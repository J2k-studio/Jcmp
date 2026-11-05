# Machine (english)

## What a computer can do
**What it is.** A computer does three main things. It calculates, it keeps data in memory, and it moves data between the different memories. Every program is made of small actions like these: one addition, or one read of a value. A CPU does millions of instructions per second, but each one is very small.
**Why it matters.** If you know how many instructions a program runs, you can guess whether it is fast or slow. A loop of one million turns with three jobs per turn does about three million jobs. This counting is the base of making programs faster.
**How to do it.**

Count what the loop does in one turn, then multiply by the number of turns. The example below adds the numbers 1 to 1000. That takes 1000 turns, and the total is 500500.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int sum = 0;
    for i in 1..1001 { sum += i; }
    jout << "sum " << sum << "\n";
}
```

```
sum 500500
```

> **Watch out:** A common mistake is to think that the CPU does everything at once. A loop that runs for a long time is slow in proportion to the number of instructions it repeats, however fast the machine is.
**Exercises**
- A loop runs 1000 turns and adds once per turn. How many additions happen?
  - a) 1000  b) 1  c) 1000000  — Answer: a. One addition per turn, for 1000 turns, makes 1000 additions.
- A CPU can only calculate. It has nothing to do with storing data. — Answer: f. A CPU must read and write memory to keep values, such as variables.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int sum = 0;
for i in 1..11 { sum += i; }
jout << sum << "\n";
}
```
  Output: `55`. The numbers 1 to 10 add up to 55, the well-known sum from maths.
- Every real action a program takes is a calculation, a read, or a ___ of data. — Answer: **write**. The CPU works on data by reading from memory and writing to memory.
- The order of thinking about whether a program is fast or slow: look at what the loop does in one turn → count the turns → multiply the work per turn by the turns → compare with your goal. You need to know the amount of work before you can judge it.
- A loop has two jobs in each turn. How many jobs does it do in 1000 turns?
  - a) 2000  b) 1000  c) 3000  — Answer: a. Two jobs times 1000 turns gives 2000 jobs.
**Tasks**
- **Sum to 100** — Write a program that adds the numbers 1 to 100 and prints sum 5050. Output: `sum 5050`. Hint: Use for i in 1..101
- **Count steps** — Run a loop of 10 turns. Each turn adds 3 to total. Print total 30. Output: `total 30`. Hint: Use total += 3 inside the loop

## Bits and bytes
**What it is.** Data in memory is kept as bits. Eight bits make one byte. The type of a value decides how many bytes it uses. A char uses one byte. An int in J2K uses eight bytes. A float uses four bytes, and a double uses eight bytes. The size tells you how much memory an array needs.
**Why it matters.** When you know the size of each type, you know how big an array is in memory and when the memory will run out. Using float instead of double makes an array half the size, so the CPU can read more values for each memory read.
**How to do it.**

Use sizeof(type) to see the size in bytes. Work out the size of an array by multiplying the number of items by the size of one item.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "char " << sizeof(char) << " int " << sizeof(int) << "\n";
    jout << "float " << sizeof(float) << " double " << sizeof(double) << "\n";
    int n = 100;
    jout << "array of 100 floats: " << n * sizeof(float) << " bytes\n";
}
```

```
char 1 int 8
float 4 double 8
array of 100 floats: 400 bytes
```

> **Watch out:** Bits and bytes are not the same amount. A bit is the smallest unit. A byte is eight bits. If a number is given in bits, divide it by eight before you compare it with memory sizes.
**Exercises**
- How many bits are in one byte?
  - a) 8  b) 4  c) 16  — Answer: a. One byte is eight bits.
- A double uses more memory than a float. — Answer: t. A double uses eight bytes and a float uses four bytes.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << sizeof(float) * 10 << "\n";
}
```
  Output: `40`. A float uses 4 bytes. Ten of them use 40 bytes.
- The function ___ tells the size of a type in bytes. — Answer: **sizeof**. sizeof takes a type in brackets.
- Work out the size of an array of 50 floats: write down the number of items, 50 → find the size of a float, 4 bytes → multiply them → you get 200 bytes. You must know the size of one item before you can multiply by the count.
- Why does float make an array use less memory?
  - a) It uses four bytes for each value, not eight  b) It adds faster  c) It has no sign  — Answer: a. A smaller size per value means less memory.
