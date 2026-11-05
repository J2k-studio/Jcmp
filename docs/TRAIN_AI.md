# Training a model with J2K

This page explains how to train a small neural network in J2K with the library `<neuron>` (file `std/neuron.j`, header "neuron 0.7.1"), from XOR to a tiny character-level language model. Every example was compiled and run with `jcmp` for this page, and the outputs were checked against the `.out` files of the test suite. Anything that was not run is marked **not measured**.

The compiler commands are the same as in `docs/PERFORMANCE.md`:

```sh
export JCMP_LIB=$HOME/Jcmp-reg/Library J2K_PATH=$HOME/Jcmp-reg/build/libs
jcmp file.jk -o out && ./out
```

The examples use the compiler built from branch `l7` (not released), as in `docs/PERFORMANCE.md`.

## 1. What `<neuron>` gives

The file's header lists the main uses. These are the parts, read from `std/neuron.j`:

| part | what it is | main functions |
|---|---|---|
| `Tensor` | a table of `rows x cols` **double** numbers | `zeros`, `get`, `set`, `matmul`, `matmul_fast` (float32 inside, threads), `add`, `transpose`, `relu`, `softmax` |
| `Network` | layers of `Tensor` neurons, relu between the layers | `make`, `add(inputs, outputs)`, `fit(x, y, rounds, rate)`, `predict`, `save`, `load` (a text file `.jw`) |
| `Tensor32` | a table of **float32** numbers, shape of 1 to 4 numbers (the last one is the width of a row) | `make(shape)`, `zeros`, `random(rows, cols, seed, scale)`, `from_list`, `get`, `set`, `gather`, `copy`, `reshape`, `add`, `mul`, `scale`, `transpose`, `relu`, `softmax`, `sum`, `mean`, `matmul`, `size`, `rows`, `cols` |
| `Graph` | autograd: a tape of operations; the gradients come from `backward` | `param`, `input`, `mark`, `clear`, `backward(loss)`, `value(n)`, `gradient(n)`, `sgd(rate)`, `adamw(lr, decay)`, `clip(max_norm)`, `acc_add`, `acc_apply(scale)`, `save`, `load` |
| `Linear` | `y = x @ w + b` made from two parameters | `g.linear(inputs, outputs, seed)`, `g.apply(l, x)` |
| `Sched` | learning-rate schedule | `Sched::cosine(step, total, warm, base, low)` |
| `shuffled` | a random order of `0 .. n-1` for mini-batches | `shuffled(n, seed)` |
| `Gpt` | a GPT language model on bytes (no tokenizer) | `make(vocab, ctx, d, heads, layers, seed)`, `bytes(text)`, `text_of`, `step(data, starts, lr, decay, clip)`, `loss_on`, `write(prompt, n, temp, topk, seed)`, `save`, `load` |

The operations of a `Graph` are the `OP_` numbers in the file: `matmul add mul relu tanh sigmoid embed gelu silu layer_norm rms_norm attention conv2d maxpool mse softmax_ce` (plus the kinds `INPUT` and `PARAM`). Their methods are the same names: `g.matmul(a, b)`, `g.attention(q, k, v, heads)` (causal, several heads), `g.conv2d(x, w, b, c_in, h, wd, c_out, k, stride, pad)`, `g.mse(out, target)` (the target is a `Tensor32`), `g.softmax_ce(scores, classes)`.

A node is an `int`. `g.value(n)` is the `Tensor32` of the node and `g.gradient(n)` its gradient after `backward`. `g.mark()` marks the end of the parameters: everything that is made after it is one step, and `g.clear()` throws the step away while the parameters stay.

**Optimisers in the code:** plain gradient descent (`sgd`), AdamW (`adamw`, with the moving averages of the gradient and of its square, and weight decay), and the clip of the gradient by its global norm (`clip`). `acc_add` and `acc_apply` add up gradients over several sequences and take their mean. `Sched::cosine` has a linear warm-up and then a cosine fall. **Not in the code:** momentum, other adaptive optimisers, dropout (there is no such operation), and half-precision training.

Two library hooks are outside `<neuron>`. `<neurongpu>` (`std/neurongpu.j`) sets a hook in `Tensor32::matmul` for big products. `<npu>` (`std/npu.j`) is a layer with fixed weights for inference. Both are described in section 4.

