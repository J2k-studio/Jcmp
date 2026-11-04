// font 0.1.0 -- real text for apps: reads a TrueType font file (the fonts of the phone are in /system/fonts: Roboto-Regular.ttf, NotoSansThai-Regular.ttf ...),
// draws the letters with smooth edges at any size, and puts them on a <canvas2d> (every backend). Latin, numbers, signs and Thai (the marks
// of Thai go over and under their letter). The shape of a letter is made once (a small PNG in a cache folder) and then drawn as a picture.
//   Font f;  f.open("/system/fonts/Roboto-Regular.ttf");  f.add("/system/fonts/NotoSansThai-Regular.ttf");  f.cache("cache");
//   double right = f.draw(c, 20.0, 40.0, "Hello สวัสดี", 24.0, 0xffffffff);     // x, y = top of the line, size in dots, colour
//   double w = f.width("Hello", 24.0);
// Needs <canvas2d> (the backend must implement load and image) and a folder where the pictures of the letters can be written.   License: MPL-2.0.
#import <canvas2d>

// ---- the file of a font ----
struct Ttf {
    String d;                  // the bytes of the file
    int glyf;
    int loca;
    int hmtx;
    int cmap4;                 // the offset of the format 4 table of cmap (0: none)
    int cmap12;                // the offset of the format 12 table (0: none)
    int upem;                  // units per em
    int nglyphs;
    int locfmt;                // 0: short offsets, 1: long
    int nhm;                   // number of long metrics
    int asc;                   // ascender and descender in font units
    int desc;
    bool ok;

    void init(self) { self.ok = false; }

    int u8(self, int o) { return self.d[o] & 255; }
    int u16(self, int o) { return ((self.d[o] & 255) << 8) | (self.d[o + 1] & 255); }
    int i16(self, int o) {
        int v = self.u16(o);
        if v >= 32768 { v -= 65536; }
        return v;
    }
    int u32(self, int o) { return (self.u16(o) << 16) | self.u16(o + 2); }

    // reads the file; false when it is not a TrueType font that this code can use (.ttf with glyf outlines)
    bool open(self, String path) {
        Result<String, Error> r = Fs::read_bytes(path);
        if r.is_err() { return false; }
        self.d = r.unwrap();
        self.ok = false;
        if self.d.len < 12 { return false; }
        int tag = self.u32(0);
        if tag != 0x00010000 && tag != 0x74727565 { return false; }      // 1.0 or 'true'
        int nt = self.u16(4);
        self.glyf = 0; self.loca = 0; self.hmtx = 0; self.cmap4 = 0; self.cmap12 = 0;
        int head = 0; int hhea = 0; int maxp = 0; int cmap = 0;
        for i in 0..nt {
            int o = 12 + i * 16;
            int t = self.u32(o);
            int off = self.u32(o + 8);
            if t == 0x676c7966 { self.glyf = off; }          // glyf
            if t == 0x6c6f6361 { self.loca = off; }          // loca
            if t == 0x686d7478 { self.hmtx = off; }          // hmtx
            if t == 0x68656164 { head = off; }               // head
            if t == 0x68686561 { hhea = off; }               // hhea
            if t == 0x6d617870 { maxp = off; }               // maxp
            if t == 0x636d6170 { cmap = off; }               // cmap
        }
        if self.glyf == 0 || self.loca == 0 || self.hmtx == 0 || head == 0 || hhea == 0 || maxp == 0 || cmap == 0 { return false; }
        self.upem = self.u16(head + 18);
        self.locfmt = self.i16(head + 50);
        self.nglyphs = self.u16(maxp + 4);
        self.asc = self.i16(hhea + 4);
        self.desc = self.i16(hhea + 6);
        self.nhm = self.u16(hhea + 34);
        int nsub = self.u16(cmap + 2);
        for i in 0..nsub {
            int pid = self.u16(cmap + 4 + i * 8);
            int eid = self.u16(cmap + 6 + i * 8);
            int off = cmap + self.u32(cmap + 8 + i * 8);
            int fmt = self.u16(off);
            bool unicode = pid == 0 || (pid == 3 && (eid == 1 || eid == 10));
            if unicode && fmt == 4 && self.cmap4 == 0 { self.cmap4 = off; }
            if unicode && fmt == 12 && self.cmap12 == 0 { self.cmap12 = off; }
        }
        if self.cmap4 == 0 && self.cmap12 == 0 { return false; }
        self.ok = self.upem > 0;
        return self.ok;
    }

