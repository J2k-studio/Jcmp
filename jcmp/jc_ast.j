// jc_ast.j -- a syntax tree per function body (docs/design/10-structured-pipeline.md 8.1, part A1; the owner chose T1 on 2026-10-14).
//
// A1a (this file, so far): a PROBE. When the parser is at the `{` of a function body, ast_probe() reads the body again with its own
// small parser into a tree of nodes, for the subset: whole numbers, `int` locals and parameters, `+ - * / %`, the bit operators,
// comparisons, `&& || !`, calls of functions that return a whole number, assignments, `if / else`, `while`, `for i in a..b`,
// `return`, `break`, `continue`. Then the lexer is put back where it was and the normal parser goes on: nothing about the
// generated code changes. The switch `-xast` says, for every function, whether the body is in the subset (and why not).
// The next steps (A1b) lower the tree straight to the IR and compare it with the text path (`-noast`).
//
// The operators have the order of docs/syntax-design.md 34: * / %  >  + -  >  << >>  >  &  >  xor  >  |  >  < > <= >=  >  == !=  >  &&  >  ||.

#define AST_MAXN 16384

// node kinds
#define AK_NUM 1             // val = the number
#define AK_VAR 2             // val = the local (index of the probe's table)
#define AK_BIN 3             // val = operator code (AO_*), a, b = operands
#define AK_NEG 4             // a
#define AK_NOT 5             // a
#define AK_CALL 6            // val = the function (index), a = first argument node, the arguments are a chain through ast_nx
#define AK_ASSIGN 7          // c = the target (AK_VAR, AK_GVAR, AK_INDEX, AK_DEREF), a = the value; b = operator code (0: plain `=`, else AO_*)
#define AK_IF 8              // a = condition, b = then block, c = else (a block, another AK_IF, or 0)
#define AK_WHILE 9           // a = condition, b = body
#define AK_FOR 10            // val = the local, a = from, b = to, c = body
#define AK_RET 11            // a = value (0: none)
#define AK_BLOCK 12          // a = first statement, the statements are a chain through ast_nx
#define AK_DECL 13           // val = the local, a = initial value (0: none); b = the number of elements of a fixed array of one dimension (-1: not known)
#define AK_EXPR 14           // a = the expression (a call)
#define AK_BREAK 15
#define AK_CONT 16
#define AK_INDEX 17          // a = the array or pointer (AK_VAR / AK_GVAR), b = the index
#define AK_DEREF 18          // a = the pointer (p^)
#define AK_ADDR 19           // a = the variable or element (@x, @a[i])
#define AK_CAST 20           // val = the type code, a = the value
#define AK_GVAR 21           // val = the global
#define AK_STR 22            // a string literal (only in cout)
#define AK_COUT 23           // a = the first item, the items are a chain through c
#define AK_INCDEC 24         // val = the local (or -1 - the global), b = +1 / -1
#define AK_FNUM 25           // a number with a decimal point (the bits are not kept)
#define AK_FIELD 26          // a = the struct value, val = the field (index in the field tables)
#define AK_METHOD 28         // a = the object, b = first argument (a chain through ast_nx), val = the name (an offset in ast_pool)
#define AK_TRYQ 29           // a = the value: `expr?` (an Err or None goes back to the caller)
#define AK_SWITCH 30         // a = the value, b = the first case (a chain through ast_nx)
#define AK_CASE 31           // a = the first pattern (a chain through ast_nx; 0: `_`), b = the body, val = how many names it binds
#define AK_THROW 32          // a = the value
#define AK_TRYCATCH 33       // a = the try block, b = the catch block, val = the local of the caught text
#define AK_DEFER 34          // a = the statement
#define AK_BUILTIN 35        // val = the name (pool), a = the first argument (chain through ast_nx): alloc, arr, sizeof, move ...
#define AK_ENUMV 36          // an enum member: val = the name (pool), a = the first value (data enums)
#define AK_RAW 37            // a block of the low level (register { }, an `_.name { }` block): the tokens are skipped
#define AK_CIN 38            // `cin >> a >> b;`
#define AK_LAMBDA 39         // a = the body (a block); the parameters are locals of the body
#define AK_USING 40          // using enum Name;  using name;  (nothing runs)
#define AK_REG 41            // Reg::x0 : a register of the low level, val = the name (pool)
#define AK_LIST 27           // an initial list `{a, b, ...}`: a = the first item, the items are a chain through c

// operator codes
#define AO_ADD 1
#define AO_SUB 2
#define AO_MUL 3
#define AO_DIV 4
#define AO_MOD 5
#define AO_SHL 6
#define AO_SHR 7
#define AO_AND 8
#define AO_XOR 9
#define AO_OR 10
#define AO_LT 11
#define AO_LE 12
#define AO_GT 13
#define AO_GE 14
#define AO_EQ 15
#define AO_NE 16
#define AO_LAND 17
#define AO_LOR 18

int ast_kind[AST_MAXN];
int ast_a[AST_MAXN];
int ast_b[AST_MAXN];
int ast_c[AST_MAXN];
int ast_val[AST_MAXN];
int ast_nx[AST_MAXN];
int ast_ue[64];                  // the enums that `using enum` made visible in the body read now
int ast_cls[AST_MAXN];           // AK_ENUMV: what the name is (ast_classify), 0 when it is not resolved
char ast_pool[65536];            // names that nodes keep (methods, members, built-in names), 0 ended
int ast_plen;            // the next one in a list (the arguments of a call, the items of a list or cout, the statements of a block)
int ast_ty[AST_MAXN];            // the type of an expression node: base + 65536 * kind (kind 0 scalar, 1 pointer to, 2 array of, 3 struct)
int ast_n;
int ast_root;                    // the block of the last body read (0: it is not in the subset)

// the locals of the body: names (the probe's own table; the parameters come first)
char ast_lname[16384];           // 256 x 64
int ast_usig[1024];               // by the unique number of a local: the signature (its number) of the function pointer that it is, else -1
int ast_lid[256];                // the unique number of each local of the body (a slot of this table is reused when a block ends)
int ast_nuid;
int ast_uname[1024];             // unique number -> the name (an offset in ast_pool)
int ast_lkind[256];              // 0 a scalar, 1 a pointer, 2 a fixed array of one dimension, 3 a struct
int ast_ndims = 1;               // the dimensions of the name that ast_name_node read (a fixed array)
int ast_ldims[256];              // a fixed array: how many dimensions
int ast_lbase[256];              // the width code of the scalar / the pointee / the element (16 + n: the struct n)
int ast_nl;
int ast_ok;                      // 0 while reading, set to 0 by the first thing that is not understood
char ast_why[128];
int ast_lower_on = 1;            // the functions of the subset are built from the tree (jc_astlow.j); -noast: all from the text
int ast_main_on = 1;             // main is made from the tree too (-noastmain: from the text)
int ast_lower_report;            // -ast2: a line for every function that was tried
int ast_report;                  // -xast
int ast_dump;                    // -xastdump: the tree of every body that is in the subset
int ast_funcs;                   // all bodies read / the ones in the subset (for -xast)
int ast_funcs_ok;
int ast_loop_depth;
int ast_in_cout;                 // 1 while an item of cout is read: `<<` is the stream there, a shift is written `shl`

void ast_fail(char^ why) {
    if ast_ok == 1 {
        ast_ok = 0;
        str_copy(@ast_why, why, 90);
        // the token where it happened
        int n = str_len(@ast_why);
        if n < 100 && tok_kind != T_EOF {
            ast_why[n] = ' ';
            ast_why[n + 1] = '[';
            int k = 0;
            while tok_text[k] != 0 && k < 20 {
                ast_why[n + 2 + k] = tok_text[k];
                k += 1;
            }
            ast_why[n + 2 + k] = ']';
            ast_why[n + 3 + k] = 0;
            // and the line: the file of the token is the one that is read now
            int len2 = str_len(@ast_why);
            if len2 < 110 {
                ast_why[len2] = ' ';
                ast_why[len2 + 1] = '@';
                int ln = cur_line;
                char d[12];
                int dn = 0;
                if ln == 0 { d[0] = '0'; dn = 1; }
                while ln > 0 && dn < 10 {
                    d[dn] = '0' + ln % 10;
                    ln = ln / 10;
                    dn += 1;
                }
                int di = 0;
                while dn > 0 {
                    dn -= 1;
                    ast_why[len2 + 2 + di] = d[dn];
                    di += 1;
                }
                ast_why[len2 + 2 + di] = 0;
            }
        }
    }
}

int ast_cur_ty;                  // the type the next node gets (set by the caller, used and cleared by ast_node)

// keep the current token's text in the pool, return its offset
int ast_pool_add(char^ t) {
    int at = ast_plen;
    int k = 0;
    while t[k] != 0 && at + k < 65000 {
        ast_pool[at + k] = t[k];
        k += 1;
    }
    ast_pool[at + k] = 0;
    ast_plen = at + k + 1;
    return at;
}

int ast_mkty(int kind, int base) {
    return base + 65536 * kind;
}

int ast_node(int kind, int a, int b, int c, int val) {
    if ast_n >= AST_MAXN - 1 {
        ast_fail("the body is too big for the tree");
        return 0;
    }
    ast_n += 1;
    ast_ty[ast_n] = ast_cur_ty;
    ast_cur_ty = 0;
    ast_nx[ast_n] = 0;
    ast_kind[ast_n] = kind;
    ast_a[ast_n] = a;
    ast_b[ast_n] = b;
    ast_c[ast_n] = c;
    ast_val[ast_n] = val;
    return ast_n;
}

// a copy of the tree of a place (a variable, a field, an element, a dereference), for a target that is also read
int ast_clone(int n) {
    int k = ast_kind[n];
    ast_cur_ty = ast_ty[n];
    if k == AK_VAR || k == AK_GVAR || k == AK_NUM { return ast_node(k, 0, ast_b[n], ast_c[n], ast_val[n]); }
    if k == AK_FIELD || k == AK_DEREF {
        int a2 = ast_clone(ast_a[n]);
        if ast_ok == 0 { return 0; }
        ast_cur_ty = ast_ty[n];
        return ast_node(k, a2, ast_b[n], ast_c[n], ast_val[n]);
    }
    if k == AK_INDEX {
        int ia = ast_clone(ast_a[n]);
        if ast_ok == 0 { return 0; }
        int ib = ast_clone(ast_b[n]);
        if ast_ok == 0 { return 0; }
        ast_cur_ty = ast_ty[n];
        return ast_node(k, ia, ib, ast_c[n], ast_val[n]);
    }
    ast_fail("a target that cannot be copied in the tree");
    return 0;
}

int ast_find_local(char^ name) {
    int i = ast_nl - 1;
    while i >= 0 {
        if str_eq(@ast_lname + i * 64, name) { return i; }
        i -= 1;
    }
    return 0 - 1;
}

int ast_add_local(char^ name) {
    if ast_nl >= 256 {
        ast_fail("too many locals");
        return 0 - 1;
    }
    str_copy(@ast_lname + ast_nl * 64, name, 64);
    ast_lid[ast_nl] = ast_nuid;
    if ast_nuid < 1023 {
        ast_uname[ast_nuid] = ast_pool_add(name);
        ast_usig[ast_nuid] = 0 - 1;
        ast_nuid += 1;
    }
    ast_lkind[ast_nl] = 0;
    ast_lbase[ast_nl] = 8;
    ast_ldims[ast_nl] = 1;
    ast_nl += 1;
    return ast_nl - 1;
}

// the type of `a op b` for numbers: a double if one is, else a float if both are, else u64 if one is, else int
int ast_arith_ty(int ta, int tb) {
    int ba = ta % 65536;
    int bb = tb % 65536;
    if ba == 7 || bb == 7 { return ast_mkty(0, 7); }
    if ba == 6 || bb == 6 { return ast_mkty(0, 6); }
    if ba == 13 || bb == 13 { return ast_mkty(0, 13); }
    return ast_mkty(0, 8);
}

// a decimal literal or a calculation of them: the text path gives it the type "a decimal number", which becomes float or double as needed
bool ast_is_flit(int n) {
    if n == 0 { return false; }
    int k = ast_kind[n];
    if k == AK_FNUM { return true; }
    if k == AK_NEG { return ast_is_flit(ast_a[n]); }
    if k == AK_BIN { return ast_val[n] >= AO_ADD && ast_val[n] <= AO_DIV && ast_is_flit(ast_a[n]) && ast_is_flit(ast_b[n]); }
    return false;
}

// the element of a dynamic array T[]: kept in the base of a kind 5 type as  element kind * 1000 + element code  (the packed type of the
// parser says it: dyn_code, dyn_ptr, dyn_tid); 0 when it is not known
int ast_dyn_base(int info) {
    if info == 0 { return 0; }
    if is_strarr_dyn(info) { return 4008; }
    int code = dyn_code(info);
    int ptr = dyn_ptr(info);
    int tid = dyn_tid(info);
    if ptr >= 2 { return 1400 + code; }
    if ptr == 1 { return 1000 + code; }
    if tid >= 3 && tid < 90 { return 6000 + tid; }
    if code >= 16 { return 3000 + code; }
    return code;
}

// the type of the result of a function (fret is the type id: 0 a number, 1 a bool, 90 float, 91 double, 93 u8, 94 u32, 95 u64, 100 + n a struct)
int ast_fn_ty(int fi) {
    int t = fret[fi];
    if fretdyn[fi] != 0 {
        if is_str_dyn(fretdyn[fi]) { return ast_mkty(4, 8); }
        return ast_mkty(5, ast_dyn_base(fretdyn[fi]));
    }
    if t >= 3 && t < 90 { return ast_mkty(6, t); }
    if t == 1 { return ast_mkty(0, 3); }
    if t == 90 { return ast_mkty(0, 6); }
    if t == 91 { return ast_mkty(0, 7); }
    if t == 93 { return ast_mkty(0, 11); }
    if t == 94 { return ast_mkty(0, 12); }
    if t == 95 { return ast_mkty(0, 13); }
    if t >= 100 { return ast_mkty(3, 16 + t - 100); }
    if fcharret[fi] == 1 { return ast_mkty(0, 2); }
    if fcharret[fi] == 2 { return ast_mkty(1, 2); }
    return ast_mkty(0, 8);
}

// is the code a scalar of the subset (no struct, no enum, no String)?
bool ast_scalar_code(int code) {
    return code >= 1 && code <= 15;
}

// a scalar or a struct
bool ast_value_code(int code) {
    return (code >= 1 && code <= 15) || (code >= 16 && code < 16 + scount) || (code >= 3 && code < 90) || (code >= 400 && code < 416 + scount);
}

