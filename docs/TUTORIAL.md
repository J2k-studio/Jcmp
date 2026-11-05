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
45. Two tasks, two stacks: a context switch
46. A queue without a lock
47. A whole function in raw instructions
48. Any instruction of the CPU by name
49. Names in layers: modules and using
50. Enums that carry values
51. Structs: methods, nesting and arrays
52. Values that free themselves
53. Function pointers and lambdas
54. Numbers of every size
55. Raw memory: alloc, pools and grow
56. Raw bytes and data that cannot change
57. Building a project with makej
58. Several cores, and the build file as a program
59. Shared libraries: export and -l
60. Scripts with jsh, and writing on the phone
61. The libraries of the phone: `-dyn` and `<native>`
62. OpenGL ES: the first picture, drawn by the chip
63. A triangle and a shader
64. The chip as a calculator: compute shaders
65. Vulkan: asking the chip
66. Games: Jaric Engine
67. Talking to the web: `<web>`
68. A bot that answers: `<telegram>` and `<discord>`
69. Live news: WebSocket and the Discord Gateway
70. Numbers that learn: tensors and gradients
71. Teaching a network: layers, batches and AdamW
72. A language model that you train on the phone
73. Running models that others made: GGUF and `<llama>`
74. Fast code: what the language costs and how to ask for speed
75. Programs and libraries from the net: `jc`
76. Counting in base 2 and base 16
77. Negative numbers: two's complement
78. Numbers with a point, inside
79. From logic gates to an adder
80. A tiny CPU of our own
81. An assembler for the tiny CPU
82. The real thing: an ARM64 instruction as 32 bits
83. Laying out the output: columns, digits, hex
84. The screens of an app: `<ui>`
85. An apk without the Android tools: `apkj`
86. Looking at part of an array: Span
87. Real text: reading UTF-8 and the library <font>
88. Light, shadow and glow: how colours mix
89. Keys from one secret: HKDF and the tool jmaip
90. Fast loops: how to write code the compiler can vectorise
91. Why loops over arrays are fast
92. Measuring time with Time::mono_ns
93. float and double, and float[] arrays
94. SIMD types: f32x4 load and store
95. f32x4 operators and .sum()
96. axpy with f32x4: y = y + a * x
97. Matrix product, the plain way (ijk)
98. Why ijk is slower: a chain of adds, and two accumulators
99. Four accumulators by hand
100. Vector across j: four columns of C at once
101. A 4x8 register block
102. Threads: the #multithread loop
103. Bounds checks and the -d switch
104. The switches -novec, -nofma, -nopeep, -noir
105. Reading the assembly of a loop
106. Integer sums with i32x4
107. Avoiding allocation in a hot loop
108. Struct of arrays and array of structs
109. Cache: row-major order, i-k-j against i-j-k
110. Comparing with C fairly
111. What a neural network is
112. A tensor
113. Matrix multiply
114. A linear layer
115. Activation functions
116. The loss: mean squared error
117. The gradient, checked two ways
118. Gradient descent: one weight
119. Two weights: a line
120. XOR with a small network
121. Backpropagation on the graph
122. Mini-batches and shuffling
123. Softmax and cross-entropy
124. The learning rate
125. Starting weights
126. Embeddings
127. A tiny character model
128. Saving and loading weights
129. Inference: using a trained network
130. Why matmul is the speed
131. A program of several files
132. A test for your own function
133. Errors in a program that reads input
134. Command-line arguments
135. Reading a text file line by line
136. Writing a CSV report
137. JSON in and out
138. A small state machine
139. A tokenizer for arithmetic
140. A calculator with recursive descent
141. A heap from scratch
142. Word frequency with a hash map
143. Sorting with your own comparison
144. A room graph for a text adventure
145. A game loop without graphics
146. A bank account with methods and checks
147. A generic stack: Stack<T>
148. defer: cleanup when a function fails
149. A build file of makej, read as text
150. Reading a compiler error

## Lesson 1. Hello, world

Every program starts at `main`. `jout <<` prints; `\n` is a new line. Save this as `hello.jk`.

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
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
`jout` prints decimals too. Lines end with `;`.

```jk
#import <stdlib>
using stdlib;

void main() {
    int apples = 5;
    int pears = 3;
    int total = apples + pears;
    jout << "total = " << total << "\n";

    double price = 2.5;
    jout << "cost = " << price * 4.0 << "\n";

    char letter = 'J';
    jout << letter << "\n";

    bool enough = total > 7;
    if enough { jout << "enough fruit\n"; }
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
        jout << "A\n";
    } else if score >= 70 {
        jout << "B\n";
    } else {
        jout << "C\n";
    }
    bool passed = score >= 50 && score <= 100;
    if passed { jout << "passed\n"; }
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
        jout << i << " ";
        i++;
    }
    jout << "\n";

    for k in 0..5 { jout << k * k << " "; }
    jout << "\n";

    for int j = 10; j > 0; j -= 3 { jout << j << " "; }
    jout << "\n";
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
    jout << square(7) << "\n";
    jout << sum_to(10) << "\n";
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
    jout << "Hello, " << name << "!\n";
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
    jout << "total " << total << "\n";

    char word[] = "banana";
    int count = 0;
    for i in 0..word.len {
        if word[i] == 'a' { count++; }
    }
    jout << word << " has " << count << " letter a\n";

    int grid[2][3];
    for r in 0..2 {
        for c in 0..3 { grid[r][c] = r * 3 + c; }
    }
    jout << grid[1][2] << "\n";
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

`jin >> a >> b;` reads words from the keyboard. The type of the variable decides what is read: a number for `int`,
a word for a `char` array. `jin` reads decimals too. Words are separated by spaces or new lines.

```jk
#import <stdlib>
using stdlib;

void main() {
    char name[20];
    int age;
    jin >> name >> age;
    jout << name << " will be " << age + 1 << " next year\n";
}
```

Input: `Ann 30`

Output:

```
Ann will be 31 next year
```

Run it and type `Ann 30` (or pipe it in: `echo "Ann 30" | ./input`). Bad input throws an error you can catch (the lesson on try and catch).

## Lesson 8. Lines, numbers and keys: read

`jin` reads words. When you want a whole line, a number from a line, or an answer to a question, the module `read` (`using Input;`) does it: `read.line()`, `read.number()`, `read.yes("question")`. `read.enter()` waits for Enter and `read.key()` waits for one key without Enter (see below).

```jk
#import <stdlib>
using stdlib;
using Input;

void main() {
    jout << "name? ";
    String name = read.line();
    jout << "age? ";
    int age = read.number();
    jout << name << " will be " << age + 1 << " next year\n";
    if read.yes("again?") { jout << "ok\n"; } else { jout << "bye\n"; }
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

`read.number()` throws an error when the line is not a whole number (`read.try_number()` gives a `Result` instead). `read.key()` gives the code of the key, with no echo and no Enter: letters are their codes, Escape is 27, and the arrows are 257 (up), 258 (down), 259 (right), 260 (left), with Home, End, Delete, the page keys and F1 to F4 after them; at the end of the input it is -1. `read.key_timeout(ms)` gives up after that time (-2), `read.password()` hides what is typed, and `read.decimal()` reads a number with a decimal part. That is how a game or a menu reads the keyboard. Use `read` or `jin` in one program, not both.

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
    jout << r.area() << "\n";
    r.grow(1);
    jout << r.w << "x" << r.h << " area " << r.area() << "\n";
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
        Light::Red: jout << "stop\n";
        Light::Yellow: jout << "slow down\n";
        Light::Green: jout << "go\n";
    }
}

void main() {
    say(Light::Green);
    say(Light::Red);

    int n = 3;
    switch n {
        1, 2: jout << "small\n";
        3: jout << "three\n";
        _: jout << "other\n";
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
    jout << n << "\n";

    int a[3];
    a[0] = 10; a[1] = 20; a[2] = 30;
    int^ q = @a;
    jout << q[1] << "\n";
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
    jout << squares.len << " items, total " << total(squares) << "\n";

    int^ buffer = (int^)alloc(sizeof(int) * 3);
    buffer[0] = 7;
    buffer[1] = 8;
    buffer[2] = 9;
    jout << buffer[0] + buffer[2] << "\n";
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
Methods: `push`, `append`, `pop`, `clear`, `find`, `slice(from, to)`, `c()` (the characters as a plain text). `jin >> s` reads one word.
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
    jout << a << " " << b << "\n";

    String line = "Hello, " + shout("Jao");
    jout << line << " (" << line.len << " characters)\n";
    jout << line.find("Jao") << " " << line.slice(0, 5) << "\n";
    if a == "abc" { jout << "same\n"; }
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
    jout << largest(3, 9) << "\n";
    jout << largest(2.5, 1.5) << "\n";
    jout << largest<int>(8, 2) << "\n";
    Box<int> b = {7};
    jout << b.get() << "\n";
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
    for s in scores { jout << s << " "; }
    jout << "\n";

    Map<String, int> ages;
    ages.put("ann", 31);
    ages.put("bob", 25);
    ages.put("ann", 32);
    jout << ages.get("ann") << " " << ages.len << "\n";
    for name in ages.keys_list() {
        jout << name << " is " << ages.get(name) << "\n";
    }

    Set<int> seen;
    for i in 0..20 { seen.add(i % 5); }
    jout << seen.len << " different, has 3: " << seen.has(3) << "\n";
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
    jout << apply(int(int a, int b) { return a + b; }, 3, 4) << "\n";
    int(int)^ triple = int(int x) { return x * 3; };
    jout << triple(5) << "\n";
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
        jout << divide(10, 2) << "\n";
        jout << divide(1, 0) << "\n";
    } catch (e) {
        jout << "error: " << e << "\n";
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
    jout << "hypotenuse = " << sqrt(a * a + b * b) << "\n";

    int whole = (int)floor(7.9);
    jout << whole << "\n";

    double half = (double)whole / 2.0;
    jout << half << "\n";
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
    jout << line << "\n";
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
    jout << cube(3) << "\n";
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
            jin >> w;
            count++;
            int n = length(@w);
            if n > longest { longest = n; }
        }
    } catch (e) {
        // the input is over
    }
    jout << count << " words, the longest has " << longest << " letters\n";
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
        Result::Ok(v): jout << "sum = " << v << "\n";
        Result::Err(e): jout << "error: " << e.message << "\n";
    }
}

void main() {
    show(add("20", "22"));
    show(add("20", ""));
    Option<String> home = Env::get("J2K_SURELY_NOT_SET");
    jout << home.is_none() << " " << Env::get("PATH").is_some() << "\n";
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
    defer jout << "leaving work(" << n << ")\n";
    if n > 5 {
        jout << "big\n";
        return;
    }
    jout << "small\n";
}

void main() {
    work(3);
    work(9);
    for i in 0..2 {
        defer jout << "end of round " << i << "\n";
        jout << "round " << i << "\n";
    }
    defer jout << "first defer\n";
    defer jout << "second defer\n";
    jout << "main body\n";
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
    jout << b.cents << " " << c.cents << " " << (a + a == c) << "\n";
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
    jout << d.text() << " weekday " << d.weekday() << "\n";
    d.add_days(60);
    jout << d.text() << " day of year " << d.day_of_year() << "\n";
    jout << Date::is_leap(2024) << " " << Date::days_in_month(2024, 2) << "\n";
    Random::seed(42);
    int r = Random::range(1, 7);
    jout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    int t0 = Time::mono_ns();
    Time::sleep_ms(20);
    jout << (Time::mono_ns() - t0 >= 20000000) << "\n";
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
    jout << doc.text(doc.get(root, "name")) << " " << doc.number(doc.get(root, "version")) << "\n";
    int tags = doc.get(root, "tags");
    for i in 0..doc.len(tags) { jout << doc.text(doc.at(tags, i)) << " "; }
    jout << doc.boolean(doc.get(root, "ok")) << "\n";
    jout << doc.dump(tags) << "\n";
    jout << Json::quote("say \"hi\"") << "\n";
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
    jout << f.len << ": " << f[0] << " | " << f[1] << " | " << f[2] << "\n";
    jout << Csv::join_line(f) << "\n";
    jout << Fmt::fixed(3.14159, 2) << " " << Fmt::pad_left("7", 3, '0') << " " << Fmt::thousands(1234567) << "\n";
    jout << Fmt::hex(255) << " " << Fmt::bin(5) << " " << Fmt::percent(0.256, 1) << " " << Fmt::bytes(1536) << "\n";
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
    jout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find("[0-9]+", "room 42, floor 7") << " " << Regex::find_text("[0-9]+", "room 42, floor 7") << "\n";
    jout << Sha256::hex("abc") << "\n";
    jout << Hex::encode("Hi") << " " << Base64::encode("Man") << " " << Base64::decode("TWFu").unwrap() << "\n";
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
    jout << Path::join("dir", "file.txt") << "\n";
    String[] args = arr(0);
    args.push("hello from a child");
    String out = Proc::output("echo", args).unwrap();
    jout << out;
    jout << Env::args().len << "\n";
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
    jout << x << " " << Bit::popcount(x) << " " << Bit::clz(x) << " " << Bit::ctz(x) << "\n";
    jout << (x >> 4) << " " << (x & 0xF) << " " << (x << 4) << " " << (x xor 0xFF) << "\n";
    jout << Bit::rotl(1, 63) << "\n";
    jout << Bit::bswap(0x0102030405060708) << "\n";
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
    jout << hi.sum << " " << lo.sum << " " << hi.c << "\n";
    BitWide w = Bit::mul_wide(-1, 3);
    jout << w.hi << " " << w.lo << "\n";
    BitDivRem d = Bit::div_rem(-17, 5);
    jout << d.q << " " << d.r << "\n";
    jout << Bit::add_sat(9223372036854775807, 5) << "\n";
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
    jout << total << "\n";
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
L9017:
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
    jout << clamp(-5, 0, 10) << " " << clamp(7, 0, 10) << " " << clamp(99, 0, 10) << "\n";
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
    jout << counter << "\n";
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
    jout << add_mul(2, 3, 4) << "\n";
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
    jout << n << "\n";
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
    jout << carry_of(-1, 1) << " " << carry_of(1, 2) << "\n";
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
    jout << v << "\n";
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
    for i in 0..8 { jout << (b[i] & 255) << " "; }
    jout << "\n";
    int a[4];
    for i in 0..4 { a[i] = i * 10; }
    int^ p = @a[0];
    int^ q = @a[3];
    jout << ((int)q - (int)p) << " " << (p == @a[0]) << " " << (q^) << "\n";
    jout << sizeof(int) << " " << sizeof(char) << "\n";
}
```

Output:

```
8 7 6 5 4 3 2 1 
24 true 30
8 1
```

`0x0102030405060708` is stored as `08 07 ... 01`. Four `int`s are 32 bytes, so `a[3]` is 24 bytes after `a[0]`. When you print the address of a variable (`jout << p;`) you get `0x...`; here we print distances because an address changes from run to run.

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
    jout << (pid > 0) << "\n";
    void^ page = Sys::mmap(4096);
    int^ words = (int^)page;
    for i in 0..512 { words[i] = i * i; }
    jout << words[511] << "\n";
    Sys::munmap(page, 4096);
}
```

Output:

```
hi
true
261121
```

`mmap` gives whole pages (4096 bytes) that are zero at the start. `jout` itself ends in `Sys::write`. For any call the library does not name there is `Sys::call(number, a0 ... a5)` and the `svc` of lesson 36.

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
    jout << a[3] + b[3] << " " << top << " " << ((int)b - (int)a) << "\n";
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
    jout << counter << "\n";
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
    jout << sum << " " << (ticks > 0) << " " << (Cpu::frequency() > 0) << "\n";
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
    jout << c.x << " " << c.y << " " << c.z << "\n";
    jout << c.zyx.x << "\n";
}
```

Output:

```
9.000000 12.000000 15.000000
15.000000
```

`a + b * 2.0` is `(1,2,3) + (8,10,12)`. Use `jcmp file.jk -show NAME` (lesson 32) on a loop over a `double` array to see the vector instructions.

## Lesson 45. Two tasks, two stacks: a context switch

A thread is the kernel's way to run two things at once. Without the kernel you can still make two tasks that take turns, if each has its own stack. All that a task is, is its registers: `x19` to `x30` and the stack pointer `sp`. `frame Context { x19..x30; sp; }` names that record of 13 words. `Context::save(x0)` writes the registers to the record at `x0`, `Context::restore(x1)` loads them from the record at `x1`. After a `restore`, the `ret` goes to wherever the saved `x30` points: into the other task.

```jk
#import <stdlib>
using stdlib;

frame Context { x19..x30; sp; }

naked void ctx_save(int^ c) {
    Context::save(x0);
    ret;
}

naked void ctx_switch(int^ from, int^ to) {
    Context::save(x0);
    Context::restore(x1);
    ret;
}

int main_ctx[16];
int task_ctx[16];
char task_stack[16384];
int value;

void squares() {
    int n = 1;
    while true {
        value = n * n;
        n += 1;
        ctx_switch(@task_ctx, @main_ctx);
    }
}

void main() {
    ctx_save(@task_ctx);
    task_ctx[10] = 0;
    task_ctx[11] = (int)squares;
    task_ctx[12] = ((int)@task_stack + 16000) & (0 - 16);
    for k in 0..6 {
        ctx_switch(@main_ctx, @task_ctx);
        jout << value << " ";
    }
    jout << "\n";
}
```

Output:

```
1 4 9 16 25 36 
```

The first time, there is no saved state, so `main` makes one: it saves its own registers into `task_ctx` as a start, then changes three words: word 10 (`x29`, the frame pointer) to 0, word 11 (`x30`, where the switch will return to) to the function `squares`, and word 12 (`sp`) to the top of a block of memory used as the stack, aligned to 16. `squares` never returns: it writes a value and switches back, and each switch from `main` resumes it after its last switch. This is how coroutines, green threads and generators are made; it is ARM64 only because the saved registers are those of ARM64.

## Lesson 46. A queue without a lock

A spinlock makes threads wait for each other. A ring buffer with one writer and one reader needs no lock at all: the writer owns `head` (how many it has written), the reader owns `tail` (how many it has read), and each only reads the other's number. `Atomic::load` and `Atomic::store` are the loads and stores with the memory order that makes this correct: what the writer put in the ring before `Atomic::store(@head, ...)` is seen by the reader that sees the new `head`.

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int ring[64];
int head;
int tail;
int total;

void producer(void^ arg) {
    for i in 1..1001 {
        while Atomic::load(@head) - Atomic::load(@tail) >= 64 { Cpu::pause(); }
        int h = Atomic::load(@head);
        ring[h % 64] = i;
        Atomic::store(@head, h + 1);
    }
}

void consumer(void^ arg) {
    int got = 0;
    while got < 1000 {
        int t = Atomic::load(@tail);
        while Atomic::load(@head) == t { Cpu::pause(); }
        total += ring[t % 64];
        Atomic::store(@tail, t + 1);
        got += 1;
    }
}

void main() {
    Thread a = create(producer, null);
    Thread b = create(consumer, null);
    a.join();
    b.join();
    jout << total << "\n";
}
```

Output:

```
500500
```

The sum of 1 to 1000 is 500500 every time; it was run 60 times in a row to be sure. When the ring is full the writer waits, when it is empty the reader waits, and `Cpu::pause()` makes the waiting kind to the CPU. It works for exactly one writer and one reader: with two writers they would both write the same `head`, and then you need `Atomic::cas` (the spinlock lesson).

## Lesson 47. A whole function in raw instructions

In a `naked` function nothing is added by the compiler: you write the machine instructions, one statement for one instruction, with the registers `x0` to `x30` by name. `x2 = x2 + x3;` is `add x2, x2, x3`, `x3 = [x0 + 0];` is a load, `if x1 == 0 goto done;` compares and branches, `name:` is a label, `goto`, `ret`. The arguments come in `x0`, `x1`, ... and the result goes back in `x0`. This is the loop of `sum_words`, the same loop that a compiler makes for you, written by hand.

```jk
#import <stdlib>
using stdlib;

naked int sum_words(int^ p, int n) {
    x2 = 0;
loop:
    if x1 == 0 goto done;
    x3 = [x0 + 0];
    x2 = x2 + x3;
    x0 = x0 + 8;
    x1 = x1 - 1;
    goto loop;
done:
    x0 = x2;
    ret;
}

void main() {
    int a[5] = {10, 20, 30, 40, 5};
    jout << sum_words(@a, 5) << "\n";
    jout << sum_words(@a, 0) << "\n";
}
```

Output:

```
105
0
```

`x0` walks along the array by 8 bytes (one `int`), `x1` counts down, `x2` is the sum. When `x1` is 0 the jump goes to `done`. Because there is no frame, no register is saved for you: a naked function may use `x0` to `x17` freely; if you need `x19` and above, save them yourself.

## Lesson 48. Any instruction of the CPU by name

`Cpu::inst("name", operands ...)` puts any instruction that the assembler knows, with registers as operands, so the CPU can do in one instruction what the language has no operator for: `umulh` is the high 64 bits of a 128-bit product, `rbit` reverses all 64 bits, `rev` reverses the 8 bytes.

```jk
#import <stdlib>
using stdlib;

naked int mulhi(int a, int b) {
    Cpu::inst("umulh", x0, x0, x1);
    ret;
}

naked int reverse_bits(int a) {
    Cpu::inst("rbit", x0, x0);
    ret;
}

naked int swap_bytes(int a) {
    Cpu::inst("rev", x0, x0);
    ret;
}

void main() {
    jout << mulhi(0x8000000000000000, 6) << " " << mulhi(100, 100) << "\n";
    jout << reverse_bits(1) << " " << reverse_bits(6) << "\n";
    jout << swap_bytes(1) << " " << swap_bytes(0x0102030405060708) << "\n";
}
```

Output:

```
3 0
-9223372036854775808 6917529027641081856
72057594037927936 578437695752307201
```

`0x8000000000000000 * 6` is 3 times 2^64, so the high half is 3. `rbit(1)` puts the lowest bit at the top (the number shown is negative because bit 63 is the sign). `rev(1)` is 1 followed by 56 zero bits. The names come from the ARM64 manual; `jcmp file.jk -show NAME` shows what was made. A name the assembler does not know stops the compiler with a message, and `raw<u32>[...]` (lesson 38) writes the machine word itself.

# Part 4: more of the language

## Lesson 49. Names in layers: modules and using

A library function has a name in three layers: `Fs::fs.write(...)` is the namespace `Fs`, the module `fs`, the function `write`. `using Fs;` takes the namespace away, so `fs.write(...)` is enough, and `using Str::str.len;` makes one function available by its short name. The long form always works, so a program can use both. Your own files are brought in with `#import "name"` (lesson 20) and the libraries with `#import <name>`.

```jk
#import <stdlib>
using stdlib;
using Fs;
using Str::str.len;

void main() {
    fs.write("tl_demo.txt", "hello modules\n");
    String text = fs.read("tl_demo.txt");
    jout << text;
    jout << Fs::fs.size("tl_demo.txt") << " " << Str::str.len("abc") << "\n";
    Fs::fs.remove("tl_demo.txt");
}
```

Output:

```
hello modules
14 3
```

Short names make a program read like a script; the long names say where a function comes from. If two modules in use have the same short name, the compiler asks you to write the long form, so nothing is picked by chance.

## Lesson 50. Enums that carry values

A member of an `enum class` can hold values: `Circle(double r)`, `Rect(double w, double h)`, `Empty`. A value of the enum is one thing that is a different member at different times. `switch` takes it apart and gives names to the values (`_` ignores one). Methods go after the members, after a `;`, and `switch self^` looks at the object itself.

```jk
#import <stdlib>

using stdlib;
enum class Color { Red, Green, Blue };

enum class Shape { Circle(double r), Rect(double w, double h), Empty;
    double area(self) {
        switch self^ {
            Shape::Circle(r): return 3.0 * r * r;
            Shape::Rect(w, h): return w * h;
            Shape::Empty: return 0.0;
        }
        return 0.0;
    }
};

void main() {
    Color c = Color::Green;
    switch c {
        Color::Red: jout << "red\n";
        Color::Green: jout << "green\n";
        Color::Blue: jout << "blue\n";
    }
    Shape a = Shape::Circle(2.0);
    Shape b = Shape::Rect(3.0, 4.5);
    Shape e = Shape::Empty;
    jout << a.area() << " " << b.area() << " " << e.area() << "\n";
    switch b {
        Shape::Rect(w, _): jout << "width " << w << "\n";
        _: jout << "something else\n";
    }
}
```

Output:

```
green
12.000000 13.500000 0.000000
width 3.000000
```

`switch` checks that every member is handled unless there is a `_` case, so adding a new member shows every place that has to change. This is the tool for things that come in several shapes: tokens, messages, results.

## Lesson 51. Structs: methods, nesting and arrays

