// jc_opt.j -- passes on the IR (jc_ir.j). The first pass: loop-invariant constants.
//
// A whole number constant that needs more than one instruction (a 64-bit constant such as the multiplier of a division by 7) and is made
// inside a loop is made again at every turn. This pass finds the loops (a back edge goes to a block that dominates its source), puts the
// constant into a stack cell in a new block in front of the OUTERMOST loop that holds it, and the loop reads the cell. The register pass
// (jc_regs.j) then keeps the cell in a register when one is free; if not, a load costs less than four instructions.

#define OP_MAXL 1024
#define OP_MAXH 512

int op_s1[IR_MAXB];              // the successors of a block (-1 = none)
int op_s2[IR_MAXB];
int op_phead[IR_MAXB];           // the predecessors: a list of edges, an edge e = 2 * (the block it comes from) + 0 or 1
int op_enext[16384];
int op_po[IR_MAXB];              // the number of a block in the post order (-1: the flow never gets there)
int op_rpo[IR_MAXB];             // the blocks in reverse post order
int op_nrpo;
int op_idom[IR_MAXB];
int op_mark[IR_MAXB];            // the loop that a block belongs to is marked with the stamp of the loop being looked at
int op_stamp;
int op_stack[IR_MAXB];
int op_dfs_b[IR_MAXB];           // the stack of the depth first search: the block and which successor is next
int op_dfs_k[IR_MAXB];
int op_outer[IR_MAXB];           // the outermost loop (an index into op_lh) that a block is in, or -1

int op_bsrc[4096];        // the back edges: from, to
int op_bdst[4096];
int op_nback;
int op_lh[OP_MAXL];              // the loops: the header, the size
int op_lsize[OP_MAXL];
int op_nloops;

int op_hl[OP_MAXH];              // the hoisted constants: the loop, the value, the cell (k of the load)
int op_hv[OP_MAXH];
int op_hq[OP_MAXH];
int op_nh;

int op_hoisted;                  // how many constants were moved out of loops (all functions; for -irstat)

int op_succ(int b, int k) {
    if k == 0 { return op_s1[b]; }
    return op_s2[b];
}

// does the block a dominate the block b?
bool op_dom(int a, int b) {
    int x = b;
    while true {
        if x == a { return true; }
        if x == 0 { return false; }
        x = op_idom[x];
        if x < 0 { return false; }
    }
    return false;
}

int op_intersect(int a, int b) {
    int x = a;
    int y = b;
    while x != y {
        while op_po[x] < op_po[y] { x = op_idom[x]; }
        while op_po[y] < op_po[x] { y = op_idom[y]; }
    }
    return x;
}

// the graph: successors, predecessors, post order, immediate dominators
void op_graph() {
    int b = 0;
    while b < ir_nb {
        int t = ir_be[b] - 1;
        int op = ir_op[t];
        op_s1[b] = 0 - 1;
        op_s2[b] = 0 - 1;
        if op == IR_JMP { op_s1[b] = ir_t1[t]; }
        if op == IR_BR || op == IR_FBR {
            op_s1[b] = ir_t1[t];
            op_s2[b] = ir_t2[t];
        }
        op_phead[b] = 0 - 1;
        op_po[b] = 0 - 1;
        op_idom[b] = 0 - 1;
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        int k = 0;
        while k < 2 {
            int s = op_succ(b, k);
            if s >= 0 {
                int e = b * 2 + k;
                op_enext[e] = op_phead[s];
                op_phead[s] = e;
            }
            k += 1;
        }
        b += 1;
    }
    // the depth first search from the entry (an explicit stack)
    int sp = 0;
    int npo = 0;
    op_mark[0] = 0 - 7;
    op_dfs_b[0] = 0;
    op_dfs_k[0] = 0;
    sp = 1;
    int seen_stamp = 0 - 7;
    b = 1;
    while b < ir_nb {
        op_mark[b] = 0;
        b += 1;
    }
    while sp > 0 {
        int cb = op_dfs_b[sp - 1];
        int ck = op_dfs_k[sp - 1];
        if ck >= 2 {
            op_po[cb] = npo;
            op_rpo[ir_nb - 1 - npo] = cb;
            npo += 1;
            sp -= 1;
        } else {
            op_dfs_k[sp - 1] = ck + 1;
            int s2 = op_succ(cb, ck);
            if s2 >= 0 && op_mark[s2] != seen_stamp {
                op_mark[s2] = seen_stamp;
                op_dfs_b[sp] = s2;
                op_dfs_k[sp] = 0;
                sp += 1;
            }
        }
    }
    // op_rpo holds the blocks that were reached at the END of the array (npo of them)
    op_nrpo = npo;
    int shift = ir_nb - npo;
    int r = 0;
    while r < npo {
        op_rpo[r] = op_rpo[r + shift];
        r += 1;
    }
    // dominators (Cooper, Harvey, Kennedy)
    op_idom[0] = 0;
    bool changed = true;
    while changed {
        changed = false;
        int ri = 1;
        while ri < npo {
            int blk = op_rpo[ri];
            int ni = 0 - 1;
            int e = op_phead[blk];
            while e >= 0 {
                int p = e / 2;
                if op_po[p] >= 0 && op_idom[p] >= 0 {
                    if ni < 0 { ni = p; } else { ni = op_intersect(p, ni); }
                }
                e = op_enext[e];
            }
            if ni >= 0 && op_idom[blk] != ni {
                op_idom[blk] = ni;
                changed = true;
            }
            ri += 1;
        }
    }
}

// mark the blocks of the loop number l (its header and every block that reaches a back edge source without passing the header)
int op_mark_loop(int l) {
    op_stamp += 1;
    int h = op_lh[l];
    int n = 1;
    int sp = 0;
    op_mark[h] = op_stamp;
    int i = 0;
    while i < op_nback {
        if op_bdst[i] == h && op_mark[op_bsrc[i]] != op_stamp {
            op_mark[op_bsrc[i]] = op_stamp;
            op_stack[sp] = op_bsrc[i];
            sp += 1;
            n += 1;
        }
        i += 1;
    }
    while sp > 0 {
        sp -= 1;
        int x = op_stack[sp];
        int e = op_phead[x];
        while e >= 0 {
            int p = e / 2;
            if op_po[p] >= 0 && op_mark[p] != op_stamp {
                op_mark[p] = op_stamp;
                op_stack[sp] = p;
                sp += 1;
                n += 1;
            }
            e = op_enext[e];
        }
    }
    return n;
}

// does the constant need more than one instruction? (counts the 16-bit pieces that are not all 0, or for a negative number not all 1)
bool op_costly(int k) {
    int fill = 0;
    if k < 0 { fill = 65535; }
    int n = 0;
    int c = 0;
    while c < 4 {
        if ((k >> (c * 16)) & 65535) != fill { n += 1; }
        c += 1;
    }
    return n >= 2;
}

// the stack cells that exist already: the deepest one
int op_maxq() {
    int m = 0;
    int i = 0;
    while i < ir_n {
        if (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE) && ir_a[i] == 30 && ir_k[i] < 0 {
            if 0 - ir_k[i] > m { m = 0 - ir_k[i]; }
        }
        i += 1;
    }
    return m;
}