// the parameters and the locals that the parser has already: scalars, structs, pointers to them and fixed arrays
int ast_np0;                       // the locals of the parser when the body began (the parameters): their numbers are the parser's

void ast_load_params() {
    ast_nl = 0;
    ast_plen = 0;
    ast_np0 = lcount;
    int i = 0;
    while i < lcount {
        int li = ast_add_local(@lname + i * 64);
        if li < 0 { return; }
        if ltid[i] < 0 && ast_lid[li] < 1023 { ast_usig[ast_lid[li]] = 0 - ltid[i] - 1; }
        // `self` of a method of a generic instance (Option<String>) carries the dynamic type of T: it is still the address of the struct
        bool self_ptr = str_eq(@lname + i * 64, "self") && ldyn[i] != 0 && (lptr[i] != 0 || lelem[i] >= 16);
        if ldyn[i] != 0 && !self_ptr {
            if is_str_dyn(ldyn[i]) { ast_lkind[li] = 4; ast_lbase[li] = 8; } else { ast_lkind[li] = 5; ast_lbase[li] = ast_dyn_base(ldyn[i]); }
            i += 1;
            continue;
        }
        if ltid[i] >= 3 && ltid[i] < 90 && lkind[i] == 0 && lptr[i] == 0 {
            ast_lkind[li] = 6;
            ast_lbase[li] = ltid[i];
            i += 1;
            continue;
        }
        if lkind[i] == 1 {
            if !ast_value_code(lelem[i]) {
                ast_fail("a parameter that is an array of structs of a type not in the subset");
                return;
            }
            ast_lkind[li] = 2;
            ast_lbase[li] = lelem[i];
            ast_ldims[li] = lnd[i];
        } else if lptr[i] != 0 {
            if !ast_value_code(lptr[i]) {
                ast_fail("a parameter that is a pointer to a pointer");
                return;
            }
            ast_lkind[li] = 1;
            ast_lbase[li] = lptr[i];
        } else {
            if !ast_value_code(lelem[i]) {
                ast_fail("a parameter of a type that is not in the subset");
                return;
            }
            if lelem[i] >= 16 { ast_lkind[li] = 3; }
            ast_lbase[li] = lelem[i];
        }
        i += 1;
    }
}

// ---------------------------------------------------------------- expressions
// the code of the scalar type that the current token names (0: it is not one)
int ast_type_kw() {
    if tok_kind != T_IDENT { return 0; }
    if tok_is("int") { return 8; }
    if tok_is("char") { return 2; }
    if tok_is("bool") { return 3; }
    if tok_is("i8") { return 1; }
    if tok_is("i32") { return 4; }
    if tok_is("float") || tok_is("f32") { return 6; }
    if tok_is("double") || tok_is("f64") { return 7; }
    if tok_is("u8") { return 11; }
    if tok_is("u32") { return 12; }
    if tok_is("u64") { return 13; }
    if tok_is("void") { return 10; }
    return 0;
}

// the kind (0 scalar, 1 pointer, 2 array) and base code of a global; -1 when it is not in the subset
int ast_gkind;
int ast_gbase;
int ast_gdims;
bool ast_global_ok(int gi) {
    if gdyn[gi] != 0 {
        if is_str_dyn(gdyn[gi]) { ast_gkind = 4; ast_gbase = 8; } else { ast_gkind = 5; ast_gbase = ast_dyn_base(gdyn[gi]); }
        return true;
    }
    if gtid[gi] >= 3 && gtid[gi] < 90 && gkind[gi] == 0 && gptr[gi] == 0 {
        ast_gkind = 6;
        ast_gbase = gtid[gi];
        return true;
    }
    ast_gkind = 0;
    ast_gbase = gelem[gi];
    ast_gdims = 1;
    if gkind[gi] == 1 {
        ast_gkind = 2;
        ast_gdims = gnd[gi];
    } else if gptr[gi] != 0 {
        ast_gkind = 1;
        ast_gbase = gptr[gi];
    } else if gelem[gi] >= 16 {
        ast_gkind = 3;
    }
    return ast_value_code(ast_gbase);
}


int ast_call(int fidx) {
    // the name and `(` were read
    int first = 0;
    int last = 0;
    int n = 0;
    next();                                  // (
    if !tok_is(")") {
        while true {
            int e = ast_expr(0);
            if ast_ok == 0 { return 0; }
            // the arguments are a chain through c
            if first == 0 { first = e; } else { ast_nx[last] = e; }
            last = e;
            n += 1;
            if tok_is(",") { next(); } else { break; }
        }
    }
    if !tok_is(")") {
        ast_fail("a call that is not understood");
        return 0;
    }
    next();
    if n != fnpar[fidx] {
        ast_fail("a call with another number of arguments");
        return 0;
    }
    ast_cur_ty = ast_fn_ty(fidx);
    return ast_node(AK_CALL, first, 0, 0, fidx);
}

// `[index]`, `^`, `?`, `.field` and `.method(args)` after a name, with the type that the chain has: kind 0 scalar, 1 pointer, 2 array,
// 3 struct, 4 String, 5 dynamic array, 6 enum; base: the width code of the scalar / pointee / element, 16 + n for the struct n
// the type of the result of a method of a String (kind 4) or a dynamic array (kind 5, element in base): void is kind 7; kind 8 when not known
int ast_member_ty(int kind, int base, char^ n) {
    int unknown = ast_mkty(8, 0);
    if kind == 4 {
        if str_eq(n, "push") || str_eq(n, "append") || str_eq(n, "clear") || str_eq(n, "free") || str_eq(n, "insert") { return ast_mkty(7, 0); }
        if str_eq(n, "slice") || str_eq(n, "trim") || str_eq(n, "upper") || str_eq(n, "lower") || str_eq(n, "replace") || str_eq(n, "repeat") { return ast_mkty(4, 8); }
        if str_eq(n, "find") || str_eq(n, "count") || str_eq(n, "to_int") { return ast_mkty(0, 8); }
        if str_eq(n, "to_double") { return ast_mkty(0, 7); }
        if str_eq(n, "starts_with") || str_eq(n, "ends_with") || str_eq(n, "contains") { return ast_mkty(0, 3); }
        if str_eq(n, "c") { return ast_mkty(1, 2); }
        if str_eq(n, "char_at") || str_eq(n, "pop") { return ast_mkty(0, 2); }
        if str_eq(n, "split") { return ast_mkty(5, 4008); }
        return unknown;
    }
    if kind == 5 {
        if str_eq(n, "push") || str_eq(n, "clear") || str_eq(n, "free") || str_eq(n, "resize") || str_eq(n, "sort") || str_eq(n, "insert") { return ast_mkty(7, 0); }
        if str_eq(n, "contains") { return ast_mkty(0, 3); }
        if str_eq(n, "index_of") { return ast_mkty(0, 8); }
        if str_eq(n, "join") { return ast_mkty(4, 8); }
        if (str_eq(n, "pop") || str_eq(n, "get") || str_eq(n, "at") || str_eq(n, "remove")) && base >= 1 {
            return ast_mkty(base / 1000, base % 1000);
        }
        return unknown;
    }
    return unknown;
}

int ast_pkind;
int ast_pbase;

// `(a, b)` of a call: the current token is `(`; returns the first argument (0: none), the others are chained through ast_nx
int ast_args_n;
int ast_args() {
    next();                                  // (
    int first = 0;
    int last = 0;
    ast_args_n = 0;
    if !tok_is(")") {
        while true {
            int e = ast_expr(0);
            if ast_ok == 0 { return 0; }
            if first == 0 { first = e; } else { ast_nx[last] = e; }
            last = e;
            ast_args_n += 1;
            if tok_is(",") { next(); } else { break; }
        }
    }
    if !tok_is(")") {
        ast_fail("a call that is not understood");
        return 0;
    }
    next();
    return first;
}

int ast_pdims;
int ast_postfix(int base, int kind, int tb) {
    int cur = base;
    ast_pkind = kind;
    ast_pbase = tb;
    ast_pdims = ast_ndims;
    ast_ndims = 1;
    while true {
        if tok_is("[") && ast_pkind != 3 {
            int kind_before = ast_pkind;
            int base_before = ast_pbase;
            int dims_before = ast_pdims;
            next();
            int ix = ast_expr(0);
            if ast_ok == 0 { return 0; }
            ast_pkind = kind_before;
            ast_pbase = base_before;
            ast_pdims = dims_before;
            int slice_hi = 0;
            if tok_is(".") {
                // a view a[lo..hi]
                next();
                if !tok_is(".") {
                    ast_fail("a slice that is not understood");
                    return 0;
                }
                next();
                slice_hi = ast_expr(0);
                if ast_ok == 0 { return 0; }
                ast_pkind = kind_before;
                ast_pbase = base_before;
                ast_pdims = dims_before;
            }
            if !tok_is("]") {
                ast_fail("an index that is not understood");
                return 0;
            }
            next();
            if ast_pkind == 4 {
                ast_pkind = 0;
                ast_pbase = 2;
            } else if ast_pkind == 5 && ast_pbase >= 1 {
                // the element of a dynamic array
                int ek = ast_pbase / 1000;
                ast_pbase = ast_pbase % 1000;
                ast_pkind = ek;
                ast_pdims = 1;
            } else if ast_pkind == 5 || ast_pkind == 8 {
                ast_pkind = 8;
                ast_pbase = 0;                       // the element type of a dynamic array is not known
            } else if ast_pkind == 2 && ast_pdims > 1 {
                ast_pdims -= 1;                      // a row of a table: still an array
            } else if ast_pbase >= 400 {
                ast_pkind = 1;
                ast_pbase = ast_pbase - 400;
            } else if ast_pbase >= 16 && ast_pbase < 400 {
                ast_pkind = 3;
            } else {
                ast_pkind = 0;
            }
            if slice_hi != 0 {
                // the view keeps the kind of the array
                ast_pkind = kind_before;
                ast_pbase = base_before;
            }
            ast_cur_ty = ast_mkty(ast_pkind, ast_pbase);
            cur = ast_node(AK_INDEX, cur, ix, slice_hi, 0);
        } else if tok_is("^") && (ast_pkind == 1 || ast_pkind == 8 || (ast_pkind == 0 && ast_pbase == 0)) {
            next();
            if ast_pbase >= 400 {
                ast_pkind = 1;
                ast_pbase = ast_pbase - 400;
            } else if ast_pbase >= 16 {
                ast_pkind = 3;
            } else {
                ast_pkind = 0;
            }
            ast_cur_ty = ast_mkty(ast_pkind, ast_pbase);
            cur = ast_node(AK_DEREF, cur, 0, 0, 0);
        } else if tok_is("^") && ast_pkind == 6 {
            // `self^` in a method of a data enum: self is the address of the enum value
            next();
            ast_cur_ty = ast_mkty(6, ast_pbase);
            cur = ast_node(AK_DEREF, cur, 0, 0, 0);
        } else if tok_is("(") && (ast_pkind == 0 || ast_pkind == 1 || ast_pkind == 8) && (ast_kind[cur] == AK_VAR || ast_kind[cur] == AK_GVAR || ast_kind[cur] == AK_FIELD || ast_kind[cur] == AK_INDEX || ast_kind[cur] == AK_CALL || ast_kind[cur] == AK_METHOD) {
            // a call through a pointer to a function: f(a, b)
            int cargs = ast_args();
            if ast_ok == 0 { return 0; }
            ast_pkind = 0;
            ast_pbase = 8;
            ast_cur_ty = ast_mkty(0, 8);
            cur = ast_node(AK_CALL, cargs, cur, 0, 0 - 1);
        } else if tok_is("?") {
            next();
            ast_pkind = 8;
            ast_pbase = 0;
            ast_cur_ty = ast_mkty(8, 0);
            cur = ast_node(AK_TRYQ, cur, 0, 0, 0);
        } else if tok_is(".") {
            // a field or a method (not `..` of a range: the caller of a range reads the first `.` itself)
            int sv_pos = cur_pos;
            int sv_line = cur_line;
            int sv_ls = cur_line_start;
            bool two_dots = lc(0) == '.';
            cur_pos = sv_pos;
            cur_line = sv_line;
            cur_line_start = sv_ls;
            if two_dots { break; }
            next();
            if tok_kind != T_IDENT {
                ast_fail("a field name was expected");
                return 0;
            }
            if ast_pkind == 1 && ast_kind[cur] == AK_VAR && str_eq(@tok_text, "len") {
                // `a.len` of a parameter `T a[]` (an array of structs too): the hidden local a__len
                int qli = 0;
                bool qgot = false;
                while qli < ast_nl {
                    if ast_lid[qli] == ast_val[cur] {
                        char qln[96];
                        str_copy(@qln, @ast_lname + qli * 64, 64);
                        str_copy(@qln + str_len(@qln), "__len", 8);
                        int qlen = ast_find_local(@qln);
                        if qlen >= 0 {
                            next();
                            ast_pkind = 0;
                            ast_pbase = 8;
                            ast_ndims = 0;
                            ast_cur_ty = ast_mkty(0, 8);
                            cur = ast_node(AK_VAR, 0, 0, 0, ast_lid[qlen]);
                            qli = ast_nl;
                            qgot = true;
                        }
                    }
                    qli += 1;
                }
                if qgot { continue; }
            }
            if ast_pkind == 1 && ast_pbase >= 16 {
                // a pointer to a struct used like the struct (the `self` of a method, a name in a case)
                ast_cur_ty = ast_mkty(3, ast_pbase);
                cur = ast_node(AK_DEREF, cur, 0, 0, 0);
                ast_pkind = 3;
            }
            char mn[64];
            str_copy(@mn, @tok_text, 64);
            int st = 0 - 1;
            if ast_pkind == 3 { st = ast_pbase - 16; }
            int fi = 0 - 1;
            if st >= 0 { fi = find_field(st, @mn); }
            next();
            if tok_is("(") {
                // a method: the user's `Struct__name`, or a member of String / a dynamic array / a library struct
                int rty = ast_mkty(8, 0);
                if st >= 0 && st < scount {
                    char full[128];
                    str_copy(@full, @sname + st * 64, 64);
                    int k = str_len(@full);
                    full[k] = '_';
                    full[k + 1] = '_';
                    int j = 0;
                    while mn[j] != 0 && k + 2 + j < 120 {
                        full[k + 2 + j] = mn[j];
                        j += 1;
                    }
                    full[k + 2 + j] = 0;
                    int mf = find_func(@full);
                    if mf >= 0 { rty = ast_fn_ty(mf); }
                }
                if rty / 65536 == 8 && (ast_pkind == 4 || ast_pkind == 5) { rty = ast_member_ty(ast_pkind, ast_pbase, @mn); }
                int kb2 = ast_pkind;
                int bb2 = ast_pbase;
                int db2 = ast_pdims;
                int args = ast_args();
                if ast_ok == 0 { return 0; }
                ast_pkind = kb2;
                ast_pbase = bb2;
                ast_pdims = db2;
                ast_cur_ty = rty;
                int mnode = ast_node(AK_METHOD, cur, args, 0, ast_pool_add(@mn));
                cur = mnode;
                ast_pkind = rty / 65536;
                ast_pbase = rty % 65536;
            } else if fi >= 0 {
                if fldkind[fi] == 1 {
                    if !ast_value_code(fldcode[fi]) {
                        ast_fail("a field that is an array of a type not in the subset");
                        return 0;
                    }
                    ast_pkind = 2;
                    ast_pbase = fldcode[fi];
                    ast_pdims = fldnd[fi];
                } else if flddyn[fi] != 0 {
                    if is_str_dyn(flddyn[fi]) { ast_pkind = 4; ast_pbase = 8; } else { ast_pkind = 5; ast_pbase = ast_dyn_base(flddyn[fi]); }
                } else if fldptr[fi] != 0 {
                    if !ast_value_code(fldptr[fi]) {
                        ast_fail("a field that is a pointer to a pointer");
                        return 0;
                    }
                    ast_pkind = 1;
                    ast_pbase = fldptr[fi];
                } else if fldtid[fi] >= 3 && fldtid[fi] < 90 {
                    ast_pkind = 6;
                    ast_pbase = fldtid[fi];
                } else {
                    if !ast_value_code(fldcode[fi]) {
                        ast_fail("a field of a type that is not in the subset");
                        return 0;
                    }
                    if fldcode[fi] >= 16 { ast_pkind = 3; } else { ast_pkind = 0; }
                    ast_pbase = fldcode[fi];
                }
                ast_cur_ty = ast_mkty(ast_pkind, ast_pbase);
                cur = ast_node(AK_FIELD, cur, 0, 0, fi);
            } else {
                // a member that is not a field of a user struct: len, cap ... of a String or a dynamic array, a member of a library type
                int plen = 0 - 1;
                if str_eq(@mn, "len") && ast_kind[cur] == AK_VAR {
                    // `a.len` of a parameter `T a[]`: the hidden local a__len
                    int pli = 0;
                    while pli < ast_nl {
                        if ast_lid[pli] == ast_val[cur] {
                            char pln[96];
                            str_copy(@pln, @ast_lname + pli * 64, 64);
                            str_copy(@pln + str_len(@pln), "__len", 8);
                            plen = ast_find_local(@pln);
                        }
                        pli += 1;
                    }
                }
                ast_pkind = 0;
                ast_pbase = 8;
                ast_cur_ty = ast_mkty(0, 8);
                if plen >= 0 {
                    ast_ndims = 0;
                    cur = ast_node(AK_VAR, 0, 0, 0, ast_lid[plen]);
                } else {
                    cur = ast_node(AK_FIELD, cur, ast_pool_add(@mn) + 1, 0, 0 - 1);
                }
            }
        } else {
            break;
        }
    }
    return cur;
}

