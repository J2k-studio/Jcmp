# J2K & Jcmp

**J2K** is a systems programming language designed from scratch.  
**Jcmp** is its native compiler that emits raw machine code (no LLVM, no GCC backend).

> Status: early development (Phase 1) — ARM64 ELF target, built and tested on mobile (Termux).

---

## Philosophy

1. **Maximum self-reliance** — write the compiler, assembler, and code emitter yourself.
2. **Close to the metal** — compile directly to machine code bytes; no intermediate IR dependency.
3. **Self-hosting as a milestone** — the compiler will eventually be written in J2K itself.
4. **Document everything** — the roadmap is updated weekly so the current state is always clear.
5. **A new language** — not a continuation of previous experiments; lessons are kept, code is not.

Inspired by **HolyC** (Terry Davis) and **C++**, while deliberately avoiding the weak typing of the former and the full complexity of templates / multiple inheritance of the latter.

---

## Current Status (as of 2026-08)

| Component              | State                          |
|------------------------|--------------------------------|
| Roadmap & design docs  | Active, weekly updates         |
| Syntax design          | Draft locked for core features |
| Hand-written ARM64 ELF | Done (Phase 0 exit criteria)   |
| J2K Assembler (v1)     | In progress                    |
| Jcmp (compiler)        | Early stages                   |
| Self-hosting           | Planned (Phase 2)              |
| x86_64 backend         | Planned later                  |
| Freestanding / toy OS  | Long-term goal                 |

**Progress is public and inspectable** — see `roadmap-j2k.md` (weekly log + decisions), the binaries (`Jcmp`, `j2k_asm_v1`), and assembly artifacts (`.s` / `.o`) in this repository.

Primary development environment: **ARM64 + Termux** (no desktop PC required).

---

## Repository Layout

```
Jcmp/
├── roadmap-j2k.md      # Full project roadmap & design decisions
├── syntax-design.md    # Language syntax specification (draft)
├── Jcmp                # Compiler binary (current)
├── j2k_asm_v1          # Assembler binary
├── *.s / *.o           # Assembly / object artifacts
├── test/               # Test sources
├── _test_out/          # Test outputs
└── run_all_tests.sh    # Test runner
```

---

## Quick Overview of the Language (J2K)

- **File extension**: `.jk`
- **Entry point**: `main()`
- **Style**: C/C++-like declarations, HolyC-inspired simplicity
- **Pointers**: `@` (address-of) and `^` (pointer type / dereference)
- **I/O**: `cout <<` is **language magic** (built into the compiler, not a library)
- **Memory**: hybrid — automatic free where lifetime is proven, manual `alloc`/`free` otherwise
- **No LLVM / no external compiler backend** — the goal is direct machine-code emission

Example (illustrative; syntax still evolving):

```jk
i32 add(i32 a, i32 b) {
    return a + b;
}

void main() {
    i32 x = 42;
    i32^ p = @x;
    cout << "value = " << p^;
}
```

Full design notes live in `syntax-design.md` and `roadmap-j2k.md`.

---

## Build & Usage (current)

```bash
# Typical invocation once the toolchain is ready
./Jcmp main.jk -o main

# Flags (planned / partial)
#   -d   debug (bounds checks, guard bytes)
#   -st  strict mode (warnings become errors)
#   -I   additional search path for imports
```

Exact capabilities of the current binaries are still evolving. See the roadmap for the precise Phase 1 targets.

---

## Roadmap (high level)

| Phase | Goal                                              |
|-------|---------------------------------------------------|
| 0     | Hand-written ARM64 ELF that runs on Termux        |
| 1     | Assembler + Compiler v0/v1 targeting ARM64        |
| 2     | Self-hosting (compiler written in J2K)            |
| 3     | x86_64 backend                                    |
| 4–5   | Freestanding runtime + toy OS experiments         |

Detailed decisions, weekly logs, and open questions are kept in `roadmap-j2k.md`.

---

## License

This project is **proprietary**.  
You may **read** and **run** the code for personal study.  
You may **not** copy it as your own work, redistribute it, or claim ownership.

See the full terms in the [LICENSE](LICENSE) file.

---

## Author

**Jao** (J2k-studio)  
Thailand · IT student · developing entirely on mobile (ARM64 + Termux)

---

## Contributing / Contact

The repository is currently under active solo development.  
Design decisions are recorded in the roadmap; external contributions are not accepted at this stage.

For questions or permission requests, open an issue or contact via the GitHub profile **J2k-studio**.
