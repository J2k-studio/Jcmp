// A1b: the tree of a function body lowered straight to the IR (design 10, 8.1; hidden switch -ast). The functions that use only `int`,
// `bool` and `double` parameters, locals and globals, arithmetic, comparisons, casts between int and double, && || !, if / while /
// for a..b, break, continue, return and calls of such functions are built from the tree; everything else keeps the text path (the
// function is lifted from its text as before). The frame layout that the tree computes is compared with the hint line of the text
// parser; when they differ the function is lifted from its text.
//
// How the values are kept (as the text path does): a whole number in v1 (x0), a double in f32 (d0); a second operand in v2 / f33; in
// the frame and in the arguments a double is its 64 bits (a whole number register, f2bits / bits2f at the edge).

#define AT_MAX 131072
#define AT_FUNCS 4096
int at_kind[AT_MAX];
int at_a[AT_MAX];
int at_b[AT_MAX];
int at_c[AT_MAX];
int at_val[AT_MAX];
int at_nx[AT_MAX];
int at_ty[AT_MAX];
int at_n;
char at_name[262144];            // AT_FUNCS x 64
int at_root[AT_FUNCS];
int at_fidx[AT_FUNCS];           // the function number of the parser (fname, fnpar ...)
int at_nfn;
int ast_lower_used;              // the functions that were built from the tree
int ast_lower_tried;
int ast_lower_report;            // -ast2: a line for every function that was tried

// ---------------------------------------------------------------- is the body in the subset?
// the type of a node: kind 0 (scalar) and base 8 (int), 3 (bool) or 7 (double)
// the width codes of the elements that are handled: 8 int, 7 double, 1 i8, 2 char, 4 i32 (the narrow ones are read and written with
// their own width, as the text path does)
bool as1_el(int b) {
    return b == 8 || b == 7 || b == 1 || b == 2 || b == 4;
}

// bytes of one value of the width code, and the width that a load uses (negative: signed)
int as1_bytes(int b) {
    if b == 1 || b == 2 { return 1; }
    if b == 4 { return 4; }
    return 8;
}

int as1_lw(int b) {
    if b == 1 { return 0 - 1; }
    if b == 4 { return 0 - 4; }
    return as1_bytes(b);
}

bool as1_scalar(int t) {
    if t / 65536 != 0 { return false; }
    int b = t % 65536;
    return b == 3 || as1_el(b);
}

// a pointer to a whole number or a double
bool as1_ptr(int t) {
    if t / 65536 != 1 { return false; }
    int b = t % 65536;
    return as1_el(b);
}

// a fixed array of whole numbers or doubles
bool as1_arr(int t) {
    if t / 65536 != 2 { return false; }
    int b = t % 65536;
    return as1_el(b);
}

bool as1_val(int t) {
    return as1_scalar(t) || as1_ptr(t);
}

bool as1_dbl(int t) {
    return t / 65536 == 0 && t % 65536 == 7;
}

// the type id of a parameter or a result (fptid / fret): 0 a whole number, 1 bool, 91 double
bool as1_tid(int t) {
    return t == 0 || t == 1 || t == 91;
}

bool as1_arith(int ao) {
    return ao == AO_ADD || ao == AO_SUB || ao == AO_MUL || ao == AO_DIV;
}

// the base of an index: an array or a pointer, a local or a global
bool as1_base(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int t = ast_ty[n];
    if k == AK_VAR { return as1_ptr(t) || as1_arr(t); }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 || gdyn[gi] != 0 { return false; }
        if gkind[gi] == 1 { return as1_el(gelem[gi]) && gptr[gi] == 0 && gnd[gi] == 1 && as1_arr(t); }
        // a pointer variable: gptr is the width code of what it points to
        return gkind[gi] == 0 && gelem[gi] == 8 && as1_el(gptr[gi]) && as1_ptr(t) && t % 65536 == gptr[gi];
    }
    return false;
}

// the calls that the text path turns into an instruction of the CPU (Bit::, Cpu::, Cache::, Mem::barrier*, Atomic::): no call is made
bool as1_prefix(char^ nm, char^ pre) {
    int i = 0;
    while pre[i] != 0 {
        if nm[i] != pre[i] { return false; }
        i += 1;
    }
    return true;
}

bool as1_special(char^ nm) {
    if as1_prefix(nm, "Bit__") || as1_prefix(nm, "Cpu__") || as1_prefix(nm, "Cache__") || as1_prefix(nm, "Atomic__") { return true; }
    if as1_prefix(nm, "Mem__bar") { return true; }
    return nm[0] == '_' && nm[1] == '_';
}

// a call of a function with parameters and a result of whole numbers, pointers, bools or doubles (a void function only as a statement)
bool as1_call(int n) {
    int fi = ast_val[n];
    if fi < 0 || fi >= fcount || fnpar[fi] > 8 || fretdyn[fi] != 0 { return false; }
    if fvoid[fi] == 0 && !as1_tid(fret[fi]) { return false; }
    if fcharret[fi] != 0 || farr[fi] != 0 || as1_special(@fname + fi * 64) { return false; }
    int a2 = ast_a[n];
    int pk = 0;
    while a2 != 0 {
        if pk >= fnpar[fi] || !as1_expr(a2) { return false; }
        int pt = fptid[fi * 8 + pk];
        if !as1_tid(pt) { return false; }
        // a double goes to a double parameter, a whole number (or a pointer) to a whole number one
        if (pt == 91) != as1_dbl(ast_ty[a2]) { return false; }
        pk += 1;
        a2 = ast_nx[a2];
    }
    return pk == fnpar[fi];
}

