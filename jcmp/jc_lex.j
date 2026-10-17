// jc_lex.jk -- part 2 of the J2K compiler written in J2K: the tokenizer.
//
// next() reads the next token into tok_kind / tok_text / tok_num / tok_str.
// Words (identifiers and keywords alike) are T_IDENT; the parser compares
// the text (tok_is("while")). Operators are T_OP with their text. A character
// literal is a T_NUM. "import" is handled here too: lex_import() switches to
// the named file and goes back to the importing file when it ends.

// ----------------------------------------------------- token kinds (as data)
int T_EOF = 0;
int T_IDENT = 1;
int T_NUM = 2;
int T_STR = 3;
int T_OP = 4;

// ------------------------------------------------------------ source buffers
// 16 nested files, each in its own 512 KB slice of src_bufs
char src_bufs[8388608];
int cur_base;                // start of the current file's slice
int cur_len;
int cur_pos;
int cur_line;
int cur_line_start;
int lx_depth;                // 0 = the main file
int stk_pos[16];             // saved positions of the files below the current one
int stk_line[16];
int stk_ls[16];
int stk_len[16];            // the length of the file below (so that returning to it does not need a scan of its whole text)
char lvl_name[2048];         // path of the file at each level (16 x 128)
char inc_names[65536];        // paths already imported (64 x 128)
int inc_count;
int lvl_inst[16];            // 1 = the level is the text of a generic instance: its end is an end of items, not a return to the file below
int mt_pending;              // 1 after #multithread until the for loop it belongs to is parsed
int cpu_loaded;              // 1 once `import cpu` has been read
int simd_loaded;             // 1 once `import <simd>` has been read
int lvl_lib[16];             // 1 for a level that is a built-in library (its warnings are not shown)
int vector_loaded;           // 1 once `import <vector>` has been read
int matrix_loaded;
int quat_loaded;
int cplx_loaded;
int stats_loaded;
int gfx_loaded;              // 1 once `#import <gfx>` has been read
int canvas_loaded;
int screen_loaded;
int math_loaded;             // 1 once `#import <math>` has been read (using math::vector loads the parts)           // 1 once `import <matrix>` has been read
int std_loaded;              // 1 once `import std` has been read
int std_units;               // the units of the standard library that are read (bit n = unit n, see gen_std.sh): 511 = all

// ---------------------------------------------------------------- #define
char def_name[131072];         // 256 names x 64
char def_val[524288];         // 256 values x 256
int def_count;
int reserve_mask;            // #reserve x18, x19 ...: bit n = register xn is never used by the compiler (x18, x19 .. x25)

// a #define whose text is an arithmetic expression of several tokens (`2+3`, `N * 4 - 1`) is kept in parentheses, so that `N * 2` is
// `(2+3) * 2`, as everybody reads it (owner, 2026-10-15). Texts that are not an expression (a type, an argument list, a statement, a
// string, an assignment) stay as written.
bool define_is_expr(char^ s, int n) {
    if n < 3 { return false; }
    bool has_op = false;
    int depth = 0;
    int i = 0;
    while i < n {
        int c = s[i];
        if c == ',' || c == ';' || c == '{' || c == '}' || c == '"' || c == 39 || c == '=' || c == '[' || c == ']' || c == '#' || c == '@' || c == '^' || c == ':' || c == '?' { return false; }
        if c == '(' { depth += 1; }
        if c == ')' { depth -= 1; if depth < 0 { return false; } }
        if (c == '+' && i + 1 < n && s[i + 1] == '+') || (c == '-' && i + 1 < n && s[i + 1] == '-') { return false; }
        if c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == '<' || c == '>' || c == '&' || c == '|' { has_op = true; }
        i += 1;
    }
    if depth != 0 || !has_op { return false; }
    // the first word must not be a keyword of a statement
    char w[16];
    int k = 0;
    int j = 0;
    while j < n && (s[j] == ' ' || s[j] == 9) { j += 1; }
    while j < n && k < 15 && ((s[j] >= 'a' && s[j] <= 'z') || (s[j] >= 'A' && s[j] <= 'Z') || s[j] == '_') {
        w[k] = s[j];
        k += 1;
        j += 1;
    }
    w[k] = 0;
    if str_eq(@w, "return") || str_eq(@w, "if") || str_eq(@w, "else") || str_eq(@w, "while") || str_eq(@w, "for") || str_eq(@w, "loop") || str_eq(@w, "switch") || str_eq(@w, "case") || str_eq(@w, "break") || str_eq(@w, "continue") || str_eq(@w, "goto") || str_eq(@w, "defer") || str_eq(@w, "throw") || str_eq(@w, "try") || str_eq(@w, "catch") || str_eq(@w, "cout") || str_eq(@w, "cin") { return false; }
    return true;
}

