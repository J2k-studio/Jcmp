// neuron 0.7.0 -- tensors and small neural networks that train on the phone.   #import <neuron>   (needs jcmp 1.1.0.0; license: MPL-2.0)
// 0.2.0: Tensor::matmul_fast(o): float32 + NEON dot products + threads for big tables (see the fast way below)
//   Gpt m = Gpt::make(256, 64, 64, 4, 2, 1);   m.step(data, starts, lr, decay, clip);   m.write(prompt, n, temp, topk, seed)      // 0.7.0: a GPT that trains on the phone (bottom of this file)
//   Tensor a = Tensor::zeros(2, 3);   a.set(0, 1, 5.0);   Tensor c = a.matmul(b);   Tensor p = c.relu().softmax();
//   Network n = Network::make();   n.add(2, 8);   n.add(8, 1);                // layers of neurons: relu between them
//   n.fit(x, y, 3000, 0.1);   Tensor out = n.predict(x);   n.save("m.jw");   Network m = Network::load("m.jw");
// A Tensor is a table of rows x cols numbers (double); the methods return new Tensors. The file .jw is a text file (the weights).

#import <simd>
#import <cpu>
using cpu::thread;

// exp and tanh in about 15 multiplications (Math::exp and Math::tanh take 100 ns each): exp(x) = (exp(x / 64) by a polynomial of degree 6) ^ 64; the relative error is
// below 1e-4 for -30 < x < 30. tanh(x) = 1 - 2 / (exp(2x) + 1), with a series near 0 (no cancellation) and 1 beyond 9.
double nt_exp(double x) {
    if x < -60.0 { return 0.0; }
    if x > 60.0 { x = 60.0; }
    double y = x * 0.015625;
    double r = 1.0 + y * (1.0 + y * (0.5 + y * (0.16666666666666666 + y * (0.041666666666666664 + y * (0.008333333333333333 + y * 0.001388888888888889)))));
    r = r * r;
    r = r * r;
    r = r * r;
    r = r * r;
    r = r * r;
    r = r * r;
    return r;
}

double nt_tanh(double x) {
    if x > 9.0 { return 1.0; }
    if x < -9.0 { return -1.0; }
    double a = x;
    if a < 0.0 { a = 0.0 - a; }
    if a < 0.05 { return x * (1.0 - x * x * 0.3333333333333333); }
    double e = nt_exp(2.0 * a);
    double t = 1.0 - 2.0 / (e + 1.0);
    if x < 0.0 { return 0.0 - t; }
    return t;
}

// ---- the fast way to multiply (neuron 0.2.0): the numbers are packed as float32 in rows of a multiple of 8, B is turned over so that every
// result is a dot product of two rows (4 numbers at a time, no splat, two accumulators), and the rows of the result are shared among threads.
// bench/dot.jk measured: 1.8-2.1 GFLOPS on one core (the plain loop: 0.4), and about 3.5 times more with 4 threads.
float^ mm_a;                     // m rows of kp numbers
float^ mm_bt;                    // n rows of kp numbers (B turned over)
float^ mm_c;                     // m rows of n numbers
int mm_kp;
int mm_n;
int^ mm_range;                   // [2 * t] first row and [2 * t + 1] end row of the thread t

void mm_rows(void^ arg) {
    int id = (int)arg;
    float^ a = mm_a;
    float^ bt = mm_bt;
    float^ c = mm_c;
    int kp = mm_kp;
    int n = mm_n;
    for i in mm_range[2 * id]..mm_range[2 * id + 1] {
        for jj in 0..n {
            f32x4 s0 = {0.0, 0.0, 0.0, 0.0};
            f32x4 s1 = {0.0, 0.0, 0.0, 0.0};
            int k = 0;
            while k < kp {
                f32x4 a0 = f32x4::load(a, i * kp + k);
                f32x4 b0 = f32x4::load(bt, jj * kp + k);
                f32x4 a1 = f32x4::load(a, i * kp + k + 4);
                f32x4 b1 = f32x4::load(bt, jj * kp + k + 4);
                s0 = s0 + a0 * b0;
                s1 = s1 + a1 * b1;
                k += 8;
            }
            f32x4 s = s0 + s1;
            c[i * n + jj] = s.sum();
        }
    }
}

struct Tensor {
    int rows;
    int cols;
    double[] d;

    static Tensor zeros(int rows, int cols) {
        Tensor t;
        t.rows = rows;
        t.cols = cols;
        t.d = arr(rows * cols + 1);
        for i in 0..rows * cols { t.d.push(0.0); }
        return t;
    }
    double get(self, int r, int c) { return self.d[r * self.cols + c]; }
    void set(self, int r, int c, double v) { self.d[r * self.cols + c] = v; }

    Tensor matmul(self, Tensor o) {
        Tensor r = Tensor::zeros(self.rows, o.cols);
        for i in 0..self.rows {
            for k in 0..self.cols {
                double a = self.d[i * self.cols + k];
                for j in 0..o.cols { r.d[i * o.cols + j] += a * o.d[k * o.cols + j]; }
            }
        }
        return r;
    }
    // the same as matmul, much faster for big tables (pack to float32, dot products, threads); the numbers are float32 inside, so the last digits differ
    Tensor matmul_fast(self, Tensor o) {
        int m = self.rows;
        int k = self.cols;
        int n = o.cols;
        if m * k * n < 32768 { return self.matmul(o); }                // small: the plain loop is cheaper than the packing
        int kp = (k + 7) / 8 * 8;
        int sa = m * kp * 4 + 64;                                        // the buffers come from the system (mmap, zeroed): the compiler does not track them as owners
        int sb = n * kp * 4 + 64;
        int sc = m * n * 4 + 64;
        float^ pa = (float^)Sys::mmap(sa);
        float^ pbt = (float^)Sys::mmap(sb);
        float^ pc = (float^)Sys::mmap(sc);
        for i in 0..m { for kk in 0..kp { pa[i * kp + kk] = 0.0; if kk < k { pa[i * kp + kk] = (float)self.d[i * k + kk]; } } }
        for jj in 0..n { for kk in 0..kp { pbt[jj * kp + kk] = 0.0; if kk < k { pbt[jj * kp + kk] = (float)o.d[kk * n + jj]; } } }
        int threads = 4;
        if m < 16 { threads = 1; }
        mm_a = pa; mm_bt = pbt; mm_c = pc; mm_kp = kp; mm_n = n;
        int^ rng = (int^)Sys::mmap(4096);
        mm_range = rng;
        for t in 0..threads { rng[2 * t] = m * t / threads; rng[2 * t + 1] = m * (t + 1) / threads; }
        if threads == 1 { mm_rows((void^)0); }
        else {
            Thread[] ts = arr(4);
            for t in 0..threads { ts.push(create(mm_rows, (void^)t)); }
            for t in 0..threads { ts[t].join(); }
        }
        Sys::munmap((void^)rng, 4096);
        Tensor r = Tensor::zeros(m, n);
        for i in 0..m * n { r.d[i] = (double)pc[i]; }
        Sys::munmap((void^)pa, sa);
        Sys::munmap((void^)pbt, sb);
        Sys::munmap((void^)pc, sc);
        return r;
    }
    Tensor add(self, Tensor o) {                     // o may be one row: it is added to every row (the bias)
        Tensor r = Tensor::zeros(self.rows, self.cols);
        for i in 0..self.rows {
            for j in 0..self.cols {
                double b = o.d[j];
                if o.rows == self.rows { b = o.d[i * self.cols + j]; }
                r.d[i * self.cols + j] = self.d[i * self.cols + j] + b;
            }
        }
        return r;
    }
    Tensor transpose(self) {
        Tensor r = Tensor::zeros(self.cols, self.rows);
        for i in 0..self.rows { for j in 0..self.cols { r.d[j * self.rows + i] = self.d[i * self.cols + j]; } }
        return r;
    }
    Tensor relu(self) {
        Tensor r = Tensor::zeros(self.rows, self.cols);
        for i in 0..self.rows * self.cols { if self.d[i] > 0.0 { r.d[i] = self.d[i]; } }
        return r;
    }
    Tensor softmax(self) {                           // every row becomes numbers that sum to 1
        Tensor r = Tensor::zeros(self.rows, self.cols);
        for i in 0..self.rows {
            double m = self.d[i * self.cols];
            for j in 0..self.cols { if self.d[i * self.cols + j] > m { m = self.d[i * self.cols + j]; } }
            double s = 0.0;
            for j in 0..self.cols {
                double e = nt_exp(self.d[i * self.cols + j] - m);
                r.d[i * self.cols + j] = e;
                s += e;
            }
            for j in 0..self.cols { r.d[i * self.cols + j] = r.d[i * self.cols + j] / s; }
        }
        return r;
    }
}

// A layer of neurons: y = x @ w + b. forward() remembers x; backward() learns (plain gradient descent) and gives the gradient for the layer before.
struct Dense {
    Tensor w;
    Tensor b;
    Tensor x;

