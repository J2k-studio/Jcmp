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
// the live-in and live-out registers of the blocks only (op_li, op_lo), without the webs
int lv_use[IR_MAXB];
void op_liveness() {
    op_graph();
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
        lv_use[b] = u;
        ldef[b] = d;
        op_li[b] = u;
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
            int nin = lv_use[blk] | (out & ~ldef[blk]);
            if nin != op_li[blk] || out != op_lo[blk] {
                op_li[blk] = nin;
                op_lo[blk] = out;
                changed = true;
            }
            ri -= 1;
        }
    }
}

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

int cp_done[IR_MAXB];
int cp_pc[IR_MAXB];

void op_prop_block(int b, int cont) {
    if cont == 0 {
        cp_cur += 1;
        cp_nact = 0;
    }
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
                    if op == IR_ROTR32 { ok = cp_small(k, 31); }
                    if (op == IR_AND || op == IR_OR || op == IR_XOR) && as_logic_imm(k) >= 0 { ok = true; }
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
        // an operation with the number that changes nothing is a copy (`x + 0`, `x << 0`, `x * 1`, `x & -1`)
        if !fixed && ir_bi[i] == 1 && ir_d[i] > 0 && ir_a[i] > 0 && ir_vcls[ir_d[i]] == 0 && ir_vcls[ir_a[i]] == 0 {
            bool same = false;
            if (op == IR_ADD || op == IR_SUB || op == IR_OR || op == IR_XOR || op == IR_SHL || op == IR_LSHR || op == IR_ASHR) && ir_b[i] == 0 { same = true; }
            if op == IR_MUL && ir_b[i] == 1 { same = true; }
            if op == IR_AND && ir_b[i] == 0 - 1 { same = true; }
            if same {
                ir_op[i] = IR_COPY;
                ir_b[i] = 0;
                ir_bi[i] = 0;
                ir_k[i] = 0;
                op = IR_COPY;
                op_clean_changes += 1;
            }
        }
        // an operation on two known numbers is a number
        if !fixed && op >= IR_ADD && op <= IR_ASHR && op != IR_SDIV && op != IR_UDIV && ir_d[i] != 0 && ir_vcls[ir_d[i]] == 0 && ir_a[i] != 0 && cp_get(ir_a[i]) == 1 && ir_vcls[ir_a[i]] == 0 {
            bool haveb = false;
            int kb = 0;
            if ir_bi[i] == 1 { kb = ir_b[i]; haveb = true; }
            else if cp_get(ir_b[i]) == 1 && ir_vcls[ir_b[i]] == 0 { kb = cp_val[ir_b[i]]; haveb = true; }
            if haveb {
                int ka = cp_val[ir_a[i]];
                int r = 0;
                bool okf = true;
                if op == IR_ADD { r = ka + kb; }
                else if op == IR_SUB { r = ka - kb; }
                else if op == IR_MUL { r = ka * kb; }
                else if op == IR_AND { r = ka & kb; }
                else if op == IR_OR { r = ka | kb; }
                else if op == IR_XOR { r = ka xor kb; }
                else if op == IR_SHL && kb >= 0 && kb <= 63 { r = ka << kb; }
                else if op == IR_ASHR && kb >= 0 && kb <= 63 { r = ka >> kb; }
                else if op == IR_LSHR && kb >= 0 && kb <= 63 {
                    r = ka;
                    if kb > 0 { r = (ka >> kb) & ((1 << (64 - kb)) - 1); }
                } else { okf = false; }
                if okf {
                    ir_op[i] = IR_CONST;
                    ir_k[i] = r;
                    ir_a[i] = 0;
                    ir_bi[i] = 1;
                    op = IR_CONST;
                    op_clean_changes += 1;
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
        || (op >= IR_FADD && op <= IR_FSETCC) || op == IR_ADDR_GLOBAL || op == IR_ADDR_FUNC || op == IR_FCONST || (op >= IR_CLZ && op <= IR_POPCNT) || op == IR_FTRUNC || op == IR_FCEIL || (op >= IR_F32IN && op <= IR_F32TOI);
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
        int nb0 = ir_nb;
        while b < nb0 {
            cp_done[b] = 0;
            cp_pc[b] = 0;
            b += 1;
        }
        b = 0;
        while b < nb0 {
            if op_po[b] >= 0 {
                int k = 0;
                while k < 2 {
                    int sc = op_succ(b, k);
                    if sc >= 0 && !(k == 1 && op_succ(b, 0) == sc) { cp_pc[sc] += 1; }
                    k += 1;
                }
            }
            b += 1;
        }
        // a block that only one block leads to goes on with what is known at the end of that block (the body of an inlined function
        // follows the arguments this way)
        int ri = 0;
        while ri < op_nrpo {
            int start = op_rpo[ri];
            ri += 1;
            if cp_done[start] == 0 && start < nb0 {
                int cur = start;
                int cont = 0;
                while cur >= 0 {
                    cp_done[cur] = 1;
                    op_prop_block(cur, cont);
                    int term = ir_be[cur] - 1;
                    int nxt = 0 - 1;
                    int tk = ir_op[term];
                    int cand1 = 0 - 1;
                    int cand2 = 0 - 1;
                    if tk == IR_JMP { cand1 = ir_t1[term]; }
                    if tk == IR_BR || tk == IR_FBR { cand1 = ir_t2[term]; cand2 = ir_t1[term]; }
                    if cand1 >= 0 && cand1 < nb0 && cp_pc[cand1] == 1 && cp_done[cand1] == 0 && cand1 != cur { nxt = cand1; }
                    else if cand2 >= 0 && cand2 < nb0 && cp_pc[cand2] == 1 && cp_done[cand2] == 0 && cand2 != cur && cand1 != cand2 { nxt = cand2; }
                    cur = nxt;
                    cont = 1;
                }
            }
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
int vn_mem;                     // the memory epoch: every store and every call makes a new one (a load of a global array is the same value inside one epoch)
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
// does the value v come from the value g (the base of the globals) through additions and shifts?
bool vn_from(int v, int g, int depth) {
    if v == g { return true; }
    if depth <= 0 || v < 0 { return false; }
    int k = vn_k[v];
    if k >= IR_ADD && k <= IR_ASHR && k != IR_SDIV && k != IR_UDIV && k != IR_MUL {
        if vn_from(vn_x[v], g, depth - 1) { return true; }
        if vn_y[v] < 1000000 && vn_y[v] >= 0 && vn_from(vn_y[v], g, depth - 1) { return true; }
    }
    return false;
}

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
        bool fwd = false;
        bool memload = false;
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
                    if V >= 0 && vn_al[V] >= 0 { V = vn_al[V]; fwd = true; }
                } else if ir_a[i] != 30 && ir_a[i] >= 1 && (ir_opt & 4194304) == 0 && ir_vcls[d] == 0 {
                    // a load from an element of a global array: the same address in the same epoch is the same value
                    int vg = vn_reg(29);
                    int vad = vn_reg(ir_a[i]);
                    if vg >= 0 && vad >= 0 && vn_from(vad, vg, 6) {
                        valuable = true;
                        memload = true;
                        int wq = ir_w[i] + 16;
                        V = vn_find(1004, vad, ir_k[i], vn_mem * 64 + wq);
                        if V < 0 {
                            V = vn_new(1004, vad, ir_k[i], vn_mem * 64 + wq);
                            if V >= 0 {
                                vn_enter(V);
                                vn_def[V] = i;
                                vn_heavy[V] = 2;          // read again from a cell that the first load writes (the register pass keeps the cell in a register)
                            }
                        }
                    }
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
                if (op != IR_LOAD || (fwd && (ir_opt & 1048576) == 0) || memload) && (op != IR_CONST || (ir_k[i] != 0 && op_costly(ir_k[i]))) && h >= 1 && vn_holds(h, V) && ir_vcls[h] == ir_vcls[d] && vn_def[V] != i {
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
                } else if op == IR_LOAD && fwd && (ir_opt & 1048576) == 0 && ir_vcls[d] == 0 && vn_k[V] == 1001 && !op_costly(vn_x[V]) {
                    // the cell holds a small number that no register holds now: make it again (the store may then be dead)
                    ir_op[i] = IR_CONST;
                    ir_k[i] = vn_x[V];
                    ir_a[i] = 0;
                    ir_bi[i] = 1;
                    vn_changes += 1;
                    done = true;
                } else if op == IR_LOAD && fwd && (ir_opt & 1048576) == 0 && ir_vcls[d] == 0 && vn_k[V] == IR_ADD && vn_y[V] >= 1000000 && vn_y[V] < 1000000 + 4096 && vn_z[V] % 4 == 0 && vn_x[V] == vn_reg(30) && vn_reg(30) >= 0 {
                    // the cell holds the address of a frame object (the frame pointer plus a number): make it again
                    ir_op[i] = IR_ADD;
                    ir_a[i] = 30;
                    ir_b[i] = vn_y[V] - 1000000;
                    ir_bi[i] = 1;
                    ir_k[i] = 0;
                    vn_changes += 1;
                    done = true;
                } else if op != IR_CONST && (op != IR_LOAD || memload) && vn_heavy[V] >= 1 && vn_def[V] >= 0 && vn_def[V] != i && ir_op[vn_def[V]] == op {
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
        // a second operand that is a known small number is an immediate (the text pass would take "mov x1, N" into "cmp x0, N" without
        // asking whether x1 is needed later: with an immediate there is no such pair)
        if (op == IR_BR || op == IR_ADD || op == IR_SUB || op == IR_SETCC) && ir_bi[i] == 0 && vn_n < VN_MAX - 8 && ir_vcls[ir_a[i]] == 0 {
            int vb5 = vn_reg(ir_b[i]);
            if vb5 >= 0 && vn_k[vb5] == 1001 && vn_x[vb5] >= 0 && vn_x[vb5] <= 4095 {
                ir_bi[i] = 1;
                ir_b[i] = vn_x[vb5];
                vn_changes += 1;
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
        if op == IR_STORE || op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { vn_mem += 1; }
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

void op_walk(int kind) {
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
                if kind == 0 { vn_block(cur, cont); } else { fa_block(cur, cont); }
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
    if kind == 0 {
        b = 0;
        while b < nb0 {
            if op_po[b] >= 0 { vn_emit(b); }
            b += 1;
        }
    }
}

void op_cse_run() {
    op_walk(0);
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

// ---------------------------------------------------------------------------------------------- slots that only hold doubles
// A local `double x` lives in an 8-byte slot, and the code of the front end moves it through whole number registers:
//     fmov x0, d0 / str x0, [slot]   and   ldr x0, [slot] / fmov d1, x0
// The IR keeps that as  v1 = f2bits f ; store [slot], v1  and  v1 = load [slot] ; f = bits2f v1. When the slot becomes a register
// the moves between the two register files stay (3 - 5 cycles each, in the middle of the chain of a loop that carries x and y).
// A slot is a double slot when every store puts in the result of an f2bits (or a constant, or a load of another double slot) that
// is read by nothing but such stores and bits2f, and every load is read by nothing but such stores and bits2f. Then the loads
// and the stores work on double registers: `ldr d, [slot]`, `str d, [slot]`.
int fs_cand[8192];
int fs_changes;

int fs_slot_of(int i) {
    int s = vn_slot(i);
    if s >= 0 && s < 8192 { return s; }
    return 0 - 1;
}

// the instruction that made the value of r at pos, through copies: F2BITS, CONST or a LOAD (-1: something else)
int fs_root(int b, int pos, int r) {
    int guard = 0;
    int at = pos;
    int v = r;
    while guard < 8 {
        int j = rn_find_def(b, at, v);
        if j < 0 { return 0 - 1; }
        int op = ir_op[j];
        if op == IR_COPY {
            v = ir_a[j];
            at = j;
            guard += 1;
            continue;
        }
        if op == IR_F2BITS || op == IR_CONST || (op == IR_LOAD && ir_a[j] == 30 && ir_w[j] == 8 && ir_bi[j] == 0) { return j; }
        return 0 - 1;
    }
    return 0 - 1;
}

bool fs_uses_ok(int b, int from, int d, int depth) {
    if depth > 6 || d < 1 { return false; }
    int j = from;
    while j < ir_be[b] {
        int op = ir_op[j];
        if op == IR_NOP { j += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            int g = 0;
            while g < ir_ac[j] {
                if ir_args[ir_as[j] + g] == d { return false; }
                g += 1;
            }
            if op == IR_CALLIND && ir_a[j] == d { return false; }
            if op == IR_SYSCALL && ir_a[j] == d { return false; }
            return d <= 19;
        }
        bool reads = ir_a[j] == d || (ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] == d);
        if reads {
            if op == IR_BITS2F && ir_a[j] == d {
            } else if op == IR_COPY && ir_a[j] == d {
                int e = ir_d[j];
                if e == d {
                    // a copy onto itself changes nothing: the value goes on in the same register
                    j += 1;
                    continue;
                }
                if e < 1 || e >= 64 { return false; }
                if !fs_uses_ok(b, j + 1, e, depth + 1) { return false; }
            } else if op == IR_STORE && ir_w[j] == 8 && ir_bi[j] == 0 && ir_b[j] == d && ir_a[j] == 30 {
                int s2 = fs_slot_of(j);
                if s2 < 0 || fs_cand[s2] != 1 { return false; }
            } else {
                return false;
            }
        }
        if ir_d[j] == d && op != IR_STORE { return true; }
        j += 1;
    }
    if d < 64 { return (op_lo[b] & (1 << d)) == 0; }
    return true;
}

// a double register (d18 .. d29) that the block b does not mention and that does not live across it, and that this pass did not take
// in the block yet (bit r of taken); 0 when there is none. The scratch registers of the lowering (d30, d31) and d16, d17 are left alone.
int fs_pick(int b, int taken) {
    int r = 61;
    while r >= 50 {
        if r != 59 && (taken & (1 << r)) == 0 && (op_li[b] & (1 << r)) == 0 && (op_lo[b] & (1 << r)) == 0 && !bt_mentions(b, r) { return r; }
        r -= 1;
    }
    return 0;
}

void op_fslots() {
    if ir_nb > 2000 { return; }
    op_liveness();
    int s = 0;
    while s < 8192 { fs_cand[s] = 0; s += 1; }
    bool any = false;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] == IR_STORE && ir_a[i] == 30 {
                    int sl = fs_slot_of(i);
                    if sl >= 0 { fs_cand[sl] = 1; any = true; }
                }
                i += 1;
            }
        }
        b += 1;
    }
    if !any { return; }
    // the slots that something else than a double uses go out, until nothing changes
    bool changed = true;
    int rounds = 0;
    while changed && rounds < 12 {
        changed = false;
        rounds += 1;
        b = 0;
        while b < ir_nb {
            if op_po[b] >= 0 {
                int i = ir_bs[b];
                while i < ir_be[b] {
                    int op = ir_op[i];
                    if (op == IR_STORE || op == IR_LOAD) && ir_a[i] == 30 && ir_w[i] == 8 {
                        int sl = fs_slot_of(i);
                        if sl >= 0 && fs_cand[sl] == 1 {
                            bool ok = true;
                            if op == IR_STORE {
                                if ir_bi[i] != 0 { ok = false; }
                                else {
                                    int rt = fs_root(b, i, ir_b[i]);
                                    if rt < 0 { ok = false; }
                                    else {
                                        if ir_op[rt] == IR_LOAD {
                                            int s3 = fs_slot_of(rt);
                                            if s3 < 0 || fs_cand[s3] != 1 { ok = false; }
                                        }
                                        // every reader of the value: the register the root wrote, after the root
                                        if ok && !fs_uses_ok(b, rt + 1, ir_d[rt], 0) { ok = false; }
                                    }
                                }
                            } else {
                                if ir_vcls[ir_d[i]] != 0 || !fs_uses_ok(b, i + 1, ir_d[i], 0) { ok = false; }
                            }
                            if !ok { fs_cand[sl] = 0; changed = true; }
                        }
                    }
                    i += 1;
                }
            }
            b += 1;
        }
    }
    // the slots that stay: stores and loads work on double registers
    int map_of[64];
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int z = 0;
            while z < 64 { map_of[z] = 0; z += 1; }
            int taken = 0;
            int i = ir_bs[b];
            while i < ir_be[b] {
                int op = ir_op[i];
                if op == IR_NOP { i += 1; continue; }
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                    z = 0;
                    while z < 64 { map_of[z] = 0; z += 1; }
                    i += 1;
                    continue;
                }
                // the uses of a retyped value
                if op == IR_STORE && ir_bi[i] == 0 && ir_b[i] > 0 && ir_b[i] < 64 && map_of[ir_b[i]] != 0 && ir_a[i] == 30 {
                    ir_b[i] = map_of[ir_b[i]];
                    fs_changes += 1;
                } else if op == IR_BITS2F && ir_a[i] > 0 && ir_a[i] < 64 && map_of[ir_a[i]] != 0 {
                    ir_op[i] = IR_COPY;
                    ir_a[i] = map_of[ir_a[i]];
                    fs_changes += 1;
                    op = IR_COPY;
                } else if op == IR_COPY && ir_a[i] > 0 && ir_a[i] < 64 && map_of[ir_a[i]] != 0 && ir_d[i] > 0 && ir_d[i] < 64 {
                    int nf2 = fs_pick(b, taken);
                    int od = ir_d[i];
                    if ir_a[i] == od && nf2 == 0 { i += 1; continue; }
                    if nf2 != 0 {
                        taken = taken | (1 << nf2);
                        ir_a[i] = map_of[ir_a[i]];
                        ir_d[i] = nf2;
                        map_of[od] = nf2;
                    } else {
                        // no register for the copy: the double goes back to a whole number register
                        ir_op[i] = IR_F2BITS;
                        ir_a[i] = map_of[ir_a[i]];
                        map_of[od] = 0;
                    }
                    fs_changes += 1;
                    i += 1;
                    continue;
                }
                int d = ir_d[i];
                if d > 0 && d < 64 && op != IR_STORE && ir_vcls[d] == 0 {
                    map_of[d] = 0;
                    bool retype = false;
                    if op == IR_LOAD && ir_a[i] == 30 && ir_w[i] == 8 && ir_bi[i] == 0 {
                        int sl2 = fs_slot_of(i);
                        if sl2 >= 0 && fs_cand[sl2] == 1 { retype = true; }
                    } else if (op == IR_F2BITS || op == IR_CONST) && fs_uses_ok(b, i + 1, d, 0) {
                        // only when a store of a double slot is among the readers (else nothing is gained)
                        int j = i + 1;
                        bool feeds = false;
                        while j < ir_be[b] && !feeds {
                            if ir_op[j] == IR_STORE && ir_b[j] == d && ir_bi[j] == 0 && ir_a[j] == 30 { feeds = true; }
                            if ir_op[j] == IR_COPY && ir_a[j] == d { feeds = true; }
                            if ir_d[j] == d && ir_op[j] != IR_STORE { j = ir_be[b]; }
                            j += 1;
                        }
                        retype = feeds;
                    }
                    if retype {
                        int nf = fs_pick(b, taken);
                        if nf != 0 {
                            taken = taken | (1 << nf);
                            if op == IR_F2BITS { ir_op[i] = IR_COPY; }
                            else if op == IR_CONST { ir_op[i] = IR_FCONST; }
                            ir_d[i] = nf;
                            map_of[d] = nf;
                            fs_changes += 1;
                        }
                    }
                }
                i += 1;
            }
        }
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

// ---------------------------------------------------------------------------------------------- vectors written and read again
// A 16-byte store and a 16-byte load of the same place (the same base vreg and number) in one block, with no other store, call or
// change of the base in between: the load is a copy of the stored vector. (The store stays: another pass may find it dead.)
int vf_a[8];
int vf_k[8];
int vf_v[8];
int vf_n;
int vf_changes;

void vf_kill_reg(int r) {
    int j = 0;
    int m = 0;
    while j < vf_n {
        if vf_a[j] != r && vf_v[j] != r {
            vf_a[m] = vf_a[j];
            vf_k[m] = vf_k[j];
            vf_v[m] = vf_v[j];
            m += 1;
        }
        j += 1;
    }
    vf_n = m;
}

void op_vfwd() {
    int b = 0;
    while b < ir_nb {
        vf_n = 0;
        int i = ir_bs[b];
        while i < ir_be[b] {
            int op = ir_op[i];
            if op == IR_LOAD && ir_w[i] == 16 && ir_vcls[ir_d[i]] == 2 {
                int j = 0;
                int hit = 0 - 1;
                while j < vf_n {
                    if vf_a[j] == ir_a[i] && vf_k[j] == ir_k[i] { hit = j; }
                    j += 1;
                }
                if hit >= 0 {
                    int v = vf_v[hit];
                    int d = ir_d[i];
                    ir_op[i] = IR_COPY;
                    ir_a[i] = v;
                    ir_b[i] = 0;
                    ir_bi[i] = 0;
                    ir_k[i] = 0;
                    ir_w[i] = 0;
                    vf_changes += 1;
                    vf_kill_reg(d);
                    i += 1;
                    continue;
                }
            }
            if op == IR_STORE || op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { vf_n = 0; }
            if ir_d[i] != 0 { vf_kill_reg(ir_d[i]); }
            if op == IR_STORE && ir_w[i] == 16 && ir_vcls[ir_b[i]] == 2 && ir_a[i] != ir_b[i] && vf_n < 8 {
                vf_a[vf_n] = ir_a[i];
                vf_k[vf_n] = ir_k[i];
                vf_v[vf_n] = ir_b[i];
                vf_n += 1;
            }
            i += 1;
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- small copies of structs in place
// bl j2k_copy (x0 = from, x3 = to, x2 = the size in bytes, a multiple of 8) with a size that is known and at most 128: loads and stores
// instead of a call (a struct of three doubles is three pairs, not a call with a loop).
int ci_changes;

// the size in bytes of the copy made by the call i, or -1 if it is not a small copy of known size
int ci_size(int b, int i) {
    if ir_op[i] != IR_CALL { return 0 - 1; }
    if !str_eq(@ir_name + ir_k[i] * 64, "j2k_copy") && !str_eq(@ir_name + ir_k[i] * 64, "j2k_copy16") { return 0 - 1; }
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
                        bool as_vec = sz2 == 16 && str_eq(@ir_name + ir_k[i] * 64, "j2k_copy16");
                        if as_vec {
                            // a simd value: one 16-byte load and store
                            int tq = ir_vreg(2);
                            int lq = ir_n;
                            ir_op[lq] = IR_LOAD; ir_d[lq] = tq; ir_a[lq] = 1; ir_b[lq] = 0; ir_bi[lq] = 0; ir_k[lq] = 0; ir_w[lq] = 16;
                            ir_t1[lq] = 0 - 1; ir_t2[lq] = 0 - 1; ir_as[lq] = 0; ir_ac[lq] = 0;
                            int sq = lq + 1;
                            ir_op[sq] = IR_STORE; ir_d[sq] = 0; ir_a[sq] = 4; ir_b[sq] = tq; ir_bi[sq] = 0; ir_k[sq] = 0; ir_w[sq] = 16;
                            ir_t1[sq] = 0 - 1; ir_t2[sq] = 0 - 1; ir_as[sq] = 0; ir_ac[sq] = 0;
                            ir_n += 2;
                            off = sz2;
                        }
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

// ---------------------------------------------------------------------------------------------- inlining of small functions
// The IR of every small function that can be lifted is kept (after the passes). A call to such a function is replaced by a copy of its
// blocks: the block of the call is cut in two, the callee's frame slots and stack cells get new places in the frame of the caller,
// its temporaries get new vregs, its returns jump to the second half. The arguments are in x0..x7 at the call already (as the callee
// expects them), the result is in x0.

#define IS_MAXF 1024
#define IS_MAXI 60000
#define IS_MAXB 6000
#define IS_MAXA 60000
#define IS_MAXV 60000
#define IS_MAXN 4096

char is_fname[65536];            // 64 characters each
int is_i0[IS_MAXF];              // the first instruction in the store
int is_ni[IS_MAXF];
int is_b0[IS_MAXF];
int is_nb[IS_MAXF];
int is_a0[IS_MAXF];
int is_n0[IS_MAXF];              // its names (64 characters each in is_names)
int is_frame[IS_MAXF];
int is_h0[IS_MAXF];              // its hint line in is_hint
int is_hn[IS_MAXF];
int is_nv[IS_MAXF];              // how many vregs it uses (the classes of those from 64 are in is_vc from is_v0)
int is_v0[IS_MAXF];
int is_recursive[IS_MAXF];
int is_size[IS_MAXF];                 // instructions that do something
int is_count;
int is_ti;
int is_tb;
int is_ta;
int is_tn;
int is_th;
int is_tv;

int is_op[IS_MAXI];
int is_d[IS_MAXI];
int is_a[IS_MAXI];
int is_b[IS_MAXI];
int is_bi[IS_MAXI];
int is_k[IS_MAXI];
int is_w[IS_MAXI];
int is_t1[IS_MAXI];
int is_t2[IS_MAXI];
int is_as[IS_MAXI];
int is_ac[IS_MAXI];
int is_args[IS_MAXA];
int is_bs[IS_MAXB];
int is_be[IS_MAXB];
char is_names[262144];
char is_hint[65536];
int is_vc[IS_MAXV];

int inl_done;                    // how many calls were replaced by their bodies (all functions)
int inl_maxsize = 60;
int inl_tiny = 8;                // a callee this small is inlined everywhere, a bigger one only inside loops            // the biggest callee (instructions that do something)

int is_ht[4096];                 // the kept functions by name: the index + 1 (open addressing); is_ht_n says how many are in it
int is_ht_n;

int is_hash(char^ name) {
    int h = 5381;
    int k = 0;
    while name[k] != 0 {
        h = (h * 33 + name[k]) & 1073741823;
        k += 1;
    }
    return h & 4095;
}

int is_find(char^ name) {
    if is_ht_n != is_count {
        // the table is made again when the number of kept functions is not the one it knows (a new collection)
        int z = 0;
        while z < 4096 {
            is_ht[z] = 0;
            z += 1;
        }
        int f0 = 0;
        while f0 < is_count {
            int h0 = is_hash(@is_fname + f0 * 64);
            while is_ht[h0] != 0 { h0 = (h0 + 1) & 4095; }
            is_ht[h0] = f0 + 1;
            f0 += 1;
        }
        is_ht_n = is_count;
    }
    int h = is_hash(name);
    while is_ht[h] != 0 {
        int f = is_ht[h] - 1;
        if str_eq(@is_fname + f * 64, name) { return f; }
        h = (h + 1) & 4095;
    }
    return 0 - 1;
}

// keep the function that is in the ir_ arrays now (if it is small and fine to copy)
void is_save(char^ name) {
    if is_count >= IS_MAXF { return; }
    if str_len(name) >= 63 { return; }
    int cnt = op_count();
    if cnt > inl_maxsize || ir_nb > 40 { return; }
    int total_b = ir_nb;
    int total_i = 0;
    int b = 0;
    while b < ir_nb {
        total_i += ir_be[b] - ir_bs[b];
        b += 1;
    }
    if is_ti + total_i >= IS_MAXI || is_tb + total_b >= IS_MAXB || is_ta + ir_nargs >= IS_MAXA || is_tn + ir_nnames >= IS_MAXN || is_th + lf_hint_n >= 65000 || is_tv + ir_nv >= IS_MAXV { return; }
    // no indirect calls, no system calls in the middle, and it must not call itself
    int rec = 0;
    b = 0;
    while b < ir_nb {
        int i = ir_bs[b];
        while i < ir_be[b] {
            if ir_op[i] == IR_CALLIND { return; }
            // the frame pointer may only be the base of a load / store, or the first operand of an add of a number (the slots are moved when the function is inlined)
            int o5 = ir_op[i];
            if o5 == IR_CALL || o5 == IR_SYSCALL {
                int g5 = 0;
                while g5 < ir_ac[i] {
                    if ir_args[ir_as[i] + g5] == 30 { return; }
                    g5 += 1;
                }
            }
            if ir_a[i] == 30 && !((o5 == IR_LOAD || o5 == IR_STORE) || (o5 == IR_ADD && ir_bi[i] == 1)) { return; }
            if ir_uses_b(o5) && ir_bi[i] == 0 && ir_b[i] == 30 { return; }
            if ir_op[i] == IR_CALL && str_eq(@ir_name + ir_k[i] * 64, name) { rec = 1; }
            i += 1;
        }
        b += 1;
    }
    int f = is_count;
    str_copy(@is_fname + f * 64, name, 64);
    is_i0[f] = is_ti;
    is_b0[f] = is_tb;
    is_a0[f] = is_ta;
    is_n0[f] = is_tn;
    is_h0[f] = is_th;
    is_v0[f] = is_tv;
    is_nb[f] = ir_nb;
    is_frame[f] = lf_frame;
    is_hn[f] = lf_hint_n;
    is_nv[f] = ir_nv;
    is_recursive[f] = rec;
    is_size[f] = cnt;
    // blocks and instructions, in block order, with the blocks' ranges relative to the function's first instruction
    int at = is_ti;
    b = 0;
    while b < ir_nb {
        is_bs[is_tb + b] = at - is_ti;
        int i2 = ir_bs[b];
        while i2 < ir_be[b] {
            is_op[at] = ir_op[i2]; is_d[at] = ir_d[i2]; is_a[at] = ir_a[i2]; is_b[at] = ir_b[i2]; is_bi[at] = ir_bi[i2];
            is_k[at] = ir_k[i2]; is_w[at] = ir_w[i2]; is_t1[at] = ir_t1[i2]; is_t2[at] = ir_t2[i2];
            is_ac[at] = ir_ac[i2];
            if ir_ac[i2] > 0 {
                is_as[at] = is_ta;
                int g = 0;
                while g < ir_ac[i2] {
                    is_args[is_ta] = ir_args[ir_as[i2] + g];
                    is_ta += 1;
                    g += 1;
                }
            }
            at += 1;
            i2 += 1;
        }
        is_be[is_tb + b] = at - is_ti;
        b += 1;
    }
    is_ti = at;
    is_tb += ir_nb;
    int n = 0;
    while n < ir_nnames {
        str_copy(@is_names + (is_tn + n) * 64, @ir_name + n * 64, 64);
        n += 1;
    }
    is_tn += ir_nnames;
    int h = 0;
    while h < lf_hint_n {
        is_hint[is_th + h] = lf_hint_text[h];
        h += 1;
    }
    is_th += lf_hint_n;
    int v = 0;
    while v < ir_nv {
        is_vc[is_tv + v] = ir_vcls[v];
        v += 1;
    }
    is_tv += ir_nv;
    is_count += 1;
}

// write one instruction at the end of the arrays
int in_put(int op, int d, int a, int b, int bi, int k, int w, int t1, int t2) {
    int j = ir_n;
    ir_op[j] = op; ir_d[j] = d; ir_a[j] = a; ir_b[j] = b; ir_bi[j] = bi; ir_k[j] = k; ir_w[j] = w;
    ir_t1[j] = t1; ir_t2[j] = t2; ir_as[j] = 0; ir_ac[j] = 0;
    ir_n += 1;
    return j;
}

int in_map[IS_MAXV];

int in_v(int v) {
    if v >= 64 { return in_map[v]; }
    return v;
}

// the hint line of the callee, its offsets moved by delta, added to the hint line of the caller
void in_hint(int f, int delta) {
    int n = is_hn[f];
    int base = is_h0[f];
    int p = 2;
    while p < n {
        while p < n && is_hint[base + p] == ' ' { p += 1; }
        if p < n {
            int off = 0;
            while p < n && is_hint[base + p] >= '0' && is_hint[base + p] <= '9' { off = off * 10 + (is_hint[base + p] - '0'); p += 1; }
            p += 1;
            int size = 0;
            while p < n && is_hint[base + p] >= '0' && is_hint[base + p] <= '9' { size = size * 10 + (is_hint[base + p] - '0'); p += 1; }
            p += 1;
            int flag = 0;
            while p < n && is_hint[base + p] >= '0' && is_hint[base + p] <= '9' { flag = flag * 10 + (is_hint[base + p] - '0'); p += 1; }
            // write " off:size:flag"
            if lf_hint_n < 16000 - 40 {
                if lf_hint_n == 0 {
                    lf_hint_text[0] = ';';
                    lf_hint_text[1] = 'H';
                    lf_hint_n = 2;
                }
                lf_hint_text[lf_hint_n] = ' ';
                lf_hint_n += 1;
                int parts[3];
                parts[0] = off + delta;
                parts[1] = size;
                parts[2] = flag;
                int q = 0;
                while q < 3 {
                    char dg[12];
                    int dn = 0;
                    int dv = parts[q];
                    if dv == 0 { dg[0] = '0'; dn = 1; }
                    while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
                    while dn > 0 { dn -= 1; lf_hint_text[lf_hint_n] = dg[dn]; lf_hint_n += 1; }
                    if q < 2 { lf_hint_text[lf_hint_n] = ':'; lf_hint_n += 1; }
                    q += 1;
                }
            }
        }
    }
}

// replace the call c in the block b by the body of the function f; false if there is no room
bool in_inline(int b, int c, int f) {
    int nbc = is_nb[f];
    // room
    if ir_nb + nbc + 2 >= IR_MAXB - 2 || ir_n + 2 * (ir_be[b] - ir_bs[b]) + 4 * is_ni[f] + 64 >= IR_MAXI || ir_nv + is_nv[f] >= IR_MAXV - 8 { return false; }
    // the temporaries of the callee get new vregs
    int v = 64;
    while v < is_nv[f] {
        in_map[v] = ir_vreg(is_vc[is_v0[f] + v]);
        v += 1;
    }
    // frame: the slots (offsets from 16) move up by delta; the stack cells (negative offsets) go below the deepest one of the caller
    int delta = lf_frame - 16;
    int neg = op_maxq();
    lf_frame = lf_frame + is_frame[f] - 16;
    in_hint(f, delta);
    int base = ir_nb;
    int kb = base + nbc;                      // the second half of the block of the call
    // the first half: the instructions before the call, then a jump into the copy
    int s0 = ir_n;
    int i = ir_bs[b];
    while i < c {
        int j = in_put(ir_op[i], ir_d[i], ir_a[i], ir_b[i], ir_bi[i], ir_k[i], ir_w[i], ir_t1[i], ir_t2[i]);
        ir_as[j] = ir_as[i];
        ir_ac[j] = ir_ac[i];
        i += 1;
    }
    in_put(IR_JMP, 0, 0, 0, 0, 0, 0, base, 0 - 1);
    int oldend = ir_be[b];
    int oldstart = ir_bs[b];
    // the copy of the callee's blocks
    int cb = 0;
    while cb < nbc {
        int bid = base + cb;
        ir_bs[bid] = ir_n;
        int ci = is_i0[f] + is_bs[is_b0[f] + cb];
        int ce = is_i0[f] + is_be[is_b0[f] + cb];
        while ci < ce {
            int op = is_op[ci];
            int d = is_d[ci];
            if op == IR_PARAM || (op == IR_ADDR_SLOT && d == 30) {
                ci += 1;
                continue;
            }
            int a = is_a[ci];
            int k = is_k[ci];
            int bb = is_b[ci];
            if is_bi[ci] == 0 && (ir_uses_b(op)) { bb = in_v(bb); }
            if (op == IR_LOAD || op == IR_STORE) && a == 30 {
                if k >= 0 { k = k + delta; } else { k = k - neg; }
            } else if op == IR_ADDR_SLOT {
                k = k + delta;
            } else if op == IR_ADD && a == 30 && is_bi[ci] == 1 {
                bb = bb + delta;
            }
            if op == IR_RET {
                if a != 1 && a != 0 { in_put(IR_COPY, 1, in_v(a), 0, 0, 0, 0, 0 - 1, 0 - 1); }
                in_put(IR_JMP, 0, 0, 0, 0, 0, 0, kb, 0 - 1);
                ci += 1;
                continue;
            }
            int t1 = is_t1[ci];
            int t2 = is_t2[ci];
            if op == IR_JMP || op == IR_BR || op == IR_FBR { t1 = t1 + base; }
            if op == IR_BR || op == IR_FBR { t2 = t2 + base; }
            if op == IR_CALL {
                k = ir_name_index(@is_names + (is_n0[f] + k) * 64);
            }
            int j2 = in_put(op, in_v(d), in_v(a), bb, is_bi[ci], k, is_w[ci], t1, t2);
            if is_ac[ci] > 0 {
                int regs[16];
                int g = 0;
                while g < is_ac[ci] && g < 16 {
                    regs[g] = in_v(is_args[is_as[ci] + g]);
                    g += 1;
                }
                ir_set_args(j2, g, @regs);
            }
            ci += 1;
        }
        ir_be[bid] = ir_n;
        cb += 1;
    }
    // the second half
    ir_bs[kb] = ir_n;
    i = c + 1;
    while i < oldend {
        int j3 = in_put(ir_op[i], ir_d[i], ir_a[i], ir_b[i], ir_bi[i], ir_k[i], ir_w[i], ir_t1[i], ir_t2[i]);
        ir_as[j3] = ir_as[i];
        ir_ac[j3] = ir_ac[i];
        i += 1;
    }
    ir_be[kb] = ir_n;
    ir_blab[kb] = 0 - 1;
    int z = 0;
    while z < nbc {
        ir_blab[base + z] = 0 - 1;
        z += 1;
    }
    ir_bs[b] = s0;
    ir_be[b] = s0 + (c - oldstart) + 1;
    ir_nb = kb + 1;
    if ir_lastb == b { ir_lastb = kb; }
    inl_done += 1;
    return true;
}

int inl_inloop[IR_MAXB];

// the blocks that are in a loop of the function now
void inl_find_loops() {
    op_graph();
    int b = 0;
    while b < ir_nb {
        inl_inloop[b] = 0;
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int k = 0;
            while k < 2 {
                int sc = op_succ(b, k);
                if sc >= 0 && op_dom(sc, b) {
                    // the loop of the back edge b -> sc: sc and everything that reaches b without passing sc
                    op_stamp += 1;
                    op_mark[sc] = op_stamp;
                    inl_inloop[sc] = 1;
                    int sp = 0;
                    if b != sc {
                        op_mark[b] = op_stamp;
                        op_stack[0] = b;
                        sp = 1;
                    }
                    while sp > 0 {
                        sp -= 1;
                        int x = op_stack[sp];
                        inl_inloop[x] = 1;
                        int e = op_phead[x];
                        while e >= 0 {
                            int p = e / 2;
                            if op_po[p] >= 0 && op_mark[p] != op_stamp {
                                op_mark[p] = op_stamp;
                                op_stack[sp] = p;
                                sp += 1;
                            }
                            e = op_enext[e];
                        }
                    }
                }
                k += 1;
            }
        }
        b += 1;
    }
}

// the calls in the function now that can be replaced
void op_inline(char^ self) {
    // is there a call at all to a function that is kept?
    bool any = false;
    int b0 = 0;
    while b0 < ir_nb && !any {
        int i0 = ir_bs[b0];
        while i0 < ir_be[b0] && !any {
            if ir_op[i0] == IR_CALL && is_find(@ir_name + ir_k[i0] * 64) >= 0 { any = true; }
            i0 += 1;
        }
        b0 += 1;
    }
    if !any { return; }
    inl_find_loops();
    int guard = 0;
    bool again = true;
    while again && guard < 12 {
        again = false;
        int b = 0;
        while b < ir_nb && !again {
            int i = ir_bs[b];
            while i < ir_be[b] && !again {
                if ir_op[i] == IR_CALL && ir_n < 2500 {
                    int f = is_find(@ir_name + ir_k[i] * 64);
                    if f >= 0 && is_recursive[f] == 0 && !str_eq(@is_fname + f * 64, self) && (is_size[f] <= inl_tiny || (inl_inloop[b] == 1 && is_size[f] <= inl_maxsize)) {
                        int nb_before = ir_nb;
                        bool inloop = inl_inloop[b] == 1;
                        if in_inline(b, i, f) {
                            // the new blocks are in a loop if the block of the call was
                            int z = nb_before;
                            while z < ir_nb {
                                if z < IR_MAXB { inl_inloop[z] = 0; if inloop { inl_inloop[z] = 1; } }
                                z += 1;
                            }
                            again = true;
                            guard += 1;
                        }
                    }
                }
                i += 1;
            }
            b += 1;
        }
    }
}


// ---------------------------------------------------------------------------------------------- expressions out of loops
// An instruction that writes a register of a variable (written once in the loop, not live at the entrance of the loop) and whose value
// comes from instructions that are pure and from registers that the loop does not write is made once, in a block in front of the loop:
// the address of b[i] in the loop over j is the same in every turn. The chain of scratch registers that leads to it (x0, x1, ...) moves
// with it and gets registers of its own (temporaries). A chain whose scratch values are read by anything else stays.
int lc_D[64];                   // how many instructions of the loop write the register (a call writes all the registers it clobbers)
int lc_in[IR_MAXB];
int lc_taken[IR_MAXI];
int lc_mem[64];                 // the instructions of the slice being built
int lc_nm;
int lc_hl[2048];                // the instructions to move in order, the slices one after the other; -1 ends a slice
int lc_nh;
int lc_from[64];
int lc_to[64];
int lc_nmap;
int lc_keep;                    // the instruction that makes the value the root store writes and that something else in the loop reads too: it becomes a load of the cell
int lc_kl[256];
int lc_kk[256];
int lc_nkl;
int lc_live;                    // the registers live at the entrance of the loop (the moved code may not write them)
int lc_moved;                   // how many instructions were moved (for the statistics)
int lc_nst[16384];              // the stores to each plain frame slot (index offset / 8) and stack cell (8192 + (-offset) / 8) in the loop
int lc_ldo[16384];              // 1: a load of the slot outside the loop
int lc_rootb;                   // the block and the index of the store that is the root (for the check of the loads)
int lc_rooti;
int lc_rootslot;

// a load of a plain 8-byte frame slot that the loop never writes
bool lc_inv_load(int m) {
    if ir_op[m] != IR_LOAD || ir_a[m] != 30 || ir_w[m] != 8 { return false; }
    int k = ir_k[m];
    if k % 8 != 0 { return false; }
    if k < 0 { return (0 - k) / 8 < 8192 && lc_nst[8192 + (0 - k) / 8] == 0; }
    if k / 8 >= 8192 { return false; }
    return op_plain[k / 8] == 1 && lc_nst[k / 8] == 0;
}

// the index of a frame slot or a stack cell (-1: not a whole slot)
int lc_ci(int k) {
    if k % 8 != 0 { return 0 - 1; }
    if k >= 0 {
        if k / 8 < 8192 { return k / 8; }
        return 0 - 1;
    }
    if (0 - k) / 8 < 8192 { return 8192 + (0 - k) / 8; }
    return 0 - 1;
}

bool lc_pure(int op) {
    if op == IR_CONST || op == IR_COPY { return true; }
    if op >= IR_ADD && op <= IR_MULHS && op != IR_SDIV && op != IR_UDIV { return true; }
    if op == IR_NEG || op == IR_NOT || op == IR_EXT { return true; }
    if op >= IR_FADD && op <= IR_FFLOOR { return true; }
    if op == IR_I2F || op == IR_FCONST || op == IR_BITS2F || op == IR_F2BITS { return true; }
    return false;
}

// the registers an instruction reads: a (when it is a register) and b (when it is a register): -1 for none
int lc_src(int i, int which) {
    int op = ir_op[i];
    if op == IR_CONST || op == IR_FCONST { return 0 - 1; }
    if which == 0 {
        if ir_a[i] > 0 { return ir_a[i]; }
        return 0 - 1;
    }
    if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] > 0 { return ir_b[i]; }
    return 0 - 1;
}

bool lc_in_slice(int m) {
    int q = 0;
    while q < lc_nm {
        if lc_mem[q] == m { return true; }
        q += 1;
    }
    return false;
}

// the slice that makes the value of instruction root (in block b); true when it can move
bool lc_slice(int b, int root) {
    lc_nm = 1;
    lc_mem[0] = root;
    int qi = 0;
    while qi < lc_nm {
        int k = lc_mem[qi];
        int w = 0;
        while w < 2 {
            int r = lc_src(k, w);
            if r >= 1 {
                int m = 0 - 1;
                int j = k - 1;
                while j >= ir_bs[b] && m < 0 {
                    if ir_op[j] != IR_NOP && ir_d[j] == r { m = j; }
                    else if ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL {
                        if r < 64 && (op_clobber() & (1 << r)) != 0 { return false; }
                    }
                    j -= 1;
                }
                if m >= 0 {
                    if lc_taken[m] != 0 || !(lc_pure(ir_op[m]) || lc_inv_load(m)) { return false; }
                    if !lc_in_slice(m) {
                        if lc_nm >= 14 { return false; }
                        lc_mem[lc_nm] = m;
                        lc_nm += 1;
                    }
                } else {
                    // not made in this block before: it must be a register that the loop never writes
                    if r >= 64 || lc_D[r] != 0 { return false; }
                }
            }
            w += 1;
        }
        qi += 1;
    }
    // the member that makes the value of a root store: when something else reads it afterwards it stays in the loop as a load of the cell
    lc_keep = 0 - 1;
    if ir_op[root] == IR_STORE {
        int best = 0 - 1;
        int c = 1;
        while c < lc_nm {
            if ir_d[lc_mem[c]] == ir_b[root] && lc_mem[c] < root && lc_mem[c] > best { best = lc_mem[c]; }
            c += 1;
        }
        lc_keep = best;
    }
    // the scratch registers of the slice are read by nothing outside it, and the entrance of the loop does not need their values
    int a = 1;
    while a < lc_nm {
        int m2 = lc_mem[a];
        int r2 = ir_d[m2];
        if r2 >= 64 || r2 < 1 || (lc_live & (1 << r2)) != 0 { return false; }
        if m2 == lc_keep { a += 1; continue; }
        int j2 = m2 + 1;
        bool redef = false;
        while j2 < ir_be[b] && !redef {
            if !lc_in_slice(j2) && ir_op[j2] != IR_NOP {
                if lc_src(j2, 0) == r2 || lc_src(j2, 1) == r2 { return false; }
                int opj = ir_op[j2];
                if opj == IR_STORE && ir_b[j2] == r2 { return false; }
                if opj == IR_CALL || opj == IR_CALLIND || opj == IR_SYSCALL {
                    int g = 0;
                    while g < ir_ac[j2] {
                        if ir_args[ir_as[j2] + g] == r2 { return false; }
                        g += 1;
                    }
                    if opj != IR_SYSCALL && r2 < 64 && (op_clobber() & (1 << r2)) != 0 { redef = true; }
                }
                if opj == IR_BR || opj == IR_FBR || opj == IR_RET {
                    if ir_a[j2] == r2 || (ir_uses_b(opj) && ir_bi[j2] == 0 && ir_b[j2] == r2) { return false; }
                }
                if ir_d[j2] == r2 { redef = true; }
            } else if lc_in_slice(j2) && ir_d[j2] == r2 && j2 != m2 {
                redef = true;
            }
            j2 += 1;
        }
        if !redef && r2 < 64 && (op_lo[b] & (1 << r2)) != 0 { return false; }
        a += 1;
    }
    return true;
}

// the instructions that were moved out of the loop (written into the new block at the end)
int lc_bop[1024];
int lc_bd[1024];
int lc_ba[1024];
int lc_bb[1024];
int lc_bbi[1024];
int lc_bk[1024];
int lc_bw[1024];
int lc_nb2;
int lc_q;                       // the deepest stack cell used (a new cell is 8 deeper)
int lc_tl[16384];               // the cells and slots that the function touches (each once)
int lc_ntl;
int lc_tmark[16384];
int lc_tstamp;
int lc_tot[16384];              // the loads of each slot / cell in the whole function that do not follow a store of the cell in their own block (stack cells) or any load (slots)

// the loads of the whole function (once, and again after a loop was changed)
void lc_prep() {
    int zi = 0;
    while zi < lc_ntl {
        lc_tot[lc_tl[zi]] = 0;
        zi += 1;
    }
    lc_ntl = 0;
    lc_tstamp += 1;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int i3 = ir_bs[b];
            int seen_st[40];
            int nseen = 0;
            while i3 < ir_be[b] {
                if ir_a[i3] == 30 && ir_op[i3] != IR_NOP && lc_ci(ir_k[i3]) >= 0 {
                    int ws = lc_ci(ir_k[i3]);
                    if lc_tmark[ws] != lc_tstamp {
                        lc_tmark[ws] = lc_tstamp;
                        lc_tl[lc_ntl] = ws;
                        lc_ntl += 1;
                        lc_tot[ws] = 0;
                    }
                    if ir_op[i3] == IR_STORE && nseen < 40 { seen_st[nseen] = ws; nseen += 1; }
                    if ir_op[i3] == IR_LOAD {
                        bool own = false;
                        if ir_k[i3] < 0 {
                            int sq = 0;
                            while sq < nseen { if seen_st[sq] == ws { own = true; } sq += 1; }
                        }
                        if !own { lc_tot[ws] += 1; }
                    }
                }
                i3 += 1;
            }
        }
        b += 1;
    }
}

// the numbers of the loop: how often registers and cells are written there (only the blocks of the loop are looked at)
void lc_count(int h) {
    int r = 0;
    while r < 64 {
        lc_D[r] = 0;
        r += 1;
    }
    int zz = 0;
    while zz < lc_ntl {
        int ti = lc_tl[zz];
        lc_nst[ti] = 0;
        lc_ldo[ti] = lc_tot[ti];
        zz += 1;
    }
    int b = 0;
    while b < ir_nb {
        if lc_in[b] == 1 {
            int i = ir_bs[b];
            int seen_st[40];
            int nseen = 0;
            while i < ir_be[b] {
                int op = ir_op[i];
                if op != IR_NOP {
                    int dm = op_defs(i);
                    if op == IR_SYSCALL { dm = dm | op_clobber(); }
                    int v = 1;
                    while v < 64 {
                        if (dm & (1 << v)) != 0 { lc_D[v] += 1; }
                        v += 1;
                    }
                    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                        v = 1;
                        while v < 64 {
                            if (dm & (1 << v)) != 0 { lc_D[v] += 1; }
                            v += 1;
                        }
                    }
                    if ir_a[i] == 30 && lc_ci(ir_k[i]) >= 0 {
                        int ws = lc_ci(ir_k[i]);
                        if op == IR_STORE { lc_nst[ws] += 1; if nseen < 40 { seen_st[nseen] = ws; nseen += 1; } }
                        if op == IR_LOAD {
                            // the loads inside the loop are not "outside"
                            bool own = false;
                            if ir_k[i] < 0 {
                                int sq = 0;
                                while sq < nseen { if seen_st[sq] == ws { own = true; } sq += 1; }
                            }
                            if !own { lc_ldo[ws] -= 1; }
                        }
                    }
                }
                i += 1;
            }
        }
        b += 1;
    }
}

// is the slice in lc_mem worth a cell: a multiplication or a division in it, or three instructions
bool lc_worth() {
    int a = 0;
    while a < lc_nm {
        int op = ir_op[lc_mem[a]];
        if op == IR_MUL || op == IR_MULHS || op == IR_FMUL || op == IR_FDIV || op == IR_FSQRT { return true; }
        a += 1;
    }
    return lc_nm >= 3;
}

// is the store i2 (in block b) a root that can be moved? every load of its slot in the loop comes after it
bool lc_store_ok(int b, int i2) {
    if ir_op[i2] != IR_STORE || ir_a[i2] != 30 || ir_w[i2] != 8 || lc_taken[i2] != 0 { return false; }
    int sk = lc_ci(ir_k[i2]);
    if sk < 0 { return false; }
    if !(ir_k[i2] < 0 || op_plain[sk] == 1) { return false; }
    if lc_nst[sk] != 1 || lc_ldo[sk] != 0 || ir_b[i2] <= 0 || ir_bi[i2] != 0 { return false; }
    int lb = 0;
    while lb < ir_nb {
        if lc_in[lb] == 1 {
            int li = ir_bs[lb];
            while li < ir_be[lb] {
                if ir_op[li] == IR_LOAD && ir_a[li] == 30 && ir_k[li] == ir_k[i2] {
                    if lb == b { if li < i2 { return false; } }
                    else if !op_dom(b, lb) { return false; }
                }
                li += 1;
            }
        }
        lb += 1;
    }
    return true;
}

// the loop with the header h: expressions out of it, one at a time (what a move leaves behind can be moved the next time).
// Returns true when something was moved (the graph is made again).
bool lc_loop(int h) {
    // the blocks of the loop
    int b = 0;
    while b < ir_nb {
        lc_in[b] = 0;
        b += 1;
    }
    lc_in[h] = 1;
    int sp = 0;
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && b != h {
            int k = 0;
            while k < 2 {
                if op_succ(b, k) == h && lc_in[b] == 0 && op_dom(h, b) {
                    lc_in[b] = 1;
                    op_stack[sp] = b;
                    sp += 1;
                }
                k += 1;
            }
        }
        b += 1;
    }
    while sp > 0 {
        sp -= 1;
        int x = op_stack[sp];
        int e = op_phead[x];
        while e >= 0 {
            int p = e / 2;
            if op_po[p] >= 0 && lc_in[p] == 0 {
                lc_in[p] = 1;
                op_stack[sp] = p;
                sp += 1;
            }
            e = op_enext[e];
        }
    }
    vn_hints();
    lc_live = op_li[h];
    lc_nb2 = 0;
    lc_nkl = 0;
    int attempts = 0;
    bool found = true;
    while found && attempts < 40 && lc_nb2 < 900 {
        found = false;
        attempts += 1;
        lc_count(h);
        b = 0;
        while b < ir_nb && !found {
            if lc_in[b] == 1 {
                int i2 = ir_bs[b];
                int e2 = ir_be[b];
                while i2 < e2 && !found {
                    int op2 = ir_op[i2];
                    int d = ir_d[i2];
                    bool cand = false;
                    if op2 == IR_STORE { cand = lc_store_ok(b, i2); }
                    else if op2 != IR_NOP && lc_taken[i2] == 0 && lc_pure(op2) && op2 != IR_CONST && d >= 1 && d <= 63 && lc_D[d] == 1 && (lc_live & (1 << d)) == 0 { cand = true; }
                    bool value_root = false;
                    if !cand && op2 != IR_NOP && op2 != IR_STORE && op2 != IR_CONST && op2 != IR_COPY && lc_pure(op2) && d >= 1 && d <= 63 && lc_D[d] >= 1 { value_root = true; }
                    if value_root && !(lc_slice(b, i2) && lc_nm >= 2 && lc_worth()) { value_root = false; }
                    if (cand || value_root) && (value_root || lc_slice(b, i2)) {
                        if value_root { lc_keep = 0 - 1; }
                        // in the order of the instructions
                        int a = 0;
                        while a < lc_nm {
                            int c = a + 1;
                            while c < lc_nm {
                                if lc_mem[c] < lc_mem[a] {
                                    int t = lc_mem[a];
                                    lc_mem[a] = lc_mem[c];
                                    lc_mem[c] = t;
                                }
                                c += 1;
                            }
                            a += 1;
                        }
                        // the move: the copies go to the buffer, the originals go away (or become a load of the cell)
                        int vcell = 0;
                        if value_root {
                            // the value of the last instruction is kept in a new cell: written once before the loop, read where it was made
                            lc_q += 8;
                            vcell = 0 - lc_q;
                        }
                        a = 0;
                        while a < lc_nm && lc_nb2 < 1000 {
                            int m = lc_mem[a];
                            lc_bop[lc_nb2] = ir_op[m];
                            lc_bd[lc_nb2] = ir_d[m];
                            lc_ba[lc_nb2] = ir_a[m];
                            lc_bb[lc_nb2] = ir_b[m];
                            lc_bbi[lc_nb2] = ir_bi[m];
                            lc_bk[lc_nb2] = ir_k[m];
                            lc_bw[lc_nb2] = ir_w[m];
                            lc_nb2 += 1;
                            if value_root && m == i2 {
                                // the store of the value in the new cell comes right after the instruction in the buffer
                                lc_bop[lc_nb2] = IR_STORE;
                                lc_bd[lc_nb2] = 0;
                                lc_ba[lc_nb2] = 30;
                                lc_bb[lc_nb2] = ir_d[m];
                                lc_bbi[lc_nb2] = 0;
                                lc_bk[lc_nb2] = vcell;
                                lc_bw[lc_nb2] = 8;
                                lc_nb2 += 1;
                                ir_op[m] = IR_LOAD;
                                ir_a[m] = 30;
                                ir_b[m] = 0;
                                ir_bi[m] = 0;
                                ir_k[m] = vcell;
                                ir_w[m] = 8;
                            } else if m == lc_keep {
                                ir_op[m] = IR_LOAD;
                                ir_a[m] = 30;
                                ir_b[m] = 0;
                                ir_bi[m] = 0;
                                ir_k[m] = ir_k[i2];
                                ir_w[m] = 8;
                            } else {
                                ir_op[m] = IR_NOP;
                                ir_d[m] = 0;
                                ir_a[m] = 0;
                                ir_bi[m] = 1;
                            }
                            lc_moved += 1;
                            a += 1;
                        }
                        found = true;
                    }
                    i2 += 1;
                }
            }
            b += 1;
        }
    }
    if lc_nb2 == 0 { return false; }
    // the new block in front of the loop
    int nb0 = ir_nb;
    int pre = ir_new_block(0 - 1);
    ir_set_block(pre);
    int hi = 0;
    while hi < lc_nb2 {
        int ni = ir_add(lc_bop[hi], lc_bd[hi], lc_ba[hi], lc_bb[hi], lc_bbi[hi], lc_bk[hi]);
        ir_w[ni] = lc_bw[hi];
        hi += 1;
    }
    int jm = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jm] = h;
    // every jump to the header from outside the loop goes to the new block
    b = 0;
    while b < nb0 {
        if lc_in[b] == 0 {
            int t = ir_be[b] - 1;
            int top = ir_op[t];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[t] == h { ir_t1[t] = pre; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[t] == h { ir_t2[t] = pre; }
        }
        b += 1;
    }
    return true;
}

// all the loops, the innermost first (a header is found by its back edge; a header that is deeper in the tree of dominators is inner)
int lc_us;                      // the time of this pass (the microseconds, for -xtime)
int lc_calls;
void op_licm_exprs() {
    int t0 = 0;
    if x_time == 1 { t0 = tm_now(); lc_calls += 1; }
    op_licm_run();
    if x_time == 1 { lc_us += tm_now() - t0; }
}

void op_licm_run() {
    op_graph();
    int zc = 0;
    while zc < 16384 {              // nothing may be left from the function before (docs/design/16-separate-compilation.md, -xrepeat)
        lc_nst[zc] = 0;
        lc_ldo[zc] = 0;
        lc_tot[zc] = 0;
        lc_tmark[zc] = 0;
        zc += 1;
    }
    lc_ntl = 0;
    int hs[64];
    int hd[64];
    int nh = 0;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int k = 0;
            while k < 2 {
                int s = op_succ(b, k);
                if s > 0 && op_dom(s, b) && nh < 60 {
                    bool seen = false;
                    int z = 0;
                    while z < nh {
                        if hs[z] == s { seen = true; }
                        z += 1;
                    }
                    if !seen {
                        int dep = 0;
                        int x = s;
                        while x > 0 && dep < 1000 {
                            x = op_idom[x];
                            dep += 1;
                        }
                        hs[nh] = s;
                        hd[nh] = dep;
                        nh += 1;
                    }
                }
                k += 1;
            }
        }
        b += 1;
    }
    if nh == 0 { return; }
    // the deepest first
    int i = 1;
    while i < nh {
        int th = hs[i];
        int td = hd[i];
        int j = i - 1;
        while j >= 0 && hd[j] < td {
            hs[j + 1] = hs[j];
            hd[j + 1] = hd[j];
            j -= 1;
        }
        hs[j + 1] = th;
        hd[j + 1] = td;
        i += 1;
    }
    lc_q = op_maxq();
    op_liveness();
    lc_prep();
    i = 0;
    while i < nh {
        if lc_loop(hs[i]) {
            op_liveness();
            lc_prep();
        }
        i += 1;
    }
}

