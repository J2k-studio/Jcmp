# SIMD: vector types, loops, and looking at the machine code

J2K has two ways to use the 128-bit NEON registers of ARM64. You can write vector values yourself
(`f32x4`, `f64x2`, `i32x4`, `i8x16` from `#import <simd>`), or write plain loops over arrays and let the
compiler's vectoriser use NEON for them. Everything here was compiled and run on the author's phone
(Kirin 990, ARM64, Termux, 2026-11-05). Timings are not in this guide: no benchmark was run for it.

## 1. The four vector types

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    f64x2 a = {1.5, 2.5};                 // two doubles:    a.x a.y
    i64x2 n = {7, 8};                     // two 64-bit ints: n.x n.y
    f32x4 f = {1.0, 2.0, 3.0, 4.0};       // four floats:    f.x f.y f.z f.w
    i32x4 m = {10, 20, 30, 40};           // four 32-bit ints: m.x m.y m.z m.w
    jout << a.y << " " << n.y << " " << f.w << " " << m.z << "\n";
    return 0;
}
```

Output:

```
2.500000 8 4.000000 30
```

| Type | Lanes | Element | Load / store element size |
|---|---|---|---|
| `f64x2` | 2 | `double` | 8 bytes |
| `i64x2` | 2 | `int` (64 bits) | 8 bytes |
| `f32x4` | 4 | `float` | 4 bytes |
| `i32x4` | 4 | `i32` | 4 bytes |
| `i8x16` | 16 | `i8` | 1 byte (the index counts bytes) |

The lanes are named like the parts of `vec3`. Each value is 16 bytes, one NEON register.

## 2. Operators

`+ - *` and `/` (floats only) work lane by lane in one instruction. A number on one side is used for
every lane. Both sides must have the same type. `i64x2` has no `*`.

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    f64x2 a = {1.5, 2.5};
    f64x2 b = {2.0, 4.0};
    f64x2 c = a + b * 2.0;                // (1.5 + 4, 2.5 + 8)
    jout << c.x << " " << c.y << "\n";
    i32x4 m = {10, 20, 30, 40};
    i32x4 k = m * m + m;
    jout << k.x << " " << k.w << "\n";
    return 0;
}
```

Output:

```
5.500000 10.500000
110 1640
```

## 3. Loads and stores of arrays

`T::load(array, i)` reads the lanes starting at element `i`; `v.store(array, i)` writes them back.

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    double arr[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    f64x2 v = f64x2::load(@arr[0], 2);    // arr[2], arr[3]
    v.store(@arr[0], 4);                  // arr[4] = v.x, arr[5] = v.y
    jout << arr[4] << " " << arr[5] << "\n";
    return 0;
}
```

Output:

```
3.000000 4.000000
```

Inside a loop the vectors stay in NEON registers.

## 4. Reductions: `sum`, `min`, `max`

`v.sum()`, `v.min()` and `v.max()` give the sum, the smallest and the largest lane. For four lanes
`sum()` is `(x + y) + (z + w)`.

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    f32x4 f = {1.0, 2.0, 3.0, 4.0};
    jout << f.sum() << " " << f.min() << " " << f.max() << "\n";
    i32x4 m = {10, 20, 30, 40};
    jout << m.sum() << "\n";
    return 0;
}
```

Output:

```
10.000000 1.000000 4.000000
100
```

## 5. `i8x16` and the int8 dot product

