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
8. Lines, numbers and keys: read
9. Structs and methods
10. Enums and switch
11. Pointers
12. Growing arrays and memory
13. Strings
14. Generics
15. Lists, maps and sets
16. Lambdas
17. Errors with try and catch
18. Decimals and the Math library
19. Files
20. A program in several files
21. A small project: counting words
22. Option, Result and ?
23. defer: clean up on every way out
24. Operators for your own types
25. Dates, time and random numbers
26. JSON
27. CSV and formatting numbers
28. Patterns, hashes and encodings
29. Paths, other programs and the log
30. Bits and bytes
31. Numbers wider than 64 bits
32. Looking at the code the compiler made
33. Keeping the code short: #expect
34. Threads and atomic operations
35. Registers: the register block
36. A function with nothing around it: naked and svc
37. The flags of the CPU
38. Machine words you write yourself
39. Addresses and bytes
40. Talking to the kernel
41. Your own allocator
42. A spinlock
43. Counting the clock of the CPU
44. Vectors in the hardware

## Lesson 1. Hello, world

Every program starts at `main`. `cout <<` prints; `\n` is a new line. Save this as `hello.jk`.

```jk
#import <stdlib>
using stdlib;

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
using stdlib;

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
using stdlib;

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
using stdlib;

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
using stdlib;

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
using stdlib;

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
using stdlib;

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

Run it and type `Ann 30` (or pipe it in: `echo "Ann 30" | ./input`). Bad input throws an error you can catch (the lesson on try and catch).

## Lesson 8. Lines, numbers and keys: read

`cin` reads words. When you want a whole line, a number from a line, or an answer to a question, the module `read` (`using Input;`) does it: `read.line()`, `read.number()`, `read.yes("question")`. `read.enter()` waits for Enter and `read.key()` waits for one key without Enter (see below).

```jk
#import <stdlib>
using stdlib;
using Input;

void main() {
    cout << "name? ";
    String name = read.line();
    cout << "age? ";
    int age = read.number();
    cout << name << " will be " << age + 1 << " next year\n";
    if read.yes("again?") { cout << "ok\n"; } else { cout << "bye\n"; }
}
```

Input: `Ann
30
y`

Output:

```
name? age? Ann will be 31 next year
again? [y/n] ok
```

`read.number()` throws an error when the line is not a whole number (`read.try_number()` gives a `Result` instead). `read.key()` gives the code of the key, with no echo and no Enter: letters are their codes, Escape is 27, and the arrows are 257 (up), 258 (down), 259 (right), 260 (left), with Home, End, Delete, the page keys and F1 to F4 after them; at the end of the input it is -1. `read.key_timeout(ms)` gives up after that time (-2), `read.password()` hides what is typed, and `read.decimal()` reads a number with a decimal part. That is how a game or a menu reads the keyboard. Use `read` or `cin` in one program, not both.

## Lesson 9. Structs and methods

A `struct` groups values. Functions inside it are methods; they receive the object as `self`. `Rect r = {3, 4};` fills the fields in order.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 10. Enums and switch

An `enum class` is a list of named values. `switch` picks the case that matches, with no fall-through; `_` is "anything else".
An enum is not a number, so you cannot mix them up by accident.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 11. Pointers

`@x` is the address of `x`. `int^ p` is a pointer to an int; `p^` is the value it points to. A pointer lets a function change its caller's variable.
`p[i]` reaches the i-th element (there is no `p + 1`).

```jk
#import <stdlib>
using stdlib;

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

## Lesson 12. Growing arrays and memory

`int[] list = arr(4)` is a dynamic array: it starts empty and grows with `push`. `alloc(n)` gives raw memory. The compiler frees what a
local variable made with `arr` or `alloc` at the end of the block, so you rarely call `free` yourself.

