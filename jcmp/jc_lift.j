// jc_lift.j -- from the assembler text of a function to the IR (jc_ir.j) and back (design: docs/design/03-ir.md).
//
// The compiler writes its code as ARM64 text. This file reads the text of a function ("lifts" it) into a first form of the IR in which the
// virtual registers ARE the registers of the machine: x0..x30 are the vregs 1..31, d0..d31 the vregs 32..63 (the vregs from 64 on are temporaries).
// Every line becomes one or a few IR instructions; the stack temporaries ([sp, #n]) become loads and stores at a fixed place of the frame
// (the depth of the stack is followed while reading); a comparison and the jump that uses it become one IR jump. Only the functions
// that the lifter understands completely are lifted (a function with an unknown instruction is left as it is).
//
// "Lowering" writes the IR back as text. With -irtrip every function that can be lifted is lifted and lowered again, and the program must
// behave as before: this is how the lifter is tested. The next steps (docs/design/03-ir.md) rename the machine registers to real virtual
// registers, run passes on the IR and allocate registers.

char lf_why[100];                 // why the last function could not be lifted
int lf_frame;                     // the size of the frame that the prologue made
int lf_lifted;                    // counts, for -irstat
int lf_failed;
int lf_blab[8192];                // the labels of the function: their numbers and the block that each one starts
int lf_blk[8192];
int lf_nlab;
int lf_leader[65536];             // 1: the line starts a block (and the number of the block, from 1)
int lf_depth_at[IR_MAXB];         // the depth of the stack at the start of each block (-1: not known yet)
int lf_depth;                     // the depth of the stack now (bytes below the frame pointer)
int lf_cmp_kind;                  // the comparison that is waiting for its jump: 1 whole numbers, 2 doubles, 0 none
int lf_cmp_a;
int lf_cmp_b;
int lf_cmp_bi;
int lf_epi_line;                  // the line where the epilogue starts (-1: none, a program that ends with a system call)
int lf_epi_len;                   // how many lines the epilogue has
char lf_epi_text[1024];           // the epilogue as it was written, to be used again by the lowering
int lf_epi_n;
int lf_body_start;                // the first line after the prologue
int lf_fp;                        // the vreg of the frame pointer (x29)
int lf_head_n;                    // the lines before the body (the prologue), as text
char lf_head_text[512];

int lf_fail(char^ why) {
    str_copy(@lf_why, why, 100);
    return 0;
}

// the same, with the text of the line that was not understood
int lf_fail_line(char^ why, int idx) {
    str_copy(@lf_why, why, 100);
    int n = str_len(@lf_why);
    if n < 60 {
        lf_why[n] = ':';
        lf_why[n + 1] = ' ';
        int k = 0;
        while pt_txt[idx * 64 + k] != 0 && n + 2 + k < 98 {
            lf_why[n + 2 + k] = pt_txt[idx * 64 + k];
            k += 1;
        }
        lf_why[n + 2 + k] = 0;
    }
    return 0;
}

// the vreg of the machine register x<n> / d<n>
int lf_x(int n) {
    return n + 1;
}

int lf_d(int n) {
    return 32 + n;
}

// a number written as  #12  12  -12  #-12  at the operand (s, k): lf_val, true if it is one
int lf_val;
bool lf_imm(int s, int k) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] { return false; }
    int i = 0;
    if pt_o[o] == '#' { i = 1; }
    bool neg = false;
    if pt_o[o + i] == '-' {
        neg = true;
        i += 1;
    }
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    int v = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        v = v * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if pt_o[o + i] != 0 { return false; }
    if neg { v = 0 - v; }
    lf_val = v;
    return true;
}

// a memory operand  [xB, #N]  or  [xB]  or  [sp, #N]: lf_mbase (0..30, 31 = sp) and lf_moff
int lf_mbase;
int lf_moff;
bool lf_mem(int s, int k) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != '[' { return false; }
    int i = 1;
    if pt_o[o + i] == 's' && pt_o[o + i + 1] == 'p' {
        lf_mbase = 31;
        i += 2;
    } else if pt_o[o + i] == 'x' && pt_o[o + i + 1] >= '0' && pt_o[o + i + 1] <= '9' {
        i += 1;
        int v = 0;
        while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
            v = v * 10 + (pt_o[o + i] - '0');
            i += 1;
        }
        lf_mbase = v;
    } else {
        return false;
    }
    lf_moff = 0;
    if pt_o[o + i] == ']' { return pt_o[o + i + 1] == 0; }
    if pt_o[o + i] != ',' { return false; }
    i += 1;
    while pt_o[o + i] == ' ' { i += 1; }
    if pt_o[o + i] == '#' { i += 1; }
    bool neg = false;
    if pt_o[o + i] == '-' {
        neg = true;
        i += 1;
    }
    if pt_o[o + i] < '0' || pt_o[o + i] > '9' { return false; }
    int n = 0;
    while pt_o[o + i] >= '0' && pt_o[o + i] <= '9' {
        n = n * 10 + (pt_o[o + i] - '0');
        i += 1;
    }
    if neg { n = 0 - n; }
    if pt_o[o + i] != ']' || pt_o[o + i + 1] != 0 { return false; }
    lf_moff = n;
    return true;
}

