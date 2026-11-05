# Basics (english)

## What is a computer
**What it is.** A computer is a machine that takes in data, works on it by following a list of instructions, and gives back a result. It is fast and it repeats the same steps exactly every time, without getting tired. But it can only do what its instructions tell it to do.
**Why it matters.** Everything you use, a phone, a cash machine, a traffic light and a calculator, is a computer that follows instructions. When you understand that it only follows instructions, you understand why a program must be exact in every line.
**How to do it.**

A computer works in three steps: it takes input, it processes the data, and it gives output. Think of a calculator. You press 2, then plus, then 3, then equals. The input is 2 plus 3. The processing is the addition. The output is the 5 on the screen. The program below does the same cycle in code. The text printed by jout is the output.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 2;
    int b = 3;
    int sum = a + b;
    jout << "result " << sum << "\n";
}
```

```
result 5
```

> **Watch out:** People often think a computer understands what they want. It does not. It only follows the lines that were written. If the result is wrong, read the code line by line before you blame the machine.
**Exercises**
- How does a computer work, mainly?
  - a) It follows a list of instructions that a person wrote  b) It thinks and decides everything by itself  c) It guesses the best answer from the internet  — Answer: a. A computer has no understanding of its own. It moves through the instructions one step at a time. The cleverness we see comes from the instructions written by people.
- A computer can do things that no instruction has told it to do, by itself. — Answer: f. Without an instruction the computer does not know what to do. However fast it is, it cannot do work that was never told to it.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int x = 6;
jout << x * 7 << "\n";
}
```
  Output: `42`. 6 times 7 is 42. The computer runs the lines from top to bottom and nothing else.
- A computer works in three steps: it takes in input, it processes the data, and it sends out the ___. — Answer: **output**. Output is the result that leaves the machine. It is the opposite of input, which goes into the machine.
- The order of one round of work of a computer: take in the input → process it with the instructions → send out the result → wait for the next input. You need the input before you can process it, and you must process it before there is a result to send out.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << 10 - 4 * 2 << "\n";
}
```
  Output: `2`. Multiplication comes before subtraction, so 4 times 2 is 8 first. Then 10 minus 8 is 2. This is the same order as in school maths.
**Tasks**
- **Area of a rectangle** — Write a program that stores a width of 4 and a height of 5 in int variables, multiplies them and prints the text area followed by the area. Output: `area 20`. Hint: Use int w = 4; and jout << "area " << w * h << "\n";
- **Shopping** — Store a price of 25 and a quantity of 4 in variables and print the total as: total 100. Output: `total 100`. Hint: The total is the price times the quantity. Do not type the number 100 yourself.

## Hardware and software
**What it is.** Hardware is the part you can touch, such as the CPU, the RAM, the screen and the keyboard. Software is the set of instructions that is stored as data, such as a web browser, an operating system or a program you write yourself. Software has no body, but it needs hardware to run on.
**Why it matters.** If you want to buy, fix or build a computer, you must tell whether the problem is in the machine or in the program. A broken screen is a hardware problem. An app that freezes is usually a software problem. Programming means writing software that runs on hardware that already exists.
**How to do it.**

Check each part one by one. If you can hit it with a hammer, it is hardware. If you can delete it without breaking the machine, it is software. The program you write is software. The compiler is software. The file that the compiler makes is also software. All three run on the same CPU.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // this text is software: a program that the computer runs
    int speed = 3;
    int hours = 4;
    jout << "distance " << speed * hours << " km\n";
}
```

```
distance 12 km
```

> **Watch out:** People often call the whole machine a program, and then talks become confusing. Ask yourself: can I touch it? If not, and I can copy it or delete it, it is software.
**Exercises**
- Which of these is hardware?
  - a) The keyboard  b) A web browser  c) The J2K language  — Answer: a. A keyboard is a physical part that you can touch. A browser and a language are sets of instructions stored as data, so they are software.
