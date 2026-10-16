// Printing a double that is 2^64 or more (coutf calls this from j2k_print_f64): d.dddddde+NN, the sign is written by the caller.
struct __Fp {
    static void huge(int bits) {
        double fl[1];
        int^ fb = (int^)@fl[0];
        fb[0] = bits;
        double d = fl[0];
        int e10 = 0;
        while d >= 1.0e23 {
            d = d / 1.0e22;
            e10 += 22;
        }
        while d >= 10.0 {
            d = d / 10.0;
            e10 += 1;
        }
        int m = (int)(d * 1000000.0 + 0.5);
        if m >= 10000000 {
            m = m / 10;
            e10 += 1;
        }
        char buf[32];
        int n = 0;
        buf[n] = (char)(48 + m / 1000000);
        n += 1;
        buf[n] = '.';
        n += 1;
        int div = 100000;
        while div > 0 {
            buf[n] = (char)(48 + m / div % 10);
            n += 1;
            div = div / 10;
        }
        buf[n] = 'e';
        n += 1;
        buf[n] = '+';
        n += 1;
        if e10 >= 100 {
            buf[n] = (char)(48 + e10 / 100);
            n += 1;
        }
        buf[n] = (char)(48 + e10 / 10 % 10);
        n += 1;
        buf[n] = (char)(48 + e10 % 10);
        n += 1;
        syscall(64, 1, @buf, n);
    }
}
