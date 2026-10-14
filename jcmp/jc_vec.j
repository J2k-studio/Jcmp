// jc_vec.j -- 128-bit vectors (the class 2 of the IR) at the end of the pipeline, just before the IR is written as text:
//
//   1. a stack object of 16 bytes that is only loaded and stored as a whole (ldr q / str q at its start) and whose address is only used
//      for that, in the block that makes it, lives in a vector register (every load is a copy of it, every store a copy into it);
//   2. every class 2 vreg gets one of the registers v17 .. v29 that the function does not use as a double (a graph colouring over the
//      live ranges; the copies are joined when they can be).
//
// A vector is never alive over a call (the registers are caller-saved and there is no spill): an object that would be is left in
// memory, a temporary that would be makes vr_run return false (the function is then kept as the parser wrote it).

#define VR_MAXID 256
#define VR_W 8                   // 32-bit words in a set of ids

int vr_idof[IR_MAXV];            // class 2 vreg -> id (-1: none)
int vr_vreg[VR_MAXID];           // id -> the vreg (0 for an object before it is promoted)
int vr_obj[VR_MAXID];            // id -> the object (the index in ob_off ...), -1 for a vreg
int vr_nid;
int vr_oid[2048];                // object -> id, or -1
int vr_cand[2048];               // 1: the object is a candidate, 0: not, 2: left alone for the rest of the run
int vr_nacc[2048];
int vr_nld[2048];
int vr_bad[2048];
int vr_ia[IR_MAXI];              // instruction -> the object that a load / store reaches (as a whole or one lane of it), or -1
int vr_ik[IR_MAXI];              // 1: the whole object (16 bytes), 2: a lane of 8 bytes, 3: a lane of 4 bytes
int vr_io[IR_MAXI];              // the byte of the object where the access starts
int vr_fd[IR_MAXI];              // 1: a store of a lane that starts a run of stores that cover the whole object (it needs no old value)

// the frame address that a vreg holds in the block that is read now (vr_ast[v] == vr_stamp: vr_ao[v] is known)
int vr_ao[IR_MAXV];
int vr_ast[IR_MAXV];
int vr_stamp;
int vr_known[256];               // the vregs that hold a frame address in the block now
int vr_nknown;
bool vr_allbad;
int vr_cello[4096];              // a stack cell (the slot (-k) / 8 below the frame pointer) that holds a frame address, in this block
int vr_cellst[4096];
int vr_celll[256];
int vr_ncell;
int vr_dm[64];                   // 1: the double register is named by the function (vreg 32 + n)

int vr_lin[65536];
int vr_lout[65536];
int vr_use[65536];
int vr_def[65536];
int vr_adj[2048];
int vr_cross[VR_MAXID];
int vr_col[VR_MAXID];
int vr_part[VR_MAXID];           // the id that a copy joins with this one (-1: none)
int vr_live[VR_W];
int vr_spk[IR_MAXI];             // call -> where its list of spilled objects starts in vr_spl
int vr_spc[IR_MAXI];             // call -> how many objects are stored before it and loaded after it
int vr_spl[8192];
int vr_nspl;
bool vr_spfail;
int vr_defs[4];
int vr_ndefs;
int vr_uses[4];
int vr_nuses;

bool vr_reach(int b) {
    return ir_opt == 0 || op_po[b] >= 0;
}

bool vr_class2(int v) {
    return v >= 64 && v < ir_nv && ir_vcls[v] == 2;
}

void vr_known_set(int v, int off) {
    if v < 1 || v >= IR_MAXV { return; }
    if vr_ast[v] != vr_stamp {
        if vr_nknown < 256 { vr_known[vr_nknown] = v; vr_nknown += 1; }
    }
    vr_ast[v] = vr_stamp;
    vr_ao[v] = off;
}

bool vr_is_known(int v) {
    return v >= 1 && v < IR_MAXV && vr_ast[v] == vr_stamp;
}

// the vreg v is used in a way that this analysis does not follow: the object it points into cannot live in a register
int vr_ci;                       // the instruction that is read now (-1: the end of a block)
void vr_escape(int v) {
    if v == 30 { vr_allbad = true; return; }
    if !vr_is_known(v) { return; }
    int o = fa_object_of(vr_ao[v]);
    if o >= 0 { vr_bad[o] = 1; }
    if (ir_opt & 262144) != 0 {
        write_err("  escape: vreg "); write_err_int(v); write_err(" holds "); write_err_int(vr_ao[v]);
        if vr_ci >= 0 { write_err(" used by instruction "); write_err_int(vr_ci); write_err(" "); write_err(ir_opname(ir_op[vr_ci])); }
        else { write_err(" at the end of a block"); }
        write_err("\n");
    }
}

