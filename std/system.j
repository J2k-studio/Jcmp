// The system: Env (arguments and environment), Proc (run another program), Term (the terminal).
struct Env {
    // the value of an environment variable
    static Option<String> get(String name) {
        int^ gg0 = (int^)__gl();
        if gg0[0] == 0 { return Option<String>::None; }        // a shared library (-l) has no start of a program: no arguments, no environment
        int i = argc() + 1;
        int nl = name.len;
        char^ nm = name.c();
        while arg(i) != null {
            char^ e = arg(i);
            int k = 0;
            while k < nl && e[k] == nm[k] { k += 1; }
            if k == nl && e[k] == '=' {
                String v = "";
                v.append((char^)(e + nl + 1));
                return Option<String>::Some(v);
            }
            i += 1;
        }
        return Option<String>::None;
    }
    // the arguments of the program (the first one is the program itself)
    static String[] args() {
        int^ gg0 = (int^)__gl();
        if gg0[0] == 0 { String[] none = arr(1); return none; }        // a shared library (-l) has no start of a program: no arguments, no environment
        String[] r = arr(argc() + 1);
        for i in 0..argc() {
            String a = "";
            a.append((char^)arg(i));
            r.push(a);
        }
        return r;
    }
}

// running other programs. The program is looked for in the folders of PATH unless its name has a /.
//   int code = Proc::run("ls", args)?;            (the output goes where the program's own goes)
//   String text = Proc::output("echo", args)?;    (the output is returned as text)
struct Proc {
    // starts a child (stdout to wfd when wfd >= 0); returns its id, or a negative error number
    static int launch(String cmd, String[] args, int wfd) {
        int na = args.len;
        int^ argv = (int^)Mem::alloc(8 * (na + 2));
        argv[0] = (int)cmd.c();
        for i in 0..na { argv[i + 1] = (int)args[i].c(); }
        argv[na + 1] = 0;
        int ne = 0;
        int^ gg1 = (int^)__gl();
        while gg1[0] != 0 && arg(argc() + 1 + ne) != null { ne += 1; }
        int^ envp = (int^)Mem::alloc(8 * (ne + 1));
        for i in 0..ne { envp[i] = (int)arg(argc() + 1 + i); }
        envp[ne] = 0;
        int pid = Sys::fork();
        if pid == 0 {
            if wfd >= 0 { Sys::dup2(wfd, 1); }
            bool slash = false;
            for i in 0..cmd.len { if cmd[i] == '/' { slash = true; } }
            if slash {
                Sys::execve(cmd.c(), argv, envp);
            } else {
                String path = "";
                switch Env::get("PATH") {
                    Option::Some(p): path.append(p.c());
                    Option::None: path.append("/usr/bin:/bin");
                }
                int start = 0;
                for i in 0..path.len + 1 {
                    if i == path.len || path[i] == ':' {
                        String full = path.slice(start, i) + "/" + cmd;
                        Sys::execve(full.c(), argv, envp);
                        start = i + 1;
                    }
                }
            }
            Sys::exit(127);
        }
        Mem::free(argv);
        Mem::free(envp);
        return pid;
    }
    // waits for the child; its exit code (128 + the signal if it was killed)
    static int finish(int pid) {
        int status = 0;
        Sys::wait(pid, @status);
        int sig = status & 127;
        if sig != 0 { return 128 + sig; }
        return (status >> 8) & 255;
    }
    // runs a program and waits for it; its exit code (127 if it could not be started)
    static Result<int, Error> run(String cmd, String[] args) {
        int pid = Proc::launch(cmd, args, -1);
        if pid < 0 { return Result<int, Error>::Err(Error::make(ErrorKind::Other, "cannot start " + cmd)); }
        return Result<int, Error>::Ok(Proc::finish(pid));
    }
    // runs a program, waits for it and returns what it wrote to its output
    static Result<String, Error> output(String cmd, String[] args) {
        int fds[1];
        int rc = Sys::pipe(@fds);
        if rc < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Io, "cannot make a pipe")); }
        int rfd = fds[0] & 4294967295;
        int wfd = fds[0] >> 32;
        int pid = Proc::launch(cmd, args, wfd);
        Sys::close(wfd);
        if pid < 0 {
            Sys::close(rfd);
            return Result<String, Error>::Err(Error::make(ErrorKind::Other, "cannot start " + cmd));
        }
        String text = "";
        char buf[4096];
        int n = Sys::read(rfd, @buf, 4095);
        while n > 0 {
            buf[n] = 0;
            text.append((char^)@buf);
            n = Sys::read(rfd, @buf, 4095);
        }
        Sys::close(rfd);
        Proc::finish(pid);
        return Result<String, Error>::Ok(text);
    }
}

