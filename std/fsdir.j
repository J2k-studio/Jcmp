// Files and folders: Fs (whole files), Dir (folders). Needs the core (Result, Error) and text (Str).
// an Error for the system error number e (a negative number from a system call is fine) and what was being done
struct Fs {
    static Error error(int e, String what, String path) {
        if e < 0 { e = 0 - e; }
        ErrorKind k = ErrorKind::Io;
        if e == 2 || e == 20 { k = ErrorKind::NotFound; }
        if e == 13 || e == 1 { k = ErrorKind::Denied; }
        if e == 22 || e == 21 || e == 36 { k = ErrorKind::Invalid; }
        String m = what + path;
        m += " (error ";
        m += (char)('0' + e / 100 % 10);
        m += (char)('0' + e / 10 % 10);
        m += (char)('0' + e % 10);
        m += ")";
        return Error::make(k, m);
    }
    // the whole file as a String
    static Result<String, Error> read_text(String path) {
        int fd = syscall(56, -100, path.c(), 0, 0);
        if fd < 0 { return Result<String, Error>::Err(Fs::error(fd, "cannot open ", path)); }
        String text = "";
        char buf[4096];
        int n = syscall(63, fd, @buf, 4095);
        while n > 0 {
            buf[n] = 0;
            text.append((char^)@buf);
            n = syscall(63, fd, @buf, 4095);
        }
        syscall(57, fd);
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
        int fd = syscall(56, -100, path.c(), flags, 420);
        if fd < 0 { return Result<int, Error>::Err(Fs::error(fd, "cannot write ", path)); }
        int done = 0;
        char^ p = text.c();
        while done < text.len {
            int n = syscall(64, fd, p + done, text.len - done);
            if n <= 0 {
                syscall(57, fd);
                return Result<int, Error>::Err(Fs::error(n, "cannot write ", path));
            }
            done += n;
        }
        syscall(57, fd);
        return Result<int, Error>::Ok(done);
    }
    static bool exists(String path) {
        return syscall(48, -100, path.c(), 0, 0) == 0;
    }
    // the size of a file in bytes
    static Result<int, Error> size(String path) {
        int fd = syscall(56, -100, path.c(), 0, 0);
        if fd < 0 { return Result<int, Error>::Err(Fs::error(fd, "cannot open ", path)); }
        int n = syscall(62, fd, 0, 2);
        syscall(57, fd);
        if n < 0 { return Result<int, Error>::Err(Fs::error(n, "cannot size ", path)); }
        return Result<int, Error>::Ok(n);
    }
    static Result<int, Error> remove(String path) {
        int r = syscall(35, -100, path.c(), 0);
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot remove ", path)); }
        return Result<int, Error>::Ok(0);
    }
    static Result<int, Error> rename(String from, String to) {
        int r = syscall(38, -100, from.c(), -100, to.c());
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot rename ", from)); }
        return Result<int, Error>::Ok(0);
    }
}

struct Dir {
    static bool exists(String path) {
        int st[18];
        if syscall(79, -100, path.c(), @st, 0) != 0 { return false; }       // newfstatat
        return (st[2] & 4294967295 & 61440) == 16384;                          // st_mode is a folder
    }
    static Result<int, Error> make(String path) {
        int r = syscall(34, -100, path.c(), 493);
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot make the folder ", path)); }
        return Result<int, Error>::Ok(0);
    }
    // the folder and the ones above it (like mkdir -p)
    static Result<int, Error> make_all(String path) {
        String part = "";
        for ch in path {
            if ch == '/' && part.len > 0 {
                if !Dir::exists(part) {
                    int r1 = syscall(34, -100, part.c(), 493);
                    if r1 < 0 { return Result<int, Error>::Err(Fs::error(r1, "cannot make the folder ", part)); }
                }
            }
            part.push(ch);
        }
        if part.len > 0 && !Dir::exists(part) {
            int r2 = syscall(34, -100, part.c(), 493);
            if r2 < 0 { return Result<int, Error>::Err(Fs::error(r2, "cannot make the folder ", part)); }
        }
        return Result<int, Error>::Ok(0);
    }
    // remove an empty folder
    static Result<int, Error> remove(String path) {
        int r = syscall(35, -100, path.c(), 512);                // AT_REMOVEDIR
        if r < 0 { return Result<int, Error>::Err(Fs::error(r, "cannot remove the folder ", path)); }
        return Result<int, Error>::Ok(0);
    }
    // the names in a folder (not . and ..), in order
    static Result<String[], Error> list(String path) {
        int fd = syscall(56, -100, path.c(), 16384, 0);
        if fd < 0 { return Result<String[], Error>::Err(Fs::error(fd, "cannot read the folder ", path)); }
        String[] names = arr(8);
        char buf[4096];
        int n = syscall(61, fd, @buf, 4096);                     // getdents64
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
            n = syscall(61, fd, @buf, 4096);
        }
        syscall(57, fd);
        names.sort();
        return Result<String[], Error>::Ok(names);
    }
    static Result<String, Error> current() {
        char buf[1024];
        int n = syscall(17, @buf, 1024);
        if n < 0 { return Result<String, Error>::Err(Fs::error(n, "cannot get the folder", "")); }
        String s = "";
        s.append((char^)@buf);
        return Result<String, Error>::Ok(s);
    }
}
