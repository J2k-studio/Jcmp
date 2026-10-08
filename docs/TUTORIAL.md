# Learn J2K: a step-by-step tutorial

This tutorial teaches the language by small programs. Each program was compiled and run to produce the output you see.
You need the compiler (see the README: `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`).
Type a program into a file such as `hello.jk`, then:

```bash
jcmp hello.jk -o hello      # compile
./hello                     # run
```

For the complete list of features see [LANGUAGE.md](LANGUAGE.md); for the command line see [USAGE.md](USAGE.md).

## Contents

1. Hello, world
2. Numbers and variables
3. Making decisions
4. Loops
5. Functions
6. Arrays and text
7. Reading input
8. Structs and methods
9. Enums and switch
10. Pointers
11. Growing arrays and memory
12. Strings
13. Generics
14. Lists, maps and sets
15. Lambdas
16. Errors with try and catch
17. Decimals and the Math library
18. Files
19. A program in several files
20. A small project: counting words

## Lesson 1. Hello, world

Every program starts at `main`. `cout <<` prints; `\n` is a new line. Save this as `hello.jk`.

```jk
#import <stdlib>
using stdlib

void main() {
    cout << "Hello, J2K!\n";
}
```

Output:

```
Hello, J2K!
```

Compile and run: `jcmp hello.jk -o hello` then `./hello`. If you made a typo, the compiler tells you the file, line and column
and shows the line with a `^` under the problem.
**Try:** print your own name.

## Lesson 2. Numbers and variables

A variable has a type: `int` (whole number, 64 bit), `double` (decimal), `char` (one character), `bool` (true or false).
`cout` prints decimals too. Lines end with `;`.

```jk
#import <stdlib>
using stdlib

void main() {
    int apples = 5;
    int pears = 3;
    int total = apples + pears;
    cout << "total = " << total << "\n";

    double price = 2.5;
    cout << "cost = " << price * 4.0 << "\n";

    char letter = 'J';
    cout << letter << "\n";

    bool enough = total > 7;
    if enough { cout << "enough fruit\n"; }
}
```

Output:

```
total = 8
cost = 10.000000
J
enough fruit
```

A `bool` is not a number: `if total` is an error, write `if total != 0`. Likewise `int` and `double` do not mix without a cast:
`(double)total`.

## Lesson 3. Making decisions

`if`, `else if`, `else` choose what to run. Conditions use `== != < > <= >=` and `&&` (and), `||` (or), `!` (not). Braces are always needed.

```jk
#import <stdlib>
using stdlib

void main() {
    int score = 72;
    if score >= 90 {
        cout << "A\n";
    } else if score >= 70 {
        cout << "B\n";
    } else {
        cout << "C\n";
    }
    bool passed = score >= 50 && score <= 100;
    if passed { cout << "passed\n"; }
}
```

Output:

```
B
passed
```

**Try:** change `score` and see which letter you get.

## Lesson 4. Loops

`while` repeats while a condition is true. `for i in a..b` counts from `a` up to `b - 1`. The C-style `for` is also there.
`break` leaves a loop, `continue` skips to the next round.

```jk
#import <stdlib>
using stdlib

void main() {
    int i = 1;
    while i <= 3 {
        cout << i << " ";
        i++;
    }
    cout << "\n";

    for k in 0..5 { cout << k * k << " "; }
    cout << "\n";

    for int j = 10; j > 0; j -= 3 { cout << j << " "; }
    cout << "\n";
}
```

Output:

```
1 2 3 
0 1 4 9 16 
10 7 4 1 
```

**Try:** print the multiplication table of 7.

## Lesson 5. Functions

A function has a result type, a name and parameters. `void` means no result. A function can be written below the place that uses it.

```jk
#import <stdlib>
using stdlib

void main() {
    cout << square(7) << "\n";
    cout << sum_to(10) << "\n";
    greet("Ann");
}

int square(int x) {
    return x * x;
}

int sum_to(int n) {
    int s = 0;
    for i in 1..n + 1 { s += i; }
    return s;
}

void greet(char^ name) {
    cout << "Hello, " << name << "!\n";
}
```

Output:

```
49
55
Hello, Ann!
```

`char^` means "pointer to characters": that is how text is passed to a function.

## Lesson 6. Arrays and text