- Software can run by itself, without any hardware. — Answer: f. Software is a set of instructions that the CPU must read and carry out. Without a machine it is only text on paper or on a disk.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int speed = 3;
jout << "km " << speed * 4 << "\n";
}
```
  Output: `km 12`. The code is software. It prints the result of 3 times 4, which is 12.
- The parts of a computer that you can touch are called ___. — Answer: **hardware**. Hardware is the metal, the silicon and the wires that you can see and touch. Software is the instructions stored inside them.
- Turning code that you wrote into a program that can run: write the code as a text file → compile it with jcmp → get a program file → run it on the CPU. Text code cannot run by itself. It must be turned into instructions that the machine understands first.
- A program on your phone freezes. Which problem is most likely to be checked first?
  - a) Software, for example an endless loop in the code  b) Hardware, for example broken RAM  c) The electricity in the house  — Answer: a. A freeze is usually a software problem. Still, first check that other programs work, to be sure the hardware is fine.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int n = 0;
n += 5;
n += 5;
jout << n << "\n";
}
```
  Output: `10`. The variable n starts at 0. It gets 5 added twice. Each change writes a new value over the old one.
**Tasks**
- **Counter** — Store 1 in the variable n, add 2 to it three times, and print the last value of n. Output: `7`. Hint: Use n += 2; three times. The start value is 1.

## The CPU: the part that follows instructions
**What it is.** The CPU (central processing unit) is the main processing part. It reads one instruction at a time from memory, works out what that instruction means, and then does it, for example an addition or a comparison. Its speed is measured in cycles per second, called hertz. But the amount of work done in one cycle matters just as much.
**Why it matters.** Every program you write becomes instructions for the CPU in the end. If you know what the CPU does in each cycle, you can understand why a long loop is slow, and why counting how many times something runs is important.
**How to do it.**

The CPU works in a repeating cycle: it fetches an instruction from memory, decodes it (works out what it means), executes it, and then moves on to the next instruction. The instructions the CPU understands are numbers in its own format. The compiler turns the J2K text into those numbers.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // each turn of this loop is a few CPU instructions: fetch, decode, execute
    int total = 0;
    for i in 1..5 {
        total += i;
    }
    jout << "sum " << total << "\n";
}
```

```
sum 10
```

> **Watch out:** A fast CPU does not make a program fast. A loop that runs a million times for no reason is still slow. Think about how many steps you need before you write the loop.
**Exercises**
- In which order does the CPU do the three steps of one instruction?
  - a) Fetch, decode, execute  b) Execute, fetch, decode  c) Decode, send out, fetch  — Answer: a. The CPU must fetch an instruction before it can decode it, and decode it before it can execute it.
- A CPU can always run many instructions at the same time in one cycle. — Answer: f. Some CPUs can do several things at once in some cases, but the next instruction often needs the result of the one before. So not everything runs at the same time.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int sum = 0;
for i in 1..4 { sum += i; }
jout << sum << "\n";
}
```
  Output: `6`. The loop 1..4 counts 1, 2 and 3. It does not include 4. The total is 6.
- The speed of a CPU, measured in cycles per second, is given in ___. — Answer: **hertz**. Hertz (Hz) means cycles per second. For example, 2 GHz means two thousand million cycles per second.
- The CPU does one instruction: fetch the instruction from memory → decode what it means → execute it → move on to the next instruction. The same order repeats for every instruction. If the first step does not happen, the rest have nothing to work on.
- Why is a loop that runs a million times slower than one formula?
  - a) Because the CPU must run the instructions of the loop again and again  b) Because the CPU sleeps during the loop  c) Because the letters in the code are too long  — Answer: a. Each turn of a loop really runs its instructions again. The more turns there are, the more instructions the CPU has to fetch and run.
**Tasks**
- **Count the sum** — Write a program that adds the numbers 1 to 100 with a for loop and prints the text sum followed by the total. Output: `sum 5050`. Hint: Use for k in 1..101 which means 1 up to 100
- **Even numbers** — Write a program that adds only the even numbers from 1 to 10 and prints even 30. Output: `even 30`. Hint: Use an if with % 2 == 0 inside the loop

## Memory (RAM)
**What it is.** RAM is the working memory. Every variable that a program uses is kept in RAM. Each cell has its own address, like a house number. When the computer is turned off, everything in RAM is lost. This is different from permanent storage, which keeps its data.
**Why it matters.** The CPU is much faster than RAM. If a program needs more RAM than is there, the system becomes very slow. Many crashes come from reading or writing a place in RAM that the program should not touch.
**How to do it.**

