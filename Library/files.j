enum class FileMode { Read, Write, Append, ReadWrite };

struct File {
    static i32 open(char^ path, FileMode mode) {
        int flags = 0;
        switch mode {
            FileMode::Read: flags = 0;
            FileMode::Write: flags = 577;
            FileMode::Append: flags = 1089;
            FileMode::ReadWrite: flags = 2;
        }
        return (i32)Sys::open(path, flags, 420);
    }
    static i32 close(i32 fd) {
        return (i32)Sys::close(fd);
    }
    static i32 read(i32 fd, char buf[]) {
        if buf.len < 2 { return -22; }
        int n = Sys::read(fd, buf, buf.len - 1);
        if n < 0 { return (i32)n; }
        buf[n] = 0;
        return (i32)n;
    }
    static i32 write(i32 fd, char buf[]) {
        int n = 0;
        while n < buf.len && buf[n] != 0 { n += 1; }
        return (i32)Sys::write(fd, buf, n);
    }
    static i32 read_line(i32 fd, char line[]) {
        int n = 0;
        char c = 0;
        while n < line.len - 1 {
            int got = Sys::read(fd, @c, 1);
            if got < 0 { return (i32)got; }
            if got == 0 {
                if n == 0 { return -1; }
                break;
            }
            if c == 10 { break; }
            line[n] = c;
            n += 1;
        }
        line[n] = 0;
        return (i32)n;
    }
}

// Files and folders: Fs (whole files), Dir (folders). Needs the core (Result, Error) and text (Str).
// an Error for the system error number e (a negative number from a system call is fine) and what was being done
struct Fs {
    static Error error(int e, String what, String path) {
        return Error::from_errno(e, what + path);
    }
    // the whole file as a String
    static Result<String, Error> read_text(String path) {
        int fd = Sys::open_read(path.c());
        if fd < 0 { return Result<String, Error>::Err(Fs::error(fd, "cannot open ", path)); }
        String text = "";
        char buf[4096];
        int n = Sys::read(fd, @buf, 4095);
        while n > 0 {
            buf[n] = 0;
            text.append((char^)@buf);
            n = Sys::read(fd, @buf, 4095);
        }
        Sys::close(fd);
        if n < 0 { return Result<String, Error>::Err(Fs::error(n, "cannot read ", path)); }
        return Result<String, Error>::Ok(text);
    }
    // the lines of a file (without the line ends)
    static Result<String[], Error> read_lines(String path) {
        String text = Fs::read_text(path)?;
        String[] parts = text.split("\n");
        String[] lines = arr(parts.len + 1);
        for i in 0..parts.len {
            String line = parts[i];
            int n = line.len;
            if n > 0 {
                char last = line[n - 1];
                if last == 13 { line = line.slice(0, n - 1); }
            }
            if i < parts.len - 1 || line.len > 0 { lines.push(line); }
        }
        parts.free();
        return Result<String[], Error>::Ok(lines);
    }
    // write the text to the file (made or emptied); Ok(the number of bytes)
    static Result<int, Error> write_text(String path, String text) {
        return Fs::put(path, text, 577);
    }
    // add the text at the end of the file (made if needed)
    static Result<int, Error> append_text(String path, String text) {
        return Fs::put(path, text, 1089);
    }
    static Result<int, Error> put(String path, String text, int flags) {
        int fd = Sys::open(path.c(), flags, 420);
        if fd < 0 { return Result<int, Error>::Err(Fs::error(fd, "cannot write ", path)); }
        int done = 0;
        char^ p = text.c();
        while done < text.len {
            int n = Sys::write(fd, p + done, text.len - done);
            if n <= 0 {
                Sys::close(fd);
                return Result<int, Error>::Err(Fs::error(n, "cannot write ", path));
            }
            done += n;
        }
        Sys::close(fd);
        return Result<int, Error>::Ok(done);
    }
    static bool exists(String path) {
        return Sys::access(path.c()) == 0;
    }
    // the size of a file in bytes
    static Result<int, Error> size(String path) {
        int fd = Sys::open_read(path.c());
        if fd < 0 { return Result<int, Error>::Err(Fs::error(fd, "cannot open ", path)); }
        int n = Sys::lseek(fd, 0, 2);
        Sys::close(fd);
        if n < 0 { return Result<int, Error>::Err(Fs::error(n, "cannot size ", path)); }
        return Result<int, Error>::Ok(n);
    }
    static Result<int, Error> remove(String path) {
        int r = Sys::unlink(path.c());
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot remove ", path)); }
        return Result<int, Error>::Ok(0);
    }
    static Result<int, Error> rename(String from, String to) {
        int r = Sys::rename(from.c(), to.c());
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot rename ", from)); }
        return Result<int, Error>::Ok(0);
    }
}

struct Dir {
    static bool exists(String path) {
        int st[18];
        if Sys::stat(path.c(), @st) != 0 { return false; }       // newfstatat
        return (st[2] & 4294967295 & 61440) == 16384;                          // st_mode is a folder
    }
    static Result<int, Error> make(String path) {
        int r = Sys::mkdir(path.c(), 493);
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot make the folder ", path)); }
        return Result<int, Error>::Ok(0);
    }
    // the folder and the ones above it (like mkdir -p)
    static Result<int, Error> make_all(String path) {
        String part = "";
        for ch in path {
            if ch == '/' && part.len > 0 {
                if !Dir::exists(part) {
                    int r1 = Sys::mkdir(part.c(), 493);
                    if r1 < 0 { return Result<int, Error>::Err(Fs::error(r1, "cannot make the folder ", part)); }
                }
            }
            part.push(ch);
        }
        if part.len > 0 && !Dir::exists(part) {
            int r2 = Sys::mkdir(part.c(), 493);
            if r2 < 0 { return Result<int, Error>::Err(Fs::error(r2, "cannot make the folder ", part)); }
        }
        return Result<int, Error>::Ok(0);
    }
    // remove an empty folder
    static Result<int, Error> remove(String path) {
        int r = Sys::rmdir(path.c());                // AT_REMOVEDIR
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot remove the folder ", path)); }
        return Result<int, Error>::Ok(0);
    }
    // the names in a folder (not . and ..), in order
    static Result<String[], Error> list(String path) {
        int fd = Sys::open_dir(path.c());
        if fd < 0 { return Result<String[], Error>::Err(Fs::error(fd, "cannot read the folder ", path)); }
        String[] names = arr(8);
        char buf[4096];
        int n = Sys::getdents(fd, @buf, 4096);                     // getdents64
        while n > 0 {
            int at = 0;
            while at < n {
                int reclen = buf[at + 16] + buf[at + 17] * 256;
                String name = "";
                int k = at + 19;
                while buf[k] != 0 {
                    name.push(buf[k]);
                    k += 1;
                }
                if !(name == ".") && !(name == "..") { names.push(name); }
                at += reclen;
            }
            n = Sys::getdents(fd, @buf, 4096);
        }
        Sys::close(fd);
        names.sort();
        return Result<String[], Error>::Ok(names);
    }
    static Result<String, Error> current() {
        char buf[1024];
        int n = Sys::getcwd(@buf, 1024);
        if n < 0 { return Result<String, Error>::Err(Fs::error(n, "cannot get the folder", "")); }
        String s = "";
        s.append((char^)@buf);
        return Result<String, Error>::Ok(s);
    }
}

// fs, dir: the short names of the library (Fs::fs.read(p), with  using Fs;  fs.read(p)). A failure is thrown as a text (try / catch);
// try_name returns the Result. The long names above (Fs::read_text ...) keep working.

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

