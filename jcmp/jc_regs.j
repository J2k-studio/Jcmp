// jc_regs.j -- the register pass: in a function that has loops, the whole-number locals that are used most (weighted by how deep
// in loops they are used) live in the registers x19..x25 instead of the stack frame. It works on the assembler text, after the code
// is made and before the peephole pass:
//
//   ldr xR, [x29, #N]   ->   mov xR, xK          str xR, [x29, #N]   ->   mov xK, xR
//
// A slot may move into a register only if (1) the compiler said (with a line ";H off:size:flag ..." at the end of the body) that
// it is a plain 8-byte value, (2) every use of it is exactly one of the two forms above (no address is taken, no byte or word
// access) and (3) the function does not use the frame in a way that needs the memory: no cleanup chain (x27 + 784: owners, defer),
// no worker of a #multithread loop (x26), no copy of x29. The registers are saved at the start and given back at the end of the
// function (callee-saved: x19..x25 are not used by anything else). A program with try/catch is left alone (a throw jumps over the
// frames without giving the registers back). Lines ";H" are always removed. -noregs switches the pass off.

char regs_buf[8388608];
int regs_len;
int rg_ls[65536];            // the start of each line of the function
int rg_n;
int rg_state[8192];          // by 8-byte slot of the frame: 0 unknown, 1 a plain value that may move, 2 not allowed
int rg_wt[8192];
int rg_dep[65536];
int rg_labn[8192];
int rg_labl[8192];
int rg_nlab;
int rg_pick[8];              // the slots that got a register
int rg_npick;
int rg_slotreg[8192];        // the register number (19..25) of a slot, or 0

// the end of the line that starts at st (the index of its newline)
int rg_end(int st) {
    int e = st;
    while out_buf[e] != 10 { e += 1; }
    return e;
}

// does the line at st start with s?
bool rg_has(int st, char^ s) {
    int i = 0;
    while s[i] != 0 {
        if out_buf[st + i] != s[i] { return false; }
        i += 1;
    }
    return true;
}

// does s occur in the line st..en?
bool rg_in(int st, int en, char^ s) {
    int k = st;
    while k < en {
        int i = 0;
        while s[i] != 0 && k + i < en && out_buf[k + i] == s[i] { i += 1; }
        if s[i] == 0 { return true; }
        k += 1;
    }
    return false;
}

// the number written at index i (digits); the index after it is in rg_next
int rg_next;
int rg_num(int i) {
    int v = 0;
    while out_buf[i] >= '0' && out_buf[i] <= '9' {
        v = v * 10 + (out_buf[i] - '0');
        i += 1;
    }
    rg_next = i;
    return v;
}

// is the line st..en a label of a function ("name:" followed by "sub sp, sp, #")?
bool rg_is_func(int st) {
    int en = rg_end(st);
    if en <= st + 1 || out_buf[en - 1] != ':' { return false; }
    if out_buf[st] == 'L' && out_buf[st + 1] >= '0' && out_buf[st + 1] <= '9' { return false; }
    if out_buf[st] == ';' { return false; }
    return rg_has(en + 1, "sub sp, sp, #");
}

// the form "ldr xR, [x29, #N]" or "str xR, [x29, #N]" at st: returns N (and rg_reg = R, rg_isload), or -1
int rg_reg;
int rg_isload;
int rg_slot_use(int st) {
    int i = st;
    if rg_has(st, "ldr x") {
        rg_isload = 1;
    } else if rg_has(st, "str x") {
        rg_isload = 0;
    } else {
        return 0 - 1;
    }
    i = st + 5;
    if out_buf[i] < '0' || out_buf[i] > '9' { return 0 - 1; }
    rg_reg = rg_num(i);
    i = rg_next;
    if !rg_has(i, ", [x29, #") { return 0 - 1; }
    i += 9;
    if out_buf[i] < '0' || out_buf[i] > '9' { return 0 - 1; }
    int n = rg_num(i);
    i = rg_next;
    if out_buf[i] != ']' || out_buf[i + 1] != 10 { return 0 - 1; }
    return n;
}

void rg_put(char c) {
    regs_buf[regs_len] = c;
    regs_len += 1;
}

void rg_text(char^ s) {
    int i = 0;
    while s[i] != 0 {
        rg_put(s[i]);
        i += 1;
    }
}

void rg_int(int v) {
    if v >= 10 { rg_int(v / 10); }
    rg_put('0' + v % 10);
}