When you declare a variable, the system reserves a cell in RAM for it. When you change the value, the old value is written over. In J2K an int is 8 bytes, so one int that stores one number uses 8 bytes of RAM.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 10;
    int b = 20;
    a = a + b;
    jout << "a = " << a << ", b = " << b << "\n";
    jout << "one int takes " << sizeof(int) << " bytes\n";
}
```

```
a = 30, b = 20
one int takes 8 bytes
```

> **Watch out:** When you change a variable, you overwrite its old value, and the old value is gone. If you need to keep the old value, use a second variable.
**Exercises**
- When does the data in a variable disappear?
  - a) When the computer is turned off or the program ends  b) When you type the next line  c) It never disappears  — Answer: a. RAM is temporary memory that needs power. Data that must stay should go into permanent storage.
- RAM and the CPU are the same piece of hardware, so they are always equally fast. — Answer: f. The CPU is much faster than RAM. That is why CPUs have a small cache, a quick memory close to the CPU, for the data they use often.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int x = 4;
x = x * x;
x = x + 1;
jout << x << "\n";
}
```
  Output: `17`. x starts at 4, becomes 16, then 17. Each change writes over the old value in the same cell.
- When a variable gets a new value, the ___ value is written over and lost. — Answer: **old**. The old value is overwritten in the same cell, so it is lost.
- The life of one variable: declare int x → reserve a cell in RAM → give it the value 5 → read the value to print it. A cell must exist before a value can be stored. Then the value can be read.
- What is a byte?
  - a) A unit of size equal to 8 bits  b) The name of the CPU  c) The name of RAM  — Answer: a. A byte is a small unit that measures size. Each byte has eight bits.
**Tasks**
- **Overwrite** — The variable n starts at 3. Change it to n * 10 and print the value of n. Output: `30`. Hint: After the change, the old value 3 is gone.
- **Two variables** — Store 7 in a and 5 in b. Swap the values using a third variable tmp, and print a and b. Output: `a 5 b 7`. Hint: The first value must be kept before it is written over.

## Permanent storage
**What it is.** Permanent storage keeps data when the power is off. Examples are a hard disk, an SSD and the flash memory of a phone. The data is kept as files with names. It is slower to reach than RAM, but it holds much more.
**Why it matters.** Your documents, your photos and the programs you installed are kept in permanent storage. If a program must keep a result for tomorrow, it must write it to a file. Keeping it in a variable is not enough, because the variable disappears when the program stops.
**How to do it.**

Open the file with File::open and say the mode, Write or Read. Write with File::write and read with File::read_line. Close it with File::close every time. A file that is opened and never closed may not get all its data written to the disk.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    i32 f = File::open("note.txt", FileMode::Write);
    File::write(f, "saved on disk\n");
    File::close(f);
    char line[64];
    i32 g = File::open("note.txt", FileMode::Read);
    File::read_line(g, line);
    File::close(g);
    jout << line << "\n";
}
```

```
saved on disk
```

> **Watch out:** If you forget to close the file, or you open a file that does not exist for reading, you get no data. Check that the number from File::open is not less than 0.
**Exercises**
- Which of these is permanent storage?
  - a) A hard disk  b) RAM  c) The CPU  — Answer: a. A hard disk keeps data when the power is off. RAM and the CPU do not keep data when the computer is turned off.
- The data in a file is still there after you turn the computer off and on again. — Answer: t. The file was written to permanent storage. Keeping its data after power off is the main feature of permanent storage.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
char line[64];
i32 f = File::open("note.txt", FileMode::Write);
File::write(f, "hi\n");
File::close(f);
i32 g = File::open("note.txt", FileMode::Read);
File::read_line(g, line);
File::close(g);
jout << line << "\n";
}
```
  Output: `hi`. The text is written to the file and then read back on one line. No other value is mixed in.
- To keep data after the program stops, you must write it to a ___. — Answer: **file**. A file is a named piece of data on permanent storage.
- Writing one text file: open the file in Write mode → write the text → close the file → open it again to read. You must close the file after writing before you can read all of it.
- Why is permanent storage slower than RAM?
  - a) It reads from a disk or flash memory, which takes more time than RAM  b) It is old  c) It only keeps some bytes  — Answer: a. Permanent storage uses slower methods than RAM. That is why it can be much bigger and cheaper.
**Tasks**
- **Save a name** — Write a file name.txt that contains the text Ann, then read it back and print it. Output: `Ann`. Hint: Open with Write first, close it, then open with Read and read the line
- **Two lines** — Write a file ids.txt with the line 1 first and then the line 2. Read the first line back and print it. Output: `1`. Hint: File::write writes the first line first. read_line reads one line.

