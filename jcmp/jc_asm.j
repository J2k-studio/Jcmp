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
int as_dyn;                     // 1: a dynamic executable (with -l's layout): PT_INTERP, DT_NEEDED libdl.so libc.so, the entry is the first instruction
int as_lib;                     // 1: the output is a shared library (.so), not a program
int as_xn_n;                    // the symbols a library gives to others (.export NAME LABEL)
int as_has_init;                // 1: .init LABEL, the function the loader runs when the library is loaded (DT_INIT)
int as_init_slot;
char as_xn_name[4096];          // 64 names x 64 bytes
int as_xn_slot[64];             // the label that holds the address
char as_so_hdr[344];            // the ELF header and the 4 program headers of a library
char as_so_meta[65536];         // after the code: the symbols, their names, the hash table and the dynamic section
int as_so_m0;                   // the file place of as_so_meta
int as_so_metalen;
int as_so_v;                    // where the global area (.bss) starts in the library, a page boundary
char as_so_zero[4096];

// the address (in the file and in memory) of the first instruction: 176 in a program, 288 in a library
int as_base() {
    if as_lib == 1 { return as_h(); }
    return 176;
}
// the size of the ELF header and the program headers of a library (a dynamic executable has one more: PT_PHDR)
int as_h() {
    if as_dyn == 1 { return 344; }
    return 288;
}
int as_last_is_sp;              // parse_reg_or_sp: was it "sp"?
char as_hdr[176];               // the ELF header

// ---------------------------------------------------------------- errors

int as_embedded;                // 1 inside jcmp: the text is written by the compiler, so an error here is a compiler bug

// the line of the text at the cursor, for the message of a compiler bug
void as_fail_internal() {
    int a = as_ci;
    if a >= as_src_len { a = as_src_len - 1; }
    while a > 0 && as_src[a - 1] != 10 { a -= 1; }
    int b = a;
    while b < as_src_len && as_src[b] != 10 && b - a < 200 { b += 1; }
    char m1[96] = "internal error: the assembler could not read this line of the code written by jcmp:\n  ";
    syscall(64, 2, @m1, 86);
    syscall(64, 2, @as_src[a], b - a);
    char m2[200] = "\nThis is a bug in jcmp, not in your program. Please report it with your source file (jcmp file.jk -o out -emit-asm file.s keeps the text).\n";
    syscall(64, 2, @m2, 139);
    syscall(93, 1);
}

