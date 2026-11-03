// jc_fmt.j -- jcmp fmt: the formatter. It changes only white space, never the meaning of a program:
//   - the line ends are \n (a \r before it is dropped);  - no space or tab at the end of a line;  - a tab at the start of a line is 4 spaces;
//   - at most one empty line in a row, none at the start of the file;  - the file ends with exactly one \n.
// jcmp fmt FILE...     write the formatted text back (a file that is already formatted is not touched)
// jcmp fmt -c FILE...  only check: say which files would change and stop with 1 if there is one
// jcmp fmt -p FILE     print the formatted text on the standard output
// Applying it twice gives the same text (tested on every file of test/, std/ and jcmp/).

char fmt_in[4194304];
char fmt_out[4194304];

// the formatted text of fmt_in[0..n) goes to fmt_out; returns its length
int fmt_text(int n) {
    int o = 0;
    int i = 0;
    int blank = 0;
    while i < n {
        int s = i;
        while i < n && fmt_in[i] != 10 { i += 1; }
        int e = i;
        if i < n { i += 1; }
        if e > s && fmt_in[e - 1] == 13 { e -= 1; }
        while e > s && (fmt_in[e - 1] == 32 || fmt_in[e - 1] == 9) { e -= 1; }
        if e == s {
            blank += 1;
        } else {
            if o > 0 && blank > 0 && o + 2 < 4194300 { fmt_out[o] = 10; o += 1; }
            blank = 0;
            int k = s;
            while k < e && fmt_in[k] == 9 && o + 4 < 4194300 {
                fmt_out[o] = 32; fmt_out[o + 1] = 32; fmt_out[o + 2] = 32; fmt_out[o + 3] = 32;
                o += 4;
                k += 1;
            }
            while k < e && o + 2 < 4194300 { fmt_out[o] = fmt_in[k]; o += 1; k += 1; }
            fmt_out[o] = 10;
            o += 1;
        }
    }
    return o;
}

// mode 0: write back, 1: check, 2: print. Returns 0 (not changed), 1 (changed or would change), -1 (cannot read or write)
int fmt_file(char^ path, int mode) {
    int n = read_file(path, @fmt_in, 4194304);
    if n < 0 { return 0 - 1; }
    int m = fmt_text(n);
    bool same = m == n;
    if same {
        int k = 0;
        while k < n { if fmt_in[k] != fmt_out[k] { same = false; break; } k += 1; }
    }
    if mode == 2 {
        syscall(64, 1, @fmt_out, m);
        return 0;
    }
    if same { return 0; }
    if mode == 1 { return 1; }
    if write_file(path, @fmt_out, m) < 0 { return 0 - 1; }
    return 1;
}

// jcmp fmt [-c|-p] FILE...  (first = the index of the first argument after "fmt")
int fmt_main(int first) {
    int mode = 0;
    int changed = 0;
    int bad = 0;
    int ai = first;
    int files = 0;
    while ai < argc() {
        char^ a = arg(ai);
        if str_eq(a, "-c") { mode = 1; }
        else if str_eq(a, "-p") { mode = 2; }
        else {
            files += 1;
            int r = fmt_file(a, mode);
            if r < 0 {
                write_err("jcmp fmt: cannot read or write ");
                write_err(a);
                write_err("\n");
                bad = 1;
            } else if r == 1 {
                changed += 1;
                if mode == 1 { write_out(a); write_out(": would change\n"); }
                else { write_out(a); write_out(": formatted\n"); }
            }
        }
        ai += 1;
    }
    if files == 0 { write_err("usage: jcmp fmt [-c | -p] FILE...\n"); return 2; }
    if bad == 1 { return 2; }
    if mode == 1 && changed > 0 { return 1; }
    return 0;
}

// jcmp migrate [-c] FILE...: cout -> jout, cin -> jin, cerr -> jerr (and coutf, cinf are left) in the code of a file: not inside a string, a character or a comment.
// -c only says which files would change. Prints one line for each file that changes.
int mig_word(int at, int n) {
    // the length of the word at fmt_in[at] if it is cout, cin or cerr as a whole word, else 0
    if at > 0 {
        int pc = fmt_in[at - 1];
        if (pc >= 'a' && pc <= 'z') || (pc >= 'A' && pc <= 'Z') || (pc >= '0' && pc <= '9') || pc == '_' || pc == '.' { return 0; }
    }
    int len = 0;
    if at + 4 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'o' && fmt_in[at + 2] == 'u' && fmt_in[at + 3] == 't' { len = 4; }
    else if at + 4 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'e' && fmt_in[at + 2] == 'r' && fmt_in[at + 3] == 'r' { len = 4; }
    else if at + 3 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'i' && fmt_in[at + 2] == 'n' { len = 3; }
    if len == 0 { return 0; }
    if at + len < n {
        int nc = fmt_in[at + len];
        if (nc >= 'a' && nc <= 'z') || (nc >= 'A' && nc <= 'Z') || (nc >= '0' && nc <= '9') || nc == '_' { return 0; }
    }
    return len;
}

int mig_text(int n) {
    int o = 0;
    int i = 0;
    while i < n {
        int c = fmt_in[i];
        if c == '"' || c == 39 {
            // a string or a character: copied as it is, up to the closing mark (a backslash protects the next one)
            int q = c;
            fmt_out[o] = c; o += 1; i += 1;
            while i < n && fmt_in[i] != q && fmt_in[i] != 10 {
                if fmt_in[i] == 92 && i + 1 < n { fmt_out[o] = fmt_in[i]; o += 1; i += 1; }
                fmt_out[o] = fmt_in[i]; o += 1; i += 1;
            }
            if i < n && fmt_in[i] == q { fmt_out[o] = q; o += 1; i += 1; }
            continue;
        }
        if c == '/' && i + 1 < n && fmt_in[i + 1] == '/' {
            while i < n && fmt_in[i] != 10 { fmt_out[o] = fmt_in[i]; o += 1; i += 1; }
            continue;
        }
        if c == 'c' {
            int len = mig_word(i, n);
            if len > 0 {
                fmt_out[o] = 'j'; o += 1;
                int k = 1;
                while k < len { fmt_out[o] = fmt_in[i + k]; o += 1; k += 1; }
                i += len;
                continue;
            }
        }
        fmt_out[o] = c; o += 1; i += 1;
        if o > 4194200 { break; }
    }
    return o;
}

int migrate_main(int first) {
    bool check = false;
    int changed = 0;
    int files = 0;
    int bad = 0;
    int ai = first;
    while ai < argc() {
        char^ a = arg(ai);
        if str_eq(a, "-c") { check = true; }
        else {
            files += 1;
            int n = read_file(a, @fmt_in, 4194304);
            if n < 0 { write_err("jcmp migrate: cannot read "); write_err(a); write_err("\n"); bad = 1; }
            else {
                int m = mig_text(n);
                bool same = m == n;
                if same { int k = 0; while k < n { if fmt_in[k] != fmt_out[k] { same = false; break; } k += 1; } }
                if !same {
                    changed += 1;
                    write_out(a);
                    if check { write_out(": would change\n"); }
                    else {
                        if write_file(a, @fmt_out, m) < 0 { write_err("jcmp migrate: cannot write "); write_err(a); write_err("\n"); bad = 1; }
                        else { write_out(": migrated\n"); }
                    }
                }
            }
        }
        ai += 1;
    }
    if files == 0 { write_err("usage: jcmp migrate [-c] FILE...\n"); return 2; }
    if bad == 1 { return 2; }
    if check && changed > 0 { return 1; }
    return 0;
}
