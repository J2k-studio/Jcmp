# Roadmap: J2K — ภาษาโปรแกรมมิ่งของตัวเอง (จาก 0 ถึงเขียน OS ได้)

> อัปเดตล่าสุด: **2026-08-21**
> ผู้เขียน: Jao (อายุ 15, นักศึกษา IT ปี 1, ประเทศไทย)
> เครื่องมือ: มือถือ (ARM64) + Termux เท่านั้น ไม่มี PC
> แรงบันดาลใจ: HolyC (Terry Davis) + C++ — ไม่พึ่ง LLVM, ไม่พึ่งไลบรารีคนอื่นถ้าไม่จำเป็น

---

## 0. ปรัชญาของโปรเจกต์ (อ่านก่อนทุกครั้งที่หลงทาง)

1. **พึ่งตัวเองมากที่สุด** — เขียน compiler เอง, เขียน assembler/emitter เอง, ไม่ใช้ LLVM/GCC backend
2. **ชิด CPU** — เป้าหมายสุดท้ายคือ compile ตรงเป็น machine code (ไบต์จริง) ไม่ผ่านตัวกลาง
3. **Self-hosting คือหมุดหมายสำคัญ** — เขียน J2K ด้วยตัวมันเอง (เหมือนที่ทำกับ JPP ได้แล้ว)
4. **บันทึกทุกอย่าง** — ไฟล์นี้ต้องอัปเดตทุกสัปดาห์ ให้คนอื่น (หรือ AI ตัวอื่น) อ่านแล้วเข้าใจสถานะปัจจุบันได้ทันที
5. **นี่คือภาษาใหม่ ไม่ใช่ JPP v2** — เริ่มจาก 0 จริงๆ แต่ "บทเรียน" จาก JPP (bug, การแก้ ARM64 encoding ฯลฯ) ยังใช้ได้ ห้ามลืมของเก่า แค่ไม่ต่อโค้ดเดิม

---

## 0.5 ลำดับลงมือทำจริง (อ่านก่อนเริ่มพิมพ์บรรทัดแรก)

> สรุปสั้นๆ ว่า "ตอนนี้ต้องทำอะไรก่อน" — รายละเอียดเต็มอยู่ใน Phase Roadmap (ข้อ 5) และ Language Design Decisions (ข้อ 8)

**ขั้นที่ 1 — เตรียม path/repo ก่อนแตะโค้ดเลย**
```bash
mkdir -p ~/j2k-cmp && cd ~/j2k-cmp
git init
```
(ตามข้อ 8.14 — path และ git ตัดสินใจแล้ว)

**ขั้นที่ 2 — Phase 0: เตรียมความรู้** (ดูรายละเอียดในข้อ 5 → Phase 0)
- อ่าน ARM64 ISA + ELF format ให้พอเขียนมือได้
- เป้าหมายจับต้องได้: เขียน ELF ARM64 "exit code" ด้วยมือให้รันผ่าน Termux ได้ก่อน — นี่คือ milestone แรกสุดของทั้งโปรเจกต์

**ขั้นที่ 3 — Phase 1 ขั้น 1: เขียน "J2K Assembler" ด้วย ARM64 asm ล้วน** (ตามข้อ 8.9, 8.13)
- นี่คือโปรแกรมจริงตัวแรกของโปรเจกต์ ไม่ใช่แค่ฝึกมือ — เป้าหมายคือแปลง text mnemonic ง่ายๆ → machine code bytes + เขียน ELF ได้

**ขั้นที่ 4 — Phase 1 ขั้น 2-3: J2K Compiler v0 → v1**
- v0 compile ด้วย J2K Assembler จากขั้น 3, รองรับ J2K subset เล็กสุด
- v1 เพิ่ม syntax ให้ครบตามข้อ 8 ทั้งหมด (memory model, pointer, array, match, struct ฯลฯ)

**คำสั่งที่ต้องมีตั้งแต่ต้น (ตามข้อ 8.16, 8.21):**
- ชื่อ compiler binary: `Jcmp`
- คำสั่งพื้นฐาน: `Jcmp main.jk -o main`
- Flag ที่ต้องรองรับ: `-d` (debug/bounds-check), `-st` (strict mode)

**สิ่งที่ต้องทำก่อนขั้นที่ 3 (เขียน J2K Assembler)**: ออกแบบ `syntax-design.md` ให้เสร็จก่อน — เพราะตอนนี้ตัดสินใจเรื่อง syntax หลักๆ ครบแล้วในข้อ 8 (memory model, pointer `@`/`^`, array, match, namespace, error handling ฯลฯ) พร้อมนำไปเขียนเป็นเอกสาร grammar จริงได้แล้ว

---



- [ ] J2K compile ตัวเองได้ 100% (self-hosted)
- [ ] มี backend ยิง machine code ตรงได้อย่างน้อย 2 สถาปัตยกรรม: **ARM64** และ **x86_64**
- [ ] รันได้แบบ freestanding (ไม่พึ่ง libc) อย่างน้อย 1 target
- [ ] มี toy OS เล็กๆ ที่ boot ได้จริงบนเครื่องจริงหรือ QEMU เขียนด้วย J2K
- [ ] เอกสาร roadmap-j2k.md ครบ อัปเดตทุกสัปดาห์ ใช้เป็น "ผลงานพิสูจน์ตัวเอง" ได้

**สิ่งที่ตัดออกตอนนี้ (revisit ทีหลัง):** iOS (ต้อง sign/sandbox ของ Apple, ทำยากสุดในบรรดาทั้งหมด, เก็บไว้ Phase 6+), HarmonyOS (คล้าย Linux ARM64 ได้บางส่วน แต่ NDK/security model ปิด ต้องรอศึกษาเพิ่ม)

---

## 2. ทำไมเลือกลำดับนี้ (เหตุผลของ AI ที่แนะนำ — ตอบคำถาม Phase 1)

คุณให้ตัดสินใจแทนเรื่อง Phase 1 นี่คือเหตุผล:

**เริ่มที่ ARM64 ก่อน ไม่ใช่ x86_64** เพราะ:
- เครื่องที่มีคือมือถือ Kirin 980 = ARM64 จริง → เขียน ELF ARM64 แล้ว **รันทดสอบได้ทันทีบนเครื่องตัวเอง** ผ่าน Termux (Linux userspace) ไม่ต้องพึ่ง emulator/QEMU
- x86_64 คุณไม่มีเครื่องจริงให้รันเทส ต้องพึ่ง QEMU (ซึ่งกิน RAM/CPU หนักบนมือถือ) — ทำทีหลังตอนมี ARM64 backend ที่พิสูจน์แนวคิด (code emitter, register allocator, ELF writer) แข็งแรงแล้ว ค่อย "แปลง target" ง่ายกว่าทำพร้อมกัน 2 arch ตั้งแต่ต้น
- คุณมีประสบการณ์ ARM64 encoding มาแล้วจาก JPP (รู้ปัญหา SP vs XZR, branch offset ฯลฯ) → ต่อยอดความรู้เดิมได้เร็วกว่า แม้จะไม่ใช้โค้ดเดิม

**สรุป:** Phase 1 = J2K compiler ยิง **ARM64 raw machine code → ELF executable ที่รันบน Termux/Android userspace ได้จริง** จากนั้นค่อยไป x86_64 (Phase 3) แล้วค่อย freestanding/OS (Phase 4-5)

---

## 3. Syntax/สไตล์ภาษา: HolyC + C++ (ตามที่เลือก)

### แนวทาง
ผสมจุดเด่นสองภาษา:

| เอามาจาก HolyC | เอามาจาก C++ |
|---|---|
| ไม่บังคับ header/include ซับซ้อน | `class`/`struct` มี method ผูกกับ type |
| Inline ASM ง่ายๆ ฝังในโค้ดได้ | Type system ที่เข้มงวดกว่า (ลด bug จาก HolyC ที่หลวมไป) |
| Auto-run เขียนแล้วรันได้ไว รู้สึกเหมือนสคริปต์ | Operator overloading (เบาๆ พอ) |
| ไม่มี pointer แบบซับซ้อนเวอร์ HolyC (implicit) | Generic แบบง่าย (template เบาๆ ไม่เอาความซับซ้อนแบบ C++ เต็ม) |

### สิ่งที่ J2K **จะไม่เอา** จากทั้งสองภาษา (บทเรียนจากปัญหาจริง)
- **ไม่เอา** HolyC's weak typing ทั้งหมด (Terry Davis เองก็ยอมรับว่ามันทำให้ debug ยาก เพราะทุกอย่างแปลงเป็น I64 ได้หมด) → J2K จะมี type checking ที่ชัดเจนกว่า
- **ไม่เอา** C++ template metaprogramming เต็มรูปแบบ (ซับซ้อนเกินไป, compile time ระเบิด, error message อ่านไม่รู้เรื่อง) → เอาแค่ generic แบบจำกัด
- **ไม่เอา** C++ multiple inheritance (เป็นแหล่ง bug ระดับ ABI ที่ซับซ้อนสุดของ C++, vtable ซ้อนกันยุ่งมาก) → single inheritance + interface พอ

### คำถามที่ต้องตอบก่อนเริ่มเขียน grammar (จะถามในเอกสารแยก `syntax-design.md` ภายหลัง)
- มี garbage collector ไหม หรือ manual memory (`malloc/free` แบบ C) หรือกึ่งอัตโนมัติแบบ RAII ของ C++?
- struct มี default constructor/destructor อัตโนมัติไหม (C++ style) หรือ ต้องเรียกเองแบบ C?
- ต้องการ namespace ไหม หรือใช้ prefix แบบง่ายพอ?

---

## 4. บทเรียนจากคนที่ทำมาก่อน (C++ กับ HolyC เจออะไร แก้ยังไง)

### C++ (Bjarne Stroustrup, เริ่ม 1979 ในชื่อ "C with Classes")
- **ปัญหา:** ต้องเข้ากันได้กับ C เดิม (backward compatibility) ทำให้ต้องแบกภาระ syntax เก่าตลอดชีวิตภาษา
  → **บทเรียนสำหรับ J2K:** เราไม่มีภาระนี้ เพราะเป็นภาษาใหม่ 100% ไม่ต้อง compat กับอะไร ใช้โอกาสนี้ออกแบบ syntax ให้สะอาดตั้งแต่ต้น
- **ปัญหา:** Compile time ช้ามากเพราะ header-based compilation (include ซ้ำๆ), แก้ด้วย modules (C++20) ซึ่งมาช้ามาก 40 ปีหลังภาษาเกิด
  → **บทเรียน:** J2K ควรออกแบบระบบ module/import ที่ไม่ใช้ text-include ตั้งแต่ day 1
- **ปัญหา:** Undefined Behavior เยอะมาก (ทำให้ compiler optimize แบบที่ทำให้ bug ยากคาดเดา)
  → **บทเรียน:** กำหนดพฤติกรรมให้ชัดเจนที่สุดเท่าที่ทำได้ แม้จะช้ากว่านิดหน่อยตอนแรก

### HolyC (Terry Davis, TempleOS, เดี่ยวเขียนทั้ง compiler+OS)
- **ปัญหา:** ทำคนเดียวทั้ง OS + compiler + ภาษา ทำให้ scope ใหญ่มาก ใช้เวลาหลักสิบปี
  → **บทเรียน:** J2K ก็ทำคนเดียวเหมือนกัน → ต้อง **แบ่งเฟสเล็กๆ ชัดเจน** (roadmap นี้) ไม่งั้นจะจมกับ scope ใหญ่แบบ Terry
- **ปัญหา:** Type system หลวม (ทุกอย่างคือ I64/F64) ทำให้เขียนเร็วตอนแรก แต่ debug ยากขึ้นเมื่อโปรเจกต์ใหญ่
  → **บทเรียนตรงกับที่เขียนไว้ข้อ 3:** เข้มงวดกว่า HolyC นิดหน่อย
