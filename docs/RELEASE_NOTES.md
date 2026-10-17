# J2K / Jcmp 0.9.183

A self-hosting compiler for the J2K language that writes Linux ARM64 executables directly.

**0.9.183:** https from the library: TLS 1.3 with the check of the certificate chain, written in J2K (X25519, ChaCha20-Poly1305, RSA, ECDSA, X.509, DNS); `Crypto`.

**0.9.182:** `Net::http.download` (files to disk with a progress bar); `jget` moved to its own project, which downloads files, not only pages.

**0.9.181:** the library is the folder `Library` installed with the compiler (not inside it any more); `Dns` and `Http` in the library; `jget -h http://...` needs no curl.

**0.9.180:** `jget -h URL` fetches data from the web (like curl / wget), `jget -li install NAME` for libraries; the libraries inside the compiler need no install.

**0.9.179:** the compiler is about twice as fast (three slow places found with a profiler); the programs it makes are unchanged.

**0.9.178:** `jget` version 0: fetch libraries from an index with a SHA-256 check.

**0.9.177:** `-cache DIR` (experimental): the back end skips the functions that did not change; two hidden bugs of the optimiser fixed.

**0.9.176:** the library as files in `Library/` paired with the compiler (version checked), `jcmp -update`, `install.sh --with-lib`.

**0.9.175:** `Listener` / `Connection` for TCP, `jcmp -showlib NAME`, more of the compiler on the syntax tree.

**0.9.174:** internal: tables of 2-3 dimensions, `a.len` of fixed arrays, `split`, char-returning functions are made from the syntax tree.

**0.9.173:** internal: `for x in ...`, `move`, the memory brackets, String methods on new Strings, array methods and arrays of bool are made from the syntax tree.

**0.9.172:** internal: `argc()`, `arg(i)`, `str(x)` and `switch` on a call result are made from the syntax tree.

**0.9.171:** internal: structs with `init()` and the operators of structs are made from the syntax tree.

**0.9.170:** short names for `csv`, `toml`, `regex`, `hash`, `num`, `hex`, `base64`; the table of short names in `docs/STDLIB.md`.

**0.9.169:** big doubles are written as `1.9e+30`; float literals up to e308 and with long digits.

**0.9.168:** short names for `fs`, `dir`, `path`, `json`, `env`, `proc`, `term`, `time`, `random` (throw, `try_` for a Result); `nl`; a double-free fix for arrays returned out of a Result.

**0.9.167:** every mistake in a file is shown (up to 20), clearer messages for a statement outside a function, a missing ( ) after a function name and `=` in a condition; warning for "/n".

**0.9.166:** library names with three layers (`Net::tcp.listen`, `using Net;`, `using Net::tcp.listen;`); a module that is not open is an error that says how to open it.

**0.9.165:** input errors of `cin` say what was expected and what was found.

**0.9.164:** `module.function(...)` for every library (`fs.read_text`, `math.sqrt`), new module `tcp` (`tcp.listen(8080)`).

**0.9.163:** fix for Android: a program that accepts a network connection no longer dies with "Bad system call"; `using net;`; errors say why (unreadable file, file system and network errors).

**0.9.162:** internal: `__hash`, `__panic`, unsized char arrays and the constructors of Result / Option are made from the syntax tree; the member names in a "has no method" help line are printed.

**0.9.161:** internal: array parameters, `char w[N] = "text"` are made from the syntax tree. New warning `-Woldlen` for `name__len` (use `name.len`).

**0.9.160:** internal: `syscall` and text literals as `char^` are made from the syntax tree; `main` with a system call is optimised whole.

**0.9.159:** internal: data-enum `switch` and structs with `free(self)` by value are made from the syntax tree; more `help:` lines in error messages.

