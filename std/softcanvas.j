// softcanvas 0.1.0 -- a Canvas2d that draws into memory (no screen, no GPU): for tests of screens, for pictures of an interface
// (save_ppm) and for apps that need a bitmap. Edges are smooth (coverage of a pixel), colours are 0xAARRGGBB and are blended over what is there.
// load() and image() work too (a PNG file; for the pictures of <font>).
//   SoftCanvas sc;  sc.make(400, 800);  Ui u;  u.start();  ...  u.begin(@sc, 400.0, 800.0); ... u.end();   sc.save_ppm("shot.ppm");
// It implements the same interface as GlCanvas, so any code written for <canvas2d> draws here. License: MPL-2.0.
#import <canvas2d>
#import <deflate>
#import <png>

struct SoftCanvas impl Canvas2d {
    int w;
    int h;
    int[] px;                    // w * h pixels, 0xFFRRGGBB
    int[] iw;                    // the pictures that load() made: width, height and the bytes (red, green, blue, alpha)
    int[] ih;
    String[] ipx;

    void init(self) { self.w = 0; self.h = 0; }

    void make(self, int width, int height) {
        self.w = width;
        self.h = height;
        self.px = arr(width * height);
        self.iw = arr(16);
        self.ih = arr(16);
        self.ipx = arr(16);
        for i in 0..width * height { self.px.push(0xff000000); }
    }

