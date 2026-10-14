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
#define AK_CALL 6            // val = the function (index), a = first argument node, the arguments are a chain through c
#define AK_ASSIGN 7          // val = the local, a = the value; b = operator code (0: plain `=`, else AO_* for `+=` ...)
#define AK_IF 8              // a = condition, b = then block, c = else (a block, another AK_IF, or 0)
#define AK_WHILE 9           // a = condition, b = body
#define AK_FOR 10            // val = the local, a = from, b = to, c = body
#define AK_RET 11            // a = value (0: none)
#define AK_BLOCK 12          // a = first statement, the statements are a chain through c
#define AK_DECL 13           // val = the local, a = initial value (0: none)
#define AK_EXPR 14           // a = the expression (a call)
#define AK_BREAK 15
#define AK_CONT 16

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
int ast_n;
int ast_root;                    // the block of the last body read (0: it is not in the subset)

// the locals of the body: names (the probe's own table; the parameters come first)
char ast_lname[16384];           // 256 x 64
int ast_nl;
int ast_ok;                      // 0 while reading, set to 0 by the first thing that is not understood
char ast_why[128];
int ast_report;                  // -xast
int ast_funcs;                   // all bodies read / the ones in the subset (for -xast)
int ast_funcs_ok;
int ast_loop_depth;

void ast_fail(char^ why) {
    if ast_ok == 1 {
        ast_ok = 0;
        str_copy(@ast_why, why, 128);
    }
}

int ast_node(int kind, int a, int b, int c, int val) {
    if ast_n >= AST_MAXN - 1 {
        ast_fail("the body is too big for the tree");
        return 0;
    }
    ast_n += 1;
    ast_kind[ast_n] = kind;
    ast_a[ast_n] = a;
    ast_b[ast_n] = b;
    ast_c[ast_n] = c;
    ast_val[ast_n] = val;
    return ast_n;
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
    ast_nl += 1;
    return ast_nl - 1;
}

// the parameters and the locals that the parser has already: whole number scalars only
void ast_load_params() {
    ast_nl = 0;
    int i = 0;
    while i < lcount {
        if lkind[i] != 0 || lelem[i] != 8 || lptr[i] != 0 || ldyn[i] != 0 {
            ast_fail("a parameter that is not a whole number");
            return;
        }
        ast_add_local(@lname + i * 64);
        i += 1;
    }
}

// ---------------------------------------------------------------- expressions

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
            if first == 0 { first = e; } else { ast_c[last] = e; }
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
    return ast_node(AK_CALL, first, 0, 0, fidx);
}

int ast_primary() {
    if tok_kind == T_NUM {
        if tok_float == 1 {
            ast_fail("a number with a decimal point");
            return 0;
        }
        int v = tok_num;
        next();
        return ast_node(AK_NUM, 0, 0, 0, v);
    }
    if tok_is("(") {
        next();
        int e = ast_expr(0);
        if ast_ok == 0 { return 0; }
        if !tok_is(")") {
            ast_fail("a bracket that is not closed");
            return 0;
        }
        next();
        return e;
    }
    if tok_is("-") {
        next();
        int a = ast_primary();
        if ast_ok == 0 { return 0; }
        return ast_node(AK_NEG, a, 0, 0, 0);
    }
    if tok_is("!") {
        next();
        int a2 = ast_primary();
        if ast_ok == 0 { return 0; }
        return ast_node(AK_NOT, a2, 0, 0, 0);
    }
    if tok_kind == T_IDENT {
        char nm[64];
        str_copy(@nm, @tok_text, 64);
        next();
        if tok_is("(") {
            int fi = find_func(@nm);
            if fi < 0 {
                ast_fail("a call of a function that is not known yet");
                return 0;
            }
            if fvoid[fi] == 1 || fret[fi] != 0 || fretdyn[fi] != 0 || fbuiltin[fi] == 1 || fop[fi] == 1 {
                ast_fail("a call of a function that does not return a whole number (or a library function)");
                return 0;
            }
            return ast_call(fi);
        }
        int li = ast_find_local(@nm);
        if li < 0 {
            ast_fail("a name that is not a whole number local or parameter");
            return 0;
        }
        return ast_node(AK_VAR, 0, 0, 0, li);
    }
    ast_fail("an expression that is not in the subset");
    return 0;
}