**Tasks**
- **Size of double** — Print the size of a double in bytes. Output: `8`. Hint: Use sizeof(double)
- **Float array** — Work out the total size in bytes of a float array of 25 values and print it. Output: `100`. Hint: Multiply 25 by sizeof(float)

## Variables, arrays and addresses
**What it is.** Every variable has an address in memory. @x is the address of x. A pointer int^ p keeps the address of an int, and p^ is the value it points to. An array is a row of boxes next to each other, and the distance between two boxes is the size of the type.
**Why it matters.** Giving a function an address lets it change the original value without copying all the data. Knowing that array boxes are next to each other explains why reading in order is fast.
**How to do it.**

Declare a pointer with the type and ^, then set its address with @. Write through the pointer with p^ = value.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 1;
    int^ p = @x;
    p^ = 5;
    jout << "x " << x << "\n";
    int a[3];
    a[0] = 10; a[1] = 7; a[2] = 3;
    int^ q = @a;
    jout << "a[1] through the pointer: " << q[1] << "\n";
}
```

```
x 5
a[1] through the pointer: 7
```

> **Watch out:** Changing a value through a pointer also changes the original variable. This is useful, but it is hard to trace. If you do not want the original to change, pass a plain value instead.
**Exercises**
- What is @x?
  - a) The address of x in memory  b) The value of x  c) The size of x  — Answer: a. @ gives the address. x alone is the value.
- p^ = 5 changes the value that the pointer p points to. — Answer: t. Writing through ^ changes the value at the address the pointer holds.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int v = 2;
int^ p = @v;
p^ = p^ * 10;
jout << v << "\n";
}
```
  Output: `20`. p points to v. The value it points to is multiplied by 10, so v becomes 20.
- The boxes of an array are next to each other in memory, which is called ___. — Answer: **contiguous**. Boxes that are next to each other can be read one after another quickly.
- Changing a variable through a pointer: declare int x → make int^ p = @x → write p^ = 5 → x now has the value 5. The pointer must point to the variable before you write through it.
- Why is reading an array in order fast?
  - a) Because the next box is next to the last one in memory  b) Because the CPU likes even numbers  c) Because there are no pointers  — Answer: a. Boxes next to each other fill a cache block that was already loaded.
**Tasks**
- **Through a pointer** — Declare int n = 4 and int^ p = @n. Multiply the value p points to by 3, then print n. Output: `12`. Hint: Write p^ = p^ * 3
- **Array pointer** — An array a holds 4, 9 and 16. Set int^ q = @a and print q[2]. Output: `16`. Hint: A pointer can read a box by its index

## Slow RAM and the cache
**What it is.** RAM is much slower than the CPU, so the CPU has a small cache close to it for the data it uses often. When one value is read, the system brings a whole block of about 64 bytes into the cache. If the program uses the whole block before it moves on, the work is fast.
**Why it matters.** Two sums with the same numbers can be fast or slow, depending on the order of the reads. The slowness comes from waiting for RAM, not from the number of additions.
**How to do it.**

When you read a two-dimensional table, put the loop over columns inside the loop over rows, because the values in a row sit next to each other in memory. The example adds the table in two orders and gets the same answer.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 4;
    int[] t = arr(n * n);
    for i in 0..n * n { t.push(i); }
    int by_rows = 0;
    for r in 0..n { for c in 0..n { by_rows += t[r * n + c]; } }
    int by_cols = 0;
    for c in 0..n { for r in 0..n { by_cols += t[r * n + c]; } }
    jout << "rows " << by_rows << " cols " << by_cols << "\n";
    jout << "same " << (by_rows == by_cols) << "\n";
}
```

```
rows 120 cols 120
same true
```

> **Watch out:** The speed differs on a real machine, but the answer must always be the same. If the answers differ, the loop is wrong, not the cache.
**Exercises**
- Why is reading along a row faster than along a column?
  - a) Because the values next to each other are loaded into the cache together  b) Because the CPU is faster on columns  c) Because rows are shorter  — Answer: a. A cache block holds several values next to each other. Using the whole block avoids many waits for RAM.
- The row sum and the column sum must always be equal. — Answer: t. Both add every value once. Only the order is different.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] t = arr(4);
t.push(1); t.push(2); t.push(3); t.push(4);
int s = 0;
for i in 0..4 { s += t[i]; }
jout << s << "\n";
}
```
  Output: `10`. 1 + 2 + 3 + 4 = 10
