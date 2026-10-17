// The cache of the back end (docs/design/16-separate-compilation.md, stage A).
// A function of the code pass has a key: a hash of its text with the numbers of the local labels (L123) renumbered in order of
// appearance, mixed with the same hash of every function it can call (the inliner reads their bodies).
// -xcachestat DIR only counts how many keys are already in DIR/keys.txt and adds the new ones; nothing else changes.
// -cache DIR uses the cache: a function whose key has a file DIR/<key>.fn takes its final text from there and the back end skips it;
// the other functions run the back end as usual and are stored. The text of a function is cut out with the marker lines ;F n and ;E n.

int cc_h[8192];               // hash of the text of the function
int cc_nh[8192];              // hash of its name
int cc_key[8192];             // the key (text + everything it calls + the options)
int cc_from[8192];            // first line of the function in out_buf
int cc_to[8192];              // end (after the last line)
int cc_e0[8192];              // its calls: index of the first one in cc_edge
int cc_e1[8192];
int cc_edge[262144];          // index of a function whose name appears in the text
int cc_okf[8192];             // 1: the function can be cached (its labels are all its own)
int cc_hit[8192];             // 1: its final text is in the cache
int cc_emark[8192];
int cc_tab[32768];            // hash of a function name -> index + 1
int cc_n;
int cc_ne;
int cc_seen[8192];
int cc_stamp;
int cc_stack[8192];
int cc_lnum[8192];
int cc_ldef[8192];
int cc_ln;
int cc_flags;
int cc_fresh;
int cc_wlen;
int cc_hits;
int cc_stored;
char cc_fbuf[4194304];

int cc_mix(int h, int v) {
    int x = (h xor v) * 1099511628211;
    return x xor (x >> 29);
}

bool cc_alnum(int c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

// a label token: L and digits only; returns the end of the token or -1
int cc_label_end(char^ b, int i, int lim) {
    if b[i] != 'L' || i + 1 >= lim || b[i + 1] < '0' || b[i + 1] > '9' { return -1; }
    int j = i + 1;
    while j < lim && b[j] >= '0' && b[j] <= '9' { j += 1; }
    if j < lim && cc_alnum(b[j]) { return -1; }
    return j;
}

int cc_ordinal(int num) {
    int k = 0;
    while k < cc_ln {
        if cc_lnum[k] == num { return k; }
        k += 1;
    }
    if cc_ln >= 8192 { return -1; }
    cc_lnum[cc_ln] = num;
    cc_ldef[cc_ln] = 0;
    cc_ln += 1;
    return cc_ln - 1;
}

int cc_lookup(int th) {
    int s = (th >> 3) & 32767;
    while cc_tab[s] != 0 {
        if cc_nh[cc_tab[s] - 1] == th { return cc_tab[s] - 1; }
        s = (s + 1) & 32767;
    }
    return -1;
}

// the text of the function f: hash with the labels renumbered, the calls (every name of a function in the text), the check that the labels are its own
void cc_hash_function(int f) {
    int a = cc_from[f];
    int b = cc_to[f];
    int h = 1469598103934665603;
    cc_ln = 0;
    cc_okf[f] = 1;
    int i = a;
    while i < b {
        int c = out_buf[i];
        bool start = cc_alnum(c) && (i == a || !cc_alnum(out_buf[i - 1]));
        if start {
            int le = cc_label_end(@out_buf, i, b);
            if le > 0 {
                int num = 0;
                int j = i + 1;
                while j < le { num = num * 10 + (out_buf[j] - '0'); j += 1; }
                int ord = cc_ordinal(num);
                if ord < 0 { cc_okf[f] = 0; ord = 0; }
                if le < b && out_buf[le] == ':' && (i == a || out_buf[i - 1] == 10) { cc_ldef[ord] = 1; }
                h = cc_mix(h, 7654321 + ord);
                i = le;
            } else {
                int j = i;
                int th = 1469598103934665603;
                while j < b && cc_alnum(out_buf[j]) {
                    th = cc_mix(th, out_buf[j]);
                    j += 1;
                }
                h = cc_mix(h, th);
                int g = cc_lookup(th);
                if g >= 0 && g != f && cc_emark[g] != f + 1 && cc_ne < 262144 {
                    cc_emark[g] = f + 1;
                    cc_edge[cc_ne] = g;
                    cc_ne += 1;
                }
                i = j;
            }
        } else {
            h = cc_mix(h, c);
            i += 1;
        }
    }
    int k = 0;
    while k < cc_ln {
        if cc_ldef[k] == 0 { cc_okf[f] = 0; }
        k += 1;
    }
    cc_h[f] = h;
}

// the functions of out_buf, the same limits as ir_run uses
void cc_scan() {
    cc_n = 0;
    cc_ne = 0;
    int t = 0;
    while t < 32768 { cc_tab[t] = 0; t += 1; }
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_is_func(i) && cc_n < 8000 {
            int p = i;
            bool done = false;
            bool seen_epi = false;
            bool seen_exit = false;
            bool is_main = rg_has(i, "main:\n");
            while p < out_len && !done {
                int pe = rg_end(p);
                if p != i && rg_is_func(p) { break; }
                if rg_has(p, "ldr x29, [sp, #0]") { seen_epi = true; }
                if seen_epi && rg_has(p, "ret\n") { done = true; }
                if is_main && rg_has(p, "mov x8, 94\n") { seen_exit = true; }
                if is_main && seen_exit && rg_has(p, "svc 0\n") { done = true; }
                p = pe + 1;
            }
            int nh = 1469598103934665603;
            int q = i;
            while q < en - 1 {
                nh = cc_mix(nh, out_buf[q]);
                q += 1;
            }
            cc_nh[cc_n] = nh;
            cc_from[cc_n] = i;
            cc_to[cc_n] = p;
            cc_emark[cc_n] = 0;
            int s = (nh >> 3) & 32767;
            while cc_tab[s] != 0 { s = (s + 1) & 32767; }
            cc_tab[s] = cc_n + 1;
            cc_n += 1;
            i = p;
        } else {
            i = en + 1;
        }
    }
    int f = 0;
    while f < cc_n {
        cc_e0[f] = cc_ne;
        cc_hash_function(f);
        cc_e1[f] = cc_ne;
        f += 1;
    }
}