int ast_nbase;                   // the base code of the name that ast_name_node read
int ast_nkind;                   // the kind (0 scalar, 1 pointer, 2 array) of the name that ast_name_node read

int ast_name_node() {
    // a name (the current token) that is a local or a global of the subset: a node (0 when it is not); the kind in ast_nkind
    char nm[64];
    str_copy(@nm, @tok_text, 64);
    int li = ast_find_local(@nm);
    if li >= 0 {
        next();
        ast_nkind = ast_lkind[li];
        ast_nbase = ast_lbase[li];
        ast_ndims = ast_ldims[li];
        ast_cur_ty = ast_mkty(ast_nkind, ast_nbase);
        return ast_node(AK_VAR, 0, 0, 0, ast_lid[li]);
    }
    int gi = find_global(@nm);
    if gi >= 0 && ast_global_ok(gi) {
        next();
        ast_nkind = ast_gkind;
        ast_nbase = ast_gbase;
        ast_ndims = ast_gdims;
        ast_cur_ty = ast_mkty(ast_nkind, ast_nbase);
        return ast_node(AK_GVAR, 0, 0, 0, gi);
    }
    // a function used as a value, or a member of an enum made visible by `using enum`: a name of the program, kept by its text
    int poolat = ast_pool_add(@nm);
    next();
    ast_nkind = 0;
    ast_nbase = 8;
    ast_ndims = 1;
    ast_cur_ty = ast_mkty(0, 8);
    char noq[4];
    noq[0] = 0;
    return ast_enumv(0, 0, ast_classify(@noq, @ast_pool + poolat), poolat);
}
// the next characters after the current token (without reading): `::`
bool ast_colons_follow() {
    int sv_pos = cur_pos;
    int sv_line = cur_line;
    int sv_ls = cur_line_start;
    while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
    bool r = lc(0) == ':' && lc(1) == ':';
    cur_pos = sv_pos;
    cur_line = sv_line;
    cur_line_start = sv_ls;
    return r;
}

// `Name::function(args)`, `Enum::Member`, `Enum::Member(values)`, `Reg::x5`: the current token is Name. A function is named Name__function
int ast_enumv(int a, int b, int cls, int val) {
    int n = ast_node(AK_ENUMV, a, b, 0, val);
    if n > 0 { ast_cls[n] = cls; }
    return n;
}

// what a name is that the tree keeps by its text (an AK_ENUMV node; the code goes to the field c):
// 1 a member of an enum, 2 a member of a data enum, 3 a member made visible by `using enum`, 4 a function used as a value,
// 5 a qualified name of the library (`Math::pi`), 6 a device, 0 not resolved
int ast_classify(char^ qual, char^ name) {
    if qual[0] != 0 {
        int en = find_enum(qual);
        if en >= 0 {
            if find_member(en, name) { return 1; }
            return 0;
        }
        if gen_is_template(qual) || find_struct(qual) >= 0 { return 2; }
        return 5;
    }
    int dvi = 0;
    while dvi < dv_count_of() {
        if dv_variant(dvi, name) >= 0 { return 3; }
        dvi += 1;
    }
    int uen2 = 0;
    while uen2 < ecount && uen2 < 64 {
        if ast_ue[uen2] == 1 && find_member(uen2, name) { return 3; }
        uen2 += 1;
    }
    int keep_ty = ex_ty;
    int keep_val = found_val;
    bool um = find_using_member(name);
    ex_ty = keep_ty;
    found_val = keep_val;
    if um { return 3; }
    if find_device(name) >= 0 { return 6; }
    if find_func(name) >= 0 || gen_is_template(name) { return 4; }
    if ast_resolve_func(name) != 0 - 1 { return 4; }
    return 0;
}

// `module.function(...)`: the current token is the name of a module that `using` has opened, a dot follows and then a static function
// of the struct that holds it (see module_dot in jc_expr.j). On success the token becomes the name of the struct. A module that is not
// open is not read here: the body stays on the text path, which gives the message.
bool ast_module_dot() {
    if tok_kind != T_IDENT || tok_text[0] < 'a' || tok_text[0] > 'z' { return false; }
    if ast_find_local(@tok_text) >= 0 || find_global(@tok_text) >= 0 || find_func(@tok_text) >= 0 || find_device(@tok_text) >= 0 || find_enum(@tok_text) >= 0 { return false; }
    int row = mod_find("", @tok_text);
    if row < 0 { return false; }
    char^ stn = mod_row(row, 2);
    int k = 0;
    while lc(k) == ' ' || lc(k) == 9 { k += 1; }
    if lc(k) != '.' || lc(k + 1) == '.' { return false; }
    k += 1;
    while lc(k) == ' ' || lc(k) == 9 { k += 1; }
    char fnm[64];
    int j = 0;
    while (is_alnum(lc(k + j)) || lc(k + j) == '_') && j < 62 {
        fnm[j] = lc(k + j);
        j += 1;
    }
    fnm[j] = 0;
    if j == 0 { return false; }
    char full[200];
    str_copy(@full, stn, 64);
    int n = str_len(@full);
    full[n] = '_';
    full[n + 1] = '_';
    str_copy(@full + n + 2, mod_row(row, 3), 20);
    str_copy(@full + str_len(@full), @fnm, 60);
    int fi = find_func(@full);
    if fi < 0 || fself[fi] == 1 || !mod_open(row, @fnm) { return false; }
    str_copy(@tok_text, stn, 64);
    str_copy(@mod_prefix, mod_row(row, 3), 60);
    return true;
}

int ast_static_call(bool as_value) {
    char full[128];
    char full_q[64];
    str_copy(@full, @tok_text, 64);
    str_copy(@full_q, @tok_text, 64);
    int is_enum = find_enum(@full);
    bool is_reg = str_eq(@full, "Reg");
    next();                                  // Name
    next();                                  // ::
    if tok_kind != T_IDENT {
        ast_fail("a name was expected after ::");
        return 0;
    }
    if is_enum < 0 && lc(0) == '.' && lc(1) != '.' {
        // Fs::fs.read(p) : the namespace, the module, the function
        int mrow = mod_find(@full, @tok_text);
        if mrow >= 0 {
            str_copy(@full, mod_row(mrow, 2), 64);
            str_copy(@mod_prefix, mod_row(mrow, 3), 60);
            next();                              // the module
            next();                              // the dot
            if tok_kind != T_IDENT {
                ast_fail("a function name was expected after the dot");
                return 0;
            }
        }
    }
    mod_apply_prefix();                      // a module of a merged struct: the function is named <module>_<name>
    if is_reg {
        int rpool = ast_pool_add(@tok_text);
        next();
        ast_cur_ty = ast_mkty(0, 8);
        return ast_node(AK_REG, 0, 0, 0, rpool);
    }
    int k = str_len(@full);
    full[k] = '_';
    full[k + 1] = '_';
    int j = 0;
    while tok_text[j] != 0 && k + 2 + j < 120 {
        full[k + 2 + j] = tok_text[j];
        j += 1;
    }
    full[k + 2 + j] = 0;
    int fi = find_func(@full);
    if fi < 0 {
        // a member of an enum (or a name of the library that is not a function: `Math::pi`)
        int poolat = ast_pool_add(@tok_text);
        next();
        int args = 0;
        if tok_is("(") {
            args = ast_args();
            if ast_ok == 0 { return 0; }
        }
        if is_enum >= 0 {
            ast_cur_ty = ast_mkty(6, 3 + is_enum);
        } else {
            ast_cur_ty = ast_mkty(0, 0);
        }
        return ast_enumv(args, 0, ast_classify(@full_q, @ast_pool + poolat), poolat);
    }
    if fop[fi] == 1 {
        ast_fail("a static function that is an operator");
        return 0;
    }
    if as_value && fvoid[fi] == 1 {
        ast_fail("a static function that returns nothing used as a value");
        return 0;
    }
    int pool2 = ast_pool_add(@tok_text);
    next();                                  // the function name; the current token is (
    if !tok_is("(") {
        // a member of a data enum written without values (`Option::None`): the library makes it with a function that has no
        // parameter: a call
        if fnpar[fi] == 0 && fvoid[fi] == 0 && fop[fi] == 0 {
            ast_cur_ty = ast_fn_ty(fi);
            return ast_postfix(ast_node(AK_CALL, 0, 0, 0, fi), ast_cur_ty / 65536, ast_cur_ty % 65536);
        }
        ast_cur_ty = ast_mkty(0, 0);
        return ast_enumv(0, 0, ast_classify(@full_q, @ast_pool + pool2), pool2);
    }
    int cn = ast_call(fi);
    if ast_ok == 0 { return 0; }
    int rt = ast_ty[cn];
    ast_ndims = 1;
    return ast_postfix(cn, rt / 65536, rt % 65536);
}

// the function a plain name means: its own, a generic that infers its types (-2), or a static function of a struct in `using`
int ast_resolve_func(char^ name) {
    int f = find_func(name);
    if f >= 0 { return f; }
    if gen_is_template(name) { return 0 - 2; }
    int k = 0;
    while k < scount {
        if us_g[k] == 1 || us_l[k] == 1 {
            char full[256];
            str_copy(@full, @sname + k * 64, 64);
            str_copy(@full + str_len(@full), "__", 4);
            str_copy(@full + str_len(@full), name, 100);
            int g = find_func(@full);
            if g >= 0 { return g; }
        }
        k += 1;
    }
    return 0 - 1;
}

// the names that the compiler knows and that are not functions of the program or the library
bool ast_is_builtin(char^ n) {
    if n[0] == '_' && n[1] == '_' { return true; }
    if n[0] == 'a' && n[1] == 'l' && n[2] == 'l' && n[3] == 'o' && n[4] == 'c' { return true; }
    return str_eq(n, "alloc") || str_eq(n, "str") || str_eq(n, "free") || str_eq(n, "arr") || str_eq(n, "sizeof") || str_eq(n, "move") || str_eq(n, "panic")
        || str_eq(n, "assert") || str_eq(n, "argc") || str_eq(n, "arg") || str_eq(n, "syscall") || str_eq(n, "exit") || str_eq(n, "len")
        || str_eq(n, "__fsqrt") || str_eq(n, "__cas") || str_eq(n, "pool") || str_eq(n, "grow") || str_eq(n, "arr_of");
}

// `T(` after a type word: a lambda `int(int a, int b) { return a + b; }`
bool ast_lambda_follows() {
    int sv_pos = cur_pos;
    int sv_line = cur_line;
    int sv_ls = cur_line_start;
    while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
    bool r = lc(0) == '(';
    cur_pos = sv_pos;
    cur_line = sv_line;
    cur_line_start = sv_ls;
    return r;
}

int ast_lam0;                      // the number of the first lambda that the text path makes in the body being read
int ast_lam_k;                     // lambdas met so far (not counting those written inside another lambda)
int ast_lam_depth;

