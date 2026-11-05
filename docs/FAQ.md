# Questions and answers

**The compiler says "a variable cannot be called like a function".** You wrote `name(...)` where `name` is a variable. Call a function by its own name, or check that the type of a function-pointer variable is written `ret(params)^`.

**`String^` is rejected.** A `String` is already a handle to its text. Write `String s` to pass one (the function borrows it), or `char^` for raw bytes.

**A `String` field of a struct and `{ ... }`.** `Room r = {"Hall", 1};` works: the text becomes a `String` of the struct.

**Why is my loop slower than C?** Read [PERFORMANCE.md](PERFORMANCE.md): keep row offsets in local `int` variables, read numbers that do not change into a local before the loop, call no functions inside it, and use `float` arrays when `float` is enough. The plain dot-product form of a matrix product has a chain of adds and is slower than the row-update form; for training use `<neuron>`.

**Does the result change with `-novec` or `-nofma`?** The vector loops give the same numbers as the scalar loops. A fused multiply-add (`fmla`, `fmadd`) rounds once instead of twice, so the last digit can differ from a program built with `-nofma`.

**Where do I put a program that needs a library?** `#import <name>` at the top; libraries that are not part of the compiler come with `jc install NAME` and are found through `J2K_PATH`. See [BUILD.md](BUILD.md).

**How do I call J2K from C, Java or Python?** Make a shared library with `export` and `-l`; see [INTEROP.md](INTEROP.md). C links with `dlopen`.

**Where is the list of known faults?** The compiler's own notes list them; the ones that matter to a user are written in the guides where they apply.
