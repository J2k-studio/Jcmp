# A tour of J2K

This is a practical guide to what the compiler accepts **today**. The formal decisions
(and the reasons for them) are in [syntax-design.md](syntax-design.md); things that are
planned but not built are listed at the end.

Files: `.jk` is a program (it has `main`); `.j` is a component that other files `import`
(it may not define `main`).

## Program shape

```jk
void main() {
    cout << "hi\n";
}
```

`main` may be `void main()` or `int main()` (the returned number is the exit code).
Statements end with `;`. Blocks use `{ }` and are always required. `//` and `/* */` are comments.

## Types

| Type    | Meaning                                  |
|---------|------------------------------------------|
| `int`   | 64-bit signed integer                    |
| `i32`, `i8` | 32 / 8-bit signed integers           |
| `char`  | 8-bit **unsigned** (a byte / character)  |
| `bool`  | `true` / `false` (1 byte)                |
| `u8`, `u32`, `u64` | unsigned integers (8 / 32 / 64 bit) |
| `f64`, `f32` | floating point                      |
| `T^`    | pointer to `T`  (`void^` = pointer to anything) |

Rules that catch bugs early:

* `bool` is not a number: `if x` with an `int` is an error — write `if x != 0`.
* Enums are not numbers; floats and integers do not mix: `(f64)n`, `(int)x`.
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

Constants: `#define MAX 100` (text substitution; defined before use).

## Control flow

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

## Arrays and strings

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
    char path[] = r"C:\raw\string";  // raw string: no escapes
    cout << sum(v) << " " << grid[1][2] << " " << name << " " << path << "\n";
    cout << v.len << "\n";           // 5
}
```

Strings are `char` arrays ending in 0. Escapes: `\n \t \r \0 \\ \" \'`.
`cout` prints a char array as text, a `char` as a character, and anything else as a number.
`cout << x;` with a single number prints a newline after it; in a chain
(`cout << a << b;`) you write `"\n"` yourself. Floats are printed with `coutf`.

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

## Heap memory that frees itself

```jk
import std
using std::mem

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
Warnings: `-Wleak` (the result of `alloc` is thrown away), `-Wmoved` (a moved variable is used again).
Limits: a `throw` that leaves a block does not free that block's memory, and memory kept by a pointer that is
assigned after its declaration is not tracked (use a declaration, or free it yourself).
A `-d` build reports at the end of `main` how many blocks were never freed.

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

## Floats

```jk
void main() {
    f64 r = 2.5;
    f32 half = 0.5;
    f64 area = 3.14159 * r * r;
    int whole = (int)area;               // casts are explicit
    coutf << area << " " << whole << " " << half << "\n";
}
```

`coutf` prints floats with 6 decimals. Literals such as `3.14`, `1e-3` adapt to `f32`/`f64`.
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
and `continue` may leave a `try` block. Up to 32 `try` blocks can be open at once.

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

## Input: cin and cinf

```jk
void main() {
    int age;
    char name[16];
    f64 height;
    cin >> name >> age;               // words are separated by spaces or new lines
    cinf >> height;
    cout << name << " " << age << "\n";
    coutf << height << "\n";
}
```

What is read follows the type of the variable: a whole number for `int`, `i8`, `i32`, `u8`, `u32`, `u64` (checked
against the range of the type), one character for `char`, a word for a `char` array (a longer word is cut and a
warning goes to stderr), a decimal number for `f32`/`f64` with `cinf`. Anything else is a compile error.
Bad input throws text you can catch: `invalid input`, `number out of range`, `end of input`.

```jk
void main() {
    int n;
    try { cin >> n; } catch (e) { cout << "not a number: " << e << "\n"; }
}
```

## Modules

```jk
import "mylib"            // mylib.j (or mylib.jk) next to this file; "dir.mylib" = dir/mylib.j
import std                // the standard library
using std::str            // call Str functions without the prefix  (or: using std)
```

Standard library (`std/`): 

| Struct | Functions |
|--------|-----------|
| `Sys`  | `exit argc arg open close read write mmap munmap` |
| `Mem`  | `alloc(n)` `free(p)` `set` `copy`  (a heap built on `mmap`) |
| `Str`  | `len eq cmp copy append find starts_with to_int from_int` |
| `Math` | `abs min max sqrt floor ceil trunc pow` (floats), `iabs imin imax ipow` (ints) |
| `File` | `File::open(path, FileMode::Read)` `read` `write` `read_line` `close` |

```jk
import std
using std::str

void main() {
    char buf[32];
    from_int(@buf, 32, 12345);
    cout << buf << " has " << len(@buf) << " digits\n";
}
```

The raw `syscall(...)`, `argc()`, `arg(i)` exist for the standard library; programs should use `Sys`.

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

threads/`Mutex`.

## Debug build

`jcmp prog.jk -d -o prog` checks every array index (fixed arrays of any dimension, arrays
in structs, array parameters). A bad index stops the program:

```
runtime error: index out of bounds, array size is 5
```

and the exit code is 134. Pointer indexing (`p[i]`) cannot be checked: a pointer does not know its size.
