// jc_low.j -- the low level of the language: functions without a frame (naked), written with register statements.
//
//   naked int sys_write(int fd, char^ buf, int n) {       // no prologue, no epilogue, no saves: the body is all there is
//       Reg::x8 = 64;                                      // one statement is one instruction
//       svc(0);
//       ret;
//   }
//
// Statements (inside a naked function, and later inside register { } blocks; design: docs/syntax-design.md 63, docs/design/08):
//   R = number;   R = R2;   R = R2 op R3;   R = R2 op number;   R op= R2;   R op= number;   R = ~R2;   R = -R2;     op: + - * / & | xor << >> >>>
//   R = [B + off];  R = u8[B + off];  u16 u32 i8 i16 i32    [B + off] = R;  u8[B + off] = R;  u16 u32     (off: a number, or + R2)
//   R = Sys::name;   Sys::name = R;     (mrs / msr)      ret;   goto label;   label:   call name;   tail name;   svc(n);
//   if R == R2 goto label;   if R < number goto label;  (== != < <= > >=)   if R.bit(n) goto label;   if !R.bit(n) goto label;
//   Cpu::wait();  Cpu::event();  Cpu::send_event();  Cpu::yield();  Cpu::nop();  Cpu::isb();  Cpu::dsb();  Cpu::dmb();  Cpu::eret();  Cpu::brk(n);
//   Cpu::inst("name", a, b ...) : any instruction of the assembler, with registers and numbers as operands
// R is  Reg::x0 .. Reg::x30, Reg::sp, Reg::lr, Reg::fp, Reg::zero, the roles Reg::arg0 .. Reg::arg7, Reg::ret; inside a naked function the
// bare names x0 .. x30, sp, lr, fp are allowed too.
// A number that does not fit the instruction is put in x17 first (x17 is the scratch register of the assembler).
// Every instruction is written after a line ";N": the text passes (peephole, register pass) do not change a naked function, the last pass
// takes the marker lines away.

int fn_naked;                    // 1 while the function being parsed is naked
int fn_noreturn;
char nk_lname[2048];             // the labels of the function: 32 names of 64 characters
int nk_lnum[32];
int nk_ldef[32];
int nk_ln;
char nk_line[256];
int nk_sp;                       // 1 if the last register read was sp
int nk_pins_n;

void nk_reset() {
    nk_ln = 0;
}

// the number of a label (made when it is first seen), and whether it was defined
int nk_label(char^ name, bool define) {
    int i = 0;
    while i < nk_ln {
        if str_eq(@nk_lname + i * 64, name) {
            if define {
                if nk_ldef[i] == 1 { die_name("this label is defined twice in the function", name); }
                nk_ldef[i] = 1;
            }
            return nk_lnum[i];
        }
        i += 1;
    }
    if nk_ln >= 32 { die("too many labels in a naked function (32 at most)"); }
    str_copy(@nk_lname + nk_ln * 64, name, 64);
    nk_lnum[nk_ln] = new_label();
    nk_ldef[nk_ln] = 0;
    if define { nk_ldef[nk_ln] = 1; }
    nk_ln += 1;
    return nk_lnum[nk_ln - 1];
}

// at the end of the function: every label that was used is defined
void nk_check_labels() {
    int i = 0;
    while i < nk_ln {
        if nk_ldef[i] == 0 { die_name("this label is used but never defined", @nk_lname + i * 64); }
        i += 1;
    }
}

void nk_emit(char^ s) {
    emit_line(";N");
    emit_line(s);
}

void nk_add_reg(char^ dst, int r) {
    if r == 31 {
        append_text(dst, "sp");
        return;
    }
    append_text(dst, "x");
    append_int(dst, r);
}

// the number in a register name  x0 .. x30, or -1
int nk_xnum(char^ t) {
    if t[0] != 'x' || t[1] < '0' || t[1] > '9' { return 0 - 1; }
    int v = 0;
    int i = 1;
    while t[i] >= '0' && t[i] <= '9' {
        v = v * 10 + (t[i] - '0');
        i += 1;
    }
    if t[i] != 0 || v > 30 { return 0 - 1; }
    return v;
}