int ast_lambda() {
    int lam_no = 0 - 1;
    if ast_lam_depth == 0 {
        lam_no = ast_lam0 + ast_lam_k;
        ast_lam_k += 1;
    }
    ast_lam_depth += 1;
    next();                                  // the result type
    next();                                  // (
    int saved_nl = ast_nl;
    int saved_loop = ast_loop_depth;
    ast_loop_depth = 0;
    while !tok_is(")") {
        if ast_type_kw() == 0 && !(tok_kind == T_IDENT && find_struct(@tok_text) >= 0) && !tok_is("String") {
            ast_fail("a parameter of a lambda that is not understood");
            return 0;
        }
        int pt = ast_type_kw();
        next();
        while tok_is("^") { next(); }
        if tok_kind != T_IDENT {
            ast_fail("a parameter of a lambda that is not understood");
            return 0;
        }
        int pl = ast_add_local(@tok_text);
        if pl >= 0 {
            ast_lkind[pl] = 0;
            ast_lbase[pl] = pt;
        }
        next();
        if tok_is(",") { next(); }
    }
    next();
    int body = ast_block();
    ast_nl = saved_nl;
    ast_loop_depth = saved_loop;
    ast_lam_depth -= 1;
    if ast_ok == 0 { return 0; }
    ast_cur_ty = ast_mkty(0, 8);
    return ast_node(AK_LAMBDA, body, 0, 0, lam_no);
}

// the name in the pool is one of the instructions of the double unit: 1 sqrt, 2 floor, 3 ceil, 4 trunc (0 for another name)
int ast_fop_of(int at) {
    if at < 0 { return 0; }
    char^ nm = @ast_pool + at;
    if str_eq(nm, "__fsqrt") { return 1; }
    if str_eq(nm, "__ffloor") { return 2; }
    if str_eq(nm, "__fceil") { return 3; }
    if str_eq(nm, "__ftrunc") { return 4; }
    if str_eq(nm, "alloc") { return 5; }            // alloc(n): the address of a block (typed as a whole number, a cast gives the pointer)
    if str_eq(nm, "free") { return 6; }
    if str_eq(nm, "arr") { return 7; }              // arr(n): a new dynamic array (only as the value of a declaration)
    if str_eq(nm, "move") { return 14; }               // move(p): the value of the owner p, which becomes null
    if str_eq(nm, "str") { return 13; }                // str(x): a new String with the number, the character or the String x
    if str_eq(nm, "argc") { return 11; }              // argc(): the number of arguments of the command line
    if str_eq(nm, "arg") { return 12; }               // arg(i): the i-th argument, a text
    if str_eq(nm, "__hash") { return 9; }             // __hash(x): a number for a key of a Map / Set (a whole number is hashed, a String too)
    if str_eq(nm, "syscall") { return 8; }          // syscall(number, args ...): the result of the system call, a whole number
    if str_eq(nm, "__cas") { return 20; }            // the atomic built-ins of std/rt_hw.j (the tree makes them only for the ARM32 target: IR_ATOMIC)
    if str_eq(nm, "__xchg") { return 21; }
    if str_eq(nm, "__fetch_add") { return 22; }
    if str_eq(nm, "__fetch_sub") { return 23; }
    if str_eq(nm, "__fetch_and") { return 24; }
    if str_eq(nm, "__fetch_or") { return 25; }
    if str_eq(nm, "__fetch_xor") { return 26; }
    if str_eq(nm, "__atomic_load") { return 27; }
    if str_eq(nm, "__atomic_store") { return 28; }
    if str_eq(nm, "__thread_start") { return 29; }    // __thread_start(function, argument, top of the stack, id word, thread block): the ARM32 target only
    return 0;
}

bool ast_is_fop(int at) {
    int o = ast_fop_of(at);
    return o >= 1 && o <= 4;
}

bool ast_is_alloc(int at) {
    return ast_fop_of(at) == 5;
}

int ast_primary() {
    if tok_kind == T_NUM {
        int isf = tok_float;
        int v = tok_num;
        int fmant = tok_mant;
        int fexp = tok_exp;
        int ischar = tok_char;
        next();
        if isf == 1 {
            ast_cur_ty = ast_mkty(0, 7);
            return ast_node(AK_FNUM, fmant, fexp, 0, 0);           // a = the mantissa, b = the power of ten (not nodes)
        }
        ast_cur_ty = ast_mkty(0, 8);
        if ischar == 1 { ast_cur_ty = ast_mkty(0, 2); }      // 'a' is a char (cout prints it as a character)
        return ast_node(AK_NUM, 0, 0, 0, v);
    }
    if tok_is("{") {
        return ast_list();
    }
    if tok_kind == T_STR {
        int sp = ast_pool_add(@tok_str);
        int sl = tok_str_len;
        next();
        ast_cur_ty = ast_mkty(4, 8);
        return ast_postfix(ast_node(AK_STR, 0, sl, 0, sp), 4, 8);
    }
    if tok_is("(") {
        next();
        int tc = ast_type_kw();
        if tc == 0 && tok_kind == T_IDENT && find_struct(@tok_text) >= 0 && ast_find_local(@tok_text) < 0 && ast_cast_follows() { tc = 16 + find_struct(@tok_text); }
        if tc == 0 && tok_kind == T_IDENT && find_enum(@tok_text) >= 0 && ast_find_local(@tok_text) < 0 && ast_cast_follows() { tc = 3 + find_enum(@tok_text); }
        if tc != 0 {
            // a cast to a scalar type or a pointer: (int)x  (Node^)p
            next();
            int castptr = 0;
            if tok_is("^") {
                next();
                castptr = 1;
            }
            if !tok_is(")") {
                ast_fail("a cast that is not understood");
                return 0;
            }
            next();
            int v2 = ast_primary();
            if ast_ok == 0 { return 0; }
            if castptr == 1 { ast_cur_ty = ast_mkty(1, tc); } else if tc >= 16 { ast_cur_ty = ast_mkty(3, tc); } else { ast_cur_ty = ast_mkty(0, tc); }
            return ast_node(AK_CAST, v2, 0, 0, tc);
        }
        int keep_cout = ast_in_cout;
        ast_in_cout = 0;
        int e = ast_expr(0);
        ast_in_cout = keep_cout;
        if ast_ok == 0 { return 0; }
        if !tok_is(")") {
            ast_fail("a bracket that is not closed");
            return 0;
        }
        next();
        return ast_postfix(e, ast_ty[e] / 65536, ast_ty[e] % 65536);
    }
    if tok_is("-") {
        next();
        int a = ast_primary();
        if ast_ok == 0 { return 0; }
        if ast_ty[a] / 65536 == 3 {
            // -a on a struct: its method neg
            int nst = ast_ty[a] % 65536 - 16;
            char nfn[128];
            str_copy(@nfn, @sname + nst * 64, 64);
            str_copy(@nfn + str_len(@nfn), "__neg", 8);
            int nfi = find_func(@nfn);
            if nfi < 0 || fop[nfi] == 0 || simd_kind(100 + nst) != 0 {
                ast_fail("a minus on a struct that is not a method of the program");
                return 0;
            }
            ast_cur_ty = ast_fn_ty(nfi);
            return ast_node(AK_METHOD, a, 0, 0, ast_pool_add("neg"));
        }
        ast_cur_ty = ast_arith_ty(ast_ty[a], ast_ty[a]);
        return ast_node(AK_NEG, a, 0, 0, 0);
    }
    if tok_is("~") {
        next();
        int a3 = ast_primary();
        if ast_ok == 0 { return 0; }
        ast_cur_ty = ast_arith_ty(ast_ty[a3], ast_ty[a3]);
        return ast_node(AK_NOT, a3, 1, 0, 0);
    }
    if tok_is("!") {
        next();
        int a2 = ast_primary();
        if ast_ok == 0 { return 0; }
        ast_cur_ty = ast_mkty(0, 3);
        return ast_node(AK_NOT, a2, 0, 0, 0);
    }
    if tok_is("@") {
        next();
        if tok_kind != T_IDENT {
            ast_fail("an address that is not of a variable or an element");
            return 0;
        }
        int bn = ast_name_node();
        if ast_ok == 0 { return 0; }
        int tgt = ast_postfix(bn, ast_nkind, ast_nbase);
        if ast_ok == 0 { return 0; }
        ast_cur_ty = ast_mkty(1, ast_ty[tgt] % 65536);
        return ast_node(AK_ADDR, tgt, 0, 0, 0);
    }
    if tok_kind == T_IDENT {
        if tok_is("nl") && ast_find_local(@tok_text) < 0 && find_global(@tok_text) < 0 && find_func(@tok_text) < 0 {
            next();
            ast_cur_ty = ast_mkty(0, 2);
            return ast_node(AK_NUM, 0, 0, 0, 10);               // nl : a new line, a char
        }
        if tok_is("true") || tok_is("false") {
            int tv = 0;
            if tok_is("true") { tv = 1; }
            next();
            ast_cur_ty = ast_mkty(0, 3);
            return ast_node(AK_NUM, 0, 0, 0, tv);
        }
        if ast_type_kw() != 0 && ast_lambda_follows() {
            return ast_lambda();
        }
        if tok_is("null") {
            next();
            ast_cur_ty = ast_mkty(1, 8);
            return ast_node(AK_NUM, 0, 0, 0, 0);
        }
        if ast_is_builtin(@tok_text) && ast_find_local(@tok_text) < 0 && find_global(@tok_text) < 0 && (ast_resolve_func(@tok_text) < 0 || !(str_eq(@tok_text, "assert") || str_eq(@tok_text, "exit") || str_eq(@tok_text, "panic") || str_eq(@tok_text, "len")) && find_func(@tok_text) < 0 || tok_is("alloc") || tok_is("arr") || tok_is("free") || tok_is("move")) {
            int bp = ast_pool_add(@tok_text);
            bool is_arr_name = str_eq(@tok_text, "arr");
            next();
            if tok_is("[") && is_arr_name && sg_read(1) {
                // arr[n] is arr(n): the parser's own rewriting
                sg_skip(1);
                sg_make(4);
                push_macro(@sg_out);
                next();
            }
            if tok_is("[") {
                // alloc[n]  arr[n]  pool[T, n]: the brackets are read as they are
                int depth2 = 0;
                int prev_code = 0;
                bool saw_caret = false;
                while tok_kind != T_EOF {
                    if tok_is("[") { depth2 += 1; }
                    if tok_is("]") {
                        depth2 -= 1;
                        if depth2 == 0 {
                            next();
                            break;
                        }
                    }
                    if tok_is("^") {
                        saw_caret = true;
                    } else if saw_caret && tok_kind == T_IDENT {
                        // alloc[int^ p = n]: a pointer variable is declared here
                        char pn[64];
                        str_copy(@pn, @tok_text, 64);
                        saw_caret = false;
                        next();
                        if tok_is("=") || tok_is("]") {
                            int pli = ast_add_local(@pn);
                            if pli >= 0 {
                                ast_lkind[pli] = 1;
                                ast_lbase[pli] = prev_code;
                                if prev_code == 0 { ast_lbase[pli] = 8; }
                            }
                        }
                        continue;
                    } else if tok_kind == T_IDENT {
                        int tc = ast_type_kw();
                        if tc != 0 { prev_code = tc; }
                    }
                    next();
                }
                int bargs2 = 0;
                if tok_is("(") {
                    bargs2 = ast_args();
                    if ast_ok == 0 { return 0; }
                }
                ast_cur_ty = ast_mkty(0, 0);
                if ast_is_fop(bp) { ast_cur_ty = ast_mkty(0, 7); }
                if ast_is_alloc(bp) { ast_cur_ty = ast_mkty(0, 8); }
                return ast_postfix(ast_node(AK_BUILTIN, bargs2, 0, 0, bp), 0, 0);
            }
            if tok_is("(") {
                int bargs = 0;
                // sizeof(Type) and alloc[...](...) forms: a type name is read as a name or skipped
                if bp >= 0 && ast_pool[bp] == 's' && ast_pool[bp + 1] == 'i' {
                    next();
                    if at_type() {
                        // sizeof(Type): a number
                        parse_type();
                        int szv = 8;
                        if ty_ptr == 0 { szv = size_of(ty_elem); }
                        if tok_is(")") {
                            next();
                            ast_cur_ty = ast_mkty(0, 8);
                            return ast_postfix(ast_node(AK_NUM, 0, 0, 0, szv), 0, 8);
                        }
                    }
                    // sizeof(x): the size of the type of an expression (the code of the operand is not made)
                    int so = ast_expr(0);
                    if ast_ok == 0 { return 0; }
                    if !tok_is(")") {
                        ast_fail("sizeof of something that is not understood");
                        return 0;
                    }
                    next();
                    int sk = ast_ty[so] / 65536;
                    int sb = ast_ty[so] % 65536;
                    int ssz = 0;
                    if sk == 0 {
                        ssz = 8;
                        if sb == 1 || sb == 2 || sb == 3 || sb == 11 { ssz = 1; }
                        if sb == 4 || sb == 6 || sb == 12 { ssz = 4; }
                    } else if sk == 1 || sk == 4 || sk == 5 {
                        ssz = 8;
                    } else if sk == 3 {
                        ssz = ssize[sb - 16];
                    } else {
                        ast_fail("sizeof of an array or of a type that is not in the subset");
                        return 0;
                    }
                    ast_cur_ty = ast_mkty(0, 8);
                    return ast_postfix(ast_node(AK_NUM, 0, 0, 0, ssz), 0, 8);
                } else {
                    bargs = ast_args();
                    if ast_ok == 0 { return 0; }
                }
                ast_cur_ty = ast_mkty(0, 0);
                if ast_is_fop(bp) { ast_cur_ty = ast_mkty(0, 7); }
                if ast_is_alloc(bp) { ast_cur_ty = ast_mkty(0, 8); }
                if ast_fop_of(bp) >= 8 { ast_cur_ty = ast_mkty(0, 8); }
                if ast_fop_of(bp) == 13 {
                    ast_cur_ty = ast_mkty(4, 8);
                    return ast_postfix(ast_node(AK_BUILTIN, bargs, 0, 0, bp), 4, 8);
                }
                if ast_fop_of(bp) == 14 && bargs != 0 {
                    int mk = ast_ty[bargs] / 65536;
                    int mb = ast_ty[bargs] % 65536;
                    ast_cur_ty = ast_ty[bargs];
                    return ast_postfix(ast_node(AK_BUILTIN, bargs, 0, 0, bp), mk, mb);
                }
                return ast_postfix(ast_node(AK_BUILTIN, bargs, 0, 0, bp), 0, 8);
            }
            ast_fail("a built-in name that is not called");
            return 0;
        }
        if (ast_colons_follow() && ast_find_local(@tok_text) < 0) || ast_module_dot() {
            return ast_static_call(true);
        }
        // a call?
        char nm[64];
        str_copy(@nm, @tok_text, 64);
        int fi = ast_resolve_func(@nm);
        if fi != 0 - 1 && ast_find_local(@nm) < 0 && find_global(@nm) < 0 {
            // look ahead: `name (`: the lexer has no peek, so read the name and see
            int sv_pos = cur_pos;
            int sv_line = cur_line;
            int sv_ls = cur_line_start;
            while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
            bool is_call = lc(0) == '(';
            cur_pos = sv_pos;
            cur_line = sv_line;
            cur_line_start = sv_ls;
            if is_call && fi == 0 - 2 {
                // a generic function called without its types: they come from the arguments
                next();
                int gargs = ast_args();
                if ast_ok == 0 { return 0; }
                ast_cur_ty = ast_mkty(0, 0);
                return ast_postfix(ast_node(AK_CALL, gargs, 0, 0, 0 - 1), 0, 0);
            }
            if is_call {
                if fop[fi] == 1 {
                    ast_fail("a call of an operator function");
                    return 0;
                }
                if fvoid[fi] == 1 {
                    ast_fail("a call of a function that returns nothing used as a value");
                    return 0;
                }
                next();                          // the name; the current token is `(`
                int ccn = ast_call(fi);
                if ast_ok == 0 { return 0; }
                int crt = ast_ty[ccn];
                ast_ndims = 1;
                return ast_postfix(ccn, crt / 65536, crt % 65536);
            }
        }
        int bn2 = ast_name_node();
        if ast_ok == 0 { return 0; }
        return ast_postfix(bn2, ast_nkind, ast_nbase);
    }
    ast_fail("an expression that is not in the subset");
    return 0;
}

