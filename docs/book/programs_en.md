# Programs (english)

## Install and your first file
**What it is.** Before you can write programs, you need the compiler, called jcmp. It turns your .jk text file into a program file that can run. A .jk file is a plain text file that you write yourself. You can use any text editor, but save the file as plain text.
**Why it matters.** Every later lesson uses the same loop: write a file, compile it, run it, and read the result. If this step does not work, you will only see error messages and you will not know what is wrong.
**How to do it.**

Install the compiler with the install command in the README of the project (use curl or wget, whichever you have). Then check it with jcmp -version.
Create a file named hello.jk and write the code below.
```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
} 
```
Compile it with jcmp hello.jk -o hello and run it with ./hello. If you see Hello, J2K!, it works.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
    jout << "Second line\n";
}
```

```
Hello, J2K!
Second line
```

> **Watch out:** If you type jcmp and see command not found, the compiler is not on your path yet. This does not mean your code is wrong. Use the full path to the compiler file instead.
**Exercises**
- What is a .jk file?
  - a) A plain text file with J2K code  b) A program that already runs  c) A picture of the code  — Answer: a. A .jk file is plain text that people can read. The compiler changes it into a program file.
- You must compile the .jk file again after every change before you run it. — Answer: t. A program you run is the result of the last compile. If you do not compile again, you still run the old code.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "A\n";
jout << "B\n";
}
```
  Output: `A / B`. The program runs from top to bottom. The first line prints A and goes to a new line. Then it prints B.
- The command that checks the compiler version is jcmp -___ — Answer: **version**. The option -version shows which version of the compiler you have.
- The steps of your first program: make the file hello.jk → compile it with jcmp → run the file hello → read the printed result. The file must exist before you compile it, and the compile must work before you run it.
- Why do we write #import and using at the top?
  - a) To get jout and the basic functions of the standard library  b) To make the program faster  c) To write our name  — Answer: a. The stdlib library has jout and basic functions. Without the import, the program does not know these words.
**Tasks**
- **Hello** — Write a program that prints the line Hello, learner!. Output: `Hello, learner!`. Hint: Use jout with text in double quotes, and remember \n at the end.
- **Two lines** — Write a program that prints one, goes to a new line, and then prints two. Output: `one / two`. Hint: Use one jout for each line.

## main and jout
**What it is.** main is the start function. Every program starts at main and runs its lines from top to bottom until the closing brace. jout << prints output to the screen. You can join many values with <<. Text goes in double quotes. A number is printed as it is. \n starts a new line.
**Why it matters.** Every program you see has a main. Without main, the compiler does not know where to start. Printing is the first way you see what your code does.
**How to do it.**

Write your statements inside the braces of main. Each statement ends with a semicolon ;. You can calculate inside jout without a variable first.
```jk
void main() {
    jout << "total " << 6 * 7 << "\n";
} 
```
This prints total 42.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "A number: " << 42 << "\n";
    jout << "Two numbers: " << 3 << " and " << 4 << "\n";
    jout << 10 + 5 * 2 << "\n";
}
```

```
A number: 42
Two numbers: 3 and 4
20
```

> **Watch out:** In this compiler, a line that only prints a number, like jout << n;, also ends the line after the number in our test. Do not depend on this. Write << "\n" yourself.
**Exercises**
- Where does a J2K program start?
  - a) At main  b) At the first line of the file  c) At jout  — Answer: a. Every program starts at main. Other functions run when main calls them.
- \n in jout means one space. — Answer: f. \n means a new line, not a space. For a space, write a space inside the text.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "x=" << 2 + 3 << "\n";
}
```
  Output: `x=5`. The value 2 + 3 is worked out first, then it is printed after x=.
- Every program starts at the function named ___. — Answer: **main**. main is the start point that the compiler looks for.
- Printing two lines from one program: write the statements inside main → first jout with \n → second jout with \n → run to see the result. The statements run in order from top to bottom, and each line needs its own \n.
- What happens if you forget the semicolon after a jout?
  - a) The compiler says the statement is not finished  b) Nothing  c) The program prints twice  — Answer: a. The semicolon marks the end of a statement. Without it, the compiler does not know where the statement ends.
**Tasks**
- **Sum in one line** — Write a program that prints total 42 on one line, by calculating 6 * 7 inside jout. Output: `total 42`. Hint: Join the text total and the number 6 * 7 with <<
- **Three lines** — Write a program that prints a, then b, then c, each on its own line. Output: `a / b / c`. Hint: Use three jout statements, and put \n at the end of each one

## Variables and types
**What it is.** A variable is a named box that keeps one value. You must say its type. int keeps a whole number. double keeps a decimal number. bool keeps true or false. char keeps one letter in single quotes. String keeps text in double quotes. The type tells you what the value can do.
**Why it matters.** If you keep a number in text, you cannot add it. If you keep a decimal in an int, the decimal part is lost without any warning. Choosing the right type keeps your program safe, and the compiler can check it.
**How to do it.**