// the instruction i makes ids that can be used by the sets below
void vr_du(int i) {
    int op = ir_op[i];
    vr_ndefs = 0;
    vr_nuses = 0;
    int d = ir_d[i];
    if vr_class2(d) && vr_idof[d] >= 0 { vr_defs[vr_ndefs] = vr_idof[d]; vr_ndefs += 1; }
    int a = ir_a[i];
    if vr_class2(a) && vr_idof[a] >= 0 { vr_uses[vr_nuses] = vr_idof[a]; vr_nuses += 1; }
    if ir_uses_b(op) && ir_bi[i] == 0 {
        int b = ir_b[i];
        if vr_class2(b) && vr_idof[b] >= 0 { vr_uses[vr_nuses] = vr_idof[b]; vr_nuses += 1; }
    }
    int o = vr_ia[i];
    if o >= 0 && vr_cand[o] == 1 {
        if op == IR_STORE {
            vr_defs[vr_ndefs] = vr_oid[o];
            vr_ndefs += 1;
            // a lane that is stored keeps the other lanes: the old value is used (unless this store starts a run that covers all)
            if vr_ik[i] != 1 && vr_fd[i] == 0 { vr_uses[vr_nuses] = vr_oid[o]; vr_nuses += 1; }
        } else if op == IR_LOAD {
            vr_uses[vr_nuses] = vr_oid[o];
            vr_nuses += 1;
        }
    }
}

// does the call i read its argument number g (the IR says every call reads x0 .. x7; the function that is called reads its parameters)?
bool vr_call_reads(int i, int g) {
    int op = ir_op[i];
    if op != IR_CALL { return true; }
    char^ cn = @ir_name + ir_k[i] * 64;
    if str_eq(cn, "j2k_copy") || str_eq(cn, "j2k_copy16") { return g == 0 || g == 2 || g == 3; }
    if cn[0] == 'j' && cn[1] == '2' && cn[2] == 'k' && cn[3] == '_' && cn[4] == 'p' && cn[5] == 'r' && cn[6] == 'i' { return g == 0; }
    int cf = find_func(cn);
    if cf >= 0 && farr[cf] == 0 {
        int na = fnpar[cf] + fself[cf] + 1;
        if fret[cf] >= 100 { na += 1; }
        return g < na;
    }
    return true;
}

int vr_seen[IR_MAXB];
int vr_seen_stamp;
int vr_seen_n;

// is the vreg v (a register or a temporary) read later, on some path from the end of the block b, before it is written again?
bool vr_used_from(int b, int v, int depth) {
    int k = 0;
    while k < 2 {
        int s = op_succ(b, k);
        k += 1;
        if s < 0 || vr_seen[s] == vr_seen_stamp { continue; }
        vr_seen[s] = vr_seen_stamp;
        vr_seen_n += 1;
        if vr_seen_n > 300 { return true; }
        bool dead = false;
        int i = ir_bs[s];
        while i < ir_be[s] && !dead {
            int op = ir_op[i];
            if ir_a[i] == v && v != 0 { return true; }
            if ir_uses_b(op) && ir_bi[i] == 0 && ir_b[i] == v { return true; }
            if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                int g = 0;
                while g < ir_ac[i] {
                    if ir_args[ir_as[i] + g] == v && vr_call_reads(i, g) { return true; }
                    g += 1;
                }
                if v < 64 && ((op_clobber() >> v) & 1) == 1 { dead = true; }
            }
            if ir_d[i] == v { dead = true; }
            i += 1;
        }
        if !dead && vr_used_from(s, v, depth + 1) { return true; }
    }
    return false;
}