// ---------------------------------------------------------------------------------------------- stores to stack cells that nobody reads
int dc_read[16384];
int dc_changes;

void op_dead_cells() {
    if (ir_opt & 524288) != 0 { return; }
    int i = 0;
    while i < 16384 {
        dc_read[i] = 0;
        i += 1;
    }
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] == IR_LOAD && ir_a[j] == 30 {
                    int k = ir_k[j];
                    int w = ir_w[j];
                    if w < 0 { w = 0 - w; }
                    if w == 0 { w = 8; }
                    if k < 0 {
                        dc_read[8192 + (0 - k) / 8] = 1;
                        dc_read[8192 + (0 - k + 7) / 8] = 1;
                    } else if k / 8 < 8192 {
                        dc_read[k / 8] = 1;
                        if (k + w - 1) / 8 < 8192 { dc_read[(k + w - 1) / 8] = 1; }
                    }
                }
                j += 1;
            }
        }
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int j2 = ir_bs[b];
            while j2 < ir_be[b] {
                if ir_op[j2] == IR_STORE && ir_a[j2] == 30 && ir_w[j2] == 8 {
                    int k2 = ir_k[j2];
                    int sl = 0 - 1;
                    if k2 < 0 && (0 - k2) % 8 == 0 && (0 - k2) / 8 < 8192 { sl = 8192 + (0 - k2) / 8; }
                    else if k2 >= 0 && k2 % 8 == 0 && k2 / 8 < 8192 && op_plain[k2 / 8] == 1 { sl = k2 / 8; }
                    if sl >= 0 && dc_read[sl] == 0 {
                        ir_op[j2] = IR_NOP;
                        ir_d[j2] = 0;
                        ir_a[j2] = 0;
                        ir_bi[j2] = 1;
                        dc_changes += 1;
                    }
                }
                j2 += 1;
            }
        }
        b += 1;
    }
}


