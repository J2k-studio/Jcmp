# bench: the speed of J2K against C (the first numbers, 2026-10-29, Kirin 990, clang -O2, one core)

`matmul.jk` / `matmul.c`: C = A x B, 128 x 128, three ways. Run: `jcmp matmul.jk -o m && ./m` and `clang -O2 matmul.c -o mc && ./mc`.

| Way | C (clang -O2) | J2K (jcmp 1.2.4) | J2K / C |
|---|---|---|---|
| double, scalar | 1.15 GFLOPS | 0.42 - 0.58 | 2.0 - 2.7 x slower |
| float32, scalar | 2.01 | 0.37 - 0.47 | 4.3 - 5.4 x slower |
| float32, NEON by hand (4 lanes) | 6.8 - 7.9 | 0.74 - 0.95 | 7.5 - 10 x slower |

What the code of the inner loop (`-show`) says: the vector `av` is rebuilt from memory for every lane; every loop step reloads the pointers from the stack and recomputes `j * 4`, the address and the offset (`mul`, `add`, `lsl` for each access); `cv + av * bv` is `fmul` then `fadd` (not one `fmla`); the values live in stack slots, not in registers across the loop. So the work for the compiler (Phase 5.5) is: keep loop values in registers, hoist what does not change in the loop (strength reduction of `i * n + j * 4`), use fused multiply-add, build `{a, a, a, a}` with one `dup`, and unroll a little. With these the NEON line should come within 1.5 x of C.
Targets by release: scalar float32 within 1.5 x of C, NEON within 1.5 x, then 1.2 x.

## llama_bench.jk (neuron 0.5 / llama 0.1.1)
`llama_bench model.gguf [new tokens]` prints the load time, tokens per second for the prompt and for new tokens, milliseconds per token and the memory of the program. Kirin 990, one core, 2026-10-30:

| model | load | tokens/s | memory |
|---|---|---|---|
| stories15M-q4_0 (15M parameters) | 1.0 s | 82 | 124 MB after load |
| stories260K (0.26M) | 0.05 s | about 600 | small |

The energy per token (joules) needs the battery counters of Android, which a Termux program cannot read (`/sys/class/power_supply` is not visible); the Jaric app can read them with `BatteryManager` and will print it.
