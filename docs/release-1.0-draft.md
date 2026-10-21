# 1.0.0.0 — draft of the announcement, the promise and the steps (for the owner to read and change; written 2026-10-22)

## 1. What the number means (from docs/roadmap-1.0.md)
`A.B.C.D` — A a big step (rare), B new features, C small updates, D fixes only. **1.0.0.0** is the end of the first era: the language, the compiler (written in J2K, builds itself on ARM64 and ARM32), the standard library, the messages and the tests are stable. From then on a program that compiles keeps compiling; things are added, names do not change in a way that breaks a program.

## 2. The promise "updates are free" (owner, 2026-10-17) — proposed words
For `README.md` and the release notes (public):
> Every update of jcmp 1.x.x.x, now and later, is free of charge. A new release never needs a new payment, and the compiler you have keeps working.

The `LICENSE` today (version 1.1) allows reading, building and running for learning, personal use and research without profit, and forbids commercial use without written permission. The promise above is about the price of updates, so it does not contradict it, but **the owner should check the wording of the LICENSE** and decide whether to add one sentence there, for example in a new section "Updates": *"Updates of the Software are provided under this License at no charge."* (The assistant does not change the LICENSE.)

## 3. Announcement text (English, for the GitHub release and the README)
> **jcmp 1.0.0.0** — the J2K compiler, written in J2K, for Linux ARM64 and ARM32.
> * One small program, no dependencies: it writes ELF files itself (no libc, no linker). It builds itself, byte for byte, on both targets.
> * The language: whole numbers of 64 bits, `double` / `float`, strings and arrays that free themselves, structs, enums, `try / catch`, threads, and the CPU level (`register { }`, `naked`, atomics, raw machine words).
> * Close to C in speed on ARM64 (the benchmarks are within 1.5 times of `clang -O2`, except one loop).
> * The standard library: files, folders, text, JSON, CSV, TOML, regular expressions, maps and sets, SHA-256, TCP and https (TLS 1.3), and more downloaded with `jget`.
> * `jcmp -show NAME` shows the code that was made for a function.
> * Known limits: `docs/LIMITS.md`. Every library function: `docs/API.md`.
> * Updates are free (see the promise above).

## 4. The steps of the release (the assistant does them; none is done yet)
1. The owner answers `docs/decisions-for-1.0.md` (the questions that touch the language), and checks the LICENSE words (section 2).
2. The code is frozen. `tools/campaign.sh 3` gives three clean runs on the release candidate (the same commit that will be tagged).
3. The version becomes four numbers: `VERSION` and `JCMP_VERSION` in `jcmp/jcmp.jk` = `1.0.0.0`; the places that `ship.sh` changes (README, README.th.md, docs/RELEASE_NOTES.md, install lines) already take any text after `--version`. The tag is `v1.0.0.0`. `install.sh --version 1.0.0.0` and `jcmp -update` take the text as it is (checked for 0.9.x; tested again with the candidate).
4. `CHANGELOG.md` and `docs/RELEASE_NOTES.md` get the 1.0.0.0 entry (the announcement above, shortened).
5. `./ship.sh 1.0.0.0 "jcmp 1.0.0.0"`; then a fresh install from the public release, and the campaign step `fresh_install` again.
6. After the release: `docs/LIMITS.md` stays up to date with every release; the compatibility rule of section 1 starts.

## 5. After 1.0.0.0 (docs/roadmap-1.0.md, section 6)
x86_64; `async`; the J2K library file (`.jo`); the CPU-level features of `docs/open-questions.md`; GPU; the own OS; the Xiaorin project. Each is a feature step (B) or a big step (A).
