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
// the locals that the parser had when the body began (the hidden `..ret`, the parameters, `..src` of a struct by value): where they are
int at_nl[AT_FUNCS];
int at_fb[AT_FUNCS];             // the frame size then
char at_hint[1048576];          // the hint line then (AT_FUNCS x 256)
int at_loff[131072];             // AT_FUNCS x 32: the frame offset of each
int at_lk[131072];               // 0 a parameter register is stored there, else the size of a struct by value (copied from the slot before)
int ast_lower_used;              // the functions that were built from the tree
int ast_lower_tried;

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
    if t / 65536 == 6 { return t % 65536 >= 3 && t % 65536 < 90; }    // a member of a plain enum is a whole number
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

// a struct whose variables are plain bytes in the frame: no free(), no init(), no String or dynamic array inside
bool as1_splain(int s) {
    if s < 0 || s >= scount { return false; }
    if struct_needs_zero(s) { return false; }
    char hn[64];
    str_copy(@hn, @sname + s * 64, 64);
    str_copy(@hn + str_len(@hn), "__init", 8);
    return find_func(@hn) < 0;
}

bool as1_scode(int b) {
    return b >= 16 && b < 16 + scount;
}

// a struct value, a pointer to a struct, an array of structs
bool as1_sty(int t) {
    return t / 65536 == 3 && as1_scode(t % 65536);
}

bool as1_sptr(int t) {
    return t / 65536 == 1 && as1_scode(t % 65536);
}

bool as1_sarr(int t) {
    return t / 65536 == 2 && as1_scode(t % 65536);
}

// any pointer of the subset
bool as1_pt(int t) {
    return as1_ptr(t) || as1_sptr(t);
}

bool as1_val(int t) {
    return as1_scalar(t) || as1_pt(t);
}

// width of a field: a bool is one byte there (a bool variable is 8 bytes), the others as their width code
int as1_fbytes(int b) {
    if b == 3 { return 1; }
    return as1_bytes(b);
}

int as1_flw(int b) {
    if b == 3 { return 1; }
    return as1_lw(b);
}

bool as1_dbl(int t) {
    return t / 65536 == 0 && t % 65536 == 7;
}

// the type id of a parameter or a result (fptid / fret): 0 a whole number, 1 bool, 91 double
// a struct that can be passed and returned by value: plain bytes, not too big
bool as1_sbyval(int s) {
    return as1_splain(s) && ssize[s] <= 128;
}

bool as1_tid(int t) {
    return t == 0 || t == 1 || t == 91 || (t >= 3 && t < 90);
}

// the type id of a parameter: as above or a struct by value
bool as1_ptid(int t) {
    if t >= 100 && t < 100 + scount { return as1_sbyval(t - 100); }
    return as1_tid(t);
}

// the type id of a result: as above or a struct
bool as1_rtid(int t) {
    return as1_tid(t) || as1_ptid(t);
}

bool as1_arith(int ao) {
    return ao == AO_ADD || ao == AO_SUB || ao == AO_MUL || ao == AO_DIV;
}

// a variable (local or global) that is a pointer, an array or a struct, as the subset knows it (a scalar is not here)
bool as1_var_ok(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int t = ast_ty[n];
    if k == AK_VAR { return as1_pt(t) || as1_arr(t) || as1_sarr(t) || (as1_sty(t) && as1_splain(t % 65536 - 16)); }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 || gdyn[gi] != 0 { return false; }
        if gkind[gi] == 1 {
            if gptr[gi] != 0 || gnd[gi] != 1 { return false; }
            return (as1_el(gelem[gi]) && as1_arr(t)) || (as1_scode(gelem[gi]) && as1_sarr(t));
        }
        if gkind[gi] != 0 { return false; }
        // a pointer variable: gptr is the width code of what it points to
        if gptr[gi] != 0 {
            return gelem[gi] == 8 && t % 65536 == gptr[gi] && ((as1_el(gptr[gi]) && as1_ptr(t)) || (as1_scode(gptr[gi]) && as1_sptr(t)));
        }
        return as1_scode(gelem[gi]) && as1_sty(t);
    }
    return false;
}

// an index: a whole number that is not a double
bool as1_index_ok(int ix) {
    return as1_expr(ix) && !as1_dbl(ast_ty[ix]) && as1_scalar(ast_ty[ix]);
}

// an object in memory that has an address: a variable that is an array or a struct, an element that is a struct, p^ of a struct,
// a field that is a struct or an array (a scalar is the value, not here)
bool as1_lv(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int t = ast_ty[n];
    if k == AK_VAR || k == AK_GVAR { return (as1_arr(t) || as1_sarr(t) || as1_sty(t)) && as1_var_ok(n); }
    if opt_debug == 1 { return false; }
    if k == AK_DEREF { return as1_sty(t) && as1_sptr(ast_ty[ast_a[n]]) && as1_expr(ast_a[n]); }
    if k == AK_INDEX { return as1_sty(t) && ast_c[n] == 0 && as1_base(ast_a[n]) && as1_index_ok(ast_b[n]); }
    if k == AK_FIELD {
        int fi = ast_val[n];
        if fi < 0 || fldptr[fi] != 0 || flddyn[fi] != 0 || !as1_sty(ast_ty[ast_a[n]]) { return false; }
        if fldkind[fi] == 1 {
            if fldnd[fi] != 1 || !(as1_arr(t) || as1_sarr(t)) { return false; }
        } else if !as1_sty(t) {
            return false;
        }
        return as1_lv(ast_a[n]);
    }
    return false;
}

