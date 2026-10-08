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
char lvl_name[2048];         // path of the file at each level (16 x 128)
char inc_names[65536];        // paths already imported (64 x 128)
int inc_count;
int std_loaded;              // 1 once `import std` has been read

// ---------------------------------------------------------------- #define
char def_name[131072];         // 256 names x 64
char def_val[524288];         // 256 values x 256
int def_count;

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
    write_err(@err_file);
    write_err(":");
    write_err_int(err_line);
    write_err(":");
    write_err_int(err_col);
    write_err(": ");
    write_err(kind);
    write_err(": ");
}

// the end of a message: the source line and a ^ under the column
void end_msg() {
    write_err("\n");
    int a = err_base + err_ls;
    int e = a;
    while src_bufs[e] != 0 && src_bufs[e] != 10 { e += 1; }
    if e > a {
        syscall(64, 2, @src_bufs + a, e - a);
        write_err("\n");
        int k = 0;
        while k < err_col - 1 && k < e - a {
            if src_bufs[a + k] == 9 { write_err("\t"); } else { write_err(" "); }
            k += 1;
        }
        write_err("^\n");
    }
}

void die(char^ msg) {
    begin_msg("error");
    write_err(msg);
    end_msg();
    syscall(93, 1);
}

// die with a name in the message:  error: msg 'name'
void die_name(char^ msg, char^ name) {
    begin_msg("error");
    write_err(msg);
    write_err(" '");
    write_err(name);
    write_err("'");
    end_msg();
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

// make `path` the current file (a new level); the old one is saved
void push_file(char^ path) {
    if lx_depth >= 15 { die("imports nested too deeply"); }
    stk_pos[lx_depth] = cur_pos;
    stk_line[lx_depth] = cur_line;
    stk_ls[lx_depth] = cur_line_start;
    lx_depth += 1;
    cur_base = lx_depth * 524288;
    str_copy(@lvl_name + lx_depth * 128, path, 128);
    int n = read_file(path, @src_bufs + cur_base, 524288);
    if n < 0 { die_name("cannot read file", path); }
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
    str_copy(@lvl_name + (lx_depth + 1) * 128, @lvl_name + lx_depth * 128, 128);
    lx_depth += 1;
    cur_base = lx_depth * 524288;
    str_copy(@src_bufs + cur_base, text, 300);
    cur_len = str_len(text);
    cur_pos = 0;
    cur_line = stk_line[lx_depth - 1];
    cur_line_start = 0;
}

void pop_file() {
    lx_depth -= 1;
    cur_base = lx_depth * 524288;
    cur_pos = stk_pos[lx_depth];
    cur_line = stk_line[lx_depth];
    cur_line_start = stk_ls[lx_depth];
    // the length of the file we returned to: it ends at its last 0 byte
    int n = 0;
    while src_bufs[cur_base + n] != 0 { n += 1; }
    cur_len = n;
    set_err_file(lx_depth);
}

void lex_init(char^ path) {
    def_count = 0;
    std_loaded = 0;
    lx_depth = 0;
    cur_base = 0;
    str_copy(@lvl_name, path, 128);
    int n = read_file(path, @src_bufs, 524288);
    if n < 0 { die_name("cannot read file", path); }
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

// the token is the word "import": switch to the named file (once)
void lex_import() {
    next();
    if tok_kind == T_IDENT && str_eq(@tok_text, "std") {
        if std_loaded == 0 {
            std_loaded = 1;
            push_std();
        }
        next();
        return;
    }
    if tok_kind != T_STR { die("import needs a file name in quotes"); }
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
    int j = 0;
    while j < inc_count {
        if str_eq(@inc_names + j * 128, @path) {
            next();                      // already imported: skip it
            return;
        }
        j += 1;
    }
    if inc_count >= 512 { die("too many imported files"); }
    str_copy(@inc_names + inc_count * 128, @path, 128);
    inc_count += 1;
    push_file(@path);
    next();
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
    die("unknown escape sequence");
    return 0;
}

// the next token
void next() {
    while true {
        skip_blanks();
        if cur_pos < cur_len { break; }
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
        if !str_eq(@dw, "define") { die("unknown directive after #"); }
        while lc(0) == 32 || lc(0) == 9 { adv(); }
        if !is_letter(lc(0)) { die("#define needs a name"); }
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
            if cur_pos >= cur_len { die("unterminated string"); }
            if rn >= 1000 { die("string literal too long"); }
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
        int dfound = find_define(@tok_text);
        if dfound >= 0 {
            push_macro(@def_val + dfound * 256);
            next();
            return;
        }
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
            if hex_value(lc(0)) < 0 { die("bad hex number"); }
            while hex_value(lc(0)) >= 0 {
                tok_num = tok_num * 16 + hex_value(lc(0));
                adv();
            }
        } else if c == '0' && (lc(1) == 'b' || lc(1) == 'B') {
            adv();
            adv();
            if lc(0) != '0' && lc(0) != '1' { die("bad binary number"); }
            while lc(0) == '0' || lc(0) == '1' {
                tok_num = tok_num * 2 + (lc(0) - '0');
                adv();
            }
        } else {
            while is_digit(lc(0)) {
                tok_num = tok_num * 10 + (lc(0) - '0');
                adv();
            }
            // 1.5   2.5e10   1e-3   (a "." must be followed by a digit: 0..10 is a range)
            bool has_frac = lc(0) == '.' && is_digit(lc(1));
            bool has_exp = (lc(0) == 'e' || lc(0) == 'E') && (is_digit(lc(1)) || ((lc(1) == '+' || lc(1) == '-') && is_digit(lc(2))));
            if has_frac || has_exp {
                tok_float = 1;
                tok_mant = tok_num;
                tok_exp = 0;
                if tok_mant > 9007199254740992 { die("float literal has too many digits"); }
                if has_frac {
                    adv();
                    while is_digit(lc(0)) {
                        if tok_mant > 900719925474099 { die("float literal has too many digits"); }
                        tok_mant = tok_mant * 10 + (lc(0) - '0');
                        tok_exp -= 1;
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
                if tok_mant > 9007199254740992 { die("float literal has too many digits"); }
                if tok_exp > 22 || tok_exp < 0 - 22 { die("float literal exponent out of range (-22..22)"); }
            }
        }
        return;
    }
    if c == '"' {
        adv();
        tok_kind = T_STR;
        int sn = 0;
        while lc(0) != '"' {
            if cur_pos >= cur_len { die("unterminated string"); }
            int sch = lc(0);
            adv();
            if sch == 92 { sch = read_escape(); }
            if sn >= 1000 { die("string literal too long"); }
            tok_str[sn] = sch;
            sn += 1;
        }
        adv();
        tok_str[sn] = 0;
        tok_str_len = sn;
        return;
    }
    if c == 39 {
        adv();
        tok_kind = T_NUM;
        tok_char = 1;
        int cch = lc(0);
        adv();
        if cch == 92 { cch = read_escape(); }
        if lc(0) != 39 { die("unterminated character literal"); }
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

void expect(char^ s) {
    if !tok_is(s) { die_name("expected", s); }
    next();
}
