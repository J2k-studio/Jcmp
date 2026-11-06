// jc_opt.j -- passes on the IR (jc_ir.j). The first pass: loop-invariant constants.
//
// A whole number constant that needs more than one instruction (a 64-bit constant such as the multiplier of a division by 7) and is made
// inside a loop is made again at every turn. This pass finds the loops (a back edge goes to a block that dominates its source), puts the
// constant into a stack cell in a new block in front of the OUTERMOST loop that holds it, and the loop reads the cell. The register pass
// (jc_regs.j) then keeps the cell in a register when one is free; if not, a load costs less than four instructions.

#define OP_MAXL 1024
#define OP_MAXH 512

i64 op_s1[IR_MAXB];              // the successors of a block (-1 = none)
i64 op_s2[IR_MAXB];
i64 op_phead[IR_MAXB];           // the predecessors: a list of edges, an edge e = 2 * (the block it comes from) + 0 or 1
i64 op_enext[16384];
i64 op_po[IR_MAXB];              // the number of a block in the post order (-1: the flow never gets there)
i64 op_rpo[IR_MAXB];             // the blocks in reverse post order
i64 op_nrpo;
i64 op_idom[IR_MAXB];
i64 op_mark[IR_MAXB];            // the loop that a block belongs to is marked with the stamp of the loop being looked at
i64 op_stamp;
i64 op_stack[IR_MAXB];
i64 op_dfs_b[IR_MAXB];           // the stack of the depth first search: the block and which successor is next
i64 op_dfs_k[IR_MAXB];
i64 op_outer[IR_MAXB];           // the outermost loop (an index into op_lh) that a block is in, or -1

i64 op_bsrc[4096];        // the back edges: from, to
i64 op_bdst[4096];
i64 op_nback;
i64 op_lh[OP_MAXL];              // the loops: the header, the size
i64 op_lsize[OP_MAXL];
i64 op_nloops;

i64 op_hl[OP_MAXH];              // the hoisted constants: the loop, the value, the cell (k of the load)
i64 op_hv[OP_MAXH];
i64 op_hq[OP_MAXH];
i64 op_nh;

i64 op_hoisted;                  // how many constants were moved out of loops (all functions; for -irstat)

i64 op_succ(i64 b, i64 k) {
    if k == 0 { return op_s1[b]; }
    return op_s2[b];
}

// does the block a dominate the block b?
bool op_dom(i64 a, i64 b) {
    i64 x = b;
    while true {
        if x == a { return true; }
        if x == 0 { return false; }
        x = op_idom[x];
        if x < 0 { return false; }
    }
    return false;
}

i64 op_intersect(i64 a, i64 b) {
    i64 x = a;
    i64 y = b;
    while x != y {
        while op_po[x] < op_po[y] { x = op_idom[x]; }
        while op_po[y] < op_po[x] { y = op_idom[y]; }
    }
    return x;
}

// the graph: successors, predecessors, post order, immediate dominators
void op_graph() {
    i64 b = 0;
    while b < ir_nb {
        i64 t = ir_be[b] - 1;
        i64 op = ir_op[t];
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
        i64 k = 0;
        while k < 2 {
            i64 s = op_succ(b, k);
            if s >= 0 {
                i64 e = b * 2 + k;
                op_enext[e] = op_phead[s];
                op_phead[s] = e;
            }
            k += 1;
        }
        b += 1;
    }
    // the depth first search from the entry (an explicit stack)
    i64 sp = 0;
    i64 npo = 0;
    op_mark[0] = 0 - 7;
    op_dfs_b[0] = 0;
    op_dfs_k[0] = 0;
    sp = 1;
    i64 seen_stamp = 0 - 7;
    b = 1;
    while b < ir_nb {
        op_mark[b] = 0;
        b += 1;
    }
    while sp > 0 {
        i64 cb = op_dfs_b[sp - 1];
        i64 ck = op_dfs_k[sp - 1];
        if ck >= 2 {
            op_po[cb] = npo;
            op_rpo[ir_nb - 1 - npo] = cb;
            npo += 1;
            sp -= 1;
        } else {
            op_dfs_k[sp - 1] = ck + 1;
            i64 s2 = op_succ(cb, ck);
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
    i64 shift = ir_nb - npo;
    i64 r = 0;
    while r < npo {
        op_rpo[r] = op_rpo[r + shift];
        r += 1;
    }
    // dominators (Cooper, Harvey, Kennedy)
    op_idom[0] = 0;
    bool changed = true;
    while changed {
        changed = false;
        i64 ri = 1;
        while ri < npo {
            i64 blk = op_rpo[ri];
            i64 ni = 0 - 1;
            i64 e = op_phead[blk];
            while e >= 0 {
                i64 p = e / 2;
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
i64 op_mark_loop(i64 l) {
    op_stamp += 1;
    i64 h = op_lh[l];
    i64 n = 1;
    i64 sp = 0;
    op_mark[h] = op_stamp;
    i64 i = 0;
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
        i64 x = op_stack[sp];
        i64 e = op_phead[x];
        while e >= 0 {
            i64 p = e / 2;
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
bool op_costly(i64 k) {
    i64 fill = 0;
    if k < 0 { fill = 65535; }
    i64 n = 0;
    i64 c = 0;
    while c < 4 {
        if ((k >> (c * 16)) & 65535) != fill { n += 1; }
        c += 1;
    }
    return n >= 2;
}

// the stack cells that exist already: the deepest one
i64 op_maxq() {
    i64 m = 0;
    i64 i = 0;
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
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 s = op_succ(b, k);
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
    i64 i = 0;
    while i < op_nback {
        i64 h = op_bdst[i];
        bool known = false;
        i64 j = 0;
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
        i64 th = op_lh[i];
        i64 ts = op_lsize[i];
        i64 j = i - 1;
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
    i64 q = op_maxq();
    i64 nb0 = ir_nb;
    op_nh = 0;
    b = 0;
    while b < nb0 {
        i64 l = op_outer[b];
        if l >= 0 {
            i64 p = ir_bs[b];
            while p < ir_be[b] {
                if ir_op[p] == IR_CONST && ir_d[p] >= 1 && ir_d[p] <= 31 && op_costly(ir_k[p]) {
                    i64 hi = 0 - 1;
                    i64 u = 0;
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
        i64 u2 = 0;
        while u2 < op_nh {
            if op_hl[u2] == i { any = true; }
            u2 += 1;
        }
        if any {
            i64 pre = ir_new_block(0 - 1);
            ir_set_block(pre);
            u2 = 0;
            while u2 < op_nh {
                if op_hl[u2] == i {
                    i64 tv = ir_vreg(0);
                    ir_add(IR_CONST, tv, 0, 0, 0, op_hv[u2]);
                    i64 st = ir_add(IR_STORE, 0, 30, tv, 0, op_hq[u2]);
                    ir_w[st] = 8;
                }
                u2 += 1;
            }
            i64 jm = ir_add(IR_JMP, 0, 0, 0, 0, 0);
            i64 hh = op_lh[i];
            ir_t1[jm] = hh;
            // every jump to the header from outside the loop goes to the new block
            op_mark_loop(i);
            b = 0;
            while b < nb0 {
                if op_mark[b] != op_stamp {
                    i64 t = ir_be[b] - 1;
                    i64 top = ir_op[t];
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

i64 op_li[IR_MAXB];              // live-in registers of a block: bit v is the vreg v
i64 op_lo[IR_MAXB];
i64 op_exit[524288];             // the definition (an instruction number + 1, or 65536 + block * 64 + register + 1) that a register has at the end of a block, or 0
i64 op_uf[589824];               // union-find over: the instructions (their results) and the live-in nodes
i64 op_cur[64];
i64 opn_a[IR_MAXI];             // the node (see op_exit) of the definition that reaches each operand: -1 not a machine register, -2 none reaches
i64 opn_b[IR_MAXI];
i64 opn_g[IR_MAXA];
i64 ldef[IR_MAXB];
i64 op_seen[589824];
i64 op_fn_stamp;
i64 op_tot_defs;
i64 op_tot_webs;
i64 op_tot_fixed;

i64 op_clobber() {
    // caller-saved: x0..x18 (vregs 1..19), d0..d7 (32..39), d16..d31 (48..63)
    i64 m = 0;
    i64 v = 1;
    while v <= 19 { m = m | (1 << v); v += 1; }
    v = 32;
    while v <= 39 { m = m | (1 << v); v += 1; }
    v = 48;
    while v <= 63 { m = m | (1 << v); v += 1; }
    return m;
}

i64 op_bit(i64 v) {
    if v >= 1 && v <= 63 { return 1 << v; }
    return 0;
}

i64 op_uses(i64 i) {
    i64 m = op_bit(ir_a[i]);
    i64 op = ir_op[i];
    if ir_uses_b(op) && ir_bi[i] == 0 { m = m | op_bit(ir_b[i]); }
    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        i64 a = 0;
        while a < ir_ac[i] {
            m = m | op_bit(ir_args[ir_as[i] + a]);
            a += 1;
        }
    }
    return m;
}

i64 op_defs(i64 i) {
    i64 op = ir_op[i];
    i64 m = op_bit(ir_d[i]);
    if op == IR_CALL || op == IR_CALLIND { m = m | op_clobber(); }
    return m;
}

i64 op_find(i64 x) {
    i64 r = x;
    while op_uf[r] != r { r = op_uf[r]; }
    while op_uf[x] != r {
        i64 nx = op_uf[x];
        op_uf[x] = r;
        x = nx;
    }
    return r;
}

void op_union(i64 a, i64 b) {
    i64 ra = op_find(a);
    i64 rb = op_find(b);
    if ra != rb { op_uf[ra] = rb; }
}

// the nodes of the definitions that reach the operands of the instruction i (op_cur says what each register holds now)
i64 op_node(i64 v) {
    if v < 1 || v > 63 { return 0 - 1; }
    if op_cur[v] == 0 { return 0 - 2; }
    return op_cur[v] - 1;
}

void op_record(i64 i) {
    i64 op = ir_op[i];
    opn_a[i] = op_node(ir_a[i]);
    opn_b[i] = 0 - 1;
    if ir_uses_b(op) && ir_bi[i] == 0 { opn_b[i] = op_node(ir_b[i]); }
    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
        i64 a = 0;
        while a < ir_ac[i] {
            opn_g[ir_as[i] + a] = op_node(ir_args[ir_as[i] + a]);
            a += 1;
        }
    }
}


// liveness of the machine registers over the blocks, then the webs; returns the number of webs of the function
// the live-in and live-out registers of the blocks only (op_li, op_lo), without the webs
i64 lv_use[IR_MAXB];
void op_liveness() {
    op_graph();
    i64 b = 0;
    while b < ir_nb {
        i64 u = 0;
        i64 d = 0;
        i64 i = ir_bs[b];
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
        i64 ri = op_nrpo - 1;
        while ri >= 0 {
            i64 blk = op_rpo[ri];
            i64 out = 0;
            i64 k = 0;
            while k < 2 {
                i64 s = op_succ(blk, k);
                if s >= 0 { out = out | op_li[s]; }
                k += 1;
            }
            i64 nin = lv_use[blk] | (out & ~ldef[blk]);
            if nin != op_li[blk] || out != op_lo[blk] {
                op_li[blk] = nin;
                op_lo[blk] = out;
                changed = true;
            }
            ri -= 1;
        }
    }
}

i64 op_webs() {
    op_graph();
    // use / def of each block
    i64 b = 0;
    while b < ir_nb {
        i64 u = 0;
        i64 d = 0;
        i64 i = ir_bs[b];
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
        i64 ri = op_nrpo - 1;
        while ri >= 0 {
            i64 blk = op_rpo[ri];
            i64 out = 0;
            i64 k = 0;
            while k < 2 {
                i64 s = op_succ(blk, k);
                if s >= 0 { out = out | op_li[s]; }
                k += 1;
            }
            i64 uu = 0;
            i64 i2 = ir_bs[blk];
            i64 dd = 0;
            while i2 < ir_be[blk] {
                uu = uu | (op_uses(i2) & ~dd);
                dd = dd | op_defs(i2);
                i2 += 1;
            }
            i64 nin = uu | (out & ~ldef[blk]);
            if nin != op_li[blk] || out != op_lo[blk] {
                op_li[blk] = nin;
                op_lo[blk] = out;
                changed = true;
            }
            ri -= 1;
        }
    }
    // the nodes
    // only the nodes that can be used: the instructions (0 .. ir_n) and the live-in nodes of the blocks (from 65536); this was every node up to 65536 + 64 * blocks each time
    i64 nn = 65536 + ir_nb * 64;
    i64 x = 0;
    while x < ir_n + 1 {
        op_uf[x] = x;
        x += 1;
    }
    x = 65536;
    while x < nn {
        op_uf[x] = x;
        x += 1;
    }
    b = 0;
    while b < ir_nb {
        i64 r = 0;
        while r < 64 {
            op_cur[r] = 0;
            if r >= 1 && (op_li[b] & (1 << r)) != 0 { op_cur[r] = 65536 + b * 64 + r + 1; }
            r += 1;
        }
        i64 i3 = ir_bs[b];
        while i3 < ir_be[b] {
            op_record(i3);
            i64 dv = ir_d[i3];
            if dv >= 1 && dv <= 63 { op_cur[dv] = i3 + 1; }
            if ir_op[i3] == IR_CALL || ir_op[i3] == IR_CALLIND {
                i64 cm = op_clobber();
                i64 r2 = 1;
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
            i64 r3 = 1;
            while r3 < 64 {
                if (op_li[b] & (1 << r3)) != 0 {
                    i64 e = op_phead[b];
                    while e >= 0 {
                        i64 p = e / 2;
                        i64 ex = op_exit[p * 64 + r3];
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
    i64 webs = 0;
    i64 defs = 0;
    i64 i4 = 0;
    while i4 < ir_n {
        i64 dv2 = ir_d[i4];
        if dv2 >= 1 && dv2 <= 63 {
            defs += 1;
            i64 rt = op_find(i4);
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

i64 w_reg[OP_MAXW];              // the register the web has now
i64 w_start[OP_MAXW];
i64 w_end[OP_MAXW];
i64 w_fixed[OP_MAXW];
i64 w_new[OP_MAXW];              // the register it gets (0 = not yet)
i64 w_defi[OP_MAXW];             // the instruction of its first definition (the copy that may be removed), or -1
i64 w_ndef[OP_MAXW];
i64 w_bnext[OP_MAXW];
i64 w_nextf[OP_MAXW];
i64 op_nw;
i64 op_wmap[589824];
i64 op_pos[IR_MAXI];
i64 op_bpos0[IR_MAXB];           // the first / last position of a block
i64 op_bpos1[IR_MAXB];
i64 op_bhead[65540];
i64 op_cumcall[65540];
i64 op_reserved[64];
i64 op_busy[64];
i64 op_lastw[64];
i64 op_fbusy[64];
i64 op_fhead[64];
i64 op_ra_changes;
i64 op_ra_removed;
i64 op_ra_webs;

bool op_in_pool(i64 r) {
    return (r >= 1 && r <= 15) || (r >= 32 && r <= 39) || (r >= 48 && r <= 61 && r != 59);
}

i64 op_web(i64 node, i64 reg) {
    i64 root = op_find(node);
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

i64 op_node_reg(i64 node) {
    if node >= 65536 { return (node - 65536) % 64; }
    return ir_d[node];
}

void op_touch(i64 w, i64 p) {
    if w < 0 { return; }
    if p < w_start[w] { w_start[w] = p; }
    if p > w_end[w] { w_end[w] = p; }
}

// a use of the operand node n at the position p of the instruction i; fixed: the instruction needs the register as it is
void op_use(i64 n, i64 p, bool fixed) {
    if n == 0 - 1 { return; }
    if n == 0 - 2 { return; }
    i64 w = op_web(n, op_node_reg(n));
    if w < 0 { return; }
    op_touch(w, p);
    if fixed { w_fixed[w] = 1; }
}

// can the web [s, e] take the register rr? (srcw: the source of the copy that defines it, which may end where it starts, but only in want)
bool op_try(i64 rr, i64 s, i64 e, i64 srcw, i64 want) {
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
    i64 npos = 0;
    i64 ri = 0;
    while ri < op_nrpo {
        i64 b = op_rpo[ri];
        op_bpos0[b] = npos;
        i64 i = ir_bs[b];
        while i < ir_be[b] {
            op_pos[i] = npos;
            npos += 1;
            i += 1;
        }
        op_bpos1[b] = npos - 1;
        ri += 1;
    }
    i64 r = 0;
    while r < 64 {
        op_reserved[r] = 0;
        r += 1;
    }
    // definitions and uses
    ri = 0;
    while ri < op_nrpo {
        i64 b2 = op_rpo[ri];
        i64 i2 = ir_bs[b2];
        while i2 < ir_be[b2] {
            i64 p = op_pos[i2];
            i64 op = ir_op[i2];
            bool call = op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL;
            if op == IR_CALL || op == IR_CALLIND { op_cumcall[p] = 1; } else { op_cumcall[p] = 0; }
            bool special = call || op == IR_RET;
            i64 dv = ir_d[i2];
            if dv >= 1 && dv <= 63 {
                i64 w = op_web(i2, dv);
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
                i64 a = 0;
                while a < ir_ac[i2] {
                    i64 g = ir_as[i2] + a;
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
        i64 b3 = op_rpo[ri];
        i64 r2 = 1;
        while r2 < 64 {
            if (op_li[b3] & (1 << r2)) != 0 {
                i64 w = op_web(65536 + b3 * 64 + r2, r2);
                if w < 0 { return false; }
                op_touch(w, op_bpos0[b3]);
            }
            if (op_lo[b3] & (1 << r2)) != 0 && op_exit[b3 * 64 + r2] != 0 {
                i64 w2 = op_web(op_exit[b3 * 64 + r2] - 1, r2);
                if w2 < 0 { return false; }
                op_touch(w2, op_bpos1[b3]);
            }
            r2 += 1;
        }
        ri += 1;
    }
    op_ra_webs += op_nw;
    // the webs that cross a call, or are not in the pool, stay where they are
    i64 p2 = 0;
    i64 run = 0;
    while p2 < npos {
        run += op_cumcall[p2];
        op_cumcall[p2] = run;
        p2 += 1;
    }
    i64 w3 = 0;
    while w3 < op_nw {
        if w_end[w3] < w_start[w3] { w_end[w3] = w_start[w3]; }
        if !op_in_pool(w_reg[w3]) || op_reserved[w_reg[w3]] == 1 { w_fixed[w3] = 1; }
        if w_end[w3] - w_start[w3] >= 2 {
            i64 c1 = op_cumcall[w_end[w3] - 1];
            i64 c0 = op_cumcall[w_start[w3]];
            if c1 > c0 { w_fixed[w3] = 1; }
        }
        w3 += 1;
    }
    // buckets by start position; the fixed webs of each register in order of their start
    i64 pp = 0;
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
        i64 w4 = op_bhead[pp];
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
    i64 changes = 0;
    pp = 0;
    while pp < npos {
        i64 w5 = op_bhead[pp];
        while w5 >= 0 {
            if w_fixed[w5] == 0 {
                i64 s = w_start[w5];
                i64 e = w_end[w5];
                i64 want = 0;
                // a copy whose source dies at the copy: the same register
                i64 di = w_defi[w5];
                i64 srcw = 0 - 1;
                if w_ndef[w5] == 1 && di >= 0 && ir_op[di] == IR_COPY && opn_a[di] >= 0 {
                    srcw = op_web(opn_a[di], op_node_reg(opn_a[di]));
                    if srcw >= 0 && w_end[srcw] == s && w_new[srcw] != 0 && w_fixed[srcw] == 0 { want = w_new[srcw]; }
                }
                i64 chosen = 0;
                if want > 0 && op_try(want, s, e, srcw, want) { chosen = want; }
                if chosen == 0 && op_try(w_reg[w5], s, e, srcw, want) { chosen = w_reg[w5]; }
                if chosen == 0 {
                    i64 lo = 1;
                    i64 hi = 15;
                    if w_reg[w5] >= 32 { lo = 32; hi = 61; }
                    i64 scan = lo;
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
        i64 b6 = op_rpo[ri];
        i64 i6 = ir_bs[b6];
        while i6 < ir_be[b6] {
            i64 op6 = ir_op[i6];
            i64 dv6 = ir_d[i6];
            if opn_a[i6] >= 0 && ir_a[i6] >= 1 && ir_a[i6] <= 63 {
                i64 wa = op_web(opn_a[i6], ir_a[i6]);
                if w_new[wa] != ir_a[i6] { ir_a[i6] = w_new[wa]; changes += 1; }
            }
            if opn_b[i6] >= 0 && ir_uses_b(op6) && ir_bi[i6] == 0 && ir_b[i6] >= 1 && ir_b[i6] <= 63 {
                i64 wb = op_web(opn_b[i6], ir_b[i6]);
                if w_new[wb] != ir_b[i6] { ir_b[i6] = w_new[wb]; changes += 1; }
            }
            if dv6 >= 1 && dv6 <= 63 {
                i64 wd = op_web(i6, dv6);
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

i64 cp_kind[IR_MAXV];            // 0 nothing known, 1 the vreg holds a constant, 2 it is a copy of cp_val
i64 cp_val[IR_MAXV];
i64 cp_stamp[IR_MAXV];
i64 cp_cur;
i64 cp_act[64];                  // the vregs that have a kind now (to be killed when their source is written)
i64 cp_nact;
i64 op_clean_changes;

i64 cp_get(i64 v) {
    if v < 1 || v >= ir_nv || cp_stamp[v] != cp_cur { return 0; }
    return cp_kind[v];
}

void cp_kill(i64 d) {
    if d < 1 || d >= ir_nv { return; }
    if cp_stamp[d] == cp_cur { cp_kind[d] = 0; }
    i64 k = 0;
    while k < cp_nact {
        i64 v = cp_act[k];
        if cp_stamp[v] == cp_cur && cp_kind[v] == 2 && cp_val[v] == d { cp_kind[v] = 0; }
        k += 1;
    }
}

void cp_set(i64 v, i64 kind, i64 val) {
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
i64 cp_root(i64 v) {
    if cp_get(v) == 2 { return cp_val[v]; }
    return v;
}

bool cp_small(i64 k, i64 hi) {
    return k >= 0 && k <= hi;
}

i64 cp_flip(i64 cc) {
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

// the bits of a float made from the bits of a double (fcvt sD, dA), worked out here
i64 cp_fbits(i64 dbits) {
    double dd[1];
    i64^ db = (i64^)@dd[0];
    db[0] = dbits;
    float ff[2];
    ff[0] = (float)dd[0];
    i32^ fb = (i32^)@ff[0];
    return fb[0] & 4294967295;
}

i64 cp_done[IR_MAXB];
i64 cp_pc[IR_MAXB];

void op_prop_block(i64 b, i64 cont) {
    if cont == 0 {
        cp_cur += 1;
        cp_nact = 0;
    }
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        i64 op = ir_op[i];
        bool fixed = op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_RET;
        if !fixed {
            i64 a = ir_a[i];
            if a != 0 && cp_get(a) == 2 && ir_vcls[cp_val[a]] == ir_vcls[a] {
                ir_a[i] = cp_val[a];
                op_clean_changes += 1;
            }
            if ir_uses_b(op) && ir_bi[i] == 0 {
                i64 bv = ir_b[i];
                if cp_get(bv) == 2 && ir_vcls[cp_val[bv]] == ir_vcls[bv] {
                    ir_b[i] = cp_val[bv];
                    op_clean_changes += 1;
                }
                bv = ir_b[i];
                if cp_get(bv) == 1 && ir_vcls[bv] == 0 {
                    i64 k = cp_val[bv];
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
                    i64 k2 = cp_val[ir_a[i]];
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
            i64 kb = 0;
            if ir_bi[i] == 1 { kb = ir_b[i]; haveb = true; }
            else if cp_get(ir_b[i]) == 1 && ir_vcls[ir_b[i]] == 0 { kb = cp_val[ir_b[i]]; haveb = true; }
            if haveb {
                i64 ka = cp_val[ir_a[i]];
                i64 r = 0;
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
        // the bits of a float that is a known constant: a whole number constant (a float literal in an expression of floats)
        if op == IR_F32OUT && cp_get(ir_a[i]) == 4 && ir_d[i] > 0 && ir_vcls[ir_d[i]] == 0 {
            ir_op[i] = IR_CONST;
            ir_k[i] = cp_val[ir_a[i]];
            ir_a[i] = 0;
            ir_bi[i] = 1;
            op_clean_changes += 1;
            op = IR_CONST;
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
        i64 d = ir_d[i];
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            cp_cur += 1;
            cp_nact = 0;
        } else if d != 0 {
            i64 akind = 0;
            i64 aval = 0;
            if ir_a[i] > 0 { akind = cp_get(ir_a[i]); aval = cp_val[ir_a[i]]; }
            cp_kill(d);
            if op == IR_CONST && ir_vcls[d] == 0 {
                cp_set(d, 1, ir_k[i]);
            } else if op == IR_FCONST && ir_vcls[d] == 1 {
                cp_set(d, 3, ir_k[i]);
            } else if op == IR_FCVT_DS && akind == 3 && ir_vcls[d] == 1 {
                cp_set(d, 4, cp_fbits(aval));
            } else if op == IR_COPY && ir_a[i] != d {
                i64 src = ir_a[i];
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

bool op_pure(i64 op) {
    return op == IR_CONST || op == IR_COPY || (op >= IR_ADD && op <= IR_MULHS) || op == IR_NEG || op == IR_NOT || op == IR_EXT || op == IR_SETCC
        || (op >= IR_FADD && op <= IR_FSETCC) || op == IR_ADDR_GLOBAL || op == IR_ADDR_FUNC || op == IR_FCONST || (op >= IR_CLZ && op <= IR_POPCNT) || op == IR_FTRUNC || op == IR_FCEIL || (op >= IR_F32IN && op <= IR_F32TOI);
}

i64 op_tl[IR_MAXV];
i64 op_tl_stamp[IR_MAXV];
i64 op_tl_cur;

// dead code: backward in each block with the live registers at its end (op_lo); the temporaries (vregs from 64) live inside a block
void op_dce() {
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 live = op_lo[b];
            op_tl_cur += 1;
            i64 i = ir_be[b] - 1;
            while i >= ir_bs[b] {
                i64 op = ir_op[i];
                i64 d = ir_d[i];
                bool dead = false;
                if (op_pure(op) || (op == IR_LOAD && ir_a[i] == 30)) && d != 0 && op != IR_NOP {
                    if d >= 64 { dead = op_tl_stamp[d] != op_tl_cur || op_tl[d] == 0; }
                    else if (d >= 1 && d <= 15) || (d >= 32 && d <= 39) || (d >= 48 && d <= 61) { dead = (live & (1 << d)) == 0; }       // d8 .. d15 (40 .. 47) are callee-saved: a catch puts them back for the caller
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
                    i64 a = ir_a[i];
                    if a >= 64 {
                        op_tl_stamp[a] = op_tl_cur;
                        op_tl[a] = 1;
                    }
                    if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] >= 64 {
                        op_tl_stamp[ir_b[i]] = op_tl_cur;
                        op_tl[ir_b[i]] = 1;
                    }
                    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                        i64 g = 0;
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
    i64 round = 0;
    while round < 1 {
        op_graph();
        i64 b = 0;
        i64 nb0 = ir_nb;
        while b < nb0 {
            cp_done[b] = 0;
            cp_pc[b] = 0;
            b += 1;
        }
        b = 0;
        while b < nb0 {
            if op_po[b] >= 0 {
                i64 k = 0;
                while k < 2 {
                    i64 sc = op_succ(b, k);
                    if sc >= 0 && !(k == 1 && op_succ(b, 0) == sc) { cp_pc[sc] += 1; }
                    k += 1;
                }
            }
            b += 1;
        }
        // a block that only one block leads to goes on with what is known at the end of that block (the body of an inlined function
        // follows the arguments this way)
        i64 ri = 0;
        while ri < op_nrpo {
            i64 start = op_rpo[ri];
            ri += 1;
            if cp_done[start] == 0 && start < nb0 {
                i64 cur = start;
                i64 cont = 0;
                while cur >= 0 {
                    cp_done[cur] = 1;
                    op_prop_block(cur, cont);
                    i64 term = ir_be[cur] - 1;
                    i64 nxt = 0 - 1;
                    i64 tk = ir_op[term];
                    i64 cand1 = 0 - 1;
                    i64 cand2 = 0 - 1;
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
i64 vn_k[VN_MAX];               // the kind (an opcode, or 1000 + something for the others)
i64 vn_x[VN_MAX];
i64 vn_y[VN_MAX];
i64 vn_z[VN_MAX];
i64 vn_def[VN_MAX];             // the instruction that made it first (in this block), or -1
i64 vn_heavy[VN_MAX];
i64 vn_cell[VN_MAX];            // the stack cell (k of the load) it was written to, or 0
i64 vn_holder[VN_MAX];          // a register that held it last
i64 vn_inv[VN_MAX];             // the value that F2BITS / BITS2F of this one gives back (0 = none)
i64 vn_ab[VN_MAX];              // this value is (value vn_ab) + the number vn_ao (an address with an offset), vn_ab = -1: no
i64 vn_ao[VN_MAX];
i64 vn_al[VN_MAX];              // the value of a stored cell version is the value that was stored (-1 = none)
i64 vn_n;
i64 vn_ht[131072];
i64 vn_hst[131072];
i64 vn_hcur;
i64 vr_vn[IR_MAXV];             // the value number of a register now
i64 vr_st[IR_MAXV];
i64 vr_cur;
i64 vn_ins[IR_MAXI];            // after this instruction a store to this cell must be written
i64 op_plain[8192];             // 1: the frame slot (offset / 8) is a plain 8-byte value (from the hint line)
i64 vn_ver[16384];              // the version of a frame slot: index (offset / 8) for offsets >= 0, 8192 + (-offset / 8) for stack cells
i64 vn_ver_st[16384];
i64 vn_cell_cur;
i64 vn_cellvn[16384];
i64 vn_q;                       // the deepest stack cell now
i64 vn_changes;
i64 vn_mem;                     // the memory epoch: every store and every call makes a new one (a load of a global array is the same value inside one epoch)
i64 nc_dbg;                      // -ncdbg: say what the null check pass sees
i64 vn_neg_open;                // 1: the address of a stack cell (a negative offset of the frame) is taken somewhere: a store through a pointer may be to a cell
i64 vn_cellhits;                // how many values were read from a cell instead of being computed again

// the numbers of the hint line  ";H off:size:flag ..."  into op_plain
void vn_hints() {
    i64 i = 0;
    while i < 8192 {
        op_plain[i] = 0;
        i += 1;
    }
    i64 n = lf_hint_n;
    i64 p = 2;
    while p < n {
        while p < n && lf_hint_text[p] == ' ' { p += 1; }
        if p < n {
            i64 off = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { off = off * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            i64 size = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { size = size * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            i64 flag = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { flag = flag * 10 + (lf_hint_text[p] - '0'); p += 1; }
            if flag == 2 { flag = 1; }                      // a 32-bit number in an 8-byte slot is as plain as a 64-bit one here
            if size == 8 && flag == 1 && off % 8 == 0 && off / 8 < 8192 && op_plain[off / 8] == 0 { op_plain[off / 8] = 1; }
            else if off / 8 < 8192 {
                // any other entry that covers the slot makes it not plain
                i64 w = off / 8;
                i64 w1 = (off + size - 1) / 8;
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
i64 vn_slot(i64 i) {
    if ir_a[i] != 30 || ir_w[i] != 8 { return 0 - 1; }
    i64 k = ir_k[i];
    if k < 0 {
        if (0 - k) / 8 < 8192 && (0 - k) % 8 == 0 { return 8192 + (0 - k) / 8; }
        return 0 - 1;
    }
    if k % 8 == 0 && k / 8 < 8192 && op_plain[k / 8] == 1 { return k / 8; }
    return 0 - 1;
}

i64 vn_new(i64 kind, i64 x, i64 y, i64 z) {
    if vn_n >= VN_MAX { return 0 - 1; }
    i64 v = vn_n;
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

i64 vn_hash(i64 kind, i64 x, i64 y, i64 z) {
    i64 h = kind * 1000003 + x * 10007 + y * 131 + z * 7 + 12345;
    if h < 0 { h = 0 - h; }
    if h < 0 { h = 0; }
    return h & 131071;
}

// the value with this key, or -1
i64 vn_find(i64 kind, i64 x, i64 y, i64 z) {
    i64 h = vn_hash(kind, x, y, z);
    i64 n = 0;
    while n < 131072 && vn_hst[h] == vn_hcur {
        i64 v = vn_ht[h];
        if vn_k[v] == kind && vn_x[v] == x && vn_y[v] == y && vn_z[v] == z { return v; }
        h = (h + 1) & 131071;
        n += 1;
    }
    return 0 - 1;
}

void vn_enter(i64 v) {
    i64 h = vn_hash(vn_k[v], vn_x[v], vn_y[v], vn_z[v]);
    i64 n = 0;
    while n < 131072 && vn_hst[h] == vn_hcur {
        h = (h + 1) & 131071;
        n += 1;
    }
    vn_hst[h] = vn_hcur;
    vn_ht[h] = v;
}

// the value of a register now (a register that was not written in the block holds a value that comes from outside)
i64 vn_reg(i64 r) {
    if r < 1 || r >= ir_nv { return 0 - 1; }
    if vr_st[r] == vr_cur { return vr_vn[r]; }
    i64 v = vn_new(1000, r, 0, 0);
    if v < 0 { return v; }
    vr_vn[r] = v;
    vr_st[r] = vr_cur;
    if r < 64 { vn_holder[v] = r; }
    return v;
}

// the log of the registers that a region (one side of an if) writes, so that the facts of the code before the if can come back after it
#define GV_LOG 4096
i64 gv_lr[GV_LOG];
i64 gv_lvn[GV_LOG];
i64 gv_lst[GV_LOG];
i64 gv_lv[GV_LOG];
i64 gv_lh[GV_LOG];
i64 gv_ln;
i64 gv_on;
i64 gv_over;
i64 gv_joins;                   // how many joins of an if kept the facts

void vn_set(i64 r, i64 v) {
    if r < 1 || r >= ir_nv { return; }
    if gv_on == 1 {
        if gv_ln < GV_LOG {
            gv_lr[gv_ln] = r;
            gv_lvn[gv_ln] = vr_vn[r];
            gv_lst[gv_ln] = vr_st[r];
            gv_lv[gv_ln] = v;
            if v >= 0 { gv_lh[gv_ln] = vn_holder[v]; }
            gv_ln += 1;
        } else { gv_over = 1; }
    }
    if v < 0 {
        vr_st[r] = 0;
        return;
    }
    vr_vn[r] = v;
    vr_st[r] = vr_cur;
    if r < 64 { vn_holder[v] = r; }                  // a temporary (vreg >= 64) lives inside one block only
}

bool vn_commutes(i64 op) {
    return op == IR_ADD || op == IR_MUL || op == IR_AND || op == IR_OR || op == IR_XOR || op == IR_FADD || op == IR_FMUL;
}

bool vn_is_heavy_op(i64 op) {
    return op == IR_MUL || op == IR_SDIV || op == IR_UDIV || op == IR_MULHS || op == IR_FMUL || op == IR_FDIV || op == IR_FSQRT;
}

// is the register r still holding the value v?
bool vn_holds(i64 r, i64 v) {
    return r >= 1 && r < ir_nv && vr_st[r] == vr_cur && vr_vn[r] == v;
}

// what is known about a value on the way into the block (from the branches that led here): value, condition, number, 1 = the condition holds
i64 vf_vn[16];
i64 vf_cc[16];
i64 vf_imm[16];
i64 vf_t[16];
i64 vf_n;
i64 vn_folded;                  // branches that were decided

// does the branch  cc v, imm  go the true way (1), the false way (0), or is it not known (-1)?
i64 vf_decide(i64 cc, i64 v, i64 imm) {
    if v < 0 { return 0 - 1; }
    if vn_k[v] == 1001 { if tj_holds(cc, vn_x[v], imm) { return 1; } return 0; }
    i64 f = 0;
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
bool vn_from(i64 v, i64 g, i64 depth) {
    if v == g { return true; }
    if depth <= 0 || v < 0 { return false; }
    i64 k = vn_k[v];
    if k >= IR_ADD && k <= IR_ASHR && k != IR_SDIV && k != IR_UDIV && k != IR_MUL {
        if vn_from(vn_x[v], g, depth - 1) { return true; }
        if vn_y[v] < 1000000 && vn_y[v] >= 0 && vn_from(vn_y[v], g, depth - 1) { return true; }
    }
    return false;
}

// the value of (base + off) for the instruction i (an add or sub of a number) whose first operand is the value va that is itself base + ao; -1: no change
i64 gv_reassoc(i64 i, i64 va) {
    i64 off = vn_ao[va];
    if ir_op[i] == IR_ADD { off += ir_b[i]; } else { off -= ir_b[i]; }
    i64 bv = vn_ab[va];
    if off == 0 { return bv; }
    if off > 0 && off < 4096 {
        i64 v = vn_find(IR_ADD, bv, off + 1000000, ir_k[i] * 4 + ir_w[i]);
        if v < 0 {
            v = vn_new(IR_ADD, bv, off + 1000000, ir_k[i] * 4 + ir_w[i]);
            if v >= 0 { vn_enter(v); vn_def[v] = i; vn_ab[v] = bv; vn_ao[v] = off; }
        }
        return v;
    }
    if off < 0 && off > 0 - 4096 {
        i64 v2 = vn_find(IR_SUB, bv, 0 - off + 1000000, ir_k[i] * 4 + ir_w[i]);
        if v2 < 0 {
            v2 = vn_new(IR_SUB, bv, 0 - off + 1000000, ir_k[i] * 4 + ir_w[i]);
            if v2 >= 0 { vn_enter(v2); vn_def[v2] = i; vn_ab[v2] = bv; vn_ao[v2] = off; }
        }
        return v2;
    }
    return 0 - 1;
}

void vn_block(i64 b, i64 cont) {
    if cont == 0 {
        vn_n = 0;
        vn_hcur += 1;
        vr_cur += 1;
        vf_n = 0;
    }
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        i64 op = ir_op[i];
        i64 d = ir_d[i];
        vn_ins[i] = 0;
        if (op == IR_LOAD || op == IR_STORE) && ir_a[i] != 30 && ir_a[i] >= 1 && vn_n < VN_MAX - 8 {
            i64 va3 = vn_reg(ir_a[i]);
            if va3 >= 0 && vn_ab[va3] >= 0 {
                i64 hb = vn_holder[vn_ab[va3]];
                i64 w = ir_w[i];
                if w < 0 { w = 0 - w; }
                i64 nk = ir_k[i] + vn_ao[va3];
                if hb >= 1 && vn_holds(hb, vn_ab[va3]) && ir_vcls[hb] == 0 && w > 0 && nk >= 0 && nk <= 32760 && nk % w == 0 {
                    ir_a[i] = hb;
                    ir_k[i] = nk;
                    vn_changes += 1;
                }
            }
        }
        i64 V = 0 - 1;
        bool fwd = false;
        bool memload = false;
        bool valuable = false;
        if d != 0 && vn_n < VN_MAX - 8 {
            if op == IR_CONST {
                valuable = true;
                V = vn_find(1001, ir_k[i], 0, 0);
                if V < 0 { V = vn_new(1001, ir_k[i], 0, 0); vn_enter(V); }
            } else if op == IR_LOAD {
                i64 sl = vn_slot(i);
                if sl >= 0 {
                    valuable = true;
                    if vn_ver_st[sl] != vn_hcur { vn_ver_st[sl] = vn_hcur; vn_ver[sl] = 0; vn_cellvn[sl] = 0 - 1; }
                    V = vn_find(1002, sl, vn_ver[sl], 0);
                    if V < 0 { V = vn_new(1002, sl, vn_ver[sl], 0); vn_enter(V); if V >= 0 { vn_def[V] = i; } }
                    if V >= 0 && vn_al[V] >= 0 { V = vn_al[V]; fwd = true; }
                } else if ir_a[i] != 30 && ir_a[i] >= 1 && ir_vcls[d] == 0 && opt_nullchk == 1 && vn_reg(ir_a[i]) >= 0 {
                    // a load through a pointer: the same pointer in the same epoch gives the same value (the epoch changes at every call and at every store but the
                    // stores into a frame slot or cell that no pointer can reach); the data pointer of the header of an array is read once an access, not once a round
                    i64 vh = vn_reg(ir_a[i]);
                    valuable = true;
                    memload = true;
                    V = vn_find(1004, vh, ir_k[i], vn_mem * 64 + ir_w[i] + 16);
                    if V < 0 {
                        V = vn_new(1004, vh, ir_k[i], vn_mem * 64 + ir_w[i] + 16);
                        if V >= 0 {
                            vn_enter(V);
                            vn_def[V] = i;
                            vn_heavy[V] = 2;
                        }
                    }
                } else if ir_a[i] != 30 && ir_a[i] >= 1 && (ir_opt & 4194304) == 0 && ir_vcls[d] == 0 {
                    // a load from an element of a global array: the same address in the same epoch is the same value
                    i64 vg = vn_reg(29);
                    i64 vad = vn_reg(ir_a[i]);
                    if vg >= 0 && vad >= 0 && vn_from(vad, vg, 6) {
                        valuable = true;
                        memload = true;
                        i64 wq = ir_w[i] + 16;
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
                i64 va = vn_reg(ir_a[i]);
                if va >= 0 { vn_set(d, va); i += 1; continue; }
            } else if op_pure(op) && op != IR_NOP && op != IR_CONST && op != IR_COPY {
                i64 va2 = vn_reg(ir_a[i]);
                i64 vb2 = 0;
                i64 kk = ir_k[i];
                if ir_uses_b(op) {
                    if ir_bi[i] == 1 { vb2 = ir_b[i] + 1000000; } else { vb2 = vn_reg(ir_b[i]); }
                }
                if va2 >= 0 && vb2 >= 0 {
                    valuable = true;
                    i64 xa = va2;
                    i64 xb = vb2;
                    if vn_commutes(op) && ir_bi[i] == 0 && xb < xa { xa = vb2; xb = va2; }
                    i64 ky = op;
                    if op == IR_BITS2F && vn_inv[va2] > 0 { V = vn_inv[va2]; }
                    else if op == IR_F2BITS && vn_inv[va2] > 0 { V = vn_inv[va2]; }
                    else if (op == IR_ADD || op == IR_SUB) && ir_bi[i] == 1 && vn_ab[va2] >= 0 && (ir_opt & 8796093022208) == 0 && gv_reassoc(i, va2) >= 0 {
                        V = gv_reassoc(i, va2);                  // (x + c1) - c2 is x + (c1 - c2): the same value as x when they cancel
                    } else {
                        V = vn_find(ky, xa, xb, kk * 4 + ir_w[i] * 1);
                        if V < 0 {
                            V = vn_new(ky, xa, xb, kk * 4 + ir_w[i] * 1);
                            if V >= 0 {
                                vn_enter(V);
                                vn_def[V] = i;
                                i64 hv = 0;
                                if vn_is_heavy_op(op) { hv = 1; }
                                if vn_heavy[va2] == 1 { hv = 1; }
                                if vb2 < 1000000 && vn_heavy[vb2] == 1 { hv = 1; }
                                vn_heavy[V] = hv;
                                if op == IR_F2BITS || op == IR_BITS2F { vn_inv[V] = va2; }
                                if op == IR_ADD && ir_bi[i] == 1 { vn_ab[V] = va2; vn_ao[V] = ir_b[i]; }
                                if op == IR_SUB && ir_bi[i] == 1 && ir_b[i] < 4096 { vn_ab[V] = va2; vn_ao[V] = 0 - ir_b[i]; }
                            }
                        }
                    }
                }
            }
            if valuable && V >= 0 {
                // a register that holds the value already: a copy
                bool done = false;
                i64 h = vn_holder[V];
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
                } else if (op == IR_ADD || op == IR_SUB) && ir_bi[i] == 1 && vn_k[V] == 1002 && vn_def[V] >= 0 && vn_def[V] < i && ir_vcls[d] == 0 && ir_op[vn_def[V]] == IR_LOAD && ir_a[vn_def[V]] == 30 && vn_ver_st[vn_x[V]] == vn_hcur && vn_ver[vn_x[V]] == vn_y[V] {
                    // x + c - c: no register holds x any more, but its slot has not been written since: read it again (the register pass keeps it in a register)
                    i64 ld0 = vn_def[V];
                    ir_op[i] = IR_LOAD;
                    ir_a[i] = 30;
                    ir_k[i] = ir_k[ld0];
                    ir_w[i] = ir_w[ld0];
                    ir_b[i] = 0;
                    ir_bi[i] = 0;
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
            i64 vb5 = vn_reg(ir_b[i]);
            if vb5 >= 0 && vn_k[vb5] == 1001 && vn_x[vb5] >= 0 && vn_x[vb5] <= 4095 {
                ir_bi[i] = 1;
                ir_b[i] = vn_x[vb5];
                vn_changes += 1;
            }
        }
        // a branch on a number: decided when the way in tells the answer
        if op == IR_BR && ir_bi[i] == 1 && vn_n < VN_MAX - 8 {
            i64 vq = vn_reg(ir_a[i]);
            i64 dec = vf_decide(ir_k[i], vq, ir_b[i]);
            if dec >= 0 && (ir_opt & 2048) == 0 {
                i64 tgt = ir_t2[i];
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
        // a store into the frame (a plain slot, or a stack cell when nobody takes the address of a cell) cannot change what a pointer reaches
        bool frame_store = op == IR_STORE && ir_a[i] == 30 && ir_w[i] == 8 && ((ir_k[i] >= 0 && ir_k[i] % 8 == 0 && ir_k[i] / 8 < 8192 && op_plain[ir_k[i] / 8] == 1) || (ir_k[i] < 0 && vn_neg_open == 0));
        if (op == IR_STORE && !frame_store) || op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { vn_mem += 1; }
        if op == IR_STORE {
            i64 sl2 = vn_slot(i);
            if sl2 >= 0 {
                if vn_ver_st[sl2] != vn_hcur { vn_ver_st[sl2] = vn_hcur; vn_ver[sl2] = 0; }
                vn_ver[sl2] += 1;
                i64 vb = vn_reg(ir_b[i]);
                if vb >= 0 {
                    // a load of the new version of the slot gives the stored value
                    i64 nv = vn_new(1002, sl2, vn_ver[sl2], 0);
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
            i64 vo = vn_new(1003, d, i, 0);
            vn_set(d, vo);
        } else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            vr_cur += 1;
        }
        i += 1;
    }
}

// the block b written again (at the end of the arrays) with the stores after the instructions that made values read from cells
bool vn_emit(i64 b) {
    bool any = false;
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        if vn_ins[i] < 0 { any = true; }
        i += 1;
    }
    if !any { return true; }
    i64 cnt = ir_be[b] - ir_bs[b];
    i64 extra = 0;
    i = ir_bs[b];
    while i < ir_be[b] {
        if vn_ins[i] < 0 { extra += 1; }
        i += 1;
    }
    if ir_n + cnt + extra + 2 >= IR_MAXI || ir_nv + 4 >= IR_MAXV { return false; }
    i64 ns = ir_n;
    i = ir_bs[b];
    i64 e0 = ir_be[b];
    while i < e0 {
        i64 j = ir_n;
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
            i64 st = ir_n;
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

i64 vn_done[IR_MAXB];
i64 vn_pc[IR_MAXB];             // the number of predecessors (that the flow can reach)

// ---------------------------------------------------------------------------------------------- constants of locals that are written once (-irdbg 70368744177664 = 1<<46 switches it off)
// "int w = 512;" in the entry block, and no other store to the slot anywhere: every load of the slot is the number (the loop passes then see
// `y * 512`, a shift, and constant offsets). The slot must be a plain one (nobody takes its address).
i64 sk_cnt[8192];
i64 sk_val[8192];
i64 sk_idx[8192];
i64 sk_has[8192];
i64 sk_known[IR_MAXV];
i64 sk_kv[IR_MAXV];
i64 sk_changes;

void op_slotconst() {
    op_graph();
    vn_hints();
    i64 z = 0;
    while z < 8192 { sk_cnt[z] = 0; sk_has[z] = 0; z += 1; }
    i64 b = 0;
    while b < ir_nb {
        i64 i = ir_bs[b];
        while i < ir_be[b] {
            if ir_op[i] == IR_STORE && ir_a[i] == 30 && ir_k[i] >= 0 {
                i64 w = ir_w[i];
                if w < 0 { w = 0 - w; }
                if w < 1 { w = 1; }
                i64 s0 = ir_k[i] / 8;
                i64 s1 = (ir_k[i] + w - 1) / 8;
                while s0 <= s1 && s0 < 8192 { sk_cnt[s0] += 1; s0 += 1; }
            }
            i += 1;
        }
        b += 1;
    }
    // the entry block: the numbers that registers hold, and the stores of them into plain slots
    i64 r = 0;
    while r < ir_nv { sk_known[r] = 0; r += 1; }
    i64 i2 = ir_bs[0];
    while i2 < ir_be[0] {
        i64 op = ir_op[i2];
        i64 d = ir_d[i2];
        if op == IR_STORE && ir_a[i2] == 30 && ir_w[i2] == 8 && ir_bi[i2] == 0 && ir_k[i2] >= 0 && ir_k[i2] % 8 == 0 && ir_k[i2] / 8 < 8192 {
            i64 sl = ir_k[i2] / 8;
            if (op_plain[sl] == 1 && sk_cnt[sl] == 1 && ir_b[i2] >= 1 && ir_b[i2] < ir_nv && sk_known[ir_b[i2]] == 1) {
                sk_has[sl] = 1;
                sk_val[sl] = sk_kv[ir_b[i2]];
                sk_idx[sl] = i2;
            }
        } else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            r = 0;
            while r < ir_nv { sk_known[r] = 0; r += 1; }
        } else if d >= 1 && d < ir_nv {
            i64 ka = 0;
            i64 va = 0;
            if ir_a[i2] >= 1 && ir_a[i2] < ir_nv { ka = sk_known[ir_a[i2]]; va = sk_kv[ir_a[i2]]; }
            sk_known[d] = 0;
            if op == IR_CONST { sk_known[d] = 1; sk_kv[d] = ir_k[i2]; }
            else if op == IR_COPY && ka == 1 { sk_known[d] = 1; sk_kv[d] = va; }
            else if op == IR_EXT && ka == 1 && ir_k[i2] == 32 {
                i64 v = va;
                if ir_w[i2] == 1 {
                    v = v & 4294967295;
                    if v >= 2147483648 { v = v - 4294967296; }
                } else { v = v & 4294967295; }
                sk_known[d] = 1;
                sk_kv[d] = v;
            }
        }
        i2 += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i3 = ir_bs[b];
            while i3 < ir_be[b] {
                if ir_op[i3] == IR_LOAD && ir_a[i3] == 30 && ir_k[i3] >= 0 && ir_k[i3] % 8 == 0 && ir_k[i3] / 8 < 8192 && ir_d[i3] >= 1 && ir_vcls[ir_d[i3]] == 0 {
                    i64 sl3 = ir_k[i3] / 8;
                    if sk_has[sl3] == 1 && !(b == 0 && i3 < sk_idx[sl3]) {
                        i64 v3 = sk_val[sl3];
                        i64 lw = ir_w[i3];
                        bool ok = false;
                        if lw == 8 { ok = true; }
                        else if lw == 0 - 4 { v3 = v3 & 4294967295; if v3 >= 2147483648 { v3 = v3 - 4294967296; } ok = true; }
                        else if lw == 4 { v3 = v3 & 4294967295; ok = true; }
                        if ok {
                            ir_op[i3] = IR_CONST;
                            ir_k[i3] = v3;
                            ir_a[i3] = 0;
                            ir_bi[i3] = 1;
                            sk_changes += 1;
                        }
                    }
                }
                i3 += 1;
            }
        }
        b += 1;
    }
}

// global value numbering over an if: the side q (one block, entered from the branch `term` only, ending in a jump) is numbered with the facts of the
// code before the branch; afterwards what the side wrote is forgotten (the registers it wrote become unknown, the slots it stored get a new version,
// the values it made cannot be found), so the join block can use everything that was known before the branch
void gv_side(i64 q, i64 term, i64 trueside) {
    i64 vf0 = vf_n;
    if ir_bi[term] == 1 {
        i64 vq = vn_reg(ir_a[term]);
        if vq >= 0 && vf_n < 16 {
            vf_vn[vf_n] = vq;
            vf_cc[vf_n] = ir_k[term];
            vf_imm[vf_n] = ir_b[term];
            vf_t[vf_n] = trueside;
            vf_n += 1;
        }
    }
    i64 mark = vn_n;
    gv_ln = 0;
    gv_over = 0;
    gv_on = 1;
    vn_done[q] = 1;
    vn_block(q, 1);
    gv_on = 0;
    if gv_over == 1 {
        vr_cur += 1;
    } else {
        i64 g = gv_ln - 1;
        while g >= 0 {
            i64 r = gv_lr[g];
            vr_st[r] = 0;                          // the register has another value on the way through the side: unknown at the join
            if gv_lv[g] >= 0 { vn_holder[gv_lv[g]] = gv_lh[g]; }
            g -= 1;
        }
    }
    i64 i = ir_bs[q];
    while i < ir_be[q] {
        if ir_op[i] == IR_STORE {
            i64 sl = vn_slot(i);
            if sl >= 0 {
                if vn_ver_st[sl] != vn_hcur { vn_ver_st[sl] = vn_hcur; vn_ver[sl] = 0; vn_cellvn[sl] = 0 - 1; }
                vn_ver[sl] += 1;
            }
        }
        i += 1;
    }
    i64 v = mark;
    while v < vn_n {
        if vn_k[v] != 1000 && vn_k[v] != 1003 { vn_k[v] = 0 - 5; }
        v += 1;
    }
    vf_n = vf0;
}

// the block q is a side of an if: only the branch leads to it, and it ends in a jump to j
bool gv_is_side(i64 q, i64 p, i64 j, i64 nb0) {
    if q < 0 || q >= nb0 || q == p || q == j || vn_pc[q] != 1 || vn_done[q] != 0 || op_po[q] < 0 { return false; }
    i64 t = ir_be[q] - 1;
    return t >= ir_bs[q] && ir_op[t] == IR_JMP && ir_t1[t] == j;
}

void op_walk(i64 kind) {
    op_graph();
    vn_hints();
    vn_neg_open = 0;
    {
        i64 ib = 0;
        while ib < ir_nb {
            if op_po[ib] >= 0 {
                i64 ii = ir_bs[ib];
                while ii < ir_be[ib] {
                    i64 io = ir_op[ii];
                    if (io == IR_ADDR_SLOT && ir_d[ii] != 30 && (ir_k[ii] < 0 || ir_b[ii] < 0)) || (io == IR_ADD && ir_a[ii] == 30 && ir_bi[ii] == 1 && ir_b[ii] < 0) { vn_neg_open = 1; }
                    if ir_a[ii] == 30 && io != IR_LOAD && io != IR_STORE && io != IR_ADDR_SLOT && !(io == IR_ADD && ir_bi[ii] == 1) { vn_neg_open = 1; }
                    ii += 1;
                }
            }
            ib += 1;
        }
    }
    if nc_dbg == 1 { write_err("  vn of "); write_err(@ir_fname); write_err(" neg_open "); write_err_int(vn_neg_open); write_err(" plain16 "); write_err_int(op_plain[2]); write_err(" plain24 "); write_err_int(op_plain[3]); write_err(" hint "); write_err(@lf_hint_text); write_err("\n"); }
    vn_q = op_maxq();
    i64 b = 0;
    i64 nb0 = ir_nb;
    while b < nb0 {
        vn_done[b] = 0;
        vn_pc[b] = 0;
        b += 1;
    }
    b = 0;
    while b < nb0 {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 sc = op_succ(b, k);
                if sc >= 0 && !(k == 1 && op_succ(b, 0) == sc) { vn_pc[sc] += 1; }
                k += 1;
            }
        }
        b += 1;
    }
    // the blocks in reverse post order; after a block comes the successor that only it leads to (what is known stays)
    i64 ri = 0;
    while ri < op_nrpo {
        i64 start = op_rpo[ri];
        ri += 1;
        if vn_done[start] == 0 && start < nb0 {
            i64 cur = start;
            i64 cont = 0;
            while cur >= 0 {
                vn_done[cur] = 1;
                if kind == 0 { vn_block(cur, cont); } else { fa_block(cur, cont); }
                // the way on: the false side of a branch first (the fall through), else the true side, else the target of a jump
                i64 term = ir_be[cur] - 1;
                i64 nxt = 0 - 1;
                i64 tk = ir_op[term];
                i64 cand1 = 0 - 1;
                i64 cand2 = 0 - 1;
                if tk == IR_JMP { cand1 = ir_t1[term]; }
                if tk == IR_BR || tk == IR_FBR { cand1 = ir_t2[term]; cand2 = ir_t1[term]; }
                i64 which = 0;
                bool joined = false;
                if kind == 0 && tk == IR_BR && (ir_opt & 17592186044416) == 0 && (ir_opt & 256) == 0 && ir_t1[term] != ir_t2[term] {
                    i64 ga = ir_t1[term];
                    i64 gb = ir_t2[term];
                    i64 gj = 0 - 1;
                    bool ga_side = false;
                    bool gb_side = false;
                    if ga >= 0 && ga < nb0 && gb >= 0 && gb < nb0 {
                        i64 ta2 = ir_be[ga] - 1;
                        i64 tb2 = ir_be[gb] - 1;
                        if ta2 >= ir_bs[ga] && tb2 >= ir_bs[gb] && ir_op[ta2] == IR_JMP && ir_op[tb2] == IR_JMP && ir_t1[ta2] == ir_t1[tb2] {
                            gj = ir_t1[ta2];                         // a diamond
                            ga_side = gv_is_side(ga, cur, gj, nb0);
                            gb_side = gv_is_side(gb, cur, gj, nb0);
                            if !(ga_side && gb_side) { ga_side = false; gb_side = false; }
                        }
                        if !ga_side && !gb_side {
                            // a triangle: one side is the join itself
                            if gv_is_side(ga, cur, gb, nb0) { gj = gb; ga_side = true; }
                            else if gv_is_side(gb, cur, ga, nb0) { gj = ga; gb_side = true; }
                        }
                    }
                    if gj >= 0 && gj < nb0 && gj != cur && vn_pc[gj] == 2 && vn_done[gj] == 0 && (ga_side || gb_side) {
                        if ga_side { gv_side(ga, term, 1); }
                        if gb_side { gv_side(gb, term, 0); }
                        gv_joins += 1;
                        nxt = gj;
                        joined = true;
                    }
                }
                if joined { }
                else if cand1 >= 0 && cand1 < nb0 && vn_pc[cand1] == 1 && vn_done[cand1] == 0 && cand1 != cur { nxt = cand1; which = 2; }
                else if cand2 >= 0 && cand2 < nb0 && vn_pc[cand2] == 1 && vn_done[cand2] == 0 && cand2 != cur && cand1 != cand2 { nxt = cand2; which = 1; }
                if (ir_opt & 256) != 0 { nxt = 0 - 1; }
                if nxt >= 0 && !joined && tk == IR_BR && ir_bi[term] == 1 {
                    // what the branch tells about its value on the way to nxt
                    i64 vq = vn_reg(ir_a[term]);
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
i64 op_count() {
    op_graph();
    i64 n = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i = ir_bs[b];
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
bool bt_mentions(i64 b, i64 r) {
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        if ir_d[i] == r || ir_a[i] == r || (ir_uses_b(ir_op[i]) && ir_bi[i] == 0 && ir_b[i] == r) { return true; }
        if ir_op[i] == IR_CALL || ir_op[i] == IR_CALLIND || ir_op[i] == IR_SYSCALL {
            i64 g = 0;
            while g < ir_ac[i] {
                if ir_args[ir_as[i] + g] == r { return true; }
                g += 1;
            }
        }
        i += 1;
    }
    return false;
}

i64 bt_changes;

// the only instruction after `from` in the block b that reads the register x before x is written again (-1: none, more than one, or x lives on)
i64 bt_reader(i64 b, i64 from, i64 x) {
    i64 j = from;
    i64 found = 0 - 1;
    i64 count = 0;
    while j < ir_be[b] {
        bool reads = ir_a[j] == x || (ir_uses_b(ir_op[j]) && ir_bi[j] == 0 && ir_b[j] == x);
        bool call = ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL;
        if call {
            i64 g = 0;
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

void op_bits_block(i64 b) {
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        if ir_op[i] == IR_F2BITS && ir_d[i] >= 1 && ir_d[i] <= 31 && ir_vcls[ir_a[i]] == 1 {
            i64 x = ir_d[i];
            i64 src = ir_a[i];
            i64 j1 = bt_reader(b, i + 1, x);
            i64 use = 0 - 1;
            i64 mid = 0 - 1;
            if j1 >= 0 && ir_op[j1] == IR_BITS2F { use = j1; }
            else if j1 >= 0 && ir_op[j1] == IR_COPY && ir_a[j1] == x && ir_d[j1] >= 1 && ir_d[j1] <= 31 {
                i64 j2 = bt_reader(b, j1 + 1, ir_d[j1]);
                if j2 >= 0 && ir_op[j2] == IR_BITS2F { use = j2; mid = j1; }
            }
            if use >= 0 {
                // is the source written between the two? then a copy is needed, else nothing to do
                bool written = false;
                i64 m = i + 1;
                while m < use {
                    if ir_d[m] == src || ir_op[m] == IR_CALL || ir_op[m] == IR_CALLIND { written = true; }
                    m += 1;
                }
                if written {
                    i64 r = 48;
                    i64 pick = 0;
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
    i64 b = 0;
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
i64 fs_cand[8192];
i64 fs_changes;

i64 fs_slot_of(i64 i) {
    i64 s = vn_slot(i);
    if s >= 0 && s < 8192 { return s; }
    return 0 - 1;
}

// the instruction that made the value of r at pos, through copies: F2BITS, CONST or a LOAD (-1: something else)
i64 fs_root(i64 b, i64 pos, i64 r) {
    i64 guard = 0;
    i64 at = pos;
    i64 v = r;
    while guard < 8 {
        i64 j = rn_find_def(b, at, v);
        if j < 0 { return 0 - 1; }
        i64 op = ir_op[j];
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

bool fs_uses_ok(i64 b, i64 from, i64 d, i64 depth) {
    if depth > 6 || d < 1 { return false; }
    i64 j = from;
    while j < ir_be[b] {
        i64 op = ir_op[j];
        if op == IR_NOP { j += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            i64 g = 0;
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
                i64 e = ir_d[j];
                if e == d {
                    // a copy onto itself changes nothing: the value goes on in the same register
                    j += 1;
                    continue;
                }
                if e < 1 || e >= 64 { return false; }
                if !fs_uses_ok(b, j + 1, e, depth + 1) { return false; }
            } else if op == IR_STORE && ir_w[j] == 8 && ir_bi[j] == 0 && ir_b[j] == d && ir_a[j] == 30 {
                i64 s2 = fs_slot_of(j);
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
i64 fs_pick(i64 b, i64 taken) {
    i64 r = 61;
    while r >= 50 {
        if r != 59 && (taken & (1 << r)) == 0 && (op_li[b] & (1 << r)) == 0 && (op_lo[b] & (1 << r)) == 0 && !bt_mentions(b, r) { return r; }
        r -= 1;
    }
    return 0;
}

void op_fslots() {
    if ir_nb > 2000 { return; }
    op_liveness();
    i64 s = 0;
    while s < 8192 { fs_cand[s] = 0; s += 1; }
    bool any = false;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] == IR_STORE && ir_a[i] == 30 {
                    i64 sl = fs_slot_of(i);
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
    i64 rounds = 0;
    while changed && rounds < 12 {
        changed = false;
        rounds += 1;
        b = 0;
        while b < ir_nb {
            if op_po[b] >= 0 {
                i64 i = ir_bs[b];
                while i < ir_be[b] {
                    i64 op = ir_op[i];
                    if (op == IR_STORE || op == IR_LOAD) && ir_a[i] == 30 && ir_w[i] == 8 {
                        i64 sl = fs_slot_of(i);
                        if sl >= 0 && fs_cand[sl] == 1 {
                            bool ok = true;
                            if op == IR_STORE {
                                if ir_bi[i] != 0 { ok = false; }
                                else {
                                    i64 rt = fs_root(b, i, ir_b[i]);
                                    if rt < 0 { ok = false; }
                                    else {
                                        if ir_op[rt] == IR_LOAD {
                                            i64 s3 = fs_slot_of(rt);
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
    i64 map_of[64];
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 z = 0;
            while z < 64 { map_of[z] = 0; z += 1; }
            i64 taken = 0;
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                i64 op = ir_op[i];
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
                    i64 nf2 = fs_pick(b, taken);
                    i64 od = ir_d[i];
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
                i64 d = ir_d[i];
                if d > 0 && d < 64 && op != IR_STORE && ir_vcls[d] == 0 {
                    map_of[d] = 0;
                    bool retype = false;
                    if op == IR_LOAD && ir_a[i] == 30 && ir_w[i] == 8 && ir_bi[i] == 0 {
                        i64 sl2 = fs_slot_of(i);
                        if sl2 >= 0 && fs_cand[sl2] == 1 { retype = true; }
                    } else if (op == IR_F2BITS || op == IR_CONST) && fs_uses_ok(b, i + 1, d, 0) {
                        // only when a store of a double slot is among the readers (else nothing is gained)
                        i64 j = i + 1;
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
                        i64 nf = fs_pick(b, taken);
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
i64 fr_on = 0;                  // off: stp/ldp pre- and post-index were 9 % SLOWER than sub/str/str on the Cortex-A55 (fib), measured 0.9.71

i64 fr_number(i64 p) {
    i64 n = 0;
    while out_buf[p] >= '0' && out_buf[p] <= '9' {
        n = n * 10 + (out_buf[p] - '0');
        p += 1;
    }
    return n;
}

void fr_run() {
    regs_len = 0;
    i64 i = 0;
    while i < out_len {
        i64 en = rg_end(i);
        if rg_has(i, "sub sp, sp, #") {
            i64 n = fr_number(i + 13);
            i64 l2 = en + 1;
            i64 l3 = 0 - 1;
            i64 l4 = 0 - 1;
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
            i64 l2 = en + 1;
            i64 l3 = 0 - 1;
            if l2 < out_len && rg_has(l2, "ldr x30, [sp, #8]\n") { l3 = rg_end(l2) + 1; }
            if l3 > 0 && l3 < out_len && rg_has(l3, "add sp, sp, #") {
                i64 n = fr_number(l3 + 13);
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
    i64 t = 0;
    while t < regs_len {
        out_buf[t] = regs_buf[t];
        t += 1;
    }
    out_len = regs_len;
}

// ---------------------------------------------------------------------------------------------- jump threading
// A block that holds only "br cc xR, #N" and is jumped to from a block that has just set xR to a constant: the jump goes straight to the
// right target (the boolean that && and || make with  mov x0, 1 / mov x0, 0  and test again). The constant stays where it is; dead code removes it.
bool tj_holds(i64 cc, i64 a, i64 b) {
    if cc == IR_EQ { return a == b; }
    if cc == IR_NE { return a != b; }
    if cc == IR_LT { return a < b; }
    if cc == IR_LE { return a <= b; }
    if cc == IR_GT { return a > b; }
    if cc == IR_GE { return a >= b; }
    // unsigned: compare after flipping the sign bit
    i64 sign = 1 << 63;
    i64 ua = a + sign;
    i64 ub = b + sign;
    if cc == IR_ULT { return ua < ub; }
    if cc == IR_ULE { return ua <= ub; }
    if cc == IR_UGT { return ua > ub; }
    return ua >= ub;
}

// the target an edge from the block b to the block t can be threaded to, or -1
i64 tj_target(i64 b, i64 t, i64 upto) {
    if t == b { return 0 - 1; }
    // the first instruction that does something; it must be the last of the block
    i64 br = ir_bs[t];
    while br < ir_be[t] - 1 && ir_op[br] == IR_NOP { br += 1; }
    if br != ir_be[t] - 1 { return 0 - 1; }
    if ir_op[br] == IR_JMP {
        if ir_t1[br] == t { return 0 - 1; }
        return ir_t1[br];
    }
    if ir_op[br] != IR_BR || ir_bi[br] != 1 || ir_a[br] < 1 || ir_a[br] > 31 { return 0 - 1; }
    i64 r = ir_a[br];
    // the last definition of r in b before the terminator
    i64 i = upto - 1;
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

i64 tj_changes;

void op_thread() {
    i64 pass = 0;
    while pass < 3 {
        i64 before = tj_changes;
        i64 b = 0;
        i64 nb0 = ir_nb;
        while b < nb0 {
            i64 t = ir_be[b] - 1;
            i64 op = ir_op[t];
            if op == IR_JMP || op == IR_BR || op == IR_FBR {
                i64 n1 = tj_target(b, ir_t1[t], t);
                if n1 >= 0 { ir_t1[t] = n1; tj_changes += 1; }
                if op != IR_JMP {
                    i64 n2 = tj_target(b, ir_t2[t], t);
                    if n2 >= 0 { ir_t2[t] = n2; tj_changes += 1; }
                }
            }
            b += 1;
        }
        if tj_changes == before { return; }
        pass += 1;
    }
}

// ---------------------------------------------------------------------------------------------- merging of blocks
// A block that ends with a jump to a block that nobody else reaches (one way in, not the entry, no address taken) is one block with it:
// the front end and the inlining cut the code into such chains (a call, a check, the end of a statement). The passes that work inside a
// block (the stack cells, the vectors, the constants of cells, later the promotion of cells) then see the whole chain. The instructions of
// the chain are copied to a new place at the end of the arrays (the blocks are ranges); the blocks that were taken in stay but nobody reaches them.
i64 mg_pc[IR_MAXB];
i64 mg_pin[IR_MAXB];
i64 mg_gone[IR_MAXB];
i64 mg_chain[IR_MAXB];
i64 mg_changes;

void op_merge_blocks() {
    // the allocator of webs (-irra, off by default) orders its intervals by the block numbers: not yet taught about merged chains
    if (ir_opt & 2147483648) != 0 || (ir_opt & 2) != 0 { return; }
    op_graph();
    i64 b = 0;
    while b < ir_nb {
        mg_pc[b] = 0;
        mg_pin[b] = 0;
        mg_gone[b] = 0;
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 sc = op_succ(b, k);
                if sc >= 0 && !(k == 1 && op_succ(b, 0) == sc) { mg_pc[sc] += 1; }
                k += 1;
            }
            i64 j = ir_bs[b];
            while j < ir_be[b] - 1 {
                i64 op = ir_op[j];
                if op != IR_NOP {
                    if ir_t1[j] >= 0 && ir_t1[j] < ir_nb { mg_pin[ir_t1[j]] = 1; }
                    if ir_t2[j] >= 0 && ir_t2[j] < ir_nb { mg_pin[ir_t2[j]] = 1; }
                }
                j += 1;
            }
        }
        b += 1;
    }
    if ir_lastb >= 0 && ir_lastb < ir_nb { mg_pin[ir_lastb] = 1; }      // the block that falls into the epilogue stays where it is
    i64 nb0 = ir_nb;
    i64 ri = 0;
    while ri < op_nrpo {
        i64 h = op_rpo[ri];
        ri += 1;
        if h >= nb0 || mg_gone[h] == 1 { continue; }
        // the chain that starts at h
        i64 n = 0;
        i64 cur = h;
        mg_chain[0] = h;
        n = 1;
        while n < 4000 {
            i64 tt = ir_be[cur] - 1;
            if ir_op[tt] != IR_JMP { break; }
            i64 s = ir_t1[tt];
            if s < 0 || s >= nb0 || s == h || s == 0 || mg_pc[s] != 1 || mg_pin[s] == 1 || mg_gone[s] == 1 || op_po[s] < 0 { break; }
            mg_chain[n] = s;
            n += 1;
            cur = s;
        }
        if n < 2 { continue; }
        i64 total = 0;
        i64 q = 0;
        while q < n {
            total += ir_be[mg_chain[q]] - ir_bs[mg_chain[q]];
            q += 1;
        }
        if ir_n + total + 8 >= IR_MAXI { return; }
        i64 start = ir_n;
        q = 0;
        while q < n {
            i64 cb = mg_chain[q];
            i64 last = ir_be[cb];
            if q < n - 1 { last = last - 1; }             // the jump to the next block of the chain goes
            i64 jj = ir_bs[cb];
            while jj < last {
                i64 ni = ir_n;
                ir_op[ni] = ir_op[jj];
                ir_d[ni] = ir_d[jj];
                ir_a[ni] = ir_a[jj];
                ir_b[ni] = ir_b[jj];
                ir_bi[ni] = ir_bi[jj];
                ir_k[ni] = ir_k[jj];
                ir_w[ni] = ir_w[jj];
                ir_t1[ni] = ir_t1[jj];
                ir_t2[ni] = ir_t2[jj];
                ir_as[ni] = ir_as[jj];
                ir_ac[ni] = ir_ac[jj];
                ir_n += 1;
                jj += 1;
            }
            if q > 0 {
                mg_gone[cb] = 1;
                if ir_lastb == cb { ir_lastb = h; }
            }
            q += 1;
        }
        ir_bs[h] = start;
        ir_be[h] = ir_n;
        mg_changes += n - 1;
    }
    op_graph();
}

// ---------------------------------------------------------------------------------------------- cells kept in registers inside a block
// In a block (a merged chain is a big one) a plain frame cell or a temporary cell below the base that is written and read again is kept in
// a register that the block does not use otherwise: the store stays (other blocks, the next turn of a loop read it; a cell nobody reads is
// removed later by op_dead_cells), the load becomes a copy. A double that went through the cell as bits (`f2bits`, store ... load, `bits2f`)
// stays a double: the cell is held in a double register, the load gives `f2bits` of it and the `bits2f` after it is a copy again.
// The knowledge ends at a call (the registers are not kept over it) and at the end of the block. Only cells that the passes treat as plain.
#define CP_N 12
i64 cp_off[CP_N];
i64 cp_reg[CP_N];
i64 cp_cls[CP_N];
i64 cp_n;
i64 cp_fv[64];                   // d = f2bits F is known for the whole number register d: F (0: not known)
i64 cp_ll_off[64];
i64 cp_ll_pos[64];
i64 cp_nll;
i64 cp_pool_i[10];
i64 cp_pool_f[13];
i64 cp_changes;
i64 cp_blocks;

bool cp_cell_ok(i64 k) {
    if k < 0 { return vn_neg_open == 0 && (0 - k) % 8 == 0; }
    return k % 8 == 0 && k / 8 < 8192 && op_plain[k / 8] == 1;
}

i64 cp_find(i64 k) {
    i64 i = 0;
    while i < cp_n {
        if cp_off[i] == k { return i; }
        i += 1;
    }
    return 0 - 1;
}

void cp_kill_reg(i64 r) {
    if r >= 1 && r < 64 {
        cp_fv[r] = 0;
        i64 i = 0;
        while i < 64 {
            if cp_fv[i] == r { cp_fv[i] = 0; }
            i += 1;
        }
    }
}

i64 cp_lastload(i64 k) {
    i64 i = 0;
    while i < cp_nll {
        if cp_ll_off[i] == k { return cp_ll_pos[i]; }
        i += 1;
    }
    return 0 - 1;
}

void cp_drop(i64 c) {
    cp_n -= 1;
    cp_off[c] = cp_off[cp_n]; cp_reg[c] = cp_reg[cp_n]; cp_cls[c] = cp_cls[cp_n];
}

i64 cp_emit(i64 op, i64 d, i64 a, i64 b, i64 bi, i64 k) {
    i64 ni = ir_n;
    ir_op[ni] = op;
    ir_d[ni] = d;
    ir_a[ni] = a;
    ir_b[ni] = b;
    ir_bi[ni] = bi;
    ir_k[ni] = k;
    ir_w[ni] = 0;
    ir_t1[ni] = 0 - 1;
    ir_t2[ni] = 0 - 1;
    ir_as[ni] = 0;
    ir_ac[ni] = 0;
    ir_n += 1;
    return ni;
}

void cp_copy(i64 j) {
    i64 ni = ir_n;
    ir_op[ni] = ir_op[j];
    ir_d[ni] = ir_d[j];
    ir_a[ni] = ir_a[j];
    ir_b[ni] = ir_b[j];
    ir_bi[ni] = ir_bi[j];
    ir_k[ni] = ir_k[j];
    ir_w[ni] = ir_w[j];
    ir_t1[ni] = ir_t1[j];
    ir_t2[ni] = ir_t2[j];
    ir_as[ni] = ir_as[j];
    ir_ac[ni] = ir_ac[j];
    ir_n += 1;
}

// a register of the pool that the block does not mention and no cell holds
i64 cp_take(i64 cls, i64 mention) {
    if cls == 1 && (ir_opt & 4294967296) != 0 { return 0; }
    if cls == 0 && (ir_opt & 8589934592) != 0 { return 0; }
    i64 n = 10;
    if cls == 1 { n = 13; }
    i64 i = 0;
    while i < n {
        i64 r = cp_pool_i[i % 10];
        if cls == 1 { r = cp_pool_f[i]; }
        if i < n && (mention & op_bit(r)) == 0 {
            bool used = false;
            i64 c = 0;
            while c < cp_n { if cp_reg[c] == r { used = true; } c += 1; }
            if !used { return r; }
        }
        i += 1;
    }
    return 0;
}

void op_cell_promote() {
    if (ir_opt & 2147483648) != 0 || (ir_opt & 16777216) != 0 || (ir_opt & 2) != 0 { return; }
    op_graph();
    vn_hints();
    // vn_neg_open: an address below the base is taken somewhere
    vn_neg_open = 0;
    i64 zb = 0;
    while zb < ir_nb {
        if op_po[zb] >= 0 {
            i64 zi = ir_bs[zb];
            while zi < ir_be[zb] {
                i64 zo = ir_op[zi];
                if (zo == IR_ADDR_SLOT && ir_d[zi] != 30 && (ir_k[zi] < 0 || ir_b[zi] < 0)) || (zo == IR_ADD && ir_a[zi] == 30 && ir_bi[zi] == 1 && ir_b[zi] < 0) { vn_neg_open = 1; }
                if ir_a[zi] == 30 && zo != IR_LOAD && zo != IR_STORE && zo != IR_ADDR_SLOT && !(zo == IR_ADD && ir_bi[zi] == 1) { vn_neg_open = 1; }
                if (zo == IR_LOAD || zo == IR_STORE) && ir_a[zi] == 30 && ir_k[zi] < 0 && (ir_w[zi] != 8 || (ir_k[zi] % 8) != 0) { vn_neg_open = 1; }
                zi += 1;
            }
        }
        zb += 1;
    }
    i64 pi = 0;
    while pi < 10 { cp_pool_i[pi] = 6 + pi; pi += 1; }              // x5 .. x14
    i64 pf = 0;
    while pf < 5 { cp_pool_f[pf] = 35 + pf; pf += 1; }              // d3 .. d7
    while pf < 13 { cp_pool_f[pf] = 48 + (pf - 5); pf += 1; }       // d16 .. d23
    op_liveness();
    i64 nb0 = ir_nb;
    i64 b = 0;
    while b < nb0 {
        if op_po[b] >= 0 && ir_n + (ir_be[b] - ir_bs[b]) * 3 + 64 < IR_MAXI {
            // the registers that the block names or keeps alive
            i64 mention = op_li[b] | op_lo[b];
            i64 mj = ir_bs[b];
            while mj < ir_be[b] {
                mention = mention | op_uses(mj) | op_defs(mj);
                mj += 1;
            }
            // is there anything to do? a cell written or read twice
            i64 cnt = 0;
            i64 sj = ir_bs[b];
            while sj < ir_be[b] {
                if (ir_op[sj] == IR_LOAD || ir_op[sj] == IR_STORE) && ir_a[sj] == 30 && ir_w[sj] == 8 && cp_cell_ok(ir_k[sj]) { cnt += 1; }
                sj += 1;
            }
            // the last load of each cell in the block: after it the register is free again, and a store after it needs none
            cp_nll = 0;
            i64 ll = ir_bs[b];
            while ll < ir_be[b] {
                if ir_op[ll] == IR_LOAD && ir_a[ll] == 30 && ir_w[ll] == 8 && cp_cell_ok(ir_k[ll]) {
                    i64 lx = 0;
                    while lx < cp_nll && cp_ll_off[lx] != ir_k[ll] { lx += 1; }
                    if lx == cp_nll && cp_nll < 64 { cp_nll += 1; cp_ll_off[lx] = ir_k[ll]; }
                    if lx < 64 { cp_ll_pos[lx] = ll; }
                }
                ll += 1;
            }
            i64 capn = (ir_opt >> 40) & 4095;
            if cnt >= 2 && (capn == 0 || cp_blocks < capn) {
                i64 start = ir_n;
                i64 before = cp_changes;
                cp_n = 0;
                i64 fz = 0;
                while fz < 64 { cp_fv[fz] = 0; fz += 1; }
                i64 j = ir_bs[b];
                i64 jend = ir_be[b];
                while j < jend {
                    i64 op = ir_op[j];
                    i64 d = ir_d[j];
                    bool done = false;
                    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                        cp_n = 0;
                        fz = 0;
                        while fz < 64 { cp_fv[fz] = 0; fz += 1; }
                    } else if op == IR_STORE && ir_a[j] == 30 && ir_w[j] == 8 && cp_cell_ok(ir_k[j]) {
                        i64 k = ir_k[j];
                        i64 c = cp_find(k);
                        i64 r = ir_b[j];
                        i64 rc = 2;
                        if ir_bi[j] == 0 && r >= 1 && r < 64 { rc = ir_vcls[r]; }          // a scratch temporary (64 and up) lives for one instruction: not kept
                        if rc > 1 || j >= cp_lastload(k) {
                            if c >= 0 {
                                cp_n -= 1;
                                cp_off[c] = cp_off[cp_n]; cp_reg[c] = cp_reg[cp_n]; cp_cls[c] = cp_cls[cp_n];
                            }
                        } else {
                            i64 fsrc = 0;
                            if rc == 1 { fsrc = r; }
                            else if r < 64 && cp_fv[r] != 0 { fsrc = cp_fv[r]; }
                            i64 want = 0;
                            if fsrc != 0 { want = 1; }
                            if c >= 0 && cp_cls[c] != want {
                                cp_n -= 1;
                                cp_off[c] = cp_off[cp_n]; cp_reg[c] = cp_reg[cp_n]; cp_cls[c] = cp_cls[cp_n];
                                c = 0 - 1;
                            }
                            i64 hreg = 0;
                            if c >= 0 { hreg = cp_reg[c]; } else if cp_n < CP_N { hreg = cp_take(want, mention); }
                            if hreg != 0 {
                                if c < 0 {
                                    c = cp_n;
                                    cp_n += 1;
                                    cp_off[c] = k;
                                    cp_reg[c] = hreg;
                                    cp_cls[c] = want;
                                }
                                if want == 1 { cp_emit(IR_COPY, hreg, fsrc, 0, 0, 0); } else { cp_emit(IR_COPY, hreg, r, 0, 0, 0); }
                                cp_changes += 1;
                            } else if c >= 0 {
                                cp_n -= 1;
                                cp_off[c] = cp_off[cp_n]; cp_reg[c] = cp_reg[cp_n]; cp_cls[c] = cp_cls[cp_n];
                            }
                        }
                    } else if op == IR_LOAD && ir_a[j] == 30 && ir_w[j] == 8 && cp_cell_ok(ir_k[j]) && d >= 1 && ir_vcls[d] <= 1 {
                        i64 k2 = ir_k[j];
                        i64 c2 = cp_find(k2);
                        i64 dcls = ir_vcls[d];
                        if c2 >= 0 {
                            if cp_cls[c2] == dcls {
                                cp_emit(IR_COPY, d, cp_reg[c2], 0, 0, 0);
                                if d < 64 { cp_kill_reg(d); }
                            } else if dcls == 0 {
                                cp_emit(IR_F2BITS, d, cp_reg[c2], 0, 0, 0);
                                if d < 64 { cp_kill_reg(d); cp_fv[d] = cp_reg[c2]; }
                            } else {
                                cp_emit(IR_BITS2F, d, cp_reg[c2], 0, 0, 0);
                                cp_kill_reg(d);
                            }
                            cp_changes += 1;
                            done = true;
                            if j >= cp_lastload(k2) { cp_drop(c2); }
                        } else if cp_n < CP_N && d < 64 && j < cp_lastload(k2) {
                            i64 h2 = cp_take(dcls, mention);
                            if h2 != 0 {
                                cp_copy(j);
                                cp_emit(IR_COPY, h2, d, 0, 0, 0);
                                if d < 64 { cp_kill_reg(d); }
                                i64 c3 = cp_n;
                                cp_n += 1;
                                cp_off[c3] = k2;
                                cp_reg[c3] = h2;
                                cp_cls[c3] = dcls;
                                done = true;
                            }
                        }
                    } else if op == IR_BITS2F && ir_a[j] >= 1 && ir_a[j] < 64 && cp_fv[ir_a[j]] != 0 && d >= 32 && d < 64 {
                        i64 src = cp_fv[ir_a[j]];
                        cp_emit(IR_COPY, d, src, 0, 0, 0);
                        cp_kill_reg(d);
                        cp_changes += 1;
                        done = true;
                    } else if (op == IR_LOAD || op == IR_STORE) && ir_a[j] == 30 {
                        // another width: a cell that it touches is not known any more
                        i64 kk = ir_k[j];
                        i64 ww = ir_w[j];
                        if ww < 0 { ww = 0 - ww; }
                        i64 ci = 0;
                        while ci < cp_n {
                            if cp_off[ci] < kk + ww && cp_off[ci] + 8 > kk {
                                cp_n -= 1;
                                cp_off[ci] = cp_off[cp_n]; cp_reg[ci] = cp_reg[cp_n]; cp_cls[ci] = cp_cls[cp_n];
                            } else {
                                ci += 1;
                            }
                        }
                    }
                    if !done {
                        cp_copy(j);
                        if d != 0 {
                            cp_kill_reg(d);
                            if op == IR_F2BITS && d >= 1 && d < 64 && ir_vcls[d] == 0 && ir_a[j] >= 32 && ir_a[j] < 64 && ir_a[j] != d { cp_fv[d] = ir_a[j]; }
                        }
                    }
                    j += 1;
                }
                if cp_changes != before {
                    cp_blocks += 1;
                    if (ir_opt & 4194304) != 0 { write_err("promoted block "); write_err_int(cp_blocks); write_err(" of "); write_err(@ir_fname); write_err(" B"); write_err_int(b); write_err("\n"); }
                    ir_bs[b] = start;
                    ir_be[b] = ir_n;
                } else {
                    ir_n = start;
                }
            }
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- vectors written and read again
// A 16-byte store and a 16-byte load of the same place (the same base vreg and number) in one block, with no other store, call or
// change of the base in between: the load is a copy of the stored vector. (The store stays: another pass may find it dead.)
i64 vf_a[8];
i64 vf_k[8];
i64 vf_v[8];
i64 vf_n;
i64 vf_changes;

void vf_kill_reg(i64 r) {
    i64 j = 0;
    i64 m = 0;
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
    i64 b = 0;
    while b < ir_nb {
        vf_n = 0;
        i64 i = ir_bs[b];
        while i < ir_be[b] {
            i64 op = ir_op[i];
            if op == IR_LOAD && ir_w[i] == 16 && ir_vcls[ir_d[i]] == 2 {
                i64 j = 0;
                i64 hit = 0 - 1;
                while j < vf_n {
                    if vf_a[j] == ir_a[i] && vf_k[j] == ir_k[i] { hit = j; }
                    j += 1;
                }
                if hit >= 0 {
                    i64 v = vf_v[hit];
                    i64 d = ir_d[i];
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
i64 ci_changes;

// the size in bytes of the copy made by the call i, or -1 if it is not a small copy of known size
i64 ci_size(i64 b, i64 i) {
    if ir_op[i] != IR_CALL { return 0 - 1; }
    if !str_eq(@ir_name + ir_k[i] * 64, "j2k_copy") && !str_eq(@ir_name + ir_k[i] * 64, "j2k_copy16") { return 0 - 1; }
    i64 j = i - 1;
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
    i64 nb0 = ir_nb;
    i64 b = 0;
    while b < nb0 {
        if op_po[b] >= 0 {
            i64 need = 0;
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                i64 sz = ci_size(b, i);
                if sz > 0 { need += sz / 4; }
                i += 1;
            }
            if need > 0 && ir_n + (ir_be[b] - ir_bs[b]) + need + 4 < IR_MAXI && ir_nv + need < IR_MAXV - 8 {
                i64 ns = ir_n;
                i64 e0 = ir_be[b];
                i = ir_bs[b];
                while i < e0 {
                    i64 sz2 = ci_size(b, i);
                    if sz2 > 0 {
                        i64 off = 0;
                        bool as_vec = sz2 == 16 && str_eq(@ir_name + ir_k[i] * 64, "j2k_copy16");
                        if as_vec {
                            // a simd value: one 16-byte load and store
                            i64 tq = ir_vreg(2);
                            i64 lq = ir_n;
                            ir_op[lq] = IR_LOAD; ir_d[lq] = tq; ir_a[lq] = 1; ir_b[lq] = 0; ir_bi[lq] = 0; ir_k[lq] = 0; ir_w[lq] = 16;
                            ir_t1[lq] = 0 - 1; ir_t2[lq] = 0 - 1; ir_as[lq] = 0; ir_ac[lq] = 0;
                            i64 sq = lq + 1;
                            ir_op[sq] = IR_STORE; ir_d[sq] = 0; ir_a[sq] = 4; ir_b[sq] = tq; ir_bi[sq] = 0; ir_k[sq] = 0; ir_w[sq] = 16;
                            ir_t1[sq] = 0 - 1; ir_t2[sq] = 0 - 1; ir_as[sq] = 0; ir_ac[sq] = 0;
                            ir_n += 2;
                            off = sz2;
                        }
                        while off < sz2 {
                            i64 t = ir_vreg(0);
                            i64 l = ir_n;
                            ir_op[l] = IR_LOAD; ir_d[l] = t; ir_a[l] = 1; ir_b[l] = 0; ir_bi[l] = 0; ir_k[l] = off; ir_w[l] = 8;
                            ir_t1[l] = 0 - 1; ir_t2[l] = 0 - 1; ir_as[l] = 0; ir_ac[l] = 0;
                            i64 s = l + 1;
                            ir_op[s] = IR_STORE; ir_d[s] = 0; ir_a[s] = 4; ir_b[s] = t; ir_bi[s] = 0; ir_k[s] = off; ir_w[s] = 8;
                            ir_t1[s] = 0 - 1; ir_t2[s] = 0 - 1; ir_as[s] = 0; ir_ac[s] = 0;
                            ir_n += 2;
                            off += 8;
                        }
                        ci_changes += 1;
                    } else {
                        i64 j2 = ir_n;
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
i64 is_i0[IS_MAXF];              // the first instruction in the store
i64 is_ni[IS_MAXF];
i64 is_b0[IS_MAXF];
i64 is_nb[IS_MAXF];
i64 is_a0[IS_MAXF];
i64 is_n0[IS_MAXF];              // its names (64 characters each in is_names)
i64 is_frame[IS_MAXF];
i64 is_h0[IS_MAXF];              // its hint line in is_hint
i64 is_hn[IS_MAXF];
i64 is_nv[IS_MAXF];              // how many vregs it uses (the classes of those from 64 are in is_vc from is_v0)
i64 is_v0[IS_MAXF];
i64 is_recursive[IS_MAXF];
i64 is_size[IS_MAXF];                 // instructions that do something
i64 is_count;
i64 is_ti;
i64 is_tb;
i64 is_ta;
i64 is_tn;
i64 is_th;
i64 is_tv;

i64 is_op[IS_MAXI];
i64 is_d[IS_MAXI];
i64 is_a[IS_MAXI];
i64 is_b[IS_MAXI];
i64 is_bi[IS_MAXI];
i64 is_k[IS_MAXI];
i64 is_w[IS_MAXI];
i64 is_t1[IS_MAXI];
i64 is_t2[IS_MAXI];
i64 is_as[IS_MAXI];
i64 is_ac[IS_MAXI];
i64 is_args[IS_MAXA];
i64 is_bs[IS_MAXB];
i64 is_be[IS_MAXB];
char is_names[262144];
char is_hint[65536];
i64 is_vc[IS_MAXV];

i64 inl_done;                    // how many calls were replaced by their bodies (all functions)
i64 inl_maxsize = 60;
i64 inl_tiny = 30;               // a callee this small is inlined everywhere, a bigger one only inside loops            // the biggest callee (instructions that do something)

i64 is_ht[4096];                 // the kept functions by name: the index + 1 (open addressing); is_ht_n says how many are in it
i64 is_ht_n;

i64 is_hash(char^ name) {
    i64 h = 5381;
    i64 k = 0;
    while name[k] != 0 {
        h = (h * 33 + name[k]) & 1073741823;
        k += 1;
    }
    return h & 4095;
}

i64 is_find(char^ name) {
    if is_ht_n != is_count {
        // the table is made again when the number of kept functions is not the one it knows (a new collection)
        i64 z = 0;
        while z < 4096 {
            is_ht[z] = 0;
            z += 1;
        }
        i64 f0 = 0;
        while f0 < is_count {
            i64 h0 = is_hash(@is_fname + f0 * 64);
            while is_ht[h0] != 0 { h0 = (h0 + 1) & 4095; }
            is_ht[h0] = f0 + 1;
            f0 += 1;
        }
        is_ht_n = is_count;
    }
    i64 h = is_hash(name);
    while is_ht[h] != 0 {
        i64 f = is_ht[h] - 1;
        if str_eq(@is_fname + f * 64, name) { return f; }
        h = (h + 1) & 4095;
    }
    return 0 - 1;
}

// keep the function that is in the ir_ arrays now (if it is small and fine to copy)
void is_save(char^ name) {
    if is_count >= IS_MAXF { return; }
    if str_len(name) >= 63 { return; }
    i64 cnt = op_count();
    if cnt > inl_maxsize || ir_nb > 40 { return; }
    i64 total_b = ir_nb;
    i64 total_i = 0;
    i64 b = 0;
    while b < ir_nb {
        total_i += ir_be[b] - ir_bs[b];
        b += 1;
    }
    if is_ti + total_i >= IS_MAXI || is_tb + total_b >= IS_MAXB || is_ta + ir_nargs >= IS_MAXA || is_tn + ir_nnames >= IS_MAXN || is_th + lf_hint_n >= 65000 || is_tv + ir_nv >= IS_MAXV { return; }
    // no indirect calls, no system calls in the middle, and it must not call itself
    i64 rec = 0;
    b = 0;
    while b < ir_nb {
        i64 i = ir_bs[b];
        while i < ir_be[b] {
            if ir_op[i] == IR_CALLIND { return; }
            // the frame pointer may only be the base of a load / store, or the first operand of an add of a number (the slots are moved when the function is inlined)
            i64 o5 = ir_op[i];
            if o5 == IR_CALL || o5 == IR_SYSCALL {
                i64 g5 = 0;
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
    i64 f = is_count;
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
    i64 at = is_ti;
    b = 0;
    while b < ir_nb {
        is_bs[is_tb + b] = at - is_ti;
        i64 i2 = ir_bs[b];
        while i2 < ir_be[b] {
            is_op[at] = ir_op[i2]; is_d[at] = ir_d[i2]; is_a[at] = ir_a[i2]; is_b[at] = ir_b[i2]; is_bi[at] = ir_bi[i2];
            is_k[at] = ir_k[i2]; is_w[at] = ir_w[i2]; is_t1[at] = ir_t1[i2]; is_t2[at] = ir_t2[i2];
            is_ac[at] = ir_ac[i2];
            if ir_ac[i2] > 0 {
                is_as[at] = is_ta;
                i64 g = 0;
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
    i64 n = 0;
    while n < ir_nnames {
        str_copy(@is_names + (is_tn + n) * 64, @ir_name + n * 64, 64);
        n += 1;
    }
    is_tn += ir_nnames;
    i64 h = 0;
    while h < lf_hint_n {
        is_hint[is_th + h] = lf_hint_text[h];
        h += 1;
    }
    is_th += lf_hint_n;
    i64 v = 0;
    while v < ir_nv {
        is_vc[is_tv + v] = ir_vcls[v];
        v += 1;
    }
    is_tv += ir_nv;
    is_count += 1;
}

// write one instruction at the end of the arrays
i64 in_put(i64 op, i64 d, i64 a, i64 b, i64 bi, i64 k, i64 w, i64 t1, i64 t2) {
    i64 j = ir_n;
    ir_op[j] = op; ir_d[j] = d; ir_a[j] = a; ir_b[j] = b; ir_bi[j] = bi; ir_k[j] = k; ir_w[j] = w;
    ir_t1[j] = t1; ir_t2[j] = t2; ir_as[j] = 0; ir_ac[j] = 0;
    ir_n += 1;
    return j;
}

i64 in_map[IS_MAXV];

i64 in_v(i64 v) {
    if v >= 64 { return in_map[v]; }
    return v;
}

// the hint line of the callee, its offsets moved by delta, added to the hint line of the caller
void in_hint(i64 f, i64 delta) {
    i64 n = is_hn[f];
    i64 base = is_h0[f];
    i64 p = 2;
    while p < n {
        while p < n && is_hint[base + p] == ' ' { p += 1; }
        if p < n {
            i64 off = 0;
            while p < n && is_hint[base + p] >= '0' && is_hint[base + p] <= '9' { off = off * 10 + (is_hint[base + p] - '0'); p += 1; }
            p += 1;
            i64 size = 0;
            while p < n && is_hint[base + p] >= '0' && is_hint[base + p] <= '9' { size = size * 10 + (is_hint[base + p] - '0'); p += 1; }
            p += 1;
            i64 flag = 0;
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
                i64 parts[3];
                parts[0] = off + delta;
                parts[1] = size;
                parts[2] = flag;
                i64 q = 0;
                while q < 3 {
                    char dg[12];
                    i64 dn = 0;
                    i64 dv = parts[q];
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
bool in_inline(i64 b, i64 c, i64 f) {
    i64 nbc = is_nb[f];
    // room
    if ir_nb + nbc + 2 >= IR_MAXB - 2 || ir_n + 2 * (ir_be[b] - ir_bs[b]) + 4 * is_ni[f] + 64 >= IR_MAXI || ir_nv + is_nv[f] >= IR_MAXV - 8 { return false; }
    // the temporaries of the callee get new vregs
    i64 v = 64;
    while v < is_nv[f] {
        in_map[v] = ir_vreg(is_vc[is_v0[f] + v]);
        v += 1;
    }
    // frame: the slots (offsets from 16) move up by delta; the stack cells (negative offsets) go below the deepest one of the caller
    i64 delta = lf_frame - 16;
    i64 neg = op_maxq();
    lf_frame = lf_frame + is_frame[f] - 16;
    in_hint(f, delta);
    i64 base = ir_nb;
    i64 kb = base + nbc;                      // the second half of the block of the call
    // the first half: the instructions before the call, then a jump into the copy
    i64 s0 = ir_n;
    i64 i = ir_bs[b];
    while i < c {
        i64 j = in_put(ir_op[i], ir_d[i], ir_a[i], ir_b[i], ir_bi[i], ir_k[i], ir_w[i], ir_t1[i], ir_t2[i]);
        ir_as[j] = ir_as[i];
        ir_ac[j] = ir_ac[i];
        i += 1;
    }
    in_put(IR_JMP, 0, 0, 0, 0, 0, 0, base, 0 - 1);
    i64 oldend = ir_be[b];
    i64 oldstart = ir_bs[b];
    // the copy of the callee's blocks
    i64 cb = 0;
    while cb < nbc {
        i64 bid = base + cb;
        ir_bs[bid] = ir_n;
        i64 ci = is_i0[f] + is_bs[is_b0[f] + cb];
        i64 ce = is_i0[f] + is_be[is_b0[f] + cb];
        while ci < ce {
            i64 op = is_op[ci];
            i64 d = is_d[ci];
            if op == IR_PARAM || (op == IR_ADDR_SLOT && d == 30) {
                ci += 1;
                continue;
            }
            i64 a = is_a[ci];
            i64 k = is_k[ci];
            i64 bb = is_b[ci];
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
            i64 t1 = is_t1[ci];
            i64 t2 = is_t2[ci];
            if op == IR_JMP || op == IR_BR || op == IR_FBR { t1 = t1 + base; }
            if op == IR_BR || op == IR_FBR { t2 = t2 + base; }
            if op == IR_CALL || op == IR_ADDR_FUNC {
                k = ir_name_index(@is_names + (is_n0[f] + k) * 64);          // the address of a function names it too (an inlined callee that uses `op = add`)
            }
            i64 j2 = in_put(op, in_v(d), in_v(a), bb, is_bi[ci], k, is_w[ci], t1, t2);
            if is_ac[ci] > 0 {
                i64 regs[16];
                i64 g = 0;
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
        i64 j3 = in_put(ir_op[i], ir_d[i], ir_a[i], ir_b[i], ir_bi[i], ir_k[i], ir_w[i], ir_t1[i], ir_t2[i]);
        ir_as[j3] = ir_as[i];
        ir_ac[j3] = ir_ac[i];
        i += 1;
    }
    ir_be[kb] = ir_n;
    ir_blab[kb] = 0 - 1;
    i64 z = 0;
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

i64 inl_inloop[IR_MAXB];

// the blocks that are in a loop of the function now
void inl_find_loops() {
    op_graph();
    i64 b = 0;
    while b < ir_nb {
        inl_inloop[b] = 0;
        b += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 sc = op_succ(b, k);
                if sc >= 0 && op_dom(sc, b) {
                    // the loop of the back edge b -> sc: sc and everything that reaches b without passing sc
                    op_stamp += 1;
                    op_mark[sc] = op_stamp;
                    inl_inloop[sc] = 1;
                    i64 sp = 0;
                    if b != sc {
                        op_mark[b] = op_stamp;
                        op_stack[0] = b;
                        sp = 1;
                    }
                    while sp > 0 {
                        sp -= 1;
                        i64 x = op_stack[sp];
                        inl_inloop[x] = 1;
                        i64 e = op_phead[x];
                        while e >= 0 {
                            i64 p = e / 2;
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
    i64 b0 = 0;
    while b0 < ir_nb && !any {
        i64 i0 = ir_bs[b0];
        while i0 < ir_be[b0] && !any {
            if ir_op[i0] == IR_CALL && is_find(@ir_name + ir_k[i0] * 64) >= 0 { any = true; }
            i0 += 1;
        }
        b0 += 1;
    }
    if !any { return; }
    inl_find_loops();
    i64 guard = 0;
    bool again = true;
    while again && guard < 12 {
        again = false;
        i64 b = 0;
        while b < ir_nb && !again {
            i64 i = ir_bs[b];
            while i < ir_be[b] && !again {
                if ir_op[i] == IR_CALL && ir_n < 2500 {
                    i64 f = is_find(@ir_name + ir_k[i] * 64);
                    if f >= 0 && is_recursive[f] == 0 && !str_eq(@is_fname + f * 64, self) && (is_size[f] <= inl_tiny || (inl_inloop[b] == 1 && is_size[f] <= inl_maxsize)) {
                        i64 nb_before = ir_nb;
                        bool inloop = inl_inloop[b] == 1;
                        if in_inline(b, i, f) {
                            // the new blocks are in a loop if the block of the call was
                            i64 z = nb_before;
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
i64 lc_D[64];                   // how many instructions of the loop write the register (a call writes all the registers it clobbers)
i64 lc_in[IR_MAXB];
i64 lc_taken[IR_MAXI];
i64 lc_mem[64];                 // the instructions of the slice being built
i64 lc_nm;
i64 lc_hl[2048];                // the instructions to move in order, the slices one after the other; -1 ends a slice
i64 lc_nh;
i64 lc_from[64];
i64 lc_to[64];
i64 lc_nmap;
i64 lc_keep;                    // the instruction that makes the value the root store writes and that something else in the loop reads too: it becomes a load of the cell
i64 lc_kl[256];
i64 lc_kk[256];
i64 lc_nkl;
i64 lc_live;                    // the registers live at the entrance of the loop (the moved code may not write them)
i64 lc_moved;                   // how many instructions were moved (for the statistics)
i64 lc_nst[16384];              // the stores to each plain frame slot (index offset / 8) and stack cell (8192 + (-offset) / 8) in the loop
i64 lc_ldo[16384];              // 1: a load of the slot outside the loop
i64 lc_rootb;                   // the block and the index of the store that is the root (for the check of the loads)
i64 lc_rooti;
i64 lc_rootslot;

// a load of a plain 8-byte frame slot that the loop never writes
bool lc_inv_load(i64 m) {
    if ir_op[m] != IR_LOAD || ir_a[m] != 30 || !(ir_w[m] == 8 || ((ir_w[m] == 4 || ir_w[m] == 0 - 4) && (ir_opt & 35184372088832) == 0)) { return false; }       // a 32-bit local (load.-4) of a plain slot too
    i64 k = ir_k[m];
    if k % 8 != 0 { return false; }
    if k < 0 { return (0 - k) / 8 < 8192 && lc_nst[8192 + (0 - k) / 8] == 0; }
    if k / 8 >= 8192 { return false; }
    return op_plain[k / 8] == 1 && lc_nst[k / 8] == 0;
}

// the index of a frame slot or a stack cell (-1: not a whole slot)
i64 lc_ci(i64 k) {
    if k % 8 != 0 { return 0 - 1; }
    if k >= 0 {
        if k / 8 < 8192 { return k / 8; }
        return 0 - 1;
    }
    if (0 - k) / 8 < 8192 { return 8192 + (0 - k) / 8; }
    return 0 - 1;
}

bool lc_pure(i64 op) {
    if op == IR_CONST || op == IR_COPY { return true; }
    if op >= IR_ADD && op <= IR_MULHS && op != IR_SDIV && op != IR_UDIV { return true; }
    if op == IR_NEG || op == IR_NOT || op == IR_EXT { return true; }
    if op >= IR_FADD && op <= IR_FFLOOR { return true; }
    if op == IR_I2F || op == IR_FCONST || op == IR_BITS2F || op == IR_F2BITS { return true; }
    return false;
}

// the registers an instruction reads: a (when it is a register) and b (when it is a register): -1 for none
i64 lc_src(i64 i, i64 which) {
    i64 op = ir_op[i];
    if op == IR_CONST || op == IR_FCONST { return 0 - 1; }
    if which == 0 {
        if ir_a[i] > 0 { return ir_a[i]; }
        return 0 - 1;
    }
    if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] > 0 { return ir_b[i]; }
    return 0 - 1;
}

bool lc_in_slice(i64 m) {
    i64 q = 0;
    while q < lc_nm {
        if lc_mem[q] == m { return true; }
        q += 1;
    }
    return false;
}

// the slice that makes the value of instruction root (in block b); true when it can move
bool lc_slice(i64 b, i64 root) {
    lc_nm = 1;
    lc_mem[0] = root;
    i64 qi = 0;
    while qi < lc_nm {
        i64 k = lc_mem[qi];
        i64 w = 0;
        while w < 2 {
            i64 r = lc_src(k, w);
            if r >= 1 {
                i64 m = 0 - 1;
                i64 j = k - 1;
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
        i64 best = 0 - 1;
        i64 c = 1;
        while c < lc_nm {
            if ir_d[lc_mem[c]] == ir_b[root] && lc_mem[c] < root && lc_mem[c] > best { best = lc_mem[c]; }
            c += 1;
        }
        lc_keep = best;
    }
    // the scratch registers of the slice are read by nothing outside it, and the entrance of the loop does not need their values
    i64 a = 1;
    while a < lc_nm {
        i64 m2 = lc_mem[a];
        i64 r2 = ir_d[m2];
        if r2 >= 64 || r2 < 1 || (lc_live & (1 << r2)) != 0 { return false; }
        if m2 == lc_keep { a += 1; continue; }
        i64 j2 = m2 + 1;
        bool redef = false;
        while j2 < ir_be[b] && !redef {
            if !lc_in_slice(j2) && ir_op[j2] != IR_NOP {
                if lc_src(j2, 0) == r2 || lc_src(j2, 1) == r2 { return false; }
                i64 opj = ir_op[j2];
                if opj == IR_STORE && ir_b[j2] == r2 { return false; }
                if opj == IR_CALL || opj == IR_CALLIND || opj == IR_SYSCALL {
                    i64 g = 0;
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
i64 lc_bop[1024];
i64 lc_bd[1024];
i64 lc_ba[1024];
i64 lc_bb[1024];
i64 lc_bbi[1024];
i64 lc_bk[1024];
i64 lc_bw[1024];
i64 lc_nb2;
i64 lc_q;                       // the deepest stack cell used (a new cell is 8 deeper)
i64 lc_tl[16384];               // the cells and slots that the function touches (each once)
i64 lc_ntl;
i64 lc_tmark[16384];
i64 lc_tstamp;
i64 lc_tot[16384];              // the loads of each slot / cell in the whole function that do not follow a store of the cell in their own block (stack cells) or any load (slots)

// the loads of the whole function (once, and again after a loop was changed)
void lc_prep() {
    i64 zi = 0;
    while zi < lc_ntl {
        lc_tot[lc_tl[zi]] = 0;
        zi += 1;
    }
    lc_ntl = 0;
    lc_tstamp += 1;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i3 = ir_bs[b];
            i64 seen_st[40];
            i64 nseen = 0;
            while i3 < ir_be[b] {
                if ir_a[i3] == 30 && ir_op[i3] != IR_NOP && lc_ci(ir_k[i3]) >= 0 {
                    i64 ws = lc_ci(ir_k[i3]);
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
                            i64 sq = 0;
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
void lc_count(i64 h) {
    i64 r = 0;
    while r < 64 {
        lc_D[r] = 0;
        r += 1;
    }
    i64 zz = 0;
    while zz < lc_ntl {
        i64 ti = lc_tl[zz];
        lc_nst[ti] = 0;
        lc_ldo[ti] = lc_tot[ti];
        zz += 1;
    }
    i64 b = 0;
    while b < ir_nb {
        if lc_in[b] == 1 {
            i64 i = ir_bs[b];
            i64 seen_st[40];
            i64 nseen = 0;
            while i < ir_be[b] {
                i64 op = ir_op[i];
                if op != IR_NOP {
                    i64 dm = op_defs(i);
                    if op == IR_SYSCALL { dm = dm | op_clobber(); }
                    i64 v = 1;
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
                        i64 ws = lc_ci(ir_k[i]);
                        if op == IR_STORE { lc_nst[ws] += 1; if nseen < 40 { seen_st[nseen] = ws; nseen += 1; } }
                        if op == IR_LOAD {
                            // the loads inside the loop are not "outside"
                            bool own = false;
                            if ir_k[i] < 0 {
                                i64 sq = 0;
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
    i64 a = 0;
    while a < lc_nm {
        i64 op = ir_op[lc_mem[a]];
        if op == IR_MUL || op == IR_MULHS || op == IR_FMUL || op == IR_FDIV || op == IR_FSQRT { return true; }
        a += 1;
    }
    return lc_nm >= 3;
}

// is the store i2 (in block b) a root that can be moved? every load of its slot in the loop comes after it
bool lc_store_ok(i64 b, i64 i2) {
    if ir_op[i2] != IR_STORE || ir_a[i2] != 30 || ir_w[i2] != 8 || lc_taken[i2] != 0 { return false; }
    i64 sk = lc_ci(ir_k[i2]);
    if sk < 0 { return false; }
    if !(ir_k[i2] < 0 || op_plain[sk] == 1) { return false; }
    if lc_nst[sk] != 1 || lc_ldo[sk] != 0 || ir_b[i2] <= 0 || ir_bi[i2] != 0 { return false; }
    i64 lb = 0;
    while lb < ir_nb {
        if lc_in[lb] == 1 {
            i64 li = ir_bs[lb];
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
bool lc_loop(i64 h) {
    // the blocks of the loop
    i64 b = 0;
    while b < ir_nb {
        lc_in[b] = 0;
        b += 1;
    }
    lc_in[h] = 1;
    i64 sp = 0;
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && b != h {
            i64 k = 0;
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
        i64 x = op_stack[sp];
        i64 e = op_phead[x];
        while e >= 0 {
            i64 p = e / 2;
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
    i64 attempts = 0;
    bool found = true;
    while found && attempts < 40 && lc_nb2 < 900 {
        found = false;
        attempts += 1;
        lc_count(h);
        b = 0;
        while b < ir_nb && !found {
            if lc_in[b] == 1 {
                i64 i2 = ir_bs[b];
                i64 e2 = ir_be[b];
                while i2 < e2 && !found {
                    i64 op2 = ir_op[i2];
                    i64 d = ir_d[i2];
                    bool cand = false;
                    if op2 == IR_STORE { cand = lc_store_ok(b, i2); }
                    else if op2 != IR_NOP && lc_taken[i2] == 0 && lc_pure(op2) && op2 != IR_CONST && d >= 1 && d <= 63 && lc_D[d] == 1 && (lc_live & (1 << d)) == 0 { cand = true; }
                    bool value_root = false;
                    if !cand && op2 != IR_NOP && op2 != IR_STORE && op2 != IR_CONST && op2 != IR_COPY && lc_pure(op2) && d >= 1 && d <= 63 && lc_D[d] >= 1 { value_root = true; }
                    if value_root && !(lc_slice(b, i2) && lc_nm >= 2 && lc_worth()) { value_root = false; }
                    if (cand || value_root) && (value_root || lc_slice(b, i2)) {
                        if value_root { lc_keep = 0 - 1; }
                        // in the order of the instructions
                        i64 a = 0;
                        while a < lc_nm {
                            i64 c = a + 1;
                            while c < lc_nm {
                                if lc_mem[c] < lc_mem[a] {
                                    i64 t = lc_mem[a];
                                    lc_mem[a] = lc_mem[c];
                                    lc_mem[c] = t;
                                }
                                c += 1;
                            }
                            a += 1;
                        }
                        // the move: the copies go to the buffer, the originals go away (or become a load of the cell)
                        i64 vcell = 0;
                        if value_root {
                            // the value of the last instruction is kept in a new cell: written once before the loop, read where it was made
                            lc_q += 8;
                            vcell = 0 - lc_q;
                        }
                        a = 0;
                        while a < lc_nm && lc_nb2 < 1000 {
                            i64 m = lc_mem[a];
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
    i64 nb0 = ir_nb;
    i64 pre = ir_new_block(0 - 1);
    ir_set_block(pre);
    i64 hi = 0;
    while hi < lc_nb2 {
        i64 ni = ir_add(lc_bop[hi], lc_bd[hi], lc_ba[hi], lc_bb[hi], lc_bbi[hi], lc_bk[hi]);
        ir_w[ni] = lc_bw[hi];
        hi += 1;
    }
    i64 jm = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jm] = h;
    // every jump to the header from outside the loop goes to the new block
    b = 0;
    while b < nb0 {
        if lc_in[b] == 0 {
            i64 t = ir_be[b] - 1;
            i64 top = ir_op[t];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[t] == h { ir_t1[t] = pre; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[t] == h { ir_t2[t] = pre; }
        }
        b += 1;
    }
    return true;
}

// all the loops, the innermost first (a header is found by its back edge; a header that is deeper in the tree of dominators is inner)
i64 lc_us;                      // the time of this pass (the microseconds, for -xtime)
i64 lc_calls;
void op_licm_exprs() {
    i64 t0 = 0;
    if x_time == 1 { t0 = tm_now(); lc_calls += 1; }
    op_licm_run();
    if x_time == 1 { lc_us += tm_now() - t0; }
}

void op_licm_run() {
    op_graph();
    i64 zc = 0;
    while zc < 16384 {              // nothing may be left from the function before (docs/design/16-separate-compilation.md, -xrepeat)
        lc_nst[zc] = 0;
        lc_ldo[zc] = 0;
        lc_tot[zc] = 0;
        lc_tmark[zc] = 0;
        zc += 1;
    }
    lc_ntl = 0;
    i64 hs[64];
    i64 hd[64];
    i64 nh = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 s = op_succ(b, k);
                if s > 0 && op_dom(s, b) && nh < 60 {
                    bool seen = false;
                    i64 z = 0;
                    while z < nh {
                        if hs[z] == s { seen = true; }
                        z += 1;
                    }
                    if !seen {
                        i64 dep = 0;
                        i64 x = s;
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
    i64 i = 1;
    while i < nh {
        i64 th = hs[i];
        i64 td = hd[i];
        i64 j = i - 1;
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
i64 dc_read[16384];
i64 dc_changes;

void op_dead_cells() {
    if (ir_opt & 524288) != 0 { return; }
    i64 i = 0;
    while i < 16384 {
        dc_read[i] = 0;
        i += 1;
    }
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] == IR_LOAD && ir_a[j] == 30 {
                    i64 k = ir_k[j];
                    i64 w = ir_w[j];
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
            i64 j2 = ir_bs[b];
            while j2 < ir_be[b] {
                if ir_op[j2] == IR_STORE && ir_a[j2] == 30 && ir_w[j2] == 8 {
                    i64 k2 = ir_k[j2];
                    i64 sl = 0 - 1;
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


// ---------------------------------------------------------------------------------------------- dead stores to the temporary cells
// The cells below the frame pointer (k < 0) are temporaries of the front end and of inlined calls: the same cell holds a different value in
// each statement (the address of a struct that is passed, a saved argument). A store to such a cell that is overwritten (or never read)
// before the next load on every path does nothing. The cells are followed with a bit for each one (at most 60), backwards over the blocks.
// Done only when no address below the base is taken and every access is a whole aligned word. When the stored value was an address of a
// frame object, the address computation is dead then and the object may become plain words (op_sroa).

#define DT_MAXC 60
i64 dt_cell[DT_MAXC];
i64 dt_n;
i64 dt_use[IR_MAXB];
i64 dt_def[IR_MAXB];
i64 dt_in[IR_MAXB];
i64 dt_changes;

i64 dt_index(i64 k) {
    i64 i = 0;
    while i < dt_n {
        if dt_cell[i] == k { return i; }
        i += 1;
    }
    if dt_n >= DT_MAXC { return 0 - 1; }
    dt_cell[dt_n] = k;
    dt_n += 1;
    return dt_n - 1;
}

void op_dead_temps() {
    if (ir_opt & 33554432) != 0 { return; }
    op_graph();
    vn_hints();
    dt_n = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                i64 op = ir_op[j];
                if (op == IR_LOAD || op == IR_STORE) && ir_a[j] == 30 && ir_k[j] < 0 {
                    i64 w = ir_w[j];
                    if w < 0 { w = 0 - w; }
                    if w != 8 || (ir_k[j] % 8) != 0 { return; }
                    if dt_index(ir_k[j]) < 0 { return; }
                } else if (op == IR_ADDR_SLOT && ir_d[j] != 30 && ir_k[j] < 0) || (op == IR_ADD && ir_a[j] == 30 && ir_bi[j] == 1 && ir_b[j] < 0) {
                    return;
                } else if ir_a[j] == 30 && op != IR_LOAD && op != IR_STORE && op != IR_ADDR_SLOT && !(op == IR_ADD && ir_bi[j] == 1) {
                    return;
                } else if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] == 30 && op != IR_STORE {
                    return;
                } else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                    i64 g = 0;
                    while g < ir_ac[j] {
                        if ir_args[ir_as[j] + g] == 30 { return; }
                        g += 1;
                    }
                }
                j += 1;
            }
        }
        b += 1;
    }
    if dt_n == 0 { return; }
    b = 0;
    while b < ir_nb {
        dt_use[b] = 0;
        dt_def[b] = 0;
        dt_in[b] = 0;
        if op_po[b] >= 0 {
            i64 j2 = ir_bs[b];
            while j2 < ir_be[b] {
                if ir_op[j2] == IR_LOAD && ir_a[j2] == 30 && ir_k[j2] < 0 {
                    i64 c = dt_index(ir_k[j2]);
                    if (dt_def[b] & (1 << c)) == 0 { dt_use[b] = dt_use[b] | (1 << c); }
                } else if ir_op[j2] == IR_STORE && ir_a[j2] == 30 && ir_k[j2] < 0 {
                    dt_def[b] = dt_def[b] | (1 << dt_index(ir_k[j2]));
                }
                j2 += 1;
            }
        }
        b += 1;
    }
    bool again = true;
    while again {
        again = false;
        b = ir_nb - 1;
        while b >= 0 {
            if op_po[b] >= 0 {
                i64 out = 0;
                i64 k = 0;
                while k < 2 {
                    i64 s = op_succ(b, k);
                    if s >= 0 { out = out | dt_in[s]; }
                    k += 1;
                }
                i64 nin = dt_use[b] | (out & (0 - 1 - dt_def[b]));
                if nin != dt_in[b] { dt_in[b] = nin; again = true; }
            }
            b -= 1;
        }
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 live = 0;
            i64 k2 = 0;
            while k2 < 2 {
                i64 s2 = op_succ(b, k2);
                if s2 >= 0 { live = live | dt_in[s2]; }
                k2 += 1;
            }
            i64 j3 = ir_be[b] - 1;
            while j3 >= ir_bs[b] {
                if ir_op[j3] == IR_STORE && ir_a[j3] == 30 && ir_k[j3] < 0 {
                    i64 c2 = dt_index(ir_k[j3]);
                    if (live & (1 << c2)) == 0 {
                        ir_op[j3] = IR_NOP;
                        ir_d[j3] = 0;
                        ir_a[j3] = 0;
                        ir_bi[j3] = 1;
                        dt_changes += 1;
                    } else {
                        live = live & (0 - 1 - (1 << c2));
                    }
                } else if ir_op[j3] == IR_LOAD && ir_a[j3] == 30 && ir_k[j3] < 0 {
                    live = live | (1 << dt_index(ir_k[j3]));
                }
                j3 -= 1;
            }
        }
        b += 1;
    }
}

// ---------------------------------------------------------------------------------------------- stack cells inside one block
// `store [cell], r` ... `d = load [cell]` ... `store [cell], x` in one block: the value only goes through the cell, but r may have been
// written again before the load (the registers are not single-assignment, so value numbering cannot name it). The store becomes
// `d = copy r` (d is neither read nor written in between) and the load goes away. Arguments of inlined calls are passed this way.

i64 cf_changes;

i64 cf_loads[8192];             // the loads of each plain frame slot in the function
i64 cf_nloads[8192];            // the loads of each cell below the frame base (the temporaries): index (0 - offset) / 8; +2 for another width
i64 cf_vesc;                    // 1: the frame base is used as a value (an address of the frame is taken): no cell can be said to be private

void op_cell_fwd() {
    if (ir_opt & 16777216) != 0 { return; }
    vn_hints();
    i64 zi = 0;
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
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 lj = ir_bs[b];
            while lj < ir_be[b] {
                if ir_op[lj] == IR_LOAD && ir_a[lj] == 30 && ir_k[lj] >= 0 && ir_k[lj] / 8 < 8192 {
                    cf_loads[ir_k[lj] / 8] += 1;
                    if ir_k[lj] % 8 != 0 || ir_w[lj] != 8 { cf_loads[ir_k[lj] / 8] += 2; }
                }
                if ir_op[lj] == IR_LOAD && ir_a[lj] == 30 && ir_k[lj] < 0 {
                    // the cells below the base: a load of another width touches two of them
                    i64 nk = (0 - ir_k[lj] + 7) / 8;
                    i64 nk2 = (0 - ir_k[lj] + ir_w[lj] + 6) / 8;
                    if nk >= 0 && nk < 8192 { cf_nloads[nk] += 1; }
                    if nk2 != nk && nk2 < 8192 { cf_nloads[nk2] += 2; }
                    if ir_k[lj] % 8 != 0 || ir_w[lj] != 8 { if nk < 8192 { cf_nloads[nk] += 2; } }
                }
                if ir_op[lj] != IR_NOP {
                    i64 vu = op_uses(lj);
                    bool base_use = (ir_op[lj] == IR_LOAD && ir_a[lj] == 30) || (ir_op[lj] == IR_STORE && ir_a[lj] == 30 && !(ir_bi[lj] == 0 && ir_b[lj] == 30));
                    // the address of an object above the base (add xN, x29, #k with k >= 0) does not reach the cells below it
                    bool above = (ir_op[lj] == IR_ADD && ir_a[lj] == 30 && ir_bi[lj] == 1 && ir_b[lj] >= 0) || (ir_op[lj] == IR_ADDR_SLOT && ir_k[lj] >= 0 && ir_d[lj] != 30);
                    if (vu & op_bit(30)) != 0 && !base_use && !above { cf_vesc = 1; }
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
            i64 s = ir_bs[b];
            i64 mention = op_lo[b];             // the registers that the block names, and the ones that live after it
            i64 mj = ir_bs[b];
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
                    i64 nk = (0 - ir_k[s] + 7) / 8;
                    if nk >= 0 && nk < 8192 && cf_nloads[nk] == 1 { lone = true; }
                }
                if ir_op[s] == IR_STORE && ir_a[s] == 30 && ir_w[s] == 8 && (ir_k[s] < 0 || lone) && ir_bi[s] == 0 {
                    i64 c = ir_k[s];
                    i64 r = ir_b[s];
                    i64 ld = 0 - 1;
                    i64 uses = 0;                     // registers read in between, by a call also the arguments
                    i64 defs = 0;
                    bool over = false;
                    bool bad = false;
                    i64 j = s + 1;
                    while j < ir_be[b] && !over && !bad {
                        i64 op = ir_op[j];
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
                        i64 d = ir_d[ld];
                        i64 bt = op_bit(d);
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
                            i64 t = 0;
                            i64 lo = 1;
                            i64 hi = 14;
                            if ir_vcls[r] == 1 { lo = 32; hi = 39; }
                            i64 tt = lo;
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

i64 cc_cnt[8192];
i64 cc_blk[8192];
i64 cc_pos[8192];
i64 cc_val[8192];
i64 cc_const[8192];
i64 cc_changes;

// the instruction that defines the register r last before the instruction `from` of block b, looking back through blocks that have one way in
// (a jump from a single predecessor); -1 when it is not found there (a call that may change r, a join of paths ...)
i64 cc_def(i64 b, i64 from, i64 r) {
    i64 steps = 0;
    while steps < 8 {
        i64 q = from;
        while q >= ir_bs[b] {
            if ir_d[q] == r && ir_op[q] != IR_NOP { return q; }
            if (ir_op[q] == IR_CALL || ir_op[q] == IR_CALLIND || ir_op[q] == IR_SYSCALL) && r >= 1 && r <= 19 { return 0 - 1; }
            q -= 1;
        }
        // one predecessor?
        i64 e = op_phead[b];
        if e < 0 || op_enext[e] >= 0 { return 0 - 1; }
        i64 pb = e / 2;
        if pb == b || op_po[pb] < 0 { return 0 - 1; }
        b = pb;
        from = ir_be[b] - 2;
        steps += 1;
    }
    return 0 - 1;
}

void op_const_cells() {
    if (ir_opt & 33554432) != 0 { return; }
    vn_hints();
    op_graph();
    i64 i = 0;
    while i < 8192 {
        cc_cnt[i] = 0;
        cc_const[i] = 0;
        i += 1;
    }
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] == IR_STORE && ir_a[j] == 30 && ir_k[j] >= 0 {
                    i64 sl = ir_k[j] / 8;
                    i64 w = ir_w[j];
                    if w < 0 { w = 0 - w; }
                    if sl < 8192 {
                        // a store of a different width or place touches the slot of its first byte only; plain slots are whole words
                        cc_cnt[sl] += 1;
                        if (w != 8 || ir_k[j] % 8 != 0) { cc_cnt[sl] += 2; }
                        cc_blk[sl] = b;
                        cc_pos[sl] = j;
                        // the value: the last definition of the register before the store in this block
                        if ir_bi[j] == 0 {
                            i64 r = ir_b[j];
                            i64 q = cc_def(b, j - 1, r);
                            if q >= 0 && ir_op[q] == IR_CONST && ir_d[q] == r {
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
            i64 j2 = ir_bs[b];
            while j2 < ir_be[b] {
                if ir_op[j2] == IR_LOAD && ir_a[j2] == 30 && ir_k[j2] >= 0 && ir_w[j2] == 8 && ir_k[j2] % 8 == 0 && ir_k[j2] / 8 < 8192 {
                    i64 sl2 = ir_k[j2] / 8;
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

i64 fa_reg[IR_MAXV];
i64 fa_st[IR_MAXV];
i64 fa_cur;
i64 fa_cell[16384];
i64 fa_cst[16384];
i64 fa_changes;

i64 fa_get(i64 r) {
    if r == 30 { return 0; }
    if r < 1 || r >= ir_nv || fa_st[r] != fa_cur { return 0 - 1000000; }
    return fa_reg[r];
}

void fa_set(i64 r, i64 off) {
    if r < 1 || r >= ir_nv { return; }
    fa_reg[r] = off;
    fa_st[r] = fa_cur;
}

void fa_clear(i64 r) {
    if r >= 1 && r < ir_nv { fa_st[r] = 0; }
}

void fa_block(i64 b, i64 cont) {
    if cont == 0 { fa_cur += 1; }
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        i64 op = ir_op[i];
        i64 d = ir_d[i];
        // a load or a store through a frame pointer plus a number
        if (op == IR_LOAD || op == IR_STORE) && ir_a[i] != 30 {
            i64 fo = fa_get(ir_a[i]);
            i64 wq = ir_w[i];
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
            i64 sl = 0 - 1;
            if ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 8192 { sl = 8192 + (0 - ir_k[i]) / 8; }
            else if ir_k[i] >= 0 && ir_k[i] % 8 == 0 && ir_k[i] / 8 < 8192 && op_plain[ir_k[i] / 8] == 1 { sl = ir_k[i] / 8; }
            if sl >= 0 && fa_cst[sl] == fa_cur { fa_set(d, fa_cell[sl]); } else { fa_clear(d); }
        } else if op == IR_STORE && ir_a[i] == 30 && ir_w[i] == 8 {
            i64 sl2 = 0 - 1;
            if ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 8192 { sl2 = 8192 + (0 - ir_k[i]) / 8; }
            else if ir_k[i] >= 0 && ir_k[i] % 8 == 0 && ir_k[i] / 8 < 8192 && op_plain[ir_k[i] / 8] == 1 { sl2 = ir_k[i] / 8; }
            if sl2 >= 0 {
                i64 vo = fa_get(ir_b[i]);
                if vo > 0 - 1000000 && ir_b[i] != 30 { fa_cell[sl2] = vo; fa_cst[sl2] = fa_cur; } else { fa_cst[sl2] = 0; }
            }
        } else if d != 0 {
            fa_clear(d);
        }
        i += 1;
    }
}

// the objects of the frame from the hint line
i64 ob_off[2048];
i64 ob_size[2048];
i64 ob_flag[2048];
i64 ob_esc[2048];
i64 ob_n;

void fa_objects() {
    ob_n = 0;
    i64 n = lf_hint_n;
    i64 p = 2;
    while p < n && ob_n < 2048 {
        while p < n && lf_hint_text[p] == ' ' { p += 1; }
        if p < n {
            i64 off = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { off = off * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            i64 size = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { size = size * 10 + (lf_hint_text[p] - '0'); p += 1; }
            p += 1;
            i64 flag = 0;
            while p < n && lf_hint_text[p] >= '0' && lf_hint_text[p] <= '9' { flag = flag * 10 + (lf_hint_text[p] - '0'); p += 1; }
            ob_off[ob_n] = off;
            ob_size[ob_n] = size;
            ob_flag[ob_n] = flag;
            ob_esc[ob_n] = 0;
            ob_n += 1;
        }
    }
}

i64 fa_object_of(i64 k) {
    i64 j = 0;
    while j < ob_n {
        if k >= ob_off[j] && k < ob_off[j] + ob_size[j] { return j; }
        j += 1;
    }
    return 0 - 1;
}

void op_sroa_finish() {
    fa_objects();
    bool all_esc = false;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                i64 op = ir_op[i];
                i64 k = ir_k[i];
                // the frame pointer in any other use (plus a register, a copy ...): any object may be reached
                if (ir_a[i] == 30 && op != IR_LOAD && op != IR_STORE && !(op == IR_ADD && ir_bi[i] == 1) && op != IR_ADDR_SLOT) { all_esc = true; }
                if ((ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30) && !(op == IR_STORE && false)) { all_esc = true; }
                if (op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL) {
                    i64 g = 0;
                    while g < ir_ac[i] {
                        if ir_args[ir_as[i] + g] == 30 { all_esc = true; }
                        g += 1;
                    }
                }
                if (op == IR_ADDR_SLOT && ir_d[i] != 30) || (op == IR_ADD && ir_a[i] == 30 && ir_bi[i] == 1) {
                    i64 off = k;
                    if op == IR_ADD { off = ir_b[i]; }
                    i64 o = fa_object_of(off);
                    if o >= 0 && !(opt_nullchk == 1 && nc_is_record(i, b, off)) { ob_esc[o] = 1; }
                    if (ir_opt & 262144) != 0 { write_err("  address of "); write_err_int(off); write_err(" by instruction "); write_err_int(i); write_err(" op "); write_err_int(op); write_err("\n"); }
                } else if (op == IR_LOAD || op == IR_STORE) && ir_a[i] == 30 && k >= 16 {
                    i64 o2 = fa_object_of(k);
                    if o2 >= 0 && ob_flag[o2] == 0 {
                        i64 w = ir_w[i];
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
        i64 jj = 0;
        while jj < ob_n {
            ob_esc[jj] = 1;
            jj += 1;
        }
    }
    // the hint line again: an object that was not plain, is not used by its address any more and is made of whole words, is plain words now
    char nt[16384];
    i64 nn = 0;
    nt[0] = ';';
    nt[1] = 'H';
    nn = 2;
    i64 j = 0;
    bool changed = false;
    while j < ob_n && nn < 15000 {
        bool conv = ob_flag[j] == 0 && ob_esc[j] == 0 && ob_size[j] % 8 == 0 && ob_off[j] % 8 == 0 && ob_size[j] <= 128;
        i64 words = 1;
        i64 osz = ob_size[j];
        if conv { words = ob_size[j] / 8; osz = 8; changed = true; }
        if (ir_opt & 262144) != 0 {
            write_err("object "); write_err_int(ob_off[j]); write_err(":"); write_err_int(ob_size[j]); write_err(":"); write_err_int(ob_flag[j]);
            if ob_esc[j] == 1 { write_err(" escaped"); }
            if conv { write_err(" -> words"); }
            write_err("\n");
        }
        i64 w = 0;
        while w < words {
            i64 vals[3];
            vals[0] = ob_off[j] + w * 8;
            vals[1] = osz;
            vals[2] = ob_flag[j];
            if conv { vals[2] = 1; }
            if ob_esc[j] == 1 && ob_flag[j] == 1 { vals[2] = 0; changed = true; }
            nt[nn] = ' ';
            nn += 1;
            i64 q = 0;
            while q < 3 {
                char dg[12];
                i64 dn = 0;
                i64 dv = vals[q];
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
        i64 t = 0;
        while t < nn {
            lf_hint_text[t] = nt[t];
            t += 1;
        }
        lf_hint_n = nn;
    }
}


// ---------------------------------------------------------------------------------------------- null checks of array variables
// Every use of a dynamic array or a String variable loads its slot and checks it for null (a block that calls __Arr__nullerr when it is). The same variable is
// checked again at every use, three times in `y[k] = y[k] * 0.5 + x[k]`. A slot of the frame whose address is never taken (or is taken only for the
// cleanup record that frees the array at the end: the record is read by the code that unwinds, nothing else can write through it) can be changed only by
// a store that names it. So a check is redundant when every way in to it has passed the same check and no store to the slot lies between: the branch
// becomes a jump and the call of __Arr__nullerr is dead. (A data flow over the blocks: the set of slots known not to be null, joined by AND.)
i64 nc_off[64];                  // the offsets of the slots that are checked
i64 nc_addr[64];                 // how many times the address of the slot is used for anything but the cleanup record
i64 nc_n;
i64 nc_in[IR_MAXB];
i64 nc_out[IR_MAXB];
i64 nc_slot[IR_MAXB];            // the number of the slot that the block ends by checking, or -1
i64 nc_ok[IR_MAXB];              // the block where the check passes to
i64 nc_panic[IR_MAXB];           // 1: the block calls __Arr__nullerr (it never comes back)
i64 nc_changes;

i64 nc_index(i64 off) {
    i64 i = 0;
    while i < nc_n {
        if nc_off[i] == off { return i; }
        i += 1;
    }
    if nc_n >= 62 { return 0 - 1; }
    nc_off[nc_n] = off;
    nc_addr[nc_n] = 0;
    nc_n += 1;
    return nc_n - 1;
}

// the instruction after i in the block that is not a nop, or -1
i64 nc_next(i64 i, i64 b) {
    i64 j = i + 1;
    while j < ir_be[b] && ir_op[j] == IR_NOP { j += 1; }
    if j >= ir_be[b] { return 0 - 1; }
    return j;
}

// is the address made by instruction i (of block b), for the offset off, only given to the cleanup record (the store 16 bytes further)?
bool nc_is_record(i64 i, i64 b, i64 off) {
    i64 j = nc_next(i, b);
    if j < 0 || ir_op[j] != IR_STORE || ir_w[j] != 8 || ir_b[j] != ir_d[i] { return false; }
    // the record is written through the frame pointer (the store 16 bytes further) or, in the form that the lifter makes first, through the register that holds
    // its address (v = add v30, off + 8; the slot address goes to [v + 8], the function to [v + 16])
    i64 rb = 0 - 1;
    if ir_a[j] == 30 {
        if ir_k[j] != off + 16 { return false; }
    } else {
        if ir_k[j] != 8 || ir_a[j] < 1 || ir_a[j] > 63 { return false; }
        rb = ir_a[j];
        i64 q = i - 1;
        bool found = false;
        while q >= ir_bs[b] && !found {
            if ir_op[q] != IR_NOP && ir_d[q] == rb {
                found = true;
                if !(ir_op[q] == IR_ADD && ir_a[q] == 30 && ir_bi[q] == 1 && ir_b[q] == off + 8) { return false; }
            }
            q -= 1;
        }
        if !found { return false; }
    }
    // the record goes on with the address of the function that frees the object, stored 8 bytes further
    i64 j2 = nc_next(j, b);
    if !(j2 >= 0 && ir_op[j2] == IR_ADDR_FUNC) { return false; }
    i64 j3 = nc_next(j2, b);
    if j3 < 0 || ir_op[j3] != IR_STORE || ir_b[j3] != ir_d[j2] { return false; }
    if rb < 0 { return ir_a[j3] == 30 && ir_k[j3] == off + 24; }
    return ir_a[j3] == rb && ir_k[j3] == 16;
}

// the hint line says that the slot off is a plain 8-byte value (flag 1): value numbering may then reuse its loads
void nc_make_plain(i64 off) {
    i64 p = 2;
    while p < lf_hint_n {
        while p < lf_hint_n && lf_hint_text[p] == 32 { p += 1; }
        i64 start = p;
        i64 o = 0;
        while p < lf_hint_n && lf_hint_text[p] >= 48 && lf_hint_text[p] <= 57 { o = o * 10 + (lf_hint_text[p] - 48); p += 1; }
        if p < lf_hint_n && lf_hint_text[p] == 58 && o == off && p + 3 < lf_hint_n && lf_hint_text[p + 1] == 56 && lf_hint_text[p + 2] == 58 && lf_hint_text[p + 3] == 48
            && (p + 4 >= lf_hint_n || lf_hint_text[p + 4] == 32) {
            lf_hint_text[p + 3] = 49;
            if nc_dbg == 1 { write_err("  made plain: "); write_err_int(off); write_err("\n"); }
            return;
        }
        while p < lf_hint_n && lf_hint_text[p] != 32 { p += 1; }
    }
}

void op_nullchk() {
    nc_changes = 0;
    if nc_dbg == 1 { write_err("== nullchk of "); write_err(@ir_fname); write_err(" blocks "); write_err_int(ir_nb); write_err("\n"); }
    op_graph();
    nc_n = 0;
    i64 b = 0;
    while b < ir_nb {
        nc_slot[b] = 0 - 1;
        nc_ok[b] = 0 - 1;
        nc_panic[b] = 0;
        b += 1;
    }
    // 1. the blocks that check a slot, and the blocks that panic
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && ir_be[b] > ir_bs[b] {
            i64 i0 = ir_bs[b];
            while i0 < ir_be[b] {
                if ir_op[i0] == IR_CALL && (str_eq(@ir_name + ir_k[i0] * 64, "__Arr__nullerr") || str_eq(@ir_name + ir_k[i0] * 64, "__panic")) { nc_panic[b] = 1; }
                i0 += 1;
            }
        }
        b += 1;
    }
    // a block that only jumps on to a block that panics panics too (the body of an inlined __Arr__nullerr is several blocks)
    i64 pr = 0;
    while pr < 6 {
        b = 0;
        while b < ir_nb {
            if op_po[b] >= 0 && nc_panic[b] == 0 && ir_be[b] > ir_bs[b] {
                i64 tt = ir_be[b] - 1;
                if ir_op[tt] == IR_JMP && ir_t1[tt] >= 0 && nc_panic[ir_t1[tt]] == 1 { nc_panic[b] = 1; }
            }
            b += 1;
        }
        pr += 1;
    }
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && ir_be[b] > ir_bs[b] {
            i64 t = ir_be[b] - 1;
            if nc_dbg == 1 && ir_op[t] == IR_BR { write_err("  br in block "); write_err_int(b); write_err(" bi "); write_err_int(ir_bi[t]); write_err(" b "); write_err_int(ir_b[t]); write_err(" k "); write_err_int(ir_k[t]); write_err(" t2 "); write_err_int(ir_t2[t]); write_err(" panic "); if ir_t2[t] >= 0 { write_err_int(nc_panic[ir_t2[t]]); } write_err("\n"); }
            if ir_op[t] == IR_BR && ir_t2[t] >= 0 && nc_panic[ir_t2[t]] == 1 && ir_bi[t] == 1 && ir_b[t] == 0 && ir_k[t] == IR_NE {
                // the register that is tested was loaded from a slot of the frame, as the last thing that wrote it in this block
                i64 v = ir_a[t];
                i64 j = t - 1;
                while j >= ir_bs[b] && (ir_op[j] == IR_NOP || (ir_d[j] != v && !(ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND))) { j -= 1; }
                if j >= ir_bs[b] && ir_op[j] == IR_LOAD && ir_a[j] == 30 && ir_w[j] == 8 && ir_d[j] == v && ir_k[j] >= 16 && ir_k[j] % 8 == 0 {
                    i64 ix = nc_index(ir_k[j]);
                    if ix >= 0 {
                        nc_slot[b] = ix;
                        nc_ok[b] = ir_t1[t];
                    }
                }
            }
        }
        b += 1;
    }
    if nc_dbg == 1 { write_err("nullchk: "); write_err(@ir_fname); write_err(" slots "); write_err_int(nc_n); write_err("\n"); }
    if nc_n == 0 { return; }
    // 2. the slots whose address is used for something else than the cleanup record may be changed by anyone: not tracked
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                i64 op = ir_op[i];
                if (op == IR_ADDR_SLOT && ir_d[i] != 30) || (op == IR_ADD && ir_a[i] == 30 && ir_bi[i] == 1) {
                    i64 off = ir_k[i];
                    if op == IR_ADD { off = ir_b[i]; }
                    i64 ix = 0 - 1;
                    i64 q = 0;
                    while q < nc_n { if nc_off[q] == off { ix = q; } q += 1; }
                    if ix >= 0 {
                        // the cleanup record: the address goes to the slot 16 bytes further, in the next instruction
                        if !nc_is_record(i, b, off) {
                            nc_addr[ix] += 1;
                            if nc_dbg == 1 {
                                write_err("  address of slot "); write_err_int(off); write_err(" in block "); write_err_int(b); write_err(" op "); write_err_int(op);
                                i64 jj = nc_next(i, b);
                                if jj >= 0 { write_err(" next op "); write_err_int(ir_op[jj]); write_err(" a "); write_err_int(ir_a[jj]); write_err(" k "); write_err_int(ir_k[jj]); write_err(" w "); write_err_int(ir_w[jj]); write_err(" b "); write_err_int(ir_b[jj]); write_err(" d(i) "); write_err_int(ir_d[i]); }
                                write_err("\n");
                            }
                        }
                    }
                }
                // a frame pointer that goes anywhere else may reach any slot
                if (ir_a[i] == 30 && op != IR_LOAD && op != IR_STORE && op != IR_ADDR_SLOT && !(op == IR_ADD && ir_bi[i] == 1))
                    || (ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30) {
                    i64 q2 = 0;
                    while q2 < nc_n { nc_addr[q2] += 1; q2 += 1; }
                }
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                    i64 g = 0;
                    while g < ir_ac[i] {
                        if ir_args[ir_as[i] + g] == 30 {
                            i64 q3 = 0;
                            while q3 < nc_n { nc_addr[q3] += 1; q3 += 1; }
                        }
                        g += 1;
                    }
                }
                i += 1;
            }
        }
        b += 1;
    }
    // 3. the data flow: the slots known not to be null at the start of each block (all of them to begin with, except at the entry)
    i64 all = 0;
    i64 q4 = 0;
    while q4 < nc_n { if nc_addr[q4] == 0 { all = all | (1 << q4); } q4 += 1; }
    b = 0;
    while b < ir_nb {
        nc_in[b] = all;
        nc_out[b] = all;
        b += 1;
    }
    nc_in[0] = 0;
    i64 round = 0;
    bool changed = true;
    while changed && round < 30 {
        changed = false;
        round += 1;
        i64 ri = 0;
        while ri < op_nrpo {
            b = op_rpo[ri];
            ri += 1;
            if b >= ir_nb || op_po[b] < 0 { continue; }
            i64 in = all;
            if b == 0 { in = 0; }
            else {
                i64 e = op_phead[b];
                bool any = false;
                while e >= 0 {
                    i64 p = e / 2;
                    e = op_enext[e];
                    if op_po[p] < 0 || nc_panic[p] == 1 { continue; }
                    i64 pe = nc_out[p];
                    if nc_slot[p] >= 0 && nc_ok[p] == b { pe = pe | (1 << nc_slot[p]); }
                    in = in & pe;
                    any = true;
                }
                if !any { in = 0; }
            }
            i64 m = in;
            i64 i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] == IR_STORE && ir_a[i] == 30 {
                    // a store of the result of __Arr__make: that array exists (it panics when there is no memory), so the slot is not null from here on
                    bool made = false;
                    if ir_bi[i] == 0 && ir_w[i] == 8 && ir_b[i] >= 1 {
                        i64 jm = i - 1;
                        while jm >= ir_bs[b] && (ir_op[jm] == IR_NOP || ir_d[jm] != ir_b[i]) { jm -= 1; }
                        if jm >= ir_bs[b] && ir_op[jm] == IR_CALL && str_eq(@ir_name + ir_k[jm] * 64, "__Arr__make") { made = true; }
                    }
                    i64 q5 = 0;
                    while q5 < nc_n {
                        if ir_k[i] < nc_off[q5] + 8 && ir_k[i] + 8 > nc_off[q5] {
                            m = m & ~(1 << q5);
                            if made && ir_k[i] == nc_off[q5] { m = m | (1 << q5); }
                        }
                        q5 += 1;
                    }
                }
                i += 1;
            }
            if in != nc_in[b] || m != nc_out[b] { changed = true; }
            nc_in[b] = in;
            nc_out[b] = m;
        }
    }
    if nc_dbg == 1 { i64 qd = 0; while qd < nc_n { write_err("  slot "); write_err_int(nc_off[qd]); write_err(" addr uses "); write_err_int(nc_addr[qd]); write_err("\n"); qd += 1; } }
    // 4. a check that every way in has passed is a jump
    b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && nc_slot[b] >= 0 && (nc_out[b] & (1 << nc_slot[b])) != 0 && nc_addr[nc_slot[b]] == 0 {
            i64 t2 = ir_be[b] - 1;
            ir_op[t2] = IR_JMP;
            ir_t1[t2] = nc_ok[b];
            ir_t2[t2] = 0 - 1;
            ir_a[t2] = 0;
            nc_changes += 1;
        }
        b += 1;
    }
    // the slots that nobody can change but a store that names them are plain values for value numbering
    i64 q6 = 0;
    while q6 < nc_n {
        if nc_addr[q6] == 0 { nc_make_plain(nc_off[q6]); }
        q6 += 1;
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
    i64 i = 0;
    while i < out_len {
        i64 en = rg_end(i);
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
    i64 t = 0;
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
    i64 i = 0;
    while i < out_len {
        i64 en = rg_end(i);
        if rg_has(i, ";NB\n") { any = true; }
        i = en + 1;
    }
    if !any { return; }
    regs_len = 0;
    bool inside = false;
    i = 0;
    while i < out_len {
        i64 en2 = rg_end(i);
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
    i64 t = 0;
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

i64 rn_out[196608];              // [block * RN_NS + t]: the bounds of the tracked slots and of the registers at the end of the block
i64 rn_cs[RN_NS];                // the bounds in the block being scanned
i64 rn_ent[64];                  // the bounds of the registers when the block began
i64 rn_lr[IR_MAXV];              // the bound of a vreg inside the block (valid when rn_ls is the stamp of the block)
i64 rn_ls[IR_MAXV];
i64 rn_stamp;
i64 rn_ir[IR_MAXI];              // the bound of the result of each instruction (set when the block is scanned)
i64 rn_id[16384];                // slot (vn_slot) -> index t, or -1
i64 rn_nt;
i64 rn_leak;
i64 rn_changes;
i64 rn_big;
i64 rn_unk;
i64 rn_total;                    // all functions (for -irstat)

i64 rn_get(i64 v) {
    if v <= 0 || v >= IR_MAXV { return rn_unk; }
    if v < 64 {
        i64 x = rn_cs[RN_NT + v];
        if x < 0 { return 0; }
        return x;
    }
    if rn_ls[v] != rn_stamp { return rn_unk; }
    return rn_lr[v];
}

void rn_set(i64 v, i64 x) {
    if v > 0 && v < 64 { rn_cs[RN_NT + v] = x; }
    else if v >= 64 && v < IR_MAXV {
        rn_lr[v] = x;
        rn_ls[v] = rn_stamp;
    }
}

// the slot index t of a load / store, or -1
i64 rn_slot_t(i64 i) {
    i64 s = vn_slot(i);
    if s < 0 { return 0 - 1; }
    if s >= 8192 && rn_leak != 0 { return 0 - 1; }
    return rn_id[s];
}

i64 rn_add(i64 x, i64 y) {
    if x == rn_unk || y == rn_unk { return rn_unk; }
    if x == rn_big && y == rn_big { return rn_unk; }
    if x == rn_big { if y <= 1048576 { return rn_big; } return rn_unk; }
    if y == rn_big { if x <= 1048576 { return rn_big; } return rn_unk; }
    i64 s = x + y;
    if s >= rn_big { return rn_unk; }
    return s;
}

i64 rn_mul(i64 x, i64 y) {
    if x == rn_unk || y == rn_unk || x == rn_big || y == rn_big { return rn_unk; }
    if x == 0 || y == 0 { return 0; }
    if x > (rn_big - 1) / y { return rn_unk; }
    return x * y;
}

// all bits below the highest bit 1
i64 rn_smear(i64 m) {
    i64 r = m;
    r = r | (r >> 1);
    r = r | (r >> 2);
    r = r | (r >> 4);
    r = r | (r >> 8);
    r = r | (r >> 16);
    r = r | (r >> 32);
    return r;
}

// the bound of the number the second operand is (a number of the instruction or a vreg)
i64 rn_bval(i64 i) {
    if ir_bi[i] == 1 {
        i64 k = ir_b[i];
        if k >= 0 && k < rn_big { return k; }
        return rn_unk;
    }
    return rn_get(ir_b[i]);
}

// the bound of the result of the instruction i
i64 rn_eval(i64 i) {
    i64 op = ir_op[i];
    i64 d = ir_d[i];
    if d <= 0 || d >= IR_MAXV { return rn_unk; }
    if ir_vcls[d] != 0 { return rn_unk; }
    i64 a = rn_get(ir_a[i]);
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
            i64 k = ir_b[i];
            if k >= 0 && k < rn_big { return k; }
            if k < 0 { return a; }         // a & ~mask: not bigger than a
            return rn_unk;
        }
        i64 bb = rn_get(ir_b[i]);
        if a == rn_unk { return bb; }
        if bb == rn_unk { return a; }
        if a < bb { return a; }
        return bb;
    }
    if op == IR_OR || op == IR_XOR {
        i64 bo = rn_bval(i);
        if a == rn_unk || bo == rn_unk { return rn_unk; }
        if a == rn_big || bo == rn_big { return rn_big; }
        i64 m = a;
        if bo > m { m = bo; }
        return rn_smear(m);
    }
    if op == IR_SHL {
        if ir_bi[i] == 0 || a == rn_unk || a == rn_big { return rn_unk; }
        i64 k = ir_b[i];
        if k < 0 || k > 61 { return rn_unk; }
        if a > (rn_big - 1) >> k { return rn_unk; }
        return a << k;
    }
    if op == IR_LSHR || op == IR_ASHR {
        if ir_bi[i] == 0 { return rn_unk; }
        i64 k = ir_b[i];
        if k < 0 || k > 63 { return rn_unk; }
        if a == rn_unk {
            if op == IR_LSHR && k >= 2 { return (1 << (64 - k)) - 1; }
            return rn_unk;
        }
        if a == rn_big { if k >= 1 { return rn_big; } return rn_big; }
        return a >> k;
    }
    if op == IR_MULHS {
        i64 bm = rn_get(ir_b[i]);
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
        i64 w = ir_w[i];
        if w == 1 { return 255; }
        if w == 2 { return 65535; }
        if w == 4 { return 4294967295; }
        i64 t = rn_slot_t(i);
        if t >= 0 && w == 8 {
            i64 v = rn_cs[t];
            if v < 0 { return 0; }
            return v;
        }
        return rn_unk;
    }
    return rn_unk;
}

// the last instruction before `pos` in the block b that writes the vreg v (-1: none in the block, -2: a call in between)
i64 rn_find_def(i64 b, i64 pos, i64 v) {
    i64 j = pos - 1;
    while j >= ir_bs[b] {
        i64 op = ir_op[j];
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { return 0 - 2; }
        if ir_d[j] == v && op != IR_NOP && op != IR_STORE { return j; }
        j -= 1;
    }
    return 0 - 1;
}

// is the vreg v written by an instruction in [from, to)?
bool rn_written(i64 from, i64 to, i64 v) {
    i64 j = from;
    while j < to {
        if ir_d[j] == v && ir_op[j] != IR_NOP && ir_op[j] != IR_STORE { return true; }
        j += 1;
    }
    return false;
}

// where the value of v at `pos` comes from, through copies: the instruction that made it (>= 0), or -(v + 10) when it is the value the
// block started with, or -1 when it cannot be said
i64 rn_origin(i64 b, i64 pos, i64 v) {
    i64 j = rn_find_def(b, pos, v);
    i64 at = pos;
    i64 x = v;
    i64 n = 0;
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
bool rn_rotate(i64 b, i64 i) {
    if ir_bi[i] != 1 || ir_b[i] != 4294967295 { return false; }
    i64 c = rn_find_def(b, i, ir_a[i]);
    if c < 0 || ir_op[c] != IR_OR || ir_bi[c] != 0 { return false; }
    i64 p = rn_find_def(b, c, ir_a[c]);
    i64 q = rn_find_def(b, c, ir_b[c]);
    i64 hop = 0;
    while p >= 0 && ir_op[p] == IR_COPY && hop < 8 { p = rn_find_def(b, p, ir_a[p]); hop += 1; }
    hop = 0;
    while q >= 0 && ir_op[q] == IR_COPY && hop < 8 { q = rn_find_def(b, q, ir_a[q]); hop += 1; }
    if p < 0 || q < 0 || ir_bi[p] != 1 || ir_bi[q] != 1 { return false; }
    i64 r = p;
    i64 l = q;
    if ir_op[p] == IR_SHL { r = q; l = p; }
    if ir_op[l] != IR_SHL { return false; }
    if ir_op[r] != IR_LSHR && ir_op[r] != IR_ASHR { return false; }
    i64 n = ir_b[r];
    if n < 1 || n > 31 || ir_b[l] != 32 - n { return false; }
    i64 o1 = rn_origin(b, r, ir_a[r]);
    i64 o2 = rn_origin(b, l, ir_a[l]);
    if o1 == 0 - 1 || o1 != o2 { return false; }
    // the value must be known to fit in 32 bits (the instruction that made it)
    i64 src = 0;
    if o1 >= 0 {
        if rn_ir[o1] > 4294967295 { return false; }
        // made by `y & 0xFFFFFFFF`: the instruction ignores the upper half, so y itself can be turned
        if ir_op[o1] == IR_AND && ir_bi[o1] == 1 && ir_b[o1] == 4294967295 && ir_a[o1] > 0 && !rn_written(o1, i, ir_a[o1]) { src = ir_a[o1]; }
    } else {
        // the value the block started with: the bound at the start
        i64 lv = 0 - (o1 + 10);
        if lv < 1 || lv >= 64 { return false; }
        i64 eb = rn_ent[lv];
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
void rn_block(i64 b, bool rewrite) {
    rn_stamp += 1;
    i64 ev = 1;
    while ev < 64 { rn_ent[ev] = rn_cs[RN_NT + ev]; ev += 1; }
    i64 i = ir_bs[b];
    while i < ir_be[b] {
        i64 op = ir_op[i];
        if op == IR_NOP { i += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            rn_stamp += 1;
            i64 cv = 1;
            while cv <= 19 { rn_cs[RN_NT + cv] = rn_unk; cv += 1; }
            if ir_d[i] > 0 { rn_set(ir_d[i], rn_unk); }
            i += 1;
            continue;
        }
        if op == IR_STORE {
            i64 t = rn_slot_t(i);
            if t >= 0 && ir_w[i] == 8 {
                if ir_bi[i] == 1 {
                    i64 k = ir_b[i];
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
                i64 v = rn_get(ir_a[i]);
                i64 k = ir_b[i];
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
                    i64 v2 = rn_get(ir_a[i]);
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
            i64 rv = rn_eval(i);
            rn_ir[i] = rv;
            rn_set(ir_d[i], rv);
        }
        i += 1;
    }
}

// the state at the start of the block b: the join of the ends of the blocks that come before it
void rn_entry(i64 b) {
    i64 t = 0;
    while t < RN_NS {
        rn_cs[t] = 0 - 2;
        if b == 0 { rn_cs[t] = rn_unk; }
        t += 1;
    }
    i64 e = op_phead[b];
    while e >= 0 {
        i64 p = e / 2;
        if op_po[p] >= 0 {
            t = 0;
            while t < RN_NS {
                i64 v = rn_out[p * RN_NS + t];
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
    i64 i = 0;
    while i < ir_n {
        i64 op = ir_op[i];
        if op == IR_ADDR_SLOT { if ir_d[i] != 30 { rn_leak = 1; } }
        else if op != IR_LOAD && op != IR_STORE && op != IR_NOP {
            if ir_a[i] == 30 { rn_leak = 1; }
            if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == 30 { rn_leak = 1; }
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                i64 g = 0;
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
            i64 s = vn_slot(i);
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
    i64 pass = 0;
    bool changed = true;
    while changed && pass < 30 {
        changed = false;
        pass += 1;
        i64 ri = 0;
        while ri < op_nrpo {
            i64 b = op_rpo[ri];
            rn_entry(b);
            rn_block(b, false);
            i64 t = 0;
            while t < RN_NS {
                i64 old = rn_out[b * RN_NS + t];
                i64 n = rn_cs[t];
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
    i64 rj = 0;
    while rj < op_nrpo {
        i64 b2 = op_rpo[rj];
        rn_entry(b2);
        i64 t2 = 0;
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
i64 cl_head[CL_MAX];             // the header block
i64 cl_slot[CL_MAX];             // the slot index (vn_slot) of the counter
i64 cl_step[CL_MAX];
i64 cl_bkind[CL_MAX];            // the bound: 0 a number, 1 a slot that is not written in the loop
i64 cl_bval[CL_MAX];             // the number, or the slot index
i64 cl_cc[CL_MAX];               // the condition that keeps the loop going (IR_LT, IR_LE, IR_ULT, IR_ULE)
i64 cl_body[CL_MAX];             // the first block of the body
i64 cl_exit[CL_MAX];
i64 cl_calls[CL_MAX];            // calls inside the loop (a loop with calls is never vectorised)
i64 cl_nblk[CL_MAX];             // the blocks of the loop
i64 cl_inner[CL_MAX];            // 1: no other loop inside
i64 cl_lidx[CL_MAX];             // the loop (op_lh index) of the description
i64 cl_stb[CL_MAX];              // the block and the instruction of the step of the counter
i64 cl_sti[CL_MAX];
i64 cl_n;
i64 cl_total;                    // all functions (-irstat)

i64 cl_inv(i64 cc) {
    if cc == IR_GE { return IR_LT; }
    if cc == IR_GT { return IR_LE; }
    if cc == IR_UGE { return IR_ULT; }
    if cc == IR_UGT { return IR_ULE; }
    return 0 - 1;
}

void cl_analyse(i64 l) {
    i64 h = op_lh[l];
    i64 stamp = op_stamp;
    // the loop is marked with op_stamp (op_mark_loop was called just before)
    i64 t = ir_be[h] - 1;
    if ir_op[t] != IR_BR || cl_n >= CL_MAX { return; }
    bool in1 = op_mark[ir_t1[t]] == stamp;
    bool in2 = op_mark[ir_t2[t]] == stamp;
    if in1 == in2 { return; }
    i64 cc = ir_k[t];
    i64 body = ir_t1[t];
    i64 ex = ir_t2[t];
    if !in1 {
        cc = cl_inv(cc);
        body = ir_t2[t];
        ex = ir_t1[t];
    }
    if cc != IR_LT && cc != IR_LE && cc != IR_ULT && cc != IR_ULE { return; }
    i64 ld = rn_find_def(h, t, ir_a[t]);
    if ld < 0 || ir_op[ld] != IR_LOAD || ir_w[ld] != 8 || ir_a[ld] != 30 { return; }
    i64 sl = vn_slot(ld);
    if sl < 0 { return; }
    // the bound
    i64 bk = 0;
    i64 bv = 0;
    if ir_bi[t] == 1 {
        bv = ir_b[t];
    } else {
        i64 bd = rn_find_def(h, t, ir_b[t]);
        if bd < 0 { return; }
        if ir_op[bd] == IR_CONST { bv = ir_k[bd]; }
        else if ir_op[bd] == IR_LOAD && ir_w[bd] == 8 && ir_a[bd] == 30 && vn_slot(bd) >= 0 { bk = 1; bv = vn_slot(bd); }
        else { return; }
    }
    // the writes inside the loop
    i64 stores = 0;
    i64 st_b = 0 - 1;
    i64 st_i = 0 - 1;
    i64 calls = 0;
    i64 nblk = 0;
    bool bound_written = false;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && op_mark[b] == stamp {
            nblk += 1;
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                i64 op = ir_op[j];
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { calls += 1; }
                if op == IR_STORE && ir_a[j] == 30 {
                    i64 s2 = vn_slot(j);
                    if s2 == sl { stores += 1; st_b = b; st_i = j; }
                    else if bk == 1 && s2 == bv { bound_written = true; }
                    else if s2 < 0 {
                        // a store at an offset that is not a plain word: it could be anywhere in the frame
                        i64 k = ir_k[j];
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
    i64 ad = rn_find_def(st_b, st_i, ir_b[st_i]);
    if ad < 0 || ir_op[ad] != IR_ADD || ir_bi[ad] != 1 || ir_b[ad] < 1 || ir_b[ad] > 1024 { return; }
    i64 ld2 = rn_find_def(st_b, ad, ir_a[ad]);
    if ld2 < 0 || ir_op[ld2] != IR_LOAD || ir_w[ld2] != 8 || ir_a[ld2] != 30 || vn_slot(ld2) != sl { return; }
    // nothing stores to the slot between the load and the store (there is one store only), so the value is i + step
    i64 n = cl_n;
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
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                i64 s = op_succ(b, k);
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
    i64 i = 0;
    while i < op_nback {
        i64 h = op_bdst[i];
        bool known = false;
        i64 j = 0;
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
    i64 l = 0;
    while l < op_nloops {
        op_lsize[l] = op_mark_loop(l);
        cl_analyse(l);
        l += 1;
    }
    // an inner loop has no other loop header inside it
    i64 a = 0;
    while a < cl_n {
        i64 la = 0;
        while la < op_nloops && op_lh[la] != cl_head[a] { la += 1; }
        if la < op_nloops {
            op_mark_loop(la);
            i64 c = 0;
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
        i64 q = 0;
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

i64 vz_kind[IR_MAXV];
i64 vz_base[IR_MAXV];            // VZ_INV / VZ_ADDR: 0 a plain number, 29 the global area, 30 the frame
i64 vz_off[IR_MAXV];             // the number added to the base
i64 vz_vec[IR_MAXV];             // VZ_WORD / VZ_VEC / VZ_VWORD: the vector vreg in the vector body (class 2)
i64 vz_def[IR_MAXV];             // the register is written in the body
#define VZ_I2 11                 // the counter + an invariant register (vz_dyn) + a number of elements (vz_off): the index of a matrix element
i64 vz_dyn[IR_MAXV];             // VZ_I2 / VZ_IDX8 / VZ_ADDR: the invariant register that is added to the index (0: none)
i64 vz_dinst[IR_MAXV];           // the instruction that wrote the register last (while scanning)
i64 vz_ndef[IR_MAXV];            // how many instructions of the body write the register
i64 vz_dep[64];                  // the instructions that make a dyn register (done again in front of the vector loop)
i64 vz_ndep;
i64 vz_chain[256];
i64 vz_nchain;
i64 vz_acc_base[64];             // the accesses: base, offset, store?
i64 vz_acc_off[64];
i64 vz_acc_st[64];
i64 vz_nacc;
i64 vz_count;                    // loops made (all functions)
i64 vz_tried;
i64 vz_lslot[IR_MAXV];           // an int value that is a load of a plain slot: the slot index (else -1)
i64 vz_dslot[IR_MAXV];           // a double that is such a value's bits: the slot
i64 vz_hs[16];                   // the slots whose double is broadcast once in VP
i64 vz_hq[16];
i64 vz_nhs;
i64 vz_shift;                    // VB: bytes added to every element offset (the second copy of an unrolled body)
i64 vz_ti;                       // VB: the counter, loaded once
i64 vz_ab29;                     // VB: v29 + 8 * i (0: not made yet)
i64 vz_ab30;                     // VB: v30 + 8 * i
#define VZ_ACCV 9                // the value of an accumulator slot at the start of the turn (a vector in the vector loop)
#define VZ_ACCN 10               // the new value of an accumulator (acc + element)
i64 vz_sl_ld[16384];             // loads / stores of each plain frame slot in the body
i64 vz_sl_st[16384];
i64 vz_acc_slot[8];              // the accumulators: the slot, and the vector that holds its two partial sums
i64 vz_acc_q[32];                // the vectors of the partial sums: accumulator * 4 + chunk
i64 vz_nacc2;
i64 vz_pk_base[16];              // the pointers that walk along the arrays: base, offset, the stack cell that holds the pointer
i64 vz_pk_off[16];
i64 vz_pk_cell[16];
i64 vz_hpv[16];
i64 vz_null_off[8];              // the frame offsets of the array pointers that the loop checks for null
i64 vz_nnull;
i64 vz_ntmp;                     // address cells of the frame that the body writes and reads again
i64 vz_tmp_k[8];
i64 vz_tmp_ls[8];
i64 vz_tmp_kind[8];
i64 vz_tmp_vec[8];
i64 vz_tmp_base[8];
i64 vz_tmp_off[8];                  // the register that holds the data pointer of a heap array (for the pointer cell)
i64 vz_npk;
i64 vz_br_end;                   // the branch at the end of the vector body
i64 vz_has_fp;                   // the body has floating point arithmetic on elements
i64 vz_bq[64];                  // a double register that the body only reads: its broadcast made in VP (0: none)
i64 vz_w;                        // the size of the elements the loop reads and writes: 8 (the original), 4 (float, i32) or 1 (char)
i64 vz_lg;                       // log2 of it
i64 vz_work[IR_MAXI];            // the body instructions in order
i64 vz_nwork;

// the offset from the frame pointer of the slot index s (vn_slot)
i64 vz_slot_off(i64 s) {
    if s >= 8192 { return 0 - (s - 8192) * 8; }
    return s * 8;
}

bool vz_is_nop(i64 j) {
    return ir_op[j] == IR_NOP;
}

// the scalar instruction j cloned into the block that is being written
void vz_clone(i64 j) {
    i64 e = ir_add(ir_op[j], ir_d[j], ir_a[j], ir_b[j], ir_bi[j], ir_k[j]);
    ir_w[e] = ir_w[j];
}

// the arrangement code of IR_VOP / IR_VDUP for the element size: 1 = .2d, 2 = .4s, 3 = .16b
i64 vz_arr() {
    if vz_w == 8 { return 1; }
    if vz_w == 4 { return 2; }
    return 3;
}

// the whole number r (a scalar) in every lane
i64 vz_bcast(i64 r) {
    i64 qv = ir_vreg(2);
    i64 dp = ir_add(IR_VDUP, qv, r, 0, 0, 0);
    ir_w[dp] = vz_arr();
    return qv;
}

i64 vz_iabs(i64 w) {
    if w < 0 { return 0 - w; }
    return w;
}

// the register that holds base + 8 * i in the vector body (made at the first use)
i64 vz_abase(i64 base) {
    i64 cur = vz_ab29;
    if base == 30 { cur = vz_ab30; }
    if cur != 0 { return cur; }
    i64 tsh = ir_vreg(0);
    if vz_lg == 0 { ir_add(IR_COPY, tsh, vz_ti, 0, 0, 0); } else { ir_add(IR_SHL, tsh, vz_ti, vz_lg, 1, 0); }
    i64 ab = ir_vreg(0);
    ir_add(IR_ADD, ab, base, tsh, 0, 0);
    if base == 30 { vz_ab30 = ab; } else { vz_ab29 = ab; }
    return ab;
}

// the index of the pointer for base + off (a new one is made when emit is false)
i64 vz_kadd;                     // vz_ptr: what the access adds to the pointer (its offset minus the offset the pointer was made with)

// one pointer serves every access of the same base whose offset is the same modulo 16 and within 60000 bytes (the offset of ldr q is
// a multiple of 16 and at most 65520): three arrays are one pointer and one step for each turn, not three
i64 vz_pk_find(i64 base, i64 off, bool make) {
    i64 u = 0;
    while u < vz_npk {
        if vz_pk_base[u] == base {
            i64 dd = off - vz_pk_off[u];
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
i64 vz_ptr(i64 base, i64 off) {
    i64 u = vz_pk_find(base, off, false);
    i64 pt = ir_vreg(0);
    i64 lp = ir_add(IR_LOAD, pt, 30, 0, 0, 0);
    ir_w[lp] = 8;
    ir_k[lp] = vz_pk_cell[u];
    vz_kadd = off - vz_pk_off[u];
    return pt;
}

i64 vz_hq_of(i64 slot) {
    i64 u = 0;
    while u < vz_nhs {
        if vz_hs[u] == slot { return vz_hq[u]; }
        u += 1;
    }
    return 0;
}

// can the register r be made again in front of the vector loop? (the instructions that wrote it are pure: a load of a frame cell, a number, + - * << and copies)
bool vz_dep_ok(i64 r, i64 depth) {
    if r == 29 || r == 30 || r <= 0 || r >= ir_nv { return true; }
    if vz_ndef[r] == 0 { return true; }                     // a value that comes into the loop
    if vz_ndef[r] > 1 || depth > 6 { return false; }
    i64 j = vz_dinst[r];
    if j <= 0 { return false; }
    i64 op = ir_op[j];
    if op == IR_CONST { return true; }
    if op == IR_LOAD { return ir_a[j] == 30 && ir_w[j] == 8 && vz_dep_ok(ir_a[j], depth + 1); }
    if op == IR_COPY { return vz_dep_ok(ir_a[j], depth + 1); }
    if op == IR_ADD || op == IR_SUB || op == IR_MUL || op == IR_SHL {
        if !vz_dep_ok(ir_a[j], depth + 1) { return false; }
        if ir_bi[j] == 0 && !vz_dep_ok(ir_b[j], depth + 1) { return false; }
        return true;
    }
    return false;
}

// the instructions that make r, operands first (vz_dep, vz_ndep)
void vz_collect(i64 r) {
    if r == 29 || r == 30 || r <= 0 || r >= ir_nv || vz_ndef[r] == 0 { return; }
    i64 j = vz_dinst[r];
    i64 k = 0;
    while k < vz_ndep { if vz_dep[k] == j { return; } k += 1; }
    if ir_op[j] != IR_CONST { vz_collect(ir_a[j]); if ir_uses_b(ir_op[j]) && ir_bi[j] == 0 { vz_collect(ir_b[j]); } }
    if vz_ndep < 64 { vz_dep[vz_ndep] = j; vz_ndep += 1; }
}

// walk the body: the kind of every value, the accesses; with emit the vector body is written too (into the block being written)
// false when anything is not understood
// -irdbg 4194304: say where the vectoriser gave up (the line of jc_opt.j)
bool vz_fail(i64 line) {
    if (ir_opt & 4194304) != 0 {
        write_err("vz gave up at jc_opt.j:");
        write_err_int(line + 1);
        write_err(" fn=");
        write_err(@ir_fname);
        write_err("\n");
    }
    return false;
}

bool vz_scan(i64 q, i64 islot, i64 incl, i64 inch, bool emit) {
    i64 h = cl_head[q];
    vz_nacc = 0;
    if !emit { vz_has_fp = 0; }
    i64 v = 0;
    while v < ir_nv {
        vz_kind[v] = 0;
        vz_def[v] = 0;
        vz_dyn[v] = 0;
        vz_dinst[v] = 0;
        vz_ndef[v] = 0;
        vz_lslot[v] = 0 - 1;
        vz_dslot[v] = 0 - 1;
        v += 1;
    }
    if !emit { vz_nhs = 0; }
    // what the body writes
    i64 c = 0;
    while c < vz_nchain {
        i64 b = vz_chain[c];
        i64 j = ir_bs[b];
        while j < ir_be[b] - 1 {
            if ir_op[j] != IR_NOP && ir_d[j] > 0 && j != inch { vz_def[ir_d[j]] = 1; vz_ndef[ir_d[j]] += 1; }
            j += 1;
        }
        c += 1;
    }
    // the loads and stores of frame slots in the body (an accumulator is stored once and loaded once)
    {
        i64 zi = 0;
        while zi < 16384 { vz_sl_ld[zi] = 0; vz_sl_st[zi] = 0; zi += 1; }
        i64 zc = 0;
        while zc < vz_nchain {
            i64 zb = vz_chain[zc];
            i64 zj = ir_bs[zb];
            while zj < ir_be[zb] - 1 {
                if (ir_op[zj] == IR_LOAD || ir_op[zj] == IR_STORE) && ir_a[zj] == 30 {
                    i64 zs = vn_slot(zj);
                    if zs >= 0 {
                        if ir_op[zj] == IR_LOAD { vz_sl_ld[zs] += 1; } else { vz_sl_st[zs] += 1; }
                    } else if ir_op[zj] == IR_LOAD && ir_w[zj] == 0 - 4 && ir_bi[zj] == 0 && ir_k[zj] >= 0 && ir_k[zj] % 8 == 0 && ir_k[zj] / 8 < 8192 && op_plain[ir_k[zj] / 8] == 1 {
                        vz_sl_ld[ir_k[zj] / 8] += 1;            // a 32-bit accumulator is read with ldrsw
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
        i64 pc = 0;
        while pc < vz_nchain {
            i64 pb = vz_chain[pc];
            i64 pj = ir_bs[pb];
            while pj < ir_be[pb] - 1 {
                if (ir_op[pj] == IR_LOAD || ir_op[pj] == IR_STORE) && ir_a[pj] != 30 && pj != incl && pj != inch && !(ir_op[pj] == IR_LOAD && ir_w[pj] == 8 && ir_k[pj] == 16 && ir_bi[pj] == 0) {
                    i64 pw = vz_iabs(ir_w[pj]);
                    if pw != 8 && pw != 4 && pw != 1 { return vz_fail(5318); }
                    if vz_w == 0 { vz_w = pw; } else if vz_w != pw { return vz_fail(5319); }
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
    vz_ntmp = 0;
    vz_kind[29] = VZ_INV; vz_base[29] = 29; vz_off[29] = 0;
    vz_kind[30] = VZ_INV; vz_base[30] = 30; vz_off[30] = 0;
    c = 0;
    while c < vz_nchain {
        i64 b2 = vz_chain[c];
        i64 j2 = ir_bs[b2];
        while j2 < ir_be[b2] - 1 {
            i64 op = ir_op[j2];
            // the counter step: its load, add and store are not part of the work
            if j2 == incl || j2 == incl + 1 || j2 == inch { j2 += 1; continue; }
            if op == IR_NOP { j2 += 1; continue; }
            // reading a register that the body writes later (a value carried to the next turn)
            i64 a = ir_a[j2];
            if a > 0 && a < ir_nv && vz_def[a] == 1 && vz_kind[a] == 0 { return vz_fail(5344); }
            if ir_uses_b(op) && ir_bi[j2] == 0 && ir_b[j2] > 0 && ir_b[j2] < ir_nv && vz_def[ir_b[j2]] == 1 && vz_kind[ir_b[j2]] == 0 { return vz_fail(5345); }
            i64 d = ir_d[j2];
            // the address of an element kept in a temporary cell of the frame between two blocks (y[k] = ...): remembered, not stored
            if op == IR_STORE && ir_a[j2] == 30 && ir_w[j2] == 8 && ir_bi[j2] == 0 && ir_k[j2] < 0 && ir_b[j2] > 0 && (vz_kind[ir_b[j2]] == VZ_ADDR || vz_kind[ir_b[j2]] == VZ_WORD || vz_kind[ir_b[j2]] == VZ_VEC || vz_kind[ir_b[j2]] == VZ_VWORD || vz_kind[ir_b[j2]] == VZ_INV) && vz_ntmp < 8 {
                i64 ti = 0;
                while ti < vz_ntmp && vz_tmp_k[ti] != ir_k[j2] { ti += 1; }
                if ti == vz_ntmp { vz_ntmp += 1; }
                vz_tmp_k[ti] = ir_k[j2];
                vz_tmp_base[ti] = vz_base[ir_b[j2]];
                vz_tmp_off[ti] = vz_off[ir_b[j2]];
                vz_tmp_kind[ti] = vz_kind[ir_b[j2]];
                vz_tmp_vec[ti] = vz_vec[ir_b[j2]];
                vz_tmp_ls[ti] = vz_lslot[ir_b[j2]];
                if vz_kind[ir_b[j2]] == VZ_INV && emit { vz_clone(j2); }       // a plain value goes through the cell as it did
                j2 += 1;
                continue;
            }
            if op == IR_LOAD && ir_a[j2] == 30 && ir_w[j2] == 8 && ir_bi[j2] == 0 && ir_k[j2] < 0 && vz_ntmp > 0 {
                i64 tl = 0;
                while tl < vz_ntmp && vz_tmp_k[tl] != ir_k[j2] { tl += 1; }
                if tl < vz_ntmp {
                    vz_kind[d] = vz_tmp_kind[tl]; vz_base[d] = vz_tmp_base[tl]; vz_off[d] = vz_tmp_off[tl]; vz_vec[d] = vz_tmp_vec[tl];
                    vz_lslot[d] = vz_tmp_ls[tl];
                    if vz_kind[d] == VZ_INV && emit { vz_clone(j2); }
                    j2 += 1;
                    continue;
                }
            }
            if op == IR_LOAD && ir_a[j2] == 30 && ir_w[j2] == 0 - 4 && ir_bi[j2] == 0 && vz_w == 4 && (ir_opt & 68719476736) == 0 && ir_k[j2] >= 0 && ir_k[j2] % 8 == 0 && ir_k[j2] / 8 < 8192 && op_plain[ir_k[j2] / 8] == 1 && ir_k[j2] / 8 != islot && vz_sl_st[ir_k[j2] / 8] > 0 {
                // a 32-bit accumulator (s += a[i], s += a[i] * b[i], with the wrap-around at 32 bits): partial sums in the four lanes
                i64 s4 = ir_k[j2] / 8;
                if vz_sl_st[s4] != 1 || vz_sl_ld[s4] != 1 || (vz_nacc2 >= 8 && !emit) { return vz_fail(5374); }
                i64 ai4 = 0;
                while ai4 < vz_nacc2 && vz_acc_slot[ai4] != s4 { ai4 += 1; }
                if ai4 >= vz_nacc2 {
                    if emit { return vz_fail(5378); }
                    vz_acc_slot[ai4] = s4;
                    vz_acc_q[ai4 * 4] = 0;
                    vz_acc_q[ai4 * 4 + 1] = 0;
                    vz_acc_q[ai4 * 4 + 2] = 0;
                    vz_acc_q[ai4 * 4 + 3] = 0;
                    vz_nacc2 += 1;
                }
                vz_kind[d] = VZ_ACCV;
                vz_lslot[d] = s4;
                vz_vec[d] = vz_acc_q[ai4 * 4 + vz_shift / 16];
                j2 += 1;
                continue;
            }
            if op == IR_LOAD && ir_a[j2] == 30 && ir_w[j2] != 8 {
                // a float or a 32-bit number kept in a slot, that the loop does not write: it does not change
                i64 lk = ir_k[j2];
                i64 lwn = vz_iabs(ir_w[j2]);
                if lwn != 4 && lwn != 1 { return vz_fail(5351); }
                i64 sc2 = 0;
                while sc2 < vz_nchain {
                    i64 sb2 = vz_chain[sc2];
                    i64 sj2 = ir_bs[sb2];
                    while sj2 < ir_be[sb2] - 1 {
                        if ir_op[sj2] == IR_STORE && ir_a[sj2] == 30 && ir_k[sj2] < lk + 8 && ir_k[sj2] + 8 > lk { return vz_fail(5357); }
                        sj2 += 1;
                    }
                    sc2 += 1;
                }
                vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0;
                if emit { vz_clone(j2); }
            } else if op == IR_LOAD {
                if ir_w[j2] != 8 && ir_a[j2] == 30 { return vz_fail(5365); }
                if ir_a[j2] != 30 && ir_w[j2] == 8 && ir_k[j2] == 16 && vz_kind[ir_a[j2]] == VZ_INV && vz_base[ir_a[j2]] == 0 && vz_lslot[ir_a[j2]] >= 0 {
                    // the data pointer of a heap array (header [ptr + 16]) whose header pointer is in a slot that the loop does not write:
                    // the base 100000 + slot; the pointer is made once in front of the loop
                    vz_kind[d] = VZ_INV; vz_base[d] = 100000 + vz_lslot[ir_a[j2]]; vz_off[d] = 0; vz_lslot[d] = 0 - 1;
                    if emit { vz_clone(j2); }
                    j2 += 1;
                    continue;
                }
                if ir_a[j2] != 30 && vz_iabs(ir_w[j2]) != vz_w { return vz_fail(5366); }
                if ir_a[j2] == 30 && ir_bi[j2] == 0 {
                    i64 s = vn_slot(j2);
                    if s < 0 { return vz_fail(5369); }
                    if s != islot && vz_sl_st[s] > 0 {
                        // an accumulator: one load, one store, a whole number, a plain slot, no use of the slot's value except `acc + x`
                        if vz_w != 8 { return vz_fail(5372); }
                        if vz_sl_st[s] != 1 || vz_sl_ld[s] != 1 || vz_nacc2 >= 8 && !emit { return vz_fail(5373); }
                        i64 ai = 0;
                        while ai < vz_nacc2 && vz_acc_slot[ai] != s { ai += 1; }
                        if ai >= vz_nacc2 {
                            if emit { return vz_fail(5377); }
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
                    else if d >= 32 && d < 64 && (ir_opt & 562949953421312) == 0 { vz_kind[d] = VZ_DINV; vz_dslot[d] = s; }      // a double loaded from its cell (-irdbg 2251799813685248: not)
                    else { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; vz_lslot[d] = s; }
                    if emit && vz_kind[d] != VZ_I { vz_clone(j2); }
                } else if vz_kind[ir_a[j2]] == VZ_ADDR {
                    if vz_nacc >= 64 { return vz_fail(5395); }
                    vz_acc_base[vz_nacc] = vz_base[ir_a[j2]] + 1000000 * vz_dyn[ir_a[j2]];
                    vz_acc_off[vz_nacc] = vz_off[ir_a[j2]] + ir_k[j2];
                    vz_acc_st[vz_nacc] = 0;
                    vz_nacc += 1;
                    if emit {
                        i64 qv = ir_vreg(2);
                        i64 lpt = vz_ptr(vz_base[ir_a[j2]] + 1000000 * vz_dyn[ir_a[j2]], vz_off[ir_a[j2]] + ir_k[j2]);
                        i64 le = ir_add(IR_LOAD, qv, lpt, 0, 0, vz_shift + vz_kadd);
                        ir_w[le] = 16;
                        vz_vec[d] = qv;
                    }
                    vz_kind[d] = VZ_WORD;
                } else {
                    if (ir_opt & 4194304) != 0 { write_err("load a="); write_err_int(ir_a[j2]); write_err(" kind(a)="); write_err_int(vz_kind[ir_a[j2]]); write_err(" k="); write_err_int(ir_k[j2]); write_err(" w="); write_err_int(ir_w[j2]); write_err(" lslot="); write_err_int(vz_lslot[ir_a[j2]]); write_err(" base="); write_err_int(vz_base[ir_a[j2]]); write_err("\n"); }
                    return vz_fail(5408);
                }
            } else if op == IR_CONST {
                vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0;
                if emit { vz_clone(j2); }
            } else if op == IR_COPY {
                i64 sa = ir_a[j2];
                i64 ks = vz_kind[sa];
                if ks == 0 || ks == VZ_ACCN { return vz_fail(5415); }
                vz_kind[d] = ks; vz_base[d] = vz_base[sa]; vz_off[d] = vz_off[sa]; vz_vec[d] = vz_vec[sa]; vz_dyn[d] = vz_dyn[sa];
                vz_lslot[d] = vz_lslot[sa]; vz_dslot[d] = vz_dslot[sa];
                if emit && ks != VZ_VEC && ks != VZ_VWORD && ks != VZ_WORD && ks != VZ_ADDR && ks != VZ_IDX8 && ks != VZ_I && ks != VZ_ACCV { vz_clone(j2); }
            } else if op == IR_SHL {
                if vz_kind[ir_a[j2]] == VZ_WORD && ir_bi[j2] == 1 && ir_b[j2] >= 0 && ir_b[j2] < vz_w * 8 {
                    // a lane shifted to the left by a number (the bits that leave the lane are lost, as the store loses them)
                    if emit {
                        i64 cn = ir_vreg(0);
                        ir_add(IR_CONST, cn, 0, 0, 0, ir_b[j2]);
                        i64 qc = vz_bcast(cn);
                        i64 sh2 = ir_vreg(2);
                        i64 shn = ir_add(IR_VOP, sh2, vz_vec[ir_a[j2]], qc, 0, 10);
                        ir_w[shn] = vz_arr();
                        vz_vec[d] = sh2;
                    }
                    vz_kind[d] = VZ_WORD;
                    j2 += 1;
                    continue;
                }
                i64 shk = vz_kind[ir_a[j2]];
                if ir_bi[j2] != 1 || ir_b[j2] != vz_lg || (shk != VZ_I && shk != VZ_I2) { return vz_fail(5435); }
                i64 shdyn = 0;
                i64 shoff = 0;
                if shk == VZ_I2 { shdyn = vz_dyn[ir_a[j2]]; shoff = vz_off[ir_a[j2]] << vz_lg; }
                vz_kind[d] = VZ_IDX8;
                vz_dyn[d] = shdyn;
                vz_off[d] = shoff;
            } else if op == IR_EXT && ir_k[j2] == 32 && ir_w[j2] == 1 && vz_w == 4 && vz_kind[ir_a[j2]] == VZ_ACCN {
                // the sign extension of the new value of a 32-bit accumulator: the lanes are 32 bits already
                vz_kind[d] = VZ_ACCN;
                vz_vec[d] = vz_vec[ir_a[j2]];
                vz_lslot[d] = vz_lslot[ir_a[j2]];
            } else if (op == IR_ADD || op == IR_SUB) && ir_bi[j2] == 0 && (vz_kind[ir_a[j2]] == VZ_ACCV || (op == IR_ADD && vz_kind[ir_b[j2]] == VZ_ACCV)) {
                i64 ra5 = ir_a[j2];
                i64 rx = ir_b[j2];
                if vz_kind[rx] == VZ_ACCV { i64 t5 = ra5; ra5 = rx; rx = t5; }
                // the other operand: a loaded element or a value that does not change
                i64 kx = vz_kind[rx];
                if kx != VZ_WORD && kx != VZ_INV { return vz_fail(5443); }
                if vz_kind[ra5] != VZ_ACCV { return vz_fail(5444); }
                if emit {
                    i64 qx = 0;
                    if kx == VZ_WORD { qx = vz_vec[rx]; }
                    else {
                        qx = ir_vreg(2);
                        i64 dupx = ir_add(IR_VDUP, qx, rx, 0, 0, 0);
                        ir_w[dupx] = vz_arr();
                    }
                    i64 aq = vz_vec[ra5];
                    i64 ve5 = ir_add(IR_VOP, aq, aq, qx, 0, 4);
                    if op == IR_SUB { ir_k[ve5] = 5; }
                    ir_w[ve5] = vz_arr();
                    vz_vec[d] = aq;
                }
                vz_kind[d] = VZ_ACCN;
                vz_lslot[d] = vz_lslot[ra5];
            } else if (op == IR_ADD || op == IR_SUB || op == IR_MUL || op == IR_AND || op == IR_OR || op == IR_XOR) && (vz_kind[ir_a[j2]] == VZ_WORD || (ir_bi[j2] == 0 && vz_kind[ir_b[j2]] == VZ_WORD)) {
                // element-wise whole number arithmetic: the lanes hold the low bytes of the scalar result, which is all that a store keeps
                i64 ra6 = ir_a[j2];
                i64 ka6 = vz_kind[ra6];
                i64 kb6 = VZ_INV;
                if ir_bi[j2] == 0 { kb6 = vz_kind[ir_b[j2]]; }
                if ka6 != VZ_WORD && ka6 != VZ_INV { return vz_fail(5467); }
                if kb6 != VZ_WORD && kb6 != VZ_INV { return vz_fail(5468); }
                if op == IR_MUL && vz_w == 8 { return vz_fail(5469); }
                if emit {
                    i64 qa6 = 0;
                    i64 qb6 = 0;
                    if ka6 == VZ_WORD { qa6 = vz_vec[ra6]; } else { qa6 = vz_bcast(ra6); }
                    if ir_bi[j2] == 1 {
                        i64 cn6 = ir_vreg(0);
                        ir_add(IR_CONST, cn6, 0, 0, 0, ir_b[j2]);
                        qb6 = vz_bcast(cn6);
                    } else if kb6 == VZ_WORD { qb6 = vz_vec[ir_b[j2]]; }
                    else { qb6 = vz_bcast(ir_b[j2]); }
                    i64 kk6 = 4;
                    if op == IR_SUB { kk6 = 5; } else if op == IR_MUL { kk6 = 6; } else if op == IR_AND { kk6 = 7; } else if op == IR_OR { kk6 = 8; } else if op == IR_XOR { kk6 = 9; }
                    i64 qr6 = ir_vreg(2);
                    i64 ve6 = ir_add(IR_VOP, qr6, qa6, qb6, 0, kk6);
                    ir_w[ve6] = vz_arr();
                    vz_vec[d] = qr6;
                }
                vz_kind[d] = VZ_WORD;
            } else if op == IR_ADD {
                i64 ka = vz_kind[ir_a[j2]];
                if ir_bi[j2] == 1 {
                    if ka == VZ_INV { vz_kind[d] = VZ_INV; vz_base[d] = vz_base[ir_a[j2]]; vz_off[d] = vz_off[ir_a[j2]] + ir_b[j2]; vz_dyn[d] = 0; }
                    else if ka == VZ_ADDR { i64 sd = vz_dyn[ir_a[j2]]; vz_kind[d] = VZ_ADDR; vz_base[d] = vz_base[ir_a[j2]]; vz_off[d] = vz_off[ir_a[j2]] + ir_b[j2]; vz_dyn[d] = sd; }
                    else if ka == VZ_I || ka == VZ_I2 {
                        // the counter plus a number of elements
                        i64 id0 = 0;
                        i64 io0 = 0;
                        if ka == VZ_I2 { id0 = vz_dyn[ir_a[j2]]; io0 = vz_off[ir_a[j2]]; }
                        vz_kind[d] = VZ_I2; vz_dyn[d] = id0; vz_off[d] = io0 + ir_b[j2];
                    }
                    else { return vz_fail(5493); }
                } else {
                    i64 kb = vz_kind[ir_b[j2]];
                    i64 ra = ir_a[j2];
                    i64 rb = ir_b[j2];
                    bool handled = false;
                    // the counter plus an invariant number (the offset of a row): the index of a matrix element
                    i64 invr = ra;
                    if ka == VZ_I { invr = rb; }
                    if ((ka == VZ_I && kb == VZ_INV) || (ka == VZ_INV && kb == VZ_I)) && vz_base[invr] == 0 {
                        // the invariant number must be a load of a frame cell (a local such as the offset of a row): it is loaded again in front of the loop
                        i64 j0 = vz_dinst[invr];
                        if j0 <= 0 || ir_op[j0] != IR_LOAD || ir_a[j0] != 30 || ir_w[j0] != 8 || ir_bi[j0] != 0 { return vz_fail(5495); }
                        vz_kind[d] = VZ_I2; vz_dyn[d] = 500000 + ir_k[j0]; vz_off[d] = 0;
                        handled = true;
                    }
                    if !handled {
                        i64 dyb = 0;
                        i64 ofb = 0;
                        i64 dya = 0;
                        i64 ofa = 0;
                        if vz_w == 1 {
                            // elements of one byte: the address is the base plus the counter itself
                            if ka == VZ_I { ka = VZ_IDX8; }
                            if kb == VZ_I { kb = VZ_IDX8; }
                            if ka == VZ_I2 { dya = vz_dyn[ra]; ofa = vz_off[ra]; ka = VZ_IDX8; }
                            if kb == VZ_I2 { dyb = vz_dyn[rb]; ofb = vz_off[rb]; kb = VZ_IDX8; }
                        }
                        if ka == VZ_IDX8 && dya == 0 && ofa == 0 && vz_w != 1 { dya = vz_dyn[ra]; ofa = vz_off[ra]; }
                        if kb == VZ_IDX8 && dyb == 0 && ofb == 0 && vz_w != 1 { dyb = vz_dyn[rb]; ofb = vz_off[rb]; }
                        if ka == VZ_IDX8 && kb == VZ_INV { i64 tmp = ra; ra = rb; rb = tmp; i64 tk = ka; ka = kb; kb = tk; i64 td = dya; dya = dyb; dyb = td; i64 to = ofa; ofa = ofb; ofb = to; }
                        if ka == VZ_INV && kb == VZ_IDX8 && vz_base[ra] != 0 {
                            vz_kind[d] = VZ_ADDR; vz_base[d] = vz_base[ra]; vz_off[d] = vz_off[ra] + ofb; vz_dyn[d] = dyb;
                        } else if ka == VZ_INV && kb == VZ_IDX8 && vz_base[ra] == 0 && vz_lslot[ra] >= 0 && (ir_opt & 36028797018963968) == 0 {
                            // a pointer kept in a slot that the loop does not write (a parameter `float^ p`): the base 200000 + slot; the value of the slot is the data pointer
                            vz_kind[d] = VZ_ADDR; vz_base[d] = 200000 + vz_lslot[ra]; vz_off[d] = vz_off[ra] + ofb; vz_dyn[d] = dyb;
                        } else { return vz_fail(5506); }
                    }
                }
                if emit && vz_kind[d] != VZ_ADDR && vz_kind[d] != VZ_I2 { vz_clone(j2); }
            } else if op == IR_F32IN {
                i64 kx = vz_kind[ir_a[j2]];
                if (kx == VZ_WORD || kx == VZ_VWORD) && vz_w == 4 { vz_kind[d] = VZ_VEC; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if kx == VZ_INV { vz_kind[d] = VZ_DINV; if emit { vz_clone(j2); } }
                else { return vz_fail(5513); }
            } else if op == IR_F32OUT {
                i64 kx2 = vz_kind[ir_a[j2]];
                if kx2 == VZ_VEC && vz_w == 4 { vz_kind[d] = VZ_VWORD; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if kx2 == VZ_DINV { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; if emit { vz_clone(j2); } }
                else { return vz_fail(5518); }
            } else if op == IR_FCVT_DS {
                if vz_kind[ir_a[j2]] != VZ_DINV { return vz_fail(5520); }
                vz_kind[d] = VZ_DINV;
                if emit { vz_clone(j2); }
            } else if op >= IR_FADD32 && op <= IR_FDIV32 {
                i64 ra7 = ir_a[j2];
                i64 rb7 = ir_b[j2];
                i64 ka7 = vz_kind[ra7];
                i64 kb7 = vz_kind[rb7];
                if (ka7 != VZ_VEC && ka7 != VZ_DINV) || (kb7 != VZ_VEC && kb7 != VZ_DINV) { return vz_fail(5528); }
                if ka7 == VZ_VEC || kb7 == VZ_VEC {
                    if vz_w != 4 { return vz_fail(5530); }
                    if !emit { vz_has_fp = 1; }
                    if !emit {
                        // a number that does not change: broadcast once in front of the loop (a slot is broadcast as .4s here, as .2d for a double)
                        i64 hk7 = 0;
                        while hk7 < 2 {
                            i64 rr7 = ra7;
                            i64 kk7b = ka7;
                            if hk7 == 1 { rr7 = rb7; kk7b = kb7; }
                            if kk7b == VZ_DINV && vz_dslot[rr7] >= 0 && vz_nhs < 16 {
                                i64 hx7 = 0;
                                bool have7 = false;
                                while hx7 < vz_nhs { if vz_hs[hx7] == vz_dslot[rr7] { have7 = true; } hx7 += 1; }
                                if !have7 { vz_hs[vz_nhs] = vz_dslot[rr7]; vz_nhs += 1; }
                            }
                            hk7 += 1;
                        }
                    }
                    if emit {
                        i64 qa7 = 0;
                        i64 qb7 = 0;
                        if ka7 == VZ_VEC { qa7 = vz_vec[ra7]; }
                        else if vz_dslot[ra7] >= 0 && vz_hq_of(vz_dslot[ra7]) != 0 { qa7 = vz_hq_of(vz_dslot[ra7]); }
                        else {
                            i64 xa7 = ir_vreg(0);
                            ir_add(IR_F32OUT, xa7, ra7, 0, 0, 0);
                            qa7 = vz_bcast(xa7);
                        }
                        if kb7 == VZ_VEC { qb7 = vz_vec[rb7]; }
                        else if vz_dslot[rb7] >= 0 && vz_hq_of(vz_dslot[rb7]) != 0 { qb7 = vz_hq_of(vz_dslot[rb7]); }
                        else {
                            i64 xb7 = ir_vreg(0);
                            ir_add(IR_F32OUT, xb7, rb7, 0, 0, 0);
                            qb7 = vz_bcast(xb7);
                        }
                        i64 kk7 = op - IR_FADD32;
                        i64 qr7 = ir_vreg(2);
                        i64 ve7 = ir_add(IR_VOP, qr7, qa7, qb7, 0, kk7);
                        ir_w[ve7] = 2;
                        vz_vec[d] = qr7;
                    }
                    vz_kind[d] = VZ_VEC;
                } else {
                    vz_kind[d] = VZ_DINV;
                    if emit { vz_clone(j2); }
                }
            } else if op == IR_BITS2F {
                i64 ka2 = vz_kind[ir_a[j2]];
                if ka2 == VZ_WORD && vz_w != 8 { return vz_fail(5560); }
                if ka2 == VZ_WORD { vz_kind[d] = VZ_VEC; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if ka2 == VZ_INV { vz_kind[d] = VZ_DINV; vz_dslot[d] = vz_lslot[ir_a[j2]]; if emit { vz_clone(j2); } }
                else { return vz_fail(5563); }
            } else if op == IR_FCONST {
                vz_kind[d] = VZ_DINV;
                if emit { vz_clone(j2); }
            } else if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV {
                i64 ra3 = ir_a[j2];
                i64 rb3 = ir_b[j2];
                i64 ka3 = vz_kind[ra3];
                i64 kb3 = vz_kind[rb3];
                bool oka = ka3 == VZ_VEC || ka3 == VZ_DINV;
                bool okb = kb3 == VZ_VEC || kb3 == VZ_DINV;
                if !oka || !okb { return vz_fail(5574); }
                if ka3 == VZ_VEC || kb3 == VZ_VEC {
                    if vz_w != 8 { return vz_fail(5576); }
                    if !emit { vz_has_fp = 1; }
                    if !emit {
                        i64 hk = 0;
                        while hk < 2 {
                            i64 rr = ra3;
                            i64 kk2 = ka3;
                            if hk == 1 { rr = rb3; kk2 = kb3; }
                            if kk2 == VZ_DINV && vz_dslot[rr] >= 0 && vz_nhs < 16 {
                                i64 hx = 0;
                                bool have = false;
                                while hx < vz_nhs { if vz_hs[hx] == vz_dslot[rr] { have = true; } hx += 1; }
                                if !have { vz_hs[vz_nhs] = vz_dslot[rr]; vz_nhs += 1; }
                            }
                            hk += 1;
                        }
                    }
                    if emit {
                        i64 qa = 0;
                        i64 qb = 0;
                        if ka3 == VZ_VEC { qa = vz_vec[ra3]; }
                        else if vz_dslot[ra3] >= 0 && vz_hq_of(vz_dslot[ra3]) != 0 { qa = vz_hq_of(vz_dslot[ra3]); }
                        else if ra3 < 64 && vz_def[ra3] == 0 && vz_bq[ra3] != 0 { qa = vz_bq[ra3]; }
                        else {
                            i64 xa = ir_vreg(0);
                            ir_add(IR_F2BITS, xa, ra3, 0, 0, 0);
                            qa = ir_vreg(2);
                            i64 dupa = ir_add(IR_VDUP, qa, xa, 0, 0, 0);
                            ir_w[dupa] = 1;
                        }
                        if kb3 == VZ_VEC { qb = vz_vec[rb3]; }
                        else if vz_dslot[rb3] >= 0 && vz_hq_of(vz_dslot[rb3]) != 0 { qb = vz_hq_of(vz_dslot[rb3]); }
                        else if rb3 < 64 && vz_def[rb3] == 0 && vz_bq[rb3] != 0 { qb = vz_bq[rb3]; }
                        else {
                            i64 xb = ir_vreg(0);
                            ir_add(IR_F2BITS, xb, rb3, 0, 0, 0);
                            qb = ir_vreg(2);
                            i64 dupb = ir_add(IR_VDUP, qb, xb, 0, 0, 0);
                            ir_w[dupb] = 1;
                        }
                        i64 qr = ir_vreg(2);
                        i64 kk = 0;
                        if op == IR_FSUB { kk = 1; } else if op == IR_FMUL { kk = 2; } else if op == IR_FDIV { kk = 3; }
                        i64 ve = ir_add(IR_VOP, qr, qa, qb, 0, kk);
                        ir_w[ve] = 1;
                        vz_vec[d] = qr;
                    }
                    vz_kind[d] = VZ_VEC;
                } else {
                    vz_kind[d] = VZ_DINV;
                    if emit { vz_clone(j2); }
                }
            } else if op == IR_F2BITS {
                i64 ka4 = vz_kind[ir_a[j2]];
                if ka4 == VZ_VEC && vz_w != 8 { return vz_fail(5630); }
                if ka4 == VZ_VEC { vz_kind[d] = VZ_VWORD; vz_vec[d] = vz_vec[ir_a[j2]]; }
                else if ka4 == VZ_DINV { vz_kind[d] = VZ_INV; vz_base[d] = 0; vz_off[d] = 0; if emit { vz_clone(j2); } }
                else { return vz_fail(5633); }
            } else if op == IR_STORE && ir_a[j2] == 30 && ir_w[j2] == 8 && ir_bi[j2] == 0 && vn_slot(j2) >= 0 && vz_kind[ir_b[j2]] == VZ_ACCN {
                // the new value of the accumulator goes to the slot after the loop: nothing is written in the vector loop
                if vz_lslot[ir_b[j2]] != vn_slot(j2) { return vz_fail(5636); }
            } else if op == IR_STORE {
                if vz_iabs(ir_w[j2]) != vz_w || ir_bi[j2] != 0 { return vz_fail(5638); }
                if vz_kind[ir_a[j2]] != VZ_ADDR { return vz_fail(5639); }
                i64 kv = vz_kind[ir_b[j2]];
                if kv != VZ_VWORD && kv != VZ_WORD && kv != VZ_INV { return vz_fail(5641); }
                if vz_nacc >= 64 { return vz_fail(5642); }
                vz_acc_base[vz_nacc] = vz_base[ir_a[j2]] + 1000000 * vz_dyn[ir_a[j2]];
                vz_acc_off[vz_nacc] = vz_off[ir_a[j2]] + ir_k[j2];
                vz_acc_st[vz_nacc] = 1;
                vz_nacc += 1;
                if emit {
                    i64 qs = 0;
                    if kv == VZ_VWORD || kv == VZ_WORD { qs = vz_vec[ir_b[j2]]; }
                    else {
                        qs = vz_bcast(ir_b[j2]);
                    }
                    i64 spt = vz_ptr(vz_base[ir_a[j2]] + 1000000 * vz_dyn[ir_a[j2]], vz_off[ir_a[j2]] + ir_k[j2]);
                    i64 se = ir_add(IR_STORE, 0, spt, qs, 0, vz_shift + vz_kadd);
                    ir_w[se] = 16;
                }
            } else {
                return vz_fail(5658);
            }
            if d > 0 { vz_dinst[d] = j2; }
            j2 += 1;
        }
        c += 1;
    }
    // the accesses must not get in each other's way
    i64 x = 0;
    while x < vz_nacc {
        i64 y = 0;
        while y < vz_nacc {
            // the same array reached with different invariant offsets: the distance is not known
            if x != y && (vz_acc_st[x] == 1 || vz_acc_st[y] == 1) && vz_acc_base[x] != vz_acc_base[y] && vz_acc_base[x] % 1000000 == vz_acc_base[y] % 1000000 { return vz_fail(5671); }
            if x != y && (vz_acc_st[x] == 1 || vz_acc_st[y] == 1) && vz_acc_base[x] == vz_acc_base[y] {
                i64 dd = vz_acc_off[x] - vz_acc_off[y];
                if dd < 0 { dd = 0 - dd; }
                if dd != 0 && dd < 16 { return vz_fail(5672); }
            }
            y += 1;
        }
        x += 1;
    }
    // at least one store, or an accumulator
    bool st = vz_nacc2 > 0;
    i64 w = 0;
    while w < vz_nacc { if vz_acc_st[w] == 1 { st = true; } w += 1; }
    return st;
}

// the live-in doubles that a vector operation reads: broadcast once in the block being written (VP)
void vz_hoist(i64 q) {
    i64 c = 0;
    while c < vz_nchain {
        i64 b = vz_chain[c];
        i64 j = ir_bs[b];
        while j < ir_be[b] - 1 {
            i64 op = ir_op[j];
            if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV {
                i64 k = 0;
                while k < 2 {
                    i64 r = ir_a[j];
                    if k == 1 { r = ir_b[j]; }
                    if r >= 32 && r < 64 && vz_def[r] == 0 && vz_bq[r] == 0 && ir_vcls[r] == 1 {
                        i64 xv = ir_vreg(0);
                        ir_add(IR_F2BITS, xv, r, 0, 0, 0);
                        i64 qv = ir_vreg(2);
                        i64 dp = ir_add(IR_VDUP, qv, xv, 0, 0, 0);
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
i64 vz_rn_to[IR_MAXV];
i64 vz_rn_st[IR_MAXV];
i64 vz_rn_stamp;
i64 vz_inv_def[IR_MAXV];        // stamp: written in the body (after renaming), and the instruction is moved
i64 vz_wr_st[IR_MAXV];          // stamp: written in the body
i64 vz_rd_first[IR_MAXV];       // stamp: read before it is written
i64 vz_hoisted_n;

i64 vz_rename_of(i64 v) {
    if v > 0 && v < IR_MAXV && vz_rn_st[v] == vz_rn_stamp { return vz_rn_to[v]; }
    return v;
}

bool vz_hoistable_op(i64 op) {
    if op == IR_CONST || op == IR_FCONST || op == IR_COPY || op == IR_F32IN || op == IR_F32OUT || op == IR_FCVT_DS || op == IR_FCVT_SD { return true; }
    if op == IR_BITS2F || op == IR_F2BITS || op == IR_VDUP || op == IR_VOP || op == IR_EXT || op == IR_NEG || op == IR_NOT { return true; }
    if op >= IR_ADD && op <= IR_ASHR { return op != IR_SDIV && op != IR_UDIV; }
    if op == IR_FADD || op == IR_FSUB || op == IR_FMUL || op == IR_FDIV { return true; }
    if op >= IR_FADD32 && op <= IR_FDIV32 { return true; }
    return false;
}

// vb: the vector body (complete, the last instruction is its branch), vh0: its entry
// returns the number of instructions moved
// a load in the vector body whose register is written again before anything reads it (the copies of a pointer made for every chunk): dropped.
// Only loads of the frame or of a header ([reg + 16]); a register that is still unread at the end of the body is kept (it can be live after the loop),
// except a scratch temporary (64 and up).
void vz_dead_loads(i64 vb) {
    i64 s = ir_bs[vb];
    i64 e = ir_n - 1;
    i64 j = s;
    while j <= e {
        if ir_op[j] == IR_LOAD && ir_d[j] > 0 && ir_d[j] < IR_MAXV && ir_vcls[ir_d[j]] == 0 && (ir_a[j] == 30 || ir_k[j] == 16) && ir_w[j] == 8 {
            i64 d = ir_d[j];
            i64 m = j + 1;
            i64 state = 0;           // 1 read, 2 written again first
            while m <= e && state == 0 {
                i64 op = ir_op[m];
                if op != IR_NOP {
                    if ir_a[m] == d { state = 1; }
                    else if ir_uses_b(op) && ir_bi[m] == 0 && ir_b[m] == d { state = 1; }
                    else if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL || op == IR_BR || op == IR_JMP || op == IR_FBR { state = 1; }
                    else if ir_d[m] == d { state = 2; }
                }
                m += 1;
            }
            if state == 2 || (state == 0 && d >= 64) { ir_op[j] = IR_NOP; }
        }
        j += 1;
    }
}

i64 vz_licm(i64 vb, i64 br0) {
    i64 s = ir_bs[vb];
    i64 e = ir_n - 1;
    if e <= s { return 0; }
    vz_rn_stamp += 1;
    // 1. which registers are read before they are written
    i64 j = s;
    while j <= e {
        i64 op = ir_op[j];
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
        i64 op = ir_op[j];
        if op != IR_NOP {
            if ir_a[j] > 0 { ir_a[j] = vz_rename_of(ir_a[j]); }
            if ir_uses_b(op) && ir_bi[j] == 0 && ir_b[j] > 0 { ir_b[j] = vz_rename_of(ir_b[j]); }
            i64 d = ir_d[j];
            if d > 0 && d < IR_MAXV && d != 29 && d != 30 && vz_rd_first[d] != vz_rn_stamp {
                i64 nv = ir_vreg(ir_vcls[d]);
                vz_rn_to[d] = nv;
                vz_rn_st[d] = vz_rn_stamp;
                ir_d[j] = nv;
                if nv > 0 && nv < IR_MAXV { vz_wr_st[nv] = vz_rn_stamp; vz_rd_first[nv] = 0; }
            }
        }
        j += 1;
    }
    // the frame bytes that the body writes
    i64 nst = 0;
    i64 sk[64];
    j = s;
    while j <= e {
        if ir_op[j] == IR_STORE && ir_a[j] == 30 && nst < 64 { sk[nst] = ir_k[j]; nst += 1; }
        if ir_op[j] == IR_STORE && ir_a[j] != 30 && ir_w[j] != 16 { return 0; }
        if ir_op[j] == IR_CALL || ir_op[j] == IR_CALLIND || ir_op[j] == IR_SYSCALL { return 0; }
        j += 1;
    }
    // 3. what can go: the instruction reads nothing that the body writes except the results of instructions that go
    i64 moved[512];
    i64 nm = 0;
    i64 stamp2 = vz_rn_stamp;
    j = s;
    while j < e {
        i64 op = ir_op[j];
        i64 d = ir_d[j];
        bool can = false;
        if op != IR_NOP && d > 0 && d < IR_MAXV && vz_rd_first[d] != stamp2 && nm < 500 {
            if vz_hoistable_op(op) { can = true; }
            if op == IR_LOAD && ir_a[j] == 30 && ir_bi[j] == 0 && ir_w[j] != 16 {
                can = true;
                i64 z = 0;
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
    i64 flagged[512];
    if nm > 0 {
        i64 fi = 0;
        while fi < nm { flagged[fi] = 1; fi += 1; }
        bool again = true;
        while again {
            again = false;
            fi = 0;
            while fi < nm {
                if flagged[fi] == 1 {
                    i64 fj = moved[fi];
                    i64 fd = ir_d[fj];
                    bool ok = true;
                    // an operand that was in the list but is not any more
                    i64 oa = ir_a[fj];
                    if oa > 0 && oa < IR_MAXV && vz_wr_st[oa] == stamp2 && vz_inv_def[oa] != stamp2 { ok = false; }
                    if ir_uses_b(ir_op[fj]) && ir_bi[fj] == 0 {
                        i64 ob = ir_b[fj];
                        if ob > 0 && ob < IR_MAXV && vz_wr_st[ob] == stamp2 && vz_inv_def[ob] != stamp2 { ok = false; }
                    }
                    if ok && ir_vcls[fd] != 2 {
                        // the readers that stay in the body
                        i64 rj = s;
                        while rj <= e && ok {
                            if ir_op[rj] != IR_NOP {
                                bool is_moved = false;
                                i64 mi = 0;
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
        i64 kn = 0;
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
    i64 dup_of[512];
    i64 du = 0;
    while du < nm {
        dup_of[du] = 0 - 1;
        i64 dj = moved[du];
        i64 dv = 0;
        while dv < du && dup_of[du] < 0 {
            i64 vj = moved[dv];
            if dup_of[dv] < 0 && ir_op[vj] == ir_op[dj] && ir_a[vj] == ir_a[dj] && ir_bi[vj] == ir_bi[dj] && ir_k[vj] == ir_k[dj] && ir_w[vj] == ir_w[dj] && (ir_bi[dj] == 1 || !ir_uses_b(ir_op[dj]) || ir_b[vj] == ir_b[dj]) && ir_vcls[ir_d[vj]] == ir_vcls[ir_d[dj]] {
                dup_of[du] = vj;
                // every use of the dropped register reads the first one
                i64 old_r = ir_d[dj];
                i64 new_r = ir_d[vj];
                i64 uj = s;
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
    i64 vk = ir_new_block(0 - 1);
    ir_set_block(vk);
    i64 u = 0;
    while u < nm {
        i64 jj = moved[u];
        if dup_of[u] >= 0 {
            ir_op[jj] = IR_NOP;
            ir_d[jj] = 0;
            ir_a[jj] = 0;
            ir_bi[jj] = 1;
            u += 1;
            continue;
        }
        i64 ne = ir_add(ir_op[jj], ir_d[jj], ir_a[jj], ir_b[jj], ir_bi[jj], ir_k[jj]);
        ir_w[ne] = ir_w[jj];
        ir_op[jj] = IR_NOP;
        ir_d[jj] = 0;
        ir_a[jj] = 0;
        ir_bi[jj] = 1;
        u += 1;
    }
    i64 jk = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jk] = vb;
    ir_t1[br0] = vk;
    vz_hoisted_n += nm;
    return nm;
}

// a block that only reports a missing array (a call of __Arr__nullerr, then a jump)
bool vz_is_nulltrap(i64 b) {
    bool ok = false;
    i64 j = ir_bs[b];
    while j < ir_be[b] {
        i64 op = ir_op[j];
        if op == IR_CALL {
            // the check inlined (the call of __panic with the text) or not (a call of __Arr__nullerr)
            if !str_eq(@ir_name + ir_k[j] * 64, "__Arr__nullerr") && !str_eq(@ir_name + ir_k[j] * 64, "__panic") { return false; }
            ok = true;
        } else if op != IR_NOP && op != IR_JMP && op != IR_TRAP && op != IR_ADD && op != IR_CONST && op != IR_ADDR_SLOT {
            return false;
        }
        j += 1;
    }
    return ok;
}

bool vz_make(i64 q, i64 l) {
    i64 h = cl_head[q];
    i64 islot = cl_slot[q];
    // the blocks of the loop other than the header must be one chain from the body to the block that jumps back
    op_mark_loop(l);
    i64 stamp = op_stamp;
    i64 total = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && op_mark[b] == stamp { total += 1; }
        b += 1;
    }
    vz_nchain = 0;
    vz_nnull = 0;
    i64 cur = cl_body[q];
    while cur != h {
        if op_mark[cur] != stamp || vz_nchain >= 250 { return vz_fail(5946); }
        i64 tt = ir_be[cur] - 1;
        i64 trapb = 0 - 1;
        i64 nextb = 0 - 1;
        if ir_op[tt] == IR_BR && ir_bi[tt] == 1 && ir_b[tt] == 0 && vz_nnull < 8 {
            if ir_k[tt] == IR_NE && vz_is_nulltrap(ir_t2[tt]) { trapb = ir_t2[tt]; nextb = ir_t1[tt]; }
            else if ir_k[tt] == IR_EQ && vz_is_nulltrap(ir_t1[tt]) { trapb = ir_t1[tt]; nextb = ir_t2[tt]; }
        }
        if trapb >= 0 {
            // the check that an array exists: a branch to a block that reports it; the vector loop checks the arrays once, in front
            i64 nd = rn_find_def(cur, tt, ir_a[tt]);
            if nd < 0 || ir_op[nd] != IR_LOAD || ir_a[nd] != 30 || ir_w[nd] != 8 { return vz_fail(5947); }
            vz_null_off[vz_nnull] = ir_k[nd];
            vz_nnull += 1;
            if op_mark[trapb] == stamp { total -= 1; }              // the block that reports it is in the loop only when it goes on afterwards
            vz_chain[vz_nchain] = cur;
            vz_nchain += 1;
            cur = nextb;
            continue;
        }
        if ir_op[tt] != IR_JMP {
            if (ir_opt & 4194304) != 0 { write_err("chain stops: op "); write_err_int(ir_op[tt]); write_err(" cc "); write_err_int(ir_k[tt]); write_err(" bi "); write_err_int(ir_bi[tt]); write_err(" b "); write_err_int(ir_b[tt]); write_err(" t2 trap "); if vz_is_nulltrap(ir_t2[tt]) { write_err("yes"); } else { write_err("no"); } write_err("\n"); }
            return vz_fail(5948);
        }
        vz_chain[vz_nchain] = cur;
        vz_nchain += 1;
        cur = ir_t1[tt];
    }
    if vz_nchain + 1 != total || vz_nchain == 0 { return vz_fail(5953); }
    // the header: loads and the branch only
    i64 j = ir_bs[h];
    while j < ir_be[h] - 1 {
        if ir_op[j] != IR_LOAD && ir_op[j] != IR_NOP && ir_op[j] != IR_CONST { return vz_fail(5957); }
        j += 1;
    }
    // the step of the counter: the three instructions load, add, store at the end of the last block
    i64 lastb = vz_chain[vz_nchain - 1];
    i64 e = ir_be[lastb] - 2;
    while e >= ir_bs[lastb] && ir_op[e] == IR_NOP { e -= 1; }
    i64 inch = e;
    if inch < ir_bs[lastb] || ir_op[inch] != IR_STORE || ir_a[inch] != 30 || vn_slot(inch) != islot || ir_bi[inch] != 0 { return vz_fail(5965); }
    i64 ad = rn_find_def(lastb, inch, ir_b[inch]);
    if ad < 0 || ir_op[ad] != IR_ADD || ir_bi[ad] != 1 || ir_b[ad] != 1 { return vz_fail(5967); }
    i64 ld = rn_find_def(lastb, ad, ir_a[ad]);
    if ld < 0 || ir_op[ld] != IR_LOAD || ir_a[ld] != 30 || vn_slot(ld) != islot { return vz_fail(5969); }
    // between the load and the store only the add (and nops)
    i64 m = ld + 1;
    while m < inch {
        if m != ad && ir_op[m] != IR_NOP { return vz_fail(5973); }
        m += 1;
    }
    if !vz_scan(q, islot, ld, inch, false) { return vz_fail(5976); }
    // doubles: `-irdbg 536870912` keeps them scalar (0.9.128 did that by default, from a measurement of a poor vector loop: 320 against
    // 308 ms; with pointers and one branch for each turn the vector loop is 106 ms against 297 ms)
    if vz_has_fp == 1 && (ir_opt & 536870912) != 0 { return vz_fail(5979); }
    vz_npk = 0;
    {
        i64 ak = 0;
        while ak < vz_nacc {
            if vz_pk_find(vz_acc_base[ak], vz_acc_off[ak], true) < 0 { return vz_fail(5984); }
            ak += 1;
        }
    }
    // the registers the body writes must not be needed after the loop (the original header runs once more and writes its own)
    i64 ex = cl_exit[q];
    i64 c = 0;
    while c < vz_nchain {
        i64 jj = ir_bs[vz_chain[c]];
        while jj < ir_be[vz_chain[c]] - 1 {
            i64 dr = ir_d[jj];
            if dr > 0 && dr < 64 && ir_op[jj] != IR_NOP {
                bool in_header = false;
                i64 hj = ir_bs[h];
                while hj < ir_be[h] { if ir_d[hj] == dr { in_header = true; } hj += 1; }
                // x2..x7 (v3..v8) look live at every call after the loop (the lifter passes all the argument registers); no value of the loop is kept there
                if !in_header && (dr < 3 || dr > 8) && (op_li[ex] & (1 << dr)) != 0 { if (ir_opt & 4194304) != 0 { write_err("live reg "); write_err_int(dr); write_err(" exit B"); write_err_int(ex); write_err("\n"); } return vz_fail(5999); }
                if (op_li[h] & (1 << dr)) != 0 && vz_kind[dr] != 0 { }
            }
            jj += 1;
        }
        c += 1;
    }
    // the new blocks: VP (once: the broadcasts, the limit n - 1 into a stack cell), VH (the test of every turn), VB (the body)
    i64 qcell = 0 - (op_maxq() + 8);
    i64 boff = vz_slot_off(cl_bval[q]);
    i64 vp = ir_new_block(0 - 1);
    ir_set_block(vp);
    // the doubles that the body reads and does not write: made into vectors once
    {
        i64 u = 0;
        while u < 64 { vz_bq[u] = 0; u += 1; }
    }
    i64 vbnd = ir_vreg(0);
    i64 br_guard = 0 - 1;
    i64 vpb = 0 - 1;
    if cl_bkind[q] == 0 {
        ir_add(IR_CONST, vbnd, 0, 0, 0, cl_bval[q]);
    } else {
        i64 lb = ir_add(IR_LOAD, vbnd, 30, 0, 0, 0);
        ir_w[lb] = 8;
        ir_k[lb] = boff;
    }
    // n - 1 must not wrap: the smallest number (0 for an unsigned compare) skips the vector loop
    i64 vlim = ir_vreg(0);
    i64 vmin = ir_vreg(0);
    i64 minv = 0;
    i64 gcc = IR_ULT;
    i64 nchunks = 4;                             // 16-byte chunks in one turn of the vector loop
    if vz_w == 1 { nchunks = 2; }
    i64 per_turn = 16 * nchunks / vz_w;          // elements in one turn
    if cl_cc[q] == IR_LT { minv = (1 << 63) + per_turn - 1; gcc = IR_LT; } else { minv = per_turn - 1; }
    ir_add(IR_CONST, vmin, 0, 0, 0, minv);
    br_guard = ir_add(IR_BR, 0, vbnd, vmin, 0, gcc);
    vpb = ir_new_block(0 - 1);
    ir_set_block(vpb);
    // the broadcasts (the registers of the loop's doubles are live in here)
    vz_hoist(q);
    {
        i64 hu = 0;
        while hu < vz_nhs {
            i64 hx = ir_vreg(0);
            i64 hl = ir_add(IR_LOAD, hx, 30, 0, 0, 0);
            ir_w[hl] = 8;
            ir_k[hl] = vz_slot_off(vz_hs[hu]);
            i64 hqv = ir_vreg(2);
            i64 hd = ir_add(IR_VDUP, hqv, hx, 0, 0, 0);
            ir_w[hd] = vz_arr();
            vz_hq[hu] = hqv;
            hu += 1;
        }
        i64 au = 0;
        while au < vz_nacc2 {
            i64 zx = ir_vreg(0);
            ir_add(IR_CONST, zx, 0, 0, 0, 0);
            i64 zch = 0;
            while zch < nchunks {
                i64 zq = ir_vreg(2);
                i64 zd = ir_add(IR_VDUP, zq, zx, 0, 0, 0);
                ir_w[zd] = 1;
                vz_acc_q[au * 4 + zch] = zq;
                zch += 1;
            }
            au += 1;
        }
    }
    i64 vbnd2 = ir_vreg(0);
    if cl_bkind[q] == 0 {
        ir_add(IR_CONST, vbnd2, 0, 0, 0, cl_bval[q]);
    } else {
        i64 lb2 = ir_add(IR_LOAD, vbnd2, 30, 0, 0, 0);
        ir_w[lb2] = 8;
        ir_k[lb2] = boff;
    }
    ir_add(IR_ADD, vlim, vbnd2, 0 - (per_turn - 1), 1, 0);
    i64 stl = ir_add(IR_STORE, 0, 30, vlim, 0, qcell);
    ir_w[stl] = 8;
    // the data pointers of heap arrays (base 100000 + slot): loaded once; two different arrays must not overlap (else the scalar loop runs)
    {
        i64 hu = 0;
        while hu < vz_npk {
            vz_hpv[hu] = 0;
            if vz_pk_base[hu] % 1000000 >= 100000 {
                i64 hs = 0 - 1;
                i64 hv = 0;
                while hv < hu { if vz_pk_base[hv] % 1000000 == vz_pk_base[hu] % 1000000 { hs = hv; } hv += 1; }
                if hs >= 0 { vz_hpv[hu] = vz_hpv[hs]; }
                else {
                    i64 hh = ir_vreg(0);
                    i64 lh0 = ir_add(IR_LOAD, hh, 30, 0, 0, 0);
                    ir_w[lh0] = 8;
                    i64 hd = hh;
                    if vz_pk_base[hu] % 1000000 >= 200000 {
                        ir_k[lh0] = vz_slot_off(vz_pk_base[hu] % 1000000 - 200000);       // a pointer variable: the slot holds the data pointer itself
                    } else {
                        ir_k[lh0] = vz_slot_off(vz_pk_base[hu] % 1000000 - 100000);
                        hd = ir_vreg(0);
                        i64 lh1 = ir_add(IR_LOAD, hd, hh, 0, 0, 0);
                        ir_w[lh1] = 8;
                        ir_k[lh1] = 16;
                    }
                    i64 shd = ir_add(IR_STORE, 0, 30, hd, 0, qcell - 8 * (17 + hu));
                    ir_w[shd] = 8;
                    vz_hpv[hu] = 1 + hu;                    // the cell qcell - 8 * (17 + hu) holds the pointer
                }
            }
            hu += 1;
        }
        i64 nu = 0;
        while nu < vz_nnull {
            i64 nr = ir_vreg(0);
            i64 nl = ir_add(IR_LOAD, nr, 30, 0, 0, 0);
            ir_w[nl] = 8;
            ir_k[nl] = vz_null_off[nu];
            i64 nbr = ir_add(IR_BR, 0, nr, 0, 1, IR_EQ);
            ir_t1[nbr] = h;
            i64 nnx = ir_new_block(0 - 1);
            ir_t2[nbr] = nnx;
            ir_set_block(nnx);
            nu += 1;
        }
        i64 ha = 0;
        while ha < vz_npk {
            i64 hb = ha + 1;
            while hb < vz_npk {
                if vz_hpv[ha] != 0 && vz_hpv[hb] != 0 && vz_hpv[ha] != vz_hpv[hb] {
                    i64 span = per_turn * vz_w + 256;
                    i64 df = ir_vreg(0);
                    i64 ra1 = ir_vreg(0);
                    i64 rb1 = ir_vreg(0);
                    i64 lca = ir_add(IR_LOAD, ra1, 30, 0, 0, 0);
                    ir_w[lca] = 8;
                    ir_k[lca] = qcell - 8 * (17 + vz_hpv[ha] - 1);
                    i64 lcb = ir_add(IR_LOAD, rb1, 30, 0, 0, 0);
                    ir_w[lcb] = 8;
                    ir_k[lcb] = qcell - 8 * (17 + vz_hpv[hb] - 1);
                    ir_add(IR_SUB, df, ra1, rb1, 0, 0);
                    i64 df2 = ir_vreg(0);
                    ir_add(IR_ADD, df2, df, span, 1, 0);
                    i64 brx = ir_add(IR_BR, 0, df2, 2 * span, 1, IR_ULE);
                    ir_t1[brx] = h;
                    i64 nxt = ir_new_block(0 - 1);
                    ir_t2[brx] = nxt;
                    ir_set_block(nxt);
                }
                hb += 1;
            }
            ha += 1;
        }
    }
    // the pointers: base + 8 * i + offset at the start, one cell each
    {
        i64 pu = 0;
        while pu < vz_npk {
            vz_pk_cell[pu] = qcell - 8 * (pu + 1);
            i64 ti0 = ir_vreg(0);
            i64 li0 = ir_add(IR_LOAD, ti0, 30, 0, 0, 0);
            ir_w[li0] = 8;
            ir_k[li0] = vz_slot_off(cl_slot[q]);
            i64 sh0 = ir_vreg(0);
            if vz_lg == 0 { ir_add(IR_COPY, sh0, ti0, 0, 0, 0); } else { ir_add(IR_SHL, sh0, ti0, vz_lg, 1, 0); }
            // every temporary below lives for one instruction (the scratch registers are reused): the sum is built in a stack cell
            i64 pbase = vz_pk_base[pu] % 1000000;
            i64 pdyn = vz_pk_base[pu] / 1000000;
            i64 acell = vz_pk_cell[pu];
            if pbase >= 100000 {
                i64 pbv = ir_vreg(0);
                i64 lcp = ir_add(IR_LOAD, pbv, 30, 0, 0, 0);
                ir_w[lcp] = 8;
                ir_k[lcp] = qcell - 8 * (17 + vz_hpv[pu] - 1);
                i64 pbs = ir_vreg(0);
                if vz_lg == 0 { ir_add(IR_ADD, pbs, pbv, sh0, 0, 0); } else { ir_add(IR_ADD, pbs, pbv, sh0, 0, 0); }
                i64 sa0 = ir_add(IR_STORE, 0, 30, pbs, 0, acell);
                ir_w[sa0] = 8;
            } else {
                i64 pa = ir_vreg(0);
                ir_add(IR_ADD, pa, pbase, sh0, 0, 0);
                i64 sa1 = ir_add(IR_STORE, 0, 30, pa, 0, acell);
                ir_w[sa1] = 8;
            }
            if pdyn != 0 {
                // the invariant part of the index (the offset of a row): the cell is read here, shifted and added
                i64 dreg = ir_vreg(0);
                i64 dld = ir_add(IR_LOAD, dreg, 30, 0, 0, 0);
                ir_w[dld] = 8;
                ir_k[dld] = pdyn - 500000;
                i64 dsh = ir_vreg(0);
                if vz_lg == 0 { ir_add(IR_COPY, dsh, dreg, 0, 0, 0); } else { ir_add(IR_SHL, dsh, dreg, vz_lg, 1, 0); }
                i64 sd0 = ir_add(IR_STORE, 0, 30, dsh, 0, qcell - 8 * 40);
                ir_w[sd0] = 8;
                i64 cur0 = ir_vreg(0);
                i64 lcu = ir_add(IR_LOAD, cur0, 30, 0, 0, 0);
                ir_w[lcu] = 8;
                ir_k[lcu] = acell;
                i64 dsv = ir_vreg(0);
                i64 lds = ir_add(IR_LOAD, dsv, 30, 0, 0, 0);
                ir_w[lds] = 8;
                ir_k[lds] = qcell - 8 * 40;
                i64 sm = ir_vreg(0);
                ir_add(IR_ADD, sm, cur0, dsv, 0, 0);
                i64 sd1 = ir_add(IR_STORE, 0, 30, sm, 0, acell);
                ir_w[sd1] = 8;
            }
            i64 cur1 = ir_vreg(0);
            i64 lc1 = ir_add(IR_LOAD, cur1, 30, 0, 0, 0);
            ir_w[lc1] = 8;
            ir_k[lc1] = acell;
            i64 pb = ir_vreg(0);
            ir_add(IR_ADD, pb, cur1, vz_pk_off[pu], 1, 0);
            i64 sp0 = ir_add(IR_STORE, 0, 30, pb, 0, vz_pk_cell[pu]);
            ir_w[sp0] = 8;
            pu += 1;
        }
    }
    i64 jpb = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    i64 vh0 = ir_new_block(0 - 1);
    ir_t1[jpb] = vh0;
    ir_set_block(vh0);
    i64 t0 = ir_vreg(0);
    i64 t1 = ir_vreg(0);
    {
        i64 la = ir_add(IR_LOAD, t0, 30, 0, 0, 0);
        ir_w[la] = 8;
        ir_k[la] = vz_slot_off(cl_slot[q]);
        i64 lc = ir_add(IR_LOAD, t1, 30, 0, 0, 0);
        ir_w[lc] = 8;
        ir_k[lc] = qcell;
    }
    i64 br0 = ir_add(IR_BR, 0, t0, t1, 0, cl_cc[q]);
    i64 vb = ir_new_block(0 - 1);
    ir_t1[br0] = vb;
    ir_t2[br0] = h;
    ir_t1[br_guard] = h;
    ir_t2[br_guard] = vpb;
    // the vector body
    ir_set_block(vb);
    {
        i64 chunk = 0;
        while chunk < nchunks {
            vz_shift = chunk * 16;
            vz_ab29 = 0;
            vz_ab30 = 0;
            vz_ti = ir_vreg(0);
            i64 lti = ir_add(IR_LOAD, vz_ti, 30, 0, 0, 0);
            ir_w[lti] = 8;
            ir_k[lti] = ir_k[ld];
            vz_scan(q, islot, ld, inch, true);
            chunk += 1;
        }
        vz_shift = 0;
    }
    // the pointers move on by four elements
    {
        i64 pv = 0;
        while pv < vz_npk {
            i64 pcur = ir_vreg(0);
            i64 lc0 = ir_add(IR_LOAD, pcur, 30, 0, 0, 0);
            ir_w[lc0] = 8;
            ir_k[lc0] = vz_pk_cell[pv];
            i64 pnext = ir_vreg(0);
            ir_add(IR_ADD, pnext, pcur, 16 * nchunks, 1, 0);
            i64 sc0 = ir_add(IR_STORE, 0, 30, pnext, 0, vz_pk_cell[pv]);
            ir_w[sc0] = 8;
            pv += 1;
        }
    }
    // i = i + 4
    {
        i64 tk = ir_vreg(0);
        i64 lk = ir_add(IR_LOAD, tk, 30, 0, 0, 0);
        ir_w[lk] = 8;
        ir_k[lk] = ir_k[ld];
        i64 tj = ir_vreg(0);
        ir_add(IR_ADD, tj, tk, per_turn, 1, 0);
        i64 si = ir_add(IR_STORE, 0, 30, tj, 0, ir_k[ld]);
        ir_w[si] = 8;
        // the test at the bottom: one branch for each turn
        i64 tlim = ir_vreg(0);
        i64 lq = ir_add(IR_LOAD, tlim, 30, 0, 0, 0);
        ir_w[lq] = 8;
        ir_k[lq] = qcell;
        vz_br_end = ir_add(IR_BR, 0, tj, tlim, 0, cl_cc[q]);
        ir_t1[vz_br_end] = vb;
        ir_t2[vz_br_end] = h;
    }
    // what does not change from turn to turn is made once, in front of the body
    if (ir_opt & 17179869184) == 0 { vz_dead_loads(vb); }          // -irdbg 17179869184: keep the repeated loads
    vz_licm(vb, br0);
    // the exit of the vector loop: the two partial sums of every accumulator are added to its slot
    if vz_nacc2 > 0 {
        i64 vx = ir_new_block(0 - 1);
        ir_set_block(vx);
        i64 au2 = 0;
        while au2 < vz_nacc2 {
            // two temporaries at a time (the lowering has few scratch registers): slot + lane 0, then + lane 1
            i64 ov = ir_vreg(0);
            i64 lo = ir_add(IR_LOAD, ov, 30, 0, 0, 0);
            ir_w[lo] = 8;
            ir_k[lo] = vz_slot_off(vz_acc_slot[au2]);
            i64 run = ov;
            i64 xch = 0;
            while xch < nchunks && vz_w == 4 {
                // four 32-bit lanes (zero-extended, added in 64 bits: the low 32 bits are the sum modulo 2^32)
                i64 ln = 0;
                while ln < 4 {
                    i64 l4 = ir_vreg(0);
                    i64 e4 = ir_add(IR_VLANE, l4, vz_acc_q[au2 * 4 + xch], 0, 0, ln * 4);
                    ir_w[e4] = 4;
                    i64 s4r = ir_vreg(0);
                    ir_add(IR_ADD, s4r, run, l4, 0, 0);
                    run = s4r;
                    ln += 1;
                }
                xch += 1;
            }
            while xch < nchunks && vz_w != 4 {
                i64 l0 = ir_vreg(0);
                i64 e0 = ir_add(IR_VLANE, l0, vz_acc_q[au2 * 4 + xch], 0, 0, 0);
                ir_w[e0] = 8;
                i64 s1 = ir_vreg(0);
                ir_add(IR_ADD, s1, run, l0, 0, 0);
                i64 l1 = ir_vreg(0);
                i64 e1 = ir_add(IR_VLANE, l1, vz_acc_q[au2 * 4 + xch], 0, 0, 8);
                ir_w[e1] = 8;
                i64 s2 = ir_vreg(0);
                ir_add(IR_ADD, s2, s1, l1, 0, 0);
                run = s2;
                xch += 1;
            }
            if vz_w == 4 {
                i64 rx4 = ir_vreg(0);
                i64 ex4 = ir_add(IR_EXT, rx4, run, 0, 0, 32);
                ir_w[ex4] = 1;
                run = rx4;
            }
            i64 so = ir_add(IR_STORE, 0, 30, run, 0, 0);
            ir_w[so] = 8;
            ir_k[so] = vz_slot_off(vz_acc_slot[au2]);
            au2 += 1;
        }
        i64 jx = ir_add(IR_JMP, 0, 0, 0, 0, 0);
        ir_t1[jx] = h;
        ir_t2[br0] = vx;
        ir_t2[vz_br_end] = vx;
    }
    // the jumps into the header from outside the loop go to VP
    i64 nb0 = vp;
    op_mark_loop(l);
    i64 bb = 0;
    while bb < nb0 {
        if op_mark[bb] != op_stamp && op_po[bb] >= 0 {
            i64 tb = ir_be[bb] - 1;
            i64 top = ir_op[tb];
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

// ---------------------------------------------------------------------------------------------- unroll-and-jam (design 31, L7)
// A counted loop O (step 1, j < n) whose body is  PRE ; an inner counted loop I ; POST  runs two turns at once in front of the original
// loop (which stays and does the rest). Each part is a straight chain of blocks (a null check may branch to a trap). The blocks, in order:
//   G   the arrays that POST writes are not the arrays that the loop reads (the headers differ), else the original loop
//   H2  if j + 1 < n go on, else the original header
//   PRE of the turn j (the cells it writes are new cells), PRE of the turn j + 1 (the original cells, j + 1 in place of j)
//   H3  the test of I (k < bound), the body of I for j, the body of I for j + 1 (the step of k is in the second one)
//   POST of j, POST of j + 1, then j = j + 2 and back to H2
// Every accumulator keeps its own order of operations, so the results are the same bits. The cells that the part writes must be written
// before they are read in the same turn (a value that goes from one turn to the next stops the change), the start and the bound of I
// must not depend on j, no call, and the stores of POST must go to arrays that nothing in the loop reads (tested at run time: the headers
// of the arrays are different objects). `-irdbg 4503599627370496` switches it off, `-irdbg 9007199254740992` says why it did not fire.
#define UJ_MAXB 48
i64 uj_pre[UJ_MAXB];
i64 uj_npre;
i64 uj_inn[UJ_MAXB];
i64 uj_ninn;
i64 uj_post[UJ_MAXB];
i64 uj_npost;
i64 uj_m1[RN_MAXB];
i64 uj_m2[RN_MAXB];
i64 uj_wo[64];                   // the frame cells that the loop writes (offsets), and the new cells for the turn j
i64 uj_wt[64];
i64 uj_wseen[64];                // 1: stored before it was read in the order of the turn
i64 uj_nw;
i64 uj_f[2048];                  // all instructions of the parts in the order of the turn
i64 uj_fs[2048];                 // the part of each (0 PRE, 1 H3, 2 I, 3 POST)
i64 uj_nf;
i64 uj_wkey[16];                 // the arrays that POST writes (keys), and the ones that are read
i64 uj_nwk;
i64 uj_rkey[16];
i64 uj_nrk;
i64 uj_jo;
i64 uj_ko;
i64 uj_done[32];
i64 uj_ndone;
i64 uj_count;                    // all functions

bool uj_fail(i64 line) {
    if ((ir_opt & 9007199254740992) != 0) {
        write_err("uj gave up at jc_opt.j:");
        write_err_int(line);
        write_err(" fn=");
        write_err(@ir_fname);
        write_err("\n");
    }
    return false;
}

// the straight chain of blocks from start up to (not including) stop
i64 uj_walk(i64 start, i64 stop, i64 stamp, i64^ out) {
    i64 n = 0;
    i64 cur = start;
    while cur != stop {
        if cur < 0 || op_mark[cur] != stamp || n >= UJ_MAXB - 1 { return 0 - 1; }
        out[n] = cur;
        n += 1;
        i64 tt = ir_be[cur] - 1;
        i64 nxt = 0 - 1;
        if ir_op[tt] == IR_JMP { nxt = ir_t1[tt]; }
        else if ir_op[tt] == IR_BR && ir_bi[tt] == 1 && ir_b[tt] == 0 {
            if ir_k[tt] == IR_NE && vz_is_nulltrap(ir_t2[tt]) { nxt = ir_t1[tt]; }
            else if ir_k[tt] == IR_EQ && vz_is_nulltrap(ir_t1[tt]) { nxt = ir_t2[tt]; }
            else { return 0 - 1; }
        } else { return 0 - 1; }
        cur = nxt;
    }
    return n;
}

// is the frame cell with this offset stored by an instruction of the nest? (a cell that is only read, such as the cell with the handle of an array, may stay)
bool uj_stored(i64 off) {
    i64 p = 0;
    while p < uj_nf {
        i64 x = uj_f[p];
        if ir_op[x] == IR_STORE && ir_a[x] == 30 && ir_k[x] == off { return true; }
        p += 1;
    }
    return false;
}

i64 uj_wfind(i64 off) {
    i64 i = 0;
    while i < uj_nw { if uj_wo[i] == off { return i; } i += 1; }
    return 0 - 1;
}

// the last instruction before position p of the list (inside the same part) that writes the register r
i64 uj_def(i64 p, i64 r) {
    i64 s = uj_fs[p];
    i64 q = p - 1;
    while q >= 0 && uj_fs[q] == s {
        i64 x = uj_f[q];
        if ir_d[x] == r && ir_op[x] != IR_NOP && ir_op[x] != IR_STORE && ir_op[x] != IR_BR && ir_op[x] != IR_JMP { return q; }
        q -= 1;
    }
    return 0 - 1;
}

// the cell that holds the array whose header is in the register r at position p (copies are followed): 1000000 * (29 or 30) + the offset
// of the cell + 500000, or -1
i64 uj_hdr(i64 p, i64 r) {
    i64 hreg = r;
    i64 at = p;
    i64 guard = 0;
    while guard < 6 {
        i64 dh = uj_def(at, hreg);
        if dh < 0 { return 0 - 1; }
        i64 xh = uj_f[dh];
        if ir_op[xh] == IR_COPY { hreg = ir_a[xh]; at = dh; guard += 1; continue; }
        if ir_op[xh] == IR_LOAD && ir_w[xh] == 8 && ir_a[xh] == 30 {
            // a reload of a frame cell: if this part stored the header there before, follow the stored register
            i64 sq = dh - 1;
            i64 found = 0 - 1;
            while sq >= 0 && uj_fs[sq] == uj_fs[dh] && found < 0 {
                i64 sx = uj_f[sq];
                if ir_op[sx] == IR_STORE && ir_a[sx] == 30 && ir_k[sx] == ir_k[xh] { found = sq; }
                sq -= 1;
            }
            if found >= 0 {
                hreg = ir_b[uj_f[found]];
                at = found;
                guard += 1;
                continue;
            }
            return 30 * 1000000 + ir_k[xh] + 500000;
        }
        if ir_op[xh] == IR_LOAD && ir_w[xh] == 8 && ir_a[xh] == 29 {
            return ir_a[xh] * 1000000 + ir_k[xh] + 500000;
        }
        return 0 - 1;
    }
    return 0 - 1;
}

// the array object behind the register r (the data pointer of an array, used at position p): the data pointer is  load [header + 16]
i64 uj_key_of_data(i64 p, i64 r) {
    i64 d2 = uj_def(p, r);
    if d2 < 0 { return 0 - 1; }
    i64 x2 = uj_f[d2];
    if ir_op[x2] != IR_LOAD || ir_w[x2] != 8 || ir_k[x2] != 16 { return 0 - 1; }
    return uj_hdr(d2, ir_a[x2]);
}

i64 uj_key(i64 p) {
    i64 x = uj_f[p];
    i64 a = ir_a[x];
    if a == 29 || a == 30 { return 0 - 1; }
    i64 d1 = uj_def(p, a);
    if d1 < 0 { return 0 - 1; }
    i64 x1 = uj_f[d1];
    i64 cg = 0;
    while ir_op[x1] == IR_COPY && cg < 6 {
        a = ir_a[x1];
        d1 = uj_def(d1, a);
        if d1 < 0 { return 0 - 1; }
        x1 = uj_f[d1];
        cg += 1;
    }
    if ir_op[x1] == IR_LOAD { return uj_key_of_data(d1 + 1, a); }
    if ir_op[x1] != IR_ADD || ir_bi[x1] != 0 { return 0 - 1; }
    // a global array: the address is (the index << 3) + the register of the global area (v29), the array is told by the displacement of the access.
    // Like the vectoriser: two accesses with displacements that are 16 or more bytes apart are different arrays, the same displacement is the same array
    // (two displacements closer than 16 are not told apart here: the key is the displacement rounded down to 16, and the scan of a part refuses a store and a load of one key)
    if ir_a[x1] == 29 || ir_b[x1] == 29 { return 2000000000 + (ir_k[x] / 16) * 16; }
    i64 k1 = uj_key_of_data(d1, ir_a[x1]);
    if k1 >= 0 { return k1; }
    return uj_key_of_data(d1, ir_b[x1]);
}

bool uj_scan(i64 qo, i64 qi) {
    uj_nf = 0;
    uj_nw = 0;
    uj_nwk = 0;
    uj_nrk = 0;
    i64 seg = 0;
    while seg < 4 {
        i64 cnt = 0;
        if seg == 0 { cnt = uj_npre; }
        else if seg == 1 { cnt = 1; }
        else if seg == 2 { cnt = uj_ninn; }
        else { cnt = uj_npost; }
        i64 c = 0;
        while c < cnt {
            i64 b = 0;
            if seg == 0 { b = uj_pre[c]; }
            else if seg == 1 { b = cl_head[qi]; }
            else if seg == 2 { b = uj_inn[c]; }
            else { b = uj_post[c]; }
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                if ir_op[j] != IR_NOP {
                    if uj_nf >= 2000 { return uj_fail(1); }
                    uj_f[uj_nf] = j;
                    uj_fs[uj_nf] = seg;
                    uj_nf += 1;
                }
                j += 1;
            }
            c += 1;
        }
        seg += 1;
    }
    i64 jo = uj_jo;
    i64 ko = uj_ko;
    i64 p = 0;
    while p < uj_nf {
        i64 x = uj_f[p];
        i64 op = ir_op[x];
        i64 seg2 = uj_fs[p];
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { return uj_fail(2); }
        if op == IR_BR || op == IR_JMP { p += 1; continue; }
        if ir_d[x] >= 64 || ir_a[x] >= 64 || (ir_uses_b(op) && ir_bi[x] == 0 && ir_b[x] >= 64) { return uj_fail(3); }
        if op == IR_LOAD && ir_a[x] == 30 {
            i64 off = ir_k[x];
            if ir_w[x] != 8 || off % 8 != 0 { return uj_fail(4); }
            if off >= 0 && (off / 8 >= 8192 || op_plain[off / 8] != 1) { return uj_fail(5); }
            if off != jo && off != ko {
                i64 wi = uj_wfind(off);
                if wi < 0 {
                    if uj_nw >= 60 { return uj_fail(6); }
                    uj_wo[uj_nw] = off;
                    uj_wseen[uj_nw] = 0;
                    uj_wt[uj_nw] = 0 - 1;                  // read first: if it is stored later, the value goes from turn to turn
                    uj_nw += 1;
                    wi = uj_nw - 1;
                    uj_wseen[wi] = 2;                      // 2: read before any store
                }
            }
        } else if op == IR_STORE && ir_a[x] == 30 {
            i64 off2 = ir_k[x];
            if ir_w[x] != 8 || off2 % 8 != 0 { return uj_fail(7); }
            if off2 >= 0 && (off2 / 8 >= 8192 || op_plain[off2 / 8] != 1) { return uj_fail(8); }
            if off2 == jo && x != cl_sti[qo] { return uj_fail(22); }
            if off2 == ko && !(seg2 == 0 || x == cl_sti[qi]) { return uj_fail(23); }
            if off2 != jo && off2 != ko {
                i64 wj = uj_wfind(off2);
                if wj < 0 {
                    if uj_nw >= 60 { return uj_fail(9); }
                    uj_wo[uj_nw] = off2;
                    uj_wseen[uj_nw] = 1;
                    uj_wt[uj_nw] = 0 - 1;
                    uj_nw += 1;
                } else if uj_wseen[wj] == 0 { uj_wseen[wj] = 1; }
            }
            if ir_b[x] >= 64 { return uj_fail(10); }
        } else if op == IR_STORE {
            if ir_a[x] == 29 { return uj_fail(11); }
            if seg2 != 3 { return uj_fail(12); }
            i64 ky = uj_key(p);
            if ky < 0 { return uj_fail(13); }
            i64 u = 0;
            bool have = false;
            while u < uj_nwk { if uj_wkey[u] == ky { have = true; } u += 1; }
            if !have { if uj_nwk >= 8 { return uj_fail(14); } uj_wkey[uj_nwk] = ky; uj_nwk += 1; }
        } else if op == IR_LOAD && ir_a[x] != 29 && ir_k[x] == 16 && ir_w[x] == 8 && uj_hdr(p, ir_a[x]) >= 0 {
            // the data pointer of an array: it reads the header, which nothing in the loop writes
        } else if op == IR_LOAD && ir_a[x] != 29 {
            i64 ky2 = uj_key(p);
            if ky2 < 0 { return uj_fail(15); }
            i64 u2 = 0;
            bool have2 = false;
            while u2 < uj_nrk { if uj_rkey[u2] == ky2 { have2 = true; } u2 += 1; }
            if !have2 { if uj_nrk >= 8 { return uj_fail(16); } uj_rkey[uj_nrk] = ky2; uj_nrk += 1; }
        } else if ir_a[x] == 30 || (ir_uses_b(op) && ir_bi[x] == 0 && ir_b[x] == 30) {
            return uj_fail(17);                    // the address of the frame is used for something else
        }
        p += 1;
    }
    // a cell that is read before it is stored in the turn (and stored somewhere in the loop) goes from one turn to the next
    i64 w = 0;
    while w < uj_nw {
        if uj_wseen[w] == 2 {
            // read first: allowed only when nothing stores it
            i64 p2 = 0;
            while p2 < uj_nf {
                i64 x2 = uj_f[p2];
                if ir_op[x2] == IR_STORE && ir_a[x2] == 30 && ir_k[x2] == uj_wo[w] { return uj_fail(18); }
                p2 += 1;
            }
        }
        w += 1;
    }
    // the cells that are only read keep their place; the ones that are stored get new cells
    i64 base = op_maxq();
    i64 nn = 0;
    w = 0;
    while w < uj_nw {
        bool stored = false;
        i64 p3 = 0;
        while p3 < uj_nf {
            i64 x3 = uj_f[p3];
            if ir_op[x3] == IR_STORE && ir_a[x3] == 30 && ir_k[x3] == uj_wo[w] { stored = true; }
            p3 += 1;
        }
        if stored { uj_wt[w] = 0 - (base + 8 + 8 * nn); nn += 1; }
        else { uj_wt[w] = uj_wo[w]; }
        w += 1;
    }
    // the arrays that are written are not read by the loop (the same cell would be the same array)
    i64 a1 = 0;
    while a1 < uj_nwk {
        i64 a2 = 0;
        while a2 < uj_nrk { if uj_wkey[a1] == uj_rkey[a2] { return uj_fail(19); } a2 += 1; }
        // the cell with the array must not be written by the loop
        i64 cellb = uj_wkey[a1] / 1000000;
        i64 cello = uj_wkey[a1] % 1000000 - 500000;
        if cellb == 30 && uj_stored(cello) { return uj_fail(20); }
        a1 += 1;
    }
    i64 a3 = 0;
    while a3 < uj_nrk {
        i64 cb = uj_rkey[a3] / 1000000;
        i64 co = uj_rkey[a3] % 1000000 - 500000;
        if cb == 30 && uj_stored(co) { return uj_fail(21); }
        a3 += 1;
    }
    return true;
}

// the block b copied as a new block (mode 1: the turn j, new cells; mode 2: the turn j + 1, the cells of the loop); the step of j is left out,
// the step of k only when keepk is false
i64 uj_copy_block(i64 b, i64 mode, bool keepk) {
    i64 nb = ir_new_block(0 - 1);
    ir_set_block(nb);
    i64 j = ir_bs[b];
    while j < ir_be[b] {
        i64 op = ir_op[j];
        if op == IR_NOP { j += 1; continue; }
        if (op == IR_LOAD || op == IR_STORE) && ir_a[j] == 30 {
            i64 off = ir_k[j];
            if off == uj_jo {
                if op == IR_STORE { j += 1; continue; }
                i64 e = ir_add(op, ir_d[j], ir_a[j], ir_b[j], ir_bi[j], off);
                ir_w[e] = ir_w[j];
                if mode == 2 { ir_add(IR_ADD, ir_d[j], ir_d[j], 1, 1, 0); }
                j += 1;
                continue;
            }
            if off == uj_ko && op == IR_STORE && !keepk { j += 1; continue; }
            if mode == 1 {
                i64 wi = uj_wfind(off);
                if wi >= 0 { off = uj_wt[wi]; }
            }
            i64 e2 = ir_add(op, ir_d[j], ir_a[j], ir_b[j], ir_bi[j], off);
            ir_w[e2] = ir_w[j];
            j += 1;
            continue;
        }
        i64 e3 = ir_add(op, ir_d[j], ir_a[j], ir_b[j], ir_bi[j], ir_k[j]);
        ir_w[e3] = ir_w[j];
        ir_t1[e3] = ir_t1[j];
        ir_t2[e3] = ir_t2[j];
        j += 1;
    }
    return nb;
}

// a chain copied; the targets inside the chain are changed to the copies
void uj_copy_chain(i64^ list, i64 n, i64^ map, i64 mode, bool keepk) {
    i64 first = ir_nb;
    i64 c = 0;
    while c < n {
        map[list[c]] = uj_copy_block(list[c], mode, keepk);
        c += 1;
    }
    i64 nbk = first;
    while nbk < ir_nb {
        i64 tt = ir_be[nbk] - 1;
        if ir_op[tt] == IR_JMP || ir_op[tt] == IR_BR {
            if ir_t1[tt] >= 0 && ir_t1[tt] < RN_MAXB && map[ir_t1[tt]] >= 0 { ir_t1[tt] = map[ir_t1[tt]]; }
            if ir_op[tt] == IR_BR && ir_t2[tt] >= 0 && ir_t2[tt] < RN_MAXB && map[ir_t2[tt]] >= 0 { ir_t2[tt] = map[ir_t2[tt]]; }
        }
        nbk += 1;
    }
}

bool uj_make(i64 qo, i64 qi) {
    i64 ho = cl_head[qo];
    i64 hi = cl_head[qi];
    i64 lo = 0;
    while lo < op_nloops && op_lh[lo] != ho { lo += 1; }
    if lo >= op_nloops { return uj_fail(30); }
    op_mark_loop(lo);
    i64 stamp = op_stamp;
    if op_mark[hi] != stamp { return uj_fail(31); }
    uj_npre = uj_walk(cl_body[qo], hi, stamp, @uj_pre);
    uj_ninn = uj_walk(cl_body[qi], hi, stamp, @uj_inn);
    uj_npost = uj_walk(cl_exit[qi], ho, stamp, @uj_post);
    if uj_npre < 1 || uj_ninn < 1 || uj_npost < 1 { return uj_fail(32); }
    // every block of the loop is in a part (or the header, or a block that reports a null)
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 && op_mark[b] == stamp && b != ho && b != hi {
            bool inpart = false;
            i64 c = 0;
            while c < uj_npre { if uj_pre[c] == b { inpart = true; } c += 1; }
            c = 0;
            while c < uj_ninn { if uj_inn[c] == b { inpart = true; } c += 1; }
            c = 0;
            while c < uj_npost { if uj_post[c] == b { inpart = true; } c += 1; }
            if !inpart && !vz_is_nulltrap(b) { return uj_fail(33); }
        }
        b += 1;
    }
    // the steps are where the counted-loop analysis found them: the last block of POST (j) and of I (k)
    if cl_stb[qo] != uj_post[uj_npost - 1] || cl_stb[qi] != uj_inn[uj_ninn - 1] { return uj_fail(34); }
    uj_jo = vz_slot_off(cl_slot[qo]);
    uj_ko = vz_slot_off(cl_slot[qi]);
    // nothing is live in a register where a part starts
    // (v2 .. v8 look live in every block that can reach a null report: the call of __panic reads all the argument registers)
    i64 m28 = (1 << 28) - 2 - 508;          // x1 .. x27 without x2 .. x8; x28 holds the base of the globals and is live everywhere
    if (op_li[uj_pre[0]] & m28) != 0 {
        i64 lm = op_li[uj_pre[0]] & m28;
        i64 lb = 0;
        while ((lm >> lb) & 1) == 0 { lb += 1; }
        return uj_fail(3500 + lb);              // 3500 + the number of the first register that is live
    }
    if (op_li[hi] & m28) != 0 { return uj_fail(352); }
    if (op_li[uj_inn[0]] & m28) != 0 { return uj_fail(353); }
    if (op_li[uj_post[0]] & m28) != 0 { return uj_fail(354); }
    if (op_li[ho] & m28) != 0 { return uj_fail(355); }
    if !uj_scan(qo, qi) { return false; }
    // the start of I is a number; the bound of I and of O are not written by the loop
    {
        bool kinit = false;
        i64 c2 = 0;
        while c2 < uj_npre {
            i64 bb = uj_pre[c2];
            i64 jj = ir_bs[bb];
            while jj < ir_be[bb] {
                if ir_op[jj] == IR_STORE && ir_a[jj] == 30 && ir_k[jj] == uj_ko {
                    i64 dd = rn_find_def(bb, jj, ir_b[jj]);
                    if dd < 0 || ir_op[dd] != IR_CONST { return uj_fail(36); }
                    kinit = true;
                }
                jj += 1;
            }
            c2 += 1;
        }
        if !kinit { return uj_fail(37); }
        if cl_bkind[qi] == 1 {
            // the bound of I is a cell. The loop may set it at the start of every turn (the copy of n that `for k in 0..n` makes), but only
            // in PRE and only from a number or a cell that the loop does not write: then it does not depend on j
            i64 bo = vz_slot_off(cl_bval[qi]);
            if bo == uj_jo { return uj_fail(38); }
            i64 p4 = 0;
            while p4 < uj_nf {
                i64 x4 = uj_f[p4];
                if ir_op[x4] == IR_STORE && ir_a[x4] == 30 && ir_k[x4] == bo {
                    if uj_fs[p4] != 0 { return uj_fail(39); }
                    i64 dv = uj_def(p4, ir_b[x4]);
                    if dv < 0 { return uj_fail(40); }
                    i64 xv = uj_f[dv];
                    if ir_op[xv] == IR_CONST { }
                    else if ir_op[xv] == IR_LOAD && ir_a[xv] == 30 && ir_w[xv] == 8 && ir_k[xv] != uj_jo && ir_k[xv] != uj_ko {
                        i64 wv = uj_wfind(ir_k[xv]);
                        if wv >= 0 && uj_wt[wv] != ir_k[xv] { return uj_fail(41); }
                    } else { return uj_fail(42); }
                }
                p4 += 1;
            }
        }
    }
    // ---- build
    i64 nb0 = ir_nb;
    {
        i64 u = 0;
        while u < RN_MAXB { uj_m1[u] = 0 - 1; uj_m2[u] = 0 - 1; u += 1; }
    }
    // G: one block for each pair (array written, array read)
    i64 gfirst = 0 - 1;
    i64 prevbr = 0 - 1;
    i64 pa = 0;
    while pa < uj_nwk {
        i64 pb = 0;
        while pb < uj_nrk {
            if uj_wkey[pa] >= 2000000000 || uj_rkey[pb] >= 2000000000 { pb += 1; continue; }       // a global array has no cell with its pointer: its key tells it from the others
            i64 gb = ir_new_block(0 - 1);
            ir_set_block(gb);
            if gfirst < 0 { gfirst = gb; }
            if prevbr >= 0 { ir_t2[prevbr] = gb; }
            i64 ta = ir_vreg(0);
            i64 tb = ir_vreg(0);
            i64 la = ir_add(IR_LOAD, ta, uj_wkey[pa] / 1000000, 0, 0, uj_wkey[pa] % 1000000 - 500000);
            ir_w[la] = 8;
            i64 lb = ir_add(IR_LOAD, tb, uj_rkey[pb] / 1000000, 0, 0, uj_rkey[pb] % 1000000 - 500000);
            ir_w[lb] = 8;
            prevbr = ir_add(IR_BR, 0, ta, tb, 0, IR_EQ);
            ir_t1[prevbr] = ho;
            pb += 1;
        }
        pa += 1;
    }
    // H2: j + 1 < n
    i64 h2 = ir_new_block(0 - 1);
    ir_set_block(h2);
    if gfirst < 0 { gfirst = h2; }
    if prevbr >= 0 { ir_t2[prevbr] = h2; }
    i64 tj = ir_vreg(0);
    i64 tj1 = ir_vreg(0);
    i64 lj = ir_add(IR_LOAD, tj, 30, 0, 0, uj_jo);
    ir_w[lj] = 8;
    ir_add(IR_ADD, tj1, tj, 1, 1, 0);
    i64 brh2 = 0 - 1;
    if cl_bkind[qo] == 0 {
        brh2 = ir_add(IR_BR, 0, tj1, cl_bval[qo], 1, cl_cc[qo]);
    } else {
        i64 tn = ir_vreg(0);
        i64 ln = ir_add(IR_LOAD, tn, 30, 0, 0, vz_slot_off(cl_bval[qo]));
        ir_w[ln] = 8;
        brh2 = ir_add(IR_BR, 0, tj1, tn, 0, cl_cc[qo]);
    }
    ir_t2[brh2] = ho;
    // PRE (two copies), H3, I (two copies), POST (two copies), the step
    uj_copy_chain(@uj_pre, uj_npre, @uj_m1, 1, true);
    i64 pre1 = uj_m1[uj_pre[0]];
    i64 pre1_last = uj_m1[uj_pre[uj_npre - 1]];
    uj_copy_chain(@uj_pre, uj_npre, @uj_m2, 2, true);
    i64 pre2 = uj_m2[uj_pre[0]];
    i64 pre2_last = uj_m2[uj_pre[uj_npre - 1]];
    // H3: the header of I (the loads and the branch)
    i64 h3 = uj_copy_block(hi, 2, true);
    uj_copy_chain(@uj_inn, uj_ninn, @uj_m1, 1, false);
    i64 in1 = uj_m1[uj_inn[0]];
    i64 in1_last = uj_m1[uj_inn[uj_ninn - 1]];
    uj_copy_chain(@uj_inn, uj_ninn, @uj_m2, 2, true);
    i64 in2 = uj_m2[uj_inn[0]];
    i64 in2_last = uj_m2[uj_inn[uj_ninn - 1]];
    uj_copy_chain(@uj_post, uj_npost, @uj_m1, 1, true);
    i64 po1 = uj_m1[uj_post[0]];
    i64 po1_last = uj_m1[uj_post[uj_npost - 1]];
    uj_copy_chain(@uj_post, uj_npost, @uj_m2, 2, true);
    i64 po2 = uj_m2[uj_post[0]];
    i64 po2_last = uj_m2[uj_post[uj_npost - 1]];
    // the step: j = j + 2
    i64 st = ir_new_block(0 - 1);
    ir_set_block(st);
    i64 sj = ir_vreg(0);
    i64 sj2 = ir_vreg(0);
    i64 slj = ir_add(IR_LOAD, sj, 30, 0, 0, uj_jo);
    ir_w[slj] = 8;
    ir_add(IR_ADD, sj2, sj, 2, 1, 0);
    i64 ssj = ir_add(IR_STORE, 0, 30, sj2, 0, uj_jo);
    ir_w[ssj] = 8;
    i64 jst = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jst] = h2;
    // the wiring
    ir_t1[brh2] = pre1;
    ir_t1[ir_be[pre1_last] - 1] = pre2;
    ir_t1[ir_be[pre2_last] - 1] = h3;
    {
        i64 th = ir_be[h3] - 1;
        // the branch of H3: the body of I goes to the first copy, the exit to POST
        if ir_t1[th] == cl_body[qi] { ir_t1[th] = in1; ir_t2[th] = po1; }
        else { ir_t2[th] = in1; ir_t1[th] = po1; }
    }
    ir_t1[ir_be[in1_last] - 1] = in2;
    ir_t1[ir_be[in2_last] - 1] = h3;
    ir_t1[ir_be[po1_last] - 1] = po2;
    ir_t1[ir_be[po2_last] - 1] = st;
    // the jumps into the header from outside the loop go to G
    op_mark_loop(lo);
    i64 bb2 = 0;
    while bb2 < nb0 {
        if op_mark[bb2] != op_stamp && op_po[bb2] >= 0 {
            i64 tb2 = ir_be[bb2] - 1;
            i64 top = ir_op[tb2];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[tb2] == ho { ir_t1[tb2] = gfirst; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[tb2] == ho { ir_t2[tb2] = gfirst; }
        }
        bb2 += 1;
    }
    uj_count += 1;
    if uj_ndone < 30 { uj_done[uj_ndone] = ho; uj_ndone += 1; }
    if ((ir_opt & 9007199254740992) != 0) { write_err("uj fired in "); write_err(@ir_fname); write_err("\n"); }
    return true;
}

void uj_run() {
    uj_ndone = 0;
    i64 rounds = 0;
    while rounds < 4 {
        rounds += 1;
        op_counted_loops();
        if cl_n < 2 { return; }
        op_liveness();
        bool fired = false;
        i64 q = 0;
        while q < cl_n && !fired {
            bool done = false;
            i64 d = 0;
            while d < uj_ndone { if uj_done[d] == cl_head[q] { done = true; } d += 1; }
            if !done && cl_inner[q] == 0 && cl_step[q] == 1 && (cl_cc[q] == IR_LT || cl_cc[q] == IR_ULT) {
                i64 lo = 0;
                while lo < op_nloops && op_lh[lo] != cl_head[q] { lo += 1; }
                if lo < op_nloops {
                    op_mark_loop(lo);
                    i64 st = op_stamp;
                    i64 ninner = 0;
                    i64 qi = 0 - 1;
                    i64 c = 0;
                    while c < op_nloops {
                        if op_lh[c] != cl_head[q] && op_mark[op_lh[c]] == st { ninner += 1; }
                        c += 1;
                    }
                    i64 r = 0;
                    while r < cl_n {
                        if r != q && op_mark[cl_head[r]] == st && cl_inner[r] == 1 && cl_step[r] == 1 && (cl_cc[r] == IR_LT || cl_cc[r] == IR_ULT) { qi = r; }
                        r += 1;
                    }
                    if ninner == 1 && qi >= 0 {
                        if uj_make(q, qi) { fired = true; }
                        else if uj_ndone < 30 { uj_done[uj_ndone] = cl_head[q]; uj_ndone += 1; }
                    }
                }
            }
            q += 1;
        }
        if !fired { return; }
    }
}

void op_vectorize() {
    if opt_debug == 1 || opt_novec == 1 { return; }
    op_counted_loops();
    if (ir_opt & 4503599627370496) == 0 && cl_n >= 2 { uj_run(); op_counted_loops(); }
    if (ir_opt & 4194304) != 0 { write_err("op_vectorize in "); write_err(@ir_fname); write_err(" counted loops "); write_err_int(cl_n); write_err("\n"); }
    if cl_n == 0 { return; }
    if (ir_opt & 8388608) != 0 { ir_print(); syscall(64, 2, @ir_pbuf, ir_plen); }
    i64 nl = cl_n;
    i64 heads[CL_MAX];
    i64 q = 0;
    while q < nl { heads[q] = cl_head[q]; q += 1; }
    q = 0;
    while q < nl {
        // the loop descriptors can move when blocks are added: look the loop up again by its header
        bool fine = cl_inner[q] == 1 && cl_calls[q] == 0 && cl_step[q] == 1 && (cl_cc[q] == IR_LT || cl_cc[q] == IR_ULT);
        if (ir_opt & 4194304) != 0 { write_err("loop in "); write_err(@ir_fname); write_err(": inner "); write_err_int(cl_inner[q]); write_err(" calls "); write_err_int(cl_calls[q]); write_err(" step "); write_err_int(cl_step[q]); write_err(" cc "); write_err_int(cl_cc[q]); write_err("\n"); }
        if fine {
            i64 l = 0;
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
i64 ss_kf[SS_MAXK];              // the scale
i64 ss_kbase[SS_MAXK];           // 29 the global area, 30 the frame, 1000 + k: the plain slot at the frame offset k (a pointer)
i64 ss_koff[SS_MAXK];
i64 ss_kcell[SS_MAXK];
i64 ss_nk;
// affine keys (kind 6): the address is  stride * i + sum(coef * [slot]) + off,  the stride a number (ss_kac) or a number times a plain slot
i64 ss_kk[SS_MAXK];              // 0 the old keys (f, base, off), 6 an affine key
i64 ss_khas[SS_MAXK];            // 1: the stride is ss_kac * [slot ss_kas]
i64 ss_kas[SS_MAXK];
i64 ss_kac[SS_MAXK];
i64 ss_kn[SS_MAXK];
i64 ss_kt[72];
i64 ss_kc[72];
i64 ss_kcell2[SS_MAXK];          // the step of the pointer when the stride is a slot
// the affine values of the vregs of the block being scanned: entries 0, 1 and 2 are temporaries
#define SS_MAXA 512
i64 ssa_has[SS_MAXA];
i64 ssa_as[SS_MAXA];
i64 ssa_ac[SS_MAXA];
i64 ssa_n[SS_MAXA];
i64 ssa_t[1536];
i64 ssa_c[1536];
i64 ssa_off[SS_MAXA];
i64 ssa_np;
i64 ss_wo[256];                  // the frame cells (below the slots) that the loop writes
i64 ss_nwo;
i64 ss_inner;                    // the loop is an innermost loop (the affine forms and the cells are only used there)
i64 ss_noinv;                    // 1: the cells cannot be told to be invariant
i64 ss_pj[SS_MAXP];              // the instructions to become `load pointer`, and their keys
i64 ss_pk[SS_MAXP];
i64 ss_np;
i64 ss_kind[IR_MAXV];            // 1 the counter, 2 f * i, 3 a number, 4 an invariant pointer (base + c), 5 base + f * i + c
i64 ss_f[IR_MAXV];
i64 ss_base[IR_MAXV];
i64 ss_off[IR_MAXV];
i64 ss_stampv[IR_MAXV];
i64 ss_prodv[IR_MAXV];           // kind 5: the instruction that made it (-1: not a producer that is changed)
i64 ss_stamp;
i64 ss_ce_cell[8];               // cells (frame offsets) that the entry block of the loop fills once with an address `base + f * i + c`
i64 ss_ce_f[8];
i64 ss_ce_base[8];
i64 ss_ce_off[8];
i64 ss_nce;
i64 ss_chb[16];                  // the blocks that every turn of the loop runs through first, in order (the header jumps into the first; each ends in a
i64 ss_chn;                      // test that leaves the loop or a jump): a cell filled in one of them is filled before every later use in the turn
i64 ss_lst[16384];               // slots written in the loop
i64 ss_total;                    // all functions
i64 ss_nb0;                      // the blocks the function had before the loops were changed

i64 ss_get(i64 v) {
    if v <= 0 || v >= IR_MAXV || ss_stampv[v] != ss_stamp { return 0; }
    return ss_kind[v];
}

void ss_set(i64 v, i64 kind, i64 f, i64 base, i64 off) {
    if v <= 0 || v >= IR_MAXV { return; }
    ss_stampv[v] = ss_stamp;
    ss_kind[v] = kind;
    ss_f[v] = f;
    ss_base[v] = base;
    ss_off[v] = off;
    ss_prodv[v] = 0 - 1;
}

i64 ss_key(i64 f, i64 base, i64 off) {
    i64 u = 0;
    while u < ss_nk {
        if ss_kk[u] == 0 && ss_kf[u] == f && ss_kbase[u] == base && ss_koff[u] == off { return u; }
        u += 1;
    }
    if ss_nk >= SS_MAXK { return 0 - 1; }
    ss_kk[ss_nk] = 0;
    ss_kf[ss_nk] = f;
    ss_kbase[ss_nk] = base;
    ss_koff[ss_nk] = off;
    ss_nk += 1;
    return ss_nk - 1;
}

void ss_acopy(i64 a, i64 r) {
    ssa_has[r] = ssa_has[a];
    ssa_as[r] = ssa_as[a];
    ssa_ac[r] = ssa_ac[a];
    ssa_n[r] = ssa_n[a];
    ssa_off[r] = ssa_off[a];
    i64 t = 0;
    while t < 3 {
        ssa_t[r * 3 + t] = ssa_t[a * 3 + t];
        ssa_c[r * 3 + t] = ssa_c[a * 3 + t];
        t += 1;
    }
}

// the value of a vreg as an affine form in entry e
bool ss_toaff(i64 v, i64 e) {
    i64 k = ss_get(v);
    ssa_has[e] = 0;
    ssa_as[e] = 0;
    ssa_ac[e] = 0;
    ssa_n[e] = 0;
    ssa_off[e] = 0;
    if k == 1 { ssa_ac[e] = 1; return true; }
    if k == 2 { ssa_ac[e] = ss_f[v]; return true; }
    if k == 3 { ssa_off[e] = ss_off[v]; return true; }
    if k == 4 && ss_base[v] >= 1000 {
        ssa_n[e] = 1;
        ssa_t[e * 3] = ss_base[v] - 1000;
        ssa_c[e * 3] = 1;
        ssa_off[e] = ss_off[v];
        return true;
    }
    if k == 9 {
        ssa_n[e] = 1;
        ssa_t[e * 3] = ss_off[v];
        ssa_c[e * 3] = 1;
        return true;
    }
    if k == 6 { ss_acopy(ss_f[v], e); return true; }
    return false;
}

bool ss_aadd(i64 a, i64 b) {
    i64 r = 2;
    if ssa_has[a] != 0 && ssa_has[b] != 0 {
        if ssa_as[a] != ssa_as[b] { return false; }
        ssa_has[r] = 1;
        ssa_as[r] = ssa_as[a];
        ssa_ac[r] = ssa_ac[a] + ssa_ac[b];
    } else if ssa_has[a] != 0 {
        if ssa_ac[b] != 0 { return false; }
        ssa_has[r] = 1;
        ssa_as[r] = ssa_as[a];
        ssa_ac[r] = ssa_ac[a];
    } else if ssa_has[b] != 0 {
        if ssa_ac[a] != 0 { return false; }
        ssa_has[r] = 1;
        ssa_as[r] = ssa_as[b];
        ssa_ac[r] = ssa_ac[b];
    } else {
        ssa_has[r] = 0;
        ssa_as[r] = 0;
        ssa_ac[r] = ssa_ac[a] + ssa_ac[b];
    }
    ssa_off[r] = ssa_off[a] + ssa_off[b];
    i64 n = 0;
    while n < ssa_n[a] {
        ssa_t[r * 3 + n] = ssa_t[a * 3 + n];
        ssa_c[r * 3 + n] = ssa_c[a * 3 + n];
        n += 1;
    }
    i64 u = 0;
    while u < ssa_n[b] {
        i64 f = 0;
        i64 w = 0;
        while w < n {
            if ssa_t[r * 3 + w] == ssa_t[b * 3 + u] { ssa_c[r * 3 + w] += ssa_c[b * 3 + u]; f = 1; }
            w += 1;
        }
        if f == 0 {
            if n >= 3 { return false; }
            ssa_t[r * 3 + n] = ssa_t[b * 3 + u];
            ssa_c[r * 3 + n] = ssa_c[b * 3 + u];
            n += 1;
        }
        u += 1;
    }
    ssa_n[r] = n;
    return true;
}

bool ss_abig(i64 x) {
    return x > 1073741824 || x < 0 - 1073741824;
}

// entry e times a number, into entry 2
bool ss_ascale(i64 e, i64 m) {
    if m > 4096 || m < 0 - 4096 { return false; }
    i64 r = 2;
    ss_acopy(e, r);
    ssa_ac[r] = ssa_ac[e] * m;
    ssa_off[r] = ssa_off[e] * m;
    bool bad = ss_abig(ssa_ac[r]) || ss_abig(ssa_off[r]);
    i64 t = 0;
    while t < ssa_n[e] {
        ssa_c[r * 3 + t] = ssa_c[e * 3 + t] * m;
        if ss_abig(ssa_c[r * 3 + t]) { bad = true; }
        t += 1;
    }
    return !bad;
}

// (a number times the counter) times a plain slot, into entry 2
bool ss_amulvar(i64 a, i64 b) {
    if ssa_has[a] != 0 || ssa_ac[a] == 0 || ssa_n[a] != 0 || ssa_off[a] != 0 { return false; }
    if ssa_has[b] != 0 || ssa_ac[b] != 0 || ssa_n[b] != 1 || ssa_off[b] != 0 { return false; }
    i64 c = ssa_ac[a] * ssa_c[b * 3];
    if ss_abig(c) { return false; }
    ssa_has[2] = 1;
    ssa_as[2] = ssa_t[b * 3];
    ssa_ac[2] = c;
    ssa_n[2] = 0;
    ssa_off[2] = 0;
    return true;
}

// the frame cell at a negative offset is the same at every turn
bool ss_cellinv(i64 off) {
    if ss_noinv != 0 { return false; }
    i64 i = 0;
    while i < ss_nwo {
        if ss_wo[i] < off + 8 && off < ss_wo[i] + 16 { return false; }
        i += 1;
    }
    return true;
}

// how many stores of the loop touch the cell off (the same test as ss_cellinv)
i64 ss_cellwrites(i64 off) {
    i64 n = 0;
    i64 i = 0;
    while i < ss_nwo {
        if ss_wo[i] < off + 8 && off < ss_wo[i] + 16 { n += 1; }
        i += 1;
    }
    return n;
}

bool ss_inchain(i64 b) {
    i64 i = 0;
    while i < ss_chn {
        if ss_chb[i] == b { return true; }
        i += 1;
    }
    return false;
}

i64 ss_cefind(i64 off) {
    i64 i = 0;
    while i < ss_nce {
        if ss_ce_cell[i] == off { return i; }
        i += 1;
    }
    return 0 - 1;
}

i64 ss_key6(i64 e) {
    i64 u = 0;
    while u < ss_nk {
        if ss_kk[u] == 6 && ss_khas[u] == ssa_has[e] && ss_kas[u] == ssa_as[e] && ss_kac[u] == ssa_ac[e] && ss_kn[u] == ssa_n[e] && ss_koff[u] == ssa_off[e] {
            bool same = true;
            i64 t = 0;
            while t < ssa_n[e] {
                if ss_kt[u * 3 + t] != ssa_t[e * 3 + t] || ss_kc[u * 3 + t] != ssa_c[e * 3 + t] { same = false; }
                t += 1;
            }
            if same { return u; }
        }
        u += 1;
    }
    if ss_nk >= SS_MAXK { return 0 - 1; }
    u = ss_nk;
    ss_kk[u] = 6;
    ss_khas[u] = ssa_has[e];
    ss_kas[u] = ssa_as[e];
    ss_kac[u] = ssa_ac[e];
    ss_kf[u] = ssa_ac[e];
    ss_kn[u] = ssa_n[e];
    ss_koff[u] = ssa_off[e];
    ss_kbase[u] = 0;
    i64 t2 = 0;
    while t2 < ssa_n[e] {
        ss_kt[u * 3 + t2] = ssa_t[e * 3 + t2];
        ss_kc[u * 3 + t2] = ssa_c[e * 3 + t2];
        t2 += 1;
    }
    ss_nk += 1;
    return u;
}

// a vreg that holds c * reg
i64 ss_mulc(i64 reg, i64 c) {
    if c == 1 { return reg; }
    i64 m = ir_vreg(0);
    if c > 0 && (c & (c - 1)) == 0 {
        i64 sh = 0;
        while (1 << sh) != c { sh += 1; }
        ir_add(IR_SHL, m, reg, sh, 1, 0);
    } else {
        i64 cf = ir_vreg(0);
        ir_add(IR_CONST, cf, 0, 0, 0, c);
        ir_add(IR_MUL, m, reg, cf, 0, 0);
    }
    return m;
}

i64 ss_term(i64 slot, i64 c) {
    i64 t = ir_vreg(0);
    i64 l = ir_add(IR_LOAD, t, 30, 0, 0, 0);
    ir_w[l] = 8;
    ir_k[l] = slot;
    return ss_mulc(t, c);
}

// scan one block of the loop; the producers that an access uses are collected
void ss_block(i64 b, i64 islot) {
    ss_stamp += 1;
    ssa_np = 3;
    i64 j = ir_bs[b];
    while j < ir_be[b] - 1 {
        i64 op = ir_op[j];
        i64 d = ir_d[j];
        if op == IR_NOP { j += 1; continue; }
        if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
            ss_stamp += 1;
            j += 1;
            continue;
        }
        // the entry block of the loop keeps an address in a frame cell (value numbering shares it with the other blocks): the loads of the
        // cell in the blocks after it are the same address (-irdbg 1152921504606846976 switches this off)
        if op == IR_STORE && ir_a[j] == 30 && ir_k[j] < 0 && ir_w[j] == 8 && ir_bi[j] == 0 && ss_inchain(b) && ss_inner == 1 && ss_noinv == 0 && ss_nce < 8 && (ir_opt & 1152921504606846976) == 0 {
            i64 sv = ir_b[j];
            if ss_get(sv) == 5 && ss_prodv[sv] >= 0 && ss_cellwrites(ir_k[j]) == 1 && ss_cefind(ir_k[j]) < 0 {
                ss_ce_cell[ss_nce] = ir_k[j];
                ss_ce_f[ss_nce] = ss_f[sv];
                ss_ce_base[ss_nce] = ss_base[sv];
                ss_ce_off[ss_nce] = ss_off[sv];
                ss_nce += 1;
            }
        }
        // a use of a changed address: the instruction that made it needs the pointer
        if (op == IR_LOAD || op == IR_STORE) && ir_a[j] > 0 && (ss_get(ir_a[j]) == 5 || ss_get(ir_a[j]) == 6) && ss_prodv[ir_a[j]] >= 0 && ss_np < SS_MAXP {
            i64 pr = ss_prodv[ir_a[j]];
            i64 k = 0 - 1;
            if ss_get(ir_a[j]) == 6 { k = ss_key6(ss_f[ir_a[j]]); }
            else { k = ss_key(ss_f[ir_a[j]], ss_base[ir_a[j]], ss_off[ir_a[j]]); }
            bool known = false;
            i64 u = 0;
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
        i64 nk = 0;
        i64 nf = 0;
        i64 nb = 0;
        i64 no = 0;
        i64 a = ir_a[j];
        i64 ka = ss_get(a);
        if op == IR_LOAD && ir_w[j] == 8 && a == 30 && ir_k[j] < 0 {
            i64 ce = ss_cefind(ir_k[j]);
            if ce >= 0 { nk = 5; nf = ss_ce_f[ce]; nb = ss_ce_base[ce]; no = ss_ce_off[ce]; }
            else if ss_inner == 1 && ss_cellinv(ir_k[j]) { nk = 9; no = ir_k[j]; }
        } else if op == IR_LOAD && ir_w[j] == 8 && a == 30 {
            i64 sl = vn_slot(j);
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
            i64 mv = 0;
            bool have = false;
            if ir_bi[j] == 1 { mv = ir_b[j]; have = true; }
            else if ss_get(ir_b[j]) == 3 { mv = ss_off[ir_b[j]]; have = true; }
            if have && mv > 0 && mv <= 4096 { nk = 2; nf = mv; }
        } else if op == IR_ADD && ir_bi[j] == 1 && (a == 29 || a == 30) {
            nk = 4; nb = a; no = ir_b[j];
        } else if op == IR_ADD {
            i64 kb = 0;
            i64 bv = 0;
            i64 rb = 0;
            if ir_bi[j] == 1 { kb = 3; bv = ir_b[j]; } else { rb = ir_b[j]; kb = ss_get(rb); if kb == 3 { bv = ss_off[rb]; } }
            if ka == 4 && kb == 3 { nk = 4; nb = ss_base[a]; no = ss_off[a] + bv; }
            else if ka == 5 && kb == 3 { nk = 5; nf = ss_f[a]; nb = ss_base[a]; no = ss_off[a] + bv; }
            else if ka == 2 && kb == 4 { nk = 5; nf = ss_f[a]; nb = ss_base[rb]; no = ss_off[rb]; }
            else if ka == 4 && kb == 2 { nk = 5; nf = ss_f[rb]; nb = ss_base[a]; no = ss_off[a]; }
            else if ka == 4 && kb == 0 && a == 29 { nk = 0; }
        }
        // the global area and the frame are pointers
        if op == IR_ADD && ir_bi[j] == 0 {
            i64 xa = ir_a[j];
            i64 xb = ir_b[j];
            i64 kxa = ss_get(xa);
            i64 kxb = ss_get(xb);
            if xa == 29 && kxb == 2 { nk = 5; nf = ss_f[xb]; nb = 29; no = 0; }
            else if xb == 29 && kxa == 2 { nk = 5; nf = ss_f[xa]; nb = 29; no = 0; }
            else if xa == 30 && kxb == 2 { nk = 5; nf = ss_f[xb]; nb = 30; no = 0; }
            else if xb == 30 && kxa == 2 { nk = 5; nf = ss_f[xa]; nb = 30; no = 0; }
        }
        if nk == 0 && ss_inner == 1 && (ir_opt & 2305843009213693952) == 0 {
            bool ok = false;
            if op == IR_ADD || op == IR_MUL {
                if ka != 0 && ss_toaff(a, 0) {
                    if ir_bi[j] == 1 {
                        ssa_has[1] = 0; ssa_as[1] = 0; ssa_ac[1] = 0; ssa_n[1] = 0; ssa_off[1] = ir_b[j];
                        ok = true;
                    } else if ss_toaff(ir_b[j], 1) { ok = true; }
                }
                if ok {
                    if op == IR_ADD { ok = ss_aadd(0, 1); }
                    else if ssa_n[1] == 0 && ssa_has[1] == 0 && ssa_ac[1] == 0 { ok = ss_ascale(0, ssa_off[1]); }
                    else if ssa_n[0] == 0 && ssa_has[0] == 0 && ssa_ac[0] == 0 { ok = ss_ascale(1, ssa_off[0]); }
                    else { ok = ss_amulvar(0, 1) || ss_amulvar(1, 0); }
                }
            } else if op == IR_SHL && ir_bi[j] == 1 && ka != 0 && ir_b[j] >= 0 && ir_b[j] <= 12 && ss_toaff(a, 0) {
                ok = ss_ascale(0, 1 << ir_b[j]);
            }
            if ok && ssa_np < SS_MAXA {
                ss_acopy(2, ssa_np);
                nk = 6;
                nf = ssa_np;
                ssa_np += 1;
            }
        }
        ss_set(d, nk, nf, nb, no);
        if nk == 5 { ss_prodv[d] = j; }
        if nk == 6 && (ssa_has[nf] != 0 || ssa_ac[nf] != 0) { ss_prodv[d] = j; }
        j += 1;
    }
}

bool ss_loop(i64 q) {
    i64 h = cl_head[q];
    i64 l = cl_lidx[q];
    i64 islot = cl_slot[q];
    i64 stb = cl_stb[q];
    i64 sti = cl_sti[q];
    if cl_step[q] < 1 || cl_step[q] > 64 { return false; }
    // the step of the counter is the last instruction of its block (nops and the jump after it), and the block jumps to the header
    i64 t = ir_be[stb] - 1;
    if ir_op[t] != IR_JMP || ir_t1[t] != h { return false; }
    i64 m = sti + 1;
    while m < t {
        if ir_op[m] != IR_NOP { return false; }
        m += 1;
    }
    op_mark_loop(l);
    i64 stamp = op_stamp;
    // the slots that the loop writes
    i64 zi = 0;
    while zi < 16384 { ss_lst[zi] = 0; zi += 1; }
    ss_nwo = 0;
    ss_noinv = 0;
    ss_inner = cl_inner[q];
    i64 b = 0;
    while b < ss_nb0 {
        if op_po[b] >= 0 && op_mark[b] == stamp {
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                i64 jo = ir_op[j];
                if jo == IR_ATOMIC || jo == IR_RAW || jo == IR_ADDR_SLOT { ss_noinv = 1; }
                if jo == IR_STORE && ir_a[j] == 30 && ir_k[j] < 0 {
                    if ss_nwo < 256 { ss_wo[ss_nwo] = ir_k[j]; ss_nwo += 1; } else { ss_noinv = 1; }
                }
                if ir_op[j] == IR_STORE && ir_a[j] == 30 {
                    i64 s2 = vn_slot(j);
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
    ss_nce = 0;
    ss_chn = 0;
    {
        i64 cb = h;
        bool go = true;
        while go && ss_chn < 16 {
            i64 ht = ir_be[cb] - 1;
            i64 nx = 0 - 1;
            if ir_op[ht] == IR_JMP { nx = ir_t1[ht]; }
            else if ir_op[ht] == IR_BR || ir_op[ht] == IR_FBR {
                i64 e1 = ir_t1[ht];
                i64 e2 = ir_t2[ht];
                bool in1 = e1 >= 0 && e1 < ss_nb0 && op_po[e1] >= 0 && op_mark[e1] == stamp && e1 != h;
                bool in2 = e2 >= 0 && e2 < ss_nb0 && op_po[e2] >= 0 && op_mark[e2] == stamp && e2 != h;
                if in1 && !in2 { nx = e1; }
                else if in2 && !in1 { nx = e2; }
            }
            if nx < 0 || nx >= ss_nb0 || op_po[nx] < 0 || op_mark[nx] != stamp || nx == h || ss_inchain(nx) { go = false; }
            else { ss_chb[ss_chn] = nx; ss_chn += 1; cb = nx; }
        }
    }
    b = 0;
    i64 nb0 = ss_nb0;
    {
        i64 ci = 0;
        while ci < ss_chn { ss_block(ss_chb[ci], islot); ci += 1; }
    }
    while b < nb0 {
        if op_po[b] >= 0 && op_mark[b] == stamp && b != h && !ss_inchain(b) { ss_block(b, islot); }
        b += 1;
    }
    // memory cells that move on cost a load and a store for each turn: many pointers with a stride from a slot do not pay (the loop of a
    // matmul that makes two columns at a time is slower), so at most one such key and two affine keys are kept
    i64 nv6 = 0;
    i64 na6 = 0;
    i64 ku = 0;
    while ku < ss_nk {
        if ss_kk[ku] == 6 {
            na6 += 1;
            if ss_khas[ku] != 0 { nv6 += 1; }
        }
        ku += 1;
    }
    if nv6 > 1 || na6 > 2 {
        i64 wp = 0;
        i64 rp = 0;
        while rp < ss_np {
            if ss_kk[ss_pk[rp]] != 6 {
                ss_pj[wp] = ss_pj[rp];
                ss_pk[wp] = ss_pk[rp];
                wp += 1;
            }
            rp += 1;
        }
        ss_np = wp;
        ku = 0;
        while ku < ss_nk {
            if ss_kk[ku] == 6 { ss_kk[ku] = 99; }
            ku += 1;
        }
    }
    if ss_np == 0 { return false; }
    // cells
    i64 cellbase = 0 - (op_maxq() + 8);
    i64 u = 0;
    while u < ss_nk {
        ss_kcell[u] = cellbase - 8 * u;
        ss_kcell2[u] = cellbase - 8 * (ss_nk + u);
        u += 1;
    }
    // the instructions become loads of the pointers
    u = 0;
    while u < ss_np {
        i64 pj = ss_pj[u];
        ir_op[pj] = IR_LOAD;
        ir_a[pj] = 30;
        ir_b[pj] = 0;
        ir_bi[pj] = 0;
        ir_k[pj] = ss_kcell[ss_pk[u]];
        ir_w[pj] = 8;
        u += 1;
    }
    // the block in front of the loop: the pointers from the counter
    i64 pre = ir_new_block(0 - 1);
    ir_set_block(pre);
    u = 0;
    while u < ss_nk {
        i64 ti = ir_vreg(0);
        i64 li = ir_add(IR_LOAD, ti, 30, 0, 0, 0);
        ir_w[li] = 8;
        ir_k[li] = vz_slot_off(islot);
        if ss_kk[u] == 99 { u += 1; continue; }
        if ss_kk[u] == 6 {
            // every value is used by the next instruction or the one after it (the register pass does not keep a value alive over more),
            // the sum is built in the cell of the pointer
            i64 cellp = ss_kcell[u];
            if ss_khas[u] != 0 {
                i64 sv = ss_term(ss_kas[u], ss_kac[u]);
                i64 dl = ss_mulc(sv, cl_step[q]);
                i64 sd = ir_add(IR_STORE, 0, 30, dl, 0, ss_kcell2[u]);
                ir_w[sd] = 8;
                i64 sv2 = ss_term(ss_kas[u], ss_kac[u]);
                i64 ti6 = ir_vreg(0);
                i64 li6 = ir_add(IR_LOAD, ti6, 30, 0, 0, 0);
                ir_w[li6] = 8;
                ir_k[li6] = vz_slot_off(islot);
                i64 cv = ir_vreg(0);
                ir_add(IR_MUL, cv, ti6, sv2, 0, 0);
                i64 s6 = ir_add(IR_STORE, 0, 30, cv, 0, cellp);
                ir_w[s6] = 8;
            } else {
                i64 ti7 = ir_vreg(0);
                i64 li7 = ir_add(IR_LOAD, ti7, 30, 0, 0, 0);
                ir_w[li7] = 8;
                ir_k[li7] = vz_slot_off(islot);
                i64 cv7 = ss_mulc(ti7, ss_kac[u]);
                i64 s7 = ir_add(IR_STORE, 0, 30, cv7, 0, cellp);
                ir_w[s7] = 8;
            }
            i64 w6 = 0;
            while w6 < ss_kn[u] {
                i64 tv = ss_term(ss_kt[u * 3 + w6], ss_kc[u * 3 + w6]);
                i64 ov = ir_vreg(0);
                i64 lo = ir_add(IR_LOAD, ov, 30, 0, 0, 0);
                ir_w[lo] = 8;
                ir_k[lo] = cellp;
                i64 nv = ir_vreg(0);
                ir_add(IR_ADD, nv, ov, tv, 0, 0);
                i64 s8 = ir_add(IR_STORE, 0, 30, nv, 0, cellp);
                ir_w[s8] = 8;
                w6 += 1;
            }
            if ss_koff[u] != 0 {
                i64 ov2 = ir_vreg(0);
                i64 lo2 = ir_add(IR_LOAD, ov2, 30, 0, 0, 0);
                ir_w[lo2] = 8;
                ir_k[lo2] = cellp;
                i64 nv2 = ir_vreg(0);
                ir_add(IR_ADD, nv2, ov2, ss_koff[u], 1, 0);
                i64 s9 = ir_add(IR_STORE, 0, 30, nv2, 0, cellp);
                ir_w[s9] = 8;
            }
            u += 1;
            continue;
        }
        i64 cur = ti;
        if ss_kf[u] != 1 {
            i64 tm = ir_vreg(0);
            if ss_kf[u] == 2 || ss_kf[u] == 4 || ss_kf[u] == 8 || ss_kf[u] == 16 || ss_kf[u] == 32 || ss_kf[u] == 64 || ss_kf[u] == 128 || ss_kf[u] == 256 || ss_kf[u] == 512 || ss_kf[u] == 1024 || ss_kf[u] == 2048 || ss_kf[u] == 4096 {
                i64 sh = 0;
                while (1 << sh) != ss_kf[u] { sh += 1; }
                ir_add(IR_SHL, tm, ti, sh, 1, 0);
            } else {
                i64 cf = ir_vreg(0);
                ir_add(IR_CONST, cf, 0, 0, 0, ss_kf[u]);
                ir_add(IR_MUL, tm, ti, cf, 0, 0);
            }
            cur = tm;
        }
        i64 tb = ir_vreg(0);
        if ss_kbase[u] >= 1000 {
            // the pointer in the plain slot at the frame offset kbase - 1000
            i64 lb = ir_add(IR_LOAD, tb, 30, 0, 0, 0);
            ir_w[lb] = 8;
            ir_k[lb] = ss_kbase[u] - 1000;
            i64 ta = ir_vreg(0);
            ir_add(IR_ADD, ta, tb, cur, 0, 0);
            cur = ta;
        } else {
            i64 ta2 = ir_vreg(0);
            ir_add(IR_ADD, ta2, ss_kbase[u], cur, 0, 0);
            cur = ta2;
        }
        i64 tc = ir_vreg(0);
        ir_add(IR_ADD, tc, cur, ss_koff[u], 1, 0);
        i64 sp = ir_add(IR_STORE, 0, 30, tc, 0, ss_kcell[u]);
        ir_w[sp] = 8;
        u += 1;
    }
    i64 jp = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jp] = h;
    // the block after the step of the counter: the pointers move on
    i64 inc = ir_new_block(0 - 1);
    ir_set_block(inc);
    u = 0;
    while u < ss_nk {
        if ss_kk[u] == 99 { u += 1; continue; }
        i64 pc = ir_vreg(0);
        i64 lc = ir_add(IR_LOAD, pc, 30, 0, 0, 0);
        ir_w[lc] = 8;
        ir_k[lc] = ss_kcell[u];
        i64 pn = ir_vreg(0);
        if ss_kk[u] == 6 && ss_khas[u] != 0 {
            i64 dv = ir_vreg(0);
            i64 ldv = ir_add(IR_LOAD, dv, 30, 0, 0, 0);
            ir_w[ldv] = 8;
            ir_k[ldv] = ss_kcell2[u];
            ir_add(IR_ADD, pn, pc, dv, 0, 0);
        } else {
            ir_add(IR_ADD, pn, pc, ss_kf[u] * cl_step[q], 1, 0);
        }
        i64 sc = ir_add(IR_STORE, 0, 30, pn, 0, ss_kcell[u]);
        ir_w[sc] = 8;
        u += 1;
    }
    i64 ji = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[ji] = h;
    ir_t1[t] = inc;
    // every jump into the header from outside the loop goes to the new block in front of it
    b = 0;
    while b < nb0 {
        if op_po[b] >= 0 && op_mark[b] != stamp {
            i64 tb2 = ir_be[b] - 1;
            i64 top = ir_op[tb2];
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
    i64 n = cl_n;
    i64 q = 0;
    while q < n {
        if cl_calls[q] >= 0 { ss_loop(q); }
        q += 1;
    }
}

// ---------------------------------------------------------------------------------------------- the data pointer of heap arrays
// In an innermost counted loop without calls, whose blocks are one straight chain from the body back to the header, every access
// `a[i]` loads the handle from its frame cell, checks it for null and loads the data pointer `[handle + 16]`. When nothing in the loop
// writes the cell of the handle (or the data field of any header), the checks and the loads move in front of the loop: a new block
// runs the test of the loop once, and only when the loop runs at least once the handles are checked (in the order of the first turn,
// to the same trap blocks) and the data pointers are kept in new frame cells. A loop that runs zero times never checks anything.
// `-irdbg 1125899906842624` switches it off, 144115188075855872 stops the hoist of handles without a check, 72057594037927936 limits it to a
// loop that is one straight chain of blocks (the body may have an `if`: a block that runs at every turn decides what is hoisted).
#define AH_MAXH 12
#define AH_MAXC 64
i64 ah_cell[AH_MAXH];            // the frame cell of the handle
i64 ah_trap[AH_MAXH];            // the trap block of its check
i64 ah_ncell[AH_MAXH];           // the new cell for the data pointer
i64 ah_n;
i64 ah_cv[IR_MAXV];              // vreg -> the handle cell whose value it holds (while scanning)
i64 ah_cs[IR_MAXV];
i64 ah_stamp;
i64 ah_br[AH_MAXC];              // the checks to turn into jumps
i64 ah_nbr;
i64 ah_ld[AH_MAXC];              // the data loads to turn into loads of the new cell, and the hoist index
i64 ah_li[AH_MAXC];
i64 ah_nld;
i64 ah_chain[UJ_MAXB];
i64 ah_total;

i64 ah_get(i64 v) {
    if v <= 0 || v >= IR_MAXV || ah_cs[v] != ah_stamp { return 0 - 1000000; }
    return ah_cv[v];
}

void ah_set(i64 v, i64 c) {
    if v <= 0 || v >= IR_MAXV { return; }
    ah_cs[v] = ah_stamp;
    ah_cv[v] = c;
}

i64 ah_npred(i64 t) {
    i64 n = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                if op_succ(b, k) == t { n += 1; }
                k += 1;
            }
        }
        b += 1;
    }
    return n;
}

i64 ah_tmpc[UJ_MAXB];
i64 ah_lastpred;
i64 ah_nall;                     // the blocks of the loop (without the header), in reverse post order
i64 ah_prevb;

i64 ah_npred1(i64 t) {
    i64 n = 0;
    ah_lastpred = 0 - 1;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            i64 k = 0;
            while k < 2 {
                if op_succ(b, k) == t { n += 1; ah_lastpred = b; }
                k += 1;
            }
        }
        b += 1;
    }
    return n;
}

// does an instruction of the loop write the 8 bytes at this frame offset?
bool ah_written(i64 nch, i64 off) {
    i64 c = 0;
    while c < nch {
        i64 b = ah_chain[c];
        i64 j = ir_bs[b];
        while j < ir_be[b] {
            i64 op = ir_op[j];
            if op == IR_STORE {
                if ir_a[j] == 30 {
                    if ir_k[j] < off + 8 && off < ir_k[j] + 16 { return true; }
                } else if ir_k[j] == 16 { return true; }
            }
            if op == IR_ATOMIC || op == IR_RAW || op == IR_ADDR_SLOT || op == IR_LCALL || op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL { return true; }
            j += 1;
        }
        c += 1;
    }
    return false;
}

bool ah_istrap(i64 b) {
    i64 j = ir_bs[b];
    while j < ir_be[b] {
        if ir_op[j] == IR_TRAP { return true; }
        j += 1;
    }
    return false;
}

// is the handle in this frame cell checked for null somewhere in the function (a branch to a trap block)? Then it is an array handle,
// and its data field at 16 can be read in front of a loop where the check in the loop was dropped; a field of a struct at 16 would not do
i64 ah_ck[64];
i64 ah_nck;

bool ah_incheck(i64 cell) {
    i64 i = 0;
    while i < ah_nck {
        if ah_ck[i] == cell { return true; }
        i += 1;
    }
    return false;
}

void ah_collect_checked() {
    ah_nck = 0;
    i64 b = 0;
    while b < ir_nb {
        if op_po[b] >= 0 {
            ah_stamp += 1;
            i64 j = ir_bs[b];
            while j < ir_be[b] {
                i64 op = ir_op[j];
                i64 d = ir_d[j];
                if op == IR_BR && ir_k[j] == IR_NE && ir_bi[j] == 1 && ir_b[j] == 0 && ah_get(ir_a[j]) >= 0 && ir_t2[j] >= 0 && ah_nck < 64 && ah_istrap(ir_t2[j]) {
                    if !ah_incheck(ah_get(ir_a[j])) { ah_ck[ah_nck] = ah_get(ir_a[j]); ah_nck += 1; }
                }
                if d > 0 && d < IR_MAXV {
                    if op == IR_LOAD && ir_a[j] == 30 && ir_w[j] == 8 && ir_k[j] >= 0 { ah_set(d, ir_k[j]); }
                    else if op == IR_COPY { ah_set(d, ah_get(ir_a[j])); }
                    else { ah_set(d, 0 - 1000000); }
                }
                j += 1;
            }
        }
        b += 1;
    }
}

i64 ah_cellidx(i64 cell) {
    i64 hi = 0;
    while hi < ah_n && ah_cell[hi] != cell { hi += 1; }
    return hi;
}

// the data pointer loaded at j (register d) is used as the base of an indexed access in the same block: the handle is an array whose
// null check was dropped earlier (known not to be null), so it is hoisted like a checked one. `-irdbg 288230376151711744` switches this off.
bool ah_indexed(i64 b, i64 j, i64 d) {
    if (ir_opt & 288230376151711744) != 0 || d <= 0 { return false; }
    i64 e = ir_be[b] - 1;
    i64 m = j + 1;
    while m < e {
        i64 op = ir_op[m];
        if (op == IR_LOAD || op == IR_STORE) && ir_bi[m] == 0 && ir_b[m] == d && ir_a[m] != 30 { return true; }
        if op == IR_ADD && ir_bi[m] == 0 && (ir_a[m] == d || ir_b[m] == d) && ir_d[m] > 0 {
            // data + index, and the sum is the address of the next access
            i64 n2 = m + 1;
            while n2 < e && ir_op[n2] == IR_NOP { n2 += 1; }
            if n2 < e && (ir_op[n2] == IR_LOAD || ir_op[n2] == IR_STORE) && ir_a[n2] == ir_d[m] && ir_a[n2] != 30 { return true; }
        }
        m += 1;
    }
    return false;
}

// a block that runs at every turn (spine = 1) decides which handles are hoisted: from its checks, and from the data loads of handles
// that no check guards any more (the check was dropped because the handle is known not to be null); the other blocks (inside an `if`)
// only use what the spine gave
void ah_scan(i64 b, i64 nch, i64 spine) {
    i64 j = ir_bs[b];
    i64 e = ir_be[b] - 1;
    while j < e {
        i64 op = ir_op[j];
        i64 d = ir_d[j];
        if op == IR_NOP || op == IR_STORE { j += 1; continue; }
        if op == IR_LOAD && ir_a[j] != 30 && ah_get(ir_a[j]) >= 0 && ir_k[j] == 16 && ir_w[j] == 8 {
            i64 cell = ah_get(ir_a[j]);
            i64 hi = ah_cellidx(cell);
            if hi == ah_n && spine == 1 && ah_n < AH_MAXH && (ir_opt & 144115188075855872) == 0 && (ah_incheck(cell) || ah_indexed(b, j, d)) {
                ah_cell[ah_n] = cell;
                ah_trap[ah_n] = 0 - 1;
                ah_n += 1;
            }
            if hi < ah_n && ah_nld < AH_MAXC {
                ah_ld[ah_nld] = j;
                ah_li[ah_nld] = hi;
                ah_nld += 1;
            }
            ah_set(d, 0 - 1000000);
        } else if d > 0 && ir_vcls[d] == 0 {
            i64 nc = 0 - 1000000;
            if op == IR_LOAD && ir_a[j] == 30 && ir_w[j] == 8 && ir_k[j] >= 0 {
                i64 sl = vn_slot(j);
                if sl >= 0 && sl < 8192 && !ah_written(nch, ir_k[j]) { nc = ir_k[j]; }
            } else if op == IR_COPY {
                nc = ah_get(ir_a[j]);
            }
            ah_set(d, nc);
        } else if d > 0 {
            ah_set(d, 0 - 1000000);
        }
        j += 1;
    }
    i64 tt = ir_be[b] - 1;
    if ir_op[tt] == IR_BR && ir_k[tt] == IR_NE && ir_bi[tt] == 1 && ir_b[tt] == 0 && ah_get(ir_a[tt]) >= 0 {
        i64 cell2 = ah_get(ir_a[tt]);
        i64 hi2 = ah_cellidx(cell2);
        if hi2 == ah_n && spine == 1 && ah_n < AH_MAXH {
            ah_cell[ah_n] = cell2;
            ah_trap[ah_n] = ir_t2[tt];
            ah_n += 1;
        }
        if hi2 < ah_n && ah_nbr < AH_MAXC {
            ah_br[ah_nbr] = tt;
            ah_nbr += 1;
        }
    }
}

bool ah_loop(i64 q) {
    i64 h = cl_head[q];
    i64 l = cl_lidx[q];
    if cl_inner[q] != 1 || cl_calls[q] != 0 { return false; }
    i64 th = ir_be[h] - 1;
    if ir_op[th] != IR_BR { return false; }
    // the header: only reads of cells, then the test
    i64 j0 = ir_bs[h];
    while j0 < th {
        i64 o0 = ir_op[j0];
        if o0 != IR_LOAD && o0 != IR_CONST && o0 != IR_NOP && o0 != IR_COPY { return false; }
        if o0 == IR_LOAD && (ir_a[j0] != 30 || ir_w[j0] != 8) { return false; }
        j0 += 1;
    }
    op_mark_loop(l);
    i64 stamp = op_stamp;
    // the blocks of the loop in reverse post order; nothing leaves the loop but the test of the header and the traps
    i64 nch = 0;
    i64 r = 0;
    while r < op_nrpo {
        i64 rb = op_rpo[r];
        if op_mark[rb] == stamp && rb != h {
            if nch >= UJ_MAXB { return false; }
            ah_chain[nch] = rb;
            nch += 1;
            i64 k = 0;
            while k < 2 {
                i64 sx = op_succ(rb, k);
                if sx >= 0 && op_mark[sx] != stamp && !ah_istrap(sx) { return false; }
                k += 1;
            }
        }
        r += 1;
    }
    if nch <= 0 || nch > 40 { return false; }
    if (ir_opt & 72057594037927936) != 0 {
        // -irdbg 72057594037927936: only a loop whose blocks are one straight chain
        i64 nwalk = uj_walk(cl_body[q], h, stamp, @ah_tmpc);
        if nwalk <= 0 || cl_nblk[q] != nwalk + 1 { return false; }
    }
    i64 stb = cl_stb[q];
    ah_n = 0;
    ah_nbr = 0;
    ah_nld = 0;
    ah_collect_checked();
    i64 pass = 0;
    while pass < 2 {
        i64 c = 0;
        ah_stamp += 1;
        ah_prevb = 0 - 1;
        while c < nch {
            i64 b = ah_chain[c];
            bool sp = op_dom(b, stb);
            if (pass == 0 && sp) || (pass == 1 && !sp) {
                i64 np = ah_npred1(b);
                if np != 1 || ah_lastpred != ah_prevb { ah_stamp += 1; }
                i64 spn = 0;
                if pass == 0 { spn = 1; }
                ah_scan(b, nch, spn);
                ah_prevb = b;
            }
            c += 1;
        }
        pass += 1;
    }
    if ah_n == 0 || ah_nld == 0 { return false; }
    // an access of a cell is only changed when the check of that cell was seen before it, and the check is only removed when the
    // data pointer is used: every hoisted cell must have at least one data load
    i64 cellbase = 0 - (op_maxq() + 8);
    i64 u = 0;
    while u < ah_n { ah_ncell[u] = cellbase - 8 * u; u += 1; }
    u = 0;
    while u < ah_nld {
        i64 x = ah_ld[u];
        ir_a[x] = 30;
        ir_b[x] = 0;
        ir_bi[x] = 0;
        ir_k[x] = ah_ncell[ah_li[u]];
        ir_w[x] = 8;
        u += 1;
    }
    u = 0;
    while u < ah_nbr {
        i64 br = ah_br[u];
        ir_op[br] = IR_JMP;
        ir_a[br] = 0;
        ir_b[br] = 0;
        ir_bi[br] = 0;
        ir_k[br] = 0;
        ir_t2[br] = 0 - 1;
        u += 1;
    }
    i64 nb0 = ir_nb;
    // the blocks: P (the test), E (first check), C0 .. Cn-1
    i64 pb = ir_new_block(0 - 1);
    ir_set_block(pb);
    i64 jh = ir_bs[h];
    while jh < th {
        i64 ox = ir_op[jh];
        if ox != IR_NOP {
            i64 ni = ir_add(ox, ir_d[jh], ir_a[jh], ir_b[jh], ir_bi[jh], ir_k[jh]);
            ir_w[ni] = ir_w[jh];
        }
        jh += 1;
    }
    i64 pbr = ir_add(IR_BR, 0, ir_a[th], ir_b[th], ir_bi[th], ir_k[th]);
    i64 body = cl_body[q];
    i64 eb = ir_new_block(0 - 1);
    if ir_t1[th] == body { ir_t1[pbr] = eb; ir_t2[pbr] = ir_t2[th]; }
    else { ir_t1[pbr] = ir_t1[th]; ir_t2[pbr] = eb; }
    ir_set_block(eb);
    u = 0;
    while u < ah_n {
        i64 hv = ir_vreg(0);
        i64 lh = ir_add(IR_LOAD, hv, 30, 0, 0, 0);
        ir_w[lh] = 8;
        ir_k[lh] = ah_cell[u];
        if ah_trap[u] >= 0 {
            i64 bk = ir_add(IR_BR, 0, hv, 0, 1, IR_NE);
            ir_t2[bk] = ah_trap[u];
            i64 cb = ir_new_block(0 - 1);
            ir_t1[bk] = cb;
            ir_set_block(cb);
        }
        i64 dv = ir_vreg(0);
        i64 ld = ir_add(IR_LOAD, dv, hv, 0, 0, 16);
        ir_w[ld] = 8;
        i64 st = ir_add(IR_STORE, 0, 30, dv, 0, ah_ncell[u]);
        ir_w[st] = 8;
        u += 1;
    }
    i64 jp = ir_add(IR_JMP, 0, 0, 0, 0, 0);
    ir_t1[jp] = h;
    // every edge into the header from outside the loop goes to the new test
    i64 b2 = 0;
    while b2 < nb0 {
        if op_po[b2] >= 0 && op_mark[b2] != stamp {
            i64 tb2 = ir_be[b2] - 1;
            i64 top = ir_op[tb2];
            if (top == IR_JMP || top == IR_BR || top == IR_FBR) && ir_t1[tb2] == h { ir_t1[tb2] = pb; }
            if (top == IR_BR || top == IR_FBR) && ir_t2[tb2] == h { ir_t2[tb2] = pb; }
        }
        b2 += 1;
    }
    ah_total += 1;
    ss_total += 1;
    return true;
}

void op_arrhoist() {
    if opt_debug == 1 || (ir_opt & 1125899906842624) != 0 { return; }
    op_counted_loops();
    i64 n = cl_n;
    i64 q = 0;
    while q < n {
        if cl_inner[q] == 1 && cl_calls[q] == 0 { ah_loop(q); }
        q += 1;
    }
}
