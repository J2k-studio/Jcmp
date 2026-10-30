// llama 0.2.0 -- runs Llama-style language models from GGUF files on the phone (CPU): the forward pass, a SentencePiece tokenizer, sampling.   #import <llama>   (needs <gguf>; license: MPL-2.0)
//   switch Lm::load("stories15M-q4_0.gguf") {
//       Result::Ok(m): {
//           int[] ids = m.encode("Once upon a time");              // token numbers (with the start token)
//           String text = m.generate(ids, 60, 0.8, 40, 0.95, 1);   // 60 new tokens; temperature, top-k (0 = off), top-p (1.0 = off), seed
//           cout << text << "\n";
//       }
//       Result::Err(e): { cout << e.message << "\n"; }
//   }
// Lower level: m.reset(); Tensor32 logits = m.step(token) (one token, the cache remembers the earlier ones); m.piece(token) is its text.
// Weights are read as float32 (F32, F16, Q8_0, Q4_0 files are dequantised when loaded: a 15M model takes about 60 MB). The architecture "llama" (RMS norm, RoPE,
// grouped-query attention, SwiGLU) is supported; the context is cut at 512 tokens.

#import <gguf>
#import <simd>

i8^ lm_xq;                          // the quantised copy of the vector x (one byte per number) and its scales, made once for all products
float^ lm_xs;

// x as bytes, a scale for every 32 numbers (like Q8_0): a product with a quantised matrix uses it
void llama_qx(float[] x) {
    if (int)lm_xq == 0 {
        lm_xq = (i8^)Sys::mmap(262144);
        lm_xs = (float^)Sys::mmap(32768);
    }
    int nb = x.len / 32;
    for b in 0..nb {
        float amax = 0.0;
        for j in 0..32 {
            float v = x[b * 32 + j];
            if v < 0.0 { v = 0.0 - v; }
            if v > amax { amax = v; }
        }
        float inv = 0.0;
        if amax > 0.0 { inv = 127.0 / amax; }
        lm_xs[b] = amax / 127.0;
        for j in 0..32 {
            float v = x[b * 32 + j] * inv;
            int q = 0;
            if v >= 0.0 { q = (int)(v + 0.5); } else { q = 0 - (int)(0.5 - v); }
            lm_xq[b * 32 + j] = (i8)q;
        }
    }
}

// one row of a quantised matrix against the quantised x: nb blocks of 32 weights, two SDOT instructions each (the lanes are added without a call)
float llama_qrow(i8^ wp, float^ wsp, i8^ xq, float^ xs, int nb) {
    float acc = 0.0;
    for b in 0..nb {
        i32x4 d0 = i8x16::load(wp, b * 32).dot(i8x16::load(xq, b * 32));
        i32x4 d1 = i8x16::load(wp, b * 32 + 16).dot(i8x16::load(xq, b * 32 + 16));
        i32x4 dd = d0 + d1;
        int t = dd.x + dd.y + dd.z + dd.w;
        acc += (float)t * (wsp[b] * xs[b]);
    }
    return acc;
}

// y = W x for a matrix W of rows x cols (QMat) and a vector x of cols numbers. A quantised matrix: x is quantised too and every 32 numbers are two SDOT
// instructions (i8x16 dot); a float matrix: four numbers at a time (NEON), two sums, when cols is a multiple of 8
float[] llama_mv(QMat m, float[] x) {
    int rows = m.rows;
    int cols = m.cols;
    float[] y = arr(rows + 1);
    if m.quant == 1 {
        llama_qx(x);
        int nb = cols / 32;
        float^ xs = lm_xs;
        i8^ xq = lm_xq;
        for j in 0..rows { y.push(llama_qrow((i8^)(m.wq + j * cols), (float^)(m.ws + j * nb * 4), xq, xs, nb)); }
        return y;
    }
    Tensor32 w = m.f;
    if cols % 8 == 0 {
        float^ wp = @w.d[0];
        float^ xp = @x[0];
        for j in 0..rows {
            int o = j * cols;
            f32x4 s0 = {0.0, 0.0, 0.0, 0.0};
            f32x4 s1 = {0.0, 0.0, 0.0, 0.0};
            int i = 0;
            while i < cols {
                s0 = s0 + f32x4::load(wp, o + i) * f32x4::load(xp, i);
                s1 = s1 + f32x4::load(wp, o + i + 4) * f32x4::load(xp, i + 4);
                i += 8;
            }
            f32x4 s = s0 + s1;
            y.push(s.sum());
        }
        return y;
    }
    for j in 0..rows {
        int o = j * cols;
        float s0 = 0.0;
        for i in 0..cols { s0 += w.d[o + i] * x[i]; }
        y.push(s0);
    }
    return y;
}

