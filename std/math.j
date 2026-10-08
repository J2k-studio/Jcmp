// Math: numbers. The f64 functions use the CPU's own instructions.
struct Math {
    static f64 abs(f64 x) {
        if x < 0.0 { return -x; }
        return x;
    }
    static f64 min(f64 a, f64 b) {
        if b < a { return b; }
        return a;
    }
    static f64 max(f64 a, f64 b) {
        if b > a { return b; }
        return a;
    }
    static f64 sqrt(f64 x) {
        return __fsqrt(x);
    }
    // round down / up / toward zero
    static f64 floor(f64 x) {
        return __ffloor(x);
    }
    static f64 ceil(f64 x) {
        return __fceil(x);
    }
    static f64 trunc(f64 x) {
        return __ftrunc(x);
    }
    // x to the power n (n >= 0)
    static f64 pow(f64 x, int n) {
        f64 r = 1.0;
        while n > 0 {
            r = r * x;
            n -= 1;
        }
        return r;
    }
    static int iabs(int x) {
        if x < 0 { return 0 - x; }
        return x;
    }
    static int imin(int a, int b) {
        if b < a { return b; }
        return a;
    }
    static int imax(int a, int b) {
        if b > a { return b; }
        return a;
    }
    static int ipow(int x, int n) {
        int r = 1;
        while n > 0 {
            r = r * x;
            n -= 1;
        }
        return r;
    }
}