`i8x16` holds sixteen bytes, made for quantised numbers. `a.dot(b)` multiplies the bytes in groups of
four and adds them: every 32-bit lane of the result is the sum of four products (lanes 0-3, 4-7, 8-11,
12-15). That is sixteen multiply-adds in one instruction (`SDOT`, Cortex-A76 and newer; not on the
ARM32 target).

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    i8 bytesA[16];
    i8 bytesB[16];
    for i in 0..16 { bytesA[i] = (i8)(i + 1); bytesB[i] = (i8)2; }
    i8x16 x = i8x16::load(@bytesA[0], 0);
    i8x16 y = i8x16::load(@bytesB[0], 0);
    i32x4 d = x.dot(y);
    jout << d.sum() << "\n";             // 2 * (1 + 2 + ... + 16)
    return 0;
}
```

Output:

```
272
```

## 6. The vectoriser: which loops get NEON

You do not write these. A loop over arrays that does the same thing to every element is run two
elements (`double`) or four (`float`, `int`) at a time, with a scalar loop for the rest. The
result is the same as the scalar loop; `-novec` turns this off to check it.

What the compiler did, measured on 2026-11-05 by counting the vector-register lines of each function in
`--emit-asm` output (the function `v_...` in a test file, arrays of 64 elements):

| Loop | Vectorised? |
|---|---|
| `dc[i] = da[i] + db[i] * k` on global `double` arrays | yes |
| `fc[i] = fa[i] + fb[i] * k` on global `float` arrays | yes |
| `y[i] = x[i] * 2.0 + 1.0` on local fixed arrays | yes |
| `c[i] = a[i] * 2.0` on `float[]` made with `arr(n)` | yes |
| `ib[i] = ia[i]` (a copy of `int`) | yes |
| `c[i] = a[i] * 2.0` with **pointer parameters** `float^` or `double^` | no (in this test) |
| `da[i] = da[i - 1] + 1.0` (each turn needs the one before) | no (correct) |
| `s = s + da[i]` (a `double` sum; the order of additions is kept) | no (correct, as the test `t370` expects) |

Pointer parameters were not vectorised in this test; use a global or a local array, or write the NEON
code yourself with `f32x4::load` if the data arrives as a pointer.

Three habits help the compiler (from the tutorial, lesson 90): keep row offsets in plain local `int`
variables, read an unchanging number into a local before the loop, and do not call a function in the
loop. If two arrays might overlap, the compiler tests it at run time and uses the scalar loop.

```jk
#import <stdlib>
using stdlib;

float a[10];
float b[10];
float c[10];

void madd(int n, float k) {
    for i in 0..n {
        c[i] = a[i] + b[i] * k;
    }
}

int main() {
    int n = 10;
    for i in 0..n { a[i] = (float)i; b[i] = 0.5; }
    madd(n, 2.0);
    float s = 0.0;
    for i in 0..n { s = s + c[i]; }
    jout << c[9] << " " << s << "\n";
    return 0;
}
```

Output:

```
10.000000 55.000000
```

Run with `-novec` (`jcmp prog.jk -novec -o prog`): the same output (checked).

## 7. Fused multiply-add

`a * b + c` on `double` is one instruction (`fmadd`) when the product is used only by that addition.
The result has one rounding instead of two, so its last bit can differ from `-nofma` (which keeps
the two roundings).

Measured: in the dot-product loop `s = s + x[i] * y[i]` the assembler listing had one `fmadd`;
the same program with `-nofma` had none; both printed `10.000000`. In a plain function
`double mul_add(double a, double b, double c) { return a * b + c; }` the listing had `fmul` and `fadd`
and no `fmadd` in this test, so do not rely on the fusion in that shape.

## 8. Looking at the machine code

```
jcmp prog.jk --emit-asm prog.jasm -o prog     # the whole assembler text
jcmp prog.jk -show NAME                       # the code of one function, with its instruction count
```

`--emit-asm` gives the whole listing; each function starts with its name followed by `:`. `-show`
prints one function's code and its instruction count, but in a test it printed only the first 18 lines of
a float loop function (the listing from `--emit-asm` had 67 lines, with the NEON code), so use
`--emit-asm` to see a whole loop.

Counting the NEON lines of a function in the listing is a quick check that a loop was vectorised:
look for `v17.2d`, `ldr q17`, `fmul v17.4s`, `fmla`.

## 9. Limits

* `i8x16::dot` is not on the ARM32 target (the compiler says so).
* `i64x2` has no `*`; `/` needs a float type; both sides of an operator must have the same type.
* A sum of floating-point values keeps its order (the test `t370` checks it), so such a loop stays scalar.
* No timings in this guide (see [PERFORMANCE.md](PERFORMANCE.md) when it is written).

## See also

* [SYSTEMS.md](SYSTEMS.md) for the arrays and the pointers the loops use
* [LANGUAGE.md](LANGUAGE.md) "`#import <simd>`" and "Fused multiply-add"
* [USAGE.md](USAGE.md) for `-novec`, `-nopeep`, `-noir`