- The block of data that the cache reads at one time is about 64 bytes, and this is called a cache ___. — Answer: **line**. A cache line is one block that is loaded at a time.
- Making a table read faster: loop over rows on the outside → loop over columns on the inside → read the boxes that are next to each other → the answer stays the same but it is faster. Changing the loop order changes cache use, not the answer.
- What is the difference between RAM and the cache?
  - a) RAM is bigger but slower than the cache  b) RAM is always faster  c) They are the same  — Answer: a. The cache is small and fast. RAM is large and slow.
**Tasks**
- **Row total** — A 3 by 3 table holds t[i] = i for i from 0 to 8. Add all values by rows and print 36. Output: `36`. Hint: 0 + 1 + ... + 8 = 36
- **Column total** — Add the same values in column order and print 36. Output: `36`. Hint: Change the order of the loops and the sum stays the same

## Walking in order or jumping
**What it is.** Reading an array box by box, in order, is called stride 1. Jumping over boxes is a big stride. Both read the same values and give the same sum, but a big stride wastes the cache, because each block gives only some of its values.
**Why it matters.** Real programs often jump by accident, for example when they read a column from a table that is stored by rows. Knowing what is a walk in order helps you arrange the loops.
**How to do it.**

Try a jump index (i * 3) % n over an array of size n, and compare the sum with the sum from reading in order.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 8;
    int[] a = arr(n);
    for i in 0..n { a.push(i * 2); }
    int walk = 0;
    for i in 0..n { walk += a[i]; }
    int jump = 0;
    for i in 0..n { jump += a[(i * 3) % n]; }
    jout << "walk " << walk << " jump " << jump << "\n";
}
```

```
walk 56 jump 56
```

> **Watch out:** The same sum does not mean the same speed. Check whether the reads are in order, and if they are not, change the data layout or the loop.
**Exercises**
- What does an index that jumps over boxes cause?
  - a) A waste of the cache blocks  b) A different answer  c) A compile error  — Answer: a. A jump loads blocks and uses only some of their values.
- A jump over boxes always gives a different sum from walking in order. — Answer: f. If every box is read once, the sum is the same. Only the speed is different.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int[] a = arr(3);
a.push(5); a.push(6); a.push(7);
int s = 0;
for i in 0..3 { s += a[(i * 2) % 3]; }
jout << s << "\n";
}
```
  Output: `18`. The indexes 0, 2, 1 read the values 5, 7, 6, which add up to 18.
- Reading boxes one after another is called stride ___. — Answer: **one**. Stride one means moving one box at a time.
- Comparing two ways of reading: make the same array → read in order → read with jumps → compare the sums and the time. The sums must be equal before you compare the speed.
- When you are not sure which access is faster, what should you do?
  - a) Measure it with a fair clock  b) Guess and believe it  c) Do nothing  — Answer: a. A measurement gives the truth more than a guess.
**Tasks**
- **Jump six** — An array of 0 to 5 holds values equal to their index. Read the index (i * 5) % 6, add the values and print sum 15. Output: `sum 15`. Hint: The indexes are a new order of 0 to 5, each used once
- **Jump four** — In the array 1, 2, 3, 4 read the index (i * 3) % 4, add the values and print 10. Output: `10`. Hint: This jump visits every box exactly once

## The pipeline and branches
**What it is.** A CPU works in a pipeline. While one instruction runs, the next one is fetched and decoded at the same time. An if is a branch: the CPU must guess which way the program goes. If the guess is right, it is fast. If the guess is wrong, the CPU throws away the work and starts again. Guesses are good when the result of the condition follows a pattern.
**Why it matters.** A loop with an if inside may be slow because of wrong guesses. If the data is arranged so that the results come in groups, the CPU guesses better.
**How to do it.**