bool as1_expr(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int ty = ast_ty[n];
    if !as1_val(ty) { return false; }
    if k == AK_NUM { return as1_scalar(ty); }
    if k == AK_FNUM { return true; }
    if k == AK_VAR { return as1_scalar(ty) || as1_ptr(ty); }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 { return false; }
        if as1_ptr(ty) { return as1_base(n); }
        return gkind[gi] == 0 && (as1_el(gelem[gi]) || gelem[gi] == 3) && gptr[gi] == 0 && gdyn[gi] == 0 && as1_tid(gtid[gi]);
    }
    if k == AK_INDEX {
        if opt_debug == 1 || ast_c[n] != 0 || !as1_scalar(ty) { return false; }
        int ix = ast_b[n];
        return as1_base(ast_a[n]) && as1_expr(ix) && !as1_dbl(ast_ty[ix]) && as1_scalar(ast_ty[ix]);
    }
    if k == AK_DEREF {
        if opt_debug == 1 || !as1_scalar(ty) { return false; }
        return as1_ptr(ast_ty[ast_a[n]]) && as1_expr(ast_a[n]);
    }
    if k == AK_ADDR {
        if !as1_ptr(ty) { return false; }
        int t = ast_a[n];
        int tk = ast_kind[t];
        if tk == AK_VAR || tk == AK_GVAR {
            // a scalar or an array of the width of the pointer
            int tt = ast_ty[t];
            if tk == AK_VAR { return (as1_scalar(tt) && !(tt % 65536 == 3)) || as1_arr(tt); }
            int gi2 = ast_val[t];
            if gi2 < 0 || gdyn[gi2] != 0 || gptr[gi2] != 0 || !as1_el(gelem[gi2]) { return false; }
            return (gkind[gi2] == 0 && as1_scalar(tt) && as1_tid(gtid[gi2])) || (gkind[gi2] == 1 && gnd[gi2] == 1);
        }
        if tk == AK_INDEX { return as1_expr(t); }
        return false;
    }
    if k == AK_BIN {
        int a = ast_a[n];
        int b = ast_b[n];
        if !as1_expr(a) || !as1_expr(b) { return false; }
        int ao = ast_val[n];
        bool any_p = as1_ptr(ast_ty[a]) || as1_ptr(ast_ty[b]);
        if any_p {
            // pointers are only compared for equality (with a pointer or a whole number)
            return (ao == AO_EQ || ao == AO_NE) && !as1_dbl(ast_ty[a]) && !as1_dbl(ast_ty[b]);
        }
        bool any_d = as1_dbl(ast_ty[a]) || as1_dbl(ast_ty[b]);
        if any_d {
            // a double with + - * / and the comparisons (the other operand may be a whole number)
            return as1_arith(ao) || (ao >= AO_LT && ao <= AO_NE);
        }
        return true;
    }
    if k == AK_NEG { return as1_scalar(ast_ty[ast_a[n]]) && as1_expr(ast_a[n]); }
    if k == AK_NOT { return as1_expr(ast_a[n]) && !as1_dbl(ast_ty[ast_a[n]]); }
    if k == AK_CAST {
        int tc = ast_val[n];
        return (tc == 7 || as1_el(tc)) && as1_scalar(ast_ty[ast_a[n]]) && as1_expr(ast_a[n]);
    }
    if k == AK_CALL { return as1_call(n); }
    return false;
}

bool as1_target(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    if !as1_val(ast_ty[n]) { return false; }
    if k == AK_VAR { return true; }
    return (k == AK_GVAR || k == AK_INDEX || k == AK_DEREF) && as1_expr(n);
}

bool as1_stmt(int n) {
    if n == 0 { return true; }
    int k = ast_kind[n];
    if k == AK_BLOCK {
        int s = ast_a[n];
        while s != 0 {
            if !as1_stmt(s) { return false; }
            s = ast_nx[s];
        }
        return true;
    }
    if k == AK_DECL {
        int dt = ast_ty[n];
        if as1_arr(dt) {
            // a fixed array of one dimension with a number as its size, no initial values
            return ast_a[n] == 0 && ast_b[n] > 0 && ast_b[n] < 65536;
        }
        if as1_ptr(dt) {
            if ast_a[n] == 0 { return true; }
            int pv = ast_a[n];
            return as1_expr(pv) && (as1_ptr(ast_ty[pv]) || (ast_kind[pv] == AK_NUM && ast_val[pv] == 0));
        }
        if !as1_scalar(dt) { return false; }
        if ast_a[n] == 0 { return true; }
        // the value has the type of the variable
        return as1_expr(ast_a[n]) && as1_val(ast_ty[ast_a[n]]) && !as1_ptr(ast_ty[ast_a[n]]) && as1_dbl(ast_ty[ast_a[n]]) == as1_dbl(dt);
    }
    if k == AK_ASSIGN {
        int t = ast_c[n];
        if !as1_target(t) || !as1_expr(ast_a[n]) || ast_b[n] < 0 { return false; }
        bool td = as1_dbl(ast_ty[t]);
        int opc = ast_b[n];
        if as1_ptr(ast_ty[t]) {
            // a pointer gets a pointer of the same kind or 0
            int pv2 = ast_a[n];
            return opc == 0 && as1_expr(pv2) && (as1_ptr(ast_ty[pv2]) || (ast_kind[pv2] == AK_NUM && ast_val[pv2] == 0));
        }
        if as1_ptr(ast_ty[ast_a[n]]) { return false; }
        if td { return (opc == 0 || as1_arith(opc)) && as1_dbl(ast_ty[ast_a[n]]) == (td || true); }
        return !as1_dbl(ast_ty[ast_a[n]]);
    }
    if k == AK_INCDEC { return as1_target(ast_a[n]) && as1_scalar(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_a[n]]); }
    if k == AK_EXPR { return ast_kind[ast_a[n]] == AK_CALL && as1_call(ast_a[n]); }
    if k == AK_IF { return as1_expr(ast_a[n]) && as1_stmt(ast_b[n]) && as1_stmt(ast_c[n]); }
    if k == AK_WHILE { return ast_val[n] == 0 && ast_c[n] == 0 && as1_expr(ast_a[n]) && as1_stmt(ast_b[n]); }
    if k == AK_FOR { return ast_b[n] != 0 && as1_expr(ast_a[n]) && as1_expr(ast_b[n]) && !as1_dbl(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_b[n]]) && as1_stmt(ast_c[n]); }
    if k == AK_RET { return ast_a[n] == 0 || as1_expr(ast_a[n]); }
    if k == AK_BREAK || k == AK_CONT { return true; }
    return false;
}

// the node fields that hold nodes, by kind: bit 0 a, bit 1 b, bit 2 c
int at_fields(int k) {
    if k == AK_BIN || k == AK_WHILE || k == AK_INDEX { return 3; }
    if k == AK_DEREF || k == AK_ADDR { return 1; }
    if k == AK_NEG || k == AK_NOT || k == AK_CALL || k == AK_BLOCK || k == AK_DECL || k == AK_EXPR || k == AK_RET || k == AK_INCDEC || k == AK_CAST { return 1; }
    if k == AK_ASSIGN { return 5; }
    if k == AK_IF || k == AK_FOR { return 7; }
    return 0;
}

