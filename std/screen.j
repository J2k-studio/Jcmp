// Screen: a picture of colour dots (rgb) shown in the terminal. Two dots sit in one character cell (the upper half
// block with a colour for the top and a colour for the bottom), so a terminal of 100 x 40 characters gives 100 x 80 dots.
//   #import <gfx>   using gfx::screen;
//   Screen s = Screen::make(Term::cols(), (Term::rows() - 1) * 2);
//   s.clear(0, 0, 0);   s.set(10, 5, 255, 120, 40);   s.glow(0.6);   s.show();
// A colour is three numbers 0..255, or one packed number from Screen::rgb(r, g, b).
struct Screen {
    i64 w;
    i64 h;                       // in dots (an even number)
    i64[] pix;                   // 0xRRGGBB for each dot
    static Screen make(i64 w, i64 h) {
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
    static i64 rgb(i64 r, i64 g, i64 b) {
        if r < 0 { r = 0; }
        if r > 255 { r = 255; }
        if g < 0 { g = 0; }
        if g > 255 { g = 255; }
        if b < 0 { b = 0; }
        if b > 255 { b = 255; }
        return (r << 16) | (g << 8) | b;
    }
    void clear(self, i64 r, i64 g, i64 b) {
        i64 c = Screen::rgb(r, g, b);
        for i in 0..self.w * self.h { self.pix[i] = c; }
    }
    void set(self, i64 x, i64 y, i64 r, i64 g, i64 b) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        self.pix[y * self.w + x] = Screen::rgb(r, g, b);
    }
    void set_packed(self, i64 x, i64 y, i64 c) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        self.pix[y * self.w + x] = c;
    }
    // adds light to a dot (the colours are added up, to 255 at most)
    void add(self, i64 x, i64 y, i64 r, i64 g, i64 b) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        i64 c = self.pix[y * self.w + x];
        self.pix[y * self.w + x] = Screen::rgb(((c >> 16) & 255) + r, ((c >> 8) & 255) + g, (c & 255) + b);
    }
    i64 get(self, i64 x, i64 y) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return 0; }
        return self.pix[y * self.w + x];
    }
    // mixes a colour into a dot: a = 0 keeps the dot, a = 1 puts the colour
    void blend(self, i64 x, i64 y, i64 r, i64 g, i64 b, double a) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        i64 c = self.pix[y * self.w + x];
        i64 nr = (i64)((double)((c >> 16) & 255) * (1.0 - a) + (double)r * a);
        i64 ng = (i64)((double)((c >> 8) & 255) * (1.0 - a) + (double)g * a);
        i64 nb = (i64)((double)(c & 255) * (1.0 - a) + (double)b * a);
        self.pix[y * self.w + x] = Screen::rgb(nr, ng, nb);
    }
    // a straight line from (x0, y0) to (x1, y1), both ends included (Bresenham)
    void line(self, i64 x0, i64 y0, i64 x1, i64 y1, i64 r, i64 g, i64 b) {
        i64 dx = x1 - x0;
        if dx < 0 { dx = 0 - dx; }
        i64 dy = y1 - y0;
        if dy < 0 { dy = 0 - dy; }
        i64 sx = 1;
        if x0 > x1 { sx = -1; }
        i64 sy = 1;
        if y0 > y1 { sy = -1; }
        i64 err = dx - dy;
        i64 c = Screen::rgb(r, g, b);
        while true {
            self.set_packed(x0, y0, c);
            if x0 == x1 && y0 == y1 { break; }
            i64 e2 = 2 * err;
            if e2 > 0 - dy {
                err -= dy;
                x0 += sx;
            }
            if e2 < dx {
                err += dx;
                y0 += sy;
            }
        }
    }
    // the border of a rectangle with the corner (x, y), w dots wide and h high
    void rect(self, i64 x, i64 y, i64 w, i64 h, i64 r, i64 g, i64 b) {
        if w <= 0 || h <= 0 { return; }
        self.line(x, y, x + w - 1, y, r, g, b);
        self.line(x, y + h - 1, x + w - 1, y + h - 1, r, g, b);
        self.line(x, y, x, y + h - 1, r, g, b);
        self.line(x + w - 1, y, x + w - 1, y + h - 1, r, g, b);
    }
    void fill_rect(self, i64 x, i64 y, i64 w, i64 h, i64 r, i64 g, i64 b) {
        i64 c = Screen::rgb(r, g, b);
        for j in 0..h {
            for i in 0..w { self.set_packed(x + i, y + j, c); }
        }
    }
    // the border of a circle with the middle (cx, cy) (the midpoint method)
    void circle(self, i64 cx, i64 cy, i64 rad, i64 r, i64 g, i64 b) {
        i64 c = Screen::rgb(r, g, b);
        i64 x = rad;
        i64 y = 0;
        i64 err = 1 - rad;
        while x >= y {
            self.set_packed(cx + x, cy + y, c);
            self.set_packed(cx + y, cy + x, c);
            self.set_packed(cx - y, cy + x, c);
            self.set_packed(cx - x, cy + y, c);
            self.set_packed(cx - x, cy - y, c);
            self.set_packed(cx - y, cy - x, c);
            self.set_packed(cx + y, cy - x, c);
            self.set_packed(cx + x, cy - y, c);
            y += 1;
            if err < 0 {
                err += 2 * y + 1;
            } else {
                x -= 1;
                err += 2 * (y - x) + 1;
            }
        }
    }
    void fill_circle(self, i64 cx, i64 cy, i64 rad, i64 r, i64 g, i64 b) {
        i64 c = Screen::rgb(r, g, b);
        for j in 0 - rad..rad + 1 {
            for i in 0 - rad..rad + 1 {
                if i * i + j * j <= rad * rad { self.set_packed(cx + i, cy + j, c); }
            }
        }
    }
    // the whole picture goes from one colour at the top to another at the bottom
    void gradient_v(self, i64 r0, i64 g0, i64 b0, i64 r1, i64 g1, i64 b1) {
        for y in 0..self.h {
            double t = (double)y / (double)(self.h - 1);
            i64 c = Screen::rgb((i64)((double)r0 + (double)(r1 - r0) * t), (i64)((double)g0 + (double)(g1 - g0) * t), (i64)((double)b0 + (double)(b1 - b0) * t));
            for x in 0..self.w { self.pix[y * self.w + x] = c; }
        }
    }
    // effects on the whole picture
    // the edges get darker: strength 0 (nothing) to 1 (black at the corners)
    void vignette(self, double strength) {
        double cx = (double)self.w / 2.0;
        double cy = (double)self.h / 2.0;
        double rmax = cx * cx + cy * cy;
        for y in 0..self.h {
            for x in 0..self.w {
                double dx = (double)x + 0.5 - cx;
                double dy = (double)y + 0.5 - cy;
                double f = 1.0 - strength * (dx * dx + dy * dy) / rmax;
                i64 c = self.pix[y * self.w + x];
                self.pix[y * self.w + x] = Screen::rgb((i64)((double)((c >> 16) & 255) * f), (i64)((double)((c >> 8) & 255) * f), (i64)((double)(c & 255) * f));
            }
        }
    }
    // every second row is darker (like an old screen): strength 0 to 1
    void scanlines(self, double strength) {
        double f = 1.0 - strength;
        for y in 0..self.h {
            if y % 2 == 1 {
                for x in 0..self.w {
                    i64 c = self.pix[y * self.w + x];
                    self.pix[y * self.w + x] = Screen::rgb((i64)((double)((c >> 16) & 255) * f), (i64)((double)((c >> 8) & 255) * f), (i64)((double)(c & 255) * f));
                }
            }
        }
    }
    // all the dots lighter (f > 1) or darker (f < 1)
    void brightness(self, double f) {
        for i in 0..self.w * self.h {
            i64 c = self.pix[i];
            self.pix[i] = Screen::rgb((i64)((double)((c >> 16) & 255) * f), (i64)((double)((c >> 8) & 255) * f), (i64)((double)(c & 255) * f));
        }
    }
    // the opposite colours
    void invert(self) {
        for i in 0..self.w * self.h {
            self.pix[i] = 16777215 - self.pix[i];
        }
    }
    // how many dots are not black (to count what was drawn)
    i64 lit(self) {
        i64 n = 0;
        for i in 0..self.w * self.h { if self.pix[i] != 0 { n += 1; } }
        return n;
    }

    // light spreads out of the bright dots (a soft blur added on top): strength 0..1
    void glow(self, double strength) {
        i64 n = self.w * self.h;
        i64[] tmp = arr(n);
        tmp.resize(n);
        i64[] out = arr(n);
        out.resize(n);
        // blur along x then along y: a box of 2 * 3 + 1 dots, three times for a smooth falloff
        for pass in 0..2 {
            for y in 0..self.h {
                for x in 0..self.w {
                    i64 sr = 0;
                    i64 sg = 0;
                    i64 sb = 0;
                    i64 cnt = 0;
                    for k in -3..4 {
                        i64 xx = x + k;
                        if xx >= 0 && xx < self.w {
                            i64 c = self.pix[y * self.w + xx];
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
                    i64 sr = 0;
                    i64 sg = 0;
                    i64 sb = 0;
                    i64 cnt = 0;
                    for k in -3..4 {
                        i64 yy = y + k;
                        if yy >= 0 && yy < self.h {
                            i64 c = tmp[yy * self.w + x];
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
            i64 c = self.pix[i];
            i64 g = out[i];
            i64 r = ((c >> 16) & 255) + (i64)(strength * (double)((g >> 16) & 255) * 2.0);
            i64 gr = ((c >> 8) & 255) + (i64)(strength * (double)((g >> 8) & 255) * 2.0);
            i64 b = (c & 255) + (i64)(strength * (double)(g & 255) * 2.0);
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
        i64 last_top = -1;
        i64 last_bot = -1;
        for row in 0..self.h / 2 {
            for x in 0..self.w {
                i64 top = self.pix[(row * 2) * self.w + x];
                i64 bot = self.pix[(row * 2 + 1) * self.w + x];
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
        jout << self.frame();
    }
    // clears the terminal (call it once before the first show)
    void begin(self) {
        String s = "";
        s.push((char)27);
        s.append("[2J");
        jout << s;
    }
    // back to the normal colours (call it when the program ends by itself)
    void end(self) {
        String s = "";
        s.push((char)27);
        s.append("[0m");
        jout << s;
    }
}
