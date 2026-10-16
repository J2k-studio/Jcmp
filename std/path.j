// Path: names of files (join, parent, extension ...).
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

// path: the module name of Path (Path::path.join(a, b), with  using Path;  path.join(a, b))
struct __Path {
    static String join(String a, String b) { return Path::join(a, b); }
    static String name(String p) { return Path::name(p); }
    static String parent(String p) { return Path::parent(p); }
    static String ext(String p) { return Path::ext(p); }
    static String stem(String p) { return Path::stem(p); }
}