Declare with the type, then the name, then the value, like int apples = 5; Change the value with = and do not write the type again. An int and a double cannot be mixed without a cast. A cast is the type in brackets, like (double)apples.
```jk
int apples = 5;
apples = apples + 2;
double price = 2.5;
String name = "Ann";
```
**Example.**

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
    jout << apples << " " << price << " " << sunny << "\n";
    jout << letter << name << "\n";
    int half = (int)(price * 2.0);
    jout << half << "\n";
}
```

```
7 2.500000 true
JAnn
5
```

> **Watch out:** Division of two int values cuts off the decimal part: 7 / 2 gives 3. To get a decimal result, use 7.0 / 2.0 and make sure both sides are the same type.
**Exercises**
- Which type is right for one letter?
  - a) char  b) String  c) bool  — Answer: a. char keeps one letter in single quotes. String keeps longer text.
- int x = 2.5; is correct code. — Answer: f. 2.5 is a decimal number, but int keeps only whole numbers. Use double, or convert the value first.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 7;
int b = 2;
jout << a / b << "\n";
}
```
  Output: `3`. Both values are int, so the division is a whole-number division. The decimal part is cut off, so the answer is 3.
- A variable that keeps a decimal number has the type ___. — Answer: **double**. double keeps decimal numbers. int keeps only whole numbers.
- Using one variable: declare the type and the name → give it a first value → change the value if you need to → use the value in jout. You must declare before you use it, and you must give a value before you read it.
- Why can you not write if total where total is an int?
  - a) The condition must be a bool  b) Because total is a number  c) It is not wrong  — Answer: a. An if needs true or false. To test a number, write a comparison such as total != 0.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
double d = 3.0;
jout << (int)d << "\n";
}
```
  Output: `3`. The cast (int) removes the decimal part of 3.0, so the result is 3.
**Tasks**
- **Division and remainder** — Store 7 and 2 in int variables and print the quotient and the remainder as 3 1. Output: `3 1`. Hint: Use / for the quotient and % for the remainder
- **Total** — Store the double price 2.5 and the quantity 4 and print the text total followed by the total price as a decimal. Output: `total 10.000000`. Hint: jout shows decimals with six digits after the point. Use a double for both values.
- **Name** — Store J2K in a String called name and print name followed by rocks. Output: `J2K rocks`. Hint: Use + to join the text and include a space in the text

## Calculate and compare
**What it is.** The math operators are + - * / and % (remainder). Multiply and divide come before add and subtract. Brackets change the order. Comparisons == != < > <= >= give a bool. Use && (and) and ! (not) to join conditions.
**Why it matters.** Most programs decide things from numbers, such as whether a price is enough or a limit is passed. If you know the order of operations and what a comparison gives back, your conditions will do what you mean.
**How to do it.**

Write the formula step by step, and use brackets when you are not sure.
```jk
int a = 7;
int b = 2;
jout << (a + b) * 3 << "\n";
jout << (a >= 3 && b < 1) << "\n";
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 7;
    int b = 2;
    jout << 2 + 3 * 4 << "\n";
    jout << (2 + 3) * 4 << "\n";
    jout << a % b << "\n";
    jout << (a >= 3 && b < 1) << "\n";
    jout << !(a == 7) << "\n";
}
```

```
14
20
1
false
false
```

> **Watch out:** Mixing many operators in one line is easy to get wrong. Use brackets. Also do not confuse = (store a value) with == (compare two values).
**Exercises**
- What is the value of 2 + 3 * 4?
  - a) 14  b) 20  c) 24  — Answer: a. Multiply comes first, so 3 * 4 is 12, then 2 is added to get 14.
- The comparison 5 > 3 gives a bool, and the value is true. — Answer: t. Comparisons always give a bool. 5 is greater than 3, so the value is true.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << 17 % 5 << "\n";
}
```
  Output: `2`. 17 divided by 5 is 3 with a remainder of 2. The % operator gives the remainder.
- The English word that matches the symbol && is ___. — Answer: **and**. && means both conditions must be true.
- Working out (2 + 3) * 4: write the formula as you think it → work out the bracket first to get 5 → multiply by 4 to get 20 → print the result. Brackets change the order, so you do the bracket first before the multiplication.
- What does ! do in front of a condition?
  - a) It flips a bool  b) It adds one  c) It stores a value  — Answer: a. ! turns true into false and false into true.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int x = 10;
jout << (x == 10) << "\n";
jout << (x != 10) << "\n";
}
```
  Output: `true / false`. == and != check equal and not equal. They give opposite answers.
**Tasks**
- **Mixed formula** — Print the result of (a + b) * 3, where a is 7 and b is 2. Output: `27`. Hint: Work out the bracket first, then multiply by 3
- **In a range** — Store 12 in n and print true if n is greater than 5 and less than 20. Output: `true`. Hint: Use && to join two comparisons
- **Divide** — Print the quotient and the remainder of 47 divided by 5, as 9 2. Output: `9 2`. Hint: Use / and % in that order

## The if statement
**What it is.** if runs its block when the condition is true. else if tries another condition when the first one is false. else runs when no condition was true. The braces are always needed. The condition must be a bool. You can put an if inside another if when you need to check more than one thing.
**Why it matters.** Almost every program chooses a path. Is the price OK? Did the user pass? Writing if the way you think is a main skill. If you put the conditions in the wrong order, the answer is wrong and the compiler does not warn you.
**How to do it.**

Write the most specific condition first, because after an else if is true, the other ones are not checked.
```jk
int score = 72;
if score >= 90 {
    jout << "A\n";
} else if score >= 70 {
    jout << "B\n";
} else {
    jout << "C\n";
}
```
**Example.**

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
    bool passed = score >= 50;
    if passed { jout << "passed\n"; }
    if score >= 50 {
        if score >= 70 { jout << "good pass\n"; }
    }
}
```

