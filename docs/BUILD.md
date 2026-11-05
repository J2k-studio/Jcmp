# Building projects, libraries and versions

This guide covers the build tool `makej`, where the compiler finds libraries, the `jc` command
for installing libraries and tools, the version numbers, and the compile cache. Everything marked
"run" was run on the author's phone (Termux, 2026-11-05, compiler 1.2.13.0, makej 0.11.0).

## 1. A project with `makej`

`makej` reads a file called `makej` in the project folder. Each `[program.NAME]` is a program
built from its `main` file, each `[library.NAME]` a shared library (`-l`), each `[step.NAME]` a shell
command. `needs` lists what must be built first.

```
proj/
  makej
  src/hello.jk
  src/tool.jk
  core/core.jk
```

`src/hello.jk`:

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "hello\n";
}
```

`src/tool.jk`:

```jk
#import <stdlib>
using stdlib;

int main() {
    int t = 0;
    for i in 0..10 { t += i; }
    jout << "tool sum " << t << "\n";
    return 0;
}
```

`core/core.jk` (a library, no `main`):

```jk
export int twice(int x) { return x * 2; }
```

`makej` (the build file, a small TOML):

```
[makej]
out = "_out"

[program.hello]
main = "src/hello.jk"

[program.tool]
main = "src/tool.jk"
flags = "-d"

[library.core]
main = "core/core.jk"
flags = "-l"

[step.run]
run = "_out/hello && _out/tool"
needs = "hello tool"
```

Run (in the project folder):

```
$ makej
makej: building hello
makej: building tool
makej: building core
makej: done in 0.5 s
$ makej
makej: done in 0.0 s
$ makej -v run
makej: hello is up to date
makej: tool is up to date
makej: core is up to date
makej: run
  $ _out/hello && _out/tool
hello
tool sum 45
makej: done in 0.0 s
```

What `makej` does:

| Command | Meaning |
|---|---|
| `makej` | build every program and library (the target `all`) |
| `makej NAME` | build one target and what it needs (`makej run`) |
| `makej -v` | say more: the commands and the "up to date" lines |
| `makej -n` | show what would be done, do nothing |
| `makej -j 2` | build two things at once; `-j` alone uses all cores |
| `makej list` | list the targets (kind, main file, flags, needs) |
| `makej nosuch` | `makej: there is no target 'nosuch'. The targets: ...` and exit code 2 |

A program or library is built again only when a `.jk` or `.j` file in the folder of its main file
(and below it) is newer than the result.

## 2. A build file as a J2K program

When a build needs a loop or a condition, write `makej.jk` instead (it wins over the plain file):

```jk
#import <stdlib>
#import <makej>

int main() {
    Build b = Build::make();
    b.program("hello", "src/hello.jk", "");
    b.program("tool", "src/tool.jk", "-d");
    b.step("run", "_out/hello && _out/tool");
    b.needs("run", "hello tool");
    return b.run();
}
```

Run it with `makej -j 2` or `makej run` (`makej` compiles this file with its own copy of the library
`<makej>`; plain `jcmp` on this file reports `library not found 'makej'`). The functions used are `Build::make`, `program`, `library`
(`b.library("core", "core/core.jk", "-l")`), `step`, `needs` and `run`. `makej doc NAME` prints the
comment at the top of an installed library's file.

## 3. Where libraries are found

`#import <name>` looks for a library of the language; `#import "name"` for your own file.

| Import | Looked for in |
|---|---|
| `#import <stdlib>`, `<math>`, `<cpu>` ... | the `Library` folder of the compiler |
| `#import <jobs>`, `<gpu>`, `<npu>` ... | the folders of `J2K_PATH` (separated by `:`) and `~/.j2k/Library` |
| `#import "helper"` | `helper.j` or `helper.jk` next to the file that imports it, then the `-I` folders |

The compiler looks for its own `Library` folder in this order: the folder named in `JCMP_LIB`, then
`Library` next to `jcmp`, then `../Library/jcmp` and `../Library` next to it. If none fits, the
compiler stops and says so.

