// gamej 0.2.0 -- JARIC ENGINE, a small game engine for the terminal and the Jaric app.   #import <gamej>   (needs jcmp 1.1.0.0; license: MPL-2.0)
//   Game g = Game::open("Pong");                  // the whole terminal is the screen; each text cell is two pixels (half blocks, 24-bit colour)
//   while g.running() {
//       g.begin();                                // keys, the time since the last frame (g.dt, seconds)
//       if g.held(Key::left()) { x -= 40.0 * g.dt; }
//       g.clear(Game::rgb(16, 24, 32));
//       g.rect(10, 10, 8, 4, Game::rgb(255, 255, 255));    // x y w h colour (0xRRGGBB)
//       g.text(2, 2, "SCORE 12", Game::rgb(255, 220, 80));
//       g.end();                                  // draws the frame and waits for the next one (60 per second)
//   }
//   g.close();
// Pixels: g.w x g.h. Draw: clear pixel rect frame line circle text art. Keys: hit(k) = pressed since the last frame, held(k) = pressed lately
// (a terminal has no key-up message, so a held key is a key that repeated within 0.18 s; the keys row of the Jaric app gives single presses).
// Esc and Ctrl-C end the game. GAME_FRAMES=N (environment) runs N frames without a terminal and stops (for tests).
// Sound in the Jaric app: g.sound("file.mp3").
// In the Jaric app the game draws on a SURFACE (a picture of g.w x g.h pixels, 160 x 90, drawn by the graphics chip and scaled to the screen) and
// a touch comes as g.touching() / g.tapped() with g.touch_x, g.touch_y (in pixels). Elsewhere the terminal is the screen. GAMEJ_TERM=1 forces the terminal.
// The back key of the app ends a game that has a surface.

struct Key {
    static int up() { return 257; }
    static int down() { return 258; }
    static int right() { return 259; }
    static int left() { return 260; }
    static int space() { return 32; }
    static int enter() { return 13; }
    static int esc() { return 27; }
}

char game_tio[64];
bool game_raw;
bool game_tty;

void game_raw_on() {
    if game_raw || Sys::isatty(0) != 0 { return; }
    Sys::call(29, 0, 21505, (int)@game_tio, 0, 0, 0);
    char r[64];
    for i in 0..64 { r[i] = game_tio[i]; }
    r[12] = r[12] & 244;                                    // no signals, no line editing, no echo: a key arrives at once
    Sys::call(29, 0, 21506, (int)@r, 0, 0, 0);
    game_raw = true;
}

void game_raw_off() {
    if !game_raw { return; }
    Sys::call(29, 0, 21506, (int)@game_tio, 0, 0, 0);
    game_raw = false;
}

int game_byte(int ms) {
    if !Input::ready(ms) { return 0 - 1; }
    char b[2];
    int n = Sys::read(0, @b, 1);
    if n <= 0 { return 0 - 2; }
    return b[0] & 255;
}

String game_font() { return "00000222025500057575367365124525253220001222142224052500272000024007000000211244755572622771747717175571174717747577111175757757170202002024124210707042124713027574725755656563444365556746477464434553557557222711152556554444757755655552555265644255636565534216722225555755552557755525555222712476444644211311132500000007"; }

struct Game {
    int w;
    int h;
    int cols;
    int rows;
    int[] px;
    int[] prev;
    int[] key_at;               // the time (ms) each key was last seen
    int[] key_hit;              // 1: pressed since the last begin()
    bool alive;
    bool first;
    int frame;
    int last_ms;
    int target_ms;
    int limit;                  // GAME_FRAMES
    bool surf;                  // drawing on the surface of the app
    int sfd;
    char^ sbuf;
    String spath;
    int touch_x;
    int touch_y;
    bool touch_down;
    bool touch_hit;
    double dt;
    String font;

    static int rgb(int r, int g, int b) { return ((r & 255) << 16) | ((g & 255) << 8) | (b & 255); }

