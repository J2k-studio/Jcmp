# J2K against C and C++ (same programs, 2026-10-30)

    jcmp b.jk -o bj;  clang -O2 b.c -o bc;  clang++ -O2 b.cpp -o bcpp;  ./bj N   (N = 0 .. 5)

Kirin 990, one run each, the best of 7, **on a busy phone (load about 46)**: the numbers show the order of things, not exact times. Clang 21 at -O2; C++ uses `std::vector`. All three print the same results.

| program | J2K | C | C++ | J2K / C |
|---|---|---|---|---|
| 0 fib(35), calls | 71 ms | 65 | 68 | 1.1 |
| 1 float sum, 20M | 68 | 37 | 38 | 1.8 |
| 2 float update `y[k] = y[k]*0.5 + x[k]`, 20M | 112 | 24 | 30 | 4.7 |
| 3 int sum, 20M | 42 | 24 | 33 | 1.8 |
| 4 sieve of 5M | 101 | 69 | 68 | 1.5 |
| 5 one million small arrays (malloc / `arr`) | 61 | 20 | 26 | 3.0 |

Compile time of the program: J2K 0.32 s, clang 1.3 s (clang++ the same). Size: J2K 28 KB (no libc), C 7 KB (dynamic), C++ 44 KB (dynamic).
Where the gap is: clang vectorises the loops 2 and 3 (four floats at a time) and keeps the array pointer in a register; J2K reloads the array header and checks it for null in every access (design 25, section 6). The allocator of J2K takes 40 ns for a small array against 20 ns of malloc.