- **จุดที่ทำถูก:** Compiler เขียนด้วยภาษาตัวเอง (self-hosting) ตั้งแต่เนิ่นๆ ทำให้ทุก feature ใหม่ถูกทดสอบผ่านการใช้งานจริงทันที
  → **บทเรียน:** J2K ควร self-host ให้เร็วที่สุดเท่าที่จะทำได้ (Phase 2) เหมือนที่ JPP ทำสำเร็จมาแล้ว

---

## 5. Phase Roadmap

### Phase 0 — เตรียมความรู้ (ก่อนเขียนโค้ดบรรทัดแรก)
เป้าหมาย: เข้าใจพอที่จะไม่ต้องหยุดกลางทางเพื่อไปหาความรู้พื้นฐาน

- [ ] อ่าน ARM64 (AArch64) ISA reference โดยเฉพาะ: register convention (AAPCS64), instruction encoding ของกลุ่มที่ต้องใช้ (data processing, load/store, branch)
- [ ] เข้าใจ ELF file format (header, program header, section header) แบบเขียนมือได้
- [ ] ทบทวนของเก่าจาก JPP: ปัญหา SP vs XZR, CBNZ, branch patching, buffer overflow ที่เจอมา — สรุปเป็น checklist กันพลาดซ้ำ
- [ ] ออกแบบ syntax คร่าวๆ ของ J2K (แยกไฟล์ `syntax-design.md`) — **ทำหลังจากตัดสินใจ decision รอบ 1-6 ในข้อ 8 ครบแล้ว** (ตอนนี้ครบแล้ว พร้อมออกแบบได้)
- [x] ตัดสินใจ bootstrap chain: **ไล่ ASM เป็นขั้นๆ** (ARM64 asm → J2K Assembler → J2K Compiler v0 → v1 → self-hosting) ตามข้อ 8.9 ✅
- [x] เขียน ELF ARM64 "Hello exit code" ด้วยมือ (hardcode bytes) แล้วรันผ่าน Termux ได้ ✅ (2026-08-21 — ดู Weekly Log)

**Exit criteria:** เขียน ELF ARM64 "Hello exit code" ด้วยมือ (hardcode bytes) แล้วรันผ่าน Termux ได้ — **ผ่านแล้ว ✅**

### Phase 1 — Bootstrap Chain (ASM → J2K Assembler → J2K Compiler v0/v1)
เป้าหมาย: ไล่สร้างเครื่องมือทีละขั้นตาม chain ในข้อ 8.9 จนได้ J2K compiler ตัวที่ compile ภาษา J2K subset เล็กๆ ได้จริง

- [x] **ขั้น 1 — J2K Assembler** (เขียนด้วย ARM64 asm ล้วน): เครื่องมือแปลง text (mnemonic ง่ายๆ) → machine code bytes + เขียน ELF ได้ ✅ (2026-08-21 — v0.2 รองรับ `mov`/`add`/`sub`/`cmp`/`svc`, ทดสอบผ่าน — ดู Weekly Log)
- [x] **ขั้น 2 — J2K Compiler v0** (emit `.jasm` แล้ว assemble ต่อด้วย J2K Assembler จากขั้น 1): compiler จิ๋วที่สุดที่ compile J2K subset เล็กมาก (แค่ตัวแปร, arithmetic, syscall exit) ได้ ✅ (2026-08-21 — ทดสอบผ่านบนเครื่องจริง `.jk`→`.jasm`→ELF)
- [ ] **ขั้น 3 — J2K Compiler v1** (compile ด้วย v0): เพิ่ม feature ให้ครบตามที่ตัดสินใจในข้อ 8 — lexer/parser เต็มรูปแบบ, if/match/loop, function, struct, array (fixed+dynamic), pointer (`@`/`^`), memory model (`let`/`raw`)
- [ ] ทดสอบ: เขียนโปรแกรม J2K เล็กๆ (fibonacci, bubble sort) compile แล้วรันได้จริงด้วย v1

**Exit criteria:** เขียนโปรแกรม J2K 5 ไฟล์ต่างๆ กัน compile ผ่าน v1 แล้ว "เอาต์พุตตรงกับที่ควรจะเป็น" ทุกไฟล์

### Phase 2 — Self-Hosting
เป้าหมาย: เขียน J2K compiler ด้วยภาษา J2K เอง

- [ ] เขียน lexer/parser/codegen เวอร์ชัน J2K โดยใช้ bootstrap compiler (Phase 1) compile ตัวมันเอง
- [ ] Bootstrap คอมไพล์ compiler เวอร์ชัน J2K → ได้ binary ใหม่
- [ ] เอา binary ใหม่มาคอมไพล์ compiler เวอร์ชัน J2K ตัวเองอีกรอบ (self-compile รอบสอง) → ผลลัพธ์ต้องตรงกัน (bit-identical หรืออย่างน้อย behavior เหมือนกัน) — นี่คือจุดพิสูจน์ self-hosting สำเร็จ

**Exit criteria:** J2K compile ตัวเองได้ 2 รอบติดต่อกัน ไม่ต้องพึ่ง bootstrap C++ compiler อีกต่อไป

### Phase 3 — x86_64 Backend
เป้าหมาย: เพิ่ม backend ที่สอง ยืนยันว่า compiler ออกแบบมาแยก frontend/backend จริง

- [ ] ศึกษา x86_64 instruction encoding (โดยเฉพาะ REX prefix, ModRM, SIB — ซับซ้อนกว่า ARM64 ตรงที่ variable-length encoding)
- [ ] เพิ่ม codegen backend สำหรับ x86_64 (frontend/AST ใช้ร่วมกับ ARM64)
- [ ] ทดสอบผ่าน QEMU user-mode (`qemu-x86_64` รันบน Termux ได้ ไม่ต้อง full-system emulation)

**Exit criteria:** โปรแกรม J2K เดียวกัน compile ได้ทั้ง ARM64 และ x86_64 output แล้วให้ผลลัพธ์เหมือนกัน

### Phase 4 — Freestanding Mode
เป้าหมาย: compile โค้ดที่ไม่พึ่ง OS/libc เลย (พื้นฐานสำหรับเขียน OS)

- [ ] เพิ่มโหมด compile แบบไม่ link libc, ไม่มี syscall wrapper อัตโนมัติ
- [ ] จัดการ memory เองทั้งหมด (ไม่มี malloc จาก OS, ใช้ static memory หรือเขียน allocator เอง)
- [ ] ทดสอบ: เขียนโปรแกรมที่รันตรงบน "bare" ARM64 ผ่าน QEMU -kernel โดยไม่มี OS ใดๆ ห่อ

**Exit criteria:** โปรแกรม J2K freestanding รันบน QEMU -M virt (ARM64) แสดงผลผ่าน UART ได้

### Phase 5 — Toy OS
เป้าหมาย: kernel เล็กๆ เขียนด้วย J2K

- [ ] Bootloader ขั้นต่ำ (หรือใช้ standard boot protocol ที่มีอยู่)
- [ ] Kernel entry, จัดการ interrupt/exception ขั้นพื้นฐาน
- [ ] Memory management เบื้องต้น (page table ARM64)
- [ ] Output ผ่าน UART หรือ framebuffer ง่ายๆ

**Exit criteria:** boot ได้จริงบน QEMU และถ้าเป็นไปได้ บนฮาร์ดแวร์จริง (เช่น Raspberry Pi ที่เป็น ARM64 หาซื้อง่าย)

### Phase 6 — Multi-Target Exploration (Android / HarmonyOS / iOS)
เป้าหมาย: สำรวจความเป็นไปได้ (ไม่ใช่ target หลัก จนกว่า Phase 0-5 เสร็จ)

- [ ] Android: J2K ออก ELF ที่รันผ่าน NDK/NativeActivity ได้ (ใกล้เคียงกับที่ทำใน Angle-turn อยู่แล้ว)
- [ ] HarmonyOS: ศึกษาความเข้ากันได้กับ Linux ARM64 ABI (ยังไม่ชัดเจน ต้องรอข้อมูลเพิ่ม)
- [ ] iOS: ต้องมี Mach-O output + code signing (Apple ปิดมาก) — เก็บเป็นข้อสุดท้ายจริงๆ

---

## 6. Weekly Log (บันทึกทุกสัปดาห์ — เพิ่ม entry ใหม่ไว้บนสุด)

> รูปแบบ: `### YYYY-MM-DD — สรุปสั้นๆ` ตามด้วยหัวข้อ ทำอะไร / เจอปัญหาอะไร / แก้ยังไง / สัปดาห์หน้าจะทำอะไร

### 2026-08-29 (รอบ 10) — v1.3 ออกแบบต่อ: เปลี่ยน type keyword เป็น `i64`, เพิ่ม `ret` ใน j2k_asm, แก้ register mapping ของฟังก์ชันจาก x0-x7 เป็น x19-x26
- **Type keyword `i` -> `i64`**: Jao ทักเองว่า `i i = 10;` (ตัวแปรชื่อ `i` ชนกับ type keyword `i`) อ่านสับสน — ล็อคสำรวจแล้วตรงกับข้อ 8.24 เดิม (`i` เฉยๆ = `i64` โดย default สำหรับภาษาเต็มในอนาคต) เลยให้ Jcmp เขียน `i64` เต็มไปเลยตอนนี้ ดูข้อ 32 ใน syntax-design — แก้ dispatch logic ใน `parse_block`/header parsing ให้ใช้ `match_word` เหมือน keyword อื่น ลบ special-case เดิมทิ้ง, อัปเดตชุดเทส t01-t16 ทั้งหมดเป็น `i64` แล้ว regression ยัง 16/16 ผ่าน
- **j2k_asm เพิ่ม `ret`**: ตรวจพบว่ายังไม่รองรับเลย (fixed encoding `0xD65F03C0`, ไม่มี operand) — จำเป็นสำหรับ function return ใน v1.3 เพิ่ม `try_ret`/`handle_ret` ในไฟล์แล้ว รอผลทดสอบ `test_ret.jasm` (bl->mov x0,42->ret, คาด exit 42) และ regression suite จาก Jao
- **Register mapping ของฟังก์ชัน (ข้อ 33 syntax-design) แก้ไข 2 รอบในวันเดียว**:
  - รอบแรก: ตัดสินใจกับ Jao ว่า param+local ใช้ pool ร่วมกันสูงสุด 8 ตัว (เร็วกว่า spill ไป stack) เลือกใช้ `x0-x7` ก่อน
  - รอบสอง (Jao ถามเรื่อง C ใช้ param กี่ตัว/ARM มี 31 ตัวจะเลือกยังไงให้เร็วสุด): พบว่า x0-x7 เป็น **caller-saved** ตาม AAPCS64 จริง — แปลว่าทุกจุดที่เรียกฟังก์ชัน (`bl`) ต้อง save/restore ตัวแปร caller ลง stack ทุกครั้ง ช้ากว่าที่ควร **เปลี่ยนไปใช้ `x19-x26` (callee-saved) แทน** — ผลคือจุดเรียกฟังก์ชันไม่ต้อง save/restore อะไรเลย แต่ละฟังก์ชัน save/restore แค่ตัวเองตอน prologue/epilogue ครั้งเดียว x0-x7 กลับไปทำหน้าที่ ABI จริง (ส่ง arg เข้า/รับผลกลับชั่วคราว), x9-x17 ยังเป็น compiler scratch เหมือนเดิม, x18 ห้ามใช้ (platform register)
  - รายละเอียดเต็มอยู่ในข้อ 33 ของ syntax-design-16.md (เขียนทับของเดิมแล้ว)