Keep the condition in a loop simple. If you can arrange the data so that the results come in groups, do it. The answer stays the same.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 10;
    int[] a = arr(n);
    for i in 0..n { a.push(i); }
    int count = 0;
    for i in 0..n {
        if a[i] >= 5 { count += 1; }
    }
    jout << "count " << count << "\n";
}
```

```
count 5
```

> **Watch out:** Adding branches in a hot loop often makes it slower. Check how often the if runs before you decide what to change.
**Exercises**
- Why is a wrong guess of a branch slow?
  - a) The CPU must throw away the instructions it guessed and start again  b) Because the instructions disappear  c) Because if does not run  — Answer: a. The wrong guessed work is thrown away, which wastes time.
- A pipeline means the CPU runs one instruction completely before it fetches the next one. — Answer: f. A pipeline overlaps several steps of different instructions at the same time.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int count = 0;
for i in 0..6 {
    if i % 2 == 0 { count += 1; }
}
jout << count << "\n";
}
```
  Output: `3`. The values 0, 2 and 4 are even, so the count is 3.
- An if in a loop makes the CPU ___ which way the program will go. — Answer: **guess**. The CPU guesses the branch before the condition is known.
- How the CPU handles an if in a loop: fetch the if instruction → guess the way to go → run the next instructions → if the guess was wrong, throw the work away and start again. A wrong guess is a cost the CPU must pay.
- What kind of data makes the if in a loop easy to guess?
  - a) Results that come in groups, such as small values all before large values  b) Random values only  c) No data at all  — Answer: a. When the result repeats in a row, the last guess is usually right.
**Tasks**
- **Count above five** — Count the values in the array 0 to 9 that are greater than 5 and print count 4. Output: `count 4`. Hint: The values 6, 7, 8 and 9 are greater than 5
- **Even numbers** — Count the even numbers from 1 to 10 with an if and print even 5. Output: `even 5`. Hint: Use % 2 == 0

## SIMD: many values at once
**What it is.** SIMD means one instruction works on many values at the same time. The NEON registers of ARM64 are 128 bits, so they hold four float values at once. The type f32x4 in J2K holds four values, and adding a vector to itself does all four lanes in one instruction.
**Why it matters.** Pictures, sound and matrix products repeat the same work millions of times. Doing it one value at a time is slow. SIMD does several values per instruction, and sometimes the compiler makes SIMD code from a plain loop by itself.
**How to do it.**

Make an f32x4 value with braces, then use + or the method sum, which works on all the lanes at once.
**Example.**

```jk
#import <stdlib>
#import <simd>
using stdlib;

void main() {
    f32x4 f = {1.0, 2.0, 3.0, 4.0};
    jout << f.sum() << " " << f.min() << " " << f.max() << "\n";
    f32x4 g = f * 2.0;
    jout << g.w << "\n";
}
```

```
10.000000 1.000000 4.000000
8.000000
```

> **Watch out:** You must import simd before you use f32x4. A vector is not an ordinary array. Both sides of an operation must have the same type.
**Exercises**
- How many values does an f32x4 work on in one instruction?
  - a) 4  b) 2  c) 8  — Answer: a. The name f32x4 says four values, each 32 bits.
- SIMD can be faster because it works on several values in one instruction. — Answer: t. This is the main idea of SIMD.
- Predict the output:

```jk
#import <stdlib>
#import <simd>
using stdlib;

void main() {
f32x4 a = {1.0, 2.0, 3.0, 4.0};
jout << (a + a).sum() << "\n";
}
```
  Output: `20.000000`. a + a gives 2, 4, 6, 8. Their sum is 20.
- Each value inside a vector is called a ___. — Answer: **lane**. A lane is one slot of a vector.
- Adding up four values with SIMD: make an f32x4 → add it to itself → call sum → print the result. The values must exist before you can add and sum them.
- Which library must you import before you use f32x4?
  - a) simd  b) jout  c) sum  — Answer: a. simd gives the vector types and their methods.
**Tasks**
- **Sum of a vector** — Make an f32x4 with the values 1, 2, 3 and 4, and print its sum as 10.000000. Output: `10.000000`. Hint: Use .sum()
- **Multiply each lane** — Make an f32x4 with the values 1, 1, 1 and 1, multiply it by 3.0, and print the sum of the result. Output: `12.000000`. Hint: Four lanes of 3 add up to 12

## Floats and doubles: decimal numbers in the machine
**What it is.** A decimal number in the machine is stored as a binary number that is close to the real value. Some numbers, like 0.1, cannot be stored exactly. A float uses 32 bits and a double uses 64 bits, so a double is more exact. Comparing two decimal numbers with == is often wrong, because they differ by a tiny amount.
**Why it matters.** Money, science and graphics programs must understand this small error. For example, in the machine 0.1 + 0.2 is not equal to 0.3.
**How to do it.**

