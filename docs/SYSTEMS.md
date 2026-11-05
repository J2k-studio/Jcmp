# Low-level programming: pointers, memory, the system, threads, atomics

J2K gives you the machine under the language, in small steps: a pointer is a number that is an address,
`Mem::` and `Sys::` are named calls to the heap and the kernel, and threads, atomics and `#multithread`
share the work. Every example here was compiled and run on the author's phone (ARM64, Termux,
2026-11-05). The lower layers (`device`, `register { }`, `abi`, `naked`) are in
[LANGUAGE.md](LANGUAGE.md); they need hardware or kernel code and were not run here.

## 1. Pointers

`T^` is a pointer to `T`, `@x` is the address of `x`, `p^` reads or writes what `p` points to, and
`p[i]` counts in elements (there is no `p + 1`).

```jk
#import <stdlib>
using stdlib;

int main() {
    int x = 10;
    int^ p = @x;
    p^ = p^ + 5;            // p^ is the value at the address
    int a[3];
    int^ q = @a;
    q[2] = 7;               // q[2] is the third element
    jout << x << " " << a[2] << "\n";
    return 0;
}
```

Output:

```
15 7
```

Pointers and numbers convert with casts: `(int)p` gives the address, `(char^)n` the pointer.
`void^` must be cast before use: `(int^)alloc(80)`.

## 2. The heap, and who frees it

`alloc(bytes)` gives a block of memory. A local variable that is declared from `alloc` or `arr` owns
the block, and the compiler frees it at every way out of the function. A function that returns the
block hands the ownership to its caller.

```jk
#import <stdlib>
using stdlib;

struct Node { int value; Node^ next; }

Node^ make(int v) {
    Node^ n = (Node^)alloc(sizeof(Node));   // returned: the caller owns it
    n^.value = v;
    return n;
}

int main() {
    Node^ a = make(41);                     // freed by the compiler at the end of main
    int^ tmp = (int^)alloc(80);             // freed too
    tmp[0] = 7;
    jout << a^.value + tmp[0] << "\n";
    return 0;
}
```

Output:

```
48
```

Ownership moves with `return p;`, `move(p)`, or a store into a field, an array or a global. Passing a
pointer to a function without `move` only lends it.

## 3. The bracket forms of `alloc` and `free`

`Mem::alloc(bytes)` and `Mem::free(p)` are the same heap called by name. The bracket forms are a shorter way to write `alloc` and `free`; `n` counts **elements**, not bytes.

```jk
#import <stdlib>
using stdlib;

int main() {
    alloc[int^ p = 4];                      // 4 ints; the compiler frees p at the end of main
    p[0] = 3;
    alloc[int^ pool = 8];                   // a pool of 8 ints
    alloc[pool[2] >> int^ a];               // 2 of them go to a
    a[0] = 9;
    jout << p[0] << " " << a[0] << "\n";
    free[a];                                // gives a's part back
    return 0;
}
```

Output:

```
3 9
```


## 4. `Sys::`: the kernel by name

`Sys` has one named function per system call (`open_read`, `open_write`, `read`, `write`, `close`,
`mmap`, `munmap`, `getpid`, `sleep_ms` and more). A call returns the kernel's answer, or a negative
number for an error. `Error::reason(n)` says the error in words.

```jk
#import <stdlib>
using stdlib;

int main() {
    int fd = Sys::open_write("sys_example.txt");
    Sys::write(fd, "hello\n".c(), 6);
    Sys::close(fd);
    jout << Error::reason(Sys::open_read("no_such_file_here")) << "\n";
    jout << (Sys::getpid() > 0) << "\n";
    return 0;
}
```

Output:

```
there is no file or folder with this name
true
```

`sys_example.txt` now holds `hello`.

### Memory from the kernel: `Sys::mmap`

`Sys::mmap(n)` gives `n` bytes of fresh zeroed memory straight from the kernel (null on failure);
`Sys::munmap(p, n)` gives it back. The address must be a multiple of 4096 (a page).

```jk
#import <stdlib>
using stdlib;

int main() {
    int^ big = (int^)Sys::mmap(4096);
    if big != null {
        big[5] = 99;
        jout << big[5] << " " << big[6] << "\n";     // a new page is zeroed
        Sys::munmap(big, 4096);
    }
    return 0;
}
```

Output:

```
99 0
```

A call that `Sys` lacks: `Sys::call(number, ...)`.

## 5. Threads and `#multithread`

`create(function, argument)` starts a thread and `join()` waits for it; the argument is a `void^`.
Each thread has its own stack; globals and the heap are shared. For a whole section that must run alone
use a `Mutex` (`lock()`, `unlock()`; see the example in LANGUAGE.md "Threads and locks").

`#multithread` before a `for i in a..b` loop shares its iterations among the cores (at most 16
parts). Each iteration must be independent; no `break`, `return` or nested `#multithread` inside.

```jk
#import <stdlib>
using stdlib;

int squares[1000];

int main() {
    int offset = 5;
    #multithread
    for i in 0..1000 {
        squares[i] = i * i + offset;
    }
    jout << squares[999] << "\n";
    return 0;
}
```

Output:

```
998006
```

## 6. Atomics

`Atomic::add`, `sub`, `swap`, `bit_and`, `bit_or`, `bit_xor` change a number in one step and return
the old value. `Atomic::cas(p, old, new)` changes it only if it is `old`, and returns the value it had.
`Atomic::load` and `Atomic::store` are the acquire and release forms. This is a spin lock built from them:

```jk
#import <stdlib>
#import <cpu>
using cpu::thread;

int lock;
int counter;

void bump(void^ arg) {
    for i in 0..500 {
        while Atomic::cas(@lock, 0, 1) != 0 { }    // spin until it was 0 and is now 1
        counter += 1;
        Atomic::store(@lock, 0);                   // release
    }
}

int main() {
    Thread t1 = create(bump, null);
    Thread t2 = create(bump, null);
    t1.join();
    t2.join();
    jout << counter << "\n";
    return 0;
}
```

Output:

```
1000
```

For a counter, `Atomic::add` is enough.

## 7. Jobs, tasks and channels

`<jobs>` runs many small jobs on several threads; the jobs are taken from a shared counter, so slow and
fast jobs balance by themselves. `<tasks>` runs one function on its own thread and gives its value back,
and `Channel<T>` is a queue between threads.

```jk
#import <stdlib>
#import <cpu>
#import <jobs>
using stdlib;
using cpu::thread;

int done;

void work(void^ arg) {
    Atomic::add(@done, 1);
}

int main() {
    Jobs::run(50, 4, work);                    // 50 jobs on 4 threads; returns when all are done
    jout << done << "\n";
    return 0;
}
```

Output:

```
50
```

```jk
#import <stdlib>
#import <cpu>
#import <tasks>
using stdlib;

int square(void^ arg) {
    int n = (int)arg;
    return n * n;
}

int main() {
    Task tk = Task::run(square, (void^)12);     // starts at once on a new thread
    jout << tk.wait() << "\n";
    Channel<int> c = Channel<int>::make();
    c.send(5);
    jout << c.receive() << "\n";
    return 0;
}
```

Output:

```
144
5
```

Tasks and jobs must not let an error leave their function; catch it inside. See [BUILD.md](BUILD.md)
for where the libraries are.

## See also

* [INTEROP.md](INTEROP.md): handing pointers to C, Python and Java
* [SIMD.md](SIMD.md): vector registers
* [LANGUAGE.md](LANGUAGE.md): the full rules and the low-level blocks