## Input and output
**What it is.** Input devices send data into the computer, such as a keyboard, a mouse, a microphone and a camera. Output devices send results out of the computer, such as a screen, a speaker and a printer. Some devices do both, such as a touch screen.
**Why it matters.** A program that cannot receive any input can only do fixed work, and a program that cannot send any output shows nothing to anyone. When you write a program, you must decide where the data comes in and where the result goes out.
**How to do it.**

Think in three boxes: where does the data come in, who handles it, and where does the result go out. In J2K, a program reads from the keyboard with jin, and it sends text out with jout. You will learn both in the section Write programs.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // output: the program sends text to the screen with jout
    int price = 25;
    int qty = 4;
    jout << "price " << price << "\n";
    jout << "total " << price * qty << "\n";
}
```

```
price 25
total 100
```

> **Watch out:** Do not think that printing to the screen saves the data. When the program stops, the screen output is gone. To keep it, write it to a file.
**Exercises**
- Which of these is an input device?
  - a) The keyboard  b) The speaker  c) The screen  — Answer: a. A keyboard sends the characters you type into the computer. A speaker and a screen receive results from the computer.
- A touch screen is both an input device and an output device. — Answer: t. A touch screen receives your touch as input and shows the picture as output on the same surface.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int a = 4;
int b = 5;
jout << "in " << a << " and " << b << "\n";
jout << "out " << a * b << "\n";
}
```
  Output: `in 4 and 5 / out 20`. The first line shows the values the program has got, and the second line shows the result it worked out.
- A device that shows the result to a person, such as a screen, is an ___ device. — Answer: **output**. An output device sends the result out of the computer.
- Getting a value from the keyboard into a program: a person types on the keyboard → the characters enter the computer → the program reads them with jin → the value is stored in a variable. The data from the person must go into the computer before the program can read it.
- What kind of device is a speaker?
  - a) Output  b) Input  c) Both  — Answer: a. A speaker gets a signal from the computer and makes sound. It does not get anything from the person.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << "a" << "b" << 3 << "\n";
}
```
  Output: `ab3`. When several values are joined with <<, each one is printed next to the last, with no space between them.
**Tasks**
- **Receipt** — An item costs 40 and two are bought. Print the line item 80 and then the line total 80, calculated from variables. Output: `item 80 / total 80`. Hint: The total is the price times the quantity. Use variables for both values.
- **Two lines** — Print A, then go to a new line, then print B. Output: `A / B`. Hint: Use \n to make a new line

## Data and programs
**What it is.** Data is the information that is stored, such as numbers, letters, pictures and sounds. A program is the set of instructions that says what to do with the data. The same data gives different results when the instructions are different. Data does nothing on its own. A program must read it.
**Why it matters.** When you understand that data and programs are different things, you know whether a wrong result comes from the instructions or from the data you typed in. For example, 42 is data, but multiplying it by 2 is the program.
**How to do it.**

Look at each value the program keeps. Numbers and text that are stored are data. The instructions that work with them are the program. Text in double quotes is text, not a number, until you change it with to_int.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    String text = "42";
    int n = text.to_int();
    jout << text + "!\n";
    jout << n + 1 << "\n";
}
```

```
42!
43
```

> **Watch out:** The text "42" and the number 42 are not the same. You cannot add 1 to the text in the same way, or you get a wrong result. Convert it first.
**Exercises**
- Which of these is data?
  - a) The number 42  b) The jout instruction  c) The main function  — Answer: a. The number 42 is a value that is kept. jout and main are instructions of the program.
- The meaning of data can change without changing the program. — Answer: f. The meaning of data depends on the program that reads it. If the program works differently, the result is different.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
String s = "7";
int n = s.to_int();
jout << n * 6 << "\n";
}
```
  Output: `42`. to_int changes the text 7 into the number 7, and then 7 times 6 is 42.
- Text that holds digits must be changed with the method ___ before you calculate with it. — Answer: **to_int**. to_int changes a String into a whole number.
- Using a number that is in text, in a calculation: get the text from the user → change it with to_int → calculate with the number → print the result. You must convert it first, before you can calculate with it.
- Why does one set of data give different results in two programs?
  - a) Because the instructions that use the data are different  b) Because the data changes by itself  c) Because the RAM changes  — Answer: a. Data does not act by itself. The difference comes from the instructions that work with it.
**Tasks**
- **Convert text** — Store "10" in a String, convert it to a number, and print the number times 3. Output: `30`. Hint: Use to_int and then multiply by 3
- **Mixed** — Store 7 as a number and "7" as text. Convert the text to a number and print the sum of both. Output: `14`. Hint: Convert the text first, then add it to the number

## Binary numbers and bits
**What it is.** All data in a computer is kept as binary numbers, which use only 0 and 1. One digit is called a bit. Eight bits make one byte. In binary, each place has a value of 1, 2, 4, 8, 16 and so on, and each value is double the one before. The number 13 is 1101 in binary, because 8 + 4 + 1 is 13.
**Why it matters.** Knowing binary helps you understand the limits of numbers. An int of 8 bytes has 64 bits. Reading a file of numbers, or debugging a problem with flags, also needs this knowledge.
**How to do it.**

To change a number to binary, divide it by 2 again and again and keep the remainder each time, until you get 0. Then read the remainders from the bottom to the top. In J2K, the operator >> moves the bits to the right, and & keeps only the bits that you want to look at.
**Example.**

```jk
#import <stdlib>
using stdlib;

