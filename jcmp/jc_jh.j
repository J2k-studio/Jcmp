// jc_jh.j -- the interface file of a module (docs/design/16-separate-compilation.md, docs/syntax-design.md 80): jcmp -jh FILE
// It is the file as the other modules see it: the directives, the declarations of globals and functions (the header of each function, the body gone), the structs and
// enums with their fields and the headers of their methods; the comments in front of them stay. The first line holds the version of the compiler and two hashes
// (of the source and of the interface), so that a tool can tell "the interface changed" from "only a body changed".
// This is text made by reading the source (not by the checking of the compiler), so it shows the names and types as they were written.

char jh_in[4194304];
char jh_out[2097152];
char jh_pend[262144];
int jh_n;                      // the length of the source
int jh_o;                      // the length of the interface
int jh_p;                      // the length of the text that waits (pend)

void jh_put(int c) {
    if jh_o < 2097000 {
        jh_out[jh_o] = c;
        jh_o += 1;
    }
}

void jh_puts(char^ t) {
    int k = 0;
    while t[k] != 0 {
        jh_put(t[k]);
        k += 1;
    }
}

void jh_pend_add(int c) {
    if jh_p < 262000 {
        jh_pend[jh_p] = c;
        jh_p += 1;
    }
}

// the text that waits goes to the interface; extra is added after it (";" for a function whose body is left out)
void jh_flush(char^ extra) {
    // the end of the text: no blanks
    int e = jh_p;
    while e > 0 && (jh_pend[e - 1] == ' ' || jh_pend[e - 1] == 9 || jh_pend[e - 1] == 10 || jh_pend[e - 1] == 13) { e -= 1; }
    // the start: at most one empty line before it
    int s = 0;
    int nl = 0;
    while s < e && (jh_pend[s] == ' ' || jh_pend[s] == 9 || jh_pend[s] == 10 || jh_pend[s] == 13) {
        if jh_pend[s] == 10 { nl += 1; }
        s += 1;
    }
    // keep the indentation of the first line
    int back = s;
    while back > 0 && jh_pend[back - 1] != 10 { back -= 1; }
    if e > s {
        if nl > 1 && jh_o > 0 { jh_put(10); }
        int k = back;
        while k < e {
            jh_put(jh_pend[k]);
            k += 1;
        }
        jh_puts(extra);
        jh_put(10);
    }
    jh_p = 0;
}

// the first word of the waiting text, after blanks and comments: is it struct / enum / union / class ?
bool jh_pend_is_type() {
    int k = 0;
    while k < jh_p {
        int c = jh_pend[k];
        if c == ' ' || c == 9 || c == 10 || c == 13 { k += 1; }
        else if c == '/' && k + 1 < jh_p && jh_pend[k + 1] == '/' {
            while k < jh_p && jh_pend[k] != 10 { k += 1; }
        } else if c == '/' && k + 1 < jh_p && jh_pend[k + 1] == '*' {
            k += 2;
            while k + 1 < jh_p && !(jh_pend[k] == '*' && jh_pend[k + 1] == '/') { k += 1; }
            k += 2;
        } else { break; }
    }
    char w[12];
    int n = 0;
    while k < jh_p && n < 10 && ((jh_pend[k] >= 'a' && jh_pend[k] <= 'z') || (jh_pend[k] >= 'A' && jh_pend[k] <= 'Z')) {
        w[n] = jh_pend[k];
        n += 1;
        k += 1;
    }
    w[n] = 0;
    return str_eq(@w, "struct") || str_eq(@w, "enum") || str_eq(@w, "union") || str_eq(@w, "class");
}

// i is at a { : the position after the matching }
int jh_skip_body(int i) {
    int depth = 0;
    while i < jh_n {
        int c = jh_in[i];
        if c == '"' {
            i += 1;
            while i < jh_n && jh_in[i] != '"' {
                if jh_in[i] == 92 { i += 1; }
                i += 1;
            }
        } else if c == 39 {
            i += 1;
            while i < jh_n && jh_in[i] != 39 {
                if jh_in[i] == 92 { i += 1; }
                i += 1;
            }
        } else if c == '/' && i + 1 < jh_n && jh_in[i + 1] == '/' {
            while i < jh_n && jh_in[i] != 10 { i += 1; }
            continue;
        } else if c == '/' && i + 1 < jh_n && jh_in[i + 1] == '*' {
            i += 2;
            while i + 1 < jh_n && !(jh_in[i] == '*' && jh_in[i + 1] == '/') { i += 1; }
            i += 1;
        } else if c == '{' {
            depth += 1;
        } else if c == '}' {
            depth -= 1;
            if depth == 0 { return i + 1; }
        }
        i += 1;
    }
    return i;
}