    static Dense make(int inputs, int outputs, int seed) {
        Dense l;
        l.w = Tensor::zeros(inputs, outputs);
        l.b = Tensor::zeros(1, outputs);
        int s = seed * 2654435761 + 12345;
        for i in 0..inputs * outputs {
            s = (s * 1103515245 + 12345) & 2147483647;
            l.w.d[i] = ((double)(s % 2000) / 1000.0 - 1.0) * Math::sqrt(2.0 / (double)inputs);
        }
        l.x = Tensor::zeros(1, 1);
        return l;
    }
    Tensor forward(self, Tensor x) {
        self.x = x;
        return x.matmul_fast(self.w).add(self.b);
    }
    Tensor backward(self, Tensor dy, double rate) {
        Tensor dx = dy.matmul_fast(self.w.transpose());
        Tensor dw = self.x.transpose().matmul_fast(dy);
        for i in 0..self.w.rows * self.w.cols { self.w.d[i] = self.w.d[i] - rate * dw.d[i]; }
        for j in 0..self.b.cols {
            double g = 0.0;
            for i in 0..dy.rows { g += dy.d[i * dy.cols + j]; }
            self.b.d[j] = self.b.d[j] - rate * g;
        }
        return dx;
    }
}

// A network of layers: every layer is Dense, with relu after all of them but the last. Trained by gradient descent on the mean squared error.
struct Network {
    Dense[] layers;
    int count;
    int seed;

    static Network make() {
        Network n;
        n.layers = arr(4);
        n.count = 0;
        n.seed = 1;
        return n;
    }
    void add(self, int inputs, int outputs) {
        self.seed += 1;
        self.layers.push(Dense::make(inputs, outputs, self.seed));
        self.count += 1;
    }
    Tensor predict(self, Tensor x) {
        Tensor h = x;
        for k in 0..self.count {
            h = self.layers[k].forward(h);
            if k < self.count - 1 { h = h.relu(); }
        }
        return h;
    }
    // one round over all the rows: returns the mean squared error before the step
    double step(self, Tensor x, Tensor y, double rate) {
        Tensor[] outs = arr(self.count + 1);
        Tensor h = x;
        for k in 0..self.count {
            h = self.layers[k].forward(h);
            outs.push(h);
            if k < self.count - 1 { h = h.relu(); }
        }
        Tensor o = outs[self.count - 1];
        Tensor g = Tensor::zeros(o.rows, o.cols);
        double loss = 0.0;
        int cells = o.rows * o.cols;
        for i in 0..cells {
            double d = o.d[i] - y.d[i];
            loss += d * d;
            g.d[i] = 2.0 * d / (double)cells;
        }
        int k2 = self.count - 1;
        while k2 >= 0 {
            Tensor gin = self.layers[k2].backward(g, rate);
            if k2 > 0 {
                Tensor pre = outs[k2 - 1];
                for i in 0..pre.rows * pre.cols { if pre.d[i] <= 0.0 { gin.d[i] = 0.0; } }
            }
            g = gin;
            k2 -= 1;
        }
        return loss / (double)cells;
    }
    double fit(self, Tensor x, Tensor y, int rounds, double rate) {
        double loss = 0.0;
        for e in 0..rounds { loss = self.step(x, y, rate); }
        return loss;
    }
    // the weights as text:  neuron-jw 1 / layers N / for each layer: inputs outputs and the numbers
    String text(self) {
        String t = "neuron-jw 1\nlayers " + str(self.count) + "\n";
        for k in 0..self.count {
            Dense l = self.layers[k];
            t = t + str(l.w.rows) + " " + str(l.w.cols) + "\n";
            for i in 0..l.w.rows * l.w.cols { t = t + str(l.w.d[i]) + " "; }
            t = t + "\n";
            for i in 0..l.b.cols { t = t + str(l.b.d[i]) + " "; }
            t = t + "\n";
        }
        return t;
    }
    bool save(self, String path) {
        Result<int, Error> r = Fs::write_text(path, self.text());
        return r.is_ok();
    }
    static Network load(String path) {
        Network n = Network::make();
        Result<String, Error> r = Fs::read_text(path);
        if !r.is_ok() { return n; }
        String[] ls = r.take().split("\n");
        if ls.len < 2 || ls[0] != "neuron-jw 1" { return n; }
        int count = ls[1].slice(7, ls[1].len).to_int();
        int at = 2;
        for k in 0..count {
            String[] dim = ls[at].split(" ");
            Dense l = Dense::make(dim[0].to_int(), dim[1].to_int(), 1);
            String[] wv = ls[at + 1].split(" ");
            for i in 0..l.w.rows * l.w.cols { l.w.d[i] = wv[i].to_double(); }
            String[] bv = ls[at + 2].split(" ");
            for i in 0..l.b.cols { l.b.d[i] = bv[i].to_double(); }
            n.layers.push(l);
            n.count += 1;
            at += 3;
        }
        return n;
    }
}

// ============================================================================================================================
// neuron 0.5.0: Tensor32 (float32, up to 4 dimensions) and Graph (autograd with a tape). The old Tensor / Network above stay as they are.
//   Graph g = Graph::make();
//   int w = g.param(Tensor32::random(2, 8, 1, 0.5));   int b = g.param(Tensor32::zeros(1, 8));      // parameters live as long as the graph
//   g.mark();                                                                                      // everything made after mark() is one step
//   for step in 0..1000 {
//       int x = g.input(xs);   int h = g.relu(g.add(g.matmul(x, w), b));   int loss = g.mse(h, ys);
//       g.backward(loss);   g.sgd(0.1);   g.clear();                                                // clear() throws the step away, keeps the parameters
//   }
// A node is an int (its number). g.value(n) is the Tensor32 of a node, g.grad(n) its gradient after backward.
// ============================================================================================================================

// c = a x b for small tables, n a multiple of 4: four columns of two rows at a time stay in registers while k runs (a function of its own with no calls, so
// that the compiler keeps every vector in a register)
void nt_mm_small(float^ ap, float^ bp, float^ cp, int m, int k, int n) {
    int i = 0;
    while i + 2 <= m {
        int j = 0;
        while j < n {
            f32x4 c0 = {0.0, 0.0, 0.0, 0.0};
            f32x4 c1 = {0.0, 0.0, 0.0, 0.0};
            for kk in 0..k {
                f32x4 bv = f32x4::load(bp, kk * n + j);
                float a0 = ap[i * k + kk];
                float a1 = ap[(i + 1) * k + kk];
                f32x4 av0 = {a0, a0, a0, a0};
                f32x4 av1 = {a1, a1, a1, a1};
                c0 = c0 + av0 * bv;
                c1 = c1 + av1 * bv;
            }
            c0.store(cp, i * n + j);
            c1.store(cp, (i + 1) * n + j);
            j += 4;
        }
        i += 2;
    }
    while i < m {
        int j = 0;
        while j < n {
            f32x4 c0 = {0.0, 0.0, 0.0, 0.0};
            for kk in 0..k {
                float a0 = ap[i * k + kk];
                f32x4 av0 = {a0, a0, a0, a0};
                c0 = c0 + av0 * f32x4::load(bp, kk * n + j);
            }
            c0.store(cp, i * n + j);
            j += 4;
        }
        i += 1;
    }
}

struct Tensor32 {
    int[] shape;                       // 1 to 4 numbers, the last one is the width of a row
    float[] d;

    static Tensor32 make(int[] shape) {
        Tensor32 t;
        t.shape = arr(shape.len + 1);                  // a copy: assigning the array would move it out of the caller's tensor
        int n = 1;
        for i in 0..shape.len { t.shape.push(shape[i]); n = n * shape[i]; }
        t.d = arr(n + 1);
        t.d.resize(n);                                  // n zeros in one block (a push for each one took twice as long)
        return t;
    }
    static Tensor32 zeros(int rows, int cols) {
        int[] s = arr(2);
        s.push(rows);
        s.push(cols);
        return Tensor32::make(s);
    }
    // numbers from -scale to scale (a small generator with the seed: the same seed gives the same numbers)
    static Tensor32 random(int rows, int cols, int seed, double scale) {
        Tensor32 t = Tensor32::zeros(rows, cols);
        int s = seed * 2654435761 + 12345;
        for i in 0..rows * cols {
            s = (s * 1103515245 + 12345) & 2147483647;
            t.d[i] = (float)(((double)(s % 2000) / 1000.0 - 1.0) * scale);
        }
        return t;
    }
    // from a flat list of numbers, row by row
    static Tensor32 from_list(int rows, int cols, double[] v) {
        Tensor32 t = Tensor32::zeros(rows, cols);
        for i in 0..rows * cols { t.d[i] = (float)v[i]; }
        return t;
    }
    int size(self) { return self.d.len; }
    int cols(self) { return self.shape[self.shape.len - 1]; }
    int rows(self) { return self.d.len / self.shape[self.shape.len - 1]; }
    double get(self, int r, int c) { return (double)self.d[r * self.cols() + c]; }
    void set(self, int r, int c, double v) { self.d[r * self.cols() + c] = (float)v; }
    // the rows idx[0], idx[1], ... as a new table (a mini-batch)
    Tensor32 gather(self, int[] idx) {
        int c = self.cols();
        Tensor32 r = Tensor32::zeros(idx.len, c);
        for i in 0..idx.len { for j in 0..c { r.d[i * c + j] = self.d[idx[i] * c + j]; } }
        return r;
    }
    Tensor32 copy(self) {
        Tensor32 t = Tensor32::make(self.shape);
        for i in 0..self.d.len { t.d[i] = self.d[i]; }
        return t;
    }
    // the same numbers with another shape (the product must stay the same; a copy)
    Tensor32 reshape(self, int[] shape) {
        Tensor32 t = Tensor32::make(shape);
        for i in 0..self.d.len { t.d[i] = self.d[i]; }
        return t;
    }