// a register name (without Reg::): its number, 31 for sp, 32 for the zero register, or -1
int nk_regname(char^ t, bool bare) {
    int x = nk_xnum(t);
    if x >= 0 { return x; }
    if str_eq(t, "sp") { return 31; }
    if str_eq(t, "lr") { return 30; }
    if str_eq(t, "fp") { return 29; }
    if str_eq(t, "zero") { return 32; }
    if bare { return 0 - 1; }
    if str_eq(t, "ret") { return 0; }
    if t[0] == 'a' && t[1] == 'r' && t[2] == 'g' && t[3] >= '0' && t[3] <= '7' && t[4] == 0 { return t[3] - '0'; }
    return 0 - 1;
}

// is the current token the start of a register?  (does not read it)
bool nk_at_reg() {
    if tok_kind != T_IDENT { return false; }
    if str_eq(@tok_text, "Reg") { return true; }
    return nk_regname(@tok_text, true) >= 0;
}

// read a register: Reg::name or a bare name; returns 0..30, 31 (sp), 32 (zero)
int nk_reg() {
    if tok_kind != T_IDENT { die("a register was expected (Reg::x0, x0, sp ...)"); }
    int r = 0 - 1;
    if str_eq(@tok_text, "Reg") {
        next();
        expect("::");
        if tok_kind != T_IDENT { die("a register name was expected after Reg::"); }
        r = nk_regname(@tok_text, false);
        if r < 0 { die_name("this is not a register (x0 .. x30, sp, lr, fp, zero, arg0 .. arg7, ret)", @tok_text); }
    } else {
        r = nk_regname(@tok_text, true);
        if r < 0 { die_name("a register was expected, this is not one", @tok_text); }
    }
    next();
    return r;
}

// a number, with an optional minus sign
bool nk_at_num() {
    if tok_kind == T_NUM { return true; }
    return tok_is("-");
}

int nk_num() {
    int neg = 0;
    if tok_is("-") {
        neg = 1;
        next();
    }
    if tok_kind != T_NUM { die("a number was expected"); }
    int v = tok_num;
    next();
    if neg == 1 { v = 0 - v; }
    return v;
}

// the text of a number for an instruction line
void nk_add_num(char^ dst, int v) {
    if v < 0 {
        append_text(dst, "-");
        if v == 0 - 9223372036854775807 - 1 {
            append_text(dst, "9223372036854775808");
            return;
        }
        append_int(dst, 0 - v);
        return;
    }
    append_int(dst, v);
}

// "mn xA, xB, xC"
void nk_rrr(char^ mn, int a, int b, int c) {
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    nk_add_reg(@nk_line, a);
    append_text(@nk_line, ", ");
    nk_add_reg(@nk_line, b);
    append_text(@nk_line, ", ");
    nk_add_reg(@nk_line, c);
    nk_emit(@nk_line);
}

// "mn xA, xB, #n"  (the number is written without #)
void nk_rrn(char^ mn, int a, int b, int n) {
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    nk_add_reg(@nk_line, a);
    append_text(@nk_line, ", ");
    nk_add_reg(@nk_line, b);
    append_text(@nk_line, ", #");
    nk_add_num(@nk_line, n);
    nk_emit(@nk_line);
}

void nk_rn(char^ mn, int a, int n) {
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    nk_add_reg(@nk_line, a);
    append_text(@nk_line, ", #");
    nk_add_num(@nk_line, n);
    nk_emit(@nk_line);
}

void nk_rr(char^ mn, int a, int b) {
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    nk_add_reg(@nk_line, a);
    append_text(@nk_line, ", ");
    nk_add_reg(@nk_line, b);
    nk_emit(@nk_line);
}

// x17 = n
void nk_scratch(int n) {
    nk_rn("mov", 17, n);
}