// the terminal: its size, and whether a key was pressed (a program that runs until told to stop)
//   int cols = Term::cols();   if Term::key_pressed() { break; }       (a line + Enter; Ctrl-C always stops a program)
struct Term {
    // the number of columns (80 if it cannot be asked)
    static int cols() {
        char ws[8];
        int rc = Sys::window_size(1, @ws);
        if rc < 0 { return 80; }
        int c = (ws[2] & 255) | ((ws[3] & 255) << 8);
        if c < 10 { return 80; }
        return c;
    }
    // the number of rows (24 if it cannot be asked)
    static int rows() {
        char ws[8];
        int rc = Sys::window_size(1, @ws);
        if rc < 0 { return 24; }
        int r = (ws[0] & 255) | ((ws[1] & 255) << 8);
        if r < 5 { return 24; }
        return r;
    }
    // true if something was typed (it is read and thrown away); nothing is waited for, and the terminal is not changed.
    // With the keyboard line by line, the text arrives when Enter is pressed.
    static bool key_pressed() {
        char pfd[8];
        char ts[16];
        for i in 0..8 { pfd[i] = 0; }
        for i in 0..16 { ts[i] = 0; }
        pfd[4] = 1;                                   // POLLIN on file 0
        int rc = Sys::ppoll(@pfd, 1, @ts);
        if rc <= 0 { return false; }
        if (pfd[6] & 1) == 0 { return false; }
        char buf[256];
        int n = Sys::read(0, @buf, 256);
        return n > 0;                                 // 0 is the end of the input: no key
    }
}