// ---------------------------------------------------------------------------------------------- stack cells inside one block
// `store [cell], r` ... `d = load [cell]` ... `store [cell], x` in one block: the value only goes through the cell, but r may have been
// written again before the load (the registers are not single-assignment, so value numbering cannot name it). The store becomes
// `d = copy r` (d is neither read nor written in between) and the load goes away. Arguments of inlined calls are passed this way.

int cf_changes;

int cf_loads[8192];             // the loads of each plain frame slot in the function
int cf_nloads[8192];            // the loads of each cell below the frame base (the temporaries): index (0 - offset) / 8; +2 for another width
int cf_vesc;                    // 1: the frame base is used as a value (an address of the frame is taken): no cell can be said to be private

void op_cell_fwd() {
    if (ir_opt & 16777216) != 0 { return; }
    vn_hints();
    int zi = 0;
    while zi < 8192 {
        cf_loads[zi] = 0;
        zi += 1;
    }
    zi = 0;
    while zi < 8192 {
        cf_nloads[zi] = 0;
        zi += 1;
    }
    cf_vesc = 0;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int lj = ir_bs[b];
            while lj < ir_be[b] {
                if ir_op[lj] == IR_LOAD && ir_a[lj] == 30 && ir_k[lj] >= 0 && ir_k[lj] / 8 < 8192 {
                    cf_loads[ir_k[lj] / 8] += 1;
                    if ir_k[lj] % 8 != 0 || ir_w[lj] != 8 { cf_loads[ir_k[lj] / 8] += 2; }
                }
                if ir_op[lj] == IR_LOAD && ir_a[lj] == 30 && ir_k[lj] < 0 {
                    // the cells below the base: a load of another width touches two of them
                    int nk = (0 - ir_k[lj] + 7) / 8;
                    int nk2 = (0 - ir_k[lj] + ir_w[lj] + 6) / 8;
                    if nk >= 0 && nk < 8192 { cf_nloads[nk] += 1; }
                    if nk2 != nk && nk2 < 8192 { cf_nloads[nk2] += 2; }
                    if ir_k[lj] % 8 != 0 || ir_w[lj] != 8 { if nk < 8192 { cf_nloads[nk] += 2; } }
                }
                if ir_op[lj] != IR_NOP {
                    int vu = op_uses(lj);
                    bool base_use = (ir_op[lj] == IR_LOAD && ir_a[lj] == 30) || (ir_op[lj] == IR_STORE && ir_a[lj] == 30 && !(ir_bi[lj] == 0 && ir_b[lj] == 30));
                    if (vu & op_bit(30)) != 0 && !base_use { cf_vesc = 1; }
                }
                lj += 1;
            }
        }
        b += 1;
    }
    op_liveness();
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int s = ir_bs[b];
            int mention = op_lo[b];             // the registers that the block names, and the ones that live after it
            int mj = ir_bs[b];
            while mj < ir_be[b] {
                mention = mention | op_uses(mj) | op_defs(mj);
                mj += 1;
            }
            while s < ir_be[b] {
                bool lone = false;           // a plain slot that is read by one load only: the store goes away with it
                if ir_op[s] == IR_STORE && ir_a[s] == 30 && ir_w[s] == 8 && ir_k[s] >= 0 && ir_k[s] % 8 == 0 && ir_k[s] / 8 < 8192 {
                    lone = op_plain[ir_k[s] / 8] == 1 && cf_loads[ir_k[s] / 8] == 1;
                }
                if ir_op[s] == IR_STORE && ir_a[s] == 30 && ir_w[s] == 8 && ir_k[s] < 0 && ir_k[s] % 8 == 0 && cf_vesc == 0 && ir_bi[s] == 0 {
                    // a temporary below the base that one load reads (the address of `b[i]` kept while the right side is computed)
                    int nk = (0 - ir_k[s] + 7) / 8;
                    if nk >= 0 && nk < 8192 && cf_nloads[nk] == 1 { lone = true; }
                }
                if ir_op[s] == IR_STORE && ir_a[s] == 30 && ir_w[s] == 8 && (ir_k[s] < 0 || lone) && ir_bi[s] == 0 {
                    int c = ir_k[s];
                    int r = ir_b[s];
                    int ld = 0 - 1;
                    int uses = 0;                     // registers read in between, by a call also the arguments
                    int defs = 0;
                    bool over = false;
                    bool bad = false;
                    int j = s + 1;
                    while j < ir_be[b] && !over && !bad {
                        int op = ir_op[j];
                        if op == IR_LOAD && ir_a[j] == 30 && ir_k[j] < c + 8 && ir_k[j] + 8 > c {
                            if ir_k[j] == c && ir_w[j] == 8 && ld < 0 { ld = j; } else { bad = true; }
                        } else if op == IR_STORE && ir_a[j] == 30 && ir_k[j] < c + 8 && ir_k[j] + 8 > c {
                            if ir_k[j] == c && ir_w[j] == 8 { over = true; } else { bad = true; }
                        } else {
                            if ld < 0 {
                                uses = uses | op_uses(j);
                                defs = defs | op_defs(j);
                            }
                        }
                        j += 1;
                    }
                    if (over || lone) && !bad && ld > 0 {
                        int d = ir_d[ld];
                        int bt = op_bit(d);
                        if d >= 1 && d < 64 && r >= 1 && r < 64 && ir_vcls[d] == ir_vcls[r] && (uses & bt) == 0 && (defs & bt) == 0 {
                            ir_op[s] = IR_COPY;
                            ir_d[s] = d;
                            ir_a[s] = r;
                            ir_b[s] = 0;
                            ir_k[s] = 0;
                            ir_bi[s] = 0;
                            ir_op[ld] = IR_NOP;
                            ir_d[ld] = 0;
                            ir_a[ld] = 0;
                            ir_bi[ld] = 1;
                            cf_changes += 1;
                        } else if d >= 1 && d < 64 && r >= 1 && r < 64 && ir_vcls[d] == ir_vcls[r] && lone {
                            // d or r is written or read in between: the value waits in a register that this block does not name
                            int t = 0;
                            int lo = 1;
                            int hi = 14;
                            if ir_vcls[r] == 1 { lo = 32; hi = 39; }
                            int tt = lo;
                            while tt <= hi && t == 0 {
                                if (mention & (1 << tt)) == 0 { t = tt; }
                                tt += 1;
                            }
                            if t != 0 {
                                mention = mention | (1 << t);
                                ir_op[s] = IR_COPY;
                                ir_d[s] = t;
                                ir_a[s] = r;
                                ir_b[s] = 0;
                                ir_k[s] = 0;
                                ir_bi[s] = 0;
                                ir_op[ld] = IR_COPY;
                                ir_a[ld] = t;
                                ir_b[ld] = 0;
                                ir_k[ld] = 0;
                                ir_bi[ld] = 0;
                                cf_changes += 1;
                            }
                        }
                    }
                }
                s += 1;
            }
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- variables that are set once to a number
// A plain frame slot (a local `int n = 200;` that is never changed) with exactly one store in the whole function, of a number made in
// the same block, in a block that comes before every load of the slot: each load is the number itself. The loop bounds and the factors
// of the products then fold (`n * n`, `cmp i, 200`), and the register pass has fewer variables to keep.