// the register form of an operation  d = a op b
// kind 1: add/sub-like (immediate 0..4095)   2: shifts (0..63)   3: only registers (the number goes to x17)
void nk_binop(char^ op, int d, int a, bool bnum, int b) {
    char^ mn = null;
    int kind = 3;
    if str_eq(op, "+") { mn = "add"; kind = 1; }
    else if str_eq(op, "-") { mn = "sub"; kind = 1; }
    else if str_eq(op, "*") { mn = "mul"; }
    else if str_eq(op, "/") { mn = "sdiv"; }
    else if str_eq(op, "&") { mn = "and"; }
    else if str_eq(op, "|") { mn = "orr"; }
    else if str_eq(op, "xor") { mn = "eor"; }
    else if str_eq(op, "<<") { mn = "lsl"; kind = 2; }
    else if str_eq(op, ">>") { mn = "asr"; kind = 2; }
    else if str_eq(op, ">>>") { mn = "lsr"; kind = 2; }
    else { die_name("this operator is not an instruction (use + - * / & | xor << >> >>>)", op); }
    if !bnum {
        nk_rrr(mn, d, a, b);
        return;
    }
    if kind == 1 && b >= 0 && b <= 4095 {
        nk_rrn(mn, d, a, b);
        return;
    }
    if kind == 1 && b < 0 && b >= 0 - 4095 {
        // add with a negative number is a sub
        if str_eq(op, "+") { nk_rrn("sub", d, a, 0 - b); } else { nk_rrn("add", d, a, 0 - b); }
        return;
    }
    if kind == 2 {
        if b < 0 || b > 63 { die("a shift is 0 .. 63 places"); }
        nk_rrn(mn, d, a, b);
        return;
    }
    nk_scratch(b);
    nk_rrr(mn, d, a, 17);
}

// [base + off] after the opening bracket was read: the address as "base" and a number that fits the access (size: 1, 2, 4, 8)
// returns the base register to use (maybe 17) and sets nk_off
int nk_off;
int nk_addr(int size) {
    int base = nk_reg();
    int off = 0;
    bool regoff = false;
    int roff = 0;
    if tok_is("+") || tok_is("-") {
        bool minus = tok_is("-");
        next();
        if nk_at_reg() {
            if minus { die("a register offset cannot be subtracted: put the address in a register first"); }
            roff = nk_reg();
            regoff = true;
        } else {
            if tok_kind != T_NUM { die("a number or a register was expected after + in an address"); }
            off = tok_num;
            next();
            if minus { off = 0 - off; }
        }
    }
    expect("]");
    if regoff {
        nk_rrr("add", 17, base, roff);
        nk_off = 0;
        return 17;
    }
    if off >= 0 && off % size == 0 && off <= 4095 * size {
        nk_off = off;
        return base;
    }
    // a number that does not fit: the address is made in x17
    if off >= 0 {
        if off <= 4095 { nk_rrn("add", 17, base, off); } else { nk_scratch(off); nk_rrr("add", 17, base, 17); }
    } else {
        if off >= 0 - 4095 { nk_rrn("sub", 17, base, 0 - off); } else { nk_scratch(0 - off); nk_rrr("sub", 17, base, 17); }
    }
    nk_off = 0;
    return 17;
}

void nk_mem(char^ mn, int rt, int base, int off) {
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    nk_add_reg(@nk_line, rt);
    append_text(@nk_line, ", [");
    nk_add_reg(@nk_line, base);
    if off != 0 {
        append_text(@nk_line, ", #");
        nk_add_num(@nk_line, off);
    }
    append_text(@nk_line, "]");
    nk_emit(@nk_line);
}

// the access prefix at the current token: u8 u16 u32 i8 i16 i32, or "[" (64 bits). Sets nk_msize and nk_mkind (0 plain 64 bit, 1 u8, 2 u16, 3 u32, 4 i8, 5 i16, 6 i32).
int nk_msize;
int nk_mkind;
bool nk_at_mem() {
    if tok_is("[") { return true; }
    if tok_kind != T_IDENT { return false; }
    return str_eq(@tok_text, "u8") || str_eq(@tok_text, "u16") || str_eq(@tok_text, "u32") || str_eq(@tok_text, "i8") || str_eq(@tok_text, "i16") || str_eq(@tok_text, "i32");
}

void nk_read_mem_prefix() {
    nk_mkind = 0;
    nk_msize = 8;
    if tok_kind == T_IDENT {
        if str_eq(@tok_text, "u8") { nk_mkind = 1; nk_msize = 1; }
        else if str_eq(@tok_text, "u16") { nk_mkind = 2; nk_msize = 2; }
        else if str_eq(@tok_text, "u32") { nk_mkind = 3; nk_msize = 4; }
        else if str_eq(@tok_text, "i8") { nk_mkind = 4; nk_msize = 1; }
        else if str_eq(@tok_text, "i16") { nk_mkind = 5; nk_msize = 2; }
        else if str_eq(@tok_text, "i32") { nk_mkind = 6; nk_msize = 4; }
        next();
    }
    expect("[");
}

