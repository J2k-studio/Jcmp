# Jcmp (english)

## What jcmp does
**What it is.** jcmp is the compiler of J2K. It reads a source file that ends in .jk, checks every line, and writes a program that the computer can run. If the check fails, it prints a message with the file, the line and the column, and it writes no program.
**Why it matters.** Every J2K program goes through jcmp. You will use it each time you change a line, so it is worth knowing what it does with your file and what its messages mean.
**How to do it.**

Write the file, then compile it with the name of the output after -o, and run the output. The steps are: write hello.jk, run jcmp hello.jk -o hello, then run ./hello. The example below is the whole program.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "compiled and running\n";
}
```

```
compiled and running
```

> **Watch out:** Running the old program after a failed compile is a common mistake. If jcmp shows an error, no new program was written, so the old file still runs and hides the problem.
**Exercises**
- What does jcmp do with the source file hello.jk?
  - a) It runs the program in the file  b) It checks the file and writes a program  c) It deletes the file  — Answer: b. jcmp checks every line, then writes a program. Running is a separate step.
- Which option gives the output program the name hello?
  - a) -name hello  b) -o hello  c) -out=hello  — Answer: b. The option -o names the output file. Without it the name depends on the source name.
- If jcmp finds an error, it still writes a new program file. — Answer: f. With an error no new program is written, so an old file of that name may still exist.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "a" << "\n";
jout << "b";
}
```
  Output: `a / b`. Each jout prints its text. The first ends with a new line, and the second prints b with no new line after it.
- The option that names the output file is -___. — Answer: **o**. jcmp hello.jk -o hello writes the program called hello.
- Make and run a first program: write hello.jk → run jcmp hello.jk -o hello → run ./hello → read the printed result. The file must exist first, and the compile must succeed before you run it.
**Tasks**
- **Two words** — Write a program that prints hello and then world, each on its own line. Output: `hello / world`. Hint: Use one jout for each word, and end each one with \n.

## Programs and components
**What it is.** J2K has two kinds of file. A file that ends in .jk is a program, and it must have a main function, which is where the program starts. A file that ends in .j is a component. Other files import it with #import. A component may not have main.
**Why it matters.** A large project is split into many files. Components hold the code that many programs share, and programs hold main. Knowing which is which stops the compiler message that says main is missing.
**How to do it.**

Put main in a .jk file. Put shared functions in a .j file and import them where you need them. The example is a complete program that only uses the library.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "main is the start\n";
}
```

```
main is the start
```

> **Watch out:** Putting main in a .j file is a mistake. Rename the file to .jk, or move main to a program file that imports the component.
**Exercises**
- Which file must contain main?
  - a) a .j file  b) a .jk file  c) a file with no name  — Answer: b. A program is a .jk file. Components (.j) cannot define main.
- Which line brings a library into a file?
  - a) using stdlib;  b) #import <stdlib>  c) jout << x;  — Answer: b. #import loads the library. using stdlib makes its names usable without the prefix.
- A component (.j file) is a program that runs by itself. — Answer: f. A component is imported by other files and does not run by itself.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "start\n";
}
```
  Output: `start`. The program starts in main and prints the text once.
- The file name ending for a program is .___. — Answer: **jk**. A program ends in .jk and a component ends in .j.
- Split code into two files: write shared functions in a .j file → put main in a .jk file → import the .j file in the .jk file → compile the .jk file. The component is written first, so the program can import it.
**Tasks**
- **Start message** — Write a program that prints the words main runs first. Output: `main runs first`. Hint: Use jout with the text and end it with \n.

## Integer types: int, i32, i8
**What it is.** An integer type stores a whole number. int is 64 bits. i32 is 32 bits and i8 is 8 bits. All of them are signed, so they can hold negative values. The size tells you the largest value the type can keep.
**Why it matters.** A number that is too big for its type is cut to fit. The result is not what you expect, and the bug is hard to see. Knowing the size prevents it.
**How to do it.**

