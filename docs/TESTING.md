# Testing the J2K compiler
This page describes the test suite of the compiler, the checks around it, and how to add a case. It is for the
author and for whoever works on the development repository. It describes the private test suite (`test/`,
`run_all_tests.sh`, `tools/`), which is not in the public branch.

Run every command from the root of the repository.

## 1. Running the suite

```sh
./bootstrap.sh                                   # build the compiler with itself; must print BOOTSTRAP OK
cp _test_out/boot/jcmp3 bin/jcmp                 # use the new compiler (bootstrap.sh prints a note when bin/jcmp differs)
JCMP=_test_out/boot/jcmp3 ./run_all_tests.sh     # the whole suite with the J2K compiler: must be all PASS
./run_all_tests.sh                               # without JCMP: the compiler is bin/jcmp
SEED=1 ./run_all_tests.sh                        # the frozen assembly compiler (the first tests of the history only)
PERF=1 ./run_all_tests.sh                        # also the speed check of tools/bench (section 5)
```

How the runner chooses the compiler:

* `JCMP=path` names the compiler. Without it and with `bin/jcmp` present, `bin/jcmp` is used.
* `SEED=1` uses the assembly seed, when `seed/` is present. The seed builds only the first tests of the history.
  Without a seed and without `JCMP`, the runner stops and tells you to name the compiler with `JCMP` after `bootstrap.sh`.
* `JCMP_LIB` is set to the folder `Library/` of the repository. `J2K_CACHE` is empty, so the cache does not change
  the messages the tests compare. `J2K_PATH` includes `build/libs`, where the downloadable libraries are.
* The assembler for J2K-built runs is `bin/j2k_asm_j2k` (the variable `ASM` chooses another one). Floating point
  tests use it.

The last line of the output is `== summary: N passed, M failed ==`. When M is not 0 it also prints `failed tests:`
with the names. The files of a failed test are in `_test_out/`: `NAME.compile_err` (compiler messages),
`NAME.jasm` (the assembler text), `NAME.asm_err`, `NAME.stdout` (the output of the program).

## 2. What the runner does for one test

For a test `NAME` (file `test/NAME.jk`):

1. The compiler writes `_test_out/NAME.jasm`. The extra options come from the variable `JCFLAGS`, for example
   `JCFLAGS="-d"` for the bounds checks.
2. If `test/NAME.warn` exists, the compiler's error output must be exactly that file. Otherwise the test fails.
3. The assembler writes `_test_out/NAME_bin`. The program runs with a 20-second timeout, with standard input from
   `test/NAME.in` if that file exists, or from `/dev/null`. A run that hits the timeout (exit code 124) is run once more.
4. If `test/NAME.out` exists, the standard output must be exactly that file.
5. The exit code must be the expected number that is written in the runner's list.

Three helpers cover the other cases:

* `run_fail NAME`: the compiler must reject `test/NAME.jk` (a non-zero exit).
* `run_fail_msg NAME TEXT`: the compiler must reject it, and its message must contain `TEXT`.
* `run_test` with an `ASM=...` or `JCFLAGS=...` prefix: one test with another assembler or other options.

## 3. The list of tests in the runner

`run_all_tests.sh` lists every test with its expected exit code, one per line, in order:

```
run_test t01_single             7
run_test t02_add                8
...
run_fail t100_fail_if_int
```

Tests that only the J2K compiler can pass are inside `if [ -n "${JCMP:-}" ]`. Tests of the ARM32 target, of the
examples (every file of `examples/` must compile), of the documents and of the tools come after the list. The file
itself is the authority; the list is long and changes with each feature.

Checks the runner does after the list (each prints PASS or FAIL):

* **Examples**: every program in `examples/` must compile.
* **Fuzz**: `tools/fuzz.py` with 20 random programs against a Python interpreter, once with the default options and
  once with `-noir`.
* **ARM32**: the ARM32 back end builds the tests; the built programs run natively when the machine runs 32-bit
  programs, and the check says it is skipped otherwise. The compiler also compiles itself for ARM32 through
  `tools/selfhost32.sh`.
* **Documents**: `tools/doccheck.py` compiles every program with a `main` in `README.md`, `docs/LANGUAGE.md`,
  `docs/TUTORIAL.md`, `docs/COOKBOOK.md` and `docs/UI.md`. The summary line must say `0 bad`.
* **API page**: `tools/make_api.sh --check` says whether `docs/API.md` is up to date.
* **Interface file**: `jcmp -jh` drops the bodies and gives an interface hash that changes with a header and not with a
  body; `jcmp -api net` shows a library without bodies.
