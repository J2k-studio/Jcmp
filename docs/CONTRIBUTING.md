# Contributing to J2K and the compiler `jcmp`

**Outside contributions are not accepted at this stage.** The project is developed by a single author
([README.md](../README.md)). The license ([LICENSE](../LICENSE)) says that a contribution sent to the licensor
gives the licensor the right to use it, and gives the sender no right in the software. Read the license before
you send anything.

This page is for the author, for anyone who is asked to help, and for anyone who wants to know the rules a change
must follow. The rules below come from the working rules of the repository and from [DEVELOPING.md](DEVELOPING.md).

## 1. Language of the work

* Compiler messages are in English, in the form `file:line:col: error: ...`.
* Code, identifiers, commands, commit messages and the documents in `docs/` are in English.
  The language specification, `docs/syntax-design.md`, is written in Thai.

## 2. The language is the owner's decision

* A new syntax, or a change of the meaning of existing syntax, is decided by the owner of the language. Propose it
  in `docs/syntax-design.md` as a new numbered section, with the options and their pros and cons, and wait
  ([DEVELOPING.md](DEVELOPING.md), "Changing the language").
* Syntax that the owner has already decided stays as it is.
* A change that does not change the language (an optimisation, a fix, a library function) does not need that step.

## 3. Every change comes with a test

* A new feature or a fix comes with a test program and the exact output it must print (a `.out` file).
  A test that must fail to compile is also a test; a `.warn` file holds the exact compiler messages when the test
  checks them. Tests are registered in the test runner.
* Everything must pass before a change is kept ([DEVELOPING.md](DEVELOPING.md), "The loop"). The test suite and its
  runner are kept in the development repository only, and are not part of this public copy. A contributor who has
  access to that repository finds the way to run them in its testing guide.

## 4. The compiler: how a change is built and checked

1. A change to `jcmp/` is built by the compiler itself: run `./bootstrap.sh`. `jcmp1` is built by `bin/jcmp`,
   `jcmp2` by `jcmp1`, and `jcmp3` by `jcmp2`. The script succeeds only when `jcmp2` and `jcmp3` are identical
   (binary and assembler text). See [ARCHITECTURE.md](ARCHITECTURE.md), section 7.
2. After a change to `std/`, run `./gen_std.sh`, then `./bootstrap.sh`.
3. Copy the new compiler to `bin/jcmp` (the script prints a note when it differs) and run the tests with it.
4. A change that is meant to make code faster prints the numbers before and after, in the commit message or in
   the notes ([DEVELOPING.md](DEVELOPING.md), "Measuring").

**Frozen seed.** The first compiler, written in assembly, is the `seed/` folder of the development repository. It
is frozen: do not add features to it, and do not edit it. A feature that the seed cannot compile is listed in the
J2K-only block of the test runner, and in the skip list of `bootstrap.sh`.

## 5. Language documents and examples

* A feature of the language is documented in [LANGUAGE.md](LANGUAGE.md), with examples.
* Every code example in `LANGUAGE.md` must compile and run. A program in a document that has a `main` is compiled
  by the document checker, a tool of the development repository.
  A block that is not meant to compile is marked as such in the document.
* The manuals `USAGE.md`, `LIBRARIES.md`, `API.md` and `STDLIB.md` are kept true with the code. `API.md` is made from
  the libraries by a script; do not edit it by hand.

## 6. Libraries and tools

* A library is a file `std/NAME.j` whose first line is a comment with its name and version, for example
  `// neuron 0.7.1 -- ...`. Add it to `gen_std.sh`, add a test, and add a page in `docs/` ([DEVELOPING.md](DEVELOPING.md)).
  [INTERNAL_API.md](INTERNAL_API.md) says which functions are public and what a change must keep.
* A tool is a folder with its program, its build and test scripts, a README, a `CHANGELOG.md` and a `VERSION` file.
* A change to a library or a tool is written in its `CHANGELOG.md` under **Added** and **Fixed**
  ([DEVELOPING.md](DEVELOPING.md)).

## 7. Commits

* Commit messages are in English.
* Keep the public documents free of links to files that are not in the public copy.

## 8. Not documented

* The rules about formatting: the repository has a formatter (`jcmp fmt`, [USAGE.md](USAGE.md)), which changes white
  space only. No rule about unrelated reformatting of existing code is written down in the files of the repository.
* The review process. Nothing is written down about who reviews a change.
