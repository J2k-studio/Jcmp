// The routines that the ARM32 target needs and that the ARM64 target has as assembly in the compiler (docs/design/15-arm32.md).
// They are written in J2K and made by the same back end as the program; the compiler calls them by name (__a32_*) for the operations that
// a 32 bit machine has no instruction for (division, the high half of a product) and for the printing of jout.
// Nothing here is used by the ARM64 target: a function that nobody calls is not made.

// unsigned 64-bit a / b, a % b (0 when b is 0); the numbers below 2^52 are divided as doubles (exact: a / b is never rounded up to the next
// whole number when a < 2^52), the others by shift and subtract
i64 __a32_udiv(i64 a, i64 b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        return (i64)(da / db);
    }
    i64 top = 1 << 63;
    i64 bt = b xor top;
    i64 q = 0;
    i64 r = 0;
    i64 i = 63;
    while i >= 0 {
        i64 carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
            q = q | (1 << i);
        }
        i -= 1;
    }
    return q;
}

i64 __a32_umod(i64 a, i64 b) {
    if b == 0 { return 0; }
    if a >= 0 && a < 4503599627370496 && b > 0 && b < 4503599627370496 {
        double da = (double)a;
        double db = (double)b;
        i64 q = (i64)(da / db);
        return a - q * b;
    }
    i64 top = 1 << 63;
    i64 bt = b xor top;
    i64 r = 0;
    i64 i = 63;
    while i >= 0 {
        i64 carry = (r >> 63) & 1;
        r = (r << 1) | ((a >> i) & 1);
        if carry == 1 || (r xor top) >= bt {
            r = r - b;
        }
        i -= 1;
    }
    return r;
}

// signed division: the quotient goes towards 0, the remainder has the sign of a
i64 __a32_sdiv(i64 a, i64 b) {
    if b == 0 { return 0; }
    i64 neg = 0;
    if a < 0 { a = 0 - a; neg = 1 - neg; }
    if b < 0 { b = 0 - b; neg = 1 - neg; }
    i64 q = __a32_udiv(a, b);
    if neg == 1 { return 0 - q; }
    return q;
}

i64 __a32_smod(i64 a, i64 b) {
    if b == 0 { return 0; }
    i64 neg = 0;
    if a < 0 { a = 0 - a; neg = 1; }
    if b < 0 { b = 0 - b; }
    i64 r = __a32_umod(a, b);
    if neg == 1 { return 0 - r; }
    return r;
}

// __a32_mulhs (the high 64 bits of the signed 128-bit product a * b) is a routine by hand in the back end (jc_a32.j, a32_emit_exc)

// the start: the stack has 4-byte words (argc, the pointers of argv, 0, the pointers of the environment, 0); the programs (argc(), arg(i), Env)
// read 8-byte words: a copy in that form is made and the entry gives its address to the global area
i64 __a32_fixargs(i64 sp) {
    i32^ old = (i32^)sp;
    i64 w = (old[0] & 4294967295) + 2;
    while (old[w] & 4294967295) != 0 { w += 1; }
    // after the environment come the pairs of the auxiliary vector: (1 << 17) of AT_HWCAP (16) says that the CPU has udiv / sdiv (the global area is at 0x10000000, the flag at 872)
    i64 k = w + 1;
    while (old[k] & 4294967295) != 0 {
        if (old[k] & 4294967295) == 16 && ((old[k + 1] & 4294967295) & 131072) != 0 {
            i64^ gflag = (i64^)268435456;
            gflag[109] = 1;
        }
        k += 2;
    }
    i64 mem = syscall(222, 0, (w + 2) * 8, 3, 34, -1, 0);
    i64^ nw = (i64^)mem;
    i64 j = 0;
    while j <= w {
        nw[j] = old[j] & 4294967295;
        j += 1;
    }
    return mem;
}

// the copy of j2k_copy / j2k_copy16 (source, -, bytes (a multiple of 8), destination)
void __a32_copy(i64 s, i64 u, i64 n, i64 d) {
    i64^ ps = (i64^)s;
    i64^ pd = (i64^)d;
    i64 k = 0;
    while k * 8 < n {
        pd[k] = ps[k];
        k += 1;
    }
}

void __a32_copy16(i64 s, i64 u, i64 n, i64 d) {
    __a32_copy(s, u, n, d);
}

void __a32_divzero() {
    __panic("division by zero");
}

// the signal handler for SIGSEGV (called by the entry stub with the arguments of the kernel put in our own form)
void __a32_hex(i64 v) {
    char b[16];
    i64 i = 7;
    while i >= 0 {
        i64 dgt = (v >> (4 * i)) & 15;
        if dgt < 10 { b[7 - i] = '0' + dgt; } else { b[7 - i] = 'a' + dgt - 10; }
        i -= 1;
    }
    b[8] = 0;
    syscall(64, 2, @b, 8);
}

void __a32_segv(i64 sig, i64 info, i64 uc) {
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
    i64 n = 0;
    while s[n] != 0 { n += 1; }
    syscall(64, 2, s, n);
}

void __a32_print_str(char^ s) {
    i64 n = 0;
    while s[n] != 0 { n += 1; }
    __wr(__out_fd(), s, n);
}

void __a32_print_char(i64 c) {
    char b[8];
    b[0] = c;
    __wr(__out_fd(), @b, 1);
}

