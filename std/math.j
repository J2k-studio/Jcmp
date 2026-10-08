// Math: numbers. The double functions use the CPU's own instructions.
struct Math {
    static double abs(double x) {
        if x < 0.0 { return -x; }
        return x;
    }
    static double min(double a, double b) {
        if b < a { return b; }
        return a;
    }
    static double max(double a, double b) {
        if b > a { return b; }
        return a;
    }
    static double sqrt(double x) {
        return __fsqrt(x);
    }
    // round down / up / toward zero
    static double floor(double x) {
        return __ffloor(x);
    }
    static double ceil(double x) {
        return __fceil(x);
    }
    static double trunc(double x) {
        return __ftrunc(x);
    }
    // x to the power n (n >= 0)
    static double pow(double x, int n) {
        double r = 1.0;
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
