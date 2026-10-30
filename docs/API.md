# The functions of the libraries

Made by `tools/make_api.sh` from the libraries (`jcmp -api NAME` writes one of them). Every function of a library is here, with the comment in front of it;
the categories and how to import them are in [STDLIB.md](STDLIB.md). A name that starts with a lower case word after `static` and is not meant for programs
(the helpers of a library, such as the steps of a hash) is listed too: the compiler does not hide them yet.

## core

```jk
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
    static void panic(char^ msg);
    // stop with the message if ok is false
    static void assert(bool ok, char^ msg);
    static int argc();
    static char^ arg(int i);
    // ---- a call that is not here yet
    static int call(int number, int a0, int a1, int a2, int a3, int a4, int a5);
    // is the first name (n letters) one of the real places of the system?
    static bool vr_system(char^ s, int n);
    // ---- the virtual root of Jaric. When the environment has JARIC_ROOT (the folder of the app: files/ with home, usr, ... and the links bin, etc, tmp, lib, var),
    // a path that begins with / and whose first name is a folder of that place is read there: /etc/hosts is JARIC_ROOT/etc/hosts, / is JARIC_ROOT, /u is the
    // storage of the user (/sdcard). The real places of the system (/proc, /dev, /sys, /sdcard, /storage, /data, /system ...) and every path that does not
    // begin with / stay as they are. Without JARIC_ROOT nothing changes. The answer is written in buf (4096 bytes) or is the path itself.
    static char^ vroot(char^ path, char^ buf);
    // the path of the real folder the other way: the answer of getcwd begins with JARIC_ROOT: it is shown as / ...
    static int vr_back(char^ buf, int n);

    // ---- files
    // flags and mode are the numbers of this machine; open_read / open_write / open_append / open_dir need none
    static int open(char^ path, int flags, int mode);
    static int open_read(char^ path);
    // create or empty the file; mode 0644 (before the umask)
    static int open_write(char^ path);
    // create the file if it is not there; writes go to the end
    static int open_append(char^ path);
    // a folder, to read with getdents
    static int open_dir(char^ path);
    static int close(int fd);
    static int read(int fd, void^ buf, int n);
    static int write(int fd, void^ buf, int n);
    // whence: 0 from the start, 1 from here, 2 from the end
    static int lseek(int fd, int offset, int whence);
    static int unlink(char^ path);
    static int rmdir(char^ path);
    static int rename(char^ from, char^ to);
    static int mkdir(char^ path, int mode);
    static int chmod(char^ path, int mode);
    // the details of a file in buf (128 bytes); the mode is the 4 bytes at offset 16, the size the 8 bytes at offset 48
    static int stat(char^ path, void^ buf);
    static int fstat(int fd, void^ buf);
    static int readlink(char^ path, char^ buf, int n);
    // the entries of a folder opened with open_dir (linux_dirent64)
    static int getdents(int fd, void^ buf, int n);
    static int getcwd(char^ buf, int n);
    // change the folder of the program (a virtual path is read as in open)
    static int chdir(char^ path);
    // is the file number a terminal? (the call TCGETS: 0 yes)
    static int isatty(int fd);
    // the size of the terminal in buf (8 bytes: rows, columns, 2 more numbers of 16 bits)
    static int window_size(int fd, void^ buf);
    static int pipe(void^ fds);
    static int dup2(int old, int fresh);
    // ---- memory
    // n bytes of fresh zeroed memory from the system (null on failure)
    static void^ mmap(int n);
    static int munmap(void^ p, int n);
    // prot: 0 nothing, 1 read, 2 write, 4 execute (added)
    static int mprotect(void^ p, int n, int prot);
    // ---- the program and its processes
    static void exit(int code);
    static int getpid();
    static int gettid();
    // send a signal to ONE process (pid > 0); the calls that reach a whole group of processes (pid <= 0) are refused here: use Sys::call for them
    static int kill(int pid, int sig);
    // a new process like this one (fork): 0 in the child, the id of the child in the parent
    static int fork();
    static int execve(char^ path, void^ argv, void^ envp);
    // wait for the child pid; its state goes to *status
    static int wait(int pid, int^ status);
    static int sleep_ms(int ms);
    static int yield();
    // sleep for the time in ts (ts[0] seconds, ts[1] nanoseconds)
    static int nanosleep(int^ ts);
    // the fast user lock of the kernel: op 128 waits while *addr == val, 129 wakes val waiters (the "private" kinds); 0 waits (shared)
    static int futex(int^ addr, int op, int val);
    // wait until one of the n file numbers in fds (struct pollfd, 8 bytes each) is ready, or the time in ts has passed (ts null: no limit)
    static int ppoll(void^ fds, int n, void^ ts);
    // 0 when the file or folder can be seen (it exists), else the error
    static int access(char^ path);
    // the clock: which = 0 the time of day, 1 a clock that only goes forward; the seconds and the nanoseconds go to ts[0] and ts[1]
    static int clock_gettime(int which, int^ ts);
    // n random bytes from the system
    static int random(void^ buf, int n);
    // ---- sockets (IPv4)
    static int socket_tcp();
    static int socket_udp();
    static int socketpair(void^ fds);
    static int bind(int fd, void^ addr, int len);
    static int listen(int fd, int backlog);
    static int connect(int fd, void^ addr, int len);
    static int accept(int fd);
    static int getsockname(int fd, void^ addr, int^ len);
    static int setsockopt(int fd, int level, int name, void^ value, int len);
    // wait for data at most ms milliseconds on a socket: the receive time out
    static int set_receive_timeout(int fd, int seconds);
}

// Option<T> and Result<T,E>: a value that may be missing, or an operation that may fail, as a value.
//   Option<int> a = Option<int>::Some(5);   Option<int> b = Option<int>::None;
//   Result<int, Error> r = parse(text);     int n = parse(text)?;      (? returns the error to the caller)
// switch takes a value apart:  switch r { Result::Ok(v): ...; Result::Err(e): ...; }

enum class ErrorKind { Other, NotFound, Denied, Invalid, Parse, Io }

char error_text_buf[256];
          // the text of a thrown error stays alive while the stack is unwound

// the usual error: what went wrong (kind) and a message
struct Error {
    ErrorKind kind;
    String message;
    static Error make(ErrorKind kind, String message);
    // throw a text (the short forms of the library throw instead of returning a Result; catch with try { } catch (e) { })
    static void raise(char^ msg);
    // the reason of a system error number in words (a negative number from a system call is fine)
    static String reason(int e);
    // the kind of a system error number
    static ErrorKind kind_of(int e);
    // the error for a system error number: "what: reason (error N)"
    static Error from_errno(int e, String what);
    void free(self);
}

enum class Option<T> { Some(T value), None;
    bool is_some(self);
    bool is_none(self);
    // the value (throws if there is none)
    T unwrap(self);
    // the value, or fallback
    T or(self, T fallback);
}

enum class Result<T, E> { Ok(T value), Err(E error);
    // the value, or the error is thrown as a text (the short forms of the library: fs.read(path), json.parse(text) ...)
    T take(self);
    bool is_ok(self);
    bool is_err(self);
    // the value (throws if it is an error)
    T unwrap(self);
    // the value, or fallback
    T or(self, T fallback);
}

// Arena: memory handed out in a row from one block and given back all at once.
//   Arena a;  a.init(4096);  int^ p = (int^)a.take(80);  ...  a.reset();  ...  a.free();
// take gives 8-byte aligned memory (zeroed), or null when the block is full.
struct Arena {
    int^ base;
    int size;
    int used;
    void init(self, int bytes);
    void^ take(self, int bytes);
    // everything taken so far is given back (the block stays)
    void reset(self);
    int left(self);
    void free(self);
}
```

## number