Example (the repository's library folder and the built libraries of `build/libs`):

```
export JCMP_LIB=$HOME/Jcmp-reg/Library J2K_PATH=$HOME/Jcmp-reg/build/libs
jcmp prog.jk -o prog && ./prog
```

Your own folders: a file `helper.j` in `other/` is found with `-I`:

```jk
// main.jk
#import <stdlib>
#import "other/helper"
int main() { jout << helper_twice(5) << "\n"; return 0; }
```

```
jcmp -I . main.jk -o m && ./m        # -I . makes other/helper.j findable
```

```jk
// other/helper.j
int helper_twice(int x) { return x * 2; }
```

Output:

```
10
```

(Run and checked on the phone.)

## 4. Installing libraries and tools with `jc`

`jc` is the command of Jaric for installing things (run on the phone; installing was not run here
to keep the phone unchanged):

```
jc lib list               # the libraries of J2K that are installed (run: prints gamej, glapp, ... )
jc lib install NAME       # a library of Jcmp-libs into ~/.j2k/Library (not run here)
jc install NAME           # a tool of Jcmp-Tools, for example makej or jget (not run here)
jc tools                  # the tools
jc update                 # jsh and the tools that have a newer release
```

`jget` is the download tool of [Jcmp-Tools](https://github.com/J2k-studio/Jcmp-Tools); `Net::http.download`
is the library function it uses. A library that `jc lib install NAME` puts in `~/.j2k/Library` is found
by `#import <NAME>`.

Other programs (git, python, ssh ...) are planned as packages in `~/jcmp-pkg`: its README says
nothing is published yet (the index format is in `SPEC.md` there). This guide does not use them.

## 5. Versions

| Where | What it says |
|---|---|
| `VERSION` (repository) | the version of the compiler, `1.2.13.0` |
| `JCMP_VERSION` in `jcmp/jcmp.jk` | the same number, built into the compiler (`#define JCMP_VERSION`) |
| `Library/VERSION` | must be the version of the compiler (else the compiler says to install them again) |
| `jcmp -version` | prints `jcmp 1.2.13.0 (J2K compiler, Linux ARM64)` |
| first line of a library file | `// jobs 0.1.0 -- run many small jobs ...` (name, version, what it does) |
| `makej --version` | `makej 0.11.0` |

A library declares its version in the first comment line, in the form `// NAME X.Y.Z -- text`.
Example: `std/jobs.j` starts with `// jobs 0.1.0 -- ...`, `std/gpu.j` with `// gpu 0.2.0 -- ...`.

`jcmp -update` replaces the compiler and its library together with the latest release (not run here:
it would replace the compiler in use).

## 6. The compile cache

With `-cache DIR` the compiler keeps the final code of every function in `DIR` and reuses it for the
functions that did not change. The output is the same, byte for byte (checked):

```
$ jcmp l90.jk -o c1 -nocache
$ jcmp l90.jk -o c2 -cache cachedir
$ jcmp l90.jk -o c3 -cache cachedir
$ cmp c1 c2 && cmp c2 c3 && echo "cache: identical bytes"
cache: identical bytes
$ ls cachedir | wc -l
41
$ jcmp -clean cachedir
jcmp: cache cachedir: 41 files deleted, 55 KB
```

| Setting | Effect |
|---|---|
| (nothing) | the cache is on by default for big programs, in `~/.j2k/cache` |
| `J2K_CACHE=DIR` | the cache folder for the shell |
| `J2K_CACHE=` (empty) or `-nocache` | no cache |
| `J2K_CACHE_MAX_MB` | the size limit (default 512); the oldest files go first |
| `jcmp -clean DIR` | empty the folder; deleting it by hand is also safe |

The key contains the compiler version and the options, so an old cache is never used by another
compiler. The documentation says the cache saves about a third of the time for big programs (the
compiler itself: 11.7 s to 7.9 s, from `USAGE.md`); this guide did not measure it again.

## See also

* [USAGE.md](USAGE.md) for the compiler options
* [LIBRARIES.md](LIBRARIES.md) for what each library does
* [APP_PACKAGING.md](APP_PACKAGING.md) for `makej apk`, `pack` and `dist`