// copy the text st..en (not the newline) and a newline
void rg_copy(int st, int en) {
    int k = st;
    while k < en {
        rg_put(out_buf[k]);
        k += 1;
    }
    rg_put(10);
}

// the function that starts at the line fs and has the lines rg_ls[0 .. rg_n - 1]: write it (with registers if it pays)
void rg_function(int is_main) {
    int i = 0;
    int ok = 1;
    int hint_at = 0 - 1;
    int epi = 0 - 1;
    int s = 0;
    while s < 8192 {
        rg_state[s] = 0;
        rg_wt[s] = 0;
        rg_slotreg[s] = 0;
        s += 1;
    }
    // the hints
    i = 0;
    while i < rg_n {
        int st = rg_ls[i];
        if rg_has(st, ";H") {
            hint_at = i;
            int en = rg_end(st);
            int p = st + 2;
            while p < en {
                while p < en && out_buf[p] == ' ' { p += 1; }
                if p < en {
                    int off = rg_num(p);
                    p = rg_next + 1;
                    int size = rg_num(p);
                    p = rg_next + 1;
                    int flag = rg_num(p);
                    p = rg_next;
                    int w0 = off / 8;
                    int w1 = (off + size - 1) / 8;
                    if size <= 0 { w1 = w0; }
                    int w = w0;
                    while w <= w1 && w < 8192 {
                        if flag == 1 && size == 8 && off % 8 == 0 && rg_state[w] != 2 {
                            rg_state[w] = 1;
                        } else {
                            rg_state[w] = 2;
                        }
                        w += 1;
                    }
                }
            }
        }
        i += 1;
    }
    if hint_at < 0 { ok = 0; }
    // the labels (for the loops)
    rg_nlab = 0;
    i = 0;
    while i < rg_n {
        rg_dep[i] = 0;
        int st = rg_ls[i];
        int en = rg_end(st);
        if out_buf[st] == 'L' && out_buf[st + 1] >= '0' && out_buf[st + 1] <= '9' && out_buf[en - 1] == ':' && rg_nlab < 8192 {
            rg_labn[rg_nlab] = rg_num(st + 1);
            rg_labl[rg_nlab] = i;
            rg_nlab += 1;
        }
        i += 1;
    }
    // what the lines do
    i = 0;
    while i < rg_n && ok == 1 {
        int st = rg_ls[i];
        int en = rg_end(st);
        if rg_has(st, ";H") {
            i += 1;
            continue;
        }
        if rg_in(st, en, "x26") || rg_in(st, en, "j2k_try_enter") || (rg_in(st, en, "x27") && rg_in(st, en, "#784")) {
            ok = 0;
        }
        if rg_has(st, "mov x29,") { ok = 0; }
        // a branch backwards makes a loop: the lines in between count more
        if rg_has(st, "b ") || rg_has(st, "b.") || rg_has(st, "cbz ") || rg_has(st, "cbnz ") || rg_has(st, "tbz ") || rg_has(st, "tbnz ") {
            int q = en - 1;
            while q > st && out_buf[q] != 'L' && out_buf[q] != ' ' { q -= 1; }
            if out_buf[q] == 'L' && out_buf[q + 1] >= '0' && out_buf[q + 1] <= '9' {
                int target = rg_num(q + 1);
                int li = 0;
                while li < rg_nlab {
                    if rg_labn[li] == target && rg_labl[li] < i {
                        int j = rg_labl[li];
                        while j <= i {
                            rg_dep[j] += 1;
                            j += 1;
                        }
                    }
                    li += 1;
                }
            }
        }
        i += 1;
    }
    // the uses of x29
    i = 0;
    while i < rg_n && ok == 1 {
        int st = rg_ls[i];
        int en = rg_end(st);
        if rg_in(st, en, "x29") && !rg_has(st, ";H") {
            int n = rg_slot_use(st);
            if n >= 0 {
                if n % 8 == 0 && n / 8 < 8192 {
                    int d = rg_dep[i];
                    if d > 3 { d = 3; }
                    int wgt = 1;
                    while d > 0 {
                        wgt = wgt * 8;
                        d -= 1;
                    }
                    rg_wt[n / 8] += wgt;
                } else if n / 8 < 8192 {
                    rg_state[n / 8] = 2;
                }
            } else if rg_has(st, "add x29, sp, #0") || rg_has(st, "str x29, [sp, #0]") || rg_has(st, "ldr x29, [sp, #0]") {
                // the frame itself
            } else {
                // some other use: the places it touches are not free; with no number the frame is used in a way we cannot follow
                int p = st;
                while p < en && out_buf[p] != '#' { p += 1; }
                int has_x29 = 0;
                if rg_in(st, en, "x29, #") || rg_in(st, en, "[x29, #") { has_x29 = 1; }
                if has_x29 == 1 && p < en {
                    int nn = rg_num(p + 1);
                    if nn / 8 < 8191 {
                        rg_state[nn / 8] = 2;
                        rg_state[nn / 8 + 1] = 2;
                    }
                } else {
                    ok = 0;
                }
            }
        }
        if rg_has(st, "ldr x29, [sp, #0]") && epi < 0 { epi = i; }
        i += 1;
    }
    if is_main == 0 && epi < 0 { ok = 0; }
    // the choice: the slots with the biggest weight, if they pay for being saved and restored
    rg_npick = 0;
    if ok == 1 {
        int round = 0;
        while round < 7 {
            int best = 0 - 1;
            int bw = 5;                                       // at least 6 uses (weighted) to be worth two memory accesses
            int w = 0;
            while w < 8192 {
                if rg_state[w] == 1 && rg_slotreg[w] == 0 && rg_wt[w] > bw {
                    bw = rg_wt[w];
                    best = w;
                }
                w += 1;
            }
            if best >= 0 {
                rg_slotreg[best] = 19 + rg_npick;
                rg_pick[rg_npick] = best;
                rg_npick += 1;
            }
            round += 1;
        }
    }
    // write it
    i = 0;
    while i < rg_n {
        int st = rg_ls[i];
        int en = rg_end(st);
        if rg_has(st, ";H") {
            i += 1;
            continue;
        }
        if rg_npick > 0 {
            int n = 0 - 1;
            if rg_in(st, en, "x29") { n = rg_slot_use(st); }
            if n >= 0 && n % 8 == 0 && n / 8 < 8192 && rg_slotreg[n / 8] != 0 {
                int r = rg_reg;
                int load = rg_isload;
                int k = rg_slotreg[n / 8];
                rg_text("mov x");
                if load == 1 {
                    rg_int(r);
                    rg_text(", x");
                    rg_int(k);
                } else {
                    rg_int(k);
                    rg_text(", x");
                    rg_int(r);
                }
                rg_put(10);
                i += 1;
                continue;
            }
            if i == epi && is_main == 0 {
                int k2 = 0;
                while k2 < rg_npick {
                    rg_text("ldr x");
                    rg_int(19 + k2);
                    rg_text(", [sp, #");
                    rg_int(k2 * 8);
                    rg_text("]\n");
                    k2 += 1;
                }
                rg_text("add sp, sp, #");
                rg_int((rg_npick + 1) / 2 * 16);
                rg_put(10);
            }
        }
        rg_copy(st, en);
        if rg_npick > 0 && rg_has(st, "add x29, sp, #0") && is_main == 0 {
            rg_text("sub sp, sp, #");
            rg_int((rg_npick + 1) / 2 * 16);
            rg_put(10);
            int k3 = 0;
            while k3 < rg_npick {
                rg_text("str x");
                rg_int(19 + k3);
                rg_text(", [sp, #");
                rg_int(k3 * 8);
                rg_text("]\n");
                k3 += 1;
            }
        }
        i += 1;
    }
}

