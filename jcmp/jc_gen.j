// jc_gen.j -- generics (docs/syntax-design.md, section 41).
//
//   T max<T>(T a, T b) { ... }          a generic function
//   struct List<T> { ... }              a generic struct
//   max<int>(1, 2)     List<int> xs;    a use: the compiler writes the source text of that
//                                       instance (T replaced by int, the name by max__int) and
//                                       compiles it like any other declaration (monomorphization)
//
// How it fits the compiler: before every top-level item, gen_item() (called by parse_program)
//   1. if the item is a generic declaration: keeps its text and skips it;
//   2. otherwise looks through the text of the item for uses `Name<args>` and makes the
//      instances that do not exist yet (at top level, between two items, so that the state of
//      the parser is clean) -- an instance is pushed as an extra "file" and parsed as items;
//   3. the lexer (next) turns `Name<args>` into the single identifier of the instance.
// A generic must be written before its first use. The tables are rebuilt in every pass.

char lam_buf[262144];
int lam_used;
int lam_off[512];
int lam_len[512];
int lam_line[512];
char lam_file[65536];        // 512 x 128
int lam_count;
int lam_done;
int lam_seq;
int lam_warned;
char tpl_text[1048576];      // the texts of the generic declarations
int tpl_used;
char tpl_name[4096];         // 64 x 64
char tpl_par[32768];         // 64 templates x 8 parameters x 64
int tpl_np[64];
int tpl_off[64];
int tpl_len[64];
int tpl_line[64];
char tpl_file[8192];         // 64 x 128
int tpl_count;

char ins_key[65536];         // 256 x 256: Name<arg,arg>
char ins_name[16384];        // 256 x 64: the name of the instance
int ins_state[256];          // 0 entered, 1 compiled
int ins_ti[256];
char ins_args[65536];        // 256 x 256
int ins_count;

char gen_buf[524288];        // the text of the instance being made

// the lexer state saved while an instance is parsed (one slot per level)
int gs_kind[16];
int gs_num[16];
int gs_float[16];
int gs_mant[16];
int gs_exp[16];
int gs_char[16];
int gs_strlen[16];
int gs_line[16];
int gs_col[16];
int gs_base[16];
int gs_ls[16];
int gs_mt[16];
char gs_text[4096];          // 16 x 256
char gs_str[16384];          // 16 x 1024

void gen_reset() {
    lam_used = 0;
    lam_count = 0;
    lam_done = 0;
    lam_seq = 0;
    lam_warned = 0;
    tpl_used = 0;
    tpl_count = 0;
    ins_count = 0;
}

int gen_find_tpl(char^ name) {
    int i = 0;
    while i < tpl_count {
        if str_eq(@tpl_name + i * 64, name) { return i; }
        i += 1;
    }
    return 0 - 1;
}

// ------------------------------------------------------------- raw text scanning
// b[0..n) is source text; these never produce tokens

// a string, a character literal or a comment starts at b[i]: the index after it; otherwise i
int gen_skip_lit(char^ b, int i, int n) {
    int c = b[i];
    if c == 34 {
        int raw = 0;
        if i > 0 && b[i - 1] == 'r' {
            raw = 1;
            if i > 1 && is_alnum(b[i - 2]) { raw = 0; }
        }
        i += 1;
        while i < n && b[i] != 34 {
            if b[i] == 92 && raw == 0 { i += 1; }
            i += 1;
        }
        return i + 1;
    }
    if c == 39 {
        i += 1;
        while i < n && b[i] != 39 {
            if b[i] == 92 { i += 1; }
            i += 1;
        }
        return i + 1;
    }
    if c == '/' && i + 1 < n && b[i + 1] == '/' {
        while i < n && b[i] != 10 { i += 1; }
        return i;
    }
    if c == '/' && i + 1 < n && b[i + 1] == '*' {
        i += 2;
        while i + 1 < n && !(b[i] == '*' && b[i + 1] == '/') { i += 1; }
        return i + 2;
    }
    return i;
}

int gen_blanks(char^ b, int i, int n) {
    while i < n && is_space(b[i]) { i += 1; }
    return i;
}

// the end of the item that starts at b[i]: after its `;`, or after the `}` that closes its
// block (a block after `=` is an initializer: the item goes on to the `;`)
int gen_item_end(char^ b, int i, int n) {
    int par = 0;
    int brace = 0;
    int init = 0;
    int last = 0;
    while i < n {
        int j = gen_skip_lit(b, i, n);
        if j != i {
            i = j;
        } else {
            int c = b[i];
            if c == '(' || c == '[' {
                par += 1;
            } else if c == ')' || c == ']' {
                par -= 1;
            } else if c == '{' {
                if brace == 0 && last == '=' { init = 1; }
                brace += 1;
            } else if c == '}' {
                brace -= 1;
                if brace == 0 && init == 0 { return i + 1; }
            } else if c == ';' {
                if brace == 0 && par == 0 { return i + 1; }
            }
            if !is_space(c) { last = c; }
            i += 1;
        }
    }
    return n;
}

// b[i] is the `<` of `Name<args>`: copies the arguments, without blanks, to dst
// ("int,List<int>") and returns the index after the closing `>`; -1 if it does not close
int gen_args(char^ b, int i, int n, char^ dst) {
    int depth = 0;
    int o = 0;
    while i < n {
        int c = b[i];
        if c == '<' {
            depth += 1;
            if depth > 1 { dst[o] = c; o += 1; }
        } else if c == '>' {
            depth -= 1;
            if depth == 0 {
                dst[o] = 0;
                return i + 1;
            }
            dst[o] = c;
            o += 1;
        } else if c == ';' || c == '{' || c == '(' || c == ')' || c == '=' {
            return 0 - 1;
        } else if !is_space(c) {
            dst[o] = c;
            o += 1;
        }
        if o >= 240 { die("generic arguments too long"); }
        i += 1;
    }
    return 0 - 1;
}

