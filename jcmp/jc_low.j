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
    nk_dest(rd);
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

// ---------------------------------------------------------------------------------------------- Sys:: in every function
//   int t = Sys::cntvct_el0;          // mrs x0, cntvct_el0
//   Sys::tpidr_el0 = p;               // msr tpidr_el0, x0
//   Sys::daifset = 2;                 // msr daifset, #2   (the fields of PSTATE take a number: daifset daifclr)
// The names are the ones of the manual (lower or upper case). Most of them are for the kernel: a program that runs under Linux can read a few
// (cntvct_el0, cntfrq_el0, tpidr_el0, nzcv, fpcr, fpsr ...); the others stop it with an illegal instruction.

// the name after Sys:: (the token is "::" at the start); lower case in dst
void sys_name(char^ dst) {
    next();                                  // ::
    if tok_kind != T_IDENT { die("a system register name was expected after Sys::"); }
    int i = 0;
    while tok_text[i] != 0 && i < 62 {
        char c = tok_text[i];
        if c >= 'A' && c <= 'Z' { c = c + 32; }
        dst[i] = c;
        i += 1;
    }
    dst[i] = 0;
    next();
}

void gen_sys_read() {
    char sn[64];
    sys_name(@sn);
    if as_sysreg_code(@sn) < 0 { die_name("this is not a system register that jcmp knows (see docs/LANGUAGE.md; the general form is s3_0_c12_c0_0)", @sn); }
    str_copy(@nk_line, "mrs x0, ", 256);
    append_text(@nk_line, @sn);
    emit_line(@nk_line);
    ex_w = 8;
    ex_ty = 0;
    rv_valid = 0;
}

// Sys::name = expression;   (the token is "::")
void parse_sys_assign() {
    char sn[64];
    sys_name(@sn);
    bool pstate = str_eq(@sn, "daifset") || str_eq(@sn, "daifclr");
    if !pstate && as_sysreg_code(@sn) < 0 { die_name("this is not a system register that jcmp knows (see docs/LANGUAGE.md; the general form is s3_0_c12_c0_0)", @sn); }
    expect("=");
    if pstate {
        if tok_kind != T_NUM { die("daifset and daifclr take a number 0 .. 15"); }
        str_copy(@nk_line, "msr ", 256);
        append_text(@nk_line, @sn);
        append_text(@nk_line, ", ");
        append_int(@nk_line, tok_num & 15);
        emit_line(@nk_line);
        next();
        expect(";");
        return;
    }
    parse_expr();
    str_copy(@nk_line, "msr ", 256);
    append_text(@nk_line, @sn);
    append_text(@nk_line, ", x0");
    emit_line(@nk_line);
    expect(";");
}

// ---------------------------------------------------------------------------------------------- device: hardware registers as data
//   device Uart @ 0x0900_0000 {
//       data:  u32 @ 0x00;
//       flags: u32 @ 0x18 { txfull: 5; rxempty: 4; mode: 8..10; }       // names for bits (a number) or for a field of bits (hi..lo)
//   }
//   Uart.data = 'A';                    // one store of 32 bits (a store of the size of the register)
//   if Uart.flags.txfull { }            // a read of the device each time, a bool;  Uart.flags.bit(5) the same for a number of a bit
//   int m = Uart.flags.mode;            // the bits 8..10 as a number
//   Uart.flags.mode = 3;                // reads the register, changes those bits, writes it
//   Uart.ctrl |= 1;                     // | & + - with a number: read, change, write
// Every access is made where it is written, as often as it is written (the optimiser does not merge or remove accesses to a device).
// u8 u16 u32 u64: the size of the register; the value read is not signed.

char dev_name[1024];              // 16 devices
int dev_base[16];
int dev_nf[16];                   // how many fields
int dev_f0[16];                   // the first field
int dev_count;
char devf_name[8192];             // 128 fields of 64 characters
int devf_off[128];
int devf_size[128];
int devf_nb[128];                 // how many named bit fields
int devf_b0[128];                 // the first of them
int devf_count;
char devb_name[8192];             // 128 bit fields
int devb_hi[128];
int devb_lo[128];
int devb_count;

int find_device(char^ name) {
    int i = 0;
    while i < dev_count {
        if str_eq(@dev_name + i * 64, name) { return i; }
        i += 1;
    }
    return 0 - 1;
}