```
B
passed
good pass
```

> **Watch out:** If you write if n { with n as an int, the compiler says a bool is needed. Write if n != 0 instead. Always put braces after the if.
**Exercises**
- If score is 95, which line is printed first?
  - a) A  b) B  c) C  — Answer: a. 95 is greater than 90, so the first block runs. The other conditions are not checked.
- else must always follow an if. — Answer: f. else is optional. Use it when you need a path for the case where no other condition was true.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = -4;
if n > 0 {
    jout << "positive\n";
} else if n < 0 {
    jout << "negative\n";
} else {
    jout << "zero\n";
}
}
```
  Output: `negative`. -4 is not greater than 0, so the program checks the second condition. -4 is less than 0.
- The word for the block that runs when no other condition was true is ___. — Answer: **else**. else is the last choice, used when the earlier conditions are all false.
- Order of an if with an else if: check the if → if it is false, check the else if → if that is false too, run the else → continue after the block. The conditions are checked in order, and only one block runs.
- Why must >= 90 come before >= 70?
  - a) Because the first true block runs. In the other order, 95 would give B  b) Because numbers must be sorted  c) It does not matter  — Answer: a. If >= 70 comes first, every score from 70 up gets B.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 3;
if a > 1 {
    if a > 5 { jout << "big\n"; }
    jout << "middle\n";
}
}
```
  Output: `middle`. a is greater than 1, so the outer block runs. 3 is not greater than 5, so big is skipped and middle is printed.
**Tasks**
- **Pass or fail** — If the score 60 is at least 50, print pass. Otherwise print fail. Output: `pass`. Hint: Use if and else
- **Sign of a number** — Store -4 in n and print positive, zero or negative, depending on the value of n. Output: `negative`. Hint: Use two else if checks
- **FizzBuzz** — For the numbers 1 to 15, print the number. If it divides by 3, print Fizz. If it divides by 5, print Buzz. If it divides by both, print FizzBuzz.. Output: `1 / 2 / Fizz / 4 / Buzz / Fizz / 7 / 8 / Fizz / Buzz / 11 / Fizz / 13 / 14 / FizzBuzz`. Hint: Check for both first, then check each one

## Loops
**What it is.** A while loop repeats while its condition is true. A for i in a..b loop counts i from a up to b - 1. The C-style for puts the counter, the test and the step in one line. break leaves the loop at once. continue skips to the next turn.
**Why it matters.** Some work must be done many times, such as adding a hundred numbers, searching a list, or repeating until you get a good result. Writing each step by hand is long and easy to get wrong. Loops solve this.
**How to do it.**

Use for when you know how many turns you need. Use while when you do not know the number of turns yet.
```jk
int sum = 0;
for k in 1..11 { sum += k; }
jout << sum << "\n";
int i = 1;
while i <= 3 { i++; }
jout << i << "\n";
```
**Example.**

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

```
1 2 3 
0 1 4 9 16 
10 7 4 1
```

> **Watch out:** for i in 1..4 does not include 4. To include 4, write 1..5. A while loop whose condition never becomes false runs forever.
**Exercises**
- How many times does for i in 0..3 run?
  - a) 3  b) 4  c) 2  — Answer: a. 0..3 means 0, 1 and 2. It does not include 3, so there are three turns.
- break stops the whole program. — Answer: f. break leaves the loop that it is in. The program continues with the code after the loop.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
for i in 0..5 {
    if i == 2 { continue; }
    jout << i << "\n";
}
}
```
  Output: `0 / 1 / 3 / 4`. continue skips the print when i is 2 and goes to the next turn.
- The word that leaves a loop at once is ___. — Answer: **break**. break is used when you have found what you need and do not need more turns.
- Adding the numbers 1 to 10 with a for loop: set sum to 0 → loop with for k in 1..11 → add k to sum → print sum. sum must exist before you add to it, and the addition must be inside the loop.
- Why can a while loop never end?
  - a) Because its condition stays true  b) Because jout is slow  c) Because it needs break every time  — Answer: a. If the condition never becomes false, the loop keeps going.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 6;
int steps = 0;
while n != 1 {
    if n % 2 == 0 { n = n / 2; } else { n = n * 3 + 1; }
    steps += 1;
}
jout << steps << "\n";
}
```
  Output: `8`. 6 goes to 3, 10, 5, 16, 8, 4, 2, 1. That is eight steps.