// copy the identifier at b[i] into word (63 at most); returns its end
int gen_word(char^ b, int i, int n, char^ word) {
    int k = 0;
    while i < n && is_alnum(b[i]) {
        if k < 63 { word[k] = b[i]; k += 1; }
        i += 1;
    }
    word[k] = 0;
    return i;
}

// ----------------------------------------------------------------- the instances

// arg k of a list "a,b<c,d>,e" (depth-aware); returns false if there is no such argument
bool gen_arg(char^ args, int k, char^ dst) {
    int i = 0;
    int depth = 0;
    int cur = 0;
    int o = 0;
    while true {
        int c = args[i];
        if c == 0 || (c == ',' && depth == 0) {
            if cur == k {
                dst[o] = 0;
                return o > 0;
            }
            if c == 0 { return false; }
            cur += 1;
            o = 0;
        } else {
            if c == '<' { depth += 1; }
            if c == '>' { depth -= 1; }
            if cur == k && o < 250 {
                dst[o] = c;
                o += 1;
            }
        }
        i += 1;
    }
    return false;
}

int gen_arg_count(char^ args) {
    int n = 1;
    int depth = 0;
    int i = 0;
    if args[0] == 0 { return 0; }
    while args[i] != 0 {
        if args[i] == '<' { depth += 1; }
        if args[i] == '>' { depth -= 1; }
        if args[i] == ',' && depth == 0 { n += 1; }
        i += 1;
    }
    return n;
}

int gen_find_ins(char^ key) {
    int i = 0;
    while i < ins_count {
        if str_eq(@ins_key + i * 256, key) { return i; }
        i += 1;
    }
    return 0 - 1;
}

// the name of an instance: Name__ + the arguments with ^ [ ] < > , turned into letters
void gen_mangle(char^ dst, char^ name, char^ args) {
    int o = 0;
    int i = 0;
    while name[i] != 0 && o < 40 { dst[o] = name[i]; o += 1; i += 1; }
    dst[o] = '_';
    dst[o + 1] = '_';
    o += 2;
    i = 0;
    while args[i] != 0 {
        int c = args[i];
        if is_alnum(c) {
            dst[o] = c;
            o += 1;
        } else if c == '^' {
            dst[o] = 'P';
            o += 1;
        } else if c == '<' {
            dst[o] = 'L';
            o += 1;
        } else if c == '>' {
            dst[o] = 'G';
            o += 1;
        } else {
            dst[o] = '_';
            o += 1;
        }
        i += 1;
        if o >= 60 { break; }
    }
    dst[o] = 0;
}

int gen_len;

void gen_put(int c) {
    if gen_len >= 524280 { die("generic instance too large"); }
    gen_buf[gen_len] = c;
    gen_len += 1;
}

void gen_put_str(char^ s) {
    int i = 0;
    while s[i] != 0 {
        gen_put(s[i]);
        i += 1;
    }
}

// make the text of instance `ins` of template `ti` in gen_buf
void gen_build(int ti, int ins, char^ args) {
    char argv[256];
    char word[64];
    char skip[256];
    char^ t = @tpl_text + tpl_off[ti];
    int n = tpl_len[ti];
    int i = 0;
    int head = 0;
    gen_len = 0;
    while i < n {
        int j = gen_skip_lit(t, i, n);
        if j != i {
            while i < j && i < n {
                gen_put(t[i]);
                i += 1;
            }
        } else if is_letter(t[i]) {
            int k = gen_word(t, i, n, @word);
            int pi = 0 - 1;
            int q = 0;
            while q < tpl_np[ti] {
                if str_eq(@tpl_par + (ti * 8 + q) * 64, @word) { pi = q; }
                q += 1;
            }
            int nx = gen_blanks(t, k, n);
            if head == 0 && str_eq(@word, @tpl_name + ti * 64) && nx < n && t[nx] == '<' {
                head = 1;
                gen_put_str(@ins_name + ins * 64);
                int e = gen_args(t, nx, n, @skip);
                if e < 0 { die("a generic declaration: > expected"); }
                // keep the blanks and new lines of the skipped part (line numbers stay right)
                int z = k;
                while z < e {
                    if t[z] == 10 { gen_put(10); }
                    z += 1;
                }
                i = e;
            } else if pi >= 0 {
                gen_arg(args, pi, @argv);
                gen_put_str(@argv);
                i = k;
            } else {
                gen_put_str(@word);
                i = k;
            }
        } else if is_digit(t[i]) {
            while i < n && is_alnum(t[i]) {
                gen_put(t[i]);
                i += 1;
            }
        } else {
            gen_put(t[i]);
            i += 1;
        }
    }
    gen_put(10);
    gen_buf[gen_len] = 0;
}

void gen_save(int d) {
    gs_kind[d] = tok_kind;
    gs_num[d] = tok_num;
    gs_float[d] = tok_float;
    gs_mant[d] = tok_mant;
    gs_exp[d] = tok_exp;
    gs_char[d] = tok_char;
    gs_strlen[d] = tok_str_len;
    gs_line[d] = err_line;
    gs_col[d] = err_col;
    gs_base[d] = err_base;
    gs_ls[d] = err_ls;
    gs_mt[d] = mt_pending;
    str_copy(@gs_text + d * 256, @tok_text, 256);
    int i = 0;
    while i <= tok_str_len && i < 1023 {
        gs_str[d * 1024 + i] = tok_str[i];
        i += 1;
    }
}