void show_bits(int n) {
    String s = "";
    for i in 0..4 {
        s.push((char)(48 + ((n >> (3 - i)) & 1)));
    }
    jout << s << "\n";
}

void main() {
    show_bits(13);
    show_bits(5);
}
```

```
1101
0101
```

> **Watch out:** The numbers 0101 and 101 have the same value, because a zero in front does not change the number. When you show bits, decide how many digits you want and keep to it.
**Exercises**
- What is 1011 in binary, in decimal?
  - a) 11  b) 1011  c) 5  — Answer: a. 8 + 0 + 2 + 1 is 11. Each digit stands for a power of 2.
- A bit that has the value 1 in the fourth place from the right is worth 8. — Answer: t. The places from the right are worth 1, 2, 4 and 8, so the fourth place is worth 8.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << (6 & 3) << "\n";
}
```
  Output: `2`. 6 is 110 and 3 is 011. Only the place with the value 2 has a 1 in both numbers, so the answer is 2.
- The operator that moves the bits of a number to the right in J2K is written >> and is called a right ___. — Answer: **shift**. The >> operator shifts the bits to the right. Shifting one place right works like dividing by 2.
- Writing the number 5 in binary: divide by 2 and keep the remainder → repeat with the result until you get 0 → read the remainders from the bottom up → you get 101. The first remainder is always in the rightmost place, so you read the list from the end.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
jout << (1 << 3) << "\n";
}
```
  Output: `8`. Shifting left by one place is the same as multiplying by 2. Shifting left three times multiplies by 8.
- How many bits are in one byte?
  - a) 8  b) 4  c) 16  — Answer: a. A byte has eight bits, which can show the values from 0 to 255.
**Tasks**
- **Binary shift** — Write a program that shifts the value 10 one place to the right and prints the result. Output: `5`. Hint: 10 is 1010 in binary. Shifted right it is 101, which is 5.
- **Count bits** — Write a program that counts how many of the four bits of 13 are 1, and prints bits 3. Output: `bits 3`. Hint: 1101 has three 1s. Use a for loop and & 1 to count them.

## Letters and Unicode
**What it is.** A computer stores letters as numbers. The letter A has the code 65 and the letter a has the code 97. Unicode is a big table that gives a code to letters of almost every language in the world, including the Thai letter ก. In J2K, a String is kept as bytes in UTF-8, and some letters use more than one byte.
**Why it matters.** Without this, you might think that ก has a length of one, but the program says its length is three bytes. Counting length and cutting text must take into account whether you count bytes or letters.
**How to do it.**

Use (int)'A' to see the code of a letter, and (char) with a number to get the letter back. A single letter goes in single quotes, and text goes in double quotes. The .len of a String counts bytes, not the letters that a person sees.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    char c = 'A';
    jout << (int)c << "\n";
    String word = "Jao";
    jout << word.len << "\n";
    String th = "ก";
    jout << th.len << "\n";
}
```

```
65
3
3
```

> **Watch out:** One Thai letter uses more than one byte. So the length of "ก" is 3. If you cut text by bytes, you can break a letter in the middle and get broken characters.
**Exercises**
- What is the code of the letter A in the ASCII or Unicode table?
  - a) 65  b) 97  c) 1  — Answer: a. A is 65 and a is 97. They are different letters in the table.