// the level of the operator at the current token (0: not a binary operator) and its code; higher binds tighter
int ast_op_code;
int ast_op_level() {
    ast_op_code = 0;
    if tok_kind == T_OP {
        if ast_in_cout == 1 && tok_is("<<") { return 0 - 2; }
        if tok_is("*") { ast_op_code = AO_MUL; return 9; }
        if tok_is("/") { ast_op_code = AO_DIV; return 9; }
        if tok_is("%") { ast_op_code = AO_MOD; return 9; }
        if tok_is("+") { ast_op_code = AO_ADD; return 8; }
        if tok_is("-") { ast_op_code = AO_SUB; return 8; }
        if tok_is("<<") { ast_op_code = AO_SHL; return 7; }
        if tok_is(">>") { ast_op_code = AO_SHR; return 7; }
        if tok_is("&") { ast_op_code = AO_AND; return 6; }
        if tok_is("|") { ast_op_code = AO_OR; return 4; }
        if tok_is("<") { ast_op_code = AO_LT; return 3; }
        if tok_is("<=") { ast_op_code = AO_LE; return 3; }
        if tok_is(">") { ast_op_code = AO_GT; return 3; }
        if tok_is(">=") { ast_op_code = AO_GE; return 3; }
        if tok_is("==") { ast_op_code = AO_EQ; return 2; }
        if tok_is("!=") { ast_op_code = AO_NE; return 2; }
        if tok_is("&&") { ast_op_code = AO_LAND; return 1; }
        if tok_is("||") { ast_op_code = AO_LOR; return 0 - 1; }
    }
    if tok_kind == T_IDENT {
        if tok_is("xor") { ast_op_code = AO_XOR; return 5; }
        if tok_is("shl") { ast_op_code = AO_SHL; return 7; }
        if tok_is("shr") { ast_op_code = AO_SHR; return 7; }
    }
    return 0 - 2;
}

// precedence climbing: level 0 is the lowest (`||` is the level -1 and is allowed when the caller starts at -1)
int ast_expr(int level) {
    int lhs = ast_primary();
    if ast_ok == 0 { return 0; }
    while true {
        int lv = ast_op_level();
        int code = ast_op_code;
        if lv == 0 - 2 { break; }
        int minl = level;
        if level == 0 { minl = 0 - 1; }
        if lv < minl { break; }
        next();
        int rhs = ast_expr(lv + 1);
        if ast_ok == 0 { return 0; }
        if ast_ty[rhs] / 65536 == 3 && ast_ty[lhs] / 65536 == 0 && code == AO_MUL {
            // number * struct: the same as struct * number (the method mul of the struct)
            int sw = lhs;
            lhs = rhs;
            rhs = sw;
        }
        if ast_ty[lhs] / 65536 == 3 && (code == AO_ADD || code == AO_SUB || code == AO_MUL || code == AO_DIV || code == AO_EQ || code == AO_NE) {
            // an operator of a struct: a call of its method  add  sub  mul  div  eq  (a != b is the negation of eq)
            int ost = ast_ty[lhs] % 65536 - 16;
            char^ opn = "add";
            if code == AO_SUB { opn = "sub"; }
            if code == AO_MUL { opn = "mul"; }
            if code == AO_DIV { opn = "div"; }
            if code == AO_EQ || code == AO_NE { opn = "eq"; }
            char ofn[128];
            str_copy(@ofn, @sname + ost * 64, 64);
            str_copy(@ofn + str_len(@ofn), "__", 4);
            str_copy(@ofn + str_len(@ofn), opn, 16);
            int ofi = find_func(@ofn);
            if ofi < 0 || fop[ofi] == 0 || simd_kind(100 + ost) != 0 {
                ast_fail("an operator of a struct that is not a method of the program");
                return 0;
            }
            ast_cur_ty = ast_fn_ty(ofi);
            int om = ast_node(AK_METHOD, lhs, rhs, 0, ast_pool_add(opn));
            if code == AO_NE {
                ast_cur_ty = ast_mkty(0, 3);
                om = ast_node(AK_NOT, om, 0, 0, 0);
            }
            lhs = om;
            continue;
        }
        if code >= AO_LT {
            ast_cur_ty = ast_mkty(0, 3);
        } else if code == AO_ADD && (ast_ty[lhs] / 65536 == 4 || ast_ty[rhs] / 65536 == 4) {
            ast_cur_ty = ast_mkty(4, 8);               // a String joined with something
        } else if (code == AO_ADD || code == AO_SUB) && ast_ty[lhs] / 65536 == 1 && ast_ty[rhs] / 65536 == 0 && ast_ty[rhs] % 65536 != 6 && ast_ty[rhs] % 65536 != 7 {
            ast_cur_ty = ast_ty[lhs];                  // a pointer moved by a number of bytes (the same type)
        } else if code == AO_ADD && ast_ty[rhs] / 65536 == 1 && ast_ty[lhs] / 65536 == 0 && ast_ty[lhs] % 65536 != 6 && ast_ty[lhs] % 65536 != 7 {
            ast_cur_ty = ast_ty[rhs];
        } else if (ast_ty[lhs] == 6 && ast_is_flit(rhs)) || (ast_ty[rhs] == 6 && ast_is_flit(lhs)) {
            ast_cur_ty = ast_mkty(0, 6);               // a float and a decimal literal: a float (the literal adapts)
        } else {
            ast_cur_ty = ast_arith_ty(ast_ty[lhs], ast_ty[rhs]);
        }
        lhs = ast_node(AK_BIN, lhs, rhs, 0, code);
    }
    return lhs;
}

// ---------------------------------------------------------------- statements
int ast_stmt_assign_op(char^ t) {
    if str_eq(t, "+=") { return AO_ADD; }
    if str_eq(t, "-=") { return AO_SUB; }
    if str_eq(t, "*=") { return AO_MUL; }
    if str_eq(t, "/=") { return AO_DIV; }
    if str_eq(t, "%=") { return AO_MOD; }
    if str_eq(t, "&=") { return AO_AND; }
    if str_eq(t, "|=") { return AO_OR; }
    if str_eq(t, "<<=") { return AO_SHL; }
    if str_eq(t, ">>=") { return AO_SHR; }
    if str_eq(t, "^=") || str_eq(t, "xor=") { return AO_XOR; }
    if str_eq(t, "shl=") { return AO_SHL; }
    if str_eq(t, "shr=") { return AO_SHR; }
    return 0;
}

int ast_if() {
    next();                                  // if
    int c = ast_expr(0);
    if ast_ok == 0 { return 0; }
    int th = ast_block();
    if ast_ok == 0 { return 0; }
    int el = 0;
    if tok_kind == T_IDENT && tok_is("else") {
        next();
        if tok_kind == T_IDENT && tok_is("if") {
            el = ast_if();
        } else {
            el = ast_block();
        }
        if ast_ok == 0 { return 0; }
    }
    return ast_node(AK_IF, c, th, el, 0);
}

// `cout << a << "text" << b;`
int ast_cout() {
    next();                                  // cout
    int first = 0;
    int last = 0;
    while tok_is("<<") {
        next();
        int item = 0;
        ast_in_cout = 1;
        item = ast_expr(0);
        ast_in_cout = 0;
        if ast_ok == 0 { return 0; }
        if first == 0 { first = item; } else { ast_nx[last] = item; }
        last = item;
    }
    if !tok_is(";") {
        ast_fail("a cout that is not understood");
        return 0;
    }
    next();
    return ast_node(AK_COUT, first, 0, 0, 0);
}

// `{a, b, {c, d}}`
int ast_list() {
    next();                                  // {
    int first = 0;
    int last = 0;
    while !tok_is("}") {
        int item = 0;
        if tok_is("{") {
            item = ast_list();
        } else {
            item = ast_expr(0);
        }
        if ast_ok == 0 { return 0; }
        if first == 0 { first = item; } else { ast_nx[last] = item; }
        last = item;
        if tok_is(",") { next(); } else { break; }
    }
    if !tok_is("}") {
        ast_fail("an initial list that is not understood");
        return 0;
    }
    next();
    return ast_node(AK_LIST, first, 0, 0, 0);
}

// a declaration of a scalar, a struct, a String, an enum, a pointer, a fixed array or a dynamic array:
// `T name = e;`  `T^ name = e;`  `T name[N];`  `T[] name = e;`  `String name = e;`  `T name = {..};`
int ast_decl(int base) {
    int tkind = 0;
    if base == 0 - 2 {
        tkind = 4;                           // String
        base = 8;
    } else if base <= 0 - 10 {
        // an enum: the caller passes -10 - its number (its type id 3 + n would be mistaken for a width code: bool, i32, double, int)
        tkind = 6;
        base = 3 + (0 - 10 - base);
    }
    next();                                  // the type
    bool isfn = false;
    if tok_is("(") {
        // a pointer to a function: int(int, int)^ f
        isfn = true;
        int fdepth = 0;
        while tok_kind != T_EOF {
            if tok_is("(") { fdepth += 1; }
            if tok_is(")") {
                fdepth -= 1;
                if fdepth == 0 {
                    next();
                    break;
                }
            }
            next();
        }
    }
    int ptr = 0;
    while tok_is("^") {
        next();
        ptr += 1;
    }
    int dynarr = 0;
    if ptr == 2 { base = 400 + base; }
    if tok_is("[") {
        // `T[] name`: a dynamic array
        int sv_pos = cur_pos;
        int sv_line = cur_line;
        int sv_ls = cur_line_start;
        while cur_pos < cur_len && lc(0) == ' ' { adv(); }
        bool empty = lc(0) == ']';
        cur_pos = sv_pos;
        cur_line = sv_line;
        cur_line_start = sv_ls;
        if empty {
            next();
            next();
            dynarr = 1;
        }
    }
    if tok_kind != T_IDENT {
        ast_fail("a declaration that is not understood");
        return 0;
    }
    char dn[64];
    str_copy(@dn, @tok_text, 64);
    next();
    int kind = 0;
    if ptr > 0 { kind = 1; }
    else if tkind != 0 { kind = tkind; }
    else if base >= 16 { kind = 3; }
    if dynarr == 1 { kind = 5; }
    if dynarr == 1 {
        // the element of the dynamic array (see ast_dyn_base)
        int eb = base;
        if tkind == 4 { eb = 4008; }
        else if ptr >= 2 { eb = 1400 + (base % 400); }
        else if ptr == 1 { eb = 1000 + base; }
        else if tkind == 6 { eb = 6000 + base; }
        else if base >= 16 { eb = 3000 + base; }
        base = eb;
    }
    int dims = 0;
    int dcount = 0 - 1;                      // the number of elements of a one dimensional array with a number as its size
    int dsz0 = 0;                            // the sizes of the first dimensions (0: not a number)
    int dsz1 = 0;
    int dsz2 = 0;
    while tok_is("[") {
        next();
        if tok_is("]") {
            // an array whose size comes from its initial list
        } else if tok_kind == T_NUM && tok_float == 0 {
            if dims == 0 { dcount = tok_num; dsz0 = tok_num; }
            if dims == 1 { dsz1 = tok_num; }
            if dims == 2 { dsz2 = tok_num; }
            next();
        } else {
            int sz = ast_expr(0);
            if ast_ok == 0 { return 0; }
        }
        if !tok_is("]") {
            ast_fail("a size that is not understood");
            return 0;
        }
        next();
        dims += 1;
    }
    if dims > 0 {
        if kind == 6 { base = 8; }                 // the elements of an array of an enum are whole numbers of 8 bytes
        kind = 2;
        if ptr == 1 { base = 400 + base; }
    }
    int init = 0;
    if tok_is("=") {
        next();
        if tok_is("{") {
            init = ast_list();
        } else {
            init = ast_expr(0);
        }
        if ast_ok == 0 { return 0; }
    } else if tok_is("@") {
        // a pinned variable: int n @ x19 = 0;
        next();
        next();
        if tok_is("=") {
            next();
            init = ast_expr(0);
            if ast_ok == 0 { return 0; }
        }
    }
    if !tok_is(";") {
        ast_fail("a declaration that is not understood (a list of names)");
        return 0;
    }
    next();
    int di = ast_add_local(@dn);
    if di >= 0 && isfn && ast_lid[di] < 1023 { ast_usig[ast_lid[di]] = 0 - 2; }          // a local that is a function pointer: its signature is looked for when the parser has its locals (as1_sigof)
    if di >= 0 {
        ast_lkind[di] = kind;
        ast_lbase[di] = base;
        if dims > 0 { ast_ldims[di] = dims; }
    }
    if di < 0 { return ast_node(AK_DECL, init, 0, 0, 0); }
    ast_cur_ty = ast_mkty(kind, base);                // the type of the variable
    int dn2 = ast_node(AK_DECL, init, 0, 0, ast_lid[di]);
    if dn2 != 0 && kind == 2 && dims == 1 { ast_b[dn2] = dcount; } else if dn2 != 0 { ast_b[dn2] = 0 - 1; }
    if dn2 != 0 && kind == 2 && (dims == 2 || dims == 3) && dsz0 > 0 && dsz1 > 0 && (dims == 2 || dsz2 > 0) && init == 0 {
        // a table: the number of elements, and the elements that one step of the first and of the second index skips
        int tot = dsz0 * dsz1;
        int s1 = dsz1;
        int s2 = 0;
        if dims == 3 {
            tot = tot * dsz2;
            s1 = dsz1 * dsz2;
            s2 = dsz2;
        }
        if tot < 65536 && s1 < 65536 {
            ast_b[dn2] = tot;
            ast_c[dn2] = s1 + s2 * 65536;
        }
    }
    return dn2;
}