// the base of an index: an array or a pointer, a local or a global, a field
bool as1_base(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int t = ast_ty[n];
    if as1_arr(t) || as1_sarr(t) { return as1_lv(n); }
    if as1_pt(t) {
        if k == AK_VAR || k == AK_GVAR { return as1_var_ok(n); }
        if k == AK_FIELD { return as1_expr(n); }
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

// the functions of the group Bit that are one instruction (the text path does the same): 1 clz, 2 ctz, 3 popcount, 4 bswap, 5 rotl, 6 rotr
int as1_intrin(char^ nm) {
    if !as1_prefix(nm, "Bit__") { return 0; }
    char^ r = nm + 5;
    if as1_prefix(r, "clz") && r[3] == 0 { return 1; }
    if as1_prefix(r, "ctz") && r[3] == 0 { return 2; }
    if as1_prefix(r, "popcount") && r[8] == 0 { return 3; }
    if as1_prefix(r, "bswap") && r[5] == 0 { return 4; }
    if as1_prefix(r, "rotl") && r[4] == 0 { return 5; }
    if as1_prefix(r, "rotr") && r[4] == 0 { return 6; }
    return 0;
}

bool as1_special(char^ nm) {
    if as1_intrin(nm) != 0 { return false; }
    if as1_prefix(nm, "Bit__") || as1_prefix(nm, "Cpu__") || as1_prefix(nm, "Cache__") || as1_prefix(nm, "Atomic__") { return true; }
    if as1_prefix(nm, "Mem__bar") { return true; }
    return nm[0] == '_' && nm[1] == '_';
}

// the arguments from a2 go to the parameters from pk of the function fi
bool as1_args(int fi, int a2, int pk) {
    while a2 != 0 {
        if pk >= fnpar[fi] { return false; }
        int pt = fptid[fi * 8 + pk];
        if pt >= 100 {
            // a struct by value: a struct of that type that has an address, or a call that makes one
            if !as1_ptid(pt) || ast_ty[a2] != 3 * 65536 + 16 + pt - 100 || !as1_sx(a2) { return false; }
        } else {
            if !as1_expr(a2) || !as1_tid(pt) { return false; }
            // a double goes to a double parameter, a whole number (or a pointer) to a whole number one
            if (pt == 91) != as1_dbl(ast_ty[a2]) { return false; }
        }
        pk += 1;
        a2 = ast_nx[a2];
    }
    return pk == fnpar[fi];
}

// the number of registers of the call besides the parameters: the address of the result when a struct is the result
int as1_hidden(int fi) {
    if fvoid[fi] == 0 && fret[fi] >= 100 { return 1; }
    return 0;
}

// a call of a function with parameters and a result of whole numbers, pointers, bools, doubles, plain structs (a void function
// only as a statement)
bool as1_call(int n) {
    int fi = ast_val[n];
    if fi < 0 || fi >= fcount || fretdyn[fi] != 0 { return false; }
    if fnpar[fi] + as1_hidden(fi) > 8 { return false; }
    if fvoid[fi] == 0 && !as1_rtid(fret[fi]) { return false; }
    if fcharret[fi] != 0 || farr[fi] != 0 || as1_special(@fname + fi * 64) { return false; }
    int ik = as1_intrin(@fname + fi * 64);
    if ik != 0 {
        // whole numbers in and out (the text path takes any number of arguments from the call: only the right count is lowered)
        int want = 1;
        if ik >= 5 { want = 2; }
        if fnpar[fi] != want { return false; }
    }
    return as1_args(fi, ast_a[n], 0);
}

// a struct value: an object that has an address, or the result of a call
bool as1_sx(int n) {
    if n == 0 || !as1_sty(ast_ty[n]) { return false; }
    int k = ast_kind[n];
    if k == AK_CALL { return as1_call(n) && as1_hidden(ast_val[n]) == 1; }
    if k == AK_METHOD { return as1_method(n) && as1_hidden(as1_mfn(n)) == 1; }
    return as1_lv(n);
}

// the function of a method call `s.name(args)` on a struct of the program: Struct__name, or -1
int as1_mfn(int n) {
    int r = ast_a[n];
    int rt = ast_ty[r];
    if !as1_sty(rt) { return 0 - 1; }
    char full[128];
    str_copy(@full, @sname + (rt % 65536 - 16) * 64, 64);
    int k = str_len(@full);
    full[k] = '_';
    full[k + 1] = '_';
    int j = 0;
    char^ mn = @ast_pool + ast_val[n];
    while mn[j] != 0 && k + 2 + j < 120 {
        full[k + 2 + j] = mn[j];
        j += 1;
    }
    full[k + 2 + j] = 0;
    return find_func(@full);
}

// a method of a struct (its first parameter is the address of the struct) with parameters and a result of the subset
bool as1_method(int n) {
    if opt_debug == 1 { return false; }
    int fi = as1_mfn(n);
    if fi < 0 || fnpar[fi] < 1 || fretdyn[fi] != 0 || fop[fi] != 0 { return false; }
    if fnpar[fi] + as1_hidden(fi) > 8 { return false; }
    if fvoid[fi] == 0 && !as1_rtid(fret[fi]) { return false; }
    if fcharret[fi] != 0 || farr[fi] != 0 || as1_special(@fname + fi * 64) { return false; }
    if fptid[fi * 8] != 0 || !as1_lv(ast_a[n]) { return false; }
    return as1_args(fi, ast_b[n], 1);
}

// the value of a member of a plain enum (`Color::Red`, or the bare name of `using enum`) goes to as1_ev; false when it is not one
int as1_ev;
bool as1_enumv(int n) {
    if ast_a[n] != 0 || ast_cls[n] == 0 { return false; }
    int keep_ty = ex_ty;
    int keep_val = found_val;
    bool r = false;
    int t = ast_ty[n];
    if ast_c[n] != 0 { t = ast_c[n]; }          // a pattern of a switch: the type of the value
    if ast_cls[n] == 1 && t / 65536 == 6 {
        if find_member(t % 65536 - 3, @ast_pool + ast_val[n]) { r = true; as1_ev = found_val; }
    } else if ast_cls[n] == 3 {
        if find_using_member(@ast_pool + ast_val[n]) { r = true; as1_ev = found_val; }
    }
    ex_ty = keep_ty;
    found_val = keep_val;
    return r;
}

bool as1_expr(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int ty = ast_ty[n];
    if !as1_val(ty) { return false; }
    if k == AK_NUM { return as1_scalar(ty); }
    if k == AK_FNUM { return true; }
    if k == AK_ENUMV { return as1_enumv(n); }
    if k == AK_BUILTIN {
        // __fsqrt / __ffloor / __fceil / __ftrunc of a double
        int a1 = ast_a[n];
        return ast_fop_of(ast_val[n]) != 0 && a1 != 0 && ast_nx[a1] == 0 && as1_dbl(ast_ty[a1]) && as1_expr(a1);
    }
    if k == AK_VAR { return as1_scalar(ty) || as1_pt(ty); }
    if k == AK_FIELD {
        int fi = ast_val[n];
        if opt_debug == 1 || fi < 0 || fldkind[fi] != 0 || flddyn[fi] != 0 || !as1_sty(ast_ty[ast_a[n]]) { return false; }
        if as1_pt(ty) { if fldptr[fi] == 0 { return false; } } else if fldptr[fi] != 0 { return false; }
        return as1_lv(ast_a[n]);
    }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 { return false; }
        if as1_pt(ty) { return as1_var_ok(n); }
        return gkind[gi] == 0 && (as1_el(gelem[gi]) || gelem[gi] == 3) && gptr[gi] == 0 && gdyn[gi] == 0 && as1_tid(gtid[gi]);
    }
    if k == AK_INDEX {
        if opt_debug == 1 || ast_c[n] != 0 || !as1_scalar(ty) { return false; }
        return as1_base(ast_a[n]) && as1_index_ok(ast_b[n]);
    }
    if k == AK_DEREF {
        if opt_debug == 1 || !as1_scalar(ty) { return false; }
        return as1_ptr(ast_ty[ast_a[n]]) && as1_expr(ast_a[n]);
    }
    if k == AK_ADDR {
        if !as1_pt(ty) { return false; }
        int t = ast_a[n];
        int tk = ast_kind[t];
        int tt = ast_ty[t];
        // a struct, an array of structs, a field that is a struct or an array
        if (tk == AK_VAR || tk == AK_GVAR || tk == AK_FIELD || tk == AK_INDEX) && (as1_sty(tt) || as1_sarr(tt) || (tk == AK_FIELD && as1_arr(tt))) { return as1_lv(t); }
        if tk == AK_FIELD { return as1_ptr(ty) && as1_scalar(tt) && tt % 65536 != 3 && as1_expr(t); }
        if tk == AK_VAR || tk == AK_GVAR {
            // a scalar or an array of the width of the pointer
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
        bool any_p = as1_pt(ast_ty[a]) || as1_pt(ast_ty[b]);
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
    if k == AK_METHOD { return as1_method(n) && fvoid[as1_mfn(n)] == 0; }
    return false;
}

bool as1_target(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    if !as1_val(ast_ty[n]) { return false; }
    if k == AK_VAR { return true; }
    return (k == AK_GVAR || k == AK_INDEX || k == AK_DEREF || k == AK_FIELD) && as1_expr(n);
}

// a call whose result is a pointer (the tree types it as a whole number: the result type id of a pointer is 0)
bool as1_callptr(int n) {
    int k = ast_kind[n];
    return (k == AK_CALL || k == AK_METHOD) && as1_scalar(ast_ty[n]) && !as1_dbl(ast_ty[n]);
}

// one value of a list: an expression (not a list) of the kind of the element
bool as1_item(int e, int code) {
    return ast_kind[e] != AK_LIST && as1_scalar(ast_ty[e]) && as1_expr(e) && as1_dbl(ast_ty[e]) == (code == 7);
}

// a list of values for the struct s: the fields in order, a list for a field that is a struct or an array
bool as1_slist(int lst, int s) {
    if lst == 0 || ast_kind[lst] != AK_LIST || !as1_splain(s) { return false; }
    int it = ast_a[lst];
    int k = 0;
    while k < snf[s] {
        int fi = sfirst[s] + k;
        if it == 0 || fldptr[fi] != 0 || flddyn[fi] != 0 { return false; }
        if fldkind[fi] == 1 {
            if fldnd[fi] != 1 || !as1_el(fldcode[fi]) || ast_kind[it] != AK_LIST { return false; }
            int e = ast_a[it];
            int c = 0;
            while e != 0 {
                if !as1_item(e, fldcode[fi]) { return false; }
                c += 1;
                e = ast_nx[e];
            }
            if c != fldcnt[fi] { return false; }
        } else if fldcode[fi] >= 16 {
            if fldcode[fi] >= 16 + scount || !as1_slist(it, fldcode[fi] - 16) { return false; }
        } else {
            if !(as1_el(fldcode[fi]) || fldcode[fi] == 3) || !as1_item(it, fldcode[fi]) { return false; }
        }
        it = ast_nx[it];
        k += 1;
    }
    return it == 0;
}

// the number of values of a list
int as1_count(int lst) {
    int c = 0;
    int e = ast_a[lst];
    while e != 0 {
        c += 1;
        e = ast_nx[e];
    }
    return c;
}

bool as1_decl(int n) {
    int k = ast_kind[n];
        int dt = ast_ty[n];
        int init = ast_a[n];
        if as1_arr(dt) {
            // a fixed array of one dimension with a number as its size, no initial values or a list that fits
            if init == 0 { return ast_b[n] > 0 && ast_b[n] < 65536; }
            if ast_kind[init] != AK_LIST { return false; }
            int cnt = as1_count(init);
            if cnt == 0 || cnt >= 65536 || (ast_b[n] > 0 && cnt > ast_b[n]) || ast_b[n] == 0 { return false; }
            int e = ast_a[init];
            while e != 0 {
                if !as1_item(e, dt % 65536) { return false; }
                e = ast_nx[e];
            }
            return true;
        }
        if as1_sty(dt) {
            if !as1_splain(dt % 65536 - 16) || ssize[dt % 65536 - 16] > 128 && init != 0 { return false; }
            // no value, a list, or a struct of the same type (a variable, a field, an element or a call)
            if init != 0 && ast_kind[init] == AK_LIST { return as1_slist(init, dt % 65536 - 16); }
            return init == 0 || (ast_ty[init] == dt && as1_sx(init));
        }
        if as1_sarr(dt) {
            int ss = dt % 65536 - 16;
            if !as1_splain(ss) { return false; }
            if init == 0 { return ast_b[n] > 0 && ast_b[n] * ssize[ss] < 65536; }
            if ast_kind[init] != AK_LIST { return false; }
            int cnt2 = as1_count(init);
            if cnt2 == 0 || ast_b[n] == 0 || (ast_b[n] > 0 && cnt2 > ast_b[n]) || cnt2 * ssize[ss] >= 65536 { return false; }
            int e2 = ast_a[init];
            while e2 != 0 {
                if !as1_slist(e2, ss) { return false; }
                e2 = ast_nx[e2];
            }
            return true;
        }
        if as1_pt(dt) {
            if ast_a[n] == 0 { return true; }
            int pv = ast_a[n];
            return as1_expr(pv) && (as1_pt(ast_ty[pv]) || (ast_kind[pv] == AK_NUM && ast_val[pv] == 0) || as1_callptr(pv));
        }
        if !as1_scalar(dt) { return false; }
        if ast_a[n] == 0 { return true; }
        // the value has the type of the variable
        return as1_expr(ast_a[n]) && as1_val(ast_ty[ast_a[n]]) && !as1_pt(ast_ty[ast_a[n]]) && as1_dbl(ast_ty[ast_a[n]]) == as1_dbl(dt);
    return false;
}

bool as1_assign(int n) {
    int k = ast_kind[n];
        int t = ast_c[n];
        if as1_sty(ast_ty[t]) {
            // a struct is copied: the target has an address, the value is a struct of the same type
            return ast_b[n] == 0 && as1_lv(t) && as1_sbyval(ast_ty[t] % 65536 - 16) && ast_ty[ast_a[n]] == ast_ty[t] && as1_sx(ast_a[n]);
        }
        if !as1_target(t) || !as1_expr(ast_a[n]) || ast_b[n] < 0 { return false; }
        bool td = as1_dbl(ast_ty[t]);
        int opc = ast_b[n];
        if as1_pt(ast_ty[t]) {
            // a pointer gets a pointer of the same kind or 0
            int pv2 = ast_a[n];
            return opc == 0 && as1_expr(pv2) && (as1_pt(ast_ty[pv2]) || (ast_kind[pv2] == AK_NUM && ast_val[pv2] == 0) || as1_callptr(pv2));
        }
        if as1_pt(ast_ty[ast_a[n]]) { return false; }
        if td { return (opc == 0 || as1_arith(opc)) && as1_dbl(ast_ty[ast_a[n]]) == (td || true); }
        return !as1_dbl(ast_ty[ast_a[n]]);
    return false;
}

int as1_fret;                    // the struct that the function being looked at returns (its number), else -1

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
    if k == AK_DECL { return as1_decl(n); }
    if k == AK_ASSIGN { return as1_assign(n); }
    if k == AK_INCDEC { return as1_target(ast_a[n]) && as1_scalar(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_a[n]]); }
    if k == AK_EXPR { return (ast_kind[ast_a[n]] == AK_CALL && as1_call(ast_a[n])) || (ast_kind[ast_a[n]] == AK_METHOD && as1_method(ast_a[n])); }
    if k == AK_IF { return as1_expr(ast_a[n]) && as1_stmt(ast_b[n]) && as1_stmt(ast_c[n]); }
    if k == AK_WHILE { return ast_val[n] == 0 && ast_c[n] == 0 && as1_expr(ast_a[n]) && as1_stmt(ast_b[n]); }
    if k == AK_FOR { return ast_b[n] != 0 && as1_expr(ast_a[n]) && as1_expr(ast_b[n]) && !as1_dbl(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_b[n]]) && as1_stmt(ast_c[n]); }
    if k == AK_RET {
        if ast_a[n] == 0 { return true; }
        if as1_sty(ast_ty[ast_a[n]]) { return as1_fret >= 0 && ast_ty[ast_a[n]] == 3 * 65536 + 16 + as1_fret && as1_sx(ast_a[n]); }
        return as1_expr(ast_a[n]);
    }
    if k == AK_BREAK || k == AK_CONT { return true; }
    if k == AK_SWITCH {
        // a whole number, a char or an enum; the patterns are constants (a data enum or a name that is bound: the text path)
        int sv = ast_a[n];
        if !as1_scalar(ast_ty[sv]) || as1_dbl(ast_ty[sv]) || !as1_expr(sv) { return false; }
        int cs = ast_b[n];
        if cs == 0 { return false; }
        while cs != 0 {
            if ast_kind[cs] != AK_CASE || ast_val[cs] != 0 { return false; }
            int pt = ast_a[cs];
            while pt != 0 {
                int pk = ast_kind[pt];
                if pk == AK_NEG { pk = ast_kind[ast_a[pt]]; if pk != AK_NUM { return false; } }
                else if pk == AK_ENUMV {
                    // a pattern has no type of its own: it is a member of the enum of the value
                    if ast_ty[sv] / 65536 == 6 { ast_c[pt] = ast_ty[sv]; }
                    if !as1_enumv(pt) { return false; }
                }
                else if pk != AK_NUM { return false; }
                pt = ast_nx[pt];
            }
            if !as1_stmt(ast_b[cs]) { return false; }
            cs = ast_nx[cs];
        }
        return true;
    }
    if k == AK_COUT {
        int it = ast_a[n];
        if it == 0 { return false; }
        while it != 0 {
            if ast_kind[it] != AK_STR {
                // a number, a bool, a char or a double (a pointer, a String, an array: the text path)
                if !as1_scalar(ast_ty[it]) || !as1_expr(it) { return false; }
            }
            it = ast_nx[it];
        }
        return true;
    }
    return false;
}