    // the glyph number of a character (0: the font has none)
    int glyph(self, int cp) {
        if self.cmap12 != 0 {
            int n = self.u32(self.cmap12 + 12);
            for i in 0..n {
                int o = self.cmap12 + 16 + i * 12;
                int s = self.u32(o);
                int e = self.u32(o + 4);
                if cp >= s && cp <= e { return self.u32(o + 8) + cp - s; }
            }
            return 0;
        }
        if self.cmap4 == 0 || cp > 65535 { return 0; }
        int segx2 = self.u16(self.cmap4 + 6);
        int endo = self.cmap4 + 14;
        int starto = endo + segx2 + 2;
        int deltao = starto + segx2;
        int rangeo = deltao + segx2;
        int seg = 0;
        while seg < segx2 {
            int e = self.u16(endo + seg);
            if cp <= e {
                int s = self.u16(starto + seg);
                if cp < s { return 0; }
                int ro = self.u16(rangeo + seg);
                int delta = self.i16(deltao + seg);
                if ro == 0 { return (cp + delta) & 65535; }
                int gi = self.u16(rangeo + seg + ro + (cp - s) * 2);
                if gi == 0 { return 0; }
                return (gi + delta) & 65535;
            }
            seg += 2;
        }
        return 0;
    }

    // the advance width of a glyph, in font units
    int advance(self, int g) {
        int k = g;
        if k >= self.nhm { k = self.nhm - 1; }
        return self.u16(self.hmtx + k * 4);
    }
    int lsb(self, int g) {
        if g < self.nhm { return self.i16(self.hmtx + g * 4 + 2); }
        return self.i16(self.hmtx + self.nhm * 4 + (g - self.nhm) * 2);
    }
}

// ---- the shape of a letter: outline -> pixels ----
// a bitmap of coverage (0..255), the size of the letter and where it sits relative to the pen (x) and the baseline (y, up is negative)
struct Glyph {
    int w;
    int h;
    int left;                  // dots from the pen to the left edge of the bitmap
    int top;                   // dots from the baseline up to the top edge (a letter above the line has a positive top)
    double adv;                // the advance in dots
    char[] a;                  // w * h bytes of coverage
}

// collects line segments of an outline in pixel space, then fills them (the area method: each segment adds its signed area to the cells it crosses,
// and the running sum along a row is the coverage)
struct Raster {
    int w;
    int h;
    double[] acc;              // (w + 3) * h cells
    double px;                 // the pen: where the last point of the contour is
    double py;
    double sx;                 // the start of the contour
    double sy;

    void make(self, int width, int height) {
        self.w = width;
        self.h = height;
        int n = (width + 3) * height;
        self.acc = arr(n);
        for i in 0..n { self.acc.push(0.0); }
    }