void regs_run() {
    regs_len = 0;
    int i = 0;
    int work = 1;
    if opt_regs == 0 || used_try == 1 { work = 0; }
    while i < out_len {
        int en = rg_end(i);
        if work == 1 && rg_is_func(i) {
            // the function: from its label to its last line (the ret after the first epilogue; for main the exit call)
            int is_main = 0;
            if rg_has(i, "main:\n") { is_main = 1; }
            rg_n = 0;
            int p = i;
            bool done = false;
            bool seen_epi = false;
            bool too_big = false;
            while p < out_len && !done {
                int pe = rg_end(p);
                if p != i && rg_is_func(p) { too_big = true; done = true; }
                else if rg_n >= 65535 { too_big = true; done = true; }
                else {
                    rg_ls[rg_n] = p;
                    rg_n += 1;
                    if rg_has(p, "ldr x29, [sp, #0]") { seen_epi = true; }
                    if seen_epi && rg_has(p, "ret\n") { done = true; }
                    if is_main == 1 && rg_has(p, "svc 0\n") { done = true; }
                }
                p = pe + 1;
            }
            if too_big || !done {
                // not understood (a helper of the runtime): its first line is copied, the lines after it are looked at one by one
                rg_copy(i, en);
                i = en + 1;
            } else {
                int fstart = regs_len;
                rg_function(is_main);
                if rg_npick > 0 || is_main == 1 { regs_post(fstart); }
                i = p;
            }
        } else {
            if !rg_has(i, ";H") { rg_copy(i, en); }
            i = en + 1;
        }
    }
    int t = 0;
    while t < regs_len {
        out_buf[t] = regs_buf[t];
        t += 1;
    }
    out_len = regs_len;
}

