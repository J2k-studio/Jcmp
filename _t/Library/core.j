// Sys: the operating system, one named function for each call (Linux ARM64 today).
//
// The program asks Sys, Sys asks the kernel. Nobody writes the number of a system call: the numbers (and the numbers of flags) belong to one machine,
// and are in this file only, so that a port to another machine changes this file and not the programs. The functions give the result of the kernel:
// a number >= 0, or the error as a negative number (-2 is "no such file", see Error::reason(n)). They check the arguments that would make the
// kernel read or write at a wrong place (a null buffer, a negative size, an address that is not a page) and give -14 (bad address) or -22
// (invalid argument) without calling it. A call that Sys does not have yet: Sys::call(number, ...) (the compiler warns about syscall(...) in a
// program; write  #allow syscall  at the top of a low level program to silence it).
// Designed by the assistant at the owner's request (2026-10-17, docs/syntax-design.md 82), adjustable.
struct Sys {
    // a bug in the program: print  panic: message  and stop (exit code 134); try/catch cannot catch it
    static void panic(char^ msg) {
        __panic(msg);
    }
    // stop with the message if ok is false
    static void assert(bool ok, char^ msg) {
        if !ok { __panic(msg); }
    }
    static int argc() {
        return argc();
    }
    static char^ arg(int i) {
        return arg(i);
    }
    // ---- a call that is not here yet
    static int call(int number, int a0, int a1, int a2, int a3, int a4, int a5) {
        return syscall(number, a0, a1, a2, a3, a4, a5);
    }
    // ---- files
    // flags and mode are the numbers of this machine; open_read / open_write / open_append / open_dir need none
    static int open(char^ path, int flags, int mode) {
        if path == null { return -14; }
        return syscall(56, -100, path, flags, mode);
    }
    static int open_read(char^ path) { return Sys::open(path, 0, 0); }
    // create or empty the file; mode 0644 (before the umask)
    static int open_write(char^ path) { return Sys::open(path, 577, 420); }
    // create the file if it is not there; writes go to the end
    static int open_append(char^ path) { return Sys::open(path, 1089, 420); }
    // a folder, to read with getdents
    static int open_dir(char^ path) { return Sys::open(path, 16384, 0); }
    static int close(int fd) {
        if fd < 0 { return -9; }
        return syscall(57, fd);
    }
    static int read(int fd, void^ buf, int n) {
        if n < 0 { return -22; }
        if n > 0 && buf == null { return -14; }
        return syscall(63, fd, buf, n);
    }
    static int write(int fd, void^ buf, int n) {
        if n < 0 { return -22; }
        if n > 0 && buf == null { return -14; }
        __flush();
        return syscall(64, fd, buf, n);
    }
    // whence: 0 from the start, 1 from here, 2 from the end
    static int lseek(int fd, int offset, int whence) {
        if whence < 0 || whence > 2 { return -22; }
        return syscall(62, fd, offset, whence);
    }
    static int unlink(char^ path) {
        if path == null { return -14; }
        return syscall(35, -100, path, 0);
    }
    static int rmdir(char^ path) {
        if path == null { return -14; }
        return syscall(35, -100, path, 0x200);
    }
    static int rename(char^ from, char^ to) {
        if from == null || to == null { return -14; }
        return syscall(38, -100, from, -100, to);
    }
    static int mkdir(char^ path, int mode) {
        if path == null { return -14; }
        return syscall(34, -100, path, mode);
    }
    static int chmod(char^ path, int mode) {
        if path == null { return -14; }
        return syscall(53, -100, path, mode, 0);
    }
    // the details of a file in buf (128 bytes); the mode is the 4 bytes at offset 16, the size the 8 bytes at offset 48
    static int stat(char^ path, void^ buf) {
        if path == null || buf == null { return -14; }
        return syscall(79, -100, path, buf, 0);
    }
    static int fstat(int fd, void^ buf) {
        if buf == null { return -14; }
        return syscall(80, fd, buf, 0);
    }
    static int readlink(char^ path, char^ buf, int n) {
        if path == null || buf == null { return -14; }
        if n <= 0 { return -22; }
        return syscall(78, -100, path, buf, n);
    }
    // the entries of a folder opened with open_dir (linux_dirent64)
    static int getdents(int fd, void^ buf, int n) {
        if buf == null { return -14; }
        if n <= 0 { return -22; }
        return syscall(61, fd, buf, n);
    }
    static int getcwd(char^ buf, int n) {
        if buf == null { return -14; }
        if n <= 0 { return -22; }
        return syscall(17, buf, n);
    }
    // is the file number a terminal? (the call TCGETS: 0 yes)
    static int isatty(int fd) {
        char t[64];
        return syscall(29, fd, 21505, @t);
    }
    // the size of the terminal in buf (8 bytes: rows, columns, 2 more numbers of 16 bits)
    static int window_size(int fd, void^ buf) {
        if buf == null { return -14; }
        return syscall(29, fd, 0x5413, buf);
    }
    static int pipe(void^ fds) {
        if fds == null { return -14; }
        return syscall(59, fds, 0);
    }
    static int dup2(int old, int fresh) {
        return syscall(24, old, fresh, 0);
    }
    // ---- memory
    // n bytes of fresh zeroed memory from the system (null on failure)
    static void^ mmap(int n) {
        if n <= 0 { return null; }
        int r = syscall(222, 0, n, 3, 34, -1, 0);
        if r < 0 { return null; }
        return (void^)r;
    }
    static int munmap(void^ p, int n) {
        int a = (int)p;
        if a == 0 || (a & 4095) != 0 || n <= 0 { return -22; }
        return syscall(215, p, n);
    }
    // prot: 0 nothing, 1 read, 2 write, 4 execute (added)
    static int mprotect(void^ p, int n, int prot) {
        int a = (int)p;
        if a == 0 || (a & 4095) != 0 || n <= 0 || prot < 0 || prot > 7 { return -22; }
        return syscall(226, p, n, prot);
    }
    // ---- the program and its processes
    static void exit(int code) {
        __flush();
        syscall(94, code & 255);           // exit_group: the whole program, all threads
    }
    static int getpid() { return syscall(172); }
    static int gettid() { return syscall(178); }
    // send a signal to ONE process (pid > 0); the calls that reach a whole group of processes (pid <= 0) are refused here: use Sys::call for them
    static int kill(int pid, int sig) {
        if pid <= 0 || sig < 0 || sig > 64 { return -22; }
        return syscall(129, pid, sig);
    }
    // a new process like this one (fork): 0 in the child, the id of the child in the parent
    static int fork() {
        __flush();
        return syscall(220, 17, 0, 0, 0, 0);
    }
    static int execve(char^ path, void^ argv, void^ envp) {
        if path == null || argv == null { return -14; }
        __flush();
        return syscall(221, path, argv, envp);
    }
    // wait for the child pid; its state goes to *status
    static int wait(int pid, int^ status) {
        return syscall(260, pid, status, 0, 0);
    }
    static int sleep_ms(int ms) {
        if ms < 0 { return -22; }
        int ts[2];
        ts[0] = ms / 1000;
        ts[1] = (ms % 1000) * 1000000;
        return syscall(101, @ts, 0);
    }
    static int yield() { return syscall(124); }
    // sleep for the time in ts (ts[0] seconds, ts[1] nanoseconds)
    static int nanosleep(int^ ts) {
        if ts == null { return -14; }
        return syscall(101, ts, 0);
    }
    // the fast user lock of the kernel: op 128 waits while *addr == val, 129 wakes val waiters (the "private" kinds); 0 waits (shared)
    static int futex(int^ addr, int op, int val) {
        if addr == null { return -14; }
        return syscall(98, addr, op, val, 0, 0, 0);
    }
    // wait until one of the n file numbers in fds (struct pollfd, 8 bytes each) is ready, or the time in ts has passed (ts null: no limit)
    static int ppoll(void^ fds, int n, void^ ts) {
        if fds == null || n < 0 { return -22; }
        return syscall(73, fds, n, ts, 0, 8);
    }
    // 0 when the file or folder can be seen (it exists), else the error
    static int access(char^ path) {
        if path == null { return -14; }
        return syscall(48, -100, path, 0, 0);
    }
    // the clock: which = 0 the time of day, 1 a clock that only goes forward; the seconds and the nanoseconds go to ts[0] and ts[1]
    static int clock_gettime(int which, int^ ts) {
        if ts == null { return -14; }
        return syscall(113, which, ts);
    }
    // n random bytes from the system
    static int random(void^ buf, int n) {
        if buf == null || n < 0 { return -22; }
        return syscall(278, buf, n, 0);
    }
    // ---- sockets (IPv4)
    static int socket_tcp() { return syscall(198, 2, 1, 0); }
    static int socket_udp() { return syscall(198, 2, 2, 0); }
    static int socketpair(void^ fds) {
        if fds == null { return -14; }
        return syscall(199, 1, 1, 0, fds);
    }
    static int bind(int fd, void^ addr, int len) {
        if addr == null || len <= 0 { return -22; }
        return syscall(200, fd, addr, len);
    }
    static int listen(int fd, int backlog) { return syscall(201, fd, backlog); }
    static int connect(int fd, void^ addr, int len) {
        if addr == null || len <= 0 { return -22; }
        return syscall(203, fd, addr, len);
    }
    static int accept(int fd) { return syscall(242, fd, 0, 0, 0); }
    static int getsockname(int fd, void^ addr, int^ len) {
        if addr == null || len == null { return -14; }
        return syscall(204, fd, addr, len);
    }
    static int setsockopt(int fd, int level, int name, void^ value, int len) {
        if value == null || len <= 0 { return -22; }
        return syscall(208, fd, level, name, value, len);
    }
    // wait for data at most ms milliseconds on a socket: the receive time out
    static int set_receive_timeout(int fd, int seconds) {
        int tv[2];
        tv[0] = seconds;
        tv[1] = 0;
        return syscall(208, fd, 1, 20, @tv, 16);
    }
}