Choose the type by the size of the value. When you store a value in a small type, the value is cut to that size. Addition is done at full width, but the value is cut when it is stored. The example shows this with i8.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    i8 a = 100;
    i8 b = 100;
    int sum = a + b;
    i8 small = a + b;
    jout << sum << "\n";
    jout << small << "\n";
}
```

```
200
-56
```

> **Watch out:** The result of i8 + i8 is an int during the addition. The cut only happens when the sum is stored in an i8. Store it in an int when you need the full value.
**Exercises**
- What is the size of an int in J2K?
  - a) 8 bits  b) 32 bits  c) 64 bits  — Answer: c. int is 64 bits. i32 is 32 bits and i8 is 8 bits.
- i8 can hold up to 127. What happens when 200 is stored in an i8?
  - a) The value is cut to fit  b) The compiler stops  c) The value stays 200  — Answer: a. The value is cut to 8 bits when stored, so it does not stay 200.
- An i8 can hold negative numbers. — Answer: t. All the signed types hold negative values as well as positive ones.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
i8 x = 127;
int y = x + 1;
jout << y << "\n";
}
```
  Output: `128`. The addition is done at full width, so 127 plus 1 is 128 in an int.
- The type that is 64 bits and signed is ___. — Answer: **int**. int is the normal whole number type of J2K.
- Store a big number in an i8: write the number → store it in an i8 → the value is cut to 8 bits → read the value that was kept. The cut happens when the value is stored, so the store is the step that changes it.
**Tasks**
- **Small store** — Write a program that stores 200 in an i8 and prints it. Output: `-56`. Hint: 200 is cut to 8 bits. Think of the 8-bit range: from -128 to 127.

## Unsigned types: u8, u32, u64
**What it is.** An unsigned type stores only zero and positive numbers. u8 is 8 bits, u32 is 32 bits and u64 is 64 bits. Because there is no sign, the same bits hold a bigger positive value. A u8 can hold 0 to 255.
**Why it matters.** Bytes, hashes and bit masks are often unsigned. If you mix a signed and an unsigned value, the compiler asks you for a cast, so the sign is never mixed by accident.
**How to do it.**

Use an unsigned type when the value can never be negative. Compare, divide and shift it as an unsigned number. Cast between signed and unsigned with (u32)n or (int)x when you mean it. The example adds to a u8 and shows the cut.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    u8 b = 250;
    b += 10;
    jout << b << "\n";
}
```

```
4
```

> **Watch out:** -1 does not fit an unsigned type. A negative number needs a cast, or it is an error. The cast does not make the value different in the bits; it only changes how the bits are read.
**Exercises**
- What is the largest value a u8 can hold?
  - a) 127  b) 255  c) 256  — Answer: b. u8 is 8 bits and unsigned, so it holds 0 to 255.
- Why does the compiler stop when you mix an int and a u32 in one sum?
  - a) Because the names are too long  b) Because the signs do not match and a cast is needed  c) Because u32 is slow  — Answer: b. Mixing a signed and an unsigned value needs a cast, so the intention is clear.
- b += 10 on a u8 holding 250 gives 260 in the variable. — Answer: f. 260 is cut to 8 bits when stored, so the variable holds 4.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
u8 b = 255;
b += 1;
jout << b << "\n";
}
```
  Output: `0`. 255 plus 1 is 256, and the cut to 8 bits leaves 0.
- An unsigned type is written with the letter u, for example u___. — Answer: **8**. u8 holds the numbers from 0 to 255.
- Add to an unsigned value: declare the u8 with a value → add with += → the result is cut to 8 bits when stored → print the value. The cut is part of the store, so it happens at the last step.
**Tasks**
- **Wrap value** — Write a program with u8 b = 250, add 10 to b, and print the word wrap and then b. Output: `wrap 4`. Hint: Use b += 10 and then jout with the text, a space and b.

## Floating point: float and double
**What it is.** A floating point number has a decimal part, such as 2.5. float is the 32-bit kind and double is the 64-bit kind. A double keeps more digits. int and float do not mix in one expression without a cast, so you convert the value yourself.
**Why it matters.** Money, measures and averages need decimals. Choosing double gives more digits. Dividing two ints gives a whole number, so one of them must be a double.
**How to do it.**

Write a decimal number like 2.5 and it becomes a double. To divide two int values as decimals, cast one of them with (double). The example casts n before the division, so the result has a decimal part.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 7;
    double half = (double)n / 2.0;
    jout << half << "\n";
}
```

```
3.500000
```

> **Watch out:** 7 / 2 with two int values gives 3, not 3.5. The decimal part is lost when both sides are whole numbers.
**Exercises**
- What is the difference between float and double?
  - a) float is 64 bits and double is 32 bits  b) float is 32 bits and double is 64 bits  c) There is no difference  — Answer: b. float is the 32-bit kind and double the 64-bit kind, which keeps more digits.
- Why does 7 / 2 with two int values give 3?
  - a) Because 7 is odd  b) Because integer division drops the decimal part  c) Because the compiler is wrong  — Answer: b. Integer division keeps only the whole part of the answer.
- A double and an int can be added together without any cast. — Answer: f. int and float do not mix in one expression without a cast. Cast one side with (double).
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 5;
jout << (double)a / 2.0 << "\n";
}
```
  Output: `2.500000`. The cast makes a double, so 5 divided by 2 is 2.5.
