// jc_asm.jk -- the J2K assembler as a library (every top-level name starts with as_).
// Used by j2k_asm.jk (the stand-alone tool) and by jcmp (one command: .jk -> ELF).
// Same job and the same output as j2k_asm_v1.s (ARM64 assembly): reads a
// .jasm text file, writes an ELF64 executable.   usage: j2k_asm in.jasm out
//
// Compile it with the assembly compiler:  Jcmp j2k_asm.jk j2k_asm.jasm
// then assemble it with j2k_asm_v1 and compare its output to j2k_asm_v1's.

char as_src[16777216];          // the .jasm text
int as_src_len;
int as_ci;                      // cursor: index into src

char as_code[8388608];          // machine code, 4 bytes per instruction
int as_pos;                     // bytes of code emitted so far (also the address)
int as_pass;                    // 1: collect labels, 2: encode

char as_lnames[2097152];        // label table: 32768 names x 64 bytes
int as_laddr[32768];
int as_label_count;
char as_nbuf[64];               // the label name just read (zero padded)

int as_bss_size;
int as_last_is_sp;              // parse_reg_or_sp: was it "sp"?
char as_hdr[176];               // the ELF header

// ---------------------------------------------------------------- errors

void as_fail() {
    // "j2k_asm: error at line L, column C: parse or I/O error"
    int line = 1;
    int col = 1;
    int i = 0;
    while i < as_ci && i < as_src_len {
        if as_src[i] == 10 {
            line += 1;
            col = 1;
        } else {
            col += 1;
        }
        i += 1;
    }
    char msg[48] = "j2k_asm: error at line ";
    syscall(64, 2, @msg, 23);
    as_print_dec(line);
    char m2[16] = ", column ";
    syscall(64, 2, @m2, 9);
    as_print_dec(col);
    char m3[32] = ": parse or I/O error\n";
    syscall(64, 2, @m3, 22);
    syscall(93, 1);
}

void as_print_dec(int v) {
    char digits[24];
    int n = 0;
    if v == 0 {
        digits[0] = '0';
        n = 1;
    }
    while v > 0 {
        digits[n] = '0' + v % 10;
        v = v / 10;
        n += 1;
    }
    char one[2];
    while n > 0 {
        n -= 1;
        one[0] = digits[n];
        syscall(64, 2, @one, 1);
    }
}

// ----------------------------------------------------------- tiny scanners

int as_cur() {
    if as_ci < as_src_len { return as_src[as_ci]; }
    return 0;
}

int as_peek(int off) {
    if as_ci + off < as_src_len { return as_src[as_ci + off]; }
    return 0;
}

void as_skip_spaces() {
    while as_ci < as_src_len && (as_src[as_ci] == 32 || as_src[as_ci] == 9) {
        as_ci += 1;
    }
}

bool as_is_digit(int c) {
    return c >= '0' && c <= '9';
}

bool as_is_letter(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

bool as_is_name_char(int c) {
    return as_is_letter(c) || as_is_digit(c) || c == '_';
}

int as_parse_number() {
    if as_cur() == '#' { as_ci += 1; }
    int v = 0;
    int digits = 0;
    if as_cur() == '0' && (as_peek(1) == 'x' || as_peek(1) == 'X') {
        // hexadecimal:  0x7FF0_0000
        as_ci += 2;
        while as_ci < as_src_len {
            int c = as_src[as_ci];
            int d = 0 - 1;
            if c >= '0' && c <= '9' { d = c - '0'; }
            else if c >= 'a' && c <= 'f' { d = c - 'a' + 10; }
            else if c >= 'A' && c <= 'F' { d = c - 'A' + 10; }
            else if c == '_' { as_ci += 1; continue; }
            if d < 0 { break; }
            v = v * 16 + d;
            digits += 1;
            as_ci += 1;
        }
        if digits == 0 { as_fail(); }
        return v;
    }
    if as_cur() == '0' && (as_peek(1) == 'b' || as_peek(1) == 'B') && (as_peek(2) == '0' || as_peek(2) == '1') {
        as_ci += 2;
        while as_ci < as_src_len && (as_src[as_ci] == '0' || as_src[as_ci] == '1' || as_src[as_ci] == '_') {
            if as_src[as_ci] != '_' { v = v * 2 + (as_src[as_ci] - '0'); }
            as_ci += 1;
        }
        return v;
    }
    while as_ci < as_src_len && as_is_digit(as_src[as_ci]) {
        v = v * 10 + (as_src[as_ci] - '0');
        digits += 1;
        as_ci += 1;
    }
    if digits == 0 { as_fail(); }
    return v;
}

int as_parse_signed() {
    if as_cur() == '#' { as_ci += 1; }
    if as_cur() == '-' {
        as_ci += 1;
        return 0 - as_parse_number();
    }
    return as_parse_number();
}

int as_parse_reg() {
    if as_cur() == 'l' && as_peek(1) == 'r' { as_ci += 2; return 30; }
    if as_cur() != 'x' { as_fail(); }
    if as_peek(1) == 'z' && as_peek(2) == 'r' {
        as_ci += 3;
        return 31;
    }
    as_ci += 1;
    int r = as_parse_number();
    if r > 30 { as_fail(); }
    return r;
}

// "xN" or "sp" (-> 31, last_is_sp = 1). "sp" must be followed by a delimiter.
int as_parse_reg_or_sp() {
    as_last_is_sp = 0;
    if as_cur() == 's' && as_peek(1) == 'p' {
        int d = as_peek(2);
        if d == 32 || d == ',' || d == ']' || d == 9 || d == 10 {
            as_ci += 2;
            as_last_is_sp = 1;
            return 31;
        }
    }
    return as_parse_reg();
}

// ----------------------------------------------------- floating-point registers
int as_fp_kind;                 // after parse_freg: 1 = dN (double), 0 = sN (single)

bool as_at_freg() {
    int c = as_cur();
    if c != 'd' && c != 's' { return false; }
    return as_is_digit(as_peek(1));
}

int as_parse_freg() {
    if as_cur() == 'd' {
        as_fp_kind = 1;
    } else if as_cur() == 's' {
        as_fp_kind = 0;
    } else {
        as_fail();
    }
    as_ci += 1;
    return as_parse_number();
}

// wN (only used by fmov sN, wN / fmov wN, sN)
int as_parse_wreg() {
    if as_cur() != 'w' { as_fail(); }
    as_ci += 1;
    return as_parse_number();
}

void as_expect_comma() {
    as_skip_spaces();
    if as_cur() != ',' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
}

// -------------------------------------------------------------- emitting

void as_put32(int w) {
    if as_pos >= 8388608 { as_fail(); }
    if as_pass == 2 {
        as_code[as_pos] = w & 255;
        as_code[as_pos + 1] = (w >> 8) & 255;
        as_code[as_pos + 2] = (w >> 16) & 255;
        as_code[as_pos + 3] = (w >> 24) & 255;
    }
    as_pos += 4;
}

// any 64-bit value: one MOVN for small negatives, else MOVZ + a MOVK per
// non-zero 16-bit chunk above bit 15
void as_emit_mov_imm(int rd, int v) {
    int nv = ~v;
    if nv >= 0 && nv <= 65535 {
        as_put32(0x92800000 | (nv << 5) | rd);
        return;
    }
    as_put32(0xD2800000 | ((v & 65535) << 5) | rd);
    int hw = 1;
    while hw < 4 {
        int chunk = (v >> (16 * hw)) & 65535;
        if chunk != 0 {
            as_put32(0xF2800000 | (chunk << 5) | (hw << 21) | rd);
        }
        hw += 1;
    }
}

// add/sub/cmp with an immediate: opi = immediate form (high 16 bits),
// opo = the opposite form (used for negative values), opr = register form
void as_addsub_imm(int value, int rd, int rn, int opi, int opo, int opr) {
    int orig = value;
    if value < 0 {
        value = 0 - value;
        opi = opo;
    }
    if value <= 4095 {
        as_put32((opi << 16) | (value << 10) | (rn << 5) | rd);
        return;
    }
    as_emit_mov_imm(17, orig);
    as_put32((opr << 16) | (17 << 16) | 0x00206000 | (rn << 5) | rd);
}

// ---------------------------------------------------------------- labels

void as_read_label_name() {
    int n = 0;
    while n < 64 { as_nbuf[n] = 0; n += 1; }
    n = 0;
    while as_ci < as_src_len && as_is_name_char(as_src[as_ci]) {
        if n >= 63 { as_fail(); }                 // names are at most 63 characters (a longer one used to be cut short silently)
        as_nbuf[n] = as_src[as_ci];
        n += 1;
        as_ci += 1;
    }
}

bool as_name_matches(int slot) {
    int i = 0;
    while i < 64 {
        if as_lnames[slot * 64 + i] != as_nbuf[i] { return false; }
        if as_nbuf[i] == 0 { return true; }
        i += 1;
    }
    return true;
}

void as_add_label() {
    if as_label_count >= 32768 { as_fail(); }
    int i = 0;
    while i < 64 {
        as_lnames[as_label_count * 64 + i] = as_nbuf[i];
        i += 1;
    }
    as_laddr[as_label_count] = as_pos;
    as_label_count += 1;
}

int as_find_label() {
    int i = 0;
    while i < as_label_count {
        if as_name_matches(i) { return as_laddr[i]; }
        i += 1;
    }
    as_fail();
    return 0;
}

// is there "name:" at the cursor?
bool as_peek_is_label() {
    int i = as_ci;
    if i >= as_src_len { return false; }
    if !as_is_letter(as_src[i]) && as_src[i] != '_' { return false; }
    while i < as_src_len && as_is_name_char(as_src[i]) { i += 1; }
    return i < as_src_len && as_src[i] == ':';
}

// --------------------------------------------------------------- handlers

void as_h_mov() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    if as_cur() == 'x' || (as_cur() == 'l' && as_peek(1) == 'r') {
        int rm = as_parse_reg();
        as_put32(0xAA000000 | (rm << 16) | (31 << 5) | rd);
    } else {
        as_emit_mov_imm(rd, as_parse_signed());
    }
}