void op_run() {
    op_graph();
    // the back edges
    op_nback = 0;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int k = 0;
            while k < 2 {
                int s = op_succ(b, k);
                if s >= 0 && op_dom(s, b) && op_nback < OP_MAXL * 4 {
                    op_bsrc[op_nback] = b;
                    op_bdst[op_nback] = s;
                    op_nback += 1;
                }
                k += 1;
            }
        }
        b += 1;
    }
    if op_nback == 0 { return; }
    // the loops (one for each header), the biggest first
    op_nloops = 0;
    int i = 0;
    while i < op_nback {
        int h = op_bdst[i];
        bool known = false;
        int j = 0;
        while j < op_nloops {
            if op_lh[j] == h { known = true; }
            j += 1;
        }
        if !known && h != 0 && op_nloops < OP_MAXL {
            op_lh[op_nloops] = h;
            op_nloops += 1;
        }
        i += 1;
    }
    i = 0;
    while i < op_nloops {
        op_lsize[i] = op_mark_loop(i);
        i += 1;
    }
    i = 1;
    while i < op_nloops {
        int th = op_lh[i];
        int ts = op_lsize[i];
        int j = i - 1;
        while j >= 0 && op_lsize[j] < ts {
            op_lh[j + 1] = op_lh[j];
            op_lsize[j + 1] = op_lsize[j];
            j -= 1;
        }
        op_lh[j + 1] = th;
        op_lsize[j + 1] = ts;
        i += 1;
    }
    b = 0;
    while b < ir_nb {
        op_outer[b] = 0 - 1;
        b += 1;
    }
    i = 0;
    while i < op_nloops {
        op_mark_loop(i);
        b = 0;
        while b < ir_nb {
            if op_mark[b] == op_stamp && op_outer[b] < 0 { op_outer[b] = i; }
            b += 1;
        }
        i += 1;
    }
    // the constants in loops: read from a cell that the new block in front of the loop fills
    int q = op_maxq();
    int nb0 = ir_nb;
    op_nh = 0;
    b = 0;
    while b < nb0 {
        int l = op_outer[b];
        if l >= 0 {
            int p = ir_bs[b];
            while p < ir_be[b] {
                if ir_op[p] == IR_CONST && ir_d[p] >= 1 && ir_d[p] <= 31 && op_costly(ir_k[p]) {
                    int hi = 0 - 1;
                    int u = 0;
                    while u < op_nh {
                        if op_hl[u] == l && op_hv[u] == ir_k[p] { hi = u; }
                        u += 1;
                    }
                    if hi < 0 && op_nh < OP_MAXH {
                        q += 8;
                        op_hl[op_nh] = l;
                        op_hv[op_nh] = ir_k[p];
                        op_hq[op_nh] = 0 - q;
                        hi = op_nh;
                        op_nh += 1;
                    }
                    if hi >= 0 {
                        ir_op[p] = IR_LOAD;
                        ir_a[p] = 30;
                        ir_k[p] = op_hq[hi];
                        ir_w[p] = 8;
                        op_hoisted += 1;
                    }
                }
                p += 1;
            }
        }
        b += 1;
    }
    // one new block in front of each loop that got a constant
    i = 0;
    while i < op_nloops {
        bool any = false;
        int u2 = 0;
        while u2 < op_nh {
            if op_hl[u2] == i { any = true; }
            u2 += 1;
        }
        if any {
            int pre = ir_new_block(0 - 1);
            ir_set_block(pre);
            u2 = 0;
            while u2 < op_nh {
                if op_hl[u2] == i {
                    int tv = ir_vreg(0);
                    ir_add(IR_CONST, tv, 0, 0, 0, op_hv[u2]);
                    int st = ir_add(IR_STORE, 0, 30, tv, 0, op_hq[u2]);
                    ir_w[st] = 8;
                }
                u2 += 1;
            }
            int jm = ir_add(IR_JMP, 0, 0, 0, 0, 0);
            int hh = op_lh[i];
            ir_t1[jm] = hh;
            // every jump to the header from outside the loop goes to the new block
            op_mark_loop(i);
            b = 0;
            while b < nb0 {
                if op_mark[b] != op_stamp {
                    int t = ir_be[b] - 1;
                    int top = ir_op[t];
                    if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[t] == hh { ir_t1[t] = pre; }
                    if (top == IR_BR || top == IR_FBR) && ir_t2[t] == hh { ir_t2[t] = pre; }
                }
                b += 1;
            }
        }
        i += 1;
    }
}

// ---------------------------------------------------------------------------------------------- liveness and webs
// A "web" is the set of definitions of one machine register that are connected through their uses (what a renaming to virtual registers
// needs). Only the registers x0..x30 / d0..d31 (vregs 1..63) are looked at; the temporaries (vregs from 64) live inside a block.

int op_li[IR_MAXB];              // live-in registers of a block: bit v is the vreg v
int op_lo[IR_MAXB];
int op_exit[524288];             // the definition (an instruction number + 1, or 65536 + block * 64 + register + 1) that a register has at the end of a block, or 0
int op_uf[589824];               // union-find over: the instructions (their results) and the live-in nodes
int op_cur[64];
int opn_a[IR_MAXI];             // the node (see op_exit) of the definition that reaches each operand: -1 not a machine register, -2 none reaches
int opn_b[IR_MAXI];
int opn_g[IR_MAXA];
int ldef[IR_MAXB];
int op_seen[589824];
int op_fn_stamp;
int op_tot_defs;
int op_tot_webs;
int op_tot_fixed;

int op_clobber() {
    // caller-saved: x0..x18 (vregs 1..19), d0..d7 (32..39), d16..d31 (48..63)
    int m = 0;
    int v = 1;
    while v <= 19 { m = m | (1 << v); v += 1; }
    v = 32;
    while v <= 39 { m = m | (1 << v); v += 1; }
    v = 48;
    while v <= 63 { m = m | (1 << v); v += 1; }
    return m;
}

int op_bit(int v) {
    if v >= 1 && v <= 63 { return 1 << v; }
    return 0;
}

int op_uses(int i) {
    int m = op_bit(ir_a[i]);
    int op = ir_op[i];
    if ir_uses_b(op) && ir_bi[i] == 0 { m = m | op_bit(ir_b[i]); }
    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        int a = 0;
        while a < ir_ac[i] {
            m = m | op_bit(ir_args[ir_as[i] + a]);
            a += 1;
        }
    }
    return m;
}

int op_defs(int i) {
    int op = ir_op[i];
    int m = op_bit(ir_d[i]);
    if op == IR_CALL || op == IR_CALLIND { m = m | op_clobber(); }
    return m;
}

int op_find(int x) {
    int r = x;
    while op_uf[r] != r { r = op_uf[r]; }
    while op_uf[x] != r {
        int nx = op_uf[x];
        op_uf[x] = r;
        x = nx;
    }
    return r;
}

void op_union(int a, int b) {
    int ra = op_find(a);
    int rb = op_find(b);
    if ra != rb { op_uf[ra] = rb; }
}

// the nodes of the definitions that reach the operands of the instruction i (op_cur says what each register holds now)
int op_node(int v) {
    if v < 1 || v > 63 { return 0 - 1; }
    if op_cur[v] == 0 { return 0 - 2; }
    return op_cur[v] - 1;
}

void op_record(int i) {
    int op = ir_op[i];
    opn_a[i] = op_node(ir_a[i]);
    opn_b[i] = 0 - 1;
    if ir_uses_b(op) && ir_bi[i] == 0 { opn_b[i] = op_node(ir_b[i]); }
    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        int a = 0;
        while a < ir_ac[i] {
            opn_g[ir_as[i] + a] = op_node(ir_args[ir_as[i] + a]);
            a += 1;
        }
    }
}

// liveness of the machine registers over the blocks, then the webs; returns the number of webs of the function
int op_webs() {
    op_graph();
    // use / def of each block
    int b = 0;
    while b < ir_nb {
        int u = 0;
        int d = 0;
        int i = ir_bs[b];
        while i < ir_be[b] {
            u = u | (op_uses(i) & ~d);
            d = d | op_defs(i);
            i += 1;
        }
        op_li[b] = u;
        op_lo[b] = d;                 // op_lo holds the defs for now
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        ldef[b] = op_lo[b];
        op_lo[b] = 0;
        b += 1;
    }
    bool changed = true;
    while changed {
        changed = false;
        int ri = op_nrpo - 1;
        while ri >= 0 {
            int blk = op_rpo[ri];
            int out = 0;
            int k = 0;
            while k < 2 {
                int s = op_succ(blk, k);
                if s >= 0 { out = out | op_li[s]; }
                k += 1;
            }
            int uu = 0;
            int i2 = ir_bs[blk];
            int dd = 0;
            while i2 < ir_be[blk] {
                uu = uu | (op_uses(i2) & ~dd);
                dd = dd | op_defs(i2);
                i2 += 1;
            }
            int nin = uu | (out & ~ldef[blk]);
            if nin != op_li[blk] || out != op_lo[blk] {
                op_li[blk] = nin;
                op_lo[blk] = out;
                changed = true;
            }
            ri -= 1;
        }
    }
    // the nodes
    int nn = 65536 + ir_nb * 64;
    int x = 0;
    while x < nn {
        op_uf[x] = x;
        x += 1;
    }
    b = 0;
    while b < ir_nb {
        int r = 0;
        while r < 64 {
            op_cur[r] = 0;
            if r >= 1 && (op_li[b] & (1 << r)) != 0 { op_cur[r] = 65536 + b * 64 + r + 1; }
            r += 1;
        }
        int i3 = ir_bs[b];
        while i3 < ir_be[b] {
            op_record(i3);
            int dv = ir_d[i3];
            if dv >= 1 && dv <= 63 { op_cur[dv] = i3 + 1; }
            if ir_op[i3] == IR_CALL || ir_op[i3] == IR_CALLIND {
                int cm = op_clobber();
                int r2 = 1;
                while r2 < 64 {
                    if (cm & (1 << r2)) != 0 && r2 != dv { op_cur[r2] = 0; }
                    r2 += 1;
                }
            }
            i3 += 1;
        }
        r = 0;
        while r < 64 {
            op_exit[b * 64 + r] = op_cur[r];
            r += 1;
        }
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int r3 = 1;
            while r3 < 64 {
                if (op_li[b] & (1 << r3)) != 0 {
                    int e = op_phead[b];
                    while e >= 0 {
                        int p = e / 2;
                        int ex = op_exit[p * 64 + r3];
                        if ex != 0 && op_po[p] >= 0 { op_union(65536 + b * 64 + r3, ex - 1); }
                        e = op_enext[e];
                    }
                }
                r3 += 1;
            }
        }
        b += 1;
    }
    // count: the roots that hold at least one definition
    op_fn_stamp += 1;
    int webs = 0;
    int defs = 0;
    int i4 = 0;
    while i4 < ir_n {
        int dv2 = ir_d[i4];
        if dv2 >= 1 && dv2 <= 63 {
            defs += 1;
            int rt = op_find(i4);
            if op_seen[rt] != op_fn_stamp {
                op_seen[rt] = op_fn_stamp;
                webs += 1;
            }
        }
        i4 += 1;
    }
    op_tot_defs += defs;
    op_tot_webs += webs;
    return webs;
}