**0.9.158:** internal: `try` / `catch` / `throw`, arrays of pointers, returned arrays and arrays of Strings are made from the syntax tree.
**0.9.157:** internal: `main` is made from the syntax tree too; loops are written test, body, jump back.
**0.9.156:** vector loops use one pointer for arrays that are walked together (the `arrays` benchmark 187 -> 139 ms).
**0.9.155:** internal: Strings and arrays in struct fields and globals are made from the syntax tree as well.
**0.9.154:** internal: Strings (variables, joins, comparisons, methods, results) are made from the syntax tree as well.
**0.9.153:** internal: dynamic arrays of numbers (`int[] a = arr(4); a.push(3);` ...) are made from the syntax tree as well.
**0.9.152:** internal: memory made by `alloc` and freed by the compiler (and structs that free themselves) is handled in the code that is made from the syntax tree.
**0.9.151:** internal: `switch`, `sizeof(Type)`, the one instruction functions of `Bit` and `__fsqrt` and the others are made from the syntax tree as well.
**0.9.150:** internal: the compiler builds most functions from the syntax tree by default (hidden `-noast` goes back to the text); lists of initial values (`int a[4] = {1, 2, 3};`) are made from the tree.
**0.9.149:** internal: `cout` is made from the syntax tree as well (switch `-ast`, not on by default); the buffer for the assembly text of the compiler is 16 MB.
**0.9.148:** internal: structs (fields, arrays of structs, by-value parameters and results), enums and methods are made from the syntax tree as well (switch `-ast`, not on by default).
**0.9.147:** internal: `char` / `i32` values, arrays and pointers are made from the syntax tree as well (switch `-ast`, not on by default).
**0.9.146:** internal: functions with pointers and arrays are made from the syntax tree as well (switch `-ast`, not on by default).
**0.9.145:** internal: functions with `double` values are made from the syntax tree as well (switch `-ast`, not on by default).
**0.9.144:** internal: a first part of the code of the compiler is made from the syntax tree instead of the text (switch `-ast`, not on by default).
**0.9.143:** `#define` with an expression is kept in parentheses (`#define N 2+3`: `N * 2` is 10), array sizes may be constant expressions (`int a[N * 2 + 1];`).
**0.9.142:** double locals stay in double registers (no more moves through whole number registers in loops that carry doubles).
**0.9.141:** vector loops: what does not change is made once in front of the loop, four chunks in a turn (`float` / `i32` / `char` loops within 1.25x of clang -O2).
**0.9.140:** vector loops for `float`, `i32` and `char` arrays (5 times faster than the scalar loop) and for loops that have a number in the body (`a[i] * 2.0`).
**0.9.139:** clearer error messages: they say what was found (`an expression was expected, but found ';'`) and how to go on.
**0.9.138:** programs that use `throw` / `try` / `cin` (Map.get, unwrap, to_int ...) keep their variables in registers again: 25 - 45 % faster on the standard library; faster `alloc` / `free` and one allocation for a new array.
**0.9.137:** new in the standard library: `Fmt`, `Regex`, `Date`, `Csv`, `Toml`, `Log`, `Net` (TCP sockets), `Arena`.
**0.9.136:** error messages in plain sentences with the facts and a help line (the field list of a struct, both types of a mismatch, the import to write, the line of an unclosed block).
**0.9.135:** the standard library in categories (`#import <text>`, `<data>`, `<files>` ...); `Sys::write(...)` works again.
**0.9.134:** the syntax tree reads all 949 function bodies of the tests, benchmarks and examples (String, arrays, enums, switch, try, defer, methods, lambdas); generated code is the same.
**0.9.133:** the syntax tree has types on its nodes and can be printed (`-xastdump`); a fault in how the lists were chained is fixed.
**0.9.132:** the syntax tree probe reads structs and fields: 57 % of the function bodies are in the subset (generated code is the same).
**0.9.131:** the syntax tree probe reads pointers, arrays, doubles and `cout`: 39 % of the function bodies are in the subset (generated code is the same).
**0.9.130:** floating point loops over arrays are vectorised again (3 times faster than scalar in the measurement).
**0.9.129:** array addresses in counted loops are pointers that move on (strength reduction); the vector loop has one branch for each turn.
**0.9.128:** vector loops walk along arrays with pointers (an int copy of 2048 elements is 3 times faster); floating point loops stay scalar (measured: no gain on this core); fewer copies in the generated text.
**0.9.127:** a syntax tree per function body, first step: a probe that reads bodies into a tree (`-xast`); the generated code is the same.
**0.9.126:** the vectoriser: variables stay in registers (0.9.125 was slower than the scalar loop), four elements per turn, sums of whole numbers in two lanes.
**0.9.125:** the first vectoriser: loops over arrays (`c[i] = a[i] + b[i] * k`, copies, fills) run two elements per turn with NEON.
**0.9.124:** counted loops are recognised on the IR (the base of the vectoriser; the generated code is unchanged); the owner chose a syntax tree per function body (T1).
**0.9.123:** known ranges of whole numbers; the rotation of a 32-bit value is one `ror` (crypto code: `Sha256` and the like); the sign fix of `i % 7` / `i / 10` of a counter is gone.
**0.9.122:** functions with 32-bit `float` values (and `f32x4`) go through the IR optimiser too.
**0.9.121:** SIMD step S4: `sum()`, `min()`, `max()` of the lanes of `f64x2`, `i64x2`, `f32x4`, `i32x4`.
**0.9.120:** SIMD step S3: `f64x2::load(@a[0], i)`, `v.store(@a[0], i)`; vectors stay in NEON registers in loops (a loop of `acc += d * 2.0` is 6 times faster).
**0.9.119:** SIMD step S2b: functions with simd operators go through the IR (vectors as temporaries; copies and reloads are single 16-byte accesses).
**0.9.118:** SIMD step S2: `+ - * /` on `f64x2`, `i64x2`, `f32x4`, `i32x4` are one NEON instruction (a number on one side is used for every lane).
**0.9.117:** `#import <simd>`: the vector types `f64x2`, `i64x2`, `f32x4`, `i32x4` (step S1); a float field of a struct can start from a decimal literal.

