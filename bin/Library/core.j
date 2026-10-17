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
            Option::Some(v): return v;
            Option::None: __panic("unwrap of a None");
        }
        __panic("unwrap of a None");
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Option::Some(v): return v;
            Option::None: return fallback;
        }
        return fallback;
    }
};

enum class Result<T, E> { Ok(T value), Err(E error);
    // the value, or the error is thrown as a text (the short forms of the library: fs.read(path), json.parse(text) ...)
    T take(self) {
        switch self^ {
            Result::Ok(v): return v;
            Result::Err(e): Error::raise(e.message.c());
        }
        Error::raise("take of an Err");
    }
    bool is_ok(self) { return self.__tag == 0; }
    bool is_err(self) { return self.__tag == 1; }
    // the value (throws if it is an error)
    T unwrap(self) {
        switch self^ {
            Result::Ok(v): return v;
            Result::Err(e): __panic("unwrap of an Err");
        }
        __panic("unwrap of an Err");
    }
    // the value, or fallback
    T or(self, T fallback) {
        switch self^ {
            Result::Ok(v): return v;
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