// add (isadd = true) or sub
void as_h_addsub(bool isadd) {
    as_skip_spaces();
    int rd = as_parse_reg_or_sp();
    int sp_d = as_last_is_sp;
    as_expect_comma();
    int rn = as_parse_reg_or_sp();
    int sp_n = as_last_is_sp;
    as_expect_comma();
    if as_cur() == 'x' {
        if sp_d != 0 || sp_n != 0 { as_fail(); }
        int rm = as_parse_reg();
        int base = 0xCB000000;
        if isadd { base = 0x8B000000; }
        as_put32(base | (rm << 16) | (rn << 5) | rd);
        return;
    }
    if as_cur() == '#' { as_ci += 1; }
    int v = as_parse_signed();
    if isadd {
        as_addsub_imm(v, rd, rn, 0x9100, 0xD100, 0x8B00);
    } else {
        as_addsub_imm(v, rd, rn, 0xD100, 0x9100, 0xCB00);
    }
}

void as_h_cmp() {
    as_skip_spaces();
    int rn = as_parse_reg();
    as_expect_comma();
    if as_cur() == 'x' {
        int rm = as_parse_reg();
        as_put32(0xEB000000 | (rm << 16) | (rn << 5) | 31);
    } else {
        as_addsub_imm(as_parse_signed(), 31, rn, 0xF100, 0xB100, 0xEB00);
    }
}

// three-register forms: mul, udiv, sdiv, and, orr, eor, lsl, lsr, asr
// lsl / lsr / asr: with three registers, or with a number: lsl x0, x1, #3
void as_h_shift(int regbase, int kind) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    if as_cur() == '#' {
        as_ci += 1;
        int imm = as_parse_number();
        if imm < 0 || imm > 63 { as_fail(); }
        if kind == 0 {
            as_put32(0xD3400000 | (((64 - imm) & 63) << 16) | ((63 - imm) << 10) | (rn << 5) | rd);
        } else if kind == 1 {
            as_put32(0xD340FC00 | (imm << 16) | (rn << 5) | rd);
        } else if kind == 3 {
            as_put32(0x93C00000 | (rn << 16) | (imm << 10) | (rn << 5) | rd);          // ror xd, xn, #imm  =  extr xd, xn, xn, #imm
        } else {
            as_put32(0x9340FC00 | (imm << 16) | (rn << 5) | rd);
        }
        return;
    }
    int rm = as_parse_reg();
    as_put32(regbase | (rm << 16) | (rn << 5) | rd);
}

// msub / madd: four registers: xd = xa - xn * xm  (msub), xd = xa + xn * xm (madd)
// popcnt xd, xn : the number of bits that are 1 in xn (four instructions with the vector register v27: fmov, cnt, addv, fmov)
void as_h_popcnt() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_put32(0x9E670000 | (rn << 5) | 27);                 // fmov d27, xn
    as_put32(0x0E205800 | (27 << 5) | 27);                 // cnt v27.8b, v27.8b
    as_put32(0x0E31B800 | (27 << 5) | 27);                 // addv b27, v27.8b
    as_put32(0x9E660000 | (27 << 5) | rd);                 // fmov xd, d27
}

// neg xd, xm : xd = 0 - xm   (sub xd, xzr, xm)
void as_h_neg() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_put32(0xCB0003E0 | (rm << 16) | rd);
}

