// jc_expr.jk -- part 3 of the J2K compiler written in J2K: symbols,
// variables and expressions.
//
// Code model (see jc_base.jk): a value is a 64-bit integer, an expression
// leaves its result in x0, operands waiting for the other side are pushed on
// the stack, locals live at [x29 + offset], globals at [x28 + offset].
// Scalars take 8 bytes (a char is wrapped to 0..255 when it is stored).
// Arrays hold bytes (char, bool) or 8-byte ints. A pointer variable is a
// scalar that remembers how big the thing it points to is (1 or 8 bytes),
// so p[i] and p^ know what to load.
//
// Rule for this file (the first compiler has no block scope): a local
// variable name is used only once per function.

// the type last read by parse_type (jc_stmt.jk); width codes: 1 i8, 2 char,
// 3 bool, 4 i32, 8 int
int ty_elem;                 // code for one array element of this type
int ty_width;                // code for a scalar of this type
int ty_ptr;                  // 0, or the code of the pointee for T^
int ty_void;                 // 1 for "void"
int ty_dyn;                  // 0, or the packed element type of a dynamic array T[] (see dyn_pack)
int arr_esize;               // element size for the arr(n) being parsed (0 = not known)
// ---- ownership of memory (alloc / arr): a local variable declared from them frees it at the end of its block
int own_off[256];            // frame offset of each owner (innermost last)
int own_kind[256];           // 0 = Mem::alloc block, 1 = dynamic array / String, 2 = temporary String, 4 = a struct with a free(self) method
int own_aux[256];            // kind 4: the struct
int own_rec[256];            // the frame offset of its cleanup record (see own_add)
int stmt_t0;                 // own_count where the statement being parsed began
int own_blk[256];            // the block it belongs to
int own_moved[256];          // 1 after the ownership went elsewhere (for the "used after move" warning)
int own_count;
int cur_blk;                 // id of the block being parsed
int blk_serial;
int own_ok = 1;              // 0 where a declaration may not run (a case body without braces)
int ex_dyn;                  // the packed element type of the dynamic array the last expression was (0 = none)
int ex_arr_cnt = -1;         // set when the last expression was a whole fixed array: its element count ...
int ex_arr_code;             // ... and its element width code
int lalias[8192];            // 1: a variable that is a pointer to a struct but is used like the struct itself (a name in a case)
int lused[8192];             // 1 once the name was looked up after its declaration
int lwarn[8192];             // 1: warn if it is never used (a scalar or array made by a declaration statement)
int lw_line[8192];           // where it was declared
int lw_col[8192];
int lw_base[8192];
int lw_ls[8192];
int track_unused;            // 1 while a declaration statement is parsed
int decl_line;               // the position of the name being declared
int decl_col;
int decl_base;
int decl_ls;
int rv_valid;                // the last operand read was exactly a plain local variable ...
int rv_off;                  // ... at this frame offset
int last_call_struct;        // the last call made a struct value (a fresh temporary)
int own_src_off;             // struct_source: the frame offset of the local variable (or temporary) a value moves out of
int cond_depth;              // > 0 while the right side of && or || is compiled (it may not run)
int last_call_struct_off;    // the frame offset of the temporary that the last call's struct result is in
int last_call_owning;        // the last call made returns memory its receiver owns
int ty_tid;                  // type of values: 0 number, 1 bool, 3+n enum number n
int ex_ty;                   // type of the last operand/result: 0 number, 1 bool, 2 the literal 0 or 1, 3+n enum n
int ex_w;                    // width code of the last operand/result: 0 = a plain number, else 1 i8, 2 char, 3 bool, 4 i32, 8 int

char sname[16384];           // 256 x 64
int ssize[256];               // bytes, a multiple of 8
int sfirst[256];              // its first field in the field tables
int snf[256];                 // how many fields
int scount;
char fldname[524288];         // 1024 x 64
int fldcode[8192];           // width code of the field (8 int, 16+n a struct ...)
int fldoff[8192];
int fldkind[8192];           // 0 scalar, 1 array
int fldptr[8192];
int fldtid[8192];
int fldnd[8192];
int fldst1[8192];
int fldst2[8192];
int fldcnt[8192];
int flddyn[8192];
int fldcount;

