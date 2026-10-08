// jc_stmt.jk -- part 4 of the J2K compiler written in J2K: statements,
// functions, global declarations, the program's start stub and main().
//
// usage:  jcmp input.jk output.jasm
//
// The language it understands (the subset S, enough to compile itself):
//   top level   import "file"   TYPE name;   TYPE name = literal;
//               TYPE name[N];   RET name(TYPE a, TYPE^ b) { ... }
//   types       int  char  bool  (void for a result), and T^ pointers
//   statements  declarations, name = e;  name op= e;  name[i] = e;
//               p^ = e;  name++;  call;  if / else if / else;  while;
//               break;  continue;  return [e];  { block }
//   expressions numbers (decimal, 0x, 0b), 'c', "text", true false null,
//               names, name[i], p^, @name, calls, syscall(...), argc(), arg(i),
//               - ! ~ * / % + - << >> & xor | < > <= >= == != && ||
//
// Rule for this file (the first compiler has no block scope): a local
// variable name is used only once per function.

// ------------------------------------------------------------ declarations


int cf_flag;                 // parse_const found a float constant
int cf_mant;
int cf_exp;
int cf_neg;
int gfi_off[4096];            // global floats set at startup
int gfi_mant[4096];
int gfi_exp[4096];
int gfi_neg[4096];
int gfi_f32[4096];
int gfi_count;
int cur_in_func;             // 1 while compiling a function body
int using_line;
int gsi_off[4096];            // global structs whose init() runs at startup
int gsi_s[4096];
int gsi_n[4096];
int gsi_count;
int fn_self_struct = -1;     // set while a struct's method is parsed
int cur_ret_off;             // frame slot holding the hidden result address (struct results)
int cp_src[8];               // struct parameters to copy in the prologue
int cp_dst[8];
int cp_size[8];
int cp_count;
int cur_ret_isptr;           // 1 if the function returns a pointer or a dynamic array
int cur_ret_tid;
int cur_is_main;             // compiling main?
int ret_label;               // label of the current function's epilogue
int patch_a;                 // out_buf positions of the frame-size digits
int patch_b;

int body_pending;            // 1 just before a function body is parsed
int for_step;                // 1 while parsing a for-loop step: the assignment has no ';'
int try_depth;               // try blocks that are open at this point of the function
int used_try;                // 1 if try / throw was used: the exception routines are emitted
int loop_own[64];            // own_count when each open loop began
int loop_try[64];            // try_depth when each open loop began
int brk_stack[64];           // labels for break / continue, one per open loop
int cont_stack[64];
int loop_depth;

int parse_fn_type_ok = 1;      // parse_type may read RET(PARAMS)^

// is the current token a type word?
bool at_type() {
    if tok_kind == T_IDENT && find_enum(@tok_text) >= 0 { return true; }
    if tok_kind == T_IDENT && find_struct(@tok_text) >= 0 { return true; }
    return tok_is("int") || tok_is("char") || tok_is("bool") || tok_is("void") || tok_is("i8") || tok_is("i32") || tok_is("f32") || tok_is("f64") || tok_is("u8") || tok_is("u32") || tok_is("u64");
}

// TYPE [^] ; sets the ty_* variables and leaves the token after the type
void parse_type() {
    ty_void = 0;
    ty_ptr = 0;
    ty_tid = 0;
    ty_dyn = 0;
    if tok_is("int") {
        ty_elem = 8;
        ty_width = 8;
    } else if tok_is("char") {
        ty_elem = 2;
        ty_width = 2;
    } else if tok_is("i8") {
        ty_elem = 1;
        ty_width = 1;
    } else if tok_is("u8") {
        ty_elem = 11;
        ty_width = 11;
        ty_tid = 93;
    } else if tok_is("u32") {
        ty_elem = 12;
        ty_width = 12;
        ty_tid = 94;
    } else if tok_is("u64") {
        ty_elem = 13;
        ty_width = 13;
        ty_tid = 95;
    } else if tok_is("f32") {
        ty_elem = 6;
        ty_width = 6;
        ty_tid = 90;
    } else if tok_is("f64") {
        ty_elem = 7;
        ty_width = 7;
        ty_tid = 91;
    } else if tok_is("i32") {
        ty_elem = 4;
        ty_width = 4;
    } else if tok_is("bool") {
        ty_elem = 3;
        ty_width = 8;
        ty_tid = 1;
    } else if tok_is("void") {
        ty_elem = 10;                    // void^ : a pointer to nothing in particular
        ty_width = 8;
        ty_void = 1;
    } else if tok_kind == T_IDENT && find_enum(@tok_text) >= 0 {
        ty_tid = 3 + find_enum(@tok_text);
        ty_elem = 8;
        ty_width = 8;
    } else if tok_kind == T_IDENT && find_struct(@tok_text) >= 0 {
        int st = find_struct(@tok_text);
        ty_tid = 100 + st;
        ty_elem = 16 + st;
        ty_width = 16 + st;
    } else {
        die("a type was expected");
    }
    next();
    if tok_is("^") {
        ty_tid = 0;
        next();
        ty_ptr = ty_elem;            // a pointer: the pointee is this type
        ty_elem = 8;
        ty_width = 8;
        if tok_is("^") {
            next();                  // T^^ : a pointer to a pointer to T
            ty_ptr = 100 + ty_ptr;
            if tok_is("^") { die("at most two levels of ^ are supported (T^^)"); }
        }
    }
    if tok_is("(") && parse_fn_type_ok == 1 {
        // RET(PARAMS)^ : a pointer to a function
        int r_tid = ty_tid;
        if ty_ptr != 0 { r_tid = 0; }
        if ty_void == 1 && ty_ptr == 0 { r_tid = 98; }
        next();
        int pn = 0;
        int ptmp[16];
        if !tok_is(")") {
            while true {
                parse_type();
                int pt = ty_tid;
                if ty_ptr != 0 { pt = 0; }
                if ty_void == 1 && ty_ptr == 0 { die("a parameter type cannot be void"); }
                if pn >= 8 { die("a function pointer type has at most 8 parameters"); }
                ptmp[pn] = pt;
                pn += 1;
                if tok_is(",") {
                    next();
                } else {
                    break;
                }
            }
        }
        expect(")");
        expect("^");
        int pk = 0;
        while pk < pn {
            sg_tmp[pk] = ptmp[pk];
            pk += 1;
        }
        int sg = sig_intern(r_tid, pn);
        ty_tid = 0 - sg - 1;
        ty_elem = 8;
        ty_width = 8;
        ty_ptr = 0;
        ty_void = 0;
    }
    if tok_is("[") {
        // T[] : a dynamic array of T (the elements are T, or T^ ...)
        if ty_void == 1 && ty_ptr == 0 { die("an array of void"); }
        int de_tid = ty_tid;
        if ty_ptr != 0 { de_tid = 0; }
        int de_code = ty_elem;
        int de_ptr = ty_ptr;
        next();
        expect("]");
        ty_dyn = dyn_pack(de_code, de_ptr, de_tid);
        ty_tid = 99;
        ty_elem = 8;
        ty_width = 8;
        ty_ptr = 0;
    }
}

// the frame size goes in as seven digits so the text can be patched later
void emit_patch_digits() {
    patch_a = out_len;
    emit_str("0000000");
}

void patch_number(int at, int value) {
    int k = 6;
    while k >= 0 {
        out_buf[at + k] = '0' + value % 10;
        value = value / 10;
        k -= 1;
    }
}

// ------------------------------------------------------------- assignments