- To turn an int into a double, write (___)n. — Answer: **double**. (double)n gives the value as a decimal number before the division.
- Divide and print a decimal: write the int values → cast one of them to double → divide → print the result. The cast comes before the division, not after it.
**Tasks**
- **Average** — Write a program that makes an int total = 9 and an int count = 2, and prints the word avg and the average as a double. Output: `avg 4.500000`. Hint: Use (double)total / (double)count inside jout.

## Casts: changing a type on purpose
**What it is.** A cast changes the type of a value with brackets, such as (int)x or (double)n. You write it when you want the change and the compiler would otherwise say no. A cast tells the compiler that you know what you are doing.
**Why it matters.** Without casts, mixing types is an error. With casts you say clearly where a change happens, so a reader sees the change and can check it.
**How to do it.**

Put the type in brackets before the value. The cast applies to the value right after it, so (double)n / 2.0 casts n first and then divides. The example shows a cast from a float to an int, which cuts the decimal part.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    double x = 3.9;
    int whole = (int)x;
    jout << whole << "\n";
}
```

```
3
```

> **Watch out:** (int)3.9 is 3, not 4. A cast to int drops the decimal part; it does not round.
**Exercises**
- What is the value of (int)3.9?
  - a) 4  b) 3  c) 3.9  — Answer: b. The cast to int drops the decimal part. It does not round.
- In (double)n / 2.0 which part is done first?
  - a) The division  b) The cast of n  c) The printing  — Answer: b. The cast binds to n, so n becomes a double before the division.
- A cast is needed to mix a signed and an unsigned value in one expression. — Answer: t. Mixing signed and unsigned values is an error until one side is cast.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = -1;
u32 back = (u32)n;
jout << back << "\n";
}
```
  Output: `4294967295`. The cast reads the same 32 bits as an unsigned value, which is the largest u32 minus 0.
- A cast to an int is written with the word ___ in brackets. — Answer: **int**. (int)x changes x to an int, and the decimal part is dropped.
- Cast a value and print it: write the value with its type → put the new type in brackets before it → use the cast value in the expression → print the result. The cast is written next to the value it changes.
**Tasks**
- **Cast down** — Write a program with double d = 8.8 and print the whole part with a cast to int, with the word whole before it. Output: `whole 8`. Hint: Use (int)d inside jout.

## Strings and the new line
**What it is.** A string is text in double quotes, such as "hi". A new line in a string is written as \n, a backslash and the letter n. The word nl does the same without the backslash. A slash followed by n, written /n, is not a new line. It is a slash and the letter n, and the compiler warns you.
**Why it matters.** Output with the wrong new line looks broken. The warning about /n tells you about a typing mistake that is easy to miss.
**How to do it.**

Write \n at the end of a line of text, or write nl after a value. The example shows both ways in one program.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "first\n";
    jout << "second" << nl;
}
```

```
first
second
```

> **Watch out:** If you type /n instead of \n, the compiler warns that it is a slash and the letter n. The line is printed with /n in it, and no new line is made.
**Exercises**
- Which code makes a new line in a string?
  - a) "/n"  b) "\n"  c) "new line"  — Answer: b. \n is a backslash and n, and it makes a new line. /n is a slash and n, which is not a new line.
- What does nl do in jout << x << nl;
  - a) It prints the word nl  b) It makes a new line  c) It stops the program  — Answer: b. nl needs no backslash. It prints the new line after the value.
- A single value in jout << x; gets its new line by itself. — Answer: t. jout prints one value with a new line at the end, so you do not need \n for a single value.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "a" << nl;
jout << "b" << "\n";
}
```
  Output: `a / b`. Each line ends with a new line. nl and \n both make one.