**0.9.116:** `#pragma read`: global variables that cannot be written (compile time error, and not writable pages at run time).

**0.9.115:** `raw<u32>[...]` writes raw words / bytes inside low-level blocks.

**0.9.114:** `a[lo..hi]` is a view (`Span`) of a part of an array.

**0.9.113:** `a * b + c` with doubles is one `fmadd` (like C compilers do); `-nofma` keeps two roundings.

**0.9.112:** named low-level blocks `_.name { }` called with `_.name;`, and `_. { }` as a short `register { }`.

**0.9.111:** `orr` / `eor` / `and` with a shifted register (rotate idioms are shorter); a value that goes through a frame slot once is kept in a register (sha256 about 10 % faster).

**0.9.110:** a local variable that is set once to a number is that number in every use (loop bounds, products).

**0.9.109:** a double `Mem::free(p)` has its own message.

**0.9.108:** `Span<T>` (a view into an array) and `in` / `out` / `clobber` lines in `register { }` blocks.

**0.9.107:** dead moves into x15 - x17 are removed (small code saving in float struct code).

**0.9.106:** a missing file in `#import "name"` gives a clear message with help (and says when the extension should not be written).

**0.9.105:** `sort_by` (stable, with a comparator), `lower_bound` / `upper_bound` / `binary_search`, `Queue`, `Deque` and `Heap` in the standard library.

**0.9.104:** struct temporaries (`vec3` arithmetic) live in registers instead of stack cells (vec3 benchmark 85 -> 56 ms).

**0.9.103:** an invariant product or quotient in a loop (`i * n` in `a[i * n + k]`) is computed once before the loop.

**0.9.102:** a value that does not change in a loop (the address of `b[i]` in the loop over `j`) is computed once before it.

**0.9.101:** a register rule no longer treats the address of `blr xN` as unused; moves that nothing reads are removed.

**0.9.100:** a use of a variable after `Mem::free` of it is reported (warning; error with `-st`).

**0.9.99:** constants are made once before a loop (on by default); a slowdown of `Mem::alloc` / `free` found by the benchmarks is fixed.

**0.9.98:** `add xD, xN, xM, lsl #n` (shifted register operand): an array index costs one instruction less.

**0.9.97:** elements of the first global arrays are one instruction cheaper to reach; a repeated read of a global array element is made once.

**0.9.96:** the built-in assembler is 7 times faster (the compiler compiles itself in 3.6 s instead of 4.3 s); same output byte for byte.

**0.9.95:** a block of 256 KB or more is given back to the system by `free`; the compiler is a little faster.

**0.9.94:** constants fold and become immediates (shifts, `& 4294967295`, bitmask immediates); sha256 is 25% faster; new benchmarks sha256, hashmap, strings.

