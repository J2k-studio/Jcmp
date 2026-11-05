# Writing fast J2K code

This page is for people who write numeric J2K code: loops over arrays, matrix products, small vector types. It says how the compiler makes such loops fast, what shape of loop it accepts, which types to use, and how to measure. Every program below was compiled and run with `jcmp` before it went into this page.

**Status (2026-11-05).** The vectoriser for heap arrays and for matrix indices is on the development branches, not in a released version yet. The examples here were compiled with the compiler built from branch `l7` (`~/Jcmp-l7/_test_out/boot/jcmp3`). If a loop below is not vectorised with your compiler, check its version first (`jcmp -version`) and see `docs/PROJECT_SUMMARY.md`.

To compile any file on this page:

```sh
export JCMP_LIB=$HOME/Jcmp-reg/Library J2K_PATH=$HOME/Jcmp-reg/build/libs
jcmp file.jk -o out && ./out
```

## 1. How the compiler makes loops fast

The compiler works in layers (the table is from `docs/design/31-speed-structure.md`):

| layer | what it does for speed |
|---|---|
| front end | types, struct values, inline hints |
| IR passes | inlining, value numbering, cell promotion, counted loops, **vectoriser** (NEON), loop-invariant motion |
| lowering | IR to ARM64 text |
| register pass | slot-to-register assignment, peephole rules (fused multiply-add, forwarding of loads and stores, loop-invariant hoisting) |

Two things matter most for you as a programmer:

1. **The vectoriser.** A loop over arrays of `float` is turned into NEON code: four `float` values per instruction (`f32x4`). It only does this when the loop has the simple shape of section 2. Otherwise the loop stays scalar, and the scalar code is still correct.
2. **The overlap guard.** When the vectoriser cannot prove that two arrays (or two rows of one array) do not overlap, it writes a run-time test. If the test fails, the scalar loop runs. Results are the same either way.

To see what the vectoriser does with a program, use these switches (section 6): `-irdbg 4194304` prints one line per counted loop that it looks at, and says when it gives up and why (for example `calls 2` for a loop with calls in the body). `-emit-asm file.jasm` writes the ARM64 text, where vector code shows as `.4s` operands.

## 2. The loop shape the vectoriser accepts

From the summary and from the tests `test/t578_vec_heap.jk` (heap arrays, every length 0 to 69) and `test/t579_vec_rows.jk` (row offsets):

- **A counted loop** over an index, for example `while j < n { ...; j += 1; }` or `for i in 0..n`.
- **Arrays of `float`** (32 bits). Global arrays, local arrays and heap arrays (`float[] x = arr(n)`) are all accepted. Two different arrays are checked for overlap at run time; if they overlap the scalar loop runs.
- **Row offsets in locals.** `c[ci + j] = c[ci + j] + av * b[bk + j]` is vectorised when `ci` and `bk` are locals that do not change inside the loop. Write the row start (`i * n`, `k * n`) in a local before the loop, not inside it.
- **A scalar broadcast before the loop.** Read the scalar (`float av = a[i * n + k];`) before the inner loop, so that it is one value inside the loop body.
- **No calls inside the loop.** A call stops the vectoriser: in a test with a call `bump(s)` in the loop body, the loop got no vector code, and `-irdbg 4194304` printed `calls 2` for it. Move the call out of the loop, or write the body inline.
- **No 64-bit integer multiply.** NEON has no 64-bit integer multiply, so `int[] * int[]` stays scalar. The summary does not report a vectorised `int` loop.
- **Doubles.** The measured loops in the project are float loops. The summary does not report a vectorised `double` loop, so do not assume one.

When a loop does not match the list, check it with `-irdbg 4194304` before you rewrite it.

## 3. `float` or `double`, and the SIMD types

- `float` is 32 bits. It is the type to use for array data where the precision allows it: it halves the memory traffic and gives four lanes per NEON register.
- `double` is 64 bits (two lanes per register). Use it where the precision matters, for example for sums of many small numbers.
- A decimal literal next to a `float` becomes a `float` (`2.0 * x` with `float x`).
- Library `<neuron>` follows the same split: `Tensor` holds `double`s, `Tensor32` holds `float32` and is the fast one. The header of `std/neuron.j` says that `Tensor::matmul_fast` packs the numbers to `float32`, so its last digits differ from `matmul`.