// the number of a label "L123" at the operand (s, k), or -1
int lf_label_of(int s, int k) {
    int o = (s * 4 + k) * 40;
    if k >= pt_no[s] || pt_o[o] != 'L' { return 0 - 1; }
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

// the block that the label number starts, or -1
int lf_block_of_label(int num) {
    int i = 0;
    while i < lf_nlab {
        if lf_blab[i] == num { return lf_blk[i]; }
        i += 1;
    }
    return 0 - 1;
}

// is the line (a parsed slot s) a jump or call that does not return? (the helpers of the runtime that stop the program)
bool lf_noreturn(char^ name) {
    return str_eq(name, "j2k_divzero") || str_eq(name, "j2k_oob") || str_eq(name, "j2k_noret") || str_eq(name, "__panic") || str_eq(name, "j2k_uncaught");
}

// the condition of a b.cc: the IR condition, or -1 (float: the same names, see below)
int lf_cc(char^ cc, int is_float) {
    if str_eq(cc, "eq") { return IR_EQ; }
    if str_eq(cc, "ne") { return IR_NE; }
    if is_float == 1 {
        if str_eq(cc, "mi") { return IR_LT; }
        if str_eq(cc, "ls") { return IR_LE; }
        if str_eq(cc, "gt") { return IR_GT; }
        if str_eq(cc, "ge") { return IR_GE; }
        return 0 - 1;
    }
    if str_eq(cc, "lt") { return IR_LT; }
    if str_eq(cc, "le") { return IR_LE; }
    if str_eq(cc, "gt") { return IR_GT; }
    if str_eq(cc, "ge") { return IR_GE; }
    if str_eq(cc, "lo") { return IR_ULT; }
    if str_eq(cc, "ls") { return IR_ULE; }
    if str_eq(cc, "hi") { return IR_UGT; }
    if str_eq(cc, "hs") { return IR_UGE; }
    return 0 - 1;
}

// the lines of the function out_buf[st .. en) go to pt_txt (64 bytes each); false if a line is too long
bool lf_load(int st, int en) {
    int n = 0;
    int p = st;
    lf_hint_n = 0;
    while p < en {
        int e = p;
        while out_buf[e] != 10 { e += 1; }
        if out_buf[p] == ';' && out_buf[p + 1] == 'H' {
            // the hint line (long): kept for the register pass
            int hc = p;
            while hc < e && lf_hint_n < 16000 {
                lf_hint_text[lf_hint_n] = out_buf[hc];
                lf_hint_n += 1;
                hc += 1;
            }
            pt_txt[n * 64] = ';';
            pt_txt[n * 64 + 1] = 'H';
            pt_txt[n * 64 + 2] = 0;
            n += 1;
            p = e + 1;
            continue;
        }
        if e - p > 62 || n >= 65000 { return false; }
        int c = 0;
        while p + c < e {
            pt_txt[n * 64 + c] = out_buf[p + c];
            c += 1;
        }
        pt_txt[n * 64 + c] = 0;
        n += 1;
        p = e + 1;
    }
    pt_n = n;
    return true;
}

// does the line idx of pt_txt start with the text t?
bool lf_starts(int idx, char^ t) {
    int b = idx * 64;
    int i = 0;
    while t[i] != 0 {
        if pt_txt[b + i] != t[i] { return false; }
        i += 1;
    }
    return true;
}

// is the line a label "L<number>:" ? then the number, else -1
int lf_label_line(int idx) {
    int b = idx * 64;
    if pt_txt[b] != 'L' { return 0 - 1; }
    int i = 1;
    if pt_txt[b + i] < '0' || pt_txt[b + i] > '9' { return 0 - 1; }
    int v = 0;
    while pt_txt[b + i] >= '0' && pt_txt[b + i] <= '9' {
        v = v * 10 + (pt_txt[b + i] - '0');
        i += 1;
    }
    if pt_txt[b + i] != ':' || pt_txt[b + i + 1] != 0 { return 0 - 1; }
    return v;
}

// the registers that the compare of the line (a, b) uses: is one of them written by the lines between the comparison at idx and the
// jump that uses it? (then the comparison works on copies)
bool lf_cmp_clobbered(int idx, int ra, int rb) {
    int j = idx + 1;
    int guard = 0;
    while j < pt_n && guard < 6 {
        guard += 1;
        if lf_label_line(j) >= 0 { return false; }
        if !pt_parse(1, j) { return false; }
        if pt_mn(1, "b.eq") || pt_m[16] == 'b' && pt_m[17] == '.' { return false; }
        if pt_no[1] >= 1 && pt_writes_first(1) && pt_isreg(1, 0) {
            int w = pt_regno(1, 0, 'x');
            if w == ra || w == rb { return true; }
        }
        j += 1;
    }
    return false;
}

// ---------------------------------------------------------------------------------------------- the lifter

// instructions with the vregs of the machine registers
int lf_emit(int op, int d, int a, int b, int bi, int k) {
    return ir_add(op, d, a, b, bi, k);
}

// one line of the body; returns 0 if it could not be understood (lf_why says what)
int lf_line(int idx) {
    if !pt_parse(0, idx) { return 1; }
    int fp = lf_fp;
    if pt_no[0] >= 1 && pt_isreg(0, 0) && pt_writes_first(0) {
        int wr = pt_regno(0, 0, 'x');
        if wr == 27 || wr == 28 || wr == 29 { return lf_fail("a write to x27, x28 or x29"); }
    }
    // sub sp, sp, #N / add sp, sp, #N
    if (pt_mn(0, "sub") || pt_mn(0, "add")) && pt_no[0] == 3 && pt_op(0, 0, "sp") {
        if !pt_op(0, 1, "sp") || !lf_imm(0, 2) { return lf_fail("a use of sp that is not a push or a pop"); }
        if pt_mn(0, "sub") { lf_depth += lf_val; } else { lf_depth -= lf_val; }
        if lf_depth < 0 { return lf_fail("the stack went above the frame"); }
        return 1;
    }
    if pt_mn(0, "add") && pt_no[0] == 3 && pt_isreg(0, 0) && pt_op(0, 1, "sp") {
        return lf_fail("the address of something on the stack (add xN, sp, #K)");
    }
    if pt_mn(0, "mov") && pt_no[0] == 2 && pt_isreg(0, 0) {
        int d = lf_x(pt_regno(0, 0, 'x'));
        if pt_op(0, 1, "sp") { return lf_fail("mov xN, sp"); }
        if pt_isreg(0, 1) {
            lf_emit(IR_COPY, d, lf_x(pt_regno(0, 1, 'x')), 0, 0, 0);
            return 1;
        }
        if lf_imm(0, 1) {
            lf_emit(IR_CONST, d, 0, 0, 0, lf_val);
            return 1;
        }
        return lf_fail_line("mov", idx);
    }
    // the three-operand arithmetic: add sub mul sdiv udiv and orr eor lsl lsr asr (register or number as the last operand)
    int op = 0;
    if pt_mn(0, "add") { op = IR_ADD; }
    else if pt_mn(0, "sub") { op = IR_SUB; }
    else if pt_mn(0, "mul") { op = IR_MUL; }
    else if pt_mn(0, "sdiv") { op = IR_SDIV; }
    else if pt_mn(0, "udiv") { op = IR_UDIV; }
    else if pt_mn(0, "and") { op = IR_AND; }
    else if pt_mn(0, "orr") { op = IR_OR; }
    else if pt_mn(0, "eor") { op = IR_XOR; }
    else if pt_mn(0, "lsl") { op = IR_SHL; }
    else if pt_mn(0, "lsr") { op = IR_LSHR; }
    else if pt_mn(0, "asr") { op = IR_ASHR; }
    else if pt_mn(0, "smulh") { op = IR_MULHS; }
    else if pt_mn(0, "ror") { op = IR_ROTR; }
    if op != 0 {
        if pt_no[0] != 3 || !pt_isreg(0, 0) || !pt_isreg(0, 1) { return lf_fail("arithmetic with an operand that is not understood"); }
        int dd = lf_x(pt_regno(0, 0, 'x'));
        int aa = lf_x(pt_regno(0, 1, 'x'));
        if pt_isreg(0, 2) {
            lf_emit(op, dd, aa, lf_x(pt_regno(0, 2, 'x')), 0, 0);
            return 1;
        }
        if lf_imm(0, 2) && op != IR_MUL && op != IR_SDIV && op != IR_UDIV && op != IR_MULHS {
            lf_emit(op, dd, aa, lf_val, 1, 0);
            return 1;
        }
        return lf_fail("arithmetic with a last operand that is not understood");
    }
    if (pt_mn(0, "msub") || pt_mn(0, "madd")) && pt_no[0] == 4 && pt_isreg(0, 0) && pt_isreg(0, 1) && pt_isreg(0, 2) && pt_isreg(0, 3) {
        // d = a -/+ n * m
        int t = ir_vreg(0);
        lf_emit(IR_MUL, t, lf_x(pt_regno(0, 1, 'x')), lf_x(pt_regno(0, 2, 'x')), 0, 0);
        if pt_mn(0, "msub") {
            lf_emit(IR_SUB, lf_x(pt_regno(0, 0, 'x')), lf_x(pt_regno(0, 3, 'x')), t, 0, 0);
        } else {
            lf_emit(IR_ADD, lf_x(pt_regno(0, 0, 'x')), lf_x(pt_regno(0, 3, 'x')), t, 0, 0);
        }
        return 1;
    }
    if (pt_mn(0, "clz") || pt_mn(0, "rbit") || pt_mn(0, "rev") || pt_mn(0, "popcnt")) && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) {
        int opb = IR_CLZ;
        if pt_mn(0, "rbit") { opb = IR_RBIT; }
        if pt_mn(0, "rev") { opb = IR_BSWAP; }
        if pt_mn(0, "popcnt") { opb = IR_POPCNT; }
        lf_emit(opb, lf_x(pt_regno(0, 0, 'x')), lf_x(pt_regno(0, 1, 'x')), 0, 0, 0);
        return 1;
    }
    if (pt_mn(0, "neg") || pt_mn(0, "mvn")) && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) {
        int opn = IR_NEG;
        if pt_mn(0, "mvn") { opn = IR_NOT; }
        lf_emit(opn, lf_x(pt_regno(0, 0, 'x')), lf_x(pt_regno(0, 1, 'x')), 0, 0, 0);
        return 1;
    }
    if (pt_mn(0, "sxtb") || pt_mn(0, "sxth") || pt_mn(0, "sxtw") || pt_mn(0, "uxtb") || pt_mn(0, "uxth") || pt_mn(0, "uxtw")) && pt_no[0] == 2 && pt_isreg(0, 0) && pt_isreg(0, 1) {
        int bits = 8;
        if pt_m[3] == 'h' { bits = 16; }
        if pt_m[3] == 'w' { bits = 32; }
        int e = lf_emit(IR_EXT, lf_x(pt_regno(0, 0, 'x')), lf_x(pt_regno(0, 1, 'x')), 0, 0, bits);
        if pt_m[0] == 's' { ir_w[e] = 1; }
        return 1;
    }
    // memory
    int width = 0;
    bool is_load = false;
    if pt_mn(0, "ldr") { width = 8; is_load = true; }
    else if pt_mn(0, "ldrb") { width = 1; is_load = true; }
    else if pt_mn(0, "ldrh") { width = 2; is_load = true; }
    else if pt_mn(0, "ldrw") { width = 4; is_load = true; }
    else if pt_mn(0, "ldrsb") { width = 0 - 1; is_load = true; }
    else if pt_mn(0, "ldrsh") { width = 0 - 2; is_load = true; }
    else if pt_mn(0, "ldrsw") { width = 0 - 4; is_load = true; }
    else if pt_mn(0, "str") { width = 8; }
    else if pt_mn(0, "strb") { width = 1; }
    else if pt_mn(0, "strh") { width = 2; }
    else if pt_mn(0, "strw") { width = 4; }
    if width != 0 {
        if pt_no[0] != 2 || !lf_mem(0, 1) { return lf_fail_line("memory access", idx); }
        int vr = 0;
        if pt_isreg(0, 0) {
            vr = lf_x(pt_regno(0, 0, 'x'));
        } else if pt_regno(0, 0, 'd') >= 0 {
            vr = lf_d(pt_regno(0, 0, 'd'));
            if width != 8 { return lf_fail("a double that is not 8 bytes"); }
        } else {
            return lf_fail("a memory access with a register that is not understood");
        }
        int base = 0;
        int off = lf_moff;
        if lf_mbase == 29 && lf_moff >= lf_frame { return lf_fail("reads an argument that was passed on the stack (more than 8 arguments)"); }
        if lf_mbase == 31 {
            base = fp;
            off = lf_moff - lf_depth;
        } else {
            base = lf_x(lf_mbase);
        }
        if is_load {
            int e = lf_emit(IR_LOAD, vr, base, 0, 0, off);
            ir_w[e] = width;
        } else {
            int e2 = lf_emit(IR_STORE, 0, base, vr, 0, off);
            ir_w[e2] = width;
        }
        return 1;
    }
    // comparisons: the jump that uses them takes the values
    if pt_mn(0, "cmp") && pt_no[0] == 2 && pt_isreg(0, 0) {
        int ra = pt_regno(0, 0, 'x');
        int rb = 0 - 1;
        bool bimm = false;
        int immv = 0;
        if pt_isreg(0, 1) { rb = pt_regno(0, 1, 'x'); }
        else if lf_imm(0, 1) { bimm = true; immv = lf_val; }
        else { return lf_fail("cmp with an operand that is not understood"); }
        lf_cmp_kind = 1;
        lf_cmp_a = lf_x(ra);
        if lf_cmp_clobbered(idx, ra, rb) {
            int ta = ir_vreg(0);
            lf_emit(IR_COPY, ta, lf_x(ra), 0, 0, 0);
            lf_cmp_a = ta;
            if rb >= 0 {
                int tb = ir_vreg(0);
                lf_emit(IR_COPY, tb, lf_x(rb), 0, 0, 0);
                lf_cmp_b = tb;
            }
        } else if rb >= 0 {
            lf_cmp_b = lf_x(rb);
        }
        if bimm {
            lf_cmp_bi = 1;
            lf_cmp_b = immv;
        } else {
            lf_cmp_bi = 0;
        }
        return 1;
    }
    if pt_mn(0, "fcmp") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 {
        lf_cmp_kind = 2;
        lf_cmp_a = lf_d(pt_regno(0, 0, 'd'));
        lf_cmp_b = lf_d(pt_regno(0, 1, 'd'));
        lf_cmp_bi = 0;
        // the registers are copied: the lines in between may write them
        int fa = ir_vreg(1);
        int fb = ir_vreg(1);
        lf_emit(IR_COPY, fa, lf_cmp_a, 0, 0, 0);
        lf_emit(IR_COPY, fb, lf_cmp_b, 0, 0, 0);
        lf_cmp_a = fa;
        lf_cmp_b = fb;
        return 1;
    }
    // doubles
    if pt_mn(0, "fmov") && pt_no[0] == 2 {
        if pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'd') >= 0 {
            lf_emit(IR_COPY, lf_d(pt_regno(0, 0, 'd')), lf_d(pt_regno(0, 1, 'd')), 0, 0, 0);
            return 1;
        }
        if pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'x') >= 0 {
            lf_emit(IR_BITS2F, lf_d(pt_regno(0, 0, 'd')), lf_x(pt_regno(0, 1, 'x')), 0, 0, 0);
            return 1;
        }
        if pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 {
            lf_emit(IR_F2BITS, lf_x(pt_regno(0, 0, 'x')), lf_d(pt_regno(0, 1, 'd')), 0, 0, 0);
            return 1;
        }
        return lf_fail("a float of 32 bits (fmov with s or w registers)");
    }
    int lfop = 0;
    if pt_mn(0, "fadd") { lfop = IR_FADD; }
    else if pt_mn(0, "fsub") { lfop = IR_FSUB; }
    else if pt_mn(0, "fmul") { lfop = IR_FMUL; }
    else if pt_mn(0, "fdiv") { lfop = IR_FDIV; }
    if lfop != 0 {
        if pt_no[0] != 3 || pt_regno(0, 0, 'd') < 0 || pt_regno(0, 1, 'd') < 0 || pt_regno(0, 2, 'd') < 0 { return lf_fail("a float of 32 bits"); }
        lf_emit(lfop, lf_d(pt_regno(0, 0, 'd')), lf_d(pt_regno(0, 1, 'd')), lf_d(pt_regno(0, 2, 'd')), 0, 0);
        return 1;
    }
    int lfop1 = 0;
    if pt_mn(0, "fsqrt") { lfop1 = IR_FSQRT; }
    else if pt_mn(0, "fneg") { lfop1 = IR_FNEG; }
    else if pt_mn(0, "fabs") { lfop1 = IR_FABS; }
    else if pt_mn(0, "frintm") { lfop1 = IR_FFLOOR; }
    else if pt_mn(0, "frintz") { lfop1 = IR_FTRUNC; }
    else if pt_mn(0, "frintp") { lfop1 = IR_FCEIL; }
    if lfop1 != 0 {
        if pt_no[0] != 2 || pt_regno(0, 0, 'd') < 0 || pt_regno(0, 1, 'd') < 0 { return lf_fail("a float of 32 bits"); }
        lf_emit(lfop1, lf_d(pt_regno(0, 0, 'd')), lf_d(pt_regno(0, 1, 'd')), 0, 0, 0);
        return 1;
    }
    if pt_mn(0, "scvtf") && pt_no[0] == 2 && pt_regno(0, 0, 'd') >= 0 && pt_regno(0, 1, 'x') >= 0 {
        lf_emit(IR_I2F, lf_d(pt_regno(0, 0, 'd')), lf_x(pt_regno(0, 1, 'x')), 0, 0, 0);
        return 1;
    }
    if pt_mn(0, "fcvtzs") && pt_no[0] == 2 && pt_regno(0, 0, 'x') >= 0 && pt_regno(0, 1, 'd') >= 0 {
        lf_emit(IR_F2I, lf_x(pt_regno(0, 0, 'x')), lf_d(pt_regno(0, 1, 'd')), 0, 0, 0);
        return 1;
    }
    // addresses of functions
    if pt_mn(0, "adr") && pt_no[0] == 2 && pt_isreg(0, 0) {
        if lf_label_of(0, 1) >= 0 { return lf_fail("the address of a label inside the function (a defer)"); }
        char nm[64];
        int o = (0 * 4 + 1) * 40;
        int c = 0;
        while pt_o[o + c] != 0 && c < 62 {
            nm[c] = pt_o[o + c];
            c += 1;
        }
        nm[c] = 0;
        lf_emit(IR_ADDR_FUNC, lf_x(pt_regno(0, 0, 'x')), 0, 0, 0, ir_name_index(@nm));
        return 1;
    }
    return lf_fail_line("not understood", idx);
}