// Option<T> and Result<T,E>: a value that may be missing, or an operation that may fail, as a value.
//   Option<int> a = Option<int>::Some(5);   Option<int> b = Option<int>::None;
//   Result<int, Error> r = parse(text);     int n = parse(text)?;      (? returns the error to the caller)
// switch takes a value apart:  switch r { Result::Ok(v): ...; Result::Err(e): ...; }

enum class ErrorKind { Other, NotFound, Denied, Invalid, Parse, Io };

char error_text_buf[256];          // the text of a thrown error stays alive while the stack is unwound

// the usual error: what went wrong (kind) and a message
struct Error {
    ErrorKind kind;
    String message;
    static Error make(ErrorKind kind, String message) {
        Error e;
        e.kind = kind;
        e.message = message;
        return e;
    }
    // throw a text (the short forms of the library throw instead of returning a Result; catch with try { } catch (e) { })
    static void raise(char^ msg) {
        int n = 0;
        while msg[n] != 0 && n < 255 {
            error_text_buf[n] = msg[n];
            n += 1;
        }
        error_text_buf[n] = 0;
        throw (char^)@error_text_buf;
    }
    // the reason of a system error number in words (a negative number from a system call is fine)
    static String reason(int e) {
        if e < 0 { e = 0 - e; }
        if e == 1 { return "not allowed"; }
        if e == 2 { return "there is no file or folder with this name"; }
        if e == 4 { return "interrupted"; }
        if e == 9 { return "the file number is not open"; }
        if e == 12 { return "out of memory"; }
        if e == 13 { return "permission denied"; }
        if e == 17 { return "it exists already"; }
        if e == 20 { return "a part of the path is a file, not a folder"; }
        if e == 21 { return "this is a folder, not a file"; }
        if e == 22 { return "invalid argument"; }
        if e == 24 { return "too many files are open"; }
        if e == 28 { return "no space left on the device"; }
        if e == 32 { return "the other side has closed the connection"; }
        if e == 36 { return "the name is too long"; }
        if e == 39 { return "the folder is not empty"; }
        if e == 97 { return "this kind of address is not supported"; }
        if e == 98 { return "the address is already in use"; }
        if e == 99 { return "this address cannot be used here"; }
        if e == 104 { return "the connection was reset"; }
        if e == 110 { return "timed out"; }
        if e == 111 { return "connection refused (nothing listens there)"; }
        if e == 113 { return "no route to the host"; }
        return "the system refused";
    }
    // the kind of a system error number
    static ErrorKind kind_of(int e) {
        if e < 0 { e = 0 - e; }
        if e == 2 || e == 20 || e == 110 || e == 111 || e == 113 { return ErrorKind::NotFound; }
        if e == 13 || e == 1 { return ErrorKind::Denied; }
        if e == 22 || e == 21 || e == 36 || e == 97 { return ErrorKind::Invalid; }
        return ErrorKind::Io;
    }
    // the error for a system error number: "what: reason (error N)"
    static Error from_errno(int e, String what) {
        if e < 0 { e = 0 - e; }
        String m = what + ": " + Error::reason(e) + " (error " + str(e) + ")";
        return Error::make(Error::kind_of(e), m);
    }
    void free(self) {
        self.message.free();
    }
};