The vector types are in `<simd>` (`std/simd.j`): `f64x2`, `i64x2`, `f32x4`, `i32x4` and `i8x16`. The lanes are named `x y z w`. Each has `load(p, i)` (reads consecutive elements), `v.store(p, i)` (writes them back) and `sum()`. Operators `+`, `-` and `*` work lane by lane, and a scalar is broadcast when it is multiplied by a vector (`c00 + b0 * a0` in section 4). `i8x16` has `dot`, the SDOT instruction (the header says it is for quantised products). The matrix product in section 4 uses only `f32x4`.

## 4. The matrix product in three forms

All three forms compute `C = A * B` for `512 x 512` matrices of `float`. The first two are in `tools/bench/gemm/gemm.jk`. The program takes its form from the first argument: `./gemm 0` is the dot-product form (the default), `./gemm 1` is the row form. The third form is the 4x8 register block of section 4.3. Each program prints `c[12345]`. For the same inputs, forms 0, 1 and 4x8 print the same value (`1142.375000`); that was checked on this phone.

### 4.1 `ijk`: dot products

Every `c[i][j]` is a dot product, accumulated in one local. The reduction is one dependent chain of additions. The vectoriser does not touch this loop.

The whole file `tools/bench/gemm/gemm.jk` (forms 0 and 1 are the two loops):

```jk
#import <stdlib>
using stdlib;

// C = A * B for N x N float32 matrices: ijk (dot products), ikj (row updates, no dependent chain), and a 4-row version of ikj
int N = 512;

int main() {
    int n = 512;
    float[] a = arr(n * n);
    float[] b = arr(n * n);
    float[] c = arr(n * n);
    for i in 0..n * n { a.push((float)(i % 13) * 0.5); b.push((float)(i % 7) * 0.25); c.push(0.0); }
    int which = 0;
    String[] av = Env::args();
    if av.len > 1 { which = av[1].to_int(); }
    if which == 0 {
        for i in 0..n { for j in 0..n {
            float s = 0.0;
            for k in 0..n { s = s + a[i * n + k] * b[k * n + j]; }
            c[i * n + j] = s;
        } }
    } else if which == 1 {
        for i in 0..n {
            for k in 0..n {
                float av = a[i * n + k];
                int ci = i * n;
                int bk = k * n;
                int j = 0;
                while j < n { c[ci + j] = c[ci + j] + av * b[bk + j]; j += 1; }
            }
        }
    }
    jout << c[12345] << "\n";
    return 0;
}
```

The loop over `k` reads `b` with a stride of `n`, so `b` is not read in order. The summary measured this form at about 1.6 times the speed of `clang -O2` (section 5).

### 4.2 `ikj`: row updates

The loop order changes to `i`, `k`, `j`. The inner loop walks along one row of `c` and one row of `b`, so both are read in order. The row starts `ci` and `bk` are locals, and `av` is read once per `k` before the inner loop. This is the shape of section 2, so the vectoriser makes it NEON code. (Form 1 in the file above is this loop.)

The summary measured this form at about 1.9 times `clang -O2` after the vectoriser (section 5).

### 4.3 4x8 register block

This kernel keeps eight `f32x4` accumulators (4 rows of `C`, 8 columns) in registers. For every `k` it loads two vectors of `B` and four numbers of `A`, then does eight multiply-adds. The file header says: "C = A*B, 4x8 register block: 8 accumulators; per k: 2 loads of B (8 floats), 4 numbers of A, 8 multiply-adds".

The whole file (`mk.jk`, the same `main` as `gemm.jk`):

