// vec2, vec3, vec4: vectors of doubles.   #import <math>   using math::vector;
//   vec3 p = {1.0, 2.0, 3.0};   p += v * dt;   double l = p.normalize().dot(light);
// operators: a + b, a - b, a * k, a / k, a == b, a != b and a += b (methods declared with the word operator)

struct vec2 {
    double x;
    double y;
    static vec2 make(double x, double y) {
        vec2 r;
        r.x = x;
        r.y = y;
        return r;
    }
    static vec2 zero() { return vec2::make(0.0, 0.0); }
    static vec2 splat(double v) { return vec2::make(v, v); }
    operator vec2 add(self, vec2 o) { return vec2::make(self.x + o.x, self.y + o.y); }
    operator vec2 sub(self, vec2 o) { return vec2::make(self.x - o.x, self.y - o.y); }
    vec2 mulv(self, vec2 o) { return vec2::make(self.x * o.x, self.y * o.y); }
    vec2 divv(self, vec2 o) { return vec2::make(self.x / o.x, self.y / o.y); }
    operator vec2 mul(self, double k) { return vec2::make(self.x * k, self.y * k); }
    operator vec2 div(self, double k) { return vec2::make(self.x / k, self.y / k); }
    vec2 neg(self) { return vec2::make(0.0 - self.x, 0.0 - self.y); }
    double dot(self, vec2 o) { return self.x * o.x + self.y * o.y; }
    double length_sq(self) { return self.x * self.x + self.y * self.y; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, vec2 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    vec2 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    vec2 lerp(self, vec2 o, double t) { return vec2::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t); }
    vec2 min(self, vec2 o) { return vec2::make(Math::min(self.x, o.x), Math::min(self.y, o.y)); }
    vec2 max(self, vec2 o) { return vec2::make(Math::max(self.x, o.x), Math::max(self.y, o.y)); }
    vec2 abs(self) { return vec2::make(Math::abs(self.x), Math::abs(self.y)); }
    vec2 reflect(self, vec2 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec2 o) { return self.x == o.x && self.y == o.y; }
    // the z of the 3D cross product
    double cross(self, vec2 o) { return self.x * o.y - self.y * o.x; }
    vec2 perp(self) { return vec2::make(0.0 - self.y, self.x); }
}

struct vec3 {
    double x;
    double y;
    double z;
    static vec3 make(double x, double y, double z) {
        vec3 r;
        r.x = x;
        r.y = y;
        r.z = z;
        return r;
    }
    static vec3 zero() { return vec3::make(0.0, 0.0, 0.0); }
    static vec3 splat(double v) { return vec3::make(v, v, v); }
    operator vec3 add(self, vec3 o) { return vec3::make(self.x + o.x, self.y + o.y, self.z + o.z); }
    operator vec3 sub(self, vec3 o) { return vec3::make(self.x - o.x, self.y - o.y, self.z - o.z); }
    vec3 mulv(self, vec3 o) { return vec3::make(self.x * o.x, self.y * o.y, self.z * o.z); }
    vec3 divv(self, vec3 o) { return vec3::make(self.x / o.x, self.y / o.y, self.z / o.z); }
    operator vec3 mul(self, double k) { return vec3::make(self.x * k, self.y * k, self.z * k); }
    operator vec3 div(self, double k) { return vec3::make(self.x / k, self.y / k, self.z / k); }
    vec3 neg(self) { return vec3::make(0.0 - self.x, 0.0 - self.y, 0.0 - self.z); }
    double dot(self, vec3 o) { return self.x * o.x + self.y * o.y + self.z * o.z; }
    double length_sq(self) { return self.x * self.x + self.y * self.y + self.z * self.z; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, vec3 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    vec3 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    vec3 lerp(self, vec3 o, double t) { return vec3::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t, self.z + (o.z - self.z) * t); }
    vec3 min(self, vec3 o) { return vec3::make(Math::min(self.x, o.x), Math::min(self.y, o.y), Math::min(self.z, o.z)); }
    vec3 max(self, vec3 o) { return vec3::make(Math::max(self.x, o.x), Math::max(self.y, o.y), Math::max(self.z, o.z)); }
    vec3 abs(self) { return vec3::make(Math::abs(self.x), Math::abs(self.y), Math::abs(self.z)); }
    vec3 reflect(self, vec3 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec3 o) { return self.x == o.x && self.y == o.y && self.z == o.z; }
    vec3 cross(self, vec3 o) { return vec3::make(self.y * o.z - self.z * o.y, self.z * o.x - self.x * o.z, self.x * o.y - self.y * o.x); }
}

struct vec4 {
    double x;
    double y;
    double z;
    double w;
    static vec4 make(double x, double y, double z, double w) {
        vec4 r;
        r.x = x;
        r.y = y;
        r.z = z;
        r.w = w;
        return r;
    }
    static vec4 zero() { return vec4::make(0.0, 0.0, 0.0, 0.0); }
    static vec4 splat(double v) { return vec4::make(v, v, v, v); }
    operator vec4 add(self, vec4 o) { return vec4::make(self.x + o.x, self.y + o.y, self.z + o.z, self.w + o.w); }
    operator vec4 sub(self, vec4 o) { return vec4::make(self.x - o.x, self.y - o.y, self.z - o.z, self.w - o.w); }
    vec4 mulv(self, vec4 o) { return vec4::make(self.x * o.x, self.y * o.y, self.z * o.z, self.w * o.w); }
    vec4 divv(self, vec4 o) { return vec4::make(self.x / o.x, self.y / o.y, self.z / o.z, self.w / o.w); }
    operator vec4 mul(self, double k) { return vec4::make(self.x * k, self.y * k, self.z * k, self.w * k); }
    operator vec4 div(self, double k) { return vec4::make(self.x / k, self.y / k, self.z / k, self.w / k); }
    vec4 neg(self) { return vec4::make(0.0 - self.x, 0.0 - self.y, 0.0 - self.z, 0.0 - self.w); }
    double dot(self, vec4 o) { return self.x * o.x + self.y * o.y + self.z * o.z + self.w * o.w; }
    double length_sq(self) { return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w; }
    double length(self) { return Math::sqrt(self.length_sq()); }
    double distance(self, vec4 o) { return self.sub(o).length(); }
    // the same direction with length 1 (the zero vector stays zero)
    vec4 normalize(self) {
        double l = self.length();
        if l == 0.0 { return self.mul(1.0); }
        return self.div(l);
    }
    vec4 lerp(self, vec4 o, double t) { return vec4::make(self.x + (o.x - self.x) * t, self.y + (o.y - self.y) * t, self.z + (o.z - self.z) * t, self.w + (o.w - self.w) * t); }
    vec4 min(self, vec4 o) { return vec4::make(Math::min(self.x, o.x), Math::min(self.y, o.y), Math::min(self.z, o.z), Math::min(self.w, o.w)); }
    vec4 max(self, vec4 o) { return vec4::make(Math::max(self.x, o.x), Math::max(self.y, o.y), Math::max(self.z, o.z), Math::max(self.w, o.w)); }
    vec4 abs(self) { return vec4::make(Math::abs(self.x), Math::abs(self.y), Math::abs(self.z), Math::abs(self.w)); }
    vec4 reflect(self, vec4 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec4 o) { return self.x == o.x && self.y == o.y && self.z == o.z && self.w == o.w; }
}