```jk
#import <stdlib>

using stdlib;
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

## Lesson 13. Strings

`String` holds text that can grow. `String s = "hello";` makes a copy of the text; `a + b` joins; `==` compares; `s.len` is the length and `s[i]` one character.
Methods: `push`, `append`, `pop`, `clear`, `find`, `slice(from, to)`, `c()` (the characters as a plain text). `cin >> s` reads one word.
A `String` is freed at the end of its block, and `String b = a;` makes a separate copy.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 14. Generics

A function or struct can take a type as a parameter: write it in `<>` after the name. The compiler makes one copy for every type you use.
A function finds the type from its arguments: `largest(3, 9)`; you can also write it, `largest<int>(3, 9)`. A struct always has it written: `Box<double>`.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 15. Lists, maps and sets

A list is a dynamic array with more tools: `sort`, `insert`, `remove`, `contains`, `index_of`. `for x in list` visits every element.
`Map<K,V>` stores values by key and `Set<T>` stores each value once. They free themselves at the end of the block.

```jk
#import <stdlib>
using stdlib;

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
5 different, has 3: true
```

`ages.get("zed")` would throw `key not found`; ask with `ages.has("zed")` first. `keys_list()` makes a new list that the `for` loop frees for you.

## Lesson 16. Lambdas

A lambda is a small function written right where you need it: `int(int a, int b) { return a + b; }`. It can be passed to a function that takes a function
pointer, or kept in a variable of type `int(int, int)^`. It cannot use the variables around it.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 17. Errors with try and catch

`throw "text"` stops what you are doing and jumps to the nearest `catch`. Without a `catch` the program stops and prints `uncaught exception: text`.

```jk
#import <stdlib>
using stdlib;

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

## Lesson 18. Decimals and the Math library

`#import <stdlib>` brings the standard library and `using stdlib` lets you write `sqrt(x)` instead of `Math::sqrt(x)` (every program that prints needs both lines; the tutorial adds them at the top). If two modules have the same function name (`write` is in `Sys` and `File`), write the module: `File::write(...)`. Casts are explicit: `(int)x`, `(double)n`.

```jk
#import <stdlib>

using stdlib;
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

## Lesson 19. Files

`File::open(path, mode)` gives a number (negative if it failed). `read`, `write`, `read_line` and `close` use it.

```jk
#import <stdlib>

using stdlib;
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

## Lesson 20. A program in several files

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
using stdlib;

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

## Lesson 21. A small project: counting words

Putting it together: read words until the input ends (reading past the end throws `end of input`) and report how many there were and the longest.

```jk
#import <stdlib>
using stdlib;

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

# More of the library

## Lesson 22. Option, Result and ?

An operation that can fail gives a `Result<T, Error>`; a value that may be missing is an `Option<T>`. You take a `Result` apart with `switch`, or you pass the failure on with `?`: `int x = parse(a)?;` returns the error to the caller at once and otherwise gives the value.

```jk
#import <stdlib>
using stdlib;

Result<int, Error> parse(String s) {
    if s.len == 0 { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "empty text")); }
    return Result<int, Error>::Ok(s.to_int());
}

Result<int, Error> add(String a, String b) {
    int x = parse(a)?;
    int y = parse(b)?;
    return Result<int, Error>::Ok(x + y);
}

void show(Result<int, Error> r) {
    switch r {
        Result::Ok(v): cout << "sum = " << v << "\n";
        Result::Err(e): cout << "error: " << e.message << "\n";
    }
}

void main() {
    show(add("20", "22"));
    show(add("20", ""));
    Option<String> home = Env::get("J2K_SURELY_NOT_SET");
    cout << home.is_none() << " " << Env::get("PATH").is_some() << "\n";
}
```

Output:

```
sum = 42
error: empty text
true true
```

`add` has no `if` for the errors: `?` does it. `Env::get` gives an `Option`: `is_none()` / `is_some()` ask it. Other helpers: `unwrap()` (throws when there is no value) and `or(fallback)`. `try` / `catch` (lesson 17) is the other way, for when throwing is better.

## Lesson 23. defer: clean up on every way out

`defer statement;` runs when the block is left, whichever way it is left: at the end, by `return`, `break` or `continue`, or when an error passes through. The last `defer` runs first. It is the place for `close`, `free`, `unlock`: you write it next to the thing it undoes and you cannot forget it on one of the paths.

```jk
#import <stdlib>
using stdlib;

void work(int n) {
    defer cout << "leaving work(" << n << ")\n";
    if n > 5 {
        cout << "big\n";
        return;
    }
    cout << "small\n";
}