// ------------------------------------------------------------------------------------------------------------------------------
// The second part: after a function was written, the moves that the registers left behind are shortened:
//   mov x0, xK / mov x10, x0 (x0 not needed afterwards)       mov x10, xK
//   mov x0, xK / add x0, x0, #1 / mov xK, x0                  add xK, xK, #1
//   mov x1, x0 / mov x0, x10 / add x0, x0, x1 / mov xK, x0    add xK, x10, x0
//   mov x0, xA / mov x1, xB / cmp x0, x1 / b.lt L             cmp xA, xB / b.lt L
// "x0 is not needed afterwards" is looked up by following the code (labels, jumps, both ways of a conditional jump) until the
// register is written or read; whatever is not understood counts as "needed".
// The lines of the function are copied into slots of 64 bytes (a line that does not fit: the function is left as it is); a deleted
// line has an empty slot.

char pt_txt[4194304];
int pt_n;
char pt_m[64];               // a parsed line: the mnemonic and the operands (slot s: 16 + 4 * 40 bytes)
char pt_o[640];
int pt_no[4];

// parse the line idx into the slot s; false for a label, a deleted line or a line that is not an instruction
bool pt_parse(int s, int idx) {
    int b = idx * 64;
    if pt_txt[b] == 0 { return false; }
    int e = b;
    while pt_txt[e] != 0 { e += 1; }
    if pt_txt[e - 1] == ':' { return false; }
    int k = b;
    int m = s * 16;
    int mc = 0;
    while k < e && pt_txt[k] != ' ' && mc < 15 {
        pt_m[m + mc] = pt_txt[k];
        mc += 1;
        k += 1;
    }
    pt_m[m + mc] = 0;
    pt_no[s] = 0;
    while k < e {
        while k < e && pt_txt[k] == ' ' { k += 1; }
        if k < e && pt_no[s] < 4 {
            int o = (s * 4 + pt_no[s]) * 40;
            int oc = 0;
            int depth = 0;
            while k < e && !(pt_txt[k] == ',' && depth == 0) && oc < 39 {
                if pt_txt[k] == '[' { depth += 1; }
                if pt_txt[k] == ']' { depth -= 1; }
                pt_o[o + oc] = pt_txt[k];
                oc += 1;
                k += 1;
            }
            pt_o[o + oc] = 0;
            pt_no[s] += 1;
            if k < e && pt_txt[k] == ',' { k += 1; }
        }
    }
    return true;
}

bool pt_mn(int s, char^ t) {
    int m = s * 16;
    int i = 0;
    while t[i] != 0 {
        if pt_m[m + i] != t[i] { return false; }
        i += 1;
    }
    return pt_m[m + i] == 0;
}

bool pt_op(int s, int k, char^ t) {
    int o = (s * 4 + k) * 40;
    int i = 0;
    while t[i] != 0 {
        if pt_o[o + i] != t[i] { return false; }
        i += 1;
    }
    return pt_o[o + i] == 0;
}

// is the operand a plain register x0..x30 (not sp, not a number)?
bool pt_isreg(int s, int k) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != 'x' { return false; }
    int i = 1;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { i += 1; }
    return pt_o[o + i] == 0;
}

bool pt_isnum(int s, int k) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] { return false; }
    int i = 0;
    if pt_o[o] == '#' { i = 1; }
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { i += 1; }
    return pt_o[o + i] == 0;
}

