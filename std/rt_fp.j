// Printing a double that is 2^64 or more (coutf calls this from j2k_print_f64): d.dddddde+NN, the sign is written by the caller.

// ---- the standard output is buffered (64 KB in the global area: the word 110 = bytes used, 111 = the mode: 0 not looked at,
// 1 buffered, 2 not buffered). A terminal is not buffered (a program that talks to a person); a thread makes it unbuffered.
// It is written out at the end of the program, before the standard error text of a panic / uncaught exception / crash, before a new process
// (fork / execve) and before Sys::write.
void __flush() {
    int^ g = (int^)268435456;
    int n = g[110];
    g[110] = 0;
    int off = 0;
    while off < n {
        int r = syscall(64, 1, (char^)(268435456 + 896 + off), n - off);
        if r <= 0 { break; }
        off += r;
    }
}

// the same as write(fd, p, n) for the program's output
void __wr(int fd, char^ p, int n) {
    if fd != 1 {
        syscall(64, fd, p, n);
        return;
    }
    int^ g = (int^)268435456;
    int mode = g[111];
    if mode == 0 {
        char t[64];
        mode = 1;
        if syscall(29, 1, 21505, @t) == 0 { mode = 2; }
        g[111] = mode;
    }
    if mode == 2 {
        int off = 0;
        while off < n {
            int r = syscall(64, 1, p + off, n - off);
            if r <= 0 { break; }
            off += r;
        }
        return;
    }
    if g[110] + n > 65536 { __flush(); }
    if n >= 65536 {
        int off2 = 0;
        while off2 < n {
            int r2 = syscall(64, 1, p + off2, n - off2);
            if r2 <= 0 { break; }
            off2 += r2;
        }
        return;
    }
    char^ dst = (char^)(268435456 + 896 + g[110]);
    for i in 0..n { dst[i] = p[i]; }
    g[110] += n;
}

// a thread is made: from now on every write goes straight out (no lock around the buffer)
void __out_unbuffer() {
    __flush();
    int^ g = (int^)268435456;
    g[111] = 2;
}

// cout << a bool: true or false
void __print_bool(int v) {
    if v != 0 {
        __wr(__out_fd(), "true", 4);
    } else {
        __wr(__out_fd(), "false", 5);
    }
}

// cout << a pointer or an address: 0x and the digits in hex (0x0 for null)
void __print_ptr(int v) {
    char buf[24];
    int at = 22;
    if v == 0 {
        buf[at] = '0';
        at -= 1;
    }
    int x = v;
    int k = 0;
    while k < 16 && x != 0 {
        int d = x & 15;
        if d < 10 { buf[at] = (char)(48 + d); } else { buf[at] = (char)(87 + d); }
        at -= 1;
        x = (x >> 4) & 1152921504606846975;
        k += 1;
    }
    buf[at] = 'x';
    at -= 1;
    buf[at] = '0';
    at -= 1;
    __wr(__out_fd(), @buf[at + 1], 22 - at);
}

// the file that cout writes to: 1, or 2 inside a statement with cerr (the word at 864 of the global area, 0 or 1, plus 1)
int __out_fd() {
    int^ gout = (int^)268435456;
    return gout[108] + 1;
}

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
        __wr(__out_fd(), @buf, n);
    }
}