enum class Option<T> { Some(T value), None;
    bool is_some(self) { return self.__tag == 0; }
    bool is_none(self) { return self.__tag == 1; }
    // the value (throws if there is none)
    T unwrap(self) {
        switch self^ {
            Option::Some(_): {
                T out;                                             // the bytes of the value move out; the Option frees nothing of it later
                Mem::copy(@out, @self.Some_value, sizeof(T));
                Mem::set(@self.Some_value, 0, sizeof(T));
                return out;
            }
            Option::None: __panic("unwrap of a None");
        }
        __panic("unwrap of a None");
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Option::Some(_): {
                T out;
                Mem::copy(@out, @self.Some_value, sizeof(T));
                Mem::set(@self.Some_value, 0, sizeof(T));
                return out;
            }
            Option::None: return fallback;
        }
        return fallback;
    }
};

enum class Result<T, E> { Ok(T value), Err(E error);
    // the value, or the error is thrown as a text (the short forms of the library: fs.read(path), json.parse(text) ...)
    T take(self) {
        switch self^ {
            Result::Ok(_): {
                T out;                                         // the bytes of the value move out; the Result frees nothing of it later
                Mem::copy(@out, @self.Ok_value, sizeof(T));
                Mem::set(@self.Ok_value, 0, sizeof(T));
                return out;
            }
            Result::Err(e): Error::raise(e.message.c());
        }
        Error::raise("take of an Err");
    }
    bool is_ok(self) { return self.__tag == 0; }
    bool is_err(self) { return self.__tag == 1; }
    // the value (throws if it is an error)
    T unwrap(self) {
        switch self^ {
            Result::Ok(_): {
                T out;
                Mem::copy(@out, @self.Ok_value, sizeof(T));
                Mem::set(@self.Ok_value, 0, sizeof(T));
                return out;
            }
            Result::Err(e): __panic("unwrap of an Err");
        }
        __panic("unwrap of an Err");
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Result::Ok(_): {
                T out;
                Mem::copy(@out, @self.Ok_value, sizeof(T));
                Mem::set(@self.Ok_value, 0, sizeof(T));
                return out;
            }
            Result::Err(e): return fallback;
        }
        return fallback;
    }
};

// Arena: memory handed out in a row from one block and given back all at once.
//   Arena a;  a.init(4096);  int^ p = (int^)a.take(80);  ...  a.reset();  ...  a.free();
// take gives 8-byte aligned memory (zeroed), or null when the block is full.
struct Arena {
    int^ base;
    int size;
    int used;
    void init(self, int bytes) {
        self.base = (int^)Mem::alloc(bytes);
        self.size = bytes;
        self.used = 0;
    }
    void^ take(self, int bytes) {
        int n = (bytes + 7) / 8 * 8;
        if self.base == null || self.used + n > self.size { return null; }
        char^ b = (char^)self.base;
        void^ p = (void^)@b[self.used];
        Mem::set(p, 0, n);
        self.used += n;
        return p;
    }
    // everything taken so far is given back (the block stays)
    void reset(self) { self.used = 0; }
    int left(self) { return self.size - self.used; }
    void free(self) {
        if self.base != null { Mem::free((void^)self.base); }
        self.base = null;
        self.size = 0;
        self.used = 0;
    }
}