// the arguments of every call: x0..x7 (what the callee reads is not known here)
int lf_args[8];
void lf_set_call_args(int e) {
    int k = 0;
    while k < 8 {
        lf_args[k] = lf_x(k);
        k += 1;
    }
    ir_set_args(e, 8, @lf_args);
}

// lift the function that is in pt_txt[0 .. pt_n): 1 if it worked, else 0 and the reason in lf_why
int lf_total;                         // the lines of the body end here (the epilogue is not part of it)
int lf_nblocks;

// the first pass: which lines start a block
int lf_find_blocks() {
    lf_nlab = 0;
    int i = lf_body_start;
    int nblocks = 0;
    bool open = false;                // the block that is being made has an instruction already
    bool need_new = false;            // the line before ended a block
    int li = 0;
    while li < pt_n {
        lf_leader[li] = 0;
        li += 1;
    }
    while i < lf_total {
        if lf_starts(i, ";H") {
            i += 1;
            continue;
        }
        int lab = lf_label_line(i);
        if lab >= 0 {
            if nblocks == 0 || open || need_new {
                nblocks += 1;
                lf_leader[i] = nblocks;
                open = false;
                need_new = false;
            }
            if lf_nlab >= 8190 { return lf_fail("too many labels"); }
            lf_blab[lf_nlab] = lab;
            lf_blk[lf_nlab] = nblocks - 1;
            lf_nlab += 1;
        } else {
            if nblocks == 0 || need_new {
                nblocks += 1;
                lf_leader[i] = nblocks;
                need_new = false;
            }
            open = true;
            if !pt_parse(0, i) { return lf_fail("a line that is not understood"); }
            bool ends = false;
            if pt_m[0] == 'b' && pt_m[1] == '.' { ends = true; }
            if pt_mn(0, "b") || pt_mn(0, "ret") { ends = true; }
            if pt_mn(0, "bl") && pt_no[0] == 1 && lf_noreturn(@pt_o) { ends = true; }
            if pt_mn(0, "svc") { ends = true; }
            if ends {
                need_new = true;
                open = false;
            }
        }
        i += 1;
    }
    lf_nblocks = nblocks;
    return 1;
}