// after "name" (already looked up): the rest of an assignment statement, or a
// method call used as a statement:  = e;  op= e;  ++;  --;  name.f(...);
// The target may be name, name[i], p^, a.b.c, a[i].f[j] ...
void parse_assign(char^ target) {
    char op[8];
    op[0] = 0;
    str_copy(@id_name, target, 256);
    parse_lvalue();
    if lv_done == 1 {
        if for_step == 0 { expect(";"); }
        return;
    }
    if try_indirect_call() {             // f(...) through a function pointer, used as a statement
        if for_step == 0 { expect(";"); }
        return;
    }
    int a_code = lv_code;
    int a_kind = lv_kind;
    int lv_dyn_saved = lv_dyn;
    int a_tid = lv_tid;
    int a_ptr = lv_ptr;
    int a_fresh = lv_fresh;              // the target is a plain variable (no [ ] . ^ in front of the =)
    int a_base_local = lv_base_local;
    int a_base_off = lv_base_off;
    if lv_kind == 1 { die_name("an array needs an index", target); }
    int tgt_ty = a_tid;
    if a_ptr != 0 { tgt_ty = 0; }
    push_x0();                           // the target's address waits on the stack
    int is_incr = 0;
    if tok_is("=") {
        next();
    } else if tok_is("++") || tok_is("--") {
        is_incr = 1;
        if tok_is("++") { str_copy(@op, "+", 8); } else { str_copy(@op, "-", 8); }
        next();
    } else if tok_kind == T_OP && str_len(@tok_text) >= 2 && tok_text[str_len(@tok_text) - 1] == '=' {
        str_copy(@op, @tok_text, 8);
        op[str_len(@op) - 1] = 0;         // "+=" -> "+"
        next();
    } else {
        die("an assignment was expected");
    }
    if a_code >= 16 && a_ptr == 0 {
        // a whole struct: copy from another struct or fill from { ... }
        if op[0] != 0 { die("a struct can only be assigned with ="); }
        if tok_is("{") {
            parse_brace(a_code - 16, 0);
        } else {
            parse_expr();
            check_assign(a_tid);
            emit_line("ldr x3, [sp, #0]");
            ins_n("mov x2, ", ssize[a_code - 16]);
            emit_line("bl j2k_copy");
        }
        emit_line("add sp, sp, #16");
        if for_step == 0 { expect(";"); }
        return;
    }
    int src_owner = 0 - 1;               // the owner variable whose value is being stored, if any
    if is_incr == 1 {
        emit_line("mov x0, 1");
        ex_ty = 0;
        need_num(tgt_ty);
    } else {
        if a_kind == 3 { arr_esize = size_of(dyn_code(lv_dyn_saved)); }
        parse_expr();
        arr_esize = 0;
        if rv_valid == 1 && op[0] == 0 && (a_ptr != 0 || a_kind == 3) { src_owner = own_find(rv_off); }      // only a pointer or an array handle can carry ownership
        if op[0] == 0 {
            check_assign(tgt_ty);
        } else if !is_float(tgt_ty) {
            bin_type(tgt_ty, ex_ty);
        }
    }
    int rhs_ty = ex_ty;
    if for_step == 0 { expect(";"); }
    emit_line("ldr x3, [sp, #0]");       // x3 = the target's address, x0 = the value
    emit_line("add sp, sp, #16");
    emit_line("mov x1, x0");
    if op[0] != 0 {
        load_from_x3(a_code);
        if is_float(tgt_ty) {
            fp_binop(@op, tgt_ty, rhs_ty);
        } else {
            uns_op = 0;
            if is_unsigned(tgt_ty) { uns_op = 1; }
            arith_op(@op);
        }
        emit_line("mov x1, x0");
    }
    store_through(a_code);
    if src_owner >= 0 {
        // p = owner; storing it somewhere that outlives the block (a field, an element, a global,
        // another owner) moves the ownership there; a plain alias variable only borrows it
        int tgt_own = 0 - 1;
        if a_fresh == 1 && a_base_local == 1 { tgt_own = own_find(a_base_off); }
        // a plain variable declared in the same or an inner block only borrows; one that outlives the owner's block takes it
        bool borrow = a_fresh == 1 && a_base_local == 1 && tgt_own < 0;
        if borrow && blk_encloses(local_blk(a_base_off), own_blk[src_owner]) { borrow = false; }
        if !borrow {
            emit_owner_null(src_owner);
            if own_blk[src_owner] == cur_blk { own_moved[src_owner] = 1; }
        }
    }
    if a_fresh == 1 && a_base_local == 1 && op[0] == 0 {
        int me = own_find(a_base_off);
        if me >= 0 { own_moved[me] = 0; }          // it owns something again
    }
}

// { v, v, ... } for struct s: fills the struct whose address is on top of the
// stack, starting `base` bytes into it
void parse_brace(int s, int base) {
    expect("{");
    int k = 0;
    while k < snf[s] {
        int fi = sfirst[s] + k;
        if k > 0 { expect(","); }
        if fldkind[fi] == 1 {
            expect("{");
            int e = 0;
            int esz = size_of(fldcode[fi]);
            while e < fldcnt[fi] {
                if e > 0 { expect(","); }
                parse_expr();
                emit_line("ldr x3, [sp, #0]");
                ins_n("add x3, x3, #", base + fldoff[fi] + e * esz);
                emit_line("mov x1, x0");
                store_through(fldcode[fi]);
                e += 1;
            }
            expect("}");
        } else if fldcode[fi] >= 16 && fldptr[fi] == 0 {
            parse_brace(fldcode[fi] - 16, base + fldoff[fi]);
        } else {
            parse_expr();
            emit_line("ldr x3, [sp, #0]");
            ins_n("add x3, x3, #", base + fldoff[fi]);
            emit_line("mov x1, x0");
            store_through(fldcode[fi]);
        }
        k += 1;
    }
    expect("}");
}

// x0 = x0 op x1 for an operator given as text ("+", "xor", "<<", ...)
void arith_op(char^ opname) {
    arith(opname);
}

// ------------------------------------------------------------- statements

void parse_block() {
    int scope_mark = lcount;             // names declared inside end with the block
    int saved_base = scope_base;
    if body_pending == 1 {
        body_pending = 0;                // the function body shares its scope with the parameters
    } else {
        scope_base = lcount;
    }
    int saved_blk = cur_blk;
    blk_serial += 1;
    if blk_serial >= 4000 { die("too many nested or consecutive blocks in one function"); }
    blk_parent[blk_serial] = cur_blk;
    cur_blk = blk_serial;
    int saved_ok = own_ok;
    own_ok = 1;
    int own_mark = own_count;
    expect("{");
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected"); }
        parse_statement();
    }
    expect("}");
    own_free_from(own_mark, 1);          // the memory that this block owns is given back here
    own_ok = saved_ok;
    cur_blk = saved_blk;
    lcount = scope_mark;
    scope_base = saved_base;
}

// "cond {": the condition value in x0, then a jump to `lfalse` if it is 0
void parse_condition(int lfalse) {
    parse_expr();
    need_bool();
    emit_line("cmp x0, 0");
    jump_if("eq", lfalse);
}

void parse_if() {
    int lend = new_label();
    int lnext = new_label();
    next();                              // "if"
    parse_condition(lnext);
    parse_block();
    while tok_is("else") {
        next();
        jump(lend);
        place_label(lnext);
        if tok_is("if") {
            lnext = new_label();
            next();
            parse_condition(lnext);
            parse_block();
        } else {
            lnext = 0;
            parse_block();
            break;
        }
    }
    if lnext != 0 { place_label(lnext); }
    place_label(lend);
}

void parse_while() {
    int lstart = new_label();
    int lend = new_label();
    next();                              // "while"
    place_label(lstart);
    parse_condition(lend);
    if loop_depth >= 63 { die("loops nested too deeply"); }
    brk_stack[loop_depth] = lend;
    cont_stack[loop_depth] = lstart;
    loop_try[loop_depth] = try_depth;
    loop_own[loop_depth] = own_count;
    loop_depth += 1;
    parse_block();
    loop_depth -= 1;
    jump(lstart);
    place_label(lend);
}

// for TYPE name = e; cond; step { ... }      for name in a..b { ... }
void parse_for() {
    int for_mark = lcount;
    int lstart = new_label();
    int lbody = new_label();
    int lstep = new_label();
    int lend = new_label();
    next();                              // "for"
    if loop_depth >= 63 { die("loops nested too deeply"); }
    if at_type() {
        parse_local_decl();              // the declaration ends with ';'
        place_label(lstart);
        parse_condition(lend);
        expect(";");
        jump(lbody);
        place_label(lstep);
        for_step = 1;
        parse_statement();
        for_step = 0;
        jump(lstart);
        place_label(lbody);
    } else {
        // for i in a..b : i counts a, a+1, ... b-1
        if tok_kind != T_IDENT { die("a loop variable was expected"); }
        char f_name[256];
        str_copy(@f_name, @tok_text, 256);
        next();
        expect("in");
        parse_expr();
        ty_tid = 0;
        add_local(@f_name, 0, 8, 8, 0);
        int f_off = loff[lcount - 1];
        ins_mem("str", "x0", "x29", f_off);
        expect(".");
        expect(".");
        parse_expr();
        add_local("..end", 0, 8, 8, 0);
        int e_off = loff[lcount - 1];
        ins_mem("str", "x0", "x29", e_off);
        place_label(lstart);
        ins_mem("ldr", "x0", "x29", f_off);
        ins_mem("ldr", "x1", "x29", e_off);
        emit_line("cmp x0, x1");
        jump_if("ge", lend);
        jump(lbody);
        place_label(lstep);
        ins_mem("ldr", "x0", "x29", f_off);
        emit_line("add x0, x0, #1");
        ins_mem("str", "x0", "x29", f_off);
        jump(lstart);
        place_label(lbody);
    }
    brk_stack[loop_depth] = lend;
    cont_stack[loop_depth] = lstep;
    loop_try[loop_depth] = try_depth;
    loop_own[loop_depth] = own_count;
    loop_depth += 1;
    parse_block();
    loop_depth -= 1;
    jump(lstep);
    place_label(lend);
    lcount = for_mark;
}

// cout << a << b << ...;   (one number alone also ends the line)
void parse_cout() {
    int c_count = 0;
    int c_last = 0;
    int c_float = 0;
    if tok_is("coutf") { c_float = 1; }
    next();                              // "cout" or "coutf"
    while tok_is("<<") {
        next();
        in_cout = 1;
        parse_bitor();
        in_cout = 0;
        c_last = ex_w;
        if is_float(ex_ty) {
            if c_float == 0 { die("cout prints numbers and text; use coutf for floats"); }
            if ex_ty == 90 { f32_to_f64(0); }
            emit_line("bl j2k_print_f64");
            used_fprint = 1;
            used_uprint = 1;
            c_last = 8;
        } else if c_last == 9 {
            emit_line("bl j2k_print_str");
        } else if c_last == 2 {
            emit_line("bl j2k_print_char");
        } else {
            if ex_ty == 95 {
                emit_line("bl j2k_print_uint");
                used_uprint = 1;
            } else {
                emit_line("bl j2k_print_int");
            }
        }
        c_count += 1;
    }
    if c_count == 0 { die("<< expected after cout"); }
    expect(";");
    if c_count == 1 && c_last != 9 && c_last != 2 {
        emit_line("mov x0, 10");
        emit_line("bl j2k_print_char");
    }
}

