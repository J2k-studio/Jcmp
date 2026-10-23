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

// the short names of the files unit (fs, dir, path): Fs::fs.read(p), with  using Fs;  fs.read(p). A function is named <module>_<name> here
// (one struct for the three modules, because the number of structs of a program is limited); the compiler adds the prefix.
struct __Files {
    static String fs_read(String path) { return Fs::read_text(path).take(); }
    static Result<String, Error> fs_try_read(String path) { return Fs::read_text(path); }
    static String[] fs_lines(String path) { return Fs::read_lines(path).take(); }
    static Result<String[], Error> fs_try_lines(String path) { return Fs::read_lines(path); }
    static int fs_write(String path, String text) { return Fs::write_text(path, text).take(); }
    static Result<int, Error> fs_try_write(String path, String text) { return Fs::write_text(path, text); }
    static int fs_append(String path, String text) { return Fs::append_text(path, text).take(); }
    static Result<int, Error> fs_try_append(String path, String text) { return Fs::append_text(path, text); }
    static bool fs_exists(String path) { return Fs::exists(path); }
    static int fs_size(String path) { return Fs::size(path).take(); }
    static Result<int, Error> fs_try_size(String path) { return Fs::size(path); }
    static int fs_remove(String path) { return Fs::remove(path).take(); }
    static Result<int, Error> fs_try_remove(String path) { return Fs::remove(path); }
    static int fs_rename(String from, String to) { return Fs::rename(from, to).take(); }
    static Result<int, Error> fs_try_rename(String from, String to) { return Fs::rename(from, to); }
    static String read_text(String path) { return Fs::read_text(path).take(); }
    static Result<String, Error> read_try_text(String path) { return Fs::read_text(path); }
    static String read_bytes(String path) { return Fs::read_bytes(path).take(); }
    static Result<String, Error> read_try_bytes(String path) { return Fs::read_bytes(path); }
    static String[] read_lines(String path) { return Fs::read_lines(path).take(); }
    static Result<String[], Error> read_try_lines(String path) { return Fs::read_lines(path); }
    static bool dir_exists(String path) { return Dir::exists(path); }
    static int dir_make(String path) { return Dir::make(path).take(); }
    static Result<int, Error> dir_try_make(String path) { return Dir::make(path); }
    static int dir_make_all(String path) { return Dir::make_all(path).take(); }
    static Result<int, Error> dir_try_make_all(String path) { return Dir::make_all(path); }
    static int dir_remove(String path) { return Dir::remove(path).take(); }
    static Result<int, Error> dir_try_remove(String path) { return Dir::remove(path); }
    static String[] dir_list(String path) { return Dir::list(path).take(); }
    static Result<String[], Error> dir_try_list(String path) { return Dir::list(path); }
    static String dir_current() { return Dir::current().take(); }
    static Result<String, Error> dir_try_current() { return Dir::current(); }
    static String path_join(String a, String b) { return Path::join(a, b); }
    static String path_name(String p) { return Path::name(p); }
    static String path_parent(String p) { return Path::parent(p); }
    static String path_ext(String p) { return Path::ext(p); }
    static String path_stem(String p) { return Path::stem(p); }
}