void nk_load(int rd) {
    nk_read_mem_prefix();
    int base = nk_addr(nk_msize);
    char^ mn = "ldr";
    if nk_mkind == 1 { mn = "ldrb"; }
    else if nk_mkind == 2 { mn = "ldrh"; }
    else if nk_mkind == 3 { mn = "ldrw"; }
    else if nk_mkind == 4 { mn = "ldrsb"; }
    else if nk_mkind == 5 { mn = "ldrsh"; }
    else if nk_mkind == 6 { mn = "ldrsw"; }
    nk_mem(mn, rd, base, nk_off);
}

// condition text for b.cc
char^ nk_cc(char^ op) {
    if str_eq(op, "==") { return "eq"; }
    if str_eq(op, "!=") { return "ne"; }
    if str_eq(op, "<") { return "lt"; }
    if str_eq(op, "<=") { return "le"; }
    if str_eq(op, ">") { return "gt"; }
    if str_eq(op, ">=") { return "ge"; }
    die_name("a comparison was expected (== != < <= > >=)", op);
    return "eq";
}

// the system register name:  Sys::name
void nk_sys_name(char^ dst) {
    expect("Sys");
    expect("::");
    if tok_kind != T_IDENT { die("a system register name was expected after Sys::"); }
    int i = 0;
    while tok_text[i] != 0 {
        char c = tok_text[i];
        if c >= 'A' && c <= 'Z' { c = c + 32; }
        dst[i] = c;
        i += 1;
    }
    dst[i] = 0;
    next();
}

// the instruction names that Cpu::inst accepts are the ones of the assembler; the operands are registers, numbers or labels of the function
void nk_inst() {
    expect("(");
    if tok_kind != T_STR { die("Cpu::inst needs the name of the instruction in quotes"); }
    str_copy(@nk_line, @tok_str, 256);
    next();
    int n = 0;
    while accept(",") {
        if n == 0 { append_text(@nk_line, " "); } else { append_text(@nk_line, ", "); }
        if nk_at_reg() {
            nk_add_reg(@nk_line, nk_reg());
        } else if nk_at_num() {
            nk_add_num(@nk_line, nk_num());
        } else if tok_kind == T_IDENT {
            append_text(@nk_line, "L");
            append_int(@nk_line, nk_label(@tok_text, false));
            next();
        } else {
            die("a register, a number or a label was expected");
        }
        n += 1;
    }
    expect(")");
    nk_emit(@nk_line);
}

// Cpu::name();  the statement after "Cpu" "::" was read: tok is the name
void nk_cpu() {
    if tok_kind != T_IDENT { die("a name was expected after Cpu::"); }
    char name[64];
    str_copy(@name, @tok_text, 64);
    next();
    if str_eq(@name, "inst") {
        nk_inst();
        return;
    }
    expect("(");
    int arg = 0;
    if str_eq(@name, "brk") {
        arg = nk_num();
    }
    expect(")");
    if str_eq(@name, "wait") { nk_emit("wfi"); }
    else if str_eq(@name, "event") { nk_emit("wfe"); }
    else if str_eq(@name, "send_event") { nk_emit("sev"); }
    else if str_eq(@name, "yield") { nk_emit("yield"); }
    else if str_eq(@name, "nop") { nk_emit("nop"); }
    else if str_eq(@name, "isb") { nk_emit("isb"); }
    else if str_eq(@name, "dsb") { nk_emit("dsb sy"); }
    else if str_eq(@name, "dmb") { nk_emit("dmb sy"); }
    else if str_eq(@name, "eret") { nk_emit("eret"); }
    else if str_eq(@name, "brk") {
        str_copy(@nk_line, "brk ", 256);
        append_int(@nk_line, arg);
        nk_emit(@nk_line);
    } else {
        die_name("this is not a Cpu:: function of the low level (wait event send_event yield nop isb dsb dmb eret brk inst)", @name);
    }
}

// the end of a statement
void nk_end() {
    expect(";");
}