**0.9.93:** `-d` builds stop at once on a read or write past the end of a block or after free (guard pages).

**0.9.92:** `import` without the `#` is an error (write `#import <stdlib>`).

**0.9.91:** a number stored in a pointer (`char^ p = 5;`) and a text passed to an `int` parameter are errors.

**0.9.90:** a missing `)` or `]` at the end of a line is reported together with the other errors.

**0.9.89:** the raw mode: a file that starts with `#!library` gets no start code, no runtime and needs no `main` (the file is the program).

**0.9.88:** leaf functions have no frame (no prologue / epilogue) and keep more variables in registers.

**0.9.87:** several missing `;` are all reported (`3 errors generated.`); `using stdlib;` must end with `;` (add it to older programs).

**0.9.86:** leaf functions keep variables in more registers; using the value of a `void` call (`int a = f();`) is an error (it was accepted before); `cout` / `cin` need no import and no `using` (no warning).

**0.9.85:** a function that can reach its end without a value, and a literal index outside a fixed array, are errors; `did you mean 'x'?` for names, functions and libraries; a hint for `int[3] a;`; an error of the assembler is reported as an internal error of jcmp (with the line).

**0.9.84:** error messages: a program without `main` and a call with the wrong number of arguments are reported clearly (the second was accepted silently before); a text stored in an `int`, a value returned from a `void` function are errors too; `docs/error-messages-plan.md`.

**0.9.83:** a round of bug hunting with a fuzzer, a garbage test and an encoding test (no wrong code found in 2,200 random programs); one example fixed.

**0.9.82:** `frame` (`Context::save/restore`: a context switch in two lines), `interrupt` functions, `align(N)`, `@no_reorder { }`. The plan of `syntax-design.md` 63.4 is done.

**0.9.81:** `#reserve`, `register { }` blocks, `Reg::x18`, and pinned variables `int n @ x19`.

**0.9.80:** `device` declarations (hardware registers as data: `Uart.data = 'A';`), `Sys::name` system registers in every function, digit separators.

**0.9.79:** `abi` declarations: `Syscall::call(64, 1, buf, n)` with the registers of a convention you declare.

**0.9.78:** `Cpu::`, `Atomic::`, `Cache::` and `Mem::barrier*` groups: instructions of the CPU by name in every function.

**0.9.77:** the low level begins: `naked` functions written with register statements (`Reg::x8 = 64; svc(0); ret;`), a much bigger assembler checked against llvm-mc.

**0.9.76:** struct temporaries become variables (vec3 benchmark 119 -> 86 ms), functions start at multiples of 32 bytes (fib no longer depends on where it lands).

**0.9.75:** inlining of small functions and methods (vec3 operators 40 % faster); the compiler takes 1 s longer to compile itself.

**0.9.74:** small struct copies are loads/stores; vec operators build in place; vec3 benchmark 323 -> 197 ms.

**0.9.73:** three text rules for copies and addresses of doubles; nbody 31 % faster, mandel 16 % faster.

**0.9.72:** known checks are not made twice (division by zero in loops), `msub`/`madd` of registers, labels only where needed; gcd 16 % faster.

**0.9.71:** jump threading (no more booleans re-tested after && / ||; fib 20 % faster), double constants in one instruction.

**0.9.70:** every function goes through the IR; opposite-condition jumps; double round trips removed (nbody 21 % faster than before the IR optimiser).

**0.9.69:** the IR optimiser is on: value numbering (repeated `b + i * 56` is computed once), copy/constant propagation, dead code; `nbody` 22 % faster.

**0.9.67:** `Bit::clz ctz popcount rotl rotr bswap` — instructions of the CPU as names of the language (no call, no assembly).

**0.9.66:** the IR is made from the compiler's code (lifting and lowering, `-irtrip` passes every test and the compiler itself); locals with a String field start as zeros (an old fault); the test script uses the newest compiler; `-d` crashes say where.

**0.9.65:** the IR data structures, printer and checker (`jc_ir.j`; no change of the generated code yet).

**0.9.64:** `-d` finds double free and writes after free and names the function of every leak; `-Wmoved` for `p[i]`; pools reuse given-back pieces; two ownership faults fixed (push of a temporary struct, arrays of self-freeing structs).