    // a + b: the same shape, or b is one row that is added to every row (the bias)
    Tensor32 add(self, Tensor32 o) {
        Tensor32 r = Tensor32::make(self.shape);
        int c = self.cols();
        int n = self.d.len;
        if o.d.len == n { for i in 0..n { r.d[i] = self.d[i] + o.d[i]; } }
        else { for i in 0..n { r.d[i] = self.d[i] + o.d[i % c]; } }
        return r;
    }
    Tensor32 mul(self, Tensor32 o) {
        Tensor32 r = Tensor32::make(self.shape);
        for i in 0..self.d.len { r.d[i] = self.d[i] * o.d[i]; }
        return r;
    }
    Tensor32 scale(self, double k) {
        Tensor32 r = Tensor32::make(self.shape);
        float kf = (float)k;
        for i in 0..self.d.len { r.d[i] = self.d[i] * kf; }
        return r;
    }
    Tensor32 transpose(self) {
        int m = self.rows();
        int n = self.cols();
        Tensor32 r = Tensor32::zeros(n, m);
        for i in 0..m { for j in 0..n { r.d[j * m + i] = self.d[i * n + j]; } }
        return r;
    }
    Tensor32 relu(self) {
        Tensor32 r = Tensor32::make(self.shape);
        for i in 0..self.d.len { if self.d[i] > 0.0 { r.d[i] = self.d[i]; } }
        return r;
    }
    Tensor32 softmax(self) {                           // every row becomes numbers that sum to 1
        Tensor32 r = Tensor32::make(self.shape);
        int c = self.cols();
        int m = self.rows();
        for i in 0..m {
            double mx = (double)self.d[i * c];
            for j in 0..c { if (double)self.d[i * c + j] > mx { mx = (double)self.d[i * c + j]; } }
            double s = 0.0;
            for j in 0..c {
                double e = nt_exp((double)self.d[i * c + j] - mx);
                r.d[i * c + j] = (float)e;
                s += e;
            }
            for j in 0..c { r.d[i * c + j] = (float)((double)r.d[i * c + j] / s); }
        }
        return r;
    }
    double sum(self) {
        double s = 0.0;
        for i in 0..self.d.len { s += (double)self.d[i]; }
        return s;
    }
    double mean(self) { return self.sum() / (double)self.d.len; }

    // a @ b. Small tables: three plain loops in the order i, k, j (the inner loop walks both rows). Big tables: packed, dot products, threads (as matmul_fast).
    Tensor32 matmul(self, Tensor32 o) {
        int m = self.rows();
        int k = self.cols();
        int n = o.cols();
        Tensor32 r = Tensor32::zeros(m, n);
        if m * k * n < 2500000 {
            if n % 4 == 0 {
                nt_mm_small(@self.d[0], @o.d[0], @r.d[0], m, k, n);
                return r;
            }
            for i in 0..m {
                for kk in 0..k {
                    float a = self.d[i * k + kk];
                    for j in 0..n { r.d[i * n + j] += a * o.d[kk * n + j]; }
                }
            }
            return r;
        }
        int kp = (k + 7) / 8 * 8;
        int sa = m * kp * 4 + 64;
        int sb = n * kp * 4 + 64;
        int sc = m * n * 4 + 64;
        float^ pa = (float^)Sys::mmap(sa);
        float^ pbt = (float^)Sys::mmap(sb);
        float^ pc = (float^)Sys::mmap(sc);
        for i in 0..m { for kk in 0..k { pa[i * kp + kk] = self.d[i * k + kk]; } }
        for jj in 0..n { for kk in 0..k { pbt[jj * kp + kk] = o.d[kk * n + jj]; } }
        int threads = 4;
        if m < 16 { threads = 1; }
        mm_a = pa; mm_bt = pbt; mm_c = pc; mm_kp = kp; mm_n = n;
        int^ rng = (int^)Sys::mmap(4096);
        mm_range = rng;
        for t in 0..threads { rng[2 * t] = m * t / threads; rng[2 * t + 1] = m * (t + 1) / threads; }
        if threads == 1 { mm_rows((void^)0); }
        else {
            Thread[] ts = arr(4);
            for t in 0..threads { ts.push(create(mm_rows, (void^)t)); }
            for t in 0..threads { ts[t].join(); }
        }
        Sys::munmap((void^)rng, 4096);
        for i in 0..m * n { r.d[i] = pc[i]; }
        Sys::munmap((void^)pa, sa);
        Sys::munmap((void^)pbt, sb);
        Sys::munmap((void^)pc, sc);
        return r;
    }
}

// ---- attention kernels (dh = the width of a head, a multiple of 4): four numbers at a time, with no calls but the sum of four lanes
// pr[(h * t + i) * t + j] = (q_i . k_j) * sc for j <= i, in every head
void nt_att_scores(float^ q, float^ k, float^ pr, int t, int w, int heads, float sc) {
    int dh = w / heads;
    for h in 0..heads {
        for i in 0..t {
            for j in 0..i + 1 {
                f32x4 acc = {0.0, 0.0, 0.0, 0.0};
                int d = 0;
                while d < dh {
                    acc = acc + f32x4::load(q, i * w + h * dh + d) * f32x4::load(k, j * w + h * dh + d);
                    d += 4;
                }
                pr[(h * t + i) * t + j] = acc.sum() * sc;
            }
        }
    }
}
// out_i += p_ij * v_j (the probabilities pr are ready)
void nt_att_out(float^ pr, float^ v, float^ out, int t, int w, int heads) {
    int dh = w / heads;
    for h in 0..heads {
        for i in 0..t {
            for j in 0..i + 1 {
                float p = pr[(h * t + i) * t + j];
                f32x4 pv = {p, p, p, p};
                int d = 0;
                while d < dh {
                    int o = i * w + h * dh + d;
                    f32x4 r = f32x4::load(out, o) + pv * f32x4::load(v, j * w + h * dh + d);
                    r.store(out, o);
                    d += 4;
                }
            }
        }
    }
}
// the gradients of q, k and v from the gradient dy of the output: dp_j = dy_i . v_j, ds_j = p_j (dp_j - sum p dp) * sc, dv_j += p_j dy_i, dq_i += ds_j k_j, dk_j += ds_j q_i
// (dpb: room for t numbers). The pointers are in the globals nt_ab_*: a function with more than 8 parameters is not safe
float^ nt_ab_q;
float^ nt_ab_k;
float^ nt_ab_v;
float^ nt_ab_pr;
float^ nt_ab_dy;
float^ nt_ab_dq;
float^ nt_ab_dk;
float^ nt_ab_dv;
float^ nt_ab_dpb;
void nt_att_back(int t, int w, int heads, float sc) {
    float^ q = nt_ab_q;
    float^ k = nt_ab_k;
    float^ v = nt_ab_v;
    float^ pr = nt_ab_pr;
    float^ dy = nt_ab_dy;
    float^ dq = nt_ab_dq;
    float^ dk = nt_ab_dk;
    float^ dv = nt_ab_dv;
    float^ dpb = nt_ab_dpb;
    int dh = w / heads;
    for h in 0..heads {
        for i in 0..t {
            float dot = 0.0;
            for j in 0..i + 1 {
                f32x4 acc = {0.0, 0.0, 0.0, 0.0};
                int d = 0;
                while d < dh {
                    acc = acc + f32x4::load(dy, i * w + h * dh + d) * f32x4::load(v, j * w + h * dh + d);
                    d += 4;
                }
                float dp = acc.sum();
                dpb[j] = dp;
                dot += pr[(h * t + i) * t + j] * dp;
            }
            for j in 0..i + 1 {
                float p = pr[(h * t + i) * t + j];
                float ds = p * (dpb[j] - dot) * sc;
                f32x4 pv = {p, p, p, p};
                f32x4 dsv = {ds, ds, ds, ds};
                int d = 0;
                while d < dh {
                    int oi = i * w + h * dh + d;
                    int oj = j * w + h * dh + d;
                    f32x4 g = f32x4::load(dy, oi);
                    f32x4 a1 = f32x4::load(dv, oj) + pv * g;
                    a1.store(dv, oj);
                    f32x4 a2 = f32x4::load(dq, oi) + dsv * f32x4::load(k, oj);
                    a2.store(dq, oi);
                    f32x4 a3 = f32x4::load(dk, oj) + dsv * f32x4::load(q, oi);
                    a3.store(dk, oj);
                    d += 4;
                }
            }
        }
    }
}

