// jc_peep.j -- the peephole pass: the assembler text of the whole program is read line by line and a few wasteful groups of
// lines are written shorter. It runs once, after the code is made and before it is assembled. Every rule looks only at lines
// that follow each other (a label line is a wall), and every rule keeps what the program does.
//
//   str xR, [xB, #N] / ldr xR, [xB, #N]                    the value is still in xR: the second line goes
//   sub sp, sp, #16 / str x0, [sp, #0] / ldr x0, [sp, #0] / add sp, sp, #16     a push that is popped at once: all four go
//   sub sp, sp, #16 / str x0, [sp, #0] / add sp, sp, #16                         (the same without the load): all three go
//   mov x1, N / add x0, x0, x1  (or sub, cmp)              add x0, x0, #N
//   cmp x0, A / mov x0, 1 / b.C L / mov x0, 0 / L: / cmp x0, 0 / b.eq|b.ne T     cmp x0, A / b.C' T   (a comparison used as a condition)
//   b L / L:                                                the jump to the next line goes

char peep_buf[8388608];
int peep_len;

// the start of the line that is `back` lines before the last one in peep_buf (0 = the last), or -1
int peep_start(int back) {
    int e = peep_len;
    if e == 0 || peep_buf[e - 1] != 10 { return 0 - 1; }
    int st = e - 1;
    int k = 0;
    while true {
        while st > 0 && peep_buf[st - 1] != 10 { st -= 1; }
        if k == back { return st; }
        if st == 0 { return 0 - 1; }
        st -= 1;                         // on the newline before
        k += 1;
    }
    return 0 - 1;
}

// is the line that starts at st exactly the text s (up to the newline)?
bool peep_is(int st, char^ s) {
    if st < 0 { return false; }
    int i = 0;
    while s[i] != 0 {
        if peep_buf[st + i] != s[i] { return false; }
        i += 1;
    }
    return peep_buf[st + i] == 10;
}

// does the line start with the text s?
bool peep_has(int st, char^ s) {
    if st < 0 { return false; }
    int i = 0;
    while s[i] != 0 {
        if peep_buf[st + i] != s[i] { return false; }
        i += 1;
    }
    return true;
}

// the end of the line (the index of its newline)
int peep_end(int st) {
    int e = st;
    while peep_buf[e] != 10 { e += 1; }
    return e;
}

// is the line a label ("L12:")?
bool peep_is_label(int st) {
    if st < 0 { return false; }
    int e = peep_end(st);
    return e > st && peep_buf[e - 1] == ':';
}

// the number at p (digits only up to the end of the line), or -1
int peep_number(int p, int e) {
    if p >= e { return 0 - 1; }
    int n = 0;
    while p < e {
        int c = peep_buf[p];
        if c < '0' || c > '9' { return 0 - 1; }
        n = n * 10 + (c - '0');
        p += 1;
    }
    return n;
}

// the opposite condition of a branch (eq <-> ne ...), written into out; false if there is none
bool peep_inverse(char^ c, char^ out) {
    if str_eq(c, "eq") { str_copy(out, "ne", 4); return true; }
    if str_eq(c, "ne") { str_copy(out, "eq", 4); return true; }
    if str_eq(c, "lt") { str_copy(out, "ge", 4); return true; }
    if str_eq(c, "ge") { str_copy(out, "lt", 4); return true; }
    if str_eq(c, "gt") { str_copy(out, "le", 4); return true; }
    if str_eq(c, "le") { str_copy(out, "gt", 4); return true; }
    if str_eq(c, "lo") { str_copy(out, "hs", 4); return true; }
    if str_eq(c, "hs") { str_copy(out, "lo", 4); return true; }
    if str_eq(c, "hi") { str_copy(out, "ls", 4); return true; }
    if str_eq(c, "ls") { str_copy(out, "hi", 4); return true; }
    return false;
}

// writes the number n (digits) at peep_buf[at...] and returns the index after it
int peep_put_number(int n, int at) {
    char d[12];
    int dn = 0;
    int v = n;
    if v == 0 {
        d[0] = '0';
        dn = 1;
    }
    while v > 0 {
        d[dn] = '0' + v % 10;
        dn += 1;
        v = v / 10;
    }
    while dn > 0 {
        dn -= 1;
        peep_buf[at] = d[dn];
        at += 1;
    }
    return at;
}