* **Encodings**: `tools/asm_check.py` checks the assembler's encodings against `llvm-mc`, when `llvm-mc` and `python3`
  are installed, for the lists `test/asm_check_*.txt`.
* **Performance** (only with `PERF=1`): `tools/bench/perf_check.sh`.

## 4. Diffcheck: the same result with other options

`tools/diffcheck.sh [JCMP]` compiles every test that has a `.out` file (names with `fail` or `_expect` are skipped)
with the default options, and then with each variant of the `VARIANTS` list. Each build must give the same exit
code and the same standard output as the default build. It prints `DIFF`, `COMPILE FAIL` or a difference and ends with
`diffcheck: N builds, M differences`.

The default list in the script is:

```
-noast | -noir | -noinl | -noregs | -nopeep | -nonullchk | -d | -noalign | -irdbg 4096 -irclr 8 | -noir -noregs -nopeep
```

Other settings: `VARIANTS` replaces the list (separated by `|`), `OUT` chooses the folder of the temporary files, and
`OLD=path` (with `OLD_LIB`) also builds every program with an older compiler and compares the results. The switches
`-noicopy` and `-nohoist` exist in the compiler but are not in the default list.

Some programs print a leak report with `-d`; a difference counts only if the output before it differs.

## 5. Speed check

`tools/bench/perf_check.sh` (also run by `PERF=1 ./run_all_tests.sh`) compares, for each benchmark and for the
compiler compiling itself, the size of the assembler text (exact: a bigger number fails at once) and the best of five
runs (it fails when more than 30 % slower than `tools/bench/baseline.txt`; `TOL=` changes the limit). `--update`
writes a new baseline, on purpose only.

`tools/bench/gate.sh` runs the whole table of `tools/bench/run.sh` and fails when a program is slower than 1.5 times gcc -O2 (the known exceptions are listed in the script). `tools/bench/run.sh` also compares the exit code with the C program (not for the float programs nbody and mandel, where fma contraction changes the rounding) and appends the times to `tools/bench/history.txt`. Run the gate before every release: a slowdown of the `arrays` benchmark (5 times) once passed unnoticed for three releases.

## 6. Documents

* `python3 tools/doccheck.py FILE --jcmp bin/jcmp`: each block that starts with a line ` ```jk ` and has a `main`
  is compiled; a block without `main` is a fragment and is only counted; a block marked ` ```jk-no ` is not looked at.
  The last line is `doccheck FILE: N compile, F fragments, B bad`. It exits with 1 when `B` is not 0.
* `python3 tools/make_tutorial.py` writes `docs/TUTORIAL.md` and `docs/TUTORIAL.th.md`. It compiles and runs every
  program of the tutorial with `bin/jcmp` and puts the real output into the text. Run it after a change to a program
  of the tutorial, then run `doccheck.py` on the result.
* `tools/make_api.sh` writes `docs/API.md` from the libraries (section 3 checks that it is up to date).

## 7. Adding a case

1. Write `test/tNNN_name.jk`. Use a number that is not used yet (`ls test/t*.jk` lists them).
2. Write the exact output the program must print in `test/tNNN_name.out`. A program that reads input takes it from
   `test/tNNN_name.in`. A program that must be rejected needs no `.out`; write its name as `tNNN_fail_name.jk` and
   register it with `run_fail`.
3. If the compiler's messages are part of the test, write them in `test/tNNN_name.warn`. The file must match the
   compiler's error output exactly.
4. Register the test in `run_all_tests.sh` with its expected exit code (`run_test NAME CODE`), or with `run_fail` /
   `run_fail_msg`. Put it inside the `if [ -n "${JCMP:-}" ]` block when only the J2K compiler can pass it.
5. If the seed compiler cannot build the program, the comparison with the seed in `bootstrap.sh` must skip it. The script
   skips by name pattern in a `case` list: `t97_*` (the output of a `bool` in `cout`), `t57_*`, `t64_*`, `t65_*`
   (`i8` arithmetic), and every name from `t130_` to `t599_` (rules that only the J2K compiler has).
   Add a pattern there when a new name needs one.
6. Run the new test on its own while you work, then the whole suite before a change is merged. The rule written in
   the design notes is: small tests while working, the full suite before a merge.

**How the expected output is made:** not documented in the files of this repository. The `.out` files are compared
byte for byte with the output of the program.

Names with `_expect` (for example `t480_expect.jk` with `t480_expect.out`) are skipped by `diffcheck.sh`.

## 8. Current counts

At the time of writing this page the repository has 968 files named `t*` in `test/`, 324 `.out` files, 6 `.warn`
files and 4 `.in` files. The number of tests run by the runner is the number of `run_test` and `run_fail` lines, and
it changes with each feature; read the summary line of a run instead of this page.