Check the difference with a small limit you accept, instead of using ==. The example below shows both.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    double x = 0.1 + 0.2;
    jout << (x == 0.3) << " " << x << "\n";
    float f = 1.5;
    jout << (double)f * 2.0 << "\n";
    double diff = x - 0.3;
    if diff < 0.000001 && diff > -0.000001 { jout << "close enough\n"; }
}
```

```
false 0.300000
3.000000
close enough
```

> **Watch out:** Printing 0.300000 does not prove that the value is exact. The output has six digits, and the real value may differ from 0.3 by a little.
**Exercises**
- How is a double different from a float?
  - a) A double has 64 bits and is more exact  b) A double keeps whole numbers only  c) They are the same  — Answer: a. A double uses eight bytes and is more exact than a float.
- In the machine, 0.1 + 0.2 == 0.3 is always true. — Answer: f. Some decimal values cannot be stored exactly, so the sum has a tiny error.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
double a = 0.5 + 0.25;
jout << (a == 0.75) << "\n";
}
```
  Output: `true`. 0.5 and 0.25 can be stored exactly in binary, so the sum is exactly 0.75.
- To compare decimal numbers safely, use a small ___ that you accept. — Answer: **tolerance**. A tolerance is the error you accept.
- Comparing 0.1 + 0.2 with 0.3 safely: work out the difference → take its absolute value → compare it with a small accepted limit → decide. Do not compare with == directly.
- How many bits does a float use?
  - a) 32  b) 64  c) 16  — Answer: a. A float uses 32 bits, four bytes.
**Tasks**
- **Exact value** — Print the result of 0.5 + 0.25 == 0.75. Output: `true`. Hint: 0.5 and 0.25 are stored exactly
- **Difference** — Work out 1.0 - 0.9 and print close if the result differs from 0.1 by at most 0.000001, otherwise print far. Output: `close`. Hint: The result differs from 0.1 by a tiny amount

## Fused multiply-add (FMA)
**What it is.** Some CPUs have a fused multiply-add instruction. It does a * b + c in one instruction and rounds only once. The answer can differ a little from multiplying first and adding after, which rounds twice. The J2K compiler uses this instruction by itself, and the switch -nofma turns it off so that results can be compared.
**Why it matters.** One instruction is faster and a little more exact, but the answer can differ slightly from what you expect. You must know this when you compare results with another program.
**How to do it.**

Write the formula in the normal way, a * b + c. The compiler chooses the combined instruction when it can.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    double a = 2.0;
    double b = 3.0;
    double c = 1.0;
    double r = a * b + c;
    jout << r << "\n";
    jout << (r == 7.0) << "\n";
}
```

```
7.000000
true
```

> **Watch out:** FMA does not always make the answer wrong. It rounds fewer times. When you compare with another calculation, use a tolerance that you accept.
**Exercises**
- What does FMA do?
  - a) It multiplies and adds in one instruction  b) It divides and subtracts  c) It saves a value in a file  — Answer: a. Fused multiply-add means multiply and add together.
- FMA always rounds twice. — Answer: f. FMA rounds once, after the multiply and the add.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
double x = 4.0 * 2.0 + 1.0;
jout << x << "\n";
}
```
  Output: `9.000000`. 4 times 2 is 8, plus 1 is 9.
- The compiler switch that turns FMA off is -___. — Answer: **nofma**. -nofma turns the combined instruction off so you can compare results.
- The formula a * b + c: multiply a by b → add c → with FMA, round once at the end → you get the result. Multiplying before adding is the order in mathematics.
- Why can the result of FMA differ from multiply then add?
  - a) Because it rounds fewer times  b) Because the value changes  c) Because FMA does not use numbers  — Answer: a. A different number of roundings can give a slightly different answer.
**Tasks**
- **Simple FMA** — Work out 5.0 * 2.0 + 3.0 and print 13.000000. Output: `13.000000`. Hint: Both ways give the same result for this number
- **Two steps** — Work out x = 1.5 * 4.0, then y = x + 0.5, and print y. Output: `6.500000`. Hint: Use two variables

