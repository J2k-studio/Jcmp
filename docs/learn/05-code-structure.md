# 5. Layers: the stack of a program

A computer is built in layers. Each layer uses only the one below and hides it from the one above. Knowing the layers tells you where to look when something is wrong.

## From electricity to your app
```
  your app            Jdesk: pages, buttons, notes
  libraries           canvas2d, net, neuron   (code you import)
  language            J2K: int, String, struct, arrays, threads
  compiler            jcmp: source -> tokens -> tree -> IR -> assembly -> machine code
  runtime             memory (alloc/free), arrays, strings, printing
  operating system    Android / Linux: files, network, processes, threads (syscalls)
  CPU and GPU         instructions, registers, caches, cores
  gates and wires     transistors, bits
```
A `jout << "hi"` goes down: the compiler turns it into calls of the runtime, the runtime fills a buffer and asks the system with a syscall (`write`), the system gives the bytes to the terminal, the screen lights pixels.

## What the compiler does with a file
1. **Lexer:** the text becomes tokens (words, numbers, signs).
2. **Parser:** the tokens become a tree (an expression `a + b * c` has `b * c` below `+`).
3. **Checks:** types and names are checked here; this is where `error:` lines come from.
4. **IR:** a small, simple language of operations on virtual registers; the optimiser works here (it removes repeated loads and dead code, keeps floats in registers).
5. **Assembly and machine code:** the IR is written as ARM64 and assembled into bytes.
6. **ELF file:** the bytes with a header that the system can run.
You can look at each step: `jcmp prog.jk -show f`, `-emit-asm`, `-irdbg 2097152` (the IR), `-irstat`.

## The layers of your own project
A project that stays easy to read has the same shape as the stack above: the parts that talk to the outside at the edge, the rules in the middle, small pieces at the bottom.
```
Jdesk/
  src/
    main.jk        the start: which page shows
    ui/            buttons, titles: the pieces every page uses
    pages/         one file for each screen
    notes/         one folder for each thing the app is about (the rules and its data)
    tasks/
    files/
  data/            what the app keeps
  assets/          pictures, sounds
  README.md        how to build and where things are
```
`makej init -apk` writes this for an app, `makej init -pro NAME` for a program. The rule: **a file imports only from below** (`pages` use `ui`, `ui` does not use `pages`); that keeps a change in one place from breaking ten others.

## Questions
1. Draw what happens when you press a key in a program that reads `jin >> x`.
2. Which layer reports "file not found"? Which layer would you fix if your program was slow only for big arrays?
3. In your project, which file would you read first to find where a button is drawn?
