# Learn from zero: one path, no jumping

This page answers "I have never programmed: where do I start and where do I go next?" It is one line of steps; every step says what to read and what to do. Every example compiles and runs on a phone. (Thai version: [LEARN.md](LEARN.md))

**Principles:** one idea at a time · say it in your own words · link it to real code · you do not have to read a whole book before you start · do not jump to SIMD or the matrix product before you understand memory.

## The path

| Step | Learn | Read | Do |
|---|---|---|---|
| 0 | Install and run the first file | [BASICS chapter 0](BASICS.md) | Write Hello and run `jcmp hello.jk -o hello && ./hello` |
| 1 | What a computer is and how it works | [book: Computers, the basics](book/basics_en.md) | The exercises at the end, a five-line summary |
| 2 | Programming: variables, conditions, loops, functions | [BASICS 1-9](BASICS.md), [book: Write programs](book/programs_en.md), [TUTORIAL lessons 1-23](TUTORIAL.md) | Every task at the end of a chapter |
| 3 | Data structures and algorithms | [book: Data structures](book/ds_en.md), TUTORIAL 141-143, 153-162 | Write a stack, a queue, a heap, a hash table yourself |
| 4 | The machine, memory and speed | [book: The machine and speed](book/machine_en.md), TUTORIAL 30-48, 91-110, 163 | Time a loop along rows against one down columns |
| 5 | English for programmers | [book: English](book/english_en.md) | Read error messages and documentation in English |
| 6 | The J2K language in depth | [book: jcmp](book/jcmp_en.md), [LANGUAGE](LANGUAGE.md), [COOKBOOK](COOKBOOK.md) | Build one small project |
| 7 | Deep subjects | [PERFORMANCE](PERFORMANCE.md), [TRAIN_AI](TRAIN_AI.md), [SIMD](SIMD.md), [GPU](GPU.md), [SYSTEMS](SYSTEMS.md), [INTEROP](INTEROP.md), [APP_PACKAGING](APP_PACKAGING.md) | Pick the one you like |

The map of all the computer science subjects, 0 to 100, is [CS_PATH](CS_PATH.md).

## The first 7 days (30 to 45 minutes a day)

Every day: read one short topic · write a five-line summary in your own words · do two thinking questions or one short piece of code.

| Day | Learn | Read |
|---|---|---|
| 1 | What a computer can do | the first chapter of the book: Computers, the basics |
| 2 | Bits and bytes | the chapters on binary numbers, letters and Unicode |
| 3 | Variables, arrays and addresses | BASICS 2 and 8, the chapter on addresses in the book: The machine and speed |
| 4 | Why RAM is slow, what a cache is | the cache chapter of the book: The machine and speed |
| 5 | Walking in order against jumping around | TUTORIAL 109 and 163 |
| 6 | ijk and the matrix product | TUTORIAL 97-101 |
| 7 | Review the week, write one page | your own summaries |

**Keep in your head:** the machine does simple things again and again · data is 0 and 1 · the CPU is fast, RAM is slow · data in good order is faster · GEMM is the matrix product · speed = less waiting for data + many values at once.

**Do not:** jump to SIMD or GEMM before memory · read several topics at once without a summary · learn words by heart without explaining them in your own words.

## If you like a game
The program `learnj` (`jc install learnj`) uses the same content as questions and exams in the terminal (you do not need it if you prefer to read).
