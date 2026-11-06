// jc_base.jk -- part 1 of the J2K compiler written in J2K (roadmap Phase 2b).
//
// The compiler is split into four files, joined with import:
//   jc_base.jk  buffers, text/number helpers, the output writer, errors, files
//   jc_lex.jk   the tokenizer (comments, numbers, strings, imports)
//   jc_expr.jk  symbols, types, expressions and their code
//   jc_stmt.jk  statements, functions, globals, the start stub, main()
//
// It is written in a SMALL SUBSET of J2K -- ints, chars, bool, arrays,
// pointers, functions, if/while, string literals, syscall -- so that it can
// compile itself. It emits the same .jasm text that j2k_asm understands.
//
// Conventions of the generated code (kept simple on purpose):
//   * every value is a 64-bit integer; an expression's result is in x0
//   * temporaries are pushed on the stack (sub sp / str / ldr / add sp)
//   * every local variable lives in the stack frame at [x29 + offset]
//   * global variables live at x28 + offset (x28 = 0x10000000, set at start)

// --------------------------------------------------------------- the output

char out_buf[16777216];       // the .jasm text being produced
i64 out_len;

void emit_ch(i64 c) {
    if out_len >= 16777200 { die("output too large"); }
    out_buf[out_len] = c;
    out_len += 1;
}

void emit_str(char^ s) {
    i64 i = 0;
    while s[i] != 0 {
        emit_ch(s[i]);
        i += 1;
    }
}

void emit_nl() {
    emit_ch(10);
}

// a signed decimal number
void emit_int(i64 v) {
    if v < 0 {
        emit_ch('-');
        v = 0 - v;
    }
    if v == 0 {
        emit_ch('0');
        return;
    }
    char digits[24];
    i64 n = 0;
    while v > 0 {
        digits[n] = '0' + v % 10;
        v = v / 10;
        n += 1;
    }
    while n > 0 {
        n -= 1;
        emit_ch(digits[n]);
    }
}

// "L<n>"  (labels are numbered)
void emit_lab(i64 n) {
    emit_ch('L');
    emit_int(n);
}

// one whole line "text\n"
void emit_line(char^ s) {
    emit_str(s);
    emit_nl();
}

// "op xA, xB\n"-style helpers keep the code generator short
void emit_op1(char^ op, i64 imm) {         // "op x0, imm"
    emit_str(op);
    emit_ch(' ');
    emit_int(imm);
    emit_nl();
}

// ------------------------------------------------------------- text helpers

i64 str_len(char^ s) {
    i64 n = 0;
    while s[n] != 0 { n += 1; }
    return n;
}

bool str_eq(char^ a, char^ b) {
    i64 i = 0;
    while a[i] != 0 && b[i] != 0 {
        if a[i] != b[i] { return false; }
        i += 1;
    }
    return a[i] == b[i];
}

// copy at most cap-1 characters of src into dst and end it with 0
void str_copy(char^ dst, char^ src, i64 cap) {
    i64 i = 0;
    while src[i] != 0 && i < cap - 1 {
        dst[i] = src[i];
        i += 1;
    }
    dst[i] = 0;
}

bool is_digit(i64 c) {
    return c >= '0' && c <= '9';
}