// does the operand (s, k) mention the register r (as x r, w r, inside brackets too)?
bool pt_has_reg(int s, int k, int r) {
    int o = (s * 4 + k) * 40;
    int i = 0;
    while pt_o[o + i] != 0 {
        if (pt_o[o + i] == 'x' || pt_o[o + i] == 'w') && (i == 0 || (pt_o[o + i - 1] < 'a' || pt_o[o + i - 1] > 'z')) && pt_o[o + i + 1] >= '0' && pt_o[o + i + 1] <= '9' {
            int j = i + 1;
            int v = 0;
            while pt_o[o + j] >= '0' && pt_o[o + j] <= '9' {
                v = v * 10 + (pt_o[o + j] - '0');
                j += 1;
            }
            if v == r { return true; }
        }
        i += 1;
    }
    return false;
}

// the mnemonics whose first operand is only written
bool pt_writes_first(int s) {
    return pt_mn(s, "mov") || pt_mn(s, "ldr") || pt_mn(s, "ldrb") || pt_mn(s, "ldrh") || pt_mn(s, "ldrsw") || pt_mn(s, "ldrsb") || pt_mn(s, "ldrsh") || pt_mn(s, "add") || pt_mn(s, "sub") || pt_mn(s, "mul") || pt_mn(s, "sdiv") || pt_mn(s, "udiv") || pt_mn(s, "and") || pt_mn(s, "orr") || pt_mn(s, "eor") || pt_mn(s, "lsl") || pt_mn(s, "lsr") || pt_mn(s, "asr") || pt_mn(s, "neg") || pt_mn(s, "mvn") || pt_mn(s, "cset") || pt_mn(s, "smulh") || pt_mn(s, "umulh") || pt_mn(s, "msub") || pt_mn(s, "madd") || pt_mn(s, "sxtw") || pt_mn(s, "uxtb") || pt_mn(s, "uxth") || pt_mn(s, "sxtb") || pt_mn(s, "sxth") || pt_mn(s, "adr") || pt_mn(s, "fmov") || pt_mn(s, "fcvtzs") || pt_mn(s, "scvtf") || pt_mn(s, "ucvtf");
}

// the line index of the label L<n> in this function, or -1
int pt_label_at(int num) {
    int li = 0;
    while li < rg_nlab {
        if rg_labn[li] == num { return rg_labl[li]; }
        li += 1;
    }
    return 0 - 1;
}

// is the register r not needed any more from the line idx on? (slot 3 of the parse arrays is used)
bool pt_dead(int idx, int r, int budget) {
    while budget > 0 {
        if idx >= pt_n { return false; }
        budget -= 1;
        int b = idx * 64;
        if pt_txt[b] == 0 {
            idx += 1;
            continue;
        }
        if !pt_parse(3, idx) {
            idx += 1;                                     // a label
            continue;
        }
        if pt_mn(3, "b") {
            // the target label: "L123"
            int o = 3 * 4 * 40;
            if pt_o[o] != 'L' { return false; }
            int num = rg_numpt(o + 1);
            int at = pt_label_at(num);
            if at < 0 { return false; }
            idx = at;
            continue;
        }
        if pt_mn(3, "ret") { return r != 0; }                // only x0 carries the result
        if pt_mn(3, "mov") && pt_op(3, 0, "x8") && (pt_op(3, 1, "94") || pt_op(3, 1, "93")) { return r != 0; }       // the program ends: only x0 (the exit code) is read
        if pt_mn(3, "bl") || pt_mn(3, "blr") || pt_mn(3, "svc") || pt_mn(3, "br") {
            return false;
        }
        if pt_m[48] == 'b' && pt_m[49] == '.' {
            int o2 = 3 * 4 * 40;
            if pt_o[o2] != 'L' { return false; }
            int num2 = rg_numpt(o2 + 1);
            int at2 = pt_label_at(num2);
            if at2 < 0 { return false; }
            if !pt_dead(at2, r, budget / 2) { return false; }
            idx += 1;
            continue;
        }
        if pt_mn(3, "cbz") || pt_mn(3, "cbnz") || pt_mn(3, "tbz") || pt_mn(3, "tbnz") {
            return false;
        }
        bool first_only = pt_writes_first(3);
        int k = 0;
        bool reads = false;
        while k < pt_no[3] {
            if pt_has_reg(3, k, r) {
                if k == 0 && first_only {
                    // only written, unless it is also used in a memory operand or a source of the same line (checked below)
                } else {
                    reads = true;
                }
            }
            k += 1;
        }
        if reads { return false; }
        if first_only && pt_no[3] > 0 && pt_isreg(3, 0) && pt_has_reg(3, 0, r) {
            if pt_mn(3, "msub") || pt_mn(3, "madd") { return false; }
            return true;
        }
        idx += 1;
    }
    return false;
}

