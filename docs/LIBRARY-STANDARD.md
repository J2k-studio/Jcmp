# The standard of a library (`std/NAME.j`)

One standard for every library, old and new. `tools/libcheck.py` checks it; `release.sh` stops when a library that follows the standard stops following it, and the list of the old libraries that do not follow it yet
(`docs/libcheck-baseline.txt`) can only get shorter.

## 1. The file
* **Name:** one word in lower case (`utf8`, `geom`, `draw2d`); one topic per library; when it grows over about 1,500 lines, split it (`draw2d` / `canvas`).
* **First line:** `// NAME X.Y.Z -- what it is, in one line.   #import <NAME>   (license: MPL-2.0)`; add `needs jcmp X.Y.Z` when it uses a newer feature.
* **Then 3 to 8 lines of examples** (comment lines): the calls a newcomer needs first, each with the answer in a comment. These lines are the start of the chapter (`tools/libdoc.py` copies them).
* **Then a line about the limits** (what it does not do, what is not constant time, what is slow).
* **A struct named like the library** (`Utf8`, `Geom`) holds the functions as `static`; a thing that has a state is a struct with `make()` and methods (`Profile`, `Game`).
* **Lines are at most 200 characters** and a function fits on a screen where it can.

## 2. The interface
* **Names:** `snake_case` for functions and fields, `CamelCase` for structs, `UPPER_CASE` for constants; a name says what it does (`rect_hit`, not `rh`); no abbreviation that a newcomer cannot read.
* **Errors:** a mistake that can happen on a good program (a file that is not there, a text that is not a number) gives `Result<T, Error>`; a mistake of the caller (an index out of range, a null) is a check that stops the program with a clear message.
  Nothing fails silently and nothing returns a magic number.
* **Memory:** the owner of every buffer is written in the first lines of the function; a hot function takes the buffer from the caller; a library does not keep a global that grows.
* **Text** is `str` and is UTF-8; a function that counts or cuts text says whether it works by bytes or by characters (`<utf8>`).
* **No C and no other language:** the library is J2K; what differs between machines is chosen with `#if ARCH == "arm64"` and both ways are tested.
* **Layers:** base -> text -> files -> data -> math -> crypto -> net -> media -> graphics -> game. A library may import only a layer below it (and `<stdlib>`).

## 3. The proof (all four, or the library is not finished)
1. **A test** `test/tNNN_NAME.jk` with its `.out`: every public function at least once, the edges (empty, one, the biggest), and a wrong input; it is registered in `run_all_tests.sh`.
2. **A chapter** in `docs/LIBRARIES.md` (`## Title: #import <NAME>`) with one example that runs (the doc check compiles it).
3. **Speed** (a library of numbers, text or data): a program in `tools/bench` or a line in the chapter that compares it with the C way, and the cost of the big operations written in words (O(n log n), a copy, an allocation).
4. **A version** `0.x.0` while the names may change, `1.0.0` when they are frozen; a name that goes away warns for two releases (`[-Wdeprecated]`) as the old words of the language do.

## 4. Review checklist (a person reads this before the library goes in)
- Can a newcomer use it from the first lines of the file alone?
- Does an error say what to do next?
- Is there a function that nobody will call? (cut it)
- Is the name of each function the name that the same idea has in the other libraries?
- Does it compile with no warning, and does `tools/libcheck.py NAME` say nothing?
