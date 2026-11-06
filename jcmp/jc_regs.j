// jc_regs.j -- the register pass: in a function that has loops, the whole-number locals that are used most (weighted by how deep
// in loops they are used) live in the registers x19..x25 instead of the stack frame. It works on the assembler text, after the code
// is made and before the peephole pass:
//
//   ldr xR, [x29, #N]   ->   mov xR, xK          str xR, [x29, #N]   ->   mov xK, xR
//
// A slot may move into a register only if (1) the compiler said (with a line ";H off:size:flag ..." at the end of the body) that
// it is a plain 8-byte value, (2) every use of it is exactly one of the two forms above (no address is taken, no byte or word
// access) and (3) the function does not use the frame in a way that needs the memory: no defer (a piece of code that is called from
// other places of the function),
// no worker of a #multithread loop (x26), no copy of x29. The registers are saved at the start and given back at the end of the
// function (callee-saved: x19..x25 are not used by anything else). A function that has a try keeps its variables in the frame, and
// puts x19..x25 / d8..d15 back as they were when the try began when it catches (a throw jumps over the frames in between without
// giving their registers back; jc_stmt.j parse_try). Lines ";H" are always removed. -noregs switches the pass off.

char regs_buf[8388608];
i64 regs_len;
i64 rg_ls[65536];            // the start of each line of the function
i64 rg_n;
i64 rg_state[8192];          // by 8-byte slot of the frame: 0 unknown, 1 a plain value that may move, 2 not allowed
i64 rg_wt[8192];
i64 rg_dep[65536];
i64 rg_bmax[8192];           // by label: the last line that branches back to it (-1: none)
i64 rg_ltgt[65536];          // per line, worked out once before the live analysis: the line a jump goes to (-1: none)
i64 rg_lfall[65536];         // 1: the flow goes on to the next line
i64 rg_lc[65536];            // the candidate that this line loads or stores (-1: none)
i64 rg_lload[65536];         // 1: it is a load
i64 rg_skip[65536];
i64 rg_dead[65536];          // 1: a store of a slot that nobody reads any more (the line is not written)
i64 rg_labn[8192];
i64 rg_labl[8192];
i64 rg_nlab;
i64 rg_pick[8];              // the slots that got a register
i64 rg_npick;
i64 rg_leaf;                 // 1: the function makes no call (only calls that never return)
i64 rg_nextra;               // caller-saved registers that a leaf function may use for variables: they are not mentioned in its text
i64 rg_extra[8];
i64 rg_callpre[65538];         // rg_callpre[i]: the calls (that come back) in the lines before i: an interval without a call may use the extras of a function that is not a leaf
i64 rg_elide;                // 1: the frame of the function is not needed (no stack slot is left)
i64 rg_mask;                 // the registers x0 .. x30 that the text of the function mentions
i64 al_to = 32;              // every function starts at a multiple of this many bytes (0: no padding)
i64 rg_novecw;               // -irdbg 137438953472: the variables of a vector loop weigh as much as the others
i64 rg_nostruct;             // -irdbg 274877906944: the words of small structs stay in the frame
i64 rg_i32_off;              // -irdbg 34359738368: 32-bit variables stay in the frame
i64 rg_w32[8192];            // 1: the slot holds a 32-bit number (hint flag 2): its register always holds the sign-extended value
i64 rg_pin[8192];            // the register (18, 19 .. 25) a slot is pinned to, or 0 (int n @ x19)
i64 rg_slotreg[8192];        // the register number (19..25) of a slot, or 0
i64 rg_slotd[8192];          // the double register number (8..15) of a slot, or 0
i64 rg_fl[8192];             // how many uses of the slot are conversions to and from a double register
i64 rg_tot[8192];            // how many uses the slot has
i64 rg_first[8192];          // the first and the last line where the slot is live
i64 rg_last[8192];
i64 rg_cand[8192];           // the slots that are looked at by the allocator
i64 rg_ncand;
i64 rg_cidx[8192];           // the number of a slot in rg_cand, or -1
i64 rg_live[524288];         // live-in sets: 8 words of 32 bits for each line (the first 256 candidates)
i64 rg_xsave[8];             // the frame slot where the old value of x(19 + k) is kept, or -1
i64 rg_dsave[8];             // the same for d(8 + k)
i64 rg_act[16];              // the slots that hold a register now (the linear scan)
i64 rg_nact;

// the end of the line that starts at st (the index of its newline)
i64 rg_end(i64 st) {
    i64 e = st;
    while out_buf[e] != 10 { e += 1; }
    return e;
}

// does the line at st start with s?
bool rg_has(i64 st, char^ s) {
    i64 i = 0;
    while s[i] != 0 {
        if out_buf[st + i] != s[i] { return false; }
        i += 1;
    }
    return true;
}

// does s occur in the line st..en?
bool rg_in(i64 st, i64 en, char^ s) {
    i64 k = st;
    while k < en {
        i64 i = 0;
        while s[i] != 0 && k + i < en && out_buf[k + i] == s[i] { i += 1; }
        if s[i] == 0 { return true; }
        k += 1;
    }
    return false;
}

// the number written at index i (digits); the index after it is in rg_next
i64 rg_next;
i64 rg_num(i64 i) {
    i64 v = 0;
    while out_buf[i] >= '0' && out_buf[i] <= '9' {
        v = v * 10 + (out_buf[i] - '0');
        i += 1;
    }
    rg_next = i;
    return v;
}

// is the line st..en a label of a function ("name:" followed by "sub sp, sp, #")?
i64 rg_nofma_fn;                 // the function being finished has the line ;NOFMA (a vector loop): no fused multiply-add

// a naked function: the label of the function, then a line ";N" (the low level of the language; ARM32 lifts it)
bool rg_is_naked(i64 st) {
    i64 en = rg_end(st);
    if en <= st + 1 || out_buf[en - 1] != ':' { return false; }
    if out_buf[st] == 'L' && out_buf[st + 1] >= '0' && out_buf[st + 1] <= '9' { return false; }
    if out_buf[st] == ';' || out_buf[st] == '.' { return false; }
    return rg_has(en + 1, ";N");
}

bool rg_is_func(i64 st) {
    i64 en = rg_end(st);
    if en <= st + 1 || out_buf[en - 1] != ':' { return false; }
    if out_buf[st] == 'L' && out_buf[st + 1] >= '0' && out_buf[st + 1] <= '9' { return false; }
    if out_buf[st] == ';' { return false; }
    return rg_has(en + 1, "sub sp, sp, #");
}

// the form "ldr xR, [x29, #N]" or "str xR, [x29, #N]" at st: returns N (and rg_reg = R, rg_isload), or -1
i64 rg_reg;
i64 rg_isload;
// does the line st write the register x<r> as its first operand?
bool rg_writes_x(i64 st, i64 r) {
    i64 en = rg_end(st);
    i64 k = st;
    while k < en && out_buf[k] != ' ' { k += 1; }
    if k + 1 < en && out_buf[k + 1] == 'x' && rg_num(k + 2) == r { return true; }
    return false;
}

// a load of the slot into x<r> at line i is followed (within a few plain lines) by "fmov dN, x<r>"
bool rg_fmov_ahead(i64 i, i64 r) {
    i64 k = i + 1;
    while k < rg_n && k <= i + 4 {
        i64 st = rg_ls[k];
        if rg_fmov_from(st, r) { return true; }
        if rg_writes_x(st, r) { return false; }
        i64 en = rg_end(st);
        if out_buf[en - 1] == ':' || out_buf[st] == 'b' { return false; }
        k += 1;
    }
    return false;
}

// a store of x<r> at line i is preceded (within a few plain lines) by "fmov x<r>, dN"
bool rg_fmov_back(i64 i, i64 r) {
    i64 k = i - 1;
    while k >= 0 && k >= i - 4 {
        i64 st = rg_ls[k];
        if rg_fmov_to(st, r) { return true; }
        if rg_writes_x(st, r) { return false; }
        i64 en = rg_end(st);
        if out_buf[en - 1] == ':' || out_buf[st] == 'b' { return false; }
        k -= 1;
    }
    return false;
}

// the line st is "sxtw x<r>, x<s>" (the register r now holds a sign-extended 32-bit value)
bool rg_sxtw_self(i64 st, i64 r) {
    return rg_has(st, "sxtw x") && rg_writes_x(st, r);
}

i64 rg_isd;                  // 1: the use at the line is ldr dK / str dK (a double, written by the lowering of the IR)

i64 rg_isw;                  // 1: the use is ldrsw xR / strw xR (a 32-bit access of the slot)
i64 rg_slot_use(i64 st) {
    i64 i = st;
    rg_isd = 0;
    rg_isw = 0;
    i64 skip = 5;
    if rg_has(st, "ldrsw x") {
        rg_isload = 1;
        rg_isw = 1;
        skip = 7;
    } else if rg_has(st, "strw x") {
        rg_isload = 0;
        rg_isw = 1;
        skip = 6;
    } else if rg_has(st, "ldr x") {
        rg_isload = 1;
    } else if rg_has(st, "str x") {
        rg_isload = 0;
    } else if rg_has(st, "ldr d") {
        rg_isload = 1;
        rg_isd = 1;
    } else if rg_has(st, "str d") {
        rg_isload = 0;
        rg_isd = 1;
    } else {
        return 0 - 1;
    }
    i = st + skip;
    if out_buf[i] < '0' || out_buf[i] > '9' { return 0 - 1; }
    rg_reg = rg_num(i);
    i = rg_next;
    if !rg_has(i, ", [x29, #") { return 0 - 1; }
    i += 9;
    if out_buf[i] < '0' || out_buf[i] > '9' { return 0 - 1; }
    i64 n = rg_num(i);
    i = rg_next;
    if out_buf[i] != ']' || out_buf[i + 1] != 10 { return 0 - 1; }
    return n;
}

void rg_put(char c) {
    regs_buf[regs_len] = c;
    regs_len += 1;
}

void rg_text(char^ s) {
    i64 i = 0;
    while s[i] != 0 {
        rg_put(s[i]);
        i += 1;
    }
}

void rg_int(i64 v) {
    if v < 0 {
        rg_put('-');
        if v == 0 - 9223372036854775807 - 1 {
            rg_text("9223372036854775808");
            return;
        }
        v = 0 - v;
    }
    if v >= 10 { rg_int(v / 10); }
    rg_put('0' + v % 10);
}

// copy the text st..en (not the newline) and a newline
void rg_copy(i64 st, i64 en) {
    i64 k = st;
    while k < en {
        rg_put(out_buf[k]);
        k += 1;
    }
    rg_put(10);
}

// is the line at st "fmov dK, xR" (a double made from the x register R)?
bool rg_fmov_from(i64 st, i64 r) {
    bool single = rg_has(st, "fmov s");          // a float: fmov sK, wR
    if !rg_has(st, "fmov d") && !single { return false; }
    i64 en = rg_end(st);
    i64 k = en - 1;
    while k > st && out_buf[k] >= '0' && out_buf[k] <= '9' { k -= 1; }
    if single {
        if out_buf[k] != 'w' || out_buf[k - 1] != ' ' { return false; }
    } else if out_buf[k] != 'x' || out_buf[k - 1] != ' ' { return false; }
    return rg_num(k + 1) == r && rg_next == en;
}

// is the line at st "fmov xR, dK"?
bool rg_fmov_to(i64 st, i64 r) {
    if rg_has(st, "fmov w") {                    // a float: fmov wR, sK
        i64 numw = rg_num(st + 6);
        return numw == r && rg_has(rg_next, ", s");
    }
    if !rg_has(st, "fmov x") { return false; }
    i64 num = rg_num(st + 6);
    return num == r && rg_has(rg_next, ", d");
}

// the bit of candidate c (0..255) in the live set of the line i: word index, mask
bool rg_lv_get(i64 line, i64 c) {
    return (rg_live[line * 8 + c / 32] >> (c % 32)) % 2 == 1;
}

void rg_lv_set(i64 line, i64 c) {
    if !rg_lv_get(line, c) { rg_live[line * 8 + c / 32] += 1 << (c % 32); }
}

// the live variable analysis for the candidates, then a linear scan: the slots that are live at the same time get different
// registers, slots whose lives do not meet may share one
i64 rg_debug;                    // -rgdbg: say what the register pass thinks of every slot of main (state, uses, weight)

