# Using Jcmp

## Compile and run

```bash
bin/jcmp program.jk -o program      # source -> executable (one step)
./program
```

Requirements: Linux **ARM64** (a phone with Termux works). Nothing else: the assembler
and the ELF writer are inside the compiler.

### Command line

```
jcmp input.jk -o output [-d] [-st] [-I dir] [--emit-asm file.jasm]
jcmp input.jk output.jasm              (older form: write assembler text only)
```

| Option | Meaning |
|--------|---------|
| `-o file`          | write the ARM64 executable |
| `--emit-asm file`  | also (or only) write the assembler text, to read what the compiler generated |
| `-st`              | strict: every warning becomes an error |
| `-I dir`           | where `import "name"` also looks (after the folder of the importing file) |
| `-d`               | debug build: array index checks. A bad index prints `runtime error: index out of bounds, array size is N` and the program exits with code 134 |

Exit code of `jcmp`: 0 = success (warnings may have been printed), 1 = error.
The generated programs exit with the value returned by `main` (or `Sys::exit(n)`).

### Assembler on its own

`bin/j2k_asm_j2k text.jasm output` turns assembler text into an executable
(the same assembler that is inside `jcmp`).

## Rebuild the compiler with itself

```bash
./bootstrap.sh
```

Stage 0 is the committed `bin/jcmp`; it compiles `jcmp/jcmp.jk` into `jcmp1`, `jcmp1`
compiles it into `jcmp2`, `jcmp2` into `jcmp3`. Success means `jcmp2` and `jcmp3` are
byte-for-byte identical. The script then builds every test program with `jcmp3` and with the
old assembly compiler and checks that they behave the same.

```bash
./bootstrap-from-binary.sh          # the short check: stage1 == stage2 == bin/jcmp
cp _test_out/boot/jcmp3 bin/jcmp    # after a change that you want to keep as the new starting point
```

After editing `std/*.j` run `./gen_std.sh` first (it regenerates `jcmp/jc_std.j`).
The assembler binary is rebuilt with `bin/jcmp j2k_asm.jk -o bin/j2k_asm_j2k`.

The compiler is always rebuilt from the committed binary `bin/jcmp` (the very first compiler, written
in assembly, is not part of this repository).

## Tests

```bash
JCMP=_test_out/boot/jcmp3 ./run_all_tests.sh     # the J2K compiler, whole suite
./run_all_tests.sh                               # the old assembly compiler (frozen)
```

Test programs live in `test/`. Next to `name.jk` there may be:
`name.out` (exact expected output), `name.warn` (exact expected compiler messages).
Programs named `*_fail_*` must be rejected. `JCFLAGS="-st"` passes options to the compiler.
Features added after the assembly compiler was frozen are tested only in the `JCMP=` mode.

## Examples

```bash
for e in hello fib shapes heap; do bin/jcmp examples/$e.jk -o /tmp/$e && /tmp/$e; done
```

## The standard library

`import std` puts the library in front of your program; `using std::mem` (or `str`, `sys`,
`math`, `fs`) lets you call its functions without the prefix. Its source is `std/*.j`.
See [LANGUAGE.md](LANGUAGE.md).

## Should the documentation be a website?

Markdown files are shown nicely by GitHub, and `README.md` is the front page. A website
(GitHub Pages built from `docs/`) is worth doing later, when the language settles.

## Limits of the compiler

| What | Limit |
|------|-------|
| local variables in one function | 8,192 |
| global variables / functions | 16,384 each |
| struct types / enum types | 64 / 64 (the type codes share one number space) |
| struct fields (all structs) / enum members (all enums) | 8,192 each |
| `#define` names / imported files | 2,048 / 512 |
| parameters of a function / arguments of a call | 16 |
| array dimensions / pointer levels (`T^^`) | 3 / 2 |
| source file size | 512 KB per file, imports nested 15 deep |
| name length | 63 characters |
| program size | 8 MB of generated assembler text |

A program that reaches a limit gets a clear `error: too many ...` message.
