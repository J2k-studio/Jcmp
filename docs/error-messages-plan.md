# Error messages: plan

Goal: every mistake a programmer can make gets a clear message with the file, the line, the column, the
source line with a `^`, and (where it helps) a `help:` line. A mistake that is accepted without any message is
worse than an unclear message, so those come first.

Format (already used for most errors):

```
file.jk:15:23: error: expected ';' at the end of line 15 (it is missing there)
 15 |     int x = 5
    |              ^
```

A message about the whole file (no line to point at) is written as:

```
error: no main function found in 'file.jk'
  help: every program needs `void main()` or `int main()`
```

## Done

| Release | What |
|---|---|
| 0.9.84 | A program without `main`: `error: no main function found` + help (before: an unreadable message from the assembler) |
| 0.9.84 | A call with the wrong number of arguments: `'add' takes 2 arguments, but 1 was given` (before: accepted without any message, the missing value was garbage) |
| 0.9.84 | A text stored in an `int` (declaration, assignment, return): `a text cannot be stored in an int` |
| 0.9.84 | `return value;` in a `void` function: `a void function cannot return a value` |
| 0.9.84 | A path that reaches the end of a non-void function (`if` without `else`, `while cond`): `can reach its end without returning a value` (case 6) |
| 0.9.84 | A literal index outside a fixed array, 1-3 dimensions: `index 5 is out of range: the array has 3 elements` (case 8) |

## Found by probing (2026-10-13), still open

| # | Case | Today | Wanted |
|---|---|---|---|
| 1 | `int a = "hi";` | DONE in 0.9.84 | (function arguments `f("hi")` to an `int` parameter are still accepted: pointer parameters have the same type id, needs a flag per parameter) |
| 2 | `int[3] a;` (C++/Java style array) | DONE in 0.9.84 | `help: write  int a[3];` |
| 3 | `import <name>` for a library that does not exist | DONE in 0.9.84 | `did you mean 'stdlib'?` (only the built-in names; libraries found on the search path are not listed yet) |
| 4 | unknown name | DONE in 0.9.84 | `did you mean 'x'?` (locals, globals, functions; 1 edit, 2 for 5+ letters) |
| 5 | `import` written without `#` | warning `write #import` | ok, keep (will become an error) |
| 6 | return type mismatch (both types in the message) | to be probed | message with both types (missing return: DONE) |
| 7 | use after move / ownership | to be probed | show where the value was moved |
| 8 | index out of range of a constant index (`a[5]` on `a[3]`) | DONE in 0.9.84 | (a constant folded index such as `a[2+3]` or a `-1` is not checked yet) |
| 9 | assembler errors (`j2k_asm: error at line N`) | DONE in 0.9.84: `internal error: ... This is a bug in jcmp` with the generated line | (a source line cannot be given: the text has no line map) |

| 0.9.87 | Several missing `;` in one file are all shown (`N errors generated.`); `using ...` without `;` is an error |

## Order of work

1. Anything accepted silently (cases 1, 6, 8) - the language is meant to be safer than C.
2. Hints that cost nothing (2, 3, 4).
3. Ownership messages (7).
4. Keep a test for every message: `run_fail_msg NAME "text"` in `run_all_tests.sh` checks the text, not only
   the rejection.

## Rules

* One mistake, one message. A missing `;` at the end of a line is recoverable (the parser goes on as if it was there, up to 10 are shown, `soft_error` in `jc_lex.j`); any other error stops the compiler at the first one. More recoverable cases (a missing `)` or `}` at the end of a line) can use the same `soft_error`.
* The text names what is wrong and what to write instead.
* Never print an error that comes from the assembler or the linker: if it is reached, it is a compiler bug.
