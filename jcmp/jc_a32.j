// jc_a32.j: the ARM32 back end, first step (docs/design/15-arm32.md, docs/design/18-symbolic-ir.md).
// `jcmp -target arm32 x.jk -o x` writes an ELF32 file (EABI 5, ARM mode) from the IR of the functions, with no register allocation:
// every virtual register has an 8 byte cell in the frame (a 64-bit whole number: low word, high word), every instruction loads its
// operands into r0..r3, works, and stores the result. Slow and simple; it is the base that the tests of the language run on first.
// Our own calling rules: every argument takes 8 bytes at [sp + 8 * k] of the caller, the result is in r0 (low) and r1 (high).
// What it cannot do yet stops the build with the name of the function and of the instruction (a function that nobody calls is not looked at).

char a32_code[2097152];
int a32_pos;                      // bytes of code so far
#define A32_MAXF 2048
char a32_fname[131072];           // 64 characters each
int a32_foff[A32_MAXF];           // the offset of the code of the function
int a32_fok[A32_MAXF];            // 1: made, 0: not (a32_fwhy says why)
char a32_fwhy[262144];            // 128 characters each
int a32_nf;
#define A32_MAXC 16384
int a32_cat[A32_MAXC];            // the calls: the place of the `bl`, the function that makes it, the name of what it calls
int a32_cfn[A32_MAXC];
int a32_ckind[A32_MAXC];          // 0 a `bl`, 1 the address of the function (movw + movt)
char a32_cname[1048576];          // 64 characters each
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
void a32_vmem(bool load, bool single, int vd, int off) {
    int base = 0xED000B00;
    if single { base = 0xED000A00; }
    if load { base = base | 0x00100000; }
    if off >= 0 && off <= 1020 && off % 4 == 0 {
        a32_w(base | 0x00800000 | (13 << 16) | (vd << 12) | (off / 4));
    } else {
        a32_addr(13, off);
        a32_w(base | 0x00800000 | (12 << 16) | (vd << 12));
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

// (rlo, rhi) shifted by the count in rc (0 .. 63); r3 and r4 are used; kind 0 left, 1 logical right, 2 arithmetic right
void a32_shreg(int kind, int rlo, int rhi, int rc) {
    a32_dpi(A32_AL, 3, 0, 3, rc, 32);                                          // rsb r3, rc, #32
    if kind == 0 {
        a32_w(0xE1A00010 | (rhi << 12) | (rc << 8) | rhi);                      // lsl rhi, rhi, rc
        a32_w(0xE1800010 | (rhi << 16) | (rhi << 12) | (3 << 8) | 0x20 | rlo);  // orr rhi, rhi, rlo, lsr r3
        a32_dpi(A32_AL, 2, 1, 4, rc, 32);                                      // subs r4, rc, #32
        a32_w(0x51800010 | (rhi << 16) | (rhi << 12) | (4 << 8) | rlo);         // orrpl rhi, rhi, rlo, lsl r4
        a32_w(0xE1A00010 | (rlo << 12) | (rc << 8) | rlo);                      // lsl rlo, rlo, rc
    } else {
        a32_w(0xE1A00010 | (rlo << 12) | (rc << 8) | 0x20 | rlo);               // lsr rlo, rlo, rc
        a32_w(0xE1800010 | (rlo << 16) | (rlo << 12) | (3 << 8) | rhi);         // orr rlo, rlo, rhi, lsl r3
        a32_dpi(A32_AL, 2, 1, 4, rc, 32);                                      // subs r4, rc, #32
        if kind == 1 {
            a32_w(0x51800010 | (rlo << 16) | (rlo << 12) | (4 << 8) | 0x20 | rhi);    // orrpl rlo, rlo, rhi, lsr r4
            a32_w(0xE1A00010 | (rhi << 12) | (rc << 8) | 0x20 | rhi);                 // lsr rhi, rhi, rc
        } else {
            a32_w(0x51800010 | (rlo << 16) | (rlo << 12) | (4 << 8) | 0x40 | rhi);    // orrpl rlo, rlo, rhi, asr r4
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
    }
    return a32_vbase + a32_vmap[v] * 8;
}

// (rlo, rhi) = the virtual register v
void a32_load(int rlo, int rhi, int v) {
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
    int c = a32_cell(v);
    a32_ldr(rlo, 13, c);
    a32_ldr(rhi, 13, c + 4);
}

void a32_store(int rlo, int rhi, int v) {
    int c = a32_cell(v);
    a32_str(rlo, 13, c);
    a32_str(rhi, 13, c + 4);
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
    a32_load(0, 1, a);
    if bi == 1 {
        a32_const64(2, 3, bnum);
    } else {
        a32_load(2, 3, b);
    }
    if cc == IR_EQ || cc == IR_NE {
        a32_dp(A32_AL, 1, 0, 4, 0, 2);          // eor r4, r0, r2
        a32_dp(A32_AL, 1, 0, 5, 1, 3);          // eor r5, r1, r3
        a32_dp(A32_AL, 12, 1, 4, 4, 5);         // orrs r4, r4, r5
        if cc == IR_EQ { return A32_EQ; }
        return A32_NE;
    }
    bool swap = cc == IR_GT || cc == IR_LE || cc == IR_UGT || cc == IR_ULE;
    if swap {
        a32_dp(A32_AL, 10, 1, 0, 2, 0);         // cmp r2, r0
        a32_dp(A32_AL, 6, 1, 4, 3, 1);          // sbcs r4, r3, r1
    } else {
        a32_dp(A32_AL, 10, 1, 0, 0, 2);         // cmp r0, r2
        a32_dp(A32_AL, 6, 1, 4, 1, 3);          // sbcs r4, r1, r3
    }
    if cc == IR_LT || cc == IR_GT { return A32_LT; }
    if cc == IR_GE || cc == IR_LE { return A32_GE; }
    if cc == IR_ULT || cc == IR_UGT { return A32_CC; }
    return A32_CS;
}

void a32_epilogue() {
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
    if op == IR_CONST {
        a32_const64(0, 1, ir_k[i]);
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_COPY {
        a32_load(0, 1, ir_a[i]);
        a32_store(0, 1, d);
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
        a32_load(0, 1, ir_a[i]);
        a32_load_b(i);
        if op == IR_ADD { a32_dp(A32_AL, 4, 1, 0, 0, 2); a32_dp(A32_AL, 5, 0, 1, 1, 3); }
        else if op == IR_SUB { a32_dp(A32_AL, 2, 1, 0, 0, 2); a32_dp(A32_AL, 6, 0, 1, 1, 3); }
        else if op == IR_AND { a32_dp(A32_AL, 0, 0, 0, 0, 2); a32_dp(A32_AL, 0, 0, 1, 1, 3); }
        else if op == IR_OR { a32_dp(A32_AL, 12, 0, 0, 0, 2); a32_dp(A32_AL, 12, 0, 1, 1, 3); }
        else { a32_dp(A32_AL, 1, 0, 0, 0, 2); a32_dp(A32_AL, 1, 0, 1, 1, 3); }
        a32_store(0, 1, d);
        return true;
    }
    if op == IR_MUL {
        a32_load(0, 1, ir_a[i]);
        a32_load_b(i);
        a32_w(0xE0800090 | (5 << 16) | (4 << 12) | (2 << 8) | 0);          // umull r4, r5, r0, r2
        a32_w(0xE0200090 | (5 << 16) | (5 << 12) | (3 << 8) | 0);          // mla r5, r0, r3, r5
        a32_w(0xE0200090 | (5 << 16) | (5 << 12) | (2 << 8) | 1);          // mla r5, r1, r2, r5
        a32_store(4, 5, d);
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
            a32_load(6, 7, ir_a[i]);
            base = 6;
        }
        if op == IR_LOAD {
            if aw == 8 {
                a32_ldr(0, base, off);
                a32_ldr(1, base, off + 4);
            } else if aw == 4 {
                a32_ldr(0, base, off);
                if w < 0 { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); } else { a32_const(1, 0); }
            } else {
                a32_addr(base, off);
                if aw == 1 {
                    if w < 0 { a32_w(0xE1D000D0 | (12 << 16) | (0 << 12)); } else { a32_w(0xE5D00000 | (12 << 16) | (0 << 12)); }     // ldrsb / ldrb r0, [r12]
                } else {
                    if w < 0 { a32_w(0xE1D000F0 | (12 << 16) | (0 << 12)); } else { a32_w(0xE1D000B0 | (12 << 16) | (0 << 12)); }     // ldrsh / ldrh r0, [r12]
                }
                if w < 0 { a32_w(0xE1A00040 | (1 << 12) | (31 << 7) | 0); } else { a32_const(1, 0); }
            }
            a32_store(0, 1, d);
        } else {
            a32_load(0, 1, ir_b[i]);
            if aw == 8 {
                a32_str(0, base, off);
                a32_str(1, base, off + 4);
            } else if aw == 4 {
                a32_str(0, base, off);
            } else {
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
        a32_load(12, 8, ir_a[i]);
        a32_w(0xE12FFF3C);                          // blx r12
        if d != 0 { a32_store(0, 1, d); }
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
            a32_w(0x1A000000 | 3);                      // bne +3 words: to the clrex below (skips the 2 moves, strexd and the compare)
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
        a32_mov(6, 0);
        a32_mov(7, 1);
        a32_shreg(1, 0, 1, 2);                               // r0:r1 = x >> n
        a32_dpi(A32_AL, 3, 0, 2, 2, 0);                      // rsb r2, r2, #0
        a32_dpi(A32_AL, 0, 0, 2, 2, 63);                     // and r2, r2, #63: (64 - n) mod 64
        a32_shreg(0, 6, 7, 2);                               // r6:r7 = x << (64 - n)
        a32_dp(A32_AL, 12, 0, 0, 0, 6);
        a32_dp(A32_AL, 12, 0, 1, 1, 7);
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
        a32_vmem(true, false, 0, a32_cell(ir_a[i]));
        a32_vmem(true, false, 1, a32_cell(ir_b[i]));
        if op == IR_FADD { a32_vfp(0xEE300B00, 0, 0, 1); }
        else if op == IR_FSUB { a32_vfp(0xEE300B40, 0, 0, 1); }
        else if op == IR_FMUL { a32_vfp(0xEE200B00, 0, 0, 1); }
        else { a32_vfp(0xEE800B00, 0, 0, 1); }
        a32_vmem(false, false, 0, a32_cell(d));
        return true;
    }
    if op == IR_FNEG || op == IR_FABS || op == IR_FSQRT {
        a32_vmem(true, false, 0, a32_cell(ir_a[i]));
        if op == IR_FNEG { a32_vfp(0xEEB10B40, 0, 0, 0); }
        else if op == IR_FABS { a32_vfp(0xEEB00BC0, 0, 0, 0); }
        else { a32_vfp(0xEEB10BC0, 0, 0, 0); }
        a32_vmem(false, false, 0, a32_cell(d));
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
            a32_vmem(false, false, 0, a32_cell(d));
        } else {
            a32_vfp(0xEEB70BC0, 0, 0, 0);                    // vcvt.f32.f64 s0, d0
            a32_vmem(false, true, 0, a32_cell(d));
        }
        return true;
    }
    if op == IR_FSETCC || op == IR_FBR {
        a32_vmem(true, false, 0, a32_cell(ir_a[i]));
        a32_vmem(true, false, 1, a32_cell(ir_b[i]));
        a32_w(0xEEB40B40 | (0 << 12) | 1);                  // vcmp.f64 d0, d1
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
        a32_vmem(true, false, 0, a32_cell(ir_a[i]));
        a32_vfp(0xEEB70BC0, 0, 0, 0);                        // vcvt.f32.f64 s0, d0
        a32_vmem(false, true, 0, a32_cell(d));
        return true;
    }
    if op == IR_FCVT_SD || op == IR_F32TOI {
        a32_vmem(true, true, 0, a32_cell(ir_a[i]));
        a32_vfp(0xEEB70AC0, 0, 0, 0);                        // vcvt.f64.f32 d0, s0
        if op == IR_FCVT_SD {
            a32_vmem(false, false, 0, a32_cell(d));
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
        a32_str(0, 13, 0);
        a32_str(1, 13, 4);
        a32_str(2, 13, 8);
        a32_str(3, 13, 12);
        if op == IR_SDIV { a32_bl("__a32_sdiv"); }
        else if op == IR_UDIV { a32_bl("__a32_udiv"); }
        else { a32_bl("__a32_mulhs"); }
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
            a32_load(k, 8, ir_args[ir_as[i] + k]);
            k += 1;
        }
        a32_load(7, 8, ir_a[i]);
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
        if (ir_op[i] == IR_FFLOOR || ir_op[i] == IR_FCEIL || ir_op[i] == IR_FTRUNC || ir_op[i] == IR_F2I || ir_op[i] == IR_F32TOI) && maxargs < 1 { maxargs = 1; }
        i += 1;
    }
    a32_outb = maxargs * 8;
    a32_cellbase = a32_outb + lf_frame + maxq;
    a32_vbase = a32_cellbase;
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
    b = 0;
    while b < ir_nb && a32_bad == 0 {
        a32_boff[b] = a32_pos;
        int k2 = ir_bs[b];
        while k2 < ir_be[b] && a32_bad == 0 {
            if !a32_instr(k2, b) { a32_fail("an instruction"); }
            k2 += 1;
        }
        b += 1;
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

// the 32 bit ELF file
char a32_hdr[116];
char a32_data[1048576];
char a32_mapbuf[524288];

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
    // the global area: the texts and the values that the ARM64 target stores at the start are in the file
    int dsize = (a32_systab() + 1024 + 4095) / 4096 * 4096;
    if dsize < 4096 { dsize = 4096; }
    int dused = 0;
    // the table of system call numbers
    int sn = 0;
    while sn < 512 {
        int sv = a32_sysno(sn);
        a32_data[a32_systab() + sn * 2] = sv & 255;
        a32_data[a32_systab() + sn * 2 + 1] = (sv >> 8) & 255;
        sn += 1;
    }
    dused = a32_systab() + 1024;
    int gi = 0;
    while gi < ginit_count {
        int off = ginit_off[gi];
        int val = ginit_val[gi];
        if off + 8 > 1048576 { die("the ARM32 back end: the global area is too big"); }
        int bi = 0;
        while bi < 8 {
            a32_data[off + bi] = (val >> (8 * bi)) & 255;
            bi += 1;
        }
        if off + 8 > dused { dused = off + 8; }
        gi += 1;
    }
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
        int foff = gfi_off[gi];
        int fbi = 0;
        while fbi < 8 {
            a32_data[foff + fbi] = (fbits >> (8 * fbi)) & 255;
            fbi += 1;
        }
        if foff + 8 > dused { dused = foff + 8; }
        gi += 1;
    }
    // the header: ELF32, ARM, EABI 5, two segments: code (R + X) and the global area (R + W)
    int dataoff = (116 + a32_pos + 4095) / 4096 * 4096;
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
    a32_hput(44, 2, 2);                    // two program headers
    a32_hput(52, 4, 1);                    // segment 1: PT_LOAD, the headers and the code
    a32_hput(56, 4, 0);
    a32_hput(60, 4, 0x10000);
    a32_hput(64, 4, 0x10000);
    a32_hput(68, 4, 116 + a32_pos);
    a32_hput(72, 4, 116 + a32_pos);
    a32_hput(76, 4, 5);
    a32_hput(80, 4, 4096);
    a32_hput(84, 4, 1);                    // segment 2: PT_LOAD, the global area at 0x10000000
    a32_hput(88, 4, dataoff);
    a32_hput(92, 4, 268435456);
    a32_hput(96, 4, 268435456);
    a32_hput(100, 4, dused);
    a32_hput(104, 4, dsize);
    a32_hput(108, 4, 6);
    a32_hput(112, 4, 4096);
    int out = syscall(56, -100, path, 577, 493);
    if out < 0 {
        write_err("jcmp: cannot write the program file\n");
        syscall(93, 1);
    }
    syscall(64, out, @a32_hdr, 116);
    syscall(64, out, @a32_code, a32_pos);
    char zeros[4096];
    int zi = 0;
    while zi < 4096 { zeros[zi] = 0; zi += 1; }
    int pad = dataoff - (116 + a32_pos);
    while pad > 0 {
        int chunk = pad;
        if chunk > 4096 { chunk = 4096; }
        syscall(64, out, @zeros, chunk);
        pad -= chunk;
    }
    if dused > 0 { syscall(64, out, @a32_data, dused); }
    syscall(57, out);
    syscall(93, 0);
}
