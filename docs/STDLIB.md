# The standard library in categories

`#import <stdlib>` reads everything below (unused functions are left out of the program). A category reads only its own part
and what that part needs, so a small program is compiled with less text:

```jk
#import <text>
#import <data>          // Map, Set, Queue ... (also reads core, number and text)
```

| category | what it holds | needs |
|---|---|---|
| `core` | `Sys` (system calls), `Option`, `Result`, `Error`, `ErrorKind`; the memory routines (`Mem`, dynamic arrays, `String`) are always there | - |
| `number` | `Math` (functions of numbers, constants), `Num` (numbers from text) | core |
| `text` | `Str` (0-terminated text), `Hex`, `Base64` | core |
| `files` | `File`, `Fs` (whole files, `Result`), `Dir` (folders), `Path` | core, text |
| `system` | `Env` (arguments, environment), `Proc` (run a program), `Term` (the terminal) | core, text |
| `time` | `Time` (clock, sleep), `Random` | core |
| `data` | `Map`, `Set`, `Queue`, `Deque`, `Heap`, `Span`, `Json`, `JsonDoc` | core, number, text |
| `crypto` | `Sha256` | core, text, files |

Other libraries are named as before: `#import <math>` (`vector`, `matrix`, `quat`, `complex`, `stats`: chosen with
`using math::vector;`), `<gfx>` (`canvas`, `screen`), `<cpu>` (threads), `<simd>`.

`Sys::name` is a system register when `Sys` has no function of that name; `Sys::write(...)` calls the function.