// ---------------------------------------------------------------------------------------------- the register allocator on the IR (-irra)
// Every web (see above) that is not tied to a fixed register gets a register again: linear scan over the live interval of the web,
// so that a web can take the register of a copy source that dies at the copy (the copy becomes "mov x, x" and is not written).
// The vregs stay machine registers, so the lowering does not change.

#define OP_MAXW 131072

int w_reg[OP_MAXW];              // the register the web has now
int w_start[OP_MAXW];
int w_end[OP_MAXW];
int w_fixed[OP_MAXW];
int w_new[OP_MAXW];              // the register it gets (0 = not yet)
int w_defi[OP_MAXW];             // the instruction of its first definition (the copy that may be removed), or -1
int w_ndef[OP_MAXW];
int w_bnext[OP_MAXW];
int w_nextf[OP_MAXW];
int op_nw;
int op_wmap[589824];
int op_pos[IR_MAXI];
int op_bpos0[IR_MAXB];           // the first / last position of a block
int op_bpos1[IR_MAXB];
int op_bhead[65540];
int op_cumcall[65540];
int op_reserved[64];
int op_busy[64];
int op_lastw[64];
int op_fbusy[64];
int op_fhead[64];
int op_ra_changes;
int op_ra_removed;
int op_ra_webs;

bool op_in_pool(int r) {
    return (r >= 1 && r <= 15) || (r >= 32 && r <= 39) || (r >= 48 && r <= 61 && r != 59);
}

int op_web(int node, int reg) {
    int root = op_find(node);
    if op_seen[root] != op_fn_stamp {
        if op_nw >= OP_MAXW { return 0 - 1; }
        op_seen[root] = op_fn_stamp;
        op_wmap[root] = op_nw;
        w_reg[op_nw] = reg;
        w_start[op_nw] = 1000000000;
        w_end[op_nw] = 0 - 1;
        w_fixed[op_nw] = 0;
        w_new[op_nw] = 0;
        w_defi[op_nw] = 0 - 1;
        w_ndef[op_nw] = 0;
        op_nw += 1;
    }
    return op_wmap[root];
}

int op_node_reg(int node) {
    if node >= 65536 { return (node - 65536) % 64; }
    return ir_d[node];
}

void op_touch(int w, int p) {
    if w < 0 { return; }
    if p < w_start[w] { w_start[w] = p; }
    if p > w_end[w] { w_end[w] = p; }
}

// a use of the operand node n at the position p of the instruction i; fixed: the instruction needs the register as it is
void op_use(int n, int p, bool fixed) {
    if n == 0 - 1 { return; }
    if n == 0 - 2 { return; }
    int w = op_web(n, op_node_reg(n));
    if w < 0 { return; }
    op_touch(w, p);
    if fixed { w_fixed[w] = 1; }
}

// can the web [s, e] take the register rr? (srcw: the source of the copy that defines it, which may end where it starts, but only in want)
bool op_try(int rr, int s, int e, int srcw, int want) {
    if rr < 1 || !op_in_pool(rr) || op_reserved[rr] == 1 { return false; }
    while op_fhead[rr] >= 0 && w_start[op_fhead[rr]] <= s {
        if w_end[op_fhead[rr]] > op_fbusy[rr] { op_fbusy[rr] = w_end[op_fhead[rr]]; }
        op_fhead[rr] = w_nextf[op_fhead[rr]];
    }
    if op_fbusy[rr] >= s { return false; }
    if op_fhead[rr] >= 0 && w_start[op_fhead[rr]] <= e { return false; }
    if op_busy[rr] >= s {
        if op_busy[rr] == s && srcw >= 0 && op_lastw[rr] == srcw && rr == want { return true; }
        return false;
    }
    return true;
}

bool op_ra_run() {
    op_webs();
    op_fn_stamp += 1;
    op_nw = 0;
    // positions: the reachable blocks in reverse post order
    int npos = 0;
    int ri = 0;
    while ri < op_nrpo {
        int b = op_rpo[ri];
        op_bpos0[b] = npos;
        int i = ir_bs[b];
        while i < ir_be[b] {
            op_pos[i] = npos;
            npos += 1;
            i += 1;
        }
        op_bpos1[b] = npos - 1;
        ri += 1;
    }
    int r = 0;
    while r < 64 {
        op_reserved[r] = 0;
        r += 1;
    }
    // definitions and uses
    ri = 0;
    while ri < op_nrpo {
        int b2 = op_rpo[ri];
        int i2 = ir_bs[b2];
        while i2 < ir_be[b2] {
            int p = op_pos[i2];
            int op = ir_op[i2];
            bool call = op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL;
            if op == IR_CALL || op == IR_CALLIND { op_cumcall[p] = 1; } else { op_cumcall[p] = 0; }
            bool special = call || op == IR_RET;
            int dv = ir_d[i2];
            if dv >= 1 && dv <= 63 {
                int w = op_web(i2, dv);
                if w < 0 { return false; }
                op_touch(w, p);
                w_ndef[w] += 1;
                if w_defi[w] < 0 { w_defi[w] = i2; }
                if call || op == IR_PARAM || (op == IR_ADDR_SLOT && dv == 30) { w_fixed[w] = 1; }
            }
            if opn_a[i2] == 0 - 2 && ir_a[i2] >= 1 && ir_a[i2] <= 63 { op_reserved[ir_a[i2]] = 1; }
            op_use(opn_a[i2], p, special);
            if opn_b[i2] == 0 - 2 && ir_uses_b(op) && ir_bi[i2] == 0 && ir_b[i2] >= 1 && ir_b[i2] <= 63 { op_reserved[ir_b[i2]] = 1; }
            op_use(opn_b[i2], p, special);
            if call {
                int a = 0;
                while a < ir_ac[i2] {
                    int g = ir_as[i2] + a;
                    if opn_g[g] == 0 - 2 && ir_args[g] >= 1 && ir_args[g] <= 63 { op_reserved[ir_args[g]] = 1; }
                    op_use(opn_g[g], p, true);
                    a += 1;
                }
            }
            i2 += 1;
        }
        ri += 1;
    }
    // the registers that are live across the borders of blocks
    ri = 0;
    while ri < op_nrpo {
        int b3 = op_rpo[ri];
        int r2 = 1;
        while r2 < 64 {
            if (op_li[b3] & (1 << r2)) != 0 {
                int w = op_web(65536 + b3 * 64 + r2, r2);
                if w < 0 { return false; }
                op_touch(w, op_bpos0[b3]);
            }
            if (op_lo[b3] & (1 << r2)) != 0 && op_exit[b3 * 64 + r2] != 0 {
                int w2 = op_web(op_exit[b3 * 64 + r2] - 1, r2);
                if w2 < 0 { return false; }
                op_touch(w2, op_bpos1[b3]);
            }
            r2 += 1;
        }
        ri += 1;
    }
    op_ra_webs += op_nw;
    // the webs that cross a call, or are not in the pool, stay where they are
    int p2 = 0;
    int run = 0;
    while p2 < npos {
        run += op_cumcall[p2];
        op_cumcall[p2] = run;
        p2 += 1;
    }
    int w3 = 0;
    while w3 < op_nw {
        if w_end[w3] < w_start[w3] { w_end[w3] = w_start[w3]; }
        if !op_in_pool(w_reg[w3]) || op_reserved[w_reg[w3]] == 1 { w_fixed[w3] = 1; }
        if w_end[w3] - w_start[w3] >= 2 {
            int c1 = op_cumcall[w_end[w3] - 1];
            int c0 = op_cumcall[w_start[w3]];
            if c1 > c0 { w_fixed[w3] = 1; }
        }
        w3 += 1;
    }
    // buckets by start position; the fixed webs of each register in order of their start
    int pp = 0;
    while pp <= npos {
        op_bhead[pp] = 0 - 1;
        pp += 1;
    }
    w3 = 0;
    while w3 < op_nw {
        w_bnext[w3] = op_bhead[w_start[w3]];
        op_bhead[w_start[w3]] = w3;
        w3 += 1;
    }
    r = 0;
    while r < 64 {
        op_fhead[r] = 0 - 1;
        op_busy[r] = 0 - 1;
        op_lastw[r] = 0 - 1;
        op_fbusy[r] = 0 - 1;
        r += 1;
    }
    pp = npos - 1;
    while pp >= 0 {
        int w4 = op_bhead[pp];
        while w4 >= 0 {
            if w_fixed[w4] == 1 {
                w_nextf[w4] = op_fhead[w_reg[w4]];
                op_fhead[w_reg[w4]] = w4;
                w_new[w4] = w_reg[w4];
            }
            w4 = w_bnext[w4];
        }
        pp -= 1;
    }
    // the scan
    int changes = 0;
    pp = 0;
    while pp < npos {
        int w5 = op_bhead[pp];
        while w5 >= 0 {
            if w_fixed[w5] == 0 {
                int s = w_start[w5];
                int e = w_end[w5];
                int want = 0;
                // a copy whose source dies at the copy: the same register
                int di = w_defi[w5];
                int srcw = 0 - 1;
                if w_ndef[w5] == 1 && di >= 0 && ir_op[di] == IR_COPY && opn_a[di] >= 0 {
                    srcw = op_web(opn_a[di], op_node_reg(opn_a[di]));
                    if srcw >= 0 && w_end[srcw] == s && w_new[srcw] != 0 && w_fixed[srcw] == 0 { want = w_new[srcw]; }
                }
                int chosen = 0;
                if want > 0 && op_try(want, s, e, srcw, want) { chosen = want; }
                if chosen == 0 && op_try(w_reg[w5], s, e, srcw, want) { chosen = w_reg[w5]; }
                if chosen == 0 {
                    int lo = 1;
                    int hi = 15;
                    if w_reg[w5] >= 32 { lo = 32; hi = 61; }
                    int scan = lo;
                    while chosen == 0 && scan <= hi {
                        if op_try(scan, s, e, srcw, want) { chosen = scan; }
                        scan += 1;
                    }
                }
                if chosen == 0 {
                    chosen = w_reg[w5];                // nothing free: it stays (cannot happen for a web that is alone on its register)
                    w_fixed[w5] = 1;
                    return false;
                }
                w_new[w5] = chosen;
                op_busy[chosen] = e;
                op_lastw[chosen] = w5;
            }
            w5 = w_bnext[w5];
        }
        pp += 1;
    }
    // write the registers into the instructions
    ri = 0;
    while ri < op_nrpo {
        int b6 = op_rpo[ri];
        int i6 = ir_bs[b6];
        while i6 < ir_be[b6] {
            int op6 = ir_op[i6];
            int dv6 = ir_d[i6];
            if opn_a[i6] >= 0 && ir_a[i6] >= 1 && ir_a[i6] <= 63 {
                int wa = op_web(opn_a[i6], ir_a[i6]);
                if w_new[wa] != ir_a[i6] { ir_a[i6] = w_new[wa]; changes += 1; }
            }
            if opn_b[i6] >= 0 && ir_uses_b(op6) && ir_bi[i6] == 0 && ir_b[i6] >= 1 && ir_b[i6] <= 63 {
                int wb = op_web(opn_b[i6], ir_b[i6]);
                if w_new[wb] != ir_b[i6] { ir_b[i6] = w_new[wb]; changes += 1; }
            }
            if dv6 >= 1 && dv6 <= 63 {
                int wd = op_web(i6, dv6);
                if w_new[wd] != dv6 { ir_d[i6] = w_new[wd]; changes += 1; }
            }
            i6 += 1;
        }
        ri += 1;
    }
    op_ra_changes += changes;
    return true;
}

