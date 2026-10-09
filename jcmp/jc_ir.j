// jc_ir.j -- the intermediate representation (IR) of Jcmp: design in docs/design/03-ir.md (option I1).
//
// A function is a list of basic blocks. A block is a run of instructions (in order, one block after the other in the arrays) and ends
// with exactly one terminator (jmp, br, ret, trap). Instructions are three-address code on virtual registers ("vregs"): a vreg is a
// number, it can be assigned many times (this is not SSA), and has a class: 0 = a 64-bit whole number or pointer, 1 = a double.
// Memory is touched only by load / store with a width. The IR does not know the machine: the back end gives it registers and code.
//
// The arrays below hold ONE function at a time (ir_reset starts a new one).

#define IR_MAXI 65536
#define IR_MAXB 8192
#define IR_MAXV 65536
#define IR_MAXA 262144

// the opcodes
#define IR_CONST 1           // d = k                              (a 64-bit whole number)
#define IR_COPY 2            // d = a
#define IR_ADD 3             // d = a + b|k      (all the arithmetic below: b is a vreg, or the number k when ir_bi is 1)
#define IR_SUB 4
#define IR_MUL 5
#define IR_SDIV 6
#define IR_UDIV 7
#define IR_AND 8
#define IR_OR 9
#define IR_XOR 10
#define IR_SHL 11
#define IR_LSHR 12
#define IR_ASHR 13
#define IR_MULHS 14          // d = the high 64 bits of the signed product a * b
#define IR_NEG 15            // d = -a
#define IR_NOT 16            // d = ~a
#define IR_EXT 17            // d = a extended from k bits (k = 8, 16, 32; ir_w = 1: signed, 0: unsigned)
#define IR_SETCC 18          // d = (a cc b|k) ? 1 : 0           (cc: see below)
#define IR_LOAD 19           // d = memory[a + k]                  (ir_w: bytes 1 2 4 8, negative: signed)
#define IR_STORE 20          // memory[a + k] = b                  (ir_w: bytes 1 2 4 8)
#define IR_FADD 21           // d = a + b   (doubles)
#define IR_FSUB 22
#define IR_FMUL 23
#define IR_FDIV 24
#define IR_FSQRT 25          // d = sqrt(a)
#define IR_FNEG 26
#define IR_FABS 27
#define IR_FFLOOR 28
#define IR_I2F 29            // d (double) = a (whole number)
#define IR_F2I 30            // d (whole number) = a (double), towards 0
#define IR_BITS2F 31         // d (double) = the bits a (whole number)
#define IR_F2BITS 32         // d (whole number) = the bits of a (double)
#define IR_FSETCC 33         // d = (a cc b) ? 1 : 0  (doubles; false if one is not a number)
#define IR_ADDR_SLOT 34      // d = the address of the slot k of the frame (plus ir_b, a number)
#define IR_ADDR_GLOBAL 35    // d = the address of the global area + k
#define IR_ADDR_FUNC 36      // d = the address of the function named ir_name[k]
#define IR_CALL 37           // d = name(args)       (the function is ir_name[k]; the arguments are in ir_args)
#define IR_CALLIND 38        // d = a(args)           (a function pointer)
#define IR_SYSCALL 39        // d = the system call a(args)
#define IR_JMP 40            // go to the block t1
#define IR_BR 41             // if a cc b|k go to the block t1, else to t2
#define IR_FBR 42            // if the doubles a cc b: t1, else t2
#define IR_RET 43            // return a (a = 0: no value)
#define IR_TRAP 44           // the program cannot get here (a call that never returns)
#define IR_PARAM 45          // d = the argument number k of the function (made at the start of the first block)

// the conditions (cc) of IR_SETCC and IR_BR
#define IR_EQ 0
#define IR_NE 1
#define IR_LT 2
#define IR_LE 3
#define IR_GT 4
#define IR_GE 5
#define IR_ULT 6
#define IR_ULE 7
#define IR_UGT 8
#define IR_UGE 9

// the instructions
int ir_op[IR_MAXI];
int ir_d[IR_MAXI];           // the vreg that gets the result (0 = none)
int ir_a[IR_MAXI];           // the first operand (a vreg, 0 = none)
int ir_b[IR_MAXI];           // the second operand (a vreg, or a number when ir_bi is 1)
int ir_bi[IR_MAXI];          // 1: ir_b is a number
int ir_k[IR_MAXI];           // a number: the constant, the offset, the condition, the bits of an extension, the index of a name
int ir_w[IR_MAXI];           // the width of a load / store, the sign of an extension
int ir_t1[IR_MAXI];          // the blocks that a jump goes to
int ir_t2[IR_MAXI];
int ir_as[IR_MAXI];          // the arguments of a call: ir_args[ir_as .. ir_as + ir_ac)
int ir_ac[IR_MAXI];
int ir_args[IR_MAXA];
int ir_nargs;
int ir_n;                    // how many instructions

