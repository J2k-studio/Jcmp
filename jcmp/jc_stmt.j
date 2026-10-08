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
int xp_pos[8];               // places in the output where the offset of an argument 9.. is patched in
int xp_reg[8];
int xp_count;
int cp_src[8];               // struct parameters to copy in the prologue
int cp_dst[8];
int cp_size[8];
int cp_sidx[8];
int cp_count;
int fn_returns;              // 1 once the function has a return with a value or a throw
int fn_line;
int fn_col;
int fn_base;
int fn_ls;
int cur_ret_str;             // 1 if the function returns a String
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

// `vec NAME = { a, b, c };` : the number of values in the braces (the current token is `vec`, nothing after it is read yet).
// -1 if the text is not of that shape
int vec_count_ahead() {
    int o = 0;
    while is_space(lc(o)) { o += 1; }
    if !is_letter(lc(o)) { return -1; }
    while is_letter(lc(o)) || is_digit(lc(o)) || lc(o) == '_' { o += 1; }
    while is_space(lc(o)) { o += 1; }
    if lc(o) != '=' { return -1; }
    o += 1;
    while is_space(lc(o)) { o += 1; }
    if lc(o) != '{' { return -1; }
    return count_values_from(o + 1);
}

// the number of values in { a, b, c } : o is the offset just after the {  (-1 if it never closes)
int count_values_from(int o) {
    int depth = 0;
    int n = 0;
    int any = 0;
    while lc(o) != 0 {
        int c = lc(o);
        if c == '"' || c == 39 {
            int q = c;
            o += 1;
            while lc(o) != 0 && lc(o) != q {
                if lc(o) == 92 { o += 1; }
                o += 1;
            }
            any = 1;
        } else if c == '(' || c == '[' || c == '{' {
            depth += 1;
            any = 1;
        } else if c == ')' || c == ']' {
            depth -= 1;
        } else if c == '}' {
            if depth == 0 {
                if any == 1 { return n + 1; }
                return 0;
            }
            depth -= 1;
        } else if c == ',' && depth == 0 {
            n += 1;
        } else if !is_space(c) {
            any = 1;
        }
        o += 1;
    }
    return -1;
}

// is the current token a type word?
bool at_type() {
    if tok_kind == T_IDENT && tok_is("vec") && find_struct("vec") < 0 && find_struct("vec3") >= 0 { return true; }
    if tok_kind == T_IDENT && find_enum(@tok_text) >= 0 { return true; }
    if tok_kind == T_IDENT && find_struct(@tok_text) >= 0 { return true; }
    if tok_kind == T_IDENT && tok_is("String") { return true; }
    return tok_is("int") || tok_is("char") || tok_is("bool") || tok_is("void") || tok_is("i8") || tok_is("i32") || tok_is("float") || tok_is("double") || tok_is("f32") || tok_is("f64") || tok_is("u8") || tok_is("u32") || tok_is("u64");
}

// TYPE [^] ; sets the ty_* variables and leaves the token after the type
// f32 / f64 were the first names of float / double: still accepted, with one warning per program
int using_warned;
int old_float_warned;
int using_std_seen;          // 1 after `using std` (the whole module) at the top level
int io_warned;
void old_float_name() {
    if old_float_warned == 1 { return; }
    old_float_warned = 1;
    warn("'f32' and 'f64' are now called 'float' and 'double'", "deprecated");
}

// coutf and cinf were the first names for printing / reading floats: cout and cin do it now (one warning per program)
int io_float_warned;
void io_float_name() {
    if io_float_warned == 1 { return; }
    io_float_warned = 1;
    warn("coutf and cinf are not needed: cout and cin print and read floats too", "deprecated");
}

// cout, coutf, cin and cinf need `import std` and `using std`: for now a warning, later an error
void check_io_std() {
    if io_warned == 1 || (std_loaded == 1 && using_std_seen == 1) { return; }
    io_warned = 1;
    warn("cout, coutf, cin and cinf need 'import <stdlib>' and 'using stdlib' at the top of the file (this will become an error)", "std");
}

