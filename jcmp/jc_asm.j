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

char as_lnames[786432];         // label table: 32768 names x 24 bytes
int as_laddr[32768];
int as_label_count;
char as_nbuf[24];               // the label name just read (zero padded)

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
    int v = 0;
    while as_ci < as_src_len && as_is_digit(as_src[as_ci]) {
        v = v * 10 + (as_src[as_ci] - '0');
        as_ci += 1;
    }
    return v;
}

int as_parse_signed() {
    if as_cur() == '-' {
        as_ci += 1;
        return 0 - as_parse_number();
    }
    return as_parse_number();
}

int as_parse_reg() {
    if as_cur() != 'x' { as_fail(); }
    as_ci += 1;
    return as_parse_number();
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
    while n < 24 { as_nbuf[n] = 0; n += 1; }
    n = 0;
    while as_ci < as_src_len && as_is_name_char(as_src[as_ci]) {
        if n < 23 { as_nbuf[n] = as_src[as_ci]; }
        n += 1;
        as_ci += 1;
    }
}

bool as_name_matches(int slot) {
    int i = 0;
    while i < 24 {
        if as_lnames[slot * 24 + i] != as_nbuf[i] { return false; }
        i += 1;
    }
    return true;
}

void as_add_label() {
    if as_label_count >= 32768 { as_fail(); }
    int i = 0;
    while i < 24 {
        as_lnames[as_label_count * 24 + i] = as_nbuf[i];
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
    if as_cur() == 'x' {
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
void as_h_rrr(int base) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    int rm = as_parse_reg();
    as_put32(base | (rm << 16) | (rn << 5) | rd);
}

// ldr/str family: op = the instruction's high 16 bits, shift = log2(size)
void as_h_mem(int op, int shift) {
    as_skip_spaces();
    int rt = as_parse_reg();
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
void as_h_fmov() {
    as_skip_spaces();
    if as_at_freg() {
        int rd = as_parse_freg();
        int kind = as_fp_kind;
        as_expect_comma();
        if kind == 1 {
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

void as_instruction() {
    if as_cur() == '.' {                    // ".bss N"
        as_ci += 1;
        as_read_mnemonic();
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
    if as_mn_is("lsl") { as_h_rrr(0x9AC02000); return; }
    if as_mn_is("lsr") { as_h_rrr(0x9AC02400); return; }
    if as_mn_is("asr") { as_h_rrr(0x9AC02800); return; }
    if as_mn_is("ldr") { as_h_mem(0xF940, 3); return; }
    if as_mn_is("str") { as_h_mem(0xF900, 3); return; }
    if as_mn_is("ldrb") { as_h_mem(0x3940, 0); return; }
    if as_mn_is("ldrsb") { as_h_mem(0x3980, 0); return; }
    if as_mn_is("ldrsw") { as_h_mem(0xB980, 2); return; }
    if as_mn_is("strb") { as_h_mem(0x3900, 0); return; }
    if as_mn_is("strw") { as_h_mem(0xB900, 2); return; }
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
    if out < 0 { as_fail(); }
    syscall(64, out, @as_hdr, 176);
    syscall(64, out, @as_code, as_pos);
    syscall(57, out);
}