// R = ...;  (the destination register was read, tok is "=" or an operator with =)
void nk_assign(int rd, char^ op_eq) {
    // op_eq: "=" or "+=" "-=" ...
    bool plain = str_eq(op_eq, "=");
    char op[8];
    if !plain {
        int n = str_len(op_eq);
        str_copy(@op, op_eq, 8);
        op[n - 1] = 0;
    }
    if plain {
        // R = number
        if nk_at_num() {
            int v = nk_num();
            nk_rn("mov", rd, v);
            nk_end();
            return;
        }
        if nk_at_mem() {
            nk_load(rd);
            nk_end();
            return;
        }
        if tok_is("Sys") {
            char sr[64];
            nk_sys_name(@sr);
            str_copy(@nk_line, "mrs ", 256);
            nk_add_reg(@nk_line, rd);
            append_text(@nk_line, ", ");
            append_text(@nk_line, @sr);
            nk_emit(@nk_line);
            nk_end();
            return;
        }
        if tok_is("~") {
            next();
            int rs = nk_reg();
            nk_rr("mvn", rd, rs);
            nk_end();
            return;
        }
        if tok_is("-") && !(nk_at_num()) {
            die("a number or a register was expected");
        }
        if tok_is("Bit") {
            // R = Bit::clz(R2);  clz ctz popcount bswap rbit
            next();
            expect("::");
            char bn[32];
            str_copy(@bn, @tok_text, 32);
            next();
            expect("(");
            int rb = nk_reg();
            expect(")");
            if str_eq(@bn, "clz") { nk_rr("clz", rd, rb); }
            else if str_eq(@bn, "rbit") { nk_rr("rbit", rd, rb); }
            else if str_eq(@bn, "bswap") { nk_rr("rev", rd, rb); }
            else if str_eq(@bn, "popcount") { nk_rr("popcnt", rd, rb); }
            else if str_eq(@bn, "ctz") { nk_rr("rbit", rd, rb); nk_rr("clz", rd, rd); }
            else { die_name("this is not a Bit:: function here (clz ctz popcount bswap rbit)", @bn); }
            nk_end();
            return;
        }
        // R = R2 [op (R3 | number)]
        int ra = nk_reg();
        if tok_is(";") {
            if ra == 32 { nk_rn("mov", rd, 0); } else { nk_rr("mov", rd, ra); }
            next();
            return;
        }
        if tok_kind != T_OP && !tok_is("xor") { die("an operator or ; was expected"); }
        char o2[8];
        str_copy(@o2, @tok_text, 8);
        next();
        if str_eq(@o2, ">>") && tok_is(">") {
            next();
            str_copy(@o2, ">>>", 8);
        }
        if nk_at_reg() {
            int rb2 = nk_reg();
            nk_binop(@o2, rd, ra, false, rb2);
        } else if nk_at_num() {
            int nb = nk_num();
            nk_binop(@o2, rd, ra, true, nb);
        } else {
            die("a register or a number was expected");
        }
        nk_end();
        return;
    }
    // R op= R2 | number
    str_copy(@nk_line, @op, 256);
    if str_eq(@op, ">>") && tok_is(">") {
        next();
        str_copy(@op, ">>>", 8);
    }
    if nk_at_reg() {
        int rc = nk_reg();
        nk_binop(@op, rd, rd, false, rc);
    } else if nk_at_num() {
        int nc = nk_num();
        nk_binop(@op, rd, rd, true, nc);
    } else {
        die("a register or a number was expected");
    }
    nk_end();
}

// if ... goto label;
void nk_if() {
    next();                                // if
    bool neg = false;
    if tok_is("!") {
        neg = true;
        next();
    }
    int ra = nk_reg();
    if tok_is(".") {
        // R.bit(n)
        next();
        if !tok_is("bit") { die("only .bit(n) can follow a register in an if"); }
        next();
        expect("(");
        int bit = nk_num();
        expect(")");
        if bit < 0 || bit > 63 { die("a bit is 0 .. 63"); }
        if !tok_is("goto") { die("goto was expected"); }
        next();
        if tok_kind != T_IDENT { die("a label was expected"); }
        int lab = nk_label(@tok_text, false);
        next();
        nk_end();
        str_copy(@nk_line, "tbnz ", 256);
        if neg { str_copy(@nk_line, "tbz ", 256); }
        nk_add_reg(@nk_line, ra);
        append_text(@nk_line, ", ");
        append_int(@nk_line, bit);
        append_text(@nk_line, ", L");
        append_int(@nk_line, lab);
        nk_emit(@nk_line);
        return;
    }
    if neg { die("! is for R.bit(n) only; write the comparison the other way"); }
    if tok_kind != T_OP { die("a comparison (== != < <= > >=) was expected"); }
    char cmpop[8];
    str_copy(@cmpop, @tok_text, 8);
    char^ cc = nk_cc(@cmpop);
    next();
    if nk_at_reg() {
        int rb = nk_reg();
        nk_rr("cmp", ra, rb);
    } else {
        int nb = nk_num();
        if nb >= 0 && nb <= 4095 {
            nk_rn("cmp", ra, nb);
        } else {
            nk_scratch(nb);
            nk_rr("cmp", ra, 17);
        }
    }
    if !tok_is("goto") { die("goto was expected"); }
    next();
    if tok_kind != T_IDENT { die("a label was expected"); }
    int lab2 = nk_label(@tok_text, false);
    next();
    nk_end();
    str_copy(@nk_line, "b.", 256);
    append_text(@nk_line, cc);
    append_text(@nk_line, " L");
    append_int(@nk_line, lab2);
    nk_emit(@nk_line);
}

