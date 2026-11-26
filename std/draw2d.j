// draw2d 0.1.0 -- more shapes over any Canvas2d (OpenGL, memory, terminal ...): ellipses, rounded boxes, rings, arcs, curves, polygons, gradients, outlines.
//   #import <canvas2d>  #import <draw2d>        (license: MPL-2.0)
//   draw_ellipse(c, cx, cy, rx, ry, colour);            draw_rrect(c, x, y, w, h, radius, colour);        draw_ring(c, cx, cy, r_in, r_out, colour);
//   draw_arc(c, cx, cy, r, from_rad, to_rad, width, colour);   draw_bezier(c, x0, y0, x1, y1, x2, y2, x3, y3, width, colour);
//   draw_polygon(c, xs, ys, n, colour)   (convex: the points go round the shape);   draw_gradient_h / draw_gradient_v(c, x, y, w, h, from, to);
//   draw_gradient_radial(c, cx, cy, r, centre_colour, edge_colour);   draw_rect_stroke(c, x, y, w, h, line_width, colour);   draw_mix(from, to, t)
// Everything is made of the triangles, lines and boxes of Canvas2d, so it works on every backend. Colours are 0xAARRGGBB. An opaque colour has no seams;
// a see-through colour may show faint lines where two triangles meet (the gradients are made for opaque colours).

double draw_pi() { return 3.141592653589793; }

// the colour between two colours: t = 0 gives a, t = 1 gives b (every channel, alpha too)
i64 draw_mix(i64 a, i64 b, double t) {
    if t < 0.0 { t = 0.0; }
    if t > 1.0 { t = 1.0; }
    i64 out = 0;
    for sh in 0..4 {
        i64 s = sh * 8;
        double ca = (double)((a >> s) & 255);
        double cb = (double)((b >> s) & 255);
        i64 v = (i64)(ca + (cb - ca) * t + 0.5);
        out = out | ((v & 255) << s);
    }
    return out;
}

// how many sides make a round shape of this radius look round
i64 draw_sides(double r) {
    i64 n = (i64)(r * 1.5) + 12;
    if n > 120 { n = 120; }
    return n;
}

// a piece of a filled ellipse (a fan of triangles from the centre) from angle a0 to a1; an opaque colour overlaps a little so that no seam shows
void draw_fan(Canvas2d^ c, double cx, double cy, double rx, double ry, double a0, double a1, i64 argb) {
    double r = rx;
    if ry > r { r = ry; }
    i64 n = (i64)((a1 - a0) / (2.0 * draw_pi()) * (double)draw_sides(r)) + 1;
    double eps = 0.0;
    if ((argb >> 24) & 255) == 255 { eps = 1.2 / (r + 1.0); }
    double step = (a1 - a0) / (double)n;
    for i in 0..n {
        double s = a0 + step * (double)i;
        double e = s + step + eps;
        c^.tri(cx, cy, cx + rx * Math::cos(s), cy + ry * Math::sin(s), cx + rx * Math::cos(e), cy + ry * Math::sin(e), argb);
    }
}

void draw_ellipse(Canvas2d^ c, double cx, double cy, double rx, double ry, i64 argb) {
    draw_fan(c, cx, cy, rx, ry, 0.0, 2.0 * draw_pi(), argb);
    if ((argb >> 24) & 255) == 255 { c^.rect(cx - rx * 0.6, cy - ry * 0.6, rx * 1.2, ry * 1.2, argb); }      // the middle, where the points of the triangles meet
}

// a box with round corners (radius is cut to half of the shorter side)
void draw_rrect(Canvas2d^ c, double x, double y, double w, double h, double radius, i64 argb) {
    double r = radius;
    double m = w;
    if h < m { m = h; }
    if r > m / 2.0 { r = m / 2.0; }
    if r <= 0.0 { c^.rect(x, y, w, h, argb); return; }
    c^.rect(x + r, y, w - 2.0 * r, h, argb);
    c^.rect(x, y + r, r, h - 2.0 * r, argb);
    c^.rect(x + w - r, y + r, r, h - 2.0 * r, argb);
    double pi = draw_pi();
    draw_fan(c, x + r, y + r, r, r, pi, 1.5 * pi, argb);
    draw_fan(c, x + w - r, y + r, r, r, 1.5 * pi, 2.0 * pi, argb);
    draw_fan(c, x + w - r, y + h - r, r, r, 0.0, 0.5 * pi, argb);
    draw_fan(c, x + r, y + h - r, r, r, 0.5 * pi, pi, argb);
}

// a ring: the part between two circles
void draw_ring(Canvas2d^ c, double cx, double cy, double r_in, double r_out, i64 argb) {
    i64 n = draw_sides(r_out);
    double step = 2.0 * draw_pi() / (double)n;
    double eps = 0.0;
    if ((argb >> 24) & 255) == 255 { eps = 1.2 / (r_out + 1.0); }
    for i in 0..n {
        double s = step * (double)i;
        double e = s + step + eps;
        double x0 = cx + r_in * Math::cos(s);
        double y0 = cy + r_in * Math::sin(s);
        double x1 = cx + r_out * Math::cos(s);
        double y1 = cy + r_out * Math::sin(s);
        double x2 = cx + r_out * Math::cos(e);
        double y2 = cy + r_out * Math::sin(e);
        double x3 = cx + r_in * Math::cos(e);
        double y3 = cy + r_in * Math::sin(e);
        c^.tri(x0, y0, x1, y1, x2, y2, argb);
        c^.tri(x0, y0, x2, y2, x3, y3, argb);
    }
}