// the number in pt_o at index i
int rg_numpt(int i) {
    int v = 0;
    while pt_o[i] >= '0' && pt_o[i] <= '9' {
        v = v * 10 + (pt_o[i] - '0');
        i += 1;
    }
    return v;
}

// the line idx gets the text s (an empty text deletes it)
void pt_set(int idx, char^ t) {
    int b = idx * 64;
    int i = 0;
    while t[i] != 0 && i < 63 {
        pt_txt[b + i] = t[i];
        i += 1;
    }
    pt_txt[b + i] = 0;
}

// the next live line after idx (an instruction or a label), or -1
int pt_next(int idx) {
    idx += 1;
    while idx < pt_n && pt_txt[idx * 64] == 0 { idx += 1; }
    if idx >= pt_n { return 0 - 1; }
    return idx;
}

// build "mnem op1, op2, op3" from the slot s with the operand k replaced by the text r (r may be null)
char pt_line[64];
void pt_build(int s, int k, char^ r) {
    int n = 0;
    int m = s * 16;
    int i = 0;
    while pt_m[m + i] != 0 {
        pt_line[n] = pt_m[m + i];
        n += 1;
        i += 1;
    }
    int j = 0;
    while j < pt_no[s] {
        pt_line[n] = ',';
        if j == 0 { pt_line[n] = ' '; }
        n += 1;
        if j > 0 {
            pt_line[n] = ' ';
            n += 1;
        }
        int o = (s * 4 + j) * 40;
        int c = 0;
        if j == k && r != null {
            while r[c] != 0 {
                pt_line[n] = r[c];
                n += 1;
                c += 1;
            }
        } else {
            while pt_o[o + c] != 0 {
                pt_line[n] = pt_o[o + c];
                n += 1;
                c += 1;
            }
        }
        j += 1;
    }
    pt_line[n] = 0;
}

