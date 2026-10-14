// simd: vectors of 2 or 4 numbers that live in one 128-bit register.   #import <simd>
//
//   f64x2 v = {1.0, 2.0};       v.x  v.y                      two doubles
//   i64x2 n = {1, 2};           n.x  n.y                      two 64-bit whole numbers
//   f32x4 f = {1.0, 2.0, 3.0, 4.0};   f.x f.y f.z f.w         four floats
//   i32x4 m = {1, 2, 3, 4};     m.x m.y m.z m.w               four 32-bit whole numbers
//
// The lanes are named x y z w as in vec3. Step S1 of docs/syntax-design.md 59: the types; the operators and
// the loads from arrays come next.

struct f64x2 {
    double x;
    double y;
}

struct i64x2 {
    int x;
    int y;
}

struct f32x4 {
    float x;
    float y;
    float z;
    float w;
}

struct i32x4 {
    i32 x;
    i32 y;
    i32 z;
    i32 w;
}
