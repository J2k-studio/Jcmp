// Screen: a picture of colour dots (rgb) shown in the terminal. Two dots sit in one character cell (the upper half
// block with a colour for the top and a colour for the bottom), so a terminal of 100 x 40 characters gives 100 x 80 dots.
//   #import <gfx>   using gfx::screen;
//   Screen s = Screen::make(Term::cols(), (Term::rows() - 1) * 2);
//   s.clear(0, 0, 0);   s.set(10, 5, 255, 120, 40);   s.glow(0.6);   s.show();
// A colour is three numbers 0..255, or one packed number from Screen::rgb(r, g, b).
struct Screen {
    int w;
    int h;                       // in dots (an even number)
    int[] pix;                   // 0xRRGGBB for each dot
    static Screen make(int w, int h) {
        Screen s;
        s.w = w;
        s.h = h + h % 2;
        s.pix = arr(s.w * s.h);
        s.pix.resize(s.w * s.h);
        s.clear(0, 0, 0);
        return s;
    }
    void free(self) {
        self.pix.free();
    }
    static int rgb(int r, int g, int b) {
        if r < 0 { r = 0; }
        if r > 255 { r = 255; }
        if g < 0 { g = 0; }
        if g > 255 { g = 255; }
        if b < 0 { b = 0; }
        if b > 255 { b = 255; }
        return (r << 16) | (g << 8) | b;
    }
    void clear(self, int r, int g, int b) {
        int c = Screen::rgb(r, g, b);
        for i in 0..self.w * self.h { self.pix[i] = c; }
    }
    void set(self, int x, int y, int r, int g, int b) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        self.pix[y * self.w + x] = Screen::rgb(r, g, b);
    }
    void set_packed(self, int x, int y, int c) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        self.pix[y * self.w + x] = c;
    }
    // adds light to a dot (the colours are added up, to 255 at most)
    void add(self, int x, int y, int r, int g, int b) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        int c = self.pix[y * self.w + x];
        self.pix[y * self.w + x] = Screen::rgb(((c >> 16) & 255) + r, ((c >> 8) & 255) + g, (c & 255) + b);
    }
    int get(self, int x, int y) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return 0; }
        return self.pix[y * self.w + x];
    }
    // light spreads out of the bright dots (a soft blur added on top): strength 0..1
    void glow(self, double strength) {
        int n = self.w * self.h;
        int[] tmp = arr(n);
        tmp.resize(n);
        int[] out = arr(n);
        out.resize(n);
        // blur along x then along y: a box of 2 * 3 + 1 dots, three times for a smooth falloff
        for pass in 0..2 {
            for y in 0..self.h {
                for x in 0..self.w {
                    int sr = 0;
                    int sg = 0;
                    int sb = 0;
                    int cnt = 0;
                    for k in -3..4 {
                        int xx = x + k;
                        if xx >= 0 && xx < self.w {
                            int c = self.pix[y * self.w + xx];
                            if pass == 1 { c = tmp[y * self.w + xx]; }
                            sr += (c >> 16) & 255;
                            sg += (c >> 8) & 255;
                            sb += c & 255;
                            cnt += 1;
                        }
                    }
                    tmp[y * self.w + x] = Screen::rgb(sr / cnt, sg / cnt, sb / cnt);
                }
            }
            for y in 0..self.h {
                for x in 0..self.w {
                    int sr = 0;
                    int sg = 0;
                    int sb = 0;
                    int cnt = 0;
                    for k in -3..4 {
                        int yy = y + k;
                        if yy >= 0 && yy < self.h {
                            int c = tmp[yy * self.w + x];
                            sr += (c >> 16) & 255;
                            sg += (c >> 8) & 255;
                            sb += c & 255;
                            cnt += 1;
                        }
                    }
                    out[y * self.w + x] = Screen::rgb(sr / cnt, sg / cnt, sb / cnt);
                }
            }
            for i in 0..n { tmp[i] = out[i]; }
            if pass == 0 {
                // the second round blurs the blurred picture
                for i in 0..n { out[i] = tmp[i]; }
            }
        }
        for i in 0..n {
            int c = self.pix[i];
            int g = out[i];
            int r = ((c >> 16) & 255) + (int)(strength * (double)((g >> 16) & 255) * 2.0);
            int gr = ((c >> 8) & 255) + (int)(strength * (double)((g >> 8) & 255) * 2.0);
            int b = (c & 255) + (int)(strength * (double)(g & 255) * 2.0);
            self.pix[i] = Screen::rgb(r, gr, b);
        }
        tmp.free();
        out.free();
    }
    // the picture as text (with the colour codes), starting with "back to the top left"
    String frame(self) {
        String o = "";
        o.push((char)27);
        o.append("[H");
        int last_top = -1;
        int last_bot = -1;
        for row in 0..self.h / 2 {
            for x in 0..self.w {
                int top = self.pix[(row * 2) * self.w + x];
                int bot = self.pix[(row * 2 + 1) * self.w + x];
                if top != last_top {
                    o.push((char)27);
                    o.append("[38;2;");
                    o.append(json_int_text((top >> 16) & 255));
                    o.push(';');
                    o.append(json_int_text((top >> 8) & 255));
                    o.push(';');
                    o.append(json_int_text(top & 255));
                    o.push('m');
                    last_top = top;
                }
                if bot != last_bot {
                    o.push((char)27);
                    o.append("[48;2;");
                    o.append(json_int_text((bot >> 16) & 255));
                    o.push(';');
                    o.append(json_int_text((bot >> 8) & 255));
                    o.push(';');
                    o.append(json_int_text(bot & 255));
                    o.push('m');
                    last_bot = bot;
                }
                o.append("▀");              // the upper half block
            }
            o.push((char)27);
            o.append("[0m\n");
            last_top = -1;
            last_bot = -1;
        }
        return o;
    }
    void show(self) {
        cout << self.frame();
    }
    // clears the terminal (call it once before the first show)
    void begin(self) {
        String s = "";
        s.push((char)27);
        s.append("[2J");
        cout << s;
    }
    // back to the normal colours (call it when the program ends by itself)
    void end(self) {
        String s = "";
        s.push((char)27);
        s.append("[0m");
        cout << s;
    }
}
