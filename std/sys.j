// Sys: the operating system calls, one function each (Linux ARM64)
struct Sys {
    // a bug in the program: print  panic: message  and stop (exit code 134); try/catch cannot catch it
    static void panic(char^ msg) {
        __panic(msg);
    }
    // stop with the message if ok is false
    static void assert(bool ok, char^ msg) {
        if !ok { __panic(msg); }
    }
    static void exit(int code) {
        syscall(94, code);                 // exit_group: the whole program, all threads
    }
    static int argc() {
        return argc();
    }
    static char^ arg(int i) {
        return arg(i);
    }
    static int open(char^ path, int flags, int mode) {
        return syscall(56, -100, path, flags, mode);
    }
    static int close(int fd) {
        return syscall(57, fd);
    }
    static int read(int fd, void^ buf, int n) {
        return syscall(63, fd, buf, n);
    }
    static int write(int fd, void^ buf, int n) {
        return syscall(64, fd, buf, n);
    }
    // n bytes of fresh zeroed memory from the system (null on failure)
    static void^ mmap(int n) {
        int r = syscall(222, 0, n, 3, 34, -1, 0);
        if r < 0 { return null; }
        return (void^)r;
    }
    static int munmap(void^ p, int n) {
        return syscall(215, p, n);
    }
}