// a line made of pieces with round joints (a thick curve has no gaps)
void draw_joint(Canvas2d^ c, double x, double y, double width, i64 argb) {
    if width > 2.0 { c^.circle(x, y, width / 2.0, argb); }
}

// a piece of a circle line: from angle a0 to a1 (radians, 0 = right, growing downwards on the screen)
void draw_arc(Canvas2d^ c, double cx, double cy, double r, double a0, double a1, double width, i64 argb) {
    i64 n = (i64)((double)draw_sides(r) * (a1 - a0) / (2.0 * draw_pi())) + 2;
    double step = (a1 - a0) / (double)n;
    double px = cx + r * Math::cos(a0);
    double py = cy + r * Math::sin(a0);
    for i in 1..n + 1 {
        double a = a0 + step * (double)i;
        double qx = cx + r * Math::cos(a);
        double qy = cy + r * Math::sin(a);
        c^.line(px, py, qx, qy, width, argb);
        draw_joint(c, qx, qy, width, argb);
        px = qx;
        py = qy;
    }
}

// a cubic Bezier curve: from (x0, y0) to (x3, y3) pulled towards the two control points
void draw_bezier(Canvas2d^ c, double x0, double y0, double x1, double y1, double x2, double y2, double x3, double y3, double width, i64 argb) {
    i64 n = 32;
    double px = x0;
    double py = y0;
    for i in 1..n + 1 {
        double t = (double)i / (double)n;
        double u = 1.0 - t;
        double a = u * u * u;
        double b = 3.0 * u * u * t;
        double d = 3.0 * u * t * t;
        double e = t * t * t;
        double qx = a * x0 + b * x1 + d * x2 + e * x3;
        double qy = a * y0 + b * y1 + d * y2 + e * y3;
        c^.line(px, py, qx, qy, width, argb);
        draw_joint(c, qx, qy, width, argb);
        px = qx;
        py = qy;
    }
}

// a filled convex polygon: the points (xs[i], ys[i]) go round the shape. An opaque colour: each triangle is turned a little over the next one (no seam)
void draw_polygon(Canvas2d^ c, double^ xs, double^ ys, i64 n, i64 argb) {
    double sign = 1.0;
    double cross = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (ys[1] - ys[0]) * (xs[2] - xs[0]);
    if cross < 0.0 { sign = -1.0; }
    bool opaque = ((argb >> 24) & 255) == 255;
    for i in 1..n - 1 {
        double qx = xs[i + 1];
        double qy = ys[i + 1];
        if opaque && i < n - 2 {
            double vx = qx - xs[0];
            double vy = qy - ys[0];
            double len = Math::sqrt(vx * vx + vy * vy) + 1.0;
            double e = sign * 1.2 / len;
            qx = xs[0] + vx * Math::cos(e) - vy * Math::sin(e);
            qy = ys[0] + vx * Math::sin(e) + vy * Math::cos(e);
        }
        c^.tri(xs[0], ys[0], xs[i], ys[i], qx, qy, argb);
    }
}

// the colours go from `from` on the left to `to` on the right (strips of one dot, at most 256)
void draw_gradient_h(Canvas2d^ c, double x, double y, double w, double h, i64 from, i64 to) {
    i64 n = (i64)w;
    if n > 256 { n = 256; }
    if n < 1 { n = 1; }
    double sw = w / (double)n;
    for i in 0..n {
        double t = ((double)i + 0.5) / (double)n;
        c^.rect(x + sw * (double)i, y, sw + 0.5, h, draw_mix(from, to, t));
    }
}

// the colours go from `from` at the top to `to` at the bottom
void draw_gradient_v(Canvas2d^ c, double x, double y, double w, double h, i64 from, i64 to) {
    i64 n = (i64)h;
    if n > 256 { n = 256; }
    if n < 1 { n = 1; }
    double sh = h / (double)n;
    for i in 0..n {
        double t = ((double)i + 0.5) / (double)n;
        c^.rect(x, y + sh * (double)i, w, sh + 0.5, draw_mix(from, to, t));
    }
}

// a circle that is `centre` in the middle and `edge` at the border (opaque colours)
void draw_gradient_radial(Canvas2d^ c, double cx, double cy, double r, i64 centre, i64 edge) {
    i64 n = (i64)r;
    if n > 128 { n = 128; }
    if n < 2 { n = 2; }
    for i in 0..n {
        double t = (double)i / (double)(n - 1);
        draw_ellipse(c, cx, cy, r * (1.0 - t) + 0.5, r * (1.0 - t) + 0.5, draw_mix(edge, centre, t));
    }
}

// the outline of a box, drawn inside it
void draw_rect_stroke(Canvas2d^ c, double x, double y, double w, double h, double lw, i64 argb) {
    c^.rect(x, y, w, lw, argb);
    c^.rect(x, y + h - lw, w, lw, argb);
    c^.rect(x, y + lw, lw, h - 2.0 * lw, argb);
    c^.rect(x + w - lw, y + lw, lw, h - 2.0 * lw, argb);
}