    // blend the colour argb over the pixel (x, y); cov (0..1) scales the alpha (the part of the pixel that is covered)
    void put(self, int x, int y, int argb, double cov) {
        if x < 0 || y < 0 || x >= self.w || y >= self.h { return; }
        double al = (double)((argb >> 24) & 255) / 255.0 * cov;
        if al <= 0.0 { return; }
        int i = y * self.w + x;
        int d = self.px[i];
        double inv = 1.0 - al;
        int r = (int)((double)((argb >> 16) & 255) * al + (double)((d >> 16) & 255) * inv + 0.5);
        int g = (int)((double)((argb >> 8) & 255) * al + (double)((d >> 8) & 255) * inv + 0.5);
        int b = (int)((double)(argb & 255) * al + (double)(d & 255) * inv + 0.5);
        self.px[i] = 0xff000000 | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255);
    }

    void begin(self) { }
    void end(self) { }
    void clear(self, int argb) {
        int c = 0xff000000 | (argb & 0xffffff);
        for i in 0..self.w * self.h { self.px[i] = c; }
    }

    void rect(self, double x, double y, double rw, double rh, int argb) {
        int x0 = (int)x;
        if (double)x0 > x { x0 -= 1; }
        int y0 = (int)y;
        if (double)y0 > y { y0 -= 1; }
        int x1 = (int)(x + rw);
        if (double)x1 < x + rw { x1 += 1; }
        int y1 = (int)(y + rh);
        if (double)y1 < y + rh { y1 += 1; }
        if x0 < 0 { x0 = 0; }
        if y0 < 0 { y0 = 0; }
        if x1 > self.w { x1 = self.w; }
        if y1 > self.h { y1 = self.h; }
        for py in y0..y1 {
            double oy = (double)(py + 1);
            if y + rh < oy { oy = y + rh; }
            double sy = (double)py;
            if y > sy { sy = y; }
            double cy = oy - sy;
            if cy <= 0.0 { continue; }
            for pxl in x0..x1 {
                double ox = (double)(pxl + 1);
                if x + rw < ox { ox = x + rw; }
                double sx = (double)pxl;
                if x > sx { sx = x; }
                double cx = ox - sx;
                if cx > 0.0 { self.put(pxl, py, argb, cx * cy); }
            }
        }
    }

    // the coverage (0..1) of the pixel by a triangle: 3 x 3 samples
    double tri_cov(self, int px0, int py0, double ax, double ay, double bx, double by, double cx, double cy) {
        int n = 0;
        for sy in 0..3 {
            for sx in 0..3 {
                double qx = (double)px0 + ((double)sx + 0.5) / 3.0;
                double qy = (double)py0 + ((double)sy + 0.5) / 3.0;
                double d1 = (qx - bx) * (ay - by) - (ax - bx) * (qy - by);
                double d2 = (qx - cx) * (by - cy) - (bx - cx) * (qy - cy);
                double d3 = (qx - ax) * (cy - ay) - (cx - ax) * (qy - ay);
                bool neg = d1 < 0.0 || d2 < 0.0 || d3 < 0.0;
                bool pos = d1 > 0.0 || d2 > 0.0 || d3 > 0.0;
                if !(neg && pos) { n += 1; }
            }
        }
        return (double)n / 9.0;
    }

    void tri(self, double x0, double y0, double x1, double y1, double x2, double y2, int argb) {
        double minx = x0; if x1 < minx { minx = x1; } if x2 < minx { minx = x2; }
        double maxx = x0; if x1 > maxx { maxx = x1; } if x2 > maxx { maxx = x2; }
        double miny = y0; if y1 < miny { miny = y1; } if y2 < miny { miny = y2; }
        double maxy = y0; if y1 > maxy { maxy = y1; } if y2 > maxy { maxy = y2; }
        int ix0 = (int)minx - 1; if ix0 < 0 { ix0 = 0; }
        int iy0 = (int)miny - 1; if iy0 < 0 { iy0 = 0; }
        int ix1 = (int)maxx + 2; if ix1 > self.w { ix1 = self.w; }
        int iy1 = (int)maxy + 2; if iy1 > self.h { iy1 = self.h; }
        for py in iy0..iy1 {
            for pxl in ix0..ix1 {
                double cv = self.tri_cov(pxl, py, x0, y0, x1, y1, x2, y2);
                if cv > 0.0 { self.put(pxl, py, argb, cv); }
            }
        }
    }

    void line(self, double x0, double y0, double x1, double y1, double width, int argb) {
        double hw = width / 2.0;
        double minx = x0; if x1 < minx { minx = x1; }
        double maxx = x0; if x1 > maxx { maxx = x1; }
        double miny = y0; if y1 < miny { miny = y1; }
        double maxy = y0; if y1 > maxy { maxy = y1; }
        int ix0 = (int)(minx - hw) - 1; if ix0 < 0 { ix0 = 0; }
        int iy0 = (int)(miny - hw) - 1; if iy0 < 0 { iy0 = 0; }
        int ix1 = (int)(maxx + hw) + 2; if ix1 > self.w { ix1 = self.w; }
        int iy1 = (int)(maxy + hw) + 2; if iy1 > self.h { iy1 = self.h; }
        double dx = x1 - x0;
        double dy = y1 - y0;
        double len2 = dx * dx + dy * dy;
        for py in iy0..iy1 {
            for pxl in ix0..ix1 {
                double qx = (double)pxl + 0.5;
                double qy = (double)py + 0.5;
                double t = 0.0;
                if len2 > 0.0 { t = ((qx - x0) * dx + (qy - y0) * dy) / len2; }
                if t < 0.0 { t = 0.0; }
                if t > 1.0 { t = 1.0; }
                double ex = qx - (x0 + t * dx);
                double ey = qy - (y0 + t * dy);
                double dist = Math::sqrt(ex * ex + ey * ey);
                double cv = hw - dist + 0.5;
                if cv > 1.0 { cv = 1.0; }
                if cv > 0.0 { self.put(pxl, py, argb, cv); }
            }
        }
    }

    void circle(self, double cx, double cy, double r, int argb) {
        int ix0 = (int)(cx - r) - 1; if ix0 < 0 { ix0 = 0; }
        int iy0 = (int)(cy - r) - 1; if iy0 < 0 { iy0 = 0; }
        int ix1 = (int)(cx + r) + 2; if ix1 > self.w { ix1 = self.w; }
        int iy1 = (int)(cy + r) + 2; if iy1 > self.h { iy1 = self.h; }
        for py in iy0..iy1 {
            for pxl in ix0..ix1 {
                double ex = (double)pxl + 0.5 - cx;
                double ey = (double)py + 0.5 - cy;
                double cv = r - Math::sqrt(ex * ex + ey * ey) + 0.5;
                if cv > 1.0 { cv = 1.0; }
                if cv > 0.0 { self.put(pxl, py, argb, cv); }
            }
        }
    }

    bool has_instancing(self) { return false; }
    bool has_shaders(self) { return false; }
    // a PNG file becomes a picture number (-1: not loaded)
    int load(self, String path) {
        Result<String, Error> r = Fs::read_bytes(path);
        if r.is_err() { return -1; }
        bool ok = false;
        Image im = Png::decode(r.unwrap(), @ok);
        if !ok { return -1; }
        self.iw.push(im.w);
        self.ih.push(im.h);
        self.ipx.push(im.px);
        return self.iw.len - 1;
    }

    // one channel (0 red .. 3 alpha) of the picture at the point (u, v) in its own dots, with a smooth mix of the four dots round it
    double sample(self, int pic, double u, double v, int ch) {
        int w0 = self.iw[pic];
        int h0 = self.ih[pic];
        double fu = u - 0.5;
        double fv = v - 0.5;
        int x0 = (int)Math::floor(fu);
        int y0 = (int)Math::floor(fv);
        double tx = fu - (double)x0;
        double ty = fv - (double)y0;
        double acc = 0.0;
        for dy in 0..2 {
            for dx in 0..2 {
                int xx = x0 + dx;
                int yy = y0 + dy;
                double wgt = 1.0;
                if dx == 0 { wgt = 1.0 - tx; } else { wgt = tx; }
                if dy == 0 { wgt = wgt * (1.0 - ty); } else { wgt = wgt * ty; }
                if xx >= 0 && yy >= 0 && xx < w0 && yy < h0 {
                    acc += wgt * (double)(self.ipx[pic][(yy * w0 + xx) * 4 + ch] & 255);
                }
            }
        }
        return acc;
    }

    // the picture in the box (x, y, bw, bh), multiplied by the tint
    void image(self, int pic, double x, double y, double bw, double bh, int tint) {
        if pic < 0 || pic >= self.iw.len || bw <= 0.0 || bh <= 0.0 { return; }
        int ix0 = (int)Math::floor(x); if ix0 < 0 { ix0 = 0; }
        int iy0 = (int)Math::floor(y); if iy0 < 0 { iy0 = 0; }
        int ix1 = (int)Math::ceil(x + bw); if ix1 > self.w { ix1 = self.w; }
        int iy1 = (int)Math::ceil(y + bh); if iy1 > self.h { iy1 = self.h; }
        double kx = (double)self.iw[pic] / bw;
        double ky = (double)self.ih[pic] / bh;
        double tr = (double)((tint >> 16) & 255) / 255.0;
        double tg = (double)((tint >> 8) & 255) / 255.0;
        double tb = (double)(tint & 255) / 255.0;
        double ta = (double)((tint >> 24) & 255) / 255.0;
        for py in iy0..iy1 {
            for pxl in ix0..ix1 {
                double u = ((double)pxl + 0.5 - x) * kx;
                double v = ((double)py + 0.5 - y) * ky;
                double a = self.sample(pic, u, v, 3) / 255.0 * ta;
                if a > 0.0 {
                    int r = (int)(self.sample(pic, u, v, 0) * tr + 0.5);
                    int g = (int)(self.sample(pic, u, v, 1) * tg + 0.5);
                    int b = (int)(self.sample(pic, u, v, 2) * tb + 0.5);
                    int col = (255 << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255);
                    self.put(pxl, py, col, a);
                }
            }
        }
    }

    // the colour of a pixel (0xFFRRGGBB), or 0 outside
    int get(self, int x, int y) {
        if x < 0 || y < 0 || x >= self.w || y >= self.h { return 0; }
        return self.px[y * self.w + x];
    }

    // a binary PPM file (P6, width up to 4096); any viewer or `convert` makes a PNG of it. Returns true when the file was written.
    bool save_ppm(self, String path) {
        int fd = Sys::open_write(path.c());
        if fd < 0 { return false; }
        String head = "P6\n" + str(self.w) + " " + str(self.h) + "\n255\n";
        Sys::write(fd, (void^)head.c(), head.len);
        if self.w > 4096 { Sys::close(fd); return false; }
        char row[12288];
        for y in 0..self.h {
            int n = 0;
            for x in 0..self.w {
                int c = self.px[y * self.w + x];
                row[n] = (char)((c >> 16) & 255);
                row[n + 1] = (char)((c >> 8) & 255);
                row[n + 2] = (char)(c & 255);
                n += 3;
            }
            Sys::write(fd, (void^)@row, n);
        }
        Sys::close(fd);
        return true;
    }
}
