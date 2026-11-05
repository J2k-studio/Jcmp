# tools/bench/langs, 2026-11-05 (phone load ~50: only ratios count; best of 4-5 rounds, each program inside is best of 3; interleaved J2K / C -O2 / Java / node)

Before (compiler of branch matrixidx), ms:

| program | J2K | C -O2 | Java | node | J2K/C | J2K/Java |
|---|---|---|---|---|---|---|
| fib(35) | 250 | 137 | 236 | 837 | 1.8 | 1.06 |
| sieve 5M | 324 | 247 | 290 | 348 | 1.3 | 1.12 |
| mandel 400x300 | 97 | 68 | 80 | 86 | 1.4 | 1.21 |
| matmul 200 (ijk) | 135 | 49 | 98 | 152 | 2.8 | 1.38 |
| qsort 1M | 319 | 165 | 268 | 1178 | 1.9 | 1.19 |

Finding: **every access to a global array that is more than 32 KB from the base register (x28) cost five instructions** (`add`, `mov`, `movk`, `add`, `ldr`): the assembler built the offset in x17. All five programs keep their data in globals.

Fix (jc_asm.j, `as_h_mem`): an offset up to 16 MB is one `add x17, xN, #(off >> 12), lsl #12` plus the access with the low 12 bits. Test t580_far_global (int, char, double, float, u32 arrays beyond 32 KB; equal with `-nopeep`, `-noir`, `-noir -noregs -nopeep` and with the old compiler).

After (same session, interleaved), ms:

| program | J2K | C -O2 | Java | J2K/C | J2K/Java |
|---|---|---|---|---|---|
| fib | 260 | 139 | 209 | 1.9 | 1.24 |
| sieve | 339 | 273 | 277 | 1.2 | 1.22 |
| mandel | 106 | 77 | 84 | 1.4 | 1.26 |
| matmul | 136 | 65 | 102 | 2.1 | 1.33 |
| qsort | 311 | 246 | 372 | 1.3 | 0.84 |

A direct old-vs-new run (3 rounds, J2K only): matmul 172 -> 119, qsort 373 -> 278, sieve 379 -> 295, mandel 116 -> 101, fib 268 -> 261. The phone's speed drifted between the sessions, so compare the ratios inside one table.

Still above Java: fib (the frame and the saved registers are built before the base case: shrink-wrapping, L10), sieve (the `mov x0, 0; strb x0` pair and the `add x8, x22, x28` address instead of `strb wzr, [x28, x22]`), mandel (dependent fmul/fadd chain: FMA with a reused product, L6), matmul ijk (dependent chain: unroll-and-jam, L7). Next cheapest: put the base `x28 + (off & ~4095)` of a global array in a register for the whole loop (one `add` less per access), `strb wzr`.