// called at the end of ast_probe for a body that is in the tree's subset: keep it when it is in the subset of the lowering
void at_store(int f_idx) {
    if ast_lower_on == 0 || at_nfn >= AT_FUNCS || at_n + ast_n + 2 >= AT_MAX { return; }
    // the function: parameters of whole numbers, bool or double, a result of those or nothing
    if fnpar[f_idx] > 8 || fretdyn[f_idx] != 0 || fcharret[f_idx] != 0 || farr[f_idx] != 0 { return; }
    int pk = 0;
    while pk < fnpar[f_idx] {
        if !as1_tid(fptid[f_idx * 8 + pk]) { return; }
        pk += 1;
    }
    if fvoid[f_idx] == 0 && !as1_tid(fret[f_idx]) { return; }
    if !as1_stmt(ast_root) { return; }
    int base = at_n;
    int i = 1;
    while i <= ast_n {
        int k = ast_kind[i];
        int fl = at_fields(k);
        at_kind[base + i] = k;
        at_a[base + i] = ast_a[i];
        at_b[base + i] = ast_b[i];
        at_c[base + i] = ast_c[i];
        if (fl & 1) != 0 && ast_a[i] != 0 { at_a[base + i] = ast_a[i] + base; }
        if (fl & 2) != 0 && ast_b[i] != 0 { at_b[base + i] = ast_b[i] + base; }
        if (fl & 4) != 0 && ast_c[i] != 0 { at_c[base + i] = ast_c[i] + base; }
        at_val[base + i] = ast_val[i];
        at_ty[base + i] = ast_ty[i];
        at_nx[base + i] = 0;
        if ast_nx[i] != 0 { at_nx[base + i] = ast_nx[i] + base; }
        i += 1;
    }
    at_n = base + ast_n + 1;
    str_copy(@at_name + at_nfn * 64, @fname + f_idx * 64, 64);
    at_root[at_nfn] = ast_root + base;
    at_fidx[at_nfn] = f_idx;
    at_nfn += 1;
}

// ---------------------------------------------------------------- the lowering
#define GL_MAXP 4096
int gl_pinstr[GL_MAXP];          // the jumps whose targets are label numbers until the end
int gl_np;
int gl_lblock[GL_MAXP];          // label -> block
int gl_nlab;
int gl_term;                     // 1: the current block has its last instruction
int gl_depth;                    // the cells in use below the frame pointer
int gl_off[1024];                // the unique number of a local -> its offset in the frame
int gl_nslot;                    // the next offset to give
int gl_bsl[AT_MAX];              // for loops: the offset of the hidden bound, by the node
int gl_nz[8];                    // the local variables known to be not 0 here (after `while b != 0 {`); cleared at every join
int gl_nzn;
int gl_fail;
int gl_why;                      // 1: the frame of the tree is not the frame of the parser
int gl_ret;                      // the label of the return
int gl_retd;                     // 1: the function gives a double
int gl_brk[32];
int gl_cnt[32];
int gl_loops;
int gl_args[8];

int gl_label() {
    if gl_nlab >= GL_MAXP { gl_fail = 1; return 0; }
    gl_lblock[gl_nlab] = 0 - 1;
    gl_nlab += 1;
    return gl_nlab - 1;
}

void gl_note(int ins) {
    if gl_np >= GL_MAXP { gl_fail = 1; return; }
    gl_pinstr[gl_np] = ins;
    gl_np += 1;
}

// a block that holds the code that follows a jump (it has no label: nothing jumps there, the IR cleaning removes it)
void gl_ensure() {
    if gl_term == 1 {
        int b = ir_new_block(0 - 1);
        ir_set_block(b);
        gl_term = 0;
    }
}

void gl_jmp(int label) {
    gl_ensure();
    int j = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[j] = label;
    gl_note(j);
    gl_term = 1;
}

// the label starts a block (the block above falls into it with a jump)
void gl_place(int label) {
    gl_nzn = 0;
    if gl_term == 0 {
        int j = ir_add(IR_JMP, 0, 0, 0, 0, 0);
        ir_t1[j] = label;
        gl_note(j);
    }
    int b = ir_new_block(0 - 1);
    ir_set_block(b);
    gl_lblock[label] = b;
    gl_term = 0;
}

void gl_br(int cc, int a, int b, int bi, int lt, int lf) {
    gl_ensure();
    int e = ir_add(IR_BR, 0, a, b, bi, cc);
    ir_t1[e] = lt;
    ir_t2[e] = lf;
    gl_note(e);
    gl_term = 1;
}

void gl_fbr(int cc, int a, int b, int lt, int lf) {
    gl_ensure();
    int e = ir_add(IR_FBR, 0, a, b, 0, cc);
    ir_t1[e] = lt;
    ir_t2[e] = lf;
    gl_note(e);
    gl_term = 1;
}

void gl_load(int dst, int base, int off) {
    gl_ensure();
    int e = ir_add(IR_LOAD, dst, base, 0, 0, off);
    ir_w[e] = 8;
}

void gl_loadw(int dst, int base, int off, int w) {
    gl_ensure();
    int e = ir_add(IR_LOAD, dst, base, 0, 0, off);
    ir_w[e] = w;
}

// the width of a load of the value of the node (a narrow variable or element: its own width)
int gl_vw(int n) {
    int t = at_ty[n];
    if t / 65536 != 0 { return 8; }
    return as1_lw(t % 65536);
}

// v1 = v1 wrapped to the width code (a store into a narrow variable wraps first, as store_scalar does)
void gl_wrap(int code) {
    if code != 1 && code != 2 && code != 4 { return; }
    gl_ensure();
    int bits = 8;
    if code == 4 { bits = 32; }
    int e = ir_add(IR_EXT, 1, 1, 0, 0, bits);
    if code != 2 { ir_w[e] = 1; }
}

void gl_store(int base, int off, int val) {
    gl_ensure();
    int e = ir_add(IR_STORE, 0, base, val, 0, off);
    ir_w[e] = 8;
}

int gl_cell(int d) {
    return 0 - 8 * (d + 1);
}

int gl_cc(int ao) {
    if ao == AO_LT { return IR_LT; }
    if ao == AO_LE { return IR_LE; }
    if ao == AO_GT { return IR_GT; }
    if ao == AO_GE { return IR_GE; }
    if ao == AO_EQ { return IR_EQ; }
    return IR_NE;
}

bool gl_is_cmp(int ao) {
    return ao >= AO_LT && ao <= AO_NE;
}

bool gl_isd(int n) {
    return as1_dbl(at_ty[n]);
}

bool gl_is_nz(int n) {
    if at_kind[n] != AK_VAR { return false; }
    int i = 0;
    while i < gl_nzn {
        if gl_nz[i] == at_val[n] { return true; }
        i += 1;
    }
    return false;
}

void gl_nz_clear(int id) {
    int i = 0;
    while i < gl_nzn {
        if gl_nz[i] == id {
            gl_nz[i] = gl_nz[gl_nzn - 1];
            gl_nzn -= 1;
        } else { i += 1; }
    }
}

