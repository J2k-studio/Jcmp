# Changelog

## 0.9.161
* **AST A6:** array parameters (`int a[]`, `P ps[]`, `char t[]`), the arguments that are arrays or texts (address + number of elements), `a.len` on them, and `char w[16] = "text"` with `cout << w` are made from the tree.
* **New warning `-Woldlen`:** `name__len` is the old way to read the length of an array parameter; use `name.len`. The old name still works.
* Gate: 481 tests pass (default and `-noast`), 300 fuzz programs, `diffcheck` the same 2 differences. 1549 of 1846 corpus functions come from the tree.
* Tests: `t426_ast_chararray`, `t427_ast_arrparam`, `t428_warn_oldlen`.

## 0.9.160
* **AST A6:** `syscall(n, ...)` and a text literal where a `char^` is wanted (`char^ p = "abc"`, `f("text")`) are made from the tree.
* Fix: a `main` that contains a system call was cut at the first `svc` by the lifter and the register pass; its end is `mov x8, 94` + `svc 0` now.
* Gate: 476 tests pass (default and `-noast`), 300 fuzz programs, `diffcheck` the same 2 differences. 1508 of 1823 corpus functions come from the tree.
* Tests: `t424_ast_textptr`, `t425_ast_syscall`.

## 0.9.159
* **AST A6:** `switch` over data enums (`Option::Some(v): ...`) and structs with `free(self)` by value (moved into a copy, the source emptied) are made from the tree.
* Error messages: `help:` lines for ~60 common errors.
* Gate: 472 tests pass, 300 fuzz programs, `diffcheck` the same 2 differences. 1496 of 1814 corpus functions come from the tree.
* Tests: `t422_ast_dataenum`, `t423_ast_freestruct`.

## 0.9.158
* **AST A6: `try` / `catch` / `throw` from the tree** (the 120-byte snapshot of `x19` .. `x25` and `d8` .. `d15`, `j2k_try_enter`, the reload in the catch; `break` / `continue` / `return` inside a `try` leave the tries first). The name in `catch (e)` is a `char^` in the tree now (it was typed like a String), so `cout << e` prints a text.
* **Dynamic arrays of pointers and of enum members** (`Node^[] list = arr(2);`, `list.push(p)` moves an owner into the array, `list[i]^.v`), **arrays that are returned and passed on** (`int[] f()`, `return a;`, `int[] b = f();`), **`a == null` / `a != null`**, `a = null`.
* **Arrays of Strings** (`String[]`): `push`, `pop`, `insert`, `remove`, `clear`, `sort`, `contains`, `index_of`, `join`, `resize`, `free`, `len`, `names[i]` as a String place (read, `=`, `+=`, a method).
* Statement tags: a variable that the parser made null (its memory moved) is looked at only when it is the value of the statement being lowered (a push no longer takes the null of the next statement).
* `-ast2` prints the first statement or condition that the lowering does not take (`stmt: ...` / `cond: ...`), in the syntax of the tree.
* `tools/fuzz_str.py` uses an array of Strings too (270 more programs, 0 differences).
* The gate: 468 tests pass with the default and `-noast`, 300 fuzz programs, `diffcheck` the same 2 differences. 1367 of 1743 functions of the corpus are built from the tree.
* Tests: `t420_ast_try` (6), `t421_ast_arrays` (9).

## 0.9.157
* **`main` is made from the syntax tree too** (hidden `-noastmain` goes back). The reason it was off in 0.9.156 was the layout of blocks, not the register pass: the text path writes a loop as test, body (falls through), jump back; the tree wrote test, exit, ... and the body at the end of the function, so the live range of a variable of the loop spanned everything in between and the variables of the later loops found no register. **The layout puts the side of a branch that leads back to the test (the body of a loop) next to the test now**, for all code (the benchmarks `arrays`, `strings`, `mandel`, `sha256` of the tree are at the speed of the text path again).
* `-rgdbg` (hidden): what the register pass thinks of every slot of `main` (state, uses, weight).
* The gate: 464 tests pass with the default and with `-noast`, 300 fuzz programs, `diffcheck` the same 2 differences, benchmarks equal within the noise of the phone. 1227 of 1671 functions of the corpus are built from the tree (the mains count now).
* Counts of the lowering tests (`t405` .. `t419`) are one more each (the `main` of the test).

## 0.9.156
* **Vectoriser: one pointer for all arrays that a loop walks together.** A vector loop used one pointer (a cell of the frame, loaded at every access) for each array; now the arrays of the same base whose offsets are equal modulo 16 and within 60000 bytes share one pointer, and the distance between the arrays goes into the offset of each `ldr q` / `str q`. `c[i] = a[i] + b[i] * k` was 3 pointers and 3 steps for each turn: now 1 and 1. The `arrays` benchmark (an `axpy`, a copy and a sum of 2048 elements, 60000 times) is 187 -> 139 ms.
* `main` made from the tree is behind the hidden switch `-astmain` (it works and passes the tests, but the register pass gives the variables of `main` to other slots than the text path does and the `arrays` benchmark was 172 -> 210 ms, `strings` 72 -> 81 ms); every other function is made from the tree by default as before.
* The gate: 464 tests pass with the default and `-noast`, 300 fuzz programs, `diffcheck` the same 2 differences.

## 0.9.155
* **AST A6, ownership layer 4: Strings and dynamic arrays in struct fields, in globals and through pointers.** `r^.name`, `s.items`, `gname`, `grec.name` as the receiver of every String / dynamic array operation, as the target of `=`, `+=`, `push`, `free()`, as an argument, as the base of `[i]` and `.len`; `d = arr(n)` and `d = other` on a place; a local struct with a String or an array in it starts as zeros (like the text path); `s.free()` on a String. A place may be a chain of fields, derefs and indexes that has no call in it (it is worked out twice).
* `tools/fuzz_str.py` also uses a struct with two Strings (local and global) and a global String: 150 more programs, 0 differences between the tree and `-noast`.
* The gate: 464 tests pass with the default and `-noast`, 300 fuzz programs, `diffcheck` the same 2 differences, speed equal. 1041 of 1483 functions of the corpus are built from the tree.
* Test: `t419_ast_fields` (3 functions).

## 0.9.154
* **AST A6, ownership layer 3: Strings from the tree.** String variables and parameters (borrowed), `String s;` / `= "text"` / `= other` (a copy) / `= a + b` (taken over), `s = ...` (the old content goes), `s += String | text | char`, `a + b` and `+` chains (a new String is a temporary owner that is freed at the end of the statement, or before the jump of an `if` / `while` condition), `== != < <= > >=`, `s.len`, `s.cap`, `s[i]`, `cout << s`, `push` / `pop` / `clear` / `append`, `find` / `contains` / `starts_with` / `ends_with` / `count` / `to_int` / `to_double`, `slice` / `trim` / `upper` / `lower` / `repeat`, a text given to a String parameter (a temporary String is made), functions that return a String (an owner or a temporary moves out, anything else is copied), calls used as statements. The text parser records its decisions (temporaries added, the places where they are freed, what was moved) and the tree follows them; any difference stops the tree for that function.
* `tools/fuzz_str.py`: random String programs compiled both ways must do the same (100 programs, 0 differences).
* The gate: 462 tests pass with the default and with `-noast`, 300 fuzz programs, `diffcheck` the same 2 differences, speed equal. 964 of 1443 functions of the corpus are built from the tree.
* Tests: `t417_ast_string` (3 functions), `t418_ast_string2` (7).

## 0.9.153
* **AST A6, ownership layer 2: dynamic arrays of numbers from the tree.** `T[] a = arr(n);` (also `T[] a;` and `T[] b = a;`), `a.len`, `a.cap`, `a[i]` (with the null check of the header), assignment and op-assignment on elements, `a.push(v)`, `a.pop()`, `a.resize(n)`, `a.clear()`, `a.free()`, passing an array to a function (`int[] a` parameters borrow), for `int`, `i8`, `i32`, `char` and `double` elements. The owner records and the frees at the end of blocks come from the parser's events (layer 1). A `-d` build, an array of structs / Strings / pointers, assigning to an array variable, `sort` / `insert` / `index_of` and the other list functions stay on the text path.
* The gate: 458 tests pass with the default and `-noast`, 300 more fuzz programs, `diffcheck` the same 2 differences, speed equal. 926 of 1421 functions of the corpus are built from the tree.
* Test: `t416_ast_dyn` (3 functions).

## 0.9.152
* **AST A6, ownership layer 1: memory that frees itself (`alloc`, `free`, owners of structs that free themselves) from the tree.** The text parser still decides what is owned and where it is freed; it now records its decisions as a list of events per function (an owner was added, a place where owners are freed: end of a block, `return`, `break`, `continue`, end of the function; a variable became null because it was freed or moved). The tree makes the same record of the cleanup chain (`[x27 + 784]`), the same frees and the same nulls from that list, and **refuses the function when the list does not match exactly what the tree did** (any event left over, any place that was not met): the text path then makes it, as before. Covered: `T^ p = (T^)alloc(n)`, `free(p)`, `Mem::free(p)`, `return p` (the owner is null first), storing an owner into a field / element (it becomes null), owners freed at the end of blocks and loops, structs with `free(self)` as variables and by-value parameters. `-d` builds keep the text path for functions that own memory (the line of every allocation).
* The frame offsets of the 32-byte cleanup records come from the parser's list and are checked against it.
* `-ast2` also prints the events (`own FUNCTION: type a b c d`).
* The gate: 456 tests pass with the default and with `-noast`, 300 more fuzz programs, `diffcheck` the same 2 differences as before, speed equal. 909 of 1411 functions of the corpus are built from the tree.
* Test: `t415_ast_own` (4 functions: lists, nested blocks, `break` / `continue` / `return` with owners).

## 0.9.151
* **AST A1b, seventh part: `switch`, `sizeof(Type)`, `Bit::clz / ctz / popcount / bswap / rotl / rotr` and `__fsqrt / __ffloor / __fceil / __ftrunc` from the tree.** A `switch` on a whole number, a `char` or an enum with constant patterns (`1, 2:`, `-5:`, `'a':`, `Kind::Plus:`) and `_`: the tests in order, then the bodies; the default runs when nothing matched wherever it is written; `break` / `continue` inside go to the loop around the switch. `sizeof(int)`, `sizeof(P)`, `sizeof(int^)` are numbers in the tree. The functions of `Bit` are the one instruction (`clz`, `rbit` + `clz`, `popcnt`, `rev`, `ror`) and the four functions of the double unit are `fsqrt`, `frintm`, `frintp`, `frintz`, as in the text path. 900 of 1404 functions of the corpus are built from the tree (873 of 1387 in 0.9.150).
* The gate: 454 tests pass with the default and with `-noast`, 300 more fuzz programs, `diffcheck` (`-noast`, `-noir`, `-noinl`) the same differences as before (an out of range read in `t154_bounds` that depends on what is in the frame), speed equal.
* Test: `t414_ast_switch` (7 functions).

## 0.9.150
* **The tree is the default path (A6, first step): the functions of the subset are built from the syntax tree without any switch.** `-noast` (hidden) makes every function from its text as before; `-ast` is accepted and does nothing. The functions that the tree does not lower yet (Strings and dynamic arrays, `alloc` / `free` / `arr`, `switch`, `try`, lambdas, `float`, structs that free themselves) are still made from the text, one function at a time, and the frame check keeps the two paths consistent. The compiler built with the tree path is byte-identical when it compiles itself again (fixed point). Compile time of the compiler: 6.5 s -> 7.1 s (the tree is read for every function); the program is 0.9 % smaller.
* **Lists of values from the tree:** `int a[4] = {1, 2, 3};` (the rest is 0), `int b[] = {..}`, `double`, `char`, `i32` arrays, structs `P p = {7, 8};`, nested structs, arrays inside structs.
* `-ast2` names the first builtin that keeps a function on the text path (`kind 35 arr`).
* The gate: 452 tests pass with the default and with `-noast`, 300 more fuzz programs, `diffcheck` with the default as the base; `tools/diffcheck.sh` has `-noast` among its variants now. Speed equal to the text path.
* Test: `t413_ast_list` (2 functions).