// the key: the text of the function and of everything it can reach by calls (the sum does not depend on the order), and the options
void cc_keys() {
    cc_flags = cc_mix(al_to, fr_on);
    cc_flags = cc_mix(cc_flags, inl_off);
    cc_flags = cc_mix(cc_flags, ir_max);
    cc_flags = cc_mix(cc_flags, ir_min);
    cc_flags = cc_mix(cc_flags, ir_mode);
    cc_flags = cc_mix(cc_flags, ir_opt);
    cc_flags = cc_mix(cc_flags, ir_pre);
    cc_flags = cc_mix(cc_flags, opt_debug);
    cc_flags = cc_mix(cc_flags, opt_fma);
    cc_flags = cc_mix(cc_flags, opt_peep);
    cc_flags = cc_mix(cc_flags, opt_regs);
    cc_flags = cc_mix(cc_flags, reserve_mask);       // #reserve x19: the registers the program keeps for itself
    cc_flags = cc_mix(cc_flags, bare_mode);
    int v = 0;
    char^ vs = JCMP_VERSION;
    while vs[v] != 0 { cc_flags = cc_mix(cc_flags, vs[v]); v += 1; }
    int f = 0;
    while f < cc_n {
        cc_stamp += 1;
        int sp = 1;
        cc_stack[0] = f;
        cc_seen[f] = cc_stamp;
        int sum = 0;
        int cnt = 0;
        while sp > 0 {
            sp -= 1;
            int g = cc_stack[sp];
            if g != f {
                sum = sum + cc_mix(cc_h[g], 99);
                cnt += 1;
            }
            int e = cc_e0[g];
            while e < cc_e1[g] {
                int t = cc_edge[e];
                if cc_seen[t] != cc_stamp && sp < 8191 {
                    cc_seen[t] = cc_stamp;
                    cc_stack[sp] = t;
                    sp += 1;
                }
                e += 1;
            }
        }
        cc_key[f] = cc_mix(cc_mix(cc_mix(cc_h[f], sum), cnt), cc_flags);
        f += 1;
    }
}

void cc_hex(int v, char^ dst) {
    int k = 0;
    while k < 16 {
        int nib = (v >> (60 - k * 4)) & 15;
        if nib < 10 { dst[k] = '0' + nib; } else { dst[k] = 'a' + nib - 10; }
        k += 1;
    }
}

void cc_path(int f, char^ path, char^ ext) {
    str_copy(path, cc_dir, 250);
    append_text(path, "/");
    char hx[20];
    cc_hex(cc_key[f], @hx);
    hx[16] = 0;
    append_text(path, @hx);
    append_text(path, ext);
}

// ---- writing into as_src (the scratch buffer until the assembler runs)
void cc_putc(int c) {
    as_src[cc_wlen] = c;
    cc_wlen += 1;
}