int find_struct(char^ name) {
    int i = 0;
    while i < scount {
        if str_eq(@sname + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}

int find_field(int s, char^ name) {
    int i = sfirst[s];
    int last = sfirst[s] + snf[s];
    while i < last {
        if str_eq(@fldname + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}

// ------------------------------------------------------------------ enums
char ename[4096];            // 64 x 64
int ecount;
char emname[524288];          // 512 members x 64
int emval[8192];
int emenum[8192];
int emcount;
int us_g[256];                // "using Struct" at file level
int us_l[256];                // ... inside the current function
int ue_g[64];                // "using enum" at file level
int ue_l[64];                // ... inside the current function

int find_enum(char^ name) {
    int i = 0;
    while i < ecount {
        if str_eq(@ename + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}

// the member `name` of enum `en`, or -1 (the value is left in found_val)
int found_val;
bool find_member(int en, char^ name) {
    int i = 0;
    while i < emcount {
        if emenum[i] == en && str_eq(@emname + i * 64, name) {
            found_val = emval[i];
            return true;
        }
        i += 1;
    }
    return false;
}

// a bare member name made visible by "using enum": sets found_val, ex_ty
bool find_using_member(char^ name) {
    int en = 0;
    while en < ecount {
        if ue_g[en] == 1 || ue_l[en] == 1 {
            if find_member(en, name) {
                ex_ty = 3 + en;
                return true;
            }
        }
        en += 1;
    }
    return false;
}

// ---------------------------------------------------- function pointer types
// A function pointer variable is an 8-byte scalar whose type id is negative:
// -(n+1) = signature n  (the result type and the parameter types).
int sig_ret[256];            // result type id (98 = void)
int sig_n[256];
int sig_p[4096];             // 16 parameter type ids per signature
int sig_count;
int sg_tmp[16];              // parameters of the signature being built

bool is_fnptr(int t) {
    return t < 0;
}

int sig_intern(int ret, int n) {
    int i = 0;
    while i < sig_count {
        if sig_ret[i] == ret && sig_n[i] == n {
            int same = 1;
            int k = 0;
            while k < n {
                if sig_p[i * 16 + k] != sg_tmp[k] { same = 0; }
                k += 1;
            }
            if same == 1 { return i; }
        }
        i += 1;
    }
    if sig_count >= 256 { die("too many different function pointer types"); }
    sig_ret[sig_count] = ret;
    sig_n[sig_count] = n;
    int j = 0;
    while j < n {
        sig_p[sig_count * 16 + j] = sg_tmp[j];
        j += 1;
    }
    sig_count += 1;
    return sig_count - 1;
}

// ------------------------------------------------------------ type checks
// (only in pass 2, when every function and enum is known)

// the text for a type id in messages
void type_name_err(int t) {
    if t == 99 {
        write_err("a dynamic array");
    } else if t < 0 {
        write_err("a function pointer");
    } else if t == 1 {
        write_err("bool");
    } else if t == 93 {
        write_err("u8");
    } else if t == 94 {
        write_err("u32");
    } else if t == 95 {
        write_err("u64");
    } else if t == 96 {
        write_err("a number");
    } else if t == 90 {
        write_err("float");
    } else if t == 91 {
        write_err("double");
    } else if t == 92 {
        write_err("a decimal number");
    } else if t >= 100 {
        write_err(@sname + (t - 100) * 64);
    } else if t >= 3 {
        write_err(@ename + (t - 3) * 64);
    } else {
        write_err("a number");
    }
}

// ---------------------------------------------------------------- floats
// A float lives in x0 as its IEEE bits: f64 = 64 bits, f32 = the low 32 bits.
// Types: 90 f32, 91 f64, 92 a decimal literal (it becomes f32 or f64 as needed).

bool is_float(int t) {
    return t >= 90 && t <= 92;
}

// "fmov dR, xR ; fcvt sR, dR ; fmov wR, sR": f64 bits in xR become f32 bits
void lit_to_f32(int r) {
    emit_str("fmov d");
    emit_int(r);
    emit_str(", x");
    emit_int(r);
    emit_nl();
    emit_str("fcvt s");
    emit_int(r);
    emit_str(", d");
    emit_int(r);
    emit_nl();
    emit_str("fmov w");
    emit_int(r);
    emit_str(", s");
    emit_int(r);
    emit_nl();
}

// f32 bits in xR become f64 bits
void f32_to_f64(int r) {
    emit_str("fmov s");
    emit_int(r);
    emit_str(", w");
    emit_int(r);
    emit_nl();
    emit_str("fcvt d");
    emit_int(r);
    emit_str(", s");
    emit_int(r);
    emit_nl();
    emit_str("fmov x");
    emit_int(r);
    emit_str(", d");
    emit_int(r);
    emit_nl();
}

// x0 = left, x1 = right, types lt / rt: both must be floats (a literal adapts);
// returns 90 when the operation is done in f32, else 91; the operands are ready
int fp_prepare(int lt, int rt) {
    if (!is_float(lt) || !is_float(rt)) && pass_no >= 2 { die("cannot mix a float and a non-float (use a cast, e.g. (double)n)"); }
    if (lt == 90 && rt == 91) || (lt == 91 && rt == 90) { die("cannot mix float and double (use a cast)"); }
    if lt == 90 || rt == 90 {
        if lt == 92 { lit_to_f32(0); }
        if rt == 92 { lit_to_f32(1); }
        return 90;
    }
    return 91;
}

// x0 = x0 op x1 for + - * /  ; returns the result type
int fp_binop(char^ op, int lt, int rt) {
    int kind = fp_prepare(lt, rt);
    char ins[8];
    if str_eq(op, "+") { str_copy(@ins, "fadd", 8); }
    else if str_eq(op, "-") { str_copy(@ins, "fsub", 8); }
    else if str_eq(op, "*") { str_copy(@ins, "fmul", 8); }
    else if str_eq(op, "/") { str_copy(@ins, "fdiv", 8); }
    else { die_name("this operator does not work on floats", op); }
    if kind == 90 {
        emit_line("fmov s0, w0");
        emit_line("fmov s1, w1");
        emit_str(@ins);
        emit_line(" s0, s0, s1");
        emit_line("fmov w0, s0");
        return 90;
    }
    emit_line("fmov d0, x0");
    emit_line("fmov d1, x1");
    emit_str(@ins);
    emit_line(" d0, d0, d1");
    emit_line("fmov x0, d0");
    if lt == 92 && rt == 92 { return 92; }
    return 91;
}

// x0 = (left cond right) for floats: cond is the integer-style name (lt le gt ge eq ne)
void fp_compare(char^ cond, int lt, int rt) {
    int kind = fp_prepare(lt, rt);
    if kind == 90 {
        emit_line("fmov s0, w0");
        emit_line("fmov s1, w1");
        emit_line("fcmp s0, s1");
    } else {
        emit_line("fmov d0, x0");
        emit_line("fmov d1, x1");
        emit_line("fcmp d0, d1");
    }
    // after fcmp, "lt" and "le" would be true for NaN; mi / ls are not
    char fc[4];
    str_copy(@fc, cond, 4);
    if str_eq(cond, "lt") { str_copy(@fc, "mi", 4); }
    if str_eq(cond, "le") { str_copy(@fc, "ls", 4); }
    int ld = new_label();
    emit_line("mov x0, 1");
    jump_if(@fc, ld);
    emit_line("mov x0, 0");
    place_label(ld);
}

// the bits of the double 10^k for k = 19 .. 22 (exact)
int pow10_bits(int k) {
    if k == 19 { return 4891288408196988160; }
    if k == 20 { return 4906019910204099648; }
    if k == 21 { return 4921056587992461136; }
    return 4936209963552724370;
}

// the literal being read (tok_mant * 10^tok_exp) -> x0 as f64 bits
void gen_float_literal() {
    ins_n("mov x0, ", tok_mant);
    emit_line("scvtf d0, x0");
    if tok_exp != 0 {
        int p10 = 1;
        int pk = 0;
        int ae = tok_exp;
        if ae < 0 { ae = 0 - ae; }
        if ae <= 18 {
            while pk < ae {
                p10 = p10 * 10;
                pk += 1;
            }
            ins_n("mov x1, ", p10);
            emit_line("scvtf d1, x1");
        } else {
            // 10^19 .. 10^22 do not fit an integer register but are exact doubles: their bits
            ins_n("mov x1, ", pow10_bits(ae));
            emit_line("fmov d1, x1");
        }
        if tok_exp < 0 {
            emit_line("fdiv d0, d0, d1");
        } else {
            emit_line("fmul d0, d0, d1");
        }
    }
    emit_line("fmov x0, d0");
    ex_w = 7;
    ex_ty = 92;
    next();
}

bool is_unsigned(int t) {
    return t >= 93 && t <= 95;
}

// a number of any kind (96 = a whole-number literal, 2 = the literal 0 or 1)
bool is_numeric(int t) {
    return t == 0 || t == 2 || t == 96 || is_unsigned(t);
}

bool is_litnum(int t) {
    return t == 2 || t == 96;
}

// signed and unsigned do not mix without a cast (two unsigned sizes do: the wider one wins)
bool num_compat(int a, int b) {
    if is_unsigned(a) && b == 0 { return false; }
    if is_unsigned(b) && a == 0 { return false; }
    return true;
}

// the type of  a OP b  (+ - * / % & | xor): dies on a bool, an enum, a float, or a bad mix
int bin_type(int a, int b) {
    if pass_no < 2 { return 0; }
    if !is_numeric(a) || !is_numeric(b) { die("arithmetic needs numbers (bool and enum values cannot be used)"); }
    if !num_compat(a, b) { die("cannot mix signed and unsigned numbers (use a cast, e.g. (u32)x)"); }
    if is_unsigned(a) && is_unsigned(b) {
        if a > b { return a; }           // u8 < u32 < u64: the wider one
        return b;
    }
    if is_unsigned(a) { return a; }
    if is_unsigned(b) { return b; }
    if is_litnum(a) && is_litnum(b) { return 96; }
    return 0;
}

// a << n  /  a >> n : the type of the left side
int shift_type(int a, int b) {
    if pass_no < 2 { return 0; }
    if !is_numeric(a) || !is_numeric(b) { die("arithmetic needs numbers (bool and enum values cannot be used)"); }
    if is_unsigned(a) { return a; }
    if is_litnum(a) && is_litnum(b) { return 96; }
    return 0;
}

// the value in x0 (type ex_ty) is stored where a `want` is expected
void check_assign(int want) {
    if pass_no < 2 { return; }
    int ok = 0;
    if want == 90 && (ex_ty == 90 || ex_ty == 92) { ok = 1; }
    if want == 91 && (ex_ty == 91 || ex_ty == 92) { ok = 1; }
    if ok == 1 && want == 90 && ex_ty == 92 { lit_to_f32(0); }
    if want == 0 && (ex_ty == 0 || ex_ty == 2 || ex_ty == 96 || ex_ty == 97) { ok = 1; }
    if want == 99 && (ex_ty == 99 || ex_ty == 97 || ex_ty == 80) { ok = 1; }          // a dynamic array (or null)
    if want < 0 && (ex_ty == want || ex_ty == 97) { ok = 1; }          // a function pointer: the same signature, or null
    if is_unsigned(want) && (ex_ty == 2 || ex_ty == 96) { ok = 1; }
    if is_unsigned(want) && is_unsigned(ex_ty) && ex_ty <= want { ok = 1; }      // widening needs no cast
    if want == 1 && (ex_ty == 1 || ex_ty == 2) { ok = 1; }
    if want >= 3 && ex_ty == want { ok = 1; }          // an enum, a struct, a float, an unsigned type of the same kind
    if ok == 0 {
        begin_msg("error");
        write_err("type mismatch: expected ");
        type_name_err(want);
        write_err(", got ");
        if ex_ty == 2 { write_err("a number"); } else { type_name_err(ex_ty); }
        write_err(" (use a comparison for a bool, or a cast)");
        end_msg();
        syscall(93, 1);
    }
}

// the operand in x0 must be a bool (or the literal 0/1)
void need_bool() {
    if pass_no < 2 { return; }
    if ex_ty != 1 && ex_ty != 2 { die("a bool is required here (write a comparison, e.g. x != 0)"); }
}

// the operand must be an ordinary number (not bool, not enum)
void need_num(int t) {
    if pass_no < 2 { return; }
    if !is_numeric(t) { die("arithmetic needs numbers (bool and enum values cannot be used)"); }
}

// ------------------------------------------------------------ symbol tables

// locals of the function being compiled (parameters first)
char lname[524288];           // 1024 x 64
int lkind[8192];             // 0 scalar, 1 array
int lelem[8192];             // array: element size; scalar: width (1 = char, 8 = int)
int loff[8192];              // frame offset from x29
int lptr[8192];              // pointer variable: size of the pointee (0 = not a pointer)
int lnd[8192];               // array dimensions: 1, 2 or 3
int lst1[8192];              // elements to skip for a step in the first index
int lst2[8192];              // ... in the second index (3 dimensions)
int lblk[8192];              // the block each local variable was declared in
int blk_parent[4096];        // parent block of each block id (0 = the function body's outside)
int ldyn[8192];              // kind 3 (dynamic array): the packed element type
int ltid[8192];              // type of a scalar / of an array's elements
int lcnt[8192];              // array: number of elements
int scope_base;              // locals below this index belong to enclosing blocks
int lcount;
int frame_bytes;             // frame used so far (starts at 16: saved x29, x30)

// globals
char gname[1048576];           // 2048 x 64
int gkind[16384];
int gelem[16384];
int goff[16384];
int gptr[16384];
int gnd[16384];
int gst1[16384];
int gst2[16384];
int gdyn[16384];
int gtid[16384];
int gcnt[16384];
int gcount;
int gl_bytes;                // bytes of the global area handed out (slot 0 = initial sp)

// global initial values, stored at startup by the start stub
int ginit_off[262144];
int ginit_val[262144];
int ginit_count;

// functions seen so far (to tell a call from an unknown name)
char fname[1048576];          // 2048 x 64
int fnpar[16384];             // declared parameters (an array parameter counts once)
int fvoid[16384];            // 1 if the function returns void
int fpstr[131072];             // 1 for a parameter of type String (8 per function)
int fretdyn[16384];             // the packed element type if the function returns a dynamic array
int fretstr[16384];             // 1 if the function returns a String
int fowned[16384];           // 1 if the function returns memory it owned (return p; moves it out)
int fcharret[16384];            // 1 if the function returns a char: cout prints the result as a character
int fret[16384];              // type of the result
int fptid[131072];            // type of each parameter (8 per function)
int fself[16384];             // 1 if the function is a method with self (not static)
int farr[16384];              // 1 if the last parameter is an array (T name[])
int fcount;

int find_func(char^ name) {
    int i = 0;
    while i < fcount {
        if str_eq(@fname + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}


// the variable last found by lookup_var
int v_local;                 // 1 local, 2 local of the enclosing function (inside a #multithread body: base x26), 0 global
int mt_outer;                // while a #multithread body is compiled: how many locals belong to the enclosing function
int v_kind;
int v_elem;
int v_off;
int v_ptr;
int v_nd;
int v_cnt;
int v_dyn;
int v_tid;
int v_st1;
int v_st2;

int label_no;                // label counter
int in_cout;                 // 1 while parsing a cout operand: << and >> end it

char id_name[256];           // a copy of the identifier being parsed

// ---------------------------------------------------------------- lookups

int find_local(char^ name) {
    int i = lcount - 1;
    while i >= 0 {
        if str_eq(@lname + i * 64, name) { return i; }
        i -= 1;
    }
    return -1;
}

int find_global(char^ name) {
    int i = 0;
    while i < gcount {
        if str_eq(@gname + i * 64, name) { return i; }
        i += 1;
    }
    return -1;
}

// finds a local, else a global; sets the v_* variables
bool lookup_var(char^ name) {
    int li = find_local(name);
    if li >= 0 {
        lused[li] = 1;
        v_local = 1;
        if mt_outer > 0 && li < mt_outer { v_local = 2; }
        v_kind = lkind[li];
        v_elem = lelem[li];
        v_off = loff[li];
        v_ptr = lptr[li];
        v_nd = lnd[li];
        v_cnt = lcnt[li];
        v_tid = ltid[li];
        v_dyn = ldyn[li];
        v_st1 = lst1[li];
        v_st2 = lst2[li];
        return true;
    }
    int gi = find_global(name);
    if gi >= 0 {
        v_local = 0;
        v_kind = gkind[gi];
        v_elem = gelem[gi];
        v_off = goff[gi];
        v_ptr = gptr[gi];
        v_nd = gnd[gi];
        v_cnt = gcnt[gi];
        v_tid = gtid[gi];
        v_dyn = gdyn[gi];
        v_st1 = gst1[gi];
        v_st2 = gst2[gi];
        return true;
    }
    return false;
}

// a new local may not hide a global or repeat a name of its block (called while the token is still
// the name, so the message points at it)
void check_local_name(char^ name) {
    if name[0] == '.' { return; }
    if find_global(name) >= 0 { die_name("a local variable hides a global of the same name", name); }
    int dup = find_local(name);
    if dup >= scope_base && dup >= 0 { die_name("this name is already declared in this block", name); }
}

int luninit[8192];           // 1: a scalar declared without a value that nothing has written yet
int lunloop[8192];           // the loop depth where it was declared

// declare a local: bytes = 8 for a scalar, the (rounded) size for an array
void add_local(char^ name, int kind, int elem, int bytes, int ptr) {
    if lcount >= 8192 { die("too many local variables"); }
    check_local_name(name);
    str_copy(@lname + lcount * 64, name, 64);
    lkind[lcount] = kind;
    lelem[lcount] = elem;
    lptr[lcount] = ptr;
    lcnt[lcount] = bytes / size_of(elem);
    ltid[lcount] = ty_tid;
    ldyn[lcount] = ty_dyn;
    lblk[lcount] = cur_blk;
    luninit[lcount] = 0;
    lused[lcount] = 0;
    lalias[lcount] = 0;
    lwarn[lcount] = 0;
    if track_unused == 1 && (kind == 0 || kind == 1) && elem < 16 && name[0] != '.' {
        lwarn[lcount] = 1;
        lw_line[lcount] = decl_line;
        lw_col[lcount] = decl_col;
        lw_base[lcount] = decl_base;
        lw_ls[lcount] = decl_ls;
    }
    lnd[lcount] = 1;
    lst1[lcount] = 0;
    lst2[lcount] = 0;
    loff[lcount] = frame_bytes;
    frame_bytes += (bytes + 7) / 8 * 8;
    lcount += 1;
}

void add_global(char^ name, int kind, int elem, int bytes, int ptr) {
    if gcount >= 16384 { die("too many global variables"); }
    str_copy(@gname + gcount * 64, name, 64);
    gkind[gcount] = kind;
    gelem[gcount] = elem;
    gptr[gcount] = ptr;
    gcnt[gcount] = bytes / size_of(elem);
    gtid[gcount] = ty_tid;
    gdyn[gcount] = ty_dyn;
    gnd[gcount] = 1;
    gst1[gcount] = 0;
    gst2[gcount] = 0;
    goff[gcount] = gl_bytes;
    gl_bytes += (bytes + 7) / 8 * 8;
    gcount += 1;
}

void add_ginit(int off, int val) {
    if ginit_count >= 262144 { die("too many global initializers"); }
    ginit_off[ginit_count] = off;
    ginit_val[ginit_count] = val;
    ginit_count += 1;
}

// ------------------------------------------------------------ code helpers

int new_label() {
    label_no += 1;
    return label_no;
}

void place_label(int n) {
    emit_lab(n);
    emit_str(":\n");
}

void jump(int n) {
    emit_str("b ");
    emit_lab(n);
    emit_nl();
}

// "b.eq L12" and friends
void jump_if(char^ cond, int n) {
    emit_str("b.");
    emit_str(cond);
    emit_ch(' ');
    emit_lab(n);
    emit_nl();
}

// "text <number>"
void ins_n(char^ text, int n) {
    emit_str(text);
    emit_int(n);
    emit_nl();
}

// "ldr x0, [x29, #16]"  (op, register, base, offset)
void ins_mem(char^ op, char^ reg, char^ base, int off) {
    emit_str(op);
    emit_ch(' ');
    emit_str(reg);
    emit_str(", [");
    emit_str(base);
    emit_str(", #");
    emit_int(off);
    emit_str("]\n");
}

void push_x0() {
    emit_line("sub sp, sp, #16");
    emit_line("str x0, [sp, #0]");
}

// x1 = top of the stack, x0 unchanged ... then drop it
void pop_x1() {
    emit_line("ldr x1, [sp, #0]");
    emit_line("add sp, sp, #16");
}

// the register that a variable's offset is relative to: 1 = x29 (this function), 2 = x26 (the function
// around a #multithread loop), 0 = x28 (globals)
char^ base_of(int local) {
    if local == 1 { return "x29"; }
    if local == 2 { return "x26"; }
    return "x28";
}

char^ var_base() {
    return base_of(v_local);
}

// the address of the variable (array start / scalar slot) into x0
void addr_of_var() {
    emit_str("add x0, ");
    emit_str(var_base());
    emit_str(", #");
    emit_int(v_off);
    emit_nl();
}

// load the value of a scalar variable into x0
void load_scalar() {
    char lop[8];
    str_copy(@lop, "ldr", 8);
    if v_elem == 1 { str_copy(@lop, "ldrsb", 8); }
    if v_elem == 2 { str_copy(@lop, "ldrb", 8); }
    if v_elem == 4 { str_copy(@lop, "ldrsw", 8); }
    if v_elem == 11 { str_copy(@lop, "ldrb", 8); }
    if v_elem == 12 { str_copy(@lop, "ldrw", 8); }
    ins_mem(@lop, "x0", var_base(), v_off);
}

// bytes taken by one value of a width code: 1 i8, 2 char, 3 bool, 4 i32, 8 int
int size_of(int code) {
    if code >= 400 { return 8; }         // 400 + c : a pointer to a pointer to c
    if code >= 16 { return ssize[code - 16]; }
    if code == 8 || code == 9 || code == 7 || code == 13 { return 8; }
    if code == 6 || code == 4 || code == 12 { return 4; }
    return 1;
}

// store x0 into a scalar variable (wrapped to its width first)
void store_scalar() {
    if v_elem == 1 { emit_line("sxtb x0, x0"); }
    if v_elem == 2 { emit_line("uxtb x0, x0"); }
    if v_elem == 4 { emit_line("sxtw x0, x0"); }
    if v_elem == 11 { emit_line("uxtb x0, x0"); }
    if v_elem == 12 { emit_line("uxtw x0, x0"); }
    ins_mem("str", "x0", var_base(), v_off);
}

// x0 = the value of the given width code at the address held in x0
void load_through(int code) {
    if code == 6 { code = 4; }
    if code == 7 || code == 13 { code = 8; }
    if code == 11 { code = 2; }
    if code == 1 {
        emit_line("ldrsb x0, [x0, #0]");
    } else if code == 12 {
        emit_line("ldrw x0, [x0, #0]");
    } else if code == 4 {
        emit_line("ldrsw x0, [x0, #0]");
    } else if code == 8 {
        emit_line("ldr x0, [x0, #0]");
    } else {
        emit_line("ldrb x0, [x0, #0]");
    }
}

// x0 = the value of the given width code at the address in x3
void load_from_x3(int code) {
    if code == 6 { code = 4; }
    if code == 7 || code == 13 { code = 8; }
    if code == 11 { code = 2; }
    if code == 1 {
        emit_line("ldrsb x0, [x3, #0]");
    } else if code == 12 {
        emit_line("ldrw x0, [x3, #0]");
    } else if code == 4 {
        emit_line("ldrsw x0, [x3, #0]");
    } else if code == 8 {
        emit_line("ldr x0, [x3, #0]");
    } else {
        emit_line("ldrb x0, [x3, #0]");
    }
}

// store x1 at the address in x3 (width code)
void store_through(int code) {
    if code == 7 || code == 13 { code = 8; }
    if code == 6 || code == 12 { code = 4; }
    if code == 8 {
        emit_line("str x1, [x3, #0]");
    } else if code == 4 {
        emit_line("strw x1, [x3, #0]");
    } else {
        emit_line("strb x1, [x3, #0]");
    }
}

// the element address base + index * size: the index is in x0; leaves the
// address in x0 (an array's base is its frame/global address, a pointer
// variable's base is its value)
void element_address() {
    ins_n("mov x1, ", size_of(v_elem));
    emit_line("mul x0, x0, x1");
    if v_kind == 1 {
        emit_str("add x1, ");
        emit_str(var_base());
        emit_str(", #");
        emit_int(v_off);
        emit_nl();
    } else {
        ins_mem("ldr", "x1", var_base(), v_off);
    }
    emit_line("add x0, x0, x1");
}

// the width an operation on two operands is done in: a plain number takes the
// other side's width, otherwise the wider one
int res_w(int a, int b) {
    int r = a;
    if a == 0 { r = b; }
    else if b != 0 && size_of(b) > size_of(a) { r = b; }
    if r == 2 || r == 3 || r == 9 { r = 8; }      // char / bool / text arithmetic is int arithmetic
    return r;
}

// wrap x0 to a signed small width (i8, i32) and remember it as the result width
void wrap_result(int w) {
    // arithmetic is done at full register width (like C: i8 + i8 is an int);
    // the value is cut to its width only when it is stored or cast
    ex_w = 8;
}

// the token is "[" : parses [i], [i][j] or [i][j][k] and leaves the element
// number (counted from the start of the array) in x0
int chk_cnt;                 // for the next index chain: elements of the array (0 = unknown)
int chk_len_off;             // ... or: the frame/global offset of the hidden length (-1 = none)
int chk_len_local;

// -d : x0 = the index; stop with a message if it is not below `size`
// (size is a constant, or in x2 already when size < 0)
void emit_bounds(int size) {
    if opt_debug == 0 { return; }
    if size == 0 { return; }
    int lok = new_label();
    if size > 0 { ins_n("mov x2, ", size); }
    emit_line("cmp x0, x2");
    jump_if("lo", lok);
    emit_line("mov x1, x2");
    emit_line("bl j2k_oob");
    place_label(lok);
    used_oob = 1;
}

// the check of one index: dimension number k of nd, with the size from the plan above
void check_index(int k, int nd, int cnt, int st1, int st2, int len_off, int len_local) {
    if opt_debug == 0 { return; }
    if len_off >= 0 {
        ins_mem("ldr", "x2", base_of(len_local), len_off);
        emit_bounds(0 - 1);
        return;
    }
    if cnt <= 0 { return; }
    int size = cnt;
    if nd == 2 && k == 0 { size = cnt / st1; }
    if nd == 2 && k == 1 { size = st1; }
    if nd == 3 && k == 0 { size = cnt / st1; }
    if nd == 3 && k == 1 { size = st1 / st2; }
    if nd == 3 && k == 2 { size = st2; }
    emit_bounds(size);
}

void parse_index_chain() {
    int nd = v_nd;
    int st1 = v_st1;
    int st2 = v_st2;
    int cnt = chk_cnt;
    int len_off = chk_len_off;
    int len_local = chk_len_local;
    chk_cnt = 0;
    chk_len_off = 0 - 1;
    next();
    parse_expr();
    expect("]");
    check_index(0, nd, cnt, st1, st2, len_off, len_local);
    if nd > 1 {
        ins_n("mov x1, ", st1);
        emit_line("mul x0, x0, x1");
        push_x0();
        if !tok_is("[") { die("this array needs more indexes"); }
        next();
        parse_expr();
        expect("]");
        check_index(1, nd, cnt, st1, st2, len_off, len_local);
        if nd == 3 {
            ins_n("mov x1, ", st2);
            emit_line("mul x0, x0, x1");
        }
        pop_x1();
        emit_line("add x0, x0, x1");
        if nd == 3 {
            push_x0();
            if !tok_is("[") { die("this array needs more indexes"); }
            next();
            parse_expr();
            expect("]");
            check_index(2, nd, cnt, st1, st2, len_off, len_local);
            pop_x1();
            emit_line("add x0, x0, x1");
        }
    }
    v_nd = nd;
    v_st1 = st1;
    v_st2 = st2;
}

// ------------------------------------------------------------ string literals

// the text of a string literal goes into the global area (stored at
// startup); the expression is its address
// the text (len characters) goes into the global block; x0 = its address
void place_text(char^ text, int len) {
    int off = (gl_bytes + 7) / 8 * 8;
    int size = (len + 8) / 8 * 8;
    gl_bytes = off + size;
    int k = 0;
    while k < size {
        int chunk = 0;
        int b = 7;
        while b >= 0 {
            chunk = chunk * 256;
            if k + b < len { chunk = chunk + text[k + b]; }
            b -= 1;
        }
        if chunk != 0 { add_ginit(off + k, chunk); }
        k += 8;
    }
    emit_line("mov x0, x28");
    ins_n("add x0, x0, #", off);
}

void gen_string() {
    place_text(@tok_str, tok_str_len);
    next();
}

// ------------------------------------------------------------------- calls

// arguments are evaluated in order and pushed; then popped into x0..x{n-1}
int call_fi = -1;             // function of the call being parsed (-1 = unknown)
int call_sig = -1;             // signature of the indirect call being parsed (-1 = none)
int call_skip;               // leading parameters not written in the call (self)
int arr_call_at = -1;           // index of the array argument of the call being parsed (-1 = none)

// an argument for an array parameter: a string or an array name; pushes its
// address and its length
void parse_array_arg() {
    if tok_kind == T_STR {
        int sl = tok_str_len + 1;
        gen_string();
        push_x0();
        ins_n("mov x0, ", sl);
        push_x0();
        return;
    }
    if tok_kind != T_IDENT { die("an array was expected for this parameter"); }
    char aa_name[256];
    str_copy(@aa_name, @tok_text, 256);
    next();
    if !lookup_var(@aa_name) { die_name("unknown name", @aa_name); }
    if v_kind != 1 { die_name("not an array", @aa_name); }
    addr_of_var();
    push_x0();
    ins_n("mov x0, ", v_cnt);
    push_x0();
}

int parse_args() {
    int n = 0;
    int ai = arr_call_at;
    arr_call_at = 0 - 1;
    int pfi = call_fi;
    int pskip = call_skip;
    int psig = call_sig;
    call_sig = 0 - 1;
    call_fi = 0 - 1;
    call_skip = 0;
    int argno = 0;
    if tok_is(")") {
        next();
        return 0;
    }
    while true {
        if argno == ai {
            parse_array_arg();
            n += 2;
        } else {
            parse_expr();
            if pfi >= 0 && argno + pskip < 8 && fpstr[pfi * 8 + argno + pskip] == 1 && ex_ty != 80 && ex_w == 9 {
                rt_call("__Str__from");      // a text for a String parameter: a temporary String is made
                str_temp();
            }
            if pfi >= 0 && argno + pskip < fnpar[pfi] && argno + pskip < 8 { check_assign(fptid[pfi * 8 + argno + pskip]); }
            if psig >= 0 && argno < sig_n[psig] { check_assign(sig_p[psig * 16 + argno]); }
            if pfi >= 0 && argno + pskip < 8 && fptid[pfi * 8 + argno + pskip] >= 100 && ex_ty >= 100 && struct_has_free(ex_ty - 100) {
                // a value that frees itself is moved into the call: a fresh value goes as it is, a local variable is
                // copied to a temporary and emptied now (so that a throw in the call cannot free it twice)
                int how = struct_source(ex_ty - 100);
                if how == 2 {
                    int src_off = own_src_off;
                    int ssz = ssize[ex_ty - 100];
                    ty_tid = 0;
                    add_local("..moved", 0, 16 + ex_ty - 100, ssz, 0);
                    int tmp_at = loff[lcount - 1];
                    ins_n("add x3, x29, #", tmp_at);
                    ins_n("mov x2, ", ssz);
                    emit_line("bl j2k_copy");
                    emit_zero_local(src_off, ssz);
                    int oi2 = own_find(src_off);
                    if oi2 >= 0 && own_blk[oi2] == cur_blk { own_moved[oi2] = 1; }
                    ins_n("add x0, x29, #", tmp_at);
                }
            }
            push_x0();
            n += 1;
        }
        argno += 1;
        if n > 16 { die("too many arguments (16 at most)"); }
        if tok_is(",") {
            next();
        } else {
            break;
        }
    }
    expect(")");
    return n;
}

// loads the pushed arguments into x0..x7. With 8 or fewer the stack slots are given back here;
// with more, the slots stay (the callee reads arguments 9.. from them, on the stack of its own
// thread) and the caller drops them after the call (see drop_args).
void pop_args(int n) {
    int i = n - 1;
    int slot = 0;
    while i >= 0 {
        if i < 8 {
            emit_str("ldr x");
            emit_int(i);
            emit_str(", [sp, #");
            emit_int(slot * 16);
            emit_str("]\n");
        }
        slot += 1;
        i -= 1;
    }
    if n > 0 && n <= 8 {
        emit_str("add sp, sp, #");
        emit_int(n * 16);
        emit_nl();
    }
}

// after the call: give the argument slots back when there were more than 8
void drop_args(int n) {
    if n > 8 { ins_n("add sp, sp, #", n * 16); }
}

// a plain call name that is not a function of its own may be a static method of
// a struct made visible by "using": id_name becomes Struct__name
void resolve_callee() {
    if find_func(@id_name) >= 0 { return; }
    if gen_is_template(@id_name) {
        gen_infer_call();                // a generic called without <...>: T comes from the arguments
        return;
    }
    if str_eq(@id_name, "syscall") || str_eq(@id_name, "argc") || str_eq(@id_name, "arg") { return; }
    int k = 0;
    int found = 0 - 1;
    while k < scount {
        if us_g[k] == 1 || us_l[k] == 1 {
            char rc_full[256];
            str_copy(@rc_full, @sname + k * 64, 64);
            str_copy(@rc_full + str_len(@rc_full), "__", 4);
            str_copy(@rc_full + str_len(@rc_full), @id_name, 100);
            if find_func(@rc_full) >= 0 {
                if found >= 0 && pass_no >= 2 {
                    char amb[200];
                    str_copy(@amb, "the name is in several modules that are in use (", 200);
                    append_text(@amb, @sname + found * 64);
                    append_text(@amb, " and ");
                    append_text(@amb, @sname + k * 64);
                    append_text(@amb, "): write Module::name");
                    die_name(@amb, @id_name);
                }
                if found < 0 { found = k; }
            }
        }
        k += 1;
    }
    if found >= 0 {
        char rc_one[256];
        str_copy(@rc_one, @sname + found * 64, 64);
        str_copy(@rc_one + str_len(@rc_one), "__", 4);
        str_copy(@rc_one + str_len(@rc_one), @id_name, 100);
        str_copy(@id_name, @rc_one, 256);
    }
}

// ---------------------------------------------- owners
// is block `a` a strict ancestor of block `b` (an enclosing block)?
bool blk_encloses(int a, int b) {
    int x = blk_parent[b];
    while true {
        if x == a { return true; }
        if x == 0 { return false; }
        x = blk_parent[x];
    }
    return false;
}

// the local variable at frame offset off: the block it was declared in (-1 = unknown)
int local_blk(int off) {
    int i = lcount - 1;
    while i >= 0 {
        if loff[i] == off { return lblk[i]; }
        i -= 1;
    }
    return 0 - 1;
}

int own_find(int off) {
    int i = own_count - 1;
    while i >= 0 {
        if own_off[i] == off { return i; }
        i -= 1;
    }
    return -1;
}

// An owner is also entered in the cleanup chain of the thread (the head is at [x27 + 784]): a record of
// 4 words in the frame [next, address of the slot, routine, mode]. When a throw leaves the function the
// chain is walked and everything that was not freed yet is freed (mode 0: the routine gets the value in the
// slot, mode 1: it gets the address of the slot, a struct with free(self)). Leaving a block takes the
// records out again (own_unlink).
void own_add(int off, int kind, int aux) {
    if own_count >= 256 { die("too many owning variables in one function"); }
    if kind != 2 && kind != 6 && kind != 7 && kind != 9 { str_flush(stmt_t0, 1); }       // Strings made by this statement go first: the records must be in order
    own_off[own_count] = off;
    own_kind[own_count] = kind;
    own_aux[own_count] = aux;
    own_blk[own_count] = cur_blk;
    own_moved[own_count] = 0;
    own_rec[own_count] = frame_bytes;
    frame_bytes += 32;
    char fn[128];
    int mode = 0;
    if kind == 5 {
        mode = 2;                            // a deferred statement: aux is the label of its code, off is not used
    } else if kind == 0 {
        str_copy(@fn, "Mem__free", 128);
    } else if kind == 3 || kind == 9 {
        str_copy(@fn, "__Str__free_all", 128);
    } else if kind == 4 || kind == 6 {
        str_copy(@fn, @sname + aux * 64, 64);
        append_text(@fn, "__free");
        mode = 1;
    } else {
        str_copy(@fn, "__Arr__free", 128);
    }
    if kind != 5 { note_call(@fn); }
    ins_n("add x1, x29, #", own_rec[own_count]);
    emit_line("ldr x2, [x27, #784]");
    emit_line("str x2, [x1, #0]");
    if kind == 5 {
        emit_line("str x29, [x1, #8]");      // the frame the code works on
        emit_str("adr x2, ");
        emit_lab(aux);
        emit_nl();
    } else {
        ins_n("add x2, x29, #", off);
        emit_line("str x2, [x1, #8]");
        emit_str("adr x2, ");
        emit_line(@fn);
    }
    emit_line("str x2, [x1, #16]");
    ins_n("mov x2, ", mode);
    emit_line("str x2, [x1, #24]");
    emit_line("str x1, [x27, #784]");
    own_count += 1;
}

// the cleanup chain goes back to what it was before owner `from` (and the ones after it) were entered
void own_unlink(int from) {
    ins_mem("ldr", "x1", "x29", own_rec[from]);
    emit_line("str x1, [x27, #784]");
}

void emit_owner_free(int i) {
    if own_kind[i] == 5 {
        emit_str("bl ");                     // a deferred statement runs now
        emit_lab(own_aux[i]);
        emit_nl();
        return;
    }
    if own_kind[i] == 4 || own_kind[i] == 6 {
        // a struct variable with a free(self) method: the compiler calls it
        char sf[128];
        str_copy(@sf, @sname + own_aux[i] * 64, 64);
        append_text(@sf, "__free");
        ins_n("add x0, x29, #", own_off[i]);
        rt_call(@sf);
        return;
    }
    ins_mem("ldr", "x0", "x29", own_off[i]);
    if own_kind[i] == 3 || own_kind[i] == 9 {
        rt_call("__Str__free_all");
    } else if own_kind[i] >= 1 {
        rt_call("__Arr__free");
    } else {
        rt_call("Mem__free");
    }
}

// the variable no longer owns anything (it is null)
void emit_owner_null(int i) {
    emit_line("mov x1, 0");
    ins_mem("str", "x1", "x29", own_off[i]);
}

// free the owners with index >= from (innermost first); with pop the list shrinks
void own_free_from(int from, int pop) {
    int i = own_count - 1;
    if from < own_count {
        while i >= from {
            emit_owner_free(i);
            i -= 1;
        }
        own_unlink(from);
    }
    if pop == 1 { own_count = from; }
}

// ---------------------------------------------- which functions are used
// Pass 2 records every call (from function cur_fidx, -1 = outside any function);
// pass 3 leaves out the functions that main cannot reach (most of std).
int cur_fidx = -1;
int edge_from[262144];
char edge_to[16777216];       // 65536 x 64
int edge_count;
int freach[16384];

void note_call(char^ name) {
    if pass_no != 2 { return; }
    if edge_count > 0 && edge_from[edge_count - 1] == cur_fidx && str_eq(@edge_to + (edge_count - 1) * 64, name) { return; }
    if edge_count >= 262144 { die("too many calls in this program"); }
    edge_from[edge_count] = cur_fidx;
    str_copy(@edge_to + edge_count * 64, name, 64);
    edge_count += 1;
}

// freach[f] = 1 for main and everything it (and the global initializers) can call
void compute_reach() {
    int k = 0;
    while k < fcount {
        freach[k] = 0;
        k += 1;
    }
    int m = find_func("main");
    if m >= 0 { freach[m] = 1; }
    bool changed = true;
    while changed {
        changed = false;
        int j = 0;
        while j < edge_count {
            int to = find_func(@edge_to + j * 64);
            if to >= 0 && freach[to] == 0 && (edge_from[j] < 0 || freach[edge_from[j]] == 1) {
                freach[to] = 1;
                changed = true;
            }
            j += 1;
        }
    }
}

int call_bare;               // 1: the next gen_call is a call without ( ) (a data enum member)
int bare_call;
int call_pre;                // arguments already pushed (self of a method call)
int call_method;             // 1 for a method call: arguments are counted after self

// a call: the (mangled) name is in id_name and the token is the "(" after it
void gen_call() {
    char callee[256];
    str_copy(@callee, @id_name, 256);
    note_call(@callee);
    int pre = call_pre;
    call_pre = 0;
    int is_method = call_method;
    call_method = 0;
    if call_bare == 1 {
        call_bare = 0;                   // a member of a data enum written without ( )
        bare_call = 1;
    } else {
        expect("(");
    }
    int fi = find_func(@callee);
    if fi < 0 && pass_no >= 2 && !(callee[0] == '_' && callee[1] == '_') && !str_eq(@callee, "syscall") && !str_eq(@callee, "argc") && !str_eq(@callee, "arg") { die_name("unknown function", @callee); }
    int res_ty = 0;
    int tmp_off = 0;
    if fi >= 0 { res_ty = fret[fi]; }
    if str_eq(@callee, "__fsqrt") || str_eq(@callee, "__ffloor") || str_eq(@callee, "__fceil") || str_eq(@callee, "__ftrunc") { res_ty = 91; }
    int is_atomic = 0;
    if str_eq(@callee, "__cas") || str_eq(@callee, "__xchg") || str_eq(@callee, "__fetch_add") { is_atomic = 1; }
    if fi >= 0 && farr[fi] == 1 { arr_call_at = fnpar[fi] - 1 - is_method; }
    last_call_struct = 0;
    if res_ty >= 100 {
        // a struct result: a temporary in this frame, its address goes first
        ty_tid = 0;
        add_local("..result", 0, 16 + res_ty - 100, ssize[res_ty - 100], 0);
        tmp_off = loff[lcount - 1];
        ins_n("add x0, x29, #", tmp_off);
        push_x0();
        if pre > 0 {
            // a method: the callee wants (result address, self): swap the two stack slots
            emit_line("ldr x1, [sp, #16]");
            emit_line("ldr x2, [sp, #0]");
            emit_line("str x2, [sp, #16]");
            emit_line("str x1, [sp, #0]");
        }
        pre += 1;
    }
    call_fi = fi;
    call_skip = is_method;
    int n = pre;
    if bare_call == 1 {
        bare_call = 0;
    } else {
        n = parse_args() + pre;
    }
    int free_owner = 0 - 1;
    if str_eq(@callee, "Mem__free") && n == 1 && rv_valid == 1 { free_owner = own_find(rv_off); }
    pop_args(n);
    if str_eq(@callee, "syscall") {
        if n < 1 || n > 7 { die("syscall takes 1 to 7 arguments"); }
        emit_line("mov x8, x0");
        int i = 1;
        while i < n {
            emit_str("mov x");
            emit_int(i - 1);
            emit_str(", x");
            emit_int(i);
            emit_nl();
            i += 1;
        }
        emit_line("svc 0");
    } else if str_eq(@callee, "__fsqrt") || str_eq(@callee, "__ffloor") || str_eq(@callee, "__fceil") || str_eq(@callee, "__ftrunc") {
        // one f64 in x0 -> one f64 in x0 (the CPU's own instruction)
        if n != 1 { die("this function takes one argument"); }
        emit_line("fmov d0, x0");
        if str_eq(@callee, "__fsqrt") { emit_line("fsqrt d0, d0"); }
        if str_eq(@callee, "__ffloor") { emit_line("frintm d0, d0"); }
        if str_eq(@callee, "__fceil") { emit_line("frintp d0, d0"); }
        if str_eq(@callee, "__ftrunc") { emit_line("frintz d0, d0"); }
        emit_line("fmov x0, d0");
    } else if is_atomic == 1 {
        // atomic operations on an 8-byte word at the address in x0 (x1, x2 = the other arguments);
        // the result is the value the word had before. Built from load-exclusive / store-exclusive.
        int la = new_label();
        int lb = new_label();
        place_label(la);
        emit_line("ldaxr x3, [x0]");
        if str_eq(@callee, "__cas") {
            if n != 3 { die("__cas(address, old, new) takes three arguments"); }
            emit_line("cmp x3, x1");
            jump_if("ne", lb);
            emit_line("stlxr w4, x2, [x0]");
        } else if str_eq(@callee, "__xchg") {
            if n != 2 { die("__xchg(address, value) takes two arguments"); }
            emit_line("stlxr w4, x1, [x0]");
        } else {
            if n != 2 { die("__fetch_add(address, value) takes two arguments"); }
            emit_line("add x5, x3, x1");
            emit_line("stlxr w4, x5, [x0]");
        }
        emit_line("cmp x4, 0");
        jump_if("ne", la);
        place_label(lb);
        emit_line("dmb ish");
        emit_line("mov x0, x3");
    } else if str_eq(@callee, "__thread_start") {
        // (function, argument, top of the new stack, address of the thread's id word, its thread block)
        if n != 5 { die("__thread_start takes five arguments"); }
        used_thread = 1;
        emit_line("bl j2k_thread_start");
    } else if str_eq(@callee, "__fp") {
        emit_line("mov x0, x29");                 // this function's frame: [x0] = the caller's frame, [x0 + 8] = the return address
    } else if str_eq(@callee, "__fntab") {
        used_fntab = 1;
        emit_line("adr x0, j2k_fntab");           // pairs (function address, name) ended by a 0
    } else if str_eq(@callee, "argc") {
        emit_line("ldr x9, [x28, #0]");
        emit_line("ldr x0, [x9, #0]");
    } else if str_eq(@callee, "arg") {
        emit_line("mov x1, 8");
        emit_line("mul x0, x0, x1");
        emit_line("ldr x9, [x28, #0]");
        emit_line("add x9, x9, x0");
        emit_line("ldr x0, [x9, #8]");
    } else {
        emit_str("bl ");
        emit_line(@callee);
        drop_args(n);
        if tmp_off != 0 { ins_n("add x0, x29, #", tmp_off); }
    }
    if free_owner >= 0 { emit_owner_null(free_owner); }       // Mem::free(p) on an owner: p is null afterwards
    ex_w = 8;
    if fi >= 0 && fcharret[fi] == 1 { ex_w = 2; }
    if fi >= 0 && fcharret[fi] == 2 { ex_w = 9; }
    ex_ty = res_ty;
    last_call_owning = 0;
    if str_eq(@callee, "Mem__alloc") { last_call_owning = 1; }
    if fi >= 0 && fowned[fi] == 1 { last_call_owning = 1; }
    rv_valid = 0;
    if fi >= 0 && fretdyn[fi] != 0 { ex_dyn = fretdyn[fi]; }
    if res_ty >= 100 {
        last_call_struct = 1;
        last_call_struct_off = tmp_off;
        if struct_has_free(res_ty - 100) && cur_fidx >= 0 {
            // the result frees itself: the temporary is an owner until the end of the statement unless it is moved on
            if cond_depth > 0 { die("a value that frees itself cannot be made on the right of && or || (put it in a variable first)"); }
            own_add(tmp_off, 6, res_ty - 100);
        }
    }
    if fi >= 0 && fretstr[fi] == 1 {
        last_call_owning = 0;            // a String that is returned is a temporary that the compiler frees
        str_temp();
    }
}

// the type of what a pointer to `code` points at
int pointee_tid(int code) {
    if code >= 400 { return 0; }
    if code == 11 { return 93; }
    if code == 12 { return 94; }
    if code == 13 { return 95; }
    if code == 3 { return 1; }
    if code == 6 { return 90; }
    if code == 7 { return 91; }
    if code >= 16 { return 100 + code - 16; }
    return 0;
}

// the object found by parse_lvalue (its address is in x0)
int lv_code;                 // width code of the object (16+n for a struct n)
int lv_kind;                 // 1 if it is a whole array
int lv_ptr;                  // pointee code if the object is a pointer variable
int lv_tid;
int lv_nd;
int lv_st1;
int lv_st2;
int lv_cnt;
int lv_dyn;
int lv_base_off;             // frame offset / local-ness of the variable the chain began with
int lv_base_local;
int lv_self;                 // the variable is `self`
char lv_base[256];           // the variable the chain started from
int lv_fresh;                // 1 while no [ ] ^ . has been followed yet
int lv_serial;               // counts the l-value chains parsed (sizeof uses it)
int lv_done;                 // 1: a method call ended the chain, its result is in x0

// is the "." that is the current token followed by the word len, on an array?
// (looks one token ahead by reading the source text)
bool lv_len_next() {
    if lc(0) != 'l' || lc(1) != 'e' || lc(2) != 'n' { return false; }
    if is_alnum(lc(3)) { return false; }
    if lv_kind == 1 { return true; }
    return lv_fresh == 1 && lv_kind == 0 && lv_ptr != 0 && lv_ptr < 16 && lv_code < 16;
}

// the variable id_name was found (v_*): x0 = its address, then follow
// [index], ^, .field and .method(...)
void parse_lvalue() {
    lv_done = 0;
    lv_self = 0;
    lv_fresh = 1;
    lv_serial += 1;
    str_copy(@lv_base, @id_name, 256);
    if str_eq(@id_name, "self") { lv_self = 1; }
    int ali = find_local(@id_name);
    if ali >= 0 && lalias[ali] == 1 { lv_self = 1; }
    addr_of_var();
    lv_code = v_elem;
    lv_kind = v_kind;
    lv_ptr = v_ptr;
    lv_tid = v_tid;
    lv_nd = v_nd;
    lv_st1 = v_st1;
    lv_st2 = v_st2;
    lv_cnt = v_cnt;
    lv_dyn = v_dyn;
    lv_base_off = v_off;
    lv_base_local = v_local;
    lvalue_loop();
}

// the object whose address is in x0 is described by lv_*: follow [index], ^, .field, .method(...)
void lvalue_loop() {
    while true {
        if lv_kind == 3 && tok_is("[") {
            dyn_index();
        } else if lv_kind == 3 && tok_is(".") {
            dyn_member();
            if lv_done == 1 { return; }
        } else if tok_is("[") {
            int s_code = lv_code;
            int s_ptr = lv_ptr;
            int s_tid = lv_tid;
            int s_self = lv_self;
            int s_isarr = lv_kind;
            v_nd = lv_nd;
            v_st1 = lv_st1;
            v_st2 = lv_st2;
            chk_cnt = 0;
            chk_len_off = 0 - 1;
            if s_isarr == 1 { chk_cnt = lv_cnt; }
            if s_isarr == 0 && lv_fresh == 1 && opt_debug == 1 {
                // an array parameter: its hidden length is the limit
                char lim_name[300];
                str_copy(@lim_name, @lv_base, 256);
                str_copy(@lim_name + str_len(@lim_name), "__len", 8);
                int saved_off = v_off;
                int saved_loc = v_local;
                if lookup_var(@lim_name) {
                    chk_len_off = v_off;
                    chk_len_local = v_local;
                }
                v_off = saved_off;
                v_local = saved_loc;
            }
            if s_isarr == 0 {
                if s_ptr == 0 { die("this is neither an array nor a pointer"); }
                if s_ptr == 10 { die("a void^ cannot be indexed (cast it to a typed pointer first)"); }
                v_nd = 1;
                load_through(8);             // x0 = the pointer's value
                s_code = s_ptr;
                s_tid = pointee_tid(s_ptr);
                s_ptr = 0;
            }
            push_x0();                       // the base address
            parse_index_chain();
            ins_n("mov x1, ", size_of(s_code));
            emit_line("mul x0, x0, x1");
            pop_x1();
            emit_line("add x0, x0, x1");
            if s_code >= 400 {
                // an element that is itself a pointer (T^^ p; p[i])
                s_ptr = s_code - 400;
                s_code = 8;
                s_tid = 0;
            }
            lv_fresh = 0;
            lv_code = s_code;
            lv_ptr = s_ptr;
            lv_tid = s_tid;
            lv_self = s_self;
            lv_kind = 0;
            lv_nd = 1;
        } else if tok_is("^") {
            if lv_ptr == 0 || lv_kind == 1 { die("not a pointer"); }
            if lv_ptr == 10 { die("a void^ cannot be dereferenced (cast it to a typed pointer first)"); }
            next();
            lv_fresh = 0;
            load_through(8);
            lv_code = lv_ptr;
            lv_tid = pointee_tid(lv_ptr);
            lv_ptr = 0;
            if lv_code >= 400 {
                // p^ is itself a pointer (T^^ p)
                lv_ptr = lv_code - 400;
                lv_code = 8;
                lv_tid = 0;
            }
            lv_self = 0;
        } else if tok_is(".") && lv_len_next() {
            // name.len : the number of elements of an array (or array parameter)
            next();                          // "."
            next();                          // "len"
            if lv_kind == 1 {
                int first_dim = lv_cnt;
                if lv_nd > 1 { first_dim = lv_cnt / lv_st1; }
                ins_n("mov x0, ", first_dim);
            } else {
                char ln_name[300];
                str_copy(@ln_name, @lv_base, 256);
                str_copy(@ln_name + str_len(@ln_name), "__len", 8);
                if !lookup_var(@ln_name) { die("len is only for arrays"); }
                load_scalar();
            }
            ex_w = 8;
            ex_ty = 0;
            lv_done = 1;
            return;
        } else if tok_is(".") {
            if lv_kind == 0 && lv_code < 16 && lv_ptr >= 16 && lv_self == 1 {
                load_through(8);             // self is a pointer: self.x works directly
                lv_code = lv_ptr;
                lv_ptr = 0;
            }
            if lv_code < 16 || lv_kind == 1 { die("this value has no fields"); }
            next();
            if tok_kind != T_IDENT { die("a field or method name was expected"); }
            int st = lv_code - 16;
            char m_name[256];
            str_copy(@m_name, @tok_text, 256);
            next();
            int fld_try = find_field(st, @m_name);
            if tok_is("(") && !(fld_try >= 0 && fldtid[fld_try] < 0) {
                // a method call: x0 = the object's address is `self`
                push_x0();
                char m_full[256];
                str_copy(@m_full, @sname + st * 64, 64);
                str_copy(@m_full + str_len(@m_full), "__", 4);
                str_copy(@m_full + str_len(@m_full), @m_name, 100);
                if find_func(@m_full) < 0 && pass_no >= 2 { die_name("the struct has no such method", @m_name); }
                if pass_no >= 2 && fself[find_func(@m_full)] == 0 { die_name("this function is static: call it as Struct::name(...)", @m_name); }
                str_copy(@id_name, @m_full, 256);
                if lv_fresh == 1 && lv_base_local == 1 {
                    int mvi = own_find(lv_base_off);
                    if mvi >= 0 && own_moved[mvi] == 1 { warn("this variable was moved and is used afterwards (it is empty now)", "moved"); }
                }
                call_pre = 1;
                call_method = 1;
                gen_call();
                if ex_ty >= 100 && (tok_is(".") || tok_is("[")) {
                    // obj.method().field : the result struct (a temporary) is the new object
                    lv_code = 16 + ex_ty - 100;
                    lv_kind = 0;
                    lv_ptr = 0;
                    lv_tid = ex_ty;
                    lv_self = 0;
                    lv_fresh = 0;
                    continue;
                }
                lv_done = 1;
                return;
            }
            int fi = find_field(st, @m_name);
            if fi < 0 { die_name("the struct has no such field", @m_name); }
            if fldoff[fi] != 0 { ins_n("add x0, x0, #", fldoff[fi]); }
            lv_code = fldcode[fi];
            lv_kind = fldkind[fi];
            lv_ptr = fldptr[fi];
            lv_tid = fldtid[fi];
            lv_nd = fldnd[fi];
            lv_st1 = fldst1[fi];
            lv_st2 = fldst2[fi];
            lv_cnt = fldcnt[fi];
            lv_dyn = flddyn[fi];
            lv_self = 0;
            lv_fresh = 0;
        } else {
            break;
        }
    }
}

// Struct::function(args) or Enum::Member: the name is in id_name, the token is "::"
void gen_scope() {
    int en = find_enum(@id_name);
    int sd = find_struct(@id_name);
    if en < 0 && sd < 0 { die_name("unknown name", @id_name); }
    next();
    if tok_kind != T_IDENT { die("a name was expected after ::"); }
    if en >= 0 {
        if !find_member(en, @tok_text) { die_name("not a member of the enum", @tok_text); }
        ins_n("mov x0, ", found_val);
        ex_w = 8;
        ex_ty = 3 + en;
        next();
        return;
    }
    char sc_full[256];
    str_copy(@sc_full, @id_name, 64);
    str_copy(@sc_full + str_len(@sc_full), "__", 4);
    str_copy(@sc_full + str_len(@sc_full), @tok_text, 100);
    if find_func(@sc_full) < 0 && pass_no >= 2 { die_name("the struct has no such function", @tok_text); }
    if pass_no >= 2 && fself[find_func(@sc_full)] == 1 { die_name("this method needs an object: call it as object.name(...)", @tok_text); }
    next();
    if !tok_is("(") && gen_bare_variant(@id_name, @sc_full) {
        // Shape::Empty : a member of a data enum without parameters is a call without ( )
        str_copy(@id_name, @sc_full, 256);
        call_bare = 1;
        gen_call();
        return;
    }
    if !tok_is("(") {
        // Struct::function without a call: its address
        int sfv = find_func(@sc_full);
        if sfv < 0 { emit_line("mov x0, 0"); ex_ty = 97; ex_w = 8; return; }
        gen_function_value(sfv, @sc_full);
        return;
    }
    str_copy(@id_name, @sc_full, 256);
    gen_call();
    call_postfix();
}

// after a call: f(...)(...) , f().field , f().method() , f()[i] , and a String result with a method (f().trim())
void call_postfix() {
    int again = 1;
    int guard = 0;
    while again == 1 && guard < 8 {
    guard += 1;
    again = 0;
    while ex_ty < 0 && tok_is("(") {
        gen_call_indirect(ex_ty);            // f(...)(...) : call the pointer that f returned
    }
    if ex_ty >= 100 && (tok_is(".") || tok_is("[")) {
        // f().field : the returned struct (a temporary) is the object
        lv_done = 0;
        lv_self = 0;
        lv_fresh = 0;
        lv_code = 16 + ex_ty - 100;
        lv_kind = 0;
        lv_ptr = 0;
        lv_tid = ex_ty;
        lvalue_loop();
        finish_rvalue();
    } else if ex_ty == 99 && tok_is(".") && ex_dyn != 0 {
        // f().len : the array that f returned is a temporary kept in a frame slot until the end of the statement
        int tk = 7;
        if is_strarr_dyn(ex_dyn) { tk = 9; }
        if cond_depth > 0 { die("a new array cannot be made on the right of && or ||"); }
        ty_tid = 0;
        add_local(".t", 0, 8, 8, 0);
        int toff = loff[lcount - 1];
        ins_mem("str", "x0", "x29", toff);
        own_add(toff, tk, 0);
        last_call_owning = 0;
        lv_done = 0;
        lv_self = 0;
        lv_fresh = 0;
        ins_n("add x0, x29, #", toff);
        lv_code = 8;
        lv_kind = 3;
        lv_ptr = 0;
        lv_tid = 99;
        lv_dyn = ex_dyn;
        lv_nd = 1;
        lvalue_loop();
        finish_rvalue();
    } else if ex_ty == 80 && tok_is(".") && rv_valid == 1 {
        // f().trim() : the String that f returned is a temporary kept in a frame slot: it is the String variable
        lv_done = 0;
        lv_self = 0;
        lv_fresh = 0;
        ins_n("add x0, x29, #", rv_off);
        lv_code = 8;
        lv_kind = 3;
        lv_ptr = 0;
        lv_tid = 99;
        lv_dyn = dyn_pack(2, 0, 70);
        lv_nd = 1;
        lvalue_loop();
        finish_rvalue();
    }
    if (ex_ty == 80 || ex_ty == 99 || ex_ty >= 100) && tok_is(".") && lv_done == 1 { again = 1; }
    }
}

// an identifier in an expression: a variable, an element, a deref or a call
void gen_identifier() {
    str_copy(@id_name, @tok_text, 256);
    next();
    if tok_is("(") && str_eq(@id_name, "move") && !lookup_var(@id_name) && find_func(@id_name) < 0 {
        // move(p) : p gives its memory away (the value is used, p becomes null)
        next();
        parse_expr();
        expect(")");
        int mi = 0 - 1;
        if rv_valid == 1 { mi = own_find(rv_off); }
        if mi < 0 && pass_no >= 2 { die("move(...) needs a local variable that owns memory (made by alloc or arr)"); }
        if mi >= 0 {
            emit_owner_null(mi);
            if own_blk[mi] == cur_blk { own_moved[mi] = 1; }
        }
        rv_valid = 0;
        return;
    }
    if tok_is("(") && str_eq(@id_name, "__hash") && !lookup_var(@id_name) {
        // __hash(x) : a number for a key of a Map / Set (a whole number, a pointer, a float or a String)
        next();
        parse_expr();
        expect(")");
        if ex_ty == 80 {
            rt_call("__Str__hash");
        } else {
            rt_call("__Str__hashint");
        }
        ex_w = 8;
        ex_ty = 0;
        rv_valid = 0;
        return;
    }
    if tok_is("(") && str_eq(@id_name, "arr") && !lookup_var(@id_name) && find_func(@id_name) < 0 {
        // arr(n) : a new dynamic array with room for n elements
        next();
        int esz = arr_esize;
        arr_esize = 0;
        if esz == 0 && pass_no >= 2 { die("arr(...) needs to know its element type: write  T[] x = arr(n);"); }
        parse_expr();
        expect(")");
        bin_type(0, ex_ty);
        emit_line("mov x1, x0");
        ins_n("mov x0, ", esz);
        rt_call("__Arr__make");
        ex_w = 8;
        ex_ty = 99;
        last_call_owning = 1;
        rv_valid = 0;
        return;
    }
    if tok_is("(") && !(lookup_var(@id_name) && v_tid < 0 && v_kind != 2) {
        resolve_callee();
        gen_call();
        call_postfix();
        return;
    }
    if tok_is("::") {
        gen_scope();
        return;
    }
    if !lookup_var(@id_name) {
        if find_using_member(@id_name) {
            ins_n("mov x0, ", found_val);
            ex_w = 8;
            return;
        }
        // a function name used as a value
        resolve_callee();
        int fv = find_func(@id_name);
        if fv >= 0 {
            gen_function_value(fv, @id_name);
            return;
        }
        if pass_no < 2 {
            emit_line("mov x0, 0");
            ex_ty = 97;
            ex_w = 8;
            return;
        }
        die_name("unknown name", @id_name);
    }
    if v_local >= 1 && v_kind == 0 { uninit_read(find_local(@id_name)); }
    char gi_name[256];
    str_copy(@gi_name, @id_name, 256);
    parse_lvalue();
    if try_indirect_call() { return; }
    finish_rvalue();
    if lv_done == 1 && tok_is(".") { call_postfix(); }       // s.trim().len : go on with the result of a method
}

// the function f used as a value (its name without a call): x0 = its address,
// ex_ty = the type of its signature
void gen_function_value(int fi, char^ name) {
    if pass_no < 2 { ex_ty = 97; ex_w = 8; emit_line("mov x0, 0"); return; }
    if fself[fi] == 1 || farr[fi] == 1 { die_name("the address of a method or of a function with an array parameter cannot be taken", name); }
    if fnpar[fi] > 8 { die_name("a function with more than 8 parameters cannot be used as a value", name); }
    int k = 0;
    while k < fnpar[fi] {
        sg_tmp[k] = fptid[fi * 8 + k];
        k += 1;
    }
    int r = fret[fi];
    if fvoid[fi] == 1 { r = 98; }
    int sg = sig_intern(r, fnpar[fi]);
    note_call(name);                     // the function is used: keep it in the program
    emit_str("adr x0, ");
    emit_line(name);
    ex_w = 8;
    ex_ty = 0 - sg - 1;
}

// a call through a function pointer: its value is in x0, the token is "("
void gen_call_indirect(int tid) {
    int sg = 0 - tid - 1;
    push_x0();                           // the address waits under the arguments
    expect("(");
    int pre = 0;
    int tmp_off = 0;
    int r = sig_ret[sg];
    if r >= 100 && r < 200 {
        ty_tid = 0;
        add_local("..result", 0, 16 + r - 100, ssize[r - 100], 0);
        tmp_off = loff[lcount - 1];
        ins_n("add x0, x29, #", tmp_off);
        push_x0();
        pre = 1;
    }
    call_sig = sg;
    call_fi = 0 - 1;
    call_skip = 0;
    int n = parse_args();
    if n != sig_n[sg] && pass_no >= 2 { die("wrong number of arguments for this function pointer"); }
    n += pre;
    pop_args(n);
    if n <= 8 {
        emit_line("ldr x9, [sp, #0]");
        emit_line("add sp, sp, #16");
        emit_line("blr x9");
    } else {
        ins_mem("ldr", "x9", "sp", n * 16);       // the address is under the argument slots
        emit_line("blr x9");
        ins_n("add sp, sp, #", n * 16 + 16);
    }
    if tmp_off != 0 { ins_n("add x0, x29, #", tmp_off); }
    ex_w = 8;
    ex_ty = r;
    if r == 98 { ex_ty = 0; }
}

// ---------------------------------------------------------- dynamic arrays
// A variable of type T[] holds the address of a header [length, capacity, data, element size]
// (see std/prelude.j, struct __Arr). The packed element type: code | ptr << 8 | (tid + 1024) << 17.

int dyn_pack(int code, int ptr, int tid) {
    return code + ptr * 1024 + (tid + 1024) * 1048576;
}

int dyn_code(int info) {
    return info % 1024;
}

int dyn_ptr(int info) {
    return (info / 1024) % 1024;
}

int dyn_tid(int info) {
    return info / 1048576 - 1024;
}

// A value of a struct that frees itself (it has a method free(self)) cannot be copied. It moves: a fresh value (the result of
// a call, a constructor) is taken over, a plain local variable is emptied (zeroed) after its bytes were copied, anything
// else is an error. Returns 1 for a fresh value, 2 for a local variable (its frame offset in own_src_off), else dies.
int struct_source(int sidx) {
    if last_call_struct == 1 && last_call_struct_off != 0 {
        own_src_off = last_call_struct_off;
        return 2;
    }
    if rv_valid == 1 {
        int oi = own_find(rv_off);
        if oi >= 0 && own_kind[oi] == 4 {
            own_src_off = rv_off;
            return 2;
        }
    }
    if pass_no >= 2 { die_name("a value that frees itself can only be taken from a call or from a local variable (it moves); use a pointer for the rest", @sname + sidx * 64); }
    return 1;
}

// the local variable at frame offset off (a struct of size bytes) becomes empty: zeros
void emit_zero_local(int off, int size) {
    int zk = 0;
    emit_line("mov x1, 0");
    while zk < size {
        ins_mem("str", "x1", "x29", off + zk);
        zk += 8;
    }
}

// ---------------------------------------------------------------- String
// A String is a dynamic array of char (a header on the heap) that is marked by the type id 70 in its
// packed element type. In expressions its type is 80. It is copied when it is assigned (a copy of
// a String variable, a text, or a temporary that is taken over), is freed at the end of its block
// like the other owners, and a String made by an expression (a + b, s.slice(..), a call) is a
// temporary owner of kind 2 that is freed at the end of the statement unless it is taken over.
bool is_str_dyn(int info) {
    return info != 0 && dyn_code(info) == 2 && dyn_tid(info) == 70;
}

// String[]: a dynamic array whose elements are Strings (8 bytes each); the array owns them
bool is_strarr_dyn(int info) {
    return info != 0 && dyn_code(info) == 8 && dyn_ptr(info) == 0 && dyn_tid(info) == 71;
}


// x0 = a new String: remember it as a temporary owner
void str_temp() {
    if cond_depth > 0 { die("a new String cannot be made on the right of && or || (put it in a variable first)"); }
    if cur_fidx < 0 { die("a String can only be made inside a function"); }
    ty_tid = 0;
    add_local(".t", 0, 8, 8, 0);
    int off = loff[lcount - 1];
    ins_mem("str", "x0", "x29", off);
    own_add(off, 2, 0);
    rv_valid = 1;
    rv_off = off;
    ex_ty = 80;
    ex_w = 8;
}

// how an operand is passed to the String routines: 0 a text, 1 a String, 2 one character
int str_kind() {
    if ex_ty == 80 { return 1; }
    if ex_w == 9 { return 0; }
    if ex_w == 2 { return 2; }
    if pass_no >= 2 { die("a String operand must be a String, a text or a char"); }
    return 0;
}

// x0 = the value of an expression that becomes the content of a String variable: afterwards x0 is a
// String that the destination owns (a text is copied, a String variable is copied, a temporary is taken over)
void str_adopt() {
    if pass_no >= 2 {
        if ex_ty == 80 {
            int ti = 0 - 1;
            if rv_valid == 1 { ti = own_find(rv_off); }
            if ti >= 0 && own_kind[ti] == 2 {
                emit_owner_null(ti);
                own_moved[ti] = 1;
            } else {
                rt_call("__Str__clone");
            }
        } else if ex_w == 9 {
            rt_call("__Str__from");
        } else {
            die("a String can only be made from a text or another String");
        }
    }
    rv_valid = 0;
    ex_ty = 80;
    ex_w = 8;
}

// the temporaries from own[t0..] are freed (keep = 1: x0 is kept) and leave the list
bool is_temp_kind(int k) {
    return k == 2 || k == 6 || k == 7 || k == 9;
}

void str_flush(int t0, int keep) {
    int i = t0;
    int any = 0;
    int first_tmp = 0 - 1;
    while i < own_count {
        if is_temp_kind(own_kind[i]) && own_moved[i] == 0 { any = 1; }
        if is_temp_kind(own_kind[i]) && first_tmp < 0 { first_tmp = i; }
        i += 1;
    }
    if any == 1 {
        if keep == 1 { push_x0(); }
        i = own_count - 1;
        while i >= t0 {
            if is_temp_kind(own_kind[i]) && own_moved[i] == 0 { emit_owner_free(i); }
            i -= 1;
        }
        if keep == 1 {
            emit_line("ldr x0, [sp, #0]");
            emit_line("add sp, sp, #16");
        }
    }
    if first_tmp >= 0 { own_unlink(first_tmp); }
    int w = t0;
    i = t0;
    while i < own_count {
        if !is_temp_kind(own_kind[i]) {
            own_off[w] = own_off[i];
            own_kind[w] = own_kind[i];
            own_aux[w] = own_aux[i];
            own_rec[w] = own_rec[i];
            own_blk[w] = own_blk[i];
            own_moved[w] = own_moved[i];
            w += 1;
        }
        i += 1;
    }
    own_count = w;
}

void rt_call(char^ name) {
    note_call(name);
    emit_str("bl ");
    emit_line(name);
}

// x0 = a header address: stop with an exception if it is null
void dyn_null_check() {
    int lok = new_label();
    emit_line("cmp x0, 0");
    jump_if("ne", lok);
    rt_call("__Arr__nullerr");
    place_label(lok);
}

// the members of a String that are not those of every dynamic array; true if dm was one of them
// (x0 = the address of the variable, the token is after the name)
bool str_member(char^ dm) {
    if str_eq(dm, "push") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Str__push");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "pop") {
        expect("(");
        expect(")");
        load_through(8);
        rt_call("__Str__pop");
        ex_w = 2;
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "clear") {
        expect("(");
        expect(")");
        load_through(8);
        rt_call("__Str__clear");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "append") || str_eq(dm, "find") {
        bool is_find = str_eq(dm, "find");
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        int kb = str_kind();
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", kb);
        if is_find {
            rt_call("__Str__find");
            ex_w = 8;
        } else {
            rt_call("__Str__append");
        }
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "slice") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        push_x0();
        expect(",");
        parse_expr();
        expect(")");
        emit_line("mov x2, x0");
        emit_line("ldr x1, [sp, #0]");
        emit_line("ldr x0, [sp, #16]");
        emit_line("add sp, sp, #32");
        rt_call("__Str__slice");
        str_temp();
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "c") {
        expect("(");
        expect(")");
        load_through(8);
        rt_call("__Str__c");
        ex_w = 9;
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "trim") || str_eq(dm, "upper") || str_eq(dm, "lower") {
        expect("(");
        expect(")");
        load_through(8);
        if str_eq(dm, "trim") { rt_call("__Str__trim"); }
        if str_eq(dm, "upper") { rt_call("__Str__upper"); }
        if str_eq(dm, "lower") { rt_call("__Str__lower"); }
        str_temp();
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "to_int") || str_eq(dm, "to_double") {
        expect("(");
        expect(")");
        load_through(8);
        if str_eq(dm, "to_int") {
            rt_call("__Str__to_int");
            ex_ty = 0;
        } else {
            rt_call("__Str__to_double");
            ex_ty = 91;
        }
        ex_w = 8;
        rv_valid = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "starts_with") || str_eq(dm, "ends_with") || str_eq(dm, "contains") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        int kx = str_kind();
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", kx);
        if str_eq(dm, "starts_with") { rt_call("__Str__starts_with"); }
        if str_eq(dm, "ends_with") { rt_call("__Str__ends_with"); }
        if str_eq(dm, "contains") {
            rt_call("__Str__find");
            emit_line("mov x1, 0");
            compare("ge");
        }
        ex_w = 8;
        ex_ty = 1;
        rv_valid = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "replace") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        int ka = str_kind();
        push_x0();
        expect(",");
        parse_expr();
        expect(")");
        int kb = str_kind();
        emit_line("mov x3, x0");
        ins_n("mov x4, ", kb);
        emit_line("ldr x1, [sp, #0]");
        ins_n("mov x2, ", ka);
        emit_line("ldr x0, [sp, #16]");
        emit_line("add sp, sp, #32");
        rt_call("__Str__replace");
        str_temp();
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "repeat") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Str__repeat");
        str_temp();
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "split") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        int ks = str_kind();
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", ks);
        rt_call("__Str__split");
        ex_w = 8;
        ex_ty = 99;
        ex_dyn = dyn_pack(8, 0, 71);       // a String[] that the caller owns
        last_call_owning = 1;
        rv_valid = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "resize") { die("a String has no resize (use push, append or slice)"); }
    return false;
}

// the members of a String[] (x0 = the address of the variable); true if dm was one of them
bool strarr_member(char^ dm) {
    if str_eq(dm, "push") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        str_adopt();                     // the array gets its own copy (or takes a temporary over)
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Str__apush");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "pop") {
        expect("(");
        expect(")");
        load_through(8);
        rt_call("__Str__apop");
        str_temp();                      // the String that came out is a temporary
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "insert") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        push_x0();
        expect(",");
        parse_expr();
        expect(")");
        str_adopt();
        emit_line("mov x2, x0");
        emit_line("ldr x1, [sp, #0]");
        emit_line("ldr x0, [sp, #16]");
        emit_line("add sp, sp, #32");
        rt_call("__Str__ainsert");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "remove") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Str__aremove");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "clear") || str_eq(dm, "sort") {
        expect("(");
        expect(")");
        load_through(8);
        if str_eq(dm, "clear") { rt_call("__Str__clear_all"); } else { rt_call("__Str__asort"); }
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "contains") || str_eq(dm, "index_of") {
        bool want_bool = str_eq(dm, "contains");
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        int kx = str_kind();
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", kx);
        rt_call("__Str__aindex");
        ex_w = 8;
        ex_ty = 0;
        if want_bool {
            emit_line("mov x1, 0");
            compare("ge");
            ex_ty = 1;
        }
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "free") {
        expect("(");
        expect(")");
        push_x0();                       // the variable's address
        load_through(8);
        rt_call("__Str__free_all");
        emit_line("ldr x3, [sp, #0]");
        emit_line("add sp, sp, #16");
        emit_line("mov x1, 0");
        store_through(8);
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "join") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        int kj = str_kind();
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", kj);
        rt_call("__Str__ajoin");
        str_temp();
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "resize") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Str__aresize");        // new places are null Strings
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    return false;
}

