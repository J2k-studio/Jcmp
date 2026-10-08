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

char out_buf[8388608];       // the .jasm text being produced
int out_len;

void emit_ch(int c) {
    if out_len >= 8388600 { die("output too large"); }
    out_buf[out_len] = c;
    out_len += 1;
}

void emit_str(char^ s) {
    int i = 0;
    while s[i] != 0 {
        emit_ch(s[i]);
        i += 1;
    }
}

void emit_nl() {
    emit_ch(10);
}

// a signed decimal number
void emit_int(int v) {
    if v < 0 {
        emit_ch('-');
        v = 0 - v;
    }
    if v == 0 {
        emit_ch('0');
        return;
    }
    char digits[24];
    int n = 0;
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
void emit_lab(int n) {
    emit_ch('L');
    emit_int(n);
}

// one whole line "text\n"
void emit_line(char^ s) {
    emit_str(s);
    emit_nl();
}

// "op xA, xB\n"-style helpers keep the code generator short
void emit_op1(char^ op, int imm) {         // "op x0, imm"
    emit_str(op);
    emit_ch(' ');
    emit_int(imm);
    emit_nl();
}

// ------------------------------------------------------------- text helpers

int str_len(char^ s) {
    int n = 0;
    while s[n] != 0 { n += 1; }
    return n;
}

bool str_eq(char^ a, char^ b) {
    int i = 0;
    while a[i] != 0 && b[i] != 0 {
        if a[i] != b[i] { return false; }
        i += 1;
    }
    return a[i] == b[i];
}

// copy at most cap-1 characters of src into dst and end it with 0
void str_copy(char^ dst, char^ src, int cap) {
    int i = 0;
    while src[i] != 0 && i < cap - 1 {
        dst[i] = src[i];
        i += 1;
    }
    dst[i] = 0;
}

bool is_digit(int c) {
    return c >= '0' && c <= '9';
}

bool is_letter(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

bool is_alnum(int c) {
    return is_letter(c) || is_digit(c);
}

bool is_space(int c) {
    return c == 32 || c == 9 || c == 10 || c == 13;
}

// value of a hex digit, or -1
int hex_value(int c) {
    if c >= '0' && c <= '9' { return c - '0'; }
    if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
    if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
    return -1;
}

// ------------------------------------------------------------------- errors

// where the lexer is (set by jc_lex.jk); used in messages
char err_file[128];
int err_line;
int err_col;

void write_out(char^ s) {
    syscall(64, 1, s, str_len(s));
}

void write_err(char^ s) {
    syscall(64, 2, s, str_len(s));
}

// colours for messages (ANSI): used when standard error is a terminal (or with -color)
int use_color;               // 1 = messages are coloured
int msg_kind;                // 1 = the message being written is an error, 2 = a warning

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

// the colour of the word `error` (red) or `warning` (orange)
void kind_color() {
    if msg_kind == 1 { set_color("[1;31m"); } else { set_color("[1;38;5;208m"); }
}

void write_err_int(int v) {
    char buf[24];
    int n = 0;
    if v == 0 {
        buf[0] = '0';
        n = 1;
    }
    char rev[24];
    int k = 0;
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
int opt_debug;               // -d : a debug build
int opt_strict;              // -st : warnings are errors
char inc_dir[256];           // -I dir : where `import "name"` looks if the file is not next to the importer
int warn_count;
int used_fprint;             // 1 if coutf was used: the float printing routine is emitted
int used_uprint;             // 1 if an unsigned 64-bit number is printed: the routine is emitted
int used_thread;             // 1 if a thread is started: the start routine is emitted
int used_divz;               // 1 if a division was emitted: the 'division by zero' routine is added
int used_oob;                // 1 if a bounds check was emitted: the error routine is added
int pass_no;                 // 1 = learn declarations, 2 = check and note calls, 3 = generate code

// ------------------------------------------------------------------- files

// read a whole file into dst (at most cap-1 bytes) and end it with 0;
// returns the length, or -1 if it cannot be opened/read
int read_file(char^ path, char^ dst, int cap) {
    int fd = syscall(56, -100, path, 0, 0);
    if fd < 0 { return -1; }
    int n = syscall(63, fd, dst, cap - 1);
    syscall(57, fd);
    if n < 0 { return -1; }
    dst[n] = 0;
    return n;
}

// write buf[0..len) to a new file (mode 0755); returns 0 or -1
int write_file(char^ path, char^ buf, int len) {
    int fd = syscall(56, -100, path, 577, 493);
    if fd < 0 { return -1; }
    int n = syscall(64, fd, buf, len);
    syscall(57, fd);
    if n != len { return -1; }
    return 0;
}
