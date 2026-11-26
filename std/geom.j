// geom 0.1.0 -- shapes that touch: boxes, circles, segments, rays and polygons (for games, physics, pickers).   #import <geom>   (license: MPL-2.0)
//   bool hit = Geom::rect_hit(ax, ay, aw, ah, bx, by, bw, bh);            // two boxes (x, y = the top left corner; y grows downwards)
//   Push p = Geom::rect_push(ax, ay, aw, ah, bx, by, bw, bh);             // how far box a must move to leave box b: p.hit, p.x, p.y (the shorter way)
//   double t = Geom::ray_rect(ox, oy, dx, dy, rx, ry, rw, rh);            // from (ox, oy) in the direction (dx, dy): the distance in lengths of d, or -1
//   bool in = Geom::point_in_polygon(px, py, xs, ys, n);                  // any polygon: xs and ys are arrays of doubles (a shape that crosses itself too)
// Everything is plain numbers (doubles), so it works with any picture or world. Touching edges count as a hit.

struct Push {
    bool hit;
    double x;          // the move that takes the first shape out of the second (0, 0 when they do not touch)
    double y;
}

struct Geom {
    static double sqr(double v) { return v * v; }
    static double dist(double x0, double y0, double x1, double y1) { return Math::sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)); }

    static bool point_in_rect(double px, double py, double rx, double ry, double rw, double rh) {
        return px >= rx && px <= rx + rw && py >= ry && py <= ry + rh;
    }

    static bool point_in_circle(double px, double py, double cx, double cy, double r) {
        return (px - cx) * (px - cx) + (py - cy) * (py - cy) <= r * r;
    }

    static bool rect_hit(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh) {
        return ax <= bx + bw && bx <= ax + aw && ay <= by + bh && by <= ay + ah;
    }

    static bool circle_hit(double ax, double ay, double ar, double bx, double by, double br) {
        double r = ar + br;
        return (bx - ax) * (bx - ax) + (by - ay) * (by - ay) <= r * r;
    }

    // a circle and a box: the point of the box that is nearest to the centre decides
    static bool circle_rect(double cx, double cy, double r, double rx, double ry, double rw, double rh) {
        double nx = Math::clamp(cx, rx, rx + rw);
        double ny = Math::clamp(cy, ry, ry + rh);
        return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) <= r * r;
    }

    // the shorter move that takes box a out of box b (along x or along y)
    static Push rect_push(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh) {
        Push p;
        p.hit = false;
        p.x = 0.0;
        p.y = 0.0;
        if !Geom::rect_hit(ax, ay, aw, ah, bx, by, bw, bh) { return p; }
        double left = (bx - (ax + aw));            // move left (negative)
        double right = (bx + bw) - ax;             // move right
        double up = (by - (ay + ah));
        double down = (by + bh) - ay;
        double mx = left;
        if Math::abs(right) < Math::abs(mx) { mx = right; }
        double my = up;
        if Math::abs(down) < Math::abs(my) { my = down; }
        p.hit = true;
        if Math::abs(mx) <= Math::abs(my) { p.x = mx; } else { p.y = my; }
        return p;
    }

    // the distance from a point to a segment (the nearest point of the segment)
    static double dist_point_segment(double px, double py, double x0, double y0, double x1, double y1) {
        double dx = x1 - x0;
        double dy = y1 - y0;
        double len2 = dx * dx + dy * dy;
        double t = 0.0;
        if len2 > 0.0 { t = Math::clamp(((px - x0) * dx + (py - y0) * dy) / len2, 0.0, 1.0); }
        return Geom::dist(px, py, x0 + t * dx, y0 + t * dy);
    }

    // do two segments cross? (the end of one on the other counts)
    static bool segments_hit(double ax, double ay, double bx, double by, double cx, double cy, double dx, double dy) {
        double d1 = Geom::cross(cx, cy, dx, dy, ax, ay);
        double d2 = Geom::cross(cx, cy, dx, dy, bx, by);
        double d3 = Geom::cross(ax, ay, bx, by, cx, cy);
        double d4 = Geom::cross(ax, ay, bx, by, dx, dy);
        if ((d1 > 0.0 && d2 < 0.0) || (d1 < 0.0 && d2 > 0.0)) && ((d3 > 0.0 && d4 < 0.0) || (d3 < 0.0 && d4 > 0.0)) { return true; }
        if d1 == 0.0 && Geom::on_segment(cx, cy, dx, dy, ax, ay) { return true; }
        if d2 == 0.0 && Geom::on_segment(cx, cy, dx, dy, bx, by) { return true; }
        if d3 == 0.0 && Geom::on_segment(ax, ay, bx, by, cx, cy) { return true; }
        if d4 == 0.0 && Geom::on_segment(ax, ay, bx, by, dx, dy) { return true; }
        return false;
    }

    // the cross product of (p1 - p0) and (q - p0): its sign says on which side of the line p0 p1 the point q is
    static double cross(double x0, double y0, double x1, double y1, double qx, double qy) {
        return (x1 - x0) * (qy - y0) - (y1 - y0) * (qx - x0);
    }

    static bool on_segment(double x0, double y0, double x1, double y1, double px, double py) {
        return px >= Math::min(x0, x1) && px <= Math::max(x0, x1) && py >= Math::min(y0, y1) && py <= Math::max(y0, y1);
    }

    // a ray against a box: the distance along the ray, in lengths of (dx, dy), where it enters the box (0 when it starts inside), or -1 when it misses
    static double ray_rect(double ox, double oy, double dx, double dy, double rx, double ry, double rw, double rh) {
        double tmin = 0.0;
        double tmax = 1.0e30;
        for axis in 0..2 {
            double o = ox;
            double d = dx;
            double lo = rx;
            double hi = rx + rw;
            if axis == 1 { o = oy; d = dy; lo = ry; hi = ry + rh; }
            if Math::abs(d) < 1.0e-12 {
                if o < lo || o > hi { return -1.0; }
            } else {
                double t1 = (lo - o) / d;
                double t2 = (hi - o) / d;
                if t1 > t2 { double tmp = t1; t1 = t2; t2 = tmp; }
                if t1 > tmin { tmin = t1; }
                if t2 < tmax { tmax = t2; }
                if tmin > tmax { return -1.0; }
            }
        }
        return tmin;
    }

    // a ray against a circle: the distance along the ray where it enters (0 when it starts inside), or -1
    static double ray_circle(double ox, double oy, double dx, double dy, double cx, double cy, double r) {
        double fx = ox - cx;
        double fy = oy - cy;
        double a = dx * dx + dy * dy;
        double b = 2.0 * (fx * dx + fy * dy);
        double c = fx * fx + fy * fy - r * r;
        if c <= 0.0 { return 0.0; }
        double disc = b * b - 4.0 * a * c;
        if a == 0.0 || disc < 0.0 { return -1.0; }
        double t = (0.0 - b - Math::sqrt(disc)) / (2.0 * a);
        if t < 0.0 { return -1.0; }
        return t;
    }

    // a point in any polygon (even-odd rule): the points are (xs[i], ys[i]) for i in 0..n
    static bool point_in_polygon(double px, double py, double^ xs, double^ ys, i64 n) {
        bool inside = false;
        i64 j = n - 1;
        for i in 0..n {
            if (ys[i] > py) != (ys[j] > py) {
                double x = (xs[j] - xs[i]) * (py - ys[i]) / (ys[j] - ys[i]) + xs[i];
                if px < x { inside = !inside; }
            }
            j = i;
        }
        return inside;
    }

    // the area of a polygon (positive when the points go the usual way round, negative the other way)
    static double polygon_area(double^ xs, double^ ys, i64 n) {
        double a = 0.0;
        i64 j = n - 1;
        for i in 0..n {
            a += (xs[j] + xs[i]) * (ys[j] - ys[i]);
            j = i;
        }
        return a / 2.0;
    }
}