int lf_function(char^ name) {
    lf_why[0] = 0;
    // the prologue: name: / sub sp, sp, #N / str x29, [sp, #0] / str x30, [sp, #8] / add x29, sp, #0
    if pt_n < 8 || !lf_starts(1, "sub sp, sp, #") || !lf_starts(2, "str x29, [sp, #0]") || !lf_starts(3, "str x30, [sp, #8]") || !lf_starts(4, "add x29, sp, #0") {
        return lf_fail("the function does not start with the usual prologue");
    }
    lf_body_start = 5;
    lf_frame = 0;
    int pi = 13;
    while pt_txt[64 + pi] >= '0' && pt_txt[64 + pi] <= '9' {
        lf_frame = lf_frame * 10 + (pt_txt[64 + pi] - '0');
        pi += 1;
    }
    // the end: the epilogue (ldr x29, ldr x30, add sp, ret) or, in main, the exit call
    int last = pt_n - 1;
    while last >= 0 && lf_starts(last, ";H") { last -= 1; }
    lf_epi_line = 0 - 1;
    if lf_starts(last, "ret") && last >= 8 && lf_starts(last - 1, "add sp, sp, #") && lf_starts(last - 2, "ldr x30, [sp, #8]") && lf_starts(last - 3, "ldr x29, [sp, #0]") {
        lf_epi_line = last - 3;
    }
    if lf_epi_line >= 0 { lf_total = lf_epi_line; } else { lf_total = last + 1; }
    if lf_find_blocks() == 0 { return 0; }
    int nblocks = lf_nblocks;
    if nblocks == 0 { return lf_fail("no code"); }
    if nblocks > IR_MAXB - 4 { return lf_fail("too many blocks"); }
    ir_reset(name);
    ir_nv = 64;
    int cv = 1;
    while cv < 32 {
        ir_vcls[cv] = 0;
        cv += 1;
    }
    while cv < 64 {
        ir_vcls[cv] = 1;
        cv += 1;
    }
    lf_fp = lf_x(29);
    lf_depth = 0;
    lf_cmp_kind = 0;
    int bi = 0;
    while bi < nblocks {
        lf_depth_at[bi] = 0 - 1;
        bi += 1;
    }
    int cur = 0 - 1;
    int i = lf_body_start;
    bool fell = true;                     // the flow can come from the line above
    while i < lf_total {
        if lf_starts(i, ";H") {
            i += 1;
            continue;
        }
        int ldr = lf_leader[i];
        if ldr > 0 {
            int nb = ir_nb;
            if nb != ldr - 1 { return lf_fail("internal error: blocks out of order"); }
            if cur >= 0 && fell {
                if lf_depth_at[nb] >= 0 && lf_depth_at[nb] != lf_depth { return lf_fail("the depth of the stack is not the same at a join"); }
                int j = ir_add(IR_JMP, 0, 0, 0, 0, 0);
                ir_t1[j] = nb;
            }
            ir_new_block(0 - 1);
            ir_set_block(nb);
            cur = nb;
            if lf_depth_at[nb] >= 0 && !fell { lf_depth = lf_depth_at[nb]; }
            if lf_depth_at[nb] < 0 { lf_depth_at[nb] = lf_depth; }
            if nb == 0 {
                int pk = 0;
                while pk < 8 {
                    ir_add(IR_PARAM, lf_x(pk), 0, 0, 0, pk);
                    pk += 1;
                }
                ir_add(IR_ADDR_SLOT, lf_fp, 0, 0, 0, 0);
            }
            fell = true;
            lf_cmp_kind = 0;
        }
        if lf_label_line(i) >= 0 {
            i += 1;
            continue;
        }
        if cur < 0 { return lf_fail("code before the first block"); }
        if !pt_parse(0, i) { return lf_fail("a line that is not understood"); }
        if pt_m[0] == 'b' && pt_m[1] == '.' {
            if lf_cmp_kind == 0 { return lf_fail("a conditional jump without a comparison"); }
            char cc[8];
            cc[0] = pt_m[2];
            cc[1] = pt_m[3];
            cc[2] = 0;
            int ccn = lf_cc(@cc, lf_cmp_kind - 1);
            if ccn < 0 { return lf_fail("a condition that is not understood"); }
            int target = lf_label_of(0, 0);
            if target < 0 { return lf_fail("a conditional jump to something that is not a label"); }
            int tb = lf_block_of_label(target);
            if tb < 0 { return lf_fail("a jump to a label that was not found"); }
            int nxt = cur + 1;
            if nxt >= nblocks { return lf_fail("a conditional jump at the end of the function"); }
            int opj = IR_BR;
            if lf_cmp_kind == 2 { opj = IR_FBR; }
            int e = ir_add(opj, 0, lf_cmp_a, lf_cmp_b, lf_cmp_bi, ccn);
            ir_t1[e] = tb;
            ir_t2[e] = nxt;
            if lf_depth_at[tb] >= 0 && lf_depth_at[tb] != lf_depth { return lf_fail("the depth of the stack is not the same at a jump"); }
            lf_depth_at[tb] = lf_depth;
            if lf_depth_at[nxt] >= 0 && lf_depth_at[nxt] != lf_depth { return lf_fail("the depth of the stack is not the same at a jump"); }
            lf_depth_at[nxt] = lf_depth;
            fell = false;
            lf_cmp_kind = 0;
            i += 1;
            continue;
        }
        if pt_mn(0, "b") && pt_no[0] == 1 {
            int tg = lf_label_of(0, 0);
            if tg < 0 { return lf_fail("a jump to something that is not a label"); }
            int tb2 = lf_block_of_label(tg);
            if tb2 < 0 { return lf_fail("a jump to a label that was not found"); }
            int e2 = ir_add(IR_JMP, 0, 0, 0, 0, 0);
            ir_t1[e2] = tb2;
            if lf_depth_at[tb2] >= 0 && lf_depth_at[tb2] != lf_depth { return lf_fail("the depth of the stack is not the same at a jump"); }
            lf_depth_at[tb2] = lf_depth;
            fell = false;
            i += 1;
            continue;
        }
        if pt_mn(0, "bl") && pt_no[0] == 1 {
            if i + 1 < lf_total && lf_starts(i + 1, "add sp, sp, #") { return lf_fail("a call with arguments on the stack (more than 8)"); }
            char fn[64];
            int c = 0;
            while pt_o[c] != 0 && c < 62 {
                fn[c] = pt_o[c];
                c += 1;
            }
            fn[c] = 0;
            int ce = ir_add(IR_CALL, lf_x(0), 0, 0, 0, ir_name_index(@fn));
            lf_set_call_args(ce);
            if lf_noreturn(@fn) {
                ir_add(IR_TRAP, 0, 0, 0, 0, 0);
                fell = false;
            }
            lf_cmp_kind = 0;
            i += 1;
            continue;
        }
        if pt_mn(0, "blr") && pt_no[0] == 1 && pt_isreg(0, 0) {
            int ce2 = ir_add(IR_CALLIND, lf_x(0), lf_x(pt_regno(0, 0, 'x')), 0, 0, 0);
            lf_set_call_args(ce2);
            lf_cmp_kind = 0;
            i += 1;
            continue;
        }
        if pt_mn(0, "svc") {
            int se = ir_add(IR_SYSCALL, lf_x(0), lf_x(8), 0, 0, 0);
            lf_set_call_args(se);
            if i + 1 >= lf_total && lf_epi_line < 0 {
                ir_add(IR_TRAP, 0, 0, 0, 0, 0);
                fell = false;
            }
            lf_cmp_kind = 0;
            i += 1;
            continue;
        }
        if lf_line(i) == 0 { return 0; }
        i += 1;
    }
    // the end: the epilogue is a return of x0 (the flow that falls off the body goes there)
    if lf_epi_line >= 0 {
        if cur < 0 { return lf_fail("no code"); }
        if lf_depth != 0 && fell { return lf_fail("the stack is not empty at the end"); }
        ir_set_block(ir_nb - 1);
        if fell || ir_be[ir_nb - 1] == ir_bs[ir_nb - 1] {
            ir_add(IR_RET, 0, lf_x(0), 0, 0, 0);
        }
    } else {
        if fell { return lf_fail("the function does not end"); }
    }
    if ir_check() == 0 { return lf_fail(@ir_err); }
    ir_lastb = ir_nb - 1;
    return 1;
}


