# J2K / Jcmp 0.3.2

A self-hosting compiler for the J2K language that writes Linux ARM64 executables directly.

**0.3.2:** division by zero throws instead of giving 0, a crash from a null pointer or a stack overflow prints a message, new warning `-Wuninit`, coloured messages (red errors, orange warnings) with line numbers.

**0.3.1:** generics (`T max<T>(T a, T b)`, `struct Box<T>`), a clear error for an unknown function (it used to end in an assembler error), a function that returns `char` prints a character, up to 80 structs.

**New in 0.3.0:** threads (`import cpu`: `Thread`, `Mutex`), `#multithread` loops that share their iterations among the CPU cores, a thread-safe heap, a separate try/catch state per thread.

**0.2.2:** the program files are called `jcmp` and `j2k_asm`; `jcmp -version` and `jcmp -help` work.
**0.2.1** fixes a lexer bug (a character literal after a decimal literal) and adds a step-by-step tutorial (`docs/TUTORIAL.md`).

**New in 0.2.0:** dynamic arrays (`T[] x = arr(n)`), memory owned by local variables is freed automatically at the
end of the block, `cin` / `cinf`, function pointers, unsigned types, `sizeof`, `try`/`catch`/`throw`, smaller programs
(unused library functions are left out). Full list: CHANGELOG.md.

**Install:** `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`
(options: `--dir ../bin`, `--version 0.3.2`, `--with-assembler`), or download `jcmp` below, check it
against `SHA256SUMS` and `chmod +x` it. See the README.

**Use:** `jcmp hello.jk -o hello && ./hello`

Files: `jcmp` (the compiler), `j2k_asm` (stand-alone assembler),
`jcmp-0.3.2-linux-arm64.tar.gz` (both + README + LICENSE + examples + docs), `SHA256SUMS`.
Linux ARM64 only. See LICENSE for the terms of use.