```jk
// Math: numbers. The double functions use the CPU's own instructions.
struct Math {
    static double abs(double x);
    static double min(double a, double b);
    static double max(double a, double b);
    static int min_int(int a, int b);
    static int max_int(int a, int b);
    static double sqrt(double x);
    // round down / up / toward zero
    static double floor(double x);
    static double ceil(double x);
    static double trunc(double x);
    // x to the power n (n a whole number, negative too): by squaring
    static double powi(double x, int n);
    // ---- numbers made from and taken apart into bits (the IEEE form)
    static double from_bits(int bits);
    static int to_bits(double x);
    static double inf();
    static double nan();
    static bool is_nan(double x);
    static bool is_inf(double x);
    static double pi();
    static double tau();
    static double e();
    static double sign(double x);
    // to the nearest whole number (halves away from zero)
    static double round(double x);
    static double clamp(double x, double lo, double hi);
    // a + (b - a) * t
    static double lerp(double a, double b, double t);
    static double radians(double deg);
    static double degrees(double rad);
    // the remainder of x / y with the sign of x
    static double fmod(double x, double y);
    // ---- e^x
    static double exp(double x);
    // ---- the natural logarithm
    static double log(double x);
    static double log2(double x);
    static double log10(double x);
    // x to the power y
    static double pow(double x, double y);
    static double cbrt(double x);
    static double hypot(double x, double y);
    // ---- sine, cosine, tangent (the angle in radians)
    static double sin(double x);
    static double cos(double x);
    static double tan(double x);
    // sin and cos for |r| <= 0.8 (the series)
    static double sin_poly(double r);
    static double cos_poly(double r);
    // ---- the inverse functions
    static double atan(double x);
    // the angle of the point (x, y) : -pi .. pi
    static double atan2(double y, double x);
    static double asin(double x);
    static double acos(double x);
    static double sinh(double x);
    static double cosh(double x);
    static double tanh(double x);
    static int iabs(int x);
    static int imin(int a, int b);
    static int imax(int a, int b);
    static int ipow(int x, int n);
}

// Num: conversions between numbers and text.
// text to numbers, as a Result (String.to_int() / to_double() throw instead)
struct Num {
    static Result<int, Error> parse_int(String s);
    static Result<double, Error> parse_double(String s);
}

// num: the short names (Num::num.parse_int(text), with  using Num;  num.parse_int(text)); a text that is not a number is thrown
struct __Num {
    static int parse_int(String s);
    static Result<int, Error> try_parse_int(String s);
    static double parse_double(String s);
    static Result<double, Error> try_parse_double(String s);
}
```

## text

```jk
// Str: functions on 0-terminated text (a char array, a string literal or a char^)
struct Str {
    static int len(char^ s);
    static bool eq(char^ a, char^ b);
    // < 0, 0 or > 0 like strcmp
    static int cmp(char^ a, char^ b);
    // copy src into dst (room for cap characters including the 0); returns the length
    static int copy(char^ dst, int cap, char^ src);
    // add src to the end of dst; returns the new length
    static int append(char^ dst, int cap, char^ src);
    // index of the first t in s, or -1
    static int find(char^ s, char^ t);
    static bool starts_with(char^ s, char^ prefix);
    // leading spaces, an optional sign, then digits (stops at the first other character)
    static int to_int(char^ s);
    // write v as text into dst (room for cap characters); returns the length
    static int from_int(char^ dst, int cap, int v);
}

// Hex: bytes as two hex digits each
//   Hex::encode("Hi") -> "4869"      Hex::decode("4869")? -> "Hi"
struct Hex {
    static String encode(String s);
    static int nibble(char c);
    static Result<String, Error> decode(String h);
}

// Base64 (RFC 4648, with = at the end)
//   Base64::encode("Man") -> "TWFu"      Base64::decode("TWFu")? -> "Man"
struct Base64 {
    static String encode(String s);
    static int value(char c);
    static Result<String, Error> decode(String b);
}

// hex, base64: the short names (Hex::hex.encode(s), with  using Hex;  hex.encode(s));  decode throws on a text that is not valid

// Fmt: numbers and text laid out for people.
//   Fmt::fixed(3.14159, 2) -> "3.14"      Fmt::pad_left("7", 3, '0') -> "007"      Fmt::thousands(1234567) -> "1,234,567"
//   Fmt::hex(255) -> "ff"      Fmt::bin(5) -> "101"      Fmt::percent(0.256, 1) -> "25.6%"      Fmt::bytes(1536) -> "1.5 KB"
struct Fmt {
    // s with c added on the left until it has `width` characters (a longer text stays as it is)
    static String pad_left(String s, int width, char c);
    // s with c added on the right
    static String pad_right(String s, int width, char c);
    // the number x with exactly `digits` digits after the point (0 .. 15), rounded half away from zero
    static String fixed(double x, int digits);
    // the digits of n (n >= 0) in the base b (2 .. 16)
    static String base(int n, int b);
    static String hex(int n);
    static String bin(int n);
    // 1234567 -> "1,234,567"
    static String thousands(int n);
    // 0.256 -> "25.6%"
    static String percent(double ratio, int digits);
    // a size in bytes: 1536 -> "1.5 KB"
    static String bytes(int n);
}

// Regex: a small pattern matcher (a backtracking one), for the common cases.
//   Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") -> true     (the whole text)
//   Regex::find("[0-9]+", "room 42, floor 7") -> 5                    (where the first match starts, or -1)
//   Regex::find_text("[0-9]+", "room 42, floor 7") -> "42"
//   Regex::find_all("[0-9]+", "room 42, floor 7") -> ["42", "7"]      Regex::replace(p, t, "#"), Regex::split(p, t), Regex::count(p, t)
// Pattern: a character, . (any), \d \w \s (and \D \W \S), [abc] [a-z] [^0-9], \. (a character that has a meaning), ^ $,
// x* x+ x? and x{n} x{n,} x{n,m} on one thing (greedy; a ? after them makes them lazy: x*?), ( ... ) a group (also with | inside, and
// with a quantifier after it; (?: ... ) is the same), and | between whole alternatives. There are no captures yet.
int rx_depth;
                       // how deep the matcher is (a group repeated many times is a deep recursion)
int rx_steps;
                       // the work of one search: a pattern that cannot end (a group that matches nothing, repeated) is stopped
int rx_qmin;
                        // the last quantifier read by quant(): its least and its most (-1: no limit), its length, and lazy
int rx_qmax;
int rx_qlen;
int rx_lazy;

struct Regex {
    // does the character c belong to the class at p[i] (a \d, \w, \s, a [..] set, a . or a literal)? the length of the item in rl
    static int item_len(String p, int i);
    static bool class_has(char e, char c);
    // does the single item p[i .. i + n) match the character c?
    static bool item_matches(String p, int i, int n, char c);
    // the quantifier at p[i] (i < pe): rx_qmin, rx_qmax (-1: no limit), rx_qlen (0: none) and rx_lazy
    static void quant(String p, int i, int pe);
    // the ")" that closes the "(" at p[i] (-1: none); p[i .. pe)
    static int group_end(String p, int i, int pe);
    // the end of a match of p[pi .. pe) at t[ti ..], or -1 (backtracking)
    static int m(String p, int pi, int pe, String t, int ti);
    static int m2(String p, int pi, int pe, String t, int ti);
    // a group "(inner)" repeated qmin .. qmax times, then the rest of the pattern: each branch of the group, followed by the group
    // again (with the counts one less) and the rest, is a pattern of its own
    static int group(String inner, int qmin, int qmax, int lazy, String rest, String t, int ti);
    // the parts of a pattern between the top-level | (not inside [ ], \ or ( ))
    static String[] alternatives(String p);
    // the end of the match that starts exactly at ti (every top-level branch is tried), or -1
    static int match_here(String p, String t, int ti);
    // the position where the first match starts (-1: none)
    static int find(String p, String t);
    // the text of the first match ("" when there is none: use find to tell the difference)
    static String find_text(String p, String t);
    // does the pattern match the whole text?
    static bool matches(String p, String t);
    // every match, from left to right, none overlapping (an empty match is skipped)
    static String[] find_all(String p, String t);
    static int count(String p, String t);
    // the text with every match replaced by `with`
    static String replace(String p, String t, String with);
    // the pieces of the text between the matches
    static String[] split(String p, String t);
}

// regex: the short names (Regex::regex.matches(p, t), with  using Regex;  regex.matches(p, t))

// the short names of the text unit (hex, base64, regex): <module>_<name>, the compiler adds the prefix
struct __Text {
    static String hex_encode(String s);
    static String hex_decode(String h);
    static Result<String, Error> hex_try_decode(String h);
    static String base64_encode(String s);
    static String base64_decode(String b);
    static Result<String, Error> base64_try_decode(String b);
    static int regex_find(String p, String t);
    static String regex_text(String p, String t);
    static bool regex_matches(String p, String t);
}
```