void as_h_rrrr(int base) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_expect_comma();
    int ra = as_parse_reg();
    as_put32(base | (rm << 16) | (ra << 10) | (rn << 5) | rd);
}

void as_h_rrr(int base) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_put32(base | (rm << 16) | (rn << 5) | rd);
}

// stp xA, xB, [sp, #-N]!   (the prologue: N is a multiple of 8, at most 512)   and   ldp xA, xB, [sp], #N   (the epilogue: at most 504)
void as_h_pair(bool store) {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    int rt2 = as_parse_reg();
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    int rn = as_parse_reg_or_sp();
    as_skip_spaces();
    int imm = 0;
    if store {
        if as_cur() != ',' { as_fail(); }
        as_ci += 1;
        as_skip_spaces();
        if as_cur() != '#' { as_fail(); }
        as_ci += 1;
        if as_cur() != '-' { as_fail(); }
        as_ci += 1;
        imm = 0 - as_parse_number();
        as_skip_spaces();
        if as_cur() != ']' { as_fail(); }
        as_ci += 1;
        if as_cur() != '!' { as_fail(); }
        as_ci += 1;
        if imm < 0 - 512 || (imm & 7) != 0 { as_fail(); }
        as_put32(0xA9800000 | (((imm >> 3) & 127) << 15) | (rt2 << 10) | (rn << 5) | rt);
    } else {
        if as_cur() != ']' { as_fail(); }
        as_ci += 1;
        as_expect_comma();
        if as_cur() != '#' { as_fail(); }
        as_ci += 1;
        imm = as_parse_number();
        if imm > 504 || (imm & 7) != 0 { as_fail(); }
        as_put32(0xA8C00000 | (((imm >> 3) & 127) << 15) | (rt2 << 10) | (rn << 5) | rt);
    }
}

// ldr/str family: op = the instruction's high 16 bits, shift = log2(size)
void as_h_mem(int op, int shift) {
    as_skip_spaces();
    int rt = 0;
    if as_cur() == 'd' && as_is_digit(as_peek(1)) {
        // ldr dN, [..] / str dN, [..]  (a double)
        rt = as_parse_freg();
        if op == 0xF940 { op = 0xFD40; }
        else if op == 0xF900 { op = 0xFD00; }
        else { as_fail(); }
    } else {
        rt = as_parse_reg();
    }
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    int rn = as_parse_reg_or_sp();
    as_skip_spaces();
    int imm = 0;
    if as_cur() == ']' {
        as_ci += 1;
    } else {
        if as_cur() != ',' { as_fail(); }
        as_ci += 1;
        as_skip_spaces();
        if as_cur() != '#' { as_fail(); }
        as_ci += 1;
        imm = as_parse_number();
        as_skip_spaces();
        if as_cur() != ']' { as_fail(); }
        as_ci += 1;
        if (imm & ((1 << shift) - 1)) != 0 { as_fail(); }
    }
    int imm12 = imm >> shift;
    if imm12 > 4095 {
        as_emit_mov_imm(17, imm);
        as_put32(0x8B206000 | (17 << 16) | (rn << 5) | 17);
        rn = 17;
        imm12 = 0;
    }
    as_put32((op << 16) | (imm12 << 10) | (rn << 5) | rt);
}

// sxtb / sxtw / uxtb: base = 0x9340 or 0xD340, imms = 0x1C00 or 0x7C00
void as_h_sxt(int base, int imms) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_put32((base << 16) | imms | (rn << 5) | rd);
}

int as_parse_cond() {
    int a = as_cur();
    int b = as_peek(1);
    as_ci += 2;
    if a == 'e' && b == 'q' { return 0; }
    if a == 'n' && b == 'e' { return 1; }
    if a == 'l' && b == 't' { return 11; }
    if a == 'l' && b == 'e' { return 13; }
    if a == 'l' && b == 's' { return 9; }
    if a == 'g' && b == 't' { return 12; }
    if a == 'g' && b == 'e' { return 10; }
    if a == 'h' && b == 's' { return 2; }
    if a == 'l' && b == 'o' { return 3; }
    if a == 'm' && b == 'i' { return 4; }
    if a == 'p' && b == 'l' { return 5; }
    if a == 'h' && b == 'i' { return 8; }
    as_fail();
    return 0;
}

// b, bl, b.cond: the cursor is just after the 'b'
void as_h_branch() {
    int is_bl = 0;
    int cond = 14;                       // 14 = unconditional
    if as_cur() == 'l' {
        as_ci += 1;
        is_bl = 1;
    } else if as_cur() == '.' {
        as_ci += 1;
        cond = as_parse_cond();
    }
    as_skip_spaces();
    as_read_label_name();
    if as_pass == 1 {
        as_put32(0);
        return;
    }
    int delta = (as_find_label() - as_pos) >> 2;
    if is_bl == 1 {
        as_put32(0x94000000 | (delta & 0x3FFFFFF));
    } else if cond == 14 {
        as_put32(0x14000000 | (delta & 0x3FFFFFF));
    } else {
        as_put32(0x54000000 | ((delta & 0x7FFFF) << 5) | cond);
    }
}

// fadd fsub fmul fdiv: dREG, dREG, dREG (or the s forms)
void as_h_fp3(int dbase, int sbase) {
    as_skip_spaces();
    int rd = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rn = as_parse_freg();
    if as_fp_kind != kind { as_fail(); }
    as_expect_comma();
    int rm = as_parse_freg();
    if as_fp_kind != kind { as_fail(); }
    int base = sbase;
    if kind == 1 { base = dbase; }
    as_put32(base | (rm << 16) | (rn << 5) | rd);
}

// fneg fabs fsqrt frintm frintp frintz: two registers of the same kind
void as_h_fp2(int dbase, int sbase) {
    as_skip_spaces();
    int rd = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rn = as_parse_freg();
    if as_fp_kind != kind { as_fail(); }
    int base = sbase;
    if kind == 1 { base = dbase; }
    as_put32(base | (rn << 5) | rd);
}

void as_h_fcmp() {
    as_skip_spaces();
    int rn = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rm = as_parse_freg();
    if as_fp_kind != kind { as_fail(); }
    int base = 0x1E202000;
    if kind == 1 { base = 0x1E602000; }
    as_put32(base | (rm << 16) | (rn << 5));
}

