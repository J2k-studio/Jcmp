# Roadmap: ARM64 Performance Optimization (Jcmp)

> เป้าหมาย: ทำให้ J2K เป็นภาษาที่ทำงานได้เร็วและมีประสิทธิภาพสูงสุดบนสถาปัตยกรรม ARM64 โดยเฉพาะ Huawei P40 (Kirin 990)

---

## Phase F1: NEON SIMD Integration
**ระยะเวลาโดยประมาณ**: 2-3 เดือน

### รายละเอียด
- เพิ่ม intrinsic functions ใน compiler สำหรับเรียกใช้ ARM NEON (SIMD) โดยตรง
- รองรับ data types: `f32x4`, `i32x4`, `i16x8`, `u8x16`
- Auto-vectorization เบื้องต้นสำหรับลูปที่ทำ operation ซ้ำๆ กัน

### ข้อดี
- ประมวลผลข้อมูลพร้อมกัน 4-16 ตัวในคำสั่งเดียว (เหมาะกับเสียง, ภาพ, cryptography)
- ลดจำนวนคำสั่งที่ต้องทำงานลงอย่างมาก (speedup 2-4 เท่า)
- ไม่ต้องพึ่งพาไลบรารีภายนอก

### ข้อเสีย
- การเขียน intrinsic ทำให้โค้ดอ่านยากและพกพาไม่ได้ (เฉพาะ ARM)
- Auto-vectorization ทำได้ยาก หากลูปมีเงื่อนไขซับซ้อน
- ใช้ register เพิ่มขึ้น อาจชนกับส่วนอื่นของ compiler
- ต้องเรียนรู้ instruction set ของ NEON โดยเฉพาะ (ค่อนข้างซับซ้อน)

---

## Phase F2: Cache-Aware Code Generation
**ระยะเวลาโดยประมาณ**: 1-2 เดือน

### รายละเอียด
- Compiler จะวิเคราะห์ access pattern ของอาเรย์และ struct
- จัดเรียงข้อมูลในหน่วยความจำให้ติดกัน (cache-line alignment = 64 bytes)
- ใส่ instruction `PRFM` (prefetch) ล่วงหน้าก่อนเข้าถึงข้อมูล
- จัดกลุ่มฟังก์ชันที่เรียกใช้บ่อย (hot/cold function splitting)

### ข้อดี
- ลด cache miss ได้มาก (โดยเฉพาะในลูปยาวๆ)
- Prefetch ช่วยซ่อน latency ของ RAM (โดยเฉพาะบน P40 ที่ RAM แรงไม่มาก)
- ทำงานได้ดีกับข้อมูลที่เป็น streaming (เสียง, วิดีโอ)

### ข้อเสีย
- Prefetch ที่ผิดตำแหน่งจะทำให้ช้าลง (เสียเวลาในการโหลดข้อมูลที่ไม่ใช้)
- Alignment ทำให้ไฟล์ไบนารีใหญ่ขึ้น (มีช่องว่างระหว่าง struct)
- การวิเคราะห์ access pattern ต้องใช้เวลา compile นานขึ้น
- ต้องรู้รายละเอียด cache hierarchy ของ CPU นั้นๆ (P40 = L1 32KB, L2 512KB, L3 4MB)

---

## Phase F3: ARM Atomic Operations & Lock-Free
**ระยะเวลาโดยประมาณ**: 1 เดือน

### รายละเอียด
- รองรับคำสั่ง `LDADD`, `CAS` (compare-and-swap), `SWP`
- เพิ่ม keyword `atomic` สำหรับตัวแปรที่ใช้ข้ามเธรด
- สร้าง lock-free data structures (queue, stack) ใน standard library

### ข้อดี
- เร็วกว่าการใช้ mutex/pthread มาก (ไม่ต้องเรียก kernel)
- เหมาะกับงาน bot ที่รับ-ส่งข้อมูลพร้อมกันหลายช่องทาง
- ป้องกัน race condition โดยไม่ต้องใช้ล็อก

### ข้อเสีย
- การเขียน lock-free code ยากมาก (ABA problem, memory ordering)
- ถ้าใช้ผิดจะทำให้ data corruption หรือ deadlock ได้ง่าย
- Atomic ops บางตัวช้ากว่าปกติ 2-3 เท่า (เพราะต้อง sync ระหว่าง core)
- P40 มี 8 core (big.LITTLE) การ sync ข้าม cluster อาจช้า

---

## Phase F4: Linker-Level Optimization
**ระยะเวลาโดยประมาณ**: 2-3 สัปดาห์

### รายละเอียด
- จัดเรียงฟังก์ชันใน `.text` section ตาม call graph (hot functions ติดกัน)
- ใช้ linker script เพื่อวาง data section ในตำแหน่งที่เหมาะสม
- LTO (Link-Time Optimization) เบื้องต้น: inline function ข้ามไฟล์
- Strip unused symbols เพื่อลดขนาด binary

### ข้อดี
- ลด branch misprediction (เพราะฟังก์ชันที่เรียกกันอยู่ใกล้กัน)
- instruction cache ทำงานได้ดีขึ้น
- ขนาด binary เล็กลง โหลดเร็วขึ้น