// the row r of a matrix as float numbers (an embedding)
float[] llama_row(QMat m, int r) {
    float[] y = arr(m.cols + 1);
    if m.quant == 1 {
        i8^ wp = (i8^)(m.wq + r * m.cols);
        float^ wsp = (float^)(m.ws + r * (m.cols / 32) * 4);
        for j in 0..m.cols { y.push((float)wp[j] * wsp[j / 32]); }
        return y;
    }
    for j in 0..m.cols { y.push(m.f.d[r * m.cols + j]); }
    return y;
}

float[] llama_rms(float[] x, Tensor32 gain, double eps) {
    int n = x.len;
    double ss = 0.0;
    for i in 0..n { ss += (double)x[i] * (double)x[i]; }
    float k = (float)(1.0 / Math::sqrt(ss / (double)n + eps));
    float[] y = arr(n + 1);
    for i in 0..n { y.push(x[i] * k * gain.d[i]); }
    return y;
}

struct Llama {
    int embd;
    int layers;
    int heads;
    int kv_heads;
    int hd;                            // the width of a head
    int ffn;
    int vocab;
    int ctx;
    double eps;
    double rope_base;
    int rope_dims;
    QMat tok_emb;
    Tensor32 out_norm;
    QMat output;
    QMat[] wq;
    QMat[] wk;
    QMat[] wv;
    QMat[] wo;
    Tensor32[] anorm;
    QMat[] gate;
    QMat[] down;
    QMat[] up;
    Tensor32[] fnorm;
    float[] kc;                        // the keys and values of the positions done: [layer][position][kv_heads * hd]
    float[] vc;
    int pos;                           // the next position
    // the tokenizer
    String[] pieces;
    double[] scores;
    Map<String, int> ids;
    int bos;
    int eos;
    int rng;

    void reset(self) { self.pos = 0; }