- The word that makes a new line without a backslash is ___. — Answer: **nl**. jout << x << nl; prints x and then goes to a new line.
- Print two lines of text: write the first jout with the text and \n → write the second jout with the text → compile → run and read the lines. Each jout is one line of output in the order it is written.
**Tasks**
- **Two lines** — Write a program that prints one, goes to a new line, and then prints two using nl. Output: `one / two`. Hint: Use jout << "one" << nl; and then jout << "two" << nl;.

## Reading a compiler error
**What it is.** A compiler error has the form file:line:col: error: message. The file is the name of the source file, line and col are the place, and the message says what is wrong. The message is the reason, and the place tells you where to look.
**Why it matters.** Errors are the most common thing you read. The compiler always gives the place, so the fastest way to fix a program is to go to that place and read the message word by word.
**How to do it.**

Go to the line first. Read the message and find the word that names the problem, such as unknown name or type. Change one thing, then compile again. Do not change many things at once, or you will not know which change helped.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int count = 3;
    jout << count << "\n";
}
```

```
3
```

> **Watch out:** Do not fix the second error first. One early error often causes the messages that come after it. Fix the first message and compile again.
**Exercises**
- In main.jk:4:9: error: unknown name, what is the place of the problem?
  - a) file main.jk, line 4, column 9  b) line 9  c) the word error  — Answer: a. The place is file:line:col, so the problem is at line 4, column 9 of main.jk.
- Which error should you fix first when there are many?
  - a) The last one  b) The first one  c) A random one  — Answer: b. The first error often causes the later ones, so fix it and compile again.
- A warning in the message means the program was not made. — Answer: f. A warning does not stop the build. It says that something may be wrong.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int count = 3;
jout << count << "\n";
}
```
  Output: `3`. count holds 3, and jout prints it with a new line.
- The message format is file, then line, then ___ separated by colons. — Answer: **column**. file:line:col is the place of the message.
- Fix a compile error: read the first message → go to the place it names → change one thing → compile again. One change at a time shows which change fixed the problem.
**Tasks**
- **Fix the print** — Write a program that prints the number 10 with a new line. Output: `10`. Hint: Use jout << 10 << "\n"; in main.

## bool and if: bool is not a number
**What it is.** bool is the type of a yes or no value. Its two values are true and false, and it takes one byte. An if statement needs a bool. A number is not a bool, so if n is an error when n is an int. You write if n != 0 to ask the question.
**Why it matters.** Many languages let you write if n and treat any number as yes. J2K asks you to write the question, so the reader sees the condition at once.
**How to do it.**

Store the answer of a comparison in a bool, or write the comparison directly after if. The example stores a comparison in a bool and then uses if with it. Then it checks an int against zero with != to ask the question.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    bool ok = 7 > 3;
    if ok { jout << "yes\n"; }
    int n = 0;
    if n != 0 { jout << "not zero\n"; } else { jout << "zero\n"; }
}
```

```
yes
zero
```

> **Watch out:** if n with an int n is an error. Write if n != 0 to say what you mean, because a number is not a yes or no value.
**Exercises**
- What is the size of a bool?
  - a) one bit  b) one byte  c) four bytes  — Answer: b. A bool takes one byte and holds true or false.
- Which line is correct when n is an int?
  - a) if n { ... }  b) if n != 0 { ... }  c) if (n) = 0 { ... }  — Answer: b. if needs a bool. n != 0 is a comparison that gives a bool.
- A number can be used directly as the condition of if in J2K. — Answer: f. bool is not a number. Compare the number first, so the condition is a bool.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
bool b = 2 == 2;
if b { jout << "same\n"; }
}
```
  Output: `same`. The comparison 2 == 2 is true, so the bool holds true and the if prints.
- The two values of a bool are true and ___. — Answer: **false**. A bool is a yes or no value with two values.
- Use a comparison in an if: write the comparison → put it after if or in a bool → write the block with jout → add an else for the other case. The comparison gives the bool that if needs.
**Tasks**
- **Check positive** — Write a program with int n = 4. Print the word positive if n > 0 is true, otherwise print the word no. Output: `positive`. Hint: Use if n > 0 with jout and else with another jout.

## char: one character or byte
**What it is.** char is an 8-bit unsigned type that holds one character or byte. Written in single quotes, 'A' is a char with the value 65. A char prints as the character, while u8 prints as a number. Arithmetic on a char gives an int, and storing the result in a char cuts it to 8 bits.
**Why it matters.** Text is read one character at a time. If you confuse char with u8 or with a string, a character prints as a number and the output is wrong.
**How to do it.**