// which objects are candidates: the walk over the blocks that follows the frame addresses
void vr_find_objects() {
    fa_objects();
    int o = 0;
    while o < ob_n {
        vr_bad[o] = 0;
        vr_nacc[o] = 0;
        vr_nld[o] = 0;
        vr_oid[o] = 0 - 1;
        vr_cand[o] = 0;
        o += 1;
    }
    vr_allbad = false;
    int zi = 0;
    while zi < ir_n {
        vr_ia[zi] = 0 - 1;
        vr_fd[zi] = 0;
        zi += 1;
    }
    int clob = op_clobber();
    int b = 0;
    while b < ir_nb {
        if vr_reach(b) {
            vr_stamp += 1;
            vr_nknown = 0;
            vr_ncell = 0;
            vr_known_set(30, 0);
            int i = ir_bs[b];
            while i < ir_be[b] {
                int op = ir_op[i];
                int d = ir_d[i];
                vr_ci = i;
                vr_ia[i] = 0 - 1;
                int newoff = 0;
                bool newknown = false;
                if op == IR_ADDR_SLOT && d != 30 {
                    newknown = true;
                    newoff = ir_k[i];
                } else if op == IR_ADD && ir_bi[i] == 1 && vr_is_known(ir_a[i]) {
                    newknown = true;
                    newoff = vr_ao[ir_a[i]] + ir_b[i];
                } else if op == IR_COPY && vr_is_known(ir_a[i]) {
                    newknown = true;
                    newoff = vr_ao[ir_a[i]];
                } else if op == IR_LOAD && ir_a[i] == 30 && ir_w[i] == 8 && ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 4096 && vr_cellst[(0 - ir_k[i]) / 8] == vr_stamp {
                    // a frame address that was pushed in a cell of the stack is popped again
                    newknown = true;
                    newoff = vr_cello[(0 - ir_k[i]) / 8];
                } else if op == IR_STORE && ir_a[i] == 30 && ir_w[i] == 8 && ir_k[i] < 0 && (0 - ir_k[i]) % 8 == 0 && (0 - ir_k[i]) / 8 < 4096 {
                    int cs = (0 - ir_k[i]) / 8;
                    if vr_is_known(ir_b[i]) && ir_b[i] != 30 {
                        if vr_ncell < 256 {
                            vr_cello[cs] = vr_ao[ir_b[i]];
                            vr_cellst[cs] = vr_stamp;
                            vr_celll[vr_ncell] = cs;
                            vr_ncell += 1;
                        } else {
                            vr_escape(ir_b[i]);
                        }
                    } else {
                        vr_cellst[cs] = 0;
                        if ir_b[i] == 30 { vr_allbad = true; }
                    }
                } else if op == IR_LOAD || op == IR_STORE {
                    if vr_is_known(ir_a[i]) {
                        int addr = vr_ao[ir_a[i]] + ir_k[i];
                        int ob = fa_object_of(addr);
                        if ob >= 0 {
                            int w = ir_w[i];
                            int off = addr - ob_off[ob];
                            int dv = ir_d[i];
                            if op == IR_STORE { dv = ir_b[i]; }
                            bool okobj = ob_size[ob] == 16 && ob_flag[ob] == 0 && off >= 0 && off < 16 && dv >= 1;
                            int kind = 0;
                            if okobj {
                                if w == 16 && off == 0 && vr_class2(dv) { kind = 1; }
                                else if (w == 8 || w == 0 - 8) && off % 8 == 0 && !vr_class2(dv) && (dv < 64 || ir_vcls[dv] != 2) && !(op == IR_STORE && w < 0) { kind = 2; }
                                else if (w == 4 || (w == 0 - 4 && op == IR_LOAD)) && off % 4 == 0 && !vr_class2(dv) && (dv < 32 || dv >= 64) && ir_vcls[dv] == 0 { kind = 3; }
                            }
                            if kind != 0 {
                                vr_ia[i] = ob;
                                vr_ik[i] = kind;
                                vr_io[i] = off;
                                vr_fd[i] = 0;
                                vr_nacc[ob] += 1;
                                if op == IR_LOAD { vr_nld[ob] += 1; }
                            } else {
                                vr_bad[ob] = 1;
                            }
                        }
                    }
                    if op == IR_STORE { vr_escape(ir_b[i]); }
                } else {
                    vr_escape(ir_a[i]);
                    if ir_uses_b(op) && ir_bi[i] == 0 { vr_escape(ir_b[i]); }
                    if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                        int g = 0;
                        while g < ir_ac[i] {
                            if vr_call_reads(i, g) { vr_escape(ir_args[ir_as[i] + g]); }
                            g += 1;
                        }
                    }
                }
                // the vreg the instruction writes
                if d != 0 {
                    if newknown { vr_known_set(d, newoff); }
                    else if vr_is_known(d) && d != 30 { vr_ast[d] = 0; }
                }
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                    int kk = 0;
                    while kk < vr_nknown {
                        int kv = vr_known[kk];
                        if kv < 64 && vr_ast[kv] == vr_stamp && kv != 30 && ((clob >> kv) & 1) == 1 { vr_ast[kv] = 0; }
                        kk += 1;
                    }
                }
                i += 1;
            }
            // a run of lane stores that covers the whole object in the block: the first of them needs no old value
            int si = ir_bs[b];
            while si < ir_be[b] {
                if ir_op[si] == IR_STORE && vr_ia[si] >= 0 && vr_ik[si] >= 2 {
                    int so = vr_ia[si];
                    int mask = 0;
                    int wb = 8;
                    if vr_ik[si] == 3 { wb = 4; }
                    int bit = 0;
                    while bit < wb { mask = mask | (1 << (vr_io[si] + bit)); bit += 1; }
                    int sj = si + 1;
                    while sj < ir_be[b] && mask != 65535 {
                        int sop = ir_op[sj];
                        if sop == IR_CALL || sop == IR_CALLIND || sop == IR_SYSCALL { break; }
                        if vr_ia[sj] == so {
                            if sop == IR_STORE && vr_ik[sj] >= 2 {
                                int wb2 = 8;
                                if vr_ik[sj] == 3 { wb2 = 4; }
                                int bit2 = 0;
                                while bit2 < wb2 { mask = mask | (1 << (vr_io[sj] + bit2)); bit2 += 1; }
                            } else {
                                break;
                            }
                        }
                        sj += 1;
                    }
                    if mask == 65535 { vr_fd[si] = 1; }
                }
                si += 1;
            }
            // an address that is still held at the end of the block and is needed later (or is a temporary): the object is reached
            // from somewhere that this walk does not see
            vr_ci = 0 - 1;
            // an address that waits in a cell of the stack at the end of the block is used somewhere else
            int cj = 0;
            while cj < vr_ncell {
                int cs2 = vr_celll[cj];
                if vr_cellst[cs2] == vr_stamp {
                    int co = fa_object_of(vr_cello[cs2]);
                    if co >= 0 { vr_bad[co] = 1; }
                }
                cj += 1;
            }
            int kj = 0;
            while kj < vr_nknown {
                int kv2 = vr_known[kj];
                if vr_ast[kv2] == vr_stamp && kv2 != 30 {
                    bool live_out = kv2 >= 64;
                    if !live_out && ((op_lo[b] >> kv2) & 1) == 1 {
                        vr_seen_stamp += 1;
                        vr_seen_n = 0;
                        live_out = vr_used_from(b, kv2, 0);
                    }
                    if live_out { vr_escape(kv2); }
                }
                kj += 1;
            }
        }
        b += 1;
    }
    o = 0;
    while o < ob_n {
        if !vr_allbad && vr_bad[o] == 0 && vr_nacc[o] > 0 && ob_size[o] == 16 && ob_flag[o] == 0 { vr_cand[o] = 1; }
        if (ir_opt & 262144) != 0 && ob_size[o] == 16 {
            write_err("vector object "); write_err_int(ob_off[o]);
            if vr_allbad { write_err(" (the frame pointer is used in another way)"); }
            if vr_bad[o] != 0 { write_err(" bad"); }
            if vr_cand[o] == 1 { write_err(" candidate"); }
            write_err(" accesses "); write_err_int(vr_nacc[o]);
            write_err("\n");
        }
        o += 1;
    }
}

