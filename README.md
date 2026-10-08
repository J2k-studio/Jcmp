# J2K & Jcmp

**J2K** is a small systems programming language, designed from scratch and close to the machine.
**Jcmp** is its native compiler: it reads `.jk` / `.j` source and writes a Linux ARM64 executable
directly (its own assembler and ELF writer — no LLVM, no GCC, no `as`, no `ld`).

The compiler is **written in J2K itself** and builds itself (self-hosting).
Everything was developed on a phone (ARM64, Termux).

```jk
// hello.jk
void main() {
    cout << "Hello from J2K!\n";
}
```

```console
$ bin/jcmp examples/hello.jk -o hello
$ ./hello
Hello from J2K!
```

> [ภาษาไทย → README.th.md](README.th.md)

---

## Status

| Component                                   | State |
|---------------------------------------------|-------|
| Compiler written in J2K (`jcmp/`)           | **Working, self-hosting** (two generations are identical, byte for byte) |
| Assembler written in J2K (`jcmp/jc_asm.j`)  | Working, built into the compiler |
| Language                                    | Integers (`i8 i32 int char bool`, unsigned `u8 u32 u64`), floats (`f32 f64`), arrays (up to 3 dimensions), pointers (`T^`, `T^^`), function pointers, structs with methods, enums, `switch`, `for`/`while`, `try`/`catch`, `sizeof`, dynamic arrays (`T[]`), strings, `#define`, imports |
| Standard library (`std/`)                   | `Sys`, `Mem` (heap), `Str`, `Math`, `File` |
| Diagnostics                                 | `file:line:col: error/warning:` with the source line and `^`; `-st` makes warnings errors |
| Debug build (`-d`)                          | array bounds checks |
| Errors                                      | `try` / `catch` / `throw` with text |
| Memory                                      | `alloc`/`free`, dynamic arrays, automatic freeing of owned memory at the end of a block |
| Not done yet                                | `cin`, threads/`Mutex`, optimisation |
| Target                                      | Linux **ARM64** only |

The test suite passes (more than 160 programs with the J2K compiler).
Release history: [CHANGELOG.md](CHANGELOG.md).

---

## Install

You need a Linux **ARM64** machine (a phone with Termux works) and `curl` or `wget`
(Termux: `pkg install curl wget`). The compiler is a single file, published as a
[release](https://github.com/J2k-studio/Jcmp/releases).

**One line** (downloads the latest release, checks its SHA-256, installs `jcmp` into `$PREFIX/bin` on
Termux or `~/.local/bin` elsewhere):

```bash
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
# or
wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
```

**By hand** (to see exactly what you get):

```bash
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp-linux-arm64
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS          # must say: jcmp-linux-arm64: OK
chmod +x jcmp-linux-arm64
mv jcmp-linux-arm64 ~/.local/bin/jcmp              # any folder on your PATH
# wget works the same:  wget https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp-linux-arm64
```

A specific version: replace `latest/download` with `download/v0.1.0`
(`JCMP_VERSION=0.1.0` for `install.sh`). The bundle `jcmp-<version>-linux-arm64.tar.gz` holds
the compiler, the assembler, the examples and the docs:

```bash
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp-0.1.0-linux-arm64.tar.gz
tar -xzf jcmp-0.1.0-linux-arm64.tar.gz
```

Check it works:

```bash
jcmp --version                       # jcmp 0.1.0 (J2K compiler, Linux ARM64)
printf 'void main() { cout << "hi\\n"; }\n' > hi.jk
jcmp hi.jk -o hi && ./hi
```

**From the source repository** (to read or rebuild the compiler; it contains a ready `bin/jcmp`):

```bash
git clone https://github.com/J2k-studio/Jcmp.git
cd Jcmp
bin/jcmp examples/fib.jk -o fib && ./fib
./bootstrap.sh                       # rebuild the compiler with itself
```

If the repository or its releases are private, `curl`/`wget` need a token
(`curl -fL -H "Authorization: Bearer $TOKEN" ...`) or use `gh release download`.

More: [docs/USAGE.md](docs/USAGE.md) (command line, building, testing) and
[docs/LANGUAGE.md](docs/LANGUAGE.md) (a tour of the language).

---

## The language in one screen

```jk
import std                      // the standard library: Sys, Mem, Str, Math, File
using std::math

enum class Color { Red, Green, Blue };

struct Point {
    f64 x;
    f64 y;
    f64 length(self) { return sqrt(self.x * self.x + self.y * self.y); }
}

int sum(int a[]) {              // arrays arrive with their length: a.len
    int total = 0;
    for i in 0..a.len { total += a[i]; }
    return total;
}

void main() {
    int numbers[4];
    for i in 0..4 { numbers[i] = i * 10; }
    cout << "sum = " << sum(numbers) << "\n";

    Point p = {3.0, 4.0};
    coutf << "length = " << p.length() << "\n";     // 5.000000

    Color c = Color::Green;
    switch c {
        Color::Red: cout << "red\n";
        Color::Green: cout << "green\n";
        _: cout << "other\n";
    }
}
```

Design goals: **fast and close to the CPU** (values live in registers, struct layout like C,
arithmetic at register width), **strict where it prevents bugs** (a `bool` is not an `int`,
an enum is not a number, `int` and `float` do not mix without a cast), **no hidden magic**
(no garbage collector, no pointer arithmetic — use `p[i]`).

---

## Repository layout

```
Jcmp/
├── README.md, README.th.md, LICENSE, VERSION, CHANGELOG.md
├── install.sh            download + check + install the latest release
├── release.sh            builds the release files into dist/ (for the maintainer)
├── bin/                  the compiler and assembler binaries (built by themselves)
│   ├── jcmp              the compiler (J2K -> ARM64 ELF)
│   └── j2k_asm_j2k       the stand-alone assembler (.jasm -> ELF)
├── jcmp/                 the compiler's own source, in J2K
│   ├── jcmp.jk             entry point (main, command line)
│   ├── jc_base.j  jc_lex.j  jc_expr.j  jc_stmt.j   the four parts
│   ├── jc_asm.j            the assembler (a library)
│   └── jc_std.j            generated from std/ by gen_std.sh
├── std/                  the standard library (J2K): sys, mem, str, math, fs
├── examples/             small programs
├── test/                 the test programs (+ expected output in .out / .warn files)
├── docs/                 language specification and guides
│   ├── syntax-design.md    the language specification (decisions are recorded here)
│   └── LANGUAGE.md  USAGE.md
├── j2k_asm.jk            command-line wrapper of the assembler
├── bootstrap.sh          rebuild the compiler with itself and compare
├── bootstrap-from-binary.sh   the short version of the same check
├── run_all_tests.sh      the test suite
└── gen_std.sh            std/*.j -> jcmp/jc_std.j
```

---

## How it was built (bootstrapping)

The first assembler and compiler were hand-written in ARM64 assembly. The assembler was then
rewritten in J2K, then the compiler, in four parts. Today the compiler compiles itself:
`bootstrap.sh` starts from the committed `bin/jcmp`, builds three generations and checks that
the last two are byte-for-byte identical. The assembly versions are no longer part of this
repository.

---

## License

This project is **proprietary, source-available**: you may read it and run it for personal study
and non-commercial use; you may not copy it, redistribute it, or claim it as your own.
See [LICENSE](LICENSE) for the full terms (English + Thai summary).

## Author

**Jao** (J2k-studio) — Thailand. Contact for permission requests: the GitHub profile **J2k-studio**.
The project is developed by a single author; outside contributions are not accepted at this stage.