    static Game open(String title) {
        Game g;
        g.cols = Term::cols();
        g.rows = Term::rows();
        game_tty = Sys::isatty(1) == 0 && Sys::isatty(0) == 0;
        g.limit = 0;
        switch Env::get("GAME_FRAMES") {
            Option::Some(v): { g.limit = v.to_int(); }
            Option::None: { }
        }
        if !game_tty && g.limit == 0 { g.limit = 1; }
        if !game_tty { g.cols = 80; g.rows = 24; }
        g.w = g.cols;
        g.h = g.rows * 2;
        g.surf = false;
        g.touch_down = false;
        g.touch_hit = false;
        g.touch_x = 0;
        g.touch_y = 0;
        bool in_app = false;
        switch Env::get("JARIC") {
            Option::Some(v): { in_app = true; }
            Option::None: { }
        }
        switch Env::get("GAMEJ_TERM") {
            Option::Some(v): { in_app = false; }
            Option::None: { }
        }
        if in_app && game_tty {
            g.surf = true;
            g.w = 160;
            g.h = 90;
        }
        g.px = arr(g.w * g.h + 1);
        g.prev = arr(g.w * g.h + 1);
        for i in 0..g.w * g.h { g.px.push(0); g.prev.push(0 - 1); }
        g.key_at = arr(512);
        g.key_hit = arr(512);
        for i in 0..512 { g.key_at.push(0 - 100000); g.key_hit.push(0); }
        g.alive = true;
        g.first = true;
        g.frame = 0;
        g.target_ms = 16;
        g.dt = 0.016;
        g.last_ms = Time::now_ms();
        g.font = game_font();
        if game_tty {
            game_raw_on();
            cout << "\e[?1049h\e[?25l\e[2J";
        }
        if g.surf {
            String tmp = "/data/local/tmp";
            switch Env::get("TMPDIR") {
                Option::Some(t): { tmp = t; }
                Option::None: { }
            }
            g.spath = tmp + "/gamej-fb-" + str(Sys::getpid());
            g.sfd = Sys::open_write(g.spath.c());
            if g.sfd < 0 {
                g.surf = false;
                g.w = g.cols;
                g.h = g.rows * 2;
                g.px = arr(g.w * g.h + 1);
                g.prev = arr(g.w * g.h + 1);
                for i in 0..g.w * g.h { g.px.push(0); g.prev.push(0 - 1); }
            }
            else {
                g.sbuf = (char^)Mem::alloc(g.w * g.h * 4 + 16);
                for i in 0..g.w * g.h * 4 { g.sbuf[i] = 0; }
                Sys::write(g.sfd, g.sbuf, g.w * g.h * 4);
                cout << "\e]7777;gfx;open;" << g.w << ";" << g.h << ";" << g.spath << "\a";
            }
        }
        return g;
    }

    bool running(self) { return self.alive; }
    void quit(self) { self.alive = false; }

    // frames per second (default 60)
    void set_fps(self, int fps) {
        if fps < 1 { fps = 1; }
        self.target_ms = 1000 / fps;
    }

    void close(self) {
        if self.surf {
            cout << "\e]7777;gfx;close\a";
            Sys::close(self.sfd);
            Fs::remove(self.spath);
            self.surf = false;
        }
        if game_tty {
            cout << "\e[0m\e[?25h\e[?1049l";
            game_raw_off();
        }
        self.alive = false;
    }

    void note_key(self, int k, int now) {
        if k < 0 || k >= 512 { return; }
        self.key_at[k] = now;
        self.key_hit[k] = 1;
    }

    // keys and time: call it first in every frame
    void begin(self) {
        int now = Time::now_ms();
        self.dt = (double)(now - self.last_ms) / 1000.0;
        if self.dt > 0.1 { self.dt = 0.1; }                      // a long pause does not throw things through walls
        self.last_ms = now;
        for i in 0..512 { self.key_hit[i] = 0; }
        self.touch_hit = false;
        if !game_tty { return; }
        while Input::ready(0) {
            int c = game_byte(0);
            if c < 0 { break; }
            if c == 3 { self.alive = false; continue; }
            if c == 27 {
                int d = game_byte(8);
                if d < 0 { self.note_key(27, now); self.alive = false; continue; }
                if d == 91 || d == 79 {
                    int e = game_byte(8);
                    if e == 65 { self.note_key(257, now); }
                    else if e == 66 { self.note_key(258, now); }
                    else if e == 67 { self.note_key(259, now); }
                    else if e == 68 { self.note_key(260, now); }
                    else { while e >= 48 && e <= 59 { e = game_byte(8); } }
                } else if d == 93 {                                // a message of the app: read it up to BEL
                    String m = "";
                    int e = game_byte(30);
                    while e >= 0 && e != 7 && e != 27 { m.push((char)e); e = game_byte(30); }
                    if e == 27 { game_byte(8); }
                    String[] pm = m.split(";");
                    if pm.len >= 5 && pm[0] == "7777" && pm[1] == "touch" {
                        self.touch_x = pm[3].to_int();
                        self.touch_y = pm[4].to_int();
                        if pm[2] == "D" { self.touch_down = true; self.touch_hit = true; }
                        else if pm[2] == "U" { self.touch_down = false; }
                    } else if pm.len >= 2 && pm[0] == "7777" && pm[1] == "gfx-closed" { self.alive = false; }
                }
                continue;
            }
            if c >= 65 && c <= 90 { c = c + 32; }                  // letters are lower case: hit('a')
            self.note_key(c, now);
        }
    }