- The text "ก" always has a length of one byte. — Answer: f. A Thai letter uses several bytes in UTF-8, so the length of ก is not 1.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
char c = 'B';
jout << (int)c << "\n";
}
```
  Output: `66`. B comes one place after A in the table, so it is 65 + 1, which is 66.
- The table that gives a code to the letters of all languages is called ___. — Answer: **unicode**. Unicode is the standard that gives codes to almost every letter in the world.
- Finding the code of the letter Z in a program: write the letter 'Z' → convert it to int with (int) → print the value → you get 90. A letter must be a number before its code can be shown.
- What is the code for the character '1' in ASCII?
  - a) It is not the value 1. It is the code 49  b) The number 1  c) The letter a  — Answer: a. The character '1' has the code 49. It is not the number 1. A programmer must keep these two apart.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
String w = "ab";
jout << w.len << "\n";
}
```
  Output: `2`. Each English letter uses one byte, so two letters make two bytes.
**Tasks**
- **Code of Z** — Print the code of the letter 'Z' using (int). Output: `90`. Hint: Z has the code 90 in ASCII
- **Length of Thai** — Print the length in bytes of the text "กา". Output: `6`. Hint: Each Thai letter here uses three bytes in UTF-8, so the total is six.

## The operating system
**What it is.** The operating system is the first large program that runs after the computer is switched on. It manages the CPU, the RAM, the storage and all devices, and it lets other programs ask for services through system calls. A program should not touch the hardware directly.
**Why it matters.** Each program gets its own part of RAM. It can open a file without knowing where the disk is, and it can use the network. All these jobs belong to the operating system. If you understand this, you know which services your program asks for.
**How to do it.**

When a program needs something from the machine, for example to read a file, it asks the operating system. It does not read the disk itself. In J2K, functions such as File::open and Env::get work by asking the operating system. The answer can be an Option, or a number that says the request failed.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // the operating system answers: a variable that is not set gives an empty Option
    Option<String> v = Env::get("J2K_SURELY_NOT_SET");
    if v.is_none() { jout << "no such variable\n"; }
    jout << "the program asked the system for it\n";
}
```

```
no such variable
the program asked the system for it
```

> **Watch out:** Do not assume a program can reach everything. The operating system has permission rules. If a program asks for something it may not use, the system refuses. Always check the answer.
**Exercises**
- What is the main job of the operating system?
  - a) To manage the devices and let programs ask for services  b) To write music  c) To change code into letters  — Answer: a. The operating system looks after the resources of the computer and stands between programs and the hardware.
- A program should always touch the hardware directly, to be as fast as possible. — Answer: f. The operating system shares resources safely. If a program touches the hardware directly, it can break the system or other programs.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
Option<String> v = Env::get("J2K_SURELY_NOT_SET");
jout << v.is_some() << "\n";
}
```
  Output: `false`. This variable is not set, so there is no value. is_some gives false.
- A request that a program makes to the operating system is called a system ___. — Answer: **call**. A system call is a request that enters the operating system.
- A program opens one file: the program calls File::open → the operating system opens the file on the disk → it returns a file number → the program reads or writes with that number. The program does not know where the disk is. It must wait until the system opens the file for it.
- Why can some files not be opened, even if the program is correct?
  - a) The operating system does not allow it, or the file does not exist  b) The CPU is bored  c) The letters are in Thai  — Answer: a. The operating system checks permissions and whether the file exists before it gives access.
**Tasks**
- **Missing variable** — Read the variable J2K_NOT_HERE with Env::get and print none if it is not set. Output: `none`. Hint: Use is_none() in an if
- **Ask twice** — Write a program that asks for the variable J2K_NOT_HERE twice, and counts the answers that are not set. Print the count. Output: `2`. Hint: Each request is a separate Env::get, and add one for each.

## Files and folders
**What it is.** A file is a piece of data with a name, kept on permanent storage. A folder is a place that holds files and smaller folders in a tree. A path tells where something is, from a starting point. For example, docs/plan.txt means the file plan.txt inside the folder docs.
**Why it matters.** Almost every program must know where to find its files. If the path is wrong by one character, the file cannot be opened. You must know both the file name and the folder it is in.
**How to do it.**