## Threads and race conditions
**What it is.** A thread runs a function at the same time as other functions. If two threads add to the same variable with counter += 1, some additions can be lost, because adding takes three steps: read, add and write. If the steps of two threads mix, the result is wrong. This is called a race condition. Atomic::add does the three steps as one step that cannot be interrupted.
**Why it matters.** A program that uses several cores of the CPU shares data. If it shares data without protection, the result is not certain, and the cause is hard to find.
**How to do it.**

Create a thread with create, giving the function name and an argument. Use join to wait until it is done. Use Atomic::add on a shared variable.
**Example.**

```jk
#import <stdlib>
#import <cpu>
using stdlib;
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

```
30000
```

> **Watch out:** counter += 1 in several threads is not safe, even if the result looks right some of the time. Use Atomic or a lock every time you share a value.
**Exercises**
- What is a race condition?
  - a) The result depends on the order in which threads interleave  b) A race between programs  c) A slow compile  — Answer: a. If the order is not certain, the result can be wrong.
- Atomic::add protects the adding from being interrupted. — Answer: t. It does the read, the add and the write as one step that cannot be divided.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 0;
Atomic::add(@n, 5);
Atomic::add(@n, 2);
jout << n << "\n";
}
```
  Output: `7`. Atomic::add adds 5, then adds 2, so the value is 7.
- The method that waits until a thread has finished is called ___. — Answer: **join**. join waits until that thread is done.
- Using threads with a shared counter: create the threads with create → every thread uses Atomic::add → join every thread → print the final value. You must wait for all threads to finish before you read the result.
- Why must you join the threads before you read the counter?
  - a) To be sure every thread has finished adding  b) To make the threads faster  c) To close the program  — Answer: a. If you do not wait, the value may not be complete yet.
**Tasks**
- **Two counters** — Create two threads that each add 1 a thousand times to a shared counter. Join both, then print 2000. Output: `2000`. Hint: Use Atomic::add on the counter
- **Five adds** — Add 1 to a counter with Atomic::add five times in one program, then print 5. Output: `5`. Hint: Use one Atomic::add for each addition

## Matrix product, the ijk way
**What it is.** Matrix product C = A * B means that C[i][j] is the sum of A[i][k] times B[k][j], with k going from 0 to n-1. The direct way is to loop over i on the outside, j in the middle, and k on the inside. The name ijk comes from this order of the loops.
**Why it matters.** The matrix product is the main job of machine learning and graphics. Once you understand this order of loops, you can see why other orders are faster.
**How to do it.**

Start with C set to zero, then add the products into each cell of C.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 2;
    int[] a = arr(4); int[] b = arr(4); int[] c = arr(4);
    a.push(1); a.push(2); a.push(3); a.push(4);
    b.push(5); b.push(6); b.push(7); b.push(8);
    for i in 0..4 { c.push(0); }
    for i in 0..n {
        for j in 0..n {
            for k in 0..n {
                c[i * n + j] += a[i * n + k] * b[k * n + j];
            }
        }
    }
    jout << c[0] << " " << c[1] << "\n";
    jout << c[2] << " " << c[3] << "\n";
}
```

```
19 22
43 50
```

> **Watch out:** If you forget to set C to zero first, the result is wrong, because the old values are added in. An array made with push must be filled with zeros by you.
**Exercises**
- In C[i][j], what does the index k do?
  - a) It goes along the row of A and the column of B  b) It chooses a row of C  c) Nothing  — Answer: a. k adds up the products of a row of A with a column of B.
- For A * B, the number of columns of A must equal the number of rows of B. — Answer: t. Otherwise the two matrices cannot be multiplied.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 2;
int b = 3;
jout << a * b + a << "\n";
}
```
  Output: `8`. 2 times 3 is 6, plus 2 is 8.
- The plain loop order is i, j, and then ___. — Answer: **k**. The last loop is over k, so the order is ijk.
- Multiplying two 2 by 2 matrices: set C to zero → loop over i and j → loop over k and add the products → print each cell. You must prepare zeros before you add.
- Why is the index written as i * n + j?
  - a) Because a matrix is stored row after row in one long array  b) Because n must be multiplied  c) Because j comes first  — Answer: a. A two-dimensional table is stored as one line of rows.
**Tasks**
- **Times identity** — Use A = [[1,2],[3,4]] and B = [[1,0],[0,1]], then print C[0] and C[3] separated by a space. Output: `1 4`. Hint: A matrix times the identity is A itself
- **Product 19** — Use A = [[1,2],[3,4]] and B = [[5,6],[7,8]] and print C[0]. Output: `19`. Hint: 1 * 5 + 2 * 7 = 19