// the keyboard: a line, one key, Enter, a yes / no, a number (designed by AI at user request, adjustable: docs/syntax-design.md 90)
//   String name = Input::line();   int k = Input::key();   (one key, no Enter, nothing shown on the screen)
// It reads the file 0 byte by byte (it does not share the buffer of `cin`; use one of the two in a program).
struct Input {
    // a line without its new line; "" at the end of the input
    static String line() {
        String r = "";
        char c[2];
        int n = Sys::read(0, @c, 1);
        while n > 0 {
            if c[0] == 10 { return r; }
            c[1] = 0;
            r.append((char^)@c);
            n = Sys::read(0, @c, 1);
        }
        return r;
    }
    // the line as a whole number (an error when it is not one)
    static Result<int, Error> number() {
        String t = Input::line();
        int i = 0;
        bool neg = false;
        if t.len > 0 && t[0] == 45 { neg = true; i = 1; }
        if i >= t.len { return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "not a whole number: " + t)); }
        int v = 0;
        while i < t.len {
            int d = t[i] - 48;
            if d < 0 || d > 9 { return Result<int, Error>::Err(Error::make(ErrorKind::Parse, "not a whole number: " + t)); }
            v = v * 10 + d;
            i += 1;
        }
        if neg { v = 0 - v; }
        return Result<int, Error>::Ok(v);
    }
    // waits for Enter (the rest of the line is thrown away)
    static void enter() {
        Input::line();
    }
    // asks and waits for y or n (Enter alone is no); true for y / Y
    static bool yes(String question) {
        cout << question << " [y/n] ";
        String a = Input::line();
        if a.len > 0 && (a[0] == 121 || a[0] == 89) { return true; }
        return false;
    }
    // true when the file 0 has something to read within ms milliseconds (ms < 0: wait for ever)
    static bool ready(int ms) {
        int pfd[1];
        int ts[2];
        pfd[0] = 1 << 32;                               // fd 0, events POLLIN (the next 2 bytes), revents 0
        if ms >= 0 {
            ts[0] = ms / 1000;
            ts[1] = (ms % 1000) * 1000000;
            return Sys::ppoll(@pfd, 1, @ts) > 0;
        }
        return Sys::ppoll(@pfd, 1, null) > 0;
    }
    // one key without Enter and without an echo. A letter is its code; Escape is 27; the other keys are 257 up, 258 down, 259 right,
    // 260 left, 261 Home, 262 End, 263 Delete, 264 PageUp, 265 PageDown, 266 Insert, 270 .. 273 F1 .. F4; -1 at the end of the input.
    // When the input is not a terminal it is the next byte.
    static int key() {
        return Input::key_wait(0 - 1);
    }
    // the same, but it waits at most ms milliseconds; -2 when no key was pressed in that time
    static int key_wait(int ms) {
        char t[64];
        bool tty = Sys::isatty(0) == 0;
        if tty {
            syscall(29, 0, 21505, @t);                  // TCGETS
            char raw[64];
            for i in 0..64 { raw[i] = t[i]; }
            raw[12] = raw[12] & 245;                    // lflag low byte: no ICANON (2), no ECHO (8)
            raw[23] = 1;                                // VMIN: wait for 1 byte
            raw[22] = 0;                                // VTIME: no time limit
            syscall(29, 0, 21506, @raw);                // TCSETS
        }
        int k = 0 - 2;
        if ms < 0 || Input::ready(ms) {
            char b[4];
            int n = Sys::read(0, @b, 1);
            k = 0 - 1;
            if n > 0 {
                k = b[0] & 255;
                if k == 27 && tty && Input::ready(40) {
                    char e[2];
                    Sys::read(0, @e, 1);
                    if e[0] == 91 && Input::ready(40) {
                        Sys::read(0, @e, 1);
                        if e[0] == 65 { k = 257; }
                        else if e[0] == 66 { k = 258; }
                        else if e[0] == 67 { k = 259; }
                        else if e[0] == 68 { k = 260; }
                        else if e[0] == 72 { k = 261; }
                        else if e[0] == 70 { k = 262; }
                        else if e[0] >= 49 && e[0] <= 54 {
                            int code = e[0] - 48;                    // ESC [ n ~
                            if Input::ready(40) { Sys::read(0, @e, 1); }
                            if code == 1 { k = 261; }
                            else if code == 2 { k = 266; }
                            else if code == 3 { k = 263; }
                            else if code == 4 { k = 262; }
                            else if code == 5 { k = 264; }
                            else { k = 265; }
                        }
                    } else if e[0] == 79 && Input::ready(40) {
                        Sys::read(0, @e, 1);                         // ESC O P .. S: F1 .. F4
                        if e[0] >= 80 && e[0] <= 83 { k = 270 + e[0] - 80; }
                    }
                }
            }
        }
        if tty { syscall(29, 0, 21506, @t); }
        return k;
    }
    // a line typed without an echo (a password); on a terminal the new line is written for the user
    static String password() {
        char t[64];
        bool tty = Sys::isatty(0) == 0;
        if tty {
            syscall(29, 0, 21505, @t);
            char raw[64];
            for i in 0..64 { raw[i] = t[i]; }
            raw[12] = raw[12] & 247;                    // no ECHO (8)
            syscall(29, 0, 21506, @raw);
        }
        String r = Input::line();
        if tty {
            syscall(29, 0, 21506, @t);
            cout << "\n";
        }
        return r;
    }
    // a line as a decimal number (an error when it is not one)
    static double decimal() {
        return Input::line().to_double();
    }
}

// env, proc, term, read: the short names (Env::env.get(name), with  using Env;  env.get(name))

// the short names of the system unit (env, proc, term): <module>_<name>, the compiler adds the prefix
struct __System {
    static Option<String> env_get(String name) { return Env::get(name); }
    static String env_get_or(String name, String fallback) {
        Option<String> v = Env::get(name);
        switch v {
            Option::Some(s): return s;
            Option::None: return fallback;
        }
        return fallback;
    }
    static String[] env_args() { return Env::args(); }
    static int proc_run(String cmd, String[] args) { return Proc::run(cmd, args).take(); }
    static Result<int, Error> proc_try_run(String cmd, String[] args) { return Proc::run(cmd, args); }
    static String proc_output(String cmd, String[] args) { return Proc::output(cmd, args).take(); }
    static Result<String, Error> proc_try_output(String cmd, String[] args) { return Proc::output(cmd, args); }
    static int term_cols() { return Term::cols(); }
    static int term_rows() { return Term::rows(); }
    static bool term_key_pressed() { return Term::key_pressed(); }
    static String read_line() { return Input::line(); }
    static int read_number() { return Input::number().take(); }
    static Result<int, Error> read_try_number() { return Input::number(); }
    static void read_enter() { Input::enter(); }
    static bool read_yes(String question) { return Input::yes(question); }
    static int read_key() { return Input::key(); }
    static int read_key_timeout(int ms) { return Input::key_wait(ms); }
    static String read_password() { return Input::password(); }
    static double read_decimal() { return Input::decimal(); }
}
