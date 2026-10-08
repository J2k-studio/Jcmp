# J2K / Jcmp 0.2.2

A self-hosting compiler for the J2K language that writes Linux ARM64 executables directly.

**0.2.2:** the program files are called `jcmp` and `j2k_asm`; `jcmp -version` and `jcmp -help` work.
**0.2.1** fixes a lexer bug (a character literal after a decimal literal) and adds a step-by-step tutorial (`docs/TUTORIAL.md`).

**New in 0.2.0:** dynamic arrays (`T[] x = arr(n)`), memory owned by local variables is freed automatically at the
end of the block, `cin` / `cinf`, function pointers, unsigned types, `sizeof`, `try`/`catch`/`throw`, smaller programs
(unused library functions are left out). Full list: CHANGELOG.md.

**Install:** `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`
(options: `--dir ../bin`, `--version 0.2.2`, `--with-assembler`), or download `jcmp` below, check it
against `SHA256SUMS` and `chmod +x` it. See the README.

**Use:** `jcmp hello.jk -o hello && ./hello`

Files: `jcmp` (the compiler), `j2k_asm` (stand-alone assembler),
`jcmp-0.2.2-linux-arm64.tar.gz` (both + README + LICENSE + examples + docs), `SHA256SUMS`.
Linux ARM64 only. See LICENSE for the terms of use.