void main() {
    work(3);
    work(9);
    for i in 0..2 {
        defer cout << "end of round " << i << "\n";
        cout << "round " << i << "\n";
    }
    defer cout << "first defer\n";
    defer cout << "second defer\n";
    cout << "main body\n";
}
```

Output:

```
small
leaving work(3)
big
leaving work(9)
round 0
end of round 0
round 1
end of round 1
main body
second defer
first defer
```

`work(9)` returns in the middle and the message still comes. Inside a loop the `defer` runs at the end of every round. A deferred statement cannot itself `return`, `break` or `continue`.

## Lesson 24. Operators for your own types

A struct can say which of its methods an operator calls: write `operator` in front of the method. `+` calls `add`, `-` calls `sub`, `*` calls `mul`, `/` calls `div`, `==` and `!=` call `eq`, `-v` calls `neg`. Then `a + b * 2` reads like arithmetic, and the vectors, matrices and complex numbers of the math libraries are made the same way.

```jk
#import <stdlib>
using stdlib;

struct Money {
    int cents;
    operator Money add(self, Money o) { Money r = {self.cents + o.cents}; return r; }
    operator Money mul(self, int k) { Money r = {self.cents * k}; return r; }
    operator bool eq(self, Money o) { return self.cents == o.cents; }
}

void main() {
    Money a = {250};
    Money b = a + a * 3;
    Money c = 2 * a;
    cout << b.cents << " " << c.cents << " " << (a + a == c) << "\n";
}
```

Output:

```
1000 500 true
```

`a + a * 3` is `a.add(a.mul(3))`: 250 + 750 = 1000. `2 * a` (a number on the left of `*`) is the same as `a.mul(2)`. A method without the word `operator` is never called by an operator, so nothing happens behind your back.

## Lesson 25. Dates, time and random numbers

`Date` is a day and a time on the calendar (UTC): `set_unix(seconds)` fills it from the seconds since 1970, `text()` writes it, `add_days` moves it, `weekday()` is 0 for Sunday. `Time::mono_ns()` is a clock that only goes forward (for measuring) and `Time::sleep_ms` waits. `Random::seed` starts the random numbers; `Random::range(1, 7)` is 1 to 6.

```jk
#import <stdlib>
using stdlib;

void main() {
    Date d;
    d.set_unix(86400 * 365);
    cout << d.text() << " weekday " << d.weekday() << "\n";
    d.add_days(60);
    cout << d.text() << " day of year " << d.day_of_year() << "\n";
    cout << Date::is_leap(2024) << " " << Date::days_in_month(2024, 2) << "\n";
    Random::seed(42);
    int r = Random::range(1, 7);
    cout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    int t0 = Time::mono_ns();
    Time::sleep_ms(20);
    cout << (Time::mono_ns() - t0 >= 20000000) << "\n";
}
```

Output:

```
1971-01-01 00:00:00 weekday 5
1971-03-02 00:00:00 day of year 61
true 29
true true
true
```

One year after 1970-01-01 is 1971-01-01, a Friday (5). 2024 is a leap year, so February has 29 days. The same seed always gives the same random numbers, which makes a program with random numbers testable.

## Lesson 26. JSON

`Json::parse(text)` reads JSON into a document. You walk it with node numbers: `doc.root()` is the top, `doc.get(node, "name")` is a member of an object, `doc.at(node, i)` an element of an array, `doc.len(node)` how many, and `doc.text`, `doc.number`, `doc.boolean` read the value. `doc.dump(node)` writes a node back as JSON text, and `Json::quote` makes a safe string literal.

```jk
#import <stdlib>
using stdlib;

void main() {
    String text = "{\"name\": \"J2K\", \"version\": 0.9, \"tags\": [\"fast\", \"small\"], \"ok\": true}";
    JsonDoc doc = Json::parse(text).unwrap();
    int root = doc.root();
    cout << doc.text(doc.get(root, "name")) << " " << doc.number(doc.get(root, "version")) << "\n";
    int tags = doc.get(root, "tags");
    for i in 0..doc.len(tags) { cout << doc.text(doc.at(tags, i)) << " "; }
    cout << doc.boolean(doc.get(root, "ok")) << "\n";
    cout << doc.dump(tags) << "\n";
    cout << Json::quote("say \"hi\"") << "\n";
}
```

Output:

```
J2K 0.900000
fast small true
["fast","small"]
"say \"hi\""
```

A node that is not there is -1 and gives an empty answer, so a wrong name does not crash. `unwrap()` throws the parse error when the text is not JSON; `switch` on the `Result` to handle it yourself.

## Lesson 27. CSV and formatting numbers

`Csv::split_line` cuts one line of comma separated values into fields (a field in quotes may hold commas) and `Csv::join_line` does the opposite. `Fmt` writes numbers the way people read them: `fixed` (decimals), `pad_left`, `thousands`, `hex`, `bin`, `percent`, `bytes`.

```jk
#import <stdlib>
using stdlib;