// ---------------------------------------------------------------------------------------------- copies, constants, dead code (-iropt)
// In each block, going forward: an operand that is a copy of another register reads that register (the copy dies when nothing else
// reads it), an operand that is a small constant becomes an immediate. Then, going backward over the liveness: an instruction without side
// effect whose result nobody reads is removed.

int cp_kind[IR_MAXV];            // 0 nothing known, 1 the vreg holds a constant, 2 it is a copy of cp_val
int cp_val[IR_MAXV];
int cp_stamp[IR_MAXV];
int cp_cur;
int cp_act[64];                  // the vregs that have a kind now (to be killed when their source is written)
int cp_nact;
int op_clean_changes;

int cp_get(int v) {
    if v < 1 || v >= ir_nv || cp_stamp[v] != cp_cur { return 0; }
    return cp_kind[v];
}

void cp_kill(int d) {
    if d < 1 || d >= ir_nv { return; }
    if cp_stamp[d] == cp_cur { cp_kind[d] = 0; }
    int k = 0;
    while k < cp_nact {
        int v = cp_act[k];
        if cp_stamp[v] == cp_cur && cp_kind[v] == 2 && cp_val[v] == d { cp_kind[v] = 0; }
        k += 1;
    }
}

void cp_set(int v, int kind, int val) {
    if v < 1 || v >= ir_nv { return; }
    if cp_nact >= 64 {
        cp_cur += 1;
        cp_nact = 0;
    }
    cp_stamp[v] = cp_cur;
    cp_kind[v] = kind;
    cp_val[v] = val;
    cp_act[cp_nact] = v;
    cp_nact += 1;
}

// what a use of v reads: the register it is a copy of (or v)
int cp_root(int v) {
    if cp_get(v) == 2 { return cp_val[v]; }
    return v;
}

bool cp_small(int k, int hi) {
    return k >= 0 && k <= hi;
}

int cp_flip(int cc) {
    if cc == IR_LT { return IR_GT; }
    if cc == IR_GT { return IR_LT; }
    if cc == IR_LE { return IR_GE; }
    if cc == IR_GE { return IR_LE; }
    if cc == IR_ULT { return IR_UGT; }
    if cc == IR_UGT { return IR_ULT; }
    if cc == IR_ULE { return IR_UGE; }
    if cc == IR_UGE { return IR_ULE; }
    return cc;
}

void op_prop_block(int b) {
    cp_cur += 1;
    cp_nact = 0;
    int i = ir_bs[b];
    while i < ir_be[b] {
        int op = ir_op[i];
        bool fixed = op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_RET;
        if !fixed {
            int a = ir_a[i];
            if a != 0 && cp_get(a) == 2 && ir_vcls[cp_val[a]] == ir_vcls[a] {
                ir_a[i] = cp_val[a];
                op_clean_changes += 1;
            }
            if ir_uses_b(op) && ir_bi[i] == 0 {
                int bv = ir_b[i];
                if cp_get(bv) == 2 && ir_vcls[cp_val[bv]] == ir_vcls[bv] {
                    ir_b[i] = cp_val[bv];
                    op_clean_changes += 1;
                }
                bv = ir_b[i];
                if cp_get(bv) == 1 && ir_vcls[bv] == 0 {
                    int k = cp_val[bv];
                    bool ok = false;
                    if op == IR_ADD || op == IR_SUB || op == IR_SETCC || op == IR_BR { ok = cp_small(k, 4095); }
                    if op == IR_SHL || op == IR_LSHR || op == IR_ASHR || op == IR_ROTR { ok = cp_small(k, 63); }
                    if ok {
                        ir_bi[i] = 1;
                        ir_b[i] = k;
                        op_clean_changes += 1;
                    }
                }
                // a constant first operand of a commutative operation or a comparison
                if ir_bi[i] == 0 && cp_get(ir_a[i]) == 1 && ir_vcls[ir_a[i]] == 0 && cp_get(ir_b[i]) != 1 {
                    int k2 = cp_val[ir_a[i]];
                    if op == IR_ADD && cp_small(k2, 4095) {
                        ir_a[i] = ir_b[i];
                        ir_b[i] = k2;
                        ir_bi[i] = 1;
                        op_clean_changes += 1;
                    } else if (op == IR_BR || op == IR_SETCC) && cp_small(k2, 4095) {
                        ir_a[i] = ir_b[i];
                        ir_b[i] = k2;
                        ir_bi[i] = 1;
                        ir_k[i] = cp_flip(ir_k[i]);
                        op_clean_changes += 1;
                    }
                }
            }
        }
        // a double made from a known whole number: a double constant (one instruction when the number fits in 8 bits)
        if op == IR_BITS2F && cp_get(ir_a[i]) == 1 && ir_vcls[ir_d[i]] == 1 {
            ir_op[i] = IR_FCONST;
            ir_k[i] = cp_val[ir_a[i]];
            ir_a[i] = 0;
            ir_bi[i] = 1;
            op_clean_changes += 1;
            op = IR_FCONST;
        }
        // what the instruction writes
        int d = ir_d[i];
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            cp_cur += 1;
            cp_nact = 0;
        } else if d != 0 {
            cp_kill(d);
            if op == IR_CONST && ir_vcls[d] == 0 {
                cp_set(d, 1, ir_k[i]);
            } else if op == IR_COPY && ir_a[i] != d {
                int src = ir_a[i];
                if cp_get(src) == 1 && ir_vcls[d] == 0 {
                    ir_op[i] = IR_CONST;
                    ir_k[i] = cp_val[src];
                    ir_a[i] = 0;
                    cp_set(d, 1, ir_k[i]);
                    op_clean_changes += 1;
                } else {
                    cp_set(d, 2, src);
                }
            }
        }
        i += 1;
    }
}