## 2. Worked examples from the tests

All examples below are in `test/` and their outputs are in the matching `.out` file. The test runner checks them.

### 2.1 Network with `Tensor` (`test/t506_neuron.jk`)

The shortest example: a two-layer network learns a four-row table.

The whole file:

```jk
#import <stdlib>
#import <math>
#import <neuron>
void main() {
    Tensor x = Tensor::zeros(4, 2);
    Tensor y = Tensor::zeros(4, 1);
    x.set(1, 1, 1.0); x.set(2, 0, 1.0); x.set(3, 0, 1.0); x.set(3, 1, 1.0);
    y.set(1, 0, 1.0); y.set(2, 0, 1.0);
    Network n = Network::make();
    n.add(2, 8);
    n.add(8, 1);
    double loss = n.fit(x, y, 4000, 0.1);
    Tensor o = n.predict(x);
    jout << "loss<0.001: " << (loss < 0.001) << "\n";
    for i in 0..4 { jout << (o.d[i] > 0.5) << " "; }
    jout << "\n";
    n.save("_t506.jw");
    Network m = Network::load("_t506.jw");
    Tensor o2 = m.predict(x);
    bool same = true;
    for i in 0..4 { double d = o2.d[i] - o.d[i]; if d > 0.000001 || d < 0.0 - 0.000001 { same = false; } }
    jout << "reloaded same: " << same << "\n";
    Fs::remove("_t506.jw");
}
```

Expected output (the same as `test/t506_neuron.out`):

```
loss<0.001: true
false true true false 
reloaded same: true
```

What it does: `fit` runs 4000 rounds of gradient descent with rate 0.1 and returns the loss. `save` writes the weights as text, and `load` puts them back into a new network; the check at the end compares the two predictions.

### 2.2 XOR with a `Graph` (from `test/t551_neuron_autograd.jk`)

The XOR block of `test/t551_neuron_autograd.jk`, as a complete program. Two layers, tanh and then sigmoid, mean squared error, plain gradient descent with rate 0.5 for 3000 steps:

Complete program (`xor.jk`, compiled and run):

```jk
#import <stdlib>
#import <neuron>

// XOR with a Graph: two layers (tanh, then sigmoid), mean squared error, plain gradient descent
Graph g;

void main() {
    g = Graph::make();
    int w1 = g.param(Tensor32::random(2, 6, 1, 1.0));
    int b1 = g.param(Tensor32::zeros(1, 6));
    int w2 = g.param(Tensor32::random(6, 1, 2, 1.0));
    int b2 = g.param(Tensor32::zeros(1, 1));
    g.mark();
    double[] xv = arr(8);
    xv.push(0.0); xv.push(0.0); xv.push(0.0); xv.push(1.0); xv.push(1.0); xv.push(0.0); xv.push(1.0); xv.push(1.0);
    double[] yv = arr(4);
    yv.push(0.0); yv.push(1.0); yv.push(1.0); yv.push(0.0);
    Tensor32 xs = Tensor32::from_list(4, 2, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    double last = 1.0;
    for step in 0..3000 {
        int x = g.input(xs);
        int h = g.tanh(g.add(g.matmul(x, w1), b1));
        int o = g.sigmoid(g.add(g.matmul(h, w2), b2));
        int l = g.mse(o, ys);
        last = (double)g.value(l).d[0];
        g.backward(l);
        g.sgd(0.5);
        g.clear();
    }
    int x2 = g.input(xs);
    int h2 = g.tanh(g.add(g.matmul(x2, w1), b1));
    int o2 = g.sigmoid(g.add(g.matmul(h2, w2), b2));
    Tensor32 out = g.value(o2);
    jout << "last loss " << last << "\n";
    jout << "answers: " << out.d[0] << " " << out.d[1] << " " << out.d[2] << " " << out.d[3] << "\n";
}
```

The program prints the last loss and the four answers. On this phone it printed `last loss 0.000407` and `answers: 0.011009 0.976954 0.980323 0.024233` (values near 0, 1, 1, 0). The test `test/t551` checks the same thing as a boolean (`xor loss small: true`, `xor answers: truetruetruetrue`).

The steps inside the loop are the training pattern of every example below:

