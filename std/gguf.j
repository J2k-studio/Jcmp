// gguf 0.2.0 -- a reader of GGUF model files (the format of llama.cpp): metadata, the tokens, and the tensors as float32.   #import <gguf>   (needs <neuron>, <simd>; license: MPL-2.0)
//   switch Gg::open("model.gguf") {
//       Result::Ok(f): {
//           cout << f.meta("general.architecture") << " " << f.meta_int("llama.block_count", 0) << "\n";
//           for i in 0..f.tensor_count() { cout << f.name(i) << " " << f.shape_text(i) << " type " << f.type_name(i) << "\n"; }
//           Tensor32 w = f.load("token_embd.weight");          // dequantised to float32; shape = [ne1, ne0] (rows, row width)
//       }
//       Result::Err(e): { cout << e.message << "\n"; }
//   }
// Types read: F32, F16, Q8_0, Q4_0 (the ones small models use); other tensor types are listed but load() gives an Error text via ok=false.
// f.tokens (the vocabulary), f.merges (BPE merges, if the file has them). The whole header is read into memory (up to 64 MB); a tensor is read from the file when it is loaded.

#import <neuron>
#import <simd>

struct GgReader {
    String b;
    int p;
    bool bad;

    int u8(self) {
        if self.p >= self.b.len { self.bad = true; return 0; }
        int v = self.b[self.p] & 255;
        self.p += 1;
        return v;
    }
    int u32(self) {
        int v = 0;
        for k in 0..4 { v = v | (self.u8() << (8 * k)); }
        return v;
    }
    int u64(self) {
        int v = 0;
        for k in 0..8 { v = v | (self.u8() << (8 * k)); }
        return v;
    }
    String str(self) {
        int n = self.u64();
        if n < 0 || self.p + n > self.b.len { self.bad = true; return ""; }
        String s = self.b.slice(self.p, self.p + n) + "";
        self.p += n;
        return s;
    }
}

// a half precision number (16 bits) as a double
double gg_half(int h) {
    int sign = (h >> 15) & 1;
    int e = (h >> 10) & 31;
    int m = h & 1023;
    double v = 0.0;
    if e == 0 { v = (double)m / 1024.0 * Math::pow(2.0, -14.0); }
    else if e == 31 { v = 65504.0; }
    else { v = (1.0 + (double)m / 1024.0) * Math::pow(2.0, (double)(e - 15)); }
    if sign == 1 { return 0.0 - v; }
    return v;
}

// a matrix of a model: quantised tensors (Q8_0, Q4_0) are kept as bytes (int8, one byte per weight) with a scale for every 32 weights, so a product with them
// moves a quarter of the memory of float32 and can use the int8 dot product (i8x16.dot); other types are float32 in `f`
struct QMat {
    int quant;                         // 1: wq / ws hold the weights; 0: f holds them
    Tensor32 f;
    int rows;
    int cols;
    int wq;                            // the address of rows * cols int8 weights (row after row)
    int ws;                            // the address of rows * cols / 32 float scales
}

struct GgufFile {
    String path;
    int version;
    int align;
    int data_start;
    String[] keys;                     // the metadata: names ...
    String[] vals;                     // ... and values as text (an array shows as "[array of N]")
    String[] tokens;                   // tokenizer.ggml.tokens
    String[] merges;                   // tokenizer.ggml.merges
    double[] scores;                   // tokenizer.ggml.scores (the score of every token, for the SentencePiece merges)
    String[] t_names;
    int[] t_type;
    int[] t_off;
    int[] t_dims;                      // 4 numbers per tensor (ne0 first; unused ones are 1)
    int[] t_nd;