**Tasks**
- **Sum to ten** — Use for to add 1 to 10, and print the text sum followed by the total. Output: `sum 55`. Hint: Use for k in 1..11
- **Count down** — Print 10 down to 1, going down by 3, one number on each line. Output: `10 / 7 / 4 / 1`. Hint: Use for int j = 10; j > 0; j -= 3
- **Repeat until found** — Start at 6. If the number is even, divide by 2. If it is odd, multiply by 3 and add 1. Repeat until you get 1, then print steps followed by the number of steps. Output: `steps 8`. Hint: Use while n != 1 and count each step

## Nested loops
**What it is.** A loop can be inside another loop. The inner loop runs all its turns before the outer loop moves one step. The total number of turns is the product of the turns of each loop. Nested loops are used for tables, pairs and grids.
**Why it matters.** Tables, pictures and game boards are all nested loops. When you know how many times the inner loop runs for each step of the outer loop, you can count the work and predict the time.
**How to do it.**

The outer loop uses a row counter r. The inner loop uses a column counter c. Use two different names, so the counters do not clash.
```jk
for r in 1..4 {
    for c in 1..4 {
        jout << r * c << " ";
    }
    jout << "\n";
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    for r in 1..4 {
        for c in 1..4 { jout << r * c << " "; }
        jout << "\n";
    }
    for r in 1..4 {
        for c in 1..4 {
            if c <= r { jout << "*"; }
        }
        jout << "\n";
    }
}
```

```
1 2 3 
2 4 6 
3 6 9 
*
**
***
```

> **Watch out:** Do not use the same name for the inner and outer counter. Names that clash cause errors or wrong results. Use r and c, or i and j.
**Exercises**
- If the outer loop runs 3 times and the inner loop runs 4 times, how many times in total?
  - a) 12  b) 7  c) 34  — Answer: a. 3 times 4 is 12, because each outer turn runs the full inner loop.
- The inner loop cannot stop until the outer loop ends. — Answer: t. The inner loop must finish all its turns before the outer loop moves one step. This is why nested loops take more time.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int count = 0;
for i in 0..3 {
    for j in 0..2 { count += 1; }
}
jout << count << "\n";
}
```
  Output: `6`. The outer loop runs 3 times and the inner loop runs 2 times, so the total is 6.
- A loop inside another loop is called a ___ loop. — Answer: **nested**. A nested loop is a loop inside another loop.
- Printing a table of three rows with nested loops: the outer loop chooses the row → the inner loop prints every column → print a new line after each row → the whole table is printed. The outer loop starts each row, and the inner loop prints all the columns in that row.
- If you forget \n after the inner loop, what happens?
  - a) All values are on one line  b) The program does not compile  c) The table is turned around  — Answer: a. Without a new line, the values join up on one line.
**Tasks**
- **Triangle** — Print three lines of stars. The first line has one star, the second has two, and the third has three. Output: `* / ** / ***`. Hint: Let the inner loop follow the row number
- **Count pairs** — Count the pairs (i, j) where i and j are in 1..4 and i is less than j. Print pairs 6. Output: `pairs 6`. Hint: Use an if inside the inner loop
- **Multiplication table** — Print the table of 1 to 3 with a space between the numbers, one row on each line. Output: `1 2 3 / 2 4 6 / 3 6 9`. Hint: Look at the example in this lesson, and make sure there is no space at the end of a row

## jin: reading from the keyboard
**What it is.** jin >> reads a value from the keyboard, or from a pipe. It reads one word at a time. Words are separated by spaces or new lines. The type of the variable decides what is read. An int reads a number. A char array reads text.
**Why it matters.** A program that always does the same thing is not very useful. When a program can take input from a person, it becomes flexible. But you must know that wrong input stops the program with a message.
**How to do it.**

Declare the variables with the right type, then write jin >> name >> age; in the order a person will type them.
```jk
char name[20];
int age;
```
You can test with a pipe, like echo "Ann 30" | ./program
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    char name[20];
    int age;
    jin >> name >> age;
    jout << name << " will be " << age + 1 << " next year\n";
}
input: Ann 30
```

```
Ann will be 31 next year
```

> **Watch out:** If the input ends before the number, the program stops with an end of input message. If a word is typed where a number is needed, you get an invalid input message. Always think that a person may type the wrong thing.
**Exercises**
- What decides what jin reads?
  - a) The type of the variable that gets the value  b) The order of the prints  c) The name of the program  — Answer: a. An int variable reads a number. A char array reads text.