    // the finger is on the screen / has just touched it (the surface of the Jaric app)
    bool touching(self) { return self.touch_down; }
    bool tapped(self) { return self.touch_hit; }
    bool hit(self, int k) { return k >= 0 && k < 512 && self.key_hit[k] == 1; }
    bool held(self, int k) { return k >= 0 && k < 512 && Time::now_ms() - self.key_at[k] < 180; }

    void clear(self, int c) {
        for i in 0..self.w * self.h { self.px[i] = c; }
    }

    void pixel(self, int x, int y, int c) {
        if x < 0 || y < 0 || x >= self.w || y >= self.h { return; }
        self.px[y * self.w + x] = c;
    }

    int get(self, int x, int y) {
        if x < 0 || y < 0 || x >= self.w || y >= self.h { return 0; }
        return self.px[y * self.w + x];
    }

    void rect(self, int x, int y, int rw, int rh, int c) {
        int x0 = x;
        int y0 = y;
        int x1 = x + rw;
        int y1 = y + rh;
        if x0 < 0 { x0 = 0; }
        if y0 < 0 { y0 = 0; }
        if x1 > self.w { x1 = self.w; }
        if y1 > self.h { y1 = self.h; }
        for yy in y0..y1 {
            for xx in x0..x1 { self.px[yy * self.w + xx] = c; }
        }
    }

    void frame_rect(self, int x, int y, int rw, int rh, int c) {
        self.rect(x, y, rw, 1, c);
        self.rect(x, y + rh - 1, rw, 1, c);
        self.rect(x, y, 1, rh, c);
        self.rect(x + rw - 1, y, 1, rh, c);
    }

    void line(self, int x0, int y0, int x1, int y1, int c) {
        int dx = x1 - x0;
        if dx < 0 { dx = 0 - dx; }
        int dy = y1 - y0;
        if dy < 0 { dy = 0 - dy; }
        int sx = 1;
        if x0 > x1 { sx = 0 - 1; }
        int sy = 1;
        if y0 > y1 { sy = 0 - 1; }
        int err = dx - dy;
        while true {
            self.pixel(x0, y0, c);
            if x0 == x1 && y0 == y1 { break; }
            int e2 = 2 * err;
            if e2 > 0 - dy { err -= dy; x0 += sx; }
            if e2 < dx { err += dx; y0 += sy; }
        }
    }

    void circle(self, int cx, int cy, int r, int c) {
        for yy in 0 - r..r + 1 {
            for xx in 0 - r..r + 1 {
                if xx * xx + yy * yy <= r * r { self.pixel(cx + xx, cy + yy, c); }
            }
        }
    }

    // text with a small 3 x 5 font (capital letters, digits, signs); returns the x after the last letter
    int text(self, int x, int y, String s, int c) {
        return self.text_scaled(x, y, s, c, 1);
    }

    int text_scaled(self, int x, int y, String s, int c, int scale) {
        for i in 0..s.len {
            int ch = s[i] & 255;
            if ch >= 97 && ch <= 122 { ch = ch - 32; }
            if ch < 32 || ch > 95 { ch = 63; }
            int g = (ch - 32) * 5;
            for ry in 0..5 {
                int bits = self.font[g + ry] - 48;
                for rx in 0..3 {
                    if ((bits >> (2 - rx)) & 1) != 0 { self.rect(x + rx * scale, y + ry * scale, scale, scale, c); }
                }
            }
            x += 4 * scale;
        }
        return x;
    }