// ---------------------------------------------------------------------------------------------- the lowering (IR -> text)

int lw_lab[IR_MAXB];              // the label number of each block in the new text
int lw_tmp_i;                     // the temporaries (vregs from 64 on) get the scratch registers x15, x16 / d30, d31 in turn
int lw_tmp_reg[IR_MAXV];
int lw_maxq;                      // the deepest stack cell that the function used (bytes below the frame pointer)
int lw_cells[512];                // the frame offsets that the stack cells got (for the hint line)
int lw_ncells;

// the name of the register of a vreg: x5 / d3; a temporary gets a scratch register when it is written
void lw_reg(int v) {
    if v >= 1 && v <= 31 {
        rg_text("x");
        rg_int(v - 1);
    } else if v >= 32 && v <= 63 {
        rg_text("d");
        rg_int(v - 32);
    } else {
        int r = lw_tmp_reg[v];
        if ir_vcls[v] == 1 { rg_text("d"); } else { rg_text("x"); }
        rg_int(r);
    }
}

// a temporary that is written now gets the next scratch register
void lw_def(int v) {
    if v >= 64 {
        lw_tmp_i += 1;
        if ir_vcls[v] == 1 { lw_tmp_reg[v] = 30 + lw_tmp_i % 2; } else { lw_tmp_reg[v] = 15 + lw_tmp_i % 2; }
    }
}