- jin always reads a whole line, with spaces. — Answer: f. jin splits the input at spaces and new lines. To read a whole line, you need a different method.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 4;
int b = 2;
jout << "in " << a + b << "\n";
}
```
  Output: `in 6`. There is no jin here. The value a + b is 6, and it is printed after the text in.
- The command that reads values from the keyboard in J2K is ___. — Answer: **jin**. jin reads values into variables.
- Reading a name and an age from a person: declare char name[20] and int age → call jin >> name >> age → use the values in jout → compile and run. The variables must exist before jin fills them, and the value must be read before it is used.
- Why should char name have a size like 20?
  - a) To reserve room for the letters that will be read  b) To make printing faster  c) To make numbers decimal  — Answer: a. A char array has a fixed size. If the text is longer, it does not fit.
**Tasks**
- **Greeting** — Declare char name[] = "Ann" and print hi Ann. Output: `hi Ann`. Hint: Use char name[] = "Ann"; and print the text hi followed by the name
- **Number from text** — Store the text "30" in a String, convert it to a number, add 1 and print the result. Output: `31`. Hint: to_int turns the text into a number before you add

## Functions
**What it is.** A function is a named block of code. It can take parameters and can send back a value with return. The type before the name tells the type of the value sent back. void means nothing is sent back. A function can call itself (recursion) if it has a stop case. You can write a function before or after the place that calls it.
**Why it matters.** Functions remove repeated code, make code easier to read, and let you test small parts. Every big program is built from small functions.
**How to do it.**

Write the return type, the name, and the parameters, then return the value.
```jk
#import <stdlib>
using stdlib;

int square(int x) {
    return x * x;
}

void main() {
    jout << square(4) << "\n";
}
```
When you pass a value into a function, the value is copied. A change to the parameter does not change the variable outside.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << factorial(5) << "\n";
    jout << square(7) << "\n";
}

int factorial(int n) {
    if n <= 1 { return 1; }
    return n * factorial(n - 1);
}

int square(int x) {
    return x * x;
}
```

```
120
49
```

> **Watch out:** A function that must return a value but has a path with no return can give a warning or a wrong result. A recursive function with no stop case never ends.
**Exercises**
- Which type do you write for a function that returns nothing?
  - a) void  b) int  c) bool  — Answer: a. void means that there is no value sent back.
- Changing a parameter inside a function changes the caller's variable. — Answer: f. The value is copied into the function, so the caller's variable does not change. A pointer is needed for that, which you learn later.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << twice(4) << "\n";
}

int twice(int n) {
return n * 2;
}
```
  Output: `8`. The function gets 4 as n, and it returns 8 to jout.
- The word that sends a value back from a function is ___. — Answer: **return**. return sends a value back to the caller and ends the function at once.
- Calling square with the value 3: pass 3 as the parameter → calculate x * x → return 9 → the caller gets 9. The value must be passed in before the calculation can happen.
- Why does a function call itself?
  - a) To split a big problem into smaller problems of the same kind  b) To make the program slower  c) To delete variables  — Answer: a. Recursion makes the problem smaller each time until the stop case is reached.
**Tasks**
- **Square** — Write a function square and print square(7). Output: `49`. Hint: Use int square(int x) and return x * x
- **Factorial** — Write a recursive function factorial and print factorial(5). Output: `120`. Hint: The stop case is n less than or equal to 1. Return 1 then.
- **Largest of three** — Write a function max3(a, b, c) that returns the largest value, and print max3(4, 9, 2). Output: `9`. Hint: Use two if checks, or compare the values in pairs

## Arrays
**What it is.** An array keeps many values of the same type in one variable. int scores[5] has five places, counted from 0. scores.len is the length. An array that can grow is int[] list = arr(4), and you add values with push. All the values sit next to each other in memory.
**Why it matters.** Most data comes in groups, such as test scores, prices or the pixels of a picture. Arrays store these groups, and all the data structures you will learn later are built on them.
**How to do it.**

Declare the size, fill the places with a loop or one place at a time, then read them with a loop from 0 to len.
```jk
int scores[5];
for i in 0..5 { scores[i] = (i + 1) * 10; }
int total = 0;
for i in 0..scores.len { total += scores[i]; }
jout << total << "\n";
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int scores[5];
    for i in 0..5 { scores[i] = (i + 1) * 10; }
    int total = 0;
    for i in 0..scores.len { total += scores[i]; }
    jout << "total " << total << "\n";
    int grid[2][3];
    for r in 0..2 {
        for c in 0..3 { grid[r][c] = r * 3 + c; }
    }
    jout << grid[1][2] << "\n";
}
```

```
total 150
5
```

> **Watch out:** An array of five places has places 0 to 4. Writing scores[5] uses a place that does not exist. Build with -d while you learn, so the compiler checks indexes while the program runs.
**Exercises**
- How many places does int scores[5] have?
  - a) 5  b) 4  c) 6  — Answer: a. The places are 0 to 4, which is five places.
- arr(4) makes an array with four zeros at once. — Answer: f. arr(4) makes an empty array that grows with push. If you want starting values, you must write them yourself.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a[3];
a[0] = 2; a[1] = 4; a[2] = 6;
jout << a[1] + a[2] << "\n";
}
```
  Output: `10`. a[1] is 4 and a[2] is 6, so the sum is 10.
- The length of an array is written with .___. — Answer: **len**. .len gives the length of the array.
- Finding the largest value in an array: set best to the first place → loop from the second place → if the new value is bigger, use it as best → print best. Start from a real value that exists, then look at every place after it.
- How many places does int grid[2][3] have in total?
  - a) 6  b) 5  c) 23  — Answer: a. 2 times 3 is 6.