A path that does not start with a slash is a relative path. It starts from the folder where the program is running. In a program, you write the path as text, for example "docs/plan.txt", and pass it to File::open.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    String dir = "docs";
    String path = dir + "/" + "plan.txt";
    jout << path << " has " << path.len << " characters\n";
}
```

```
docs/plan.txt has 13 characters
```

> **Watch out:** File names can be case sensitive on many systems, so Plan.txt and plan.txt can be two different files. Write the name exactly, letter for letter.
**Exercises**
- What does the file path docs/plan.txt mean?
  - a) The file plan.txt inside the folder docs  b) The folder plan  c) The file docs inside plan.txt  — Answer: a. A path is read from left to right. The folders come first and the file name is at the end.
- A folder can hold files and smaller folders inside it. — Answer: t. Folders can be nested many levels deep, which helps you organise data.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
String a = "a";
String p = a + "/" + "b.txt";
jout << p << "\n";
}
```
  Output: `a/b.txt`. Joining text with the plus sign makes the path that is wanted.
- The position of a file, written as folder names and a file name in order, is called its ___. — Answer: **path**. A path, such as docs/plan.txt, tells where the file is.
- Finding the file docs/plan.txt: start in the folder where the program runs → go into the folder docs → look for the file plan.txt → open the file. The system must go into the folder first before it can find the file inside it.
- What stops a file from opening even though the program is correct?
  - a) A wrong spelling of one letter in the name  b) A variable  c) A for loop  — Answer: a. One wrong letter means the system cannot find the file. You must check every letter in the path.
**Tasks**
- **Join a path** — Build the path notes/day1.txt from the variable dir (notes) and the variable name (day1.txt), and print it. Output: `notes/day1.txt`. Hint: Join with + and "/"
- **Count the path** — Print the length of the path "src/main.jk". Output: `11`. Hint: Count every character, including the slash and the dot.

## Networks and the web
**What it is.** A network connects computers to one another. The internet is a network of networks around the world. Data is cut into packets. Each packet has a destination address (an IP address) and is sent over many links until it reaches the destination. A website uses the HTTP or HTTPS protocol to send its messages.
**Why it matters.** Almost every program today uses a network, whether it opens a web page, downloads a package or chats. If you understand that data travels in packets with addresses, you can understand delays and failed connections.
**How to do it.**

A URL such as http://example.com/a has three parts: the protocol (http), the host name (example.com) and the path on the server (/a). A program can split it: use find to get the place of :// and then use slice to cut the text.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    String url = "http://example.com/a";
    int at = url.find("://");
    jout << "protocol " << url.slice(0, at) << "\n";
    jout << "host and path " << url.slice(at + 3, url.len) << "\n";
}
```

```
protocol http
host and path example.com/a
```

> **Watch out:** find gives the position counted from 0. If you write at + 3 wrongly, you can cut one letter too many or too few from the host name.
**Exercises**
- What does the internet send data in?
  - a) Packets  b) One file that never ends  c) Single letters  — Answer: a. Data is cut into small pieces with destination addresses. Packets can take different routes.
- Every URL must have :// after the protocol. — Answer: t. The protocol and the host are separated by :// in the standard URL format.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
String u = "https://x.io/p";
jout << u.find("://") << "\n";
}
```
  Output: `5`. The letters h, t, t, p, s use the first five places. The :// starts at place 5, counting from 0.
- The system tells where a packet must go with an ___ address. — Answer: **ip**. An IP address is the address that the network uses to find the destination.
- Opening one web page: type the URL in the browser → find the IP address of the host → send an HTTP request → receive the reply and show it. You must know the destination before you can send the request, and you need the reply before you can show the page.
- What happens when a packet is lost on the way?
  - a) The protocol sends it again or reports the failure  b) All the data is lost forever  c) Everything comes back by itself  — Answer: a. Protocols such as TCP check and send again when needed. A program must still handle a failed connection.