void parse_device() {
    next();                                  // device
    if tok_kind != T_IDENT { die("a name for the device was expected"); }
    int d = find_device(@tok_text);
    bool fresh = false;
    if pass_no == 1 {
        if d >= 0 { die_name("this device exists already", @tok_text); }
        if dev_count >= 16 { die("too many devices (16 at most)"); }
        d = dev_count;
        dev_count += 1;
        str_copy(@dev_name + d * 64, @tok_text, 64);
        dev_nf[d] = 0;
        dev_f0[d] = devf_count;
        fresh = true;
    }
    next();
    expect("@");
    if tok_kind != T_NUM { die("the address of the device (a number) was expected after @"); }
    if fresh { dev_base[d] = tok_num; }
    next();
    expect("{");
    while !tok_is("}") {
        if tok_kind != T_IDENT { die("the name of a register was expected"); }
        char fname_[64];
        str_copy(@fname_, @tok_text, 64);
        next();
        expect(":");
        if tok_kind != T_IDENT { die("u8, u16, u32 or u64 was expected"); }
        int size = 0;
        if str_eq(@tok_text, "u8") { size = 1; }
        else if str_eq(@tok_text, "u16") { size = 2; }
        else if str_eq(@tok_text, "u32") { size = 4; }
        else if str_eq(@tok_text, "u64") { size = 8; }
        else { die_name("the size of a register is u8, u16, u32 or u64", @tok_text); }
        next();
        expect("@");
        if tok_kind != T_NUM { die("the offset of the register (a number) was expected after @"); }
        int off = tok_num;
        next();
        int fidx = 0 - 1;
        if fresh {
            if devf_count >= 128 { die("too many device registers (128 at most)"); }
            fidx = devf_count;
            devf_count += 1;
            dev_nf[d] += 1;
            str_copy(@devf_name + fidx * 64, @fname_, 64);
            devf_off[fidx] = off;
            devf_size[fidx] = size;
            devf_nb[fidx] = 0;
            devf_b0[fidx] = devb_count;
        }
        if tok_is("{") {
            next();
            while !tok_is("}") {
                if tok_kind != T_IDENT { die("the name of a bit field was expected"); }
                char bname[64];
                str_copy(@bname, @tok_text, 64);
                next();
                expect(":");
                if tok_kind != T_NUM { die("a bit number was expected"); }
                int lo = tok_num;
                int hi = tok_num;
                next();
                if tok_is(".") {
                    next();
                    expect(".");
                    if tok_kind != T_NUM { die("the upper bit number was expected"); }
                    hi = tok_num;
                    next();
                    if hi < lo { die("a bit field is written low..high (8..10)"); }
                }
                if hi >= size * 8 { die("this bit is outside the register"); }
                expect(";");
                if fresh {
                    if devb_count >= 128 { die("too many bit fields (128 at most)"); }
                    str_copy(@devb_name + devb_count * 64, @bname, 64);
                    devb_hi[devb_count] = hi;
                    devb_lo[devb_count] = lo;
                    devb_count += 1;
                    devf_nb[fidx] += 1;
                }
            }
            next();
            accept(";");
        } else {
            expect(";");
        }
    }
    expect("}");
    accept(";");
}

// the register of the device d named name (the index), or -1
int dev_field(int d, char^ name) {
    int i = 0;
    while i < dev_nf[d] {
        if str_eq(@devf_name + (dev_f0[d] + i) * 64, name) { return dev_f0[d] + i; }
        i += 1;
    }
    return 0 - 1;
}

int dev_bitfield(int f, char^ name) {
    int i = 0;
    while i < devf_nb[f] {
        if str_eq(@devb_name + (devf_b0[f] + i) * 64, name) { return devf_b0[f] + i; }
        i += 1;
    }
    return 0 - 1;
}

// the address of the register into x9
void dev_addr(int d, int f) {
    str_copy(@nk_line, "mov x9, ", 256);
    append_int(@nk_line, dev_base[d] + devf_off[f]);
    emit_line(@nk_line);
}

// the load of the register at x9 into dst
void dev_load(int f, char^ dst) {
    int sz = devf_size[f];
    char^ mn = "ldr";
    if sz == 1 { mn = "ldrb"; }
    else if sz == 2 { mn = "ldrh"; }
    else if sz == 4 { mn = "ldrw"; }
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    append_text(@nk_line, dst);
    append_text(@nk_line, ", [x9]");
    emit_line(@nk_line);
}

