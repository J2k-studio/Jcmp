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
int rg_skip[65536];
int rg_labn[8192];
int rg_labl[8192];
int rg_nlab;
int rg_pick[8];              // the slots that got a register
int rg_npick;
int rg_slotreg[8192];        // the register number (19..25) of a slot, or 0
int rg_slotd[8192];          // the double register number (8..15) of a slot, or 0
int rg_fl[8192];             // how many uses of the slot are conversions to and from a double register
int rg_tot[8192];            // how many uses the slot has
int rg_first[8192];          // the first and the last line where the slot is live
int rg_last[8192];
int rg_cand[8192];           // the slots that are looked at by the allocator
int rg_ncand;
int rg_cidx[8192];           // the number of a slot in rg_cand, or -1
int rg_live[524288];         // live-in sets: 8 words of 32 bits for each line (the first 256 candidates)
int rg_xsave[8];             // the frame slot where the old value of x(19 + k) is kept, or -1
int rg_dsave[8];             // the same for d(8 + k)
int rg_act[16];              // the slots that hold a register now (the linear scan)
int rg_nact;

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

// is the line at st "fmov dK, xR" (a double made from the x register R)?
bool rg_fmov_from(int st, int r) {
    if !rg_has(st, "fmov d") { return false; }
    int en = rg_end(st);
    int k = en - 1;
    while k > st && out_buf[k] >= '0' && out_buf[k] <= '9' { k -= 1; }
    if out_buf[k] != 'x' || out_buf[k - 1] != ' ' { return false; }
    return rg_num(k + 1) == r && rg_next == en;
}

// is the line at st "fmov xR, dK"?
bool rg_fmov_to(int st, int r) {
    if !rg_has(st, "fmov x") { return false; }
    int num = rg_num(st + 6);
    return num == r && rg_has(rg_next, ", d");
}

// the bit of candidate c (0..255) in the live set of the line i: word index, mask
bool rg_lv_get(int line, int c) {
    return (rg_live[line * 8 + c / 32] >> (c % 32)) % 2 == 1;
}

void rg_lv_set(int line, int c) {
    if !rg_lv_get(line, c) { rg_live[line * 8 + c / 32] += 1 << (c % 32); }
}

