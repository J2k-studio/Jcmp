# Dogfood notes: what it is like to write a real program in J2K (2026-10-22)

First program: `jgrep` (a small grep: `-i -n -v -c`, regular expressions, files or stdin), about 90 lines, source in `~/jgrep/jgrep.jk` (planned for the Jcmp-Tools repo). Compared with the real `grep -E` on 8 cases: the same output on all.

## What felt good
* It compiled on the first try; the library had everything (`Env::args`, `Fs::read_lines`, `Regex::find`, `String.lower/split`, `Result` with `switch`).
* No `main(argc, argv)`, no includes, no memory management in the program: the Strings free themselves.
* `cerr` (new) made the usage and the error messages right.

## What was missing or rough (candidates, owner decides)
1. **Output is not buffered.** `cout << line << "\n"` is two `write` system calls (measured with strace: 3348 writes for 1674 lines). On 200,000 lines `jgrep error` took 2.1 s against 0.11 s of `grep`; the search itself is about 0.6 s. A program that prints a lot is 3 to 10 times slower than the same in C. Proposal: buffer stdout in the runtime (flush at exit and on every exit path, before reading from the keyboard, before writing to stderr, when the output is a terminal at each new line). This is the biggest finding: it helps every program. (Optimisation item.)
2. **No way to see the end of the input with `read.line()`**: an empty line and the end both give `""`. `jgrep` reads stdin with `Sys::read` in a loop. A function like `read.eof()` or `read.try_line()` (a `Result`/`Option`) is needed.
3. `String` has no `lines()`; `text.split("\n")` leaves an empty last element that has to be removed by hand (`pop`).
4. The regular expression library is small (no `\d`, no `{n,m}`, no groups?): fine for a first grep, to be checked against the documentation.
5. A global `int` as an option flag works, but `bool` globals with initial values or a small `struct Options` passed around would read better (initializers of globals must be literals).

## Speed
`jgrep -c "[0-9]+"` on 8.5 MB: 0.6 s (grep 0.07 s); the matcher is a backtracking one, as documented. The plan item for the standard library: a faster path for a pattern that is a plain word (a search for the text, no regex machinery).

## Second program: `jsh`, a shell (2026-10-22), 300 lines (in the Jaric repository, os/userland/shell)
Worked first time after fixing five small things; pipes, redirection, background, history, line editing, `$?`. More findings:
6. ~~A backslash or a quote inside a `//` comment is read as a string~~ — **retracted**: the later errors were a cascade after the first error (the unknown escape `\x1b` in a string); comments are skipped correctly (checked). The recovery after a bad escape still gives confusing follow-up errors.
7. **No `\x1b` escape** (only `\n \t \r \0 \\ \' \"`): a terminal program had to build the ESC character with `(char)27`. **Fixed after 1.0 work: `\e`, `\xHH`, `\a`, `\b` (test t501).**
8. **`out` (and `in`) are read as modifiers**, so `String^ out` as a parameter name is refused with a message that does not say why. **The help text now says that the words are reserved.**
9. **A statement cannot start with `(`** (`((int^)p)[3] = 1;`): use a variable. (A crash that was first blamed on assigning a switch binding to an outer variable could not be reproduced in a small program; it came together with the `unwrap()` use after free that is fixed.)
10. `String::push(char)` and `slice` made the line editor easy; a `String.insert(pos, text)` and `remove(pos, n)` would make it shorter.