**0.9.63:** the bracket forms of memory: `alloc[int^ p = n]`, `alloc0`, `free[p]`, `grow[p = n]`, `arr[n]`, and pools `alloc[pool[12] >> int^ a]`.

**0.9.62:** the mascot's shadow on the Earth is a J when the Moon is a J.

**0.9.61:** a new heap allocator (size classes, splitting and joining), no lock before the first thread, a literal index is an offset.

**0.9.60:** `Mem::copy` / `Mem::set` by words.

**0.9.59:** call arguments in registers instead of the stack (2 to 4 plain arguments); functions that own memory can use registers too.

**0.9.58:** a register allocator (live variable analysis + linear scan; doubles in d8..d15), floats stay in floating point registers (n-body 593 -> 321 ms, Mandelbrot 72 -> 49 ms); `b.len` on arrays of structs; the J-shaped shadow of the mascot's Moon.

**0.9.57:** faster floats (literals worked out at compile time) and array access, a better register pass (sieve 98 -> 60 ms, matmul 62 -> 36 ms).

**0.9.56:** faster code, third step: a register pass keeps the busiest locals of loops in x19..x25 (sieve 143 -> 98 ms, matmul 85 -> 62 ms).

**0.9.55:** `jcmp -space` shows the pixel mascot (ASCII if the terminal has no 24-bit colour); smaller J in the colour of the Moon; no orbit line.

**0.9.54:** `jcmp -space px` (colour pixels) and `jcmp -space pxg` (white, grey, black pixels): the mascot in pixels, two ways to compare.

**0.9.53:** the mascot's Moon is plain when full and becomes the letter J from a half Moon to a crescent.

**0.9.52:** the solar system example in colour (lit balls with surfaces, rings of Saturn, sun corona); the mascot has air and city lights.

**0.9.51:** `str(x)` (number to String); any number of array parameters; `move(ps[i])` on array elements.

**0.9.50.1:** the README status tables and the language tour are up to date.

**0.9.50:** two functions with the same name are an error; faster compound assignment.

**0.9.49:** `<` `>` `<=` `>=` on Strings; `@name` of a switch binding; four larger test programs checked against Python.

**0.9.48:** `for i in lo..hi` with a variable start (an old fault); `Screen` drawing (line, rect, circle, gradient) and effects (vignette, scanlines, brightness, invert).

**0.9.47:** math library: `quat`, `complex`, `stats`.

**0.9.46:** fixes `a[a.len - 1]` (an old fault); `Path`, `Hex`, `Base64` in the standard library.

**0.9.45:** faster code, second step: a peephole pass, better loops and array access (fib 211 -> 93 ms, sieve 276 -> 144 ms).

**0.9.44:** faster code: operands wait in registers instead of the stack, one-instruction variable reads, division by a literal without `sdiv` (fib 211 -> 136 ms, loop 1554 -> 1105 ms).

**0.9.43:** `(a + b).dot(c)`, `-v` and `2.0 * v` on structs with operator methods.

**0.9.42:** the mascot is real ASCII art: a rich ramp of 66 characters and edge characters that follow the line.

**0.9.41:** the mascot: smoother (4 rays per character, dither), clouds and shores on the Earth, craters on the Moon.

**0.9.40:** the mascot: the Earth with the Moon that carries the letter J, fixed Sun, real phase and clock, slower, with the scale.

**0.9.39:** the mascot: finer in a big terminal (60 x 24, 76 x 30), the Moon of digits with its name, the unlit part left black.

**0.9.38:** the mascot: a fuller Earth (letters-only ramp, brighter) and a bigger, clearer Moon; shorter captions.

**0.9.37:** the mascot is the Earth that turns and goes round the Sun, with the Moon and its phases and the real light times.

**0.9.36:** the mascot is a globe with a raised white J, in black, white and grey, with light and shadow and a thin Kepler ring.

**0.9.35:** fixes the source of 0.9.34 (it did not build); the mascot has more detail (a hanging J, belts, ringlets, small moons, grey shadows, glints on the rings).

**0.9.34:** the mascot is 50 x 20 and shows Earth time (UTC clock, and the hours that have passed on the planet).