// the node fields that hold nodes, by kind: bit 0 a, bit 1 b, bit 2 c
int at_fields(int k) {
    if k == AK_BIN || k == AK_WHILE || k == AK_INDEX { return 3; }
    if k == AK_DEREF || k == AK_ADDR || k == AK_FIELD { return 1; }
    if k == AK_NEG || k == AK_NOT || k == AK_CALL || k == AK_BLOCK || k == AK_DECL || k == AK_EXPR || k == AK_RET || k == AK_INCDEC || k == AK_CAST { return 1; }
    if k == AK_ASSIGN { return 5; }
    if k == AK_IF || k == AK_FOR { return 7; }
    if k == AK_METHOD || k == AK_SWITCH || k == AK_CASE { return 3; }
    if k == AK_COUT || k == AK_LIST || k == AK_BUILTIN { return 1; }
    return 0;
}

// the kinds of nodes that the lowering knows
bool as1_kind_ok(int k) {
    if k == AK_NUM || k == AK_FNUM || k == AK_VAR || k == AK_GVAR || k == AK_INDEX || k == AK_DEREF || k == AK_ADDR || k == AK_FIELD { return true; }
    if k == AK_BIN || k == AK_NEG || k == AK_NOT || k == AK_CAST || k == AK_CALL || k == AK_DECL || k == AK_ASSIGN || k == AK_INCDEC { return true; }
    if k == AK_STR || k == AK_COUT || k == AK_ENUMV || k == AK_METHOD || k == AK_SWITCH || k == AK_CASE { return true; }
    return k == AK_EXPR || k == AK_IF || k == AK_WHILE || k == AK_FOR || k == AK_RET || k == AK_BREAK || k == AK_CONT || k == AK_BLOCK;
}