void main() {
    String[] f = Csv::split_line("Ann,\"Lee, Jr\",30");
    cout << f.len << ": " << f[0] << " | " << f[1] << " | " << f[2] << "\n";
    cout << Csv::join_line(f) << "\n";
    cout << Fmt::fixed(3.14159, 2) << " " << Fmt::pad_left("7", 3, '0') << " " << Fmt::thousands(1234567) << "\n";
    cout << Fmt::hex(255) << " " << Fmt::bin(5) << " " << Fmt::percent(0.256, 1) << " " << Fmt::bytes(1536) << "\n";
}
```

Output:

```
3: Ann | Lee, Jr | 30
Ann,"Lee, Jr",30
3.14 007 1,234,567
ff 101 25.6% 1.5 KB
```

The field `Lee, Jr` keeps its comma, and `join_line` puts the quotes back because the field needs them. `Fmt::bytes(1536)` is `1.5 KB`.

## Lesson 28. Patterns, hashes and encodings

`Regex` is a small pattern matcher: `matches` (the whole text), `find` (where the first match starts, or -1), `find_text` (the matching text). `Sha256::hex` is the SHA-256 hash of a text (and `Sha256::file` of a file), `Hex::encode` writes bytes as two hex digits each, and `Base64` is the text form that mails and web pages use for bytes.

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find("[0-9]+", "room 42, floor 7") << " " << Regex::find_text("[0-9]+", "room 42, floor 7") << "\n";
    cout << Sha256::hex("abc") << "\n";
    cout << Hex::encode("Hi") << " " << Base64::encode("Man") << " " << Base64::decode("TWFu").unwrap() << "\n";
}
```

Output:

```
true 5 42
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
4869 TWFu Man
```

The hash of `abc` is a well-known test value of SHA-256 (`ba7816bf...`). `Base64::decode` gives a `Result` because the text may not be valid.

## Lesson 29. Paths, other programs and the log

`Path::join` builds a path with the right separator. `Proc::output(program, args)` runs another program and gives what it wrote; `Proc::run` gives its exit code. `Env::args()` is the list of arguments of your own program (the first is its name). `Log` writes messages to the standard error with a level: `Log::set_level(2)` hides the `info` messages and keeps the errors.

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << Path::join("dir", "file.txt") << "\n";
    String[] args = arr(0);
    args.push("hello from a child");
    String out = Proc::output("echo", args).unwrap();
    cout << out;
    cout << Env::args().len << "\n";
    Log::set_level(2);
    Log::info("not shown");
    Log::error("shown on the standard error");
}
```

Output:

```
dir/file.txt
hello from a child
1
```

`String[] args = arr(0);` makes an empty list of Strings and `push` adds to it. The log line went to the standard error, so it is not in the output above; run the program in a terminal to see both.

# Part 2: toward the machine

## Lesson 30. Bits and bytes

A whole number is 64 bits. `>>` and `<<` shift them, `&` keeps bits, `xor` flips them. `Bit::` has the work that the CPU does in one instruction:
`popcount` (how many bits are 1), `clz` / `ctz` (zero bits in front / after), `rotl` / `rotr` (turn the bits round), `bswap` (reverse the 8 bytes).

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 0xB0;
    cout << x << " " << Bit::popcount(x) << " " << Bit::clz(x) << " " << Bit::ctz(x) << "\n";
    cout << (x >> 4) << " " << (x & 0xF) << " " << (x << 4) << " " << (x xor 0xFF) << "\n";
    cout << Bit::rotl(1, 63) << "\n";
    cout << Bit::bswap(0x0102030405060708) << "\n";
}
```

Output:

```
176 3 56 4
11 0 2816 79
-9223372036854775808
578437695752307201
```

`0xB0` is `1011 0000` in binary: 3 bits are 1, 56 zero bits stand in front, 4 after. The last line turns the 8 bytes `01 02 ... 08` round to `08 07 ... 01`.

## Lesson 31. Numbers wider than 64 bits

When 64 bits are not enough you keep a number in several words and add word by word. `Bit::add_carry(a, b, carry_in)` gives a struct with the sum and the carry out.
`Bit::mul_wide` gives the whole 128-bit product, `Bit::div_rem` the quotient and the remainder together, `Bit::add_sat` an addition that stops at the largest number instead of wrapping.