// the second operand of an instruction: a register or a number
void lw_b(int i) {
    if ir_bi[i] == 1 {
        rg_text("#");
        rg_int(ir_b[i]);
    } else {
        lw_reg(ir_b[i]);
    }
}

// the offset of a memory access: a stack cell (negative, from the frame pointer) goes into the extra room after the frame
int lw_offset(int base, int off) {
    if base == 30 && off < 0 {
        lw_note_cell(lf_frame + lw_maxq + off);
        return lf_frame + lw_maxq + off;
    }
    return off;
}

// the text of the condition for b.cc
char^ lw_cc(int cc, int is_float) {
    if cc == IR_EQ { return "eq"; }
    if cc == IR_NE { return "ne"; }
    if is_float == 1 {
        if cc == IR_LT { return "mi"; }
        if cc == IR_LE { return "ls"; }
        if cc == IR_GT { return "gt"; }
        return "ge";
    }
    if cc == IR_LT { return "lt"; }
    if cc == IR_LE { return "le"; }
    if cc == IR_GT { return "gt"; }
    if cc == IR_GE { return "ge"; }
    if cc == IR_ULT { return "lo"; }
    if cc == IR_ULE { return "ls"; }
    if cc == IR_UGT { return "hi"; }
    return "hs";
}

// the opposite condition of a b.cc (also for the double compares: a not-a-number makes both "less than" and "not less than" true for the second)
char^ lw_inv(char^ cc) {
    if str_eq(cc, "eq") { return "ne"; }
    if str_eq(cc, "ne") { return "eq"; }
    if str_eq(cc, "lt") { return "ge"; }
    if str_eq(cc, "ge") { return "lt"; }
    if str_eq(cc, "le") { return "gt"; }
    if str_eq(cc, "gt") { return "le"; }
    if str_eq(cc, "lo") { return "hs"; }
    if str_eq(cc, "hs") { return "lo"; }
    if str_eq(cc, "ls") { return "hi"; }
    if str_eq(cc, "hi") { return "ls"; }
    if str_eq(cc, "mi") { return "pl"; }
    return "mi";
}

void lw_label(int b) {
    rg_text("L");
    rg_int(lw_lab[b]);
}

// does the instruction j read the vreg v (as its first or second operand or as an argument of a call)?
bool lw_reads(int j, int v) {
    if ir_a[j] == v { return true; }
    if ir_uses_b(ir_op[j]) && ir_bi[j] == 0 && ir_b[j] == v { return true; }
    if ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL {
        int a = 0;
        while a < ir_ac[j] {
            if ir_args[ir_as[j] + a] == v { return true; }
            a += 1;
        }
    }
    return false;
}

// a product in a temporary that the next instruction adds or subtracts (and nobody reads again) is one madd / msub
bool lw_fuse(int k, int b) {
    if ir_op[k] != IR_MUL || ir_bi[k] == 1 || ir_d[k] < 64 || ir_vcls[ir_d[k]] != 0 || k + 1 >= ir_be[b] { return false; }
    int t = ir_d[k];
    int n = k + 1;
    int op = ir_op[n];
    if ir_bi[n] == 1 || ir_vcls[ir_d[n]] != 0 { return false; }
    char^ nm = null;
    int other = 0;
    if op == IR_SUB && ir_b[n] == t && ir_a[n] != t { nm = "msub"; other = ir_a[n]; }
    else if op == IR_ADD && ir_a[n] == t && ir_b[n] != t { nm = "madd"; other = ir_b[n]; }
    else if op == IR_ADD && ir_b[n] == t && ir_a[n] != t { nm = "madd"; other = ir_a[n]; }
    if nm == null { return false; }
    if ir_a[k] == t || ir_b[k] == t { return false; }
    int j = n + 1;
    while j < ir_be[b] {
        if lw_reads(j, t) { return false; }
        if ir_d[j] == t { j = ir_be[b]; } else { j += 1; }
    }
    int d = ir_d[n];
    lw_def(d);
    rg_text(nm);
    rg_text(" ");
    lw_reg(d);
    rg_text(", ");
    lw_reg(ir_a[k]);
    rg_text(", ");
    lw_reg(ir_b[k]);
    rg_text(", ");
    lw_reg(other);
    rg_put(10);
    return true;
}

// the block that is written after the block b (the last block of the function is written at the end)
int lw_next(int b) {
    if b == ir_lastb { return 0 - 1; }
    int n = b + 1;
    if n == ir_lastb { n += 1; }
    if n >= ir_nb { n = ir_lastb; }
    return n;
}