int at_rej_n;
// -ast2: why a function of the tree is kept on the text path
void at_reject(int f_idx, char^ why) {
    if ast_lower_report != 1 { return; }
    write_err("astlow: ");
    write_err(@fname + f_idx * 64);
    write_err(" rejected: ");
    write_err(why);
    if why[0] == 'p' || why[0] == 'r' || why[0] == 's' {
        write_err(" ");
        write_err_int(at_rej_n);
    }
    if why[0] == 'n' {
        // the first kind of node that is not lowered, else the first type that is not
        int i = 1;
        bool said = false;
        while i <= ast_n && !said {
            if !as1_kind_ok(ast_kind[i]) {
                write_err(" kind ");
                write_err_int(ast_kind[i]);
                if ast_kind[i] == AK_BUILTIN { write_err(" "); write_err(@ast_pool + ast_val[i]); }
                said = true;
            } else {
                int ty2 = ast_ty[i];
                int tk2 = ty2 / 65536;
                int tb2 = ty2 % 65536;
                if tk2 == 4 || tk2 == 5 || tk2 == 8 || (tk2 == 0 && (tb2 == 6 || tb2 == 11 || tb2 == 12 || tb2 == 13)) || tk2 == 6 && tb2 >= 90 {
                    write_err(" type ");
                    write_err_int(tk2);
                    write_err(":");
                    write_err_int(tb2);
                    write_err(" of node ");
                    write_err_int(ast_kind[i]);
                    said = true;
                }
            }
            i += 1;
        }
    }
    write_err("\n");
}