bool op_pure(int op) {
    return op == IR_CONST || op == IR_COPY || (op >= IR_ADD && op <= IR_MULHS) || op == IR_NEG || op == IR_NOT || op == IR_EXT || op == IR_SETCC
        || (op >= IR_FADD && op <= IR_FSETCC) || op == IR_ADDR_GLOBAL || op == IR_ADDR_FUNC || op == IR_FCONST || (op >= IR_CLZ && op <= IR_POPCNT) || op == IR_FTRUNC || op == IR_FCEIL;
}

int op_tl[IR_MAXV];
int op_tl_stamp[IR_MAXV];
int op_tl_cur;

// dead code: backward in each block with the live registers at its end (op_lo); the temporaries (vregs from 64) live inside a block
void op_dce() {
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int live = op_lo[b];
            op_tl_cur += 1;
            int i = ir_be[b] - 1;
            while i >= ir_bs[b] {
                int op = ir_op[i];
                int d = ir_d[i];
                bool dead = false;
                if (op_pure(op) || (op == IR_LOAD && ir_a[i] == 30)) && d != 0 && op != IR_NOP {
                    if d >= 64 { dead = op_tl_stamp[d] != op_tl_cur || op_tl[d] == 0; }
                    else if (d >= 1 && d <= 15) || (d >= 32 && d <= 61) { dead = (live & (1 << d)) == 0; }
                }
                if dead {
                    ir_op[i] = IR_NOP;
                    ir_d[i] = 0;
                    ir_a[i] = 0;
                    ir_bi[i] = 1;
                    op_clean_changes += 1;
                } else if op != IR_NOP {
                    if d >= 64 {
                        op_tl_stamp[d] = op_tl_cur;
                        op_tl[d] = 0;
                    }
                    live = (live & ~op_defs(i)) | op_uses(i);
                    int a = ir_a[i];
                    if a >= 64 {
                        op_tl_stamp[a] = op_tl_cur;
                        op_tl[a] = 1;
                    }
                    if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] >= 64 {
                        op_tl_stamp[ir_b[i]] = op_tl_cur;
                        op_tl[ir_b[i]] = 1;
                    }
                    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                        int g = 0;
                        while g < ir_ac[i] {
                            if ir_args[ir_as[i] + g] >= 64 {
                                op_tl_stamp[ir_args[ir_as[i] + g]] = op_tl_cur;
                                op_tl[ir_args[ir_as[i] + g]] = 1;
                            }
                            g += 1;
                        }
                    }
                }
                i -= 1;
            }
        }
        b += 1;
    }
}

void op_clean_run() {
    int round = 0;
    while round < 1 {
        op_graph();
        int b = 0;
        while b < ir_nb {
            if op_po[b] >= 0 { op_prop_block(b); }
            b += 1;
        }
        op_webs();                 // liveness
        op_dce();
        round += 1;
    }
}

// ---------------------------------------------------------------------------------------------- value numbering inside a block (-ircse)
// Values are numbered: the same operation on the same values has the same number. A second computation of a value that a register still holds
// becomes a copy of that register; a second computation of a "heavy" value (a multiplication, a division, a square root, or something made of them,
// such as the address b + i * 56 of an element of an array of structs) is read from a new stack cell that the first computation wrote.
// The register pass keeps the cell in a register when one is free. A loop-carried frame cell (a local variable that is a plain 8-byte value) is
// numbered by its version: every store makes a new version, so two loads of the same version are the same value.

#define VN_MAX 60000
int vn_k[VN_MAX];               // the kind (an opcode, or 1000 + something for the others)
int vn_x[VN_MAX];
int vn_y[VN_MAX];
int vn_z[VN_MAX];
int vn_def[VN_MAX];             // the instruction that made it first (in this block), or -1
int vn_heavy[VN_MAX];
int vn_cell[VN_MAX];            // the stack cell (k of the load) it was written to, or 0
int vn_holder[VN_MAX];          // a register that held it last
int vn_inv[VN_MAX];             // the value that F2BITS / BITS2F of this one gives back (0 = none)
int vn_ab[VN_MAX];              // this value is (value vn_ab) + the number vn_ao (an address with an offset), vn_ab = -1: no
int vn_ao[VN_MAX];
int vn_al[VN_MAX];              // the value of a stored cell version is the value that was stored (-1 = none)
int vn_n;
int vn_ht[131072];
int vn_hst[131072];
int vn_hcur;
int vr_vn[IR_MAXV];             // the value number of a register now
int vr_st[IR_MAXV];
int vr_cur;
int vn_ins[IR_MAXI];            // after this instruction a store to this cell must be written
int op_plain[8192];             // 1: the frame slot (offset / 8) is a plain 8-byte value (from the hint line)
int vn_ver[16384];              // the version of a frame slot: index (offset / 8) for offsets >= 0, 8192 + (-offset / 8) for stack cells
int vn_ver_st[16384];
int vn_cell_cur;
int vn_cellvn[16384];
int vn_q;                       // the deepest stack cell now
int vn_changes;
int vn_cellhits;                // how many values were read from a cell instead of being computed again