int find_define(char^ name) {
    int i = 0;
    while i < def_count {
        if str_eq(@def_name + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}

// ------------------------------------------------------------- the token
int tok_kind;
char tok_text[256];          // identifier / operator text
int tok_num;                 // number or character value
int tok_float;               // 1 if the number is a float literal: value = tok_mant * 10^tok_exp
int tok_mant;
int tok_exp;
int tok_char;                // 1 if the number was written as a character literal
char tok_str[1024];          // string literal, decoded
int tok_str_len;

// -------------------------------------------------------------- characters

int lc(int off) {
    int p = cur_pos + off;
    if p < cur_len { return src_bufs[cur_base + p]; }
    return 0;
}

void adv() {
    if cur_pos < cur_len {
        if src_bufs[cur_base + cur_pos] == 10 {
            cur_line += 1;
            cur_line_start = cur_pos + 1;
        }
        cur_pos += 1;
    }
}

int err_base;                // where the source of the error position is
int err_ls;

void mark_pos() {
    err_line = cur_line;
    err_col = cur_pos - cur_line_start + 1;
    err_base = cur_base;
    err_ls = cur_line_start;
}

// ------------------------------------------------- errors and warnings
// format:  file:line:col: error: message      (then the source line and a ^)

void begin_msg(char^ kind) {
    msg_kind = 1;
    if str_eq(kind, "warning") { msg_kind = 2; }
    set_color("[1m");
    if err_file[0] != 0 {
        write_err(@err_file);
        write_err(":");
        write_err_int(err_line);
        write_err(":");
        write_err_int(err_col);
    } else {
        write_err("jcmp");                  // no source file yet (the file named on the command line cannot be read)
    }
    write_err(": ");
    kind_color();
    write_err(kind);
    write_err(":");
    color_reset();
    set_color("[1m");
    write_err(" ");
}

// the end of a message: the source line and a ^ under the column
void end_msg() {
    color_reset();
    write_err("\n");
    int a = err_base + err_ls;
    int e = a;
    while src_bufs[e] != 0 && src_bufs[e] != 10 { e += 1; }
    if e > a {
        // "  12 | source line" and "     | ^" under the column
        char num[24];
        num[0] = 0;
        append_int(@num, err_line);
        int w = str_len(@num);
        set_color("[36m");
        write_err(" ");
        write_err(@num);
        write_err(" | ");
        color_reset();
        syscall(64, 2, @src_bufs + a, e - a);
        write_err("\n");
        set_color("[36m");
        write_err(" ");
        int g = 0;
        while g < w {
            write_err(" ");
            g += 1;
        }
        write_err(" | ");
        color_reset();
        int k = 0;
        while k < err_col - 1 && k < e - a {
            if src_bufs[a + k] == 9 { write_err("\t"); } else { write_err(" "); }
            k += 1;
        }
        kind_color();
        write_err("^");
        color_reset();
        write_err("\n");
    }
}

// errors that the compiler survived (a missing ';'): counted in pass 1, all of them are shown, then the compiler stops
int err_count;
void err_summary() {
    if err_count == 0 { return; }
    msg_kind = 1;
    kind_color();
    write_err_int(err_count);
    if err_count == 1 { write_err(" error generated."); } else { write_err(" errors generated."); }
    color_reset();
    write_err("\n");
}

// the end of every error message: with the recovery on (passes 1 and 2) the error is counted and thrown to the loop that reads
// statements and items, which skips to the next one and goes on (so that all the mistakes of a file are shown, at most 20);
// otherwise the summary is written and the compiler stops
int recover_on;
void die_end() {
    err_count += 1;
    if recover_on == 1 && err_count < 20 { throw "error already written"; }
    if err_count >= 20 { write_err("too many errors, the compiler stops here\n"); }
    err_summary();
    syscall(93, 1);
}

void die(char^ msg) {
    begin_msg("error");
    write_err(msg);
    end_msg();
    die_end();
}

// an error after which the parser can go on (the token that is missing is taken as written): shown once, in pass 1
void soft_error(char^ msg) {
    if pass_no != 1 { return; }
    if err_count >= 10 { die("too many errors, the compiler stops here"); }
    begin_msg("error");
    write_err(msg);
    end_msg();
    err_count += 1;
}

// an error that is written in every pass where it is met (pass 1 and 2), counted, and the reading goes on as if it were not there
void soft_error_here(char^ msg) {
    if pass_no != 1 { return; }
    begin_msg("error");
    write_err(msg);
    end_msg();
    err_count += 1;
}

void soft_error_help(char^ msg, char^ help) {
    if pass_no != 1 { return; }
    begin_msg("error");
    write_err(msg);
    end_msg();
    write_err("  help: ");
    write_err(help);
    write_err("\n");
    err_count += 1;
}

// an error with a second line  help: ...  under the source line
void die_help(char^ msg, char^ help) {
    begin_msg("error");
    write_err(msg);
    end_msg();
    write_err("  help: ");
    write_err(help);
    write_err("\n");
    die_end();
}

// what the parser sees now, for a message:  the end of the file / a text / 'token'
void write_found() {
    if tok_kind == T_EOF {
        write_err("the end of the file");
    } else if tok_kind == T_STR {
        write_err("a text");
    } else if tok_kind == T_NUM {
        write_err("the number ");
        write_err_int(tok_num);
    } else {
        write_err("'");
        write_err(@tok_text);
        write_err("'");
    }
}

// "<what> was expected, but found <token>" with a help line
void die_found(char^ what, char^ help) {
    begin_msg("error");
    write_err(what);
    write_err(" was expected, but found ");
    write_found();
    end_msg();
    write_err("  help: ");
    write_err(help);
    write_err("\n");
    die_end();
}

// the closest known name to `name` (at most 1 edit away, 2 for names of 5+ letters): in sug_buf, 1 if there is one
char sug_buf[64];
int sug_best;                // the distance of the best one so far
int sug_row[130];
int edit_distance(char^ a, char^ b) {
    int la = str_len(a);
    int lb = str_len(b);
    if la > 62 || lb > 62 { return 99; }
    int j = 0;
    while j <= lb {
        sug_row[j] = j;
        j += 1;
    }
    int i = 1;
    while i <= la {
        int prev = sug_row[0];
        sug_row[0] = i;
        j = 1;
        while j <= lb {
            int cur = sug_row[j];
            int cost = 1;
            if a[i - 1] == b[j - 1] { cost = 0; }
            int best = prev + cost;
            if sug_row[j] + 1 < best { best = sug_row[j] + 1; }
            if sug_row[j - 1] + 1 < best { best = sug_row[j - 1] + 1; }
            sug_row[j] = best;
            prev = cur;
            j += 1;
        }
        i += 1;
    }
    return sug_row[lb];
}

// offer one candidate (called for each known name)
void sug_try(char^ name, char^ cand) {
    if cand[0] == 0 || cand[0] == '_' { return; }
    int lim = 1;
    if str_len(name) >= 5 { lim = 2; }
    int d = edit_distance(name, cand);
    if d == 0 || d > lim { return; }
    if d < sug_best {
        sug_best = d;
        str_copy(@sug_buf, cand, 64);
    }
}

// die with a name in the message:  error: msg 'name'
int in_lambda;               // 1 while the function being compiled is a lambda
void die_name(char^ msg, char^ name) {
    begin_msg("error");
    bool as_type = false;
    if str_eq(msg, "unknown name") && cur_pos < cur_len {
        // `Name other` is a declaration: the word is a type that does not exist
        int sp = cur_pos;
        while sp < cur_len && (src_bufs[cur_base + sp] == ' ' || src_bufs[cur_base + sp] == 9) { sp += 1; }
        int c = src_bufs[cur_base + sp];
        if sp < cur_len && sp > cur_pos && ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_') { as_type = true; }
    }
    // the parser has read the next word already: `Foo f;` stops at `f`
    if str_eq(msg, "unknown name") && tok_kind == T_IDENT && !str_eq(@tok_text, name) && name[0] >= 'A' && name[0] <= 'Z' { as_type = true; }
    if as_type { write_err("unknown type"); } else { write_err(msg); }
    if in_lambda == 1 && str_eq(msg, "unknown name") { write_err(" (a lambda cannot use the variables around it)"); }
    write_err(" '");
    write_err(name);
    write_err("'");
    end_msg();
    sug_best = 99;
    sug_buf[0] = 0;
    if str_eq(msg, "unknown name") || str_eq(msg, "unknown function") { sug_names(name); }
    if msg[0] == 'l' && msg[1] == 'i' && msg[2] == 'b' {
        sug_try(name, "stdlib");
        sug_try(name, "gfx");
        sug_try(name, "math");
        sug_try(name, "cpu");
    }
    if sug_buf[0] != 0 {
        write_err("  help: did you mean '");
        write_err(@sug_buf);
        write_err("'?\n");
    } else if as_type {
        write_err("  help: declare it with struct or enum class, check the spelling, or add the #import that holds it\n");
    } else if str_eq(msg, "unknown function") && (str_eq(name, "alloc") || str_eq(name, "free") || str_eq(name, "arr")) {
        write_err("  help: this is part of the standard library: write #import <stdlib> at the top of the file\n");
    }
    if msg[0] == 'l' && msg[1] == 'i' && msg[2] == 'b' {
        write_err("  help: looked in the -I folders, J2K_PATH, ~/.j2k/Library and the Library folder next to the compiler (jget -li install NAME fetches a library from the index; jget is a separate tool); built in: stdlib, core, number, text, files, system, time, data, crypto, math, gfx, cpu, simd\n");
    }
    die_end();
}

// the program has no main function (a message about the whole file, so it has no line)
void die_no_main(char^ path) {
    msg_kind = 1;
    set_color("[1m");
    kind_color();
    write_err("error:");
    color_reset();
    write_err(" no main function found in '");
    write_err(path);
    write_err("'\n  help: every program needs `void main()` or `int main()`\n");
    syscall(93, 1);
}

// text += the decimal digits of v (v >= 0)
void append_int(char^ dst, int v) {
    char tmp[24];
    int n = 0;
    if v == 0 {
        tmp[0] = '0';
        n = 1;
    }
    while v > 0 {
        tmp[n] = '0' + v % 10;
        v = v / 10;
        n += 1;
    }
    int at = str_len(dst);
    while n > 0 {
        n -= 1;
        dst[at] = tmp[n];
        at += 1;
    }
    dst[at] = 0;
}

void append_text(char^ dst, char^ more) {
    int at = str_len(dst);
    int k = 0;
    while more[k] != 0 {
        dst[at] = more[k];
        at += 1;
        k += 1;
    }
    dst[at] = 0;
}

// a warning (with -st it is an error); `flag` names it, e.g. "switch"
void warn(char^ msg, char^ flag) {
    if pass_no != 3 { return; }          // each warning once
    if lvl_lib[lx_depth] == 1 { return; } // not in a built-in library: the user cannot change it
    if opt_strict == 1 {
        begin_msg("error");
        write_err(msg);
        write_err(" [-W");
        write_err(flag);
        write_err(", -st]");
        end_msg();
        syscall(93, 1);
    }
    begin_msg("warning");
    write_err(msg);
    write_err(" [-W");
    write_err(flag);
    write_err("]");
    end_msg();
    warn_count += 1;
}

void set_err_file(int level) {
    str_copy(@err_file, @lvl_name + level * 128, 128);
}

// blanks, // comments and /* comments */
void skip_blanks() {
    while cur_pos < cur_len {
        int c = lc(0);
        if is_space(c) {
            adv();
        } else if c == '/' && lc(1) == '/' {
            while cur_pos < cur_len && lc(0) != 10 { adv(); }
        } else if c == '/' && lc(1) == '*' {
            adv();
            adv();
            while cur_pos < cur_len && !(lc(0) == '*' && lc(1) == '/') { adv(); }
            adv();
            adv();
        } else {
            return;
        }
    }
}

// ---------------------------------------------------------- files / imports

int tok_seq;                 // counts the tokens read (a literal followed by ']' is one step)
int ro_block;                // 1 between #pragma read begin and end
int ro_next;                 // 1: the next global variable is read-only
int ro_file;                 // bit d: the file at depth d has #pragma read as its first line
int lvl_seq0[16];            // tok_seq when the file at this depth was entered

// the files of the folder of `path` that are named almost like it: the closest in sug_buf (with the folder in front)
void sug_files(char^ path) {
    char dir[256];
    char base[128];
    int n = str_len(path);
    int slash = 0 - 1;
    int i = 0;
    while i < n { if path[i] == '/' { slash = i; } i += 1; }
    if slash < 0 {
        dir[0] = '.';
        dir[1] = 0;
        str_copy(@base, path, 128);
    } else {
        str_copy(@dir, path, 256);
        dir[slash] = 0;
        if slash == 0 { dir[0] = '/'; dir[1] = 0; }
        str_copy(@base, path + slash + 1, 128);
    }
    int fd = syscall(56, -100, @dir, 0, 0);
    if fd < 0 { return; }
    char ents[4096];
    int guard = 0;
    while guard < 64 {
    guard += 1;
    int got = syscall(61, fd, @ents, 4096);
    if got <= 0 { break; }
    int off = 0;
    while off < got {
        int reclen = (ents[off + 16] & 255) | ((ents[off + 17] & 255) << 8);
        char^ nm = @ents[off + 19];
        if nm[0] != '.' {
            // the name with or without the ending .jk
            sug_try(@base, nm);
            int ln = str_len(nm);
            if ln > 3 && nm[ln - 3] == '.' && nm[ln - 2] == 'j' && nm[ln - 1] == 'k' {
                char stem[128];
                str_copy(@stem, nm, 128);
                stem[ln - 3] = 0;
                sug_try(@base, @stem);
            }
        }
        if reclen <= 0 { break; }
        off += reclen;
    }
    }
    syscall(57, fd);
    if sug_buf[0] != 0 && slash >= 0 {
        // the folder goes in front of the name
        char whole[256];
        str_copy(@whole, path, 256);
        whole[slash + 1] = 0;
        int wl = str_len(@whole);
        str_copy(@whole + wl, @sug_buf, 256 - wl);
        str_copy(@sug_buf, @whole, 64);
    }
}

// error: the file `path` cannot be read; says why, and offers a file of almost the same name
void die_file(char^ path) {
    begin_msg("error");
    write_err("cannot read file '");
    write_err(path);
    write_err("': ");
    int e = file_errno;
    if e == 2 { write_err("there is no file with this name"); }
    else if e == 13 { write_err("permission denied (no right to read it)"); }
    else if e == 21 { write_err("this is a folder, not a file"); }
    else if e == 20 { write_err("a part of the path is a file, not a folder"); }
    else if e == 36 { write_err("the name is too long"); }
    else if e == 40 { write_err("too many symbolic links"); }
    else { write_err("the system could not read it (error "); write_err_int(e); write_err(")"); }
    end_msg();
    sug_best = 99;
    sug_buf[0] = 0;
    if e == 2 || e == 20 { sug_files(path); }
    if sug_buf[0] != 0 {
        write_err("  help: did you mean '");
        write_err(@sug_buf);
        write_err("'?\n");
    } else if e == 2 {
        char cwd[256];
        int cl = syscall(17, @cwd, 256);
        write_err("  help: check the spelling; looked in the folder ");
        if cl > 0 { write_err("'"); write_err(@cwd); write_err("'"); } else { write_err("(this one)"); }
        write_err("\n");
    } else if e == 21 {
        write_err("  help: give the program file, for example main.jk\n");
    }
    die_end();
}

// make `path` the current file (a new level); the old one is saved
void push_file(char^ path) {
    if lx_depth >= 15 { die("imports nested too deeply"); }
    stk_pos[lx_depth] = cur_pos;
    stk_line[lx_depth] = cur_line;
    stk_ls[lx_depth] = cur_line_start;
    stk_len[lx_depth] = cur_len;
    lx_depth += 1;
    lvl_lib[lx_depth] = 0;
    lvl_seq0[lx_depth] = tok_seq;
    ro_file = ro_file & ~(1 << lx_depth);
    cur_base = lx_depth * 524288;
    str_copy(@lvl_name + lx_depth * 128, path, 128);
    int n = read_file(path, @src_bufs + cur_base, 524288);
    if n < 0 { die_file(path); }
    cur_len = n;
    cur_pos = 0;
    cur_line = 1;
    cur_line_start = 0;
    set_err_file(lx_depth);
}

// the text of a #define becomes a new "file" that ends where the text ends
void push_macro(char^ text) {
    if lx_depth >= 15 { die("#define nested too deeply"); }
    stk_pos[lx_depth] = cur_pos;
    stk_line[lx_depth] = cur_line;
    stk_ls[lx_depth] = cur_line_start;
    stk_len[lx_depth] = cur_len;
    str_copy(@lvl_name + (lx_depth + 1) * 128, @lvl_name + lx_depth * 128, 128);
    lx_depth += 1;
    lvl_lib[lx_depth] = lvl_lib[lx_depth - 1];
    cur_base = lx_depth * 524288;
    str_copy(@src_bufs + cur_base, text, 300);
    cur_len = str_len(text);
    cur_pos = 0;
    cur_line = stk_line[lx_depth - 1];
    cur_line_start = 0;
}

// the text of a generic instance becomes a new level; at its end next() gives T_EOF
// and the caller pops it (pop_file)
void push_text(char^ text, int n, char^ file, int line) {
    if lx_depth >= 15 { die("generic instances nested too deeply"); }
    stk_pos[lx_depth] = cur_pos;
    stk_line[lx_depth] = cur_line;
    stk_ls[lx_depth] = cur_line_start;
    stk_len[lx_depth] = cur_len;
    lx_depth += 1;
    lvl_lib[lx_depth] = 0;
    cur_base = lx_depth * 524288;
    str_copy(@lvl_name + lx_depth * 128, file, 128);
    int i = 0;
    while i < n {
        src_bufs[cur_base + i] = text[i];
        i += 1;
    }
    src_bufs[cur_base + n] = 0;
    cur_len = n;
    cur_pos = 0;
    cur_line = line;
    cur_line_start = 0;
    lvl_inst[lx_depth] = 1;
    set_err_file(lx_depth);
}

void pop_file() {
    lvl_inst[lx_depth] = 0;
    lx_depth -= 1;
    cur_base = lx_depth * 524288;
    cur_pos = stk_pos[lx_depth];
    cur_line = stk_line[lx_depth];
    cur_line_start = stk_ls[lx_depth];
    cur_len = stk_len[lx_depth];
    set_err_file(lx_depth);
}

void lex_init(char^ path) {
    def_count = 0;
    gen_reset();
    lx_depth = 0;
    lvl_inst[0] = 0;
    std_loaded = 0;
    std_units = 0;
    vector_loaded = 0;
    matrix_loaded = 0;
    quat_loaded = 0;
    cplx_loaded = 0;
    stats_loaded = 0;
    math_loaded = 0;
    gfx_loaded = 0;
    canvas_loaded = 0;
    screen_loaded = 0;
    mt_pending = 0;
    cpu_loaded = 0;
    simd_loaded = 0;
    lx_depth = 0;
    cur_base = 0;
    ro_block = 0;
    ro_next = 0;
    ro_file = 0;
    lvl_seq0[0] = 0;
    str_copy(@lvl_name, path, 128);
    int n = read_file(path, @src_bufs, 524288);
    if n < 0 { die_file(path); }
    cur_len = n;
    cur_pos = 0;
    cur_line = 1;
    cur_line_start = 0;
    inc_count = 0;
    set_err_file(0);
    push_prelude();                      // Mem and the dynamic array routines come first
}


// ---------------------------------------------------------------- import std
// append one line of text to the current level's buffer
// ---------------------------------------------------------------- the standard library: inside the compiler, or in files
// The compiler and its library are one pair (docs/roadmap-1.0.md): the files of the library are the text that is inside the compiler,
// and a folder `Library` with the file VERSION is used when it is found (JCMP_LIB, Library next to the compiler, ../Library/jcmp next to it).
// The version in lib/VERSION must be the version of the compiler; if not, the compiler stops and says what to do.
int lib_external;                // 1: read the library from files in lib_dir, 0: from the text inside the compiler
char lib_dir[256];

bool lib_has_version(char^ dir) {
    char vp[300];
    str_copy(@vp, dir, 250);
    append_text(@vp, "/VERSION");
    char vb[64];
    return read_file(@vp, @vb, 60) > 0;
}

// the folder of the library (lib_dir), or false
bool lib_find_dir() {
    char^ envd = env_get("JCMP_LIB");
    if envd != null && envd[0] != 0 {
        str_copy(@lib_dir, envd, 250);
        return true;
    }
    char exe[256];
    int en = syscall(78, -100, "/proc/self/exe", @exe, 200);
    if en <= 0 { return false; }
    exe[en] = 0;
    int cut = en;
    while cut > 0 && exe[cut - 1] != '/' { cut -= 1; }
    if cut <= 0 { return false; }
    exe[cut - 1] = 0;
    str_copy(@lib_dir, @exe, 200);
    append_text(@lib_dir, "/Library");
    if lib_has_version(@lib_dir) { return true; }
    str_copy(@lib_dir, @exe, 200);
    append_text(@lib_dir, "/../Library/jcmp");
    if lib_has_version(@lib_dir) { return true; }
    str_copy(@lib_dir, @exe, 200);
    append_text(@lib_dir, "/../Library");
    if lib_has_version(@lib_dir) { return true; }
    lib_dir[0] = 0;
    return false;
}

// at the start of the compiler: choose the source of the library and check that it is the library of this compiler
void lib_init(char^ ver) {
    lib_external = 0;
    if !lib_find_dir() { return; }       // not found: the first program that needs the library says so (ext_put)
    char vp[300];
    str_copy(@vp, @lib_dir, 250);
    append_text(@vp, "/VERSION");
    char vb[64];
    int vn = read_file(@vp, @vb, 60);
    if vn <= 0 {
        begin_msg("error");
        write_err("the folder of the library has no VERSION file: ");
        write_err(@lib_dir);
        end_msg();
        write_err("  help: the folder named in JCMP_LIB (or Library next to the compiler) must be the lib folder of a release of jcmp\n");
        err_count += 1;
        err_summary();
        syscall(93, 1);
    }
    while vn > 0 && (vb[vn - 1] == 10 || vb[vn - 1] == 13 || vb[vn - 1] == ' ') { vn -= 1; }
    vb[vn] = 0;
    if !str_eq(@vb, ver) {
        begin_msg("error");
        write_err("the library in '");
        write_err(@lib_dir);
        write_err("' is for jcmp ");
        write_err(@vb);
        write_err(", but this compiler is jcmp ");
        write_err(ver);
        end_msg();
        write_err("  help: a compiler and its library must be the same version; install them again together (jcmp -update, or the install script)\n");
        err_count += 1;
        err_summary();
        syscall(93, 1);
    }
    lib_external = 1;
}

// jcmp -update [VERSION]: run the install script, which replaces the compiler and the library together (a pair).
// The script comes from JCMP_INSTALL_URL (a mirror, or a file: address for tests) or from the public repository.
void self_update(char^ version) {
    char exe[256];
    int en = syscall(78, -100, "/proc/self/exe", @exe, 250);
    if en <= 0 { write_err("jcmp: -update cannot find where the compiler is\n"); syscall(93, 1); }
    exe[en] = 0;
    int cut = en;
    while cut > 0 && exe[cut - 1] != '/' { cut -= 1; }
    if cut <= 1 { write_err("jcmp: -update cannot find the folder of the compiler\n"); syscall(93, 1); }
    exe[cut - 1] = 0;
    char^ url = env_get("JCMP_INSTALL_URL");
    if url == null || url[0] == 0 { url = "https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh"; }
    char script[1200];
    script[0] = 0;
    append_text(@script, "U='");
    append_text(@script, url);
    append_text(@script, "'; (curl -fsSL \"$U\" || wget -qO- \"$U\") | sh -s -- --dir '");
    append_text(@script, @exe);
    append_text(@script, "'");
    if lib_find_dir() {
        append_text(@script, " --libdir '");
        append_text(@script, @lib_dir);
        append_text(@script, "'");
    } else {
        append_text(@script, " --with-lib");
    }
    if version != null {
        append_text(@script, " --version '");
        append_text(@script, version);
        append_text(@script, "'");
    }
    int k = 0;
    while script[k] != 0 {
        if script[k] == 10 { write_err("jcmp: -update: a name has a line break in it\n"); syscall(93, 1); }
        k += 1;
    }
    write_err("jcmp: updating the compiler and its library together ...\n");
    char^ prefix = env_get("PREFIX");
    char shp[200];
    shp[0] = 0;
    int ne = 0;
    while arg(argc() + 1 + ne) != null { ne += 1; }
    int envp[200];
    if ne > 190 { ne = 190; }
    int ei = 0;
    while ei < ne { envp[ei] = (int)arg(argc() + 1 + ei); ei += 1; }
    envp[ne] = 0;
    int av[6];
    av[0] = (int)"sh";
    av[1] = (int)"-c";
    av[2] = (int)@script;
    av[3] = 0;
    int pid = syscall(220, 17, 0, 0, 0, 0);
    if pid == 0 {
        if prefix != null && str_len(prefix) < 150 {
            str_copy(@shp, prefix, 150);
            append_text(@shp, "/bin/sh");
            syscall(221, @shp, @av, @envp);
        }
        syscall(221, "/bin/sh", @av, @envp);
        syscall(221, "/system/bin/sh", @av, @envp);
        syscall(221, "/usr/bin/sh", @av, @envp);
        syscall(93, 127);
    }
    int status = 0;
    syscall(260, pid, @status, 0, 0);
    if status != 0 { write_err("jcmp: -update failed; nothing was changed unless the lines above say so\n"); syscall(93, 1); }
    syscall(93, 0);
}

// the text of the library file name.j is added to the library "file" that is being made (see the push_ functions)
void lib_missing() {
    begin_msg("error");
    write_err("the library of jcmp was not found");
    end_msg();
    write_err("  help: the compiler and its library are installed together; the library is the folder Library next to the compiler (or ../Library/jcmp, or the folder named in JCMP_LIB)\n");
    write_err("  help: install them again with  jcmp -update  or with the install script\n");
    err_count += 1;
    err_summary();
    syscall(93, 1);
}

void ext_put(char^ name) {
    if lib_external == 0 { lib_missing(); }
    char fp[300];
    str_copy(@fp, @lib_dir, 250);
    append_text(@fp, "/");
    append_text(@fp, name);
    append_text(@fp, ".j");
    int room = 524288 - cur_len - 4;
    int n = read_file(@fp, @src_bufs + cur_base + cur_len, room);
    if n < 0 {
        begin_msg("error");
        write_err("a file of the library cannot be read: ");
        write_err(@fp);
        end_msg();
        write_err("  help: the library folder is damaged or incomplete; install the compiler and its library again (jcmp -update)\n");
        err_count += 1;
        err_summary();
        syscall(93, 1);
    }
    cur_len += n;
}

// the file of the library NAME: NAME.j in the folder Library (the libraries that come with the compiler), else in the places of the libraries that
// are installed later (-I, J2K_PATH, ~/.j2k/Library: jget puts them there). false when there is none.
bool lib_resolve(char^ name, char^ out) {
    if lib_external == 1 {
        str_copy(out, @lib_dir, 250);
        append_text(out, "/");
        append_text(out, name);
        append_text(out, ".j");
        if file_exists(out) { return true; }
    }
    char rel[80];
    str_copy(@rel, name, 70);
    return find_library(@rel, out);
}

// the library NAME becomes a new level that is read next (as the units of the standard library do)
void push_lib(char^ name) {
    char path[300];
    if !lib_resolve(name, @path) {
        char m[160];
        str_copy(@m, "the library '", 20);
        append_text(@m, name);
        append_text(@m, "' is not installed");
        die_help(@m, "install it with  jget -li install NAME  (the download tool: https://github.com/J2k-studio/Jget); the libraries that come with jcmp are in its folder Library");
    }
    if lx_depth >= 15 { die("imports nested too deeply"); }
    stk_pos[lx_depth] = cur_pos;
    stk_line[lx_depth] = cur_line;
    stk_ls[lx_depth] = cur_line_start;
    stk_len[lx_depth] = cur_len;
    str_copy(@lvl_name + (lx_depth + 1) * 128, @path, 128);
    lx_depth += 1;
    lvl_lib[lx_depth] = 1;
    cur_base = lx_depth * 524288;
    cur_len = 0;
    int n = read_file(@path, @src_bufs + cur_base, 524000);
    if n < 0 { die_file(@path); }
    cur_len = n;
    src_bufs[cur_base + cur_len] = 0;
    cur_pos = 0;
    cur_line = 1;
    cur_line_start = 0;
}

void put(char^ text) {
    int i = 0;
    while text[i] != 0 {
        src_bufs[cur_base + cur_len] = text[i];
        cur_len += 1;
        i += 1;
    }
    src_bufs[cur_base + cur_len] = 10;
    cur_len += 1;
}

// p[0..n) is a path without its extension: try ".j" then ".jk"; the one that
// exists is left in p (if neither exists p ends in ".j")
bool try_ext(char^ p, int n) {
    p[n] = '.';
    p[n + 1] = 'j';
    p[n + 2] = 0;
    if file_exists(p) { return true; }
    p[n + 2] = 'k';
    p[n + 3] = 0;
    if file_exists(p) { return true; }
    p[n + 2] = 0;
    return false;
}

bool file_exists(char^ p) {
    int fd = syscall(56, -100, p, 0, 0);
    if fd < 0 { return false; }
    syscall(57, fd);
    return true;
}

// the value of an environment variable (the strings after the arguments of the program), or null
char^ env_get(char^ name) {
    int i = argc() + 1;
    int nl = str_len(name);
    while arg(i) != null {
        char^ e = arg(i);
        int k = 0;
        while k < nl && e[k] == name[k] { k += 1; }
        if k == nl && e[k] == '=' { return e + nl + 1; }
        i += 1;
    }
    return null;
}

// dir/rel.j or dir/rel.jk, or dir/rel/last.j(k) where last is the last part of rel (a package folder);
// the path that exists is left in out
bool try_lib_dir(char^ dir, char^ rel, char^ out) {
    int n = str_len(dir);
    if n == 0 || n > 150 { return false; }
    str_copy(out, dir, 256);
    out[n] = '/';
    n += 1;
    int r = str_len(rel);
    if n + r > 240 { return false; }
    int k = 0;
    while k < r {
        out[n + k] = rel[k];
        k += 1;
    }
    n += r;
    out[n] = 0;
    if try_ext(out, n) { return true; }
    int last = 0;
    k = 0;
    while k < r {
        if rel[k] == '/' { last = k + 1; }
        k += 1;
    }
    out[n] = '/';
    n += 1;
    k = last;
    while k < r && n < 245 {
        out[n] = rel[k];
        n += 1;
        k += 1;
    }
    out[n] = 0;
    return try_ext(out, n);
}

// import <name> : look for a library, in order: -I dir, the folders of J2K_PATH (separated by :), ~/.j2k/lib,
// the lib folder next to the compiler. rel is the name with / for the dots.
bool find_library(char^ rel, char^ out) {
    if inc_dir[0] != 0 && try_lib_dir(@inc_dir, rel, out) { return true; }
    char^ jp = env_get("J2K_PATH");
    if jp != null {
        char one[256];
        int p = 0;
        while true {
            int n = 0;
            while jp[p] != 0 && jp[p] != ':' && n < 250 {
                one[n] = jp[p];
                n += 1;
                p += 1;
            }
            one[n] = 0;
            if n > 0 && try_lib_dir(@one, rel, out) { return true; }
            if jp[p] == 0 { break; }
            p += 1;
        }
    }
    char^ home = env_get("HOME");
    if home != null {
        char hd[256];
        str_copy(@hd, home, 200);
        append_text(@hd, "/.j2k/Library");
        if try_lib_dir(@hd, rel, out) { return true; }
    }
    char exe[256];
    int en = syscall(78, -100, "/proc/self/exe", @exe, 200);
    if en > 0 {
        exe[en] = 0;
        int cut = en;
        while cut > 0 && exe[cut - 1] != '/' { cut -= 1; }
        if cut > 0 {
            exe[cut - 1] = 0;
            char ld[256];
            str_copy(@ld, @exe, 200);
            append_text(@ld, "/Library");
            if try_lib_dir(@ld, rel, out) { return true; }
        }
    }
    return false;
}

int import_bare_warned;
int import_hash;             // 1 if the last word import was written with its # (#import)
int import_warned;           // 1 after the warning about a library written without < >

// switch to the file at path (once)
void import_file(char^ path) {
    int j = 0;
    while j < inc_count {
        if str_eq(@inc_names + j * 128, path) {
            next();                      // already imported: skip it
            return;
        }
        j += 1;
    }
    if inc_count >= 512 { die("too many imported files"); }
    str_copy(@inc_names + inc_count * 128, path, 128);
    inc_count += 1;
    push_file(path);
    next();
}

// using math::vector / matrix / (nothing: all): the current token is `math`, nothing after it is read yet.
// The text of the parts is pushed so that it is read before whatever follows the using.
void using_math() {
    if math_loaded == 0 { die("using math needs  #import <math>  first"); }
    skip_blanks();
    int want = 31;                                   // all the parts: 1 vector, 2 matrix, 4 quat, 8 complex, 16 stats
    if lc(0) == ':' && lc(1) == ':' {
        adv();
        adv();
        skip_blanks();
        char part[32];
        int n = 0;
        while is_letter(lc(0)) && n < 30 {
            part[n] = lc(0);
            n += 1;
            adv();
        }
        part[n] = 0;
        if str_eq(@part, "vector") { want = 1; }
        else if str_eq(@part, "matrix") { want = 3; }          // matrix needs vector
        else if str_eq(@part, "quat") { want = 5; }            // quat needs vector
        else if str_eq(@part, "complex") { want = 8; }
        else if str_eq(@part, "stats") { want = 16; }
        else { die_name("unknown part of math (vector, matrix, quat, complex or stats)", @part); }
    }
    skip_blanks();
    if lc(0) == ';' { adv(); }
    // the last one pushed is read first: vector comes first, then matrix and quat, and the others
    if (want & 16) != 0 && stats_loaded == 0 {
        stats_loaded = 1;
        push_lib("stats");
    }
    if (want & 8) != 0 && cplx_loaded == 0 {
        cplx_loaded = 1;
        push_lib("complex");
    }
    if (want & 4) != 0 && quat_loaded == 0 {
        quat_loaded = 1;
        push_lib("quat");
    }
    if (want & 2) != 0 && matrix_loaded == 0 {
        matrix_loaded = 1;
        push_lib("matrix");
    }
    if (want & 1) != 0 && vector_loaded == 0 {
        vector_loaded = 1;
        push_lib("vector");
    }
    next();
}

// using gfx::canvas : like using_math (the current token is `gfx`)
void using_gfx() {
    if gfx_loaded == 0 { die("using gfx needs  #import <gfx>  first"); }
    int want = 3;                                    // 1 canvas, 2 screen, 3 both
    skip_blanks();
    if lc(0) == ':' && lc(1) == ':' {
        adv();
        adv();
        skip_blanks();
        char part[32];
        int n = 0;
        while is_letter(lc(0)) && n < 30 {
            part[n] = lc(0);
            n += 1;
            adv();
        }
        part[n] = 0;
        if str_eq(@part, "canvas") { want = 1; }
        else if str_eq(@part, "screen") { want = 2; }
        else { die_name("unknown part of gfx (canvas or screen)", @part); }
    }
    skip_blanks();
    if lc(0) == ';' { adv(); }
    // read first: vector, then canvas / screen
    if (want == 1 || want == 3) && canvas_loaded == 0 {
        canvas_loaded = 1;
        push_lib("canvas");
    }
    if (want == 2 || want == 3) && screen_loaded == 0 {
        screen_loaded = 1;
        push_lib("screen");
    }
    if vector_loaded == 0 {
        vector_loaded = 1;
        push_lib("vector");
    }
    next();
}

// the units of the mask that are not read yet become a new "file" (read next)
void std_load(int mask) {
    int need = mask - (mask & std_units);
    if need == 0 { return; }
    std_units = std_units | need;
    std_loaded = 1;
    push_std_units(need);
}

// the mask of a category of the standard library (0: it is not one): the units it needs are in it
int std_category(char^ name) {
    if str_eq(name, "core") { return 1; }
    if str_eq(name, "number") { return 3; }
    if str_eq(name, "text") { return 5; }
    if str_eq(name, "files") { return 13; }
    if str_eq(name, "system") { return 21; }
    if str_eq(name, "time") { return 33; }
    if str_eq(name, "data") { return 71; }
    if str_eq(name, "crypto") { return 141; }
    if str_eq(name, "net") { return 397; }
    return 0;
}

// the library `name` (with / for the dots) is loaded: the built-in ones (stdlib, cpu), else a file found by find_library
// jcmp -showlib NAME: the source of a library that is inside the compiler, written to the standard output (1: shown, 0: no such library)
bool show_library(char^ name) {
    int mask = std_category(name);
    if str_eq(name, "stdlib") || str_eq(name, "std") || str_eq(name, "math") || str_eq(name, "gfx") { mask = 511; }
    if mask != 0 {
        push_std_units(mask);
    } else if str_eq(name, "simd") || str_eq(name, "cpu") || str_eq(name, "vector") || str_eq(name, "matrix") || str_eq(name, "quat") || str_eq(name, "complex") || str_eq(name, "stats") || str_eq(name, "canvas") || str_eq(name, "screen") {
        push_lib(name);
    }
    else { return false; }
    syscall(64, 1, @src_bufs + cur_base, cur_len);
    return true;
}

void import_library(char^ name, char^ rel) {
    if str_eq(name, "stdlib") || str_eq(name, "std") {
        if str_eq(name, "std") && import_warned == 0 {
            import_warned = 1;
            warn("the library 'std' is now called 'stdlib': write import <stdlib>", "deprecated");
        }
        std_load(511);
        next();
        return;
    }
    if str_eq(name, "gfx") {
        // the graphics library: its parts (canvas) are chosen with  using gfx::canvas;  (needs stdlib and math::vector)
        gfx_loaded = 1;
        std_load(511);
        next();
        return;
    }
    if str_eq(name, "math") {
        // the math library: its parts (vector, matrix) are chosen with  using math::vector;
        math_loaded = 1;
        std_load(511);
        next();
        return;
    }
    if std_category(name) != 0 {
        std_load(std_category(name));
        next();
        return;
    }
    if str_eq(name, "simd") {
        if simd_loaded == 0 {
            simd_loaded = 1;
            push_lib("simd");
        }
        next();
        return;
    }
    if str_eq(name, "cpu") {
        if cpu_loaded == 0 {
            cpu_loaded = 1;
            push_lib("cpu");
        }
        next();
        return;
    }
    char found[256];
    if !find_library(rel, @found) { die_name("library not found", name); }
    import_file(@found);
}

// the token is the word "import": switch to the named file (once)
//   import <stdlib>   a library       import "file"   a file next to this one (or in the -I folder)
void lex_import() {
    next();
    if import_hash == 0 {
        die_help("import must be written with a # at the start", "write  #import <stdlib>  or  #import \"file\"");
    }
    if tok_is("<") {
        next();
        char lname[200];
        char lrel[200];
        int ln = 0;
        while true {
            if tok_kind != T_IDENT { die("a library name was expected after import <"); }
            int w = 0;
            while tok_text[w] != 0 && ln < 190 {
                lname[ln] = tok_text[w];
                lrel[ln] = tok_text[w];
                ln += 1;
                w += 1;
            }
            next();
            if tok_is(".") {
                lname[ln] = '.';
                lrel[ln] = '/';
                ln += 1;
                next();
            } else {
                break;
            }
        }
        lname[ln] = 0;
        lrel[ln] = 0;
        if !tok_is(">") { die("> expected to end import <name>"); }
        // the library is loaded from here on: import_library calls next() for the token after >
        import_library(@lname, @lrel);
        return;
    }
    if tok_kind == T_IDENT && (str_eq(@tok_text, "cpu") || str_eq(@tok_text, "std") || str_eq(@tok_text, "stdlib")) {
        char bn[64];
        str_copy(@bn, @tok_text, 64);
        import_library(@bn, @bn);
        return;
    }
    if tok_kind != T_STR { die("import needs a library in < > or a file name in quotes"); }
    char path[256];
    int n = 0;
    int i = 0;
    if tok_str[0] == '.' && tok_str[1] == '/' {
        path[0] = '/';
        n = 1;
        i = 2;
    } else {
        // the folder of the importing file
        int last = -1;
        int k = 0;
        while lvl_name[lx_depth * 128 + k] != 0 {
            if lvl_name[lx_depth * 128 + k] == '/' { last = k; }
            k += 1;
        }
        k = 0;
        while k <= last {
            path[n] = lvl_name[lx_depth * 128 + k];
            n += 1;
            k += 1;
        }
    }
    int name_n = n;                      // where the imported name starts in path
    while tok_str[i] != 0 {
        if n >= 250 { die("import path too long"); }
        if tok_str[i] == '.' {
            path[n] = '/';
        } else {
            path[n] = tok_str[i];
        }
        n += 1;
        i += 1;
    }
    // name.j (a component file) first, then name.jk
    bool found = try_ext(@path, n);
    if !found && inc_dir[0] != 0 && tok_str[0] != '.' {
        // not next to the importing file: look in the -I directory
        char alt[256];
        int an = 0;
        while inc_dir[an] != 0 && an < 200 {
            alt[an] = inc_dir[an];
            an += 1;
        }
        alt[an] = '/';
        an += 1;
        int ak = name_n;
        while ak < n && an < 250 {
            alt[an] = path[ak];
            an += 1;
            ak += 1;
        }
        if try_ext(@alt, an) { str_copy(@path, @alt, 256); }
    }
    if !file_exists(@path) {
        char nm[200];
        str_copy(@nm, "cannot find the file to import: '", 200);
        append_text(@nm, @tok_str);
        append_text(@nm, "' (looked for ");
        append_text(@nm, @path + name_n);
        append_text(@nm, " and the same with .jk, next to this file and in the -I folder)");
        int sl = str_len(@tok_str);
        if (sl > 3 && tok_str[sl - 3] == '.' && tok_str[sl - 2] == 'j' && tok_str[sl - 1] == 'k') || (sl > 2 && tok_str[sl - 2] == '.' && tok_str[sl - 1] == 'j') {
            die_help(@nm, "a name in quotes has no extension: write  #import \"name\"  (a dot in it means a folder)");
        }
        die_help(@nm, "for a library of the standard set write  #import <name>;  for your own file  #import \"name\"  with name.j or name.jk next to this file");
    }
    import_file(@path);
}

// ----------------------------------------------------------------- tokens

// one escape sequence after a backslash (the backslash is already consumed)
int read_escape() {
    int c = lc(0);
    adv();
    if c == 'n' { return 10; }
    if c == 't' { return 9; }
    if c == 'r' { return 13; }
    if c == '0' { return 0; }
    if c == 92 { return 92; }
    if c == 39 { return 39; }
    if c == '"' { return 34; }
    char em[80];
    str_copy(@em, "unknown escape sequence: a backslash followed by '", 80);
    int el = str_len(@em);
    em[el] = c;
    em[el + 1] = 0;
    append_text(@em, "' (the known ones are \\n \\t \\r \\0 \\\\ \\' \\\")");
    die(@em);
    return 0;
}


int prev_tok_line;           // the line of the token before the current one
int prev_end_line;           // where that token ended
int prev_end_col;
int prev_end_base;
int prev_end_ls;

// a[lo..hi] (a name directly followed by brackets with .. at the top level of them, on one line) is written span(a, lo, hi) in the text
// (a view of a part of an array: Span<T> of the standard library). The name is the one just read (wn characters before cur_pos).
int slice_start;
bool slice_rewrite(int wn) {
    if str_eq(@tok_text, "alloc") || str_eq(@tok_text, "alloc0") || str_eq(@tok_text, "free") || str_eq(@tok_text, "grow") || str_eq(@tok_text, "arr") { return false; }
    int p = cur_pos + 1;
    int depth = 0;
    int dots = 0 - 1;
    int close = 0 - 1;
    while p < cur_len && close < 0 {
        int c = src_bufs[cur_base + p];
        if c == 10 || c == ';' || c == '{' || c == '}' || c == '"' || c == 39 { return false; }
        if c == '(' || c == '[' { depth += 1; }
        else if c == ')' { depth -= 1; if depth < 0 { return false; } }
        else if c == ']' {
            if depth == 0 { close = p; } else { depth -= 1; }
        } else if c == '.' && depth == 0 && dots < 0 && src_bufs[cur_base + p + 1] == '.' && src_bufs[cur_base + p - 1] != '.' && src_bufs[cur_base + p + 2] != '.' {
            dots = p;
        }
        p += 1;
    }
    if close < 0 || dots < 0 { return false; }
    int nstart = cur_pos - wn;
    int lo_a = cur_pos + 1;
    int lo_n = dots - lo_a;
    int hi_a = dots + 2;
    int hi_n = close - hi_a;
    if lo_n <= 0 || hi_n <= 0 { return false; }
    int newlen = 5 + wn + 1 + lo_n + 1 + hi_n + 1;          // span( name , lo , hi )
    int oldlen = close + 1 - nstart;
    int delta = newlen - oldlen;
    if cur_len + delta + 2 >= 524288 { return false; }
    // the new text in a temporary place, then the rest of the file is moved
    char tmp[1100];
    if newlen >= 1090 { return false; }
    int q = 0;
    tmp[q] = 's'; tmp[q + 1] = 'p'; tmp[q + 2] = 'a'; tmp[q + 3] = 'n'; tmp[q + 4] = '('; q += 5;
    int k = 0;
    while k < wn { tmp[q] = tok_text[k]; q += 1; k += 1; }
    tmp[q] = ','; q += 1;
    k = 0;
    while k < lo_n { tmp[q] = src_bufs[cur_base + lo_a + k]; q += 1; k += 1; }
    tmp[q] = ','; q += 1;
    k = 0;
    while k < hi_n { tmp[q] = src_bufs[cur_base + hi_a + k]; q += 1; k += 1; }
    tmp[q] = ')'; q += 1;
    int tail = cur_len - (close + 1) + 1;                    // with the byte after the end of the file
    if delta > 0 {
        int m = tail - 1;
        while m >= 0 {
            src_bufs[cur_base + close + 1 + delta + m] = src_bufs[cur_base + close + 1 + m];
            m -= 1;
        }
    } else if delta < 0 {
        int m2 = 0;
        while m2 < tail {
            src_bufs[cur_base + close + 1 + delta + m2] = src_bufs[cur_base + close + 1 + m2];
            m2 += 1;
        }
    }
    k = 0;
    while k < q { src_bufs[cur_base + nstart + k] = tmp[k]; k += 1; }
    cur_len += delta;
    slice_start = nstart;
    return true;
}

// the next token
void next() {
    tok_seq += 1;
    prev_tok_line = err_line;
    prev_end_line = cur_line;
    prev_end_col = cur_pos - cur_line_start + 1;
    prev_end_base = cur_base;
    prev_end_ls = cur_line_start;
    while true {
        skip_blanks();
        if cur_pos < cur_len { break; }
        if lvl_inst[lx_depth] == 1 {
            tok_kind = T_EOF;
            tok_text[0] = 0;
            mark_pos();
            return;
        }
        if lx_depth == 0 {
            tok_kind = T_EOF;
            tok_text[0] = 0;
            mark_pos();
            return;
        }
        pop_file();
    }
    mark_pos();
    int c = lc(0);
    if c == '#' {
        adv();
        char dw[16];
        int dn = 0;
        while is_letter(lc(0)) && dn < 15 {
            dw[dn] = lc(0);
            dn += 1;
            adv();
        }
        dw[dn] = 0;
        if dn == 0 && lc(0) == '!' {
            // #!library : a marker of the whole file (the raw mode); the rest of the line is ignored
            adv();
            char mk[16];
            int mn = 0;
            while is_letter(lc(0)) && mn < 15 {
                mk[mn] = lc(0);
                mn += 1;
                adv();
            }
            mk[mn] = 0;
            if !str_eq(@mk, "library") { die("unknown marker after '#!' (the known one is  #!library )"); }
            bare_mode = 1;
            while lc(0) != 10 && lc(0) != 0 { adv(); }
            next();
            return;
        }
        if str_eq(@dw, "import") {
            // #import <lib> / #import "file" : the token is the word import, written with its #
            tok_kind = T_IDENT;
            str_copy(@tok_text, "import", 8);
            import_hash = 1;
            return;
        }
        if str_eq(@dw, "pragma") {
            // #pragma read | readonly [begin | end]: data that must not change (docs/syntax-design.md 70)
            while lc(0) == 32 || lc(0) == 9 { adv(); }
            char pw[16];
            int pn = 0;
            while is_letter(lc(0)) && pn < 15 { pw[pn] = lc(0); pn += 1; adv(); }
            pw[pn] = 0;
            if !(str_eq(@pw, "read") || str_eq(@pw, "readonly")) { die("unknown #pragma (the known one is  #pragma read , also  #pragma readonly )"); }
            while lc(0) == 32 || lc(0) == 9 { adv(); }
            char pm[16];
            int pk = 0;
            while is_letter(lc(0)) && pk < 15 { pm[pk] = lc(0); pk += 1; adv(); }
            pm[pk] = 0;
            if str_eq(@pm, "begin") { ro_block = 1; }
            else if str_eq(@pm, "end") { ro_block = 0; }
            else if pk != 0 { die("after #pragma read only begin or end can follow"); }
            else if tok_seq <= lvl_seq0[lx_depth] + 1 { ro_file = ro_file | (1 << lx_depth); }     // the first thing of the file: all of its globals
            else { ro_next = 1; }                                                                   // the next global variable
            while lc(0) != 10 && lc(0) != 0 { adv(); }
            next();
            return;
        }
        if str_eq(@dw, "multithread") {
            mt_pending = 1;              // the next statement must be a for loop: its iterations run on several threads
            next();
            return;
        }
        if str_eq(@dw, "allow") {
            // #allow syscall : this program calls the system by number on purpose (no warning about syscall(...))
            while lc(0) == 32 || lc(0) == 9 { adv(); }
            char aw[32];
            int ak = 0;
            while is_letter(lc(0)) && ak < 30 {
                aw[ak] = lc(0);
                ak += 1;
                adv();
            }
            aw[ak] = 0;
            if str_eq(@aw, "syscall") { allow_syscall = 1; }
            else { die("after #allow can follow: syscall"); }
            while lc(0) != 10 && lc(0) != 0 { adv(); }
            next();
            return;
        }
        if str_eq(@dw, "reserve") {
            // #reserve x19, x20 : the compiler never uses these registers; the program does (Reg::x19, register { })
            while true {
                while lc(0) == 32 || lc(0) == 9 { adv(); }
                if lc(0) != 'x' { die("#reserve takes registers: #reserve x18, x19"); }
                adv();
                int rn = 0;
                int rd = 0;
                while is_digit(lc(0)) {
                    rn = rn * 10 + (lc(0) - '0');
                    rd += 1;
                    adv();
                }
                if rd == 0 || !(rn == 18 || (rn >= 19 && rn <= 25)) { die("only x18 and x19 .. x25 can be reserved (x0 .. x17 are used by every expression, x26 .. x30 by the runtime)"); }
                reserve_mask = reserve_mask | (1 << rn);
                while lc(0) == 32 || lc(0) == 9 { adv(); }
                if lc(0) == ',' { adv(); } else { break; }
            }
            next();
            return;
        }
        if !str_eq(@dw, "define") { die("unknown directive after #"); }
        while lc(0) == 32 || lc(0) == 9 { adv(); }
        if !is_letter(lc(0)) { die_help("#define needs a name", "write #define NAME value"); }
        if def_count >= 2048 { die("too many #define names"); }
        int di = def_count;
        int dk = 0;
        while is_alnum(lc(0)) {
            if dk < 62 {
                def_name[di * 64 + dk] = lc(0);
                dk += 1;
            }
            adv();
        }
        def_name[di * 64 + dk] = 0;
        while lc(0) == 32 || lc(0) == 9 { adv(); }
        int dv = 0;
        while cur_pos < cur_len && lc(0) != 10 && !(lc(0) == '/' && lc(1) == '/') {
            if dv < 250 {
                def_val[di * 256 + dv] = lc(0);
                dv += 1;
            }
            adv();
        }
        while dv > 0 && (def_val[di * 256 + dv - 1] == 32 || def_val[di * 256 + dv - 1] == 9) { dv -= 1; }
        def_val[di * 256 + dv] = 0;
        if dv < 248 && define_is_expr(@def_val + di * 256, dv) {
            int mv = dv;
            while mv > 0 {
                def_val[di * 256 + mv] = def_val[di * 256 + mv - 1];
                mv -= 1;
            }
            def_val[di * 256] = '(';
            def_val[di * 256 + dv + 1] = ')';
            def_val[di * 256 + dv + 2] = 0;
        }
        def_count += 1;
        next();
        return;
    }
    if c == 'r' && lc(1) == '"' {
        // raw string r"...": no escapes, ends at the next double quote
        adv();
        adv();
        tok_kind = T_STR;
        int rn = 0;
        while lc(0) != '"' {
            if cur_pos >= cur_len { die_help("unterminated string", "add the closing \" before the end of the line (a text cannot continue on the next line)"); }
            if rn >= 1000 { die_help("string literal too long", "split the text in two with +, or put it in a file and read it"); }
            tok_str[rn] = lc(0);
            rn += 1;
            adv();
        }
        adv();
        tok_str[rn] = 0;
        tok_str_len = rn;
        return;
    }
    if is_letter(c) {
        int wn = 0;
        while is_alnum(lc(0)) {
            if wn >= 63 { die("name too long (63 characters at most)"); }
            tok_text[wn] = lc(0);
            wn += 1;
            adv();
        }
        tok_text[wn] = 0;
        tok_kind = T_IDENT;
        if lc(0) == '[' && slice_rewrite(wn) {
            // a[lo..hi] became span(a, lo, hi): read it again from the start of the name
            cur_pos = slice_start;
            next();
            return;
        }
        if wn == 6 && str_eq(@tok_text, "import") { import_hash = 0; }
        int dfound = find_define(@tok_text);
        if dfound >= 0 {
            push_macro(@def_val + dfound * 256);
            next();
            return;
        }
        gen_use();
        // xor= shl= shr= are operators (the words themselves are operators too)
        if lc(0) == '=' && lc(1) != '=' {
            if str_eq(@tok_text, "xor") || str_eq(@tok_text, "shl") || str_eq(@tok_text, "shr") {
                tok_text[wn] = '=';
                tok_text[wn + 1] = 0;
                tok_kind = T_OP;
                adv();
            }
        }
        return;
    }
    if is_digit(c) {
        tok_kind = T_NUM;
        tok_char = 0;
        tok_float = 0;
        tok_num = 0;
        if c == '0' && (lc(1) == 'x' || lc(1) == 'X') {
            adv();
            adv();
            if hex_value(lc(0)) < 0 { die_help("bad hex number", "a hex number is 0x followed by digits 0-9 and a-f"); }
            while hex_value(lc(0)) >= 0 || (lc(0) == '_' && hex_value(lc(1)) >= 0) {
                if lc(0) == '_' {
                    adv();                                   // 0x0900_0000 : a _ between digits is ignored
                    continue;
                }
                tok_num = tok_num * 16 + hex_value(lc(0));
                adv();
            }
        } else if c == '0' && (lc(1) == 'b' || lc(1) == 'B') {
            adv();
            adv();
            if lc(0) != '0' && lc(0) != '1' { die_help("bad binary number", "a binary number is 0b followed by 0 and 1"); }
            while lc(0) == '0' || lc(0) == '1' || (lc(0) == '_' && (lc(1) == '0' || lc(1) == '1')) {
                if lc(0) == '_' {
                    adv();
                    continue;
                }
                tok_num = tok_num * 2 + (lc(0) - '0');
                adv();
            }
        } else {
            int fm = 0;                                      // the first 18 digits, for a decimal number with a long whole part
            int fextra = 0;                                  // the digits after those
            int fnd = 0;
            while is_digit(lc(0)) || (lc(0) == '_' && is_digit(lc(1))) {
                if lc(0) == '_' {
                    adv();                                   // 1_000_000
                    continue;
                }
                tok_num = tok_num * 10 + (lc(0) - '0');
                if fm > 0 || lc(0) != '0' { fnd += 1; }
                if fnd <= 18 { fm = fm * 10 + (lc(0) - '0'); } else { fextra += 1; }
                adv();
            }
            // 1.5   2.5e10   1e-3   (a "." must be followed by a digit: 0..10 is a range)
            bool has_frac = lc(0) == '.' && is_digit(lc(1));
            bool has_exp = (lc(0) == 'e' || lc(0) == 'E') && (is_digit(lc(1)) || ((lc(1) == '+' || lc(1) == '-') && is_digit(lc(2))));
            if has_frac || has_exp {
                tok_float = 1;
                tok_mant = tok_num;
                tok_exp = 0;
                if fextra > 0 {
                    tok_mant = fm;                           // 12345678901234567890.0 : the first 18 digits and a power of ten
                    tok_exp = fextra;
                }
                if has_frac {
                    adv();
                    while is_digit(lc(0)) {
                        if tok_mant <= 99999999999999999 {          // more than 18 digits are not kept (a double has about 16)
                            tok_mant = tok_mant * 10 + (lc(0) - '0');
                            tok_exp -= 1;
                        }
                        adv();
                    }
                }
                if lc(0) == 'e' || lc(0) == 'E' {
                    adv();
                    int exp_sign = 1;
                    if lc(0) == '-' {
                        exp_sign = 0 - 1;
                        adv();
                    } else if lc(0) == '+' {
                        adv();
                    }
                    int exp_val = 0;
                    while is_digit(lc(0)) {
                        if exp_val < 1000 { exp_val = exp_val * 10 + (lc(0) - '0'); }
                        adv();
                    }
                    tok_exp += exp_sign * exp_val;
                }
                if tok_exp > 308 || tok_exp < 0 - 308 { die("float literal exponent out of range (-308..308)"); }
            }
        }
        return;
    }
    if c == '"' {
        adv();
        tok_kind = T_STR;
        int sn = 0;
        while lc(0) != '"' {
            if cur_pos >= cur_len { die_help("unterminated string", "add the closing \" before the end of the line (a text cannot continue on the next line)"); }
            int sch = lc(0);
            adv();
            if sch == 92 { sch = read_escape(); }
            if sn >= 1000 { die_help("string literal too long", "split the text in two with +, or put it in a file and read it"); }
            tok_str[sn] = sch;
            sn += 1;
        }
        adv();
        tok_str[sn] = 0;
        tok_str_len = sn;
        if sn >= 2 && tok_str[sn - 2] == '/' && tok_str[sn - 1] == 'n' {
            // "/n" or "text/n": a slash and the letter n (not a new line) unless the text is a path with more slashes
            int sl = 0;
            int sli = 0;
            while sli < sn { if tok_str[sli] == '/' { sl += 1; } sli += 1; }
            if sl == 1 { warn("this text ends with /n (a slash and the letter n): a new line is written \\n, with a backslash", "slash-n"); }
        }
        return;
    }
    if c == 39 {
        adv();
        tok_kind = T_NUM;
        tok_char = 1;
        tok_float = 0;
        int cch = lc(0);
        adv();
        if cch == 92 { cch = read_escape(); }
        if lc(0) != 39 { die_help("unterminated character literal", "a character is written between single quotes: 'a'"); }
        adv();
        tok_num = cch;
        return;
    }
    // operators: longest match
    tok_kind = T_OP;
    int c1 = lc(1);
    int c2 = lc(2);
    int len = 1;
    if (c == '<' && c1 == '<' && c2 == '=') || (c == '>' && c1 == '>' && c2 == '=') {
        len = 3;
    } else if (c == '&' && c1 == '&') || (c == '|' && c1 == '|') || (c == '=' && c1 == '=') {
        len = 2;
    } else if (c == '!' && c1 == '=') || (c == '<' && c1 == '=') || (c == '>' && c1 == '=') {
        len = 2;
    } else if (c == '<' && c1 == '<') || (c == '>' && c1 == '>') || (c == ':' && c1 == ':') {
        len = 2;
    } else if (c == '+' && c1 == '=') || (c == '-' && c1 == '=') || (c == '*' && c1 == '=') {
        len = 2;
    } else if (c == '/' && c1 == '=') || (c == '%' && c1 == '=') || (c == '&' && c1 == '=') {
        len = 2;
    } else if (c == '|' && c1 == '=') || (c == '+' && c1 == '+') || (c == '-' && c1 == '-') {
        len = 2;
    } else if c == '-' && c1 == '>' {
        len = 2;                         // ->  (a lambda)
    }
    int k = 0;
    while k < len {
        tok_text[k] = lc(0);
        adv();
        k += 1;
    }
    tok_text[len] = 0;
}

// ------------------------------------------------------------ parser helpers

// is the current token this operator or word?
bool tok_is(char^ s) {
    if tok_kind != T_OP && tok_kind != T_IDENT { return false; }
    return str_eq(@tok_text, s);
}

bool accept(char^ s) {
    if tok_is(s) {
        next();
        return true;
    }
    return false;
}

int soft_paren_line;         // the line where a missing ')' or ']' was reported: the ';' that follows is not reported again

void missing_semicolon(int soft) {
    if soft == 1 && soft_paren_line == prev_tok_line { return; }
    char m[100];
    err_line = prev_end_line;            // the message points just after the last token of the line above
    err_col = prev_end_col;
    err_base = prev_end_base;
    err_ls = prev_end_ls;
    str_copy(@m, "expected ';' at the end of line ", 100);
    append_int(@m, prev_tok_line);
    append_text(@m, ": the statement is not finished");
    if soft == 1 { soft_error(@m); } else { die(@m); }
}

void expect(char^ s) {
    if !tok_is(s) {
        if str_eq(s, ";") && err_line > prev_tok_line && prev_tok_line > 0 {
            // the ';' is missing at the end of a line: say so, go on as if it was written (the next token is not used up)
            missing_semicolon(1);
            return;
        }
        if (str_eq(s, ")") || str_eq(s, "]")) && err_line > prev_tok_line && prev_tok_line > 0 && pass_no == 1 {
            // a ')' or ']' missing at the end of a line: the same way
            char m2[100];
            int sv_line = err_line;
            int sv_col = err_col;
            int sv_base = err_base;
            int sv_ls = err_ls;
            err_line = prev_end_line;
            err_col = prev_end_col;
            err_base = prev_end_base;
            err_ls = prev_end_ls;
            str_copy(@m2, "expected '", 100);
            append_text(@m2, s);
            append_text(@m2, "' at the end of line ");
            append_int(@m2, prev_tok_line);
            append_text(@m2, ": it is not closed");
            soft_error(@m2);
            err_line = sv_line;
            err_col = sv_col;
            err_base = sv_base;
            err_ls = sv_ls;
            soft_paren_line = prev_tok_line;
            return;
        }
        begin_msg("error");
        write_err("expected '");
        write_err(s);
        write_err("', but found ");
        if tok_kind == T_EOF {
            write_err("the end of the file");
        } else if tok_kind == T_STR {
            write_err("a text");
        } else {
            write_err("'");
            write_err(@tok_text);
            write_err("'");
        }
        end_msg();
        die_end();
    }
    next();
}
