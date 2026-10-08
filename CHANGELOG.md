# Changelog

## 0.9.0
* **Lambdas:** a function without a name where you use it: `(int a, int b) -> int { return a + b; }`, `() -> void { ... }`. It gives a function pointer, so it can be passed to a function or kept in `int(int, int)^ f = ...;`. It cannot use the variables around it (a clear message says so).
* `->` is a token now.

## 0.8.1
* **A `throw` frees what the left functions owned:** arrays, Strings, `alloc` blocks, Strings made inside a statement and structs with `free(self)` are freed on the way to the `catch` (innermost first). Before, they leaked. Cost: about ten instructions when an owner is made.
* Warnings are bright yellow now (a fixed colour that does not depend on the terminal theme).

## 0.8.0
* **`#import`** (with the `#`, like `#define`): `#import <stdlib>`, `#import "file"`. A plain `import` still works with a warning `[-Wimport]`; a later version makes the `#` required.
* **`cout` and `cin` handle every type**, decimals included. `coutf` and `cinf` still work with a warning `[-Wdeprecated]`.
* **A function that must return a value but has no `return` at all is an error** (`make it void, or return something`). A path that reaches the end without `return` still throws at run time (0.7.1).
* New warnings: `-Wunused` (a local variable that is declared and never used).
* Removed the check "cout cannot print a float" (floats print with `cout` now).

## 0.7.1
* **A function that ends without `return`** (and returns a value) now throws `a function ended without returning a value` instead of giving a junk number. A normal `return` costs nothing extra. `main` without `return` still gives 0, as in C.
* A missing `<<` in `cout` (or `>>` in `cin`) is explained: `expected ';' or '<<' here (is a '<<' missing between two values?)`.

## 0.7.0
* **`import <library>`** for libraries and **`import "file"`** for your own files. A library is looked up in `-I`, `J2K_PATH`, `~/.j2k/lib` and the `lib` folder next to the compiler.
* **`std` is now `stdlib`:** `import <stdlib>`, `using stdlib`, `using stdlib::math`. `cpu` is `import <cpu>`. The old forms (`import std`, `using std`, a bare `import cpu`) still work with a warning (`[-Wdeprecated]`, `[-Wimport]`).

## 0.6.0
* **Collections:** `Map<K,V>` (`put get has remove len keys_list values_list`), `Set<T>` (`add has remove len items_list`) in the standard library; keys can be numbers, chars, pointers or Strings. `get` throws `key not found`.
* **`String[]`**: an array of Strings (it owns them). **List methods** on every dynamic array: `insert`, `remove`, `sort`, `contains`, `index_of`.
* **`for x in list { }`** over a dynamic array, a `String[]`, a String (its characters), a fixed array or a list returned by a call.
* **A struct with a method `free(self)` is freed by the compiler** at the end of the block of a local variable (also on `return`, `break`, `continue`). It starts zeroed and cannot be copied, passed or returned by value.
* Warnings are yellow (they were orange).

## 0.5.0
* **Names of the decimal types:** `float` (32 bit) and `double` (64 bit), as in C. `f32` and `f64` still work, with a warning `[-Wdeprecated]`.
* **`cout`, `coutf`, `cin`, `cinf` need `import std` and `using std`.** A program without them gets the warning `[-Wstd]` (a later version makes it an error). Update your programs: put `import std` and `using std` at the top.
* `using std` makes `Sys`, `Mem`, `Str`, `Math` and `File` usable without the prefix; a name that is in two of them (`write`) is an error that tells you to write `File::write`.

## 0.4.0
* **`String`**: text that grows. `String s = "hi";`, `a + b`, `a == b`, `s += x`, `s.len`, `s[i]`, `push pop append clear find slice c`, `cin >> s`. `String b = a;` makes a copy; Strings are freed at the end of their block, and a String made by an expression is freed at the end of the statement.
* **Generics** (since 0.3.1) are described in the tour (`docs/LANGUAGE.md`) and the tutorial (lessons 12 and 13).
* Functions that return `char^` (a text) can be printed with `cout`.

## 0.3.3
* **Fixed:** declaring a name twice in a block (or a local with the name of a global) reported the error at the *next* statement; it now points at the name that is declared again.

