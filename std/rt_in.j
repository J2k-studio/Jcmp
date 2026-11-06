// Reading the keyboard (jin >> x, cinf >> x): a buffer over file descriptor 0.
char std_in_buf[4096];
i64 std_in_pos;
i64 std_in_len;
char std_in_err[160];              // the text of the last input error (thrown; it must stay alive while the stack is unwound)
i64 std_in_en;

struct __In {
    // the next byte without taking it, or -1 at the end of the input
    static i64 peek() {
        if std_in_pos >= std_in_len {
            i64 n = syscall(63, 0, @std_in_buf, 4096);
            if n <= 0 { return -1; }
            std_in_len = n;
            std_in_pos = 0;
        }
        return std_in_buf[std_in_pos];
    }
    static bool space(i64 c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    static void err_put(char^ s) {
        i64 i = 0;
        while s[i] != 0 && std_in_en < 150 {
            std_in_err[std_in_en] = s[i];
            std_in_en += 1;
            i += 1;
        }
        std_in_err[std_in_en] = 0;
    }
    // throw "invalid input: <what> was expected, but found 'x'": c is the character that was found. The wrong word stays in the input
    // (a program that catches the error skips it with  jin >> word;  see test t173)
    static void bad(char^ what, i64 c) {
        std_in_en = 0;
        __In::err_put("invalid input: ");
        __In::err_put(what);
        __In::err_put(" was expected, but found ");
        if c < 0 || c == 10 || c == 13 {
            __In::err_put("the end of the line");
        } else {
            char one[4];
            one[0] = 39;
            one[1] = (char)c;
            one[2] = 39;
            one[3] = 0;
            __In::err_put((char^)@one);
        }
        throw (char^)@std_in_err;
    }
    // skip white space: the first character of the next word, or -1
    static i64 start() {
        i64 c = __In::peek();
        while c >= 0 && __In::space(c) {
            std_in_pos += 1;
            c = __In::peek();
        }
        return c;
    }
    // a word into a String
    static void str(void^ h) {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a word was expected, but the input has ended"; }
        __Str::clear(h);
        while c >= 0 && !__In::space(c) {
            __Str::push(h, c);
            std_in_pos += 1;
            c = __In::peek();
        }
    }
    // a whole number (an error unless lo <= value <= hi; no limits when lo > hi; uns = 1: no minus sign)
    static i64 num(i64 lo, i64 hi, i64 uns) {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a whole number was expected, but the input has ended"; }
        i64 neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c < '0' || c > '9' { __In::bad("a whole number", c); }
        if neg == 1 && uns == 1 { __In::bad("a number without a minus sign", '-'); }
        i64 v = 0;
        while c >= '0' && c <= '9' {
            v = v * 10 + (c - '0');
            std_in_pos += 1;
            c = __In::peek();
        }
        if c >= 0 && !__In::space(c) { __In::bad("the end of the number", c); }
        if neg == 1 { v = 0 - v; }
        if lo <= hi && (v < lo || v > hi) { throw "number out of range for this variable (the type cannot hold it)"; }
        return v;
    }
    // a decimal number: 12  -3.5  .5  2e-3
    static double fnum() {
        i64 c = __In::start();
        if c < 0 { throw "end of input: a number was expected, but the input has ended"; }
        i64 neg = 0;
        if c == '-' || c == '+' {
            if c == '-' { neg = 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        i64 mant = 0;
        i64 exp = 0;
        i64 seen = 0;
        while c >= '0' && c <= '9' {
            seen = 1;
            if mant < 100000000000000000 { mant = mant * 10 + (c - '0'); } else { exp += 1; }
            std_in_pos += 1;
            c = __In::peek();
        }
        if c == '.' {
            std_in_pos += 1;
            c = __In::peek();
            while c >= '0' && c <= '9' {
                seen = 1;
                if mant < 100000000000000000 {
                    mant = mant * 10 + (c - '0');
                    exp -= 1;
                }
                std_in_pos += 1;
                c = __In::peek();
            }
        }
        if seen == 0 { __In::bad("a number", c); }
        if c == 'e' || c == 'E' {
            std_in_pos += 1;
            c = __In::peek();
            i64 eneg = 0;
            if c == '-' || c == '+' {
                if c == '-' { eneg = 1; }
                std_in_pos += 1;
                c = __In::peek();
            }
            if c < '0' || c > '9' { __In::bad("the digits of the exponent", c); }
            i64 ev = 0;
            while c >= '0' && c <= '9' {
                if ev < 10000 { ev = ev * 10 + (c - '0'); }
                std_in_pos += 1;
                c = __In::peek();
            }
            if eneg == 1 { exp -= ev; } else { exp += ev; }
        }
        if c >= 0 && !__In::space(c) { __In::bad("the end of the number", c); }
        double v = (double)mant;
        while exp > 0 {
            v = v * 10.0;
            exp -= 1;
        }
        while exp < 0 {
            v = v / 10.0;
            exp += 1;
        }
        if neg == 1 { v = -v; }
        return v;
    }
    // one character
    static i64 ch() {
        i64 c = __In::start();
        if c < 0 { throw "end of input"; }
        std_in_pos += 1;
        return c;
    }
    static i64 put(char^ buf, i64 at, char^ s) {
        i64 i = 0;
        while s[i] != 0 {
            buf[at] = s[i];
            at += 1;
            i += 1;
        }
        return at;
    }
    static i64 putnum(char^ buf, i64 at, i64 v) {
        char d[24];
        i64 n = 0;
        if v == 0 {
            d[0] = '0';
            n = 1;
        }
        while v > 0 {
            d[n] = '0' + v % 10;
            v = v / 10;
            n += 1;
        }
        while n > 0 {
            n -= 1;
            buf[at] = d[n];
            at += 1;
        }
        return at;
    }
    // a word into dst (room for cap characters including the 0): longer words are cut
    static i64 word(char^ dst, i64 cap, char^ name) {
        i64 c = __In::start();
        if c < 0 { throw "end of input"; }
        i64 n = 0;
        i64 cut = 0;
        while c >= 0 && !__In::space(c) {
            if n < cap - 1 {
                dst[n] = c;
                n += 1;
            } else {
                cut = 1;
            }
            std_in_pos += 1;
            c = __In::peek();
        }
        dst[n] = 0;
        if cut == 1 {
            char m[200];
            i64 at = __In::put(@m, 0, "warning: input truncated — '");
            at = __In::put(@m, at, name);
            at = __In::put(@m, at, "' accepts max ");
            at = __In::putnum(@m, at, cap - 1);
            at = __In::put(@m, at, " characters (char[");
            at = __In::putnum(@m, at, cap);
            at = __In::put(@m, at, "] - 1 for \\0)\n");
            syscall(64, 2, @m, at);
        }
        return n;
    }
}

