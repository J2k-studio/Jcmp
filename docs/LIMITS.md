# Known limits

What jcmp does not do, or does less well, today. A limit that has a workaround says so. This page is kept up to date with every release.

## Targets
* **Linux ARM64** is the main target: the whole language, the whole library, the checks of `-d`.
* **Linux ARM32** (`-target arm32`, ELF32, EABI 5): runs on a 64-bit ARM Linux machine that runs 32-bit programs (an Android phone does). The same source builds for both. It needs a CPU with the integer divide instructions and VFP/NEON (ARMv7-A and newer, every ARMv8 phone).
  * Not on ARM32: the checks of `-d` (the compiler says so), `Cpu::inst` of an instruction that is not in the list of docs/syntax-design.md section 84 (`ubfx`, `udiv`, `umull`, `ldrex` ... are), the system registers `Sys::name`, `Cache::clean / invalidate / zero` (privileged), `#pragma read` (read-only data), instructions of ARM64 written as text. `raw<u32>[...]` takes the machine words of the target you build for.
  * Speed: ARM32 programs run at about 1.7x to 5.6x of the ARM64 time on the benchmarks of tools/bench (mandel 1.7x, gcd 2.4x, fib 2.7x, matmul 2.9x, nbody 3.5x, loop 4.8x, arrays 5.6x); the slowest are the ones that work on 64-bit whole numbers all the time (qsort about 7x, sha256 about 11x), because the CPU has 32-bit registers. See tools/bench/baseline32.txt.
  * A multiply and an add are not fused into one instruction on ARM32 (`fma`), so the last bit of a floating-point result can differ from ARM64.
  * The numbers above come from `tools/bench/baseline32.txt` (1.7x to 11.2x of the ARM64 time); the main reason is that there is little register allocation on ARM32 yet.
* No x86_64, Windows or macOS target yet.

## Numbers and speed (ARM64)
* `int` is 64 bits on every target. There is no 32-bit `int`; `i32`, `u32` and the other widths are for storage (arrays, struct fields) and casts.
* The benchmarks of the repository are within 1.5 times of `clang -O2`, except a loop that divides the counter by a constant (3.6 times): clang proves that the counter fits in 32 bits and vectorizes the division.
* Measured on the phone against `clang -O2` (interleaved, the phone changes speed with its load, so only ratios count; the numbers are from 2026-11-05 on the development branch, not yet released): updating a float array 0.8x, integer sum about 1.1x, sieve 0.9x, small arrays 1.5x, matrix multiply (`c[i*n+j] += a*b`, row form) about 1.9x and the plain triple loop about 1.6x to 2.5x, because J2K does not yet use several independent accumulators; struct temporaries (`vec3`) about 1.5x. Loops over arrays are vectorised with NEON when the compiler can show that the arrays do not overlap or can test it at run time.
* Training a model on the phone: use `<neuron>` (`matmul_fast`, float32, threads) for the heavy part; plain loops are slower than a tuned kernel.

## Language
* No separate compilation: a program is compiled from all its sources into one executable (the cache keeps the code of the functions that did not change).
* A `#multithread` loop cannot be nested, and its body may not use `try`.
* Interfaces (`itf`): a struct has one base or one interface, not both and not several (planned).
* No `async` / `await` yet; threads are in `<cpu>` (`Thread`, `Mutex`, `Atomic`).

## Library
* Network: IPv4 only. `https` is TLS 1.3 with the check of the certificate chain; there is no server side of TLS.
* The libraries `simd`, `quat`, `complex`, `stats`, `canvas` and `screen` are downloaded with `jc lib install NAME` (the index is the repository `Jcmp-libs` on GitHub; the checksum is checked before a file is installed). Libraries of other authors are not listed yet.
* [API.md](API.md) lists every function of every library; some are helpers of the library (the steps of a hash, for example) that the compiler does not hide yet.

## Tools
* `jcmp -d` (memory and bounds checks) is for ARM64 programs.
* The debugger is not written yet. The formatter exists: `jcmp fmt` (see USAGE.md).
