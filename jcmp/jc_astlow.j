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
    if b == 1 || b == 2 || b == 3 { return 1; }
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
    return as1_el(b) || b == 3 || b == 10 || (b >= 400 && b < 416);      // 10: void^; 400 + n: a pointer to a pointer (both are only passed on and compared)
}

// a fixed array of whole numbers or doubles
bool as1_arr(int t) {
    if t / 65536 != 2 { return false; }
    int b = t % 65536;
    return as1_el(b) || b == 3;                    // an array of bool takes a byte for each
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

// a struct (or one inside it) with a free(self) method
bool as1_sfree(int s) {
    if struct_has_free(s) { return true; }
    int f = sfirst[s];
    int last = sfirst[s] + snf[s];
    while f < last {
        if fldcode[f] >= 16 && fldcode[f] < 400 && fldptr[f] == 0 && fldcode[f] - 16 != s && fldkind[f] == 0 {
            if as1_sfree(fldcode[f] - 16) { return true; }
        }
        f += 1;
    }
    return false;
}

// a struct that a local variable can be: no init(); a String, a dynamic array or a free(self) inside it starts as zeros
bool as1_sdecl(int s) {
    return s >= 0 && s < scount;
}

// does the struct have an init() (it runs where a variable of the struct is made without a value)?
bool as1_hasinit(int s) {
    if s < 0 || s >= scount { return false; }
    char hn[64];
    str_copy(@hn, @sname + s * 64, 64);
    str_copy(@hn + str_len(@hn), "__init", 8);
    return find_func(@hn) >= 0;
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

// a dynamic array of numbers (the elements are 1 i8, 2 char, 4 i32, 8 int, 7 double; its value is the address of the header)
bool as1_dyn(int t) {
    if t / 65536 != 5 { return false; }
    int b = t % 65536;
    // numbers, pointers (1000 + the code of what they point to) and members of enums (6000 + the type id): all 8 bytes except the numbers
    return as1_el(b) || (b >= 1000 && b < 1500) || (b >= 6003 && b < 6090) || b == 4008;
}

// an array of Strings: its elements are String headers (8 bytes)
bool as1_sdyn(int t) {
    return t / 65536 == 5 && t % 65536 == 4008;
}

// the width code of an element of the dynamic array of the type t
int as1_dcode(int t) {
    int b = t % 65536;
    if b < 1000 { return b; }
    return 8;
}

// a String or a dynamic array of numbers: both have the header [length, capacity, data]
bool as1_dynlike(int t) {
    return as1_dyn(t) || as1_sdyn(t) || t / 65536 == 4;
}

bool as1_dbl(int t) {
    return t / 65536 == 0 && t % 65536 == 7;
}

// the type id of a parameter or a result (fptid / fret): 0 a whole number, 1 bool, 91 double
// a struct that can be passed and returned by value: plain bytes, not too big
bool as1_sbyval(int s) {
    return as1_sdecl(s) && ssize[s] <= 128;
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
    if k == AK_VAR { return as1_pt(t) || as1_arr(t) || as1_sarr(t) || (as1_sty(t) && as1_sdecl(t % 65536 - 16)); }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 || gdyn[gi] != 0 { return false; }
        if gkind[gi] == 1 {
            if gptr[gi] != 0 || gnd[gi] < 1 || gnd[gi] > 3 { return false; }
            return ((as1_el(gelem[gi]) || gelem[gi] == 3) && as1_arr(t)) || (as1_scode(gelem[gi]) && as1_sarr(t));
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
    if k == AK_INDEX { return (as1_sty(t) || as1_arr(t)) && ast_c[n] == 0 && as1_base(ast_a[n]) && as1_index_ok(ast_b[n]); }
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
    if as1_dynlike(t) { return opt_debug == 0 && as1_dplace(n); }
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
    if str_eq(nm, "__panic") { return false; }          // a function of the prelude: a call
    return nm[0] == '_' && nm[1] == '_';
}

// the arguments from a2 go to the parameters from pk of the function fi
bool as1_args(int fi, int a2, int pk) {
    while a2 != 0 {
        if pk >= fnpar[fi] { return false; }
        int pt = fptid[fi * 8 + pk];
        if (farr[fi] >> pk) % 2 == 1 {
            // T name[]: a text (its bytes and length + 1) or an array variable (its address and its number of elements)
            int ak = ast_kind[a2];
            if ak == AK_STR { if ast_b[a2] >= 1000 || opt_debug == 1 { return false; } }
            else if ak == AK_VAR || ak == AK_GVAR { if !(as1_arr(ast_ty[a2]) || as1_sarr(ast_ty[a2])) { return false; } }
            else { return false; }
        } else if pt == 99 && fpstr[fi * 8 + pk] == 1 {
            // a String parameter (borrowed): a String variable, a text (a temporary String is made) or a new String
            if ast_ty[a2] / 65536 != 4 || !as1_sval(a2) { return false; }
        } else if pt == 99 {
            // a dynamic array: the variable (the callee borrows it)
            if !as1_dyn(ast_ty[a2]) || !as1_dplace(a2) { return false; }
        } else if pt >= 100 {
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

// the registers that the parameters take: an array parameter (T name[]) takes two (the address and the length)
int as1_nregs(int fi) {
    int n = fnpar[fi];
    int k = 0;
    while k < fnpar[fi] {
        if (farr[fi] >> k) % 2 == 1 { n += 1; }
        k += 1;
    }
    return n;
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
    if fi < 0 || fi >= fcount { return false; }
    if fretdyn[fi] != 0 && fretstr[fi] != 1 && !as1_dyn(ast_fn_ty(fi)) { return false; }
    if as1_nregs(fi) + as1_hidden(fi) > 8 { return false; }
    if fvoid[fi] == 0 && !as1_rtid(fret[fi]) && fretstr[fi] != 1 && fretdyn[fi] == 0 { return false; }
    if as1_special(@fname + fi * 64) { return false; }
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

// ---- Strings: a String is the address of a header that is built like the header of a dynamic array of chars
// an expression whose value is the same wherever it is worked out and that has no call in it: variables, fields, derefs, indexes by a
// number or a variable (a place is used twice: to read the header and to write it)
bool as1_pure(int n) {
    int k = ast_kind[n];
    if k == AK_VAR || k == AK_GVAR || k == AK_NUM { return true; }
    if k == AK_DEREF || k == AK_FIELD { return as1_pure(ast_a[n]); }
    if k == AK_INDEX || k == AK_BIN { return as1_pure(ast_a[n]) && as1_pure(ast_b[n]); }
    return false;
}

// a place that holds a String or a dynamic array of numbers: a variable (local or global) or a field of a struct
bool as1_dplace(int n) {
    int t = ast_ty[n];
    int k = ast_kind[n];
    if !(t / 65536 == 4 && t % 65536 == 8) && !as1_dyn(t) && !as1_sdyn(t) { return false; }
    if k == AK_VAR { return true; }
    if k == AK_INDEX {
        // an element of an array of Strings is a String place
        return t / 65536 == 4 && ast_c[n] == 0 && as1_sdyn(ast_ty[ast_a[n]]) && as1_dplace(ast_a[n]) && as1_pure(ast_b[n]) && as1_index_ok(ast_b[n]) && opt_debug == 0;
    }
    if k == AK_GVAR {
        int gi = ast_val[n];
        return gi >= 0 && gdyn[gi] != 0;
    }
    if k == AK_FIELD {
        int fi = ast_val[n];
        if fi < 0 || flddyn[fi] == 0 || fldkind[fi] != 3 || fldptr[fi] != 0 || opt_debug == 1 { return false; }
        return as1_pure(ast_a[n]) && as1_sty(ast_ty[ast_a[n]]) && as1_lv(ast_a[n]);
    }
    return false;
}

// a String place
bool as1_svarn(int n) {
    return ast_ty[n] / 65536 == 4 && as1_dplace(n);
}

// an operand of the String routines: a String value (a variable, a text, a new String) or a char
bool as1_sop(int n) {
    if n == 0 { return false; }
    if ast_ty[n] / 65536 == 4 { return as1_sval(n); }
    return as1_scalar(ast_ty[n]) && ast_ty[n] % 65536 == 2 && as1_expr(n);
}

// does an operand make a text, a char or a String (not an operation of the String routines): only these two are never both on one side of a +
bool as1_stext(int n) {
    return ast_kind[n] == AK_STR || (ast_ty[n] / 65536 != 4);
}

// a String value that the tree lowers: a variable, a text, a join (+) of those, slice / trim / upper / lower / repeat of a variable
bool as1_sval(int n) {
    if n == 0 || opt_debug == 1 { return false; }
    int k = ast_kind[n];
    if ast_ty[n] / 65536 != 4 { return false; }
    if k == AK_STR { return ast_b[n] < 1000; }
    if k == AK_VAR || k == AK_GVAR || k == AK_FIELD || k == AK_INDEX { return as1_dplace(n); }
    if k == AK_METHOD && as1_sdyn(ast_ty[ast_a[n]]) { return as1_samethod(n) == 2 || as1_samethod(n) == 10; }
    if k == AK_BUILTIN && ast_fop_of(ast_val[n]) == 13 {
        // str(x): a whole number (not an unsigned 64-bit one), a char, a double or a String
        int sa = ast_a[n];
        if sa == 0 || ast_nx[sa] != 0 { return false; }
        if ast_ty[sa] / 65536 == 4 { return as1_sval(sa) && ast_kind[sa] != AK_STR; }
        return as1_scalar(ast_ty[sa]) && as1_expr(sa) && ast_ty[sa] % 65536 != 13 && ast_ty[sa] % 65536 != 3;
    }
    if k == AK_CALL { return ast_val[n] >= 0 && fretstr[ast_val[n]] == 1 && as1_call(n); }
    if k == AK_METHOD && as1_sty(ast_ty[ast_a[n]]) { return as1_mfn(n) >= 0 && fretstr[as1_mfn(n)] == 1 && as1_method(n); }      // a method of a struct that gives a String
    if k == AK_BIN {
        if ast_val[n] != AO_ADD { return false; }
        int a = ast_a[n];
        int b = ast_b[n];
        // at least one side is a String that is not a text (a text and a char are not joined by the String routines)
        if as1_stext(a) && as1_stext(b) { return false; }
        return as1_sop(a) && as1_sop(b);
    }
    if k == AK_METHOD {
        int r = ast_a[n];
        if !as1_srecv(r) { return false; }
        char^ nm = @ast_pool + ast_val[n];
        int a2 = ast_b[n];
        int na = 0;
        int e = a2;
        while e != 0 {
            na += 1;
            e = ast_nx[e];
        }
        if str_eq(nm, "replace") { return na == 2 && as1_sop(a2) && as1_sop(ast_nx[a2]); }
        if str_eq(nm, "trim") || str_eq(nm, "upper") || str_eq(nm, "lower") { return na == 0; }
        if str_eq(nm, "repeat") { return na == 1 && as1_scalar(ast_ty[a2]) && !as1_dbl(ast_ty[a2]) && as1_expr(a2); }
        if str_eq(nm, "slice") {
            return na == 2 && as1_scalar(ast_ty[a2]) && !as1_dbl(ast_ty[a2]) && as1_expr(a2) && as1_scalar(ast_ty[ast_nx[a2]]) && !as1_dbl(ast_ty[ast_nx[a2]]) && as1_expr(ast_nx[a2]);
        }
        return false;
    }
    return false;
}

// does the String value make a new String (a temporary that the compiler frees at the end of the statement)?
bool as1_smk(int n) {
    int k = ast_kind[n];
    return k == AK_BIN || k == AK_METHOD || k == AK_CALL;
}

// a comparison with a String on a side
bool as1_scmp(int n) {
    int ao = ast_val[n];
    if !(ao >= AO_LT && ao <= AO_NE) { return false; }
    return as1_sop(ast_a[n]) && as1_sop(ast_b[n]) && !(as1_stext(ast_a[n]) && as1_stext(ast_b[n]));
}

// a member function of an array of Strings: 1 push(s) 2 pop() 3 insert(i, s) 4 remove(i) 5 clear() 6 sort() 7 contains(x) 8 index_of(x)
// 9 free() 10 join(sep) 11 resize(n); 0 when it is not one
int as1_samethod(int n) {
    int r = ast_a[n];
    if opt_debug == 1 || !as1_sdyn(ast_ty[r]) || !as1_dplace(r) { return 0; }
    char^ nm = @ast_pool + ast_val[n];
    int a = ast_b[n];
    int na = 0;
    int e = a;
    while e != 0 {
        na += 1;
        e = ast_nx[e];
    }
    if str_eq(nm, "push") { if na == 1 && ast_ty[a] / 65536 == 4 && as1_sval(a) { return 1; } return 0; }
    if str_eq(nm, "pop") { if na == 0 { return 2; } return 0; }
    if str_eq(nm, "insert") {
        if na == 2 && as1_scalar(ast_ty[a]) && !as1_dbl(ast_ty[a]) && as1_expr(a) && ast_ty[ast_nx[a]] / 65536 == 4 && as1_sval(ast_nx[a]) { return 3; }
        return 0;
    }
    if str_eq(nm, "remove") { if na == 1 && as1_scalar(ast_ty[a]) && !as1_dbl(ast_ty[a]) && as1_expr(a) { return 4; } return 0; }
    if str_eq(nm, "clear") { if na == 0 { return 5; } return 0; }
    if str_eq(nm, "sort") { if na == 0 { return 6; } return 0; }
    if str_eq(nm, "contains") { if na == 1 && as1_sop(a) { return 7; } return 0; }
    if str_eq(nm, "index_of") { if na == 1 && as1_sop(a) { return 8; } return 0; }
    if str_eq(nm, "free") { if na == 0 { return 9; } return 0; }
    if str_eq(nm, "join") { if na == 1 && as1_sop(a) { return 10; } return 0; }
    if str_eq(nm, "resize") { if na == 1 && as1_scalar(ast_ty[a]) && !as1_dbl(ast_ty[a]) && as1_expr(a) { return 11; } return 0; }
    return 0;
}

// a member function of a String variable that is a statement or gives a number or a char: 1 push(c), 2 pop(), 3 clear(), 4 append(x); 0 else
// a String value that a method may read: a variable (a place) or a new String (the temporary lives to the end of the statement)
bool as1_srecv(int r) {
    if ast_ty[r] / 65536 != 4 || ast_kind[r] == AK_STR { return false; }
    return as1_svarn(r) || as1_sval(r);
}

int as1_strmethod(int n) {
    int r = ast_a[n];
    if opt_debug == 1 || !as1_srecv(r) { return 0; }
    char^ nm = @ast_pool + ast_val[n];
    int a = ast_b[n];
    int na = 0;
    int e = a;
    while e != 0 {
        na += 1;
        e = ast_nx[e];
    }
    if str_eq(nm, "c") { if na == 0 { return 18; } return 0; }
    if str_eq(nm, "split") { if na == 1 && as1_sop(a) { return 20; } return 0; }
    if str_eq(nm, "replace") { if na == 2 && as1_sop(a) && as1_sop(ast_nx[a]) { return 19; } return 0; }
    bool mutating = str_eq(nm, "push") || str_eq(nm, "pop") || str_eq(nm, "clear") || str_eq(nm, "append") || str_eq(nm, "free");
    if mutating && !as1_svarn(r) { return 0; }
    if str_eq(nm, "push") {
        if na != 1 || !as1_scalar(ast_ty[a]) || as1_dbl(ast_ty[a]) || !as1_expr(a) { return 0; }
        return 1;
    }
    if str_eq(nm, "pop") { if na == 0 { return 2; } return 0; }
    if str_eq(nm, "clear") { if na == 0 { return 3; } return 0; }
    if str_eq(nm, "append") { if na == 1 && as1_sop(a) { return 4; } return 0; }
    if str_eq(nm, "find") { if na == 1 && as1_sop(a) { return 10; } return 0; }
    if str_eq(nm, "contains") { if na == 1 && as1_sop(a) { return 11; } return 0; }
    if str_eq(nm, "starts_with") { if na == 1 && as1_sop(a) { return 12; } return 0; }
    if str_eq(nm, "ends_with") { if na == 1 && as1_sop(a) { return 13; } return 0; }
    if str_eq(nm, "count") { if na == 0 { return 14; } return 0; }
    if str_eq(nm, "to_int") { if na == 0 { return 15; } return 0; }
    if str_eq(nm, "to_double") { if na == 0 { return 16; } return 0; }
    if str_eq(nm, "free") { if na == 0 { return 17; } return 0; }
    return 0;
}

// a member function of a dynamic array variable of numbers: 1 push(v), 2 pop(), 3 resize(n), 4 clear(), 5 free(); 0 when it is not one
int as1_dynmethod(int n) {
    int r = ast_a[n];
    if opt_debug == 1 || !as1_dyn(ast_ty[r]) || as1_sdyn(ast_ty[r]) || !as1_dplace(r) { return 0; }
    char^ nm = @ast_pool + ast_val[n];
    int a = ast_b[n];
    int na = 0;
    int e = a;
    while e != 0 {
        na += 1;
        e = ast_nx[e];
    }
    int code = as1_dcode(ast_ty[r]);
    if str_eq(nm, "push") {
        if na != 1 || !as1_expr(a) { return 0; }
        if (ast_ty[r] % 65536) >= 1000 && (ast_ty[r] % 65536) < 1500 {
            // a pointer (the array owns it afterwards when it was an owner)
            if as1_pt(ast_ty[a]) || (ast_kind[a] == AK_NUM && ast_val[a] == 0) || as1_callptr(a) { return 1; }
            return 0;
        }
        if !as1_scalar(ast_ty[a]) || as1_dbl(ast_ty[a]) != (code == 7) { return 0; }
        return 1;
    }
    if str_eq(nm, "pop") { if na == 0 { return 2; } return 0; }
    if str_eq(nm, "resize") {
        if na != 1 || !as1_scalar(ast_ty[a]) || as1_dbl(ast_ty[a]) || !as1_expr(a) { return 0; }
        return 3;
    }
    if str_eq(nm, "clear") { if na == 0 { return 4; } return 0; }
    if str_eq(nm, "free") { if na == 0 { return 5; } return 0; }
    if str_eq(nm, "sort") { if na == 0 && code != 6 { return 6; } return 0; }
    if str_eq(nm, "remove") {
        if na == 1 && as1_scalar(ast_ty[a]) && !as1_dbl(ast_ty[a]) && as1_expr(a) { return 7; }
        return 0;
    }
    bool isptr = (ast_ty[r] % 65536) >= 1000 && (ast_ty[r] % 65536) < 1500;
    if str_eq(nm, "insert") {
        if na != 2 || !as1_scalar(ast_ty[a]) || as1_dbl(ast_ty[a]) || !as1_expr(a) { return 0; }
        int v2 = ast_nx[a];
        if isptr { if as1_pt(ast_ty[v2]) && as1_expr(v2) { return 8; } return 0; }
        if as1_scalar(ast_ty[v2]) && as1_dbl(ast_ty[v2]) == (code == 7) && as1_expr(v2) { return 8; }
        return 0;
    }
    if str_eq(nm, "contains") || str_eq(nm, "index_of") {
        if na != 1 || !as1_expr(a) { return 0; }
        if isptr { if !as1_pt(ast_ty[a]) { return 0; } } else if !as1_scalar(ast_ty[a]) || as1_dbl(ast_ty[a]) != (code == 7) { return 0; }
        if str_eq(nm, "contains") { return 9; }
        return 10;
    }
    return 0;
}

// a method of a struct (its first parameter is the address of the struct) with parameters and a result of the subset
bool as1_method(int n) {
    if opt_debug == 1 { return false; }
    int fi = as1_mfn(n);
    if fi < 0 || fnpar[fi] < 1 { return false; }
    if fretdyn[fi] != 0 && fretstr[fi] != 1 && !as1_dyn(ast_fn_ty(fi)) { return false; }
    if fnpar[fi] + as1_hidden(fi) > 8 { return false; }
    if fvoid[fi] == 0 && !as1_rtid(fret[fi]) && fretstr[fi] != 1 && fretdyn[fi] == 0 { return false; }
    if farr[fi] != 0 || as1_special(@fname + fi * 64) { return false; }
    if fptid[fi * 8] != 0 || !as1_sx(ast_a[n]) { return false; }      // the object: a variable, or a struct that a call made
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

// a.len of a fixed array: a variable (a local, a global) or a field of a struct, one dimension
bool as1_fixed_len(int n) {
    int dr = ast_a[n];
    if opt_debug == 1 || !(as1_arr(ast_ty[dr]) || as1_sarr(ast_ty[dr])) { return false; }
    if !str_eq(@ast_pool + ast_b[n] - 1, "len") { return false; }
    int k = ast_kind[dr];
    if k == AK_VAR || k == AK_GVAR { return as1_var_ok(dr); }
    if k == AK_FIELD {
        int fi = ast_val[dr];
        return fi >= 0 && fldkind[fi] == 1 && fldnd[fi] == 1 && fldcnt[fi] > 0 && as1_lv(dr);
    }
    return false;
}

bool as1_expr(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    int ty = ast_ty[n];
    if k == AK_STR { return ast_b[n] < 1000 && opt_debug == 0; }      // a text where a `char^` is wanted: the address of its bytes
    if !as1_val(ty) { return false; }
    if k == AK_NUM { return as1_scalar(ty) || (as1_pt(ty) && ast_val[n] == 0); }
    if k == AK_FNUM { return true; }
    if k == AK_ENUMV { return as1_enumv(n); }
    if k == AK_BUILTIN {
        // __fsqrt / __ffloor / __fceil / __ftrunc of a double
        int a1 = ast_a[n];
        int bo = ast_fop_of(ast_val[n]);
        if bo == 5 {
            // alloc(bytes): a call of Mem__alloc (the -d build tells where the block was made: the text path)
            return opt_debug == 0 && a1 != 0 && ast_nx[a1] == 0 && as1_scalar(ast_ty[a1]) && !as1_dbl(ast_ty[a1]) && as1_expr(a1) && find_func("Mem__alloc") >= 0;
        }
        if bo == 14 {
            // move(p): the pointer variable gives its memory away (it is null afterwards)
            return a1 != 0 && ast_nx[a1] == 0 && ast_kind[a1] == AK_VAR && as1_pt(ast_ty[a1]) && as1_expr(a1) && opt_debug == 0;
        }
        if bo == 11 { return a1 == 0 && opt_debug == 0; }
        if bo == 12 { return a1 != 0 && ast_nx[a1] == 0 && as1_scalar(ast_ty[a1]) && !as1_dbl(ast_ty[a1]) && as1_expr(a1) && opt_debug == 0; }
        if bo == 9 {
            // __hash(x): a String or a whole number / pointer
            if a1 == 0 || ast_nx[a1] != 0 || opt_debug == 1 { return false; }
            if ast_ty[a1] / 65536 == 4 { return as1_sval(a1); }
            return as1_expr(a1) && !as1_dbl(ast_ty[a1]);
        }
        if bo == 8 {
            // syscall(number, up to 6 arguments): whole numbers and pointers (a text is its address)
            int sc = 0;
            int sa = a1;
            while sa != 0 {
                if !as1_expr(sa) || as1_dbl(ast_ty[sa]) { return false; }
                sc += 1;
                sa = ast_nx[sa];
            }
            return opt_debug == 0 && sc >= 1 && sc <= 7;
        }
        return bo >= 1 && bo <= 4 && a1 != 0 && ast_nx[a1] == 0 && as1_dbl(ast_ty[a1]) && as1_expr(a1);
    }
    if k == AK_VAR { return as1_scalar(ty) || as1_pt(ty); }
    if k == AK_FIELD && ast_val[n] < 0 && as1_fixed_len(n) { return true; }
    if k == AK_FIELD && ast_val[n] < 0 {
        // a.len, a.cap of a dynamic array variable
        int dr = ast_a[n];
        if opt_debug == 1 || !as1_scalar(ty) { return false; }
        // a variable of a dynamic array or a String, or a String that is made (a call, a join ...)
        if !(as1_dynlike(ast_ty[dr]) && as1_dplace(dr)) && !(ast_ty[dr] / 65536 == 4 && ast_kind[dr] != AK_STR && as1_sval(dr)) { return false; }
        char^ dm = @ast_pool + ast_b[n] - 1;
        return str_eq(dm, "len") || str_eq(dm, "cap");
    }
    if k == AK_FIELD {
        int fi = ast_val[n];
        if opt_debug == 1 || fi < 0 || fldkind[fi] != 0 || flddyn[fi] != 0 || !as1_sty(ast_ty[ast_a[n]]) { return false; }
        if as1_pt(ty) { if fldptr[fi] == 0 { return false; } } else if fldptr[fi] != 0 { return false; }
        return as1_lv(ast_a[n]) || ((ast_kind[ast_a[n]] == AK_CALL || ast_kind[ast_a[n]] == AK_METHOD) && as1_sx(ast_a[n]));
    }
    if k == AK_GVAR {
        int gi = ast_val[n];
        if gi < 0 { return false; }
        if as1_pt(ty) { return as1_var_ok(n); }
        return gkind[gi] == 0 && (as1_el(gelem[gi]) || gelem[gi] == 3) && gptr[gi] == 0 && gdyn[gi] == 0 && as1_tid(gtid[gi]);
    }
    if k == AK_INDEX {
        if opt_debug == 1 || ast_c[n] != 0 { return false; }
        if !as1_scalar(ty) && !(as1_pt(ty) && as1_dyn(ast_ty[ast_a[n]]) && as1_dplace(ast_a[n])) { return false; }
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
            if tk == AK_VAR { return (as1_scalar(tt) && !(tt % 65536 == 3)) || as1_arr(tt) || as1_ptr(tt); }
            int gi2 = ast_val[t];
            if gi2 < 0 || gdyn[gi2] != 0 || gptr[gi2] != 0 || !as1_el(gelem[gi2]) { return false; }
            return (gkind[gi2] == 0 && as1_scalar(tt) && as1_tid(gtid[gi2])) || (gkind[gi2] == 1 && gnd[gi2] == 1);
        }
        if tk == AK_INDEX { return as1_expr(t); }
        return false;
    }
    if k == AK_BIN && (ast_ty[ast_a[n]] / 65536 == 5 || ast_ty[ast_b[n]] / 65536 == 5) {
        // a dynamic array is compared with null (0) or with another array: the addresses of the headers
        int dao = ast_val[n];
        if dao != AO_EQ && dao != AO_NE { return false; }
        int da = ast_a[n];
        int db = ast_b[n];
        bool oka = (as1_dyn(ast_ty[da]) && as1_dplace(da)) || (ast_kind[da] == AK_NUM && ast_val[da] == 0);
        bool okb = (as1_dyn(ast_ty[db]) && as1_dplace(db)) || (ast_kind[db] == AK_NUM && ast_val[db] == 0);
        return oka && okb;
    }
    if k == AK_BIN && (ast_ty[ast_a[n]] / 65536 == 4 || ast_ty[ast_b[n]] / 65536 == 4) { return as1_scmp(n); }
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
        // (T^)x : a pointer from a pointer or a whole number (the address is the same)
        if as1_pt(ty) { return (as1_pt(ast_ty[ast_a[n]]) || (as1_scalar(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_a[n]]))) && as1_expr(ast_a[n]); }
        return (tc == 7 || as1_el(tc)) && (as1_scalar(ast_ty[ast_a[n]]) || (tc != 7 && as1_pt(ast_ty[ast_a[n]]))) && as1_expr(ast_a[n]);      // a pointer to a whole number: the address
    }
    if k == AK_CALL { return as1_call(n); }
    if k == AK_METHOD {
        if as1_dyn(ast_ty[ast_a[n]]) && !as1_sdyn(ast_ty[ast_a[n]]) { int dm2 = as1_dynmethod(n); return dm2 == 2 || dm2 == 9 || dm2 == 10; }
        if ast_ty[ast_a[n]] / 65536 == 4 {
            int sm2 = as1_strmethod(n);
            return sm2 == 2 || (sm2 >= 10 && sm2 <= 16) || sm2 == 18;
        }
        if as1_sdyn(ast_ty[ast_a[n]]) {
            int sa2 = as1_samethod(n);
            return sa2 == 7 || sa2 == 8;
        }
        return as1_method(n) && fvoid[as1_mfn(n)] == 0;
    }
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
    return (k == AK_CALL || k == AK_METHOD || k == AK_BUILTIN) && as1_scalar(ast_ty[n]) && !as1_dbl(ast_ty[n]);
}

// a dynamic array value: a place, arr(n), or a call that returns one
bool as1_dynval(int v) {
    if ast_kind[v] == AK_NUM && ast_val[v] == 0 { return true; }              // null
    if as1_dyn(ast_ty[v]) && as1_dplace(v) { return true; }
    if ast_kind[v] == AK_CALL { return as1_dyn(ast_ty[v]) && as1_call(v); }
    if ast_kind[v] == AK_METHOD && as1_sty(ast_ty[ast_a[v]]) { return as1_dyn(ast_ty[v]) && as1_method(v); }      // a method of a struct that gives a list
    if ast_kind[v] == AK_METHOD && ast_ty[ast_a[v]] / 65536 == 4 { return as1_dyn(ast_ty[v]) && as1_strmethod(v) == 20; }        // text.split(sep): a new list of Strings
    if ast_kind[v] == AK_BUILTIN && ast_fop_of(ast_val[v]) == 7 {
        int na0 = ast_a[v];
        return opt_debug == 0 && na0 != 0 && ast_nx[na0] == 0 && as1_scalar(ast_ty[na0]) && !as1_dbl(ast_ty[na0]) && as1_expr(na0);
    }
    return false;
}

// one value of a list: an expression (not a list) of the kind of the element
bool as1_item(int e, int code) {
    return ast_kind[e] != AK_LIST && as1_scalar(ast_ty[e]) && as1_expr(e) && as1_dbl(ast_ty[e]) == (code == 7);
}

// a list of values for the struct s: the fields in order, a list for a field that is a struct or an array
bool as1_slist(int lst, int s) {
    if lst == 0 || ast_kind[lst] != AK_LIST || struct_needs_zero(s) { return false; }
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
            if ast_kind[init] == AK_STR && ast_b[n] < 0 { return dt % 65536 == 2 && ast_b[init] < 1000 && opt_debug == 0; }
            if ast_kind[init] == AK_STR { return dt % 65536 == 2 && ast_b[n] > 0 && ast_b[n] < 65536 && ast_b[init] < ast_b[n] && ast_b[init] < 1000 && opt_debug == 0; }
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
        if dt / 65536 == 4 && dt % 65536 == 8 {
            // a String: empty, or from a text, another String (a copy) or a new String (taken over)
            return opt_debug == 0 && (init == 0 || as1_sval(init));
        }
        if as1_dyn(dt) {
            // no value (null), a new array arr(n), or another dynamic array variable (the same array)
            if init == 0 { return true; }
            return as1_dynval(init);
        }
        if as1_sty(dt) {
            if init == 0 { return as1_sdecl(dt % 65536 - 16); }
            if !as1_sbyval(dt % 65536 - 16) { return false; }
            // no value, a list, or a struct of the same type (a variable, a field, an element or a call)
            if init != 0 && ast_kind[init] == AK_LIST { return as1_slist(init, dt % 65536 - 16); }
            return init == 0 || (ast_ty[init] == dt && as1_sx(init));
        }
        if as1_sarr(dt) {
            int ss = dt % 65536 - 16;
            if struct_needs_zero(ss) { return false; }
            if as1_hasinit(ss) && (init != 0 || ast_b[n] > 64) { return false; }
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
            return as1_expr(pv) && (as1_pt(ast_ty[pv]) || ast_kind[pv] == AK_STR || (ast_kind[pv] == AK_NUM && ast_val[pv] == 0) || as1_callptr(pv));
        }
        if !as1_scalar(dt) { return false; }
        if ast_a[n] == 0 { return true; }
        // the value has the type of the variable
        return as1_expr(ast_a[n]) && as1_val(ast_ty[ast_a[n]]) && !as1_pt(ast_ty[ast_a[n]]) && as1_dbl(ast_ty[ast_a[n]]) == as1_dbl(dt);
    return false;
}

bool as1_assign(int n) {
    int k = ast_kind[n];
        if ast_ty[ast_c[n]] / 65536 == 4 {
            // = a String / text / new String, += a String, a text or a char; the target is a local String that owns its memory
            int sv = ast_a[n];
            if !as1_svarn(ast_c[n]) || opt_debug == 1 { return false; }
            if ast_b[n] == 0 { return as1_sval(sv); }
            return ast_b[n] == AO_ADD && as1_sop(sv);
        }
        if as1_dyn(ast_ty[ast_c[n]]) {
            // a dynamic array place gets another place (the same array) or a new array arr(n); nothing is freed
            int dv = ast_a[n];
            if !as1_dplace(ast_c[n]) || ast_b[n] != 0 || opt_debug == 1 { return false; }
            return as1_dynval(dv);
        }
        int t = ast_c[n];
        if as1_sty(ast_ty[t]) {
            // a struct is copied: the target has an address, the value is a struct of the same type
            if struct_has_free(ast_ty[t] % 65536 - 16) {
                // the old content is freed, the new one is moved in: from a local variable (emptied afterwards) or a call
                int vk = ast_kind[ast_a[n]];
                if vk != AK_VAR && vk != AK_CALL { return false; }
            }
            return ast_b[n] == 0 && as1_lv(t) && as1_sbyval(ast_ty[t] % 65536 - 16) && ast_ty[ast_a[n]] == ast_ty[t] && as1_sx(ast_a[n]);
        }
        if !as1_target(t) || !as1_expr(ast_a[n]) || ast_b[n] < 0 { return false; }
        bool td = as1_dbl(ast_ty[t]);
        int opc = ast_b[n];
        if as1_pt(ast_ty[t]) {
            // a pointer gets a pointer of the same kind or 0
            int pv2 = ast_a[n];
            return opc == 0 && as1_expr(pv2) && (as1_pt(ast_ty[pv2]) || ast_kind[pv2] == AK_STR || (ast_kind[pv2] == AK_NUM && ast_val[pv2] == 0) || as1_callptr(pv2));
        }
        if as1_pt(ast_ty[ast_a[n]]) { return false; }
        if td { return (opc == 0 || as1_arith(opc)) && as1_dbl(ast_ty[ast_a[n]]) == (td || true); }
        return !as1_dbl(ast_ty[ast_a[n]]);
    return false;
}

int as1_fretdyn;                 // 1 when the function being looked at returns a dynamic array of numbers
int as1_fretstr;                 // 1 when the function being looked at returns a String
int as1_fret;                    // the struct that the function being looked at returns (its number), else -1

// for x in things { }: the elements of a dynamic array (numbers, pointers, members of enums, Strings), the chars of a String, a fixed array
// of numbers; a list that a call made is freed after the loop
bool as1_foreach(int n) {
    int sq = ast_a[n];
    int st = ast_ty[sq];
    int kd = st / 65536;
    int bs = st % 65536;
    if opt_debug == 1 || !as1_stmt(ast_c[n]) { return false; }
    if kd == 4 { return bs == 8 && as1_dplace(sq) && ast_kind[sq] != AK_INDEX; }
    if kd == 5 {
        if !as1_dyn(st) { return false; }
        if as1_dplace(sq) { return true; }
        return as1_dynval(sq) && (ast_kind[sq] == AK_CALL || ast_kind[sq] == AK_METHOD);
    }
    if kd == 2 && (bs == 8 || bs == 7 || bs == 2 || bs == 4) {
        return (ast_kind[sq] == AK_VAR || ast_kind[sq] == AK_GVAR) && as1_arr(st);
    }
    return false;
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
    if k == AK_DECL { return as1_decl(n); }
    if k == AK_ASSIGN { return as1_assign(n); }
    if k == AK_INCDEC { return as1_target(ast_a[n]) && as1_scalar(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_a[n]]); }
    if k == AK_EXPR {
        int ex = ast_a[n];
        if ast_kind[ex] == AK_BUILTIN && ast_fop_of(ast_val[ex]) == 6 {
            // free(p)
            int fa = ast_a[ex];
            return opt_debug == 0 && fa != 0 && ast_nx[fa] == 0 && as1_pt(ast_ty[fa]) && as1_expr(fa) && find_func("Mem__free") >= 0;
        }
        if ast_kind[ex] == AK_METHOD && as1_dyn(ast_ty[ast_a[ex]]) && !as1_sdyn(ast_ty[ast_a[ex]]) { return as1_dynmethod(ex) != 0; }
        if ast_kind[ex] == AK_METHOD && ast_ty[ast_a[ex]] / 65536 == 4 { return as1_strmethod(ex) != 0; }
        if ast_kind[ex] == AK_METHOD && as1_sdyn(ast_ty[ast_a[ex]]) { return as1_samethod(ex) != 0; }
        if ast_kind[ex] == AK_BUILTIN && (ast_fop_of(ast_val[ex]) >= 8 || ast_fop_of(ast_val[ex]) == 5) { return as1_expr(ex); }      // the result is not used
        return (ast_kind[ex] == AK_CALL && as1_call(ex)) || (ast_kind[ex] == AK_METHOD && as1_method(ex));
    }
    if k == AK_IF { return as1_expr(ast_a[n]) && as1_stmt(ast_b[n]) && as1_stmt(ast_c[n]); }
    if k == AK_WHILE { return ast_val[n] == 0 && ast_c[n] == 0 && as1_expr(ast_a[n]) && as1_stmt(ast_b[n]); }
    if k == AK_FOR && ast_b[n] == 0 { return as1_foreach(n); }
    if k == AK_FOR { return ast_b[n] != 0 && as1_expr(ast_a[n]) && as1_expr(ast_b[n]) && !as1_dbl(ast_ty[ast_a[n]]) && !as1_dbl(ast_ty[ast_b[n]]) && as1_stmt(ast_c[n]); }
    if k == AK_RET {
        if ast_a[n] == 0 { return true; }
        if as1_sty(ast_ty[ast_a[n]]) { return as1_fret >= 0 && ast_ty[ast_a[n]] == 3 * 65536 + 16 + as1_fret && as1_sx(ast_a[n]); }
        if as1_fret >= 0 || as1_fretstr == 1 || as1_fretdyn == 1 { if !(ast_ty[ast_a[n]] / 65536 == 4 || ast_ty[ast_a[n]] / 65536 == 5) { return false; } }      // the result is a struct, a String or an array: the value must be one too
        if ast_ty[ast_a[n]] / 65536 == 4 { return as1_fretstr == 1 && as1_sval(ast_a[n]); }
        if ast_ty[ast_a[n]] / 65536 == 5 { return as1_fretdyn == 1 && as1_dynval(ast_a[n]); }
        return as1_expr(ast_a[n]);
    }
    if k == AK_BREAK || k == AK_CONT { return true; }
    if k == AK_THROW {
        // throw "text";  or a char^ (the nearest catch gets the text)
        int tv = ast_a[n];
        if tv == 0 { return false; }
        if ast_kind[tv] == AK_STR { return ast_b[tv] < 1000; }
        return as1_ptr(ast_ty[tv]) && ast_ty[tv] % 65536 == 2 && as1_expr(tv);
    }
    if k == AK_TRYCATCH { return as1_stmt(ast_a[n]) && as1_stmt(ast_b[n]); }
    if k == AK_SWITCH && ast_val[n] == 1 {
        // a data enum (a struct with a tag in its first word): the cases are members; the names they bind are copies of the values
        int ds = ast_a[n];
        if !as1_sty(ast_ty[ds]) || !(as1_lv(ds) || ((ast_kind[ds] == AK_CALL || ast_kind[ds] == AK_METHOD) && as1_sx(ds))) || opt_debug == 1 { return false; }
        int dcs = ast_b[n];
        if dcs == 0 { return false; }
        while dcs != 0 {
            int bn = ast_c[dcs];
            while bn != 0 {
                int bt = ast_ty[bn];
                bool bok = as1_scalar(bt) || as1_pt(bt) || bt / 65536 == 4 || as1_dyn(bt);
                if bt / 65536 == 3 && as1_scode(bt % 65536) && as1_splain(bt % 65536 - 16) && !struct_has_free(bt % 65536 - 16) { bok = true; }      // a value that frees itself is moved out of the enum: the text path
                if !bok { return false; }
                bn = ast_nx[bn];
            }
            if !as1_stmt(ast_b[dcs]) { return false; }
            dcs = ast_nx[dcs];
        }
        return true;
    }
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
            if ast_kind[it] != AK_STR && ast_ty[it] / 65536 == 4 {
                if !as1_sval(it) { return false; }
            } else if as1_ptr(ast_ty[it]) && ast_ty[it] % 65536 == 2 && ast_kind[it] != AK_STR {
                // a char^: the characters up to the 0 (a catch variable, the result of c())
                if !as1_expr(it) { return false; }
            } else if (ast_kind[it] == AK_VAR || ast_kind[it] == AK_GVAR) && as1_arr(ast_ty[it]) && ast_ty[it] % 65536 == 2 && as1_var_ok(it) {
                // a local array of chars: printed up to the 0
            } else if ast_kind[it] != AK_STR {
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
    if k == AK_METHOD || k == AK_SWITCH { return 3; }
    if k == AK_CASE { return 7; }
    if k == AK_COUT || k == AK_LIST || k == AK_BUILTIN || k == AK_THROW { return 1; }
    if k == AK_TRYCATCH { return 3; }
    return 0;
}

// the kinds of nodes that the lowering knows
bool as1_kind_ok(int k) {
    if k == AK_NUM || k == AK_FNUM || k == AK_VAR || k == AK_GVAR || k == AK_INDEX || k == AK_DEREF || k == AK_ADDR || k == AK_FIELD { return true; }
    if k == AK_BIN || k == AK_NEG || k == AK_NOT || k == AK_CAST || k == AK_CALL || k == AK_DECL || k == AK_ASSIGN || k == AK_INCDEC { return true; }
    if k == AK_STR || k == AK_COUT || k == AK_ENUMV || k == AK_METHOD || k == AK_SWITCH || k == AK_CASE || k == AK_THROW || k == AK_TRYCATCH { return true; }
    return k == AK_EXPR || k == AK_IF || k == AK_WHILE || k == AK_FOR || k == AK_RET || k == AK_BREAK || k == AK_CONT || k == AK_BLOCK;
}

int at_rej_n;

// is this node a value (not a statement)?
bool at_isexpr(int k) {
    return k == AK_NUM || k == AK_FNUM || k == AK_VAR || k == AK_GVAR || k == AK_BIN || k == AK_NEG || k == AK_NOT || k == AK_CALL || k == AK_INDEX || k == AK_DEREF || k == AK_ADDR || k == AK_CAST || k == AK_STR || k == AK_FIELD || k == AK_METHOD || k == AK_BUILTIN || k == AK_ENUMV || k == AK_LIST;
}

// does the lowering take this value, in any of the ways a value is taken (a number, a String, a list, a struct, a place)?
bool at_value_ok(int n) {
    int k = ast_kind[n];
    int t = ast_ty[n];
    if k == AK_STR || k == AK_LIST || k == AK_ENUMV { return true; }
    if (k == AK_VAR || k == AK_GVAR) && (t / 65536 == 2 || t / 65536 == 3) && as1_var_ok(n) { return true; }      // an array or a struct variable is a base, not a value
    if as1_expr(n) { return true; }
    if t / 65536 == 4 && as1_sval(n) { return true; }
    if as1_dyn(t) || as1_sdyn(t) { if as1_dplace(n) || as1_dynval(n) { return true; } }
    if as1_sty(t) && as1_sx(n) { return true; }
    return false;
}

// -ast2: the smallest value inside n that the lowering does not take (0: none, or n itself is the statement)
int at_culprit(int n) {
    if n == 0 || !at_isexpr(ast_kind[n]) { return 0; }
    int fl = at_fields(ast_kind[n]);
    int r = 0;
    if (fl & 1) != 0 {
        int c = ast_a[n];
        while c != 0 && at_isexpr(ast_kind[c]) {
            r = at_culprit(c);
            if r != 0 { return r; }
            c = ast_nx[c];
        }
    }
    if (fl & 2) != 0 {
        int c2 = ast_b[n];
        while c2 != 0 && at_isexpr(ast_kind[c2]) {
            r = at_culprit(c2);
            if r != 0 { return r; }
            c2 = ast_nx[c2];
        }
    }
    if !at_value_ok(n) { return n; }
    return 0;
}

// the line "  culprit: ..." under a statement that is not taken
void at_say_culprit(int n) {
    int cn = 0;
    int k = ast_kind[n];
    if k == AK_DECL || k == AK_EXPR || k == AK_RET || k == AK_ASSIGN || k == AK_COUT {
        int c = ast_a[n];
        while c != 0 && cn == 0 {
            cn = at_culprit(c);
            c = ast_nx[c];
        }
        if cn == 0 && k == AK_ASSIGN { cn = at_culprit(ast_c[n]); }
    }
    if cn != 0 {
        write_err("  culprit: ");
        ast_olen = 0;
        ast_pexpr(cn);
        syscall(64, 2, @ast_obuf, ast_olen);
        write_err(" [kind ");
        write_err_int(ast_kind[cn]);
        write_err(", type ");
        write_err_int(ast_ty[cn] / 65536);
        write_err(":");
        write_err_int(ast_ty[cn] % 65536);
        write_err("]\n");
    }
}

// -ast2: the first statement that the lowering does not take, printed as the tree prints it
bool at_bad(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    if k == AK_BLOCK {
        int c = ast_a[n];
        while c != 0 {
            if at_bad(c) { return true; }
            c = ast_nx[c];
        }
        return false;
    }
    if k == AK_IF || k == AK_WHILE {
        if !as1_expr(ast_a[n]) {
            write_err("  cond: ");
            ast_olen = 0;
            ast_pexpr(ast_a[n]);
            syscall(64, 2, @ast_obuf, ast_olen);
            write_err("\n");
            return true;
        }
        if at_bad(ast_b[n]) { return true; }
        if k == AK_IF { return at_bad(ast_c[n]); }
        return false;
    }
    if k == AK_FOR {
        if at_bad(ast_c[n]) { return true; }
        if !as1_stmt(n) {
            write_err("  for: the bounds\n");
            return true;
        }
        return false;
    }
    if k == AK_TRYCATCH { return at_bad(ast_a[n]) || at_bad(ast_b[n]); }
    if k == AK_SWITCH {
        int cs = ast_b[n];
        while cs != 0 {
            if at_bad(ast_b[cs]) { return true; }
            cs = ast_nx[cs];
        }
    }
    if !as1_stmt(n) {
        write_err("  stmt: ");
        ast_olen = 0;
        ast_pstmt(n, 0);
        syscall(64, 2, @ast_obuf, ast_olen);
        at_say_culprit(n);
        return true;
    }
    return false;
}

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
    if why[0] == 'n' { at_bad(ast_root); }
}

// every local that the parser had when the body began and that is a dynamic array or a String is a dynamic array of numbers
bool as1_dynparams() {
    int i = 0;
    while i < lcount && i < ast_nl {
        if (ast_lkind[i] == 4 && opt_debug == 1) || (ast_lkind[i] == 5 && !as1_el(ast_lbase[i])) { return false; }
        i += 1;
    }
    return true;
}

// called at the end of ast_probe for a body that is in the tree's subset: keep it when it is in the subset of the lowering
void at_store(int f_idx) {
    if ast_lower_on == 0 || at_nfn >= AT_FUNCS || at_n + ast_n + 2 >= AT_MAX { return; }
    // the function: parameters of whole numbers, bool or double, a result of those or nothing
    if as1_nregs(f_idx) + as1_hidden(f_idx) > 8 || (fretdyn[f_idx] != 0 && fretstr[f_idx] != 1 && !as1_dyn(ast_fn_ty(f_idx))) {
        at_rej_n = fnpar[f_idx] * 1000 + fretdyn[f_idx] * 100 + fcharret[f_idx] * 10 + farr[f_idx];
        at_reject(f_idx, "signature");
        return;
    }
    int pk = 0;
    while pk < fnpar[f_idx] {
        if (farr[f_idx] >> pk) % 2 == 1 { pk += 1; continue; }
        if fptid[f_idx * 8 + pk] == 99 && as1_dynparams() { pk += 1; continue; }
        if !as1_ptid(fptid[f_idx * 8 + pk]) { at_rej_n = fptid[f_idx * 8 + pk]; at_reject(f_idx, "parameter"); return; }
        pk += 1;
    }
    if fvoid[f_idx] == 0 && !as1_rtid(fret[f_idx]) && fretstr[f_idx] != 1 && fretdyn[f_idx] == 0 { at_rej_n = fret[f_idx]; at_reject(f_idx, "result"); return; }
    if lcount > 32 || hint_len > 250 || hint_len >= 16383 { at_rej_n = lcount; at_reject(f_idx, "signature"); return; }
    as1_fret = 0 - 1;
    as1_fretstr = 0;
    as1_fretdyn = 0;
    if fvoid[f_idx] == 0 && fretstr[f_idx] == 1 { as1_fretstr = 1; }
    if fvoid[f_idx] == 0 && fretdyn[f_idx] != 0 && fretstr[f_idx] != 1 { as1_fretdyn = 1; }
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
        if k == AK_METHOD && as1_dyn(ast_ty[ast_a[i]]) && !as1_sdyn(ast_ty[ast_a[i]]) {
            at_val[base + i] = 1000 + as1_dynmethod(i);
        }
        if k == AK_METHOD && as1_sdyn(ast_ty[ast_a[i]]) { at_val[base + i] = 3000 + as1_samethod(i); }
        if k == AK_METHOD && ast_ty[ast_a[i]] / 65536 == 4 {
            // 2000 + 1..4 the statements and pop, 2005 slice, 2006 trim, 2007 upper, 2008 lower, 2009 repeat
            int sm = as1_strmethod(i);
            if sm == 0 && as1_sval(i) {
                char^ smn = @ast_pool + ast_val[i];
                if str_eq(smn, "slice") { sm = 5; }
                if str_eq(smn, "trim") { sm = 6; }
                if str_eq(smn, "upper") { sm = 7; }
                if str_eq(smn, "lower") { sm = 8; }
                if str_eq(smn, "repeat") { sm = 9; }
            }
            at_val[base + i] = 2000 + sm;
        }
        if k == AK_FIELD && ast_val[i] < 0 && as1_fixed_len(i) {
            // the number of elements: a field and a global know it now, a local gets it when its declaration is lowered
            int fdr = ast_a[i];
            at_val[base + i] = 0 - 4;
            if ast_kind[fdr] == AK_FIELD { at_c[base + i] = fldcnt[ast_val[fdr]]; }
            else if ast_kind[fdr] == AK_GVAR { at_c[base + i] = gcnt[ast_val[fdr]]; if gnd[ast_val[fdr]] > 1 && gst1[ast_val[fdr]] > 0 { at_c[base + i] = gcnt[ast_val[fdr]] / gst1[ast_val[fdr]]; } }
            else { at_val[base + i] = 0 - 5; }
        } else if k == AK_FIELD && ast_val[i] < 0 && as1_dynlike(ast_ty[ast_a[i]]) {
            at_val[base + i] = 0 - 2;                                 // .len
            if str_eq(@ast_pool + ast_b[i] - 1, "cap") { at_val[base + i] = 0 - 3; }
        }
        if k == AK_BUILTIN { at_val[base + i] = ast_fop_of(ast_val[i]); }
        if k == AK_DECL && ast_b[i] < 0 && ast_a[i] != 0 && ast_kind[ast_a[i]] == AK_LIST { at_b[base + i] = as1_count(ast_a[i]); }
        if k == AK_DECL && ast_b[i] < 0 && ast_a[i] != 0 && ast_kind[ast_a[i]] == AK_STR { at_b[base + i] = ast_b[ast_a[i]] + 1; }
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
int gl_trydepth;                 // try blocks that are open at this point
int gl_looptry[32];              // gl_trydepth when each open loop began
int gl_ismain;                   // 1 while main is made: it ends with the exit call, a `return` gives its status
int gl_retoff;                   // the slot that holds the address of the result of a function that gives a struct, else -1
int gl_ab;                       // the base register and the offset that gl_addr / gl_lv give
int gl_ao;
int gl_ast1[1024];               // a local table: the elements that a step of the first index skips, and of the second
int gl_ast2[1024];
int gl_acnt[1024];               // the number of elements of the array variable (a local), for the arguments of T name[]
int gl_mvslot[AT_MAX];           // an argument that is a value that frees itself: the slot of its copy
int gl_nstemps;                  // the new Strings made so far (the slots)
int gl_hastmp[AT_MAX];           // for an if / while: its condition makes new Strings (they are freed before the jump)
int gl_depth;                    // the cells in use below the frame pointer
int gl_off[1024];                // the unique number of a local -> its offset in the frame
int gl_nslot;                    // the next offset to give
int gl_bsl[AT_MAX];              // for loops: the offset of the hidden bound, by the node
int gl_nz[8];                    // the local variables known to be not 0 here (after `while b != 0 {`); cleared at every join
int gl_nzn;
int gl_fail;
int gl_fcode;                    // which place of the lowering gave up first (the number of the call of gl_failx)
void gl_failx(int code) {
    gl_fail = 1;
    if gl_fcode == 0 { gl_fcode = code; }
}
int gl_why;                      // 1: the frame of the tree is not the frame of the parser
int gl_ret;                      // the label of the return
int gl_retd;                     // 1: the function gives a double
int gl_brk[32];
int gl_cnt[32];
int gl_loops;
int gl_args[8];

int gl_label() {
    if gl_nlab >= GL_MAXP { gl_failx(1); return 0; }
    gl_lblock[gl_nlab] = 0 - 1;
    gl_nlab += 1;
    return gl_nlab - 1;
}

void gl_note(int ins) {
    if gl_np >= GL_MAXP { gl_failx(2); return; }
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
    if k == AK_BUILTIN && (at_val[n] == 8 || at_val[n] == 9) { return true; }
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
        if gl_is_cmp(ao) && at_ty[at_a[n]] / 65536 != 4 && at_ty[at_b[n]] / 65536 != 4 {
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
        // the first argument is the address of the object (a variable, or the slot of the struct that a call made)
        gl_saddr(a);
        gl_ensure();
        gl_store(30, gl_cell(gl_depth), 1);
        gl_depth += 1;
        argn += 1;
        a = at_b[n];
    }
    int hn = 0;
    if hid { hn = 1; }
    int xarr = 0;                         // the registers that the array arguments took in addition
    while a != 0 {
        if (farr[fi] >> (argn - hn - xarr)) % 2 == 1 {
            // T name[]: the address, then the number of elements (a text: its length + 1)
            int alen = 0;
            if at_kind[a] == AK_STR {
                gl_sval(a);
                alen = at_b[a] + 1;
            } else {
                if at_kind[a] == AK_VAR { alen = gl_acnt[at_val[a]]; } else { alen = gcnt[at_val[a]]; }
                if alen <= 0 { gl_failx(30); return; }
                gl_lv(a);
                gl_ensure();
                if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
            }
            gl_ensure();
            gl_store(30, gl_cell(gl_depth), 1);
            gl_depth += 1;
            ir_add(IR_CONST, 1, 0, 0, 0, alen);
            gl_store(30, gl_cell(gl_depth), 1);
            gl_depth += 1;
            argn += 2;
            xarr += 1;
            a = at_nx[a];
            continue;
        }
        if fptid[fi * 8 + argn - hn - xarr] >= 100 {
            gl_saddr(a);
            if fptid[fi * 8 + argn - hn - xarr] < 100 + scount && struct_has_free(fptid[fi * 8 + argn - hn - xarr] - 100) {
                // moved into a copy; the source is emptied; the callee gets the address of the copy
                gl_ensure();
                gl_copy(30, gl_mvslot[a], 1, 0, ssize[fptid[fi * 8 + argn - hn - xarr] - 100]);
                go_zero();
                ir_add(IR_ADD, 1, 30, gl_mvslot[a], 1, 0);
            }
        } else if fptid[fi * 8 + argn - hn - xarr] == 99 && fpstr[fi * 8 + argn - hn - xarr] == 1 {
            // a String parameter borrows: the String, or a temporary String made from a text
            gl_sval(a);
            if at_kind[a] == AK_STR {
                gl_rt2("__Str__from", 1);
                gl_skeep(a);
            }
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
    if hid {
        ir_add(IR_ADD, 1, 30, at_c[n], 1, 0);
        if struct_has_free(fret[fi] - 100) { go_decl(at_c[n]); }          // the result is an owner of the kind 6 (own_add after the call)
    }
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
// run S__init on the struct at the frame offset off
void gl_init_call(int sidx, int off) {
    char inm[64];
    str_copy(@inm, @sname + sidx * 64, 64);
    str_copy(@inm + str_len(@inm), "__init", 8);
    gl_ensure();
    ir_add(IR_ADD, 1, 30, off, 1, 0);
    gl_rt1(@inm, 1);
}

void gl_assign_struct(int target, int value) {
    int fsi = at_ty[target] % 65536 - 16;
    if struct_has_free(fsi) {
        // value first, then free(target), copy, and the source is emptied
        gl_lv(target);
        gl_ensure();
        if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
        int c1 = gl_cell(gl_depth);
        gl_store(30, c1, 1);
        gl_depth += 1;
        gl_saddr(value);
        gl_ensure();
        int c2 = gl_cell(gl_depth);
        gl_store(30, c2, 1);
        gl_depth += 1;
        gl_load(1, 30, c1);
        char sfn[128];
        str_copy(@sfn, @sname + fsi * 64, 64);
        str_copy(@sfn + str_len(@sfn), "__free", 8);
        gl_rt1(@sfn, 1);
        gl_load(3, 30, c1);
        gl_load(4, 30, c2);
        gl_depth -= 2;
        gl_copy(3, 0, 4, 0, ssize[fsi]);
        go_zero();
        return;
    }
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
    else { gl_failx(3); }
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
    else { gl_failx(4); }
}

// the address of an element (a[i], p[i]) or of what a pointer points to (p^): the base register and the offset go to gl_ab and
// gl_ao (the base is v30 or v29 for an array with a number as index, else v1). May use v1 and v2.

// v1 = the header that a place holds (a String or a dynamic array: a variable, a global or a field)
void gl_pload(int r) {
    gl_ensure();
    int k = at_kind[r];
    if k == AK_VAR {
        gl_load(1, 30, gl_off[at_val[r]]);
        return;
    }
    if k == AK_GVAR {
        gl_load(1, 29, goff[at_val[r]]);
        return;
    }
    gl_addr(r);
    gl_ensure();
    int le = ir_add(IR_LOAD, 1, gl_ab, 0, 0, gl_ao);
    ir_w[le] = 8;
}

// the place r gets the value that waits in the cell c (v1, v2, v3 are used)
void gl_pstore(int r, int c) {
    gl_ensure();
    int k = at_kind[r];
    if k == AK_VAR {
        gl_load(3, 30, c);
        gl_store(30, gl_off[at_val[r]], 3);
        return;
    }
    if k == AK_GVAR {
        gl_load(3, 30, c);
        gl_store(29, goff[at_val[r]], 3);
        return;
    }
    gl_addr(r);
    gl_ensure();
    gl_load(3, 30, c);
    int se = ir_add(IR_STORE, 0, gl_ab, 3, 0, gl_ao);
    ir_w[se] = 8;
}

// the place is null
void gl_pnull(int r) {
    gl_ensure();
    int k = at_kind[r];
    if k == AK_VAR || k == AK_GVAR {
        ir_add(IR_CONST, 3, 0, 0, 0, 0);
        if k == AK_VAR { gl_store(30, gl_off[at_val[r]], 3); } else { gl_store(29, goff[at_val[r]], 3); }
        return;
    }
    gl_addr(r);
    gl_ensure();
    ir_add(IR_CONST, 3, 0, 0, 0, 0);
    int se = ir_add(IR_STORE, 0, gl_ab, 3, 0, gl_ao);
    ir_w[se] = 8;
}

// v1 = the header of the dynamic array that the variable holds, stops with an exception when it is null (dyn_null_check)
void gl_dyn_header(int var) {
    gl_pload(var);
    gl_nullchk();
}

void gl_nullchk() {
    int lok = gl_label();
    int lnull = gl_label();
    gl_br(IR_NE, 1, 0, 1, lok, lnull);
    gl_place(lnull);
    int ce = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Arr__nullerr"));
    ir_set_args(ce, 0, @gl_args);
    gl_place(lok);
}

// a call of a runtime routine with one or two arguments in v1 (v2)
void gl_rt2(char^ name, int n) {
    gl_ensure();
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(name));
    gl_args[0] = 1;
    gl_args[1] = 2;
    gl_args[2] = 3;
    gl_args[3] = 4;
    gl_args[4] = 5;
    ir_set_args(e, n, @gl_args);
}

// the element of the code at v1 (an address): v1 = its value, f32 for a double
void gl_dyn_load(int code) {
    gl_ensure();
    int le = ir_add(IR_LOAD, 1, 1, 0, 0, 0);
    ir_w[le] = as1_lw(code);
    if code == 7 { ir_add(IR_BITS2F, 32, 1, 0, 0, 0); }
}

// the member functions of a dynamic array variable (statement or value); at_val is 1000 + 1 push, 2 pop, 3 resize, 4 clear, 5 free
// how the array routines compare the elements of the array type t: 0 signed, 1 unsigned (also pointers), 2 float, 3 double
int gl_arr_kind(int t) {
    int b = t % 65536;
    if b >= 1000 && b < 1500 { return 1; }
    int code = as1_dcode(t);
    if code == 6 { return 2; }
    if code == 7 { return 3; }
    if code == 2 || code == 3 || code == 11 || code == 12 || code == 13 { return 1; }
    return 0;
}

// v1 = the bits of the value v for an array of the element code `code` (a double goes as its bits)
void gl_dyn_value_bits(int code, int v) {
    if code == 7 {
        gl_expr_d(v);
        gl_ensure();
        ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
    } else {
        gl_expr(v);
        gl_ensure();
    }
}

void gl_dynmethod(int n) {
    int op = at_val[n] - 1000;
    int r = at_a[n];
    int code = as1_dcode(at_ty[r]);
    int a = at_b[n];
    if op == 1 {
        // push(v): the header, then the value, then the place of the new element
        gl_pload(r);
        int c0 = gl_cell(gl_depth);
        gl_store(30, c0, 1);
        gl_depth += 1;
        if code == 7 {
            gl_expr_d(a);
            gl_ensure();
            ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
        } else {
            gl_expr(a);
            gl_ensure();
        }
        int c1 = gl_cell(gl_depth);
        gl_store(30, c1, 1);
        gl_depth += 1;
        gl_load(1, 30, c0);
        gl_rt2("__Arr__slot", 1);
        ir_add(IR_COPY, 3, 1, 0, 0, 0);
        gl_load(2, 30, c1);
        int se = ir_add(IR_STORE, 0, 3, 2, 0, 0);
        ir_w[se] = as1_bytes(code);
        gl_depth -= 2;
        go_drain_val(a);
        return;
    }
    if op == 2 {
        gl_pload(r);
        gl_rt2("__Arr__pop", 1);
        gl_dyn_load(code);
        return;
    }
    if op == 3 {
        gl_pload(r);
        int c2 = gl_cell(gl_depth);
        gl_store(30, c2, 1);
        gl_depth += 1;
        gl_expr(a);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c2);
        gl_depth -= 1;
        gl_rt2("__Arr__resize", 2);
        return;
    }
    if op == 4 {
        gl_dyn_header(r);
        ir_add(IR_CONST, 2, 0, 0, 0, 0);
        gl_store(1, 0, 2);
        return;
    }
    if op == 6 {
        // sort(): the header and how the elements compare
        gl_pload(r);
        ir_add(IR_CONST, 2, 0, 0, 0, gl_arr_kind(at_ty[r]));
        gl_rt2("__Arr__sort", 2);
        return;
    }
    if op == 7 {
        gl_pload(r);
        int c3 = gl_cell(gl_depth);
        gl_store(30, c3, 1);
        gl_depth += 1;
        gl_expr(a);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c3);
        gl_depth -= 1;
        gl_rt2("__Arr__remove", 2);
        return;
    }
    if op == 8 {
        // insert(i, v): the header, the position, the value (its bits)
        gl_pload(r);
        int c4 = gl_cell(gl_depth);
        gl_store(30, c4, 1);
        gl_depth += 1;
        gl_expr(a);
        gl_ensure();
        int c5 = gl_cell(gl_depth);
        gl_store(30, c5, 1);
        gl_depth += 1;
        gl_dyn_value_bits(code, at_nx[a]);
        ir_add(IR_COPY, 3, 1, 0, 0, 0);
        gl_load(1, 30, c4);
        gl_load(2, 30, c5);
        gl_depth -= 2;
        gl_rt2("__Arr__insert", 3);
        go_drain_val(at_nx[a]);
        return;
    }
    if op == 9 || op == 10 {
        // contains(v) / index_of(v): the header, the bits of the value, how the elements compare
        gl_pload(r);
        int c6 = gl_cell(gl_depth);
        gl_store(30, c6, 1);
        gl_depth += 1;
        gl_dyn_value_bits(code, a);
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c6);
        gl_depth -= 1;
        ir_add(IR_CONST, 3, 0, 0, 0, gl_arr_kind(at_ty[r]));
        gl_rt2("__Arr__index", 3);
        if op == 9 {
            ir_add(IR_CONST, 2, 0, 0, 0, 0);
            ir_add(IR_SETCC, 1, 1, 2, 0, IR_GE);
        }
        return;
    }
    // free()
    gl_pload(r);
    gl_rt2("__Arr__free", 1);
    gl_pnull(r);
}

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

// a row of a table (an INDEX whose type is an array): the elements that one step of its index skips
int gl_rowelems(int n) {
    int lvl = 1;
    int b = at_a[n];
    while at_kind[b] == AK_INDEX {
        lvl += 1;
        b = at_a[b];
    }
    int s1 = 0;
    int s2 = 0;
    if at_kind[b] == AK_VAR { s1 = gl_ast1[at_val[b]]; s2 = gl_ast2[at_val[b]]; }
    else if at_kind[b] == AK_GVAR { s1 = gst1[at_val[b]]; s2 = gst2[at_val[b]]; }
    else if at_kind[b] == AK_FIELD { s1 = fldst1[at_val[b]]; s2 = fldst2[at_val[b]]; }
    if lvl == 1 { return s1; }
    if lvl == 2 { return s2; }
    return 0;
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
        int fb = at_kind[at_a[n]];
        if fb == AK_CALL || fb == AK_METHOD {
            gl_saddr(at_a[n]);                  // a field of a struct that a call made: its slot
            gl_ab = 1;
            gl_ao = 0;
        } else {
            gl_lv(at_a[n]);
        }
        gl_ao += fldoff[at_val[n]];
        return;
    }
    int b = at_a[n];
    int ix = at_b[n];
    if as1_dynlike(at_ty[b]) {
        // an element of a dynamic array (or a char of a String): the data pointer is at [header + 16]; the header is checked first and waits while the index is worked out
        int des = 8;
        if at_ty[n] / 65536 == 0 { des = as1_bytes(at_ty[n] % 65536); }
        int dp2 = 1;
        int dsh = 0;
        while dp2 < des {
            dp2 = dp2 * 2;
            dsh += 1;
        }
        gl_dyn_header(b);
        if at_kind[ix] == AK_NUM && at_val[ix] >= 0 && at_val[ix] < 4096 {
            gl_load(1, 1, 16);
            gl_ab = 1;
            gl_ao = at_val[ix] * des;
            return;
        }
        int dar = 0;
        int dc = gl_cell(gl_depth);
        if gl_rdepth < 7 && !gl_has_call(ix) {
            dar = 9 + gl_rdepth;
            ir_add(IR_COPY, dar, 1, 0, 0, 0);
            gl_rdepth += 1;
        } else {
            gl_store(30, dc, 1);
            gl_depth += 1;
        }
        gl_expr(ix);
        gl_scale(des, dsh);
        gl_ensure();
        if dar != 0 {
            ir_add(IR_COPY, 2, dar, 0, 0, 0);
            gl_rdepth -= 1;
        } else {
            gl_load(2, 30, dc);
            gl_depth -= 1;
        }
        gl_load(2, 2, 16);
        ir_add(IR_ADD, 1, 1, 2, 0, 0);
        gl_ab = 1;
        gl_ao = 0;
        return;
    }
    bool is_arr = as1_arr(at_ty[b]) || as1_sarr(at_ty[b]);
    int bk = at_kind[b];
    int boff = 0;
    int bvr = 30;
    int es = 8;
    if as1_sty(at_ty[n]) { es = ssize[at_ty[n] % 65536 - 16]; } else { es = as1_bytes(at_ty[n] % 65536); }
    if as1_arr(at_ty[n]) || as1_sarr(at_ty[n]) {
        // this element is a row of a table: a step skips the elements of the rows below it
        int relems = gl_rowelems(n);
        if relems <= 0 { gl_failx(35); return; }
        if as1_sarr(at_ty[n]) { es = ssize[at_ty[n] % 65536 - 16] * relems; } else { es = as1_bytes(at_ty[n] % 65536) * relems; }
    }
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
    if k == AK_STR { gl_sval(n); return; }
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
    if k == AK_FIELD && (at_val[n] == 0 - 4 || at_val[n] == 0 - 5) {
        gl_ensure();
        int fcnt = at_c[n];
        if at_val[n] == 0 - 5 { fcnt = gl_acnt[at_val[at_a[n]]]; if gl_ast1[at_val[at_a[n]]] > 0 { fcnt = fcnt / gl_ast1[at_val[at_a[n]]]; } }
        if fcnt <= 0 { gl_failx(34); return; }
        ir_add(IR_CONST, 1, 0, 0, 0, fcnt);
        return;
    }
    if k == AK_FIELD && at_val[n] < 0 {
        if at_kind[at_a[n]] == AK_VAR {
            gl_dyn_header(at_a[n]);
        } else {
            gl_sval(at_a[n]);
            gl_nullchk();
        }
        int fo2 = 0;
        if at_val[n] == 0 - 3 { fo2 = 8; }
        gl_load(1, 1, fo2);
        return;
    }
    if k == AK_METHOD && at_val[n] >= 3000 {
        gl_samethod(n);
        return;
    }
    if k == AK_METHOD && at_val[n] >= 2000 {
        gl_strmethod(n);
        return;
    }
    if k == AK_METHOD && at_val[n] >= 1000 {
        gl_dynmethod(n);
        return;
    }
    if k == AK_BIN && (at_ty[at_a[n]] / 65536 == 4 || at_ty[at_b[n]] / 65536 == 4) {
        gl_scmp(n);
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
    if k == AK_CAST && as1_pt(at_ty[n]) {
        gl_expr(at_a[n]);
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
    if k == AK_BUILTIN && at_val[n] == 7 {
        gl_failx(5);                         // arr(n) is only the value of a declaration (gl_stmt)
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 5 {
        gl_expr(at_a[n]);
        gl_rt1("Mem__alloc", 1);
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 14 {
        gl_expr(at_a[n]);
        if !go_null(gl_off[at_val[at_a[n]]], 0) { gl_failx(31); }
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 11 {
        gl_ensure();
        gl_load(1, 29, 0);                      // the saved stack pointer: argc is the first word
        gl_load(1, 1, 0);
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 12 {
        gl_expr(at_a[n]);
        gl_ensure();
        ir_add(IR_SHL, 1, 1, 3, 1, 0);          // i * 8
        gl_load(2, 29, 0);
        ir_add(IR_ADD, 1, 2, 1, 0, 0);
        gl_load(1, 1, 8);                       // argv[i] is at [sp + 8 + 8 * i]
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 9 {
        if at_ty[at_a[n]] / 65536 == 4 {
            gl_sval(at_a[n]);
            gl_rt1("__Str__hash", 1);
        } else {
            gl_expr(at_a[n]);
            gl_rt1("__Str__hashint", 1);
        }
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 8 {
        // syscall: the arguments wait in cells, then x8 = the number, x0 .. = the arguments
        int sbase = gl_depth;
        int sn = 0;
        int sa = at_a[n];
        while sa != 0 {
            gl_expr(sa);
            gl_ensure();
            gl_store(30, gl_cell(gl_depth), 1);
            gl_depth += 1;
            sn += 1;
            sa = at_nx[sa];
        }
        gl_depth = sbase;
        int sk = 0;
        while sk < sn {
            gl_load(sk + 1, 30, gl_cell(sbase + sk));
            sk += 1;
        }
        gl_ensure();
        ir_add(IR_COPY, 9, 1, 0, 0, 0);
        sk = 1;
        while sk < sn {
            ir_add(IR_COPY, sk, sk + 1, 0, 0, 0);
            sk += 1;
        }
        int se = ir_add(IR_SYSCALL, 1, 9, 0, 0, 0);
        int r = 0;
        while r < sn - 1 {
            gl_args[r] = r + 1;
            r += 1;
        }
        ir_set_args(se, sn - 1, @gl_args);
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
    gl_failx(6);
}

void gl_block_list(int s) {
    while s != 0 {
        gl_stmt(s);
        go_flush(false);                 // the new Strings of the statement are freed at its end (parse_statement)
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
    if off < 0 { gl_failx(7); return; }
    gl_ensure();
    ir_add(IR_ADD, 1, 29, off, 1, 0);
    gl_rt1("j2k_print_str", 1);
    gl_lastw = 9;
}

// a String value (a variable or a new String): the characters are at [header + 16]
void gl_cout_string(int it) {
    gl_sval(it);
    gl_nullchk();
    gl_ensure();
    gl_load(1, 1, 16);
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
        } else if at_ty[it] / 65536 == 4 {
            gl_cout_string(it);
        } else if (at_kind[it] == AK_VAR || at_kind[it] == AK_GVAR) && as1_arr(at_ty[it]) && at_ty[it] % 65536 == 2 {
            gl_ensure();
            if at_kind[it] == AK_VAR { ir_add(IR_ADD, 1, 30, gl_off[at_val[it]], 1, 0); } else { ir_add(IR_ADD, 1, 29, goff[at_val[it]], 1, 0); }
            gl_rt1("j2k_print_str", 1);
            gl_lastw = 9;
        } else if at_ty[it] / 65536 == 1 && at_ty[it] % 65536 == 2 {
            gl_expr(it);
            gl_rt1("j2k_print_str", 1);
            gl_lastw = 9;
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
        if gl_loops >= 32 { gl_failx(8); return; }
        gl_brk[gl_loops] = le3;
        gl_cnt[gl_loops] = ls;
        gl_looptry[gl_loops] = gl_trydepth;
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

// ---------------------------------------------------------------- ownership (the events that the text parser recorded: jc_expr.j, ow_*)
int go_pos;                      // the next event of this function
int go_end;                      // one past its last event
int gl_blkn;                     // the blocks, the return statements, the break and continue statements seen so far (as the parser counts)
int gl_retn;
int gl_brkn;

// the type of the next event, 0 when there is none
int go_peek() {
    if go_pos >= go_end { return 0; }
    return ow_ty[go_pos];
}

// the routine that frees an owner of the kind, in gl_ofn (1 when the mode is the address of the slot); false when the tree does not know it
char gl_ofn[128];
int gl_omode;
bool go_fn(int kind, int aux) {
    gl_omode = 0;
    if kind == 0 {
        str_copy(@gl_ofn, "Mem__free", 128);
        return true;
    }
    if kind == 1 || kind == 2 {
        str_copy(@gl_ofn, "__Arr__free", 128);
        return true;
    }
    if kind == 3 || kind == 9 {
        str_copy(@gl_ofn, "__Str__free_all", 128);
        return true;
    }
    if kind == 4 || kind == 6 {
        str_copy(@gl_ofn, @sname + aux * 64, 64);
        append_text(@gl_ofn, "__free");
        gl_omode = 1;
        return true;
    }
    return false;
}

// a variable that owns memory was declared at the frame offset off: the record of the cleanup chain is made (own_add)
void go_decl(int off) {
    if go_peek() != 1 || ow_a[go_pos] != off { return; }
    int kind = ow_b[go_pos];
    int aux = ow_c[go_pos];
    int rec = ow_d[go_pos];
    go_pos += 1;
    if !go_fn(kind, aux) { gl_failx(9); return; }
    // the registers are those of the text path (x1, x2): the value in x0 of an expression stays
    gl_ensure();
    ir_add(IR_ADD, 2, 30, rec, 1, 0);                       // add x1, x29, #rec
    gl_load(3, 28, 784);                                   // ldr x2, [x27, #784]
    gl_store(2, 0, 3);
    ir_add(IR_ADD, 3, 30, off, 1, 0);
    gl_store(2, 8, 3);
    ir_add(IR_ADDR_FUNC, 3, 0, 0, 0, ir_name_index(@gl_ofn));
    gl_store(2, 16, 3);
    ir_add(IR_CONST, 3, 0, 0, 0, gl_omode);
    gl_store(2, 24, 3);
    gl_store(28, 784, 2);
}

// the variables that the statement just made null (their memory went into a field, an element ...)
// the value that the statement stored is a variable: when the parser made it null (its memory moved) this is the place
void go_drain_val(int val) {
    if val == 0 || at_kind[val] != AK_VAR { return; }
    if go_peek() == 4 && ow_b[go_pos] == 3 && ow_a[go_pos] == gl_off[at_val[val]] {
        go_null(ow_a[go_pos], 3);
    }
}

// a value that frees itself moved out of a local variable: the local is emptied (zeros), as emit_zero_local did
void go_zero() {
    if go_peek() == 5 {
        int off = ow_a[go_pos];
        int size = ow_b[go_pos];
        go_pos += 1;
        gl_ensure();
        ir_add(IR_CONST, 2, 0, 0, 0, 0);
        int zk = 0;
        while zk < size {
            gl_store(30, off + zk, 2);
            zk += 8;
        }
    }
}

// the variable at off became null (it was freed or its memory moved): `mov x1, 0; str x1, [x29, #off]`
bool go_null(int off, int why) {
    if go_peek() != 4 || ow_a[go_pos] != off || ow_b[go_pos] != why { return false; }
    go_pos += 1;
    gl_ensure();
    ir_add(IR_CONST, 2, 0, 0, 0, 0);                        // mov x1, 0
    gl_store(30, off, 2);
    return true;
}

// a place where the owners of a block / function are freed: the frees are those that the parser made there. v1 is not kept.
bool go_site(int site, int id) {
    if go_peek() != 2 || ow_a[go_pos] != site || ow_b[go_pos] != id { return false; }
    int rec = ow_c[go_pos];
    int cnt = ow_d[go_pos];
    go_pos += 1;
    int k = 0;
    while k < cnt {
        if go_peek() != 3 { gl_failx(10); return true; }
        int off = ow_a[go_pos];
        int kind = ow_b[go_pos];
        int aux = ow_c[go_pos];
        go_pos += 1;
        if !go_fn(kind, aux) { gl_failx(11); return true; }
        gl_ensure();
        if gl_omode == 1 { ir_add(IR_ADD, 1, 30, off, 1, 0); } else { gl_load(1, 30, off); }
        int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(@gl_ofn));
        gl_args[0] = 1;
        ir_set_args(e, 1, @gl_args);
        k += 1;
    }
    gl_ensure();
    gl_load(2, 30, rec);                                    // the chain goes back to what it was before
    gl_store(28, 784, 2);
    return true;
}

// the temporary Strings of a statement or a condition are freed (str_flush): the owners that the parser freed there, then the chain
// goes back; live: v1 holds a value that must be kept
void go_flush(bool live) {
    if go_peek() != 2 || ow_a[go_pos] != 6 { return; }
    int rec = ow_c[go_pos];
    int cnt = ow_d[go_pos];
    go_pos += 1;
    int cc = 0;
    if live {
        gl_ensure();
        cc = gl_cell(gl_depth);
        gl_store(30, cc, 1);
        gl_depth += 1;
    }
    int k = 0;
    while k < cnt {
        if go_peek() != 3 { gl_failx(12); return; }
        int off = ow_a[go_pos];
        int kind = ow_b[go_pos];
        int aux = ow_c[go_pos];
        go_pos += 1;
        if !go_fn(kind, aux) { gl_failx(13); return; }
        gl_ensure();
        if gl_omode == 1 { ir_add(IR_ADD, 1, 30, off, 1, 0); } else { gl_load(1, 30, off); }
        int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(@gl_ofn));
        gl_args[0] = 1;
        ir_set_args(e, 1, @gl_args);
        k += 1;
    }
    gl_ensure();
    gl_load(2, 30, rec);
    gl_store(28, 784, 2);
    if live {
        gl_depth -= 1;
        gl_load(1, 30, cc);
    }
}

// ---------------------------------------------------------------- Strings
// the kind of an operand for the String routines: 1 a String, 0 a text, 2 a char
int gl_skind(int n) {
    if at_ty[n] / 65536 == 4 {
        if at_kind[n] == AK_STR { return 0; }
        return 1;
    }
    return 2;
}

// the new String in v1 is kept in the hidden slot of the node and becomes an owner until the end of the statement (str_temp)
void gl_skeep(int n) {
    gl_ensure();
    gl_store(30, at_c[n], 1);
    go_decl(at_c[n]);
}

// v1 = the value of a String operand: the header of a String, the address of a text, the code of a char
void gl_sval(int n) {
    int k = at_kind[n];
    if k == AK_STR {
        int off = gl_lit(at_val[n], at_b[n]);
        if off < 0 { gl_failx(14); return; }
        gl_ensure();
        ir_add(IR_ADD, 1, 29, off, 1, 0);
        return;
    }
    if at_ty[n] / 65536 != 4 {
        gl_expr(n);
        return;
    }
    if k == AK_VAR || k == AK_GVAR || k == AK_FIELD || k == AK_INDEX {
        gl_pload(n);
        return;
    }
    if k == AK_CALL || (k == AK_METHOD && at_val[n] >= 0 && at_val[n] < 1000) {
        gl_call(n);
        gl_skeep(n);
        return;
    }
    if k == AK_METHOD && at_val[n] >= 3000 {
        gl_samethod(n);
        return;
    }
    if k == AK_BUILTIN && at_val[n] == 13 {
        int sa = at_a[n];
        if at_ty[sa] / 65536 == 4 {
            gl_sval(sa);
            gl_rt2("__Str__clone", 1);
        } else if gl_isd(sa) {
            gl_expr_d(sa);
            gl_ensure();
            ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
            gl_rt2("__Str__from_double", 1);
        } else if at_ty[sa] % 65536 == 2 {
            gl_expr(sa);
            gl_rt2("__Str__from_char", 1);
        } else {
            gl_expr(sa);
            gl_ensure();
            ir_add(IR_CONST, 2, 0, 0, 0, 0);
            gl_rt2("__Str__from_int", 2);
        }
        gl_skeep(n);
        return;
    }
    if k == AK_BIN {
        int a = at_a[n];
        int b = at_b[n];
        gl_sval(a);
        gl_ensure();
        int c0 = gl_cell(gl_depth);
        gl_store(30, c0, 1);
        gl_depth += 1;
        gl_sval(b);
        gl_ensure();
        ir_add(IR_COPY, 3, 1, 0, 0, 0);
        gl_load(1, 30, c0);
        gl_depth -= 1;
        ir_add(IR_CONST, 2, 0, 0, 0, gl_skind(a));
        ir_add(IR_CONST, 4, 0, 0, 0, gl_skind(b));
        int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Str__cat"));
        gl_args[0] = 1;
        gl_args[1] = 2;
        gl_args[2] = 3;
        gl_args[3] = 4;
        ir_set_args(e, 4, @gl_args);
        gl_skeep(n);
        return;
    }
    // slice / trim / upper / lower / repeat of a String variable (at_val 2005 .. 2009)
    int mo = at_val[n] - 2000;
    int r = at_a[n];
    int a1 = at_b[n];
    gl_sval(r);
    if mo == 19 {
        // replace(a, b): x0 = the String, x1 = a, x2 = its kind, x3 = b, x4 = its kind
        gl_ensure();
        int cr0 = gl_cell(gl_depth);
        gl_store(30, cr0, 1);
        gl_depth += 1;
        gl_sval(a1);
        gl_ensure();
        int cr1 = gl_cell(gl_depth);
        gl_store(30, cr1, 1);
        gl_depth += 1;
        gl_sval(at_nx[a1]);
        gl_ensure();
        ir_add(IR_COPY, 4, 1, 0, 0, 0);
        gl_load(1, 30, cr0);
        gl_load(2, 30, cr1);
        gl_depth -= 2;
        ir_add(IR_CONST, 3, 0, 0, 0, gl_skind(a1));
        ir_add(IR_CONST, 5, 0, 0, 0, gl_skind(at_nx[a1]));
        int re = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Str__replace"));
        gl_args[0] = 1;
        gl_args[1] = 2;
        gl_args[2] = 3;
        gl_args[3] = 4;
        gl_args[4] = 5;
        ir_set_args(re, 5, @gl_args);
        gl_skeep(n);
        return;
    }
    if mo == 5 {
        gl_ensure();
        int c1 = gl_cell(gl_depth);
        gl_store(30, c1, 1);
        gl_depth += 1;
        gl_expr(a1);
        gl_ensure();
        int c2 = gl_cell(gl_depth);
        gl_store(30, c2, 1);
        gl_depth += 1;
        gl_expr(at_nx[a1]);
        gl_ensure();
        ir_add(IR_COPY, 3, 1, 0, 0, 0);
        gl_load(1, 30, c1);
        gl_load(2, 30, c2);
        gl_depth -= 2;
        int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Str__slice"));
        gl_args[0] = 1;
        gl_args[1] = 2;
        gl_args[2] = 3;
        ir_set_args(e, 3, @gl_args);
    } else if mo == 9 {
        gl_ensure();
        int c3 = gl_cell(gl_depth);
        gl_store(30, c3, 1);
        gl_depth += 1;
        gl_expr(a1);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c3);
        gl_depth -= 1;
        gl_rt2("__Str__repeat", 2);
    } else if mo == 6 {
        gl_rt2("__Str__trim", 1);
    } else if mo == 7 {
        gl_rt2("__Str__upper", 1);
    } else {
        gl_rt2("__Str__lower", 1);
    }
    gl_skeep(n);
}

// a comparison with a String: v1 = 0 / 1
void gl_scmp(int n) {
    int ao = at_val[n];
    int a = at_a[n];
    int b = at_b[n];
    gl_sval(a);
    gl_ensure();
    int c0 = gl_cell(gl_depth);
    gl_store(30, c0, 1);
    gl_depth += 1;
    gl_sval(b);
    gl_ensure();
    ir_add(IR_COPY, 3, 1, 0, 0, 0);
    gl_load(1, 30, c0);
    gl_depth -= 1;
    ir_add(IR_CONST, 2, 0, 0, 0, gl_skind(a));
    ir_add(IR_CONST, 4, 0, 0, 0, gl_skind(b));
    char^ rt = "__Str__eq";
    if ao != AO_EQ && ao != AO_NE { rt = "__Str__order"; }
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(rt));
    gl_args[0] = 1;
    gl_args[1] = 2;
    gl_args[2] = 3;
    gl_args[3] = 4;
    ir_set_args(e, 4, @gl_args);
    if ao == AO_NE {
        ir_add(IR_CONST, 2, 0, 0, 0, 1);
        ir_add(IR_XOR, 1, 1, 2, 0, 0);
    } else if ao != AO_EQ {
        ir_add(IR_CONST, 2, 0, 0, 0, 0);
        ir_add(IR_SETCC, 1, 1, 2, 0, gl_cc(ao));
    }
}

// the member functions of an array of Strings: at_val 3001 .. 3011 (as1_samethod)
void gl_samethod(int n) {
    int mo = at_val[n] - 3000;
    int r = at_a[n];
    int a = at_b[n];
    gl_pload(r);
    if mo == 2 {
        gl_rt2("__Str__apop", 1);
        gl_skeep(n);
        return;
    }
    if mo == 5 || mo == 6 || mo == 9 {
        if mo == 5 { gl_rt2("__Str__clear_all", 1); }
        else if mo == 6 { gl_rt2("__Str__asort", 1); }
        else {
            gl_rt2("__Str__free_all", 1);
            gl_pnull(r);
        }
        return;
    }
    gl_ensure();
    int c0 = gl_cell(gl_depth);
    gl_store(30, c0, 1);
    gl_depth += 1;
    if mo == 1 {
        gl_sadopt(a);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c0);
        gl_depth -= 1;
        gl_rt2("__Str__apush", 2);
        return;
    }
    if mo == 3 {
        gl_expr(a);
        gl_ensure();
        int c1 = gl_cell(gl_depth);
        gl_store(30, c1, 1);
        gl_depth += 1;
        gl_sadopt(at_nx[a]);
        gl_ensure();
        ir_add(IR_COPY, 3, 1, 0, 0, 0);
        gl_load(1, 30, c0);
        gl_load(2, 30, c1);
        gl_depth -= 2;
        int e3 = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Str__ainsert"));
        gl_args[0] = 1;
        gl_args[1] = 2;
        gl_args[2] = 3;
        ir_set_args(e3, 3, @gl_args);
        return;
    }
    if mo == 4 || mo == 11 {
        gl_expr(a);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c0);
        gl_depth -= 1;
        if mo == 4 { gl_rt2("__Str__aremove", 2); } else { gl_rt2("__Str__aresize", 2); }
        return;
    }
    // contains(x) / index_of(x) / join(sep): the array, the value, its kind
    gl_sval(a);
    gl_ensure();
    ir_add(IR_COPY, 2, 1, 0, 0, 0);
    gl_load(1, 30, c0);
    gl_depth -= 1;
    ir_add(IR_CONST, 3, 0, 0, 0, gl_skind(a));
    char^ rn = "__Str__aindex";
    if mo == 10 { rn = "__Str__ajoin"; }
    int e4 = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(rn));
    gl_args[0] = 1;
    gl_args[1] = 2;
    gl_args[2] = 3;
    ir_set_args(e4, 3, @gl_args);
    if mo == 7 {
        ir_add(IR_CONST, 2, 0, 0, 0, 0);
        ir_add(IR_SETCC, 1, 1, 2, 0, IR_GE);
    }
    if mo == 10 { gl_skeep(n); }
}

// the member functions of a String variable: at_val 2001 push, 2002 pop, 2003 clear, 2004 append
// text.split(sep): v1 = the new list of Strings (x0 = the String, x1 = the separator, x2 = its kind)
void gl_split(int n) {
    int a = at_b[n];
    gl_sval(at_a[n]);
    gl_ensure();
    int cs0 = gl_cell(gl_depth);
    gl_store(30, cs0, 1);
    gl_depth += 1;
    gl_sval(a);
    gl_ensure();
    ir_add(IR_COPY, 2, 1, 0, 0, 0);
    gl_load(1, 30, cs0);
    gl_depth -= 1;
    ir_add(IR_CONST, 3, 0, 0, 0, gl_skind(a));
    gl_rt2("__Str__split", 3);
}

void gl_strmethod(int n) {
    int mo = at_val[n] - 2000;
    int a = at_b[n];
    gl_ensure();
    if mo == 18 {
        gl_sval(at_a[n]);
        gl_rt2("__Str__c", 1);
        return;
    }
    if mo == 2 || mo == 3 || mo >= 14 || mo == 14 {
        gl_sval(at_a[n]);
        if mo == 17 {
            // free(): the memory goes and the place is null
            gl_rt2("__Arr__free", 1);
            gl_pnull(at_a[n]);
            return;
        }
        if mo == 2 { gl_rt2("__Str__pop", 1); }
        else if mo == 3 { gl_rt2("__Str__clear", 1); }
        else if mo == 14 { gl_rt2("__Str__count", 1); }
        else if mo == 15 { gl_rt2("__Str__to_int", 1); }
        else {
            gl_rt2("__Str__to_double", 1);
            ir_add(IR_BITS2F, 32, 1, 0, 0, 0);
        }
        return;
    }
    gl_sval(at_a[n]);
    int c0 = gl_cell(gl_depth);
    gl_store(30, c0, 1);
    gl_depth += 1;
    if mo == 1 {
        gl_expr(a);
        gl_ensure();
        ir_add(IR_COPY, 2, 1, 0, 0, 0);
        gl_load(1, 30, c0);
        gl_depth -= 1;
        gl_rt2("__Str__push", 2);
        return;
    }
    // append(x) / find(x) / contains(x) / starts_with(x) / ends_with(x): x0 = the String, x1 = the value, x2 = its kind
    gl_sval(a);
    gl_ensure();
    ir_add(IR_COPY, 2, 1, 0, 0, 0);
    gl_load(1, 30, c0);
    gl_depth -= 1;
    ir_add(IR_CONST, 3, 0, 0, 0, gl_skind(a));
    char^ rn = "__Str__append";
    if mo == 10 || mo == 11 { rn = "__Str__find"; }
    if mo == 12 { rn = "__Str__starts_with"; }
    if mo == 13 { rn = "__Str__ends_with"; }
    int e = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index(rn));
    gl_args[0] = 1;
    gl_args[1] = 2;
    gl_args[2] = 3;
    ir_set_args(e, 3, @gl_args);
    if mo == 11 {
        // contains: the place is 0 or more
        ir_add(IR_CONST, 2, 0, 0, 0, 0);
        ir_add(IR_SETCC, 1, 1, 2, 0, IR_GE);
    }
}

// the value of a String expression that a variable takes: v1 = a String that the variable owns (str_adopt)
void gl_sadopt(int n) {
    int k = at_kind[n];
    gl_sval(n);
    gl_ensure();
    if k == AK_STR {
        gl_rt2("__Str__from", 1);
    } else if k == AK_BIN || k == AK_CALL || (k == AK_METHOD && at_val[n] >= 2005) || (k == AK_METHOD && at_val[n] >= 0 && at_val[n] < 1000) || (k == AK_BUILTIN && at_val[n] == 13) {
        // a new String: taken over, the temporary is null
        if !go_null(at_c[n], 5) { gl_failx(15); }
    } else {
        gl_rt2("__Str__clone", 1);
    }
}

// the value of the node (at_c) that is an owner of the kind 2 when v1 is saved: used by calls for a text given to a String parameter
void gl_cond_top(int cond, int lt, int lf, int hastmp) {
    if hastmp == 0 {
        gl_cond(cond, lt, lf);
        return;
    }
    gl_expr(cond);
    go_flush(true);
    gl_br(IR_NE, 1, 0, 1, lt, lf);
}

// the value of a text or char operand for the routines
// try { } catch (e) { }: the callee-saved registers are kept, j2k_try_enter returns 0 now and 1 again after a throw
void gl_try(int n) {
    int snap = gl_bsl[n];
    gl_ensure();
    int k = 0;
    while k < 7 {
        int se = ir_add(IR_STORE, 0, 30, 20 + k, 0, snap + k * 8);
        ir_w[se] = 8;
        k += 1;
    }
    k = 0;
    while k < 8 {
        int se2 = ir_add(IR_STORE, 0, 30, 40 + k, 0, snap + 56 + k * 8);
        ir_w[se2] = 8;
        k += 1;
    }
    int ce = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("j2k_try_enter"));
    ir_set_args(ce, 0, @gl_args);
    int lcatch = gl_label();
    int lbody = gl_label();
    int lend = gl_label();
    gl_br(IR_NE, 1, 0, 1, lcatch, lbody);
    gl_place(lbody);
    gl_trydepth += 1;
    gl_stmt(at_a[n]);
    gl_trydepth -= 1;
    gl_ensure();
    int le = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("j2k_try_leave"));
    ir_set_args(le, 0, @gl_args);
    gl_jmp(lend);
    gl_place(lcatch);
    k = 0;
    while k < 7 {
        int lk = ir_add(IR_LOAD, 20 + k, 30, 0, 0, snap + k * 8);
        ir_w[lk] = 8;
        k += 1;
    }
    k = 0;
    while k < 8 {
        int lk2 = ir_add(IR_LOAD, 40 + k, 30, 0, 0, snap + 56 + k * 8);
        ir_w[lk2] = 8;
        k += 1;
    }
    gl_load(1, 28, 0);                                      // ldr x0, [x27, #0]: the text that was thrown
    gl_store(30, gl_off[at_val[n]], 1);
    gl_stmt(at_b[n]);
    gl_place(lend);
}

// the calls of j2k_try_leave for n try blocks that the flow leaves (v1 is an argument: it must stay)
void gl_leave_tries(int cnt) {
    while cnt > 0 {
        gl_rt1("j2k_try_leave", 1);
        cnt -= 1;
    }
}

// the value of a constant pattern
int gl_pat(int p) {
    if at_kind[p] == AK_NEG { return 0 - at_val[at_a[p]]; }
    return at_val[p];
}

// switch: the tests in order, then the bodies; the default runs when nothing matched wherever it is written
// switch on a data enum: the address of the struct waits in the slot; the tag is its first word; a member that binds names copies the
// values into the locals of the case first
void gl_switch_data(int n) {
    int slot = gl_bsl[n];
    gl_saddr(at_a[n]);
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
    if nc > 256 { gl_failx(0); return; }
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
                int te = ir_add(IR_LOAD, 1, 1, 0, 0, 0);
                ir_w[te] = 8;
                ir_add(IR_CONST, 2, 0, 0, 0, at_val[pt]);
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
        int bn = at_c[cs];
        while bn != 0 {
            int fi = at_b[bn];
            int bty = at_ty[bn];
            int loc = gl_off[at_val[bn]];
            gl_load(1, 30, slot);
            if bty / 65536 == 3 {
                gl_copy(30, loc, 1, fldoff[fi], ssize[bty % 65536 - 16]);
            } else if bty / 65536 == 1 && fldcode[fi] >= 16 && fldptr[fi] == 0 {
                // a struct that frees itself is only looked at: the name is its address
                ir_add(IR_ADD, 1, 1, fldoff[fi], 1, 0);
                gl_store(30, loc, 1);
            } else {
                int w = 8;
                if bty / 65536 == 0 { w = as1_flw(bty % 65536); }
                int le = ir_add(IR_LOAD, 2, 1, 0, 0, fldoff[fi]);
                ir_w[le] = w;
                gl_store(30, loc, 2);
            }
            bn = at_nx[bn];
        }
        gl_stmt(at_b[cs]);
        if at_kind[at_b[cs]] != AK_BLOCK { go_flush(false); }       // a body without braces is a statement of its own (parse_statement)
        gl_jmp(lend);
        ci += 1;
        cs = at_nx[cs];
    }
    gl_place(lend);
}

void gl_switch(int n) {
    if at_val[n] == 1 {
        gl_switch_data(n);
        return;
    }
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
    if nc > 256 { gl_failx(16); return; }
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
        if at_kind[at_b[cs]] != AK_BLOCK { go_flush(false); }
        gl_jmp(lend);
        ci += 1;
        cs = at_nx[cs];
    }
    gl_place(lend);
}

int sq_of_for(int n) { return at_a[n]; }

// the number of elements of the fixed array variable sq (a local or a global)
int gl_foreach_count(int sq) {
    int c = 0;
    if at_kind[sq] == AK_VAR { c = gl_acnt[at_val[sq]]; } else { c = gcnt[at_val[sq]]; }
    if c <= 0 { gl_failx(33); return 0; }
    return c;
}

// for x in things { }: the hidden variables are ..seq (the list), ..idx (the position) and the loop variable, in this order
void gl_foreach(int n) {
    int sq = at_a[n];
    int st = at_ty[sq];
    int kd = st / 65536;
    int bs = st % 65536;
    int seq = gl_bsl[n];
    int idx = seq + 8;
    if go_find_add(seq) >= 0 { idx = seq + 8 + 32; }
    int var = gl_off[at_val[n]];
    bool fixed = kd == 2;
    if fixed {
        // the address of element 0 and the number of elements
        gl_lv(sq);
        gl_ensure();
        if gl_ab != 1 || gl_ao != 0 { ir_add(IR_ADD, 1, gl_ab, gl_ao, 1, 0); }
    } else if at_kind[sq] == AK_METHOD && at_val[sq] == 2020 {
        gl_split(sq);
    } else if at_kind[sq] == AK_CALL || at_kind[sq] == AK_METHOD {
        gl_call(sq);
    } else {
        gl_pload(sq);
    }
    go_flush(true);                                         // the Strings of the list expression are not needed any more
    gl_ensure();
    gl_store(30, seq, 1);
    if !fixed { go_decl(seq); }                             // a list that a call made is an owner until the end of the loop
    ir_add(IR_CONST, 2, 0, 0, 0, 0);
    gl_store(30, idx, 2);
    if !fixed {
        gl_load(1, 30, seq);
        gl_nullchk();
    }
    int ecode = 8;
    if kd == 4 { ecode = 2; } else if kd == 5 { ecode = as1_dcode(st); } else { ecode = bs; }
    int esz = as1_bytes(ecode);
    int lc2 = gl_label();
    int lb2 = gl_label();
    int ls = gl_label();
    int le3 = gl_label();
    gl_place(lc2);
    gl_load(1, 30, idx);
    if fixed {
        ir_add(IR_CONST, 2, 0, 0, 0, gl_foreach_count(sq));
    } else {
        gl_load(2, 30, seq);
        gl_loadw(2, 2, 0, 8);
    }
    gl_br(IR_LT, 1, 2, 0, lb2, le3);
    gl_place(lb2);
    // the element
    gl_load(1, 30, idx);
    if esz == 8 { ir_add(IR_SHL, 1, 1, 3, 1, 0); } else if esz == 4 { ir_add(IR_SHL, 1, 1, 2, 1, 0); }
    if fixed {
        gl_load(2, 30, seq);
    } else {
        gl_load(2, 30, seq);
        gl_loadw(2, 2, 16, 8);
    }
    ir_add(IR_ADD, 1, 1, 2, 0, 0);
    gl_loadw(1, 1, 0, as1_flw(ecode));
    gl_store(30, var, 1);
    if gl_loops >= 32 { gl_failx(8); return; }
    gl_brk[gl_loops] = le3;
    gl_cnt[gl_loops] = ls;
    gl_looptry[gl_loops] = gl_trydepth;
    gl_loops += 1;
    gl_stmt(at_c[n]);
    gl_loops -= 1;
    gl_place(ls);
    gl_load(1, 30, idx);
    ir_add(IR_ADD, 1, 1, 1, 1, 0);
    gl_store(30, idx, 1);
    gl_jmp(lc2);
    gl_place(le3);
    if go_peek() == 2 && ow_a[go_pos] == 0 && ow_b[go_pos] == 0 { go_site(0, 0); }      // a list made by a call is freed here (the parser leaves no site number)
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
    if k == AK_THROW {
        int tv = at_a[n];
        if at_kind[tv] == AK_STR {
            int toff = gl_lit(at_val[tv], at_b[tv]);
            if toff < 0 { gl_failx(0); return; }
            gl_ensure();
            ir_add(IR_ADD, 1, 29, toff, 1, 0);
        } else {
            gl_expr(tv);
        }
        gl_rt1("j2k_throw", 1);
        return;
    }
    if k == AK_TRYCATCH {
        gl_try(n);
        return;
    }
    if k == AK_BLOCK {
        gl_blkn += 1;
        int bid = gl_blkn;
        gl_block_list(at_a[n]);
        go_site(1, bid);
        return;
    }
    if k == AK_DECL && at_ty[n] / 65536 == 4 {
        int soff = gl_off[at_val[n]];
        int sinit = at_a[n];
        gl_ensure();
        if sinit == 0 {
            // String name;  : the String of the empty text
            int eo = gl_lit(0, 0);
            if eo < 0 { gl_failx(17); return; }
            ir_add(IR_ADD, 1, 29, eo, 1, 0);
            gl_rt2("__Str__from", 1);
        } else {
            gl_sadopt(sinit);
        }
        gl_ensure();
        gl_store(30, soff, 1);
        go_flush(false);                // own_add frees the new Strings of the statement first
        go_decl(soff);
        return;
    }
    if k == AK_DECL && as1_dyn(at_ty[n]) {
        int doff = gl_off[at_val[n]];
        int dinit = at_a[n];
        gl_ensure();
        if dinit == 0 {
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
        } else if at_kind[dinit] == AK_NUM {
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
        } else if at_kind[dinit] == AK_METHOD && at_val[dinit] == 2020 {
            gl_split(dinit);
        } else if at_kind[dinit] == AK_CALL || (at_kind[dinit] == AK_METHOD && at_val[dinit] < 1000) {
            gl_call(dinit);
        } else if at_kind[dinit] != AK_BUILTIN {
            gl_pload(dinit);
        } else {
            // arr(n): the routine takes the size of an element and the number
            gl_expr(at_a[dinit]);
            gl_ensure();
            ir_add(IR_COPY, 2, 1, 0, 0, 0);
            ir_add(IR_CONST, 1, 0, 0, 0, as1_bytes(as1_dcode(at_ty[n])));
            gl_rt2("__Arr__make", 2);
        }
        gl_store(30, doff, 1);
        go_flush(false);                // own_add frees the new Strings of the statement first (a text given to a String parameter)
        go_decl(doff);
        return;
    }
    if k == AK_DECL {
        if as1_arr(at_ty[n]) || as1_sarr(at_ty[n]) {
            if at_a[n] == 0 && as1_sarr(at_ty[n]) && as1_hasinit(at_ty[n] % 65536 - 16) {
                // an array of structs that have init(): it runs on each element
                int isz = ssize[at_ty[n] % 65536 - 16];
                int ik = 0;
                while ik < at_b[n] {
                    gl_init_call(at_ty[n] % 65536 - 16, gl_off[at_val[n]] + ik * isz);
                    ik += 1;
                }
                return;
            }
            if at_a[n] != 0 && at_kind[at_a[n]] == AK_STR {
                // char w[16] = "text": the bytes in words of 8, the rest zeros (as the text path does)
                int sl = at_b[at_a[n]];
                int words = (at_b[n] + 7) / 8;
                int wi = 0;
                while wi < words {
                    int wv = 0;
                    int bi = 7;
                    while bi >= 0 {
                        int pos = wi * 8 + bi;
                        int bv = 0;
                        if pos < sl { bv = at_spool[at_val[at_a[n]] + pos] & 255; }
                        wv = (wv << 8) | bv;
                        bi -= 1;
                    }
                    gl_ensure();
                    ir_add(IR_CONST, 1, 0, 0, 0, wv);
                    gl_store(30, gl_off[at_val[n]] + wi * 8, 1);
                    wi += 1;
                }
                return;
            }
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
                go_decl(gl_off[at_val[n]]);
                return;
            }
            if at_a[n] != 0 {
                gl_saddr(at_a[n]);
                gl_ensure();
                gl_copy(30, gl_off[at_val[n]], 1, 0, ssize[at_ty[n] % 65536 - 16]);
                go_zero();                                  // a value that frees itself moved in: its source is emptied
                go_flush(false);
            } else if struct_needs_zero(at_ty[n] % 65536 - 16) {
                // a String or a dynamic array inside starts null: the struct starts as zeros
                gl_ensure();
                ir_add(IR_CONST, 2, 0, 0, 0, 0);
                int zk = 0;
                int zsz = ssize[at_ty[n] % 65536 - 16];
                while zk < zsz {
                    gl_store(30, gl_off[at_val[n]] + zk, 2);
                    zk += 8;
                }
            }
            if at_a[n] == 0 && as1_hasinit(at_ty[n] % 65536 - 16) { gl_init_call(at_ty[n] % 65536 - 16, gl_off[at_val[n]]); }
            go_decl(gl_off[at_val[n]]);
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
        go_decl(gl_off[at_val[n]]);
        return;
    }
    if k == AK_ASSIGN && as1_dyn(at_ty[at_c[n]]) {
        // a dynamic array place gets the same array as another place, or a new one
        int dp = at_c[n];
        int dv2 = at_a[n];
        if at_kind[dv2] == AK_BUILTIN {
            gl_expr(at_a[dv2]);
            gl_ensure();
            ir_add(IR_COPY, 2, 1, 0, 0, 0);
            ir_add(IR_CONST, 1, 0, 0, 0, as1_bytes(as1_dcode(at_ty[dp])));
            gl_rt2("__Arr__make", 2);
        } else if at_kind[dv2] == AK_NUM {
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
        } else if at_kind[dv2] == AK_CALL {
            gl_call(dv2);
        } else {
            gl_pload(dv2);
        }
        gl_ensure();
        int c7 = gl_cell(gl_depth);
        gl_store(30, c7, 1);
        gl_depth += 1;
        gl_pstore(dp, c7);
        gl_depth -= 1;
        go_drain_val(dv2);
        return;
    }
    if k == AK_ASSIGN && at_ty[at_c[n]] / 65536 == 4 {
        int sv2 = at_c[n];
        int sval = at_a[n];
        if at_b[n] == 0 {
            // = : the new String is made (a copy or taken over), the old content goes, the variable gets the new one
            gl_sadopt(sval);
            gl_ensure();
            int c5 = gl_cell(gl_depth);
            gl_store(30, c5, 1);
            gl_depth += 1;
            gl_pload(sv2);
            gl_rt2("__Arr__free", 1);
            gl_depth -= 1;
            gl_pstore(sv2, c5);
        } else {
            // += : append a String, a text or a char
            gl_sval(sval);
            gl_ensure();
            int c6 = gl_cell(gl_depth);
            gl_store(30, c6, 1);
            gl_depth += 1;
            gl_pload(sv2);
            gl_load(2, 30, c6);
            gl_depth -= 1;
            ir_add(IR_CONST, 3, 0, 0, 0, gl_skind(sval));
            int ea = ir_add(IR_CALL, 1, 0, 0, 0, ir_name_index("__Str__append"));
            gl_args[0] = 1;
            gl_args[1] = 2;
            gl_args[2] = 3;
            ir_set_args(ea, 3, @gl_args);
        }
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
        go_drain_val(at_a[n]);
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
        int ex = at_a[n];
        if at_kind[ex] == AK_BUILTIN && at_val[ex] == 6 {
            // free(p): the call, then the variable is null when it was an owner
            gl_expr(at_a[ex]);
            gl_rt1("Mem__free", 1);
            int pv = at_a[ex];
            if at_kind[pv] == AK_VAR { go_null(gl_off[at_val[pv]], 2); }
            return;
        }
        gl_expr(ex);
        if at_kind[ex] == AK_CALL && at_val[ex] >= 0 && fretstr[at_val[ex]] == 1 { gl_skeep(ex); }       // the String that came back is freed at the end of the statement
        // Mem::free(p) on an owner: null afterwards
        if (at_kind[ex] == AK_CALL) && at_a[ex] != 0 && at_kind[at_a[ex]] == AK_VAR && go_peek() == 4 { go_null(gl_off[at_val[at_a[ex]]], 2); }
        return;
    }
    if k == AK_IF {
        int lt = gl_label();
        int lf = gl_label();
        int le = gl_label();
        gl_cond_top(at_a[n], lt, lf, gl_hastmp[n]);
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
        gl_cond_top(at_a[n], lb, le2, gl_hastmp[n]);
        gl_place(lb);
        gl_nz_from(at_a[n]);
        if gl_loops >= 32 { gl_failx(18); return; }
        gl_brk[gl_loops] = le2;
        gl_cnt[gl_loops] = lc;
        gl_looptry[gl_loops] = gl_trydepth;
        gl_loops += 1;
        gl_stmt(at_b[n]);
        gl_loops -= 1;
        gl_jmp(lc);
        gl_place(le2);
        return;
    }
    if k == AK_FOR && at_b[n] == 0 {
        gl_foreach(n);
        return;
    }
    if k == AK_FOR {
        gl_for(n);
        return;
    }
    if k == AK_RET {
        gl_retn += 1;
        int rid = gl_retn;
        if at_a[n] != 0 && as1_sty(at_ty[at_a[n]]) {
            // a struct result is written through the address that came in the hidden first parameter
            gl_saddr(at_a[n]);
            gl_ensure();
            gl_load(3, 30, gl_retoff);
            gl_copy(3, 0, 1, 0, ssize[at_ty[at_a[n]] % 65536 - 16]);
            go_zero();
        } else if at_a[n] != 0 && at_ty[at_a[n]] / 65536 == 5 {
            // a dynamic array result: its header (an owner moves out: the parser nulls it)
            int rd = at_a[n];
            if at_kind[rd] == AK_BUILTIN {
                gl_expr(at_a[rd]);
                gl_ensure();
                ir_add(IR_COPY, 2, 1, 0, 0, 0);
                ir_add(IR_CONST, 1, 0, 0, 0, as1_bytes(as1_dcode(at_ty[rd])));
                gl_rt2("__Arr__make", 2);
            } else if at_kind[rd] == AK_CALL {
                gl_call(rd);
            } else {
                gl_pload(rd);
            }
        } else if at_a[n] == 0 && gl_ismain == 1 {
            gl_ensure();
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
        } else if at_a[n] != 0 && at_ty[at_a[n]] / 65536 == 4 {
            // a String result: an owner or a temporary moves out, a text is made into a String, anything else is copied
            int rs = at_a[n];
            gl_sval(rs);
            gl_ensure();
            if at_kind[rs] == AK_STR {
                gl_rt2("__Str__from", 1);
            } else if at_kind[rs] == AK_VAR && !(go_peek() == 4 && ow_b[go_pos] == 1 && ow_a[go_pos] == gl_off[at_val[rs]]) {
                gl_rt2("__Str__clone", 1);
            }
        } else if at_a[n] != 0 {
            if gl_retd == 1 {
                gl_expr_d(at_a[n]);
                gl_ensure();
                ir_add(IR_F2BITS, 1, 32, 0, 0, 0);
            } else {
                gl_expr(at_a[n]);
            }
        }
        gl_leave_tries(gl_trydepth);
        // the owners are freed here (what the parser did): the value waits in a cell; a returned owner is null first
        if (go_peek() == 4 && ow_b[go_pos] == 1) || (go_peek() == 2 && ow_a[go_pos] == 2 && ow_b[go_pos] == rid) {
            gl_ensure();
            int vc = gl_cell(gl_depth);
            gl_store(30, vc, 1);
            gl_depth += 1;
            if go_peek() == 4 {
                int rv = at_a[n];
                int rvoff = 0 - 1;
                if rv != 0 && at_kind[rv] == AK_VAR { rvoff = gl_off[at_val[rv]]; }
                if rv != 0 && at_kind[rv] != AK_VAR && at_ty[rv] / 65536 == 4 { rvoff = at_c[rv]; }
                if rvoff < 0 || !go_null(rvoff, 1) { gl_failx(19); return; }
            }
            if !go_site(2, rid) { gl_failx(20); return; }
            gl_depth -= 1;
            gl_load(1, 30, vc);
        }
        gl_jmp(gl_ret);
        return;
    }
    if k == AK_BREAK {
        if gl_loops == 0 { gl_failx(21); return; }
        gl_leave_tries(gl_trydepth - gl_looptry[gl_loops - 1]);
        gl_brkn += 1;
        go_site(3, gl_brkn);
        gl_jmp(gl_brk[gl_loops - 1]);
        return;
    }
    if k == AK_CONT {
        if gl_loops == 0 { gl_failx(22); return; }
        gl_leave_tries(gl_trydepth - gl_looptry[gl_loops - 1]);
        gl_brkn += 1;
        go_site(4, gl_brkn);
        gl_jmp(gl_cnt[gl_loops - 1]);
        return;
    }
    gl_failx(23);
}

// the offsets of the locals in the order of the declarations; the text of the hint line that this makes goes to the buffer
char gl_hint[8192];
int gl_hint_n;

void gl_hint_add(int off) {
    gl_hint_add2(off, 8, 1);
}

// the hint of a hidden slot that holds a struct: the parser calls one of 8 bytes a plain 8-byte value (a variable of the struct is not)
void gl_hint_struct(int off, int size) {
    if size == 8 { gl_hint_add(off); } else { gl_hint_add2(off, size, 0); }
}

void gl_hint_add2(int off, int size, int flag) {
    if gl_hint_n > 8000 { gl_failx(24); return; }
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

// the events of the function fi are ow_lo .. go_end: ow_lo is the first
int ow_lo;
void go_range(int fi) {
    int i = 0;
    while i < ow_n && ow_fn[i] != fi { i += 1; }
    ow_lo = i;
    while i < ow_n && ow_fn[i] == fi { i += 1; }
    go_pos = ow_lo;
    go_end = i;
}

// the event that added an owner at the frame offset off, or -1
int go_find_add(int off) {
    int i = ow_lo;
    while i < go_end {
        if ow_ty[i] == 1 && ow_a[i] == off { return i; }
        i += 1;
    }
    return 0 - 1;
}

// the hidden slots of the results of calls that give a struct, in the order the parser makes them: a call makes its slot when its name
// is read (before its arguments); a method call after its object. The offset goes to the field c of the node.
// the hidden slot of a new String (a temporary owner: `.t`, 8 bytes, then its record of 32 bytes); its offset goes to the field c

void gl_stemp(int n) {
    gl_nstemps += 1;
    at_c[n] = gl_nslot;
    gl_hint_add(gl_nslot);
    gl_nslot += 8;
    int oe = go_find_add(at_c[n]);
    if oe < 0 || ow_d[oe] != gl_nslot { gl_failx(25); return; }
    gl_nslot += 32;
}

void gl_tmps(int n) {
    if n == 0 { return; }
    int k = at_kind[n];
    if at_ty[n] / 65536 == 4 && (k == AK_BIN || (k == AK_METHOD && at_val[n] < 3000) || (k == AK_BUILTIN && at_val[n] == 13)) {
        // a new String: the operands first, then the temporary
        if k == AK_BUILTIN {
            gl_tmps(at_a[n]);
        } else if k == AK_BIN {
            gl_tmps(at_a[n]);
            gl_tmps(at_b[n]);
        } else {
            gl_tmps(at_a[n]);
            int sa = at_b[n];
            while sa != 0 {
                gl_tmps(sa);
                sa = at_nx[sa];
            }
        }
        gl_stemp(n);
        return;
    }
    if k == AK_METHOD && at_val[n] >= 1000 {
        // a member function of a dynamic array or a String: the receiver (a temporary String has its slot first), then the arguments
        gl_tmps(at_a[n]);
        int ma = at_b[n];
        while ma != 0 {
            gl_tmps(ma);
            ma = at_nx[ma];
        }
        if at_val[n] == 3002 || at_val[n] == 3010 { gl_stemp(n); }
        return;
    }
    if k == AK_CALL || k == AK_METHOD {
        int fi = at_val[n];
        if k == AK_METHOD { gl_tmps(at_a[n]); }
        if fi >= 0 && fvoid[fi] == 0 && fret[fi] >= 100 {
            int sz = ssize[fret[fi] - 100];
            at_c[n] = gl_nslot;
            gl_hint_struct(gl_nslot, sz);              // the hidden slot of a struct result: the parser makes it with the type id 0
            gl_nslot += (sz + 7) / 8 * 8;
        }
        int a = at_a[n];
        int pidx = 0;
        if k == AK_METHOD {
            a = at_b[n];
            pidx = 1;
        }
        while a != 0 {
            gl_tmps(a);
            // a text for a String parameter: a temporary String is made
            if fi >= 0 && at_kind[a] == AK_STR && pidx < 8 && fpstr[fi * 8 + pidx] == 1 { gl_stemp(a); }
            // a value that frees itself goes in a copy (`..moved`) and its source is emptied
            if fi >= 0 && pidx < 8 && fptid[fi * 8 + pidx] >= 100 && fptid[fi * 8 + pidx] < 100 + scount && struct_has_free(fptid[fi * 8 + pidx] - 100) {
                int msz = ssize[fptid[fi * 8 + pidx] - 100];
                gl_mvslot[a] = gl_nslot;
                gl_hint_struct(gl_nslot, msz);
                gl_nslot += (msz + 7) / 8 * 8;
            }
            pidx += 1;
            a = at_nx[a];
        }
        // the result that frees itself is an owner of the kind 6 until the end of the statement (its record comes after the call)
        if fi >= 0 && fvoid[fi] == 0 && fret[fi] >= 100 && at_c[n] != 0 && struct_has_free(fret[fi] - 100) && cond_depth == 0 {
            int oe6 = go_find_add(at_c[n]);
            if oe6 >= 0 {
                if ow_d[oe6] != gl_nslot { gl_failx(0); }
                gl_nslot += 32;
            }
        }
        // a String that comes back is a temporary owner
        if fi >= 0 && fretstr[fi] == 1 && (k == AK_CALL || k == AK_METHOD) { gl_stemp(n); }
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
        int own_at = gl_nslot;
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_acnt[at_val[n]] = at_b[n]; }
        if as1_dyn(at_ty[n]) || at_ty[n] / 65536 == 4 {
            gl_hint_add2(gl_nslot, 8, 0);
            gl_nslot += 8;
        } else if as1_arr(at_ty[n]) {
            if at_val[n] >= 0 && at_val[n] < 1024 { gl_ast1[at_val[n]] = at_c[n] % 65536; gl_ast2[at_val[n]] = at_c[n] / 65536; }
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
            if at_a[n] == 0 && as1_hasinit(at_ty[n] % 65536 - 16) {
                gl_hint_add(gl_nslot);              // the counter of the loop that runs init() on each element (..i)
                gl_nslot += 8;
            }
        } else {
            gl_hint_add(gl_nslot);
            gl_nslot += 8;
        }
        // a variable that owns memory has a record of the cleanup chain after it (32 bytes, not in the hint line)
        int oe = go_find_add(own_at);
        if oe >= 0 {
            if ow_d[oe] != gl_nslot { gl_failx(26); }
            gl_nslot += 32;
        }
    } else if k == AK_FOR && at_b[n] == 0 {
        // for x in things: ..seq (+ its record when a call made the list), ..idx, the variable
        gl_tmps(at_a[n]);
        gl_bsl[n] = gl_nslot;
        gl_hint_add(gl_nslot);
        int seq_at = gl_nslot;
        gl_nslot += 8;
        int soe = go_find_add(seq_at);
        if soe >= 0 {
            if ow_d[soe] != gl_nslot { gl_failx(32); }
            gl_nslot += 32;
        }
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        if at_ty[sq_of_for(n)] / 65536 == 5 && at_ty[sq_of_for(n)] % 65536 == 4008 { gl_hint_add2(gl_nslot, 8, 0); } else { gl_hint_add(gl_nslot); }
        gl_nslot += 8;
        gl_slots(at_c[n]);
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
        int ns0 = gl_nstemps;
        gl_tmps(at_a[n]);
        gl_hastmp[n] = 0;
        if gl_nstemps != ns0 { gl_hastmp[n] = 1; }
        gl_slots(at_b[n]);
        gl_slots(at_c[n]);
    } else if k == AK_WHILE {
        int ns1 = gl_nstemps;
        gl_tmps(at_a[n]);
        gl_hastmp[n] = 0;
        if gl_nstemps != ns1 { gl_hastmp[n] = 1; }
        gl_slots(at_b[n]);
    } else if k == AK_TRYCATCH {
        // the registers x19 .. x25 and d8 .. d15 are kept in 120 bytes; then the try block, the name of the text, the catch block
        gl_bsl[n] = gl_nslot;
        gl_hint_add2(gl_nslot, 120, 0);
        gl_nslot += 120;
        gl_slots(at_a[n]);
        if at_val[n] >= 0 && at_val[n] < 1024 { gl_off[at_val[n]] = gl_nslot; }
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        gl_slots(at_b[n]);
    } else if k == AK_THROW {
        gl_tmps(at_a[n]);
    } else if k == AK_SWITCH {
        gl_tmps(at_a[n]);
        gl_bsl[n] = gl_nslot;
        gl_hint_add(gl_nslot);
        gl_nslot += 8;
        int cs = at_b[n];
        while cs != 0 {
            // the names that a member binds: a local each (a copy of a struct takes its size)
            int bn = at_c[cs];
            while bn != 0 {
                gl_off[at_val[bn]] = gl_nslot;
                int bty = at_ty[bn];
                if bty / 65536 == 3 {
                    int bsz = ssize[bty % 65536 - 16];
                    gl_hint_add2(gl_nslot, bsz, 0);
                    gl_nslot += (bsz + 7) / 8 * 8;
                } else if bty / 65536 == 4 || bty / 65536 == 5 {
                    gl_hint_add2(gl_nslot, 8, 0);
                    gl_nslot += 8;
                } else {
                    gl_hint_add(gl_nslot);
                    gl_nslot += 8;
                }
                bn = at_nx[bn];
            }
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
    gl_ismain = 0;
    if str_eq(name, "main") { gl_ismain = 1; }
    int fi = at_fidx[ti];
    if gl_ismain == 1 && opt_debug == 1 { return 0; }        // the -d report at the end of main: the text path
    int np = fnpar[fi];
    // the frame: what the parser had when the body began (the hidden slots and the parameters), then the locals as it declares them
    gl_nslot = at_fb[ti];
    str_copy(@gl_hint, @at_hint + ti * 256, 8000);
    gl_hint_n = str_len(@gl_hint);
    gl_fail = 0;
    gl_fcode = 0;
    int nl = at_nl[ti];
    int p = 0;
    while p < nl {
        gl_off[p] = at_loff[ti * 32 + p];
        p += 1;
    }
    go_range(fi);
    if opt_debug == 1 && go_end > ow_lo { return 0; }       // a -d build keeps the line of every allocation: the text path
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
    // the owners that the parameters are (a struct by value that frees itself): their records come first
    go_pos = ow_lo;
    while go_peek() == 1 && ow_a[go_pos] < at_fb[ti] { go_decl(ow_a[go_pos]); }
    gl_ret = gl_label();
    gl_blkn = 0;
    gl_retn = 0;
    gl_brkn = 0;
    gl_stmt(at_root[ti]);
    go_site(5, 0);
    // every event of the parser was used: what the tree did is what the text path did
    if go_pos != go_end { gl_failx(27); }
    if gl_fail == 1 { return 0; }
    if gl_ismain == 1 {
        // main: falling off the end gives 0; the end is the exit call (the text path: `mov x0, 0`, the label, `mov x8, 94`, `svc 0`)
        if gl_term == 0 {
            gl_ensure();
            ir_add(IR_CONST, 1, 0, 0, 0, 0);
        }
        gl_place(gl_ret);
        ir_add(IR_CONST, 9, 0, 0, 0, 94);
        int xe = ir_add(IR_SYSCALL, 1, 9, 0, 0, 0);
        int xk = 0;
        while xk < 8 {
            gl_args[xk] = xk + 1;
            xk += 1;
        }
        ir_set_args(xe, 8, @gl_args);
        ir_ac[xe] = 1;
        ir_add(IR_TRAP, 0, 0, 0, 0, 0);
        gl_term = 1;
    } else {
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
    }
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
        else {
            write_err(" not lowered [");
            write_err_int(gl_fcode);
            write_err("]");
            if go_pos < go_end {
                write_err(" (the next event: ");
                write_err_int(ow_ty[go_pos]);
                write_err(" ");
                write_err_int(ow_a[go_pos]);
                write_err(" ");
                write_err_int(ow_b[go_pos]);
                write_err(" ");
                write_err_int(ow_c[go_pos]);
                write_err(" ");
                write_err_int(ow_d[go_pos]);
                write_err(" at ");
                write_err_int(go_pos - ow_lo);
                write_err(")");
            }
            write_err("\n");
        }
        // the ownership events of the function (the text parser's decisions)
        int oe = 0;
        while oe < ow_n {
            if ow_fn[oe] == at_fidx[ti] {
                write_err("  own ");
                write_err_int(ow_ty[oe]);
                write_err(" ");
                write_err_int(ow_a[oe]);
                write_err(" ");
                write_err_int(ow_b[oe]);
                write_err(" ");
                write_err_int(ow_c[oe]);
                write_err(" ");
                write_err_int(ow_d[oe]);
                write_err("\n");
            }
            oe += 1;
        }
    }
    return ok;
}