    // one segment, in pixel units with y down; the part above row 0 or below the bitmap is ignored
    void line(self, double x0, double y0, double x1, double y1) {
        if y0 == y1 { return; }
        double dir = 1.0;
        double ax = x0; double ay = y0; double bx = x1; double by = y1;
        if y0 > y1 { dir = 0.0 - 1.0; ax = x1; ay = y1; bx = x0; by = y0; }
        double dxdy = (bx - ax) / (by - ay);
        double x = ax;
        int ys = (int)ay;
        if ay < 0.0 { x -= ay * dxdy; ys = 0; }
        int ye = (int)by;
        if (double)ye < by { ye += 1; }
        if ye > self.h { ye = self.h; }
        int stride = self.w + 3;
        for y in ys..ye {
            double top = (double)y;
            if ay > top { top = ay; }
            double bot = (double)(y + 1);
            if by < bot { bot = by; }
            double dy = bot - top;
            double xn = x + dxdy * dy;
            double d = dy * dir;
            double lo = x;
            double hi = xn;
            if xn < x { lo = xn; hi = x; }
            if lo < 0.0 { lo = 0.0; }
            if hi < 0.0 { hi = 0.0; }
            if hi > (double)self.w { hi = (double)self.w; }
            if lo > (double)self.w { lo = (double)self.w; }
            int x0i = (int)lo;
            double x0f = lo - (double)x0i;
            int x1i = (int)hi;
            if (double)x1i < hi { x1i += 1; }
            int base = y * stride;
            if x1i <= x0i + 1 {
                double xmf = 0.5 * (lo + hi) - (double)x0i;
                self.acc[base + x0i] += d - d * xmf;
                self.acc[base + x0i + 1] += d * xmf;
            } else {
                double s = 1.0 / (hi - lo);
                double a0 = 0.5 * s * (1.0 - x0f) * (1.0 - x0f);
                double x1f = hi - (double)x1i + 1.0;
                double am = 0.5 * s * x1f * x1f;
                self.acc[base + x0i] += d * a0;
                if x1i == x0i + 2 {
                    self.acc[base + x0i + 1] += d * (1.0 - a0 - am);
                } else {
                    double a1 = s * (1.5 - x0f);
                    self.acc[base + x0i + 1] += d * (a1 - a0);
                    for xi in x0i + 2..x1i - 1 { self.acc[base + xi] += d * s; }
                    double a2 = a1 + (double)(x1i - x0i - 3) * s;
                    self.acc[base + x1i - 1] += d * (1.0 - a2 - am);
                }
                self.acc[base + x1i] += d * am;
            }
            x = xn;
        }
    }

    void move_to(self, double x, double y) {
        self.px = x; self.py = y; self.sx = x; self.sy = y;
    }
    void line_to(self, double x, double y) {
        self.line(self.px, self.py, x, y);
        self.px = x; self.py = y;
    }
    // a quadratic curve through the control point (cx, cy): cut into short lines
    void quad_to(self, double cx, double cy, double x, double y) {
        double dx = self.px - 2.0 * cx + x;
        double dy = self.py - 2.0 * cy + y;
        double dd = Math::sqrt(dx * dx + dy * dy);
        int n = (int)(Math::sqrt(dd) * 1.0) + 2;
        if n > 24 { n = 24; }
        double x0 = self.px;
        double y0 = self.py;
        for i in 1..n + 1 {
            double t = (double)i / (double)n;
            double mt = 1.0 - t;
            double qx = mt * mt * x0 + 2.0 * mt * t * cx + t * t * x;
            double qy = mt * mt * y0 + 2.0 * mt * t * cy + t * t * y;
            self.line_to(qx, qy);
        }
    }
    void close(self) {
        if self.px != self.sx || self.py != self.sy { self.line(self.px, self.py, self.sx, self.sy); }
        self.px = self.sx; self.py = self.sy;
    }

    // the coverage of the cells, 0..255
    void to_bytes(self, char[] out) {
        int stride = self.w + 3;
        for y in 0..self.h {
            double run = 0.0;
            for x in 0..self.w {
                run += self.acc[y * stride + x];
                double v = Math::abs(run);
                if v > 1.0 { v = 1.0; }
                out.push((char)((int)(v * 255.0 + 0.5)));
            }
        }
    }
}