// one instruction as text; the block b is the one that it is in (for the fall through of jumps)
bool lw_instr(int i, int b) {
    int op = ir_op[i];
    int d = ir_d[i];
    if op == IR_PARAM {
        return true;                                     // the arguments are in x0..x7 already
    }
    if op == IR_NOP { return true; }
    if op == IR_ADDR_SLOT {
        if d == 30 { return true; }                      // the frame pointer is x29 already
        rg_text("add ");
        lw_reg(d);
        rg_text(", x29, #");
        rg_int(ir_k[i]);
        rg_put(10);
        return true;
    }
    if op == IR_CONST {
        lw_def(d);
        rg_text("mov ");
        lw_reg(d);
        rg_text(", ");
        rg_int(ir_k[i]);
        rg_put(10);
        return true;
    }
    if op == IR_COPY {
        if d == ir_a[i] && d < 64 { return true; }            // a copy to the same register (the allocator made it)
        lw_def(d);
        if ir_vcls[d] == 1 { rg_text("fmov "); } else { rg_text("mov "); }
        lw_reg(d);
        rg_text(", ");
        lw_reg(ir_a[i]);
        rg_put(10);
        return true;
    }
    char^ nm = null;
    if op == IR_ADD { nm = "add"; }
    else if op == IR_SUB { nm = "sub"; }
    else if op == IR_MUL { nm = "mul"; }
    else if op == IR_SDIV { nm = "sdiv"; }
    else if op == IR_UDIV { nm = "udiv"; }
    else if op == IR_AND { nm = "and"; }
    else if op == IR_OR { nm = "orr"; }
    else if op == IR_XOR { nm = "eor"; }
    else if op == IR_SHL { nm = "lsl"; }
    else if op == IR_LSHR { nm = "lsr"; }
    else if op == IR_ASHR { nm = "asr"; }
    else if op == IR_MULHS { nm = "smulh"; }
    else if op == IR_ROTR { nm = "ror"; }
    else if op == IR_FADD { nm = "fadd"; }
    else if op == IR_FSUB { nm = "fsub"; }
    else if op == IR_FMUL { nm = "fmul"; }
    else if op == IR_FDIV { nm = "fdiv"; }
    if nm != null {
        lw_def(d);
        rg_text(nm);
        rg_text(" ");
        lw_reg(d);
        rg_text(", ");
        lw_reg(ir_a[i]);
        rg_text(", ");
        lw_b(i);
        rg_put(10);
        return true;
    }
    char^ n1 = null;
    if op == IR_NEG { n1 = "neg"; }
    else if op == IR_CLZ { n1 = "clz"; }
    else if op == IR_RBIT { n1 = "rbit"; }
    else if op == IR_BSWAP { n1 = "rev"; }
    else if op == IR_POPCNT { n1 = "popcnt"; }
    else if op == IR_NOT { n1 = "mvn"; }
    else if op == IR_FSQRT { n1 = "fsqrt"; }
    else if op == IR_FNEG { n1 = "fneg"; }
    else if op == IR_FABS { n1 = "fabs"; }
    else if op == IR_FFLOOR { n1 = "frintm"; }
    else if op == IR_FTRUNC { n1 = "frintz"; }
    else if op == IR_FCEIL { n1 = "frintp"; }
    else if op == IR_I2F { n1 = "scvtf"; }
    else if op == IR_F2I { n1 = "fcvtzs"; }
    else if op == IR_BITS2F || op == IR_F2BITS { n1 = "fmov"; }
    if n1 != null {
        lw_def(d);
        rg_text(n1);
        rg_text(" ");
        lw_reg(d);
        rg_text(", ");
        lw_reg(ir_a[i]);
        rg_put(10);
        return true;
    }
    if op == IR_EXT {
        lw_def(d);
        if ir_w[i] == 1 {
            if ir_k[i] == 8 { rg_text("sxtb "); } else if ir_k[i] == 16 { rg_text("sxth "); } else { rg_text("sxtw "); }
        } else {
            if ir_k[i] == 8 { rg_text("uxtb "); } else if ir_k[i] == 16 { rg_text("uxth "); } else { rg_text("uxtw "); }
        }
        lw_reg(d);
        rg_text(", ");
        lw_reg(ir_a[i]);
        rg_put(10);
        return true;
    }
    if op == IR_LOAD || op == IR_STORE {
        int w = ir_w[i];
        if op == IR_LOAD {
            lw_def(d);
            if w == 8 { rg_text("ldr "); }
            else if w == 1 { rg_text("ldrb "); }
            else if w == 2 { rg_text("ldrh "); }
            else if w == 4 { rg_text("ldrw "); }
            else if w == 0 - 1 { rg_text("ldrsb "); }
            else if w == 0 - 2 { rg_text("ldrsh "); }
            else { rg_text("ldrsw "); }
            lw_reg(d);
        } else {
            if w == 8 { rg_text("str "); }
            else if w == 1 { rg_text("strb "); }
            else if w == 2 { rg_text("strh "); }
            else { rg_text("strw "); }
            lw_reg(ir_b[i]);
        }
        rg_text(", [");
        lw_reg(ir_a[i]);
        rg_text(", #");
        rg_int(lw_offset(ir_a[i], ir_k[i]));
        rg_text("]\n");
        return true;
    }
    if op == IR_ADDR_FUNC {
        lw_def(d);
        rg_text("adr ");
        lw_reg(d);
        rg_text(", ");
        rg_text(@ir_name + ir_k[i] * 64);
        rg_put(10);
        return true;
    }
    if op == IR_CALL || op == IR_CALLIND {
        if op == IR_CALL {
            rg_text("bl ");
            rg_text(@ir_name + ir_k[i] * 64);
        } else {
            rg_text("blr ");
            lw_reg(ir_a[i]);
        }
        rg_put(10);
        return true;
    }
    if op == IR_SYSCALL {
        rg_text("svc 0\n");
        return true;
    }
    if op == IR_JMP {
        if ir_t1[i] != lw_next(b) {
            rg_text("b ");
            lw_label(ir_t1[i]);
            rg_put(10);
        }
        return true;
    }
    if op == IR_BR || op == IR_FBR {
        if op == IR_BR {
            rg_text("cmp ");
        } else {
            rg_text("fcmp ");
        }
        lw_reg(ir_a[i]);
        rg_text(", ");
        if ir_bi[i] == 1 { rg_int(ir_b[i]); } else { lw_reg(ir_b[i]); }
        rg_put(10);
        rg_text("b.");
        char^ ccs = lw_cc(ir_k[i], 0);
        if op == IR_FBR { ccs = lw_cc(ir_k[i], 1); }
        if ir_t1[i] == lw_next(b) && ir_t2[i] != lw_next(b) {
            // the true branch is the next block: jump on the opposite condition to the other one
            rg_text(lw_inv(ccs));
            rg_text(" ");
            lw_label(ir_t2[i]);
            rg_put(10);
            return true;
        }
        rg_text(ccs);
        rg_text(" ");
        lw_label(ir_t1[i]);
        rg_put(10);
        if ir_t2[i] != lw_next(b) {
            rg_text("b ");
            lw_label(ir_t2[i]);
            rg_put(10);
        }
        return true;
    }
    if op == IR_RET {
        return true;                                     // the epilogue follows the last block (a return is a jump to it, below)
    }
    if op == IR_TRAP {
        return true;
    }
    return false;
}

// the function that was lifted goes to regs_buf as text; the frame is as large as the stack cells need (the head and the epilogue say it)
// the hint line for the register pass: the old hints and the stack cells (plain 8-byte values)
void lw_hint() {
    int hl = 0;
    if lf_hint_n > 0 {
        while hl < lf_hint_n {
            rg_put(lf_hint_text[hl]);
            hl += 1;
        }
    } else {
        rg_text(";H");
    }
    int ci = 0;
    while ci < lw_ncells {
        rg_text(" ");
        rg_int(lw_cells[ci]);
        rg_text(":8:1");
        ci += 1;
    }
    rg_put(10);
}