int cc_cnt[8192];
int cc_blk[8192];
int cc_pos[8192];
int cc_val[8192];
int cc_const[8192];
int cc_changes;

void op_const_cells() {
    if (ir_opt & 33554432) != 0 { return; }
    vn_hints();
    op_graph();
    int i = 0;
    while i < 8192 {
        cc_cnt[i] = 0;
        cc_const[i] = 0;
        i += 1;
    }
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] == IR_STORE && ir_a[j] == 30 && ir_k[j] >= 0 {
                    int sl = ir_k[j] / 8;
                    int w = ir_w[j];
                    if w < 0 { w = 0 - w; }
                    if sl < 8192 {
                        // a store of a different width or place touches the slot of its first byte only; plain slots are whole words
                        cc_cnt[sl] += 1;
                        if (w != 8 || ir_k[j] % 8 != 0) { cc_cnt[sl] += 2; }
                        cc_blk[sl] = b;
                        cc_pos[sl] = j;
                        // the value: the last definition of the register before the store in this block
                        if ir_bi[j] == 0 {
                            int r = ir_b[j];
                            int q = j - 1;
                            while q >= ir_bs[b] {
                                if ir_d[q] == r && ir_op[q] != IR_NOP { break; }
                                if ir_op[q] == IR_CALL || ir_op[q] == IR_CALLIND || ir_op[q] == IR_SYSCALL {
                                    if r >= 1 && r <= 19 { q = ir_bs[b] - 2; break; }
                                }
                                q -= 1;
                            }
                            if q >= ir_bs[b] && ir_op[q] == IR_CONST && ir_d[q] == r {
                                cc_val[sl] = ir_k[q];
                                cc_const[sl] = 1;
                            } else {
                                cc_const[sl] = 0;
                            }
                        } else {
                            cc_const[sl] = 0;
                        }
                    }
                }
                j += 1;
            }
        }
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int j2 = ir_bs[b];
            while j2 < ir_be[b] {
                if ir_op[j2] == IR_LOAD && ir_a[j2] == 30 && ir_k[j2] >= 0 && ir_w[j2] == 8 && ir_k[j2] % 8 == 0 && ir_k[j2] / 8 < 8192 {
                    int sl2 = ir_k[j2] / 8;
                    if cc_cnt[sl2] == 1 && cc_const[sl2] == 1 && op_plain[sl2] == 1 && ir_d[j2] >= 1 && ir_d[j2] < 64 && ir_vcls[ir_d[j2]] == 0 {
                        bool before = false;
                        if cc_blk[sl2] == b { before = cc_pos[sl2] < j2; } else { before = op_dom(cc_blk[sl2], b); }
                        if before {
                            ir_op[j2] = IR_CONST;
                            ir_k[j2] = cc_val[sl2];
                            ir_a[j2] = 0;
                            ir_b[j2] = 0;
                            ir_bi[j2] = 0;
                            cc_changes += 1;
                        }
                    }
                }
                j2 += 1;
            }
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- struct temporaries in the frame (SROA)
// A pointer that is the frame pointer plus a number (ADDR_SLOT, add x, x29, #N, and copies and sums of them, also when they went through a
// stack cell) is followed through each chain of blocks; a load or store through such a pointer becomes a load or store at the offset
// from the frame pointer. The address computations are dead after that; a frame object whose address is still used somewhere else (a call
// argument, ...) is not touched. Frame objects that are only accessed by whole 8-byte words after that are written to the hint line as plain
// slots, so the passes that know the plain slots (value numbering, dead stores) and the register pass treat each word as a variable.

int fa_reg[IR_MAXV];
int fa_st[IR_MAXV];
int fa_cur;
int fa_cell[16384];
int fa_cst[16384];
int fa_changes;

int fa_get(int r) {
    if r == 30 { return 0; }
    if r < 1 || r >= ir_nv || fa_st[r] != fa_cur { return 0 - 1000000; }
    return fa_reg[r];
}

void fa_set(int r, int off) {
    if r < 1 || r >= ir_nv { return; }
    fa_reg[r] = off;
    fa_st[r] = fa_cur;
}

void fa_clear(int r) {
    if r >= 1 && r < ir_nv { fa_st[r] = 0; }
}

void fa_block(int b, int cont) {
    if cont == 0 { fa_cur += 1; }
    int i = ir_bs[b];
    while i < ir_be[b] {
        int op = ir_op[i];
        int d = ir_d[i];
        // a load or a store through a frame pointer plus a number
        if (op == IR_LOAD || op == IR_STORE) && ir_a[i] != 30 {
            int fo = fa_get(ir_a[i]);
            int wq = ir_w[i];
            if wq < 0 { wq = 0 - wq; }
            if wq == 0 { wq = 1; }
            if fo > 0 - 1000000 && fo + ir_k[i] >= 16 && fo + ir_k[i] < 30000 && (fo + ir_k[i]) % wq == 0 {
                ir_k[i] = fo + ir_k[i];
                ir_a[i] = 30;
                fa_changes += 1;
            }
        }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            fa_cur += 1;                                  // the registers are not known after a call (the cells stay, but they are looked up by version)
            fa_clear(d);
        } else if op == IR_ADDR_SLOT && d != 30 {
            fa_set(d, ir_k[i]);
        } else if op == IR_ADD && ir_bi[i] == 1 && fa_get(ir_a[i]) > 0 - 1000000 {
            fa_set(d, fa_get(ir_a[i]) + ir_b[i]);
        } else if op == IR_COPY && fa_get(ir_a[i]) > 0 - 1000000 && ir_a[i] != 30 {
            fa_set(d, fa_get(ir_a[i]));
        } else if op == IR_LOAD && ir_a[i] == 30 && ir_w[i] == 8 {
            // a pointer that was stored in a stack cell
            int sl = 0 - 1;
            if ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 8192 { sl = 8192 + (0 - ir_k[i]) / 8; }
            else if ir_k[i] >= 0 && ir_k[i] % 8 == 0 && ir_k[i] / 8 < 8192 && op_plain[ir_k[i] / 8] == 1 { sl = ir_k[i] / 8; }
            if sl >= 0 && fa_cst[sl] == fa_cur { fa_set(d, fa_cell[sl]); } else { fa_clear(d); }
        } else if op == IR_STORE && ir_a[i] == 30 && ir_w[i] == 8 {
            int sl2 = 0 - 1;
            if ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 8192 { sl2 = 8192 + (0 - ir_k[i]) / 8; }
            else if ir_k[i] >= 0 && ir_k[i] % 8 == 0 && ir_k[i] / 8 < 8192 && op_plain[ir_k[i] / 8] == 1 { sl2 = ir_k[i] / 8; }
            if sl2 >= 0 {
                int vo = fa_get(ir_b[i]);
                if vo > 0 - 1000000 && ir_b[i] != 30 { fa_cell[sl2] = vo; fa_cst[sl2] = fa_cur; } else { fa_cst[sl2] = 0; }
            }
        } else if d != 0 {
            fa_clear(d);
        }
        i += 1;
    }
}

// the objects of the frame from the hint line
int ob_off[2048];
int ob_size[2048];
int ob_flag[2048];
int ob_esc[2048];
int ob_n;

void fa_objects() {
    ob_n = 0;
    int n = lf_hint_n;
    int p = 2;
    while p < n && ob_n < 2048 {
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
            ob_off[ob_n] = off;
            ob_size[ob_n] = size;
            ob_flag[ob_n] = flag;
            ob_esc[ob_n] = 0;
            ob_n += 1;
        }
    }
}

int fa_object_of(int k) {
    int j = 0;
    while j < ob_n {
        if k >= ob_off[j] && k < ob_off[j] + ob_size[j] { return j; }
        j += 1;
    }
    return 0 - 1;
}

void op_sroa_finish() {
    fa_objects();
    bool all_esc = false;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            int i = ir_bs[b];
            while i < ir_be[b] {
                int op = ir_op[i];
                int k = ir_k[i];
                // the frame pointer in any other use (plus a register, a copy ...): any object may be reached
                if (ir_a[i] == 30 && op != IR_LOAD && op != IR_STORE && !(op == IR_ADD && ir_bi[i] == 1) && op != IR_ADDR_SLOT) { all_esc = true; }
                if ((ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30) && !(op == IR_STORE && false)) { all_esc = true; }
                if (op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL) {
                    int g = 0;
                    while g < ir_ac[i] {
                        if ir_args[ir_as[i] + g] == 30 { all_esc = true; }
                        g += 1;
                    }
                }
                if (op == IR_ADDR_SLOT && ir_d[i] != 30) || (op == IR_ADD && ir_a[i] == 30 && ir_bi[i] == 1) {
                    int off = k;
                    if op == IR_ADD { off = ir_b[i]; }
                    int o = fa_object_of(off);
                    if o >= 0 { ob_esc[o] = 1; }
                    if (ir_opt & 262144) != 0 { write_err("  address of "); write_err_int(off); write_err(" by instruction "); write_err_int(i); write_err(" op "); write_err_int(op); write_err("\n"); }
                } else if (op == IR_LOAD || op == IR_STORE) && ir_a[i] == 30 && k >= 16 {
                    int o2 = fa_object_of(k);
                    if o2 >= 0 && ob_flag[o2] == 0 {
                        int w = ir_w[i];
                        if w < 0 { w = 0 - w; }
                        if !(w == 8 && k % 8 == 0 && k % 8 == 0 && ob_off[o2] % 8 == 0 && k + 8 <= ob_off[o2] + ob_size[o2]) { ob_esc[o2] = 1; }
                    }
                }
                i += 1;
            }
        }
        b += 1;
    }
    if (ir_opt & 262144) != 0 { write_err("function "); write_err(@ir_fname); if all_esc { write_err(" (all objects reached)"); } write_err("\n"); }
    if all_esc {
        int jj = 0;
        while jj < ob_n {
            ob_esc[jj] = 1;
            jj += 1;
        }
    }
    // the hint line again: an object that was not plain, is not used by its address any more and is made of whole words, is plain words now
    char nt[16384];
    int nn = 0;
    nt[0] = ';';
    nt[1] = 'H';
    nn = 2;
    int j = 0;
    bool changed = false;
    while j < ob_n && nn < 15000 {
        bool conv = ob_flag[j] == 0 && ob_esc[j] == 0 && ob_size[j] % 8 == 0 && ob_off[j] % 8 == 0 && ob_size[j] <= 128;
        int words = 1;
        int osz = ob_size[j];
        if conv { words = ob_size[j] / 8; osz = 8; changed = true; }
        if (ir_opt & 262144) != 0 {
            write_err("object "); write_err_int(ob_off[j]); write_err(":"); write_err_int(ob_size[j]); write_err(":"); write_err_int(ob_flag[j]);
            if ob_esc[j] == 1 { write_err(" escaped"); }
            if conv { write_err(" -> words"); }
            write_err("\n");
        }
        int w = 0;
        while w < words {
            int vals[3];
            vals[0] = ob_off[j] + w * 8;
            vals[1] = osz;
            vals[2] = ob_flag[j];
            if conv { vals[2] = 1; }
            if ob_esc[j] == 1 && ob_flag[j] == 1 { vals[2] = 0; changed = true; }
            nt[nn] = ' ';
            nn += 1;
            int q = 0;
            while q < 3 {
                char dg[12];
                int dn = 0;
                int dv = vals[q];
                if dv == 0 { dg[0] = '0'; dn = 1; }
                while dv > 0 { dg[dn] = '0' + dv % 10; dv = dv / 10; dn += 1; }
                while dn > 0 { dn -= 1; nt[nn] = dg[dn]; nn += 1; }
                if q < 2 { nt[nn] = ':'; nn += 1; }
                q += 1;
            }
            w += 1;
        }
        j += 1;
    }
    if changed && j == ob_n && (ir_opt & 65536) == 0 {
        int t = 0;
        while t < nn {
            lf_hint_text[t] = nt[t];
            t += 1;
        }
        lf_hint_n = nn;
    }
}

void op_sroa() {
    if (ir_opt & 131072) == 0 { op_walk(1); }
    op_clean_run();                               // the address computations that nobody uses any more must not count as uses
    op_graph();
    op_sroa_finish();
}

// ---------------------------------------------------------------------------------------------- function alignment
// Every function starts at an address that is a multiple of al_to bytes (".align N" in the assembler text). Measured on the Cortex-A55: the
// speed of `fib` changed between 68 and 83 ms only by moving the function by a few instructions; at 32 bytes it is always the fast one.


