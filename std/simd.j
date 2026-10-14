// simd: vectors of 2 or 4 numbers that live in one 128-bit register.   #import <simd>
//
//   f64x2 v = {1.0, 2.0};       v.x  v.y                      two doubles
//   i64x2 n = {1, 2};           n.x  n.y                      two 64-bit whole numbers
//   f32x4 f = {1.0, 2.0, 3.0, 4.0};   f.x f.y f.z f.w         four floats
//   i32x4 m = {1, 2, 3, 4};     m.x m.y m.z m.w               four 32-bit whole numbers
//
// The lanes are named x y z w as in vec3. Steps S1-S3 of docs/syntax-design.md 59: the types, the operators, the loads and
// stores of arrays (f64x2::load(a, i), v.store(a, i)).

struct f64x2 {
    double x;
    double y;

    // f64x2::load(a, i) is the pair a[i], a[i + 1] in one 16-byte load; v.store(a, i) writes it back (the compiler makes the
    // instruction; these bodies say what it means)
    static f64x2 load(double^ p, int i) {
        f64x2 r = {p[i], p[i + 1]};
        return r;
    }
    void store(self, double^ p, int i) {
        p[i] = self.x;
        p[i + 1] = self.y;
    }
}

struct i64x2 {
    int x;
    int y;

    static i64x2 load(int^ p, int i) {
        i64x2 r = {p[i], p[i + 1]};
        return r;
    }
    void store(self, int^ p, int i) {
        p[i] = self.x;
        p[i + 1] = self.y;
    }
}

struct f32x4 {
    float x;
    float y;
    float z;
    float w;

    static f32x4 load(float^ p, int i) {
        f32x4 r = {p[i], p[i + 1], p[i + 2], p[i + 3]};
        return r;
    }
    void store(self, float^ p, int i) {
        p[i] = self.x;
        p[i + 1] = self.y;
        p[i + 2] = self.z;
        p[i + 3] = self.w;
    }
}

struct i32x4 {
    i32 x;
    i32 y;
    i32 z;
    i32 w;

    static i32x4 load(i32^ p, int i) {
        i32x4 r = {p[i], p[i + 1], p[i + 2], p[i + 3]};
        return r;
    }
    void store(self, i32^ p, int i) {
        p[i] = self.x;
        p[i + 1] = self.y;
        p[i + 2] = self.z;
        p[i + 3] = self.w;
    }
}
