# A tour of J2K

This is a practical guide to what the compiler accepts **today**. The formal decisions
(and the reasons for them) are in [syntax-design.md](syntax-design.md); things that are
planned but not built are listed at the end.

Files: `.jk` is a program (it has `main`); `.j` is a component that other files `import`
(it may not define `main`).

## Program shape

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << "hi\n";
}
```

`cout` and `cin` need no import and no `using`: they are always there (the other modules of the standard library still need
`#import <stdlib>`; `using stdlib` makes their names usable without the prefix).
`using stdlib` makes the names of all the std modules usable without the prefix; if two modules have the same name (`write` is in `Sys` and
`File`) the compiler reports it and you write `File::write(...)`. `float` is the 32-bit and `double` the 64-bit decimal type (they were
called `f32` and `f64`; the old names still work with a warning).

`main` may be `void main()` or `int main()` (the returned number is the exit code).
A new line is written `"\n"` (a backslash and n; not `"/n"`, which is a slash and the letter n and gets a warning) or with the word `nl`,
which needs no backslash: `cout << x << nl;`. A single value, `cout << x;`, gets its new line by itself.
Statements end with `;`. Blocks use `{ }` and are always required. `//` and `/* */` are comments.

## Types

| Type    | Meaning                                  |
|---------|------------------------------------------|
| `int`   | 64-bit signed integer                    |
| `i32`, `i8` | 32 / 8-bit signed integers           |
| `char`  | 8-bit **unsigned** (a byte / character)  |
| `bool`  | `true` / `false` (1 byte)                |
| `u8`, `u32`, `u64` | unsigned integers (8 / 32 / 64 bit) |
| `double`, `float` | floating point                      |
| `T^`    | pointer to `T`  (`void^` = pointer to anything) |

Rules that catch bugs early:

* `bool` is not a number: `if x` with an `int` is an error — write `if x != 0`.
* Enums are not numbers; floats and integers do not mix: `(double)n`, `(int)x`.
* Arithmetic is done at full register width (`i8 + i8` is an `int`); the value is cut to size
  when it is **stored** or **cast**.

```jk
void main() {
    i8 a = 100;
    i8 b = 100;
    int sum = a + b;      // 200 (no overflow in the addition)
    i8 small = a + b;     // -56 (cut to 8 bits when stored)
    cout << sum << "\n";
    cout << small << "\n";
}
```

### Unsigned numbers

```jk
void main() {
    u32 h = 2166136261;              // does not fit an i32, fits a u32
    u8 b = 250;
    b += 10;                         // 260 is cut to 8 bits when stored: 4
    u64 huge = 18446744073709551615;
    cout << h << " " << b << " " << huge << " " << (huge >> 63) << "\n";
    int n = -1;
    u32 back = (u32)n;               // signed <-> unsigned needs a cast
    cout << back << "\n";
}
```

Unsigned values are compared, divided and shifted right as unsigned numbers. Mixing a signed
with an unsigned value is an error (cast one side); unsigned types of different sizes mix
(the wider one wins). A whole-number literal fits any numeric type; `-1` does not fit an
unsigned one. `u8` is a number, `char` is a character (they print differently).
Arithmetic runs at full register width and the value is cut to size when it is stored,
so `a - b` on two `u32` shows a huge value until it is stored in a `u32`.

## Variables, constants, operators

```jk
int x = 5;
x += 2;  x++;  x xor= 1;
bool ok = x > 3 && x < 100;
int bits = (x << 2) | 0xFF;         // 0x.. and 0b.. literals
char letter = 'A';
```

Operators, highest first: `* / %` · `+ -` · `<< >>` (`shl shr`) · `&` · `xor` · `|` ·
`< > <= >=` · `== !=` · `&&` · `||`. Bit operators bind tighter than comparisons
(`a & 1 == 0` means `(a & 1) == 0`). `~x` is bitwise not, `!` is logical not.
`xor` is a word because `^` means "pointer".

Constants: `#define MAX 100` (text substitution; defined before use). When the text is an arithmetic expression of several tokens it is kept in parentheses, so `#define N 2+3` gives `N * 2 == 10`; a text that is not an expression (a type, an argument list, a statement, an assignment, a string) is substituted as written. An array size may be a constant expression: `int a[N * 2 + 1];`.

## Control flow

A condition has no parentheses: `if a > b { ... }`, `while n < 3 { ... }`, `for i in 0..5 { ... }`. The `{` ends the condition: an expression never continues with `{` (the only place where `{ ... }` is a value is the right side of a declaration, `Point p = {1, 2};`, and there the `{` comes straight after the `=`), so no ambiguity is possible.

```jk
void main() {
    int n = 0;
    while n < 3 { n++; }

    for int i = 0; i < 10; i += 2 { if i == 6 { break; } }   // C-style
    for i in 0..5 { cout << i << " "; }                      // 0,1,2,3,4 (end excluded)
    cout << "\n";

    if n == 3 { cout << "three\n"; } else if n == 4 { cout << "four\n"; } else { cout << "other\n"; }
}
```

`for i in a..b` evaluates `b` once. `break` and `continue` work in both loops.

### switch

```jk
enum class Kind { Num, Plus, Minus };

int apply(Kind k, int a, int b) {
    int r = 0;
    switch k {
        Kind::Plus: r = a + b;
        Kind::Minus: { r = a - b; r += 0; }
        _: r = -1;
    }
    return r;
}

void main() { cout << apply(Kind::Plus, 3, 4) << "\n"; }
```

No fall-through. `_` is the default. Several values: `1, 2, 3: ...`. An enum `switch`
without `_` that misses a member gives a warning (`-Wswitch`).
`using enum Kind;` lets you write `Plus` instead of `Kind::Plus`.

## Functions

```jk
int add(int a, int b) { return a + b; }
void main() { cout << add(2, 3) << "\n"; }       // functions may be used before they are written
```

At most 16 parameters (the 9th and later travel through a small area of global memory, so programs that call functions from several threads would need another scheme). A function can be used above its definition. Arrays are passed with
their length (see below). Structs are passed by value (copied); use `T^` to share.

### Default arguments

The last parameters may have a default value: a constant (a whole number, a bool, a char, `null`, an enum member). A call may leave those parameters out; the compiler puts the value in. A parameter without a default cannot come after one with a default.

```jk
int add(int a, int b = 10, int c = 100) { return a + b + c; }
void main() { cout << add(1) << " " << add(1, 2) << " " << add(1, 2, 3) << "\n"; }     // 111 103 6
```

Methods work the same way (`int bump(self, int d = 1)`). Named arguments are not built (syntax-design 98, B).

## Arrays and strings

A function can have any number of array parameters (`int dot(int a[], int b[])`), anywhere in the list. `str(x)` makes a String from a number, a char, a bool or a String: `str(42)`, `str(2.5)`, `str('x')`, `str(true)`.

```jk
int sum(int a[]) {                  // an array parameter arrives with its length
    int s = 0;
    for i in 0..a.len { s += a[i]; }
    return s;
}

void main() {
    int v[5];                        // not cleared
    for i in 0..5 { v[i] = i + 1; }
    int grid[3][4];                  // up to 3 dimensions
    grid[1][2] = 7;
    char name[] = "J2K";             // size counted for you (includes the 0 at the end)
    double dist[3] = {12.0, 18.0, 25.0};   // a list of values (the rest, if any, is zero)
    int primes[] = {2, 3, 5, 7};     // [] : the size is the number of values (1 dimension; also for globals, with constants)
    char path[] = r"C:\raw\string";  // raw string: no escapes
    cout << sum(v) << " " << grid[1][2] << " " << name << " " << path << "\n";
    cout << v.len << "\n";           // 5
}
```

Strings are `char` arrays ending in 0. Escapes: `\n \t \r \0 \\ \" \'`.
`cout` prints a char array as text, a `char` as a character, and anything else as a number.
`cout << x;` with a single number prints a newline after it; in a chain
(`cout << a << b;`) you write `"\n"` yourself. Floats are printed with `cout` too (6 decimals).