// the live variable analysis for the candidates, then a linear scan: the slots that are live at the same time get different
// registers, slots whose lives do not meet may share one
void rg_allocate(int epi, int is_main) {
    // the candidates: the slots that may move and are used often enough, the busiest 256
    rg_ncand = 0;
    int w = 0;
    while w < 8192 {
        rg_cidx[w] = 0 - 1;
        w += 1;
    }
    int thr = 3;
    int rounds = 0;
    while rounds < 300 {
        // the busiest slot that is not taken yet
        int best = 0 - 1;
        int bw = thr;
        w = 0;
        while w < 8192 {
            if rg_state[w] == 1 && rg_cidx[w] < 0 && rg_wt[w] > bw {
                bw = rg_wt[w];
                best = w;
            }
            w += 1;
        }
        if best < 0 || rg_ncand >= 256 { rounds = 300; }
        else {
            rg_cidx[best] = rg_ncand;
            rg_cand[rg_ncand] = best;
            rg_ncand += 1;
            rounds += 1;
        }
    }
    if rg_ncand == 0 { return; }
    // live-in sets: use[i] = a load of the slot, def[i] = a store of it; go backwards until nothing changes
    int i = 0;
    while i < rg_n * 8 {
        rg_live[i] = 0;
        i += 1;
    }
    int pass = 0;
    bool changed = true;
    while changed && pass < 50 {
        changed = false;
        pass += 1;
        i = rg_n - 1;
        while i >= 0 {
            int st = rg_ls[i];
            int en = rg_end(st);
            // the successors: the next line unless this one ends the flow; the target of a jump
            int lo0 = 0;
            int lo1 = 0;
            int lo2 = 0;
            int lo3 = 0;
            int lo4 = 0;
            int lo5 = 0;
            int lo6 = 0;
            int lo7 = 0;
            bool falls = true;
            bool is_ret = rg_has(st, "ret\n");
            if is_ret { falls = false; }
            int tgt = 0 - 1;
            bool is_b = rg_has(st, "b ");
            if is_b || rg_has(st, "b.") || rg_has(st, "cbz ") || rg_has(st, "cbnz ") || rg_has(st, "tbz ") || rg_has(st, "tbnz ") {
                int q = en - 1;
                while q > st && out_buf[q] != 'L' && out_buf[q] != ' ' { q -= 1; }
                if out_buf[q] == 'L' && out_buf[q + 1] >= '0' && out_buf[q + 1] <= '9' {
                    int target = rg_num(q + 1);
                    int li = 0;
                    while li < rg_nlab {
                        if rg_labn[li] == target { tgt = rg_labl[li]; }
                        li += 1;
                    }
                }
                if is_b { falls = false; }
            }
            if falls && i + 1 < rg_n {
                lo0 = rg_live[(i + 1) * 8];
                lo1 = rg_live[(i + 1) * 8 + 1];
                lo2 = rg_live[(i + 1) * 8 + 2];
                lo3 = rg_live[(i + 1) * 8 + 3];
                lo4 = rg_live[(i + 1) * 8 + 4];
                lo5 = rg_live[(i + 1) * 8 + 5];
                lo6 = rg_live[(i + 1) * 8 + 6];
                lo7 = rg_live[(i + 1) * 8 + 7];
            }
            if tgt >= 0 {
                lo0 = lo0 | rg_live[tgt * 8];
                lo1 = lo1 | rg_live[tgt * 8 + 1];
                lo2 = lo2 | rg_live[tgt * 8 + 2];
                lo3 = lo3 | rg_live[tgt * 8 + 3];
                lo4 = lo4 | rg_live[tgt * 8 + 4];
                lo5 = lo5 | rg_live[tgt * 8 + 5];
                lo6 = lo6 | rg_live[tgt * 8 + 6];
                lo7 = lo7 | rg_live[tgt * 8 + 7];
            }
            // this line: a store kills, a load makes live
            int c = 0 - 1;
            bool is_load = false;
            if rg_skip[i] == 0 && rg_in(st, en, "x29") {
                int n = rg_slot_use(st);
                if n >= 0 && n % 8 == 0 && n / 8 < 8192 {
                    c = rg_cidx[n / 8];
                    is_load = rg_isload == 1;
                }
            }
            if c >= 0 {
                int wd = c / 32;
                int mk = 1 << (c % 32);
                int cur = lo0;
                if wd == 1 { cur = lo1; }
                if wd == 2 { cur = lo2; }
                if wd == 3 { cur = lo3; }
                if wd == 4 { cur = lo4; }
                if wd == 5 { cur = lo5; }
                if wd == 6 { cur = lo6; }
                if wd == 7 { cur = lo7; }
                if is_load { cur = cur | mk; } else { cur = (cur | mk) - mk; }
                if wd == 0 { lo0 = cur; }
                if wd == 1 { lo1 = cur; }
                if wd == 2 { lo2 = cur; }
                if wd == 3 { lo3 = cur; }
                if wd == 4 { lo4 = cur; }
                if wd == 5 { lo5 = cur; }
                if wd == 6 { lo6 = cur; }
                if wd == 7 { lo7 = cur; }
            }
            if rg_live[i * 8] != lo0 || rg_live[i * 8 + 1] != lo1 || rg_live[i * 8 + 2] != lo2 || rg_live[i * 8 + 3] != lo3 || rg_live[i * 8 + 4] != lo4 || rg_live[i * 8 + 5] != lo5 || rg_live[i * 8 + 6] != lo6 || rg_live[i * 8 + 7] != lo7 {
                changed = true;
                rg_live[i * 8] = lo0;
                rg_live[i * 8 + 1] = lo1;
                rg_live[i * 8 + 2] = lo2;
                rg_live[i * 8 + 3] = lo3;
                rg_live[i * 8 + 4] = lo4;
                rg_live[i * 8 + 5] = lo5;
                rg_live[i * 8 + 6] = lo6;
                rg_live[i * 8 + 7] = lo7;
            }
            i -= 1;
        }
    }
    if changed { return; }                                      // not settled: no allocation (should not happen)
    // the intervals: from the first line where the slot is live (or stored) to the last one
    int c2 = 0;
    while c2 < rg_ncand {
        rg_first[c2] = 1000000;
        rg_last[c2] = 0 - 1;
        c2 += 1;
    }
    i = 0;
    while i < rg_n {
        int c3 = 0;
        while c3 < rg_ncand {
            if rg_lv_get(i, c3) {
                if i < rg_first[c3] { rg_first[c3] = i; }
                if i > rg_last[c3] { rg_last[c3] = i; }
            }
            c3 += 1;
        }
        // a store makes the slot live after it, a load before: both ends count
        int st = rg_ls[i];
        int en = rg_end(st);
        if rg_skip[i] == 0 && rg_in(st, en, "x29") {
            int n = rg_slot_use(st);
            if n >= 0 && n % 8 == 0 && n / 8 < 8192 {
                int cc = rg_cidx[n / 8];
                if cc >= 0 {
                    if i < rg_first[cc] { rg_first[cc] = i; }
                    if i > rg_last[cc] { rg_last[cc] = i; }
                }
            }
        }
        i += 1;
    }
    // the linear scan, by the start of the interval: x registers 19..25 for whole numbers, d8..d15 for doubles
    int done = 0;
    int taken[256];
    c2 = 0;
    while c2 < rg_ncand {
        taken[c2] = 0;
        c2 += 1;
    }
    int xowner[8];
    int downer[8];
    int k = 0;
    while k < 8 {
        xowner[k] = 0 - 1;
        downer[k] = 0 - 1;
        k += 1;
    }
    while done < rg_ncand {
        // the interval that starts first among the ones not done
        int cur = 0 - 1;
        c2 = 0;
        while c2 < rg_ncand {
            if taken[c2] == 0 && rg_last[c2] >= 0 && (cur < 0 || rg_first[c2] < rg_first[cur]) { cur = c2; }
            c2 += 1;
        }
        if cur < 0 { done = rg_ncand; }
        else {
            taken[cur] = 1;
            done += 1;
            int slot = rg_cand[cur];
            bool is_d = rg_fl[slot] * 2 >= rg_tot[slot] && rg_tot[slot] > 0;
            int nreg = 7;
            if is_d { nreg = 8; }
            // free the registers whose owner ended before this interval starts
            k = 0;
            while k < nreg {
                int ow = xowner[k];
                if is_d { ow = downer[k]; }
                if ow >= 0 && rg_last[ow] < rg_first[cur] {
                    if is_d { downer[k] = 0 - 1; } else { xowner[k] = 0 - 1; }
                }
                k += 1;
            }
            // a free register, else the owner with the smallest weight if it is smaller than this one
            int pick = 0 - 1;
            k = 0;
            while k < nreg && pick < 0 {
                int ow2 = xowner[k];
                if is_d { ow2 = downer[k]; }
                if ow2 < 0 { pick = k; }
                k += 1;
            }
            if pick < 0 {
                int low = 0 - 1;
                k = 0;
                while k < nreg {
                    int ow3 = xowner[k];
                    if is_d { ow3 = downer[k]; }
                    if low < 0 || rg_wt[rg_cand[ow3]] < rg_wt[rg_cand[low]] { low = ow3; pick = k; }
                    k += 1;
                }
                if rg_wt[rg_cand[low]] < rg_wt[slot] {
                    // the old owner stays in memory
                    int os = rg_cand[low];
                    rg_slotreg[os] = 0;
                    rg_slotd[os] = 0;
                } else {
                    pick = 0 - 1;
                }
            }
            if pick >= 0 {
                if is_d {
                    downer[pick] = cur;
                    rg_slotd[slot] = 8 + pick;
                    if rg_dsave[pick] < 0 { rg_dsave[pick] = slot; }
                } else {
                    xowner[pick] = cur;
                    rg_slotreg[slot] = 19 + pick;
                    if rg_xsave[pick] < 0 { rg_xsave[pick] = slot; }
                }
            }
        }
    }
    // a register whose first owner was thrown out may have lost its save slot: any slot that has the register will do
    k = 0;
    while k < 8 {
        rg_xsave[k] = 0 - 1;
        rg_dsave[k] = 0 - 1;
        k += 1;
    }
    w = 0;
    while w < 8192 {
        if rg_slotreg[w] != 0 {
            rg_npick += 1;
            if rg_xsave[rg_slotreg[w] - 19] < 0 { rg_xsave[rg_slotreg[w] - 19] = w; }
        }
        if rg_slotd[w] != 0 {
            rg_npick += 1;
            if rg_dsave[rg_slotd[w] - 8] < 0 { rg_dsave[rg_slotd[w] - 8] = w; }
        }
        w += 1;
    }
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
        rg_slotd[s] = 0;
        rg_fl[s] = 0;
        rg_tot[s] = 0;
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
    // an address that is computed and thrown away at once ("add x0, x29, #N" and then a load into x0 that does not use x0): the pair of
    // lines is not a use of the slot
    i = 0;
    while i < rg_n {
        rg_skip[i] = 0;
        if i + 1 < rg_n && rg_has(rg_ls[i], "add x0, x29, #") && rg_has(rg_ls[i + 1], "ldr x0, [x") && !rg_has(rg_ls[i + 1], "ldr x0, [x0") {
            rg_skip[i] = 1;
        }
        i += 1;
    }
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
        if rg_has(st, ";H") || rg_skip[i] == 1 {
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
        if rg_in(st, en, "x29") && !rg_has(st, ";H") && rg_skip[i] == 0 {
            int n = rg_slot_use(st);
            if n >= 0 {
                if n % 8 == 0 && n / 8 < 8192 {
                    rg_tot[n / 8] += 1;
                    if rg_isload == 1 && i + 1 < rg_n && rg_fmov_from(rg_ls[i + 1], rg_reg) { rg_fl[n / 8] += 1; }
                    if rg_isload == 0 && i > 0 && rg_fmov_to(rg_ls[i - 1], rg_reg) { rg_fl[n / 8] += 1; }
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
    // the allocation: live variable analysis, then a linear scan over the live intervals of the slots that are used most
    rg_npick = 0;
    int k0 = 0;
    while k0 < 8 {
        rg_xsave[k0] = 0 - 1;
        rg_dsave[k0] = 0 - 1;
        k0 += 1;
    }
    if ok == 1 {
        rg_allocate(epi, is_main);
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
        if rg_skip[i] == 1 && rg_npick > 0 {
            i += 1;
            continue;
        }
        if rg_npick > 0 {
            int n = 0 - 1;
            if rg_in(st, en, "x29") { n = rg_slot_use(st); }
            if n >= 0 && n % 8 == 0 && n / 8 < 8192 && (rg_slotreg[n / 8] != 0 || rg_slotd[n / 8] != 0) {
                int r = rg_reg;
                int load = rg_isload;
                if rg_slotreg[n / 8] != 0 {
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
                } else {
                    int kd = rg_slotd[n / 8];
                    rg_text("fmov ");
                    if load == 1 {
                        rg_text("x");
                        rg_int(r);
                        rg_text(", d");
                        rg_int(kd);
                    } else {
                        rg_text("d");
                        rg_int(kd);
                        rg_text(", x");
                        rg_int(r);
                    }
                }
                rg_put(10);
                i += 1;
                continue;
            }
            if i == epi && is_main == 0 {
                int k2 = 0;
                while k2 < 8 {
                    if rg_xsave[k2] >= 0 {
                        rg_text("ldr x");
                        rg_int(19 + k2);
                        rg_text(", [x29, #");
                        rg_int(rg_xsave[k2] * 8);
                        rg_text("]\n");
                    }
                    if rg_dsave[k2] >= 0 {
                        rg_text("ldr d");
                        rg_int(8 + k2);
                        rg_text(", [x29, #");
                        rg_int(rg_dsave[k2] * 8);
                        rg_text("]\n");
                    }
                    k2 += 1;
                }
            }
        }
        rg_copy(st, en);
        if rg_npick > 0 && rg_has(st, "add x29, sp, #0") && is_main == 0 {
            // the frame slots of the moved variables are free now: the old values of the registers are kept there
            int k3 = 0;
            while k3 < 8 {
                if rg_xsave[k3] >= 0 {
                    rg_text("str x");
                    rg_int(19 + k3);
                    rg_text(", [x29, #");
                    rg_int(rg_xsave[k3] * 8);
                    rg_text("]\n");
                }
                if rg_dsave[k3] >= 0 {
                    rg_text("str d");
                    rg_int(8 + k3);
                    rg_text(", [x29, #");
                    rg_int(rg_dsave[k3] * 8);
                    rg_text("]\n");
                }
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
                if opt_regs == 1 { regs_post(fstart); }
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

// does the operand (s, k) mention the double register dn (as dN or sN)?
bool pt_has_dreg(int s, int k, int dn) {
    int o = (s * 4 + k) * 40;
    int i = 0;
    while pt_o[o + i] != 0 {
        if (pt_o[o + i] == 'd' || pt_o[o + i] == 's') && (i == 0 || (pt_o[o + i - 1] < 'a' || pt_o[o + i - 1] > 'z')) && pt_o[o + i + 1] >= '0' && pt_o[o + i + 1] <= '9' {
            int j = i + 1;
            int v = 0;
            while pt_o[o + j] >= '0' && pt_o[o + j] <= '9' {
                v = v * 10 + (pt_o[o + j] - '0');
                j += 1;
            }
            if v == dn && (pt_o[o + j] == 0 || pt_o[o + j] == ',' || pt_o[o + j] == ']' || pt_o[o + j] == ' ') { return true; }
        }
        i += 1;
    }
    return false;
}

// the register r (0..30: x, 32..63: d) is mentioned by the operand (s, k)
bool pt_rd(int s, int k, int r) {
    if r >= 32 { return pt_has_dreg(s, k, r - 32); }
    return pt_has_reg(s, k, r);
}

// the mnemonics whose first operand is only written
bool pt_writes_first(int s) {
    return pt_mn(s, "mov") || pt_mn(s, "ldr") || pt_mn(s, "ldrb") || pt_mn(s, "ldrh") || pt_mn(s, "ldrsw") || pt_mn(s, "ldrsb") || pt_mn(s, "ldrsh") || pt_mn(s, "add") || pt_mn(s, "sub") || pt_mn(s, "mul") || pt_mn(s, "sdiv") || pt_mn(s, "udiv") || pt_mn(s, "and") || pt_mn(s, "orr") || pt_mn(s, "eor") || pt_mn(s, "lsl") || pt_mn(s, "lsr") || pt_mn(s, "asr") || pt_mn(s, "neg") || pt_mn(s, "mvn") || pt_mn(s, "cset") || pt_mn(s, "smulh") || pt_mn(s, "umulh") || pt_mn(s, "msub") || pt_mn(s, "madd") || pt_mn(s, "sxtw") || pt_mn(s, "uxtb") || pt_mn(s, "uxth") || pt_mn(s, "sxtb") || pt_mn(s, "sxth") || pt_mn(s, "adr") || pt_mn(s, "fmov") || pt_mn(s, "fcvtzs") || pt_mn(s, "scvtf") || pt_mn(s, "ucvtf") || pt_mn(s, "fadd") || pt_mn(s, "fsub") || pt_mn(s, "fmul") || pt_mn(s, "fdiv") || pt_mn(s, "fsqrt") || pt_mn(s, "fneg") || pt_mn(s, "fabs") || pt_mn(s, "fcvt") || pt_mn(s, "frintm") || pt_mn(s, "frintp") || pt_mn(s, "frintz");
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
int pt_steps;
bool pt_dead(int idx, int r, int budget) {
    if budget == 40 { pt_steps = 400; }                  // a new question: the whole search may take 400 lines
    while pt_steps > 0 {
        if idx >= pt_n { return false; }
        pt_steps -= 1;
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
        // d0..d7 and d16..d31 are scratch registers for the calls; d8..d15 keep their value over a call (and are given back at the end)
        if r >= 32 && (r < 40 || r >= 48) && (pt_mn(3, "ret") || pt_mn(3, "bl") || pt_mn(3, "blr") || pt_mn(3, "svc")) { return true; }
        if r >= 40 && r < 48 && (pt_mn(3, "ret") || pt_mn(3, "svc")) { return false; }
        if r >= 40 && r < 48 && (pt_mn(3, "bl") || pt_mn(3, "blr")) {
            idx += 1;
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
            if !pt_dead(at2, r, 1) { return false; }
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
            if pt_rd(3, k, r) {
                if k == 0 && first_only {
                    // only written, unless it is also used in a memory operand or a source of the same line (checked below)
                } else {
                    reads = true;
                }
            }
            k += 1;
        }
        if reads { return false; }
        if first_only && pt_no[3] > 0 && (pt_isreg(3, 0) || pt_regno(3, 0, 'd') >= 0) && pt_rd(3, 0, r) {
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

// the mnemonics in which a register that is read may be replaced by a copy of it
bool pt_copy_ok(int s) {
    return pt_mn(s, "add") || pt_mn(s, "sub") || pt_mn(s, "mul") || pt_mn(s, "sdiv") || pt_mn(s, "udiv") || pt_mn(s, "and") || pt_mn(s, "orr") || pt_mn(s, "eor") || pt_mn(s, "lsl") || pt_mn(s, "lsr") || pt_mn(s, "asr") || pt_mn(s, "cmp") || pt_mn(s, "str") || pt_mn(s, "ldr") || pt_mn(s, "strb") || pt_mn(s, "ldrb") || pt_mn(s, "ldrsb") || pt_mn(s, "ldrsw") || pt_mn(s, "strh") || pt_mn(s, "ldrh") || pt_mn(s, "fmov") || pt_mn(s, "scvtf") || pt_mn(s, "neg") || pt_mn(s, "mvn") || pt_mn(s, "sxtw") || pt_mn(s, "uxtb") || pt_mn(s, "sxtb") || pt_mn(s, "msub") || pt_mn(s, "madd") || pt_mn(s, "smulh") || pt_mn(s, "mov");
}

// the line of the slot s with every x<r> that is read replaced by the text rep, in pt_line; returns how many were replaced
// (the first operand is a destination, and is left as it is, for the mnemonics that write their first operand)
char pt_sub_prefix;
int pt_subst(int s, int r, char^ rep, bool dest_first) {
    int n = 0;
    int m = s * 16;
    int i = 0;
    int count = 0;
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
        while pt_o[o + c] != 0 {
            bool hit = false;
            if pt_o[o + c] == pt_sub_prefix && (c == 0 || pt_o[o + c - 1] < 'a' || pt_o[o + c - 1] > 'z') && pt_o[o + c + 1] >= '0' && pt_o[o + c + 1] <= '9' && !(j == 0 && dest_first) {
                int q = c + 1;
                int v = 0;
                while pt_o[o + q] >= '0' && pt_o[o + q] <= '9' {
                    v = v * 10 + (pt_o[o + q] - '0');
                    q += 1;
                }
                if v == r {
                    int t = 0;
                    while rep[t] != 0 {
                        pt_line[n] = rep[t];
                        n += 1;
                        t += 1;
                    }
                    c = q;
                    count += 1;
                    hit = true;
                }
            }
            if !hit {
                pt_line[n] = pt_o[o + c];
                n += 1;
                c += 1;
            }
        }
        j += 1;
    }
    pt_line[n] = 0;
    return count;
}

// the number N of the operand (s, k) when it is written <prefix>N, else -1
int pt_regno(int s, int k, char prefix) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != prefix { return 0 - 1; }
    int i = 1;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return 0 - 1; }
    int v = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] != 0 { return 0 - 1; }
    return v;
}

int pt_val[64];              // the value number of each register: x0..x30 are 0..30, d0..d31 are 32..63 (0: not known)
int pt_vnext;

void pt_vn_clear() {
    int i = 0;
    while i < 64 {
        pt_val[i] = 0;
        i += 1;
    }
}

int pt_vn_get(int r) {
    if pt_val[r] == 0 {
        pt_vnext += 1;
        pt_val[r] = pt_vnext;
    }
    return pt_val[r];
}

void pt_vn_fresh(int r) {
    pt_vnext += 1;
    pt_val[r] = pt_vnext;
}

// a double register (32 + n) other than skip that holds the value id, or -1
int pt_vn_find_d(int id, int skip) {
    int i = 32;
    while i < 64 {
        if pt_val[i] == id && i != skip { return i; }
        i += 1;
    }
    return 0 - 1;
}

// the mnemonics that write a double register as their first operand
bool pt_writes_d(int s) {
    return pt_mn(s, "fadd") || pt_mn(s, "fsub") || pt_mn(s, "fmul") || pt_mn(s, "fdiv") || pt_mn(s, "fsqrt") || pt_mn(s, "fneg") || pt_mn(s, "fabs") || pt_mn(s, "scvtf") || pt_mn(s, "ucvtf") || pt_mn(s, "fcvt") || pt_mn(s, "frintm") || pt_mn(s, "frintp") || pt_mn(s, "frintz") || pt_mn(s, "fmov") || pt_mn(s, "ldr");
}

// the mnemonics that write nothing that matters here
bool pt_writes_nothing(int s) {
    return pt_mn(s, "str") || pt_mn(s, "strb") || pt_mn(s, "strh") || pt_mn(s, "cmp") || pt_mn(s, "fcmp") || pt_mn(s, "b") || (pt_m[s * 16] == 'b' && pt_m[s * 16 + 1] == '.') || pt_mn(s, "cbz") || pt_mn(s, "cbnz") || pt_mn(s, "tbz") || pt_mn(s, "tbnz") || pt_mn(s, "tst") || pt_mn(s, "nop");
}

// the line "mnemonic dA, dB" written into pt_line
void pt_line_dd(char^ mn, int a, int b) {
    int n = 0;
    while mn[n] != 0 {
        pt_line[n] = mn[n];
        n += 1;
    }
    pt_line[n] = ' ';
    pt_line[n + 1] = 'd';
    n += 2;
    char dg[8];
    int dn = 0;
    int dv = a;
    if dv == 0 { dg[0] = '0'; dn = 1; }
    while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
    while dn > 0 { dn -= 1; pt_line[n] = dg[dn]; n += 1; }
    pt_line[n] = ',';
    pt_line[n + 1] = ' ';
    pt_line[n + 2] = 'd';
    n += 3;
    dv = b;
    dn = 0;
    if dv == 0 { dg[0] = '0'; dn = 1; }
    while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
    while dn > 0 { dn -= 1; pt_line[n] = dg[dn]; n += 1; }
    pt_line[n] = 0;
}

// one pass over the lines with value numbers: a register that already holds a value is not loaded again, a double register that
// holds a value is used instead of the x register that holds the same bits
bool pt_mirror() {
    bool changed = false;
    pt_vn_clear();
    int i = 0;
    while i < pt_n {
        if pt_txt[i * 64] != 0 {
            if !pt_parse(0, i) {
                pt_vn_clear();                                   // a label: the flow comes from elsewhere too
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'x') >= 0 {
                int dk = 32 + pt_regno(0, 0, 'd');
                int xn = pt_regno(0, 1, 'x');
                int id = pt_vn_get(xn);
                if pt_val[dk] == id {
                    pt_set(i, "");
                    changed = true;
                } else {
                    int dm = pt_vn_find_d(id, dk);
                    if dm >= 0 {
                        pt_line_dd("fmov", dk - 32, dm - 32);
                        pt_set(i, @pt_line);
                        changed = true;
                    }
                    pt_val[dk] = id;
                }
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 {
                int xn2 = pt_regno(0, 0, 'x');
                int id2 = pt_vn_get(32 + pt_regno(0, 1, 'd'));
                if pt_val[xn2] == id2 {
                    pt_set(i, "");
                    changed = true;
                } else {
                    pt_val[xn2] = id2;
                }
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 {
                int dk3 = 32 + pt_regno(0, 0, 'd');
                int id3 = pt_vn_get(32 + pt_regno(0, 1, 'd'));
                if pt_val[dk3] == id3 {
                    pt_set(i, "");
                    changed = true;
                } else {
                    pt_val[dk3] = id3;
                }
            } else if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 {
                int a = pt_regno(0, 0, 'x');
                int b = pt_regno(0, 1, 'x');
                if b >= 0 {
                    int id4 = pt_vn_get(b);
                    if pt_val[a] == id4 {
                        pt_set(i, "");
                        changed = true;
                    } else {
                        pt_val[a] = id4;
                    }
                } else {
                    pt_vn_fresh(a);
                }
            } else if pt_mn(0, "bl") || pt_mn(0, "blr") || pt_mn(0, "svc") || pt_mn(0, "br") || pt_mn(0, "ret") {
                pt_vn_clear();
            } else if pt_writes_nothing(0) {
                // nothing changes
            } else if pt_no[0] >= 1 && pt_regno(0, 0, 'd') >= 0 && pt_writes_d(0) {
                // an operation on doubles: when both sources hold the same value, the second source is the first
                int dd0 = 32 + pt_regno(0, 0, 'd');
                if pt_no[0] == 3 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 2, 'd') >= 0 && pt_regno(0, 1, 'd') != pt_regno(0, 2, 'd') && pt_val[32 + pt_regno(0, 1, 'd')] != 0 && pt_val[32 + pt_regno(0, 1, 'd')] == pt_val[32 + pt_regno(0, 2, 'd')] && !pt_mn(0, "ldr") {
                    int r1 = pt_regno(0, 1, 'd');
                    char nl2[40];
                    int n2 = 0;
                    int m0 = 0;
                    while pt_m[m0] != 0 { nl2[n2] = pt_m[m0]; n2 += 1; m0 += 1; }
                    nl2[n2] = ' ';
                    n2 += 1;
                    // dD, dR1, dR1
                    char dg[8];
                    int dn = 0;
                    int pass = 0;
                    while pass < 3 {
                        int v = pt_regno(0, 0, 'd');
                        if pass > 0 { v = r1; }
                        nl2[n2] = 'd';
                        n2 += 1;
                        dn = 0;
                        if v == 0 { dg[0] = '0'; dn = 1; }
                        while v > 0 { dg[dn] = '0' + v % 10; v = v / 10; dn += 1; }
                        while dn > 0 { dn -= 1; nl2[n2] = dg[dn]; n2 += 1; }
                        if pass < 2 { nl2[n2] = ','; nl2[n2 + 1] = ' '; n2 += 2; }
                        pass += 1;
                    }
                    nl2[n2] = 0;
                    pt_set(i, @nl2);
                    changed = true;
                }
                pt_vn_fresh(dd0);
            } else if pt_no[0] >= 1 && pt_regno(0, 0, 'x') >= 0 && pt_writes_first(0) {
                pt_vn_fresh(pt_regno(0, 0, 'x'));
            } else {
                pt_vn_clear();                                   // not understood
            }
        }
        i += 1;
    }
    return changed;
}

// one try of all the rules at the line i: true if something was changed
bool pt_rules(int i) {
    int j = pt_next(i);
    if j < 0 { return false; }
    if !pt_parse(0, i) { return false; }
    if !pt_parse(1, j) { return false; }
    // mov x0, S / (a line that does not touch x0 and S) / I  ->  I with S in place of x0   (and the same for x1): when I writes
    // x0 itself, or x0 is not needed afterwards
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) && (pt_op(0, 0, "x0") || pt_op(0, 0, "x1")) {
        int rr = 0;
        if pt_op(0, 0, "x1") { rr = 1; }
        int sreg = 0;
        {
            int o0s = (0 * 4 + 1) * 40;
            int cs = 1;
            while pt_o[o0s + cs] >= '0' && pt_o[o0s + cs] <= '9' {
                sreg = sreg * 10 + (pt_o[o0s + cs] - '0');
                cs += 1;
            }
        }
        if sreg != rr {
            char sx[40];
            int o0 = (0 * 4 + 1) * 40;
            int c = 0;
            while pt_o[o0 + c] != 0 { sx[c] = pt_o[o0 + c]; c += 1; }
            sx[c] = 0;
            int jj = j;
            int tries = 0;
            while jj >= 0 && tries < 3 {
                if !pt_parse(1, jj) { break; }
                bool mentions = false;
                int kq = 0;
                while kq < pt_no[1] {
                    if pt_has_reg(1, kq, rr) { mentions = true; }
                    kq += 1;
                }
                if mentions {
                    if pt_copy_ok(1) && !pt_mn(1, "mov") {
                        bool dest_r = pt_writes_first(1) && pt_isreg(1, 0) && pt_has_reg(1, 0, rr);
                        pt_sub_prefix = 'x';
            int cnt = pt_subst(1, rr, @sx, pt_writes_first(1));
                        if cnt > 0 && (dest_r || pt_dead(pt_next(jj), rr, 40)) {
                            char nl[64];
                            int q = 0;
                            while pt_line[q] != 0 { nl[q] = pt_line[q]; q += 1; }
                            nl[q] = 0;
                            pt_set(jj, @nl);
                            pt_set(i, "");
                            return true;
                        }
                    }
                    break;
                }
                // not touching x<rr>: it may stay in between if it does not write S and is a plain register write
                if !(pt_writes_first(1) && (pt_isreg(1, 0) || pt_o[(1 * 4) * 40] == 'd') && !pt_has_reg(1, 0, sreg) && !pt_mn(1, "ldr") && !pt_mn(1, "ldrb")) { break; }
                jj = pt_next(jj);
                tries += 1;
            }
            // the rules below use the lines i and j again
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // add xA, xA, #N / ldr xR, [xA, #0]  ->  ldr xR, [xA, #N]  (also str, ldrb, strb): the address is not needed afterwards
    if pt_mn(0, "add") && pt_no[0] == 3 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isnum(0, 2) && (pt_mn(1, "ldr") || pt_mn(1, "str") || pt_mn(1, "ldrb") || pt_mn(1, "strb")) && pt_no[1] == 2 {
        int o2 = (0 * 4 + 2) * 40;
        int off = 0;
        int c2 = 0;
        if pt_o[o2] == '#' { c2 = 1; }
        while pt_o[o2 + c2] >= '0' && pt_o[o2 + c2] <= '9' {
            off = off * 10 + (pt_o[o2 + c2] - '0');
            c2 += 1;
        }
        bool wide = pt_mn(1, "ldr") || pt_mn(1, "str");
        bool range_ok = (wide && off % 8 == 0 && off <= 32760) || (!wide && off <= 4095);
        // the address operand of the load: "[xD, #0]"
        int om = (1 * 4 + 1) * 40;
        int dreg = 0;
        int dd = 0;
        if pt_o[om] == '[' && pt_o[om + 1] == 'x' {
            dd = 2;
            while pt_o[om + dd] >= '0' && pt_o[om + dd] <= '9' {
                dreg = dreg * 10 + (pt_o[om + dd] - '0');
                dd += 1;
            }
        }
        bool zero_off = pt_o[om + dd] == ',' && pt_o[om + dd + 1] == ' ' && pt_o[om + dd + 2] == '#' && pt_o[om + dd + 3] == '0' && pt_o[om + dd + 4] == ']' && pt_o[om + dd + 5] == 0;
        if range_ok && zero_off && dd > 2 && pt_has_reg(0, 0, dreg) && (pt_mn(1, "ldr") || pt_mn(1, "ldrb") || !pt_has_reg(1, 0, dreg)) {
            // the destination of the add is the register that the load uses; the source of the add is the base now
            bool load = pt_mn(1, "ldr") || pt_mn(1, "ldrb");
            bool same_dest = load && pt_isreg(1, 0) && pt_has_reg(1, 0, dreg);
            if same_dest || pt_dead(pt_next(j), dreg, 40) {
                char nl[64];
                int n = 0;
                int m1 = 1 * 16;
                int c = 0;
                while pt_m[m1 + c] != 0 { nl[n] = pt_m[m1 + c]; n += 1; c += 1; }
                nl[n] = ' '; n += 1;
                int o10 = (1 * 4 + 0) * 40;
                c = 0;
                while pt_o[o10 + c] != 0 { nl[n] = pt_o[o10 + c]; n += 1; c += 1; }
                nl[n] = ','; nl[n + 1] = ' '; nl[n + 2] = '['; n += 3;
                int o01 = (0 * 4 + 1) * 40;
                c = 0;
                while pt_o[o01 + c] != 0 { nl[n] = pt_o[o01 + c]; n += 1; c += 1; }
                nl[n] = ','; nl[n + 1] = ' '; nl[n + 2] = '#'; n += 3;
                int dv = off;
                char dg[12];
                int dn = 0;
                if dv == 0 { dg[0] = '0'; dn = 1; }
                while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
                while dn > 0 { dn -= 1; nl[n] = dg[dn]; n += 1; }
                nl[n] = ']'; nl[n + 1] = 0;
                pt_set(j, @nl);
                pt_set(i, "");
                return true;
            }
        }
    }
    // mov x1, x0 / mov x0, S / fmov d0, x0 / fmov d1, x1   ->   fmov d1, x0 / fmov d0, S   (x0 and x1 are not needed afterwards)
    int k3 = pt_next(j);
    int k4 = 0 - 1;
    if k3 >= 0 { k4 = pt_next(k3); }
    if k4 >= 0 && pt_mn(0, "mov") && pt_op(0, 0, "x1") && pt_op(0, 1, "x0") && pt_mn(1, "mov") && pt_op(1, 0, "x0") && pt_isreg(1, 1) && !pt_op(1, 1, "x1") && pt_parse(2, k3) {
        if pt_mn(2, "fmov") && pt_op(2, 0, "d0") && pt_op(2, 1, "x0") && pt_parse(3, k4) && pt_mn(3, "fmov") && pt_op(3, 0, "d1") && pt_op(3, 1, "x1") && pt_dead(pt_next(k4), 0, 40) && pt_dead(pt_next(k4), 1, 40) {
            char na[64];
            char nb[64];
            int o1 = (1 * 4 + 1) * 40;
            nb[0] = 'f'; nb[1] = 'm'; nb[2] = 'o'; nb[3] = 'v'; nb[4] = ' '; nb[5] = 'd'; nb[6] = '1'; nb[7] = ','; nb[8] = ' '; nb[9] = 'x'; nb[10] = '0'; nb[11] = 0;
            na[0] = 'f'; na[1] = 'm'; na[2] = 'o'; na[3] = 'v'; na[4] = ' '; na[5] = 'd'; na[6] = '0'; na[7] = ','; na[8] = ' ';
            int n = 9;
            int c = 0;
            while pt_o[o1 + c] != 0 { na[n] = pt_o[o1 + c]; n += 1; c += 1; }
            na[n] = 0;
            pt_set(i, @nb);
            pt_set(j, @na);
            pt_set(k3, "");
            pt_set(k4, "");
            return true;
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
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
    // I x0, ... / mov D, x0   ->   I D, ...   when x0 is not needed afterwards (I writes its first operand, and is not a plain mov)
    if pt_writes_first(0) && !pt_mn(0, "mov") && !pt_mn(0, "adr") && pt_op(0, 0, "x0") && pt_no[0] >= 2 && pt_mn(1, "mov") && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_op(1, 0, "x0") && pt_dead(pt_next(j), 0, 40) {
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
    // ldr xN, [..] / fmov dK, xN  ->  ldr dK, [..]      fmov xN, dM / str xN, [..]  ->  str dM, [..]   (xN not needed afterwards)
    if pt_mn(0, "ldr") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_mn(1, "fmov") && pt_no[1] == 2 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'x') == pt_regno(0, 0, 'x') && pt_dead(pt_next(j), pt_regno(0, 0, 'x'), 40) {
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
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_mn(1, "str") && pt_no[1] == 2 && pt_regno(1, 0, 'x') == pt_regno(0, 0, 'x') && !pt_has_reg(1, 1, pt_regno(0, 0, 'x')) && pt_dead(pt_next(j), pt_regno(0, 0, 'x'), 40) {
        int o1 = (0 * 4 + 1) * 40;
        char dd[40];
        int c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(1, 0, @dd);
        pt_set(j, @pt_line);
        pt_set(i, "");
        return true;
    }
    // fmov dB, dA / I using dB  ->  I using dA   (dB is written by I, or not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 0, 'd') != pt_regno(0, 1, 'd') && (pt_mn(1, "fadd") || pt_mn(1, "fsub") || pt_mn(1, "fmul") || pt_mn(1, "fdiv") || pt_mn(1, "fsqrt") || pt_mn(1, "fneg") || pt_mn(1, "fabs") || pt_mn(1, "fcmp") || pt_mn(1, "fmov") || pt_mn(1, "fcvtzs") || pt_mn(1, "str") || pt_mn(1, "frintm") || pt_mn(1, "frintp") || pt_mn(1, "frintz")) {
        int db = pt_regno(0, 0, 'd');
        char sd[40];
        int o0 = (0 * 4 + 1) * 40;
        int c = 0;
        while pt_o[o0 + c] != 0 { sd[c] = pt_o[o0 + c]; c += 1; }
        sd[c] = 0;
        bool dest_b = pt_writes_first(1) && pt_regno(1, 0, 'd') == db;
        pt_sub_prefix = 'd';
        int cnt = pt_subst(1, db, @sd, pt_writes_first(1) && !pt_mn(1, "str") && !pt_mn(1, "fcmp"));
        if cnt > 0 && (dest_b || pt_dead(pt_next(j), 32 + db, 40)) {
            char nl[64];
            int q = 0;
            while pt_line[q] != 0 { nl[q] = pt_line[q]; q += 1; }
            nl[q] = 0;
            pt_set(j, @nl);
            pt_set(i, "");
            return true;
        }
    }
    // fmov dA, S / fmov dB, dA   ->   fmov dB, S   (dA is not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_mn(1, "fmov") && pt_no[1] == 2 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'd') == pt_regno(0, 0, 'd') && pt_regno(1, 0, 'd') != pt_regno(0, 0, 'd') && (pt_regno(0, 1, 'x') >= 0 || pt_regno(0, 1, 'd') >= 0) {
        if pt_dead(pt_next(j), 32 + pt_regno(0, 0, 'd'), 40) {
            int o1 = (1 * 4 + 0) * 40;
            int o0 = (0 * 4 + 1) * 40;
            char nl[40];
            int n = 0;
            nl[0] = 'f'; nl[1] = 'm'; nl[2] = 'o'; nl[3] = 'v'; nl[4] = ' ';
            n = 5;
            int c = 0;
            while pt_o[o1 + c] != 0 { nl[n] = pt_o[o1 + c]; n += 1; c += 1; }
            nl[n] = ','; nl[n + 1] = ' ';
            n += 2;
            c = 0;
            while pt_o[o0 + c] != 0 { nl[n] = pt_o[o0 + c]; n += 1; c += 1; }
            nl[n] = 0;
            pt_set(j, @nl);
            pt_set(i, "");
            return true;
        }
    }
    // ldr xN, [A] / (one line that does not touch xN or the base of A) / fmov dK, xN   ->   (the line) / ldr dK, [A]
    if pt_mn(0, "ldr") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_op(0, 0, "x1") {
        int nreg = pt_regno(0, 0, 'x');
        int k5 = pt_next(j);
        if k5 >= 0 && (pt_writes_first(1) || pt_writes_d(1)) && !pt_mn(1, "ldr") && !pt_mn(1, "str") && pt_no[1] >= 2 && !pt_rd(1, 0, nreg) && !pt_rd(1, 1, nreg) && (pt_no[1] < 3 || !pt_rd(1, 2, nreg)) && pt_parse(2, k5) {
            // the base register of the load (the operand "[xB, #N]"): not written by the line in between
            int ob = (0 * 4 + 1) * 40;
            int bn = 0 - 1;
            if pt_o[ob] == '[' && pt_o[ob + 1] == 'x' {
                bn = 0;
                int q = ob + 2;
                while pt_o[q] >= '0' && pt_o[q] <= '9' {
                    bn = bn * 10 + (pt_o[q] - '0');
                    q += 1;
                }
            }
            bool base_ok = bn >= 0 && !(pt_regno(1, 0, 'x') == bn);
            if base_ok && pt_mn(2, "fmov") && pt_no[2] == 2 && pt_regno(2, 0, 'd') >= 0 && pt_regno(2, 1, 'x') == nreg && pt_dead(pt_next(k5), nreg, 40) {
                int o2 = (2 * 4 + 0) * 40;
                char dd[40];
                int c = 0;
                while pt_o[o2 + c] != 0 { dd[c] = pt_o[o2 + c]; c += 1; }
                dd[c] = 0;
                pt_parse(0, i);
                pt_build(0, 0, @dd);
                pt_set(k5, @pt_line);
                pt_set(i, "");
                return true;
            }
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // a double register that is written and not read afterwards: gone
    if (pt_mn(0, "fmov") || pt_mn(0, "fadd") || pt_mn(0, "fsub") || pt_mn(0, "fmul") || pt_mn(0, "fdiv") || pt_mn(0, "fsqrt") || pt_mn(0, "fneg") || pt_mn(0, "fabs") || pt_mn(0, "scvtf")) && pt_regno(0, 0, 'd') >= 0 {
        if pt_dead(j, 32 + pt_regno(0, 0, 'd'), 40) {
            pt_set(i, "");
            return true;
        }
    }
    // a move or a conversion into an x register that nothing reads afterwards: gone
    if (pt_mn(0, "mov") || pt_mn(0, "fmov")) && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 {
        int dr = pt_regno(0, 0, 'x');
        if (dr <= 4 || (dr >= 10 && dr <= 14)) && pt_dead(j, dr, 40) {
            pt_set(i, "");
            return true;
        }
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
        if pt_mirror() { changed = 1; }
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
