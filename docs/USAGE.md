# Using Jcmp

## Compile and run

```bash
bin/jcmp program.jk -o program      # source -> executable (one step)
./program
```

Requirements: Linux **ARM64** (a phone with Termux works). Nothing else: the assembler
and the ELF writer are inside the compiler.

### Command line

```
jcmp input.jk [-o output] [-d] [-st] [-I dir] [--emit-asm file.jasm]
jcmp input.jk output                    (the second name is the program; if it ends in .jasm only the assembler text is written)
```

| Option | Meaning |
|--------|---------|
| `-o file`          | write the ARM64 executable; without `-o` it is named like the source without `.jk` / `.j`, in the current folder (`jcmp test.jk` makes `test`). `-o folder/` (or an existing folder) puts it there with that name: `jcmp sub/test.jk -o sub/` makes `sub/test` |
| `--emit-asm file`  | also (or only) write the assembler text, to read what the compiler generated |
| `-color` / `-nocolor` | coloured messages (errors red, warnings yellow); the default is on when the messages go to a terminal |
| `-st`              | strict: every warning becomes an error |
| `-I dir`           | where `#import "name"` also looks (after the folder of the importing file) |
| `-version`, `-help` | print the version / a short list of the options (one or two dashes: `--version`; also `-v`, `-h`) |
| `-d`               | debug build: array index checks. A bad index prints `runtime error: index out of bounds, array size is N` and the program exits with code 134 |

Exit code of `jcmp`: 0 = success (warnings may have been printed), 1 = error.
The generated programs exit with the value returned by `main` (or `Sys::exit(n)`).

### Assembler on its own

`bin/j2k_asm_j2k text.jasm output` turns assembler text into an executable
(the same assembler that is inside `jcmp`).

## Rebuild the compiler with itself

```bash
./bootstrap.sh
```

Stage 0 is the committed `bin/jcmp`; it compiles `jcmp/jcmp.jk` into `jcmp1`, `jcmp1`
compiles it into `jcmp2`, `jcmp2` into `jcmp3`. Success means `jcmp2` and `jcmp3` are
byte-for-byte identical. The script then builds every test program with `jcmp3` and with the
old assembly compiler and checks that they behave the same.

```bash
./bootstrap-from-binary.sh          # the short check: stage1 == stage2 == bin/jcmp
cp _test_out/boot/jcmp3 bin/jcmp    # after a change that you want to keep as the new starting point
```

After editing `std/*.j` run `./gen_std.sh` first (it regenerates `jcmp/jc_std.j`).
The assembler binary is rebuilt with `bin/jcmp j2k_asm.jk -o bin/j2k_asm_j2k`.

The compiler is always rebuilt from the committed binary `bin/jcmp` (the very first compiler, written
in assembly, is not part of this repository).

## Examples

```bash
for e in hello fib shapes heap; do bin/jcmp examples/$e.jk -o /tmp/$e && /tmp/$e; done
```

## The standard library

`#import <stdlib>` puts the library in front of your program; `using stdlib` lets you call its functions without the prefix
(or only one module: `using stdlib::mem`, `str`, `sys`, `math`, `fs`). `cout` and `cin` need `#import <stdlib>` and `using stdlib`. Its source is `std/*.j`.
See [LANGUAGE.md](LANGUAGE.md).

### Where the library lives, and `jcmp -update`
The library is not inside the `jcmp` file: it is the folder `Library/` (one file for each part: `net.j`, `text.j` ...; `jcmp -showlib net` writes one), published and
installed together with the compiler. The compiler looks for it in the folder named in `JCMP_LIB`, then `Library` next to `jcmp`, then `../Library/jcmp` and `../Library` next to it. The compiler and its library are a **pair**:
`Library/VERSION` must be the version of the compiler, or the compiler stops and tells you to install them again; when the folder is missing the compiler says so. `#import <net>` is a library of the language;
`#import "dir/file.jk"` is your own file.
`jcmp -update` replaces the compiler and its library together with the latest release (`jcmp -update 0.9.176` for a given one);
`install.sh` installs the library files with the compiler.

### `jget`: data from the web, and libraries (version 0)
`jget -h URL` fetches the data at an address (http, https, ftp, file) and writes it to the screen; `jget -h URL -o FILE` writes it to a file (a bare `jget URL` does the same). An `http://` address is fetched by `jget` itself (it looks the name up with DNS and speaks HTTP/1.1, redirects and chunked answers included); `https://` and other addresses use `curl`, or `wget` when there is no `curl` (jget has no TLS yet).
`jget -li list` shows the libraries of the index, `jget -li install NAME` downloads one, checks its SHA-256 against the index and puts it in `~/.j2k/Library/NAME.j`, where
`#import <NAME>` finds it; `jget -li uninstall NAME` deletes it, `jget -li installed` lists the folder. The libraries of the standard set (`cpu`, `net`, `math` ...) come with the compiler and need no install. `JGET_INDEX` names another index (an address or a `file://` path), `JGET_LIB` another folder.
The index is a text file with a line `NAME VERSION URL SHA256` for each library. The source of `jget` is `examples/jget.jk`. The project index is not published yet, so set `JGET_INDEX` to an index of your own for now.

### `-cache DIR` (experimental)
`jcmp prog.jk -cache build/cache` keeps the final code of every function in the folder `build/cache` and uses it the next time for the functions that did not change
(and for everything that they call); only the changed functions go through the optimiser and the register pass again. The program is the same, byte for byte, as without
`-cache`. The key of a function includes the version of the compiler and the options, so an old cache is never used by another compiler or other options. The folder can
be deleted at any time. This saves about a third of the time for big programs (the compiler itself: 11.7 s to 7.9 s); small programs do not need it.

## Should the documentation be a website?

Markdown files are shown nicely by GitHub, and `README.md` is the front page. A website
(GitHub Pages built from `docs/`) is worth doing later, when the language settles.

## Limits of the compiler

| What | Limit |
|------|-------|
| local variables in one function | 8,192 |
| global variables / functions | 16,384 each |
| struct types / enum types | 64 / 64 (the type codes share one number space) |
| struct fields (all structs) / enum members (all enums) | 8,192 each |
| `#define` names / imported files | 2,048 / 512 |
| parameters of a function / arguments of a call | 16 |
| array dimensions / pointer levels (`T^^`) | 3 / 2 |
| source file size | 512 KB per file, imports nested 15 deep |
| name length | 63 characters |
| program size | 8 MB of generated assembler text |

A program that reaches a limit gets a clear `error: too many ...` message.