// the condition holds: a variable that is tested against 0 is not 0 (`b != 0`, `b > 0`, and both sides of &&)
void gl_nz_from(int c) {
    if at_kind[c] != AK_BIN { return; }
    int ao = at_val[c];
    int a = at_a[c];
    int b = at_b[c];
    if ao == AO_LAND {
        gl_nz_from(a);
        gl_nz_from(b);
        return;
    }
    if (ao == AO_NE || ao == AO_GT) && at_kind[a] == AK_VAR && at_kind[b] == AK_NUM && at_val[b] == 0 && !gl_isd(a) && gl_nzn < 8 {
        gl_nz[gl_nzn] = at_val[a];
        gl_nzn += 1;
    }
}

// the value of the node as a double in f32: a whole number is converted
void gl_expr_d(int n) {
    gl_expr(n);
    if !gl_isd(n) {
        gl_ensure();
        ir_add(IR_I2F, 32, 1, 0, 0, 0);
    }
}

// the operands of a binary operator: a in v1, b in v2
void gl_operands(int a, int b) {
    gl_expr(a);
    gl_operands_l(b);
}

// the same when the left operand is in v1 already. A number or a variable goes straight to v2; the left operand waits in a register
// (v9 ..) while the right one is worked out, when that has no call; else in a cell of the frame
int gl_rdepth;
void gl_operands_l(int b) {
    int k = at_kind[b];
    gl_ensure();
    if k == AK_NUM {
        ir_add(IR_CONST, 2, 0, 0, 0, at_val[b]);
        return;
    }
    if (k == AK_VAR || k == AK_GVAR) && !gl_isd(b) {
        if k == AK_VAR { gl_loadw(2, 30, gl_off[at_val[b]], gl_vw(b)); } else { gl_loadw(2, 29, goff[at_val[b]], gl_vw(b)); }
        return;
    }
    if gl_rdepth < 7 && !gl_has_call(b) {
        int r = 9 + gl_rdepth;
        ir_add(IR_COPY, r, 1, 0, 0, 0);
        gl_rdepth += 1;
        gl_expr(b);
        gl_rdepth -= 1;
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        ir_add(IR_COPY, 1, r, 0, 0, 0);
        return;
    }
    int c = gl_cell(gl_depth);
    gl_store(30, c, 1);
    gl_depth += 1;
    gl_expr(b);
    gl_depth -= 1;
    gl_ensure();
    ir_add(IR_COPY, 2, 1, 0, 0, 0);
    gl_load(1, 30, c);
}

// does the expression contain a call? (a call destroys the double registers d16 .. d31)
bool gl_has_call(int n) {
    if n == 0 { return false; }
    int k = at_kind[n];
    if k == AK_CALL { return true; }
    if k == AK_BIN { return gl_has_call(at_a[n]) || gl_has_call(at_b[n]); }
    if k == AK_NEG || k == AK_NOT || k == AK_CAST || k == AK_DEREF || k == AK_ADDR { return gl_has_call(at_a[n]); }
    if k == AK_INDEX { return gl_has_call(at_a[n]) || gl_has_call(at_b[n]); }
    return false;
}

// the double registers that hold the left operands while the right ones are worked out (d24 .. d29 without d27, which the
// instruction popcnt uses)
int gl_freg(int d) {
    if d == 0 { return 56; }
    if d == 1 { return 57; }
    if d == 2 { return 58; }
    if d == 3 { return 60; }
    return 61;
}

int gl_fdepth;
int gl_ra;                       // after gl_operands_d: the registers that hold the left and the right operand
int gl_rb;

// an operand that is worked out without touching f32 (a number, a variable): it goes to f33 while the left one stays in f32
bool gl_simple_d(int n) {
    int k = at_kind[n];
    return k == AK_FNUM || ((k == AK_VAR || k == AK_GVAR) && gl_isd(n));
}

// the operands of a binary operator on doubles: a in gl_ra (a double register that this keeps for it), b in f32
void gl_operands_d(int a, int b) {
    gl_expr_d(a);
    gl_operands_dl(b);
}

// the same when the left operand is in f32 already
void gl_operands_dl(int b) {
    gl_ensure();
    if gl_simple_d(b) {
        // the right operand into f33: the left one stays in f32
        if at_kind[b] == AK_FNUM {
            ir_add(IR_FCONST, 33, 0, 0, 0, float_literal_bits(at_a[b], at_b[b]));
        } else {
            if at_kind[b] == AK_VAR { gl_load(1, 30, gl_off[at_val[b]]); } else { gl_load(1, 29, goff[at_val[b]]); }
            ir_add(IR_BITS2F, 33, 1, 0, 0, 0);
        }
        gl_ra = 32;
        gl_rb = 33;
        return;
    }
    if gl_fdepth < 5 && !gl_has_call(b) {
        // the left operand waits in a double register
        int fr = gl_freg(gl_fdepth);
        ir_add(IR_COPY, fr, 32, 0, 0, 0);
        gl_fdepth += 1;
        gl_expr_d(b);
        gl_fdepth -= 1;
        gl_ensure();
        gl_ra = fr;
        gl_rb = 32;
        return;
    }
    int c = gl_cell(gl_depth);
    ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
    gl_store(30, c, 1);
    gl_depth += 1;
    gl_expr_d(b);
    gl_depth -= 1;
    gl_ensure();
    gl_load(1, 30, c);
    ir_add(IR_BITS2F, 33, 1, 0, 0, 0);
    gl_ra = 33;
    gl_rb = 32;
}

// a jump on a condition: to lt when it holds, else to lf
void gl_cond(int n, int lt, int lf) {
    int k = at_kind[n];
    if k == AK_BIN {
        int ao = at_val[n];
        if ao == AO_LAND {
            int lm = gl_label();
            gl_cond(at_a[n], lm, lf);
            gl_place(lm);
            gl_cond(at_b[n], lt, lf);
            return;
        }
        if ao == AO_LOR {
            int lm2 = gl_label();
            gl_cond(at_a[n], lt, lm2);
            gl_place(lm2);
            gl_cond(at_b[n], lt, lf);
            return;
        }
        if gl_is_cmp(ao) {
            if gl_isd(at_a[n]) || gl_isd(at_b[n]) {
                gl_operands_d(at_a[n], at_b[n]);
                gl_fbr(gl_cc(ao), gl_ra, gl_rb, lt, lf);
            } else {
                gl_operands(at_a[n], at_b[n]);
                gl_br(gl_cc(ao), 1, 2, 0, lt, lf);
            }
            return;
        }
    }
    if k == AK_NOT {
        gl_cond(at_a[n], lf, lt);
        return;
    }
    gl_expr(n);
    gl_br(IR_NE, 1, 0, 1, lt, lf);
}

