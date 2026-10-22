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


// Hex: bytes as two hex digits each
//   Hex::encode("Hi") -> "4869"      Hex::decode("4869")? -> "Hi"
struct Hex {
    static String encode(String s) {
        String digits = "0123456789abcdef";
        String r = "";
        for i in 0..s.len {
            int b = s[i] & 255;
            r.push(digits[b / 16]);
            r.push(digits[b % 16]);
        }
        return r;
    }
    static int nibble(char c) {
        if c >= '0' && c <= '9' { return c - '0'; }
        if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
        if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
        return -1;
    }
    static Result<String, Error> decode(String h) {
        if h.len % 2 != 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "a hex text has an even number of digits")); }
        String r = "";
        int i = 0;
        while i < h.len {
            int a = Hex::nibble(h[i]);
            int b = Hex::nibble(h[i + 1]);
            if a < 0 || b < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "not a hex digit")); }
            r.push((char)(a * 16 + b));
            i += 2;
        }
        return Result<String, Error>::Ok(r);
    }
}

// Base64 (RFC 4648, with = at the end)
//   Base64::encode("Man") -> "TWFu"      Base64::decode("TWFu")? -> "Man"
struct Base64 {
    static String encode(String s) {
        String t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        String r = "";
        int i = 0;
        while i + 2 < s.len {
            int v = ((s[i] & 255) << 16) | ((s[i + 1] & 255) << 8) | (s[i + 2] & 255);
            r.push(t[(v >> 18) & 63]);
            r.push(t[(v >> 12) & 63]);
            r.push(t[(v >> 6) & 63]);
            r.push(t[v & 63]);
            i += 3;
        }
        if s.len - i == 1 {
            int v = (s[i] & 255) << 16;
            r.push(t[(v >> 18) & 63]);
            r.push(t[(v >> 12) & 63]);
            r.push('=');
            r.push('=');
        } else if s.len - i == 2 {
            int v = ((s[i] & 255) << 16) | ((s[i + 1] & 255) << 8);
            r.push(t[(v >> 18) & 63]);
            r.push(t[(v >> 12) & 63]);
            r.push(t[(v >> 6) & 63]);
            r.push('=');
        }
        return r;
    }
    static int value(char c) {
        if c >= 'A' && c <= 'Z' { return c - 'A'; }
        if c >= 'a' && c <= 'z' { return c - 'a' + 26; }
        if c >= '0' && c <= '9' { return c - '0' + 52; }
        if c == '+' { return 62; }
        if c == '/' { return 63; }
        return -1;
    }
    static Result<String, Error> decode(String b) {
        String r = "";
        int acc = 0;
        int bits = 0;
        for i in 0..b.len {
            char c = b[i];
            if c == '=' { break; }
            if c == 10 || c == 13 || c == 32 { continue; }
            int v = Base64::value(c);
            if v < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Parse, "not a base64 character")); }
            acc = (acc << 6) | v;
            bits += 6;
            if bits >= 8 {
                bits -= 8;
                r.push((char)((acc >> bits) & 255));
            }
        }
        return Result<String, Error>::Ok(r);
    }
}

// hex, base64: the short names (Hex::hex.encode(s), with  using Hex;  hex.encode(s));  decode throws on a text that is not valid

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

// Regex: a small pattern matcher (a backtracking one), for the common cases.
//   Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") -> true     (the whole text)
//   Regex::find("[0-9]+", "room 42, floor 7") -> 5                    (where the first match starts, or -1)
//   Regex::find_text("[0-9]+", "room 42, floor 7") -> "42"
//   Regex::find_all("[0-9]+", "room 42, floor 7") -> ["42", "7"]      Regex::replace(p, t, "#"), Regex::split(p, t), Regex::count(p, t)
// Pattern: a character, . (any), \d \w \s (and \D \W \S), [abc] [a-z] [^0-9], \. (a character that has a meaning), ^ $,
// x* x+ x? and x{n} x{n,} x{n,m} on one thing (greedy; a ? after them makes them lazy: x*?), ( ... ) a group (also with | inside, and
// with a quantifier after it; (?: ... ) is the same), and | between whole alternatives. There are no captures yet.
int rx_depth;                       // how deep the matcher is (a group repeated many times is a deep recursion)
int rx_steps;                       // the work of one search: a pattern that cannot end (a group that matches nothing, repeated) is stopped
int rx_qmin;                        // the last quantifier read by quant(): its least and its most (-1: no limit), its length, and lazy
int rx_qmax;
int rx_qlen;
int rx_lazy;