void gen_restore(int d) {
    tok_kind = gs_kind[d];
    tok_num = gs_num[d];
    tok_float = gs_float[d];
    tok_mant = gs_mant[d];
    tok_exp = gs_exp[d];
    tok_char = gs_char[d];
    tok_str_len = gs_strlen[d];
    err_line = gs_line[d];
    err_col = gs_col[d];
    err_base = gs_base[d];
    err_ls = gs_ls[d];
    mt_pending = gs_mt[d];
    str_copy(@tok_text, @gs_text + d * 256, 256);
    int i = 0;
    while i <= tok_str_len && i < 1023 {
        tok_str[i] = gs_str[d * 1024 + i];
        i += 1;
    }
}

// the instance of template ti with these arguments ("int,List<int>"): its index; a new one is only
// entered in the table (ins_state 0: not compiled yet)
int gen_register(int ti, char^ args) {
    char key[256];
    char nm[64];
    key[0] = 0;
    append_text(@key, @tpl_name + ti * 64);
    append_text(@key, "<");
    append_text(@key, args);
    append_text(@key, ">");
    int f = gen_find_ins(@key);
    if f >= 0 { return f; }
    if gen_arg_count(args) != tpl_np[ti] {
        die_name("wrong number of generic arguments for", @tpl_name + ti * 64);
    }
    if ins_count >= 256 { die("too many generic instances"); }
    int ins = ins_count;
    ins_count += 1;
    ins_state[ins] = 0;
    ins_ti[ins] = ti;
    str_copy(@ins_args + ins * 256, args, 256);
    str_copy(@ins_key + ins * 256, @key, 256);
    gen_mangle(@nm, @tpl_name + ti * 64, args);
    // a name that is too long or already taken by another instance: number it
    int taken = 0;
    int q = 0;
    while q < ins {
        if str_eq(@ins_name + q * 64, @nm) { taken = 1; }
        q += 1;
    }
    if taken == 1 || str_len(@nm) >= 56 {
        nm[0] = 0;
        int tl = str_len(@tpl_name + ti * 64);
        if tl > 40 { tl = 40; }
        int w = 0;
        while w < tl { nm[w] = tpl_name[ti * 64 + w]; w += 1; }
        nm[tl] = 0;
        append_text(@nm, "__g");
        append_int(@nm, ins);
    }
    str_copy(@ins_name + ins * 64, @nm, 64);
    return ins;
}

// compile instance `ins`: its text is read as items, here (at top level)
void gen_compile(int ins) {
    int ti = ins_ti[ins];
    ins_state[ins] = 1;
    gen_build(ti, ins, @ins_args + ins * 256);
    int d = lx_depth;
    gen_save(d);
    push_text(@gen_buf, gen_len, @tpl_file + ti * 128, tpl_line[ti]);
    next();
    while tok_kind != T_EOF { parse_one_item(); }
    pop_file();
    gen_restore(d);
}

// the instance, made and compiled now if it does not exist yet (the use is Name<args> in the text)
int gen_instance(int ti, char^ args) {
    int ins = gen_register(ti, args);
    if ins_state[ins] == 0 { gen_compile(ins); }
    return ins;
}

// the instances that a call without <...> asked for (see gen_infer_call) are compiled after the item
void gen_pending() {
    int i = 0;
    while i < ins_count {
        if ins_state[i] == 0 { gen_compile(i); }
        i += 1;
    }
}

// ------------------------------------------------------------------ the items

// the item starting at b[s] is a generic declaration? registers it and returns its end; else -1
int gen_declaration(char^ b, int s, int n, int line) {
    int i = s;
    char name[64];
    int open = 0 - 1;
    int is_struct = 0;
    char word[64];
    int w = gen_word(b, i, n, @word);
    if str_eq(@word, "struct") && w < n {
        is_struct = 1;
        int a = gen_blanks(b, w, n);
        int e = gen_word(b, a, n, @name);
        int nx = gen_blanks(b, e, n);
        if e > a && nx < n && b[nx] == '<' { open = nx; }
    } else {
        // the first ( = ; { of the head: a function if it is a ( with a > in front of it
        while i < n {
            int j = gen_skip_lit(b, i, n);
            if j != i {
                i = j;
            } else {
                int c = b[i];
                if c == '=' || c == ';' || c == '{' { return 0 - 1; }
                if c == '(' {
                    int k = i - 1;
                    while k > s && is_space(b[k]) { k -= 1; }
                    if b[k] != '>' { return 0 - 1; }
                    int depth = 0;
                    while k > s {
                        if b[k] == '>' { depth += 1; }
                        if b[k] == '<' {
                            depth -= 1;
                            if depth == 0 { break; }
                        }
                        k -= 1;
                    }
                    if b[k] != '<' { return 0 - 1; }
                    open = k;
                    k -= 1;
                    while k > s && is_space(b[k]) { k -= 1; }
                    int e2 = k + 1;
                    while k >= s && is_alnum(b[k]) { k -= 1; }
                    if e2 - (k + 1) < 1 || e2 - (k + 1) > 62 { return 0 - 1; }
                    int z = 0;
                    while z < e2 - (k + 1) { name[z] = b[k + 1 + z]; z += 1; }
                    name[z] = 0;
                    break;
                }
                i += 1;
            }
        }
    }
    if open < 0 { return 0 - 1; }
    if tpl_count >= 64 { die("too many generic declarations"); }
    int ti = tpl_count;
    str_copy(@tpl_name + ti * 64, @name, 64);
    // the parameter names between < and >
    char plist[256];
    int pe = gen_args(b, open, n, @plist);
    if pe < 0 { die("a generic declaration: > expected"); }
    int np = gen_arg_count(@plist);
    if np < 1 || np > 8 { die("a generic declaration needs 1 to 8 parameters"); }
    char one[256];
    int pk = 0;
    while pk < np {
        gen_arg(@plist, pk, @one);
        int ok = 1;
        int oi = 0;
        while one[oi] != 0 {
            if !is_alnum(one[oi]) { ok = 0; }
            oi += 1;
        }
        if ok == 0 || !is_letter(one[0]) { die("a generic parameter must be a name"); }
        str_copy(@tpl_par + (ti * 8 + pk) * 64, @one, 64);
        pk += 1;
    }
    int end = gen_item_end(b, s, n);
    int e3 = gen_blanks(b, end, n);
    if is_struct == 1 && e3 < n && b[e3] == ';' { end = e3 + 1; }
    int len = end - s;
    if tpl_used + len + 1 >= 1048576 { die("generic declarations too large"); }
    int x = 0;
    while x < len {
        tpl_text[tpl_used + x] = b[s + x];
        x += 1;
    }
    tpl_text[tpl_used + len] = 0;
    tpl_off[ti] = tpl_used;
    tpl_len[ti] = len;
    tpl_used += len + 1;
    tpl_line[ti] = line;
    str_copy(@tpl_file + ti * 128, @err_file, 128);
    tpl_np[ti] = np;
    tpl_count += 1;
    return end;
}