**0.9.33:** the mascot in colour with a day/night side and rim glow; `jcmp -space N` sets the time speed (default 1500).

**0.9.32:** the mascot moves with Saturn's real numbers (ring radii, Kepler speeds, 10.56 h spin, 26.73 degree tilt; time x4000).

**0.9.31:** the mascot is a Saturn-like J with rings, light and shadows, and a less stiff turning.

**0.9.30:** the mascot's bodies orbit the J by Kepler's laws (like a solar system).

**0.9.30:** the mascot is a solid 3D (isometric) J with balls orbiting by Kepler's laws.

**0.9.29:** the mascot looks like Saturn (rings round the J) with a credit line.

**0.9.28:** `jcmp -space` shows the J2K logo in ASCII (the mascot).

**0.9.27:** example `logo.jk` (the J2K logo animation); `Screen.add`.

**0.9.26:** array lists (`double a[3] = {1.0, 2.0, 3.0};`), colour dots in gfx (`Screen`), `Term` (size, key press), a colour black hole.

**0.9.25:** the examples run until Ctrl-C; better solar system (Kepler orbits, sun-lit planets, moons, ring) and black hole (Doppler, redshift).

**0.9.24:** `#import <gfx>` with `Canvas` (ASCII drawing with a depth buffer); examples `solar.jk` and `blackhole.jk`.

**0.9.23:** example `examples/solar.jk`: an ASCII solar system.

**0.9.22:** `vec pos = {1.0, 2.0, 3.0};` and swizzles (`v.xy`, `c.rgb`).

**0.9.21:** JSON in the standard library (`Json::parse`, `JsonDoc`); `Result<T, E>` with an owning struct works (`unwrap`).

**0.9.20:** operator methods (`operator vec3 add(...)` makes `a + b` work); math types are `vec2/3/4`, `mat3/4`.

**0.9.19:** `#import <math>` and `using math::vector;` / `using math::matrix;`.

**0.9.18:** math libraries `<vector>` (Vec2/3/4) and `<matrix>` (Mat3/4).

**0.9.17:** `Sha256::hex` and `Sha256::file`.

**0.9.16:** `Proc::run` and `Proc::output` start other programs.

**0.9.15:** UTF-8 text: `count()`, `chars()`, `char_at(i)`; `upper`/`lower` for Latin, Greek and Cyrillic.

**0.9.14:** `Num::parse_int` / `Num::parse_double` return a `Result`.

**0.9.13:** a panic prints the chain of functions that were running; `using enum` for data enums; up to 256 structs per program.

**0.9.12.1:** methods can be chained on any String or array expression (`"text".trim().len`, `Env::args().len`); use of a moved value in a method call is warned.

**0.9.12:** the `Math` library is complete (exp, log, sin, cos, tan, atan2, pow with decimal exponents, ...); `pow(x, n)` with a whole exponent is now `powi`; decimal literals with exponents beyond 18 are right.

**0.9.11:** fixes names longer than 23 characters being cut short (two functions could be mixed up); new `Fs`, `Dir`, `Env`, `Time`, `Random` in the standard library.

**0.9.10:** bugs (divide by zero, null array, position out of range, ...) are panics that try/catch cannot catch; `panic`, `assert`, `Map.try_get`.

**0.9.9:** `defer`.

**0.9.8:** `Option<T>`, `Result<T,E>`, `Error` and `expr?` (an error goes back to the caller); values that free themselves move.

**0.9.7:** enums that carry values (`Circle(double r)`), `switch` that takes them apart, generic enums.

**0.9.6:** String methods `trim upper lower replace repeat starts_with ends_with contains to_int to_double split join`.

**0.9.5:** `-o folder/` puts the program in that folder under the name of the source; `jcmp test.jk sub/test` names it.

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
(options: `--dir ../bin`, `--version 0.9.84`, `--with-assembler`), or download `jcmp` below, check it
against `SHA256SUMS` and `chmod +x` it. See the README.

**Use:** `jcmp hello.jk && ./hello`

Files: `jcmp` (the compiler), `j2k_asm` (stand-alone assembler),
`jcmp-0.9.84-linux-arm64.tar.gz` (both + README + LICENSE + examples + docs), `SHA256SUMS`.
Linux ARM64 only. See LICENSE for the terms of use.