struct Regex {
    // does the character c belong to the class at p[i] (a \d, \w, \s, a [..] set, a . or a literal)? the length of the item in rl
    static int item_len(String p, int i) {
        char c = p[i];
        if c == '\\' { return 2; }
        if c == '[' {
            int j = i + 1;
            if j < p.len && p[j] == '^' { j += 1; }
            if j < p.len && p[j] == ']' { j += 1; }
            while j < p.len && p[j] != ']' { j += 1; }
            return j + 1 - i;
        }
        return 1;
    }
    static bool class_has(char e, char c) {
        if e == 'd' { return c >= '0' && c <= '9'; }
        if e == 'w' { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'; }
        if e == 's' { return c == ' ' || c == 9 || c == 10 || c == 13; }
        return false;
    }
    // does the single item p[i .. i + n) match the character c?
    static bool item_matches(String p, int i, int n, char c) {
        char e = p[i];
        if e == '.' { return c != 10; }
        if e == '\\' {
            char k = p[i + 1];
            if k == 'd' || k == 'w' || k == 's' { return Regex::class_has(k, c); }
            if k == 'D' { return !Regex::class_has('d', c); }
            if k == 'W' { return !Regex::class_has('w', c); }
            if k == 'S' { return !Regex::class_has('s', c); }
            if k == 'n' { return c == 10; }
            if k == 't' { return c == 9; }
            return c == k;
        }
        if e == '[' {
            int j = i + 1;
            bool neg = false;
            if p[j] == '^' {
                neg = true;
                j += 1;
            }
            bool hit = false;
            int end = i + n - 1;
            while j < end {
                char a = p[j];
                if a == '\\' && j + 1 < end {
                    char k = p[j + 1];
                    if k == 'd' || k == 'w' || k == 's' {
                        if Regex::class_has(k, c) { hit = true; }
                    } else if k == c {
                        hit = true;
                    }
                    j += 2;
                } else if j + 2 < end && p[j + 1] == '-' {
                    if c >= a && c <= p[j + 2] { hit = true; }
                    j += 3;
                } else {
                    if c == a { hit = true; }
                    j += 1;
                }
            }
            return hit != neg;
        }
        return c == e;
    }
    // the quantifier at p[i] (i < pe): rx_qmin, rx_qmax (-1: no limit), rx_qlen (0: none) and rx_lazy
    static void quant(String p, int i, int pe) {
        rx_qmin = 1;
        rx_qmax = 1;
        rx_qlen = 0;
        rx_lazy = 0;
        if i >= pe { return; }
        char q = p[i];
        if q == '*' { rx_qmin = 0; rx_qmax = -1; rx_qlen = 1; }
        else if q == '+' { rx_qmin = 1; rx_qmax = -1; rx_qlen = 1; }
        else if q == '?' { rx_qmin = 0; rx_qmax = 1; rx_qlen = 1; }
        else if q == '{' {
            int j = i + 1;
            int lo = 0;
            int hi = 0;
            bool digits = false;
            while j < pe && p[j] >= '0' && p[j] <= '9' { lo = lo * 10 + (p[j] - '0'); j += 1; digits = true; }
            if !digits { return; }
            hi = lo;
            if j < pe && p[j] == ',' {
                j += 1;
                if j < pe && p[j] == '}' { hi = -1; }
                else {
                    hi = 0;
                    while j < pe && p[j] >= '0' && p[j] <= '9' { hi = hi * 10 + (p[j] - '0'); j += 1; }
                }
            }
            if j >= pe || p[j] != '}' { return; }
            rx_qmin = lo;
            rx_qmax = hi;
            rx_qlen = j + 1 - i;
        } else { return; }
        if i + rx_qlen < pe && p[i + rx_qlen] == '?' { rx_lazy = 1; rx_qlen += 1; }
    }
    // the ")" that closes the "(" at p[i] (-1: none); p[i .. pe)
    static int group_end(String p, int i, int pe) {
        int depth = 0;
        int j = i;
        while j < pe {
            char c = p[j];
            if c == '\\' { j += 2; continue; }
            if c == '[' { j += Regex::item_len(p, j); continue; }
            if c == '(' { depth += 1; }
            if c == ')' {
                depth -= 1;
                if depth == 0 { return j; }
            }
            j += 1;
        }
        return -1;
    }
    // the end of a match of p[pi .. pe) at t[ti ..], or -1 (backtracking)
    static int m(String p, int pi, int pe, String t, int ti) {
        rx_depth += 1;
        rx_steps += 1;
        int r = -1;
        if rx_depth <= 4000 && rx_steps <= 2000000 { r = Regex::m2(p, pi, pe, t, ti); }
        rx_depth -= 1;
        return r;
    }
    static int m2(String p, int pi, int pe, String t, int ti) {
        if pi >= pe { return ti; }
        if p[pi] == '$' && pi + 1 == pe {
            if ti == t.len { return ti; }
            return -1;
        }
        if p[pi] == '(' {
            int g = Regex::group_end(p, pi, pe);
            if g < 0 { return -1; }
            String inner = p.slice(pi + 1, g);
            if inner.starts_with("?:") { inner = inner.slice(2, inner.len); }
            Regex::quant(p, g + 1, pe);
            int qmin = rx_qmin;
            int qmax = rx_qmax;
            int lazy = rx_lazy;
            String rest = p.slice(g + 1 + rx_qlen, pe);
            return Regex::group(inner, qmin, qmax, lazy, rest, t, ti);
        }
        int n = Regex::item_len(p, pi);
        int after = pi + n;
        Regex::quant(p, after, pe);
        if rx_qlen > 0 {
            int qmin = rx_qmin;
            int qmax = rx_qmax;
            int lazy = rx_lazy;
            int rest = after + rx_qlen;
            int count = 0;
            int pos = ti;
            if lazy == 1 {
                // as few as possible first, then more
                while count < qmin && pos < t.len && Regex::item_matches(p, pi, n, t[pos]) { pos += 1; count += 1; }
                if count < qmin { return -1; }
                while true {
                    int r = Regex::m(p, rest, pe, t, ti + count);
                    if r >= 0 { return r; }
                    if (qmax >= 0 && count >= qmax) || pos >= t.len || !Regex::item_matches(p, pi, n, t[pos]) { return -1; }
                    pos += 1;
                    count += 1;
                }
            }
            // as many as possible first, then fewer
            while (qmax < 0 || count < qmax) && pos < t.len && Regex::item_matches(p, pi, n, t[pos]) {
                pos += 1;
                count += 1;
            }
            while count >= qmin {
                int r = Regex::m(p, rest, pe, t, ti + count);
                if r >= 0 { return r; }
                count -= 1;
            }
            return -1;
        }
        if ti < t.len && Regex::item_matches(p, pi, n, t[ti]) {
            return Regex::m(p, after, pe, t, ti + 1);
        }
        return -1;
    }
    // a group "(inner)" repeated qmin .. qmax times, then the rest of the pattern: each branch of the group, followed by the group
    // again (with the counts one less) and the rest, is a pattern of its own
    static int group(String inner, int qmin, int qmax, int lazy, String rest, String t, int ti) {
        if qmax == 0 { return Regex::m(rest, 0, rest.len, t, ti); }
        String again = "(" + inner + ")";
        int nmin = qmin;
        if nmin > 0 { nmin -= 1; }
        int nmax = qmax;
        if nmax > 0 { nmax -= 1; }
        if nmax == 0 { again = ""; }
        else if nmax < 0 && nmin == 0 { again = again + "*"; }
        else if nmax < 0 { again = again + "{" + str(nmin) + ",}"; }
        else { again = again + "{" + str(nmin) + "," + str(nmax) + "}"; }
        if lazy == 1 { if again.len > 0 { again = again + "?"; } }
        if lazy == 1 && qmin == 0 {
            int r0 = Regex::m(rest, 0, rest.len, t, ti);
            if r0 >= 0 { return r0; }
        }
        String[] br = Regex::alternatives(inner);
        for k in 0..br.len {
            String pat = br[k] + again + rest;
            int r = Regex::m(pat, 0, pat.len, t, ti);
            if r >= 0 { return r; }
        }
        if qmin == 0 && lazy == 0 { return Regex::m(rest, 0, rest.len, t, ti); }
        return -1;
    }
    // the parts of a pattern between the top-level | (not inside [ ], \ or ( ))
    static String[] alternatives(String p) {
        String[] r = arr(4);
        int start = 0;
        int depth = 0;
        int i = 0;
        while i < p.len {
            char c = p[i];
            if c == '\\' { i += 2; continue; }
            if c == '[' { i += Regex::item_len(p, i); continue; }
            if c == '(' { depth += 1; }
            if c == ')' { depth -= 1; }
            if c == '|' && depth == 0 {
                r.push(p.slice(start, i));
                start = i + 1;
            }
            i += 1;
        }
        r.push(p.slice(start, p.len));
        return r;
    }
    // the end of the match that starts exactly at ti (every top-level branch is tried), or -1
    static int match_here(String p, String t, int ti) {
        String[] br = Regex::alternatives(p);
        for k in 0..br.len {
            String b = br[k];
            int r = -1;
            rx_steps = 0;
            if b.len > 0 && b[0] == '^' {
                if ti == 0 { r = Regex::m(b, 1, b.len, t, ti); }
            } else {
                r = Regex::m(b, 0, b.len, t, ti);
            }
            if r >= 0 { return r; }
        }
        return -1;
    }
    // the position where the first match starts (-1: none)
    static int find(String p, String t) {
        for s in 0..t.len + 1 {
            int r = Regex::match_here(p, t, s);
            if r >= 0 { return s; }
        }
        return -1;
    }
    // the text of the first match ("" when there is none: use find to tell the difference)
    static String find_text(String p, String t) {
        for s in 0..t.len + 1 {
            int r = Regex::match_here(p, t, s);
            if r >= 0 { return t.slice(s, r); }
        }
        return "";
    }
    // does the pattern match the whole text?
    static bool matches(String p, String t) {
        String whole = "^(?:" + p + ")$";
        return Regex::match_here(whole, t, 0) >= 0;
    }
    // every match, from left to right, none overlapping (an empty match is skipped)
    static String[] find_all(String p, String t) {
        String[] r = arr(4);
        int s = 0;
        while s <= t.len {
            int e = Regex::match_here(p, t, s);
            if e > s {
                r.push(t.slice(s, e));
                s = e;
            } else {
                s += 1;
            }
        }
        return r;
    }
    static int count(String p, String t) {
        String[] all = Regex::find_all(p, t);
        return all.len;
    }
    // the text with every match replaced by `with`
    static String replace(String p, String t, String with) {
        String out = "";
        int s = 0;
        while s <= t.len {
            int e = Regex::match_here(p, t, s);
            if e > s {
                out = out + with;
                s = e;
            } else {
                if s < t.len { out.push(t[s]); }
                s += 1;
            }
        }
        return out;
    }
    // the pieces of the text between the matches
    static String[] split(String p, String t) {
        String[] r = arr(4);
        int s = 0;
        int piece = 0;
        while s <= t.len {
            int e = Regex::match_here(p, t, s);
            if e > s {
                r.push(t.slice(piece, s));
                s = e;
                piece = e;
            } else {
                s += 1;
            }
        }
        r.push(t.slice(piece, t.len));
        return r;
    }
}

// regex: the short names (Regex::regex.matches(p, t), with  using Regex;  regex.matches(p, t))

// the short names of the text unit (hex, base64, regex): <module>_<name>, the compiler adds the prefix
struct __Text {
    static String hex_encode(String s) { return Hex::encode(s); }
    static String hex_decode(String h) { return Hex::decode(h).take(); }
    static Result<String, Error> hex_try_decode(String h) { return Hex::decode(h); }
    static String base64_encode(String s) { return Base64::encode(s); }
    static String base64_decode(String b) { return Base64::decode(b).take(); }
    static Result<String, Error> base64_try_decode(String b) { return Base64::decode(b); }
    static int regex_find(String p, String t) { return Regex::find(p, t); }
    static String regex_text(String p, String t) { return Regex::find_text(p, t); }
    static bool regex_matches(String p, String t) { return Regex::matches(p, t); }
}