// the numbers of the hint line  ";H off:size:flag ..."  into op_plain
void vn_hints() {
    int i = 0;
    while i < 8192 {
        op_plain[i] = 0;
        i += 1;
    }
    int n = lf_hint_n;
    int p = 2;
    while p < n {
        while p < n && lf_hint_text[p] == ' ' { p += 1; }
        if p < n {
            int off = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { off = off * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            int size = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { size = size * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            int flag = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { flag = flag * 10 + (lf_hint_text[p] - '0'); p += 1; }
            if size == 8 && flag == 1 && off % 8 == 0 && off / 8 < 8192 && op_plain[off / 8] == 0 { op_plain[off / 8] = 1; }
            else if off / 8 < 8192 {
                // any other entry that covers the slot makes it not plain
                int w = off / 8;
                int w1 = (off + size - 1) / 8;
                if size <= 0 { w1 = w; }
                while w <= w1 && w < 8192 {
                    if !(size == 8 && flag == 1 && off % 8 == 0) { op_plain[w] = 2; }
                    w += 1;
                }
            }
        }
    }
}

// the index of the frame slot an instruction touches (a load or a store of 8 bytes at x29 + k), or -1 when it is not a plain slot
int vn_slot(int i) {
    if ir_a[i] != 30 || ir_w[i] != 8 { return 0 - 1; }
    int k = ir_k[i];
    if k < 0 {
        if (0 - k) / 8 < 8192 && (0 - k) % 8 == 0 { return 8192 + (0 - k) / 8; }
        return 0 - 1;
    }
    if k % 8 == 0 && k / 8 < 8192 && op_plain[k / 8] == 1 { return k / 8; }
    return 0 - 1;
}

int vn_new(int kind, int x, int y, int z) {
    if vn_n >= VN_MAX { return 0 - 1; }
    int v = vn_n;
    vn_n += 1;
    vn_k[v] = kind;
    vn_x[v] = x;
    vn_y[v] = y;
    vn_z[v] = z;
    vn_def[v] = 0 - 1;
    vn_heavy[v] = 0;
    vn_cell[v] = 0;
    vn_holder[v] = 0;
    vn_inv[v] = 0;
    vn_al[v] = 0 - 1;
    vn_ab[v] = 0 - 1;
    vn_ao[v] = 0;
    return v;
}

int vn_hash(int kind, int x, int y, int z) {
    int h = kind * 1000003 + x * 10007 + y * 131 + z * 7 + 12345;
    if h < 0 { h = 0 - h; }
    if h < 0 { h = 0; }
    return h & 131071;
}

// the value with this key, or -1
int vn_find(int kind, int x, int y, int z) {
    int h = vn_hash(kind, x, y, z);
    int n = 0;
    while n < 131072 && vn_hst[h] == vn_hcur {
        int v = vn_ht[h];
        if vn_k[v] == kind && vn_x[v] == x && vn_y[v] == y && vn_z[v] == z { return v; }
        h = (h + 1) & 131071;
        n += 1;
    }
    return 0 - 1;
}

void vn_enter(int v) {
    int h = vn_hash(vn_k[v], vn_x[v], vn_y[v], vn_z[v]);
    int n = 0;
    while n < 131072 && vn_hst[h] == vn_hcur {
        h = (h + 1) & 131071;
        n += 1;
    }
    vn_hst[h] = vn_hcur;
    vn_ht[h] = v;
}

// the value of a register now (a register that was not written in the block holds a value that comes from outside)
int vn_reg(int r) {
    if r < 1 || r >= ir_nv { return 0 - 1; }
    if vr_st[r] == vr_cur { return vr_vn[r]; }
    int v = vn_new(1000, r, 0, 0);
    if v < 0 { return v; }
    vr_vn[r] = v;
    vr_st[r] = vr_cur;
    if r < 64 { vn_holder[v] = r; }
    return v;
}

void vn_set(int r, int v) {
    if r < 1 || r >= ir_nv { return; }
    if v < 0 {
        vr_st[r] = 0;
        return;
    }
    vr_vn[r] = v;
    vr_st[r] = vr_cur;
    if r < 64 { vn_holder[v] = r; }                  // a temporary (vreg >= 64) lives inside one block only
}

bool vn_commutes(int op) {
    return op == IR_ADD || op == IR_MUL || op == IR_AND || op == IR_OR || op == IR_XOR || op == IR_FADD || op == IR_FMUL;
}

bool vn_is_heavy_op(int op) {
    return op == IR_MUL || op == IR_SDIV || op == IR_UDIV || op == IR_MULHS || op == IR_FMUL || op == IR_FDIV || op == IR_FSQRT;
}

// is the register r still holding the value v?
bool vn_holds(int r, int v) {
    return r >= 1 && r < ir_nv && vr_st[r] == vr_cur && vr_vn[r] == v;
}

// what is known about a value on the way into the block (from the branches that led here): value, condition, number, 1 = the condition holds
int vf_vn[16];
int vf_cc[16];
int vf_imm[16];
int vf_t[16];
int vf_n;
int vn_folded;                  // branches that were decided

// does the branch  cc v, imm  go the true way (1), the false way (0), or is it not known (-1)?
int vf_decide(int cc, int v, int imm) {
    if v < 0 { return 0 - 1; }
    if vn_k[v] == 1001 { if tj_holds(cc, vn_x[v], imm) { return 1; } return 0; }
    int f = 0;
    while f < vf_n {
        if vf_vn[f] == v {
            bool known_eq = (vf_cc[f] == IR_EQ && vf_t[f] == 1) || (vf_cc[f] == IR_NE && vf_t[f] == 0);
            bool known_ne = (vf_cc[f] == IR_NE && vf_t[f] == 1) || (vf_cc[f] == IR_EQ && vf_t[f] == 0);
            if known_eq {
                if tj_holds(cc, vf_imm[f], imm) { return 1; }
                return 0;
            }
            if known_ne && vf_imm[f] == imm {
                if cc == IR_EQ { return 0; }
                if cc == IR_NE { return 1; }
            }
        }
        f += 1;
    }
    return 0 - 1;
}

// cont = 1: the block is entered from the block processed before it only, so what is known stays
void vn_block(int b, int cont) {
    if cont == 0 {
        vn_n = 0;
        vn_hcur += 1;
        vr_cur += 1;
        vf_n = 0;
    }
    int i = ir_bs[b];
    while i < ir_be[b] {
        int op = ir_op[i];
        int d = ir_d[i];
        vn_ins[i] = 0;
        if (op == IR_LOAD || op == IR_STORE) && ir_a[i] != 30 && ir_a[i] >= 1 && vn_n < VN_MAX - 8 {
            int va3 = vn_reg(ir_a[i]);
            if va3 >= 0 && vn_ab[va3] >= 0 {
                int hb = vn_holder[vn_ab[va3]];
                int w = ir_w[i];
                if w < 0 { w = 0 - w; }
                int nk = ir_k[i] + vn_ao[va3];
                if hb >= 1 && vn_holds(hb, vn_ab[va3]) && ir_vcls[hb] == 0 && w > 0 && nk >= 0 && nk <= 32760 && nk % w == 0 {
                    ir_a[i] = hb;
                    ir_k[i] = nk;
                    vn_changes += 1;
                }
            }
        }
        int V = 0 - 1;
        bool valuable = false;
        if d != 0 && vn_n < VN_MAX - 8 {
            if op == IR_CONST {
                valuable = true;
                V = vn_find(1001, ir_k[i], 0, 0);
                if V < 0 { V = vn_new(1001, ir_k[i], 0, 0); vn_enter(V); }
            } else if op == IR_LOAD {
                int sl = vn_slot(i);
                if sl >= 0 {
                    valuable = true;
                    if vn_ver_st[sl] != vn_hcur { vn_ver_st[sl] = vn_hcur; vn_ver[sl] = 0; vn_cellvn[sl] = 0 - 1; }
                    V = vn_find(1002, sl, vn_ver[sl], 0);
                    if V < 0 { V = vn_new(1002, sl, vn_ver[sl], 0); vn_enter(V); }
                    if V >= 0 && vn_al[V] >= 0 { V = vn_al[V]; }
                }
            } else if op == IR_COPY {
                int va = vn_reg(ir_a[i]);
                if va >= 0 { vn_set(d, va); i += 1; continue; }
            } else if op_pure(op) && op != IR_NOP && op != IR_CONST && op != IR_COPY {
                int va2 = vn_reg(ir_a[i]);
                int vb2 = 0;
                int kk = ir_k[i];
                if ir_uses_b(op) {
                    if ir_bi[i] == 1 { vb2 = ir_b[i] + 1000000; } else { vb2 = vn_reg(ir_b[i]); }
                }
                if va2 >= 0 && vb2 >= 0 {
                    valuable = true;
                    int xa = va2;
                    int xb = vb2;
                    if vn_commutes(op) && ir_bi[i] == 0 && xb < xa { xa = vb2; xb = va2; }
                    int ky = op;
                    if op == IR_BITS2F && vn_inv[va2] > 0 { V = vn_inv[va2]; }
                    else if op == IR_F2BITS && vn_inv[va2] > 0 { V = vn_inv[va2]; }
                    else {
                        V = vn_find(ky, xa, xb, kk * 4 + ir_w[i] * 1);
                        if V < 0 {
                            V = vn_new(ky, xa, xb, kk * 4 + ir_w[i] * 1);
                            if V >= 0 {
                                vn_enter(V);
                                vn_def[V] = i;
                                int hv = 0;
                                if vn_is_heavy_op(op) { hv = 1; }
                                if vn_heavy[va2] == 1 { hv = 1; }
                                if vb2 < 1000000 && vn_heavy[vb2] == 1 { hv = 1; }
                                vn_heavy[V] = hv;
                                if op == IR_F2BITS || op == IR_BITS2F { vn_inv[V] = va2; }
                                if op == IR_ADD && ir_bi[i] == 1 { vn_ab[V] = va2; vn_ao[V] = ir_b[i]; }
                            }
                        }
                    }
                }
            }
            if valuable && V >= 0 {
                // a register that holds the value already: a copy
                bool done = false;
                int h = vn_holder[V];
                if op != IR_LOAD && (op != IR_CONST || (ir_k[i] != 0 && op_costly(ir_k[i]))) && h >= 1 && vn_holds(h, V) && ir_vcls[h] == ir_vcls[d] && vn_def[V] != i {
                    if h == d {
                        ir_op[i] = IR_NOP;
                        ir_d[i] = 0;
                        ir_a[i] = 0;
                        ir_bi[i] = 1;
                    } else {
                        ir_op[i] = IR_COPY;
                        ir_a[i] = h;
                        ir_bi[i] = 0;
                    }
                    vn_changes += 1;
                    done = true;
                } else if op != IR_CONST && op != IR_LOAD && vn_heavy[V] == 1 && vn_def[V] >= 0 && vn_def[V] != i && ir_op[vn_def[V]] == op {
                    // the value was made earlier and no register holds it now: it is read from a cell that the first computation wrote
                    if vn_cell[V] == 0 {
                        vn_q += 8;
                        vn_cell[V] = 0 - vn_q;
                        vn_ins[vn_def[V]] = vn_cell[V];
                    }
                    vn_cellhits += 1;
                    ir_op[i] = IR_LOAD;
                    ir_a[i] = 30;
                    ir_k[i] = vn_cell[V];
                    ir_w[i] = 8;
                    ir_bi[i] = 0;
                    vn_changes += 1;
                    done = true;
                }
                vn_set(d, V);
                i += 1;
                continue;
            }
        }
        // a branch on a number: decided when the way in tells the answer
        if op == IR_BR && ir_bi[i] == 1 && vn_n < VN_MAX - 8 {
            int vq = vn_reg(ir_a[i]);
            int dec = vf_decide(ir_k[i], vq, ir_b[i]);
            if dec >= 0 && (ir_opt & 2048) == 0 {
                int tgt = ir_t2[i];
                if dec == 1 { tgt = ir_t1[i]; }
                ir_op[i] = IR_JMP;
                ir_t1[i] = tgt;
                ir_t2[i] = 0 - 1;
                ir_a[i] = 0;
                vn_folded += 1;
                vn_changes += 1;
            }
        }
        // anything else
        if op == IR_STORE {
            int sl2 = vn_slot(i);
            if sl2 >= 0 {
                if vn_ver_st[sl2] != vn_hcur { vn_ver_st[sl2] = vn_hcur; vn_ver[sl2] = 0; }
                vn_ver[sl2] += 1;
                int vb = vn_reg(ir_b[i]);
                if vb >= 0 {
                    // a load of the new version of the slot gives the stored value
                    int nv = vn_new(1002, sl2, vn_ver[sl2], 0);
                    if nv >= 0 {
                        vn_enter(nv);
                        vn_al[nv] = vb;
                    }
                }
            }
        }
        if d != 0 {
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                vr_cur += 1;
            }
            int vo = vn_new(1003, d, i, 0);
            vn_set(d, vo);
        } else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            vr_cur += 1;
        }
        i += 1;
    }
}

