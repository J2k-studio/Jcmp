// The routines that the ARM32 target needs and that the ARM64 target has as assembly in the compiler (docs/design/15-arm32.md).
// They are written in J2K and made by the same back end as the program; the compiler calls them by name (__a32_*) for the operations that
// a 32 bit machine has no instruction for (division, the high half of a product) and for the printing of cout.
// Nothing here is used by the ARM64 target: a function that nobody calls is not made.

// unsigned 64-bit a / b, a % b (0 when b is 0); the numbers below 2^52 are divided as doubles (exact: a / b is never rounded up to the next
// whole number when a < 2^52), the others by shift and subtract
int __a32_udiv(int a, int b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        return (int)(da / db);
    }
    int top = 1 << 63;
    int bt = b xor top;
    int q = 0;
    int r = 0;
    int i = 63;
    while i >= 0 {
        int carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
            q = q | (1 << i);
        }
        i -= 1;
    }
    return q;
}

int __a32_umod(int a, int b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        int q = (int)(da / db);
        return a - q * b;
    }
    int top = 1 << 63;
    int bt = b xor top;
    int r = 0;
    int i = 63;
    while i >= 0 {
        int carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
        }
        i -= 1;
    }
    return r;
}

// signed division: the quotient goes towards 0, the remainder has the sign of a
int __a32_sdiv(int a, int b) {
    if b == 0 { return 0; }
    int neg = 0;
    if a < 0 { a = 0 - a; neg = 1 - neg; }
    if b < 0 { b = 0 - b; neg = 1 - neg; }
    int q = __a32_udiv(a, b);
    if neg == 1 { return 0 - q; }
    return q;
}

int __a32_smod(int a, int b) {
    if b == 0 { return 0; }
    int neg = 0;
    if a < 0 { a = 0 - a; neg = 1; }
    if b < 0 { b = 0 - b; }
    int r = __a32_umod(a, b);
    if neg == 1 { return 0 - r; }
    return r;
}

// __a32_mulhs (the high 64 bits of the signed 128-bit product a * b) is a routine by hand in the back end (jc_a32.j, a32_emit_exc)

// the start: the stack has 4-byte words (argc, the pointers of argv, 0, the pointers of the environment, 0); the programs (argc(), arg(i), Env)
// read 8-byte words: a copy in that form is made and the entry gives its address to the global area
int __a32_fixargs(int sp) {
    i32^ old = (i32^)sp;
    int w = (old[0] & 4294967295) + 2;
    while (old[w] & 4294967295) != 0 { w += 1; }
    // after the environment come the pairs of the auxiliary vector: (1 << 17) of AT_HWCAP (16) says that the CPU has udiv / sdiv (the global area is at 0x10000000, the flag at 872)
    int k = w + 1;
    while (old[k] & 4294967295) != 0 {
        if (old[k] & 4294967295) == 16 && ((old[k + 1] & 4294967295) & 131072) != 0 {
            int^ gflag = (int^)268435456;
            gflag[109] = 1;
        }
        k += 2;
    }
    int mem = syscall(222, 0, (w + 2) * 8, 3, 34, -1, 0);
    int^ nw = (int^)mem;
    int j = 0;
    while j <= w {
        nw[j] = old[j] & 4294967295;
        j += 1;
    }
    return mem;
}

// the copy of j2k_copy / j2k_copy16 (source, -, bytes (a multiple of 8), destination)
void __a32_copy(int s, int u, int n, int d) {
    int^ ps = (int^)s;
    int^ pd = (int^)d;
    int k = 0;
    while k * 8 < n {
        pd[k] = ps[k];
        k += 1;
    }
}

void __a32_copy16(int s, int u, int n, int d) {
    __a32_copy(s, u, n, d);
}

void __a32_divzero() {
    __panic("division by zero");
}

// the signal handler for SIGSEGV (called by the entry stub with the arguments of the kernel put in our own form)
void __a32_hex(int v) {
    char b[16];
    int i = 7;
    while i >= 0 {
        int dgt = (v >> (4 * i)) & 15;
        if dgt < 10 { b[7 - i] = '0' + dgt; } else { b[7 - i] = 'a' + dgt - 10; }
        i -= 1;
    }
    b[8] = 0;
    syscall(64, 2, @b, 8);
}