// called at the end of ast_probe for a body that is in the tree's subset: keep it when it is in the subset of the lowering
void at_store(int f_idx) {
    if ast_lower_on == 0 || at_nfn >= AT_FUNCS || at_n + ast_n + 2 >= AT_MAX { return; }
    // the function: parameters of whole numbers, bool or double, a result of those or nothing
    if fnpar[f_idx] + as1_hidden(f_idx) > 8 || fretdyn[f_idx] != 0 || fcharret[f_idx] != 0 || farr[f_idx] != 0 {
        at_rej_n = fnpar[f_idx] * 1000 + fretdyn[f_idx] * 100 + fcharret[f_idx] * 10 + farr[f_idx];
        at_reject(f_idx, "signature");
        return;
    }
    int pk = 0;
    while pk < fnpar[f_idx] {
        if !as1_ptid(fptid[f_idx * 8 + pk]) { at_rej_n = fptid[f_idx * 8 + pk]; at_reject(f_idx, "parameter"); return; }
        pk += 1;
    }
    if fvoid[f_idx] == 0 && !as1_rtid(fret[f_idx]) { at_rej_n = fret[f_idx]; at_reject(f_idx, "result"); return; }
    if lcount > 32 || hint_len > 250 || hint_len >= 16383 { at_rej_n = lcount; at_reject(f_idx, "signature"); return; }
    as1_fret = 0 - 1;
    if fvoid[f_idx] == 0 && fret[f_idx] >= 100 { as1_fret = fret[f_idx] - 100; }
    if !as1_stmt(ast_root) { at_reject(f_idx, "node or type"); return; }
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
        if k == AK_METHOD { at_val[base + i] = as1_mfn(i); }
        if k == AK_BUILTIN { at_val[base + i] = ast_fop_of(ast_val[i]); }
        if k == AK_DECL && ast_b[i] < 0 && ast_a[i] != 0 && ast_kind[ast_a[i]] == AK_LIST { at_b[base + i] = as1_count(ast_a[i]); }
        if k == AK_STR {
            int sl = ast_b[i];
            if at_spn + sl + 1 > 262144 { at_n = base; at_reject(f_idx, "literals"); return; }
            str_copy(@at_spool + at_spn, @ast_pool + ast_val[i], sl + 1);
            at_val[base + i] = at_spn;
            at_spn += sl;
        }
        if k == AK_ENUMV {
            // the value of the member is known now (the names of the tree are not kept)
            at_kind[base + i] = AK_NUM;
            as1_enumv(i);
            at_val[base + i] = as1_ev;
            at_a[base + i] = 0;
        }
        at_nx[base + i] = 0;
        if ast_nx[i] != 0 { at_nx[base + i] = ast_nx[i] + base; }
        i += 1;
    }
    at_n = base + ast_n + 1;
    str_copy(@at_name + at_nfn * 64, @fname + f_idx * 64, 64);
    at_root[at_nfn] = ast_root + base;
    at_fidx[at_nfn] = f_idx;
    at_nl[at_nfn] = lcount;
    at_fb[at_nfn] = frame_bytes;
    str_copy(@at_hint + at_nfn * 256, @hint_buf, 256);
    int li = 0;
    while li < lcount {
        at_loff[at_nfn * 32 + li] = loff[li];
        at_lk[at_nfn * 32 + li] = 0;
        // a struct by value: nothing is stored from a register for it, the slot before it (`..src`) holds the address
        if ltid[li] >= 100 && lptr[li] == 0 && lkind[li] == 0 && lname[li * 64] != '.' { at_lk[at_nfn * 32 + li] = ssize[ltid[li] - 100]; }
        li += 1;
    }
    at_nfn += 1;
}

// ---------------------------------------------------------------- the lowering
#define GL_MAXP 4096
int gl_pinstr[GL_MAXP];          // the jumps whose targets are label numbers until the end
int gl_np;
int gl_lblock[GL_MAXP];          // label -> block
int gl_nlab;
int gl_term;                     // 1: the current block has its last instruction
int gl_retoff;                   // the slot that holds the address of the result of a function that gives a struct, else -1
int gl_ab;                       // the base register and the offset that gl_addr / gl_lv give
int gl_ao;
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
    if at_kind[n] == AK_FIELD { return as1_flw(t % 65536); }
    return as1_lw(t % 65536);
}

