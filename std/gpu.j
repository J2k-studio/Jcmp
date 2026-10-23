// gpu 0.1.0 -- the graphics chip for J2K programs.   #import <gpu>   (needs jcmp 1.1.0.0; license: MPL-2.0)
//   Gpu g = Gpu::open(320, 180);                  // a picture of 320 x 180 logical pixels, scaled to the screen (in the Jaric app)
//   if !g.ok() { cout << "no graphics chip here\n"; return; }
//   g.load(1, "ship.png");                        // a picture file becomes the texture 1
//   while g.running() {
//       g.begin();                                // touches and keys, g.dt
//       g.clear(Gpu::rgb(10, 20, 40));
//       g.rect(10, 10, 50, 30, Gpu::rgb(255, 200, 60));
//       g.tri(100, 100, 140, 100, 120, 60, Gpu::rgb(255, 0, 0));
//       g.tri_colors(200, 100, Gpu::rgb(255, 0, 0), 240, 100, Gpu::rgb(0, 255, 0), 220, 60, Gpu::rgb(0, 0, 255));
//       g.image(1, 150, 90, 32, 32, Gpu::rgb(255, 255, 255));      // the last number tints the picture (white = as it is)
//       g.end();                                  // sends the picture to the chip and waits for the next one
//   }
//   g.close();
// The commands are written into a file and the Jaric app draws them with OpenGL ES (the chip does the work, not the processor).
// Colours are 0xAARRGGBB (Gpu::rgb is opaque, Gpu::rgba(r,g,b,a) has an alpha). Touch: g.touching() g.tapped() g.touch_x g.touch_y.
// Elsewhere (a terminal) Gpu::open gives a Gpu that is not ok(): use the library gamej there. Esc and the back key end the game.
// g.renderer is the name of the chip when the app told it (for example "Mali-G76").

char gpu_tio[64];
bool gpu_raw;

int gpu_byte(int ms) {
    if !Input::ready(ms) { return 0 - 1; }
    char b[2];
    int n = Sys::read(0, @b, 1);
    if n <= 0 { return 0 - 2; }
    return b[0] & 255;
}

struct Gpu {
    int w;
    int h;
    int fd;
    String path;
    String renderer;
    int[] cmd;
    char^ buf;
    int buf_cap;
    bool good;
    bool alive;
    int frame;
    int last_ms;
    int target_ms;
    double dt;
    int touch_x;
    int touch_y;
    bool touch_down;
    bool touch_hit;
    int[] key_at;
    int[] key_hit;