## Loop orders of the matrix product
**What it is.** There are six orders for the loops i, j and k. All give the same answer, but the order ikj makes the inner loop walk along rows of B and C, which sit next to each other in memory, so the cache works well. The order ijk walks down the columns of B with jumps, so it is slower.
**Why it matters.** When you write several nested loops, the order of the loops changes the speed a lot while the answer stays the same. Writers of fast programs must know this.
**How to do it.**

Move the loop over k into the middle. The inner loop over j then walks along rows of C and B.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 3;
    int[] a = arr(9); int[] b = arr(9); int[] c1 = arr(9); int[] c2 = arr(9);
    for i in 0..9 { a.push(i + 1); b.push(9 - i); c1.push(0); c2.push(0); }
    for i in 0..n {
        for j in 0..n {
            for k in 0..n { c1[i * n + j] += a[i * n + k] * b[k * n + j]; }
        }
    }
    for i in 0..n {
        for k in 0..n {
            for j in 0..n { c2[i * n + j] += a[i * n + k] * b[k * n + j]; }
        }
    }
    bool same = true;
    for i in 0..9 { if c1[i] != c2[i] { same = false; } }
    jout << "same " << same << "\n";
    jout << c2[0] << " " << c2[8] << "\n";
}
```

```
same true
30 90
```

> **Watch out:** Changing the loop order can change the speed a lot, but you must always check that the answer is the same before you trust the change.
**Exercises**
- How does the order ikj make the inner loop walk along rows of B and C?
  - a) The index j is the innermost, so it walks next-door boxes  b) It has no effect  c) It changes the answer  — Answer: a. The inner loop over j reaches boxes that are next to each other.
- Different loop orders always give different answers for the matrix product. — Answer: f. The answer is the same, because the same products are added, only in a different order.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int s = 0;
for i in 0..2 {
    for k in 0..3 { s += 1; }
}
jout << s << "\n";
}
```
  Output: `6`. The outer loop runs 2 times and the inner loop 3 times, so the total is 6.
- Moving the loop over k into the middle gives the order i, k and then ___. — Answer: **j**. The new order is i, k, j.
- Testing a new loop order: write the old version → write the new version → compare every cell → measure the time when the results are the same. You must be sure the results match before you compare the speed.
- Why must you compare results before you trust a loop change?
  - a) Because a mistake in writing can change the answer  b) Because the compiler does not run  c) Because the time changes  — Answer: a. The answer must not change. If it does, the loop is wrong.
**Tasks**
- **Swap the loops** — Use A = [[1,2],[3,4]] and B = [[5,6],[7,8]] with the order i, k, j, and print C[0]. Output: `19`. Hint: The order is different, but the answer is the same
- **Compare orders** — Compare the ijk and ikj results on the same 2 by 2 matrices and print same true. Output: `same true`. Hint: Both results must be equal

## Blocking: cutting the product into blocks
**What it is.** Blocking cuts a matrix into small blocks that fit in the cache, then multiplies one block at a time. A block that is used again stays in the cache while it is needed, so it is not read from RAM again and again. The answer stays the same, because every product is still added once, only in another order.
**Why it matters.** A big matrix does not fit in the whole cache. Cutting it into blocks makes the cache much more useful. Almost every math library uses this idea.
**How to do it.**

Loop over the blocks on the outside with the block size bs, then multiply only the part of each block with the inner loops.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int n = 4;
    int bs = 2;
    int[] a = arr(16); int[] b = arr(16); int[] c = arr(16);
    for i in 0..16 { a.push(i % 5); b.push((i * 3) % 7); c.push(0); }
    int ii = 0;
    while ii < n {
        int jj = 0;
        while jj < n {
            for i in ii..ii + bs {
                for k in 0..n {
                    for j in jj..jj + bs { c[i * n + j] += a[i * n + k] * b[k * n + j]; }
                }
            }
            jj += bs;
        }
        ii += bs;
    }
    int plain = 0;
    for i in 0..n {
        for j in 0..n {
            for k in 0..n { plain += a[i * n + k] * b[k * n + j]; }
        }
    }
    int total = 0;
    for i in 0..16 { total += c[i]; }
    jout << "blocked total " << total << "\n";
    jout << "plain total " << plain << "\n";
}
```

```
blocked total 339
plain total 339
```

> **Watch out:** Blocking must cover every cell exactly once. Check the edges of the last block when n is not a multiple of the block size.
**Exercises**
- Why are small blocks faster?
  - a) Because they stay in the cache and are used again  b) Because they need no additions  c) Because they are decimal  — Answer: a. A block that fits in the cache is used many times without a trip to RAM.
- Blocking changes the answer of the matrix product. — Answer: f. Every product is still added, only in a different order.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int total = 0;
for i in 0..4 {
    if i % 2 == 0 { total += i; }
}
jout << total << "\n";
}
```
  Output: `2`. The loop runs for 0 to 3. The even values 0 and 2 add up to 2.