bool lw_function() {
    // the deepest stack cell
    lw_maxq = 0;
    int i = 0;
    while i < ir_n {
        if (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE) && ir_a[i] == 30 && ir_k[i] < 0 {
            int q = 0 - ir_k[i];
            if q > lw_maxq { lw_maxq = q; }
        }
        i += 1;
    }
    int nframe = (lf_frame + lw_maxq + 15) / 16 * 16;     // sp stays a multiple of 16
    // the head: the name, the frame size, the saves of x29 / x30
    char hn[64];
    int c = 0;
    while pt_txt[c] != 0 && c < 62 {
        hn[c] = pt_txt[c];
        c += 1;
    }
    hn[c] = 0;
    rg_text(@hn);
    rg_put(10);
    rg_text("sub sp, sp, #");
    int nn = nframe;
    char dd[8];
    int dk = 0;
    while dk < 7 {
        dd[6 - dk] = '0' + nn % 10;
        nn = nn / 10;
        dk += 1;
    }
    dk = 0;
    while dk < 7 {
        rg_put(dd[dk]);
        dk += 1;
    }
    rg_put(10);
    rg_text("str x29, [sp, #0]\nstr x30, [sp, #8]\nadd x29, sp, #0\n");
    // blocks
    int epi_label = new_label();
    int b = 0;
    while b < ir_nb {
        lw_lab[b] = new_label();
        b += 1;
    }
    lw_ncells = 0;
    i = 0;
    while i < ir_n {
        if (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE) && ir_a[i] == 30 && ir_k[i] < 0 { lw_note_cell(lf_frame + lw_maxq + ir_k[i]); }
        i += 1;
    }
    int ord = 0;
    while ord <= ir_nb {
        // the blocks in order, except that the last block of the function (the one with the exit) is written at the end
        b = ord;
        if ord == ir_lastb { ord += 1; continue; }
        if ord == ir_nb { b = ir_lastb; }
        if b == ir_lastb && lf_epi_line < 0 { lw_hint(); }
        ord += 1;
        rg_text("L");
        rg_int(lw_lab[b]);
        rg_text(":\n");
        int k = ir_bs[b];
        while k < ir_be[b] {
            if lw_fuse(k, b) {
                k += 2;
                continue;
            }
            if !lw_instr(k, b) { return false; }
            if ir_op[k] == IR_RET && b != ir_lastb {
                rg_text("b L");
                rg_int(epi_label);
                rg_put(10);
            }
            k += 1;
        }
    }
    if lf_epi_line >= 0 { lw_hint(); }
    // the epilogue
    if lf_epi_line >= 0 {
        rg_text("L");
        rg_int(epi_label);
        rg_text(":\nldr x29, [sp, #0]\nldr x30, [sp, #8]\nadd sp, sp, #");
        dk = 0;
        nn = nframe;
        while dk < 7 {
            dd[6 - dk] = '0' + nn % 10;
            nn = nn / 10;
            dk += 1;
        }
        dk = 0;
        while dk < 7 {
            rg_put(dd[dk]);
            dk += 1;
        }
        rg_text("\nret\n");
    }
    return true;
}

// the cell was used: remember its offset for the hint line
void lw_note_cell(int off) {
    int i = 0;
    while i < lw_ncells {
        if lw_cells[i] == off { return; }
        i += 1;
    }
    if lw_ncells < 512 {
        lw_cells[lw_ncells] = off;
        lw_ncells += 1;
    }
}

// ---------------------------------------------------------------------------------------------- the driver

int ir_max = 1000000;             // -irmax N: only the first N functions that can be lifted are lowered again (to find a fault)
int ir_min;                       // -irmin N: not the first N
char ir_stat_fn[128];

void ir_say(char^ a, char^ b, char^ c) {
    write_err(a);
    write_err(b);
    write_err(c);
    write_err("\n");
}

// every function that can be lifted is lifted (and lowered again in mode 2)
void ir_run() {
    regs_len = 0;
    lf_lifted = 0;
    lf_failed = 0;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_is_func(i) {
            // the end of the function: the epilogue (ret) or, in main, the exit call
            int p = i;
            bool done = false;
            bool seen_epi = false;
            bool is_main = rg_has(i, "main:\n");
            int cnt = 0;
            while p < out_len && !done {
                int pe = rg_end(p);
                if p != i && rg_is_func(p) { break; }
                cnt += 1;
                if rg_has(p, "ldr x29, [sp, #0]") { seen_epi = true; }
                if seen_epi && rg_has(p, "ret\n") { done = true; }
                if is_main && rg_has(p, "svc 0\n") { done = true; }
                p = pe + 1;
            }
            // the name
            int nl = 0;
            while i + nl < en - 1 && nl < 120 {
                ir_stat_fn[nl] = out_buf[i + nl];
                nl += 1;
            }
            ir_stat_fn[nl] = 0;
            bool ok = false;
            if done && cnt < 60000 {
                if lf_load(i, p) {
                    if lf_function(@ir_stat_fn) == 1 {
                        ok = true;
                    } else {
                        lf_failed += 1;
                        if ir_mode == 1 { ir_say("not lifted: ", @ir_stat_fn, ""); ir_say("    ", @lf_why, ""); }
                    }
                } else {
                    lf_failed += 1;
                    if ir_mode == 1 { ir_say("not lifted: ", @ir_stat_fn, ""); ir_say("    ", "a line is too long", ""); }
                }
            }
            if ok {
                lf_lifted += 1;
                op_changed = 1;
                if ir_mode == 1 { op_webs(); }
                if ir_opt > 0 {
                    int h0 = op_hoisted;
                    int c0 = op_ra_changes;
                    int vh0 = vn_cellhits;
                    int cnt0 = 0;
                    if (ir_opt & 64) == 0 { cnt0 = op_count(); }
                    int bt0 = bt_changes;
                    if (ir_opt & 8) != 0 { op_cse_run(); }
                    if (ir_opt & 4) != 0 { op_clean_run(); }
                    if (ir_opt & 32) != 0 { op_bits_run(); }
                    if (ir_opt & 1) != 0 { op_run(); }
                    if (ir_opt & 2) != 0 { op_ra_run(); }
                    if op_hoisted == h0 && op_ra_changes == c0 && (vn_cellhits == vh0 || (ir_opt & 64) != 0 || op_count() >= cnt0) && bt_changes == bt0 && (ir_opt & 64) == 0 { op_changed = 0; }
                }
                if ir_mode == 3 {
                    ir_print();
                    syscall(64, 2, @ir_pbuf, ir_plen);
                }
                if ir_mode == 2 && op_changed == 1 && lf_lifted > ir_min && lf_lifted <= ir_max {
                    if ir_max < 1000000 { ir_say("lowering ", @ir_stat_fn, ""); }
                    int mark = regs_len;
                    if lw_function() {
                        i = p;
                        continue;
                    }
                    regs_len = mark;
                    lf_failed += 1;
                }
            }
            // as it was
            int q = i;
            while q < p {
                int qe = rg_end(q);
                rg_copy(q, qe);
                q = qe + 1;
            }
            if p == i {
                rg_copy(i, en);
                p = en + 1;
            }
            i = p;
        } else {
            rg_copy(i, en);
            i = en + 1;
        }
    }
    if ir_mode == 1 {
        write_err("functions lifted: ");
        write_err_int(lf_lifted);
        write_err(", not lifted: ");
        write_err_int(lf_failed);
        write_err("\n");
        write_err("definitions of machine registers: ");
        write_err_int(op_tot_defs);
        write_err(", webs: ");
        write_err_int(op_tot_webs);
        write_err("\n");
    }
    if ir_mode == 2 || ir_mode == 3 {
        int t = 0;
        while t < regs_len {
            out_buf[t] = regs_buf[t];
            t += 1;
        }
        out_len = regs_len;
    }
}