void as_fail() {
    if as_embedded == 1 { as_fail_internal(); }
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

// ----------------------------------------------------- NEON vector registers (vN.2d, vN.4s)
int as_vec_arr;                 // after as_parse_vreg: 1 = .2d, 2 = .4s

bool as_at_vreg() {
    as_skip_spaces();
    return as_cur() == 'v' && as_is_digit(as_peek(1));
}

int as_parse_vreg() {
    if as_cur() != 'v' { as_fail(); }
    as_ci += 1;
    int n = as_parse_number();
    if n > 31 { as_fail(); }
    if as_cur() != '.' { as_fail(); }
    as_ci += 1;
    int cnt = as_parse_number();
    int c = as_cur();
    as_ci += 1;
    if cnt == 2 && c == 'd' { as_vec_arr = 1; }
    else if cnt == 4 && c == 's' { as_vec_arr = 2; }
    else if cnt == 16 && c == 'b' { as_vec_arr = 3; }
    else { as_fail(); }
    return n;
}

// umov xD, vN.d[i]   umov wD, vN.s[i]   smov xD, vN.s[i]   ins vD.d[i], xN   ins vD.s[i], wN   ins vD.d[i], vN.d[0]
// dup dD, vN.d[i]  (one lane of a vector)
int as_lane_idx;                // after as_parse_vlane: the index
int as_lane_sz;                 // 8 (.d) or 4 (.s)

int as_parse_vlane() {
    if as_cur() != 'v' { as_fail(); }
    as_ci += 1;
    int n = as_parse_number();
    if n > 31 || as_cur() != '.' { as_fail(); }
    as_ci += 1;
    int c = as_cur();
    as_ci += 1;
    if c == 'd' { as_lane_sz = 8; } else if c == 's' { as_lane_sz = 4; } else { as_fail(); }
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_lane_idx = as_parse_number();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    if as_lane_sz == 8 && as_lane_idx > 1 { as_fail(); }
    if as_lane_sz == 4 && as_lane_idx > 3 { as_fail(); }
    return n;
}

void as_h_umov(bool signed) {
    as_skip_spaces();
    int rd = 0;
    bool wide = false;
    if as_cur() == 'x' { rd = as_parse_reg(); wide = true; } else { rd = as_parse_wreg(); }
    as_expect_comma();
    int rn = as_parse_vlane();
    int base = 0;
    if as_lane_sz == 8 {
        if signed || !wide { as_fail(); }
        base = 0x4E083C00 | (as_lane_idx << 20);
    } else {
        int imm5 = (as_lane_idx << 3) | 4;
        if signed {
            if !wide { as_fail(); }
            base = 0x4E002C00 | (imm5 << 16);
        } else {
            if wide { as_fail(); }
            base = 0x0E003C00 | (imm5 << 16);
        }
    }
    as_put32(base | (rn << 5) | rd);
}

void as_h_ins() {
    as_skip_spaces();
    int rd = as_parse_vlane();
    int sz = as_lane_sz;
    int idx = as_lane_idx;
    as_expect_comma();
    if as_cur() == 'v' {
        int rn = as_parse_vlane();
        if as_lane_sz != sz || as_lane_idx != 0 { as_fail(); }
        int imm5 = (idx << 4) | 8;
        if sz == 4 { imm5 = (idx << 3) | 4; }
        as_put32(0x6E000400 | (imm5 << 16) | (rn << 5) | rd);
        return;
    }
    int rn2 = 0;
    int imm5b = 0;
    if sz == 8 {
        rn2 = as_parse_reg();
        imm5b = (idx << 4) | 8;
    } else {
        rn2 = as_parse_wreg();
        imm5b = (idx << 3) | 4;
    }
    as_put32(0x4E001C00 | (imm5b << 16) | (rn2 << 5) | rd);
}

// mov vD.16b, vN.16b
void as_h_vmov() {
    int rd = as_parse_vreg();
    if as_vec_arr != 3 { as_fail(); }
    as_expect_comma();
    int rn = as_parse_vreg();
    if as_vec_arr != 3 { as_fail(); }
    as_put32(0x4EA01C00 | (rn << 16) | (rn << 5) | rd);
}

// dup vD.2d, xN   /   dup vD.4s, wN   (the same number in every lane)
void as_h_dup() {
    as_skip_spaces();
    if as_cur() == 'd' && as_is_digit(as_peek(1)) {
        // dup dD, vN.d[i]: one 64-bit lane into a double register
        int fd = as_parse_freg();
        as_expect_comma();
        int vn = as_parse_vlane();
        if as_lane_sz != 8 { as_fail(); }
        as_put32(0x5E080400 | (as_lane_idx << 20) | (vn << 5) | fd);
        return;
    }
    int rd = as_parse_vreg();
    as_expect_comma();
    int rn = 0;
    int base = 0x4E080C00;
    if as_vec_arr == 1 {
        rn = as_parse_reg();
    } else if as_vec_arr == 3 {
        base = 0x4E010C00;
        rn = as_parse_wreg();
    } else {
        base = 0x4E040C00;
        rn = as_parse_wreg();
    }
    as_put32(base | (rn << 5) | rd);
}

// vD.T, vN.T, vM.T with the opcode for .2d (op2d) or .4s (op4s); 0 = not allowed
void as_h_vec3(int op2d, int op4s) {
    as_h_vec3b(op2d, op4s, 0);
}

// the same with a third encoding for the 16 bytes (.16b); 0 = the arrangement is not allowed
void as_h_vec3b(int op2d, int op4s, int op16b) {
    as_skip_spaces();
    int rd = as_parse_vreg();
    int arr = as_vec_arr;
    as_expect_comma();
    int rn = as_parse_vreg();
    if as_vec_arr != arr { as_fail(); }
    as_expect_comma();
    int rm = as_parse_vreg();
    if as_vec_arr != arr { as_fail(); }
    int base = op4s;
    if arr == 1 { base = op2d; }
    if arr == 3 { base = op16b; }
    if base == 0 { as_fail(); }
    as_put32(base | (rm << 16) | (rn << 5) | rd);
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
    as_patch32(as_pos, w);
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

int as_lhash[65536];             // the labels by name: slot + 1 (open addressing)
int as_fx_pos[131072];          // the references to labels that are not defined yet: where the word is, its kind, the label, the word, the place in the text
int as_fx_kind[131072];
int as_fx_slot[131072];
int as_fx_base[131072];
int as_fx_ci[131072];
int as_fx_n;

int as_name_hash() {
    int h = 5381;
    int i = 0;
    while i < 64 && as_nbuf[i] != 0 {
        h = (h * 33 + as_nbuf[i]) & 1073741823;
        i += 1;
    }
    return h & 65535;
}

// the slot of the label whose name is in as_nbuf: made (not defined yet: address -1) when it is new
int as_label_slot() {
    int h = as_name_hash();
    while as_lhash[h] != 0 {
        int sl = as_lhash[h] - 1;
        if as_name_matches(sl) { return sl; }
        h = (h + 1) & 65535;
    }
    if as_label_count >= 32768 { as_fail(); }
    int i = 0;
    while i < 64 {
        as_lnames[as_label_count * 64 + i] = as_nbuf[i];
        i += 1;
    }
    as_laddr[as_label_count] = 0 - 1;
    as_lhash[h] = as_label_count + 1;
    as_label_count += 1;
    return as_label_count - 1;
}

// the label in as_nbuf is defined here (the first definition counts)
void as_add_label() {
    int sl = as_label_slot();
    if as_laddr[sl] < 0 { as_laddr[sl] = as_pos; }
}

// the bits of a reference: kind 1 = the 26 bits of b / bl, 2 = 19 bits at bit 5 (b.cond, cbz, cbnz), 3 = 14 bits at bit 5 (tbz, tbnz),
// 4 = adr (a distance in bytes)
int as_ref_bits(int kind, int delta) {
    if kind == 1 { return (delta >> 2) & 0x3FFFFFF; }
    if kind == 2 { return ((delta >> 2) & 0x7FFFF) << 5; }
    if kind == 3 { return ((delta >> 2) & 0x3FFF) << 5; }
    return ((delta & 3) << 29) | (((delta >> 2) & 0x7FFFF) << 5);
}

// an instruction that names the label in as_nbuf: written at once when the label is known, else a hole that is filled at the end
void as_emit_ref(int base, int kind) {
    int sl = as_label_slot();
    if as_laddr[sl] >= 0 {
        as_put32(base | as_ref_bits(kind, as_laddr[sl] - as_pos));
        return;
    }
    if as_fx_n >= 131072 { as_fail(); }
    as_fx_pos[as_fx_n] = as_pos;
    as_fx_kind[as_fx_n] = kind;
    as_fx_slot[as_fx_n] = sl;
    as_fx_base[as_fx_n] = base;
    as_fx_ci[as_fx_n] = as_ci;
    as_fx_n += 1;
    as_put32(base);
}

void as_patch32(int at, int w) {
    as_code[at] = w & 255;
    as_code[at + 1] = (w >> 8) & 255;
    as_code[at + 2] = (w >> 16) & 255;
    as_code[at + 3] = (w >> 24) & 255;
}

// the end of the single pass: every hole gets its distance
void as_resolve() {
    int f = 0;
    while f < as_fx_n {
        int sl = as_fx_slot[f];
        if as_laddr[sl] < 0 {
            as_ci = as_fx_ci[f];          // the message points at the line that named the label
            as_fail();
        }
        int at = as_fx_pos[f];
        if as_fx_kind[f] == 5 {
            int v = as_laddr[sl] + 0x4000B0;
            as_patch32(at, v & 4294967295);
            as_patch32(at + 4, (v >> 32) & 4294967295);
        } else {
            as_patch32(at, as_fx_base[f] | as_ref_bits(as_fx_kind[f], as_laddr[sl] - at));
        }
        f += 1;
    }
}

int as_find_label() {
    int sl = as_label_slot();
    if as_laddr[sl] < 0 { as_fail(); }
    return as_laddr[sl];
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
        // add xD, xN, xM, lsl #n   (lsl / lsr / asr)
        int shift = 0;
        int amount = 0;
        as_skip_spaces();
        if as_cur() == ',' {
            as_ci += 1;
            as_skip_spaces();
            if as_cur() == 'l' && as_peek(1) == 's' && as_peek(2) == 'l' { shift = 0; }
            else if as_cur() == 'l' && as_peek(1) == 's' && as_peek(2) == 'r' { shift = 1; }
            else if as_cur() == 'a' && as_peek(1) == 's' && as_peek(2) == 'r' { shift = 2; }
            else { as_fail(); }
            as_ci += 3;
            as_skip_spaces();
            if as_cur() == '#' { as_ci += 1; }
            amount = as_parse_number();
            if amount < 0 || amount > 63 { as_fail(); }
        }
        as_put32(base | (shift << 22) | (rm << 16) | (amount << 10) | (rn << 5) | rd);
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
        } else if kind == 4 {
            if imm > 31 { as_fail(); }
            as_put32(0x13800000 | (rn << 16) | (imm << 10) | (rn << 5) | rd);          // ror32 xd, xn, #imm  =  ror wd, wn, #imm (the upper half of xd is 0)
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

// the "bitmask immediate" of and / orr / eor / ands: a run of ones, rotated, repeated in elements of 2 .. 64 bits.
// returns N << 12 | immr << 6 | imms, or -1 when the number cannot be written that way
int as_lsr(int v, int r) {
    if r == 0 { return v; }
    return (v >> r) & ((1 << (64 - r)) - 1);
}

int as_logic_imm(int v) {
    if v == 0 || v == 0 - 1 { return 0 - 1; }
    int size = 64;
    while size > 2 {
        int half = size / 2;
        int hm = (1 << half) - 1;
        if (as_lsr(v, half) & hm) != (v & hm) { break; }
        size = half;
    }
    int emask = 0 - 1;
    if size < 64 { emask = (1 << size) - 1; }
    int e = v & emask;
    int ones = 0;
    int t = 0;
    while t < size {
        if (as_lsr(e, t) & 1) != 0 { ones += 1; }
        t += 1;
    }
    if ones == 0 || ones == size { return 0 - 1; }
    int run = (1 << ones) - 1;
    int r = 0;
    while r < size {
        int rot = run;
        if r > 0 { rot = (as_lsr(run, r) | (run << (size - r))) & emask; }
        if rot == e {
            int n = 0;
            if size == 64 { n = 1; }
            int prefix = ((0 - size) << 1) & 63;
            if size == 64 { prefix = 0; }
            return (n << 12) | (r << 6) | (prefix | (ones - 1));
        }
        r += 1;
    }
    return 0 - 1;
}

// and / orr / eor / ands with three registers, or with a bitmask immediate: and x0, x1, #255
void as_h_logic(int regbase, int immbase) {
    as_skip_spaces();
    int rd = as_parse_reg();
    as_expect_comma();
    int rn = as_parse_reg();
    as_expect_comma();
    as_skip_spaces();
    if as_cur() == 'x' {
        int rm = as_parse_reg();
        // and / orr / eor xD, xN, xM, lsl #n   (lsl / lsr / asr / ror)
        int shift = 0;
        int amount = 0;
        as_skip_spaces();
        if as_cur() == ',' {
            as_ci += 1;
            as_skip_spaces();
            if as_cur() == 'l' && as_peek(1) == 's' && as_peek(2) == 'l' { shift = 0; }
            else if as_cur() == 'l' && as_peek(1) == 's' && as_peek(2) == 'r' { shift = 1; }
            else if as_cur() == 'a' && as_peek(1) == 's' && as_peek(2) == 'r' { shift = 2; }
            else if as_cur() == 'r' && as_peek(1) == 'o' && as_peek(2) == 'r' { shift = 3; }
            else { as_fail(); }
            as_ci += 3;
            as_skip_spaces();
            if as_cur() == '#' { as_ci += 1; }
            amount = as_parse_number();
            if amount < 0 || amount > 63 { as_fail(); }
        }
        as_put32(regbase | (shift << 22) | (rm << 16) | (amount << 10) | (rn << 5) | rd);
        return;
    }
    if as_cur() == '#' { as_ci += 1; }
    int v = as_parse_signed();
    int enc = as_logic_imm(v);
    if enc < 0 { as_fail(); }
    as_put32(immbase | (((enc >> 12) & 1) << 22) | (((enc >> 6) & 63) << 16) | ((enc & 63) << 10) | (rn << 5) | rd);
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

// stp xA, xB, [sp, #-N]!  (pre-index: the prologue)     ldp xA, xB, [sp], #N  (post-index: the epilogue)
// stp xA, xB, [xN, #off]    ldp xA, xB, [xN, #off]  (an offset, no write back: off is a multiple of 8, -512 .. 504)
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
    if as_cur() == ']' {
        as_ci += 1;
        if as_cur() == ',' {
            // post-index:  [xN], #off
            as_ci += 1;
            as_skip_spaces();
            if as_cur() == '#' { as_ci += 1; }
            imm = as_parse_signed();
            if imm < 0 - 512 || imm > 504 || (imm & 7) != 0 { as_fail(); }
            int base = 0xA8C00000;
            if store { base = 0xA8800000; }
            as_put32(base | (((imm >> 3) & 127) << 15) | (rt2 << 10) | (rn << 5) | rt);
            return;
        }
        // [xN]: offset 0
        int base0 = 0xA9400000;
        if store { base0 = 0xA9000000; }
        as_put32(base0 | (rt2 << 10) | (rn << 5) | rt);
        return;
    }
    if as_cur() != ',' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    if as_cur() == '#' { as_ci += 1; }
    imm = as_parse_signed();
    as_skip_spaces();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    if imm < 0 - 512 || imm > 504 || (imm & 7) != 0 { as_fail(); }
    if as_cur() == '!' {
        // pre-index with write back
        as_ci += 1;
        int base1 = 0xA9C00000;
        if store { base1 = 0xA9800000; }
        as_put32(base1 | (((imm >> 3) & 127) << 15) | (rt2 << 10) | (rn << 5) | rt);
        return;
    }
    int base2 = 0xA9400000;
    if store { base2 = 0xA9000000; }
    as_put32(base2 | (((imm >> 3) & 127) << 15) | (rt2 << 10) | (rn << 5) | rt);
}

// ldr/str family: op = the instruction's high 16 bits, shift = log2(size)
void as_h_mem(int op, int shift) {
    as_skip_spaces();
    int rt = 0;
    if as_cur() == 'q' && as_is_digit(as_peek(1)) {
        // ldr qN, [..] / str qN, [..]  (16 bytes, one NEON register)
        as_ci += 1;
        rt = as_parse_number();
        if op == 0xF940 { op = 0x3DC0; }
        else if op == 0xF900 { op = 0x3D80; }
        else { as_fail(); }
        shift = 4;
    } else if as_cur() == 's' && as_is_digit(as_peek(1)) {
        // ldr sN, [..] / str sN, [..]  (a float)
        rt = as_parse_freg();
        if op == 0xF940 { op = 0xBD40; }
        else if op == 0xF900 { op = 0xBD00; }
        else { as_fail(); }
        shift = 2;
    } else if as_cur() == 'd' && as_is_digit(as_peek(1)) {
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
        if as_cur() == 'x' {
            // [xN, xM] or [xN, xM, lsl #k] (k is 0 or the log2 of the size): the address is the base plus the index, shifted
            int rm = as_parse_reg();
            int sflag = 0;
            as_skip_spaces();
            if as_cur() == ',' {
                as_ci += 1;
                as_skip_spaces();
                if as_cur() != 'l' || as_peek(1) != 's' || as_peek(2) != 'l' { as_fail(); }
                as_ci += 3;
                as_skip_spaces();
                if as_cur() != '#' { as_fail(); }
                as_ci += 1;
                int sh = as_parse_number();
                if sh == shift && shift > 0 { sflag = 1; } else if sh != 0 { as_fail(); }
                as_skip_spaces();
            }
            if as_cur() != ']' { as_fail(); }
            as_ci += 1;
            as_put32(((op << 16) & 0xFEFFFFFF) | 0x00200000 | 0x00000800 | (3 << 13) | (sflag << 12) | (rm << 16) | (rn << 5) | rt);
            return;
        }
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
    if is_bl == 1 {
        as_emit_ref(0x94000000, 1);
    } else if cond == 14 {
        as_emit_ref(0x14000000, 1);
    } else {
        as_emit_ref(0x54000000 | cond, 2);
    }
}

// fadd fsub fmul fdiv: dREG, dREG, dREG (or the s forms)
void as_h_fp3(int dbase, int sbase) {
    if as_at_vreg() {
        if dbase == 0x1E602800 { as_h_vec3(0x4E60D400, 0x4E20D400); }
        else if dbase == 0x1E603800 { as_h_vec3(0x4EE0D400, 0x4EA0D400); }
        else if dbase == 0x1E600800 { as_h_vec3(0x6E60DC00, 0x6E20DC00); }
        else { as_h_vec3(0x6E60FC00, 0x6E20FC00); }
        return;
    }
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

// fmadd fmsub fnmadd fnmsub dD, dN, dM, dA (doubles)
void as_h_fp4(int base) {
    as_skip_spaces();
    int rd = as_parse_freg();
    if as_fp_kind != 1 { as_fail(); }
    as_expect_comma();
    int rn = as_parse_freg();
    as_expect_comma();
    int rm = as_parse_freg();
    as_expect_comma();
    int ra = as_parse_freg();
    as_put32(base | (rm << 16) | (ra << 10) | (rn << 5) | rd);
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
        } else if kind == 0 && as_at_freg() {
            int rf2 = as_parse_freg();                 // fmov sN, sM
            if as_fp_kind != 0 { as_fail(); }
            as_put32(0x1E204000 | (rf2 << 5) | rd);
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
    as_emit_ref(0x10000000 | rd, 4);
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
    as_emit_ref(base | rt, 2);
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
    as_emit_ref(base | ((bit >> 5) << 31) | ((bit & 31) << 19) | rt, 3);
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

// crc32b / crc32h / crc32w / crc32x and crc32cb ... wd, wn, xm|wm  (the CRC32 extension of ARMv8.1; the last operand is x for crc32x only)
void as_h_crc() {
    int k = 5;                                  // after "crc32"
    int c = 0;
    if as_mn[k] == 'c' { c = 1; k += 1; }
    int sz = 0;
    if as_mn[k] == 'h' { sz = 1; }
    else if as_mn[k] == 'w' { sz = 2; }
    else if as_mn[k] == 'x' { sz = 3; }
    else if as_mn[k] != 'b' { as_fail(); }
    int base = 0x1AC04000 + sz * 1024 + c * 4096;
    if sz == 3 { base += 0x80000000; }
    as_skip_spaces();
    int rd = as_parse_wreg();
    as_expect_comma();
    int rn = as_parse_wreg();
    as_expect_comma();
    int rm = 0;
    if sz == 3 { rm = as_parse_reg(); } else { rm = as_parse_wreg(); }
    as_put32(base | (rm << 16) | (rn << 5) | rd);
}

// prfm pldl1keep, [xn]   (also pldl1strm, pldl2keep, pldl3keep, pstl1keep): a hint that the line at the address is wanted soon
void as_h_prfm() {
    as_skip_spaces();
    as_read_label_name();
    int op = 0;
    if as_seq(@as_nbuf, "pldl1keep") { op = 0; }
    else if as_seq(@as_nbuf, "pldl1strm") { op = 1; }
    else if as_seq(@as_nbuf, "pldl2keep") { op = 2; }
    else if as_seq(@as_nbuf, "pldl3keep") { op = 4; }
    else if as_seq(@as_nbuf, "pstl1keep") { op = 16; }
    else { as_fail(); }
    as_expect_comma();
    if as_cur() != '[' { as_fail(); }
    as_ci += 1;
    as_skip_spaces();
    int rn = as_parse_reg_or_sp();
    as_skip_spaces();
    if as_cur() != ']' { as_fail(); }
    as_ci += 1;
    as_put32(0xF9800000 | (rn << 5) | op);
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
    if as_mn[0] == 'c' && as_mn[1] == 'r' && as_mn[2] == 'c' { as_h_crc(); return true; }
    if as_mn_is("prfm") { as_h_prfm(); return true; }
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
                int qsl = as_label_slot();
                if as_laddr[qsl] >= 0 {
                    lo = as_laddr[qsl] + 0x4000B0;
                } else {
                    // not defined yet: two words that are filled at the end
                    if as_fx_n >= 131072 { as_fail(); }
                    as_fx_pos[as_fx_n] = as_pos;
                    as_fx_kind[as_fx_n] = 5;
                    as_fx_slot[as_fx_n] = qsl;
                    as_fx_base[as_fx_n] = 0;
                    as_fx_ci[as_fx_n] = as_ci;
                    as_fx_n += 1;
                }
            }
            as_put32(lo & 4294967295);
            as_put32((lo >> 32) & 4294967295);
            return;
        }
        if as_mn_is("word") {
            // one 32-bit word (raw<u32>[...] of the language): a number
            as_skip_spaces();
            int wv = as_parse_number();
            as_put32(wv & 4294967295);
            return;
        }
        if as_mn_is("align") {
            // pad with nops until the address (where the program is loaded: 0x4000B0 + as_pos) is a multiple of N bytes
            as_skip_spaces();
            int an = as_parse_number();
            if an < 4 || an > 4096 { as_fail(); }
            while (as_pos + as_base()) % an != 0 { as_put32(0xD503201F); }
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
        if as_mn_is("init") {
            as_skip_spaces();
            as_read_label_name();
            as_init_slot = as_label_slot();
            as_has_init = 1;
            return;
        }
        if as_mn_is("export") {
            // .export NAME LABEL : the library gives the address of LABEL to others under the name NAME
            as_skip_spaces();
            as_read_label_name();
            if as_xn_n >= 64 { as_fail(); }
            int xi = 0;
            while xi < 64 {
                as_xn_name[as_xn_n * 64 + xi] = as_nbuf[xi];
                xi += 1;
            }
            as_skip_spaces();
            as_read_label_name();
            as_xn_slot[as_xn_n] = as_label_slot();
            as_xn_n += 1;
            return;
        }
        if !as_mn_is("bss") { as_fail(); }
        as_skip_spaces();
        as_bss_size = as_parse_number();
        return;
    }
    as_read_mnemonic();
    if as_mn_is("mov") { if as_at_vreg() { as_h_vmov(); return; } as_h_mov(); return; }
    if as_mn_is("add") { if as_at_vreg() { as_h_vec3b(0x4EE08400, 0x4EA08400, 0x4E208400); return; } as_h_addsub(true); return; }
    if as_mn_is("sub") { if as_at_vreg() { as_h_vec3b(0x6EE08400, 0x6EA08400, 0x6E208400); return; } as_h_addsub(false); return; }
    if as_mn_is("cmp") { as_h_cmp(); return; }
    if as_mn_is("dup") { as_h_dup(); return; }
    if as_mn_is("umov") { as_h_umov(false); return; }
    if as_mn_is("smov") { as_h_umov(true); return; }
    if as_mn_is("ins") { as_h_ins(); return; }
    if as_mn_is("mul") { if as_at_vreg() { as_h_vec3b(0, 0x4EA09C00, 0x4E209C00); return; } as_h_rrr(0x9B007C00); return; }
    if as_mn_is("udiv") { as_h_rrr(0x9AC00800); return; }
    if as_mn_is("sdiv") { as_h_rrr(0x9AC00C00); return; }
    if as_mn_is("sdotz") {
        // the pseudo instruction of the IR: vD.4s = the dot products of the bytes of vN.16b and vM.16b: movi v31.4s, #0; sdot v31.4s, vN.16b, vM.16b; mov vD.16b, v31.16b
        as_skip_spaces();
        int zrd = as_parse_vreg();
        as_expect_comma();
        int zrn = as_parse_vreg();
        as_expect_comma();
        int zrm = as_parse_vreg();
        as_put32(0x4F00041F);
        as_put32(0x4E80941F | (zrm << 16) | (zrn << 5));
        as_put32(0x4EBF1FE0 | zrd);
        return;
    }
    if as_mn_is("ushl") { as_h_vec3b(0x6EE04400, 0x6EA04400, 0x6E204400); return; }
    // the bitwise vector instructions work on the 128 bits: every arrangement gives the same code
    if as_mn_is("and") { if as_at_vreg() { as_h_vec3b(0x4E201C00, 0x4E201C00, 0x4E201C00); return; } as_h_logic(0x8A000000, 0x92000000); return; }
    if as_mn_is("orr") { if as_at_vreg() { as_h_vec3b(0x4EA01C00, 0x4EA01C00, 0x4EA01C00); return; } as_h_logic(0xAA000000, 0xB2000000); return; }
    if as_mn_is("eor") { if as_at_vreg() { as_h_vec3b(0x6E201C00, 0x6E201C00, 0x6E201C00); return; } as_h_logic(0xCA000000, 0xD2000000); return; }
    if as_mn_is("lsl") { as_h_shift(0x9AC02000, 0); return; }
    if as_mn_is("lsr") { as_h_shift(0x9AC02400, 1); return; }
    if as_mn_is("asr") { as_h_shift(0x9AC02800, 2); return; }
    if as_mn_is("msub") { as_h_rrrr(0x9B008000); return; }
    if as_mn_is("madd") { as_h_rrrr(0x9B000000); return; }
    if as_mn_is("smulh") { as_h_rrr(0x9B407C00); return; }
    if as_mn_is("ror") { as_h_shift(0x9AC02C00, 3); return; }
    if as_mn_is("ror32") { as_h_shift(0x1AC02C00, 4); return; }
    if as_mn_is("neg") { as_h_neg(); return; }
    if as_mn_is("clz") { as_h_sxt(0xDAC0, 0x1000); return; }
    if as_mn_is("rbit") { as_h_sxt(0xDAC0, 0x0000); return; }
    if as_mn_is("rev") { as_h_sxt(0xDAC0, 0x0C00); return; }
    if as_mn_is("cls") { as_h_sxt(0xDAC0, 0x1400); return; }
    if as_mn_is("rev16") { as_h_sxt(0xDAC0, 0x0400); return; }
    if as_mn_is("rev32") { as_h_sxt(0xDAC0, 0x0800); return; }
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
    if as_mn_is("fmadd") { as_h_fp4(0x1F400000); return; }
    if as_mn_is("fmsub") { as_h_fp4(0x1F408000); return; }
    if as_mn_is("fnmadd") { as_h_fp4(0x1F600000); return; }
    if as_mn_is("fnmsub") { as_h_fp4(0x1F608000); return; }
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
                as_add_label();
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


// ------------------------------------------------- a shared library (-l)

void as_so_put(char^ buf, int at, int bytes, int v) {
    int i = 0;
    while i < bytes {
        buf[at + i] = (v >> (8 * i)) & 255;
        i += 1;
    }
}

// the layout after the code: .dynsym, .dynstr, .hash, .dynamic (one read-only part with the code), then the page of the global area
void as_lib_layout() {
    int n = as_xn_n;
    as_so_m0 = (as_h() + as_pos + 7) & ~7;
    int i = 0;
    while i < 65536 { as_so_meta[i] = 0; i += 1; }
    int symoff = 0;
    int stroff = 24 * (n + 1);
    int sp = stroff + 1;                    // the first byte of the string table is 0
    int k = 0;
    while k < n {
        int sl = as_xn_slot[k];
        if as_laddr[sl] < 0 { as_fail(); }
        int so = symoff + 24 * (k + 1);
        as_so_put(@as_so_meta, so, 4, sp - stroff);                  // st_name
        as_so_meta[so + 4] = 0x12;                                    // GLOBAL, FUNC
        as_so_put(@as_so_meta, so + 6, 2, 1);                         // st_shndx: not undefined
        as_so_put(@as_so_meta, so + 8, 8, as_h() + as_laddr[sl]);        // st_value
        int j = 0;
        while as_xn_name[k * 64 + j] != 0 && j < 63 {
            as_so_meta[sp] = as_xn_name[k * 64 + j];
            sp += 1;
            j += 1;
        }
        as_so_meta[sp] = 0;
        sp += 1;
        k += 1;
    }
    int needed1 = 0;
    int needed2 = 0;
    int interp_at = 0;
    if as_dyn == 1 {                                                   // the names the loader needs: two libraries and the loader of the system
        needed1 = sp - stroff;
        char^ n1 = "libdl.so";
        int q = 0;
        while n1[q] != 0 { as_so_meta[sp] = n1[q]; sp += 1; q += 1; }
        as_so_meta[sp] = 0; sp += 1;
        needed2 = sp - stroff;
        char^ n2 = "libc.so";
        q = 0;
        while n2[q] != 0 { as_so_meta[sp] = n2[q]; sp += 1; q += 1; }
        as_so_meta[sp] = 0; sp += 1;
        interp_at = sp;                                                // (not part of the string table, but kept in the same block)
        char^ n3 = "/system/bin/linker64";
        q = 0;
        while n3[q] != 0 { as_so_meta[sp] = n3[q]; sp += 1; q += 1; }
        as_so_meta[sp] = 0; sp += 1;
    }
    int strsize = sp - stroff;
    int hashoff = (sp + 3) & ~3;
    as_so_put(@as_so_meta, hashoff, 4, 1);                            // nbucket
    as_so_put(@as_so_meta, hashoff + 4, 4, n + 1);                    // nchain
    int first = 0;
    if n > 0 { first = 1; }
    as_so_put(@as_so_meta, hashoff + 8, 4, first);                    // bucket[0]
    k = 1;
    while k < n {
        as_so_put(@as_so_meta, hashoff + 12 + 4 * k, 4, k + 1);       // chain[k] = the next symbol, the last one 0
        k += 1;
    }
    int dynoff = (hashoff + 12 + 4 * (n + 1) + 7) & ~7;
    int mbase = as_so_m0;
    int dynlen = 96;
    int dynextra = 0;
    if as_dyn == 1 { dynextra = 48; }
    if as_has_init == 1 {
        if as_laddr[as_init_slot] < 0 { as_fail(); }
        as_so_put(@as_so_meta, dynoff + 80, 8, 12);                     // DT_INIT: the loader calls it (the address is moved by the load address)
        as_so_put(@as_so_meta, dynoff + 88, 8, as_h() + as_laddr[as_init_slot]);
        dynlen = 112;
    }
    as_so_put(@as_so_meta, dynoff, 8, 4);                  as_so_put(@as_so_meta, dynoff + 8, 8, mbase + hashoff);       // DT_HASH
    as_so_put(@as_so_meta, dynoff + 16, 8, 5);             as_so_put(@as_so_meta, dynoff + 24, 8, mbase + stroff);       // DT_STRTAB
    as_so_put(@as_so_meta, dynoff + 32, 8, 6);             as_so_put(@as_so_meta, dynoff + 40, 8, mbase + symoff);       // DT_SYMTAB
    as_so_put(@as_so_meta, dynoff + 48, 8, 10);            as_so_put(@as_so_meta, dynoff + 56, 8, strsize);              // DT_STRSZ
    as_so_put(@as_so_meta, dynoff + 64, 8, 11);            as_so_put(@as_so_meta, dynoff + 72, 8, 24);                   // DT_SYMENT
    if as_dyn == 1 {                                                    // DT_NEEDED libdl.so, libc.so (after the optional DT_INIT entry), then the end
        int ne = dynoff + 80;
        if as_has_init == 1 { ne = dynoff + 96; }
        as_so_put(@as_so_meta, ne, 8, 1);        as_so_put(@as_so_meta, ne + 8, 8, needed1);
        as_so_put(@as_so_meta, ne + 16, 8, 1);   as_so_put(@as_so_meta, ne + 24, 8, needed2);
        dynlen = dynlen + dynextra;
    }
    // two sections only, because the loader of Android wants a section table with a name table: the empty one, and the names (.dynstr)
    int shoff = dynoff + dynlen;
    as_so_put(@as_so_meta, shoff + 64 + 4, 4, 3);                      // sh_type = SHT_STRTAB
    as_so_put(@as_so_meta, shoff + 64 + 24, 8, as_so_m0 + stroff);     // sh_offset
    as_so_put(@as_so_meta, shoff + 64 + 32, 8, strsize);               // sh_size
    as_so_put(@as_so_meta, shoff + 64 + 48, 8, 1);                     // sh_addralign
    as_so_put(@as_so_meta, shoff + 128 + 4, 4, 6);                    // section 2: the dynamic section (SHT_DYNAMIC); the loader looks for it
    as_so_put(@as_so_meta, shoff + 128 + 8, 8, 2);                     // sh_flags = ALLOC
    as_so_put(@as_so_meta, shoff + 128 + 16, 8, as_so_m0 + dynoff);    // sh_addr
    as_so_put(@as_so_meta, shoff + 128 + 24, 8, as_so_m0 + dynoff);    // sh_offset
    as_so_put(@as_so_meta, shoff + 128 + 32, 8, dynlen);               // sh_size
    as_so_put(@as_so_meta, shoff + 128 + 40, 4, 1);                    // sh_link = the string table
    as_so_put(@as_so_meta, shoff + 128 + 48, 8, 8);                    // sh_addralign
    as_so_put(@as_so_meta, shoff + 128 + 56, 8, 16);                   // sh_entsize
    as_so_metalen = shoff + 192;
    int metaend = as_so_m0 + as_so_metalen;
    as_so_v = (metaend + 4095) & ~4095;
    // the program headers
    i = 0;
    while i < 344 { as_so_hdr[i] = 0; i += 1; }
    as_so_hdr[0] = 0x7f; as_so_hdr[1] = 0x45; as_so_hdr[2] = 0x4c; as_so_hdr[3] = 0x46;
    as_so_hdr[4] = 2; as_so_hdr[5] = 1; as_so_hdr[6] = 1;
    as_so_put(@as_so_hdr, 16, 2, 3);                  // ET_DYN
    as_so_put(@as_so_hdr, 18, 2, 0xb7);               // AArch64
    as_so_put(@as_so_hdr, 20, 4, 1);
    as_so_put(@as_so_hdr, 32, 8, 64);                 // e_phoff
    as_so_put(@as_so_hdr, 52, 2, 64);
    as_so_put(@as_so_hdr, 54, 2, 56);
    if as_dyn == 1 { as_so_put(@as_so_hdr, 56, 2, 5); } else { as_so_put(@as_so_hdr, 56, 2, 4); }       // four program headers (a dynamic executable: five)
    as_so_put(@as_so_hdr, 40, 8, as_so_m0 + shoff);  // e_shoff
    as_so_put(@as_so_hdr, 58, 2, 64);                 // e_shentsize
    as_so_put(@as_so_hdr, 60, 2, 3);                  // e_shnum
    as_so_put(@as_so_hdr, 62, 2, 1);                  // e_shstrndx
    as_so_put(@as_so_hdr, 64, 4, 1);                  // 1: PT_LOAD, R+X: the headers, the code, the tables
    as_so_put(@as_so_hdr, 68, 4, 5);
    as_so_put(@as_so_hdr, 96, 8, metaend);
    as_so_put(@as_so_hdr, 104, 8, metaend);
    as_so_put(@as_so_hdr, 112, 8, 4096);
    as_so_put(@as_so_hdr, 120, 4, 1);                 // 2: PT_LOAD, R+W: the global area (.bss), nothing in the file
    as_so_put(@as_so_hdr, 124, 4, 6);
    as_so_put(@as_so_hdr, 128, 8, as_so_v);
    as_so_put(@as_so_hdr, 136, 8, as_so_v);
    as_so_put(@as_so_hdr, 144, 8, as_so_v);
    int mem = (as_bss_size + 4095) & ~4095;
    if mem < 4096 { mem = 4096; }
    as_so_put(@as_so_hdr, 160, 8, mem);
    if as_dyn == 1 { as_so_put(@as_so_hdr, 152, 8, 4088); }          // the kernel needs the file data of the writable part to end inside a page (not on a page boundary) when it starts the program itself
    as_so_put(@as_so_hdr, 168, 8, 4096);
    as_so_put(@as_so_hdr, 176, 4, 2);                 // 3: PT_DYNAMIC
    as_so_put(@as_so_hdr, 180, 4, 4);
    as_so_put(@as_so_hdr, 184, 8, as_so_m0 + dynoff);
    as_so_put(@as_so_hdr, 192, 8, as_so_m0 + dynoff);
    as_so_put(@as_so_hdr, 200, 8, as_so_m0 + dynoff);
    as_so_put(@as_so_hdr, 208, 8, dynlen);
    as_so_put(@as_so_hdr, 216, 8, dynlen);
    as_so_put(@as_so_hdr, 224, 8, 8);
    if as_dyn == 1 {
        as_so_put(@as_so_hdr, 232, 4, 3);              // 4: PT_INTERP, the loader of the system
        as_so_put(@as_so_hdr, 236, 4, 4);
        as_so_put(@as_so_hdr, 240, 8, as_so_m0 + stroff + interp_at - stroff);
        as_so_put(@as_so_hdr, 248, 8, as_so_m0 + stroff + interp_at - stroff);
        as_so_put(@as_so_hdr, 256, 8, as_so_m0 + stroff + interp_at - stroff);
        as_so_put(@as_so_hdr, 264, 8, 21);
        as_so_put(@as_so_hdr, 272, 8, 21);
        as_so_put(@as_so_hdr, 280, 8, 1);
        as_so_put(@as_so_hdr, 288, 4, 6);              // 5: PT_PHDR (the loader of Android looks for it)
        as_so_put(@as_so_hdr, 292, 4, 4);
        as_so_put(@as_so_hdr, 296, 8, 64);
        as_so_put(@as_so_hdr, 304, 8, 64);
        as_so_put(@as_so_hdr, 312, 8, 64);
        as_so_put(@as_so_hdr, 320, 8, 280);
        as_so_put(@as_so_hdr, 328, 8, 280);
        as_so_put(@as_so_hdr, 336, 8, 8);
        int mv = 343;                                  // PT_PHDR must come before the PT_LOADs: the first four headers move up by one entry, PT_PHDR goes first
        char ph[56];
        int pk = 0;
        while pk < 56 { ph[pk] = as_so_hdr[288 + pk]; pk += 1; }
        mv = 287;
        while mv >= 64 { as_so_hdr[mv + 56] = as_so_hdr[mv]; mv -= 1; }
        pk = 0;
        while pk < 56 { as_so_hdr[64 + pk] = ph[pk]; pk += 1; }
        as_so_put(@as_so_hdr, 24, 8, as_h());             // e_entry: the first instruction of the code (it jumps to the start of the program)
    } else {
        as_so_put(@as_so_hdr, 232, 4, 0x6474e551);        // 4: PT_GNU_STACK, not executable
        as_so_put(@as_so_hdr, 236, 4, 6);
        as_so_put(@as_so_hdr, 280, 8, 16);
    }
    // the label of the global area: the code reaches it with adr (the distance must be less than 1 MB)
    as_nbuf[0] = 'j'; as_nbuf[1] = '2'; as_nbuf[2] = 'k'; as_nbuf[3] = '_'; as_nbuf[4] = 'g'; as_nbuf[5] = 'l'; as_nbuf[6] = 0;
    i = 7;
    while i < 64 { as_nbuf[i] = 0; i += 1; }
    int gl = as_label_slot();
    as_laddr[gl] = as_so_v - as_h();
    if as_so_v - as_h() - as_pos > 900000 || as_pos > 900000 { as_fail(); }
}

// write the library: the headers, the code, the tables, and zeros up to the page of the global area
void as_write_so(char^ path) {
    int out = syscall(56, -100, path, 577, 493);
    if out < 0 {
        char e1[48] = "cannot write the library file '";
        syscall(64, 2, @e1, 31);
        int pn = 0;
        while path[pn] != 0 { pn += 1; }
        syscall(64, 2, path, pn);
        char e2[96] = "' (a folder with that name, or no permission?)\n";
        syscall(64, 2, @e2, 48);
        syscall(93, 1);
    }
    syscall(64, out, @as_so_hdr, as_h());
    syscall(64, out, @as_code, as_pos);
    syscall(64, out, @as_so_zero, as_so_m0 - (as_h() + as_pos));
    syscall(64, out, @as_so_meta, as_so_metalen);
    int rest = as_so_v - (as_so_m0 + as_so_metalen);
    while rest > 0 {
        int chunk = rest;
        if chunk > 4096 { chunk = 4096; }
        syscall(64, out, @as_so_zero, chunk);
        rest -= chunk;
    }
    if as_dyn == 1 { syscall(64, out, @as_so_zero, 4096); }
    syscall(57, out);
}

// ------------------------------------------------- the library entry points

// as_src[0 .. len) holds the .jasm text: assemble it (exits with a message on error)
void as_assemble(int len) {
    as_src_len = len;
    as_pass = 2;
    as_label_count = 0;
    as_fx_n = 0;
    int z = 0;
    while z < 65536 {
        as_lhash[z] = 0;
        z += 1;
    }
    as_xn_n = 0;
    as_has_init = 0;
    as_run_pass();
    if as_lib == 1 { as_lib_layout(); }
    as_resolve();
    if as_lib == 0 { as_build_header(); }
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