1. `g.input(xs)` makes a node for the data; `g.matmul`, `g.add`, `g.tanh` and `g.sigmoid` make the forward pass.
2. `g.mse(o, ys)` makes the loss node.
3. `g.backward(l)` fills the gradients of all nodes.
4. `g.sgd(0.5)` changes the parameters; `g.clear()` removes the step's nodes.

`test/t551` also checks each kind of operation against a numerical derivative (`gradient check 0` to `3`, `softmax_ce`): every test prints `true`.

### 2.3 Mini-batches, AdamW, schedule and clip (`test/t552_neuron_train.jk`)

Two rings of points are classified by two layers (`Linear`, `tanh`, `softmax_ce`). Each epoch shuffles the 60 rows (`shuffled(60, epoch + 1)`), takes batches of 20 (`gather`), and calls `g.clip(5.0)` and `g.adamw(Sched::cosine(epoch, total, 5, 0.05, 0.001), 0.001)` on every batch. An excerpt of the training loop (verbatim from the test):

```jk
    for epoch in 0..total {
        int[] order = shuffled(60, epoch + 1);
        int b = 0;
        while b < 60 {
            int[] idx = arr(20);
            int[] bc = arr(20);
            for q in 0..20 { idx.push(order[b + q]); bc.push(cls[order[b + q]]); }
            int h = g.tanh(g.apply(l1, g.input(xs.gather(idx))));
            int loss = g.softmax_ce(g.apply(l2, h), bc);
            if epoch == 0 && b == 0 { first = (double)g.value(loss).d[0]; }
            last = (double)g.value(loss).d[0];
            g.backward(loss);
            double norm = g.clip(5.0);
            if norm > biggest { biggest = norm; }
            g.adamw(Sched::cosine(epoch, total, 5, 0.05, 0.001), 0.001);
            g.clear();
            b += 20;
        }
    }
```

The test then saves the parameters with `g.save`, sets the first layer to zero, and loads them back; the loaded model gives the same accuracy as before. Expected output: `adamw loss falls: true`, `accuracy above 0.95: true`, `saved true loaded true restored true broken differs true`, `other graph refuses: true`.

### 2.4 Layers for text (`test/t553_neuron_layers.jk`)

Six layers: an embedding (`embed`), `gelu`, `silu`, `layer_norm`, `rms_norm`, and causal `attention` with two heads. For each one the test checks the gradients against a numerical derivative (`layer 0` to `layer 5 gradient ok: true`) and checks the causal mask: changing the last row of the input does not change the earlier outputs (`causal: true`). Read the `build` function of the file to see how each layer is made from parameters.

### 2.5 Convolution and pooling (`test/t557_neuron_conv.jk`)

`conv2d` with 1 or 2 input channels, stride 1 or 2, and padding 0 or 1, and `maxpool` of size 2. The last part trains a network of one convolution (4 filters, 3x3), `relu`, `maxpool`, and a linear layer on 60 synthetic 8x8 pictures (a horizontal bar, a vertical bar, a diagonal, with noise) with `adamw(0.02, 0.0)` for 120 steps. The expected line is `loss falls: true accuracy: 60 of 60`.

### 2.6 A small GPT (`test/t559_gpt.jk`, `test/t554_nano_gpt.jk`)

`Gpt` is a model on bytes: `Gpt::bytes` turns a text into numbers 0 to 255, so no tokenizer is needed. `test/t559_gpt.jk` makes a model with vocabulary 256, context 16, width 32, 2 heads and 1 layer (`parameters 29824`), trains it for 200 steps on batches of four random starts, and writes text with it. Expected output (checked here): the loss falls, the check on fixed starts falls below 30 % of its start value, `writes: [at on the dog sat on the]`, and save and load give the same model.

`test/t554_nano_gpt.jk` writes the layers out by hand (embedding, attention with two heads, `rms_norm`, `gelu` feed-forward) for a short text. Its expected output is `loss from true to small true`.

The program `examples/train_gpt.jk` trains on a file: `train_gpt FILE [steps=2000] [ctx=64] [d=64] [heads=4] [layers=2] [batch=8] [lr=0.003] [out=model.gpt] [resume=1] [every=100] [prompt=text]`. It keeps the last tenth of the file for checking, saves the model every `every` steps, and prints the time per step. **Not run for this page.**