void parse_type() {
    ty_void = 0;
    ty_ptr = 0;
    ty_tid = 0;
    ty_dyn = 0;
    if tok_kind == T_IDENT && tok_is("vec") && find_struct("vec") < 0 && find_struct("vec3") >= 0 {
        // vec pos = { 1.0, 2.0, 3.0 };  the number of values says which one: vec2, vec3 or vec4
        int vn = vec_count_ahead();
        if vn < 2 || vn > 4 { die("vec needs its values in { } (2 to 4 of them): vec pos = {1.0, 2.0, 3.0};  elsewhere write vec2, vec3 or vec4"); }
        tok_text[3] = '0' + vn;
        tok_text[4] = 0;
    }
    if tok_kind == T_IDENT && tok_is("String") && find_struct(@tok_text) < 0 {
        // String: a dynamic array of char marked with the type id 70 (see is_str_dyn)
        next();
        ty_dyn = dyn_pack(2, 0, 70);
        if tok_is("[") {
            // String[] : an array of Strings (the array owns them)
            next();
            expect("]");
            ty_dyn = dyn_pack(8, 0, 71);
        }
        ty_tid = 99;
        ty_elem = 8;
        ty_width = 8;
        return;
    }
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
    } else if tok_is("float") || tok_is("f32") {
        if tok_is("f32") { old_float_name(); }
        ty_elem = 6;
        ty_width = 6;
        ty_tid = 90;
    } else if tok_is("double") || tok_is("f64") {
        if tok_is("f64") { old_float_name(); }
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
            ty_ptr = 400 + ty_ptr;
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
// a scalar that was declared without a value and has not been written yet is read
void uninit_read(int li) {
    if li < 0 || luninit[li] == 0 || lunloop[li] != loop_depth { return; }
    luninit[li] = 0;
    char m[200];
    str_copy(@m, "'", 200);
    append_text(@m, @lname + li * 64);
    append_text(@m, "' is read before it is given a value");
    warn(@m, "uninit");
}

void uninit_clear(char^ name) {
    int li = find_local(name);
    if li >= 0 { luninit[li] = 0; }
}

void parse_assign(char^ target) {
    int li = find_local(target);
    if li >= 0 && luninit[li] == 1 && tok_is("=") {
        parse_assign_core(target);       // the right side is read first: x = x + 1 warns
        luninit[li] = 0;
        return;
    }
    parse_assign_core(target);
}

void parse_assign_core(char^ target) {
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
    if lv_swz == 1 { die("a swizzle with several components can only be read (assign the parts one by one: v.x = ...)"); }
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
    // the target's address waits on the stack; but a plain variable has a fixed address that can be written again at the end
    int tgt_off = 0 - 1;
    int tgt_base = 29;
    if a_kind == 0 && a_code < 16 {
        int tn = tail_add_base();
        if tn >= 0 {
            tgt_off = tn;
            tgt_base = tail_base;
            out_len = tail_start;
        }
    }
    int tgt_reg = 0;
    if tgt_off < 0 && a_kind == 0 && a_code < 16 && stash_depth < 5 && pure_raw_ahead(100) {
        // the value on the right is made of plain things (no call): the address of the target waits in a register
        tgt_reg = 10 + stash_depth;
        stash_depth += 1;
        emit_str("mov x");
        emit_int(tgt_reg);
        emit_line(", x0");
    } else if tgt_off < 0 {
        push_x0();
    }
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
        if op[0] != 0 && (op[1] != 0 || !(op[0] == '+' || op[0] == '-' || op[0] == '*' || op[0] == '/')) { die("a struct can only be assigned with = or + - * / (an operator method)"); }
        if op[0] != 0 {
            // a += b  is  a = a.add(b)
            emit_line("ldr x0, [sp, #0]");
            push_x0();                   // self
            parse_expr();
            emit_operator_call(@op, a_tid);
            emit_line("ldr x3, [sp, #0]");
            ins_n("mov x2, ", ssize[a_code - 16]);
            emit_line("bl j2k_copy");
        } else if tok_is("{") {
            parse_brace(a_code - 16, 0);
        } else {
            parse_expr();
            check_assign(a_tid);
            int how = 0;
            int src_off = 0;
            if struct_has_free(a_code - 16) {
                // the old content of the target is freed, then the new one is moved in
                how = struct_source(a_code - 16);
                src_off = own_src_off;
                push_x0();
                emit_line("ldr x0, [sp, #16]");
                char sfree[128];
                str_copy(@sfree, @sname + (a_code - 16) * 64, 64);
                append_text(@sfree, "__free");
                rt_call(@sfree);
                emit_line("ldr x0, [sp, #0]");
                emit_line("add sp, sp, #16");
            }
            emit_line("ldr x3, [sp, #0]");
            ins_n("mov x2, ", ssize[a_code - 16]);
            emit_line("bl j2k_copy");
            if how == 2 {
                emit_zero_local(src_off, ssize[a_code - 16]);
                int oi = own_find(src_off);
                if oi >= 0 && own_blk[oi] == cur_blk { own_moved[oi] = 1; }
            }
        }
        emit_line("add sp, sp, #16");
        if for_step == 0 { expect(";"); }
        return;
    }
    if a_kind == 3 && is_str_dyn(lv_dyn_saved) {
        // a String: = copies (frees the old content), += appends
        if is_incr == 1 { die("++ and -- do not work on a String"); }
        if a_fresh == 1 && a_base_local == 1 && own_find(a_base_off) < 0 && own_ok == 1 {
            die_name("this String is only borrowed (a parameter); copy it into a local String first", target);
        }
        parse_expr();
        if op[0] == 0 {
            str_adopt();
            push_x0();                   // [sp] = the new String, [sp+16] = the target's address
            emit_line("ldr x1, [sp, #16]");
            emit_line("ldr x0, [x1, #0]");
            rt_call("__Arr__free");      // the old content goes (null is ignored)
            emit_line("ldr x0, [sp, #0]");
            emit_line("ldr x3, [sp, #16]");
            emit_line("add sp, sp, #32");
            emit_line("str x0, [x3, #0]");
        } else if op[0] == '+' && op[1] == 0 {
            int kb = str_kind();
            emit_line("mov x1, x0");
            emit_line("ldr x3, [sp, #0]");
            emit_line("ldr x0, [x3, #0]");
            emit_line("add sp, sp, #16");
            ins_n("mov x2, ", kb);
            rt_call("__Str__append");
        } else {
            die("a String can be changed with = and += only");
        }
        if for_step == 0 { expect(";"); }
        if a_fresh == 1 && a_base_local == 1 && op[0] == 0 {
            int me = own_find(a_base_off);
            if me >= 0 { own_moved[me] = 0; }
        }
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
    if tgt_off >= 0 {
        emit_str("add x3, x");           // x3 = the target's address, x0 = the value
        emit_int(tgt_base);
        emit_str(", #");
        emit_int(tgt_off);
        emit_nl();
    } else if tgt_reg != 0 {
        stash_depth -= 1;
        emit_str("mov x3, x");           // x3 = the target's address, x0 = the value
        emit_int(tgt_reg);
        emit_nl();
    } else {
        emit_line("ldr x3, [sp, #0]");       // x3 = the target's address, x0 = the value
        emit_line("add sp, sp, #16");
    }
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
    warn_unused(scope_mark);
    own_free_from(own_mark, 1);          // the memory that this block owns is given back here
    own_ok = saved_ok;
    cur_blk = saved_blk;
    lcount = scope_mark;
    scope_base = saved_base;
}

// "cond {": the condition value in x0, then a jump to `lfalse` if it is 0
void parse_condition(int lfalse) {
    int t0 = own_count;
    parse_expr();
    need_bool();
    str_flush(t0, 1);                    // the Strings made by the condition are freed before the jump
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
// for x in list { ... } : the list (x0 = a dynamic array, a String or the address of a fixed array) is
// already evaluated; x is a copy of each element in turn (a String element is only borrowed)
void parse_for_each(char^ f_name, int lstart, int lbody, int lstep, int lend, int for_mark) {
    int is_dyn = 0 - 1;                  // 1 dynamic array / String, 0 fixed array
    int code = 8;
    int eptr = 0;
    int etid = 0;
    int info = 0;
    int count = 0;
    if (ex_ty == 99 || ex_ty == 80) && ex_dyn != 0 {
        is_dyn = 1;
        info = ex_dyn;
        code = dyn_code(info);
        eptr = dyn_ptr(info);
        etid = dyn_tid(info);
        if is_str_dyn(info) { etid = 0; }
    } else if ex_arr_cnt >= 0 {
        is_dyn = 0;
        count = ex_arr_cnt;
        code = ex_arr_code;
    } else if pass_no >= 2 {
        die("for x in ... needs an array, a dynamic array, a String or a range a..b");
    }
    if code >= 16 && eptr == 0 && pass_no >= 2 { die("for x in ... does not work on an array of structs (use an index)"); }
    int elem_str = 0;
    if is_strarr_dyn(info) { elem_str = 1; }
    int seq_new = 0;
    if is_dyn == 1 && last_call_owning == 1 { seq_new = 1; }     // a list made by a call: freed after the loop
    str_flush(stmt_t0, 1);               // Strings of the list expression are not needed any more
    int own_before = own_count;
    ty_tid = 0;
    add_local("..seq", 0, 8, 8, 0);
    int seq_off = loff[lcount - 1];
    ins_mem("str", "x0", "x29", seq_off);
    if seq_new == 1 {
        int sk = 1;
        if elem_str == 1 { sk = 3; }
        own_add(seq_off, sk, 0);
    }
    add_local("..idx", 0, 8, 8, 0);
    int idx_off = loff[lcount - 1];
    emit_line("mov x0, 0");
    ins_mem("str", "x0", "x29", idx_off);
    if is_dyn == 1 {
        ins_mem("ldr", "x0", "x29", seq_off);
        dyn_null_check();
    }
    // the loop variable
    ty_tid = etid;
    if eptr != 0 { ty_tid = 0; }
    int v_code = code;
    if elem_str == 1 {
        ty_tid = 99;
        ty_dyn = dyn_pack(2, 0, 70);
        add_local(f_name, 3, 8, 8, 0);
    } else {
        add_local(f_name, 0, v_code, 8, eptr);
    }
    int var_off = loff[lcount - 1];
    place_label(lstart);
    ins_mem("ldr", "x0", "x29", idx_off);
    if is_dyn == 1 {
        ins_mem("ldr", "x1", "x29", seq_off);
        emit_line("ldr x1, [x1, #0]");
    } else {
        ins_n("mov x1, ", count);
    }
    emit_line("cmp x0, x1");
    jump_if("ge", lend);
    jump(lbody);
    place_label(lstep);
    ins_mem("ldr", "x0", "x29", idx_off);
    emit_line("add x0, x0, #1");
    ins_mem("str", "x0", "x29", idx_off);
    jump(lstart);
    place_label(lbody);
    // x0 = the address of the element, then its value
    ins_mem("ldr", "x0", "x29", idx_off);
    if is_dyn == 1 {
        ins_mem("ldr", "x1", "x29", seq_off);
        emit_line("ldr x2, [x1, #16]");
        ins_n("mov x3, ", size_of(code));
        emit_line("mul x0, x0, x3");
        emit_line("add x0, x0, x2");
    } else {
        ins_mem("ldr", "x1", "x29", seq_off);
        ins_n("mov x3, ", size_of(code));
        emit_line("mul x0, x0, x3");
        emit_line("add x0, x0, x1");
    }
    load_through(code);
    ins_mem("str", "x0", "x29", var_off);
    brk_stack[loop_depth] = lend;
    cont_stack[loop_depth] = lstep;
    loop_try[loop_depth] = try_depth;
    loop_own[loop_depth] = own_count;
    loop_depth += 1;
    parse_block();
    loop_depth -= 1;
    jump(lstep);
    place_label(lend);
    if seq_new == 1 { own_free_from(own_before, 1); }
    lcount = for_mark;
}

char for_tmp[65536];           // the text of the condition of a for loop while the step is written

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
        // the layout:  init; jump to the condition; step; condition (jumps out when false); body; jump to the step.
        // One jump a turn. The condition is read before the step is, so its text is cut out and put back after the step.
        int c_start = out_len;
        parse_condition(lend);
        expect(";");
        int c_len = out_len - c_start;
        if c_len >= 65536 { die("the condition of this for loop is too long"); }
        int c_k = 0;
        while c_k < c_len {
            for_tmp[c_k] = out_buf[c_start + c_k];
            c_k += 1;
        }
        out_len = c_start;
        int lcond = new_label();
        jump(lcond);
        place_label(lstep);
        for_step = 1;
        parse_statement();
        for_step = 0;
        place_label(lcond);
        c_k = 0;
        while c_k < c_len {
            out_buf[out_len] = for_tmp[c_k];
            out_len += 1;
            c_k += 1;
        }
    } else {
        // for i in a..b : i counts a, a+1, ... b-1
        if tok_kind != T_IDENT { die("a loop variable was expected"); }
        char f_name[256];
        str_copy(@f_name, @tok_text, 256);
        next();
        expect("in");
        ex_arr_cnt = 0 - 1;
        ex_dyn = 0;
        last_call_owning = 0;
        int sv_cout = in_cout;
        in_cout = 1;                     // a whole array is allowed here
        parse_bitor();
        in_cout = sv_cout;
        if !tok_is(".") {
            parse_for_each(@f_name, lstart, lbody, lstep, lend, for_mark);
            return;
        }
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
        // the layout: jump to the condition; body; step; condition (jumps back to the body); one jump a turn
        int lcond2 = new_label();
        jump(lcond2);
        place_label(lbody);
        brk_stack[loop_depth] = lend;
        cont_stack[loop_depth] = lstep;
        loop_try[loop_depth] = try_depth;
        loop_own[loop_depth] = own_count;
        loop_depth += 1;
        parse_block();
        loop_depth -= 1;
        place_label(lstep);
        ins_mem("ldr", "x0", "x29", f_off);
        emit_line("add x0, x0, #1");
        ins_mem("str", "x0", "x29", f_off);
        place_label(lcond2);
        ins_mem("ldr", "x0", "x29", f_off);
        ins_mem("ldr", "x1", "x29", e_off);
        emit_line("cmp x0, x1");
        jump_if("lt", lbody);
        place_label(lend);
        lcount = for_mark;
        return;
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

int mt_active;               // 1 while the body of a #multithread loop is compiled
int mt_base;                 // loop_depth at its start

// #multithread  for i in a..b { body }
// The body becomes a separate routine inside this function's code ("worker"); __Mt::run starts
// several threads that each run it for a part of a..b. Variables of the enclosing function are
// reached through x26 (the enclosing frame); variables made inside the body live in the worker's frame.
void parse_mt_for() {
    if mt_active == 1 { die("#multithread loops cannot be nested"); }
    int for_mark = lcount;
    int lworker = new_label();
    int lafter = new_label();
    int lstart = new_label();
    int lstep = new_label();
    int lend = new_label();
    next();                              // "for"
    if tok_kind != T_IDENT || at_type() { die("#multithread needs a loop of the form  for i in a..b"); }
    char m_name[256];
    str_copy(@m_name, @tok_text, 256);
    next();
    if !tok_is("in") { die("#multithread needs a loop of the form  for i in a..b"); }
    next();
    // the range is worked out here, by the calling thread
    parse_expr();
    bin_type(0, ex_ty);
    push_x0();
    expect(".");
    expect(".");
    parse_expr();
    bin_type(0, ex_ty);
    emit_line("mov x3, x0");
    emit_line("ldr x2, [sp, #0]");
    emit_line("add sp, sp, #16");
    emit_line("mov x1, x29");
    emit_str("adr x0, ");
    emit_lab(lworker);
    emit_nl();
    rt_call("__Mt__run");
    jump(lafter);
    // ---- the worker: x0 = [enclosing frame, from, to]
    place_label(lworker);
    int sv_frame = frame_bytes;
    int sv_try = try_depth;
    int sv_own = own_count;
    int sv_outer = mt_outer;
    int sv_base = mt_base;
    int sv_ok = own_ok;
    frame_bytes = 16;
    try_depth = 0;
    own_count = 0;
    own_ok = 1;
    mt_outer = lcount;                   // the locals so far belong to the enclosing function
    mt_active = 1;
    mt_base = loop_depth;
    emit_str("sub sp, sp, #");
    int pa = out_len;
    emit_str("0000000");
    emit_nl();
    emit_line("str x29, [sp, #0]");
    emit_line("str x30, [sp, #8]");
    emit_line("add x29, sp, #0");
    emit_line("ldr x26, [x0, #0]");
    emit_line("ldr x1, [x0, #8]");
    emit_line("ldr x2, [x0, #16]");
    ty_tid = 0;
    ty_dyn = 0;
    add_local(@m_name, 0, 8, 8, 0);
    int i_off = loff[lcount - 1];
    add_local("..end", 0, 8, 8, 0);
    int e_off = loff[lcount - 1];
    ins_mem("str", "x1", "x29", i_off);
    ins_mem("str", "x2", "x29", e_off);
    place_label(lstart);
    ins_mem("ldr", "x0", "x29", i_off);
    ins_mem("ldr", "x1", "x29", e_off);
    emit_line("cmp x0, x1");
    jump_if("ge", lend);
    brk_stack[loop_depth] = lend;
    cont_stack[loop_depth] = lstep;
    loop_try[loop_depth] = try_depth;
    loop_own[loop_depth] = own_count;
    loop_depth += 1;
    parse_block();
    loop_depth -= 1;
    place_label(lstep);
    ins_mem("ldr", "x0", "x29", i_off);
    emit_line("add x0, x0, #1");
    ins_mem("str", "x0", "x29", i_off);
    jump(lstart);
    place_label(lend);
    emit_line("ldr x29, [sp, #0]");
    emit_line("ldr x30, [sp, #8]");
    emit_str("add sp, sp, #");
    int pb = out_len;
    emit_str("0000000");
    emit_nl();
    emit_line("ret");
    int wframe = (frame_bytes + 15) / 16 * 16;
    patch_number(pa, wframe);
    patch_number(pb, wframe);
    frame_bytes = sv_frame;
    try_depth = sv_try;
    own_count = sv_own;
    own_ok = sv_ok;
    mt_outer = sv_outer;
    mt_base = sv_base;
    mt_active = 0;
    place_label(lafter);
    lcount = for_mark;
}

// cout << a << b << ...;   (one number alone also ends the line)
void parse_cout() {
    check_io_std();
    int c_count = 0;
    int c_last = 0;
    int c_float = 0;
    if tok_is("coutf") {
        c_float = 1;
        io_float_name();
    }
    next();                              // "cout" or "coutf"
    while tok_is("<<") {
        next();
        in_cout = 1;
        parse_bitor();
        in_cout = 0;
        c_last = ex_w;
        if ex_ty == 80 {
            dyn_null_check();
            emit_line("ldr x0, [x0, #16]");        // the characters
            emit_line("bl j2k_print_str");
            c_last = 9;
        } else if is_float(ex_ty) {
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
    if !tok_is(";") {
        if err_line > prev_tok_line && prev_tok_line > 0 { missing_semicolon(); }
        die("expected ';' or '<<' here (is a '<<' missing between two values?)");
    }
    expect(";");
    if c_count == 1 && c_last != 9 && c_last != 2 {
        emit_line("mov x0, 10");
        emit_line("bl j2k_print_char");
    }
}

// cin >> a >> b;   cinf >> x;   what each variable is read as follows from its type;
// bad or missing input throws "invalid input" / "end of input" / "number out of range"
void read_into_object(int is_f) {
    used_try = 1;
    if lv_kind == 3 && is_str_dyn(lv_dyn) {
        load_through(8);                 // the String (cin reads one word into it)
        dyn_null_check();
        rt_call("__In__str");
        return;
    }
    if lv_kind == 1 {
        if lv_code != 2 || lv_nd != 1 { die("cin can read into a char array (a word) but not into other arrays"); }
        push_x0();                       // the array's address
        place_text(@lv_base, str_len(@lv_base));
        emit_line("mov x2, x0");
        emit_line("ldr x0, [sp, #0]");
        emit_line("add sp, sp, #16");
        ins_n("mov x1, ", lv_cnt);
        rt_call("__In__word");
        return;
    }
    if lv_kind != 0 || lv_ptr != 0 || lv_code >= 16 || lv_tid == 1 || (lv_tid >= 3 && lv_tid < 90) {
        die("cin cannot read into this variable (use a number, a char, a float, a String or a char array)");
    }
    int code = lv_code;
    bool is_float_code = code == 6 || code == 7;
    push_x0();                           // the object's address
    if is_float_code {
        rt_call("__In__fnum");
        if code == 6 { lit_to_f32(0); }
    } else if code == 2 {
        rt_call("__In__ch");
    } else {
        int lo = 1;                      // lo > hi: no limits (a 64-bit number)
        int hi = 0;
        int uns = 0;
        if code == 1 { lo = 0 - 128; hi = 127; }
        if code == 4 { lo = 0 - 2147483648; hi = 2147483647; }
        if code == 11 { lo = 0; hi = 255; uns = 1; }
        if code == 12 { lo = 0; hi = 4294967295; uns = 1; }
        if code == 13 { uns = 1; }
        ins_n("mov x0, ", lo);
        ins_n("mov x1, ", hi);
        ins_n("mov x2, ", uns);
        rt_call("__In__num");
    }
    emit_line("ldr x3, [sp, #0]");
    emit_line("add sp, sp, #16");
    emit_line("mov x1, x0");
    store_through(code);
}

void parse_cin() {
    check_io_std();
    int is_f = 0;
    if tok_is("cinf") {
        is_f = 1;
        io_float_name();
    }
    next();                              // "cin" or "cinf"
    int count = 0;
    while tok_is(">>") {
        next();
        if tok_kind != T_IDENT { die("a variable was expected after >>"); }
        char ci_name[256];
        str_copy(@ci_name, @tok_text, 256);
        str_copy(@id_name, @tok_text, 256);
        next();
        if !lookup_var(@ci_name) { die_name("unknown name", @ci_name); }
        uninit_clear(@ci_name);
        parse_lvalue();
        if lv_done == 1 { die("cin needs a variable to read into"); }
        read_into_object(is_f);
        count += 1;
    }
    if count == 0 { die(">> expected after cin"); }
    if !tok_is(";") {
        if err_line > prev_tok_line && prev_tok_line > 0 { missing_semicolon(); }
        die("expected ';' or '>>' here (is a '>>' missing between two variables?)");
    }
    expect(";");
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
    if tok_is("gfx") {
        if cur_in_func == 1 { die("using gfx must be written outside functions"); }
        using_gfx();
        return;
    }
    if tok_is("math") {
        if cur_in_func == 1 { die("using math must be written outside functions"); }
        using_math();
        return;
    }
    if tok_is("enum") {
        next();
        int en = find_enum(@tok_text);
        int dden = dv_find_enum(@tok_text);
        if dden >= 0 {
            dv_set_using(dden, cur_in_func);        // a data enum: its members can be named without Name::
            next();
            accept(";");
            return;
        }
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
    if tok_is("cpu") {
        // using cpu::thread / cpu::mutex, or using cpu : both
        next();
        if tok_is("::") {
            next();
            if tok_is("thread") { us_s = find_struct("Thread"); }
            else if tok_is("mutex") { us_s = find_struct("Mutex"); }
            else { die_name("unknown cpu module", @tok_text); }
            next();
        } else {
            int uc = find_struct("Thread");
            int ud = find_struct("Mutex");
            if cur_in_func == 1 {
                if uc >= 0 { us_l[uc] = 1; }
                if ud >= 0 { us_l[ud] = 1; }
            } else {
                if uc >= 0 { us_g[uc] = 1; }
                if ud >= 0 { us_g[ud] = 1; }
            }
        }
    } else if tok_is("std") || tok_is("stdlib") {
        if tok_is("std") && using_warned == 0 {
            using_warned = 1;
            warn("the library 'std' is now called 'stdlib': write using stdlib", "deprecated");
        }
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
            if cur_in_func == 0 { using_std_seen = 1; }
            int um = 0;
            while um < scount {
                char^ mn = @sname + um * 64;
                if str_eq(mn, "Sys") || str_eq(mn, "Mem") || str_eq(mn, "Str") || str_eq(mn, "Math") || str_eq(mn, "File") {
                    if cur_in_func == 1 {
                        us_l[um] = 1;
                    } else {
                        us_g[um] = 1;
                    }
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
// a switch on a data enum (a struct with a tag, see gen_data_enum): the cases are  Name::Member  or
// Name::Member(a, b)  which also makes a and b (copies of the members' values) for the case
void parse_switch_data(int sw_off, int sd, int sv_line, int sv_col, int sv_base, int sv_ls) {
    int d = dv_find(@sname + sd * 64);
    int covered[64];
    int ci = 0;
    while ci < 64 {
        covered[ci] = 0;
        ci += 1;
    }
    int lend = new_label();
    int ldef = 0;
    expect("{");
    while !tok_is("}") {
        if tok_kind == T_EOF { die("} expected"); }
        int lbody = new_label();
        int lnext = new_label();
        int mark = lcount;
        int saved_base = scope_base;
        int bind_gv = 0 - 1;
        char bind_name[512];             // up to 8 names of 64
        int bind_n = 0;
        if tok_is("_") {
            next();
            expect(":");
            ldef = new_label();
            jump(lnext);
            place_label(ldef);
        } else {
            int labels = 0;
            while true {
                int gv = 0 - 1;
                if tok_kind == T_IDENT && dv_using(d) && dv_variant(d, @tok_text) >= 0 && !dv_label_ok(d, @tok_text) {
                    gv = dv_variant(d, @tok_text);               // after  using enum Name;  the member alone
                    next();
                } else {
                    if tok_kind != T_IDENT || !dv_label_ok(d, @tok_text) {
                        die_name("a case of this switch is written Enum::Member; the enum is", dv_name_of(d));
                    }
                    next();
                    expect("::");
                    if tok_kind != T_IDENT { die("a member name was expected"); }
                    gv = dv_variant(d, @tok_text);
                    if gv < 0 { die_name("not a member of the enum", @tok_text); }
                    next();
                }
                int vi = gv - dv_first_of(d);
                covered[vi] = 1;
                ins_mem("ldr", "x0", "x29", sw_off);
                emit_line("ldr x0, [x0, #0]");
                ins_n("mov x1, ", vi);
                emit_line("cmp x0, x1");
                jump_if("eq", lbody);
                labels += 1;
                if tok_is("(") {
                    next();
                    bind_gv = gv;
                    if !tok_is(")") {
                        while true {
                            if tok_kind != T_IDENT { die("a name was expected (or _ to ignore a value)"); }
                            if bind_n >= 8 { die("a case can name at most 8 values"); }
                            str_copy(@bind_name + bind_n * 64, @tok_text, 64);
                            bind_n += 1;
                            next();
                            if tok_is(",") {
                                next();
                            } else {
                                break;
                            }
                        }
                    }
                    expect(")");
                    if bind_n != dv_nparam_of(gv) && pass_no >= 2 {
                        die_name("this member has a different number of values", dv_vname(gv));
                    }
                }
                if tok_is(",") {
                    if bind_gv >= 0 { die("a case that names values must stand alone"); }
                    next();
                } else {
                    break;
                }
            }
            expect(":");
            jump(lnext);
            place_label(lbody);
            if bind_gv >= 0 {
                // the values: new variables, copies of the members (a String or array is only borrowed)
                scope_base = lcount;
                int k = 0;
                while k < bind_n {
                    if !str_eq(@bind_name + k * 64, "_") && pass_no >= 1 {
                        int fi = 0 - 1;
                        int fk = sfirst[sd];
                        char^ want = dv_pfield(bind_gv, k);
                        while fk < sfirst[sd] + snf[sd] {
                            if str_eq(@fldname + fk * 64, want) { fi = fk; }
                            fk += 1;
                        }
                        if fi < 0 {
                            if pass_no >= 2 { die("internal: a member of a data enum has no field"); }
                        } else {
                            ins_mem("ldr", "x0", "x29", sw_off);
                            if fldoff[fi] != 0 { ins_n("add x0, x0, #", fldoff[fi]); }
                            if flddyn[fi] != 0 {
                                emit_line("ldr x0, [x0, #0]");
                                ty_tid = 99;
                                ty_dyn = flddyn[fi];
                                add_local(@bind_name + k * 64, 3, 8, 8, 0);
                                ins_mem("str", "x0", "x29", loff[lcount - 1]);
                            } else if fldcode[fi] >= 16 && fldptr[fi] == 0 {
                                if struct_has_free(fldcode[fi] - 16) {
                                    // a value that frees itself is only looked at: the name is a pointer to it (used like the struct)
                                    ty_tid = 0;
                                    add_local(@bind_name + k * 64, 0, 8, 8, fldcode[fi]);
                                    lalias[lcount - 1] = 1;
                                    ins_mem("str", "x0", "x29", loff[lcount - 1]);
                                } else {
                                    ty_tid = fldtid[fi];
                                    add_local(@bind_name + k * 64, 0, fldcode[fi], ssize[fldcode[fi] - 16], 0);
                                    ins_n("add x3, x29, #", loff[lcount - 1]);
                                    ins_n("mov x2, ", ssize[fldcode[fi] - 16]);
                                    emit_line("bl j2k_copy");
                                }
                            } else {
                                load_through(fldcode[fi]);
                                ty_tid = fldtid[fi];
                                int lcode = fldcode[fi];
                                if fldptr[fi] != 0 { lcode = 8; }
                                add_local(@bind_name + k * 64, 0, lcode, 8, fldptr[fi]);
                                ins_mem("str", "x0", "x29", loff[lcount - 1]);
                            }
                        }
                    }
                    k += 1;
                }
            }
        }
        int sv_ok = own_ok;
        if !tok_is("{") { own_ok = 0; }
        parse_statement();
        own_ok = sv_ok;
        lcount = mark;
        scope_base = saved_base;
        jump(lend);
        place_label(lnext);
    }
    expect("}");
    if ldef != 0 { jump(ldef); }
    place_label(lend);
    if ldef == 0 && pass_no >= 2 {
        char wmsg[600];
        wmsg[0] = 0;
        int missing = 0;
        int mm = 0;
        while mm < dv_nvar_of(d) {
            if covered[mm] == 0 {
                if missing > 0 { append_text(@wmsg, ", "); }
                append_text(@wmsg, "'");
                append_text(@wmsg, dv_vname(dv_first_of(d) + mm));
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
    if sw_ty >= 100 && dv_find(@sname + (sw_ty - 100) * 64) >= 0 {
        parse_switch_data(sw_off, sw_ty - 100, sv_line, sv_col, sv_base, sv_ls);
        return;
    }
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
// does struct s have a method free(self)? Then a local variable of it is freed by the compiler at the end of its block
bool struct_has_free(int s) {
    char nm[128];
    str_copy(@nm, @sname + s * 64, 64);
    append_text(@nm, "__free");
    return find_func(@nm) >= 0;
}

// the struct at frame offset off (a parameter copy) is an owner of kind 4 if it frees itself
void struct_owner_at(int off, int s) {
    if own_ok == 1 && struct_has_free(s) { own_add(off, 4, s); }
}

// the struct variable just declared (the last local) is an owner of kind 4
void struct_owner(int s) {
    if own_ok == 1 && struct_has_free(s) {
        own_add(loff[lcount - 1], 4, s);
    }
}

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
    ins_mem("ldr", "x0", "x27", 0);
    ins_mem("str", "x0", "x29", loff[lcount - 1]);
    parse_block();
    lcount = catch_mark;
    place_label(lend);
}

// throw "text";   (the nearest catch gets the text; nothing to catch = the program stops)
void parse_throw() {
    used_try = 1;
    fn_returns = 1;
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

// the variables from index `from` up that were declared and never used
void warn_unused(int from) {
    int i = from;
    while i < lcount {
        if lwarn[i] == 1 && lused[i] == 0 {
            int sl = err_line;
            int sc = err_col;
            int sb = err_base;
            int ss = err_ls;
            err_line = lw_line[i];
            err_col = lw_col[i];
            err_base = lw_base[i];
            err_ls = lw_ls[i];
            char um[200];
            str_copy(@um, "'", 200);
            append_text(@um, @lname + i * 64);
            append_text(@um, "' is declared but never used");
            warn(@um, "unused");
            err_line = sl;
            err_col = sc;
            err_base = sb;
            err_ls = ss;
        }
        i += 1;
    }
}

void parse_local_decl() {
    track_unused = 1;
    parse_local_decl_core();
    track_unused = 0;
}

void parse_local_decl_core() {
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
    decl_line = err_line;                // where a warning about the unused variable will point
    decl_col = err_col;
    decl_base = err_base;
    decl_ls = err_ls;
    check_local_name(@d_name);
    next();
    if tok_is("[") {
        int d_count = parse_dims();
        int d_nd = dim_nd;
        int d_s1 = dim_s1;
        int d_s2 = dim_s2;
        int d_str = 0;
        int d_list = 0;
        if tok_is("=") {
            next();
            if tok_is("{") {
                // double a[3] = {1.0, 2.0, 3.0};   (a[] takes its size from the number of values)
                if d_nd != 1 { die("only a one-dimensional array can start from a list of values"); }
                if d_elem >= 16 && d_ptr == 0 { die("an array of structs cannot start from a list of values yet"); }
                d_list = count_values_from(0);                  // the current token is the {: its characters are already read
                if d_list < 0 { die("a } was expected"); }
                if d_count < 0 { d_count = d_list; }
                if d_list > d_count { die("more values than the array can hold"); }
            } else {
            if tok_kind != T_STR { die("a string was expected"); }
            if size_of(d_elem) != 1 { die("only a char array can start from a string"); }
            if d_nd != 1 { die("only a one-dimensional array can start from a string"); }
            d_str = 1;
            if d_count < 0 { d_count = tok_str_len + 1; }
            if tok_str_len + 1 > d_count { die("the string does not fit in the array"); }
            }
        } else {
            if d_count < 0 { die("an array size (a number) was expected"); }
            expect(";");
        }
        ty_tid = d_tid;
        add_local(@d_name, 1, d_elem, d_count * size_of(d_elem), d_ptr);
        lnd[lcount - 1] = d_nd;
        lst1[lcount - 1] = d_s1;
        lst2[lcount - 1] = d_s2;
        if d_list > 0 || (d_list == 0 && tok_is("{")) {
            int l_off = loff[lcount - 1];
            int l_es = size_of(d_elem);
            int l_tid = d_tid;
            if d_ptr != 0 { l_tid = 0; }
            next();                      // the {
            int l_i = 0;
            while !tok_is("}") {
                if l_i >= d_count { die("more values than the array can hold"); }
                parse_expr();
                check_assign(l_tid);
                emit_line("mov x1, x0");
                ins_n("add x3, x29, #", l_off + l_i * l_es);
                store_through(d_elem);
                l_i += 1;
                if tok_is(",") { next(); } else { break; }
            }
            if !tok_is("}") { die("} expected at the end of the list of values"); }
            next();
            // the values that are not given are zero
            if l_i < d_count {
                if d_count - l_i > 64 { die("give all the values of a big array, or none (the rest would not be zeroed)"); }
                emit_line("mov x1, 0");
                while l_i < d_count {
                    ins_n("add x3, x29, #", l_off + l_i * l_es);
                    store_through(d_elem);
                    l_i += 1;
                }
            }
            expect(";");
        }
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
    if d_dyn != 0 && is_str_dyn(d_dyn) {
        // String name;   String name = "text";   String name = other (a copy) / a + b (taken over)
        if tok_is("=") {
            next();
            parse_expr();
            str_adopt();
        } else {
            place_text("", 0);
            rt_call("__Str__from");
        }
        expect(";");
        ty_tid = 99;
        ty_dyn = d_dyn;
        add_local(@d_name, 3, 8, 8, 0);
        ins_mem("str", "x0", "x29", loff[lcount - 1]);
        if own_ok == 1 { own_add(loff[lcount - 1], 1, 0); }
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
        if dd_start == 1 {
            int dk = 1;
            if is_strarr_dyn(d_dyn) { dk = 3; }
            own_add(loff[lcount - 1], dk, 0);
        }
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
                struct_owner(d_sidx);
            } else {
                parse_expr();
                check_assign(d_tid);
                int how = 0;
                int src_off = 0;
                if struct_has_free(d_sidx) {
                    how = struct_source(d_sidx);
                    src_off = own_src_off;
                }
                ty_tid = d_tid;
                add_local(@d_name, 0, d_width, ssize[d_sidx], 0);
                ins_n("add x3, x29, #", loff[lcount - 1]);
                ins_n("mov x2, ", ssize[d_sidx]);
                emit_line("bl j2k_copy");
                if how == 2 {
                    emit_zero_local(src_off, ssize[d_sidx]);       // the value moved: the old variable is empty
                    int oi = own_find(src_off);
                    if oi >= 0 && own_blk[oi] == cur_blk { own_moved[oi] = 1; }
                }
                struct_owner(d_sidx);
            }
            expect(";");
            return;
        }
        expect(";");
        ty_tid = d_tid;
        add_local(@d_name, 0, d_width, ssize[d_sidx], 0);
        if struct_has_free(d_sidx) {
            // it will be freed at the end of the block: start from zeros so that free(self) is always safe
            int zk = 0;
            emit_line("mov x1, 0");
            while zk < ssize[d_sidx] {
                ins_mem("str", "x1", "x29", loff[lcount - 1] + zk);
                zk += 8;
            }
        }
        if struct_has_init(d_sidx) {
            ins_n("add x0, x29, #", loff[lcount - 1]);
            emit_init_call(d_sidx);
        }
        struct_owner(d_sidx);
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
        lused[lcount - 1] = 0;           // the declaration itself is not a use
        store_scalar();
        if d_own == 1 { own_add(v_off, 0, 0); }
        return;
    }
    expect(";");
    ty_tid = d_tid;
    add_local(@d_name, 0, d_width, 8, d_ptr);
    if d_width < 16 {
        luninit[lcount - 1] = 1;
        lunloop[lcount - 1] = loop_depth;
    }
}

// a statement; the Strings that its expressions made are freed at its end
void parse_statement() {
    stash_depth = 0;                     // no operand waits in a register between two statements
    int t0 = own_count;
    int saved_t0 = stmt_t0;
    stmt_t0 = t0;
    parse_statement_inner();
    stmt_t0 = saved_t0;
    str_flush(t0, 0);
}

int in_defer;                // > 0 while a deferred statement is compiled
int defer_loop_base;         // loop_depth where it began

// defer statement;   defer { ... }   : runs when the block is left (also by return, break, continue or a throw),
// the last defer first; it sees the variables as they are then
void parse_defer() {
    if in_defer > 0 { die("a defer cannot contain a defer"); }
    if cur_in_func == 0 || mt_active == 1 { die("defer is used inside a function (not in a #multithread loop)"); }
    next();                              // "defer"
    int lskip = new_label();
    int ldef = new_label();
    jump(lskip);
    place_label(ldef);
    emit_line("sub sp, sp, #16");
    emit_line("str x30, [sp, #0]");
    in_defer += 1;
    defer_loop_base = loop_depth;
    int sv_ok = own_ok;
    own_ok = 0;
    parse_statement();
    own_ok = sv_ok;
    in_defer -= 1;
    emit_line("ldr x30, [sp, #0]");
    emit_line("add sp, sp, #16");
    emit_line("ret");
    place_label(lskip);
    own_add(0 - 1, 5, ldef);
}

void parse_statement_inner() {
    if tok_is("defer") && in_func_stmt_ok() {
        parse_defer();
        return;
    }
    if mt_pending == 1 {
        mt_pending = 0;
        if !tok_is("for") { die("#multithread must be followed by a for loop"); }
        parse_mt_for();
        return;
    }
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
    if tok_is("cin") || tok_is("cinf") {
        parse_cin();
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
        if in_defer > 0 && loop_depth <= defer_loop_base { die("a deferred statement cannot break out of a loop around it"); }
        if mt_active == 1 && loop_depth - 1 == mt_base { die("break cannot be used in a #multithread loop (every iteration runs on its own)"); }
        leave_tries(try_depth - loop_try[loop_depth - 1]);
        own_free_from(loop_own[loop_depth - 1], 0);
        jump(brk_stack[loop_depth - 1]);
        return;
    }
    if tok_is("continue") {
        next();
        expect(";");
        if loop_depth == 0 { die("continue outside a loop"); }
        if in_defer > 0 && loop_depth <= defer_loop_base { die("a deferred statement cannot continue a loop around it"); }
        leave_tries(try_depth - loop_try[loop_depth - 1]);
        own_free_from(loop_own[loop_depth - 1], 0);
        jump(cont_stack[loop_depth - 1]);
        return;
    }
    if tok_is("return") {
        if in_defer > 0 { die("a deferred statement cannot return"); }
        if mt_active == 1 { die("return cannot be used inside a #multithread loop"); }
        next();
        int ret_mv = 0 - 1;
        if tok_is(";") {
            next();
            if cur_is_main == 1 { emit_line("mov x0, 0"); }
        } else {
            fn_returns = 1;
            parse_expr();
            if cur_ret_str == 1 && pass_no >= 2 {
                // a String result: an owner or a temporary moves out, anything else is copied
                if ex_ty == 80 {
                    int rv_own = 0 - 1;
                    if rv_valid == 1 { rv_own = own_find(rv_off); }
                    if rv_own < 0 { rt_call("__Str__clone"); }
                } else if ex_w == 9 {
                    rt_call("__Str__from");
                    ex_ty = 80;
                    rv_valid = 0;
                } else {
                    die("this function returns a String");
                }
            }
            check_assign(cur_ret_tid);
            if rv_valid == 1 && cur_ret_isptr == 1 { ret_mv = own_find(rv_off); }
            int rhow = 0;
            int rsrc = 0;
            if cur_ret_tid >= 100 && struct_has_free(cur_ret_tid - 100) {
                if alias_src == 1 {
                    rhow = 3;                                  // taken out of a data enum: copied, and the enum's copy is emptied
                } else {
                    rhow = struct_source(cur_ret_tid - 100);   // a value that frees itself moves out
                    rsrc = own_src_off;
                }
            }
            if rhow == 3 { push_x0(); }
            if cur_ret_tid >= 100 {
                ins_mem("ldr", "x3", "x29", cur_ret_off);
                ins_n("mov x2, ", ssize[cur_ret_tid - 100]);
                emit_line("bl j2k_copy");
            }
            if rhow == 2 { emit_zero_local(rsrc, ssize[cur_ret_tid - 100]); }
            if rhow == 3 {
                emit_line("ldr x1, [sp, #0]");
                emit_line("add sp, sp, #16");
                emit_line("mov x2, 0");
                int zk3 = 0;
                while zk3 < ssize[cur_ret_tid - 100] {
                    ins_mem("str", "x2", "x1", zk3);
                    zk3 += 8;
                }
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
        // arguments 9.. were left on the caller's stack; their distance from x29 is only known at the
        // end of the function (frame size and number of arguments): patched in parse_function
        emit_str("ldr x9, [x29, #");
        if xp_count >= 8 { die("too many parameters"); }
        xp_pos[xp_count] = out_len;
        xp_reg[xp_count] = reg;
        xp_count += 1;
        emit_str("0000000]\n");
        ins_mem("str", "x9", "x29", off);
    }
}

void parse_function() {
    int f_void = ty_void;
    int f_rettid = ty_tid;
    cur_ret_isptr = 0;
    cur_ret_str = 0;
    if is_str_dyn(ty_dyn) { cur_ret_str = 1; }
    if ty_ptr != 0 || ty_dyn != 0 { cur_ret_isptr = 1; }
    if ty_ptr != 0 { f_rettid = 0; }
    cur_ret_tid = f_rettid;
    int f_idx = find_func(@d_fname);
    int f_oper = op_pending;
    op_pending = 0;
    if f_idx < 0 {
        if fcount >= 16384 { die("too many functions"); }
        fop[fcount] = 0;
        str_copy(@fname + fcount * 64, @d_fname, 64);
        farr[fcount] = 0;
        fvoid[fcount] = 0;
        if ty_void == 1 && ty_ptr == 0 { fvoid[fcount] = 1; }
        fself[fcount] = 0;
        fnpar[fcount] = 0;
        fret[fcount] = f_rettid;
        fcharret[fcount] = 0;
        fretstr[fcount] = 0;
        fretdyn[fcount] = ty_dyn;
        if is_str_dyn(ty_dyn) { fretstr[fcount] = 1; }
        if ty_elem == 2 && ty_ptr == 0 && ty_dyn == 0 && ty_void == 0 { fcharret[fcount] = 1; }
        if ty_ptr == 2 && ty_dyn == 0 && ty_void == 0 { fcharret[fcount] = 2; }
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
    int sv_dz = used_divz;
    int sv_nr = used_noret;
    int sv_try = used_try;
    int sv_up = used_uprint;
    int sv_thr = used_thread;
    if pass_no == 3 && freach[f_idx] == 0 { f_skip = 1; }
    if f_oper == 1 { fop[f_idx] = 1; }
    cur_fidx = f_idx;
    int f_self = fn_self_struct;
    fn_self_struct = 0 - 1;
    cp_count = 0;
    xp_count = 0;
    cur_in_func = 1;
    int ue_i = 0;
    while ue_i < 64 {
        ue_l[ue_i] = 0;
        ue_i += 1;
    }
    ue_i = 0;
    while ue_i < 256 {
        us_l[ue_i] = 0;
        ue_i += 1;
    }
    dv_clear_local();
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
    if pass_no == 3 && f_skip == 0 && ft_count < 4096 {
        str_copy(@ft_names + ft_count * 64, @d_fname, 64);
        ft_count += 1;
    }
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
            if f_declared < 8 { fpstr[f_idx * 8 + f_declared] = 0; if is_str_dyn(p_dyn) { fpstr[f_idx * 8 + f_declared] = 1; } }
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
                if ssize[p_tid - 100] > 64 && pass_no >= 2 && lvl_inst[lx_depth] == 0 {
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
                cp_sidx[cp_count] = p_tid - 100;
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
        struct_owner_at(cp_dst[cp_i], cp_sidx[cp_i]);        // a value that frees itself is the callee's now
        cp_i += 1;
    }
    in_lambda = 0;
    if d_fname[0] == '_' && d_fname[1] == '_' && d_fname[2] == 'l' && d_fname[3] == 'a' && d_fname[4] == 'm' { in_lambda = 1; }
    fn_returns = 0;
    fn_line = err_line;
    fn_col = err_col;
    fn_base = err_base;
    fn_ls = err_ls;
    parse_block();
    own_free_from(0, 1);                 // what the parameters own (the body's own variables were given back at its end)
    if fvoid[f_idx] == 0 && cur_is_main == 0 && fn_returns == 0 {
        err_line = fn_line;
        err_col = fn_col;
        err_base = fn_base;
        err_ls = fn_ls;
        char rm[200];
        str_copy(@rm, "function '", 200);
        append_text(@rm, @d_fname);
        append_text(@rm, "' must return a value but has no return statement (make it void, or return something)");
        if pass_no >= 2 { die(@rm); }
    }
    in_lambda = 0;
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
        emit_line("mov x8, 94");
        emit_line("svc 0");
    } else {
        if fvoid[f_idx] == 0 {
            // the body ended without a return: that is an error at run time (a normal return jumps over this)
            emit_line("bl j2k_noret");
            used_noret = 1;
            note_call("__panic");
        }
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
    int xi = 0;
    while xi < xp_count {
        // argument k (counted from 0, n arguments in all) is at entry_sp + 16 * (n - 1 - k) = x29 + frame + ...
        patch_number(xp_pos[xi], frame + 16 * (nparams - 1 - xp_reg[xi]));
        xi += 1;
    }
    cur_fidx = 0 - 1;
    if f_skip == 1 {
        out_len = sv_out;
        gl_bytes = sv_gl;
        ginit_count = sv_ginit;
        used_fprint = sv_fp;
        used_oob = sv_oob;
        used_divz = sv_dz;
        used_noret = sv_nr;
        used_try = sv_try;
        used_uprint = sv_up;
        used_thread = sv_thr;
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
        int g_list = 0 - 1;
        if tok_is("=") {
            next();
            if tok_is("{") {
                // double dist[3] = {1.0, 2.0, 3.0};   constants only
                if g_nd != 1 { die("only a one-dimensional array can start from a list of values"); }
                if g_elem >= 16 && g_ptr == 0 { die("an array of structs cannot start from a list of values yet"); }
                if g_elem == 6 { die("a global float array cannot start from a list of values (use double, or set it in main)"); }
                g_list = count_values_from(0);
                if g_list < 0 { die("a } was expected"); }
                if g_count < 0 { g_count = g_list; }
                if g_list > g_count { die("more values than the array can hold"); }
            } else {
            if tok_kind != T_STR { die("a string was expected"); }
            if size_of(g_elem) != 1 { die("only a char array can start from a string"); }
            if g_nd != 1 { die("only a one-dimensional array can start from a string"); }
            g_str = 1;
            if g_count < 0 { g_count = tok_str_len + 1; }
            if tok_str_len + 1 > g_count { die("the string does not fit in the array"); }
            }
        } else {
            if g_count < 0 { die("an array size (a number) was expected"); }
            expect(";");
        }
        ty_tid = g_tid;
        add_global(name, 1, g_elem, g_count * size_of(g_elem), g_ptr);
        gnd[gcount - 1] = g_nd;
        gst1[gcount - 1] = g_s1;
        gst2[gcount - 1] = g_s2;
        if g_list >= 0 {
            int gl_off = goff[gcount - 1];
            int gl_es = size_of(g_elem);
            int gl_tid = g_tid;
            if g_ptr != 0 { gl_tid = 0; }
            next();                      // the {
            int gl_i = 0;
            int gl_word = 0;
            while !tok_is("}") {
                int gv = parse_const();
                int gl_at = gl_off + gl_i * gl_es;
                if cf_flag == 1 {
                    if g_tid != 91 { die("a float constant needs a double array"); }
                    if gfi_count >= 4096 { die("too many global float initializers"); }
                    if pass_no >= 2 {
                        gfi_off[gfi_count] = gl_at;
                        gfi_mant[gfi_count] = cf_mant;
                        gfi_exp[gfi_count] = cf_exp;
                        gfi_neg[gfi_count] = cf_neg;
                        gfi_f32[gfi_count] = 0;
                        gfi_count += 1;
                    }
                } else {
                    if g_ptr == 0 { check_assign(gl_tid); }
                    if g_elem == 2 || g_elem == 11 { gv = gv & 255; }
                    if g_elem == 12 { gv = gv & 4294967295; }
                    if g_elem == 1 { gv = (gv & 255) xor 128; gv = gv - 128; gv = gv & 255; }
                    if g_elem == 4 { gv = gv & 4294967295; }
                    if gl_es == 8 {
                        if gv != 0 { add_ginit(gl_at, gv); }
                    } else {
                        // small elements: the 8 bytes around are put together and stored once
                        gl_word = gl_word | (gv << ((gl_at % 8) * 8));
                        if (gl_at + gl_es) % 8 == 0 {
                            if gl_word != 0 { add_ginit(gl_at + gl_es - 8, gl_word); }
                            gl_word = 0;
                        }
                    }
                }
                gl_i += 1;
                if gl_i > g_count { die("more values than the array can hold"); }
                if tok_is(",") { next(); } else { break; }
            }
            if !tok_is("}") { die("} expected at the end of the list of values"); }
            if gl_es < 8 && gl_word != 0 {
                add_ginit(((gl_off + gl_i * gl_es - 1) / 8) * 8, gl_word);
            }
            next();
            expect(";");
        }
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
            if g_tid != 90 && g_tid != 91 { die("a float constant needs a float or double variable"); }
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
        if scount >= 256 { die("too many structs (256 at most, generic instances count)"); }
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
        op_pending = 0;
        if tok_is("operator") {
            op_pending = 1;              // operator vec3 add(self, vec3 o) { ... }: usable as a + b
            next();
        }
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

// one top-level item (generic declarations and the instances an item needs are handled first)
void parse_one_item() {
    gen_item();
    if tok_kind == T_EOF { return; }
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
    gen_lambdas();                       // the lambdas written in this item become functions now
    gen_pending();                       // so do the generic instances found by a call without <...>
}

void parse_program() {
    while tok_kind != T_EOF { parse_one_item(); }
}

// the entry point: sets x28 (the global area), keeps the initial sp (argc /
// argv live there), stores the global initial values, then runs main
// division by zero: throw the text (the caller used bl; the exception routine does not return here)
// a function ended without return (the value would be junk): throw
void emit_noret_helper() {
    emit_line("j2k_noret:");
    place_text("a function ended without returning a value", 42);
    emit_line("b __panic");
}

void emit_divzero_helper() {
    emit_line("j2k_divzero:");
    place_text("division by zero", 16);
    emit_line("b __panic");
}

// SIGSEGV (a null pointer, or a stack that ran out): say so and stop (the handler runs on its own stack)
char segv_text[80];
void emit_segv_handler() {
    str_copy(@segv_text, "runtime error: segmentation fault (null pointer or stack overflow)\n", 80);
    int n = str_len(@segv_text);
    emit_line("j2k_segv:");
    emit_line("sub sp, sp, #128");
    emit_text_chunks(@segv_text, n);
    emit_line("mov x0, 2");
    emit_line("add x1, sp, #0");
    emit_str("mov x2, ");
    emit_int(n);
    emit_nl();
    emit_line("mov x8, 64");
    emit_line("svc 0");
    emit_line("mov x0, 139");
    emit_line("mov x8, 94");
    emit_line("svc 0");
}

void emit_start_stub() {
    int alt = (gl_bytes + 15) / 16 * 16;       // the stack of the SIGSEGV handler
    gl_bytes = alt + 32768;
    emit_line("j2k_start:");
    emit_line("mov x28, 268435456");
    emit_line("add x27, x28, #72");            // x27: this thread's block (thrown text, try handlers)
    emit_line("add x9, sp, #0");
    emit_line("str x9, [x28, #0]");
    // SIGSEGV handler: rt_sigaction(11, {j2k_segv, SA_ONSTACK}) and sigaltstack
    emit_line("sub sp, sp, #64");
    emit_line("adr x0, j2k_segv");
    emit_line("str x0, [sp, #0]");
    emit_line("mov x0, 134217728");
    emit_line("str x0, [sp, #8]");
    emit_line("mov x0, 0");
    emit_line("str x0, [sp, #16]");
    emit_line("str x0, [sp, #24]");
    emit_line("mov x0, 11");
    emit_line("add x1, sp, #0");
    emit_line("mov x2, 0");
    emit_line("mov x3, 8");
    emit_line("mov x8, 134");
    emit_line("svc 0");
    ins_n("mov x9, ", alt);
    emit_line("add x0, x28, x9");
    emit_line("str x0, [sp, #32]");
    emit_line("mov x0, 0");
    emit_line("str x0, [sp, #40]");
    emit_line("mov x0, 32768");
    emit_line("str x0, [sp, #48]");
    emit_line("add x0, sp, #32");
    emit_line("mov x1, 0");
    emit_line("mov x8, 132");
    emit_line("svc 0");
    emit_line("add sp, sp, #64");
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
            if gf_e <= 18 {
                while gf_i < gf_e {
                    gf_p = gf_p * 10;
                    gf_i += 1;
                }
                ins_n("mov x1, ", gf_p);
                emit_line("scvtf d1, x1");
            } else {
                ins_n("mov x1, ", pow10_bits(gf_e));
                emit_line("fmov d1, x1");
            }
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
    if used_fntab == 1 {
        // the names of the functions, for the trace that a panic prints
        emit_line("j2k_fntab:");
        int ft_i = 0;
        while ft_i < ft_count {
            emit_str(".quad ");
            emit_line(@ft_names + ft_i * 64);
            emit_str(".quad j2k_fs");
            emit_int(ft_i);
            emit_nl();
            ft_i += 1;
        }
        emit_line(".quad 0");
        emit_line(".quad 0");
        ft_i = 0;
        while ft_i < ft_count {
            emit_str("j2k_fs");
            emit_int(ft_i);
            emit_line(":");
            emit_str(".asciz \"");
            emit_str(@ft_names + ft_i * 64);
            emit_line("\"");
            ft_i += 1;
        }
    }
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
    emit_line("mov x8, 94");
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
    emit_line("ldr x1, [x27, #8]");
    emit_line("cmp x1, 24");
    emit_line("b.ge j2k_exc_full");
    emit_line("mov x2, 32");
    emit_line("mul x2, x1, x2");
    emit_line("add x3, x27, #0");
    emit_line("add x3, x3, x2");
    emit_line("add x4, sp, #0");
    emit_line("str x4, [x3, #16]");
    emit_line("str x29, [x3, #24]");
    emit_line("str x30, [x3, #32]");
    emit_line("ldr x4, [x27, #784]");
    emit_line("str x4, [x3, #40]");
    emit_line("add x1, x1, #1");
    emit_line("str x1, [x27, #8]");
    emit_line("mov x0, 0");
    emit_line("ret");
    emit_line("j2k_exc_full:");
    emit_line("mov x0, 2");
    emit_line("mov x8, 94");
    emit_line("svc 0");
    emit_line("j2k_try_leave:");
    emit_line("ldr x1, [x27, #8]");
    emit_line("sub x1, x1, #1");
    emit_line("str x1, [x27, #8]");
    emit_line("ret");
    emit_line("j2k_throw:");
    emit_line("str x0, [x27, #0]");
    emit_line("ldr x1, [x27, #8]");
    emit_line("cmp x1, 0");
    emit_line("b.eq j2k_uncaught");
    emit_line("sub x1, x1, #1");
    emit_line("str x1, [x27, #8]");
    emit_line("mov x2, 32");
    emit_line("mul x2, x1, x2");
    emit_line("add x3, x27, #0");
    emit_line("add x3, x3, x2");
    // free what the frames that are left owned (the cleanup chain down to the head saved by the try)
    emit_line("sub sp, sp, #16");
    emit_line("str x3, [sp, #0]");
    emit_line("ldr x9, [x3, #40]");
    emit_line("str x9, [sp, #8]");
    emit_line("j2k_th1:");
    emit_line("ldr x5, [x27, #784]");
    emit_line("ldr x9, [sp, #8]");
    emit_line("cmp x5, x9");
    emit_line("b.eq j2k_th3");
    emit_line("cmp x5, 0");
    emit_line("b.eq j2k_th3");
    emit_line("ldr x6, [x5, #0]");
    emit_line("str x6, [x27, #784]");
    emit_line("ldr x7, [x5, #8]");
    emit_line("ldr x8, [x5, #16]");
    emit_line("ldr x10, [x5, #24]");
    emit_line("mov x0, x7");
    emit_line("cmp x10, 0");
    emit_line("b.ne j2k_th2");
    emit_line("ldr x0, [x7, #0]");
    emit_line("j2k_th2:");
    emit_line("cmp x10, 2");
    emit_line("b.ne j2k_th4");
    emit_line("mov x29, x7");               // a deferred statement works on the frame it was written in
    emit_line("j2k_th4:");
    emit_line("blr x8");
    emit_line("b j2k_th1");
    emit_line("j2k_th3:");
    emit_line("ldr x3, [sp, #0]");
    emit_line("add sp, sp, #16");
    emit_line("ldr x4, [x3, #16]");
    emit_line("ldr x29, [x3, #24]");
    emit_line("ldr x30, [x3, #32]");
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
    emit_line("mov x8, 94");
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

// start a thread: x0 = function, x1 = argument, x2 = top of its stack, x3 = address of its id word,
// x4 = its thread block. clone(VM|FS|FILES|SIGHAND|SYSVSEM|THREAD|PARENT_SETTID|CHILD_CLEARTID);
// the child runs function(argument) on the new stack, then ends only itself (exit, not exit_group)
void emit_thread_helper() {
    emit_line("j2k_thread_start:");
    emit_line("sub x2, x2, #32");
    emit_line("str x0, [x2, #0]");
    emit_line("str x1, [x2, #8]");
    emit_line("str x4, [x2, #16]");
    emit_line("mov x6, x3");
    emit_line("mov x0, 3477248");
    emit_line("mov x1, x2");
    emit_line("mov x2, x6");
    emit_line("mov x3, 0");
    emit_line("mov x4, x6");
    emit_line("mov x8, 220");
    emit_line("svc 0");
    emit_line("cmp x0, 0");
    emit_line("b.ne j2k_ts_parent");
    emit_line("ldr x27, [sp, #16]");
    emit_line("ldr x9, [sp, #0]");
    emit_line("ldr x0, [sp, #8]");
    emit_line("blr x9");
    emit_line("mov x0, 0");
    emit_line("mov x8, 93");
    emit_line("svc 0");
    emit_line("j2k_ts_parent:");
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

bool in_func_stmt_ok() {
    return cur_in_func == 1;
}