// the points of one glyph in font units: x, y, on-curve flag; the ends of the contours
struct Outline {
    double[] x;
    double[] y;
    int[] on;
    int[] ends;                // the index of the last point of each contour

    void init(self) { }
    void clear(self) {
        self.x = arr(64);
        self.y = arr(64);
        self.on = arr(64);
        self.ends = arr(8);
    }
}

// the outline of glyph g of the font, appended to o (a composite glyph is built of its parts, with the shift and the scale they ask for)
void ttf_outline(Ttf^ t, int g, Outline^ o, double ma, double mb, double mc, double md, double dx, double dy, int depth) {
    if g < 0 || g >= t^.nglyphs || depth > 4 { return; }
    int o0 = 0;
    int o1 = 0;
    if t^.locfmt == 0 {
        o0 = t^.u16(t^.loca + g * 2) * 2;
        o1 = t^.u16(t^.loca + g * 2 + 2) * 2;
    } else {
        o0 = t^.u32(t^.loca + g * 4);
        o1 = t^.u32(t^.loca + g * 4 + 4);
    }
    if o1 <= o0 { return; }                                         // no outline (a space)
    int p = t^.glyf + o0;
    int nc = t^.i16(p);
    if nc >= 0 {
        int base = o^.x.len;
        int endp = p + 10;
        int npts = 0;
        if nc > 0 { npts = t^.u16(endp + (nc - 1) * 2) + 1; }
        int ilen = t^.u16(endp + nc * 2);
        int fp = endp + nc * 2 + 2 + ilen;
        // flags
        int[] fl = arr(npts + 1);
        int k = 0;
        while k < npts {
            int f = t^.u8(fp);
            fp += 1;
            fl.push(f);
            k += 1;
            if (f & 8) != 0 {
                int rep = t^.u8(fp);
                fp += 1;
                while rep > 0 && k < npts { fl.push(f); k += 1; rep -= 1; }
            }
        }
        // x, then y (short vectors, or same as before, or a 16 bit change)
        double[] xs = arr(npts + 1);
        int v = 0;
        for i in 0..npts {
            int f = fl[i];
            if (f & 2) != 0 {
                int dv = t^.u8(fp);
                fp += 1;
                if (f & 16) != 0 { v += dv; } else { v -= dv; }
            } else if (f & 16) == 0 {
                v += t^.i16(fp);
                fp += 2;
            }
            xs.push((double)v);
        }
        v = 0;
        for i in 0..npts {
            int f = fl[i];
            if (f & 4) != 0 {
                int dv = t^.u8(fp);
                fp += 1;
                if (f & 32) != 0 { v += dv; } else { v -= dv; }
            } else if (f & 32) == 0 {
                v += t^.i16(fp);
                fp += 2;
            }
            double px = xs[i];
            double py = (double)v;
            o^.x.push(ma * px + mc * py + dx);
            o^.y.push(mb * px + md * py + dy);
            o^.on.push(fl[i] & 1);
        }
        for c in 0..nc { o^.ends.push(base + t^.u16(endp + c * 2)); }
        fl.free();
        xs.free();
    } else {
        // composite: a list of parts
        int q = p + 10;
        bool more = true;
        while more {
            int flags = t^.u16(q);
            int gi = t^.u16(q + 2);
            q += 4;
            double ax = 0.0;
            double ay = 0.0;
            if (flags & 1) != 0 {
                if (flags & 2) != 0 { ax = (double)t^.i16(q); ay = (double)t^.i16(q + 2); }
                q += 4;
            } else {
                if (flags & 2) != 0 {
                    int b0 = t^.u8(q); int b1 = t^.u8(q + 1);
                    if b0 >= 128 { b0 -= 256; }
                    if b1 >= 128 { b1 -= 256; }
                    ax = (double)b0; ay = (double)b1;
                }
                q += 2;
            }
            double sa = 1.0; double sb = 0.0; double sc = 0.0; double sd = 1.0;
            if (flags & 8) != 0 { sa = (double)t^.i16(q) / 16384.0; sd = sa; q += 2; }
            else if (flags & 0x40) != 0 { sa = (double)t^.i16(q) / 16384.0; sd = (double)t^.i16(q + 2) / 16384.0; q += 4; }
            else if (flags & 0x80) != 0 {
                sa = (double)t^.i16(q) / 16384.0; sb = (double)t^.i16(q + 2) / 16384.0;
                sc = (double)t^.i16(q + 4) / 16384.0; sd = (double)t^.i16(q + 6) / 16384.0;
                q += 8;
            }
            // the part is placed by (sa..sd) and (ax, ay), then by the matrix of the parent
            double na = ma * sa + mc * sb;
            double nb = mb * sa + md * sb;
            double nc2 = ma * sc + mc * sd;
            double nd = mb * sc + md * sd;
            double ndx = ma * ax + mc * ay + dx;
            double ndy = mb * ax + md * ay + dy;
            ttf_outline(t, gi, o, na, nb, nc2, nd, ndx, ndy, depth + 1);
            more = (flags & 0x20) != 0;
        }
    }
}