// operations of the tape
int OP_INPUT() { return 0; }
int OP_PARAM() { return 1; }
int OP_MATMUL() { return 2; }
int OP_ADD() { return 3; }
int OP_MUL() { return 4; }
int OP_RELU() { return 5; }
int OP_TANH() { return 6; }
int OP_SIGMOID() { return 7; }
int OP_MSE() { return 8; }
int OP_SOFTMAX_CE() { return 9; }
int OP_EMBED() { return 10; }
int OP_GELU() { return 11; }
int OP_SILU() { return 12; }
int OP_LAYER_NORM() { return 13; }
int OP_RMS_NORM() { return 14; }
int OP_ATTENTION() { return 15; }
int OP_CONV2D() { return 16; }
int OP_MAXPOOL() { return 17; }

// the two parameters of a layer (node numbers of the graph that made it)
struct Linear {
    int w;
    int b;
}

struct Graph {
    Tensor32[] val;                    // the value of every node
    Tensor32[] grad;                   // its gradient (zeros until backward)
    int[] op;
    int[] pa;                          // the first parent (a node number, -1 for none)
    int[] pb;
    int[] pc;                          // the third parent (attention), -1 for none
    int[] iarg;                        // a number of the node (attention: the number of heads)
    int[] aux;                         // whole numbers of the nodes (class numbers, embedding ids), one run per node
    int[] aux_off;                     // where the run of a node starts in aux
    int aux_keep;                      // the length of aux at mark()
    Tensor32[] target;                 // the target table of an mse node, the probabilities of softmax_ce / attention, the normalised x of a norm
    Tensor32[] extra;                  // a second table of a node (the 1/sigma of every row of a norm)
    int count;                         // the nodes now
    int keep;                          // the nodes before mark(): the parameters
    Tensor32[] m;                      // AdamW: the first and second moments of every parameter (made at the first adamw call)
    Tensor32[] v;
    Tensor32[] acc;                    // the sum of the gradients of several sequences (a batch), one table per node (made by acc_add)
    int steps;                         // AdamW steps done
    double b1t;                        // beta1 ^ steps
    double b2t;

    static Graph make() {
        Graph g;
        g.val = arr(64);
        g.grad = arr(64);
        g.op = arr(64);
        g.pa = arr(64);
        g.pb = arr(64);
        g.pc = arr(64);
        g.iarg = arr(64);
        g.aux = arr(64);
        g.aux_off = arr(64);
        g.aux_keep = 0;
        g.target = arr(64);
        g.extra = arr(64);
        g.count = 0;
        g.keep = 0;
        g.m = arr(4);
        g.v = arr(4);
        g.acc = arr(4);
        g.steps = 0;
        g.b1t = 1.0;
        g.b2t = 1.0;
        return g;
    }
    int node(self, int op, int a, int b, Tensor32 v) {
        self.val.push(v);
        self.grad.push(Tensor32::zeros(1, 1));
        self.op.push(op);
        self.pa.push(a);
        self.pb.push(b);
        self.pc.push(-1);
        self.iarg.push(0);
        self.aux_off.push(self.aux.len);
        self.target.push(Tensor32::zeros(1, 1));
        self.extra.push(Tensor32::zeros(1, 1));
        self.count += 1;
        return self.count - 1;
    }
    int input(self, Tensor32 t) { return self.node(OP_INPUT(), -1, -1, t); }
    int param(self, Tensor32 t) { return self.node(OP_PARAM(), -1, -1, t); }
    // the nodes made so far are the parameters; clear() goes back to this point
    void mark(self) { self.keep = self.count; self.aux_keep = self.aux.len; }
    void clear(self) {
        while self.count > self.keep {
            Tensor32 gone = self.val.pop();
            Tensor32 gone2 = self.grad.pop();
            self.op.pop();
            self.pa.pop();
            self.pb.pop();
            Tensor32 gone3 = self.target.pop();
            Tensor32 gone4 = self.extra.pop();
            self.pc.pop();
            self.iarg.pop();
            self.aux_off.pop();
            self.count -= 1;
        }
        while self.aux.len > self.aux_keep { self.aux.pop(); }
    }
    Tensor32 value(self, int n) { return self.val[n]; }
    Tensor32 gradient(self, int n) { return self.grad[n]; }

    int matmul(self, int a, int b) { return self.node(OP_MATMUL(), a, b, self.val[a].matmul(self.val[b])); }
    int add(self, int a, int b) { return self.node(OP_ADD(), a, b, self.val[a].add(self.val[b])); }
    int mul(self, int a, int b) { return self.node(OP_MUL(), a, b, self.val[a].mul(self.val[b])); }
    int relu(self, int a) { return self.node(OP_RELU(), a, -1, self.val[a].relu()); }
    int tanh(self, int a) {
        Tensor32 r = Tensor32::make(self.val[a].shape);
        for i in 0..r.d.len { r.d[i] = (float)nt_tanh((double)self.val[a].d[i]); }
        return self.node(OP_TANH(), a, -1, r);
    }
    int sigmoid(self, int a) {
        Tensor32 r = Tensor32::make(self.val[a].shape);
        for i in 0..r.d.len { r.d[i] = (float)(1.0 / (1.0 + nt_exp(0.0 - (double)self.val[a].d[i]))); }
        return self.node(OP_SIGMOID(), a, -1, r);
    }

    // rows of a table of vectors (token numbers -> vectors): ids has one number per row of the result; the table is a parameter of shape vocab x width
    int embed(self, int table, int[] ids) {
        int w = self.val[table].cols();
        Tensor32 r = Tensor32::zeros(ids.len, w);
        for i in 0..ids.len { for j in 0..w { r.d[i * w + j] = self.val[table].d[ids[i] * w + j]; } }
        int n = self.node(OP_EMBED(), table, -1, r);
        for i in 0..ids.len { self.aux.push(ids[i]); }
        self.iarg[n] = ids.len;
        return n;
    }
    // GELU (the tanh form) and SiLU (x times sigmoid x)
    int gelu(self, int a) {
        Tensor32 r = Tensor32::make(self.val[a].shape);
        for i in 0..r.d.len {
            double x = (double)self.val[a].d[i];
            r.d[i] = (float)(0.5 * x * (1.0 + nt_tanh(0.7978845608 * (x + 0.044715 * x * x * x))));
        }
        return self.node(OP_GELU(), a, -1, r);
    }
    int silu(self, int a) {
        Tensor32 r = Tensor32::make(self.val[a].shape);
        for i in 0..r.d.len {
            double x = (double)self.val[a].d[i];
            r.d[i] = (float)(x / (1.0 + nt_exp(0.0 - x)));
        }
        return self.node(OP_SILU(), a, -1, r);
    }
    // every row: (x - mean) / sqrt(variance + 0.00001), then times gain and plus bias (gain and bias: one row each, as parameters)
    int layer_norm(self, int a, int gain, int bias) {
        int c = self.val[a].cols();
        int m = self.val[a].rows();
        Tensor32 y = Tensor32::make(self.val[a].shape);
        Tensor32 xh = Tensor32::make(self.val[a].shape);
        Tensor32 inv = Tensor32::zeros(m, 1);
        for i in 0..m {
            double mu = 0.0;
            for j in 0..c { mu += (double)self.val[a].d[i * c + j]; }
            mu = mu / (double)c;
            double var = 0.0;
            for j in 0..c { double e = (double)self.val[a].d[i * c + j] - mu; var += e * e; }
            var = var / (double)c;
            double iv = 1.0 / Math::sqrt(var + 0.00001);
            inv.d[i] = (float)iv;
            for j in 0..c {
                double h = ((double)self.val[a].d[i * c + j] - mu) * iv;
                xh.d[i * c + j] = (float)h;
                y.d[i * c + j] = (float)(h * (double)self.val[gain].d[j] + (double)self.val[bias].d[j]);
            }
        }
        int n = self.node(OP_LAYER_NORM(), a, gain, y);
        self.pc[n] = bias;
        self.target[n] = xh;
        self.extra[n] = inv;
        return n;
    }
    // every row: x / sqrt(mean of squares + 0.00001), times gain (the norm of the Llama models: no mean, no bias)
    int rms_norm(self, int a, int gain) {
        int c = self.val[a].cols();
        int m = self.val[a].rows();
        Tensor32 y = Tensor32::make(self.val[a].shape);
        Tensor32 xh = Tensor32::make(self.val[a].shape);
        Tensor32 inv = Tensor32::zeros(m, 1);
        for i in 0..m {
            double ms = 0.0;
            for j in 0..c { double e = (double)self.val[a].d[i * c + j]; ms += e * e; }
            ms = ms / (double)c;
            double iv = 1.0 / Math::sqrt(ms + 0.00001);
            inv.d[i] = (float)iv;
            for j in 0..c {
                double h = (double)self.val[a].d[i * c + j] * iv;
                xh.d[i * c + j] = (float)h;
                y.d[i * c + j] = (float)(h * (double)self.val[gain].d[j]);
            }
        }
        int n = self.node(OP_RMS_NORM(), a, gain, y);
        self.target[n] = xh;
        self.extra[n] = inv;
        return n;
    }
    // causal self-attention of one sequence: q, k, v have one row per position and the width is split into `heads` equal parts;
    // position i looks at the positions 0..i only: softmax(q.k / sqrt(width of a head)) @ v
    int attention(self, int q, int k, int v, int heads) {
        int t = self.val[q].rows();
        int w = self.val[q].cols();
        int dh = w / heads;
        double sc = 1.0 / Math::sqrt((double)dh);
        Tensor32 out = Tensor32::zeros(t, w);
        Tensor32 pr = Tensor32::zeros(heads * t, t);
        if dh % 4 == 0 {
            nt_att_scores(@self.val[q].d[0], @self.val[k].d[0], @pr.d[0], t, w, heads, (float)sc);
            for hi in 0..heads * t {                                     // the softmax of every row, over the places 0 .. i
                int row = hi % t;
                float mx = pr.d[hi * t];
                for j in 1..row + 1 { if pr.d[hi * t + j] > mx { mx = pr.d[hi * t + j]; } }
                double z = 0.0;
                for j in 0..row + 1 {
                    double e = nt_exp((double)pr.d[hi * t + j] - (double)mx);
                    pr.d[hi * t + j] = (float)e;
                    z += e;
                }
                float iz = (float)(1.0 / z);
                for j in 0..row + 1 { pr.d[hi * t + j] = pr.d[hi * t + j] * iz; }
            }
            nt_att_out(@pr.d[0], @self.val[v].d[0], @out.d[0], t, w, heads);
            int fast = self.node(OP_ATTENTION(), q, k, out);
            self.pc[fast] = v;
            self.iarg[fast] = heads;
            self.target[fast] = pr;
            return fast;
        }
        for h in 0..heads {
            for i in 0..t {
                double mx = -1.0e30;
                for j in 0..i + 1 {
                    double s = 0.0;
                    for d in 0..dh { s += (double)self.val[q].d[i * w + h * dh + d] * (double)self.val[k].d[j * w + h * dh + d]; }
                    s = s * sc;
                    pr.d[(h * t + i) * t + j] = (float)s;
                    if s > mx { mx = s; }
                }
                double z = 0.0;
                for j in 0..i + 1 {
                    double e = nt_exp((double)pr.d[(h * t + i) * t + j] - mx);
                    pr.d[(h * t + i) * t + j] = (float)e;
                    z += e;
                }
                for j in 0..i + 1 {
                    double p = (double)pr.d[(h * t + i) * t + j] / z;
                    pr.d[(h * t + i) * t + j] = (float)p;
                    for d in 0..dh { out.d[i * w + h * dh + d] += (float)(p * (double)self.val[v].d[j * w + h * dh + d]); }
                }
            }
        }
        int n = self.node(OP_ATTENTION(), q, k, out);
        self.pc[n] = v;
        self.iarg[n] = heads;
        self.target[n] = pr;
        return n;
    }

