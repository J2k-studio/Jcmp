# Developing J2K and its compiler

This page is for a person who wants to change the language, the compiler, a library or a tool. It needs a phone or a computer with ARM64 Linux (Termux works), `git`, and the `jcmp` compiler (see the README to install it).

## The layout
| folder | what is in it |
|---|---|
| `jcmp/` | the compiler, in J2K (`jcmp.jk` is the entry, `jc_*.j` are its parts: lexer, parser, code generator, IR passes, register allocator, assembler) |
| `std/` | the standard library and the downloadable libraries, in J2K (`./gen_std.sh` turns them into `Library/` and `build/libs/`) |
| `docs/` | the manuals: `LANGUAGE.md`, `TUTORIAL.md`, `USAGE.md`, `LIBRARIES.md`, `API.md`, `LIMITS.md`, the design notes in `docs/design/` |
| `examples/` | small programs |
| `bench/`, `tools/bench/` | the speed benchmarks (J2K against C and other languages) |

## The loop
```sh
./gen_std.sh                         # after a change in std/
./bootstrap.sh                       # after a change in jcmp/: the compiler builds itself twice; the two results must be identical
cp _test_out/boot/jcmp3 bin/jcmp     # use the new compiler
python3 tools/doccheck.py docs/TUTORIAL.md --jcmp bin/jcmp   # every program of a document must compile
```
A change comes with a test: a program in `test/` and the exact output it must print (`.out`). The test script runs the whole suite and prints `== summary`. Everything must pass before a change is kept.

## Writing code in J2K
Read `docs/TUTORIAL.md` (the lessons, 1-75) and `docs/LANGUAGE.md`. A few things that are different from C: there is no `?:` (use `if`), `int` is 64 bits, text is `String`, growing arrays are `T[] a = arr(n)`, errors are `Result` / `Option` / `try`, memory has owners (assigning an array or a String to a field moves it; copy when you need two). `jcmp -show NAME file.jk` shows the machine code of a function and `jcmp -irstat file.jk` says which functions the optimiser could not handle and why.

## Changing the language
A new syntax is a decision of the owner of the language: propose it in `docs/syntax-design.md` (a new numbered section with the options, the pros and cons) and wait. The compiler passes: `jc_lex.j` (words) -> `jc_par.j` and `jc_ast.j` (the tree of the function bodies that the tree path understands) / `jc_expr.j` and `jc_stmt.j` (code generator that writes assembly text) -> `jc_lift.j` (the text becomes an IR of three-address instructions) -> `jc_opt.j`, `jc_vec.j` (passes, vectors) -> `jc_regs.j` (registers) -> text -> `jc_asm.j` (machine code). A new CPU instruction has to be known by the generator, the lifter, the IR and the assembler. The 32-bit ARM target is `jc_a32.j`.

## Libraries, tools, the app
* A library is `std/NAME.j` (the first line is a comment `// NAME 0.1.0 -- what it is`), listed in `gen_std.sh`; a test in `test/`; a page `docs/NAME.md` and a line in the index of the library repository.
* A tool is a folder with the program, `build.sh`, `test.sh`, `release.sh`, `README.md`, `CHANGELOG.md`, `VERSION`.
* Every library and tool has a README that says what it is, how to install it and how to use it with a working example. A change is written in the `CHANGELOG.md` as **Added** and **Fixed**.

## Measuring
Speed is measured, not guessed: `bench/lang.jk` (what the small things cost), `tools/bench/run.sh` (J2K against C), `tools/bench/langs/run.sh` (against Java, JavaScript and Python), `bench/llama_bench.jk`, `bench/gpu_matmul.jk`. A change that is meant to make code faster prints the numbers before and after.