```jk
#import <stdlib>
using stdlib;

void main() {
    // (5, -1) + (0, 1) as numbers of two words: high word first
    BitCarry lo = Bit::add_carry(-1, 1, 0);
    BitCarry hi = Bit::add_carry(5, 0, lo.c);
    cout << hi.sum << " " << lo.sum << " " << hi.c << "\n";
    BitWide w = Bit::mul_wide(-1, 3);
    cout << w.hi << " " << w.lo << "\n";
    BitDivRem d = Bit::div_rem(-17, 5);
    cout << d.q << " " << d.r << "\n";
    cout << Bit::add_sat(9223372036854775807, 5) << "\n";
}
```

Output:

```
6 0 0
2 -3
-3 -2
9223372036854775807
```

The low words `-1 + 1` give 0 with a carry of 1; the carry goes into the high words: `5 + 0 + 1 = 6`. The product `(2^64 - 1) * 3` does not fit in 64 bits: `hi` is 2 and `lo` is -3.

## Lesson 32. Looking at the code the compiler made

The compiler does not hide what it makes: `jcmp program.jk -show NAME` writes the machine code of the function `NAME` and how many instructions it has.
Small functions are often put inside their callers, so a function that is called once can have no code of its own. Here `scale` is kept because `main` calls it in a loop.

```jk
#import <stdlib>
using stdlib;

int scale(int x, int k) {
    return (x * k) >> 2;
}

void main() {
    int total = 0;
    for i in 0..10 { total += scale(i, 6); }
    cout << total << "\n";
}
```

Output:

```
65
```

The code of `scale` that the compiler made:

```
scale:
mul x0, x0, x1
asr x0, x0, #2
L8182:
ret
// 3 instructions
```

Run `jcmp showcode.jk -show scale` to see the lines above (they are the code of the ARM64 target). On another target the instructions are other ones.

## Lesson 33. Keeping the code short: #expect

A hot function should stay small. `#expect instructions <= N` in front of a function makes the compiler stop, with the real count, when the function grows past N: after a change of your program, or a new compiler.

```jk
#import <stdlib>
using stdlib;

#expect instructions <= 12
int clamp(int x, int lo, int hi) {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

void main() {
    cout << clamp(-5, 0, 10) << " " << clamp(7, 0, 10) << " " << clamp(99, 0, 10) << "\n";
}
```

Output:

```
0 7 10
```

Try `#expect instructions <= 2` and compile again: the compiler says how many instructions the function really has.

## Lesson 34. Threads and atomic operations

`Thread` runs a function at the same time as the others. Two threads that do `counter += 1` can lose counts, because the CPU reads, adds and writes in three steps. `Atomic::add` does the three steps as one that nobody can break.

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int counter;

void work(void^ arg) {
    for i in 0..10000 { Atomic::add(@counter, 1); }
}

void main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    Thread c = create(work, null);
    a.join();
    b.join();
    c.join();
    cout << counter << "\n";
}
```

Output:

```
30000
```

`Atomic::` also has `cas` (change a value only if it is what you expect), `swap`, `load`, `store`, `bit_or` and others, and `Mem::barrier()` orders the memory accesses of one thread against the others.

## Lesson 35. Registers: the register block

The CPU keeps the numbers it works on in registers, named `x0` ... `x30`. A `register { }` block lets you write instructions with those registers. `in x1 = a;` puts a value in a register before the block, `out x0 = r;` takes one out after it, and `clobber x4;` says that you use `x4` for your own work.
Inside the block every statement is one instruction.

```jk
#import <stdlib>
using stdlib;

int add_mul(int a, int b, int c) {
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        in x3 = c;
        clobber x4;
        x4 = x1 + x2;
        x0 = x4 * x3;
        out x0 = r;
    }
    return r;
}

void main() {
    cout << add_mul(2, 3, 4) << "\n";
}
```

Output:

```
20
```

`(2 + 3) * 4 = 20`. The same source builds for the ARM64 and the ARM32 target (the names `x0 ...` are the same on both).

## Lesson 36. A function with nothing around it: naked and svc

A `naked` function has no prologue and no epilogue: the body is all there is, and the arguments are in `x0`, `x1`, ... The statement `svc(0);` asks the kernel for a service; the number of the service is in `x8`.
Here is `write` (number 64) written by hand, with no library at all.

```jk
#import <stdlib>
using stdlib;