int dim_nd;                  // dimensions found by parse_dims
int dim_s1;
int dim_s2;

// "[N]", "[N][M]", "[N][M][K]" or "[]": the token is the first "["; returns the
// number of elements in all (-1 for an empty "[]" that a string will size)
int parse_dims() {
    int dims[3];
    int nd = 0;
    int pd_total = 1;
    while tok_is("[") {
        if nd >= 3 { die("an array has at most 3 dimensions"); }
        next();
        if tok_is("]") {
            if nd > 0 { die("only the first dimension can be empty"); }
            next();
            dims[0] = 0 - 1;
            pd_total = 0 - 1;
            nd = 1;
        } else {
            if tok_kind != T_NUM { die("an array size (a number) was expected"); }
            if tok_num <= 0 { die("bad array size"); }
            dims[nd] = tok_num;
            if pd_total >= 0 { pd_total = pd_total * tok_num; }
            nd += 1;
            next();
            expect("]");
        }
    }
    dim_nd = nd;
    dim_s1 = 0;
    dim_s2 = 0;
    if nd == 2 { dim_s1 = dims[1]; }
    if nd == 3 {
        dim_s1 = dims[1] * dims[2];
        dim_s2 = dims[2];
    }
    return pd_total;
}

// 8 bytes of the string token starting at byte k (0 beyond its end)
int str_chunk(int k) {
    int chunk = 0;
    int b = 7;
    while b >= 0 {
        chunk = chunk * 256;
        if k + b < tok_str_len { chunk = chunk + tok_str[k + b]; }
        b -= 1;
    }
    return chunk;
}

// enum class Name { A = 0, B, C = 10 };   (numbers go on from the last one)
void parse_enum() {
    next();                              // "enum"
    expect("class");
    if tok_kind != T_IDENT { die("an enum name was expected"); }
    int en = find_enum(@tok_text);
    if en < 0 {
        if ecount >= 64 { die("too many enums"); }
        en = ecount;
        str_copy(@ename + en * 64, @tok_text, 64);
        ecount += 1;
    }
    int register_members = 0;
    if pass_no == 1 { register_members = 1; }
    next();
    expect("{");
    int next_val = 0;
    while !tok_is("}") {
        if tok_kind != T_IDENT { die("an enum member name was expected"); }
        int mi = emcount;
        if register_members == 1 {
            if emcount >= 8192 { die("too many enum members"); }
            str_copy(@emname + mi * 64, @tok_text, 64);
            emenum[mi] = en;
        }
        next();
        if tok_is("=") {
            next();
            int neg = 0;
            if tok_is("-") {
                neg = 1;
                next();
            }
            if tok_kind != T_NUM { die("an enum value (a number) was expected"); }
            next_val = tok_num;
            if neg == 1 { next_val = 0 - next_val; }
            next();
        }
        if register_members == 1 {
            emval[mi] = next_val;
            emcount += 1;
        }
        next_val += 1;
        if tok_is(",") {
            next();
        } else {
            break;
        }
    }
    expect("}");
    accept(";");
}

// using enum Name;   |   using ...; (other forms are skipped)
void parse_using() {
    using_line = err_line;
    next();                              // "using"
    if tok_is("enum") {
        next();
        int en = find_enum(@tok_text);
        if en < 0 { die_name("unknown enum", @tok_text); }
        if cur_in_func == 1 {
            ue_l[en] = 1;
        } else {
            ue_g[en] = 1;
        }
        next();
        accept(";");
        return;
    }
    // using std / using std::fs / using Struct
    int us_s = -1;
    if tok_is("std") {
        next();
        if tok_is("::") {
            // using std::fs / mem / str / sys / math : the struct of that module
            next();
            if tok_is("fs") { us_s = find_struct("File"); }
            else if tok_is("mem") { us_s = find_struct("Mem"); }
            else if tok_is("str") { us_s = find_struct("Str"); }
            else if tok_is("sys") { us_s = find_struct("Sys"); }
            else if tok_is("math") { us_s = find_struct("Math"); }
            else { die_name("unknown std module", @tok_text); }
            next();
        } else {
            // using std : every module
            int um = 0;
            while um < scount {
                if cur_in_func == 1 {
                    us_l[um] = 1;
                } else {
                    us_g[um] = 1;
                }
                um += 1;
            }
        }
    } else if tok_kind == T_IDENT {
        us_s = find_struct(@tok_text);
        if us_s < 0 && pass_no >= 2 { die_name("unknown struct", @tok_text); }
        next();
    }
    if us_s >= 0 {
        if cur_in_func == 1 {
            us_l[us_s] = 1;
        } else {
            us_g[us_s] = 1;
        }
    }
    accept(";");
}

// the value of a case label or global initializer: a number, 'c', -n, an enum
// member (Enum::Member or a bare member after using enum); leaves the type in ex_ty
int parse_const() {
    int neg = 0;
    if tok_is("-") {
        neg = 1;
        next();
    }
    int v = 0;
    ex_ty = 0;
    cf_flag = 0;
    if tok_kind == T_NUM && tok_float == 1 {
        cf_flag = 1;                     // a float constant: the caller stores it
        cf_mant = tok_mant;
        cf_exp = tok_exp;
        cf_neg = neg;
        ex_ty = 92;
        next();
        return 0;
    }
    if tok_kind == T_NUM {
        v = tok_num;
        ex_ty = 96;
        if tok_char == 0 && tok_num >= 0 && tok_num <= 1 { ex_ty = 2; }
        next();
    } else if tok_is("true") {
        v = 1;
        ex_ty = 1;
        next();
    } else if tok_is("false") {
        ex_ty = 1;
        next();
    } else if tok_is("null") {
        next();
    } else if tok_kind == T_IDENT {
        int en = find_enum(@tok_text);
        char cn[256];
        str_copy(@cn, @tok_text, 256);
        next();
        if en >= 0 && tok_is("::") {
            next();
            if !find_member(en, @tok_text) { die_name("not a member of the enum", @tok_text); }
            v = found_val;
            ex_ty = 3 + en;
            next();
        } else if find_using_member(@cn) {
            v = found_val;
        } else {
            die("a constant was expected");
        }
    } else {
        die("a constant was expected");
    }
    if neg == 1 { v = 0 - v; }
    return v;
}

// switch e { 1, 2: stmt;  Kind::A: { ... }  _: stmt; }
void parse_switch() {
    int sv_line = err_line;              // where the switch is, for a warning
    int sv_col = err_col;
    int sv_base = err_base;
    int sv_ls = err_ls;
    next();                              // "switch"
    parse_expr();
    int sw_ty = ex_ty;
    int covered[8192];
    int ci_ = 0;
    while ci_ < 8192 {
        covered[ci_] = 0;
        ci_ += 1;
    }
    ty_tid = 0;
    add_local("..switch", 0, 8, 8, 0);
    int sw_off = loff[lcount - 1];
    ins_mem("str", "x0", "x29", sw_off);
    int lend = new_label();
    int ldef = 0;
    expect("{");
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected"); }
        int lbody = new_label();
        int lnext = new_label();
        if tok_is("_") {
            next();
            expect(":");
            ldef = new_label();
            jump(lnext);
            place_label(ldef);
        } else {
            while true {
                int cv = parse_const();
                if sw_ty >= 3 && sw_ty < 90 {
                    int mk = 0;
                    while mk < emcount {
                        if emenum[mk] == sw_ty - 3 && emval[mk] == cv { covered[mk] = 1; }
                        mk += 1;
                    }
                }
                ins_mem("ldr", "x0", "x29", sw_off);
                ins_n("mov x1, ", cv);
                emit_line("cmp x0, x1");
                jump_if("eq", lbody);
                if tok_is(",") {
                    next();
                } else {
                    break;
                }
            }
            expect(":");
            jump(lnext);
            place_label(lbody);
        }
        int sv_ok = own_ok;
        if !tok_is("{") { own_ok = 0; }  // a case body without braces: it may not run, nothing declared there owns memory
        parse_statement();
        own_ok = sv_ok;
        jump(lend);
        place_label(lnext);
    }
    expect("}");
    if ldef != 0 { jump(ldef); }
    place_label(lend);
    if sw_ty >= 3 && sw_ty < 90 && ldef == 0 && pass_no >= 2 {
        // an enum switch without `_` must name every member
        char wmsg[600];
        wmsg[0] = 0;
        int missing = 0;
        int mm = 0;
        while mm < emcount {
            if emenum[mm] == sw_ty - 3 && covered[mm] == 0 {
                if missing > 0 { append_text(@wmsg, ", "); }
                append_text(@wmsg, "'");
                append_text(@wmsg, @emname + mm * 64);
                append_text(@wmsg, "'");
                missing += 1;
            }
            mm += 1;
        }
        if missing > 0 {
            char wfull[700];
            str_copy(@wfull, "enumeration value(s) ", 700);
            append_text(@wfull, @wmsg);
            append_text(@wfull, " not handled in switch");
            err_line = sv_line;
            err_col = sv_col;
            err_base = sv_base;
            err_ls = sv_ls;
            warn(@wfull, "switch");
        }
    }
}