// fmov dN, xN | fmov xN, dN | fmov sN, wN | fmov wN, sN
// a decimal number with a fraction that "fmov dN, #x" can make: the 8 bits (sign, 3 bits of exponent, 4 of fraction)
int as_fpimm8() {
    if as_cur() == '#' { as_ci += 1; }
    int neg = 0;
    if as_cur() == '-' {
        neg = 1;
        as_ci += 1;
    }
    int ip = 0;
    while as_is_digit(as_cur()) {
        ip = ip * 10 + (as_cur() - '0');
        as_ci += 1;
    }
    int fp = 0;
    int scale = 1;
    if as_cur() == '.' {
        as_ci += 1;
        while as_is_digit(as_cur()) {
            if scale < 100000000 {
                fp = fp * 10 + (as_cur() - '0');
                scale = scale * 10;
            }
            as_ci += 1;
        }
    }
    // value * 128 must be a whole number m = (16 + f) * 2^e with f in 0..15 and e in 0..7
    int num = (ip * scale + fp) * 128;
    if num % scale != 0 { as_fail(); }
    int m = num / scale;
    int e = 0;
    while e < 8 {
        int top = m >> e;
        if top >= 16 && top <= 31 && (m & ((1 << e) - 1)) == 0 {
            int exp = e - 3;                               // -3 .. 4
            int bb = 0;
            int cd = 0;
            if exp >= 1 { bb = 0; cd = exp - 1; } else { bb = 1; cd = exp + 3; }
            return (neg << 7) | (bb << 6) | (cd << 4) | (top - 16);
        }
        e += 1;
    }
    as_fail();
    return 0;
}

void as_h_fmov() {
    as_skip_spaces();
    if as_at_freg() {
        int rd = as_parse_freg();
        int kind = as_fp_kind;
        as_expect_comma();
        if kind == 1 && (as_cur() == '#' || as_cur() == '-' || as_is_digit(as_cur())) {
            as_put32(0x1E601000 | (as_fpimm8() << 13) | rd);       // fmov dN, #2.0
        } else if kind == 1 && as_at_freg() {
            int rf = as_parse_freg();                  // fmov dN, dM
            if as_fp_kind != 1 { as_fail(); }
            as_put32(0x1E604000 | (rf << 5) | rd);
        } else if kind == 1 {
            int rn = as_parse_reg();
            as_put32(0x9E670000 | (rn << 5) | rd);
        } else {
            int rw = as_parse_wreg();
            as_put32(0x1E270000 | (rw << 5) | rd);
        }
        return;
    }
    if as_cur() == 'w' {
        int rw2 = as_parse_wreg();
        as_expect_comma();
        int rs = as_parse_freg();
        if as_fp_kind != 0 { as_fail(); }
        as_put32(0x1E260000 | (rs << 5) | rw2);
        return;
    }
    int rx = as_parse_reg();
    as_expect_comma();
    int rd2 = as_parse_freg();
    if as_fp_kind != 1 { as_fail(); }
    as_put32(0x9E660000 | (rd2 << 5) | rx);
}

// scvtf / ucvtf dN, xN | sN, xN   (signed / unsigned integer to float)
void as_h_scvtf_base(int sbase, int dbase) {
    as_skip_spaces();
    int rd = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rn = as_parse_reg();
    int base = sbase;
    if kind == 1 { base = dbase; }
    as_put32(base | (rn << 5) | rd);
}

// scvtf dN, xN | scvtf sN, xN
void as_h_scvtf() {
    as_skip_spaces();
    int rd = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rn = as_parse_reg();
    int base = 0x9E220000;
    if kind == 1 { base = 0x9E620000; }
    as_put32(base | (rn << 5) | rd);
}

// fcvtzu xN, dN | fcvtzu xN, sN   (float to unsigned integer)
void as_h_fcvtzu() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_freg();
    int base = 0x9E390000;
    if as_fp_kind == 1 { base = 0x9E790000; }
    as_put32(base | (rn << 5) | rd);
}

// fcvtzs xN, dN | fcvtzs xN, sN
void as_h_fcvtzs() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_freg();
    int base = 0x9E380000;
    if as_fp_kind == 1 { base = 0x9E780000; }
    as_put32(base | (rn << 5) | rd);
}

// fcvt sN, dN | fcvt dN, sN
void as_h_fcvt() {
    as_skip_spaces();
    int rd = as_parse_freg();
    int kind = as_fp_kind;
    as_expect_comma();
    int rn = as_parse_freg();
    if as_fp_kind == kind { as_fail(); }
    int base = 0x1E624000;           // to single from double
    if kind == 1 { base = 0x1E22C000; }
    as_put32(base | (rn << 5) | rd);
}

// adr xN, label : the address of a label (within +-1 MB)
void as_h_adr() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    as_read_label_name();
    if as_pass == 1 {
        as_put32(0);
        return;
    }
    int delta = as_find_label() - as_pos;
    as_put32(0x10000000 | ((delta & 3) << 29) | (((delta >> 2) & 0x7FFFF) << 5) | rd);
}

// blr xN : call the function whose address is in a register
void as_h_blr() {
    as_skip_spaces();
    int rn = as_parse_reg();
    as_put32(0xD63F0000 | (rn << 5));
}

// ldaxr / ldxr xT, [xN] : load and mark the address for an exclusive store
void as_h_ldex(int base) {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    int rn = as_parse_reg_or_sp();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    as_put32(base | (rn << 5) | rt);
}

// stlxr / stxr wS, xT, [xN] : store if nothing else touched the address (wS = 0 on success)
void as_h_stex(int base) {
    as_skip_spaces();
    int rs = as_parse_wreg();
    as_expect_comma();
    int rt = as_parse_reg();
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    int rn = as_parse_reg_or_sp();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    as_put32(base | (rs << 16) | (rn << 5) | rt);
}

void as_h_svc() {
    as_skip_spaces();
    int n = as_parse_number();
    as_put32(0xD4000001 | (n << 5));
}

// ------------------------------------------------------- one instruction

// the mnemonic is in mn (zero padded, lower case); the cursor is after it
char as_mn[16];

bool as_mn_is(char^ s) {
    int i = 0;
    while i < 16 {
        if as_mn[i] != s[i] { return false; }
        if s[i] == 0 { return true; }
        i += 1;
    }
    return true;
}

void as_read_mnemonic() {
    int n = 0;
    while n < 16 { as_mn[n] = 0; n += 1; }
    n = 0;
    while as_ci < as_src_len && as_is_letter(as_src[as_ci]) || (n > 0 && as_ci < as_src_len && as_is_digit(as_src[as_ci])) {
        if n < 15 { as_mn[n] = as_src[as_ci]; }
        n += 1;
        as_ci += 1;
    }
}

// ------------------------------------------------- more of the instruction set (system, barriers, atomics, flags)

// two texts equal (this file also builds alone, without the library)
bool as_seq(char^ a, char^ b) {
    int i = 0;
    while a[i] != 0 && b[i] != 0 {
        if a[i] != b[i] { return false; }
        i += 1;
    }
    return a[i] == b[i];
}

// cbz / cbnz xN, label
void as_h_cbz(int base) {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    as_read_label_name();
    if as_pass == 1 { as_put32(0); return; }
    int delta = (as_find_label() - as_pos) >> 2;
    as_put32(base | ((delta & 0x7FFFF) << 5) | rt);
}