// the blocks
int ir_bs[IR_MAXB];          // the first instruction of the block
int ir_be[IR_MAXB];          // one after the last one
int ir_blab[IR_MAXB];        // the number of the label of the block in the assembler text (for the printer; -1 = none)
int ir_nb;
int ir_cur;                  // the block that gets the next instruction

// the vregs: the class (0 whole number / pointer, 1 double)
int ir_vcls[IR_MAXV];
int ir_nv;

// the slots of the frame: the size in bytes and the place from the frame pointer
int ir_slot_off[1024];
int ir_slot_size[1024];
int ir_nslots;

// the names of the functions that the code calls (ir_name[i], 64 characters each)
char ir_name[262144];
int ir_nnames;
char ir_fname[128];          // the name of the function

void ir_reset(char^ name) {
    str_copy(@ir_fname, name, 128);
    ir_n = 0;
    ir_nargs = 0;
    ir_nb = 0;
    ir_cur = 0 - 1;
    ir_nv = 1;                                 // the vreg 0 means "none"
    ir_nslots = 0;
    ir_nnames = 0;
}

// a new vreg of the class cls
int ir_vreg(int cls) {
    if ir_nv >= IR_MAXV { die("the IR has too many virtual registers in one function"); }
    ir_vcls[ir_nv] = cls;
    ir_nv += 1;
    return ir_nv - 1;
}

// a new block (it gets the instructions that follow ir_set_block); label: its number in the assembler text, or -1
int ir_new_block(int label) {
    if ir_nb >= IR_MAXB { die("the IR has too many blocks in one function"); }
    ir_bs[ir_nb] = ir_n;
    ir_be[ir_nb] = ir_n;
    ir_blab[ir_nb] = label;
    ir_nb += 1;
    return ir_nb - 1;
}

// the instructions of one block are written one after the other: only the last block can get more
void ir_set_block(int b) {
    ir_cur = b;
}

// the number of a name of a function (the same text gives the same number)
int ir_name_index(char^ name) {
    int i = 0;
    while i < ir_nnames {
        if str_eq(@ir_name + i * 64, name) { return i; }
        i += 1;
    }
    if ir_nnames >= 4096 { die("the IR has too many names in one function"); }
    str_copy(@ir_name + ir_nnames * 64, name, 64);
    ir_nnames += 1;
    return ir_nnames - 1;
}

// one instruction at the end of the current block; returns its number
int ir_add(int op, int d, int a, int b, int bi, int k) {
    if ir_n >= IR_MAXI { die("the IR has too many instructions in one function"); }
    if ir_cur < 0 || ir_cur != ir_nb - 1 { die("internal error: an IR instruction was written into a block that is not the last one"); }
    int i = ir_n;
    ir_op[i] = op;
    ir_d[i] = d;
    ir_a[i] = a;
    ir_b[i] = b;
    ir_bi[i] = bi;
    ir_k[i] = k;
    ir_w[i] = 0;
    ir_t1[i] = 0 - 1;
    ir_t2[i] = 0 - 1;
    ir_as[i] = 0;
    ir_ac[i] = 0;
    ir_n += 1;
    ir_be[ir_cur] = ir_n;
    return i;
}

// the arguments of the call i (the vregs are copied)
void ir_set_args(int i, int count, int^ vregs) {
    if ir_nargs + count >= IR_MAXA { die("the IR has too many call arguments in one function"); }
    ir_as[i] = ir_nargs;
    ir_ac[i] = count;
    int k = 0;
    while k < count {
        ir_args[ir_nargs] = vregs[k];
        ir_nargs += 1;
        k += 1;
    }
}

bool ir_is_term(int op) {
    return op == IR_JMP || op == IR_BR || op == IR_FBR || op == IR_RET || op == IR_TRAP;
}

// ---------------------------------------------------------------------------------------------- the printer