### ข้อเสีย
- Linker script ซับซ้อนและพกพาไม่ได้ (ต้องปรับตาม OS)
- LTO ทำให้เวลา compile นานขึ้นมาก (อาจเป็น 2-3 เท่า)
- การเรียงฟังก์ชันต้องใช้ profiling data (PGO) จึงจะได้ผลดีที่สุด
- ถ้าจัดเรียงผิดอาจทำให้ performance แย่ลง

---

## Phase F5: System Call Optimization for Networking
**ระยะเวลาโดยประมาณ**: 1-2 เดือน

### รายละเอียด
- ใช้ `io_uring` หรือ `epoll` แทน `select`/`poll`
- Zero-copy send/receive (ใช้ `sendfile`, `splice`)
- จัด buffer pool สำหรับ socket I/O โดยเฉพาะ
- รองรับ non-blocking I/O + event loop

### ข้อดี
- รองรับการเชื่อมต่อพร้อมกันเป็นพันๆ (เหมาะกับ bot)
- Zero-copy ลดภาระ CPU ในการก็อปปี้ข้อมูล
- io_uring เร็วกว่า epoll 30-50% (บน kernel 5.x+)

### ข้อเสีย
- io_uring ต้องใช้ kernel 5.1+ (P40 อาจอัปเดตไม่ถึง)
- การเขียน event loop ซับซ้อนและต้องจัดการ memory ให้ดี
- Zero-copy ใช้ได้เฉพาะบางกรณี (ไฟล์ -> socket เท่านั้น)
- ต้องเขียน assembly syscall wrapper เอง (ไม่มี libc ช่วย)

---

## Phase F6: Profiling & Auto-Tuning (PGO)
**ระยะเวลาโดยประมาณ**: 2 เดือน

### รายละเอียด
- สร้าง instrumented binary ที่บันทึกการทำงาน (branch, cache miss, call count)
- นำข้อมูลมาใช้ในการ optimize รอบสอง (PGO = Profile-Guided Optimization)
- ปรับ NEON auto-vectorization ตามข้อมูลจริง
- ปรับ prefetch distance ตาม cache latency ที่วัดได้

### ข้อดี
- ได้ performance ที่เหมาะสมกับเครื่องของคุณโดยเฉพาะ (P40)
- ไม่ต้องเดาค่าต่างๆ ด้วยตัวเอง
- สามารถปรับให้เหมาะกับ workload ที่ใช้จริง (เช่น bot I/O)

### ข้อเสีย
- ต้อง compile สองรอบ (ช้ามาก)
- ต้องรันโปรแกรมจริงเพื่อเก็บ profile (อาจใช้เวลาหลายชั่วโมง)
- Profile data ใช้ไม่ได้กับเครื่องอื่น (ต้องทำใหม่)
- โค้ดซับซ้อนขึ้นมาก (ทั้ง compiler และ runtime)

---

## ข้อควรระวังโดยรวม

| ปัญหา | ผลกระทบ | การแก้ไข |
|--------|----------|----------|
| ARM big.LITTLE (P40 มี 2 clusters) | การย้ายเธรดระหว่างคลัสเตอร์ทำให้ cache flush | ผูกเธรดกับ core เฉพาะ (CPU affinity) |
| Termux environment | syscall บางตัวถูกจำกัด หรือไม่มี header | ต้องเขียน syscall wrapper ด้วย assembly ล้วนๆ |
| Binary size | Optimizations ทำให้ไฟล์ใหญ่ขึ้น | ใช้ `-Os` สำหรับ release build |
| Debugging | โค้ดที่ optimized แล้ว debug ยากมาก | มี flag `-O0` สำหรับ debug โดยเฉพาะ |
| Portability | โค้ดที่ใช้ NEON/Atomic ไปรันบน x86 ไม่ได้ | แยก backend ให้ชัดเจน (ARM vs x86) |

---

## ลำดับความสำคัญแนะนำ (สำหรับ P40 + Bot)

1. **Phase F5 (System Call)** — สำคัญที่สุด เพราะ bot ต้อง I/O เยอะ
2. **Phase F4 (Linker)** — ทำง่าย ได้ผลเร็ว
3. **Phase F2 (Cache)** — ช่วยเรื่อง latency ของ RAM บนมือถือ
4. **Phase F3 (Atomic)** — ถ้าใช้ multi-threading
5. **Phase F1 (NEON)** — ถ้าต้องการประมวลผลข้อมูล (เช่น JSON parser)
6. **Phase F6 (PGO)** — ทำทีหลัง เมื่อระบบเสถียรแล้ว

---

## สรุป

การทำให้ J2K ทำงานเร็วบน P40 เป็นไปได้ แต่ต้องแลกด้วย **ความซับซ้อนของโค้ด** และ **การพกพาที่ลดลง** แนวทางที่ดีคือ:
- ใช้ **feature flags** ใน compiler (`-mneon`, `-mcache-prefetch`) ให้ผู้ใช้เลือกเปิด/ปิด
- สร้าง **baseline build** ที่ไม่มีการ optimize พิเศษ เพื่อใช้ debug
- เก็บ **performance benchmark** ทุกครั้งที่เพิ่ม optimization ใหม่

