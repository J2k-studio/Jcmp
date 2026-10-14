// Fmt: numbers and text laid out for people.
//   Fmt::fixed(3.14159, 2) -> "3.14"      Fmt::pad_left("7", 3, '0') -> "007"      Fmt::thousands(1234567) -> "1,234,567"
//   Fmt::hex(255) -> "ff"      Fmt::bin(5) -> "101"      Fmt::percent(0.256, 1) -> "25.6%"      Fmt::bytes(1536) -> "1.5 KB"
struct Fmt {
    // s with c added on the left until it has `width` characters (a longer text stays as it is)
    static String pad_left(String s, int width, char c) {
        String r = "";
        int n = width - s.len;
        for i in 0..n { r.push(c); }
        r += s;
        return r;
    }
    // s with c added on the right
    static String pad_right(String s, int width, char c) {
        String r = s;
        int n = width - s.len;
        for i in 0..n { r.push(c); }
        return r;
    }
    // the number x with exactly `digits` digits after the point (0 .. 15), rounded half away from zero
    static String fixed(double x, int digits) {
        if digits < 0 { digits = 0; }
        if digits > 15 { digits = 15; }
        bool neg = x < 0.0;
        double v = x;
        if neg { v = 0.0 - v; }
        double scale = 1.0;
        for i in 0..digits { scale = scale * 10.0; }
        double r = v * scale + 0.5;
        if r >= 9.0e18 { return str(x); }
        int n = (int)r;
        int sc = (int)scale;
        String s = str(n / sc);
        if digits > 0 {
            String f = str(n % sc);
            s += ".";
            s += Fmt::pad_left(f, digits, '0');
        }
        if neg && n != 0 { return "-" + s; }
        return s;
    }
    // the digits of n (n >= 0) in the base b (2 .. 16)
    static String base(int n, int b) {
        if n == 0 { return "0"; }
        String digits = "0123456789abcdef";
        String r = "";
        int v = n;
        while v > 0 {
            r.push(digits[v % b]);
            v = v / b;
        }
        String out = "";
        int i = r.len - 1;
        while i >= 0 {
            out.push(r[i]);
            i -= 1;
        }
        return out;
    }
    static String hex(int n) {
        if n < 0 { return "-" + Fmt::base(0 - n, 16); }
        return Fmt::base(n, 16);
    }
    static String bin(int n) {
        if n < 0 { return "-" + Fmt::base(0 - n, 2); }
        return Fmt::base(n, 2);
    }
    // 1234567 -> "1,234,567"
    static String thousands(int n) {
        String s = str(n);
        bool neg = false;
        int start = 0;
        if s.len > 0 && s[0] == '-' {
            neg = true;
            start = 1;
        }
        String r = "";
        int count = 0;
        int i = s.len - 1;
        while i >= start {
            if count > 0 && count % 3 == 0 { r.push(','); }
            r.push(s[i]);
            count += 1;
            i -= 1;
        }
        String out = "";
        if neg { out.push('-'); }
        int j = r.len - 1;
        while j >= 0 {
            out.push(r[j]);
            j -= 1;
        }
        return out;
    }
    // 0.256 -> "25.6%"
    static String percent(double ratio, int digits) {
        return Fmt::fixed(ratio * 100.0, digits) + "%";
    }
    // a size in bytes: 1536 -> "1.5 KB"
    static String bytes(int n) {
        if n < 1024 { return str(n) + " B"; }
        double v = (double)n;
        String unit = "KB";
        v = v / 1024.0;
        if v >= 1024.0 {
            v = v / 1024.0;
            unit = "MB";
        }
        if v >= 1024.0 {
            v = v / 1024.0;
            unit = "GB";
        }
        return Fmt::fixed(v, 1) + " " + unit;
    }
}
