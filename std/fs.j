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
        return (i32)syscall(56, -100, path, flags, 420);
    }
    static i32 close(i32 fd) {
        return (i32)syscall(57, fd);
    }
    static i32 read(i32 fd, char buf[]) {
        if buf.len < 2 { return -22; }
        int n = syscall(63, fd, buf, buf.len - 1);
        if n < 0 { return (i32)n; }
        buf[n] = 0;
        return (i32)n;
    }
    static i32 write(i32 fd, char buf[]) {
        int n = 0;
        while n < buf.len && buf[n] != 0 { n += 1; }
        return (i32)syscall(64, fd, buf, n);
    }
    static i32 read_line(i32 fd, char line[]) {
        int n = 0;
        char c = 0;
        while n < line.len - 1 {
            int got = syscall(63, fd, @c, 1);
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
