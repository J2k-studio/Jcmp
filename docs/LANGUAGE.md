# A tour of J2K

This is a practical guide to what the compiler accepts **today**. The formal decisions
(and the reasons for them) are in [syntax-design.md](syntax-design.md); things that are
planned but not built are listed at the end.

Files: `.jk` is a program (it has `main`); `.j` is a component that other files `import`
(it may not define `main`).

## Program shape

```jk
#import <stdlib>
using stdlib

void main() {
    cout << "hi\n";
}
```

`cout` and `cin` come with the standard library: a program that uses them starts with `#import <stdlib>` and `using stdlib`
(the snippets below leave these two lines out). Without them the compiler warns `[-Wstd]` for now; a later version makes it an error.
`using stdlib` makes the names of all the std modules usable without the prefix; if two modules have the same name (`write` is in `Sys` and
`File`) the compiler reports it and you write `File::write(...)`. `float` is the 32-bit and `double` the 64-bit decimal type (they were
called `f32` and `f64`; the old names still work with a warning).

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

* Methods: `push(char)`, `pop()`, `append(x)`, `clear()`, `find(x)` (index or -1), `slice(from, to)`, `c()` (the characters as a plain text, valid until the String changes), `len`, `free()`.
* More methods: `trim()`, `upper()`, `lower()` (ASCII letters), `replace(a, b)`, `repeat(n)` (each gives a new String); `starts_with(x)`, `ends_with(x)`, `contains(x)` (true/false);
  `to_int()`, `to_double()` (the whole String must be a number, else it throws `not a number`); `split(sep)` gives a new `String[]` and `join(sep)` on a `String[]` joins it again.
  Methods work on a variable (`t.trim()`), not on a text written in the program (`"abc".trim()`).
* A new String made by an expression (`a + b`, `slice`, a call that returns a String) is a temporary: the compiler frees it at the end of the statement unless it is stored in a variable. It cannot be made on the right of `&&` or `||` (the right side may not run): put it in a variable first.
* `return s;` moves a local String out; returning a parameter or a field copies it. A String parameter only borrows, so it cannot be assigned inside the function.
* A `String` that is a field of a struct or a global is not freed by itself: call `free()`.
* Text is bytes (UTF-8): `len` counts bytes.
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
using stdlib

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
#import <cpu>
using cpu::thread
using cpu::mutex

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
| `Math` | `abs min max sqrt floor ceil trunc pow` (floats), `iabs imin imax ipow` (ints) |
| `File` | `File::open(path, FileMode::Read)` `read` `write` `read_line` `close` |

```jk
#import <stdlib>
using stdlib::str

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

thread pools.

## Debug build

`jcmp prog.jk -d -o prog` checks every array index (fixed arrays of any dimension, arrays
in structs, array parameters). A bad index stops the program:

```
runtime error: index out of bounds, array size is 5
```

and the exit code is 134. Pointer indexing (`p[i]`) cannot be checked: a pointer does not know its size.
