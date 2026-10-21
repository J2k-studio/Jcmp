// jc_a32.j: the ARM32 back end, first step (docs/design/15-arm32.md, docs/design/18-symbolic-ir.md).
// `jcmp -target arm32 x.jk -o x` writes an ELF32 file (EABI 5, ARM mode) from the IR of the functions, with no register allocation:
// every virtual register has an 8 byte cell in the frame (a 64-bit whole number: low word, high word), every instruction loads its
// operands into r0..r3, works, and stores the result. Slow and simple; it is the base that the tests of the language run on first.
// Our own calling rules: every argument takes 8 bytes at [sp + 8 * k] of the caller, the result is in r0 (low) and r1 (high).
// What it cannot do yet stops the build with the name of the function and of the instruction (a function that nobody calls is not looked at).

char a32_code[33554432];
int a32_pos;                      // bytes of code so far
#define A32_MAXF 8192
char a32_fname[524288];           // 64 characters each
int a32_foff[A32_MAXF];           // the offset of the code of the function
int a32_fok[A32_MAXF];            // 1: made, 0: not (a32_fwhy says why)
char a32_fwhy[1048576];            // 128 characters each
int a32_nf;
#define A32_MAXC 131072
int a32_cat[A32_MAXC];            // the calls: the place of the `bl`, the function that makes it, the name of what it calls
int a32_cfn[A32_MAXC];
int a32_ckind[A32_MAXC];          // 0 a `bl`, 1 the address of the function (movw + movt)
char a32_cname[8388608];          // 64 characters each
int a32_nc;
// the jumps inside one function
int a32_jat[8192];
int a32_jblk[8192];
int a32_jcond[8192];
int a32_nj;
int a32_boff[IR_MAXB];
int a32_vmap[IR_MAXV];            // the cell of a virtual register, -1: none
int a32_nvc;
int a32_total;                    // the frame of the function
int a32_outb;                     // the bytes of the arguments of the calls that the function makes (at the bottom of the frame)
int a32_cellbase;                 // the offset of the cells (the negative offsets of the frame pointer) from sp
int a32_kver[IR_MAXV];            // the vregs that hold a known number in the block being made (a32_kver[v] == a32_blkver), and the number
int a32_kval[IR_MAXV];
int a32_blkver;
int a32_dead[IR_MAXI];            // 1: nobody reads the result of the instruction (not in the block after it, not in the blocks that follow): no store
int a32_skipd;                    // the vreg whose store is left out in the instruction being made (0: none)
int a32_skipped;                  // 1: the store was left out (a load of it in the same instruction would be wrong)
int a32_ebad;                     // 1: that happened: the function is made again with all the stores
int a32_elide;                    // 1: a32_dead is valid for this function
int a32_elide_off;                // 1: do not leave stores out
int a32_lvs[IR_MAXV];             // the live vregs while a block is looked at backwards (a32_lvs[v] == a32_lvstamp)
int a32_lvstamp;
int a32_nohi[IR_MAXI];            // 1: the high word of the result is never read (an address, a counter that is only added to ...): it is not worked out and not stored
int a32_hid[IR_MAXV];             // a32_hid[v] == a32_lvstamp: a later instruction of the block needs the high word of v
int a32_clo;                      // the vreg whose low word r0 holds right after a store of the low word only (valid while a32_pos == a32_clopos)
int a32_clopos;
int a32_chain[IR_MAXI];           // 1: only the next instruction reads the result, and it takes it first: the result need not be stored (checked: if it is not taken from r0:r1 the function is made again with all the stores)
int a32_chp;                      // the vreg whose store was left out because the instruction being made reads it from the registers (0: none)
int a32_chn;                      // the same, set by the instruction being made for the next one
int a32_chmode;                   // 1: the store being left out is such a one (the value stays in r0:r1)
int a32_nohi_cur;                 // the instruction being made: the high word of its result is not wanted
// the variables of the frame that live in registers: the slot index (a plain 8-byte slot at v30 + k: k / 8, a cell at v30 - k: 8192 + k / 8) to a pair, 0: r4 r5, 1: r8 r9
int a32_sst[16384];               // a32_sst[idx] == a32_sstamp: the slot was seen in this function
int a32_sstamp;
int a32_scnt[16384];              // how often it is used (a use in a loop counts more)
int a32_sbad[16384];              // 1: it cannot live in a register
int a32_sreg[16384];              // the pair, -1: none
int a32_salloc;                   // 1: this function keeps variables in r4 .. r9
int a32_special;                  // 1: this function changes r4, r5, r8 or r9 itself (atomics, bit count, a raw system call, the routines of try and threads)
int a32_nsave;                    // 4: the registers are saved in the frame (a function that uses them or changes them)
int a32_bdepth[IR_MAXB];          // how deep in loops a block is (a jump back over it)
// the doubles that live in d8 .. d15 for the whole function (callee-saved: a function that uses them saves them in its frame)
int a32_dhome[IR_MAXV];           // the register 8 .. 15 of a double vreg (valid when a32_dst[v] == a32_dstamp)
int a32_dst[IR_MAXV];
int a32_dstamp;
int a32_dcnt[IR_MAXV];            // how often a double vreg is used (a use in a loop counts more)
int a32_dbad[IR_MAXV];            // a32_dbad[v] == a32_dstamp: it cannot live in a register (a single precision operation or something else reads its cell)
int a32_dseen[IR_MAXV];            // a32_dseen[v] == a32_dstamp: a32_dcnt[v] is valid in this function
// the whole numbers that live in a pair of registers (r4:r5, r6:r7, r8:r9) for the whole function, like the variables of the frame
int a32_ihome[IR_MAXV];           // the low register 4, 6 or 8 (valid when a32_ist[v] == a32_istamp)
int a32_ist[IR_MAXV];
int a32_istamp;
int a32_icnt[IR_MAXV];
int a32_iseen[IR_MAXV];
int a32_ialloc;                   // 1: a whole number vreg lives in a pair
int a32_noireg;                   // -xnoireg: no whole numbers in registers (to compare)
int a32_direct = 4095;             // -xdirect N: which direct register paths are on (bit 0 const, 1 copy, 2 add nohi, 3 add, 4 compare, 5 base register, 6 load into a pair, 7 store from a pair)
int a32_nodreg;                   // -xnodreg: no doubles in d8 .. d15 (to compare)
int a32_dmask;                    // bit k: d(8 + k) is saved in the prologue and restored by the epilogue
int a32_dsoff;                    // where in the frame the saved d registers are
int a32_selidx[3];                // the slots that were chosen
int a32_cv;                       // the vreg that r0:r1 hold right after a store (valid while a32_pos == a32_cpos)
int a32_cpos;
int a32_lcat[1024];               // the local calls (bl to a block of the same function): place, block
int a32_lcblk[1024];
int a32_nlc;
int a32_cur2;
char a32_thn[4096];               // the routines that run a defer body for the unwinder (names), the block of each
int a32_thblk[64];
int a32_nth;
int a32_thg;                      // counts all of them (the names)

// "__a32_defer_N"
void a32_thname(char^ dst, int n) {
    str_copy(dst, "__a32_defer_", 64);
    char dg[12];
    int nd = 0;
    int m = n;
    if m == 0 { dg[0] = '0'; nd = 1; }
    while m > 0 {
        dg[nd] = '0' + m % 10;
        m = m / 10;
        nd += 1;
    }
    int at = 12;
    while nd > 0 {
        nd -= 1;
        dst[at] = dg[nd];
        at += 1;
    }
    dst[at] = 0;
}
int a32_vbase;                    // the offset of the cells of the virtual registers from sp
int a32_bad;                      // 1: the function cannot be made
char a32_why[128];
int a32_cur;                      // the number of the function being made
int a32_wrap_ok;                  // 1: a system call goes through __a32_sys

void a32_w(int v) {
    a32_code[a32_pos] = v & 255;
    a32_code[a32_pos + 1] = (v >> 8) & 255;
    a32_code[a32_pos + 2] = (v >> 16) & 255;
    a32_code[a32_pos + 3] = (v >> 24) & 255;
    a32_pos += 4;
}

void a32_set(int at, int v) {
    a32_code[at] = v & 255;
    a32_code[at + 1] = (v >> 8) & 255;
    a32_code[at + 2] = (v >> 16) & 255;
    a32_code[at + 3] = (v >> 24) & 255;
}

void a32_fail(char^ what) {
    if a32_bad == 0 {
        a32_bad = 1;
        str_copy(@a32_why, what, 128);
    }
}

// the conditions
#define A32_EQ 0
#define A32_NE 1
#define A32_CS 2
#define A32_CC 3
#define A32_GE 10
#define A32_LT 11
#define A32_AL 14

// data processing with a register: opc 0 and 1 eor 2 sub 3 rsb 4 add 5 adc 6 sbc 10 cmp 12 orr 13 mov 15 mvn
void a32_dp(int cond, int opc, int s, int rd, int rn, int rm) {
    a32_w((cond << 28) | (opc << 21) | (s << 20) | (rn << 16) | (rd << 12) | rm);
}

// data processing with a small number (0 .. 255)
// the 12 bits (rotation and 8 bits) of an immediate of a data processing instruction for the 32-bit value v (0 .. 2^32 - 1), or -1 if it has none
int a32_imm12(int v) {
    int r = 0;
    while r < 16 {
        int sh = 2 * r;
        int rl = v;
        if sh != 0 { rl = ((v << sh) | (v >> (32 - sh))) & 4294967295; }
        if rl <= 255 { return (r << 8) | rl; }
        r += 1;
    }
    return 0 - 1;
}

// a data processing instruction with an immediate that a32_imm12 made
void a32_dpi12(int cond, int opc, int s, int rd, int rn, int enc) {
    a32_w((cond << 28) | 0x02000000 | (opc << 21) | (s << 20) | (rn << 16) | (rd << 12) | enc);
}

void a32_dpi(int cond, int opc, int s, int rd, int rn, int imm) {
    a32_w((cond << 28) | 0x02000000 | (opc << 21) | (s << 20) | (rn << 16) | (rd << 12) | (imm & 255));
}

// rd = a 32 bit number
void a32_const(int rd, int v) {
    int lo = v & 65535;
    int hi = (v >> 16) & 65535;
    a32_w(0xE3000000 | ((lo >> 12) << 16) | (rd << 12) | (lo & 4095));
    if hi != 0 {
        a32_w(0xE3400000 | ((hi >> 12) << 16) | (rd << 12) | (hi & 4095));
    }
}

// (rlo, rhi) = a 64-bit number
void a32_const64(int rlo, int rhi, int k) {
    a32_const(rlo, k & 4294967295);
    a32_const(rhi, (k >> 32) & 4294967295);
}

// mov<cc> rd, #v (v below 65536)
void a32_const_cc(int cc, int rd, int v) {
    a32_w((cc << 28) | 0x03000000 | ((v >> 12) << 16) | (rd << 12) | (v & 4095));
}

void a32_mov(int rd, int rm) {
    a32_dp(A32_AL, 13, 0, rd, 0, rm);
}

// ldr / str rd, [rn, #off] (any offset: a far one goes through r12)
void a32_ldr(int rd, int rn, int off) {
    if off >= 0 - 4095 && off <= 4095 {
        int u = 0x00800000;
        int o = off;
        if off < 0 { u = 0; o = 0 - off; }
        a32_w(0xE5100000 | u | (rn << 16) | (rd << 12) | o);
    } else {
        a32_const(12, off);
        a32_w(0xE7900000 | (rn << 16) | (rd << 12) | 12);
    }
}

void a32_str(int rd, int rn, int off) {
    if off >= 0 - 4095 && off <= 4095 {
        int u = 0x00800000;
        int o = off;
        if off < 0 { u = 0; o = 0 - off; }
        a32_w(0xE5000000 | u | (rn << 16) | (rd << 12) | o);
    } else {
        a32_const(12, off);
        a32_w(0xE7800000 | (rn << 16) | (rd << 12) | 12);
    }
}

// r12 = rn + off
void a32_addr(int rn, int off) {
    if off == 0 {
        a32_mov(12, rn);
    } else {
        a32_const(12, off);
        a32_dp(A32_AL, 4, 0, 12, rn, 12);
    }
}

// ---- VFP (double precision in d0 .. d3, single precision in s0 / s2)
// vldr / vstr of a register of the VFP from a place of the frame (sp + off)
int a32_dcoff;            // the cell whose double d0 holds right after a store of d0 (valid while a32_pos == a32_dcpos)
int a32_dcpos;

void a32_vmem(bool load, bool single, int vd, int off) {
    if load && !single && vd == 0 && off == a32_dcoff && a32_pos == a32_dcpos { return; }
    int base = 0xED000B00;
    if single { base = 0xED000A00; }
    if load { base = base | 0x00100000; }
    if off >= 0 && off <= 1020 && off % 4 == 0 {
        a32_w(base | 0x00800000 | (13 << 16) | (vd << 12) | (off / 4));
    } else {
        a32_addr(13, off);
        a32_w(base | 0x00800000 | (12 << 16) | (vd << 12));
    }
    if !load && !single && vd == 0 {
        a32_dcoff = off;
        a32_dcpos = a32_pos;
    }
}

// vldr / vstr d(vd), [base, #off] for a double that lives in a register (base: r2 or sp)
void a32_vmemb(bool load, int vd, int base, int off) {
    int w = 0xED800B00;
    if load { w = 0xED900B00; }
    if off >= 0 && off <= 1020 && off % 4 == 0 {
        a32_w(w | (base << 16) | (vd << 12) | (off / 4));
    } else {
        a32_addr(base, off);
        a32_w(w | (12 << 16) | (vd << 12));
    }
}

void a32_vfp(int base, int vd, int vn, int vm) {
    a32_w(base | (vn << 16) | (vd << 12) | vm);
}

// (rlo, rhi) -> d(dreg) and back
void a32_vmov_to_d(int dreg, int rlo, int rhi) {
    a32_w(0xEC400B10 | (rhi << 16) | (rlo << 12) | dreg);
}

void a32_vmov_from_d(int rlo, int rhi, int dreg) {
    a32_w(0xEC500B10 | (rhi << 16) | (rlo << 12) | dreg);
}

// (rlo, rhi) shifted by the count in rc (0 .. 63); r3 and r12 are used; kind 0 left, 1 logical right, 2 arithmetic right
void a32_shreg(int kind, int rlo, int rhi, int rc) {
    a32_dpi(A32_AL, 3, 0, 3, rc, 32);                                          // rsb r3, rc, #32
    if kind == 0 {
        a32_w(0xE1A00010 | (rhi << 12) | (rc << 8) | rhi);                      // lsl rhi, rhi, rc
        a32_w(0xE1800010 | (rhi << 16) | (rhi << 12) | (3 << 8) | 0x20 | rlo);  // orr rhi, rhi, rlo, lsr r3
        a32_dpi(A32_AL, 2, 1, 12, rc, 32);                                     // subs r12, rc, #32
        a32_w(0x51800010 | (rhi << 16) | (rhi << 12) | (12 << 8) | rlo);         // orrpl rhi, rhi, rlo, lsl r12
        a32_w(0xE1A00010 | (rlo << 12) | (rc << 8) | rlo);                      // lsl rlo, rlo, rc
    } else {
        a32_w(0xE1A00010 | (rlo << 12) | (rc << 8) | 0x20 | rlo);               // lsr rlo, rlo, rc
        a32_w(0xE1800010 | (rlo << 16) | (rlo << 12) | (3 << 8) | rhi);         // orr rlo, rlo, rhi, lsl r3
        a32_dpi(A32_AL, 2, 1, 12, rc, 32);                                     // subs r12, rc, #32
        if kind == 1 {
            a32_w(0x51800010 | (rlo << 16) | (rlo << 12) | (12 << 8) | 0x20 | rhi);    // orrpl rlo, rlo, rhi, lsr r12
            a32_w(0xE1A00010 | (rhi << 12) | (rc << 8) | 0x20 | rhi);                 // lsr rhi, rhi, rc
        } else {
            a32_w(0x51800010 | (rlo << 16) | (rlo << 12) | (12 << 8) | 0x40 | rhi);    // orrpl rlo, rlo, rhi, asr r12
            a32_w(0xE1A00010 | (rhi << 12) | (rc << 8) | 0x40 | rhi);                 // asr rhi, rhi, rc
        }
    }
}

// rd = the number of bits set in rs (32 bits); r4, r5, r6 are used
void a32_popcnt32(int rd, int rs) {
    a32_const(6, 0x55555555);
    a32_w(0xE1A00020 | (4 << 12) | (1 << 7) | rs);                              // lsr r4, rs, #1
    a32_dp(A32_AL, 0, 0, 4, 4, 6);                                              // and r4, r4, r6
    a32_dp(A32_AL, 2, 0, 4, rs, 4);                                             // sub r4, rs, r4
    a32_const(6, 0x33333333);
    a32_dp(A32_AL, 0, 0, 5, 4, 6);                                              // and r5, r4, r6
    a32_w(0xE1A00020 | (4 << 12) | (2 << 7) | 4);                               // lsr r4, r4, #2
    a32_dp(A32_AL, 0, 0, 4, 4, 6);                                              // and r4, r4, r6
    a32_dp(A32_AL, 4, 0, 4, 4, 5);                                              // add r4, r4, r5
    a32_w(0xE0800020 | (4 << 16) | (4 << 12) | (4 << 7) | 4);                   // add r4, r4, r4, lsr #4
    a32_const(6, 0x0F0F0F0F);
    a32_dp(A32_AL, 0, 0, 4, 4, 6);                                              // and r4, r4, r6
    a32_const(6, 0x01010101);
    a32_w(0xE0000090 | (4 << 16) | (6 << 8) | 4);                               // mul r4, r4, r6
    a32_w(0xE1A00020 | (rd << 12) | (24 << 7) | 4);                             // lsr rd, r4, #24
}

