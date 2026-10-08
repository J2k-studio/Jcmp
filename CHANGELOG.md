# Changelog

## 0.1.0 — first release
* The compiler is written in J2K and compiles itself (self-hosting).
* One command from source to an ARM64 Linux executable (the assembler is built in).
* Language: `int i32 i8 u8 u32 u64 char bool f32 f64`, arrays (3 dimensions), pointers, `T^^`, function pointers,
  structs with methods, enums, `switch`, `for`/`while`, `try`/`catch`/`throw`, `sizeof`, `#define`, imports (`.j` components).
* Dynamic arrays `T[] x = arr(n)`; memory owned by local variables is freed automatically at the end of the block.
* Standard library: `Sys`, `Mem`, `Str`, `Math`, `File`.
* Messages like `file:line:col: error: ...` with the source line; warnings and `-st`; `-d` array bounds checks.