    // a convolution over images: x has one image per row, stored as channels x height x width (c_in * h * w numbers); w is a parameter of c_out rows of
    // c_in * k * k numbers; b a parameter of one row of c_out numbers. Square window k, stride, zero padding. The result has c_out * ho * wo numbers per row
    // with ho = (h + 2 pad - k) / stride + 1 (the same for wo).
    int conv2d(self, int x, int w, int b, int c_in, int h, int wd, int c_out, int k, int stride, int pad) {
        int ho = (h + 2 * pad - k) / stride + 1;
        int wo = (wd + 2 * pad - k) / stride + 1;
        int nimg = self.val[x].rows();
        Tensor32 r = Tensor32::zeros(nimg, c_out * ho * wo);
        int inw = c_in * h * wd;
        int outw = c_out * ho * wo;
        for n in 0..nimg {
            for co in 0..c_out {
                for oy in 0..ho {
                    for ox in 0..wo {
                        double s = (double)self.val[b].d[co];
                        for ci in 0..c_in {
                            for ky in 0..k {
                                int iy = oy * stride - pad + ky;
                                if iy < 0 || iy >= h { continue; }
                                for kx in 0..k {
                                    int ix = ox * stride - pad + kx;
                                    if ix < 0 || ix >= wd { continue; }
                                    s += (double)self.val[x].d[n * inw + (ci * h + iy) * wd + ix] * (double)self.val[w].d[co * c_in * k * k + (ci * k + ky) * k + kx];
                                }
                            }
                        }
                        r.d[n * outw + (co * ho + oy) * wo + ox] = (float)s;
                    }
                }
            }
        }
        int node = self.node(OP_CONV2D(), x, w, r);
        self.pc[node] = b;
        self.aux.push(c_in); self.aux.push(h); self.aux.push(wd); self.aux.push(c_out); self.aux.push(k); self.aux.push(stride); self.aux.push(pad);
        return node;
    }
    // the biggest number of every k x k square (stride k) of every channel: c channels of h x wd per row; h and wd should be multiples of k
    int maxpool(self, int x, int c, int h, int wd, int k) {
        int ho = h / k;
        int wo = wd / k;
        int nimg = self.val[x].rows();
        int inw = c * h * wd;
        int outw = c * ho * wo;
        Tensor32 r = Tensor32::zeros(nimg, outw);
        int node = self.node(OP_MAXPOOL(), x, -1, r);
        self.aux.push(c); self.aux.push(h); self.aux.push(wd); self.aux.push(k);
        for n in 0..nimg {
            for ch in 0..c {
                for oy in 0..ho {
                    for ox in 0..wo {
                        int best = n * inw + (ch * h + oy * k) * wd + ox * k;
                        for ky in 0..k {
                            for kx in 0..k {
                                int at = n * inw + (ch * h + oy * k + ky) * wd + ox * k + kx;
                                if self.val[x].d[at] > self.val[x].d[best] { best = at; }
                            }
                        }
                        r.d[n * outw + (ch * ho + oy) * wo + ox] = self.val[x].d[best];
                        self.aux.push(best);
                    }
                }
            }
        }
        return node;
    }

    // the mean of the squares of (a - target): one number
    int mse(self, int a, Tensor32 target) {
        double s = 0.0;
        for i in 0..target.d.len {
            double e = (double)self.val[a].d[i] - (double)target.d[i];
            s += e * e;
        }
        Tensor32 r = Tensor32::zeros(1, 1);
        r.d[0] = (float)(s / (double)target.d.len);
        int n = self.node(OP_MSE(), a, -1, r);
        self.target[n] = target;
        return n;
    }
    // softmax of every row of a (the scores), then the mean of -log(probability of the right class); classes: one class number per row
    int softmax_ce(self, int a, int[] classes) {
        Tensor32 p = self.val[a].softmax();
        int c = p.cols();
        double s = 0.0;
        for i in 0..classes.len { s = s - Math::log((double)p.d[i * c + classes[i]] + 0.0000000001); }
        Tensor32 r = Tensor32::zeros(1, 1);
        r.d[0] = (float)(s / (double)classes.len);
        int n = self.node(OP_SOFTMAX_CE(), a, -1, r);
        for i in 0..classes.len { self.aux.push(classes[i]); }
        self.iarg[n] = classes.len;
        self.target[n] = p;
        return n;
    }