// called by parse_program before each top-level item (the first token of the item is current)
void gen_item() {
    if tok_kind != T_IDENT { return; }
    if err_base != cur_base { return; }
    if tok_is("import") || tok_is("enum") || tok_is("using") { return; }
    char^ b = @src_bufs + cur_base;
    int s = err_ls + err_col - 1;
    int n = cur_len;
    int line = err_line;
    int ls = err_ls;
    int end = gen_declaration(b, s, n, line);
    if end >= 0 {
        // a generic declaration: keep the text, skip it
        while cur_base + cur_pos < cur_base + end && cur_pos < cur_len { adv(); }
        next();
        gen_item();
        return;
    }
    if tpl_count == 0 { return; }
    // look for uses of a generic in the text of this item
    int e = gen_item_end(b, s, n);
    int i = s;
    char word[64];
    char args[256];
    int made = 0;
    int keep_line = err_line;
    int keep_col = err_col;
    int keep_ls = err_ls;
    while i < e {
        int j = gen_skip_lit(b, i, n);
        if j != i {
            i = j;
        } else if is_letter(b[i]) {
            int k = gen_word(b, i, n, @word);
            int ti = gen_find_tpl(@word);
            if ti >= 0 {
                int nx = gen_blanks(b, k, n);
                if nx < n && b[nx] == '<' {
                    int ae = gen_args(b, nx, n, @args);
                    if ae > 0 {
                        // an error inside the instance is reported at the place of the use
                        int ln = line;
                        int lsx = ls;
                        int z = s;
                        while z < i {
                            if b[z] == 10 { ln += 1; lsx = z + 1; }
                            z += 1;
                        }
                        err_line = ln;
                        err_ls = lsx;
                        err_col = i - lsx + 1;
                        gen_instance(ti, @args);
                        made = 1;
                        k = ae;
                    }
                }
            }
            i = k;
        } else if is_digit(b[i]) {
            while i < e && is_alnum(b[i]) { i += 1; }
        } else {
            i += 1;
        }
    }
    err_line = keep_line;
    err_col = keep_col;
    err_ls = keep_ls;
    if made == 1 {
        // the first token was read before its instance existed: read it again
        cur_pos = s;
        cur_line = line;
        cur_line_start = ls;
        next();
    }
}

// the lexer found the identifier tok_text: is it `Name<args>` of an instance that exists?
// then the token becomes the name of the instance and the text up to the > is consumed
void gen_use() {
    if tpl_count == 0 { return; }
    int ti = gen_find_tpl(@tok_text);
    if ti < 0 { return; }
    char^ b = @src_bufs + cur_base;
    int nx = gen_blanks(b, cur_pos, cur_len);
    if nx >= cur_len || b[nx] != '<' { return; }
    char args[256];
    char key[256];
    int ae = gen_args(b, nx, cur_len, @args);
    if ae < 0 { return; }
    key[0] = 0;
    append_text(@key, @tok_text);
    append_text(@key, "<");
    append_text(@key, @args);
    append_text(@key, ">");
    int f = gen_find_ins(@key);
    if f < 0 { return; }
    while cur_pos < ae { adv(); }
    str_copy(@tok_text, @ins_name + f * 64, 256);
}

// ---------------------------------------------------------------- lambdas
//   (int a, int b) -> int { return a + b; }       a function without a name, written where it is used
// It cannot use the variables around it (it is an ordinary function that gets the name __lambda_N).
// The text of the function is kept and compiled as soon as the item that contains it is done; the
// expression itself is the address of the function (a function pointer).


// is the "(" (the current token) the start of a lambda? Looks at the text after it: a type and then a name,
// or ")" and "->"
bool lambda_ahead() {
    char^ b = @src_bufs + cur_base;
    int n = cur_len;
    int i = gen_blanks(b, cur_pos, n);
    if i < n && b[i] == ')' {
        i = gen_blanks(b, i + 1, n);
        return i + 1 < n && b[i] == '-' && b[i + 1] == '>';
    }
    char word[64];
    int e = gen_word(b, i, n, @word);
    if e == i { return false; }
    bool is_ty = str_eq(@word, "int") || str_eq(@word, "char") || str_eq(@word, "bool") || str_eq(@word, "i8") || str_eq(@word, "i32");
    if str_eq(@word, "u8") || str_eq(@word, "u32") || str_eq(@word, "u64") || str_eq(@word, "float") || str_eq(@word, "double") { is_ty = true; }
    if str_eq(@word, "f32") || str_eq(@word, "f64") || str_eq(@word, "String") { is_ty = true; }
    if find_struct(@word) >= 0 || find_enum(@word) >= 0 { is_ty = true; }
    if !is_ty { return false; }
    i = gen_blanks(b, e, n);
    while i < n && b[i] == '^' { i = gen_blanks(b, i + 1, n); }
    if i + 1 < n && b[i] == '[' && b[i + 1] == ']' { i = gen_blanks(b, i + 2, n); }
    return i < n && is_letter(b[i]);
}