char^ ir_opname(int op) {
    if op == IR_CONST { return "const"; }
    if op == IR_COPY { return "copy"; }
    if op == IR_ADD { return "add"; }
    if op == IR_SUB { return "sub"; }
    if op == IR_MUL { return "mul"; }
    if op == IR_SDIV { return "sdiv"; }
    if op == IR_UDIV { return "udiv"; }
    if op == IR_AND { return "and"; }
    if op == IR_OR { return "or"; }
    if op == IR_XOR { return "xor"; }
    if op == IR_SHL { return "shl"; }
    if op == IR_LSHR { return "lshr"; }
    if op == IR_ASHR { return "ashr"; }
    if op == IR_MULHS { return "mulhs"; }
    if op == IR_NEG { return "neg"; }
    if op == IR_NOT { return "not"; }
    if op == IR_EXT { return "ext"; }
    if op == IR_SETCC { return "setcc"; }
    if op == IR_LOAD { return "load"; }
    if op == IR_STORE { return "store"; }
    if op == IR_FADD { return "fadd"; }
    if op == IR_FSUB { return "fsub"; }
    if op == IR_FMUL { return "fmul"; }
    if op == IR_FDIV { return "fdiv"; }
    if op == IR_FSQRT { return "fsqrt"; }
    if op == IR_FNEG { return "fneg"; }
    if op == IR_FABS { return "fabs"; }
    if op == IR_FFLOOR { return "ffloor"; }
    if op == IR_I2F { return "i2f"; }
    if op == IR_F2I { return "f2i"; }
    if op == IR_BITS2F { return "bits2f"; }
    if op == IR_F2BITS { return "f2bits"; }
    if op == IR_FSETCC { return "fsetcc"; }
    if op == IR_ADDR_SLOT { return "addr.slot"; }
    if op == IR_ADDR_GLOBAL { return "addr.global"; }
    if op == IR_ADDR_FUNC { return "addr.func"; }
    if op == IR_CALL { return "call"; }
    if op == IR_CALLIND { return "callind"; }
    if op == IR_SYSCALL { return "syscall"; }
    if op == IR_JMP { return "jmp"; }
    if op == IR_BR { return "br"; }
    if op == IR_FBR { return "fbr"; }
    if op == IR_RET { return "ret"; }
    if op == IR_TRAP { return "trap"; }
    if op == IR_PARAM { return "param"; }
    return "?";
}

char^ ir_ccname(int cc) {
    if cc == IR_EQ { return "eq"; }
    if cc == IR_NE { return "ne"; }
    if cc == IR_LT { return "lt"; }
    if cc == IR_LE { return "le"; }
    if cc == IR_GT { return "gt"; }
    if cc == IR_GE { return "ge"; }
    if cc == IR_ULT { return "ult"; }
    if cc == IR_ULE { return "ule"; }
    if cc == IR_UGT { return "ugt"; }
    return "uge";
}

// the text of the IR goes to the output buffer of the printer
char ir_pbuf[1048576];
int ir_plen;

void ir_pc(int c) {
    if ir_plen < 1048570 {
        ir_pbuf[ir_plen] = c;
        ir_plen += 1;
    }
}

void ir_ps(char^ s) {
    int i = 0;
    while s[i] != 0 {
        ir_pc(s[i]);
        i += 1;
    }
}

void ir_pn(int v) {
    if v < 0 {
        ir_pc('-');
        v = 0 - v;
    }
    if v == 0 {
        ir_pc('0');
        return;
    }
    char d[24];
    int n = 0;
    while v > 0 {
        d[n] = '0' + v % 10;
        v = v / 10;
        n += 1;
    }
    while n > 0 {
        n -= 1;
        ir_pc(d[n]);
    }
}

void ir_pv(int v) {
    if ir_vcls[v] == 1 { ir_pc('f'); } else { ir_pc('v'); }
    ir_pn(v);
}

// the second operand: a vreg or a number
void ir_pb(int i) {
    if ir_bi[i] == 1 { ir_pn(ir_b[i]); } else { ir_pv(ir_b[i]); }
}