    // adds g to the gradient of node n
    void give(self, int n, Tensor32 g) {
        if self.grad[n].d.len != g.d.len { self.grad[n] = g.copy(); return; }
        for i in 0..g.d.len { self.grad[n].d[i] += g.d[i]; }
    }
    // the gradients of everything the node `loss` depends on (loss: a node with one number); the gradients of an earlier step are forgotten
    void backward(self, int loss) {
        for i in 0..self.count { self.grad[i] = Tensor32::zeros(1, 1); }
        Tensor32 one = Tensor32::zeros(1, 1);
        one.d[0] = 1.0;
        self.grad[loss] = one;
        int i = loss;
        while i >= 0 {
            if self.grad[i].d.len == self.val[i].d.len || self.op[i] == OP_MSE() || self.op[i] == OP_SOFTMAX_CE() {
                int o = self.op[i];
                int a = self.pa[i];
                int b = self.pb[i];
                Tensor32 dy = self.grad[i];
                if o == OP_MATMUL() {
                    self.give(a, dy.matmul(self.val[b].transpose()));
                    self.give(b, self.val[a].transpose().matmul(dy));
                } else if o == OP_ADD() {
                    self.give(a, dy);
                    if self.val[b].d.len == dy.d.len { self.give(b, dy); }
                    else {                                                 // the bias: the sum of the rows
                        int c = dy.cols();
                        Tensor32 gb = Tensor32::zeros(1, c);
                        for r in 0..dy.rows() { for j in 0..c { gb.d[j] += dy.d[r * c + j]; } }
                        self.give(b, gb);
                    }
                } else if o == OP_MUL() {
                    self.give(a, dy.mul(self.val[b]));
                    self.give(b, dy.mul(self.val[a]));
                } else if o == OP_RELU() {
                    Tensor32 g = Tensor32::make(dy.shape);
                    for k in 0..g.d.len { if self.val[a].d[k] > 0.0 { g.d[k] = dy.d[k]; } }
                    self.give(a, g);
                } else if o == OP_TANH() {
                    Tensor32 g = Tensor32::make(dy.shape);
                    for k in 0..g.d.len { g.d[k] = dy.d[k] * (1.0 - self.val[i].d[k] * self.val[i].d[k]); }
                    self.give(a, g);
                } else if o == OP_SIGMOID() {
                    Tensor32 g = Tensor32::make(dy.shape);
                    for k in 0..g.d.len { g.d[k] = dy.d[k] * self.val[i].d[k] * (1.0 - self.val[i].d[k]); }
                    self.give(a, g);
                } else if o == OP_MSE() {
                    Tensor32 g = Tensor32::make(self.val[a].shape);
                    float k2 = (float)(2.0 * (double)dy.d[0] / (double)g.d.len);
                    for k in 0..g.d.len { g.d[k] = (self.val[a].d[k] - self.target[i].d[k]) * k2; }
                    self.give(a, g);
                } else if o == OP_EMBED() {
                    int w = self.val[a].cols();
                    Tensor32 g = Tensor32::zeros(self.val[a].rows(), w);
                    for r in 0..self.iarg[i] {
                        int id = self.aux[self.aux_off[i] + r];
                        for j in 0..w { g.d[id * w + j] += dy.d[r * w + j]; }
                    }
                    self.give(a, g);
                } else if o == OP_GELU() {
                    Tensor32 g = Tensor32::make(dy.shape);
                    for k in 0..g.d.len {
                        double x = (double)self.val[a].d[k];
                        double u = 0.7978845608 * (x + 0.044715 * x * x * x);
                        double th = nt_tanh(u);
                        double du = 0.7978845608 * (1.0 + 3.0 * 0.044715 * x * x);
                        g.d[k] = (float)((double)dy.d[k] * (0.5 * (1.0 + th) + 0.5 * x * (1.0 - th * th) * du));
                    }
                    self.give(a, g);
                } else if o == OP_SILU() {
                    Tensor32 g = Tensor32::make(dy.shape);
                    for k in 0..g.d.len {
                        double x = (double)self.val[a].d[k];
                        double sg = 1.0 / (1.0 + nt_exp(0.0 - x));
                        g.d[k] = (float)((double)dy.d[k] * sg * (1.0 + x * (1.0 - sg)));
                    }
                    self.give(a, g);
                } else if o == OP_LAYER_NORM() || o == OP_RMS_NORM() {
                    int c = dy.cols();
                    int m = dy.rows();
                    Tensor32 dx = Tensor32::make(dy.shape);
                    Tensor32 dg = Tensor32::zeros(1, c);
                    Tensor32 db = Tensor32::zeros(1, c);
                    for r in 0..m {
                        double s1 = 0.0;
                        double s2 = 0.0;
                        for j in 0..c {
                            double dyj = (double)dy.d[r * c + j];
                            double xh = (double)self.target[i].d[r * c + j];
                            double dxh = dyj * (double)self.val[b].d[j];
                            s1 += dxh;
                            s2 += dxh * xh;
                            dg.d[j] += (float)(dyj * xh);
                            db.d[j] += (float)dyj;
                        }
                        double iv = (double)self.extra[i].d[r];
                        for j in 0..c {
                            double xh = (double)self.target[i].d[r * c + j];
                            double dxh = (double)dy.d[r * c + j] * (double)self.val[b].d[j];
                            if o == OP_LAYER_NORM() { dx.d[r * c + j] = (float)(iv * (dxh - s1 / (double)c - xh * s2 / (double)c)); }
                            else { dx.d[r * c + j] = (float)(iv * (dxh - xh * s2 / (double)c)); }
                        }
                    }
                    self.give(a, dx);
                    self.give(b, dg);
                    if o == OP_LAYER_NORM() { self.give(self.pc[i], db); }
                } else if o == OP_ATTENTION() {
                    int vv = self.pc[i];
                    int t = self.val[a].rows();
                    int w = self.val[a].cols();
                    int heads = self.iarg[i];
                    int dh = w / heads;
                    double sc = 1.0 / Math::sqrt((double)dh);
                    Tensor32 dq = Tensor32::zeros(t, w);
                    Tensor32 dk = Tensor32::zeros(t, w);
                    Tensor32 dv = Tensor32::zeros(t, w);
                    if dh % 4 == 0 {
                        Tensor32 dpb = Tensor32::zeros(1, t);
                        nt_ab_q = @self.val[a].d[0]; nt_ab_k = @self.val[b].d[0]; nt_ab_v = @self.val[vv].d[0]; nt_ab_pr = @self.target[i].d[0];
                        nt_ab_dy = @dy.d[0]; nt_ab_dq = @dq.d[0]; nt_ab_dk = @dk.d[0]; nt_ab_dv = @dv.d[0]; nt_ab_dpb = @dpb.d[0];
                        nt_att_back(t, w, heads, (float)sc);
                    } else {
                    for h in 0..heads {
                        for r in 0..t {
                            double dot = 0.0;                                   // sum over j of P_rj * dP_rj
                            for j in 0..r + 1 {
                                double dp = 0.0;
                                for d in 0..dh { dp += (double)dy.d[r * w + h * dh + d] * (double)self.val[vv].d[j * w + h * dh + d]; }
                                dot += (double)self.target[i].d[(h * t + r) * t + j] * dp;
                            }
                            for j in 0..r + 1 {
                                double p = (double)self.target[i].d[(h * t + r) * t + j];
                                double dp = 0.0;
                                for d in 0..dh { dp += (double)dy.d[r * w + h * dh + d] * (double)self.val[vv].d[j * w + h * dh + d]; }
                                double ds = p * (dp - dot) * sc;
                                for d in 0..dh {
                                    dv.d[j * w + h * dh + d] += (float)(p * (double)dy.d[r * w + h * dh + d]);
                                    dq.d[r * w + h * dh + d] += (float)(ds * (double)self.val[b].d[j * w + h * dh + d]);
                                    dk.d[j * w + h * dh + d] += (float)(ds * (double)self.val[a].d[r * w + h * dh + d]);
                                }
                            }
                        }
                    }
                    }
                    self.give(a, dq);
                    self.give(b, dk);
                    self.give(vv, dv);
                } else if o == OP_CONV2D() {
                    int bb = self.pc[i];
                    int ax = self.aux_off[i];
                    int c_in = self.aux[ax]; int h = self.aux[ax + 1]; int wd = self.aux[ax + 2]; int c_out = self.aux[ax + 3];
                    int k = self.aux[ax + 4]; int stride = self.aux[ax + 5]; int pad = self.aux[ax + 6];
                    int ho = (h + 2 * pad - k) / stride + 1;
                    int wo = (wd + 2 * pad - k) / stride + 1;
                    int nimg = self.val[a].rows();
                    int inw = c_in * h * wd;
                    int outw = c_out * ho * wo;
                    Tensor32 dx = Tensor32::zeros(nimg, inw);
                    Tensor32 dw = Tensor32::zeros(c_out, c_in * k * k);
                    Tensor32 db = Tensor32::zeros(1, c_out);
                    for n in 0..nimg {
                        for co in 0..c_out {
                            for oy in 0..ho {
                                for ox in 0..wo {
                                    float g = dy.d[n * outw + (co * ho + oy) * wo + ox];
                                    db.d[co] += g;
                                    for ci in 0..c_in {
                                        for ky in 0..k {
                                            int iy = oy * stride - pad + ky;
                                            if iy < 0 || iy >= h { continue; }
                                            for kx in 0..k {
                                                int ix = ox * stride - pad + kx;
                                                if ix < 0 || ix >= wd { continue; }
                                                int xi = n * inw + (ci * h + iy) * wd + ix;
                                                int wi = co * c_in * k * k + (ci * k + ky) * k + kx;
                                                dw.d[wi] += g * self.val[a].d[xi];
                                                dx.d[xi] += g * self.val[b].d[wi];
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    self.give(a, dx);
                    self.give(b, dw);
                    self.give(bb, db);
                } else if o == OP_MAXPOOL() {
                    int ax = self.aux_off[i];
                    int c = self.aux[ax]; int h = self.aux[ax + 1]; int wd = self.aux[ax + 2];
                    Tensor32 dx = Tensor32::zeros(self.val[a].rows(), c * h * wd);
                    for q in 0..dy.d.len { dx.d[self.aux[ax + 4 + q]] += dy.d[q]; }
                    self.give(a, dx);
                } else if o == OP_SOFTMAX_CE() {
                    Tensor32 g = self.target[i].copy();                    // the probabilities
                    int c = g.cols();
                    int rows = self.iarg[i];
                    for r in 0..rows { g.d[r * c + self.aux[self.aux_off[i] + r]] -= 1.0; }
                    float k3 = (float)((double)dy.d[0] / (double)rows);
                    for k in 0..g.d.len { g.d[k] = g.d[k] * k3; }
                    self.give(a, g);
                }
            }
            i -= 1;
        }
    }

    // a layer: y = x @ w + b; the two parameters are made now (call it before mark())
    Linear linear(self, int inputs, int outputs, int seed) {
        Linear l;
        l.w = self.param(Tensor32::random(inputs, outputs, seed, Math::sqrt(3.0 / (double)inputs)));
        l.b = self.param(Tensor32::zeros(1, outputs));
        return l;
    }
    int apply(self, Linear l, int x) { return self.add(self.matmul(x, l.w), l.b); }

    // the size of the gradient of all parameters (the square root of the sum of squares); when it is above max_norm all gradients are made smaller so that it is max_norm
    double clip(self, double max_norm) {
        double sq = 0.0;
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() && self.grad[n].d.len == self.val[n].d.len {
                for k in 0..self.grad[n].d.len { sq += (double)self.grad[n].d[k] * (double)self.grad[n].d[k]; }
            }
        }
        double norm = Math::sqrt(sq);
        if norm > max_norm && norm > 0.0 {
            float f = (float)(max_norm / norm);
            for n in 0..self.keep {
                if self.op[n] == OP_PARAM() && self.grad[n].d.len == self.val[n].d.len {
                    for k in 0..self.grad[n].d.len { self.grad[n].d[k] = self.grad[n].d[k] * f; }
                }
            }
        }
        return norm;
    }

    // AdamW: the moving averages of the gradient and of its square (beta 0.9 and 0.999), and the weight decay that is taken from the weights themselves
    void adamw(self, double lr, double decay) {
        double beta1 = 0.9;
        double beta2 = 0.999;
        double eps = 0.00000001;
        while self.m.len < self.keep { self.m.push(Tensor32::zeros(1, 1)); self.v.push(Tensor32::zeros(1, 1)); }
        self.steps += 1;
        self.b1t = self.b1t * beta1;
        self.b2t = self.b2t * beta2;
        double c1 = 1.0 - self.b1t;
        double c2 = 1.0 - self.b2t;
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() && self.grad[n].d.len == self.val[n].d.len {
                if self.m[n].d.len != self.val[n].d.len { self.m[n] = Tensor32::make(self.val[n].shape); self.v[n] = Tensor32::make(self.val[n].shape); }
                for k in 0..self.val[n].d.len {
                    double gk = (double)self.grad[n].d[k];
                    double mk = beta1 * (double)self.m[n].d[k] + (1.0 - beta1) * gk;
                    double vk = beta2 * (double)self.v[n].d[k] + (1.0 - beta2) * gk * gk;
                    self.m[n].d[k] = (float)mk;
                    self.v[n].d[k] = (float)vk;
                    double w = (double)self.val[n].d[k];
                    w = w - lr * ((mk / c1) / (Math::sqrt(vk / c2) + eps) + decay * w);
                    self.val[n].d[k] = (float)w;
                }
            }
        }
    }

    // the parameters in a text file (numbers with 9 digits); load() puts them back into a graph that has the same parameters (same order and shapes)
    bool save(self, String path) {
        String t = "neuron-graph 1\n";
        int np = 0;
        for n in 0..self.keep { if self.op[n] == OP_PARAM() { np += 1; } }
        t.append("params " + str(np) + "\n");
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() {
                String line = "";
                for k in 0..self.val[n].shape.len { line.append(str(self.val[n].shape[k]) + " "); }
                t.append(line + "\n");
                String nums = "";
                for k in 0..self.val[n].d.len {
                    if k > 0 { nums.push(' '); }
                    nums.append(Json::num_text((double)self.val[n].d[k]));
                }
                t.append(nums + "\n");
            }
        }
        Result<int, Error> r = Fs::write_text(path, t);
        return r.is_ok();
    }
    bool load(self, String path) {
        Result<String, Error> r = Fs::read_text(path);
        if !r.is_ok() { return false; }
        String[] ls = r.take().split("\n");
        if ls.len < 2 || ls[0] != "neuron-graph 1" { return false; }
        int np = 0;
        for n in 0..self.keep { if self.op[n] == OP_PARAM() { np += 1; } }
        if ls[1] != "params " + str(np) { return false; }
        int at = 2;
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() {
                String want = "";
                for k in 0..self.val[n].shape.len { want.append(str(self.val[n].shape[k]) + " "); }
                if at + 1 >= ls.len || ls[at] != want { return false; }
                String[] nums = ls[at + 1].split(" ");
                if nums.len != self.val[n].d.len { return false; }
                for k in 0..nums.len { self.val[n].d[k] = (float)nums[k].to_double(); }
                at += 2;
            }
        }
        return true;
    }

    // a batch of several sequences: after each backward() call acc_add() to keep the gradients of the parameters; at the end acc_apply(1 / batch)
    // puts the mean into the gradients, and clip / adamw / sgd work as usual
    void acc_add(self) {
        while self.acc.len < self.keep { self.acc.push(Tensor32::zeros(1, 1)); }
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() && self.grad[n].d.len == self.val[n].d.len {
                if self.acc[n].d.len != self.val[n].d.len { self.acc[n] = Tensor32::make(self.val[n].shape); }
                for k in 0..self.val[n].d.len { self.acc[n].d[k] += self.grad[n].d[k]; }
            }
        }
    }
    void acc_apply(self, double scale) {
        float f = (float)scale;
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() && n < self.acc.len && self.acc[n].d.len == self.val[n].d.len {
                if self.grad[n].d.len != self.val[n].d.len { self.grad[n] = Tensor32::make(self.val[n].shape); }
                for k in 0..self.val[n].d.len {
                    self.grad[n].d[k] = self.acc[n].d[k] * f;
                    self.acc[n].d[k] = 0.0;
                }
            }
        }
    }

    // plain gradient descent on the parameters (the first `keep` nodes that are parameters)
    void sgd(self, double rate) {
        float r = (float)rate;
        for n in 0..self.keep {
            if self.op[n] == OP_PARAM() && self.grad[n].d.len == self.val[n].d.len {
                for k in 0..self.val[n].d.len { self.val[n].d[k] -= r * self.grad[n].d[k]; }
            }
        }
    }
}

// the numbers 0 .. n-1 in a mixed order (the same seed gives the same order): for mini-batches
int[] shuffled(int n, int seed) {
    int[] a = arr(n + 1);
    for i in 0..n { a.push(i); }
    int s = seed * 2654435761 + 12345;
    int i = n - 1;
    while i > 0 {
        s = (s * 1103515245 + 12345) & 2147483647;
        int j = s % (i + 1);
        int t = a[i];
        a[i] = a[j];
        a[j] = t;
        i -= 1;
    }
    return a;
}

// learning-rate schedules: step from 0 to total
struct Sched {
    // grows from 0 to base in `warm` steps, then falls to low along a cosine until `total`
    static double cosine(int step, int total, int warm, double base, double low) {
        if step < warm { return base * (double)(step + 1) / (double)warm; }
        double p = (double)(step - warm) / (double)(total - warm);
        if p > 1.0 { p = 1.0; }
        return low + (base - low) * 0.5 * (1.0 + Math::cos(3.141592653589793 * p));
    }
}

// ============================================================================================================================
// Gpt: a GPT language model that trains on the phone (neuron 0.7.0). Build it, train it on a text, write with it, save and load it.
//   Gpt m = Gpt::make(256, 64, 64, 4, 2, 1);                  // vocab, context, width, heads, layers, seed
//   int[] data = Gpt::bytes(text);                            // a text as numbers 0-255 (byte level: no tokenizer needed)
//   int[] starts = arr(8); ... starts.push(position in data) ... // each start is the beginning of one training sequence of m.ctx + 1 numbers
//   double loss = m.step(data, starts, 0.003, 0.01, 1.0);     // one step on a batch: mean loss; learning rate, weight decay, clip of the gradient
//   String text = m.write(Gpt::bytes("Once"), 100, 0.8, 20, 1);   // 100 new tokens: temperature, top-k (0 = off), seed
//   m.save("model.gpt");   Gpt n = Gpt::load("model.gpt");    // the weights (text) and the sizes (model.gpt.cfg)
// The model: embeddings of tokens and positions, then `layers` blocks (RMS norm, causal multi-head attention, RMS norm, GELU feed-forward 4 times as wide, residual
// connections), a last RMS norm and a linear layer to the vocabulary. The Graph above does the gradients; AdamW does the learning. The program that uses it
// is the tool `neuron` (neuron gpt train FILE) and examples/train_gpt.jk.
// ============================================================================================================================

struct Gpt {
    Graph g;
    int vocab;
    int ctx;
    int d;
    int heads;
    int layers;
    int emb;
    int pos;
    int gfin;
    Linear head;
    Linear[] wq;
    Linear[] wk;
    Linear[] wv;
    Linear[] wo;
    Linear[] up;
    Linear[] down;
    int[] gain1;
    int[] gain2;
    int rng;

