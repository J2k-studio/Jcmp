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
    static vec2 zero() { vec2 r; r.x = 0.0; r.y = 0.0; return r; }
    static vec2 splat(double v) { vec2 r; r.x = v; r.y = v; return r; }
    operator vec2 add(self, vec2 o) { vec2 r; r.x = self.x + o.x; r.y = self.y + o.y; return r; }
    operator vec2 sub(self, vec2 o) { vec2 r; r.x = self.x - o.x; r.y = self.y - o.y; return r; }
    vec2 mulv(self, vec2 o) { vec2 r; r.x = self.x * o.x; r.y = self.y * o.y; return r; }
    vec2 divv(self, vec2 o) { vec2 r; r.x = self.x / o.x; r.y = self.y / o.y; return r; }
    operator vec2 mul(self, double k) { vec2 r; r.x = self.x * k; r.y = self.y * k; return r; }
    operator vec2 div(self, double k) { vec2 r; r.x = self.x / k; r.y = self.y / k; return r; }
    operator vec2 neg(self) { vec2 r; r.x = 0.0 - self.x; r.y = 0.0 - self.y; return r; }
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
    vec2 lerp(self, vec2 o, double t) { vec2 r; r.x = self.x + (o.x - self.x) * t; r.y = self.y + (o.y - self.y) * t; return r; }
    vec2 min(self, vec2 o) { vec2 r; r.x = Math::min(self.x, o.x); r.y = Math::min(self.y, o.y); return r; }
    vec2 max(self, vec2 o) { vec2 r; r.x = Math::max(self.x, o.x); r.y = Math::max(self.y, o.y); return r; }
    vec2 abs(self) { vec2 r; r.x = Math::abs(self.x); r.y = Math::abs(self.y); return r; }
    vec2 reflect(self, vec2 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec2 o) { return self.x == o.x && self.y == o.y; }
    // the z of the 3D cross product
    double cross(self, vec2 o) { return self.x * o.y - self.y * o.x; }
    vec2 perp(self) { vec2 r; r.x = 0.0 - self.y; r.y = self.x; return r; }
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
    static vec3 zero() { vec3 r; r.x = 0.0; r.y = 0.0; r.z = 0.0; return r; }
    static vec3 splat(double v) { vec3 r; r.x = v; r.y = v; r.z = v; return r; }
    operator vec3 add(self, vec3 o) { vec3 r; r.x = self.x + o.x; r.y = self.y + o.y; r.z = self.z + o.z; return r; }
    operator vec3 sub(self, vec3 o) { vec3 r; r.x = self.x - o.x; r.y = self.y - o.y; r.z = self.z - o.z; return r; }
    vec3 mulv(self, vec3 o) { vec3 r; r.x = self.x * o.x; r.y = self.y * o.y; r.z = self.z * o.z; return r; }
    vec3 divv(self, vec3 o) { vec3 r; r.x = self.x / o.x; r.y = self.y / o.y; r.z = self.z / o.z; return r; }
    operator vec3 mul(self, double k) { vec3 r; r.x = self.x * k; r.y = self.y * k; r.z = self.z * k; return r; }
    operator vec3 div(self, double k) { vec3 r; r.x = self.x / k; r.y = self.y / k; r.z = self.z / k; return r; }
    operator vec3 neg(self) { vec3 r; r.x = 0.0 - self.x; r.y = 0.0 - self.y; r.z = 0.0 - self.z; return r; }
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
    vec3 lerp(self, vec3 o, double t) { vec3 r; r.x = self.x + (o.x - self.x) * t; r.y = self.y + (o.y - self.y) * t; r.z = self.z + (o.z - self.z) * t; return r; }
    vec3 min(self, vec3 o) { vec3 r; r.x = Math::min(self.x, o.x); r.y = Math::min(self.y, o.y); r.z = Math::min(self.z, o.z); return r; }
    vec3 max(self, vec3 o) { vec3 r; r.x = Math::max(self.x, o.x); r.y = Math::max(self.y, o.y); r.z = Math::max(self.z, o.z); return r; }
    vec3 abs(self) { vec3 r; r.x = Math::abs(self.x); r.y = Math::abs(self.y); r.z = Math::abs(self.z); return r; }
    vec3 reflect(self, vec3 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec3 o) { return self.x == o.x && self.y == o.y && self.z == o.z; }
    vec3 cross(self, vec3 o) { vec3 r; r.x = self.y * o.z - self.z * o.y; r.y = self.z * o.x - self.x * o.z; r.z = self.x * o.y - self.y * o.x; return r; }
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
    static vec4 zero() { vec4 r; r.x = 0.0; r.y = 0.0; r.z = 0.0; r.w = 0.0; return r; }
    static vec4 splat(double v) { vec4 r; r.x = v; r.y = v; r.z = v; r.w = v; return r; }
    operator vec4 add(self, vec4 o) { vec4 r; r.x = self.x + o.x; r.y = self.y + o.y; r.z = self.z + o.z; r.w = self.w + o.w; return r; }
    operator vec4 sub(self, vec4 o) { vec4 r; r.x = self.x - o.x; r.y = self.y - o.y; r.z = self.z - o.z; r.w = self.w - o.w; return r; }
    vec4 mulv(self, vec4 o) { vec4 r; r.x = self.x * o.x; r.y = self.y * o.y; r.z = self.z * o.z; r.w = self.w * o.w; return r; }
    vec4 divv(self, vec4 o) { vec4 r; r.x = self.x / o.x; r.y = self.y / o.y; r.z = self.z / o.z; r.w = self.w / o.w; return r; }
    operator vec4 mul(self, double k) { vec4 r; r.x = self.x * k; r.y = self.y * k; r.z = self.z * k; r.w = self.w * k; return r; }
    operator vec4 div(self, double k) { vec4 r; r.x = self.x / k; r.y = self.y / k; r.z = self.z / k; r.w = self.w / k; return r; }
    operator vec4 neg(self) { vec4 r; r.x = 0.0 - self.x; r.y = 0.0 - self.y; r.z = 0.0 - self.z; r.w = 0.0 - self.w; return r; }
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
    vec4 lerp(self, vec4 o, double t) { vec4 r; r.x = self.x + (o.x - self.x) * t; r.y = self.y + (o.y - self.y) * t; r.z = self.z + (o.z - self.z) * t; r.w = self.w + (o.w - self.w) * t; return r; }
    vec4 min(self, vec4 o) { vec4 r; r.x = Math::min(self.x, o.x); r.y = Math::min(self.y, o.y); r.z = Math::min(self.z, o.z); r.w = Math::min(self.w, o.w); return r; }
    vec4 max(self, vec4 o) { vec4 r; r.x = Math::max(self.x, o.x); r.y = Math::max(self.y, o.y); r.z = Math::max(self.z, o.z); r.w = Math::max(self.w, o.w); return r; }
    vec4 abs(self) { vec4 r; r.x = Math::abs(self.x); r.y = Math::abs(self.y); r.z = Math::abs(self.z); r.w = Math::abs(self.w); return r; }
    vec4 reflect(self, vec4 n) { return self.sub(n.mul(2.0 * self.dot(n))); }
    operator bool eq(self, vec4 o) { return self.x == o.x && self.y == o.y && self.z == o.z && self.w == o.w; }
}
