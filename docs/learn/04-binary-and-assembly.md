# 4. Binary and assembly

The CPU only understands **machine code**: instructions as numbers. **Assembly** is the same instructions with names that a person can read. `jcmp` turns your J2K into assembly, then into machine code, and writes the executable.

## One line, three views
```jk
#import <stdlib>
int add3(int a, int b, int c) { return a + b + c; }
int main() { jout << add3(1, 2, 3) << "\n"; return 0; }
```
1. **Source:** `return a + b + c;`
2. **Assembly** (`jcmp prog.jk -show add3`, ARM64):
```
add x0, x0, x1        // x0 = a + b      (arguments come in x0, x1, x2)
add x0, x0, x2        // x0 = x0 + c     (the result goes back in x0)
ret                   // return to the caller
```
3. **Machine code:** each of these lines is 32 bits. `add x0, x0, x1` is the number `0x8B010000`. The assembler of `jcmp` (`jc_asm.j`) builds it from fields: the operation (`add`), the register that receives (5 bits), the two registers that are read (5 bits each).

## Reading ARM64 in five minutes
| you see | it means |
|---|---|
| `x0 .. x30` | 64-bit registers; `x0`-`x7` carry arguments, `x0` the result |
| `d0`, `s0` | a `double` / a `float` register |
| `ldr x1, [x2, #16]` | load: x1 = the 8 bytes at address x2 + 16 |
| `str x1, [x2]` | store x1 into memory at x2 |
| `add`, `sub`, `mul`, `lsl` | arithmetic; `lsl x0, x0, #3` multiplies by 8 |
| `cmp x0, x1` then `b.lt L` | compare, then jump to label L if less |
| `bl f` / `ret` | call function f / return |
| `x29`, `x30`, `sp` | frame pointer, return address, stack pointer |

## The stack
A function that calls another keeps its things in its **frame** on the stack: a block of memory just below the caller's. `sub sp, sp, #64` makes room, `add sp, sp, #64` gives it back. The return address is saved in the frame, which is why a recursion that never ends overflows the stack.

## See it yourself
```
jcmp prog.jk -show add3          # the code of one function and how many instructions it has
jcmp prog.jk -o prog -emit-asm prog.s   # the whole program as assembly text
```
Try a loop (`while i < n { s += i; i += 1; }`) and find the compare, the branch back and the registers. Then change `int` to `double` and see `fadd` instead of `add`.

## Going down on purpose
J2K lets you write a machine instruction yourself (`Cpu::inst`) and use vector registers (`f32x4`, `i8x16`): the tutorial lessons 76 to 82 build the number system, a gate-level adder, a tiny CPU with an assembler, and the encoding of ARM64 instructions step by step.

## Questions
1. Why does `-show` for a function that calls nothing have no `bl`?
2. How many bytes is a function of 12 instructions?
3. Find `cmp` and `b.` in the code of `sum_to` from chapter 2. What would change if the loop ran `n` down to 0?
