# Calling J2K from other languages (shared libraries)

A J2K file with `export` functions and no `main` becomes a shared library (`.so`) that a C program,
a Java program (JNI) or Python (`ctypes`) can load. Everything in this guide was built and run on the
author's phone (Termux, ARM64, Linux, 2026-11-05). Where a step was not run, the text says so.

## 1. Write the library

```jk
// mylib: functions that C, Java and Python can call
export int add(int a, int b) { return a + b; }
export double half(double x) { return x / 2.0; }
export int count_char(char^ s, char c) {
    int n = 0;
    int i = 0;
    while s[i] != 0 {
        if s[i] == c { n += 1; }
        i += 1;
    }
    return n;
}
export int sum_ints(int^ p, int n) {
    int t = 0;
    for i in 0..n { t = t + p[i]; }
    return t;
}
export void scale_doubles(double^ p, int n, double k) {
    for i in 0..n { p[i] = p[i] * k; }
}
export int fill_squares(int^ out, int n) {
    for i in 0..n { out[i] = i * i; }
    return n;
}
```

Build it with `-l`:

```
jcmp mylib.jk -l -o libmy.so
```

## 2. What crosses the border

| J2K type | C type | Python (ctypes) | Notes |
|---|---|---|---|
| `int` | `int64_t` (`long long`) | `c_longlong` | **`int` is 64 bits.** A C `int` (32 bits) gives wrong answers for arrays. |
| `double` | `double` | `c_double` | |
| `float` | `float` | `c_float` | tested in the repository (`fhalf`), not in this guide |
| `char` | `char` | `c_char` | |
| `int^`, `double^`, `char^` | pointers | `POINTER(...)`, `c_char_p` | the caller owns the buffer |
| `String`, arrays, structs | not yet | not yet | the compiler says so when you use them |

* At most 8 parameters per exported function.
* The library has its own globals and its own heap. Only numbers and pointers cross the border.
* The functions without `export` stay inside the library.
* The docs say `jout` inside a library is "not yet"; the repository test `t502` prints from one. Avoid it.

## 3. From C: `dlopen`

Linking with `-lmy` does **not** work yet: the linker finds no symbols in the file
(`ld.lld: error: undefined symbol: add`). The file's section table has no `.dynsym` (only the string table
and the dynamic section), so use `dlopen`, which reads the dynamic segment:

```c
#include <stdio.h>
#include <dlfcn.h>
#include <stdint.h>
int main(void) {
    void *h = dlopen("./libmy.so", RTLD_NOW);
    if (!h) { printf("dlopen: %s\n", dlerror()); return 1; }
    int64_t (*add)(int64_t, int64_t) = dlsym(h, "add");
    double (*half)(double) = dlsym(h, "half");
    int64_t (*count_char)(const char *, int64_t) = dlsym(h, "count_char");
    int64_t (*sum_ints)(int64_t *, int64_t) = dlsym(h, "sum_ints");
    void (*scale_doubles)(double *, int64_t, double) = dlsym(h, "scale_doubles");
    int64_t (*fill_squares)(int64_t *, int64_t) = dlsym(h, "fill_squares");
    int64_t nums[5] = {1, 2, 3, 4, 5};
    double ds[3] = {1.0, 2.5, 4.0};
    int64_t sq[6] = {0};
    printf("add %lld\n", (long long)add(2, 3));
    printf("half %g\n", half(5.0));
    printf("count %lld\n", (long long)count_char("banana", 'a'));
    printf("sum %lld\n", (long long)sum_ints(nums, 5));
    scale_doubles(ds, 3, 2.0);
    printf("scaled %g %g %g\n", ds[0], ds[1], ds[2]);
    fill_squares(sq, 6);
    printf("squares %lld %lld %lld\n", (long long)sq[0], (long long)sq[3], (long long)sq[5]);
    return 0;
}
```

```
clang main_dl.c -o main_dl -ldl && LD_LIBRARY_PATH=. ./main_dl
```

Output:

```
add 5
half 2.5
count 3
sum 15
scaled 2 5 8
squares 0 9 25
```

## 4. From Python: `ctypes`

```python
import ctypes
lib = ctypes.CDLL("./libmy.so")
ll = ctypes.c_longlong                      # a J2K int is 64 bits: use c_longlong, not c_int
lib.add.argtypes = [ll, ll]; lib.add.restype = ll
lib.half.argtypes = [ctypes.c_double]; lib.half.restype = ctypes.c_double
lib.count_char.argtypes = [ctypes.c_char_p, ctypes.c_char]; lib.count_char.restype = ll
lib.sum_ints.argtypes = [ctypes.POINTER(ll), ll]; lib.sum_ints.restype = ll
lib.scale_doubles.argtypes = [ctypes.POINTER(ctypes.c_double), ll, ctypes.c_double]
lib.fill_squares.argtypes = [ctypes.POINTER(ll), ll]; lib.fill_squares.restype = ll

print("add", lib.add(2, 3))
print("half", lib.half(5.0))
print("count", lib.count_char(b"banana", b"a"))
nums = (ll * 5)(1, 2, 3, 4, 5)
print("sum", lib.sum_ints(nums, 5))
ds = (ctypes.c_double * 3)(1.0, 2.5, 4.0)
lib.scale_doubles(ds, 3, 2.0)
print("scaled", ds[0], ds[1], ds[2])
sq = (ll * 6)()
lib.fill_squares(sq, 6)
print("squares", sq[0], sq[3], sq[5])
```

```
python3 -I lib_ctypes.py
```

Output:

```
add 5
half 2.5
count 3
sum 15
scaled 2.0 5.0 8.0
squares 0 9 25
```


## 5. From Java: JNI

The name of the exported function is the JNI name of the Java method: `Java_<package>_<class>_<method>`,
with the dots of the package written as `_`. JNI passes the environment and the class first, so the
J2K function takes two extra `int` parameters.

```jk
// JNI entry: Java's `static native int add(int a, int b)` of com.jaric.app.Core
export int Java_com_jaric_app_Core_add(int env, int cls, int a, int b) { return a + b; }
```

```java
package com.jaric.app;
public class Core {
    static { System.loadLibrary("jnimy"); }      // loads libjnimy.so from java.library.path
    public static native int add(int a, int b);
    public static void main(String[] args) {
        System.out.println("add " + add(2, 3));
    }
}
```

```
jcmp jnimy.jk -l -o libjnimy.so
javac com/jaric/app/Core.java
java -Djava.library.path=$PWD -cp . com.jaric.app.Core
```

Output:

```
add 5
```

This was run on the phone with the Termux Java. The Android app path (an `apk` that loads the library
through `System.loadLibrary`) is in [APP_PACKAGING.md](APP_PACKAGING.md); it was not run here.

## 6. Pitfalls

* **Sizes.** A J2K `int` is 64 bits. With C `int` arrays the values come out wrong (we saw `sum 29`
  instead of `15` and zeros in the output array). Use `int64_t`, `long long` or `c_longlong`.
* **Strings.** Pass a `char^` (a C string, `b"banana"` in Python). Do not expect `String` to cross.
* **Memory.** The library's own heap is not the caller's. The test `t502` allocates a block with
  `Mem::alloc` and frees it with `Mem::free` before it returns; a caller never frees library memory.

## See also

* [LANGUAGE.md](LANGUAGE.md) "Shared libraries: `export` and `-l`" (the rules in short)
* [SYSTEMS.md](SYSTEMS.md) for pointers and the heap
* [GUIDES.md](GUIDES.md) for the other guides