int jh_hash(char^ b, int n) {
    int h = 1469598103934665603;
    int i = 0;
    while i < n {
        h = (h xor (b[i] & 255)) * 1099511628211;
        i += 1;
    }
    return h;
}

// the interface of the source in jh_in
void jh_make() {
    jh_o = 0;
    jh_p = 0;
    int depth = 0;
    int i = 0;
    bool line_start = true;
    while i < jh_n {
        int c = jh_in[i];
        // a directive at the start of a line, at the top: copied as it is
        if c == '#' && depth == 0 && line_start && jh_p == 0 {
            while i < jh_n && jh_in[i] != 10 {
                jh_put(jh_in[i]);
                i += 1;
            }
            jh_put(10);
            continue;
        }
        if c == 10 { line_start = true; } else if c != ' ' && c != 9 { line_start = false; }
        if c == '/' && i + 1 < jh_n && jh_in[i + 1] == '/' {
            while i < jh_n && jh_in[i] != 10 {
                jh_pend_add(jh_in[i]);
                i += 1;
            }
            continue;
        }
        if c == '/' && i + 1 < jh_n && jh_in[i + 1] == '*' {
            jh_pend_add('/');
            jh_pend_add('*');
            i += 2;
            while i + 1 < jh_n && !(jh_in[i] == '*' && jh_in[i + 1] == '/') {
                jh_pend_add(jh_in[i]);
                i += 1;
            }
            jh_pend_add('*');
            jh_pend_add('/');
            i += 2;
            continue;
        }
        if c == '"' || c == 39 {
            int q = c;
            jh_pend_add(c);
            i += 1;
            while i < jh_n && jh_in[i] != q {
                if jh_in[i] == 92 {
                    jh_pend_add(jh_in[i]);
                    i += 1;
                }
                jh_pend_add(jh_in[i]);
                i += 1;
            }
            jh_pend_add(q);
            i += 1;
            continue;
        }
        if c == ';' {
            jh_pend_add(';');
            jh_flush("");
            i += 1;
            continue;
        }
        if c == '{' {
            if depth == 0 && jh_pend_is_type() {
                jh_pend_add('{');
                depth = 1;
                i += 1;
                continue;
            }
            // the body of a function or of a method: its header stays, the body goes
            jh_flush(";");
            i = jh_skip_body(i);
            continue;
        }
        if c == '}' && depth == 1 {
            jh_pend_add('}');
            jh_flush("");
            depth = 0;
            i += 1;
            if i < jh_n && jh_in[i] == ';' { i += 1; }
            continue;
        }
        jh_pend_add(c);
        i += 1;
    }
    jh_flush("");
}

// jcmp -jh FILE : the interface of FILE on the standard output (or in out)
void jh_run(char^ path, char^ out) {
    jh_n = read_file(path, @jh_in, 4194000);
    if jh_n < 0 { die_file(path); }
    jh_in[jh_n] = 0;
    jh_make();
    int src = jh_hash(@jh_in, jh_n);
    int itf = jh_hash(@jh_out, jh_o);
    char head[200];
    head[0] = 0;
    append_text(@head, "// jh 1  compiler ");
    append_text(@head, JCMP_VERSION);
    append_text(@head, "  source ");
    char hx[20];
    cc_hex(src, @hx);
    hx[16] = 0;
    append_text(@head, @hx);
    append_text(@head, "  interface ");
    cc_hex(itf, @hx);
    hx[16] = 0;
    append_text(@head, @hx);
    append_text(@head, "\n");
    if out == null {
        write_out(@head);
        syscall(64, 1, @jh_out, jh_o);
    } else {
        int hl = str_len(@head);
        int k = 0;
        while k < jh_o && hl + k < 190 { k += 1; }
        // the head and the text are written into one file
        int fd = syscall(56, -100, out, 577, 420);
        if fd < 0 { die_file(out); }
        syscall(64, fd, @head, hl);
        syscall(64, fd, @jh_out, jh_o);
        syscall(57, fd);
    }
}