void gl_call(int n) {
    int fi = at_val[n];
    int argn = 0;
    int a = at_a[n];
    int base = gl_depth;
    while a != 0 {
        gl_expr(a);
        gl_ensure();
        if gl_isd(a) { ir_add(IR_F2BITS, 1, 32, 0, 0, 0); }
        gl_store(30, gl_cell(gl_depth), 1);
        gl_depth += 1;
        argn += 1;
        a = at_nx[a];
    }
    gl_depth = base;
    int k = 0;
    while k < argn {
        gl_load(k + 1, 30, gl_cell(base + k));
        k += 1;
    }
    gl_ensure();
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(@fname + fi * 64));
    int r = 0;
    while r < argn {
        gl_args[r] = r + 1;
        r += 1;
    }
    ir_set_args(e, argn, @gl_args);
    if fret[fi] == 91 { ir_add(IR_BITS2F, 32, 1, 0, 0, 0); }
}

// v1 = v1 / d or v1 % d for a constant d >= 1 (signed), as the text path does (emit_div_const): a shift for a power of two, else the
// high half of the product with a magic number
void gl_divconst(int d, bool is_mod) {
    gl_ensure();
    if d == 1 {
        if is_mod { ir_add(IR_CONST, 1, 0, 0, 0, 0); }
        return;
    }
    if (d & (d - 1)) == 0 {
        int k = 0;
        while (1 << k) < d { k += 1; }
        ir_add(IR_ASHR, 2, 1, 63, 1, 0);
        ir_add(IR_LSHR, 2, 2, 64 - k, 1, 0);
        ir_add(IR_ADD, 2, 1, 2, 0, 0);
        ir_add(IR_ASHR, 2, 2, k, 1, 0);
        if is_mod {
            ir_add(IR_SHL, 2, 2, k, 1, 0);
            ir_add(IR_SUB, 1, 1, 2, 0, 0);
        } else {
            ir_add(IR_COPY, 1, 2, 0, 0, 0);
        }
        return;
    }
    div_magic(d);
    int m = div_mg_m;
    int sh = div_mg_s;
    ir_add(IR_CONST, 4, 0, 0, 0, m);
    ir_add(IR_MULHS, 2, 1, 4, 0, 0);
    if m < 0 { ir_add(IR_ADD, 2, 2, 1, 0, 0); }
    if sh > 0 { ir_add(IR_ASHR, 2, 2, sh, 1, 0); }
    ir_add(IR_LSHR, 3, 2, 63, 1, 0);
    ir_add(IR_ADD, 2, 2, 3, 0, 0);
    if is_mod {
        ir_add(IR_CONST, 3, 0, 0, 0, d);
        ir_add(IR_MUL, 3, 2, 3, 0, 0);
        ir_add(IR_SUB, 1, 1, 3, 0, 0);
    } else {
        ir_add(IR_COPY, 1, 2, 0, 0, 0);
    }
}

// a divisor that is a constant of 1 .. 2^31 - 1 (the text path does the division without the divide instruction)
bool gl_const_div(int b) {
    return at_kind[b] == AK_NUM && at_val[b] >= 1 && at_val[b] < 2147483648;
}

// v1 / v2 or v1 % v2: the stop for a divisor of 0 (unless it is known not to be 0), then the divide instruction
void gl_divide(int ao, bool known_nz) {
    if !known_nz {
        int lok = gl_label();
        int lz = gl_label();
        gl_br(IR_NE, 2, 0, 1, lok, lz);
        gl_place(lz);
        int ce = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("j2k_divzero"));
        ir_set_args(ce, 0, @gl_args);
        ir_add(IR_TRAP, 0, 0, 0, 0, 0);
        gl_term = 1;
        gl_place(lok);
    }
    if ao == AO_DIV {
        ir_add(IR_SDIV, 1, 1, 2, 0, 0);
    } else {
        ir_add(IR_SDIV, 3, 1, 2, 0, 0);
        ir_add(IR_MUL, 3, 3, 2, 0, 0);
        ir_add(IR_SUB, 1, 1, 3, 0, 0);
    }
}

// f32 = (the left operand) op f32
void gl_farith(int ao) {
    gl_ensure();
    int ra = gl_ra;
    int rb = gl_rb;
    if ao == AO_ADD { ir_add(IR_FADD, 32, ra, rb, 0, 0); }
    else if ao == AO_SUB { ir_add(IR_FSUB, 32, ra, rb, 0, 0); }
    else if ao == AO_MUL { ir_add(IR_FMUL, 32, ra, rb, 0, 0); }
    else if ao == AO_DIV { ir_add(IR_FDIV, 32, ra, rb, 0, 0); }
    else { gl_fail = 1; }
}

// v1 = v1 op v2 (whole numbers; / and % through gl_divide)
void gl_iarith(int ao, bool nzk) {
    gl_ensure();
    if ao == AO_ADD { ir_add(IR_ADD, 1, 1, 2, 0, 0); }
    else if ao == AO_SUB { ir_add(IR_SUB, 1, 1, 2, 0, 0); }
    else if ao == AO_MUL { ir_add(IR_MUL, 1, 1, 2, 0, 0); }
    else if ao == AO_AND { ir_add(IR_AND, 1, 1, 2, 0, 0); }
    else if ao == AO_OR { ir_add(IR_OR, 1, 1, 2, 0, 0); }
    else if ao == AO_XOR { ir_add(IR_XOR, 1, 1, 2, 0, 0); }
    else if ao == AO_SHL { ir_add(IR_SHL, 1, 1, 2, 0, 0); }
    else if ao == AO_SHR { ir_add(IR_ASHR, 1, 1, 2, 0, 0); }
    else if ao == AO_DIV || ao == AO_MOD { gl_divide(ao, nzk); }
    else { gl_fail = 1; }
}

// the address of an element (a[i], p[i]) or of what a pointer points to (p^): the base register and the offset go to gl_ab and
// gl_ao (the base is v30 or v29 for an array with a number as index, else v1). May use v1 and v2.
int gl_ab;
int gl_ao;