## 3. The 4x8 micro-kernel (branch `n4`)

The file `~/.tmpj/mk/mk.jk` is a 4x8 register-blocked kernel for `float32`. Its header comment says: "C = A*B, 4x8 register block: 8 accumulators; per k: 2 loads of B (8 floats), 4 numbers of A, 8 multiply-adds". The summary lists it as the micro-kernel work of branch `n4`. It is not in `std/neuron.j` of this checkout (branch `doc`), which has `nt_mm_small` (two rows of four columns, as its comment says). The full kernel and its status are in `docs/PERFORMANCE.md`, section 4.3.

## 4. What is not there yet

- **GPU training: not measured.** `<neurongpu>` (`std/neurongpu.j`) replaces the products of `Tensor32::matmul` by a compute shader when the product has at least `NeuronGpu::enable(limit)` multiply-adds. Its header says that the GPU is faster from about 256 x 256 x 256 on a Kirin 990; that is the file author's claim, not measured here. The test `test/t562_neuron_gpu.jk` checks only that the GPU and CPU products agree (`gpu and cpu products agree: true`). The backward pass also calls `Tensor32::matmul` (`std/neuron.j`, `backward`), so the hook would apply there too; I did not run a training step on the GPU.
- **NPU: inference only, with fixed weights.** `std/npu.j` makes a layer `y = x * W^T + bias` whose weights do not change. The summary reports one measurement: 512 x 512 in 8.5 ms on the NPU against 15 ms on the GPU and 37 ms on the CPU (2026-11-03). No training path exists.
- **Optimisers:** only `sgd`, `adamw`, `clip` and the cosine schedule (section 1). No momentum, no other adaptive methods.
- **Speed of training on the phone: not measured** for `<neuron>`. The summary's GEMM numbers (about 1.5 to 1.6 times C, load 47) are for the GEMM benchmark `tools/bench/gemm`, not for `<neuron>`. The gate in `docs/design/31-speed-structure.md` sets a target (GEMM within 1.5 times of C and not slower than Java); the target is not reached yet in the summary.
- **`Gpt` is byte-level only,** with the sizes given to `make`. There is no saved training log or benchmark in the repository for it.

## 5. From XOR to a tiny language model

1. **XOR with `Graph`** (section 2.2): one parameter set, full-batch gradient descent.
2. **Mini-batches with AdamW, a schedule and a clip** (section 2.3): shuffled batches, `save` and `load`.
3. **Layers for sequences** (section 2.4): embeddings, normalisation, causal attention. Check each layer's gradient before you train it.
4. **A small GPT on bytes** (section 2.6, `test/t559_gpt.jk`): `Gpt::make`, `m.step` on batches of starts, `m.write` to see the result.
5. **A model that learns a file:** `examples/train_gpt.jk` with its options. Start with `ctx=16 d=32 layers=1` and check that the loss falls before you make the model bigger.

Each step changes one thing, so a failure has one cause.

## 6. Tips for speed on the phone

- **Use `float32`.** `Tensor32` and `matmul_fast` store `float32`. The file comment of `std/neuron.j` gives 1.8 to 2.1 GFLOPS for one core with the dot-product form, against 0.4 for the plain loop (`bench/dot.jk`); that is the file author's measurement, not one made for this page.
- **Make products big enough for threads.** `Tensor32::matmul` uses one thread below 2,500,000 multiply-adds and four threads above it, if the product has at least 16 rows. Small layers gain nothing from threads.
- **Batch size.** `Gpt::step` and `acc_add` average the gradients of the sequences in one step, so a bigger batch is more work per step, not a faster epoch. The repository has no measurement of the best batch size. Use the time per step that `examples/train_gpt.jk` prints and compare batch sizes on the same data.
- **Check the cores** with `nproc` before you measure. The summary records a day when the shell had two cores instead of eight.
- **Charging and temperature: not measured.** The repository has no data on them. What is known: the phone's speed changes by up to three times with its load (`docs/design/31-speed-structure.md`), so compare two runs only when they are made one after the other.
- **Save the weights during a long run** (`save`, or `every=` in `examples/train_gpt.jk`, which also resumes with `resume=1`), so that a stopped run can go on from its last save.