// the picture of glyph g at `px` dots per em: the bitmap and its place; ok is false for a glyph with nothing to draw (a space)
bool ttf_render(Ttf^ t, int g, double px, Glyph^ out) {
    double sc = px / (double)t^.upem;
    out^.adv = (double)t^.advance(g) * sc;
    Outline o;
    o.clear();
    ttf_outline(t, g, @o, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0);
    int n = o.x.len;
    if n == 0 { o.x.free(); o.y.free(); o.on.free(); o.ends.free(); return false; }
    double minx = o.x[0]; double maxx = o.x[0]; double miny = o.y[0]; double maxy = o.y[0];
    for i in 1..n {
        if o.x[i] < minx { minx = o.x[i]; }
        if o.x[i] > maxx { maxx = o.x[i]; }
        if o.y[i] < miny { miny = o.y[i]; }
        if o.y[i] > maxy { maxy = o.y[i]; }
    }
    int left = (int)Math::floor(minx * sc) - 1;
    int right = (int)Math::floor(maxx * sc) + 2;
    int topy = (int)Math::floor(maxy * sc) + 1;           // above the baseline
    int boty = (int)Math::floor(miny * sc) - 1;           // below it (negative or small)
    int bw = right - left;
    int bh = topy - boty;
    if bw <= 0 || bh <= 0 || bw > 512 || bh > 512 { o.x.free(); o.y.free(); o.on.free(); o.ends.free(); return false; }
    Raster r;
    r.make(bw, bh);
    int start = 0;
    for ci in 0..o.ends.len {
        int e = o.ends[ci];
        int cnt = e - start + 1;
        if cnt >= 2 {
            // the start point: the first on-curve point, or the middle of the first two off-curve points
            int s0 = start;
            bool found = false;
            for k in 0..cnt {
                if !found && o.on[start + k] == 1 { s0 = start + k; found = true; }
            }
            double sx = 0.0;
            double sy = 0.0;
            int first = 0;
            if found {
                sx = o.x[s0]; sy = o.y[s0]; first = 1;
            } else {
                sx = (o.x[start] + o.x[start + 1]) / 2.0; sy = (o.y[start] + o.y[start + 1]) / 2.0;
                s0 = start + 1; first = 1;
            }
            r.move_to(sx * sc - (double)left, (double)topy - sy * sc);
            int i = 0;
            // walk the points after the start, round the contour back to the start
            double cx = 0.0;
            double cy = 0.0;
            bool havec = false;
            while i < cnt {
                int idx = start + ((s0 - start + first + i) % cnt);
                double qx = o.x[idx] * sc - (double)left;
                double qy = (double)topy - o.y[idx] * sc;
                if o.on[idx] == 1 {
                    if havec { r.quad_to(cx, cy, qx, qy); havec = false; }
                    else { r.line_to(qx, qy); }
                } else {
                    if havec {
                        double mx = (cx + qx) / 2.0;
                        double my = (cy + qy) / 2.0;
                        r.quad_to(cx, cy, mx, my);
                    }
                    cx = qx; cy = qy; havec = true;
                }
                i += 1;
            }
            // the last off-curve point curves back to the start
            if havec { r.quad_to(cx, cy, sx * sc - (double)left, (double)topy - sy * sc); }
            r.close();
        }
        start = e + 1;
    }
    out^.w = bw;
    out^.h = bh;
    out^.left = left;
    out^.top = topy;
    out^.a = arr(bw * bh);
    r.to_bytes(out^.a);
    r.acc.free();
    o.x.free(); o.y.free(); o.on.free(); o.ends.free();
    return true;
}