int lam_ptmp[16];

// the common end of a lambda: the raw text of the return type [r_start, r_end), of the parameters [p_start, p_end)
// and of the body [b_start, b_end) become a function; the expression is its address
void lam_finish(int r_tid, int pn, int r_start, int r_end, int p_start, int p_end, int b_start, int b_end, int line) {
    char^ b = @src_bufs + cur_base;
    char name[64];
    str_copy(@name, "__lambda_", 64);
    append_int(@name, lam_seq);
    lam_seq += 1;
    int o = lam_used;
    int x = r_start;
    while x < r_end {
        lam_buf[o] = b[x];
        o += 1;
        x += 1;
    }
    lam_buf[o] = ' ';
    o += 1;
    x = 0;
    while name[x] != 0 {
        lam_buf[o] = name[x];
        o += 1;
        x += 1;
    }
    lam_buf[o] = '(';
    o += 1;
    x = p_start;
    while x < p_end {
        lam_buf[o] = b[x];
        o += 1;
        x += 1;
    }
    lam_buf[o] = ')';
    lam_buf[o + 1] = ' ';
    o += 2;
    x = b_start;
    while x < b_end {
        lam_buf[o] = b[x];
        o += 1;
        x += 1;
        if o >= 262000 { die("the lambdas are too large"); }
    }
    lam_buf[o] = 10;
    o += 1;
    lam_off[lam_count] = lam_used;
    lam_len[lam_count] = o - lam_used;
    lam_line[lam_count] = line;
    str_copy(@lam_file + lam_count * 128, @err_file, 128);
    lam_used = o;
    lam_count += 1;
    // the lexer goes on after the body
    while cur_pos < b_end && cur_pos < cur_len { adv(); }
    next();
    int k = 0;
    while k < pn {
        sg_tmp[k] = lam_ptmp[k];
        k += 1;
    }
    int sg = sig_intern(r_tid, pn);
    note_call(@name);
    emit_str("adr x0, ");
    emit_line(@name);
    ex_w = 8;
    ex_ty = 0 - sg - 1;
    rv_valid = 0;
    last_call_owning = 0;
}

// the parameters of a lambda: the token after "(" is current; leaves ")" as the current token
int lam_params() {
    int pn = 0;
    if !tok_is(")") {
        while true {
            parse_type();
            int pt = ty_tid;
            if ty_ptr != 0 { pt = 0; }
            if ty_void == 1 && ty_ptr == 0 { die("a parameter type cannot be void"); }
            if tok_kind != T_IDENT { die("a parameter name was expected"); }
            if pn >= 8 { die("a lambda has at most 8 parameters"); }
            lam_ptmp[pn] = pt;
            pn += 1;
            next();
            if tok_is(",") {
                next();
            } else {
                break;
            }
        }
    }
    if !tok_is(")") { die(") expected"); }
    return pn;
}

// the older form  (int a) -> int { ... }  : still accepted, with a warning
void gen_lambda() {
    if err_base != cur_base { die("a lambda cannot be written inside a #define"); }
    if lam_count >= 500 { die("too many lambdas in one program"); }
    if lam_warned == 0 {
        lam_warned = 1;
        warn("write a lambda like a function: int(int a, int b) { return a + b; } (the form with -> will be removed)", "deprecated");
    }
    char^ b = @src_bufs + cur_base;
    int p_start = cur_pos;               // just after the "("
    int line = err_line;
    next();
    int pn = lam_params();
    int p_end = err_ls + err_col - 1;
    next();
    if !tok_is("->") { die("-> expected: (parameters) -> type { body }"); }
    int r_start = cur_pos;
    next();
    parse_type();
    int r_tid = ty_tid;
    if ty_ptr != 0 { r_tid = 0; }
    if ty_void == 1 && ty_ptr == 0 { r_tid = 98; }
    if !tok_is("{") { die("{ expected: the body of the lambda"); }
    int r_end = err_ls + err_col - 1;
    int b_end = gen_item_end(b, r_end, cur_len);
    lam_finish(r_tid, pn, r_start, r_end, p_start, p_end, r_end, b_end, line);
}

// is the current token a type that is followed by "(" : the start of  int(int a, int b) { ... } ?
bool lambda_fn_ahead() {
    if !at_type() { return false; }
    char^ b = @src_bufs + cur_base;
    int n = cur_len;
    int i = gen_blanks(b, cur_pos, n);
    while i < n && b[i] == '^' { i = gen_blanks(b, i + 1, n); }
    return i < n && b[i] == '(';
}