// tbz / tbnz xN, #bit, label
void as_h_tbz(int base) {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    if as_cur() == '#' { as_ci += 1; }
    int bit = as_parse_number();
    if bit > 63 { as_fail(); }
    as_expect_comma();
    as_skip_spaces();
    as_read_label_name();
    if as_pass == 1 { as_put32(0); return; }
    int delta = (as_find_label() - as_pos) >> 2;
    as_put32(base | ((bit >> 5) << 31) | ((bit & 31) << 19) | ((delta & 0x3FFF) << 5) | rt);
}

// br xN
void as_h_br() {
    as_skip_spaces();
    int rn = as_parse_reg();
    as_put32(0xD61F0000 | (rn << 5));
}

// mvn xd, xm    tst xn, xm   (two registers)
void as_h_mvn() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_put32(0xAA2003E0 | (rm << 16) | rd);
}

void as_h_tst() {
    as_skip_spaces();
    int rn = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_put32(0xEA00001F | (rm << 16) | (rn << 5));
}

// the option of a barrier: sy, st, ld, ish, ishst, ishld, nsh ..., or nothing (sy for isb / dsb, ish for dmb)
int as_barrier_option(int dflt) {
    as_skip_spaces();
    if !as_is_letter(as_cur()) { return dflt; }
    as_read_label_name();
    if as_seq(@as_nbuf, "sy") { return 15; }
    if as_seq(@as_nbuf, "st") { return 14; }
    if as_seq(@as_nbuf, "ld") { return 13; }
    if as_seq(@as_nbuf, "ish") { return 11; }
    if as_seq(@as_nbuf, "ishst") { return 10; }
    if as_seq(@as_nbuf, "ishld") { return 9; }
    if as_seq(@as_nbuf, "nsh") { return 7; }
    if as_seq(@as_nbuf, "nshst") { return 6; }
    if as_seq(@as_nbuf, "nshld") { return 5; }
    if as_seq(@as_nbuf, "osh") { return 3; }
    if as_seq(@as_nbuf, "oshst") { return 2; }
    if as_seq(@as_nbuf, "oshld") { return 1; }
    as_fail();
    return 0;
}

// csel xd, xn, xm, cond      cset xd, cond
void as_h_csel() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    int cond = as_parse_cond();
    as_put32(0x9A800000 | (rm << 16) | (cond << 12) | (rn << 5) | rd);
}

void as_h_cset() {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    int cond = as_parse_cond();
    as_put32(0x9A9F07E0 | ((cond xor 1) << 12) | rd);
}

// ldar / stlr / ldarb / stlrb ...   xt, [xn]
void as_h_acq(int base) {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    int rn = as_parse_reg_or_sp();
    as_skip_spaces();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    as_put32(base | (rn << 5) | rt);
}

// swp / ldadd / ldclr / ldset / ldeor and the a / l / al forms:  xs, xt, [xn]
void as_h_lse(int base) {
    as_skip_spaces();
    int rs = as_parse_reg();
    as_expect_comma();
    int rt = as_parse_reg();
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    int rn = as_parse_reg_or_sp();
    as_skip_spaces();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    as_put32(base | (rs << 16) | (rn << 5) | rt);
}

// brk / hvc / smc #imm16
void as_h_imm16(int base) {
    as_skip_spaces();
    if as_cur() == '#' { as_ci += 1; }
    int v = as_parse_number();
    as_put32(base | ((v & 65535) << 5));
}

// system register: the 15 bits o0:op1:CRn:CRm:op2 in place
int as_sr(int op0, int op1, int crn, int crm, int op2) {
    return ((op0 & 1) << 19) | (op1 << 16) | (crn << 12) | (crm << 8) | (op2 << 5);
}

// the 15 bits of a system register by its name (lower case), or -1
int as_sysreg_code(char^ n) {
    if as_seq(n, "sctlr_el1") { return as_sr(3, 0, 1, 0, 0); }
    if as_seq(n, "actlr_el1") { return as_sr(3, 0, 1, 0, 1); }
    if as_seq(n, "cpacr_el1") { return as_sr(3, 0, 1, 0, 2); }
    if as_seq(n, "ttbr0_el1") { return as_sr(3, 0, 2, 0, 0); }
    if as_seq(n, "ttbr1_el1") { return as_sr(3, 0, 2, 0, 1); }
    if as_seq(n, "tcr_el1") { return as_sr(3, 0, 2, 0, 2); }
    if as_seq(n, "spsr_el1") { return as_sr(3, 0, 4, 0, 0); }
    if as_seq(n, "elr_el1") { return as_sr(3, 0, 4, 0, 1); }
    if as_seq(n, "sp_el0") { return as_sr(3, 0, 4, 1, 0); }
    if as_seq(n, "currentel") { return as_sr(3, 0, 4, 2, 2); }
    if as_seq(n, "nzcv") { return as_sr(3, 3, 4, 2, 0); }
    if as_seq(n, "daif") { return as_sr(3, 3, 4, 2, 1); }
    if as_seq(n, "fpcr") { return as_sr(3, 3, 4, 4, 0); }
    if as_seq(n, "fpsr") { return as_sr(3, 3, 4, 4, 1); }
    if as_seq(n, "esr_el1") { return as_sr(3, 0, 5, 2, 0); }
    if as_seq(n, "far_el1") { return as_sr(3, 0, 6, 0, 0); }
    if as_seq(n, "mair_el1") { return as_sr(3, 0, 10, 2, 0); }
    if as_seq(n, "vbar_el1") { return as_sr(3, 0, 12, 0, 0); }
    if as_seq(n, "tpidr_el1") { return as_sr(3, 0, 13, 0, 4); }
    if as_seq(n, "tpidr_el0") { return as_sr(3, 3, 13, 0, 2); }
    if as_seq(n, "tpidrro_el0") { return as_sr(3, 3, 13, 0, 3); }
    if as_seq(n, "cntkctl_el1") { return as_sr(3, 0, 14, 1, 0); }
    if as_seq(n, "cntfrq_el0") { return as_sr(3, 3, 14, 0, 0); }
    if as_seq(n, "cntvct_el0") { return as_sr(3, 3, 14, 0, 2); }
    if as_seq(n, "cntpct_el0") { return as_sr(3, 3, 14, 0, 1); }
    if as_seq(n, "cntp_tval_el0") { return as_sr(3, 3, 14, 2, 0); }
    if as_seq(n, "cntp_ctl_el0") { return as_sr(3, 3, 14, 2, 1); }
    if as_seq(n, "cntv_tval_el0") { return as_sr(3, 3, 14, 3, 0); }
    if as_seq(n, "cntv_ctl_el0") { return as_sr(3, 3, 14, 3, 1); }
    if as_seq(n, "midr_el1") { return as_sr(3, 0, 0, 0, 0); }
    if as_seq(n, "mpidr_el1") { return as_sr(3, 0, 0, 0, 5); }
    if as_seq(n, "id_aa64pfr0_el1") { return as_sr(3, 0, 0, 4, 0); }
    if as_seq(n, "id_aa64isar0_el1") { return as_sr(3, 0, 0, 6, 0); }
    if as_seq(n, "id_aa64mmfr0_el1") { return as_sr(3, 0, 0, 7, 0); }
    // the general form  s3_0_c12_c0_0  (op0 _ op1 _ cCRn _ cCRm _ op2)
    if n[0] == 's' && n[1] >= '0' && n[1] <= '9' {
        int i = 1;
        int vals[5];
        int k = 0;
        while k < 5 {
            if k == 2 || k == 3 {
                if n[i] != 'c' { return 0 - 1; }
                i += 1;
            }
            int v = 0;
            while n[i] >= '0' && n[i] <= '9' { v = v * 10 + (n[i] - '0'); i += 1; }
            vals[k] = v;
            if k < 4 {
                if n[i] != '_' { return 0 - 1; }
                i += 1;
            }
            k += 1;
        }
        return as_sr(vals[0], vals[1], vals[2], vals[3], vals[4]);
    }
    return 0 - 1;
}

