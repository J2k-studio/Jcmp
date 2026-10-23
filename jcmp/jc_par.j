// jc_par.j -- the passes ir and regs on many cores. The functions are worked on one by one and do not depend on each other, so the work is shared by
// processes (fork): child k changes the functions with  number % n == k  and copies the others; every child writes its text into a shared piece
// of memory; the parent takes the output of function f from child f % n. No thread-safe rewrite of the passes is needed. The labels a child makes
// (they begin at label_no + (k + 1) * 10000000) are numbered again in the parent so that they are short and different. The result is
// the same as with one core, up to the numbers of the new labels. -j 1 (or a small program) works as before.

// ---- the progress of a compile (jcmp -progress FILE): the file holds one line  PERCENT STAGE CORES  (CORES: the percent of each process, or -), made again at
// every stage and, in the long passes, every few functions; makej shows it as  [||||||||    ] 62%
char prog_path[512];
int prog_on;
int prog_total;              // the functions of the pass that runs
int prog_base;
int prog_span;
int prog_child_done;         // in a child: the functions it has done
char^ prog_ptr;              // in a child: where it writes that number (the shared piece)
int prog_last_ms;

void prog_write(int pct, char^ stage, char^ cores) {
    if prog_on == 0 { return; }
    int fd = syscall(56, -100, @prog_path, 577, 420);
    if fd < 0 { return; }
    char b[300];
    int n = 0;
    char dg[16];
    int dn = 0;
    int x = pct;
    if x < 0 { x = 0; }
    if x > 100 { x = 100; }
    if x == 0 { dg[0] = '0'; dn = 1; }
    while x > 0 { dg[dn] = '0' + x % 10; dn += 1; x = x / 10; }
    while dn > 0 { dn -= 1; b[n] = dg[dn]; n += 1; }
    b[n] = ' '; n += 1;
    int i = 0;
    while stage[i] != 0 && n < 100 { b[n] = stage[i]; n += 1; i += 1; }
    b[n] = ' '; n += 1;
    i = 0;
    if cores[0] == 0 { b[n] = '-'; n += 1; }
    while cores[i] != 0 && n < 280 { b[n] = cores[i]; n += 1; i += 1; }
    b[n] = 10; n += 1;
    syscall(64, fd, @b, n);
    syscall(57, fd);
}

// the stage that tm_stage names has just ended
void prog_stage(char^ name) {
    if prog_on == 0 { return; }
    if str_eq(name, "parse pass 1 (names)") { prog_write(5, "reading", ""); }
    else if str_eq(name, "parse passes 1+2") { prog_write(10, "reading", ""); }
    else if str_eq(name, "parse pass 3 (the code)") { prog_write(19, "code", ""); }
    else if str_eq(name, "nr + first peephole") { prog_write(23, "code", ""); }
    else if str_eq(name, "ir") { prog_write(57, "ir", ""); }
    else if str_eq(name, "peephole") { prog_write(59, "peephole", ""); }
    else if str_eq(name, "register pass") { prog_write(96, "registers", ""); }
    else if str_eq(name, "peephole + alignment") { prog_write(98, "peephole", ""); }
    else if str_eq(name, "assembler") { prog_write(100, "done", ""); }
}

int par_count_functions() {
    int c = 0;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_is_func(i) { c += 1; }
        i = en + 1;
    }
    return c;
}

int par_cores() {
    char mask[128];
    int k = 0;
    while k < 128 { mask[k] = 0; k += 1; }
    int got = syscall(123, 0, 128, @mask, 0, 0);                  // sched_getaffinity: the cores this process may use
    int total = 0;
    if got > 0 {
        int i = 0;
        while i < got {
            int b = mask[i] & 255;
            while b != 0 { total += b & 1; b = b >> 1; }
            i += 1;
        }
    }
    if total < 1 { total = 1; }
    return total;
}

// how many processes for a pass over the text of out_buf
int par_decide() {
    if par_jobs == 1 || x_target == 32 || ir_mode != 2 || par_n != 0 { return 1; }
    if out_len < 600000 { return 1; }                       // a small program is faster on one core
    int n = par_jobs;
    if n <= 0 { n = par_cores(); }
    if n > 8 { n = 8; }
    return n;
}

void par_close_open() {
    if par_open >= 0 {
        par_fe[par_open] = regs_len;
        par_open = 0 - 1;
    }
}