- Cutting a matrix product into small pieces is called ___. — Answer: **blocking**. Blocking means dividing the work into blocks.
- Writing a blocked product: choose the block size → loop over the blocks on the outside → loop inside each block → check the result against the plain version. You must always check the result against the plain method.
- What must you watch when n is not a multiple of the block size?
  - a) The last block must cover the cells that are left  b) Nothing  c) The type must change  — Answer: a. If the edges of a block are wrong, some cells are skipped or counted twice.
**Tasks**
- **Blocks of one** — Do blocking with block size 2 on A = [[1,2],[3,4]] and B = [[1,0],[0,1]], then print C[0]. Output: `1`. Hint: The product with the identity is A
- **Sum of cells** — Multiply A = [[1,2],[3,4]] by B = [[5,6],[7,8]] and print the sum of the four cells of C. Output: `134`. Hint: 19 + 22 + 43 + 50 = 134

## Measuring fairly and making code fast
**What it is.** Making a program fast starts with measuring, not guessing. Use Time::mono_ns() to read the clock before and after the work, then subtract to get nanoseconds. Run the work several times and keep the shortest time, because other activity on the machine makes each run a little different.
**Why it matters.** If you do not measure, you may change a part that is not the slow part, and waste your time. A fair measurement lets you compare two versions honestly.
**How to do it.**

Save the start time, do the work, save the end time, subtract. Repeat the work several times, and check that the answer is the same every time you measure.
**Example.**

```jk
#import <stdlib>
using stdlib;

int work(int[] a) {
    int s = 0;
    for i in 0..a.len { s += a[i] * 3; }
    return s;
}

void main() {
    int[] a = arr(1000);
    for i in 0..1000 { a.push(i % 10); }
    int best = 0;
    int check = 0;
    for run in 0..5 {
        int t0 = Time::mono_ns();
        check = work(a);
        int dt = Time::mono_ns() - t0;
        if run == 0 || dt < best { best = dt; }
    }
    if Time::mono_ns() >= 0 { jout << "ok: the clock went forward\n"; }
    jout << "checksum: " << check << "\n";
}
```

```
ok: the clock went forward
checksum: 13500
```

> **Watch out:** The measured time changes every run, so never compare two versions with a single run. Always check the checksum to see that the answer has not changed.
**Exercises**
- Why choose the shortest time from several runs?
  - a) Because noise from the system makes some runs slower than they really are  b) Because short times are always wrong  c) Because you do not need to measure  — Answer: a. Other activity adds time, so the smallest value is a better picture of the work.
- The measured time is the same every time you run the program. — Answer: f. The time changes because the system does other work at the same time.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 4;
int b = a * 3;
jout << b << "\n";
}
```
  Output: `12`. 4 times 3 is 12. A value like this does not change with time.
- After you change code to make it faster, always check the ___ of the result. — Answer: **checksum**. A checksum shows the answer is still correct.
- Steps for making code faster: measure the old code → find the bottleneck → change it and check the answer → measure again and compare. You must know the bottleneck before changing code, and check the answer every time.
- Before you change code to make it faster, what should you do?
  - a) Measure the time and keep a reference answer  b) Delete the old code  c) Do not measure  — Answer: a. You need a reference to compare with.
**Tasks**
- **Time check** — Read Time::mono_ns twice and print done if the second reading is not less than the first. Output: `done`. Hint: Use if on the time difference
- **Reference answer** — Add 3 * i for i from 0 to 9 and print checksum 135. Output: `checksum 135`. Hint: 3 times 45 is 135