int as_sysreg() {
    as_skip_spaces();
    as_read_label_name();
    int c = as_sysreg_code(@as_nbuf);
    if c < 0 { as_fail(); }
    return c;
}

void as_h_mrs() {
    as_skip_spaces();
    int rt = as_parse_reg();
    as_expect_comma();
    int sr = as_sysreg();
    as_put32(0xD5300000 | sr | rt);
}

void as_h_msr() {
    as_skip_spaces();
    // the fields of PSTATE with a number:  msr daifset, #3
    if as_cur() == 'd' && as_peek(1) == 'a' && as_peek(2) == 'i' && as_peek(3) == 'f' && (as_peek(4) == 's' || as_peek(4) == 'c') {
        int set = 0;
        if as_peek(4) == 's' { set = 1; }
        as_ci += 7;                                  // daifset / daifclr
        as_expect_comma();
        as_skip_spaces();
        if as_cur() == '#' { as_ci += 1; }
        int v = as_parse_number() & 15;
        int op2 = 7;
        if set == 1 { op2 = 6; }
        as_put32(0xD500401F | (3 << 16) | (v << 8) | (op2 << 5));
        return;
    }
    int sr = as_sysreg();
    as_expect_comma();
    int rt = as_parse_reg();
    as_put32(0xD5100000 | sr | rt);
}

// dc <op>, xt   ic <op>, xt   (cache maintenance by address)
void as_h_cache(bool data) {
    as_skip_spaces();
    as_read_label_name();
    int enc = 0;
    bool needs_reg = true;
    if data {
        if as_seq(@as_nbuf, "cvac") { enc = 0xD50B7A20; }
        else if as_seq(@as_nbuf, "cvau") { enc = 0xD50B7B20; }
        else if as_seq(@as_nbuf, "civac") { enc = 0xD50B7E20; }
        else if as_seq(@as_nbuf, "ivac") { enc = 0xD5087620; }
        else if as_seq(@as_nbuf, "zva") { enc = 0xD50B7420; }
        else if as_seq(@as_nbuf, "cvap") { enc = 0xD50B7C20; }
        else { as_fail(); }
    } else {
        if as_seq(@as_nbuf, "ivau") { enc = 0xD50B7520; }
        else if as_seq(@as_nbuf, "iallu") { enc = 0xD508751F; needs_reg = false; }
        else if as_seq(@as_nbuf, "ialluis") { enc = 0xD508711F; needs_reg = false; }
        else { as_fail(); }
    }
    if needs_reg {
        as_expect_comma();
        int rt = as_parse_reg();
        as_put32(enc | rt);
    } else {
        as_put32(enc);
    }
}

// a mnemonic of the last group; true if it was one
bool as_more() {
    if as_mn_is("dc") { as_h_cache(true); return true; }
    if as_mn_is("ic") { as_h_cache(false); return true; }
    if as_mn_is("nop") { as_put32(0xD503201F); return true; }
    if as_mn_is("wfi") { as_put32(0xD503207F); return true; }
    if as_mn_is("wfe") { as_put32(0xD503205F); return true; }
    if as_mn_is("sev") { as_put32(0xD503209F); return true; }
    if as_mn_is("sevl") { as_put32(0xD50320BF); return true; }
    if as_mn_is("yield") { as_put32(0xD503203F); return true; }
    if as_mn_is("eret") { as_put32(0xD69F03E0); return true; }
    if as_mn_is("isb") { int o = as_barrier_option(15); as_put32(0xD50330DF | (o << 8)); return true; }
    if as_mn_is("dsb") { int o2 = as_barrier_option(15); as_put32(0xD503309F | (o2 << 8)); return true; }
    if as_mn_is("br") { as_h_br(); return true; }
    if as_mn_is("cbz") { as_h_cbz(0xB4000000); return true; }
    if as_mn_is("cbnz") { as_h_cbz(0xB5000000); return true; }
    if as_mn_is("tbz") { as_h_tbz(0x36000000); return true; }
    if as_mn_is("tbnz") { as_h_tbz(0x37000000); return true; }
    if as_mn_is("mvn") { as_h_mvn(); return true; }
    if as_mn_is("tst") { as_h_tst(); return true; }
    if as_mn_is("bic") { as_h_rrr(0x8A200000); return true; }
    if as_mn_is("orn") { as_h_rrr(0xAA200000); return true; }
    if as_mn_is("eon") { as_h_rrr(0xCA200000); return true; }
    if as_mn_is("ands") { as_h_rrr(0xEA000000); return true; }
    if as_mn_is("adds") { as_h_rrr(0xAB000000); return true; }
    if as_mn_is("subs") { as_h_rrr(0xEB000000); return true; }
    if as_mn_is("adc") { as_h_rrr(0x9A000000); return true; }
    if as_mn_is("adcs") { as_h_rrr(0xBA000000); return true; }
    if as_mn_is("sbc") { as_h_rrr(0xDA000000); return true; }
    if as_mn_is("sbcs") { as_h_rrr(0xFA000000); return true; }
    if as_mn_is("umulh") { as_h_rrr(0x9BC07C00); return true; }
    if as_mn_is("csel") { as_h_csel(); return true; }
    if as_mn_is("cset") { as_h_cset(); return true; }
    if as_mn_is("ldrh") { as_h_mem(0x7940, 1); return true; }
    if as_mn_is("strh") { as_h_mem(0x7900, 1); return true; }
    if as_mn_is("ldrsh") { as_h_mem(0x7980, 1); return true; }
    if as_mn_is("ldar") { as_h_acq(0xC8DFFC00); return true; }
    if as_mn_is("stlr") { as_h_acq(0xC89FFC00); return true; }
    if as_mn_is("ldarb") { as_h_acq(0x08DFFC00); return true; }
    if as_mn_is("stlrb") { as_h_acq(0x089FFC00); return true; }
    if as_mn_is("swp") { as_h_lse(0xF8208000); return true; }
    if as_mn_is("swpa") { as_h_lse(0xF8A08000); return true; }
    if as_mn_is("swpl") { as_h_lse(0xF8608000); return true; }
    if as_mn_is("swpal") { as_h_lse(0xF8E08000); return true; }
    if as_mn_is("ldadd") { as_h_lse(0xF8200000); return true; }
    if as_mn_is("ldadda") { as_h_lse(0xF8A00000); return true; }
    if as_mn_is("ldaddl") { as_h_lse(0xF8600000); return true; }
    if as_mn_is("ldaddal") { as_h_lse(0xF8E00000); return true; }
    if as_mn_is("ldclr") { as_h_lse(0xF8201000); return true; }
    if as_mn_is("ldclral") { as_h_lse(0xF8E01000); return true; }
    if as_mn_is("ldset") { as_h_lse(0xF8203000); return true; }
    if as_mn_is("ldsetal") { as_h_lse(0xF8E03000); return true; }
    if as_mn_is("ldeor") { as_h_lse(0xF8202000); return true; }
    if as_mn_is("ldeoral") { as_h_lse(0xF8E02000); return true; }
    if as_mn_is("brk") { as_h_imm16(0xD4200000); return true; }
    if as_mn_is("hvc") { as_h_imm16(0xD4000002); return true; }
    if as_mn_is("smc") { as_h_imm16(0xD4000003); return true; }
    if as_mn_is("mrs") { as_h_mrs(); return true; }
    if as_mn_is("msr") { as_h_msr(); return true; }
    return false;
}