// the width of a store into the node (a pointer is 8 bytes, a bool field one byte)
int gl_sw(int n) {
    int t = at_ty[n];
    if t / 65536 != 0 { return 8; }
    if at_kind[n] == AK_FIELD { return as1_fbytes(t % 65536); }
    return as1_bytes(t % 65536);
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
    if k == AK_CALL || k == AK_METHOD { return true; }
    if k == AK_BIN { return gl_has_call(at_a[n]) || gl_has_call(at_b[n]); }
    if k == AK_NEG || k == AK_NOT || k == AK_CAST || k == AK_DEREF || k == AK_ADDR || k == AK_FIELD || k == AK_BUILTIN { return gl_has_call(at_a[n]); }
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

// copy size bytes from [sreg + soff] to [dreg + doff] (v2 is the go-between; neither register is v2)
void gl_copy(int dreg, int doff, int sreg, int soff, int size) {
    int w = 0;
    while w < size {
        gl_ensure();
        gl_loadw(2, sreg, soff + w, 8);
        gl_store(dreg, doff + w, 2);
        w += 8;
    }
}

void gl_call(int n) {
    int fi = at_val[n];
    int argn = 0;
    int a = at_a[n];
    int base = gl_depth;
    bool hid = fvoid[fi] == 0 && fret[fi] >= 100;
    if hid {
        // a struct result: the address of its slot in this frame is the first argument
        gl_ensure();
        ir_add(IR_ADD, 1, 30, at_c[n], 1, 0);
        gl_store(30, gl_cell(gl_depth), 1);
        gl_depth += 1;
        argn = 1;
    }
    if at_kind[n] == AK_METHOD {
        // the first argument is the address of the object
        gl_lv(a);
        gl_ensure();
        if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
        gl_store(30, gl_cell(gl_depth), 1);
        gl_depth += 1;
        argn += 1;
        a = at_b[n];
    }
    int hn = 0;
    if hid { hn = 1; }
    while a != 0 {
        if fptid[fi * 8 + argn - hn] >= 100 {
            gl_saddr(a);
        } else {
            gl_expr(a);
            gl_ensure();
            if gl_isd(a) { ir_add(IR_F2BITS, 1, 32, 0, 0, 0); }
        }
        gl_ensure();
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
    int ik = as1_intrin(@fname + fi * 64);
    if ik != 0 {
        if ik == 1 { ir_add(IR_CLZ, 1, 1, 0, 0, 0); }
        else if ik == 2 { ir_add(IR_RBIT, 1, 1, 0, 0, 0); ir_add(IR_CLZ, 1, 1, 0, 0, 0); }
        else if ik == 3 { ir_add(IR_POPCNT, 1, 1, 0, 0, 0); }
        else if ik == 4 { ir_add(IR_BSWAP, 1, 1, 0, 0, 0); }
        else {
            if ik == 5 { ir_add(IR_NEG, 2, 2, 0, 0, 0); }
            ir_add(IR_ROTR, 1, 1, 2, 0, 0);
        }
        return;
    }
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(@fname + fi * 64));
    int r = 0;
    while r < argn {
        gl_args[r] = r + 1;
        r += 1;
    }
    ir_set_args(e, argn, @gl_args);
    if hid { ir_add(IR_ADD, 1, 30, at_c[n], 1, 0); }
    else if fret[fi] == 91 { ir_add(IR_BITS2F, 32, 1, 0, 0, 0); }
}

// v1 = the address of a struct value: an object that has an address, or the slot of the result of a call
void gl_saddr(int n) {
    int k = at_kind[n];
    if k == AK_CALL || k == AK_METHOD {
        gl_call(n);
        return;
    }
    gl_lv(n);
    gl_ensure();
    if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
}

// target = value for structs: the address of the target waits (v9 .. or a cell) while the value is made
void gl_assign_struct(int target, int value) {
    gl_lv(target);
    bool fixed = gl_ab == 30 || gl_ab == 29;
    int fb = gl_ab;
    int fo = gl_ao;
    int ar = 0;
    int c = gl_cell(gl_depth);
    if !fixed {
        gl_ensure();
        if gl_rdepth < 7 && !gl_has_call(value) {
            ar = 9 + gl_rdepth;
            ir_add(IR_COPY, ar, 1, 0, 0, 0);
            gl_rdepth += 1;
        } else {
            gl_store(30, c, 1);
            gl_depth += 1;
        }
    }
    gl_saddr(value);
    gl_ensure();
    if !fixed {
        if ar != 0 {
            ir_add(IR_COPY, 3, ar, 0, 0, 0);
            gl_rdepth -= 1;
        } else {
            gl_load(3, 30, c);
            gl_depth -= 1;
        }
        fb = 3;
    }
    gl_copy(fb, fo, 1, 0, ssize[at_ty[target] % 65536 - 16]);
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

// the address of an object: a variable that is an array or a struct (v30 / v29 and its offset), or what gl_addr gives
void gl_lv(int n) {
    int k = at_kind[n];
    if k == AK_VAR {
        gl_ab = 30;
        gl_ao = gl_off[at_val[n]];
        return;
    }
    if k == AK_GVAR {
        gl_ab = 29;
        gl_ao = goff[at_val[n]];
        return;
    }
    gl_addr(n);
}

// v1 = v1 * es (the index of an element of es bytes); esh is the shift when es is a power of two, else -1
void gl_scale(int es, int esh) {
    gl_ensure();
    if esh > 0 {
        ir_add(IR_SHL, 1, 1, esh, 1, 0);
    } else if esh < 0 {
        ir_add(IR_CONST, 2, 0, 0, 0, es);
        ir_add(IR_MUL, 1, 1, 2, 0, 0);
    }
}

void gl_addr(int n) {
    gl_ensure();
    int k = at_kind[n];
    if k == AK_DEREF {
        gl_expr(at_a[n]);
        gl_ab = 1;
        gl_ao = 0;
        return;
    }
    if k == AK_FIELD {
        gl_lv(at_a[n]);
        gl_ao += fldoff[at_val[n]];
        return;
    }
    int b = at_a[n];
    int ix = at_b[n];
    bool is_arr = as1_arr(at_ty[b]) || as1_sarr(at_ty[b]);
    int bk = at_kind[b];
    int boff = 0;
    int bvr = 30;
    int es = 8;
    if as1_sty(at_ty[n]) { es = ssize[at_ty[n] % 65536 - 16]; } else { es = as1_bytes(at_ty[n] % 65536); }
    int p2 = 1;
    int esh = 0;
    while p2 < es {
        p2 = p2 * 2;
        esh += 1;
    }
    if p2 != es { esh = 0 - 1; }
    bool simple = bk == AK_VAR || bk == AK_GVAR;
    if bk == AK_VAR { boff = gl_off[at_val[b]]; } else if bk == AK_GVAR { boff = goff[at_val[b]]; bvr = 29; }
    if !simple {
        // a field that is an array or a pointer, an element of an array of arrays...: the address of element 0 is bvr + boff
        if is_arr {
            gl_lv(b);
            bvr = gl_ab;
            boff = gl_ao;
        } else {
            gl_expr(b);
            bvr = 1;
            boff = 0;
        }
        if at_kind[ix] == AK_NUM && at_val[ix] >= 0 && at_val[ix] < 4096 {
            gl_ab = bvr;
            gl_ao = boff + at_val[ix] * es;
            return;
        }
        int ar = 0;
        int c = gl_cell(gl_depth);
        if bvr == 1 {
            // the address waits while the index is worked out
            if gl_rdepth < 7 && !gl_has_call(ix) {
                ar = 9 + gl_rdepth;
                ir_add(IR_COPY, ar, 1, 0, 0, 0);
                gl_rdepth += 1;
            } else {
                gl_store(30, c, 1);
                gl_depth += 1;
            }
        }
        gl_expr(ix);
        gl_scale(es, esh);
        gl_ensure();
        if bvr == 1 {
            if ar != 0 {
                ir_add(IR_ADD, 1, 1, ar, 0, 0);
                gl_rdepth -= 1;
            } else {
                gl_load(2, 30, c);
                ir_add(IR_ADD, 1, 1, 2, 0, 0);
                gl_depth -= 1;
            }
            gl_ab = 1;
            gl_ao = boff;
        } else if bvr == 29 {
            ir_add(IR_ADD, 1, 1, 29, 0, 0);
            gl_ab = 1;
            gl_ao = boff;
        } else {
            ir_add(IR_ADD, 2, 30, boff, 1, 0);
            ir_add(IR_ADD, 1, 1, 2, 0, 0);
            gl_ab = 1;
            gl_ao = 0;
        }
        return;
    }
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
    gl_scale(es, esh);
    gl_ensure();
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
    ir_w[se] = gl_sw(target);
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
    if k == AK_INDEX || k == AK_DEREF || k == AK_FIELD {
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
    if k == AK_CALL || k == AK_METHOD {
        gl_call(n);
        return;
    }
    if k == AK_BUILTIN {
        gl_expr_d(at_a[n]);
        gl_ensure();
        int fo = at_val[n];
        if fo == 1 { ir_add(IR_FSQRT, 32, 32, 0, 0, 0); }
        else if fo == 2 { ir_add(IR_FFLOOR, 32, 32, 0, 0, 0); }
        else if fo == 3 { ir_add(IR_FCEIL, 32, 32, 0, 0, 0); }
        else { ir_add(IR_FTRUNC, 32, 32, 0, 0, 0); }
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

// the offset in the data area of a literal that the text path placed (a literal of the tree is looked for among them), or -1
int gl_fidx;                     // the function being lowered (its number in fname)
int gl_lit(int sat, int slen) {
    int i = 0;
    while i < ll_n {
        if ll_used[i] == 0 && ll_fn[i] == gl_fidx && ll_len[i] == slen {
            int q = 0;
            while q < slen && ll_txt[ll_at[i] + q] == at_spool[sat + q] { q += 1; }
            if q == slen {
                ll_used[i] = 1;
                return ll_off[i];
            }
        }
        i += 1;
    }
    return 0 - 1;
}

// a call of a runtime helper with one argument in the register (v1, or f32 for a double)
void gl_rt1(char^ name, int reg) {
    gl_ensure();
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(name));
    gl_args[0] = reg;
    ir_set_args(e, 1, @gl_args);
}

// one item of a cout: the kind of what was printed goes to gl_lastw (9 a text, 2 a char, 8 else)
int gl_lastw;

void gl_cout_str(int it) {
    int off = gl_lit(at_val[it], at_b[it]);
    if off < 0 { gl_fail = 1; return; }
    gl_ensure();
    ir_add(IR_ADD, 1, 29, off, 1, 0);
    gl_rt1("j2k_print_str", 1);
    gl_lastw = 9;
}

void gl_cout_dbl(int it) {
    gl_expr_d(it);
    gl_ensure();
    ir_add(IR_F2BITS, 1, 32, 0, 0, 0);       // j2k_print_f64 takes the 64 bits in x0
    gl_rt1("j2k_print_f64", 1);
    gl_lastw = 8;
}

void gl_cout_int(int it) {
    gl_expr(it);
    if at_ty[it] / 65536 == 0 && at_ty[it] % 65536 == 2 {
        gl_rt1("j2k_print_char", 1);
        gl_lastw = 2;
    } else {
        gl_rt1("j2k_print_int", 1);
        gl_lastw = 8;
    }
}

void gl_cout(int n) {
    int it = at_a[n];
    int cnt = 0;
    gl_lastw = 8;
    while it != 0 {
        if at_kind[it] == AK_STR {
            gl_cout_str(it);
        } else if gl_isd(it) {
            gl_cout_dbl(it);
        } else {
            gl_cout_int(it);
        }
        cnt += 1;
        it = at_nx[it];
    }
    if cnt == 1 && gl_lastw != 9 && gl_lastw != 2 {
        gl_ensure();
        ir_add(IR_CONST, 1, 0, 0, 0, 10);
        gl_rt1("j2k_print_char", 1);
    }
}

void gl_for(int n) {
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

// store the value of the expression e (v1 / f32) as a field or element of the code, at base + off
void gl_put(int base, int off, int e, int code) {
    if code == 7 {
        gl_expr_d(e);
        gl_ensure();
        ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
    } else {
        gl_expr(e);
        gl_ensure();
    }
    int se = ir_add(IR_STORE, 0, base, 1, 0, off);
    ir_w[se] = as1_fbytes(code);
}

// the values of a list for the struct s go to base + off
void gl_slist(int lst, int s, int base, int off) {
    int it = at_a[lst];
    int k = 0;
    while k < snf[s] {
        int fi = sfirst[s] + k;
        if fldkind[fi] == 1 {
            int e = at_a[it];
            int c = 0;
            while e != 0 {
                gl_put(base, off + fldoff[fi] + c * as1_fbytes(fldcode[fi]), e, fldcode[fi]);
                c += 1;
                e = at_nx[e];
            }
        } else if fldcode[fi] >= 16 {
            gl_slist(it, fldcode[fi] - 16, base, off + fldoff[fi]);
        } else {
            gl_put(base, off + fldoff[fi], it, fldcode[fi]);
        }
        it = at_nx[it];
        k += 1;
    }
}

// the values of a list for an array of count elements of the width code (structs when code >= 16); what the list does not name is 0
void gl_alist(int lst, int code, int count, int base, int off) {
    int e = at_a[lst];
    int c = 0;
    int es = 8;
    if code >= 16 { es = ssize[code - 16]; } else { es = as1_fbytes(code); }
    while e != 0 {
        if code >= 16 { gl_slist(e, code - 16, base, off + c * es); } else { gl_put(base, off + c * es, e, code); }
        c += 1;
        e = at_nx[e];
    }
    if c < count {
        gl_ensure();
        ir_add(IR_CONST, 1, 0, 0, 0, 0);
        while c < count {
            if code >= 16 {
                int w = 0;
                while w < es {
                    gl_store(base, off + c * es + w, 1);
                    w += 8;
                }
            } else {
                int se = ir_add(IR_STORE, 0, base, 1, 0, off + c * es);
                ir_w[se] = es;
            }
            c += 1;
        }
    }
}

// the value of a constant pattern
int gl_pat(int p) {
    if at_kind[p] == AK_NEG { return 0 - at_val[at_a[p]]; }
    return at_val[p];
}

// switch: the tests in order, then the bodies; the default runs when nothing matched wherever it is written
void gl_switch(int n) {
    int slot = gl_bsl[n];
    gl_expr(at_a[n]);
    gl_ensure();
    gl_store(30, slot, 1);
    int lend = gl_label();
    int sdef = 0 - 1;
    int cs = at_b[n];
    int nc = 0;
    while cs != 0 {
        nc += 1;
        cs = at_nx[cs];
    }
    if nc > 256 { gl_fail = 1; return; }
    int lbl[256];
    cs = at_b[n];
    int ci = 0;
    while cs != 0 {
        lbl[ci] = gl_label();
        if at_a[cs] == 0 {
            sdef = lbl[ci];
        } else {
            int pt = at_a[cs];
            while pt != 0 {
                gl_load(1, 30, slot);
                ir_add(IR_CONST, 2, 0, 0, 0, gl_pat(pt));
                int lnext = gl_label();
                gl_br(IR_EQ, 1, 2, 0, lbl[ci], lnext);
                gl_place(lnext);
                pt = at_nx[pt];
            }
        }
        ci += 1;
        cs = at_nx[cs];
    }
    if sdef >= 0 { gl_jmp(sdef); } else { gl_jmp(lend); }
    cs = at_b[n];
    ci = 0;
    while cs != 0 {
        gl_place(lbl[ci]);
        gl_stmt(at_b[cs]);
        gl_jmp(lend);
        ci += 1;
        cs = at_nx[cs];
    }
    gl_place(lend);
}

void gl_stmt(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if k == AK_COUT {
        gl_cout(n);
        return;
    }
    if k == AK_SWITCH {
        gl_switch(n);
        return;
    }
    if k == AK_BLOCK {
        gl_block_list(at_a[n]);
        return;
    }
    if k == AK_DECL {
        if as1_arr(at_ty[n]) || as1_sarr(at_ty[n]) {
            if at_a[n] != 0 {
                int ecode = at_ty[n] % 65536;
                int ecnt = at_b[n];
                gl_alist(at_a[n], ecode, ecnt, 30, gl_off[at_val[n]]);
            }
            return;
        }
        if as1_sty(at_ty[n]) {
            if at_a[n] != 0 && at_kind[at_a[n]] == AK_LIST {
                gl_slist(at_a[n], at_ty[n] % 65536 - 16, 30, gl_off[at_val[n]]);
                return;
            }
            if at_a[n] != 0 {
                gl_saddr(at_a[n]);
                gl_ensure();
                gl_copy(30, gl_off[at_val[n]], 1, 0, ssize[at_ty[n] % 65536 - 16]);
            }
            return;
        }
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
        if as1_sty(at_ty[tgt]) {
            gl_assign_struct(tgt, at_a[n]);
            return;
        }
        if at_kind[tgt] == AK_INDEX || at_kind[tgt] == AK_DEREF || at_kind[tgt] == AK_FIELD { gl_assign_mem(tgt, at_a[n], at_b[n], 0); }
        else { gl_assign(tgt, at_a[n], at_b[n]); }
        return;
    }
    if k == AK_INCDEC {
        int tg = at_a[n];
        if at_kind[tg] == AK_INDEX || at_kind[tg] == AK_DEREF || at_kind[tg] == AK_FIELD {
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
        gl_for(n);
        return;
    }
    if k == AK_RET {
        if at_a[n] != 0 && as1_sty(at_ty[at_a[n]]) {
            // a struct result is written through the address that came in the hidden first parameter
            gl_saddr(at_a[n]);
            gl_ensure();
            gl_load(3, 30, gl_retoff);
            gl_copy(3, 0, 1, 0, ssize[at_ty[at_a[n]] % 65536 - 16]);
            gl_jmp(gl_ret);
            return;
        }
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

// the hidden slots of the results of calls that give a struct, in the order the parser makes them: a call makes its slot when its name
// is read (before its arguments); a method call after its object. The offset goes to the field c of the node.
void gl_tmps(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if k == AK_CALL || k == AK_METHOD {
        int fi = at_val[n];
        if k == AK_METHOD { gl_tmps(at_a[n]); }
        if fi >= 0 && fvoid[fi] == 0 && fret[fi] >= 100 {
            int sz = ssize[fret[fi] - 100];
            at_c[n] = gl_nslot;
            gl_hint_add2(gl_nslot, sz, 0);
            gl_nslot += (sz + 7) / 8 * 8;
        }
        int a = at_a[n];
        if k == AK_METHOD { a = at_b[n]; }
        while a != 0 {
            gl_tmps(a);
            a = at_nx[a];
        }
        return;
    }
    if k == AK_BIN || k == AK_INDEX { gl_tmps(at_a[n]); gl_tmps(at_b[n]); return; }
    if k == AK_NEG || k == AK_NOT || k == AK_CAST || k == AK_DEREF || k == AK_ADDR || k == AK_FIELD || k == AK_BUILTIN { gl_tmps(at_a[n]); }
    if k == AK_LIST {
        int li = at_a[n];
        while li != 0 {
            gl_tmps(li);
            li = at_nx[li];
        }
    }
}

void gl_slots(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if k == AK_BLOCK {
        int s = at_a[n];
        while s != 0 { gl_slots(s); s = at_nx[s]; }
    } else if k == AK_DECL {
        gl_tmps(at_a[n]);
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        if as1_arr(at_ty[n]) {
            int asz = at_b[n] * as1_bytes(at_ty[n] % 65536);
            gl_hint_add2(gl_nslot, asz, 0);
            gl_nslot += (asz + 7) / 8 * 8;
        } else if as1_sty(at_ty[n]) {
            int ssz = ssize[at_ty[n] % 65536 - 16];
            gl_hint_add2(gl_nslot, ssz, 0);
            gl_nslot += (ssz + 7) / 8 * 8;
        } else if as1_sarr(at_ty[n]) {
            int sasz = at_b[n] * ssize[at_ty[n] % 65536 - 16];
            gl_hint_add2(gl_nslot, sasz, 0);
            gl_nslot += (sasz + 7) / 8 * 8;
        } else {
            gl_hint_add(gl_nslot);
            gl_nslot += 8;
        }
    } else if k == AK_FOR {
        gl_tmps(at_a[n]);
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        gl_tmps(at_b[n]);
        gl_bsl[n] = gl_nslot;
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        gl_slots(at_c[n]);
    } else if k == AK_IF {
        gl_tmps(at_a[n]);
        gl_slots(at_b[n]);
        gl_slots(at_c[n]);
    } else if k == AK_WHILE {
        gl_tmps(at_a[n]);
        gl_slots(at_b[n]);
    } else if k == AK_SWITCH {
        gl_tmps(at_a[n]);
        gl_bsl[n] = gl_nslot;
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        int cs = at_b[n];
        while cs != 0 {
            gl_slots(at_b[cs]);
            cs = at_nx[cs];
        }
    } else if k == AK_ASSIGN {
        gl_tmps(at_c[n]);
        gl_tmps(at_a[n]);
    } else if k == AK_INCDEC {
        gl_tmps(at_a[n]);
    } else if k == AK_EXPR || k == AK_RET {
        gl_tmps(at_a[n]);
    } else if k == AK_COUT {
        int it = at_a[n];
        while it != 0 {
            gl_tmps(it);
            it = at_nx[it];
        }
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
    // the frame: what the parser had when the body began (the hidden slots and the parameters), then the locals as it declares them
    gl_nslot = at_fb[ti];
    str_copy(@gl_hint, @at_hint + ti * 256, 8000);
    gl_hint_n = str_len(@gl_hint);
    gl_fail = 0;
    int nl = at_nl[ti];
    int p = 0;
    while p < nl {
        gl_off[p] = at_loff[ti * 32 + p];
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
    // the registers go to their slots; a struct by value is copied from the address that came (the slot before it)
    p = 0;
    int rn = 0;
    while p < nl {
        if at_lk[ti * 32 + p] == 0 {
            gl_store(30, gl_off[p], rn + 1);
            rn += 1;
        }
        p += 1;
    }
    p = 0;
    while p < nl {
        int csz = at_lk[ti * 32 + p];
        if csz > 0 {
            gl_load(1, 30, gl_off[p - 1]);
            gl_copy(30, gl_off[p], 1, 0, csz);
        }
        p += 1;
    }
    gl_fidx = fi;
    p = 0;
    while p < ll_n {
        ll_used[p] = 0;
        p += 1;
    }
    gl_retoff = 0 - 1;
    if fvoid[fi] == 0 && fret[fi] >= 100 { gl_retoff = gl_off[0]; }
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