    String meta(self, String key) {
        for i in 0..self.keys.len { if self.keys[i] == key { return self.vals[i] + ""; } }
        return "";
    }
    int meta_int(self, String key, int fallback) {
        String v = self.meta(key);
        if v.len == 0 { return fallback; }
        return v.to_int();
    }
    double meta_double(self, String key, double fallback) {
        String v = self.meta(key);
        if v.len == 0 { return fallback; }
        return v.to_double();
    }
    int tensor_count(self) { return self.t_names.len; }
    String name(self, int i) { return self.t_names[i] + ""; }
    int find(self, String name) {
        for i in 0..self.t_names.len { if self.t_names[i] == name { return i; } }
        return -1;
    }
    String type_name(self, int i) {
        int t = self.t_type[i];
        if t == 0 { return "F32"; }
        if t == 1 { return "F16"; }
        if t == 2 { return "Q4_0"; }
        if t == 3 { return "Q4_1"; }
        if t == 6 { return "Q5_0"; }
        if t == 7 { return "Q5_1"; }
        if t == 8 { return "Q8_0"; }
        if t == 30 { return "BF16"; }
        return "type" + str(t);
    }
    // the dimensions as text, the widest-varying first as GGUF writes them: "4096 32000"
    String shape_text(self, int i) {
        String s = "";
        for k in 0..self.t_nd[i] {
            if k > 0 { s.push(' '); }
            s.append(str(self.t_dims[i * 4 + k]));
        }
        return s;
    }
    int elements(self, int i) {
        int n = 1;
        for k in 0..self.t_nd[i] { n = n * self.t_dims[i * 4 + k]; }
        return n;
    }
    bool supported(self, int i) {
        int t = self.t_type[i];
        return t == 0 || t == 1 || t == 2 || t == 8 || t == 30;
    }

    // the numbers of the tensor i as float32. The shape is [ne_last .. ne1, ne0] (one dimension: [1, ne0]); ok is false for a type that is not read
    Tensor32 load_at(self, int i, bool^ ok) {
        int n = self.elements(i);
        int t = self.t_type[i];
        int[] shape = arr(5);
        int nd = self.t_nd[i];
        if nd == 1 { shape.push(1); }
        int k = nd - 1;
        while k >= 0 { shape.push(self.t_dims[i * 4 + k]); k -= 1; }
        Tensor32 r = Tensor32::make(shape);
        ok[0] = true;
        int bytes = 0;
        if t == 0 { bytes = n * 4; }
        else if t == 1 || t == 30 { bytes = n * 2; }
        else if t == 8 { bytes = n / 32 * 34; }
        else if t == 2 { bytes = n / 32 * 18; }
        else { ok[0] = false; return r; }
        int fd = Sys::open_read(self.path.c());
        if fd < 0 { ok[0] = false; return r; }
        Sys::lseek(fd, self.data_start + self.t_off[i], 0);
        String raw = "";
        char buf[65536];
        int left = bytes;
        while left > 0 {
            int want = left;
            if want > 65536 { want = 65536; }
            int got = Sys::read(fd, @buf, want);
            if got <= 0 { break; }
            for q in 0..got { raw.push(buf[q]); }
            left -= got;
        }
        Sys::close(fd);
        if raw.len < bytes { ok[0] = false; return r; }
        if t == 0 {
            for q in 0..n {
                int bits = (raw[q * 4] & 255) | ((raw[q * 4 + 1] & 255) << 8) | ((raw[q * 4 + 2] & 255) << 16) | ((raw[q * 4 + 3] & 255) << 24);
                r.d[q] = gg_f32(bits);
            }
        } else if t == 1 {
            for q in 0..n { r.d[q] = (float)gg_half((raw[q * 2] & 255) | ((raw[q * 2 + 1] & 255) << 8)); }
        } else if t == 30 {                                         // bfloat16: the high half of a float32
            for q in 0..n { r.d[q] = gg_f32(((raw[q * 2] & 255) << 16) | ((raw[q * 2 + 1] & 255) << 24)); }
        } else if t == 8 {
            for blk in 0..n / 32 {
                int o = blk * 34;
                double d = gg_half((raw[o] & 255) | ((raw[o + 1] & 255) << 8));
                for j in 0..32 {
                    int v = raw[o + 2 + j] & 255;
                    if v >= 128 { v = v - 256; }
                    r.d[blk * 32 + j] = (float)((double)v * d);
                }
            }
        } else {
            for blk in 0..n / 32 {
                int o = blk * 18;
                double d = gg_half((raw[o] & 255) | ((raw[o + 1] & 255) << 8));
                for j in 0..16 {
                    int v = raw[o + 2 + j] & 255;
                    r.d[blk * 32 + j] = (float)((double)((v & 15) - 8) * d);
                    r.d[blk * 32 + j + 16] = (float)((double)((v >> 4) - 8) * d);
                }
            }
        }
        return r;
    }