    // one token at the position pos: the scores (logits) of the next token, one row; the position moves on
    Tensor32 step(self, int token) {
        int e = self.embd;
        int kvd = self.kv_heads * self.hd;
        float[] x = llama_row(self.tok_emb, token);
        int p = self.pos;
        double inv = 1.0 / Math::sqrt((double)self.hd);
        int group = self.heads / self.kv_heads;
        int half = self.rope_dims / 2;
        float[] rc = arr(half + 1);                                      // cos and sin of the angles of this position (the same in every layer)
        float[] rs = arr(half + 1);
        for i in 0..half {
            double ang = (double)p * Math::pow(self.rope_base, 0.0 - 2.0 * (double)i / (double)self.rope_dims);
            rc.push((float)Math::cos(ang));
            rs.push((float)Math::sin(ang));
        }
        for l in 0..self.layers {
            float[] h = llama_rms(x, self.anorm[l], self.eps);
            float[] q = llama_mv(self.wq[l], h);
            float[] k = llama_mv(self.wk[l], h);
            float[] v = llama_mv(self.wv[l], h);
            // RoPE: the pairs (2i, 2i+1) of every head are turned by the angle p * base^(-2i / dims)
            for hh in 0..self.heads {
                for i in 0..half {
                    int a = hh * self.hd + 2 * i;
                    float q0 = q[a];
                    float q1 = q[a + 1];
                    q[a] = q0 * rc[i] - q1 * rs[i];
                    q[a + 1] = q0 * rs[i] + q1 * rc[i];
                }
            }
            for hh in 0..self.kv_heads {
                for i in 0..half {
                    int a = hh * self.hd + 2 * i;
                    float k0 = k[a];
                    float k1 = k[a + 1];
                    k[a] = k0 * rc[i] - k1 * rs[i];
                    k[a + 1] = k0 * rs[i] + k1 * rc[i];
                }
            }
            int base = (l * self.ctx + p) * kvd;
            for i in 0..kvd { self.kc[base + i] = k[i]; self.vc[base + i] = v[i]; }
            float[] att = arr(e + 1);
            for i in 0..e { att.push(0.0); }
            for hh in 0..self.heads {
                int kvh = hh / group;
                float[] sc = arr(p + 2);
                double mx = -1.0e30;
                for t in 0..p + 1 {
                    int kb = (l * self.ctx + t) * kvd + kvh * self.hd;
                    double dot = 0.0;
                    for d in 0..self.hd { dot += (double)q[hh * self.hd + d] * (double)self.kc[kb + d]; }
                    dot = dot * inv;
                    sc.push((float)dot);
                    if dot > mx { mx = dot; }
                }
                double z = 0.0;
                for t in 0..p + 1 { double ex = Math::exp((double)sc[t] - mx); sc[t] = (float)ex; z += ex; }
                for t in 0..p + 1 {
                    float w = (float)((double)sc[t] / z);
                    int vb = (l * self.ctx + t) * kvd + kvh * self.hd;
                    for d in 0..self.hd { att[hh * self.hd + d] += w * self.vc[vb + d]; }
                }
            }
            float[] o = llama_mv(self.wo[l], att);
            for i in 0..e { x[i] += o[i]; }
            float[] h2 = llama_rms(x, self.fnorm[l], self.eps);
            float[] g = llama_mv(self.gate[l], h2);
            float[] u = llama_mv(self.up[l], h2);
            for i in 0..self.ffn {
                double gv = (double)g[i];
                g[i] = (float)(gv / (1.0 + Math::exp(0.0 - gv))) * u[i];
            }
            float[] dn = llama_mv(self.down[l], g);
            for i in 0..e { x[i] += dn[i]; }
        }
        float[] fin = llama_rms(x, self.out_norm, self.eps);
        float[] lg = llama_mv(self.output, fin);
        Tensor32 r = Tensor32::zeros(1, self.vocab);
        for i in 0..self.vocab { r.d[i] = lg[i]; }
        self.pos = p + 1;
        return r;
    }

    // ---- the tokenizer (SentencePiece as llama.cpp does it: spaces become the sign ▁, the pairs with the best score are joined while they are in the vocabulary)
    int id_of(self, String piece) {
        Option<int> o = self.ids.try_get(piece);
        switch o {
            Option::Some(v): return v;
            Option::None: return -1;
        }
        return -1;
    }
    int[] encode(self, String text) {
        String t = "\xe2\x96\x81";                                      // ▁ in front, and instead of every space
        for i in 0..text.len {
            if text[i] == ' ' { t = t + "\xe2\x96\x81"; } else { t.push(text[i]); }
        }
        String[] sym = arr(t.len + 1);                                  // one UTF-8 character each
        int i = 0;
        while i < t.len {
            int c = t[i] & 255;
            int n = 1;
            if c >= 240 { n = 4; } else if c >= 224 { n = 3; } else if c >= 192 { n = 2; }
            if i + n > t.len { n = t.len - i; }
            sym.push(t.slice(i, i + n) + "");
            i += n;
        }
        while true {
            double best = -1.0e30;
            int at = -1;
            for j in 0..sym.len - 1 {
                String pair = sym[j] + sym[j + 1];
                int id = self.id_of(pair);
                if id >= 0 && self.scores[id] > best { best = self.scores[id]; at = j; }
            }
            if at < 0 { break; }
            sym[at] = sym[at] + sym[at + 1];
            int j2 = at + 1;
            while j2 + 1 < sym.len { sym[j2] = sym[j2 + 1]; j2 += 1; }
            sym.pop();
        }
        int[] out = arr(sym.len + 2);
        out.push(self.bos);
        for j in 0..sym.len {
            int id = self.id_of(sym[j]);
            if id >= 0 { out.push(id); }
            else {                                                       // a piece that is not in the vocabulary: its bytes (<0xNN> tokens)
                for b in 0..sym[j].len {
                    String hex = "0123456789ABCDEF";
                    int bv = sym[j][b] & 255;
                    String name = "<0x" + hex.slice(bv / 16, bv / 16 + 1) + hex.slice(bv % 16, bv % 16 + 1) + ">";
                    int bid = self.id_of(name);
                    if bid >= 0 { out.push(bid); }
                }
            }
        }
        return out;
    }
    // the text of a token: ▁ is a space, <0xNN> is one byte
    String piece(self, int token) {
        if token < 0 || token >= self.pieces.len { return ""; }
        String p = self.pieces[token] + "";
        if p.len == 6 && p.starts_with("<0x") && p[5] == '>' {
            int hi = p[3] - '0';
            if p[3] >= 'A' { hi = p[3] - 'A' + 10; }
            int lo = p[4] - '0';
            if p[4] >= 'A' { lo = p[4] - 'A' + 10; }
            String one = "";
            one.push((char)(hi * 16 + lo));
            return one;
        }
        String r = "";
        int i = 0;
        while i < p.len {
            if i + 2 < p.len && (p[i] & 255) == 226 && (p[i + 1] & 255) == 150 && (p[i + 2] & 255) == 129 { r.push(' '); i += 3; }
            else { r.push(p[i]); i += 1; }
        }
        return r;
    }