## files

```jk
enum class FileMode { Read, Write, Append, ReadWrite }

struct File {
    static i32 open(char^ path, FileMode mode);
    static i32 close(i32 fd);
    static i32 read(i32 fd, char buf[]);
    static i32 write(i32 fd, char buf[]);
    static i32 read_line(i32 fd, char line[]);
}

// Files and folders: Fs (whole files), Dir (folders). Needs the core (Result, Error) and text (Str).
// an Error for the system error number e (a negative number from a system call is fine) and what was being done
struct Fs {
    static Error error(int e, String what, String path);
    // the whole file as a String
    static Result<String, Error> read_text(String path);
    // the whole file as bytes in a String: any byte, also zero (read_text stops at a zero byte)
    static Result<String, Error> read_bytes(String path);
    // write the bytes of a String (any byte) to the file (made or emptied); Ok(the number of bytes)
    static Result<int, Error> write_bytes(String path, String data);
    // the lines of a file (without the line ends)
    static Result<String[], Error> read_lines(String path);
    // write the text to the file (made or emptied); Ok(the number of bytes)
    static Result<int, Error> write_text(String path, String text);
    // add the text at the end of the file (made if needed)
    static Result<int, Error> append_text(String path, String text);
    static Result<int, Error> put(String path, String text, int flags);
    static bool exists(String path);
    // the size of a file in bytes
    static Result<int, Error> size(String path);
    static Result<int, Error> remove(String path);
    static Result<int, Error> rename(String from, String to);
}

struct Dir {
    static bool exists(String path);
    static Result<int, Error> make(String path);
    // the folder and the ones above it (like mkdir -p)
    static Result<int, Error> make_all(String path);
    // remove an empty folder
    static Result<int, Error> remove(String path);
    // the names in a folder (not . and ..), in order
    static Result<String[], Error> list(String path);
    static Result<String, Error> current();
}

// fs, dir: the short names of the library (Fs::fs.read(p), with  using Fs;  fs.read(p)). A failure is thrown as a text (try / catch);
// try_name returns the Result. The long names above (Fs::read_text ...) keep working.

// Path: names of files (join, parent, extension ...).
// Path: the parts of a file name (the separator is /)
//   Path::join("a", "b.txt") -> "a/b.txt"   Path::name("a/b.txt") -> "b.txt"   Path::parent("a/b.txt") -> "a"
//   Path::ext("a/b.txt") -> "txt"   Path::stem("a/b.txt") -> "b"
struct Path {
    static String join(String a, String b);
    // the part after the last /
    static String name(String p);
    // everything before the last / ("." if there is none, "/" for a file in the root)
    static String parent(String p);
    // the part of the name after the last . ("" if there is none, or if the name starts with the only .)
    static String ext(String p);
    // the name without its extension
    static String stem(String p);
}

// path: the module name of Path (Path::path.join(a, b), with  using Path;  path.join(a, b))

// the short names of the files unit (fs, dir, path): Fs::fs.read(p), with  using Fs;  fs.read(p). A function is named <module>_<name> here
// (one struct for the three modules, because the number of structs of a program is limited); the compiler adds the prefix.
struct __Files {
    static String fs_read(String path);
    static Result<String, Error> fs_try_read(String path);
    static String[] fs_lines(String path);
    static Result<String[], Error> fs_try_lines(String path);
    static int fs_write(String path, String text);
    static Result<int, Error> fs_try_write(String path, String text);
    static int fs_append(String path, String text);
    static Result<int, Error> fs_try_append(String path, String text);
    static bool fs_exists(String path);
    static int fs_size(String path);
    static Result<int, Error> fs_try_size(String path);
    static int fs_remove(String path);
    static Result<int, Error> fs_try_remove(String path);
    static int fs_rename(String from, String to);
    static Result<int, Error> fs_try_rename(String from, String to);
    static String read_text(String path);
    static Result<String, Error> read_try_text(String path);
    static String read_bytes(String path);
    static Result<String, Error> read_try_bytes(String path);
    static String[] read_lines(String path);
    static Result<String[], Error> read_try_lines(String path);
    static bool dir_exists(String path);
    static int dir_make(String path);
    static Result<int, Error> dir_try_make(String path);
    static int dir_make_all(String path);
    static Result<int, Error> dir_try_make_all(String path);
    static int dir_remove(String path);
    static Result<int, Error> dir_try_remove(String path);
    static String[] dir_list(String path);
    static Result<String[], Error> dir_try_list(String path);
    static String dir_current();
    static Result<String, Error> dir_try_current();
    static String path_join(String a, String b);
    static String path_name(String p);
    static String path_parent(String p);
    static String path_ext(String p);
    static String path_stem(String p);
}
```

## system

```jk
// The system: Env (arguments and environment), Proc (run another program), Term (the terminal).
struct Env {
    // the value of an environment variable
    static Option<String> get(String name);
    // the arguments of the program (the first one is the program itself)
    static String[] args();
}

// running other programs. The program is looked for in the folders of PATH unless its name has a /.
//   int code = Proc::run("ls", args)?;            (the output goes where the program's own goes)
//   String text = Proc::output("echo", args)?;    (the output is returned as text)
struct Proc {
    // starts a child (stdout to wfd when wfd >= 0); returns its id, or a negative error number
    static int launch(String cmd, String[] args, int wfd);
    // waits for the child; its exit code (128 + the signal if it was killed)
    static int finish(int pid);
    // runs a program and waits for it; its exit code (127 if it could not be started)
    static Result<int, Error> run(String cmd, String[] args);
    // runs a program, waits for it and returns what it wrote to its output
    static Result<String, Error> output(String cmd, String[] args);
}

// the terminal: its size, and whether a key was pressed (a program that runs until told to stop)
//   int cols = Term::cols();   if Term::key_pressed() { break; }       (a line + Enter; Ctrl-C always stops a program)
struct Term {
    // the number of columns (80 if it cannot be asked)
    static int cols();
    // the number of rows (24 if it cannot be asked)
    static int rows();
    // true if something was typed (it is read and thrown away); nothing is waited for, and the terminal is not changed.
    // With the keyboard line by line, the text arrives when Enter is pressed.
    static bool key_pressed();
}

// the keyboard: a line, one key, Enter, a yes / no, a number (designed by AI at user request, adjustable: docs/syntax-design.md 90)
//   String name = Input::line();   int k = Input::key();   (one key, no Enter, nothing shown on the screen)
// It reads the file 0 byte by byte (it does not share the buffer of `cin`; use one of the two in a program).
struct Input {
    // a line without its new line; "" at the end of the input
    static String line();
    // the line as a whole number (an error when it is not one)
    static Result<int, Error> number();
    // waits for Enter (the rest of the line is thrown away)
    static void enter();
    // asks and waits for y or n (Enter alone is no); true for y / Y
    static bool yes(String question);
    // true when the file 0 has something to read within ms milliseconds (ms < 0: wait for ever)
    static bool ready(int ms);
    // one key without Enter and without an echo. A letter is its code; Escape is 27; the other keys are 257 up, 258 down, 259 right,
    // 260 left, 261 Home, 262 End, 263 Delete, 264 PageUp, 265 PageDown, 266 Insert, 270 .. 273 F1 .. F4; -1 at the end of the input.
    // When the input is not a terminal it is the next byte.
    static int key();
    // the same, but it waits at most ms milliseconds; -2 when no key was pressed in that time
    static int key_wait(int ms);
    // a line typed without an echo (a password); on a terminal the new line is written for the user
    static String password();
    // a line as a decimal number (an error when it is not one)
    static double decimal();
}

// env, proc, term, read: the short names (Env::env.get(name), with  using Env;  env.get(name))

// the short names of the system unit (env, proc, term): <module>_<name>, the compiler adds the prefix
struct __System {
    static Option<String> env_get(String name);
    static String env_get_or(String name, String fallback);
    static String[] env_args();
    static int proc_run(String cmd, String[] args);
    static Result<int, Error> proc_try_run(String cmd, String[] args);
    static String proc_output(String cmd, String[] args);
    static Result<String, Error> proc_try_output(String cmd, String[] args);
    static int term_cols();
    static int term_rows();
    static bool term_key_pressed();
    static String read_line();
    static int read_number();
    static Result<int, Error> read_try_number();
    static void read_enter();
    static bool read_yes(String question);
    static int read_key();
    static int read_key_timeout(int ms);
    static String read_password();
    static double read_decimal();
}

// Log: messages for the person who runs the program, on the error output (standard error), with a level.
//   Log::set_level(2);    Log::info("not shown");    Log::error("shown: " + str(code));
// levels: 0 debug, 1 info, 2 warn, 3 error (the default is 1)
int std_log_level = 1;

struct Log {
    static void set_level(int level);
    static int level();
    static void write(int level, String name, String msg);
    static void debug(String msg);
    static void info(String msg);
    static void warn(String msg);
    static void error(String msg);
}
```