// the function that is at the top level now: true if this child must leave it as it is
bool par_skip_function() {
    par_close_open();
    int f = par_fidx;
    if f >= 65535 { f = 65534; }
    par_fs[f] = regs_len;
    par_open = f;
    par_fidx += 1;
    if par_n == 0 {
        if prog_on == 1 && (par_fidx & 31) == 0 && prog_total > 0 { prog_write(prog_base + prog_span * par_fidx / prog_total, prog_stage_name(), ""); }
        return false;
    }
    bool mine = f % par_n == par_k;
    if mine && prog_ptr != null {
        prog_child_done += 1;
        if (prog_child_done & 7) == 0 { par_put(prog_ptr, 24, prog_child_done); }
    }
    return !mine;
}

char^ prog_stage_name() {
    if prog_base < 40 { return "ir"; }
    return "registers";
}

// read and write numbers in the shared piece (8 bytes, little endian)
int par_get(char^ m, int at) {
    int v = 0;
    int k = 0;
    while k < 8 { v = v | ((m[at + k] & 255) << (8 * k)); k += 1; }
    return v;
}
void par_put(char^ m, int at, int v) {
    int k = 0;
    while k < 8 { m[at + k] = (char)((v >> (8 * k)) & 255); k += 1; }
}

// runs one pass ("which": 0 = ir_run_loop, 1 = regs_run_loop) on many processes, or on this one
void par_pass(int which) {
    int n = par_decide();
    par_fidx = 0;
    par_open = 0 - 1;
    if which == 0 { prog_base = 23; prog_span = 34; } else { prog_base = 59; prog_span = 37; }
    prog_total = 0;
    if prog_on == 1 { prog_total = par_count_functions(); prog_write(prog_base, prog_stage_name(), ""); }
    if n <= 1 {
        if which == 0 { ir_run_loop(); } else { regs_run_loop(); }
        par_close_open();
        return;
    }
    int slot = out_len + out_len / 2 + 524288 + 64 + 8 * 2 * 65536;           // the text, then the numbers of the functions
    slot = (slot + 4095) / 4096 * 4096;
    char^ shm = (char^)syscall(222, 0, slot * n, 3, 33, -1, 0);                // mmap: shared and anonymous
    if (int)shm < 0 && (int)shm > -4096 {
        if which == 0 { ir_run_loop(); } else { regs_run_loop(); }
        par_close_open();
        return;
    }
    int base_label = label_no;
    int pids[8];
    int k = 0;
    bool failed = false;
    while k < n {
        int pid = syscall(220, 17, 0, 0, 0, 0);                                 // fork (clone with SIGCHLD)
        if pid == 0 {
            par_n = n;
            par_k = k;
            prog_ptr = shm + slot * k;
            prog_child_done = 0;
            label_no = base_label + (k + 1) * 10000000;
            if which == 0 { ir_run_loop(); } else { regs_run_loop(); }
            par_close_open();
            char^ m = shm + slot * k;
            if out_len + 32 + 16 * 65536 >= slot { syscall(94, 1); }                   // the text does not fit: the parent does it again on one core
            par_put(m, 0, out_len);
            par_put(m, 8, label_no - (base_label + (k + 1) * 10000000));      // the number of labels made
            par_put(m, 16, par_fidx);
            int off = 32;
            int t = 0;
            while t < par_fidx && t < 65535 {
                par_put(m, off + 16 * t, par_fs[t]);
                par_put(m, off + 16 * t + 8, par_fe[t]);
                t += 1;
            }
            int text_at = 32 + 16 * 65536;
            int c = 0;
            while c < out_len { m[text_at + c] = out_buf[c]; c += 1; }
            syscall(94, 0);                                                    // exit_group
        }
        if pid < 0 { failed = true; break; }
        pids[k] = pid;
        k += 1;
    }
    int started = k;
    int status = 0;
    if prog_on == 0 {
        k = 0;
        while k < started {
            syscall(260, pids[k], @status, 0, 0);                              // wait4
            if status != 0 { failed = true; }
            k += 1;
        }
    } else {
        // wait and show how far every process is
        int reaped[8];
        k = 0;
        while k < 8 { reaped[k] = 0; k += 1; }
        int alive = started;
        int ts[2];
        while alive > 0 {
            k = 0;
            while k < started {
                if reaped[k] == 0 {
                    int r = syscall(260, pids[k], @status, 1, 0);                // wait4 with WNOHANG
                    if r == pids[k] {
                        reaped[k] = 1;
                        alive -= 1;
                        if status != 0 { failed = true; }
                    }
                }
                k += 1;
            }
            // the numbers of the cores
            char cs[96];
            int cn = 0;
            int sum = 0;
            k = 0;
            while k < started {
                int done = par_get(shm + slot * k, 24);
                int expect = prog_total / n + 1;
                int cp = done * 100 / expect;
                if reaped[k] == 1 { cp = 100; }
                if cp > 100 { cp = 100; }
                sum += cp;
                if k > 0 { cs[cn] = ','; cn += 1; }
                if cp >= 100 { cs[cn] = '1'; cs[cn + 1] = '0'; cs[cn + 2] = '0'; cn += 3; }
                else { if cp >= 10 { cs[cn] = '0' + cp / 10; cn += 1; } cs[cn] = '0' + cp % 10; cn += 1; }
                k += 1;
            }
            cs[cn] = 0;
            prog_write(prog_base + prog_span * (sum / started) / 100, prog_stage_name(), @cs);
            if alive > 0 {
                ts[0] = 0;
                ts[1] = 40000000;
                syscall(101, @ts, 0);                                          // nanosleep 40 ms
            }
        }
    }
    if failed {
        syscall(215, shm, slot * n);                                           // munmap
        par_fidx = 0;
        par_open = 0 - 1;
        regs_len = 0;
        if which == 0 { ir_run_loop(); } else { regs_run_loop(); }              // as with one core
        par_close_open();
        return;
    }
    // the same number of functions in every child?
    int nf = par_get(shm, 16);
    k = 1;
    while k < n {
        if par_get(shm + slot * k, 16) != nf { failed = true; }
        k += 1;
    }
    if failed || nf <= 0 || nf >= 65535 {
        syscall(215, shm, slot * n);
        par_fidx = 0;
        par_open = 0 - 1;
        regs_len = 0;
        if which == 0 { ir_run_loop(); } else { regs_run_loop(); }
        par_close_open();
        return;
    }
    // the new labels: child k gets the numbers base_label + 1 + (the labels of the children before it)
    int shift[8];
    int acc = 0;
    k = 0;
    while k < n {
        shift[k] = acc;
        acc += par_get(shm + slot * k, 8);
        k += 1;
    }
    // put the text together in regs_buf: the gaps from child 0, the functions from child f % n
    int text_at = 32 + 16 * 65536;
    int w = 0;
    int pos0 = 0;
    int f = 0;
    while f <= nf {
        // the gap before function f (or the rest after the last one) comes from child 0
        char^ m0 = shm;
        int gap_to = par_get(m0, 0);
        if f < nf { gap_to = par_get(m0, 32 + 16 * f); }
        w = par_copy(@regs_buf, w, m0 + text_at, pos0, gap_to, base_label, @shift);
        if f == nf { break; }
        int owner = f % n;
        char^ mo = shm + slot * owner;
        int fs = par_get(mo, 32 + 16 * f);
        int fe = par_get(mo, 32 + 16 * f + 8);
        w = par_copy(@regs_buf, w, mo + text_at, fs, fe, base_label, @shift);
        pos0 = par_get(m0, 32 + 16 * f + 8);
        f += 1;
    }
    int t = 0;
    while t < w { out_buf[t] = regs_buf[t]; t += 1; }
    out_len = w;
    label_no = base_label + acc;
    syscall(215, shm, slot * n);
}