- ยังไม่ได้เริ่มเขียน codegen ของ prologue/epilogue/function-call จริงใน Jcmp-v1.s — รอผลทดสอบ `ret` ก่อน
- สัปดาห์หน้า/ต่อจากนี้: รอผล `test_ret.jasm` + regression -> เริ่มเขียน Jcmp-v1.s จริง (parse function decl, parse call-as-operand, prologue/epilogue ด้วย str/ldr ทีละตัวผ่าน x19-x26, แยก `return` ของ `main` (ยัง exit ตรงๆ) กับฟังก์ชันอื่น (mov x0 + ret))

### 2026-08-29 (รอบ 9) — j2k_asm: เพิ่มรองรับ `sp` ใน `ldr`/`str`/`add`/`sub` (จำเป็นสำหรับ v1.3 function/stack-frame) — เจอ+แก้บั๊ก 2 จุด
- บริบท: เริ่มออกแบบ v1.3 (function support) ตัดสินใจกับ Jao แล้วว่าต้องใช้ real stack-frame (ไม่ใช่ flat-register scheme เดิม) เพื่อรองรับ recursion/multi-function calling convention ให้ถูกต้อง — พบว่า j2k_asm ยังไม่มีทางอ้างอิง `sp` เลย (`parse_register` รู้จักแค่ `x`+เลข) เป็น blocker แรก จึงต้องขยาย assembler ก่อน
- ทำ: เพิ่ม `parse_register_or_sp` helper (คืน reg=31 + is_sp flag เมื่อเจอ `sp`, ไม่งั้น fallback ไป `parse_register` ปกติ) ผูกเข้ากับ `handle_add`/`handle_sub` (accept `sp` เฉพาะ immediate-form ของ Rd/Rn ตามข้อจำกัดจริงของ ARM64 — register-form ใช้ sp ไม่ได้เลย เพิ่ม explicit rejection check กันเข้าใจผิดว่า encode สำเร็จ) และ `handle_ldr`/`handle_str` (Rn/base register รับ `sp` ได้, Rt ยังคงต้องเป็น register ธรรมดา)
- **แก้บั๊ก 1 (ตัวหลัก, กระทบทั้ง `handle_str`/`handle_ldr`)**: หลัง `bl parse_number` (parse ค่า `#offset` เก็บผลไว้ใน `x0`) โค้ดเรียก `bl skip_spaces` ตามด้วย `ldrb w0,[x21]` (เช็ค `]` ปิดท้าย) ก่อนเอา `x0` ไปเช็ค `offset % 8 == 0` — ทั้ง `skip_spaces` และ `ldrb` เขียนทับ `x0`/`w0` ไปแล้ว ค่าที่เอาไปเช็คจริงจึงกลายเป็นไบต์ของ `]` (93) แทนค่า offset จริง (`93 % 8 = 5 ≠ 0` → error เสมอทุกครั้งที่มี `#offset`) — บั๊กนี้มีมาตั้งแต่ v0.3 (ldr/str "build ผ่านแต่ไม่เคยเทสจริง" เพราะตอนนั้นยังไม่มี syntax จองหน่วยความจำให้เทส) ไม่เกี่ยวกับการเพิ่ม `sp` เลย เพิ่งโผล่มาให้เห็นเพราะเป็นครั้งแรกที่เทส ldr/str แบบมี offset จริงจัง — แก้โดยเซฟ `x0` ลง `x10` ทันทีหลัง `parse_number` ก่อนเรียกอะไรต่อ ใช้ `x10` แทนตลอด (ทั้ง mod-8 check และ shift สำหรับ imm12)
- **แก้บั๊ก 2 (จุดเล็ก, ไม่ใช่บั๊กจริง)**: `j2k_asm` **ไม่รองรับ comment (`//`) เลยตั้งแต่แรก** — dispatcher ไม่มี logic ข้าม `//` ถ้าเจอ `/` จะ fallback ไป `parse_error` ทันที ทำให้ไฟล์เทสที่เขียนมือแล้วใส่คอมเมนต์หัวไฟล์ (`test_sp.jasm`) พังทันทีตั้งแต่ byte 0 — ไม่ใช่บั๊กจริง เป็นแค่ syntax ที่ยังไม่เคยออกแบบให้รองรับ (compiler-generated `.jasm` จาก Jcmp ไม่เคยใส่คอมเมนต์ เลยไม่เคยเจอมาก่อน) แก้ปัญหาเฉพาะหน้าด้วยการตัดคอมเมนต์ออกจากไฟล์เทส — **ยังไม่ได้ออกแบบ/เพิ่ม comment support ให้ assembler จริง ค้างไว้ ถามได้ถ้าต้องการให้ทำ**
- กระบวนการ debug: bisect ด้วยไฟล์เทสย่อยหลายไฟล์ (`test_sp_minimal*.jasm`, `test_addspmix.jasm`, `test_ldrstr_noimm.jasm`, `test_ldrstr_imm.jasm` ฯลฯ) + เพิ่ม diagnostic ชั่วคราวใน `parse_error`/error label ต่างๆ ให้ exit code บอกตำแหน่ง byte offset หรือ sentinel เฉพาะจุดที่ error เกิด แทนการเดา — เจอบั๊กจริงหลัง pinpoint ไปที่ offset-mod-8 check โดยเฉพาะ (sentinel เฉพาะจุด) แล้วจำลอง logic ด้วย Python เทียบกับ ASM ทีละบรรทัดจนเจอจุดที่ x0 โดนเขียนทับ — diagnostic ทั้งหมด revert กลับเรียบร้อยแล้วหลังแก้เสร็จ ไม่มีโค้ด debug ค้าง
- ทดสอบ: `test_ldrstr_imm.jasm` (str/ldr + `#offset` กับ register ธรรมดา) → exit 42 ตรงตามคาด ✅, `test_sp.jasm` (sub sp / str [sp,#8] / ldr [sp,#8] / add sp) → exit 42 ตรงตามคาด ✅ (เก็บ 42 ลง stack แล้วโหลดกลับมา), regression เดิม `run_all_tests.sh` ยัง **16/16 PASS** ไม่มีอะไรพัง
- ผลลัพธ์: **`sp` support ใน j2k_asm ผ่านแล้ว ✅ (add/sub/ldr/str ทั้งหมด)** — พร้อมเริ่มเขียน stack-frame based local variable สำหรับ v1.3 function ต่อได้แล้ว
- ข้อจำกัดที่ยังค้างอยู่: comment (`//`) ยังไม่รองรับใน j2k_asm (ดูบั๊ก 2 ด้านบน — ยังไม่ได้ออกแบบ), `*=`/`/=` ยังไม่รองรับ (ต้อง mul/udiv/sdiv), ยังไม่มี `for` loop
- สัปดาห์หน้า: เริ่ม **v1.3 — function support** จริงจัง — stack-frame prologue/epilogue (`sub`/`add sp`), local variable ผ่าน `[sp, #offset]` แทน flat register x1-x7, parameter passing ผ่าน x0-x7, `bl`/`ret` calling convention, ขยาย grammar ให้เรียกฟังก์ชันเป็น operand ได้

### 2026-08-21 (รอบ 8) — J2K Compiler v1.2 (while/break/continue/compound-assign) ทดสอบผ่านครบ 16/16 เทส
- เปลี่ยน convention การตั้งชื่อไฟล์ (ตามที่ Jao กำหนด): compiler ใช้ชื่อไฟล์เดียว **`Jcmp-v1.s`** ตลอดไป อัปเดตเนื้อหาข้างในไปเรื่อยๆ ตาม sub-step (ไม่แยกไฟล์ `v1_1`/`v1_2` อีกต่อไป) เช่นเดียวกัน assembler เปลี่ยนชื่อเป็น **`j2k_asm_v1.s`**
- ทำ: เพิ่ม `while`, `break`/`continue`, compound assignment (`++` `--` `+=` `-=`) ต่อในไฟล์ `Jcmp-v1.s` เดิม — ใช้ label/branch ของ j2k_asm ที่มีอยู่แล้ว ไม่ต้องแก้ assembler เพิ่ม, เพิ่ม loop-context stack (global, .bss) สำหรับ track innermost loop ของ break/continue รองรับ nested loop ถูกต้องผ่าน call-stack recursion
- เขียนชุดทดสอบ 16 ไฟล์ (`tests/t01..t16`) + สคริปต์ `run_all_tests.sh` (build ทั้งคู่ครั้งเดียว รันทุกเทสอัตโนมัติ, auto-detect โฟลเดอร์ `tests/`/`test/`) ครอบคลุม v0 (arithmetic) + v1.1 (if/else/elif/nested-if) + v1.2 (while/compound-assign/break/continue/nested-while/nested-break) — ตามที่ Jao ขอให้เขียนเทสทั้งหมดพร้อมกันเพราะไม่แน่ใจว่าจะผ่านหรือไม่
- แก้บั๊ก 2 จุดที่เจอระหว่างทดสอบบนเครื่องจริง:
  1. **register-clobber ใน `parse_if_chain`** (segfault ตอนทดสอบ v1.1 ครั้งแรกสุด — แก้ไปแล้วในรอบ 7): ใช้ `x2`/`x3` เก็บค่าข้ามการเรียก `parse_operand` ครั้งที่สอง ซึ่งใช้ `x0-x5` เป็น scratch ภายใน แก้โดยย้ายไปใช้ `x12`/`x13`/`x14`/`x9` แทน
  2. **dispatch collision ระหว่างตัวแปรชื่อ `i` กับ type keyword `i`**: statement dispatch เดิมเช็คแค่ตัวอักษรตัวแรกเป็น `i` แล้วแยกแค่ "if" vs "i "+เว้นวรรค(declaration) แต่ไม่ครอบคลุมกรณีตัวแปรชื่อ `i` เดี่ยวๆ ที่ใช้ใน assignment statement (เช่น `i++;` ซึ่งเป็นชื่อตัวแปรลูปที่พบบ่อยที่สุด) — ตัวอักษรตัวที่สองเป็น `+` ไม่ตรงกับ `f` (if) และไม่ใช่เว้นวรรค (declaration) เดิมเผลอ fallback ไปที่ declaration ทำให้ parse ผิดพลาด แก้โดยเพิ่มเงื่อนไข: ถ้าไม่ตามด้วยเว้นวรรค/tab ให้ถือเป็น assignment statement แทน — เจอจากการรันชุดทดสอบทั้งหมดพร้อมกัน (7/16 เทสพังพร้อมกันด้วยสาเหตุเดียวกัน ตรงกับที่ Jao กังวลว่าควรเขียนเทสให้ครบตั้งแต่แรกเพื่อจับ pattern บั๊กแบบนี้ได้)
- ทดสอบ: รัน `run_all_tests.sh` บน Termux จริง → **16/16 PASS** ครบทุกเทส รวมกรณี nested while, nested break (break ต้องกระโดดไปแค่ loop ชั้นในสุดเท่านั้น), if/elif ซ้อนอยู่ใน while
- ผลลัพธ์: **v1.2 ผ่านแล้ว ✅**
- ข้อจำกัดที่ยังค้างอยู่ (บันทึกในคอมเมนต์หัวไฟล์): `*=`/`/=` ยังไม่รองรับ (j2k_asm ยังไม่มี `mul`/`udiv`/`sdiv` mnemonic — ต้องขยาย assembler ก่อนถึงจะทำได้ เป็นงานแยกต่างหาก), ยังไม่มี `for` (ทั้ง C-style และ range-style), ตัวแปรยังเป็น flat global ไม่มี block scoping จริง
- สัปดาห์หน้า: ตัดสินใจว่าจะทำ **v1.3 — `for` loop** ต่อ หรือจะไปทำ **v1.4 — function** (ประกาศ+เรียกได้หลายตัว) ก่อน เพราะ `for` ไม่ได้ block อะไรต่อ (มี `while` ทดแทนได้ในทางปฏิบัติ) ในขณะที่ function เป็นก้าวสำคัญกว่าสำหรับเป้าหมาย self-hosting ในระยะยาว — รอ Jao ตัดสินใจ

### 2026-08-21 (รอบ 7) — J2K Compiler v1.1 (if/else) ทดสอบผ่านบนเครื่องจริง
- ตัดสินใจ+บันทึก syntax ใหม่ (ยืนยันกับ Jao แล้ว, บันทึกลง syntax-design.md ข้อ 7 เป็น "กรณีพิเศษ จำเป็นต้องมี"): `else`/`else if` ตามแนว C ตรงๆ (ไม่มี `elif` แบบ Python) — `} else if COND { ... } else { ... }`
- แบ่ง Phase 1 ขั้น 3 เป็น sub-step: v1.1 if/else → v1.2 loop → v1.3 function → v1.4 struct/array → v1.5 pointer/memory model (เรียงตามลำดับที่แต่ละอันต่อยอดจากอันก่อนได้จริง และทดสอบเป็นระยะได้)
- ทำ: เขียน `Jcmp_v1_1.s` ต่อยอดจาก v0 — เพิ่ม `if`/`else if`/`else`, comparison operator (`==` `!=` `<` `>` `<=` `>=`), ใช้ label/branch ของ j2k_asm v0.3 ที่มีอยู่แล้วเต็มที่ (ไม่ต้องแก้ assembler เพิ่มเลย) โครงสร้างเปลี่ยนจาก linear statement list (v0) เป็น recursive-descent (`parse_block` เรียกตัวเองผ่าน `parse_if_chain` รองรับ if ซ้อน if ได้)
- แก้บั๊ก 1 จุดที่เจอระหว่างทดสอบ (segfault): `parse_if_chain` ใช้ `x2`/`x3` เก็บค่า regA/opcode ข้ามการเรียก `parse_operand` ครั้งที่สอง แต่ `parse_operand` (ผ่าน `parse_ident`/`symtab_find`) ใช้ `x0-x5` เป็น scratch ตามธรรมเนียมเดิม เลยไปเขียนทับค่าที่เก็บไว้ — แก้โดยย้ายไปใช้ `x12`/`x13`/`x14`/`x9` (registers ที่ธรรมเนียมกำหนดไว้ว่า "ปลอดภัยข้ามการเรียก" ตั้งแต่ v0 อยู่แล้ว แต่ตอนเขียน v1.1 ลืมทำตามธรรมเนียมเดิม)
- ทดสอบ: `test_if.jk` (`i x=10; if x>5 { return 1; } else { return 0; }`) → `Jcmp` → `.jasm` → `j2k_asm_v0.3` → ELF → รันจริงบน Termux → `echo $?` ได้ `1` ตรงตามคาด
- ผลลัพธ์: **v1.1 (if/else) ผ่านแล้ว ✅**
- ข้อจำกัดที่ตั้งใจไว้ (บันทึกในคอมเมนต์หัวไฟล์): เงื่อนไขฝั่งซ้ายต้องเป็นตัวแปรเสมอ (ตรงกับข้อจำกัดเดิมของ arithmetic), ไม่มี `&&`/`||`, ตัวแปรยังเป็น flat global ไม่มี block scoping จริง
- สัปดาห์หน้า: เริ่ม **v1.2 — loop** (while/for) — แต่ syntax-design.md ยังมีหัวข้อ "⚠️ ยังไม่ได้ออกแบบ: while/for loop syntax" ค้างอยู่ ต้องออกแบบ+ยืนยันกับ Jao ก่อนเริ่มเขียนโค้ด (เหมือนที่ทำกับ else/else-if รอบนี้)

### 2026-08-21 (รอบ 6) — J2K Compiler v0 (Jcmp) ทดสอบผ่านบนเครื่องจริง: pipeline .jk→.jasm→ELF ทำงานครบ
- แก้บั๊ก 2 จุดที่เจอระหว่างทดสอบบนเครื่องจริง:
  1. **register width mismatch**: `mov x14, w0` ผสม 64-bit กับ 32-bit ไม่ได้ (assembler error ตั้งแต่ build) — แก้เป็น `mov x14, x0`
  2. **shared-buffer clobber bug**: `symtab_add` ไม่เคย increment ตัวนับ `x17` (ตาราง symbol เลยว่างตลอด) และ `name_buf` (buffer ชั่วคราวเก็บชื่อ identifier ที่เพิ่ง parse) ถูกใช้ซ้ำทั้งตอนอ่านชื่อตัวแปรฝั่งซ้าย (เช่น `z`) และตอนอ่าน operand ฝั่งขวา (`x`, `y`) — พอ parse ถึง operand ตัวที่สอง มันเขียนทับชื่อตัวแปรฝั่งซ้ายที่เก็บไว้ก่อนหน้า ทำให้บันทึกชื่อผิดตัวลงตาราง แก้โดยเพิ่ม `lhs_name_buf` แยกต่างหาก + `save_lhs_name` subroutine คัดลอกชื่อออกมาเก็บทันทีหลัง parse ชื่อตัวแปร ก่อนที่ parse_operand จะไปใช้ `name_buf` ซ้ำ
- ทดสอบ: `test.jk` (`i x=5; i y=3; i z=x+y; return z;`) → `Jcmp test.jk test.jasm` → เช็ค `test.jasm` ได้ text ที่ถูกต้อง (`mov x1,5 / mov x2,3 / mov x3,x1 / add x3,x3,x2 / mov x0,x3 / mov x8,93 / svc 0`) → `j2k_asm_v0.3 test.jasm test_out` → รัน `test_out` บน Termux จริง → `echo $?` ได้ `8` ตรงตามคาด
- ผลลัพธ์: **Phase 1 ขั้น 2 (J2K Compiler v0) ผ่านแล้ว ✅** — pipeline เต็มทำงานจริง: `.jk` (J2K subset) → `Jcmp` (compiler v0) → `.jasm` (text) → `j2k_asm_v0.3` (assembler) → ELF ARM64 รันได้จริงบนเครื่อง
- สัปดาห์หน้า/ขั้นต่อไป: ตัดสินใจว่าจะเริ่ม **Phase 1 ขั้น 3 — J2K Compiler v1** (เพิ่ม feature ให้ครบตามข้อ 8 ทั้งหมด — lexer/parser เต็มรูปแบบ, if/match/loop, function, struct, array, pointer) เลย หรือจะเก็บงานเสริมของ v0 ก่อน (เช่น ทดสอบ edge case เพิ่ม, ทำ error message ให้ละเอียดขึ้นกว่า "parse or I/O error" เดียวรวมทุกกรณี ซึ่งทำให้ debug รอบนี้ช้าเพราะแยกไม่ออกว่า error จากจุดไหน) — รอ Jao ตัดสินใจ

### 2026-08-21 (รอบ 5) — เริ่ม J2K Compiler v0 (Jcmp_v0): .jk subset -> .jasm text (ยังไม่ทดสอบบนเครื่องจริง)
- ตัดสินใจ (ยืนยันกับ Jao แล้ว): Jcmp v0 **build ด้วย `as`/`ld` ตรงๆ** (bootstrap เหมือน j2k_asm v0.3) และ **emit เป็นไฟล์ `.jasm` (text)** แล้วส่งต่อให้ j2k_asm v0.3 assemble เป็น ELF อีกที (ไม่ใช่ compile ผ่าน j2k_asm เอง, ไม่ใช่ emit ELF ตรงๆ) — pipeline: `.jk` → Jcmp_v0 → `.jasm` → j2k_asm_v0.3 → ELF
- ทำ: เขียน `Jcmp_v0.s` รองรับ subset เล็กที่สุดตามที่ roadmap ขั้น 2 ระบุ (ตัวแปร `i`, arithmetic บวก/ลบ 1 operator/บรรทัด, `return`) — syntax ที่รองรับทั้งหมดเป็น subset ของ syntax-design.md ข้อ 3/6/13/17/21 ที่ล็อคไว้แล้ว ไม่มีการคิด syntax ใหม่
- ตรวจสอบเบื้องต้น (static เท่านั้น เหตุผลเดียวกับ v0.3 — sandbox เป็น x86_64 build ARM64 จริงไม่ได้): ไม่มี label ซ้ำ, ไม่มี branch target ที่ยังไม่ประกาศ — **ยังไม่ได้ build/รันบน Termux เลย**
- ข้อจำกัดที่ตั้งใจไว้ (บันทึกในคอมเมนต์หัวไฟล์): เฉพาะ type `i`, ไม่มี if/while/for/function อื่น, นิพจน์สูงสุด 1 operator/บรรทัด ไม่มีวงเล็บ, ไม่มีเลขลบ/ทศนิยม, ตัวแปรสูงสุด 7 ตัว (map ตรงไป x1-x7), ต้องมี `return` ปิดท้ายเสมอ
- สัปดาห์หน้า/ขั้นต่อไป: **ต้อง build+ทดสอบบน Termux จริงก่อน** ด้วย pipeline เต็ม `Jcmp_v0 test.jk test.jasm` → `j2k_asm_v0.3 test.jasm test_out` → รัน `test_out` คาด exit code 8 (จากตัวอย่าง `x=5,y=3,z=x+y,return z`) — รอผลทดสอบจาก Jao ก่อนถือว่า Phase 1 ขั้น 2 (v0) ผ่าน

### 2026-08-21 (รอบ 4) — J2K Assembler v0.3 ทดสอบผ่านบนเครื่องจริง: label/branch ทำงานถูกต้อง
- ทำ: rename `j2k_asm_v0.3.s` ให้ตรง convention, build ด้วย `as`/`ld`, ทดสอบ `test3.jasm` (loop นับ 0..5 ด้วย `cmp`/`b.ge`/`add`/`b` วน label `loop`/`done`)
- ทดสอบ: รันบน Termux จริง → `./out3 ; echo $?` ได้ `5` ตรงตามคาด
- ผลลัพธ์: **v0.3 ผ่านแล้ว ✅** — two-pass architecture (pass 1 สร้างตาราง label, pass 2 encode+resolve branch offset) ทำงานถูกต้องจริง รองรับ `label:`, `b`/`b.cond`/`bl`, และตัว `ldr`/`str` build ผ่าน (แม้ยังไม่ได้เทสจริงเพราะ jasm ยังไม่มี syntax จองหน่วยความจำ — ค้างไว้)
- สัปดาห์หน้า: ตัดสินใจว่าจะออกแบบ mnemonic จองหน่วยความจำ (สำหรับเทส ldr/str) ก่อน หรือจะถือว่า J2K Assembler (ขั้น 1 ของ Phase 1) พอเพียงแล้วเริ่มขั้น 2 — J2K Compiler v0 เลย (รอ Jao ตัดสินใจ)

### 2026-08-21 (รอบ 3) — เริ่ม J2K Assembler v0.3: two-pass, label/branch, ldr/str (ยังไม่ทดสอบบนเครื่องจริง)
- ทำ: เขียน `j2k_asm_v0.3.s` ต่อจาก v0.2 — ปรับสถาปัตยกรรมเป็น **two-pass** (pass 1 นับตำแหน่ง instruction + สร้างตาราง label, pass 2 encode+เขียนจริงพร้อม resolve branch offset จากตาราง) เพิ่ม mnemonic ใหม่: label definition (`name:`), `b`/`b.cond`/`bl`, `ldr`/`str` (x-register, unsigned offset, offset ต้องหาร 8 ลงตัว)
- ตรวจสอบเบื้องต้น (แบบ static เท่านั้น — เครื่อง sandbox เป็น x86_64 ไม่มี ARM64 cross-assembler ให้ build จริง): เช็คไม่มี label ซ้ำ, ไม่มี branch target ที่ไม่ได้ประกาศ — แต่ **ยังไม่ได้ build/รันจริงบน Termux เลย**
- ข้อจำกัดที่ตั้งใจไว้ใน v0.3: label ต้องขึ้นต้นด้วยตัวอักษร/`_` เท่านั้น (ไม่รองรับ label ตัวเลขล้วน), label ต้องอยู่บรรทัดของตัวเอง (จะพ่วง instruction ต่อท้ายบรรทัดเดียวกันได้ แต่ยังไม่ได้เทส), ldr/str ยังไม่มี syntax จองหน่วยความจำ (buffer) ในภาษา jasm เอง เลยยังเทส ldr/str จริงจังไม่ได้จนกว่าจะออกแบบ mnemonic นั้นเพิ่ม (ค้างไว้)
- สัปดาห์หน้า/ขั้นต่อไป: **ต้อง build+ทดสอบบน Termux จริงก่อน** ด้วย `test3.jasm` (loop ตัวอย่างในคอมเมนต์หัวไฟล์ คาด exit code 5) — รอผลทดสอบจาก Jao ก่อนถือว่า v0.3 ผ่าน

### 2026-08-21 (รอบ 2) — J2K Assembler v0.2 ทดสอบผ่าน: mov/add/sub/cmp/svc ทำงานถูกต้อง
- ทำ: build `j2k_asm_v0.2.s` ด้วย `as`/`ld` (one-time bootstrap step ตามข้อ 32 syntax-design.md) ได้ binary `j2k_asm_v0.2`
- ทดสอบ: เขียนไฟล์ `test2.jasm` (`mov x0,5` / `mov x1,37` / `add x0,x0,x1` / `mov x8,93` / `svc 0`) → assemble ด้วย `j2k_asm_v0.2` → ได้ ELF ARM64 ชื่อ `out2` → รันบน Termux จริง → `echo $?` ได้ `42` ตรงตามที่คาดไว้ในคอมเมนต์หัวไฟล์
- ผลลัพธ์: **Phase 1 ขั้น 1 (J2K Assembler) ผ่านแล้ว ✅** — รองรับ mnemonic ครบตามที่ v0.2 วางแผนไว้ (`mov` register/immediate, `add`/`sub` register+register และ register+immediate, `cmp` register/immediate, `svc`)
- ยังไม่มี: label/branch, `ldr`/`str` mnemonic (ตามที่ comment ในไฟล์ระบุไว้ว่าเลื่อนไป v0.3 เพราะต้องทำ two-pass assembler รองรับ forward-reference label)
- สัปดาห์หน้า: เริ่ม v0.3 — เพิ่ม label/branch + `ldr`/`str`, ออกแบบ two-pass assembler (pass 1 เก็บตำแหน่ง label, pass 2 patch offset จริง)

### 2026-08-21 — Phase 0 exit criteria สำเร็จ: ELF ARM64 hand-written exit code
- ทำ: เขียนสคริปต์ประกอบ ELF64 executable (AArch64) เอง — เข้ารหัส `MOVZ`/`SVC` เป็น machine code ด้วยมือ (bit-field ตาม AArch64 ISA) + pack ELF header/program header เองทั้งหมด ไม่ใช้ `as`/`ld`/`gcc`
- ทดสอบ: รันบน Termux จริง (ARM64) → `exit(42)` → `echo $?` ได้ `42` ตรงตามคาด
- ผลลัพธ์: **Phase 0 exit criteria ผ่านแล้ว ✅** ("เขียน ELF ARM64 Hello exit code ด้วยมือ hardcode bytes แล้วรันผ่าน Termux ได้")
- สัปดาห์หน้า: เริ่ม Phase 1 ขั้น 1 — J2K Assembler (เขียนด้วย ARM64 asm ล้วน แปลง mnemonic ง่ายๆ → machine code bytes + เขียน ELF ได้) เริ่มจาก mov + svc ก่อน

### 2026-08-19 (รอบ 2) — ปิดคำถามออกแบบรอบ 2 + ล้างข้อมูลอุปกรณ์ออกจาก roadmap
- แก้ไข: ลบชื่อรุ่นมือถือ (Huawei Kirin 980/Mali-G76) ออกจากส่วนหัวเอกสาร เหลือแค่ "มือถือ (ARM64)"
- ยืนยัน: memory allocator = custom heap + leak-protection ตามที่ระบุไว้แล้วในข้อ 8.1 (ตรงกับที่ต้องการ)
- ยืนยัน: bootstrap compiler เขียนด้วย **C++** ไม่ใช่ Assembly/machine code — ดูเหตุผลข้อ 8.5
- ลบหมายเหตุคลุมเครือเดิมในข้อ 8.4 ที่พูดถึง "ลบโทรศัพท์ออกจากโหลดแมพ" เพราะทำเสร็จแล้วรอบนี้

### 2026-08-19 — เริ่มต้นโปรเจกต์ J2K, สร้าง roadmap + ปิดคำถามออกแบบภาษารอบแรก
- ตัดสินใจ: ภาษาใหม่ 100% ไม่ต่อยอดโค้ด JPP แต่ใช้บทเรียนเดิม
- ตัดสินใจ: Phase 1 target = ARM64 ELF (เหตุผลดูข้อ 2)
- ตัดสินใจ: syntax แนว HolyC + C++
- ตัดสินใจ: ชื่อภาษา = J2K (ยืนยันแล้ว)
- ตัดสินใจ: Memory model = hybrid manual + auto (escape analysis) — ดูข้อ 8.1
- ตัดสินใจ: Type system = static + inference — ดูข้อ 8.2
- ตัดสินใจ: Error handling = exception + result type ผสมกัน — ดูข้อ 8.3
- ตัดสินใจ: Concurrency ออกแบบเผื่อไว้ใน Phase 0 แต่ implement จริงหลัง Phase 3 — ดูข้อ 8.4 (มีจุดที่ต้องยืนยันซ้ำ)
- ตัดสินใจ: Publish GitHub แบบ private จนกว่า self-hosting (Phase 2) เสร็จ
- งานถัดไป: เริ่ม Phase 0 — อ่าน ARM64 ISA reference, เขียน ELF hello-world ด้วยมือ, เริ่มร่าง syntax-design.md (คีย์เวิร์ด let/raw, try/catch, result type)

---

## 7. Checklist คำถามที่ยังไม่ตอบ (ปิดครบทุกข้อแล้ว — รอบคำถามสุดท้าย)

- [x] ชื่อภาษาสุดท้าย: **J2K** ✅ (ยืนยันแล้ว)
- [x] Memory model: **Hybrid** ✅ — manual (`alloc`/`free` แบบ C) เป็นทางเลือกสำหรับงานที่ต้อง control เต็มที่ + มีโหมดจัดการอัตโนมัติ (compiler วิเคราะห์ scope/lifetime ให้ แทรก free ให้เองเมื่อรู้ได้ชัดเจน คล้าย Rust borrow-checker แบบเบาๆ แต่ผู้เขียนเลือกปิดเป็น manual ได้ต่อ variable/scope) — รายละเอียดดูข้อ 8
- [x] Publish GitHub: **Private ก่อน อาจ public ทีหลังแต่ต้องมี license ห้ามดัดแปลง/ห้ามอ้างสิทธิ์เป็นของตัวเอง (all-rights-reserved-style / no-derivatives)** ✅
- [x] เวลาที่ใช้ได้จริง/สัปดาห์: **ตัดโปรเจกต์ Angle-turn ออกก่อน (ยังเข้าใจภาษาไม่ลึกพอ), ทิ้ง JPP ไปเลย** — เหลือ balance แค่กับเรียน IT ปี 1 เท่านั้น ทำให้มีเวลาให้ J2K มากขึ้น ✅
- [x] Concurrency (ข้อ 8.4): **ยืนยันแล้วว่าต้องมี async จริง ไม่ใช่แค่เผื่อที่ไว้เฉยๆ** + ต้องสั่งงาน CPU/thread ได้ผ่าน `import cpu; using cpu;` — รายละเอียดดูข้อ 8.4 (ปรับปรุงแล้ว) ✅
- [x] HarmonyOS compatibility (Phase 6): **เก็บไว้ในแผน แต่ไม่ใช่ priority สำคัญ** ✅

---

## 8. Language Design Decisions (ตัดสินใจแล้ว รอบคำถามที่ 2)

### 8.1 Memory Model — Hybrid (Manual + Smart Automatic) + Custom Heap Allocator
เป้าหมาย: "ทำให้ compiler ฉลาดขึ้น" ตามที่ผู้ใช้ต้องการ

- ค่าเริ่มต้น: ตัวแปร local ที่ compiler พิสูจน์ lifetime ได้ชัดเจน (ไม่หลุดออกจาก scope, ไม่ถูก return/เก็บที่อื่น) → **แทรก free ให้อัตโนมัติ** ตอน compile time (ไม่มี runtime GC, ไม่มี reference counting ที่กิน performance)
- ถ้า lifetime วิเคราะห์ไม่ได้ชัดเจน (เช่น heap object ที่ pass ข้าม function เยอะ) → บังคับให้ผู้เขียน `alloc`/`free` เอง แบบ manual (compiler เตือนถ้า path ไหนลืม free)
- คีย์เวิร์ดคร่าวๆ (ตัวอย่าง แก้ได้ตอนออกแบบ syntax จริง): `let` = auto-managed, `raw` = manual control เต็มที่
- นี่คือจุดที่ต้องทำ **escape analysis** ใน compiler — งานยากสุดใน Phase 2 (self-hosting) ควรเตรียมอ่านเรื่องนี้ล่วงหน้าใน Phase 0

**Allocator: Custom heap เขียนเอง + ระบบป้องกัน RAM รั่ว**
- ไม่พึ่ง `malloc` ของ libc — J2K เขียน heap allocator เองทั้งหมด (free-list หรือ buddy allocator แบบง่าย เลือกตอนลงมือ Phase 1)
- ระบบป้องกันหน่วยความจำรั่ว (leak protection) ที่ควรมี:
  - **Allocation tracking table**: ทุก `alloc` บันทึก pointer + ขนาด + ตำแหน่งที่ขอ (function/line) ไว้ใน metadata
  - **Scope-exit checker**: ตอนจบ scope/function compiler เช็คว่ามี allocation ที่ยังไม่ถูก free และไม่ได้ escape ออกไปไหม → เตือนหรือ error ตอน compile time (ไม่ใช่ runtime)
  - **Runtime debug mode**: build แบบ debug ใส่ guard bytes หน้า-หลัง block ที่ alloc (ตรวจ buffer overflow) + ตอนโปรแกรมจบให้ dump รายการที่ยังไม่ free (คล้าย AddressSanitizer แบบเบาๆ ที่เขียนเอง)
- นี่คือฟีเจอร์ที่ทำให้ J2K ต่างจาก C ตรงที่ "ปลอดภัยกว่าโดยไม่มี GC" — เป็นจุดขายสำคัญของภาษา ควรเก็บเป็น milestone แยกใน Phase 2
- ✅ **ยืนยันรอบ 2026-08-19:** custom heap + leak-protection ตามที่เขียนไว้ข้างบนตรงกับที่ผู้เขียนต้องการแล้ว ไม่ต้องแก้เพิ่ม

### 8.2 Type System — Static + Type Inference
- ทุกตัวแปรมี type แน่นอนตอน compile time (ไม่มีอะไรแปลงหากันมั่วแบบ HolyC)
- แต่เขียนสั้นได้: `let x = 5` compiler อนุมาน type เป็น i64 เอง ไม่ต้องเขียน `i64 x = 5` ทุกที่
- Performance: type ทั้งหมด resolve ตอน compile → runtime ไม่มี overhead เช็ค type เลย (ต่างจากภาษา dynamic typing)

### 8.3 Error Handling — C++-style (try/catch/throw) — v0.1 ทำแค่พื้นฐานก่อน (ยืนยันแล้ว)
เคยพิจารณาแบบผสม Exception + Result Type แต่**ตัดสินใจสุดท้าย: ใช้ C++-style ล้วน** (`try`/`catch`/`throw` เป็นกลไกเดียวสำหรับ error ทุกแบบ ไม่มี `Result<T, E>` แยก) เหตุผลหลัก: เขียน compiler ง่ายกว่า (ไม่ต้องพึ่ง generic ซึ่งตัดสินใจไม่ทำใน Phase 0-1 อยู่แล้ว ดูข้อ 8.2b) และคุ้นเคยง่ายเพราะใกล้เคียง C++

**v0.1 — ทำแค่เวอร์ชันเล็กสุดก่อน:**
```
throw "error message"     // throw string ธรรมดา ไม่ต้องมี custom Error class
try {
    let data = read_file("x.txt")
} catch (e) {
    print(e)               // e เป็น string
}
```
- ยังไม่มี error type hierarchy (`FileError`, `RuntimeError` แยกกัน)
- ยังไม่มี multiple catch block แยกตาม type
- แค่ throw/catch string พื้นฐานให้ทำงานได้จริงก่อน ค่อยขยายเป็น error class แยกประเภททีหลัง (Phase 2+)

### 8.2b Generic/Template — ไม่ทำใน Phase 0-1 (ยืนยันแล้ว)
- **ไม่มี generic** (`fn max<T>(...)`) ในช่วง bootstrap — เขียนฟังก์ชันแยกตาม type ที่ใช้จริงไปก่อน (เช่น `max_int`, `max_float`)
- เหตุผล: generic ทำให้ compiler ซับซ้อนขึ้นมาก ไม่ว่าจะ implement แบบ monomorphization (แบบ C++/Rust — generate โค้ดแยกทุก type instantiation) หรือ type erasure (แบบ Java เดิม — ใช้ indirection กลาง) ทั้งคู่เพิ่มงานให้ compiler ที่ยังอยากให้เรียบง่ายที่สุดตอน bootstrap
- พิจารณาเพิ่มทีหลังตอน self-hosting เสร็จแล้ว (มีเครื่องมือที่ทรงพลังกว่าช่วยพัฒนาต่อ)

### 8.2c Syntax เล็กๆ อื่นๆ — Comment / String Interpolation / Operator Overloading
- **Comment**: มีแน่นอน (รูปแบบ `//` หรือ `#` ยังไม่ตัดสินใจเจาะจง — เป็นแค่ syntax choice ไม่กระทบ compiler design)
- **String interpolation** (เช่น `"hello {name}"`): มี เพราะโค้ดสั้นและอ่านง่ายกว่า printf-style เยอะ compiler แค่แปลงเป็น concat ตอน parse ไม่กระทบ backend
- **Operator overloading** (เช่น `Vector + Vector`): **ยังไม่ทำใน Phase 0-1** เพราะเพิ่มงาน parser/type-checker เยอะ (ต้อง resolve operator ตาม type ตอน type-check) และไม่จำเป็นต่อ bootstrap — พิจารณาใส่ตอน self-hosting (Phase 2+) ถ้ายังต้องการ

### 8.4 Concurrency — ต้องมี Async จริง + สั่งงาน CPU/Thread ผ่าน `import cpu` (ปรับปรุงล่าสุด — ยืนยันแล้ว)
> เปลี่ยนจากเดิมที่ "แค่เผื่อที่ไว้ ยังไม่ implement" มาเป็น **ต้องมี async จริงจัง** ตามที่ยืนยันล่าสุด

```
import cpu
using cpu

async fn download(url) {
    // ...
}

fn main() {
    let handle = spawn(download, "http://...")   // สร้าง thread ใหม่ผ่าน cpu module
    handle.join()
}
```
- `async`/`spawn` เป็นคีย์เวิร์ดจริงในภาษา ไม่ใช่แค่ syntax เผื่อไว้เฉยๆ
- การสั่งงาน CPU ระดับ thread ทำผ่าน module แยก: `import cpu` แล้ว `using cpu` เพื่อเรียกใช้แบบสั้น (ตามกฎ namespace ข้อ 8.6) — ไม่ built-in เข้าตัว core language เพื่อให้ bootstrap compiler เรียบง่ายไว้ก่อน (เขียน `cpu` module ทีหลังตอนมี syscall backend พร้อม)
- Implementation จริง (ตัว thread/syscall) ยังต้องรอ backend ที่รองรับ syscall เต็มรูปแบบ — เป้าหมาย priority คือทำให้เสร็จเร็วที่สุดเท่าที่ทำได้ ไม่ผูกไว้ว่าต้องรอ Phase 3/x86_64 อย่างเดียวแบบเดิม แต่ขึ้นกับว่า syscall thread บน ARM64 Linux (Phase 1-2) พร้อมเมื่อไหร่ก็ทำได้เลย

### 8.4b J2K Design Goal — ทำได้ทุกอย่างผ่าน Optional Module (ยืนยันแล้ว)
- เป้าหมายระยะยาว: J2K core language เรียบง่าย แต่ **ขยายทำอะไรก็ได้ผ่าน `import`/`using` module เพิ่มเติม** ไม่ยัดทุกอย่างเข้า core
- ตัวอย่าง: อยากทำเกม → `import game; using game;` แล้วเรียก API ของ game module ได้เลย ไม่ต้องมี game engine เป็นส่วนหนึ่งของตัวภาษาแต่แรก
- หลักการนี้เดียวกับที่ตัดสินใจเรื่อง `cpu` module ข้างบน — core language เบา, ความสามารถเพิ่มเติมมาเป็น module แยกที่ import ได้ตามต้องการ

### 8.5 Struct Constructor/Destructor — Hybrid (Manual + Automatic)
คำถาม: struct มี constructor/destructor อัตโนมัติแบบ C++ หรือเรียกเองแบบ C?

**คำตอบ: Hybrid — ใช้คีย์เวิร์ด `let`/`raw` ตัวเดียวกับ memory model (ข้อ 8.1) ควบคุมทั้งคู่**

```
struct Point {
    x, y

    fn init(&self) { self.x = 0; self.y = 0 }   // เขียนเอง เรียกเองได้ตรงๆ: point_init(&p)
}

let p: Point           // auto: compiler เรียก init() ให้อัตโนมัติตอนสร้าง
raw q: Point
point_init(&q)         // manual: เรียกเอง
```

- `let` = auto-managed: compiler เรียก constructor ให้อัตโนมัติตอนสร้าง และแทรก destructor + free ให้อัตโนมัติตอนจบ scope/block (ผูกกับ escape analysis ในข้อ 8.1 กลไกเดียวกัน ไม่ต้องสร้างระบบแยก)
- `raw` = manual: ต้องเรียก `_init`/`_free` เอง ลืมไม่ได้ compiler เตือนถ้า path ไหนลืม free (ตาม leak-protection ข้อ 8.1)
- คืนค่า (destructor/free): ถ้าเป็น `let` → คืนอัตโนมัติตอนจบ block เสมอ; ถ้าเป็น `raw` → คืนเองด้วยฟังก์ชัน free ที่เขียนไว้

### 8.6 Namespace — Full Namespace + `using` แบบ Flatten (ปรับปรุงล่าสุด — ยืนยันแล้ว)
คำถาม: namespace เต็มรูปแบบหรือ prefix แบบง่าย? คนอื่นจะรู้ได้ไงว่าโค้ดต้อง `using` อะไร?

**คำตอบ: Namespace เต็มรูปแบบแบบ C++ (มี `::`) + `using ns` = flatten เต็ม (เรียกชื่อสั้นได้ทันที ไม่ต้อง qualify)**

> เปลี่ยนจากเวอร์ชันแรก (ที่ `using std` ยังบังคับพิมพ์ `std::` นำหน้าอยู่) มาเป็น **flatten เต็มแบบ C++ `using namespace std;`** ตามที่ตัดสินใจล่าสุด

```
using std          // flatten ทั้งก้อนของ std เข้า scope

fn main() {
    cin >> x           // อยู่ใน std ที่ using ไว้ → เรียกสั้นได้เลย
    cout << y

    let v = math::Vector(1, 2)   // math ไม่ได้ using → ต้อง qualify เต็มด้วย math::
}
```

**กติกา:**
- `using ns` → flatten ทั้ง namespace นั้นเข้า scope เรียกชื่อสั้นได้ทันที ไม่ต้องเช็คทีละตัว
- namespace ที่ไม่ได้ `using` → ต้อง qualify เต็มด้วย `::` เสมอ ไม่งั้น compiler หา identifier ไม่เจอ (error พร้อมคำแนะนำ ดูข้อ 8.6b)
- ถ้า `using` หลายตัวพร้อมกันแล้วมีชื่อชนกัน (เช่น `std::count` กับ `math::count`) → compiler **error ทันที** ว่า ambiguous ต้อง qualify เฉพาะตัวที่ชนเท่านั้น ตัวอื่นที่ไม่ชนยังเรียกสั้นได้ปกติ:
```
using std
using math

count(x)          // ❌ error: ambiguous — พบทั้ง std::count และ math::count
math::count(x)    // ✅ ต้อง qualify เฉพาะตัวที่ชน
dot(a, b)          // ✅ ไม่ชนใคร เรียกสั้นได้ปกติ
```
- `using ns::item` (import เจาะจงทีละตัว) ยังใช้ได้เหมือนเดิม เขียนรวมไว้บนสุดไฟล์

**Scope ของ `using`: Global (นอกฟังก์ชัน) vs Local (ในฟังก์ชัน) — ยืนยันแล้ว**
```
using std              // นอกฟังก์ชัน = global — ใช้ได้ทั้งไฟล์ ทุกฟังก์ชันเรียกสั้นได้หมด

fn main() {
    cin >> x             // ใช้ global using ได้เลย ไม่ต้อง using ซ้ำ
}

fn other() {
    using math          // ในฟังก์ชัน = local — จำกัดแค่ในฟังก์ชันนี้เท่านั้น
    let v = Vector(1, 2)  // ใช้ math:: สั้นได้เฉพาะใน other()
}

fn another() {
    let v = math::Vector(1, 2)   // math ไม่ได้ using ในฟังก์ชันนี้ (และไม่ใช่ global) → ต้อง qualify เต็ม
}
```
- `using ns` เขียน**นอกฟังก์ชัน** (ระดับไฟล์) → flatten ทั้งไฟล์
- `using ns` เขียน**ในฟังก์ชัน** → flatten เฉพาะในฟังก์ชันนั้น ฟังก์ชันอื่นไม่ได้รับผล ลดพื้นที่เสี่ยงชื่อชนกันในไฟล์ใหญ่
- กติกา ambiguous error (ชื่อชนกันข้าม `using` หลายตัว) ใช้กฎเดียวกันทั้งสอง scope

### 8.6b Compiler Error/Warning Messages — ภาษาอังกฤษ ทางการ เสมอ (ยืนยันแล้ว)
- ทุก error/warning ของ J2K compiler ใช้**ภาษาอังกฤษแบบทางการ**เท่านั้น (ไม่ใช้ภาษาพูด ไม่ปนภาษาไทย) ตามมาตรฐาน compiler ทั่วไป (GCC/Clang/Rust style)
- กรณี identifier หาไม่เจอเพราะไม่ได้ `using`/qualify — ต้อง error แนะนำตรงๆ ว่าต้องทำอะไร เช่น: `error: unknown identifier 'Vector'. Did you mean 'math::Vector'? Add 'using math::Vector' or qualify it.`
- หลักการ: error message ต้องช่วยแก้ปัญหาได้ทันทีโดยไม่ต้องเปิดเอกสารแยก โดยเฉพาะช่วงที่ยังไม่มี IDE/tooling ให้ autocomplete ช่วย

### 8.7 Syntax Design Philosophy — คิดเองเป็นหลัก
- Syntax ของ J2K จะ**ออกแบบเองเกือบทั้งหมด** ไม่ใช่ก็อปจาก C++/HolyC ตรงๆ — อาจ "คล้าย" บางจุด (เช่น `fn`, `struct`, `let`/`raw`) แต่รายละเอียด grammar เป็นของ J2K เอง
- หมายความว่าเวลาออกแบบ `syntax-design.md` (Phase 0) ไม่ต้องยึดกฎของภาษาต้นแบบเป๊ะ ๆ — ใช้เป็นแรงบันดาลใจ ปรับให้เข้ากับสิ่งที่ตัดสินใจไว้ในข้อ 8 (memory model, error handling, struct) ได้เต็มที่

### 8.8 Bootstrap Compiler Language — การวิเคราะห์เดิม (ดูข้อ 8.9 สำหรับมติล่าสุด)
> ⚠️ **หมายเหตุ:** ข้อนี้คือการวิเคราะห์ตอนแรกที่แนะนำ C++ ล้วน แต่**มติล่าสุด (ข้อ 8.9) คือกลับไปใช้ asm ไล่เป็นขั้นๆ แทน** เก็บเหตุผลเดิมไว้อ่านประกอบเพื่อเข้าใจ trade-off ทั้งสองทาง แต่ให้ยึดข้อ 8.9 เป็นแผนจริง

คำถาม: bootstrap compiler ตัวแรกควรเขียนด้วย Assembly หรือ machine code ดีไหม?

**คำตอบเดิม (ก่อนเปลี่ยนใจ): ไม่แนะนำ — แนะนำ C++ ตามที่ระบุไว้ใน Phase 0 (ข้อ 5)**

เหตุผล:
- **เป้าหมายของ bootstrap compiler คือความเร็วในการ "มีเครื่องมือใช้งานได้"** ไม่ใช่ performance ของตัว compiler เอง — เขียนด้วย Assembly/machine code จะทำให้ตัว bootstrap เองกลายเป็นโปรเจกต์ใหญ่แยกต่างหาก (ต้องเขียน string handling, data structure, memory management ทั้งหมดเองตั้งแต่ระดับต่ำสุด) กว่าจะได้ lexer/parser/codegen ที่ใช้งานได้จริงจะกินเวลาเป็นเดือนโดยยังไม่ได้แตะ J2K เลย
- **Bootstrap compiler ไม่ต้องสวยหรือเร็ว มันแค่ต้องทำงานได้ถูกต้อง** เพราะสุดท้ายมันถูกทิ้งทันทีที่ Phase 2 (self-hosting) สำเร็จ — ลงทุนเวลากับมันน้อยที่สุดเท่าที่จำเป็นคือกลยุทธ์ที่ถูกต้อง
- C++ ให้ string/container (`std::string`, `std::vector`, `std::map`) ที่ใช้เขียน lexer/parser/AST ได้เร็วกว่า Assembly หลายเท่า และยังคุมระดับ byte ได้เวลาต้อง emit ARM64 machine code ตรงๆ
- **บรรทัดฐานจากคนอื่นที่ทำภาษามาก่อน:** แทบทุกภาษาใช้ higher-level language เขียน bootstrap compiler ตัวแรก แล้วค่อย self-host — GCC ตัวแรกเขียนด้วย C, Rust ตัวแรกเขียนด้วย OCaml, Go ตัวแรกเขียนด้วย C
- ในทางกลับกัน **ข้อดีของ asm ไล่ขั้น** (เหตุผลที่เลือกจริงในข้อ 8.9) คือแต่ละ stage เล็กและจบได้จริงเป็นระยะ ได้ฝึกเข้าใจ encoding อย่างล้ำลึกทุกขั้น แลกกับเวลารวมที่ยาวกว่า

### 8.9 Bootstrap Chain — ยืนยันสุดท้าย: ไล่ ASM เป็นขั้นๆ (stage0-style)
เคยพิจารณาแบบ "asm 1 ขั้นแล้วกระโดดไป C++" แต่**เปลี่ยนใจกลับมาใช้แนวทางไล่ asm หลายขั้นตามผังเดิม** แบบเดียวกับโปรเจกต์ `stage0`/`live-bootstrap`

**Chain ที่ยืนยันใช้จริง:**
```
ARM64 Assembly (เขียนมือ)
      ↓
J2K Assembler (เขียนด้วย asm — เครื่องมือแปลง text → machine code เบื้องต้น)
      ↓
J2K Compiler v0 (เครื่องมือจิ๋วที่สุดที่ compile J2K subset เล็กๆ ได้)
      ↓
J2K Compiler v1 (ฉลาดขึ้น รองรับ feature มากขึ้น)
      ↓
J2K Compiler เขียนด้วย J2K เอง (self-hosting — Phase 2)
      ↓
J2K OS (เป้าหมายระยะยาว)
```

เหตุผลที่เลือกทางนี้: แต่ละ stage เล็กและจบได้จริงเป็นระยะ เห็นผลไว ความเสี่ยง "ทำไปครึ่งทางแล้วท้อ" ต่ำกว่าเขียนก้อนใหญ่ก้อนเดียว และได้ฝึกเข้าใจ encoding/machine code อย่างล้ำลึกทุกขั้น แม้เวลารวมจะยาวกว่าทางลัด C++ ก็ตาม — ยอมแลกเวลาเพื่อความเข้าใจระดับต่ำสุดที่ต้องการ

### 8.10 Module Loading — `import` เท่านั้น (ไม่มี `include` แบบ C)
- J2K ใช้ `import` เพียงอย่างเดียวสำหรับดึง module/namespace เข้ามาใช้ ไม่มี `include` แบบ C (ที่เป็น textual copy-paste ก่อน compile)
- เหตุผล: `include` ช้า (ต้อง parse ซ้ำทุกครั้ง), ไม่มีขอบเขต namespace ในตัวเอง, error message ชี้ผิดจุดง่าย เพราะ compiler มองเป็นไฟล์เดียวยักษ์หลัง substitution — ในขณะที่ `import` compile module แยกได้ (หรือ cache ไว้ใช้ซ้ำ) และผูกกับระบบ namespace (ข้อ 8.6) ได้เป็นธรรมชาติอยู่แล้ว ไม่ต้องมี 2 กลไกซ้อนกัน
- `std` (และ library อื่นๆ) ไม่ใช่ keyword ในตัวภาษา — เป็น library แยกต่างหากที่มากับ compiler เหมือน `<iostream>` ใน C++ ไม่ได้ built-in เข้าตัวภาษา ต้อง `import std` ก่อนถึงจะเรียก `std::cin` ได้ ไม่งั้น compiler ไม่รู้จัก

### 8.11 Compile-time Strictness — Warning เท่านั้น (ยืนยันแล้ว)
- ตัวแปรไม่ได้ใช้, unreachable code, และปัญหาระดับเดียวกัน → ให้เป็น **warning** ไม่ error — compile ผ่านต่อได้เสมอในช่วง Phase 0-1 ที่ยังพัฒนาไว จะได้ไม่ติดขัดบ่อยเกินไป
- เผื่อไว้ในอนาคต: เพิ่ม `strict mode` เป็น flag แยก (เช่น `j2kc --strict`) ที่ทำให้ warning กลายเป็น error ได้ตอนต้องการความเข้มงวดมากขึ้น (เช่น ตอน self-hosting หรือใกล้ release)

### 8.12 Basic Syntax Decisions (รอบคำถามที่ 3 — ยืนยันครบทุกข้อ ไม่ถามซ้ำ)
- **Comment**: `//` แบบ C++ (ยืนยันแล้ว)
- **นามสกุลไฟล์ source code**: `.jk` (ยืนยันแล้ว) เช่น `main.jk`
- **Entry point**: `main()` ตัวเล็กแบบ C++ (ยืนยันแล้ว) — สอดคล้องกับ convention `fn`/`struct` ที่ใช้อยู่แล้ว และ linker เข้าใจ symbol `main` เป็นมาตรฐานอยู่แล้ว
- **Boolean/null keyword**: `true`, `false`, `null` ตัวเล็กทั้งหมด (ยืนยันแล้ว)
- **Array/String พื้นฐาน**: เป็น **built-in ในตัวภาษา** (raw byte array + fixed-size) ไม่ใช่ struct ใน std library — จำเป็นสำหรับ bootstrap เอง (ไม่งั้นเกิดปัญหาไก่กับไข่ ต้องมี string ก่อนถึงจะเขียน std library ที่เก็บ string ได้) ส่วน string ที่ฉลาดกว่า (dynamic resize, UTF-8 helper) ค่อยสร้างเป็น struct ใน std library ทีหลัง (Phase 2+)
- **Semicolon**: บังคับ `;` ปิดท้ายทุก statement แบบ C++ (ยืนยันแล้ว) ไม่ใช้ newline-terminated statement

### 8.13 Bootstrap Chain — จุดเริ่มต้นจริง (ยืนยันแล้ว)
- เริ่มจาก **เขียน "J2K Assembler" เป็นเป้าหมายทันที** (ไม่ใช่ฝึก asm เปล่าๆ ก่อนแบบไม่มีเป้าหมาย) — asm ที่เขียนทุกบรรทัดมีเป้าหมายตรงคือประกอบเป็น J2K Assembler ตัวแรกของ chain ในข้อ 8.9 เลย

### 8.14 Project Storage — Path และ Git (ยืนยันแล้ว)
- เก็บโปรเจกต์ไว้ที่ `~/j2k-cmp/` ใน Termux
- Track ด้วย Git และ push ขึ้น GitHub

### 8.15 Focus/Priority — ปิดโปรเจกต์อื่นเพื่อทุ่มเวลาให้ J2K (ยืนยันแล้ว)
- **Angle-turn**: ตัดออกจากรายการโปรเจกต์คู่ขนานก่อน — เหตุผลคือยังเข้าใจภาษาที่ใช้เขียนไม่ลึกพอ
- **JPP**: ทิ้งไปเลย ไม่ทำต่อ
- เหลือ balance เวลาแค่กับการเรียน IT ปี 1 เท่านั้น ทำให้มีเวลาให้ J2K ได้มากขึ้นกว่าที่ประเมินไว้ตอนแรก

### 8.16 Basic Syntax Decisions รอบ 4 (ยืนยันครบทุกข้อ)
- **Numeric types**: แยกขนาดชัดเจนแบบ C — `i8`, `i32`, `i64` (integer) และ `f8`, `f32`, `f64` (float) ไม่มี `int`/`float` เดี่ยวๆ ที่ไม่ระบุขนาด
- **If/loop syntax**: แบบ `if` ตามด้วยเงื่อนไข แล้วครอบ body ด้วย `{}` เช่น `if x > 5 { ... }` (ไม่บังคับวงเล็บครอบเงื่อนไข)
- **Function no-return**: ใช้ `void` explicit แบบ C++ เช่น `fn print_hello() -> void { ... }` — เพื่อความสม่ำเสมอกับ syntax อื่นที่อิง C++
- **Pointer/reference**: ⚠️ **แทนที่แล้วโดยข้อ 8.18** — เดิมคิดจะใช้ `*`/`&` แบบ C แต่เปลี่ยนเป็น `@`/`^` แล้ว ดูข้อ 8.18 สำหรับ syntax ล่าสุด
- **Compiler command**: ชื่อ compiler binary คือ `Jcmp` คำสั่งพื้นฐาน `Jcmp main.jk -o main` (อาจปรับ syntax คำสั่ง/flag เพิ่มเติมภายหลังตอน implement จริง)
- **License**: **เขียนเอง** ไม่ใช้ license สำเร็จรูป (เช่น Creative Commons) เพราะไม่ได้ออกแบบมาสำหรับซอฟต์แวร์โดยเฉพาะ — จะร่างเป็น all-rights-reserved + ห้ามดัดแปลง/แจกจ่ายซ้ำ/อ้างเป็นผลงานตัวเอง แบบสั้นๆ ตอนใกล้ publish จริง (ยังไม่ต้องเขียนตอนนี้)

### 8.17 Basic Syntax Decisions รอบ 5 (ยืนยันแล้ว)
- **Multi-return values**: **ไม่มี native multi-return** ตาม C/C++/HolyC — ใช้ out-parameter ผ่าน pointer หรือห่อด้วย struct เอง เช่น `fn divmod(a, b, q: *int, r: *int) -> void { q^ = a/b; r^ = a%b }` — ไม่เพิ่ม feature พิเศษให้ compiler สอดคล้องกับ pointer (`raw`) ที่ตัดสินใจไว้แล้ว
- **Switch/Match**: ใช้คำ `match` (แบบ Rust) จับหลายค่าต่อ case ได้ (`1, 2, 3:`) แต่ปิดแต่ละ case ด้วย `;` แทน `=>` — **ไม่มี fallthrough โดยปริยาย compiler จัดการ break ให้อัตโนมัติ ไม่ต้องเขียน break เอง** (ผสม C-ish syntax + Rust behavior) — ยังไม่ยืนยันว่าบังคับ exhaustive (ต้องมี `_`) หรือไม่ รอออกแบบตอนทำ syntax-design.md จริง
- **Enum**: ยืนยันว่ามีแน่นอน แต่ยังไม่ล็อค syntax รายละเอียด (คิดเพิ่มตอนออกแบบ syntax-design.md)
- **หมายเหตุ**: ข้อเสนอ pointer symbol แบบ `@`/`^` **ยืนยันแล้ว** ดูรายละเอียดในข้อ 8.18

### 8.18 Pointer Syntax — `@`/`^` แทน `*`/`&` แบบ C (ยืนยันแล้ว — แทนที่ข้อ 8.16)
เหตุผลที่เปลี่ยน: `*` ของ C มี 3 ความหมายต่างบริบท (ประกาศ pointer type, dereference, คูณ) ทำให้กำกวมทั้งตอนเขียนและตอนอ่าน — เปลี่ยนเป็น `@`/`^` ที่ไม่ชนกับ operator อื่นเลย ชัดเจนทั้งสองฝั่ง

```
i32 x = 42
i32^ p = @x        // ^ หลัง type = "pointer to", @ นำหน้าตัวแปร = address-of

print(p^)            // p^ = dereference (อ่านค่าที่ p ชี้ไป)
p^ = 99              // เขียนค่าใหม่ผ่าน pointer
```
- `@x` = address-of (แทน `&x` เดิม)
- `T^` = pointer type (แทน `T*` เดิม) เช่น `i32^`
- `p^` = dereference แบบ postfix (แทน `*p` เดิม)
- ใช้กับ `raw` variable เต็มที่ (เพื่อรองรับ custom allocator และงานระดับ CPU) ส่วน `let` variable (auto-managed) ยังจำกัดไม่ให้ dereference ตรงๆ กัน dangling pointer ตามหลักการเดิม

### 8.19 Array Syntax — Fixed-size แบบ C (ยืนยันแล้ว)
```
i32 arr[10]                    // ประกาศ fixed-size array
arr[0] = 1
print(arr[0])

i32 matrix[3][3]              // multi-dimensional array

fn sum(arr: i32[10]) -> i32 {
    i32 total = 0
    i32 i = 0
    match i < 10 {
        true: total = total + arr[i]; i = i + 1;
    }
    return total
}
```
- Syntax หน้าตาเหมือน C/C++/HolyC (`T name[N]`) คุ้นเคย เรียนรู้ง่าย
- **Fixed-size ไม่แนบความยาว runtime** — compiler รู้ขนาด (`10`) ตอน compile time อยู่แล้ว เช็ค bounds จาก constant ได้เลย ไม่มี overhead เพิ่ม
- **ตอนส่งเข้าฟังก์ชัน**: compiler แนบความยาวไปด้วยเสมอ (metadata แค่ตอนผ่าน parameter) ไม่ decay เป็น pointer เปล่าแบบ C ไม่ต้องส่งความยาวแยกเป็น parameter อีกตัว
- **Bounds checking เฉพาะ debug build** ผ่าน guard-bytes mechanism เดียวกับข้อ 8.1 (`arr[15]` ตอน array มีแค่ 10 → error/warning runtime) — **release build ไม่เช็ค เร็วเท่า C**

### 8.20 Dynamic Array — Syntax ย่อ + คำสั่งจำเป็นเท่านั้น (ยืนยันแล้ว)
```
i32[] list = arr(10)      // arr(N) = สร้าง dynamic array เริ่ม capacity N

list.push(5)                 // เพิ่มท้าย resize อัตโนมัติถ้าเต็ม
list.pop()                    // ลบตัวสุดท้าย คืนค่าที่ลบออกมา
list[0]                        // index อ่าน/เขียนปกติ
list.len                      // property จำนวนสมาชิกจริง (ไม่ใช่ capacity, ไม่ใช่ function ไม่ต้องมี ())
list.free()                   // คืน memory (raw ต้อง free เอง ตามข้อ 8.1)
```
- คำสั่งมีแค่นี้พอ: `arr(N)`, `.push()`, `.pop()`, `.len`, `.free()` — **ไม่ใส่** `.insert()`/`.remove()`/`.sort()`/`.map()`/`.filter()` ตอนนี้ (ทำผ่าน loop เองได้ ไม่จำเป็นต่อ bootstrap เพิ่มงาน compiler โดยไม่ต้อง)
- Syntax แยกชัดจาก fixed-size ด้วยไม่มีตัวเลขในวงเล็บ: `i32[10]` (fixed) vs `i32[]` (dynamic)
- ต้องเป็น `raw` เท่านั้น (resize ต้อง realloc เอง ผูกกับ custom heap allocator ข้อ 8.1 โดยตรง) ไม่ใช้กับ `let`
- Type ภายใน (สำหรับตอนเขียน bootstrap compiler ด้วย C++): `struct DynArray<T> { data: T^, len: i64, cap: i64 }` — `<T>` ตรงนี้คือ C++ template ตอนเขียน compiler เอง ไม่ใช่ generic ของ J2K (ตัดสินใจไม่มี generic ใน J2K เอง ตามข้อ 8.2b) ฝั่ง J2K จะมี type คงที่แยกต่อ primitive ที่ใช้จริง เช่น `DynArrayI32`, `DynArrayI64`

### 8.21 Basic Syntax Decisions รอบ 6 (ยืนยันครบทุกข้อ)
- **String escape sequence**: รองรับ escape มาตรฐานแบบ C — `\n`, `\t`, `\"`, `\\` และมี **raw string** เพิ่มเติมแบบ Rust สำหรับกรณีไม่อยาก escape เลย (เช่น path, regex): `let s = r"C:\Users\name"`
- **Method call syntax**: มี 2 รูปแบบตามบริบท — struct/dynamic array ที่ "เป็นเจ้าของข้อมูล" ใช้ dot (`list.push(5)`, `p.init()`); syscall/utility function ที่ไม่ผูกกับ struct เฉพาะ ใช้ free function ผ่าน namespace (`cpu::spawn(...)`, `math::dot(a, b)`) — สอดคล้องกับ namespace (8.6) และ concurrency (8.4) ที่ตัดสินใจไว้แล้ว
- **`=` vs `==` ใน condition**: compiler **error ทันที** (ไม่ใช่แค่ warning) ถ้าเจอ `=` เดี่ยวใน condition ของ `if`/`match`/`while` เช่น `if x = 5 { ... }` → error พร้อมคำแนะนำ "did you mean '=='?"
- **Struct composition**: struct ซ้อน struct ได้ปกติ เข้าถึงด้วย `.` ต่อกันแบบ C (`p.position.x = 10`) ใช้จัดกลุ่มข้อมูลที่เกี่ยวข้องกันเป็นชั้นๆ เช่น `Player` มี `Vector2` เป็นสมาชิกซ้อนอยู่
- **File I/O**: ยังไม่ออกแบบ syntax ตอนนี้ — **เก็บไว้ในแผนอนาคต ทำหลังจากส่วนงานเล็กๆ (bootstrap พื้นฐาน) เสร็จก่อน** จะออกแบบ syntax เองตอนถึงจุดนั้น
- **Compile flags**: ใช้ตัวย่อสั้น แทน `--debug`/`--strict` เต็มคำ — คำสั่งจริงคือ `Jcmp main.jk -o main -d -st` (`-d` = debug mode มี bounds check/guard bytes ตามข้อ 8.1, 8.19; `-st` = strict mode ตามข้อ 8.11 เปิดพร้อมกันได้)

### 8.22 ⚠️ หมายเหตุสำคัญ: โค้ดตัวอย่างในเอกสารนี้ไม่ใช่ syntax ที่ล็อคแล้ว
- ทุกตัวอย่างโค้ดในเอกสารนี้ (ที่ใช้ `fn name() -> type`, `struct X { }` ฯลฯ) เป็นแค่ตัวอย่างประกอบไอเดียตอนคุยแต่ละหัวข้อ **ไม่ใช่ syntax ที่ตัดสินใจล็อคแล้ว** เพราะยังไม่ได้ทำ `syntax-design.md` จริงจัง
- สิ่งที่ล็อคแล้วจริงคือ **behavior/decision** (เช่น "มี match ไม่มี fallthrough", "array แนบความยาวตอนส่งเข้าฟังก์ชัน", "pointer ใช้ @/^") ส่วน**รูปแบบ syntax ที่ใช้เขียน** (เช่น function declaration จะเป็น `fn`-style หรือ C++-style) ให้ยึดตามข้อ 8.23 เป็นหลักถ้าขัดกับตัวอย่างเก่าในเอกสาร

### 8.23 Function Declaration Syntax — C++-style (type นำหน้า ไม่ใช้ `fn`/`->`) (ยืนยันแล้ว — แทนที่ตัวอย่าง `fn` ทั้งหมดก่อนหน้า)
```
i32 add(i32 a, i32 b) {
    return a + b
}

void print_hello() {
    print("hi")
}
```
- Return type อยู่หน้าสุดแบบ C++ ตรงๆ ไม่มี `fn` นำหน้า ไม่มี `->` คั่น
- Parameter ก็ระบุ type นำหน้าชื่อแบบ C++ (`i32 a` ไม่ใช่ `a: i32`)

### 8.24 Basic Syntax Decisions รอบ 7 (ยืนยันครบทุกข้อ)
- **`raw` ต้องระบุ type เสมอ** (ต่างจาก `let` ที่ inference ได้) เพราะเกี่ยวกับ memory ต้องชัดเจนตั้งแต่ประกาศ
- **`i` เฉยๆ (ไม่ระบุเลขขนาด) = `i64` โดย default** เช่น `raw x: i = 10` เท่ากับ `raw x: i64 = 10` — ถ้าต้องการขนาดอื่นต้องระบุชัดเจน (`i32`, `i8`)
- **Mutable by default แบบ C**: ตัวแปรที่ประกาศแล้วแก้ค่าทีหลังได้เลย ไม่ต้องมีคำสั่ง/keyword พิเศษถึงจะแก้ได้ (ต่างจาก Rust ที่ default immutable)
- **Brace/indentation style อิสระ**: compiler ไม่บังคับ style ใดๆ เขียน `{` ต่อท้ายบรรทัดเดียวกันหรือขึ้นบรรทัดใหม่ก็ได้ตามใจผู้เขียน