## time

```jk
// Time and random numbers: Time (clock, sleep), Random (a generator).
struct Time {
    // milliseconds since 1970 (the clock of the computer)
    static int now_ms();
    // a clock that only goes forward, in nanoseconds: for measuring how long something takes
    static int mono_ns();
    static void sleep_ms(int ms);
}

u64 std_rand_state;

struct Random {
    // start the series from a number (the same number gives the same series)
    static void seed(int s);
    // the next number: 0 or more (xorshift64)
    static int next();
    // a number from lo up to (not including) hi
    static int range(int lo, int hi);
    // a decimal number from 0 up to (not including) 1
    static double unit();
}

// time, random: the short names (Time::time.now_ms(), with  using Time;  time.now_ms()  and  random.range(1, 6))

// the short names of the time unit (time, random): <module>_<name>, the compiler adds the prefix
struct __TimeM {
    static int time_now_ms();
    static int time_mono_ns();
    static void time_sleep_ms(int ms);
    static void random_seed(int s);
    static int random_next();
    static int random_range(int lo, int hi);
    static double random_unit();
}

// Date: a day and a time on the calendar (the Gregorian calendar, UTC), from and to seconds since 1970.
//   Date d;  d.set_unix(86400 * 365);  cout << d.text() << " " << d.weekday() << "\n";     // 1971-01-01 00:00:00 5
struct Date {
    int year;
    int month;
           // 1 .. 12
    int day;
             // 1 .. 31
    int hour;
    int minute;
    int second;

    static bool is_leap(int y);
    static int days_in_month(int y, int m);
    // the number of days from 1970-01-01 to the day y-m-d (negative before it)
    static int days_from_civil(int y, int m, int d);
    // the date and the time of `secs` seconds since 1970-01-01 00:00:00
    void set_unix(self, int secs);
    // seconds since 1970-01-01 00:00:00
    int unix(self);
    // 0 Sunday .. 6 Saturday
    int weekday(self);
    // the day of the year, 1 .. 366
    int day_of_year(self);
    void add_days(self, int n);
    // "2024-02-29 13:05:09"
    String text(self);
}
```

## data

```jk
// Map<K,V> and Set<T>: hash tables (open addressing, linear probing). K and T can be int, char, double,
// pointers or String. Both have a free(self) method, so a local one is freed at the end of its block.

struct Map<K, V> {
    K[] keys;
    V[] vals;
    int[] st;
                  // 0 empty, 1 used, 2 deleted
    int len;
                   // how many keys
    int used;
                  // used + deleted places

    // the place of key k, or -1
    int find(self, K k);
    bool has(self, K k);
    // the value of key k (throws "key not found")
    V get(self, K k);
    // the value of key k as an Option: Some(value) or None
    Option<V> try_get(self, K k);
    void put(self, K k, V v);
    // true if key k was there
    bool remove(self, K k);
    void rehash(self, int cap);
    // a new array with the keys (in table order)
    K[] keys_list(self);
    V[] values_list(self);
    void free(self);
}

struct Set<T> {
    T[] items;
    int[] st;
    int len;
    int used;

    int find(self, T x);
    bool has(self, T x);
    // true if x was new
    bool add(self, T x);
    bool remove(self, T x);
    void rehash(self, int cap);
    T[] items_list(self);
    void free(self);
}

// ---------------------------------------------------------------------------------------------- sorting and searching
// Written with the type: sort_by<int>(a, less). `less(x, y)` is true when x must come before y; the sort is stable (merge sort, one
// buffer of the same length) and takes n log n steps.

void sort_by<T>(T[] a, bool(T, T)^ less);

// the first place i of the sorted array a where a[i] >= x (a.len when there is none)
int lower_bound<T>(T[] a, T x);

// the first place i where a[i] > x
int upper_bound<T>(T[] a, T x);

// the place of x in the sorted array a, or -1
int binary_search<T>(T[] a, T x);

// ---------------------------------------------------------------------------------------------- Queue, Deque, Heap
// Queue<T>: first in, first out (a ring buffer). Deque<T>: also at the front. Heap<T>: the smallest element (by `<`) comes out first.
// Each has len and free(self); pop / front / back on an empty one throw "empty".

struct Queue<T> {
    T[] items;
    int head;
    int len;

    void push(self, T x);
    T front(self);
    T pop(self);
    void free(self);
}

struct Deque<T> {
    T[] items;
    int head;
    int len;

    void grow(self);
    void push_back(self, T x);
    void push_front(self, T x);
    T front(self);
    T back(self);
    T pop_front(self);
    T pop_back(self);
    // the element number i from the front
    T get(self, int i);
    void free(self);
}

struct Heap<T> {
    T[] items;
    int len;

    void push(self, T x);
    T top(self);
    T pop(self);
    void free(self);
}

// ---------------------------------------------------------------------------------------------- Span<T>
// A view of a part of an array: no copy, no ownership (nothing to free; do not `push` to the array while a span of it is alive).
//   Span<int> s = span<int>(a, 1, 5);      // the elements 1, 2, 3, 4 of a
//   s.get(0)  s.set(0, 9)  s.len  s.sub(1, 3)  s.to_array()
// A write through the span changes the array. The index is checked (throws "span index out of range").

struct Span<T> {
    T[] base;
    int off;
    int len;

    T get(self, int i);
    void set(self, int i, T x);
    // the part lo .. hi of this span (a view of the same array)
    Span<T> sub(self, int lo, int hi);
    // a new array with a copy of the elements (the caller frees it)
    T[] to_array(self);
}

Span<T> span<T>(T[] a, int lo, int hi);

// JSON: Json::parse(text) gives a document, a table of nodes; a node is a number (-1 means "none").
//   JsonDoc doc = Json::parse(text)?;
//   int name = doc.get(doc.root(), "name");          String s = doc.text(name);
//   int first = doc.at(doc.get(doc.root(), "list"), 0);    double d = doc.number(first);
//   String out = doc.dump(doc.root());               // back to (compact) JSON text
// json_quote(s) makes a JSON string literal; json_num_text(x) is a number as text.
// helpers (also reachable as Json::quote and Json::num_text)
String json_int_text(int v);
// a number as the shortest text that reads back the same (up to 15 digits); nan and inf are null
String json_num_text(double x);
// a JSON string literal for s (with the quotes)
String json_quote(String s);

struct JsonDoc {
    String src;
    int pos;
    String err;
    int[] kind;
                  // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object
    double[] num;
    String[] txt;
                // the value of a string node
    String[] key;
                // the name of a node that is a member of an object
    int[] first;
                 // the first child (array, object)
    int[] last;
    int[] next;
                  // the next brother
    void free(self);
    // ---- reading (JsonDoc is made by Json::parse)
    int fail(self, String m);
    void skip_ws(self);
    // a new node; its text and name are stored with it
    int add(self, int k, String t, String name);
    // puts node c at the end of the children of node p
    void link(self, int p, int c);
    bool word(self, String w);
    int value(self, String name);
    int number_lit(self, String name);
    int hex4(self);
    // the string at pos (which is the opening quote); the text is decoded; err is set on a mistake
    String string_lit(self);
    int array(self, String name);
    int object(self, String name);

    // ---- looking at a document (n is a node; -1 or a wrong kind gives an empty answer)
    int root(self);
    // 0 null, 1 false, 2 true, 3 number, 4 string, 5 array, 6 object; -1 for no node
    int kind_of(self, int n);
    int len(self, int n);
    // the i-th element of an array or member of an object (counted from 0), or -1
    int at(self, int n, int i);
    // the member of an object with this name, or -1
    int get(self, int n, String name);
    bool has(self, int n, String name);
    // the name of a node that is a member of an object
    String name_of(self, int n);
    String text(self, int n);
    double number(self, int n);
    int integer(self, int n);
    bool boolean(self, int n);
    bool is_null(self, int n);

    // ---- writing: the node and what is below it as compact JSON text
    String dump(self, int n);
}

// the entry points: Json::parse(text), Json::quote(s), Json::num_text(x)
struct Json {
    static String quote(String s);
    static String num_text(double x);
    static Result<JsonDoc, Error> parse(String text);
}

// json: Json::json.parse(text), with  using Json;  json.parse(text). A text that is not JSON is thrown as an error; try_parse returns the Result.

// Csv: one line of comma separated values, with "quoted, fields" and "" for a quote inside a field.
//   String[] f = Csv::split_line("a,\"b,c\",d");      // a  b,c  d
//   String line = Csv::join_line(f);                  // a,"b,c",d
struct Csv {
    static String[] split_line(String line);
    static String quote_field(String f);
    static String join_line(String[] fields);
}

// csv: the short names (Csv::csv.split(line), with  using Csv;  csv.split(line))

// Toml: the simple part of TOML for settings: [sections], key = "text" | number | true | false, # comments.
// A key is written section.key (a key before any section is written alone).
//   String cfg = Fs::read_text("app.toml").unwrap();
//   Option<String> name = Toml::get(cfg, "server.name");      Option<int> port = Toml::get_int(cfg, "server.port");
struct Toml {
    // the value of the key as it is written (a quoted text without its quotes), or None
    static Option<String> get(String text, String key);
    static Option<int> get_int(String text, String key);
    static Option<bool> get_bool(String text, String key);
    static Option<double> get_double(String text, String key);
}

// toml: the short names (Toml::toml.get(text, key), with  using Toml;  toml.get(text, key)); get returns an Option, get_or a value

// the short names of the data unit (csv, json, toml): <module>_<name>, the compiler adds the prefix
struct __Data {
    static String[] csv_split(String line);
    static String csv_quote(String f);
    static String csv_join(String[] fields);
    static JsonDoc json_parse(String text);
    static Result<JsonDoc, Error> json_try_parse(String text);
    static String json_quote(String s);
    static String json_num_text(double x);
    static Option<String> toml_get(String text, String key);
    static String toml_get_or(String text, String key, String fallback);
    static Option<int> toml_get_int(String text, String key);
    static Option<bool> toml_get_bool(String text, String key);
    static Option<double> toml_get_double(String text, String key);
}
```