// ---- a small PNG writer (RGBA, no compression: the pictures of letters are small) ----
int font_crc[256];
bool font_crc_ready;

void font_crc_init() {
    for n in 0..256 {
        int c = n;
        for k in 0..8 {
            if (c & 1) != 0 { c = 0xedb88320 xor (c >> 1); } else { c = c >> 1; }
        }
        font_crc[n] = c;
    }
    font_crc_ready = true;
}

void font_be32(String s, int v) {
    s.push((char)((v >> 24) & 255)); s.push((char)((v >> 16) & 255)); s.push((char)((v >> 8) & 255)); s.push((char)(v & 255));
}

// one chunk: length, type, data, crc
void font_chunk(String png, String type, String data) {
    font_be32(png, data.len);
    png.push(type[0]); png.push(type[1]); png.push(type[2]); png.push(type[3]);
    int crc = 0xffffffff;
    for i in 0..4 { crc = font_crc[(crc xor (type[i] & 255)) & 255] xor (crc >> 8); }
    for i in 0..data.len {
        png.push(data[i]);
        crc = font_crc[(crc xor (data[i] & 255)) & 255] xor (crc >> 8);
    }
    font_be32(png, crc xor 0xffffffff);
}

// white pixels with the coverage as alpha: the colour of the text comes from the tint of the picture
bool font_write_png(String path, int w, int h, char[] alpha) {
    if !font_crc_ready { font_crc_init(); }
    String raw = "";
    for y in 0..h {
        raw.push((char)0);
        for x in 0..w {
            raw.push((char)255); raw.push((char)255); raw.push((char)255);
            raw.push(alpha[y * w + x]);
        }
    }
    // zlib: stored blocks
    String z = "";
    z.push((char)0x78); z.push((char)0x01);
    int pos = 0;
    int a = 1;
    int b = 0;
    for i in 0..raw.len {
        a = (a + (raw[i] & 255)) % 65521;
        b = (b + a) % 65521;
    }
    if raw.len == 0 { z.push((char)1); z.push((char)0); z.push((char)0); z.push((char)255); z.push((char)255); }
    while pos < raw.len {
        int n = raw.len - pos;
        if n > 65535 { n = 65535; }
        int last = 0;
        if pos + n >= raw.len { last = 1; }
        z.push((char)last);
        z.push((char)(n & 255)); z.push((char)((n >> 8) & 255));
        z.push((char)((~n) & 255)); z.push((char)(((~n) >> 8) & 255));
        for i in 0..n { z.push(raw[pos + i]); }
        pos += n;
    }
    z.push((char)((b >> 8) & 255)); z.push((char)(b & 255)); z.push((char)((a >> 8) & 255)); z.push((char)(a & 255));
    String hdr = "";
    font_be32(hdr, w); font_be32(hdr, h);
    hdr.push((char)8); hdr.push((char)6); hdr.push((char)0); hdr.push((char)0); hdr.push((char)0);
    String png = "";
    png.push((char)0x89); png.push((char)'P'); png.push((char)'N'); png.push((char)'G'); png.push((char)13); png.push((char)10); png.push((char)26); png.push((char)10);
    font_chunk(png, "IHDR", hdr);
    font_chunk(png, "IDAT", z);
    font_chunk(png, "IEND", "");
    int fd = Sys::open_write(path.c());
    if fd < 0 { return false; }
    int n2 = Sys::write(fd, (void^)png.c(), png.len);
    Sys::close(fd);
    return n2 == png.len;
}