// tries every rule on the end of peep_buf; true if something was changed
bool peep_try() {
    int l0 = peep_start(0);
    if l0 < 0 { return false; }
    if peep_is_label(l0) {
        // b L / L: : the jump to the next line
        int l1 = peep_start(1);
        if l1 >= 0 && peep_has(l1, "b L") {
            int e1 = peep_end(l1);
            int e0 = peep_end(l0);
            // the label of the last line equals the target of the b line?
            if e0 - l0 - 1 == e1 - l1 - 2 {
                bool same = true;
                int i = 0;
                while i < e0 - l0 - 1 {
                    if peep_buf[l0 + i] != peep_buf[l1 + 2 + i] { same = false; }
                    i += 1;
                }
                if same {
                    // delete the b line (move the label line over it)
                    int n = e0 - l0 + 1;
                    int t = 0;
                    while t < n {
                        peep_buf[l1 + t] = peep_buf[l0 + t];
                        t += 1;
                    }
                    peep_len = l1 + n;
                    return true;
                }
            }
        }
        return false;
    }
    // str xR, [xB, #N] / ldr xR, [xB, #N]  : the load goes (the base is the frame, the globals or the stack, never xR itself)
    if peep_has(l0, "ldr x") {
        int l1 = peep_start(1);
        if l1 >= 0 && peep_has(l1, "str x") {
            int e0 = peep_end(l0);
            int e1 = peep_end(l1);
            if e0 - l0 == e1 - l1 {
                bool same = true;
                int i = 3;
                while i < e0 - l0 {
                    if peep_buf[l0 + i] != peep_buf[l1 + i] { same = false; }
                    i += 1;
                }
                if same {
                    // the text has the form  ldr xR, [xB, #N]  : look for the base
                    int p = l0 + 4;
                    while p < e0 && peep_buf[p] != '[' { p += 1; }
                    bool ok = peep_has(p, "[x29, ") || peep_has(p, "[x28, ") || peep_has(p, "[sp, ");
                    if ok {
                        peep_len = l0;
                        return true;
                    }
                }
            }
        }
    }
    if peep_is(l0, "add sp, sp, #16") {
        int l1 = peep_start(1);
        int l2 = peep_start(2);
        int l3 = peep_start(3);
        if peep_is(l1, "ldr x0, [sp, #0]") && peep_is(l2, "str x0, [sp, #0]") && peep_is(l3, "sub sp, sp, #16") {
            peep_len = l3;
            return true;
        }
        // (the load may have been taken away by the first rule) sub sp, sp, #16 / str x0, [sp, #0] / add sp, sp, #16
        if peep_is(l1, "str x0, [sp, #0]") && peep_is(l2, "sub sp, sp, #16") {
            peep_len = l2;
            return true;
        }
        return false;
    }
    // mov x1, N / add x0, x0, x1 (sub, cmp)
    bool is_add = peep_is(l0, "add x0, x0, x1");
    bool is_sub = peep_is(l0, "sub x0, x0, x1");
    bool is_cmp = peep_is(l0, "cmp x0, x1");
    if is_add || is_sub || is_cmp {
        int l1 = peep_start(1);
        if l1 >= 0 && peep_has(l1, "mov x1, ") {
            int e1 = peep_end(l1);
            int n = peep_number(l1 + 8, e1);
            if n >= 0 && n < 4096 {
                // rewrite: the mov line becomes the instruction with the number
                peep_len = l1;
                if is_add { str_copy(@peep_buf + peep_len, "add x0, x0, #", 20); peep_len += 13; }
                if is_sub { str_copy(@peep_buf + peep_len, "sub x0, x0, #", 20); peep_len += 13; }
                if is_cmp { str_copy(@peep_buf + peep_len, "cmp x0, ", 20); peep_len += 8; }
                // the digits are still in place after the old line start: they were overwritten, so write the number again
                char d[12];
                int dn = 0;
                int v = n;
                if v == 0 {
                    d[0] = '0';
                    dn = 1;
                }
                while v > 0 {
                    d[dn] = '0' + v % 10;
                    dn += 1;
                    v = v / 10;
                }
                while dn > 0 {
                    dn -= 1;
                    peep_buf[peep_len] = d[dn];
                    peep_len += 1;
                }
                peep_buf[peep_len] = 10;
                peep_len += 1;
                return true;
            }
        }
        return false;
    }
    // add x3, xB, #N / mov x1, x0 / str x1, [x3, #0]   ->   str x0, [xB, #N]   (also strb, strw)
    if peep_has(l0, "str x1, [x3, #0]") || peep_has(l0, "strb x1, [x3, #0]") || peep_has(l0, "strw x1, [x3, #0]") {
        int l1 = peep_start(1);
        int l2 = peep_start(2);
        if l2 >= 0 && peep_is(l1, "mov x1, x0") && peep_has(l2, "add x3, x2") {
            int bch = peep_buf[l2 + 10];
            if (bch == '8' || bch == '9') && peep_buf[l2 + 11] == ',' && peep_buf[l2 + 12] == ' ' && peep_buf[l2 + 13] == '#' {
                int e2 = peep_end(l2);
                int n = peep_number(l2 + 14, e2);
                int scale = 8;
                if peep_has(l0, "strb") { scale = 1; }
                if peep_has(l0, "strw") { scale = 4; }
                if n >= 0 && n < 4096 && n % scale == 0 {
                    char op[8];
                    op[0] = 's';
                    op[1] = 't';
                    op[2] = 'r';
                    op[3] = 0;
                    if scale == 1 { str_copy(@op, "strb", 8); }
                    if scale == 4 { str_copy(@op, "strw", 8); }
                    peep_len = l2;
                    int z = 0;
                    while op[z] != 0 {
                        peep_buf[peep_len] = op[z];
                        peep_len += 1;
                        z += 1;
                    }
                    peep_buf[peep_len] = ' ';
                    peep_buf[peep_len + 1] = 'x';
                    peep_buf[peep_len + 2] = '0';
                    peep_buf[peep_len + 3] = ',';
                    peep_buf[peep_len + 4] = ' ';
                    peep_buf[peep_len + 5] = '[';
                    peep_buf[peep_len + 6] = 'x';
                    peep_buf[peep_len + 7] = '2';
                    peep_buf[peep_len + 8] = bch;
                    peep_buf[peep_len + 9] = ',';
                    peep_buf[peep_len + 10] = ' ';
                    peep_buf[peep_len + 11] = '#';
                    peep_len += 12;
                    peep_len = peep_put_number(n, peep_len);
                    peep_buf[peep_len] = ']';
                    peep_buf[peep_len + 1] = 10;
                    peep_len += 2;
                    return true;
                }
            }
        }
    }
    // mov x1, x0 / mov x0, x1N / OP x0, x0, x1   ->   OP x0, x1N, x0   (the left operand waited in x1N)
    if peep_has(l0, "add x0, x0, x1") || peep_has(l0, "sub x0, x0, x1") || peep_has(l0, "mul x0, x0, x1") || peep_has(l0, "and x0, x0, x1") || peep_has(l0, "orr x0, x0, x1") || peep_has(l0, "eor x0, x0, x1") || peep_has(l0, "cmp x0, x1") {
        int e0 = peep_end(l0);
        if (peep_has(l0, "cmp x0, x1") && e0 - l0 == 10) || e0 - l0 == 14 {
            int l1 = peep_start(1);
            int l2 = peep_start(2);
            if l2 >= 0 && peep_is(l2, "mov x1, x0") && peep_has(l1, "mov x0, x1") {
                int e1 = peep_end(l1);
                int rn = peep_number(l1 + 9, e1);
                if rn >= 10 && rn <= 14 {
                    bool is_cmp = peep_has(l0, "cmp x0, x1");
                    char op[4];
                    op[0] = peep_buf[l0];
                    op[1] = peep_buf[l0 + 1];
                    op[2] = peep_buf[l0 + 2];
                    op[3] = 0;
                    peep_len = l2;
                    peep_buf[peep_len] = op[0];
                    peep_buf[peep_len + 1] = op[1];
                    peep_buf[peep_len + 2] = op[2];
                    peep_buf[peep_len + 3] = ' ';
                    peep_len += 4;
                    if !is_cmp {
                        peep_buf[peep_len] = 'x';
                        peep_buf[peep_len + 1] = '0';
                        peep_buf[peep_len + 2] = ',';
                        peep_buf[peep_len + 3] = ' ';
                        peep_len += 4;
                    }
                    peep_buf[peep_len] = 'x';
                    peep_len += 1;
                    peep_len = peep_put_number(rn, peep_len);
                    peep_buf[peep_len] = ',';
                    peep_buf[peep_len + 1] = ' ';
                    peep_buf[peep_len + 2] = 'x';
                    peep_buf[peep_len + 3] = '0';
                    peep_buf[peep_len + 4] = 10;
                    peep_len += 5;
                    return true;
                }
            }
        }
    }
    // a comparison used as a condition
    if peep_has(l0, "b.eq ") || peep_has(l0, "b.ne ") {
        int l1 = peep_start(1);
        int l2 = peep_start(2);
        int l3 = peep_start(3);
        int l4 = peep_start(4);
        int l5 = peep_start(5);
        int l6 = peep_start(6);
        if l6 >= 0 && peep_is(l1, "cmp x0, 0") && peep_is_label(l2) && peep_is(l3, "mov x0, 0") && peep_has(l4, "b.") && peep_is(l5, "mov x0, 1") && peep_has(l6, "cmp x0, ") {
            // the label of l2 must be the target of l4
            int e2 = peep_end(l2);
            int e4 = peep_end(l4);
            int p4 = l4 + 2;
            while peep_buf[p4] != ' ' { p4 += 1; }
            // l4 = "b.COND LABEL"
            if e4 - (p4 + 1) == e2 - l2 - 1 {
                bool same = true;
                int i = 0;
                while i < e2 - l2 - 1 {
                    if peep_buf[l2 + i] != peep_buf[p4 + 1 + i] { same = false; }
                    i += 1;
                }
                if same && (peep_has(l6, "cmp x0, x") || peep_buf[l6 + 8] >= '0' && peep_buf[l6 + 8] <= '9') {
                    // the condition code
                    char cc[4];
                    cc[0] = peep_buf[l4 + 2];
                    cc[1] = peep_buf[l4 + 3];
                    cc[2] = 0;
                    char inv[4];
                    char use[4];
                    if peep_has(l0, "b.eq ") {
                        // the target is taken when the condition was false: the opposite condition
                        if !peep_inverse(@cc, @inv) { return false; }
                        str_copy(@use, @inv, 4);
                    } else {
                        str_copy(@use, @cc, 4);
                    }
                    // the target of the old branch: the text after "b.xx "
                    int tp = l0 + 5;
                    int te = peep_end(l0);
                    char tgt[64];
                    int tl = 0;
                    while tp < te && tl < 62 {
                        tgt[tl] = peep_buf[tp];
                        tl += 1;
                        tp += 1;
                    }
                    tgt[tl] = 0;
                    // cut the lines l5 .. l0 (everything after the cmp line l6) and write the new branch
                    int e6 = peep_end(l6);
                    peep_len = e6 + 1;
                    peep_buf[peep_len] = 'b';
                    peep_buf[peep_len + 1] = '.';
                    peep_buf[peep_len + 2] = use[0];
                    peep_buf[peep_len + 3] = use[1];
                    peep_buf[peep_len + 4] = ' ';
                    peep_len += 5;
                    int z = 0;
                    while tgt[z] != 0 {
                        peep_buf[peep_len] = tgt[z];
                        peep_len += 1;
                        z += 1;
                    }
                    peep_buf[peep_len] = 10;
                    peep_len += 1;
                    return true;
                }
            }
        }
    }
    return false;
}

// the whole text of out_buf goes through the rules
void peep_run() {
    peep_len = 0;
    int i = 0;
    while i < out_len {
        // copy one line
        int j = i;
        while j < out_len && out_buf[j] != 10 { j += 1; }
        if j >= out_len { j = out_len - 1; }
        int k = i;
        while k <= j {
            peep_buf[peep_len] = out_buf[k];
            peep_len += 1;
            k += 1;
        }
        i = j + 1;
        int guard = 0;
        while peep_try() && guard < 16 { guard += 1; }
    }
    int t = 0;
    while t < peep_len {
        out_buf[t] = peep_buf[t];
        t += 1;
    }
    out_len = peep_len;
}