void dev_store(int f, char^ src) {
    int sz = devf_size[f];
    char^ mn = "str";
    if sz == 1 { mn = "strb"; }
    else if sz == 2 { mn = "strh"; }
    else if sz == 4 { mn = "strw"; }
    str_copy(@nk_line, mn, 256);
    append_text(@nk_line, " ");
    append_text(@nk_line, src);
    append_text(@nk_line, ", [x9]");
    emit_line(@nk_line);
}

void dev_mov(char^ reg, int v) {
    str_copy(@nk_line, "mov ", 256);
    append_text(@nk_line, reg);
    append_text(@nk_line, ", ");
    if v < 0 {
        append_text(@nk_line, "-");
        append_int(@nk_line, 0 - v);
    } else {
        append_int(@nk_line, v);
    }
    emit_line(@nk_line);
}

int dev_mask(int hi, int lo) {
    int w = hi - lo + 1;
    if w >= 63 { return 0 - 1; }
    return (1 << w) - 1;
}

// Device.reg  /  Device.reg.bit(n)  /  Device.reg.field   in an expression (the token is "." after the device name, which is in id_name)
void gen_device_read() {
    int d = find_device(@id_name);
    next();                                  // .
    if tok_kind != T_IDENT { die("the name of a register was expected after the device name"); }
    int f = dev_field(d, @tok_text);
    if f < 0 { die_name("this device has no such register", @tok_text); }
    next();
    dev_addr(d, f);
    dev_load(f, "x0");
    ex_w = 8;
    ex_ty = 0;
    rv_valid = 0;
    if tok_is(".") {
        next();
        if tok_kind != T_IDENT { die("bit(n) or the name of a bit field was expected"); }
        if str_eq(@tok_text, "bit") {
            next();
            expect("(");
            if tok_kind != T_NUM { die("bit(n) takes a number"); }
            int bn = tok_num;
            next();
            expect(")");
            if bn < 0 || bn >= devf_size[f] * 8 { die("this bit is outside the register"); }
            if bn > 0 {
                str_copy(@nk_line, "lsr x0, x0, #", 256);
                append_int(@nk_line, bn);
                emit_line(@nk_line);
            }
            emit_line("mov x1, 1");
            emit_line("and x0, x0, x1");
            ex_ty = 1;                       // a bool
            return;
        }
        int b = dev_bitfield(f, @tok_text);
        if b < 0 { die_name("this register has no such bit field", @tok_text); }
        next();
        if devb_lo[b] > 0 {
            str_copy(@nk_line, "lsr x0, x0, #", 256);
            append_int(@nk_line, devb_lo[b]);
            emit_line(@nk_line);
        }
        int mask = dev_mask(devb_hi[b], devb_lo[b]);
        if devb_hi[b] - devb_lo[b] + 1 < 64 {
            dev_mov("x1", mask);
            emit_line("and x0, x0, x1");
        }
        if devb_hi[b] == devb_lo[b] { ex_ty = 1; }          // one bit: a bool
    }
}

// a statement  Device.reg = value;  Device.reg.field = value;  Device.reg |= value;  (the name of the device was read, the token is ".")
void parse_device_assign(char^ dname) {
    int d = find_device(dname);
    next();                                  // .
    if tok_kind != T_IDENT { die("the name of a register was expected after the device name"); }
    int f = dev_field(d, @tok_text);
    if f < 0 { die_name("this device has no such register", @tok_text); }
    next();
    int b = 0 - 1;
    if tok_is(".") {
        next();
        if tok_kind != T_IDENT { die("the name of a bit field was expected"); }
        if str_eq(@tok_text, "bit") { die("a single bit is written with its name: declare it in the braces of the register, then Device.reg.name = 1;"); }
        b = dev_bitfield(f, @tok_text);
        if b < 0 { die_name("this register has no such bit field", @tok_text); }
        next();
    }
    if tok_kind != T_OP { die("= or an operator with = (|= &= += -=) was expected"); }
    char op[8];
    str_copy(@op, @tok_text, 8);
    next();
    parse_expr();                            // the value is in x0
    expect(";");
    if b >= 0 {
        // the bits: read, clear, put the new bits in, write
        int mask = dev_mask(devb_hi[b], devb_lo[b]);
        int lo = devb_lo[b];
        dev_addr(d, f);
        dev_load(f, "x1");
        if !str_eq(@op, "=") { die("a bit field takes = only"); }
        dev_mov("x2", mask);
        emit_line("and x0, x0, x2");
        if lo > 0 {
            str_copy(@nk_line, "lsl x0, x0, #", 256);
            append_int(@nk_line, lo);
            emit_line(@nk_line);
            str_copy(@nk_line, "lsl x2, x2, #", 256);
            append_int(@nk_line, lo);
            emit_line(@nk_line);
        }
        emit_line("mvn x2, x2");
        emit_line("and x1, x1, x2");
        emit_line("orr x1, x1, x0");
        dev_store(f, "x1");
        return;
    }
    if str_eq(@op, "=") {
        dev_addr(d, f);
        dev_store(f, "x0");
        return;
    }
    dev_addr(d, f);
    dev_load(f, "x1");
    if str_eq(@op, "|=") { emit_line("orr x1, x1, x0"); }
    else if str_eq(@op, "&=") { emit_line("and x1, x1, x0"); }
    else if str_eq(@op, "+=") { emit_line("add x1, x1, x0"); }
    else if str_eq(@op, "-=") { emit_line("sub x1, x1, x0"); }
    else { die_name("this operator cannot change a device register (= |= &= += -=)", @op); }
    dev_store(f, "x1");
}