// a lambda written like a function without a name:  int(int a, int b) { return a + b; }
void gen_lambda_fn() {
    if err_base != cur_base { die("a lambda cannot be written inside a #define"); }
    if lam_count >= 500 { die("too many lambdas in one program"); }
    char^ b = @src_bufs + cur_base;
    int r_start = err_ls + err_col - 1;
    int line = err_line;
    int sv_fn = parse_fn_type_ok;
    parse_fn_type_ok = 0;                // the "(" after the type starts the parameters, not a function pointer type
    parse_type();
    parse_fn_type_ok = sv_fn;
    int r_tid = ty_tid;
    if ty_ptr != 0 { r_tid = 0; }
    if ty_void == 1 && ty_ptr == 0 { r_tid = 98; }
    int r_end = err_ls + err_col - 1;
    if !tok_is("(") { die("( expected: the parameters of the lambda"); }
    int p_start = cur_pos;
    next();
    int pn = lam_params();
    int p_end = err_ls + err_col - 1;
    next();
    if !tok_is("{") { die("{ expected: the body of the lambda"); }
    int b_start = err_ls + err_col - 1;
    int b_end = gen_item_end(b, b_start, cur_len);
    lam_finish(r_tid, pn, r_start, r_end, p_start, p_end, b_start, b_end, line);
}

// compile the lambdas that were written since the last call
void gen_lambdas() {
    while lam_done < lam_count {
        int i = lam_done;
        lam_done += 1;
        int d = lx_depth;
        gen_save(d);
        push_text(@lam_buf + lam_off[i], lam_len[i], @lam_file + i * 128, lam_line[i]);
        next();
        while tok_kind != T_EOF { parse_one_item(); }
        pop_file();
        gen_restore(d);
    }
}

// ------------------------------------------------- Name(args) : T worked out from the arguments
//   largest(3, 9)     swap(@x, @y)     first(names)
// The text of the arguments is read before they are compiled. An argument can be a number, a char, a text,
// true / false, a variable or @variable; the type of a variable is known from its declaration. T comes from a
// parameter written T, T^ or T[] (or T name[]); a whole number follows the variable beside it (else it is an
// int), a decimal number is a double. A type that does not fit is an error; so is a T that no parameter shows
// (write Name<T>(...)). Struct generics are always written with <>.

int ia_n;
int ia_s[16];
int ia_e[16];
int ia_class[16];            // 0 a type (in ia_text), 1 a whole number, 2 a decimal number
char ia_text[2048];          // 16 x 128
int tp_n;
int tp_mode[16];             // 0 T  1 T^  2 T[]  3 T name[]  -1 something else
int tp_q[16];                // which template parameter
char bd_text[1024];          // 8 x 128: what each template parameter is bound to
int bd_n[8];
int bd_w[8];
int bd_d[8];

bool gen_is_template(char^ name) {
    return gen_find_tpl(name) >= 0;
}

// the name of a type from a width code and a type id (false if it has none)
bool code_text(int code, int tid, char^ out) {
    out[0] = 0;
    if tid < 0 { return false; }
    if tid >= 3 && tid <= 66 {
        if tid - 3 >= ecount { return false; }
        str_copy(out, @ename + (tid - 3) * 64, 64);
        return true;
    }
    if tid == 1 { str_copy(out, "bool", 8); return true; }
    if tid == 90 { str_copy(out, "float", 8); return true; }
    if tid == 91 { str_copy(out, "double", 8); return true; }
    if tid == 93 { str_copy(out, "u8", 8); return true; }
    if tid == 94 { str_copy(out, "u32", 8); return true; }
    if tid == 95 { str_copy(out, "u64", 8); return true; }
    if code == 1 { str_copy(out, "i8", 8); return true; }
    if code == 2 { str_copy(out, "char", 8); return true; }
    if code == 3 { str_copy(out, "bool", 8); return true; }
    if code == 4 { str_copy(out, "i32", 8); return true; }
    if code == 6 { str_copy(out, "float", 8); return true; }
    if code == 7 { str_copy(out, "double", 8); return true; }
    if code == 8 { str_copy(out, "int", 8); return true; }
    if code == 11 { str_copy(out, "u8", 8); return true; }
    if code == 12 { str_copy(out, "u32", 8); return true; }
    if code == 13 { str_copy(out, "u64", 8); return true; }
    if code >= 16 && code < 100 { str_copy(out, @sname + (code - 16) * 64, 64); return true; }
    return false;
}

// what a pointer with this pointee code points at
bool pointee_text(int p, char^ out) {
    out[0] = 0;
    if p == 10 { return false; }
    if p >= 100 {
        if !pointee_text(p - 100, out) { return false; }
        append_text(out, "^");
        return true;
    }
    return code_text(p, pointee_tid(p), out);
}

// the type of the variable that lookup_var just found, as the text of a type
bool var_type_text(char^ out) {
    char tmp[128];
    out[0] = 0;
    if v_kind == 3 {
        int info = v_dyn;
        if is_str_dyn(info) { str_copy(out, "String", 128); return true; }
        if is_strarr_dyn(info) { str_copy(out, "String[]", 128); return true; }
        if dyn_ptr(info) != 0 {
            if !pointee_text(dyn_ptr(info), @tmp) { return false; }
            append_text(@tmp, "^");
        } else {
            if !code_text(dyn_code(info), dyn_tid(info), @tmp) { return false; }
        }
        str_copy(out, @tmp, 128);
        append_text(out, "[]");
        return true;
    }
    if v_kind == 1 {
        if !code_text(v_elem, v_tid, @tmp) { return false; }
        str_copy(out, @tmp, 128);
        append_text(out, "[]");
        return true;
    }
    if v_kind != 0 { return false; }
    if v_ptr != 0 {
        if !pointee_text(v_ptr, @tmp) { return false; }
        str_copy(out, @tmp, 128);
        append_text(out, "^");
        return true;
    }
    return code_text(v_elem, v_tid, out);
}

