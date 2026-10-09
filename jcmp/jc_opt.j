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