**Tasks**
- **Protocol** — From the URL "https://site.org/x" print the protocol (the part before ://). Output: `https`. Hint: Use find, then slice(0, at)
- **Cut the path** — From "http://a.b/hello" print everything after the host, without the http part. Output: `a.b/hello`. Hint: Cut after ://

## How a program runs
**What it is.** The program you write is text. The compiler turns the text into a set of CPU instructions, a file that can run. The operating system then loads the file into RAM, sets it up and starts the CPU at main. The CPU runs the instructions one by one until the program ends or meets an error.
**Why it matters.** When a program crashes or is slow, you must know which level has the problem: a wrong text that the compiler refuses, an error that happens while the program runs, or slowness from a loop. Each level is different.
**How to do it.**

The steps are: write the code, compile it with jcmp, and run the file that was made. If the compiler accepts the code but the program is still wrong, the problem is in the logic of the code, not in the translation.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    // this file becomes machine instructions; the program starts at main
    for i in 1..4 {
        jout << "instruction " << i << " runs\n";
    }
}
```

```
instruction 1 runs
instruction 2 runs
instruction 3 runs
```

> **Watch out:** Some people run an old file without compiling again, and then think that their change has no effect. Compile every time after you change the code.
**Exercises**
- Can the CPU read J2K code written as text directly?
  - a) No. It must be changed into machine instructions first  b) Yes, always  c) Yes, if the RAM is on  — Answer: a. The CPU understands only machine code. The compiler translates the high-level language into that code.
- The operating system loads the program file into RAM before it runs. — Answer: t. The CPU fetches its instructions from RAM, so the program must be there first.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
for i in 1..3 { jout << i << "\n"; }
}
```
  Output: `1 / 2`. The loop for i in 1..3 gives 1 and 2. It stops before 3, as the language is set up to do.
- A compiled file that is ready to run is called an ___ file. — Answer: **executable**. An executable is a program file that the system can run.
- The steps after you write code until you see the result: compile with jcmp → run the file that was made → read the result → change the code if the result is wrong. You must compile again after each change, so that you see the real result.
- Which function does a J2K program start in?
  - a) main  b) jout  c) Env  — Answer: a. A J2K program always starts at main. Other functions are called from main or from each other.
**Tasks**
- **Countdown** — Write a program that prints the numbers 3, 2 and 1, one on each line. Output: `3 / 2 / 1`. Hint: Use a for loop that counts down from 3 with int i = 3; i > 0; i--
- **One line** — Print the text run ok and then a new line. Output: `run ok`. Hint: Use jout once

## Algorithms and bugs
**What it is.** An algorithm is a clear list of steps that solves one problem, can really be carried out, and finishes in the end. For example, a way to find the largest number in a group. A bug is a mistake in the code that makes the result different from what you want. Bugs often come from steps that are missing, or from counting one too many.
**Why it matters.** Languages change, but an algorithm can be thought out before you write any code. When you understand the way to solve a problem, you can see where a bug is in your idea, not only in the grammar.
**How to do it.**

First write the steps in plain words. Then test the steps with a small example, whose answer you can work out in your head. A very common bug is off-by-one: a loop that runs one time too few or one time too many, so it misses the last item or counts one twice.
**Example.**

```jk
#import <stdlib>
using stdlib;

void main() {
    int nums[5];
    nums[0] = 4; nums[1] = 9; nums[2] = 2; nums[3] = 7; nums[4] = 5;
    int best = nums[0];
    for i in 1..5 {
        if nums[i] > best { best = nums[i]; }
    }
    jout << "largest " << best << "\n";
}
```

```
largest 9
```

> **Watch out:** The loop for i in 0..4 does not look at the fifth item. If the largest number is at the end and your answer is wrong, check the edges of the loop first.
**Exercises**
- What is the minimum that a good algorithm must have?
  - a) Clear steps that finish  b) A very long code  c) A special language  — Answer: a. An algorithm is a set of steps that can be done and that does not run forever. Its length is not the rule.
- All bugs are caused by a broken computer. — Answer: f. Most bugs come from wrong steps or wrong code, not from the machine.
- Predict the output:

```jk
#import <stdlib>
using stdlib;

void main() {
int count = 0;
for i in 0..3 { count += 1; }
jout << count << "\n";
}
```
  Output: `3`. for i in 0..3 runs three times, for 0, 1 and 2, so the count is 3.
- A loop that runs one time too many or too few is an ___-by-one bug. — Answer: **off**. An off-by-one bug is a mistake at the edge of a loop.
- Good ways to fix a bug: repeat the problem until you see it every time → make the example smaller → work out the right answer by hand → fix the cause and test again. You must be able to repeat the bug before you find its cause, and you must test again after the fix.
- If a program gives a wrong result for a small input, what should you do first?
  - a) Print the values on the way and compare them with what you expected  b) Change the computer  c) Delete all the code  — Answer: a. Printing the values on the way shows you the first step where the program goes wrong.
**Tasks**
- **Count the items** — Write a program that counts the numbers in the array 2, 4, 6 and 8, then prints count 4. Output: `count 4`. Hint: Use the .len of the array
- **Find the largest** — In the array 3, 8, 1, 9, 4 find the largest value, and print max 9. Output: `max 9`. Hint: Start with the first item and loop from the second one
