# Programs without an operating system (raw mode)

A program for a board, for a kernel, or for the emulator `jemu --system` has no operating system under it: nobody opens files, hands out memory, prints text or ends the program for it. J2K can write such programs, and **the same words work**: `jout`, `jin`, `alloc`, `arr`, `String` and `Arena` run on a bare machine as they run on Linux, on top of a small lower layer (five calls) that `#target` fills with defaults and that you can write yourself. The core of the language knows no operating system, and the compiler never adds a hidden call, a hidden allocation or a hidden library to a program that does not use it.

This chapter is the guide to the raw mode. The words themselves are in `LANGUAGE.md` (`#!library`, `naked`, `register { }`, `raw<>`, `interrupt`, `frame`); the decisions are in `syntax-design.md` section 120.

## 1. Seven depths, and you choose the one you need

| depth | what you write | when |
|---|---|---|
| 1. ordinary code | `fn sum(int n) { ... }` | nearly everything: the compiler writes the machine code |
| 2. hardware in ordinary code | `char uart @ 0x09000000;`, `Cpu::wait()`, `interrupt fnv timer() { }` | a register of a device, waiting for an interrupt |
| 3. the start of the program | `#target`, `#start` | the machine has no start code: the compiler writes it |
| 4. instructions written like assignments | a `naked` function with `x0 = x0 + x1;` `ret;` | you want to choose the registers yourself: a task switch, a handler |
| 5. one instruction by name | `Cpu::inst("adr", x0, label);` | an instruction that the language has no word for |
| 6. the bytes | `raw<u32>[0xd503201f, ...]` | a table of vectors, an instruction the assembler does not know |
| 7. lines of assembly as they are | `asm { mov x0, 1  add x0, x0, x1  ret }` (also at file level) | you know the instructions and want no compiler between you and them; `#!asm` for a whole file is planned |

None of the depths 1 - 6 needs a marker at the top of the file: the low-level words are open in every file. A `#target` line (depth 3) or a `#!library` line makes the file a raw file: the compiler adds no start code of an operating system.

## 2. A first program

```jk
#target virt {
    entry 0x40000000;
    ram 0x40100000 1M;
    stack 64K;
    heap 64K;
    console 0x09000000;
    exit 0x09100000;
}
#import <os>

fn main() {
    Console::line("hello, machine");
    Console::num(6 * 7);
    Console::put(10);
    return 0;                       // written to the exit device
}
```

Compile it as any program: `jcmp prog.jk -o prog.elf`. The file is an ELF file that a loader reads (the emulator of Jaric: `jemu --system prog.elf`). With `format bin;` in the `#target` block the file is the bytes of the code only (a flash image for a board).

The compiler writes the start code: it sets the base of the global variables and the stack, makes the global area zero, stores the start values of the globals, calls `main`, and writes the result of `main` to the exit device. Then the CPU waits (`wfi`).

## 3. The `#target` line

Put it first in the file (before any name that it defines is used).

```
#target NAME {
    entry ADDRESS;            // where the file is loaded; a multiple of 64K. The first instruction is `b j2k_start`
    ram ADDRESS SIZE;         // the memory that can be written: the global area at its start, the stack at its end
    stack SIZE;               // the part of the RAM under its end that the stack uses (default 64K)
    heap SIZE;                // the part under the stack that alloc, arrays and String take their memory from (default 0)
    console ADDRESS;          // optional: the byte register that jout writes to
    input ADDRESS;            // optional: the UART that jin reads from (the data register; the flags are at +0x18)
    exit ADDRESS;             // optional: the register that gets the result of main
    format elf;               // elf (default) or bin (the bytes of the code only)
}
```

Numbers are decimal, `0x40000000` (also `0x4000_0000`) or with `K` / `M` (`64K`, `1M`). The RAM looks like this:

```
ram start   global variables (their start values are stored by the start code)
            ... free ...
            heap   (the TARGET_HEAP_SIZE bytes: alloc, arrays, String, <os> Pool and Heap)
            stack  (grows down from the end of the RAM)
ram end
```

The block gives the program these names: `TARGET_ENTRY`, `TARGET_RAM`, `TARGET_RAM_SIZE`, `TARGET_STACK`, `TARGET_STACK_TOP`, `TARGET_HEAP_START`, `TARGET_HEAP_SIZE`, `TARGET_CONSOLE`, `TARGET_EXIT`. The compiler stops with a message when the RAM is missing, when the stack and the heap do not fit in it, or when `entry` is not a multiple of 64K. The numbers come from the memory map of the machine (the data sheet of the board).