// one statement of a naked function
void parse_naked_stmt() {
    if tok_kind != T_IDENT && !tok_is("[") { die("a statement of the low level was expected (Reg::x0 = ...; ret; goto ...; if ...)"); }
    if tok_is("ret") {
        next();
        nk_end();
        nk_emit("ret");
        return;
    }
    if tok_is("goto") {
        next();
        if tok_kind != T_IDENT { die("a label was expected"); }
        int lab = nk_label(@tok_text, false);
        next();
        nk_end();
        str_copy(@nk_line, "b L", 256);
        append_int(@nk_line, lab);
        nk_emit(@nk_line);
        return;
    }
    if tok_is("if") {
        nk_if();
        return;
    }
    if tok_is("call") || tok_is("tail") {
        bool is_call = tok_is("call");
        next();
        if tok_kind != T_IDENT { die("the name of a function was expected"); }
        char cname[256];
        str_copy(@cname, @tok_text, 256);
        next();
        nk_end();
        note_call(@cname);
        if is_call { str_copy(@nk_line, "bl ", 256); } else { str_copy(@nk_line, "b ", 256); }
        append_text(@nk_line, @cname);
        nk_emit(@nk_line);
        return;
    }
    if tok_is("svc") {
        next();
        expect("(");
        int n = nk_num();
        expect(")");
        nk_end();
        str_copy(@nk_line, "svc ", 256);
        append_int(@nk_line, n);
        nk_emit(@nk_line);
        return;
    }
    if tok_is("Cpu") {
        next();
        expect("::");
        nk_cpu();
        nk_end();
        return;
    }
    if tok_is("Sys") {
        char sr[64];
        nk_sys_name(@sr);
        expect("=");
        if nk_at_num() {
            // Sys::daifset = 3;  (the fields of PSTATE take a number)
            int v = nk_num();
            nk_end();
            str_copy(@nk_line, "msr ", 256);
            append_text(@nk_line, @sr);
            append_text(@nk_line, ", ");
            append_int(@nk_line, v);
            nk_emit(@nk_line);
            return;
        }
        int rs = nk_reg();
        nk_end();
        str_copy(@nk_line, "msr ", 256);
        append_text(@nk_line, @sr);
        append_text(@nk_line, ", ");
        nk_add_reg(@nk_line, rs);
        nk_emit(@nk_line);
        return;
    }
    if nk_at_mem() {
        // a store:  [B + off] = R;   u8[B + off] = R;
        nk_read_mem_prefix();
        int base = nk_addr(nk_msize);
        int off = nk_off;
        int size = nk_msize;
        int kind = nk_mkind;
        expect("=");
        int rs2 = 0;
        if nk_at_num() {
            int nv = nk_num();
            nk_scratch(nv);
            rs2 = 17;
            if base == 17 {
                die("a number cannot be stored when the address needs x17 too: put the number in a register first");
            }
        } else {
            rs2 = nk_reg();
        }
        nk_end();
        char^ mn = "str";
        if kind == 1 || kind == 4 { mn = "strb"; }
        else if kind == 2 || kind == 5 { mn = "strh"; }
        else if kind == 3 || kind == 6 { mn = "strw"; }
        nk_mem(mn, rs2, base, off);
        size = size + 0;
        return;
    }
    // a label  name:   or a register statement
    if tok_kind == T_IDENT && tok_text[0] == 'x' && tok_text[1] >= '0' && tok_text[1] <= '9' && nk_xnum(@tok_text) < 0 {
        die_name("this is not a register (the registers are x0 .. x30)", @tok_text);
    }
    if tok_kind == T_IDENT && !nk_at_reg() {
        char lbl_text[256];
        str_copy(@lbl_text, @tok_text, 256);
        next();
        if tok_is(":") {
            next();
            int lab = nk_label(@lbl_text, true);
            place_label(lab);
            return;
        }
        die_name("a statement of the low level was expected; this is not one", @lbl_text);
    }
    int rd = nk_reg();
    if tok_kind != T_OP { die("= or an operator with = was expected after the register"); }
    char aop[8];
    str_copy(@aop, @tok_text, 8);
    int al = str_len(@aop);
    if !(aop[al - 1] == '=' && !str_eq(@aop, "==") && !str_eq(@aop, "!=") && !str_eq(@aop, "<=") && !str_eq(@aop, ">=")) {
        die("= or an operator with = (+= -= *= &= |= <<= >>=) was expected after the register");
    }
    next();
    nk_assign(rd, @aop);
}