    // a weight matrix: Q8_0 and Q4_0 stay as int8 + scales (Q4_0 is widened to one byte per weight), the other types become float32
    QMat load_mat(self, String name, bool^ ok) {
        QMat m;
        m.quant = 0;
        m.f = Tensor32::zeros(1, 1);
        m.rows = 0;
        m.cols = 0;
        m.wq = 0;
        m.ws = 0;
        int i = self.find(name);
        if i < 0 { ok[0] = false; return m; }
        int t = self.t_type[i];
        if t != 2 && t != 8 {
            m.f = self.load_at(i, ok);
            m.rows = m.f.rows();
            m.cols = m.f.cols();
            return m;
        }
        int n = self.elements(i);
        int cols = self.t_dims[i * 4];
        if cols % 32 != 0 { ok[0] = false; return m; }
        int nb = n / 32;
        int bsz = 34;
        if t == 2 { bsz = 18; }
        i8^ wq = (i8^)Sys::mmap(n + 64);
        float^ ws = (float^)Sys::mmap(nb * 4 + 64);
        int fd = Sys::open_read(self.path.c());
        if fd < 0 { ok[0] = false; return m; }
        Sys::lseek(fd, self.data_start + self.t_off[i], 0);
        char buf[34816];                                            // 1024 blocks of the biggest kind
        int done = 0;
        while done < nb {
            int cnt = nb - done;
            if cnt > 1024 { cnt = 1024; }
            int want = cnt * bsz;
            int got = 0;
            while got < want {
                int r = Sys::read(fd, @buf + got, want - got);
                if r <= 0 { break; }
                got += r;
            }
            if got < want { Sys::close(fd); ok[0] = false; return m; }
            for blk in 0..cnt {
                int o = blk * bsz;
                ws[done + blk] = (float)gg_half((buf[o] & 255) | ((buf[o + 1] & 255) << 8));
                int base = (done + blk) * 32;
                if t == 8 {
                    for j in 0..32 {
                        int v = buf[o + 2 + j] & 255;
                        if v >= 128 { v = v - 256; }
                        wq[base + j] = (i8)v;
                    }
                } else {
                    for j in 0..16 {
                        int v = buf[o + 2 + j] & 255;
                        wq[base + j] = (i8)((v & 15) - 8);
                        wq[base + j + 16] = (i8)((v >> 4) - 8);
                    }
                }
            }
            done += cnt;
        }
        Sys::close(fd);
        m.quant = 1;
        m.rows = n / cols;
        m.cols = cols;
        m.wq = (int)wq;
        m.ws = (int)ws;
        ok[0] = true;
        return m;
    }

    // by name; a missing name or an unsupported type gives a 1 x 1 table with ok false
    Tensor32 load(self, String name, bool^ ok) {
        int i = self.find(name);
        if i < 0 { ok[0] = false; return Tensor32::zeros(1, 1); }
        return self.load_at(i, ok);
    }
}

// the four bytes of a float32 (as an int) as a float
float gg_f32(int bits) {
    int sign = (bits >> 31) & 1;
    int e = (bits >> 23) & 255;
    int m = bits & 8388607;
    double v = 0.0;
    if e == 0 { v = (double)m / 8388608.0 * Math::pow(2.0, -126.0); }
    else if e == 255 { v = 3.4e38; }
    else { v = (1.0 + (double)m / 8388608.0) * Math::pow(2.0, (double)(e - 127)); }
    if sign == 1 { v = 0.0 - v; }
    return (float)v;
}

struct Gg {
    static Result<GgufFile, Error> bad(String why) {
        return Result<GgufFile, Error>::Err(Error::make(ErrorKind::Parse, why));
    }