## crypto

```jk
// SHA-256 (FIPS 180-4): a 256-bit fingerprint of data, as 64 hex digits.
//   String h = Sha256::hex("abc");            // ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
//   String f = Sha256::file("jcmp")?;         // the same for a file (any bytes)
struct Sha256 {
    static void init(int^ st);
    static void constants(int^ st);
    // the 32 bits of x turned right by n places (n = 1 .. 31); the mask first: the compiler then knows the value fits in 32 bits and
    // makes one `ror w` of it
    static int rotr(int x, int n);
    // one block of 64 bytes at p
    static void block(int^ st, char^ p);
    // the last bytes (tn < 64) of a message of total bytes, padded; then the digest as hex
    static String finish(int^ st, char^ tail, int tn, int total);
    // the digest of the bytes of a String
    static String hex(String s);
    // the digest of the bytes of a file
    static Result<String, Error> file(String path);
}

// hash: the short names (Hash::hash.sha256(text), with  using Hash;  hash.sha256(text)); a file that cannot be read is thrown
struct Hash {
    static String sha256(String s);
    static String sha256_file(String path);
    static Result<String, Error> try_sha256_file(String path);
}

// Crypto: the hashes and the key derivation that TLS needs, on raw bytes (a pointer and a length; the answer goes to a buffer the caller gives).
//   SHA-384 / SHA-512 (FIPS 180-4), HMAC (RFC 2104), HKDF (RFC 5869). Tested with the vectors of the RFCs (test/t456_crypto.jk).
//   char out[48];   Crypto::sha384(data, n, @out);
// Designed by the assistant (2026-10-17, the first pieces of TLS for jget: docs/design/17-tls.md), adjustable. Not constant time.
struct Crypto {
    static void sha512_init(int^ h);
    static void sha384_init(int^ h);
    static void sha512_constants(int^ k);
    // the 64-bit right rotation (the shift of a whole number is arithmetic, so the high bits are cut)
    static int rotr64(int x, int n);
    static int shr64(int x, int n);
    static int load64(char^ p);
    static void store64(char^ p, int v);
    // one block of 128 bytes; h: the 8 words of the state; k: the 80 constants; w: 80 words of room
    static void sha512_block(int^ h, int^ k, int^ w, char^ blk);
    // the digest of n bytes: bits = 512 (64 bytes out) or 384 (48 bytes out)
    static void sha512_family(int bits, char^ data, int n, char^ out);
    static void sha384(char^ data, int n, char^ out);
    static void sha512(char^ data, int n, char^ out);
    // SHA-256 on raw bytes (the digest of 32 bytes goes to out)
    static void sha256(char^ data, int n, char^ out);
    // the digest of the algorithm alg (256, 384 or 512); the number of bytes it gives
    static int hash(int alg, char^ data, int n, char^ out);
    static int hash_size(int alg);
    // HMAC (RFC 2104) with the hash alg; out gets hash_size(alg) bytes
    static void hmac(int alg, char^ key, int klen, char^ msg, int mlen, char^ out);
    // HKDF-Extract (RFC 5869): prk = HMAC(salt, ikm); an empty salt is hash_size zero bytes
    static void hkdf_extract(int alg, char^ salt, int slen, char^ ikm, int ilen, char^ prk);
    // HKDF-Expand: length bytes of output keying material (length <= 255 * hash_size)
    static void hkdf_expand(int alg, char^ prk, int plen, char^ info, int ilen, char^ okm, int length);
    // ---------------------------------------------------------------- ChaCha20 and Poly1305 (RFC 8439)
    static int rotl32(int x, int n);
    static int le32(char^ p);
    static void put_le32(char^ p, int v);
    static void chacha_quarter(int^ x, int a, int b, int c, int d);
    // one block of 64 bytes of the key stream: key 32 bytes, nonce 12 bytes
    static void chacha20_block(char^ key, int counter, char^ nonce, char^ out);
    // data xor key stream (encrypts and decrypts); the first block uses `counter`; out may be the same buffer as in
    static void chacha20_xor(char^ key, int counter, char^ nonce, char^ in, int n, char^ out);
    // Poly1305 of n bytes with the one-time key (32 bytes); the tag (16 bytes) goes to out
    static void poly1305(char^ key, char^ msg, int n, char^ out);
    // the data that Poly1305 signs in the AEAD: aad, padding to 16, ciphertext, padding to 16, the two lengths (8 bytes each)
    static void aead_tag(char^ key, char^ nonce, char^ aad, int alen, char^ ct, int clen, char^ tag);
    // ChaCha20-Poly1305 AEAD (RFC 8439): encrypts n bytes of in into out (the same size) and writes the 16 bytes tag
    static void aead_seal(char^ key, char^ nonce, char^ aad, int alen, char^ in, int n, char^ out, char^ tag);
    // checks the tag of the n bytes of ciphertext and decrypts them into out; false (and out is not written) when the tag is wrong
    static bool aead_open(char^ key, char^ nonce, char^ aad, int alen, char^ ct, int n, char^ tag, char^ out);
    // ---------------------------------------------------------------- X25519 (RFC 7748; the numbers are 16 limbs of 16 bits, after TweetNaCl)
    static void gf_car(int^ o);
    static void gf_sel(int^ p, int^ q, int b);
    static void gf_pack(char^ o, int^ n);
    static void gf_unpack(int^ o, char^ n);
    static void gf_add(int^ o, int^ a, int^ b);
    static void gf_sub(int^ o, int^ a, int^ b);
    static void gf_mul(int^ o, int^ a, int^ b);
    static void gf_inv(int^ o, int^ x);
    // q = n * p on Curve25519 (n: 32 bytes, p: 32 bytes, q: 32 bytes)
    static void x25519(char^ q, char^ n, char^ p);
    // the public key of a private key (32 random bytes): n * 9
    static void x25519_public(char^ pub, char^ priv);
    // ---------------------------------------------------------------- TLS 1.3 client (RFC 8446), cipher suite TLS_CHACHA20_POLY1305_SHA256, key exchange X25519
    // A connection is a block of memory (its address is the handle). The numbers (8 bytes each) are at the offsets 0..120, the keys after them.
    //   0 fd  8 write sequence  16 read sequence  24 write encrypted?  32 read encrypted?  40 bytes waiting in inbuf  48 plain bytes ready  56 where the plain bytes start
    //   64 inbuf (address)  72 plainbuf (address)  80 transcript (address)  88 transcript length  96 certificates (address)  104 certificates length  112 peer closed?
    //   392 cipher suite  400 CertificateVerify (address)  408 its size  416 transcript hash at CertificateVerify (32)  128 write key (32)  160 write iv (12)  176 read key (32)  208 read iv (12)  224 client handshake secret (32)  256 server handshake secret (32)  288 handshake secret (32)
    static int tls_geti(char^ c, int off);
    static void tls_seti(char^ c, int off, int v);
    static void tls_put16(char^ p, int v);
    static void tls_put24(char^ p, int v);
    static int tls_get16(char^ p);
    static int tls_get24(char^ p);
    // HKDF-Expand-Label (RFC 8446 7.1) with SHA-256: out gets length bytes
    static void tls_expand_label(char^ secret, String label, char^ context, int clen, char^ out, int length);
    // Derive-Secret: the label and the hash of the transcript
    static void tls_derive(char^ secret, String label, char^ transcript, int tlen, char^ out);
    static void tls_random(char^ p, int n);
    // n bytes from the socket into p (false when the other side closes first)
    static bool tls_read_exact(int fd, char^ p, int n);
    static bool tls_write_all(int fd, char^ p, int n);
    // append a handshake message to the transcript
    static void tls_transcript(char^ c, char^ msg, int n);
    static void tls_nonce(char^ iv, int seq, char^ out);
    // send one record: type, content n bytes; encrypted when the write side has keys
    static bool tls_send_record(char^ c, int type, char^ data, int n);
    // read one record into plainbuf: gives the content type (the inner one when it was encrypted) and sets plain length at 48; -1 when the line is closed or the record is bad
    static int tls_read_record(char^ c);
    static void tls_set_keys(char^ c, int write, char^ secret);
    // starts TLS on a socket that is connected (fd): gives the handle of the connection. host is the name for the server (SNI) and for the check of the certificate.
    // insecure = 1: the certificate is NOT checked (only for tests against a server of your own). On a failure the socket is closed.
    static Result<int, Error> tls_connect(int fd, String host, int insecure);
    // the check of what the server sent: the chain of certificates (trusted, named, in date) and the signature of CertificateVerify made with the key of the first one. "" when good.
    static String tls_check_server(char^ c, String host);
    // close the socket and free the memory of the connection
    static void tls_release(char^ c);
    static Result<int, Error> tls_fail(char^ c, String why);
    // send data over the connection
    static bool tls_send(int h, String data);
    // the next piece of application data ("" when the server closed the connection)
    static String tls_recv(int h);
    static void tls_close(int h);
    // ---------------------------------------------------------------- AES-128 and GCM (FIPS 197, NIST SP 800-38D)
    static void aes_sbox(char^ out);
    static int aes_xtime(int a);
    // the 11 round keys of a 16 byte key into rk (176 bytes); sb: the S-box (256 bytes)
    static void aes_expand(char^ key, char^ rk, char^ sb);
    // one block of 16 bytes encrypted (in and out may be the same)
    static void aes_encrypt(char^ rk, char^ sb, char^ in, char^ out);
    // multiplication in GF(2^128) of GCM: x = x * h (both as 16 bytes, big-endian bit order of the standard)
    static void ghash_mul(char^ x, char^ h);
    // GHASH of the aad and the ciphertext, then the tag = E(J0) xor GHASH
    static void gcm_tag(char^ rk, char^ sb, char^ h, char^ j0, char^ aad, int alen, char^ ct, int clen, char^ tag);
    // counter mode starting at the counter block cb (the last 4 bytes are the counter); in -> out
    static void gcm_ctr(char^ rk, char^ sb, char^ cb0, char^ in, int n, char^ out);
    // AES-128-GCM with a 12 byte iv: encrypts n bytes of in into out, writes the 16 bytes tag
    static void gcm_seal(char^ key, char^ iv, char^ aad, int alen, char^ in, int n, char^ out, char^ tag);
    // checks the tag and decrypts; false (out not written) when the tag is wrong
    static bool gcm_open(char^ key, char^ iv, char^ aad, int alen, char^ ct, int n, char^ tag, char^ out);
    // ---------------------------------------------------------------- big numbers (Montgomery arithmetic) for RSA and the curves
    // A number is an array of n limbs of 28 bits, the least significant first. The modulus must be odd.
    static void bn_from_bytes(int^ a, int n, char^ b, int len);
    // the number as len bytes, big-endian (it must fit)
    static void bn_to_bytes(int^ a, int n, char^ out, int len);
    static int bn_cmp(int^ a, int^ b, int n);
    static bool bn_is_zero(int^ a, int n);
    // a = a - b (the borrow out is returned)
    static int bn_sub(int^ a, int^ b, int n);
    // a = a + b (the carry out is returned)
    static int bn_add(int^ a, int^ b, int n);
    // -m^-1 mod 2^28
    static int mont_n0(int m0);
    // r = a * b / R mod m   (R = 2^(28 n)); r may be the same array as a or b
    static void mont_mul(int^ r, int^ a, int^ b, int^ m, int n, int n0);
    // rr = R^2 mod m (by doubling), n0 is returned
    static int mont_setup(int^ m, int n, int^ rr);
    // out = base ^ e mod m, e given as bytes (big-endian); base < m
    static void mont_pow(int^ out, int^ base, char^ e, int elen, int^ m, int n, int^ rr, int n0);
    // ---------------------------------------------------------------- RSA signatures (RFC 8017), checking only
    // the public key as big-endian bytes: modulus nb (nlen), exponent eb (elen). halg: 256, 384 or 512 (the hash of the signed message).
    static bool rsa_public(char^ nb, int nlen, char^ eb, int elen, char^ sig, int slen, char^ em);
    // the DigestInfo prefix of a hash (RFC 8017 9.2); the length
    static int rsa_prefix(int halg, char^ out);
    // RSASSA-PKCS1-v1_5: the signature of the message msg
    static bool rsa_verify_pkcs1(char^ nb, int nlen, char^ eb, int elen, int halg, char^ msg, int mlen, char^ sig, int slen);
    // MGF1 (RFC 8017 B.2.1): length bytes from the seed
    static void mgf1(int halg, char^ seed, int slen, char^ out, int length);
    // RSASSA-PSS with MGF1 and a salt as long as the hash (what TLS 1.3 uses): the signature of the message msg
    static bool rsa_verify_pss(char^ nb, int nlen, char^ eb, int elen, int halg, char^ msg, int mlen, char^ sig, int slen);
    // ---------------------------------------------------------------- ECDSA on P-256 and P-384 (checking only; the curves a = -3)
    static int unhex(String h, char^ out);
    // the constants of a curve (256 or 384) as big-endian bytes: which = 0 p, 1 n, 2 Gx, 3 Gy, 4 b
    static String ec_const(int curve, int which);
    // modular addition / subtraction of numbers below m
    static void fe_add(int^ r, int^ a, int^ b, int^ m, int n);
    static void fe_sub(int^ r, int^ a, int^ b, int^ m, int n);
    // points in Jacobian coordinates: 3 numbers of 16 limbs in one array (x at 0, y at 16, z at 32); z = 0 is the point at infinity.
    // The context: pm (the prime) at 0, prr at 16, [pn0, n] at 32,33 ; the numbers are in the Montgomery form.
    static void ec_double(int^ r, int^ pt, int^ ctx);
    static void ec_add(int^ r, int^ p1, int^ p2, int^ ctx);
    // r = k * pt, k as limbs (kn limbs)
    static void ec_mul(int^ r, int^ k, int kn, int^ pt, int^ ctx);
    // ECDSA (FIPS 186-4 6.4): the public key is the point (qx, qy) as big-endian bytes of the size of the curve; e: the hash of the message (bytes);
    // r and s: the two numbers of the signature (bytes). curve: 256 or 384.
    static bool ecdsa_verify(int curve, char^ qx, char^ qy, char^ hash, int hlen, char^ rb, int rlen, char^ sb, int slen);
    // a DER signature (SEQUENCE { INTEGER r, INTEGER s }) of a message that is hashed here with halg
    static bool ecdsa_verify_der(int curve, char^ qx, char^ qy, int halg, char^ msg, int mlen, char^ sig, int slen);
    // ---------------------------------------------------------------- X.509 certificates (DER), the chain, the names, the dates
    // the element at p (avail bytes follow): its total size, or -1; info gets [tag, header size, content size]
    static int der_elem(char^ p, int avail, int^ info);
    static bool bytes_equal(char^ a, char^ b, int n);
    // does the OID (the content bytes at p, n long) equal the hex text?
    static bool oid_is(char^ p, int n, String hex);
    // the fields of a certificate (offsets into the DER bytes `c`, 0 when absent):
    //  0 tbs offset  1 tbs size   2 outer signature algorithm (oid content offset)  3 its size   4 signature bits  5 size   6 issuer (whole element)  7 size   8 subject  9 size
    //  10 notBefore (content)  11 size  12 tag   13 notAfter  14 size  15 tag   16 key algorithm oid  17 size   18 key parameters oid (content)  19 size   20 public key bits  21 size
    //  22 subjectAltName extension value (the content of its OCTET STRING)  23 size   24 basicConstraints: -1 absent, 0 not a CA, 1 a CA
    static bool x509_parse(char^ c, int len, int^ o);
    // days since 1970-01-01 of a date (the civil calendar)
    static int days_from_civil(int y, int m, int d);
    static int two(char^ p);
    // the seconds since 1970 of a UTCTime (tag 0x17: YYMMDDHHMMSSZ) or GeneralizedTime (tag 0x18: YYYYMMDDHHMMSSZ); -1 when it is not understood
    static int der_time(char^ p, int n, int tag);
    static int unix_now();
    static char lower_c(char c);
    // does a name of the certificate (a dNSName, may start with *.) cover the host?
    static bool host_matches(char^ pat, int plen, String host);
    // is the host named in the subjectAltName extension of the certificate?
    static bool x509_names_host(char^ c, int^ o, String host);
    // the public key of a certificate: the kind (1 RSA, 2 P-256, 3 P-384, 0 not supported)
    static int x509_key_kind(char^ c, int^ o);
    // verifies `msg` (mlen bytes) signed with the key of the certificate cs (parsed in os): by the signature scheme of TLS (0x0804 ...) or by an X.509 algorithm (scheme 1 sha256WithRSA, 2 sha384WithRSA, 3 sha512WithRSA, 4 ecdsa-sha256, 5 ecdsa-sha384, 6 ecdsa-sha512)
    static bool x509_check_sig(char^ cs, int^ os, int scheme, char^ msg, int mlen, char^ sig, int slen);
    // the scheme number (see x509_check_sig) of the signature algorithm of a certificate; 0 when it is not supported
    static int x509_sig_scheme(char^ c, int^ o);
    // is the certificate c (parsed in o) valid at the time `now`?
    static bool x509_valid_at(char^ c, int^ o, int now);
    // is the certificate `c` signed by the certificate `i`? (the issuer name, the signature, and that i may sign certificates)
    static bool x509_signed_by(char^ c, int^ o, char^ i, int^ oi, int now);
    // ---------------------------------------------------------------- base 64 and the files of trusted certificates
    static int b64_value(int c);
    // the bytes of a base 64 text (spaces and line ends are skipped); out must have room for n * 3 / 4 bytes
    static int b64_decode(char^ in, int n, char^ out);
    // a whole file as text, "" when it cannot be read
    static String read_text(String path);
    static int find_from(String s, String x, int from);
    // the certificates of a PEM text one after the other (DER, each prefixed by its size as 4 bytes, big-endian) in out; the number of bytes written
    static int pem_to_der_list(String text, char^ out, int cap);
    // ---------------------------------------------------------------- the trust store and the check of a chain
    static String env_value(String name);
    // the names of the files of a folder, one per line ("" when it is not a folder)
    static String list_dir(String path);
    // the texts (PEM) in which the trusted certificates are: the files of J2K_CA (a file or a folder) or, when it is not set, the usual places
    static String[] ca_files();
    // is the certificate `last` (parsed in ol) trusted: is it in the store, or signed by a certificate of the store?
    static bool trusted_by_store(char^ last, int lastlen, int^ ol, int now);
    // the check of a chain: `chain` is the certificates one after the other, each as 4 bytes of size (big-endian) and the DER bytes, the server's certificate first.
    // Gives "" when the chain is good, else the reason. The host must be named in the first certificate; now: seconds since 1970 (0: the clock of this computer).
    static String x509_check_chain(char^ chain, int chainlen, String host, int now);
    // bytes as lower case hex
    static String hex(char^ p, int n);
}
```