// does struct s have an init(self) method?
bool struct_has_init(int s) {
    char hn[64];
    str_copy(@hn, @sname + s * 64, 64);
    str_copy(@hn + str_len(@hn), "__init", 8);
    if find_func(@hn) >= 0 {
        note_call(@hn);                  // an init() runs where a variable of this struct is made
        return true;
    }
    return false;
}

// run init() on the struct whose address is in x0
void emit_init_call(int s) {
    emit_str("bl ");
    emit_str(@sname + s * 64);
    emit_line("__init");
}

// run init() on each element of the local struct array at frame offset off
void emit_init_array(int s, int off, int count) {
    ty_tid = 0;
    add_local("..i", 0, 8, 8, 0);
    int c_off = loff[lcount - 1];
    int lk = new_label();
    int le = new_label();
    emit_line("mov x0, 0");
    ins_mem("str", "x0", "x29", c_off);
    place_label(lk);
    ins_mem("ldr", "x0", "x29", c_off);
    ins_n("cmp x0, ", count);
    jump_if("ge", le);
    ins_n("mov x1, ", ssize[s]);
    emit_line("mul x0, x0, x1");
    ins_n("add x1, x29, #", off);
    emit_line("add x0, x0, x1");
    emit_init_call(s);
    ins_mem("ldr", "x0", "x29", c_off);
    emit_line("add x0, x0, #1");
    ins_mem("str", "x0", "x29", c_off);
    jump(lk);
    place_label(le);
}

// leaving n open try blocks early (return / break / continue)
void leave_tries(int n) {
    while n > 0 {
        emit_line("bl j2k_try_leave");
        n -= 1;
    }
}

// try { ... } catch (e) { ... }     e is the text that was thrown (a char^)
void parse_try() {
    used_try = 1;
    next();                              // "try"
    int lcatch = new_label();
    int lend = new_label();
    emit_line("bl j2k_try_enter");       // returns 0 now, and 1 again after a throw
    emit_line("cmp x0, 0");
    jump_if("ne", lcatch);
    try_depth += 1;
    parse_block();
    try_depth -= 1;
    emit_line("bl j2k_try_leave");
    jump(lend);
    place_label(lcatch);
    if !tok_is("catch") { die("catch expected after the try block"); }
    next();
    expect("(");
    if tok_kind != T_IDENT { die("a name for the thrown text was expected"); }
    int catch_mark = lcount;
    char c_name[256];
    str_copy(@c_name, @tok_text, 256);
    next();
    expect(")");
    ty_tid = 0;
    add_local(@c_name, 0, 8, 8, 2);
    ins_mem("ldr", "x0", "x28", 72);
    ins_mem("str", "x0", "x29", loff[lcount - 1]);
    parse_block();
    lcount = catch_mark;
    place_label(lend);
}

// throw "text";   (the nearest catch gets the text; nothing to catch = the program stops)
void parse_throw() {
    used_try = 1;
    next();                              // "throw"
    parse_expr();
    if ex_w != 9 && pass_no >= 2 { die("throw needs text (a string or a char array)"); }
    expect(";");
    emit_line("bl j2k_throw");
}

// a local declaration:  TYPE name;  TYPE name = e;  TYPE name[N];
// a struct without fields only groups functions: a variable of it does nothing
void warn_static_only(int s) {
    if snf[s] == 0 && pass_no >= 2 {
        char smsg[200];
        str_copy(@smsg, "'", 200);
        append_text(@smsg, @sname + s * 64);
        append_text(@smsg, "' is a static-only struct, instantiating it has no effect");
        warn(@smsg, "static-struct");
    }
}

void parse_local_decl() {
    char first_word[256];
    str_copy(@first_word, @tok_text, 256);
    parse_type();
    if tok_is("::") && ty_ptr == 0 {         // Struct::function(...);
        str_copy(@id_name, @first_word, 256);
        gen_scope();
        expect(";");
        return;
    }
    if ty_void == 1 && ty_ptr == 0 { die("a variable cannot be void"); }
    int d_elem = ty_elem;
    int d_width = ty_width;
    int d_ptr = ty_ptr;
    int d_tid = ty_tid;
    int d_dyn = ty_dyn;
    if tok_kind != T_IDENT { die("a variable name was expected"); }
    char d_name[256];
    str_copy(@d_name, @tok_text, 256);
    next();
    if tok_is("[") {
        int d_count = parse_dims();
        int d_nd = dim_nd;
        int d_s1 = dim_s1;
        int d_s2 = dim_s2;
        int d_str = 0;
        if tok_is("=") {
            next();
            if tok_kind != T_STR { die("a string was expected"); }
            if size_of(d_elem) != 1 { die("only a char array can start from a string"); }
            if d_nd != 1 { die("only a one-dimensional array can start from a string"); }
            d_str = 1;
            if d_count < 0 { d_count = tok_str_len + 1; }
            if tok_str_len + 1 > d_count { die("the string does not fit in the array"); }
        } else {
            if d_count < 0 { die("an array size (a number) was expected"); }
            expect(";");
        }
        ty_tid = d_tid;
        add_local(@d_name, 1, d_elem, d_count * size_of(d_elem), d_ptr);
        lnd[lcount - 1] = d_nd;
        lst1[lcount - 1] = d_s1;
        lst2[lcount - 1] = d_s2;
        if d_elem >= 16 && d_str == 0 && struct_has_init(d_elem - 16) {
            emit_init_array(d_elem - 16, loff[lcount - 1], d_count);
        }
        if d_str == 1 {
            int d_off = loff[lcount - 1];
            int d_w = 0;
            while d_w * 8 < d_count {
                ins_n("mov x0, ", str_chunk(d_w * 8));
                ins_mem("str", "x0", "x29", d_off + d_w * 8);
                d_w += 1;
            }
            next();
            expect(";");
        }
        return;
    }
    if d_dyn != 0 {
        // T[] name;   T[] name = arr(n);   T[] name = other;
        int dd_start = 0;                // 1: this variable owns the array
        if tok_is("=") {
            next();
            arr_esize = size_of(dyn_code(d_dyn));
            parse_expr();
            arr_esize = 0;
            check_assign(99);
            if last_call_owning == 1 && own_ok == 1 { dd_start = 1; }
        } else {
            emit_line("mov x0, 0");
        }
        expect(";");
        ty_tid = 99;
        ty_dyn = d_dyn;
        add_local(@d_name, 3, 8, 8, 0);
        ins_mem("str", "x0", "x29", loff[lcount - 1]);
        if dd_start == 1 { own_add(loff[lcount - 1], 1); }
        return;
    }
    if d_width >= 16 && d_ptr == 0 {
        // a struct variable
        int d_sidx = d_width - 16;
        warn_static_only(d_sidx);
        if tok_is("=") {
            next();
            if tok_is("{") {
                ty_tid = d_tid;
                add_local(@d_name, 0, d_width, ssize[d_sidx], 0);
                ins_n("add x0, x29, #", loff[lcount - 1]);
                push_x0();
                parse_brace(d_sidx, 0);
                emit_line("add sp, sp, #16");
            } else {
                parse_expr();
                check_assign(d_tid);
                ty_tid = d_tid;
                add_local(@d_name, 0, d_width, ssize[d_sidx], 0);
                ins_n("add x3, x29, #", loff[lcount - 1]);
                ins_n("mov x2, ", ssize[d_sidx]);
                emit_line("bl j2k_copy");
            }
            expect(";");
            return;
        }
        expect(";");
        ty_tid = d_tid;
        add_local(@d_name, 0, d_width, ssize[d_sidx], 0);
        if struct_has_init(d_sidx) {
            ins_n("add x0, x29, #", loff[lcount - 1]);
            emit_init_call(d_sidx);
        }
        return;
    }
    if tok_is("=") {
        next();
        parse_expr();
        if d_ptr == 0 { check_assign(d_tid); }
        int d_own = 0;
        if d_ptr != 0 && last_call_owning == 1 && own_ok == 1 { d_own = 1; }     // the variable owns what alloc gave
        expect(";");
        ty_tid = d_tid;
        add_local(@d_name, 0, d_width, 8, d_ptr);
        lookup_var(@d_name);
        store_scalar();
        if d_own == 1 { own_add(v_off, 0); }
        return;
    }
    expect(";");
    ty_tid = d_tid;
    add_local(@d_name, 0, d_width, 8, d_ptr);
}

