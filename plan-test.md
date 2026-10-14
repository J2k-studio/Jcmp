# J2K Language — Master Plan & Direction

**Document status:** Working plan  
**Last updated:** 2026-10-14  
**Language version context:** 0.9.103 (self-hosting, Linux ARM64)

---

## 1. Vision

J2K aims to become an **all-in systems and general-purpose language** that is:

- Close to the machine (register-level control, no hidden GC)
- Safer than C
- Fast enough to compete with C/C++/Zig/Rust in many domains
- Capable of interoperating cleanly with other languages (C/C++ + scripting layer)
- Eventually able to feel more like a **living system** (self-repair, hot-reload, adaptation)
- Usable for systems, algorithms, applications, and later mobile/web targets

Ultimate goal: a language that can realistically cover most serious work without forcing the programmer to switch languages constantly.

---

## 2. Current Strengths (as of 0.9.103)

- Self-hosting compiler written in J2K
- Direct ELF generation (no LLVM/GCC dependency)
- IR + optimiser (value numbering, loop invariants, constant folding, leaf functions)
- Ownership basics, `Option`/`Result`, generics, operator methods
- Low-level features: naked functions, register pinning, atomics, interrupts, device registers, abi declarations
- Assembler much faster (self-compile ~3.6s)
- Error messages started and improving (missing main, wrong arity, multiple `;` errors, etc.)
- Guard pages in `-d` builds; use-after-free warnings
- Cleaner and stricter than C in several areas (no pointer arithmetic, bool is not int, etc.)

---

## 3. Priority Plan — What To Add Next

### 3.1 Critical (Do First)

| Priority | Item | Why |
|----------|------|-----|
| 1 | **SIMD / NEON basics** | `loop`, `nbody`, `vec3` still lose clearly to clang without vectorization |
| 2 | **Better integer division / modulo** | `gcd` was ~10× slower than clang; division is a major gap |
| 3 | **Complete error messages** | Messages exist but are often truncated; need full text + location + hints |
| 4 | **Slice / Span** | View into arrays without copying; essential for algorithms and APIs |
| 5 | **Sort with comparator** | Current sort is limited; needed for real algorithmic work |

### 3.2 High (Do Next)

| Priority | Item | Why |
|----------|------|-----|
| 6 | **Queue / Deque / Heap (Priority Queue)** | Stdlib is still thin for general programs |
| 7 | **Binary search / lower_bound / upper_bound** | Core algorithm primitives |
| 8 | **Testing framework** | Required as the project and user code grow |
| 9 | **Formatter** | Consistent style; reduces friction in larger codebases |
| 10 | **x86_64 target** | Currently ARM64-only; needed for wider use |

### 3.3 Medium (All-in Direction)

| Priority | Item | Why |
|----------|------|-----|
| 11 | **Solid FFI** | Call C/C++ and be called back cleanly |
| 12 | **Practical concurrency** | Channels or high-quality primitives + thread pool |
| 13 | **Hot-reload modules** | Supports the “living system” direction |
| 14 | **Basic package system** | Share and reuse code |
| 15 | **Full freestanding mode** | Kernel / embedded without runtime |

### 3.4 Later (Do Not Rush)

- GUI
- WebAssembly
- GPU / compute
- Large package registry
- Full mobile targets
- Advanced self-repair / supervision trees

---

## 4. Slice / Span (Definition for the Plan)

**Slice / Span** = a view into a contiguous range of an array **without copying**.

- Has pointer + length
- Indexing is bounds-aware (especially in `-d`)
- Mutations through a span affect the original data
- Enables efficient APIs (pass a range, not a full copy)

Example direction (not final syntax):

```jk
int a[6] = {10, 20, 30, 40, 50, 60};
Span<int> s = a[1..5];   // view of [20, 30, 40, 50]
cout << s[0] << " " << s.len;   // 20 4
```

This is different from current `String.slice`, which copies.

---

## 5. Error Messages — Status & Required Work

**Status:** Started, still underdeveloped.

Already improved (0.9.84+):
- Missing `main` reported clearly
- Wrong number of arguments reported
- Multiple missing `;` reported together
- Some type errors improved
- `docs/error-messages-plan.md` exists

Still needed:
- Full, untruncated messages for all fail tests
- Consistent `file:line:col` + source snippet + `help:`
- Better messages for ownership / moved values
- Clear messages for import failures (show search paths)

Target quality:

```
error: no main function found
  --> main.jk
  help: every program needs `void main()` or `int main()`
```

---

## 6. Performance Gaps (From Benchmarks)

| Benchmark | Situation | Main missing piece |
|-----------|-----------|--------------------|
| fib, sieve, matmul, qsort | Close or winning | Keep improving |
| mandel, gcd | Close to behind | Division, FP, invariants |
| vec3 | Behind | Inlining / struct handling (improved, still behind) |
| nbody | Behind | fmadd / SIMD |
| loop | Far behind | NEON auto-vectorize |

Re-measure `gcd`, `nbody`, `loop`, `vec3` on **0.9.103** after recent loop-invariant and constant work.

---

## 7. Designed Syntax Directions (Agreed Concepts)

### 7.1 Inline Assembly / Low-level blocks

```jk
_. {
    mov  x0, #42
    mov  x8, #93
    svc  #0
}

_. {
    in    x1 = value
    out   x0 = result
    clobber x3, x4, nzcv
    add   x0, x1, x2
}

_.exit {
    mov  x0, #0
    mov  x8, #93
    svc  #0
}
_.exit;
```

Also: raw machine code (`.byte`, `.word`) inside the same blocks.

### 7.2 Register / Core control (future)

```jk
@reg("x19") int counter;
@on_core(2) void heavy_work() { ... }
@on_core(auto) void light_task() { ... }
```

### 7.3 Sandbox direction (defensive)

- Capability / permission model
- No raw asm / naked inside sandbox by default
- Memory and syscall gates
- Resource limits
- Audit of denied actions

---

## 8. Multi-language Architecture Target

```
C/C++ / Rust          ← maximum performance & OS interface
        ↑
      J2K             ← main logic, systems, ownership, safety
        ↑
Scripting layer       ← hot-reload, configuration (Lua-style or J2K interpreter)
```

---

## 9. Roadmap Overview

### Phase 1 — Speed & Correctness (now)
1. Re-benchmark on 0.9.103
2. Division / modulo improvements
3. SIMD / NEON basics
4. Finish error-message quality
5. Slice / Span
6. Sort comparator

### Phase 2 — Usable General-Purpose
- Queue, Deque, Heap
- Binary search family
- Testing framework
- Formatter
- Start x86_64

### Phase 3 — Interop & Living Features
- FFI + embedding
- Concurrency that is practical
- Hot-reload
- Basic packages
- Full freestanding

### Phase 4 — Expansion
- More targets (mobile, WASM)
- Registry and ecosystem
- Advanced living-system features

---

## 10. Immediate Next Actions

1. Re-run heavy benchmarks (`gcd`, `nbody`, `loop`, `vec3`, `sha256`) on 0.9.103
2. Inspect generated assembly for `gcd` vs clang `-O2`
3. Implement / finish high-value error messages
4. Design Slice / Span syntax and semantics
5. Plan NEON support in small, testable steps
6. Add sort comparator and one or two core collections

---

## 11. Guiding Principles

- Prefer clarity and explicitness over magic
- Stay close to the machine without becoming as dangerous as C
- Safe by default; unsafe / low-level must be explicit
- Good errors and tooling are features, not extras
- Grow in layers: solid core → useful libraries → interop → living features
- Keep the self-hosted, dependency-light nature of the compiler

---

**End of plan document**