void ir_print_instr(int i) {
    int op = ir_op[i];
    ir_ps("    ");
    if ir_d[i] != 0 {
        ir_pv(ir_d[i]);
        ir_ps(" = ");
    }
    ir_ps(ir_opname(op));
    if op == IR_CONST || op == IR_PARAM {
        ir_pc(' ');
        ir_pn(ir_k[i]);
    } else if op == IR_COPY || op == IR_NEG || op == IR_NOT || op == IR_FSQRT || op == IR_FNEG || op == IR_FABS || op == IR_FFLOOR || op == IR_I2F || op == IR_F2I || op == IR_BITS2F || op == IR_F2BITS {
        ir_pc(' ');
        ir_pv(ir_a[i]);
    } else if op == IR_EXT {
        ir_pc(' ');
        ir_pv(ir_a[i]);
        if ir_w[i] == 1 { ir_ps(" signed "); } else { ir_ps(" unsigned "); }
        ir_pn(ir_k[i]);
    } else if op == IR_SETCC || op == IR_FSETCC {
        ir_pc('.');
        ir_ps(ir_ccname(ir_k[i]));
        ir_pc(' ');
        ir_pv(ir_a[i]);
        ir_ps(", ");
        ir_pb(i);
    } else if op == IR_LOAD {
        ir_pc('.');
        ir_pn(ir_w[i]);
        ir_ps(" [");
        ir_pv(ir_a[i]);
        if ir_k[i] != 0 {
            ir_ps(" + ");
            ir_pn(ir_k[i]);
        }
        ir_pc(']');
    } else if op == IR_STORE {
        ir_pc('.');
        ir_pn(ir_w[i]);
        ir_ps(" [");
        ir_pv(ir_a[i]);
        if ir_k[i] != 0 {
            ir_ps(" + ");
            ir_pn(ir_k[i]);
        }
        ir_ps("], ");
        ir_pv(ir_b[i]);
    } else if op == IR_ADDR_SLOT {
        ir_ps(" slot");
        ir_pn(ir_k[i]);
        if ir_b[i] != 0 {
            ir_ps(" + ");
            ir_pn(ir_b[i]);
        }
    } else if op == IR_ADDR_GLOBAL {
        ir_pc(' ');
        ir_pn(ir_k[i]);
    } else if op == IR_ADDR_FUNC {
        ir_pc(' ');
        ir_ps(@ir_name + ir_k[i] * 64);
    } else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        ir_pc(' ');
        if op == IR_CALL {
            ir_ps(@ir_name + ir_k[i] * 64);
        } else {
            ir_pv(ir_a[i]);
        }
        ir_pc('(');
        int k = 0;
        while k < ir_ac[i] {
            if k > 0 { ir_ps(", "); }
            ir_pv(ir_args[ir_as[i] + k]);
            k += 1;
        }
        ir_pc(')');
    } else if op == IR_JMP {
        ir_ps(" B");
        ir_pn(ir_t1[i]);
    } else if op == IR_BR || op == IR_FBR {
        ir_pc('.');
        ir_ps(ir_ccname(ir_k[i]));
        ir_pc(' ');
        ir_pv(ir_a[i]);
        ir_ps(", ");
        ir_pb(i);
        ir_ps(" -> B");
        ir_pn(ir_t1[i]);
        ir_ps(", B");
        ir_pn(ir_t2[i]);
    } else if op == IR_RET {
        if ir_a[i] != 0 {
            ir_pc(' ');
            ir_pv(ir_a[i]);
        }
    } else if op == IR_TRAP {
    } else {
        // the arithmetic: a, b
        ir_pc(' ');
        ir_pv(ir_a[i]);
        ir_ps(", ");
        ir_pb(i);
    }
    ir_pc(10);
}