void parse_statement() {
    if tok_is("{") {
        parse_block();
        return;
    }
    if tok_is("if") {
        parse_if();
        return;
    }
    if tok_is("while") {
        parse_while();
        return;
    }
    if tok_is("for") {
        parse_for();
        return;
    }
    if tok_is("switch") {
        parse_switch();
        return;
    }
    if tok_is("using") {
        parse_using();
        return;
    }
    if tok_is("cout") || tok_is("coutf") {
        parse_cout();
        return;
    }
    if tok_is("break") {
        next();
        expect(";");
        if loop_depth == 0 { die("break outside a loop"); }
        leave_tries(try_depth - loop_try[loop_depth - 1]);
        own_free_from(loop_own[loop_depth - 1], 0);
        jump(brk_stack[loop_depth - 1]);
        return;
    }
    if tok_is("continue") {
        next();
        expect(";");
        if loop_depth == 0 { die("continue outside a loop"); }
        leave_tries(try_depth - loop_try[loop_depth - 1]);
        own_free_from(loop_own[loop_depth - 1], 0);
        jump(cont_stack[loop_depth - 1]);
        return;
    }
    if tok_is("return") {
        next();
        int ret_mv = 0 - 1;
        if tok_is(";") {
            next();
            if cur_is_main == 1 { emit_line("mov x0, 0"); }
        } else {
            parse_expr();
            check_assign(cur_ret_tid);
            if rv_valid == 1 && cur_ret_isptr == 1 { ret_mv = own_find(rv_off); }
            if cur_ret_tid >= 100 {
                ins_mem("ldr", "x3", "x29", cur_ret_off);
                ins_n("mov x2, ", ssize[cur_ret_tid - 100]);
                emit_line("bl j2k_copy");
            }
            expect(";");
        }
        leave_tries(try_depth);
        if ret_mv >= 0 && cur_fidx >= 0 { fowned[cur_fidx] = 1; }     // this function hands memory out
        if own_count > 0 {
            push_x0();                   // keep the result while the owned memory is given back
            if ret_mv >= 0 { emit_owner_null(ret_mv); }
            own_free_from(0, 0);
            emit_line("ldr x0, [sp, #0]");
            emit_line("add sp, sp, #16");
        }
        jump(ret_label);
        return;
    }
    if tok_is("try") {
        parse_try();
        return;
    }
    if tok_is("throw") {
        parse_throw();
        return;
    }
    if at_type() {
        parse_local_decl();
        return;
    }
    if tok_kind != T_IDENT { die("a statement was expected"); }
    char s_name[256];
    str_copy(@s_name, @tok_text, 256);
    str_copy(@id_name, @tok_text, 256);
    next();
    if tok_is("(") && !(lookup_var(@s_name) && v_tid < 0 && v_kind != 2) {   // a call used as a statement
        resolve_callee();
        gen_call();
        if last_call_owning == 1 { warn("the memory returned here is not kept, so it can never be freed", "leak"); }
        expect(";");
        return;
    }
    if tok_is("::") {                    // Struct::function(...);
        gen_scope();
        if last_call_owning == 1 { warn("the memory returned here is not kept, so it can never be freed", "leak"); }
        expect(";");
        return;
    }
    if !lookup_var(@s_name) { die_name("unknown name", @s_name); }
    parse_assign(@s_name);
}

// ------------------------------------------------------------- top level

// a function: the type was read, the name is in d_fname, the token is "("
char d_fname[256];

// store incoming parameter number `reg` into the frame slot `off`: the first 8 arrive
// in x0..x7, the others in the overflow area of the global block (see pop_args)
void emit_param_store(int reg, int off) {
    if reg < 8 {
        emit_str("str x");
        emit_int(reg);
        emit_str(", [x29, #");
        emit_int(off);
        emit_str("]\n");
    } else {
        ins_mem("ldr", "x9", "x28", 8 + (reg - 8) * 8);
        ins_mem("str", "x9", "x29", off);
    }
}

void parse_function() {
    int f_void = ty_void;
    int f_rettid = ty_tid;
    cur_ret_isptr = 0;
    if ty_ptr != 0 || ty_dyn != 0 { cur_ret_isptr = 1; }
    if ty_ptr != 0 { f_rettid = 0; }
    cur_ret_tid = f_rettid;
    int f_idx = find_func(@d_fname);
    if f_idx < 0 {
        if fcount >= 16384 { die("too many functions"); }
        str_copy(@fname + fcount * 64, @d_fname, 64);
        farr[fcount] = 0;
        fvoid[fcount] = 0;
        if ty_void == 1 && ty_ptr == 0 { fvoid[fcount] = 1; }
        fself[fcount] = 0;
        fnpar[fcount] = 0;
        fret[fcount] = f_rettid;
        f_idx = fcount;
        fcount += 1;
    }
    int f_declared = 0;
    // pass 3: a function that main cannot reach is parsed but not emitted
    int f_skip = 0;
    int sv_out = out_len;
    int sv_gl = gl_bytes;
    int sv_ginit = ginit_count;
    int sv_fp = used_fprint;
    int sv_oob = used_oob;
    int sv_try = used_try;
    int sv_up = used_uprint;
    if pass_no == 3 && freach[f_idx] == 0 { f_skip = 1; }
    cur_fidx = f_idx;
    int f_self = fn_self_struct;
    fn_self_struct = 0 - 1;
    cp_count = 0;
    cur_in_func = 1;
    int ue_i = 0;
    while ue_i < 64 {
        ue_l[ue_i] = 0;
        us_l[ue_i] = 0;
        ue_i += 1;
    }
    lcount = 0;
    frame_bytes = 16;
    loop_depth = 0;
    try_depth = 0;
    own_count = 0;
    cur_blk = 0;
    blk_serial = 0;
    own_ok = 1;
    cur_is_main = 0;
    if str_eq(@d_fname, "main") {
        cur_is_main = 1;
        // a .j file is a component to import, not a program
        int fl = str_len(@lvl_name + lx_depth * 128);
        if fl >= 2 && lvl_name[lx_depth * 128 + fl - 1] == 'j' && lvl_name[lx_depth * 128 + fl - 2] == '.' {
            die("a .j component file cannot define main");
        }
    }
    ret_label = new_label();
    emit_str(@d_fname);
    emit_str(":\n");
    emit_str("sub sp, sp, #");
    emit_patch_digits();
    emit_nl();
    emit_line("str x29, [sp, #0]");
    emit_line("str x30, [sp, #8]");
    emit_line("add x29, sp, #0");
    expect("(");
    int nparams = 0;
    if f_rettid >= 100 {
        // a struct result is written through a hidden first parameter
        ty_tid = 0;
        add_local("..ret", 0, 8, 8, 0);
        cur_ret_off = loff[lcount - 1];
        ins_mem("str", "x0", "x29", cur_ret_off);
        nparams = 1;
    }
    if f_self >= 0 && tok_is("self") {
        ty_tid = 0;
        add_local("self", 0, 8, 8, 16 + f_self);
        emit_param_store(nparams, loff[lcount - 1]);
        fself[f_idx] = 1;
        fptid[f_idx * 8] = 0;
        nparams = nparams + 1;
        f_declared = 1;
        next();
        if tok_is(",") { next(); }
    }
    if !tok_is(")") {
        while true {
            parse_type();
            if ty_void == 1 && ty_ptr == 0 { die("a parameter cannot be void"); }
            if tok_kind != T_IDENT { die("a parameter name was expected"); }
            if nparams >= 16 { die("too many parameters (16 at most)"); }
            char p_name[256];
            str_copy(@p_name, @tok_text, 256);
            int p_tid = ty_tid;
            int p_dyn = ty_dyn;
            if ty_ptr != 0 { p_tid = 0; }
            if f_declared < 8 { fptid[f_idx * 8 + f_declared] = p_tid; }
            next();
            if tok_is("[") {
                // T name[] : an address and a length (name__len) arrive together
                next();
                expect("]");
                if nparams >= 15 { die("too many parameters (16 at most)"); }
                ty_tid = 0;
                add_local(@p_name, 0, 8, 8, ty_elem);
                emit_param_store(nparams, loff[lcount - 1]);
                char p_len[256];
                str_copy(@p_len, @p_name, 256);
                str_copy(@p_len + str_len(@p_name), "__len", 8);
                add_local(@p_len, 0, 8, 8, 0);
                emit_param_store(nparams + 1, loff[lcount - 1]);
                nparams += 2;
                f_declared += 1;
                farr[f_idx] = 1;
                if !tok_is(")") { die("an array parameter must be the last one"); }
                break;
            }
            if p_dyn != 0 {
                ty_tid = 99;
                ty_dyn = p_dyn;
                add_local(@p_name, 3, 8, 8, 0);
                emit_param_store(nparams, loff[lcount - 1]);
                nparams += 1;
                f_declared += 1;
                if tok_is(",") {
                    next();
                    continue;
                }
                break;
            }
            ty_tid = p_tid;
            if p_tid >= 100 && ty_ptr == 0 {
                // a struct by value: the caller passes its address, we copy it
                ty_tid = 0;
                add_local("..src", 0, 8, 8, 0);
                int p_srcoff = loff[lcount - 1];
                emit_param_store(nparams, p_srcoff);
                ty_tid = p_tid;
                add_local(@p_name, 0, ty_width, ssize[p_tid - 100], 0);
                if cp_count >= 8 { die("too many struct parameters"); }
                if ssize[p_tid - 100] > 64 && pass_no >= 2 {
                    char bmsg[300];
                    str_copy(@bmsg, "passing '", 300);
                    append_text(@bmsg, @sname + (p_tid - 100) * 64);
                    append_text(@bmsg, "' (");
                    append_int(@bmsg, ssize[p_tid - 100]);
                    append_text(@bmsg, " bytes) by value; consider a pointer to avoid the copy");
                    warn(@bmsg, "large-by-value");
                }
                cp_src[cp_count] = p_srcoff;
                cp_dst[cp_count] = loff[lcount - 1];
                cp_size[cp_count] = ssize[p_tid - 100];
                cp_count += 1;
                nparams += 1;
                f_declared += 1;
                if tok_is(",") {
                    next();
                    continue;
                }
                break;
            }
            add_local(@p_name, 0, ty_width, 8, ty_ptr);
            emit_param_store(nparams, loff[lcount - 1]);
            nparams += 1;
            f_declared += 1;
            if tok_is(",") {
                next();
            } else {
                break;
            }
        }
    }
    expect(")");
    fnpar[f_idx] = f_declared;
    scope_base = 0;
    body_pending = 1;
    int cp_i = 0;
    while cp_i < cp_count {
        ins_mem("ldr", "x0", "x29", cp_src[cp_i]);
        ins_n("add x3, x29, #", cp_dst[cp_i]);
        ins_n("mov x2, ", cp_size[cp_i]);
        emit_line("bl j2k_copy");
        cp_i += 1;
    }
    parse_block();
    patch_b = 0;
    cur_in_func = 0;
    if cur_is_main == 1 {
        emit_line("mov x0, 0");
        place_label(ret_label);
        if opt_debug == 1 {
            push_x0();                   // the exit code
            rt_call("Mem__report");
            emit_line("ldr x0, [sp, #0]");
            emit_line("add sp, sp, #16");
        }
        emit_line("mov x8, 93");
        emit_line("svc 0");
    } else {
        place_label(ret_label);
        emit_line("ldr x29, [sp, #0]");
        emit_line("ldr x30, [sp, #8]");
        emit_str("add sp, sp, #");
        patch_b = out_len;
        emit_str("0000000");
        emit_nl();
        emit_line("ret");
    }
    int frame = (frame_bytes + 15) / 16 * 16;
    patch_number(patch_a, frame);
    if patch_b != 0 { patch_number(patch_b, frame); }
    cur_fidx = 0 - 1;
    if f_skip == 1 {
        out_len = sv_out;
        gl_bytes = sv_gl;
        ginit_count = sv_ginit;
        used_fprint = sv_fp;
        used_oob = sv_oob;
        used_try = sv_try;
        used_uprint = sv_up;
    }
    f_void = f_void + 0;
}