**Tasks**
- **Sum** — Make an array of 3, 5 and 7 and print the total 15. Output: `15`. Hint: Use a loop over all places and add them into total
- **Position of the largest** — In the array 3, 8, 1, 9, 4, print the position of the largest value. Output: `3`. Hint: Keep the position of the best value, not only the value
- **Grid sum** — Make grid[2][3] where grid[r][c] = r * 3 + c and print the sum of all places. Output: `15`. Hint: Use two nested loops and add into total

## Strings
**What it is.** A String is text that can grow. Join texts with +. .len tells the length in bytes. s[i] gives the character at place i, counted from 0. The useful methods are push (add a character at the end), find (give the place of a text), slice (cut a part), and to_int (change text to a number). Use == to compare two texts.
**Why it matters.** Most programs work with text, such as reading files, splitting words, or checking codes. If you know that .len counts bytes and find starts counting at 0, you avoid the bugs of cutting text in the wrong place.
**How to do it.**

Count a letter by looking at each place with s[i] in a loop.
```jk
String word = "banana";
int count = 0;
for i in 0..word.len {
    if word[i] == 'a' { count++; }
}
jout << count << "\n";
```
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    String first = "J2K";
    String title = first + " basics";
    jout << title << " " << title.len << " " << title[0] << "\n";
    if first == "J2K" { jout << "same\n"; }
    String line = "Hello, Jao";
    jout << line.find("Jao") << " " << line.slice(0, 5) << "\n";
    int n = "42".to_int();
    jout << n + 1 << "\n";
}
```

```
J2K basics 10 J
same
7 Hello
43
```

> **Watch out:** s[i] is a char and it is written in single quotes, like 'a'. "a" in double quotes is a String. They are different types, so the comparison does not work.
**Exercises**
- What is "abc".len?
  - a) 3  b) 2  c) 4  — Answer: a. len counts the characters. For English letters, that is the same as the bytes.
- 'a' in single quotes and "a" in double quotes are the same thing. — Answer: f. Single quotes give one char. Double quotes give a String. They are different types.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
String s = "ab";
s.push('c');
jout << s << "\n";
}
```
  Output: `abc`. push adds a character at the end of the text.
- The method that changes text with digits to an int is ___. — Answer: **to_int**. to_int works on a String.
- Cutting the word world from hello world: find the place of the space → add one to the place → slice from there to the end → print the result. The word after the space starts one place after the space.
- What is "42".to_int()?
  - a) 42  b) "42"  c) 4  — Answer: a. The method changes the text into the whole number 42.
**Tasks**
- **Count a** — Count the letter a in banana and print a 3. Output: `a 3`. Hint: Use word[i] == 'a'
- **Reverse** — Reverse the word abc to cba by looping from the end and push each character, then print it. Output: `cba`. Hint: Start at the length minus one and go down to zero
- **Cut a word** — From hello world print the word after the space. Output: `world`. Hint: Use find for the space, then slice

## Scope: where a name lives
**What it is.** A variable lives from the line where it is made until the closing brace of its block. A variable outside every function is a global, and everything can see it. A variable inside a function or a loop is a local. In a loop, a new local is made on every turn.
**Why it matters.** If you use a name outside its block, the compiler says it does not know it. Too many globals make it hard to find who changed a value. Scope keeps the parts of a program separate.
**How to do it.**

Declare a variable in the block where you use it. Only put it outside all functions when many functions need it.
```jk
int total = 100;
void main() {
    if total > 3 {
        int inner = total + 1;
    }
}
```
**Example.**

```jk
#import <stdlib>
using stdlib;

int total = 100;

int twice(int x) {
    int result = x * 2;
    return result;
}

void main() {
    int n = 5;
    if n > 3 {
        int inner = n + 1;
        jout << "inner = " << inner << "\n";
    }
    for i in 0..3 {
        int sq = i * i;
        jout << "sq = " << sq << "\n";
    }
    jout << twice(n) << " " << total << "\n";
}
```

```
inner = 6
sq = 0
sq = 1
sq = 4
10 100
```

> **Watch out:** If you print inner after the closing brace of the if, the compiler says the name is unknown. That is the scope rule working. Read the message to find where the variable was declared.
**Exercises**
- Can a variable made inside twice be used in main?
  - a) No  b) Yes  c) Only if it is an int  — Answer: a. A local variable lives only in its own function or block.
- A global variable can be changed from any function. — Answer: t. A global is visible everywhere, so any function can change it. This makes the change hard to trace.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

int g = 10;

void main() {
for i in 0..2 {
    int x = i + g;
    jout << x << "\n";
}
}
```
  Output: `10 / 11`. g is a global with the value 10. x is made again on each turn. The first turn gives 10 and the second gives 11.
- A variable declared outside every function is called a ___ variable. — Answer: **global**. A global variable can be seen everywhere.
- Life of a local variable inside a loop: enter the loop turn → make a new local → use it in this turn → leave the block and the value is gone. A new local is made every turn and it ends when the block ends.
- Why prefer locals to globals?
  - a) Because it is clear who changes the value  b) Because they are always faster  c) Because globals cannot be used  — Answer: a. A local is limited to one place, so it is easier to read and to check.
**Tasks**
- **Count from a function** — Keep a global counter that starts at 0. A function bump adds one. Call bump three times and print counter 3. Output: `counter 3`. Hint: bump must change the global counter
- **Sum of squares** — Loop i from 0 to 3 and make a local sq = i * i in each turn. Add sq to sum and print sum 14. Output: `sum 14`. Hint: The local sq is new on each turn. The squares are 0, 1, 4 and 9.

## struct: a group of values
**What it is.** A struct groups several values into one type. The values inside are called fields. You set them in order with braces, like Rect r = {3, 4};. A function inside a struct is a method, and it takes self, which is the object itself.
**Why it matters.** A piece of data often has several parts, such as a point with an x and a y, or an account with an owner and a balance. A struct shows that these values belong together.
**How to do it.**

Declare the struct with its fields and its methods, then make a value with braces that hold the values in order.
```jk
#import <stdlib>
using stdlib;

