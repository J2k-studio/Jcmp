# Changelog

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