Write a character in single quotes. Use char for a single character and a string for text. The example adds 1 to a char to get the next letter, then stores it in a char again.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    char letter = 'A';
    char next = letter + 1;
    jout << letter << " " << next << "\n";
}
```

```
A B
```

> **Watch out:** Double quotes make a string and single quotes make a char. 'A' and "A" are not the same type.
**Exercises**
- What does 'A' hold in J2K?
  - a) the text A  b) a char with the value 65  c) a number 1  — Answer: b. Single quotes make a char, and the code of A is 65.
- Which type prints the letter when you print its value?
  - a) u8  b) char  c) i32  — Answer: b. char prints as a character. u8 prints as a number.
- 'A' and "A" are the same type. — Answer: f. Single quotes give a char and double quotes give a string.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
char c = 'a';
jout << c << "\n";
}
```
  Output: `a`. A char prints as its character, so the letter a is printed.
- A single character in J2K is written in ___ quotes. — Answer: **single**. 'A' uses single quotes, and "A" uses double quotes for a string.
- Print the next letter: write a char with 'A' → add 1 to it → store the result in a char → print the char. The result of the addition must be stored before it can be printed as a char.
**Tasks**
- **Next letter** — Write a program with char c = 'C' and print the letter that comes after it. Output: `D`. Hint: Add 1 to c and store the result in a char, then print it.

## Integer division and the remainder %
**What it is.** Dividing two int values gives an int. The fraction is thrown away, so 17 / 5 is 3. The remainder operator % gives what is left over, so 17 % 5 is 2. Together they split a number into a whole part and a rest.
**Why it matters.** Clocks, lists of pages, and tests for even numbers all use division and remainder. A remainder of 0 means the number divides evenly.
**How to do it.**

Use / to find how many times one number fits into another, and % to find what is left. The example prints both for 17 and 5.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 17;
    jout << a / 5 << " " << a % 5 << "\n";
}
```

```
3 2
```

> **Watch out:** Division by zero is an error at run time. Check that the divisor is not zero before you divide.
**Exercises**
- What is 17 / 5 for two int values?
  - a) 3.4  b) 3  c) 4  — Answer: b. Integer division drops the fraction, so the answer is 3.
- What is 17 % 5?
  - a) 3  b) 2  c) 0  — Answer: b. The remainder of 17 divided by 5 is 2.
- A number is even when n % 2 is 0. — Answer: t. An even number divides by 2 with no remainder, so the remainder is 0.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << 10 % 4 << "\n";
}
```
  Output: `2`. 10 divided by 4 is 2 with a remainder of 2.
- The operator that gives the remainder of a division is ___. — Answer: **%**. The percent sign gives the rest after integer division.
- Split a count of pages: write the pages → divide by the page size for full pages → take the remainder for the last part → print both. Division gives the full pages, and the remainder gives the rest.
**Tasks**
- **Split time** — Write a program with int s = 135 and print the minutes as s / 60 and the seconds as s % 60, with the word min before the minutes and sec before the seconds. Output: `min 2 sec 15`. Hint: Use jout with the words, the values and spaces.

## Bit operators: & | xor << >>
**What it is.** Bit operators work on the bits of a whole number. & keeps the bits that both sides have. | puts a bit in when either side has it. xor, written as a word, flips a bit where the two sides differ. << moves bits to the left, which multiplies by two for each step. >> moves them to the right, which divides by two.
**Why it matters.** Flags, masks, colours and fast arithmetic all use these bits. Writing xor as a word is a J2K rule, because the sign for pointers is ^.
**How to do it.**

Write the operator between two values. The example uses 6 and shows each operator. 6 is 110 in binary, so 6 and 3 is 010, which is 2.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 6;
    jout << (x & 3) << " " << (x | 1) << " " << (x xor 5) << " " << (x << 2) << " " << (x >> 1) << "\n";
}
```

```
2 7 3 24 3
```

> **Watch out:** Bit operators bind tighter than comparisons, so a & 1 == 0 means (a & 1) == 0. Add brackets when you are unsure.
**Exercises**
- What is 6 & 3?
  - a) 7  b) 2  c) 3  — Answer: b. 110 and 011 share only the bit of value 2, so the answer is 2.
- What does x << 1 do to a whole number?
  - a) It divides by two  b) It multiplies by two  c) It adds one  — Answer: b. Moving bits one step to the left doubles the number.
- xor is written with the sign ^ in J2K. — Answer: f. ^ means pointer in J2K, so xor is written as a word.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int y = 8;
jout << (y >> 2) << "\n";
}
```
  Output: `2`. Moving the bits of 8 two places to the right gives 2.