`main` is an ordinary function here (it returns to the start code). If a division by zero, an index out of range or a function that fell off its end happens, the machine ends with the code 254, 253 or 252 at the exit device.

## 4. `#start NAME`: where the program starts

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; console 0x09000000; exit 0x09100000; }
#start kernel_main

fnv kernel_main() {
    Console::line("started in kernel_main");
}
```

`#start` names the function that runs first (default: `main`). In a `#target` program the start code calls it; a function without a result ends the machine with 0. In a raw file without `#target` (`#!library`), `#start NAME` makes the first instruction `b NAME`, so the order of the functions in the file does not matter (without it the first instruction of the first function is the entry). A name that is not in the program is an error.

## 5. Variables at an address: the registers of the hardware

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; console 0x09000000; exit 0x09100000; }
int status @ 0x09200000;           // a 32-bit register of a device
char data @ TARGET_CONSOLE;        // a byte register

fn main() {
    data = 'A';                    // one write
    status |= 1 << 3;              // one read and one write
    while (status & 1) == 0 { }    // read again in every turn
    return 0;
}
```

`TYPE name @ ADDRESS;` places a variable at a fixed address. It takes no room in the global area. The width of the type is the width of the access: `char` is 8 bits, `i16` 16, `int` 32, `i64` 64 (also a pointer or a bool). **Every read and every write in the text is one access, made in that order**: the compiler never joins two reads, never leaves one out, never moves one over another and never repeats one (the accesses are `ldar` / `stlr` instructions that no pass of the compiler changes). The address must be a multiple of the size. A variable at an address has no start value, and a float or a struct at an address is not built yet.

## 6. Instructions of the CPU

* `Cpu::irq_off()` / `Cpu::irq_on()` (the interrupts of this core), `Cpu::irq_state()` / `Cpu::irq_restore(s)` (keep the state before `irq_off`, give it back after), `Cpu::read_sysreg(vbar_el1)` / `Cpu::write_sysreg(vbar_el1, table)` (the register is a word, the compiler writes `mrs` / `msr`).
* `Cpu::wait()` (`wfi`), `Cpu::event()`, `Cpu::send_event()`, `Cpu::nop()`, `Cpu::isb()`, `Cpu::counter()` (the system counter), `Cpu::id()` (the number of the core), `Cpu::speculation_barrier()`.
* `Atomic::`, `Cache::` (clean, invalidate, prefetch) and `Mem::barrier*()` are in the core library; they ask no system.
* The system registers of the CPU are names in the `Sys::` space: `Sys::vbar_el1 = x0;` writes the register `VBAR_EL1` (also `elr_el1`, `spsr_el1`, `esr_el1`, `far_el1`, `sp_el0`, `daif`, `mair_el1`, ... and the general form `s3_0_c12_c0_0`). They are statements of a `naked` function or a `register { }` block.
* `interrupt fnv timer() { }`: a handler that saves `x0` .. `x18` and ends with `eret`. The table of vectors is a `naked` function that you write (16 entries of 128 bytes, `align(2048)`); the kernels K1 - K7 of Jaric (`os/kernel`) show the whole path: exceptions, a timer, the MMU, tasks, user programs, a disk.

## 7. Depth 4 to 6: choosing the registers yourself

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; console 0x09000000; exit 0x09100000; }
#start kernel_main

naked i64 add_fast(i64 a, i64 b) {      // the arguments are x0 and x1, the result goes in x0
    x0 = x0 + x1;
    x0 = x0 << 1;
    ret;
}

fnv kernel_main() {
    Console::num(add_fast(20, 1));       // (20 + 1) * 2 = 42
    Console::put(10);
}
```

A `naked` function has no frame and no start or end that the compiler writes: you write `ret`. Inside it the registers `x0` .. `x30` are written as names and the statements read like assignments. `Cpu::inst("name", operands...)` writes one instruction by its name, and `raw<u32>[0x...]` writes the machine word. `LANGUAGE.md` has the full list (`register { }` blocks with `in` / `out`, `frame Context`, `@no_reorder`, `align(N)`).

## 7b. `asm { }`: the lines of assembly as they are

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; console 0x09000000; exit 0x09100000; }
#start kernel_main

naked i64 countdown(i64 n) {           // the sum n + (n - 1) + ... + 1
    asm {
        mov x1, 0
    again:
        add x1, x1, x0
        subs x0, x0, #1
        b.ne again
        mov x0, x1
        ret
    }
}