    static Result<GgufFile, Error> open(String path) {
        int fd = Sys::open_read(path.c());
        if fd < 0 { return Result<GgufFile, Error>::Err(Error::make(ErrorKind::Io, "cannot read " + path)); }
        int size = Sys::lseek(fd, 0, 2);
        Sys::lseek(fd, 0, 0);
        int want = size;
        if want > 67108864 { want = 67108864; }
        GgReader rd;
        rd.b = "";
        rd.p = 0;
        rd.bad = false;
        char buf[65536];
        int left = want;
        while left > 0 {
            int w = left;
            if w > 65536 { w = 65536; }
            int got = Sys::read(fd, @buf, w);
            if got <= 0 { break; }
            for q in 0..got { rd.b.push(buf[q]); }
            left -= got;
        }
        Sys::close(fd);
        String magic = rd.b.slice(0, 4) + "";
        if rd.b.len < 24 || magic != "GGUF" { return Gg::bad(path + " is not a GGUF file"); }
        rd.p = 4;
        GgufFile f;
        f.path = path + "";
        f.version = rd.u32();
        if f.version < 2 || f.version > 3 { return Gg::bad("GGUF version " + str(f.version) + " is not read (2 and 3 are)"); }
        int ntensors = rd.u64();
        int nkv = rd.u64();
        f.align = 32;
        f.keys = arr(nkv + 1);
        f.vals = arr(nkv + 1);
        f.tokens = arr(1);
        f.merges = arr(1);
        f.scores = arr(1);
        for i in 0..nkv {
            String key = rd.str();
            int ty = rd.u32();
            String val = "";
            if ty == 9 {
                int et = rd.u32();
                int cnt = rd.u64();
                bool keep_tok = key == "tokenizer.ggml.tokens";
                bool keep_mer = key == "tokenizer.ggml.merges";
                bool keep_sc = key == "tokenizer.ggml.scores";
                for j in 0..cnt {
                    if et == 8 {
                        String s = rd.str();
                        if keep_tok { f.tokens.push(s); }
                        if keep_mer { f.merges.push(s); }
                    } else if et == 0 || et == 1 || et == 7 { rd.u8(); }
                    else if et == 2 || et == 3 { rd.u8(); rd.u8(); }
                    else if et == 6 {
                        int bits = rd.u32();
                        if keep_sc { f.scores.push((double)gg_f32(bits)); }
                    }
                    else if et == 4 || et == 5 { rd.u32(); }
                    else { rd.u64(); }
                    if rd.bad { break; }
                }
                val = "[array of " + str(cnt) + "]";
            } else if ty == 8 { val = rd.str(); }
            else if ty == 0 || ty == 7 { val = str(rd.u8()); }
            else if ty == 1 { int v = rd.u8(); if v >= 128 { v -= 256; } val = str(v); }
            else if ty == 2 { val = str(rd.u8() | (rd.u8() << 8)); }
            else if ty == 3 { int v = rd.u8() | (rd.u8() << 8); if v >= 32768 { v -= 65536; } val = str(v); }
            else if ty == 4 { val = str(rd.u32()); }
            else if ty == 5 { int v = rd.u32(); if v >= 2147483648 { v -= 4294967296; } val = str(v); }
            else if ty == 6 { val = Json::num_text((double)gg_f32(rd.u32())); }
            else if ty == 10 || ty == 11 { val = str(rd.u64()); }
            else if ty == 12 { val = "[double]"; rd.u64(); }
            else { return Gg::bad("a metadata value of the type " + str(ty) + " is not known"); }
            if rd.bad { return Gg::bad("the header ends too early (a file over 64 MB of header?)"); }
            f.keys.push(key);
            f.vals.push(val);
            if key == "general.alignment" { f.align = val.to_int(); }
        }
        f.t_names = arr(ntensors + 1);
        f.t_type = arr(ntensors + 1);
        f.t_off = arr(ntensors + 1);
        f.t_dims = arr(ntensors * 4 + 1);
        f.t_nd = arr(ntensors + 1);
        for i in 0..ntensors {
            String nm = rd.str();
            int nd = rd.u32();
            if nd < 1 || nd > 4 { return Gg::bad("the tensor " + nm + " has " + str(nd) + " dimensions"); }
            for k in 0..4 {
                int dv = 1;
                if k < nd { dv = rd.u64(); }
                f.t_dims.push(dv);
            }
            f.t_names.push(nm);
            f.t_nd.push(nd);
            f.t_type.push(rd.u32());
            f.t_off.push(rd.u64());
            if rd.bad { return Gg::bad("the header ends too early"); }
        }
        f.data_start = (rd.p + f.align - 1) / f.align * f.align;
        return Result<GgufFile, Error>::Ok(f);
    }
}
