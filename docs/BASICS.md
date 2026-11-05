# J2K basics

A beginner series in ten short chapters, numbered 0 to 9. You do not need to know
programming. Each chapter has one idea, a small program, what it prints, a **Try**
and a **If it does not work** line. Type the programs yourself: that is how you learn.

Read it on a phone, in Termux or in the Jaric app. The Thai version is
[BASICS.th.md](BASICS.th.md).

---

## 0. Install and run your first file

On Termux, install the compiler with one command (from the README):

```console
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
```

With `wget` instead: `wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`.
If one of them is missing, run `pkg install curl wget` first. On Termux the compiler goes to
`$PREFIX/bin`, which is already on your path. Check it with `jcmp -version`.

In the Jaric app, the files only say that the compiler is installed with `jc install jcmp`
(in the list of tools). They do not describe more steps for the app.

Save this as `hello.jk`:

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
}
```

Compile it and run it:

```console
jcmp hello.jk -o hello
./hello
```

Output:

```text
Hello, J2K!
```

**Try:** change the text between the quotes and compile again.

**If it does not work:** `jcmp: command not found` means the compiler is not on your path. Call it by
its folder instead, for example `../bin/jcmp hello.jk -o hello`.

---

## 1. `main` and `jout`

Every program starts at `main`. The lines between its braces `{ }` run from top to bottom.
`jout <<` prints what follows it. Text goes in double quotes, `\n` starts a new line, and a
number is printed as it is. Put several things in one line with more `<<`. Each line ends with `;`.
The first two lines (`#import` and `using`) give you `jout`: keep them at the top.

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
    jout << "Next line\n";
    jout << "A number: " << 42 << "\n";
    jout << "Two numbers: " << 3 << " and " << 4 << "\n";
    jout << 10 + 5 * 2 << "\n";
}
```

Output:

```text
Hello, J2K!
Next line
A number: 42
Two numbers: 3 and 4
20
```

**Try:** print your name on one line and your age on the next.

**If it does not work:** a line without its `;` gives this error (file `broken.jk`):

```text
broken.jk:5:26: error: expected ';' at the end of line 5: the statement is not finished
 5 |     jout << "Next line\n"
   |                          ^
1 error generated.
```

---

## 2. Variables

A variable is a named box that holds one value. Its type says what kind of value it holds:
`int` is a whole number, `double` a decimal number, `bool` is `true` or `false`,
`char` is one character (in single quotes), and `String` is text (in double quotes).
You declare a variable with its type, give it a value, and change the value later with `=`.

```jk
#import <stdlib>
using stdlib;

void main() {
    int apples = 5;
    apples = apples + 2;
    double price = 2.5;
    bool sunny = true;
    char letter = 'J';
    String name = "Ann";
    jout << apples << "\n";
    jout << price << "\n";
    jout << sunny << "\n";
    jout << letter << "\n";
    jout << name << "\n";
}
```

Output:

```text
7
2.500000
true
J
Ann
```

**Try:** make `price` 4.0 and print it. Then store your own name in `name`.

**If it does not work:** a text stored in an `int` (file `broken.jk`) gives two messages. The second
is only a result of the first:

```text
broken.jk:5:24: error: a text cannot be stored in an int
 5 |     int apples = "five";
   |                        ^
  help: declare the variable as char^ or String
broken.jk:6:20: error: unknown name 'apples'
 6 |     jout << apples << "\n";
   |                    ^
2 errors generated.
```

---

## 3. Calculating and comparing

`+ - * /` and `%` (remainder) work as usual; `*` and `/` come first, `( )` changes the order.
`7 / 2` is `3` (whole numbers), `7.0 / 2.0` is `3.5`. A comparison (`== != < > <= >=`) gives a `bool`;
`&&` is "and", `||` is "or", `!` flips a `bool`.

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 7;
    int b = 2;
    jout << a / b << "\n";
    jout << 7.0 / 2.0 << "\n";
    jout << a % b << "\n";
    jout << 2 + 3 * 4 << "\n";
    jout << (2 + 3) * 4 << "\n";
    jout << (a == 7) << "\n";
    jout << (a >= 3 && b < 1) << "\n";
    jout << (a >= 3 || b < 1) << "\n";
    jout << !(a == 7) << "\n";
}
```