void cc_put_range(char^ b, int a, int e) {
    int k = a;
    while k < e { cc_putc(b[k]); k += 1; }
}

void cc_put_text(char^ t) {
    int k = 0;
    while t[k] != 0 { cc_putc(t[k]); k += 1; }
}

void cc_put_num(int n) {
    char d[24];
    int k = 0;
    if n == 0 { d[0] = '0'; k = 1; }
    while n > 0 {
        d[k] = '0' + n % 10;
        n = n / 10;
        k += 1;
    }
    while k > 0 { k -= 1; cc_putc(d[k]); }
}

void cc_marker(char^ kind, int f) {
    cc_put_text(kind);
    cc_put_num(f);
    cc_putc(10);
}

void cc_die(char^ why) {
    write_err("jcmp: cache: ");
    write_err(why);
    write_err(" (run without -cache, or delete the folder of the cache)\n");
    syscall(93, 1);
}

void cc_back() {
    int k = 0;
    while k < cc_wlen { out_buf[k] = as_src[k]; k += 1; }
    out_len = cc_wlen;
}

// the line starts with the marker (";F " or ";E ") and the number; returns the number or -1
int cc_marker_num(int st, char^ kind) {
    if !rg_has(st, kind) { return -1; }
    int j = st + 3;
    int n = 0;
    while out_buf[j] >= '0' && out_buf[j] <= '9' { n = n * 10 + (out_buf[j] - '0'); j += 1; }
    return n;
}

// the text of a function, normalised: the labels are L0, L1 ... in order of appearance; false when a label is not defined in the text
bool cc_put_normalised(int a, int e) {
    cc_ln = 0;
    int i = a;
    while i < e {
        int c = out_buf[i];
        bool start = cc_alnum(c) && (i == a || !cc_alnum(out_buf[i - 1]));
        int le = -1;
        if start { le = cc_label_end(@out_buf, i, e); }
        if le > 0 {
            int num = 0;
            int j = i + 1;
            while j < le { num = num * 10 + (out_buf[j] - '0'); j += 1; }
            int ord = cc_ordinal(num);
            if ord < 0 { return false; }
            if le < e && out_buf[le] == ':' && (i == a || out_buf[i - 1] == 10) { cc_ldef[ord] = 1; }
            cc_putc('L');
            cc_put_num(ord);
            i = le;
        } else {
            cc_putc(c);
            i += 1;
        }
    }
    int k = 0;
    while k < cc_ln {
        if cc_ldef[k] == 0 { return false; }
        k += 1;
    }
    return true;
}

// the text of the cache file, with the labels given new numbers (cc_fresh + the ordinal)
void cc_put_fresh(int n) {
    int top = 0;
    int i = 0;
    while i < n {
        int c = cc_fbuf[i];
        bool start = cc_alnum(c) && (i == 0 || !cc_alnum(cc_fbuf[i - 1]));
        int le = -1;
        if start { le = cc_label_end(@cc_fbuf, i, n); }
        if le > 0 {
            int num = 0;
            int j = i + 1;
            while j < le { num = num * 10 + (cc_fbuf[j] - '0'); j += 1; }
            if num + 1 > top { top = num + 1; }
            cc_putc('L');
            cc_put_num(cc_fresh + num);
            i = le;
        } else {
            cc_putc(c);
            i += 1;
        }
    }
    cc_fresh += top;
}

// -cache DIR, after the code pass: the keys, which functions are in the cache, and the markers around the others
void cc_prepare() {
    cc_scan();
    cc_keys();
    syscall(34, -100, cc_dir, 493);
    char path[300];
    cc_wlen = 0;
    int prev = 0;
    int f = 0;
    while f < cc_n {
        cc_hit[f] = 0;
        if cc_okf[f] == 1 {
            cc_path(f, @path, ".fn");
            int len = read_file(@path, @cc_fbuf, 4194000);
            if len > 0 && cc_fbuf[len - 1] == 10 { cc_hit[f] = 1; cc_hits += 1; }
        }
        cc_put_range(@out_buf, prev, cc_from[f]);
        if cc_okf[f] == 1 { cc_marker(";F ", f); }
        cc_put_range(@out_buf, cc_from[f], cc_to[f]);
        if cc_okf[f] == 1 { cc_marker(";E ", f); }
        prev = cc_to[f];
        f += 1;
    }
    cc_put_range(@out_buf, prev, out_len);
    if x_time == 1 {
        write_err("    cache: ");
        write_err_int(cc_n);
        write_err(" functions, ");
        write_err_int(cc_hits);
        write_err(" in the cache\n");
        if x_cachelist == 1 {
            int g = 0;
            while g < cc_n {
                if cc_hit[g] == 1 { write_err("    hit   "); } else if cc_okf[g] == 1 { write_err("    miss  "); } else { write_err("    none  "); }
                int q = cc_from[g];
                char one[4];
                one[1] = 0;
                while out_buf[q] != 10 && q < out_len { one[0] = out_buf[q]; write_err(@one); q += 1; }
                write_err("\n");
                g += 1;
            }
        }
    }
    cc_back();
}