## 0.9.149
* **AST A1b, sixth part: `cout` in the lowering from the tree** (`-ast`): texts, whole numbers, `char`, `bool`, enum values, doubles, expressions; one value alone ends the line, as the text path does. The literals are the ones the text path placed in the data area (the compiler keeps a list per function and the tree finds its literal there; nothing is placed twice). A call to a function that returns a pointer can start a pointer variable (`P^ r = pick(@a, @b, 0);`). 847 of 1385 functions of the corpus are built from the tree (835 of 1373 before the count of this release's tool; 727 in 0.9.148).
* The text of a character literal is a `char` in the tree now (`cout << 'z'` prints `z`; it was typed as a number).
* **The buffer of the compiler for the assembly text is 16 MB** (it was 8 MB): the compiler is close to 8 MB while it works (the final file is 5.5 MB) and one more function made it stop with `output too large`.
* The gate: all 449 tests pass with `-ast`, `diffcheck -ast` 172 builds 0 differences, 300 more fuzz programs (their `main` is built from the tree), speed equal to the text path.
* Test: `t412_ast_cout` (6 functions from the tree).

## 0.9.148
* **AST A1b, fifth part: structs, enums and methods in the lowering from the tree** (`-ast`): fields of structs (`s.x`, `p^.x`, `a[i].x`, `s.inner.x`, `s.arr[i]`; locals, globals and pointers), nested structs, arrays of structs (locals, globals, `P^` indexed), `@s`, `@s.x`, `@a[i]`, op-assignment and `++` on fields, bool / `char` / `i32` / `double` / pointer fields with their own width; structs **by value**: parameters (the callee copies the struct that came by address, as the text path does), results (the address of a hidden slot goes in the first register), `a = b`, `T c = f(x)`, `return v`, a struct as an argument, results of calls as arguments (`dot(mk(1, 2), twice(mk(3, 4)))`), methods that take or give structs; methods (`s.add(v)`, `p^.mean()`); members of plain enums (`Color::Red`, `using enum`) as values, enum variables, parameters, results, fields and arrays. The hidden slots of results of calls get the offsets that the parser gives them (checked by the frame hint, as before). 727 functions of the corpus are built from the tree (465 before; 1367 functions in all).
* Fixed in the tree (not visible in programs, found while lowering): `u8` / `u32` / `u64` locals were typed like members of an enum, and a variable of the first enums (type ids 3, 4, 7, 8) was typed like `bool` / `i32` / `double` / `int`; arrays of enums have 8-byte elements in the tree now, as in the text path.
* `-ast2` says why a function stays on the text path (`astlow: NAME rejected: ...`).
* The gate: all 448 tests pass with `-ast`, `diffcheck -ast` 171 builds 0 differences (and `-ast -d` the same 5 differences as plain `-d`), 300 more fuzz programs (struct by value is lowered there), speed equal to the text path on `vec3`, `nbody`, `hashmap`, `qsort`, `sha256`, `strings`, `matmul`, `mandel`; a loop over an array of particles is 56 -> 39 ms from the tree.
* Tests: `t409_ast_struct` (9 functions), `t410_ast_enum` (6), `t411_ast_byvalue` (13).

## 0.9.147
* **AST A1b, fourth part: `char`, `i8` and `i32` in the lowering from the tree** (`-ast`): narrow locals, parameters, globals, fixed arrays (`char b[12];` takes 12 bytes in the frame), `char^` / `i32^` pointers, elements and `p^` read with their own width (`ldrb`, `ldrsb`, `ldrsw`) and written with a store of that width, a store into a narrow variable and a cast `(char)x` wrap the value. 465 functions of the corpus are built from the tree (426 before).
* The gate: all 442 tests pass with `-ast`, `diffcheck -ast` 168 builds 0 differences, 200 more fuzz programs, speed equal to the text path.
* Test: `t408_ast_narrow` (5 functions from the tree).

## 0.9.146
* **AST A1b, third part: pointers and arrays of whole numbers and doubles in the lowering from the tree** (`-ast`): `int^` / `double^` parameters, locals and globals, fixed one-dimensional arrays (`int a[10];`, locals and globals), `a[i]`, `p[i]`, `p^`, `@x`, `@a[i]`, assignment and op-assignment through them (`a[i] += v`, `p^ = v`, `a[i]++`), pointer comparison with `==` / `!=`, and a call of a `void` function as a statement. The address of an element with a number as index is a base register and an offset (no arithmetic); a global array is `add x0, x28, i, lsl #3` and the offset of the array goes into the load, as the text path does. The left operand of a binary operator waits in a register (v9 ..) when the right one has no call, a number or a variable goes straight to the second operand; before this a cell of the frame was used, and the inliner kept the cells (`rotr` of `sha256` was not inlined as a rotation: 80 -> 143 ms). The functions that the text path turns into instructions (`Bit::`, `Cpu::`, `Cache::`, `Atomic::`, `Mem::barrier*`) and `-d` builds (bounds checks) stay on the text path. 426 functions of the corpus are built from the tree (289 before), 2 are refused by the frame check.
* The gate: all 440 tests pass with `-ast` on, `diffcheck` with `-ast` and `-ast -d` (the `-d` tests that must stop do the same as `-d` alone), 600 fuzz programs with `-ast`; speed equal to the text path on `sha256`, `qsort`, `hashmap`, `arrays`, `fib`, `gcd` (the other benchmarks give the same program, byte for byte).
* `tools/ast_lower_corpus.sh`: how many functions of the corpus come from the tree.
* Test: `t407_ast_pointer` (10 functions from the tree: sums, a bubble sort through `@p[j]`, doubles in arrays, global arrays and pointers).

## 0.9.145
* **AST A1b, second part: `double` in the lowering from the tree** (`-ast`): `double` parameters, locals, globals, results, literals (`float_literal_bits` is shared with the text path), `+ - * /`, comparisons (also a whole number against a double), casts `(double)` / `(int)`, op-assignments, calls with double arguments (the 64 bits go in the whole number registers, as the text path does). The left operand of a binary operator waits in a double register (d24 .. d29) while the right one is worked out; only an expression that has a call in it uses the stack. 289 functions of the corpus are built from the tree now (200 before). A function with a pinned variable is refused by the frame check, as it must.
* The gate (the same as for 0.9.144): all 438 tests pass with `-ast` on, `diffcheck` 166 programs 0 differences, 250 fuzz programs with `-ast`. Speed of double code from the tree is that of the text path (49 -> 53 ms of a loop of Mandelbrot and Newton: the noise of the phone).
* Test: `t406_ast_double` (6 functions from the tree, checked against Python).

## 0.9.144
* **AST A1b, first part: a function body can be built straight from the tree** (hidden switch `-ast`; `-ast2` also says which functions were built from the tree). The functions that use only `int` / `bool` parameters, locals and globals, arithmetic and comparisons, `&& || !`, `if` / `while` / `for a..b`, `break`, `continue`, `return` and calls of such functions get their IR from the tree (`jcmp/jc_astlow.j`: `ast_lower`); every other function is lifted from its text as before. Division and remainder by a constant use the magic number (shared with the text path: `div_magic`), by a variable they stop for 0 unless the variable was tested against 0 by the loop or `if` that holds the division. The frame that the tree computes (offsets of the parameters and locals, the hidden bound of a `for`) is compared with the hint line of the text parser, and the text path is used when they differ.
* The gate: all 436 tests pass with `-ast` on (every test built both ways), `tools/diffcheck.sh` has `-ast` among its variants (164 programs, 0 differences), 150 fuzz programs with `-ast`. Speed: `fib` 72 -> 74 ms, `gcd` 276 -> 287 ms (the same code; noise of the phone).
* Bugs of the tree probe found by running it on real builds (it only ran with `-xast` before): `#multithread` and `#pragma read` were left switched on after the probe read ahead; `a[lo..hi]` is rewritten to `span(a, lo, hi)` in the buffer while it is read, and the probe put the old length back (the file seemed to end early). The numbers of the locals are those of the body now.
* Test: `t405_ast_lower` (7 functions from the tree; checked against Python).

## 0.9.143
* **`#define` is right now** (the owner: "fix define"): a text that is an arithmetic expression of several tokens is kept in parentheses, so `#define N 2+3` and `N * 2` give 10, not 8. A text that is not an expression (a type, an argument list, a statement, an assignment, a string, a keyword statement) is substituted as written, as before.
* **An array size may be a constant expression**: `int a[N * 2 + 1];`, `char b[1 << 8];` (numbers, `( )`, unary `-` and `~`, `* / % + - << >> & xor |`; a division by zero is an error). Before, only a single number was accepted.
* **AST A2 (the tree resolves what it held without understanding)**, measured with the new `tools/ast_corpus.sh` on the 1054 bodies of the tests, the benchmarks and the examples: nodes of unknown type 762 -> 38, names kept by their text 259 -> 0 unresolved (each is classified: a member of an enum / of a data enum / made visible by `using enum` / a function used as a value / a library name / a device), every body is in the subset (1054 of 1054; before: two bodies of `Option` / `Result` with `self^`). Element types of dynamic arrays are kept (`v[i]`, `pop`, `get` give the element), the results of the methods of String and arrays have types (void is kind 7), `alloc[... int^ p]` declares its pointer, `using enum` is read by the tree, lambdas and `using` have their own node kinds. `-xast2` lists every node the tree does not understand.
* Tests: `t403_define_expr`, `t404_ast_resolve` (with `t404_ast_resolve.ast`: nothing left unresolved).

## 0.9.142
* **A local `double` is no longer moved through a whole number register** (`op_fslots` in `jcmp/jc_opt.j`). The front end keeps a double in an 8-byte slot with `fmov x0, d0 / str x0, [slot]` and `ldr x0, [slot] / fmov d0, x0`; when the slot became a register the two moves between the register files stayed in the middle of the chain of a loop that carries `x` and `y` (3 - 5 cycles each). A slot whose stores all put in the result of an `f2bits` (or a constant, or a load of another such slot) and whose loads are read by `bits2f` only is a double slot now: its stores and loads work on double registers (`str d`, `ldr d`), and the register pass (`jc_regs.j`) understands them (`rg_isd`).
* **The copy of a double that waits in another register is forwarded** (`pt_fwd_copy`): `fmov d25, d9 / fmul d16, d25, d25` becomes `fmul d16, d9, d9`; every read of the copy up to the next label, jump or call reads the original, and the copy goes when it is not needed afterwards.
* `mandel` 45 -> 40 ms, `matmul` 39 -> 36 ms; `nbody` and `vec3` unchanged.
* Test: `t402_double_slots` (checked against Python; the same output with `-irclr 32`, `-noir`, `-noregs`).

## 0.9.141
* **What does not change from turn to turn is made once, in front of the vector loop** (`vz_licm` in `jcmp/jc_opt.j`): the body of a vector loop reused the registers of the scalar body, so the general LICM could not move anything out of it, and the broadcast of `k`, the float `2.0` and the load of a parameter were done again in every chunk. The body is renamed (a new name at every write), the instructions that read only registers that the body does not write are moved into a block that runs once, and the same value computed in two chunks is made once. `widths` 185 -> 101 ms.
* **Four chunks of 16 bytes in a turn** (two for `char`, so that short arrays still get a vector loop), and **a partial sum of its own for each chunk** (the four additions of a turn do not wait for each other). `arrays` 248 -> 190 ms.
* `bootstrap.sh`: the tests `t4xx` are not compared with the frozen seed (it has no `float`).
* Test: `t401_vectorize_carry` (a dependence between two elements of one turn: `p[i + 2] = p[i] + 1`, sums, every length).

## 0.9.140
* **The vector loops understand elements of 4 bytes (`float`, `i32`) and 1 byte (`char`)**, and whole number arithmetic on them: `fb[i] = fa[i] * k + 2.0;`, `ib[i] = ia[i] + c;`, `cb[i] = ca[i] xor c;`, also `- * & | xor` and `<<` by a number (the lanes keep the low bytes of the result, which is all that a store keeps). A turn handles 2 x 16 bytes: 4 / 8 / 32 elements; the odd tail runs in the scalar loop. `tools/bench/widths.jk`: 1075 -> 185 ms (clang -O2: 80 ms).
* **A number written in the body of a vector loop is no longer a reason to stay scalar** (`a[i] * 2.0`, `p[i] + 3`): the address of the left side of an assignment was kept in a temporary cell below the frame while the right side was computed; the pass that forwards a stored value to its load did not touch such a cell unless it was written again. Now a temporary cell that exactly one load reads is forwarded (`cf_nloads` in `op_cell_fwd`). This also removes a store and a load in other scalar code.
* NEON in the assembler: `add sub mul` with `.16b`, `and orr eor` on vectors, `ushl`, `dup vD.16b, wN` (checked against llvm-mc: `test/asm_check_neon.txt`).
* Tests: `t399_vectorize_const`, `t400_vectorize_widths` (the same result with the vectoriser off and with `-noir`, for every length 0 .. 70).

## 0.9.139
* **More messages say what was found and how to go on.** "an expression was expected, but found ';'", "a type was expected, but found ...", "a statement was expected, but found ...", "the name of the function was expected, but found the number 5" (a number is named as a number, not by an old word), each with a `help:` line. `unknown escape sequence` names the character and lists the known ones; `^` on a value that is not a pointer, `.len` on a value without a length and an array argument that is not an array explain the rule. (`write_found` / `die_found` in `jcmp/jc_lex.j`.)
* Tests: `t394` .. `t398`.

## 0.9.138
* **A program that uses `try`, `throw` or `cin` has its variables in registers again** (the biggest speed gain of the standard library: 25 - 45 %). Until now `used_try` switched the register pass off for the whole program, because a throw jumps over the frames in between without giving their registers back; but `Map.get`, `Option.unwrap`, `String.to_int`, `Result` and `cin` all throw, so every program that used them ran with all its variables in memory. Now only a function that has a `try` itself keeps its variables in the frame, and it saves x19 .. x25 / d8 .. d15 into its frame when the try begins and puts them back where it catches (`try_regs` in `jcmp/jc_stmt.j`). Measured with `tools/bench/stdlib_speed.jk` (new; ms for the same work, before -> after): Map<int,int> 131 -> 90, Map<String,int> 129 -> 97, sort_by 133 -> 91, Json::parse 37 -> 26, Sha256 15 -> 8, Fmt::fixed 45 -> 32, Csv::split_line 58 -> 37, String append 42 -> 28.
* **The caller-saved registers x8 and x9 for the variables that live between two calls** (`rg_callpre` in `jcmp/jc_regs.j`): in a function that is not a leaf, a variable whose interval has no call inside may take them when the text does not mention them.
* **`Mem::alloc` / `Mem::free` do the common case in the function itself** (one thread, a small block with a free list): 60 -> 40 ns for a pair. **A new dynamic array or String is one allocation** (the first data block is part of the block of the header; `h[2] == h + 32` tells it; the data moves to a block of its own when the array grows).
* Test: `t393_try_registers` (a throw through functions that use many registers; the same output with `-noregs`, `-noir`, `-d` and with the compiler of 0.9.137).

## 0.9.137
* **New parts of the standard library** (`docs/STDLIB.md`): `Fmt` (text: `fixed`, `pad_left`, `pad_right`, `thousands`, `hex`, `bin`, `percent`, `bytes`), `Regex` (text: `matches`, `find`, `find_text`; `. \d \w \s [a-z] [^0-9] * + ? ^ $ |`), `Date` (time: a calendar date and time from and to seconds since 1970, `weekday`, `day_of_year`, `add_days`, `text`), `Csv` and `Toml` (data: one line of values with quotes; settings by `section.key`), `Log` (system: messages with a level on standard error), `Net` (a new category `<net>`: TCP sockets, `pair`, `listen`, `accept`, `connect`, `send`, `recv`) and `Arena` (core: memory handed out in a row and given back at once).
* `gen_std.sh` has 9 units now (the new `net` is bit 8, `stdlib` is 511).
* Tests: `t387_fmt`, `t388_date` (checked against Python), `t389_csv_toml_log`, `t390_regex` (checked against Python `re`), `t391_net` (a socket pair, and a listening socket with a client in the same program), `t392_arena`.

## 0.9.136
* **Error messages in plain sentences with the facts** (`docs/error-messages-plan.md`, the night of 2026-10-14): `'break' can only be used inside a loop` (the position is the keyword; it was the token after it); `'a' is already declared in this block (the first one is on line 2)`; `the file ends inside a block: the '{' on line N is never closed`; `expected ';', but found 'x'` (the token that was found is named); `the struct 'P' has no field 'y'` / `no method 'go'` with the list of the fields (methods) of the struct; `this value cannot be indexed with [ ]`; `a variable cannot be called like a function`; `argument 1 of 'twice': a text was given, but the parameter is a number`; `a decimal number cannot be stored in a whole number (int)`; `this operation needs numbers, but the left side is a String`; `this function returns a String, but this 'return' gives a number`; `a String cannot be made from a number`; `unknown type 'Foo'`; `library not found 'x'` with the places that were searched; `unknown function 'alloc'` says to write `#import <stdlib>`.
* The names of types in messages: a String, null, nothing (void) are named (before the name of a String was empty).
* Tests: `t375` .. `t386` (twelve messages); `t330`, `t309`, `t311` check the new / old words.

## 0.9.135
* **The standard library in categories** (`docs/STDLIB.md`): `#import <core>`, `<number>`, `<text>`, `<files>`, `<system>`, `<time>`, `<data>`, `<crypto>` read only their own part and the parts it needs (`#import <stdlib>` reads all, as before). `std/os.j` is split into `fsdir.j` (`Fs`, `Dir`), `system.j` (`Env`, `Proc`, `Term`), `time.j` (`Time`, `Random`), `num.j` (`Num`); `Path` has its own file. `gen_std.sh` makes one function `push_std_units(mask)`.
* **Fixed:** `Sys::write(...)` and every other function of the struct `Sys` called with its name in front was refused as "not a system register" since 0.9.80; a name that is a function of `Sys` is a call now.
* Tests: `t373_std_categories`, `t374_std_categories2`.

## 0.9.134
* **The syntax tree reads every function body of the corpus: 949 of 949** (before: 535; `docs/design/10-structured-pipeline.md` 8.6): `String`, dynamic arrays, enums, methods, `?`, `switch` with patterns, `try` / `catch`, `throw`, `defer`, `cin`, lambdas and function pointers, slices, tables of several dimensions, pointers to pointers, `Name::function`, `Enum::Member`, the built-in names. The hidden switches `-xast` / `-xastdump` print the result; the generated code is the same. The message for a body that does not fit names the token and the line.
* Every local variable of the tree has a unique number (a block that ends does not reuse it); the dump prints compound assignments (`+=`, `shl=` ...), `for x in things`, members and methods.
* Tests: `t372_ast_more` (the tree of a program with String, array, enum, switch, try, defer and methods, and its output); `t371_ast_probe` follows the new tree.
* **A test that was wrong:** `Counter c;` without `init` has an undefined `n` (the first version of `t372` printed 12 or 15 or a large number): the test uses `Counter c = {0};`.

## 0.9.133
* **Types on the nodes of the syntax tree (A2, begun; `docs/design/10-structured-pipeline.md` 8.5):** every expression node has a type (width code and kind: scalar, pointer, array, struct); `a op b` follows double > float > u64 > int, a comparison is `bool`, a cast has its target, `@x` is a pointer, a call has the type of the function's result. The hidden switch `-xastdump` prints the tree of every body in the subset with the types (the generated code is the same).
* **Fixed in the tree before it mattered:** the statements of a block and the arguments of a call were chained through the field that `for`, `if` and an assignment use for their body, else and target (a statement list overwrote it); the lists have their own field now.
* Test: `t371` checks the printed tree (`test/t371_ast_probe.tree`).

## 0.9.132
* **The syntax tree reads structs (A1c-2, `docs/design/10-structured-pipeline.md` 8.4):** struct values and pointers to structs (`p^.x`; `p.x` inside a method), fields of every scalar, pointer and array type, nested structs, arrays of structs (`b[i].x`), initial lists, `null`, `Name::function(...)` calls. The probe (`-xast`; the generated code is the same) finds **535 of the 945 bodies (57 %)** in the subset (before: 367). Left out on purpose: `switch`, `throw`, `try` (the unwinding of the frame), String and dynamic arrays, methods.
* Test `t371_ast_probe` (a function with a struct is in the subset, one with a String is not).

## 0.9.131
* **The syntax tree reads more (A1c-1, `docs/design/10-structured-pipeline.md` 8.3):** scalars of every width and `double`, pointers (`p[i]`, `p^`, `@x`, `@a[i]`), fixed arrays of one dimension (locals and globals), casts to a scalar type, `++` / `--`, `cout << ...`, calls of functions that return a scalar or a pointer. The probe (`-xast`; the generated code is the same) finds **367 of the 945 function bodies** of the tests, benchmarks and examples in the subset (before: 153); the message of a body that is not says the token where it stopped.
* Test `t371_ast_probe`.

## 0.9.130
* **Floating point loops are vectorised again** (0.9.128 turned them off from a measurement of the poor vector loop of that time, 320 ms against 308 ms scalar, and an explanation that was wrong: the target core is wide, not a little in-order core). With pointers that move on and one branch for each turn the vector loop of `c[i] = a[i] + b[i] * k` is **106 ms against 297 ms scalar** (clang -O2: 86 ms vectorised, 148 ms scalar). `-irdbg 536870912` keeps floating point loops scalar (the test `t369_vectorize` runs both ways). The function has no fused multiply-add (the elements of the vector loop and of the remainder are made the same way); a vector `fmla` is the next step.
* Measured with the arrays benchmark (a copy, an axpy and a sum of 2048 elements): J2K 436 ms (0.9.126) -> 260 ms, clang -O2 130 ms.
* Tests: the suite (397), 400 random programs with four option sets.

## 0.9.129
* **Strength reduction of array addresses in counted loops** (`op_ssr` in `jcmp/jc_opt.j`): the address `base + f * i + c` of an element (the base: the global area, the frame, or a pointer in a plain slot that the loop does not write; `f`: 8 for `a[i]`, the size of the struct for `b[i].x`) is a pointer in a stack cell (a register after the register pass): made in a new block in front of the loop, moved on by `f * step` in a block that the step of the counter falls into. `c[i] = a[i] + b[i] * k` is 9 instructions per element (was 13); measured with the same compiler, `-irclr 1073741824` switches it off: 340 -> 300 ms.
* **The vector loop tests at the bottom** (one branch for each turn, before: two jumps and a compare at the top): an int copy of 2048 elements, 100,000 times: 301 ms scalar, 66 ms vectorised.
* **The benchmark `arrays` was wrong in the first version** (a function called 60,000 times with the same arguments: clang -O2 computed it once, 125 ms); the arguments change in every turn now, the program of C and J2K give the same result.
* Tests: the suite (397), 500 random programs with four option sets.

## 0.9.128
* **Vector loops walk along the arrays with pointers**: the address `base + 8 * i + c` of each access is a pointer kept in a stack cell (the register pass keeps it in a register) that moves on by 32 bytes a turn; the vector body of `copy` is `ldr q / str q / ldr q / str q` and four adds (14 instructions for four elements in `axpy`, before 30). `q[i] = p[i]` over 2048 whole numbers: 278 -> 88 ms.
* **Floating point loops are not vectorised any more (measured)**: on the target (Cortex-A55) two 64-bit lanes are no faster than the scalar instructions: `c[i] = a[i] + b[i] * k` was 308 ms scalar (with `fmadd`) and 320 ms vectorised. `-irdbg 536870912` vectorises them (the test `t369_vectorize` runs both ways). Copies, fills and sums of whole numbers are vectorised.
* **Text rules for the scratch registers x15 and x16** (the registers of the temporaries of the IR lowering): `mov x15, x2` / use of x15 becomes a use of x2, and `add x16, x2, #32` / `mov x2, x16` becomes `add x2, x2, #32` (before, only x0 .. x7 and x10 .. x14, x0).
* Tests: the suite (397), 250 random programs with four option sets.

## 0.9.127
* **A syntax tree per function body, first step (A1a; the owner chose T1 + T2 in parts, `docs/design/10-structured-pipeline.md` 8.1/8.2).** `jcmp/jc_ast.j` reads the body of a function a second time with a small parser into a tree, for a subset (whole numbers, `int` locals and parameters, calls of functions that return a whole number, all binary operators in the order of the language, `if / else`, `while`, `for i in a..b`, `return`, `break`, `continue`), and puts the lexer back: the generated code is the same. Hidden switch `-xast` prints for every function whether its body is in the subset and why not. Measured on the 945 bodies of the tests, benchmarks and examples: 153 (16 %) are in the subset; the main reasons for the rest are parameters that are not whole numbers (356) and statements such as `cout` (324), which the next steps add by the largest reason first.
* Test: the probe is checked in `run_all_tests.sh` (`t371`).

## 0.9.126
* **The vectoriser keeps its variables in registers and does less work per element** (found by a micro benchmark after 0.9.125: the first version was *slower* than the scalar loop, 818 ms against 526 ms): the function was marked with a text line `;NOFMA` that the register pass read as the marker of a naked function, so `i` and `n` stayed in the frame; the mark is now a list of names (`nofma_names` in `jcmp/jc_ir.j`). The limit `n - 1` / `n - 3` is made once in the block in front of the loop (kept in a stack cell, then a register), the broadcast of a double that the loop only reads is made once, the address `base + 8 * i` is made once for all accesses of a turn, and the body is unrolled twice (four elements per turn).
* **Reductions of whole numbers (V3b)**: `s = s + p[i]`, `s = s + p[i] - q[i]`, `s = s + 3`, several accumulators in one loop: two partial sums in a vector, added to the variable when the vector loop ends. Only whole numbers (floating point sums keep their order, as in C without fast-math); a running sum that is also stored (`r[i] = s`) or a product stays scalar.
* New benchmark `tools/bench/arrays.jk` (+ C twin): `c[i] = a[i] + b[i] * k`, an int copy and an int sum, 2048 elements, 60000 times: scalar 480 ms, vectorised 300 ms, clang -O2 126 ms (the rest of the gap: clang unrolls 4 times, uses 32 bit lanes for `int`, and loads with a register offset).
* Tests: `t370_vectorize_sum`.

## 0.9.125
* **The first vectoriser (V3a, `op_vectorize` in `jcmp/jc_opt.j`, design `docs/design/13-vectorizer.md`): innermost counted loops over arrays run two elements per turn.** `for i in 0..n { c[i] = a[i] + b[i] * k; }`, `a[i] = b[i]` (also whole numbers), `c[i] = k`: 16-byte loads and stores and the NEON `+ - * /` on two lanes in front of the original loop, which stays and does the rest (the length is not known at compile time). Only for the accesses that cannot get in each other's way (global or local arrays; two accesses of one array are the same element or at least two elements apart: `a[i + 2] = a[i] + 1.0` is vectorised, `a[i] = a[i - 1] + 1.0` stays scalar); loops with calls, `-d` builds and loops that carry a value in a register (sums) are left alone (reductions are the next step, V3b).
* A function that got a vector loop has no fused multiply-add (the line `;NOFMA` in its text): the elements made by the vector loop and those of the remainder are made the same way, so the result of an element does not depend on its place.
* Tests: `t369_vectorize` (every length 0 .. 11 and 63 against the values of a Python model, the same output with `-noir`, `-d`, `-nofma`).

## 0.9.124
* **Counted loops are recognised on the IR** (`op_counted_loops` in `jcmp/jc_opt.j`; design `docs/design/13-vectorizer.md` V2; no change of the generated code, the vectoriser V3 builds on it): a loop whose header is `load i; load n | number; br i < n` and whose only write of the plain slot `i` is `i = i + step` is described (counter, step, bound as a number or a slot that nothing writes in the loop, number of calls, blocks, innermost or not). Hidden switch `-irdbg 134217728` prints the loops of a program.
* **Decision of the owner (2026-10-14): T1** (a tree per function body) and T2 grown in parts beside it (`docs/design/10-structured-pipeline.md` 8.1: parts A1-A6; the hidden switch `-noast` will compare the two paths).
* Tests: `t368_counted_loops` (and the check of the recogniser in `run_all_tests.sh`).

## 0.9.123
* **Known ranges of whole numbers** (`op_range_run` in `jcmp/jc_opt.j`, design `docs/design/13-vectorizer.md` V0/V1). For every whole number the compiler now keeps "never negative, at most N" (from constants, masks, shifts, `%` and `/` by constants, loop counters, unsigned loads), across blocks and through the frame slots of variables; a counter that grows by small steps is "never negative, no bound". Used for: a shift that moves every bit out (`x >> 63` of a counter: the sign fix of `i % 7` and `i / 10`) is 0, `x & 0xFFFFFFFF` of a value that fits is a copy, and an operation with the neutral number (`x + 0`, `x * 1`, `x & -1`, `x << 0`) is a copy.
* **`ror w`: the rotation of a 32-bit value is one instruction.** `((y >> n) | (y << (32 - n))) & 0xFFFFFFFF` with `y` known to fit in 32 bits (written `y = x & 0xFFFFFFFF` first, in any number of blocks) is `IR_ROTR32` -> `ror32 xD, xA, #n` (the assembler knows the pseudo-instruction `ror32`, checked against llvm-mc `ror w`). `Sha256::rotr` in `std/hash.j` and the benchmark mask first; the rotation is 1 instruction instead of 4 (sha256 1.5x -> 1.0-1.3x of clang -O2).
* The register pass knows `ror` / `ror32` as arithmetic that only writes its first operand.
* Tests: `t367_ranges_rotate`; the tests `t360`..`t366` (SIMD, float32) are now registered in `run_all_tests.sh` (they were not run before).
* Not done yet (design 13): V2/V3, the vectoriser. `loop` is still 3.2x: clang makes 8 lanes of 32 bits; the sign fix of the remainder is gone (the loop is 8 instead of 10 instructions).

## 0.9.122
* **32-bit `float` in the IR.** A function that has `float` values (`fmov sN, wN`, `fadd s0, s0, s1`, `fcvt`, `fcmp s..`, `scvtf s..`, `fcvtzs x, s..`) was left as the parser wrote it; it is lifted and optimised now (new IR operations `IR_F32IN`, `IR_F32OUT`, `IR_FADD32 .. IR_FDIV32`, `IR_FUN32`, `IR_FCVT_DS`, `IR_FCVT_SD`, `IR_I2F32`, `IR_F32TOI`; a float is held in the low 32 bits of a double register vreg, a comparison converts both sides to doubles, which is exact). This includes every function that has an `f32x4`.
* Tests: `t366_float32_ir` (the same output with the default options, `-noir`, `-noregs`, `-noinl`, `-d`).

## 0.9.121
* **SIMD step S4: `v.sum()`, `v.min()`, `v.max()`** on `f64x2`, `i64x2`, `f32x4`, `i32x4` (the methods of the proposal in `docs/syntax-design.md` 59). `sum()` of four lanes is `(x + y) + (z + w)`. They are small methods of `std/simd.j`; the IR inlines them, so a vector that is only summed at the end stays in a register.
* Known: a function that uses `float` (32 bits) values, so every function with an `f32x4` brace initialiser, is still not lifted into the IR (`fcvt s0, d0`); it works, it is not optimised. 32-bit floats in the IR are the next step.
* Tests: `t365_simd_sum_min_max`.

## 0.9.120
* **SIMD step S3: `f64x2::load(a, i)` and `v.store(a, i)`** (the methods `load()` / `store()` of the proposal in `docs/syntax-design.md` 59; the owner said "ทำเลย"): one 16-byte load or store at the element `i` of an array (`f64x2` and `i64x2`: elements of 8 bytes, `f32x4` and `i32x4`: 4 bytes). The array is written as its first element address: `f64x2::load(@a[0], i)`, or a pointer.
* **Vectors live in registers** (new `jcmp/jc_vec.j`, at the end of the IR, before the text is written): a 16-byte stack object that is only loaded and stored as a whole or by lane (and whose address is only used for that) becomes a vector register; the other vectors get one of `v17 .. v29` that the function does not use as a double (graph colouring, copies joined). An object that is alive over a call is stored before and loaded after it. Lane reads and writes (`v.x`, `v.y = 1.0`, `{a, b}`) are `umov` / `ins` / `dup`.
* The loop `acc += d * 2.0` (2*10^8 times) takes 0.19 s (was 1.18 s in 0.9.118); `y[i] = y[i] + x[i] * 0.001` over 10^6 doubles, 200 times: 0.31 s (scalar J2K 0.59 s, clang -O2 0.28 s).
* The assembler knows `umov smov ins dup dN, vN.d[i]` (31 more instructions in the llvm-mc check, `test/asm_check_neon.txt`).
* Tests: `t363_simd_regs` (the same output with the default options, `-noir`, `-noregs`, `-noinl`, `-d`), `t364_simd_load_store`.

## 0.9.119
* **SIMD step S2b: vectors in the IR.** A function that uses the simd operators is lifted and optimised like any other: a vector is a temporary of a new class 2 (`ldr q` / `str q` of 16 bytes, `IR_VOP` for `fadd fsub fmul fdiv add sub mul` on `.2d` / `.4s`, `IR_VDUP`), scratch registers v20..v27. Copies of a simd value are one `ldr q` / `str q` (`j2k_copy16`), and a vector that is stored and loaded again in a block is not read from memory (`op_vfwd`). The loop of 2*10^8 `acc += d * 2.0` went from 1.18 s to 0.67 s.
* The text peepholes do not fold an address into `ldr q` / `str q` unless the offset is a multiple of 16. The assembler knows `mov vD.16b, vN.16b`.
* Tests: `t362_simd_ir` (the same output with the default, `-noir`, `-noregs`, `-noinl`, `-d`).

## 0.9.118
* **SIMD step S2: operators** (owner's "S2" on `docs/syntax-design.md` 59): on `f64x2`, `i64x2`, `f32x4`, `i32x4` the operators `+ - * /` (and `+= -= *= /=`) are one NEON instruction on the whole 16 bytes. The right side can be a number (`v * 2.0`, `2.0 * v`, `m * 3`): it is used for every lane. `/` only for the float types; `i64x2` has no `*` (NEON has none for 64 bits). The two values must be of the same type.
* The assembler knows `fadd fsub fmul fdiv add sub mul` on `vN.2d` / `vN.4s`, `dup vN.T, xN|wN` and `ldr/str qN, [..]`.
* A function that uses these operators is not yet lifted into the IR (it keeps the text path); step S2b puts the vectors into the IR and the register allocator.
* Tests: `t360_simd_ops`, `t361_fail_simd_i64_mul`.

## 0.9.117
* **`#import <simd>`: vector types, step S1** (owner's answer "S1" on `docs/syntax-design.md` 59): `f64x2`, `i64x2`, `f32x4`, `i32x4`, 16 bytes each, lanes `x y z w`, written `f64x2 a = {1.5, 2.5};`. No operators yet (S2).
* **Fixed:** a decimal literal in `{ ... }` for a `float` field was stored as the low half of a double (`F f = {1.5, 2.5};` gave 0 0).
* Tests: `t358_simd_types`, `t359_float_struct_init` (the suite: 382).

## 0.9.116
* **`#pragma read`** (owner's answer 4.1; `docs/syntax-design.md` 70): global data that must not change. `#pragma read` before a declaration (that variable), `#pragma read begin` ... `#pragma read end` (the block), or as the first thing of a file (all its globals); `readonly` is the same word. A direct write is a compile time error; the variable gets pages of its own that the start code makes not writable (`mprotect`), so a write through a pointer stops the program (the segmentation fault text now ends with "or a write to read-only data").
* Tests: `t356_pragma_read` (a write through a pointer: exit 139), `t357_fail_pragma_read` (the suite: 380).

## 0.9.115
* **`raw<type>[values];`** (owner's answer 4.2): bytes of the program as they are written, in a naked function, a register block or a `_.name { }` block: `raw<u32>[0xd503201f];`, `raw<u8>[0x1f, 0x20, 0x03, 0xd5];`, `raw<u16>[...]`, `raw<u64>[...]` (little endian; a value that does not fit the type is an error; a partial last word is padded with zeros). The assembler has a `.word N` directive for it.
* Tests: `t353_raw_words`, `t354_fail_raw_range`, `t355_raw_in_function` (the suite: 378).

## 0.9.114
* **`a[lo..hi]` is a view of a part of an array** (owner's answer 5.1): `Span<int> s = a[1..5];` is written `span(a, 1, 5)` by the lexer (a name directly followed by brackets with `..` at their top level, on one line; `alloc`, `alloc0`, `free`, `grow`, `arr` are left alone). `lo` and `hi` can be any expression.
* **A call of a generic without `<...>` accepts any expression for an argument that does not give a type** (`span(a, i + 1, n - 1)`: only the arguments that bind a type parameter must be simple).
* Tests: `t352_slice_view` (the suite: 375).

## 0.9.113
* **Fused multiply-add** (owner's answer 1, way 1 of `docs/syntax-design.md` 69): `fmul` followed (up to four lines later) by the `fadd` / `fsub` that is the only reader of the product becomes `fmadd` / `fmsub` / `fnmsub`; a load of the other operand that wrote one of the factors is made into the register of the product. No new syntax or function. **`-nofma`** keeps the two roundings (the result of C without contraction: `nbody` gives the same exit code as `clang -ffp-contract=off`). `fmadd fmsub fnmadd fnmsub` in the assembler (four more lines of the llvm-mc check, 120).
* First version fused over a line that wrote one factor (`fmovi d1, 112` in `x * y + 1.0` gave 2.5 for 4.75; a second one loaded the addend into the register of a factor): found by `t249`, `t283`; the lines in between are now a list of known instructions.
* Tests: `t350_fma` (the exact error of a product is not 0), `t351_nofma` (the same source with `-nofma` prints 0); the suite (374), 900 random programs.

## 0.9.112
* **`_.` blocks (owner's answer 5.2):** `_.name { ... }` at the top level is a block with a name: a function without parameters made of low-level statements (like a naked function, with a `ret` at the end), called with `_.name;` from normal code, register blocks and naked functions. `_. { ... }` inside a function is the same as `register { }` (with `in` / `out` / `clobber`). In a `#!library` file `_.start { }` can be the entry.
* Tests: `t348_named_block`, `t349_named_block_raw` (the suite: 372).

## 0.9.111
* **`and` / `orr` / `eor` with a shifted register** (`orr x0, x10, x11, lsl #30`; lsl, lsr, asr, ror) in the assembler, and a register-pass rule that joins `lsl|lsr|asr xS, xA, #n` with the following `orr|eor|and` that reads xS: a rotate written as `(x >> n) | (x << (32 - n))` is two instructions instead of three. The assembler check (llvm-mc) has four more lines (116).
* **A value that goes through a plain frame slot and is read once is passed in a register** (`op_cell_fwd`, second case): `store [slot], r ... d = load [slot]` where the slot has no other load: when `d` or `r` is written in between (an inlined parameter `x` that the body shifts), the value waits in a register that the block does not name (and that does not live after it). The parameter slots of the inlined `rotr` of `sha256` are gone; sha256 100 -> 90 ms.
* About 32-bit numbers (owner's answer 3: option ก): `u32` and `i32` already wrap around at 32 bits at every step (the result is cut after each operation); the work that was left was the code, not the meaning. A real `ror w` is a later step.
* Tests: the suite (370), 500 random programs (`-noinl`, `-d`), bootstrap; the stand-alone assembler (`bin/j2k_asm_j2k`) must be rebuilt after this change (`ship.sh` does).

## 0.9.110
* **A local that is set once to a number is that number everywhere** (`op_const_cells`): `int n = 200;` that nothing changes (one store in the function, of a number made in the same block, in a block that comes before every load) - its loads become the number, so `n * n` and `cmp k, n` fold and the loop bounds are immediate numbers. In `matmul` the three copies of `n` in registers and the loads in the inner loop are gone. A hidden switch: `-irdbg 33554432`.
* Tests: `t347_const_cells` (the suite: 370), 400 random programs (`-noinl`, `-d`), bootstrap.

## 0.9.109
* **A second `Mem::free(p)` says so:** `this variable was already freed by Mem::free and is freed again (it is null now)` (before: the general "used afterwards" text). Case 2 of the ownership proposal in `docs/error-messages-plan.md`; case 4 (a leak) is not needed because owners are freed at the end of their block.
* Tests: `t346_fail_double_free` (the suite: 369).

## 0.9.108
* **`Span<T>`** (`std/collections.j`): a view of a part of an array without copying: `Span<int> s = span<int>(a, 1, 5);` `s.get(i)`, `s.set(i, x)`, `s.len`, `s.sub(lo, hi)`, `s.to_array()`. Checked index (throws `span index out of range`). Chosen by the owner's agreement with `docs/syntax-design.md` 67 (option B).
* **`in` / `out` / `clobber` in a `register { }` block** (68 (a)): `in x1 = expr;` makes the value in the register before the instructions, `out x0 = variable;` stores it after, `clobber x4;` lists the other registers (a warning for a register that the block changes and that is in no list, `-Wregister-block`).
* Tests: `t343_span`, `t344_register_in_out`, `t345_fail_register_clobber` (the suite: 368).

## 0.9.107
* A `mov` / `fmov` into x15, x16 or x17 that nothing reads afterwards is removed (the `fmov x15, d12` pairs that were left in the `vec3` loop after the struct temporaries went into registers).
* Docs: `docs/syntax-design.md` 67 (Span / slice) and 68 (the `_.` block) from `plan-test.md`: comparisons for the owner, nothing locked.
* Tests: the suite (365), 300 random programs (`-noinl`, `-d`), bootstrap.

## 0.9.106
* **A file that `#import "name"` cannot find has a message of its own:** `cannot find the file to import: 'name' (looked for name.j and the same with .jk, next to this file and in the -I folder)` with a `help:`; `#import "name.jk"` (an extension in the quotes: the dot means a folder, so the compiler looked for `name/jk.j`) says so. Before: `cannot read file '.../name/jk.j'`.
* Tests: `t341_fail_import_ext`, `t342_fail_import_missing` (the suite: 365).

## 0.9.105
* **Standard library (`std/collections.j`): sort with a comparator, binary search, Queue, Deque, Heap.** `sort_by<T>(a, less)` (stable merge sort, n log n, one buffer; `less(x, y)` true when x comes first), `lower_bound<T>`, `upper_bound<T>`, `binary_search<T>` (sorted arrays, by `<`), `Queue<T>` (`push pop front len free`), `Deque<T>` (`push_back push_front pop_front pop_back front back get len free`), `Heap<T>` (a min-heap by `<`: `push pop top len free`). Empty ones throw "empty". The type is written (`sort_by<int>(v, ...)`, `Queue<int> q;`) as for every generic.
* Tests: `t340_sort_search_queue` (checked against Python), the suite (363).

## 0.9.104
* **Struct temporaries (`vec3` and the like) live in registers:** the argument and result cells of inlined operator calls (`v + a * 0.5`) were kept in the frame because a value stored to a stack cell and loaded back in the same block could not be named when its register was written in between. `op_cell_fwd` turns such a store into a copy into the register of the load (the load goes away), the dead stores follow, and a second SROA round (only when a cell went away) makes the temporaries plain words that the register pass puts into registers. `vec3`: the loop of the benchmark has no loads or stores of its temporaries any more (85 -> 56 ms, clang -O2: 52).
* The exit call (`svc` with 93 or 94 as the number) reads only x0: x1..x8 were taken as alive in the whole of `main` (dead address computations were kept alive by them).
* A hidden switch turns the new pass off: `-irdbg 16777216`.
* Found on the way: dead-cell removal before the address walk of SROA is wrong (the first version of the order broke the compiler itself; found by the three-stage bootstrap).
* Tests: the suite (362), 600 random programs (`-noinl`, `-d`), bootstrap; `t339_struct_temps` (checked against Python).

## 0.9.103
* **A value that does not change in a loop is made once also when nothing is stored in a variable:** `i * n` in `a[i * n + k]` inside the loop over `k` is computed before the loop, kept in a new stack cell (the register pass puts it into a register when it can) and read in the turns. Moved only when the chain has a multiplication or a division (integer or double) or three instructions.
* Tests: the suite (361), 1,200 random programs.

## 0.9.102
* **Expressions out of loops** (`op_licm_exprs` in `jcmp/jc_opt.j`): a value that is the same in every turn of a loop is computed once before it. The address of `b[i]` inside the loop over `j` (a multiplication and an addition per turn) is made in front of the loop and read from its cell in the turns: the chains that end in a store to a slot or a stack cell (the variables of the program live in cells at this stage and the register pass puts them into registers afterwards), or in a register that is written once in the loop. Only pure instructions (arithmetic, loads of cells that the loop never writes) are moved, so no read or write of memory changes its place; nothing is moved when its values are read by anything else that cannot be given the loaded value. Loops are done innermost first, so an invariant of the inner loop can leave the outer loop too.
* n-body (the inner loop of `advance`): the address of `b[i]` is out of the loop; `matmul`, `mandel`, `qsort` and the others are unchanged in speed.
* `-xtime` also tells how long the pass took and how many instructions it moved (compiling the compiler: 130 ms, 1,226 instructions). A hidden switch turns it off: `-irdbg 8388608`.
* A first version moved the code of the whole function (the loop was found without the test that its header dominates the back edge): found by the suite at once (t285, t281, the fuzzer); a second one gave the moved temporaries the two scratch registers of the lowering and lost the value of one of them: a moved chain keeps the registers it had (none of them is live at the entrance of the loop).
* Tests: the suite (361), 3,300 random programs (also `-noinl`, `-d`, `-irclr 1`), 1,050 garbage programs; `t338_licm_exprs`.

## 0.9.101
* **Fixed a latent bug of the register pass rules:** the search "is this register needed afterwards" took `blr x9` (a call through x9) as a place where x9 is not read: the register of the address was found dead. The address of a call is read now.
* A move into a register that nothing reads afterwards (`mov x25, x0` left by the register pass) is removed.
* Tests: the suite (360), 1,100 random programs with `-noir`, `-noinl`, `-d`, `-irclr 1`, 1,050 garbage programs.

## 0.9.100
* **A use after `Mem::free(p)` is reported** (a warning `-Wmoved`, an error with `-st`) when `p` is a variable that owns its memory and the use follows in the same block: `this variable was freed by Mem::free and is used afterwards (it is null now)`. It was silent before (found only by `-d` at run time, as a null access). A new value stored in `p` clears it. First of the cases of `docs/error-messages-plan.md` (ownership messages): a warning, as proposed there.
* Tests: `t336_fail_use_after_free`, `t337_free_then_new`.

## 0.9.99
* **Constants out of loops is on by default** (`-irlicm` was a hidden switch; `-irclr 1` turns it off): a number that is made in every turn of a loop (`mov x4, 5270498306774157605` for `% 7`) is made once before it when a register is free. 600 random programs and the whole suite were run with it before the change. hashmap -8 %, strings -6 %, sha256 -15 %.
* **Fixed (found by the benchmark `alloc`, 20 % slower since 0.9.97):** the values that the load CSE of 0.9.97 keeps in a cell made everything computed from them "heavy", so the register pass saw extra stores and loads in `Mem::free_raw` (index arithmetic of the size classes). The loaded value is a cell of its own now and the mark is not passed on. `alloc` is back at 125 ms.
* The blocks of 256 KB and more use two small functions (`alloc_direct`, `free_direct`) so that the hot path of `alloc` / `free` is as short as before 0.9.95.
* New baseline of `tools/bench/perf_check.sh` (with the three new benchmarks).

## 0.9.98
* **An array index is one instruction less:** `lsl x0, x8, #3` + `add x0, x28, x0` becomes `add x0, x28, x8, lsl #3` (a register pass rule; the register that gets the value is the same). The assembler (the built-in one and `j2k_asm`) reads `add / sub xD, xN, xM, lsl|lsr|asr #n` (checked against llvm-mc: 112 lines, 0 differences).
* Tests: the suite (358), 550 random programs.

## 0.9.97
* **The arrays of a program are near the base of the globals:** the table of the live blocks of a `-d` build (768 KB) is not a global array any more (it comes from `mmap` in `Mem::debug_on`), so the global arrays of a program start at an offset of a few KB instead of 790 KB. A load or a store at such an address is `ldr x0, [x0, #8616]` (the offset is inside the instruction) instead of an extra `add x0, x0, #795040`: one instruction less for every access to an element of one of the first arrays.
* **A second load of the same element of a global array** (same address, no store and no call in between, inside one chain of blocks) is not made again: `keys[i] != 0 && keys[i] != k` reads once. Only arrays of the program (addresses made from the base of the globals): a read through a pointer is never merged (a device register may change between two reads).
* **A load from a stack cell that held a small number or the address of a frame object** is made again from the number (no memory read) when no register holds it.
* Tests: the suite (358), 700 random programs with the default options, `-noir`, `-noinl`, `-d`. The instruction count of the benchmarks: hashmap -4 %, vec3 -3 %, strings 0.

## 0.9.96
* **The assembler of the compiler is 7 times faster** (0.8 s -> 0.11 s for the compiler itself; the whole compile 4.3 s -> 3.6 s): the text is read once (before: twice), the labels are found through a hash table (before: a linear search through up to 32,768 names for every branch), and a branch to a label that is not defined yet is patched at the end. The bytes it writes are the same: 371 programs (tests, examples, benchmarks) were compared byte by byte with the release before.
* `-xtime` (hidden): the time of each stage of the compiler on the error output. First step of `docs/design/10-structured-pipeline.md` (the plan to go from text to records).
* Measured with it: reading the program 1.0 s, IR 1.5 s, register pass 1.0 s, rest 0.3 s: the next targets.

## 0.9.95
* **Big blocks go back to the system:** a block of 256 KB or more from `Mem::alloc` has pages of its own (`mmap`) and `Mem::free` gives them back (`munmap`) at once; before, the memory stayed in the heap of the program for ever (a program that made 64 MB blocks 400 times ended with the resident size of the biggest, but the address space of the heap only grew). Smaller blocks are as before (chunks of 1 MB, size classes, free lists, joined neighbours). At most 64 such blocks live at a time; more use the old way. Test `t335_big_block`.
* The compiler is a little faster: the live analysis of the register pass works out the jumps and the candidates of each line once (before: at every turn of the loop), and the kept functions of the inliner are found through a hash table. Measured where the time of the compiler goes (compiling jcmp itself, 4.3 s on the phone): reading and checking the program 0.95 s, IR passes 1.3 s, register pass 0.9 s, assembler 0.8 s; inlining itself is 20 ms.
* Tests: the suite (358).

## 0.9.94
* **Constants: more of them become immediates.** The pass that follows known numbers now goes on from a block into the single block that follows it (the body of an inlined function is such a block: the arguments of the call are known inside it) and **folds an operation on two known numbers** (`32 - 6` is `26`). A shift by a known number is `lsl x0, x0, #26` (before: the number was made in a register first).
* **`and` / `orr` / `eor` with a bitmask immediate**: `x & 4294967295`, `x & 255`, `x | 0x8000...` are one instruction (`and x0, x0, #4294967295`); the assembler encodes the bitmask immediates (checked against llvm-mc, 13 more lines in `test/asm_check_core.txt`, 0 differences).
* New benchmarks (with C twins, the same results): `sha256`, `hashmap`, `strings` (J2K / clang -O2: 1.7x, 1.4x, 1.3x; sha256 was 2.0x before this release).
* Tests: the suite (357), 300 random programs.

## 0.9.93
* **`-d`: guard pages.** In a `-d` build every block of `Mem::alloc` (up to 12,000 live blocks) lives in pages of its own and ends exactly where a page that nobody may touch begins. A read or a write **one byte past the end of a block** is a fault at once (before: not found), and a block that was freed is made untouchable, so a **read or a write after free** is a fault at once (before: a read was not found; a write was found later, when the block left the quarantine). A second `free` of the same block says `free of a block that is not alive: freed twice`. The fault message of a `-d` build says what it can be: `null pointer, stack overflow, or a memory block used after free or past its end`, with the address and the place of the code.
* The exit code of a write after free is 139 now (a fault; before 134 at the time the quarantine was checked): `t274` follows.
* Tests: `t333_dbg_overflow`, `t334_dbg_read_after_free`.
* Not changed: programs without `-d` (no cost), blocks of a program with more than one thread (the old checks), more than 12,000 live blocks (the old checks for the rest).

## 0.9.92
* **`import` without `#` is an error** (it was a warning): `import must be written with a # at the start` with the help `write  #import <stdlib>  or  #import "file"`. The tests, examples and sources of the repository are changed. Test `t332_fail_import_without_hash`.
* `bootstrap.sh` gives the frozen seed compiler a copy of each test with the old spelling (`import`), so the comparison of the two compilers goes on.

## 0.9.91
* **A number stored in a pointer is an error** (it was accepted silently): `char^ p = 5;`, `p = 5;`, `return 5;` in a pointer function and `g(5)` for a `char^` parameter say `a number cannot be stored in a pointer (0 or null is fine; write (char^)n if the number is an address)`. Casts (`(char^)4096`), `0` and `null` are not affected. A number that is a variable (`char^ p = a;`) is still accepted: the compiler does not follow pointer types of expressions yet.
* **A text passed to an `int` parameter is an error** (`g("hi")` with `void g(int n)`): the same message as for a variable.
* Tests: `t328`..`t331`.

## 0.9.90
* **A missing `)` or `]` at the end of a line is reported with all the others** (like the missing `;` of 0.9.87): `expected ')' at the end of line 9 (it is missing there)`; the parser goes on as if it was written, and the `;` that follows the same line is not reported a second time. Test `t327_fail_missing_paren_lines`.

## 0.9.89
* **The raw mode `#!library`** (owner's marker, `docs/syntax-design.md` 66.5): a file with this line gets nothing added - no start code, no helpers, no runtime, no `main` needed; the first instruction of the first function is the entry and every function of the file is written. A system call program is 188 bytes. An unknown `#!name` is an error.
* Tests: `t325_bare_library`, `t326_fail_unknown_marker`.

## 0.9.88
* **Leaf functions without a frame:** a function that makes no call and keeps all its variables in caller-saved registers has no prologue and no epilogue any more (no `sub sp`, no save of `x29` / `x30`): `int sq(int a, int b)` is four instructions and `ret`.
* **More variables in registers in a leaf function:** the caller-saved registers cost nothing there, so a variable that is used twice (one store, one load) takes one too (before: only the ones used three times or more).
* Tests: the whole suite (347), 600 random programs with `-noir`, `-noinl`, `-d`.

## 0.9.87
* **More than one error at a time:** a `;` missing at the end of a line no longer stops the compiler at the first one. Every such place is shown (up to 10), the parser goes on as if the `;` was written, and the end says `3 errors generated.` Other errors (a wrong type, an unknown name) still stop at the first, as before.
* **`using ...` must end with `;`** (owner's decision, 2026-10-13): `using stdlib;`, `using std::fs;`, `using cpu::thread;`, `using enum Color;`. Without it: `expected ';' at the end of line N (it is missing there)`. **A program written for 0.9.86 or older that has `using stdlib` without `;` must add it** (tests, examples, docs and tools of the repository are changed).
* Tests: `t323_fail_many_missing_semicolons`, `t324_fail_using_without_semicolon`.

## 0.9.86
* **Leaf functions use more registers:** a function that makes no call that comes back keeps its variables also in the caller-saved registers that its own text does not mention (nothing to save, nothing to restore). The registers for a leaf are taken before `x19 .. x25`.
* **The value of a `void` call is an error:** `int a = f();` where `f` is `void` was accepted and stored garbage; now `this function returns nothing (it is void), so there is no value to store`. The hint `(use a comparison for a bool, or a cast)` of a type mismatch is only written when a bool was wanted.
* Fixed (found while reading the stash): a pinned `x18` no longer gives a negative index into the table of saved registers.
* **`cout` / `cin` need no import and no `using`** (owner's decision, `docs/syntax-design.md` 64): the `[-Wstd]` warning that 0.9.85 still wrote is gone.
* Test `t322_fail_void_value`. The private repository also keeps a copy of the assistant memory (`memory-backup/`, never published).
## 0.9.85
* **A function that can reach its end without a value is an error**: `function 'f' can reach its end without returning a value` (a path of `if` / `else if` without a final `else`, or a `while` with a condition, at the end of the body). The check is careful: `while true`, `switch`, `try`, calls such as `exit`, and a final `return` / `throw` count as ending, so a correct program is never refused (the run-time check of the old message stays for the cases the compiler cannot see; test `t204`).
* **A literal index outside a fixed array is an error at compile time**: `index 5 is out of range: the array has 3 elements (the indexes are 0..2)`, also for each dimension of `m[2][4]`. Variable indexes are still checked by `-d`.
* **Hints:** `int[3] a;` says `help: write  int a[3];`; an unknown name, function or library says `help: did you mean 'count'?` when a known name is one edit away (two for names of five letters or more).
* **The assembler never speaks to the user:** an error of the built-in assembler is now `internal error: the assembler could not read this line of the code written by jcmp: ...  This is a bug in jcmp, not in your program` with the line of the generated text (before: `j2k_asm: error at line N` of a text the user never sees). Hidden flag `-xbadasm` makes the test `t317` possible.
* **`cout` / `cin` need no import** (owner's answer, `docs/syntax-design.md` 64): nothing changes in the compiler.
* `docs/error-messages-plan.md`: the cases still open (a text passed to an `int` parameter, both types in a return mismatch, ownership messages) and the order of work.
* Tests: `t312_fail_missing_return_path`, `t313_fail_const_index`, `t314_fail_const_index_2d`, `t315_return_paths_ok`, `t316_fail_missing_return_if`, `t317_internal_asm_error`, `t318_fail_array_style`, `t319`..`t321` (did you mean).

## 0.9.84
* **Error messages: two mistakes that were not reported well.** A program without `main` now says `error: no main function found in 'file.jk'` with the help line `every program needs void main() or int main()` (before: `j2k_asm: error at line 698 ... parse or I/O error`, a message of the assembler about generated text). A call with the wrong number of arguments is an error: `'add' takes 2 arguments, but 1 was given` (methods are written `Struct::name`); before, the program compiled and the missing value was garbage, and extra values were dropped without a word.
* **A text stored in an int is an error** (`int a = "hi";`, `return "hi";` in an `int` function, `a = "hi";`): `a text cannot be stored in an int (declare the variable as char^ or String)`; before it compiled. **A value returned from a `void` function is an error**: `a void function cannot return a value`. (Pointers and `(int)` casts are not affected.)
* Tests: `t309_fail_text_to_int`, `t310_fail_void_return_value`, `t311_fail_return_text_int`, `t305_fail_no_main`, `t306_fail_too_few_args`, `t307_fail_too_many_args`, `t308_fail_method_args`; the new helper `run_fail_msg NAME "text"` in `run_all_tests.sh` checks the text of the message, not only that the program is rejected.

## 0.9.83
* **A round of bug hunting** with new tools (all in `tools/`, the first three also run in `run_all_tests.sh`): `fuzz.py` makes random programs (integers, doubles, arrays, structs passed and returned by value, calls, loops with break / continue, pointers to variables and array elements, && || !), runs them in a Python interpreter of the same language and compares: 2,200 programs built with 5 sets of options (default, -noir, -noinl, -d, -noregs, -irclr 32768) found **no wrong code**; `garbage.py` cuts and changes the test programs at random and checks that the compiler answers with a message (no crash, no hang): 3,200 broken programs, **0 bad**; `diffcheck.sh` builds every test with 8 sets of options and compares the output with the default build: the only differences are the ones that are meant (the leak report of `-d`, an out-of-range read); `asm_check.py` compares the machine words of the assembler with `llvm-mc` (116 instructions).
* **Found and fixed:** `examples/wc.jk` did not compile since the modules `Sys` and `File` both have `read` and `close` (written `File::read` now). The test suite compiles every program of `examples/` from now on.
* Reserved names: `Bit`, `Cpu`, `Atomic`, `Cache` and `Mem` are structs of the prelude; a program cannot define a struct with one of these names (documented in `docs/LANGUAGE.md`).

## 0.9.82
* **`frame`: a record of registers** (plan step 7): `frame Context { x19..x30; sp; d8..d15; }`; inside naked functions and register blocks `Context::save(x0);` writes the registers of the list to the memory at the address in x0 (`stp` pairs, `sp` through `x17`), `Context::restore(x1);` reads them back; `Context::size` is the size in bytes. A coroutine switch is a naked function of two lines (test `t302_context_switch`: two stacks, a coroutine that is resumed six times, running at user level).
* **`interrupt` functions**: `interrupt void on_timer() { ... }` saves `x0 .. x18` in its frame, runs the body as any function, gives them back and ends with `eret`. No parameters. (The floating point registers are not saved: an interrupt handler must not use doubles.) It cannot run in a program (`eret` is for the kernel), so the test (`t303_interrupt`) looks at the text.
* **`align(N)` before a function** (a power of two, 4 .. 4096): the function starts at an address that is a multiple of N (vector tables want 128 or 2048).
* **`@no_reorder { ... }`** (plan step 8): every instruction of the block is written after a marker, so no pass of the compiler moves, merges or removes it (the function is not lifted and keeps its variables in the frame). Test `t304_no_reorder` (two divisions that the optimiser would make one stay two).
* The assembler: `stp` / `ldp` with an offset and without write back, `[xN]` with offset 0 (checked against llvm-mc: 116 instructions, 0 differences).

## 0.9.81
* **Registers you keep for yourself** (plan step 6): `#reserve x18, x19` (x18 and x19 .. x25) - the compiler never gives them to a variable; `Reg::x18 = p;` and `int q = Reg::x18;` read and write a reserved register (and x18) in normal code; `register { x1 = [x0 + 8]; x1 += 1; ... }` runs the statements of the low level inside a normal function with the bare register names (a function with such a block keeps its variables in the frame; a block that leaves a callee-saved register x19 .. x28 changed and not reserved gets a warning).
* **Pinned variables**: `int n @ x19 = 0;` lives in that register (x18 or x19 .. x25) for the whole function, also across calls (x19 .. x25 are saved and given back by the function; x18 is never used by the compiler). It must be a whole number, pointer, bool, char or enum; its address cannot be taken; two variables cannot share a register in one function; not possible in a program that has try / catch. The register pass honours the pin or the compiler says why it could not.
* Tests: `t296_register_block` (reserved registers, a block with a loop and labels, an optimised function that must not touch x19), `t297_pinned` (pins across calls, x18, a pin in main), and four tests that must be rejected (`t298`-`t301`: a pin to x5, the address of a pinned variable, two pins on one register, `Reg::x5` in normal code).

## 0.9.80
* **`device`: hardware registers as data** (plan step 5): `device Uart @ 0x0900_0000 { data: u32 @ 0x00; flags: u32 @ 0x18 { txfull: 5; mode: 8..10; } }`; then `Uart.data = 'A';` is one store of the size of the register, `Uart.flags` a load (not signed), `Uart.flags.bit(5)` and `Uart.flags.txfull` are bools, `Uart.flags.mode` the bits 8..10 as a number, `Uart.flags.mode = 3;` reads, changes those bits and writes, `Uart.ctrl |= 1;` (`|= &= += -=`) reads, changes, writes. Every access is made where it is written, as often as it is written. Registers of 8, 16, 32 and 64 bits.
* **`Sys::name` in every function**: `int t = Sys::cntvct_el0;` is `mrs`, `Sys::tpidr_el0 = p;` is `msr`, `Sys::daifset = 2;` the PSTATE form. 35 names (lower or upper case) and the general form `s3_0_c12_c0_0`. An unknown name is an error with a hint.
* **Digit separators in numbers**: `0x0900_0000`, `1_000_000`, `0b1010_0101`.
* Tests: `t292_device` (a page mapped at the address of the device: all four sizes, bit fields, read-modify-write, a loop that reads the device each turn), `t293_sys`, `t294_fail_sys_name`, `t295_fail_device_field`.

## 0.9.79
* **`abi`: a calling convention for a trap instruction** (plan step 3): `abi Syscall { number: x8; args: x0..x5; result: x0; via: svc 0; }` declares where the values go; `Syscall::call(64, 1, buf, n)` computes the values like the arguments of any call, moves them into the registers (a cycle of moves is broken with `x17`), writes the instruction `via` (`svc N`, `hvc N`, `smc N`, or `bl function`) and leaves the result in `x0`. The first value is the number when the abi has a `number:`. Error messages for a register that is not one, an unknown field, more values than registers.
* Tests: `t290_abi` (a system call write + getpid, an abi whose moves make a cycle, an abi with a number and a call to a naked function), `t291_fail_abi_too_many`.

## 0.9.78
* **The groups of the CPU** (plan step 4): `Cpu::` (`wait` = wfi, `event` = wfe, `send_event`, `pause` = yield, `nop`, `isb`, `counter` = the system counter with no system call, `frequency`, `id` = the number of the core), `Mem::barrier()` / `barrier_read()` / `barrier_write()` / `barrier_full()` (dmb ish / ishld / ishst, dsb sy), `Cache::` (`clean invalidate clean_invalidate zero clean_code invalidate_code` = dc cvac / ivac / civac / zva / cvau, ic ivau), and `Atomic::` (`load` = ldar, `store` = stlr, `add sub swap cas bit_and bit_or bit_xor`; they return the value the word had before; sequentially consistent). Each one is the instruction where the call is, no call is made. They work in every function (not only naked ones).
* The assembler knows `dc` and `ic` (checked against llvm-mc: 104 instructions, 0 differences).
* Test `t289_cpu_atomic` (every operation on one thread; then four threads add to a counter and take a spin lock made of `cas` / `store` 24,000 and 2,000 times).

## 0.9.77
* **The low level begins: `naked` functions** (`jcmp/jc_low.j`, plan step 1-2 of `docs/syntax-design.md` 63.4). A `naked` function has no prologue, no epilogue, no saves; the body is written with register statements, one statement for one instruction (`Reg::x8 = 64; svc(0); ret;`), with labels, `goto`, `if R == R2 goto`, bit tests, loads and stores of 8 to 64 bits, `Sys::name` (system registers), `Cpu::` (`wait event send_event yield nop isb dsb dmb eret brk inst`) and `Bit::`. Registers are `Reg::x0`.., `Reg::sp`, `Reg::lr`, the roles `Reg::arg0..arg7`, `Reg::ret`, and (inside naked functions) bare `x0`... See `docs/LANGUAGE.md` and `docs/design/09-low-level-examples.md`. The text passes do not touch the body (marker lines `;N`, taken away by the last pass); a naked function is not lifted to the IR and not aligned.
* **The assembler knows much more** (checked against `llvm-mc`, the new test `tools/asm_check.py` with `test/asm_check_basic.txt` and `test/asm_check_core.txt`, 189 instructions, 0 differences): `nop wfi wfe sev sevl yield eret isb dsb dmb` (with the options `sy ish ld st ishld ...`), `br cbz cbnz tbz tbnz`, `mvn tst bic orn eon ands adds subs adc adcs sbc sbcs umulh csel cset`, `ldrh strh ldrsh ldar stlr ldarb stlrb`, the atomics of ARMv8.1 `swp ldadd ldclr ldset ldeor` with the `a l al` forms, `brk hvc smc`, `mrs` / `msr` with 35 system registers by name and the general form `s3_0_c12_c0_0` (also `msr daifset, #3`), `xzr` and `lr` as registers, `fmov dN, #2.0` (a decimal literal that fits in 8 bits).
* **Bugs found by that test:** a number written with `#` (`cmp x0, #5`, `mov x0, #7`) was read as 0 without a message; a missing number was read as 0; hexadecimal (`0x7FF0`) and binary (`0b101`) numbers were not read at all. Now `#`, `0x` and `0b` work and a missing number is an error.
* Error messages for the low level say what is wrong (`this is not a register (the registers are x0 .. x30)`, `this label is used but never defined`).
* Tests: `t286_naked` (a system call stub, arithmetic, a loop with labels, a load, `Bit::popcount`), `t287_fail_naked_label`, `t288_fail_naked_register`, and the encodings test in `run_all_tests.sh`.

## 0.9.76
* **Struct temporaries in the frame become variables** (scalar replacement, `op_sroa` in `jcmp/jc_opt.j`). A pointer that is the frame pointer plus a number (also through copies, sums and stack cells) is followed along each chain of blocks; a load or store through it becomes a direct access at the offset from the frame pointer. A frame object (from the hint line of the register pass) that is not used by its address any more and is only touched by whole 8-byte words, is written to the hint line as plain words: value numbering forwards its stores to its loads, stores that nobody reads are removed, and the register pass can keep each word in a register. Objects whose address is still used (a call argument, `@x`, an index that is a register) are not touched, and the hint of an object that is plain in the hint line but has its address taken is corrected now (the IR passes depended on the hint; the register pass checked the text by itself).
* **Dead stores to stack cells** are removed, **stores forwarded to loads** by a register copy, a second operand that is a known small number is an immediate (the text pass `mov x1, N` / `cmp x0, x1` -> `cmp x0, N` does not ask whether `x1` is needed later: with an immediate there is no such pair).
* **Layout of the blocks:** a block is followed by the block it jumps to (the false side of a branch first) when that is not written yet, the exit block last: after inlining the copies of the callee sit right behind the call.
* **Functions start at addresses that are multiples of 32 bytes** (`.align 32` in the assembler text; the assembler pads with `nop`; `-noalign` switches it off). Measured: the speed of `fib` changed between 68 and 83 ms only by moving the function by a few instructions (16 words in a row, period of 32 bytes); aligned it is always the fast one.
* Hidden switches to find which pass broke something: `-irdbg N` ORs bits in, `-irclr N` clears bits (4 cleaning, 8 value numbering, 128 threading, 4096 copy inline, 8192 inlining, 32768 SROA ...), `-irdbg 2097152` prints the IR before it is written, `-irdbg 262144` says which frame objects were turned into words.
* Test `t285_sroa` (structs passed and returned by value, a pointer to a local given to a function, a local array filled by a function and read with a variable index; checked against Python).
* Measured (best of 7, 0.9.75 -> 0.9.76): **vec3 119 -> 86 ms** (C: 50), fib 70 -> 67, matmul 35 -> 37, nbody 205 -> 199, gcd 308 -> 300, alloc 135 -> 118, mandel 49 -> 50, sieve 78, qsort 160 -> 158, loop 847.

## 0.9.75
* **Inlining of small functions on the IR** (`jcmp/jc_opt.j`, `ir_collect` in `jc_lift.j`; off with `-noinl`, off in `-d` builds because the stack of calls is what the leak report and the fault message walk). Before any function is written, every function with less than 160 lines of code is lifted, gets the usual passes and is kept if it has at most 60 instructions that do something. A call to a kept function is replaced by a copy of its blocks: the block of the call is cut in two, the slots of the callee's frame and its stack cells get new places in the frame of the caller (the hint line for the register pass is extended), its temporaries get new vregs, its returns jump to the second half. The arguments are in `x0..x7` at the call already, the result is in `x0`. After that the caller gets all the passes, so value numbering and dead code work across the old border (the copy of a by-value struct parameter, the result copied out).
* Where: a callee of at most 8 instructions anywhere; one of at most 60 only in a block that is in a loop; not recursive; not into a function that is already bigger than 2,500 instructions; at most 12 calls per caller.
* The lifter accepts `bl f` followed by `add sp, sp, #N` when `f` is a runtime helper (`j2k_...`) or has at most 5 parameters and no array parameter (it is a pop of a pushed value, not arguments on the stack): `main` of a program with struct operators is lifted now.
* The assembler knows `fmovi` and the IR knows `fconst` since 0.9.71; here `IR_NOP`, `IR_FCONST` are copied too.
* Test `t284_inline` (clamp with three returns, a struct passed and returned by value, a callee with a loop, nested calls, a double, a recursive function that must not be inlined; checked against Python).
* Measured (best of 5, 0.9.74 -> 0.9.75): **vec3 196 -> 120 ms** (C: 50), the rest unchanged within the noise: fib 67 -> 68, sieve 71 -> 69, matmul 33 -> 32, mandel 45 -> 45, gcd 308 -> 308, nbody 200 -> 198, qsort 155 -> 159. The price: the compiler has 210,000 lines of text instead of 181,000 and compiles itself in 4.1 s instead of 3.1 s (the compiler itself runs about 10 % faster when built with inlining).

## 0.9.74
* **Small copies of structs are loads and stores** (IR pass `op_copy_inline`): `bl j2k_copy` with a size that is known and at most 128 bytes becomes pairs of `ldr` / `str` (a `vec3` is three pairs, not a call with a loop). It runs for the copy of a by-value parameter, the copy of the result, assignments of structs.
* `std/vector.j`: the operators of `vec2 / vec3 / vec4` build the result in place (`vec3 r; r.x = ...; return r;`) instead of calling `vec3::make` (a call with four stores of arguments). `make` stays for users.
* New benchmarks in `tools/bench` with C twins: `qsort` (1,000,000 numbers, J2K 167 ms / C 157 ms) and `vec3` (operators on `vec3`, 3,000,000 steps: **323 -> 197 ms**, C 59 ms; the rest is the cost of the calls and of the struct temporaries: see the plan in `docs/PLAN.md`). Both are in `perf_check.sh` and `run.sh`.

## 0.9.73
* **Three new rules of the text pass** (`jcmp/jc_regs.j`, `pt_rules`), found by reading the inner loop of the n-body benchmark:
  * `fmov dA, dB` followed by lines that read `dA` (at most 4, no write of `dB`): they read `dB`, the `fmov` goes (the same as for `mov xA, xB` since 0.9.72, now also for doubles);
  * an operation that writes `d0` followed by `fmov dK, d0` (and `d0` not needed afterwards): it writes `dK` directly;
  * `add xD, xS, #N` followed by loads and stores through `[xD, #0]` (up to 10 lines, `xS` not written): they use `[xS, #N]`, the `add` goes. (A load that overwrites `xS` itself is the last use.)
* The inner loop of `nbody` went from 100 to 79 instructions.
* Test `t283_copies` (an array of structs of doubles, pairs, compound assignments on fields; checked against Python).
* Measured (best of 7, 0.9.72 -> 0.9.73): **nbody 287 -> 199 ms (-31 %)**, **mandel 56 -> 47 (-16 %)**, fib 72 -> 70, sieve 79 -> 76, matmul 38 -> 41 (noise), gcd 309 -> 311, loop 845 -> 849, alloc 139 -> 138.

## 0.9.72
* **What is known on the way into a block stays** (value numbering over chains of blocks: a block that only one block leads to goes on with the numbers, the stack cells and the facts of the block before it). Two results: (1) **a check that is already known is not made again** (`while b != 0 { a % b }` does not test `b` against 0 for the division by zero a second time; a branch on a value that an earlier branch decided is a plain jump), (2) values and cells are shared over a whole `if` chain.
* **`mul` + `sub` / `add` of a register is one `msub` / `madd`** when nobody reads the product afterwards (before: only for temporaries). The inner loop of `gcd` is 7 instructions now: `cmp`, `b.eq`, `sdiv`, `msub`, `mov`, `mov`, `b`.
* Labels are written only for blocks that a jump goes to (so the text passes see longer runs of plain code: `mov x0, x19` / `mov x1, x20` / `sdiv x2, x0, x1` / `msub x21, x2, x1, x0` becomes `sdiv x2, x19, x20` / `msub x21, x2, x20, x19`). New text rule: `mov xA, xB` is replaced in up to four following lines that read it.
* `b.cc L1` / `b L2` / `L1:` becomes `b.!cc L2` (also when more labels stand between). Without it `fib` was 23 % slower after the other changes (two jumps in a row).
* Hidden: `-irdbg N` ORs bits into the pass mask (256: no chains, 512: no `msub` of registers, 1024: all labels, 2048: no decided branches) to find which part broke something.
* Tests: `t282_facts` (the check of a divisor that is changed between the check and the use, `if` chains on the same value, collatz, nested comparisons; checked against Python).
* Measured (best of 7, 0.9.71 -> 0.9.72): gcd 374 -> 314 (-16 %), fib 73 -> 70, matmul 35 -> 36, mandel 52 -> 53, nbody 284 -> 283, loop 846 -> 850; the compiler has 167,000 instructions instead of 171,600 and compiles itself in 2.9 s.

## 0.9.71
* **Jump threading on the IR:** the boolean that `&&` and `||` make with `mov x0, 1` / `mov x0, 0` and then test again (`cmp x0, 0` / `b.eq`) is gone: a jump goes straight to the right target when the block before it has just set the register to a constant. Blocks that only jump are skipped, and blocks that nobody reaches are not written. `fib` 88 -> 70 ms (-20 %).
* **Double constants in one instruction:** `fmov dN, #imm` for the constants that the instruction can make (2.0, 0.5, 3.5, 31.0 ... eight bits: sign, four bits of fraction, exponent from -3 to 4). In the assembler it is written `fmovi dN, imm8`. New IR operation `fconst`.
* The register pass sees again that a variable is a double when the load is not right in front of the `fmov` (the IR moved things): `mandel` is back to the speed of the code without the IR.
* The assembler knows `stp` / `ldp` with pre- and post-index; the pass that uses them for the frame is OFF (`-stp`): measured 9 % slower on the Cortex-A55 than `sub sp` + two `str`.
* Tests: `t281_thread` (&&, || with side effects, comparison of doubles, bool variables, a loop with two conditions; double constants that fit in 8 bits and some that do not; checked against Python).
* Measured (best of 5, without the IR -> with): fib 88 -> 70, nbody 366 -> 286, matmul 38 -> 37, mandel 55 -> 55, gcd 368 -> 374, sieve 76 -> 82 (noise), loop 851 -> 847.

## 0.9.70
* **Every function that can be lifted is now written from the IR** (before: only when the IR made it smaller). Fewer instructions overall: the compiler has 171,6xx instead of 179,3xx instructions (-4.3 %); compiling it takes 4.7 s instead of 3.6 s (lifting and writing back the text).
* Jumps: when the true branch of a conditional jump is the next block, the jump is made on the opposite condition and the extra `b` is not written (also for double compares: a not-a-number still goes the right way).
* Value numbering does not replace a load of a frame cell by a copy of a register any more (the register pass could not then use the register of the promoted variable directly: `matmul` was slower).
* Round trips `fmov xN, dM` ... `fmov dK, xN` (a double that waits in a whole number register while the code between writes `dM`) are copies between double registers now.
* Measured (best of 5): `nbody` 363 -> 286 ms (-21 %), `matmul` 46 -> 38, `alloc` 138 -> 134, `gcd` 370 -> 362, `fib` 87, `sieve` 79 -> 75; `mandel` 54 -> 61 (the code of the inner loop is the same; probably the alignment of the jumps), `loop` 843 -> 849 (noise).
* Hidden switches: `-noir` (no IR at all), `-irtrip` (lift and write back, no passes).

## 0.9.69
* **The IR optimiser is on by default** (switch it off with the hidden `-noir`). Every function that can be lifted goes through the IR; the result is written back only when it is smaller (fewer instructions) than the text it came from. What the IR does now:
  * **value numbering inside a block** (`jcmp/jc_opt.j`): the same operation on the same values is one value. A value that a register still holds becomes a copy of that register; a repeated **heavy** value (a multiplication, division, square root, or anything made of them: the address `b + i * 56` of an element of an array of structs) is computed once and read from a new stack cell afterwards (the register pass keeps the cell in a register when it can). Frame cells that are plain 8-byte values are numbered by version, so a store followed by a load is seen. `fmov x, d` + `fmov d, x` round trips are removed. This is the first optimisation that the text passes could not do.
  * copies are read through, small constants become immediates, dead instructions are removed (liveness over the registers), constants that need two or more instructions are moved out of loops (`-irlicm`), an allocator on webs exists (`-irra`, hidden, off).
  * `-irtrip` (lift and write back every function, no passes) is kept for tests.
* Measured (best of 5, this phone): `nbody` 330 -> 257 ms (-22 %); `matmul` 45 -> 41; the other benchmarks and the compiler itself are unchanged within the noise (the compiler compiles itself in 3.9 s instead of 3.2 s: the lifting costs time). The code of the compiler has 178,310 instructions instead of 178,466.
* Test `t280_cse` (an array of structs, indexes that change between uses, a call that writes into the array, doubles; checked against Python).
* Performance test: `tools/bench/perf_check.sh` (also `PERF=1 ./run_all_tests.sh`) with a new baseline.

## 0.9.68
* **IR: the first pass on the IR** (`jcmp/jc_opt.j`, switch `-irlicm`, hidden, off by default): the graph of blocks (predecessors, post order, immediate dominators), the loops (a back edge goes to a block that dominates its source) and **constants out of loops**: a whole number constant that needs two or more instructions (such as the 64-bit multiplier of a division by a constant) and is made inside a loop is stored once in a stack cell by a new block in front of the OUTERMOST loop, and the loop loads the cell (the register pass keeps the cell in a register when one is free). Only the functions that the pass changed are written again from the IR.
* The lowering (IR -> text) is better: `mul` + `add`/`sub` of a temporary is one `madd` / `msub`, the block with the exit of `main` is written last (the hint line for the register pass is in the range of `main` now, so the locals of `main` stay in registers after a round trip), and the frame stays a multiple of 16 bytes when extra stack cells are added (it was possible to get a bus error).
* Test `t279_licm` (nested loops, a call in a loop, an early exit, constants used after the loop, doubles; the numbers were checked with Python with 64-bit wrap-around) and the `-irlicm` runs of seven other tests in `run_all_tests.sh`.
* Measured: on this phone (in-order Cortex-A55) the benchmarks do not get faster from this pass (`loop` 855 ms with and without, a division loop 1.47 s with and without): they wait for the multiply/shift chain, not for the constants. The pass is the base for the next ones (inlining, strength reduction, unrolling), so it stays off until it pays.

## 0.9.67
* **`Bit::` — the instructions of the CPU as names of the language** (the first step of "J2K instead of assembly", `docs/syntax-design.md` section 58): `Bit::clz(x)` (bits 0 in front of the first 1), `Bit::ctz(x)`, `Bit::popcount(x)`, `Bit::rotl(x, k)`, `Bit::rotr(x, k)`, `Bit::bswap(x)`. The compiler puts the instruction at the call (`clz`, `rbit` + `clz`, a count of bits, `ror`, `rev`): no call is made. The assembler knows `clz rbit rev ror popcnt neg` now (`popcnt` is four instructions with a vector register). The IR has the operations too (`clz rbit bswap rotr popcnt`) and lifting and lowering work with them. Test `t278` (19 numbers and 6 rotations, checked against Python). The name of the group (`Bit`) is the default of the first version, the owner may still change it.
* Known limit found on the way: the smallest whole number cannot be written as a literal (`-9223372036854775808` reads as 0): write `-9223372036854775807 - 1`.

## 0.9.66
* **The IR is made from the compiler's own code (`jcmp/jc_lift.j`, design: `docs/design/03-ir.md` section 8):** a function that the compiler wrote as assembler text is read into the IR (blocks, three-address instructions, stack temporaries as fixed cells of the frame, a compare and its jump as one jump) and can be written back (`-irtrip`, hidden; `-irstat` says which functions can be lifted, `-irdump` prints the IR). 64 of 67 functions of a typical program can be lifted (the rest: atomics, 32-bit floats, `defer`, calls with more than 8 arguments). With `-irtrip` the whole test suite and the compiler itself work (the compiler built this way passes all tests). Nothing changes in the normal code yet: this is the base for the passes that follow.
* **Fixed (an old fault found by this work):** a local struct that has a `String` or a dynamic array in it (`P p; p.name = "bob";`) did not start as zeros, so assigning a field freed what the stack held before (a crash when the stack was dirty); it starts as zeros now (also arrays of such structs and structs inside them). Test `t277`.
* `./run_all_tests.sh` uses the newest compiler (`bin/jcmp`) when `JCMP` is not given (it used the frozen assembly compiler, of which only the first tests work); `SEED=1` still runs the old one.
* A `-d` program that stops with a segmentation fault now also says the address, the place of the instruction (`pc`) and the caller.
* Fixed: a negative number in the output of the register pass (`rg_int`).

## 0.9.65
* **The IR (first step, `docs/design/03-ir.md`):** `jcmp/jc_ir.j` holds the intermediate representation of the compiler's second generation of passes: functions as basic blocks of three-address instructions on virtual registers (whole numbers and doubles), explicit `load` / `store` with a width, slots for the frame, calls with their arguments, jumps with conditions; a printer and a checker (every block ends with exactly one jump or return, every operand exists, double and whole-number operations get the right class). A hidden `jcmp -irtest` builds two functions, checks and prints them (test `t276`). Nothing in the generated code changes yet.

## 0.9.64
* **`-d` finds more:** a block that is **freed twice** (or a pointer that did not come from `alloc`) stops the program with a stack trace; a block that is **written after it was freed** is found (freed blocks are filled with 221 and kept for a while: a changed byte is reported when the block leaves); the **leak report names the function** that made each block (`leak: 64 bytes made in leak`). Tests `t273`, `t274`.
* **`-Wmoved` also for `p[i]` and `p^` after `move(p)`** (before: only when the variable itself was read). Test `t272` (with `-st`).
* **Pools reuse the pieces that were given back:** `free[b]` of a piece in the middle makes its room available to the next `alloc[pool[n] >> int^ q]` (first fit). Test `t275`.
* **Fixed (found by the new checks):** `ks.push(Node::Name("x"))` — a struct that frees itself, made by a call and pushed into an array — copied the struct and then freed the temporary, so the array held freed memory; it moves now. An array of structs that free themselves (`Node[] ks`) frees every element when it is freed (before: only the array, the elements' memory leaked); the copy that a data enum makes of such an array moves the elements.
* A `-d` program checks the size of `free[p = n]` with a separate call (the variable is made null as before).

## 0.9.63
* **The bracket forms of memory** (chosen by the owner, `docs/syntax-design.md` 57): `alloc[int^ p = 32];` (a pointer declaration with its number of elements), `alloc0[int^ p = 32];` (zeroed), `free[p];` / `free[p = 32];`, `grow[p = 64];` (a bigger block with the old content), `arr[n]` (= `arr(n)`), and **pools**: `alloc[int^ pool = 32];` then `alloc[pool[12] >> int^ a];` takes 12 elements from the pool into `a`; `free[a];` gives back only that piece; `free[pool];` everything. The forms with parentheses stay. Test `t271`.
* `Mem::alloc0`, `Mem::take`, `Mem::grow_slot`, `Mem::free_checked` in the prelude.

## 0.9.62
* **The mascot:** the shadow of the Moon on the Earth is the shape of the letter J when the Moon is the letter J (before: a round spot). The ray to the Sun is followed to the plane of the flat letter and the place where it meets the plane is looked up in the letter; a full Moon still gives a round shadow.

## 0.9.61
* **A new heap allocator** (`std/prelude.j`, `struct Mem`; design: `docs/design/04-memory.md`, option M2): blocks of up to 2048 bytes have **size classes** (a list of free blocks for each size: `alloc` and `free` take a few instructions); bigger blocks are on one list ordered by address, a block is **split** when the rest is at least 64 bytes and a freed block is **joined** with the free blocks next to it. Before: one list, first fit, no splitting and no joining (a program with many frees got slower and slower). A benchmark of 3 million mixed `alloc` / `free` (`tools/bench/alloc.jk`): 0.18 s -> 0.11 s; with many live blocks of different sizes the difference is much bigger.
* **No lock before the first thread:** the heap is locked only after `Thread::create` or a `#multithread` loop started a thread (the lock was the biggest part of the cost of one `alloc`).
* **A literal index is an offset:** `p[1]`, `a[3]` is one load with a constant offset (`ldr x0, [x0, #8]`); before it was calculated at run time.
* Tests: `t270` (40000 random allocations of all sizes, every block checked for overlap); `t140` asks for the same size class when it expects the block to be reused.

## 0.9.60
* **`Mem::copy` and `Mem::set` work 8 bytes at a time** (they worked one byte at a time): copies and fills of `String`, `T[]` and everything built on them are faster. Test `t269` (every length 0..40 from every alignment).

## 0.9.59
* **Calls with two to four arguments do not use the stack for the arguments** when the code that makes them is plain (no call, no stack): the earlier values wait in `x10`..`x14` (or `x5`..`x7`) and are moved into `x0`, `x1`, ... just before the call, and the optimiser then often leaves only the moves that are needed (`mov x1, x22 / mov x0, x20 / bl gcd`). Before: every argument was pushed and loaded again. Test `t268`.
* **Functions that own memory** (a `String`, `alloc`, a struct that frees itself) can now keep their other locals in registers too; only a function with `defer` (and a program with `try`/`catch`) is left alone.
* The search for "this register is not needed afterwards" knows that a call does not read `x8`..`x15` and does not touch `d8`..`d15`.

## 0.9.58
* **A real register allocator** (`jcmp/jc_regs.j`): a live variable analysis (a backward dataflow over the lines and jumps of a function), the live interval of every local, and a **linear scan** over the intervals. Locals whose lives do not meet share a register, so more than seven locals can live in registers over a function; if the registers are all taken, the local that is used least stays in memory. Whole numbers and pointers go to `x19`..`x25`, doubles to `d8`..`d15`.
* **Doubles stay in floating point registers:** the left operand of a float operation waits in `d16`, `d17`, ... (before: in an x register or on the stack), the operands of an operation go to `d0` and `d1` without a trip through x0, and the optimiser (value numbering of registers, copy forwarding, removing moves that nothing reads, `ldr dN, [..]` / `str dN, [..]` instead of a load and a move) removes most of the moves between x and d registers. The assembler knows `fmov dN, dM`, `ldr dN, [..]` and `str dN, [..]`.
* **More plain code is kept in registers:** the left operand also waits in a register when the right operand is a path through a struct (`b[j].x`, `p.pos.y`) and a call of `__fsqrt` / `__ffloor` / `__fceil` / `__ftrunc`; `add xA, xA, #N` before a load or store goes into the address (`ldr x0, [x0, #8]`); a dead `add x0, x29, #N` in front of a load is not an address-taken slot any more.
* **Fixed (an old gap):** `b.len` on an array parameter of structs (`void f(Body b[])`) did not compile ("this value has no fields").
* **The mascot:** when the Moon is the letter J its shadow on the Earth is a J too (before: a circle).
* Measured (ms, `clang -O2` in brackets): `fib(35)` 87 -> 72 (61), a sieve of 5 million 60 (76), a 200 x 200 matrix product 36 -> 30 (28), a Mandelbrot set 72 -> 49 (47), n-body 593 -> 321 (115), gcd 339 -> 347 (262). Test `t267` (n-body on an array of structs, checked against a C program).

## 0.9.57
* **Faster floats and array access:** a float literal is worked out when the program is compiled (`0.5` is one `mov` of its bits, before: five instructions at run time; checked against Python bit by bit, test `t266`). The left operand of an operator waits in a register also when the right operand is an array element, a float, a cast or a group of plain things (before: pushed on the stack). The base address of a global or local array with a big offset is added after the index (no push). 
* **Register pass, second step:** the old value of a register is saved in the frame slot of the variable that moved (no change of `sp`); a variable needs 4 weighted uses (was 6); the moves that are left are removed more often (a copied register is used directly: `mov x1, x20 / mul x0, x0, x1` becomes `mul x0, x0, x20`, `cmp` on registers), and the search for "not needed afterwards" follows up to 400 lines.
* Measured (ms, `clang -O2` in brackets): `fib(35)` 99 -> 87 (65), 300 million `s = s + i % 7` 767 -> 747 (200), a sieve of 5 million 98 -> 60 (75), a 200 x 200 matrix product 62 -> 36 (30).

## 0.9.56
* **Faster code, third step: a register pass** (`jcmp/jc_regs.j`, `-noregs` switches it off). In a function, the whole-number locals that are used most (weighted by how deep in loops they are used, at most seven) live in the registers `x19`..`x25` instead of the stack frame; the registers are saved at the start and given back at the end of the function. The compiler tells the pass which locals are plain 8-byte values; a local whose address is taken, a function with owners/`defer` (the cleanup chain), with a `#multithread` loop, and every program with `try`/`catch` are left alone. A second part removes the moves that are left (`mov x0, x19 / mov x10, x0` becomes `mov x10, x19`, `cmp` on registers, `add x20, x10, x0`) after finding out that the register is not needed afterwards by following the code. Test `t265`.
* Measured (ms, `clang -O2` in brackets): `fib(35)` 105 -> 99 (65), 300 million `s = s + i % 7` 881 -> 767 (200), a sieve of 5 million 143 -> 98 (79), a 200 x 200 matrix product 85 -> 62 (28).

## 0.9.55
* **`jcmp -space` is the pixel picture now** (colour, half-block pixels). The compiler looks at the terminal (`COLORTERM=truecolor` or `24bit`) and, if there is no 24-bit colour, shows the ASCII picture instead. `jcmp -space ascii` forces the characters, `jcmp -space pxg` gives white, grey and black pixels; a speed number can follow.
* The J is a little smaller and has the colour of the Moon; the orbit line is gone: only the Earth and the Moon (and the stars) are left.

## 0.9.54
* **The mascot in pixels (two ways to compare):** `jcmp -space px` draws it with half-block pixels in colour (blue sea, green land, white clouds, warm city lights, a gold J, a blue air glow); `jcmp -space pxg` draws the same picture in white, grey and black. Plain `jcmp -space` is still the ASCII picture. A speed number can follow (`jcmp -space px 600`). Needs a terminal with 24-bit colour.

## 0.9.53
* **The mascot's Moon follows its phase:** at a full Moon there is no letter; as the Moon wanes or waxes the J fades in on the surface, and from a half Moon down to a thin crescent the Moon itself becomes the letter J (drawn flat, facing us, glowing).

## 0.9.52
* **`examples/solar.jk` is in colour now** and no longer dull: every ball is lit by the sun and has its own surface (continents, clouds and ice caps on the Earth, bands and the red spot on Jupiter, the rusty Mars, the grey Mercury and Moon, the cream clouds of Venus), the rings of Saturn go behind and in front of the ball, a sun with a limb and a corona, faint orbits, an asteroid belt, twinkling coloured stars, glow and vignette. It uses `Screen` (like the black hole) and takes the size of the terminal. Test `t242`.
* **The mascot (`jcmp -space`)** has an air glow round the lit edge of the Earth and the lights of the cities on its night side.

## 0.9.51
* **`str(x)`** makes a `String` from a number, a character, a `bool` or another String: `str(42)`, `str(-7)`, `str(2.5)`, `str(1.5e20)` (`1.5e+20`), `str('x')`, `str(true)`, an unsigned `u64` up to 18446744073709551615. Floating point numbers print with up to 15 significant digits and no zeros at the end. Test `t262`.
* **Any number of array parameters, in any place:** `int dot(int a[], int b[])`, `void scale(int a[], int k, int out[])` (before, one array parameter and it had to be the last). Methods too. Test `t263`.
* **`move(ps[i])` on an element of an array** of a struct that frees itself: the element goes to a new owner and the array slot is emptied (`Person t = move(ps[1]);`). Test `t264`.
* **Fixed:** a local array of structs that free themselves now starts as zeros, so `ps[0] = make(...)` no longer frees garbage.

## 0.9.50.1
* **Docs:** the status tables of `README.md` and `README.th.md` (they still said that dynamic arrays, `cin` and threads were missing) and a section "The standard library at a glance" in `docs/LANGUAGE.md` now describe what the language and the libraries really have.

## 0.9.50
* **Two functions with the same name are an error** ("this function is defined twice"). Before, the second one silently replaced the first, which hid a fault in 0.9.49 (a new library function got the name of an old one and three tests failed). Test `t261`.
* Faster `x += e`, `x -= e`, ... on a plain variable: the peephole pass makes the six lines into four (300 million `s = s + i % 7`: 1030 -> 882 ms).

## 0.9.49
* **Strings can be ordered:** `a < b`, `a > b`, `a <= b`, `a >= b` on a `String`, a text, or a mix (by the codes of the bytes, like `strcmp`; a capital letter comes before a small one, `"é"` after `"z"`). Sorting a `String[]` with `<` works (test `t256`).
* **Fixed:** `@name` where `name` is a variable bound in a `switch` to a struct that frees itself (`Result::Ok(doc)`) is now the pointer to that struct (before, the address of the binding itself); so `total(@doc, ...)` works.
* The trace of a panic shows library names without the leading underscores (`Arr::nullerr`, was `::Arr::nullerr`).
* **Four larger test programs** whose output was checked against Python (8 queens and the longest Collatz chain, word counts and text functions, numerical integration and a determinant, generics with JSON and exceptions): `t257` - `t260`.

## 0.9.48
* **Fixed (an old fault):** a loop `for i in lo..hi` with a **variable** at the start of the range did not compile ("this value has no fields"), only a number worked (`for i in 0..hi`). `for i in lo..hi`, `for i in lo + 1..hi + 1`, `for i in 0 - r..r` work now (test `t255`).
* **gfx, drawing and effects on `Screen`:** `line` (Bresenham), `rect`, `fill_rect`, `circle`, `fill_circle`, `blend` (mix a colour into a dot), `gradient_v`; effects on the whole picture: `vignette`, `scanlines`, `brightness`, `invert`; `lit()` counts the dots that are not black. Checked by counting (a diagonal of 20 dots, a rectangle of 24, a filled circle of radius 5 of 81 dots, a circle border of 28).

## 0.9.47
* **More of the math library** (parts chosen as before with `using math::NAME;`; `using math;` takes all): **`quat`** (rotations as quaternions: `quat::from_axis_angle`, the product `q * r` (turn by `r`, then by `q`), `conj`, `normalize`, `rotate(vec3)`, `slerp`), **`complex`** (`cplx`: `+ - * /`, `-z`, `==`, `conj`, `abs`, `arg`, `exp`, `powi`, `from_polar`) and **`stats`** (`Stats::sum mean min max variance stddev median` on a `double[]`). Checked by hand: a quarter turn about y turns (1, 0, 0) into (0, 0, -1), (1 + 2i)(3 - i) = 5 + 5i, e^(i pi) = -1, (1 + i)^4 = -4.

## 0.9.46
* **Fixed (an old fault):** an index that contains `.len`, like `a[a.len - 1]`, gave the address of the element instead of the element (for a String, a `T[]`, and a fixed array): the `len` inside the index left the "finished" mark of the outer lvalue on. `v[v.len - 1]`, `s[s.len - 1]` and `m[m.len - 1][2]` work now (test `t252`).
* **Standard library:** `Path` (`join name parent ext stem`), `Hex` (`encode`, `decode` as a `Result`) and `Base64` (`encode`, `decode` as a `Result`), checked against `base64` and `xxd`.
* A clearer message when `self` is used in a method that does not have it as its first parameter (`int name(self) { ... }`).

## 0.9.45
* **Faster code, second step:** a **peephole pass** (`jcmp/jc_peep.j`, `-nopeep` switches it off) shortens the assembler text of the whole program: a store followed by a load of the same place, a push that is popped at once, `mov x1, N` + `add/sub/cmp`, a comparison used as a condition (`cmp` + one conditional branch instead of making 0 or 1 and testing it), a jump to the next line, a store with its address worked out first, and the left operand that waited in a register. **Loops** have a better shape: the condition at the bottom (`for i in a..b` and the C form), one jump a turn instead of three. **Array elements**: the index is worked out first and the base address is added after (no push), a power-of-two element size is a shift; the **address of the target of an assignment** waits in a register when the right side has no call. A division by a literal does not load the divisor any more.
* Measured (ms, best of 3; `clang -O2` in brackets): `fib(35)` 211 -> 93 (71), 300 million `s = s + i % 7` 1554 -> 1030 (232), a sieve of 5 million 276 -> 144 (72), a 200 x 200 matrix product 130 -> 80 (28).

## 0.9.44
* **Faster code (first step of the speed work):** the left operand of a binary operator no longer goes through the stack when the right operand is made of plain numbers and variables: it waits in a register (`x10`..`x14`), and a right operand that is one number or one variable is loaded straight into `x1`; a variable is read with one instruction (`ldr x0, [x29, #N]`, not an address and a load); assigning to a plain variable no longer pushes its address; `/` and `%` by a whole-number literal use a multiplication (`smulh`) and a shift instead of the slow `sdiv` (checked against `sdiv` on 164 000 values, edges of 64 bits included). New instructions in the assembler: `msub`, `madd`, `smulh`, and `lsl/lsr/asr` with a number.
* Measured against `clang` on this phone (best of 3, ms): `fib(35)` 211 -> 136, a loop of 300 million `s = s + i % 7` 1554 -> 1105, a sieve of 5 million 276 -> 186, a 200 x 200 matrix product 130 -> 89 (`clang -O2`: 71, 232, 72, 28). The programs are in `tools/bench` (private).
* The results are the same as before: a test with many forms of expressions (precedence, calls with side effects in operands, floats, chars, arrays) must give the same output as the old compiler.

## 0.9.43
* **A call can go on after a value in parentheses:** `(a + b).dot(c)`, `(s + t).len`, `(u * 2.0).z`, `(a + b).length()`.
* **`-v` on a struct** calls its `operator ... neg(self)`; `vec2/3/4` have it.
* **`2.0 * v`** is the same as `v.mul(2.0)` (a number on the left of `*` and a struct on the right); a number on the left of `/` is still an error that says so.
* Docs: a section on operator methods and the math libraries in `docs/LANGUAGE.md`.

## 0.9.42
* **The mascot is real ASCII art:** the shading uses a rich ramp of 66 different characters, letters and signs, from light to dense (`.'`^",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$`), not only a few dots; and the **edges** of the Earth and the Moon are drawn with characters that follow the line, chosen by which quarters of the cell the shape covers: the right limb of a ball is `)`, the left `(`, the top `"`, the bottom `_`, the diagonals `/` and `\`.

## 0.9.41
* **The mascot is smoother and more real:** four rays for every character (2 x 2, averaged) so that the edges of the Earth and the Moon and the steps of light are smooth; a **dither** (a fine 4 x 4 pattern of Bayer) chooses between the two nearest characters of the ramp, so a slow change of light looks like a smooth gradient; the edge between day and night is soft; the Earth has **lands with shores, clouds that drift faster than the ground**, ice at the poles and a bright spot of the Sun on the sea; the Moon has **craters** (a darker floor, a lighter rim) besides its dark seas.

## 0.9.40
* **The mascot (`jcmp -space`) redone as asked:** the **Earth** in the middle (a ball with sea, lands, ice at the poles, turning on its axis), the **Moon** going round it and **the letter J on the Moon**: the J is raised from the Moon's surface and turns with the Moon about the Moon's own axis (a turn in 40 s of the film; there is a J on the front and one on the back so that one of them is always turned to us; the J glows a little, like a logo, even where the Sun does not light the Moon). The shading is the ramp ` .:-=+*#%@` by the angle between the surface and a **fixed Sun** (from the left and the front); what the Sun does not light is left black, so the Moon shows its phases.
* **Slower:** the default is `1 s = 30 min` of real time (x1800; before x7200); the Earth turns in 48 s, the Moon goes through its phases in 23.6 minutes; `jcmp -space N` sets N. The Moon starts where the **real Moon is now** (its phase is computed from the clock of the computer: a new moon was on 2000-01-06 18:14 UTC, the month is 29.530588853 days) and the **real UTC clock and date** are shown, next to how much time has passed in the film.
* **The lines under the picture:** the real time, the time scale (`1 s = 30.0 min (x1800)`, the turn of the Earth, the cycle of the Moon in the film), the phase of the Moon and the real light times (Sun 8 min 19 s, Moon 1.28 s), and the **scale** of the picture (`1 row = 855 km`; the Moon is drawn at 1.70 Earth radii with the radius 0.62, real 60 and 0.27, so that it fits and the J can be read).
* **Sizes:** 50 x 20 characters, or finer in a bigger terminal: 60 x 24 (62 columns, 29 rows), 76 x 30 (78 x 35), 100 x 40 (104 x 46); zoom the terminal out (smaller letters) to get a bigger picture.

## 0.9.39
* **Finer picture where the terminal is big enough:** the mascot is 50 x 20 characters in a small terminal, **60 x 24** from 62 columns and 28 rows, and **76 x 30** from 78 columns and 34 rows. The globe and the Moon are the same size compared with the picture, but every character is smaller, so there is more detail.
* **The Moon is made of digits** (`1 7 3 5 2 9 6 0 8 @`), the Earth of letters, so that they can be told at a glance, and the word `MOON` stands under the Moon. **What the Sun does not light is left black**: a crescent or a half moon shows only the lit part (no earthshine and no rim on the dark side).

## 0.9.38
* **The Earth is fuller and the Moon easy to see:** the shading uses a ramp of letters only (`. : - + c v u n x z X Y U J C L Q 0 O Z m w q p d b k h a o M W & 8 % B @ $ #`, no thin punctuation) and a curve that lifts the middle tones; the sea and its lines are brighter, the grey of the characters starts higher, there is more light on the night side. The Moon is bigger (radius 0.40 of the Earth's, a little more than real 0.27, still not to scale), brighter, its dark side shows the light of the Earth, and its edge is lined so that the whole disc can be seen even as a crescent.
* The lines under the picture are shorter (`x7200  Earth 11.9 s  Moon 5.4 min`, `UTC 14:29:23  +27.7 min`).

## 0.9.37
* **The mascot (`jcmp -space`) is the Earth with the Moon, with real times.** The ring is gone. The Earth (with the letter J raised on it, in black, white and grey) **turns on its axis** (west to east, the axis leans its real 23.44 degrees) and **goes round the Sun**, and the **Moon** goes round the Earth (its orbit leans 5.14 degrees) and **shows its phases**: new, crescent, half (quarter), gibbous, full, waxing or waning, from the real angle between the Sun and the Moon. When the J turns to the far side only the plain globe is seen; on the night side it is dark. The Moon and the Earth throw shadows on each other (eclipses). The times are real: one turn of the Earth 23.93 h (86 164.1 s), one turn of the Moon 27.32 days, one year 365.26 days; the film is `N` times faster than real time (`jcmp -space N`, default 7200: the Earth turns in 12 s, the Moon in 5.4 min) and the lines under the picture say the times for this speed, the Earth time (UTC clock and how much time has passed in the film), the phase of the Moon and the real **time the light needs**: Sun to Earth 499 s (8 min 19 s, from 149 597 870.7 km / 299 792.458 km/s), Moon to Earth 1.28 s; the Sun that lights the Earth is where it was 499 s before. The Moon is drawn nearer and a little bigger than real (not to scale) so that it fits.

## 0.9.36
* **The mascot is a globe with the letter J on it** (the J as the world), in **black, white and grey only** (no more orange): a ball shaded with the sun on one side and a grey night on the other, with fine lines of latitude and longitude, a white letter J raised from the surface (the shading bends at the edges of the letter so that it stands out), a glow at the rim, a spot of reflected light on the sea. The sun goes slowly round the globe so the light and the shadow move over the J; the globe rocks a little so that the letter seems to be on its surface. A thin ring leans round it like the axis of the Earth (23.44 degrees); its gas goes round with Kepler's law and the real mass of the Earth (GM = 398 600 km^3/s^2, 1.2415e-3 rad/s at the surface, 1500 times faster in the film), the globe throws its shadow on the ring and the ring on the globe, and the sun glints on it here and there in whitish grey. Without a 24-bit colour terminal it is plain characters.
* Less clutter than 0.9.35: no belts, small moons or ringlets.

## 0.9.35
* **Fixed (serious, my mistake in the release of 0.9.34):** the source of 0.9.34 on GitHub had a half-written change in `jcmp/jc_logo.j` and could not be compiled (the released binary `jcmp` was fine). This release has a source that builds (`./bootstrap.sh` passes) and the finished change: 
* **The mascot, more detail:** the J hangs lower, so that the plane of the rings crosses its upper part and its tail shows below; finer shading with a long ramp of 68 characters; belts of clouds on the planet that turn with it; fine ringlets in the rings, the thin F ring and the Encke gap; three small moons that run beside the rings at their real distances (Prometheus, Pandora, Janus) with Kepler speeds; **shadows are grey** (the night side, the shadow of the rings and of the planet), and the sun **glints on the rings** here and there in whitish grey.

## 0.9.34
* **The mascot is 50 x 20 characters** and shows **Earth time** under the picture: the clock of the computer now (UTC, `HH:MM:SS`) and how many hours have passed on the planet in the film (`film = 12.4 h`, from the speed N).

## 0.9.33
* **The mascot looks like a lit planet:** with a 24-bit colour terminal (`COLORTERM=truecolor`, as in Termux) the characters get colours: the J has a day side (warm gold), a night side (dark blue) with a soft edge between, a bluish glow at its rim where the atmosphere is seen edge-on, and a small bright spot of reflected light; the rings are sand-coloured (the C ring greyer); the shadow cast by the rings and by the planet is bluish dark; stars are pale blue-white. Without that variable it stays plain characters.
* **`jcmp -space N`:** N is how many times faster than real time the planet and rings go (default 1500; 4000 was too fast to read the letter). The line under the picture says it. Saturn's real ring radii, Kepler speeds from its real mass, its 10.56 hour day and its 26.73 degree tilt are used at any speed.

## 0.9.32
* **The mascot with real physics (Saturn's numbers):** the rings have their real radii (C ring 74 658 - 92 000 km, B ring to 117 580 km, the Cassini division to 122 170 km, A ring to 136 775 km, the planet 60 268 km) and their gas goes round with Kepler's law and Saturn's real mass (GM = 3.793e7 km^3/s^2: omega = 4.16e-4 rad/s at one planet radius, falling with radius^-1.5). The planet turns once in its real 10.56 hours, and its axis leans its real 26.73 degrees. The film runs 4000 times faster than real time (written under the picture). The view does not swing any more: all the motion is real motion, so the J turns as the planet does.
* Array lists (`double a[3] = {1.0, 2.0, 3.0};`) are confirmed by the owner (docs/syntax-design.md section 56).

## 0.9.31
* **The mascot is Saturn:** the solid J is the planet; it has rings like Saturn's (a faint inner ring, a bright broad ring, a dark gap, an outer ring) whose gas goes round by Kepler's law (the inner part is faster, in clumps that move from left to right in front). Light and shadow: the J is lit from above, the rings throw a shadow on the lower part of the J, and the J throws its shadow on the rings. The view swings and breathes with two slow motions that do not repeat together, so the turning no longer looks stiff.

## 0.9.30
* **The mascot (`jcmp -space`) in 3D (isometric):** a solid J (an extruded letter) seen from above at the isometric angle, lit from above so that its top faces, front and sides get different characters (`.:-=+*#%@`), with four small balls that go round it on dotted ellipses by Kepler's laws (the J is at a focus; a ball is faster near the J; period ~ radius^1.5). The view turns a little to and fro, which makes the picture look solid; the J and the balls hide the orbit dots behind them. Every character is one ray into the scene (ray marching with distance functions), written in J2K inside the compiler.
## 0.9.29
* **The mascot (`jcmp -space`) like Saturn:** the J is the planet and four thin rings (with a gap, like Saturn's) lean 45 degrees round it, a little slanted. The ring stays where it is; its gas goes round, the inner rings faster, as clumps of brighter characters. A cleaner, slimmer J with a hook that curls up. Under the picture: `created by J2k-studio`, and how to stop.

## 0.9.28
* **The mascot:** `jcmp -space` shows the J2K logo in ASCII style until you press Ctrl-C or Enter: a J drawn with shaded characters (`.:-=+*#%@`) and a soft halo, a ring that leans 45 degrees and turns round it (in front of and behind the letter), twinkling stars, 24 frames a second. It reads the size of the terminal first and shows a small picture (48 x 18 characters) in the middle. It is written in J2K inside the compiler without any library (`jcmp/jc_logo.j`). `-spcae` and `-speac` do the same; it is not listed in `-help`. Plain characters: it works in any terminal (at least 50 x 20).
## 0.9.27
* **Example `examples/logo.jk`:** the J2K logo: a glowing J, a ring tilted 45 degrees that turns around it (with two beads running on it), twinkling stars, 24 frames a second (paced by the clock). Small and of a fixed size (64 x 40 dots, about 25 KB of memory).
* `Screen.add(x, y, r, g, b)` adds light to a dot.

## 0.9.26
* **Array lists:** `double dist[3] = {12.0, 18.0, 25.0};`, `int primes[] = {2, 3, 5};` (size counted), also for global arrays (constants). Values not given are zero. One dimension, not structs yet (docs/syntax-design.md section 56, waiting for the owner's confirmation of the form).
* **Colour in gfx:** `using gfx::screen;` gives `Screen::make(w, h)`: a picture of rgb dots (`set`, `set_packed`, `get`, `clear`, `glow` = bloom, `frame`, `show`, `begin`, `end`); two dots in each character cell with 24-bit colour codes. `Screen::rgb(r, g, b)` packs a colour. `using gfx::canvas;` still gives the character `Canvas`; `using gfx;` gives both.
* **Terminal (stdlib):** `Term::cols()`, `Term::rows()`, `Term::key_pressed()` (a line + Enter typed; nothing is waited for and the terminal is not changed). The examples stop on Ctrl-C or Enter.
* **Examples:** `examples/blackhole.jk` is the colour version (hot red-orange gas, bluer where it comes towards us, the thin blue ring of light that went round the hole, glow, stars; it takes the size of the terminal); the character version is `examples/blackhole_ascii.jk`. `Math::min_int`, `Math::max_int`.
* **Docs:** conditions have no parentheses and `{` ends them (no ambiguity); array lists.
* **Housekeeping:** `ship.sh` refuses to release while untracked files lie in the folder (a binary and private files had been committed by mistake in 0.9.20 - 0.9.25).

## 0.9.25
* **Examples run until Ctrl-C** when no number of frames is given (`solar`, `blackhole`; `solar 300` stops after 300 frames). Before, they stopped by themselves after a fixed number of frames.
* **Solar system:** every orbit fits the screen; planets move on ellipses by Kepler's law and are lit by the sun (the side away from the sun is dark); moons, the ring of Saturn, an asteroid belt, twinkling stars.
* **Black hole:** the disk is hotter inside (T ~ r^-3/4), turns faster inside, the side that comes towards us is brighter (Doppler boost) and light that climbs out of the hole loses energy; two rays per character smooth the edges; the view nods slowly.
* **gfx:** `Canvas.ball_lit(centre, radius, ramp, to_light)` lights a ball from a given direction; the shadow side still shows the faintest character.

## 0.9.24
* **gfx library:** `#import <gfx>` once, then `using gfx::canvas;` (loads `math::vector` too). `Canvas::make(w, h)`, `clear`, `put`, `get`, `text`, `plot(vec3, char)` (perspective, nearest wins), `line`, `ball(centre, radius, ramp)` (shaded ball), `frame`, `show`, `clear_screen`, `free`. Fields `view` and `wide` set the perspective and the character shape.
* **Examples:** `examples/solar.jk` is shorter with the Canvas; new `examples/blackhole.jk`: every character follows a ray of light bent by gravity (the disk around the hole shows up bent over the top).

## 0.9.23
* **Example `examples/solar.jk`:** an animated ASCII solar system (sun, five planets, orbits, shading, perspective, z-buffer) written with `vec3`, `mat3` and operators. Run: `jcmp examples/solar.jk -o solar && ./solar` (needs a terminal of 100 x 37).

## 0.9.22
* **`vec`:** `vec pos = {1.0, 2.0, 3.0};` is a `vec3` (the number of values says which: 2, 3 or 4). Elsewhere (parameters, fields, results) write `vec2`, `vec3`, `vec4`.
* **Swizzle:** `v.xy`, `v.zyx`, `v.xxyy`, `c.rgb` make a new vector from some components of a `vec2/3/4` (letters of `xyzw` or of `rgba`, not mixed); a single letter (`v.r`, `v.y`) is the component itself and can be assigned. A swizzle with several letters is read only.

## 0.9.21
* **JSON (stdlib):** `Json::parse(text)` gives a `Result<JsonDoc, Error>` (an error says what and at which byte); a `JsonDoc` is a table of nodes (a node is a number, -1 = none): `root get at len has name_of text number integer boolean is_null kind_of dump`. `Json::quote(s)` and `Json::num_text(x)` make JSON text. Strings are decoded (`\n`, `\u00e9`, surrogate pairs to UTF-8).
* **Fixed:** a data enum member with a parameter named `s` (`Name(String s)`) clashed with a name made by the compiler.
* **Fixed:** `return v;` of a name bound in a case to a struct that frees itself (for example `Result<JsonDoc, Error>::unwrap`) is a move now: the struct is copied out and the enum's copy is emptied. Before, `Result<T, E>` with such a `T` did not compile.
* Warnings about passing a large struct by value are not given for generic instances.

## 0.9.20
* **Operator methods:** a struct method declared with the word `operator` can be used with an operator: `+` calls `add`, `-` calls `sub`, `*` calls `mul`, `/` calls `div`, `==` / `!=` call `eq`; `a += b` (also `-= *= /=`) is `a = a.add(b)`. Example: `operator vec3 add(self, vec3 o) { ... }`, then `p = a + b * 2.0;`. A struct on the left only (`v * 2.0`); `2.0 * v` is an error that says so. A method without `operator` is never called by an operator.
* **Renamed:** the math types are `vec2 vec3 vec4 mat3 mat4` (lower case), and their `add sub mul div eq` are operators.

## 0.9.19
* **One import for the math library:** `#import <math>` once, then `using math::vector;`, `using math::matrix;` or `using math;` choose the parts (only those are compiled in). This replaces `#import <vector>` / `#import <matrix>` of 0.9.18.

## 0.9.18
* **Math libraries:** `#import <vector>` gives `Vec2`, `Vec3`, `Vec4` (make, zero, splat, add, sub, mul, div, neg, dot, cross, length, distance, normalize, lerp, min, max, abs, reflect, eq); `#import <matrix>` gives `Mat3`, `Mat4` (identity, scale, rotate_x/y/z, mul, mul_vec, transpose, and for `Mat4` translate, point, direction, project, perspective, look_at). Operators (`a + b`, `pos += vel * dt`) and swizzle come later (docs/syntax-design.md section 55).
* Warnings inside the built-in libraries are no longer shown to the user.

## 0.9.17
* **`Sha256`:** `Sha256::hex(text)` and `Sha256::file(path)` (a `Result`) give the SHA-256 digest as 64 hex digits. Checked against `sha256sum`, also on a 1 MB binary.

## 0.9.16
* **`Proc`:** `Proc::run(cmd, args)` runs a program and returns its exit code; `Proc::output(cmd, args)` returns what it printed. The program is looked for in `PATH` unless its name has a `/`; 127 means it could not be started.

## 0.9.15
* **UTF-8 text:** `s.count()` (characters), `s.chars()` (a `String[]`, one character each), `s.char_at(i)`; `upper()` / `lower()` handle Latin-1, Latin Extended-A, Greek and Cyrillic. `len` still counts bytes.

## 0.9.14
* **`Num::parse_int(s)` / `Num::parse_double(s)`** return a `Result<…, Error>` (kind `Parse`) instead of throwing, so `int n = Num::parse_int(s)?;` works.

## 0.9.13
* **A panic prints where it happened:** after `panic: <what>` the running functions follow, innermost first (`  at inner`, `  at outer`, `  at main`; methods as `Type::name`).
* **`using enum` works for data enums:** after `using enum Shape`, `switch` can use the short member names (`Circle(r):`).
* The limit of structs in one program is 256 (was 80).
* New in the assembler/compiler: `.quad`, `.asciz`, and the built-in `__fp()` / `__fntab()` (used by the trace).

## 0.9.12.1
* **Methods and `.len` on any String / array expression:** `"  text ".trim().len`, `s.trim().upper()`, `Env::args().len`, `words().join("+")`, `"MiXed".upper()` (before, only on variables and on the result of a call).
* A moved value that is used again by a method call (`b = a; a.len()`) gets the `-Wmoved` warning, like a plain read.

## 0.9.12
* **`Math` is complete:** `exp log log2 log10 pow sin cos tan asin acos atan atan2 sinh cosh tanh cbrt hypot fmod round sign clamp lerp radians degrees pi tau e inf nan is_nan is_inf powi from_bits to_bits`. Checked against known values to 12 digits.
* **Changed:** `Math::pow(x, y)` takes two decimals (like C). The old `pow(x, n)` with a whole-number exponent is now `Math::powi(x, n)` (and fast: by squaring, negative n allowed).
* **Fixed:** a decimal literal with an exponent beyond 18 (for example `0.00004539992976248485`, which is 4539992976248485e-20) gave a wrong value; it is exact now (to e22).
* **Fixed:** a forward call that returns a decimal could not be mixed with a decimal in an expression (`0.0 - f()` with `f` written later).

## 0.9.11
* **Fixed (serious):** names of functions longer than 23 characters were cut short by the assembler, so two functions whose names start the same way (for example `Result__String___Error__Ok` and `...__free`) could be taken for one. Names up to 63 characters are exact now (a longer one is an error).
* **Standard library:** `Fs` (read_text, read_lines, write_text, append_text, exists, size, remove, rename), `Dir` (exists, make, make_all, remove, list, current), `Env` (get, args), `Time` (now_ms, mono_ns, sleep_ms), `Random` (seed, next, range, unit).
* The value a call returns is looked at directly: `Env::get("HOME").is_some()`, `f().trim()`. A value that frees itself and is not used is freed at the end of the statement.
* `(Name::call() + 1)` in parentheses is not mistaken for a cast; `(char^)p` is a text.

## 0.9.10
* **Bugs are panics:** dividing by zero, a null/freed array or String, a position out of range, `pop` of an empty list, `unwrap` of `None`/`Err`, a function that ends without `return`, no memory: `panic: <what>` and exit code 134; `try`/`catch` cannot catch them. New: `panic("text")`, `assert(condition, "text")` (std), `Map.try_get(k)` (an `Option`).

## 0.9.9
* **`defer`:** `defer statement;` / `defer { ... }` runs when the block is left (end, `return`, `break`, `continue`, or a `throw` passing through), last defer first, with the variables as they are then.

## 0.9.8
* **`Option<T>` and `Result<T, E>`** (std) with the standard `Error` (`kind`, `message`) and **`expr?`**: an `Err` / `None` returns from the function at once, the content of an `Ok` / `Some` is the value. Methods `is_ok is_err is_some is_none unwrap or`.
* **Values that free themselves are moved:** a struct with `free(self)` (and a data enum that holds a String, an array or such a struct) is moved by `=`, by a by-value parameter and by `return`; a fresh value from a call is taken over.
* In a `switch` a member that frees itself is named by a pointer. The cleanup of a `throw` and the end of a function also free the parameters of that kind.

## 0.9.7
* **Enums that carry values:** `enum class Shape { Circle(double r), Rect(double w, double h), Empty; ...methods };`, built with `Shape::Rect(2.0, 3.0)`, taken apart with `switch s { Shape::Rect(w, h): ... }`. They can be generic (`enum class Maybe<T> { Some(T value), Nothing }`). The first step of the error model (`Option`, `Result`, `?` follow).

## 0.9.6
* **More String methods:** `trim`, `upper`, `lower`, `replace`, `repeat`, `starts_with`, `ends_with`, `contains`, `to_int`, `to_double`, `split` (gives a `String[]`) and `join` on a `String[]`.

## 0.9.5
* **Where the program goes:** `jcmp sub/test.jk -o sub/` (or `-o sub` when `sub` is a folder) writes `sub/test`; `jcmp test.jk sub/test` also names the program (a second name that ends in `.jasm` still means only the assembler text).

## 0.9.4
* **`-o` is optional:** `jcmp test.jk` writes the program `test` (the name of the source without `.jk` / `.j`, in the current folder). `-o name` still chooses the name.

## 0.9.3
* **A missing `;` is reported where it is missing:** `expected ';' at the end of line 4 (it is missing there)` with the `^` right after the last token of that line (before, the message pointed at the next line and talked about `<<`).
* **A program file that cannot be written has a clear message:** `cannot write the program file 'test' (a folder with that name, a program that is running, or no permission?)` (before: `j2k_asm: error at line 155 ... parse or I/O error`).

## 0.9.2
* **A generic function finds its types from the arguments:** `largest(3, 9)`, `swap(@x, @y)`, `first(names)`. Numbers, chars, texts, variables, `@variable` and arrays are understood; anything else, a mix of types (`largest(1, 2.5)`) or a `T` that no parameter shows must be written with `<type>`. A struct (`Box<int>`) is still always written.

## 0.9.1
* **A lambda is written like a function without a name** (the way functions are declared: result type first, no `->`): `int(int a, int b) { return a + b; }`, `void() { ... }`. The form of 0.9.0, `(int a, int b) -> int { ... }`, still works with a warning.

## 0.9.0
* **Lambdas:** a function without a name where you use it: `(int a, int b) -> int { return a + b; }`, `() -> void { ... }`. It gives a function pointer, so it can be passed to a function or kept in `int(int, int)^ f = ...;`. It cannot use the variables around it (a clear message says so).
* `->` is a token now.

## 0.8.1
* **A `throw` frees what the left functions owned:** arrays, Strings, `alloc` blocks, Strings made inside a statement and structs with `free(self)` are freed on the way to the `catch` (innermost first). Before, they leaked. Cost: about ten instructions when an owner is made.
* Warnings are bright yellow now (a fixed colour that does not depend on the terminal theme).

## 0.8.0
* **`#import`** (with the `#`, like `#define`): `#import <stdlib>`, `#import "file"`. A plain `import` still works with a warning `[-Wimport]`; a later version makes the `#` required.
* **`cout` and `cin` handle every type**, decimals included. `coutf` and `cinf` still work with a warning `[-Wdeprecated]`.
* **A function that must return a value but has no `return` at all is an error** (`make it void, or return something`). A path that reaches the end without `return` still throws at run time (0.7.1).
* New warnings: `-Wunused` (a local variable that is declared and never used).
* Removed the check "cout cannot print a float" (floats print with `cout` now).

## 0.7.1
* **A function that ends without `return`** (and returns a value) now throws `a function ended without returning a value` instead of giving a junk number. A normal `return` costs nothing extra. `main` without `return` still gives 0, as in C.
* A missing `<<` in `cout` (or `>>` in `cin`) is explained: `expected ';' or '<<' here (is a '<<' missing between two values?)`.

## 0.7.0
* **`import <library>`** for libraries and **`import "file"`** for your own files. A library is looked up in `-I`, `J2K_PATH`, `~/.j2k/lib` and the `lib` folder next to the compiler.
* **`std` is now `stdlib`:** `import <stdlib>`, `using stdlib`, `using stdlib::math`. `cpu` is `import <cpu>`. The old forms (`import std`, `using std`, a bare `import cpu`) still work with a warning (`[-Wdeprecated]`, `[-Wimport]`).

## 0.6.0
* **Collections:** `Map<K,V>` (`put get has remove len keys_list values_list`), `Set<T>` (`add has remove len items_list`) in the standard library; keys can be numbers, chars, pointers or Strings. `get` throws `key not found`.
* **`String[]`**: an array of Strings (it owns them). **List methods** on every dynamic array: `insert`, `remove`, `sort`, `contains`, `index_of`.
* **`for x in list { }`** over a dynamic array, a `String[]`, a String (its characters), a fixed array or a list returned by a call.
* **A struct with a method `free(self)` is freed by the compiler** at the end of the block of a local variable (also on `return`, `break`, `continue`). It starts zeroed and cannot be copied, passed or returned by value.
* Warnings are yellow (they were orange).

## 0.5.0
* **Names of the decimal types:** `float` (32 bit) and `double` (64 bit), as in C. `f32` and `f64` still work, with a warning `[-Wdeprecated]`.
* **`cout`, `coutf`, `cin`, `cinf` need `import std` and `using std`.** A program without them gets the warning `[-Wstd]` (a later version makes it an error). Update your programs: put `import std` and `using std` at the top.
* `using std` makes `Sys`, `Mem`, `Str`, `Math` and `File` usable without the prefix; a name that is in two of them (`write`) is an error that tells you to write `File::write`.

## 0.4.0
* **`String`**: text that grows. `String s = "hi";`, `a + b`, `a == b`, `s += x`, `s.len`, `s[i]`, `push pop append clear find slice c`, `cin >> s`. `String b = a;` makes a copy; Strings are freed at the end of their block, and a String made by an expression is freed at the end of the statement.
* **Generics** (since 0.3.1) are described in the tour (`docs/LANGUAGE.md`) and the tutorial (lessons 12 and 13).
* Functions that return `char^` (a text) can be printed with `cout`.

## 0.3.3
* **Fixed:** declaring a name twice in a block (or a local with the name of a global) reported the error at the *next* statement; it now points at the name that is declared again.

## 0.3.2
* **Division by zero throws** `"division by zero"` (catchable with `try`/`catch`) instead of silently giving 0. A literal divisor other than 0 costs nothing.
* **A crash tells why:** a null pointer or a stack overflow prints `runtime error: segmentation fault (null pointer or stack overflow)` and exits with 139.
* **New warning `-Wuninit`:** a variable declared without a value is read before anything was written to it.
* **Messages are easier to read:** errors in red, warnings in yellow (only when the output is a terminal; `-color` / `-nocolor` choose), and the source line has its line number: ` 12 | code` with a `^` under the place.

## 0.3.1
* **Fixed:** calling a function that does not exist (for example `alloc` without `import std` / `using std::mem`) ended with a message from the assembler; it is now `error: unknown function 'name'` at the call.
* **Fixed:** `cout << f()` printed a number when `f` returns `char`.
* The limit of structs is 80 (was 64); generic instances count. An error inside a generic instance points at the place of the use.
* **Generics**: `T max<T>(T a, T b)`, `struct Box<T>`, `struct Pair<A, B>`; the type is written at every use (`max<int>(1, 2)`, `Box<f64> b;`). A generic must be written before its first use.

## 0.3.0
* **Threads**: `import cpu` gives `Thread` (create, join, detach) and `Mutex` (futex based). Every thread has its own `try`/`catch` state and its own 1 MB stack; the heap (`alloc`/`free`) is safe to use from several threads.
* **`#multithread`** in front of `for i in a..b { ... }`: the iterations are shared among the CPU cores and the loop ends when all of them are done. `break`, `return` and a nested `#multithread` inside the body are errors.
* Built-in atomic helpers used by the library (`__cas`, `__xchg`, `__fetch_add`).

## 0.2.2
* The release files are named `jcmp` and `j2k_asm` (no more `-linux-arm64` in the name of the program); the bundle is still `jcmp-<version>-linux-arm64.tar.gz`. `install.sh` also installs older releases.
* New release file `jcmp.tar.gz` (only the program, with its executable bit): `curl -fL .../jcmp.tar.gz | tar xz -C ../bin`.
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
