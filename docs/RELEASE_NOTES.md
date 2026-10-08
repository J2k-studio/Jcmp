# J2K / Jcmp 0.9.4

A self-hosting compiler for the J2K language that writes Linux ARM64 executables directly.

**0.9.4:** `jcmp test.jk` (without `-o`) makes the program `test`.

**0.9.3:** clearer messages for a missing `;` and for an output file that cannot be written (for example `-o test` when `test` is a folder).

**0.9.2:** a generic function finds its types from the arguments: `largest(3, 9)`.

**0.9.1:** a lambda is written like a function without a name: `int(int a, int b) { return a + b; }`.

**New in 0.9.0:** lambdas.

**0.8.1:** a `throw` frees the arrays, Strings and other owned memory of the functions it leaves (no more leaks); warnings are yellow.

**0.8.0:** write `#import <stdlib>` (with the `#`); `cout`/`cin` handle decimals (no more `coutf`/`cinf`); a function that must return a value but has no `return` is an error; new warning for unused variables.

**0.7.1:** a function that ends without `return` throws an error instead of returning a junk value; clearer message for a missing `<<`.

**0.7.0:** `#import <stdlib>` / `#import <library>` (libraries are searched in `-I`, `J2K_PATH`, `~/.j2k/lib`), `std` is now called `stdlib`.

**New in 0.6.0:** `Map<K,V>` and `Set<T>`, `String[]`, list methods (`sort`, `insert`, `remove`, `contains`, `index_of`), `for x in list`, and structs with a `free(self)` method that the compiler calls at the end of the block.

**0.5.0 changes how programs begin:** `float`/`double` replace `f32`/`f64`, and `cout`/`cin` need `import std` and `using std` at the top (a warning now, an error later).

**New in 0.4.0:** `String` (text that grows: `+`, `==`, `s.len`, `s[i]`, `slice`, `find`, `cin >> s`, freed automatically) and generics (`T max<T>(T a, T b)`, `struct Box<T>`).

**0.3.3:** the error for a repeated variable name points at the second declaration (it pointed at the next line).

**0.3.2:** division by zero throws instead of giving 0, a crash from a null pointer or a stack overflow prints a message, new warning `-Wuninit`, coloured messages (red errors, orange warnings) with line numbers.

**0.3.1:** generics (`T max<T>(T a, T b)`, `struct Box<T>`), a clear error for an unknown function (it used to end in an assembler error), a function that returns `char` prints a character, up to 80 structs.

**New in 0.3.0:** threads (`import cpu`: `Thread`, `Mutex`), `#multithread` loops that share their iterations among the CPU cores, a thread-safe heap, a separate try/catch state per thread.

**0.2.2:** the program files are called `jcmp` and `j2k_asm`; `jcmp -version` and `jcmp -help` work.
**0.2.1** fixes a lexer bug (a character literal after a decimal literal) and adds a step-by-step tutorial (`docs/TUTORIAL.md`).

**New in 0.2.0:** dynamic arrays (`T[] x = arr(n)`), memory owned by local variables is freed automatically at the
end of the block, `cin` / `cin`, function pointers, unsigned types, `sizeof`, `try`/`catch`/`throw`, smaller programs
(unused library functions are left out). Full list: CHANGELOG.md.

**Install:** `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`
(options: `--dir ../bin`, `--version 0.9.4`, `--with-assembler`), or download `jcmp` below, check it
against `SHA256SUMS` and `chmod +x` it. See the README.

**Use:** `jcmp hello.jk && ./hello`

Files: `jcmp` (the compiler), `j2k_asm` (stand-alone assembler),
`jcmp-0.9.4-linux-arm64.tar.gz` (both + README + LICENSE + examples + docs), `SHA256SUMS`.
Linux ARM64 only. See LICENSE for the terms of use.