// ---------------------------------------------------------------------------------------------- register { } blocks and Reg:: in normal code
//   #reserve x18                        // the compiler never uses x18 (or x19 .. x25 if you name them)
//   register {                          // the statements of the low level (docs/LANGUAGE.md), with the bare names x0 .. x30
//       x1 = [x0 + 8];
//       x1 += 1;
//       [x0 + 8] = x1;
//   }
//   Reg::x18 = p;   int q = Reg::x18;   // in normal code only a reserved register (and x18) can be read and written
// A function with a register { } block keeps its variables in the frame (no register is given to them) and is not changed by the optimiser
// inside the block. The block may change x0 .. x17 (the work registers of the statement); a change of a callee-saved register that was not
// reserved (x19 .. x28) is a warning.

int nk_dests;                    // bit n: the register xn was written by the statements of the block

void nk_dest(int r) {
    if r >= 0 && r <= 30 { nk_dests = nk_dests | (1 << r); }
}

void parse_register_block() {
    next();                                  // register
    if !tok_is("{") { die("register { ... } was expected"); }
    nk_reset();
    nk_dests = 0;
    next();
    emit_line(";N");
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected at the end of the register block"); }
        parse_naked_stmt();
    }
    nk_check_labels();
    next();
    emit_line(";N");
    // callee-saved registers that the block changed and nobody reserved
    int r = 19;
    while r <= 28 {
        if (nk_dests & (1 << r)) != 0 && (reserve_mask & (1 << r)) == 0 {
            char wm[200];
            str_copy(@wm, "this register block changes x", 200);
            append_int(@wm, r);
            append_text(@wm, ", which a function must give back unchanged (reserve it with #reserve x");
            append_int(@wm, r);
            append_text(@wm, " if the program owns it)");
            if pass_no >= 2 { warn(@wm, "register-block"); }
        }
        r += 1;
    }
}

// a register of normal code: only x18 and the reserved ones
int nk_normal_reg() {
    if tok_kind != T_IDENT { die("a register name was expected after Reg::"); }
    int r = nk_xnum(@tok_text);
    if r < 0 { die_name("this is not a register (x18 or a reserved one)", @tok_text); }
    if r != 18 && (reserve_mask & (1 << r)) == 0 {
        die_name("normal code can read and write x18 and the registers named in #reserve only; use a register { } block for the others", @tok_text);
    }
    next();
    return r;
}

// Reg::x18 in an expression
void gen_reg_read() {
    next();                                  // ::
    int r = nk_normal_reg();
    str_copy(@nk_line, "mov x0, x", 256);
    append_int(@nk_line, r);
    emit_line(@nk_line);
    ex_w = 8;
    ex_ty = 0;
    rv_valid = 0;
}

// Reg::x18 = expression;
void parse_reg_assign() {
    next();                                  // ::
    int r = nk_normal_reg();
    expect("=");
    parse_expr();
    expect(";");
    str_copy(@nk_line, "mov x", 256);
    append_int(@nk_line, r);
    append_text(@nk_line, ", x0");
    emit_line(@nk_line);
}
