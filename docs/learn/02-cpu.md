# 2. The CPU

The CPU does one small thing, billions of times a second: **fetch** an instruction from memory, **decode** it, **execute** it. An instruction is a number (a few bytes) such as "add the number in register 1 to the number in register 2 and put the result in register 3".

## Registers
A **register** is a tiny memory inside the CPU, as fast as the arithmetic itself. The phone's ARM64 CPU has 31 general registers of 64 bits (`x0` to `x30`) and 32 for decimals and vectors (`d0`, `s0`, `v0`). A program is fast when its busy numbers stay in registers and slow when it keeps going back to memory.

## Memory is far away
Reading memory takes time. The CPU keeps copies of recent bytes in **caches**: level 1 (about 32 KB, a few cycles), level 2, level 3, then the RAM (hundreds of cycles). A loop over an array in order is fast because each cache line (64 bytes) brings the next numbers too; jumping around in memory is slow.

## Cores and threads
The Kirin 990 of the example phone has 8 cores: two big and two medium ones (fast) and four small ones (saving power). A **thread** is one sequence of instructions; the system puts threads on cores. Two threads that write the same variable need a lock or an atomic instruction (`Mutex`, `Atomic`).

## Pipelines and branches
The CPU starts the next instructions before the first one is done (a pipeline), and guesses which way an `if` goes. A wrong guess costs about 15 cycles. That is why a loop that does the same thing every time is fast and a loop with an unpredictable `if` is slow.

## Seeing it
```jk
#import <stdlib>
int sum_to(int n) {
    int s = 0;
    for i in 0..n { s += i; }
    return s;
}
int main() { jout << sum_to(100) << "\n"; return 0; }
```
Run `jcmp prog.jk -show sum_to` and read the instructions: the loop is a few lines, `s` and `i` live in registers, `add` and `cmp` and a branch. Chapter 4 explains each one.

## Questions
1. Why is summing an array of 1 million numbers about 5 times faster in a row than with random indexes?
2. What is faster: a `double` multiply or a `double` divide? (Try it with a loop and `Time::now_ms()`.)
3. The phone has 8 cores. Why does a program with 8 threads not run 8 times faster?