struct Rect {
    int w;
    int h;
    int area(self) {
        return self.w * self.h;
    }
}

void main() {
    Rect r = {3, 4};
    jout << r.area() << "\n";
}
```
**Example.**

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

```
12
4x5 area 20
```

> **Watch out:** A method that changes a field must take self, and you call it with a dot. If you forget self, the object is not changed. If the braces have fewer values than fields, you get an error.
**Exercises**
- What is a field in a struct?
  - a) A value stored in the object  b) The name of the program  c) A special function  — Answer: a. A field is a part of the data in the object, such as w and h.
- A method can change the fields of its object because it takes self. — Answer: t. self gives the method access to the object that was called, so it can change its fields.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

struct Point {
int x;
int y;
}

void main() {
Point p = {3, 4};
jout << p.x + p.y << "\n";
}
```
  Output: `7`. The values in the braces go into the fields in order. x is 3 and y is 4, so the sum is 7.
- A function inside a struct is called a ___. — Answer: **method**. A method works on one object.
- Making and using a Rect: declare the struct with its fields → make r with {3, 4} → call r.area() → print the result. The struct must be declared before a value is made, and the value must exist before a method is called.
- What happens if a method has no self?
  - a) It does not know which object to use, so it cannot reach the fields  b) It runs faster  c) Every object changes  — Answer: a. self says which object the method works on.
**Tasks**
- **Two coordinates** — Make Point p = {3, 4} and print the sum of x and y, which is 7. Output: `7`. Hint: Use p.x + p.y
- **Area** — Add a method area that returns w * h to Rect, and print the area of {5, 6}. Output: `30`. Hint: Use self.w * self.h
- **Account** — Make a struct Account with balance that starts at 100 and a method deposit(self, int x) that adds x. Deposit 25 and print balance 125. Output: `balance 125`. Hint: The method must take self to change balance

## enum and switch
**What it is.** An enum class is a list of named choices. switch picks the case that matches a value. There is no fall-through, so the next case does not run. _ is the case for anything else. An enum is not a number, so it cannot be mixed up with a number by mistake.
**Why it matters.** A value with a small set of choices, such as a direction, a state or a day, should be an enum. A plain number like 2 does not tell you its meaning. The compiler can warn you when a case is missing.
**How to do it.**

Declare the list, then write a case with the enum name and a double colon, like Light::Red.
```jk
#import <stdlib>
using stdlib;

enum class Light { Red, Yellow, Green };

void say(Light l) {
    switch l {
        Light::Red: jout << "stop\n";
        Light::Green: jout << "go\n";
        _: jout << "slow\n";
    }
}

void main() {
    say(Light::Red);
}
```
**Example.**

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

```
go
stop
three
```

> **Watch out:** If a switch on an enum misses a case, the compiler warns you. Read the warning and add the missing case. Do not hide all warnings with _.
**Exercises**
- What does switch do when one case matches?
  - a) Runs that case and then leaves the switch  b) Runs all the cases after it  c) Does nothing  — Answer: a. J2K does not fall through to the next case, so no break is needed.
- An enum class Light is the numbers 0, 1 and 2 that you can calculate with. — Answer: f. An enum is not a number. This keeps you from mixing it up with numbers by accident.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

enum class Heading { North, South };

void main() {
Heading d = Heading::South;
switch d {
    Heading::North: jout << "up\n";
    Heading::South: jout << "down\n";
}
}
```
  Output: `down`. The value d is South, so the South case runs.
- The case that handles all the other values in a switch is written as ___. — Answer: **_**. _ is the default case, run when no other case matches.
- Using an enum with a switch: declare the enum class → make the value Light::Green → pass it to say → switch picks the matching case. The enum must exist before it is used, and the value must be made before it is passed.
- Why is an enum better than plain numbers for states?
  - a) It is easy to read and the compiler can check it  b) It is always faster  c) It does not need a switch  — Answer: a. Clear names make the code easy to read, and the compiler warns about missing cases.
**Tasks**
- **Direction** — Declare enum class Heading { North, South, East } and use switch so that d = Heading::East prints east. Output: `east`. Hint: Write the case Heading::East and print east
- **Days** — Use switch on the int n. Print one when n is 1, two when n is 2, and other for anything else. Test it with 2. Output: `two`. Hint: Use 2: for the case and _ for the rest
- **Shape** — Declare enum class Shape { Circle(double r), Empty } with a method area that returns 3.0 * r * r for Circle and 0.0 for Empty. Print the area of Circle(2.0). Output: `12.000000`. Hint: Use switch self^ inside the method

## Option and Result
**What it is.** Option<T> is for a value that may be missing. It has a value or it has none. Check it with is_some or is_none. Result<T, Error> is for an action that may fail. It gives Ok with a value or Err with a reason. The ? sign passes an error back to the caller at once. If there is no error, it gives you the value to use.
**Why it matters.** A function that reads a file or an environment variable may have no result. Option and Result make you think about the failure case, instead of getting a wrong value without any sign.
**How to do it.**

With a Result, use switch with the Ok and Err cases, or use ? to pass the error on.
```jk
#import <stdlib>
using stdlib;