A `struct` groups values and can have methods; `self` is the object. Structs nest (`Line` holds two `Point`s, written `{{...}, {...}}`), they are copied when assigned, an array of them is indexed like any array, and `@p` is a pointer to one (`q^.x` reaches a member through it).

```jk
#import <stdlib>

using stdlib;
struct Point {
    double x;
    double y;
    double dist2(self) { return self.x * self.x + self.y * self.y; }
    void move(self, double dx, double dy) { self.x += dx; self.y += dy; }
}

struct Line {
    Point a;
    Point b;
}

void main() {
    Point p = {3.0, 4.0};
    p.move(1.0, 0.0);
    jout << p.x << " " << p.dist2() << "\n";
    Line l = {{0.0, 0.0}, {6.0, 8.0}};
    jout << l.b.dist2() << "\n";
    Point pts[3];
    for i in 0..3 { pts[i].x = (double)(i + 1); pts[i].y = (double)(i + 1); }
    double total = 0.0;
    for i in 0..3 { total += pts[i].dist2(); }
    jout << total << "\n";
    Point^ q = @p;
    q^.x = 10.0;
    jout << p.x << "\n";
}
```

Output:

```
4.000000 32.000000
100.000000
28.000000
10.000000
```

`p.move(1.0, 0.0)` changes `p` because `self` is the object itself, not a copy. An array of structs is filled one member at a time here; the writing `pts[3] = {{...}}` is not supported yet.

## Lesson 52. Values that free themselves

A struct with a method `free(self)` frees what it holds at the end of the block of the variable. Because of that it is **moved**, not copied: `Buffer b = a;` empties `a` and `b` owns the memory. Passing it to a function by value moves it into the function, which frees it at its end. You write the `free` once and never call it.

```jk
#import <stdlib>

using stdlib;
struct Buffer {
    int^ data;
    int n;
    void free(self) {
        if self.data != null { jout << "freeing " << self.n << "\n"; free[self.data]; }
    }
}

Buffer make(int n) {
    alloc[int^ p = n];
    Buffer b = {p, n};
    return b;
}

void use(Buffer b) {
    jout << "using " << b.n << "\n";
}

void main() {
    Buffer a = make(4);
    Buffer b = a;
    use(b);
    jout << "end of main\n";
}
```

Output:

```
using 4
freeing 4
end of main
```

"freeing 4" is printed once, by `use`, when its parameter ends, before "end of main": the buffer was moved from `a` to `b` to the parameter. There is no double free and no leak, and no garbage collector. Strings, arrays and lists are built the same way.

## Lesson 53. Function pointers and lambdas

A function can be a value: `int(int)^ op = twice;` is a pointer to a function that takes an `int` and gives an `int`. It can be passed to another function (`apply`) and called like a function. A lambda is a function without a name, written where it is used: the result type, the parameters, the body.

```jk
#import <stdlib>

using stdlib;
int twice(int x) { return x * 2; }
int square(int x) { return x * x; }

int apply(int(int)^ f, int v) { return f(v); }

void main() {
    int(int)^ op = twice;
    jout << op(5) << " " << apply(square, 7) << "\n";
    int k = 3;
    int(int)^ addk = int(int x) { return x + 100; };
    jout << apply(addk, k) << "\n";
}
```

Output:

```
10 49
103
```

This is how a sort takes the comparison, a thread takes its work, and a table of commands is made. The type is written like the function: the result, then the parameters in `( )`, then `^`.

## Lesson 54. Numbers of every size

`int` is 64 bits, but a program for a file format or a machine needs other sizes: `u8`, `u16`, `u32`, `u64` (unsigned) and `i8`, `i16`, `i32`. They wrap round when they overflow, the way the hardware does. `sizeof(type)` gives the size in bytes and `(type)value` converts.

```jk
#import <stdlib>

using stdlib;
void main() {
    u8 b = 250;
    b += 10;
    u32 big = 4000000000;
    big += 500000000;
    i32 small = 2000000000;
    small += 2000000000;
    jout << b << " " << big << " " << small << "\n";
    int wide = 4000000000;
    jout << wide + 500000000 << "\n";
    jout << sizeof(int) << " " << sizeof(u8) << " " << sizeof(double) << " " << sizeof(char) << "\n";
    double d = 3.99;
    int t = (int)d;
    char c = (char)65;
    jout << t << " " << c << " " << (int)'z' << "\n";
}
```

Output:

```
4 205032704 -294967296
4500000000
8 1 8 1
3 A 122
```

250 + 10 in a `u8` is 4, 4,000,000,000 + 500,000,000 in a `u32` is 205,032,704, and two billion plus two billion in an `i32` is negative; the same sums in `int` do not wrap. A cast from `double` to `int` cuts the decimals (3.99 becomes 3).

## Lesson 55. Raw memory: alloc, pools and grow

`alloc[int^ p = n];` takes `n` ints from the heap; `p` owns them and they are freed at the end of the block (or at once with `free[p];`). `grow[p = m];` makes the block bigger and keeps the content. A **pool** is one big block cut into pieces: `alloc[pool[12] >> int^ a];` takes 12 ints of the pool for `a` (null when the pool has no room), `free[b];` gives one piece back, `free[pool];` frees everything.

```jk
#import <stdlib>
using stdlib;
void main() {
    alloc[int^ pool = 32];
    alloc[pool[12] >> int^ a];
    alloc[pool[12] >> int^ b];
    for i in 0..3 { a[i] = i + 1; b[i] = (i + 1) * 10; }
    jout << a[2] + b[2] << "\n";
    free[b];
    alloc[pool[12] >> int^ c];
    c[0] = 99;
    jout << a[0] << " " << c[0] << "\n";
    free[pool];

    alloc[int^ p = 2];
    p[0] = 5;
    p[1] = 6;
    grow[p = 8];
    p[7] = 70;
    jout << p[1] << " " << p[7] << "\n";
    free[p];
}
```

Output:

```
33
1 99
6 70
```

A pool is the allocator of lesson 41 (a pointer that moves forward) with the freeing of single pieces added; `c` gets the room that `b` gave back. Use a pool for many small things that live and die together, and check for null when the pool may be too small. The debug build (`jcmp -d`) checks these blocks for writes past the end and for use after free.

## Lesson 56. Raw bytes and data that cannot change

`raw<u32>[0x91008800];` puts a machine word in the code exactly as written (here `add x0, x0, #34`), next to ordinary statements of a naked function. `#pragma read` makes a global variable read-only: a write is an error at compile time, and through a pointer it stops the program, because the page is protected.

```jk
#import <stdlib>

using stdlib;
#pragma read
int limit = 100;

#pragma read begin
int table[4] = {10, 20, 30, 40};
#pragma read end

naked int answer() {
    x0 = 0;
    raw<u32>[0x91008800];
    ret;
}

int main() {
    int sum = 0;
    for i in 0..4 { sum += table[i]; }
    jout << sum << " " << limit << " " << answer() << "\n";
    return 0;
}
```

Output:

```
100 100 34
```

`answer()` is 0 plus 34. Tables that must never change (lookup tables, constants of a format) belong under `#pragma read`: a bug that overwrites one is found at once instead of much later. The raw word is for ARM64; on the ARM32 target the same instruction is another word.

## Lesson 57. Building a project with makej

A project with several files and programs is built by **makej** (install it with `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp-Tools/main/install.sh | sh -s -- makej`). The build file is a plain file called `makej` that you write by hand (`nano makej`, or `makej init` writes a start). Each `[program.NAME]` is a program to build from its `main` file (with the `flags` you give), each `[library.NAME]` a library (`-l`), and each `[step.NAME]` any shell command; `needs` lists what must be made first. This is the first program of the project, `src/hello.jk`:

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "hello\n";
}
```

Output:

```
hello
```

The whole `makej` file of the project:

```
[makej]
out = "_out"

[program.hello]
main = "src/hello.jk"

[program.tool]
main = "src/tool.jk"
flags = "-d"

[step.run]
run = "_out/hello && _out/tool"
needs = "hello tool"
```

Then, in the folder of the project:

```
$ makej
makej: building hello
makej: building tool
makej: done
$ makej
makej: done
$ makej -v run
makej: hello is up to date
makej: tool is up to date
makej: run
  $ _out/hello && _out/tool
hello
tool
makej: done
```

The first `makej` builds everything; the second finds nothing to do, because a program is built again only when a `.jk` or `.j` file in the folder of its main file (and below) is newer than the result. `makej NAME` makes one target and what it needs; `-v` shows the commands. Targets whose main files are in the same folder are built together when a file there changes. A wrong name gives `makej: there is no target 'nosuch'` and exit code 2.

## Lesson 58. Several cores, and the build file as a program

`makej -j 4` builds 4 things at the same time (the default is the number of cores that are on, 8 on a phone like this one): a target starts as soon as what it needs is done, and if one fails the others that run finish, nothing new starts, and the exit code is 1. When a build needs a loop or a condition, write the build file as a J2K program instead, `makej.jk` (it wins over the plain file when both exist):

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "a build file is a program\n";
}
```

Output:

```
a build file is a program
```

This is the `makej.jk` of a project that builds a program for each source file in a folder, with a loop:

```jk-no
#import <stdlib>
#import <makej>

int main() {
    Build b = Build::make();
    String[] files = Dir::list("tools").unwrap();
    for i in 0..files.len {
        if files[i].ends_with(".jk") {
            b.program(Path::stem(files[i]), "tools/" + files[i], "");
        }
    }
    return b.run();
}
```

`Build::make()` reads the command line (`-j`, `-v`, the target), `b.program`, `b.library` and `b.step` add targets, `b.needs(a, b)` orders them, and `b.run()` builds and gives the exit code. It is an ordinary program, so everything in this tutorial works in it. For the plain file and for the program the engine is the same.

## Lesson 59. Shared libraries: export and -l

A program is not the only thing the compiler can make. With `-l` it makes a **shared library** (`.so`) whose entry points are the functions marked `export`. This is how J2K code becomes the "brain" of an Android app or a helper of any other program. The file below is a normal program here, so that this lesson can run; the library code comes after it.

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "a library has no main; this lesson is a program so that it runs\n";
}
```

Output:

```
a library has no main; this lesson is a program so that it runs
```

```jk-no
export int add(int a, int b) { return a + b; }
export double half(double x) { return x / 2.0; }

int counter = 10;
export int next() { counter = counter + 1; return counter; }
```

Build it with  `jcmp mylib.jk -l -o libmy.so`  and any program can load it: a C program, an Android app (JNI, `System.loadLibrary`), or python:

```
$ python3 -c "import ctypes; L = ctypes.CDLL('./libmy.so'); print(L.add(2, 3), L.next(), L.next())"
5 11 12
```

An `export` function follows the calling rules of the platform: integers in `x0 ..`, a `double` in `d0 ..`. Parameters and results may be `int`, `bool`, `char` and `double` (up to 8 parameters); String, arrays and structs do not cross the border yet. The library keeps its own variables (`counter` starts at 10 when the library is loaded) and its own heap. Not yet: `jout` inside a library.

## Lesson 60. Scripts with jsh, and writing on the phone

The commands of the shell are programs too. Here the lesson program stands for the program you will write on the phone; below it, a script.

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "write it with coderin, build it with jcmp, run it\n";
}
```

Output:

```
write it with coderin, build it with jcmp, run it
```

`jsh`, the shell of Jaric, runs scripts. A script is a text file; `jsh script.sh a b` runs it (`$1` is `a`, `$2` is `b`). These are the pieces:

```jk-no
name=world
echo hello $name                        # variables, and comments
if [ -f notes.txt ]; then echo found; else echo missing; fi
for f in *.jk; do echo file $f; done    # globs
n=0
while [ $n -lt 3 ]; do n=$((n + 1)); done     # arithmetic
count=$(dir *.jk | wc -l)               # the output of a command
hello() { echo hi $1; }                 # a function
hello jao
```

To write and build on the phone: `coderin hello.jk` (Ctrl-S saves, Ctrl-Q quits), then `jcmp hello.jk -o hello && ./hello`. In `makej` a build is a file too.

## Lesson 61. The libraries of the phone: `-dyn` and `<native>`


A normal J2K program is *static*: it is one file that talks to the kernel with system calls and needs nothing else. The graphics chip, however, is reached through the libraries of the phone (`libvulkan.so`, `libEGL.so`, `libGLESv3.so`, `libOpenCL.so`). To use them the program must be *dynamic*: the loader of Android starts it and gives it `libdl.so` and `libc.so`. You ask for that with one option:

```
jcmp -dyn gpu.jk -o gpu       # a dynamic executable; it runs in Termux and in the Jaric app, without any other app
```

The library `<native>` does the rest: `Native::open("libvulkan.so")` gives a *handle* (0 when the library is not there), `Native::sym(handle, "name")` gives the address of a function, and `Native::call1 .. call8` call it with whole numbers and pointers (the answer is the whole number the function returns). Memory that a C function fills is read with `Native::peek32`, `peek64`, `peek8`, and written with `poke32`, `poke64`; `Native::text(address)` makes a String from a C string.

```jk
#import <stdlib>
#import <native>

int main() {
    int lib = Native::open("libvulkan.so");
    if lib == 0 {
        jout << "no libvulkan here, or the program was not built with jcmp -dyn\n";
        return 1;
    }
    int fn = Native::sym(lib, "vkEnumerateInstanceVersion");   // the function: VkResult vkEnumerateInstanceVersion(uint32_t* version)
    char out[16];                                              // room for the number the function writes
    out[0] = 0; out[1] = 0; out[2] = 0; out[3] = 0;
    int result = Native::call1(fn, (int)@out);                 // call it with the address of out
    int v = Native::peek32((int)@out);                         // read the 32 bits it wrote
    jout << "Vulkan " << (v >> 22) << "." << ((v >> 12) & 1023) << "\n";
    return 0;
}
```

On the phone of the author this prints `Vulkan 1.1`. Built the normal (static) way it prints the first message, because a static program has no `libdl.so`.

How it works, in short: the library reads `/proc/self/maps`, finds where `libdl.so` is in memory, reads its symbol table and finds `dlopen` and `dlsym`; a function pointer made from that number is called like any function. Floating point arguments (OpenGL takes many) are passed with `Native::callf1 .. callf4` (floats only) and `Native::calli_f1 .. calli_f4` (a number first, then floats), because the C convention wants them in other registers than J2K uses.

## Lesson 62. OpenGL ES: the first picture, drawn by the chip


`<opengl3>` makes an *off-screen* OpenGL ES context (a surface the size you ask, not shown on the screen) on the real driver, then every call is the same as in the OpenGL ES documentation, spelled the J2K way (`glClearColor` is `gl.clear_color`).

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(64, 64, 3, 1);                    // 64 x 64 pixels, OpenGL ES 3.1 (use 2, 0 for the old 2.0)
    if !gl.ok {
        jout << "no OpenGL here: " << gl.log << "\n";  // gl.log says why
        return 1;
    }
    jout << "chip: " << gl.renderer << "\n";           // for example Mali-G76
    gl.clear_color(1.0, 0.5, 0.0, 1.0);                // red, green, blue, alpha: orange
    gl.clear_color_buffer();                           // the chip paints the whole picture
    String pixels = gl.read_pixels(10, 10, 1, 1);      // read one pixel back: 4 bytes
    jout << (pixels[0] & 255) << " " << (pixels[1] & 255) << " " << (pixels[2] & 255) << "\n";
    gl.close();
    return 0;
}
```

It prints `255 128 0` (the numbers of the orange). `read_pixels` returns the bytes red, green, blue, alpha of each pixel, starting with the bottom row (OpenGL counts up from the bottom). To show a picture on the screen of the Jaric app, send its pixels with the `gfx` messages (the library `<gamej>` shows how), or use the library `<gpu>`, which sends *commands* to the app and lets the app draw on the screen.

## Lesson 63. A triangle and a shader


The chip runs small programs called *shaders*, written in GLSL (a language like C). A *vertex shader* places each corner of a triangle; a *fragment shader* gives each pixel its colour. `gl.program(vertex, fragment)` compiles both and links them; it gives 0 and fills `gl.log` when a shader has a mistake (the message of the driver tells the line).

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(64, 64, 3, 1);
    if !gl.ok { jout << gl.log << "\n"; return 1; }
    String vertex = "#version 300 es\nlayout(location = 0) in vec2 pos;\nvoid main() { gl_Position = vec4(pos, 0.0, 1.0); }\n";
    String fragment = "#version 300 es\nprecision mediump float;\nout vec4 color;\nvoid main() { color = vec4(1.0, 0.5, 0.0, 1.0); }\n";
    int prog = gl.program(vertex, fragment);
    if prog == 0 { jout << "shader: " << gl.log << "\n"; return 1; }
    gl.clear_color(0.0, 0.0, 0.0, 1.0);
    gl.clear_color_buffer();
    gl.use(prog);
    Floats corners = Floats::make(6);                  // three corners, x and y each, from -1 to 1
    corners.set(0, -1.0); corners.set(1, -1.0);
    corners.set(2, 1.0);  corners.set(3, -1.0);
    corners.set(4, 0.0);  corners.set(5, 1.0);
    gl.draw_triangles(corners, 3);
    String inside = gl.read_pixels(32, 20, 1, 1);      // a pixel inside the triangle
    String outside = gl.read_pixels(1, 62, 1, 1);      // a pixel in the top left corner
    jout << (inside[0] & 255) << " " << (outside[0] & 255) << "\n";
    gl.close();
    return 0;
}
```

It prints `255 0`: orange inside, black outside. `Floats` is a block of memory of 32-bit numbers (what the chip reads); `set(i, x)` and `get(i)` use it. The same steps draw thousands of triangles: put many corners in one `Floats`, send them once, draw once.

## Lesson 64. The chip as a calculator: compute shaders


OpenGL ES 3.1 can run a shader that draws nothing and only *computes*. You give it a block of numbers, tell how many groups of threads to start, and the chip runs the same small program on every number at once (hundreds at the same time). `gl.compute(source, data, groups_x, groups_y, groups_z)` does all the steps and gives the changed numbers back.

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(8, 8, 3, 1);
    if !gl.ok { jout << gl.log << "\n"; return 1; }
    // each thread takes one number: v = v * 2 + 1.  local_size_x = 8: a group has 8 threads.
    String shader = "#version 310 es\nlayout(local_size_x = 8) in;\nlayout(std430, binding = 0) buffer Data { float v[]; };\nvoid main() { uint i = gl_GlobalInvocationID.x; v[i] = v[i] * 2.0 + 1.0; }\n";
    Floats data = Floats::make(16);
    for i in 0..16 { data.set(i, (float)i); }
    Floats result = gl.compute(shader, data, 2, 1, 1);   // 2 groups of 8 threads = 16 numbers
    if gl.log.len > 0 { jout << "log: " << gl.log << "\n"; }
    jout << result.get(0) << " " << result.get(5) << " " << result.get(15) << "\n";
    gl.close();
    return 0;
}
```

It prints `1.000000 11.000000 31.000000`. The chip is not faster for a single number; it wins when there are very many numbers and the same work on each: pictures, physics of many bodies, matrices, the layers of a neural network (`<neuron>` can use it later).

## Lesson 65. Vulkan: asking the chip


Vulkan is the modern interface: more to write, more control, less work for the driver. `<vulkan>` is the first step: it makes an *instance*, finds the chip and tells what it can do. The other steps (device, queue, buffers, pipelines) are built in the same way: a structure in memory, a function found by name, `Native::call`.

```jk
#import <stdlib>
#import <vulkan>

int main() {
    Vk vk = Vk::open();
    if !vk.ok { jout << vk.log << "\n"; return 1; }
    jout << vk.device_name << ", Vulkan " << vk.api_text() << "\n";
    jout << "memory " << vk.memory_mb << " MB, queues " << vk.queue_families << ", compute " << vk.has_compute << "\n";
    vk.close();
    return 0;
}
```

On the author's phone: `Mali-G76, Vulkan 1.1.97`, 7460 MB, one queue family that can compute. Build it with `jcmp -dyn`. A Vulkan structure is a block of bytes with the fields at fixed places (the specification gives the offsets): `Native::poke32(address + offset, value)` writes a field; look at the source of `<vulkan>` (`jcmp -showlib vulkan`) to see how `VkApplicationInfo` and `VkInstanceCreateInfo` are filled.

## Lesson 66. Games: Jaric Engine


`makej init -game` makes a project with a small game and five lessons (`makej play1` .. `play5`). The library `<gamej>` is the engine: the loop is yours (`while game.running()`), the engine gives the keys and touches, the time of a turn (`g.dt`), drawing (`clear rect circle line text art`), collision (`Game::overlap`) and sound. In a terminal it draws with half blocks; in the Jaric app it draws on a surface; `makej apk` makes it an Android app, `makej pack` a `.jc` package.

```jk
#import <stdlib>
#import <gamej>

int main() {
    Game g = Game::open("Lesson");            // the whole screen
    double x = 20.0;                          // where the square is
    while g.running() {                       // false after Esc
        g.begin();                            // read the keys, measure the time (g.dt in seconds)
        if g.held(Key::left()) { x -= 40.0 * g.dt; }       // 40 pixels a second: the same speed on every phone
        if g.held(Key::right()) { x += 40.0 * g.dt; }
        g.clear(Game::rgb(10, 20, 40));       // the colour of the sky
        g.rect((int)x, 30, 6, 6, Game::rgb(255, 200, 60));  // x y width height colour
        g.end();                              // show the picture, wait for the next turn
    }
    g.close();
    return 0;
}
```

For the chip itself use `<gpu>` in the app (triangles, pictures, tints: one batch of commands per picture) or `<opengl3>` / `<vulkan>` in a dynamic program. The plan of the engine (layers, a scene system like Godot's, the API like MonoGame's) is in the documents of the Jaric project.

## Lesson 67. Talking to the web: `<web>`


Most services of the net speak HTTP. `#import <web>` is a client: one call, the answer has a **status** (200 is good, 404 not found ...), the **headers** and the **body**. A status of 400 or more is *not* an error of the program (the body usually explains it); only a connection that fails is an `Error`.

```jk
#import <stdlib>
#import <web>

int main() {
    Result<HttpResponse, Error> r = Web::get("https://example.org/", "");     // url, extra header lines ("" for none)
    switch r {
        Result::Ok(a): {
            jout << "status " << a.status << ", " << a.body.len << " bytes\n";
            jout << "type: " << a.header("content-type") << "\n";             // a header of the answer, any case
        }
        Result::Err(e): { jout << "no answer: " << e.message << "\n"; }
    }
    return 0;
}
```

To send data: `Web::post_json(url, headers, json_text)`, `Web::post_form(url, headers, "a=1&b=2")`, or `Web::request("PUT", url, headers, body)`. Headers are lines separated by `\r\n`; `Web::url_encode(text)` makes a text safe for an address. Redirects are followed (5 at most), `https` works, one request uses one connection.

```jk
#import <stdlib>
#import <web>

// asks an API that answers with JSON and prints one field
int main() {
    String key = "my-secret-key";                                              // never write a real key in a file you share
    Result<HttpResponse, Error> r = Web::post_json("https://example.org/api", "Authorization: Bearer " + key, "{\"question\":\"hello\"}");
    switch r {
        Result::Ok(a): {
            if a.status >= 400 { jout << "the service said " << a.status << ": " << a.body << "\n"; return 1; }
            Result<JsonDoc, Error> pj = Json::parse(a.body);
            switch pj {
                Result::Ok(d): {
                    int n = d.get(0, "answer");                                 // 0 is the top object
                    if n >= 0 { jout << d.text(n) << "\n"; }
                }
                Result::Err(e2): { jout << "not JSON\n"; }
            }
        }
        Result::Err(e): { jout << "no answer: " << e.message << "\n"; }
    }
    return 0;
}
```

**Try:** change the address to a service you use; print `a.head` to see all the headers; ask for an address that does not exist and read the status.

## Lesson 68. A bot that answers: `<telegram>` and `<discord>`


A bot is a program that has an account on a chat service. You make the bot in the service (Telegram: the chat with BotFather; Discord: the developer portal), you get a **token** (a long secret text: keep it out of your files and out of git; read it from an environment variable or a file that only you can read), and the program talks to the service with `<web>` underneath.

```jk
#import <stdlib>
#import <telegram>

int main() {
    String token = "";
    switch Env::get("TG_TOKEN") { Option::Some(t): { token = t + ""; } Option::None: { } }
    if token.len == 0 { jout << "set TG_TOKEN first\n"; return 1; }
    Telegram bot = Telegram::bot(token);
    int next = 0;
    while true {
        switch bot.poll(next, 25) {                                  // waits up to 25 seconds for news (long polling)
            Result::Ok(up): {
                for i in 0..up.count() {
                    TgMessage m = up.get(i);                         // m.chat  m.from  m.text
                    bot.send(m.chat, "you said: " + m.text);
                }
                next = up.next;                                      // where to go on: the messages seen are not given again
            }
            Result::Err(e): { jout << "error: " << e.message << "\n"; return 1; }
        }
    }
    return 0;
}
```

