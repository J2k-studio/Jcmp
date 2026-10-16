// String: a dynamic array of char (header [length, capacity, data, 1]) whose data always ends
// in a 0 byte after the length, so that the data is also a C-style text (cout, c()).
// An operand is a text (kind 0), another String (kind 1) or one character (kind 2).
char std_str_ch[16];
struct __Str {
    static void^ make(int cap) {
        int^ h = (int^)__Arr::make(1, cap + 1);
        char^ d = (char^)h[2];
        d[0] = 0;
        return (void^)h;
    }
    static int textlen(char^ t) {
        int n = 0;
        while t[n] != 0 { n += 1; }
        return n;
    }
    static void check(void^ hv) {
        if (int)hv == 0 { __panic("the String is null"); }
    }
    // the characters of an operand
    static char^ ptr(void^ x, int k, int slot) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return (char^)h[2];
        }
        if k == 2 {
            std_str_ch[slot * 8] = (int)x;
            std_str_ch[slot * 8 + 1] = 0;
            return @std_str_ch + slot * 8;
        }
        return (char^)x;
    }
    static int len(void^ x, int k) {
        if k == 1 {
            __Str::check(x);
            int^ h = (int^)x;
            return h[0];
        }
        if k == 2 { return 1; }
        return __Str::textlen((char^)x);
    }
    // the whole number v written at the end of r (u = 1: v is read as an unsigned number)
    static void push_int(void^ r, int v, int u) {
        char d[24];
        int n = 0;
        int neg = 0;
        if u == 0 && v < 0 { neg = 1; }
        u64 m = (u64)v;
        if neg == 1 { m = (u64)0 - m; }
        if m == 0 {
            d[0] = '0';
            n = 1;
        }
        while m > 0 {
            d[n] = '0' + (int)(m % 10);
            n += 1;
            m = m / 10;
        }
        if neg == 1 { __Str::push(r, '-'); }
        while n > 0 {
            n -= 1;
            __Str::push(r, d[n]);
        }
    }
    // a new String with the whole number v (u = 1: v is read as an unsigned number)
    static void^ from_int(int v, int u) {
        void^ r = __Str::make(24);
        __Str::push_int(r, v, u);
        return r;
    }
    // a new String with one character
    static void^ from_char(int c) {
        void^ r = __Str::make(2);
        __Str::push(r, c);
        return r;
    }
    // the digits of n written with exactly `width` digits (leading zeros), without the trailing zeros: for the part after the point
    static void frac_digits(void^ r, int n, int width) {
        char d[24];
        int k = width;
        while k > 0 {
            k -= 1;
            d[k] = '0' + n % 10;
            n = n / 10;
        }
        int last = width;
        while last > 0 && d[last - 1] == '0' { last -= 1; }
        int i = 0;
        while i < last {
            __Str::push(r, d[i]);
            i += 1;
        }
    }
    // a new String with a decimal number: up to 15 significant digits, no zeros at the end (0.1, 2.5, 100, 1.5e+20, nan, inf)
    static void^ from_double(double x) {
        void^ r = __Str::make(32);
        if x != x {
            __Str::append(r, "nan", 0);
            return r;
        }
        if x == 0.0 {
            __Str::push(r, '0');
            return r;
        }
        if x < 0.0 {
            __Str::push(r, '-');
            x = 0.0 - x;
        }
        if x - x != 0.0 {
            __Str::append(r, "inf", 0);
            return r;
        }
        if x >= 1.0e15 || x < 1.0e-5 {
            // the form  d.ddde+XX : bring the number into 1 .. 10
            int e = 0;
            while x >= 10.0 {
                x = x / 10.0;
                e += 1;
            }
            while x < 1.0 {
                x = x * 10.0;
                e -= 1;
            }
            int d0 = (int)x;
            int f = (int)((x - (double)d0) * 1.0e14 + 0.5);
            if f >= 100000000000000 {
                f -= 100000000000000;
                d0 += 1;
            }
            if d0 >= 10 {
                d0 = 1;
                e += 1;
            }
            __Str::push(r, '0' + d0);
            if f > 0 {
                __Str::push(r, '.');
                __Str::frac_digits(r, f, 14);
            }
            __Str::push(r, 'e');
            if e < 0 {
                __Str::push(r, '-');
                e = 0 - e;
            } else {
                __Str::push(r, '+');
            }
            if e < 10 { __Str::push(r, '0'); }
            __Str::push_int(r, e, 0);
            return r;
        }
        int ip = (int)x;
        double frac = x - (double)ip;
        // the number of digits after the point: 15 digits in all
        int fd = 15;
        int t = ip;
        while t > 0 {
            fd -= 1;
            t = t / 10;
        }
        if ip == 0 {
            double q = frac;
            int zeros = 0;
            while q < 0.1 && zeros < 6 {
                q = q * 10.0;
                zeros += 1;
            }
            fd = 15 + zeros;
        }
        if fd < 0 { fd = 0; }
        int pw = 1;
        int k = 0;
        while k < fd {
            pw = pw * 10;
            k += 1;
        }
        int f = (int)(frac * (double)pw + 0.5);
        if f >= pw {
            f -= pw;
            ip += 1;
        }
        __Str::push_int(r, ip, 0);

        if f > 0 {
            __Str::push(r, '.');
            __Str::frac_digits(r, f, fd);
        }
        return r;
    }
    // a new String holding a copy of the text
    static void^ from(char^ t) {
        int n = __Str::textlen(t);
        int^ h = (int^)__Str::make(n);
        Mem::copy((void^)h[2], (void^)t, n);
        char^ d = (char^)h[2];
        d[n] = 0;
        h[0] = n;
        return (void^)h;
    }
    // a copy of a String
    static void^ clone(void^ x) {
        return __Str::cat(x, 1, (void^)"", 0);
    }
    // a new String: a followed by b
    static void^ cat(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        int^ h = (int^)__Str::make(na + nb);
        char^ d = (char^)h[2];
        Mem::copy((void^)d, (void^)__Str::ptr(a, ka, 0), na);
        Mem::copy((void^)(d + na), (void^)__Str::ptr(b, kb, 1), nb);
        d[na + nb] = 0;
        h[0] = na + nb;
        return (void^)h;
    }
    // a followed by b, in a (returns a)
    static void^ append(void^ a, void^ b, int kb) {
        __Str::check(a);
        if kb == 1 && (int)b == (int)a {                 // s.append(s): the data may move
            void^ same = __Str::clone(a);
            __Str::append(a, same, 1);
            __Arr::free(same);
            return a;
        }
        int^ h = (int^)a;
        int nb = __Str::len(b, kb);
        char^ src = __Str::ptr(b, kb, 1);
        __Arr::grow(h, h[0] + nb + 1);
        Mem::copy((void^)(h[2] + h[0]), (void^)src, nb);
        h[0] += nb;
        char^ d = (char^)h[2];
        d[h[0]] = 0;
        return a;
    }
    static void push(void^ a, int c) {
        __Str::check(a);
        int^ h = (int^)a;
        __Arr::grow(h, h[0] + 2);
        char^ d = (char^)h[2];
        d[h[0]] = c;
        h[0] += 1;
        d[h[0]] = 0;
    }
    static int pop(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        if h[0] == 0 { __panic("pop from an empty String"); }
        h[0] -= 1;
        char^ d = (char^)h[2];
        int c = d[h[0]];
        d[h[0]] = 0;
        return c;
    }
    static void clear(void^ a) {
        __Str::check(a);
        int^ h = (int^)a;
        h[0] = 0;
        char^ d = (char^)h[2];
        d[0] = 0;
    }
    // 1 if the two operands hold the same characters
    static int eq(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        if na != nb { return 0; }
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        int i = 0;
        while i < na {
            if pa[i] != pb[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // -1, 0 or 1: a is before, the same as, or after b (by the codes of the bytes, like strcmp)
    static int order(void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        int nb = __Str::len(b, kb);
        char^ pa = __Str::ptr(a, ka, 0);
        char^ pb = __Str::ptr(b, kb, 1);
        int i = 0;
        while i < na && i < nb {
            int ca = pa[i] & 255;
            int cb = pb[i] & 255;
            if ca < cb { return 0 - 1; }
            if ca > cb { return 1; }
            i += 1;
        }
        if na < nb { return 0 - 1; }
        if na > nb { return 1; }
        return 0;
    }
    // the first place of t in s at or after `from`, or -1
    static int find(void^ s, void^ t, int kt) {
        int ns = __Str::len(s, 1);
        int nt = __Str::len(t, kt);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pt = __Str::ptr(t, kt, 1);
        int i = 0;
        while i + nt <= ns {
            int j = 0;
            while j < nt && ps[i + j] == pt[j] { j += 1; }
            if j == nt { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // a new String: the characters a .. b - 1
    static void^ slice(void^ s, int a, int b) {
        int n = __Str::len(s, 1);
        if a < 0 || b > n || a > b { __panic("String slice out of range"); }
        int^ h = (int^)__Str::make(b - a);
        char^ d = (char^)h[2];
        char^ ps = __Str::ptr(s, 1, 0);
        Mem::copy((void^)d, (void^)(ps + a), b - a);
        d[b - a] = 0;
        h[0] = b - a;
        return (void^)h;
    }
    static char^ c(void^ s) {
        return __Str::ptr(s, 1, 0);
    }
    // hash of a whole number / of a String (FNV-1a over the bytes)
    static int hashint(int x) {
        int h = x * -7046029254386353131;
        return h xor (h shr 29);
    }
    static int hash(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int h = -3750763034362895579;
        int i = 0;
        while p[i] != 0 {
            h = (h xor p[i]) * 1099511628211;
            i += 1;
        }
        return h xor (h shr 29);
    }
    // String[]: n places (new ones are null, cut ones are freed)
    static void aresize(void^ hv, int n) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if n < 0 { __panic("negative array size"); }
        int^ el = (int^)h[2];
        int i = n;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::grow(h, n);
        el = (int^)h[2];
        i = h[0];
        while i < n {
            el[i] = 0;
            i += 1;
        }
        h[0] = n;
    }
    // -1, 0, 1: a before, equal to, after b (bytes)
    static int cmp(void^ a, void^ b) {
        char^ pa = __Str::ptr(a, 1, 0);
        char^ pb = __Str::ptr(b, 1, 1);
        int i = 0;
        while pa[i] != 0 && pa[i] == pb[i] { i += 1; }
        if pa[i] == pb[i] { return 0; }
        if pa[i] < pb[i] { return 0 - 1; }
        return 1;
    }

    // ---- more String functions (the bytes are treated as ASCII where case matters)
    static bool isspace(int c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    // a new String: s without the white space at both ends
    static void^ trim(void^ s) {
        int n = __Str::len(s, 1);
        char^ p = __Str::ptr(s, 1, 0);
        int a = 0;
        int b = n;
        while a < b && __Str::isspace(p[a]) { a += 1; }
        while b > a && __Str::isspace(p[b - 1]) { b -= 1; }
        return __Str::slice(s, a, b);
    }
    // ---- UTF-8: len counts bytes; these work on characters (code points)
    // the upper case of a code point (ASCII, Latin-1, Latin Extended-A, Greek, Cyrillic); others stay
    static int cp_upper(int c) {
        if c < 128 {
            if c >= 'a' && c <= 'z' { return c - 32; }
            return c;
        }
        if c >= 0xE0 && c <= 0xFE && c != 0xF7 { return c - 32; }
        if c == 0xFF { return 0x178; }
        if c >= 0x100 && c <= 0x137 && c != 0x130 && c != 0x131 && c % 2 == 1 { return c - 1; }
        if c >= 0x139 && c <= 0x148 && c % 2 == 0 { return c - 1; }
        if c >= 0x14A && c <= 0x177 && c % 2 == 1 { return c - 1; }
        if c >= 0x17A && c <= 0x17E && c % 2 == 0 { return c - 1; }
        if c == 0x3C2 { return 0x3A3; }
        if c >= 0x3B1 && c <= 0x3C9 { return c - 32; }
        if c >= 0x430 && c <= 0x44F { return c - 32; }
        if c >= 0x450 && c <= 0x45F { return c - 80; }
        return c;
    }
    static int cp_lower(int c) {
        if c < 128 {
            if c >= 'A' && c <= 'Z' { return c + 32; }
            return c;
        }
        if c >= 0xC0 && c <= 0xDE && c != 0xD7 { return c + 32; }
        if c == 0x178 { return 0xFF; }
        if c >= 0x100 && c <= 0x137 && c != 0x130 && c != 0x131 && c % 2 == 0 { return c + 1; }
        if c >= 0x139 && c <= 0x148 && c % 2 == 1 { return c + 1; }
        if c >= 0x14A && c <= 0x177 && c % 2 == 0 { return c + 1; }
        if c >= 0x179 && c <= 0x17D && c % 2 == 1 { return c + 1; }
        if c >= 0x391 && c <= 0x3A9 && c != 0x3A2 { return c + 32; }
        if c >= 0x410 && c <= 0x42F { return c + 32; }
        if c >= 0x400 && c <= 0x40F { return c + 80; }
        return c;
    }
    // r (a fresh copy) changed in place to upper (up = 1) or lower case; every mapped letter keeps its size
    static void map_case(void^ r, int up) {
        char^ p = __Str::ptr(r, 1, 0);
        int i = 0;
        while p[i] != 0 {
            int b = p[i] & 255;
            if b < 128 {
                if up == 1 { p[i] = (char)__Str::cp_upper(b); } else { p[i] = (char)__Str::cp_lower(b); }
                i += 1;
            } else if b >= 0xC2 && b <= 0xDF && (p[i + 1] & 0xC0) == 0x80 {
                int c = ((b & 0x1F) << 6) | (p[i + 1] & 0x3F);
                if up == 1 { c = __Str::cp_upper(c); } else { c = __Str::cp_lower(c); }
                p[i] = (char)(0xC0 | (c >> 6));
                p[i + 1] = (char)(0x80 | (c & 0x3F));
                i += 2;
            } else {
                i += 1;
            }
        }
    }
    static void^ upper(void^ s) {
        void^ r = __Str::clone(s);
        __Str::map_case(r, 1);
        return r;
    }
    static void^ lower(void^ s) {
        void^ r = __Str::clone(s);
        __Str::map_case(r, 0);
        return r;
    }
    // the number of characters (code points)
    static int count(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int k = 0;
        int i = 0;
        while i < n {
            if (p[i] & 0xC0) != 0x80 { k += 1; }
            i += 1;
        }
        return k;
    }
    // the size in bytes of the character that starts at byte i
    static int cp_size(char^ p, int i, int n) {
        int b = p[i] & 255;
        int k = 1;
        if b >= 0xF0 { k = 4; } else if b >= 0xE0 { k = 3; } else if b >= 0xC0 { k = 2; }
        if i + k > n { k = n - i; }
        return k;
    }
    // a String[] with every character as a String of its own
    static void^ chars(void^ s) {
        void^ r = __Arr::make(8, 4);
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n {
            int k = __Str::cp_size(p, i, n);
            __Str::apush(r, __Str::slice(s, i, i + k));
            i += k;
        }
        return r;
    }
    // the character number idx (counted from 0) as a String
    static void^ char_at(void^ s, int idx) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        int k = 0;
        while i < n {
            int sz = __Str::cp_size(p, i, n);
            if k == idx { return __Str::slice(s, i, i + sz); }
            i += sz;
            k += 1;
        }
        __panic("char_at: the position is out of range");
        return __Str::make(1);
    }
    static int starts_with(void^ s, void^ x, int kx) {
        int ns = __Str::len(s, 1);
        int nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        int i = 0;
        while i < nx {
            if ps[i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    static int ends_with(void^ s, void^ x, int kx) {
        int ns = __Str::len(s, 1);
        int nx = __Str::len(x, kx);
        if nx > ns { return 0; }
        char^ ps = __Str::ptr(s, 1, 0);
        char^ px = __Str::ptr(x, kx, 1);
        int i = 0;
        while i < nx {
            if ps[ns - nx + i] != px[i] { return 0; }
            i += 1;
        }
        return 1;
    }
    // a new String: every a in s replaced by b
    static void^ replace(void^ s, void^ a, int ka, void^ b, int kb) {
        int na = __Str::len(a, ka);
        if na == 0 { __panic("replace: the text to look for is empty"); }
        void^ r = __Str::make(__Str::len(s, 1));
        int ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pa = __Str::ptr(a, ka, 1);
        int i = 0;
        while i < ns {
            int j = 0;
            while j < na && i + j < ns && ps[i + j] == pa[j] { j += 1; }
            if j == na {
                __Str::append(r, b, kb);
                i += na;
            } else {
                __Str::push(r, ps[i]);
                i += 1;
            }
        }
        return r;
    }
    // a new String: s repeated n times
    static void^ repeat(void^ s, int n) {
        void^ r = __Str::make(__Str::len(s, 1) * (n + 1));
        int i = 0;
        while i < n {
            __Str::append(r, s, 1);
            i += 1;
        }
        return r;
    }
    // the whole String as a number (an optional sign and digits); throws "not a number"
    static int to_int(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        int neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
        int v = 0;
        while i < n && p[i] >= '0' && p[i] <= '9' {
            v = v * 10 + (p[i] - '0');
            i += 1;
        }
        while i < n && __Str::isspace(p[i]) { i += 1; }
        if i != n { throw "not a number"; }
        if neg == 1 { return 0 - v; }
        return v;
    }
    // the whole String as a decimal number (sign, digits, a point, digits, e and an exponent); throws "not a number"
    static double to_double(void^ s) {
        char^ p = __Str::ptr(s, 1, 0);
        int n = __Str::len(s, 1);
        int i = 0;
        while i < n && __Str::isspace(p[i]) { i += 1; }
        int neg = 0;
        if i < n && (p[i] == '-' || p[i] == '+') {
            if p[i] == '-' { neg = 1; }
            i += 1;
        }
        double v = 0.0;
        int any = 0;
        while i < n && p[i] >= '0' && p[i] <= '9' {
            v = v * 10.0 + (double)(p[i] - '0');
            any = 1;
            i += 1;
        }
        if i < n && p[i] == '.' {
            i += 1;
            double scale = 0.1;
            while i < n && p[i] >= '0' && p[i] <= '9' {
                v = v + (double)(p[i] - '0') * scale;
                scale = scale / 10.0;
                any = 1;
                i += 1;
            }
        }
        if any == 0 { throw "not a number"; }
        if i < n && (p[i] == 'e' || p[i] == 'E') {
            i += 1;
            int eneg = 0;
            if i < n && (p[i] == '-' || p[i] == '+') {
                if p[i] == '-' { eneg = 1; }
                i += 1;
            }
            if i >= n || p[i] < '0' || p[i] > '9' { throw "not a number"; }
            int e = 0;
            while i < n && p[i] >= '0' && p[i] <= '9' {
                e = e * 10 + (p[i] - '0');
                i += 1;
            }
            while e > 0 {
                if eneg == 1 { v = v / 10.0; } else { v = v * 10.0; }
                e -= 1;
            }
        }
        while i < n && __Str::isspace(p[i]) { i += 1; }
        if i != n { throw "not a number"; }
        if neg == 1 { return 0.0 - v; }
        return v;
    }
    // a String[] with the pieces of s between the separators (an empty separator throws)
    static void^ split(void^ s, void^ sep, int ksep) {
        int nsep = __Str::len(sep, ksep);
        if nsep == 0 { __panic("split: the separator is empty"); }
        void^ r = __Arr::make(8, 4);
        int ns = __Str::len(s, 1);
        char^ ps = __Str::ptr(s, 1, 0);
        char^ pp = __Str::ptr(sep, ksep, 1);
        int start = 0;
        int i = 0;
        while i + nsep <= ns {
            int j = 0;
            while j < nsep && ps[i + j] == pp[j] { j += 1; }
            if j == nsep {
                __Str::apush(r, __Str::slice(s, start, i));
                i += nsep;
                start = i;
            } else {
                i += 1;
            }
        }
        __Str::apush(r, __Str::slice(s, start, ns));
        return r;
    }
    // a new String: the elements of a String[] with sep between them
    static void^ ajoin(void^ hv, void^ sep, int ksep) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        void^ r = __Str::make(16);
        int i = 0;
        while i < h[0] {
            if i > 0 { __Str::append(r, sep, ksep); }
            __Str::append(r, (void^)el[i], 1);
            i += 1;
        }
        return r;
    }

    // ---- String[] : an array whose elements are String headers owned by the array
    // a deep copy of a String[] (every String is copied)
    static void^ aclone(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        void^ rv = __Arr::make(8, h[0]);
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            if el[i] == 0 {
                int^ slot = (int^)__Arr::slot(rv);
                slot[0] = 0;
            } else {
                __Str::apush(rv, __Str::clone((void^)el[i]));
            }
            i += 1;
        }
        return rv;
    }
    static void aprep(void^ hv) {
        if (int)hv == 0 { __panic("the array is null"); }
    }
    // the elements and the array are given back
    static void free_all(void^ hv) {
        int^ h = (int^)hv;
        if (int)h == 0 { return; }
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        __Arr::free(hv);
    }
    static void clear_all(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            __Arr::free((void^)el[i]);
            i += 1;
        }
        h[0] = 0;
    }
    // append s (the array takes it over)
    static void apush(void^ hv, void^ s) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::slot(hv);
        slot[0] = (int)s;
    }
    // remove the last one and give it to the caller
    static void^ apop(void^ hv) {
        __Str::aprep(hv);
        int^ slot = (int^)__Arr::pop(hv);
        return (void^)slot[0];
    }
    // put s (taken over) at place i
    static void ainsert(void^ hv, int i, void^ s) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i > h[0] { __panic("insert position out of range"); }
        __Arr::grow(h, h[0] + 1);
        int^ el = (int^)h[2];
        int k = h[0];
        while k > i {
            el[k] = el[k - 1];
            k -= 1;
        }
        el[i] = (int)s;
        h[0] += 1;
    }
    // remove the one at place i (it is freed)
    static void aremove(void^ hv, int i) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        if i < 0 || i >= h[0] { __panic("remove position out of range"); }
        int^ el = (int^)h[2];
        __Arr::free((void^)el[i]);
        int k = i;
        while k + 1 < h[0] {
            el[k] = el[k + 1];
            k += 1;
        }
        h[0] -= 1;
    }
    // the place of the first element equal to the operand, or -1
    static int aindex(void^ hv, void^ x, int kx) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int i = 0;
        while i < h[0] {
            if __Str::eq((void^)el[i], 1, x, kx) == 1 { return i; }
            i += 1;
        }
        return 0 - 1;
    }
    // sort ascending (heap sort, no extra memory)
    static void asort(void^ hv) {
        __Str::aprep(hv);
        int^ h = (int^)hv;
        int^ el = (int^)h[2];
        int n = h[0];
        int start = n / 2 - 1;
        while start >= 0 {
            __Str::asift(el, start, n);
            start -= 1;
        }
        int end = n - 1;
        while end > 0 {
            int t = el[0];
            el[0] = el[end];
            el[end] = t;
            __Str::asift(el, 0, end);
            end -= 1;
        }
    }
    static void asift(int^ el, int root, int n) {
        while true {
            int child = root * 2 + 1;
            if child >= n { return; }
            if child + 1 < n && __Str::cmp((void^)el[child], (void^)el[child + 1]) < 0 { child += 1; }
            if __Str::cmp((void^)el[root], (void^)el[child]) >= 0 { return; }
            int t = el[root];
            el[root] = el[child];
            el[child] = t;
            root = child;
        }
    }
}

