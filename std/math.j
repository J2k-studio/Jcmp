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
    // x to the power n (n a whole number, negative too): by squaring
    static double powi(double x, int n) {
        if n < 0 { return 1.0 / Math::powi(x, 0 - n); }
        double r = 1.0;
        double b = x;
        while n > 0 {
            if n & 1 == 1 { r = r * b; }
            b = b * b;
            n = n shr 1;
        }
        return r;
    }
    // ---- numbers made from and taken apart into bits (the IEEE form)
    static double from_bits(int bits) {
        int b = bits;
        double^ p = (double^)@b;
        return p[0];
    }
    static int to_bits(double x) {
        double y = x;
        int^ p = (int^)@y;
        return p[0];
    }
    static double inf() { return Math::from_bits(0x7FF0000000000000); }
    static double nan() { return Math::from_bits(0x7FF8000000000000); }
    static bool is_nan(double x) { return x != x; }
    static bool is_inf(double x) { return Math::abs(x) == Math::inf(); }
    static double pi() { return 3.141592653589793; }
    static double tau() { return 6.283185307179586; }
    static double e() { return 2.718281828459045; }
    static double sign(double x) {
        if x > 0.0 { return 1.0; }
        if x < 0.0 { return -1.0; }
        return 0.0;
    }
    // to the nearest whole number (halves away from zero)
    static double round(double x) {
        if x < 0.0 { return 0.0 - Math::floor(0.0 - x + 0.5); }
        return Math::floor(x + 0.5);
    }
    static double clamp(double x, double lo, double hi) {
        if x < lo { return lo; }
        if x > hi { return hi; }
        return x;
    }
    // a + (b - a) * t
    static double lerp(double a, double b, double t) {
        return a + (b - a) * t;
    }
    static double radians(double deg) { return deg * 0.0174532925199433; }
    static double degrees(double rad) { return rad * 57.29577951308232; }
    // the remainder of x / y with the sign of x
    static double fmod(double x, double y) {
        if y == 0.0 { return Math::nan(); }
        return x - y * Math::trunc(x / y);
    }
    // ---- e^x
    static double exp(double x) {
        if Math::is_nan(x) { return x; }
        if x > 709.78 { return Math::inf(); }
        if x < -745.2 { return 0.0; }
        double kf = Math::round(x * 1.442695040888963);
        int k = (int)kf;
        double r = x - kf * Math::from_bits(0x3FE62E42FEE00000) - kf * Math::from_bits(0x3DEA39EF35793C76);
        // e^r for |r| <= 0.35 : the series, from the end
        double t = 1.0 + r / 14.0;
        int i = 13;
        while i >= 1 {
            t = 1.0 + r * t / (double)i;
            i -= 1;
        }
        // times 2^k (in two steps so that a big k does not overflow the power)
        int k1 = k / 2;
        int k2 = k - k1;
        double s1 = Math::from_bits((k1 + 1023) shl 52);
        double s2 = Math::from_bits((k2 + 1023) shl 52);
        return t * s1 * s2;
    }
    // ---- the natural logarithm
    static double log(double x) {
        if Math::is_nan(x) { return x; }
        if x < 0.0 { return Math::nan(); }
        if x == 0.0 { return 0.0 - Math::inf(); }
        if x == Math::inf() { return x; }
        int bits = Math::to_bits(x);
        int ex = ((bits shr 52) & 2047) - 1023;
        if ex == -1023 {
            // a very small number: scale it up first
            return Math::log(x * 4.503599627370496e15) - 36.04365338911715;
        }
        double m = Math::from_bits((bits & 4503599627370495) | 4607182418800017408);   // 1 <= m < 2
        if m > 1.414213562373095 {
            m = m * 0.5;
            ex += 1;
        }
        double s = (m - 1.0) / (m + 1.0);
        double s2 = s * s;
        // 2 * (s + s^3/3 + s^5/5 + ...) , from the end
        double t = 1.0 / 25.0;
        int j = 23;
        while j >= 1 {
            t = t * s2 + 1.0 / (double)j;
            j -= 2;
        }
        return (double)ex * 0.6931471805599453 + 2.0 * s * t;
    }
    static double log2(double x) { return Math::log(x) * 1.442695040888963; }
    static double log10(double x) { return Math::log(x) * 0.4342944819032518; }
    // x to the power y
    static double pow(double x, double y) {
        if y == 0.0 { return 1.0; }
        if Math::is_nan(x) || Math::is_nan(y) { return Math::nan(); }
        double yi = Math::trunc(y);
        if yi == y && Math::abs(y) < 2147483648.0 { return Math::powi(x, (int)y); }
        if x < 0.0 { return Math::nan(); }
        if x == 0.0 {
            if y > 0.0 { return 0.0; }
            return Math::inf();
        }
        return Math::exp(y * Math::log(x));
    }
    static double cbrt(double x) {
        if x == 0.0 { return 0.0; }
        if x < 0.0 { return 0.0 - Math::exp(Math::log(0.0 - x) / 3.0); }
        double g = Math::exp(Math::log(x) / 3.0);
        g = g - (g * g * g - x) / (3.0 * g * g);       // one step of Newton makes it exact
        return g;
    }
    static double hypot(double x, double y) { return Math::sqrt(x * x + y * y); }
    // ---- sine, cosine, tangent (the angle in radians)
    static double sin(double x) {
        if Math::is_nan(x) || Math::is_inf(x) { return Math::nan(); }
        double kf = Math::round(x * 0.6366197723675814);
        double r = x - kf * Math::from_bits(0x3FF921FB54400000) - kf * Math::from_bits(0x3DD0B4611A626331);
        int q = (int)Math::fmod(kf, 4.0);
        if q < 0 { q += 4; }
        if q == 0 { return Math::sin_poly(r); }
        if q == 1 { return Math::cos_poly(r); }
        if q == 2 { return 0.0 - Math::sin_poly(r); }
        return 0.0 - Math::cos_poly(r);
    }
    static double cos(double x) {
        if Math::is_nan(x) || Math::is_inf(x) { return Math::nan(); }
        double kf = Math::round(x * 0.6366197723675814);
        double r = x - kf * Math::from_bits(0x3FF921FB54400000) - kf * Math::from_bits(0x3DD0B4611A626331);
        int q = (int)Math::fmod(kf, 4.0);
        if q < 0 { q += 4; }
        if q == 0 { return Math::cos_poly(r); }
        if q == 1 { return 0.0 - Math::sin_poly(r); }
        if q == 2 { return 0.0 - Math::cos_poly(r); }
        return Math::sin_poly(r);
    }
    static double tan(double x) { return Math::sin(x) / Math::cos(x); }
    // sin and cos for |r| <= 0.8 (the series)
    static double sin_poly(double r) {
        double r2 = r * r;
        double t = 1.0;
        int i = 15;
        while i >= 5 {
            t = 1.0 - r2 * t / (double)(i * (i - 1));
            i -= 2;
        }
        return r * (1.0 - r2 * t / 6.0);
    }
    static double cos_poly(double r) {
        double r2 = r * r;
        double t = 1.0;
        int i = 16;
        while i >= 2 {
            t = 1.0 - r2 * t / (double)(i * (i - 1));
            i -= 2;
        }
        return t;
    }
    // ---- the inverse functions
    static double atan(double x) {
        if Math::is_nan(x) { return x; }
        if x < 0.0 { return 0.0 - Math::atan(0.0 - x); }
        if x > 1.0 { return 1.570796326794897 - Math::atan(1.0 / x); }
        // atan(x) = 2 atan(x / (1 + sqrt(1 + x^2))) twice, then the series
        double y = x / (1.0 + Math::sqrt(1.0 + x * x));
        y = y / (1.0 + Math::sqrt(1.0 + y * y));
        double y2 = y * y;
        double t = 1.0 / 27.0;
        int j = 25;
        while j >= 1 {
            t = 1.0 / (double)j - y2 * t;
            j -= 2;
        }
        return 4.0 * y * t;
    }
    // the angle of the point (x, y) : -pi .. pi
    static double atan2(double y, double x) {
        if x > 0.0 { return Math::atan(y / x); }
        if x < 0.0 {
            if y >= 0.0 { return Math::atan(y / x) + 3.141592653589793; }
            return Math::atan(y / x) - 3.141592653589793;
        }
        if y > 0.0 { return 1.570796326794897; }
        if y < 0.0 { return -1.570796326794897; }
        return 0.0;
    }
    static double asin(double x) {
        if x > 1.0 || x < -1.0 { return Math::nan(); }
        if x == 1.0 { return 1.570796326794897; }
        if x == -1.0 { return -1.570796326794897; }
        return Math::atan(x / Math::sqrt(1.0 - x * x));
    }
    static double acos(double x) {
        if x > 1.0 || x < -1.0 { return Math::nan(); }
        return 1.570796326794897 - Math::asin(x);
    }
    static double sinh(double x) { return (Math::exp(x) - Math::exp(0.0 - x)) * 0.5; }
    static double cosh(double x) { return (Math::exp(x) + Math::exp(0.0 - x)) * 0.5; }
    static double tanh(double x) {
        if x > 20.0 { return 1.0; }
        if x < -20.0 { return -1.0; }
        double a = Math::exp(2.0 * x);
        return (a - 1.0) / (a + 1.0);
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