void __a32_segv(int sig, int info, int uc) {
    i32^ c = (i32^)uc;
    i32^ si = (i32^)info;
    __a32_errtext("segmentation fault: pc=0x");
    __a32_hex(c[23]);
    __a32_errtext(" lr=0x");
    __a32_hex(c[22]);
    __a32_errtext(" address=0x");
    __a32_hex(si[3]);
    __a32_errtext("\n");
    syscall(94, 139);
}

void __a32_errtext(char^ s) {
    __flush();
    int n = 0;
    while s[n] != 0 { n += 1; }
    syscall(64, 2, s, n);
}

void __a32_print_str(char^ s) {
    int n = 0;
    while s[n] != 0 { n += 1; }
    __wr(__out_fd(), s, n);
}

void __a32_print_char(int c) {
    char b[8];
    b[0] = c;
    __wr(__out_fd(), @b, 1);
}

void __a32_print_int(int v) {
    char buf[32];
    int at = 31;
    int u = v;
    bool neg = false;
    if v < 0 {
        neg = true;
        u = 0 - v;
    }
    if u == 0 {
        buf[at] = '0';
        at -= 1;
    }
    while u != 0 {
        int q = __a32_udiv(u, 10);
        buf[at] = '0' + (u - q * 10);
        at -= 1;
        u = q;
    }
    if neg {
        buf[at] = '-';
        at -= 1;
    }
    __wr(__out_fd(), @buf[at + 1], 31 - at);
}

// the end of a function that has to give a value and did not (the ARM64 target jumps to j2k_noret)
void __a32_noret() {
    __panic("a function ended without giving a value");
}

// ---- double precision numbers by their bits (the ARM32 target has no instruction for these in VFPv3)
// the whole number part, towards 0 (the bits of the double in, a 64-bit whole number out; 0 for a NaN, the limit for a number that is too big)
int __a32_d2i(int bits) {
    int e = ((bits >> 52) & 2047) - 1023;
    if e < 0 { return 0; }
    int m = (bits & 4503599627370495) | 4503599627370496;
    int v = 0;
    if e >= 63 {
        v = 9223372036854775807;
        if bits < 0 { return 0 - v - 1; }
        return v;
    }
    if e >= 52 { v = m << (e - 52); } else { v = m >> (52 - e); }
    if bits < 0 { return 0 - v; }
    return v;
}

// the number with the fraction cut off (bits in, bits out)
int __a32_trunc(int bits) {
    int e = ((bits >> 52) & 2047) - 1023;
    int sign = bits & (1 << 63);
    if e < 0 { return sign; }
    if e >= 52 { return bits; }
    int mask = (1 << (52 - e)) - 1;
    return bits & (mask xor (0 - 1));
}

int __a32_floor(int bits) {
    int t = __a32_trunc(bits);
    if bits >= 0 || t == bits { return t; }
    double fl[2];
    int^ fb = (int^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] - 1.0;
    return fb[1];
}

int __a32_ceil(int bits) {
    int t = __a32_trunc(bits);
    if bits < 0 || t == bits { return t; }
    double fl[2];
    int^ fb = (int^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] + 1.0;
    return fb[1];
}

// unsigned decimal print of a 64-bit number
void __a32_print_uint(int v) {
    char buf[32];
    int at = 31;
    if v == 0 {
        buf[at] = '0';
        at -= 1;
    }
    while v != 0 {
        int q = __a32_udiv(v, 10);
        buf[at] = '0' + (v - q * 10);
        at -= 1;
        v = q;
    }
    __wr(__out_fd(), @buf[at + 1], 31 - at);
}

