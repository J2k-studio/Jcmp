# A computer science course in J2K: depth 0 to 100

This page maps the usual subjects of a computer science course to the lessons of this repository, so that you can learn the subject *and* the language together. Every lesson is a small program that compiles and runs on a phone. Lesson numbers are those of [TUTORIAL.md](TUTORIAL.md); `B0`..`B9` are the chapters of [BASICS.md](BASICS.md).

| depth | what you understand | where |
|---|---|---|
| 0 - 20 | you can write programs | B0-B9, lessons 1-23, 151-154 |
| 21 - 40 | you can choose a data structure and an algorithm | lessons 14-16, 141-143, 155-162 |
| 41 - 60 | you know how the machine and the OS work | lessons 30-48, 76-83, 163 |
| 61 - 80 | you can design a system and make it fast | lessons 57-75, 84-90, 91-150 |
| 81 - 100 | you can build a low-level tool or a new system | lessons 45-48, 80-82, [ARCHITECTURE.md](ARCHITECTURE.md), the Jaric OS parts |

## The nine subjects

**1. Thinking like a computer** (problem solving, logic, Big-O, correct or wrong algorithms): lesson 155 (counting steps), 132 (a test for your own function), 154 (debugging by looking).

**2. Programming** (variables, conditions, loops, functions, data structures, program design): B0-B9, lessons 1-13, 131, 146-148.

**3. Data structures and algorithms** (array, list, stack, queue, tree, graph, hash; search, sort, graph, DP; time and memory): lesson 15 (lists, maps, sets), 143 (sorting with your own comparison), 141 (heap), 142 (hash map), 153 (binary search), 156 (stack), 157 (queue), 158 (search tree), 159 (graph and BFS), 160 (dynamic programming), 161 (hash table from scratch), 162 (two sorts counted).

**4. Computer systems** (binary, CPU, memory, cache, assembly, compilers): lessons 76-82 (base 2, two's complement, logic gates, a tiny CPU, an assembler), 30 (bits), 32 (the code the compiler made), 35-48 (registers, flags, raw instructions), 163 (the cache), 109 (cache in the matrix product), [ARCHITECTURE.md](ARCHITECTURE.md) (how this compiler is built).

**5. Operating systems** (process and thread, memory, file system, scheduling, concurrency): lessons 34 (threads and atomics), 40 (talking to the kernel), 41 (your own allocator), 42 (a spinlock), 45 (two tasks, two stacks: a context switch), 46 (a queue without a lock), 19 and 29 (files and paths). Scheduling and a file system from scratch are *not yet written*.

**6. Networks** (TCP/IP, HTTP, client and server, delay and bandwidth): lessons 67-69 (the web, bots, WebSocket), [INTEROP.md](INTEROP.md). A lesson on sockets from the start and on delay/bandwidth is *not yet written*.

**7. Databases** (data models, queries, transactions, indexes): lessons 26-27 (JSON, CSV), 142 (a hash map is an index). A small database engine (a table, an index, a transaction log) is *not yet written*.

**8. Software engineering** (design, tests, versions, code quality): lessons 20 and 131 (several files), 132 (tests), 57 (a build file), 75 (packages), [CONTRIBUTING.md](CONTRIBUTING.md), [STYLE.md](STYLE.md).

**9. Deep subjects**
* AI / ML: lessons 70-73 and 111-130, [TRAIN_AI.md](TRAIN_AI.md).
* Graphics and games: lessons 62-66, 84, 88, 145, [GPU.md](GPU.md).
* Security: lessons 28 and 89 (hashes, keys). A lesson on safe programming is *not yet written*.
* Compilers: lessons 32, 139-140 (a tokenizer and a recursive-descent calculator), [ARCHITECTURE.md](ARCHITECTURE.md).
* Embedded and systems: lessons 35-48, [SYSTEMS.md](SYSTEMS.md), [SIMD.md](SIMD.md).
* Distributed systems: *not yet written*.

## Speed, step by step (the matrix product as a course)

The matrix product is the best single program to learn how a computer works, because every level of the machine shows in it. Read these in order: 97 (the plain form), 98 (why the chain of adds is slow), 99 (four accumulators), 100 (four columns at once with a vector), 101 (a 4 x 8 register block), 109 (the order of the loops and the cache), 102 (threads), 110 (comparing with C fairly), 130 (why a neural network is a matrix product), and [PERFORMANCE.md](PERFORMANCE.md).

Measured on one phone (384 x 384, float32, the loop orders against C -O2, noisy): the orders whose inner loop walks along a row (`ikj`, `kij`) run as fast as C or faster; the dot-product orders (`ijk`, `jik`) are 1.5 to 2 times slower than C and are the next thing the compiler has to fix. The 4 x 8 kernel of `<neuron>` runs 14 GFLOPS on one core, the same as a C program written with the same NEON instructions.

## What is missing, in the order I would write it
1. Scheduling and a tiny file system (OS, depth 41-60).
2. Sockets from scratch, latency and bandwidth (networks).
3. A small database: table, index, log (databases).
4. Safe programming: buffer limits, input checking (security).
5. A distributed system: two processes, a message, a failure (depth 81-100).