void gl_addr(int n) {
    gl_ensure();
    int k = at_kind[n];
    if k == AK_DEREF {
        gl_expr(at_a[n]);
        gl_ab = 1;
        gl_ao = 0;
        return;
    }
    int b = at_a[n];
    int ix = at_b[n];
    bool is_arr = as1_arr(at_ty[b]);
    int bk = at_kind[b];
    int boff = 0;
    int bvr = 30;
    if bk == AK_VAR { boff = gl_off[at_val[b]]; } else { boff = goff[at_val[b]]; bvr = 29; }
    int es = as1_bytes(at_ty[n] % 65536);
    int esh = 3;
    if es == 4 { esh = 2; }
    if es == 1 { esh = 0; }
    if at_kind[ix] == AK_NUM && at_val[ix] >= 0 && at_val[ix] < 4096 {
        int eo = at_val[ix] * es;
        if is_arr {
            gl_ab = bvr;
            gl_ao = boff + eo;
        } else {
            gl_load(1, bvr, boff);
            gl_ab = 1;
            gl_ao = eo;
        }
        return;
    }
    gl_expr(ix);
    gl_ensure();
    if esh != 0 { ir_add(IR_SHL, 1, 1, esh, 1, 0); }
    if is_arr && bvr == 29 {
        // a global array: the offset of the array goes to the load (`add x0, x28, x1, lsl #3` then `ldr x0, [x0, #off]`)
        ir_add(IR_ADD, 1, 1, 29, 0, 0);
        gl_ab = 1;
        gl_ao = boff;
        return;
    }
    if is_arr {
        ir_add(IR_ADD, 2, bvr, boff, 1, 0);
    } else {
        gl_load(2, bvr, boff);
    }
    ir_add(IR_ADD, 1, 1, 2, 0, 0);
    gl_ab = 1;
    gl_ao = 0;
}

// v1 = the address of a variable or an element (@x, @a, @a[i])
void gl_addr_of(int t) {
    gl_ensure();
    int tk = at_kind[t];
    if tk == AK_VAR {
        ir_add(IR_ADD, 1, 30, gl_off[at_val[t]], 1, 0);
    } else if tk == AK_GVAR {
        ir_add(IR_ADD, 1, 29, goff[at_val[t]], 1, 0);
    } else {
        gl_addr(t);
        gl_ensure();
        if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
    }
}

// target op= value, target = value or target += step for an element or a pointer's target. v1 / f32 hold the value at the end of
// the computation (the store goes last).
void gl_assign_mem(int target, int value, int ao, int step) {
    gl_addr(target);
    bool fixed = gl_ab == 30 || gl_ab == 29;
    int fb = gl_ab;
    int fo = gl_ao;
    // the address waits in a register (v9 ..) when the value has no call, else in a cell
    int ar = 0;
    if !fixed && gl_rdepth < 7 && (value == 0 || !gl_has_call(value)) { ar = 9 + gl_rdepth; }
    int c = gl_cell(gl_depth);
    if !fixed {
        if ar != 0 {
            ir_add(IR_COPY, ar, 1, 0, 0, 0);
            gl_rdepth += 1;
        } else {
            gl_store(30, c, 1);
            gl_depth += 1;
        }
    }
    bool td = gl_isd(target);
    if ao == 0 && step == 0 {
        if td { gl_expr_d(value); } else { gl_expr(value); }
        gl_ensure();
    } else {
        // the value of the target now
        gl_ensure();
        if !fixed {
            if ar != 0 { ir_add(IR_COPY, 2, ar, 0, 0, 0); } else { gl_load(2, 30, c); }
            fb = 2;
        }
        int le = ir_add(IR_LOAD, 1, fb, 0, 0, fo);
        ir_w[le] = gl_vw(target);
        if step != 0 {
            ir_add(IR_ADD, 1, 1, step, 1, 0);
        } else if td {
            ir_add(IR_BITS2F, 32, 1, 0, 0, 0);
            gl_operands_dl(value);
            gl_farith(ao);
        } else if (ao == AO_DIV || ao == AO_MOD) && gl_const_div(value) {
            gl_divconst(at_val[value], ao == AO_MOD);
        } else {
            bool nzk = gl_is_nz(value);
            gl_operands_l(value);
            gl_iarith(ao, nzk);
        }
    }
    if !fixed {
        if ar != 0 { gl_rdepth -= 1; } else { gl_depth -= 1; }
    }
    gl_ensure();
    if td { ir_add(IR_F2BITS, 1, 32, 0, 0, 0); }
    if !fixed {
        if ar != 0 { ir_add(IR_COPY, 2, ar, 0, 0, 0); } else { gl_load(2, 30, c); }
        fb = 2;
    }
    gl_ensure();
    int se = ir_add(IR_STORE, 0, fb, 1, 0, fo);
    ir_w[se] = as1_bytes(at_ty[target] % 65536);
}

void gl_expr(int n) {
    int k = at_kind[n];
    gl_ensure();
    if k == AK_NUM {
        ir_add(IR_CONST, 1, 0, 0, 0, at_val[n]);
        return;
    }
    if k == AK_FNUM {
        ir_add(IR_FCONST, 32, 0, 0, 0, float_literal_bits(at_a[n], at_b[n]));
        return;
    }
    if k == AK_VAR || k == AK_GVAR {
        if k == AK_VAR { gl_loadw(1, 30, gl_off[at_val[n]], gl_vw(n)); } else { gl_loadw(1, 29, goff[at_val[n]], gl_vw(n)); }
        if gl_isd(n) { ir_add(IR_BITS2F, 32, 1, 0, 0, 0); }
        return;
    }
    if k == AK_INDEX || k == AK_DEREF {
        gl_addr(n);
        gl_ensure();
        int le = ir_add(IR_LOAD, 1, gl_ab, 0, 0, gl_ao);
        ir_w[le] = gl_vw(n);
        if gl_isd(n) { ir_add(IR_BITS2F, 32, 1, 0, 0, 0); }
        return;
    }
    if k == AK_ADDR {
        gl_addr_of(at_a[n]);
        return;
    }
    if k == AK_NEG {
        gl_expr(at_a[n]);
        gl_ensure();
        if gl_isd(n) { ir_add(IR_FNEG, 32, 32, 0, 0, 0); } else { ir_add(IR_NEG, 1, 1, 0, 0, 0); }
        return;
    }
    if k == AK_NOT {
        gl_expr(at_a[n]);
        gl_ensure();
        ir_add(IR_SETCC, 1, 1, 0, 1, IR_EQ);
        return;
    }
    if k == AK_CAST {
        int src = at_a[n];
        if at_val[n] == 7 {
            gl_expr_d(src);
        } else {
            gl_expr(src);
            if gl_isd(src) {
                gl_ensure();
                ir_add(IR_F2I, 1, 32, 0, 0, 0);
            }
            gl_wrap(at_val[n]);
        }
        return;
    }
    if k == AK_CALL {
        gl_call(n);
        return;
    }
    if k == AK_BIN {
        int ao = at_val[n];
        int a = at_a[n];
        int b = at_b[n];
        if ao == AO_LAND || ao == AO_LOR {
            int lt = gl_label();
            int lf = gl_label();
            int le = gl_label();
            gl_cond(n, lt, lf);
            gl_place(lt);
            ir_add(IR_CONST, 1, 0, 0, 0, 1);
            gl_jmp(le);
            gl_place(lf);
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
            gl_place(le);
            return;
        }
        if gl_isd(a) || gl_isd(b) {
            gl_operands_d(a, b);
            gl_ensure();
            if gl_is_cmp(ao) { ir_add(IR_FSETCC, 1, gl_ra, gl_rb, 0, gl_cc(ao)); }
            else { gl_farith(ao); }
            return;
        }
        if (ao == AO_DIV || ao == AO_MOD) && gl_const_div(b) {
            gl_expr(a);
            gl_divconst(at_val[b], ao == AO_MOD);
            return;
        }
        bool nzk = gl_is_nz(b);
        gl_operands(a, b);
        gl_ensure();
        if gl_is_cmp(ao) { ir_add(IR_SETCC, 1, 1, 2, 0, gl_cc(ao)); }
        else { gl_iarith(ao, nzk); }
        return;
    }
    gl_fail = 1;
}