// argument number idx is b[s..e): a number, a char, a text, true/false, a variable or @variable?
bool classify_arg(char^ b, int s, int e, int idx) {
    char^ out = @ia_text + idx * 128;
    out[0] = 0;
    ia_class[idx] = 0;
    s = gen_blanks(b, s, e);
    while e > s && is_space(b[e - 1]) { e -= 1; }
    if s >= e { return false; }
    int c = b[s];
    if is_digit(c) || (c == '-' && s + 1 < e && is_digit(b[s + 1])) {
        int k = s;
        if c == '-' { k += 1; }
        int dec = 0;
        if b[k] == '0' && k + 1 < e && (b[k + 1] == 'x' || b[k + 1] == 'X' || b[k + 1] == 'b' || b[k + 1] == 'B') {
            k += 2;
            while k < e && is_alnum(b[k]) { k += 1; }
        } else {
            while k < e && is_digit(b[k]) { k += 1; }
            if k < e && b[k] == '.' {
                dec = 1;
                k += 1;
                while k < e && is_digit(b[k]) { k += 1; }
            }
            if k < e && (b[k] == 'e' || b[k] == 'E') {
                dec = 1;
                k += 1;
                if k < e && (b[k] == '-' || b[k] == '+') { k += 1; }
                while k < e && is_digit(b[k]) { k += 1; }
            }
        }
        if k != e { return false; }
        ia_class[idx] = 1 + dec;
        return true;
    }
    if c == '"' {
        if gen_skip_lit(b, s, e) != e { return false; }
        str_copy(out, "char^", 128);
        return true;
    }
    if c == 39 {
        if gen_skip_lit(b, s, e) != e { return false; }
        str_copy(out, "char", 128);
        return true;
    }
    int at = 0;
    if c == '@' {
        at = 1;
        s = gen_blanks(b, s + 1, e);
    }
    char word[64];
    int we = gen_word(b, s, e, @word);
    if we == s || we != e || !is_letter(b[s]) { return false; }
    if at == 0 && (str_eq(@word, "true") || str_eq(@word, "false")) {
        str_copy(out, "bool", 128);
        return true;
    }
    if !lookup_var(@word) { return false; }
    if !var_type_text(out) { return false; }
    if at == 1 {
        int ol = str_len(out);
        if ol > 2 && out[ol - 1] == ']' && out[ol - 2] == '[' {
            out[ol - 2] = 0;                 // @array points at its first element
        }
        append_text(out, "^");
    }
    return true;
}

// the types of the parameters of template ti (how each one uses a template parameter)
void template_params(int ti) {
    char^ t = @tpl_text + tpl_off[ti];
    int n = tpl_len[ti];
    char skip[256];
    char tmp[256];
    char word[64];
    tp_n = 0;
    int i = 0;
    int pos = 0 - 1;
    while i < n {
        int j = gen_skip_lit(t, i, n);
        if j != i {
            i = j;
        } else if is_letter(t[i]) {
            int k = gen_word(t, i, n, @word);
            int nx = gen_blanks(t, k, n);
            if str_eq(@word, @tpl_name + ti * 64) && nx < n && t[nx] == '<' {
                pos = nx;
                break;
            }
            i = k;
        } else {
            i += 1;
        }
    }
    if pos < 0 { return; }
    int e = gen_args(t, pos, n, @skip);
    if e < 0 { return; }
    e = gen_blanks(t, e, n);
    if e >= n || t[e] != '(' { return; }
    e += 1;
    int ps = e;
    int depth = 0;
    while e < n {
        int c = t[e];
        int j = gen_skip_lit(t, e, n);
        if j != e {
            e = j;
        } else {
            bool last = false;
            if c == '(' || c == '[' { depth += 1; }
            if (c == ')' || c == ']') && depth > 0 { depth -= 1; } else if c == ')' { last = true; }
            if c == ',' && depth == 0 { last = true; }
            if last {
                // the parameter is t[ps..e)
                int pe = e;
                while pe > ps && is_space(t[pe - 1]) { pe -= 1; }
                int ws = ps;
                while ws < pe && is_space(t[ws]) { ws += 1; }
                if ws >= pe {
                    if c == ')' { return; }       // no parameters
                    ps = e + 1;
                    e += 1;
                    continue;
                }
                int arr = 0;
                if pe > ps && t[pe - 1] == ']' {
                    arr = 1;
                    while pe > ps && t[pe - 1] != '[' { pe -= 1; }
                    pe -= 1;
                    while pe > ps && is_space(t[pe - 1]) { pe -= 1; }
                }
                int nb = pe;
                while nb > ps && is_alnum(t[nb - 1]) { nb -= 1; }
                // the type is t[ps..nb) without blanks
                int tn = 0;
                int x = ps;
                while x < nb && tn < 250 {
                    if !is_space(t[x]) { tmp[tn] = t[x]; tn += 1; }
                    x += 1;
                }
                tmp[tn] = 0;
                if tp_n < 16 {
                    tp_mode[tp_n] = 0 - 1;
                    tp_q[tp_n] = 0;
                    int q = 0;
                    while q < tpl_np[ti] {
                        char^ pn = @tpl_par + (ti * 8 + q) * 64;
                        int pl = str_len(pn);
                        int m = 0 - 1;
                        if str_eq(@tmp, pn) {
                            m = 0;
                            if arr == 1 { m = 3; }
                        } else if tn == pl + 1 && tmp[pl] == '^' && str_eq_n(@tmp, pn, pl) {
                            m = 1;
                        } else if tn == pl + 2 && tmp[pl] == '[' && tmp[pl + 1] == ']' && str_eq_n(@tmp, pn, pl) {
                            m = 2;
                        }
                        if m >= 0 {
                            tp_mode[tp_n] = m;
                            tp_q[tp_n] = q;
                        }
                        q += 1;
                    }
                    tp_n += 1;
                }
                if c == ')' { return; }
                ps = e + 1;
            }
            e += 1;
        }
    }
}