bool vr_test(int^ set, int base, int id) {
    return ((set[base + (id >> 5)] >> (id & 31)) & 1) == 1;
}

void vr_set(int^ set, int base, int id) {
    set[base + (id >> 5)] = set[base + (id >> 5)] | (1 << (id & 31));
}

void vr_clear(int^ set, int base, int id) {
    set[base + (id >> 5)] = set[base + (id >> 5)] & ~(1 << (id & 31));
}

void vr_edge(int x, int y) {
    if x == y { return; }
    vr_set(@vr_adj, x * VR_W, y);
    vr_set(@vr_adj, y * VR_W, x);
}

// liveness of the ids over the blocks, then the interference and the ids that are alive over a call
void vr_analyze() {
    int x = 0;
    vr_nspl = 0;
    vr_spfail = false;
    while x < ir_n { vr_spc[x] = 0; x += 1; }
    x = 0;
    while x < vr_nid * VR_W { vr_adj[x] = 0; x += 1; }
    x = 0;
    while x < vr_nid { vr_cross[x] = 0; vr_part[x] = 0 - 1; x += 1; }
    int b = 0;
    while b < ir_nb {
        int w = 0;
        while w < VR_W {
            vr_use[b * VR_W + w] = 0;
            vr_def[b * VR_W + w] = 0;
            vr_lin[b * VR_W + w] = 0;
            vr_lout[b * VR_W + w] = 0;
            w += 1;
        }
        if vr_reach(b) {
            int i = ir_bs[b];
            while i < ir_be[b] {
                vr_du(i);
                int k = 0;
                while k < vr_nuses {
                    int u = vr_uses[k];
                    if !vr_test(@vr_def, b * VR_W, u) { vr_set(@vr_use, b * VR_W, u); }
                    k += 1;
                }
                k = 0;
                while k < vr_ndefs {
                    vr_set(@vr_def, b * VR_W, vr_defs[k]);
                    k += 1;
                }
                i += 1;
            }
        }
        b += 1;
    }
    bool changed = true;
    while changed {
        changed = false;
        int ri = op_nrpo - 1;
        while ri >= 0 {
            int blk = op_rpo[ri];
            int w2 = 0;
            while w2 < VR_W {
                int out = 0;
                int sk = 0;
                while sk < 2 {
                    int s = op_succ(blk, sk);
                    if s >= 0 { out = out | vr_lin[s * VR_W + w2]; }
                    sk += 1;
                }
                int nin = vr_use[blk * VR_W + w2] | (out & ~vr_def[blk * VR_W + w2]);
                if nin != vr_lin[blk * VR_W + w2] || out != vr_lout[blk * VR_W + w2] {
                    vr_lin[blk * VR_W + w2] = nin;
                    vr_lout[blk * VR_W + w2] = out;
                    changed = true;
                }
                w2 += 1;
            }
            ri -= 1;
        }
    }
    // the interference: a backward walk of every block
    b = 0;
    while b < ir_nb {
        if vr_reach(b) {
            int w3 = 0;
            while w3 < VR_W {
                vr_live[w3] = vr_lout[b * VR_W + w3];
                w3 += 1;
            }
            int i2 = ir_be[b] - 1;
            while i2 >= ir_bs[b] {
                int op = ir_op[i2];
                if op == IR_CALL || op == IR_CALLIND || op == IR_SYSCALL {
                    // a vector that is a temporary cannot be alive over a call; an object is stored before it and loaded after it
                    int id = 0;
                    while id < vr_nid {
                        if vr_test(@vr_live, 0, id) {
                            if vr_obj[id] < 0 {
                                vr_cross[id] = 1;
                            } else {
                                if vr_nspl >= 8190 { vr_spfail = true; }
                                else {
                                    if vr_spc[i2] == 0 { vr_spk[i2] = vr_nspl; }
                                    vr_spl[vr_nspl] = id;
                                    vr_nspl += 1;
                                    vr_spc[i2] += 1;
                                }
                            }
                        }
                        id += 1;
                    }
                    // the loads after the call write the objects: they are alive together with everything that is alive after it
                    int sk = 0;
                    while sk < vr_spc[i2] {
                        int so = vr_spl[vr_spk[i2] + sk];
                        int l2 = 0;
                        while l2 < vr_nid {
                            if l2 != so && vr_test(@vr_live, 0, l2) { vr_edge(so, l2); }
                            l2 += 1;
                        }
                        sk += 1;
                    }
                }
                vr_du(i2);
                // a copy: the two ids may share a register
                int src = 0 - 1;
                if op == IR_COPY && vr_nuses == 1 && vr_ndefs == 1 { src = vr_uses[0]; vr_part[vr_defs[0]] = vr_uses[0]; vr_part[vr_uses[0]] = vr_defs[0]; }
                if (op == IR_LOAD || op == IR_STORE) && vr_ia[i2] >= 0 && vr_cand[vr_ia[i2]] == 1 && vr_ik[i2] == 1 && vr_nuses >= 1 && vr_ndefs >= 1 {
                    // a load of an object (the object is used, the temporary defined) or a store (the object is defined, the value used)
                    src = vr_uses[0];
                    vr_part[vr_defs[0]] = vr_uses[0];
                    vr_part[vr_uses[0]] = vr_defs[0];
                }
                int dk = 0;
                while dk < vr_ndefs {
                    int dd = vr_defs[dk];
                    int id2 = 0;
                    while id2 < vr_nid {
                        if id2 != dd && id2 != src && vr_test(@vr_live, 0, id2) { vr_edge(dd, id2); }
                        id2 += 1;
                    }
                    dk += 1;
                }
                dk = 0;
                while dk < vr_ndefs {
                    vr_clear(@vr_live, 0, vr_defs[dk]);
                    dk += 1;
                }
                int uk = 0;
                while uk < vr_nuses {
                    vr_set(@vr_live, 0, vr_uses[uk]);
                    uk += 1;
                }
                i2 -= 1;
            }
        }
        b += 1;
    }
}