naked int my_write(int fd, char^ buf, int n) {
    Reg::x8 = 64;
    svc(0);
    ret;
}

void main() {
    char msg[6] = {'h', 'e', 'l', 'l', 'o', '\n'};
    int n = my_write(1, @msg, 6);
    cout << n << "\n";
}
```

Output:

```
hello
6
```

`write(1, buffer, 6)` sends 6 bytes to the standard output and returns how many it wrote. `ret;` goes back to the caller with the result in `x0`.

## Lesson 37. The flags of the CPU

After an addition or a comparison the CPU keeps four flags: `n` (negative), `z` (zero), `c` (carry) and `v` (overflow). C hides them; here you can read them. `Cpu::inst("adds", ...)` is the instruction `adds`, which sets the flags, and `Flags::c` reads one of them as 0 or 1.

```jk
#import <stdlib>
using stdlib;

int carry_of(int a, int b) {
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        Cpu::inst("adds", Reg::x3, Reg::x1, Reg::x2);
        x0 = Flags::c;
        out x0 = r;
    }
    return r;
}

void main() {
    cout << carry_of(-1, 1) << " " << carry_of(1, 2) << "\n";
}
```

Output:

```
1 0
```

`-1` is all bits 1, so `-1 + 1` carries out of the top: the flag is 1. `1 + 2` does not: 0. (This lesson is for the ARM64 target.)

## Lesson 38. Machine words you write yourself

At the bottom there is nothing but numbers. `raw<u32>[...]` puts a 32-bit machine word in the code, exactly as you wrote it. The instruction `add x1, x1, #2` of the ARM64 CPU is the number `0x91000821`; `nop` is `0xd503201f`.

```jk
#import <stdlib>
using stdlib;

void main() {
    int v = 5;
    register {
        in x1 = v + 1;
        raw<u32>[0xd503201f];
        raw<u32>[0x91000821];
        out x1 = v;
    }
    cout << v << "\n";
}
```

Output:

```
8
```

`5 + 1 = 6`, then the word adds 2: 8. These numbers are for ARM64; on the ARM32 target the same instruction is another word (`0xE2811002`), so a program that writes raw words is for one CPU.

# Part 3: to the bone

## Lesson 39. Addresses and bytes

A variable lives at an address. `@x` is that address and a pointer holds it. A `char^` looks at memory one byte at a time, so you can see how an `int` is stored: the CPU is little-endian, the lowest byte comes first. Pointers into one array are as far apart as the size of the elements. `(int)q - (int)p` is the distance in bytes.

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 0x0102030405060708;
    char^ b = (char^)@x;
    for i in 0..8 { cout << (b[i] & 255) << " "; }
    cout << "\n";
    int a[4];
    for i in 0..4 { a[i] = i * 10; }
    int^ p = @a[0];
    int^ q = @a[3];
    cout << ((int)q - (int)p) << " " << (p == @a[0]) << " " << (q^) << "\n";
    cout << sizeof(int) << " " << sizeof(char) << "\n";
}
```

Output:

```
8 7 6 5 4 3 2 1 
24 true 30
8 1
```

`0x0102030405060708` is stored as `08 07 ... 01`. Four `int`s are 32 bytes, so `a[3]` is 24 bytes after `a[0]`. When you print the address of a variable (`cout << p;`) you get `0x...`; here we print distances because an address changes from run to run.

## Lesson 40. Talking to the kernel

A program does nothing alone: writing, memory and the process id all come from the kernel through system calls. `Sys::` is a thin layer over them: `Sys::write(file, buffer, bytes)`, `Sys::getpid()`, `Sys::mmap(bytes)` (a fresh block of memory from the system, the base of every allocator) and `Sys::munmap`. No library code sits in between, one call is one `svc` instruction.

```jk
#import <stdlib>
using stdlib;

void main() {
    char msg[8];
    msg[0] = 'h'; msg[1] = 'i'; msg[2] = '\n';
    Sys::write(1, @msg, 3);
    int pid = Sys::getpid();
    cout << (pid > 0) << "\n";
    void^ page = Sys::mmap(4096);
    int^ words = (int^)page;
    for i in 0..512 { words[i] = i * i; }
    cout << words[511] << "\n";
    Sys::munmap(page, 4096);
}
```

Output:

```
hi
true
261121
```

`mmap` gives whole pages (4096 bytes) that are zero at the start. `cout` itself ends in `Sys::write`. For any call the library does not name there is `Sys::call(number, a0 ... a5)` and the `svc` of lesson 36.

## Lesson 41. Your own allocator

The fastest allocator is a pointer that only moves forward (a bump allocator): ask for a block, add its size to `top`, done. There is no `free` for one object; you give the whole block back at once. This is what an arena does, and it is why compilers and games use it. The block comes from `mmap`.

```jk
#import <stdlib>
using stdlib;