void show(Result<int, Error> r) {
    switch r {
        Result::Ok(v): jout << "sum = " << v << "\n";
        Result::Err(e): jout << "error: " << e.message << "\n";
    }
}

void main() {
    show(Result<int, Error>::Ok(42));
}
```
**Example.**

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
    jout << home.is_none() << "\n";
}
```

```
sum = 42
error: empty text
true
```

> **Watch out:** If you use unwrap on an empty Option, the program fails. Check is_some first, or use or with a fallback value.
**Exercises**
- What does ? do with an Err result?
  - a) It sends the Err back to the caller at once  b) It changes it to Ok  c) It does nothing  — Answer: a. ? passes the error up and ends the function. With Ok, it gives the value inside.
- An empty Option is the same as the number zero. — Answer: f. An empty Option is not zero. It means there is no value, so you check it with is_none.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
Option<String> v = Env::get("J2K_SURELY_NOT_SET");
jout << v.is_some() << "\n";
}
```
  Output: `false`. This variable is not set, so there is no value, and is_some gives false.
- The sign that passes an error on to the caller is called ___ in English. — Answer: **propagate**. ? returns the Err at once when there is an error.
- Using the Result of add: parse gives a Result → ? checks a and gets its value → ? checks b → add returns Ok with the sum. If any step gives Err, the function ends before the next step.
- Why must you write Result<int, Error>?
  - a) To say the type of a good value and the type of an error  b) Because int is not enough  c) Because it is a function name  — Answer: a. A Result has two types inside: the type of a good value and the type of an error.
**Tasks**
- **Result of a number** — Write parse that returns Ok of s.to_int(). Use switch to print value 12 for parse("12"). Output: `value 12`. Hint: Use Result<int, Error>::Ok and the Ok case in switch
- **Pass the error on** — Write add(a, b) that uses parse with ?, and print sum 5 for "2" and "3". Output: `sum 5`. Hint: Use int x = parse(a)?; and return Ok(x + y)
- **Fallback** — Get J2K_NOT_HERE with Env::get, give the fallback none with or, and print the result. Output: `none`. Hint: The method or(fallback) gives the fallback value when the Option is empty

## Reading compiler errors
**What it is.** A compiler message looks like file:line:column: error: what is wrong. The next lines show the line and a ^ under the problem. A help: line tells you what to try. The first message matters most, because the later ones are often caused by it.
**Why it matters.** Every programmer sees compiler errors every day. If you can read them, you fix the problem in minutes instead of guessing for hours. Fix the first error, then compile again.
**How to do it.**

Read the first message. Go to the line it names and look where the ^ points. Follow the help line if there is one. Then compile again.
A missing semicolon gives a message that says the statement is not finished. Add the semicolon at the end of the line.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // the first error is the one to fix: this version compiles and prints
    int count = 5;
    jout << "count " << count << "\n";
}
```

```
count 5
```

> **Watch out:** Do not fix the second or third message first. They may go away when you fix the first one. Fix one error, compile again, and repeat.
**Exercises**
- Which compiler message should you fix first?
  - a) The first one  b) The last one  c) The longest one  — Answer: a. The first error is the root cause. Later errors may be a result of it.
- The ^ sign in a message shows where the compiler found the problem. — Answer: t. The ^ is placed under the character that the compiler did not understand.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 2;
jout << n * 3 << "\n";
}
```
  Output: `6`. There is no error. The code multiplies 2 by 3 and gets 6.
- The line that starts with help: in a compiler message gives a ___. — Answer: **fix**. help gives a suggested way to solve the problem.
- How to fix a compiler error: read the first message → look at the line and the ^ → fix it with the help line or your own idea → compile again. Compiling again shows whether the error is gone or whether another one is left.
- What does file:3:5: error mean?
  - a) In the file, on line 3, column 5, there is an error  b) The file has five lines  c) Author number 3  — Answer: a. The first number is the line and the second number is the column.
**Tasks**
- **Fix the type** — Store the number 5 in an int called count and print count 5. Output: `count 5`. Hint: The variable must be an int and the value must be a number
- **Fix the name** — Declare total as 9 and print total 9. Output: `total 9`. Hint: Use the same name in the declaration and in the print
- **Check after a fix** — Write a program that prints ok and goes to a new line. Output: `ok`. Hint: Use jout one time