Output:

```text
3
3.500000
1
14
20
true
false
true
false
```

**If it does not work:** a `bool` needs a true or false value, so `bool ok = 5;` (file `broken.jk`)
gives:

```text
broken.jk:5:16: error: type mismatch: expected bool, got a number (use a comparison for a bool, or a cast)
 5 |     bool ok = 5;
   |                ^
broken.jk:6:16: error: unknown name 'ok'
 6 |     jout << ok << "\n";
   |                ^
2 errors generated.
```

---

## 4. `if`, `else` and nested conditions

`if` runs its block only when the condition is `true`. `else if` tries another condition
and `else` runs when nothing above was true. The braces `{ }` are always needed.
Conditions are the `bool` results from chapter 3, and you can put an `if` inside another `if`.

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

    if score >= 50 {
        if score >= 70 { jout << "good pass\n"; }
    }
}
```

Output:

```text
B
passed
good pass
```

**Try:** change `score` to 95 and then to 40, and predict the output each time.

**If it does not work:** the condition must be a `bool`, not a number. With `int n = 3;` and
`if n {` (file `broken.jk`) the compiler says:

```text
broken.jk:6:10: error: a bool is required here
 6 |     if n {
   |          ^
  help: write a comparison, e.g. x != 0
1 error generated.
```

---

## 5. Loops

A `while` loop repeats while its condition is `true`. `for i in a..b` counts `i` from `a` up to
`b - 1`. Inside a loop, `break` leaves it early and `continue` skips to the next round. A loop can
be inside another loop.

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

    int sum = 0;
    for k in 1..11 { sum += k; }
    jout << "sum 1..10 = " << sum << "\n";

    for r in 1..4 {
        for c in 1..4 { jout << r * c << "\t"; }
        jout << "\n";
    }
}
```

Output (the table is separated by tabs):

```text
1 2 3 
sum 1..10 = 55
1	2	3	
2	4	6	
3	6	9	
```

**Try:** print the multiplication table of 7 with `for`.

**If it does not work:** a `while` line needs `{` after its condition. With the braces missing
(file `broken.jk`) the compiler says:

```text
broken.jk:7:9: error: expected '{', but found 'cout'
 7 |         jout << i << " ";
   |         ^
broken.jk:10:1: error: a type was expected, but found '}'
 10 | }
    | ^
  help: a type is int, char, bool, double, float, String, a struct name, or one of these followed by ^ or []
2 errors generated.
```

---

## 6. Input: `jin`

`jin >>` reads from the keyboard. Words are separated by spaces or new lines, and the type of the
variable decides what is read: a number for `int`, a word for a `char` array. You can also
type the input into the program with a pipe: `echo "..." | ./name`.

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

Run it with input from a pipe:

```console
jcmp input.jk -o input
echo "Ann 30" | ./input
```

Output:

```text
Ann will be 31 next year
```

When the input runs out before the number, the program stops with an error:

```console
echo "Ann" | ./input
```

```text
uncaught exception: end of input: a whole number was expected, but the input has ended
```

**Try:** run `echo "Bob 41" | ./input`.

**If it does not work:** a word where a number is expected stops the program with this message
(`echo "Ann thirty" | ./broken`):

```text
uncaught exception: invalid input: a whole number was expected, but found 't'
```

---

## 7. Functions

A function has a result type, a name and parameters in brackets. `void` means it gives no result.
`return` gives the result back to the caller. A function can call another function, and it can
call itself (recursion), as long as it stops somewhere. A function can be written below
the place that uses it.

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << factorial(5) << "\n";
    banner();
}

int factorial(int n) {
    if n <= 1 { return 1; }
    return n * factorial(n - 1);
}

void print_box(int n) {
    for i in 0..n { jout << "*"; }
    jout << "\n";
}

void banner() {
    print_box(3);
    jout << "ready\n";
}
```

Output:

```text
120
***
ready
```

**Try:** write `int square(int x) { return x * x; }` and print `square(7)`.

**If it does not work:** the argument must have the type of the parameter. Passing a text to an
`int` parameter (file `broken.jk`) gives:

```text
broken.jk:9:22: error: argument 1 of 'twice': a text was given, but the parameter is a number
 9 |     jout << twice("a") << "\n";
   |                      ^
  help: declare the parameter as char^ or String, or give a number
1 error generated.
```

---

## 8. Arrays

An array is many values of one type in one variable. `int scores[5];` makes room for five
numbers, counted from 0: `scores[0]` is the first one. `scores.len` is the length. A
dynamic array `int[] list = arr(4);` starts empty and grows with `push`: `list.push(v)` adds at the end.
Loop over an array with `for i in 0..scores.len`.

```jk
#import <stdlib>
using stdlib;

void main() {
    int scores[5];
    for i in 0..5 { scores[i] = (i + 1) * 10; }
    int total = 0;
    for i in 0..scores.len { total += scores[i]; }
    jout << "total " << total << "\n";

    int best = scores[0];
    for i in 1..scores.len {
        if scores[i] > best { best = scores[i]; }
    }
    jout << "max " << best << "\n";

    int[] list = arr(4);
    for i in 1..4 { list.push(i * i); }
    jout << list.len << " " << list[2] << "\n";
}
```

Output:

```text
total 150
max 50
3 9
```

**Try:** add `scores[2] = 99;` before the loops and predict the total.

**The bounds rule:** the index must be from `0` to `len - 1`. Build with `-d` to check
it while the program runs. With `int small[3];` and an index of 5 that is read only at run time
(file `broken.jk`):

```console
jcmp broken.jk -d -o broken
./broken
```

```text
runtime error: index out of bounds, array size is 3
```

The program stops with exit code 134. Without `-d` the check is not made, so always test with `-d`
while you learn.

---

## 9. Strings

A `String` is text that can grow. Join texts with `+`. `title.len` is the number of characters,
`title[0]` is the first one, and `==` compares two texts. `"{n}"` puts the value of `n` into a text.
`to_int()` turns a `String` into an `int`. Methods work on a variable (`s.to_int()`) and also on a text
written in the program (`"42".to_int()` is 42).

```jk
#import <stdlib>
using stdlib;

void main() {
    String first = "J2K";
    String title = first + " basics";
    jout << title << " " << title.len << " " << title[0] << "\n";
    if first == "J2K" { jout << "same\n"; }

    String text = "42";
    int n = text.to_int();
    jout << "{n} plus one is {n + 1}\n";
}
```

Output:

```text
J2K basics 10 J
same
42 plus one is 43
```

**Try:** make `text` be `"7"` and print `n * 6`.

**If it does not work:** a text that is not a number stops the program (file `broken.jk`):

```text
uncaught exception: not a number
```

To keep going after a bad text, use `try` and `catch` (see [LANGUAGE.md](LANGUAGE.md)).

---

## Reading a compiler message

Every message has the form `file:line:column: error: what is wrong`. The next lines show the
line and a `^` under the place. A `help:` line tells you what to try. The first message is the one
that matters: fix it and compile again, because the later ones are often a result of it.

## Where next

* [docs/TUTORIAL.md](TUTORIAL.md): the step-by-step tutorial, with more lessons and exercises.
* [docs/COOKBOOK.md](COOKBOOK.md): short recipes for common tasks.
* [docs/LANGUAGE.md](LANGUAGE.md): the full reference of the language.