    // ---- choosing the next token from the scores: temperature 0 = the highest; top_k 0 = off; top_p 1.0 = off
    int next_rand(self) {
        int x = self.rng;
        x = x xor (x << 13);
        x = x xor ((x >> 7) & 72057594037927935);
        x = x xor (x << 17);
        self.rng = x;
        return x & 2147483647;
    }
    int sample(self, Tensor32 logits, double temp, int top_k, double top_p) {
        int n = self.vocab;
        int best = 0;
        for i in 1..n { if logits.d[i] > logits.d[best] { best = i; } }
        if temp <= 0.0 { return best; }
        // the candidates sorted by score (only the top ones are needed: a partial selection)
        int m = n;
        if top_k > 0 && top_k < n { m = top_k; }
        if top_p < 1.0 && m > 64 { m = 64; }
        int[] cand = arr(m + 1);
        float[] val = arr(m + 1);
        for i in 0..n {
            float v = logits.d[i];
            if cand.len < m {
                cand.push(i);
                val.push(v);
                int k = cand.len - 1;
                while k > 0 && val[k] > val[k - 1] {
                    float tv = val[k]; val[k] = val[k - 1]; val[k - 1] = tv;
                    int ti = cand[k]; cand[k] = cand[k - 1]; cand[k - 1] = ti;
                    k -= 1;
                }
            } else if v > val[m - 1] {
                val[m - 1] = v;
                cand[m - 1] = i;
                int k = m - 1;
                while k > 0 && val[k] > val[k - 1] {
                    float tv = val[k]; val[k] = val[k - 1]; val[k - 1] = tv;
                    int ti = cand[k]; cand[k] = cand[k - 1]; cand[k - 1] = ti;
                    k -= 1;
                }
            }
        }
        double mx = (double)val[0];
        double[] pr = arr(m + 1);
        double z = 0.0;
        for i in 0..m { double e = Math::exp(((double)val[i] - mx) / temp); pr.push(e); z += e; }
        for i in 0..m { pr[i] = pr[i] / z; }
        int keep = m;
        if top_p < 1.0 {
            double acc = 0.0;
            keep = 0;
            for i in 0..m { acc += pr[i]; keep = i + 1; if acc >= top_p { break; } }
            double z2 = 0.0;
            for i in 0..keep { z2 += pr[i]; }
            for i in 0..keep { pr[i] = pr[i] / z2; }
        }
        double r = (double)(self.next_rand() % 1000000) / 1000000.0;
        double acc2 = 0.0;
        for i in 0..keep { acc2 += pr[i]; if r < acc2 { return cand[i]; } }
        return cand[keep - 1];
    }

    // the prompt tokens, then `count` new tokens (it stops at the end token); the text of the new tokens
    String generate(self, int[] prompt, int count, double temp, int top_k, double top_p, int seed) {
        self.reset();
        self.rng = seed * 2654435761 + 88172645463325252;
        if self.rng == 0 { self.rng = 1; }
        Tensor32 lg = Tensor32::zeros(1, 1);
        for i in 0..prompt.len { lg = self.step(prompt[i]); }
        String out = "";
        for k in 0..count {
            if self.pos >= self.ctx { break; }
            int t = self.sample(lg, temp, top_k, top_p);
            if t == self.eos { break; }
            out = out + self.piece(t);
            lg = self.step(t);
        }
        return out;
    }
}