bool is_letter(i64 c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

bool is_alnum(i64 c) {
    return is_letter(c) || is_digit(c);
}

bool is_space(i64 c) {
    return c == 32 || c == 9 || c == 10 || c == 13;
}

// value of a hex digit, or -1
i64 hex_value(i64 c) {
    if c >= '0' && c <= '9' { return c - '0'; }
    if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
    if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
    return -1;
}

// ------------------------------------------------------------------- errors

// where the lexer is (set by jc_lex.jk); used in messages
char err_file[128];
i64 err_line;
i64 err_col;

void write_out(char^ s) {
    syscall(64, 1, s, str_len(s));
}

void write_err(char^ s) {
    syscall(64, 2, s, str_len(s));
}

// colours for messages (ANSI): used when standard error is a terminal (or with -color)
i64 use_color;               // 1 = messages are coloured
i64 msg_kind;                // 1 = the message being written is an error, 2 = a warning

// an escape sequence such as "[1;31m" (only if colours are on)
void set_color(char^ code) {
    if use_color != 1 { return; }
    char e[2];
    e[0] = 27;
    e[1] = 0;
    write_err(@e);
    write_err(code);
}

void color_reset() {
    set_color("[0m");
}

// the colour of the word `error` (red) or `warning` (yellow, the terminal's own bold yellow)
void kind_color() {
    if msg_kind == 1 { set_color("[1;31m"); } else { set_color("[1;38;5;226m"); }
}

void write_err_int(i64 v) {
    char buf[24];
    i64 n = 0;
    if v == 0 {
        buf[0] = '0';
        n = 1;
    }
    char rev[24];
    i64 k = 0;
    while v > 0 {
        rev[k] = '0' + v % 10;
        v = v / 10;
        k += 1;
    }
    while k > 0 {
        k -= 1;
        buf[n] = rev[k];
        n += 1;
    }
    buf[n] = 0;
    write_err(@buf);
}

// command-line options (set by main in jc_stmt.jk)
i64 opt_debug;               // -d : a debug build
i64 opt_strict;              // -st : warnings are errors
i64 opt_novec = 0;           // -novec: no loop is made into NEON vector code (for a machine that has no NEON, such as the emulator of Jaric OS)
i64 opt_fma = 1;             // 1: fmul + fadd / fsub of one value become fmadd / fmsub / fnmsub (-nofma switches it off)
i64 opt_regs = 1;            // 1: the register pass keeps the busiest whole-number locals of loops in x19..x25 (-noregs switches it off)
i64 opt_loopalign = 1;       // 1: the head of a loop starts at a multiple of 16 bytes (".align 16"); -noloopalign: off
i64 opt_rotmax = -1;         // -rotmax N: only the first N loops of a function are rotated (to find the loop that a measurement does not like)
i64 opt_rotate = 1;          // 1: a jump back to a small test block is written as a copy of the test (loop rotation at the end); -norotate: off
i64 opt_hoist = 1;           // 1: a null check and a load of an array header that do not change in a loop move before the loop (pt_hoist); -nohoist: off
i64 opt_icopy = 1;           // 1: a copy `mov xT, xV` is looked through several lines and its readers use xV (pt_fwd_icopy); -noicopy: off
i64 opt_pushfast = 1;         // 1: x.push(v) puts the common case in line (room in the array); -nopushfast: always the call
i64 opt_nullchk = 1;          // 1: a check of an array variable for null is dropped when every way in has passed the same check (-nonullchk switches it off)
i64 x_time;                  // hidden flag -xtime: the time of each stage of the compiler is written to the error output
i64 tm_ts[2];
i64 tm_last;
i64 tm_now() {
    syscall(113, 1, @tm_ts);
    return tm_ts[0] * 1000000 + tm_ts[1] / 1000;
}
i64 x_badasm;                // hidden flag -xbadasm: puts a line into the text that the assembler cannot read
i64 par_jobs;                // -j N : the number of processes that work on the functions in the passes ir and regs (0: by the cores, 1: one)
i64 par_n;                   // in a child process: how many children there are (0: not a child)
i64 par_k;                   // ... and which one this is
i64 par_fidx;                // the number of the function the pass is at
i64 par_open;                // the function whose end in the output is not recorded yet (-1: none)
i64 par_fs[65536];           // where the output of each function starts / ends in the new text
i64 par_fe[65536];
i64 opt_rot = 1;             // 1: loops get their test at the bottom (-norot switches it off)
i64 opt_peep = 1;            // 1: the peephole pass makes the code shorter (-nopeep switches it off, to look for a fault)
char inc_dir[256];           // -I dir : where `import "name"` looks if the file is not next to the importer
i64 warn_count;
i64 used_fprint;             // 1 if coutf was used: the float printing routine is emitted
i64 used_uprint;             // 1 if an unsigned 64-bit number is printed: the routine is emitted
i64 used_fntab;               // 1 if __fntab() is used: the table of function names is emitted
i64 ft_count;                // functions in the table (pass 3)
char ft_names[262144];       // their names, 64 bytes each
i64 used_thread;             // 1 if a thread is started: the start routine is emitted
i64 used_noret;              // 1 if a function can end without a return: the 'missing return' routine is added
i64 used_divz;               // 1 if a division was emitted: the 'division by zero' routine is added
i64 used_oob;                // 1 if a bounds check was emitted: the error routine is added
i64 pass_no;                 // 1 = learn declarations, 2 = check and note calls, 3 = generate code
i64 bare_mode;               // 1: the file starts with #!library: nothing is added, the file is the program (the first instruction is the entry)

// ------------------------------------------------------------------- files

// read a whole file into dst (at most cap-1 bytes) and end it with 0;
// returns the length, or -1 if it cannot be opened/read
i64 file_errno;              // why the last read_file failed: the number of the system error (2 no such file, 13 no right, 21 a folder ...)
i64 read_file(char^ path, char^ dst, i64 cap) {
    file_errno = 0;
    i64 fd = syscall(56, -100, path, 0, 0);
    if fd < 0 { file_errno = 0 - fd; return -1; }
    i64 n = syscall(63, fd, dst, cap - 1);
    syscall(57, fd);
    if n < 0 { file_errno = 0 - n; return -1; }
    dst[n] = 0;
    return n;
}

// write buf[0..len) to a new file (mode 0755); returns 0 or -1
i64 write_file(char^ path, char^ buf, i64 len) {
    i64 fd = syscall(56, -100, path, 577, 493);
    if fd < 0 { return -1; }
    i64 n = syscall(64, fd, buf, len);
    syscall(57, fd);
    if n != len { return -1; }
    return 0;
}

char^ cc_dir;                  // the folder of the cache of the back end (-cache), or null (jc_cache.j)
i64 x_cachelist;                // -xcachelist
i64 x_cutmax = 1000000;          // -xcachecut N: only the first N functions that come from the cache are cut (to find what the back end remembers)
i64 x_cutmin;                   // -xcachecut MIN MAX: the first hit that is cut
i64 x_repeat;                   // -xrepeat
i64 x_lex;                      // -xlex
i64 req_cpu;                     // #require cpu "name": bit 0 = crc32 (the functions of that extension need it)
i64 expect_pending;              // #expect instructions <= N: the limit for the next function (0: none)
i64 expect_line;                 // the line of that directive
char expect_file[128];           // and its file
i64 fexp_n[16384];               // the limit of each function (0: none)
i64 fexp_line[16384];
char fexp_file[2097152];         // 128 characters each
i64 allow_syscall;               // #allow syscall: no warning about syscall(number, ...)
i64 x_allreach;                  // -xall

i64 lam_seq;                     // the number of the next lambda (__lambda_<n>); the tree reads it to name the lambdas of a body
i64 x_target;                    // 32: -target arm32 (the ARM32 back end, jc_a32.j)
i64 x_dyn;                       // 1: -dyn, a program that is a dynamic executable (it loads libc.so and libdl.so and can call the libraries of the system)
i64 x_lib;                       // 1: -l, the program is a shared library (.so) with the functions marked `export`
char^ x_show;                    // -show NAME: the assembler text of the function NAME, as it is in the program, and the number of its instructions
char^ x_map;                     // -xmap FILE: the addresses of the functions (and the labels) of the program