    static int rgb(int r, int g, int b) { return 0xff000000 | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255); }
    static int rgba(int r, int g, int b, int a) { return ((a & 255) << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255); }

    static Gpu open(int w, int h) {
        Gpu g;
        g.w = w;
        g.h = h;
        g.good = false;
        g.alive = true;
        g.frame = 0;
        g.renderer = "";
        g.touch_down = false;
        g.touch_hit = false;
        g.touch_x = 0;
        g.touch_y = 0;
        g.target_ms = 16;
        g.dt = 0.016;
        g.last_ms = Time::now_ms();
        g.cmd = arr(1024);
        g.key_at = arr(512);
        g.key_hit = arr(512);
        for i in 0..512 { g.key_at.push(0 - 100000); g.key_hit.push(0); }
        bool in_app = false;
        switch Env::get("JARIC") {
            Option::Some(v): { in_app = true; }
            Option::None: { }
        }
        if !in_app || Sys::isatty(0) != 0 || Sys::isatty(1) != 0 { g.alive = false; return g; }
        String tmp = "/data/local/tmp";
        switch Env::get("TMPDIR") {
            Option::Some(t): { tmp = t; }
            Option::None: { }
        }
        g.path = tmp + "/gpu-cmd-" + str(Sys::getpid());
        g.fd = Sys::open_write(g.path.c());
        if g.fd < 0 { g.alive = false; return g; }
        g.buf_cap = 65536;
        g.buf = (char^)Mem::alloc(g.buf_cap);
        Sys::write(g.fd, g.buf, 4);
        Sys::call(29, 0, 21505, (int)@gpu_tio, 0, 0, 0);
        char r[64];
        for i in 0..64 { r[i] = gpu_tio[i]; }
        r[12] = r[12] & 244;
        Sys::call(29, 0, 21506, (int)@r, 0, 0, 0);
        gpu_raw = true;
        cout << "\e[?1049h\e[?25l\e]7777;gpu;open;" << w << ";" << h << ";" << g.path << "\a";
        g.good = true;
        return g;
    }

    bool ok(self) { return self.good; }
    bool running(self) { return self.alive; }
    void quit(self) { self.alive = false; }
    void set_fps(self, int fps) { if fps < 1 { fps = 1; } self.target_ms = 1000 / fps; }

    void load(self, int id, String file) {
        if !self.good { return; }
        String p = file;
        if !p.starts_with("/") {
            switch Env::get("JEC_ASSETS") {
                Option::Some(a): { if Fs::exists(a + "/" + file) { p = a + "/" + file; } }
                Option::None: { }
            }
        }
        cout << "\e]7777;gpu;tex;" << id << ";" << p << "\a";
    }

    void clear(self, int argb) { self.cmd.push(1); self.cmd.push(argb); }
    void tri(self, int x0, int y0, int x1, int y1, int x2, int y2, int argb) {
        self.cmd.push(2); self.cmd.push(x0); self.cmd.push(y0); self.cmd.push(x1); self.cmd.push(y1); self.cmd.push(x2); self.cmd.push(y2); self.cmd.push(argb);
    }
    void rect(self, int x, int y, int rw, int rh, int argb) {
        self.cmd.push(3); self.cmd.push(x); self.cmd.push(y); self.cmd.push(rw); self.cmd.push(rh); self.cmd.push(argb);
    }
    void tri_colors(self, int x0, int y0, int c0, int x1, int y1, int c1, int x2, int y2, int c2) {
        self.cmd.push(4); self.cmd.push(x0); self.cmd.push(y0); self.cmd.push(c0); self.cmd.push(x1); self.cmd.push(y1); self.cmd.push(c1); self.cmd.push(x2); self.cmd.push(y2); self.cmd.push(c2);
    }
    void image(self, int tex, int x, int y, int iw, int ih, int tint) {
        self.cmd.push(5); self.cmd.push(tex); self.cmd.push(x); self.cmd.push(y); self.cmd.push(iw); self.cmd.push(ih); self.cmd.push(tint);
    }
    // a part of the picture: u0 v0 u1 v1 in millionths (0 .. 1000000)
    void image_part(self, int tex, int x, int y, int iw, int ih, int u0, int v0, int u1, int v1, int tint) {
        self.cmd.push(6); self.cmd.push(tex); self.cmd.push(x); self.cmd.push(y); self.cmd.push(iw); self.cmd.push(ih);
        self.cmd.push(u0); self.cmd.push(v0); self.cmd.push(u1); self.cmd.push(v1); self.cmd.push(tint);
    }
    void line(self, int x0, int y0, int x1, int y1, int width, int argb) {
        self.cmd.push(7); self.cmd.push(x0); self.cmd.push(y0); self.cmd.push(x1); self.cmd.push(y1); self.cmd.push(width); self.cmd.push(argb);
    }
    void circle(self, int cx, int cy, int r, int argb) {                 // a fan of triangles
        int steps = 24;
        if r > 20 { steps = 48; }
        int px = cx + r;
        int py = cy;
        for i in 1..steps + 1 {
            double a = 6.283185307 * (double)i / (double)steps;
            int nx = cx + (int)((double)r * Math::cos(a));
            int ny = cy + (int)((double)r * Math::sin(a));
            self.tri(cx, cy, px, py, nx, ny, argb);
            px = nx;
            py = ny;
        }
    }

    void note_key(self, int k, int now) {
        if k < 0 || k >= 512 { return; }
        self.key_at[k] = now;
        self.key_hit[k] = 1;
    }
    bool hit(self, int k) { return k >= 0 && k < 512 && self.key_hit[k] == 1; }
    bool held(self, int k) { return k >= 0 && k < 512 && Time::now_ms() - self.key_at[k] < 180; }
    bool touching(self) { return self.touch_down; }
    bool tapped(self) { return self.touch_hit; }

    // touches, keys and the time since the last picture
    void begin(self) {
        int now = Time::now_ms();
        self.dt = (double)(now - self.last_ms) / 1000.0;
        if self.dt > 0.1 { self.dt = 0.1; }
        self.last_ms = now;
        for i in 0..512 { self.key_hit[i] = 0; }
        self.touch_hit = false;
        if !self.good { return; }
        while Input::ready(0) {
            int c = gpu_byte(0);
            if c < 0 { break; }
            if c == 3 { self.alive = false; continue; }
            if c == 27 {
                int d = gpu_byte(8);
                if d < 0 { self.note_key(27, now); self.alive = false; continue; }
                if d == 91 || d == 79 {
                    int e = gpu_byte(8);
                    if e == 65 { self.note_key(257, now); } else if e == 66 { self.note_key(258, now); } else if e == 67 { self.note_key(259, now); } else if e == 68 { self.note_key(260, now); }
                    else { while e >= 48 && e <= 59 { e = gpu_byte(8); } }
                } else if d == 93 {
                    String m = "";
                    int e = gpu_byte(30);
                    while e >= 0 && e != 7 && e != 27 { m.push((char)e); e = gpu_byte(30); }
                    if e == 27 { gpu_byte(8); }
                    String[] pm = m.split(";");
                    if pm.len >= 5 && pm[0] == "7777" && pm[1] == "touch" {
                        self.touch_x = pm[3].to_int();
                        self.touch_y = pm[4].to_int();
                        if pm[2] == "D" { self.touch_down = true; self.touch_hit = true; } else if pm[2] == "U" { self.touch_down = false; }
                    } else if pm.len >= 3 && pm[0] == "7777" && pm[1] == "gpu" { self.renderer = pm[2] + ""; }
                    else if pm.len >= 2 && pm[0] == "7777" && (pm[1] == "gpu-closed" || pm[1] == "gpu-error") { self.alive = false; }
                }
                continue;
            }
            if c >= 65 && c <= 90 { c = c + 32; }
            self.note_key(c, now);
        }
    }

    // sends the picture (the commands since the last end()) to the chip and waits for the next turn
    void end(self) {
        if self.good {
            int n = self.cmd.len;
            int need = (n + 1) * 4;
            if need > self.buf_cap {
                self.buf_cap = need + 65536;
                self.buf = (char^)Mem::alloc(self.buf_cap);
            }
            self.buf[0] = (char)(n & 255);
            self.buf[1] = (char)((n >> 8) & 255);
            self.buf[2] = (char)((n >> 16) & 255);
            self.buf[3] = (char)((n >> 24) & 255);
            for i in 0..n {
                int v = self.cmd[i];
                self.buf[4 + i * 4] = (char)(v & 255);
                self.buf[5 + i * 4] = (char)((v >> 8) & 255);
                self.buf[6 + i * 4] = (char)((v >> 16) & 255);
                self.buf[7 + i * 4] = (char)((v >> 24) & 255);
            }
            Sys::call(62, self.fd, 0, 0, 0, 0, 0);
            Sys::write(self.fd, self.buf, need);
            cout << "\e]7777;gpu;present\a";
            self.cmd = arr(1024);
        }
        self.frame += 1;
        int spent = Time::now_ms() - self.last_ms;
        if spent < self.target_ms && self.good { Time::sleep_ms(self.target_ms - spent); }
    }

    void close(self) {
        if self.good {
            cout << "\e]7777;gpu;close\a\e[0m\e[?25h\e[?1049l";
            Sys::close(self.fd);
            Fs::remove(self.path);
            if gpu_raw { Sys::call(29, 0, 21506, (int)@gpu_tio, 0, 0, 0); gpu_raw = false; }
            self.good = false;
        }
        self.alive = false;
    }
}