// a global: TYPE name; / TYPE name = literal; / TYPE name[N];
void parse_global(char^ name) {
    int g_elem = ty_elem;
    int g_width = ty_width;
    int g_ptr = ty_ptr;
    int g_tid = ty_tid;
    int g_dyn = ty_dyn;
    if tok_is("[") {
        int g_count = parse_dims();
        int g_nd = dim_nd;
        int g_s1 = dim_s1;
        int g_s2 = dim_s2;
        int g_str = 0;
        if tok_is("=") {
            next();
            if tok_kind != T_STR { die("a string was expected"); }
            if size_of(g_elem) != 1 { die("only a char array can start from a string"); }
            if g_nd != 1 { die("only a one-dimensional array can start from a string"); }
            g_str = 1;
            if g_count < 0 { g_count = tok_str_len + 1; }
            if tok_str_len + 1 > g_count { die("the string does not fit in the array"); }
        } else {
            if g_count < 0 { die("an array size (a number) was expected"); }
            expect(";");
        }
        ty_tid = g_tid;
        add_global(name, 1, g_elem, g_count * size_of(g_elem), g_ptr);
        gnd[gcount - 1] = g_nd;
        gst1[gcount - 1] = g_s1;
        gst2[gcount - 1] = g_s2;
        if g_elem >= 16 && g_str == 0 && pass_no >= 2 && struct_has_init(g_elem - 16) {
            if gsi_count >= 4096 { die("too many global structs with init()"); }
            gsi_off[gsi_count] = goff[gcount - 1];
            gsi_s[gsi_count] = g_elem - 16;
            gsi_n[gsi_count] = g_count;
            gsi_count += 1;
        }
        if g_str == 1 {
            int g_w = 0;
            while g_w * 8 < g_count {
                int g_chunk = str_chunk(g_w * 8);
                if g_chunk != 0 { add_ginit(goff[gcount - 1] + g_w * 8, g_chunk); }
                g_w += 1;
            }
            next();
            expect(";");
        }
        return;
    }
    if g_dyn != 0 {
        // a global dynamic array starts as null
        ty_tid = 99;
        ty_dyn = g_dyn;
        add_global(name, 3, 8, 8, 0);
        expect(";");
        return;
    }
    ty_tid = g_tid;
    if g_width >= 16 && g_ptr == 0 {
        // a global struct (init() runs at startup)
        warn_static_only(g_width - 16);
        add_global(name, 0, g_width, ssize[g_width - 16], 0);
        if pass_no >= 2 && struct_has_init(g_width - 16) {
            if gsi_count >= 4096 { die("too many global structs with init()"); }
            gsi_off[gsi_count] = goff[gcount - 1];
            gsi_s[gsi_count] = g_width - 16;
            gsi_n[gsi_count] = 1;
            gsi_count += 1;
        }
        expect(";");
        return;
    }
    add_global(name, 0, g_width, 8, g_ptr);
    if tok_is("=") {
        next();
        int value = parse_const();
        if cf_flag == 1 {
            if g_tid != 90 && g_tid != 91 { die("a float constant needs a f32 or f64 variable"); }
            if gfi_count >= 4096 { die("too many global float initializers"); }
            if pass_no >= 2 {
                gfi_off[gfi_count] = goff[gcount - 1];
                gfi_mant[gfi_count] = cf_mant;
                gfi_exp[gfi_count] = cf_exp;
                gfi_neg[gfi_count] = cf_neg;
                gfi_f32[gfi_count] = 0;
                if g_tid == 90 { gfi_f32[gfi_count] = 1; }
                gfi_count += 1;
            }
            expect(";");
            return;
        }
        if g_ptr == 0 { check_assign(g_tid); }
        if g_width == 2 || g_width == 11 { value = value & 255; }
        if g_width == 12 { value = value & 4294967295; }
        if g_width == 1 { value = (value & 255) xor 128; value = value - 128; }
        if g_width == 4 { value = (value & 4294967295) xor 2147483648; value = value - 2147483648; }
        if value != 0 { add_ginit(goff[gcount - 1], value); }
    }
    expect(";");
}

// struct Name { TYPE field; TYPE field[N]; [static] RET method([self,] params) { ... } }
void parse_struct() {
    next();                              // "struct"
    if tok_kind != T_IDENT { die("a struct name was expected"); }
    int sd = find_struct(@tok_text);
    if pass_no == 1 {
        if sd >= 0 { die_name("this struct already exists", @tok_text); }
        if scount >= 64 { die("too many structs"); }
        sd = scount;
        str_copy(@sname + sd * 64, @tok_text, 64);
        sfirst[sd] = fldcount;
        snf[sd] = 0;
        ssize[sd] = 8;
        scount += 1;
    }
    if sd < 0 { die("internal: struct not registered"); }
    next();
    expect("{");
    int off = 0;
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected"); }
        int is_static = 0;
        if tok_is("static") {
            is_static = 1;
            next();
        }
        parse_type();
        if tok_kind != T_IDENT { die("a field or method name was expected"); }
        char m_name[256];
        str_copy(@m_name, @tok_text, 256);
        int f_code = ty_elem;
        int f_wid = ty_width;
        int f_ptr = ty_ptr;
        int f_tid = ty_tid;
        int f_dynf = ty_dyn;
        next();
        if tok_is("(") {
            str_copy(@d_fname, @sname + sd * 64, 64);
            str_copy(@d_fname + str_len(@d_fname), "__", 4);
            str_copy(@d_fname + str_len(@d_fname), @m_name, 100);
            fn_self_struct = sd;
            if is_static == 1 { fn_self_struct = 0 - 1; }
            parse_function();
            continue;
        }
        int f_kind = 0;
        int f_count = 1;
        int f_nd = 1;
        int f_s1 = 0;
        int f_s2 = 0;
        int f_store = f_wid;
        if f_tid == 1 && f_ptr == 0 { f_store = 3; }       // a bool field takes one byte
        if tok_is("[") {
            f_kind = 1;
            f_count = parse_dims();
            if f_count < 0 { die("a field array needs a size"); }
            f_nd = dim_nd;
            f_s1 = dim_s1;
            f_s2 = dim_s2;
            f_store = f_code;
        }
        expect(";");
        if pass_no == 1 {
            if fldcount >= 8192 { die("too many struct fields"); }
            int f_size = size_of(f_store);
            int f_align = f_size;
            if f_store >= 16 || f_align > 8 { f_align = 8; }
            if f_ptr != 0 && f_kind == 0 { f_size = 8; f_align = 8; f_store = 8; }
            off = (off + f_align - 1) / f_align * f_align;
            int fx = fldcount;
            str_copy(@fldname + fx * 64, @m_name, 64);
            fldcode[fx] = f_store;
            if f_kind == 0 && f_ptr == 0 && f_wid == 8 { fldcode[fx] = 8; }
            fldoff[fx] = off;
            fldkind[fx] = f_kind;
            fldptr[fx] = f_ptr;
            fldtid[fx] = f_tid;
            if f_ptr != 0 { fldtid[fx] = 0; }
            fldnd[fx] = f_nd;
            fldst1[fx] = f_s1;
            fldst2[fx] = f_s2;
            fldcnt[fx] = f_count;
            flddyn[fx] = f_dynf;
            if f_dynf != 0 {
                fldkind[fx] = 3;
                fldcode[fx] = 8;
                fldtid[fx] = 99;
                fldptr[fx] = 0;
            }
            off += f_size * f_count;
            fldcount += 1;
            snf[sd] += 1;
        }
    }
    expect("}");
    accept(";");
    if pass_no == 1 { ssize[sd] = (off + 7) / 8 * 8; }
    if pass_no == 1 && ssize[sd] == 0 { ssize[sd] = 8; }
}