// the colours 0 .. 12 are v17 .. v29, minus the ones that the function uses as doubles; false: not enough
bool vr_colour() {
    int free_mask = 0;
    int r = 17;
    while r <= 29 {
        if vr_dm[r] == 0 { free_mask = free_mask | (1 << (r - 17)); }
        r += 1;
    }
    int id = 0;
    while id < vr_nid { vr_col[id] = 0 - 1; id += 1; }
    id = 0;
    while id < vr_nid {
        int used = 0;
        int j = 0;
        while j < vr_nid {
            if vr_col[j] >= 0 && vr_test(@vr_adj, id * VR_W, j) { used = used | (1 << vr_col[j]); }
            j += 1;
        }
        int avail = free_mask & ~used;
        if avail == 0 { return false; }
        int pick = 0 - 1;
        int pt = vr_part[id];
        if pt >= 0 && vr_col[pt] >= 0 && ((avail >> vr_col[pt]) & 1) == 1 { pick = vr_col[pt]; }
        if pick < 0 {
            int c = 0;
            while c < 13 && pick < 0 {
                if ((avail >> c) & 1) == 1 { pick = c; }
                c += 1;
            }
        }
        vr_col[id] = pick;
        id += 1;
    }
    return true;
}

// the ids: the class 2 vregs that the code mentions, then the candidate objects
bool vr_number() {
    int v = 0;
    while v < ir_nv { vr_idof[v] = 0 - 1; v += 1; }
    vr_nid = 0;
    int b = 0;
    while b < ir_nb {
        if vr_reach(b) {
            int i = ir_bs[b];
            while i < ir_be[b] {
                int regs[3];
                regs[0] = ir_d[i];
                regs[1] = ir_a[i];
                regs[2] = 0;
                if ir_uses_b(ir_op[i]) && ir_bi[i] == 0 { regs[2] = ir_b[i]; }
                int k = 0;
                while k < 3 {
                    int r = regs[k];
                    if vr_class2(r) && vr_idof[r] < 0 {
                        if vr_nid >= VR_MAXID - 8 { return false; }
                        vr_idof[r] = vr_nid;
                        vr_vreg[vr_nid] = r;
                        vr_obj[vr_nid] = 0 - 1;
                        vr_nid += 1;
                    }
                    k += 1;
                }
                i += 1;
            }
        }
        b += 1;
    }
    return true;
}

