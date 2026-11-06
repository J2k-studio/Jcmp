# Moving to Jcmp 1.2.23: `int` is 32 bits

Until 1.2.22 `int` was a 64-bit integer. From 1.2.23 `int` is a **32-bit** integer (the type that was called `i32`; `i32` is still accepted as another name),
and the 64-bit integer is **`i64`**. `int + int` wraps around at 32 bits, as in C and Java. A number that does not fit 32 bits is an `i64`.
The reasons: arrays of `int` take half the memory and cache, SIMD takes twice as many numbers in one register, and the names are the ones of C, Java and Rust.

A program that was written for 64-bit `int` keeps its meaning if every type word `int` is written `i64`. The tool does it for you (not in comments or text):

```
python3 tools/int2i64.py program.jk other.j        # rewrites the files in place
```

Then, file by file, you can write `int` again where 32 bits are enough (loop counters, small numbers, array elements).
Things to look at by hand: sizes and offsets (use `i64`), numbers that can pass 2147483647 (use `i64`), and `main` (it may stay `i64` or `int`).
`sizeof(int)` is 4 and `sizeof(i64)` is 8.