// after the lifting for inlining has seen every function: the bodies of the functions that come from the cache are not needed any more
void cc_cut() {
    cc_wlen = 0;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        int n = cc_marker_num(i, ";F ");
        if n >= 0 && n < cc_n && cc_hit[n] == 1 && n < x_cutmax && n >= x_cutmin {
            cc_marker(";F ", n);
            int j = en + 1;
            while j < out_len && cc_marker_num(j, ";E ") != n { j = rg_end(j) + 1; }
            if j >= out_len { cc_die("the back end lost a marker of the cache"); }
            cc_marker(";E ", n);
            i = rg_end(j) + 1;
        } else {
            cc_put_range(@out_buf, i, en + 1);
            i = en + 1;
        }
    }
    cc_back();
}

// the end of the back end: the text of the functions from the cache is put in, the others are stored; the markers go away
void cc_finish() {
    cc_wlen = 0;
    cc_fresh = 900000000;
    char path[300];
    char tmp[300];
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        int n = cc_marker_num(i, ";F ");
        if n >= 0 && n < cc_n {
            int j = en + 1;
            while j < out_len && cc_marker_num(j, ";E ") != n { j = rg_end(j) + 1; }
            if j >= out_len { cc_die("the back end lost a marker of the cache"); }
            int after = rg_end(j) + 1;
            cc_path(n, @path, ".fn");
            bool done = false;
            if cc_hit[n] == 1 {
                int len = read_file(@path, @cc_fbuf, 4194000);
                if len <= 0 { cc_die("a file of the cache disappeared while the program was made"); }
                cc_put_fresh(len);
                done = true;
            }
            if !done {
                // the function came out of the back end: it is stored (when its labels are its own) and used as it is
                int seg0 = en + 1;
                int seg1 = j;
                if seg1 - seg0 < 4000000 {
                    // the normalised text is written at the end of the new text, stored, and taken away again
                    int st = cc_wlen;
                    bool ok = cc_put_normalised(seg0, seg1);
                    if ok {
                        cc_str_tmp(@tmp, n);
                        if write_file(@tmp, @as_src + st, cc_wlen - st) == 0 {
                            syscall(38, -100, @tmp, -100, @path);
                            cc_stored += 1;
                        }
                    }
                    cc_wlen = st;
                }
                cc_put_range(@out_buf, seg0, seg1);
            }
            i = after;
        } else {
            cc_put_range(@out_buf, i, en + 1);
            i = en + 1;
        }
    }
    cc_back();
}

void cc_str_tmp(char^ tmp, int f) {
    cc_path(f, tmp, ".tmp");
}

// -xcachestat DIR: how many of the functions of this program are already known in DIR/keys.txt; the new keys are added
void cc_stat(char^ dir) {
    cc_dir = dir;
    cc_scan();
    cc_keys();
    char path[300];
    str_copy(@path, dir, 250);
    append_text(@path, "/keys.txt");
    int n = read_file(@path, @cc_fbuf, 1900000);
    if n < 0 { n = 0; }
    int hits = 0;
    int f = 0;
    while f < cc_n {
        char hx[20];
        cc_hex(cc_key[f], @hx);
        hx[16] = 0;
        bool found = false;
        int p = 0;
        while p + 16 <= n {
            int k = 0;
            while k < 16 && cc_fbuf[p + k] == hx[k] { k += 1; }
            if k == 16 { found = true; break; }
            p += 17;
        }
        if found {
            hits += 1;
        } else if n + 17 < 1900000 {
            int k = 0;
            while k < 16 { cc_fbuf[n + k] = hx[k]; k += 1; }
            cc_fbuf[n + 16] = 10;
            n += 17;
        }
        f += 1;
    }
    syscall(34, -100, dir, 493);
    if write_file(@path, @cc_fbuf, n) != 0 { write_err("jcmp: cannot write the cache list\n"); }
    write_err("cache: ");
    write_err_int(cc_n);
    write_err(" functions, ");
    write_err_int(hits);
    write_err(" already in the cache\n");
}