void gl_block_list(int s) {
    while s != 0 {
        gl_stmt(s);
        s = at_nx[s];
    }
}

// the value in v1 / f32 goes to the variable (a local or a global)
void gl_store_var(int target) {
    gl_ensure();
    if gl_isd(target) { ir_add(IR_F2BITS, 1, 32, 0, 0, 0); }
    if at_ty[target] / 65536 == 0 { gl_wrap(at_ty[target] % 65536); }
    if at_kind[target] == AK_VAR {
        gl_store(30, gl_off[at_val[target]], 1);
        gl_nz_clear(at_val[target]);
    } else {
        gl_store(29, goff[at_val[target]], 1);
    }
}

// an assignment `target op= value` or `target = value`
void gl_assign(int target, int value, int ao) {
    bool td = gl_isd(target);
    if ao == 0 {
        if td { gl_expr_d(value); } else { gl_expr(value); }
    } else if td {
        gl_operands_d(target, value);
        gl_farith(ao);
    } else if (ao == AO_DIV || ao == AO_MOD) && gl_const_div(value) {
        gl_expr(target);
        gl_divconst(at_val[value], ao == AO_MOD);
    } else {
        // target op value: the same as the binary operator (no node is made: the operands by hand)
        bool nzk = gl_is_nz(value);
        gl_operands(target, value);
        gl_iarith(ao, nzk);
    }
    gl_store_var(target);
}

void gl_stmt(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if k == AK_BLOCK {
        gl_block_list(at_a[n]);
        return;
    }
    if k == AK_DECL {
        if as1_arr(at_ty[n]) { return; }
        if at_a[n] != 0 {
            bool dd = gl_isd(n);
            if dd { gl_expr_d(at_a[n]); } else { gl_expr(at_a[n]); }
            gl_ensure();
            if dd { ir_add(IR_F2BITS, 1, 32, 0, 0, 0); }
            if at_ty[n] / 65536 == 0 { gl_wrap(at_ty[n] % 65536); }
            gl_store(30, gl_off[at_val[n]], 1);
        }
        gl_nz_clear(at_val[n]);
        return;
    }
    if k == AK_ASSIGN {
        int tgt = at_c[n];
        if at_kind[tgt] == AK_INDEX || at_kind[tgt] == AK_DEREF { gl_assign_mem(tgt, at_a[n], at_b[n], 0); }
        else { gl_assign(tgt, at_a[n], at_b[n]); }
        return;
    }
    if k == AK_INCDEC {
        int tg = at_a[n];
        if at_kind[tg] == AK_INDEX || at_kind[tg] == AK_DEREF {
            gl_assign_mem(tg, 0, 0, at_b[n]);
            return;
        }
        gl_expr(tg);
        gl_ensure();
        ir_add(IR_ADD, 1, 1, at_b[n], 1, 0);
        gl_store_var(tg);
        return;
    }
    if k == AK_EXPR {
        gl_expr(at_a[n]);
        return;
    }
    if k == AK_IF {
        int lt = gl_label();
        int lf = gl_label();
        int le = gl_label();
        gl_cond(at_a[n], lt, lf);
        gl_place(lt);
        gl_nz_from(at_a[n]);
        gl_stmt(at_b[n]);
        gl_jmp(le);
        gl_place(lf);
        if at_c[n] != 0 { gl_stmt(at_c[n]); }
        gl_place(le);
        return;
    }
    if k == AK_WHILE {
        int lc = gl_label();
        int lb = gl_label();
        int le2 = gl_label();
        gl_place(lc);
        gl_cond(at_a[n], lb, le2);
        gl_place(lb);
        gl_nz_from(at_a[n]);
        if gl_loops >= 32 { gl_fail = 1; return; }
        gl_brk[gl_loops] = le2;
        gl_cnt[gl_loops] = lc;
        gl_loops += 1;
        gl_stmt(at_b[n]);
        gl_loops -= 1;
        gl_jmp(lc);
        gl_place(le2);
        return;
    }
    if k == AK_FOR {
        int iv = gl_off[at_val[n]];
        int bv = gl_bsl[n];
        gl_expr(at_a[n]);
        gl_store(30, iv, 1);
        gl_expr(at_b[n]);
        gl_store(30, bv, 1);
        int lc2 = gl_label();
        int lb2 = gl_label();
        int ls = gl_label();
        int le3 = gl_label();
        gl_place(lc2);
        gl_load(1, 30, iv);
        gl_load(2, 30, bv);
        gl_br(IR_LT, 1, 2, 0, lb2, le3);
        gl_place(lb2);
        if gl_loops >= 32 { gl_fail = 1; return; }
        gl_brk[gl_loops] = le3;
        gl_cnt[gl_loops] = ls;
        gl_loops += 1;
        gl_stmt(at_c[n]);
        gl_loops -= 1;
        gl_place(ls);
        gl_load(1, 30, iv);
        ir_add(IR_ADD, 1, 1, 1, 1, 0);
        gl_store(30, iv, 1);
        gl_jmp(lc2);
        gl_place(le3);
        return;
    }
    if k == AK_RET {
        if at_a[n] != 0 {
            if gl_retd == 1 {
                gl_expr_d(at_a[n]);
                gl_ensure();
                ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
            } else {
                gl_expr(at_a[n]);
            }
        }
        gl_jmp(gl_ret);
        return;
    }
    if k == AK_BREAK {
        if gl_loops == 0 { gl_fail = 1; return; }
        gl_jmp(gl_brk[gl_loops - 1]);
        return;
    }
    if k == AK_CONT {
        if gl_loops == 0 { gl_fail = 1; return; }
        gl_jmp(gl_cnt[gl_loops - 1]);
        return;
    }
    gl_fail = 1;
}

