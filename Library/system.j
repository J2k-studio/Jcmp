// The system: Env (arguments and environment), Proc (run another program), Term (the terminal).
struct Env {
    // the value of an environment variable
    static Option<String> get(String name) {
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
        while arg(argc() + 1 + ne) != null { ne += 1; }
        int^ envp = (int^)Mem::alloc(8 * (ne + 1));
        for i in 0..ne { envp[i] = (int)arg(argc() + 1 + i); }
        envp[ne] = 0;
        int pid = syscall(220, 17, 0, 0, 0, 0);
        if pid == 0 {
            if wfd >= 0 { syscall(24, wfd, 1, 0); }
            bool slash = false;
            for i in 0..cmd.len { if cmd[i] == '/' { slash = true; } }
            if slash {
                syscall(221, cmd.c(), argv, envp);
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
                        syscall(221, full.c(), argv, envp);
                        start = i + 1;
                    }
                }
            }
            syscall(93, 127);
        }
        Mem::free(argv);
        Mem::free(envp);
        return pid;
    }
    // waits for the child; its exit code (128 + the signal if it was killed)
    static int finish(int pid) {
        int status = 0;
        syscall(260, pid, @status, 0, 0);
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
        int rc = syscall(59, @fds, 0);
        if rc < 0 { return Result<String, Error>::Err(Error::make(ErrorKind::Io, "cannot make a pipe")); }
        int rfd = fds[0] & 4294967295;
        int wfd = fds[0] >> 32;
        int pid = Proc::launch(cmd, args, wfd);
        syscall(57, wfd);
        if pid < 0 {
            syscall(57, rfd);
            return Result<String, Error>::Err(Error::make(ErrorKind::Other, "cannot start " + cmd));
        }
        String text = "";
        char buf[4096];
        int n = syscall(63, rfd, @buf, 4095);
        while n > 0 {
            buf[n] = 0;
            text.append((char^)@buf);
            n = syscall(63, rfd, @buf, 4095);
        }
        syscall(57, rfd);
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
        int rc = syscall(29, 1, 0x5413, @ws);
        if rc < 0 { return 80; }
        int c = (ws[2] & 255) | ((ws[3] & 255) << 8);
        if c < 10 { return 80; }
        return c;
    }
    // the number of rows (24 if it cannot be asked)
    static int rows() {
        char ws[8];
        int rc = syscall(29, 1, 0x5413, @ws);
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
        int rc = syscall(73, @pfd, 1, @ts, 0, 8);
        if rc <= 0 { return false; }
        if (pfd[6] & 1) == 0 { return false; }
        char buf[256];
        int n = syscall(63, 0, @buf, 256);
        return n > 0;                                 // 0 is the end of the input: no key
    }
}

// env, proc, term: the short names (Env::env.get(name), with  using Env;  env.get(name))

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
}

// Log: messages for the person who runs the program, on the error output (standard error), with a level.
//   Log::set_level(2);    Log::info("not shown");    Log::error("shown: " + str(code));
// levels: 0 debug, 1 info, 2 warn, 3 error (the default is 1)
int std_log_level = 1;

struct Log {
    static void set_level(int level) { std_log_level = level; }
    static int level() { return std_log_level; }
    static void write(int level, String name, String msg) {
        if level < std_log_level { return; }
        String line = "[" + name + "] " + msg + "\n";
        Sys::write(2, line.c(), line.len);
    }
    static void debug(String msg) { Log::write(0, "debug", msg); }
    static void info(String msg) { Log::write(1, "info", msg); }
    static void warn(String msg) { Log::write(2, "warn", msg); }
    static void error(String msg) { Log::write(3, "error", msg); }
}