```jk
#import <stdlib>
#import <simd>
#import <time>
// C = A*B, 4x8 register block: 8 accumulators; per k: 2 loads of B (8 floats), 4 numbers of A, 8 multiply-adds
void kern(float^ a, float^ b, float^ c, int n) {
    int i = 0;
    while i < n {
        int j = 0;
        while j < n {
            f32x4 c00 = {0.0, 0.0, 0.0, 0.0}; f32x4 c01 = {0.0, 0.0, 0.0, 0.0};
            f32x4 c10 = {0.0, 0.0, 0.0, 0.0}; f32x4 c11 = {0.0, 0.0, 0.0, 0.0};
            f32x4 c20 = {0.0, 0.0, 0.0, 0.0}; f32x4 c21 = {0.0, 0.0, 0.0, 0.0};
            f32x4 c30 = {0.0, 0.0, 0.0, 0.0}; f32x4 c31 = {0.0, 0.0, 0.0, 0.0};
            int ai = i * n;
            int bj = j;
            for k in 0..n {
                f32x4 b0 = f32x4::load(b, bj);
                f32x4 b1 = f32x4::load(b, bj + 4);
                float a0 = a[ai + k];
                float a1 = a[ai + n + k];
                float a2 = a[ai + 2 * n + k];
                float a3 = a[ai + 3 * n + k];
                c00 = c00 + b0 * a0; c01 = c01 + b1 * a0;
                c10 = c10 + b0 * a1; c11 = c11 + b1 * a1;
                c20 = c20 + b0 * a2; c21 = c21 + b1 * a2;
                c30 = c30 + b0 * a3; c31 = c31 + b1 * a3;
                bj += n;
            }
            c00.store(c, i * n + j); c01.store(c, i * n + j + 4);
            c10.store(c, (i + 1) * n + j); c11.store(c, (i + 1) * n + j + 4);
            c20.store(c, (i + 2) * n + j); c21.store(c, (i + 2) * n + j + 4);
            c30.store(c, (i + 3) * n + j); c31.store(c, (i + 3) * n + j + 4);
            j += 8;
        }
        i += 4;
    }
}
int main() {
    int n = 512;
    float^ fa = (float^)Mem::alloc(n * n * 4);
    float^ fb = (float^)Mem::alloc(n * n * 4);
    float^ fc = (float^)Mem::alloc(n * n * 4);
    for i in 0..n * n { fa[i] = (float)(i % 13) * 0.5; fb[i] = (float)(i % 7) * 0.25; fc[i] = 0.0; }
    int t0 = Time::mono_ns();
    kern(fa, fb, fc, n);
    int t1 = Time::mono_ns();
    double ms = (double)(t1 - t0) / 1000000.0;
    double flops = 2.0 * (double)n * (double)n * (double)n;
    jout << ms << " ms  " << flops / ms / 1000000.0 << " GFLOPS  check " << fc[12345] << "\n";
    return 0;
}
```

Limits of this code, as written:

- It has no edge handling. The row loop steps by 4 and the column loop by 8, so `n` must be a multiple of 8.
- The file is `~/.tmpj/mk/mk.jk`. The summary says the kernel is on branch `n4` (work in progress). It is not merged into `dev`, and it is not in the test suite. Its timing was not measured on a quiet phone.

## 5. Measured ratios to C

Each line is a number that `docs/PROJECT_SUMMARY.md` states. I did not measure these again for this page. All of them are **measured on one phone, noisy**: the phone changes speed by up to 3 times with its load, so only the ratio is meaningful, and the load is given where the summary gives it. Ratio = J2K time / C time, lower is better.

| date (summary section) | loop | J2K / C | note |
|---|---|---|---|
| 2026-11-04 (status, 1.2.12 in dev) | float update | 2.2 (52 vs 24 ms) | measured on one phone, noisy, load 44 |
| 2026-11-04 (status, 1.2.12 in dev) | int sum | 1.2 (29 vs 24 ms) | measured on one phone, noisy, load 44 |
| 2026-11-04 (status, 1.2.12 in dev) | fib | 1.14 (74 vs 65 ms) | measured on one phone, noisy, load 44 |
| 2026-11-04/05 (1.2.13 section) | float sum | 0.75 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | float update | 0.76 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | int sum | 0.6 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | sieve | 0.9 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | fib(35) | 1.28 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | 1M small arrays | 1.54 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | vec3 | 1.55 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | matmul | about 2.5 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-04/05 (1.2.13 section) | mandel | about 1.8 | measured on one phone, noisy, C = clang -O2 |
| 2026-11-05 (`docs/LIMITS.md`) | float update | 0.8 | measured on one phone, noisy |
| 2026-11-05 (`docs/LIMITS.md`) | integer sum | about 1.1 | measured on one phone, noisy |
| 2026-11-05 (`docs/LIMITS.md`) | matrix multiply, row form | about 1.9 | measured on one phone, noisy |
| 2026-11-05 (`docs/LIMITS.md`) | plain triple loop | 1.6 to 2.5 | measured on one phone, noisy |
| 2026-11-05 (vec3 section) | vec3 with `vec3` variables vs plain `double`s | 1.47 (264 vs 180 ms; C 183 ms) | measured on one phone, noisy |
| 2026-11-05 night (matrixidx) | GEMM ikj (section 4.2) | about 1.9 (610 ms vs 300 to 340 ms) | measured on one phone, noisy |
| 2026-11-05 night (matrixidx) | GEMM ijk (section 4.1) | 1.6 | measured on one phone, noisy |
| 2026-11-05 late (matrixidx) | GEMM | 1.5 to 1.6 | measured on one phone, noisy, load 47, a rough ratio |