// copy src[from, to) to dst at w; a label made by a child (a number from base + 10000000 on) gets its short number
int par_copy(char^ dst, int w, char^ src, int from, int to, int base_label, int^ shift) {
    int i = from;
    while i < to {
        int c = src[i];
        bool start = i == from || src[i - 1] == ' ' || src[i - 1] == 10 || src[i - 1] == ',';
        if c == 'L' && start && i + 1 < to && src[i + 1] >= '0' && src[i + 1] <= '9' {
            int j = i + 1;
            int v = 0;
            while j < to && src[j] >= '0' && src[j] <= '9' && j - i < 12 { v = v * 10 + (src[j] - '0'); j += 1; }
            if v >= base_label + 10000000 {
                int rel = v - base_label;
                int kk = rel / 10000000 - 1;
                int cc = rel % 10000000;
                int nv = base_label + shift[kk] + cc;
                dst[w] = 'L';
                w += 1;
                char dg[16];
                int dn = 0;
                int x = nv;
                if x == 0 { dg[0] = '0'; dn = 1; }
                while x > 0 { dg[dn] = '0' + x % 10; dn += 1; x = x / 10; }
                while dn > 0 { dn -= 1; dst[w] = dg[dn]; w += 1; }
                i = j;
                continue;
            }
        }
        dst[w] = (char)c;
        w += 1;
        i += 1;
    }
    return w;
}
