// neuron 0.1.0 -- tensors and small neural networks that train on the phone.   #import <neuron>   (needs jcmp 1.1.0.0; license: MPL-2.0)
//   Tensor a = Tensor::zeros(2, 3);   a.set(0, 1, 5.0);   Tensor c = a.matmul(b);   Tensor p = c.relu().softmax();
//   Network n = Network::make();   n.add(2, 8);   n.add(8, 1);                // layers of neurons: relu between them
//   n.fit(x, y, 3000, 0.1);   Tensor out = n.predict(x);   n.save("m.jw");   Network m = Network::load("m.jw");
// A Tensor is a table of rows x cols numbers (double); the methods return new Tensors. The file .jw is a text file (the weights).

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
                double e = Math::exp(self.d[i * self.cols + j] - m);
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
        return x.matmul(self.w).add(self.b);
    }
    Tensor backward(self, Tensor dy, double rate) {
        Tensor dx = dy.matmul(self.w.transpose());
        Tensor dw = self.x.transpose().matmul(dy);
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
