// phys2d 0.1.0 -- a body that falls and walks in a world of tiles, and a camera that follows it.   #import <tilemap>  #import <phys2d>   (needs jcmp 1.2.1.0; license: MPL-2.0)
//   Body b = Body::make(50.0, 0.0, 8.0, 16.0);        // x, y, width, height in dots (the top left corner)
//   b.vx = 120.0;  b.jump(300.0);                       // speed in dots a second; jump() gives an upward speed when the body stands on something
//   b.step(world, 0, 16, 99, 1.0 / 60.0, 900.0);       // the tile layer 0; tiles are 16 dots; the numbers 1..99 are solid; dt in seconds; gravity in dots a second a second
//   b.on_ground, b.hit_x, b.hit_y tell what it touched in the last step.
//   Camera c = Camera::make(320, 180);   c.follow(b.x, b.y, 0.15);   c.limit(2000 * 16, 600 * 16);   int sx = c.screen_x(wx); int sy = c.screen_y(wy);
// The body is moved one axis at a time and put against the tile it meets (no passing through at speeds below one tile in a step).

// the whole number below or equal (the cast cuts towards zero)
int p2d_floor(double v) {
    int i = (int)v;
    if (double)i > v { i -= 1; }
    return i;
}

struct Body {
    double x;
    double y;
    double w;
    double h;
    double vx;
    double vy;
    bool on_ground;
    bool hit_x;
    bool hit_y;

    static Body make(double x, double y, double w, double h) {
        Body b;
        b.x = x;
        b.y = y;
        b.w = w;
        b.h = h;
        b.vx = 0.0;
        b.vy = 0.0;
        b.on_ground = false;
        b.hit_x = false;
        b.hit_y = false;
        return b;
    }

    // is there a solid tile in the world where the box (bx, by, bw, bh) is
    static bool blocked(TileMap m, int layer, int ts, int solid_max, double bx, double by, double bw, double bh) {
        int x0 = p2d_floor(bx / (double)ts);
        int y0 = p2d_floor(by / (double)ts);
        int x1 = p2d_floor((bx + bw - 0.001) / (double)ts);
        int y1 = p2d_floor((by + bh - 0.001) / (double)ts);
        for ty in y0..(y1 + 1) {
            for tx in x0..(x1 + 1) {
                int t = m.get(layer, tx, ty);
                if t >= 1 && t <= solid_max { return true; }
                if tx < 0 || tx >= m.w { return true; }                  // the edges of the world are walls and the floor
                if ty >= m.h { return true; }
            }
        }
        return false;
    }

    void jump(self, double speed) {
        if self.on_ground { self.vy = 0.0 - speed; }
    }

    void step(self, TileMap m, int layer, int ts, int solid_max, double dt, double gravity) {
        self.vy = self.vy + gravity * dt;
        self.hit_x = false;
        self.hit_y = false;
        // sideways
        double nx = self.x + self.vx * dt;
        if Body::blocked(m, layer, ts, solid_max, nx, self.y, self.w, self.h) {
            self.hit_x = true;
            if self.vx > 0.0 {
                double edge = (double)(p2d_floor((nx + self.w) / (double)ts) * ts);
                nx = edge - self.w - 0.002;
            } else if self.vx < 0.0 {
                double edge2 = (double)((p2d_floor(nx / (double)ts) + 1) * ts);
                nx = edge2 + 0.002;
            }
            self.vx = 0.0;
        }
        self.x = nx;
        // up and down
        double ny = self.y + self.vy * dt;
        self.on_ground = false;
        if Body::blocked(m, layer, ts, solid_max, self.x, ny, self.w, self.h) {
            self.hit_y = true;
            if self.vy > 0.0 {
                double floor_y = (double)(p2d_floor((ny + self.h) / (double)ts) * ts);
                ny = floor_y - self.h - 0.002;
                self.on_ground = true;
            } else if self.vy < 0.0 {
                double ceil_y = (double)((p2d_floor(ny / (double)ts) + 1) * ts);
                ny = ceil_y + 0.002;
            }
            self.vy = 0.0;
        }
        self.y = ny;
    }
}

struct Camera {
    double x;                         // the top left corner of what is seen, in the dots of the world
    double y;
    int vw;                           // the size of the view in dots of the screen
    int vh;
    double max_x;
    double max_y;

    static Camera make(int vw, int vh) {
        Camera c;
        c.x = 0.0;
        c.y = 0.0;
        c.vw = vw;
        c.vh = vh;
        c.max_x = 1000000000.0;
        c.max_y = 1000000000.0;
        return c;
    }

    // the world is this big: the camera does not show beyond it
    void limit(self, int world_w, int world_h) {
        self.max_x = (double)(world_w - self.vw);
        self.max_y = (double)(world_h - self.vh);
        if self.max_x < 0.0 { self.max_x = 0.0; }
        if self.max_y < 0.0 { self.max_y = 0.0; }
    }

    // goes toward the point that is in the middle of the view: smooth = the part of the way in one call (1.0 at once, 0.1 slowly)
    void follow(self, double tx, double ty, double smooth) {
        double gx = tx - (double)self.vw / 2.0;
        double gy = ty - (double)self.vh / 2.0;
        self.x = self.x + (gx - self.x) * smooth;
        self.y = self.y + (gy - self.y) * smooth;
        if self.x < 0.0 { self.x = 0.0; }
        if self.y < 0.0 { self.y = 0.0; }
        if self.x > self.max_x { self.x = self.max_x; }
        if self.y > self.max_y { self.y = self.max_y; }
    }

    int screen_x(self, double wx) { return (int)(wx - self.x); }
    int screen_y(self, double wy) { return (int)(wy - self.y); }
    double world_x(self, int sx) { return (double)sx + self.x; }
    double world_y(self, int sy) { return (double)sy + self.y; }
}