// the body of a naked function: { statements }
void parse_naked_block() {
    nk_reset();
    expect("{");
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected at the end of the naked function"); }
        parse_naked_stmt();
    }
    nk_check_labels();
    next();
}

// a naked function after its name and "(" were read: the parameters are only counted (they arrive in x0 .. x7), then the body
void parse_naked_function(int f_idx) {
    int np = 0;
    if !tok_is(")") {
        while true {
            parse_type();
            if ty_void == 1 && ty_ptr == 0 { die("a parameter cannot be void"); }
            if tok_kind != T_IDENT { die("a parameter name was expected"); }
            if ty_dyn != 0 || (ty_tid >= 100 && ty_ptr == 0) { die("a naked function takes whole numbers and pointers only (the other values are read with Reg::)"); }
            if np >= 8 { die("a naked function has at most 8 parameters (x0 .. x7)"); }
            fptid[f_idx * 8 + np] = 0;
            fpstr[f_idx * 8 + np] = 0;
            np += 1;
            next();
            if tok_is("[") { die("an array parameter is not allowed in a naked function (pass a pointer and a length)"); }
            if tok_is(",") { next(); } else { break; }
        }
    }
    expect(")");
    fnpar[f_idx] = np;
    parse_naked_block();
}

// ---------------------------------------------------------------------------------------------- abi: a calling convention for a trap instruction
//   abi Syscall { number: x8; args: x0..x5; result: x0; via: svc 0; }
//   int n = Syscall::call(64, 1, buf, 6);        // the first value goes to the number register (if there is one), the others to the argument registers
// The values are computed like the arguments of any call; then they are moved into place (a cycle is broken with x17), the instruction `via` follows,
// and the result register is x0 afterwards.

char abi_name[1024];             // 16 names of 64 characters
int abi_num[16];                 // the register of the number, or -1
int abi_args[128];               // 8 argument registers for each
int abi_nargs[16];
int abi_res[16];
char abi_via[1024];              // the text of the instruction
int abi_count;

int find_abi(char^ name) {
    int i = 0;
    while i < abi_count {
        if str_eq(@abi_name + i * 64, name) { return i; }
        i += 1;
    }
    return 0 - 1;
}

int abi_reg() {
    if tok_kind != T_IDENT { die("a register (x0 .. x30) was expected"); }
    int r = nk_xnum(@tok_text);
    if r < 0 { die_name("this is not a register (x0 .. x30)", @tok_text); }
    next();
    return r;
}