`<discord>` is the same idea. `Discord::bot(token)`, `bot.send(channel, "text")` and `bot.messages(channel, last_id, 20)` (the newest messages, oldest first; keep `ms.last` and give it next time). Numbers of Discord are huge, so channels and messages are **text**. Turn on "Message Content Intent" in the portal or the text of messages is empty.

```jk
#import <stdlib>
#import <discord>

int main() {
    Discord bot = Discord::bot("TOKEN-of-the-bot");
    switch bot.send("123456789012345678", "hello from J2K") {
        Result::Ok(x): { jout << "sent\n"; }
        Result::Err(e): { jout << "failed: " << e.message << "\n"; }         // Discord's own words: 401 = the token is wrong
    }
    return 0;
}
```

Rules of good bots: answer only to people (`by_bot` of a Discord message tells), do not ask too fast (HTTP 429 means wait), never print the token, and test with a bot of your own on a chat of your own before you invite it anywhere.

## Lesson 69. Live news: WebSocket and the Discord Gateway


Asking again and again ("polling") wastes time. A **WebSocket** is a connection that stays open: the server sends a message the moment it has one. `<websocket>` makes one: `Ws::connect("wss://host/path", "")` gives a `WebSocket`; `send_text`, `recv` (waits for the next whole message) and `recv_wait(ms)` (waits at most `ms` milliseconds: kind 0 when nothing came).

```jk
#import <stdlib>
#import <websocket>

int main() {
    switch Ws::connect("wss://example.org/socket", "") {
        Result::Ok(ws): {
            ws.send_text("hello");
            int waited = 0;
            while waited < 10 {
                WsMessage m = ws.recv_wait(1000);                   // one second at most
                if m.kind == 0 { waited += 1; continue; }           // nothing yet: do something else, or wait again
                if m.kind == 8 { jout << "closed: " << m.text << "\n"; break; }
                jout << "got: " << m.text << "\n";                  // kind 1 text, 2 binary
                break;
            }
            ws.close();
        }
        Result::Err(e): { jout << "cannot connect: " << e.message << "\n"; }
    }
    return 0;
}
```

The Gateway of Discord is a WebSocket with rules (hello, identify, a heartbeat every few seconds). `<discord>` does the rules for you: `Gw::connect(token, Gw::intents())` and then `gw.next(1000)` gives the events one by one (and sends the heartbeat inside, so call it often).

```jk
#import <stdlib>
#import <discord>

int main() {
    String token = "TOKEN-of-the-bot";
    Discord bot = Discord::bot(token);
    switch Gw::connect(token, Gw::intents()) {
        Result::Ok(gw): {
            bool run = true;
            while run {
                DcEvent e = gw.next(1000);
                if e.kind == "MESSAGE_CREATE" && !e.by_bot { bot.send(e.channel, "you said: " + e.text); }
                if e.kind == "CLOSED" || e.kind == "RECONNECT" || e.kind == "INVALID_SESSION" { run = false; }
            }
        }
        Result::Err(e): { jout << "cannot connect: " << e.message << "\n"; }
    }
    return 0;
}
```

## Lesson 70. Numbers that learn: tensors and gradients


A neural network is a pile of multiplications whose numbers are adjusted until the answers are right. `<neuron>` gives the pieces. A **`Tensor32`** is a table of 32-bit floats (rows x columns). A **`Graph`** records the calculation, so that it can go backwards and tell how every number should change (a **gradient**).

The smallest learning program: find `w` and `b` so that `y = w x + b` fits points that lie on `y = 2x + 1`.

```jk
#import <stdlib>
#import <neuron>

Graph g;                                         // a Graph is big: keep it in a global (do not pass it around by value)

int main() {
    g = Graph::make();
    int w = g.param(Tensor32::zeros(1, 1));      // a parameter: a number that learns
    int b = g.param(Tensor32::zeros(1, 1));
    g.mark();                                    // what is made until now stays; what comes after is one step
    double[] xv = arr(4);
    xv.push(0.0); xv.push(1.0); xv.push(2.0); xv.push(3.0);
    double[] yv = arr(4);
    yv.push(1.0); yv.push(3.0); yv.push(5.0); yv.push(7.0);
    Tensor32 xs = Tensor32::from_list(4, 1, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    for step in 0..300 {
        int x = g.input(xs);
        int guess = g.add(g.matmul(x, w), b);    // x @ w + b: the four guesses
        int loss = g.mse(guess, ys);             // the mean of the squares of the errors
        g.backward(loss);                        // the gradient of every parameter
        g.sgd(0.1);                              // a small step downhill
        g.clear();                               // forget the step, keep the parameters
    }
    jout << "w = " << g.value(w).get(0, 0) << "  b = " << g.value(b).get(0, 0) << "\n";    // near 2 and 1
    return 0;
}
```

The words: **loss** = how wrong the answers are (smaller is better); **learning rate** = the size of a step (here 0.1; too big and it jumps around, too small and it takes forever); **backward** = the gradients, by the chain rule, from the loss to every parameter. The operations of a `Graph`: `matmul`, `add` (a one-row table is added to every row: the bias), `mul`, `relu`, `tanh`, `sigmoid`, `gelu`, `silu`, `softmax_ce`, `mse`, `embed`, `layer_norm`, `rms_norm`, `attention`, `conv2d`, `maxpool`. Every gradient of the library is checked against a numeric difference in its tests; you can do the same for your own idea (change a number by 0.01 both ways and see that the loss changes as the gradient says).

**Try:** change 300 to 30 steps and watch `w` stop short; change the points to `y = -3x + 4`.

## Lesson 71. Teaching a network: layers, batches and AdamW


One neuron fits a line. To learn a curve or to tell classes apart you need layers with a bend between them. A **`Linear`** layer is `x @ w + b`; between layers put `tanh` (or `relu`) or the layers collapse into one line. The classic test is XOR, which no single line can do.

```jk
#import <stdlib>
#import <neuron>

Graph g;

int main() {
    g = Graph::make();
    Linear l1 = g.linear(2, 8, 1);               // 2 numbers in, 8 out; the last number only seeds the start values
    Linear l2 = g.linear(8, 1, 2);
    g.mark();
    double[] xv = arr(8);
    xv.push(0.0); xv.push(0.0); xv.push(0.0); xv.push(1.0); xv.push(1.0); xv.push(0.0); xv.push(1.0); xv.push(1.0);
    double[] yv = arr(4);
    yv.push(0.0); yv.push(1.0); yv.push(1.0); yv.push(0.0);
    Tensor32 xs = Tensor32::from_list(4, 2, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    double last = 0.0;
    for step in 0..400 {
        int h = g.tanh(g.apply(l1, g.input(xs)));
        int out = g.sigmoid(g.apply(l2, h));                 // 0 .. 1
        int loss = g.mse(out, ys);
        last = (double)g.value(loss).d[0];
        g.backward(loss);
        g.adamw(0.05, 0.0);                                  // AdamW: a learning rate for each number, adjusted as it goes
        g.clear();
    }
    jout << "loss " << last << "\n";
    int h2 = g.tanh(g.apply(l1, g.input(xs)));
    Tensor32 o = g.value(g.sigmoid(g.apply(l2, h2)));
    for i in 0..4 { jout << xs.get(i, 0) << " xor " << xs.get(i, 1) << " = " << o.get(i, 0) << "\n"; }
    g.save("xor.model");                                     // the parameters as a text file
    return 0;
}
```

For many examples use **mini-batches**: `shuffled(n, seed)` gives a mixed order of `0..n-1`, `xs.gather(idx)` takes those rows. `g.clip(5.0)` shrinks a gradient that is too big, and `Sched::cosine(step, total, warm, lr, low)` makes the learning rate rise for `warm` steps and then fall like a cosine. To tell **classes** apart end with `g.softmax_ce(scores, classes)` (one class number per row). To save and load: `g.save(path)`, `g.load(path)` on a graph with the same parameters.

**Watch for:** a loss that does not fall (learning rate too big or too small), a loss on the training data that falls while the loss on data it never saw does not (the model only remembers: give more data or a smaller model).

## Lesson 72. A language model that you train on the phone


A language model reads text and learns which letter (or word) comes next. `Gpt` of `<neuron>` is a small GPT: embeddings, blocks with attention (every place looks at the places before it) and a layer that scores the next token. It works **byte by byte**, so Thai, English and code need no tokenizer.

```jk
#import <stdlib>
#import <neuron>

Gpt m;

int main() {
    String text = "the cat sat on the mat. the dog sat on the log. ";
    String all = "";
    for r in 0..40 { all = all + text; }
    int[] data = Gpt::bytes(all);                            // the text as numbers 0-255
    m = Gpt::make(256, 16, 32, 2, 1, 1);                     // vocabulary, context, width, heads, layers, seed
    int seed = 1;
    for step in 0..200 {
        int[] starts = arr(5);                               // where in the text this batch of 4 sequences starts
        for q in 0..4 { seed = (seed * 1103515245 + 12345) & 2147483647; starts.push(seed % (data.len - 20)); }
        double loss = m.step(data, starts, 0.02, 0.0, 1.0);  // learning rate, weight decay, clip
        if step % 50 == 0 { jout << "step " << step << " loss " << loss << "\n"; }
    }
    jout << "[" << m.write(Gpt::bytes("the cat s"), 24, 0.0, 0, 1) << "]\n";   // temperature 0: the most likely letter each time
    m.save("cats.gpt");
    return 0;
}
```

The tool `neuron` does the same for any file or folder: `neuron gpt train notes.txt`, `neuron gpt train docs/ size=medium minutes=10`, then `neuron gpt write cats.gpt "the cat"`. While it trains it prints the **check** loss, measured on the last tenth of the text that is never learned: that is the number to trust. If the loss on the learned text falls and the check loss does not, the model only remembers.

A model trained on a phone has thousands to a few million numbers and reads megabytes. It learns the style and habits of the text it reads (a code style, a language, your notes) and can complete a line. It does not know the world as the big models do; use it for a narrow job with your own text, with a search in front of it for facts.

## Lesson 73. Running models that others made: GGUF and `<llama>`