// the level of the operator at the current token (0: not a binary operator) and its code; higher binds tighter
int ast_op_code;
int ast_op_level() {
    ast_op_code = 0;
    if tok_kind == T_OP {
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

int ast_stmt() {
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
            return ast_node(AK_FOR, from, to, body2, li);
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
        if tok_is("int") {
            next();
            if tok_kind != T_IDENT {
                ast_fail("a declaration that is not understood");
                return 0;
            }
            char dn[64];
            str_copy(@dn, @tok_text, 64);
            next();
            int init = 0;
            if tok_is("=") {
                next();
                init = ast_expr(0);
                if ast_ok == 0 { return 0; }
            }
            if !tok_is(";") {
                ast_fail("a declaration that is not understood (an array, a pointer or a list)");
                return 0;
            }
            next();
            int di = ast_add_local(@dn);
            return ast_node(AK_DECL, init, 0, 0, di);
        }
        // `name = expr;`  `name += expr;`  `f(args);`
        char nm[64];
        str_copy(@nm, @tok_text, 64);
        next();
        if tok_is("(") {
            int fi = find_func(@nm);
            if fi < 0 || fbuiltin[fi] == 1 || fop[fi] == 1 {
                ast_fail("a call that is not in the subset");
                return 0;
            }
            if fnpar[fi] < 0 {
                ast_fail("a call that is not in the subset");
                return 0;
            }
            int cn = ast_call(fi);
            if ast_ok == 0 { return 0; }
            if !tok_is(";") {
                ast_fail("a statement that is not understood");
                return 0;
            }
            next();
            return ast_node(AK_EXPR, cn, 0, 0, 0);
        }
        int li2 = ast_find_local(@nm);
        if li2 < 0 {
            ast_fail("a statement that is not in the subset");
            return 0;
        }
        int opc = 0;
        if tok_kind == T_OP && tok_is("=") {
            opc = 0;
        } else if tok_kind == T_OP && ast_stmt_assign_op(@tok_text) != 0 {
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
        return ast_node(AK_ASSIGN, v2, opc, 0, li2);
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
        if first == 0 { first = s; } else { ast_c[last] = s; }
        last = s;
    }
    next();
    ast_nl = saved_nl;
    return ast_node(AK_BLOCK, first, 0, 0, 0);
}

// ---------------------------------------------------------------- the probe
// the state of the lexer, put back after the body was read
int aq_pos; int aq_line; int aq_ls; int aq_base; int aq_len; int aq_depth;
int aq_kind; int aq_num; int aq_float; int aq_mant; int aq_exp; int aq_char; int aq_strlen; int aq_seq;
int aq_ptl; int aq_pel; int aq_pec; int aq_peb; int aq_pels;
int aq_eline; int aq_ecol; int aq_ebase; int aq_els;
char aq_text[256];
char aq_str[1024];

void ast_save() {
    aq_pos = cur_pos; aq_line = cur_line; aq_ls = cur_line_start; aq_base = cur_base; aq_len = cur_len; aq_depth = lx_depth;
    aq_kind = tok_kind; aq_num = tok_num; aq_float = tok_float; aq_mant = tok_mant; aq_exp = tok_exp; aq_char = tok_char;
    aq_strlen = tok_str_len; aq_seq = tok_seq;
    aq_ptl = prev_tok_line; aq_pel = prev_end_line; aq_pec = prev_end_col; aq_peb = prev_end_base; aq_pels = prev_end_ls;
    aq_eline = err_line; aq_ecol = err_col; aq_ebase = err_base; aq_els = err_ls;
    str_copy(@aq_text, @tok_text, 256);
    str_copy(@aq_str, @tok_str, 1024);
}

void ast_restore() {
    cur_pos = aq_pos; cur_line = aq_line; cur_line_start = aq_ls; cur_base = aq_base; cur_len = aq_len; lx_depth = aq_depth;
    tok_kind = aq_kind; tok_num = aq_num; tok_float = aq_float; tok_mant = aq_mant; tok_exp = aq_exp; tok_char = aq_char;
    tok_str_len = aq_strlen; tok_seq = aq_seq;
    prev_tok_line = aq_ptl; prev_end_line = aq_pel; prev_end_col = aq_pec; prev_end_base = aq_peb; prev_end_ls = aq_pels;
    err_line = aq_eline; err_col = aq_ecol; err_base = aq_ebase; err_ls = aq_els;
    str_copy(@tok_text, @aq_text, 256);
    str_copy(@tok_str, @aq_str, 1024);
}

// the current token is the `{` of the body of the function f_idx. Returns true when the body is in the subset (ast_root is its block).
bool ast_probe(int f_idx) {
    ast_root = 0;
    if ast_report == 0 { return false; }
    ast_save();
    int keep_pass = pass_no;
    pass_no = 0;                             // the lexer's warnings were given (or will be) by the real reading
    ast_n = 0;
    ast_ok = 1;
    ast_why[0] = 0;
    ast_loop_depth = 0;
    ast_load_params();
    int root = 0;
    if ast_ok == 1 { root = ast_block(); }
    pass_no = keep_pass;
    ast_restore();
    ast_funcs += 1;
    if ast_ok == 1 {
        ast_funcs_ok += 1;
        ast_root = root;
    }
    if ast_report == 1 {
        write_err("ast: ");
        write_err(@fname + f_idx * 64);
        if ast_ok == 1 {
            write_err(" is in the subset\n");
        } else {
            write_err(" is not: ");
            write_err(@ast_why);
            write_err("\n");
        }
    }
    return ast_ok == 1;
}