    // a new model with random weights (the same seed gives the same model)
    static Gpt make(int vocab, int ctx, int d, int heads, int layers, int seed) {
        Gpt m;
        m.g = Graph::make();
        m.vocab = vocab; m.ctx = ctx; m.d = d; m.heads = heads; m.layers = layers;
        m.emb = m.g.param(Tensor32::random(vocab, d, seed, 0.1));
        m.pos = m.g.param(Tensor32::random(ctx, d, seed + 1, 0.1));
        Tensor32 ones = Tensor32::zeros(1, d);
        for k in 0..d { ones.d[k] = 1.0; }
        m.gfin = m.g.param(ones.copy());
        m.wq = arr(layers + 1); m.wk = arr(layers + 1); m.wv = arr(layers + 1); m.wo = arr(layers + 1);
        m.up = arr(layers + 1); m.down = arr(layers + 1);
        m.gain1 = arr(layers + 1); m.gain2 = arr(layers + 1);
        for l in 0..layers {
            m.gain1.push(m.g.param(ones.copy()));
            m.gain2.push(m.g.param(ones.copy()));
            m.wq.push(m.g.linear(d, d, seed + 10 + l * 8));
            m.wk.push(m.g.linear(d, d, seed + 11 + l * 8));
            m.wv.push(m.g.linear(d, d, seed + 12 + l * 8));
            m.wo.push(m.g.linear(d, d, seed + 13 + l * 8));
            m.up.push(m.g.linear(d, 4 * d, seed + 14 + l * 8));
            m.down.push(m.g.linear(4 * d, d, seed + 15 + l * 8));
        }
        m.head = m.g.linear(d, vocab, seed + 5);
        m.g.mark();
        m.rng = seed * 2654435761 + 88172645463325252;
        if m.rng == 0 { m.rng = 1; }
        return m;
    }