// the cell of the virtual register v (sp + this)
int a32_cell(int v) {
    if v <= 0 || v >= IR_MAXV { a32_fail("a virtual register that is out of range"); return a32_vbase; }
    if a32_vmap[v] < 0 {
        a32_vmap[v] = a32_nvc;
        a32_nvc += 1;
        if ir_vcls[v] == 2 { a32_nvc += 1; }              // a vector: 16 bytes
    }
    return a32_vbase + a32_vmap[v] * 8;
}

// the vector registers of the code are q0 (d0, d1) and q1 (d2, d3); the vectors of the IR live in cells of 16 bytes
void a32_vload(int q, int v) {
    a32_const(12, a32_cell(v));
    a32_dp(A32_AL, 4, 0, 12, 13, 12);                 // add r12, sp, r12
    if q == 0 { a32_w(0xF42C0A0F); } else { a32_w(0xF42C2A0F); }          // vld1.8 {d0, d1} / {d2, d3}, [r12]
}

void a32_vstore(int v) {
    a32_const(12, a32_cell(v));
    a32_dp(A32_AL, 4, 0, 12, 13, 12);
    a32_w(0xF40C0A0F);                                // vst1.8 {d0, d1}, [r12]
}

// d = a op b on vectors (the codes of IR_VOP: 0 fadd 1 fsub 2 fmul 3 fdiv 4 add 5 sub 6 mul 7 and 8 orr 9 eor 10 ushl; w: 1 = 2 x 64 bits, 2 = 4 x 32, 3 = 16 x 8)
bool a32_vop(int i) {
    int k = ir_k[i];
    int w = ir_w[i];
    a32_vload(0, ir_a[i]);
    a32_vload(1, ir_b[i]);
    if k == 7 { a32_w(0xF2000152); }
    else if k == 8 { a32_w(0xF2200152); }
    else if k == 9 { a32_w(0xF3000152); }
    else if w == 1 {
        if k == 0 { a32_w(0xEE300B02); a32_w(0xEE311B03); }
        else if k == 1 { a32_w(0xEE300B42); a32_w(0xEE311B43); }
        else if k == 2 { a32_w(0xEE200B02); a32_w(0xEE211B03); }
        else if k == 3 { a32_w(0xEE800B02); a32_w(0xEE811B03); }
        else if k == 4 { a32_w(0xF2300842); }
        else if k == 5 { a32_w(0xF3300842); }
        else if k == 10 { a32_w(0xF3320440); }
        else { a32_fail("a vector operation of 2 x 64 bits"); return false; }
    } else if w == 2 {
        if k == 0 { a32_w(0xF2000D42); }
        else if k == 1 { a32_w(0xF2200D42); }
        else if k == 2 { a32_w(0xF3000D52); }
        else if k == 3 { a32_w(0xEE800A02); a32_w(0xEEC00AA2); a32_w(0xEE811A03); a32_w(0xEEC11AA3); }
        else if k == 4 { a32_w(0xF2200842); }
        else if k == 5 { a32_w(0xF3200842); }
        else if k == 6 { a32_w(0xF2200952); }
        else if k == 10 { a32_w(0xF3220440); }
        else { a32_fail("a vector operation of 4 x 32 bits"); return false; }
    } else {
        if k == 4 { a32_w(0xF2000842); }
        else if k == 5 { a32_w(0xF3000842); }
        else if k == 6 { a32_w(0xF2000952); }
        else if k == 10 { a32_w(0xF3020440); }
        else { a32_fail("a vector operation of 16 x 8 bits"); return false; }
    }
    a32_vstore(ir_d[i]);
    return true;
}

// the register d8 .. d15 that holds the double vreg v, or -1
int a32_dh(int v) {
    if v <= 0 || v >= IR_MAXV { return 0 - 1; }
    if a32_dst[v] != a32_dstamp || a32_dhome[v] < 8 { return 0 - 1; }
    return a32_dhome[v];
}

// d(vd) = the double vreg v (a copy from its register, or a vldr from its cell)
void a32_dldv(int vd, int v) {
    int dh = a32_dh(v);
    if dh >= 0 {
        if dh != vd { a32_w(0xEEB00B40 | (vd << 12) | dh); }          // vmov.f64 d(vd), d(dh)
        return;
    }
    a32_vmem(true, false, vd, a32_cell(v));
}

// the double vreg v = d(vd)
void a32_dstv(int vd, int v) {
    int dh = a32_dh(v);
    if dh >= 0 {
        if dh != vd { a32_w(0xEEB00B40 | (dh << 12) | vd); }          // vmov.f64 d(dh), d(vd)
        return;
    }
    a32_vmem(false, false, vd, a32_cell(v));
}

// the low register of the pair that holds the whole number vreg v, or -1
int a32_ih(int v) {
    if v <= 0 || v >= IR_MAXV { return 0 - 1; }
    if a32_ist[v] != a32_istamp || a32_ihome[v] < 4 { return 0 - 1; }
    return a32_ihome[v];
}

// the low register of the pair that holds v: its home, or r(scratch) after v was loaded there (its high word in r(scratch + 1))
int a32_rd(int v, int scratch, int bit) {
    int h = a32_ih(v);
    if h >= 0 && (a32_direct & bit) != 0 { return h; }
    a32_load(scratch, scratch + 1, v);
    return scratch;
}

// the same for the low word only
int a32_rdlo(int v, int scratch, int bit) {
    int h = a32_ih(v);
    if h >= 0 && (a32_direct & bit) != 0 { return h; }
    a32_loadlo(scratch, v);
    return scratch;
}

// (rlo, rhi) = the virtual register v
void a32_load(int rlo, int rhi, int v) {
    int dhl = a32_dh(v);
    if dhl >= 0 {
        a32_vmov_from_d(rlo, rhi, dhl);
        return;
    }
    if v == 29 {
        a32_const(rlo, 268435456);                 // the global area is at 0x10000000 (x28 of the ARM64 target)
        a32_const(rhi, 0);
        return;
    }
    if v == 28 {
        a32_mov(rlo, 10);                          // the block of the thread (x27 of the ARM64 target) lives in r10
        a32_const(rhi, 0);
        return;
    }
    if v < IR_MAXV && a32_kver[v] == a32_blkver {
        a32_const64(rlo, rhi, a32_kval[v]);        // a number that was made in this block
        return;
    }
    if v == a32_cv && a32_pos == a32_cpos && !(rlo == 1 && rhi == 0) {
        // r0:r1 hold it already (the store before)
        if !(rlo == 0 && rhi == 1) {
            if rlo == 1 {
                a32_mov(rhi, 1);
                a32_mov(1, 0);
            } else {
                if rlo != 0 { a32_mov(rlo, 0); }
                if rhi != 1 { a32_mov(rhi, 1); }
            }
            if rlo == 0 || rlo == 1 || rhi == 0 || rhi == 1 { a32_cv = 0 - 1; } else { a32_cpos = a32_pos; }
        }
        return;
    }
    if a32_skipped == 1 && v == a32_skipd { a32_ebad = 1; }
    if a32_chp != 0 && v == a32_chp { a32_ebad = 1; }
    int ihl = a32_ih(v);
    if ihl >= 0 {
        a32_mov(rlo, ihl);
        a32_mov(rhi, ihl + 1);
        return;
    }
    int c = a32_cell(v);
    a32_ldr(rlo, 13, c);
    a32_ldr(rhi, 13, c + 4);
}

// rlo = the low word of the virtual register v (its high word is not wanted)
void a32_loadlo(int rlo, int v) {
    int dhl = a32_dh(v);
    if dhl >= 0 {
        a32_w(0xEE100B10 | (dhl << 16) | (rlo << 12));                 // vmov.32 rlo, d(dhl)[0]
        return;
    }
    if v == 29 {
        a32_const(rlo, 268435456);
        return;
    }
    if v == 28 {
        a32_mov(rlo, 10);
        return;
    }
    if v < IR_MAXV && a32_kver[v] == a32_blkver {
        a32_const(rlo, a32_kval[v] & 4294967295);
        return;
    }
    if v == a32_cv && a32_pos == a32_cpos && rlo != 1 {
        if rlo != 0 { a32_mov(rlo, 0); a32_cpos = a32_pos; }
        return;
    }
    if v == a32_clo && a32_pos == a32_clopos && rlo != 0 && rlo != 1 {
        a32_mov(rlo, 0);
        a32_clopos = a32_pos;
        return;
    }
    if v == a32_clo && a32_pos == a32_clopos && rlo == 0 { return; }
    if a32_skipped == 1 && v == a32_skipd { a32_ebad = 1; }
    if a32_chp != 0 && v == a32_chp { a32_ebad = 1; }
    int ihlo = a32_ih(v);
    if ihlo >= 0 {
        a32_mov(rlo, ihlo);
        return;
    }
    a32_ldr(rlo, 13, a32_cell(v));
}

void a32_store(int rlo, int rhi, int v) {
    if a32_skipd != 0 && v == a32_skipd {
        a32_skipped = 1;
        if a32_chmode == 1 {
            a32_chn = v;
            if rlo == 0 && rhi == 1 && a32_nohi_cur != 1 {
                a32_cv = v;
                a32_cpos = a32_pos;
            } else if rlo == 0 {
                a32_clo = v;
                a32_clopos = a32_pos;
            }
        }
        return;
    }
    int dhs = a32_dh(v);
    if dhs >= 0 {
        a32_vmov_to_d(dhs, rlo, rhi);
        return;
    }
    int ihs = a32_ih(v);
    if ihs >= 0 {
        a32_mov(ihs, rlo);
        if a32_nohi_cur != 1 { a32_mov(ihs + 1, rhi); }
        if a32_nohi_cur == 1 {
            if rlo == 0 { a32_clo = v; a32_clopos = a32_pos; }
        } else if rlo == 0 && rhi == 1 {
            a32_cv = v;
            a32_cpos = a32_pos;
        }
        return;
    }
    if a32_nohi_cur == 1 {
        a32_str(rlo, 13, a32_cell(v));
        if rlo == 0 {
            a32_clo = v;
            a32_clopos = a32_pos;
        }
        return;
    }
    int c = a32_cell(v);
    a32_str(rlo, 13, c);
    a32_str(rhi, 13, c + 4);
    if rlo == 0 && rhi == 1 {
        a32_cv = v;
        a32_cpos = a32_pos;
    }
}

// the second operand of an instruction: a vreg or a number, in (r2, r3)
void a32_load_b(int i) {
    if ir_bi[i] == 1 {
        a32_const64(2, 3, ir_b[i]);
    } else {
        a32_load(2, 3, ir_b[i]);
    }
}

// the offset from sp of a place of the frame (v30 + k)
int a32_frame_off(int k) {
    if k >= 0 { return a32_outb + k; }
    return a32_cellbase + k;
}

// a jump to the block t with the condition cond (the place is filled in at the end of the function)
void a32_jump(int cond, int t) {
    if a32_nj >= 8192 { a32_fail("too many jumps in one function"); return; }
    a32_jat[a32_nj] = a32_pos;
    a32_jblk[a32_nj] = t;
    a32_jcond[a32_nj] = cond;
    a32_nj += 1;
    a32_w(0);
}

// the system call numbers of the ARM64 table (the library and the runtime are written with it) as the numbers of the ARM32 EABI; 0: not known
int a32_sysno(int n) {
    if n == 17 { return 183; }  if n == 23 { return 41; }   if n == 24 { return 358; }  if n == 25 { return 55; }
    if n == 29 { return 54; }   if n == 34 { return 323; }  if n == 35 { return 328; }  if n == 36 { return 331; }
    if n == 38 { return 329; }  if n == 46 { return 194; }  if n == 48 { return 334; }  if n == 49 { return 12; }
    if n == 52 { return 94; }   if n == 56 { return 322; }  if n == 57 { return 6; }    if n == 59 { return 359; }
    if n == 61 { return 217; }  if n == 62 { return 19; }   if n == 63 { return 3; }    if n == 64 { return 4; }
    if n == 65 { return 145; }  if n == 66 { return 146; }  if n == 67 { return 180; }  if n == 68 { return 181; }
    if n == 73 { return 336; }  if n == 78 { return 332; }  if n == 79 { return 327; }  if n == 80 { return 197; }
    if n == 82 { return 118; }  if n == 93 { return 1; }    if n == 94 { return 248; }  if n == 96 { return 256; }
    if n == 98 { return 240; }  if n == 101 { return 162; } if n == 113 { return 263; } if n == 115 { return 265; }
    if n == 124 { return 158; } if n == 129 { return 37; }  if n == 130 { return 238; } if n == 132 { return 186; }
    if n == 134 { return 174; } if n == 135 { return 175; } if n == 139 { return 173; } if n == 160 { return 122; }
    if n == 165 { return 77; }  if n == 167 { return 172; } if n == 169 { return 78; }  if n == 172 { return 20; }
    if n == 173 { return 64; }  if n == 174 { return 199; } if n == 175 { return 201; } if n == 176 { return 200; }
    if n == 177 { return 202; } if n == 178 { return 224; } if n == 179 { return 116; } if n == 198 { return 281; }
    if n == 199 { return 288; } if n == 200 { return 282; } if n == 201 { return 284; } if n == 202 { return 285; }
    if n == 203 { return 283; } if n == 204 { return 286; } if n == 205 { return 287; } if n == 206 { return 290; }
    if n == 207 { return 292; } if n == 208 { return 294; } if n == 209 { return 295; } if n == 210 { return 293; }
    if n == 211 { return 296; } if n == 212 { return 297; } if n == 214 { return 45; }  if n == 215 { return 91; }
    if n == 216 { return 163; } if n == 220 { return 120; } if n == 221 { return 11; }  if n == 222 { return 192; }
    if n == 226 { return 125; } if n == 233 { return 220; } if n == 242 { return 366; } if n == 260 { return 114; }
    if n == 261 { return 369; } if n == 276 { return 382; } if n == 278 { return 384; } if n == 291 { return 397; }
    return 0;
}

// the number a vreg holds when its last definition before the instruction i in the block is `const`; -1 when not
int a32_const_of(int v, int i, int b) {
    int j = i - 1;
    while j >= ir_bs[b] {
        if ir_d[j] == v {
            if ir_op[j] == IR_CONST { return ir_k[j]; }
            return 0 - 1;
        }
        j -= 1;
    }
    return 0 - 1;
}

// the condition after a 64-bit compare: sets the flags and returns the ARM condition that means "a cc b"
int a32_compare(int cc, int a, int b, int bi, int bnum) {
    if bi == 1 && bnum >= 0 && bnum < 4294967296 && (a32_direct & 2048) != 0 {
        int celo = a32_imm12(bnum & 4294967295);
        int cehi = a32_imm12((bnum >> 32) & 4294967295);
        if celo >= 0 && cehi >= 0 {
            // a small number on the right: compared as an immediate
            int ca = a32_rd(a, 0, 2048);
            if cc == IR_EQ || cc == IR_NE {
                a32_dpi12(A32_AL, 10, 1, 0, ca, celo);                   // cmp a.lo, #lo
                a32_dpi12(A32_EQ, 10, 1, 0, ca + 1, cehi);               // cmpeq a.hi, #hi
                if cc == IR_EQ { return A32_EQ; }
                return A32_NE;
            }
            bool cswap = cc == IR_GT || cc == IR_LE || cc == IR_UGT || cc == IR_ULE;
            if cswap {
                a32_dpi12(A32_AL, 3, 1, 12, ca, celo);                   // rsbs r12, a.lo, #lo
                a32_dpi12(A32_AL, 7, 1, 12, ca + 1, cehi);               // rscs r12, a.hi, #hi
            } else {
                a32_dpi12(A32_AL, 10, 1, 0, ca, celo);                   // cmp a.lo, #lo
                a32_dpi12(A32_AL, 6, 1, 12, ca + 1, cehi);               // sbcs r12, a.hi, #hi
            }
            if cc == IR_LT || cc == IR_GT { return A32_LT; }
            if cc == IR_GE || cc == IR_LE { return A32_GE; }
            if cc == IR_ULT || cc == IR_UGT { return A32_CC; }
            return A32_CS;
        }
    }
    int ra = a32_rd(a, 0, 16);                  // the registers that hold the operands: their homes, or r0:r1 / r2:r3
    int rb = 2;
    if bi == 1 {
        a32_const64(2, 3, bnum);
    } else {
        rb = a32_rd(b, 2, 16);
    }
    if cc == IR_EQ || cc == IR_NE {
        a32_dp(A32_AL, 1, 0, 12, ra, rb);               // eor r12, a.lo, b.lo
        a32_dp(A32_AL, 1, 0, 14, ra + 1, rb + 1);       // eor r14, a.hi, b.hi
        a32_dp(A32_AL, 12, 1, 12, 12, 14);      // orrs r12, r12, r14
        if cc == IR_EQ { return A32_EQ; }
        return A32_NE;
    }
    bool swap = cc == IR_GT || cc == IR_LE || cc == IR_UGT || cc == IR_ULE;
    if swap {
        a32_dp(A32_AL, 10, 1, 0, rb, ra);               // cmp b.lo, a.lo
        a32_dp(A32_AL, 6, 1, 12, rb + 1, ra + 1);       // sbcs r12, b.hi, a.hi
    } else {
        a32_dp(A32_AL, 10, 1, 0, ra, rb);               // cmp a.lo, b.lo
        a32_dp(A32_AL, 6, 1, 12, ra + 1, rb + 1);       // sbcs r12, a.hi, b.hi
    }
    if cc == IR_LT || cc == IR_GT { return A32_LT; }
    if cc == IR_GE || cc == IR_LE { return A32_GE; }
    if cc == IR_ULT || cc == IR_UGT { return A32_CC; }
    return A32_CS;
}