void al_run() {
    regs_len = 0;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_has(i, ";N\n") {
            i = en + 1;                                   // the marker of a naked function: its job was to keep the passes away
            continue;
        }
        if al_to != 0 && rg_is_func(i) {
            rg_text(".align ");
            rg_int(al_to);
            rg_put(10);
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

// ---------------------------------------------------------------------------------------------- @no_reorder (the statement: jc_low.j)
// after the code is made: the lines between ";NB" and ";NE" get a marker in front of each instruction
void nr_run() {
    bool any = false;
    int i = 0;
    while i < out_len {
        int en = rg_end(i);
        if rg_has(i, ";NB\n") { any = true; }
        i = en + 1;
    }
    if !any { return; }
    regs_len = 0;
    bool inside = false;
    i = 0;
    while i < out_len {
        int en2 = rg_end(i);
        if rg_has(i, ";NB\n") {
            inside = true;
        } else if rg_has(i, ";NE\n") {
            inside = false;
        } else {
            if inside && out_buf[i] != ';' && !(out_buf[en2 - 1] == ':') {
                rg_text(";N\n");
            }
            rg_copy(i, en2);
        }
        i = en2 + 1;
    }
    int t = 0;
    while t < regs_len {
        out_buf[t] = regs_buf[t];
        t += 1;
    }
    out_len = regs_len;
}

// ---------------------------------------------------------------------------------------------- known ranges of whole numbers
// For every whole number (a vreg inside a block, a plain frame slot or a stack cell across blocks) the pass keeps an upper bound
// "0 .. hi" when the value cannot be negative. The values are
//   0 .. rn_big - 1   a number that is never negative and at most that
//   rn_big            never negative, no known bound: a counter (it started small and gets small steps; it would need 2^50 steps to wrap)
//   rn_unk            nothing is known
// (-2 is "not reached yet" in the flow and is the identity of the join, a maximum.) The flow is solved over the blocks (a loop makes the
// bound of a counter grow: after a few turns it becomes rn_big). What the knowledge buys:
//   * a shift that moves every possible bit out (`x >> 63` of a counter: the sign fix of a division by a constant) is 0,
//   * `x & 0xFFFFFFFF` of a value that fits is x,
//   * the rotation of a 32-bit value written as `((x >> n) | (x << (32 - n))) & 0xFFFFFFFF` is one `ror w` (IR_ROTR32).

#define RN_NT 32
#define RN_NS 96                 // the tracked slots (RN_NT) and the registers v1 .. v63
#define RN_MAXB 2048

int rn_out[196608];              // [block * RN_NS + t]: the bounds of the tracked slots and of the registers at the end of the block
int rn_cs[RN_NS];                // the bounds in the block being scanned
int rn_ent[64];                  // the bounds of the registers when the block began
int rn_lr[IR_MAXV];              // the bound of a vreg inside the block (valid when rn_ls is the stamp of the block)
int rn_ls[IR_MAXV];
int rn_stamp;
int rn_ir[IR_MAXI];              // the bound of the result of each instruction (set when the block is scanned)
int rn_id[16384];                // slot (vn_slot) -> index t, or -1
int rn_nt;
int rn_leak;
int rn_changes;
int rn_big;
int rn_unk;
int rn_total;                    // all functions (for -irstat)

int rn_get(int v) {
    if v <= 0 || v >= IR_MAXV { return rn_unk; }
    if v < 64 {
        int x = rn_cs[RN_NT + v];
        if x < 0 { return 0; }
        return x;
    }
    if rn_ls[v] != rn_stamp { return rn_unk; }
    return rn_lr[v];
}

void rn_set(int v, int x) {
    if v > 0 && v < 64 { rn_cs[RN_NT + v] = x; }
    else if v >= 64 && v < IR_MAXV {
        rn_lr[v] = x;
        rn_ls[v] = rn_stamp;
    }
}

// the slot index t of a load / store, or -1
int rn_slot_t(int i) {
    int s = vn_slot(i);
    if s < 0 { return 0 - 1; }
    if s >= 8192 && rn_leak != 0 { return 0 - 1; }
    return rn_id[s];
}

int rn_add(int x, int y) {
    if x == rn_unk || y == rn_unk { return rn_unk; }
    if x == rn_big && y == rn_big { return rn_unk; }
    if x == rn_big { if y <= 1048576 { return rn_big; } return rn_unk; }
    if y == rn_big { if x <= 1048576 { return rn_big; } return rn_unk; }
    int s = x + y;
    if s >= rn_big { return rn_unk; }
    return s;
}

int rn_mul(int x, int y) {
    if x == rn_unk || y == rn_unk || x == rn_big || y == rn_big { return rn_unk; }
    if x == 0 || y == 0 { return 0; }
    if x > (rn_big - 1) / y { return rn_unk; }
    return x * y;
}

// all bits below the highest bit 1
int rn_smear(int m) {
    int r = m;
    r = r | (r >> 1);
    r = r | (r >> 2);
    r = r | (r >> 4);
    r = r | (r >> 8);
    r = r | (r >> 16);
    r = r | (r >> 32);
    return r;
}

// the bound of the number the second operand is (a number of the instruction or a vreg)
int rn_bval(int i) {
    if ir_bi[i] == 1 {
        int k = ir_b[i];
        if k >= 0 && k < rn_big { return k; }
        return rn_unk;
    }
    return rn_get(ir_b[i]);
}

// the bound of the result of the instruction i
int rn_eval(int i) {
    int op = ir_op[i];
    int d = ir_d[i];
    if d <= 0 || d >= IR_MAXV { return rn_unk; }
    if ir_vcls[d] != 0 { return rn_unk; }
    int a = rn_get(ir_a[i]);
    if op == IR_CONST {
        if ir_k[i] >= 0 && ir_k[i] < rn_big { return ir_k[i]; }
        if ir_k[i] >= 0 { return rn_big; }       // a big positive number (the multiplier of a division): never negative
        return rn_unk;
    }
    if op == IR_COPY { return a; }
    if op == IR_ADD { return rn_add(a, rn_bval(i)); }
    if op == IR_MUL { return rn_mul(a, rn_bval(i)); }
    if op == IR_AND {
        if ir_bi[i] == 1 {
            int k = ir_b[i];
            if k >= 0 && k < rn_big { return k; }
            if k < 0 { return a; }         // a & ~mask: not bigger than a
            return rn_unk;
        }
        int bb = rn_get(ir_b[i]);
        if a == rn_unk { return bb; }
        if bb == rn_unk { return a; }
        if a < bb { return a; }
        return bb;
    }
    if op == IR_OR || op == IR_XOR {
        int bo = rn_bval(i);
        if a == rn_unk || bo == rn_unk { return rn_unk; }
        if a == rn_big || bo == rn_big { return rn_big; }
        int m = a;
        if bo > m { m = bo; }
        return rn_smear(m);
    }
    if op == IR_SHL {
        if ir_bi[i] == 0 || a == rn_unk || a == rn_big { return rn_unk; }
        int k = ir_b[i];
        if k < 0 || k > 61 { return rn_unk; }
        if a > (rn_big - 1) >> k { return rn_unk; }
        return a << k;
    }
    if op == IR_LSHR || op == IR_ASHR {
        if ir_bi[i] == 0 { return rn_unk; }
        int k = ir_b[i];
        if k < 0 || k > 63 { return rn_unk; }
        if a == rn_unk {
            if op == IR_LSHR && k >= 2 { return (1 << (64 - k)) - 1; }
            return rn_unk;
        }
        if a == rn_big { if k >= 1 { return rn_big; } return rn_big; }
        return a >> k;
    }
    if op == IR_MULHS {
        int bm = rn_get(ir_b[i]);
        if ir_bi[i] == 1 { bm = rn_bval(i); }
        if a != rn_unk && bm != rn_unk { return rn_big; }
        return rn_unk;
    }
    if op == IR_SDIV || op == IR_UDIV {
        if ir_bi[i] == 1 && ir_b[i] > 0 && a != rn_unk {
            if a == rn_big { return rn_big; }
            return a / ir_b[i];
        }
        return rn_unk;
    }
    if op == IR_SETCC { return 1; }
    if op == IR_EXT {
        if ir_w[i] == 0 && ir_k[i] == 8 { return 255; }
        if ir_w[i] == 0 && ir_k[i] == 16 { return 65535; }
        if ir_w[i] == 0 && ir_k[i] == 32 { return 4294967295; }
        return rn_unk;
    }
    if op == IR_ROTR32 { return 4294967295; }
    if op == IR_CLZ || op == IR_POPCNT { return 64; }
    if op == IR_LOAD {
        int w = ir_w[i];
        if w == 1 { return 255; }
        if w == 2 { return 65535; }
        if w == 4 { return 4294967295; }
        int t = rn_slot_t(i);
        if t >= 0 && w == 8 {
            int v = rn_cs[t];
            if v < 0 { return 0; }
            return v;
        }
        return rn_unk;
    }
    return rn_unk;
}

// the last instruction before `pos` in the block b that writes the vreg v (-1: none in the block, -2: a call in between)
int rn_find_def(int b, int pos, int v) {
    int j = pos - 1;
    while j >= ir_bs[b] {
        int op = ir_op[j];
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { return 0 - 2; }
        if ir_d[j] == v && op != IR_NOP && op != IR_STORE { return j; }
        j -= 1;
    }
    return 0 - 1;
}

// is the vreg v written by an instruction in [from, to)?
bool rn_written(int from, int to, int v) {
    int j = from;
    while j < to {
        if ir_d[j] == v && ir_op[j] != IR_NOP && ir_op[j] != IR_STORE { return true; }
        j += 1;
    }
    return false;
}

// where the value of v at `pos` comes from, through copies: the instruction that made it (>= 0), or -(v + 10) when it is the value the
// block started with, or -1 when it cannot be said
int rn_origin(int b, int pos, int v) {
    int j = rn_find_def(b, pos, v);
    int at = pos;
    int x = v;
    int n = 0;
    while j >= 0 && ir_op[j] == IR_COPY && n < 16 {
        at = j;
        x = ir_a[j];
        j = rn_find_def(b, j, x);
        n += 1;
    }
    if j >= 0 { return j; }
    if j == 0 - 1 { return 0 - (x + 10); }
    return 0 - 1;
}

// the rotation of a 32-bit number: D = and(or(shr(x, n), shl(x, 32 - n)), 0xFFFFFFFF), x not bigger than 32 bits
bool rn_rotate(int b, int i) {
    if ir_bi[i] != 1 || ir_b[i] != 4294967295 { return false; }
    int c = rn_find_def(b, i, ir_a[i]);
    if c < 0 || ir_op[c] != IR_OR || ir_bi[c] != 0 { return false; }
    int p = rn_find_def(b, c, ir_a[c]);
    int q = rn_find_def(b, c, ir_b[c]);
    int hop = 0;
    while p >= 0 && ir_op[p] == IR_COPY && hop < 8 { p = rn_find_def(b, p, ir_a[p]); hop += 1; }
    hop = 0;
    while q >= 0 && ir_op[q] == IR_COPY && hop < 8 { q = rn_find_def(b, q, ir_a[q]); hop += 1; }
    if p < 0 || q < 0 || ir_bi[p] != 1 || ir_bi[q] != 1 { return false; }
    int r = p;
    int l = q;
    if ir_op[p] == IR_SHL { r = q; l = p; }
    if ir_op[l] != IR_SHL { return false; }
    if ir_op[r] != IR_LSHR && ir_op[r] != IR_ASHR { return false; }
    int n = ir_b[r];
    if n < 1 || n > 31 || ir_b[l] != 32 - n { return false; }
    int o1 = rn_origin(b, r, ir_a[r]);
    int o2 = rn_origin(b, l, ir_a[l]);
    if o1 == 0 - 1 || o1 != o2 { return false; }
    // the value must be known to fit in 32 bits (the instruction that made it)
    int src = 0;
    if o1 >= 0 {
        if rn_ir[o1] > 4294967295 { return false; }
        // made by `y & 0xFFFFFFFF`: the instruction ignores the upper half, so y itself can be turned
        if ir_op[o1] == IR_AND && ir_bi[o1] == 1 && ir_b[o1] == 4294967295 && ir_a[o1] > 0 && !rn_written(o1, i, ir_a[o1]) { src = ir_a[o1]; }
    } else {
        // the value the block started with: the bound at the start
        int lv = 0 - (o1 + 10);
        if lv < 1 || lv >= 64 { return false; }
        int eb = rn_ent[lv];
        if eb < 0 || eb > 4294967295 { return false; }
    }
    // a vreg that still holds the value at D
    if src == 0 && !rn_written(l, i, ir_a[l]) { src = ir_a[l]; }
    if src == 0 && !rn_written(r, i, ir_a[r]) { src = ir_a[r]; }
    if src == 0 { return false; }
    ir_op[i] = IR_ROTR32;
    ir_a[i] = src;
    ir_b[i] = n;
    ir_bi[i] = 1;
    ir_k[i] = 0;
    rn_changes += 1;
    return true;
}

// run the transfer of the block b (rewrite: change instructions as well)
void rn_block(int b, bool rewrite) {
    rn_stamp += 1;
    int ev = 1;
    while ev < 64 { rn_ent[ev] = rn_cs[RN_NT + ev]; ev += 1; }
    int i = ir_bs[b];
    while i < ir_be[b] {
        int op = ir_op[i];
        if op == IR_NOP { i += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            rn_stamp += 1;
            int cv = 1;
            while cv <= 19 { rn_cs[RN_NT + cv] = rn_unk; cv += 1; }
            if ir_d[i] > 0 { rn_set(ir_d[i], rn_unk); }
            i += 1;
            continue;
        }
        if op == IR_STORE {
            int t = rn_slot_t(i);
            if t >= 0 && ir_w[i] == 8 {
                if ir_bi[i] == 1 {
                    int k = ir_b[i];
                    if k >= 0 && k < rn_big { rn_cs[t] = k; } else if k >= 0 { rn_cs[t] = rn_big; } else { rn_cs[t] = rn_unk; }
                } else {
                    rn_cs[t] = rn_get(ir_b[i]);
                }
            } else if t >= 0 {
                rn_cs[t] = rn_unk;
            }
            i += 1;
            continue;
        }
        if rewrite && ir_d[i] > 0 && ir_vcls[ir_d[i]] == 0 {
            if (op == IR_LSHR || op == IR_ASHR) && ir_bi[i] == 1 && ir_b[i] >= 1 && ir_b[i] <= 63 {
                int v = rn_get(ir_a[i]);
                int k = ir_b[i];
                bool zero = false;
                if v != rn_unk && v != rn_big && v < (1 << k) { zero = true; }
                if v == rn_big && k == 63 { zero = true; }
                if zero {
                    ir_op[i] = IR_CONST;
                    ir_k[i] = 0;
                    ir_a[i] = 0;
                    ir_b[i] = 0;
                    ir_bi[i] = 1;
                    rn_changes += 1;
                    op = IR_CONST;
                }
            } else if op == IR_AND && ir_bi[i] == 1 && ir_b[i] == 4294967295 {
                if !rn_rotate(b, i) {
                    int v2 = rn_get(ir_a[i]);
                    if v2 != rn_unk && v2 != rn_big && v2 <= 4294967295 {
                        ir_op[i] = IR_COPY;
                        ir_b[i] = 0;
                        ir_bi[i] = 0;
                        rn_changes += 1;
                        op = IR_COPY;
                    }
                }
                op = ir_op[i];
            }
        }
        if ir_d[i] > 0 {
            int rv = rn_eval(i);
            rn_ir[i] = rv;
            rn_set(ir_d[i], rv);
        }
        i += 1;
    }
}

// the state at the start of the block b: the join of the ends of the blocks that come before it
void rn_entry(int b) {
    int t = 0;
    while t < RN_NS {
        rn_cs[t] = 0 - 2;
        if b == 0 { rn_cs[t] = rn_unk; }
        t += 1;
    }
    int e = op_phead[b];
    while e >= 0 {
        int p = e / 2;
        if op_po[p] >= 0 {
            t = 0;
            while t < RN_NS {
                int v = rn_out[p * RN_NS + t];
                if v > rn_cs[t] { rn_cs[t] = v; }
                t += 1;
            }
        }
        e = op_enext[e];
    }
}

void op_range_run() {
    if ir_nb > RN_MAXB || ir_nb < 1 { return; }
    op_graph();
    vn_hints();
    rn_big = 1 << 62;
    rn_unk = rn_big + 1;
    rn_changes = 0;
    // can an address of the frame leak (a stack cell could then change behind our back)?
    rn_leak = 0;
    int i = 0;
    while i < ir_n {
        int op = ir_op[i];
        if op == IR_ADDR_SLOT { if ir_d[i] != 30 { rn_leak = 1; } }
        else if op != IR_LOAD && op != IR_STORE && op != IR_NOP {
            if ir_a[i] == 30 { rn_leak = 1; }
            if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30 { rn_leak = 1; }
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                int g = 0;
                while g < ir_ac[i] {
                    if ir_args[ir_as[i] + g] == 30 { rn_leak = 1; }
                    g += 1;
                }
            }
        }
        if op == IR_STORE && ir_bi[i] == 0 && ir_b[i] == 30 { rn_leak = 1; }
        i += 1;
    }
    // the slots that are loaded or stored as whole words
    i = 0;
    while i < 16384 { rn_id[i] = 0 - 1; i += 1; }
    rn_nt = 0;
    i = 0;
    while i < ir_n {
        if (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE) && ir_a[i] == 30 {
            int s = vn_slot(i);
            if s >= 0 && rn_id[s] < 0 && rn_nt < RN_NT && !(s >= 8192 && rn_leak != 0) {
                rn_id[s] = rn_nt;
                rn_nt += 1;
            }
        }
        i += 1;
    }
    if rn_nt == 0 {
        // no slots: still useful inside the blocks (masks, rotations)
    }
    i = 0;
    while i < ir_nb * RN_NS { rn_out[i] = 0 - 2; i += 1; }
    // the flow
    int pass = 0;
    bool changed = true;
    while changed && pass < 30 {
        changed = false;
        pass += 1;
        int ri = 0;
        while ri < op_nrpo {
            int b = op_rpo[ri];
            rn_entry(b);
            rn_block(b, false);
            int t = 0;
            while t < RN_NS {
                int old = rn_out[b * RN_NS + t];
                int n = rn_cs[t];
                if n < 0 { n = 0; }
                if old >= 0 && n < old { n = old; }
                if pass >= 4 && old >= 0 && n > old && n != rn_unk { n = rn_big; }
                if n != old {
                    rn_out[b * RN_NS + t] = n;
                    changed = true;
                }
                t += 1;
            }
            ri += 1;
        }
    }
    if changed { return; }          // did not settle: change nothing
    int rj = 0;
    while rj < op_nrpo {
        int b2 = op_rpo[rj];
        rn_entry(b2);
        int t2 = 0;
        while t2 < RN_NS {
            if rn_cs[t2] < 0 { rn_cs[t2] = 0; }
            t2 += 1;
        }
        rn_block(b2, true);
        rj += 1;
    }
    rn_total += rn_changes;
}

// ---------------------------------------------------------------------------------------------- counted loops (design 13, V2)
// A natural loop whose header is `load i; load or number n; br i < n` and whose only write of the plain slot i inside the loop is
// `i = i + step` (step a positive number) is a counted loop: it runs from the value i has on entry up to n in steps of `step`. The
// description is kept for the vectoriser (V3); `-irdbg 134217728` prints it.

#define CL_MAX 64
int cl_head[CL_MAX];             // the header block
int cl_slot[CL_MAX];             // the slot index (vn_slot) of the counter
int cl_step[CL_MAX];
int cl_bkind[CL_MAX];            // the bound: 0 a number, 1 a slot that is not written in the loop
int cl_bval[CL_MAX];             // the number, or the slot index
int cl_cc[CL_MAX];               // the condition that keeps the loop going (IR_LT, IR_LE, IR_ULT, IR_ULE)
int cl_body[CL_MAX];             // the first block of the body
int cl_exit[CL_MAX];
int cl_calls[CL_MAX];            // calls inside the loop (a loop with calls is never vectorised)
int cl_nblk[CL_MAX];             // the blocks of the loop
int cl_inner[CL_MAX];            // 1: no other loop inside
int cl_lidx[CL_MAX];             // the loop (op_lh index) of the description
int cl_stb[CL_MAX];              // the block and the instruction of the step of the counter
int cl_sti[CL_MAX];
int cl_n;
int cl_total;                    // all functions (-irstat)

int cl_inv(int cc) {
    if cc == IR_GE { return IR_LT; }
    if cc == IR_GT { return IR_LE; }
    if cc == IR_UGE { return IR_ULT; }
    if cc == IR_UGT { return IR_ULE; }
    return 0 - 1;
}

void cl_analyse(int l) {
    int h = op_lh[l];
    int stamp = op_stamp;
    // the loop is marked with op_stamp (op_mark_loop was called just before)
    int t = ir_be[h] - 1;
    if ir_op[t] != IR_BR || cl_n >= CL_MAX { return; }
    bool in1 = op_mark[ir_t1[t]] == stamp;
    bool in2 = op_mark[ir_t2[t]] == stamp;
    if in1 == in2 { return; }
    int cc = ir_k[t];
    int body = ir_t1[t];
    int ex = ir_t2[t];
    if !in1 {
        cc = cl_inv(cc);
        body = ir_t2[t];
        ex = ir_t1[t];
    }
    if cc != IR_LT && cc != IR_LE && cc != IR_ULT && cc != IR_ULE { return; }
    int ld = rn_find_def(h, t, ir_a[t]);
    if ld < 0 || ir_op[ld] != IR_LOAD || ir_w[ld] != 8 || ir_a[ld] != 30 { return; }
    int sl = vn_slot(ld);
    if sl < 0 { return; }
    // the bound
    int bk = 0;
    int bv = 0;
    if ir_bi[t] == 1 {
        bv = ir_b[t];
    } else {
        int bd = rn_find_def(h, t, ir_b[t]);
        if bd < 0 { return; }
        if ir_op[bd] == IR_CONST { bv = ir_k[bd]; }
        else if ir_op[bd] == IR_LOAD && ir_w[bd] == 8 && ir_a[bd] == 30 && vn_slot(bd) >= 0 { bk = 1; bv = vn_slot(bd); }
        else { return; }
    }
    // the writes inside the loop
    int stores = 0;
    int st_b = 0 - 1;
    int st_i = 0 - 1;
    int calls = 0;
    int nblk = 0;
    bool bound_written = false;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && op_mark[b] == stamp {
            nblk += 1;
            int j = ir_bs[b];
            while j < ir_be[b] {
                int op = ir_op[j];
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { calls += 1; }
                if op == IR_STORE && ir_a[j] == 30 {
                    int s2 = vn_slot(j);
                    if s2 == sl { stores += 1; st_b = b; st_i = j; }
                    else if bk == 1 && s2 == bv { bound_written = true; }
                    else if s2 < 0 {
                        // a store at an offset that is not a plain word: it could be anywhere in the frame
                        int k = ir_k[j];
                        if k >= 0 && (k / 8 == sl || k / 8 == bv) { return; }
                    }
                }
                j += 1;
            }
        }
        b += 1;
    }
    if stores != 1 || bound_written { return; }
    // the store: i = (load i) + step, in the same block
    if ir_bi[st_i] != 0 { return; }
    int ad = rn_find_def(st_b, st_i, ir_b[st_i]);
    if ad < 0 || ir_op[ad] != IR_ADD || ir_bi[ad] != 1 || ir_b[ad] < 1 || ir_b[ad] > 1024 { return; }
    int ld2 = rn_find_def(st_b, ad, ir_a[ad]);
    if ld2 < 0 || ir_op[ld2] != IR_LOAD || ir_w[ld2] != 8 || ir_a[ld2] != 30 || vn_slot(ld2) != sl { return; }
    // nothing stores to the slot between the load and the store (there is one store only), so the value is i + step
    int n = cl_n;
    cl_head[n] = h;
    cl_slot[n] = sl;
    cl_step[n] = ir_b[ad];
    cl_bkind[n] = bk;
    cl_bval[n] = bv;
    cl_cc[n] = cc;
    cl_body[n] = body;
    cl_exit[n] = ex;
    cl_calls[n] = calls;
    cl_nblk[n] = nblk;
    cl_inner[n] = 1;
    cl_lidx[n] = l;
    cl_stb[n] = st_b;
    cl_sti[n] = st_i;
    cl_n += 1;
}

void op_counted_loops() {
    cl_n = 0;
    if ir_nb < 2 || ir_nb > RN_MAXB { return; }
    op_graph();
    vn_hints();
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
    int l = 0;
    while l < op_nloops {
        op_lsize[l] = op_mark_loop(l);
        cl_analyse(l);
        l += 1;
    }
    // an inner loop has no other loop header inside it
    int a = 0;
    while a < cl_n {
        int la = 0;
        while la < op_nloops && op_lh[la] != cl_head[a] { la += 1; }
        if la < op_nloops {
            op_mark_loop(la);
            int c = 0;
            while c < op_nloops {
                if c != la && op_mark[op_lh[c]] == op_stamp { cl_inner[a] = 0; }
                c += 1;
            }
        }
        a += 1;
    }
    cl_total += cl_n;
    if (ir_opt & 134217728) != 0 && cl_n > 0 {
        ir_plen = 0;
        int q = 0;
        while q < cl_n {
            ir_ps("counted loop in ");
            ir_ps(@ir_fname);
            ir_ps(": header B");
            ir_pn(cl_head[q]);
            ir_ps(" slot ");
            ir_pn(cl_slot[q]);
            ir_ps(" step ");
            ir_pn(cl_step[q]);
            if cl_bkind[q] == 0 { ir_ps(" bound number "); } else { ir_ps(" bound slot "); }
            ir_pn(cl_bval[q]);
            ir_ps(" calls ");
            ir_pn(cl_calls[q]);
            ir_ps(" blocks ");
            ir_pn(cl_nblk[q]);
            if cl_inner[q] == 1 { ir_ps(" innermost"); }
            ir_pc(10);
            q += 1;
        }
        syscall(64, 2, @ir_pbuf, ir_plen);
    }
}

// ---------------------------------------------------------------------------------------------- the vectoriser (design 13, V3a)
// An innermost counted loop (step 1, `i < bound`) with a straight-line body that only reads and writes 8-byte elements of arrays
// (`c[i] = a[i] + b[i] * k`, `a[i] = b[i]`) runs two elements per turn in front of the original loop: the original loop stays and
// does the rest (and everything the vector loop does not reach). The blocks:
//   VH0: if i < bound go on, else the original header     VH1: if i + 1 < bound go to VB, else the original header
//   VB : the body with 16-byte loads and stores, `+ - * /` as two lanes, then i = i + 2 and back to VH0
// Only the addresses `base + 8 * i + c` with the base the global area or the frame, and no two accesses that are 1 .. 15 bytes
// apart (the same element, or at least two elements apart: a two-lane step cannot see the difference).
// Floating point results are the same per element. The function gets no fused multiply-add (`;NOFMA` in the text): the elements
// of the vector loop and those of the rest must be made the same way.

#define VZ_KIND_NONE 0
#define VZ_I 1                   // the counter
#define VZ_INV 2                 // a whole number that does not change in the loop (a plain number, or a pointer + number)
#define VZ_IDX8 3                // 8 * i
#define VZ_ADDR 4                // base + 8 * i + c
#define VZ_WORD 5                // an 8-byte element that was loaded (a vector in the vector loop)
#define VZ_VEC 6                 // a double made from such a word, or from vectors by + - * /
#define VZ_DINV 7                // a double that does not change in the loop
#define VZ_VWORD 8               // the bits of a VZ_VEC