// cout of a double: the same text as j2k_print_f64 of the ARM64 target (6 decimals; infinity, nan; 2^64 and more as d.dddddde+NN)
void __a32_print_f64(int bits) {
    int e = (bits >> 52) & 2047;
    if e == 2047 {
        if (bits & 4503599627370495) != 0 {
            __a32_print_str("nan");
            return;
        }
        if bits < 0 { __a32_print_char(45); }
        __a32_print_str("inf");
        return;
    }
    if bits < 0 {
        __a32_print_char(45);
        bits = bits & 9223372036854775807;
    }
    double fl[1];
    int^ fb = (int^)@fl[0];
    fb[0] = bits;
    double d = fl[0];
    if d < 9223372036854775808.0 {
        int ip = (int)d;
        double fr = (d - (double)ip) * 1000000.0 + 0.5;
        int f = (int)fr;
        if f >= 1000000 {
            f -= 1000000;
            ip += 1;
        }
        __a32_print_int(ip);
        __a32_print_char(46);
        int div = 100000;
        while div > 0 {
            int dg = f / div;
            f = f - dg * div;
            __a32_print_char(48 + dg);
            div = div / 10;
        }
        return;
    }
    if d < 18446744073709551616.0 {
        int u = (int)(d - 9223372036854775808.0) + (1 << 63);
        __a32_print_uint(u);
        __a32_print_str(".000000");
        return;
    }
    __Fp::huge(bits);
}

// a throw that no try block catches: the text goes to the standard error and the program stops with 1
void __a32_uncaught(char^ msg) {
    __a32_errtext("uncaught exception: ");
    __a32_errtext(msg);
    __a32_errtext("\n");
    syscall(94, 1);
}

// ---- the system calls of the program: the structures that the ARM64 table passes (timespec with 64-bit fields ...) have 32-bit fields here
int __a32_sys(int nr, int a0, int a1, int a2, int a3, int a4, int a5) {
    if nr == 101 {                                     // nanosleep(req, rem)
        int^ rq = (int^)a0;
        i32 b[2];
        if a0 != 0 {
            b[0] = (i32)rq[0];
            b[1] = (i32)rq[1];
            return __syscall_raw(nr, (int)@b, a1, a2, a3, a4, a5);
        }
    }
    if nr == 115 {                                     // clock_nanosleep(clock, flags, req, rem)
        int^ rq2 = (int^)a2;
        i32 b2[2];
        if a2 != 0 {
            b2[0] = (i32)rq2[0];
            b2[1] = (i32)rq2[1];
            return __syscall_raw(nr, a0, a1, (int)@b2, a3, a4, a5);
        }
    }
    if nr == 113 {                                     // clock_gettime(clock, ts)
        i32 b3[2];
        b3[0] = 0;
        b3[1] = 0;
        int rc = __syscall_raw(nr, a0, (int)@b3, a2, a3, a4, a5);
        int^ ts = (int^)a1;
        if a1 != 0 && rc == 0 {
            ts[0] = b3[0];
            ts[1] = b3[1];
        }
        return rc;
    }
    if nr == 169 {                                     // gettimeofday(tv, tz)
        i32 b4[2];
        b4[0] = 0;
        b4[1] = 0;
        int rc4 = __syscall_raw(nr, (int)@b4, a1, a2, a3, a4, a5);
        int^ tv = (int^)a0;
        if a0 != 0 && rc4 == 0 {
            tv[0] = b4[0];
            tv[1] = b4[1];
        }
        return rc4;
    }
    if nr == 73 {                                      // ppoll(fds, n, timeout, sigmask, size)
        int^ rq5 = (int^)a2;
        i32 b5[2];
        if a2 != 0 {
            b5[0] = (i32)rq5[0];
            b5[1] = (i32)rq5[1];
            return __syscall_raw(nr, a0, a1, (int)@b5, a3, a4, a5);
        }
    }
    if nr == 221 {                                     // execve(path, argv, envp): the arrays of pointers have 4-byte entries here
        int^ pa = (int^)a1;
        int^ pe = (int^)a2;
        i32 av[256];
        i32 ev[512];
        int ia = 0;
        if a1 != 0 {
            while pa[ia] != 0 && ia < 255 {
                av[ia] = (i32)pa[ia];
                ia += 1;
            }
        }
        av[ia] = 0;
        int ie = 0;
        if a2 != 0 {
            while pe[ie] != 0 && ie < 511 {
                ev[ie] = (i32)pe[ie];
                ie += 1;
            }
        }
        ev[ie] = 0;
        return __syscall_raw(nr, a0, (int)@av, (int)@ev, a3, a4, a5);
    }
    return __syscall_raw(nr, a0, a1, a2, a3, a4, a5);
}