void parse_abi() {
    next();                                  // abi
    if tok_kind != T_IDENT { die("a name for the abi was expected"); }
    int ab = find_abi(@tok_text);
    bool fresh = false;
    if pass_no == 1 {
        if ab >= 0 { die_name("this abi exists already", @tok_text); }
        if abi_count >= 16 { die("too many abi declarations (16 at most)"); }
        ab = abi_count;
        abi_count += 1;
        str_copy(@abi_name + ab * 64, @tok_text, 64);
        abi_num[ab] = 0 - 1;
        abi_nargs[ab] = 0;
        abi_res[ab] = 0;
        str_copy(@abi_via + ab * 64, "svc 0", 64);
        fresh = true;
    }
    next();
    expect("{");
    while !tok_is("}") {
        if tok_kind != T_IDENT { die("number: args: result: or via: was expected"); }
        char field[32];
        str_copy(@field, @tok_text, 32);
        next();
        expect(":");
        if str_eq(@field, "number") {
            int r = abi_reg();
            if fresh { abi_num[ab] = r; }
        } else if str_eq(@field, "result") {
            int r2 = abi_reg();
            if fresh { abi_res[ab] = r2; }
        } else if str_eq(@field, "args") {
            int first = abi_reg();
            int cnt = 0;
            if tok_is(".") {
                next();
                expect(".");                 // a range is written with two dots
                int last = abi_reg();
                if last < first || last - first > 7 { die("a range of at most 8 registers was expected (x0..x5)"); }
                while first + cnt <= last {
                    if fresh { abi_args[ab * 8 + cnt] = first + cnt; }
                    cnt += 1;
                }
            } else {
                if fresh { abi_args[ab * 8] = first; }
                cnt = 1;
                while accept(",") {
                    if cnt >= 8 { die("at most 8 argument registers"); }
                    int rn = abi_reg();
                    if fresh { abi_args[ab * 8 + cnt] = rn; }
                    cnt += 1;
                }
            }
            if fresh { abi_nargs[ab] = cnt; }
        } else if str_eq(@field, "via") {
            // svc N, hvc N, smc N, or a call:  bl name
            if tok_kind != T_IDENT { die("svc, hvc, smc or bl was expected"); }
            char vtext[64];
            str_copy(@vtext, @tok_text, 64);
            bool isbl = str_eq(@vtext, "bl");
            if !isbl && !str_eq(@vtext, "svc") && !str_eq(@vtext, "hvc") && !str_eq(@vtext, "smc") { die_name("via: takes svc, hvc, smc (with a number) or bl (with a function)", @vtext); }
            next();
            append_text(@vtext, " ");
            if isbl {
                if tok_kind != T_IDENT { die("the name of a function was expected after bl"); }
                append_text(@vtext, @tok_text);
                next();
            } else {
                append_int(@vtext, nk_num());
            }
            if fresh { str_copy(@abi_via + ab * 64, @vtext, 64); }
        } else {
            die_name("this is not a field of an abi (number args result via)", @field);
        }
        expect(";");
    }
    expect("}");
    accept(";");
    if fresh && abi_nargs[ab] == 0 { die("an abi needs args: (the registers of the arguments)"); }
}

// the call: the values are in x0 .. x(n-1) in the order they were written
void emit_abi_call(int ab, int n) {
    int total = abi_nargs[ab];
    int first = 0;
    int dst[16];
    if abi_num[ab] >= 0 {
        total += 1;
        dst[0] = abi_num[ab];
        first = 1;
    }
    if n > total { die("more values than the abi has registers"); }
    if n < first + 0 { die("the first value of this abi is the number of the call"); }
    int i = 0;
    while i < abi_nargs[ab] {
        dst[first + i] = abi_args[ab * 8 + i];
        i += 1;
    }
    // the parallel move  x[i] -> x[dst[i]]
    int src[16];
    bool done[16];
    i = 0;
    while i < n {
        src[i] = i;
        done[i] = dst[i] == i;
        i += 1;
    }
    int left = 0;
    i = 0;
    while i < n {
        if !done[i] { left += 1; }
        i += 1;
    }
    while left > 0 {
        bool moved = false;
        i = 0;
        while i < n && !moved {
            if !done[i] {
                // the destination may be written when no other move still needs it as a source
                bool free = true;
                int j = 0;
                while j < n {
                    if !done[j] && j != i && src[j] == dst[i] { free = false; }
                    j += 1;
                }
                if free {
                    str_copy(@nk_line, "mov x", 256);
                    append_int(@nk_line, dst[i]);
                    append_text(@nk_line, ", x");
                    append_int(@nk_line, src[i]);
                    emit_line(@nk_line);
                    done[i] = true;
                    left -= 1;
                    moved = true;
                }
            }
            i += 1;
        }
        if !moved {
            // only cycles are left: park one source in x17
            i = 0;
            while i < n && done[i] { i += 1; }
            str_copy(@nk_line, "mov x17, x", 256);
            append_int(@nk_line, src[i]);
            emit_line(@nk_line);
            int s0 = src[i];
            int j2 = 0;
            while j2 < n {
                if !done[j2] && src[j2] == s0 { src[j2] = 17; }
                j2 += 1;
            }
        }
    }
    if abi_via[ab * 64] == 'b' && abi_via[ab * 64 + 1] == 'l' { note_call(@abi_via + ab * 64 + 3); }
    emit_line(@abi_via + ab * 64);
    if abi_res[ab] != 0 {
        str_copy(@nk_line, "mov x0, x", 256);
        append_int(@nk_line, abi_res[ab]);
        emit_line(@nk_line);
    }
}