int vz_kind[IR_MAXV];
int vz_base[IR_MAXV];            // VZ_INV / VZ_ADDR: 0 a plain number, 29 the global area, 30 the frame
int vz_off[IR_MAXV];             // the number added to the base
int vz_vec[IR_MAXV];             // VZ_WORD / VZ_VEC / VZ_VWORD: the vector vreg in the vector body (class 2)
int vz_def[IR_MAXV];             // the register is written in the body
int vz_chain[256];
int vz_nchain;
int vz_acc_base[64];             // the accesses: base, offset, store?
int vz_acc_off[64];
int vz_acc_st[64];
int vz_nacc;
int vz_count;                    // loops made (all functions)
int vz_tried;
int vz_lslot[IR_MAXV];           // an int value that is a load of a plain slot: the slot index (else -1)
int vz_dslot[IR_MAXV];           // a double that is such a value's bits: the slot
int vz_hs[16];                   // the slots whose double is broadcast once in VP
int vz_hq[16];
int vz_nhs;
int vz_shift;                    // VB: bytes added to every element offset (the second copy of an unrolled body)
int vz_ti;                       // VB: the counter, loaded once
int vz_ab29;                     // VB: v29 + 8 * i (0: not made yet)
int vz_ab30;                     // VB: v30 + 8 * i
#define VZ_ACCV 9                // the value of an accumulator slot at the start of the turn (a vector in the vector loop)
#define VZ_ACCN 10               // the new value of an accumulator (acc + element)
int vz_sl_ld[16384];             // loads / stores of each plain frame slot in the body
int vz_sl_st[16384];
int vz_acc_slot[8];              // the accumulators: the slot, and the vector that holds its two partial sums
int vz_acc_q[32];                // the vectors of the partial sums: accumulator * 4 + chunk
int vz_nacc2;
int vz_pk_base[16];              // the pointers that walk along the arrays: base, offset, the stack cell that holds the pointer
int vz_pk_off[16];
int vz_pk_cell[16];
int vz_npk;
int vz_br_end;                   // the branch at the end of the vector body
int vz_has_fp;                   // the body has floating point arithmetic on elements
int vz_bq[64];                  // a double register that the body only reads: its broadcast made in VP (0: none)
int vz_w;                        // the size of the elements the loop reads and writes: 8 (the original), 4 (float, i32) or 1 (char)
int vz_lg;                       // log2 of it
int vz_work[IR_MAXI];            // the body instructions in order
int vz_nwork;

// the offset from the frame pointer of the slot index s (vn_slot)
int vz_slot_off(int s) {
    if s >= 8192 { return 0 - (s - 8192) * 8; }
    return s * 8;
}

bool vz_is_nop(int j) {
    return ir_op[j] == IR_NOP;
}

// the scalar instruction j cloned into the block that is being written
void vz_clone(int j) {
    int e = ir_add(ir_op[j], ir_d[j], ir_a[j], ir_b[j], ir_bi[j], ir_k[j]);
    ir_w[e] = ir_w[j];
}

// the arrangement code of IR_VOP / IR_VDUP for the element size: 1 = .2d, 2 = .4s, 3 = .16b
int vz_arr() {
    if vz_w == 8 { return 1; }
    if vz_w == 4 { return 2; }
    return 3;
}

// the whole number r (a scalar) in every lane
int vz_bcast(int r) {
    int qv = ir_vreg(2);
    int dp = ir_add(IR_VDUP, qv, r, 0, 0, 0);
    ir_w[dp] = vz_arr();
    return qv;
}

int vz_iabs(int w) {
    if w < 0 { return 0 - w; }
    return w;
}

// the register that holds base + 8 * i in the vector body (made at the first use)
int vz_abase(int base) {
    int cur = vz_ab29;
    if base == 30 { cur = vz_ab30; }
    if cur != 0 { return cur; }
    int tsh = ir_vreg(0);
    if vz_lg == 0 { ir_add(IR_COPY, tsh, vz_ti, 0, 0, 0); } else { ir_add(IR_SHL, tsh, vz_ti, vz_lg, 1, 0); }
    int ab = ir_vreg(0);
    ir_add(IR_ADD, ab, base, tsh, 0, 0);
    if base == 30 { vz_ab30 = ab; } else { vz_ab29 = ab; }
    return ab;
}

// the index of the pointer for base + off (a new one is made when emit is false)
int vz_kadd;                     // vz_ptr: what the access adds to the pointer (its offset minus the offset the pointer was made with)

// one pointer serves every access of the same base whose offset is the same modulo 16 and within 60000 bytes (the offset of ldr q is
// a multiple of 16 and at most 65520): three arrays are one pointer and one step for each turn, not three
int vz_pk_find(int base, int off, bool make) {
    int u = 0;
    while u < vz_npk {
        if vz_pk_base[u] == base {
            int dd = off - vz_pk_off[u];
            if (dd & 15) == 0 && dd < 60000 && dd > 0 - 60000 {
                if make && off < vz_pk_off[u] { vz_pk_off[u] = off; }       // the smallest offset is the anchor: no negative offsets
                return u;
            }
        }
        u += 1;
    }
    if !make || vz_npk >= 16 { return 0 - 1; }
    vz_pk_base[vz_npk] = base;
    vz_pk_off[vz_npk] = off;
    vz_npk += 1;
    return vz_npk - 1;
}

// the pointer of the access `base + 8 * i + off`, loaded from its cell (the register pass keeps the cell in a register)
int vz_ptr(int base, int off) {
    int u = vz_pk_find(base, off, false);
    int pt = ir_vreg(0);
    int lp = ir_add(IR_LOAD, pt, 30, 0, 0, 0);
    ir_w[lp] = 8;
    ir_k[lp] = vz_pk_cell[u];
    vz_kadd = off - vz_pk_off[u];
    return pt;
}

int vz_hq_of(int slot) {
    int u = 0;
    while u < vz_nhs {
        if vz_hs[u] == slot { return vz_hq[u]; }
        u += 1;
    }
    return 0;
}