`int scores[5]` is five numbers, counted from 0. `scores.len` is its length. Text is an array of `char` that ends with a 0;
`char word[] = "banana"` sizes it for you. Arrays can have up to three dimensions: `int grid[2][3]`.

```jk
#import <stdlib>
using stdlib

void main() {
    int scores[5];
    for i in 0..5 { scores[i] = (i + 1) * 10; }
    int total = 0;
    for i in 0..scores.len { total += scores[i]; }
    cout << "total " << total << "\n";

    char word[] = "banana";
    int count = 0;
    for i in 0..word.len {
        if word[i] == 'a' { count++; }
    }
    cout << word << " has " << count << " letter a\n";

    int grid[2][3];
    for r in 0..2 {
        for c in 0..3 { grid[r][c] = r * 3 + c; }
    }
    cout << grid[1][2] << "\n";
}
```

Output:

```
total 150
banana has 3 letter a
5
```

Build with `jcmp prog.jk -d -o prog` to stop with a message when an index is outside the array.

## Lesson 7. Reading input

`cin >> a >> b;` reads words from the keyboard. The type of the variable decides what is read: a number for `int`,
a word for a `char` array. `cin` reads decimals too. Words are separated by spaces or new lines.

```jk
#import <stdlib>
using stdlib

void main() {
    char name[20];
    int age;
    cin >> name >> age;
    cout << name << " will be " << age + 1 << " next year\n";
}
```

Input: `Ann 30`

Output:

```
Ann will be 31 next year
```

Run it and type `Ann 30` (or pipe it in: `echo "Ann 30" | ./input`). Bad input throws an error you can catch (lesson 12).

## Lesson 8. Structs and methods

A `struct` groups values. Functions inside it are methods; they receive the object as `self`. `Rect r = {3, 4};` fills the fields in order.

```jk
#import <stdlib>
using stdlib

struct Rect {
    int w;
    int h;

    int area(self) {
        return self.w * self.h;
    }

    void grow(self, int d) {
        self.w += d;
        self.h += d;
    }
}

void main() {
    Rect r = {3, 4};
    cout << r.area() << "\n";
    r.grow(1);
    cout << r.w << "x" << r.h << " area " << r.area() << "\n";
}
```

Output:

```
12
4x5 area 20
```

A method called `init(self)` runs automatically when a variable is created without `{ ... }`. `static` functions have no `self` and are
called as `Rect::name(...)`.

## Lesson 9. Enums and switch

An `enum class` is a list of named values. `switch` picks the case that matches, with no fall-through; `_` is "anything else".
An enum is not a number, so you cannot mix them up by accident.

```jk
#import <stdlib>
using stdlib

enum class Light { Red, Yellow, Green };

void say(Light l) {
    switch l {
        Light::Red: cout << "stop\n";
        Light::Yellow: cout << "slow down\n";
        Light::Green: cout << "go\n";
    }
}

void main() {
    say(Light::Green);
    say(Light::Red);

    int n = 3;
    switch n {
        1, 2: cout << "small\n";
        3: cout << "three\n";
        _: cout << "other\n";
    }
}
```

Output:

```
go
stop
three
```

If a `switch` on an enum forgets a member, the compiler warns you (use `-st` to make warnings errors).

## Lesson 10. Pointers

`@x` is the address of `x`. `int^ p` is a pointer to an int; `p^` is the value it points to. A pointer lets a function change its caller's variable.
`p[i]` reaches the i-th element (there is no `p + 1`).

```jk
#import <stdlib>
using stdlib

void bump(int^ p) {
    p^ = p^ + 1;
}

void main() {
    int n = 5;
    bump(@n);
    bump(@n);
    cout << n << "\n";

    int a[3];
    a[0] = 10; a[1] = 20; a[2] = 30;
    int^ q = @a;
    cout << q[1] << "\n";
}
```

Output:

```
7
20
```

## Lesson 11. Growing arrays and memory

`int[] list = arr(4)` is a dynamic array: it starts empty and grows with `push`. `alloc(n)` gives raw memory. The compiler frees what a
local variable made with `arr` or `alloc` at the end of the block, so you rarely call `free` yourself.