// ---- the font: one or two files (the second one has what the first one lacks, for example Thai) ----
struct Font impl Text2d {
    Ttf a;
    Ttf b;
    bool has_b;
    String dir;                // where the pictures of the letters are kept
    int[] keys;                // the pictures that were made: face * 2^40 + size * 2^20 + glyph + 1 -> picture number
    int[] pics;
    bool ready;

    void init(self) { self.has_b = false; self.ready = false; self.dir = "."; }

    // the main font; false when the file cannot be used
    bool open(self, String path) {
        self.keys = arr(4096);
        self.pics = arr(4096);
        for i in 0..4096 { self.keys.push(0); self.pics.push(0); }
        self.ready = self.a.open(path);
        return self.ready;
    }
    // a font for the characters that the main one lacks
    bool add(self, String path) {
        self.has_b = self.b.open(path);
        return self.has_b;
    }
    // the folder for the pictures of the letters (made when it is missing)
    void cache(self, String path) {
        self.dir = path;
        Dir::make_all(path);
    }

    // the next character of a UTF-8 text at i, and its length in bytes
    static int next_cp(String s, int i, int^ len) {
        int c = s[i] & 255;
        if c < 128 { len^ = 1; return c; }
        if c >= 0xf0 && i + 3 < s.len { len^ = 4; return ((c & 7) << 18) | ((s[i + 1] & 63) << 12) | ((s[i + 2] & 63) << 6) | (s[i + 3] & 63); }
        if c >= 0xe0 && i + 2 < s.len { len^ = 3; return ((c & 15) << 12) | ((s[i + 1] & 63) << 6) | (s[i + 2] & 63); }
        if c >= 0xc0 && i + 1 < s.len { len^ = 2; return ((c & 31) << 6) | (s[i + 1] & 63); }
        len^ = 1;
        return 63;
    }

    // Thai marks that sit over the letter before them, and the tone marks that go higher when a vowel is already there
    static bool above_vowel(int cp) { return cp == 0x0e31 || (cp >= 0x0e34 && cp <= 0x0e37) || cp == 0x0e47 || cp == 0x0e4d; }
    static bool tone(int cp) { return cp >= 0x0e48 && cp <= 0x0e4c; }

    // which face (0, 1) has the character, and its glyph; (0, 0) for a character that no face has
    void pick(self, int cp, int^ face, int^ g) {
        int g0 = self.a.glyph(cp);
        if g0 != 0 { face^ = 0; g^ = g0; return; }
        if self.has_b {
            int g1 = self.b.glyph(cp);
            if g1 != 0 { face^ = 1; g^ = g1; return; }
        }
        face^ = 0;
        g^ = 0;
    }

    // the width of a text at `px` dots per em
    double width(self, String s, double px) {
        double sc = px / (double)self.a.upem;
        double x = 0.0;
        int i = 0;
        while i < s.len {
            int n = 1;
            int cp = Font::next_cp(s, i, @n);
            int face = 0;
            int g = 0;
            self.pick(cp, @face, @g);
            if face == 0 { x += (double)self.a.advance(g) * sc; }
            else { x += (double)self.b.advance(g) * (px / (double)self.b.upem); }
            i += n;
        }
        return x;
    }
    // how far the letters go above and below the line at `px` (the bigger of the faces: Thai marks are taller than Latin letters)
    double ascent(self, double px) {
        double v = (double)self.a.asc * px / (double)self.a.upem;
        if self.has_b {
            double v2 = (double)self.b.asc * px / (double)self.b.upem;
            if v2 > v { v = v2; }
        }
        return v;
    }
    double descent(self, double px) {
        double v = (double)(0 - self.a.desc) * px / (double)self.a.upem;
        if self.has_b {
            double v2 = (double)(0 - self.b.desc) * px / (double)self.b.upem;
            if v2 > v { v = v2; }
        }
        return v;
    }
    // the height of a line at `px`
    double height(self, double px) { return self.ascent(px) + self.descent(px); }