Big models are trained elsewhere and shared as **GGUF** files (the format of llama.cpp). `<gguf>` reads them (the header, the words, the tables of numbers) and `<llama>` runs the Llama family on the CPU: RMS norm, rotary positions, grouped-query attention, a gated feed-forward and a cache that remembers the earlier tokens. The weights are usually **quantised** (Q8_0, Q4_0: a byte or four bits per weight with a scale for every 32 weights): the file is 4-8 times smaller and, kept as bytes in memory, a product moves 4 times less memory (the phone's memory bandwidth is the limit, not its multiplications). The product uses the int8 dot product of the chip (`i8x16`, lesson 74).

```jk
#import <stdlib>
#import <llama>

int main() {
    switch Lm::load("stories15M-q4_0.gguf") {                // from huggingface.co/ggml-org/tiny-llamas (19 MB)
        Result::Ok(m): {
            int[] ids = m.encode("Once upon a time");        // token numbers, the start token first
            String story = m.generate(ids, 80, 0.8, 40, 0.95, 1);    // 80 new tokens: temperature, top-k, top-p, seed
            jout << "Once upon a time" << story << "\n";
        }
        Result::Err(e): { jout << "cannot load: " << e.message << "\n"; }
    }
    return 0;
}
```

The temperature decides how daring the choice is (0 = always the most likely token); `top-k` keeps the k best, `top-p` the best ones that together hold p of the chance; the same seed gives the same text. For one token at a time use `m.step(token)` (it gives the scores of the next token) and `m.sample(scores, temp, top_k, top_p)`. The same from the shell: `neuron llama MODEL.gguf "start"` and `neuron bench MODEL.gguf` (tokens per second). On a Kirin 990 the 15 M model writes about 120 tokens a second; a model of 500 M numbers needs a quarter of a gigabyte per token to be read, so a few tokens a second is the wall until the memory gets faster.

## Lesson 74. Fast code: what the language costs and how to ask for speed


Measure before you change. `bench/lang.jk` of the repository times the small costs on your phone. What it showed on a Kirin 990 (one core):

| what | cost |
|---|---|
| `s += a[i]` over an `int[]` (checked) / through an `int^` pointer | 1.4 ns / 1.0 ns: the checks cost about 40 % |
| `f += xs[i]` over a `float[]` | 4 ns: floats are slower than whole numbers now (a known weakness) |
| a call of a tiny function | 2 ns |
| 8 million reads of a big array: in a row / 16 apart / at random places | 2.5 / 6.5 / 23 ns each: **the cache decides** |

Three habits that always pay: **walk memory in order** (the inner loop over the index that is next to the other in memory), **work in blocks** that fit the cache (the matrix product of `<neuron>` takes four columns of two rows at a time), and **let the chip do many numbers at once**. `<simd>` has vectors of one register: `f32x4` (four floats), `i32x4`, `f64x2`, and `i8x16` (sixteen bytes).

```jk
#import <stdlib>
#import <simd>

// the dot product of two float arrays, four numbers at a time
float dot(float^ a, float^ b, int n) {            // n a multiple of 4
    f32x4 acc = {0.0, 0.0, 0.0, 0.0};
    int i = 0;
    while i < n {
        acc = acc + f32x4::load(a, i) * f32x4::load(b, i);     // one load and one multiply-add for four numbers
        i += 4;
    }
    return acc.sum();
}

int main() {
    float[] a = arr(1001);
    float[] b = arr(1001);
    for i in 0..1000 { a.push((float)i * 0.001); b.push(2.0); }
    jout << dot(@a[0], @b[0], 1000) << "\n";     // 999
    return 0;
}
```

`i8x16` has one more trick, `a.dot(b)`: the dot product of sixteen bytes by sixteen bytes into four 32-bit sums in **one instruction** (the SDOT of the Cortex-A76). It is what makes a quantised model fast: `i32x4 d = i8x16::load(w, i).dot(i8x16::load(x, i));`. Keep a function with vectors small, with no calls inside the loop, so that the compiler can keep every vector in a register (look with `jcmp -show NAME file.jk` and `jcmp -irstat file.jk`). A function can have at most 8 parameters. And compare with a plain C version when it matters: the aim of J2K is to be within a small factor of C, and the numbers of `bench/` say where it is now.

## Lesson 75. Programs and libraries from the net: `jc`


`jc` brings things to the phone. Four kinds, one command each:

```text
jc install NAME          a tool of Jcmp-Tools (jsh, neuron, mulap, imgj ...), or a package (git, python, clang ...)
jc tools                 the list of tools         jc update        every tool and package that has a newer version
jc lib list              the libraries of J2K      jc lib install web telegram    a library for #import <name>
jc pkg search git        look in the packages      jc pkg list | remove NAME
jc install FILE.jc       a program of the Jaric store (it asks for the permissions it wants)
```

The tools are single programs written in J2K (`jc install neuron`). The **packages** are the programs of other people built for the prefix of the Jaric app (`jc install git`, `python`, `python-pip`, `clang`, `dropbear`): they are unpacked into the prefix and listed in `usr/var/lib/jcpkg/NAME.list` so that `jc pkg remove NAME` takes away exactly what was put there. The libraries are single files (`#import <name>`): `jc lib install NAME` puts the file where the compiler looks. Everything is checked with a SHA-256 before it is put in place; if a checksum is wrong nothing is installed.

To share your own tool: a folder with the program, `build.sh`, `test.sh`, `README.md`, `CHANGELOG.md`, `VERSION`; test it, release it as the repository Jcmp-Tools does, and a line in `tools.txt` makes `jc install` find it. Every tool and library must have a README that says what it is, how to install it and how to use it with an example that works: when you read a README that does not teach you, fix the README.

# Part 4: from the numbers to the machine

## Lesson 76. Counting in base 2 and base 16


A computer has only two digits, 0 and 1, because a wire is on or off. A number in **base 2** is written with them: `1011` means 1x8 + 0x4 + 1x2 + 1x1 = 11. Each place is worth twice the place on its right: 1, 2, 4, 8, 16, 32, 64, 128 ... A place is a **bit**; eight bits are a **byte** (0 to 255). **Base 16** (hex) has sixteen digits, `0-9` and `a-f`, and one hex digit is exactly four bits, which is why people read bytes in hex: `0xB0` is `1011 0000`.

```jk
#import <stdlib>

// the number n as `width` bits, the highest first
String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

// the number n as hex digits (at least `width` of them)
String hex(int n, int width) {
    String digits = "0123456789abcdef";
    String s = "";
    int i = width - 1;
    while i >= 0 {
        int d = (n >> (4 * i)) & 15;
        s.push(digits[d]);
        i -= 1;
    }
    return s;
}

int main() {
    for n in 0..9 { jout << n << " = " << bits(n, 8) << " = 0x" << hex(n, 2) << "\n"; }
    jout << "255 = " << bits(255, 8) << " = 0x" << hex(255, 2) << "\n";
    jout << "256 = " << bits(256, 9) << " = 0x" << hex(256, 3) << "\n";
    int x = 0;
    for i in 0..8 { x = x * 2 + (i % 2); }                  // shifting left and adding a bit is how a number is read digit by digit
    jout << x << " = " << bits(x, 8) << "\n";                // 01010101 = 85
    return 0;
}
```

`n >> i` moves the bits `i` places to the right, `& 1` keeps the lowest one: so `(n >> i) & 1` is bit number `i`. Doubling a number moves all its bits one place left (`n << 1`), halving moves them right. A byte holds 8 bits, a `short` 16, an `int` of J2K 64.

**Try:** print the powers of two up to 2^16 in binary and hex; write a function that turns the text `"1011"` into 11.

## Lesson 77. Negative numbers: two's complement


How are negative numbers made of bits? The CPU uses **two's complement**: for 8 bits, the number -1 is `11111111`, -2 is `11111110`, ... -128 is `10000000`. The highest bit is the sign (1 = negative) and it is worth -128 instead of +128. The rule to negate: **flip every bit and add one**, so that `x + (-x)` is all zeros plus a carry that falls off the end. Then the same adder circuit adds positive and negative numbers, and subtraction needs no new part.

```jk
#import <stdlib>

String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

int main() {
    for n in 0..4 { jout << "-" << n << " in 8 bits: " << bits(-n, 8) << "\n"; }       // 00000000 11111111 11111110 11111101
    int five = 5;
    int flipped = five xor 255;                     // every bit of the 8 turned over
    jout << "flip 5: " << bits(flipped, 8) << "  plus one: " << bits((flipped + 1) & 255, 8) << " = " << bits(-5, 8) << "\n";
    i8 small = 127;                                  // the biggest i8
    small += 1;                                      // one more wraps round to the smallest
    jout << "127 + 1 in an i8 = " << small << "\n";
    u8 byte = 200;
    byte += 100;                                     // 300 does not fit: 300 - 256
    jout << "200 + 100 in a u8 = " << byte << "\n";
    jout << "the same bits, two meanings: " << bits(200, 8) << " is 200 as u8, " << (200 - 256) << " as i8\n";
    return 0;
}
```

An `int` of J2K has 64 bits, so its smallest number is -2^63 and its largest 2^63 - 1; adding one to the largest wraps to the smallest. `i8`, `i16`, `i32` and `u8` ... `u64` (lesson 54) show the same thing in smaller sizes. When a small signed number is made wider, the sign bit is copied to the new places (**sign extension**): `11111110` as 8 bits and `1111111111111110` as 16 bits are both -2.

**Try:** what are 100 + 100 in an i8, 0 - 1 in a u8? Make the answer by hand with bits first.

## Lesson 78. Numbers with a point, inside


A `double` is 64 bits in three parts (**IEEE 754**): 1 bit of sign, 11 bits of exponent, 52 bits of fraction. The value is `(-1)^sign x 1.fraction x 2^(exponent - 1023)`. A `float` has 1 + 8 + 23 bits. So the numbers that a float can hold are not evenly spread: there are as many between 1 and 2 as between 1024 and 2048. And a number like 0.1 has no exact form in base 2 (as 1/3 has none in base 10), which is why `0.1 + 0.2` is not exactly `0.3`.

```jk
#import <stdlib>

String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

void show(double d) {
    int^ p = (int^)@d;                               // the same 8 bytes, looked at as a whole number
    int raw = p[0];
    int sign = (raw >> 63) & 1;
    int exponent = (raw >> 52) & 2047;
    int fraction = raw & 4503599627370495;           // the lowest 52 bits
    jout << d << ": sign " << sign << ", exponent " << bits(exponent, 11) << " (" << exponent - 1023 << "), fraction " << bits(fraction >> 40, 12) << "...\n";
}

int main() {
    show(1.0);
    show(2.0);
    show(0.5);
    show(-6.0);                                      // -1.5 x 2^2
    show(0.1);
    double s = 0.1 + 0.2;
    if s == 0.3 { jout << "0.1 + 0.2 is 0.3\n"; } else { jout << "0.1 + 0.2 is not exactly 0.3\n"; }
    return 0;
}
```

Compare numbers that are measured with a small margin (`abs(a - b) < 0.000001`), never with `==`. And do not add a very small number to a very big one: the small one is lost, because the fraction has only 52 bits (`1e16 + 1.0` is `1e16`).

**Try:** show the bits of 3.0 and work out the sign, exponent and fraction by hand; find the smallest `x` for which `1.0 + x == 1.0` (start with 1.0 and halve it).

## Lesson 79. From logic gates to an adder


A CPU is made of **gates**: AND, OR, XOR, NOT. With them you can add. Adding two bits `a + b` gives a sum bit and a carry bit: the sum is `a xor b` and the carry is `a and b` (a **half adder**). With a carry coming in too, it is a **full adder**, and eight of them in a row, each passing its carry to the next, add two bytes (a **ripple adder**). This is what the `add` instruction is, in silicon.

```jk
#import <stdlib>

// one full adder: three bits in (a, b and the carry from the right), two bits out
// the sum goes in sum[0], the carry out is the result
int full_adder(int a, int b, int carry_in, int^ sum) {
    int x = a xor b;
    sum[0] = x xor carry_in;
    return (a & b) | (x & carry_in);
}

// two 8-bit numbers added with eight full adders in a row
int add8(int a, int b) {
    int result = 0;
    int carry = 0;
    int sum[1];
    for i in 0..8 {
        carry = full_adder((a >> i) & 1, (b >> i) & 1, carry, @sum[0]);
        result = result | (sum[0] << i);
    }
    return result;                                   // a carry out of the last place falls off, as in a u8
}

// the multiplier of school: shift and add
int mul8(int a, int b) {
    int result = 0;
    for i in 0..8 {
        if ((b >> i) & 1) == 1 { result = add8(result, (a << i) & 255); }
    }
    return result;
}

int main() {
    jout << add8(100, 55) << " " << add8(200, 100) << " " << add8(255, 1) << "\n";      // 155 44 0
    int bad = 0;
    for a in 0..256 { for b in 0..256 { if add8(a, b) != (a + b) & 255 { bad += 1; } } }
    jout << "all 65536 sums agree with +: " << (bad == 0) << "\n";
    jout << mul8(12, 11) << " " << mul8(20, 20) << "\n";                                  // 132 144 (400 wraps)
    return 0;
}
```

The real CPU does the eight (or 64) places at once with a clever **carry-lookahead** circuit, so that the carry does not have to walk through every place. But the idea is the same, and so you see why `a + b` takes one cycle and why a division does not.

**Try:** build a subtractor from `add8` (negate with the rule of lesson 77: flip and add one); build a 4-bit comparator with gates only.

## Lesson 80. A tiny CPU of our own


What does a processor do? It repeats three steps forever: **fetch** the next instruction from memory at the place of the **program counter**, **decode** it (which operation, which registers), **execute** it. Here is a whole CPU in a few lines: four registers, a memory of bytes, and seven instructions that are one byte for the operation and one or two bytes for the numbers. It is a **virtual machine**; a real chip is the same story with more instructions and more speed.

| opcode | meaning |
|---|---|
| 1 r n | `r = n` (load a number) |
| 2 r s | `r = r + s` (add register s) |
| 3 r s | `r = r - s` |
| 4 r n | `if r != 0 then pc = n` (a jump) |
| 5 r | print register r |
| 6 | stop |

```jk
#import <stdlib>

int[] mem;                                           // the program, as bytes
int reg[4];
int pc;

// one step: fetch, decode, execute; false after the instruction "stop"
bool step() {
    int op = mem[pc];                                // fetch
    if op == 1 { reg[mem[pc + 1]] = mem[pc + 2]; pc += 3; }                          // r = n
    else if op == 2 { reg[mem[pc + 1]] += reg[mem[pc + 2]]; pc += 3; }              // r = r + s
    else if op == 3 { reg[mem[pc + 1]] -= reg[mem[pc + 2]]; pc += 3; }              // r = r - s
    else if op == 4 { if reg[mem[pc + 1]] != 0 { pc = mem[pc + 2]; } else { pc += 3; } }   // jump if not zero
    else if op == 5 { jout << "r" << mem[pc + 1] << " = " << reg[mem[pc + 1]] << "\n"; pc += 2; }
    else { return false; }                           // 6 (or anything else): stop
    return true;
}

int main() {
    mem = arr(32);
    // r0 = 0 (the sum), r1 = 5 (the counter), r2 = 1: add the counter to the sum, count down, until the counter is 0
    int[] program = arr(24);
    program.push(1); program.push(0); program.push(0);          //  0: r0 = 0
    program.push(1); program.push(1); program.push(5);          //  3: r1 = 5
    program.push(1); program.push(2); program.push(1);          //  6: r2 = 1
    program.push(2); program.push(0); program.push(1);          //  9: r0 = r0 + r1
    program.push(3); program.push(1); program.push(2);          // 12: r1 = r1 - r2
    program.push(4); program.push(1); program.push(9);          // 15: if r1 != 0 then jump to 9
    program.push(5); program.push(0);                           // 18: print r0
    program.push(6);                                            // 20: stop
    for i in 0..program.len { mem.push(program[i]); }
    pc = 0;
    int steps = 0;
    while step() { steps += 1; }
    jout << "ran " << steps << " instructions\n";                // the sum 5+4+3+2+1 = 15 printed once
    return 0;
}
```

Every program is just numbers in memory; the CPU does not know which bytes are code and which are data, the program counter decides. That is why a bug can run your data as code, and why a **jump** (changing `pc`) is all that a loop or an `if` is, at this level. The tiny machine above has no way to call a function: add a register that holds a return address (a **link register**, `x30` in ARM64) and two instructions, `call n` and `ret`, and it can.

**Try:** add an instruction `7 r s` that multiplies; write a program with it that computes 5 x 4 x 3; add a memory instruction `load r a` / `store r a`.

## Lesson 81. An assembler for the tiny CPU


Numbers are hard for people, so an **assembler** turns text like `add r0, r1` into the numbers (**machine code**). It reads a line, looks up the word (the **mnemonic**), reads the operands and writes the bytes. Labels (names of places) are resolved in a second pass because a jump may go forward. Here is a small one for the machine of lesson 80.

```jk
#import <stdlib>

// the register number of "r2": 2 (or -1)
int reg_of(String w) {
    if w.len == 2 && w[0] == 'r' && w[1] >= '0' && w[1] <= '3' { return w[1] - '0'; }
    return -1;
}

// the lines of a program, one instruction each: "load r1, 5" "add r0, r1" "sub r1, r2" "jnz r1, loop" "print r0" "stop", and "name:" for a label
// returns the bytes, or an empty array when a line is wrong (the message says which)
int[] assemble(String[] lines) {
    String[] labels = arr(8);
    int[] at = arr(8);
    int[] out = arr(64);
    int[] none = arr(1);
    for pass in 0..2 {                                       // pass 0 finds where the labels are, pass 1 writes the bytes
        out = arr(64);
        for k in 0..lines.len {
            String line = lines[k].trim();
            if line.len == 0 { continue; }
            if line[line.len - 1] == ':' {
                if pass == 0 { labels.push(line.slice(0, line.len - 1) + ""); at.push(out.len); }
                continue;
            }
            String[] w = line.replace(",", " ").split(" ");
            String[] p = arr(4);
            for i in 0..w.len { if w[i].len > 0 { p.push(w[i] + ""); } }
            String m = p[0];
            if m == "load" { out.push(1); out.push(reg_of(p[1])); out.push(p[2].to_int()); }
            else if m == "add" { out.push(2); out.push(reg_of(p[1])); out.push(reg_of(p[2])); }
            else if m == "sub" { out.push(3); out.push(reg_of(p[1])); out.push(reg_of(p[2])); }
            else if m == "jnz" {
                int target = -1;
                for j in 0..labels.len { if labels[j] == p[2] { target = at[j]; } }
                if target < 0 && pass == 1 { jout << "unknown label " << p[2] << "\n"; return none; }
                out.push(4); out.push(reg_of(p[1])); out.push(target);
            }
            else if m == "print" { out.push(5); out.push(reg_of(p[1])); }
            else if m == "stop" { out.push(6); }
            else { jout << "unknown instruction " << m << " in the line: " << line << "\n"; return none; }
        }
    }
    return out;
}

int main() {
    String[] src = arr(12);
    src.push("load r0, 0"); src.push("load r1, 5"); src.push("load r2, 1");
    src.push("again:");
    src.push("add r0, r1"); src.push("sub r1, r2"); src.push("jnz r1, again");
    src.push("print r0"); src.push("stop");
    int[] code = assemble(src);
    String line = "";
    for i in 0..code.len { line = line + str(code[i]) + " "; }
    jout << code.len << " bytes: " << line << "\n";           // the program of lesson 80
    String[] bad = arr(2);
    bad.push("jump somewhere");
    assemble(bad);                                            // unknown instruction jump in the line: jump somewhere
    return 0;
}
```

The real assembler of J2K is the same in kind (`jcmp/jc_asm.j`), only the instructions are ARM64's: each one is one 32-bit word with fields for the operation and the registers (lesson 82). It also has to choose between several encodings of one mnemonic (a short and a long jump) and to check that a number fits its field: a good assembler says "the number does not fit" rather than writing a wrong word.

**Try:** add the instruction `mul`; make the assembler say the line number of a mistake; write a "disassembler" that turns the bytes back into text.

## Lesson 82. The real thing: an ARM64 instruction as 32 bits


Every instruction of the ARM64 CPU of the phone is exactly **32 bits**, cut into fields. `add x1, x1, x2` (64-bit register add) is:

```
 31 30 29 28-24 23-22 21 20-16  15-10  9-5  4-0
  1  0  0 01011  00    0  Rm    000000  Rn   Rd        =  0x8B000000 | (Rm << 16) | (Rn << 5) | Rd
```

`Rm` = 2, `Rn` = 1, `Rd` = 1 gives `0x8B020021`. A program can build the word itself and compare it with the number that the assembler of the compiler made (lesson 38 shows how `raw<u32>[...]` puts a word in the code).

```jk
#import <stdlib>

String hex(int n, int width) {
    String digits = "0123456789abcdef";
    String s = "";
    int i = width - 1;
    while i >= 0 { s.push(digits[(n >> (4 * i)) & 15]); i -= 1; }
    return s;
}

// add xd, xn, xm  (64 bits)
int encode_add(int d, int n, int m) { return 0x8B000000 | (m << 16) | (n << 5) | d; }

// sub xd, xn, xm
int encode_sub(int d, int n, int m) { return 0xCB000000 | (m << 16) | (n << 5) | d; }

// mov xd, #imm16  (movz: the number in bits 5-20)
int encode_movz(int d, int imm) { return 0xD2800000 | (imm << 5) | d; }

int main() {
    jout << "add x1, x1, x2  = 0x" << hex(encode_add(1, 1, 2), 8) << "\n";     // 8b020021
    jout << "sub x0, x3, x4  = 0x" << hex(encode_sub(0, 3, 4), 8) << "\n";     // cb040060
    jout << "mov x5, #1000   = 0x" << hex(encode_movz(5, 1000), 8) << "\n";    // d2807d05
    // run the word that we built: x1 = x1 + x2 through a raw machine word
    int a = 40;
    int b = 2;
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        raw<u32>[0x8b020021];                        // the word that encode_add(1, 1, 2) made
        out x1 = r;
    }
    jout << a << " + " << b << " = " << r << " (done by the word)\n";
    return 0;
}
```

Look at the machine code that the compiler makes for your own function with `jcmp -show NAME file.jk`: the lines are the instructions in text, and `jcmp --emit-asm` keeps the whole text. Because every instruction has the same size, the CPU can find the next one at once (`pc + 4`) and decode many together; a CPU with instructions of different lengths (x86) needs more work to find where one ends. The registers `x0` to `x7` carry the arguments of a call and `x0` the result; `x29` is the frame, `x30` the return address, `sp` the stack: lessons 35 to 48 use them.

**Try:** encode `ldr x0, [x1]` (`0xF9400020` is `ldr x0, [x1, #0]`: find the fields); run `jcmp -show` on a function that adds two numbers and find the `add` in it, then decode its bits by hand.

## Lesson 83. Laying out the output: columns, digits, hex


`jout <<` prints a value as it is. For tables, money and addresses you want it laid out: so many digits, a column of fixed width, a number in base 16. There is no format string (`%5.2f`) in J2K and no new syntax: the layout is done by ordinary functions, and you put them inside the stream.

| function | gives | example |
|---|---|---|
| `fmt(x, 2)` | a double with 2 digits after the point | `fmt(2.0 / 3.0, 3)` is `0.667` |
| `tohex(n)` | the number in base 16 | `tohex(48879)` is `beef` |
| `tobin(n)` | the number in base 2 | `tobin(37)` is `100101` |
| `pad(s, w)` | the text, then spaces up to `w` characters (left aligned) | `pad("tea", 6)` is `tea   ` |
| `padl(s, w)` | spaces, then the text (right aligned: for numbers) | `padl("7", 3)` is `  7` |

The longer names are in `Fmt`: `Fmt::fixed`, `Fmt::thousands(1234567)` (`1,234,567`), `Fmt::percent(0.256, 1)` (`25.6%`), `Fmt::bytes(1536)` (`1.5 KB`), `Fmt::pad_left(s, w, '0')` (pad with any character). A text that is longer than the width is not cut.

```jk
#import <stdlib>
using stdlib;

int main() {
    String[] items = arr(3);
    items.push("tea"); items.push("rice"); items.push("coconut milk");
    int[] cents = arr(3);
    cents.push(1250); cents.push(499); cents.push(1500000);
    for i in 0..items.len {
        jout << pad(items[i], 14) << padl(Fmt::thousands(cents[i] / 100), 9) << "." << Fmt::pad_left(str(cents[i] % 100), 2, '0') << "\n";
    }
    jout << "ratio " << fmt(2.0 / 3.0, 3) << "   hex " << tohex(48879) << "   bits " << tobin(37) << "\n";
    return 0;
}
```

Output:

```
tea                  12.50
rice                  4.99
coconut milk     15,000.00
ratio 0.667   hex beef   bits 100101
```

(Prices are kept in cents so that the sum is exact; the last column is the euros part with thousands, a point and the cents with a zero in front.) Why no `printf`? The compiler knows the type of every value in the stream, so you cannot write `%d` for a double by mistake, and the language stays small.

**Try:** print the multiplication table of 1 to 9 in columns of width 4 with `padl`; print `255` as `ff`, `11111111` and `0xFF` (join `"0x"` and `tohex`).

## Lesson 84. The screens of an app: `<ui>`


An Android app made with `makej init -apk` draws every frame itself with OpenGL ES. `<ui>` (install with `jc lib install ui`) gives it buttons, labels, switches and sliders. It works in *immediate mode*: each frame you call the widgets from the top down; a widget draws itself and **tells you what happened**, so there is nothing to keep in step with your data.

```text
Ui u;                              // one for the app
bool sound;  double speed;  int taps;

// game_init:   u.start();                    game_touch(a, x, y, id):  u.touch(a, x, y);
// game_frame:  Canvas2d^ c = glapp_canvas();  c^.begin();  c^.clear(u.th.bg);
//              u.begin(c, (double)glapp_w(), (double)glapp_h());
//              u.title("MY APP");
//              if u.button("TAP ME") { taps += 1; }            // true in the frame of the click
//              u.toggle("SOUND", @sound);                        // a tap changes sound
//              u.slider("SPEED", @speed, 0.0, 10.0);             // dragging changes speed
//              u.cols(2);  u.button("A");  u.button("B");  u.end_cols();   // side by side
//              u.end();  c^.end();
```

A button clicks when the finger goes down **and up** inside its box (a user who slides away changes their mind). Colours and sizes are in `u.th`. The text is a 3 x 5 font of capital letters, digits and signs for now (lower case and Thai are planned). A page is a function that calls widgets and returns the number of the next page; see `docs/UI.md` for the page pattern and for how to test the screens without a phone (a pretend canvas that counts the drawing: `test/t573_ui.jk`).

**Try:** add a slider that sets the size of a square you draw under the widgets with `c^.rect`.

## Lesson 85. An apk without the Android tools: `apkj`


An apk is a zip file with five kinds of part: a binary `AndroidManifest.xml`, a (nearly empty) `resources.arsc`, a `classes.dex` (the small Java part that starts your native library), your `libgame.so`, and a signature. The usual tools (`aapt2`, `ecj`, `d8`, `zipalign`, `apksigner`, Java) are heavy on a phone. `apkj` is a tool written in J2K that makes all of it itself, and the signature too (ECDSA P-256 with its own certificate):

```text
apkj key                                           # makes ~/.apkj.key once; keep it (an update of an app must be signed with the same key)
apkj build manifest.toml MyApp.apk lib/arm64-v8a/libgame.so=_out/libgame.so assets/data/hello.txt=assets/hello.txt
```

`makej apk` calls it for you when the Android tools are missing (or with `MAKEJ_APKJ=1`) for an app with `render = "gl"` and no `icon.png`. The check is made with the tools that already exist: `apksigner verify MyApp.apk` says `Verifies`, `aapt2 dump badging MyApp.apk` shows the name and the version, and `unzip -t` finds no error. If a tool is missing, `makej` says what to install (`jc install apkj` or the packages) instead of failing with a long message.

**Try:** make the manifest with `apkj manifest manifest.toml AndroidManifest.xml` and open the result with `aapt2 dump xmltree MyApp.apk --file AndroidManifest.xml` (after `apkj build`); change `version` in `manifest.toml` and watch `versionCode` follow (`major * 10000 + minor * 100 + patch`).

## Lesson 86. Looking at part of an array: Span

Sometimes a function should work on a part of an array: the middle, the last ten, one row of a table. Copying that part wastes time and memory. A **Span** is a view: it points into the array and remembers where it starts and how long it is. `a[2..6]` makes a Span of the elements 2, 3, 4 and 5 (the end is not included, like `for i in 2..6`). The Span does not copy anything: writing through it changes the array.

```jk
#import <stdlib>

using stdlib;
// the sum of a part of an array, without copying it
int total(Span<int> s) {
    int t = 0;
    for i in 0..s.len { t += s.get(i); }
    return t;
}

void main() {
    int[] a = arr(10);
    for i in 0..10 { a.push(i * i); }          // 0 1 4 9 16 25 36 49 64 81

    Span<int> mid = a[2..6];                   // the elements 2, 3, 4, 5: a view, not a copy
    jout << mid.len << " elements, the first is " << mid.get(0) << "\n";
    jout << "sum of the middle: " << total(mid) << "\n";

    mid.set(0, 100);                           // writes through to the array
    jout << "a[2] is now " << a[2] << "\n";

    Span<int> inner = mid.sub(1, 3);           // a view of a view: the elements 3 and 4 of the array
    jout << "inner: " << inner.get(0) << " " << inner.get(1) << "\n";
}

```

Output:

```
4 elements, the first is 4
sum of the middle: 54
a[2] is now 100
inner: 9 16
```

A Span has `len`, `get(i)`, `set(i, v)` and `sub(from, to)` (a view of a view). An index outside the Span is an error that you can `catch` ("span index out of range"), not a silent read of other memory. `to_array()` makes a real copy when you need one. Pass a Span to a function whenever it only needs to look at a range: the function works for the whole array, a part of it, or a part of a part.

**Try:** write `int biggest(Span<int> s)` and call it on the first half and on the second half of an array.

## Lesson 87. Real text: reading UTF-8 and the library <font>

A text is bytes. The letters of English take one byte each, but a Thai letter takes three (UTF-8), so a text of 9 letters can be 21 bytes long. A font library must read the bytes and build the number of every character (its code point) before it can ask the font for the shape. The program below does that by hand.

```jk
#import <stdlib>
using stdlib;

// a text is bytes (UTF-8): a Thai letter is three bytes. This is how a font library reads it: byte by byte, building the number of each character.
int next_char(String s, int i, int^ len) {
    int c = s[i] & 255;
    if c < 128 { len^ = 1; return c; }
    if c >= 0xe0 { len^ = 3; return ((c & 15) << 12) | ((s[i + 1] & 63) << 6) | (s[i + 2] & 63); }
    len^ = 2;
    return ((c & 31) << 6) | (s[i + 1] & 63);
}

int main() {
    String s = "Hi สวัสดี";
    jout << "bytes: " << s.len << "\n";
    int i = 0;
    int letters = 0;
    while i < s.len {
        int n = 1;
        int cp = next_char(s, i, @n);
        jout << "U+" << padl(tohex(cp), 4) << " ";
        letters += 1;
        i += n;
    }
    jout << "\nletters: " << letters << "\n";
    return 0;
}

```

Output:

```
bytes: 21
U+  48 U+  69 U+  20 U+ e2a U+ e27 U+ e31 U+ e2a U+ e14 U+ e35 
letters: 9
```

`<font>` (install with `jc lib install font`) does the rest: it opens a TrueType file (the phone has them in `/system/fonts`), finds the glyph of each code point in the table `cmap`, reads its outline from `glyf`, and fills the outline into pixels with smooth edges. The shape of a letter is made once and kept as a small picture, then drawn like any picture.

```jk-no
Font f;
f.open("/system/fonts/Roboto-Regular.ttf");
f.add("/system/fonts/NotoSansThai-Regular.ttf");   // for what the first font lacks
f.cache("cache");                                   // where the pictures of the letters are kept
double right = f.draw(canvas, 20.0, 40.0, "Hello สวัสดี", 24.0, 0xffffffff);
```

Thai needs a little more than letters in a row: the marks (a vowel or a tone mark over a letter) have no width of their own and sit over the letter before them; when a tone mark comes over a vowel it is lifted. The library does this. `<ui>` takes a font with `u.font(@f, 26.0)` and then draws every word of its buttons and lists with it.

**Try:** change the text to your name and print its length in bytes and in letters.

## Lesson 88. Light, shadow and glow: how colours mix

A colour on the screen is `0xAARRGGBB`: alpha, red, green, blue, each 0 to 255. Drawing a colour with some alpha over another mixes them channel by channel: `result = top * alpha + under * (1 - alpha)`. A shadow, a glow and the smooth edge of a letter are all this one rule, repeated.

```jk
#import <stdlib>
using stdlib;

// a colour is 0xAARRGGBB. Drawing a colour with some alpha over another one mixes them channel by channel: this is what a screen does for every
// dot of a shadow, a glow or the edge of a letter.
int channel(int c, int shift) { return (c >> shift) & 255; }

int blend(int top, int under) {
    int a = channel(top, 24);
    int r = (channel(top, 16) * a + channel(under, 16) * (255 - a)) / 255;
    int g = (channel(top, 8) * a + channel(under, 8) * (255 - a)) / 255;
    int b = (channel(top, 0) * a + channel(under, 0) * (255 - a)) / 255;
    return 0xff000000 | (r << 16) | (g << 8) | b;
}

int main() {
    int blue = 0xff0000ff;
    int half_red = 0x80ff0000;
    jout << "half red over blue: " << tohex(blend(half_red, blue)) << "\n";
    jout << "a quarter of white over black: " << tohex(blend(0x40ffffff, 0xff000000)) << "\n";
    // a glow is many circles with a little alpha on top of each other: the centre gets the sum
    int glow = 0xff000000;
    for k in 0..8 { glow = blend(0x20ffffff, glow); }
    jout << "eight layers of a faint white: " << tohex(glow) << "\n";
    return 0;
}

```

Output:

```
half red over blue: ff80007f
a quarter of white over black: ff404040
eight layers of a faint white: ffa4a4a4
```

`<ui>` 0.2.0 uses exactly this: a soft shadow is a few bigger and bigger rounded boxes with a little alpha; a glow is circles on top of each other; the light under your finger is a glow at the place of the touch. `<softcanvas>` is a canvas that draws into memory with the same rule, so you can run a screen without a screen and look at the picture (`save_ppm`) or test the pixels:

```jk-no
SoftCanvas sc;  sc.make(400, 800);
Ui u;  u.start();  u.theme(0);                // 0 midnight, 1 aurora, 2 sunset, 3 light, 4 neon
u.begin(@sc, 400.0, 800.0);
u.title("My App");  u.button("Start");  u.tabs("Home|Search|Me", @tab);
u.end();
sc.save_ppm("screen.ppm");
```

The tab bar has a pill that slides to the chosen tab and stretches a little while it moves: each frame the pill moves a part of the way to where it should be (`pos += (want - pos) * dt * 11`), which is how almost every smooth movement in a UI is made.

**Try:** blend `0x80ffffff` over each of the five theme background colours and see which is brightest.

## Lesson 89. Keys from one secret: HKDF and the tool jmaip

One secret can make as many keys as you need, one for each purpose, so that a leak of one key does not open the others. This is HKDF (RFC 5869): extract a strong key from the secret, then expand it with a label for each purpose.

```jk
#import <stdlib>
using stdlib;

// a key made from a secret: HKDF turns one secret into as many keys as you need, one for each purpose. (jmaip does this for every file and passkey.)
int main() {
    char secret[32];
    for i in 0..32 { secret[i] = (char)(i * 7 + 1); }
    char salt[4];
    salt[0] = 'j'; salt[1] = 'm'; salt[2] = 'a'; salt[3] = 'i';
    char prk[32];
    Crypto::hkdf_extract(256, (char^)@salt, 4, (char^)@secret, 32, (char^)@prk);
    char info_a[8];
    info_a[0] = 'f'; info_a[1] = 'i'; info_a[2] = 'l'; info_a[3] = 'e';
    char info_b[8];
    info_b[0] = 'n'; info_b[1] = 'o'; info_b[2] = 't'; info_b[3] = 'e';
    char ka[16];
    char kb[16];
    Crypto::hkdf_expand(256, (char^)@prk, 32, (char^)@info_a, 4, (char^)@ka, 16);
    Crypto::hkdf_expand(256, (char^)@prk, 32, (char^)@info_b, 4, (char^)@kb, 16);
    String ha = "";
    String hb = "";
    for i in 0..4 { ha = ha + padl(tohex(ka[i] & 255), 2); hb = hb + padl(tohex(kb[i] & 255), 2); }
    jout << "key for files: " << ha << "...\n";
    jout << "key for notes: " << hb << "...\n";
    jout << "different: " << (ha != hb) << "\n";
    return 0;
}

```

Output:

```
key for files: a7f54c14...
key for notes: 4b5db8cb...
different: true
```

The tool **jmaip** (`jc install jmaip`) is built on this. It keeps a vault locked by a passphrase, makes **passkeys** (P-256 keys that sign a challenge, like the keys of WebAuthn), and encrypts files with a key that comes from a passkey, so only the one who has the passkey can open them:

```jk-no
jmaip init                                  # the vault (a passphrase)
jmaip key new phone                         # a passkey; prints its public key
jmaip key sign phone "login:7f3a"           # the signature of a challenge
jmaip enc -k phone notes.txt                # notes.txt.jmaip, sealed with AES-256-GCM
jmaip dec notes.txt.jmaip                   # the passkey is found from the file
```

The key for a file is `HKDF(signature of a fixed text by the passkey, random salt)`, so a changed file or a wrong key is refused, never half-opened. Remember the limit: a passkey that is a file is only as safe as the files and the passphrase; the face or fingerprint of the phone comes later, as the thing that releases the vault key.

**Try:** make a third key with the label `"backup"` and check that it differs from the other two.

## Lesson 90. Fast loops: how to write code the compiler can vectorise

A loop that does the same thing to every element of an array can run four floats (or two doubles) at a time with NEON. The compiler does this by itself when it can see that the loop is simple. The matrix product in the **row form** is the classic case: the inner loop adds `av * b[bk + j]` to `c[ci + j]` for each `j`, and no turn depends on the one before.

```jk
#import <stdlib>
using stdlib;

// C = A * B for small matrices, written in the "row update" form: the inner loop adds a row of B, times one number, to a row of C.
int main() {
    int n = 4;
    float[] a = arr(n * n);
    float[] b = arr(n * n);
    float[] c = arr(n * n);
    for i in 0..n * n { a.push((float)(i % 5)); b.push((float)(i % 3)); c.push(0.0); }
    for i in 0..n {
        for k in 0..n {
            float av = a[i * n + k];
            int ci = i * n;
            int bk = k * n;
            int j = 0;
            while j < n { c[ci + j] = c[ci + j] + av * b[bk + j]; j += 1; }
        }
    }
    for i in 0..n {
        for j in 0..n { jout << c[i * n + j] << " "; }
        jout << "\n";
    }
    return 0;
}

```

Output:

```
5.000000 5.000000 8.000000 5.000000 
2.000000 6.000000 13.000000 2.000000 
4.000000 12.000000 8.000000 4.000000 
11.000000 8.000000 8.000000 11.000000 
```

Three habits help the compiler: (1) keep the row offsets in plain local `int` variables (`ci`, `bk`) and add the counter `j` to them; (2) read the number that does not change (`av`) into a local before the loop; (3) do not call functions inside the loop. If two rows could overlap in memory, the compiler tests it at run time and uses the plain loop in that case, so the result is always the same as without vectors (`-novec` shows it).

The plain form `s = s + a[i*n+k] * b[k*n+j]` (a dot product) has a chain: each turn needs the sum of the one before. That is slower today (about 1.6x to 2.5x of C on the phone); for big training loops use `<neuron>` (`matmul_fast`).

**Try:** compile with and without `-novec` and compare the output.

## Lesson 91. Why loops over arrays are fast

An array is one block of memory whose elements sit next to each other. The processor reads memory in pieces of 64 bytes (a cache line),
so one read brings the next several numbers with it. A loop that goes straight through the array in order uses every piece it reads.
That is why this kind of loop is fast, and why much of the speed in this part comes from keeping data in order.

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] a = arr(1000);
    for i in 0..1000 { a.push(i % 7); }
    int total = 0;
    for i in 0..a.len { total += a[i]; }      // the elements are read in memory order
    jout << "sum: " << total << "\n";
    return 0;
}
```

Output:

```
sum: 2997
```

The program adds the numbers one by one in memory order. Nothing in it is clever: the speed comes from the order of the reads.

**Try:** change `i % 7` to `i % 100` and check the sum before you run it.

## Lesson 92. Measuring time with Time::mono_ns

To know how long code takes, read the clock before and after it. `Time::mono_ns()` gives nanoseconds from a clock that only goes
forward (it does not jump back when the time is set). The times change on every run, so this program prints only things that never change:
a checksum of the result and a line that shows the clock went forward. Repeat the work several times and keep the best (smallest) time.

```jk
#import <stdlib>
using stdlib;