## Dynamic arrays

```jk
int sum(int[] a) {                      // passed by reference: the callee sees the same array
    int s = 0;
    for i in 0..a.len { s += a[i]; }
    return s;
}

void main() {
    int[] list = arr(4);                // T[] : room for 4 elements, length 0
    for i in 1..11 { list.push(i * i); }   // it grows when full
    cout << list.len << " " << sum(list) << " " << list.pop() << "\n";   // 10 385 100
    list.resize(3);                     // length 3 (new elements are zero)
    list[1] = 42;
    cout << list[1] << " " << list.len << "\n";   // 42 3
    list.free();                        // frees the memory; the variable is null afterwards
}
```

`T[] x = arr(n)` makes an array with room for `n` elements and length 0. Members: `x.len`, `x.cap`,
`x.push(v)`, `x.pop()` (returns the removed element), `x.resize(n)`, `x.clear()`, `x.free()`.
Elements can be numbers, pointers, structs. A `T[]` variable is a reference: `b = a` makes both names
use the same array, and `f(a)` shares it. A variable that was never given an array (or was freed) is null;
using it throws `the dynamic array is null` (catch it with `try`/`catch`). Indexing is checked against the
length in a `-d` build.

## Strings

`String` is text that can grow. It lives on the heap and is freed at the end of its block, like a dynamic array.

```jk
String a = "abc";            // a copy of the text
String b = a;                // a separate copy
b.push('d');                 // a stays "abc"
String c = a + "-" + b;      // joins; == and != compare
cout << c << " " << c.len << " " << c[0] << "\n";
cout << c.find("-") << " " << c.slice(2, 5) << "\n";    // 3 and a new String
c += "!";                    // append (a String, a text or a char)
cin >> a;                    // one word
```

