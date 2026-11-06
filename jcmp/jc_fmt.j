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
i64 fmt_text(i64 n) {
    i64 o = 0;
    i64 i = 0;
    i64 blank = 0;
    while i < n {
        i64 s = i;
        while i < n && fmt_in[i] != 10 { i += 1; }
        i64 e = i;
        if i < n { i += 1; }
        if e > s && fmt_in[e - 1] == 13 { e -= 1; }
        while e > s && (fmt_in[e - 1] == 32 || fmt_in[e - 1] == 9) { e -= 1; }
        if e == s {
            blank += 1;
        } else {
            if o > 0 && blank > 0 && o + 2 < 4194300 { fmt_out[o] = 10; o += 1; }
            blank = 0;
            i64 k = s;
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
i64 fmt_file(char^ path, i64 mode) {
    i64 n = read_file(path, @fmt_in, 4194304);
    if n < 0 { return 0 - 1; }
    i64 m = fmt_text(n);
    bool same = m == n;
    if same {
        i64 k = 0;
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
i64 fmt_main(i64 first) {
    i64 mode = 0;
    i64 changed = 0;
    i64 bad = 0;
    i64 ai = first;
    i64 files = 0;
    while ai < argc() {
        char^ a = arg(ai);
        if str_eq(a, "-c") { mode = 1; }
        else if str_eq(a, "-p") { mode = 2; }
        else {
            files += 1;
            i64 r = fmt_file(a, mode);
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
i64 mig_word(i64 at, i64 n) {
    // the length of the word at fmt_in[at] if it is cout, cin or cerr as a whole word, else 0
    if at > 0 {
        i64 pc = fmt_in[at - 1];
        if (pc >= 'a' && pc <= 'z') || (pc >= 'A' && pc <= 'Z') || (pc >= '0' && pc <= '9') || pc == '_' || pc == '.' { return 0; }
    }
    i64 len = 0;
    if at + 4 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'o' && fmt_in[at + 2] == 'u' && fmt_in[at + 3] == 't' { len = 4; }
    else if at + 4 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'e' && fmt_in[at + 2] == 'r' && fmt_in[at + 3] == 'r' { len = 4; }
    else if at + 3 <= n && fmt_in[at] == 'c' && fmt_in[at + 1] == 'i' && fmt_in[at + 2] == 'n' { len = 3; }
    if len == 0 { return 0; }
    if at + len < n {
        i64 nc = fmt_in[at + len];
        if (nc >= 'a' && nc <= 'z') || (nc >= 'A' && nc <= 'Z') || (nc >= '0' && nc <= '9') || nc == '_' { return 0; }
    }
    return len;
}

i64 mig_text(i64 n) {
    i64 o = 0;
    i64 i = 0;
    while i < n {
        i64 c = fmt_in[i];
        if c == '"' || c == 39 {
            // a string or a character: copied as it is, up to the closing mark (a backslash protects the next one)
            i64 q = c;
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
            i64 len = mig_word(i, n);
            if len > 0 {
                fmt_out[o] = 'j'; o += 1;
                i64 k = 1;
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

i64 migrate_main(i64 first) {
    bool check = false;
    i64 changed = 0;
    i64 files = 0;
    i64 bad = 0;
    i64 ai = first;
    while ai < argc() {
        char^ a = arg(ai);
        if str_eq(a, "-c") { check = true; }
        else {
            files += 1;
            i64 n = read_file(a, @fmt_in, 4194304);
            if n < 0 { write_err("jcmp migrate: cannot read "); write_err(a); write_err("\n"); bad = 1; }
            else {
                i64 m = mig_text(n);
                bool same = m == n;
                if same { i64 k = 0; while k < n { if fmt_in[k] != fmt_out[k] { same = false; break; } k += 1; } }
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
