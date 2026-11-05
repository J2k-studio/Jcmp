# Library parts that must stay stable

This page says which names are public (programs may use them), which are internal (they may change), how a library
is versioned, and what a change must keep. Every statement comes from the files named in it. Where the files do not
say, the page says "not documented".

## 1. Where the public names are written

* [STDLIB.md](STDLIB.md) lists the categories of the standard library (`core`, `number`, `text`, `files`, `system`,
  `time`, `data`, `crypto`, `net`) and the names of each one, with examples.
* [LIBRARIES.md](LIBRARIES.md) lists the other libraries by category (`<math>`, `<cpu>`, `<net>`, `<gpu>`, `<gamej>`
  and more) with examples.
* [API.md](API.md) lists every function of every library with the comment in front of it. Its header says that a
  helper (for example the steps of a hash) is listed too, because "the compiler does not hide them yet". So a name
  that appears in `API.md` is not automatically public. The public names are the ones in `STDLIB.md` and
  `LIBRARIES.md`, and the examples in `LANGUAGE.md` and the tutorial.

A name is **public** when `STDLIB.md` or `LIBRARIES.md` names it. A name is **internal** when one of the rules in
section 2 applies to it. The compiler does not enforce this boundary; a program can call any function it can see.

## 2. Internal names, by their form

| form | where | what it is |
|---|---|---|
| `__name(...)` (two underscores) | `std/rt_*.j` (for example `rt_a32.j`, `rt_fp.j`, `rt_mem.j`, `rt_arr.j`, `rt_str.j`, `rt_heap.j`, `rt_mt.j`), and `sys.j`, `cpu.j`, `tasks.j`, `result.j`, `math.j` | runtime routines that the compiler and the libraries call. `rt_a32.j` holds the routines of the ARM32 target, which the compiler calls by name (`__a32_*`). `rt_heap.j` is the prelude that is read in front of every program. `rt_mt.j` defines the internal struct `__Mt` of `#multithread`. |
| `nt_name` | `std/neuron.j` (about 50 lines use it, for example `nt_exp`, `nt_tanh`, `nt_mm_small`) | helpers of `<neuron>`. Also the hook `nt_gpu_fn`, which takes the matrix product to the GPU. |
| `mm_name` | `std/neuron.j` (for example `mm_rows`, a worker of the threads) | a helper of `<neuron>` that runs on a thread. |
| `mont_n0`, `mont_mul`, `mont_setup`, `mont_pow` | listed in `API.md` under `struct Crypto` | modular-arithmetic helpers of `Crypto`, shown there without a note that they are internal. Not named in `STDLIB.md`. |

Inside the compiler (`jcmp/*.j`) the names are internal by definition. These prefixes are used there and are not
part of any library: `ir_` (the IR), `op_` (the passes on the IR), `vz_` (the vectoriser), `pt_` (rules of the
register pass), `as_` (the assembler), `lw_` (the lowering), `ast_` and `at_` (the syntax tree and its lowering),
`vr_` (vector registers), `cl_` (counted loops), `cc_` (the cache), `lg_` (the `-space`
picture), `regs_` and `nr_` (the register pass and the first text pass), `rt_call` (a compiler helper that writes a
runtime call). A program does not use these names.

## 3. Versioning

* **Each library file has a version on its first line**: `// NAME VERSION -- what it is`, usually followed on the same
  line by `#import <name>` and `(needs jcmp X.Y.Z.W; license ...)`. Examples in `std/`: `neuron 0.7.1`,
  `opengl3 0.3.0`, `native 0.1.1` (`std/neuron.j`, `std/opengl3.j`, `std/native.j`). The rule for these numbers is
  written in [DEVELOPING.md](DEVELOPING.md) as "a library is `std/NAME.j` (the first line is a comment `NAME 0.1.0 -- ...`)".
  Whether a library's own numbers follow the compiler's four-part rule is **not documented**.
* **The library folder is a pair with the compiler.** `Library/VERSION` must equal the version of the compiler, or the
  compiler stops and says to install them again ([USAGE.md](USAGE.md)).
* **The compiler's numbers** have four parts, A.B.C.D: "A a big step, B new features, C small updates, D fixes only; a
  1.x.x.x release keeps working programs working" ([CHANGELOG.md](../CHANGELOG.md), the 1.0.0.0 entry).
* **Old names** are kept with a warning when a name changes. Example in `CHANGELOG.md`: `jout`, `jin` and `jerr` are the new
  names of `cout`, `cin` and `cerr`; the old names still work with a warning, and the entry says they will be removed
  (a warning in 1.3, an error in 2.0). `jcmp migrate` renames them in a program.

## 4. What a change must keep

These are the rules that the files state. Anything else is **not documented**; treat it as open.

1. **Names and their meaning** of every public name in `STDLIB.md` and `LIBRARIES.md`. A change of a name goes through
   the old name with a warning first (section 3).
2. **Argument order and types** as written in the header of the function (`API.md` gives the signature of each one).
   Example: `sort_by<T>(T[] a, bool(T, T)^ less)`, where `less(x, y)` is true when `x` must come before `y`.
3. **Error results.** Errors are thrown as text; a `try_` name returns a `Result` ([STDLIB.md](STDLIB.md)). The
   system layer returns the kernel's result: a number of zero or more, or a negative error number (`-2` no such file,
   `-14` bad address, `-22` invalid argument), as written in the header of `Sys` in `API.md`. The numbers of the
   system calls are kept in one file on purpose, so that a port changes that file only.
4. **Order of results that the header states.** The sort is stable (its comment in `API.md` says so).
5. **Float results.** The files state two cases where the bits of a result may differ, and these must be kept as
   written: the fast float32 product `Tensor::matmul_fast` gives different last digits from `matmul` (header of
   `std/neuron.j`, and [PERFORMANCE.md](PERFORMANCE.md)); and a multiply-add that is fused into one instruction can
   change the last bit of a result (the help of the compiler for `-nofma`). For other float functions the files
   **do not document** a bit-for-bit rule.
6. **Printing of numbers.** `Fmt` and `Num` are documented by example in `STDLIB.md`
   (`Fmt::fixed(3.14159, 2)` gives `3.14`, and so on). The examples must still print the same text.

## 5. Names still open

Several names in `API.md` carry the note "designed by the assistant ... adjustable" (for example the header of `Sys`,
and `Listener::on` and `Connection::to` in the network part). They are not decided by the owner. The owner's decisions on the language are in the
language specification (`docs/syntax-design.md`, in Thai), and the open ones are listed in the roadmap.