void parse_top_item() {
    parse_type();
    if tok_kind != T_IDENT { die("a name was expected"); }
    str_copy(@d_fname, @tok_text, 256);
    next();
    if tok_is("(") {
        parse_function();
        return;
    }
    if ty_void == 1 && ty_ptr == 0 { die("a variable cannot be void"); }
    parse_global(@d_fname);
}

void parse_program() {
    while tok_kind != T_EOF {
        if tok_is("import") {
            lex_import();
        } else if tok_is("enum") {
            parse_enum();
        } else if tok_is("struct") {
            parse_struct();
        } else if tok_is("using") {
            parse_using();
        } else {
            parse_top_item();
        }
    }
}

// the entry point: sets x28 (the global area), keeps the initial sp (argc /
// argv live there), stores the global initial values, then runs main
void emit_start_stub() {
    emit_line("j2k_start:");
    emit_line("mov x28, 268435456");
    emit_line("add x9, sp, #0");
    emit_line("str x9, [x28, #0]");
    int i = 0;
    while i < ginit_count {
        ins_n("mov x9, ", ginit_val[i]);
        ins_mem("str", "x9", "x28", ginit_off[i]);
        i += 1;
    }
    int gf_k = 0;
    while gf_k < gfi_count {
        ins_n("mov x0, ", gfi_mant[gf_k]);
        emit_line("scvtf d0, x0");
        if gfi_exp[gf_k] != 0 {
            int gf_p = 1;
            int gf_i = 0;
            int gf_e = gfi_exp[gf_k];
            if gf_e < 0 { gf_e = 0 - gf_e; }
            while gf_i < gf_e {
                gf_p = gf_p * 10;
                gf_i += 1;
            }
            ins_n("mov x1, ", gf_p);
            emit_line("scvtf d1, x1");
            if gfi_exp[gf_k] < 0 {
                emit_line("fdiv d0, d0, d1");
            } else {
                emit_line("fmul d0, d0, d1");
            }
        }
        if gfi_neg[gf_k] == 1 { emit_line("fneg d0, d0"); }
        if gfi_f32[gf_k] == 1 {
            emit_line("fcvt s0, d0");
            emit_line("fmov w0, s0");
        } else {
            emit_line("fmov x0, d0");
        }
        ins_mem("str", "x0", "x28", gfi_off[gf_k]);
        gf_k += 1;
    }
    int gi_k = 0;
    while gi_k < gsi_count {
        int gi_n = 0;
        while gi_n < gsi_n[gi_k] {
            ins_n("add x0, x28, #", gsi_off[gi_k] + gi_n * ssize[gsi_s[gi_k]]);
            emit_str("bl ");
            emit_str(@sname + gsi_s[gi_k] * 64);
            emit_line("__init");
            gi_n += 1;
        }
        gi_k += 1;
    }
    emit_line("b main");
    emit_str(".bss ");
    emit_int(gl_bytes);
    emit_nl();
}

// the output routines that cout uses (always emitted; they only touch x0-x8)
void emit_print_helpers() {
    emit_line("j2k_print_int:");
    emit_line("sub sp, sp, #48");
    emit_line("mov x1, 0");
    emit_line("cmp x0, 0");
    emit_line("b.ge j2k_pi1");
    emit_line("mov x2, 0");
    emit_line("sub x0, x2, x0");
    emit_line("mov x1, 1");
    emit_line("j2k_pi1:");
    emit_line("mov x3, 40");
    emit_line("mov x4, 10");
    emit_line("j2k_pi2:");
    emit_line("udiv x5, x0, x4");
    emit_line("mul x6, x5, x4");
    emit_line("sub x6, x0, x6");
    emit_line("add x6, x6, #48");
    emit_line("sub x3, x3, #1");
    emit_line("add x7, sp, #0");
    emit_line("add x7, x7, x3");
    emit_line("strb x6, [x7, #0]");
    emit_line("mov x0, x5");
    emit_line("cmp x0, 0");
    emit_line("b.ne j2k_pi2");
    emit_line("cmp x1, 0");
    emit_line("b.eq j2k_pi3");
    emit_line("sub x3, x3, #1");
    emit_line("add x7, sp, #0");
    emit_line("add x7, x7, x3");
    emit_line("mov x6, 45");
    emit_line("strb x6, [x7, #0]");
    emit_line("j2k_pi3:");
    emit_line("mov x2, 40");
    emit_line("sub x2, x2, x3");
    emit_line("add x1, sp, #0");
    emit_line("add x1, x1, x3");
    emit_line("mov x0, 1");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("add sp, sp, #48");
    emit_line("ret");
    emit_line("j2k_print_str:");
    emit_line("mov x1, x0");
    emit_line("mov x2, 0");
    emit_line("j2k_ps1:");
    emit_line("add x3, x1, x2");
    emit_line("ldrb x4, [x3, #0]");
    emit_line("cmp x4, 0");
    emit_line("b.eq j2k_ps2");
    emit_line("add x2, x2, #1");
    emit_line("b j2k_ps1");
    emit_line("j2k_ps2:");
    emit_line("mov x0, 1");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("ret");
    emit_line("j2k_print_char:");
    emit_line("sub sp, sp, #16");
    emit_line("strb x0, [sp, #0]");
    emit_line("add x1, sp, #0");
    emit_line("mov x0, 1");
    emit_line("mov x2, 1");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("add sp, sp, #16");
    emit_line("ret");
}

// printing floats (only emitted when the program uses coutf: it needs the FP instructions)
void emit_fprint_helper() {
    emit_line("j2k_print_f64:");
    emit_line("sub sp, sp, #48");
    emit_line("str x30, [sp, #0]");
    emit_line("mov x1, 52");
    emit_line("lsr x2, x0, x1");
    emit_line("mov x3, 2047");
    emit_line("and x2, x2, x3");
    emit_line("cmp x2, x3");
    emit_line("b.ne j2k_pf_num");
    emit_line("mov x4, 4503599627370495");
    emit_line("and x4, x0, x4");
    emit_line("cmp x4, 0");
    emit_line("b.ne j2k_pf_nan");
    emit_line("mov x1, 63");
    emit_line("lsr x1, x0, x1");
    emit_line("cmp x1, 0");
    emit_line("b.eq j2k_pf_inf1");
    emit_line("mov x0, 45");
    emit_line("bl j2k_print_char");
    emit_line("j2k_pf_inf1:");
    emit_line("mov x0, 105");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 110");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 102");
    emit_line("bl j2k_print_char");
    emit_line("b j2k_pf_done");
    emit_line("j2k_pf_nan:");
    emit_line("mov x0, 110");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 97");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 110");
    emit_line("bl j2k_print_char");
    emit_line("b j2k_pf_done");
    emit_line("j2k_pf_num:");
    emit_line("mov x1, 63");
    emit_line("lsr x1, x0, x1");
    emit_line("cmp x1, 0");
    emit_line("b.eq j2k_pf_pos");
    emit_line("mov x5, 9223372036854775807");
    emit_line("and x0, x0, x5");
    emit_line("str x0, [sp, #8]");
    emit_line("mov x0, 45");
    emit_line("bl j2k_print_char");
    emit_line("ldr x0, [sp, #8]");
    emit_line("j2k_pf_pos:");
    emit_line("fmov d0, x0");
    emit_line("mov x1, 4890909195324358656");
    emit_line("fmov d1, x1");
    emit_line("fcmp d0, d1");
    emit_line("b.ge j2k_pf_big");
    emit_line("fcvtzs x1, d0");
    emit_line("scvtf d1, x1");
    emit_line("fsub d2, d0, d1");
    emit_line("mov x2, 1000000");
    emit_line("scvtf d3, x2");
    emit_line("fmul d2, d2, d3");
    emit_line("mov x3, 4602678819172646912");
    emit_line("fmov d4, x3");
    emit_line("fadd d2, d2, d4");
    emit_line("fcvtzs x2, d2");
    emit_line("mov x3, 1000000");
    emit_line("cmp x2, x3");
    emit_line("b.lt j2k_pf_nocarry");
    emit_line("sub x2, x2, x3");
    emit_line("add x1, x1, #1");
    emit_line("j2k_pf_nocarry:");
    emit_line("str x2, [sp, #16]");
    emit_line("mov x0, x1");
    emit_line("bl j2k_print_int");
    emit_line("mov x0, 46");
    emit_line("bl j2k_print_char");
    emit_line("mov x3, 100000");
    emit_line("str x3, [sp, #24]");
    emit_line("j2k_pf_loop:");
    emit_line("ldr x2, [sp, #16]");
    emit_line("ldr x3, [sp, #24]");
    emit_line("udiv x4, x2, x3");
    emit_line("mul x5, x4, x3");
    emit_line("sub x2, x2, x5");
    emit_line("str x2, [sp, #16]");
    emit_line("add x0, x4, #48");
    emit_line("bl j2k_print_char");
    emit_line("ldr x3, [sp, #24]");
    emit_line("mov x4, 10");
    emit_line("udiv x3, x3, x4");
    emit_line("str x3, [sp, #24]");
    emit_line("cmp x3, 0");
    emit_line("b.ne j2k_pf_loop");
    emit_line("b j2k_pf_done");
    emit_line("j2k_pf_big:");
    emit_line("mov x1, 4895412794951729152");
    emit_line("fmov d1, x1");
    emit_line("fcmp d0, d1");
    emit_line("b.ge j2k_pf_huge");
    emit_line("fcvtzu x0, d0");
    emit_line("bl j2k_print_uint");
    emit_line("mov x0, 46");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 48");
    emit_line("bl j2k_print_char");
    emit_line("b j2k_pf_done");
    emit_line("j2k_pf_huge:");
    emit_line("mov x0, 98");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 105");
    emit_line("bl j2k_print_char");
    emit_line("mov x0, 103");
    emit_line("bl j2k_print_char");
    emit_line("j2k_pf_done:");
    emit_line("ldr x30, [sp, #0]");
    emit_line("add sp, sp, #48");
    emit_line("ret");
}