```jk
#import <stdlib>

using stdlib
int total(int[] list) {
    int s = 0;
    for i in 0..list.len { s += list[i]; }
    return s;
}

void main() {
    int[] squares = arr(4);
    for i in 1..6 { squares.push(i * i); }
    cout << squares.len << " items, total " << total(squares) << "\n";

    int^ buffer = (int^)alloc(sizeof(int) * 3);
    buffer[0] = 7;
    buffer[1] = 8;
    buffer[2] = 9;
    cout << buffer[0] + buffer[2] << "\n";
}   // squares and buffer are freed here
```

Output:

```
5 items, total 55
16
```

Handing memory to someone else: `return p;`, storing it in a field, or `move(p)`. A `-d` build tells you at the end how many blocks were never freed.

## Lesson 12. Strings

`String` holds text that can grow. `String s = "hello";` makes a copy of the text; `a + b` joins; `==` compares; `s.len` is the length and `s[i]` one character.
Methods: `push`, `append`, `pop`, `clear`, `find`, `slice(from, to)`, `c()` (the characters as a plain text). `cin >> s` reads one word.
A `String` is freed at the end of its block, and `String b = a;` makes a separate copy.

```jk
#import <stdlib>
using stdlib

String shout(String s) {
    String r = s + "!";
    return r;
}

void main() {
    String a = "abc";
    String b = a;
    b.push('d');
    cout << a << " " << b << "\n";

    String line = "Hello, " + shout("Jao");
    cout << line << " (" << line.len << " characters)\n";
    cout << line.find("Jao") << " " << line.slice(0, 5) << "\n";
    if a == "abc" { cout << "same\n"; }
}
```

Output:

```
abc abcd
Hello, Jao! (11 characters)
7 Hello
same
```

A new `String` made by an expression (`a + b`, a call, `slice`) is freed for you at the end of the statement. `s.c()` points into the String: it is valid until you change it.
A String parameter only borrows the caller's String, so inside the function you cannot assign to it.

## Lesson 13. Generics

A function or struct can take a type as a parameter: write it in `<>` after the name. The compiler makes one copy for every type you use.
A function finds the type from its arguments: `largest(3, 9)`; you can also write it, `largest<int>(3, 9)`. A struct always has it written: `Box<double>`.

```jk
#import <stdlib>
using stdlib

T largest<T>(T a, T b) {
    if a > b { return a; }
    return b;
}

struct Box<T> {
    T value;
    T get(self) { return self.value; }
}

void main() {
    cout << largest(3, 9) << "\n";
    cout << largest(2.5, 1.5) << "\n";
    cout << largest<int>(8, 2) << "\n";
    Box<int> b = {7};
    cout << b.get() << "\n";
}
```

Output:

```
9
2.500000
8
7
```

A generic must be written before the first place that uses it. `largest(1, 2.5)` is an error (a whole number and a decimal number do not mix): write `largest(1.0, 2.5)`. When the type cannot be worked out, the compiler says so and you write it.

## Lesson 14. Lists, maps and sets

A list is a dynamic array with more tools: `sort`, `insert`, `remove`, `contains`, `index_of`. `for x in list` visits every element.
`Map<K,V>` stores values by key and `Set<T>` stores each value once. They free themselves at the end of the block.

```jk
#import <stdlib>
using stdlib

void main() {
    int[] scores = arr(4);
    scores.push(72); scores.push(95); scores.push(60);
    scores.sort();
    for s in scores { cout << s << " "; }
    cout << "\n";

    Map<String, int> ages;
    ages.put("ann", 31);
    ages.put("bob", 25);
    ages.put("ann", 32);
    cout << ages.get("ann") << " " << ages.len << "\n";
    for name in ages.keys_list() {
        cout << name << " is " << ages.get(name) << "\n";
    }

    Set<int> seen;
    for i in 0..20 { seen.add(i % 5); }
    cout << seen.len << " different, has 3: " << seen.has(3) << "\n";
}
```

Output:

```
60 72 95 
32 2
ann is 32
bob is 25
5 different, has 3: 1
```

`ages.get("zed")` would throw `key not found`; ask with `ages.has("zed")` first. `keys_list()` makes a new list that the `for` loop frees for you.

## Lesson 15. Lambdas

A lambda is a small function written right where you need it: `int(int a, int b) { return a + b; }`. It can be passed to a function that takes a function
pointer, or kept in a variable of type `int(int, int)^`. It cannot use the variables around it.

