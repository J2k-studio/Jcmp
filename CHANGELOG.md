# Changelog

## 0.2.2
* The release files are named `jcmp` and `j2k_asm` (no more `-linux-arm64` in the name of the program); the bundle is still `jcmp-<version>-linux-arm64.tar.gz`. `install.sh` also installs older releases.
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