// one try of all the rules at the line i: true if something was changed
bool pt_rules(int i) {
    int j = pt_next(i);
    if j < 0 { return false; }
    if !pt_parse(0, i) { return false; }
    if !pt_parse(1, j) { return false; }
    // mov x0, S / mov D, x0     ->   mov D, S
    if pt_mn(0, "mov") && pt_op(0, 0, "x0") && pt_no[0] == 2 && pt_mn(1, "mov") && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_op(1, 0, "x0") && (pt_isreg(0, 1) || pt_isnum(0, 1)) && pt_dead(pt_next(j), 0, 40) {
        char dd[40];
        int o1 = (1 * 4 + 0) * 40;
        int o0 = (0 * 4 + 1) * 40;
        int c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        char nl[64];
        nl[0] = 'm'; nl[1] = 'o'; nl[2] = 'v'; nl[3] = ' ';
        int n = 4;
        c = 0;
        while dd[c] != 0 { nl[n] = dd[c]; n += 1; c += 1; }
        nl[n] = ','; nl[n + 1] = ' '; n += 2;
        c = 0;
        while pt_o[o0 + c] != 0 { nl[n] = pt_o[o0 + c]; n += 1; c += 1; }
        nl[n] = 0;
        pt_set(i, @nl);
        pt_set(j, "");
        return true;
    }
    // ldr x0, [...] / mov D, x0  ->  ldr D, [...]   (x0 not used by the address of the same load: it is written only)
    if pt_mn(0, "ldr") && pt_op(0, 0, "x0") && pt_no[0] == 2 && pt_mn(1, "mov") && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_op(1, 0, "x0") && pt_dead(pt_next(j), 0, 40) {
        int o1 = (1 * 4 + 0) * 40;
        char dd[40];
        int c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(0, 0, @dd);
        pt_set(i, @pt_line);
        pt_set(j, "");
        return true;
    }
    // OP x0, P, Q / mov D, x0   ->   OP D, P, Q
    if pt_writes_first(0) && !pt_mn(0, "mov") && !pt_mn(0, "ldr") && !pt_mn(0, "msub") && !pt_mn(0, "madd") && !pt_mn(0, "adr") && pt_op(0, 0, "x0") && pt_no[0] >= 3 && pt_mn(1, "mov") && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_op(1, 0, "x0") && pt_dead(pt_next(j), 0, 40) {
        int o1 = (1 * 4 + 0) * 40;
        char dd[40];
        int c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(0, 0, @dd);
        pt_set(i, @pt_line);
        pt_set(j, "");
        return true;
    }
    // mov x0, A / OP D, x0, Y  (Y is not x0)  ->  OP D, A, Y   when D is x0 or x0 is not needed afterwards
    if pt_mn(0, "mov") && pt_op(0, 0, "x0") && pt_no[0] == 2 && pt_isreg(0, 1) && !pt_op(0, 1, "x0") && pt_writes_first(1) && !pt_mn(1, "mov") && !pt_mn(1, "ldr") && !pt_mn(1, "msub") && !pt_mn(1, "madd") && !pt_mn(1, "adr") && pt_no[1] >= 3 && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_has_reg(1, 2, 0) {
        bool ok = pt_op(1, 0, "x0") || pt_dead(pt_next(j), 0, 40);
        if ok {
            int o0 = (0 * 4 + 1) * 40;
            char aa[40];
            int c = 0;
            while pt_o[o0 + c] != 0 { aa[c] = pt_o[o0 + c]; c += 1; }
            aa[c] = 0;
            pt_build(1, 1, @aa);
            pt_set(j, @pt_line);
            pt_set(i, "");
            return true;
        }
    }
    // mov x1, x0 / mov x0, S / OP D, x0, x1  ->  OP D, S, x0   (the two registers are not needed afterwards)
    int k2 = pt_next(j);
    if k2 >= 0 && pt_mn(0, "mov") && pt_op(0, 0, "x1") && pt_op(0, 1, "x0") && pt_mn(1, "mov") && pt_op(1, 0, "x0") && pt_no[1] == 2 && (pt_isreg(1, 1) || pt_isnum(1, 1)) && !pt_op(1, 1, "x1") && pt_parse(2, k2) {
        if pt_writes_first(2) && !pt_mn(2, "mov") && !pt_mn(2, "ldr") && !pt_mn(2, "msub") && !pt_mn(2, "madd") && !pt_mn(2, "adr") && pt_no[2] == 3 && pt_isreg(2, 0) && pt_op(2, 1, "x0") && pt_op(2, 2, "x1") && !pt_op(2, 0, "x0") && !pt_op(2, 0, "x1") {
            if pt_dead(pt_next(k2), 0, 40) && pt_dead(pt_next(k2), 1, 40) && pt_isreg(1, 1) {
                int o1 = (1 * 4 + 1) * 40;
                char ss[40];
                int c = 0;
                while pt_o[o1 + c] != 0 { ss[c] = pt_o[o1 + c]; c += 1; }
                ss[c] = 0;
                pt_build(2, 1, @ss);
                // the third operand becomes x0
                char tmp[64];
                int q = 0;
                while pt_line[q] != 0 { tmp[q] = pt_line[q]; q += 1; }
                tmp[q] = 0;
                // replace the last "x1" by "x0"
                q -= 1;
                tmp[q] = '0';
                pt_set(k2, @tmp);
                pt_set(i, "");
                pt_set(j, "");
                return true;
            }
        }
        // ... / cmp x0, x1  ->  cmp S, x0
        if pt_mn(2, "cmp") && pt_no[2] == 2 && pt_op(2, 0, "x0") && pt_op(2, 1, "x1") && pt_isreg(1, 1) {
            if pt_dead(pt_next(k2), 0, 40) && pt_dead(pt_next(k2), 1, 40) {
                int o1 = (1 * 4 + 1) * 40;
                char tmp2[64];
                int n = 0;
                tmp2[0] = 'c'; tmp2[1] = 'm'; tmp2[2] = 'p'; tmp2[3] = ' ';
                n = 4;
                int c = 0;
                while pt_o[o1 + c] != 0 { tmp2[n] = pt_o[o1 + c]; n += 1; c += 1; }
                tmp2[n] = ','; tmp2[n + 1] = ' '; tmp2[n + 2] = 'x'; tmp2[n + 3] = '0'; tmp2[n + 4] = 0;
                pt_set(k2, @tmp2);
                pt_set(i, "");
                pt_set(j, "");
                return true;
            }
        }
    }
    // mov x0, A / mov x1, B / cmp x0, x1  ->  cmp A, B    (and  mov x0, A / cmp x0, N  ->  cmp A, N)
    if pt_mn(0, "mov") && pt_op(0, 0, "x0") && pt_isreg(0, 1) && !pt_op(0, 1, "x0") && pt_mn(1, "cmp") && pt_op(1, 0, "x0") && pt_no[1] == 2 && pt_isnum(1, 1) {
        if pt_dead(pt_next(j), 0, 40) {
            int o0 = (0 * 4 + 1) * 40;
            int o1 = (1 * 4 + 1) * 40;
            char t3[64];
            int n = 0;
            t3[0] = 'c'; t3[1] = 'm'; t3[2] = 'p'; t3[3] = ' ';
            n = 4;
            int c = 0;
            while pt_o[o0 + c] != 0 { t3[n] = pt_o[o0 + c]; n += 1; c += 1; }
            t3[n] = ','; t3[n + 1] = ' ';
            n += 2;
            c = 0;
            while pt_o[o1 + c] != 0 { t3[n] = pt_o[o1 + c]; n += 1; c += 1; }
            t3[n] = 0;
            pt_set(j, @t3);
            pt_set(i, "");
            return true;
        }
    }
    if k2 >= 0 && pt_mn(0, "mov") && pt_op(0, 0, "x0") && pt_isreg(0, 1) && !pt_op(0, 1, "x0") && pt_mn(1, "mov") && pt_op(1, 0, "x1") && pt_isreg(1, 1) && !pt_op(1, 1, "x0") && pt_parse(2, k2) {
        if pt_mn(2, "cmp") && pt_op(2, 0, "x0") && pt_op(2, 1, "x1") && pt_dead(pt_next(k2), 0, 40) && pt_dead(pt_next(k2), 1, 40) {
            int o0 = (0 * 4 + 1) * 40;
            int o1 = (1 * 4 + 1) * 40;
            char t4[64];
            int n = 0;
            t4[0] = 'c'; t4[1] = 'm'; t4[2] = 'p'; t4[3] = ' ';
            n = 4;
            int c = 0;
            while pt_o[o0 + c] != 0 { t4[n] = pt_o[o0 + c]; n += 1; c += 1; }
            t4[n] = ','; t4[n + 1] = ' ';
            n += 2;
            c = 0;
            while pt_o[o1 + c] != 0 { t4[n] = pt_o[o1 + c]; n += 1; c += 1; }
            t4[n] = 0;
            pt_set(k2, @t4);
            pt_set(i, "");
            pt_set(j, "");
            return true;
        }
    }
    return false;
}