int work(int[] a) {
    int s = 0;
    for i in 0..a.len { s += a[i] * 3; }
    return s;
}

int main() {
    int[] a = arr(100000);
    for i in 0..100000 { a.push(i % 10); }
    int best = 0;
    int check = 0;
    for run in 0..5 {
        int t0 = Time::mono_ns();
        check = work(a);
        int dt = Time::mono_ns() - t0;
        if run == 0 || dt < best { best = dt; }
    }
    int t_end = Time::mono_ns();
    if t_end >= 0 { jout << "ok: the clock went forward\n"; }
    jout << "checksum: " << check << "\n";
    return 0;
}
```

Output:

```
ok: the clock went forward
checksum: 1350000
```

One run is noisy: other programs, the cache and the clock itself change the number. The best of several runs is the usual honest figure.
This program does not print the time, so its output is the same every time you run it.

**Try:** run the work 10 times instead of 5 and check that the checksum does not change.

## Lesson 93. float and double, and float[] arrays

`float` is a 32-bit decimal number and `double` is 64-bit. A `float[]` takes half the memory of a `double[]` of the same length:
twice as many numbers fit in each cache line, and four fit in one NEON register (one `f32x4`). Use `float` when its precision is enough
(most graphics and neural network work); use `double` when a sum must be exact to many digits. Converting between them needs an explicit cast.

```jk
#import <stdlib>
using stdlib;

int main() {
    float[] f = arr(4000);
    double[] d = arr(4000);
    for i in 0..4000 {
        f.push((float)i * 0.5);
        d.push((double)i * 0.5);
    }
    double sf = 0.0;
    double sd = 0.0;
    for i in 0..4000 {
        sf += (double)f[i];
        sd += d[i];
    }
    jout << "float bytes: " << sizeof(float) << ", double bytes: " << sizeof(double) << "\n";
    jout << "sums: " << sf << " " << sd << "\n";
    return 0;
}
```

Output:

```
float bytes: 4, double bytes: 8
sums: 3999000.000000 3999000.000000
```

Both sums are right here because the numbers are halves and small. With values like 0.1 the `float` sum drifts from the `double` sum after
many additions; that is why the choice of type is a real decision.

**Try:** change `0.5` to `0.1` in both places and compare the two sums.

## Lesson 94. SIMD types: f32x4 load and store

`#import <simd>` gives vector types. `f32x4` holds four `float` numbers in one 128-bit NEON register; its parts are `x y z w`.
`f32x4::load(p, i)` reads four floats starting at element `i` of the array that `p` points to, and `v.store(p, i)` writes them back.
The index counts elements, not bytes. A loop of load, work and store handles four elements per turn.

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    float a[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    float c[8];
    f32x4 v = f32x4::load(@a[0], 4);       // a[4] a[5] a[6] a[7]
    v.store(@c[0], 0);                     // into c[0] c[1] c[2] c[3]
    f32x4 w = f32x4::load(@a[0], 0);       // a[0] .. a[3]
    w.store(@c[4], 0);                     // into c[4] .. c[7]
    for i in 0..8 { jout << c[i] << " "; }
    jout << "\n";
    return 0;
}
```

Output:

```
5.000000 6.000000 7.000000 8.000000 1.000000 2.000000 3.000000 4.000000 
```

The first four numbers of `c` are the last four of `a`, and the last four are the first four of `a`.

**Try:** load from index 2 instead of 4 and predict every number of `c` before you run it.

## Lesson 95. f32x4 operators and .sum()

The operators `+ - * /` work on all four lanes at once: one instruction does four additions. A plain number on one side is
used for every lane. `.sum()`, `.min()` and `.max()` give one number from the four lanes; they turn a vector result into a single answer.

```jk
#import <stdlib>
using stdlib;

#import <simd>

int main() {
    f32x4 x = {1.0, 2.0, 3.0, 4.0};
    f32x4 y = {0.5, 0.5, 2.0, 2.0};
    f32x4 z = x * y + x;                   // four lanes at once: 1.5 3 9 12
    jout << z.x << " " << z.y << " " << z.z << " " << z.w << "\n";
    f32x4 h = z / 2.0 - 1.0;               // the number is used for every lane
    jout << h.x << " " << h.w << "\n";
    jout << "sum " << z.sum() << "  min " << z.min() << "  max " << z.max() << "\n";
    return 0;
}
```

Output:

```
1.500000 3.000000 9.000000 12.000000
-0.250000 5.000000
sum 25.500000  min 1.500000  max 12.000000
```

The lanes of `z` are 1.5, 3, 9 and 12, so `z.sum()` is 25.5, the smallest is 1.5 and the largest is 12.

**Try:** compute `z.sum()` by hand from the first line and check it.

## Lesson 96. axpy with f32x4: y = y + a * x

This is one of the most common loops in linear algebra and in training: `y = y + a * x` (the BLAS name is axpy). For each element
there is one multiply and one add. The number `a` is put in a vector with `{a, a, a, a}`, then `x` and `y` are read four at a time.
In this simple form the length `n` must be a multiple of 4. Lesson 90 showed the row form of a matrix product; this is the same idea by itself.

```jk
#import <stdlib>
#import <simd>
using stdlib;

// y = y + a * x for n numbers; n must be a multiple of 4 in this simple form
void axpy(float a, float^ x, float^ y, int n) {
    f32x4 av = {a, a, a, a};
    int i = 0;
    while i < n {
        f32x4 xv = f32x4::load(x, i);
        f32x4 yv = f32x4::load(y, i);
        yv = yv + av * xv;
        yv.store(y, i);
        i += 4;
    }
}

int main() {
    float x[8];
    float y[8];
    for i in 0..8 {
        x[i] = (float)i;
        y[i] = 1.0;
    }
    axpy(0.5, @x[0], @y[0], 8);
    for i in 0..8 { jout << y[i] << " "; }
    jout << "\n";
    return 0;
}
```

Output:

```
1.000000 1.500000 2.000000 2.500000 3.000000 3.500000 4.000000 4.500000 
```

Each element is `1 + 0.5 * i`, so the line is 1, 1.5, 2 ... 4.5.

**Try:** call `axpy` a second time with `a` equal to 2.0 and predict the new line.

## Lesson 97. Matrix product, the plain way (ijk)

`C = A * B` is most often written as three loops: for each row `i` of C and each column `j`, the dot product of row `i` of A and
column `j` of B. The sum `s` is one dot product. It is easy to read and it is the form in most textbooks. The example is 4x4: `A[i][k] = i + k`
and `B[k][j] = k - j`, each stored in one flat array with the index `i*n + k`.

```jk
#import <stdlib>
using stdlib;

// C = A * B for 4x4, the plain way: C[i][j] is the dot product of row i of A and column j of B
int main() {
    int n = 4;
    float[] a = arr(16);
    float[] b = arr(16);
    float[] c = arr(16);
    for i in 0..n {
        for k in 0..n { a.push((float)(i + k)); }
    }
    for k in 0..n {
        for j in 0..n { b.push((float)(k - j)); }
    }
    for i in 0..n {
        for j in 0..n {
            float s = 0.0;
            for k in 0..n { s = s + a[i * n + k] * b[k * n + j]; }
            c.push(s);
        }
    }
    for i in 0..n {
        for j in 0..n { jout << c[i * n + j] << " "; }
        jout << "\n";
    }
    return 0;
}
```

Output:

```
14.000000 8.000000 2.000000 -4.000000 
20.000000 10.000000 0.000000 -10.000000 
26.000000 12.000000 -2.000000 -16.000000 
32.000000 14.000000 -4.000000 -22.000000 
```

The inner loop over `k` is a chain: each `s = s + ...` needs the result of the one before. Lesson 98 explains why that limits the speed.

**Try:** work out the first number of row 0 by hand (it is the dot product of row 0 of A and column 0 of B) and check it.

## Lesson 98. Why ijk is slower: a chain of adds, and two accumulators

The processor can do several additions at the same time, but a chain `s = s + x` must wait for the previous `s` each time, so one long
chain runs at the speed of one add after another. The fix is to **jam** the loop: keep two sums that do not depend on each other, `s0` for the
even terms and `s1` for the odd ones, and add them at the end. The answer is the same and the two chains run side by side.
Adding floats in a different order can change the last digit, so this example uses whole numbers.

```jk
#import <stdlib>
using stdlib;

// one chain: every add waits for the one before it
float dot_one(float[] a, float[] b, int n) {
    float s = 0.0;
    for i in 0..n { s = s + a[i] * b[i]; }
    return s;
}

// two chains: s0 and s1 do not wait for each other; they are added at the end
float dot_two(float[] a, float[] b, int n) {
    float s0 = 0.0;
    float s1 = 0.0;
    int i = 0;
    while i + 2 <= n {
        s0 = s0 + a[i] * b[i];
        s1 = s1 + a[i + 1] * b[i + 1];
        i += 2;
    }
    return s0 + s1;
}

int main() {
    float[] a = arr(8);
    float[] b = arr(8);
    for i in 0..8 {
        a.push((float)(i + 1));
        b.push((float)(i % 3));
    }
    jout << "one chain: " << dot_one(a, b, 8) << "\n";
    jout << "two chains: " << dot_two(a, b, 8) << "\n";
    return 0;
}
```

Output:

```
one chain: 33.000000
two chains: 33.000000
```

Both lines print the same sum. Four chains (lesson 99) usually do better still, because the processor can run four adds at once.

**Try:** write `dot_three` with three chains and check that it prints the same sum.

## Lesson 99. Four accumulators by hand

Four chains `s0 .. s3` take the elements `i`, `i+1`, `i+2` and `i+3`. The loop steps by four; the elements left over (when `n` is not a
multiple of 4) are added after it. This is the same trick as a vector with four lanes: four chains that run at once.

```jk
#import <stdlib>
using stdlib;

// four chains: s0 .. s3 take the elements i .. i+3; the loop steps by 4 and the tail is added at the end
float dot_four(float[] a, float[] b, int n) {
    float s0 = 0.0;
    float s1 = 0.0;
    float s2 = 0.0;
    float s3 = 0.0;
    int i = 0;
    while i + 4 <= n {
        s0 = s0 + a[i] * b[i];
        s1 = s1 + a[i + 1] * b[i + 1];
        s2 = s2 + a[i + 2] * b[i + 2];
        s3 = s3 + a[i + 3] * b[i + 3];
        i += 4;
    }
    float s = s0 + s1 + s2 + s3;
    while i < n {
        s = s + a[i] * b[i];
        i += 1;
    }
    return s;
}

int main() {
    float[] a = arr(18);
    float[] b = arr(18);
    for i in 0..18 {
        a.push((float)(i + 1));
        b.push((float)(i % 4));
    }
    float plain = 0.0;
    for i in 0..18 { plain = plain + a[i] * b[i]; }
    jout << "plain: " << plain << "\n";
    jout << "four chains: " << dot_four(a, b, 18) << "\n";
    return 0;
}
```

Output:

```
plain: 242.000000
four chains: 242.000000
```

Both lines are the same sum. The `while` loop at the end handles the two leftover elements (18 is not a multiple of 4).

**Try:** change every 18 to 16 (the arrays and the loops) and check that the tail loop then does nothing.

## Lesson 100. Vector across j: four columns of C at once

Instead of one dot product at a time, a vector can hold four columns: `cv` holds `C[i][j..j+3]`. For each `k`, the number `A[i][k]`
is put in every lane (a broadcast, `{x, x, x, x}`), the row `B[k][0..3]` is loaded as one vector, and `cv = cv + av * bv`. The four lanes are four
separate sums, so four chains run side by side, and the loads read memory in order. The example uses the same data as lesson 97.

```jk
#import <stdlib>
#import <simd>
using stdlib;

// C = A * B for 4x4, four columns of C at a time: cv holds the row i of C
int main() {
    int n = 4;
    float a[16];
    float b[16];
    float c[16];
    for i in 0..n {
        for k in 0..n { a[i * n + k] = (float)(i + k); }
    }
    for k in 0..n {
        for j in 0..n { b[k * n + j] = (float)(k - j); }
    }
    for i in 0..n {
        f32x4 cv = {0.0, 0.0, 0.0, 0.0};
        for k in 0..n {
            float x = a[i * n + k];                 // A[i][k]
            f32x4 av = {x, x, x, x};                // broadcast to every lane
            f32x4 bv = f32x4::load(@b[0], k * n);   // B[k][0..3]
            cv = cv + av * bv;
        }
        cv.store(@c[0], i * n);
    }
    for i in 0..16 {
        jout << c[i] << " ";
        if i % 4 == 3 { jout << "\n"; }
    }
    return 0;
}
```

Output:

```
14.000000 8.000000 2.000000 -4.000000 
20.000000 10.000000 0.000000 -10.000000 
26.000000 12.000000 -2.000000 -16.000000 
32.000000 14.000000 -4.000000 -22.000000 
```

The four lines are the same four lines lesson 97 printed.

**Try:** change `n` to 8 and the arrays to 64 numbers, and count how many times the inner loop runs.

## Lesson 101. A 4x8 register block

A register block is a small piece of C that stays in registers while the loop over `k` runs. Here C is 4 rows by 8 columns, kept as
eight `f32x4` values: two for each row (columns 0..3 and 4..7). Each `k` loads two vectors of `B` (row `k`, eight numbers), and for each row
broadcasts `A[i][k]` and adds into that row's two vectors. C is not written to memory until the end. The example uses K = 3 and small numbers,
so you can check the output by hand.

```jk
#import <stdlib>
#import <simd>
using stdlib;

// A is 4x3, B is 3x8, C is 4x8 (K = 3). The eight vectors of C stay in registers during the loop over k.
int main() {
    float a[12];
    float b[24];
    for i in 0..4 {
        for k in 0..3 { a[i * 3 + k] = (float)(i + k + 1); }
    }
    for k in 0..3 {
        for j in 0..8 { b[k * 8 + j] = (float)(k + j); }
    }
    f32x4 z = {0.0, 0.0, 0.0, 0.0};
    f32x4 c00 = z;  f32x4 c01 = z;
    f32x4 c10 = z;  f32x4 c11 = z;
    f32x4 c20 = z;  f32x4 c21 = z;
    f32x4 c30 = z;  f32x4 c31 = z;
    for k in 0..3 {
        f32x4 b_lo = f32x4::load(@b[0], k * 8);       // B[k][0..3]
        f32x4 b_hi = f32x4::load(@b[0], k * 8 + 4);   // B[k][4..7]
        float x0 = a[k];
        float x1 = a[3 + k];
        float x2 = a[6 + k];
        float x3 = a[9 + k];
        f32x4 a0 = {x0, x0, x0, x0};
        f32x4 a1 = {x1, x1, x1, x1};
        f32x4 a2 = {x2, x2, x2, x2};
        f32x4 a3 = {x3, x3, x3, x3};
        c00 = c00 + a0 * b_lo;  c01 = c01 + a0 * b_hi;
        c10 = c10 + a1 * b_lo;  c11 = c11 + a1 * b_hi;
        c20 = c20 + a2 * b_lo;  c21 = c21 + a2 * b_hi;
        c30 = c30 + a3 * b_lo;  c31 = c31 + a3 * b_hi;
    }
    float out[32];
    c00.store(@out[0], 0);   c01.store(@out[0], 4);
    c10.store(@out[0], 8);   c11.store(@out[0], 12);
    c20.store(@out[0], 16);  c21.store(@out[0], 20);
    c30.store(@out[0], 24);  c31.store(@out[0], 28);
    for i in 0..4 {
        for j in 0..8 { jout << out[i * 8 + j] << " "; }
        jout << "\n";
    }
    return 0;
}
```

Output:

```
8.000000 14.000000 20.000000 26.000000 32.000000 38.000000 44.000000 50.000000 
11.000000 20.000000 29.000000 38.000000 47.000000 56.000000 65.000000 74.000000 
14.000000 26.000000 38.000000 50.000000 62.000000 74.000000 86.000000 98.000000 
17.000000 32.000000 47.000000 62.000000 77.000000 92.000000 107.000000 122.000000 
```

Row 0 is `A[0][k]` times row `k` of B, added over `k = 0, 1, 2`. For column 0 that is 1*0 + 2*1 + 3*2 = 8.

**Try:** change `K` to 2 (use only `k` 0 and 1) and check the first number of row 0 by hand.

## Lesson 102. Threads: the #multithread loop

`#multithread` on the line before a `for` loop shares the iterations among the cores (at most 16 parts). Each iteration must be
independent of the others, and the body may not use `break`, `return` or another `#multithread`. The loop ends when every part has finished,
so the output is always the same.

```jk
#import <stdlib>
using stdlib;

int squares[1000];

void main() {
    int offset = 5;
    #multithread
    for i in 0..1000 {                  // the iterations are shared among the machine's cores
        squares[i] = i * i + offset;    // every iteration writes its own element
    }
    jout << squares[999] << "\n";
}
```

Output:

```
998006
```

Every iteration writes only its own element, so the parts never touch the same memory. A loop that adds into one shared total needs a
`Mutex` (see LANGUAGE.md) or a sum for each part.

**Try:** change `offset` to 7 and predict the output before you run it.

## Lesson 103. Bounds checks and the -d switch

`a[i]` is checked against the length only when you build with `-d`: `jcmp prog.jk -d -o prog`. A bad index then stops the program with
`runtime error: index out of bounds, array size is N` and exit code 134. A normal build does not check, so a wrong index reads other memory.
Use `-d` while you test. The check costs a compare in each loop, so the release build leaves it out. A loop over `0..a.len` never goes out of
range, and that is the form to write first.

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] a = arr(10);
    for i in 0..10 { a.push(i * 3); }
    int total = 0;
    for i in 0..a.len { total += a[i]; }      // i always stays inside 0 .. a.len - 1
    jout << "total " << total << "\n";
    return 0;
}
```

Output:

```
total 135
```

Build it with `-d` as well: `jcmp bounds.jk -d -o bounds`. The output is the same, because this program never goes out of range.

**Try:** change the loop to `for i in 0..11` with `-d` and read the error message.

## Lesson 104. The switches -novec, -nofma, -nopeep, -noir

Four switches turn off one optimisation each, so you can find which one is wrong: `-novec` (no NEON vector loops), `-nofma`
(keep the two roundings of `a*b + c`), `-nopeep` (no rewrites of the final assembler text) and `-noir` (skip the optimiser on the
intermediate form). If the output changes when you add one of them, the fault is in that part. This program prints the same with every switch,
because its numbers are exact.

```jk
#import <stdlib>
using stdlib;

int main() {
    double[] x = arr(8);
    double[] y = arr(8);
    for i in 0..8 {
        x.push(0.5 * (double)i);
        y.push(2.0 * (double)i);
    }
    double s = 0.0;
    for i in 0..8 { s = s + x[i] * y[i] + 1.0; }   // a * b + c: with FMA this is one rounding
    jout << "sum " << s << "\n";
    return 0;
}
```

Output:

```
sum 148.000000
```

Try it yourself: `jcmp switches.jk -o fast` and `jcmp switches.jk -novec -noir -o plain`, run both and compare. Use one switch at a time
when you look for a bug.

**Try:** add `-nofma` to the command and check that the output is still `sum 148.000000`.

## Lesson 105. Reading the assembly of a loop

`--emit-asm file` writes the assembler text the compiler made, so you can see what your loop turned into. Write the command with the
file name you want: `jcmp total.jk -o total --emit-asm total.jasm`. `-show NAME` writes only one function and how many instructions it has
(ARM64), so it is good for a small function such as `total` below. Read the loop body only, not the whole file: the loop is the part
that counts for speed.

```jk
#import <stdlib>
using stdlib;

// a small function with one loop: a good thing to look at with -show total or --emit-asm
double total(double[] v) {
    double s = 0.0;
    for i in 0..v.len { s = s + v[i] * 2.0; }
    return s;
}

int main() {
    double[] v = arr(16);
    for i in 0..16 { v.push((double)i); }
    jout << total(v) << "\n";
    return 0;
}
```

Output:

```
240.000000
```

The output is `240.000000`: twice the sum of 0 to 15.

**Try:** run `jcmp total.jk -show total` and see how many instructions the function has. Then change `* 2.0` to `* 3.0` and count again.

## Lesson 106. Integer sums with i32x4

Integers have the same shape: `i32[]` holds 32-bit numbers, and `i32x4` adds four of them in one instruction. A sum over an integer array
is a loop of loads and adds, as with floats, and the four lanes are added at the end with `.sum()`. An integer sum is exact, so the vector sum gives
the same number as the plain sum whatever the order of the additions.

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    i32[] a = arr(1000);
    for i in 0..1000 { a.push((i32)(i * 3 % 17)); }
    i32 plain = 0;
    for i in 0..a.len { plain += a[i]; }
    i32x4 acc = {0, 0, 0, 0};
    int i = 0;
    while i < a.len {
        acc += i32x4::load(@a[0], i);      // four numbers per turn
        i += 4;
    }
    jout << "plain " << plain << "\n";
    jout << "vector " << acc.sum() << "\n";
    return 0;
}
```

Output:

```
plain 7991
vector 7991
```

Both lines print the same total. The array length 1000 is a multiple of 4, so the vector loop needs no tail.

**Try:** change `1000` to `999` and work out what the last vector load would read past the end; then write the tail loop of lesson 99 instead.

## Lesson 107. Avoiding allocation in a hot loop

An `arr`, an `alloc` or a `String` built with `+` inside a loop asks the heap for memory on every round. That is slower than the
arithmetic around it, and a `String` built with `+` copies its text each time. Allocate once before the loop and reuse the memory.
The program below makes its buffer once and writes into it a hundred thousand times.

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] buf = arr(8);
    for i in 0..8 { buf.push(0); }        // allocated once, before the loop
    int total = 0;
    for round in 0..100000 {
        for j in 0..8 { buf[j] = round + j; }   // the same memory every round
        total += buf[7] - buf[0];
    }
    jout << total << "\n";
    return 0;
}
```

Output:

```
700000
```

Each round adds 7 (the last element minus the first), so the total is 700000.

**Try:** move the `arr(8)` and the pushes inside the outer loop, and time both versions with `Time::mono_ns` (lesson 92).

## Lesson 108. Struct of arrays and array of structs

An array of structs (AoS) keeps `x` and `y` of one point next to each other. A struct of arrays (SoA) keeps all the `x` values in one
array and all the `y` values in another. A loop that uses only `x` reads far less memory with SoA, because the `y` values are never loaded.
Both programs below give the same sum of `x`.

```jk
#import <stdlib>
using stdlib;

struct Point { double x; double y; }

// array of structs: the x and y of one point are next to each other
double sum_x_aos(Point[] ps) {
    double s = 0.0;
    for i in 0..ps.len { s = s + ps[i].x; }
    return s;
}