- The word that flips the bits where two values differ is ___. — Answer: **xor**. xor flips a bit where the two sides are different.
- Mask the low two bits: write the value → write & 3 to keep the low two bits → read the result → print it. The mask keeps only the bits that the number 3 has set.
**Tasks**
- **Double bits** — Write a program with int v = 5 and print v shifted left by 1 with the word shifted before it. Output: `shifted 10`. Hint: Use (v << 1) inside jout.

## Arrays: size and index
**What it is.** An array holds a fixed number of values of one type. You declare it with a size, such as int sizes[4], and each value has an index from 0 to size minus 1. sizes.len gives the size, so a loop can walk the whole array.
**Why it matters.** Lists of numbers, scores and pixels are arrays. Reading an index outside the range is a bug, and the checks in a debug build show it.
**How to do it.**

Declare the array with its size and optional values in braces. Use a for loop with the index from 0 to sizes.len to read each value. The example adds all the values and prints the last one.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int sizes[4] = {2, 4, 6, 8};
    int sum = 0;
    for i in 0..sizes.len { sum += sizes[i]; }
    jout << "sum " << sum << " last " << sizes[3] << "\n";
}
```

```
sum 20 last 8
```

> **Watch out:** The range 0..sizes.len stops before the length, so the last index is sizes.len minus 1. An index equal to the length is out of range.
**Exercises**
- How many values does int sizes[4] hold?
  - a) 3  b) 4  c) 5  — Answer: b. The size in brackets is the count of values, here 4.
- What is the index of the last value in int a[4]?
  - a) 4  b) 3  c) 1  — Answer: b. The indexes run from 0 to 3, so the last one is 3.
- The index 4 is valid in an array of size 4. — Answer: f. With size 4 the valid indexes are 0, 1, 2 and 3.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a[3] = {1, 2, 3};
jout << a.len << "\n";
}
```
  Output: `3`. a.len gives the size of the array, which is 3.
- The field that gives the size of an array is ___. — Answer: **len**. sizes.len gives the number of values in the array.
- Sum an array: declare the array with values → set the sum to 0 → loop over the indexes → add each value to the sum. The sum must start at zero before the loop adds to it.
**Tasks**
- **Array sum** — Write a program with int a[3] = {4, 5, 6} and print the word total followed by the sum of its values. Output: `total 15`. Hint: Use a for loop with a.len, or add the three indexes in jout.

## struct: a group of values with a method
**What it is.** A struct groups several values under one name, such as x and y. A method is a function inside the struct that gets the value as self. You call it with the dot, p.sum(). A struct value is written with braces in the order of its fields.
**Why it matters.** A point, a rectangle or a player is more than one number. A struct keeps the parts together, so the parts are passed around as one value.
**How to do it.**

Declare the fields with their types. Write methods that read self.x and self.y. Create a value with braces, then call the method with the dot. The example has one struct with a method that adds the two fields.
**Example.**

```jk
#import <stdlib>
using stdlib;

struct Point {
    int x;
    int y;

    int sum(self) {
        return self.x + self.y;
    }
}

void main() {
    Point p = {3, 4};
    jout << p.sum() << "\n";
}
```

```
7
```

> **Watch out:** A method that changes a field must take self as the first parameter, or it cannot change the value it belongs to.
**Exercises**
- What does self refer to inside a method?
  - a) the program  b) the struct value the method is called on  c) the main function  — Answer: b. self is the value the method was called on, so self.x reads its x.
- Which code creates a Point with x 1 and y 2?
  - a) Point p = {1, 2};  b) Point p = (1, 2);  c) p = Point;  — Answer: a. A struct value is given in braces, in the order of the fields.
- A struct groups values that belong together under one name. — Answer: t. A struct is a group of named fields, such as x and y, kept as one value.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

struct Box {
int w;
int h;
int area(self) {
    return self.w * self.h;
}
}