    // the interface of <canvas2d> (u.font(@f, 28.0) in <ui>)
    double text_width(self, String s, double px) { return self.width(s, px); }
    double text_height(self, double px) { return self.height(px); }
    double text_draw(self, Canvas2d^ c, double x, double y, String s, double px, int color) { return self.draw(c, x, y, s, px, color); }

    // the picture number of a glyph at a size: from the memory, else from the cache folder, else made now; -1 when it has nothing to draw
    int picture(self, Canvas2d^ c, int face, int g, int ipx, Glyph^ gl) {
        int key = face * 1099511627776 + ipx * 1048576 + g + 1;
        int h = (key * 2654435761) & 4095;
        int tries = 0;
        while self.keys[h] != 0 && tries < 4096 {
            if self.keys[h] == key { gl^.w = 0; return self.pics[h]; }
            h = (h + 1) & 4095;
            tries += 1;
        }
        String path = self.dir + "/f" + str(face) + "_" + str(ipx) + "_" + str(g) + ".png";
        bool made = false;
        int pic = -1;
        if face == 0 { made = ttf_render(@self.a, g, (double)ipx, gl); } else { made = ttf_render(@self.b, g, (double)ipx, gl); }
        if made {
            if !Fs::exists(path) { font_write_png(path, gl^.w, gl^.h, gl^.a); }
            pic = c^.load(path);
            gl^.a.free();
        }
        if tries < 4096 { self.keys[h] = key; self.pics[h] = pic; }
        return pic;
    }

    // draws the text with its top at y and the pen at x; returns the x after the last letter
    double draw(self, Canvas2d^ c, double x, double y, String s, double px, int color) {
        int ipx = (int)(px + 0.5);
        double sc = (double)ipx / (double)self.a.upem;
        double base = y + self.ascent((double)ipx);
        double pen = x;
        int prev = 0;
        int i = 0;
        while i < s.len {
            int n = 1;
            int cp = Font::next_cp(s, i, @n);
            int face = 0;
            int g = 0;
            self.pick(cp, @face, @g);
            Glyph gl;
            int pic = self.picture(c, face, g, ipx, @gl);
            double fsc = sc;
            if face == 1 { fsc = (double)ipx / (double)self.b.upem; }
            // the size and the place of the picture (a cached picture has no Glyph data: it is measured again, cheaply, from the file of the first time)
            if pic >= 0 {
                if gl.w == 0 { self.measure(face, g, ipx, @gl); }
                double lift = 0.0;
                if Font::tone(cp) && Font::above_vowel(prev) { lift = (double)ipx * 0.28; }
                c^.image(pic, pen + (double)gl.left, base - (double)gl.top - lift, (double)gl.w, (double)gl.h, color);
            }
            double adv = 0.0;
            if face == 0 { adv = (double)self.a.advance(g) * fsc; } else { adv = (double)self.b.advance(g) * fsc; }
            pen += adv;
            prev = cp;
            i += n;
        }
        return pen;
    }

    // the box of a glyph (without the pixels): the same numbers as ttf_render, for a picture that is already made
    void measure(self, int face, int g, int ipx, Glyph^ gl) {
        if face == 0 { ttf_render(@self.a, g, (double)ipx, gl); } else { ttf_render(@self.b, g, (double)ipx, gl); }
        gl^.a.free();
    }
}