// struct of arrays: all the x values are in one array
double sum_x_soa(double[] xs) {
    double s = 0.0;
    for i in 0..xs.len { s = s + xs[i]; }
    return s;
}

int main() {
    Point[] ps = arr(1000);
    double[] xs = arr(1000);
    double[] ys = arr(1000);
    for i in 0..1000 {
        Point p = {(double)i * 0.5, (double)i};
        ps.push(p);
        xs.push((double)i * 0.5);
        ys.push((double)i);
    }
    jout << "aos " << sum_x_aos(ps) << "\n";
    jout << "soa " << sum_x_soa(xs) << "\n";
    jout << "count of y " << ys.len << "\n";
    return 0;
}
```

Output:

```
aos 249750.000000
soa 249750.000000
count of y 1000
```

Both sums are the same. The loop over `x` in the SoA version touches only the `xs` array; in the AoS version the same loop skips over every `y`.

**Try:** add a `sum_y_soa` function and check that the sum of `ys` is 499500.

## Lesson 109. Cache: row-major order, i-k-j against i-j-k

A matrix sits in memory row by row (row-major): `a[i*n + j]`. Going along a row reads neighbours, which is kind to the cache; going
down a column jumps `n` numbers each time. In `C = A * B` the order of the three loops decides which matrix is read along its rows. The order
i-k-j walks along rows of `B` and `C`; the order i-j-k walks down a column of `B`. Both programs below make the same matrix, so only the speed
differs (on a matrix this small both fit in the cache, so the gap can be small; the order is the point).

```jk
#import <stdlib>
using stdlib;

int main() {
    int n = 64;
    double[] a = arr(n * n);
    double[] b = arr(n * n);
    double[] c1 = arr(n * n);
    double[] c2 = arr(n * n);
    for i in 0..n * n {
        a.push((double)(i % 7));
        b.push((double)(i % 5));
        c1.push(0.0);
        c2.push(0.0);
    }
    // i-j-k: the inner loop walks down a column of B (a jump of n numbers each time)
    for i in 0..n {
        for j in 0..n {
            for k in 0..n { c1[i * n + j] = c1[i * n + j] + a[i * n + k] * b[k * n + j]; }
        }
    }
    // i-k-j: the inner loop walks along a row of B and a row of C
    for i in 0..n {
        for k in 0..n {
            for j in 0..n { c2[i * n + j] = c2[i * n + j] + a[i * n + k] * b[k * n + j]; }
        }
    }
    bool same = true;
    for i in 0..n * n {
        if c1[i] != c2[i] { same = false; }
    }
    jout << "same matrix: " << same << "\n";
    return 0;
}
```

Output:

```
same matrix: true
```

The matrices are equal, so the loop order does not change the answer. Only the order in which the memory is read does.

**Try:** change `n` to 128 and compare the times of the two loops with `Time::mono_ns` (lesson 92). Do not print the times in a test you want to repeat.

## Lesson 110. Comparing with C fairly

To say that J2K is faster or slower than C, compare the same algorithm, the same data and the same settings. Run the two versions in
turns (A, B, A, B ...) so that heat and other work hit both alike; keep the best of N runs; and check that both give the same answer before you
compare any time. This program shows the shape of such a test: two versions of one kernel, run in turns, the answers compared, and no time printed.

```jk
#import <stdlib>
using stdlib;

// kernel A: one chain of adds
double kernel_a(double[] v) {
    double s = 0.0;
    for i in 0..v.len { s = s + v[i]; }
    return s;
}

// kernel B: four chains of adds, the same answer
double kernel_b(double[] v) {
    double s0 = 0.0;
    double s1 = 0.0;
    double s2 = 0.0;
    double s3 = 0.0;
    int n = v.len;
    int i = 0;
    while i + 4 <= n {
        s0 = s0 + v[i];
        s1 = s1 + v[i + 1];
        s2 = s2 + v[i + 2];
        s3 = s3 + v[i + 3];
        i += 4;
    }
    double s = s0 + s1 + s2 + s3;
    while i < n {
        s = s + v[i];
        i += 1;
    }
    return s;
}

int main() {
    double[] v = arr(100000);
    for i in 0..100000 { v.push((double)(i % 9)); }
    int best_a = 0;
    int best_b = 0;
    double ra = 0.0;
    double rb = 0.0;
    for round in 0..7 {
        // A and B take turns, so the load of the machine hits both alike
        int t0 = Time::mono_ns();
        ra = kernel_a(v);
        int t1 = Time::mono_ns();
        rb = kernel_b(v);
        int t2 = Time::mono_ns();
        int da = t1 - t0;
        int db = t2 - t1;
        if round == 0 || da < best_a { best_a = da; }
        if round == 0 || db < best_b { best_b = db; }
    }
    jout << "same answer: " << (ra == rb) << "\n";
    jout << "done\n";
    return 0;
}
```

Output:

```
same answer: true
done
```

The timings are kept in `best_a` and `best_b` but not printed, so the output never changes. To report them, print them in your own
benchmark, next to the same kernel written in C with the same data, and say which compiler and which flags you used.

**Try:** add a third kernel and run it in the same turns; the answer must match too.

## Lesson 111. What a neural network is

A neural network is many small units. Each unit is a weighted sum of its inputs, passed through a function. One unit, written by hand with doubles, is the whole idea: `out = relu(w1 * x1 + w2 * x2 + b)`.

```jk
#import <stdlib>
#import <math>
using stdlib;
// one neuron: it weighs its inputs, adds a bias, and passes the sum through an activation (here relu)
double relu(double x) {
    if x > 0.0 { return x; }
    return 0.0;
}
void main() {
    double x1 = 2.0;
    double x2 = 1.0;
    double w1 = 0.5;
    double w2 = -1.0;
    double b = 0.2;
    double z = w1 * x1 + w2 * x2 + b;
    jout << "sum    = " << z << "\n";
    jout << "output = " << relu(z) << "\n";
    jout << "negative sum -> " << relu(-0.5) << "\n";
}

```

Output:

```
sum    = 0.200000
output = 0.200000
negative sum -> 0.000000
```

The weights `w1`, `w2` and the bias `b` are the numbers that training changes. Here the sum is positive, so relu keeps it. A negative sum becomes 0.

**Try:** change `x2` to 3.0 and predict the output before you run it.

## Lesson 112. A tensor

A `Tensor` is a table of numbers with `rows` and `cols`. The numbers are doubles, stored row by row in the field `d`. `Tensor::zeros(r, c)` makes a table filled with 0.0, and `set` and `get` write and read a place by its row and column.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// a Tensor is a table of rows x cols doubles; zeros makes one filled with 0.0
void main() {
    Tensor t = Tensor::zeros(2, 3);
    t.set(0, 1, 5.0);
    t.set(1, 2, -1.5);
    jout << "shape " << t.rows << " x " << t.cols << "\n";
    jout << "get(0, 1) = " << t.get(0, 1) << "\n";
    jout << "get(1, 2) = " << t.get(1, 2) << "\n";
    for r in 0..t.rows {
        for c in 0..t.cols { jout << t.get(r, c) << " "; }
        jout << "\n";
    }
}

```

Output:

```
shape 2 x 3
get(0, 1) = 5.000000
get(1, 2) = -1.500000
0.000000 5.000000 0.000000 
0.000000 0.000000 -1.500000 
```

The place (r, c) is `d[r * cols + c]`. `set` changes the table in place. The operations such as `matmul`, `add` and `relu` do not change their input: they return a new Tensor.

**Try:** print `t.d[1 * 3 + 2]` and check that it equals `t.get(1, 2)`.

## Lesson 113. Matrix multiply

In a matrix product, element (i, j) of the result is the sum over k of `A[i][k] * B[k][j]`. `a.matmul(b)` is the plain loop. `a.matmul_fast(b)` uses float32 and dot products, with four threads when the table is big. A small table takes the plain loop, so the two agree. The columns of A must equal the rows of B.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// C = A x B with the plain loop (matmul) and the fast way (matmul_fast)
void show(Tensor c) {
    for r in 0..c.rows {
        for k in 0..c.cols { jout << c.get(r, k) << " "; }
        jout << "\n";
    }
}
void main() {
    Tensor a = Tensor::zeros(2, 3);
    Tensor b = Tensor::zeros(3, 2);
    for i in 0..6 {
        a.d[i] = (double)(i + 1);
        b.d[i] = (double)(i % 4);
    }
    show(a.matmul(b));
    // a big table: the fast way gives the same numbers, up to float32 rounding
    Tensor p = Tensor::zeros(40, 70);
    Tensor q = Tensor::zeros(70, 50);
    for i in 0..40 * 70 { p.d[i] = (double)(i % 11) * 0.125 - 0.5; }
    for i in 0..70 * 50 { q.d[i] = (double)(i % 7) * 0.25 - 0.75; }
    Tensor slow = p.matmul(q);
    Tensor fast = p.matmul_fast(q);
    double worst = 0.0;
    for i in 0..slow.rows * slow.cols {
        double diff = Math::abs(slow.d[i] - fast.d[i]);
        if diff > worst { worst = diff; }
    }
    jout << "shape " << fast.rows << " x " << fast.cols << ", same: " << (worst < 0.001) << "\n";
}

```

Output:

```
4.000000 10.000000 
10.000000 25.000000 
shape 40 x 50, same: true
```

Row 0 of the result is row 0 of A times B: 1 * 0 + 2 * 2 + 3 * 0 = 4 for the first element. The big table is checked against the plain loop.

**Try:** print `fast.rows` and `fast.cols` before the check and confirm they are 40 and 50.

## Lesson 114. A linear layer

A layer of neurons is `y = x @ w + b`: a row of inputs times the weight table, plus the bias. `Dense::make(inputs, outputs, seed)` makes the weights from a seed, so the same seed gives the same weights. `forward` also remembers its input, which training needs later.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// a linear layer: y = x @ w + b. The same sum is computed here by hand, and the two agree.
void main() {
    Dense layer = Dense::make(3, 2, 7);
    Tensor x = Tensor::zeros(1, 3);
    x.set(0, 0, 1.0);
    x.set(0, 1, -2.0);
    x.set(0, 2, 0.5);
    Tensor y = layer.forward(x);
    jout << "y has " << y.rows << " row and " << y.cols << " columns\n";
    bool same = true;
    for j in 0..2 {
        double s = layer.b.get(0, j);
        for i in 0..3 { s += x.get(0, i) * layer.w.get(i, j); }
        jout << "y[" << j << "] = " << y.get(0, j) << "  by hand " << s << "\n";
        if Math::abs(s - y.get(0, j)) > 0.000001 { same = false; }
    }
    jout << "same: " << same << "\n";
}

```

Output:

```
y has 1 row and 2 columns
y[0] = 0.615230  by hand 0.615230
y[1] = -0.542970  by hand -0.542970
same: true
```

A linear layer does nothing more than this: a weighted sum for each output, plus its bias. Training changes `w` and `b`.

**Try:** change the layer to `Dense::make(3, 4, 7)` and predict the shape of `y` before you run it.

## Lesson 115. Activation functions

Without an activation function, a stack of layers is one layer, because a sum of sums is still a sum. The activation bends the output: `relu(x)` is max(0, x), `tanh` goes from -1 to 1, and `sigmoid` goes from 0 to 1. First by hand on doubles, then the same functions on a graph of `Tensor32` values with `g.relu`, `g.tanh` and `g.sigmoid`.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// activation functions: by hand on doubles, then the same on a graph of float32 values
double relu(double x) {
    if x > 0.0 { return x; }
    return 0.0;
}
double sigmoid(double x) { return 1.0 / (1.0 + Math::exp(-x)); }
void main() {
    double[] xs = arr(4);
    xs.push(-2.0); xs.push(-0.5); xs.push(0.0); xs.push(1.5);
    for i in 0..4 {
        double x = xs[i];
        jout << "x " << x << "  relu " << relu(x) << "  tanh " << Math::tanh(x) << "  sigmoid " << sigmoid(x) << "\n";
    }
    Graph g = Graph::make();
    int a = g.input(Tensor32::from_list(1, 4, xs));
    int r = g.relu(a);
    int t = g.tanh(a);
    int s = g.sigmoid(a);
    jout << "graph relu " << g.value(r).d[0] << " " << g.value(r).d[3] << "\n";
    jout << "graph tanh " << g.value(t).d[0] << " " << g.value(t).d[3] << "\n";
    jout << "graph sigmoid " << g.value(s).d[2] << "\n";
}

```

Output:

```
x -2.000000  relu 0.000000  tanh -0.964028  sigmoid 0.119203
x -0.500000  relu 0.000000  tanh -0.462117  sigmoid 0.377541
x 0.000000  relu 0.000000  tanh 0.000000  sigmoid 0.500000
x 1.500000  relu 1.500000  tanh 0.905148  sigmoid 0.817574
graph relu 0.000000 1.500000
graph tanh -0.964028 0.905148
graph sigmoid 0.500000
```

The graph computes the same curves in float32, so the last digits can differ a little from the doubles.

**Try:** print `sigmoid(0.0)` and check that it is 0.5.

## Lesson 116. The loss: mean squared error

The loss tells how wrong the output is. Mean squared error takes each error, squares it and averages. Squaring makes a big error count much more than a small one, and a negative error does not cancel a positive one.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// the loss by hand, then the same with the graph's mse node
void main() {
    double[] out = arr(3);
    out.push(0.8); out.push(0.2); out.push(0.6);
    double[] want = arr(3);
    want.push(1.0); want.push(0.0); want.push(1.0);
    double s = 0.0;
    for i in 0..3 {
        double e = out[i] - want[i];
        s += e * e;
        jout << "error " << i << ": " << e << "\n";
    }
    jout << "mse by hand = " << s / 3.0 << "\n";
    Graph g = Graph::make();
    int o = g.input(Tensor32::from_list(3, 1, out));
    int l = g.mse(o, Tensor32::from_list(3, 1, want));
    jout << "mse of the graph = " << g.value(l).d[0] << "\n";
}

```

Output:

```
error 0: -0.200000
error 1: 0.200000
error 2: -0.400000
mse by hand = 0.080000
mse of the graph = 0.080000
```

The graph's `mse(output, target)` returns a node; `g.value(node).d[0]` reads its number. The two results agree.

**Try:** change the second output `0.2` to `0.5` and compute the new loss by hand before you run it.

## Lesson 117. The gradient, checked two ways

Training needs the slope of the loss: how much it changes when one weight changes. For `f(w) = (2w - 6)^2` the slope is `2 * (2w - 6) * 2`. A numerical check moves `w` a tiny step each way and divides the change by the step. The graph's `backward` must give the same number.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// f(w) = (2w - 6)^2: the slope by hand, the slope by a numerical check, and the slope from the graph
double f(double w) {
    double e = 2.0 * w - 6.0;
    return e * e;
}
void main() {
    double w = 1.0;
    double h = 0.001;
    double exact = 2.0 * (2.0 * w - 6.0) * 2.0;
    double numeric = (f(w + h) - f(w - h)) / (2.0 * h);
    jout << "f(1) = " << f(w) << "\n";
    jout << "slope by hand = " << exact << "\n";
    jout << "slope numeric = " << numeric << "\n";
    jout << "they agree: " << (Math::abs(exact - numeric) < 0.0001) << "\n";
    Graph g = Graph::make();
    double[] wv = arr(1);
    wv.push(w);
    double[] xv = arr(1);
    xv.push(2.0);
    double[] yv = arr(1);
    yv.push(6.0);
    int wn = g.param(Tensor32::from_list(1, 1, wv));
    g.mark();
    int x = g.input(Tensor32::from_list(1, 1, xv));
    int l = g.mse(g.matmul(x, wn), Tensor32::from_list(1, 1, yv));
    g.backward(l);
    jout << "slope from the graph = " << g.gradient(wn).d[0] << "\n";
}

```

Output:

```
f(1) = 16.000000
slope by hand = -16.000000
slope numeric = -16.000000
they agree: true
slope from the graph = -16.000000
```

At `w = 1` the loss is 16 and the slope is -16: making `w` bigger lowers the loss. This is the check the library uses for every operation.

**Try:** use `w = 3.0`; the slope there is 0, the lowest point of the loss.

## Lesson 118. Gradient descent: one weight

Gradient descent moves the weight a little against its slope, again and again. The rate (0.05 here) sets how big each move is. The data is `y = 2x` at x = 1, 2, 3, so the right weight is 2.

```jk
#import <stdlib>
using stdlib;
// fit one weight: y = 2x on x = 1, 2, 3. The loss is the mean of (w*x - y)^2.
void main() {
    double[] xs = arr(3);
    xs.push(1.0); xs.push(2.0); xs.push(3.0);
    double[] ys = arr(3);
    ys.push(2.0); ys.push(4.0); ys.push(6.0);
    double w = 0.0;
    double rate = 0.05;
    for step in 0..60 {
        double g = 0.0;
        double loss = 0.0;
        for i in 0..3 {
            double e = w * xs[i] - ys[i];
            loss += e * e;
            g += 2.0 * e * xs[i];
        }
        if step % 10 == 0 { jout << "step " << step << "  w = " << w << "  loss = " << loss / 3.0 << "\n"; }
        w = w - rate * g / 3.0;
    }
    jout << "w after 60 steps = " << w << "\n";
}

```

Output:

```
step 0  w = 0.000000  loss = 18.666667
step 10  w = 1.996276  loss = 0.000065
step 20  w = 1.999993  loss = 0.000000
step 30  w = 2.000000  loss = 0.000000
step 40  w = 2.000000  loss = 0.000000
step 50  w = 2.000000  loss = 0.000000
w after 60 steps = 2.000000
```

Each step uses the slope from the data, so the weight moves towards 2 and the loss falls. The rate must be small enough; the learning-rate lesson shows what happens when it is too big.

**Try:** change the data to `y = 3x` and find the weight it reaches.

## Lesson 119. Two weights: a line

A line needs two weights: `y = w * x + b`. The same descent moves both, each by its own average slope over the data points. The data is `y = 3x + 1`, so the answer is w = 3 and b = 1.

```jk
#import <stdlib>
using stdlib;
// the line y = 3x + 1 on five points: w is the slope, b the bias, both moved by their average slope
void main() {
    double[] xs = arr(5);
    double[] ys = arr(5);
    for i in 0..5 {
        xs.push((double)i);
        ys.push(3.0 * (double)i + 1.0);
    }
    double w = 0.0;
    double b = 0.0;
    double rate = 0.02;
    for step in 0..1500 {
        double gw = 0.0;
        double gb = 0.0;
        double loss = 0.0;
        for i in 0..5 {
            double e = w * xs[i] + b - ys[i];
            loss += e * e;
            gw += 2.0 * e * xs[i];
            gb += 2.0 * e;
        }
        if step % 500 == 0 { jout << "step " << step << "  loss " << loss / 5.0 << "\n"; }
        w = w - rate * gw / 5.0;
        b = b - rate * gb / 5.0;
    }
    jout << "w = " << w << "  b = " << b << "\n";
}

```

Output:

```
step 0  loss 67.000000
step 500  loss 0.000000
step 1000  loss 0.000000
w = 3.000000  b = 1.000000
```

The loss goes to almost 0 because the data lies exactly on a line.

**Try:** add the point x = 5, y = 20 (off the line) to the data and see how w and b move.

## Lesson 120. XOR with a small network

XOR is 1 when exactly one of two inputs is 1. A single straight line cannot separate its answers, but a hidden layer of tanh units can. This is the classic small network. The seeds are fixed, so every run is the same, and the loss falls step by step.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// XOR: two layers (6 tanh units, then a sigmoid) learn it. The seeds are fixed.
void main() {
    Graph g = Graph::make();
    Linear l1 = g.linear(2, 6, 1);
    Linear l2 = g.linear(6, 1, 2);
    g.mark();
    double[] xv = arr(8);
    xv.push(0.0); xv.push(0.0); xv.push(0.0); xv.push(1.0);
    xv.push(1.0); xv.push(0.0); xv.push(1.0); xv.push(1.0);
    double[] yv = arr(4);
    yv.push(0.0); yv.push(1.0); yv.push(1.0); yv.push(0.0);
    Tensor32 xs = Tensor32::from_list(4, 2, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    for step in 0..3000 {
        int h = g.tanh(g.apply(l1, g.input(xs)));
        int o = g.sigmoid(g.apply(l2, h));
        int l = g.mse(o, ys);
        if step % 1000 == 0 { jout << "step " << step << "  loss " << g.value(l).d[0] << "\n"; }
        g.backward(l);
        g.sgd(0.5);
        g.clear();
    }
    int h = g.tanh(g.apply(l1, g.input(xs)));
    Tensor32 out = g.value(g.sigmoid(g.apply(l2, h)));
    for i in 0..4 {
        jout << (int)(xs.get(i, 0)) << " xor " << (int)(xs.get(i, 1)) << " -> " << (int)(out.d[i] + 0.5) << "  (exact " << out.d[i] << ")\n";
    }
}

```

Output:

```
step 0  loss 0.277362
step 1000  loss 0.001553
step 2000  loss 0.000650
0 xor 0 -> 0  (exact 0.010549)
0 xor 1 -> 1  (exact 0.976775)
1 xor 0 -> 1  (exact 0.980717)
1 xor 1 -> 0  (exact 0.024364)
```

The outputs are rounded to 0 or 1; the exact value is shown too. If a seed does not reach the answers, change the seed (the last argument of `linear`).

**Try:** make the hidden layer 2 units (`g.linear(2, 2, 1)`, `g.linear(2, 1, 2)`) and see whether it still learns.

## Lesson 121. Backpropagation on the graph

Backpropagation is the chain rule run backwards over the graph. Each node knows its operation (`op`) and its parents (`pa`, `pb`). `backward(loss)` starts with gradient 1 at the loss and passes it to the parents. Here the graph is input, param, matmul, relu and mse, and the gradient of the weight is checked by hand.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// the operation of a node, by its number (the OP_ functions of <neuron>)
String op_name(int op) {
    if op == OP_INPUT() { return "input"; }
    if op == OP_PARAM() { return "param"; }
    if op == OP_MATMUL() { return "matmul"; }
    if op == OP_RELU() { return "relu"; }
    if op == OP_MSE() { return "mse"; }
    return "other";
}
void main() {
    Graph g = Graph::make();
    double[] wv = arr(2);
    wv.push(0.5); wv.push(1.0);
    double[] xv = arr(2);
    xv.push(1.0); xv.push(2.0);
    double[] tv = arr(1);
    tv.push(1.0);
    int w = g.param(Tensor32::from_list(2, 1, wv));
    g.mark();
    int x = g.input(Tensor32::from_list(1, 2, xv));
    int h = g.relu(g.matmul(x, w));
    int loss = g.mse(h, Tensor32::from_list(1, 1, tv));
    for i in 0..g.count { jout << "node " << i << " " << op_name(g.op[i]) << "\n"; }
    g.backward(loss);
    Tensor32 gw = g.gradient(w);
    jout << "loss " << g.value(loss).d[0] << "\n";
    jout << "gradient of w: " << gw.d[0] << " " << gw.d[1] << "\n";
}

```

Output:

```
node 0 param
node 1 input
node 2 matmul
node 3 relu
node 4 mse
loss 2.250000
gradient of w: 3.000000 6.000000
```

The chain rule gives the weight's gradient as `2 * (2.5 - 1.0) * x`, which is `(3, 6)`. `backward` walks the nodes in reverse order, from the loss back to the inputs. A matmul passes `dy * B^T` to A and `A^T * dy` to B. The number of an operation is the value of its `OP_` function.

**Try:** change the weights to `(0.5, -1.0)` and predict the gradient before running: relu blocks it, so the answer is `(0, 0)`.

## Lesson 122. Mini-batches and shuffling

Training on all rows at once is slow for big data, so a mini-batch uses a few rows at a time. Shuffling the rows each epoch makes the batches differ. `shuffled(n, seed)` gives a random order of 0 to n-1 from a fixed seed, so the same seed always gives the same order. An epoch is one pass over all the rows.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// eight points of y = 2x + 1; each epoch shuffles the rows and trains on two mini-batches of four
void main() {
    Tensor32 xs = Tensor32::zeros(8, 1);
    Tensor32 ys = Tensor32::zeros(8, 1);
    for i in 0..8 {
        xs.set(i, 0, (double)i / 4.0);
        ys.set(i, 0, 2.0 * (double)i / 4.0 + 1.0);
    }
    Graph g = Graph::make();
    Linear lin = g.linear(1, 1, 3);
    g.mark();
    for epoch in 0..3 {
        int[] perm = shuffled(8, epoch + 1);
        jout << "epoch " << epoch << " order:";
        for i in 0..8 { jout << " " << perm[i]; }
        jout << "\n";
        for bt in 0..2 {
            int[] idx = arr(4);
            for q in 0..4 { idx.push(perm[bt * 4 + q]); }
            int o = g.apply(lin, g.input(xs.gather(idx)));
            int l = g.mse(o, ys.gather(idx));
            g.backward(l);
            g.sgd(0.5);
            g.clear();
        }
        int full = g.apply(lin, g.input(xs));
        int whole = g.mse(full, ys);
        jout << "  loss on all rows " << g.value(whole).d[0] << "\n";
        g.clear();
    }
}

```