// the character after the current token is `)` or `^`: a type in a cast, not a name in an expression
bool ast_cast_follows() {
    int sv_pos = cur_pos;
    int sv_line = cur_line;
    int sv_ls = cur_line_start;
    while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
    int c = lc(0);
    bool r = c == ')' || c == '^';
    cur_pos = sv_pos;
    cur_line = sv_line;
    cur_line_start = sv_ls;
    return r;
}

// the character after the current token's end is a letter, `_` or `^` (a declaration `Pt p;` / `Pt^ p;`) - looked at without reading
bool ast_decl_follows() {
    int sv_pos = cur_pos;
    int sv_line = cur_line;
    int sv_ls = cur_line_start;
    while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
    int c = lc(0);
    bool r = is_letter(c) || c == '_' || c == '^' || (c == '[' && lc(1) == ']');
    cur_pos = sv_pos;
    cur_line = sv_line;
    cur_line_start = sv_ls;
    return r;
}

// skip a block of the low level: the current token is `{`; the tokens up to the matching `}` are not read
int ast_raw_block() {
    int depth = 0;
    while tok_kind != T_EOF {
        if tok_is("{") { depth += 1; }
        if tok_is("}") {
            depth -= 1;
            if depth == 0 {
                next();
                return ast_node(AK_RAW, 0, 0, 0, 0);
            }
        }
        next();
    }
    ast_fail("the end of the file inside a block of the low level");
    return 0;
}

// the patterns of a case: `_`, a value, `Enum::Member`, `Enum::Member(a, b)` (the names are new locals), separated by `,`
int ast_case_patterns() {
    int first = 0;
    int last = 0;
    while true {
        int item = 0;
        if tok_kind == T_IDENT && tok_is("_") {
            next();
        } else if tok_kind == T_IDENT && ast_colons_follow() {
            char pq[64];
            str_copy(@pq, @tok_text, 64);
            next();                          // the enum
            next();                          // ::
            int pa = ast_pool_add(@tok_text);
            next();
            int bound = 0;
            if tok_is("(") {
                next();
                while !tok_is(")") {
                    if tok_kind != T_IDENT {
                        ast_fail("a name of a pattern was expected");
                        return 0;
                    }
                    if !tok_is("_") {
                        int bl = ast_add_local(@tok_text);
                        if bl >= 0 {
                            ast_lkind[bl] = 5;
                            ast_lbase[bl] = 0;
                        }
                        bound += 1;
                    }
                    next();
                    if tok_is(",") { next(); }
                }
                next();
            }
            item = ast_enumv(0, bound, ast_classify(@pq, @ast_pool + pa), pa);
        } else if tok_kind == T_IDENT && ast_find_local(@tok_text) < 0 && find_global(@tok_text) < 0 && find_func(@tok_text) < 0 {
            // a member of an enum written without its name (`using enum`)
            int pa2 = ast_pool_add(@tok_text);
            next();
            int bound2 = 0;
            if tok_is("(") {
                next();
                while !tok_is(")") {
                    if tok_kind != T_IDENT {
                        ast_fail("a name of a pattern was expected");
                        return 0;
                    }
                    if !tok_is("_") {
                        int bl2 = ast_add_local(@tok_text);
                        if bl2 >= 0 {
                            ast_lkind[bl2] = 5;
                            ast_lbase[bl2] = 0;
                        }
                        bound2 += 1;
                    }
                    next();
                    if tok_is(",") { next(); }
                }
                next();
            }
            char noq2[4];
            noq2[0] = 0;
            item = ast_enumv(0, bound2, ast_classify(@noq2, @ast_pool + pa2), pa2);
        } else {
            item = ast_expr(0);
            if ast_ok == 0 { return 0; }
        }
        if item != 0 {
            if first == 0 { first = item; } else { ast_nx[last] = item; }
            last = item;
        }
        if tok_is(",") { next(); } else { break; }
    }
    return first;
}

// the cases of a switch on a data enum (a struct with a tag): `Enum::Member` or `Enum::Member(a, b)`; `_`. Each case: the patterns are
// numbers (the index of the member in its enum), the names that it binds go to a chain of AK_VAR nodes (val = the local, b = the field of
// the struct, the type is the type of the local) in the field c of the case; the cases are returned
int ast_cbinds;
int ast_data_case(int sd, int d) {
    int first = 0;
    int last = 0;
    ast_cbinds = 0;
    int bfirst = 0;
    int blast = 0;
    int bound_gv = 0 - 1;
    while true {
        int item = 0;
        if tok_kind == T_IDENT && tok_is("_") {
            next();
        } else if tok_kind == T_IDENT {
            int gv = 0 - 1;
            if dv_using(d) && dv_variant(d, @tok_text) >= 0 && !dv_label_ok(d, @tok_text) {
                gv = dv_variant(d, @tok_text);
                next();
            } else {
                if !dv_label_ok(d, @tok_text) {
                    ast_fail("a case of a data enum that is not Enum::Member");
                    return 0;
                }
                next();
                if !tok_is("::") {
                    ast_fail("a case of a data enum that is not Enum::Member");
                    return 0;
                }
                next();
                if tok_kind != T_IDENT {
                    ast_fail("a name of a member was expected");
                    return 0;
                }
                gv = dv_variant(d, @tok_text);
                next();
            }
            if gv < 0 {
                ast_fail("a member that is not in the enum");
                return 0;
            }
            ast_cur_ty = ast_mkty(0, 8);
            item = ast_node(AK_NUM, 0, 0, 0, gv - dv_first_of(d));
            if tok_is("(") {
                next();
                bound_gv = gv;
                int k = 0;
                while !tok_is(")") {
                    if tok_kind != T_IDENT {
                        ast_fail("a name of a pattern was expected");
                        return 0;
                    }
                    if !tok_is("_") {
                        // the field of the member and the type of the name (as the text parser makes the local)
                        char^ want = dv_pfield(gv, k);
                        int fi = 0 - 1;
                        int fk = sfirst[sd];
                        while fk < sfirst[sd] + snf[sd] {
                            if str_eq(@fldname + fk * 64, want) { fi = fk; }
                            fk += 1;
                        }
                        if fi < 0 {
                            ast_fail("a member of a data enum without its field");
                            return 0;
                        }
                        int bl = ast_add_local(@tok_text);
                        if bl < 0 { return 0; }
                        int bk = 0;
                        int bb = 8;
                        if flddyn[fi] != 0 {
                            if is_str_dyn(flddyn[fi]) { bk = 4; bb = 8; } else { bk = 5; bb = ast_dyn_base(flddyn[fi]); }
                        } else if fldcode[fi] >= 16 && fldptr[fi] == 0 && fldcode[fi] < 400 {
                            if struct_has_free(fldcode[fi] - 16) { bk = 1; bb = fldcode[fi]; } else { bk = 3; bb = fldcode[fi]; }
                        } else if fldptr[fi] != 0 {
                            bk = 1;
                            bb = fldptr[fi];
                        } else if fldtid[fi] >= 3 && fldtid[fi] < 90 {
                            bk = 6;
                            bb = fldtid[fi];
                        } else {
                            bk = 0;
                            bb = fldcode[fi];
                        }
                        ast_lkind[bl] = bk;
                        ast_lbase[bl] = bb;
                        ast_cur_ty = ast_mkty(bk, bb);
                        int bn = ast_node(AK_VAR, 0, fi, 0, ast_lid[bl]);
                        if bfirst == 0 { bfirst = bn; } else { ast_nx[blast] = bn; }
                        blast = bn;
                    }
                    k += 1;
                    next();
                    if tok_is(",") { next(); }
                }
                next();
            }
        } else {
            ast_fail("a case of a data enum that is not understood");
            return 0;
        }
        if item != 0 {
            if first == 0 { first = item; } else { ast_nx[last] = item; }
            last = item;
        }
        if tok_is(",") { next(); } else { break; }
    }
    ast_cbinds = bfirst;
    return first;
}

int ast_switch() {
    next();                                  // switch
    int v = ast_expr(0);
    if ast_ok == 0 { return 0; }
    // a data enum: a struct that dv_find knows by its name
    int data_sd = 0 - 1;
    int data_d = 0 - 1;
    if ast_ty[v] / 65536 == 3 && ast_ty[v] % 65536 >= 16 && ast_ty[v] % 65536 < 16 + scount {
        int sd0 = ast_ty[v] % 65536 - 16;
        int d0 = dv_find(@sname + sd0 * 64);
        if d0 >= 0 { data_sd = sd0; data_d = d0; }
    }
    if !tok_is("{") {
        ast_fail("a switch that is not understood");
        return 0;
    }
    next();
    int first = 0;
    int last = 0;
    while !tok_is("}") {
        if tok_kind == T_EOF {
            ast_fail("the end of the file inside a switch");
            return 0;
        }
        int saved_nl = ast_nl;
        int pats = 0;
        int cbinds = 0;
        if data_sd >= 0 {
            pats = ast_data_case(data_sd, data_d);
            cbinds = ast_cbinds;
        } else {
            pats = ast_case_patterns();
        }
        if ast_ok == 0 { return 0; }
        if !tok_is(":") {
            ast_fail("a case that is not understood");
            return 0;
        }
        next();
        int body = 0;
        if tok_is("{") { body = ast_block(); } else { body = ast_stmt(); }
        ast_nl = saved_nl;
        if ast_ok == 0 { return 0; }
        int cs = ast_node(AK_CASE, pats, body, cbinds, 0);
        if first == 0 { first = cs; } else { ast_nx[last] = cs; }
        last = cs;
    }
    next();
    int sw_data = 0;
    if data_sd >= 0 { sw_data = 1; }
    return ast_node(AK_SWITCH, v, first, 0, sw_data);
}

int ast_try() {
    next();                                  // try
    int tb = ast_block();
    if ast_ok == 0 { return 0; }
    if !(tok_kind == T_IDENT && tok_is("catch")) {
        ast_fail("a try without catch");
        return 0;
    }
    next();
    if !tok_is("(") {
        ast_fail("a catch that is not understood");
        return 0;
    }
    next();
    if tok_kind != T_IDENT {
        ast_fail("a catch that is not understood");
        return 0;
    }
    int saved_nl = ast_nl;
    int el = ast_add_local(@tok_text);
    if el >= 0 {
        ast_lkind[el] = 1;                   // the thrown text: a char^ (it was typed like a String before the lowering needed it)
        ast_lbase[el] = 2;
    }
    next();
    if !tok_is(")") {
        ast_fail("a catch that is not understood");
        return 0;
    }
    next();
    int cb = ast_block();
    ast_nl = saved_nl;
    if ast_ok == 0 { return 0; }
    return ast_node(AK_TRYCATCH, tb, cb, 0, ast_lid[el]);
}