// text of the bounds error, written before the size
char oob_text[64];
int oob_len;

// store `text` (len bytes) at the stack pointer, 8 bytes at a time
void emit_text_chunks(char^ text, int len) {
    int k = 0;
    while k * 8 < len {
        int chunk = 0;
        int b = 7;
        while b >= 0 {
            chunk = chunk * 256;
            if k * 8 + b < len { chunk = chunk + text[k * 8 + b]; }
            b -= 1;
        }
        ins_n("mov x3, ", chunk);
        ins_mem("str", "x3", "sp", k * 8);
        k += 1;
    }
}

void emit_oob_chunks() {
    emit_text_chunks(@oob_text, oob_len);
}

// -d : the routine that reports an index out of range (x1 = the array size)
void emit_oob_helper() {
    str_copy(@oob_text, "runtime error: index out of bounds, array size is ", 64);
    oob_len = str_len(@oob_text);
    emit_line("j2k_oob:");
    emit_line("sub sp, sp, #160");
    emit_line("mov x6, x1");
    // the message text, 8 bytes at a time
    emit_oob_chunks();
    emit_line("mov x0, 2");
    emit_line("add x1, sp, #0");
    emit_str("mov x2, ");
    emit_int(oob_len);
    emit_nl();
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x3, 127");
    emit_line("mov x4, 10");
    emit_line("add x7, sp, #0");
    emit_line("add x7, x7, x3");
    emit_line("strb x4, [x7, #0]");
    emit_line("mov x0, x6");
    emit_line("j2k_oob1:");
    emit_line("sub x3, x3, #1");
    emit_line("udiv x1, x0, x4");
    emit_line("mul x2, x1, x4");
    emit_line("sub x2, x0, x2");
    emit_line("add x2, x2, #48");
    emit_line("add x7, sp, #0");
    emit_line("add x7, x7, x3");
    emit_line("strb x2, [x7, #0]");
    emit_line("mov x0, x1");
    emit_line("cmp x0, 0");
    emit_line("b.ne j2k_oob1");
    emit_line("mov x2, 128");
    emit_line("sub x2, x2, x3");
    emit_line("add x1, sp, #0");
    emit_line("add x1, x1, x3");
    emit_line("mov x0, 2");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x0, 134");
    emit_line("mov x8, 93");
    emit_line("svc 0");
}

char exc_text[64];
int exc_len;

// try / throw: handler records live in the global block (depth at 80, thrown text at 72,
// records of 3 words from 88); a throw restores sp and x29 of the try and returns again
// to the instruction after its `bl j2k_try_enter`, now with x0 = 1
void emit_exc_helper() {
    str_copy(@exc_text, "uncaught exception: ", 64);
    exc_len = str_len(@exc_text);
    emit_line("j2k_try_enter:");
    emit_line("ldr x1, [x28, #80]");
    emit_line("cmp x1, 32");
    emit_line("b.ge j2k_exc_full");
    emit_line("mov x2, 24");
    emit_line("mul x2, x1, x2");
    emit_line("add x3, x28, #0");
    emit_line("add x3, x3, x2");
    emit_line("add x4, sp, #0");
    emit_line("str x4, [x3, #88]");
    emit_line("str x29, [x3, #96]");
    emit_line("str x30, [x3, #104]");
    emit_line("add x1, x1, #1");
    emit_line("str x1, [x28, #80]");
    emit_line("mov x0, 0");
    emit_line("ret");
    emit_line("j2k_exc_full:");
    emit_line("mov x0, 2");
    emit_line("mov x8, 93");
    emit_line("svc 0");
    emit_line("j2k_try_leave:");
    emit_line("ldr x1, [x28, #80]");
    emit_line("sub x1, x1, #1");
    emit_line("str x1, [x28, #80]");
    emit_line("ret");
    emit_line("j2k_throw:");
    emit_line("str x0, [x28, #72]");
    emit_line("ldr x1, [x28, #80]");
    emit_line("cmp x1, 0");
    emit_line("b.eq j2k_uncaught");
    emit_line("sub x1, x1, #1");
    emit_line("str x1, [x28, #80]");
    emit_line("mov x2, 24");
    emit_line("mul x2, x1, x2");
    emit_line("add x3, x28, #0");
    emit_line("add x3, x3, x2");
    emit_line("ldr x4, [x3, #88]");
    emit_line("ldr x29, [x3, #96]");
    emit_line("ldr x30, [x3, #104]");
    emit_line("add sp, x4, #0");
    emit_line("mov x0, 1");
    emit_line("ret");
    emit_line("j2k_uncaught:");
    emit_line("mov x6, x0");
    emit_line("sub sp, sp, #64");
    emit_text_chunks(@exc_text, exc_len);
    emit_line("mov x0, 2");
    emit_line("add x1, sp, #0");
    emit_str("mov x2, ");
    emit_int(exc_len);
    emit_nl();
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x2, 0");
    emit_line("j2k_unc1:");
    emit_line("add x3, x6, x2");
    emit_line("ldrb x4, [x3, #0]");
    emit_line("cmp x4, 0");
    emit_line("b.eq j2k_unc2");
    emit_line("add x2, x2, #1");
    emit_line("b j2k_unc1");
    emit_line("j2k_unc2:");
    emit_line("mov x0, 2");
    emit_line("mov x1, x6");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x4, 10");
    emit_line("strb x4, [sp, #0]");
    emit_line("mov x0, 2");
    emit_line("add x1, sp, #0");
    emit_line("mov x2, 1");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x0, 1");
    emit_line("mov x8, 93");
    emit_line("svc 0");
}

// printing an unsigned 64-bit number (only emitted when needed)
void emit_uprint_helper() {
    emit_line("j2k_print_uint:");
    emit_line("sub sp, sp, #48");
    emit_line("mov x3, 40");
    emit_line("mov x4, 10");
    emit_line("j2k_pu1:");
    emit_line("udiv x5, x0, x4");
    emit_line("mul x6, x5, x4");
    emit_line("sub x6, x0, x6");
    emit_line("add x6, x6, #48");
    emit_line("sub x3, x3, #1");
    emit_line("add x7, sp, #0");
    emit_line("add x7, x7, x3");
    emit_line("strb x6, [x7, #0]");
    emit_line("mov x0, x5");
    emit_line("cmp x0, 0");
    emit_line("b.ne j2k_pu1");
    emit_line("mov x2, 40");
    emit_line("sub x2, x2, x3");
    emit_line("add x1, sp, #0");
    emit_line("add x1, x1, x3");
    emit_line("mov x0, 1");
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("add sp, sp, #48");
    emit_line("ret");
}

// the struct copy routine: x0 = from, x3 = to, x2 = bytes (a multiple of 8)
void emit_copy_helper() {
    emit_line("j2k_copy:");
    emit_line("cmp x2, 0");
    emit_line("b.eq j2k_cp2");
    emit_line("j2k_cp1:");
    emit_line("ldr x4, [x0, #0]");
    emit_line("str x4, [x3, #0]");
    emit_line("add x0, x0, #8");
    emit_line("add x3, x3, #8");
    emit_line("sub x2, x2, #8");
    emit_line("cmp x2, 0");
    emit_line("b.ne j2k_cp1");
    emit_line("j2k_cp2:");
    emit_line("ret");
}