```jk
#import <stdlib>
using stdlib

int apply(int(int, int)^ f, int x, int y) {
    return f(x, y);
}

void main() {
    cout << apply(int(int a, int b) { return a + b; }, 3, 4) << "\n";
    int(int)^ triple = int(int x) { return x * 3; };
    cout << triple(5) << "\n";
}
```

Output:

```
7
15
```

The types are written out, so a lambda reads like a function. If the body needs a value from outside, pass it as a parameter.

## Lesson 16. Errors with try and catch

`throw "text"` stops what you are doing and jumps to the nearest `catch`. Without a `catch` the program stops and prints `uncaught exception: text`.

```jk
#import <stdlib>
using stdlib

int divide(int a, int b) {
    if b == 0 { throw "cannot divide by zero"; }
    return a / b;
}

void main() {
    try {
        cout << divide(10, 2) << "\n";
        cout << divide(1, 0) << "\n";
    } catch (e) {
        cout << "error: " << e << "\n";
    }
}
```

Output:

```
5
error: cannot divide by zero
```

## Lesson 17. Decimals and the Math library

`#import <stdlib>` brings the standard library and `using stdlib` lets you write `sqrt(x)` instead of `Math::sqrt(x)` (every program that prints needs both lines; the tutorial adds them at the top). If two modules have the same function name (`write` is in `Sys` and `File`), write the module: `File::write(...)`. Casts are explicit: `(int)x`, `(double)n`.

```jk
#import <stdlib>

using stdlib
void main() {
    double a = 3.0;
    double b = 4.0;
    cout << "hypotenuse = " << sqrt(a * a + b * b) << "\n";

    int whole = (int)floor(7.9);
    cout << whole << "\n";

    double half = (double)whole / 2.0;
    cout << half << "\n";
}
```

Output:

```
hypotenuse = 5.000000
7
3.500000
```

The library has `Sys` (system calls), `Mem` (memory), `Str` (text), `Math` and `File`.

## Lesson 18. Files

`File::open(path, mode)` gives a number (negative if it failed). `read`, `write`, `read_line` and `close` use it.

```jk
#import <stdlib>

using stdlib
void main() {
    i32 f = File::open("note.txt", FileMode::Write);
    if f < 0 { throw "cannot create note.txt"; }
    File::write(f, "J2K can write files\n");
    File::close(f);

    char line[64];
    i32 g = File::open("note.txt", FileMode::Read);
    File::read_line(g, line);
    File::close(g);
    cout << line << "\n";
}
```

Output:

```
J2K can write files
```

## Lesson 19. A program in several files

A file that ends in `.jk` is a program (it has `main`). A file that ends in `.j` is a component that other files `import`; it must not have `main`.
`#import "mathx"` finds `mathx.j` next to the file; `#import "tools.mathx"` finds `tools/mathx.j`.

`mathx.j`:

```jk
// mathx.j -- a component: functions to import
int cube(int x) {
    return x * x * x;
}
```

`multi.jk`:

```jk
#import <stdlib>
using stdlib

#import "mathx"

void main() {
    cout << cube(3) << "\n";
}
```

Output:

```
27
```

Compile only the main file: `jcmp multi.jk -o multi`; the imported file is read automatically (once).

## Lesson 20. A small project: counting words

Putting it together: read words until the input ends (reading past the end throws `end of input`) and report how many there were and the longest.

```jk
#import <stdlib>
using stdlib

int length(char^ s) {
    int n = 0;
    while s[n] != 0 { n++; }
    return n;
}

void main() {
    char w[32];
    int count = 0;
    int longest = 0;
    try {
        while true {
            cin >> w;
            count++;
            int n = length(@w);
            if n > longest { longest = n; }
        }
    } catch (e) {
        // the input is over
    }
    cout << count << " words, the longest has " << longest << " letters\n";
}
```

Input: `the quick brown fox jumps over the lazy dog`

Output:

```
9 words, the longest has 5 letters
```

Run: `echo "the quick brown fox jumps over the lazy dog" | ./wordcount`.
**Try:** also print the longest word itself.

## Where next

* [LANGUAGE.md](LANGUAGE.md) — every feature with examples (function pointers, unsigned types, `sizeof`, ...).
* [USAGE.md](USAGE.md) — the compiler's options (`-d`, `-st`, `-I`, `--emit-asm`).
* `examples/` in the repository — more small programs.