// the block b written again (at the end of the arrays) with the stores after the instructions that made values read from cells
bool vn_emit(int b) {
    bool any = false;
    int i = ir_bs[b];
    while i < ir_be[b] {
        if vn_ins[i] < 0 { any = true; }
        i += 1;
    }
    if !any { return true; }
    int cnt = ir_be[b] - ir_bs[b];
    int extra = 0;
    i = ir_bs[b];
    while i < ir_be[b] {
        if vn_ins[i] < 0 { extra += 1; }
        i += 1;
    }
    if ir_n + cnt + extra + 2 >= IR_MAXI || ir_nv + 4 >= IR_MAXV { return false; }
    int ns = ir_n;
    i = ir_bs[b];
    int e0 = ir_be[b];
    while i < e0 {
        int j = ir_n;
        ir_op[j] = ir_op[i];
        ir_d[j] = ir_d[i];
        ir_a[j] = ir_a[i];
        ir_b[j] = ir_b[i];
        ir_bi[j] = ir_bi[i];
        ir_k[j] = ir_k[i];
        ir_w[j] = ir_w[i];
        ir_t1[j] = ir_t1[i];
        ir_t2[j] = ir_t2[i];
        ir_as[j] = ir_as[i];
        ir_ac[j] = ir_ac[i];
        ir_n += 1;
        if vn_ins[i] < 0 {
            int st = ir_n;
            ir_op[st] = IR_STORE;
            ir_d[st] = 0;
            ir_a[st] = 30;
            ir_b[st] = ir_d[i];
            ir_bi[st] = 0;
            ir_k[st] = vn_ins[i];
            ir_w[st] = 8;
            ir_t1[st] = 0 - 1;
            ir_t2[st] = 0 - 1;
            ir_as[st] = 0;
            ir_ac[st] = 0;
            ir_n += 1;
        }
        i += 1;
    }
    ir_bs[b] = ns;
    ir_be[b] = ir_n;
    return true;
}

int vn_done[IR_MAXB];
int vn_pc[IR_MAXB];             // the number of predecessors (that the flow can reach)

void op_cse_run() {
    op_graph();
    vn_hints();
    vn_q = op_maxq();
    int b = 0;
    int nb0 = ir_nb;
    while b < nb0 {
        vn_done[b] = 0;
        vn_pc[b] = 0;
        b += 1;
    }
    b = 0;
    while b < nb0 {
        if op_po[b] >= 0 {
            int k = 0;
            while k < 2 {
                int sc = op_succ(b, k);
                if sc >= 0 && !(k == 1 && op_succ(b, 0) == sc) { vn_pc[sc] += 1; }
                k += 1;
            }
        }
        b += 1;
    }
    // the blocks in reverse post order; after a block comes the successor that only it leads to (what is known stays)
    int ri = 0;
    while ri < op_nrpo {
        int start = op_rpo[ri];
        ri += 1;
        if vn_done[start] == 0 && start < nb0 {
            int cur = start;
            int cont = 0;
            while cur >= 0 {
                vn_done[cur] = 1;
                vn_block(cur, cont);
                // the way on: the false side of a branch first (the fall through), else the true side, else the target of a jump
                int term = ir_be[cur] - 1;
                int nxt = 0 - 1;
                int tk = ir_op[term];
                int cand1 = 0 - 1;
                int cand2 = 0 - 1;
                if tk == IR_JMP { cand1 = ir_t1[term]; }
                if tk == IR_BR || tk == IR_FBR { cand1 = ir_t2[term]; cand2 = ir_t1[term]; }
                int which = 0;
                if cand1 >= 0 && cand1 < nb0 && vn_pc[cand1] == 1 && vn_done[cand1] == 0 && cand1 != cur { nxt = cand1; which = 2; }
                else if cand2 >= 0 && cand2 < nb0 && vn_pc[cand2] == 1 && vn_done[cand2] == 0 && cand2 != cur && cand1 != cand2 { nxt = cand2; which = 1; }
                if (ir_opt & 256) != 0 { nxt = 0 - 1; }
                if nxt >= 0 && tk == IR_BR && ir_bi[term] == 1 {
                    // what the branch tells about its value on the way to nxt
                    int vq = vn_reg(ir_a[term]);
                    if vq >= 0 && vf_n < 16 {
                        vf_vn[vf_n] = vq;
                        vf_cc[vf_n] = ir_k[term];
                        vf_imm[vf_n] = ir_b[term];
                        vf_t[vf_n] = 0;
                        if which == 1 { vf_t[vf_n] = 1; }
                        vf_n += 1;
                    }
                }
                if tk == IR_JMP && nxt < 0 { }
                cur = nxt;
                cont = 1;
            }
        }
    }
    b = 0;
    while b < nb0 {
        if op_po[b] >= 0 { vn_emit(b); }
        b += 1;
    }
}

// the number of instructions that do something, in the blocks the flow can reach (to see whether the passes made the function smaller)
int op_count() {
    op_graph();
    int n = 0;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] != IR_NOP && !(ir_op[i] == IR_COPY && ir_d[i] == ir_a[i]) && ir_op[i] != IR_PARAM { n += 1; }
                i += 1;
            }
        }
        b += 1;
    }
    return n;
}

// ---------------------------------------------------------------------------------------------- double -> whole number -> double round trips
// "fmov x1, d0 / (code that writes d0) / fmov d1, x1" (the value of a compound assignment waits in a whole number register) becomes a copy
// into a double register that the block does not use: "fmov d20, d0 / ... / fmov d1, d20". A move between a double and a whole number
// register takes several cycles on the phone, a move between double registers one.
bool bt_mentions(int b, int r) {
    int i = ir_bs[b];
    while i < ir_be[b] {
        if ir_d[i] == r || ir_a[i] == r || (ir_uses_b(ir_op[i]) && ir_bi[i] == 0 && ir_b[i] == r) { return true; }
        if ir_op[i] == IR_CALL || ir_op[i] == IR_CALLIND || ir_op[i] == IR_SYSCALL {
            int g = 0;
            while g < ir_ac[i] {
                if ir_args[ir_as[i] + g] == r { return true; }
                g += 1;
            }
        }
        i += 1;
    }
    return false;
}

int bt_changes;

// the only instruction after `from` in the block b that reads the register x before x is written again (-1: none, more than one, or x lives on)
int bt_reader(int b, int from, int x) {
    int j = from;
    int found = 0 - 1;
    int count = 0;
    while j < ir_be[b] {
        bool reads = ir_a[j] == x || (ir_uses_b(ir_op[j]) && ir_bi[j] == 0 && ir_b[j] == x);
        bool call = ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL;
        if call {
            int g = 0;
            while g < ir_ac[j] {
                if ir_args[ir_as[j] + g] == x { reads = true; }
                g += 1;
            }
        }
        if reads {
            count += 1;
            if found < 0 { found = j; }
        }
        if call || ir_d[j] == x {
            if count == 1 { return found; }
            return 0 - 1;
        }
        j += 1;
    }
    if count == 1 && (op_lo[b] & (1 << x)) == 0 { return found; }
    return 0 - 1;
}

void op_bits_block(int b) {
    int i = ir_bs[b];
    while i < ir_be[b] {
        if ir_op[i] == IR_F2BITS && ir_d[i] >= 1 && ir_d[i] <= 31 && ir_vcls[ir_a[i]] == 1 {
            int x = ir_d[i];
            int src = ir_a[i];
            int j1 = bt_reader(b, i + 1, x);
            int use = 0 - 1;
            int mid = 0 - 1;
            if j1 >= 0 && ir_op[j1] == IR_BITS2F { use = j1; }
            else if j1 >= 0 && ir_op[j1] == IR_COPY && ir_a[j1] == x && ir_d[j1] >= 1 && ir_d[j1] <= 31 {
                int j2 = bt_reader(b, j1 + 1, ir_d[j1]);
                if j2 >= 0 && ir_op[j2] == IR_BITS2F { use = j2; mid = j1; }
            }
            if use >= 0 {
                // is the source written between the two? then a copy is needed, else nothing to do
                bool written = false;
                int m = i + 1;
                while m < use {
                    if ir_d[m] == src || ir_op[m] == IR_CALL || ir_op[m] == IR_CALLIND { written = true; }
                    m += 1;
                }
                if written {
                    int r = 48;
                    int pick = 0;
                    while r <= 61 && pick == 0 {
                        if r != 59 && (op_li[b] & (1 << r)) == 0 && (op_lo[b] & (1 << r)) == 0 && !bt_mentions(b, r) { pick = r; }
                        r += 1;
                    }
                    if pick != 0 {
                        ir_op[i] = IR_COPY;
                        ir_d[i] = pick;
                        ir_a[i] = src;
                        if mid >= 0 {
                            ir_op[mid] = IR_NOP;
                            ir_d[mid] = 0;
                            ir_a[mid] = 0;
                            ir_bi[mid] = 1;
                        }
                        ir_op[use] = IR_COPY;
                        ir_a[use] = pick;
                        bt_changes += 1;
                    }
                }
            }
        }
        i += 1;
    }
}