## net

```jk
// Net: TCP sockets (IPv4, addresses written as numbers: "127.0.0.1"; there is no name lookup).
//   server:  int l = Net::tcp_listen(8080)?;   int c = Net::accept(l)?;   String req = Net::recv(c, 4096)?;   Net::send(c, "hi")?;
//   client:  int s = Net::tcp_connect("127.0.0.1", 8080)?;   Net::send(s, "hello")?;   Net::close(s);
// the state of the progress line (the speed of the last moments)
int net_pg_t;
int net_pg_b;
int net_pg_sp;

struct Net {
    static Error fail(String what, int e);
    // the four numbers of "a.b.c.d" in a[0..3]; false when it is not an address
    static bool parse_ip(String s, int^ a);
    // sockaddr_in in 16 bytes: family 2, the port and the address in network order
    static void make_addr(char^ sa, int a0, int a1, int a2, int a3, int port);
    // a socket that listens on the port (0: the system picks one; Net::port_of tells which) on every address of this computer
    static Result<int, Error> tcp_listen(int port);
    // the port that the socket is bound to
    static int port_of(int fd);
    static Result<int, Error> accept(int fd);
    static Result<int, Error> tcp_connect(String ip, int port);
    // two sockets that are joined to each other (a connection inside the program)
    static Result<int, Error> pair(int^ out);
    // all of the text is sent (the number of bytes)
    static Result<int, Error> send(int fd, String data);
    // what arrived (at most max bytes; "" when the other side closed)
    static Result<String, Error> recv(int fd, int max);
    static void close(int fd);
    // ---- names and pages: Net::dns.lookup("example.com"), Net::http.get("http://...") (designed by the assistant for jget, 2026-10-17, adjustable)
    // dns: A records over UDP port 53, no cache. A name that is already an address stays; localhost, the hosts files, then the name server.
    // http: GET over plain TCP (no https yet: TLS is not written), redirects followed, chunked answers decoded.
    static bool dns_is_ip(String s);
    // the first address after the word `nameserver` in a resolv.conf text
    static String dns_nameserver_in(String text);
    // the value of an environment variable, or "" (the net unit does not need the system unit)
    static String dns_env(String name);
    // a whole small file as a text, or "" when it cannot be read (the net unit does not need the files unit)
    static String dns_read(String path);
    // the name server to ask: J2K_DNS, then the resolv.conf files, else 1.1.1.1
    static String dns_server();
    // the address that a hosts file (a text with lines "address name name ...") gives to the name, or ""
    static String dns_hosts_in(String text, String name);
    // the question: the header and one question for the A record of the name
    static String dns_build_query(String name, int id);
    // the position after the name that starts at p (a name ends with 0, or with a pointer of two bytes)
    static int dns_skip_name(String r, int p);
    // the first A record of an answer, as "a.b.c.d", or "" when there is none
    static String dns_parse_answer(String r);
    // ask the name server (UDP), up to three times, waiting 3 seconds each time
    static Result<String, Error> dns_ask(String server, String name);
    static Result<String, Error> dns_try_lookup(String name);
    // the same, thrown as a text when it fails
    static String dns_lookup(String name);
    static String http_lower_ascii(String s);
    static int http_find_from(String s, String x, int from);
    static int http_hex_value(char c);
    // the body of a chunked answer ("size in hex CRLF data CRLF ... 0 CRLF CRLF"); false in ok[0] when it is damaged
    static String http_unchunk(String body, int^ ok);
    // one connection, plain (secure 0: h is the socket) or TLS (secure 1: h is the handle of Crypto::tls_connect)
    static Result<int, Error> http_open(String host, int port, int secure);
    static Result<int, Error> http_chan_send(int secure, int h, String data);
    static Result<String, Error> http_chan_recv(int secure, int h, int max);
    static void http_chan_close(int secure, int h);
    static Result<String, Error> http_read_all(int secure, int h);
    static Result<String, Error> http_fetch(String url, int depth);
    // the parts of an http:// address: [host, host:port, path, port]; one text (the reason) when it cannot be used
    static String[] http_split(String url);
    // 1.2 MB, 340.5 KB, 17 B
    static String http_size_text(int n);
    // 3:07 or 1:02:03
    static String http_time_text(int sec);
    // the progress line on the error output (replaces the line before it):
    //   [#########>               ]  45%  1.2 MB / 2.7 MB  340.5 KB/s  ETA 0:04
    //   [###########]  100%  2.7 MB in 0:03  (840.1 KB/s)                       (last = 1)
    //   [      <###>      ]  257.2 KB  666.4 KB/s  0:01                          (the size is not known)
    // The speed is the speed of the last second or so (not the average of everything), the bar fits the width of the terminal.
    static void http_show_progress(int done, int total, int ms, int last);
    static int http_now_ms();
    static void http_write_all(int fd, String s);
    // fetch the page into the file `path` as it arrives (written to path.part first, then renamed); show: 1 = a progress bar on the error
    // output when it is a terminal, 0 = never. Redirects and chunked answers are followed. Gives the number of bytes.
    static Result<int, Error> http_download_to(String url, String path, int show, int depth);
    static Result<int, Error> http_try_download(String url, String path, int show);
    // the same, thrown as a text when it fails
    static int http_download(String url, String path, int show);
    static Result<String, Error> http_try_get(String url);
    // the same, thrown as a text when it fails
    static String http_get(String url);
}

// Tcp: the short way (module name `tcp`, written  tcp.listen(8080)  or  Tcp::listen(8080)).
// Designed by the assistant at the owner's request (2026-10-16), adjustable. An error is thrown as a text (catch it with try/catch;
// an uncaught one stops the program with the text). The functions that return a Result instead are try_listen, try_accept, ...
//   int l = tcp.listen(8080);   int c = tcp.accept(l);   String req = tcp.recv(c);   tcp.send(c, "hello");   tcp.close(c);
//   int s = tcp.connect("127.0.0.1", 8080);
struct Tcp {
    // throw the message of the error (copied to a buffer that stays alive while the stack is unwound)
    static void fail(char^ msg);
    static int take(Result<int, Error> r);
    static int listen(int port);
    static int accept(int l);
    static int connect(String ip, int port);
    static int send(int c, String data);
    static String recv_max(int c, int max);
    static String recv(int c);
    static int port_of(int l);
    static void close(int c);
    static Result<int, Error> try_listen(int port);
    static Result<int, Error> try_accept(int l);
    static Result<int, Error> try_connect(String ip, int port);
    static Result<int, Error> try_send(int c, String data);
    static Result<String, Error> try_recv(int c);
}

// Listener and Connection: the formal names of the two sides of a TCP line (docs/syntax-design.md 79.1). Nothing closes by itself:
// the owner calls close() (it gives 0, or the number of the system error) or frees the line another way. A failure is thrown as a text.
//   Listener l = Listener::on(8080);   Connection c = l.accept();   String request = c.receive();   c.send("hello");   c.close();   l.close();
//   Connection s = Connection::to("127.0.0.1", 8080);
// Designed by the assistant (the names Listener::on and Connection::to), adjustable.
struct Connection {
    int fd;
    static Connection to(String ip, int port);
    String receive(self);
    String receive_max(self, int max);
    int send(self, String data);
    int close(self);
}
struct Listener {
    int fd;
    static Listener on(int port);
    int port(self);
    Connection accept(self);
    int close(self);
}
```