void __a32_print_int(i64 v) {
    char buf[32];
    i64 at = 31;
    i64 u = v;
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
        i64 q = __a32_udiv(u, 10);
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
i64 __a32_d2i(i64 bits) {
    i64 e = ((bits >> 52) & 2047) - 1023;
    if e < 0 { return 0; }
    i64 m = (bits & 4503599627370495) | 4503599627370496;
    i64 v = 0;
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
i64 __a32_trunc(i64 bits) {
    i64 e = ((bits >> 52) & 2047) - 1023;
    i64 sign = bits & (1 << 63);
    if e < 0 { return sign; }
    if e >= 52 { return bits; }
    i64 mask = (1 << (52 - e)) - 1;
    return bits & (mask xor (0 - 1));
}

i64 __a32_floor(i64 bits) {
    i64 t = __a32_trunc(bits);
    if bits >= 0 || t == bits { return t; }
    double fl[2];
    i64^ fb = (i64^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] - 1.0;
    return fb[1];
}

i64 __a32_ceil(i64 bits) {
    i64 t = __a32_trunc(bits);
    if bits < 0 || t == bits { return t; }
    double fl[2];
    i64^ fb = (i64^)@fl[0];
    fb[0] = t;
    fl[1] = fl[0] + 1.0;
    return fb[1];
}

// unsigned decimal print of a 64-bit number
void __a32_print_uint(i64 v) {
    char buf[32];
    i64 at = 31;
    if v == 0 {
        buf[at] = '0';
        at -= 1;
    }
    while v != 0 {
        i64 q = __a32_udiv(v, 10);
        buf[at] = '0' + (v - q * 10);
        at -= 1;
        v = q;
    }
    __wr(__out_fd(), @buf[at + 1], 31 - at);
}

// jout of a double: the same text as j2k_print_f64 of the ARM64 target (6 decimals; infinity, nan; 2^64 and more as d.dddddde+NN)
void __a32_print_f64(i64 bits) {
    i64 e = (bits >> 52) & 2047;
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
    i64^ fb = (i64^)@fl[0];
    fb[0] = bits;
    double d = fl[0];
    if d < 9223372036854775808.0 {
        i64 ip = (i64)d;
        double fr = (d - (double)ip) * 1000000.0 + 0.5;
        i64 f = (i64)fr;
        if f >= 1000000 {
            f -= 1000000;
            ip += 1;
        }
        __a32_print_int(ip);
        __a32_print_char(46);
        i64 div = 100000;
        while div > 0 {
            i64 dg = f / div;
            f = f - dg * div;
            __a32_print_char(48 + dg);
            div = div / 10;
        }
        return;
    }
    if d < 18446744073709551616.0 {
        i64 u = (i64)(d - 9223372036854775808.0) + (1 << 63);
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
i64 __a32_sys(i64 nr, i64 a0, i64 a1, i64 a2, i64 a3, i64 a4, i64 a5) {
    if nr == 101 {                                     // nanosleep(req, rem)
        i64^ rq = (i64^)a0;
        i32 b[2];
        if a0 != 0 {
            b[0] = (i32)rq[0];
            b[1] = (i32)rq[1];
            return __syscall_raw(nr, (i64)@b, a1, a2, a3, a4, a5);
        }
    }
    if nr == 115 {                                     // clock_nanosleep(clock, flags, req, rem)
        i64^ rq2 = (i64^)a2;
        i32 b2[2];
        if a2 != 0 {
            b2[0] = (i32)rq2[0];
            b2[1] = (i32)rq2[1];
            return __syscall_raw(nr, a0, a1, (i64)@b2, a3, a4, a5);
        }
    }
    if nr == 113 {                                     // clock_gettime(clock, ts)
        i32 b3[2];
        b3[0] = 0;
        b3[1] = 0;
        i64 rc = __syscall_raw(nr, a0, (i64)@b3, a2, a3, a4, a5);
        i64^ ts = (i64^)a1;
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
        i64 rc4 = __syscall_raw(nr, (i64)@b4, a1, a2, a3, a4, a5);
        i64^ tv = (i64^)a0;
        if a0 != 0 && rc4 == 0 {
            tv[0] = b4[0];
            tv[1] = b4[1];
        }
        return rc4;
    }
    if nr == 73 {                                      // ppoll(fds, n, timeout, sigmask, size)
        i64^ rq5 = (i64^)a2;
        i32 b5[2];
        if a2 != 0 {
            b5[0] = (i32)rq5[0];
            b5[1] = (i32)rq5[1];
            return __syscall_raw(nr, a0, a1, (i64)@b5, a3, a4, a5);
        }
    }
    if nr == 221 {                                     // execve(path, argv, envp): the arrays of pointers have 4-byte entries here
        i64^ pa = (i64^)a1;
        i64^ pe = (i64^)a2;
        i32 av[256];
        i32 ev[512];
        i64 ia = 0;
        if a1 != 0 {
            while pa[ia] != 0 && ia < 255 {
                av[ia] = (i32)pa[ia];
                ia += 1;
            }
        }
        av[ia] = 0;
        i64 ie = 0;
        if a2 != 0 {
            while pe[ie] != 0 && ie < 511 {
                ev[ie] = (i32)pe[ie];
                ie += 1;
            }
        }
        ev[ie] = 0;
        return __syscall_raw(nr, a0, (i64)@av, (i64)@ev, a3, a4, a5);
    }
    return __syscall_raw(nr, a0, a1, a2, a3, a4, a5);
}