void a32_epilogue() {
    if a32_nsave > 0 {
        a32_ldr(4, 13, a32_cellbase);
        a32_ldr(5, 13, a32_cellbase + 4);
        a32_ldr(6, 13, a32_cellbase + 8);
        a32_ldr(7, 13, a32_cellbase + 12);
        a32_ldr(8, 13, a32_cellbase + 16);
        a32_ldr(9, 13, a32_cellbase + 20);
    }
    if a32_dmask != 0 {
        int rk = 0;
        while rk < 8 {
            if ((a32_dmask >> rk) & 1) == 1 { a32_vmem(true, false, 8 + rk, a32_dsoff + rk * 8); }
            rk += 1;
        }
    }
    a32_ldr(14, 13, a32_outb + 8);
    a32_const(12, a32_total);
    a32_dp(A32_AL, 4, 0, 13, 13, 12);           // add sp, sp, r12
    a32_w(0xE12FFF1E);                          // bx lr
}

// the offset (from the global area) of the table of system call numbers: behind the global area
int a32_systab() {
    return (gl_bytes + 15) / 16 * 16;
}

// a call of the function name: the arguments are at the bottom of the frame already
void a32_bl(char^ name) {
    if a32_nc >= A32_MAXC { a32_fail("too many calls"); return; }
    a32_cat[a32_nc] = a32_pos;
    a32_cfn[a32_nc] = a32_cur;
    a32_ckind[a32_nc] = 0;
    str_copy(@a32_cname + a32_nc * 64, name, 64);
    a32_nc += 1;
    a32_w(0xEB000000);                         // bl (the place is filled in at the end)
}

