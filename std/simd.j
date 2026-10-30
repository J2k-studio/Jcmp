// simd: vectors of 2 or 4 numbers that live in one 128-bit register.   #import <simd>
//
//   f64x2 v = {1.0, 2.0};       v.x  v.y                      two doubles
//   i64x2 n = {1, 2};           n.x  n.y                      two 64-bit whole numbers
//   f32x4 f = {1.0, 2.0, 3.0, 4.0};   f.x f.y f.z f.w         four floats
//   i32x4 m = {1, 2, 3, 4};     m.x m.y m.z m.w               four 32-bit whole numbers
//   i8x16 b = i8x16::load(p, 0);   b.dot(c)                    sixteen bytes; the dot product into four i32 lanes (SDOT)
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
    // the lanes together: sum() is x + y, min() and max() the smaller and the larger lane
    double sum(self) { return self.x + self.y; }
    double min(self) { if self.y < self.x { return self.y; } return self.x; }
    double max(self) { if self.y > self.x { return self.y; } return self.x; }
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
    int sum(self) { return self.x + self.y; }
    int min(self) { if self.y < self.x { return self.y; } return self.x; }
    int max(self) { if self.y > self.x { return self.y; } return self.x; }
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
    // sum() is (x + y) + (z + w)
    float sum(self) { return (self.x + self.y) + (self.z + self.w); }
    float min(self) {
        float a = self.x;
        float b = self.z;
        if self.y < a { a = self.y; }
        if self.w < b { b = self.w; }
        if b < a { return b; }
        return a;
    }
    float max(self) {
        float a = self.x;
        float b = self.z;
        if self.y > a { a = self.y; }
        if self.w > b { b = self.w; }
        if b > a { return b; }
        return a;
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
    // sum() is (x + y) + (z + w)
    i32 sum(self) { return (self.x + self.y) + (self.z + self.w); }
    i32 min(self) {
        i32 a = self.x;
        i32 b = self.z;
        if self.y < a { a = self.y; }
        if self.w < b { b = self.w; }
        if b < a { return b; }
        return a;
    }
    i32 max(self) {
        i32 a = self.x;
        i32 b = self.z;
        if self.y > a { a = self.y; }
        if self.w > b { b = self.w; }
        if b > a { return b; }
        return a;
    }
}

// sixteen bytes in one register (i8x16): the loads and stores are one 16-byte instruction; + and - work lane by lane (wrapping); a.dot(b) is the int8
// dot product of the Cortex-A76 (SDOT): every 32-bit lane of the result is the sum of four products of bytes, the four lanes 0-3, 4-7, 8-11, 12-15.
// It is what a quantised matrix product needs: 16 multiply-adds in one instruction. Index of load/store counts bytes (the array is an i8 or char array).
struct i8x16 {
    i8 l0; i8 l1; i8 l2; i8 l3; i8 l4; i8 l5; i8 l6; i8 l7;
    i8 l8; i8 l9; i8 l10; i8 l11; i8 l12; i8 l13; i8 l14; i8 l15;

    static i8x16 load(i8^ p, int i) {
        i8x16 r = {p[i], p[i + 1], p[i + 2], p[i + 3], p[i + 4], p[i + 5], p[i + 6], p[i + 7], p[i + 8], p[i + 9], p[i + 10], p[i + 11], p[i + 12], p[i + 13], p[i + 14], p[i + 15]};
        return r;
    }
    void store(self, i8^ p, int i) {
        p[i] = self.l0; p[i + 1] = self.l1; p[i + 2] = self.l2; p[i + 3] = self.l3;
        p[i + 4] = self.l4; p[i + 5] = self.l5; p[i + 6] = self.l6; p[i + 7] = self.l7;
        p[i + 8] = self.l8; p[i + 9] = self.l9; p[i + 10] = self.l10; p[i + 11] = self.l11;
        p[i + 12] = self.l12; p[i + 13] = self.l13; p[i + 14] = self.l14; p[i + 15] = self.l15;
    }
    // the meaning of dot (the compiler makes SDOT of it on aarch64)
    i32x4 dot(self, i8x16 o) {
        i32x4 r = {self.l0 * o.l0 + self.l1 * o.l1 + self.l2 * o.l2 + self.l3 * o.l3,
                   self.l4 * o.l4 + self.l5 * o.l5 + self.l6 * o.l6 + self.l7 * o.l7,
                   self.l8 * o.l8 + self.l9 * o.l9 + self.l10 * o.l10 + self.l11 * o.l11,
                   self.l12 * o.l12 + self.l13 * o.l13 + self.l14 * o.l14 + self.l15 * o.l15};
        return r;
    }
}
