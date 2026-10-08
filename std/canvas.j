// Canvas: a grid of characters to draw on, with a depth buffer (the nearest thing drawn in a place wins).
//   #import <gfx>   using gfx::canvas;
//   Canvas c = Canvas::make(100, 37);
//   c.clear();   c.ball(p, 2.0, ".:-=+*#%@");   c.plot(q, 'E');   c.text(2, 1, "hello");   c.show();
// Points are vec3: x to the right, y down, z away from the viewer; plot() looks at them in perspective.
struct Canvas {
    int w;
    int h;
    double view;                 // the distance of the eye: bigger = flatter (default 60)
    double wide;                 // a character is about twice as high as wide: x is scaled by this (default 2)
    char[] cells;
    double[] depth;
    static Canvas make(int w, int h) {
        Canvas c;
        c.w = w;
        c.h = h;
        c.view = 60.0;
        c.wide = 2.0;
        c.cells = arr(w * h);
        c.cells.resize(w * h);
        c.depth = arr(w * h);
        c.depth.resize(w * h);
        c.clear();
        return c;
    }
    void free(self) {
        self.cells.free();
        self.depth.free();
    }
    // empties the canvas
    void clear(self) {
        for i in 0..self.w * self.h {
            self.cells[i] = ' ';
            self.depth[i] = 1.0e9;
        }
    }
    // a character in a place of the grid (no depth)
    void put(self, int x, int y, char c) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return; }
        self.cells[y * self.w + x] = c;
    }
    char get(self, int x, int y) {
        if x < 0 || x >= self.w || y < 0 || y >= self.h { return ' '; }
        return self.cells[y * self.w + x];
    }
    // text from (x, y) to the right
    void text(self, int x, int y, String s) {
        for i in 0..s.len { self.put(x + i, y, s[i]); }
    }
    // a point in 3D (the middle of the canvas is x = 0, y = 0)
    void plot(self, vec3 p, char c) {
        double persp = self.view / (self.view + p.z);
        int sx = (int)((double)self.w / 2.0 + p.x * persp * self.wide);
        int sy = (int)((double)self.h / 2.0 + p.y * persp);
        if sx < 0 || sx >= self.w || sy < 0 || sy >= self.h { return; }
        int at = sy * self.w + sx;
        if p.z < self.depth[at] {
            self.depth[at] = p.z;
            self.cells[at] = c;
        }
    }
    // a line of points from a to b
    void line(self, vec3 a, vec3 b, char c) {
        vec3 d = b - a;
        int n = (int)(d.length() * 2.0) + 1;
        for i in 0..n + 1 {
            vec3 q = a + d * ((double)i / (double)n);
            self.plot(q, c);
        }
    }
    // a ball of radius r (in rows), lit from the upper left: the brighter, the later in ramp
    void ball(self, vec3 p, double r, String ramp) {
        int n = ramp.len;
        double dy = 0.0 - r;
        while dy <= r {
            double dx = 0.0 - r * self.wide;
            while dx <= r * self.wide {
                double nx = dx / (r * self.wide);
                double ny = dy / r;
                double d2 = nx * nx + ny * ny;
                if d2 <= 1.0 {
                    double nz = Math::sqrt(1.0 - d2);
                    vec3 normal = {nx, ny, nz};
                    vec3 light = {-0.5, -0.5, 0.7};
                    double lit = Math::max(normal.dot(light), 0.0);
                    int k = (int)(lit * (double)(n - 1));
                    if k > n - 1 { k = n - 1; }
                    vec3 q = {p.x + dx / self.wide, p.y + dy, p.z - nz};
                    self.plot(q, ramp[k]);
                }
                dx += 0.5;
            }
            dy += 0.5;
        }
    }
    // the whole picture as text, starting with "back to the top left" (so that frames overwrite each other)
    String frame(self) {
        String out = "";
        out.push((char)27);
        out.append("[H");
        for y in 0..self.h {
            for x in 0..self.w { out.push(self.cells[y * self.w + x]); }
            out.push((char)10);
        }
        return out;
    }
    // clears the screen once (call it before the first show)
    void clear_screen(self) {
        String s = "";
        s.push((char)27);
        s.append("[2J");
        cout << s;
    }
    void show(self) {
        cout << self.frame();
    }
}