void op_bits_run() {
    if (ir_opt & 4) == 0 { op_webs(); }       // liveness (op_li, op_lo); the cleaning pass has made it already (a little too much live: safe)
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 { op_bits_block(b); }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- the frame of a function (the last text pass)
// sub sp, sp, #N / str x29, [sp, #0] / str x30, [sp, #8] / add x29, sp, #0     ->   stp x29, x30, [sp, #-N]! / add x29, sp, #0
// ldr x29, [sp, #0] / ldr x30, [sp, #8] / add sp, sp, #N                     ->   ldp x29, x30, [sp], #N
int fr_on = 0;                  // off: stp/ldp pre- and post-index were 9 % SLOWER than sub/str/str on the Cortex-A55 (fib), measured 0.9.71

int fr_number(int p) {
    int n = 0;
    while out_buf[p] >= '0' && out_buf[p] <= '9' {
        n = n * 10 + (out_buf[p] - '0');
        p += 1;
    }
    return n;
}

void fr_run() {
    regs_len = 0;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_has(i, "sub sp, sp, #") {
            int n = fr_number(i + 13);
            int l2 = en + 1;
            int l3 = 0 - 1;
            int l4 = 0 - 1;
            if l2 < out_len && rg_has(l2, "str x29, [sp, #0]\n") { l3 = rg_end(l2) + 1; }
            if l3 > 0 && l3 < out_len && rg_has(l3, "str x30, [sp, #8]\n") { l4 = rg_end(l3) + 1; }
            if l4 > 0 && l4 < out_len && rg_has(l4, "add x29, sp, #0\n") && n >= 16 && n <= 512 && n % 8 == 0 {
                rg_text("stp x29, x30, [sp, #-");
                rg_int(n);
                rg_text("]!\nadd x29, sp, #0\n");
                i = rg_end(l4) + 1;
                continue;
            }
        }
        if rg_has(i, "ldr x29, [sp, #0]\n") {
            int l2 = en + 1;
            int l3 = 0 - 1;
            if l2 < out_len && rg_has(l2, "ldr x30, [sp, #8]\n") { l3 = rg_end(l2) + 1; }
            if l3 > 0 && l3 < out_len && rg_has(l3, "add sp, sp, #") {
                int n = fr_number(l3 + 13);
                if n >= 16 && n <= 504 && n % 8 == 0 {
                    rg_text("ldp x29, x30, [sp], #");
                    rg_int(n);
                    rg_put(10);
                    i = rg_end(l3) + 1;
                    continue;
                }
            }
        }
        rg_copy(i, en);
        i = en + 1;
    }
    int t = 0;
    while t < regs_len {
        out_buf[t] = regs_buf[t];
        t += 1;
    }
    out_len = regs_len;
}

// ---------------------------------------------------------------------------------------------- jump threading
// A block that holds only "br cc xR, #N" and is jumped to from a block that has just set xR to a constant: the jump goes straight to the
// right target (the boolean that && and || make with  mov x0, 1 / mov x0, 0  and test again). The constant stays where it is; dead code removes it.
bool tj_holds(int cc, int a, int b) {
    if cc == IR_EQ { return a == b; }
    if cc == IR_NE { return a != b; }
    if cc == IR_LT { return a < b; }
    if cc == IR_LE { return a <= b; }
    if cc == IR_GT { return a > b; }
    if cc == IR_GE { return a >= b; }
    // unsigned: compare after flipping the sign bit
    int sign = 1 << 63;
    int ua = a + sign;
    int ub = b + sign;
    if cc == IR_ULT { return ua < ub; }
    if cc == IR_ULE { return ua <= ub; }
    if cc == IR_UGT { return ua > ub; }
    return ua >= ub;
}

// the target an edge from the block b to the block t can be threaded to, or -1
int tj_target(int b, int t, int upto) {
    if t == b { return 0 - 1; }
    // the first instruction that does something; it must be the last of the block
    int br = ir_bs[t];
    while br < ir_be[t] - 1 && ir_op[br] == IR_NOP { br += 1; }
    if br != ir_be[t] - 1 { return 0 - 1; }
    if ir_op[br] == IR_JMP {
        if ir_t1[br] == t { return 0 - 1; }
        return ir_t1[br];
    }
    if ir_op[br] != IR_BR || ir_bi[br] != 1 || ir_a[br] < 1 || ir_a[br] > 31 { return 0 - 1; }
    int r = ir_a[br];
    // the last definition of r in b before the terminator
    int i = upto - 1;
    while i >= ir_bs[b] {
        if ir_d[i] == r {
            if ir_op[i] != IR_CONST { return 0 - 1; }
            if tj_holds(ir_k[br], ir_k[i], ir_b[br]) { return ir_t1[br]; }
            return ir_t2[br];
        }
        if ir_op[i] == IR_CALL || ir_op[i] == IR_CALLIND || ir_op[i] == IR_SYSCALL { return 0 - 1; }
        i -= 1;
    }
    return 0 - 1;
}

int tj_changes;

void op_thread() {
    int pass = 0;
    while pass < 3 {
        int before = tj_changes;
        int b = 0;
        int nb0 = ir_nb;
        while b < nb0 {
            int t = ir_be[b] - 1;
            int op = ir_op[t];
            if op == IR_JMP || op == IR_BR || op == IR_FBR {
                int n1 = tj_target(b, ir_t1[t], t);
                if n1 >= 0 { ir_t1[t] = n1; tj_changes += 1; }
                if op != IR_JMP {
                    int n2 = tj_target(b, ir_t2[t], t);
                    if n2 >= 0 { ir_t2[t] = n2; tj_changes += 1; }
                }
            }
            b += 1;
        }
        if tj_changes == before { return; }
        pass += 1;
    }
}

// ---------------------------------------------------------------------------------------------- small copies of structs in place
// bl j2k_copy (x0 = from, x3 = to, x2 = the size in bytes, a multiple of 8) with a size that is known and at most 128: loads and stores
// instead of a call (a struct of three doubles is three pairs, not a call with a loop).
int ci_changes;

// the size in bytes of the copy made by the call i, or -1 if it is not a small copy of known size
int ci_size(int b, int i) {
    if ir_op[i] != IR_CALL { return 0 - 1; }
    if !str_eq(@ir_name + ir_k[i] * 64, "j2k_copy") { return 0 - 1; }
    int j = i - 1;
    while j >= ir_bs[b] {
        if ir_d[j] == 3 {
            if ir_op[j] == IR_CONST && ir_k[j] > 0 && ir_k[j] <= 128 && ir_k[j] % 8 == 0 { return ir_k[j]; }
            return 0 - 1;
        }
        if ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL { return 0 - 1; }
        j -= 1;
    }
    return 0 - 1;
}

void op_copy_inline() {
    op_graph();
    int nb0 = ir_nb;
    int b = 0;
    while b < nb0 {
        if op_po[b] >= 0 {
            int need = 0;
            int i = ir_bs[b];
            while i < ir_be[b] {
                int sz = ci_size(b, i);
                if sz > 0 { need += sz / 4; }
                i += 1;
            }
            if need > 0 && ir_n + (ir_be[b] - ir_bs[b]) + need + 4 < IR_MAXI && ir_nv + need < IR_MAXV - 8 {
                int ns = ir_n;
                int e0 = ir_be[b];
                i = ir_bs[b];
                while i < e0 {
                    int sz2 = ci_size(b, i);
                    if sz2 > 0 {
                        int off = 0;
                        while off < sz2 {
                            int t = ir_vreg(0);
                            int l = ir_n;
                            ir_op[l] = IR_LOAD; ir_d[l] = t; ir_a[l] = 1; ir_b[l] = 0; ir_bi[l] = 0; ir_k[l] = off; ir_w[l] = 8;
                            ir_t1[l] = 0 - 1; ir_t2[l] = 0 - 1; ir_as[l] = 0; ir_ac[l] = 0;
                            int s = l + 1;
                            ir_op[s] = IR_STORE; ir_d[s] = 0; ir_a[s] = 4; ir_b[s] = t; ir_bi[s] = 0; ir_k[s] = off; ir_w[s] = 8;
                            ir_t1[s] = 0 - 1; ir_t2[s] = 0 - 1; ir_as[s] = 0; ir_ac[s] = 0;
                            ir_n += 2;
                            off += 8;
                        }
                        ci_changes += 1;
                    } else {
                        int j2 = ir_n;
                        ir_op[j2] = ir_op[i]; ir_d[j2] = ir_d[i]; ir_a[j2] = ir_a[i]; ir_b[j2] = ir_b[i]; ir_bi[j2] = ir_bi[i]; ir_k[j2] = ir_k[i]; ir_w[j2] = ir_w[i];
                        ir_t1[j2] = ir_t1[i]; ir_t2[j2] = ir_t2[i]; ir_as[j2] = ir_as[i]; ir_ac[j2] = ir_ac[i];
                        ir_n += 1;
                    }
                    i += 1;
                }
                ir_bs[b] = ns;
                ir_be[b] = ir_n;
            }
        }
        b += 1;
    }
}