void main() {
Box b = {2, 5};
jout << b.area() << "\n";
}
```
  Output: `10`. The method multiplies w by h, which is 2 times 5, giving 10.
- Inside a method the name for the value it is called on is ___. — Answer: **self**. self is the first parameter of a method and gives access to the fields.
- Use a struct with a method: declare the fields → write the method with self → create a value with braces → call the method with the dot. The struct must be declared before its value can be created.
**Tasks**
- **Struct area** — Write a struct Rect with int w and int h and a method that returns the area. Create Rect r = {3, 3} and print the area. Output: `9`. Hint: Copy the pattern of the Point example, with self.w * self.h in the method.

## enum class and switch
**What it is.** An enum class is a set of names, such as Red, Yellow and Green. An enum is not a number, so you cannot add two of them. switch picks a block by the value. Each case is written with the enum name, such as Light::Red. Every member should have a case, or the compiler gives a warning.
**Why it matters.** States of a traffic light, a menu or a game are better named than written as numbers. The compiler checks that the cases match the names.
**How to do it.**

Declare the enum with its names. Write a function that takes the enum and uses switch with one case for each name. The example prints a message for each light.
**Example.**

```jk
#import <stdlib>
using stdlib;

enum class Way { North, South };

void show(Way d) {
    switch d {
        Way::North: jout << "up\n";
        Way::South: jout << "down\n";
    }
}

void main() {
    show(Way::South);
}
```

```
down
```

> **Watch out:** Do not compare an enum with a number. Way::North is not 0, and the compiler refuses the mix.
**Exercises**
- Can you add two enum values in J2K?
  - a) Yes, always  b) No, enums are not numbers  c) Only in a struct  — Answer: b. An enum is a set of names and is not a number, so arithmetic is refused.
- How is a case of an enum written?
  - a) North:  b) Way::North:  c) 0:  — Answer: b. A case names the enum and the member with ::.
- A switch without a case for every enum member gives a warning. — Answer: t. The compiler warns when a member is missing, so you do not forget a state.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

enum class Light { Red, Green };

void main() {
Light l = Light::Green;
switch l {
    Light::Red: jout << "stop\n";
    Light::Green: jout << "go\n";
}
}
```
  Output: `go`. The value is Green, so the case for Green runs and prints go.
- The keyword that declares a set of names is enum ___. — Answer: **class**. enum class Way declares the set of names Way.
- Pick a block by an enum: declare the enum with its names → write switch with a case for each name → call the function with a member → read the printed line. The enum comes first, so the cases have names to match.
**Tasks**
- **Traffic** — Write an enum class Sig with Stop and Go, a function that prints stop for Stop and go for Go, and call it with Sig::Go. Output: `go`. Hint: Use one switch with a case for each name.

## Constants with #define
**What it is.** #define gives a name to a value. The compiler puts the value in place of the name before it builds the program. The name is written in capital letters by convention, such as MAX. #define is placed before the code that uses it, after the imports.
**Why it matters.** A limit or a size used in many places should have one name, so a change happens in one line and not in many.
**How to do it.**

Write #define NAME value after the imports and before main. Use the name where the value is needed. The example sums the numbers from 0 to 4, using MAX for the end of the range.
**Example.**

```jk
#import <stdlib>
using stdlib;

#define MAX 5

void main() {
    int total = 0;
    for i in 0..MAX { total += i; }
    jout << total << "\n";
}
```

```
10
```

> **Watch out:** #define is text substitution, not a variable. You cannot take its address or change it, so use int when the value must change.
**Exercises**
- What does #define MAX 5 do?
  - a) It makes a variable that can change  b) It replaces the name MAX by 5 in the text  c) It prints 5  — Answer: b. #define replaces the name by the value before the build.
- Where should #define be placed?
  - a) after main  b) before the code that uses it  c) at the end of the file  — Answer: b. The name must be defined before its use, so put it before the code.
- A #define value can be changed later in the program. — Answer: f. #define is not a variable, so the value stays the same.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

#define N 3

void main() {
jout << N * 2 << "\n";
}
```
  Output: `6`. N is replaced by 3, so the program computes 3 times 2.
- The word that starts a constant text replacement is #___. — Answer: **define**. #define gives a name to a value before the build.
- Use a limit in several places: write #define LIMIT after the imports → use LIMIT in the loops → compile → change the one line to change them all. One definition is changed in one place, and the build uses it everywhere.
**Tasks**
- **Limit** — Write a program with #define LIM 4 and print the sum of the numbers 0 to LIM minus 1. Output: `6`. Hint: Use for i in 0..LIM inside a loop with total += i.