struct Lm {
    static Result<Llama, Error> bad(String why) {
        return Result<Llama, Error>::Err(Error::make(ErrorKind::Parse, why));
    }

    static Result<Llama, Error> load(String path) {
        Result<GgufFile, Error> r = Gg::open(path);
        switch r {
            Result::Ok(f): {
                if f.meta("general.architecture") != "llama" { return Lm::bad("the architecture is '" + f.meta("general.architecture") + "', only llama is run"); }
                Llama m;
                m.embd = f.meta_int("llama.embedding_length", 0);
                m.layers = f.meta_int("llama.block_count", 0);
                m.heads = f.meta_int("llama.attention.head_count", 0);
                m.kv_heads = f.meta_int("llama.attention.head_count_kv", m.heads);
                m.ffn = f.meta_int("llama.feed_forward_length", 0);
                m.ctx = f.meta_int("llama.context_length", 512);
                if m.ctx > 512 { m.ctx = 512; }
                m.eps = f.meta_double("llama.attention.layer_norm_rms_epsilon", 0.00001);
                m.rope_base = f.meta_double("llama.rope.freq_base", 10000.0);
                if m.embd <= 0 || m.layers <= 0 || m.heads <= 0 { return Lm::bad("the file has no model sizes"); }
                m.hd = m.embd / m.heads;
                m.rope_dims = f.meta_int("llama.rope.dimension_count", m.hd);
                bool ok = false;
                m.tok_emb = f.load_mat("token_embd.weight", @ok);
                if !ok { return Lm::bad("no token_embd.weight (or a type that is not read)"); }
                m.vocab = m.tok_emb.rows;
                m.out_norm = f.load("output_norm.weight", @ok);
                if !ok { return Lm::bad("no output_norm.weight"); }
                m.output = f.load_mat("output.weight", @ok);
                if !ok { m.output = m.tok_emb; }                         // tied embeddings
                m.wq = arr(m.layers + 1); m.wk = arr(m.layers + 1); m.wv = arr(m.layers + 1); m.wo = arr(m.layers + 1);
                m.anorm = arr(m.layers + 1); m.gate = arr(m.layers + 1); m.down = arr(m.layers + 1); m.up = arr(m.layers + 1); m.fnorm = arr(m.layers + 1);
                for l in 0..m.layers {
                    String pre = "blk." + str(l) + ".";
                    m.wq.push(f.load_mat(pre + "attn_q.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "attn_q.weight"); }
                    m.wk.push(f.load_mat(pre + "attn_k.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "attn_k.weight"); }
                    m.wv.push(f.load_mat(pre + "attn_v.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "attn_v.weight"); }
                    m.wo.push(f.load_mat(pre + "attn_output.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "attn_output.weight"); }
                    m.anorm.push(f.load(pre + "attn_norm.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "attn_norm.weight"); }
                    m.gate.push(f.load_mat(pre + "ffn_gate.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "ffn_gate.weight"); }
                    m.down.push(f.load_mat(pre + "ffn_down.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "ffn_down.weight"); }
                    m.up.push(f.load_mat(pre + "ffn_up.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "ffn_up.weight"); }
                    m.fnorm.push(f.load(pre + "ffn_norm.weight", @ok));
                    if !ok { return Lm::bad("missing " + pre + "ffn_norm.weight"); }
                }
                int kvd = m.kv_heads * m.hd;
                m.kc = arr(m.layers * m.ctx * kvd + 1);
                m.vc = arr(m.layers * m.ctx * kvd + 1);
                for i in 0..m.layers * m.ctx * kvd { m.kc.push(0.0); m.vc.push(0.0); }
                m.pos = 0;
                m.pieces = f.tokens;
                m.scores = f.scores;
                Map<String, int> idm;
                m.ids = idm;
                for i in 0..m.pieces.len { m.ids.put(m.pieces[i] + "", i); }
                m.bos = f.meta_int("tokenizer.ggml.bos_token_id", 1);
                m.eos = f.meta_int("tokenizer.ggml.eos_token_id", 2);
                m.rng = 1;
                return Result<Llama, Error>::Ok(m);
            }
            Result::Err(e): { return Result<Llama, Error>::Err(Error::make(e.kind, e.message)); }
        }
        return Lm::bad("load failed");
    }
}