## math

```jk
```

## cpu

```jk
// cpu: threads and locks.   import cpu    using cpu::thread    using cpu::mutex
//
//   void work(void^ arg) { ... }
//   Thread t = create(work, @data);   t.join();      or  t.detach();
//   Mutex m;   m.lock();  ...  m.unlock();
//
// A Thread value is a handle: copies of it refer to the same thread. The thread runs on its own
// 1 MB stack (taken from the system); join() gives the stack back. A detached thread cannot free its
// own stack, so that memory stays until the program ends.

struct Mutex {
    int state;
                         // 0 free, 1 taken, 2 taken and somebody waits

    void init(self);
    void lock(self);
    void unlock(self);
    // true if the lock was free and is now yours
    bool try_lock(self);
}

struct Thread {
    int^ cb;
                           // [0] thread id (the kernel makes it 0 when the thread ends), [1] stack, [2] size, [3] detached

    // start function(arg) in a new thread
    static Thread create(void(void^)^ f, void^ arg);
    // wait until the thread has ended
    void join(self);
    // let the thread run on its own; it cannot be joined any more
    void detach(self);
    bool is_running(self);
    // pause the calling thread for ms milliseconds
    static void sleep(int ms);
    static void yield();
    static int id();
}
```

## simd

```jk
// simd: vectors of 2 or 4 numbers that live in one 128-bit register.   #import <simd>
//
//   f64x2 v = {1.0, 2.0};       v.x  v.y                      two doubles
//   i64x2 n = {1, 2};           n.x  n.y                      two 64-bit whole numbers
//   f32x4 f = {1.0, 2.0, 3.0, 4.0};   f.x f.y f.z f.w         four floats
//   i32x4 m = {1, 2, 3, 4};     m.x m.y m.z m.w               four 32-bit whole numbers
//   i8x16 b = i8x16::load(p, 0);   b.dot(c)                    sixteen bytes; the dot product into four i32 lanes (SDOT)
//
// The lanes are named x y z w as in vec3. Steps S1-S3 of docs/syntax-design.md 59: the types, the operators, the loads and
// stores of arrays (f64x2::load(a, i), v.store(a, i)).

struct f64x2 {
    double x;
    double y;

    // f64x2::load(a, i) is the pair a[i], a[i + 1] in one 16-byte load; v.store(a, i) writes it back (the compiler makes the
    // instruction; these bodies say what it means)
    static f64x2 load(double^ p, int i);
    void store(self, double^ p, int i);
    // the lanes together: sum() is x + y, min() and max() the smaller and the larger lane
    double sum(self);
    double min(self);
    double max(self);
}

struct i64x2 {
    int x;
    int y;

    static i64x2 load(int^ p, int i);
    void store(self, int^ p, int i);
    int sum(self);
    int min(self);
    int max(self);
}

struct f32x4 {
    float x;
    float y;
    float z;
    float w;

    static f32x4 load(float^ p, int i);
    void store(self, float^ p, int i);
    // sum() is (x + y) + (z + w)
    float sum(self);
    float min(self);
    float max(self);
}

struct i32x4 {
    i32 x;
    i32 y;
    i32 z;
    i32 w;

    static i32x4 load(i32^ p, int i);
    void store(self, i32^ p, int i);
    // sum() is (x + y) + (z + w)
    i32 sum(self);
    i32 min(self);
    i32 max(self);
}

// sixteen bytes in one register (i8x16): the loads and stores are one 16-byte instruction; + and - work lane by lane (wrapping); a.dot(b) is the int8
// dot product of the Cortex-A76 (SDOT): every 32-bit lane of the result is the sum of four products of bytes, the four lanes 0-3, 4-7, 8-11, 12-15.
// It is what a quantised matrix product needs: 16 multiply-adds in one instruction. Index of load/store counts bytes (the array is an i8 or char array).
struct i8x16 {
    i8 l0;
 i8 l1;
 i8 l2;
 i8 l3;
 i8 l4;
 i8 l5;
 i8 l6;
 i8 l7;
    i8 l8;
 i8 l9;
 i8 l10;
 i8 l11;
 i8 l12;
 i8 l13;
 i8 l14;
 i8 l15;

    static i8x16 load(i8^ p, int i);
    void store(self, i8^ p, int i);
    // the meaning of dot (the compiler makes SDOT of it on aarch64)
    i32x4 dot(self, i8x16 o);
}
```

## gfx

```jk
```
