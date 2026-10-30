// mlp 0.1.0 -- train a small network in a few lines (on top of <neuron>).   #import <mlp>
//   int[] sizes = arr(3);  sizes.push(2); sizes.push(16); sizes.push(1);
//   Mlp net = Mlp::make(sizes, Mlp::TANH(), 1);                  // layers 2 -> 16 -> 1; the activation between them; the seed
//   net.fit(x, y, 300, 0.01);                                   // x: Tensor32 (rows of inputs), y: Tensor32 (rows of outputs); 300 epochs, learning rate
//   Tensor32 p = net.predict(x);                                // the outputs
//   double e = net.loss_on(x, y);                               // the mean squared error
// For classes (the last layer gives one number for each class, the labels are 0 .. classes - 1):
//   Mlp c = Mlp::make(sizes, Mlp::RELU(), 1);   c.fit_classes(x, labels, 100, 0.01);   double a = c.accuracy(x, labels);   int k = c.classify_row(x, 0);
//   net.save("net.mlp");   Mlp m = Mlp::load("net.mlp");
// Settings (change a field before fit): net.batch (rows in a step, 32), net.decay (weight decay of AdamW, 0.0), net.clip (largest gradient norm, 5.0),
// net.every (print the loss every this many epochs, 0 = silent, the default), net.cosine (1: the learning rate falls along a cosine to a tenth).
// fit returns the last loss; net.history has the loss of every epoch. The rows are shuffled in every epoch.
#import <neuron>

struct Mlp {
    Graph g;
    Linear[] layers;
    int[] sizes;
    int act;
    int seed;
    int batch;
    double decay;
    double clip;
    int every;
    int cosine;
    double[] history;

    static int RELU() { return 0; }
    static int TANH() { return 1; }
    static int SIGMOID() { return 2; }
    static int GELU() { return 3; }

    static Mlp make(int[] sizes, int act, int seed) {
        Mlp n;
        n.g = Graph::make();
        n.layers = arr(8);
        n.sizes = arr(sizes.len + 1);
        for i in 0..sizes.len { n.sizes.push(sizes[i]); }
        n.act = act;
        n.seed = seed;
        n.batch = 32;
        n.decay = 0.0;
        n.clip = 5.0;
        n.every = 0;
        n.cosine = 0;
        n.history = arr(64);
        for i in 0..sizes.len - 1 { n.layers.push(n.g.linear(sizes[i], sizes[i + 1], seed + i * 7)); }
        n.g.mark();
        return n;
    }

    // the output node for the input node x
    int forward(self, int x) {
        int h = x;
        int last = self.layers.len - 1;
        for i in 0..self.layers.len {
            h = self.g.apply(self.layers[i], h);
            if i < last {
                if self.act == 0 { h = self.g.relu(h); }
                else if self.act == 1 { h = self.g.tanh(h); }
                else if self.act == 2 { h = self.g.sigmoid(h); }
                else { h = self.g.gelu(h); }
            }
        }
        return h;
    }

    Tensor32 predict(self, Tensor32 x) {
        int xi = self.g.input(x);
        int o = self.forward(xi);
        Tensor32 out = self.g.value(o).copy();
        self.g.clear();
        return out;
    }

    double loss_on(self, Tensor32 x, Tensor32 y) {
        int xi = self.g.input(x);
        int o = self.forward(xi);
        int l = self.g.mse(o, y);
        double v = (double)self.g.value(l).d[0];
        self.g.clear();
        return v;
    }

    int classify_row(self, Tensor32 x, int row) {
        int[] one = arr(1);
        one.push(row);
        Tensor32 r = x.gather(one);
        Tensor32 p = self.predict(r);
        int best = 0;
        for c in 1..p.cols() { if p.d[c] > p.d[best] { best = c; } }
        return best;
    }

    double accuracy(self, Tensor32 x, int[] labels) {
        Tensor32 p = self.predict(x);
        int right = 0;
        int rows = p.rows();
        int cols = p.cols();
        for r in 0..rows {
            int best = 0;
            for c in 1..cols { if p.d[r * cols + c] > p.d[r * cols + best] { best = c; } }
            if best == labels[r] { right += 1; }
        }
        return (double)right / (double)rows;
    }

    double rate_at(self, int epoch, int epochs, double lr) {
        if self.cosine == 0 { return lr; }
        return Sched::cosine(epoch, epochs, 0, lr, lr * 0.1);
    }

    // mean squared error; y has the outputs of every row
    double fit(self, Tensor32 x, Tensor32 y, int epochs, double lr) { return self.run(x, y, null_labels(), 0, epochs, lr); }

    // softmax cross entropy; labels[r] is the class of row r
    double fit_classes(self, Tensor32 x, int[] labels, int epochs, double lr) { return self.run(x, Tensor32::zeros(1, 1), labels, 1, epochs, lr); }

    double run(self, Tensor32 x, Tensor32 y, int[] labels, int kind, int epochs, double lr) {
        int rows = x.rows();
        double last = 0.0;
        self.history.clear();
        for e in 0..epochs {
            int[] order = shuffled(rows, self.seed + e);
            double sum = 0.0;
            int steps = 0;
            int at = 0;
            while at < rows {
                int n = self.batch;
                if at + n > rows { n = rows - at; }
                int[] idx = arr(n);
                for k in 0..n { idx.push(order[at + k]); }
                Tensor32 xb = x.gather(idx);
                int xi = self.g.input(xb);
                int o = self.forward(xi);
                int l = 0;
                if kind == 0 {
                    l = self.g.mse(o, y.gather(idx));
                } else {
                    int[] lb = arr(n);
                    for k in 0..n { lb.push(labels[idx[k]]); }
                    l = self.g.softmax_ce(o, lb);
                }
                sum += (double)self.g.value(l).d[0];
                self.g.backward(l);
                self.g.clip(self.clip);
                self.g.adamw(self.rate_at(e, epochs, lr), self.decay);
                self.g.clear();
                steps += 1;
                at += n;
            }
            last = sum / (double)steps;
            self.history.push(last);
            if self.every > 0 && (e + 1) % self.every == 0 { cout << "epoch " << (e + 1) << " loss " << last << "\n"; }
        }
        return last;
    }

    bool save(self, String path) {
        String cfg = str(self.act) + " " + str(self.sizes.len);
        for i in 0..self.sizes.len { cfg = cfg + " " + str(self.sizes[i]); }
        cfg = cfg + "\n";
        if !self.g.save(path) { return false; }
        switch Fs::write_text(path + ".cfg", cfg) {
            Result::Ok(v): { return true; }
            Result::Err(e): { return false; }
        }
        return false;
    }

    static Mlp load(String path) {
        int[] sizes = arr(8);
        int act = 0;
        switch Fs::read_text(path + ".cfg") {
            Result::Ok(text): {
                String[] w = text.trim().split(" ");
                act = w[0].to_int();
                int n = w[1].to_int();
                for i in 0..n { sizes.push(w[2 + i].to_int()); }
            }
            Result::Err(e): { }
        }
        Mlp j = Mlp::make(sizes, act, 1);
        j.g.load(path);
        return j;
    }
}

int[] null_labels() { int[] none = arr(1); return none; }
