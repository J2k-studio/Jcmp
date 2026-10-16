# 1.0.0.0: the end of the first era and the start of the next (written 2026-10-17, from the owner's words)

## 1. What 1.0.0.0 means
* **The end:** the foundation is finished. The language, the compiler (written in J2K, builds itself), the standard library, the
  error messages and the tests are stable on **ARM64 and ARM32** (both must work before 1.0.0.0; the owner, 2026-10-17).
* **The start:** from 1.0.0.0 on a program that compiles keeps compiling. Names and rules of the language do not change in a
  way that breaks a program; new things are added. The version has four parts, **A.B.C.D**:
  A a big step (rare), B new features, C small updates, D fixes only.
* **Updates are free.** Every update of jcmp 1.x.x.x, now and later, is free (owner, 2026-10-17). This is a promise of the
  owner; the wording of `LICENSE` is theirs to check.

## 2. What must be true before the first 1.0.0.0 (the checklist)
| # | Item | State (2026-10-17) |
|---|---|---|
| 1 | ARM64: language, library, tests, speed (no benchmark slower than 2x clang `-O2`) | works; `loop` is 3.8x (to fix) |
| 2 | **ARM32** backend: the same language, the same tests | not started (section 4) |
| 3 | The compiler builds itself on both targets, reproducibly | ARM64 yes |
| 4 | Every test passes in every mode, **3 runs in a row**, many fuzz seeds, a fresh install of the public release works | running (section 5) |
| 5 | `jget`: a library can be fetched and installed (section 3) | not started |
| 6 | Documents: every example compiles; the specification matches the compiler; known limits are listed | in work |
| 7 | The syntax tree makes all the code (the text parser only reads, checks, warns) | 92.5% (internal; not needed by users) |
| 8 | Errors: every message says what is wrong, where, and why | good; a list is kept in `docs/error-messages-plan.md` |
| 9 | The promise "updates are free" is in the public documents | to write at 1.0.0.0 |

## 3. Where `import` finds a library (answer to the owner's question)
* `#import <stdlib>`, `<core>`, `<number>`, `<text>`, `<files>`, `<system>`, `<time>`, `<data>`, `<crypto>`, `<net>`, `<math>`,
  `<gfx>`, `<cpu>`, `<simd>` are **inside the compiler** (`jcmp/jc_std.j` is made from `std/*.j`). That is why the unpacked
  release has no library folder: the library is part of the program `jcmp`. The sources are in the repository (`std/`) and
  are shown by `jcmp -showlib NAME` (new in 0.9.175).
* Any other name is searched in this order: the `-I` folders, the folders of `J2K_PATH`, `~/.j2k/lib`, the `lib` folder next
  to the compiler. `jget` (v0, planned) puts a downloaded library in `~/.j2k/lib`.

* **Update 0.9.176 (owner, 2026-10-17):** the library is also outside the compiler, in the folder **`Library/`** (full name, owner's choice), always
  paired with the compiler of the same version (`Library/VERSION`). `#import <net>` = the official library (the compiler's `Library/`, `JCMP_LIB`,
  or the copy inside); `#import "path.jk"` = a file of the user. `jcmp -update` replaces compiler and library together. The copy inside
  the compiler stays as a fallback until the external way has been proven in releases.

## 4. ARM32 (planned steps; the compiler has an IR, so the work is a second code generator)
1. Write down what is different: 32-bit registers (r0-r12, sp, lr, pc), the calling rules (AAPCS: r0-r3, 64-bit values in a
   pair), system calls through `svc 0` with the number in r7, an ELF32 header, a 4-byte pointer, and what `int` means.
   **Decision taken by the assistant (adjustable): `int` stays 64 bits on every target** (a program gives the same answer on ARM64
   and ARM32); on ARM32 a 64-bit number lives in two registers.
2. The assembler (`jcmp/jc_asm.j`, `j2k_asm.jk`): encoders of the ARM32 instructions that the generator uses (data processing,
   `ldr`/`str`, `ldm`/`stm`, `b`/`bl`/`bx`, multiply, divide through a routine, `vfp` for `double`/`float`).
3. The generator from the IR: instruction selection, register allocation for 32-bit registers (the IR has virtual registers),
   64-bit operations in pairs, the runtime routines (print, heap, panic) for ARM32.
4. Run the whole test suite on ARM32 (an ARM32 machine or `qemu-arm` is needed: the owner's phone can run 32-bit programs only
   if the CPU allows; to be checked).
5. Only then x86_64 ("we meet again at x86", owner, 2026-10-17).

## 5. The test campaign before 1.0.0.0
Each form is tested at least three times: the suite (default and `-noast`), `diffcheck` (the tree against the text path, no
inlining, no IR), the fuzzers (`tools/fuzz.py`, `tools/fuzz_str.py`) with several seeds, the network tests several times, the
benchmarks against clang, a fresh install from the public release, and the examples of the documents. A failure is fixed and
gets a test of its own before anything else is done.

## 6. After 1.0.0.0
x86_64; async; the J2K library file (`.so`); GPU; the own OS; the Xiaorin project. Each is a feature step (B) or a big step (A).

## 7. How decisions are made from now on (owner, 2026-10-17)
What is decided is done. What is not decided waits (it is written in `docs/open-questions.md`) and the work goes on with
something else. No question stops the work.