// shorten the function that was just written to regs_buf[start ..]
void regs_post(int start) {
    // the lines, and the labels
    int n = 0;
    int p = start;
    bool fits = true;
    rg_nlab = 0;
    while p < regs_len && fits {
        int e = p;
        while regs_buf[e] != 10 { e += 1; }
        if e - p > 62 || n >= 65535 {
            fits = false;
        } else {
            int c = 0;
            while p + c < e {
                pt_txt[n * 64 + c] = regs_buf[p + c];
                c += 1;
            }
            pt_txt[n * 64 + c] = 0;
            if regs_buf[p] == 'L' && regs_buf[p + 1] >= '0' && regs_buf[p + 1] <= '9' && regs_buf[e - 1] == ':' && rg_nlab < 8192 {
                int v = 0;
                int q = p + 1;
                while regs_buf[q] >= '0' && regs_buf[q] <= '9' {
                    v = v * 10 + (regs_buf[q] - '0');
                    q += 1;
                }
                rg_labn[rg_nlab] = v;
                rg_labl[rg_nlab] = n;
                rg_nlab += 1;
            }
            n += 1;
        }
        p = e + 1;
    }
    if !fits { return; }
    pt_n = n;
    int changed = 1;
    int rounds = 0;
    while changed == 1 && rounds < 8 {
        changed = 0;
        int i = 0;
        while i < pt_n {
            if pt_txt[i * 64] != 0 {
                if pt_rules(i) { changed = 1; }
            }
            i += 1;
        }
        rounds += 1;
    }
    regs_len = start;
    int i2 = 0;
    while i2 < pt_n {
        if pt_txt[i2 * 64] != 0 {
            int c2 = 0;
            while pt_txt[i2 * 64 + c2] != 0 {
                rg_put(pt_txt[i2 * 64 + c2]);
                c2 += 1;
            }
            rg_put(10);
        }
        i2 += 1;
    }
}