Output:

```
epoch 0 order: 6 1 4 5 0 7 2 3
  loss on all rows 12.326004
epoch 1 order: 1 3 5 6 4 2 7 0
  loss on all rows 8.866676
epoch 2 order: 2 4 0 7 6 1 3 5
  loss on all rows 6.333731
```

Each epoch the order is new, so the batches are new. The loss on all rows goes down from epoch to epoch.

**Try:** compare `shuffled(8, 9)` with the order of seed 1 and check that they differ.

## Lesson 123. Softmax and cross-entropy

For classification the output is one score per class. `softmax` turns each row of scores into probabilities that add up to 1. Cross-entropy is the loss for that: `-log(probability of the right class)`, averaged over the rows. It is small when the right class has a big probability.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// three samples, three classes: row r holds the scores of the classes 0, 1, 2; the right class of row r is r
void main() {
    double[] v = arr(9);
    v.push(2.0); v.push(0.5); v.push(-1.0);
    v.push(0.1); v.push(0.3); v.push(0.2);
    v.push(1.0); v.push(0.0); v.push(2.5);
    Tensor s = Tensor::zeros(3, 3);
    for i in 0..9 { s.d[i] = v[i]; }
    Tensor p = s.softmax();
    for r in 0..3 {
        double sum = 0.0;
        jout << "probabilities " << r << ":";
        for c in 0..3 {
            jout << " " << p.get(r, c);
            sum += p.get(r, c);
        }
        jout << "  sum " << sum << "\n";
    }
    int[] right = arr(3);
    right.push(0); right.push(1); right.push(2);
    double hand = 0.0;
    for r in 0..3 { hand = hand - Math::log(p.get(r, right[r])); }
    jout << "cross-entropy by hand " << hand / 3.0 << "\n";
    Graph g = Graph::make();
    int a = g.input(Tensor32::from_list(3, 3, v));
    int l = g.softmax_ce(a, right);
    jout << "cross-entropy by the library " << g.value(l).d[0] << "\n";
}

```

Output:

```
probabilities 0: 0.785597 0.175290 0.039113  sum 1.000000
probabilities 1: 0.300610 0.367165 0.332225  sum 1.000000
probabilities 2: 0.170953 0.062890 0.766157  sum 1.000000
cross-entropy by hand 0.503207
cross-entropy by the library 0.503207
```

`softmax_ce` does both steps (softmax, then the log) in one node, and gives the same number as the hand calculation.

**Try:** make the right class of row 0 the class 2 (`right[0] = 2`) and watch the loss grow, because the score of class 2 in that row is the lowest.

## Lesson 124. The learning rate

The learning rate is the size of each step. Too small and training is slow. Too big and each step overshoots the bottom, so the weight swings wider and wider. Here the line `y = 2x` is trained with two rates: 0.2 converges, 0.22 diverges.

```jk
#import <stdlib>
#import <math>
using stdlib;
// y = 2x on x = 1, 2, 3: train w with one rate for 60 steps and return it
double train(double rate) {
    double[] xs = arr(3);
    xs.push(1.0); xs.push(2.0); xs.push(3.0);
    double[] ys = arr(3);
    ys.push(2.0); ys.push(4.0); ys.push(6.0);
    double w = 0.0;
    for step in 0..60 {
        double g = 0.0;
        for i in 0..3 { g += 2.0 * (w * xs[i] - ys[i]) * xs[i]; }
        w = w - rate * g / 3.0;
    }
    return w;
}
void main() {
    double small = train(0.2);
    double big = train(0.22);
    jout << "rate 0.2:  w = " << small << "  converged: " << (Math::abs(small - 2.0) < 0.01) << "\n";
    jout << "rate 0.22: w = " << big << "  converged: " << (Math::abs(big - 2.0) < 0.01) << "\n";
}

```

Output:

```
rate 0.2:  w = 1.999627  converged: true
rate 0.22: w = -43.183479  converged: false
```

For this data the rate must stay below about 0.214: the curvature of the loss is (2/3) * (1 + 4 + 9) = 9.33, and each step multiplies the error by `1 - rate * 9.33`. That factor has size 1 at rate 0.214. Pick the largest rate that still converges, with some room to spare.

**Try:** try 0.21 and 0.1 and see which converges fastest.

## Lesson 125. Starting weights

The starting weights matter. If they are all zero, every neuron learns the same thing. Random weights break that tie, but they must stay small: `Dense::make` draws each weight from -1 to 1 times `sqrt(2 / inputs)`, so a neuron with more inputs gets smaller weights. A seed makes the random numbers the same on every run.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// the starting weights: the same seed gives the same weights; the size is limited by sqrt(2 / inputs)
void main() {
    Dense a = Dense::make(4, 3, 5);
    Dense b = Dense::make(4, 3, 5);
    Dense c = Dense::make(4, 3, 6);
    double limit = Math::sqrt(2.0 / 4.0);
    bool inside = true;
    bool same = true;
    bool other = false;
    for i in 0..12 {
        if Math::abs(a.w.d[i]) > limit { inside = false; }
        if a.w.d[i] != b.w.d[i] { same = false; }
        if a.w.d[i] != c.w.d[i] { other = true; }
    }
    jout << "limit sqrt(2/4) = " << limit << "\n";
    jout << "first weights of seed 5:";
    for i in 0..4 { jout << " " << a.w.d[i]; }
    jout << "\n";
    jout << "all inside the limit: " << inside << "\n";
    jout << "same seed, same weights: " << same << "\n";
    jout << "other seed, other weights: " << other << "\n";
}

```

Output:

```
limit sqrt(2/4) = 0.707107
first weights of seed 5: 0.287792 0.613769 0.699329 0.046669
all inside the limit: true
same seed, same weights: true
other seed, other weights: true
```

Every weight of the layer is inside the limit. Two layers with the same seed are equal, and a different seed gives different numbers.

**Try:** make a layer with 16 inputs and print its limit, `sqrt(2 / 16)`, before you run it.

## Lesson 126. Embeddings

A word cannot go into a layer as text, so each word gets a number (an id), and the embedding table has one row for each id. `g.embed(table, ids)` copies the rows of the given ids: a sentence of three words gives a table of three rows. The rows are learned like any other weight. Here the vocabulary has six words.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// six words; each word is one row of the table (4 numbers); the id of a word is its row number
void main() {
    String[] words = arr(6);
    words.push("cat"); words.push("sat"); words.push("on");
    words.push("the"); words.push("mat"); words.push("dog");
    Graph g = Graph::make();
    int table = g.param(Tensor32::random(6, 4, 3, 0.5));
    g.mark();
    int[] ids = arr(3);
    ids.push(3); ids.push(5); ids.push(1);
    int e = g.embed(table, ids);
    Tensor32 rows = g.value(e);
    jout << "rows " << rows.rows() << " columns " << rows.cols() << "\n";
    for i in 0..3 {
        jout << words[ids[i]] << ":";
        for k in 0..4 { jout << " " << rows.get(i, k); }
        jout << "\n";
    }
    bool same = true;
    for k in 0..4 {
        if rows.get(1, k) != g.value(table).get(5, k) { same = false; }
    }
    jout << "the row of dog is row 5 of the table: " << same << "\n";
}

```

Output:

```
rows 3 columns 4
the: -0.383500 0.475000 -0.476500 -0.438000
dog: -0.187500 -0.385000 0.183500 -0.170000
sat: -0.179500 0.159000 -0.048500 -0.114000
the row of dog is row 5 of the table: true
```

The sentence is the ids 3, 5, 1: the, dog, sat. The lookup copies the rows, and the gradient of the lookup goes back into the same rows during training.

**Try:** change the sentence to `ids` 0, 1, 4 (cat, sat, mat) and check the first row again.

## Lesson 127. A tiny character model

A character model reads bytes. Given the last 8 bytes, it guesses the next byte at every place. `Gpt` in `<neuron>` is that model at a small size: an embedding, attention, a GELU layer, and AdamW for training. Here a short text that repeats teaches it the pattern, and the loss goes down.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// a tiny character model: it reads 8 bytes and guesses the next one at every place. The text repeats, so the loss falls.
Gpt m;
void main() {
    String text = "abcabcabcabcabcabcabcabc";
    int[] data = Gpt::bytes(text);
    m = Gpt::make(256, 8, 16, 2, 1, 1);
    int[] starts = arr(4);
    starts.push(0); starts.push(4); starts.push(8); starts.push(12);
    for step in 0..60 {
        double loss = m.step(data, starts, 0.01, 0.0, 1.0);
        if step % 15 == 0 { jout << "step " << step << "  loss " << loss << "\n"; }
    }
    jout << "loss at the end " << m.loss_on(data, starts) << "\n";
}

```

Output:

```
step 0  loss 6.085010
step 15  loss 0.248414
step 30  loss 0.010925
step 45  loss 0.002814
loss at the end 0.001733
```

Each number shown is the mean loss of the batch, measured before that step's update. The last line is measured after training, with no learning.

**Try:** use another short pattern, such as `"xyxyxyxyxyxyxyxyxyxyxyxy"`, and compare how fast the loss falls.

## Lesson 128. Saving and loading weights

A trained network is useful only if it can be kept. `save(path)` writes the weights as text (the layer sizes and the numbers), and `Network::load(path)` reads them back. The loaded network gives the same answers as the one that was saved.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// train a network on XOR, save its weights to a file, load them back and compare the answers
void main() {
    Tensor x = Tensor::zeros(4, 2);
    Tensor y = Tensor::zeros(4, 1);
    x.set(1, 1, 1.0); x.set(2, 0, 1.0); x.set(3, 0, 1.0); x.set(3, 1, 1.0);
    y.set(1, 0, 1.0); y.set(2, 0, 1.0);
    Network n = Network::make();
    n.add(2, 8);
    n.add(8, 1);
    n.fit(x, y, 4000, 0.1);
    bool saved = n.save("tut_net.jw");
    Network m = Network::load("tut_net.jw");
    Tensor a = n.predict(x);
    Tensor b = m.predict(x);
    double worst = 0.0;
    for i in 0..4 {
        double d = Math::abs(a.d[i] - b.d[i]);
        if d > worst { worst = d; }
    }
    jout << "saved: " << saved << "\n";
    jout << "loaded answers equal: " << (worst < 0.000001) << "\n";
    Fs::remove("tut_net.jw");
}

```

Output:

```
saved: true
loaded answers equal: true
```

The file is plain text, so you can read and copy it. The program removes its file at the end.

**Try:** print `n.text()` before saving and find the first line, `neuron-jw 1`.

## Lesson 129. Inference: using a trained network

Inference is using a trained network: only the forward pass runs. `predict` does not learn, so the weights do not change, however many times it is called. This is what a finished program does with a loaded network.

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// inference: a trained network answers; predict runs only the forward pass
void main() {
    Tensor x = Tensor::zeros(4, 2);
    Tensor y = Tensor::zeros(4, 1);
    x.set(1, 1, 1.0); x.set(2, 0, 1.0); x.set(3, 0, 1.0); x.set(3, 1, 1.0);
    y.set(1, 0, 1.0); y.set(2, 0, 1.0);
    Network n = Network::make();
    n.add(2, 8);
    n.add(8, 1);
    n.fit(x, y, 4000, 0.1);
    String before = n.text();
    Tensor answer = n.predict(x);
    for i in 0..4 {
        jout << "(" << x.get(i, 0) << ", " << x.get(i, 1) << ") -> " << (int)(answer.d[i] + 0.5) << "\n";
    }
    Tensor one = Tensor::zeros(1, 2);
    one.set(0, 0, 1.0);
    jout << "(1, 0) -> " << (int)(n.predict(one).d[0] + 0.5) << "\n";
    for k in 0..100 { n.predict(x); }
    jout << "weights unchanged after 100 calls: " << (n.text() == before) << "\n";
}

```

Output:

```
(0.000000, 0.000000) -> 0
(0.000000, 1.000000) -> 1
(1.000000, 0.000000) -> 1
(1.000000, 1.000000) -> 0
(1, 0) -> 1
weights unchanged after 100 calls: true
```

The answers are rounded to 0 or 1. The last check compares the text of all the weights before and after 100 calls to `predict`.

**Try:** predict the answer for `(0, 0)` and for `(1, 1)` and compare them with the table above.

## Lesson 130. Why matmul is the speed

Most of the time of training goes into matrix products: every layer does three of them in a step (the forward pass, the gradient of the input, and the gradient of the weights). `matmul_fast` makes each product faster: the numbers are float32, each dot product uses four-wide vectors in two accumulators, and the rows are shared by four threads. This program checks the fast table against the plain one. It prints no timing, because timings change from phone to phone.

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// one matrix product of 64 x 64 by 64 x 64: 262144 multiply-adds. The fast way must give the same table.
void main() {
    Tensor a = Tensor::zeros(64, 64);
    Tensor b = Tensor::zeros(64, 64);
    for i in 0..64 * 64 {
        a.d[i] = (double)(i % 9) * 0.1 - 0.4;
        b.d[i] = (double)(i % 5) * 0.2 - 0.4;
    }
    Tensor slow = a.matmul(b);
    Tensor fast = a.matmul_fast(b);
    double worst = 0.0;
    double sum = 0.0;
    for i in 0..64 * 64 {
        double diff = Math::abs(slow.d[i] - fast.d[i]);
        if diff > worst { worst = diff; }
        sum += fast.d[i];
    }
    jout << "multiply-adds: " << 64 * 64 * 64 << "\n";
    jout << "same table: " << (worst < 0.001) << "\n";
    jout << "sum of the table: " << sum << "\n";
}

```

Output:

```
multiply-adds: 262144
same table: true
sum of the table: 0.020048
```

A micro-kernel is the innermost piece of a matrix product: a small block of results (for example 4 rows by 8 columns) is kept in vector registers while the loop over the shared dimension runs, so that the numbers are loaded once and reused. A 4x8 kernel of this kind is an experiment of the compiler's own work and is not in `<neuron>` yet; the `matmul_fast` above is the one you can use today.

**Try:** change 64 to 128 in the sizes and check that the table is still the same (the work grows eight times).

## Lesson 131. A program of several files

A big program is split into files. Each file that ends in `.j` has one idea (a shape, a report, a parser) and no `main`; the file with `main` (`.jk`) imports them. A file is read once, even when two files import it. Here `report.j` uses `geometry.j`, and `main.jk` uses both.

`geometry.j`:

```jk
// geometry.j -- a component: a point and the distance between two points. No main here.
struct Point {
    int x;
    int y;
}

int manhattan(Point a, Point b) {
    int dx = a.x - b.x;
    int dy = a.y - b.y;
    if dx < 0 { dx = -dx; }
    if dy < 0 { dy = -dy; }
    return dx + dy;
}
```

`ec_multi_files.jk`:

`report.j`:

```jk
#import <stdlib>
using stdlib;

#import "geometry"

// report.j -- a component that uses geometry.j
void print_distance(Point a, Point b) {
    jout << "distance " << manhattan(a, b) << "\n";
}
```

`ec_multi_files.jk`:

```jk
#import <stdlib>
using stdlib;

#import "geometry"
#import "report"

void main() {
    Point home = {0, 0};
    Point shop = {3, -4};
    print_distance(home, shop);
    jout << "same again: " << manhattan(shop, home) << "\n";
}
```

Output:

```
distance 7
same again: 7
```

Compile only the main file: `jcmp main.jk -o main`. The compiler finds `report.j` and `geometry.j` next to it. Keep the names of the files the same as the names you import.

**Try:** add a function `int chebyshev(Point a, Point b)` to `geometry.j` (the larger of the two differences) and print it from `main.jk`.

## Lesson 132. A test for your own function

A test checks one result: it calls your function with a known input and compares the answer with the answer you expect. Here is a tiny test runner in J2K: each check prints `PASS` or `FAIL`, and the last line counts them. You can keep the runner in its own `.j` file and use it in every program.

```jk
#import <stdlib>
using stdlib;

int passed = 0;
int failed = 0;

// the function under test
int clamp(int x, int lo, int hi) {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

void check_int(String name, int got, int want) {
    if got == want {
        passed += 1;
        jout << "PASS " << name << "\n";
    } else {
        failed += 1;
        jout << "FAIL " << name << ": got " << got << ", want " << want << "\n";
    }
}

void main() {
    check_int("below the range", clamp(-5, 0, 10), 0);
    check_int("inside the range", clamp(7, 0, 10), 7);
    check_int("above the range", clamp(99, 0, 10), 10);
    check_int("the edge", clamp(10, 0, 10), 10);
    jout << passed << " passed, " << failed << " failed\n";
}
```

Output:

```
PASS below the range
PASS inside the range
PASS above the range
PASS the edge
4 passed, 0 failed
```

Output of the test runner: a `FAIL` line tells you the name, what the function gave and what you expected. Keep one `check` per behaviour, with a name that says it.

**Try:** change one expected value to a wrong number and see the `FAIL` line and the count.

## Lesson 133. Errors in a program that reads input

Input can be wrong, and a wrong input is not a bug in the program. A function that can fail returns a `Result<int, Error>`: either `Ok` with the value or `Err` with a message. The program reads words from the input, prints the result of each one, and keeps going when one is bad. The input is `12 x -3 7y 40`.

```jk
#import <stdlib>
using stdlib;

// a whole number from text: an optional minus sign, then digits only
Result<int, Error> parse_int(char^ s) {
    int i = 0;
    bool negative = false;
    if s[0] == '-' {
        negative = true;
        i = 1;
    }
    if s[i] == 0 {
        return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "empty number"));
    }
    int value = 0;
    while s[i] != 0 {
        if s[i] < '0' || s[i] > '9' {
            return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "not a number"));
        }
        value = value * 10 + (s[i] - '0');
        i += 1;
    }
    if negative { value = -value; }
    return Result<int, Error>::Ok(value);
}

void main() {
    char w[32];
    int total = 0;
    int bad = 0;
    try {
        while true {
            jin >> w;
            Result<int, Error> r = parse_int(@w);
            switch r {
                Result::Ok(v): {
                    total += v;
                    jout << w << " is " << v << "\n";
                }
                Result::Err(e): {
                    bad += 1;
                    jout << w << " is wrong: " << e.message << "\n";
                }
            }
        }
    } catch (e) {
        // the input is over
    }
    jout << "total " << total << ", " << bad << " wrong\n";
}
```

Input: `12 x -3 7y 40`

Output:

```
12 is 12
x is wrong: not a number
-3 is -3
7y is wrong: not a number
40 is 40
total 49, 2 wrong
```

`Error` has a `kind` (what sort of failure) and a `message`. The program decides what a failure means: here it counts it and goes on. The other choice is to stop at once, with `unwrap()`, which panics on an `Err`. `Option<T>` is the same idea for a value that may be missing, such as `Env::get(name)`.

**Try:** make the program stop at the first wrong word instead of counting it.

## Lesson 134. Command-line arguments

`Env::args()` gives the words that were typed after the program's name, as a list of Strings. Element 0 is the name of the program itself. A program that needs arguments checks how many it got and prints a usage line when they are missing.

```jk
#import <stdlib>
using stdlib;

// usage: sum NUMBER NUMBER
void main() {
    String[] a = Env::args();
    jout << "arguments given: " << (a.len - 1) << "\n";
    if a.len != 3 {
        jout << "usage: sum NUMBER NUMBER\n";
        return;
    }
    int x = a[1].to_int();
    int y = a[2].to_int();
    jout << x << " + " << y << " = " << x + y << "\n";
}
```

Output:

```
arguments given: 0
usage: sum NUMBER NUMBER
```

Run it as `./sum 20 22`: the output is `20 + 22 = 42`. Without the two numbers it prints the usage line instead. `to_int()` reads the number from the text. The arguments are always Strings: a number in them has to be converted.

**Try:** print every argument in a loop from index 1 to `a.len - 1`.

## Lesson 135. Reading a text file line by line

`Fs::write_text` writes a file and `Fs::read_lines` gives its lines as a list of Strings. The program below writes a small file in the current folder, reads it back line by line, counts the words of each line, and removes the file. A word is a run of letters between spaces.

```jk
#import <stdlib>
using stdlib;

// the number of words in one line: a word starts where a letter follows a space
int count_words(String line) {
    int n = 0;
    bool inside = false;
    for i in 0..line.len {
        if line[i] == ' ' {
            inside = false;
        } else if !inside {
            inside = true;
            n += 1;
        }
    }
    return n;
}

void main() {
    String path = "lines_demo.txt";
    Fs::write_text(path, "the first line\nthe second line has more words\n\nlast\n").unwrap();
    String[] lines = Fs::read_lines(path).unwrap();
    int words = 0;
    for i in 0..lines.len {
        int n = count_words(lines[i]);
        words += n;
        jout << "line " << (i + 1) << ": " << n << " words\n";
    }
    jout << lines.len << " lines, " << words << " words\n";
    Fs::remove(path);
}
```

Output:

```
line 1: 3 words
line 2: 6 words
line 3: 0 words
line 4: 1 words
4 lines, 10 words
```

The empty line between the two parts has 0 words. The file is in the current folder and is removed at the end, so the program leaves nothing behind. Use `Path::join` when a name has folders in it.

**Try:** also count the characters of the file (the sum of `lines[i].len`, plus one for each line break).

## Lesson 136. Writing a CSV report

A CSV file is a table in text: one line per row, the fields separated by commas. `Csv::join_line` builds a line from the fields and puts quotes around a field that has a comma in it. The program makes a small sales report, writes it as CSV, reads it back, and prints it as a table with aligned columns.

```jk
#import <stdlib>
using stdlib;

struct Sale {
    String item;
    int qty;
    double price;
}

Sale make_sale(String item, int qty, double price) {
    Sale s;
    s.item = item;
    s.qty = qty;
    s.price = price;
    return s;
}

void main() {
    Sale[] sales = arr(3);
    sales.push(make_sale("pen, blue", 3, 1.5));
    sales.push(make_sale("notebook", 2, 2.25));
    sales.push(make_sale("ink", 10, 0.4));

    String path = "sales_demo.csv";
    String text = "item,qty,price,total\n";
    for i in 0..sales.len {
        String[] f = arr(4);
        f.push(sales[i].item);
        f.push(Fmt::fixed((double)sales[i].qty, 0));
        f.push(Fmt::fixed(sales[i].price, 2));
        f.push(Fmt::fixed((double)sales[i].qty * sales[i].price, 2));
        text = text + Csv::join_line(f) + "\n";
    }
    Fs::write_text(path, text).unwrap();

    // read it back and print it as a table
    String[] lines = Fs::read_lines(path).unwrap();
    for i in 0..lines.len {
        String[] f = Csv::split_line(lines[i]);
        jout << Fmt::pad_right(f[0], 12, ' ') << Fmt::pad_left(f[1], 4, ' ') << Fmt::pad_left(f[2], 8, ' ') << Fmt::pad_left(f[3], 8, ' ') << "\n";
    }
    Fs::remove(path);
}
```

Output:

```
item         qty   price   total
pen, blue      3    1.50    4.50
notebook       2    2.25    4.50
ink           10    0.40    4.00
```

Everything in the table came from the file. `Csv::join_line` put quotes around `pen, blue` because it has a comma; `Csv::split_line` took the quotes off again. `Fmt::fixed(x, 2)` always writes two decimals, which is what a money column needs.

**Try:** add a row with a price of 12.5 and check that the total column still lines up.

## Lesson 137. JSON in and out

A program often gets JSON and answers with JSON. `Json::parse` reads the text into a document; you walk it with node numbers, add up what you need, and write the answer as JSON with `Json::quote` (a text) and `Json::num_text` (a number). The input here is a list of orders, and the answer is a JSON object with the total of the paid orders.

```jk
#import <stdlib>
using stdlib;