The entries do not agree everywhere: the 2026-11-04/05 section gives int sum 0.6, `docs/LIMITS.md` gives about 1.1 for the same day, and the matrix product is 2.5 in one entry and 1.9 in another. Both values are in the table because both are what the summary states. The newest entries for GEMM are the ones in the 2026-11-05 lines. The summary says that the ijk form still needs unroll-and-jam (design 31, lever L7); that work is not in any released version.

## 6. Switches

Each switch is read by `jcmp/jcmp.jk`. `-nofma` is listed in `jcmp -help`; the other three are accepted, and they are not in `-help`.

| switch | effect | use it to |
|---|---|---|
| `-novec` | no loop is made into NEON code | compare the vector and scalar code; run on a machine without NEON |
| `-nofma` | `a * b + c` is not fused into one `fmadd`/`fmla` | get the same bits as a build without fusion (fusion can change the last bit of a result) |
| `-nopeep` | the peephole rules of the register pass are off | find out whether a peephole rule changed a result |
| `-noir` | the IR passes are off (this includes the vectoriser) | compare with the simplest code the compiler makes |

Other switches that help with speed work: `-irdbg 4194304` (why the vectoriser gave up on a loop), `-irdbg 8388608` (the IR before the vectoriser), `-emit-asm file.jasm` (the ARM64 text), `-j N` (how many processes the compiler uses to compile; it is not a run-time switch), and `-d` (array bounds checks; a debug build, not for timing).

## 7. How to measure fairly

- **Interleave** the J2K program and its C twin. Run one, then the other, then the first again, and so on. Do not time one language in the morning and the other in the evening: the phone's speed changes with its load.
- Take the **best of N** runs (the summary used 5 to 7). Report the ratio and the load of the phone (`uptime`).
- Check `nproc` before a timing. The summary records a day when the shell got two cores instead of eight and everything was about six times slower; such a run is not a timing.
- Do not run the test suite or a diff check at the same time as a timing.
- Check the output as well: both programs must print the same value.
- Write down the switches used. A timing with `-novec` or `-noir` is a different measurement.

## 8. Threads

- **`#multithread`** before a `for i in a..b` loop shares the iterations among the cores (at most 16 parts). The body must not touch the same data from two iterations, or it must use a `Mutex`. It may not contain `break`, `return`, or another `#multithread`. The example is in `docs/LANGUAGE.md`.
- **Threads by hand:** `create(fn, arg)` starts a thread and `join()` waits for it. `std/neuron.j` does this in `Tensor32::matmul` for big products: it makes up to four threads, each computes a range of rows (`create(mm_rows, (void^)t)`), and then it joins them.
- The thresholds in `std/neuron.j` (read from the file): `Tensor32::matmul` runs on one thread below 2,500,000 multiply-adds (a 2-row kernel when `n` is a multiple of 4, else the plain loop). At or above that it packs the numbers and uses four threads, unless the product has fewer than 16 rows. `Tensor::matmul_fast` uses the plain loop below 32,768 multiply-adds.
- The file comment says that the threads give about 3.5 times the one-core speed (`bench/dot.jk`). That is the file author's measurement; it is not measured on this page.
- Threads and vectors work together: the threaded kernels use the same `f32x4` code.