// one instruction; false when it is not known yet
bool a32_instr(int i, int b) {
    int op = ir_op[i];
    int d = ir_d[i];
    if op == IR_NOP { return true; }
    if op == IR_CONST && a32_ih(d) >= 0 && a32_skipd != d && (a32_direct & 1) != 0 {
        int ch = a32_ih(d);
        if a32_nohi_cur == 1 { a32_const(ch, ir_k[i] & 4294967295); } else { a32_const64(ch, ch + 1, ir_k[i]); }
        return true;
    }
    if op == IR_CONST {
        if a32_nohi_cur == 1 {
            a32_const(0, ir_k[i] & 4294967295);
            a32_store(0, 1, d);
            return true;
        }
        a32_const64(0, 1, ir_k[i]);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_RAW {
        // a run of machine words: r0 .. r9 are loaded from x0 .. x9 before the first, stored to them after the last
        bool first = i == ir_bs[b] || ir_op[i - 1] != IR_RAW;
        bool last = i == ir_be[b] - 1 || ir_op[i + 1] != IR_RAW;
        if first {
            int rr = 0;
            while rr < 10 {
                a32_ldr(rr, 13, a32_cell(rr + 1));
                rr += 1;
            }
        }
        a32_w(ir_k[i]);
        if last {
            int rs = 0;
            while rs < 10 {
                a32_str(rs, 13, a32_cell(rs + 1));
                rs += 1;
            }
            // the high words: 0, but all ones for x0 when it is a number -4095 .. -1 (the result of a system call)
            a32_w(0xE3700A01);                               // cmn r0, #4096
            a32_dpi(A32_AL, 13, 0, 12, 0, 0);                // mov r12, #0
            a32_dpi(A32_CS, 15, 0, 12, 0, 0);                // mvncs r12, #0
            a32_str(12, 13, a32_cell(1) + 4);
            a32_dpi(A32_AL, 13, 0, 12, 0, 0);
            rs = 1;
            while rs < 10 {
                a32_str(12, 13, a32_cell(rs + 1) + 4);
                rs += 1;
            }
        }
        return true;
    }
    if op == IR_VOP { return a32_vop(i); }
    if op == IR_VDUP {
        a32_load(0, 1, ir_a[i]);
        if ir_w[i] == 1 { a32_w(0xEC410B10); a32_w(0xEC410B11); }          // vmov d0, r0, r1 / d1, r0, r1
        else if ir_w[i] == 2 { a32_w(0xEEA00B10); }                         // vdup.32 q0, r0
        else { a32_w(0xEEE00B10); }                                         // vdup.8 q0, r0
        a32_vstore(d);
        return true;
    }
    if op == IR_VLANE {
        // the lane is read from the cell of the vector
        int lc = a32_cell(ir_a[i]) + ir_k[i];
        a32_ldr(0, 13, lc);
        if ir_w[i] == 8 {
            a32_ldr(1, 13, lc + 4);
        } else if ir_w[i] < 0 {
            a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0);                  // mov r1, r0, asr #31
        } else {
            a32_const(1, 0);
        }
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_VINS {
        if ir_vcls[ir_a[i]] == 2 && ir_a[i] != d {
            a32_vload(0, ir_a[i]);
            a32_vstore(d);
        }
        a32_load(0, 1, ir_b[i]);
        int ic = a32_cell(d) + ir_k[i];
        a32_str(0, 13, ic);
        if ir_w[i] == 8 { a32_str(1, 13, ic + 4); }
        return true;
    }
    if op == IR_COPY && ir_vcls[d] == 2 {
        a32_vload(0, ir_a[i]);
        a32_vstore(d);
        return true;
    }
    if (op == IR_LOAD || op == IR_STORE) && ir_w[i] == 16 {
        int vb = 13;
        int vo = ir_k[i];
        if op == IR_STORE { a32_vload(0, ir_b[i]); }
        if ir_a[i] == 30 {
            vo = a32_frame_off(ir_k[i]);
        } else {
            a32_loadlo(2, ir_a[i]);
            vb = 2;
        }
        a32_addr(vb, vo);
        if op == IR_LOAD {
            a32_w(0xF42C0A0F);
            a32_vstore(d);
        } else {
            a32_w(0xF40C0A0F);
        }
        return true;
    }
    if op == IR_COPY && ir_vcls[d] == 1 && (a32_dh(ir_a[i]) >= 0 || a32_dh(d) >= 0) {
        // a double that lives in a register: copied with the VFP, not through r0:r1
        int cpa = a32_dh(ir_a[i]);
        int cpd = a32_dh(d);
        if cpa >= 0 && cpd >= 0 {
            if cpa != cpd { a32_w(0xEEB00B40 | (cpd << 12) | cpa); }
        } else if cpa >= 0 {
            a32_vmem(false, false, cpa, a32_cell(d));
        } else {
            a32_vmem(true, false, cpd, a32_cell(ir_a[i]));
        }
        return true;
    }
    if op == IR_COPY && ir_vcls[d] == 0 && (a32_ih(ir_a[i]) >= 0 || a32_ih(d) >= 0) && a32_skipd != d && ir_a[i] != d && (a32_direct & 2) != 0 {
        int cd = a32_ih(d);
        if a32_nohi_cur == 1 {
            int rs0 = a32_rdlo(ir_a[i], 0, 2);
            if cd >= 0 { a32_mov(cd, rs0); } else { a32_store(rs0, 1, d); }
        } else {
            int rs1 = a32_rd(ir_a[i], 0, 2);
            if cd >= 0 { a32_mov(cd, rs1); a32_mov(cd + 1, rs1 + 1); } else { a32_store(rs1, rs1 + 1, d); }
        }
        return true;
    }
    if op == IR_COPY {
        if a32_nohi_cur == 1 && ir_vcls[d] == 0 {
            a32_loadlo(0, ir_a[i]);
            a32_store(0, 1, d);
            return true;
        }
        a32_load(0, 1, ir_a[i]);
        a32_store(0, 1, d);
        return true;
    }
    if (op == IR_ADD || op == IR_SUB || op == IR_AND || op == IR_OR || op == IR_XOR) && ir_bi[i] == 1 && ir_a[i] != 30 && (a32_direct & 1024) != 0 && a32_skipd != d {
        // a number as the second operand that fits the instruction: no registers for it
        int kb = ir_b[i];
        int kop = op;
        if kop == IR_ADD && kb < 0 && kb > 0 - 4294967296 { kop = IR_SUB; kb = 0 - kb; }
        else if kop == IR_SUB && kb < 0 && kb > 0 - 4294967296 { kop = IR_ADD; kb = 0 - kb; }
        int klo = kb & 4294967295;
        int khi = (kb >> 32) & 4294967295;
        int elo = a32_imm12(klo);
        int ehi = a32_imm12(khi);
        bool kmask = kop == IR_AND && klo == 4294967295 && khi == 0;         // & 0xFFFFFFFF: the low word stays, the high word is 0
        bool kok = (elo >= 0 && ehi >= 0) || kmask;
        if kop != IR_ADD && kop != IR_SUB && kop != IR_AND && kop != IR_OR && kop != IR_XOR { kok = false; }
        if kok {
            int kra = a32_rd(ir_a[i], 0, 1024);
            int krd = 0;
            bool kdir = a32_ih(d) >= 0;
            if kdir { krd = a32_ih(d); }
            bool khiw = a32_nohi_cur != 1;
            if kmask {
                if krd != kra { a32_mov(krd, kra); }
                if khiw { a32_const(krd + 1, 0); }
            } else if kop == IR_ADD {
                if khiw { a32_dpi12(A32_AL, 4, 1, krd, kra, elo); a32_dpi12(A32_AL, 5, 0, krd + 1, kra + 1, ehi); }
                else { a32_dpi12(A32_AL, 4, 0, krd, kra, elo); }
            } else if kop == IR_SUB {
                if khiw { a32_dpi12(A32_AL, 2, 1, krd, kra, elo); a32_dpi12(A32_AL, 6, 0, krd + 1, kra + 1, ehi); }
                else { a32_dpi12(A32_AL, 2, 0, krd, kra, elo); }
            } else {
                int kopc = 0;
                if kop == IR_OR { kopc = 12; }
                if kop == IR_XOR { kopc = 1; }
                a32_dpi12(A32_AL, kopc, 0, krd, kra, elo);
                if khiw { a32_dpi12(A32_AL, kopc, 0, krd + 1, kra + 1, ehi); }
            }
            if !kdir { a32_store(0, 1, d); }
            return true;
        }
    }
    if (op == IR_ADD || op == IR_SUB || op == IR_AND || op == IR_OR || op == IR_XOR) && a32_nohi_cur == 1 && ir_a[i] != 30 && (a32_direct & 4) != 0 {
        // only the low word is wanted: one instruction on the low words (the operands and the result are used where they live)
        int nra = a32_rdlo(ir_a[i], 0, 4);
        int nrb = 2;
        if ir_bi[i] == 1 { a32_const(2, ir_b[i] & 4294967295); } else { nrb = a32_rdlo(ir_b[i], 2, 4); }
        int nrd = 0;
        bool ndir = a32_ih(d) >= 0 && a32_skipd != d;
        if ndir { nrd = a32_ih(d); }
        if op == IR_ADD { a32_dp(A32_AL, 4, 0, nrd, nra, nrb); }
        else if op == IR_SUB { a32_dp(A32_AL, 2, 0, nrd, nra, nrb); }
        else if op == IR_AND { a32_dp(A32_AL, 0, 0, nrd, nra, nrb); }
        else if op == IR_OR { a32_dp(A32_AL, 12, 0, nrd, nra, nrb); }
        else { a32_dp(A32_AL, 1, 0, nrd, nra, nrb); }
        if !ndir { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_ADD || op == IR_SUB || op == IR_AND || op == IR_OR || op == IR_XOR {
        if ir_a[i] == 30 && op == IR_ADD && ir_bi[i] == 1 {
            // the address of a place of the frame
            a32_const(12, a32_frame_off(ir_b[i]));
            a32_dp(A32_AL, 4, 0, 0, 13, 12);
            a32_const(1, 0);
            a32_store(0, 1, d);
            return true;
        }
        int fra = a32_rd(ir_a[i], 0, 8);
        int frb = 2;
        if ir_bi[i] == 1 { a32_const64(2, 3, ir_b[i]); } else { frb = a32_rd(ir_b[i], 2, 8); }
        int frd = 0;
        bool fdir = a32_ih(d) >= 0 && a32_skipd != d;
        if fdir { frd = a32_ih(d); }
        if op == IR_ADD { a32_dp(A32_AL, 4, 1, frd, fra, frb); a32_dp(A32_AL, 5, 0, frd + 1, fra + 1, frb + 1); }
        else if op == IR_SUB { a32_dp(A32_AL, 2, 1, frd, fra, frb); a32_dp(A32_AL, 6, 0, frd + 1, fra + 1, frb + 1); }
        else if op == IR_AND { a32_dp(A32_AL, 0, 0, frd, fra, frb); a32_dp(A32_AL, 0, 0, frd + 1, fra + 1, frb + 1); }
        else if op == IR_OR { a32_dp(A32_AL, 12, 0, frd, fra, frb); a32_dp(A32_AL, 12, 0, frd + 1, fra + 1, frb + 1); }
        else { a32_dp(A32_AL, 1, 0, frd, fra, frb); a32_dp(A32_AL, 1, 0, frd + 1, fra + 1, frb + 1); }
        if !fdir { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_MUL && ir_bi[i] == 1 && ir_b[i] > 0 && (ir_b[i] & (ir_b[i] - 1)) == 0 && (a32_direct & 256) != 0 && a32_skipd != d {
        // a multiplication by a power of two is a shift
        int mk = 0;
        while (1 << mk) < ir_b[i] { mk += 1; }
        int mb = ir_b[i];
        ir_op[i] = IR_SHL;
        ir_b[i] = mk;
        bool mr = a32_instr(i, b);
        ir_op[i] = IR_MUL;
        ir_b[i] = mb;
        return mr;
    }
    if op == IR_MUL {
        a32_load(0, 1, ir_a[i]);
        a32_load_b(i);
        a32_w(0xE0800090 | (12 << 16) | (14 << 12) | (2 << 8) | 0);        // umull r14, r12, r0, r2
        a32_w(0xE0200090 | (12 << 16) | (12 << 12) | (3 << 8) | 0);        // mla r12, r0, r3, r12
        a32_w(0xE0200090 | (12 << 16) | (12 << 12) | (2 << 8) | 1);        // mla r12, r1, r2, r12
        a32_mov(3, 12);
        a32_store(14, 3, d);
        return true;
    }
    if op == IR_NEG || op == IR_NOT {
        a32_load(0, 1, ir_a[i]);
        if op == IR_NEG {
            a32_dpi(A32_AL, 3, 1, 0, 0, 0);          // rsbs r0, r0, #0
            a32_dpi(A32_AL, 7, 0, 1, 1, 0);          // rsc r1, r1, #0
        } else {
            a32_dp(A32_AL, 15, 0, 0, 0, 0);          // mvn r0, r0
            a32_dp(A32_AL, 15, 0, 1, 0, 1);          // mvn r1, r1
        }
        a32_store(0, 1, d);
        return true;
    }
    if (op == IR_SHL || op == IR_LSHR || op == IR_ASHR) && ir_bi[i] == 1 && (a32_direct & 256) != 0 && a32_skipd != d && (a32_ih(ir_a[i]) >= 0 || a32_ih(d) >= 0) {
        // a shift by a number, from the registers where the operand lives into the registers where the result lives
        int sn = ir_b[i] & 63;
        bool sdh = a32_ih(d) >= 0;
        int dlo = 0;
        if sdh { dlo = a32_ih(d); }
        int dhi = dlo + 1;
        int alo = a32_rd(ir_a[i], 0, 256);
        int ahi = alo + 1;
        bool snohi = a32_nohi_cur == 1;
        if op == IR_SHL {
            if sn == 0 {
                if dlo != alo { a32_mov(dlo, alo); if !snohi { a32_mov(dhi, ahi); } }
            } else if sn < 32 {
                if !snohi {
                    a32_w(0xE1A00000 | (dhi << 12) | (sn << 7) | ahi);                              // lsl dhi, ahi, #n
                    a32_w(0xE1800020 | (dhi << 16) | (dhi << 12) | ((32 - sn) << 7) | alo);        // orr dhi, dhi, alo, lsr #(32-n)
                }
                a32_w(0xE1A00000 | (dlo << 12) | (sn << 7) | alo);                                  // lsl dlo, alo, #n
            } else {
                if !snohi { a32_w(0xE1A00000 | (dhi << 12) | ((sn - 32) << 7) | alo); }            // lsl dhi, alo, #(n-32)
                a32_const(dlo, 0);
            }
        } else if op == IR_LSHR {
            if sn == 0 {
                if dlo != alo { a32_mov(dlo, alo); if !snohi { a32_mov(dhi, ahi); } }
            } else if sn < 32 {
                a32_w(0xE1A00020 | (dlo << 12) | (sn << 7) | alo);                                  // lsr dlo, alo, #n
                a32_w(0xE1800000 | (dlo << 16) | (dlo << 12) | ((32 - sn) << 7) | ahi);            // orr dlo, dlo, ahi, lsl #(32-n)
                if !snohi { a32_w(0xE1A00020 | (dhi << 12) | (sn << 7) | ahi); }                    // lsr dhi, ahi, #n
            } else {
                int sh = sn - 32;
                if sh == 0 { a32_mov(dlo, ahi); } else { a32_w(0xE1A00020 | (dlo << 12) | (sh << 7) | ahi); }
                if !snohi { a32_const(dhi, 0); }
            }
        } else {
            if sn == 0 {
                if dlo != alo { a32_mov(dlo, alo); if !snohi { a32_mov(dhi, ahi); } }
            } else if sn < 32 {
                a32_w(0xE1A00020 | (dlo << 12) | (sn << 7) | alo);                                  // lsr dlo, alo, #n
                a32_w(0xE1800000 | (dlo << 16) | (dlo << 12) | ((32 - sn) << 7) | ahi);            // orr dlo, dlo, ahi, lsl #(32-n)
                if !snohi { a32_w(0xE1A00040 | (dhi << 12) | (sn << 7) | ahi); }                    // asr dhi, ahi, #n
            } else {
                int sh2 = sn - 32;
                if sh2 == 0 { a32_mov(dlo, ahi); } else { a32_w(0xE1A00040 | (dlo << 12) | (sh2 << 7) | ahi); }
                if !snohi { a32_w(0xE1A00040 | (dhi << 12) | (31 << 7) | ahi); }                    // asr dhi, ahi, #31
            }
        }
        if !sdh { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_SHL || op == IR_LSHR || op == IR_ASHR {
        if ir_bi[i] != 1 {
            // a shift by the number in a register (modulo 64)
            a32_load(0, 1, ir_a[i]);
            a32_load(2, 3, ir_b[i]);
            a32_dpi(A32_AL, 0, 0, 2, 2, 63);                     // and r2, r2, #63
            int shk = 0;
            if op == IR_LSHR { shk = 1; }
            if op == IR_ASHR { shk = 2; }
            a32_shreg(shk, 0, 1, 2);
            a32_store(0, 1, d);
            return true;
        }
        int n = ir_b[i] & 63;
        if op == IR_SHL && a32_nohi_cur == 1 {
            a32_loadlo(0, ir_a[i]);
            if n >= 32 { a32_const(0, 0); }
            else if n != 0 { a32_w(0xE1A00000 | (0 << 12) | (n << 7) | 0); }          // lsl r0, r0, #n
            a32_store(0, 1, d);
            return true;
        }
        a32_load(0, 1, ir_a[i]);
        if n != 0 {
            if op == IR_SHL {
                if n < 32 {
                    a32_w(0xE1A00000 | (1 << 12) | (n << 7) | 1);                          // lsl r1, r1, #n
                    a32_w(0xE1800020 | (1 << 16) | (1 << 12) | ((32 - n) << 7) | 0);      // orr r1, r1, r0, lsr #(32-n)
                    a32_w(0xE1A00000 | (0 << 12) | (n << 7) | 0);                          // lsl r0, r0, #n
                } else {
                    a32_w(0xE1A00000 | (1 << 12) | ((n - 32) << 7) | 0);                  // lsl r1, r0, #(n-32)
                    a32_const(0, 0);
                }
            } else if op == IR_LSHR {
                if n < 32 {
                    a32_w(0xE1A00020 | (0 << 12) | (n << 7) | 0);                          // lsr r0, r0, #n
                    a32_w(0xE1800000 | (0 << 16) | (0 << 12) | ((32 - n) << 7) | 1);      // orr r0, r0, r1, lsl #(32-n)
                    a32_w(0xE1A00020 | (1 << 12) | (n << 7) | 1);                          // lsr r1, r1, #n
                } else {
                    int sh = n - 32;
                    if sh == 0 { a32_mov(0, 1); } else { a32_w(0xE1A00020 | (0 << 12) | (sh << 7) | 1); }
                    a32_const(1, 0);
                }
            } else {
                if n < 32 {
                    a32_w(0xE1A00020 | (0 << 12) | (n << 7) | 0);                          // lsr r0, r0, #n
                    a32_w(0xE1800000 | (0 << 16) | (0 << 12) | ((32 - n) << 7) | 1);      // orr r0, r0, r1, lsl #(32-n)
                    a32_w(0xE1A00040 | (1 << 12) | (n << 7) | 1);                          // asr r1, r1, #n
                } else {
                    int sh2 = n - 32;
                    if sh2 == 0 { a32_mov(0, 1); } else { a32_w(0xE1A00040 | (0 << 12) | (sh2 << 7) | 1); }
                    a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 1);                         // asr r1, r1, #31
                }
            }
        }
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_EXT {
        a32_load(0, 1, ir_a[i]);
        int bits = ir_k[i];
        bool sg = ir_w[i] == 1;
        if bits == 8 { if sg { a32_w(0xE6AF0070); } else { a32_w(0xE6EF0070); } }          // sxtb / uxtb r0, r0
        else if bits == 16 { if sg { a32_w(0xE6BF0070); } else { a32_w(0xE6FF0070); } }    // sxth / uxth r0, r0
        else if bits != 32 { a32_fail("an extension from this many bits"); return false; }
        if sg { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); } else { a32_const(1, 0); }  // asr r1, r0, #31 / 0
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_SETCC {
        int bnum = 0;
        if ir_bi[i] == 1 { bnum = ir_b[i]; }
        int cc = a32_compare(ir_k[i], ir_a[i], ir_b[i], ir_bi[i], bnum);
        a32_dpi(A32_AL, 13, 0, 0, 0, 0);          // mov r0, #0
        a32_dpi(cc, 13, 0, 0, 0, 1);              // mov<cc> r0, #1
        a32_dpi(A32_AL, 13, 0, 1, 0, 0);
        a32_store(0, 1, d);
        return true;
    }
    if (op == IR_LOAD || op == IR_STORE) && ir_a[i] == 30 && a32_salloc == 1 {
        int sidx = a32_slot_index(ir_k[i], ir_w[i]);
        if sidx >= 0 && a32_sst[sidx] == a32_sstamp && a32_sreg[sidx] >= 0 {
            int slo = 4;
            if a32_sreg[sidx] == 1 { slo = 8; }
            if a32_sreg[sidx] == 2 { slo = 6; }
            if op == IR_LOAD {
                a32_mov(0, slo);
                a32_mov(1, slo + 1);
                a32_store(0, 1, d);
            } else {
                a32_load(slo, slo + 1, ir_b[i]);
            }
            return true;
        }
    }
    if op == IR_LOAD || op == IR_STORE {
        int w = ir_w[i];
        int aw = w;
        if aw < 0 { aw = 0 - aw; }
        if aw != 8 && aw != 4 && aw != 2 && aw != 1 { a32_fail("a load or a store of this width"); return false; }
        int base = 13;
        int off = ir_k[i];
        if ir_a[i] == 30 {
            off = a32_frame_off(ir_k[i]);
        } else {
            base = a32_rdlo(ir_a[i], 2, 32);
        }
        if op == IR_LOAD && aw == 8 && ir_vcls[d] == 1 && a32_dh(d) >= 0 {
            a32_vmemb(true, a32_dh(d), base, off);
            return true;
        }
        if op == IR_STORE && aw == 8 && ir_vcls[ir_b[i]] == 1 && a32_dh(ir_b[i]) >= 0 {
            a32_vmemb(false, a32_dh(ir_b[i]), base, off);
            return true;
        }
        if op == IR_LOAD && (aw == 8 || aw == 4) && a32_ih(d) >= 0 && a32_skipd != d && (a32_direct & 64) != 0 {
            // into the pair where d lives: the high word first (the base may be the low register of that pair)
            int lh = a32_ih(d);
            if aw == 8 {
                if a32_nohi_cur != 1 { a32_ldr(lh + 1, base, off + 4); }
                a32_ldr(lh, base, off);
            } else {
                a32_ldr(lh, base, off);
                if a32_nohi_cur != 1 {
                    if w < 0 { a32_w(0xE1A00040 | ((lh + 1) << 12) | (31 << 7) | lh); } else { a32_const(lh + 1, 0); }
                }
            }
            return true;
        }
        if op == IR_LOAD {
            if aw == 8 {
                a32_ldr(0, base, off);
                if a32_nohi_cur != 1 { a32_ldr(1, base, off + 4); }
            } else if aw == 4 {
                a32_ldr(0, base, off);
                if a32_nohi_cur != 1 {
                    if w < 0 { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); } else { a32_const(1, 0); }
                }
            } else {
                a32_addr(base, off);
                if aw == 1 {
                    if w < 0 { a32_w(0xE1D000D0 | (12 << 16) | (0 << 12)); } else { a32_w(0xE5D00000 | (12 << 16) | (0 << 12)); }     // ldrsb / ldrb r0, [r12]
                } else {
                    if w < 0 { a32_w(0xE1D000F0 | (12 << 16) | (0 << 12)); } else { a32_w(0xE1D000B0 | (12 << 16) | (0 << 12)); }     // ldrsh / ldrh r0, [r12]
                }
                if a32_nohi_cur != 1 {
                    if w < 0 { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); } else { a32_const(1, 0); }
                }
            }
            a32_store(0, 1, d);
        } else {
            if aw == 8 || aw == 4 {
                int sv = 0;
                if aw == 8 { sv = a32_rd(ir_b[i], 0, 128); } else { sv = a32_rdlo(ir_b[i], 0, 128); }
                a32_str(sv, base, off);
                if aw == 8 { a32_str(sv + 1, base, off + 4); }
            } else {
                a32_loadlo(0, ir_b[i]);
                a32_addr(base, off);
                if aw == 1 { a32_w(0xE5C00000 | (12 << 16) | (0 << 12)); }          // strb r0, [r12]
                else { a32_w(0xE1C000B0 | (12 << 16) | (0 << 12)); }                // strh r0, [r12]
            }
        }
        return true;
    }
    if op == IR_ADDR_SLOT {
        a32_const(12, a32_frame_off(0));
        a32_dp(A32_AL, 4, 0, 0, 13, 12);
        a32_const(1, 0);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_PARAM {
        // the arguments are at [sp + total + 8 * k]; only those that the function has are read
        int fi = find_func(@ir_fname);
        int np = 8;
        if fi >= 0 { np = as1_nregs(fi) + as1_hidden(fi); }
        if lf_naked == 1 { np = 8; }                  // a naked function reads x0 .. x7 as they come (a named block has no parameters)
        if ir_k[i] < np {
            a32_ldr(0, 13, a32_total + 8 * ir_k[i]);
            a32_ldr(1, 13, a32_total + 8 * ir_k[i] + 4);
            a32_store(0, 1, d);
        }
        return true;
    }
    if op == IR_CALL {
        int n = ir_ac[i];
        int k = 0;
        while k < n {
            a32_load(0, 1, ir_args[ir_as[i] + k]);
            a32_str(0, 13, 8 * k);
            a32_str(1, 13, 8 * k + 4);
            k += 1;
        }
        a32_bl(@ir_name + ir_k[i] * 64);
        if d != 0 { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_CALLIND {
        int ni = ir_ac[i];
        int ki = 0;
        while ki < ni {
            a32_load(0, 1, ir_args[ir_as[i] + ki]);
            a32_str(0, 13, 8 * ki);
            a32_str(1, 13, 8 * ki + 4);
            ki += 1;
        }
        a32_load(2, 3, ir_a[i]);
        a32_mov(12, 2);
        a32_w(0xE12FFF3C);                          // blx r12
        if d != 0 { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_ATOMIC && ir_k[i] >= 31 {
        // the instructions of the CPU (std/rt_hw.j): barriers, wait / event / yield, the counter, the core number, the code cache
        int cc = ir_k[i];
        if cc == 31 { a32_w(0xF57FF05B); }                       // dmb ish
        else if cc == 32 { a32_w(0xF57FF05D); }                  // dmb ishld
        else if cc == 33 { a32_w(0xF57FF05A); }                  // dmb ishst
        else if cc == 34 { a32_w(0xF57FF04F); }                  // dsb sy
        else if cc == 35 { a32_w(0xE320F003); }                  // wfi
        else if cc == 36 { a32_w(0xE320F002); }                  // wfe
        else if cc == 37 { a32_w(0xE320F004); }                  // sev
        else if cc == 38 { a32_w(0xE320F001); }                  // yield
        else if cc == 39 { a32_w(0xE320F000); }                  // nop
        else if cc == 40 { a32_w(0xF57FF06F); }                  // isb sy
        else if cc == 41 {
            a32_w(0xEC510F1E);                                   // mrrc p15, #1, r0, r1, c14: the virtual counter
            if d != 0 { a32_store(0, 1, d); }
        } else if cc == 42 {
            a32_w(0xEE1E0F10);                                   // mrc p15, #0, r0, c14, c0, #0: its frequency
            a32_const(1, 0);
            if d != 0 { a32_store(0, 1, d); }
        } else if cc == 43 {
            // the core number: getcpu(&cpu, 0, 0) with the word at the bottom of the frame
            a32_mov(0, 13);
            a32_const(1, 0);
            a32_const(2, 0);
            a32_const(7, 345);
            a32_w(0xEF000000);
            a32_ldr(0, 13, 0);
            a32_const(1, 0);
            if d != 0 { a32_store(0, 1, d); }
        } else if cc == 46 {
            a32_load(0, 14, ir_args[ir_as[i]]);
            a32_w(0xF5D0F000);                                   // pld [r0]: the line is wanted soon
        } else if cc == 47 {
            a32_w(0xF57FF04F);                                   // dsb sy
            a32_w(0xF57FF06F);                                   // isb sy: nothing after it runs before the branches before it are settled
        } else {
            // the code cache of the line at the address: cacheflush(address, address + 64, 0)
            a32_load(0, 14, ir_args[ir_as[i]]);
            a32_dpi(A32_AL, 4, 0, 1, 0, 64);                     // add r1, r0, #64
            a32_const(2, 0);
            a32_const(7, 983042);
            a32_w(0xEF000000);
        }
        return true;
    }
    if op == IR_ATOMIC {
        // an atomic operation on the 64-bit word at the address (8-aligned): ldrexd / strexd in a loop; the result is the value before
        int code = ir_k[i];
        int na = ir_ac[i];
        a32_load(6, 8, ir_args[ir_as[i]]);              // r6 = the address
        if na >= 2 { a32_load(0, 1, ir_args[ir_as[i] + 1]); }          // r0:r1 = the value
        if na >= 3 { a32_load(8, 9, ir_args[ir_as[i] + 2]); }          // r8:r9 = the new value of cas
        int top = a32_pos;
        a32_w(0xE1B00F9F | (6 << 16) | (2 << 12));      // ldrexd r2, r3, [r6]
        if code == 28 {
            // store: the new value is the value
            a32_mov(4, 0);
            a32_mov(5, 1);
        } else if code == 27 {
            a32_w(0xF57FF01F);                          // clrex: a load only
        } else if code == 20 {
            // cas: when the word is not the expected value nothing is stored
            a32_dp(A32_AL, 1, 0, 4, 2, 0);              // eor r4, r2, r0
            a32_dp(A32_AL, 1, 0, 5, 3, 1);              // eor r5, r3, r1
            a32_dp(A32_AL, 12, 1, 4, 4, 5);             // orrs r4, r4, r5
            a32_w(0x1A000000 | 4);                      // bne +4 words: to the nop below (skips the 2 moves, strexd, the compare and the loop branch)
            a32_mov(4, 8);
            a32_mov(5, 9);
        } else if code == 21 {
            a32_mov(4, 0);
            a32_mov(5, 1);
        } else if code == 22 {
            a32_dp(A32_AL, 4, 1, 4, 2, 0);              // adds r4, r2, r0
            a32_dp(A32_AL, 5, 0, 5, 3, 1);              // adc r5, r3, r1
        } else if code == 23 {
            a32_dp(A32_AL, 2, 1, 4, 2, 0);              // subs r4, r2, r0
            a32_dp(A32_AL, 6, 0, 5, 3, 1);              // sbc r5, r3, r1
        } else if code == 24 {
            a32_dp(A32_AL, 0, 0, 4, 2, 0);
            a32_dp(A32_AL, 0, 0, 5, 3, 1);
        } else if code == 25 {
            a32_dp(A32_AL, 12, 0, 4, 2, 0);
            a32_dp(A32_AL, 12, 0, 5, 3, 1);
        } else {
            a32_dp(A32_AL, 1, 0, 4, 2, 0);
            a32_dp(A32_AL, 1, 0, 5, 3, 1);
        }
        if code != 27 {
            a32_w(0xE1A00F90 | (6 << 16) | (7 << 12) | 4);   // strexd r7, r4, r5, [r6]
            a32_dpi(A32_AL, 10, 1, 0, 7, 0);                 // cmp r7, #0
            int rel = (top - (a32_pos + 8)) / 4;
            a32_w(0x1A000000 | (rel & 16777215));            // bne top
            if code == 20 {
                a32_w(0xE320F000);                           // nop (the target of the skip above)
                a32_w(0xF57FF01F);                           // clrex
            }
        }
        a32_w(0xF57FF05B);                                   // dmb ish
        if d != 0 {
            a32_store(2, 3, d);
        }
        return true;
    }
    if op == IR_CLZ {
        a32_load(0, 1, ir_a[i]);
        a32_w(0xE16F0F10 | (2 << 12) | 1);                  // clz r2, r1
        a32_w(0xE16F0F10 | (3 << 12) | 0);                  // clz r3, r0
        a32_dpi(A32_AL, 4, 0, 3, 3, 32);                    // add r3, r3, #32
        a32_dpi(A32_AL, 10, 1, 0, 1, 0);                    // cmp r1, #0
        a32_mov(2, 2);
        a32_w(0x01A00003 | (2 << 12));                      // moveq r2, r3
        a32_const(3, 0);
        a32_store(2, 3, d);
        return true;
    }
    if op == IR_RBIT || op == IR_BSWAP {
        a32_load(0, 1, ir_a[i]);
        int rb = 0xE6FF0F30;
        if op == IR_BSWAP { rb = 0xE6BF0F30; }
        a32_w(rb | (2 << 12) | 1);                          // rbit / rev r2, r1
        a32_w(rb | (3 << 12) | 0);                          // rbit / rev r3, r0
        a32_store(2, 3, d);
        return true;
    }
    if op == IR_POPCNT {
        a32_load(0, 1, ir_a[i]);
        a32_popcnt32(2, 0);
        a32_popcnt32(3, 1);
        a32_dp(A32_AL, 4, 0, 2, 2, 3);                      // add r2, r2, r3
        a32_const(3, 0);
        a32_store(2, 3, d);
        return true;
    }
    if op == IR_ROTR || op == IR_ROTR32 {
        a32_load(0, 1, ir_a[i]);
        if ir_bi[i] == 1 { a32_const(2, ir_b[i] & 63); } else { a32_load(2, 3, ir_b[i]); }
        if op == IR_ROTR32 {
            a32_dpi(A32_AL, 0, 0, 2, 2, 31);                     // and r2, r2, #31
            a32_w(0xE1A00070 | (0 << 12) | (2 << 8) | 0);        // ror r0, r0, r2
            a32_const(1, 0);
            a32_store(0, 1, d);
            return true;
        }
        a32_dpi(A32_AL, 0, 0, 2, 2, 63);                     // and r2, r2, #63
        a32_str(6, 13, 0);                                   // r6 and r7 may hold variables: kept at the bottom of the frame
        a32_str(7, 13, 4);
        a32_mov(6, 0);
        a32_mov(7, 1);
        a32_shreg(1, 0, 1, 2);                               // r0:r1 = x >> n
        a32_dpi(A32_AL, 3, 0, 2, 2, 0);                      // rsb r2, r2, #0
        a32_dpi(A32_AL, 0, 0, 2, 2, 63);                     // and r2, r2, #63: (64 - n) mod 64
        a32_shreg(0, 6, 7, 2);                               // r6:r7 = x << (64 - n)
        a32_dp(A32_AL, 12, 0, 0, 0, 6);
        a32_dp(A32_AL, 12, 0, 1, 1, 7);
        a32_ldr(6, 13, 0);
        a32_ldr(7, 13, 4);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_FCONST {
        a32_const64(0, 1, ir_k[i]);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_BITS2F || op == IR_F2BITS {
        a32_load(0, 1, ir_a[i]);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV {
        // the operands and the result are used where they are when they live in d8 .. d15
        int fa = a32_dh(ir_a[i]);
        int fb = a32_dh(ir_b[i]);
        int fd = a32_dh(d);
        if fa < 0 { a32_dldv(0, ir_a[i]); fa = 0; }
        if fb < 0 { a32_dldv(1, ir_b[i]); fb = 1; }
        int fr = 0;
        if fd >= 0 { fr = fd; }
        if op == IR_FADD { a32_vfp(0xEE300B00, fr, fa, fb); }
        else if op == IR_FSUB { a32_vfp(0xEE300B40, fr, fa, fb); }
        else if op == IR_FMUL { a32_vfp(0xEE200B00, fr, fa, fb); }
        else { a32_vfp(0xEE800B00, fr, fa, fb); }
        if fd < 0 { a32_dstv(0, d); }
        return true;
    }
    if op == IR_FNEG || op == IR_FABS || op == IR_FSQRT {
        int ua = a32_dh(ir_a[i]);
        int ud = a32_dh(d);
        if ua < 0 { a32_dldv(0, ir_a[i]); ua = 0; }
        int ur = 0;
        if ud >= 0 { ur = ud; }
        if op == IR_FNEG { a32_vfp(0xEEB10B40, ur, 0, ua); }
        else if op == IR_FABS { a32_vfp(0xEEB00BC0, ur, 0, ua); }
        else { a32_vfp(0xEEB10BC0, ur, 0, ua); }
        if ud < 0 { a32_dstv(0, d); }
        return true;
    }
    if op == IR_FFLOOR || op == IR_FCEIL || op == IR_FTRUNC || op == IR_F2I {
        // routines of std/rt_a32.j on the bits (no instruction for them in VFPv3)
        a32_load(0, 1, ir_a[i]);
        a32_str(0, 13, 0);
        a32_str(1, 13, 4);
        if op == IR_FFLOOR { a32_bl("__a32_floor"); }
        else if op == IR_FCEIL { a32_bl("__a32_ceil"); }
        else if op == IR_FTRUNC { a32_bl("__a32_trunc"); }
        else { a32_bl("__a32_d2i"); }
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_I2F || op == IR_I2F32 {
        // the 64-bit whole number a is lo + hi * 2^32: (double)(unsigned lo) + (double)(signed hi) * 2^32, one rounding
        a32_load(0, 1, ir_a[i]);
        a32_w(0xEE000A10 | (0 << 16) | (0 << 12));          // vmov s0, r0
        a32_w(0xEE000A10 | (1 << 16) | (1 << 12));          // vmov s2, r1
        a32_w(0xEEB80B40);                                   // vcvt.f64.u32 d0, s0
        a32_w(0xEEB80BC0 | (1 << 12) | 1);                   // vcvt.f64.s32 d1, s2
        a32_const(2, 0);
        a32_const(3, 0x41F00000);
        a32_vmov_to_d(2, 2, 3);                              // d2 = 2^32
        a32_vfp(0xEE200B00, 1, 1, 2);                        // vmul.f64 d1, d1, d2
        a32_vfp(0xEE300B00, 0, 0, 1);                        // vadd.f64 d0, d0, d1
        if op == IR_I2F {
            a32_dstv(0, d);
        } else {
            a32_vfp(0xEEB70BC0, 0, 0, 0);                    // vcvt.f32.f64 s0, d0
            a32_vmem(false, true, 0, a32_cell(d));
        }
        return true;
    }
    if op == IR_FSETCC || op == IR_FBR {
        int ca = a32_dh(ir_a[i]);
        int cb = a32_dh(ir_b[i]);
        if ca < 0 { a32_dldv(0, ir_a[i]); ca = 0; }
        if cb < 0 { a32_dldv(1, ir_b[i]); cb = 1; }
        a32_w(0xEEB40B40 | (ca << 12) | cb);                // vcmp.f64 d(ca), d(cb)
        a32_w(0xEEF1FA10);                                   // vmrs APSR_nzcv, fpscr
        int fcc = ir_k[i];
        int arm = A32_NE;
        if fcc == IR_EQ { arm = A32_EQ; }
        else if fcc == IR_LT { arm = 4; }                    // mi: false for a NaN
        else if fcc == IR_LE { arm = 9; }                    // ls
        else if fcc == IR_GT { arm = 12; }
        else if fcc == IR_GE { arm = A32_GE; }
        if op == IR_FSETCC {
            a32_dpi(A32_AL, 13, 0, 0, 0, 0);
            a32_dpi(arm, 13, 0, 0, 0, 1);
            a32_dpi(A32_AL, 13, 0, 1, 0, 0);
            a32_store(0, 1, d);
        } else {
            a32_jump(arm, ir_t1[i]);
            if ir_t2[i] != b + 1 { a32_jump(A32_AL, ir_t2[i]); }
        }
        return true;
    }
    if op == IR_F32IN || op == IR_F32OUT {
        a32_load(0, 1, ir_a[i]);
        a32_const(1, 0);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_FADD32 || op == IR_FSUB32 || op == IR_FMUL32 || op == IR_FDIV32 {
        a32_vmem(true, true, 0, a32_cell(ir_a[i]));
        a32_vmem(true, true, 1, a32_cell(ir_b[i]));
        if op == IR_FADD32 { a32_vfp(0xEE300A00, 0, 0, 1); }
        else if op == IR_FSUB32 { a32_vfp(0xEE300A40, 0, 0, 1); }
        else if op == IR_FMUL32 { a32_vfp(0xEE200A00, 0, 0, 1); }
        else { a32_vfp(0xEE800A00, 0, 0, 1); }
        a32_vmem(false, true, 0, a32_cell(d));
        return true;
    }
    if op == IR_FUN32 {
        a32_vmem(true, true, 0, a32_cell(ir_a[i]));
        if ir_k[i] == 0 { a32_vfp(0xEEB10A40, 0, 0, 0); }
        else if ir_k[i] == 1 { a32_vfp(0xEEB00AC0, 0, 0, 0); }
        else { a32_vfp(0xEEB10AC0, 0, 0, 0); }
        a32_vmem(false, true, 0, a32_cell(d));
        return true;
    }
    if op == IR_FCVT_DS {
        a32_dldv(0, ir_a[i]);
        a32_vfp(0xEEB70BC0, 0, 0, 0);                        // vcvt.f32.f64 s0, d0
        a32_vmem(false, true, 0, a32_cell(d));
        return true;
    }
    if op == IR_FCVT_SD || op == IR_F32TOI {
        a32_vmem(true, true, 0, a32_cell(ir_a[i]));
        a32_vfp(0xEEB70AC0, 0, 0, 0);                        // vcvt.f64.f32 d0, s0
        if op == IR_FCVT_SD {
            a32_dstv(0, d);
        } else {
            a32_vmov_from_d(0, 1, 0);
            a32_str(0, 13, 0);
            a32_str(1, 13, 4);
            a32_bl("__a32_d2i");
            a32_store(0, 1, d);
        }
        return true;
    }
    if op == IR_ADDR_FUNC {
        // the address of a function: movw + movt, filled in at the end
        if a32_nc >= A32_MAXC { a32_fail("too many calls"); return false; }
        a32_cat[a32_nc] = a32_pos;
        a32_cfn[a32_nc] = a32_cur;
        a32_ckind[a32_nc] = 1;
        str_copy(@a32_cname + a32_nc * 64, @ir_name + ir_k[i] * 64, 64);
        a32_nc += 1;
        a32_w(0xE3000000);
        a32_w(0xE3400000);
        a32_const(1, 0);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_SDIV || op == IR_UDIV || op == IR_MULHS {
        // no instruction for these on the target: a routine of std/rt_a32.j (the arguments at the bottom of the frame, the result in r0:r1)
        a32_load(0, 1, ir_a[i]);
        a32_load_b(i);
        // the CPU has udiv / sdiv (the flag at 0x10000368 was set by the start: AT_HWCAP) and the numbers are 32 bits: one instruction; else the routine
        int fb1 = 0 - 1;
        int fb2 = 0 - 1;
        int fb3 = 0 - 1;
        int fb4 = 0 - 1;
        int fb5 = 0 - 1;
        int fbd = 0 - 1;
        if op == IR_UDIV || op == IR_SDIV {
            if op == IR_UDIV {
                a32_dp(A32_AL, 12, 1, 12, 1, 3);                 // orrs r12, r1, r3: both high words 0?
                fb1 = a32_pos;
                a32_w(0);                                        // bne slow
            } else {
                a32_w(0xE1A00040 | (12 << 12) | (31 << 7) | 0);  // mov r12, r0, asr #31
                a32_dp(A32_AL, 10, 1, 0, 12, 1);                 // cmp r12, r1
                fb1 = a32_pos;
                a32_w(0);                                        // bne slow
                a32_w(0xE1A00040 | (12 << 12) | (31 << 7) | 2);  // mov r12, r2, asr #31
                a32_dp(A32_AL, 10, 1, 0, 12, 3);                 // cmp r12, r3
                fb5 = a32_pos;
                a32_w(0);                                        // bne slow
                a32_dpi(A32_AL, 11, 1, 0, 2, 1);                 // cmn r2, #1: b = -1 (the quotient may not fit)
                fb4 = a32_pos;
                a32_w(0);                                        // beq slow
            }
            a32_dpi(A32_AL, 10, 1, 0, 2, 0);                     // cmp r2, #0
            fb2 = a32_pos;
            a32_w(0);                                            // beq slow (the routine says: division by zero)
            a32_const(12, 268435456 + 872);
            a32_ldr(12, 12, 0);
            a32_dpi(A32_AL, 10, 1, 0, 12, 0);                    // cmp r12, #0
            fb3 = a32_pos;
            a32_w(0);                                            // beq slow
            if op == IR_UDIV { a32_w(0xE730F210); } else { a32_w(0xE710F210); }       // udiv / sdiv r0, r0, r2
            if op == IR_UDIV { a32_const(1, 0); } else { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); }       // r1 = 0, or the sign of r0
            fbd = a32_pos;
            a32_w(0);                                            // b done
            int slow = a32_pos;
            if fb1 >= 0 { a32_set(fb1, (1 << 28) | 0x0A000000 | (((slow - (fb1 + 8)) / 4) & 16777215)); }          // bne
            if fb5 >= 0 { a32_set(fb5, (1 << 28) | 0x0A000000 | (((slow - (fb5 + 8)) / 4) & 16777215)); }
            if fb4 >= 0 { a32_set(fb4, 0x0A000000 | (((slow - (fb4 + 8)) / 4) & 16777215)); }                       // beq
            a32_set(fb2, 0x0A000000 | (((slow - (fb2 + 8)) / 4) & 16777215));
            a32_set(fb3, 0x0A000000 | (((slow - (fb3 + 8)) / 4) & 16777215));
        }
        a32_str(0, 13, 0);
        a32_str(1, 13, 4);
        a32_str(2, 13, 8);
        a32_str(3, 13, 12);
        if op == IR_SDIV { a32_bl("__a32_sdiv"); }
        else if op == IR_UDIV { a32_bl("__a32_udiv"); }
        else { a32_bl("__a32_mulhs"); }
        if fbd >= 0 { a32_set(fbd, 0xEA000000 | (((a32_pos - (fbd + 8)) / 4) & 16777215)); }                          // b done
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_SYSCALL && ir_k[i] == 0 && a32_wrap_ok == 1 {
        // a system call of the program: through __a32_sys (std/rt_a32.j), which adapts the structures whose layout differs (timespec ...)
        a32_load(0, 1, ir_a[i]);
        a32_str(0, 13, 0);
        a32_str(1, 13, 4);
        int wk = 0;
        while wk < 6 {
            if wk < ir_ac[i] { a32_load(0, 1, ir_args[ir_as[i] + wk]); } else { a32_const(0, 0); a32_const(1, 0); }
            a32_str(0, 13, 8 * (wk + 1));
            a32_str(1, 13, 8 * (wk + 1) + 4);
            wk += 1;
        }
        a32_bl("__a32_sys");
        if d != 0 { a32_store(0, 1, d); }
        return true;
    }
    if op == IR_SYSCALL {
        // the number is the one of the ARM64 table (the library and the runtime are written with it): translated here
        int k = 0;
        while k < 6 && k < ir_ac[i] {
            a32_load(k, 14, ir_args[ir_as[i] + k]);
            k += 1;
        }
        a32_load(7, 14, ir_a[i]);
        // r7 = the ARM32 number: the table of 512 half-words behind the global area, indexed by the ARM64 number (0: ENOSYS)
        a32_const(12, 268435456 + a32_systab());
        a32_w(0xE08CC087);                               // add r12, r12, r7, lsl #1
        a32_w(0xE1DC70B0);                               // ldrh r7, [r12]
        a32_dpi(A32_AL, 10, 1, 0, 7, 0);                 // cmp r7, #0
        a32_const_cc(A32_EQ, 7, 4095);                   // moveq r7, #4095: a number the kernel does not have
        a32_w(0xEF000000);                          // svc 0
        if d != 0 {
            // an error is -4095 .. -1 (sign extended); any other 32-bit result is an address or a count (zero extended)
            a32_w(0xE3700A01);                       // cmn r0, #4096: the carry is set for 0xFFFFF000 .. 0xFFFFFFFF
            a32_dpi(A32_AL, 13, 0, 1, 0, 0);         // mov r1, #0
            a32_dpi(A32_CS, 15, 0, 1, 0, 0);         // mvncs r1, #0
            a32_store(0, 1, d);
        }
        return true;
    }
    if op == IR_LCALL {
        // a local call (a defer body): bl to the block, filled in at the end of the function
        if a32_nlc >= 1024 { a32_fail("too many local calls"); return false; }
        a32_lcat[a32_nlc] = a32_pos;
        a32_lcblk[a32_nlc] = ir_t1[i];
        a32_nlc += 1;
        a32_w(0);
        return true;
    }
    if op == IR_LENTRY {
        a32_str(14, 13, a32_cell(31));
        a32_dpi(A32_AL, 13, 0, 1, 0, 0);
        a32_str(1, 13, a32_cell(31) + 4);
        return true;
    }
    if op == IR_LRET {
        a32_ldr(0, 13, a32_cell(31));
        a32_w(0xE12FFF10);                          // bx r0
        return true;
    }
    if op == IR_ADDR_BLOCK {
        // the address of a routine (made after the code of the function) that runs the block on the frame of this function
        if a32_nc >= A32_MAXC || a32_nth >= 64 { a32_fail("too many calls"); return false; }
        char tn[64];
        a32_thname(@tn, a32_thg);
        a32_thg += 1;
        str_copy(@a32_thn + a32_nth * 64, @tn, 64);
        a32_thblk[a32_nth] = ir_t1[i];
        a32_nth += 1;
        a32_cat[a32_nc] = a32_pos;
        a32_cfn[a32_nc] = a32_cur;
        a32_ckind[a32_nc] = 1;
        str_copy(@a32_cname + a32_nc * 64, @tn, 64);
        a32_nc += 1;
        a32_w(0xE3000000);
        a32_w(0xE3400000);
        a32_const(1, 0);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_JMP {
        if ir_t1[i] != b + 1 { a32_jump(A32_AL, ir_t1[i]); }
        return true;
    }
    if op == IR_BR {
        int bnum2 = 0;
        if ir_bi[i] == 1 { bnum2 = ir_b[i]; }
        int cc2 = a32_compare(ir_k[i], ir_a[i], ir_b[i], ir_bi[i], bnum2);
        a32_jump(cc2, ir_t1[i]);
        if ir_t2[i] != b + 1 { a32_jump(A32_AL, ir_t2[i]); }
        return true;
    }
    if op == IR_RET {
        if ir_a[i] != 0 { a32_load(0, 1, ir_a[i]); }
        a32_epilogue();
        return true;
    }
    if op == IR_TRAP {
        a32_w(0xE1200070);                          // bkpt
        return true;
    }
    a32_fail("an IR instruction that is not made yet");
    str_copy(@a32_why, "the IR instruction ", 128);
    str_copy(@a32_why + str_len(@a32_why), ir_opname(op), 40);
    return false;
}

// a function that the lifter could not read: known by name, not made
void a32_unlifted(char^ name, char^ why) {
    if a32_nf >= A32_MAXF { return; }
    str_copy(@a32_fname + a32_nf * 64, name, 64);
    a32_foff[a32_nf] = 0;
    a32_fok[a32_nf] = 0;
    str_copy(@a32_fwhy + a32_nf * 128, "it is not lifted to the IR: ", 128);
    str_copy(@a32_fwhy + a32_nf * 128 + 28, why, 100);
    a32_nf += 1;
}

// the index of the frame slot that a load or a store of the width w at v30 + k is: k / 8 for a place of 8 bytes at a multiple of 8, 8192 + k / 8 for a cell
// below the frame pointer; -1 when it is another kind of access
int a32_slot_index(int k, int w) {
    if w != 8 { return 0 - 1; }
    if k >= 0 {
        if k % 8 == 0 && k / 8 < 8192 { return k / 8; }
        return 0 - 1;
    }
    if (0 - k) % 8 == 0 && (0 - k) / 8 < 8192 { return 8192 + (0 - k) / 8; }
    return 0 - 1;
}

void a32_slot_touch(int idx, int weight) {
    if a32_sst[idx] != a32_sstamp {
        a32_sst[idx] = a32_sstamp;
        a32_scnt[idx] = 0;
        a32_sbad[idx] = 0;
        a32_sreg[idx] = 0 - 1;
    }
    a32_scnt[idx] += weight;
}

void a32_slot_bad_range(int k, int w) {
    // an access that is not a plain 8-byte one: every word it touches is not for a register
    int aw = w;
    if aw < 0 { aw = 0 - aw; }
    if aw < 1 { aw = 1; }
    int lo = k;
    int hi = k + aw - 1;
    int a = lo;
    if a < 0 { a = 0 - ((0 - a + 7) / 8) * 8; } else { a = a / 8 * 8; }
    while a <= hi {
        int idx = 0 - 1;
        if a >= 0 { if a / 8 < 8192 { idx = a / 8; } } else { if (0 - a) / 8 < 8192 { idx = 8192 + (0 - a) / 8; } }
        if idx >= 0 {
            a32_slot_touch(idx, 0);
            a32_sbad[idx] = 1;
        }
        a += 8;
    }
}

void a32_itouch(int v, int w) {
    if v <= 0 || v >= IR_MAXV || v == 28 || v == 29 || v == 30 || v == 31 { return; }
    if ir_vcls[v] != 0 { return; }
    if a32_iseen[v] != a32_istamp {
        a32_iseen[v] = a32_istamp;
        a32_icnt[v] = 0;
    }
    a32_icnt[v] += w;
}

void a32_dtouch(int v, int w) {
    if v <= 0 || v >= IR_MAXV { return; }
    if ir_vcls[v] != 1 { return; }
    if a32_dseen[v] != a32_dstamp {
        a32_dseen[v] = a32_dstamp;
        a32_dcnt[v] = 0;
    }
    a32_dcnt[v] += w;
}

void a32_dnot(int v) {
    if v > 0 && v < IR_MAXV { a32_dbad[v] = a32_dstamp; }
}

// the doubles that are used most go to d8 .. d15 for the whole function (a vreg that a single precision operation reads or writes does not)
void a32_plan_doubles() {
    int b = 0;
    while b < ir_nb {
        int wgt = 1;
        int dd = a32_bdepth[b];
        while dd > 0 && wgt < 4096 { wgt = wgt * 8; dd -= 1; }
        int j = ir_bs[b];
        while j < ir_be[b] {
            int o = ir_op[j];
            a32_dtouch(ir_d[j], wgt);
            if ir_a[j] > 0 { a32_dtouch(ir_a[j], wgt); }
            if ir_uses_b(o) && ir_bi[j] == 0 && ir_b[j] > 0 { a32_dtouch(ir_b[j], wgt); }
            if o == IR_CALL || o == IR_CALLIND || o == IR_SYSCALL || o == IR_ATOMIC {
                int ak = 0;
                while ak < ir_ac[j] {
                    a32_dtouch(ir_args[ir_as[j] + ak], wgt);
                    ak += 1;
                }
            }
            if o == IR_FADD32 || o == IR_FSUB32 || o == IR_FMUL32 || o == IR_FDIV32 {
                a32_dnot(ir_d[j]);
                a32_dnot(ir_a[j]);
                a32_dnot(ir_b[j]);
            }
            if o == IR_FUN32 { a32_dnot(ir_d[j]); a32_dnot(ir_a[j]); }
            if o == IR_FCVT_DS || o == IR_I2F32 { a32_dnot(ir_d[j]); }
            if o == IR_FCVT_SD || o == IR_F32TOI { a32_dnot(ir_a[j]); }
            j += 1;
        }
        b += 1;
    }
    int k = 0;
    while k < 8 {
        int best = 0 - 1;
        int bw = 3;
        int v = 1;
        while v < ir_nv && v < IR_MAXV {
            if a32_dseen[v] == a32_dstamp && a32_dbad[v] != a32_dstamp && a32_dst[v] != a32_dstamp && ir_vcls[v] == 1 && a32_dcnt[v] > bw {
                best = v;
                bw = a32_dcnt[v];
            }
            v += 1;
        }
        if best < 0 { break; }
        a32_dst[best] = a32_dstamp;
        a32_dhome[best] = 8 + k;
        a32_dmask = a32_dmask | (1 << k);
        k += 1;
    }
}

// which variables of the frame go to registers (r4 r5 and r8 r9), and which functions have to save the registers
void a32_plan_regs() {
    a32_salloc = 0;
    a32_special = 0;
    a32_nsave = 0;
    a32_dmask = 0;
    a32_dstamp += 1;
    a32_istamp += 1;
    a32_ialloc = 0;
    a32_sstamp += 1;
    bool noalloc = a32_elide_off == 2;
    bool negescape = false;
    int i = 0;
    while i < ir_n {
        int op = ir_op[i];
        if op == IR_ATOMIC || op == IR_POPCNT || op == IR_RAW { a32_special = 1; }
        if op == IR_SYSCALL && ir_k[i] != 0 { a32_special = 1; }
        if op == IR_LCALL || op == IR_LRET || op == IR_LENTRY || op == IR_ADDR_BLOCK { noalloc = true; }
        if op == IR_CALL {
            char^ cn = @ir_name + ir_k[i] * 64;
            if str_eq(cn, "j2k_try_enter") || str_eq(cn, "j2k_try_leave") || str_eq(cn, "j2k_throw") || str_eq(cn, "j2k_thread_start") { a32_special = 1; noalloc = true; }
            if str_eq(cn, "j2k_try_enter") { a32_dmask = 255; }          // a catch point: d8 .. d15 come back as they were when it was entered
            if str_eq(cn, "__Mt__run") { noalloc = true; }
        }
        // the frame pointer as a value (not as the base of an access, not in `add v30, number`): the frame is reached in other ways
        if op == IR_LOAD || op == IR_STORE {
            if ir_a[i] != 30 && op == IR_STORE && ir_b[i] == 30 { noalloc = true; }
        } else if op == IR_ADD && ir_a[i] == 30 && ir_bi[i] == 1 {
            if ir_b[i] < 0 { negescape = true; }
        } else if op == IR_ADDR_SLOT {
        } else {
            if ir_a[i] == 30 && op != IR_ADDR_SLOT { noalloc = true; }
            if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30 { noalloc = true; }
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_ATOMIC {
                int ak = 0;
                while ak < ir_ac[i] {
                    if ir_args[ir_as[i] + ak] == 30 { noalloc = true; }
                    ak += 1;
                }
            }
        }
        i += 1;
    }
    if noalloc || a32_special == 1 {
        if a32_special == 1 { a32_nsave = 4; }
        return;
    }
    // how deep in loops each block is (a jump back to a block that is not after it)
    int b = 0;
    while b < ir_nb {
        a32_bdepth[b] = 0;
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        int ee = ir_be[b] - 1;
        int eo = ir_op[ee];
        int t1 = 0 - 1;
        int t2 = 0 - 1;
        if eo == IR_JMP { t1 = ir_t1[ee]; }
        if eo == IR_BR || eo == IR_FBR { t1 = ir_t1[ee]; t2 = ir_t2[ee]; }
        if t1 >= 0 && t1 <= b { int x = t1; while x <= b { a32_bdepth[x] += 1; x += 1; } }
        if t2 >= 0 && t2 <= b { int x2 = t2; while x2 <= b { a32_bdepth[x2] += 1; x2 += 1; } }
        b += 1;
    }
    // the uses of the slots
    b = 0;
    while b < ir_nb {
        int wgt = 1;
        int dd = a32_bdepth[b];
        while dd > 0 && wgt < 4096 { wgt = wgt * 8; dd -= 1; }
        int j = ir_bs[b];
        while j < ir_be[b] {
            int o = ir_op[j];
            if (o == IR_LOAD || o == IR_STORE) && ir_a[j] == 30 {
                int idx = a32_slot_index(ir_k[j], ir_w[j]);
                if idx >= 0 { a32_slot_touch(idx, wgt); } else { a32_slot_bad_range(ir_k[j], ir_w[j]); }
            } else if o == IR_ADD && ir_a[j] == 30 && ir_bi[j] == 1 {
                // the address of something in the frame: a word that it starts at cannot be in a register
                a32_slot_bad_range(ir_b[j], 8);
            }
            if a32_noireg == 0 {
                a32_itouch(ir_d[j], wgt);
                if ir_a[j] > 0 { a32_itouch(ir_a[j], wgt); }
                if ir_uses_b(o) && ir_bi[j] == 0 && ir_b[j] > 0 { a32_itouch(ir_b[j], wgt); }
                if o == IR_CALL || o == IR_CALLIND || o == IR_SYSCALL || o == IR_ATOMIC {
                    int iak = 0;
                    while iak < ir_ac[j] {
                        a32_itouch(ir_args[ir_as[j] + iak], wgt);
                        iak += 1;
                    }
                }
            }
            j += 1;
        }
        b += 1;
    }
    // the two used most
    int pick = 0;
    while pick < 3 {
        int best = 0 - 1;
        int bw = 3;
        int idx2 = 0;
        // only the slots seen in this function: walk the instructions again for the candidates
        int j2 = 0;
        while j2 < ir_n {
            if (ir_op[j2] == IR_LOAD || ir_op[j2] == IR_STORE) && ir_a[j2] == 30 {
                idx2 = a32_slot_index(ir_k[j2], ir_w[j2]);
                if idx2 >= 0 && a32_sst[idx2] == a32_sstamp && a32_sbad[idx2] == 0 && a32_sreg[idx2] < 0 && a32_scnt[idx2] > bw {
                    bool ok = true;
                    if idx2 < 8192 { ok = op_plain[idx2] == 1; } else { ok = !negescape; }
                    if ok { best = idx2; bw = a32_scnt[idx2]; }
                }
            }
            j2 += 1;
        }
        // a whole number vreg that is used more than the best slot
        int vbest = 0 - 1;
        if a32_noireg == 0 {
            int vw = bw;
            if best < 0 { vw = 3; }
            int vv = 1;
            while vv < ir_nv && vv < IR_MAXV {
                if a32_iseen[vv] == a32_istamp && a32_ist[vv] != a32_istamp && a32_icnt[vv] > vw {
                    vbest = vv;
                    vw = a32_icnt[vv];
                }
                vv += 1;
            }
        }
        if vbest >= 0 {
            a32_ist[vbest] = a32_istamp;
            a32_ihome[vbest] = 4;                                 // the pairs go in the order r4:r5, r8:r9, r6:r7 (as for the variables of the frame)
            if pick == 1 { a32_ihome[vbest] = 8; }
            if pick == 2 { a32_ihome[vbest] = 6; }
            a32_ialloc = 1;
            pick += 1;
        } else {
            if best < 0 { break; }
            a32_sreg[best] = pick;
            a32_salloc = 1;
            pick += 1;
        }
    }
    if a32_salloc == 1 || a32_ialloc == 1 || a32_special == 1 { a32_nsave = 4; }
    if a32_nodreg == 0 { a32_plan_doubles(); }
}

// which results are never read: a backward walk over every block from the live-out registers of the function's liveness
void a32_compute_dead() {
    a32_elide = 0;
    if a32_elide_off == 1 { return; }
    int i = 0;
    while i < ir_n {
        int o = ir_op[i];
        if o == IR_LCALL || o == IR_LRET || o == IR_LENTRY || o == IR_ADDR_BLOCK || o == IR_RAW { return; }
        i += 1;
    }
    op_liveness();
    int b = 0;
    while b < ir_nb {
        a32_lvstamp += 1;
        int v = 1;
        while v < 64 {
            if ((op_lo[b] >> v) & 1) == 1 { a32_lvs[v] = a32_lvstamp; }
            v += 1;
        }
        // the high words: every live-out vreg has its high word wanted
        v = 1;
        while v < 64 {
            if ((op_lo[b] >> v) & 1) == 1 { a32_hid[v] = a32_lvstamp; }
            v += 1;
        }
        int cj = ir_bs[b];
        while cj < ir_be[b] {
            a32_chain[cj] = 0;
            cj += 1;
        }
        int j = ir_be[b] - 1;
        while j >= ir_bs[b] {
            int d = ir_d[j];
            int op = ir_op[j];
            a32_dead[j] = 0;
            a32_nohi[j] = 0;
            // the result of the instruction before is read by this one only, and as its first operand: no store for it (a32_chain, set here, read when that instruction comes)
            if j > ir_bs[b] {
                int pd = ir_d[j - 1];
                if pd > 0 && pd < IR_MAXV && ir_vcls[pd] == 0 && (pd <= 27 || pd >= 64) && ir_a[j] == pd && (ir_d[j] == pd || a32_lvs[pd] != a32_lvstamp) && (ir_d[j] == 0 || ir_vcls[ir_d[j]] == 0) {
                    bool okop = op == IR_COPY || op == IR_ADD || op == IR_SUB || op == IR_AND || op == IR_OR || op == IR_XOR || op == IR_MUL || op == IR_NEG || op == IR_NOT || op == IR_BR || op == IR_SETCC;
                    if (op == IR_SHL || op == IR_LSHR || op == IR_ASHR) && ir_bi[j] == 1 { okop = true; }
                    if okop && !(ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] == pd) && ir_a[j] != 30 { a32_chain[j - 1] = 1; }
                }
            }
            if d > 0 && d < IR_MAXV && ir_vcls[d] == 0 && (d <= 27 || d >= 64) && a32_lvs[d] != a32_lvstamp { a32_dead[j] = 1; }
            if a32_chain[j] == 1 { a32_dead[j] = 1; }
            if d > 0 && d < IR_MAXV && ir_vcls[d] == 0 && (d <= 27 || d >= 64) && a32_hid[d] != a32_lvstamp { a32_nohi[j] = 1; }
            if d > 0 && d < IR_MAXV { a32_lvs[d] = 0; a32_hid[d] = 0; }
            // the low word of the result of these depends on the low words of the operands only: when the high word of the result is not wanted, theirs is not either
            bool lowonly = a32_nohi[j] == 1 && (op == IR_ADD || op == IR_SUB || op == IR_AND || op == IR_OR || op == IR_XOR || op == IR_COPY || op == IR_SHL || op == IR_MUL || op == IR_NEG || op == IR_NOT);
            if ir_a[j] > 0 && !lowonly && !((op == IR_LOAD || op == IR_STORE)) { a32_hid[ir_a[j]] = a32_lvstamp; }
            if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 && !lowonly {
                // a store of a number narrower than 8 bytes wants the low word only
                int sw = ir_w[j];
                if sw < 0 { sw = 0 - sw; }
                if !(op == IR_STORE && sw < 8) { a32_hid[ir_b[j]] = a32_lvstamp; }
            }
            if ir_a[j] > 0 { a32_lvs[ir_a[j]] = a32_lvstamp; }
            if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 { a32_lvs[ir_b[j]] = a32_lvstamp; }
            if (op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_ATOMIC) {
                int ak2 = 0;
                while ak2 < ir_ac[j] {
                    a32_hid[ir_args[ir_as[j] + ak2]] = a32_lvstamp;
                    ak2 += 1;
                }
            }
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_ATOMIC {
                int ak = 0;
                while ak < ir_ac[j] {
                    a32_lvs[ir_args[ir_as[j] + ak]] = a32_lvstamp;
                    ak += 1;
                }
            }
            j -= 1;
        }
        b += 1;
    }
    a32_elide = 1;
}

// the function in the IR (ir_fname) becomes code
void a32_function() {
    if a32_nf >= A32_MAXF { die("the ARM32 back end: too many functions"); }
    a32_cur = a32_nf;
    a32_nf += 1;
    str_copy(@a32_fname + a32_cur * 64, @ir_fname, 64);
    a32_foff[a32_cur] = a32_pos;
    a32_fok[a32_cur] = 0;
    a32_bad = 0;
    a32_nj = 0;
    a32_nlc = 0;
    a32_nth = 0;
    a32_wrap_ok = 1;
    a32_ebad = 0;
    a32_chp = 0;
    a32_chn = 0;
    a32_skipd = 0;
    a32_skipped = 0;
    a32_compute_dead();
    vn_hints();
    a32_plan_regs();
    int mark = a32_pos;
    int markc = a32_nc;
    // the frame: the arguments of the calls, the frame of the function (lf_frame), the cells, the cells of the virtual registers
    int maxq = 0;
    int maxargs = 0;
    int i = 0;
    while i < ir_n {
        if (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE) && ir_a[i] == 30 && ir_k[i] < 0 {
            int q = 0 - ir_k[i];
            if q > maxq { maxq = q; }
        }
        if (ir_op[i] == IR_CALL || ir_op[i] == IR_CALLIND) && ir_ac[i] > maxargs { maxargs = ir_ac[i]; }
        if (ir_op[i] == IR_SDIV || ir_op[i] == IR_UDIV || ir_op[i] == IR_MULHS) && maxargs < 2 { maxargs = 2; }
        if ir_op[i] == IR_SYSCALL && ir_k[i] == 0 && maxargs < 7 { maxargs = 7; }
        if ir_op[i] == IR_ATOMIC && ir_k[i] == 43 && maxargs < 1 { maxargs = 1; }
        if ir_op[i] == IR_ROTR && maxargs < 1 { maxargs = 1; }
        if (ir_op[i] == IR_FFLOOR || ir_op[i] == IR_FCEIL || ir_op[i] == IR_FTRUNC || ir_op[i] == IR_F2I || ir_op[i] == IR_F32TOI) && maxargs < 1 { maxargs = 1; }
        i += 1;
    }
    a32_outb = maxargs * 8;
    a32_cellbase = a32_outb + lf_frame + maxq;
    a32_vbase = a32_cellbase;
    a32_dsoff = a32_cellbase;
    if a32_nsave > 0 { a32_dsoff = a32_cellbase + 24; }          // r4 .. r9 are saved here
    a32_vbase = a32_dsoff;
    if a32_dmask != 0 { a32_vbase = a32_dsoff + 64; }            // d8 .. d15 are saved here
    int v = 0;
    while v < ir_nv && v < IR_MAXV {
        a32_vmap[v] = 0 - 1;
        v += 1;
    }
    a32_nvc = 0;
    // the cells of the virtual registers: counted first (a first run that writes nothing), so that the frame size is known
    int save = a32_pos;
    a32_total = 0;
    int b = 0;
    while b < ir_nb {
        int k = ir_bs[b];
        while k < ir_be[b] {
            a32_scan(k);
            k += 1;
        }
        b += 1;
    }
    a32_pos = save;
    a32_total = (a32_vbase + a32_nvc * 8 + 7) / 8 * 8;
    // the code
    a32_const(12, a32_total);
    a32_dp(A32_AL, 2, 0, 13, 13, 12);              // sub sp, sp, r12
    a32_str(14, 13, a32_outb + 8);                 // the return address
    if a32_nsave > 0 {
        a32_str(4, 13, a32_cellbase);
        a32_str(5, 13, a32_cellbase + 4);
        a32_str(6, 13, a32_cellbase + 8);
        a32_str(7, 13, a32_cellbase + 12);
        a32_str(8, 13, a32_cellbase + 16);
        a32_str(9, 13, a32_cellbase + 20);
    }
    if a32_dmask != 0 {
        int sk = 0;
        while sk < 8 {
            if ((a32_dmask >> sk) & 1) == 1 { a32_vmem(false, false, 8 + sk, a32_dsoff + sk * 8); }
            sk += 1;
        }
    }
    b = 0;
    while b < ir_nb && a32_bad == 0 {
        a32_boff[b] = a32_pos;
        a32_blkver += 1;
        a32_cv = 0 - 1;
        a32_clo = 0 - 1;
        a32_chn = 0;
        a32_dcoff = 0 - 1;
        int k2 = ir_bs[b];
        while k2 < ir_be[b] && a32_bad == 0 {
            a32_skipd = 0;
            a32_skipped = 0;
            a32_nohi_cur = 0;
            a32_chp = a32_chn;
            a32_chn = 0;
            a32_chmode = 0;
            // a result that lives in a register of its own is always written there: never left out, never only in r0:r1
            bool dhome = ir_d[k2] > 0 && a32_ih(ir_d[k2]) >= 0;
            if a32_elide == 1 && a32_chain[k2] == 1 && !dhome { a32_chmode = 1; }
            if a32_elide == 1 && a32_dead[k2] == 1 && !dhome { a32_skipd = ir_d[k2]; }
            if a32_elide == 1 && a32_nohi[k2] == 1 { a32_nohi_cur = 1; }
            if !a32_instr(k2, b) { a32_fail("an instruction"); }
            a32_skipd = 0;
            a32_nohi_cur = 0;
            a32_chp = 0;
            a32_chmode = 0;
            int kop = ir_op[k2];
            if kop == IR_LCALL || kop == IR_RAW { a32_blkver += 1; a32_cv = 0 - 1; a32_clo = 0 - 1; a32_dcoff = 0 - 1; }          // the code of the program changed the registers: nothing is known any more
            if ir_d[k2] > 0 && ir_d[k2] < IR_MAXV {
                a32_kver[ir_d[k2]] = 0 - 1;
                if kop == IR_CONST && ir_vcls[ir_d[k2]] == 0 {
                    a32_kver[ir_d[k2]] = a32_blkver;
                    a32_kval[ir_d[k2]] = ir_k[k2];
                }
            }
            k2 += 1;
        }
        b += 1;
    }
if a32_ebad == 1 && a32_bad == 0 {
        // a result that was not stored was loaded in the same instruction: again with all the stores
        a32_elide_off = 1;
        a32_pos = mark;
        a32_nc = markc;
        a32_nf = a32_cur;
        a32_function();
        a32_elide_off = 0;
        return;
    }
    // the routines that run a defer body for the unwinder: x0 = the frame pointer; sp becomes the sp of this function, the state of the unwinder is kept in the thread block
    int tk = 0;
    while tk < a32_nth && a32_bad == 0 {
        a32_cur2 = a32_nf;
        a32_nf += 1;
        str_copy(@a32_fname + a32_cur2 * 64, @a32_thn + tk * 64, 64);
        a32_foff[a32_cur2] = a32_pos;
        a32_fok[a32_cur2] = 1;
        a32_ldr(0, 13, 0);
        a32_str(13, 10, 768);
        a32_str(14, 10, 772);
        a32_const(1, a32_outb);
        a32_dp(A32_AL, 2, 0, 13, 0, 1);               // sub sp, r0, r1
        if a32_nlc >= 1024 { a32_fail("too many local calls"); break; }
        a32_lcat[a32_nlc] = a32_pos;
        a32_lcblk[a32_nlc] = a32_thblk[tk];
        a32_nlc += 1;
        a32_w(0);
        a32_ldr(13, 10, 768);
        a32_ldr(14, 10, 772);
        a32_w(0xE12FFF1E);                            // bx lr
        tk += 1;
    }
    int lk = 0;
    while lk < a32_nlc && a32_bad == 0 {
        int lt = a32_boff[a32_lcblk[lk]];
        int lrel = (lt - (a32_lcat[lk] + 8)) / 4;
        a32_set(a32_lcat[lk], 0xEB000000 | (lrel & 16777215));
        lk += 1;
    }
    // the jumps
    int j = 0;
    while j < a32_nj && a32_bad == 0 {
        int target = a32_boff[a32_jblk[j]];
        int rel = (target - (a32_jat[j] + 8)) / 4;
        a32_set(a32_jat[j], (a32_jcond[j] << 28) | 0x0A000000 | (rel & 16777215));
        j += 1;
    }
    if a32_bad == 1 {
        a32_pos = mark;
        a32_nc = markc;
        a32_nf = a32_cur + 1;
        str_copy(@a32_fwhy + a32_cur * 128, @a32_why, 128);
        return;
    }
    a32_fok[a32_cur] = 1;
}

// the first run: only the virtual registers that the instruction uses are counted (they get their cells)
void a32_scan(int i) {
    int op = ir_op[i];
    if ir_d[i] != 0 { a32_cell(ir_d[i]); }
    if ir_a[i] != 0 && ir_a[i] != 29 && ir_a[i] != 28 { a32_cell(ir_a[i]); }
    if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] != 0 && ir_b[i] != 29 && ir_b[i] != 28 { a32_cell(ir_b[i]); }
    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        int k = 0;
        while k < ir_ac[i] {
            a32_cell(ir_args[ir_as[i] + k]);
            k += 1;
        }
    }
}

// -target arm32: the number of instructions of the function name (the code up to the next function), -1 when it was not made
int a32_instr_count(char^ name) {
    int g = 0 - 1;
    int f = 0;
    while f < a32_nf {
        if str_eq(@a32_fname + f * 64, name) { g = f; }
        f += 1;
    }
    if g < 0 || a32_fok[g] == 0 { return 0 - 1; }
    int end = a32_pos;
    f = 0;
    while f < a32_nf {
        if a32_fok[f] == 1 && a32_foff[f] > a32_foff[g] && a32_foff[f] < end { end = a32_foff[f]; }
        f += 1;
    }
    return (end - a32_foff[g]) / 4;
}

// does the text hold the word?
bool a32_has(char^ text, char^ word) {
    int n = str_len(word);
    int i = 0;
    while text[i] != 0 {
        int k = 0;
        while k < n && text[i + k] == word[k] { k += 1; }
        if k == n { return true; }
        i += 1;
    }
    return false;
}

// the 32 bit ELF file
char a32_hdr[116];
char a32_mapbuf[2097152];

void a32_hput(int at, int bytes, int v) {
    int i = 0;
    while i < bytes {
        a32_hdr[at + i] = (v >> (8 * i)) & 255;
        i += 1;
    }
}

// the function a call goes to: by its name, else the routine of std/rt_a32.j that replaces the assembly routine j2k_xxx (__a32_xxx); -1: none
int a32_find(char^ name) {
    int g = 0 - 1;
    int f = 0;
    while f < a32_nf {
        if str_eq(@a32_fname + f * 64, name) { g = f; }
        f += 1;
    }
    if (g < 0 || a32_fok[g] == 0) && name[0] == 'j' && name[1] == '2' && name[2] == 'k' && name[3] == '_' {
        char alt[80];
        str_copy(@alt, "__a32_", 80);
        str_copy(@alt + 6, name + 4, 70);
        f = 0;
        while f < a32_nf {
            if str_eq(@a32_fname + f * 64, @alt) && a32_fok[f] == 1 { g = f; }
            f += 1;
        }
    }
    return g;
}

// ---- the routines of try / catch / throw, by hand (they work on sp and lr): j2k_try_enter, j2k_try_leave, j2k_throw
// The block of the thread is at 0x10000048: [0] the thrown value, [8] the depth, entry i at 32 * i: sp [+16], lr [+32], head of the cleanup chain [+40];
// the head of the cleanup chain (a list of records: next, address, function, mode) is at [784]; [768..783]: sp, lr of a defer body run by the unwinder and the state of the unwinder (the block is 792 bytes).
int a32_xl_at[8];                 // the places of the labels of the routine being written
int a32_xp_at[16];                // the branches to patch: place, label, condition
int a32_xp_lab[16];
int a32_xp_cond[16];
int a32_xp_n;

void a32_xbranch(int cond, int lab) {
    a32_xp_at[a32_xp_n] = a32_pos;
    a32_xp_lab[a32_xp_n] = lab;
    a32_xp_cond[a32_xp_n] = cond;
    a32_xp_n += 1;
    a32_w(0);
}

void a32_xplace(int lab) {
    a32_xl_at[lab] = a32_pos;
}

void a32_xpatch() {
    int i = 0;
    while i < a32_xp_n {
        int rel = (a32_xl_at[a32_xp_lab[i]] - (a32_xp_at[i] + 8)) / 4;
        a32_set(a32_xp_at[i], (a32_xp_cond[i] << 28) | 0x0A000000 | (rel & 16777215));
        i += 1;
    }
    a32_xp_n = 0;
}

// a function made by hand: registered as made, called by its name
void a32_xfunc(char^ name) {
    a32_cur = a32_nf;
    a32_nf += 1;
    str_copy(@a32_fname + a32_cur * 64, name, 64);
    a32_foff[a32_cur] = a32_pos;
    a32_fok[a32_cur] = 1;
    a32_xp_n = 0;
}

void a32_emit_exc() {
    // __a32_mulhs(a, b): the high 64 bits of the signed 128-bit product (the arguments at [sp], [sp + 8]; the result r0:r1; r4 .. r9 are kept)
    a32_xfunc("__a32_mulhs");
    a32_w(0xE59D0000);
    a32_w(0xE59D1004);
    a32_w(0xE59D2008);
    a32_w(0xE59D300C);
    a32_w(0xE92D03F0);
    a32_w(0xE0854290);
    a32_w(0xE0876390);
    a32_w(0xE0898291);
    a32_w(0xE0954006);
    a32_w(0xE3A05000);
    a32_w(0xE2A55000);
    a32_w(0xE0944008);
    a32_w(0xE2A55000);
    a32_w(0xE0864391);
    a32_w(0xE0944007);
    a32_w(0xE2A66000);
    a32_w(0xE0944009);
    a32_w(0xE2A66000);
    a32_w(0xE0944005);
    a32_w(0xE2A66000);
    a32_w(0xE3510000);
    a32_w(0xAA000001);
    a32_w(0xE0544002);
    a32_w(0xE0C66003);
    a32_w(0xE3530000);
    a32_w(0xAA000001);
    a32_w(0xE0544000);
    a32_w(0xE0C66001);
    a32_w(0xE1A00004);
    a32_w(0xE1A01006);
    a32_w(0xE8BD03F0);
    a32_w(0xE12FFF1E);
    // j2k_try_enter: returns 0; after a throw the program goes on after the call with r0 = 1
    a32_xfunc("j2k_try_enter");
    a32_mov(11, 10);
    a32_ldr(1, 11, 8);
    a32_dpi(A32_AL, 10, 1, 0, 1, 24);                 // cmp r1, #24
    a32_xbranch(A32_GE, 0);
    a32_dpi(A32_AL, 13, 0, 2, 0, 32);                 // mov r2, #32
    a32_w(0xE0000090 | (2 << 16) | (2 << 8) | 1);     // mul r2, r1, r2
    a32_dp(A32_AL, 4, 0, 3, 11, 2);                   // add r3, r11, r2
    a32_str(13, 3, 16);
    a32_dpi(A32_AL, 13, 0, 4, 0, 0);
    a32_str(4, 3, 20);
    a32_str(14, 3, 32);
    a32_str(4, 3, 36);
    a32_ldr(5, 11, 784);
    a32_str(5, 3, 40);
    a32_ldr(5, 11, 788);
    a32_str(5, 3, 44);
    a32_dpi(A32_AL, 4, 0, 1, 1, 1);                   // add r1, r1, #1
    a32_str(1, 11, 8);
    a32_dpi(A32_AL, 13, 0, 0, 0, 0);
    a32_dpi(A32_AL, 13, 0, 1, 0, 0);
    a32_w(0xE12FFF1E);                                // bx lr
    a32_xplace(0);
    a32_dpi(A32_AL, 13, 0, 0, 0, 2);                  // too many try blocks: exit(2)
    a32_const(7, 248);
    a32_w(0xEF000000);
    a32_xpatch();
    // j2k_try_leave
    a32_xfunc("j2k_try_leave");
    a32_mov(11, 10);
    a32_ldr(1, 11, 8);
    a32_dpi(A32_AL, 2, 0, 1, 1, 1);                   // sub r1, r1, #1
    a32_str(1, 11, 8);
    a32_w(0xE12FFF1E);
    // j2k_throw: the value is the first argument; the owners of the frames that are left are freed, sp and lr are those of the try
    a32_xfunc("j2k_throw");
    a32_mov(11, 10);
    a32_ldr(0, 13, 0);
    a32_str(0, 11, 0);
    a32_ldr(0, 13, 4);
    a32_str(0, 11, 4);
    a32_ldr(1, 11, 8);
    a32_dpi(A32_AL, 10, 1, 0, 1, 0);                  // cmp r1, #0
    a32_xbranch(A32_EQ, 3);                           // uncaught
    a32_dpi(A32_AL, 2, 0, 1, 1, 1);                   // sub r1, r1, #1
    a32_str(1, 11, 8);
    a32_dpi(A32_AL, 13, 0, 2, 0, 32);
    a32_w(0xE0000090 | (2 << 16) | (2 << 8) | 1);     // mul r2, r1, r2
    a32_dp(A32_AL, 4, 0, 3, 11, 2);                   // add r3, r11, r2
    a32_dpi(A32_AL, 2, 0, 13, 13, 32);                // sub sp, sp, #32
    a32_str(3, 11, 776);
    a32_ldr(9, 3, 40);
    a32_str(9, 11, 780);
    a32_xplace(1);                                    // loop
    a32_ldr(5, 11, 784);
    a32_ldr(4, 11, 780);
    a32_dp(A32_AL, 10, 1, 0, 5, 4);                   // cmp r5, r4
    a32_xbranch(A32_EQ, 2);
    a32_dpi(A32_AL, 10, 1, 0, 5, 0);                  // cmp r5, #0
    a32_xbranch(A32_EQ, 2);
    a32_ldr(6, 5, 0);
    a32_str(6, 11, 784);
    a32_ldr(6, 5, 4);
    a32_str(6, 11, 788);
    a32_ldr(7, 5, 8);                                 // the address of the variable
    a32_ldr(8, 5, 16);                                // the function
    a32_ldr(9, 5, 24);                                // the mode: 0 the value of the variable, 1 its address
    a32_mov(0, 7);
    a32_dpi(A32_AL, 10, 1, 0, 9, 0);                  // cmp r9, #0
    a32_w(0x05900000 | (7 << 16) | (0 << 12));        // ldreq r0, [r7]
    a32_str(0, 13, 0);
    a32_dpi(A32_AL, 13, 0, 1, 0, 0);
    a32_str(1, 13, 4);
    a32_w(0xE12FFF30 | 8);                            // blx r8
    a32_xbranch(A32_AL, 1);
    a32_xplace(2);                                    // done
    a32_ldr(3, 11, 776);
    a32_dpi(A32_AL, 4, 0, 13, 13, 32);                // add sp, sp, #32
    a32_ldr(4, 3, 16);
    a32_ldr(14, 3, 32);
    a32_mov(13, 4);
    a32_dpi(A32_AL, 13, 0, 0, 0, 1);                  // mov r0, #1
    a32_dpi(A32_AL, 13, 0, 1, 0, 0);
    a32_w(0xE12FFF1E);
    a32_xplace(3);                                    // uncaught
    a32_ldr(0, 11, 0);
    a32_dpi(A32_AL, 2, 0, 13, 13, 16);
    a32_str(0, 13, 0);
    a32_dpi(A32_AL, 13, 0, 1, 0, 0);
    a32_str(1, 13, 4);
    a32_bl("__a32_uncaught");
    a32_w(0xE1200070);
    a32_xpatch();
    // j2k_thread_start(function, argument, top of the new stack, the id word, the block of the thread): clone; the new thread calls the function
    a32_xfunc("j2k_thread_start");
    a32_ldr(1, 13, 16);                               // the top of the new stack
    a32_dpi(A32_AL, 2, 0, 1, 1, 32);                  // sub r1, r1, #32
    a32_ldr(0, 13, 0);
    a32_str(0, 1, 0);                                 // [stack + 0] = the function
    a32_ldr(0, 13, 8);
    a32_str(0, 1, 8);                                 // [stack + 8] = the argument
    a32_ldr(0, 13, 32);
    a32_str(0, 1, 16);                                // [stack + 16] = the block
    a32_ldr(2, 13, 24);                               // the id word: parent id and child clear id
    a32_mov(4, 2);
    a32_const(0, 3477248);
    a32_const(3, 0);
    a32_const(7, 120);                                // clone
    a32_w(0xEF000000);
    a32_dpi(A32_AL, 10, 1, 0, 0, 0);                  // cmp r0, #0
    a32_xbranch(A32_NE, 0);                           // the parent
    a32_ldr(10, 13, 16);                              // the child: the block of its own
    a32_ldr(9, 13, 0);
    a32_ldr(0, 13, 8);
    a32_dpi(A32_AL, 2, 0, 13, 13, 16);
    a32_str(0, 13, 0);
    a32_dpi(A32_AL, 13, 0, 1, 0, 0);
    a32_str(1, 13, 4);
    a32_w(0xE12FFF30 | 9);                            // blx r9
    a32_dpi(A32_AL, 13, 0, 0, 0, 0);
    a32_dpi(A32_AL, 13, 0, 7, 0, 1);                  // exit (this thread)
    a32_w(0xEF000000);
    a32_xplace(0);
    a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0);    // asr r1, r0, #31
    a32_w(0xE12FFF1E);
    a32_xpatch();
}

// all functions are made: the calls are filled in, the file is written
void a32_finish(char^ path) {
    a32_emit_exc();
    // the functions that main can reach must all be made
    int main_fn = 0 - 1;
    int f = 0;
    while f < a32_nf {
        if str_eq(@a32_fname + f * 64, "main") { main_fn = f; }
        f += 1;
    }
    if main_fn < 0 { die("the ARM32 back end: there is no main"); }
    char reach[2048];
    f = 0;
    while f < a32_nf { reach[f] = 0; f += 1; }
    reach[main_fn] = 1;
    // the entry stub calls these two
    int rf = a32_find("__a32_fixargs");
    if rf >= 0 { reach[rf] = 1; }
    rf = a32_find("__a32_segv");
    if rf >= 0 { reach[rf] = 1; }
    rf = a32_find("j2k_throw");
    if rf >= 0 { reach[rf] = 1; }
    rf = a32_find("j2k_thread_start");
    if rf >= 0 { reach[rf] = 1; }
    bool more = true;
    while more {
        more = false;
        int c = 0;
        while c < a32_nc {
            if a32_cat[c] >= 0 && reach[a32_cfn[c]] == 1 {
                int g = a32_find(@a32_cname + c * 64);
                if g < 0 && str_eq(@a32_cname + c * 64, "j2k_fntab") { g = main_fn; }          // the table of names for the trace: a zero word is made below
                if g < 0 {
                    write_err("jcmp: the ARM32 back end: the function '");
                    write_err(@a32_cname + c * 64);
                    write_err("' is called but not made (the runtime of the ARM32 target is not written yet)\n");
                    syscall(93, 1);
                }
                if reach[g] == 0 {
                    reach[g] = 1;
                    more = true;
                }
            }
            c += 1;
        }
    }
    f = 0;
    while f < a32_nf {
        if reach[f] == 1 && a32_fok[f] == 0 {
            write_err("jcmp: the ARM32 back end cannot make the function '");
            write_err(@a32_fname + f * 64);
            write_err("': ");
            write_err(@a32_fwhy + f * 128);
            write_err("\n");
            if a32_has(@a32_fwhy + f * 128, "not understood") {
                write_err("  help: the function has an instruction that is written for ARM64 (Cpu::inst, Sys:: registers, Cache::clean ...); for -target arm32 use the words of docs/syntax-design.md section 84, or raw<u32>[...] with ARM32 machine words\n");
            }
            syscall(93, 1);
        }
        f += 1;
    }
    // the calls
    int c2 = 0;
    while c2 < a32_nc {
        if reach[a32_cfn[c2]] == 1 {
            int g2 = a32_find(@a32_cname + c2 * 64);
            if g2 < 0 && str_eq(@a32_cname + c2 * 64, "j2k_fntab") {
                // no names for the trace on this target: the table is empty (a word that is 0, the last one of the global area)
                int zaddr = 268435456 + (a32_systab() + 1024 + 4095) / 4096 * 4096 - 8;
                a32_set(a32_cat[c2], 0xE3000000 | (((zaddr & 65535) >> 12) << 16) | (zaddr & 4095));
                a32_set(a32_cat[c2] + 4, 0xE3400000 | ((((zaddr >> 16) & 65535) >> 12) << 16) | ((zaddr >> 16) & 4095));
                c2 += 1;
                continue;
            }
            if a32_ckind[c2] == 0 {
                int rel = (a32_foff[g2] - (a32_cat[c2] + 8)) / 4;
                a32_set(a32_cat[c2], 0xEB000000 | (rel & 16777215));
            } else {
                int addr = 65536 + 116 + a32_foff[g2];
                a32_set(a32_cat[c2], 0xE3000000 | (((addr & 65535) >> 12) << 16) | (0 << 12) | (addr & 4095));
                a32_set(a32_cat[c2] + 4, 0xE3400000 | ((((addr >> 16) & 65535) >> 12) << 16) | (0 << 12) | ((addr >> 16) & 4095));
            }
        }
        c2 += 1;
    }
    // the entry: the stack pointer at the start goes to the first word of the global area (argc / argv), then main
    // the handler of SIGSEGV: the kernel gives (signal, info, context) in r0..r2; our functions take 8-byte words at the bottom of the stack
    int sg = a32_find("__a32_segv");
    int tramp = a32_pos;
    if sg >= 0 && a32_fok[sg] == 1 {
        a32_dpi(A32_AL, 2, 0, 13, 13, 24);              // sub sp, sp, #24
        a32_str(0, 13, 0);
        a32_const(3, 0);
        a32_str(3, 13, 4);
        a32_str(1, 13, 8);
        a32_str(3, 13, 12);
        a32_str(2, 13, 16);
        a32_str(3, 13, 20);
        int relg = (a32_foff[sg] - (a32_pos + 8)) / 4;
        a32_w(0xEB000000 | (relg & 16777215));
        a32_w(0xE1200070);
    }
    int entry = a32_pos;
    // the global area: mmap2(0x10000000, size, RW, PRIVATE | FIXED | ANONYMOUS, -1, 0); it is zero, the start values are copied below
    a32_const(0, 268435456);
    a32_const(1, (a32_systab() + 1024 + 4095) / 4096 * 4096);
    a32_const(2, 3);
    a32_const(3, 50);
    a32_const(4, 4294967295);
    a32_const(5, 0);
    a32_const(7, 192);
    a32_w(0xEF000000);
    if sg >= 0 && a32_fok[sg] == 1 {
        a32_dpi(A32_AL, 2, 0, 13, 13, 32);              // sub sp, sp, #32: struct sigaction {handler, mask, flags, restorer}
        a32_const(0, 65536 + 116 + tramp);
        a32_str(0, 13, 0);
        a32_const(0, 0);
        a32_str(0, 13, 4);
        a32_const(0, 4);                                // SA_SIGINFO
        a32_str(0, 13, 8);
        a32_const(0, 0);
        a32_str(0, 13, 12);
        a32_const(0, 11);                               // SIGSEGV
        a32_mov(1, 13);
        a32_const(2, 0);
        a32_const(7, 67);                               // sigaction
        a32_w(0xEF000000);
        a32_dpi(A32_AL, 4, 0, 13, 13, 32);              // add sp, sp, #32
    }
    a32_const(10, 268435456 + 72);                  // r10: the block of the thread
    // the start values of the global area: records {offset, length, words ...} ending with a length of 0 are copied from the code segment
    int blobat = a32_pos;                           // movw / movt r4 = the address of the records (filled in below)
    a32_w(0xE3004000);
    a32_w(0xE3404000);
    a32_const(7, 268435456);
    int lp0 = a32_pos;
    a32_w(0xE4945004);                              // ldr r5, [r4], #4: the offset
    a32_w(0xE4946004);                              // ldr r6, [r4], #4: the length
    a32_dpi(A32_AL, 10, 1, 0, 6, 0);                // cmp r6, #0
    int lpdone = a32_pos;
    a32_w(0);                                       // beq done
    a32_dp(A32_AL, 4, 0, 5, 5, 7);                  // add r5, r5, r7
    int lp1 = a32_pos;
    a32_w(0xE4940004);                              // ldr r0, [r4], #4
    a32_w(0xE4850004);                              // str r0, [r5], #4
    a32_dpi(A32_AL, 2, 1, 6, 6, 4);                 // subs r6, r6, #4
    a32_w(0x1A000000 | (((lp1 - (a32_pos + 8)) / 4) & 16777215));        // bne copy
    a32_w(0xEA000000 | (((lp0 - (a32_pos + 8)) / 4) & 16777215));        // b loop
    a32_set(lpdone, 0x0A000000 | (((a32_pos - (lpdone + 8)) / 4) & 16777215));
    int fx = a32_find("__a32_fixargs");
    if fx < 0 || a32_fok[fx] == 0 { die("the ARM32 back end: __a32_fixargs (std/rt_a32.j) is not made"); }
    a32_mov(3, 13);                                 // r3 = the stack pointer of the start
    a32_dpi(A32_AL, 2, 0, 13, 13, 16);              // sub sp, sp, #16
    a32_str(3, 13, 0);
    a32_const(2, 0);
    a32_str(2, 13, 4);
    int relf = (a32_foff[fx] - (a32_pos + 8)) / 4;
    a32_w(0xEB000000 | (relf & 16777215));         // bl __a32_fixargs: r0 = the address of the copy of argc / argv / envp
    a32_dpi(A32_AL, 4, 0, 13, 13, 16);              // add sp, sp, #16
    a32_const(1, 268435456);
    a32_str(0, 1, 0);
    a32_str(2, 1, 4);
    int relm = (a32_foff[main_fn] - (a32_pos + 8)) / 4;
    a32_w(0xEB000000 | (relm & 16777215));         // bl main
    a32_w(0xE1200070);                              // bkpt
    // the global area: the texts and the values that the ARM64 target stores at the start are kept as records after the code (copied at the start)
    int dsize = (a32_systab() + 1024 + 4095) / 4096 * 4096;
    if dsize < 4096 { dsize = 4096; }
    int blobpos = a32_pos;
    int rec0 = 0;                                   // the record being made: where its offset is in a32_code, and its length
    int reclen = 0;
    int recoff = 0 - 100;
    int sn = 0;
    // the table of system call numbers
    a32_w(a32_systab());
    a32_w(1024);
    while sn < 512 {
        int sv = a32_sysno(sn);
        a32_w((sv & 65535) | ((a32_sysno(sn + 1) & 65535) << 16));
        sn += 2;
    }
    int gi = 0;
    while gi < ginit_count {
        int off = ginit_off[gi];
        int val = ginit_val[gi];
        if off == recoff + reclen && reclen > 0 {
            reclen += 8;
        } else {
            if reclen > 0 { a32_set(rec0 + 4, reclen); }
            a32_w(off);
            rec0 = a32_pos - 4;
            a32_w(0);
            recoff = off;
            reclen = 8;
        }
        a32_w(val & 4294967295);
        a32_w((val >> 32) & 4294967295);
        gi += 1;
    }
    if reclen > 0 { a32_set(rec0 + 4, reclen); }
    if x_map != null {
        // -xmap FILE: "address name" for every function
        char^ mb = @a32_mapbuf;
        int mp = 0;
        int mf = 0;
        while mf < a32_nf && mp < 400000 {
            int ad = 65536 + 116 + a32_foff[mf];
            int hx = 7;
            while hx >= 0 {
                int dg = (ad >> (4 * hx)) & 15;
                if dg < 10 { mb[mp] = '0' + dg; } else { mb[mp] = 'a' + dg - 10; }
                mp += 1;
                hx -= 1;
            }
            mb[mp] = ' ';
            mp += 1;
            int nk = 0;
            while a32_fname[mf * 64 + nk] != 0 { mb[mp] = a32_fname[mf * 64 + nk]; mp += 1; nk += 1; }
            mb[mp] = 10;
            mp += 1;
            mf += 1;
        }
        write_file(x_map, mb, mp);
    }
    // the global numbers with a decimal initial value (the ARM64 target works them out at the start; here at the build, the same way)
    gi = 0;
    while gi < gfi_count {
        int fbits = float_literal_bits(gfi_mant[gi], gfi_exp[gi]);
        if gfi_neg[gi] == 1 { fbits = fbits xor (1 << 63); }
        if gfi_f32[gi] == 1 {
            double fdd[1];
            int^ fdb = (int^)@fdd[0];
            fdb[0] = fbits;
            float fff[2];
            fff[0] = (float)fdd[0];
            i32^ ffb = (i32^)@fff[0];
            fbits = ffb[0] & 4294967295;
        }
        a32_w(gfi_off[gi]);
        a32_w(8);
        a32_w(fbits & 4294967295);
        a32_w((fbits >> 32) & 4294967295);
        gi += 1;
    }
    a32_w(0);                                       // the end of the records
    a32_w(0);
    int blobaddr = 65536 + 116 + blobpos;
    a32_set(blobat, 0xE3000000 | (((blobaddr & 65535) >> 12) << 16) | (4 << 12) | (blobaddr & 4095));
    a32_set(blobat + 4, 0xE3400000 | ((((blobaddr >> 16) & 65535) >> 12) << 16) | (4 << 12) | ((blobaddr >> 16) & 4095));
    // the header: ELF32, ARM, EABI 5, two segments: code (R + X) and the global area (R + W)
    int i = 0;
    while i < 116 { a32_hdr[i] = 0; i += 1; }
    a32_hdr[0] = 0x7f; a32_hdr[1] = 0x45; a32_hdr[2] = 0x4c; a32_hdr[3] = 0x46;
    a32_hdr[4] = 1; a32_hdr[5] = 1; a32_hdr[6] = 1;
    a32_hput(16, 2, 2);                    // e_type = EXEC
    a32_hput(18, 2, 40);                   // e_machine = ARM
    a32_hput(20, 4, 1);
    a32_hput(24, 4, 0x10000 + 116 + entry);      // e_entry
    a32_hput(28, 4, 52);                   // e_phoff
    a32_hput(36, 4, 0x05000000);           // e_flags: EABI version 5
    a32_hput(40, 2, 52);
    a32_hput(42, 2, 32);
    a32_hput(44, 2, 1);                    // one program header: the code (the global area is mapped by the start code)
    a32_hput(52, 4, 1);                    // segment 1: PT_LOAD, the headers and the code
    a32_hput(56, 4, 0);
    a32_hput(60, 4, 0x10000);
    a32_hput(64, 4, 0x10000);
    a32_hput(68, 4, 116 + a32_pos);
    a32_hput(72, 4, 116 + a32_pos);
    a32_hput(76, 4, 5);
    a32_hput(80, 4, 4096);
    int out = syscall(56, -100, path, 577, 493);
    if out < 0 {
        write_err("jcmp: cannot write the program file\n");
        syscall(93, 1);
    }
    syscall(64, out, @a32_hdr, 116);
    syscall(64, out, @a32_code, a32_pos);
    syscall(57, out);
    syscall(93, 0);
}