* **Text with values inside** (owner's design, section 99 of the syntax notes): `{expression}` in a text is the value of the expression as text, so `"x = {x}, y = {y + 1}"` means `"x = " + str(x) + ", y = " + str(y + 1)`. The expression is a number, a char, a bool or a String (what `str` takes). `{{` and `}}` are a `{` and a `}`. A `{` that is not followed by a letter or `(` stays as it is (`"{ text }"`, `"{}"`).

```jk
int x = 5;
String name = "Jao";
cout << "x = {x}, next = {x + 1}, hi {name}! {{braces}}\n";    // x = 5, next = 6, hi Jao! {braces}
```
* Methods: `push(char)`, `pop()`, `append(x)`, `clear()`, `find(x)` (index or -1), `slice(from, to)`, `c()` (the characters as a plain text, valid until the String changes), `len`, `free()`.
* More methods: `trim()`, `upper()`, `lower()` (ASCII letters), `replace(a, b)`, `repeat(n)` (each gives a new String); `starts_with(x)`, `ends_with(x)`, `contains(x)` (true/false);
  `to_int()`, `to_double()` (the whole String must be a number, else it throws `not a number`); `split(sep)` gives a new `String[]` and `join(sep)` on a `String[]` joins it again.
  Methods work on a variable (`t.trim()`), not on a text written in the program (`"abc".trim()`).
* A new String made by an expression (`a + b`, `slice`, a call that returns a String) is a temporary: the compiler frees it at the end of the statement unless it is stored in a variable. It cannot be made on the right of `&&` or `||` (the right side may not run): put it in a variable first.
* `return s;` moves a local String out; returning a parameter or a field copies it. A String parameter only borrows, so it cannot be assigned inside the function.
* A `String` that is a field of a struct or a global is not freed by itself: call `free()`.
* Text is UTF-8: `len` and `s[i]` count bytes; `s.count()` counts characters, `s.chars()` is a `String[]` with one character each, `s.char_at(i)` one character. `upper()` / `lower()` know Latin, Greek and Cyrillic letters.
* Index checks happen in `-d` builds, like for every array.

## Generics

A function or struct takes types as parameters, written in `<>` after the name; the compiler makes one copy of it for every combination you use.

```jk
T largest<T>(T a, T b) { if a > b { return a; } return b; }
struct Pair<A, B> { A first; B second; }

cout << largest(3, 9) << "\n";            // T is worked out from the arguments: int
cout << largest<int>(3, 9) << "\n";        // or written
Pair<int, double> p = {1, 2.5};          // a struct always has its types written
```

* A **function** finds its types from the arguments: numbers (a whole number is an `int`, one with a point a `double`, and it follows the variable beside it:
  `largest(3, n)` with `n` an `i32` is `i32`), chars, texts, `true`/`false`, variables, `@variable` (for `T^`) and arrays (for `T[]`, the element type).
  `largest(1, 2.5)` and `largest(d, i)` (a `double` and an `int`) are errors: the types do not mix, cast one or write `largest<double>(...)`.
  Anything else (`largest(f(1), 2)`) and a `T` that no parameter shows (`T make<T>()`) must be written: `make<int>()`. A **struct** (`Box<int>`) is always written.
  A plain function with the same name wins over the generic.
* A generic must be written before the first place that uses it. Errors inside an instance point at the line of the generic.
* Instances are ordinary functions and structs (`largest<int>` is called `largest__int`), so the limit of 80 structs counts them.

## Lists, maps and sets

A list is a dynamic array: `T[]` (numbers, pointers) or `String[]` (the array owns its Strings and copies what you push).

```jk
int[] xs = arr(4);
xs.push(5); xs.push(-2); xs.push(9);
xs.sort();                    // ascending: -2 5 9
xs.insert(1, 7);              // place, value
xs.remove(0);
cout << xs.index_of(9) << xs.contains(4) << "\n";   // place or -1, true/false

String[] names = arr(2);
names.push("carol"); names.push("alice");
names.sort();
names[0] = "zoe";             // the array keeps its own copy
```

`for x in list { ... }` goes through the elements (also a String: its characters, a fixed array, and a list returned by a call, which is freed
after the loop). `x` is a copy of the element (a String element is only borrowed). `for i in a..b` still counts numbers.

`Map<K,V>` and `Set<T>` are hash tables in the standard library (`#import <stdlib>`). Keys can be whole numbers, chars, floats, pointers or Strings.

```jk
Map<String, int> ages;
ages.put("ann", 31);
ages.put("bob", 25);
cout << ages.get("bob") << ages.has("zed") << ages.len << "\n";   // get throws "key not found"
ages.remove("ann");
for k in ages.keys_list() { cout << k << "=" << ages.get(k) << "\n"; }   // values_list() too

Set<int> seen;
if seen.add(3) { cout << "new\n"; }     // add says whether it was new
```

* A variable of a struct that has a method `free(self)` is freed by the compiler at the end of its block (also on `return`, `break`, `continue`): that is
  how `Map` and `Set` clean up. Such a struct starts zeroed, and cannot be copied, passed or returned by value (use a pointer).
* `keys_list()`, `values_list()` and `items_list()` return a new list (the caller owns it).

## Heap memory that frees itself

```jk
#import <stdlib>
using stdlib;

struct Node { int value; Node^ next; }

Node^ make(int v) {
    Node^ n = (Node^)alloc(sizeof(Node));   // n owns this block ...
    n^.value = v;
    return n;                               // ... and hands it to the caller: it is not freed here
}

void main() {
    int^ tmp = (int^)alloc(80);             // freed by the compiler at the end of main
    tmp[0] = 7;
    int[] list = arr(4);                    // so is a dynamic array that main made
    list.push(tmp[0]);
    Node^ a = make(1);                      // the caller of make owns the result
    cout << a^.value + list[0] << "\n";     // 8
}
```

A local variable declared directly from `alloc(...)` or `arr(...)` (or from a function that returns
what it owns with `return p;`) **owns** that memory; the compiler frees it at every way out of the block:
the end, `return`, `break`, `continue`. Ownership moves (the old variable becomes `null`) when you
`return` the variable, store it into a field, an array element, a global or a pointer element of a dynamic array,
or write `move(p)` for an argument. Passing it to a function without `move` only lends it. A variable you
free by hand (`free(p)`) becomes `null` too, so nothing is freed twice.
`move(ps[i])` also takes an element of an array of structs that free themselves (`Person t = move(ps[1]);`): the slot becomes empty (zeros).
Warnings: `-Wleak` (the result of `alloc` is thrown away), `-Wmoved` (a moved variable is used again).
Limits: a `throw` that leaves a block does not free that block's memory, and memory kept by a pointer that is
assigned after its declaration is not tracked (use a declaration, or free it yourself).
A `-d` build reports at the end of `main` how many blocks were never freed (and in which function each one was made), stops at a block freed twice, and finds a block that was written after it was freed.

### The bracket forms of memory

A shorter way to write the same things (the forms with parentheses, `alloc(bytes)`, `free(p)`, `arr(n)`, stay). `n` is a number of **elements**:

```jk
alloc[int^ p = 32];            // int^ p, 32 ints (not cleared); p owns them, the compiler frees them at the end of the block
alloc0[int^ z = 32];           // the same, every byte 0
int[] x = arr[n];              // a dynamic array that can hold n (same as arr(n))
free[p];                       // gives the block back (p is null from now on)
free[p = 32];                  // the same; a -d build checks that the block can hold 32 elements
grow[p = 64];                  // p becomes a block of 64 elements with the old content (p is the same if there is no memory)

alloc[int^ pool = 32];         // a pool of 32 ints ...
alloc[pool[12] >> int^ a];     // ... 12 of them go to a (null if the pool has not that much room)
alloc[pool[12] >> int^ b];
free[b];                       // only b goes back (a still works, and the next piece may use b's room); free[pool] frees everything
```
If a variable is called `alloc`, `alloc0`, `free`, `grow` or `arr`, a `[` after it is an index as always.

### `frame`, `interrupt`, `align(N)`, `@no_reorder` (0.9.82)

```jk
frame Context { x19..x30; sp; }                  // a record of registers: 13 words in the order of the list

naked void ctx_switch(int^ from, int^ to) {      // a coroutine switch in two lines
    Context::save(x0);                           // x0 = the address of the record that receives this task's registers
    Context::restore(x1);                        // x1 = the record of the task to run: x30 and sp change, so `ret` goes into it
    ret;
}

interrupt void on_timer() { ticks += 1; }        // saves x0 .. x18, ends with eret (no floating point inside)
align(128) interrupt void on_irq() { ... }       // starts at an address that is a multiple of 128

@no_reorder {                                     // every instruction here stays: not moved, merged or removed
    t = a / 7;
    t = a / 7;
}
```
`Context::size` is the size of the record in bytes. `Context::save` and `restore` are statements of naked functions and register blocks; the base register cannot be `x17` and, for `restore`, not one that the frame restores.

### Registers of your own: `#reserve`, `register { }`, pinned variables (0.9.81)

```jk
#reserve x18, x19                       // the compiler never gives these to a variable (x18 and x19 .. x25 can be reserved)

int work(int n) {
    int acc @ x20 = 0;                   // lives in x20 for the whole function, also across calls
    for i in 0..n { acc += i; }
    Reg::x18 = acc;                      // normal code can read / write x18 and the reserved registers
    register {                           // the statements of the low level, with the bare names x0 .. x30
        x1 = x18;
        x1 <<= 1;
        x18 = x1;
    }
    return Reg::x18;
}
```
Inside a `register { }` block, lines at its start can carry values in and out (0.9.108):

```jk
register {
    in x1 = a;                  // x1 = the value of the expression a, made before the instructions (several `in`, at most 8)
    in x2 = b * 2;
    clobber x4;                 // the registers the block changes besides in / out: with this line the compiler warns about any other
    x4 = x1 + x2;
    x0 = x4;
    out x0 = r;                 // the variable r (an int or a pointer) gets x0 after the block
}
```
`in` values are all made first and then loaded, so one expression cannot disturb the register of another.

`_.` is the short name of the same block, and it can have a name (0.9.112):

```jk
_.addone {                      // a block with a name: a function without parameters, made of low-level statements
    x0 += 1;                    // (`ret` is added at the end)
}

int main() {
    int v = 41;
    register {
        in x0 = v;
        _.addone;               // call it by name (also inside a naked function or a register block)
        out x0 = v;
    }
    _. { x0 = 7; }              // without a name: the same as register { }
    return v;
}
```
A file marked `#!library` can start with `_.start { ... }`: the first block is the entry.

A pinned variable (`int n @ x19`) is a whole number, pointer, bool, char or enum; its address cannot be taken; two variables of one function cannot share a register; programs with try / catch cannot pin. A function with a `register { }` block keeps its variables in the frame. Changing x19 .. x28 in a block without reserving it is a warning.

### `device`: hardware registers as data, and `Sys::` (0.9.80)

```jk
device Uart @ 0x0900_0000 {
    data:  u32 @ 0x00;
    flags: u32 @ 0x18 { txfull: 5; rxempty: 4; mode: 8..10; }     // names for a bit (a number) or a field of bits (high..low)
}

void put(char c) {
    while Uart.flags.txfull { }        // a read of the device each turn (a bool)
    Uart.data = c;                     // one store of 32 bits
}
Uart.flags.mode = 3;                   // read, change those bits, write
Uart.ctrl |= 1;                        // | & + - : read, change, write
int m = Uart.flags.mode;               // the bits as a number (not signed)     Uart.flags.bit(5): one bit by its number (a bool)
```
Registers are `u8 u16 u32 u64`; every access is made where it is written, as often as it is written (the optimiser does not merge or remove it).

`Sys::name` reads (`mrs`) and writes (`msr`) a system register by its name in every function: `int t = Sys::cntvct_el0;` `Sys::tpidr_el0 = p;` `Sys::daifset = 2;`. Most of them are for kernels (a program under Linux can read `cntvct_el0 cntfrq_el0 tpidr_el0 nzcv fpcr fpsr ...`); the general form `Sys::s3_0_c12_c0_0` names any register by its numbers. Numbers may have `_` between the digits: `0x0900_0000`, `1_000_000`.

### `abi`: your own calling convention for system calls (0.9.79)

```jk
abi Syscall { number: x8; args: x0..x5; result: x0; via: svc 0; }

int write(int fd, char^ buf, int n) { return Syscall::call(64, fd, buf, n); }     // mov x8, 64 / svc 0
```
`number:` (optional) is the register of the first value, `args:` the registers of the others (`x0..x5` or `x1, x0, x2`), `result:` where the answer is (it ends in `x0`), `via:` the instruction: `svc N`, `hvc N`, `smc N` or `bl function`. The same text works for a hypervisor call or for a function with an unusual convention.

*Names taken by the library:* `Bit`, `Cpu`, `Atomic`, `Cache` and `Mem` are structs of the prelude, so a program cannot define a struct with one of these names (`Reg`, `Sys`, `Syscall`-like `abi` names and `device` names are yours to choose, but not `Reg` or `Sys`).

### The CPU by name: `Cpu::`, `Atomic::`, `Cache::`, `Mem::barrier` (0.9.78)

Each is one instruction (or a short loop) where the call is, no call is made; they work in every function.

```jk
Cpu::wait();                       // wfi       Cpu::event();  Cpu::send_event();  Cpu::pause();  Cpu::nop();  Cpu::isb();
int t = Cpu::counter();            // the system counter (ticks since boot, no system call);  Cpu::frequency() = ticks per second;  Cpu::id() = the core

Atomic::add(@n, 1);                // returns the value it had before; sub, swap, bit_and, bit_or, bit_xor the same way
Atomic::cas(@lock, 0, 1);          // compare and swap: returns the value it had; it was changed if that is the old one you gave
int v = Atomic::load(@n);          // ldar            Atomic::store(@n, 5);   // stlr

Mem::barrier();  Mem::barrier_read();  Mem::barrier_write();  Mem::barrier_full();       // dmb ish / ishld / ishst, dsb sy
Cache::clean(p);  Cache::invalidate(p);  Cache::clean_invalidate(p);  Cache::zero(p);     // dc cvac / ivac / civac / zva
```

### The low level: `naked` functions (0.9.77)

A `naked` function has no prologue, no epilogue and no saves: its body is all there is, written with register statements, one statement for one instruction. Nothing is added by the compiler and the optimiser does not touch it.

```jk
naked int sys_write(int fd, char^ buf, int n) {     // the arguments are in x0, x1, x2 as for any function
    Reg::x8 = 64;                                    // write
    svc(0);
    ret;
}

naked int sum_to(int n) {
    x1 = 0;
  again:
    if x0 == 0 goto done;
    x1 += x0;
    x0 -= 1;
    goto again;
  done:
    x0 = x1;
    ret;
}
```

Statements: `R = number;` `R = R2;` `R = R2 op R3;` `R = R2 op number;` `R op= R2;` (op: `+ - * / & | xor << >> >>>`, `>>` keeps the sign, `>>>` does not), `R = ~R2;`, loads and stores `R = [B + off];` `R = u8[B + off];` (`u8 u16 u32 i8 i16 i32`) `[B + off] = R;`, `R = Bit::clz(R2);` (`clz ctz popcount bswap rbit`), `ret;` `goto label;` `label:` `call name;` `tail name;` `svc(n);` `if R == R2 goto label;` (`== != < <= > >=`, a number is allowed on the right) `if R.bit(n) goto label;` `if !R.bit(n) goto label;` `R = Sys::name;` and `Sys::name = R;` (system registers: `mrs` and `msr`), `Cpu::wait();` `Cpu::event();` `Cpu::send_event();` `Cpu::yield();` `Cpu::nop();` `Cpu::isb();` `Cpu::dsb();` `Cpu::dmb();` `Cpu::eret();` `Cpu::brk(n);` and `Cpu::inst("name", a, b)` for any instruction the assembler knows, with registers, numbers and labels as operands.

Registers are written `Reg::x0` .. `Reg::x30`, `Reg::sp`, `Reg::lr`, `Reg::fp`, `Reg::zero`, or by role `Reg::arg0` .. `Reg::arg7`, `Reg::ret`; inside a naked function the bare names `x0` .. `x30`, `sp`, `lr`, `fp` are allowed too. A number that does not fit an instruction is loaded into `x17` first. The parameters of a naked function are only counted; the caller passes them in `x0 .. x7` as always. Design: `docs/syntax-design.md` 63, `docs/design/08-asm-replacement.md`.

### Bits: `Bit::`

The work on the bits of a whole number is done by one instruction of the CPU each (the compiler puts the instruction at the call):

```jk
Bit::clz(x)          // bits 0 in front of the first bit 1 (64 for 0):   Bit::clz(1000) = 54
Bit::ctz(x)          // bits 0 after the last bit 1 (64 for 0)
Bit::popcount(x)     // how many bits are 1
Bit::rotl(x, k)      // the bits turned left by k places (k is taken modulo 64); Bit::rotr turns right
Bit::bswap(x)        // the 8 bytes in the other order
```

## Pointers

```jk
void main() {
    int x = 10;
    int^ p = @x;          // @ = address of, ^ after a type = pointer to
    p^ = p^ + 5;          // p^ = the value p points to
    int a[3];
    int^ q = @a;
    q[2] = 7;             // p[i] indexes (counted in elements); there is no p + 1
    cout << x << " " << a[2] << "\n";
}
```

`T^^` is a pointer to a pointer (`char^^ list; list[i]` is a `char^`, `pp^` a pointer); three levels are not supported.

`@` works on variables, elements (`@a[i]`) and fields (`@s.f`). `void^` must be cast to a typed
pointer before use: `(char^)p`. Pointers and integers convert with casts: `(int)p`, `(char^)n`.

## Function pointers

```jk
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }

int apply(int(int, int)^ f, int x, int y) { return f(x, y); }

void main() {
    int(int, int)^ op = add;            // RET(PARAMS)^ : a pointer to a function
    cout << op(3, 4) << "\n";            // 7
    op = mul;
    cout << apply(op, 3, 4) << "\n";     // 12
    int(int, int)^ none = null;
    if none == null { cout << "empty\n"; }
}
```

A function's name is a value; the pointer's type must match the signature (result and
parameter types), which the compiler checks. Pointers may live in variables, arrays and struct fields
(`table[i](x)`, `object.callback(x)`) and may be returned (`pick(1)(5, 5)`).
Methods (with `self`) and functions with array parameters cannot be used as values; at most 8 parameters.

## Enums that carry values

A member of an `enum class` can hold values. A value of such an enum is one thing that is a different member at different times:

```jk
enum class Shape { Circle(double r), Rect(double w, double h), Empty;      // the ; ends the members; methods may follow
    double area(self) {
        switch self^ {
            Shape::Circle(r):  return 3.14 * r * r;
            Shape::Rect(w, h): return w * h;
            Shape::Empty:      return 0.0;
        }
        return 0.0;
    }
};

Shape s = Shape::Rect(2.0, 3.0);          // Shape::Empty (no parameters): no ( )
cout << s.area() << "\n";                 // 6
switch s {
    Shape::Circle(r):  cout << "radius " << r << "\n";
    Shape::Rect(w, _): cout << "width " << w << "\n";    // _ ignores a value
    _:                 cout << "something else\n";
}
```

* The names after `Shape::Rect(` are new variables for that case: copies of the values (a String or an array is only borrowed).
* `switch` checks that every member is handled (a warning, an error with `-st`) unless there is a `_` case.
* A data enum is a struct inside (a tag and the members' values), so it can be copied, passed, returned and kept in arrays and other structs.
* It can be generic: `enum class Maybe<T> { Some(T value), Nothing; ... }` and `Maybe<int>::Some(5)`.
* A member of a data enum cannot be given a number (`= 5`); a plain `enum class` is as before.

## Files, folders, environment, time and random numbers

These are in the standard library. Names are Strings (a text written in the program works). Things that can fail for outside reasons give a
`Result<T, Error>` (use `switch`, `?` or `.unwrap()`).

```jk
Result<String, Error> t = Fs::read_text("notes.txt");          // the whole file
Result<String[], Error> lines = Fs::read_lines("notes.txt");   // without the line ends (CR LF too)
Fs::write_text("out.txt", "hello\n");   Fs::append_text("out.txt", "more");    // Ok(bytes written)
Fs::exists(path)   Fs::size(path)   Fs::remove(path)   Fs::rename(from, to)

Dir::exists(path)  Dir::make(path)  Dir::make_all("a/b/c")  Dir::remove(path)    // remove: an empty folder
Dir::list(".")                       // Result<String[], Error>: the names, sorted
Dir::current()                       // Result<String, Error>

Env::get("HOME")                     // Option<String>
Env::args()                          // String[]: the arguments, the first is the program

Time::now_ms()   Time::mono_ns()   Time::sleep_ms(100)       // mono_ns only goes forward: for measuring
Random::seed(42)  Random::next()  Random::range(1, 7)  Random::unit()   // 0 <= unit() < 1
```

An `Error` from these has a `kind` (`NotFound`, `Denied`, `Invalid`, `Io`, ...) and a `message` that says what was being done and the system error number.

## Option, Result and ?

A value that may be missing is an `Option<T>` (`Some(value)` or `None`). An operation that may fail is a `Result<T, E>` (`Ok(value)` or
`Err(error)`); `Error` is the usual error: a `kind` (`ErrorKind::NotFound`, `Parse`, `Invalid`, ...) and a `message`.

```jk
Result<int, Error> parse(String s) {
    if s.len == 0 { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "empty text")); }
    return Result<int, Error>::Ok(s.to_int());
}

Result<int, Error> add(String a, String b) {
    int x = parse(a)?;               // an Err goes straight back to the caller, the Ok content is the value
    int y = parse(b)?;
    return Result<int, Error>::Ok(x + y);
}

switch add("20", "22") { ... }       // or  Result<int, Error> r = add(...);  switch r { Result::Ok(v): ...  Result::Err(e): ... }
```

* `expr?` works on the result of a call, in a function that returns the same kind (a `Result` with the same error type, or an `Option`).
  Everything the function owns is freed on the way out. A Result in a variable is taken apart with `switch`.
* Methods: `is_ok()`, `is_err()`, `is_some()`, `is_none()`, `unwrap()` (throws if there is no value), `or(fallback)`.
* `try`/`catch` stays for the cases where throwing is better; use a `Result` when the caller is expected to handle the failure.

## defer

`defer statement;` or `defer { ... }` runs when the block is left: at its end, by `return`, `break` or `continue`, or when a `throw` passes through. The last
`defer` runs first, and it sees the variables as they are at that moment.

```jk
int work(int n) {
    File f = open(path);
    defer f.close();                  // whatever happens below, the file is closed
    defer cout << "leaving, n = " << n << "\n";
    n += 1;
    if n > 5 { return n * 10; }
    return n;
}
```

A deferred statement cannot `return`, nor `break` or `continue` a loop around it.

## Values that free themselves

A struct (or enum) with a method `free(self)` frees what it holds at the end of the block of a variable. Because of that it is **moved**, not copied:
`Box b = a;` empties `a` and `b` holds the value; passing it to a function by value moves it into the function; `return b;` moves it to the caller;
a call that returns one gives a fresh value. A value can only come from a call or from a local variable (use a pointer for the rest), and its
`free` must work on an emptied (all zero) value. A data enum whose members hold a String, an array or such a struct gets its `free` by itself.
In a `switch`, the name of a member that frees itself is a pointer to it (used like the struct: `e.message`).

## Lambdas

A lambda is a function without a name, written where you use it. It looks like a function declaration without the name (the result type first, then the parameters):

```jk
int apply(int(int, int)^ f, int x, int y) { return f(x, y); }

cout << apply(int(int a, int b) { return a + b; }, 3, 4) << "\n";      // 7
int(int)^ twice = int(int x) { return x * 2; };                         // keep it in a function pointer
void()^ hello = void() { cout << "hi\n"; };
```

A lambda is an ordinary function in disguise (the compiler names it `__lambda_N`), so it **cannot use the variables around it**; it can use
globals and its parameters. A lambda inside a lambda is fine.

## Structs and methods

```jk
struct Counter {
    int n;
    void init(self) { self.n = 0; }          // init runs when a variable is created
    void add(self, int d) { self.n += d; }
    int get(self) { return self.n; }
    static int twice(int v) { return v * 2; }
}

void main() {
    Counter c;
    c.add(5);
    Counter d = {7};                         // brace init: init() does not run
    d.add(1);
    cout << c.get() << " " << d.get() << " " << Counter::twice(21) << "\n";
}
```

Fields are laid out like C (naturally aligned). Structs nest, can hold arrays, can be copied
with `=`, passed and returned by value. `static` functions are called as `Struct::name(...)`,
instance methods as `object.name(...)`; mixing them up is an error.

## Inheritance, virtual methods and interfaces (`itf`)

A struct can have one base: `struct Dog : Animal { ... }`. The fields of the base come first, and a pointer to a `Dog` goes where an `Animal^` is wanted.
A method marked `virtual` is chosen when the program runs; a derived struct changes it with `override`. A struct with virtual methods needs its own
`void init(self) { }` (call it once on every object: it sets the pointer to the table of the methods). Call a method through a pointer with `p^.name()`.

```jk
struct Animal {
    int legs;
    void init(self) { self.legs = 4; }
    virtual void speak(self) { cout << "..."; }
}
struct Dog : Animal {
    void init(self) { self.legs = 4; }
    override void speak(self) { cout << "Woof"; }
}
void talk(Animal^ a) { a^.speak(); cout << "\n"; }
void main() {
    Dog d; d.init();
    talk(@d);
}
```

An **interface** is written with `itf`: only the methods, no bodies, no fields. A struct says `impl Name` and writes every method (no `override` needed;
a missing one is a compile error). A pointer to the interface takes any struct that implements it:

```jk
itf Shape {
    double area(self);
    void grow(self, double k);
}
struct Sq impl Shape {
    double s;
    void init(self) { }
    double area(self) { return self.s * self.s; }
    void grow(self, double k) { self.s = self.s * k; }
}
struct Rect impl Shape {
    double w;
    double h;
    void init(self) { }
    double area(self) { return self.w * self.h; }
    void grow(self, double k) { self.w = self.w * k; self.h = self.h * k; }
}
double twice(Shape^ a) { a^.grow(2.0); return a^.area(); }
void main() {
    Sq q; q.init(); q.s = 3.0;
    Rect r; r.init(); r.w = 2.0; r.h = 5.0;
    cout << twice(@q) << " " << twice(@r) << "\n";
}
```

In this version a struct has one base **or** one interface (`struct Dog : Animal impl Speaker` is refused with a message; several interfaces are planned). A virtual
method may also be written without a body in a plain struct (`virtual int value(self);`): calling it before a derived struct overrides it stops the program with a message.

## Floats

```jk
void main() {
    double r = 2.5;
    float half = 0.5;
    double area = 3.14159 * r * r;
    int whole = (int)area;               // casts are explicit
    cout << area << " " << whole << " " << half << "\n";
}
```

`cout` prints floats with 6 decimals. Literals such as `3.14`, `1e-3` adapt to `float`/`double`.
Comparisons treat NaN correctly. `%` does not work on floats.

## Errors: try / catch / throw

```jk
int divide(int a, int b) {
    if b == 0 { throw "division by zero"; }
    return a / b;
}

void main() {
    try {
        cout << divide(10, 2) << "\n";
        cout << divide(1, 0) << "\n";
    } catch (e) {
        cout << "error: " << e << "\n";     // e is the text that was thrown
    }
}
```

Only text can be thrown (version 0.1 of the design). A `throw` that no `try` catches prints
`uncaught exception: <text>` to stderr and the program exits with code 1. `return`, `break`
and `continue` may leave a `try` block. Up to 24 `try` blocks can be open at once.

**Bugs are not exceptions.** Dividing by zero, using a null or freed array/String, a position out of range (`insert`, `remove`, `slice`), `pop` of an empty
list, `unwrap` of a `None`/`Err`, a function that ends without `return`, running out of memory: the program prints `panic: <what>` and stops with exit
code 134. `try`/`catch` cannot catch it (the program is wrong, not the data). `panic("text")` and `assert(condition, "text")` (std) do the same.
Failures that data can cause (`to_int` of bad text, input that is not a number, `Map.get` of a missing key) still throw; `Map.try_get(k)` gives an `Option`.

When a `throw` leaves functions, what they owned is freed on the way (arrays, Strings, `alloc` blocks, Strings made inside a statement, and structs
with `free(self)`), innermost first. Nothing leaks.

## sizeof

```jk
struct Node { int value; Node^ next; }

void main() {
    int a[10];
    cout << sizeof(int) << " " << sizeof(Node) << " " << sizeof(a) << " " << sizeof(a[0]) << "\n";   // 8 16 80 8
}
```

`sizeof(Type)` or `sizeof(variable / element / field)` is a constant known at compile time
(in bytes, an `int`). Struct sizes include padding. Handy with the heap: `alloc(sizeof(Node))`.

## Input: cin

```jk
void main() {
    int age;
    char name[16];
    double height;
    cin >> name >> age;               // words are separated by spaces or new lines
    cin >> height;
    cout << name << " " << age << "\n";
    cout << height << "\n";
}
```

What is read follows the type of the variable: a whole number for `int`, `i8`, `i32`, `u8`, `u32`, `u64` (checked
against the range of the type), one character for `char`, a word for a `char` array (a longer word is cut and a
warning goes to stderr), a decimal number for `float`/`double`. Anything else is a compile error.
Bad input throws text you can catch: `invalid input`, `number out of range`, `end of input`.

```jk
void main() {
    int n;
    try { cin >> n; } catch (e) { cout << "not a number: " << e << "\n"; }
}
```

## Threads and locks

```jk
#import <stdlib>
using stdlib;
#import <cpu>
using cpu::thread;
using cpu::mutex;

int counter;
Mutex mu;

void work(void^ arg) {                  // a thread runs a function  void f(void^ arg)
    for i in 0..1000 {
        mu.lock();                      // only one thread at a time between lock and unlock
        counter += 1;
        mu.unlock();
    }
}

void main() {
    Thread t1 = create(work, null);     // start two threads
    Thread t2 = create(work, null);
    t1.join();                          // wait until a thread has ended
    t2.join();
    cout << counter << "\n";            // 2000
}
```

`create(function, argument)` starts a thread; the argument is a `void^` (pass `@variable` or `(void^)number`;
cast it back inside: `(char^)arg`, `(int)arg`). `t.join()` waits for the end, `t.detach()` lets it run alone (it cannot be joined
afterwards), `t.is_running()` asks. `Thread::sleep(ms)`, `Thread::yield()` and `Thread::id()` are there too.
A `Mutex` has `lock()`, `unlock()` and `try_lock()`; unlock it yourself on every way out of the section.
Every thread has its own stack (1 MB), its own `try`/`catch` state, and shares globals and the heap (the heap is
protected by a lock). An exception that no `catch` of the thread handles ends the whole program. The program also ends when
`main` ends, even if other threads are still running.

### `#multithread` loops

```jk
int squares[1000];

void main() {
    int offset = 5;
    #multithread
    for i in 0..1000 {                  // the iterations are shared among the machine's cores
        squares[i] = i * i + offset;    // every iteration must be independent of the others
    }
    cout << squares[999] << "\n";       // 998006
}
```

Put `#multithread` on the line before a `for i in a..b` loop. The range is worked out first, split into one part per core
(at most 16), and each part runs on its own thread; the loop ends when all of them have finished. The body can read and write the
variables of the function around it and globals (you must make sure no two iterations touch the same data, or use a `Mutex`).
Not allowed inside the body: `break`, `return`, and another `#multithread`.

## Modules

```jk
#import "mylib"            // your own file: mylib.j (or mylib.jk) next to this file, then the -I folder; "dir.mylib" = dir/mylib.j
#import <stdlib>           // a library: the standard library (built in)
#import <cpu>              // a library: threads and locks (built in)
#import <greet>            // a library found by name (see below)
using stdlib::str         // call only the Str functions without the prefix (using stdlib: all modules)
```

`#import <name>` looks for `name.j` (or `name.jk`, or `name/name.j`) in these places, in this order: the `-I` folder, the folders of the
environment variable `J2K_PATH` (separated by `:`), `~/.j2k/lib`, and the `lib` folder next to the compiler. `<a.b>` means `a/b`.
The library used to be called `std`; `import std` and `using std` still work with a warning. Write `#import` (with the `#`): a plain `import` and a bare `import stdlib` (without `< >`) also work, with a warning. `coutf` and `cinf` of older versions still work with a warning: `cout` and `cin` handle every type.

Standard library (`stdlib`, source in `std/`): 

| Struct | Functions |
|--------|-----------|
| `Sys`  | `exit argc arg open close read write mmap munmap` |
| `Mem`  | `alloc(n)` `free(p)` `set` `copy`  (a heap built on `mmap`) |
| `Str`  | `len eq cmp copy append find starts_with to_int from_int` |
| `Math` | floats: `abs min max sqrt floor ceil trunc round sign clamp lerp fmod hypot cbrt`, `pow(x, y)`, `powi(x, n)`, `exp log log2 log10`, `sin cos tan asin acos atan atan2 sinh cosh tanh`, `radians degrees`, `pi() tau() e() inf() nan() is_nan() is_inf()`; ints: `iabs imin imax ipow` |
| `File` | `File::open(path, FileMode::Read)` `read` `write` `read_line` `close` |

```jk
#import <stdlib>
using stdlib::str;

void main() {
    char buf[32];
    from_int(@buf, 32, 12345);
    cout << buf << " has " << len(@buf) << " digits\n";
}
```

### `Sys`: the system, by names

A program talks to the operating system through `Sys`, which has a named function for each call: `Sys::open_read(path)`, `open_write`, `open_append`, `close`, `read`, `write`, `lseek`, `stat`,
`rename`, `unlink`, `mkdir`, `rmdir`, `getdents`, `pipe`, `fork`, `execve`, `wait`, `kill`, `clock_gettime`, `sleep_ms`, `random`, `mmap`, `munmap`, sockets (`socket_tcp`, `bind`, `listen`, `connect`, `accept`) and more.
They return what the kernel returns (a number, or a negative error: `Error::reason(n)` says it in words) and refuse arguments that would make the kernel touch a wrong place (a null buffer, a negative size, a signal to a whole group of processes)
without calling it. The numbers of the system calls are in `Sys` only, so a port to another machine changes one file.

```jk
#import <stdlib>

void main() {
    int fd = Sys::open_write("/tmp/sys_example.txt");
    Sys::write(fd, "hello\n".c(), 6);
    Sys::close(fd);
    cout << Error::reason(Sys::open_read("/tmp/there_is_no_such_file")) << "\n";
}
```

The raw `syscall(number, ...)` still works (it is what `Sys` is made of), but a program that uses it gets a warning (an error with `-st`): `Sys::call(number, ...)` is the way for a call that `Sys` does not have yet, and
`#allow syscall` at the top of a low level program says that the numbers are meant. `argc()` and `arg(i)` are for the standard library; programs use `Sys::argc()` and `Sys::arg(i)` or `Env::args()`.

## Messages

```
test.jk:3:15: error: type mismatch: expected bool, got a number (use a comparison for a bool, or a cast)
    bool b = n;
              ^
```

Warnings look the same with `warning:` and a `[-Wname]` tag; `-st` turns them into errors.
Current warnings: `-Wswitch`, `-Wlarge-by-value` (a struct over 64 bytes passed by value),
`-Wstatic-struct` (a variable of a struct that has no fields).

## Planned, not built yet

thread pools.

## Debug build

`jcmp prog.jk -d -o prog` checks every array index (fixed arrays of any dimension, arrays
in structs, array parameters). A bad index stops the program:

```
runtime error: index out of bounds, array size is 5
```

and the exit code is 134. Pointer indexing (`p[i]`) cannot be checked: a pointer does not know its size.

## Operator methods and the math libraries

A struct can say which of its methods an operator calls: write the word `operator` in front of the method. The names are fixed:
`+` calls `add`, `-` calls `sub`, `*` calls `mul`, `/` calls `div`, `==` and `!=` call `eq`, a minus in front (`-v`) calls `neg`.
`a += b` (and `-= *= /=`) means `a = a.add(b)`. A method without the word `operator` is never called by an operator.

```jk
struct Money {
    int cents;
    operator Money add(self, Money o) { Money r = {self.cents + o.cents}; return r; }
    operator Money mul(self, int k)   { Money r = {self.cents * k}; return r; }
    operator bool eq(self, Money o)   { return self.cents == o.cents; }
}
Money a = {250};
Money b = a + a * 3;             // a.add(a.mul(3))
Money c = 2 * a;                 // a number on the left of * is the same as a.mul(2)
cout << (a + b).cents << "\n";   // a call can go on after a value in parentheses
```

The math libraries are chosen with one import: `#import <math>` and then `using math::vector;` (`vec2 vec3 vec4`) or `using math::matrix;`
(`mat3 mat4`, with vector) or `using math::quat;` (rotations), `using math::complex;` (`cplx`), `using math::stats;` (`Stats`), or `using math;` (everything). A vector can be written `vec p = {1.0, 2.0, 3.0};` (the number of values says
`vec3`) and its parts can be picked with letters: `p.xy`, `p.zyx`, `c.rgb` (several letters: a new vector, read only; one letter:
the part itself, which can be assigned). The graphics library: `#import <gfx>` and `using gfx::canvas;` (characters, with a depth
buffer) or `using gfx::screen;` (colour dots). The standard library has `Term::cols()`, `Term::rows()` and `Term::key_pressed()`.

## The standard library at a glance

```jk
#import <stdlib>
using stdlib;

void main() {
    // text and numbers
    String s = "  Hello, J2K  ";
    cout << s.trim().upper() << " " << s.trim().count() << "\n";         // HELLO, J2K 10
    // Num::parse_int("42") and Num::parse_double("2.5") give a Result (see the Option, Result and ? section)
    // files, folders, the environment, time and random numbers
    //   Fs::read_text(path)?  Fs::write_text(path, text)?  Dir::list(path)?  Env::get("HOME")  Time::now_ms()  Random::range(1, 6)
    // data
    //   Json::parse(text)? (a JsonDoc: root get at len text number dump)     Sha256::hex(text)   Sha256::file(path)?
    //   Hex::encode / decode   Base64::encode / decode   Path::join name parent ext stem
    // other programs
    //   int code = Proc::run("ls", args)?     String out = Proc::output("echo", args)?
    // the terminal
    //   Term::cols()  Term::rows()  Term::key_pressed()
}
```

Collections: `List<T>` (`push pop len ...`), `Map<K, V>` (`put get try_get remove keys_list`), `Set<T>`. Strings compare with `== != < > <= >=`
(by the codes of the bytes); `s.count()` counts characters, `s.chars()` gives them one by one, `upper()` and `lower()` know Latin, Greek and Cyrillic.

A loop over a range takes numbers or variables: `for i in 0..n`, `for i in lo..hi`, `for i in lo + 1..hi + 1`.


## The raw mode: `#!library`

A file that has the line `#!library` is a raw file (owner's marker, `docs/syntax-design.md` 66): the compiler adds nothing - no start code, no helpers, no runtime, no `main`. The first instruction of the first function is the entry of the program; every function is written. Use `naked` functions and the low level statements (see above); `exit` is a system call you write yourself:

```
#!library
naked void start() {
    Reg::x0 = 7;
    Reg::x8 = 93;
    svc(0);
}
```

The program is 12 bytes of code after the 176 bytes of the ELF header. An unknown marker (`#!banana`) is an error.

## Fused multiply-add (0.9.113)

`a * b + c`, `c - a * b` and `a * b - c` with doubles are made with one instruction (`fmadd`, `fmsub`, `fnmsub`) when the product is used by that
addition only: it is as fast as C (clang does the same) and the result has one rounding instead of two, so its last bit can differ from a machine
without FMA or from the same program with `-nofma`, which keeps the two roundings. No new syntax: the code you write does not change.

## `a[lo..hi]`: a view of a part of an array (0.9.114)

```jk
int[] a = arr(8);   // 10 20 30 40 50 60
Span<int> s = a[1..5];          // 20 30 40 50: no copy, `s.get(i)`, `s.set(i, x)`, `s.len`, `s.sub(lo, hi)`, `s.to_array()`
int total(Span<int> v) { ... }
total(a[2..4]);
```
`a[lo..hi]` is written `span(a, lo, hi)` by the compiler (a name directly followed by brackets that have `..` in them, on one line); `lo` and `hi`
can be expressions. A view does not own the memory and is checked when it is used (`span index out of range`). It works for dynamic arrays
(`T[]`); for a String use `s.slice(a, b)`.

## `raw<type>[values];`: bytes as they are written (0.9.115)

In a naked function, a register block or a `_.name { }` block:

```jk
raw<u32>[0xd503201f];                    // one instruction word (nop)
raw<u8>[0x1f, 0x20, 0x03, 0xd5];         // the same four bytes (little endian)
raw<u16>[0x201f, 0xd503];                // the same, as half words
raw<u64>[0x1100000011000000];            // two words
```
The type is `u8`, `u16`, `u32` or `u64`; a value that does not fit is an error. The assembler works in 4-byte words, so a group that does not fill
the last word is padded with zeros. A function with a raw word is opaque to the passes (as every register block is).

## `#pragma read`: data that must not change (0.9.116)

```jk
#pragma read                    // the next global variable only
int limit = 100;

#pragma read begin              // every global variable up to `end`
int table[4] = {10, 20, 30, 40};
int scale = 3;
#pragma read end
```
`#pragma read` as the very first thing of a file makes every global variable of that file read-only. (`#pragma readonly` is the same.)
* A direct write (`limit = 1;`, `table[2] = 5;`, `limit += 1;`) is an error at compile time: `this variable is read-only (#pragma read) and cannot be written`.
* The variable has pages of its own and the start code makes them not writable (`mprotect`): a write through a pointer stops the program with the
  segmentation fault message (`... or a write to read-only data`). The cost is 8 KB of address space for each read-only variable.
* Locals cannot be read-only (a local with the pragma is not special); in a `#!library` file there is no start code, so only the compile time check works.

## Libraries that come with jcmp, and libraries you download

The folder `Library` of jcmp holds the libraries that come with it: the standard library (`core number text files system time data crypto net`, all of `#import <stdlib>`), `math` (with `vector`
and `matrix`) and `cpu`. The others are **downloaded when you need them** with [jget](https://github.com/J2k-studio/Jcmp-Tools): `simd` (`#import <simd>`), `quat`, `complex`, `stats`
(`using math::quat;` ...) and `canvas`, `screen` (`#import <gfx>`, `using gfx::canvas;`): `jc lib install simd`, `jc lib install gfx`. A program that imports a library that is not installed gets the message
`the library 'simd' is not installed` with that command. They are put in `~/.j2k/Library`, where the compiler looks (and in the folders of `J2K_PATH`).

## `#import <simd>`: vector types, step S1 (0.9.117)

```jk
#import <simd>
f64x2 a = {1.5, 2.5};                 // two doubles:            a.x  a.y
i64x2 n = {7, 8};                     // two 64-bit numbers:     n.x  n.y
f32x4 f = {1.0, 2.0, 3.0, 4.0};       // four floats:            f.x f.y f.z f.w
i32x4 m = {10, 20, 30, 40};           // four 32-bit numbers:    m.x m.y m.z m.w
```
The types are 16 bytes (the size of a 128-bit NEON register); the lanes are named like the parts of `vec3`. This is the first step of
`docs/syntax-design.md` 59.

The operators `+ - * /` (and `+= -= *= /=`) are one NEON instruction on the whole value (0.9.118):
```jk
f64x2 c = a + b * 2.0;          // a number on the right (or on the left of *) is used for every lane
i32x4 k = m * m + m;
```
`/` needs a float type; `i64x2` has no `*`; both sides must be the same type (or a number).

Loads and stores of arrays (0.9.120): one 16-byte access at the element `i`:
```jk
double a[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
f64x2 v = f64x2::load(@a[0], 2);        // a[2], a[3]
v.store(@a[0], 4);                        // a[4] = v.x, a[5] = v.y
```
(`f64x2` and `i64x2` take an element of 8 bytes, `f32x4` (`float^`) and `i32x4` (`i32^`) of 4 bytes.) In a loop the vectors stay in NEON registers. `v.sum()`, `v.min()` and `v.max()` (0.9.121) give the sum, the smallest and the largest lane (`sum()` of four lanes is `(x + y) + (z + w)`).



## Looking at the code, and keeping it short

`jcmp program.jk -show NAME` writes the code that was made for the function `NAME` and how many instructions it has. `#expect` in front of a
function makes the compiler stop when the function grows past a limit:

```jk
#expect instructions <= 12
int twice(int x) {
    return x + x;
}

void main() {
    cout << twice(21) << "\n";
}
```

The count is for ARM64 (the function is counted after the optimizer, and a function that is inlined everywhere has no code of its own); `-target arm32` does not check the limits.


## Wide numbers and the flags of the CPU

`Bit` has the steps of arithmetic on numbers that are wider than 64 bits. A function gives one struct (there is no tuple):

```jk
void main() {
    // 128-bit addition of (a_hi, a_lo) + (b_hi, b_lo), word by word
    int a_lo = -1;
    int a_hi = 5;
    BitCarry lo = Bit::add_carry(a_lo, 1, 0);
    BitCarry hi = Bit::add_carry(a_hi, 0, lo.c);
    cout << hi.sum << " " << lo.sum << " " << hi.c << "\n";
    BitWide w = Bit::mul_wide(-1, 3);
    cout << w.hi << " " << w.lo << "\n";
    BitDivRem d = Bit::div_rem(-17, 5);
    cout << d.q << " " << d.r << " " << Bit::add_sat(9223372036854775807, 5) << "\n";
}
```

On ARM64 a `register { }` block can read the flags that an instruction left: `x4 = Flags::c;` (also `z`, `n`, `v`; 0 or 1).


## `cerr`: messages for the standard error

`cerr << ...;` prints like `cout`, but to the standard error. When a program runs as `program > result.txt` the results go to the file and the messages
of `cerr` still appear on the screen. (`cerr` is part of the standard library, like `cout`: `#import <stdlib>`.)

```jk
void main() {
    cout << "result: " << 42 << "\n";
    cerr << "warning: the input was empty\n";
}
```

## What `cout` prints for a `bool` and for a pointer

A `bool` prints as `true` or `false`. A pointer prints as `0x` and its address in hex (`null` as `0x0`); write `(int)p` to print it as a number.

```jk
int main() {
    bool ok = 3 > 2;
    int^ p = null;
    cout << ok << " " << p << nl;
    return 0;
}
```

Output: `true 0x0`.

## Reading the keyboard: `read`

`cin` reads words. For a whole line, one key, or a yes / no question the library has the module `read` (`using Input;`):

```jk
#import <stdlib>
using Input;

void main() {
    cout << "name? ";
    String name = read.line();
    int age = read.number();
    cout << name << " is " << age << nl;
    if read.yes("again?") { cout << "ok" << nl; }
}
```

`read.key()` waits for one key without Enter and without showing it; it gives the code of the key (letters are their codes, Escape 27; 257 up, 258 down, 259 right, 260 left, 261 Home, 262 End, 263 Delete, 264 PageUp, 265 PageDown, 266 Insert, 270 .. 273 F1 .. F4; -1 at the end of the input). `read.key_timeout(ms)` waits at most that long and gives -2 when no key came. `read.password()` reads a line without showing it and `read.decimal()` reads a number with a decimal part. `read.enter()` waits for Enter, `read.try_number()` gives a `Result` instead of throwing. Use `read` or `cin` in one program, not both.

## A variable in a register: `reg<int x19> c`

`reg<int x20> total = 0;` keeps the variable `total` in the register `x20` for the whole function (x18 and x19 .. x25 are allowed; the compiler does not use `x18` itself). It is the same as the older form `int total @ x20 = 0;`. Only whole numbers, pointers, `bool`, `char` and enums can live in a register.

```jk
int sq(int v) { return v * v; }

int main() {
    reg<int x20> acc = 0;
    for i in 0..5 { acc += sq(i); }
    cout << acc << "\n";
    return 0;
}
```

The program prints `30`.

## Prefetch, the speculation barrier and the CRC instructions

`Cache::prefetch(@a[i + 8]);` tells the CPU that the line at that address is wanted soon (a hint: it never fails, and `null` is allowed). `Cpu::speculation_barrier();` stops the CPU from running instructions ahead of the branches before it (the defence against Spectre-type attacks).

The CRC32 instructions are an extension that not every ARMv8 CPU has, so a program says that it needs them: `#require cpu "crc32"` at the top of the file. Then `Cpu::crc32(crc, data)` (8 bytes at once), `Cpu::crc32_u8(crc, byte)` and the `crc32c` forms (the Castagnoli polynomial) work. Start with `crc = 0xFFFFFFFF` and flip the bits at the end. Without the directive a call is a compile error; on `-target arm32` the directive is an error (ARMv7 has no such instruction).

```jk
#require cpu "crc32"
#import <stdlib>
using stdlib;

void main() {
    char^ text = "123456789";
    int crc = 0xFFFFFFFF;
    for i in 0..9 { crc = Cpu::crc32_u8(crc, text[i] & 255); }
    cout << ((crc xor 0xFFFFFFFF) & 0xFFFFFFFF) << "\n";
}
```

The program prints `3421780262` (the same number as zlib's `crc32`).

### OpenGL, Vulkan and the libraries of the system: no flag

A program that says `#import <native>` (and so `#import <opengl3>` or `#import <vulkan>`, which import it) is built by jcmp as a dynamic executable by itself: it gets `libc.so` and `libdl.so` from the loader of Android and can call the C functions of the phone (`jcmp -dyn` before; it still works). A shared library built with `-l` needs no flag either: it uses the libraries of the process that loads it. In a game that is an Android app, the app (a `GLSurfaceView`) owns the OpenGL ES context and calls the exported functions of the game on its GL thread; the game then says `Gl gl = Gl::attach(w, h);` and draws on that context.

## Shared libraries: `export` and `-l`

A file that has no `main` and whose functions are marked `export` can be built as a **shared library** that a C program, an Android app (through JNI, `System.loadLibrary`) or python (`ctypes`) loads:

```jk-no
export int add(int a, int b) { return a + b; }
export double half(double x) { return x / 2.0; }

int counter = 10;                       // a variable of the library: it gets its first value when the library is loaded
export int next() { counter = counter + 1; return counter; }
```

```
jcmp mylib.jk -l -o libmy.so
```

* An `export` function follows the calling rules of the platform (AAPCS64 on ARM64): integers in `x0 ..`, a `double` in `d0 ..`, the result in `x0` or `d0`. The name of the entry is the name of the function.
* Parameters and result: `int`, `bool`, `char`, `float`, `double` and pointers (`int^`, `char^`, `double^`: a buffer that the caller owns), at most 8 parameters. (String, arrays and structs come later; the compiler says so when you use them.)
* For Java (JNI) write the name that Java looks for: `export int Java_com_example_Core_add(int env, int cls, int a, int b)` is `static native int add(int a, int b)` of the class `com.example.Core`.
* The library has its own global variables, its own heap and its own `String`s and arrays inside; they never cross its border yet.
* The functions that are not marked `export` stay inside (and are not in the file if no exported function reaches them).
* Try it from python: `ctypes.CDLL('./libmy.so').add(2, 3)` is 5.
* Not yet: `cout` inside a library, ARM32, and a library that calls another library. The test `t502` in the repository loads a library the way a C program does.


## A root like an OS (JARIC_ROOT)
A phone does not let an app make `/bin` or `/etc`. A program made by jcmp can still see them: set the environment variable `JARIC_ROOT` to a folder (the Jaric app sets it to its files folder) and the paths that begin with `/` are read inside that folder when their first name is a folder there:
```
JARIC_ROOT=/data/data/com.jaric.app/files
Fs::read_text("/etc/motd")       // files/etc/motd
Sys::chdir("/");  Sys::getcwd    // "/" (the folder files/ shown as /)
Fs::exists("/u/DCIM")            // /sdcard/DCIM (/u is the storage of the user)
Fs::exists("/proc/version")      // the real one: /proc /dev /sys /sdcard /storage /data /system ... are never hidden
```
It works for everything that goes through `Sys` (Fs, Dir, Proc, jsh, jbox, your programs). Programs of other makers (Python, git of Termux) do not know it and use real paths. Without `JARIC_ROOT` nothing changes. In a shared library (`-l`) there is no environment, so there is no virtual root (and `Env::get` answers "nothing").