// how the array routines compare elements of this type: 0 signed, 1 unsigned (also pointers), 2 float, 3 double
int arr_kind(int code, int eptr) {
    if eptr != 0 { return 1; }
    if code == 6 { return 2; }
    if code == 7 { return 3; }
    if code == 2 || code == 3 || code == 11 || code == 12 || code == 13 { return 1; }
    return 0;
}

// insert remove sort contains index_of on an array of numbers / pointers (x0 = the address of the variable)
bool num_member(char^ dm, int code, int eptr, int etid) {
    if code >= 16 && eptr == 0 {
        if str_eq(dm, "insert") || str_eq(dm, "remove") || str_eq(dm, "sort") || str_eq(dm, "contains") || str_eq(dm, "index_of") {
            die_name("this method works on arrays of numbers, pointers and Strings", dm);
        }
        return false;
    }
    int kind = arr_kind(code, eptr);
    if str_eq(dm, "sort") {
        expect("(");
        expect(")");
        load_through(8);
        ins_n("mov x1, ", kind);
        rt_call("__Arr__sort");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "remove") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Arr__remove");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "insert") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        push_x0();
        expect(",");
        parse_expr();
        if eptr == 0 { check_assign(etid); }
        expect(")");
        emit_line("mov x2, x0");
        emit_line("ldr x1, [sp, #0]");
        emit_line("ldr x0, [sp, #16]");
        emit_line("add sp, sp, #32");
        rt_call("__Arr__insert");
        ex_ty = 0;
        lv_done = 1;
        return true;
    }
    if str_eq(dm, "contains") || str_eq(dm, "index_of") {
        bool want_bool = str_eq(dm, "contains");
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        if eptr == 0 { check_assign(etid); }
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x2, ", kind);
        rt_call("__Arr__index");
        ex_w = 8;
        ex_ty = 0;
        if want_bool {
            emit_line("mov x1, 0");
            compare("ge");
            ex_ty = 1;
        }
        lv_done = 1;
        return true;
    }
    return false;
}