// walk the body: the kind of every value, the accesses; with emit the vector body is written too (into the block being written)
// false when anything is not understood
bool vz_scan(int q, int islot, int incl, int inch, bool emit) {
    int h = cl_head[q];
    vz_nacc = 0;
    if !emit { vz_has_fp = 0; }
    int v = 0;
    while v < ir_nv {
        vz_kind[v] = 0;
        vz_def[v] = 0;
        vz_lslot[v] = 0 - 1;
        vz_dslot[v] = 0 - 1;
        v += 1;
    }
    if !emit { vz_nhs = 0; }
    // what the body writes
    int c = 0;
    while c < vz_nchain {
        int b = vz_chain[c];
        int j = ir_bs[b];
        while j < ir_be[b] - 1 {
            if ir_op[j] != IR_NOP && ir_d[j] > 0 && j != inch { vz_def[ir_d[j]] = 1; }
            j += 1;
        }
        c += 1;
    }
    // the loads and stores of frame slots in the body (an accumulator is stored once and loaded once)
    {
        int zi = 0;
        while zi < 16384 { vz_sl_ld[zi] = 0; vz_sl_st[zi] = 0; zi += 1; }
        int zc = 0;
        while zc < vz_nchain {
            int zb = vz_chain[zc];
            int zj = ir_bs[zb];
            while zj < ir_be[zb] - 1 {
                if (ir_op[zj] == IR_LOAD || ir_op[zj] == IR_STORE) && ir_a[zj] == 30 {
                    int zs = vn_slot(zj);
                    if zs >= 0 {
                        if ir_op[zj] == IR_LOAD { vz_sl_ld[zs] += 1; } else { vz_sl_st[zs] += 1; }
                    }
                }
                zj += 1;
            }
            zc += 1;
        }
        if !emit { vz_nacc2 = 0; }
    }
    // the size of the elements: all the accesses through an address that is not the frame must have the same one
    vz_w = 0;
    {
        int pc = 0;
        while pc < vz_nchain {
            int pb = vz_chain[pc];
            int pj = ir_bs[pb];
            while pj < ir_be[pb] - 1 {
                if (ir_op[pj] == IR_LOAD || ir_op[pj] == IR_STORE) && ir_a[pj] != 30 && pj != incl && pj != inch {
                    int pw = vz_iabs(ir_w[pj]);
                    if pw != 8 && pw != 4 && pw != 1 { return false; }
                    if vz_w == 0 { vz_w = pw; } else if vz_w != pw { return false; }
                }
                pj += 1;
            }
            pc += 1;
        }
        if vz_w == 0 { vz_w = 8; }
        vz_lg = 3;
        if vz_w == 4 { vz_lg = 2; }
        if vz_w == 1 { vz_lg = 0; }
    }
    // live in: v29 the global area, v30 the frame
    vz_kind[29] = VZ_INV; vz_base[29] = 29; vz_off[29] = 0;
    vz_kind[30] = VZ_INV; vz_base[30] = 30; vz_off[30] = 0;
    c = 0;
    while c < vz_nchain {
        int b2 = vz_chain[c];
        int j2 = ir_bs[b2];
        while j2 < ir_be[b2] - 1 {
            int op = ir_op[j2];
            // the counter step: its load, add and store are not part of the work
            if j2 == incl || j2 == incl + 1 || j2 == inch { j2 += 1; continue; }
            if op == IR_NOP { j2 += 1; continue; }
            // reading a register that the body writes later (a value carried to the next turn)
            int a = ir_a[j2];
            if a > 0 && a < ir_nv && vz_def[a] == 1 && vz_kind[a] == 0 { return false; }
            if ir_uses_b(op) && ir_bi[j2] == 0 && ir_b[j2] > 0 && ir_b[j2] < ir_nv && vz_def[ir_b[j2]] == 1 && vz_kind[ir_b[j2]] == 0 { return false; }
            int d = ir_d[j2];
            if op == IR_LOAD && ir_a[j2] == 30 && ir_w[j2] != 8 {
                // a float or a 32-bit number kept in a slot, that the loop does not write: it does not change
                int lk = ir_k[j2];
                int lwn = vz_iabs(ir_w[j2]);
                if lwn != 4 && lwn != 1 { return false; }
                int sc2 = 0;
                while sc2 < vz_nchain {
                    int sb2 = vz_chain[sc2];
                    int sj2 = ir_bs[sb2];
                    while sj2 < ir_be[sb2] - 1 {
                        if ir_op[sj2] == IR_STORE && ir_a[sj2] == 30 && ir_k[sj2] < lk + 8 && ir_k[sj2] + 8 > lk { return false; }
                        sj2 += 1;
                    }
                    sc2 += 1;
                }
                vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0;
                if emit { vz_clone(j2); }
            } else if op == IR_LOAD {
                if ir_w[j2] != 8 && ir_a[j2] == 30 { return false; }
                if ir_a[j2] != 30 && vz_iabs(ir_w[j2]) != vz_w { return false; }
                if ir_a[j2] == 30 && ir_bi[j2] == 0 {
                    int s = vn_slot(j2);
                    if s < 0 { return false; }
                    if s != islot && vz_sl_st[s] > 0 {
                        // an accumulator: one load, one store, a whole number, a plain slot, no use of the slot's value except `acc + x`
                        if vz_w != 8 { return false; }
                        if vz_sl_st[s] != 1 || vz_sl_ld[s] != 1 || vz_nacc2 >= 8 && !emit { return false; }
                        int ai = 0;
                        while ai < vz_nacc2 && vz_acc_slot[ai] != s { ai += 1; }
                        if ai >= vz_nacc2 {
                            if emit { return false; }
                            vz_acc_slot[ai] = s;
                            vz_acc_q[ai * 4] = 0;
                            vz_acc_q[ai * 4 + 1] = 0;
                            vz_acc_q[ai * 4 + 2] = 0;
                            vz_acc_q[ai * 4 + 3] = 0;
                            vz_nacc2 += 1;
                        }
                        vz_kind[d] = VZ_ACCV;
                        vz_lslot[d] = s;
                        vz_vec[d] = vz_acc_q[ai * 4 + vz_shift / 16];
                        j2 += 1;
                        continue;
                    }
                    if s == islot { vz_kind[d] = VZ_I; }
                    else { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; vz_lslot[d] = s; }
                    if emit && vz_kind[d] != VZ_I { vz_clone(j2); }
                } else if vz_kind[ir_a[j2]] == VZ_ADDR {
                    if vz_nacc >= 64 { return false; }
                    vz_acc_base[vz_nacc] = vz_base[ir_a[j2]];
                    vz_acc_off[vz_nacc] = vz_off[ir_a[j2]] + ir_k[j2];
                    vz_acc_st[vz_nacc] = 0;
                    vz_nacc += 1;
                    if emit {
                        int qv = ir_vreg(2);
                        int lpt = vz_ptr(vz_base[ir_a[j2]], vz_off[ir_a[j2]] + ir_k[j2]);
                        int le = ir_add(IR_LOAD, qv, lpt, 0, 0, vz_shift + vz_kadd);
                        ir_w[le] = 16;
                        vz_vec[d] = qv;
                    }
                    vz_kind[d] = VZ_WORD;
                } else { return false; }
            } else if op == IR_CONST {
                vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0;
                if emit { vz_clone(j2); }
            } else if op == IR_COPY {
                int sa = ir_a[j2];
                int ks = vz_kind[sa];
                if ks == 0 || ks == VZ_ACCN { return false; }
                vz_kind[d] = ks; vz_base[d] = vz_base[sa]; vz_off[d] = vz_off[sa]; vz_vec[d] = vz_vec[sa];
                vz_lslot[d] = vz_lslot[sa]; vz_dslot[d] = vz_dslot[sa];
                if emit && ks != VZ_VEC && ks != VZ_VWORD && ks != VZ_WORD && ks != VZ_ADDR && ks != VZ_IDX8 && ks != VZ_I && ks != VZ_ACCV { vz_clone(j2); }
            } else if op == IR_SHL {
                if vz_kind[ir_a[j2]] == VZ_WORD && ir_bi[j2] == 1 && ir_b[j2] >= 0 && ir_b[j2] < vz_w * 8 {
                    // a lane shifted to the left by a number (the bits that leave the lane are lost, as the store loses them)
                    if emit {
                        int cn = ir_vreg(0);
                        ir_add(IR_CONST, cn, 0, 0, 0, ir_b[j2]);
                        int qc = vz_bcast(cn);
                        int sh2 = ir_vreg(2);
                        int shn = ir_add(IR_VOP, sh2, vz_vec[ir_a[j2]], qc, 0, 10);
                        ir_w[shn] = vz_arr();
                        vz_vec[d] = sh2;
                    }
                    vz_kind[d] = VZ_WORD;
                    j2 += 1;
                    continue;
                }
                if ir_bi[j2] != 1 || ir_b[j2] != vz_lg || vz_kind[ir_a[j2]] != VZ_I { return false; }
                vz_kind[d] = VZ_IDX8;
            } else if (op == IR_ADD || op == IR_SUB) && ir_bi[j2] == 0 && (vz_kind[ir_a[j2]] == VZ_ACCV || (op == IR_ADD && vz_kind[ir_b[j2]] == VZ_ACCV)) {
                int ra5 = ir_a[j2];
                int rx = ir_b[j2];
                if vz_kind[rx] == VZ_ACCV { int t5 = ra5; ra5 = rx; rx = t5; }
                // the other operand: a loaded element or a value that does not change
                int kx = vz_kind[rx];
                if kx != VZ_WORD && kx != VZ_INV { return false; }
                if vz_kind[ra5] != VZ_ACCV { return false; }
                if emit {
                    int qx = 0;
                    if kx == VZ_WORD { qx = vz_vec[rx]; }
                    else {
                        qx = ir_vreg(2);
                        int dupx = ir_add(IR_VDUP, qx, rx, 0, 0, 0);
                        ir_w[dupx] = 1;
                    }
                    int aq = vz_vec[ra5];
                    int ve5 = ir_add(IR_VOP, aq, aq, qx, 0, 4);
                    if op == IR_SUB { ir_k[ve5] = 5; }
                    ir_w[ve5] = 1;
                    vz_vec[d] = aq;
                }
                vz_kind[d] = VZ_ACCN;
                vz_lslot[d] = vz_lslot[ra5];
            } else if (op == IR_ADD || op == IR_SUB || op == IR_MUL || op == IR_AND || op == IR_OR || op == IR_XOR) && (vz_kind[ir_a[j2]] == VZ_WORD || (ir_bi[j2] == 0 && vz_kind[ir_b[j2]] == VZ_WORD)) {
                // element-wise whole number arithmetic: the lanes hold the low bytes of the scalar result, which is all that a store keeps
                int ra6 = ir_a[j2];
                int ka6 = vz_kind[ra6];
                int kb6 = VZ_INV;
                if ir_bi[j2] == 0 { kb6 = vz_kind[ir_b[j2]]; }
                if ka6 != VZ_WORD && ka6 != VZ_INV { return false; }
                if kb6 != VZ_WORD && kb6 != VZ_INV { return false; }
                if op == IR_MUL && vz_w == 8 { return false; }
                if emit {
                    int qa6 = 0;
                    int qb6 = 0;
                    if ka6 == VZ_WORD { qa6 = vz_vec[ra6]; } else { qa6 = vz_bcast(ra6); }
                    if ir_bi[j2] == 1 {
                        int cn6 = ir_vreg(0);
                        ir_add(IR_CONST, cn6, 0, 0, 0, ir_b[j2]);
                        qb6 = vz_bcast(cn6);
                    } else if kb6 == VZ_WORD { qb6 = vz_vec[ir_b[j2]]; }
                    else { qb6 = vz_bcast(ir_b[j2]); }
                    int kk6 = 4;
                    if op == IR_SUB { kk6 = 5; } else if op == IR_MUL { kk6 = 6; } else if op == IR_AND { kk6 = 7; } else if op == IR_OR { kk6 = 8; } else if op == IR_XOR { kk6 = 9; }
                    int qr6 = ir_vreg(2);
                    int ve6 = ir_add(IR_VOP, qr6, qa6, qb6, 0, kk6);
                    ir_w[ve6] = vz_arr();
                    vz_vec[d] = qr6;
                }
                vz_kind[d] = VZ_WORD;
            } else if op == IR_ADD {
                int ka = vz_kind[ir_a[j2]];
                if ir_bi[j2] == 1 {
                    if ka == VZ_INV { vz_kind[d] = VZ_INV; vz_base[d] = vz_base[ir_a[j2]]; vz_off[d] = vz_off[ir_a[j2]] + ir_b[j2]; }
                    else if ka == VZ_ADDR { vz_kind[d] = VZ_ADDR; vz_base[d] = vz_base[ir_a[j2]]; vz_off[d] = vz_off[ir_a[j2]] + ir_b[j2]; }
                    else { return false; }
                } else {
                    int kb = vz_kind[ir_b[j2]];
                    int ra = ir_a[j2];
                    int rb = ir_b[j2];
                    if vz_w == 1 {
                        // elements of one byte: the address is the base plus the counter itself
                        if ka == VZ_I { ka = VZ_IDX8; }
                        if kb == VZ_I { kb = VZ_IDX8; }
                    }
                    if ka == VZ_IDX8 && kb == VZ_INV { int tmp = ra; ra = rb; rb = tmp; int tk = ka; ka = kb; kb = tk; }
                    if ka == VZ_INV && kb == VZ_IDX8 && vz_base[ra] != 0 {
                        vz_kind[d] = VZ_ADDR; vz_base[d] = vz_base[ra]; vz_off[d] = vz_off[ra];
                    } else { return false; }
                }
                if emit && vz_kind[d] != VZ_ADDR { vz_clone(j2); }
            } else if op == IR_F32IN {
                int kx = vz_kind[ir_a[j2]];
                if (kx == VZ_WORD || kx == VZ_VWORD) && vz_w == 4 { vz_kind[d] = VZ_VEC; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if kx == VZ_INV { vz_kind[d] = VZ_DINV; if emit { vz_clone(j2); } }
                else { return false; }
            } else if op == IR_F32OUT {
                int kx2 = vz_kind[ir_a[j2]];
                if kx2 == VZ_VEC && vz_w == 4 { vz_kind[d] = VZ_VWORD; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if kx2 == VZ_DINV { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; if emit { vz_clone(j2); } }
                else { return false; }
            } else if op == IR_FCVT_DS {
                if vz_kind[ir_a[j2]] != VZ_DINV { return false; }
                vz_kind[d] = VZ_DINV;
                if emit { vz_clone(j2); }
            } else if op >= IR_FADD32 && op <= IR_FDIV32 {
                int ra7 = ir_a[j2];
                int rb7 = ir_b[j2];
                int ka7 = vz_kind[ra7];
                int kb7 = vz_kind[rb7];
                if (ka7 != VZ_VEC && ka7 != VZ_DINV) || (kb7 != VZ_VEC && kb7 != VZ_DINV) { return false; }
                if ka7 == VZ_VEC || kb7 == VZ_VEC {
                    if vz_w != 4 { return false; }
                    if !emit { vz_has_fp = 1; }
                    if emit {
                        int qa7 = 0;
                        int qb7 = 0;
                        if ka7 == VZ_VEC { qa7 = vz_vec[ra7]; }
                        else {
                            int xa7 = ir_vreg(0);
                            ir_add(IR_F32OUT, xa7, ra7, 0, 0, 0);
                            qa7 = vz_bcast(xa7);
                        }
                        if kb7 == VZ_VEC { qb7 = vz_vec[rb7]; }
                        else {
                            int xb7 = ir_vreg(0);
                            ir_add(IR_F32OUT, xb7, rb7, 0, 0, 0);
                            qb7 = vz_bcast(xb7);
                        }
                        int kk7 = op - IR_FADD32;
                        int qr7 = ir_vreg(2);
                        int ve7 = ir_add(IR_VOP, qr7, qa7, qb7, 0, kk7);
                        ir_w[ve7] = 2;
                        vz_vec[d] = qr7;
                    }
                    vz_kind[d] = VZ_VEC;
                } else {
                    vz_kind[d] = VZ_DINV;
                    if emit { vz_clone(j2); }
                }
            } else if op == IR_BITS2F {
                int ka2 = vz_kind[ir_a[j2]];
                if ka2 == VZ_WORD && vz_w != 8 { return false; }
                if ka2 == VZ_WORD { vz_kind[d] = VZ_VEC; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if ka2 == VZ_INV { vz_kind[d] = VZ_DINV; vz_dslot[d] = vz_lslot[ir_a[j2]]; if emit { vz_clone(j2); } }
                else { return false; }
            } else if op == IR_FCONST {
                vz_kind[d] = VZ_DINV;
                if emit { vz_clone(j2); }
            } else if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV {
                int ra3 = ir_a[j2];
                int rb3 = ir_b[j2];
                int ka3 = vz_kind[ra3];
                int kb3 = vz_kind[rb3];
                bool oka = ka3 == VZ_VEC || ka3 == VZ_DINV;
                bool okb = kb3 == VZ_VEC || kb3 == VZ_DINV;
                if !oka || !okb { return false; }
                if ka3 == VZ_VEC || kb3 == VZ_VEC {
                    if vz_w != 8 { return false; }
                    if !emit { vz_has_fp = 1; }
                    if !emit {
                        int hk = 0;
                        while hk < 2 {
                            int rr = ra3;
                            int kk2 = ka3;
                            if hk == 1 { rr = rb3; kk2 = kb3; }
                            if kk2 == VZ_DINV && vz_dslot[rr] >= 0 && vz_nhs < 16 {
                                int hx = 0;
                                bool have = false;
                                while hx < vz_nhs { if vz_hs[hx] == vz_dslot[rr] { have = true; } hx += 1; }
                                if !have { vz_hs[vz_nhs] = vz_dslot[rr]; vz_nhs += 1; }
                            }
                            hk += 1;
                        }
                    }
                    if emit {
                        int qa = 0;
                        int qb = 0;
                        if ka3 == VZ_VEC { qa = vz_vec[ra3]; }
                        else if vz_dslot[ra3] >= 0 && vz_hq_of(vz_dslot[ra3]) != 0 { qa = vz_hq_of(vz_dslot[ra3]); }
                        else if ra3 < 64 && vz_def[ra3] == 0 && vz_bq[ra3] != 0 { qa = vz_bq[ra3]; }
                        else {
                            int xa = ir_vreg(0);
                            ir_add(IR_F2BITS, xa, ra3, 0, 0, 0);
                            qa = ir_vreg(2);
                            int dupa = ir_add(IR_VDUP, qa, xa, 0, 0, 0);
                            ir_w[dupa] = 1;
                        }
                        if kb3 == VZ_VEC { qb = vz_vec[rb3]; }
                        else if vz_dslot[rb3] >= 0 && vz_hq_of(vz_dslot[rb3]) != 0 { qb = vz_hq_of(vz_dslot[rb3]); }
                        else if rb3 < 64 && vz_def[rb3] == 0 && vz_bq[rb3] != 0 { qb = vz_bq[rb3]; }
                        else {
                            int xb = ir_vreg(0);
                            ir_add(IR_F2BITS, xb, rb3, 0, 0, 0);
                            qb = ir_vreg(2);
                            int dupb = ir_add(IR_VDUP, qb, xb, 0, 0, 0);
                            ir_w[dupb] = 1;
                        }
                        int qr = ir_vreg(2);
                        int kk = 0;
                        if op == IR_FSUB { kk = 1; } else if op == IR_FMUL { kk = 2; } else if op == IR_FDIV { kk = 3; }
                        int ve = ir_add(IR_VOP, qr, qa, qb, 0, kk);
                        ir_w[ve] = 1;
                        vz_vec[d] = qr;
                    }
                    vz_kind[d] = VZ_VEC;
                } else {
                    vz_kind[d] = VZ_DINV;
                    if emit { vz_clone(j2); }
                }
            } else if op == IR_F2BITS {
                int ka4 = vz_kind[ir_a[j2]];
                if ka4 == VZ_VEC && vz_w != 8 { return false; }
                if ka4 == VZ_VEC { vz_kind[d] = VZ_VWORD; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if ka4 == VZ_DINV { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; if emit { vz_clone(j2); } }
                else { return false; }
            } else if op == IR_STORE && ir_a[j2] == 30 && ir_w[j2] == 8 && ir_bi[j2] == 0 && vn_slot(j2) >= 0 && vz_kind[ir_b[j2]] == VZ_ACCN {
                // the new value of the accumulator goes to the slot after the loop: nothing is written in the vector loop
                if vz_lslot[ir_b[j2]] != vn_slot(j2) { return false; }
            } else if op == IR_STORE {
                if vz_iabs(ir_w[j2]) != vz_w || ir_bi[j2] != 0 { return false; }
                if vz_kind[ir_a[j2]] != VZ_ADDR { return false; }
                int kv = vz_kind[ir_b[j2]];
                if kv != VZ_VWORD && kv != VZ_WORD && kv != VZ_INV { return false; }
                if vz_nacc >= 64 { return false; }
                vz_acc_base[vz_nacc] = vz_base[ir_a[j2]];
                vz_acc_off[vz_nacc] = vz_off[ir_a[j2]] + ir_k[j2];
                vz_acc_st[vz_nacc] = 1;
                vz_nacc += 1;
                if emit {
                    int qs = 0;
                    if kv == VZ_VWORD || kv == VZ_WORD { qs = vz_vec[ir_b[j2]]; }
                    else {
                        qs = vz_bcast(ir_b[j2]);
                    }
                    int spt = vz_ptr(vz_base[ir_a[j2]], vz_off[ir_a[j2]] + ir_k[j2]);
                    int se = ir_add(IR_STORE, 0, spt, qs, 0, vz_shift + vz_kadd);
                    ir_w[se] = 16;
                }
            } else {
                return false;
            }
            j2 += 1;
        }
        c += 1;
    }
    // the accesses must not get in each other's way
    int x = 0;
    while x < vz_nacc {
        int y = 0;
        while y < vz_nacc {
            if x != y && (vz_acc_st[x] == 1 || vz_acc_st[y] == 1) && vz_acc_base[x] == vz_acc_base[y] {
                int dd = vz_acc_off[x] - vz_acc_off[y];
                if dd < 0 { dd = 0 - dd; }
                if dd != 0 && dd < 16 { return false; }
            }
            y += 1;
        }
        x += 1;
    }
    // at least one store, or an accumulator
    bool st = vz_nacc2 > 0;
    int w = 0;
    while w < vz_nacc { if vz_acc_st[w] == 1 { st = true; } w += 1; }
    return st;
}

// the live-in doubles that a vector operation reads: broadcast once in the block being written (VP)
void vz_hoist(int q) {
    int c = 0;
    while c < vz_nchain {
        int b = vz_chain[c];
        int j = ir_bs[b];
        while j < ir_be[b] - 1 {
            int op = ir_op[j];
            if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV {
                int k = 0;
                while k < 2 {
                    int r = ir_a[j];
                    if k == 1 { r = ir_b[j]; }
                    if r >= 32 && r < 64 && vz_def[r] == 0 && vz_bq[r] == 0 && ir_vcls[r] == 1 {
                        int xv = ir_vreg(0);
                        ir_add(IR_F2BITS, xv, r, 0, 0, 0);
                        int qv = ir_vreg(2);
                        int dp = ir_add(IR_VDUP, qv, xv, 0, 0, 0);
                        ir_w[dp] = 1;
                        vz_bq[r] = qv;
                    }
                    k += 1;
                }
            }
            j += 1;
        }
        c += 1;
    }
}

// ---- what does not change from one turn to the next goes in front of the vector loop
// The vector body reuses the registers of the scalar body (v1 .. v14), so the general LICM cannot move anything out of it. Here the
// body is renamed (every register that is written before it is read gets a new name at each write), then the instructions that
// read only registers the body does not write, or the results of such instructions, are moved into a new block that runs once:
// the broadcast of `k`, the float `2.0`, the loads of the slots that the body does not write.
int vz_rn_to[IR_MAXV];
int vz_rn_st[IR_MAXV];
int vz_rn_stamp;
int vz_inv_def[IR_MAXV];        // stamp: written in the body (after renaming), and the instruction is moved
int vz_wr_st[IR_MAXV];          // stamp: written in the body
int vz_rd_first[IR_MAXV];       // stamp: read before it is written
int vz_hoisted_n;

int vz_rename_of(int v) {
    if v > 0 && v < IR_MAXV && vz_rn_st[v] == vz_rn_stamp { return vz_rn_to[v]; }
    return v;
}

bool vz_hoistable_op(int op) {
    if op == IR_CONST || op == IR_FCONST || op == IR_COPY || op == IR_F32IN || op == IR_F32OUT || op == IR_FCVT_DS || op == IR_FCVT_SD { return true; }
    if op == IR_BITS2F || op == IR_F2BITS || op == IR_VDUP || op == IR_VOP || op == IR_EXT || op == IR_NEG || op == IR_NOT { return true; }
    if op >= IR_ADD && op <= IR_ASHR { return op != IR_SDIV && op != IR_UDIV; }
    if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV { return true; }
    if op >= IR_FADD32 && op <= IR_FDIV32 { return true; }
    return false;
}

// vb: the vector body (complete, the last instruction is its branch), vh0: its entry
// returns the number of instructions moved
int vz_licm(int vb, int br0) {
    int s = ir_bs[vb];
    int e = ir_n - 1;
    if e <= s { return 0; }
    vz_rn_stamp += 1;
    // 1. which registers are read before they are written
    int j = s;
    while j <= e {
        int op = ir_op[j];
        if op != IR_NOP {
            if ir_a[j] > 0 && ir_a[j] < IR_MAXV && vz_wr_st[ir_a[j]] != vz_rn_stamp { vz_rd_first[ir_a[j]] = vz_rn_stamp; }
            if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 && ir_b[j] < IR_MAXV && vz_wr_st[ir_b[j]] != vz_rn_stamp { vz_rd_first[ir_b[j]] = vz_rn_stamp; }
            if ir_d[j] > 0 && ir_d[j] < IR_MAXV { vz_wr_st[ir_d[j]] = vz_rn_stamp; }
        }
        j += 1;
    }
    // 2. the renaming: a register that is not carried gets a new name at every write
    j = s;
    while j <= e {
        int op = ir_op[j];
        if op != IR_NOP {
            if ir_a[j] > 0 { ir_a[j] = vz_rename_of(ir_a[j]); }
            if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 { ir_b[j] = vz_rename_of(ir_b[j]); }
            int d = ir_d[j];
            if d > 0 && d < IR_MAXV && d != 29 && d != 30 && vz_rd_first[d] != vz_rn_stamp {
                int nv = ir_vreg(ir_vcls[d]);
                vz_rn_to[d] = nv;
                vz_rn_st[d] = vz_rn_stamp;
                ir_d[j] = nv;
                if nv > 0 && nv < IR_MAXV { vz_wr_st[nv] = vz_rn_stamp; vz_rd_first[nv] = 0; }
            }
        }
        j += 1;
    }
    // the frame bytes that the body writes
    int nst = 0;
    int sk[64];
    j = s;
    while j <= e {
        if ir_op[j] == IR_STORE && ir_a[j] == 30 && nst < 64 { sk[nst] = ir_k[j]; nst += 1; }
        if ir_op[j] == IR_STORE && ir_a[j] != 30 && ir_w[j] != 16 { return 0; }
        if ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL { return 0; }
        j += 1;
    }
    // 3. what can go: the instruction reads nothing that the body writes except the results of instructions that go
    int moved[512];
    int nm = 0;
    int stamp2 = vz_rn_stamp;
    j = s;
    while j < e {
        int op = ir_op[j];
        int d = ir_d[j];
        bool can = false;
        if op != IR_NOP && d > 0 && d < IR_MAXV && vz_rd_first[d] != stamp2 && nm < 500 {
            if vz_hoistable_op(op) { can = true; }
            if op == IR_LOAD && ir_a[j] == 30 && ir_bi[j] == 0 && ir_w[j] != 16 {
                can = true;
                int z = 0;
                while z < nst { if sk[z] < ir_k[j] + 8 && sk[z] + 8 > ir_k[j] { can = false; } z += 1; }
            }
        }
        if can && ir_a[j] > 0 && ir_a[j] < IR_MAXV && vz_wr_st[ir_a[j]] == stamp2 && vz_inv_def[ir_a[j]] != stamp2 { can = false; }
        if can && ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 && ir_b[j] < IR_MAXV && vz_wr_st[ir_b[j]] == stamp2 && vz_inv_def[ir_b[j]] != stamp2 { can = false; }
        // a register that is written once only (after the renaming) and not carried
        if can {
            moved[nm] = j;
            nm += 1;
            vz_inv_def[d] = stamp2;
        }
        j += 1;
    }
    if nm == 0 { return 0; }
    // a scalar result may be used by moved instructions only (the register pass does not keep a scalar across blocks); a vector may
    // be used in the body
    int flagged[512];
    if nm > 0 {
        int fi = 0;
        while fi < nm { flagged[fi] = 1; fi += 1; }
        bool again = true;
        while again {
            again = false;
            fi = 0;
            while fi < nm {
                if flagged[fi] == 1 {
                    int fj = moved[fi];
                    int fd = ir_d[fj];
                    bool ok = true;
                    // an operand that was in the list but is not any more
                    int oa = ir_a[fj];
                    if oa > 0 && oa < IR_MAXV && vz_wr_st[oa] == stamp2 && vz_inv_def[oa] != stamp2 { ok = false; }
                    if ir_uses_b(ir_op[fj]) && ir_bi[fj] == 0 {
                        int ob = ir_b[fj];
                        if ob > 0 && ob < IR_MAXV && vz_wr_st[ob] == stamp2 && vz_inv_def[ob] != stamp2 { ok = false; }
                    }
                    if ok && ir_vcls[fd] != 2 {
                        // the readers that stay in the body
                        int rj = s;
                        while rj <= e && ok {
                            if ir_op[rj] != IR_NOP {
                                bool is_moved = false;
                                int mi = 0;
                                while mi < nm { if moved[mi] == rj && flagged[mi] == 1 { is_moved = true; } mi += 1; }
                                if !is_moved {
                                    if ir_a[rj] == fd { ok = false; }
                                    if ir_uses_b(ir_op[rj]) && ir_bi[rj] == 0 && ir_b[rj] == fd { ok = false; }
                                }
                            }
                            rj += 1;
                        }
                    }
                    if !ok {
                        flagged[fi] = 0;
                        vz_inv_def[fd] = 0;
                        again = true;
                    }
                }
                fi += 1;
            }
        }
        // keep the flagged ones only
        int kn = 0;
        fi = 0;
        while fi < nm {
            if flagged[fi] == 1 { moved[kn] = moved[fi]; kn += 1; }
            fi += 1;
        }
        nm = kn;
        if nm == 0 { return 0; }
    }
    // the registers that the moved instructions write must be written there only: the renaming made them unique unless a register
    // was read before its first write in the body (then it was not renamed and cannot be here: vz_rd_first)
    // the same value computed twice (the two chunks of the body): the second one is dropped, its uses read the first
    int dup_of[512];
    int du = 0;
    while du < nm {
        dup_of[du] = 0 - 1;
        int dj = moved[du];
        int dv = 0;
        while dv < du && dup_of[du] < 0 {
            int vj = moved[dv];
            if dup_of[dv] < 0 && ir_op[vj] == ir_op[dj] && ir_a[vj] == ir_a[dj] && ir_bi[vj] == ir_bi[dj] && ir_k[vj] == ir_k[dj] && ir_w[vj] == ir_w[dj] && (ir_bi[dj] == 1 || !ir_uses_b(ir_op[dj]) || ir_b[vj] == ir_b[dj]) && ir_vcls[ir_d[vj]] == ir_vcls[ir_d[dj]] {
                dup_of[du] = vj;
                // every use of the dropped register reads the first one
                int old_r = ir_d[dj];
                int new_r = ir_d[vj];
                int uj = s;
                while uj <= e {
                    if ir_op[uj] != IR_NOP {
                        if ir_a[uj] == old_r { ir_a[uj] = new_r; }
                        if ir_uses_b(ir_op[uj]) && ir_bi[uj] == 0 && ir_b[uj] == old_r { ir_b[uj] = new_r; }
                    }
                    uj += 1;
                }
            }
            dv += 1;
        }
        du += 1;
    }
    // 4. the new block, that runs once between the test and the body
    int vk = ir_new_block(0 - 1);
    ir_set_block(vk);
    int u = 0;
    while u < nm {
        int jj = moved[u];
        if dup_of[u] >= 0 {
            ir_op[jj] = IR_NOP;
            ir_d[jj] = 0;
            ir_a[jj] = 0;
            ir_bi[jj] = 1;
            u += 1;
            continue;
        }
        int ne = ir_add(ir_op[jj], ir_d[jj], ir_a[jj], ir_b[jj], ir_bi[jj], ir_k[jj]);
        ir_w[ne] = ir_w[jj];
        ir_op[jj] = IR_NOP;
        ir_d[jj] = 0;
        ir_a[jj] = 0;
        ir_bi[jj] = 1;
        u += 1;
    }
    int jk = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jk] = vb;
    ir_t1[br0] = vk;
    vz_hoisted_n += nm;
    return nm;
}

bool vz_make(int q, int l) {
    int h = cl_head[q];
    int islot = cl_slot[q];
    // the blocks of the loop other than the header must be one chain from the body to the block that jumps back
    op_mark_loop(l);
    int stamp = op_stamp;
    int total = 0;
    int b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && op_mark[b] == stamp { total += 1; }
        b += 1;
    }
    vz_nchain = 0;
    int cur = cl_body[q];
    while cur != h {
        if op_mark[cur] != stamp || vz_nchain >= 250 { return false; }
        int tt = ir_be[cur] - 1;
        if ir_op[tt] != IR_JMP { return false; }
        vz_chain[vz_nchain] = cur;
        vz_nchain += 1;
        cur = ir_t1[tt];
    }
    if vz_nchain + 1 != total || vz_nchain == 0 { return false; }
    // the header: loads and the branch only
    int j = ir_bs[h];
    while j < ir_be[h] - 1 {
        if ir_op[j] != IR_LOAD && ir_op[j] != IR_NOP && ir_op[j] != IR_CONST { return false; }
        j += 1;
    }
    // the step of the counter: the three instructions load, add, store at the end of the last block
    int lastb = vz_chain[vz_nchain - 1];
    int e = ir_be[lastb] - 2;
    while e >= ir_bs[lastb] && ir_op[e] == IR_NOP { e -= 1; }
    int inch = e;
    if inch < ir_bs[lastb] || ir_op[inch] != IR_STORE || ir_a[inch] != 30 || vn_slot(inch) != islot || ir_bi[inch] != 0 { return false; }
    int ad = rn_find_def(lastb, inch, ir_b[inch]);
    if ad < 0 || ir_op[ad] != IR_ADD || ir_bi[ad] != 1 || ir_b[ad] != 1 { return false; }
    int ld = rn_find_def(lastb, ad, ir_a[ad]);
    if ld < 0 || ir_op[ld] != IR_LOAD || ir_a[ld] != 30 || vn_slot(ld) != islot { return false; }
    // between the load and the store only the add (and nops)
    int m = ld + 1;
    while m < inch {
        if m != ad && ir_op[m] != IR_NOP { return false; }
        m += 1;
    }
    if !vz_scan(q, islot, ld, inch, false) { return false; }
    // doubles: `-irdbg 536870912` keeps them scalar (0.9.128 did that by default, from a measurement of a poor vector loop: 320 against
    // 308 ms; with pointers and one branch for each turn the vector loop is 106 ms against 297 ms)
    if vz_has_fp == 1 && (ir_opt & 536870912) != 0 { return false; }
    vz_npk = 0;
    {
        int ak = 0;
        while ak < vz_nacc {
            if vz_pk_find(vz_acc_base[ak], vz_acc_off[ak], true) < 0 { return false; }
            ak += 1;
        }
    }
    // the registers the body writes must not be needed after the loop (the original header runs once more and writes its own)
    int ex = cl_exit[q];
    int c = 0;
    while c < vz_nchain {
        int jj = ir_bs[vz_chain[c]];
        while jj < ir_be[vz_chain[c]] - 1 {
            int dr = ir_d[jj];
            if dr > 0 && dr < 64 && ir_op[jj] != IR_NOP {
                bool in_header = false;
                int hj = ir_bs[h];
                while hj < ir_be[h] { if ir_d[hj] == dr { in_header = true; } hj += 1; }
                if !in_header && (op_li[ex] & (1 << dr)) != 0 { return false; }
                if (op_li[h] & (1 << dr)) != 0 && vz_kind[dr] != 0 { }
            }
            jj += 1;
        }
        c += 1;
    }
    // the new blocks: VP (once: the broadcasts, the limit n - 1 into a stack cell), VH (the test of every turn), VB (the body)
    int qcell = 0 - (op_maxq() + 8);
    int boff = vz_slot_off(cl_bval[q]);
    int vp = ir_new_block(0 - 1);
    ir_set_block(vp);
    // the doubles that the body reads and does not write: made into vectors once
    {
        int u = 0;
        while u < 64 { vz_bq[u] = 0; u += 1; }
    }
    int vbnd = ir_vreg(0);
    int br_guard = 0 - 1;
    int vpb = 0 - 1;
    if cl_bkind[q] == 0 {
        ir_add(IR_CONST, vbnd, 0, 0, 0, cl_bval[q]);
    } else {
        int lb = ir_add(IR_LOAD, vbnd, 30, 0, 0, 0);
        ir_w[lb] = 8;
        ir_k[lb] = boff;
    }
    // n - 1 must not wrap: the smallest number (0 for an unsigned compare) skips the vector loop
    int vlim = ir_vreg(0);
    int vmin = ir_vreg(0);
    int minv = 0;
    int gcc = IR_ULT;
    int nchunks = 4;                             // 16-byte chunks in one turn of the vector loop
    if vz_w == 1 { nchunks = 2; }
    int per_turn = 16 * nchunks / vz_w;          // elements in one turn
    if cl_cc[q] == IR_LT { minv = (1 << 63) + per_turn - 1; gcc = IR_LT; } else { minv = per_turn - 1; }
    ir_add(IR_CONST, vmin, 0, 0, 0, minv);
    br_guard = ir_add(IR_BR, 0, vbnd, vmin, 0, gcc);
    vpb = ir_new_block(0 - 1);
    ir_set_block(vpb);
    // the broadcasts (the registers of the loop's doubles are live in here)
    vz_hoist(q);
    {
        int hu = 0;
        while hu < vz_nhs {
            int hx = ir_vreg(0);
            int hl = ir_add(IR_LOAD, hx, 30, 0, 0, 0);
            ir_w[hl] = 8;
            ir_k[hl] = vz_slot_off(vz_hs[hu]);
            int hqv = ir_vreg(2);
            int hd = ir_add(IR_VDUP, hqv, hx, 0, 0, 0);
            ir_w[hd] = 1;
            vz_hq[hu] = hqv;
            hu += 1;
        }
        int au = 0;
        while au < vz_nacc2 {
            int zx = ir_vreg(0);
            ir_add(IR_CONST, zx, 0, 0, 0, 0);
            int zch = 0;
            while zch < nchunks {
                int zq = ir_vreg(2);
                int zd = ir_add(IR_VDUP, zq, zx, 0, 0, 0);
                ir_w[zd] = 1;
                vz_acc_q[au * 4 + zch] = zq;
                zch += 1;
            }
            au += 1;
        }
    }
    int vbnd2 = ir_vreg(0);
    if cl_bkind[q] == 0 {
        ir_add(IR_CONST, vbnd2, 0, 0, 0, cl_bval[q]);
    } else {
        int lb2 = ir_add(IR_LOAD, vbnd2, 30, 0, 0, 0);
        ir_w[lb2] = 8;
        ir_k[lb2] = boff;
    }
    ir_add(IR_ADD, vlim, vbnd2, 0 - (per_turn - 1), 1, 0);
    int stl = ir_add(IR_STORE, 0, 30, vlim, 0, qcell);
    ir_w[stl] = 8;
    // the pointers: base + 8 * i + offset at the start, one cell each
    {
        int pu = 0;
        while pu < vz_npk {
            vz_pk_cell[pu] = qcell - 8 * (pu + 1);
            int ti0 = ir_vreg(0);
            int li0 = ir_add(IR_LOAD, ti0, 30, 0, 0, 0);
            ir_w[li0] = 8;
            ir_k[li0] = vz_slot_off(cl_slot[q]);
            int sh0 = ir_vreg(0);
            if vz_lg == 0 { ir_add(IR_COPY, sh0, ti0, 0, 0, 0); } else { ir_add(IR_SHL, sh0, ti0, vz_lg, 1, 0); }
            int pa = ir_vreg(0);
            ir_add(IR_ADD, pa, vz_pk_base[pu], sh0, 0, 0);
            int pb = ir_vreg(0);
            ir_add(IR_ADD, pb, pa, vz_pk_off[pu], 1, 0);
            int sp0 = ir_add(IR_STORE, 0, 30, pb, 0, vz_pk_cell[pu]);
            ir_w[sp0] = 8;
            pu += 1;
        }
    }
    int jpb = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    int vh0 = ir_new_block(0 - 1);
    ir_t1[jpb] = vh0;
    ir_set_block(vh0);
    int t0 = ir_vreg(0);
    int t1 = ir_vreg(0);
    {
        int la = ir_add(IR_LOAD, t0, 30, 0, 0, 0);
        ir_w[la] = 8;
        ir_k[la] = vz_slot_off(cl_slot[q]);
        int lc = ir_add(IR_LOAD, t1, 30, 0, 0, 0);
        ir_w[lc] = 8;
        ir_k[lc] = qcell;
    }
    int br0 = ir_add(IR_BR, 0, t0, t1, 0, cl_cc[q]);
    int vb = ir_new_block(0 - 1);
    ir_t1[br0] = vb;
    ir_t2[br0] = h;
    ir_t1[br_guard] = h;
    ir_t2[br_guard] = vpb;
    // the vector body
    ir_set_block(vb);
    {
        int chunk = 0;
        while chunk < nchunks {
            vz_shift = chunk * 16;
            vz_ab29 = 0;
            vz_ab30 = 0;
            vz_ti = ir_vreg(0);
            int lti = ir_add(IR_LOAD, vz_ti, 30, 0, 0, 0);
            ir_w[lti] = 8;
            ir_k[lti] = ir_k[ld];
            vz_scan(q, islot, ld, inch, true);
            chunk += 1;
        }
        vz_shift = 0;
    }
    // the pointers move on by four elements
    {
        int pv = 0;
        while pv < vz_npk {
            int pcur = ir_vreg(0);
            int lc0 = ir_add(IR_LOAD, pcur, 30, 0, 0, 0);
            ir_w[lc0] = 8;
            ir_k[lc0] = vz_pk_cell[pv];
            int pnext = ir_vreg(0);
            ir_add(IR_ADD, pnext, pcur, 16 * nchunks, 1, 0);
            int sc0 = ir_add(IR_STORE, 0, 30, pnext, 0, vz_pk_cell[pv]);
            ir_w[sc0] = 8;
            pv += 1;
        }
    }
    // i = i + 4
    {
        int tk = ir_vreg(0);
        int lk = ir_add(IR_LOAD, tk, 30, 0, 0, 0);
        ir_w[lk] = 8;
        ir_k[lk] = ir_k[ld];
        int tj = ir_vreg(0);
        ir_add(IR_ADD, tj, tk, per_turn, 1, 0);
        int si = ir_add(IR_STORE, 0, 30, tj, 0, ir_k[ld]);
        ir_w[si] = 8;
        // the test at the bottom: one branch for each turn
        int tlim = ir_vreg(0);
        int lq = ir_add(IR_LOAD, tlim, 30, 0, 0, 0);
        ir_w[lq] = 8;
        ir_k[lq] = qcell;
        vz_br_end = ir_add(IR_BR, 0, tj, tlim, 0, cl_cc[q]);
        ir_t1[vz_br_end] = vb;
        ir_t2[vz_br_end] = h;
    }
    // what does not change from turn to turn is made once, in front of the body
    vz_licm(vb, br0);
    // the exit of the vector loop: the two partial sums of every accumulator are added to its slot
    if vz_nacc2 > 0 {
        int vx = ir_new_block(0 - 1);
        ir_set_block(vx);
        int au2 = 0;
        while au2 < vz_nacc2 {
            // two temporaries at a time (the lowering has few scratch registers): slot + lane 0, then + lane 1
            int ov = ir_vreg(0);
            int lo = ir_add(IR_LOAD, ov, 30, 0, 0, 0);
            ir_w[lo] = 8;
            ir_k[lo] = vz_slot_off(vz_acc_slot[au2]);
            int run = ov;
            int xch = 0;
            while xch < nchunks {
                int l0 = ir_vreg(0);
                int e0 = ir_add(IR_VLANE, l0, vz_acc_q[au2 * 4 + xch], 0, 0, 0);
                ir_w[e0] = 8;
                int s1 = ir_vreg(0);
                ir_add(IR_ADD, s1, run, l0, 0, 0);
                int l1 = ir_vreg(0);
                int e1 = ir_add(IR_VLANE, l1, vz_acc_q[au2 * 4 + xch], 0, 0, 8);
                ir_w[e1] = 8;
                int s2 = ir_vreg(0);
                ir_add(IR_ADD, s2, s1, l1, 0, 0);
                run = s2;
                xch += 1;
            }
            int so = ir_add(IR_STORE, 0, 30, run, 0, 0);
            ir_w[so] = 8;
            ir_k[so] = vz_slot_off(vz_acc_slot[au2]);
            au2 += 1;
        }
        int jx = ir_add(IR_JMP, 0, 0, 0, 0, 0);
        ir_t1[jx] = h;
        ir_t2[br0] = vx;
        ir_t2[vz_br_end] = vx;
    }
    // the jumps into the header from outside the loop go to VP
    int nb0 = vp;
    op_mark_loop(l);
    int bb = 0;
    while bb < nb0 {
        if op_mark[bb] != op_stamp && op_po[bb] >= 0 {
            int tb = ir_be[bb] - 1;
            int top = ir_op[tb];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[tb] == h { ir_t1[tb] = vp; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[tb] == h { ir_t2[tb] = vp; }
        }
        bb += 1;
    }
    ir_nofma_fn = 1;
    nofma_add(@ir_fname);
    vz_count += 1;
    return true;
}

void op_vectorize() {
    if opt_debug == 1 { return; }
    op_counted_loops();
    if cl_n == 0 { return; }
    int nl = cl_n;
    int heads[CL_MAX];
    int q = 0;
    while q < nl { heads[q] = cl_head[q]; q += 1; }
    q = 0;
    while q < nl {
        // the loop descriptors can move when blocks are added: look the loop up again by its header
        bool fine = cl_inner[q] == 1 && cl_calls[q] == 0 && cl_step[q] == 1 && (cl_cc[q] == IR_LT || cl_cc[q] == IR_ULT);
        if fine {
            int l = 0;
            while l < op_nloops && op_lh[l] != heads[q] { l += 1; }
            if l < op_nloops {
                vz_tried += 1;
                if (ir_opt & 536870912) != 0 { }
                vz_make(q, l);
            }
        }
        q += 1;
    }
}

// ---------------------------------------------------------------------------------------------- strength reduction of array addresses
// In a counted loop, the address `base + f * i + c` of an array element (the base: the global area, the frame, or a pointer kept in a plain
// slot that the loop does not write; f: 8 for `a[i]`, the size of the struct for `b[i].x`) is computed again at every turn from the
// counter. Here it becomes a pointer in a stack cell: made in a new block in front of the loop from the counter, moved on by f * step in
// a new block that the step of the counter falls into. The register pass keeps the cells in registers; the address of an access is then a
// register (`ldr d0, [x19, #8]`), and the instructions that made it are dead.

#define SS_MAXK 24
#define SS_MAXP 64
int ss_kf[SS_MAXK];              // the scale
int ss_kbase[SS_MAXK];           // 29 the global area, 30 the frame, 1000 + k: the plain slot at the frame offset k (a pointer)
int ss_koff[SS_MAXK];
int ss_kcell[SS_MAXK];
int ss_nk;
int ss_pj[SS_MAXP];              // the instructions to become `load pointer`, and their keys
int ss_pk[SS_MAXP];
int ss_np;
int ss_kind[IR_MAXV];            // 1 the counter, 2 f * i, 3 a number, 4 an invariant pointer (base + c), 5 base + f * i + c
int ss_f[IR_MAXV];
int ss_base[IR_MAXV];
int ss_off[IR_MAXV];
int ss_stampv[IR_MAXV];
int ss_prodv[IR_MAXV];           // kind 5: the instruction that made it (-1: not a producer that is changed)
int ss_stamp;
int ss_lst[16384];               // slots written in the loop
int ss_total;                    // all functions
int ss_nb0;                      // the blocks the function had before the loops were changed

int ss_get(int v) {
    if v <= 0 || v >= IR_MAXV || ss_stampv[v] != ss_stamp { return 0; }
    return ss_kind[v];
}

void ss_set(int v, int kind, int f, int base, int off) {
    if v <= 0 || v >= IR_MAXV { return; }
    ss_stampv[v] = ss_stamp;
    ss_kind[v] = kind;
    ss_f[v] = f;
    ss_base[v] = base;
    ss_off[v] = off;
    ss_prodv[v] = 0 - 1;
}

int ss_key(int f, int base, int off) {
    int u = 0;
    while u < ss_nk {
        if ss_kf[u] == f && ss_kbase[u] == base && ss_koff[u] == off { return u; }
        u += 1;
    }
    if ss_nk >= SS_MAXK { return 0 - 1; }
    ss_kf[ss_nk] = f;
    ss_kbase[ss_nk] = base;
    ss_koff[ss_nk] = off;
    ss_nk += 1;
    return ss_nk - 1;
}

// scan one block of the loop; the producers that an access uses are collected
void ss_block(int b, int islot) {
    ss_stamp += 1;
    int j = ir_bs[b];
    while j < ir_be[b] - 1 {
        int op = ir_op[j];
        int d = ir_d[j];
        if op == IR_NOP { j += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            ss_stamp += 1;
            j += 1;
            continue;
        }
        // a use of a changed address: the instruction that made it needs the pointer
        if (op == IR_LOAD || op == IR_STORE) && ir_a[j] > 0 && ss_get(ir_a[j]) == 5 && ss_prodv[ir_a[j]] >= 0 && ss_np < SS_MAXP {
            int pr = ss_prodv[ir_a[j]];
            int k = ss_key(ss_f[ir_a[j]], ss_base[ir_a[j]], ss_off[ir_a[j]]);
            bool known = false;
            int u = 0;
            while u < ss_np { if ss_pj[u] == pr { known = true; } u += 1; }
            if k >= 0 && !known {
                ss_pj[ss_np] = pr;
                ss_pk[ss_np] = k;
                ss_np += 1;
            }
        }
        if d <= 0 || ir_vcls[d] != 0 {
            if op == IR_STORE { j += 1; continue; }
            if d > 0 { ss_set(d, 0, 0, 0, 0); }
            j += 1;
            continue;
        }
        int nk = 0;
        int nf = 0;
        int nb = 0;
        int no = 0;
        int a = ir_a[j];
        int ka = ss_get(a);
        if op == IR_LOAD && ir_w[j] == 8 && a == 30 {
            int sl = vn_slot(j);
            if sl == islot { nk = 1; nf = 1; }
            else if sl >= 0 && sl < 8192 && ss_lst[sl] == 0 && op_plain[sl] == 1 { nk = 4; nb = 1000 + sl * 8; }
        } else if op == IR_CONST {
            nk = 3; no = ir_k[j];
        } else if op == IR_COPY && ka != 0 {
            nk = ka; nf = ss_f[a]; nb = ss_base[a]; no = ss_off[a];
        } else if op == IR_SHL && ir_bi[j] == 1 && ka == 1 && ir_b[j] >= 0 && ir_b[j] <= 12 {
            nk = 2; nf = 1 << ir_b[j];
        } else if op == IR_MUL && ka == 1 {
            // i * number (the number a constant register or an immediate)
            int mv = 0;
            bool have = false;
            if ir_bi[j] == 1 { mv = ir_b[j]; have = true; }
            else if ss_get(ir_b[j]) == 3 { mv = ss_off[ir_b[j]]; have = true; }
            if have && mv > 0 && mv <= 4096 { nk = 2; nf = mv; }
        } else if op == IR_ADD && ir_bi[j] == 1 && (a == 29 || a == 30) {
            nk = 4; nb = a; no = ir_b[j];
        } else if op == IR_ADD {
            int kb = 0;
            int bv = 0;
            int rb = 0;
            if ir_bi[j] == 1 { kb = 3; bv = ir_b[j]; } else { rb = ir_b[j]; kb = ss_get(rb); if kb == 3 { bv = ss_off[rb]; } }
            if ka == 4 && kb == 3 { nk = 4; nb = ss_base[a]; no = ss_off[a] + bv; }
            else if ka == 5 && kb == 3 { nk = 5; nf = ss_f[a]; nb = ss_base[a]; no = ss_off[a] + bv; }
            else if ka == 2 && kb == 4 { nk = 5; nf = ss_f[a]; nb = ss_base[rb]; no = ss_off[rb]; }
            else if ka == 4 && kb == 2 { nk = 5; nf = ss_f[rb]; nb = ss_base[a]; no = ss_off[a]; }
            else if ka == 4 && kb == 0 && a == 29 { nk = 0; }
        }
        // the global area and the frame are pointers
        if op == IR_ADD && ir_bi[j] == 0 {
            int xa = ir_a[j];
            int xb = ir_b[j];
            int kxa = ss_get(xa);
            int kxb = ss_get(xb);
            if xa == 29 && kxb == 2 { nk = 5; nf = ss_f[xb]; nb = 29; no = 0; }
            else if xb == 29 && kxa == 2 { nk = 5; nf = ss_f[xa]; nb = 29; no = 0; }
            else if xa == 30 && kxb == 2 { nk = 5; nf = ss_f[xb]; nb = 30; no = 0; }
            else if xb == 30 && kxa == 2 { nk = 5; nf = ss_f[xa]; nb = 30; no = 0; }
        }
        ss_set(d, nk, nf, nb, no);
        if nk == 5 { ss_prodv[d] = j; }
        j += 1;
    }
}

bool ss_loop(int q) {
    int h = cl_head[q];
    int l = cl_lidx[q];
    int islot = cl_slot[q];
    int stb = cl_stb[q];
    int sti = cl_sti[q];
    if cl_step[q] < 1 || cl_step[q] > 64 { return false; }
    // the step of the counter is the last instruction of its block (nops and the jump after it), and the block jumps to the header
    int t = ir_be[stb] - 1;
    if ir_op[t] != IR_JMP || ir_t1[t] != h { return false; }
    int m = sti + 1;
    while m < t {
        if ir_op[m] != IR_NOP { return false; }
        m += 1;
    }
    op_mark_loop(l);
    int stamp = op_stamp;
    // the slots that the loop writes
    int zi = 0;
    while zi < 16384 { ss_lst[zi] = 0; zi += 1; }
    int b = 0;
    while b < ss_nb0 {
        if op_po[b] >= 0 && op_mark[b] == stamp {
            int j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] == IR_STORE && ir_a[j] == 30 {
                    int s2 = vn_slot(j);
                    if s2 >= 0 && s2 < 16384 { ss_lst[s2] = 1; }
                    else if ir_k[j] >= 0 && ir_k[j] / 8 < 16384 { ss_lst[ir_k[j] / 8] = 1; }
                }
                j += 1;
            }
        }
        b += 1;
    }
    ss_nk = 0;
    ss_np = 0;
    b = 0;
    int nb0 = ss_nb0;
    while b < nb0 {
        if op_po[b] >= 0 && op_mark[b] == stamp && b != h { ss_block(b, islot); }
        b += 1;
    }
    if ss_np == 0 { return false; }
    // cells
    int cellbase = 0 - (op_maxq() + 8);
    int u = 0;
    while u < ss_nk {
        ss_kcell[u] = cellbase - 8 * u;
        u += 1;
    }
    // the instructions become loads of the pointers
    u = 0;
    while u < ss_np {
        int pj = ss_pj[u];
        ir_op[pj] = IR_LOAD;
        ir_a[pj] = 30;
        ir_b[pj] = 0;
        ir_bi[pj] = 0;
        ir_k[pj] = ss_kcell[ss_pk[u]];
        ir_w[pj] = 8;
        u += 1;
    }
    // the block in front of the loop: the pointers from the counter
    int pre = ir_new_block(0 - 1);
    ir_set_block(pre);
    u = 0;
    while u < ss_nk {
        int ti = ir_vreg(0);
        int li = ir_add(IR_LOAD, ti, 30, 0, 0, 0);
        ir_w[li] = 8;
        ir_k[li] = vz_slot_off(islot);
        int cur = ti;
        if ss_kf[u] != 1 {
            int tm = ir_vreg(0);
            if ss_kf[u] == 2 || ss_kf[u] == 4 || ss_kf[u] == 8 || ss_kf[u] == 16 || ss_kf[u] == 32 || ss_kf[u] == 64 || ss_kf[u] == 128 || ss_kf[u] == 256 || ss_kf[u] == 512 || ss_kf[u] == 1024 || ss_kf[u] == 2048 || ss_kf[u] == 4096 {
                int sh = 0;
                while (1 << sh) != ss_kf[u] { sh += 1; }
                ir_add(IR_SHL, tm, ti, sh, 1, 0);
            } else {
                int cf = ir_vreg(0);
                ir_add(IR_CONST, cf, 0, 0, 0, ss_kf[u]);
                ir_add(IR_MUL, tm, ti, cf, 0, 0);
            }
            cur = tm;
        }
        int tb = ir_vreg(0);
        if ss_kbase[u] >= 1000 {
            // the pointer in the plain slot at the frame offset kbase - 1000
            int lb = ir_add(IR_LOAD, tb, 30, 0, 0, 0);
            ir_w[lb] = 8;
            ir_k[lb] = ss_kbase[u] - 1000;
            int ta = ir_vreg(0);
            ir_add(IR_ADD, ta, tb, cur, 0, 0);
            cur = ta;
        } else {
            int ta2 = ir_vreg(0);
            ir_add(IR_ADD, ta2, ss_kbase[u], cur, 0, 0);
            cur = ta2;
        }
        int tc = ir_vreg(0);
        ir_add(IR_ADD, tc, cur, ss_koff[u], 1, 0);
        int sp = ir_add(IR_STORE, 0, 30, tc, 0, ss_kcell[u]);
        ir_w[sp] = 8;
        u += 1;
    }
    int jp = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jp] = h;
    // the block after the step of the counter: the pointers move on
    int inc = ir_new_block(0 - 1);
    ir_set_block(inc);
    u = 0;
    while u < ss_nk {
        int pc = ir_vreg(0);
        int lc = ir_add(IR_LOAD, pc, 30, 0, 0, 0);
        ir_w[lc] = 8;
        ir_k[lc] = ss_kcell[u];
        int pn = ir_vreg(0);
        ir_add(IR_ADD, pn, pc, ss_kf[u] * cl_step[q], 1, 0);
        int sc = ir_add(IR_STORE, 0, 30, pn, 0, ss_kcell[u]);
        ir_w[sc] = 8;
        u += 1;
    }
    int ji = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[ji] = h;
    ir_t1[t] = inc;
    // every jump into the header from outside the loop goes to the new block in front of it
    b = 0;
    while b < nb0 {
        if op_po[b] >= 0 && op_mark[b] != stamp {
            int tb2 = ir_be[b] - 1;
            int top = ir_op[tb2];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[tb2] == h { ir_t1[tb2] = pre; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[tb2] == h { ir_t2[tb2] = pre; }
        }
        b += 1;
    }
    ss_total += 1;
    return true;
}

void op_ssr() {
    if opt_debug == 1 { return; }
    op_counted_loops();
    ss_nb0 = ir_nb;
    int n = cl_n;
    int q = 0;
    while q < n {
        if cl_calls[q] >= 0 { ss_loop(q); }
        q += 1;
    }
}