// the whole function as text in ir_pbuf (ir_plen bytes)
void ir_print() {
    ir_plen = 0;
    ir_ps("function ");
    ir_ps(@ir_fname);
    ir_ps("  (");
    ir_pn(ir_nb);
    ir_ps(" blocks, ");
    ir_pn(ir_n);
    ir_ps(" instructions, ");
    ir_pn(ir_nv - 1);
    ir_ps(" vregs, ");
    ir_pn(ir_nslots);
    ir_ps(" slots)\n");
    int b = 0;
    while b < ir_nb {
        ir_ps("  B");
        ir_pn(b);
        if ir_blab[b] >= 0 {
            ir_ps("  (L");
            ir_pn(ir_blab[b]);
            ir_pc(')');
        }
        ir_ps(":\n");
        int i = ir_bs[b];
        while i < ir_be[b] {
            ir_print_instr(i);
            i += 1;
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- the checker

char ir_err[200];

// does the instruction use the vreg v as an operand? (for the checker)
bool ir_uses_b(int op) {
    return op >= IR_ADD && op <= IR_MULHS || op == IR_SETCC || op == IR_FSETCC || op == IR_BR || op == IR_FBR || op == IR_STORE || (op >= IR_FADD && op <= IR_FDIV);
}

// 1 if the function is well made, else 0 and the message in ir_err
int ir_check() {
    ir_err[0] = 0;
    if ir_nb == 0 {
        str_copy(@ir_err, "no blocks", 200);
        return 0;
    }
    int b = 0;
    while b < ir_nb {
        if ir_be[b] <= ir_bs[b] {
            str_copy(@ir_err, "a block has no instructions", 200);
            return 0;
        }
        int i = ir_bs[b];
        while i < ir_be[b] {
            int op = ir_op[i];
            bool last = i == ir_be[b] - 1;
            if ir_is_term(op) && !last {
                str_copy(@ir_err, "a jump or return in the middle of a block", 200);
                return 0;
            }
            if !ir_is_term(op) && last {
                str_copy(@ir_err, "a block does not end with a jump or a return", 200);
                return 0;
            }
            if ir_d[i] < 0 || ir_d[i] >= ir_nv || ir_a[i] < 0 || ir_a[i] >= ir_nv {
                str_copy(@ir_err, "a vreg that does not exist", 200);
                return 0;
            }
            if ir_uses_b(op) && ir_bi[i] == 0 && (ir_b[i] < 0 || ir_b[i] >= ir_nv) {
                str_copy(@ir_err, "a vreg that does not exist (second operand)", 200);
                return 0;
            }
            if op == IR_JMP || op == IR_BR || op == IR_FBR {
                if ir_t1[i] < 0 || ir_t1[i] >= ir_nb {
                    str_copy(@ir_err, "a jump to a block that does not exist", 200);
                    return 0;
                }
                if op != IR_JMP && (ir_t2[i] < 0 || ir_t2[i] >= ir_nb) {
                    str_copy(@ir_err, "a jump to a block that does not exist", 200);
                    return 0;
                }
            }
            // the class of the operands: a double operation works on doubles, a whole number operation on whole numbers
            int ca = ir_vcls[ir_a[i]];
            if ir_a[i] != 0 {
                if (op >= IR_FADD && op <= IR_FFLOOR && ca != 1) || (op >= IR_ADD && op <= IR_MULHS && ca != 0) {
                    str_copy(@ir_err, "an operand of the wrong class", 200);
                    return 0;
                }
            }
            i += 1;
        }
        b += 1;
    }
    return 1;
}

// ---------------------------------------------------------------------------------------------- a self test (jcmp -irtest)

// builds  int sum(int n) { int s = 0; for i in 0..n { s = s + i; } return s; }  and a small function with doubles, checks and prints them
void ir_selftest() {
    ir_reset("sum");
    int b0 = ir_new_block(0 - 1);
    ir_set_block(b0);
    int n = ir_vreg(0);
    int s = ir_vreg(0);
    int i = ir_vreg(0);
    ir_add(IR_PARAM, n, 0, 0, 0, 0);
    ir_add(IR_CONST, s, 0, 0, 0, 0);
    ir_add(IR_CONST, i, 0, 0, 0, 0);
    int j0 = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    int b1 = ir_new_block(0 - 1);
    ir_set_block(b1);
    int br = ir_add(IR_BR, 0, i, n, 0, IR_LT);
    int b2 = ir_new_block(0 - 1);
    ir_set_block(b2);
    ir_add(IR_ADD, s, s, i, 0, 0);
    ir_add(IR_ADD, i, i, 1, 1, 0);
    int j2 = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    int b3 = ir_new_block(0 - 1);
    ir_set_block(b3);
    ir_add(IR_RET, 0, s, 0, 0, 0);
    ir_t1[j0] = b1;
    ir_t1[br] = b2;
    ir_t2[br] = b3;
    ir_t1[j2] = b1;
    if ir_check() == 0 {
        write_err("irtest: ");
        write_err(@ir_err);
        write_err("\n");
        syscall(93, 1);
    }
    ir_print();
    syscall(64, 1, @ir_pbuf, ir_plen);
    // double area(ptr p) { return p[0] * p[1]; }   with a call
    ir_reset("area");
    int c0 = ir_new_block(0 - 1);
    ir_set_block(c0);
    int p = ir_vreg(0);
    int x = ir_vreg(1);
    int y = ir_vreg(1);
    int r = ir_vreg(1);
    int q = ir_vreg(0);
    ir_add(IR_PARAM, p, 0, 0, 0, 0);
    int ld1 = ir_add(IR_LOAD, x, p, 0, 0, 0);
    ir_w[ld1] = 8;
    int ld2 = ir_add(IR_LOAD, y, p, 0, 0, 8);
    ir_w[ld2] = 8;
    ir_add(IR_FMUL, r, x, y, 0, 0);
    ir_add(IR_ADDR_GLOBAL, q, 0, 0, 0, 4096);
    int st = ir_add(IR_STORE, 0, q, r, 0, 16);
    ir_w[st] = 8;
    int cl = ir_add(IR_CALL, ir_vreg(0), 0, 0, 0, ir_name_index("print_f64"));
    int args[2];
    args[0] = r;
    ir_set_args(cl, 1, @args);
    ir_add(IR_RET, 0, r, 0, 0, 0);
    if ir_check() == 0 {
        write_err("irtest: ");
        write_err(@ir_err);
        write_err("\n");
        syscall(93, 1);
    }
    ir_print();
    syscall(64, 1, @ir_pbuf, ir_plen);
}