// the offsets of the locals in the order of the declarations; the text of the hint line that this makes goes to the buffer
char gl_hint[8192];
int gl_hint_n;

void gl_hint_add(int off) {
    gl_hint_add2(off, 8, 1);
}

void gl_hint_add2(int off, int size, int flag) {
    if gl_hint_n > 8000 { gl_fail = 1; return; }
    gl_hint[gl_hint_n] = 0;
    append_int(@gl_hint, off);
    gl_hint_n = str_len(@gl_hint);
    gl_hint[gl_hint_n] = ':';
    gl_hint[gl_hint_n + 1] = 0;
    append_int(@gl_hint, size);
    gl_hint_n = str_len(@gl_hint);
    gl_hint[gl_hint_n] = ':';
    gl_hint[gl_hint_n + 1] = 0;
    append_int(@gl_hint, flag);
    gl_hint_n = str_len(@gl_hint);
    gl_hint[gl_hint_n] = ' ';
    gl_hint[gl_hint_n + 1] = 0;
    gl_hint_n += 1;
}

void gl_slots(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if k == AK_BLOCK {
        int s = at_a[n];
        while s != 0 { gl_slots(s); s = at_nx[s]; }
    } else if k == AK_DECL {
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        if as1_arr(at_ty[n]) {
            int asz = at_b[n] * as1_bytes(at_ty[n] % 65536);
            gl_hint_add2(gl_nslot, asz, 0);
            gl_nslot += (asz + 7) / 8 * 8;
        } else {
            gl_hint_add(gl_nslot);
            gl_nslot += 8;
        }
    } else if k == AK_FOR {
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        gl_bsl[n] = gl_nslot;
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        gl_slots(at_c[n]);
    } else if k == AK_IF {
        gl_slots(at_b[n]);
        gl_slots(at_c[n]);
    } else if k == AK_WHILE {
        gl_slots(at_b[n]);
    }
}

// the tree of the function `name` (without the colon): the index in the store, or -1
int at_find(char^ name) {
    int i = 0;
    while i < at_nfn {
        if str_eq(@at_name + i * 64, name) { return i; }
        i += 1;
    }
    return 0 - 1;
}

int ast_lower_body(int ti, char^ name) {
    gl_why = 0;
    int fi = at_fidx[ti];
    int np = fnpar[fi];
    // the frame: parameters first, then the locals as the parser declares them
    gl_nslot = 16;
    gl_hint_n = 0;
    gl_hint[0] = 0;
    gl_fail = 0;
    int p = 0;
    while p < np {
        gl_off[p] = gl_nslot;
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        p += 1;
    }
    gl_slots(at_root[ti]);
    if gl_fail == 1 { return 0; }
    // the hint line of the parser is ";H off:size:flag ..." (lf_hint_text)
    if !(gl_hint_n == 0 && lf_hint_n == 0) {
        if lf_hint_n < 3 || lf_hint_text[0] != ';' || lf_hint_text[1] != 'H' || lf_hint_text[2] != ' ' { gl_why = 1; return 0; }
        if gl_hint_n != lf_hint_n - 3 { gl_why = 1; return 0; }
    }
    int c = 0;
    while c < gl_hint_n {
        if gl_hint[c] != lf_hint_text[c + 3] { gl_why = 1; return 0; }
        c += 1;
    }
    // the IR
    ir_reset(name);
    ir_nv = 64;
    int cv = 1;
    while cv < 32 { ir_vcls[cv] = 0; cv += 1; }
    while cv < 64 { ir_vcls[cv] = 1; cv += 1; }
    gl_np = 0;
    gl_nlab = 0;
    gl_depth = 0;
    gl_loops = 0;
    gl_term = 0;
    gl_nzn = 0;
    gl_fdepth = 0;
    gl_rdepth = 0;
    gl_retd = 0;
    if fvoid[fi] == 0 && fret[fi] == 91 { gl_retd = 1; }
    int b0 = ir_new_block(0 - 1);
    ir_set_block(b0);
    int pk = 0;
    while pk < 8 {
        ir_add(IR_PARAM, pk + 1, 0, 0, 0, pk);
        pk += 1;
    }
    ir_add(IR_ADDR_SLOT, 30, 0, 0, 0, 0);
    p = 0;
    while p < np {
        gl_store(30, gl_off[p], p + 1);
        p += 1;
    }
    gl_ret = gl_label();
    gl_stmt(at_root[ti]);
    if gl_fail == 1 { return 0; }
    // falling off the end of a function that gives a value: the runtime stops (as the text path does)
    if gl_term == 0 && fvoid[fi] == 0 {
        gl_ensure();
        int ce = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("j2k_noret"));
        ir_set_args(ce, 0, @gl_args);
        ir_add(IR_TRAP, 0, 0, 0, 0, 0);
        gl_term = 1;
    }
    gl_place(gl_ret);
    ir_add(IR_RET, 0, 1, 0, 0, 0);
    gl_term = 1;
    // the labels become blocks
    int q = 0;
    while q < gl_np {
        int ins = gl_pinstr[q];
        int t1 = ir_t1[ins];
        if t1 >= 0 { ir_t1[ins] = gl_lblock[t1]; }
        if ir_op[ins] == IR_BR || ir_op[ins] == IR_FBR {
            int t2 = ir_t2[ins];
            if t2 >= 0 { ir_t2[ins] = gl_lblock[t2]; }
        }
        q += 1;
    }
    if ir_check() == 0 { return 0; }
    ir_lastb = ir_nb - 1;
    ast_lower_used += 1;
    return 1;
}

// build the IR of the function from its tree; 1 when it worked (the IR is complete), 0 when the text path must be used
int ast_lower(char^ name) {
    ast_lower_tried += 1;
    int ti = at_find(name);
    if ti < 0 { return 0; }
    int ok = ast_lower_body(ti, name);
    if ast_lower_report == 1 {
        write_err("astlow: ");
        write_err(name);
        if ok == 1 { write_err(" from the tree\n"); }
        else if gl_why == 1 {
            write_err(" the frame of the tree is not the frame of the parser\n  tree:   ");
            write_err(@gl_hint);
            write_err("\n  parser: ");
            int hq = 0;
            while hq < lf_hint_n { char hc[2]; hc[0] = lf_hint_text[hq]; hc[1] = 0; write_err(@hc); hq += 1; }
            write_err("\n");
        }
        else { write_err(" not lowered\n"); }
    }
    return ok;
}