// x[i] on a dynamic array: x0 = the address of the variable
void dyn_index() {
    int info = lv_dyn;
    int code = dyn_code(info);
    int eptr = dyn_ptr(info);
    int etid = dyn_tid(info);
    if is_str_dyn(info) { etid = 0; }     // the elements of a String are plain chars
    load_through(8);                     // x0 = the header
    dyn_null_check();
    push_x0();
    next();                              // "["
    parse_expr();
    expect("]");
    pop_x1();                            // x1 = the header, x0 = the index
    if opt_debug == 1 {
        int lok = new_label();
        emit_line("ldr x2, [x1, #0]");
        emit_line("cmp x0, x2");
        jump_if("lo", lok);
        emit_line("mov x1, x2");
        emit_line("bl j2k_oob");
        place_label(lok);
        used_oob = 1;
    }
    emit_line("ldr x2, [x1, #16]");
    ins_n("mov x3, ", size_of(code));
    emit_line("mul x0, x0, x3");
    emit_line("add x0, x0, x2");
    lv_code = code;
    lv_ptr = eptr;
    lv_tid = etid;
    if eptr != 0 { lv_tid = 0; }
    lv_kind = 0;
    lv_dyn = 0;
    lv_fresh = 0;
    if is_strarr_dyn(info) {
        // an element of a String[] is a String variable
        lv_code = 8;
        lv_ptr = 0;
        lv_tid = 99;
        lv_kind = 3;
        lv_dyn = dyn_pack(2, 0, 70);
    }
}