int^ heap;
int top;

int^ bump(int n) {
    int^ p = @heap[top];
    top += n;
    return p;
}

void main() {
    heap = (int^)Sys::mmap(65536);
    int^ a = bump(4);
    int^ b = bump(4);
    for i in 0..4 { a[i] = i; b[i] = i * 100; }
    cout << a[3] + b[3] << " " << top << " " << ((int)b - (int)a) << "\n";
    Sys::munmap(heap, 65536);
}
```

Output:

```
303 8 32
```

Both blocks sit side by side: `b` is 32 bytes after `a`, and `top` counts 8 `int`s. The standard library has this ready as `Arena`; writing it once shows there is no magic in an allocator.

## Lesson 42. A spinlock

Lesson 34 used `Atomic::add`. For a bigger piece of work (several statements that must not be mixed) you need a lock. A spinlock is one `int`: 0 is free, 1 is taken. `Atomic::cas(@lock, 0, 1)` changes it to 1 only if it was 0 and gives the old value, so exactly one thread wins. The others spin; `Cpu::pause()` tells the CPU it is a spin loop (it saves power and helps the other hyper-thread).

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int lock;
int counter;

void work(void^ arg) {
    for i in 0..10000 {
        while Atomic::cas(@lock, 0, 1) != 0 { Cpu::pause(); }
        counter += 1;
        Atomic::store(@lock, 0);
    }
}

void main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    a.join();
    b.join();
    cout << counter << "\n";
}
```

Output:

```
20000
```

`counter += 1` is now safe although it is three steps, because only the thread that holds the lock runs it. `Atomic::store` releases the lock with the right memory order, so the new `counter` is seen by the next thread. A spinlock is right for very short work; for long waits use a lock that sleeps.

## Lesson 43. Counting the clock of the CPU

`Cpu::counter()` reads the system counter of the CPU (no system call, a few cycles) and `Cpu::frequency()` says how many ticks make a second. It is the most exact stopwatch you have. To time code: read, run, read, subtract. `Bit::popcount` is one instruction on the CPU, so a million of them are quick.

```jk
#import <stdlib>
using stdlib;

void main() {
    int start = Cpu::counter();
    int sum = 0;
    for i in 0..1000000 { sum += Bit::popcount(i); }
    int ticks = Cpu::counter() - start;
    cout << sum << " " << (ticks > 0) << " " << (Cpu::frequency() > 0) << "\n";
}
```

Output:

```
9884992 true true
```

The sum is fixed, the time is not, so the program prints only whether the time was measured. Measure more than once: the first run warms the cache. With `#expect instructions <= N` (lesson 33) you guard the size, with the counter you guard the time.

## Lesson 44. Vectors in the hardware

Graphics and physics work on groups of numbers. `vec3` is three `double`s with the operators `+ - *`, and its parts are picked by letter (`c.zyx` is the same three numbers in the reverse order). For many numbers at once the CPU has SIMD registers (NEON on ARM): the compiler turns loops over arrays into vector instructions by itself, and `#import <simd>` gives the lanes by name.

```jk
#import <stdlib>
using stdlib;
#import <math>
using math::vector;

void main() {
    vec3 a = {1.0, 2.0, 3.0};
    vec3 b = {4.0, 5.0, 6.0};
    vec3 c = a + b * 2.0;
    cout << c.x << " " << c.y << " " << c.z << "\n";
    cout << c.zyx.x << "\n";
}
```

Output:

```
9.000000 12.000000 15.000000
15.000000
```

`a + b * 2.0` is `(1,2,3) + (8,10,12)`. Use `jcmp file.jk -show NAME` (lesson 32) on a loop over a `double` array to see the vector instructions.

## Where next

* [LANGUAGE.md](LANGUAGE.md) — every feature with examples (function pointers, unsigned types, `sizeof`, ...).
* [USAGE.md](USAGE.md) — the compiler's options (`-d`, `-st`, `-I`, `--emit-asm`).
* `examples/` in the repository — more small programs.
