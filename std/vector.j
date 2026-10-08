// Vec2, Vec3, Vec4: vectors of doubles. #import <vector>
//   Vec3 p = Vec3::make(1.0, 2.0, 3.0);   Vec3 q = p.add(v.mul(dt));   double l = p.normalize().dot(light);
// (the operators + - * and += on vectors come later: see docs/syntax-design.md, section 55)

struct Vec2 {
    double x;
    double y;
    static Vec2 make(double x, double y) {
        Vec2 r;
        r.x = x;
        r.y = y;
        return r;
    }
    static Vec2 zero() { return Vec2::make(0.0, 0.0); }
    static Vec2 splat(double v) { return Vec2::make(v, v); }
    Vec2 add(self, Vec2 o) { return Vec2::make(self.x + o.x, self.y + o.y); }
    Vec2 sub(self, Vec2 o) { return Vec2::make(self.x - o.x, self.y - o.y); }
    Vec2 mulv(self, Vec2 o) { return Vec2::make(self.x * o.x, self.y * o.y); }
    Vec2 divv(self, Vec2 o) { return Vec2::make(self.x / o.x, self.y / o.y); }
    Vec2 mul(self, double k) { return Vec2::make(self.x * k, self.y * k); }
    Vec2 div(self, double k) { return Vec2::make(self.x / k, self.y / k); }
    Vec2 neg(self) { return Vec2::make(0.0 - self.x, 0.0 - self.y); }
    double dot(self, Vec2 o) { return self.x * o.x + self.y * o.y; }
    double length_sq(self) { return self.x * self.x + self.y * self.y; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, Vec2 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    Vec2 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    Vec2 lerp(self, Vec2 o, double t) { return Vec2::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t); }
    Vec2 min(self, Vec2 o) { return Vec2::make(Math::min(self.x, o.x), Math::min(self.y, o.y)); }
    Vec2 max(self, Vec2 o) { return Vec2::make(Math::max(self.x, o.x), Math::max(self.y, o.y)); }
    Vec2 abs(self) { return Vec2::make(Math::abs(self.x), Math::abs(self.y)); }
    Vec2 reflect(self, Vec2 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    bool eq(self, Vec2 o) { return self.x == o.x && self.y == o.y; }
    // the z of the 3D cross product
    double cross(self, Vec2 o) { return self.x * o.y - self.y * o.x; }
    Vec2 perp(self) { return Vec2::make(0.0 - self.y, self.x); }
}

struct Vec3 {
    double x;
    double y;
    double z;
    static Vec3 make(double x, double y, double z) {
        Vec3 r;
        r.x = x;
        r.y = y;
        r.z = z;
        return r;
    }
    static Vec3 zero() { return Vec3::make(0.0, 0.0, 0.0); }
    static Vec3 splat(double v) { return Vec3::make(v, v, v); }
    Vec3 add(self, Vec3 o) { return Vec3::make(self.x + o.x, self.y + o.y, self.z + o.z); }
    Vec3 sub(self, Vec3 o) { return Vec3::make(self.x - o.x, self.y - o.y, self.z - o.z); }
    Vec3 mulv(self, Vec3 o) { return Vec3::make(self.x * o.x, self.y * o.y, self.z * o.z); }
    Vec3 divv(self, Vec3 o) { return Vec3::make(self.x / o.x, self.y / o.y, self.z / o.z); }
    Vec3 mul(self, double k) { return Vec3::make(self.x * k, self.y * k, self.z * k); }
    Vec3 div(self, double k) { return Vec3::make(self.x / k, self.y / k, self.z / k); }
    Vec3 neg(self) { return Vec3::make(0.0 - self.x, 0.0 - self.y, 0.0 - self.z); }
    double dot(self, Vec3 o) { return self.x * o.x + self.y * o.y + self.z * o.z; }
    double length_sq(self) { return self.x * self.x + self.y * self.y + self.z * self.z; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, Vec3 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    Vec3 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    Vec3 lerp(self, Vec3 o, double t) { return Vec3::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t, self.z + (o.z - self.z) * t); }
    Vec3 min(self, Vec3 o) { return Vec3::make(Math::min(self.x, o.x), Math::min(self.y, o.y), Math::min(self.z, o.z)); }
    Vec3 max(self, Vec3 o) { return Vec3::make(Math::max(self.x, o.x), Math::max(self.y, o.y), Math::max(self.z, o.z)); }
    Vec3 abs(self) { return Vec3::make(Math::abs(self.x), Math::abs(self.y), Math::abs(self.z)); }
    Vec3 reflect(self, Vec3 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    bool eq(self, Vec3 o) { return self.x == o.x && self.y == o.y && self.z == o.z; }
    Vec3 cross(self, Vec3 o) { return Vec3::make(self.y * o.z - self.z * o.y, self.z * o.x - self.x * o.z, self.x * o.y - self.y * o.x); }
}

struct Vec4 {
    double x;
    double y;
    double z;
    double w;
    static Vec4 make(double x, double y, double z, double w) {
        Vec4 r;
        r.x = x;
        r.y = y;
        r.z = z;
        r.w = w;
        return r;
    }
    static Vec4 zero() { return Vec4::make(0.0, 0.0, 0.0, 0.0); }
    static Vec4 splat(double v) { return Vec4::make(v, v, v, v); }
    Vec4 add(self, Vec4 o) { return Vec4::make(self.x + o.x, self.y + o.y, self.z + o.z, self.w + o.w); }
    Vec4 sub(self, Vec4 o) { return Vec4::make(self.x - o.x, self.y - o.y, self.z - o.z, self.w - o.w); }
    Vec4 mulv(self, Vec4 o) { return Vec4::make(self.x * o.x, self.y * o.y, self.z * o.z, self.w * o.w); }
    Vec4 divv(self, Vec4 o) { return Vec4::make(self.x / o.x, self.y / o.y, self.z / o.z, self.w / o.w); }
    Vec4 mul(self, double k) { return Vec4::make(self.x * k, self.y * k, self.z * k, self.w * k); }
    Vec4 div(self, double k) { return Vec4::make(self.x / k, self.y / k, self.z / k, self.w / k); }
    Vec4 neg(self) { return Vec4::make(0.0 - self.x, 0.0 - self.y, 0.0 - self.z, 0.0 - self.w); }
    double dot(self, Vec4 o) { return self.x * o.x + self.y * o.y + self.z * o.z + self.w * o.w; }
    double length_sq(self) { return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, Vec4 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    Vec4 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    Vec4 lerp(self, Vec4 o, double t) { return Vec4::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t, self.z + (o.z - self.z) * t, self.w + (o.w - self.w) * t); }
    Vec4 min(self, Vec4 o) { return Vec4::make(Math::min(self.x, o.x), Math::min(self.y, o.y), Math::min(self.z, o.z), Math::min(self.w, o.w)); }
    Vec4 max(self, Vec4 o) { return Vec4::make(Math::max(self.x, o.x), Math::max(self.y, o.y), Math::max(self.z, o.z), Math::max(self.w, o.w)); }
    Vec4 abs(self) { return Vec4::make(Math::abs(self.x), Math::abs(self.y), Math::abs(self.z), Math::abs(self.w)); }
    Vec4 reflect(self, Vec4 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    bool eq(self, Vec4 o) { return self.x == o.x && self.y == o.y && self.z == o.z && self.w == o.w; }
}