void rg_allocate(i64 epi, i64 is_main) {
    if rg_debug == 1 && is_main == 1 {
        i64 dw = 0;
        while dw < 8192 {
            if rg_tot[dw] > 0 {
                write_err("slot ");
                write_err_int(dw * 8);
                write_err(" state ");
                write_err_int(rg_state[dw]);
                write_err(" uses ");
                write_err_int(rg_tot[dw]);
                write_err(" weight ");
                write_err_int(rg_wt[dw]);
                write_err("\n");
            }
            dw += 1;
        }
    }
    // the candidates: the slots that may move and are used often enough, the busiest 256
    rg_ncand = 0;
    i64 w = 0;
    while w < 8192 {
        rg_cidx[w] = 0 - 1;
        w += 1;
    }
    // the pinned slots are candidates whatever their weight
    w = 0;
    while w < 8192 {
        if rg_state[w] == 1 && rg_pin[w] > 0 && rg_cidx[w] < 0 && rg_ncand < 256 && rg_tot[w] > 0 {
            rg_cidx[w] = rg_ncand;
            rg_cand[rg_ncand] = w;
            rg_ncand += 1;
        }
        w += 1;
    }
    i64 thr = 2;
    i64 rounds = 0;
    while rounds < 300 {
        // the busiest slot that is not taken yet
        i64 best = 0 - 1;
        i64 bw = thr;
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
    if rg_nextra > 0 {
        // the caller-saved registers of a leaf function cost nothing (no save, no restore): they take slots of two uses too
        // (in a function that is not a leaf: x8 and x9 for the variables that live between two calls)
        i64 extra_left = rg_nextra;
        rounds = 0;
        while extra_left > 0 && rounds < 16 && rg_ncand < 256 {
            i64 best2 = 0 - 1;
            i64 bw2 = 1;
            w = 0;
            while w < 8192 {
                if rg_state[w] == 1 && rg_cidx[w] < 0 && rg_wt[w] > bw2 && rg_pin[w] == 0 {
                    bw2 = rg_wt[w];
                    best2 = w;
                }
                w += 1;
            }
            if best2 < 0 { rounds = 16; }
            else {
                rg_cidx[best2] = rg_ncand;
                rg_cand[rg_ncand] = best2;
                rg_ncand += 1;
                extra_left -= 1;
                rounds += 1;
            }
        }
    }
    if rg_ncand == 0 { return; }
    // live-in sets: use[i] = a load of the slot, def[i] = a store of it; go backwards until nothing changes
    i64 i = 0;
    while i < rg_n * 8 {
        rg_live[i] = 0;
        i += 1;
    }
    // what each line does for the flow, once (the analysis below goes over the lines several times)
    i = 0;
    while i < rg_n {
        i64 st0 = rg_ls[i];
        i64 en0 = rg_end(st0);
        bool falls0 = true;
        if rg_has(st0, "ret\n") { falls0 = false; }
        i64 tgt0 = 0 - 1;
        bool is_b0 = rg_has(st0, "b ");
        if is_b0 || rg_has(st0, "b.") || rg_has(st0, "cbz ") || rg_has(st0, "cbnz ") || rg_has(st0, "tbz ") || rg_has(st0, "tbnz ") {
            i64 q0 = en0 - 1;
            while q0 > st0 && out_buf[q0] != 'L' && out_buf[q0] != ' ' { q0 -= 1; }
            if out_buf[q0] == 'L' && out_buf[q0 + 1] >= '0' && out_buf[q0 + 1] <= '9' {
                i64 target0 = rg_num(q0 + 1);
                i64 li0 = 0;
                while li0 < rg_nlab {
                    if rg_labn[li0] == target0 { tgt0 = rg_labl[li0]; }
                    li0 += 1;
                }
            }
            if is_b0 { falls0 = false; }
        }
        rg_ltgt[i] = tgt0;
        rg_lfall[i] = 0;
        if falls0 { rg_lfall[i] = 1; }
        i64 c0 = 0 - 1;
        rg_lload[i] = 0;
        if rg_skip[i] == 0 && rg_in(st0, en0, "x29") {
            i64 n0 = rg_slot_use(st0);
            if n0 >= 0 && n0 % 8 == 0 && n0 / 8 < 8192 {
                c0 = rg_cidx[n0 / 8];
                if rg_isload == 1 { rg_lload[i] = 1; }
            }
        }
        rg_lc[i] = c0;
        i += 1;
    }
    i64 pass = 0;
    bool changed = true;
    while changed && pass < 50 {
        changed = false;
        pass += 1;
        i = rg_n - 1;
        while i >= 0 {
            // the successors: the next line unless this one ends the flow; the target of a jump
            i64 lo0 = 0;
            i64 lo1 = 0;
            i64 lo2 = 0;
            i64 lo3 = 0;
            i64 lo4 = 0;
            i64 lo5 = 0;
            i64 lo6 = 0;
            i64 lo7 = 0;
            bool falls = rg_lfall[i] == 1;
            i64 tgt = rg_ltgt[i];
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
            i64 c = rg_lc[i];
            bool is_load = rg_lload[i] == 1;
            if c >= 0 {
                i64 wd = c / 32;
                i64 mk = 1 << (c % 32);
                i64 cur = lo0;
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
    // a store to a slot that is not live after it (nobody loads the value any more) is dead: the line is not written
    i = 0;
    while i < rg_n {
        rg_dead[i] = 0;
        i64 cd = rg_lc[i];
        if cd >= 0 && rg_lload[i] == 0 && opt_icopy == 1 {
            bool lv = false;
            if rg_lfall[i] == 1 && i + 1 < rg_n && rg_lv_get(i + 1, cd) { lv = true; }
            if rg_ltgt[i] >= 0 && rg_lv_get(rg_ltgt[i], cd) { lv = true; }
            if rg_lfall[i] == 1 && i + 1 >= rg_n { lv = true; }
            if !lv { rg_dead[i] = 1; }
        }
        i += 1;
    }
    // the intervals: from the first line where the slot is live (or stored) to the last one
    i64 c2 = 0;
    while c2 < rg_ncand {
        rg_first[c2] = 1000000;
        rg_last[c2] = 0 - 1;
        c2 += 1;
    }
    i = 0;
    while i < rg_n {
        i64 c3 = 0;
        while c3 < rg_ncand {
            if rg_lv_get(i, c3) {
                if i < rg_first[c3] { rg_first[c3] = i; }
                if i > rg_last[c3] { rg_last[c3] = i; }
            }
            c3 += 1;
        }
        // a store makes the slot live after it, a load before: both ends count
        i64 st = rg_ls[i];
        i64 en = rg_end(st);
        if rg_skip[i] == 0 && rg_in(st, en, "x29") {
            i64 n = rg_slot_use(st);
            if n >= 0 && n % 8 == 0 && n / 8 < 8192 {
                i64 cc = rg_cidx[n / 8];
                if cc >= 0 {
                    if i < rg_first[cc] { rg_first[cc] = i; }
                    if i > rg_last[cc] { rg_last[cc] = i; }
                }
            }
        }
        i += 1;
    }
    // the linear scan, by the start of the interval: x registers 19..25 for whole numbers, d8..d15 for doubles
    i64 done = 0;
    i64 taken[256];
    c2 = 0;
    while c2 < rg_ncand {
        taken[c2] = 0;
        c2 += 1;
    }
    i64 xowner[16];
    i64 downer[8];
    i64 xr[16];                           // the register of each entry of the pool: 0 .. 6 = x19 .. x25, 7 = x18, 8 .. = caller-saved ones of a leaf function
    i64 ordx[16];                         // the entries that an ordinary variable may take, the best first
    i64 nordx = 0;
    i64 k = 0;
    while k < 16 {
        xowner[k] = 0 - 1;
        xr[k] = 0;
        k += 1;
    }
    k = 0;
    while k < 8 {
        downer[k] = 0 - 1;
        // a register that the program reserved (#reserve x19) is never given to a variable
        if k < 7 { xr[k] = 19 + k; }
        if k < 7 && (reserve_mask & (1 << (19 + k))) != 0 { xowner[k] = 0 - 2; }
        k += 1;
    }
    xr[7] = 18;
    if (reserve_mask & (1 << 18)) != 0 { xowner[7] = 0 - 2; }
    i64 ex = 0;
    while ex < rg_nextra {
        xr[8 + ex] = rg_extra[ex];
        ex += 1;
    }
    {
        // the registers that need no save first
        ex = 0;
        while ex < rg_nextra {
            ordx[nordx] = 8 + ex;
            nordx += 1;
            ex += 1;
        }
        if rg_leaf == 1 && xowner[7] == 0 - 1 {
            ordx[nordx] = 7;
            nordx += 1;
        }
    }
    k = 0;
    while k < 7 {
        ordx[nordx] = k;
        nordx += 1;
        k += 1;
    }
    // a pinned variable owns its register for the whole function
    c2 = 0;
    while c2 < rg_ncand {
        i64 ps = rg_cand[c2];
        if rg_pin[ps] > 0 {
            i64 pk = rg_pin[ps] - 19;
            if rg_pin[ps] == 18 { pk = 7; }
            if xowner[pk] != 0 - 1 {
                if xowner[pk] == 0 - 2 { die("a variable is pinned to a register that #reserve keeps for the program (reserved registers are not given to variables)"); }
                die("two variables are pinned to the same register in one function");
            }
            xowner[pk] = c2;
            taken[c2] = 1;
            done += 1;
            rg_slotreg[ps] = xr[pk];
            if pk < 7 && rg_xsave[pk] < 0 { rg_xsave[pk] = ps; }
        }
        c2 += 1;
    }
    while done < rg_ncand {
        // the interval that starts first among the ones not done
        i64 cur = 0 - 1;
        c2 = 0;
        while c2 < rg_ncand {
            if taken[c2] == 0 && rg_last[c2] >= 0 && (cur < 0 || rg_first[c2] < rg_first[cur]) { cur = c2; }
            c2 += 1;
        }
        if cur < 0 { done = rg_ncand; }
        else {
            taken[cur] = 1;
            done += 1;
            i64 slot = rg_cand[cur];
            bool is_d = rg_fl[slot] * 2 >= rg_tot[slot] && rg_tot[slot] > 0;
            i64 nreg = nordx;
            if is_d { nreg = 8; }
            // free the registers whose owner ended before this interval starts
            i64 kj = 0;
            while kj < nreg {
                k = kj;
                if !is_d { k = ordx[kj]; }
                i64 ow = xowner[k];
                if is_d { ow = downer[k]; }
                if ow >= 0 && rg_last[ow] < rg_first[cur] && (is_d || rg_pin[rg_cand[ow]] == 0) {
                    if is_d { downer[k] = 0 - 1; } else { xowner[k] = 0 - 1; }
                }
                kj += 1;
            }
            // a free register, else the owner with the smallest weight if it is smaller than this one
            // (an interval that has a call inside cannot be in a caller-saved register)
            bool callfree = rg_callpre[rg_last[cur] + 1] - rg_callpre[rg_first[cur]] == 0;
            i64 pick = 0 - 1;
            kj = 0;
            while kj < nreg && pick < 0 {
                k = kj;
                if !is_d { k = ordx[kj]; }
                i64 ow2 = xowner[k];
                if is_d { ow2 = downer[k]; }
                bool allowed = is_d || k < 8 || rg_leaf == 1 || callfree;
                if ow2 == 0 - 1 && allowed { pick = k; }
                kj += 1;
            }
            if pick < 0 {
                i64 low = 0 - 1;
                kj = 0;
                while kj < nreg {
                    k = kj;
                    if !is_d { k = ordx[kj]; }
                    i64 ow3 = xowner[k];
                    if is_d { ow3 = downer[k]; }
                    bool allowed3 = is_d || k < 8 || rg_leaf == 1 || callfree;
                    if allowed3 && ow3 >= 0 && (is_d || rg_pin[rg_cand[ow3]] == 0) && (low < 0 || rg_wt[rg_cand[ow3]] < rg_wt[rg_cand[low]]) { low = ow3; pick = k; }
                    kj += 1;
                }
                if low >= 0 && rg_wt[rg_cand[low]] < rg_wt[slot] {
                    // the old owner stays in memory
                    i64 os = rg_cand[low];
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
                    rg_slotreg[slot] = xr[pick];
                    if pick < 7 && rg_xsave[pick] < 0 { rg_xsave[pick] = slot; }
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
            if rg_slotreg[w] >= 19 && rg_xsave[rg_slotreg[w] - 19] < 0 { rg_xsave[rg_slotreg[w] - 19] = w; }
        }
        if rg_slotd[w] != 0 {
            rg_npick += 1;
            if rg_dsave[rg_slotd[w] - 8] < 0 { rg_dsave[rg_slotd[w] - 8] = w; }
        }
        w += 1;
    }
}

// the registers xN / wN that the line st mentions, as a mask
i64 rg_line_regs(i64 st, i64 en) {
    i64 m = 0;
    i64 j = st;
    while j < en {
        i64 c = out_buf[j];
        if (c == 'x' || c == 'w') && (j == st || !((out_buf[j - 1] >= 'a' && out_buf[j - 1] <= 'z') || (out_buf[j - 1] >= 'A' && out_buf[j - 1] <= 'Z') || (out_buf[j - 1] >= '0' && out_buf[j - 1] <= '9') || out_buf[j - 1] == '_')) && out_buf[j + 1] >= '0' && out_buf[j + 1] <= '9' {
            i64 v = 0;
            i64 q = j + 1;
            while out_buf[q] >= '0' && out_buf[q] <= '9' {
                v = v * 10 + (out_buf[q] - '0');
                q += 1;
            }
            if v <= 30 { m = m | (1 << v); }
            j = q;
        } else {
            j += 1;
        }
    }
    return m;
}

// is the line a call that comes back?  (a call of a routine that never returns does not count)
bool rg_is_call(i64 st) {
    if rg_has(st, "blr ") || rg_has(st, "br ") || rg_has(st, "svc ") { return true; }
    if rg_has(st, "bl ") {
        if rg_has(st, "bl j2k_divzero") || rg_has(st, "bl j2k_noret") || rg_has(st, "bl j2k_oob") { return false; }
        return true;
    }
    return false;
}

// the function that starts at the line fs and has the lines rg_ls[0 .. rg_n - 1]: write it (with registers if it pays)
void rg_function(i64 is_main) {
    i64 i = 0;
    i64 ok = 1;
    i64 hint_at = 0 - 1;
    i64 epi = 0 - 1;
    i64 s = 0;
    while s < 8192 {
        rg_state[s] = 0;
        rg_wt[s] = 0;
        rg_pin[s] = 0;
        rg_w32[s] = 0;
        rg_slotreg[s] = 0;
        rg_slotd[s] = 0;
        rg_fl[s] = 0;
        rg_tot[s] = 0;
        s += 1;
    }
    // a function with a register { } block writes registers by itself: nothing moves into registers
    i = 0;
    while i < rg_n {
        if rg_has(rg_ls[i], ";N") { ok = 0; }
        i += 1;
    }
    // the hints
    i = 0;
    while i < rg_n {
        i64 st = rg_ls[i];
        if rg_has(st, ";H") {
            hint_at = i;
            i64 en = rg_end(st);
            i64 p = st + 2;
            while p < en {
                while p < en && out_buf[p] == ' ' { p += 1; }
                if p < en {
                    i64 off = rg_num(p);
                    p = rg_next + 1;
                    i64 size = rg_num(p);
                    p = rg_next + 1;
                    i64 flag = rg_num(p);
                    p = rg_next;
                    i64 w0 = off / 8;
                    i64 w1 = (off + size - 1) / 8;
                    if size <= 0 { w1 = w0; }
                    i64 w = w0;
                    i64 pinv = 0;
                    if flag >= 100 { pinv = flag - 100; flag = 1; }
                    i64 is32 = 0;
                    if flag == 2 && rg_i32_off == 0 { is32 = 1; flag = 1; }
                    // a struct of 8 or 16 bytes (hint flag 0): its words move into registers when every use of them in the text is a plain
                    // 8-byte load or store (an address taken anywhere makes the words not allowed below); -irdbg 274877906944 switches it off
                    bool sw = flag == 0 && (size == 8 || size == 16) && off % 8 == 0 && rg_nostruct == 0;
                    while w <= w1 && w < 8192 {
                        if (sw || (flag == 1 && size == 8 && off % 8 == 0)) && rg_state[w] != 2 {
                            rg_state[w] = 1;
                            rg_pin[w] = pinv;
                            if is32 == 1 { rg_w32[w] = 1; }
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
        rg_dead[i] = 0;
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
        i64 st = rg_ls[i];
        i64 en = rg_end(st);
        if out_buf[st] == 'L' && out_buf[st + 1] >= '0' && out_buf[st + 1] <= '9' && out_buf[en - 1] == ':' && rg_nlab < 8192 {
            rg_labn[rg_nlab] = rg_num(st + 1);
            rg_labl[rg_nlab] = i;
            rg_nlab += 1;
        }
        i += 1;
    }
    i64 bl0 = 0;
    while bl0 < rg_nlab { rg_bmax[bl0] = 0 - 1; bl0 += 1; }
    // what the lines do
    i = 0;
    while i < rg_n && ok == 1 {
        i64 st = rg_ls[i];
        i64 en = rg_end(st);
        if rg_has(st, ";H") || rg_skip[i] == 1 {
            i += 1;
            continue;
        }
        if rg_in(st, en, "x26") || rg_in(st, en, "j2k_try_enter") || rg_has(st, "str x30, [sp, #0]") {
            ok = 0;
        }
        if rg_has(st, "mov x29,") { ok = 0; }
        // a branch backwards makes a loop: the lines in between count more
        if rg_has(st, "b ") || rg_has(st, "b.") || rg_has(st, "cbz ") || rg_has(st, "cbnz ") || rg_has(st, "tbz ") || rg_has(st, "tbnz ") {
            i64 q = en - 1;
            while q > st && out_buf[q] != 'L' && out_buf[q] != ' ' { q -= 1; }
            if out_buf[q] == 'L' && out_buf[q + 1] >= '0' && out_buf[q + 1] <= '9' {
                i64 target = rg_num(q + 1);
                i64 li = 0;
                while li < rg_nlab {
                    // the farthest branch back to a label makes the loop; another branch to the same label (a rotated loop has a test at each end of the body) is the same loop
                    if rg_labn[li] == target && rg_labl[li] < i {
                        if i > rg_bmax[li] { rg_bmax[li] = i; }
                    }
                    li += 1;
                }
            }
        }
        i += 1;
    }
    bl0 = 0;
    while bl0 < rg_nlab {
        if rg_bmax[bl0] >= 0 {
            // a loop that has NEON loads or stores (a vector loop) is the hot one: its variables count more (-irdbg 137438953472: not)
            i64 vb0 = 1;
            if rg_novecw == 0 {
                i64 vq = rg_labl[bl0];
                while vq <= rg_bmax[bl0] && vb0 == 1 {
                    if rg_has(rg_ls[vq], "ldr q") { vb0 = 5; }
                    vq += 1;
                }
            }
            i64 jb = rg_labl[bl0];
            while jb <= rg_bmax[bl0] {
                rg_dep[jb] += vb0;
                jb += 1;
            }
        }
        bl0 += 1;
    }
    // the uses of x29
    i = 0;
    while i < rg_n && ok == 1 {
        i64 st = rg_ls[i];
        i64 en = rg_end(st);
        if rg_in(st, en, "x29") && !rg_has(st, ";H") && rg_skip[i] == 0 {
            i64 n = rg_slot_use(st);
            if n >= 0 {
                if n % 8 == 0 && n / 8 < 8192 {
                    if rg_isw == 1 && rg_w32[n / 8] == 0 { rg_state[n / 8] = 2; }
                    rg_tot[n / 8] += 1;
                    if rg_isd == 1 { rg_fl[n / 8] += 1; }
                    else if rg_isload == 1 && rg_fmov_ahead(i, rg_reg) { rg_fl[n / 8] += 1; }
                    else if rg_isload == 0 && rg_fmov_back(i, rg_reg) { rg_fl[n / 8] += 1; }
                    i64 d = rg_dep[i];
                    if d > 12 { d = 12; }                // a deep nest counts more than a shallow one (the jumps back from cold code make the depth too big everywhere, by the same amount)
                    i64 wgt = 1;
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
                i64 p = st;
                while p < en && out_buf[p] != '#' { p += 1; }
                i64 has_x29 = 0;
                if rg_in(st, en, "x29, #") || rg_in(st, en, "[x29, #") { has_x29 = 1; }
                if has_x29 == 1 && p < en {
                    i64 nn = rg_num(p + 1);
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
    // a leaf function (no call that comes back) may keep variables in caller-saved registers that its text does not mention: nothing to save
    rg_leaf = 0;
    rg_nextra = 0;
    rg_mask = 0;
    if ok == 1 && is_main == 0 && opt_debug == 0 {
        rg_leaf = 1;
        i = 0;
        rg_callpre[0] = 0;
        while i < rg_n {
            i64 st2 = rg_ls[i];
            i64 en2 = rg_end(st2);
            rg_callpre[i + 1] = rg_callpre[i];
            if !rg_has(st2, ";H") {
                if rg_is_call(st2) {
                    rg_leaf = 0;
                    rg_callpre[i + 1] += 1;
                }
                rg_mask = rg_mask | rg_line_regs(st2, en2);
            }
            i += 1;
        }
        if rg_leaf == 0 && rg_n < 65000 {
            // x9 and x8, when the text does not mention them: for the variables that do not live over a call
            i64 cand2[2];
            cand2[0] = 9; cand2[1] = 8;
            i64 cj = 0;
            while cj < 2 {
                if (rg_mask & (1 << cand2[cj])) == 0 { rg_extra[rg_nextra] = cand2[cj]; rg_nextra += 1; }
                cj += 1;
            }
        }
        if rg_leaf == 1 {
            // x2 x3 x4 x8 x9 (the text passes after this one use x5 x6 x7 x10 .. x14 as holders; x15 .. x17 are scratch registers)
            i64 cand[5];
            cand[0] = 9; cand[1] = 8; cand[2] = 4; cand[3] = 3; cand[4] = 2;
            i64 ci2 = 0;
            while ci2 < 5 {
                if (rg_mask & (1 << cand[ci2])) == 0 { rg_extra[rg_nextra] = cand[ci2]; rg_nextra += 1; }
                ci2 += 1;
            }
        }
    }
    // the allocation: live variable analysis, then a linear scan over the live intervals of the slots that are used most
    rg_npick = 0;
    i64 k0 = 0;
    while k0 < 8 {
        rg_xsave[k0] = 0 - 1;
        rg_dsave[k0] = 0 - 1;
        k0 += 1;
    }
    if ok == 1 {
        rg_allocate(epi, is_main);
    }
    // a pinned variable must have its register
    i64 pw = 0;
    while pw < 8192 {
        if rg_pin[pw] > 0 && rg_slotreg[pw] == 0 && rg_tot[pw] > 0 {
            die("a pinned variable (int n @ x19) could not be kept in its register: its address is used, or the function has a register { } block, defer, try or a #multithread loop");
        }
        pw += 1;
    }
    // a leaf function whose variables are all in caller-saved registers needs no frame: no stack pointer move, no saves of x29 / x30
    i64 elide = 0;
    if ok == 1 && is_main == 0 && rg_leaf == 1 && opt_debug == 0 {
        elide = 1;
        i64 ew = 0;
        while ew < 8192 {
            if (rg_slotreg[ew] >= 19 && rg_slotreg[ew] <= 25) || rg_slotd[ew] != 0 { elide = 0; }
            ew += 1;
        }
        i = 0;
        while i < rg_n && elide == 1 {
            i64 st = rg_ls[i];
            i64 en = rg_end(st);
            if rg_in(st, en, "x29") && !rg_has(st, ";H") && rg_skip[i] == 0 {
                if rg_has(st, "add x29, sp, #0") || rg_has(st, "str x29, [sp, #0]") || rg_has(st, "ldr x29, [sp, #0]") {
                    // the frame itself
                } else {
                    i64 n = rg_slot_use(st);
                    if !(n >= 0 && n % 8 == 0 && n / 8 < 8192 && rg_slotreg[n / 8] != 0) { elide = 0; }
                }
            }
            if rg_has(st, "str x30, [sp, #8]") || rg_has(st, "ldr x30, [sp, #8]") {
                // saved link register: fine, nothing else may change it
            } else if rg_in(st, en, "x30") && !rg_has(st, ";H") {
                elide = 0;
            }
            i += 1;
        }
    }
    rg_elide = elide;
    // write it
    i = 0;
    while i < rg_n {
        i64 st = rg_ls[i];
        i64 en = rg_end(st);
        if rg_dead[i] == 1 {
            i += 1;
            continue;
        }
        if rg_has(st, ";H") {
            i += 1;
            continue;
        }
        if elide == 1 {
            if rg_has(st, "sub sp, sp, #0000") || rg_has(st, "add sp, sp, #0000") || rg_has(st, "str x29, [sp, #0]") || rg_has(st, "ldr x29, [sp, #0]") || rg_has(st, "str x30, [sp, #8]") || rg_has(st, "ldr x30, [sp, #8]") || rg_has(st, "add x29, sp, #0") {
                i += 1;
                continue;
            }
        }
        if rg_skip[i] == 1 && rg_npick > 0 {
            i += 1;
            continue;
        }
        if rg_npick > 0 {
            i64 n = 0 - 1;
            if rg_in(st, en, "x29") { n = rg_slot_use(st); }
            if n >= 0 && n % 8 == 0 && n / 8 < 8192 && (rg_slotreg[n / 8] != 0 || rg_slotd[n / 8] != 0) {
                i64 r = rg_reg;
                i64 load = rg_isload;
                bool isd = rg_isd == 1;
                if isd {
                    // a double register is read or written: a move between double registers, or into the whole number register
                    if rg_slotreg[n / 8] != 0 {
                        i64 kx = rg_slotreg[n / 8];
                        if load == 1 {
                            rg_text("fmov d");
                            rg_int(r);
                            rg_text(", x");
                            rg_int(kx);
                        } else {
                            rg_text("fmov x");
                            rg_int(kx);
                            rg_text(", d");
                            rg_int(r);
                        }
                    } else {
                        i64 kdd = rg_slotd[n / 8];
                        if load == 1 {
                            rg_text("fmov d");
                            rg_int(r);
                            rg_text(", d");
                            rg_int(kdd);
                        } else {
                            rg_text("fmov d");
                            rg_int(kdd);
                            rg_text(", d");
                            rg_int(r);
                        }
                    }
                } else if rg_slotreg[n / 8] != 0 && rg_w32[n / 8] == 1 && load == 0 {
                    // a store into a 32-bit variable: the register keeps the sign-extended value (no sxtw when the line before made it)
                    i64 k = rg_slotreg[n / 8];
                    bool ext = i > 0 && rg_sxtw_self(rg_ls[i - 1], r);
                    if ext { rg_text("mov x"); } else { rg_text("sxtw x"); }
                    rg_int(k);
                    rg_text(", x");
                    rg_int(r);
                } else if rg_slotreg[n / 8] != 0 {
                    i64 k = rg_slotreg[n / 8];
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
                    i64 kd = rg_slotd[n / 8];
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
                i64 k2 = 0;
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
            i64 k3 = 0;
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
    par_pass(1);                                             // on many cores when the program is big (jc_par.j)
}

void regs_run_loop() {
    i64 i = 0;
    i64 work = 1;
    if opt_regs == 0 { work = 0; }
    while i < out_len {
        i64 en = rg_end(i);
        if par_open >= 0 && !rg_is_func(i) { par_close_open(); }
        if work == 1 && rg_is_func(i) {
            bool par_skip = par_skip_function();
            // the function: from its label to its last line (the ret after the first epilogue; for main the exit call)
            i64 is_main = 0;
            if rg_has(i, "main:\n") { is_main = 1; }
            rg_n = 0;
            i64 p = i;
            bool done = false;
            bool seen_epi = false;
            bool seen_exit = false;
            bool too_big = false;
            while p < out_len && !done {
                i64 pe = rg_end(p);
                if p != i && rg_is_func(p) { too_big = true; done = true; }
                else if rg_n >= 65535 { too_big = true; done = true; }
                else {
                    rg_ls[rg_n] = p;
                    rg_n += 1;
                    if rg_has(p, "ldr x29, [sp, #0]") { seen_epi = true; }
                    if seen_epi && rg_has(p, "ret\n") { done = true; }
                    if is_main == 1 && rg_has(p, "mov x8, 94\n") { seen_exit = true; }
                    if is_main == 1 && seen_exit && rg_has(p, "svc 0\n") { done = true; }
                }
                p = pe + 1;
            }
            if too_big || !done {
                // not understood (a helper of the runtime): its first line is copied, the lines after it are looked at one by one
                rg_copy(i, en);
                i = en + 1;
            } else if par_skip {
                i64 q = i;                                     // another process works on this function: it is copied as it is
                while q < p {
                    i64 qe = rg_end(q);
                    if !rg_has(q, ";H") { rg_copy(q, qe); }
                    q = qe + 1;
                }
                i = p;
            } else {
                i64 fstart = regs_len;
                rg_function(is_main);
                if opt_regs == 1 { regs_post(fstart); }
                i = p;
            }
        } else {
            if !rg_has(i, ";H") { rg_copy(i, en); }
            i = en + 1;
        }
    }
    i64 t = 0;
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
i64 pt_n;
char pt_m[64];               // a parsed line: the mnemonic and the operands (slot s: 16 + 4 * 40 bytes)
char pt_o[640];
i64 pt_no[4];

// parse the line idx into the slot s; false for a label, a deleted line or a line that is not an instruction
bool pt_parse(i64 s, i64 idx) {
    i64 b = idx * 64;
    if pt_txt[b] == 0 { return false; }
    i64 e = b;
    while pt_txt[e] != 0 { e += 1; }
    if pt_txt[e - 1] == ':' { return false; }
    i64 k = b;
    i64 m = s * 16;
    i64 mc = 0;
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
            i64 o = (s * 4 + pt_no[s]) * 40;
            i64 oc = 0;
            i64 depth = 0;
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

bool pt_mn(i64 s, char^ t) {
    i64 m = s * 16;
    i64 i = 0;
    while t[i] != 0 {
        if pt_m[m + i] != t[i] { return false; }
        i += 1;
    }
    return pt_m[m + i] == 0;
}

bool pt_op(i64 s, i64 k, char^ t) {
    i64 o = (s * 4 + k) * 40;
    i64 i = 0;
    while t[i] != 0 {
        if pt_o[o + i] != t[i] { return false; }
        i += 1;
    }
    return pt_o[o + i] == 0;
}

// is the operand a plain register x0..x30 (not sp, not a number)?
bool pt_isreg(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != 'x' { return false; }
    i64 i = 1;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { i += 1; }
    return pt_o[o + i] == 0;
}

bool pt_isnum(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    if k >= pt_no[s] { return false; }
    i64 i = 0;
    if pt_o[o] == '#' { i = 1; }
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { i += 1; }
    return pt_o[o + i] == 0;
}

// does the operand (s, k) mention the register r (as x r, w r, inside brackets too)?
bool pt_has_reg(i64 s, i64 k, i64 r) {
    i64 o = (s * 4 + k) * 40;
    i64 i = 0;
    while pt_o[o + i] != 0 {
        if (pt_o[o + i] == 'x' || pt_o[o + i] == 'w') && (i == 0 || (pt_o[o + i - 1] < 'a' || pt_o[o + i - 1] > 'z')) && pt_o[o + i + 1] >= '0' && pt_o[o + i + 1] <= '9' {
            i64 j = i + 1;
            i64 v = 0;
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
bool pt_has_dreg(i64 s, i64 k, i64 dn) {
    i64 o = (s * 4 + k) * 40;
    i64 i = 0;
    while pt_o[o + i] != 0 {
        if (pt_o[o + i] == 'd' || pt_o[o + i] == 's' || pt_o[o + i] == 'v' || pt_o[o + i] == 'q') && (i == 0 || (pt_o[o + i - 1] < 'a' || pt_o[o + i - 1] > 'z')) && pt_o[o + i + 1] >= '0' && pt_o[o + i + 1] <= '9' {
            i64 j = i + 1;
            i64 v = 0;
            while pt_o[o + j] >= '0' && pt_o[o + j] <= '9' {
                v = v * 10 + (pt_o[o + j] - '0');
                j += 1;
            }
            if v == dn && (pt_o[o + j] == 0 || pt_o[o + j] == ',' || pt_o[o + j] == ']' || pt_o[o + j] == ' ' || pt_o[o + j] == '.') { return true; }
        }
        i += 1;
    }
    return false;
}

// the register r (0..30: x, 32..63: d) is mentioned by the operand (s, k)
bool pt_rd(i64 s, i64 k, i64 r) {
    if r >= 32 { return pt_has_dreg(s, k, r - 32); }
    return pt_has_reg(s, k, r);
}

// the mnemonics whose first operand is only written
// the offset N of the second operand "[x29, #N]" of the line in slot s (a plain frame cell), or -1 when it has another form
i64 pt_frame_off(i64 s) {
    if pt_no[s] < 2 { return 0 - 1; }
    i64 o = (s * 4 + 1) * 40;
    if pt_o[o] != '[' || pt_o[o + 1] != 'x' || pt_o[o + 2] != '2' || pt_o[o + 3] != '9' || pt_o[o + 4] != ',' || pt_o[o + 5] != ' ' || pt_o[o + 6] != '#' { return 0 - 1; }
    i64 k = o + 7;
    if pt_o[k] < '0' || pt_o[k] > '9' { return 0 - 1; }
    i64 v = 0;
    while pt_o[k] >= '0' && pt_o[k] <= '9' { v = v * 10 + (pt_o[k] - '0'); k += 1; }
    if pt_o[k] != ']' || pt_o[k + 1] != 0 { return 0 - 1; }
    return v;
}

bool pt_writes_first(i64 s) {
    return pt_mn(s, "mov") || pt_mn(s, "ldr") || pt_mn(s, "ldrb") || pt_mn(s, "ldrh") || pt_mn(s, "ldrsw") || pt_mn(s, "ldrsb") || pt_mn(s, "ldrsh") || pt_mn(s, "add") || pt_mn(s, "sub") || pt_mn(s, "mul") || pt_mn(s, "sdiv") || pt_mn(s, "udiv") || pt_mn(s, "and") || pt_mn(s, "orr") || pt_mn(s, "eor") || pt_mn(s, "lsl") || pt_mn(s, "lsr") || pt_mn(s, "asr") || pt_mn(s, "ror") || pt_mn(s, "ror32") || pt_mn(s, "neg") || pt_mn(s, "mvn") || pt_mn(s, "cset") || pt_mn(s, "smulh") || pt_mn(s, "umulh") || pt_mn(s, "msub") || pt_mn(s, "madd") || pt_mn(s, "sxtw") || pt_mn(s, "uxtb") || pt_mn(s, "uxth") || pt_mn(s, "sxtb") || pt_mn(s, "sxth") || pt_mn(s, "adr") || pt_mn(s, "fmov") || pt_mn(s, "fmovi") || pt_mn(s, "fcvtzs") || pt_mn(s, "scvtf") || pt_mn(s, "ucvtf") || pt_mn(s, "fadd") || pt_mn(s, "fsub") || pt_mn(s, "fmul") || pt_mn(s, "fdiv") || pt_mn(s, "fsqrt") || pt_mn(s, "fneg") || pt_mn(s, "fabs") || pt_mn(s, "dup") || pt_mn(s, "fcvt") || pt_mn(s, "frintm") || pt_mn(s, "frintp") || pt_mn(s, "frintz");
}

// the line index of the label L<n> in this function, or -1
i64 pt_label_at(i64 num) {
    i64 li = 0;
    while li < rg_nlab {
        if rg_labn[li] == num { return rg_labl[li]; }
        li += 1;
    }
    return 0 - 1;
}

// is the register r not needed any more from the line idx on? (slot 3 of the parse arrays is used)

// how many whole-number arguments the routine that `bl NAME` (in slot s) calls reads (x0 .. x(n-1)); 8 when it is not known
i64 pt_call_args(i64 s) {
    if pt_no[s] < 1 { return 8; }
    if pt_op(s, 0, "j2k_print_int") || pt_op(s, 0, "j2k_print_str") || pt_op(s, 0, "j2k_print_f64") || pt_op(s, 0, "j2k_print_char") || pt_op(s, 0, "j2k_print_bool") || pt_op(s, 0, "j2k_print_ptr") || pt_op(s, 0, "j2k_print_uint") { return 1; }
    if pt_op(s, 0, "__flush") { return 0; }
    if pt_op(s, 0, "__panic") || pt_op(s, 0, "__Arr__free") || pt_op(s, 0, "__Arr__nullerr") { return 1; }
    if pt_op(s, 0, "__Arr__grow") || pt_op(s, 0, "__Arr__make") { return 2; }
    return 8;
}
i64 pt_steps;
i64 pt_vis[65536];                // the labels that this question has been to (a loop: nothing reads the register on the way round)
i64 pt_vstamp;
bool pt_dead(i64 idx, i64 r, i64 budget) {
    if budget == 40 { pt_steps = 400; pt_vstamp += 1; }                  // a new question: the whole search may take 400 lines
    if budget == 41 { pt_steps = 6000; pt_vstamp += 1; }                 // a new question that may look at a whole big function
    while pt_steps > 0 {
        if idx >= pt_n { return false; }
        pt_steps -= 1;
        i64 b = idx * 64;
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
            i64 o = 3 * 4 * 40;
            if pt_o[o] != 'L' { return false; }
            i64 num = rg_numpt(o + 1);
            i64 at = pt_label_at(num);
            if at < 0 { return false; }
            if at < 65536 {
                if pt_vis[at] == pt_vstamp { return true; }
                pt_vis[at] = pt_vstamp;
            }
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
        if pt_mn(3, "bl") && pt_op(3, 0, "__panic") { return r != 0; }       // __panic(x0) never comes back and reads only x0
        if pt_mn(3, "ret") { return r != 0; }                // only x0 carries the result
        if pt_mn(3, "mov") && pt_op(3, 0, "x8") && (pt_op(3, 1, "94") || pt_op(3, 1, "93")) { return r != 0; }       // the program ends: only x0 (the exit code) is read
        if pt_mn(3, "blr") && pt_no[3] >= 1 && pt_rd(3, 0, r) { return false; }          // the address of the call is read
        // the runtime routines that take few arguments: the argument registers above them are not read by the call, and the call clobbers them
        if r >= 1 && r <= 7 && pt_mn(3, "bl") && r >= pt_call_args(3) { return true; }
        if r >= 8 && r <= 15 && (pt_mn(3, "bl") || pt_mn(3, "blr")) { return true; }       // not an argument register: a call does not read it, and clobbers it
        if r >= 19 && r <= 28 && (pt_mn(3, "bl") || pt_mn(3, "blr")) {
            idx += 1;                                          // a call keeps x19 .. x28 (callee-saved) and cannot read them as arguments
            continue;
        }
        if pt_mn(3, "bl") || pt_mn(3, "blr") || pt_mn(3, "svc") || pt_mn(3, "br") {
            return false;
        }
        if pt_m[48] == 'b' && pt_m[49] == '.' {
            i64 o2 = 3 * 4 * 40;
            if pt_o[o2] != 'L' { return false; }
            i64 num2 = rg_numpt(o2 + 1);
            i64 at2 = pt_label_at(num2);
            if at2 < 0 { return false; }
            bool seen2 = at2 < 65536 && pt_vis[at2] == pt_vstamp;
            if at2 < 65536 { pt_vis[at2] = pt_vstamp; }
            if !seen2 && !pt_dead(at2, r, 1) { return false; }
            idx += 1;
            continue;
        }
        if pt_mn(3, "cbz") || pt_mn(3, "cbnz") || pt_mn(3, "tbz") || pt_mn(3, "tbnz") {
            return false;
        }
        bool first_only = pt_writes_first(3);
        i64 k = 0;
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
        if first_only && pt_no[3] > 0 && (pt_isreg(3, 0) || pt_regno(3, 0, 'd') >= 0 || pt_regno(3, 0, 's') >= 0 || pt_regno(3, 0, 'w') >= 0 || pt_regno(3, 0, 'q') >= 0 || pt_vreg(3, 0) >= 0) && pt_rd(3, 0, r) {
            return true;                                      // msub / madd read their other operands too: that was looked at above
        }
        idx += 1;
    }
    return false;
}

// the number in pt_o at index i
i64 rg_numpt(i64 i) {
    i64 v = 0;
    while pt_o[i] >= '0' && pt_o[i] <= '9' {
        v = v * 10 + (pt_o[i] - '0');
        i += 1;
    }
    return v;
}

// the line idx gets the text s (an empty text deletes it)
void pt_set(i64 idx, char^ t) {
    i64 b = idx * 64;
    i64 i = 0;
    while t[i] != 0 && i < 63 {
        pt_txt[b + i] = t[i];
        i += 1;
    }
    pt_txt[b + i] = 0;
}

// the next live line after idx (an instruction or a label), or -1
i64 pt_next(i64 idx) {
    idx += 1;
    while idx < pt_n && pt_txt[idx * 64] == 0 { idx += 1; }
    if idx >= pt_n { return 0 - 1; }
    return idx;
}

// build "mnem op1, op2, op3" from the slot s with the operand k replaced by the text r (r may be null)
char pt_line[64];
void pt_build(i64 s, i64 k, char^ r) {
    i64 n = 0;
    i64 m = s * 16;
    i64 i = 0;
    while pt_m[m + i] != 0 {
        pt_line[n] = pt_m[m + i];
        n += 1;
        i += 1;
    }
    i64 j = 0;
    while j < pt_no[s] {
        pt_line[n] = ',';
        if j == 0 { pt_line[n] = ' '; }
        n += 1;
        if j > 0 {
            pt_line[n] = ' ';
            n += 1;
        }
        i64 o = (s * 4 + j) * 40;
        i64 c = 0;
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

// the line of slot s with the register x<from> (and w<from>) read in its operands replaced by x<to> (w<to>); the first operand is left alone when
// the mnemonic writes it (pt_writes_first). Fills pt_line.
void pt_build_subst(i64 s, i64 from, i64 to) {
    i64 n = 0;
    i64 m = s * 16;
    i64 i = 0;
    while pt_m[m + i] != 0 {
        pt_line[n] = pt_m[m + i];
        n += 1;
        i += 1;
    }
    bool keep0 = pt_writes_first(s);
    i64 j = 0;
    while j < pt_no[s] {
        pt_line[n] = ',';
        if j == 0 { pt_line[n] = ' '; }
        n += 1;
        if j > 0 {
            pt_line[n] = ' ';
            n += 1;
        }
        i64 o = (s * 4 + j) * 40;
        i64 c = 0;
        while pt_o[o + c] != 0 && n < 60 {
            char ch = pt_o[o + c];
            bool token = (ch == 'x' || ch == 'w') && !(j == 0 && keep0) && (c == 0 || pt_o[o + c - 1] < 'a' || pt_o[o + c - 1] > 'z') && pt_o[o + c + 1] >= '0' && pt_o[o + c + 1] <= '9';
            if token {
                i64 q = c + 1;
                i64 v = 0;
                while pt_o[o + q] >= '0' && pt_o[o + q] <= '9' { v = v * 10 + (pt_o[o + q] - '0'); q += 1; }
                if v == from {
                    pt_line[n] = ch;
                    n += 1;
                    char dg[8];
                    i64 dn = 0;
                    i64 dv = to;
                    if dv == 0 { dg[0] = '0'; dn = 1; }
                    while dv > 0 { dg[dn] = '0' + dv % 10; dn += 1; dv = dv / 10; }
                    while dn > 0 { dn -= 1; pt_line[n] = dg[dn]; n += 1; }
                    c = q;
                    continue;
                }
            }
            pt_line[n] = ch;
            n += 1;
            c += 1;
        }
        j += 1;
    }
    pt_line[n] = 0;
}


// the mnemonics in which a register that is read may be replaced by a copy of it
bool pt_copy_ok(i64 s) {
    return pt_mn(s, "add") || pt_mn(s, "sub") || pt_mn(s, "mul") || pt_mn(s, "sdiv") || pt_mn(s, "udiv") || pt_mn(s, "and") || pt_mn(s, "orr") || pt_mn(s, "eor") || pt_mn(s, "lsl") || pt_mn(s, "lsr") || pt_mn(s, "asr") || pt_mn(s, "cmp") || pt_mn(s, "str") || pt_mn(s, "ldr") || pt_mn(s, "strb") || pt_mn(s, "ldrb") || pt_mn(s, "ldrsb") || pt_mn(s, "ldrsw") || pt_mn(s, "strh") || pt_mn(s, "ldrh") || pt_mn(s, "fmov") || pt_mn(s, "scvtf") || pt_mn(s, "neg") || pt_mn(s, "mvn") || pt_mn(s, "sxtw") || pt_mn(s, "uxtb") || pt_mn(s, "sxtb") || pt_mn(s, "msub") || pt_mn(s, "madd") || pt_mn(s, "smulh") || pt_mn(s, "mov");
}

// the line of the slot s with every x<r> that is read replaced by the text rep, in pt_line; returns how many were replaced
// (the first operand is a destination, and is left as it is, for the mnemonics that write their first operand)
char pt_sub_prefix;
i64 pt_subst(i64 s, i64 r, char^ rep, bool dest_first) {
    i64 n = 0;
    i64 m = s * 16;
    i64 i = 0;
    i64 count = 0;
    while pt_m[m + i] != 0 {
        pt_line[n] = pt_m[m + i];
        n += 1;
        i += 1;
    }
    i64 j = 0;
    while j < pt_no[s] {
        pt_line[n] = ',';
        if j == 0 { pt_line[n] = ' '; }
        n += 1;
        if j > 0 {
            pt_line[n] = ' ';
            n += 1;
        }
        i64 o = (s * 4 + j) * 40;
        i64 c = 0;
        while pt_o[o + c] != 0 {
            bool hit = false;
            if pt_o[o + c] == pt_sub_prefix && (c == 0 || pt_o[o + c - 1] < 'a' || pt_o[o + c - 1] > 'z') && pt_o[o + c + 1] >= '0' && pt_o[o + c + 1] <= '9' && !(j == 0 && dest_first) {
                i64 q = c + 1;
                i64 v = 0;
                while pt_o[o + q] >= '0' && pt_o[o + q] <= '9' {
                    v = v * 10 + (pt_o[o + q] - '0');
                    q += 1;
                }
                if v == r {
                    i64 t = 0;
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
// a vector operand "v27.4s" / "v3.2d": the number of the register (else -1); pt_varr is 1 for .4s, 2 for .2d, 0 for another arrangement
i64 pt_varr;
i64 pt_vreg(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    pt_varr = 0;
    if k >= pt_no[s] || pt_o[o] != 'v' { return 0 - 1; }
    i64 i = 1;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return 0 - 1; }
    i64 v = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { v = v * 10 + (pt_o[o + i] - '0'); i += 1; }
    if pt_o[o + i] != '.' { return 0 - 1; }
    if pt_o[o + i + 1] == '4' && pt_o[o + i + 2] == 's' && pt_o[o + i + 3] == 0 { pt_varr = 1; }
    else if pt_o[o + i + 1] == '2' && pt_o[o + i + 2] == 'd' && pt_o[o + i + 3] == 0 { pt_varr = 2; }
    return v;
}

i64 pt_regno(i64 s, i64 k, char prefix) {
    i64 o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != prefix { return 0 - 1; }
    i64 i = 1;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return 0 - 1; }
    i64 v = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] != 0 { return 0 - 1; }
    return v;
}

i64 pt_val[64];              // the value number of each register: x0..x30 are 0..30, d0..d31 are 32..63 (0: not known)
i64 pt_vnext;

void pt_vn_clear() {
    i64 i = 0;
    while i < 64 {
        pt_val[i] = 0;
        i += 1;
    }
}

i64 pt_vn_get(i64 r) {
    if pt_val[r] == 0 {
        pt_vnext += 1;
        pt_val[r] = pt_vnext;
    }
    return pt_val[r];
}

void pt_vn_fresh(i64 r) {
    pt_vnext += 1;
    pt_val[r] = pt_vnext;
}

// a double register (32 + n) other than skip that holds the value id, or -1
i64 pt_vn_find_d(i64 id, i64 skip) {
    i64 i = 32;
    while i < 64 {
        if pt_val[i] == id && i != skip { return i; }
        i += 1;
    }
    return 0 - 1;
}

// the mnemonics that write a double register as their first operand
bool pt_writes_d(i64 s) {
    return pt_mn(s, "fadd") || pt_mn(s, "fsub") || pt_mn(s, "fmul") || pt_mn(s, "fdiv") || pt_mn(s, "fsqrt") || pt_mn(s, "fneg") || pt_mn(s, "fabs") || pt_mn(s, "scvtf") || pt_mn(s, "ucvtf") || pt_mn(s, "fcvt") || pt_mn(s, "frintm") || pt_mn(s, "frintp") || pt_mn(s, "frintz") || pt_mn(s, "fmov") || pt_mn(s, "ldr");
}

// the mnemonics that write nothing that matters here
bool pt_writes_nothing(i64 s) {
    return pt_mn(s, "str") || pt_mn(s, "strb") || pt_mn(s, "strh") || pt_mn(s, "cmp") || pt_mn(s, "fcmp") || pt_mn(s, "b") || (pt_m[s * 16] == 'b' && pt_m[s * 16 + 1] == '.') || pt_mn(s, "cbz") || pt_mn(s, "cbnz") || pt_mn(s, "tbz") || pt_mn(s, "tbnz") || pt_mn(s, "tst") || pt_mn(s, "nop");
}

// the line "mnemonic dA, dB" written into pt_line
void pt_line_dd(char^ mn, i64 a, i64 b) {
    i64 n = 0;
    while mn[n] != 0 {
        pt_line[n] = mn[n];
        n += 1;
    }
    pt_line[n] = ' ';
    pt_line[n + 1] = 'd';
    n += 2;
    char dg[8];
    i64 dn = 0;
    i64 dv = a;
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
    i64 i = 0;
    while i < pt_n {
        if pt_txt[i * 64] != 0 {
            if !pt_parse(0, i) {
                pt_vn_clear();                                   // a label: the flow comes from elsewhere too
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'x') >= 0 {
                i64 dk = 32 + pt_regno(0, 0, 'd');
                i64 xn = pt_regno(0, 1, 'x');
                i64 id = pt_vn_get(xn);
                if pt_val[dk] == id {
                    pt_set(i, "");
                    changed = true;
                } else {
                    i64 dm = pt_vn_find_d(id, dk);
                    if dm >= 0 {
                        pt_line_dd("fmov", dk - 32, dm - 32);
                        pt_set(i, @pt_line);
                        changed = true;
                    }
                    pt_val[dk] = id;
                }
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 {
                i64 xn2 = pt_regno(0, 0, 'x');
                i64 id2 = pt_vn_get(32 + pt_regno(0, 1, 'd'));
                if pt_val[xn2] == id2 {
                    pt_set(i, "");
                    changed = true;
                } else {
                    pt_val[xn2] = id2;
                }
            } else if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 {
                i64 dk3 = 32 + pt_regno(0, 0, 'd');
                i64 id3 = pt_vn_get(32 + pt_regno(0, 1, 'd'));
                if pt_val[dk3] == id3 {
                    pt_set(i, "");
                    changed = true;
                } else {
                    pt_val[dk3] = id3;
                }
            } else if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 {
                i64 a = pt_regno(0, 0, 'x');
                i64 b = pt_regno(0, 1, 'x');
                if b >= 0 {
                    i64 id4 = pt_vn_get(b);
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
                i64 dd0 = 32 + pt_regno(0, 0, 'd');
                if pt_no[0] == 3 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 2, 'd') >= 0 && pt_regno(0, 1, 'd') != pt_regno(0, 2, 'd') && pt_val[32 + pt_regno(0, 1, 'd')] != 0 && pt_val[32 + pt_regno(0, 1, 'd')] == pt_val[32 + pt_regno(0, 2, 'd')] && !pt_mn(0, "ldr") {
                    i64 r1 = pt_regno(0, 1, 'd');
                    char nl2[40];
                    i64 n2 = 0;
                    i64 m0 = 0;
                    while pt_m[m0] != 0 { nl2[n2] = pt_m[m0]; n2 += 1; m0 += 1; }
                    nl2[n2] = ' ';
                    n2 += 1;
                    // dD, dR1, dR1
                    char dg[8];
                    i64 dn = 0;
                    i64 pass = 0;
                    while pass < 3 {
                        i64 v = pt_regno(0, 0, 'd');
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
// b.cc LA / b LB / (labels) LA:   ->   b.!cc LB / (labels) LA:
bool pt_branch_over(i64 i) {
    i64 bi = i * 64;
    if pt_txt[bi] != 'b' || pt_txt[bi + 1] != '.' || pt_txt[bi + 4] != ' ' || pt_txt[bi + 5] != 'L' { return false; }
    i64 j = pt_next(i);
    if j < 0 { return false; }
    i64 bj = j * 64;
    if pt_txt[bj] != 'b' || pt_txt[bj + 1] != ' ' || pt_txt[bj + 2] != 'L' { return false; }
    // the target of the first jump must be one of the labels that follow the second
    i64 k = pt_next(j);
    bool found = false;
    i64 guard = 0;
    while k >= 0 && guard < 8 && !found {
        i64 bk = k * 64;
        i64 e = bk;
        while pt_txt[e] != 0 { e += 1; }
        if pt_txt[e - 1] != ':' { break; }
        // compare "L<num>:" with the operand of the first jump
        i64 c = 0;
        bool same = true;
        while c < e - bk - 1 {
            if pt_txt[bk + c] != pt_txt[bi + 5 + c] { same = false; }
            c += 1;
        }
        if same && (pt_txt[bi + 5 + c] == 0) { found = true; }
        k = pt_next(k);
        guard += 1;
    }
    if !found { return false; }
    char c0 = pt_txt[bi + 2];
    char c1 = pt_txt[bi + 3];
    char n0 = ' ';
    char n1 = ' ';
    if c0 == 'e' && c1 == 'q' { n0 = 'n'; n1 = 'e'; }
    else if c0 == 'n' && c1 == 'e' { n0 = 'e'; n1 = 'q'; }
    else if c0 == 'l' && c1 == 't' { n0 = 'g'; n1 = 'e'; }
    else if c0 == 'g' && c1 == 'e' { n0 = 'l'; n1 = 't'; }
    else if c0 == 'g' && c1 == 't' { n0 = 'l'; n1 = 'e'; }
    else if c0 == 'l' && c1 == 'e' { n0 = 'g'; n1 = 't'; }
    else if c0 == 'l' && c1 == 'o' { n0 = 'h'; n1 = 's'; }
    else if c0 == 'h' && c1 == 's' { n0 = 'l'; n1 = 'o'; }
    else if c0 == 'h' && c1 == 'i' { n0 = 'l'; n1 = 's'; }
    else if c0 == 'l' && c1 == 's' { n0 = 'h'; n1 = 'i'; }
    else if c0 == 'm' && c1 == 'i' { n0 = 'p'; n1 = 'l'; }
    else if c0 == 'p' && c1 == 'l' { n0 = 'm'; n1 = 'i'; }
    else { return false; }
    char nl[64];
    nl[0] = 'b'; nl[1] = '.'; nl[2] = n0; nl[3] = n1; nl[4] = ' ';
    i64 n = 5;
    i64 c2 = 2;
    while pt_txt[bj + c2] != 0 { nl[n] = pt_txt[bj + c2]; n += 1; c2 += 1; }
    nl[n] = 0;
    pt_set(i, @nl);
    pt_set(j, "");
    return true;
}

// the copy of a double `fmov dT, dV` at the line i: every read of dT in the lines that follow (up to the first label, jump or call, or until
// dT or dV is written) reads dV instead; the copy goes when dT is not needed after that. Nothing is changed unless all of it works.
char pt_fk = 'd';              // the kind of the float registers that pt_fwd_copy looks at: 'd' (doubles) or 's' (floats)
i64 pt_fc_line[16];
char pt_fc_txt[1024];

bool pt_op_is_d(i64 s, i64 o, i64 n) {
    i64 b = (s * 4 + o) * 40;
    if pt_o[b] != pt_fk { return false; }
    i64 v = 0;
    i64 c = 1;
    while pt_o[b + c] >= '0' && pt_o[b + c] <= '9' { v = v * 10 + (pt_o[b + c] - '0'); c += 1; }
    return c > 1 && pt_o[b + c] == 0 && v == n;
}


// the copy of an integer `mov xT, xV` at the line i: the reads of xT in the lines that follow (a b.cond whose target does not need xT is looked through)
// read xV instead; the copy goes when xT is not needed after that. Only the instructions of the list below are changed; any other line that
// mentions xT or xV ends it. Nothing is changed unless all of it works.
i64 pt_ic_line[16];
char pt_ic_txt[1024];
bool pt_fwd_icopy(i64 i) {
    if !pt_parse(0, i) { return false; }
    i64 rt = pt_regno(0, 0, 'x');
    i64 rv = pt_regno(0, 1, 'x');
    i64 nrep = 0;
    i64 at = pt_next(i);
    i64 steps = 0;
    bool t_dead = false;
    while at >= 0 && steps < 12 && !t_dead {
        steps += 1;
        if pt_txt[at * 64] == 0 { at = pt_next(at); continue; }
        if !pt_parse(2, at) { return false; }                      // a label: the flow comes from elsewhere too
        if pt_m[32] == 'b' && pt_m[33] == '.' && pt_o[2 * 4 * 40] == 'L' {
            i64 bat = pt_label_at(rg_numpt(2 * 4 * 40 + 1));
            if bat >= 0 && pt_dead(bat, rt, 40) { at = pt_next(at); continue; }
            return false;
        }
        if pt_m[32] == 'b' || pt_mn(2, "cbz") || pt_mn(2, "cbnz") || pt_mn(2, "tbz") || pt_mn(2, "tbnz") || pt_mn(2, "ret") || pt_mn(2, "svc") || pt_mn(2, "blr") || pt_mn(2, "br") {
            if pt_dead(at, rt, 40) { t_dead = true; break; }
            return false;
        }
        i64 np = pt_no[2];
        bool w0 = pt_writes_first(2);
        bool reads_t = false;
        bool mention_v = false;
        i64 o = 0;
        while o < np {
            if pt_rd(2, o, rt) && !(o == 0 && w0) { reads_t = true; }
            if pt_rd(2, o, rv) { mention_v = true; }
            o += 1;
        }
        bool dest_t = w0 && np >= 1 && (pt_regno(2, 0, 'x') == rt || pt_regno(2, 0, 'w') == rt);          // a write of wT writes xT too
        bool dest_v = w0 && np >= 1 && (pt_regno(2, 0, 'x') == rv || pt_regno(2, 0, 'w') == rv);
        bool mentions = reads_t || dest_t || mention_v;
        if !mentions { at = pt_next(at); continue; }
        bool okm = pt_mn(2, "str") || pt_mn(2, "strw") || pt_mn(2, "strb") || pt_mn(2, "strh") || pt_mn(2, "ldr") || pt_mn(2, "ldrsw") || pt_mn(2, "ldrb") || pt_mn(2, "ldrh") || pt_mn(2, "ldrsb") || pt_mn(2, "ldrsh")
            || pt_mn(2, "cmp") || pt_mn(2, "cmn") || pt_mn(2, "tst") || pt_mn(2, "add") || pt_mn(2, "sub") || pt_mn(2, "mul") || pt_mn(2, "and") || pt_mn(2, "orr") || pt_mn(2, "eor") || pt_mn(2, "lsl") || pt_mn(2, "lsr") || pt_mn(2, "asr")
            || pt_mn(2, "sxtw") || pt_mn(2, "scvtf") || pt_mn(2, "sdiv") || pt_mn(2, "udiv") || pt_mn(2, "madd") || pt_mn(2, "msub") || pt_mn(2, "neg") || pt_mn(2, "mvn") || pt_mn(2, "mov");
        if !okm { return false; }
        bool changed = false;
        if reads_t {
            if nrep >= 14 { return false; }
            pt_build_subst(2, rt, rv);
            pt_ic_line[nrep] = at;
            i64 c2 = 0;
            while pt_line[c2] != 0 && c2 < 62 { pt_ic_txt[nrep * 64 + c2] = pt_line[c2]; c2 += 1; }
            pt_ic_txt[nrep * 64 + c2] = 0;
            nrep += 1;
            changed = true;
        }
        if dest_t { t_dead = true; break; }
        if dest_v {
            // xV changes here: later reads of xT could no longer be taken from xV
            if pt_dead(pt_next(at), rt, 40) { t_dead = true; break; }
            return false;
        }
        at = pt_next(at);
    }
    if nrep == 0 { return false; }
    if !t_dead {
        if at < 0 || !pt_dead(at, rt, 40) { return false; }
    }
    i64 r = 0;
    while r < nrep {
        pt_set(pt_ic_line[r], @pt_ic_txt + r * 64);
        r += 1;
    }
    pt_set(i, "");
    return true;
}

bool pt_fwd_copy(i64 i) {
    if !pt_parse(0, i) { return false; }
    i64 t = pt_regno(0, 0, pt_fk);
    i64 v = pt_regno(0, 1, pt_fk);
    i64 nrep = 0;
    i64 at = pt_next(i);
    i64 steps = 0;
    bool t_dead = false;           // dT is written again, or not needed any more
    while at >= 0 && steps < 12 && !t_dead {
        steps += 1;
        if pt_txt[at * 64] == 0 { at = pt_next(at); continue; }
        if !pt_parse(2, at) {
            // a label: the flow comes from elsewhere too
            return false;
        }
        if pt_m[32] == 'b' && pt_m[33] == '.' && pt_o[2 * 4 * 40] == 'L' {
            // a conditional branch (b.eq ...): the copy may be looked through it when the register dT is not needed on the path it jumps to
            // (the null check and the bounds check jump to a panic and never come back)
            i64 bat = pt_label_at(rg_numpt(2 * 4 * 40 + 1));
            if bat >= 0 && pt_dead(bat, 32 + t, 40) { at = pt_next(at); continue; }
        }
        bool barrier = pt_m[32] == 'b' || pt_mn(2, "cbz") || pt_mn(2, "cbnz") || pt_mn(2, "tbz") || pt_mn(2, "tbnz") || pt_mn(2, "ret") || pt_mn(2, "svc") || pt_mn(2, "blr");
        if barrier {
            if pt_dead(at, 32 + t, 40) { t_dead = true; }
            else { return false; }
            break;
        }
        i64 np = pt_no[2];
        bool mention_t = false;
        bool mention_v = false;
        i64 o = 0;
        while o < np {
            if pt_rd(2, o, 32 + t) { mention_t = true; }
            if pt_rd(2, o, 32 + v) { mention_v = true; }
            o += 1;
        }
        if !mention_t && !mention_v { at = pt_next(at); continue; }
        // which form is it
        bool fp3 = pt_mn(2, "fadd") || pt_mn(2, "fsub") || pt_mn(2, "fmul") || pt_mn(2, "fdiv") || pt_mn(2, "fmadd") || pt_mn(2, "fmsub") || pt_mn(2, "fnmadd") || pt_mn(2, "fnmsub") || pt_mn(2, "fsqrt") || pt_mn(2, "fneg") || pt_mn(2, "fabs") || pt_mn(2, "fmov");
        bool cmp = pt_mn(2, "fcmp");
        bool st = pt_mn(2, "str");
        if !fp3 && !cmp && !st {
            if mention_t { return false; }
            // it touches dV only: a write of dV ends the forwarding; a read does not matter
            // any other line that has dV as its first operand writes it (fmovi, ldr, scvtf ...); stores and compares only read
            if pt_no[2] >= 1 && pt_rd(2, 0, 32 + v) && !pt_mn(2, "str") && !pt_mn(2, "fcmp") {
                if pt_dead(at, 32 + t, 40) { t_dead = true; break; }
                return false;
            }
            at = pt_next(at);
            continue;
        }
        // reads of dT: operands other than the first (the first for fcmp and str); an operand that names dT in another way stops it
        bool writes_t = false;
        bool writes_v = false;
        bool changed = false;
        char nl4[64];
        i64 n4 = 0;
        i64 mm = 2 * 16;
        i64 mi = 0;
        while pt_m[mm + mi] != 0 { nl4[n4] = pt_m[mm + mi]; n4 += 1; mi += 1; }
        o = 0;
        while o < np {
            nl4[n4] = ',';
            if o == 0 { nl4[n4] = ' '; }
            n4 += 1;
            if o > 0 { nl4[n4] = ' '; n4 += 1; }
            bool is_dest = o == 0 && !cmp && !st;
            i64 ob = (2 * 4 + o) * 40;
            if pt_op_is_d(2, o, t) {
                if is_dest { writes_t = true; }
                else {
                    nl4[n4] = pt_fk; n4 += 1;
                    if v >= 10 { nl4[n4] = '0' + v / 10; n4 += 1; }
                    nl4[n4] = '0' + v % 10; n4 += 1;
                    changed = true;
                    o += 1;
                    continue;
                }
            } else if pt_rd(2, o, 32 + t) {
                return false;
            }
            if pt_op_is_d(2, o, v) && is_dest { writes_v = true; }
            if pt_rd(2, o, 32 + v) && !pt_op_is_d(2, o, v) && is_dest { return false; }
            i64 c = 0;
            while pt_o[ob + c] != 0 { nl4[n4] = pt_o[ob + c]; n4 += 1; c += 1; }
            o += 1;
        }
        nl4[n4] = 0;
        if changed {
            if nrep >= 14 { return false; }
            pt_fc_line[nrep] = at;
            i64 c2 = 0;
            while nl4[c2] != 0 { pt_fc_txt[nrep * 64 + c2] = nl4[c2]; c2 += 1; }
            pt_fc_txt[nrep * 64 + c2] = 0;
            nrep += 1;
        }
        if writes_t { t_dead = true; break; }
        if writes_v {
            if pt_dead(pt_next(at), 32 + t, 40) { t_dead = true; break; }
            return false;
        }
        at = pt_next(at);
    }
    if nrep == 0 { return false; }
    if !t_dead {
        // the end of the window: dT must not be needed after the last line looked at
        if at < 0 || !pt_dead(at, 32 + t, 40) { return false; }
    }
    i64 r = 0;
    while r < nrep {
        pt_set(pt_fc_line[r], @pt_fc_txt + r * 64);
        r += 1;
    }
    pt_set(i, "");
    return true;
}


bool pt_rules(i64 i) {
    if pt_branch_over(i) { return true; }
    i64 j = pt_next(i);
    if j < 0 { return false; }
    if !pt_parse(0, i) { return false; }
    if !pt_parse(1, j) { return false; }
    // mov xD, xS  /  mov xD, N   where nothing reads xD before it is written again (or the function ends): the line does nothing
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_isreg(0, 0) && (pt_isreg(0, 1) || pt_isnum(0, 1)) {
        i64 dr = pt_regno(0, 0, 'x');
        if (dr >= 1 && dr <= 7) || (dr >= 9 && dr <= 17) || (dr >= 19 && dr <= 25) {
            if pt_dead(j, dr, 40) {
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // OP xA, ... / mov xK, xA   where xA is not needed afterwards   ->   OP xK, ...   (the operation writes the register it was meant for)
    if pt_no[0] >= 2 && pt_isreg(0, 0) && pt_mn(1, "mov") && pt_no[1] == 2 && pt_isreg(1, 0) && pt_isreg(1, 1) && (pt_mn(0, "add") || pt_mn(0, "sub") || pt_mn(0, "mul") || pt_mn(0, "and") || pt_mn(0, "orr") || pt_mn(0, "eor") || pt_mn(0, "lsl") || pt_mn(0, "lsr") || pt_mn(0, "asr") || pt_mn(0, "smulh") || pt_mn(0, "umulh") || pt_mn(0, "msub") || pt_mn(0, "madd") || pt_mn(0, "sdiv") || pt_mn(0, "udiv")) {
        i64 fa0 = pt_regno(0, 0, 'x');
        i64 fk = pt_regno(1, 0, 'x');
        i64 fs = pt_regno(1, 1, 'x');
        if fa0 == fs && fk != fa0 && fa0 >= 0 && fa0 <= 17 && fk >= 0 && fk <= 25 && fk != 18 {
            if pt_dead(pt_next(j), fa0, 40) {
                char fkn[8];
                i64 fq = 0;
                fkn[fq] = 'x'; fq += 1;
                if fk >= 10 { fkn[fq] = '0' + fk / 10; fq += 1; }
                fkn[fq] = '0' + fk % 10; fq += 1;
                fkn[fq] = 0;
                pt_build(0, 0, @fkn);
                char fnl[64];
                i64 fc2 = 0;
                while pt_line[fc2] != 0 { fnl[fc2] = pt_line[fc2]; fc2 += 1; }
                fnl[fc2] = 0;
                pt_set(i, @fnl);
                pt_set(j, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // lsl xD, xA, #n / add xD, xB, xD   ->   add xD, xB, xA, lsl #n      (also with the operands of the add the other way round):
    // the register xD gets the same value, the shifted number was only on its way
    if pt_mn(0, "lsl") && pt_no[0] == 3 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isnum(0, 2) && pt_mn(1, "add") && pt_no[1] == 3 && pt_isreg(1, 0) && pt_isreg(1, 1) && pt_isreg(1, 2) {
        i64 sd = pt_regno(0, 0, 'x');
        i64 sa = pt_regno(0, 1, 'x');
        i64 ad = pt_regno(1, 0, 'x');
        i64 ab = pt_regno(1, 1, 'x');
        i64 ac = pt_regno(1, 2, 'x');
        i64 other = 0 - 1;
        if ad == sd && ac == sd && ab != sd { other = ab; }
        else if ad == sd && ab == sd && ac != sd { other = ac; }
        i64 sn = 0;
        i64 so = (0 * 4 + 2) * 40;
        i64 si = 0;
        if pt_o[so] == '#' { si = 1; }
        while pt_o[so + si] >= '0' && pt_o[so + si] <= '9' && sn < 100 {
            sn = sn * 10 + (pt_o[so + si] - '0');
            si += 1;
        }
        if other >= 0 && sd >= 0 && sa >= 0 && sd <= 30 && sa <= 30 && other <= 30 && sn >= 1 && sn <= 4 {
            char sl[48];
            i64 q = 0;
            sl[q] = 'a'; sl[q + 1] = 'd'; sl[q + 2] = 'd'; sl[q + 3] = ' '; q += 4;
            i64 parts[3];
            parts[0] = sd; parts[1] = other; parts[2] = sa;
            i64 pi = 0;
            while pi < 3 {
                sl[q] = 'x'; q += 1;
                i64 rv = parts[pi];
                if rv >= 10 { sl[q] = '0' + rv / 10; q += 1; }
                sl[q] = '0' + rv % 10; q += 1;
                sl[q] = ','; sl[q + 1] = ' '; q += 2;
                pi += 1;
            }
            q -= 2;
            sl[q] = ','; sl[q + 1] = ' '; sl[q + 2] = 'l'; sl[q + 3] = 's'; sl[q + 4] = 'l'; sl[q + 5] = ' '; sl[q + 6] = '#'; q += 7;
            sl[q] = '0' + sn; q += 1;
            sl[q] = 0;
            pt_set(i, "");
            pt_set(j, @sl);
            return true;
        }
    }
    // dup vX.A, wN / <one line that writes neither vX nor wN> / dup vX.A, wN (the same text)  ->  the second dup is dropped
    if pt_mn(0, "dup") && pt_no[0] == 2 && pt_vreg(0, 0) >= 0 {
        i64 dx = pt_vreg(0, 0);
        i64 j2 = pt_next(j);
        bool dsame = j2 >= 0 && j2 < pt_n;
        if dsame {
            i64 dc = 0;
            while dc < 64 && dsame {
                if pt_txt[i * 64 + dc] != pt_txt[j2 * 64 + dc] { dsame = false; }
                if pt_txt[i * 64 + dc] == 0 { break; }
                dc += 1;
            }
        }
        if dsame && (pt_mn(1, "fmla") || pt_mn(1, "fadd") || pt_mn(1, "fmul") || pt_mn(1, "fsub")) && pt_no[1] == 3 && pt_vreg(1, 0) >= 0 && pt_vreg(1, 0) != dx {
            pt_set(j2, "");
            pt_parse(0, i);
            pt_parse(1, j);
            return true;
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // vector multiply-add:  fmul vT.A, vX.A, vY.A / fadd vD.A, vD.A, vT.A (or vT, vD) with vT not needed afterwards  ->  fmla vD.A, vX.A, vY.A
    // (the multiply is dropped, so vX and vY are untouched; fmla reads the old vD, vX and vY). Not in a function with the line ;NOFMA.
    if opt_fma == 1 && rg_nofma_fn == 0 && pt_mn(0, "fmul") && pt_no[0] == 3 && pt_mn(1, "fadd") && pt_no[1] == 3 {
        i64 vt = pt_vreg(0, 0);
        i64 vta = pt_varr;
        i64 vx = pt_vreg(0, 1);
        i64 vxa = pt_varr;
        i64 vy = pt_vreg(0, 2);
        i64 vya = pt_varr;
        i64 vd = pt_vreg(1, 0);
        i64 vda = pt_varr;
        i64 v1 = pt_vreg(1, 1);
        i64 v1a = pt_varr;
        i64 v2 = pt_vreg(1, 2);
        i64 v2a = pt_varr;
        if vta != 0 && vt >= 0 && vx >= 0 && vy >= 0 && vd >= 0 && v1 >= 0 && v2 >= 0 && vxa == vta && vya == vta && vda == vta && v1a == vta && v2a == vta && vd != vt
            && ((v1 == vd && v2 == vt) || (v2 == vd && v1 == vt)) && pt_dead(pt_next(j), 32 + vt, 40) {
            char vl[48];
            i64 vq = 0;
            vl[0] = 'f'; vl[1] = 'm'; vl[2] = 'l'; vl[3] = 'a'; vl[4] = ' '; vq = 5;
            i64 vparts[3];
            vparts[0] = vd; vparts[1] = vx; vparts[2] = vy;
            i64 vpi = 0;
            while vpi < 3 {
                vl[vq] = 'v'; vq += 1;
                i64 vr = vparts[vpi];
                if vr >= 10 { vl[vq] = '0' + vr / 10; vq += 1; }
                vl[vq] = '0' + vr % 10; vq += 1;
                vl[vq] = '.'; vq += 1;
                if vta == 1 { vl[vq] = '4'; vl[vq + 1] = 's'; } else { vl[vq] = '2'; vl[vq + 1] = 'd'; }
                vq += 2;
                if vpi < 2 { vl[vq] = ','; vl[vq + 1] = ' '; vq += 2; }
                vpi += 1;
            }
            vl[vq] = 0;
            pt_set(i, "");
            pt_set(j, @vl);
            return true;
        }
    }
    // fmul dT, dA, dB ... fadd|fsub dD, ...  where one operand of the add is dT (not needed afterwards, or written by the add) and the
    // lines in between do not touch dT and do not write dA / dB (at most 4 lines):
    //   fmadd dD, dA, dB, dC   (C + T)      fmsub dD, dA, dB, dC  (C - T)      fnmsub dD, dA, dB, dC  (T - C)
    if opt_fma == 1 && rg_nofma_fn == 0 && pt_mn(0, "fmul") && pt_no[0] == 3 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 2, 'd') >= 0 {
        i64 ft = pt_regno(0, 0, 'd');
        i64 fa = pt_regno(0, 1, 'd');
        i64 fb = pt_regno(0, 2, 'd');
        i64 fj = j;
        i64 fsteps = 0;
        i64 ffound = 0 - 1;
        i64 fkind = 0;
        i64 fc = 0 - 1;
        i64 fd = 0 - 1;
        i64 fixl = 0 - 1;                          // a load that writes dA / dB and gives the addend: it loads into dT (free) instead
        i64 fixr = 0 - 1;
        char fixtext[64];
        bool ffail = false;
        while fj >= 0 && fsteps < 5 && ffound < 0 && !ffail {
            if !pt_parse(1, fj) { ffail = true; break; }
            if pt_mn(1, "b") || pt_mn(1, "bl") || pt_mn(1, "blr") || pt_mn(1, "ret") || pt_mn(1, "svc") || pt_mn(1, "cbz") || pt_mn(1, "cbnz") || pt_mn(1, "tbz") || pt_mn(1, "tbnz") || (pt_m[16] == 'b' && pt_m[17] == '.') { ffail = true; break; }
            bool isfa = (pt_mn(1, "fadd") || pt_mn(1, "fsub")) && pt_no[1] == 3 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'd') >= 0 && pt_regno(1, 2, 'd') >= 0;
            i64 fx = 0 - 1;
            i64 fy = 0 - 1;
            if isfa { fx = pt_regno(1, 1, 'd'); fy = pt_regno(1, 2, 'd'); }
            if isfa && ((fx == ft && fy != ft) || (fy == ft && fx != ft)) {
                bool isadd = pt_mn(1, "fadd");
                fd = pt_regno(1, 0, 'd');
                if fx == ft { fc = fy; if isadd { fkind = 0; } else { fkind = 2; } }
                else { fc = fx; if isadd { fkind = 0; } else { fkind = 1; } }
                if fixl >= 0 {
                    // the addend is the loaded value; the register it had must not be needed afterwards (unless the result goes there)
                    if fc != fixr { ffail = true; }
                    else if fd != fixr && !pt_dead(pt_next(fj), 32 + fixr, 40) { ffail = true; }
                    else { ffound = fj; }
                } else if fd == ft || pt_dead(pt_next(fj), 32 + ft, 40) { ffound = fj; } else { ffail = true; }
            } else {
                // another line: it may not read or write dT, nor write dA or dB
                i64 fk = 0;
                while fk < pt_no[1] {
                    if pt_has_dreg(1, fk, ft) { ffail = true; }
                    fk += 1;
                }
                if fixl >= 0 {
                    i64 fk2 = 0;
                    while fk2 < pt_no[1] {
                        if pt_has_dreg(1, fk2, fixr) { ffail = true; }
                        fk2 += 1;
                    }
                }
                if pt_writes_first(1) && pt_no[1] > 0 && (pt_has_dreg(1, 0, fa) || pt_has_dreg(1, 0, fb)) {
                    if pt_mn(1, "ldr") && pt_no[1] == 2 && fixl < 0 && !ffail && ft != fa && ft != fb {
                        fixl = fj;
                        fixr = pt_regno(1, 0, 'd');
                        // the text of the load with dT as the destination
                        i64 fo = (1 * 4 + 1) * 40;
                        i64 fz = 0;
                        fixtext[0] = 'l'; fixtext[1] = 'd'; fixtext[2] = 'r'; fixtext[3] = ' '; fixtext[4] = 'd'; fz = 5;
                        if ft >= 10 { fixtext[fz] = '0' + ft / 10; fz += 1; }
                        fixtext[fz] = '0' + ft % 10; fz += 1;
                        fixtext[fz] = ','; fixtext[fz + 1] = ' '; fz += 2;
                        i64 fw = 0;
                        while pt_o[fo + fw] != 0 && fz < 60 { fixtext[fz] = pt_o[fo + fw]; fz += 1; fw += 1; }
                        fixtext[fz] = 0;
                        if pt_regno(1, 0, 'd') < 0 { ffail = true; }
                    } else {
                        ffail = true;
                    }
                }
                bool fknown = pt_mn(1, "ldr") || pt_mn(1, "str") || pt_mn(1, "fadd") || pt_mn(1, "fsub") || pt_mn(1, "fmul") || pt_mn(1, "fdiv") || pt_mn(1, "fsqrt")
                    || pt_mn(1, "fneg") || pt_mn(1, "fabs") || pt_mn(1, "fmov") || pt_mn(1, "fcmp") || pt_mn(1, "fcvtzs") || pt_mn(1, "scvtf")
                    || pt_mn(1, "mov") || pt_mn(1, "add") || pt_mn(1, "sub") || pt_mn(1, "lsl") || pt_mn(1, "lsr") || pt_mn(1, "asr") || pt_mn(1, "cmp")
                    || pt_mn(1, "and") || pt_mn(1, "orr") || pt_mn(1, "eor") || pt_mn(1, "mul");
                if !fknown { ffail = true; }
                if !ffail { fj = pt_next(fj); }
            }
            fsteps += 1;
        }
        if ffound >= 0 {
            if fixl >= 0 { fc = ft; }              // dT holds the addend now
            char fl[48];
            i64 fq = 0;
            fl[0] = 'f'; fq = 1;
            if fkind == 0 { fl[1] = 'm'; fl[2] = 'a'; fl[3] = 'd'; fl[4] = 'd'; fq = 5; }
            else if fkind == 1 { fl[1] = 'm'; fl[2] = 's'; fl[3] = 'u'; fl[4] = 'b'; fq = 5; }
            else { fl[1] = 'n'; fl[2] = 'm'; fl[3] = 's'; fl[4] = 'u'; fl[5] = 'b'; fq = 6; }
            fl[fq] = ' '; fq += 1;
            i64 fparts[4];
            fparts[0] = fd; fparts[1] = fa; fparts[2] = fb; fparts[3] = fc;
            i64 fpi = 0;
            while fpi < 4 {
                fl[fq] = 'd'; fq += 1;
                i64 frv = fparts[fpi];
                if frv >= 10 { fl[fq] = '0' + frv / 10; fq += 1; }
                fl[fq] = '0' + frv % 10; fq += 1;
                if fpi < 3 { fl[fq] = ','; fl[fq + 1] = ' '; fq += 2; }
                fpi += 1;
            }
            fl[fq] = 0;
            pt_set(i, "");
            if fixl >= 0 { pt_set(fixl, @fixtext); }
            pt_set(ffound, @fl);
            return true;
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // lsl|lsr|asr xS, xA, #n / orr|eor|and xD, xP, xQ  (one of P, Q is S)  ->  op xD, xO, xA, lsl|lsr|asr #n
    // (xS is written by the op itself, or nobody reads it afterwards)
    if (pt_mn(0, "lsl") || pt_mn(0, "lsr") || pt_mn(0, "asr")) && pt_no[0] == 3 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isnum(0, 2)
        && (pt_mn(1, "orr") || pt_mn(1, "eor") || pt_mn(1, "and")) && pt_no[1] == 3 && pt_isreg(1, 0) && pt_isreg(1, 1) && pt_isreg(1, 2) {
        i64 ls = pt_regno(0, 0, 'x');
        i64 la = pt_regno(0, 1, 'x');
        i64 ld = pt_regno(1, 0, 'x');
        i64 lp = pt_regno(1, 1, 'x');
        i64 lq = pt_regno(1, 2, 'x');
        i64 lo = 0 - 1;
        if lp == ls && lq != ls { lo = lq; }
        else if lq == ls && lp != ls { lo = lp; }
        i64 ln = 0;
        i64 lso = (0 * 4 + 2) * 40;
        i64 lsi = 0;
        if pt_o[lso] == '#' { lsi = 1; }
        while pt_o[lso + lsi] >= '0' && pt_o[lso + lsi] <= '9' && ln < 100 {
            ln = ln * 10 + (pt_o[lso + lsi] - '0');
            lsi += 1;
        }
        if lo >= 0 && ls >= 0 && la >= 0 && ld >= 0 && ls <= 30 && la <= 30 && ld <= 30 && lo <= 30 && ln >= 1 && ln <= 63 && (ld == ls || pt_dead(pt_next(j), ls, 40)) {
            char ll[56];
            i64 lq2 = 0;
            i64 lc = 0;
            while pt_m[16 + lc] != 0 { ll[lq2] = pt_m[16 + lc]; lq2 += 1; lc += 1; }     // the mnemonic of line 1
            ll[lq2] = ' '; lq2 += 1;
            i64 lparts[3];
            lparts[0] = ld; lparts[1] = lo; lparts[2] = la;
            i64 lpi = 0;
            while lpi < 3 {
                ll[lq2] = 'x'; lq2 += 1;
                i64 lrv = lparts[lpi];
                if lrv >= 10 { ll[lq2] = '0' + lrv / 10; lq2 += 1; }
                ll[lq2] = '0' + lrv % 10; lq2 += 1;
                ll[lq2] = ','; ll[lq2 + 1] = ' '; lq2 += 2;
                lpi += 1;
            }
            ll[lq2] = 'l'; ll[lq2 + 1] = 's';
            if pt_mn(0, "lsl") { ll[lq2 + 2] = 'l'; } else if pt_mn(0, "lsr") { ll[lq2 + 2] = 'r'; } else { ll[lq2] = 'a'; ll[lq2 + 1] = 's'; ll[lq2 + 2] = 'r'; }
            lq2 += 3;
            ll[lq2] = ' '; ll[lq2 + 1] = '#'; lq2 += 2;
            if ln >= 10 { ll[lq2] = '0' + ln / 10; lq2 += 1; }
            ll[lq2] = '0' + ln % 10; lq2 += 1;
            ll[lq2] = 0;
            pt_set(i, "");
            pt_set(j, @ll);
            return true;
        }
    }
    // <op> d0, ... / fmov dK, d0   ->   <op> dK, ...      (d0 is not needed afterwards)
    if pt_mn(1, "fmov") && pt_no[1] == 2 && pt_op(1, 1, "d0") && pt_regno(1, 0, 'd') > 0 && pt_no[0] >= 1 && pt_op(0, 0, "d0") && (pt_mn(0, "fadd") || pt_mn(0, "fsub") || pt_mn(0, "fmul") || pt_mn(0, "fdiv") || pt_mn(0, "fsqrt") || pt_mn(0, "fneg") || pt_mn(0, "fabs") || pt_mn(0, "fmov") || pt_mn(0, "ldr") || pt_mn(0, "scvtf") || pt_mn(0, "frintm") || pt_mn(0, "frintp") || pt_mn(0, "frintz")) {
        i64 kreg = pt_regno(1, 0, 'd');
        if pt_dead(pt_next(j), 32, 40) {
            char nl0[64];
            i64 n0 = 0;
            i64 m0 = 0 * 16;
            i64 c0 = 0;
            while pt_m[m0 + c0] != 0 { nl0[n0] = pt_m[m0 + c0]; n0 += 1; c0 += 1; }
            nl0[n0] = ' '; n0 += 1;
            nl0[n0] = 'd'; n0 += 1;
            i64 kv = kreg;
            if kv >= 10 { nl0[n0] = '0' + kv / 10; n0 += 1; }
            nl0[n0] = '0' + kv % 10; n0 += 1;
            i64 oi = 1;
            while oi < pt_no[0] {
                nl0[n0] = ','; nl0[n0 + 1] = ' '; n0 += 2;
                i64 oo = (0 * 4 + oi) * 40;
                c0 = 0;
                while pt_o[oo + c0] != 0 { nl0[n0] = pt_o[oo + c0]; n0 += 1; c0 += 1; }
                oi += 1;
            }
            nl0[n0] = 0;
            pt_set(i, @nl0);
            pt_set(j, "");
            return true;
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // fmov dA, dB / <up to 4 lines that read dA (and do not write dB)>  ->  the same lines with dB in place of dA, and no fmov
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 && !(pt_regno(0, 0, 'd') >= 8 && pt_regno(0, 0, 'd') <= 15) {
        i64 da = pt_regno(0, 0, 'd');
        i64 db = pt_regno(0, 1, 'd');
        if da != db {
            char sd[40];
            i64 od = (0 * 4 + 1) * 40;
            i64 cd = 0;
            while pt_o[od + cd] != 0 { sd[cd] = pt_o[od + cd]; cd += 1; }
            sd[cd] = 0;
            char pendd[320];
            i64 pend_d[5];
            i64 npd = 0;
            i64 jd = j;
            bool okd = false;
            bool faild = false;
            i64 stepsd = 0;
            while jd >= 0 && stepsd < 5 && !okd && !faild {
                if !pt_parse(1, jd) { faild = true; break; }
                bool mentd = false;
                i64 kd = 0;
                while kd < pt_no[1] {
                    if pt_has_dreg(1, kd, da) { mentd = true; }
                    kd += 1;
                }
                bool wrb = pt_writes_first(1) && pt_no[1] > 0 && pt_has_dreg(1, 0, db);
                if pt_mn(1, "b") || pt_mn(1, "bl") || pt_mn(1, "blr") || pt_mn(1, "ret") || pt_mn(1, "svc") || pt_mn(1, "cbz") || pt_mn(1, "cbnz") || (pt_m[16] == 'b' && pt_m[17] == '.') { faild = true; break; }
                if mentd {
                    bool okm = pt_mn(1, "fadd") || pt_mn(1, "fsub") || pt_mn(1, "fmul") || pt_mn(1, "fdiv") || pt_mn(1, "fsqrt") || pt_mn(1, "fneg") || pt_mn(1, "fabs") || pt_mn(1, "fmov") || pt_mn(1, "fcmp") || pt_mn(1, "str") || pt_mn(1, "fcvtzs") || pt_mn(1, "frintm") || pt_mn(1, "frintp") || pt_mn(1, "frintz");
                    if !okm { faild = true; break; }
                    bool dest_ad = pt_writes_first(1) && pt_regno(1, 0, 'd') == da;
                    pt_sub_prefix = 'd';
                    i64 cntd = pt_subst(1, da, @sd, pt_writes_first(1));
                    if cntd == 0 && !dest_ad { faild = true; break; }
                    i64 qd = 0;
                    while pt_line[qd] != 0 { pendd[npd * 64 + qd] = pt_line[qd]; qd += 1; }
                    pendd[npd * 64 + qd] = 0;
                    pend_d[npd] = jd;
                    npd += 1;
                    if dest_ad { okd = true; }
                    else if pt_dead(pt_next(jd), 32 + da, 40) { okd = true; }
                    else if wrb { faild = true; }
                } else if wrb {
                    faild = true;
                } else if !(pt_writes_first(1) && (pt_isreg(1, 0) || pt_o[(1 * 4) * 40] == 'd')) && !pt_mn(1, "str") && !pt_mn(1, "fcmp") {
                    faild = true;
                }
                if !okd && !faild { jd = pt_next(jd); }
                stepsd += 1;
            }
            if okd && npd >= 1 {
                i64 pid = 0;
                while pid < npd {
                    char nld[64];
                    i64 qd2 = 0;
                    while pendd[pid * 64 + qd2] != 0 { nld[qd2] = pendd[pid * 64 + qd2]; qd2 += 1; }
                    nld[qd2] = 0;
                    pt_set(pend_d[pid], @nld);
                    pid += 1;
                }
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // add xD, xS, #N / ldr or str with the address [xD, #0] (several of them)  ->  the address [xS, #N] in each, and no add
    if pt_mn(0, "add") && pt_no[0] == 3 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isnum(0, 2) && pt_regno(0, 0, 'x') != pt_regno(0, 1, 'x') && (pt_regno(0, 0, 'x') <= 7 || (pt_regno(0, 0, 'x') >= 8 && pt_regno(0, 0, 'x') <= 16)) && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 1, 'x') <= 30 {
        i64 xd = pt_regno(0, 0, 'x');
        i64 xs = pt_regno(0, 1, 'x');
        i64 o2n = (0 * 4 + 2) * 40;
        i64 immn = 0;
        i64 c2n = 0;
        if pt_o[o2n] == '#' { c2n = 1; }
        while pt_o[o2n + c2n] >= '0' && pt_o[o2n + c2n] <= '9' {
            immn = immn * 10 + (pt_o[o2n + c2n] - '0');
            c2n += 1;
        }
        if immn % 8 == 0 && immn <= 32760 {
            char want[24];
            i64 wn = 0;
            want[wn] = '['; wn += 1;
            want[wn] = 'x'; wn += 1;
            if xd >= 10 { want[wn] = '0' + xd / 10; wn += 1; }
            want[wn] = '0' + xd % 10; wn += 1;
            want[wn] = ','; want[wn + 1] = ' '; want[wn + 2] = '#'; want[wn + 3] = '0'; want[wn + 4] = ']'; want[wn + 5] = 0;
            char pendm[640];
            i64 pend_m[10];
            i64 npm = 0;
            i64 jm = j;
            bool okm2 = false;
            bool failm = false;
            i64 stepsm = 0;
            while jm >= 0 && stepsm < 10 && !okm2 && !failm {
                if !pt_parse(1, jm) { failm = true; break; }
                bool mentm = false;
                i64 km = 0;
                while km < pt_no[1] {
                    if pt_has_reg(1, km, xd) { mentm = true; }
                    km += 1;
                }
                if pt_mn(1, "b") || pt_mn(1, "bl") || pt_mn(1, "blr") || pt_mn(1, "ret") || pt_mn(1, "svc") || pt_mn(1, "cbz") || pt_mn(1, "cbnz") || (pt_m[16] == 'b' && pt_m[17] == '.') { failm = true; break; }
                if mentm {
                    // only as the address "[xD, #0]" of a load or store, and not as the register that is loaded or stored
                    if !((pt_mn(1, "ldr") || pt_mn(1, "str")) && pt_no[1] == 2 && pt_op(1, 1, @want) && !pt_has_reg(1, 0, xd) && !(pt_o[(1 * 4 + 0) * 40] == 'q' && immn % 16 != 0)) { 
                        // "ldr xD, [xD, #0]" : the address is read, then xD is written
                        if (pt_mn(1, "ldr") && pt_no[1] == 2 && pt_op(1, 1, @want) && pt_op(1, 0, "x0") == false && pt_regno(1, 0, 'x') == xd) {
                            char nlx[64];
                            i64 nx = 0;
                            nlx[0] = 'l'; nlx[1] = 'd'; nlx[2] = 'r'; nlx[3] = ' '; nx = 4;
                            nlx[nx] = 'x'; nx += 1;
                            if xd >= 10 { nlx[nx] = '0' + xd / 10; nx += 1; }
                            nlx[nx] = '0' + xd % 10; nx += 1;
                            nlx[nx] = ','; nlx[nx + 1] = ' '; nlx[nx + 2] = '['; nlx[nx + 3] = 'x'; nx += 4;
                            if xs >= 10 { nlx[nx] = '0' + xs / 10; nx += 1; }
                            nlx[nx] = '0' + xs % 10; nx += 1;
                            nlx[nx] = ','; nlx[nx + 1] = ' '; nlx[nx + 2] = '#'; nx += 3;
                            char dgx[8];
                            i64 dnx = 0;
                            i64 dvx = immn;
                            if dvx == 0 { dgx[0] = '0'; dnx = 1; }
                            while dvx > 0 { dgx[dnx] = '0' + dvx % 10; dvx = dvx / 10; dnx += 1; }
                            while dnx > 0 { dnx -= 1; nlx[nx] = dgx[dnx]; nx += 1; }
                            nlx[nx] = ']'; nlx[nx + 1] = 0;
                            i64 qx = 0;
                            while nlx[qx] != 0 { pendm[npm * 64 + qx] = nlx[qx]; qx += 1; }
                            pendm[npm * 64 + qx] = 0;
                            pend_m[npm] = jm;
                            npm += 1;
                            okm2 = true;
                        } else {
                            failm = true;
                        }
                    } else {
                        char nlm[64];
                        i64 nm = 0;
                        i64 mm = 1 * 16;
                        i64 cm = 0;
                        while pt_m[mm + cm] != 0 { nlm[nm] = pt_m[mm + cm]; nm += 1; cm += 1; }
                        nlm[nm] = ' '; nm += 1;
                        i64 oo1 = (1 * 4 + 0) * 40;
                        cm = 0;
                        while pt_o[oo1 + cm] != 0 { nlm[nm] = pt_o[oo1 + cm]; nm += 1; cm += 1; }
                        nlm[nm] = ','; nlm[nm + 1] = ' '; nlm[nm + 2] = '['; nlm[nm + 3] = 'x'; nm += 4;
                        if xs >= 10 { nlm[nm] = '0' + xs / 10; nm += 1; }
                        nlm[nm] = '0' + xs % 10; nm += 1;
                        nlm[nm] = ','; nlm[nm + 1] = ' '; nlm[nm + 2] = '#'; nm += 3;
                        char dgm[8];
                        i64 dnm = 0;
                        i64 dvm = immn;
                        if dvm == 0 { dgm[0] = '0'; dnm = 1; }
                        while dvm > 0 { dgm[dnm] = '0' + dvm % 10; dvm = dvm / 10; dnm += 1; }
                        while dnm > 0 { dnm -= 1; nlm[nm] = dgm[dnm]; nm += 1; }
                        nlm[nm] = ']'; nlm[nm + 1] = 0;
                        i64 qm = 0;
                        while nlm[qm] != 0 { pendm[npm * 64 + qm] = nlm[qm]; qm += 1; }
                        pendm[npm * 64 + qm] = 0;
                        pend_m[npm] = jm;
                        npm += 1;
                        if pt_dead(pt_next(jm), xd, 40) { okm2 = true; }
                        else if pt_mn(1, "ldr") && pt_isreg(1, 0) && pt_has_reg(1, 0, xs) { failm = true; }
                    }
                } else {
                    // a line that writes the source of the add ends the search; one that writes xD ends it with success
                    if pt_writes_first(1) && pt_no[1] > 0 && pt_isreg(1, 0) && pt_has_reg(1, 0, xs) { failm = true; }
                    else if pt_writes_first(1) && pt_no[1] > 0 && pt_isreg(1, 0) && pt_has_reg(1, 0, xd) { okm2 = true; }
                    else if pt_mn(1, "str") || pt_mn(1, "ldr") || pt_mn(1, "cmp") || pt_writes_first(1) || pt_mn(1, "fcmp") { }
                    else { failm = true; }
                }
                if !okm2 && !failm { jm = pt_next(jm); }
                stepsm += 1;
            }
            if okm2 && npm >= 1 {
                i64 pim = 0;
                while pim < npm {
                    char nlq[64];
                    i64 qq = 0;
                    while pendm[pim * 64 + qq] != 0 { nlq[qq] = pendm[pim * 64 + qq]; qq += 1; }
                    nlq[qq] = 0;
                    pt_set(pend_m[pim], @nlq);
                    pim += 1;
                }
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // mov x0, S / (a line that does not touch x0 and S) / I  ->  I with S in place of x0   (and the same for x1): when I writes
    // x0 itself, or x0 is not needed afterwards
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) && (pt_regno(0, 0, 'x') <= 7 || (pt_regno(0, 0, 'x') >= 8 && pt_regno(0, 0, 'x') <= 16)) {
        i64 rr = pt_regno(0, 0, 'x');
        i64 sreg = pt_regno(0, 1, 'x');
        if sreg != rr {
            char sx[40];
            i64 o0 = (0 * 4 + 1) * 40;
            i64 c = 0;
            while pt_o[o0 + c] != 0 { sx[c] = pt_o[o0 + c]; c += 1; }
            sx[c] = 0;
            i64 jj = j;
            i64 tries = 0;
            while jj >= 0 && tries < 9 {
                if !pt_parse(1, jj) { break; }
                bool mentions = false;
                i64 kq = 0;
                while kq < pt_no[1] {
                    if pt_has_reg(1, kq, rr) { mentions = true; }
                    kq += 1;
                }
                if mentions {
                    if pt_copy_ok(1) {
                        bool dest_r = pt_writes_first(1) && pt_isreg(1, 0) && pt_has_reg(1, 0, rr);
                        pt_sub_prefix = 'x';
            i64 cnt = pt_subst(1, rr, @sx, pt_writes_first(1));
                        if cnt > 0 && (dest_r || pt_dead(pt_next(jj), rr, 40)) {
                            char nl[64];
                            i64 q = 0;
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
    // mov xA, xB / <up to 9 lines that read xA (and not write xB)>  ->  the same lines with xB in place of xA, and no mov: when xA is
    // written by the last of them or is not needed afterwards
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) && (pt_regno(0, 0, 'x') <= 7 || (pt_regno(0, 0, 'x') >= 8 && pt_regno(0, 0, 'x') <= 16)) && pt_regno(0, 1, 'x') >= 0 {
        i64 ra = pt_regno(0, 0, 'x');
        i64 rb = pt_regno(0, 1, 'x');
        if ra != rb && rb != 31 {
            char sx2[40];
            i64 o0b = (0 * 4 + 1) * 40;
            i64 cb = 0;
            while pt_o[o0b + cb] != 0 { sx2[cb] = pt_o[o0b + cb]; cb += 1; }
            sx2[cb] = 0;
            char pend[640];
            i64 pend_at[10];
            i64 npend = 0;
            i64 jj2 = j;
            bool ok2 = false;
            bool fail2 = false;
            i64 steps2 = 0;
            while jj2 >= 0 && steps2 < 10 && !ok2 && !fail2 {
                if !pt_parse(1, jj2) { fail2 = true; break; }
                bool ment = false;
                i64 kq2 = 0;
                while kq2 < pt_no[1] {
                    if pt_has_reg(1, kq2, ra) { ment = true; }
                    kq2 += 1;
                }
                bool wr_b = pt_writes_first(1) && pt_no[1] > 0 && pt_has_reg(1, 0, rb);
                if pt_mn(1, "b") || pt_mn(1, "bl") || pt_mn(1, "blr") || pt_mn(1, "ret") || pt_mn(1, "svc") || pt_mn(1, "cbz") || pt_mn(1, "cbnz") || (pt_m[16] == 'b' && pt_m[17] == '.') { fail2 = true; break; }
                if ment {
                    if !pt_copy_ok(1) { fail2 = true; break; }
                    bool dest_a = pt_writes_first(1) && pt_isreg(1, 0) && pt_has_reg(1, 0, ra);
                    pt_sub_prefix = 'x';
                    i64 cnt2 = pt_subst(1, ra, @sx2, pt_writes_first(1));
                    if cnt2 == 0 && !dest_a { fail2 = true; break; }
                    i64 q2 = 0;
                    while pt_line[q2] != 0 { pend[npend * 64 + q2] = pt_line[q2]; q2 += 1; }
                    pend[npend * 64 + q2] = 0;
                    pend_at[npend] = jj2;
                    npend += 1;
                    if dest_a { ok2 = true; }
                    else if pt_dead(pt_next(jj2), ra, 40) { ok2 = true; }
                    else if wr_b { fail2 = true; }
                } else if wr_b {
                    fail2 = true;
                } else if !(pt_writes_first(1) && (pt_isreg(1, 0) || pt_o[(1 * 4) * 40] == 'd') && !pt_mn(1, "ldr") && !pt_mn(1, "ldrb")) && !pt_mn(1, "cmp") && !pt_mn(1, "str") {
                    fail2 = true;
                }
                if !ok2 && !fail2 { jj2 = pt_next(jj2); }
                steps2 += 1;
            }
            if ok2 && npend >= 2 {
                i64 pi2 = 0;
                while pi2 < npend {
                    char nl2[64];
                    i64 q3 = 0;
                    while pend[pi2 * 64 + q3] != 0 { nl2[q3] = pend[pi2 * 64 + q3]; q3 += 1; }
                    nl2[q3] = 0;
                    pt_set(pend_at[pi2], @nl2);
                    pi2 += 1;
                }
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // add xA, xA, #N / ldr xR, [xA, #0]  ->  ldr xR, [xA, #N]  (also str, ldrb, strb): the address is not needed afterwards
    if pt_mn(0, "add") && pt_no[0] == 3 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isnum(0, 2) && (pt_mn(1, "ldr") || pt_mn(1, "str") || pt_mn(1, "ldrb") || pt_mn(1, "strb")) && pt_no[1] == 2 {
        i64 o2 = (0 * 4 + 2) * 40;
        i64 off = 0;
        i64 c2 = 0;
        if pt_o[o2] == '#' { c2 = 1; }
        while pt_o[o2 + c2] >= '0' && pt_o[o2 + c2] <= '9' {
            off = off * 10 + (pt_o[o2 + c2] - '0');
            c2 += 1;
        }
        bool wide = pt_mn(1, "ldr") || pt_mn(1, "str");
        bool range_ok = (wide && off % 8 == 0 && off <= 32760) || (!wide && off <= 4095);
        if pt_o[(1 * 4 + 0) * 40] == 'q' { range_ok = off % 16 == 0 && off <= 65520; }     // a 128-bit vector: the offset is a multiple of 16
        // the address operand of the load: "[xD, #0]"
        i64 om = (1 * 4 + 1) * 40;
        i64 dreg = 0;
        i64 dd = 0;
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
                i64 n = 0;
                i64 m1 = 1 * 16;
                i64 c = 0;
                while pt_m[m1 + c] != 0 { nl[n] = pt_m[m1 + c]; n += 1; c += 1; }
                nl[n] = ' '; n += 1;
                i64 o10 = (1 * 4 + 0) * 40;
                c = 0;
                while pt_o[o10 + c] != 0 { nl[n] = pt_o[o10 + c]; n += 1; c += 1; }
                nl[n] = ','; nl[n + 1] = ' '; nl[n + 2] = '['; n += 3;
                i64 o01 = (0 * 4 + 1) * 40;
                c = 0;
                while pt_o[o01 + c] != 0 { nl[n] = pt_o[o01 + c]; n += 1; c += 1; }
                nl[n] = ','; nl[n + 1] = ' '; nl[n + 2] = '#'; n += 3;
                i64 dv = off;
                char dg[12];
                i64 dn = 0;
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
    i64 k3 = pt_next(j);
    i64 k4 = 0 - 1;
    if k3 >= 0 { k4 = pt_next(k3); }
    if k4 >= 0 && pt_mn(0, "mov") && pt_op(0, 0, "x1") && pt_op(0, 1, "x0") && pt_mn(1, "mov") && pt_op(1, 0, "x0") && pt_isreg(1, 1) && !pt_op(1, 1, "x1") && pt_parse(2, k3) {
        if pt_mn(2, "fmov") && pt_op(2, 0, "d0") && pt_op(2, 1, "x0") && pt_parse(3, k4) && pt_mn(3, "fmov") && pt_op(3, 0, "d1") && pt_op(3, 1, "x1") && pt_dead(pt_next(k4), 0, 40) && pt_dead(pt_next(k4), 1, 40) {
            char na[64];
            char nb[64];
            i64 o1 = (1 * 4 + 1) * 40;
            nb[0] = 'f'; nb[1] = 'm'; nb[2] = 'o'; nb[3] = 'v'; nb[4] = ' '; nb[5] = 'd'; nb[6] = '1'; nb[7] = ','; nb[8] = ' '; nb[9] = 'x'; nb[10] = '0'; nb[11] = 0;
            na[0] = 'f'; na[1] = 'm'; na[2] = 'o'; na[3] = 'v'; na[4] = ' '; na[5] = 'd'; na[6] = '0'; na[7] = ','; na[8] = ' ';
            i64 n = 9;
            i64 c = 0;
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
        i64 o1 = (1 * 4 + 0) * 40;
        i64 o0 = (0 * 4 + 1) * 40;
        i64 c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        char nl[64];
        nl[0] = 'm'; nl[1] = 'o'; nl[2] = 'v'; nl[3] = ' ';
        i64 n = 4;
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
    if pt_writes_first(0) && !pt_mn(0, "mov") && !pt_mn(0, "adr") && pt_no[0] >= 2 && pt_regno(0, 0, 'x') >= 0 && (pt_regno(0, 0, 'x') == 0 || pt_regno(0, 0, 'x') == 15 || pt_regno(0, 0, 'x') == 16) && pt_mn(1, "mov") && pt_isreg(1, 0) && pt_regno(1, 1, 'x') == pt_regno(0, 0, 'x') && pt_regno(1, 0, 'x') != pt_regno(0, 0, 'x') && pt_dead(pt_next(j), pt_regno(0, 0, 'x'), 40) {
        i64 o1 = (1 * 4 + 0) * 40;
        char dd[40];
        i64 c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(0, 0, @dd);
        pt_set(i, @pt_line);
        pt_set(j, "");
        return true;
    }
    // ldr xN, [..] / fmov dK, xN  ->  ldr dK, [..]      fmov xN, dM / str xN, [..]  ->  str dM, [..]   (xN not needed afterwards)
    if pt_mn(0, "ldr") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_mn(1, "fmov") && pt_no[1] == 2 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'x') == pt_regno(0, 0, 'x') && pt_dead(pt_next(j), pt_regno(0, 0, 'x'), 40) {
        i64 o1 = (1 * 4 + 0) * 40;
        char dd[40];
        i64 c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(0, 0, @dd);
        pt_set(i, @pt_line);
        pt_set(j, "");
        return true;
    }
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_mn(1, "str") && pt_no[1] == 2 && pt_regno(1, 0, 'x') == pt_regno(0, 0, 'x') && !pt_has_reg(1, 1, pt_regno(0, 0, 'x')) && pt_dead(pt_next(j), pt_regno(0, 0, 'x'), 40) {
        i64 o1 = (0 * 4 + 1) * 40;
        char dd[40];
        i64 c = 0;
        while pt_o[o1 + c] != 0 { dd[c] = pt_o[o1 + c]; c += 1; }
        dd[c] = 0;
        pt_build(1, 0, @dd);
        pt_set(j, @pt_line);
        pt_set(i, "");
        return true;
    }
    // ldrsw xN, [..] / fmov sK, wN  ->  ldr sK, [..]      fmov wN, sK / strw xN, [..]  ->  str sK, [..]   (xN not needed afterwards)
    if pt_no[0] == 2 && pt_no[1] == 2 {
        i64 lsk = 0 - 1;
        i64 lsn = 0 - 1;
        i64 lsm = 0;               // 0: the load is line 0 and the memory operand is operand 1 of line 0; 1: the store
        if pt_mn(0, "ldrsw") && pt_regno(0, 0, 'x') >= 0 && pt_mn(1, "fmov") && pt_regno(1, 0, 's') >= 0 && pt_regno(1, 1, 'w') == pt_regno(0, 0, 'x') {
            lsk = pt_regno(1, 0, 's'); lsn = pt_regno(0, 0, 'x'); lsm = 0;
        } else if pt_mn(0, "fmov") && pt_regno(0, 0, 'w') >= 0 && pt_regno(0, 1, 's') >= 0 && pt_mn(1, "strw") && pt_regno(1, 0, 'x') == pt_regno(0, 0, 'w') && !pt_has_reg(1, 1, pt_regno(0, 0, 'w')) {
            lsk = pt_regno(0, 1, 's'); lsn = pt_regno(0, 0, 'w'); lsm = 1;
        }
        if lsk >= 0 && pt_dead(pt_next(j), lsn, 40) {
            char lb[64];
            i64 ln = 0;
            if lsm == 0 { lb[0] = 'l'; lb[1] = 'd'; lb[2] = 'r'; ln = 3; } else { lb[0] = 's'; lb[1] = 't'; lb[2] = 'r'; ln = 3; }
            lb[ln] = ' '; lb[ln + 1] = 's'; ln += 2;
            char lg[8];
            i64 lk = 0;
            i64 lv = lsk;
            if lv == 0 { lg[0] = '0'; lk = 1; }
            while lv > 0 { lg[lk] = '0' + lv % 10; lk += 1; lv = lv / 10; }
            while lk > 0 { lk -= 1; lb[ln] = lg[lk]; ln += 1; }
            lb[ln] = ','; lb[ln + 1] = ' '; ln += 2;
            i64 mo = (lsm * 4 + 1) * 40;
            if lsm == 1 { mo = (1 * 4 + 1) * 40; }
            i64 mc = 0;
            while pt_o[mo + mc] != 0 && ln < 62 { lb[ln] = pt_o[mo + mc]; ln += 1; mc += 1; }
            lb[ln] = 0;
            if lsm == 0 { pt_set(j, @lb); pt_set(i, ""); } else { pt_set(j, @lb); pt_set(i, ""); }
            return true;
        }
    }
    // ldr xN, [xB, #k] / (up to six lines that change neither xN nor xB nor memory) / the same ldr   ->   the second one is not written
    if pt_mn(0, "ldr") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_o[(0 * 4 + 1) * 40] == '[' && pt_o[(0 * 4 + 1) * 40 + 1] == 'x' {
        i64 dn = pt_regno(0, 0, 'x');
        i64 ob4 = (0 * 4 + 1) * 40;
        i64 bn4 = 0;
        i64 q4 = ob4 + 2;
        while pt_o[q4] >= '0' && pt_o[q4] <= '9' { bn4 = bn4 * 10 + (pt_o[q4] - '0'); q4 += 1; }
        if dn != bn4 && pt_o[q4] == ',' {
            i64 cur = j;
            i64 steps = 0;
            while cur >= 0 && steps < 7 {
                if !pt_parse(2, cur) { break; }
                bool same = pt_mn(2, "ldr") && pt_no[2] == 2 && pt_regno(2, 0, 'x') == dn;
                if same {
                    i64 ob5 = (2 * 4 + 1) * 40;
                    i64 c5 = 0;
                    while pt_o[ob5 + c5] != 0 && pt_o[ob5 + c5] == pt_o[ob4 + c5] { c5 += 1; }
                    if pt_o[ob5 + c5] == 0 && pt_o[ob4 + c5] == 0 {
                        pt_set(cur, "");
                        return true;
                    }
                }
                // anything that could change xN, xB or memory ends the search
                bool pass = pt_writes_first(2) && !pt_mn(2, "str") && !pt_mn(2, "strw") && !pt_mn(2, "strb") && pt_regno(2, 0, 'x') != dn && pt_regno(2, 0, 'x') != bn4 && pt_no[2] >= 1;
                if !pass && (pt_mn(2, "cmp") || pt_mn(2, "tst") || pt_mn(2, "fcmp")) { pass = true; }
                if !pass { break; }
                if pt_mn(2, "bl") || pt_mn(2, "blr") || pt_mn(2, "svc") { break; }
                cur = pt_next(cur);
                steps += 1;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // str xA|dA, [x29, #N] / (up to 8 lines: no label, no branch, no call; no store that may touch the cell; nothing that writes the register)
    // / ldr xB|dB, [x29, #N]   ->   the load becomes a register move (mov / fmov), or goes when it is the same register: a number kept in a
    // stack cell by the front end (a vec3 temporary) is read again from the register that wrote it
    if pt_mn(0, "str") && pt_no[0] == 2 && opt_icopy == 1 && (pt_regno(0, 0, 'x') >= 0 || pt_regno(0, 0, 'd') >= 0) {
        i64 fcell = pt_frame_off(0);
        i64 fsrc_x = pt_regno(0, 0, 'x');
        i64 fsrc_d = pt_regno(0, 0, 'd');
        if fcell >= 0 && fsrc_x < 29 {
            i64 fat = j;
            i64 fsteps = 0;
            i64 ffound = 0 - 1;
            while fat >= 0 && fsteps < 8 && ffound < 0 {
                if !pt_parse(2, fat) { break; }
                bool fbad = false;
                if pt_mn(2, "ldr") && pt_no[2] == 2 && pt_frame_off(2) == fcell && (pt_regno(2, 0, 'x') >= 0 || pt_regno(2, 0, 'd') >= 0) {
                    ffound = fat;
                    break;
                }
                if pt_mn(2, "str") || pt_mn(2, "strw") || pt_mn(2, "strb") || pt_mn(2, "strh") {
                    // a store: only to another place of the frame
                    i64 so = pt_frame_off(2);
                    if so < 0 || (so < fcell + 8 && so + 8 > fcell) { fbad = true; }
                } else if pt_mn(2, "ldr") || pt_mn(2, "ldrb") || pt_mn(2, "ldrh") || pt_mn(2, "ldrsw") || pt_mn(2, "cmp") || pt_mn(2, "fcmp") {
                    // reads (a plain write of the first operand is checked below)
                } else if !pt_writes_first(2) || pt_mn(2, "adr") {
                    fbad = true;
                }
                if !fbad && pt_writes_first(2) && pt_no[2] >= 1 {
                    if fsrc_x >= 0 && pt_regno(2, 0, 'x') == fsrc_x { fbad = true; }
                    if fsrc_x >= 0 && pt_regno(2, 0, 'w') == fsrc_x { fbad = true; }
                    if fsrc_d >= 0 && pt_regno(2, 0, 'd') == fsrc_d { fbad = true; }
                    if fsrc_d >= 0 && pt_regno(2, 0, 's') == fsrc_d { fbad = true; }
                }
                if fbad { break; }
                fat = pt_next(fat);
                fsteps += 1;
            }
            if ffound >= 0 {
                i64 ld_x = pt_regno(2, 0, 'x');
                i64 ld_d = pt_regno(2, 0, 'd');
                if ld_x < 29 {
                    char fm[32];
                    i64 fq = 0;
                    bool same = (fsrc_x >= 0 && ld_x == fsrc_x) || (fsrc_d >= 0 && ld_d == fsrc_d);
                    if same {
                        pt_set(ffound, "");
                        return true;
                    }
                    if fsrc_x >= 0 && ld_x >= 0 { fm[0] = 'm'; fm[1] = 'o'; fm[2] = 'v'; fq = 3; }
                    else { fm[0] = 'f'; fm[1] = 'm'; fm[2] = 'o'; fm[3] = 'v'; fq = 4; }
                    fm[fq] = ' '; fq += 1;
                    i64 fparts[2];
                    char fcls[2];
                    if ld_x >= 0 { fparts[0] = ld_x; fcls[0] = 'x'; } else { fparts[0] = ld_d; fcls[0] = 'd'; }
                    if fsrc_x >= 0 { fparts[1] = fsrc_x; fcls[1] = 'x'; } else { fparts[1] = fsrc_d; fcls[1] = 'd'; }
                    i64 fp = 0;
                    while fp < 2 {
                        fm[fq] = fcls[fp]; fq += 1;
                        if fparts[fp] >= 10 { fm[fq] = '0' + fparts[fp] / 10; fq += 1; }
                        fm[fq] = '0' + fparts[fp] % 10; fq += 1;
                        if fp == 0 { fm[fq] = ','; fm[fq + 1] = ' '; fq += 2; }
                        fp += 1;
                    }
                    fm[fq] = 0;
                    pt_set(ffound, @fm);
                    return true;
                }
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // add xD, x29, #N (the address of a cell) that nobody reads before xD is written again: gone (the front end makes it for a copy that
    // the later passes took out)
    if pt_mn(0, "add") && pt_no[0] == 3 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 0, 'x') < 29 && opt_icopy == 1 {
        i64 ao1 = (0 * 4 + 1) * 40;
        if pt_o[ao1] == 'x' && pt_o[ao1 + 1] == '2' && pt_o[ao1 + 2] == '9' && pt_o[ao1 + 3] == 0 && pt_o[(0 * 4 + 2) * 40] == '#' {
            if pt_dead(j, pt_regno(0, 0, 'x'), 40) {
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // str xA, [x29, #N] / ldr xB, [x29, #N]   ->   str xA, [x29, #N] / mov xB, xA      (the value just stored is in the register; the store stays)
    if pt_mn(0, "str") && pt_mn(1, "ldr") && pt_no[0] == 2 && pt_no[1] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(1, 0, 'x') >= 0 && opt_icopy == 1 {
        i64 sa = pt_regno(0, 0, 'x');
        i64 sb = pt_regno(1, 0, 'x');
        i64 om0 = (0 * 4 + 1) * 40;
        i64 om1 = (1 * 4 + 1) * 40;
        bool same = pt_o[om0] == '[' && pt_o[om0 + 1] == 'x' && pt_o[om0 + 2] == '2' && pt_o[om0 + 3] == '9';
        i64 sc = 0;
        while same && (pt_o[om0 + sc] != 0 || pt_o[om1 + sc] != 0) {
            if pt_o[om0 + sc] != pt_o[om1 + sc] { same = false; }
            sc += 1;
        }
        if same && sa < 29 && sb < 29 {
            if sa == sb { pt_set(j, ""); return true; }
            char mv[24];
            i64 mq = 0;
            mv[mq] = 'm'; mq += 1; mv[mq] = 'o'; mq += 1; mv[mq] = 'v'; mq += 1; mv[mq] = ' '; mq += 1; mv[mq] = 'x'; mq += 1;
            if sb >= 10 { mv[mq] = '0' + sb / 10; mq += 1; }
            mv[mq] = '0' + sb % 10; mq += 1;
            mv[mq] = ','; mq += 1; mv[mq] = ' '; mq += 1; mv[mq] = 'x'; mq += 1;
            if sa >= 10 { mv[mq] = '0' + sa / 10; mq += 1; }
            mv[mq] = '0' + sa % 10; mq += 1;
            mv[mq] = 0;
            pt_set(j, @mv);
            return true;
        }
    }
    // mov xA, BITS / (up to 3 lines that do not touch xA or sK) / fmov sK, wA   ->   (the lines) / fmovsi sK, imm8      when BITS is a float that fmov can write directly (0.5, 1.5, 2.0 ...)
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_isnum(0, 1) && opt_icopy == 1 {
        i64 ca = pt_regno(0, 0, 'x');
        i64 ov = (0 * 4 + 1) * 40;
        i64 oc = 0;
        if pt_o[ov] == '#' { oc = 1; }
        i64 bits = 0;
        i64 dg = 0;
        while pt_o[ov + oc] >= '0' && pt_o[ov + oc] <= '9' && dg < 11 { bits = bits * 10 + (pt_o[ov + oc] - '0'); oc += 1; dg += 1; }
        // the ARM immediate of a single: a : NOT(b) : b b b b b : c d e f g h : 19 zeros
        i64 imm8 = 0 - 1;
        if bits > 0 && bits < 4294967296 && (bits & 524287) == 0 {
            i64 sg = (bits >> 31) & 1;
            i64 b30 = (bits >> 30) & 1;
            i64 b29 = (bits >> 25) & 31;
            i64 nb = 1 - b30;
            bool rep = (nb == 1 && b29 == 31) || (nb == 0 && b29 == 0);
            if rep { imm8 = (sg << 7) | (nb << 6) | ((bits >> 19) & 63); }
        }
        if imm8 >= 0 && ca < 29 {
            i64 at = pt_next(i);
            i64 steps = 0;
            i64 found = 0 - 1;
            i64 fk = 0 - 1;
            while at >= 0 && steps < 4 && found < 0 {
                steps += 1;
                if !pt_parse(2, at) { break; }
                if pt_m[32] == 'b' || pt_mn(2, "cbz") || pt_mn(2, "cbnz") || pt_mn(2, "tbz") || pt_mn(2, "tbnz") || pt_mn(2, "ret") || pt_mn(2, "svc") { break; }
                if pt_mn(2, "fmov") && pt_no[2] == 2 && pt_regno(2, 1, 'w') == ca && pt_regno(2, 0, 's') >= 0 {
                    found = at;
                    fk = pt_regno(2, 0, 's');
                    break;
                }
                bool touch = false;
                i64 q = 0;
                while q < pt_no[2] { if pt_rd(2, q, ca) { touch = true; } q += 1; }
                if touch { break; }
                at = pt_next(at);
            }
            // the lines in between must not use sK either (the constant lands there later than it was made, but nothing may read or write it in between)
            bool clean = found >= 0;
            if clean {
                i64 at2 = pt_next(i);
                while at2 >= 0 && at2 != found {
                    if pt_parse(2, at2) {
                        i64 q2 = 0;
                        while q2 < pt_no[2] { if pt_rd(2, q2, 32 + fk) { clean = false; } q2 += 1; }
                    }
                    at2 = pt_next(at2);
                }
            }
            if clean && pt_dead(pt_next(found), ca, 40) {
                char fl3[40];
                i64 fq3 = 0;
                char hd[10];
                hd[0] = 'f'; hd[1] = 'm'; hd[2] = 'o'; hd[3] = 'v'; hd[4] = 's'; hd[5] = 'i'; hd[6] = ' '; hd[7] = 's'; hd[8] = 0;
                i64 hq = 0;
                while hd[hq] != 0 { fl3[fq3] = hd[hq]; fq3 += 1; hq += 1; }
                if fk >= 10 { fl3[fq3] = '0' + fk / 10; fq3 += 1; }
                fl3[fq3] = '0' + fk % 10; fq3 += 1;
                fl3[fq3] = ','; fq3 += 1; fl3[fq3] = ' '; fq3 += 1;
                if imm8 >= 100 { fl3[fq3] = '0' + imm8 / 100; fq3 += 1; }
                if imm8 >= 10 { fl3[fq3] = '0' + (imm8 / 10) % 10; fq3 += 1; }
                fl3[fq3] = '0' + imm8 % 10; fq3 += 1;
                fl3[fq3] = 0;
                pt_set(found, @fl3);
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // fmov wA, sK / mov xC, xA / (lines that do not write sK or xC) / mov xB, xC / fmov sK, wB   ->   the same without the last fmov (sK still holds the value;
    // the float went into an integer register and came back for nothing)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'w') >= 0 && pt_regno(0, 1, 's') >= 0 && pt_mn(1, "mov") && pt_no[1] == 2 && pt_regno(1, 1, 'x') == pt_regno(0, 0, 'w') && pt_regno(1, 0, 'x') >= 19 && pt_regno(1, 0, 'x') <= 28 && opt_icopy == 1 {
        i64 fk2 = pt_regno(0, 1, 's');
        i64 cc = pt_regno(1, 0, 'x');
        i64 at3 = pt_next(j);
        i64 st3 = 0;
        i64 pm = 0 - 1;
        bool ok3 = true;
        while at3 >= 0 && st3 < 10 && ok3 && pm < 0 {
            st3 += 1;
            if !pt_parse(2, at3) { ok3 = false; break; }
            if pt_m[32] == 'b' || pt_mn(2, "cbz") || pt_mn(2, "cbnz") || pt_mn(2, "tbz") || pt_mn(2, "tbnz") || pt_mn(2, "ret") || pt_mn(2, "svc") { ok3 = false; break; }
            // the pair that brings it back
            if pt_mn(2, "mov") && pt_no[2] == 2 && pt_regno(2, 0, 'x') >= 0 && pt_regno(2, 1, 'x') == cc {
                i64 nx = pt_next(at3);
                if nx >= 0 && pt_parse(3, nx) && pt_mn(3, "fmov") && pt_no[3] == 2 && pt_regno(3, 0, 's') == fk2 && pt_regno(3, 1, 'w') == pt_regno(2, 0, 'x') {
                    pm = nx;
                    break;
                }
            }
            // a line that mentions sK at all, or writes xC, ends the search
            i64 q3 = 0;
            while q3 < pt_no[2] {
                if pt_rd(2, q3, 32 + fk2) { ok3 = false; }
                if q3 == 0 && pt_rd(2, 0, cc) && pt_writes_first(2) { ok3 = false; }
                q3 += 1;
            }
            at3 = pt_next(at3);
        }
        if ok3 && pm >= 0 {
            pt_set(pm, "");
            return true;
        }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // a register that is written and not read again, by an instruction that does nothing else (mov, fmov to a w or x register, add sub and or eor shifts without flags): the line goes
    if opt_icopy == 1 && pt_no[0] >= 2 && (pt_mn(0, "mov") || pt_mn(0, "fmov") || pt_mn(0, "add") || pt_mn(0, "sub") || pt_mn(0, "lsl") || pt_mn(0, "lsr") || pt_mn(0, "asr") || pt_mn(0, "and") || pt_mn(0, "orr") || pt_mn(0, "eor")) {
        i64 dw = pt_regno(0, 0, 'x');
        if dw < 0 { dw = pt_regno(0, 0, 'w'); }
        if dw >= 0 && dw <= 25 && dw != 18 && !(pt_mn(0, "fmov") && pt_regno(0, 0, 'x') < 0 && pt_regno(0, 0, 'w') < 0) {
            bool plain = true;
            i64 qd = 1;
            while qd < pt_no[0] { if pt_rd(0, qd, 28) || pt_rd(0, qd, 29) || pt_rd(0, qd, 31) { plain = false; } qd += 1; }
            if plain && pt_dead(pt_next(i), dw, 41) {
                pt_set(i, "");
                return true;
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // mov xT, xV / cmp xV, ...   ->   mov xT, xV / cmp xT, ...      (the same value; xV may then be written by the line before in place: add xT, ... )
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 0, 'x') != pt_regno(0, 1, 'x') && (pt_mn(1, "cmp") || pt_mn(1, "cmn") || pt_mn(1, "tst")) && pt_no[1] == 2 && opt_icopy == 1 {
        i64 mt = pt_regno(0, 0, 'x');
        i64 mv = pt_regno(0, 1, 'x');
        if mt < 29 && mv < 29 && pt_regno(1, 0, 'x') == mv && pt_regno(1, 1, 'x') != mv {
            pt_build_subst(1, mv, mt);
            pt_set(j, @pt_line);
            return true;
        }
    }
    // mov xN, 0 / str|strb|strh|strw xN, [...]  (xN is not needed afterwards, not part of the address)  ->  str.. xzr, [...]
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 0, 'x') < 29 && pt_isnum(0, 1) && opt_icopy == 1
        && (pt_mn(1, "str") || pt_mn(1, "strb") || pt_mn(1, "strh") || pt_mn(1, "strw")) && pt_no[1] == 2 && pt_regno(1, 0, 'x') == pt_regno(0, 0, 'x') {
        i64 zr = pt_regno(0, 0, 'x');
        i64 zo = (0 * 4 + 1) * 40;
        i64 zc = 0;
        if pt_o[zo] == '#' { zc = 1; }
        if pt_o[zo + zc] == '0' && pt_o[zo + zc + 1] == 0 && !pt_rd(1, 1, zr) && pt_dead(pt_next(j), zr, 40) {
            // the text of the store with xzr instead of xN
            char zl[64];
            i64 zb = j * 64;
            i64 zq = 0;
            while pt_txt[zb + zq] != ' ' && pt_txt[zb + zq] != 0 && zq < 20 { zl[zq] = pt_txt[zb + zq]; zq += 1; }
            if pt_txt[zb + zq] == ' ' {
                zl[zq] = ' '; zl[zq + 1] = 'x'; zl[zq + 2] = 'z'; zl[zq + 3] = 'r';
                i64 zp = zq + 1;
                i64 zk = zb + zq + 1;
                zk += 1;                                              // the 'x'
                while pt_txt[zk] >= '0' && pt_txt[zk] <= '9' { zk += 1; }
                i64 zw = zq + 4;
                while pt_txt[zk] != 0 && zw < 62 { zl[zw] = pt_txt[zk]; zw += 1; zk += 1; }
                zl[zw] = 0;
                pt_set(i, "");
                pt_set(j, @zl);
                return true;
            }
        }
    }
    // lsl xA, xI, #k / (one independent line) / OP rt, [xA, xB]   ->   (the line) / OP rt, [xB, xI, lsl #k]      (the element address after the load of the data pointer)
    if pt_mn(0, "lsl") && pt_no[0] == 3 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'x') >= 0 && pt_isnum(0, 2) && pt_no[1] >= 2 && opt_icopy == 1 {
        i64 la = pt_regno(0, 0, 'x');
        i64 li = pt_regno(0, 1, 'x');
        i64 o2 = (0 * 4 + 2) * 40;
        i64 lk = 0 - 1;
        if pt_o[o2] == '#' && pt_o[o2 + 1] >= '0' && pt_o[o2 + 1] <= '3' && pt_o[o2 + 2] == 0 { lk = pt_o[o2 + 1] - '0'; }
        bool mid = pt_mn(1, "ldr") || pt_mn(1, "ldrsw") || pt_mn(1, "ldrb") || pt_mn(1, "ldrh") || pt_mn(1, "add") || pt_mn(1, "sub") || pt_mn(1, "mov") || pt_mn(1, "lsl") || pt_mn(1, "lsr");
        i64 n2 = pt_next(j);
        if lk >= 0 && la != li && mid && n2 >= 0 && pt_writes_first(1) {
            bool mid_ok = !pt_rd(1, 0, la) && pt_regno(1, 0, 'x') != li && pt_regno(1, 0, 'x') != la;
            i64 q = 1;
            while q < pt_no[1] { if pt_rd(1, q, la) { mid_ok = false; } q += 1; }
            if mid_ok && pt_parse(2, n2) && pt_no[2] == 2 {
                i64 sz2 = 0 - 1;
                bool st2 = pt_mn(2, "str") || pt_mn(2, "strw") || pt_mn(2, "strb") || pt_mn(2, "strh");
                if pt_mn(2, "ldr") || pt_mn(2, "str") {
                    if pt_regno(2, 0, 'x') >= 0 || pt_regno(2, 0, 'd') >= 0 { sz2 = 3; }
                    else if pt_regno(2, 0, 's') >= 0 { sz2 = 2; }
                } else if pt_mn(2, "ldrsw") || pt_mn(2, "strw") { sz2 = 2; }
                else if pt_mn(2, "ldrh") || pt_mn(2, "strh") { sz2 = 1; }
                else if pt_mn(2, "ldrb") || pt_mn(2, "strb") { sz2 = 0; }
                // the operand must be exactly "[xA, xB]" with xB another register that is not xA
                i64 ob = (2 * 4 + 1) * 40;
                i64 xb = 0 - 1;
                if pt_o[ob] == '[' && pt_o[ob + 1] == 'x' {
                    i64 a1 = ob + 2;
                    i64 v1 = 0;
                    while pt_o[a1] >= '0' && pt_o[a1] <= '9' { v1 = v1 * 10 + (pt_o[a1] - '0'); a1 += 1; }
                    if v1 == la && pt_o[a1] == ',' && pt_o[a1 + 1] == ' ' && pt_o[a1 + 2] == 'x' {
                        i64 a2 = a1 + 3;
                        i64 v2 = 0;
                        while pt_o[a2] >= '0' && pt_o[a2] <= '9' { v2 = v2 * 10 + (pt_o[a2] - '0'); a2 += 1; }
                        if pt_o[a2] == ']' && pt_o[a2 + 1] == 0 && v2 != la { xb = v2; }
                    }
                }
                bool first_is_a2 = pt_regno(2, 0, 'x') == la;
                if sz2 >= 0 && xb >= 0 && (lk == 0 || lk == sz2) && !(st2 && first_is_a2) && (first_is_a2 || pt_dead(pt_next(n2), la, 40)) {
                    char fl2[64];
                    i64 fq = 0;
                    i64 mq2 = 0;
                    while pt_m[2 * 16 + mq2] != 0 { fl2[fq] = pt_m[2 * 16 + mq2]; fq += 1; mq2 += 1; }
                    fl2[fq] = ' '; fq += 1;
                    i64 o0b = (2 * 4 + 0) * 40;
                    i64 oq2 = 0;
                    while pt_o[o0b + oq2] != 0 { fl2[fq] = pt_o[o0b + oq2]; fq += 1; oq2 += 1; }
                    fl2[fq] = ','; fq += 1; fl2[fq] = ' '; fq += 1; fl2[fq] = '['; fq += 1; fl2[fq] = 'x'; fq += 1;
                    if xb >= 10 { fl2[fq] = '0' + xb / 10; fq += 1; }
                    fl2[fq] = '0' + xb % 10; fq += 1;
                    fl2[fq] = ','; fq += 1; fl2[fq] = ' '; fq += 1; fl2[fq] = 'x'; fq += 1;
                    if li >= 10 { fl2[fq] = '0' + li / 10; fq += 1; }
                    fl2[fq] = '0' + li % 10; fq += 1;
                    if lk > 0 {
                        fl2[fq] = ','; fq += 1; fl2[fq] = ' '; fq += 1; fl2[fq] = 'l'; fq += 1; fl2[fq] = 's'; fq += 1; fl2[fq] = 'l'; fq += 1; fl2[fq] = ' '; fq += 1; fl2[fq] = '#'; fq += 1;
                        fl2[fq] = '0' + lk; fq += 1;
                    }
                    fl2[fq] = ']'; fq += 1;
                    fl2[fq] = 0;
                    pt_set(n2, @fl2);
                    pt_set(i, "");
                    return true;
                }
            }
            pt_parse(0, i);
            pt_parse(1, j);
        }
    }
    // add xA, xB, xC [, lsl #k] / OP rt, [xA, #0]   ->   OP rt, [xB, xC [, lsl #k]]      (a register offset: k is 0 or the log2 of the size; xA written by OP or not needed afterwards)
    if pt_mn(0, "add") && (pt_no[0] == 3 || pt_no[0] == 4) && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 2, 'x') >= 0 && pt_no[1] == 2 {
        i64 ra = pt_regno(0, 0, 'x');
        i64 rb = pt_regno(0, 1, 'x');
        i64 rc = pt_regno(0, 2, 'x');
        i64 sk = 0;
        bool shift_ok = true;
        if pt_no[0] == 4 {
            i64 o3 = (0 * 4 + 3) * 40;
            if pt_o[o3] == 'l' && pt_o[o3 + 1] == 's' && pt_o[o3 + 2] == 'l' && pt_o[o3 + 3] == ' ' && pt_o[o3 + 4] == '#' && pt_o[o3 + 5] >= '0' && pt_o[o3 + 5] <= '9' && pt_o[o3 + 6] == 0 { sk = pt_o[o3 + 5] - '0'; }
            else { shift_ok = false; }
        }
        // the log2 of the size of the access, or -1 when the line is not a plain load or store
        i64 sz = 0 - 1;
        bool is_store = pt_mn(1, "str") || pt_mn(1, "strw") || pt_mn(1, "strb") || pt_mn(1, "strh");
        if pt_mn(1, "ldr") || pt_mn(1, "str") {
            if pt_regno(1, 0, 'x') >= 0 || pt_regno(1, 0, 'd') >= 0 { sz = 3; }
            else if pt_regno(1, 0, 's') >= 0 { sz = 2; }
        } else if pt_mn(1, "ldrsw") || pt_mn(1, "strw") || pt_mn(1, "ldrw") { sz = 2; }
        else if pt_mn(1, "ldrh") || pt_mn(1, "strh") || pt_mn(1, "ldrsh") { sz = 1; }
        else if pt_mn(1, "ldrb") || pt_mn(1, "strb") || pt_mn(1, "ldrsb") { sz = 0; }
        if shift_ok && sz >= 0 && (sk == 0 || sk == sz) {
            // the second operand is exactly "[xA, #0]"
            char want[16];
            i64 wq = 0;
            want[wq] = '['; wq += 1;
            want[wq] = 'x'; wq += 1;
            if ra >= 10 { want[wq] = '0' + ra / 10; wq += 1; }
            want[wq] = '0' + ra % 10; wq += 1;
            want[wq] = ','; wq += 1; want[wq] = ' '; wq += 1; want[wq] = '#'; wq += 1; want[wq] = '0'; wq += 1; want[wq] = ']'; wq += 1; want[wq] = 0;
            bool first_is_a = pt_regno(1, 0, 'x') == ra;
            if pt_op(1, 1, @want) && !(is_store && first_is_a) && (first_is_a || pt_dead(pt_next(j), ra, 40)) {
                char fl[64];
                i64 fn2 = 0;
                i64 mq = 0;
                i64 mbase = 1 * 16;
                while pt_m[mbase + mq] != 0 { fl[fn2] = pt_m[mbase + mq]; fn2 += 1; mq += 1; }
                fl[fn2] = ' '; fn2 += 1;
                i64 o0 = (1 * 4 + 0) * 40;
                i64 oq = 0;
                while pt_o[o0 + oq] != 0 { fl[fn2] = pt_o[o0 + oq]; fn2 += 1; oq += 1; }
                fl[fn2] = ','; fn2 += 1; fl[fn2] = ' '; fn2 += 1; fl[fn2] = '['; fn2 += 1; fl[fn2] = 'x'; fn2 += 1;
                if rb >= 10 { fl[fn2] = '0' + rb / 10; fn2 += 1; }
                fl[fn2] = '0' + rb % 10; fn2 += 1;
                fl[fn2] = ','; fn2 += 1; fl[fn2] = ' '; fn2 += 1; fl[fn2] = 'x'; fn2 += 1;
                if rc >= 10 { fl[fn2] = '0' + rc / 10; fn2 += 1; }
                fl[fn2] = '0' + rc % 10; fn2 += 1;
                if sk > 0 {
                    fl[fn2] = ','; fn2 += 1; fl[fn2] = ' '; fn2 += 1; fl[fn2] = 'l'; fn2 += 1; fl[fn2] = 's'; fn2 += 1; fl[fn2] = 'l'; fn2 += 1; fl[fn2] = ' '; fn2 += 1; fl[fn2] = '#'; fn2 += 1;
                    fl[fn2] = '0' + sk; fn2 += 1;
                }
                fl[fn2] = ']'; fn2 += 1;
                fl[fn2] = 0;
                pt_set(j, @fl);
                pt_set(i, "");
                return true;
            }
        }
    }
    // mov xT, xV / I that reads xT  ->  I with xV in place of xT      (xT is written by I, or not needed afterwards)
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 0, 'x') != pt_regno(0, 1, 'x') && pt_regno(0, 1, 'x') < 29 {
        i64 rt = pt_regno(0, 0, 'x');
        i64 rv = pt_regno(0, 1, 'x');
        bool okm = pt_mn(1, "str") || pt_mn(1, "strw") || pt_mn(1, "strb") || pt_mn(1, "strh") || pt_mn(1, "ldr") || pt_mn(1, "ldrsw") || pt_mn(1, "ldrb") || pt_mn(1, "ldrh") || pt_mn(1, "ldrsb") || pt_mn(1, "ldrsh")
            || pt_mn(1, "cmp") || pt_mn(1, "cmn") || pt_mn(1, "tst") || pt_mn(1, "add") || pt_mn(1, "sub") || pt_mn(1, "mul") || pt_mn(1, "and") || pt_mn(1, "orr") || pt_mn(1, "eor") || pt_mn(1, "lsl") || pt_mn(1, "lsr") || pt_mn(1, "asr")
            || pt_mn(1, "sxtw") || pt_mn(1, "scvtf") || pt_mn(1, "sdiv") || pt_mn(1, "udiv") || pt_mn(1, "madd") || pt_mn(1, "msub") || pt_mn(1, "neg") || pt_mn(1, "mvn") || pt_mn(1, "cbz") || pt_mn(1, "cbnz");
        if okm && pt_no[1] >= 1 {
            bool reads = false;
            i64 kk = 0;
            bool w0 = pt_writes_first(1);
            while kk < pt_no[1] {
                if pt_rd(1, kk, rt) && !(kk == 0 && w0) { reads = true; }
                kk += 1;
            }
            bool dest_t = w0 && pt_regno(1, 0, 'x') == rt;
            // a store or a compare has no destination: the first operand is read
            if reads && (dest_t || pt_dead(pt_next(j), rt, 40)) {
                pt_build_subst(1, rt, rv);
                pt_set(j, @pt_line);
                pt_set(i, "");
                return true;
            }
        }
    }
    // ldrsw xN, [A] / (one line that does not touch xN) / fmov sK, wN   ->   (the line) / ldr sK, [A]      (xN not needed afterwards)
    if pt_mn(0, "ldrsw") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_op(0, 0, "x1") == false || (pt_mn(0, "ldrsw") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0) {
        i64 nreg2 = pt_regno(0, 0, 'x');
        i64 k6 = pt_next(j);
        if k6 >= 0 && (pt_writes_first(1) || pt_writes_d(1)) && !pt_mn(1, "ldr") && !pt_mn(1, "str") && !pt_mn(1, "strw") && pt_no[1] >= 2 && !pt_rd(1, 0, nreg2) && !pt_rd(1, 1, nreg2) && (pt_no[1] < 3 || !pt_rd(1, 2, nreg2)) && pt_parse(2, k6) {
            i64 ob2 = (0 * 4 + 1) * 40;
            i64 bn2 = 0 - 1;
            if pt_o[ob2] == '[' && pt_o[ob2 + 1] == 'x' {
                bn2 = 0;
                i64 q2 = ob2 + 2;
                while pt_o[q2] >= '0' && pt_o[q2] <= '9' {
                    bn2 = bn2 * 10 + (pt_o[q2] - '0');
                    q2 += 1;
                }
            }
            // the line in between must not write the base register of the load, nor read or write the float register that gets the value
            i64 sk2 = pt_regno(2, 0, 's');
            bool mid_ok = bn2 >= 0 && !(pt_regno(1, 0, 'x') == bn2) && sk2 >= 0 && pt_regno(1, 0, 's') != sk2 && pt_regno(1, 1, 's') != sk2 && (pt_no[1] < 3 || pt_regno(1, 2, 's') != sk2) && pt_regno(1, 0, 'd') != sk2 && pt_regno(1, 1, 'd') != sk2;
            // the index register of [xB, xI, lsl #n] counts too: the line in between must not write it either
            i64 midreg = pt_regno(1, 0, 'x');
            if mid_ok && midreg >= 0 {
                i64 sc = ob2;
                while pt_o[sc] != 0 {
                    if pt_o[sc] == 'x' && pt_o[sc + 1] >= '0' && pt_o[sc + 1] <= '9' && (pt_o[sc - 1] == ' ' || pt_o[sc - 1] == '[' || pt_o[sc - 1] == ',') {
                        i64 rn = 0;
                        i64 sd = sc + 1;
                        while pt_o[sd] >= '0' && pt_o[sd] <= '9' { rn = rn * 10 + (pt_o[sd] - '0'); sd += 1; }
                        if rn == midreg { mid_ok = false; }
                    }
                    sc += 1;
                }
            }
            if mid_ok && pt_mn(2, "fmov") && pt_no[2] == 2 && pt_regno(2, 1, 'w') == nreg2 && pt_dead(pt_next(k6), nreg2, 40) {
                char lb2[64];
                i64 ln2 = 0;
                lb2[0] = 'l'; lb2[1] = 'd'; lb2[2] = 'r'; lb2[3] = ' '; lb2[4] = 's'; ln2 = 5;
                char lg2[8];
                i64 lk2 = 0;
                i64 lv2 = sk2;
                if lv2 == 0 { lg2[0] = '0'; lk2 = 1; }
                while lv2 > 0 { lg2[lk2] = '0' + lv2 % 10; lk2 += 1; lv2 = lv2 / 10; }
                while lk2 > 0 { lk2 -= 1; lb2[ln2] = lg2[lk2]; ln2 += 1; }
                lb2[ln2] = ','; lb2[ln2 + 1] = ' '; ln2 += 2;
                i64 mc2 = 0;
                while pt_o[ob2 + mc2] != 0 && ln2 < 62 { lb2[ln2] = pt_o[ob2 + mc2]; ln2 += 1; mc2 += 1; }
                lb2[ln2] = 0;
                pt_set(k6, @lb2);
                pt_set(i, "");
                return true;
            }
        }
    }
    // fmov wN, sK / (one line that does not touch xN or sK) / strw xN, [A]   ->   (the line) / str sK, [A]      (xN not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'w') >= 0 && pt_regno(0, 1, 's') >= 0 {
        i64 nreg3 = pt_regno(0, 0, 'w');
        i64 sk3 = pt_regno(0, 1, 's');
        i64 k7 = pt_next(j);
        if k7 >= 0 && (pt_writes_first(1) || pt_writes_d(1)) && !pt_mn(1, "ldr") && !pt_mn(1, "str") && !pt_mn(1, "strw") && pt_no[1] >= 2 && !pt_rd(1, 0, nreg3) && !pt_rd(1, 1, nreg3) && (pt_no[1] < 3 || !pt_rd(1, 2, nreg3)) && pt_regno(1, 0, 's') != sk3 && pt_regno(1, 0, 'd') != sk3 && pt_parse(2, k7) {
            if pt_mn(2, "strw") && pt_no[2] == 2 && pt_regno(2, 0, 'x') == nreg3 && !pt_has_reg(2, 1, nreg3) && pt_dead(pt_next(k7), nreg3, 40) {
                char lb3[64];
                i64 ln3 = 0;
                lb3[0] = 's'; lb3[1] = 't'; lb3[2] = 'r'; lb3[3] = ' '; lb3[4] = 's'; ln3 = 5;
                char lg3[8];
                i64 lk3 = 0;
                i64 lv3 = sk3;
                if lv3 == 0 { lg3[0] = '0'; lk3 = 1; }
                while lv3 > 0 { lg3[lk3] = '0' + lv3 % 10; lk3 += 1; lv3 = lv3 / 10; }
                while lk3 > 0 { lk3 -= 1; lb3[ln3] = lg3[lk3]; ln3 += 1; }
                lb3[ln3] = ','; lb3[ln3 + 1] = ' '; ln3 += 2;
                i64 ob3 = (2 * 4 + 1) * 40;
                i64 mc3 = 0;
                while pt_o[ob3 + mc3] != 0 && ln3 < 62 { lb3[ln3] = pt_o[ob3 + mc3]; ln3 += 1; mc3 += 1; }
                lb3[ln3] = 0;
                pt_set(k7, @lb3);
                pt_set(i, "");
                return true;
            }
        }
    }
    // a float that lives in d8..d15: fmov xN, dK / fmov sM, wN  ->  fmov sM, sK      fmov wN, sK / fmov dM, xN  ->  fmov sM, sK   (xN not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_mn(1, "fmov") && pt_no[1] == 2 {
        i64 fxn = 0 - 1;
        i64 fsrc = 0 - 1;
        i64 fdst = 0 - 1;
        if pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_regno(1, 0, 's') >= 0 && pt_regno(1, 1, 'w') == pt_regno(0, 0, 'x') {
            fxn = pt_regno(0, 0, 'x'); fsrc = pt_regno(0, 1, 'd'); fdst = pt_regno(1, 0, 's');
        } else if pt_regno(0, 0, 'w') >= 0 && pt_regno(0, 1, 's') >= 0 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'x') == pt_regno(0, 0, 'w') {
            fxn = pt_regno(0, 0, 'w'); fsrc = pt_regno(0, 1, 's'); fdst = pt_regno(1, 0, 'd');
        }
        if fxn >= 0 && pt_dead(pt_next(j), fxn, 40) {
            char fb[24];
            fb[0] = 'f'; fb[1] = 'm'; fb[2] = 'o'; fb[3] = 'v'; fb[4] = ' '; fb[5] = 's';
            i64 fn = 6;
            char fg[8];
            i64 fk = 0;
            i64 fv = fdst;
            if fv == 0 { fg[0] = '0'; fk = 1; }
            while fv > 0 { fg[fk] = '0' + fv % 10; fk += 1; fv = fv / 10; }
            while fk > 0 { fk -= 1; fb[fn] = fg[fk]; fn += 1; }
            fb[fn] = ','; fb[fn + 1] = ' '; fb[fn + 2] = 's'; fn += 3;
            fv = fsrc;
            if fv == 0 { fg[0] = '0'; fk = 1; }
            while fv > 0 { fg[fk] = '0' + fv % 10; fk += 1; fv = fv / 10; }
            while fk > 0 { fk -= 1; fb[fn] = fg[fk]; fn += 1; }
            fb[fn] = 0;
            pt_set(j, @fb);
            pt_set(i, "");
            return true;
        }
    }
    // fmov dB, dA / I using dB  ->  I using dA   (dB is written by I, or not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 0, 'd') != pt_regno(0, 1, 'd') && (pt_mn(1, "fadd") || pt_mn(1, "fsub") || pt_mn(1, "fmul") || pt_mn(1, "fdiv") || pt_mn(1, "fsqrt") || pt_mn(1, "fneg") || pt_mn(1, "fabs") || pt_mn(1, "fcmp") || pt_mn(1, "fmov") || pt_mn(1, "fcvtzs") || pt_mn(1, "str") || pt_mn(1, "frintm") || pt_mn(1, "frintp") || pt_mn(1, "frintz")) {
        i64 db = pt_regno(0, 0, 'd');
        char sd[40];
        i64 o0 = (0 * 4 + 1) * 40;
        i64 c = 0;
        while pt_o[o0 + c] != 0 { sd[c] = pt_o[o0 + c]; c += 1; }
        sd[c] = 0;
        bool dest_b = pt_writes_first(1) && pt_regno(1, 0, 'd') == db;
        pt_sub_prefix = 'd';
        i64 cnt = pt_subst(1, db, @sd, pt_writes_first(1) && !pt_mn(1, "str") && !pt_mn(1, "fcmp"));
        if cnt > 0 && (dest_b || pt_dead(pt_next(j), 32 + db, 40)) {
            char nl[64];
            i64 q = 0;
            while pt_line[q] != 0 { nl[q] = pt_line[q]; q += 1; }
            nl[q] = 0;
            pt_set(j, @nl);
            pt_set(i, "");
            return true;
        }
    }
    // mov xT, xV / ... / I that reads xT   ->   (the lines) / I with xV      (see pt_fwd_icopy)
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 0, 'x') != pt_regno(0, 1, 'x') && pt_regno(0, 1, 'x') < 29 && opt_icopy == 1 {
        if pt_fwd_icopy(i) { return true; }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // FOP rA, ... / fmov rB, rA   ->   FOP rB, ...      (a floating-point operation, rA a float or a double register not needed afterwards)
    if opt_icopy == 1 && pt_no[0] >= 2 && pt_mn(1, "fmov") && pt_no[1] == 2 && (pt_mn(0, "fadd") || pt_mn(0, "fsub") || pt_mn(0, "fmul") || pt_mn(0, "fdiv") || pt_mn(0, "fsqrt") || pt_mn(0, "fabs") || pt_mn(0, "fneg") || pt_mn(0, "fmax") || pt_mn(0, "fmin") || pt_mn(0, "fmadd") || pt_mn(0, "fmsub") || pt_mn(0, "fnmadd") || pt_mn(0, "fnmsub")) {
        char fkind = 'd';
        i64 fa1 = pt_regno(0, 0, 'd');
        if fa1 < 0 { fa1 = pt_regno(0, 0, 's'); fkind = 's'; }
        i64 fb1 = pt_regno(1, 0, fkind);
        i64 fc1 = pt_regno(1, 1, fkind);
        if fa1 >= 0 && fb1 >= 0 && fc1 == fa1 && fb1 != fa1 && pt_dead(pt_next(j), 32 + fa1, 40) {
            char rn[12];
            i64 rq = 0;
            rn[rq] = fkind; rq += 1;
            if fb1 >= 10 { rn[rq] = '0' + fb1 / 10; rq += 1; }
            rn[rq] = '0' + fb1 % 10; rq += 1;
            rn[rq] = 0;
            pt_build(0, 0, @rn);
            pt_set(i, @pt_line);
            pt_set(j, "");
            return true;
        }
    }
    // the same for floats: fmov sT, sV / ... / OP D, ..., sT, ...
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 's') >= 0 && pt_regno(0, 1, 's') >= 0 && pt_regno(0, 0, 's') != pt_regno(0, 1, 's') && opt_icopy == 1 {
        pt_fk = 's';
        bool fwd_s = pt_fwd_copy(i);
        pt_fk = 'd';
        if fwd_s { return true; }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // fmov dT, dV / ... / OP D, ..., dT, ...   ->   (the lines) / OP D, ..., dV, ...      (see pt_fwd_copy)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 && pt_regno(0, 0, 'd') != pt_regno(0, 1, 'd') {
        if pt_fwd_copy(i) { return true; }
        pt_parse(0, i);
        pt_parse(1, j);
    }
    // fmov dA, S / fmov dB, dA   ->   fmov dB, S   (dA is not needed afterwards)
    if pt_mn(0, "fmov") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_mn(1, "fmov") && pt_no[1] == 2 && pt_regno(1, 0, 'd') >= 0 && pt_regno(1, 1, 'd') == pt_regno(0, 0, 'd') && pt_regno(1, 0, 'd') != pt_regno(0, 0, 'd') && (pt_regno(0, 1, 'x') >= 0 || pt_regno(0, 1, 'd') >= 0) {
        if pt_dead(pt_next(j), 32 + pt_regno(0, 0, 'd'), 40) {
            i64 o1 = (1 * 4 + 0) * 40;
            i64 o0 = (0 * 4 + 1) * 40;
            char nl[40];
            i64 n = 0;
            nl[0] = 'f'; nl[1] = 'm'; nl[2] = 'o'; nl[3] = 'v'; nl[4] = ' ';
            n = 5;
            i64 c = 0;
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
        i64 nreg = pt_regno(0, 0, 'x');
        i64 k5 = pt_next(j);
        if k5 >= 0 && (pt_writes_first(1) || pt_writes_d(1)) && !pt_mn(1, "ldr") && !pt_mn(1, "str") && pt_no[1] >= 2 && !pt_rd(1, 0, nreg) && !pt_rd(1, 1, nreg) && (pt_no[1] < 3 || !pt_rd(1, 2, nreg)) && pt_parse(2, k5) {
            // the base register of the load (the operand "[xB, #N]"): not written by the line in between
            i64 ob = (0 * 4 + 1) * 40;
            i64 bn = 0 - 1;
            if pt_o[ob] == '[' && pt_o[ob + 1] == 'x' {
                bn = 0;
                i64 q = ob + 2;
                while pt_o[q] >= '0' && pt_o[q] <= '9' {
                    bn = bn * 10 + (pt_o[q] - '0');
                    q += 1;
                }
            }
            bool base_ok = bn >= 0 && !(pt_regno(1, 0, 'x') == bn);
            if base_ok && pt_mn(2, "fmov") && pt_no[2] == 2 && pt_regno(2, 0, 'd') >= 0 && pt_regno(2, 1, 'x') == nreg && pt_dead(pt_next(k5), nreg, 40) {
                i64 o2 = (2 * 4 + 0) * 40;
                char dd[40];
                i64 c = 0;
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
        i64 dr = pt_regno(0, 0, 'x');
        if (dr <= 4 || (dr >= 10 && dr <= 17)) && pt_dead(j, dr, 40) {
            pt_set(i, "");
            return true;
        }
    }
    // mov x0, A / OP D, x0, Y  (Y is not x0)  ->  OP D, A, Y   when D is x0 or x0 is not needed afterwards
    if pt_mn(0, "mov") && pt_op(0, 0, "x0") && pt_no[0] == 2 && pt_isreg(0, 1) && !pt_op(0, 1, "x0") && pt_writes_first(1) && !pt_mn(1, "mov") && !pt_mn(1, "ldr") && !pt_mn(1, "msub") && !pt_mn(1, "madd") && !pt_mn(1, "adr") && pt_no[1] >= 3 && pt_isreg(1, 0) && pt_op(1, 1, "x0") && !pt_has_reg(1, 2, 0) {
        bool ok = pt_op(1, 0, "x0") || pt_dead(pt_next(j), 0, 40);
        if ok {
            i64 o0 = (0 * 4 + 1) * 40;
            char aa[40];
            i64 c = 0;
            while pt_o[o0 + c] != 0 { aa[c] = pt_o[o0 + c]; c += 1; }
            aa[c] = 0;
            pt_build(1, 1, @aa);
            pt_set(j, @pt_line);
            pt_set(i, "");
            return true;
        }
    }
    // mov x1, x0 / mov x0, S / OP D, x0, x1  ->  OP D, S, x0   (the two registers are not needed afterwards)
    i64 k2 = pt_next(j);
    if k2 >= 0 && pt_mn(0, "mov") && pt_op(0, 0, "x1") && pt_op(0, 1, "x0") && pt_mn(1, "mov") && pt_op(1, 0, "x0") && pt_no[1] == 2 && (pt_isreg(1, 1) || pt_isnum(1, 1)) && !pt_op(1, 1, "x1") && pt_parse(2, k2) {
        if pt_writes_first(2) && !pt_mn(2, "mov") && !pt_mn(2, "ldr") && !pt_mn(2, "msub") && !pt_mn(2, "madd") && !pt_mn(2, "adr") && pt_no[2] == 3 && pt_isreg(2, 0) && pt_op(2, 1, "x0") && pt_op(2, 2, "x1") && !pt_op(2, 0, "x0") && !pt_op(2, 0, "x1") {
            if pt_dead(pt_next(k2), 0, 40) && pt_dead(pt_next(k2), 1, 40) && pt_isreg(1, 1) {
                i64 o1 = (1 * 4 + 1) * 40;
                char ss[40];
                i64 c = 0;
                while pt_o[o1 + c] != 0 { ss[c] = pt_o[o1 + c]; c += 1; }
                ss[c] = 0;
                pt_build(2, 1, @ss);
                // the third operand becomes x0
                char tmp[64];
                i64 q = 0;
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
                i64 o1 = (1 * 4 + 1) * 40;
                char tmp2[64];
                i64 n = 0;
                tmp2[0] = 'c'; tmp2[1] = 'm'; tmp2[2] = 'p'; tmp2[3] = ' ';
                n = 4;
                i64 c = 0;
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
            i64 o0 = (0 * 4 + 1) * 40;
            i64 o1 = (1 * 4 + 1) * 40;
            char t3[64];
            i64 n = 0;
            t3[0] = 'c'; t3[1] = 'm'; t3[2] = 'p'; t3[3] = ' ';
            n = 4;
            i64 c = 0;
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
            i64 o0 = (0 * 4 + 1) * 40;
            i64 o1 = (1 * 4 + 1) * 40;
            char t4[64];
            i64 n = 0;
            t4[0] = 'c'; t4[1] = 'm'; t4[2] = 'p'; t4[3] = ' ';
            n = 4;
            i64 c = 0;
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

// the text "mov xA, xB" written to t
void pt_regline(char^ t, i64 a, i64 b) {
    i64 n = 0;
    t[0] = 'm'; t[1] = 'o'; t[2] = 'v'; t[3] = ' '; t[4] = 'x';
    n = 5;
    if a >= 10 { t[n] = '1'; t[n + 1] = '0' + a - 10; n += 2; } else { t[n] = '0' + a; n += 1; }
    t[n] = ','; t[n + 1] = ' '; t[n + 2] = 'x';
    n += 3;
    if b >= 10 { t[n] = '1'; t[n + 1] = '0' + b - 10; n += 2; } else { t[n] = '0' + b; n += 1; }
    t[n] = 0;
}

// the previous live line before idx, or -1
i64 pt_prev(i64 idx) {
    idx -= 1;
    while idx >= 0 && pt_txt[idx * 64] == 0 { idx -= 1; }
    return idx;
}

// is the line idx exactly the text t?
bool pt_is(i64 idx, char^ t) {
    i64 b = idx * 64;
    i64 i = 0;
    while t[i] != 0 {
        if pt_txt[b + i] != t[i] { return false; }
        i += 1;
    }
    return pt_txt[b + i] == 0;
}

// the arguments of a call that are pushed one by one and then loaded into x0, x1, ... :
//     <code> / sub sp, sp, #16 / str x0, [sp, #0] / <code> / sub sp, sp, #16 / str x0, [sp, #0] / ldr x1, [sp, #0] / ldr x0, [sp, #16] / add sp, sp, #32
// become: the earlier values wait in x5, x6, x7, the last one stays in x0, and the moves into x0, x1, ... are made at the end. Only if
// the code between the pushes is made of plain instructions (no stack, no call, no x5..x7), at most 4 values.
bool pt_pushpop() {
    bool changed = false;
    i64 i = 0;
    while i < pt_n {
        if pt_txt[i * 64] != 0 && pt_parse(0, i) && pt_mn(0, "ldr") && pt_no[0] == 2 && pt_op(0, 1, "[sp, #0]") && pt_regno(0, 0, 'x') >= 1 && pt_regno(0, 0, 'x') <= 3 {
            i64 nn = pt_regno(0, 0, 'x') + 1;
            i64 ldr_at[4];
            ldr_at[0] = i;
            bool ok = true;
            i64 k = 1;
            i64 cur = i;
            while k < nn && ok {
                cur = pt_next(cur);
                if cur < 0 || !pt_parse(0, cur) || !pt_mn(0, "ldr") || pt_no[0] != 2 || pt_regno(0, 0, 'x') != nn - 1 - k { ok = false; }
                else {
                    // the address: [sp, #16k]
                    char want[24];
                    want[0] = '['; want[1] = 's'; want[2] = 'p'; want[3] = ','; want[4] = ' '; want[5] = '#';
                    i64 w = 6;
                    i64 dv = 16 * k;
                    char dg[8];
                    i64 dn = 0;
                    while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
                    while dn > 0 { dn -= 1; want[w] = dg[dn]; w += 1; }
                    want[w] = ']';
                    want[w + 1] = 0;
                    if !pt_op(0, 1, @want) { ok = false; }
                    ldr_at[k] = cur;
                }
                k += 1;
            }
            i64 add_at = 0 - 1;
            if ok {
                add_at = pt_next(cur);
                char wadd[24];
                wadd[0] = 'a'; wadd[1] = 'd'; wadd[2] = 'd'; wadd[3] = ' '; wadd[4] = 's'; wadd[5] = 'p'; wadd[6] = ','; wadd[7] = ' '; wadd[8] = 's'; wadd[9] = 'p'; wadd[10] = ','; wadd[11] = ' '; wadd[12] = '#';
                i64 w2 = 13;
                i64 dv2 = 16 * nn;
                char dg2[8];
                i64 dn2 = 0;
                while dv2 > 0 { dg2[dn2] = '0' + dv2 % 10; dv2 = dv2 / 10; dn2 += 1; }
                while dn2 > 0 { dn2 -= 1; wadd[w2] = dg2[dn2]; w2 += 1; }
                wadd[w2] = 0;
                if add_at < 0 || !pt_is(add_at, @wadd) { ok = false; }
            }
            // the pushes, from the last one backwards
            i64 sub_at[4];
            i64 str_at[4];
            i64 used[16];
            i64 u0 = 0;
            while u0 < 16 {
                used[u0] = 0;
                u0 += 1;
            }
            if ok {
                i64 p = pt_prev(i);
                i64 pi = nn - 1;
                i64 guard = 0;
                while pi >= 0 && ok {
                    // p must be "str x0, [sp, #0]" and the line before it "sub sp, sp, #16"
                    if p < 0 || !pt_is(p, "str x0, [sp, #0]") { ok = false; }
                    else {
                        i64 q = pt_prev(p);
                        if q < 0 || !pt_is(q, "sub sp, sp, #16") { ok = false; }
                        else {
                            str_at[pi] = p;
                            sub_at[pi] = q;
                            pi -= 1;
                            // the code before this push (up to the previous push): plain instructions only
                            if pi >= 0 {
                                i64 r = pt_prev(q);
                                guard = 0;
                                bool found = false;
                                while r >= 0 && !found && ok && guard < 80 {
                                    guard += 1;
                                    if pt_is(r, "str x0, [sp, #0]") {
                                        i64 r2 = pt_prev(r);
                                        if r2 >= 0 && pt_is(r2, "sub sp, sp, #16") { found = true; }
                                        else { ok = false; }
                                    } else if pt_parse(1, r) {
                                        i64 kk = 0;
                                        while kk < pt_no[1] {
                                            i64 ur = 5;
                                            while ur < 15 {
                                                if pt_has_reg(1, kk, ur) { used[ur] = 1; }
                                                ur += 1;
                                            }
                                            if pt_o[(1 * 4 + kk) * 40] == 's' && pt_o[(1 * 4 + kk) * 40 + 1] == 'p' { ok = false; }
                                            if pt_o[(1 * 4 + kk) * 40] == '[' && pt_o[(1 * 4 + kk) * 40 + 1] == 's' && pt_o[(1 * 4 + kk) * 40 + 2] == 'p' { ok = false; }
                                            kk += 1;
                                        }
                                        if pt_mn(1, "bl") && !(pt_op(1, 0, "j2k_divzero") || pt_op(1, 0, "j2k_oob")) { ok = false; }
                                        if pt_mn(1, "blr") || pt_mn(1, "svc") || pt_mn(1, "ret") || pt_mn(1, "br") { ok = false; }
                                        if pt_mn(1, "sub") && pt_op(1, 0, "sp") { ok = false; }
                                        if !found { r = pt_prev(r); }
                                    } else {
                                        // a label inside the code of an argument: fine
                                        r = pt_prev(r);
                                    }
                                }
                                if !found { ok = false; }
                                else { p = r; }
                            }
                        }
                    }
                }
            }
            // the registers that hold the earlier values: x10..x14 if the code of the arguments does not use them (a call does not
            // read them), else x5..x7
            i64 hold[4];
            if ok {
                i64 nh = 0;
                i64 cand = 10;
                while cand <= 14 && nh < nn - 1 {
                    if used[cand] == 0 && !(cand >= 5 && cand <= 7) { hold[nh] = cand; nh += 1; }
                    cand += 1;
                }
                cand = 5;
                while cand <= 7 && nh < nn - 1 {
                    if used[cand] == 0 { hold[nh] = cand; nh += 1; }
                    cand += 1;
                }
                if nh < nn - 1 { ok = false; }
            }
            if ok {
                i64 pj = 0;
                while pj < nn {
                    if pj < nn - 1 {
                        char mv[24];
                        pt_regline(@mv, hold[pj], 0);
                        pt_set(sub_at[pj], @mv);
                    } else {
                        pt_set(sub_at[pj], "");
                    }
                    pt_set(str_at[pj], "");
                    pj += 1;
                }
                i64 kq = 0;
                while kq < nn {
                    char mv2[24];
                    i64 tgt = nn - 1 - kq;
                    i64 srcr = 0;
                    if kq != 0 { srcr = hold[tgt]; }
                    pt_regline(@mv2, tgt, srcr);
                    pt_set(ldr_at[kq], @mv2);
                    kq += 1;
                }
                pt_set(add_at, "");
                changed = true;
            }
        }
        i += 1;
    }
    return changed;
}


// ---- loop-invariant motion (S3): in a rotated loop (the head is "  .align 16 / Lnnn:" and one jump goes back to it) a null check
// `cmp xN, 0 / b.eq P` and a load `ldr xK, [xN, #imm]` (or `ldr dK`) at the start of the body move to the room that regs_post
// left before the ".align" when xN does not change in the loop, the loop makes no call and no store, and nobody jumps into the
// middle of the loop. The loop is entered only by the fall through, so the moved lines run once before the first pass and
// the register holds the same value as the pass would have loaded.

// does the parsed line (slot s) end the straight run (a branch) ?
bool pt_is_branch(i64 s) {
    i64 m = s * 16;
    if pt_m[m] == 'b' && (pt_m[m + 1] == 0 || pt_m[m + 1] == '.') { return true; }
    return pt_mn(s, "cbz") || pt_mn(s, "cbnz") || pt_mn(s, "tbz") || pt_mn(s, "tbnz") || pt_mn(s, "br") || pt_mn(s, "ret");
}

// a line that may change memory or leave the function
bool pt_is_storeish(i64 s) {
    i64 m = s * 16;
    // a store of an array element `str xV, [xBase, xIndex, lsl #k]` writes the data of an array, never a header or a frame cell
    if (pt_mn(s, "str") || pt_mn(s, "strb") || pt_mn(s, "strh")) && pt_no[s] == 2 {
        i64 o = (s * 4 + 1) * 40;
        i64 i = 0;
        while pt_o[o + i] != 0 && pt_o[o + i] != ',' { i += 1; }
        if pt_o[o + i] == ',' && pt_o[o + i + 1] == ' ' && (pt_o[o + i + 2] == 'x' || pt_o[o + i + 2] == 'w') { return false; }
    }
    if pt_mn(s, "bl") || pt_mn(s, "blr") || pt_mn(s, "svc") || pt_mn(s, "dmb") || pt_mn(s, "dsb") || pt_mn(s, "isb") || pt_mn(s, "swp") { return true; }
    if pt_m[m] == 's' && pt_m[m + 1] == 't' { return true; }
    if pt_m[m] == 'l' && pt_m[m + 1] == 'd' && (pt_m[m + 2] == 'x' || pt_m[m + 2] == 'a') { return true; }
    if pt_m[m] == 'c' && pt_m[m + 1] == 'a' && pt_m[m + 2] == 's' { return true; }
    return false;
}

// does the parsed line (slot s) write the register r (0..30 x, 32..63 d)?
bool pt_wr(i64 s, i64 r) {
    if pt_is_branch(s) || pt_mn(s, "cmp") || pt_mn(s, "cmn") || pt_mn(s, "tst") || pt_mn(s, "fcmp") || pt_mn(s, "fcmpe") || pt_mn(s, "prfm") { return false; }
    i64 m0 = s * 16;
    bool isst = pt_m[m0] == 's' && pt_m[m0 + 1] == 't';        // str, strb, strh, stp, stur ...: the first operand is read, not written
    if !isst && pt_no[s] >= 1 && pt_rd(s, 0, r) { return true; }
    if pt_mn(s, "ldp") && pt_no[s] >= 2 && pt_rd(s, 1, r) { return true; }
    if pt_no[s] >= 3 && r < 32 {
        i64 o = (s * 4 + 1) * 40;
        if pt_o[o] == '[' && pt_has_reg(s, 1, r) { return true; }       // a base register that is written back
    }
    i64 k = 0;
    while k < pt_no[s] {
        i64 o2 = (s * 4 + k) * 40;
        i64 e = 0;
        while pt_o[o2 + e] != 0 { e += 1; }
        if e > 0 && pt_o[o2 + e - 1] == '!' && r < 32 && pt_has_reg(s, k, r) { return true; }
        k += 1;
    }
    return false;
}

// does the parsed line (slot s) mention the register r in any operand?
bool pt_mentions(i64 s, i64 r) {
    i64 k = 0;
    while k < pt_no[s] {
        if pt_rd(s, k, r) { return true; }
        k += 1;
    }
    return false;
}

bool pt_flag_setter(i64 s) {
    return pt_mn(s, "cmp") || pt_mn(s, "cmn") || pt_mn(s, "tst") || pt_mn(s, "fcmp") || pt_mn(s, "fcmpe") || pt_mn(s, "subs") || pt_mn(s, "adds") || pt_mn(s, "ands") || pt_mn(s, "bics") || pt_mn(s, "negs");
}

bool pt_flag_reader(i64 s) {
    i64 m = s * 16;
    if pt_m[m] == 'b' && pt_m[m + 1] == '.' { return true; }
    return pt_mn(s, "csel") || pt_mn(s, "csinc") || pt_mn(s, "csinv") || pt_mn(s, "csneg") || pt_mn(s, "cset") || pt_mn(s, "csetm") || pt_mn(s, "cinc") || pt_mn(s, "cinv") || pt_mn(s, "cneg") || pt_mn(s, "fcsel") || pt_mn(s, "adc") || pt_mn(s, "adcs") || pt_mn(s, "sbc") || pt_mn(s, "sbcs") || pt_mn(s, "ccmp") || pt_mn(s, "ccmn");
}

// from the line `from` on, the flags are set before anybody reads them (inside the loop body, up to the line jj)
bool pt_flags_free(i64 from, i64 jj) {
    i64 q = from;
    while q >= 0 && q <= jj {
        if !pt_parse(2, q) { return false; }
        if pt_flag_setter(2) { return true; }
        if pt_flag_reader(2) || pt_is_branch(2) { return false; }
        q = pt_next(q);
    }
    return false;
}

// the number n of the label operand "Ln" that is the last operand of the parsed line (slot s), or -1
i64 pt_target_num(i64 s) {
    if pt_no[s] < 1 { return 0 - 1; }
    i64 o = (s * 4 + pt_no[s] - 1) * 40;
    if pt_o[o] != 'L' { return 0 - 1; }
    i64 i = 1;
    i64 v = 0;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return 0 - 1; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] != 0 { return 0 - 1; }
    return v;
}

// the register number of the base of the operand "[xN, #imm]" or "[xN]" (slot s, operand k), or -1
i64 pt_base_reg(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    if pt_o[o] != '[' || pt_o[o + 1] != 'x' { return 0 - 1; }
    i64 i = 2;
    i64 v = 0;
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return 0 - 1; }
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] == ']' && pt_o[o + i + 1] == 0 { return v; }
    if pt_o[o + i] == ',' && pt_o[o + i + 1] == ' ' && pt_o[o + i + 2] == '#' {
        i64 j = o + i + 3;
        if pt_o[j] == '-' { j += 1; }
        if pt_o[j] < '0' || pt_o[j] > '9' { return 0 - 1; }
        while pt_o[j] >= '0' && pt_o[j] <= '9' { j += 1; }
        if pt_o[j] == ']' && pt_o[j + 1] == 0 { return v; }
    }
    return 0 - 1;
}

// the register number (0..30 x, 32..63 d or s) of operand k of slot s when it is a plain register, or -1
i64 pt_reg_of(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    char c = pt_o[o];
    if (c != 'x' && c != 'd' && c != 's') || pt_o[o + 1] < '0' || pt_o[o + 1] > '9' { return 0 - 1; }
    i64 i = 1;
    i64 v = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] != 0 || v > 31 { return 0 - 1; }
    if c == 'x' { return v; }
    return 32 + v;
}

// is the operand k of slot s "[xN]" or "[xN, #0]"?
bool pt_zero_off(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    if pt_o[o] != '[' || pt_o[o + 1] != 'x' { return false; }
    i64 i = 2;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' { i += 1; }
    if pt_o[o + i] == ']' && pt_o[o + i + 1] == 0 { return true; }
    return pt_o[o + i] == ',' && pt_o[o + i + 1] == ' ' && pt_o[o + i + 2] == '#' && pt_o[o + i + 3] == '0' && pt_o[o + i + 4] == ']' && pt_o[o + i + 5] == 0;
}

// the register F that the lines lab..jj do not mention and that nobody needs at the head of the loop, or -1
// (floats: s16..s23 are used; whole numbers: x1..x15 but not x8)
i64 pt_free_reg(i64 lab, i64 jj, bool fl) {
    i64 f = 1;
    if fl { f = 48; }
    i64 top = 15;
    if fl { top = 55; }
    while f <= top {
        if fl || (f != 8 && f != 16 && f != 17) {
            bool used = false;
            i64 w = pt_next(lab);
            while w >= 0 && w <= jj {
                if pt_parse(3, w) && pt_mentions(3, f) { used = true; break; }
                w = pt_next(w);
            }
            if !used && pt_dead(lab, f, 60) { return f; }
        }
        f += 1;
    }
    return 0 - 1;
}

// the register rk is written at q and written again later in a straight run: the first value gets the register f
// (the lines q .. the next write, the next write itself only when it does not read rk)
bool pt_rename_run(i64 q, i64 jj, i64 rk, i64 f) {
    i64 w = q;
    i64 last = 0 - 1;
    while w >= 0 && w <= jj {
        if !pt_parse(2, w) { return false; }
        if pt_is_branch(2) { return false; }
        if w != q && pt_wr(2, rk) {
            // the next write: its sources must not read rk
            i64 k = 1;
            while k < pt_no[2] { if pt_rd(2, k, rk) { return false; } k += 1; }
            last = w;
            break;
        }
        w = pt_next(w);
    }
    if last < 0 { return false; }
    // no w-form of the register in the run (whole numbers)
    w = q;
    while rk < 32 && w < last {
        if pt_txt[w * 64] != 0 && pt_parse(2, w) {
            i64 k2 = 0;
            while k2 < pt_no[2] {
                i64 o = (2 * 4 + k2) * 40;
                i64 c = 0;
                while pt_o[o + c] != 0 {
                    if pt_o[o + c] == 'w' && (c == 0 || pt_o[o + c - 1] < 'a' || pt_o[o + c - 1] > 'z') && pt_o[o + c + 1] >= '0' && pt_o[o + c + 1] <= '9' {
                        i64 v = 0;
                        i64 c3 = c + 1;
                        while pt_o[o + c3] >= '0' && pt_o[o + c3] <= '9' { v = v * 10 + (pt_o[o + c3] - '0'); c3 += 1; }
                        if v == rk { return false; }
                    }
                    c += 1;
                }
                k2 += 1;
            }
        }
        w += 1;
    }
    i64 pass = 0;
    while pass < 3 {
        char rep[8];
        char letter = 'x';
        i64 fr = f;
        i64 rr = rk;
        if rk >= 32 {
            if pass == 0 { letter = 's'; }
            if pass == 1 { letter = 'd'; }
            if pass == 2 { pass = 3; break; }
            fr = f - 32;
            rr = rk - 32;
        }
        rep[0] = letter;
        i64 rl = 1;
        if fr >= 10 { rep[1] = (char)('0' + fr / 10); rl = 2; }
        rep[rl] = (char)('0' + fr % 10);
        rep[rl + 1] = 0;
        pt_sub_prefix = letter;
        w = q;
        while w < last {
            if pt_txt[w * 64] != 0 && pt_parse(2, w) {
                pt_subst(2, rr, (char^)@rep, false);
                pt_set(w, (char^)@pt_line);
            }
            w += 1;
        }
        pass += 1;
        if rk < 32 { break; }
    }
    return true;
}

i64 pt_hl[8];
bool pt_hoist_loop(i64 a, i64 lab, i64 jj, i64 used) {
    // the body: no call, no store (a store of an array element is allowed); which registers are written
    i64 bad = 0;                      // registers that are written by something else than `add xA, xB, xC (, lsl #k)`
    i64 q = pt_next(lab);
    while q >= 0 && q <= jj {
        if pt_parse(0, q) {
            bool addreg = pt_mn(0, "add") && pt_no[0] >= 3 && (pt_o[(0 * 4 + 2) * 40] == 'x' || pt_o[(0 * 4 + 2) * 40] == 'w') && pt_isreg(0, 0);
            i64 r = 0;
            while r < 31 {
                if pt_wr(0, r) && !(addreg && pt_reg_of(0, 0) == r) { bad = bad | (1 << r); }
                r += 1;
            }
        }
        q = pt_next(q);
    }
    i64 gm = 0;                       // registers that hold an element address made by an `add` in this pass
    q = pt_next(lab);
    while q >= 0 && q <= jj {
        if pt_parse(0, q) {
            if pt_mn(0, "add") && pt_no[0] >= 3 && (pt_o[(0 * 4 + 2) * 40] == 'x' || pt_o[(0 * 4 + 2) * 40] == 'w') && pt_isreg(0, 0) {
                i64 ra = pt_reg_of(0, 0);
                if ra >= 0 && ra < 31 && ((bad >> ra) & 1) == 0 { gm = gm | (1 << ra); }
            } else if pt_is_storeish(0) {
                bool elem = false;
                if (pt_mn(0, "str") || pt_mn(0, "strb") || pt_mn(0, "strh")) && pt_no[0] == 2 {
                    i64 rb0 = pt_base_reg(0, 1);
                    bool zero = pt_zero_off(0, 1);
                    if rb0 >= 0 && rb0 < 31 && ((gm >> rb0) & 1) == 1 && zero { elem = true; }
                }
                if !elem { return false; }
            }
        }
        q = pt_next(q);
    }
    // nobody outside jumps into the middle of the loop
    i64 z = 0;
    while z < pt_n {
        if (z < lab || z > jj) && pt_parse(0, z) && pt_is_branch(0) {
            i64 tn = pt_target_num(0);
            if tn >= 0 {
                i64 tl = pt_label_at(tn);
                if tl > lab && tl <= jj { return false; }
            }
        }
        z += 1;
    }
    i64 hn = 0;
    q = pt_next(lab);
    while q >= 0 && q <= jj && hn < 8 - used {
        if !pt_parse(0, q) { break; }
        if pt_is_branch(0) { break; }
        if (pt_mn(0, "cmp") && pt_no[0] == 2 && pt_isreg(0, 0) && (pt_op(0, 1, "0") || pt_op(0, 1, "#0"))) {
            i64 rn = pt_reg_of(0, 0);
            i64 q2 = pt_next(q);
            bool okp = false;
            if q2 >= 0 && q2 <= jj && hn + 2 <= 8 - used && pt_parse(1, q2) && pt_mn(1, "b.eq") && pt_target_num(1) >= 0 && rn != 28 && rn != 29 {
                i64 tl2 = pt_label_at(pt_target_num(1));
                if tl2 < lab || tl2 > jj {
                    // rn is not written in the body
                    bool inv = true;
                    i64 w = pt_next(lab);
                    while w >= 0 && w <= jj {
                        if pt_parse(2, w) && pt_wr(2, rn) { inv = false; break; }
                        w = pt_next(w);
                    }
                    if inv && pt_flags_free(pt_next(q2), jj) { okp = true; }
                }
            }
            if !okp { break; }
            pt_hl[hn] = q;
            pt_hl[hn + 1] = q2;
            hn += 2;
            q = pt_next(q2);
            continue;
        }
        bool isldr = pt_mn(0, "ldr") && pt_no[0] == 2;
        bool isconst = pt_no[0] == 2 && (pt_mn(0, "fmovsi") || (pt_mn(0, "mov") && pt_isnum(0, 1)));
        if isldr || isconst {
            i64 rk = pt_reg_of(0, 0);
            i64 rb = 99;                  // a constant has no base register
            if isldr { rb = pt_base_reg(0, 1); }
            if isconst && ((pt_mn(0, "fmovsi") && rk < 32) || (pt_mn(0, "mov") && rk >= 32)) { rk = 0 - 1; }
            if rk >= 0 && rb >= 0 && rb != 28 && rb != 31 && rk != rb {
                bool inv2 = true;
                i64 nwr = 0;
                i64 nrd = 0;
                i64 w2 = pt_next(lab);
                while w2 >= 0 && w2 <= jj {
                    if pt_parse(2, w2) {
                        if pt_wr(2, rb) { inv2 = false; break; }
                        if pt_wr(2, rk) { nwr += 1; }
                        else if w2 < q && pt_mentions(2, rk) { nrd += 1; }
                        if w2 < q && pt_wr(2, rk) { nrd += 1; }
                    }
                    w2 = pt_next(w2);
                }
                if inv2 && nwr >= 2 && nrd == 0 {
                    i64 ff = pt_free_reg(lab, jj, rk >= 32);
                    if ff >= 0 && pt_rename_run(q, jj, rk, ff) {
                        pt_parse(0, q);
                        nwr = 1;
                    }
                }
                if inv2 && nwr == 1 && nrd == 0 {
                    pt_hl[hn] = q;
                    hn += 1;
                    pt_parse(0, q);
                }
            }
        }
        q = pt_next(q);
    }
    if hn == 0 { return false; }
    // move the lines into the room before the ".align"
    i64 at = a - 8 + used;
    i64 hi = 0;
    while hi < hn {
        i64 src = pt_hl[hi] * 64;
        i64 c = 0;
        while pt_txt[src + c] != 0 {
            pt_txt[(at + hi) * 64 + c] = pt_txt[src + c];
            c += 1;
        }
        pt_txt[(at + hi) * 64 + c] = 0;
        pt_txt[src] = 0;
        hi += 1;
    }
    return true;
}


// a global array far from the base register: add xA, x28, xI (, lsl #k) / OP rt, [xA, #G]  with G above the range of the access
// -> OP rt, [xF, xI (, lsl #k)] where xF = x28 + G is made once before the loop (two lines in the room before the ".align")
i64 pt_far_size(i64 s) {
    if pt_no[s] != 2 { return 0 - 1; }
    if pt_mn(s, "ldr") || pt_mn(s, "str") {
        if pt_regno(s, 0, 'x') >= 0 || pt_regno(s, 0, 'd') >= 0 { return 8; }
        if pt_regno(s, 0, 's') >= 0 { return 4; }
        return 0 - 1;
    }
    if pt_mn(s, "ldrb") || pt_mn(s, "strb") { return 1; }
    if pt_mn(s, "ldrh") || pt_mn(s, "strh") { return 2; }
    if pt_mn(s, "ldrw") || pt_mn(s, "strw") || pt_mn(s, "ldrsw") { return 4; }
    return 0 - 1;
}

// the number after '#' in operand k of slot s ("[xA, #G]"), or -1
i64 pt_far_off(i64 s, i64 k) {
    i64 o = (s * 4 + k) * 40;
    i64 i = 0;
    while pt_o[o + i] != 0 && pt_o[o + i] != '#' { i += 1; }
    if pt_o[o + i] != '#' { return 0 - 1; }
    i += 1;
    i64 v = 0;
    i64 n = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' && n < 12 { v = v * 10 + (pt_o[o + i] - '0'); i += 1; n += 1; }
    if n == 0 || pt_o[o + i] != ']' { return 0 - 1; }
    return v;
}

bool pt_far_loop(i64 a, i64 lab, i64 jj) {
    i64 used = 0;
    while used < 8 && pt_txt[(a - 8 + used) * 64] != 0 { used += 1; }
    if used > 6 { return false; }
    // no call in the loop; nobody outside jumps into the middle of it
    i64 q = pt_next(lab);
    while q >= 0 && q <= jj {
        if pt_parse(0, q) && (pt_mn(0, "bl") || pt_mn(0, "blr") || pt_mn(0, "svc")) { return false; }
        q = pt_next(q);
    }
    i64 z = 0;
    while z < pt_n {
        if (z < lab || z > jj) && pt_parse(0, z) && pt_is_branch(0) {
            i64 tn = pt_target_num(0);
            if tn >= 0 {
                i64 tl = pt_label_at(tn);
                if tl > lab && tl <= jj { return false; }
            }
        }
        z += 1;
    }
    bool any = false;
    i64 rounds = 0;
    while rounds < 2 && used <= 6 {
        rounds += 1;
        // the first far pair gives the offset G of this round
        i64 gG = 0 - 1;
        q = pt_next(lab);
        while q >= 0 && q <= jj && gG < 0 {
            i64 q2 = pt_next(q);
            if q2 >= 0 && q2 <= jj && pt_parse(0, q) && pt_mn(0, "add") && (pt_no[0] == 3 || pt_no[0] == 4) && pt_parse(1, q2) {
                i64 sz = pt_far_size(1);
                i64 ga = pt_regno(0, 0, 'x');
                i64 bb = pt_base_reg(1, 1);
                i64 gv = pt_far_off(1, 1);
                if sz > 0 && ga >= 0 && ga == bb && gv > 4095 * sz && gv % sz == 0 && gv < 2000000000 && pt_regno(1, 0, 'x') != ga { gG = gv; }
            }
            q = pt_next(q);
        }
        if gG < 0 { break; }
        i64 ff = pt_free_reg(lab, jj, false);
        if ff < 0 { break; }
        i64 done = 0;
        q = pt_next(lab);
        while q >= 0 && q <= jj {
            i64 q2 = pt_next(q);
            if q2 >= 0 && q2 <= jj && pt_parse(0, q) && pt_mn(0, "add") && (pt_no[0] == 3 || pt_no[0] == 4) && pt_parse(1, q2) {
                i64 sz = pt_far_size(1);
                i64 ga = pt_regno(0, 0, 'x');
                i64 bb = pt_base_reg(1, 1);
                i64 gv = pt_far_off(1, 1);
                if sz > 0 && ga >= 0 && ga == bb && gv == gG && pt_regno(1, 0, 'x') != ga {
                    // the index and the shift of the add: add xA, x28, xI, lsl #k | add xA, x28, xI | add xA, xI, x28
                    i64 ix = 0 - 1;
                    i64 kk = 0;
                    bool okf = false;
                    if pt_regno(0, 1, 'x') == 28 && pt_regno(0, 2, 'x') >= 0 && pt_regno(0, 2, 'x') != 28 {
                        ix = pt_regno(0, 2, 'x');
                        okf = true;
                        if pt_no[0] == 4 {
                            i64 o3 = (0 * 4 + 3) * 40;
                            if pt_o[o3] == 'l' && pt_o[o3 + 1] == 's' && pt_o[o3 + 2] == 'l' && pt_o[o3 + 3] == ' ' && pt_o[o3 + 4] == '#' && pt_o[o3 + 5] >= '0' && pt_o[o3 + 5] <= '4' && pt_o[o3 + 6] == 0 { kk = pt_o[o3 + 5] - '0'; } else { okf = false; }
                        }
                    } else if pt_no[0] == 3 && pt_regno(0, 2, 'x') == 28 && pt_regno(0, 1, 'x') >= 0 && pt_regno(0, 1, 'x') != 28 {
                        ix = pt_regno(0, 1, 'x');
                        okf = true;
                    }
                    i64 shl = 0;
                    if sz == 2 { shl = 1; } else if sz == 4 { shl = 2; } else if sz == 8 { shl = 3; }
                    if okf && ix >= 0 && ix != ga && ix < 29 && (kk == 0 || kk == shl) && pt_dead(pt_next(q2), ga, 40) {
                        // OP rt, [xF, xI (, lsl #k)]
                        char nl[64];
                        i64 nq = 0;
                        i64 m1 = 1 * 16;
                        while pt_m[m1 + nq] != 0 && nq < 12 { nl[nq] = pt_m[m1 + nq]; nq += 1; }
                        nl[nq] = ' '; nq += 1;
                        i64 o0 = (1 * 4 + 0) * 40;
                        i64 w0 = 0;
                        while pt_o[o0 + w0] != 0 && w0 < 12 { nl[nq] = pt_o[o0 + w0]; nq += 1; w0 += 1; }
                        nl[nq] = ','; nl[nq + 1] = ' '; nl[nq + 2] = '['; nl[nq + 3] = 'x'; nq += 4;
                        if ff >= 10 { nl[nq] = '0' + ff / 10; nq += 1; }
                        nl[nq] = '0' + ff % 10; nq += 1;
                        nl[nq] = ','; nl[nq + 1] = ' '; nl[nq + 2] = 'x'; nq += 3;
                        if ix >= 10 { nl[nq] = '0' + ix / 10; nq += 1; }
                        nl[nq] = '0' + ix % 10; nq += 1;
                        if kk > 0 { nl[nq] = ','; nl[nq + 1] = ' '; nl[nq + 2] = 'l'; nl[nq + 3] = 's'; nl[nq + 4] = 'l'; nl[nq + 5] = ' '; nl[nq + 6] = '#'; nl[nq + 7] = '0' + kk; nq += 8; }
                        nl[nq] = ']'; nq += 1;
                        nl[nq] = 0;
                        pt_set(q, "");
                        pt_set(q2, @nl);
                        done += 1;
                    }
                }
            }
            q = pt_next(q);
        }
        if done == 0 { break; }
        // the two lines that make xF
        char h1[64];
        char h2[64];
        i64 hq = 0;
        h1[0] = 'm'; h1[1] = 'o'; h1[2] = 'v'; h1[3] = ' '; h1[4] = 'x'; hq = 5;
        if ff >= 10 { h1[hq] = '0' + ff / 10; hq += 1; }
        h1[hq] = '0' + ff % 10; hq += 1;
        h1[hq] = ','; h1[hq + 1] = ' '; hq += 2;
        char dg[16];
        i64 dn = 0;
        i64 gt = gG;
        while gt > 0 { dg[dn] = '0' + gt % 10; dn += 1; gt = gt / 10; }
        while dn > 0 { dn -= 1; h1[hq] = dg[dn]; hq += 1; }
        h1[hq] = 0;
        i64 hp = 0;
        h2[0] = 'a'; h2[1] = 'd'; h2[2] = 'd'; h2[3] = ' '; h2[4] = 'x'; hp = 5;
        if ff >= 10 { h2[hp] = '0' + ff / 10; hp += 1; }
        h2[hp] = '0' + ff % 10; hp += 1;
        h2[hp] = ','; h2[hp + 1] = ' '; h2[hp + 2] = 'x'; hp += 3;
        if ff >= 10 { h2[hp] = '0' + ff / 10; hp += 1; }
        h2[hp] = '0' + ff % 10; hp += 1;
        h2[hp] = ','; h2[hp + 1] = ' '; h2[hp + 2] = 'x'; h2[hp + 3] = '2'; h2[hp + 4] = '8'; h2[hp + 5] = 0;
        pt_set(a - 8 + used, @h1);
        pt_set(a - 8 + used + 1, @h2);
        used += 2;
        any = true;
    }
    return any;
}

bool pt_hoist() {
    if opt_hoist == 0 { return false; }
    bool any = false;
    i64 a = 8;
    while a < pt_n {
        if pt_txt[a * 64] == '.' && pt_txt[a * 64 + 1] == 'a' && pt_txt[a * 64 + 6] == ' ' && pt_txt[a * 64 + 7] == '1' && pt_txt[a * 64 + 8] == '6' && pt_txt[a * 64 + 9] == 0 {
            bool room = true;
            i64 used = 0;
            while used < 8 && pt_txt[(a - 8 + used) * 64] != 0 { used += 1; }
            i64 e = used;
            while e < 8 { if pt_txt[(a - 8 + e) * 64] != 0 { room = false; } e += 1; }
            if used >= 8 { room = false; }
            i64 lab = pt_next(a);
            if room && lab >= 0 && pt_txt[lab * 64] == 'L' {
                i64 v = 0;
                i64 k = 1;
                while pt_txt[lab * 64 + k] >= '0' && pt_txt[lab * 64 + k] <= '9' {
                    v = v * 10 + (pt_txt[lab * 64 + k] - '0');
                    k += 1;
                }
                if pt_txt[lab * 64 + k] == ':' && k > 1 {
                    i64 refs = 0;
                    i64 jj = 0 - 1;
                    i64 z = 0;
                    while z < pt_n {
                        if pt_parse(0, z) && pt_target_num(0) == v {
                            refs += 1;
                            if pt_is_branch(0) { jj = z; } else { refs += 5; }
                        }
                        z += 1;
                    }
                    if refs == 1 && jj > lab {
                        if pt_hoist_loop(a, lab, jj, used) { any = true; }
                        if pt_far_loop(a, lab, jj) { any = true; }
                    }
                }
            }
        }
        a += 1;
    }
    return any;
}

// add xA, xB, xI (, lsl #k) ... str vS, [xA, #0]   ->   str vS, [xB, xI (, lsl #k)]   when xA is not needed after the store
bool pt_addstr(i64 i) {
    if !pt_parse(0, i) || !pt_mn(0, "add") || pt_no[0] < 3 || pt_no[0] > 4 { return false; }
    i64 ra = pt_regno(0, 0, 'x');
    i64 rb = pt_regno(0, 1, 'x');
    i64 ri = pt_regno(0, 2, 'x');
    if ra < 0 || rb < 0 || ri < 0 || ra == rb || ra == ri { return false; }
    i64 sh = 0;
    if pt_no[0] == 4 {
        i64 o3 = (0 * 4 + 3) * 40;
        if !(pt_o[o3] == 'l' && pt_o[o3 + 1] == 's' && pt_o[o3 + 2] == 'l' && pt_o[o3 + 3] == ' ' && pt_o[o3 + 4] == '#' && pt_o[o3 + 5] >= '0' && pt_o[o3 + 5] <= '3' && pt_o[o3 + 6] == 0) { return false; }
        sh = pt_o[o3 + 5] - '0';
    }
    i64 j = pt_next(i);
    i64 steps = 0;
    while j >= 0 && steps < 8 {
        if !pt_parse(1, j) { return false; }
        if pt_is_branch(1) || pt_mn(1, "bl") || pt_mn(1, "blr") { return false; }
        if (pt_mn(1, "str") || pt_mn(1, "strb") || pt_mn(1, "strh")) && pt_no[1] == 2 && pt_zero_off(1, 1) && pt_base_reg(1, 1) == ra && !pt_rd(1, 0, ra) {
            i64 rv = pt_reg_of(1, 0);
            if rv < 0 { return false; }
            i64 need = 0;
            if pt_mn(1, "str") { need = 2; if pt_o[(1 * 4 + 0) * 40] == 'd' || pt_o[(1 * 4 + 0) * 40] == 'x' { need = 3; } }
            if pt_mn(1, "strh") { need = 1; }
            if pt_mn(1, "strb") { need = 0; }
            if need != sh { return false; }
            if !pt_dead(pt_next(j), ra, 40) { return false; }
            // build the new store
            i64 n = 0;
            char^ mn = "str";
            if pt_mn(1, "strb") { mn = "strb"; }
            if pt_mn(1, "strh") { mn = "strh"; }
            i64 c = 0;
            while mn[c] != 0 { pt_line[n] = mn[c]; n += 1; c += 1; }
            pt_line[n] = ' '; n += 1;
            i64 o0 = (1 * 4 + 0) * 40;
            c = 0;
            while pt_o[o0 + c] != 0 { pt_line[n] = pt_o[o0 + c]; n += 1; c += 1; }
            pt_line[n] = ','; n += 1; pt_line[n] = ' '; n += 1; pt_line[n] = '['; n += 1;
            i64 o1 = (0 * 4 + 1) * 40;
            c = 0;
            while pt_o[o1 + c] != 0 { pt_line[n] = pt_o[o1 + c]; n += 1; c += 1; }
            pt_line[n] = ','; n += 1; pt_line[n] = ' '; n += 1;
            i64 o2 = (0 * 4 + 2) * 40;
            c = 0;
            while pt_o[o2 + c] != 0 { pt_line[n] = pt_o[o2 + c]; n += 1; c += 1; }
            if pt_no[0] == 4 {
                pt_line[n] = ','; n += 1; pt_line[n] = ' '; n += 1;
                i64 o3b = (0 * 4 + 3) * 40;
                c = 0;
                while pt_o[o3b + c] != 0 { pt_line[n] = pt_o[o3b + c]; n += 1; c += 1; }
            }
            pt_line[n] = ']'; n += 1;
            pt_line[n] = 0;
            pt_set(j, (char^)@pt_line);
            pt_set(i, "");
            return true;
        }
        // anything in between must not change xB or xI, nor touch xA
        if pt_wr(1, rb) || pt_wr(1, ri) || pt_mentions(1, ra) { return false; }
        j = pt_next(j);
        steps += 1;
    }
    return false;
}

// shorten the function that was just written to regs_buf[start ..]
void regs_post(i64 start) {
    // the lines, and the labels
    i64 n = 0;
    i64 p = start;
    bool fits = true;
    rg_nlab = 0;
    while p < regs_len && fits {
        i64 e = p;
        while regs_buf[e] != 10 { e += 1; }
        if e - p > 62 || n >= 65535 {
            fits = false;
        } else {
            if opt_hoist != 0 && e - p == 9 && regs_buf[p] == '.' && regs_buf[p + 1] == 'a' && regs_buf[p + 7] == '1' && regs_buf[p + 8] == '6' && n < 65000 {
                i64 pd = 0;
                while pd < 8 {
                    pt_txt[n * 64] = 0;
                    n += 1;
                    pd += 1;
                }
            }
            i64 c = 0;
            while p + c < e {
                pt_txt[n * 64 + c] = regs_buf[p + c];
                c += 1;
            }
            pt_txt[n * 64 + c] = 0;
            if regs_buf[p] == 'L' && regs_buf[p + 1] >= '0' && regs_buf[p + 1] <= '9' && regs_buf[e - 1] == ':' && rg_nlab < 8192 {
                i64 v = 0;
                i64 q = p + 1;
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
    rg_nofma_fn = 0;
    if n > 0 && nofma_has(@pt_txt) { rg_nofma_fn = 1; }
    pt_pushpop();
    i64 changed = 1;
    i64 rounds = 0;
    i64 hoisted = 0;
    while changed == 1 && rounds < 12 {
        changed = 0;
        if pt_mirror() { changed = 1; }
        i64 i = 0;
        while i < pt_n {
            if pt_txt[i * 64] != 0 {
                if pt_rules(i) { changed = 1; } else if pt_addstr(i) { changed = 1; }
            }
            i += 1;
        }
        rounds += 1;
        if changed == 0 && hoisted < 5 {
            hoisted += 1;
            if pt_hoist() { changed = 1; }
        }
    }
    regs_len = start;
    i64 i2 = 0;
    while i2 < pt_n {
        if pt_txt[i2 * 64] != 0 {
            i64 c2 = 0;
            while pt_txt[i2 * 64 + c2] != 0 {
                rg_put(pt_txt[i2 * 64 + c2]);
                c2 += 1;
            }
            rg_put(10);
        }
        i2 += 1;
    }
}