void as_instruction() {
    if as_cur() == '.' {                    // ".bss N"  ".quad label|number"  ".asciz "text""
        as_ci += 1;
        as_read_mnemonic();
        if as_mn_is("quad") {
            // 8 bytes, aligned to 8: a number, or the address of a label (where the program is loaded)
            if as_pos % 8 != 0 { as_put32(0); }
            as_skip_spaces();
            int lo = 0;
            if as_cur() >= '0' && as_cur() <= '9' {
                lo = as_parse_number();
            } else {
                as_read_label_name();
                if as_pass == 2 { lo = as_find_label() + 0x4000B0; }
            }
            as_put32(lo & 4294967295);
            as_put32((lo >> 32) & 4294967295);
            return;
        }
        if as_mn_is("align") {
            // pad with nops until the address (where the program is loaded: 0x4000B0 + as_pos) is a multiple of N bytes
            as_skip_spaces();
            int an = as_parse_number();
            if an < 4 || an > 4096 { as_fail(); }
            while (as_pos + 176) % an != 0 { as_put32(0xD503201F); }
            return;
        }
        if as_mn_is("asciz") {
            // a text between double quotes (no escapes), a 0 byte after it, padded to a multiple of 4
            as_skip_spaces();
            if as_cur() != 34 { as_fail(); }
            as_ci += 1;
            int w = 0;
            int nb = 0;
            while as_ci < as_src_len && as_src[as_ci] != 34 {
                w = w | (as_src[as_ci] << (nb * 8));
                nb += 1;
                if nb == 4 {
                    as_put32(w);
                    w = 0;
                    nb = 0;
                }
                as_ci += 1;
            }
            as_ci += 1;
            as_put32(w);                    // the rest of the text and the 0 byte (a new word if the text filled the last one)
            return;
        }
        if !as_mn_is("bss") { as_fail(); }
        as_skip_spaces();
        as_bss_size = as_parse_number();
        return;
    }
    as_read_mnemonic();
    if as_mn_is("mov") { as_h_mov(); return; }
    if as_mn_is("add") { as_h_addsub(true); return; }
    if as_mn_is("sub") { as_h_addsub(false); return; }
    if as_mn_is("cmp") { as_h_cmp(); return; }
    if as_mn_is("mul") { as_h_rrr(0x9B007C00); return; }
    if as_mn_is("udiv") { as_h_rrr(0x9AC00800); return; }
    if as_mn_is("sdiv") { as_h_rrr(0x9AC00C00); return; }
    if as_mn_is("and") { as_h_rrr(0x8A000000); return; }
    if as_mn_is("orr") { as_h_rrr(0xAA000000); return; }
    if as_mn_is("eor") { as_h_rrr(0xCA000000); return; }
    if as_mn_is("lsl") { as_h_shift(0x9AC02000, 0); return; }
    if as_mn_is("lsr") { as_h_shift(0x9AC02400, 1); return; }
    if as_mn_is("asr") { as_h_shift(0x9AC02800, 2); return; }
    if as_mn_is("msub") { as_h_rrrr(0x9B008000); return; }
    if as_mn_is("madd") { as_h_rrrr(0x9B000000); return; }
    if as_mn_is("smulh") { as_h_rrr(0x9B407C00); return; }
    if as_mn_is("ror") { as_h_shift(0x9AC02C00, 3); return; }
    if as_mn_is("neg") { as_h_neg(); return; }
    if as_mn_is("clz") { as_h_sxt(0xDAC0, 0x1000); return; }
    if as_mn_is("rbit") { as_h_sxt(0xDAC0, 0x0000); return; }
    if as_mn_is("rev") { as_h_sxt(0xDAC0, 0x0C00); return; }
    if as_mn_is("popcnt") { as_h_popcnt(); return; }
    if as_mn_is("fmovi") {
        as_skip_spaces();
        int fd = as_parse_freg();
        as_expect_comma();
        int im = as_parse_number();
        as_put32(0x1E601000 | ((im & 255) << 13) | fd);
        return;
    }
    if as_mn_is("stp") { as_h_pair(true); return; }
    if as_mn_is("ldp") { as_h_pair(false); return; }
    if as_mn_is("ldr") { as_h_mem(0xF940, 3); return; }
    if as_mn_is("str") { as_h_mem(0xF900, 3); return; }
    if as_mn_is("ldrb") { as_h_mem(0x3940, 0); return; }
    if as_mn_is("ldrsb") { as_h_mem(0x3980, 0); return; }
    if as_mn_is("ldrsw") { as_h_mem(0xB980, 2); return; }
    if as_mn_is("strb") { as_h_mem(0x3900, 0); return; }
    if as_mn_is("strw") { as_h_mem(0xB900, 2); return; }
    if as_mn_is("ldaxr") { as_h_ldex(0xC85FFC00); return; }
    if as_mn_is("ldxr") { as_h_ldex(0xC85F7C00); return; }
    if as_mn_is("stlxr") { as_h_stex(0xC800FC00); return; }
    if as_mn_is("stxr") { as_h_stex(0xC8007C00); return; }
    if as_mn_is("dmb") { int dob = as_barrier_option(11); as_put32(0xD50330BF | (dob << 8)); return; }       // dmb ish by default
    if as_mn_is("clrex") { as_put32(0xD5033F5F); return; }
    if as_mn_is("adr") { as_h_adr(); return; }
    if as_mn_is("blr") { as_h_blr(); return; }
    if as_mn_is("ldrw") { as_h_mem(0xB940, 2); return; }
    if as_mn_is("uxtw") { as_h_sxt(0xD340, 0x7C00); return; }
    if as_mn_is("ucvtf") { as_h_scvtf_base(0x9E230000, 0x9E630000); return; }
    if as_mn_is("fcvtzu") { as_h_fcvtzu(); return; }
    if as_mn_is("sxtb") { as_h_sxt(0x9340, 0x1C00); return; }
    if as_mn_is("sxtw") { as_h_sxt(0x9340, 0x7C00); return; }
    if as_mn_is("uxtb") { as_h_sxt(0xD340, 0x1C00); return; }
    if as_mn_is("b") { as_h_branch(); return; }
    if as_mn_is("bl") { as_ci -= 1; as_h_branch(); return; }
    if as_mn_is("ret") { as_put32(0xD65F03C0); return; }
    if as_mn_is("svc") { as_h_svc(); return; }
    if as_mn_is("fadd") { as_h_fp3(0x1E602800, 0x1E202800); return; }
    if as_mn_is("fsub") { as_h_fp3(0x1E603800, 0x1E203800); return; }
    if as_mn_is("fmul") { as_h_fp3(0x1E600800, 0x1E200800); return; }
    if as_mn_is("fdiv") { as_h_fp3(0x1E601800, 0x1E201800); return; }
    if as_mn_is("fneg") { as_h_fp2(0x1E614000, 0x1E214000); return; }
    if as_mn_is("fabs") { as_h_fp2(0x1E60C000, 0x1E20C000); return; }
    if as_mn_is("fsqrt") { as_h_fp2(0x1E61C000, 0x1E21C000); return; }
    if as_mn_is("frintm") { as_h_fp2(0x1E654000, 0x1E254000); return; }
    if as_mn_is("frintp") { as_h_fp2(0x1E64C000, 0x1E24C000); return; }
    if as_mn_is("frintz") { as_h_fp2(0x1E65C000, 0x1E25C000); return; }
    if as_mn_is("fcmp") { as_h_fcmp(); return; }
    if as_mn_is("fmov") { as_h_fmov(); return; }
    if as_mn_is("scvtf") { as_h_scvtf(); return; }
    if as_mn_is("fcvtzs") { as_h_fcvtzs(); return; }
    if as_mn_is("fcvt") { as_h_fcvt(); return; }
    if as_more() { return; }
    as_fail();
}