## 0.3.2
* **Division by zero throws** `"division by zero"` (catchable with `try`/`catch`) instead of silently giving 0. A literal divisor other than 0 costs nothing.
* **A crash tells why:** a null pointer or a stack overflow prints `runtime error: segmentation fault (null pointer or stack overflow)` and exits with 139.
* **New warning `-Wuninit`:** a variable declared without a value is read before anything was written to it.
* **Messages are easier to read:** errors in red, warnings in yellow (only when the output is a terminal; `-color` / `-nocolor` choose), and the source line has its line number: ` 12 | code` with a `^` under the place.

## 0.3.1
* **Fixed:** calling a function that does not exist (for example `alloc` without `import std` / `using std::mem`) ended with a message from the assembler; it is now `error: unknown function 'name'` at the call.
* **Fixed:** `cout << f()` printed a number when `f` returns `char`.
* The limit of structs is 80 (was 64); generic instances count. An error inside a generic instance points at the place of the use.
* **Generics**: `T max<T>(T a, T b)`, `struct Box<T>`, `struct Pair<A, B>`; the type is written at every use (`max<int>(1, 2)`, `Box<f64> b;`). A generic must be written before its first use.

## 0.3.0
* **Threads**: `import cpu` gives `Thread` (create, join, detach) and `Mutex` (futex based). Every thread has its own `try`/`catch` state and its own 1 MB stack; the heap (`alloc`/`free`) is safe to use from several threads.
* **`#multithread`** in front of `for i in a..b { ... }`: the iterations are shared among the CPU cores and the loop ends when all of them are done. `break`, `return` and a nested `#multithread` inside the body are errors.
* Built-in atomic helpers used by the library (`__cas`, `__xchg`, `__fetch_add`).

## 0.2.2
* The release files are named `jcmp` and `j2k_asm` (no more `-linux-arm64` in the name of the program); the bundle is still `jcmp-<version>-linux-arm64.tar.gz`. `install.sh` also installs older releases.
* New release file `jcmp.tar.gz` (only the program, with its executable bit): `curl -fL .../jcmp.tar.gz | tar xz -C ../bin`.
* `jcmp -version` and `jcmp -help` (one or two dashes: `-version`, `--version`, also `-v`, `-h`); the help is a short list of the options.

## 0.2.1
* Fixed: a character literal (`'J'`) that came after a decimal literal (`2.5`) was taken for a decimal number.
* New: a step-by-step tutorial, `docs/TUTORIAL.md` (and `docs/TUTORIAL.th.md` in Thai); every program in it is compiled and run.

## 0.2.0
* **Dynamic arrays**: `T[] x = arr(n)` with `len cap push pop resize clear free`, indexing (bounds-checked with `-d`), struct and pointer elements.
* **Memory that frees itself**: a local variable declared from `alloc(...)` / `arr(...)` is freed at the end of its block (also on `return`, `break`, `continue`); `move(p)`, warnings `-Wleak` and `-Wmoved`, and a leak report in `-d` builds.
* **Input**: `cin >> a >> b;` and `cinf >> x;` (the type of the variable decides what is read; bad input throws text).
* **Function pointers** (`int(int, int)^ op = add;`), unsigned types (`u8 u32 u64`), `sizeof`, `try`/`catch`/`throw`, `T^^`, 16 parameters, structs returned by methods.
* Smaller programs: functions that `main` cannot reach (most of `std`) are left out.
* `install.sh` options `--dir`, `--version`, `--with-assembler`.


## 0.1.0 — first release
* The compiler is written in J2K and compiles itself (self-hosting).
* One command from source to an ARM64 Linux executable (the assembler is built in).
* Language: `int i32 i8 u8 u32 u64 char bool f32 f64`, arrays (3 dimensions), pointers, `T^^`, function pointers,
  structs with methods, enums, `switch`, `for`/`while`, `try`/`catch`/`throw`, `sizeof`, `#define`, imports (`.j` components).
* Dynamic arrays `T[] x = arr(n)`; memory owned by local variables is freed automatically at the end of the block.
* Standard library: `Sys`, `Mem`, `Str`, `Math`, `File`.
* Messages like `file:line:col: error: ...` with the source line; warnings and `-st`; `-d` array bounds checks.
