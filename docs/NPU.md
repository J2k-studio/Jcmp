# The NPU of the phone: `#import <npu>`

`<npu>` (version 0.1.0, `std/npu.j`) runs one layer of a neural network on the NPU of the phone through
Android's NNAPI: `y = x * W^T + bias` with **fixed** weights. It is for inference (the weights stay the
same); it is not a training library. When the phone has no NPU, or NNAPI is missing, the layer says so
and the program goes on with the CPU. Measured on the author's phone (Kirin 990, Termux, 2026-11-05);
the numbers are from one session and are not a benchmark suite.

## 1. A layer, checked against the CPU

`#import <npu>` needs no `-dyn` flag: the library imports `<native>`, which makes the program a dynamic
executable by itself.

```jk
#import <stdlib>
#import <npu>
// one layer with fixed weights on the NPU, checked against the CPU
int main() {
    if !Npu::available() { jout << "no NPU here: the CPU does the layer\n"; return 0; }
    int m = 8; int k = 16; int n = 8;
    float^ w = (float^)Mem::alloc(n * k * 4);       // n x k weights, row i = the weights of output i
    float^ bias = (float^)Mem::alloc(n * 4);
    float^ x = (float^)Mem::alloc(m * k * 4);
    float^ y = (float^)Mem::alloc(m * n * 4);
    for i in 0..n * k { w[i] = (float)(i % 5) * 0.25 - 0.5; }
    for i in 0..n { bias[i] = (float)i * 0.5; }
    for i in 0..m * k { x[i] = (float)(i % 7) * 0.25; }
    NpuLinear l = NpuLinear::make(w, bias, m, k, n);
    if !l.ok { jout << "the NPU refused the model, code " << l.code << "\n"; return 1; }
    if !l.run(x, y) { jout << "the run failed\n"; return 1; }
    double worst = 0.0;
    for r in 0..m { for c in 0..n {
        double want = (double)bias[c];
        for q in 0..k { want = want + (double)x[r * k + q] * (double)w[c * k + q]; }
        double e = (double)y[r * n + c] - want;
        if e < 0.0 { e = 0.0 - e; }
        if e / (1.0 + want) > worst { worst = e / (1.0 + want); }
    } }
    l.destroy();
    jout << "y[0] = " << y[0] << ", within 1 percent of the CPU: " << (worst < 0.01) << "\n";
    return 0;
}
```

Output:

```
y[0] = -0.437500, within 1 percent of the CPU: true
```

## 2. The API

| Call | What it does |
|---|---|
| `Npu::available()` | true when NNAPI has a device that is not the reference CPU |
| `NpuLinear::make(w, bias, m, k, n)` | builds and compiles the model. `w`: `n x k` numbers (row-major), `bias`: `n` numbers or `null`, `m` rows of `x` at a time |
| `l.ok`, `l.code` | `ok` is true when the model is ready; `code` is 0, or the NNAPI error of the step that failed, or -1 when there is no NPU |
| `l.run(x, y)` | `x` is `m x k`, `y` is `m x n`, both `float` (float32 in and out). Returns false when the NPU says no |
| `l.destroy()` | frees the model and the compilation |

The weights and the bias are given to the model at `make`. Making a model takes about
30 to 70 ms (see the numbers below), so make it once and call `run` many times.

## 3. Limits

* **Half precision.** The NPU computes in float16 (`relaxComputationFloat32toFloat16`). Numbers above 65504
  overflow, and the digits are about three. The test `t569` accepts a difference of 1 percent.
* **Fixed weights.** The weights must be constants of the model. NNAPI on this phone refused a model whose
  weights were an input (error 4).
* **Inference only.** The model is made from the weights; a training step would change them and need a new
  model each time.
* **Size.** The biggest size tried was 512 (`m`, `k`, `n`). 1024 was too slow (the file says so).
* **One layer.** `<npu>` gives one fully connected layer. A whole network is not in the library yet.

## 4. What was measured

From the comments of `std/npu.j` (Kirin 990, the design notes in `docs/design/26`):

| One product `m = k = n` | NPU | CPU (`Tensor32.matmul`) | GPU |
|---|---|---|---|
| 512 | 8.8 ms | 37 ms | 15 ms |
| 256 | 4.6 ms | 5.5 ms | 3.6 ms |
| 128 | 3.2 ms | 1.0 ms | |

A call costs about 3 ms, so for one row at a time (`m = 1`) the CPU wins; from 8 rows the NPU is level or
faster. The file also says that making the model takes about 70 ms.

Run again on 2026-11-05 with `bench/npu_layer.jk` (`npu_layer m k n`, one session, a few runs each):

| `m k n` | NPU per product | CPU per product | model |
|---|---|---|---|
| 1 256 256 | 0.95 ms | 0.05 ms | 30 ms |
| 64 256 256 | 1.15 - 1.25 ms | 2.5 - 2.8 ms | 30 ms |
| 128 256 256 | 1.4 ms | 5.0 ms | 30 ms |
| 512 512 512 | 4.2 ms | 78 ms | 34 ms |

The CPU column is `Tensor32.matmul` of `<neuron>`, not the vectoriser of [SIMD.md](SIMD.md), and the phone
changes speed with its load, so only the ratios count. The first run of the model is 1 to 5 ms.

`bench/npu_nnapi.jk` calls NNAPI directly (`npu_nnapi DEVICE M K N`, the file says device 0 is the NPU and
1 the reference CPU; the device names were not checked here). Run with `0 4 3 2` it printed a
difference of 0.000000 from the CPU and 1.1 ms per product.

## 5. Build and run

```
export JCMP_LIB=... J2K_PATH=...        # the library folder and the built libraries (see BUILD.md)
jcmp npu_demo.jk -o npu_demo && ./npu_demo
```

On a computer without an NPU the program prints `no NPU here: the CPU does the layer`. The NPU is only
used on a phone with NNAPI; the tests `t569` print `npu: ok` also when there is no NPU, so they check
nothing there.

## See also

* [GPU.md](GPU.md) for the graphics chip and OpenGL ES
* `bench/README.md` for the `<neuron>` numbers on the same phone