void main() {
    String text = "[{\"item\": \"tea\", \"price\": 2.5, \"paid\": true}, {\"item\": \"cake\", \"price\": 3.25, \"paid\": false}, {\"item\": \"jam\", \"price\": 4, \"paid\": true}]";
    JsonDoc doc = Json::parse(text).unwrap();
    int root = doc.root();
    double paid_total = 0.0;
    int unpaid = 0;
    for i in 0..doc.len(root) {
        int order = doc.at(root, i);
        double price = doc.number(doc.get(order, "price"));
        if doc.boolean(doc.get(order, "paid")) {
            paid_total += price;
            jout << "paid: " << Json::quote(doc.text(doc.get(order, "item"))) << "\n";
        } else {
            unpaid += 1;
        }
    }
    String answer = "{\"paid_total\": " + Json::num_text(paid_total) + ", \"unpaid\": " + Json::num_text((double)unpaid) + "}";
    jout << answer << "\n";
    JsonDoc back = Json::parse(answer).unwrap();
    jout << "read back: " << back.number(back.get(back.root(), "paid_total")) << "\n";
}
```

Output:

```
paid: "tea"
paid: "jam"
{"paid_total": 6.5, "unpaid": 1}
read back: 6.500000
```

`Json::parse` gives a `Result`, so a broken text does not crash the program. The answer is plain text, so it can be sent to another program or saved. Reading it back with `Json::parse` is a good test that the answer is valid JSON.

**Try:** add a fourth order with `"paid": true` and a price of 1.25, and check that `paid_total` becomes 7.75.

## Lesson 138. A small state machine

A state machine is a program that is always in one state, and each event moves it to the next one. An `enum class` with data is a good way to write the states: `Paying(int cents)` remembers how much has been paid. This vending machine costs 25 cents. Coins are 5, 10, 20 and so on; the event 0 is "nothing put in".

```jk
#import <stdlib>
using stdlib;

enum class Vend {
    Idle,
    Paying(int cents),
    Change(int back)
}

// the next state from the current one and an event (a coin in cents; 0 = nothing put in)
Vend step(Vend s, int coin) {
    switch s {
        Vend::Idle: {
            if coin > 0 { return Vend::Paying(coin); }
            return Vend::Idle;
        }
        Vend::Paying(c): {
            int sum = c + coin;
            if sum >= 25 { return Vend::Change(sum - 25); }
            return Vend::Paying(sum);
        }
        Vend::Change(b): {
            return Vend::Idle;
        }
    }
    return s;
}

void show(Vend s) {
    switch s {
        Vend::Idle: jout << "idle\n";
        Vend::Paying(c): jout << "paying, " << c << " cents so far\n";
        Vend::Change(b): jout << "give back " << b << " cents\n";
    }
}

void main() {
    Vend s = Vend::Idle;
    int events[5];
    events[0] = 10;
    events[1] = 10;
    events[2] = 10;
    events[3] = 0;
    events[4] = 0;
    for i in 0..5 {
        s = step(s, events[i]);
        show(s);
    }
}
```

Output:

```
paying, 10 cents so far
paying, 20 cents so far
give back 5 cents
idle
idle
```

Each state is a value of the enum, so it can be copied and passed around, and `switch` makes sure every state is handled. The machine has no hidden variables: all that it knows is in the value `s`.

**Try:** add a state `Broken` that the machine goes to on a coin of 100 or more, and handle it in `show`.

## Lesson 139. A tokenizer for arithmetic

Before a program can understand `(12 + 3) * 4`, it cuts the text into tokens: numbers, operators and brackets. This is the tokenizer. It walks the text with an index, skips spaces, and builds one number from a run of digits. The tokens are an `enum class` with data, kept in a list.

```jk
#import <stdlib>
using stdlib;

enum class Token {
    Num(int value),
    Op(char sign),
    Open,
    Close
}

Token[] tokenize(String s) {
    Token[] out = arr(8);
    int i = 0;
    while i < s.len {
        char c = s[i];
        if c == ' ' {
            i += 1;
        } else if c >= '0' && c <= '9' {
            int v = 0;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                v = v * 10 + (s[i] - '0');
                i += 1;
            }
            out.push(Token::Num(v));
        } else if c == '(' {
            out.push(Token::Open);
            i += 1;
        } else if c == ')' {
            out.push(Token::Close);
            i += 1;
        } else {
            out.push(Token::Op(c));
            i += 1;
        }
    }
    return out;
}

void main() {
    Token[] toks = tokenize("(12 + 3) * 4");
    for i in 0..toks.len {
        switch toks[i] {
            Token::Num(v): jout << "number " << v << "\n";
            Token::Op(c): jout << "operator " << c << "\n";
            Token::Open: jout << "open bracket\n";
            Token::Close: jout << "close bracket\n";
        }
    }
}
```

Output:

```
open bracket
number 12
operator +
number 3
close bracket
operator *
number 4
```

The tokenizer does not check that the tokens make sense: `12 12` gives two numbers in a row, which is the parser's job (lesson 140, the calculator, does that). A character that is not known is kept as an `Op`, so the parser can report it.

**Try:** make a `Token::Name(String)` for letters, so that `x + 1` is also tokenized.

## Lesson 140. A calculator with recursive descent

A recursive-descent parser has one function for each level of the grammar: `expr` (plus and minus), `term` (times and divide) and `factor` (a number or a bracket). Each function reads the tokens it needs and calls the next level. A bracket calls `expr` again, which is why it is recursive. The tokenizer is in its own file, `tokens.j`, from lesson 139, and this program imports it.

`tokens.j`:

```jk
#import <stdlib>
using stdlib;

// tokens.j -- the tokenizer of the lesson before (no main here)
enum class Token {
    Num(int value),
    Op(char sign),
    Open,
    Close
}

Token[] tokenize(String s) {
    Token[] out = arr(8);
    int i = 0;
    while i < s.len {
        char c = s[i];
        if c == ' ' {
            i += 1;
        } else if c >= '0' && c <= '9' {
            int v = 0;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                v = v * 10 + (s[i] - '0');
                i += 1;
            }
            out.push(Token::Num(v));
        } else if c == '(' {
            out.push(Token::Open);
            i += 1;
        } else if c == ')' {
            out.push(Token::Close);
            i += 1;
        } else {
            out.push(Token::Op(c));
            i += 1;
        }
    }
    return out;
}
```

`ec_calculator.jk`:

```jk
#import <stdlib>
using stdlib;

#import "tokens"

Token[] toks;
int pos = 0;

// the token at the position, or an operator that matches nothing when the list is over
char peek_op() {
    if pos >= toks.len { return '#'; }
    switch toks[pos] {
        Token::Op(c): return c;
        _: return '#';
    }
    return '#';
}

int factor() {
    if pos >= toks.len { return 0; }
    Token t = toks[pos];
    pos += 1;
    switch t {
        Token::Num(v): return v;
        Token::Open: {
            int v = expr();
            pos += 1;          // skip the close bracket
            return v;
        }
        _: return 0;
    }
    return 0;
}

int term() {
    int v = factor();
    while peek_op() == '*' || peek_op() == '/' {
        char op = peek_op();
        pos += 1;
        int r = factor();
        if op == '*' { v = v * r; } else { v = v / r; }
    }
    return v;
}

int expr() {
    int v = term();
    while peek_op() == '+' || peek_op() == '-' {
        char op = peek_op();
        pos += 1;
        int r = term();
        if op == '+' { v = v + r; } else { v = v - r; }
    }
    return v;
}

int calc(String s) {
    toks = tokenize(s);
    pos = 0;
    return expr();
}

void main() {
    String[] sums = arr(4);
    sums.push("2 + 3 * (4 - 1)");
    sums.push("(10 - 4) / 2");
    sums.push("7 - 2 - 1");
    sums.push("100 / 7 / 2");
    for i in 0..sums.len {
        jout << sums[i] << " = " << calc(sums[i]) << "\n";
    }
}
```

Output:

```
2 + 3 * (4 - 1) = 11
(10 - 4) / 2 = 3
7 - 2 - 1 = 4
100 / 7 / 2 = 7
```

`7 - 2 - 1` is 4 and not 6: the loop in `expr` takes the operators from the left, one after another, as arithmetic does. The brackets in `factor` are what makes the grammar recursive: `expr` calls `factor`, which calls `expr`. The functions can be written in any order, because a function may be used before it is written.

**Try:** add a unary minus (`-5 + 2`) to `factor`.

## Lesson 141. A heap from scratch

A heap is a tree stored in a list: the smallest value is always at index 0. `push` adds a value at the end and moves it up while it is smaller than its parent; `pop` takes index 0 and moves the last value up to its place and down again. Pushing numbers and popping them all gives them in order: that is heap sort.

```jk
#import <stdlib>
using stdlib;

struct MinHeap {
    int[] a;

    void push(self, int x) {
        self.a.push(x);
        int i = self.a.len - 1;
        while i > 0 {
            int parent = (i - 1) / 2;
            if self.a[i] >= self.a[parent] { break; }
            int t = self.a[i];
            self.a[i] = self.a[parent];
            self.a[parent] = t;
            i = parent;
        }
    }

    int pop(self) {
        int top = self.a[0];
        int last = self.a.len - 1;
        self.a[0] = self.a[last];
        self.a.pop();
        int i = 0;
        while true {
            int l = 2 * i + 1;
            int r = l + 1;
            int m = i;
            if l < self.a.len && self.a[l] < self.a[m] { m = l; }
            if r < self.a.len && self.a[r] < self.a[m] { m = r; }
            if m == i { break; }
            int t = self.a[i];
            self.a[i] = self.a[m];
            self.a[m] = t;
            i = m;
        }
        return top;
    }
}

void main() {
    MinHeap h;
    h.a = arr(8);
    int input[7];
    input[0] = 5; input[1] = 3; input[2] = 8; input[3] = 1;
    input[4] = 9; input[5] = 2; input[6] = 7;
    for i in 0..7 { h.push(input[i]); }
    jout << "smallest first: ";
    while h.a.len > 0 {
        jout << h.pop() << " ";
    }
    jout << "\n";
}
```

Output:

```
smallest first: 1 2 3 5 7 8 9 
```

The heap is a struct with a method for each step, and the list it keeps is an ordinary `int[]`. The standard library has a `Heap<T>` as well (`std/collections.j`); writing one yourself shows what it does. A priority queue, such as the next task to run, is a heap of (priority, task) pairs.

**Try:** make it a max-heap by changing the two comparisons.

## Lesson 142. Word frequency with a hash map

`Map<K, V>` is the hash table of the standard library: `put` stores a value under a key, `get` reads it, `has` asks whether a key is there. To count words, a Map gives the count of each word: a word that is not there yet starts at 1, and the others get one more. `keys_list()` gives the words, which are sorted to print them in a fixed order.

```jk
#import <stdlib>
using stdlib;

void main() {
    String[] words = arr(16);
    words.push("the"); words.push("cat"); words.push("and"); words.push("the");
    words.push("dog"); words.push("and"); words.push("the"); words.push("bird");

    Map<String, int> count;
    for i in 0..words.len {
        String w = words[i];
        if count.has(w) {
            count.put(w, count.get(w) + 1);
        } else {
            count.put(w, 1);
        }
    }

    String[] keys = count.keys_list();
    keys.sort();
    for i in 0..keys.len {
        jout << keys[i] << " " << count.get(keys[i]) << "\n";
    }
    jout << "distinct words: " << count.len << "\n";
}
```

Output:

```
and 2
bird 1
cat 1
dog 1
the 3
distinct words: 5
```

`get` on a key that is not there throws `key not found`, so a program asks `has` first, as above. The table grows by itself when it gets full. Sorting the keys gives the same output every time, even though the hash table itself has no fixed order.

**Try:** count the words of a sentence that you type in: put the words in an array from a file, as in lesson 135, instead.

## Lesson 143. Sorting with your own comparison

`sort_by<T>(list, less)` sorts with a comparison that you give: `less(x, y)` is true when `x` must come before `y`. The comparison can be a named function or a lambda (a function without a name, written where it is used). The sort is stable: items that compare equal keep their order.

```jk
#import <stdlib>
using stdlib;

// a named comparison: the bigger number first
bool bigger_first(int x, int y) { return x > y; }

void main() {
    int[] nums = arr(8);
    nums.push(5); nums.push(12); nums.push(7); nums.push(30); nums.push(2);

    sort_by<int>(nums, bigger_first);
    for i in 0..nums.len { jout << nums[i] << " "; }
    jout << "\n";

    // a lambda: order by the last digit (equal digits keep their order)
    sort_by<int>(nums, bool(int x, int y) { return x % 10 < y % 10; });
    for i in 0..nums.len { jout << nums[i] << " "; }
    jout << "\n";

    // a lambda for decimals: by the distance from zero
    double[] ds = arr(3);
    ds.push(-2.5); ds.push(1.0); ds.push(-4.0);
    sort_by<double>(ds, bool(double x, double y) { return x * x < y * y; });
    for i in 0..ds.len { jout << ds[i] << " "; }
    jout << "\n";
}
```

Output:

```
30 12 7 5 2 
30 12 2 5 7 
1.000000 -2.500000 -4.000000 
```

The second sort orders the numbers by their last digit: 30 (0) comes first, then 12 and 2 (both end in 2). 12 was before 2 in the list, and the sort is stable, so 12 stays before 2. The decimals are ordered by their square, so -2.5 and 1.0 come before -4.0.

**Try:** sort the numbers from the smallest to the biggest distance from 10 with a lambda.

## Lesson 144. A room graph for a text adventure

A text adventure is a graph: each room has an exit to the north, east, south and west, and an exit leads to another room or nowhere. Here a room is a struct, the rooms are a list, and an exit is the index of the other room, with `-1` for a wall. A list of moves walks the player through the rooms.

```jk
#import <stdlib>
using stdlib;

struct Room {
    String name;
    int north;
    int east;
    int south;
    int west;
}

// the index of the room in direction d (n e s w), or -1 for a wall
int exit_of(Room r, char d) {
    if d == 'n' { return r.north; }
    if d == 'e' { return r.east; }
    if d == 's' { return r.south; }
    if d == 'w' { return r.west; }
    return -1;
}

Room make_room(String name, int north, int east, int south, int west) {
    Room r;
    r.name = name;
    r.north = north;
    r.east = east;
    r.south = south;
    r.west = west;
    return r;
}

void main() {
    Room[] rooms = arr(3);
    Room hall = make_room("Hall", 1, -1, -1, -1);
    Room kitchen = make_room("Kitchen", -1, 2, 0, -1);
    Room garden = make_room("Garden", -1, -1, -1, 1);
    rooms.push(hall);
    rooms.push(kitchen);
    rooms.push(garden);

    String path = "nessw";
    int here = 0;
    jout << "start in " << rooms[here].name << "\n";
    for i in 0..path.len {
        char d = path[i];
        int next = exit_of(rooms[here], d);
        if next < 0 {
            jout << "a wall to the " << d << "\n";
        } else {
            here = next;
            jout << "go " << d << " to " << rooms[here].name << "\n";
        }
    }
    jout << "you are in the " << rooms[here].name << "\n";
}
```

Output:

```
start in Hall
go n to Kitchen
go e to Garden
a wall to the s
a wall to the s
go w to Kitchen
you are in the Kitchen
```

The rooms are data, and the walk is a loop: a new room or a new path needs no new code. Each room is a value, so `rooms[here]` reads it and `rooms[here].name` its name. The list of rooms could come from a file of JSON (lesson 137) in a bigger game.

**Try:** add a room `Cellar` below the kitchen and walk down into it.

## Lesson 145. A game loop without graphics

A game does the same thing again and again: update the world, then draw it. The update must not look at the clock, or the game plays differently on every machine. Instead it advances by a fixed step, `dt`, and the same number of steps always gives the same result. Here a ball falls and bounces once on the floor; the loop prints the height every 20 steps.

```jk
#import <stdlib>
using stdlib;

void main() {
    double dt = 1.0 / 60.0;     // a fixed step: 60 steps for each second, every time
    double gravity = -9.8;      // metres per second squared
    double height = 5.0;
    double speed = 0.0;
    bool bounced = false;

    for step in 0..300 {
        speed += gravity * dt;
        height += speed * dt;
        if height <= 0.0 {
            height = 0.0;
            if !bounced {
                speed = -speed * 0.6;
                bounced = true;
                jout << "bounce at step " << step << "\n";
            } else {
                speed = 0.0;
            }
        }
        if step % 20 == 0 {
            jout << "step " << step << " height " << Fmt::fixed(height, 2) << "\n";
        }
    }
    jout << "final height " << Fmt::fixed(height, 2) << "\n";
}
```

Output:

```
step 0 height 5.00
step 20 height 4.37
step 40 height 2.66
bounce at step 60
step 60 height 0.00
step 80 height 1.42
step 100 height 1.75
step 120 height 1.00
step 140 height 0.00
step 160 height 0.00
step 180 height 0.00
step 200 height 0.00
step 220 height 0.00
step 240 height 0.00
step 260 height 0.00
step 280 height 0.00
final height 0.00
```

Run the same program twice and you get the same numbers: nothing depends on the time it runs. A real game adds input and drawing to the loop, but the rule stays: the state changes only in the update, and `dt` is the same for every step.

**Try:** change `dt` to `1.0 / 30.0` and see how the bounce moves to another step.

## Lesson 146. A bank account with methods and checks

A struct with methods keeps its data and the rules for changing it together. A bank account keeps the money in cents, a whole number: money as a `double` gets small rounding errors. Each method checks its input before it changes anything, and returns `true` or `false` so the caller knows what happened.

```jk
#import <stdlib>
using stdlib;

struct Account {
    String owner;
    int cents;

    bool deposit(self, int amount) {
        if amount <= 0 { return false; }
        self.cents += amount;
        return true;
    }

    bool withdraw(self, int amount) {
        if amount <= 0 || amount > self.cents { return false; }
        self.cents -= amount;
        return true;
    }

    void show(self) {
        jout << self.owner << ": " << Fmt::fixed((double)self.cents / 100.0, 2) << "\n";
    }
}

void main() {
    Account acc;
    acc.owner = "Ann";
    acc.cents = 0;
    acc.deposit(5000);
    acc.show();

    if acc.withdraw(1250) {
        jout << "took 12.50\n";
    }
    acc.show();

    if !acc.withdraw(999999) {
        jout << "refused: not enough money\n";
    }
    if !acc.deposit(-5) {
        jout << "refused: the amount must be more than 0\n";
    }
    acc.show();
}
```

Output:

```
Ann: 50.00
took 12.50
Ann: 37.50
refused: not enough money
refused: the amount must be more than 0
Ann: 37.50
```

`withdraw` looks at the balance before it takes money out, so the balance can never go below 0 through this struct. The rule lives in one place: anyone who uses `Account` gets it for free. Keep the fields private to the struct when the program grows, and change them only through methods.

**Try:** add a method `bool transfer(self, Account^ to, int amount)` that withdraws from one account and deposits into another.

## Lesson 147. A generic stack: Stack<T>

A stack takes the last item put in first out (like a pile of plates). `Stack<T>` works for any type `T`: write `Stack<int>` for numbers or `Stack<String>` for text, and the compiler makes the code for each one. `init` runs when a variable of the struct is created, so the list is ready at once.

```jk
#import <stdlib>
using stdlib;

struct Stack<T> {
    T[] items;

    void init(self) {
        self.items = arr(4);
    }

    void push(self, T x) {
        self.items.push(x);
    }

    bool empty(self) {
        return self.items.len == 0;
    }

    // takes the top item off; throws when the stack is empty
    T pop(self) {
        if self.items.len == 0 { throw "the stack is empty"; }
        return self.items.pop();
    }
}

void main() {
    Stack<int> nums;
    for i in 1..4 { nums.push(i * i); }
    while !nums.empty() {
        jout << nums.pop() << " ";
    }
    jout << "\n";

    Stack<int> more;
    more.push(7);
    more.push(8);
    jout << more.pop() << " then " << more.pop() << "\n";
}
```

Output:

```
9 4 1 
8 then 7
```

`Stack<int>` in both places is the same copy of the code: the compiler makes it once and reuses it. The last value pushed comes out first. `empty()` is asked before `pop()`, because `pop` throws on an empty stack.

**Try:** make a `Stack<double>` and push two decimals.

## Lesson 148. defer: cleanup when a function fails

A function that makes a temporary file must remove it, even when something goes wrong half way. `defer` puts the removal right next to the creation, and it runs when the function ends: by `return`, or when an error (`throw`) leaves the function. The program below writes a file, fails on purpose, and the caller sees that the file was removed.

```jk
#import <stdlib>
using stdlib;

// writes a file, checks it, and removes the file on every way out
int check_file(String path, String text) {
    Fs::write_text(path, text).unwrap();
    defer Fs::remove(path);
    defer jout << "removed " << path << "\n";
    String[] lines = Fs::read_lines(path).unwrap();
    if lines.len == 0 { throw "the file is empty"; }
    return lines.len;
}

void main() {
    jout << check_file("defer_ok.txt", "a\nb\nc\n") << " lines\n";
    try {
        jout << check_file("defer_bad.txt", "") << " lines\n";
    } catch (e) {
        jout << "caught: " << e << "\n";
    }
    jout << "left behind: " << Fs::exists("defer_ok.txt") << Fs::exists("defer_bad.txt") << "\n";
}
```

Output:

```
removed defer_ok.txt
3 lines
removed defer_bad.txt
caught: the file is empty
left behind: falsefalse
```

The two `defer` lines run in the reverse order: first the message, then the removal, in both calls. The file is gone before `main` looks at it. Without `defer` the removal would be the last line of the function, and the `throw` would skip it.

**Try:** move the `defer` lines below the `throw` and see that the program now removes nothing when it fails.

## Lesson 149. A build file of makej, read as text

**makej** builds a project from a build file, a plain text file named `makej` (lesson 57). It has sections in square brackets: `[program.NAME]` for a program with its `main` file, `[step.NAME]` for a shell command with `needs` (what must be built first). The file is only text, so a program can read it like any other file. The program below writes a small build file, reads it line by line, lists its sections, and removes it.

```jk
#import <stdlib>
using stdlib;

void main() {
    String path = "makej_demo";
    String build = "[makej]\nout = \"_out\"\n\n[program.hello]\nmain = \"src/hello.jk\"\n\n[step.run]\nneeds = \"hello\"\nrun = \"_out/hello\"\n";
    Fs::write_text(path, build).unwrap();

    String[] lines = Fs::read_lines(path).unwrap();
    int targets = 0;
    int settings = 0;
    for i in 0..lines.len {
        String line = lines[i];
        if line.len > 0 && line[0] == '[' {
            targets += 1;
            jout << "target " << line << "\n";
        } else if line.len > 0 && line[0] != '#' {
            settings += 1;
        }
    }
    jout << targets << " sections, " << settings << " settings\n";
    Fs::remove(path);
}
```

Output:

```
target [makej]
target [program.hello]
target [step.run]
3 sections, 4 settings
```

The real `makej` reads this file itself. A line that starts with `#` is a comment, and a section name shows what kind of target it is. Run `makej init` in a folder to make a start, and `makej -v` to see the commands it runs (lesson 57). The program above only shows that the file is plain text, and it could check the same things that makej checks.

```jk-no
[makej]
out = "_out"

[program.hello]
main = "src/hello.jk"
```

**Try:** print only the `main = ...` lines and the name of the section above each one.

## Lesson 150. Reading a compiler error

When the compiler finds a problem it prints the place and the reason in one line: `file:line:col: error: message`, then the source line with a `^` under the spot. Read the first line first: the file, the line and the column tell you where to look. The message names the problem in words. The program below compiles; the message format is shown after it, from a real error.

```jk
#import <stdlib>
using stdlib;

// this program compiles; the message format is shown after it
int average(int[] values) {
    int total = 0;
    for i in 0..values.len { total += values[i]; }
    if values.len == 0 { return 0; }
    return total / values.len;
}

void main() {
    int[] marks = arr(3);
    marks.push(70);
    marks.push(85);
    marks.push(91);
    jout << "average " << average(marks) << "\n";
}
```

Output:

```
average 82
```

Suppose the `}` at the end of the `for` line in `average` is missing. This is the real output of the compiler for that one change:

```jk-no
ec_read_errors.jk:12:6: error: a variable cannot be void
 12 | void main() {
    |      ^
  help: void is only for functions that give no value; use int, double, ... for a variable
ec_read_errors.jk:19:1: error: the file ends inside a block: the '{' on line 5 is never closed
  help: a '}' is missing; check the braces that follow that line
```

Read it in this order: (1) the file and the place, `12:6` is line 12, column 6; (2) the message, which says what is wrong; (3) the source line with the `^`, and the `help` line, which often says the fix. The first message points at `main`, but the cause is the `{` of `average` on line 5, which is never closed. So the message at the place where the compiler notices a problem is not always where the mistake is: read the `help` lines and the last message too. Fix one error, compile again, and the rest may disappear.

**Try:** delete the `}` at the end of the `for` line in `average`, compile, and check that the message names the line of the function.

## Where next

* [LIBRARIES.md](LIBRARIES.md) — how to use each part of the standard library, by category.
* [LANGUAGE.md](LANGUAGE.md) — every feature with examples (function pointers, unsigned types, `sizeof`, ...).
* [USAGE.md](USAGE.md) — the compiler's options (`-d`, `-st`, `-I`, `--emit-asm`).
* `examples/` in the repository — more small programs.