// does the instruction i read the vector vreg v?
bool vr_reads(int i, int v) {
    if ir_a[i] == v && v != 0 { return true; }
    if ir_uses_b(ir_op[i]) && ir_bi[i] == 0 && ir_b[i] == v { return true; }
    return false;
}

void vr_subst(int i, int from, int to) {
    if ir_a[i] == from { ir_a[i] = to; }
    if ir_uses_b(ir_op[i]) && ir_bi[i] == 0 && ir_b[i] == from { ir_b[i] = to; }
}

void vr_nop(int i) {
    ir_op[i] = IR_NOP;
    ir_d[i] = 0;
    ir_a[i] = 0;
    ir_b[i] = 0;
    ir_bi[i] = 1;
    ir_k[i] = 0;
    ir_w[i] = 0;
}

// copies between vectors in one block: a temporary that is a copy of a register is replaced by the register where it is read; the
// copy into an object that follows the instruction that made the value makes the instruction write the object
void vr_copies() {
    int b = 0;
    while b < ir_nb {
        if vr_reach(b) {
            // A: d = copy a  (d a temporary)
            int i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] == IR_COPY && vr_class2(ir_d[i]) && vr_class2(ir_a[i]) && ir_d[i] != ir_a[i] {
                    int d = ir_d[i];
                    int a = ir_a[i];
                    bool temp = vr_obj[vr_idof[d]] < 0;
                    if temp {
                        int j = i + 1;
                        bool open = true;
                        bool rest_use = false;
                        while j < ir_be[b] {
                            if open { vr_subst(j, d, a); }
                            else if vr_reads(j, d) { rest_use = true; }
                            if ir_d[j] == d && ir_op[j] != IR_NOP { break; }
                            if ir_d[j] == a { open = false; }
                            j += 1;
                        }
                        if !rest_use { vr_nop(i); }
                    }
                }
                i += 1;
            }
            // B: v = copy t  (v an object's register, t made by an instruction of this block and read only here)
            i = ir_bs[b];
            while i < ir_be[b] {
                if ir_op[i] == IR_COPY && vr_class2(ir_d[i]) && vr_class2(ir_a[i]) && ir_d[i] != ir_a[i] {
                    int v = ir_d[i];
                    int t = ir_a[i];
                    if vr_obj[vr_idof[v]] >= 0 && vr_obj[vr_idof[t]] < 0 {
                        // the defining instruction of t
                        int dj = i - 1;
                        bool ok = true;
                        while dj >= ir_bs[b] && ir_d[dj] != t {
                            if ir_d[dj] == v || vr_reads(dj, v) { ok = false; break; }
                            dj -= 1;
                        }
                        if ok && dj >= ir_bs[b] {
                            int dop = ir_op[dj];
                            if dop == IR_VOP || dop == IR_VDUP || (dop == IR_LOAD && ir_w[dj] == 16) || dop == IR_COPY {
                                // t may not be read after the copy
                                int r = i + 1;
                                bool later = false;
                                while r < ir_be[b] {
                                    if vr_reads(r, t) { later = true; }
                                    if ir_d[r] == t && ir_op[r] != IR_NOP { break; }
                                    r += 1;
                                }
                                bool live_after = false;
                                if r >= ir_be[b] { live_after = false; }
                                if !later && !live_after {
                                    int m = dj + 1;
                                    while m < i {
                                        vr_subst(m, t, v);
                                        m += 1;
                                    }
                                    ir_d[dj] = v;
                                    vr_nop(i);
                                }
                            }
                        }
                    }
                }
                i += 1;
            }
        }
        b += 1;
    }
}

// "d = add fp, #k" (the address of a frame object) that nobody reads any more: the loads and stores through it are registers now
void vr_dead_addrs() {
    int clob = op_clobber();
    int b = 0;
    while b < ir_nb {
        if vr_reach(b) {
            int i = ir_bs[b];
            while i < ir_be[b] {
                int op = ir_op[i];
                int d = ir_d[i];
                bool addr = (op == IR_ADDR_SLOT && d != 30) || (op == IR_ADD && ir_bi[i] == 1 && ir_a[i] == 30 && d != 30);
                if addr && d >= 1 {
                    bool used = false;
                    bool dead = false;
                    int j = i + 1;
                    while j < ir_be[b] && !used && !dead {
                        int jop = ir_op[j];
                        if ir_a[j] == d || (ir_uses_b(jop) && ir_bi[j] == 0 && ir_b[j] == d) { used = true; }
                        if jop == IR_CALL || jop == IR_CALLIND || jop == IR_SYSCALL {
                            int g = 0;
                            while g < ir_ac[j] {
                                if ir_args[ir_as[j] + g] == d && vr_call_reads(j, g) { used = true; }
                                g += 1;
                            }
                            if !used && d < 64 && ((clob >> d) & 1) == 1 { dead = true; }
                        }
                        if !used && ir_d[j] == d && jop != IR_NOP { dead = true; }
                        j += 1;
                    }
                    if !used && !dead {
                        // the end of the block
                        if d >= 64 { dead = true; }
                        else if ((op_lo[b] >> d) & 1) == 0 { dead = true; }
                        else {
                            vr_seen_stamp += 1;
                            vr_seen_n = 0;
                            dead = !vr_used_from(b, d, 0);
                        }
                    }
                    if !used && dead { vr_nop(i); }
                }
                i += 1;
            }
        }
        b += 1;
    }
}