int ast_stmt() {
    if tok_is("{") { return ast_block(); }
    if tok_kind == T_IDENT && ast_find_local(@tok_text) < 0 { sg_statement(); }      // alloc[int^ p = n]; free[p]; grow[p = n]: the usual form, read the same way as the parser does
    if tok_is("@") {
        // @no_reorder { ... }
        next();
        next();
        if tok_is("{") { return ast_raw_block(); }
        ast_fail("an attribute that is not understood");
        return 0;
    }
    if tok_kind == T_IDENT {
        if tok_is("if") { return ast_if(); }
        if tok_is("while") {
            next();
            int c = ast_expr(0);
            if ast_ok == 0 { return 0; }
            ast_loop_depth += 1;
            int body = ast_block();
            ast_loop_depth -= 1;
            if ast_ok == 0 { return 0; }
            return ast_node(AK_WHILE, c, body, 0, 0);
        }
        if tok_is("for") {
            next();
            if ast_type_kw() != 0 {
                // for int i = 0; i < n; i++ { }
                int saved_nl3 = ast_nl;
                int ini = ast_decl(ast_type_kw());
                if ast_ok == 0 { return 0; }
                int cond = ast_expr(0);
                if ast_ok == 0 { return 0; }
                if !tok_is(";") {
                    ast_fail("a for loop that is not understood");
                    return 0;
                }
                next();
                int stp = 0;
                if tok_kind == T_IDENT {
                    char sn[64];
                    str_copy(@sn, @tok_text, 64);
                    int stl = ast_find_local(@sn);
                    int tgt = ast_name_node();
                    if ast_ok == 0 { return 0; }
                    tgt = ast_postfix(tgt, ast_nkind, ast_nbase);
                    if ast_ok == 0 { return 0; }
                    if tok_is("++") || tok_is("--") {
                        next();
                        stp = ast_node(AK_INCDEC, tgt, 1, 0, 0);
                    } else {
                        int opc2 = 0;
                        if tok_is("=") { opc2 = 0; } else { opc2 = ast_stmt_assign_op(@tok_text); }
                        next();
                        int sval = ast_expr(0);
                        if ast_ok == 0 { return 0; }
                        stp = ast_node(AK_ASSIGN, sval, opc2, tgt, 0);
                    }
                }
                ast_loop_depth += 1;
                int body4 = ast_block();
                ast_loop_depth -= 1;
                ast_nl = saved_nl3;
                if ast_ok == 0 { return 0; }
                return ast_node(AK_WHILE, cond, body4, ini, 0 - 1 - stp);
            }
            if tok_kind != T_IDENT {
                ast_fail("a for loop that is not understood");
                return 0;
            }
            char vn[64];
            str_copy(@vn, @tok_text, 64);
            next();
            if !tok_is("in") {
                ast_fail("a for loop that is not over a range");
                return 0;
            }
            next();
            int from = ast_expr(0);
            if ast_ok == 0 { return 0; }
            if tok_is("{") {
                // for x in things { }: the elements of an array, a list, a String, a map
                int saved_nl2 = ast_nl;
                int li2 = ast_add_local(@vn);
                if li2 >= 0 {
                    ast_lkind[li2] = 0;
                    ast_lbase[li2] = 0;
                    // the type of the element: a number, a pointer, a member of an enum, a char of a String, a String of a String[]
                    int fkd = ast_ty[from] / 65536;
                    int fbs = ast_ty[from] % 65536;
                    if fkd == 5 {
                        if fbs == 4008 { ast_lkind[li2] = 4; ast_lbase[li2] = 8; }
                        else if fbs < 1000 { ast_lbase[li2] = fbs; }
                        else if fbs >= 1000 && fbs < 1500 { ast_lkind[li2] = 1; ast_lbase[li2] = fbs - 1000; }
                        else if fbs >= 6003 && fbs < 6090 { ast_lkind[li2] = 6; ast_lbase[li2] = fbs - 6000; }
                    } else if fkd == 4 {
                        ast_lbase[li2] = 2;
                    } else if fkd == 2 && fbs < 16 {
                        ast_lbase[li2] = fbs;
                    }
                }
                ast_loop_depth += 1;
                int body3 = ast_block();
                ast_loop_depth -= 1;
                ast_nl = saved_nl2;
                if ast_ok == 0 { return 0; }
                return ast_node(AK_FOR, from, 0, body3, ast_lid[li2]);
            }
            // `..` is read as two `.`
            if !tok_is(".") {
                ast_fail("a for loop that is not over a range");
                return 0;
            }
            next();
            if !tok_is(".") {
                ast_fail("a for loop that is not over a range");
                return 0;
            }
            next();
            int to = ast_expr(0);
            if ast_ok == 0 { return 0; }
            int saved_nl = ast_nl;
            int li = ast_add_local(@vn);
            ast_loop_depth += 1;
            int body2 = ast_block();
            ast_loop_depth -= 1;
            ast_nl = saved_nl;
            if ast_ok == 0 { return 0; }
            return ast_node(AK_FOR, from, to, body2, ast_lid[li]);
        }
        if tok_is("return") {
            next();
            if tok_is(";") {
                next();
                return ast_node(AK_RET, 0, 0, 0, 0);
            }
            int v = ast_expr(0);
            if ast_ok == 0 { return 0; }
            if !tok_is(";") {
                ast_fail("a return that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_RET, v, 0, 0, 0);
        }
        if tok_is("break") {
            next();
            if !tok_is(";") || ast_loop_depth == 0 {
                ast_fail("a break that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_BREAK, 0, 0, 0, 0);
        }
        if tok_is("continue") {
            next();
            if !tok_is(";") || ast_loop_depth == 0 {
                ast_fail("a continue that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_CONT, 0, 0, 0, 0);
        }
        if tok_is("cout") { return ast_cout(); }
        if tok_is("using") {
            next();
            if tok_is("enum") {
                // using enum Name;  its members are visible in the rest of the block
                next();
                int uen = find_enum(@tok_text);
                if uen >= 0 && uen < 64 { ast_ue[uen] = 1; }
            }
            while !tok_is(";") && tok_kind != T_EOF { next(); }
            next();
            return ast_node(AK_USING, 0, 0, 0, 0);
        }
        if tok_is("switch") { return ast_switch(); }
        if tok_is("try") { return ast_try(); }
        if tok_is("throw") {
            next();
            int tv = ast_expr(0);
            if ast_ok == 0 { return 0; }
            if !tok_is(";") {
                ast_fail("a throw that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_THROW, tv, 0, 0, 0);
        }
        if tok_is("defer") {
            next();
            int ds = 0;
            if tok_is("{") { ds = ast_block(); } else { ds = ast_stmt(); }
            if ast_ok == 0 { return 0; }
            return ast_node(AK_DEFER, ds, 0, 0, 0);
        }
        if tok_is("register") || tok_is("_") {
            // `register { }` or `_. { }`: the low level, read as it is
            int sv_pos = cur_pos;
            int sv_line = cur_line;
            int sv_ls = cur_line_start;
            next();
            if tok_is("{") { return ast_raw_block(); }
            if tok_is(".") {
                next();
                if tok_is("{") { return ast_raw_block(); }
            }
            ast_fail("a block of the low level that is not understood");
            return 0;
        }
        if tok_is("cin") {
            next();
            int cfirst = 0;
            int clast = 0;
            while tok_is(">>") {
                next();
                int cb = ast_name_node();
                if ast_ok == 0 { return 0; }
                cb = ast_postfix(cb, ast_nkind, ast_nbase);
                if ast_ok == 0 { return 0; }
                if cfirst == 0 { cfirst = cb; } else { ast_nx[clast] = cb; }
                clast = cb;
            }
            if !tok_is(";") {
                ast_fail("a cin that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_CIN, cfirst, 0, 0, 0);
        }
        int tcode = ast_type_kw();
        if tcode != 0 && !(tcode == 10 && !ast_decl_follows() && !ast_lambda_follows()) { return ast_decl(tcode); }
        if tok_is("String") && ast_find_local(@tok_text) < 0 {
            return ast_decl(0 - 2);
        }
        if find_struct(@tok_text) < 0 && find_enum(@tok_text) < 0 && ast_find_local(@tok_text) < 0 && find_global(@tok_text) < 0
            && ast_resolve_func(@tok_text) == 0 - 1 && ast_decl_follows() && !ast_is_builtin(@tok_text) {
            return ast_decl(0);
        }
        if find_enum(@tok_text) >= 0 && ast_find_local(@tok_text) < 0 && ast_decl_follows() {
            return ast_decl(0 - 10 - find_enum(@tok_text));
        }
        if ast_is_builtin(@tok_text) && ast_find_local(@tok_text) < 0 && find_global(@tok_text) < 0 && (ast_resolve_func(@tok_text) < 0 || !(str_eq(@tok_text, "assert") || str_eq(@tok_text, "exit") || str_eq(@tok_text, "panic") || str_eq(@tok_text, "len")) && find_func(@tok_text) < 0 || tok_is("alloc") || tok_is("arr") || tok_is("free") || tok_is("move")) {
            int bx = ast_expr(0);
            if ast_ok == 0 { return 0; }
            if !tok_is(";") {
                ast_fail("a statement that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_EXPR, bx, 0, 0, 0);
        }
        if (ast_colons_follow() && ast_find_local(@tok_text) < 0) || ast_module_dot() {
            int sc = ast_static_call(false);
            if ast_ok == 0 { return 0; }
            if tok_is("=") {
                next();
                int sv = ast_expr(0);
                if ast_ok == 0 { return 0; }
                if !tok_is(";") {
                    ast_fail("an assignment that is not understood");
                    return 0;
                }
                next();
                ast_cur_ty = ast_mkty(0, 8);
                return ast_node(AK_ASSIGN, sv, 0, sc, 0);
            }
            if !tok_is(";") {
                ast_fail("a statement that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_EXPR, sc, 0, 0, 0);
        }
        if tok_kind == T_IDENT && find_struct(@tok_text) >= 0 && ast_find_local(@tok_text) < 0 && ast_decl_follows() {
            return ast_decl(16 + find_struct(@tok_text));
        }
        // `f(args);`   `target = e;`   `target += e;`   `name++;`
        char nm[64];
        str_copy(@nm, @tok_text, 64);
        int fi = ast_resolve_func(@nm);
        if fi != 0 - 1 && ast_find_local(@nm) < 0 && find_global(@nm) < 0 {
            int sv_pos = cur_pos;
            int sv_line = cur_line;
            int sv_ls = cur_line_start;
            while cur_pos < cur_len && (lc(0) == ' ' || lc(0) == 9) { adv(); }
            bool is_call = lc(0) == '(';
            cur_pos = sv_pos;
            cur_line = sv_line;
            cur_line_start = sv_ls;
            if is_call && fi == 0 - 2 {
                next();
                int gargs2 = ast_args();
                if ast_ok == 0 { return 0; }
                if !tok_is(";") {
                    ast_fail("a statement that is not understood");
                    return 0;
                }
                next();
                ast_cur_ty = ast_mkty(0, 0);
                int gcall = ast_node(AK_CALL, gargs2, 0, 0, 0 - 1);
                return ast_node(AK_EXPR, gcall, 0, 0, 0);
            }
            if is_call {
                if fop[fi] == 1 {
                    ast_fail("a call of an operator function");
                    return 0;
                }
                next();
                int cn = ast_call(fi);
                if ast_ok == 0 { return 0; }
                if !tok_is(";") {
                    ast_fail("a statement that is not understood");
                    return 0;
                }
                next();
                return ast_node(AK_EXPR, cn, 0, 0, 0);
            }
        }
        int target = ast_name_node();
        if ast_ok == 0 { return 0; }
        target = ast_postfix(target, ast_nkind, ast_nbase);
        if ast_ok == 0 { return 0; }
        if tok_kind == T_OP && (tok_is("++") || tok_is("--")) {
            int step = 1;
            if tok_is("--") { step = 0 - 1; }
            next();
            if !tok_is(";") {
                ast_fail("a statement that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_INCDEC, target, step, 0, 0);
        }
        if tok_is(";") && (ast_kind[target] == AK_METHOD || ast_kind[target] == AK_CALL || ast_kind[target] == AK_TRYQ) {
            next();
            return ast_node(AK_EXPR, target, 0, 0, 0);
        }
        int opc = 0;
        if tok_kind == T_OP && tok_is("=") {
            opc = 0;
        } else if ast_stmt_assign_op(@tok_text) != 0 {
            opc = ast_stmt_assign_op(@tok_text);
        } else {
            ast_fail("a statement that is not in the subset");
            return 0;
        }
        next();
        int v2 = ast_expr(0);
        if ast_ok == 0 { return 0; }
        if !tok_is(";") {
            ast_fail("an assignment that is not understood");
            return 0;
        }
        next();
        if opc != 0 && ast_ty[target] / 65536 == 3 {
            // a += b on a struct is a = a.add(b) (sub, mul, div the same): the method call gets a copy of the target
            char^ opn2 = "add";
            if opc == AO_SUB { opn2 = "sub"; }
            else if opc == AO_MUL { opn2 = "mul"; }
            else if opc == AO_DIV { opn2 = "div"; }
            else if opc != AO_ADD { ast_fail("this operator does not work on a struct"); return 0; }
            int sst = ast_ty[target] % 65536 - 16;
            char sfn[128];
            str_copy(@sfn, @sname + sst * 64, 64);
            str_copy(@sfn + str_len(@sfn), "__", 4);
            str_copy(@sfn + str_len(@sfn), opn2, 16);
            int sfi = find_func(@sfn);
            if sfi < 0 || fop[sfi] == 0 || simd_kind(100 + sst) != 0 {
                ast_fail("an operator of a struct that is not a method of the program");
                return 0;
            }
            int tcopy = ast_clone(target);
            if ast_ok == 0 { return 0; }
            ast_cur_ty = ast_fn_ty(sfi);
            int mcall = ast_node(AK_METHOD, tcopy, v2, 0, ast_pool_add(opn2));
            ast_cur_ty = ast_ty[target];
            return ast_node(AK_ASSIGN, mcall, 0, target, 0);
        }
        ast_cur_ty = ast_ty[target];
        return ast_node(AK_ASSIGN, v2, opc, target, 0);
    }
    ast_fail("a statement that is not in the subset");
    return 0;
}

// `{ statements }`; the locals declared inside end with the block
int ast_block() {
    if !tok_is("{") {
        ast_fail("a block was expected");
        return 0;
    }
    int saved_nl = ast_nl;
    next();
    int first = 0;
    int last = 0;
    while !tok_is("}") {
        if tok_kind == T_EOF {
            ast_fail("the end of the file inside a block");
            return 0;
        }
        int s = ast_stmt();
        if ast_ok == 0 { return 0; }
        if first == 0 { first = s; } else { ast_nx[last] = s; }
        last = s;
    }
    next();
    ast_nl = saved_nl;
    return ast_node(AK_BLOCK, first, 0, 0, 0);
}

// ---------------------------------------------------------------- the printer (-xastdump)
char ast_obuf[65536];
int ast_olen;

void ast_pc(int c) {
    if ast_olen < 65530 {
        ast_obuf[ast_olen] = c;
        ast_olen += 1;
    }
}

void ast_ps(char^ t) {
    int i = 0;
    while t[i] != 0 {
        ast_pc(t[i]);
        i += 1;
    }
}

void ast_pn(int v) {
    if v < 0 {
        ast_pc('-');
        v = 0 - v;
    }
    char d[24];
    int n = 0;
    if v == 0 {
        d[0] = '0';
        n = 1;
    }
    while v > 0 {
        d[n] = '0' + v % 10;
        v = v / 10;
        n += 1;
    }
    while n > 0 {
        n -= 1;
        ast_pc(d[n]);
    }
}

void ast_pbase(int b) {
    if b == 1 { ast_ps("i8"); }
    else if b == 2 { ast_ps("char"); }
    else if b == 3 { ast_ps("bool"); }
    else if b == 4 { ast_ps("i32"); }
    else if b == 6 { ast_ps("float"); }
    else if b == 7 { ast_ps("double"); }
    else if b == 8 { ast_ps("int"); }
    else if b == 11 { ast_ps("u8"); }
    else if b == 12 { ast_ps("u32"); }
    else if b == 13 { ast_ps("u64"); }
    else if b >= 16 && b - 16 < scount { ast_ps(@sname + (b - 16) * 64); }
    else { ast_ps("?"); }
}

void ast_pty(int t) {
    int k = t / 65536;
    if k == 4 {
        ast_ps("String");
        return;
    }
    if k == 5 {
        ast_ps("array");
        return;
    }
    if k == 6 {
        ast_ps("enum");
        return;
    }
    if k == 7 {
        ast_ps("void");
        return;
    }
    if k == 8 || t % 65536 == 0 {
        ast_ps("?");
        return;
    }
    ast_pbase(t % 65536);
    if k == 1 { ast_pc('^'); }
    if k == 2 { ast_ps("[]"); }
}

void ast_pexpr(int n) {
    if n == 0 {
        ast_ps("()");
        return;
    }
    int k = ast_kind[n];
    if k == AK_NUM {
        ast_pn(ast_val[n]);
    } else if k == AK_FNUM {
        ast_ps("<float>");
    } else if k == AK_VAR {
        ast_ps(@ast_pool + ast_uname[ast_val[n]]);
    } else if k == AK_GVAR {
        ast_ps("$");
        ast_ps(@gname + ast_val[n] * 64);
    } else if k == AK_STR {
        ast_ps("\"..\"");
    } else if k == AK_BIN {
        ast_pc('(');
        ast_pexpr(ast_a[n]);
        ast_pc(' ');
        int o = ast_val[n];
        if o == AO_ADD { ast_ps("+"); } else if o == AO_SUB { ast_ps("-"); } else if o == AO_MUL { ast_ps("*"); }
        else if o == AO_DIV { ast_ps("/"); } else if o == AO_MOD { ast_ps("%"); } else if o == AO_SHL { ast_ps("<<"); }
        else if o == AO_SHR { ast_ps(">>"); } else if o == AO_AND { ast_ps("&"); } else if o == AO_XOR { ast_ps("xor"); }
        else if o == AO_OR { ast_ps("|"); } else if o == AO_LT { ast_ps("<"); } else if o == AO_LE { ast_ps("<="); }
        else if o == AO_GT { ast_ps(">"); } else if o == AO_GE { ast_ps(">="); } else if o == AO_EQ { ast_ps("=="); }
        else if o == AO_NE { ast_ps("!="); } else if o == AO_LAND { ast_ps("&&"); } else { ast_ps("||"); }
        ast_pc(' ');
        ast_pexpr(ast_b[n]);
        ast_pc(')');
    } else if k == AK_NEG {
        ast_ps("(- ");
        ast_pexpr(ast_a[n]);
        ast_pc(')');
    } else if k == AK_NOT {
        ast_ps("(! ");
        ast_pexpr(ast_a[n]);
        ast_pc(')');
    } else if k == AK_CALL {
        ast_pc('(');
        ast_ps(@fname + ast_val[n] * 64);
        int a = ast_a[n];
        while a != 0 {
            ast_pc(' ');
            ast_pexpr(a);
            a = ast_nx[a];
        }
        ast_pc(')');
    } else if k == AK_INDEX {
        ast_pexpr(ast_a[n]);
        ast_pc('[');
        ast_pexpr(ast_b[n]);
        ast_pc(']');
    } else if k == AK_DEREF {
        ast_pexpr(ast_a[n]);
        ast_pc('^');
    } else if k == AK_ADDR {
        ast_pc('@');
        ast_pexpr(ast_a[n]);
    } else if k == AK_CAST {
        ast_ps("((");
        ast_pty(ast_ty[n]);
        ast_ps(") ");
        ast_pexpr(ast_a[n]);
        ast_pc(')');
    } else if k == AK_FIELD {
        ast_pexpr(ast_a[n]);
        ast_pc('.');
        if ast_val[n] >= 0 { ast_ps(@fldname + ast_val[n] * 64); } else { ast_ps(@ast_pool + ast_b[n] - 1); }
    } else if k == AK_METHOD {
        ast_pc('(');
        ast_pexpr(ast_a[n]);
        ast_pc('.');
        ast_ps(@ast_pool + ast_val[n]);
        int ma = ast_b[n];
        while ma != 0 {
            ast_pc(' ');
            ast_pexpr(ma);
            ma = ast_nx[ma];
        }
        ast_pc(')');
    } else if k == AK_TRYQ {
        ast_pexpr(ast_a[n]);
        ast_pc('?');
    } else if k == AK_BUILTIN {
        ast_pc('(');
        ast_ps(@ast_pool + ast_val[n]);
        int ba = ast_a[n];
        while ba != 0 {
            ast_pc(' ');
            ast_pexpr(ba);
            ba = ast_nx[ba];
        }
        ast_pc(')');
    } else if k == AK_ENUMV {
        ast_ps(@ast_pool + ast_val[n]);
    } else if k == AK_RAW || k == AK_LAMBDA || k == AK_REG {
        ast_ps("<raw>");
    } else if k == AK_LIST {
        ast_pc('{');
        int a2 = ast_a[n];
        while a2 != 0 {
            ast_pexpr(a2);
            a2 = ast_nx[a2];
            if a2 != 0 { ast_ps(", "); }
        }
        ast_pc('}');
    } else {
        ast_ps("<?>");
    }
    if k != AK_LIST && k != AK_STR && k != AK_FNUM {
        ast_pc(':');
        ast_pty(ast_ty[n]);
    }
}

void ast_indent(int d) {
    int i = 0;
    while i < d {
        ast_ps("  ");
        i += 1;
    }
}

void ast_pstmt(int n, int d) {
    int k = ast_kind[n];
    ast_indent(d);
    if k == AK_BLOCK {
        ast_ps("{\n");
        int s = ast_a[n];
        while s != 0 {
            ast_pstmt(s, d + 1);
            s = ast_nx[s];
        }
        ast_indent(d);
        ast_ps("}\n");
    } else if k == AK_DECL {
        ast_ps("decl ");
        ast_ps(@ast_pool + ast_uname[ast_val[n]]);
        if ast_a[n] != 0 {
            ast_ps(" = ");
            ast_pexpr(ast_a[n]);
        }
        ast_pc(10);
    } else if k == AK_ASSIGN {
        ast_pexpr(ast_c[n]);
        int ao = ast_b[n];
        if ao == 0 { ast_ps(" = "); }
        else if ao == AO_ADD { ast_ps(" += "); } else if ao == AO_SUB { ast_ps(" -= "); } else if ao == AO_MUL { ast_ps(" *= "); }
        else if ao == AO_DIV { ast_ps(" /= "); } else if ao == AO_MOD { ast_ps(" %= "); } else if ao == AO_AND { ast_ps(" &= "); }
        else if ao == AO_OR { ast_ps(" |= "); } else if ao == AO_XOR { ast_ps(" xor= "); } else if ao == AO_SHL { ast_ps(" shl= "); }
        else { ast_ps(" shr= "); }
        ast_pexpr(ast_a[n]);
        ast_pc(10);
    } else if k == AK_INCDEC {
        ast_pexpr(ast_a[n]);
        if ast_b[n] > 0 { ast_ps("++\n"); } else { ast_ps("--\n"); }
    } else if k == AK_IF {
        ast_ps("if ");
        ast_pexpr(ast_a[n]);
        ast_pc(10);
        ast_pstmt(ast_b[n], d + 1);
        if ast_c[n] != 0 {
            ast_indent(d);
            ast_ps("else\n");
            ast_pstmt(ast_c[n], d + 1);
        }
    } else if k == AK_WHILE {
        ast_ps("while ");
        ast_pexpr(ast_a[n]);
        ast_pc(10);
        ast_pstmt(ast_b[n], d + 1);
    } else if k == AK_FOR {
        ast_ps("for ");
        ast_ps(@ast_pool + ast_uname[ast_val[n]]);
        ast_ps(" in ");
        ast_pexpr(ast_a[n]);
        if ast_b[n] != 0 {
            ast_ps(" .. ");
            ast_pexpr(ast_b[n]);
        }
        ast_pc(10);
        ast_pstmt(ast_c[n], d + 1);
    } else if k == AK_RET {
        ast_ps("return ");
        if ast_a[n] != 0 { ast_pexpr(ast_a[n]); }
        ast_pc(10);
    } else if k == AK_BREAK {
        ast_ps("break\n");
    } else if k == AK_CONT {
        ast_ps("continue\n");
    } else if k == AK_THROW {
        ast_ps("throw ");
        ast_pexpr(ast_a[n]);
        ast_pc(10);
    } else if k == AK_DEFER {
        ast_ps("defer\n");
        ast_pstmt(ast_a[n], d + 1);
    } else if k == AK_SWITCH {
        ast_ps("switch ");
        ast_pexpr(ast_a[n]);
        ast_pc(10);
        int cs = ast_b[n];
        while cs != 0 {
            ast_indent(d + 1);
            ast_ps("case");
            int pt = ast_a[cs];
            if pt == 0 { ast_ps(" _"); }
            while pt != 0 {
                ast_pc(' ');
                ast_pexpr(pt);
                pt = ast_nx[pt];
            }
            ast_pc(10);
            ast_pstmt(ast_b[cs], d + 2);
            cs = ast_nx[cs];
        }
    } else if k == AK_TRYCATCH {
        ast_ps("try\n");
        ast_pstmt(ast_a[n], d + 1);
        ast_indent(d);
        ast_ps("catch\n");
        ast_pstmt(ast_b[n], d + 1);
    } else if k == AK_RAW || k == AK_USING {
        ast_ps("<raw>\n");
    } else if k == AK_CIN {
        ast_ps("cin");
        int ci = ast_a[n];
        while ci != 0 {
            ast_ps(" >> ");
            ast_pexpr(ci);
            ci = ast_nx[ci];
        }
        ast_pc(10);
    } else if k == AK_EXPR {
        ast_pexpr(ast_a[n]);
        ast_pc(10);
    } else if k == AK_COUT {
        ast_ps("cout");
        int it = ast_a[n];
        while it != 0 {
            ast_ps(" << ");
            ast_pexpr(it);
            it = ast_nx[it];
        }
        ast_pc(10);
    } else {
        ast_ps("<?>\n");
    }
}

// ---------------------------------------------------------------- the probe
// the state of the lexer, put back after the body was read
int aq_pos; int aq_line; int aq_ls; int aq_base; int aq_len; int aq_depth;
int aq_kind; int aq_num; int aq_float; int aq_mant; int aq_exp; int aq_char; int aq_strlen; int aq_seq;
int aq_ptl; int aq_pel; int aq_pec; int aq_peb; int aq_pels;
int aq_eline; int aq_ecol; int aq_ebase; int aq_els;
int aq_mt; int aq_ro_next; int aq_ro_block; int aq_ro_file;
char aq_text[256];
char aq_str[1024];

void ast_save() {
    aq_pos = cur_pos; aq_line = cur_line; aq_ls = cur_line_start; aq_base = cur_base; aq_len = cur_len; aq_depth = lx_depth;
    aq_kind = tok_kind; aq_num = tok_num; aq_float = tok_float; aq_mant = tok_mant; aq_exp = tok_exp; aq_char = tok_char;
    aq_strlen = tok_str_len; aq_seq = tok_seq;
    aq_ptl = prev_tok_line; aq_pel = prev_end_line; aq_pec = prev_end_col; aq_peb = prev_end_base; aq_pels = prev_end_ls;
    aq_eline = err_line; aq_ecol = err_col; aq_ebase = err_base; aq_els = err_ls;
    aq_mt = mt_pending; aq_ro_next = ro_next; aq_ro_block = ro_block; aq_ro_file = ro_file;
    str_copy(@aq_text, @tok_text, 256);
    str_copy(@aq_str, @tok_str, 1024);
}

void ast_restore() {
    // a[lo..hi] is rewritten to span(a, lo, hi) in the buffer while it is read: the text is longer now and must stay so
    int len_now = cur_len;
    bool same_level = lx_depth == aq_depth && cur_base == aq_base;
    cur_pos = aq_pos; cur_line = aq_line; cur_line_start = aq_ls; cur_base = aq_base; cur_len = aq_len; lx_depth = aq_depth;
    if same_level { cur_len = len_now; }
    tok_kind = aq_kind; tok_num = aq_num; tok_float = aq_float; tok_mant = aq_mant; tok_exp = aq_exp; tok_char = aq_char;
    tok_str_len = aq_strlen; tok_seq = aq_seq;
    prev_tok_line = aq_ptl; prev_end_line = aq_pel; prev_end_col = aq_pec; prev_end_base = aq_peb; prev_end_ls = aq_pels;
    err_line = aq_eline; err_col = aq_ecol; err_base = aq_ebase; err_ls = aq_els;
    mt_pending = aq_mt; ro_next = aq_ro_next; ro_block = aq_ro_block; ro_file = aq_ro_file;
    str_copy(@tok_text, @aq_text, 256);
    str_copy(@tok_str, @aq_str, 1024);
}

// the current token is the `{` of the body of the function f_idx. Returns true when the body is in the subset (ast_root is its block).
bool ast_probe(int f_idx) {
    ast_root = 0;
    if ast_report == 0 && ast_lower_on == 0 { return false; }
    ast_save();
    if tok_is("[") {
        while !tok_is("{") && tok_kind != T_EOF { next(); }
    }
    int keep_pass = pass_no;
    pass_no = 0;                             // the lexer's warnings were given (or will be) by the real reading
    ast_n = 0;
    ast_ok = 1;
    int ue0 = 0;
    while ue0 < 64 { ast_ue[ue0] = 0; ue0 += 1; }
    ast_why[0] = 0;
    ast_loop_depth = 0;
    ast_nuid = 0;                            // the numbers of the locals are those of this body
    ast_lam0 = lam_seq;                      // the text path names the lambdas of this body __lambda_<this number>, +1 ... in the order they are written
    ast_lam_k = 0;
    ast_lam_depth = 0;
    ast_load_params();
    int root = 0;
    if ast_ok == 1 { root = ast_block(); }
    pass_no = keep_pass;
    ast_restore();
    ast_funcs += 1;
    if ast_ok == 0 && ast_lower_report == 1 {
        write_err("astlow: ");
        write_err(@fname + f_idx * 64);
        write_err(" not in the tree: ");
        write_err(@ast_why);
        write_err("\n");
    }
    if ast_ok == 1 {
        ast_funcs_ok += 1;
        ast_root = root;
        if ast_lower_on == 1 { at_store(f_idx); }
    }
    if ast_ok == 1 && ast_dump == 1 {
        ast_olen = 0;
        ast_ps("tree ");
        ast_ps(@fname + f_idx * 64);
        ast_pc(10);
        ast_pstmt(root, 1);
        syscall(64, 2, @ast_obuf, ast_olen);
    }
    if ast_report >= 1 {
        write_err("ast: ");
        write_err(@fname + f_idx * 64);
        if ast_ok == 1 {
            write_err(" is in the subset");
            // what the tree holds without having understood it (A2 brings these to zero)
            int ne = 0;
            int nr = 0;
            int nu = 0;
            int nn = 1;
            while nn <= ast_n {
                if ast_kind[nn] == AK_ENUMV && ast_cls[nn] == 0 {
                    ne += 1;
                    if ast_report == 2 { write_err("enumv "); write_err(@ast_pool + ast_val[nn]); write_err("\n"); }
                }
                if ast_kind[nn] == AK_RAW { nr += 1; }
                if ast_ty[nn] / 65536 == 8 {
                    nu += 1;
                    if ast_report == 2 {
                        write_err("unk ");
                        write_err_int(ast_kind[nn]);
                        if ast_kind[nn] == AK_METHOD || ast_kind[nn] == AK_BUILTIN { write_err(" "); write_err(@ast_pool + ast_val[nn]); }
                        write_err("\n");
                    }
                }

                nn += 1;
            }
            write_err("  nodes ");
            write_err_int(ast_n);
            write_err(" enumv ");
            write_err_int(ne);
            write_err(" raw ");
            write_err_int(nr);
            write_err(" unknown ");
            write_err_int(nu);
            write_err("\n");
        } else {
            write_err(" is not: ");
            write_err(@ast_why);
            write_err("\n");
        }
    }
    return ast_ok == 1;
}
