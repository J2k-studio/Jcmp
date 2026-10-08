// Str: functions on 0-terminated text (a char array, a string literal or a char^)
struct Str {
    static int len(char^ s) {
        int n = 0;
        while s[n] != 0 { n += 1; }
        return n;
    }
    static bool eq(char^ a, char^ b) {
        int i = 0;
        while a[i] != 0 && b[i] != 0 {
            if a[i] != b[i] { return false; }
            i += 1;
        }
        return a[i] == b[i];
    }
    // < 0, 0 or > 0 like strcmp
    static int cmp(char^ a, char^ b) {
        int i = 0;
        while a[i] != 0 && a[i] == b[i] { i += 1; }
        return a[i] - b[i];
    }
    // copy src into dst (room for cap characters including the 0); returns the length
    static int copy(char^ dst, int cap, char^ src) {
        int i = 0;
        while src[i] != 0 && i < cap - 1 {
            dst[i] = src[i];
            i += 1;
        }
        if cap > 0 { dst[i] = 0; }
        return i;
    }
    // add src to the end of dst; returns the new length
    static int append(char^ dst, int cap, char^ src) {
        int n = Str::len(dst);
        int i = 0;
        while src[i] != 0 && n + i < cap - 1 {
            dst[n + i] = src[i];
            i += 1;
        }
        dst[n + i] = 0;
        return n + i;
    }
    // index of the first t in s, or -1
    static int find(char^ s, char^ t) {
        int n = Str::len(s);
        int m = Str::len(t);
        int i = 0;
        while i + m <= n {
            int j = 0;
            while j < m && s[i + j] == t[j] { j += 1; }
            if j == m { return i; }
            i += 1;
        }
        return -1;
    }
    static bool starts_with(char^ s, char^ prefix) {
        int i = 0;
        while prefix[i] != 0 {
            if s[i] != prefix[i] { return false; }
            i += 1;
        }
        return true;
    }
    // leading spaces, an optional sign, then digits (stops at the first other character)
    static int to_int(char^ s) {
        int i = 0;
        while s[i] == 32 || s[i] == 9 { i += 1; }
        int neg = 0;
        if s[i] == '-' {
            neg = 1;
            i += 1;
        } else if s[i] == '+' {
            i += 1;
        }
        int v = 0;
        while s[i] >= '0' && s[i] <= '9' {
            v = v * 10 + (s[i] - '0');
            i += 1;
        }
        if neg == 1 { return 0 - v; }
        return v;
    }
    // write v as text into dst (room for cap characters); returns the length
    static int from_int(char^ dst, int cap, int v) {
        char tmp[24];
        int n = 0;
        int neg = 0;
        if v < 0 {
            neg = 1;
            v = 0 - v;
        }
        if v == 0 {
            tmp[0] = '0';
            n = 1;
        }
        while v > 0 {
            tmp[n] = '0' + v % 10;
            v = v / 10;
            n += 1;
        }
        int total = n + neg;
        if total + 1 > cap { return -1; }
        int k = 0;
        if neg == 1 {
            dst[0] = '-';
            k = 1;
        }
        while n > 0 {
            n -= 1;
            dst[k] = tmp[n];
            k += 1;
        }
        dst[k] = 0;
        return total;
    }
}