// false: the function cannot be written with its vectors (it stays as the parser wrote it)
bool vr_run() {
    bool any = false;
    int i = 0;
    while i < ir_n {
        if ir_op[i] == IR_VOP || ir_op[i] == IR_VDUP || (ir_w[i] == 16 && (ir_op[i] == IR_LOAD || ir_op[i] == IR_STORE)) { any = true; }
        i += 1;
    }
    if !any { return true; }
    op_graph();
    if ir_opt != 0 { op_liveness(); }
    // the double registers that the function names
    int r = 0;
    while r < 64 { vr_dm[r] = 0; r += 1; }
    i = 0;
    while i < ir_n {
        int rr[3];
        rr[0] = ir_d[i];
        rr[1] = ir_a[i];
        rr[2] = 0;
        if ir_uses_b(ir_op[i]) && ir_bi[i] == 0 { rr[2] = ir_b[i]; }
        int k = 0;
        while k < 3 {
            if rr[k] >= 32 && rr[k] < 64 { vr_dm[rr[k] - 32] = 1; }
            k += 1;
        }
        if ir_op[i] == IR_CALL || ir_op[i] == IR_CALLIND || ir_op[i] == IR_SYSCALL {
            int g = 0;
            while g < ir_ac[i] {
                int av = ir_args[ir_as[i] + g];
                if av >= 32 && av < 64 { vr_dm[av - 32] = 1; }
                g += 1;
            }
        }
        i += 1;
    }
    if !vr_number() { return false; }
    int nvec = vr_nid;
    int ncand = 0;
    if ir_opt != 0 {
        vr_find_objects();
        int o = 0;
        while o < ob_n && vr_nid < VR_MAXID - 8 {
            if vr_cand[o] == 1 {
                vr_oid[o] = vr_nid;
                vr_vreg[vr_nid] = 0;
                vr_obj[vr_nid] = o;
                vr_nid += 1;
                ncand += 1;
            }
            o += 1;
        }
        while o < ob_n {
            if vr_cand[o] == 1 { vr_cand[o] = 0; }
            o += 1;
        }
    }
    // alive over a call, or too many alive at once: the object with the fewest accesses stays in memory, until it works
    int rounds = 0;
    while true {
        vr_analyze();
        int ob = 0;
        bool vec_cross = false;
        int idv = 0;
        while idv < nvec {
            if vr_cross[idv] == 1 { vec_cross = true; }
            idv += 1;
        }
        if vr_spfail { return false; }
        if vec_cross { return false; }
        if vr_colour() { break; }
        // not enough registers: drop the object with the fewest accesses
        int low = 0 - 1;
        ob = 0;
        while ob < ob_n {
            if vr_cand[ob] == 1 {
                if low < 0 || vr_nacc[ob] < vr_nacc[low] { low = ob; }
            }
            ob += 1;
        }
        if low < 0 { return false; }
        vr_cand[low] = 2;
        rounds += 1;
        if rounds > 12 { return false; }
    }
    // the promotion: the loads and stores of the objects that stayed become copies of one new vreg each
    int ob2 = 0;
    while ob2 < ob_n {
        if vr_cand[ob2] == 1 {
            int nv = ir_vreg(2);
            vr_vreg[vr_oid[ob2]] = nv;
            vr_idof[nv] = vr_oid[ob2];
        }
        ob2 += 1;
    }
    // the objects that are alive over a call are stored in their place in the frame before it and loaded after it
    if vr_nspl > 0 {
        int extra = vr_nspl * 2 + 8;
        if ir_n + ir_n + extra >= IR_MAXI { return false; }
        int bb = 0;
        while bb < ir_nb {
            bool has = false;
            if vr_reach(bb) {
                int hi = ir_bs[bb];
                while hi < ir_be[bb] {
                    if vr_spc[hi] > 0 { has = true; }
                    hi += 1;
                }
            }
            if has {
                int ns = ir_n;
                int e0 = ir_be[bb];
                int ci = ir_bs[bb];
                while ci < e0 {
                    int sc = vr_spc[ci];
                    int q = 0;
                    while q < sc {
                        int so = vr_spl[vr_spk[ci] + q];
                        int sob = vr_obj[so];
                        int n0 = ir_n;
                        ir_op[n0] = IR_STORE; ir_d[n0] = 0; ir_a[n0] = 30; ir_b[n0] = vr_vreg[so]; ir_bi[n0] = 0; ir_k[n0] = ob_off[sob]; ir_w[n0] = 16;
                        ir_t1[n0] = 0 - 1; ir_t2[n0] = 0 - 1; ir_as[n0] = 0; ir_ac[n0] = 0;
                        vr_ia[n0] = 0 - 1; vr_fd[n0] = 0; vr_spc[n0] = 0;
                        ir_n += 1;
                        q += 1;
                    }
                    int n1 = ir_n;
                    ir_op[n1] = ir_op[ci]; ir_d[n1] = ir_d[ci]; ir_a[n1] = ir_a[ci]; ir_b[n1] = ir_b[ci]; ir_bi[n1] = ir_bi[ci]; ir_k[n1] = ir_k[ci]; ir_w[n1] = ir_w[ci];
                    ir_t1[n1] = ir_t1[ci]; ir_t2[n1] = ir_t2[ci]; ir_as[n1] = ir_as[ci]; ir_ac[n1] = ir_ac[ci];
                    vr_ia[n1] = vr_ia[ci]; vr_ik[n1] = vr_ik[ci]; vr_io[n1] = vr_io[ci]; vr_fd[n1] = vr_fd[ci];
                    ir_n += 1;
                    q = 0;
                    while q < sc {
                        int lo = vr_spl[vr_spk[ci] + q];
                        int lob = vr_obj[lo];
                        int n2 = ir_n;
                        ir_op[n2] = IR_LOAD; ir_d[n2] = vr_vreg[lo]; ir_a[n2] = 30; ir_b[n2] = 0; ir_bi[n2] = 0; ir_k[n2] = ob_off[lob]; ir_w[n2] = 16;
                        ir_t1[n2] = 0 - 1; ir_t2[n2] = 0 - 1; ir_as[n2] = 0; ir_ac[n2] = 0;
                        vr_ia[n2] = 0 - 1; vr_fd[n2] = 0;
                        ir_n += 1;
                        q += 1;
                    }
                    ci += 1;
                }
                ir_bs[bb] = ns;
                ir_be[bb] = ir_n;
            }
            bb += 1;
        }
        // the arrays of the new instructions: the calls are not spilled twice
        int zz = 0;
        while zz < ir_n { vr_spc[zz] = 0; zz += 1; }
    }
    int j = 0;
    while j < ir_n {
        int oo = vr_ia[j];
        if oo >= 0 && vr_cand[oo] == 1 {
            int var = vr_vreg[vr_oid[oo]];
            int kind = vr_ik[j];
            if ir_op[j] == IR_LOAD {
                if kind == 1 {
                    ir_op[j] = IR_COPY;
                    ir_a[j] = var;
                    ir_k[j] = 0;
                    ir_w[j] = 0;
                } else {
                    // a lane: the old a (the base) is not needed
                    ir_op[j] = IR_VLANE;
                    ir_a[j] = var;
                    ir_k[j] = vr_io[j];
                }
                ir_b[j] = 0;
                ir_bi[j] = 0;
            } else if vr_nld[oo] == 0 {
                ir_op[j] = IR_NOP;
                ir_d[j] = 0;
                ir_a[j] = 0;
                ir_b[j] = 0;
                ir_bi[j] = 1;
                ir_k[j] = 0;
                ir_w[j] = 0;
            } else if kind == 1 {
                int val = ir_b[j];
                ir_op[j] = IR_COPY;
                ir_d[j] = var;
                ir_a[j] = val;
                ir_b[j] = 0;
                ir_bi[j] = 0;
                ir_k[j] = 0;
                ir_w[j] = 0;
            } else {
                int val2 = ir_b[j];
                ir_op[j] = IR_VINS;
                ir_d[j] = var;
                ir_a[j] = var;
                ir_b[j] = val2;
                ir_bi[j] = 0;
                ir_k[j] = vr_io[j];
            }
        }
        j += 1;
    }
    vr_copies();
    vr_dead_addrs();
    // the registers: every vector is an ordinary vreg now, so the live ranges are worked out again
    int zo = 0;
    while zo < ob_n { vr_cand[zo] = 0; zo += 1; }
    zo = 0;
    while zo < ir_n { vr_ia[zo] = 0 - 1; zo += 1; }
    if !vr_number() { return false; }
    vr_analyze();
    if vr_spfail { return false; }
    int idc = 0;
    while idc < vr_nid {
        if vr_cross[idc] == 1 { return false; }
        idc += 1;
    }
    if !vr_colour() { return false; }
    int id3 = 0;
    while id3 < vr_nid {
        int v3 = vr_vreg[id3];
        if v3 >= 64 { lw_tmp_reg[v3] = 17 + vr_col[id3]; }
        id3 += 1;
    }
    return true;
}