bool str_eq_n(char^ a, char^ b, int n) {
    int i = 0;
    while i < n {
        if a[i] != b[i] { return false; }
        i += 1;
    }
    return true;
}

bool is_integer_type(char^ t) {
    return str_eq(t, "int") || str_eq(t, "i8") || str_eq(t, "i32") || str_eq(t, "u8") || str_eq(t, "u32") || str_eq(t, "u64");
}

void bind_param(int ti, int q, char^ text) {
    char^ cur = @bd_text + q * 128;
    if bd_n[q] == 0 {
        str_copy(cur, text, 128);
        bd_n[q] = 1;
        return;
    }
    if str_eq(cur, text) { return; }
    char m[300];
    str_copy(@m, "cannot work out ", 300);
    append_text(@m, @tpl_par + (ti * 8 + q) * 64);
    append_text(@m, ": it is both ");
    append_text(@m, cur);
    append_text(@m, " and ");
    append_text(@m, text);
    append_text(@m, " (cast one of them, or write the type: ");
    append_text(@m, @tpl_name + ti * 64);
    append_text(@m, "<...>(...))");
    die(@m);
}

// Name(args): the instance is entered and queued; id_name becomes its name. The current token is "(".
void gen_infer_call() {
    int ti = gen_find_tpl(@id_name);
    if err_base != cur_base { die("a call of a generic without <...> cannot be inside a #define"); }
    char^ b = @src_bufs + cur_base;
    int n = cur_len;
    // the arguments: b[i..) up to the matching )
    ia_n = 0;
    int i = gen_blanks(b, cur_pos, n);
    if i < n && b[i] != ')' {
        int depth = 0;
        int s = i;
        while i < n {
            int j = gen_skip_lit(b, i, n);
            if j != i {
                i = j;
            } else {
                int c = b[i];
                if c == '(' || c == '[' || c == '{' { depth += 1; }
                bool end = false;
                if (c == ')' || c == ']' || c == '}') {
                    if depth == 0 { end = true; } else { depth -= 1; }
                }
                if c == ',' && depth == 0 { end = true; }
                if end {
                    if ia_n >= 16 { die("too many arguments"); }
                    ia_s[ia_n] = s;
                    ia_e[ia_n] = i;
                    ia_n += 1;
                    if c == ')' { break; }
                    s = i + 1;
                }
                i += 1;
            }
        }
    }
    template_params(ti);
    char^ name = @tpl_name + ti * 64;
    if ia_n != tp_n { die_name("wrong number of arguments for the generic", name); }
    int q = 0;
    while q < 8 {
        bd_n[q] = 0;
        bd_w[q] = 0;
        bd_d[q] = 0;
        q += 1;
    }
    int a = 0;
    while a < ia_n {
        if !classify_arg(b, ia_s[a], ia_e[a], a) {
            char m[300];
            str_copy(@m, "cannot work out the types of the arguments of ", 300);
            append_text(@m, name);
            append_text(@m, ": write them, ");
            append_text(@m, name);
            append_text(@m, "<type>(...)");
            die(@m);
        }
        int mode = tp_mode[a];
        int pq = tp_q[a];
        if mode >= 0 {
            char^ at = @ia_text + a * 128;
            if ia_class[a] == 1 && mode == 0 {
                bd_w[pq] = 1;
            } else if ia_class[a] == 2 && mode == 0 {
                bd_d[pq] = 1;
            } else if ia_class[a] != 0 {
                die_name("this argument needs a pointer or an array: write the type", name);
            } else if mode == 0 {
                bind_param(ti, pq, at);
            } else {
                char tt[128];
                str_copy(@tt, at, 128);
                int tl = str_len(@tt);
                if mode == 1 {
                    if tl < 2 || tt[tl - 1] != '^' { die_name("this argument must be a pointer", name); }
                    tt[tl - 1] = 0;
                } else {
                    if tl < 3 || tt[tl - 1] != ']' || tt[tl - 2] != '[' { die_name("this argument must be an array", name); }
                    tt[tl - 2] = 0;
                }
                bind_param(ti, pq, @tt);
            }
        }
        a += 1;
    }
    char args[256];
    args[0] = 0;
    q = 0;
    while q < tpl_np[ti] {
        char^ pn = @tpl_par + (ti * 8 + q) * 64;
        if bd_n[q] == 1 {
            char^ bt = @bd_text + q * 128;
            if bd_d[q] == 1 && !(str_eq(bt, "float") || str_eq(bt, "double")) { die_name("a decimal number does not fit this type (write 2.0 only for float / double)", name); }
            if bd_w[q] == 1 && !is_integer_type(bt) { die_name("a whole number does not fit this type (write 2.0 for float / double)", name); }
        } else if bd_w[q] == 1 && bd_d[q] == 1 {
            die_name("cannot work out the type: a whole number and a decimal number (write the type)", name);
        } else if bd_d[q] == 1 {
            str_copy(@bd_text + q * 128, "double", 128);
            bd_n[q] = 1;
        } else if bd_w[q] == 1 {
            str_copy(@bd_text + q * 128, "int", 128);
            bd_n[q] = 1;
        } else {
            char m[300];
            str_copy(@m, "cannot work out ", 300);
            append_text(@m, pn);
            append_text(@m, " from the arguments: write ");
            append_text(@m, name);
            append_text(@m, "<type>(...)");
            die(@m);
        }
        if q > 0 { append_text(@args, ","); }
        append_text(@args, @bd_text + q * 128);
        q += 1;
    }
    int ins = gen_register(ti, @args);
    str_copy(@id_name, @ins_name + ins * 64, 256);
}