// x.len  x.cap  x.push(v)  x.pop()  x.resize(n)  x.clear()  x.free()  on a dynamic array
// (x0 = the address of the variable). Sets lv_done, or turns a popped struct into the object.
void dyn_member() {
    int info = lv_dyn;
    int code = dyn_code(info);
    int eptr = dyn_ptr(info);
    int etid = dyn_tid(info);
    if is_str_dyn(info) { etid = 0; }     // the elements of a String are plain chars
    next();                              // "."
    if tok_kind != T_IDENT { die("a member name was expected"); }
    char dm[64];
    str_copy(@dm, @tok_text, 64);
    next();
    ex_w = 8;
    ex_ty = 0;
    if is_str_dyn(info) && str_member(@dm) { return; }
    if is_strarr_dyn(info) && strarr_member(@dm) { return; }
    if str_eq(@dm, "clone") && !is_str_dyn(info) {
        // a copy of an array (a String[] copies its Strings): a new array that the receiver owns
        expect("(");
        expect(")");
        load_through(8);
        if is_strarr_dyn(info) { rt_call("__Str__aclone"); } else { rt_call("__Arr__clone"); }
        ex_w = 8;
        ex_ty = 99;
        ex_dyn = info;
        last_call_owning = 1;
        rv_valid = 0;
        lv_done = 1;
        return;
    }
    if !is_str_dyn(info) && !is_strarr_dyn(info) && num_member(@dm, code, eptr, etid) { return; }
    if str_eq(@dm, "len") || str_eq(@dm, "cap") {
        load_through(8);
        dyn_null_check();
        if str_eq(@dm, "len") { emit_line("ldr x0, [x0, #0]"); } else { emit_line("ldr x0, [x0, #8]"); }
        lv_done = 1;
        return;
    }
    if str_eq(@dm, "push") {
        expect("(");
        load_through(8);
        push_x0();                       // the header
        arr_esize = 0;
        parse_expr();
        if eptr == 0 { check_assign(etid); }
        expect(")");
        int push_owner = 0 - 1;
        if rv_valid == 1 { push_owner = own_find(rv_off); }
        push_x0();                       // the value (the address of a struct)
        emit_line("ldr x0, [sp, #16]");
        rt_call("__Arr__slot");          // x0 = the place of the new element
        emit_line("mov x3, x0");
        emit_line("ldr x1, [sp, #0]");
        emit_line("add sp, sp, #32");
        if code >= 16 && code < 400 && eptr == 0 {
            emit_line("mov x0, x1");
            ins_n("mov x2, ", ssize[code - 16]);
            emit_line("bl j2k_copy");
        } else {
            store_through(code);
        }
        if push_owner >= 0 {
            emit_owner_null(push_owner);       // the array owns the pointer now
            if own_blk[push_owner] == cur_blk { own_moved[push_owner] = 1; }
        }
        ex_ty = 0;
        lv_done = 1;
        return;
    }
    if str_eq(@dm, "pop") {
        expect("(");
        expect(")");
        load_through(8);
        rt_call("__Arr__pop");           // x0 = where the removed element still is
        if code >= 16 && code < 400 && eptr == 0 {
            lv_code = code;              // a struct: it is the object from here on
            lv_kind = 0;
            lv_ptr = 0;
            lv_tid = etid;
            lv_dyn = 0;
            lv_fresh = 0;
            lv_done = 0;
            return;
        }
        load_through(code);
        ex_w = code;
        ex_ty = etid;
        if eptr != 0 { ex_ty = 0; }
        if eptr == 2 { ex_w = 9; }
        lv_done = 1;
        return;
    }
    if str_eq(@dm, "resize") {
        expect("(");
        load_through(8);
        push_x0();
        parse_expr();
        bin_type(0, ex_ty);
        expect(")");
        emit_line("mov x1, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        rt_call("__Arr__resize");
        lv_done = 1;
        return;
    }
    if str_eq(@dm, "clear") {
        expect("(");
        expect(")");
        load_through(8);
        dyn_null_check();
        emit_line("mov x1, 0");
        emit_line("str x1, [x0, #0]");
        lv_done = 1;
        return;
    }
    if str_eq(@dm, "free") {
        expect("(");
        expect(")");
        push_x0();                       // the variable's address
        load_through(8);
        rt_call("__Arr__free");
        emit_line("ldr x3, [sp, #0]");
        emit_line("add sp, sp, #16");
        emit_line("mov x1, 0");
        store_through(8);                // the variable is null from now on
        lv_done = 1;
        return;
    }
    die_name("a dynamic array has no such member", @dm);
}

// after an l-value chain: if the object is a function pointer and "(" follows, call it
bool try_indirect_call() {
    if lv_done == 1 || lv_kind != 0 || lv_tid >= 0 || lv_code >= 16 { return false; }
    if !tok_is("(") { return false; }
    load_through(lv_code);
    gen_call_indirect(lv_tid);
    return true;
}

// the value of the object found by the l-value chain (x0 = its address)
void finish_rvalue() {
    if lv_done == 1 { return; }
    if lv_fresh == 1 && lv_base_local == 1 && (lv_kind == 0 || lv_kind == 3) {
        rv_valid = 1;
        rv_off = lv_base_off;
        int oi = own_find(lv_base_off);
        if oi >= 0 && own_moved[oi] == 1 { warn("this variable was moved and is used afterwards (it is null now)", "moved"); }
    }
    if lv_kind == 3 {
        load_through(8);                 // a dynamic array as a value: its header address
        ex_w = 8;
        ex_ty = 99;
        ex_dyn = lv_dyn;
        if is_str_dyn(lv_dyn) { ex_ty = 80; }
        return;
    }
    if lv_kind == 1 {
        if in_cout == 0 && pass_no >= 2 { die("an array needs an index (or @)"); }
        if lv_nd == 1 {
            ex_arr_cnt = lv_cnt;
            ex_arr_code = lv_code;
        }
        ex_ty = 0;                   // cout << name : the text of a char array
        ex_w = 8;
        if lv_code == 2 { ex_w = 9; }
        return;
    }
    if lv_code >= 16 {
        ex_w = 8;                    // a struct value is its address
        ex_ty = 100 + lv_code - 16;
        return;
    }
    load_through(lv_code);
    ex_w = lv_code;
    ex_ty = lv_tid;
    if lv_ptr != 0 { ex_ty = 0; }
    if lv_ptr == 2 { ex_w = 9; }
}

// (T)x where T or x is a float; x0 = the value (type src)
void gen_float_cast(int to, int src, int to_width) {
    if is_float(to) && is_float(src) {
        if to == 90 && src == 91 || to == 90 && src == 92 {
            lit_to_f32(0);
        } else if to == 91 && src == 90 {
            f32_to_f64(0);
        }
        return;
    }
    if is_float(to) {
        // number -> float
        if !is_numeric(src) { die("only numbers can be cast to a float"); }
        char cv[8];
        str_copy(@cv, "scvtf", 8);
        if is_unsigned(src) { str_copy(@cv, "ucvtf", 8); }
        if to == 90 {
            emit_str(@cv);
            emit_line(" s0, x0");
            emit_line("fmov w0, s0");
        } else {
            emit_str(@cv);
            emit_line(" d0, x0");
            emit_line("fmov x0, d0");
        }
        return;
    }
    // float -> number (the fraction is cut off)
    if to != 0 && !is_unsigned(to) { die("a float can only be cast to a number type"); }
    char fz[8];
    str_copy(@fz, "fcvtzs", 8);
    if is_unsigned(to) { str_copy(@fz, "fcvtzu", 8); }
    if src == 90 {
        emit_line("fmov s0, w0");
        emit_str(@fz);
        emit_line(" x0, s0");
    } else {
        emit_line("fmov d0, x0");
        emit_str(@fz);
        emit_line(" x0, d0");
    }
    if to_width == 1 { emit_line("sxtb x0, x0"); }
    if to_width == 2 || to_width == 11 { emit_line("uxtb x0, x0"); }
    if to_width == 4 { emit_line("sxtw x0, x0"); }
    if to_width == 12 { emit_line("uxtw x0, x0"); }
}

// sizeof(Type) or sizeof(variable / field / element): the size in bytes, known now
void gen_sizeof() {
    next();                              // "sizeof"
    expect("(");
    int size = 0;
    if at_type() {
        parse_type();
        if ty_void == 1 && ty_ptr == 0 { die("sizeof(void) has no meaning"); }
        size = 8;
        if ty_ptr == 0 { size = size_of(ty_elem); }
    } else {
        // the operand is read only for its type: the code it makes is thrown away
        int sv_out = out_len;
        int sv_gl = gl_bytes;
        int sv_ginit = ginit_count;
        int sv_fp = used_fprint;
        int sv_oob = used_oob;
        int sv_lcount = lcount;
        int serial = lv_serial;
        int sv_cout = in_cout;
        in_cout = 1;                     // a whole array is allowed here
        parse_unary();
        in_cout = sv_cout;
        if lv_serial != serial && lv_done == 0 {
            if lv_kind == 1 {
                size = lv_cnt * size_of(lv_code);
            } else if lv_ptr != 0 {
                size = 8;
            } else if lv_tid == 1 {
                size = 1;
            } else {
                size = size_of(lv_code);
            }
        } else if ex_ty == 90 {
            size = 4;
        } else if ex_ty >= 100 {
            size = ssize[ex_ty - 100];
        } else {
            size = 8;
        }
        out_len = sv_out;
        gl_bytes = sv_gl;
        ginit_count = sv_ginit;
        used_fprint = sv_fp;
        used_oob = sv_oob;
        lcount = sv_lcount;
    }
    expect(")");
    ins_n("mov x0, ", size);
    ex_w = 8;
    ex_ty = 96;
}

// a value followed by ? : see gen_try_op
void parse_unary() {
    parse_unary_core();
    while tok_is("?") {
        gen_try_op();
    }
}

// the current token is a struct / enum name followed by :: (Name::call(...), not a type in a cast)?
bool scope_follows() {
    int k = 0;
    while lc(k) == 32 || lc(k) == 9 { k += 1; }
    return lc(k) == ':' && lc(k + 1) == ':';
}

void parse_unary_core() {
    rv_valid = 0;
    last_call_owning = 0;
    last_call_struct = 0;
    if tok_kind == T_NUM && tok_float == 1 {
        gen_float_literal();
        return;
    }
    if tok_kind == T_NUM {
        ins_n("mov x0, ", tok_num);
        ex_w = 0;
        ex_ty = 96;                      // a whole-number literal: fits a signed or an unsigned type
        if tok_char == 1 { ex_w = 2; }
        if tok_char == 0 && tok_num >= 0 && tok_num <= 1 { ex_ty = 2; }
        next();
        return;
    }
    if tok_kind == T_STR {
        gen_string();
        ex_w = 9;
        ex_ty = 0;
        if tok_is(".") {
            // "text".trim() : the text becomes a String (a temporary) that has the methods
            rt_call("__Str__from");
            str_temp();
            call_postfix();
        }
        return;
    }
    if tok_kind == T_IDENT {
        if lambda_fn_ahead() {
            gen_lambda_fn();
            return;
        }
        if tok_is("sizeof") {
            gen_sizeof();
            return;
        }
        if tok_is("true") {
            emit_line("mov x0, 1");
            ex_w = 8;
            ex_ty = 1;
            next();
            return;
        }
        if tok_is("false") {
            emit_line("mov x0, 0");
            ex_w = 8;
            ex_ty = 1;
            next();
            return;
        }
        if tok_is("null") {
            emit_line("mov x0, 0");
            ex_w = 8;
            ex_ty = 97;
            next();
            return;
        }
        gen_identifier();
        return;
    }
    if tok_is("(") && lambda_ahead() {
        gen_lambda();
        return;
    }
    if tok_is("(") {
        next();
        if at_type() && !scope_follows() {
            parse_type();
            if ty_void == 1 && ty_ptr == 0 { die("a value cannot be cast to void"); }
            expect(")");
            int cast_ty = ty_tid;
            int cast_ptr = ty_ptr;
            int cast_w = ty_width;
            parse_unary();
            if cast_ptr == 0 && pass_no >= 2 {
                if cast_ty == 1 { die("a value cannot be cast to bool (write a comparison)"); }
                if ex_ty == 1 { die("a bool cannot be cast (write a comparison instead)"); }
            }
            if cast_ptr == 0 && (is_float(cast_ty) || is_float(ex_ty)) {
                gen_float_cast(cast_ty, ex_ty, cast_w);
                ex_w = 8;
                ex_ty = cast_ty;
                return;
            }
            ex_ty = 0;
            if cast_ptr == 0 { ex_ty = cast_ty; }
            ty_width = cast_w;
            ty_ptr = cast_ptr;
            if ty_ptr != 0 {
                ex_w = 8;
                if ty_ptr == 2 { ex_w = 9; }          // (char^)p is a text
            } else {
                if ty_width == 1 { emit_line("sxtb x0, x0"); }
                if ty_width == 2 || ty_width == 11 { emit_line("uxtb x0, x0"); }
                if ty_width == 4 { emit_line("sxtw x0, x0"); }
                if ty_width == 12 { emit_line("uxtw x0, x0"); }
                ex_w = ty_width;
            }
            return;
        }
        parse_expr();
        expect(")");
        return;
    }
    if tok_is("-") {
        next();
        if tok_kind == T_NUM && tok_float == 0 {
            ins_n("mov x0, ", 0 - tok_num);
            ex_w = 0;
            ex_ty = 0;
            next();
            return;
        }
        parse_unary();
        if is_float(ex_ty) {
            if ex_ty == 90 {
                emit_line("fmov s0, w0");
                emit_line("fneg s0, s0");
                emit_line("fmov w0, s0");
            } else {
                emit_line("fmov d0, x0");
                emit_line("fneg d0, d0");
                emit_line("fmov x0, d0");
            }
            return;
        }
        need_num(ex_ty);
        if is_unsigned(ex_ty) && pass_no >= 2 { die("unary minus does not apply to an unsigned number (use 0 - x with a cast)"); }
        ex_ty = 0;
        emit_line("mov x1, 0");
        emit_line("sub x0, x1, x0");
        return;
    }
    if tok_is("!") {
        next();
        parse_unary();
        need_bool();
        int lt = new_label();
        emit_line("cmp x0, 0");
        emit_line("mov x0, 1");
        jump_if("eq", lt);
        emit_line("mov x0, 0");
        place_label(lt);
        ex_w = 8;
        ex_ty = 1;
        return;
    }
    if tok_is("~") {
        next();
        parse_unary();
        need_num(ex_ty);
        if !is_unsigned(ex_ty) { ex_ty = 0; }
        emit_line("mov x1, -1");
        emit_line("eor x0, x0, x1");
        if ex_ty == 93 { emit_line("uxtb x0, x0"); }
        if ex_ty == 94 { emit_line("uxtw x0, x0"); }
        return;
    }
    if tok_is("@") {
        next();
        if tok_kind != T_IDENT { die("@ needs a variable name"); }
        str_copy(@id_name, @tok_text, 256);
        next();
        if !lookup_var(@id_name) { die_name("unknown name", @id_name); }
        uninit_clear(@id_name);            // its address is taken: it may be written through it
        parse_lvalue();
        if lv_done == 1 { die("@ needs a variable, element or field"); }
        ex_w = 8;
        ex_ty = 0;
        return;
    }
    die("expression expected");
}

// -------------------------------------------------- binary operator levels

// right operand evaluated; x0 = right, the left value is on the stack:
// leaves x0 = left, x1 = right
void take_operands() {
    rv_valid = 0;
    emit_line("mov x1, x0");
    emit_line("ldr x0, [sp, #0]");
    emit_line("add sp, sp, #16");
}

// the instruction for an arithmetic/bit operator word or symbol applied to
// x0 and x1
int uns_op;                  // 1: the next arith() works on unsigned numbers

// x1 = the divisor: 0 throws "division by zero" (catchable), in every build
int div_nonzero;             // 1: the divisor is a literal other than 0: no check
void emit_divzero_check() {
    if div_nonzero == 1 { return; }
    int lok = new_label();
    emit_line("cmp x1, 0");
    jump_if("ne", lok);
    emit_line("bl j2k_divzero");
    place_label(lok);
    used_divz = 1;
    note_call("__panic");
}

void arith(char^ op) {
    if str_eq(op, "+") { emit_line("add x0, x0, x1"); return; }
    if str_eq(op, "-") { emit_line("sub x0, x0, x1"); return; }
    if str_eq(op, "*") { emit_line("mul x0, x0, x1"); return; }
    if str_eq(op, "/") {
        emit_divzero_check();
        if uns_op == 1 { emit_line("udiv x0, x0, x1"); } else { emit_line("sdiv x0, x0, x1"); }
        return;
    }
    if str_eq(op, "%") {
        emit_divzero_check();
        if uns_op == 1 { emit_line("udiv x2, x0, x1"); } else { emit_line("sdiv x2, x0, x1"); }
        emit_line("mul x2, x2, x1");
        emit_line("sub x0, x0, x2");
        return;
    }
    if str_eq(op, "&") { emit_line("and x0, x0, x1"); return; }
    if str_eq(op, "|") { emit_line("orr x0, x0, x1"); return; }
    if str_eq(op, "xor") { emit_line("eor x0, x0, x1"); return; }
    if str_eq(op, "<<") || str_eq(op, "shl") { emit_line("lsl x0, x0, x1"); return; }
    if str_eq(op, ">>") || str_eq(op, "shr") {
        if uns_op == 1 { emit_line("lsr x0, x0, x1"); } else { emit_line("asr x0, x0, x1"); }
        return;
    }
    die_name("unknown operator", op);
}

void parse_mul() {
    parse_unary();
    int mlw = ex_w;
    int mlt = ex_ty;
    while tok_is("*") || tok_is("/") || tok_is("%") {
        char op[8];
        str_copy(@op, @tok_text, 8);
        next();
        push_x0();
        int rhs_lit = 0;
        if tok_kind == T_NUM && tok_float == 0 && tok_num != 0 { rhs_lit = 1; }
        parse_unary();
        if is_float(mlt) || is_float(ex_ty) {
            if str_eq(@op, "%") { die("% does not work on floats"); }
            int mrt = ex_ty;
            take_operands();
            mlt = fp_binop(@op, mlt, mrt);
            ex_ty = mlt;
            mlw = 8;
            ex_w = 8;
        } else {
            int mlt_t = bin_type(mlt, ex_ty);
            mlt = mlt_t;
            ex_ty = mlt_t;
            uns_op = 0;
            if is_unsigned(mlt_t) { uns_op = 1; }
            take_operands();
            div_nonzero = rhs_lit;
            arith(@op);
            div_nonzero = 0;
            mlw = res_w(mlw, ex_w);
            wrap_result(mlw);
        }
    }
}

void parse_add() {
    parse_mul();
    int alw = ex_w;
    int alt = ex_ty;
    while tok_is("+") || tok_is("-") {
        char aop[8];
        str_copy(@aop, @tok_text, 8);
        next();
        push_x0();
        parse_mul();
        if alt == 80 || ex_ty == 80 {
            // String + String / text / char
            if !str_eq(@aop, "+") { die("a String can only be joined with +"); }
            int kb = str_kind();
            int ka = 0;
            if alt == 80 { ka = 1; } else if alw == 2 { ka = 2; }
            emit_line("mov x2, x0");
            emit_line("ldr x0, [sp, #0]");
            emit_line("add sp, sp, #16");
            ins_n("mov x1, ", ka);
            ins_n("mov x3, ", kb);
            rt_call("__Str__cat");
            str_temp();
            alt = 80;
            alw = 8;
        } else if is_float(alt) || is_float(ex_ty) {
            int art = ex_ty;
            take_operands();
            alt = fp_binop(@aop, alt, art);
            ex_ty = alt;
            alw = 8;
            ex_w = 8;
        } else {
            int alt_t = bin_type(alt, ex_ty);
            alt = alt_t;
            ex_ty = alt_t;
            uns_op = 0;
            if is_unsigned(alt_t) { uns_op = 1; }
            take_operands();
            arith(@aop);
            alw = res_w(alw, ex_w);
            wrap_result(alw);
        }
    }
}

void parse_shift() {
    parse_add();
    int slw = ex_w;
    int slt = ex_ty;
    while (tok_is("<<") || tok_is(">>")) && in_cout == 0 || tok_is("shl") || tok_is("shr") {
        char sop[8];
        str_copy(@sop, @tok_text, 8);
        next();
        push_x0();
        parse_add();
        int slt_t = shift_type(slt, ex_ty);
        slt = slt_t;
        ex_ty = slt_t;
        uns_op = 0;
        if is_unsigned(slt_t) { uns_op = 1; }
        take_operands();
        arith(@sop);
        slw = res_w(slw, ex_w);
        wrap_result(slw);
    }
}

void parse_bitand() {
    parse_shift();
    int blw = ex_w;
    int blt = ex_ty;
    while tok_is("&") {
        next();
        push_x0();
        parse_shift();
        int blt_t = bin_type(blt, ex_ty);
        blt = blt_t;
        ex_ty = blt_t;
        uns_op = 0;
        if is_unsigned(blt_t) { uns_op = 1; }
        take_operands();
        emit_line("and x0, x0, x1");
        blw = res_w(blw, ex_w);
        wrap_result(blw);
    }
}

void parse_bitxor() {
    parse_bitand();
    int xlw = ex_w;
    int xlt = ex_ty;
    while tok_is("xor") {
        next();
        push_x0();
        parse_bitand();
        int xlt_t = bin_type(xlt, ex_ty);
        xlt = xlt_t;
        ex_ty = xlt_t;
        uns_op = 0;
        if is_unsigned(xlt_t) { uns_op = 1; }
        take_operands();
        emit_line("eor x0, x0, x1");
        xlw = res_w(xlw, ex_w);
        wrap_result(xlw);
    }
}

void parse_bitor() {
    parse_bitxor();
    int olw = ex_w;
    int olt = ex_ty;
    while tok_is("|") {
        next();
        push_x0();
        parse_bitxor();
        int olt_t = bin_type(olt, ex_ty);
        olt = olt_t;
        ex_ty = olt_t;
        uns_op = 0;
        if is_unsigned(olt_t) { uns_op = 1; }
        take_operands();
        emit_line("orr x0, x0, x1");
        olw = res_w(olw, ex_w);
        wrap_result(olw);
    }
}

// x0 = (left cond right): 1 or 0
void compare(char^ cond) {
    int ld = new_label();
    emit_line("cmp x0, x1");
    emit_line("mov x0, 1");
    jump_if(cond, ld);
    emit_line("mov x0, 0");
    place_label(ld);
}

void parse_relational() {
    parse_bitor();
    while tok_is("<") || tok_is(">") || tok_is("<=") || tok_is(">=") {
        char rel[4];
        str_copy(@rel, @tok_text, 4);
        int rel_lt = ex_ty;
        if !is_float(rel_lt) { need_num(ex_ty); }
        next();
        push_x0();
        parse_bitor();
        int rel_rt = ex_ty;
        if !is_float(rel_lt) && !is_float(rel_rt) { need_num(ex_ty); }
        take_operands();
        if is_float(rel_lt) || is_float(rel_rt) {
            if str_eq(@rel, "<") { fp_compare("lt", rel_lt, rel_rt); }
            if str_eq(@rel, ">") { fp_compare("gt", rel_lt, rel_rt); }
            if str_eq(@rel, "<=") { fp_compare("le", rel_lt, rel_rt); }
            if str_eq(@rel, ">=") { fp_compare("ge", rel_lt, rel_rt); }
        } else if is_unsigned(rel_lt) || is_unsigned(rel_rt) {
            if !num_compat(rel_lt, rel_rt) && pass_no >= 2 { die("cannot compare signed and unsigned numbers (use a cast)"); }
            if str_eq(@rel, "<") { compare("lo"); }
            if str_eq(@rel, ">") { compare("hi"); }
            if str_eq(@rel, "<=") { compare("ls"); }
            if str_eq(@rel, ">=") { compare("hs"); }
        } else {
            if str_eq(@rel, "<") { compare("lt"); }
            if str_eq(@rel, ">") { compare("gt"); }
            if str_eq(@rel, "<=") { compare("le"); }
            if str_eq(@rel, ">=") { compare("ge"); }
        }
        ex_w = 8;
        ex_ty = 1;
    }
}

// == and != need two values of the same kind (the literal 0/1 fits a number or a bool)
void check_comparable(int a, int b) {
    if pass_no < 2 { return; }
    int ok = 0;
    if is_numeric(a) && is_numeric(b) && num_compat(a, b) { ok = 1; }
    if a == 99 && (b == 99 || b == 97) { ok = 1; }
    if b == 99 && a == 97 { ok = 1; }
    if a == 97 && (is_numeric(b) || b < 0 || b == 97) { ok = 1; }          // null
    if b == 97 && (is_numeric(a) || a < 0) { ok = 1; }
    if a < 0 && a == b { ok = 1; }
    if (a == 1 || a == 2) && (b == 1 || b == 2) { ok = 1; }
    if a >= 3 && a == b { ok = 1; }
    if ok == 0 { die("cannot compare values of different types (use a cast)"); }
}

void parse_equality() {
    parse_relational();
    while tok_is("==") || tok_is("!=") {
        char eqop[4];
        str_copy(@eqop, @tok_text, 4);
        int eq_left = ex_ty;
        int eq_lw = ex_w;
        next();
        push_x0();
        parse_relational();
        int eq_right = ex_ty;
        if eq_left == 80 || eq_right == 80 {
            // String == String / text
            int kb = str_kind();
            int ka = 0;
            if eq_left == 80 { ka = 1; } else if eq_lw == 2 { ka = 2; }
            emit_line("mov x2, x0");
            emit_line("ldr x0, [sp, #0]");
            emit_line("add sp, sp, #16");
            ins_n("mov x1, ", ka);
            ins_n("mov x3, ", kb);
            rt_call("__Str__eq");
            if str_eq(@eqop, "!=") {
                emit_line("mov x1, 1");
                emit_line("eor x0, x0, x1");
            }
            ex_w = 8;
            ex_ty = 1;
            rv_valid = 0;
        } else {
        if !is_float(eq_left) && !is_float(eq_right) { check_comparable(eq_left, eq_right); }
        take_operands();
        if is_float(eq_left) || is_float(eq_right) {
            if str_eq(@eqop, "==") { fp_compare("eq", eq_left, eq_right); }
            if str_eq(@eqop, "!=") { fp_compare("ne", eq_left, eq_right); }
        } else {
            if str_eq(@eqop, "==") { compare("eq"); }
            if str_eq(@eqop, "!=") { compare("ne"); }
        }
        ex_w = 8;
        ex_ty = 1;
        }
    }
}

// a && b : the right side only runs if the left side is true
void parse_land() {
    parse_equality();
    if tok_is("&&") {
        int lfalse = new_label();
        int lend = new_label();
        while tok_is("&&") {
            rv_valid = 0;
            need_bool();
            next();
            emit_line("cmp x0, 0");
            jump_if("eq", lfalse);
            cond_depth += 1;
            parse_equality();
            cond_depth -= 1;
        }
        need_bool();
        emit_line("cmp x0, 0");
        jump_if("eq", lfalse);
        emit_line("mov x0, 1");
        jump(lend);
        place_label(lfalse);
        emit_line("mov x0, 0");
        place_label(lend);
        ex_w = 8;
        ex_ty = 1;
    }
}

// a || b : the right side only runs if the left side is false
void parse_expr() {
    int saved_cout = in_cout;
    in_cout = 0;
    parse_land();
    if tok_is("||") {
        int ltrue = new_label();
        int lend2 = new_label();
        while tok_is("||") {
            rv_valid = 0;
            need_bool();
            next();
            emit_line("cmp x0, 0");
            jump_if("ne", ltrue);
            cond_depth += 1;
            parse_land();
            cond_depth -= 1;
        }
        need_bool();
        emit_line("cmp x0, 0");
        jump_if("ne", ltrue);
        emit_line("mov x0, 0");
        jump(lend2);
        place_label(ltrue);
        emit_line("mov x0, 1");
        place_label(lend2);
        ex_w = 8;
        ex_ty = 1;
    }
    in_cout = saved_cout;
}