void as_skip_to_eol() {
    while as_ci < as_src_len && as_src[as_ci] != 10 { as_ci += 1; }
}

// one whole pass over the text
void as_run_pass() {
    as_ci = 0;
    as_pos = 0;
    while as_ci < as_src_len {
        int c = as_src[as_ci];
        if c == 32 || c == 10 || c == 9 {
            as_ci += 1;
        } else {
            if as_peek_is_label() {
                as_read_label_name();
                as_ci += 1;                 // ':'
                if as_pass == 1 { as_add_label(); }
                as_skip_spaces();
                if as_ci < as_src_len && as_src[as_ci] != 10 {
                    as_instruction();
                    as_skip_to_eol();
                }
            } else {
                as_instruction();
                as_skip_to_eol();
            }
        }
    }
}

// ------------------------------------------------------------- the output

void as_put_hdr(int at, int bytes, int v) {
    int i = 0;
    while i < bytes {
        as_hdr[at + i] = (v >> (8 * i)) & 255;
        i += 1;
    }
}

void as_build_header() {
    int i = 0;
    while i < 176 { as_hdr[i] = 0; i += 1; }
    as_hdr[0] = 0x7f; as_hdr[1] = 0x45; as_hdr[2] = 0x4c; as_hdr[3] = 0x46;
    as_hdr[4] = 2; as_hdr[5] = 1; as_hdr[6] = 1;
    as_put_hdr(16, 2, 2);                   // e_type = EXEC
    as_put_hdr(18, 2, 0xb7);                // e_machine = AArch64
    as_put_hdr(20, 4, 1);
    as_put_hdr(24, 8, 0x4000B0);            // e_entry
    as_put_hdr(32, 8, 64);                  // e_phoff
    as_put_hdr(52, 2, 64);
    as_put_hdr(54, 2, 56);
    as_put_hdr(56, 2, 2);                   // two program headers
    as_put_hdr(64, 4, 1);                   // segment 1: code, R+X
    as_put_hdr(68, 4, 5);
    as_put_hdr(80, 8, 0x400000);
    as_put_hdr(88, 8, 0x400000);
    as_put_hdr(96, 8, 176 + as_pos);
    as_put_hdr(104, 8, 176 + as_pos);
    as_put_hdr(112, 8, 0x10000);
    as_put_hdr(120, 4, 1);                  // segment 2: data (bss), R+W
    as_put_hdr(124, 4, 6);
    as_put_hdr(136, 8, 0x10000000);
    as_put_hdr(144, 8, 0x10000000);
    int mem = (as_bss_size + 4095) & ~4095;
    if mem < 4096 { mem = 4096; }
    as_put_hdr(160, 8, mem);
    as_put_hdr(168, 8, 0x1000);
}


// ------------------------------------------------- the library entry points

// as_src[0 .. len) holds the .jasm text: assemble it (exits with a message on error)
void as_assemble(int len) {
    as_src_len = len;
    as_pass = 1;
    as_run_pass();
    as_pass = 2;
    as_run_pass();
    as_build_header();
}

// write the ELF file of the last as_assemble
void as_write_elf(char^ path) {
    int out = syscall(56, -100, path, 577, 493);
    if out < 0 {
        char e1[48] = "cannot write the program file '";
        syscall(64, 2, @e1, 31);
        int pn = 0;
        while path[pn] != 0 { pn += 1; }
        syscall(64, 2, path, pn);
        char e2[96] = "' (a folder with that name, a program that is running, or no permission?)\n";
        syscall(64, 2, @e2, 74);
        syscall(93, 1);
    }
    syscall(64, out, @as_hdr, 176);
    syscall(64, out, @as_code, as_pos);
    syscall(57, out);
}