    // a text as byte numbers
    static int[] bytes(String text) {
        int[] r = arr(text.len + 1);
        for i in 0..text.len { r.push(text[i] & 255); }
        return r;
    }
    // byte numbers as a text
    static String text_of(int[] ids) {
        String s = "";
        for i in 0..ids.len { s.push((char)ids[i]); }
        return s;
    }

    // the scores of the next token at every position of ids (a node: ids.len rows of vocab numbers)
    int forward(self, int[] ids) {
        int t = ids.len;
        int[] pids = arr(t + 1);
        for i in 0..t { pids.push(i); }
        int x = self.g.add(self.g.embed(self.emb, ids), self.g.embed(self.pos, pids));
        for l in 0..self.layers {
            int n1 = self.g.rms_norm(x, self.gain1[l]);
            int att = self.g.attention(self.g.apply(self.wq[l], n1), self.g.apply(self.wk[l], n1), self.g.apply(self.wv[l], n1), self.heads);
            x = self.g.add(x, self.g.apply(self.wo[l], att));
            int n2 = self.g.rms_norm(x, self.gain2[l]);
            x = self.g.add(x, self.g.apply(self.down[l], self.g.gelu(self.g.apply(self.up[l], n2))));
        }
        return self.g.apply(self.head, self.g.rms_norm(x, self.gfin));
    }

    // one learning step on a batch: every start in `starts` is the beginning of a sequence of ctx + 1 numbers in data (the first ctx are the input, the
    // next token at every place is the answer). The gradients of the sequences are averaged; clip: the biggest size of the gradient (0 = no clip).
    // Returns the mean loss of the batch.
    double step(self, int[] data, int[] starts, double lr, double decay, double clip) {
        double total = 0.0;
        for q in 0..starts.len {
            int s = starts[q];
            int[] inp = arr(self.ctx + 1);
            int[] want = arr(self.ctx + 1);
            for i in 0..self.ctx { inp.push(data[s + i]); want.push(data[s + i + 1]); }
            int loss = self.g.softmax_ce(self.forward(inp), want);
            total += (double)self.g.value(loss).d[0];
            self.g.backward(loss);
            self.g.acc_add();
            self.g.clear();
        }
        self.g.acc_apply(1.0 / (double)starts.len);
        if clip > 0.0 { self.g.clip(clip); }
        self.g.adamw(lr, decay);
        return total / (double)starts.len;
    }

    // the mean loss on sequences (no learning): for a check on text the model has not seen
    double loss_on(self, int[] data, int[] starts) {
        double total = 0.0;
        for q in 0..starts.len {
            int s = starts[q];
            int[] inp = arr(self.ctx + 1);
            int[] want = arr(self.ctx + 1);
            for i in 0..self.ctx { inp.push(data[s + i]); want.push(data[s + i + 1]); }
            int loss = self.g.softmax_ce(self.forward(inp), want);
            total += (double)self.g.value(loss).d[0];
            self.g.clear();
        }
        return total / (double)starts.len;
    }

    int next_rand(self) {
        int x = self.rng;
        x = x xor (x << 13);
        x = x xor ((x >> 7) & 72057594037927935);
        x = x xor (x << 17);
        self.rng = x;
        return x & 2147483647;
    }

    // the next token after the numbers in ids (the last ctx of them are used): temperature 0 = the best; top_k 0 = any
    int next_token(self, int[] ids, double temp, int top_k) {
        int[] inp = arr(self.ctx + 1);
        int from = ids.len - self.ctx;
        if from < 0 { from = 0; }
        for i in from..ids.len { inp.push(ids[i]); }
        Tensor32 sc = self.g.value(self.forward(inp));
        int row = (inp.len - 1) * self.vocab;
        self.g.clear();
        int best = 0;
        for c in 1..self.vocab { if sc.d[row + c] > sc.d[row + best] { best = c; } }
        if temp <= 0.0 { return best; }
        // the candidates: the top_k best (or all), a softmax with the temperature, one drawn by chance
        int m = self.vocab;
        if top_k > 0 && top_k < m { m = top_k; }
        int[] cand = arr(m + 1);
        float[] val = arr(m + 1);
        for i in 0..self.vocab {
            float v = sc.d[row + i];
            if cand.len < m {
                cand.push(i); val.push(v);
                int k = cand.len - 1;
                while k > 0 && val[k] > val[k - 1] { float tv = val[k]; val[k] = val[k - 1]; val[k - 1] = tv; int ti = cand[k]; cand[k] = cand[k - 1]; cand[k - 1] = ti; k -= 1; }
            } else if v > val[m - 1] {
                val[m - 1] = v; cand[m - 1] = i;
                int k = m - 1;
                while k > 0 && val[k] > val[k - 1] { float tv = val[k]; val[k] = val[k - 1]; val[k - 1] = tv; int ti = cand[k]; cand[k] = cand[k - 1]; cand[k - 1] = ti; k -= 1; }
            }
        }
        double mx = (double)val[0];
        double z = 0.0;
        double[] pr = arr(m + 1);
        for i in 0..m { double e = Math::exp(((double)val[i] - mx) / temp); pr.push(e); z += e; }
        double r = (double)(self.next_rand() % 1000000) / 1000000.0 * z;
        double acc = 0.0;
        for i in 0..m { acc += pr[i]; if r < acc { return cand[i]; } }
        return cand[m - 1];
    }

    // `count` new tokens after the prompt (byte numbers); the text of the new ones
    String write(self, int[] prompt, int count, double temp, int top_k, int seed) {
        self.rng = seed * 2654435761 + 88172645463325252;
        if self.rng == 0 { self.rng = 1; }
        int[] ids = arr(prompt.len + count + 1);
        for i in 0..prompt.len { ids.push(prompt[i]); }
        int[] fresh = arr(count + 1);
        for k in 0..count {
            int t = self.next_token(ids, temp, top_k);
            ids.push(t);
            fresh.push(t);
        }
        return Gpt::text_of(fresh);
    }

    // the weights go to `path`, the sizes to `path.cfg`
    bool save(self, String path) {
        String cfg = "gpt 1 " + str(self.vocab) + " " + str(self.ctx) + " " + str(self.d) + " " + str(self.heads) + " " + str(self.layers) + "\n";
        Result<int, Error> r = Fs::write_text(path + ".cfg", cfg);
        if !r.is_ok() { return false; }
        return self.g.save(path);
    }
    // a model from a file written by save (a Gpt with vocab 0 when the files cannot be read)
    static Gpt load(String path) {
        Result<String, Error> r = Fs::read_text(path + ".cfg");
        if !r.is_ok() { return Gpt::make(1, 1, 8, 1, 1, 1); }
        String[] w = r.take().trim().split(" ");
        if w.len < 7 || w[0] != "gpt" { return Gpt::make(1, 1, 8, 1, 1, 1); }
        Gpt m = Gpt::make(w[2].to_int(), w[3].to_int(), w[4].to_int(), w[5].to_int(), w[6].to_int(), 1);
        if !m.g.load(path) { return Gpt::make(1, 1, 8, 1, 1, 1); }
        return m;
    }
}