fnv kernel_main() {
    Console::num(countdown(10));        // 55
    Console::put(10);
}
```

Every line (or every part between `;`) of the block goes to the assembler as it is written; `//` starts a comment; labels are written `name:`; braces inside a line (`{v0.4s}`) are counted. The block can be inside a function (best a `naked` one: the compiler has no register of its own in it) or between functions (a table of vectors: `asm { .align 11  ... }`). A file that is only an `asm { }` block is a complete program with no runtime at all:

```jk
#!library
asm {
    mov x0, 7
    mov x8, 93
    svc 0
}
```

In an ordinary function use only `x0` .. `x15` and do not touch `sp`, `x28` or `x29`: the compiler keeps its variables there. The assembler knows the instructions that the compiler itself writes (about 190 names); one it does not know is an error that names the line, and `raw<u32>[...]` gives the machine word instead.

## 8. The layers: what the language does, what you can write, and `<os>`

A `#target` program is an ordinary program: **`jout`, `jin`, `alloc` / `free` / `alloc<int n>(50)`, dynamic arrays (`arr`, `push`), `String` and `Arena` work** as on Linux, and the same source runs on both. Under them is a lower layer of five calls that the runtime makes: *get a block of memory*, *write bytes*, *read bytes*, *give a block back* and *end*. `#target` gives each call a default (the heap line, the `console` register, the `input` register, nothing, the `exit` register). **You may write the lower layer yourself**: a function of the program with one of these names takes the place of the default:

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; heap 64K; exit 0x09100000; }
char uart @ 0x09000000;

fn os_write(i64 file, char^ buffer, i64 count) {      // jout, jerr and the panic message end here
    i64 i = 0;
    while i < count { uart = buffer[i]; i += 1; }
    return count;
}

fn main() {
    jout << "custom write " << 42 << "\n";
    return 0;
}
```

| function you may write | called when | gives |
|---|---|---|
| `os_write(file, buffer, count)` | the output buffer of `jout` / `jerr` is written | the count |
| `os_read(file, buffer, count)` | `jin` needs bytes | the number of bytes (0 at the end) |
| `os_map(address, length)` | the heap needs a new piece | the address of a block of zeros, or a negative number |
| `os_unmap(address, length)` | a big block is given back | 0 |
| `os_exit(code)` | the program ends | never returns |

The functions must not use `jout`, `jin`, `alloc` or `arr` themselves (they are the layer below those). They are the place to put a driver of your own (a UART with a ready flag, a memory manager of your own, a log in flash).

**`#import <os>` is the layer above**: services that you may use instead of `jout` and `alloc`, with nothing under them: `Console` (`put`, `print`, `line`, `num`, `hex` to the console register), `Heap` (`alloc` / `free` from a range of your own) and `Pool` (blocks in a row, all given back at once). Call a part by its name (`Console::line("x")`) or write `using Console;` and call it without the name (`line("x")`).

```jk
#target virt { entry 0x40000000; ram 0x40100000 1M; stack 64K; heap 64K; console 0x09000000; exit 0x09100000; }
#import <os>
using Console;

fn main() {
    line("hello");
    i64^ a = (i64^)Heap::alloc(80);       // 16-byte aligned, zeroed, null when nothing fits
    Heap::free((void^)a);
    return 0;
}
```

## 9. What is not there, and what the compiler says

| you write | what happens |
|---|---|
| a thread | error that names the function: the machine has one core and no scheduler (write the tasks in the kernel: `examples/os` of Jaric) |
| no `main` (or the name of `#start`) | error: a #target program needs a main function |
| a stack and a heap that do not fit in the RAM | error with the sizes |
| `jin` with no `input` line | reads nothing (the end of the input at once) |
| the heap is full | the runtime panics with "out of memory" (the message goes to `os_write`) |

Files, the network, the clock and `Env` are calls of an operating system: they answer "not implemented" (the lower layer does not have them). Fixed arrays (`int a[100];`), structs, pointers, loops, recursion, floating point, `switch`, methods and the whole language of the core work.

## 10. Testing

A program with a `#target` is tested in the emulator before a board: `jemu --system prog.elf` loads the ELF file, runs it on the machine of Jaric (UART at `0x09000000`, exit device at `0x09100000`, RAM from `0x40000000`), and its exit code is the result of `main`. The tests `K0`, `K0b` ... `K7` of Jaric (`os/kernel/test.sh`) run this way. A board needs the numbers of its own memory map in the `#target` block and `format bin;`.

The compiler makes ARM64 code for these programs. The ARM32 / Thumb-2 target of a board and x86_64 come later.
