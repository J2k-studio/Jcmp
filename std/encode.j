
// Path: the parts of a file name (the separator is /)
//   Path::join("a", "b.txt") -> "a/b.txt"   Path::name("a/b.txt") -> "b.txt"   Path::parent("a/b.txt") -> "a"
//   Path::ext("a/b.txt") -> "txt"   Path::stem("a/b.txt") -> "b"
struct Path {
    static String join(String a, String b) {
        String r = "";
        r.append(a);
        if a.len > 0 && a[a.len - 1] != '/' && b.len > 0 && b[0] != '/' { r.push('/'); }
        if a.len > 0 && a[a.len - 1] == '/' && b.len > 0 && b[0] == '/' {
            r.append(b.slice(1, b.len));
        } else {
            r.append(b);
        }
        return r;
    }
    // the part after the last /
    static String name(String p) {
        int cut = -1;
        for i in 0..p.len { if p[i] == '/' { cut = i; } }
        return p.slice(cut + 1, p.len);
    }
    // everything before the last / ("." if there is none, "/" for a file in the root)
    static String parent(String p) {
        int cut = -1;
        for i in 0..p.len { if p[i] == '/' { cut = i; } }
        if cut < 0 { return "."; }
        if cut == 0 { return "/"; }
        return p.slice(0, cut);
    }
    // the part of the name after the last . ("" if there is none, or if the name starts with the only .)
    static String ext(String p) {
        String n = Path::name(p);
        int dot = -1;
        for i in 0..n.len { if n[i] == '.' { dot = i; } }
        if dot <= 0 { return ""; }
        return n.slice(dot + 1, n.len);
    }
    // the name without its extension
    static String stem(String p) {
        String n = Path::name(p);
        int dot = -1;
        for i in 0..n.len { if n[i] == '.' { dot = i; } }
        if dot <= 0 { return n; }
        return n.slice(0, dot);
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