    // a picture made of letters: rows separated by new lines; the legend is  <letter>#RRGGBB  repeated ("r#ff0000g#00ff00");
    // '.' and ' ' are empty. Example: g.art(10, 5, ".rr.\nrrrr\n.rr.", "r#ff4040");
    void art(self, int x, int y, String rows, String legend) {
        int yy = 0;
        int xx = 0;
        for i in 0..rows.len {
            int ch = rows[i] & 255;
            if ch == 10 { yy += 1; xx = 0; continue; }
            if ch != 46 && ch != 32 {
                int k = 0;
                while k + 8 <= legend.len {
                    if (legend[k] & 255) == ch {
                        int v = 0;
                        for q in 0..6 {
                            int d = legend[k + 2 + q] & 255;
                            int dv = 0;
                            if d >= 48 && d <= 57 { dv = d - 48; } else if d >= 97 && d <= 102 { dv = d - 87; } else if d >= 65 && d <= 70 { dv = d - 55; }
                            v = v * 16 + dv;
                        }
                        self.pixel(x + xx, y + yy, v);
                        break;
                    }
                    k += 8;
                }
            }
            xx += 1;
        }
    }

    // two boxes overlap?
    static bool overlap(int ax, int ay, int aw, int ah, int bx, int by, int bw, int bh) {
        return ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah;
    }

    void sound(self, String path) {
        switch Env::get("JARIC") {
            Option::Some(v): { cout << "\e]7777;audio;play;" << path << "\a"; }
            Option::None: { }
        }
    }

    // draws the frame (only the cells that changed) and waits for the next one
    void end(self) {
        if game_tty { self.present(); }
        self.frame += 1;
        if self.limit > 0 && self.frame >= self.limit { self.alive = false; }
        int spent = Time::now_ms() - self.last_ms;
        if spent < self.target_ms && game_tty { Time::sleep_ms(self.target_ms - spent); }
    }

    void present(self) {
        if self.surf {
            int n = self.w * self.h;
            for i in 0..n {
                int c = self.px[i];
                self.sbuf[i * 4] = (char)(c & 255);
                self.sbuf[i * 4 + 1] = (char)((c >> 8) & 255);
                self.sbuf[i * 4 + 2] = (char)((c >> 16) & 255);
                self.sbuf[i * 4 + 3] = (char)255;
            }
            Sys::call(62, self.sfd, 0, 0, 0, 0, 0);               // lseek to the start
            Sys::write(self.sfd, self.sbuf, n * 4);
            cout << "\e]7777;gfx;present\a";
            return;
        }
        String s = "";
        int lastcol = 0 - 5;
        int lastrow = 0 - 5;
        int fgc = 0 - 1;
        int bgc = 0 - 1;
        for r in 0..self.rows {
            for x in 0..self.w {
                int top = self.px[(2 * r) * self.w + x];
                int bot = self.px[(2 * r + 1) * self.w + x];
                int ptop = self.prev[(2 * r) * self.w + x];
                int pbot = self.prev[(2 * r + 1) * self.w + x];
                if top == ptop && bot == pbot { continue; }
                self.prev[(2 * r) * self.w + x] = top;
                self.prev[(2 * r + 1) * self.w + x] = bot;
                if lastrow != r || lastcol != x - 1 { s.append("\e["); s.append(str(r + 1)); s.append(";"); s.append(str(x + 1)); s.append("H"); }
                if fgc != top {
                    s.append("\e[38;2;"); s.append(str((top >> 16) & 255)); s.append(";"); s.append(str((top >> 8) & 255)); s.append(";"); s.append(str(top & 255)); s.append("m");
                    fgc = top;
                }
                if bgc != bot {
                    s.append("\e[48;2;"); s.append(str((bot >> 16) & 255)); s.append(";"); s.append(str((bot >> 8) & 255)); s.append(";"); s.append(str(bot & 255)); s.append("m");
                    bgc = bot;
                }
                s.append("▀");
                lastrow = r;
                lastcol = x;
            }
        }
        if s.len > 0 { s.append("\e[0m"); cout << s; }
    }
}
