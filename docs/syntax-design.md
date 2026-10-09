# J2K Syntax Design (ฉบับร่างแรก)

> รวบรวมจาก Language Design Decisions (roadmap-j2k-3.md ข้อ 8.1-8.24) มาเรียงเป็น syntax เดียวกันทั้งไฟล์
> เรียงจากหัวไฟล์ (comment, import) ไปจนจบไฟล์ (main) — พิมพ์ผิด/ไม่ชัวร์ตรงไหน แก้ได้เลยระหว่างอ่าน

---

## ⚠️ คำสั่งสำหรับ AI/ผู้ช่วยตัวอื่นที่เข้ามาทำงานต่อกับไฟล์นี้ (อ่านก่อนทำงานอะไรทั้งหมด)

**ให้ทำตาม roadmap J2K (ไฟล์นี้ + roadmap-j2k) อย่างเคร่งครัด 100%**

กติกาบังคับ:
1. **ห้ามตัดสินใจหรือล็อค syntax เองเด็ดขาด** — ทำหน้าที่แค่ "เสนอทางเลือก" และ "อธิบายข้อดีข้อเสีย" เท่านั้น ผู้ใช้เป็นคนตัดสินใจสุดท้ายทุกครั้ง
2. **ห้ามปรับแต่ง/แก้ไข/เพิ่มเติมสิ่งที่ล็อคไว้แล้วในไฟล์นี้เองโดยไม่บอกก่อน** — ถ้าจำเป็นต้องแก้ (เช่น พบว่าขัดแย้งกัน) ต้องทักท้วงและถามยืนยันจากผู้ใช้ก่อนเสมอ ห้ามแก้ทับเงียบๆ
3. **มีคำถามอะไรให้ถามได้เสมอ** — ถ้าไม่แน่ใจว่าสิ่งที่ผู้ใช้ขอตรงกับ decision เดิมไหม หรือไม่ชัดเจนตรงไหน ให้ถามก่อนเดินหน้า ไม่ต้องเดาเอง
4. **ก่อนเสนอ syntax ใหม่ ให้อ่านทั้งไฟล์นี้ก่อนเสมอ** เพื่อให้สอดคล้องกับสิ่งที่ตัดสินใจไปแล้ว ไม่ขัดแย้งกันเอง
5. **ทุกครั้งที่มีการตัดสินใจใหม่ ต้องบันทึกลงไฟล์นี้เท่านั้น** ห้ามสร้างไฟล์อื่นแยก ห้ามเก็บไว้แค่ในคำตอบเฉยๆ โดยไม่บันทึก
6. **แนวทาง syntax หลักคือผสม C, C++, HolyC** (ชิด CPU/memory, เขียนสั้น กระชับ) ไม่ใช่แนว Python/JavaScript หรือ high-level มาก — ภาษาอื่น (Rust, Go, Odin, Zig) ใช้ได้แค่เป็นไอเดียเปรียบเทียบเท่านั้น ไม่ใช่ต้นแบบหลัก

---

## 1. หัวไฟล์ — Comment, Import, Using

```
// นี่คือ comment บรรทัดเดียว (ยืนยันแล้ว)
/* comment หลายบรรทัด
   แบบนี้ก็มี */

import std              // ดึง module std เข้ามา (built-in module ไม่มี quote)
import math
import cpu

using std                // global using — ใช้ได้ทั้งไฟล์ ทุกฟังก์ชันเรียกสั้นได้ (flatten เต็ม)
using math::Vector       // using แบบเจาะจง — เอาแค่ตัวนี้
```

**กติกา:**
- `import` ใช้ดึง module เข้ามา ไม่มี `include` แบบ C
- `using` เขียนนอกฟังก์ชัน = global (ทั้งไฟล์), เขียนในฟังก์ชัน = local (จำกัดแค่ในนั้น)
- `using ns` (ไม่ระบุ item) = flatten ทั้งก้อน เรียกสั้นได้ทันที
- `using ns::item` = เอาเฉพาะตัวที่ระบุ
- ชื่อชนกันข้าม `using` หลายตัว → compiler error บังคับ qualify เฉพาะตัวที่ชน

### 1.1 Import ไฟล์ตัวเอง (local/relative/absolute) (ยืนยันแล้ว)

```c
import "test"                     // relative: test.j (หรือ test.jk ถ้าไม่มี .j) ในโฟลเดอร์เดียวกัน
import "test.math"                // relative sub-path: test/math.j (หรือ .jk)
import "./home.test.mach"         // absolute จาก root: /home/test/mach.j (หรือ .jk)
```
```bash
Jcmp main.jk -o main -I ~/j2k-libs   // search path เสริมผ่าน compile flag
```

**กติกา:**
- `import "name"` (มี quote, ไม่มี `./` นำหน้า) = **local file** ของเราเอง แยกจาก `import std` (built-in module ไม่มี quote)
- ตัวคั่นระดับโฟลเดอร์ = `.` (dot notation) เช่น `test.math` = `test/math.jk`
- ไม่มี `./` นำหน้า = **relative path** จากไฟล์ที่ import
- มี `./` นำหน้า = **absolute path เริ่มจาก root** — `/` ตรงนี้ทำหน้าที่แค่ signal 2 ตัวแรกบอกประเภท path เท่านั้น ตัวคั่นที่เหลือหลังจากนั้นยังเป็น `.` เหมือนเดิม (`./home.test.mach` → `/home/test/mach.jk`)
- `-I` compile flag เพิ่ม search path เสริม (สอดคล้องกับ `-d`/`-st` ที่มีอยู่แล้ว) — compiler หา local ก่อนเสมอ ไม่เจอค่อยหาต่อใน search path list

---

## 2. Numeric Types

```
i8, i32, i64      // integer แยกขนาดชัดเจน
f32, f64          // float แยกขนาดชัดเจน (ไม่มี f8 — ตัดออก 2026-10-08)
```
ไม่มี `int`/`float` เดี่ยวๆ ที่ไม่ระบุขนาด (บังคับชัดเจนเสมอ ยกเว้น `raw x: i` ที่ inference เป็น `i64` — ดูข้อ 4)

### 2a. `bool` Type (ยืนยันแล้ว)

```c
bool done = false;
if done { ... }
```

**กติกา:**
- `bool` เป็น type แยกต่างหาก ขนาด **1 byte**
- **แยกขาดจาก integer สมบูรณ์** — ห้าม cast ไป/กลับกับ `i8`/`i32`/`i64` ฯลฯ เลย (ไม่มี `(i32)true` หรือ `(bool)0`)
- ต้องการค่า `bool` ต้องมาจาก comparison/logical operator เท่านั้น (`x == 0`, `x > 5 && y > 0` ฯลฯ) ไม่ใช่ cast จากตัวเลขตรงๆ — กันความคลุมเครือแบบ C ดั้งเดิม (`if x` ที่ `x` เป็นเลขทั่วไป จะไม่มีทางเขียนแบบนั้นได้อีกต่อไป ต้องเขียน `if x != 0` ชัดเจน)

---

## 3. ตัวแปร — C-style (ยืนยันแล้ว)

```
i x = 5;          // i เฉยๆ = i64 (auto — compiler จัดการ size ให้)
i32 y = 10;       // ระบุขนาดชัดเจน (manual control)
i8 z = 20;        // ขนาดเล็ก — ต้องการควบคุม memory เอง
i64 w = 30;       // ระบุ i64 ตรงๆ ก็ได้ เทียบเท่า i เฉยๆ

char s[] = "hello";       // string — compiler นับขนาดให้เอง (auto-size)
char r[] = r"C:\path";    // raw string ก็ได้
```

**กติกา:**
- ไม่มี `let`/`raw` keyword — ใช้ C-style: type นำหน้าชื่อตัวแปรตรงๆ
- `i` เฉยๆ = **auto** = `i64` — ใช้เมื่อไม่สนใจขนาด ให้ compiler จัดการ
- `i8`, `i32`, `i64` = **explicit** — ใช้เมื่อต้องการควบคุม memory / ขนาดข้อมูลเอง
- **Mutable by default** — แก้ค่าทีหลังได้เลย ไม่ต้องมี `mut`
- ปิดทุก statement ด้วย `;` เสมอ
- `char s[]` = string แบบ C — compiler นับจำนวน char ให้อัตโนมัติรวม `\0`

---

## 4. Pointer — `@` / `^`

```
i32 x = 42
i32^ p = @x        // ^ หลัง type = "pointer to", @ นำหน้าตัวแปร = address-of

print(p^)            // p^ = dereference (postfix)
p^ = 99              // เขียนค่าใหม่ผ่าน pointer
```
ใช้ได้กับตัวแปรทั่วไป (ทุกตัวแปรเป็น C-style จัดการเองได้อยู่แล้ว ไม่มีการแยก `let`/`raw` อีกต่อไป — ดูข้อ 25)

---

## 5. Array (ยืนยันแล้ว)

```c
// Fixed-size
i64 a[10];
a[0] = 5;
a[1] = 99;

cout << a[0];    // ปริ้น 1 ตัว = 5
cout << a[];     // ปริ้นทั้งหมด = 5 99 0 0 0 ... (เว้นวรรคคั่น)

// Multi-dimensional
i64 matrix[3][3];
matrix[0][0] = 1;

// Array of struct
Point arr[10];
arr[0] = {1, 2};
cout << arr[0].x;

// Dynamic
i64[] list = arr(10);
list.push(5);
list.pop();
list[0];
list.len;
list.free();

// ส่งเข้าฟังก์ชัน
void print_all(i64 a[10]) {
    cout << a[];
}
```

**กติกา:**
- ค่า default ของ element ที่ไม่กำหนด = **garbage แบบ C** (ไม่ zero อัตโนมัติ)
- `cout << a[]` = ปริ้นทุก element เว้นวรรคคั่น
- `cout << a[0]` = ปริ้น element เดียว
- compiler แนบความยาวตอนส่งเข้าฟังก์ชัน ไม่ decay เป็น pointer แบบ C
- bounds check เฉพาะ debug build (`-d` flag)
- Dynamic array ต้อง `.free()` เอง

### 5a. Dynamic Array — ขอบเขต bootstrap (ยืนยันแล้ว)

- **`.insert()` / `.sort()` — ยังไม่มีตอน bootstrap** เริ่มต้นมีแค่ `push`/`pop`/`len`/`free`/`[]` เท่านั้น อยาก insert กลาง array หรือ sort ต้อง manual เขียนเอง (shift/algorithm เอง) ไปก่อน — **ตั้งใจเพิ่มทีหลังหลัง bootstrap ขั้นแรกเสร็จแล้ว** ไม่ใช่ตัดทิ้งถาวร
- **Bounds check ของ dynamic array ใช้ mechanism เดียวกับ fixed array** — ผูกกับ `-d` flag (debug build เท่านั้น) ใช้ guard-bytes mechanism เดิม (ข้อ 5 เดิม/ข้อ 26) ไม่ต้องสร้างระบบใหม่แยกสำหรับ dynamic array

---

## 6. Function Declaration — C++-style

```
i32 add(i32 a, i32 b) {
    return a + b
}

void print_hello() {
    print("hi")
}
```
Return type นำหน้าแบบ C++ ไม่มี `fn`/`->` — parameter ระบุ type นำหน้าชื่อ (`i32 a` ไม่ใช่ `a: i32`)

---

## 7. If / Loop

```
if x > 5 {
    print("big")
}
```
ไม่บังคับวงเล็บครอบเงื่อนไข ครอบ body ด้วย `{}` เสมอ — brace style อิสระ (`{` ต่อท้ายบรรทัดเดียวกันหรือขึ้นบรรทัดใหม่ก็ได้)

**`else` / `else if` (ตัดสินใจ 2026-08-21 — ยืนยันแล้ว, จำเป็นต้องมี):** ตามแนว C ตรงๆ (ไม่มี `elif` แบบ Python) — `else` และ `else if` (สองคำแยกกัน ไม่ใช่ keyword เดี่ยว) ต่อ chain ได้ตามปกติ `{}` บังคับเสมอเหมือน `if`:
```
if x > 5 {
    print("big")
} else if x > 0 {
    print("small")
} else {
    print("non-positive")
}
```

**⚠️ ยังไม่ได้ออกแบบ:** ~~`while`/`for` loop syntax~~ — แก้ไข: ล็อคไว้แล้วจริงๆ ดูหัวข้อ 18 (ธงนี้ค้างมาจากก่อนล็อค ลบทิ้งเมื่อ 2026-08-21)

---

## 8. Switch (เดิมชื่อ Match — เปลี่ยนเป็น `switch`) (ยืนยันแล้ว)

```c
switch s {
    Status::OK: cout << "ok";
    using enum Status;                // จากบรรทัดนี้เป็นต้นไป ไม่ต้อง qualify Status:: อีก
    NotFound: cout << "not found";
    _: cout << "other";
}
```

**กติกา:**
- ใช้ keyword **`switch`** (คำเต็มแบบ C/C++ ไม่ใช่ `match` หรือคำย่อ `sw`)
- ปิดแต่ละ case ด้วย `;` ไม่มี fallthrough (compiler จัดการ break อัตโนมัติ)
- `_` = wildcard/default case ครอบกรณีที่เหลือทั้งหมดที่ไม่มี case ตรงๆ ระบุไว้ก่อนหน้า
- **Exhaustive check ผูกกับ `-st` (strict mode)**:
  - ไม่มี `-st` → ขาด case ไป **แค่ warning** เตือนว่า enum ตัวนี้ยังไม่ครบ ยัง compile ผ่านได้ (เหมาะตอน dev/prototype เร็วๆ)
  - มี `-st` → ขาด case ไป **error ทันที** ไม่ยอม compile (เหมาะตอน build จริง/publish) — ใส่ `_` ครอบไว้ถือว่า exhaustive แล้ว ไม่ error
  - ใช้ flag `-st` ที่มีอยู่แล้วในระบบ ไม่ต้องเพิ่ม flag ใหม่

### 8a. `using enum X;` — shorthand เข้าถึงสมาชิก enum โดยไม่ qualify (ยืนยันแล้ว)

```c
void f() {
    using enum Status;   // local ในฟังก์ชันนี้
    Status s = OK;         // ใช้ OK แทน Status::OK ได้เลย
}
```

**กติกา:**
- **ใช้ได้ทั่วไป ไม่จำกัดแค่ใน `switch`** — เดินตามกฎเดียวกับ `using` ปกติ (ข้อ 1): เขียนนอกฟังก์ชัน = global ทั้งไฟล์, เขียนในฟังก์ชัน/block = local เฉพาะที่นั้น เหตุผลที่ไม่แยกกฎพิเศษเฉพาะ `switch`: กฎเดียวใช้ได้ทุกที่ ง่ายกว่าต้องจำ 2 ระบบคู่ขนาน (ปกติ + เฉพาะ switch) ลดโอกาสสับสนตอนเขียนและตอน implement compiler
- **มีผลนับจากบรรทัดที่เขียนเป็นต้นไปเท่านั้น ไม่ย้อนขึ้นไปข้างบน** — case/statement ที่อยู่ก่อนบรรทัด `using enum` ต้อง qualify เต็ม (`Status::OK`) ส่วนหลังจากนั้นใช้แบบสั้นได้ (`OK`) เหตุผล: สอดคล้องกับพฤติกรรม `using` แบบ local ที่มีอยู่แล้ว (มีผลจากจุดที่ประกาศเป็นต้นไปในขอบเขตนั้น ไม่ใช่ hoist ขึ้นไปทั้ง block) ทำให้ compiler อ่านจากบนลงล่างตรงไปตรงมา ไม่ต้อง scan ทั้ง block ล่วงหน้าก่อนรู้ว่าบรรทัดไหนใช้ shorthand ได้

---

## 9. Struct (ยืนยันแล้ว)

```c
struct Point {
    i32 x;
    i32 y;

    void init(self) {      // init = constructor รันอัตโนมัติตอนสร้าง instance
        self.x = 0;
        self.y = 0;
    }
}

Point p;              // ประกาศเปล่า — init() รันอัตโนมัติ
Point p = {0, 0};     // init พร้อมกำหนดค่า — ต้องระบุทุก field ด้วย {}
```

**กติกา:**
- field ต้องระบุ type เสมอ แบบ C-style (`i32 x;`)
- `init(self)` = constructor — `self` keyword พิเศษไม่ต้องระบุ type
- `self.field` เข้าถึง field ใน method ได้เลย
- สร้าง instance ต้องใช้ `{}` เสมอถ้ากำหนดค่า — ไม่รองรับ assign ค่าเดียวตรงๆ (`Point p = 10` ใช้ไม่ได้)
- struct ซ้อน struct ได้ เข้าถึงด้วย `.` ต่อกัน (`p.position.x = 10`)

### 9a. Struct Method ทั่วไป (ยืนยันแล้ว)

```c
struct Point {
    i32 x;
    i32 y;

    void init(self) {
        self.x = 0;
        self.y = 0;
    }

    void move(self, i32 dx, i32 dy) {
        self.x = self.x + dx;
        self.y = self.y + dy;
    }

    i32 distance_from_origin(self) {
        return self.x * self.x + self.y * self.y;
    }

    void reset(self) {
        self.move(-self.x, -self.y);   // เรียก method อื่นผ่าน self ได้
    }
}

Point p;
p.move(5, 3);
i32 d = p.distance_from_origin();
```

**กติกา:**
- Method ทั่วไป (ไม่ใช่ `init`) ใช้ pattern เดียวกัน — `self` เป็น parameter แรกเสมอ, return type ระบุได้ตามปกติ (ไม่ต้อง `void` เท่านั้น)
- **ไม่อนุญาต method overloading** — ชื่อ method ซ้ำกันในโครงสร้างเดียว (parameter ต่างกัน) ไม่ได้ ทุกชื่อ method ต้องไม่ซ้ำกันภายใน struct เดียวกัน (ตรงปรัชญา C ล้วนๆ ไม่ต้องมี compiler logic เลือก overload ตาม argument type/count)
- **เรียก method อื่นผ่าน `self.other_method()` ได้** — เป็นธรรมชาติ ไม่มีข้อจำกัด

---

## 10. Error Handling — try/catch/throw

```
void read_file(string path) {
    if !exists(path) {
        throw "file not found"
    }
}

void main() {
    try {
        read_file("x.txt")
    } catch (e) {
        print(e)
    }
}
```
v0.1: throw string ธรรมดา ไม่มี error class/hierarchy แยกประเภทก่อน

---

## 11. Enum (ยืนยันแล้ว)

```c
enum class Status { OK = 0, NotFound = 404, ServerError = 500 };

Status s = Status::OK;
i32 code = (i32)s;              // cast กลับเป็นเลข = 0

if s == Status::NotFound {
    print("not found");
}
```

**กติกา:**
- Scoped แบบ C++11 (`enum class`) — เข้าถึงสมาชิกต้อง qualify ด้วย `EnumName::Member` เสมอ กันชื่อชนกันข้าม enum
- กำหนดค่าเองได้ (`= value`) เหมาะกับ error code/syscall ที่มีเลขตายตัว
- สมาชิกที่ไม่ระบุค่า = auto-increment จากตัวก่อนหน้า +1 (ถ้าตัวแรกไม่ระบุ = เริ่มจาก 0) แบบ C
- Cast กลับเป็นเลขได้ด้วย type casting ปกติ `(i32)s`
- สอดคล้องกับ `::` ที่ใช้กับ namespace อยู่แล้ว (เช่น `math::dot()`)

---

## 12. Concurrency (ยืนยันแล้ว)

```c
import cpu
using cpu::thread

void download(void^ arg) {
    char^ u = (char^)arg;
    // ใช้ u^ อ่านค่า url
}

void main() {
    char url[] = "http://a.com";
    Thread t = create(download, @url);

    cout << "thread started\n";

    t.join();
    cout << "thread finished\n";
}
```

**กติกา:**
- `Thread` เป็น `struct` static-only เหมือน pattern `File` (ข้อ 27) — `create()`/`.join()` มาจาก `Thread::` แต่ย่อด้วย `using` ได้
- `import cpu` แยกเป็น module ของตัวเอง **ไม่รวมเข้า `std`** (ต่างจาก `File` ที่รวมใน `import std` — cpu/thread เป็นงานเฉพาะทาง แยกไว้เพื่อไม่ให้ `std` บวมและหายาก)
- **ไม่มี `async`/`await`** — ตัดทิ้ง ขัดปรัชญา "ชิด CPU" ของภาษา (เป็น abstraction ระดับสูงที่ซ่อนกลไก thread/scheduler ไว้ข้างใต้ ต้องมี state machine transform ในคอมไพเลอร์ซึ่งซับซ้อนเกินความจำเป็น)
- **`create()` รับ 1 argument เท่านั้น** (ไม่ใช่ variadic) — ฟังก์ชันที่จะ spawn ต้องมี signature ตายตัว `void f(void^ arg)` รับ generic pointer เดียว ถ้าต้องการส่งหลายค่า ห่อเป็น `struct` เองแล้วส่ง `@struct_instance` เข้าไป (แบบ C/pthread ดั้งเดิม)
- **ห้ามเรียก `.join()` จากภายในฟังก์ชันที่ thread ตัวเองกำลังรัน** (`t.join()` ข้างในฟังก์ชันของ `t` เอง) — จะเกิด deadlock (รอตัวเองจบ) ต้องเรียก `.join()` จาก thread อื่น (โดยทั่วไปคือ main) เท่านั้น
- Argument ส่งผ่าน pointer (`@url`) ไม่ copy ข้อมูล — ผู้เขียนต้องรับผิดชอบ lifetime เอง (ตัวแปรต้นทางต้องยังไม่หลุด scope ก่อน thread อ่านเสร็จ) ตรงกับปรัชญา manual memory control ของภาษา

### ⚠️ ยังไม่ได้ออกแบบ (ค้างต่อจากนี้)
- [ ] ThreadPool (งานหนักจำนวนมาก) — เลื่อนไว้ก่อน ไม่จำเป็นสำหรับ bootstrap

### 12c. `#multithread` — Directive สำหรับ parallel loop (ยืนยันแล้ว)

```c
#multithread
for i in 0..1000 {
    process(tasks[i]);
}
```

**กติกา:**
- ใช้ `#` นำหน้าตรงๆ แบบเดียวกับ `#define` (ข้อ 23) ไม่ใช้ `#pragma` ห่อ (สั้นกว่า พิมพ์น้อยกว่า)
- แปะไว้บรรทัดก่อน `for` loop — บอก compiler ว่าลูปนี้แต่ละรอบไม่ขึ้นต่อกัน แตกไปทำงานคู่ขนานหลาย thread ได้เลย
- ผู้เขียนรับผิดชอบเองว่าลูปนั้น "แตกคู่ขนานได้จริง" (ไม่มี dependency ระหว่างรอบ) — compiler ไม่ validate ความถูกต้องเชิง logic ให้ (ถ้าแปะผิดกับลูปที่ต้องรันตามลำดับ ผลลัพธ์จะผิดแบบเงียบๆ ไม่มี error เตือน)
- ใช้ได้กับ `for` loop เท่านั้น (ทั้งแบบ C-style และ range-style ข้อ 18) ไม่ใช้กับ `while`
- เบื้องหลัง compiler generate การแบ่งงานให้ thread หลายตัวเอง (จำนวน thread ที่ใช้ขึ้นกับ implementation ของ compiler ยังไม่ fix จำนวนตายตัว) — ผู้เขียนไม่ต้องยุ่งกับ `Thread::create()`/`.join()` เองสำหรับกรณีนี้

### 12b. `.detach()` (ยืนยันแล้ว)

```c
void main() {
    char url[] = "http://a.com";
    Thread t = create(save_log, @url);
    t.detach();
    // main จบตรงนี้ได้เลย ไม่ต้องรอ t
}
```

**กติกา:**
- `.detach()` = ปล่อยให้ thread ทำงานเบื้องหลัง ตัดขาดจากตัวแปรที่ถืออยู่ — ไม่ต้อง `.join()` อีกต่อไป
- **เรียก `.join()` หลัง `.detach()` (หรือซ้ำ `.detach()`)** → **runtime error**: `cannot join a detached thread` (ตรวจตอน compile time ไม่ได้ เพราะเป็น runtime state)
- **Thread ที่ detach แล้วยังเช็คสถานะได้** เช่น `.is_running()` — แค่ `.join()`/`.detach()` ซ้ำเรียกไม่ได้เท่านั้น (ไม่ได้ตัดขาดสมบูรณ์ทุก method)
- **Main จบ → detached thread ที่ยังไม่เสร็จตายตามทันที** (ตรงกับพฤติกรรม OS thread จริง process ตาย = thread ทั้งหมดตายไปด้วย) — ไม่มี grace period/timeout รอ ตรงปรัชญา "ชัดเจน ไม่มี magic ซ่อน" ของภาษา ผู้เขียนต้องเรียก `.join()` เองถ้าอยากรับประกันงานเสร็จก่อนโปรแกรมจบ

### 12a. Mutex (ยืนยันแล้ว)

```c
Mutex m;
i32 counter = 0;

void increment(void^ arg) {
    m.lock();
    counter = counter + 1;
    m.unlock();
}
```

**กติกา:**
- `Mutex` เป็น **struct instance ปกติ** (ต้องสร้าง `Mutex m;` จริง มีสถานะของตัวเอง) — ต่างจาก `File`/`Thread` ที่เป็น static-only struct (ข้อ 27, ข้อ 12) เพราะ mutex ต้องมี "สถานะล็อคอยู่หรือไม่" ผูกกับ instance
- `.lock()` / `.unlock()` เป็น **manual เท่านั้น** — ไม่มี scope guard/RAII (ไม่ต้องเพิ่ม destructor concept ใหม่ในภาษา)
- **ป้องกันการลืม `unlock()` ด้วย compile-time static analysis**: compiler เดินตรวจทุกเส้นทางที่ฟังก์ชันจบ (ทุก `return`, ทุก path ถึง `}` ปิดท้าย) — ถ้ามี `.lock()` ที่ไม่มี `.unlock()` คู่กันในเส้นทางออกใดเส้นทางหนึ่ง → **warning ตอน compile time**:
  ```c
  void increment(void^ arg) {
      m.lock();
      if some_error {
          return;   // ⚠️ warning: 'm' locked but not unlocked on this path
      }
      counter++;
      m.unlock();
  }
  ```
- เป็น warning ไม่ใช่ error (เหมือน pattern switch ไม่ครบ case ข้อ 8 ตอนไม่มี `-st`) — ปล่อยให้ compile ผ่านได้ แต่เตือนชัดเจน

---

## 13. Entry Point

```
void main() {
    // จุดเริ่มโปรแกรม
}
```

---

## 14. String (ยืนยันแล้ว)

```c
char s1[] = "hello\nworld";      // escape มาตรฐาน: \n \t \" \\
char s2[] = r"C:\Users\name";    // raw string ไม่ escape
```

**String interpolation ตัดทิ้ง — ไม่มี `"value: {x}"`** ใช้ `cout <<` ต่อค่าแทนทั้งหมด (ตามข้อ 15):
```c
cout << "value: " << x << "\n";
```

---

## 15. I/O พื้นฐาน (ยืนยันแล้ว)

```c
// --- Output ---
cout << "hello " << x << "\n";     // integer / string
coutf << "pi = " << pi << "\n";    // float — precision ดีกว่า รับทศนิยมได้เยอะกว่า

// --- Input ---
cin >> x;      // รับ integer — strict (กรอก string ไม่ได้ถ้า x เป็น i/i32/i8)
cinf >> x;     // รับ float — รองรับทศนิยม precision สูง คำนวณได้ดีกว่า
```

**กติกา:**
- `cout` / `cin` → ใช้กับ integer (`i`, `i32`, `i64`, `i8`) และ string (`char[]`)
- `coutf` / `cinf` → ใช้กับ float type (`f32`, `f64`) — precision สูงกว่า
- `cin` smart ตาม type — compiler รู้เองว่าตัวแปรเป็น type ไหน รับค่าให้ถูกต้องอัตโนมัติ
- chain ด้วย `<<` (output) และ `>>` (input) แบบ C++
- compiler รู้ type ของตัวแปรอยู่แล้ว ไม่ต้องมี format specifier (`%d`, `%f`)
- ทุก statement ปิด `;` เสมอ

**`cin` กับ `char[]` — Bounds:**
```c
char a[5] = "";
cin >> a;    // กรอก "hello world" → เกิน size
```
- **ตัดทิ้ง** — รับได้แค่ `n-1` ตัว (เหลือที่ให้ `\0`) แล้วหยุด
- **เตือน** พร้อมบอกจำนวนที่รับได้จริง — คำนวณอัตโนมัติจาก size ที่ประกาศ:
```
warning: input truncated — 'a' accepts max 4 characters (char[5] - 1 for \0)
```

---

## 16. Forward Declaration (ยืนยันแล้ว)

compiler scan ทั้งไฟล์ก่อน — เรียกฟังก์ชันที่อยู่ด้านล่างได้เลยโดยไม่ต้อง declare ก็ได้ แต่ declare ก็ได้ถ้าอยากชัดเจน ทั้งสองแบบ compiler รับได้

```c
// แบบไม่ declare — compiler รู้จักเองจากการ scan ทั้งไฟล์
i main() {
    greet();
    cout << add(1, 2);
    return 0;
}

i32 add(i32 a, i32 b) { return a + b; }
void greet() { cout << "hi"; }

// แบบ declare ก่อน — ถ้าอยากชัดเจน
i32 add(i32 a, i32 b);
void greet();

i main() {
    greet();
    cout << add(1, 2);
    return 0;
}
```

---

## 17. Return (ยืนยันแล้ว)

```c
i32 add(i32 a, i32 b) {
    return a + b;     // ส่งค่ากลับให้คนที่เรียก
}

void greet() {
    cout << "hi";
    return;           // จบฟังก์ชัน — ละไว้ได้ถ้าอยู่ท้ายสุด
}

i main() {
    return 0;         // บอก OS ว่าโปรแกรมจบปกติ (0 = success)
}
```

**กติกา:**
- `void` → ไม่ส่งค่ากลับ, `return;` เปล่าๆ หรือละไว้ท้ายฟังก์ชันได้
- type อื่น (`i`, `i32`, `f32` ฯลฯ) → ต้อง `return ค่า;` เสมอ
- `main` return `0` = โปรแกรมจบปกติ, return ค่าอื่น = error code

---

## 18. Loop — `while` / `for` (ยืนยันแล้ว)

```c
// while
while x < 10 {
    x++;
}

// for แบบ C
for i32 i = 0; i < 10; i++ {
    cout << i;
}

// for แบบ range — 0..10 = exclusive (i = 0,1,...,9 ไม่รวม 10)
for i in 0..10 {
    cout << i;
}
```

**กติกา:**
- `while` ไม่บังคับวงเล็บ เหมือน `if`
- `for` รองรับ 2 รูปแบบ — C-style และ range style
- `..` = exclusive (ไม่รวมตัวสุดท้าย)

---

## 19. Compound Assignment / Increment (ยืนยันแล้ว)

```c
x++;       // เพิ่ม 1
x--;       // ลด 1
x += 2;    // เพิ่ม 2
x -= 3;    // ลด 3
x *= 2;    // คูณ 2
x /= 4;    // หาร 4
```

---

## 20. Break / Continue (ยืนยันแล้ว)

```c
while x < 10 {
    if x == 5 { break; }      // หยุด loop ทันที
    if x == 3 { continue; }   // ข้ามไป iteration ถัดไป
    x++;
}
```

ใช้ได้กับทั้ง `while` และ `for` ทั้งสองรูปแบบ

---

## 21. Operators (ยืนยันแล้ว)

```c
// Logical
if x > 0 && y > 0 { }    // and
if x == 0 || y == 0 { }  // or
if !done { }               // not
if x != 5 { }             // not equal

// Modulo
i32 r = 10 % 3;           // = 1 (เหลือจากการหาร)
```

---

## 22. Type Casting — C-style (ยืนยันแล้ว)

```c
f32 pi = 3.14;
i32 x = (i32)pi;    // = 3 (ตัดทศนิยมทิ้ง)
```

---

## 23. `#define` — Preprocessor Directive (ยืนยันแล้ว)

```c
#define MAX 100
#define PI 3.14
#define APP_NAME "J2K"

i main() {
    cout << MAX;
    cout << APP_NAME;
    return 0;
}
```

**กติกา:**
- `#` นำหน้า — เป็น directive พิเศษ ไม่ใช่ statement ธรรมดา
- **ไม่บังคับ `;`** ปิดท้าย (ยกเว้นให้เพราะไม่ใช่ statement)
- compiler แทนค่าก่อน compile (text substitution)
- ไม่มี type — (เดิมเขียนว่าถ้าต้องการ type ใช้ `const` แทน — **ผู้ใช้ตัดสินใจ 2026-10-07 ว่า `const` ไม่จำเป็น ไม่ทำ**)

---

## 24. Operator Precedence Table (ยืนยันแล้ว)

ตารางมาตรฐานแบบ C/C++ (จากสูงไปต่ำ, ตัวที่สูงกว่าคำนวณก่อน):

| ลำดับ | Operator | ความหมาย |
|---|---|---|
| 1 (สูงสุด) | `()` `[]` `.` `::` | เรียกฟังก์ชัน, index, member access, namespace |
| 2 | `!` `-` (unary) `(type)` `@` `^` (deref) | not, unary minus, cast, address-of, dereference |
| 3 | `*` `/` `%` | คูณ หาร มอด |
| 4 | `+` `-` | บวก ลบ |
| 5 | `<` `>` `<=` `>=` | เปรียบเทียบ |
| 6 | `==` `!=` | เท่ากับ ไม่เท่ากับ |
| 7 | `&&` | and |
| 8 (ต่ำสุด) | `\|\|` | or |
| — | `=` `+=` `-=` `*=` `/=` | assignment (ทำหลังสุดเสมอ, right-to-left) |

ตัวอย่าง: `a + b * c == d && e > f` เท่ากับ `((a + (b * c)) == d) && (e > f)`

ตรงกับลำดับมาตรฐานของ C/C++/Rust — ใช้ตรงๆ ไม่ปรับเปลี่ยน เพราะโปรแกรมเมอร์ทุกคนคุ้นเคยลำดับนี้อยู่แล้ว

---

## 25. Reserved Keywords & Symbols (สรุปรวม — อ้างอิงจากทุกหัวข้อที่ตัดสินใจแล้ว)

> หัวข้อนี้เป็นการ**รวบรวม** สิ่งที่ตัดสินใจไปแล้วกระจายอยู่ทั้งไฟล์มาไว้ที่เดียว ไม่ใช่การตัดสินใจใหม่ — มี 2 จุดค้างต้องยืนยันก่อนปิดเป็นทางการ (ดูท้ายหัวข้อ)

### Keywords (คำสงวน)

| หมวด | Keyword |
|---|---|
| Type | `i8` `i32` `i64` `f32` `f64` `char` `void` |
| Control flow | `if` `else` `while` `for` `switch` `using` `enum` |
| Struct/OOP | `struct` `self` `init` |
| Function | `return` |
| Error handling | `try` `catch` `throw` |
| Import | `import` |
| Literal | `true` `false` `null` |
| Preprocessor | `#define` |
| Wildcard | `_` (ใช้ใน `switch` เท่านั้น) |

### Operators/Symbols (สัญลักษณ์สงวน)

| หมวด | สัญลักษณ์ |
|---|---|
| Arithmetic | `+` `-` `*` `/` `%` |
| Comparison | `==` `!=` `<` `>` `<=` `>=` |
| Logical | `&&` `\|\|` `!` |
| Assignment | `=` `+=` `-=` `*=` `/=` |
| Increment/Decrement | `++` `--` |
| Pointer | `@` (address-of) `^` (pointer type / dereference) |
| Access | `.` (member access / import sub-path) `::` (namespace / enum scope) |
| Grouping | `()` `{}` `[]` |
| Statement/separator | `;` `,` |
| Preprocessor/comment | `#` `//` `/* */` |
| String | `"..."` `r"..."` |

**สัญลักษณ์ที่ทำงาน 2 หน้าที่ต่างบริบทกัน (ต้องแยกด้วยตำแหน่ง/บริบทตอนเขียน parser):**
- `^` — "pointer type" ถ้าอยู่หลัง type (`i32^`), "dereference" ถ้าอยู่หลัง identifier (`p^`)
- `.` — "member access" ถ้าอยู่นอก `import`, "sub-path" ถ้าอยู่ใน `import "..."`
- `::` — namespace กับ enum scope ทำหน้าที่เดียวกันจริง (scope resolution) ไม่ถือว่าชนกัน

### ✅ ยืนยันปิดแล้ว
1. **`raw`** — ตัดทิ้งแล้ว ไม่มี concept แยก `let`(auto)/`raw`(manual) อีกต่อไป เพราะทุกตัวแปรเป็น C-style ล้วน มี memory model เดียว (mutable by default, จัดการเองได้อยู่แล้วตามข้อ 8.24) — ไม่ใช่ keyword ของภาษา
2. **`match`** — ถูกแทนที่ด้วย `switch` แล้ว (ข้อ 8) ไม่ใช่ keyword ของภาษา คงชื่อไว้แค่ในประวัติการเปลี่ยนแปลง

---

## 26. `#define` + Array Size (ยืนยันแล้ว)

```c
#define SIZE 10
i64 a[SIZE];       // ใช้ #define แทน array size ได้ — ผลตามธรรมชาติของ text substitution (ข้อ 23)
```

**กติกา — 3 ระดับป้องกัน (ใช้ร่วมกันทั้งหมด):**

1. **Compile-time validation** — ค่าที่ `#define` แทนเข้ามาในตำแหน่ง array size ต้องเป็นจำนวนเต็มบวกจริง ไม่งั้น error ทันที
   ```c
   #define SIZE -1
   i64 a[SIZE];    // error: array size must be a positive integer, got '-1'
   ```
2. **ต้องประกาศก่อนใช้เสมอ** — `#define` เป็น text substitution ล้วนๆ ไม่ scan ทั้งไฟล์แบบฟังก์ชัน (ต่างจาก forward declaration ข้อ 16) ใช้ก่อนประกาศ = error
   ```c
   i64 a[SIZE];       // error: 'SIZE' is not defined
   #define SIZE 10
   ```
3. **Bounds checking เชื่อมกับ debug build (`-d`) ที่มีอยู่แล้ว** — ค่าจาก `#define` กลายเป็น literal number ธรรมดาตอน compile ใช้ guard-bytes mechanism เดิม (ข้อ 8.19) ได้ทันที ไม่ต้องสร้างระบบใหม่
   ```bash
   Jcmp main.jk -o main -d
   ```
   ```c
   #define SIZE 10
   i64 a[SIZE];
   a[15] = 1;    // runtime error (debug build เท่านั้น): index out of bounds — array size is 10
   ```

---

## จุดที่ยังต้องออกแบบต่อ (ยังไม่ล็อค)

### ✅ ปรับแล้ว
- [x] ตัวแปร C-style (ตัด let/raw)
- [x] Pointer `i32 p^ = @x`
- [x] Array fixed/dynamic/multi-dim
- [x] Loop while/for + break/continue
- [x] Compound assignment `++` `--` `+=` `-=`
- [x] Operators `&&` `||` `!` `!=` `%`
- [x] Type casting `(i32)x`
- [x] `#define` preprocessor
- [x] I/O cout/cin/coutf/cinf
- [x] Forward declaration
- [x] Return
- [x] Struct field type + init(self)
- [x] Enum syntax (`enum class` + explicit value + auto-increment)
- [x] Switch (เดิม match) — keyword `switch`, exhaustive ผูก `-st`, `using enum X`
- [x] Operator precedence table
- [x] String interpolation — ตัดทิ้ง ใช้ `cout <<` แทนทั้งหมด
- [x] Module import — local/relative/absolute/search path (`.` cascade, `./` = absolute root, `-I` flag)
- [x] `#define` + array size — ได้ พร้อม 3 ระดับป้องกัน

### ✅ ปรับแล้ว (ต่อ)
- [x] File I/O — ปิดหัวข้อครบ (ดูข้อ 27 ท้ายไฟล์)

---

## 27. File I/O (ยืนยันแล้ว — โครงหลัก)

```c
import std::file
using File

void main() {
    i32 f = File::open("data.txt", FileMode::Read);
    char buf[256];
    read(f, buf);      // = File::read(f, buf) เพราะ using File แล้ว
    close(f);
}
```

**กติกา:**
- `File` เป็น **`struct`** ที่รวม **`static` method** ทั้งหมด (ไม่มี field, ไม่มี `self`) — ทำหน้าที่เหมือน namespace ของฟังก์ชัน ไม่ใช่ instance/object
- `static` method เรียกผ่านชื่อ struct ตรงๆ ด้วย `::` (`File::open(...)`) ไม่ต้องสร้าง instance ก่อน
- ตัว handle ที่ได้จาก `File::open` เป็น `i32` (file descriptor แบบใกล้ POSIX/syscall) ไม่ใช่ struct/pointer
- ใช้ `using File;` (ตามกฎ `using` ข้อ 1 ปกติ ไม่มี syntax พิเศษแยก) เพื่อเรียกฟังก์ชันสั้นได้โดยไม่ต้อง `File::` ซ้ำ — ต้อง `import` module ที่มี `File` เข้ามาก่อนเสมอ (`import std::file`) ถึงจะ `using` ได้
- ฟังก์ชันที่มีอยู่ตอนนี้ (โครงร่าง ยังไม่ปิด signature เต็ม): `File::open(path, mode)`, `read(fd, buf)`, `write(fd, buf)`, `close(fd)`
- `read(f, buf)` ไม่ต้องส่ง size แยก — ใช้กฎเดิมของ array (ข้อ 5): `char buf[256]` เป็น fixed-size แนบความยาวให้ compiler อัตโนมัติตอนส่งเข้าฟังก์ชันอยู่แล้ว

### ✅ ยืนยันครบแล้ว — File I/O ปิดหัวข้อ

1. **`static` keyword** — เพิ่มเข้า Keyword table (ข้อ 25) แล้ว
2. **Struct ไม่มี field เลย (เช่น `File`) แล้วสร้าง instance** (`File f;`) → **warning** (ไม่ error): `warning: 'File' is a static-only struct, instantiating it has no effect`
3. **Struct ผสม static + instance method ปนกันได้** — แต่เรียกผิดแบบ (เช่น `p.origin()` เรียก static ผ่าน `.`, หรือ `Point::init()` เรียก instance method ผ่าน `::` โดยไม่มี instance) → **compile-time error** ทันที (เหมือน pattern จับ `=`/`==` ผิดในเงื่อนไข ข้อ 21)
4. **`FileMode` enum** — ยืนยันสมาชิก:
   ```c
   enum class FileMode { Read, Write, Append, ReadWrite };
   ```
   auto-increment ปกติ (`Read=0, Write=1, Append=2, ReadWrite=3`) ไม่ผูกกับ syscall number
5. **Module** — ใช้ `import std` ก้อนเดียว (ไม่มี submodule แยกไฟล์) ข้างในแบ่งเป็นส่วนย่อย เช่น `fs`, `math`, `cpu` แล้วใช้กฎ `using ns::item` เดิม (ข้อ 1) ดึงมาเฉพาะส่วนที่ต้องการ: `using std::fs`
6. **Error handling ตอนเปิดไฟล์ไม่สำเร็จ** — **return ค่าติดลบแบบ POSIX** (ไม่ใช้ `throw`) ผู้เขียนต้องเช็คเอง:
   ```c
   i32 f = File::open("missing.txt", FileMode::Read);
   if f < 0 {
       return;
   }
   ```
7. **`read_line`** — มี เป็นฟังก์ชันแยกชื่อจาก `read` (ไม่ overload):
   ```c
   char line[256];
   read_line(f, line);   // อ่านจนเจอ \n หรือ buffer เต็ม หยุดอัตโนมัติ
   ```

### สรุปโค้ดตัวอย่างสุดท้าย (ครบทุก decision)
```c
import std
using std::fs

void main() {
    i32 f = File::open("data.txt", FileMode::Read);
    if f < 0 {
        return;
    }

    char buf[256];
    read(f, buf);

    char line[256];
    read_line(f, line);

    close(f);
}
```

---

## 28. Global Variable (ยืนยันแล้ว)

```c
i32 counter = 0;      // global — ประกาศนอกฟังก์ชันใดๆ

void increment() {
    counter = counter + 1;    // เข้าถึง global ได้ตรงๆ ไม่ต้องมี keyword พิเศษ
}

void main() {
    increment();
    cout << counter;   // = 1
}
```

**กติกา:**
- ไม่มี syntax พิเศษแยกสำหรับ global — ใช้กฎตัวแปรปกติ (ข้อ 3) แค่ตำแหน่งที่เขียน (นอกฟังก์ชัน) กำหนดว่าเป็น global เหมือน pattern `using` (ข้อ 1) ที่ตำแหน่งกำหนด scope เช่นกัน
- **ห้ามตั้งชื่อตัวแปร local ในฟังก์ชันซ้ำกับชื่อ global** — compile error ทันทีถ้าชนกัน (ไม่อนุญาตให้ shadow) กันความสับสนว่ากำลังอ่าน/เขียนตัวแปรไหนอยู่

### ⚠️ ค้างไว้คิดต่อภายหน้า
- **Multi-file global initialization order** — ถ้ามีหลายไฟล์และ global ของไฟล์หนึ่งอ้างอิงค่าจาก global อีกไฟล์ ลำดับการสร้างยังไม่ได้ออกแบบ (ปัญหาคลาสสิกแบบ C++ static initialization order fiasco) — เลื่อนไปคิดตอนออกแบบระบบ multi-file compilation จริงจัง

---

## 29. Pass by Value/Reference — Struct เข้าฟังก์ชัน (ยืนยันแล้ว)

```c
struct Point {          // เล็ก (8 bytes) — pass by value ปกติ ไม่มีปัญหา
    i32 x;
    i32 y;
}

struct BigData {         // ใหญ่ (สมมติ 8000 bytes)
    i64 buffer[1000];
}

void modify(Point p) {
    p.x = 999;   // แก้ในนี้ไม่กระทบต้นฉบับ (pass by value)
}

void process(BigData d) {   // ⚠️ warning: passing 'BigData' (8000 bytes) by value —
    // ...                   //    consider using 'BigData^' to avoid copying
}

void main() {
    Point a = {1, 2};
    modify(a);
    cout << a.x;   // = 1 (ไม่เปลี่ยน — pass by value เสมอ)

    // อยากแก้ต้นฉบับ ต้องส่ง pointer เอง ชัดเจน
    void modify_ref(Point^ p) { p^.x = 999; }
    modify_ref(@a);
    cout << a.x;   // = 999
}
```

**กติกา:**
- **Struct ส่งเข้าฟังก์ชันเป็น pass by value เสมอ** (copy ทั้งก้อน) — ตรงกับปรัชญา explicit ของภาษา (ตรงกับ array ข้อ 5 ที่แนบไปทั้งก้อนแต่ไม่ decay, และตรงกับการปฏิเสธ implicit reference/capture ในข้อ 12)
- อยากแก้ต้นฉบับ (pass by reference) ต้องส่ง pointer เอง (`@` / `^`) ชัดเจนเสมอ — ไม่มี auto-reference แบบ C++ `&`
- **Compile-time warning เมื่อ struct ที่ส่งเข้าฟังก์ชันมีขนาดเกิน 64 bytes** (ผูกกับ cache line size ของ CPU ทั่วไป เป็น threshold ปฏิบัติ ปรับได้ทีหลัง) — เตือนแนะนำให้ใช้ pointer แทนเพื่อลด overhead การ copy แต่ไม่บังคับ (compile ผ่านได้ปกติ)
- ใช้ pattern warning เดียวกับที่มีอยู่แล้วทั่วไฟล์ (switch ไม่ครบ case ข้อ 8, static-only struct ข้อ 27, mutex ไม่ unlock ข้อ 12a) ไม่ต้องเพิ่มระบบใหม่

---

## 30. Multiple Return Values (ยืนยันแล้ว)

```c
struct DivResult {
    i32 quotient;
    i32 remainder;
}

DivResult divide(i32 a, i32 b) {
    DivResult r;
    r.quotient = a / b;
    r.remainder = a % b;
    return r;
}

void main() {
    DivResult res = divide(10, 3);
    cout << res.quotient << " " << res.remainder;   // 3 1
}
```

**กติกา:**
- **ไม่มี true multiple return / tuple syntax** — ไม่เพิ่ม syntax ใหม่ในภาษาเลย
- ต้องการ return หลายค่า → ห่อเป็น `struct` แล้ว `return` struct นั้นก้อนเดียว (ใช้ pattern `struct` ข้อ 9/9a และ `return` ข้อ 17 ที่มีอยู่แล้วตรงๆ)
- อ่าน signature ชัดเจนกว่าใช้ out-parameter pointer เพราะเห็นชื่อ field มีความหมาย (`res.quotient` เข้าใจง่ายกว่า `i32^ result` ลอยๆ)

---

## 31. Docstring (ยืนยันแล้ว — ไม่มี syntax พิเศษ)

```c
// คำนวณระยะทางระหว่างจุดสองจุด
// a, b = จุดสองจุดที่จะวัดระยะ
// return: ระยะทาง (float)
f32 distance(Point a, Point b) { ... }
```

**กติกา:**
- **ไม่มี `///` แยกจาก `//`** — ใช้ comment ธรรมดา (ข้อ 1) เขียนไว้เหนือฟังก์ชันเป็น docstring ไม่เพิ่ม syntax/symbol ใหม่เข้าภาษา
- เหตุผล: เก็บไว้เป็นของที่เพิ่มทีหลังได้ถ้าต้องการ integrate กับ IDE/doc generator จริงจัง ไม่จำเป็นสำหรับ bootstrap ตอนนี้

## 32. Type Keyword ของ Jcmp ปัจจุบัน — เปลี่ยนจาก `i` เดี่ยวๆ เป็น `i64` (ยืนยันแล้ว, 2026-08-29)
- **เปลี่ยน type keyword ที่ Jcmp (compiler) รองรับจาก `i` (ตัวอักษรเดียว) เป็น `i64`** — Jao ยกขึ้นมาเองว่าตัวแปรชื่อ `i` (ตัวนับ loop ที่พบบ่อยที่สุด) กับ type keyword `i` ชนกันจนอ่านสับสน (`i i = 10;`)
- ตรงกับข้อ 8.24 ที่ล็อคไว้แล้วสำหรับภาษาเต็มในอนาคต ("`i` เฉยๆ = `i64` โดย default") — การเปลี่ยนนี้แค่ทำให้ Jcmp (subset ปัจจุบัน) เขียน `i64` แบบเต็มไปเลย ไม่มี short-form `i` เฉยๆ ให้ใช้ตอนนี้ (short-form เก็บไว้เป็นน้ำตาล syntax ของภาษาเต็มทีหลัง)
- ผลคือ `i` กลายเป็นแค่ชื่อตัวแปรธรรมดา ไม่ใช่ keyword อีกต่อไป — แก้ปัญหาการชนกันที่ dispatch level ไปในตัวโดยไม่ต้องมี logic พิเศษแยกเช็ค boundary แบบเดิม (เดิมต้องเช็คว่าตามด้วยเว้นวรรคหรือไม่ถึงจะรู้ว่าเป็น type keyword หรือชื่อตัวแปร)
- Breaking change กับ Jcmp v0-v1.2: โค้ด `.jk` เดิมทั้งหมดที่เขียนด้วย `i x = 5;` ต้องเปลี่ยนเป็น `i64 x = 5;` — อัปเดตชุดเทส t01-t16 ให้ตรงแล้ว
- ยืนยันพร้อมกันในรอบเดียวกับการเริ่ม v1.3 (function): function ใหม่ใช้ `i64` เป็น type เดียวทั้ง return type และทุก parameter (ยังไม่มี `void`, ยังไม่มี type อื่น — เก็บไว้ sub-step ถัดไป)

## 33. Function — Register Allocation (ยืนยันแล้ว, แก้ไข 2026-08-29 รอบ 2 — เปลี่ยนจาก x0-x7 เป็น x19-x26)
- **param + local variable เก็บ register slot ร่วมกัน (shared pool) สูงสุด 8 ตัวต่อฟังก์ชัน — ใช้ `x19-x26` (callee-saved ตาม AAPCS64) แทน `x0-x7` เดิม**
- เหตุผลที่เปลี่ยน: ตอนแรกเลือก x0-x7 เพราะคิดว่าเร็วสุด (ไม่มี stack-spill) แต่พลาดจุดสำคัญ — x0-x7 เป็น **caller-saved (volatile)** ตาม ARM64 ABI จริง แปลว่าทุกครั้งที่มีการเรียกฟังก์ชัน (`bl`) ต้อง save/restore ตัวแปรทั้งหมดของฝั่งเรียกลง stack **ทุกจุดที่เรียก** (ทั้งใน caller ก่อนเรียก และใน callee ตอน prologue/epilogue) — ช้ากว่าที่ควรจะเป็นมาก
- **x19-x26 เป็น callee-saved** — ABI รับประกันว่าไม่มีฟังก์ชันไหนแตะโดยไม่เซฟคืนให้ ผลคือ:
  - จุดที่ "เรียก" ฟังก์ชัน (call site) **ไม่ต้อง save/restore ตัวแปรของ caller เลย** (ต่างจากดีไซน์เดิมที่ต้องทำทุกจุดที่เรียก)
  - แต่ละฟังก์ชัน save/restore **เฉพาะตัวเอง** ตอน prologue/epilogue ครั้งเดียว (เซฟค่าเดิมของ x19-x26 ที่ยืมมาจาก caller ไว้ก่อนใช้ แล้วคืนก่อน return) — ไม่ผูกกับจำนวนจุดที่ฟังก์ชันนี้ไปเรียกคนอื่นต่อ
- **x0-x7 กลับไปใช้ตามหน้าที่ ABI จริง**: ส่ง argument เข้า (ตอนเตรียมเรียก) / รับผลลัพธ์กลับ (ตอน return) เท่านั้น — ไม่ใช่ที่เก็บถาวรของตัวแปรอีกต่อไป ค่าที่อยู่ในนั้นถือว่าใช้ได้แค่ชั่วคราวรอบๆ จุดเรียก/return
- **x9-x17 = scratch ของ compiler เอง** ระหว่างคำนวณ expression (ตามที่ codegen เดิมใช้อยู่แล้วในหลายจุด เช่น x12/x13/x14/x9/x10 ใน if-chain/while/return)
- **x18 ห้ามใช้** (platform register ตาม ABI, ระบบจองไว้)
- **x29/x30** = frame pointer / link register ตามปกติ
- ลำดับ allocate: parameter ตามลำดับประกาศได้ x19,x20,x21,... ก่อน ตัวแปรที่ประกาศเพิ่มใน body ได้ slot ถัดไปต่อเนื่องกัน (x19+n)
- ถ้า param+local รวมกันเกิน 8 ตัว -> parse_error (ยังไม่รองรับ spill ไป stack สำหรับตัวแปรเกิน — เก็บไว้เป็นงานอนาคตถ้าต้องการ)
- Prologue ของทุกฟังก์ชัน (ยกเว้น `main`): เซฟ x19-x26 เดิม (ของ caller) + x29/x30 ลง stack ก่อนใช้งาน แล้ว copy argument จาก x0-x7 (ตาม ABI ตอนเข้ามา) เข้า x19-x26 (parameter slot ของฟังก์ชันนี้) — ต้องใช้ `str`/`ldr` ทีละตัว **ไม่ใช้ `stp`/`ldp`** (j2k_asm ไม่รองรับ, เป็น limitation เดิม)
- Epilogue: mov ผลลัพธ์ (อยู่ใน register slot ใดก็ตามที่ `return` คำนวณไว้) เข้า x0 (ตาม ABI ผลลัพธ์กลับทาง x0) ก่อน restore x19-x26/x29/x30 กลับจาก stack แล้ว `ret`
- **`main` เป็นกรณีพิเศษ**: ไม่ต้อง save/restore อะไร (ไม่มี caller ให้ห่วง) `return` ใน `main` ยังคง emit exit syscall ตรงๆ เหมือนเดิม (ไม่ใช่ `ret`) ส่วนฟังก์ชันอื่นทั้งหมด `return` ต้อง mov ผลลัพธ์เข้า x0 แล้ว jump ไป epilogue ของฟังก์ชันนั้น (ไม่ exit ตรงๆ)

---

## 34. Bitwise XOR — `xor` / `xor=` (ยืนยันแล้ว, 2026-10-07)

```c
i32 a = 6 xor 3;      // = 5
a xor= 1;              // compound assignment, เหมือน +=
```

**กติกา:**
- XOR ระดับบิตใช้คำ **`xor`** (ไม่ใช้ `^` เพราะ `^` เป็น pointer ตามข้อ 4) และ compound assignment ใช้ **`xor=`**
- `xor` เป็นคำสงวน (keyword) — ห้ามใช้เป็นชื่อตัวแปร/ฟังก์ชัน
- ตัวเลือกที่ไม่เลือก: `^=` (ชนกับ `p^ = ...` ของ pointer), `xor_`, `~^`, `^^`, ฟังก์ชัน `xor(a, b)`

### ตัวดำเนินการบิตอื่น (ยืนยันแล้ว, 2026-10-07)

```c
i32 a = 6 & 3;        // and  = 2
i32 b = 6 | 3;        // or   = 7
i32 c = 6 xor 3;      // xor  = 5
i32 d = 6 << 2;       // เลื่อนซ้าย = 24
i32 e = 24 >> 2;      // เลื่อนขวา = 6
a &= 1;  b |= 4;  c xor= 2;  d <<= 1;  e >>= 1;
if a & 1 == 0 { }     // = (a & 1) == 0
```

**กติกา:**
- ตัวดำเนินการ: `&` `|` `xor` `<<` `>>` และ compound `&=` `|=` `xor=` `<<=` `>>=`
- Lexer อ่านตัวยาวที่สุดก่อน (`&&` ก่อน `&`, `||` ก่อน `|`, `<<=` ก่อน `<<`)
- `>>` ของค่ามีเครื่องหมาย (`i8` `i32` `i64`) = เลื่อนแบบรักษาเครื่องหมาย; ของ `char` (unsigned) = เติม 0
- **`shl` `shr` `shl=` `shr=` = คำพ้องความหมาย (ยืนยันแล้ว, 2026-10-07)** ของ `<<` `>>` `<<=` `>>=` — ใช้แทนกันได้ทุกที่ precedence เท่ากัน; คนที่ไม่อยากปรับตัวใช้ `<<` `>>` แบบ C ได้ตามปกติ (ไม่บังคับให้ใช้คำ); `shl`/`shr` เป็นคำสงวน ห้ามใช้เป็นชื่อตัวแปร/ฟังก์ชัน; ข้อดีคือใน `cout` เขียน `cout << a shl 2;` ได้โดยไม่ต้องใส่วงเล็บ
- **ชนกับ `cout <<` / `cin >>`:** ใน statement ของ `cout`/`cin` ตัว `<<` `>>` ระดับนอกสุดคือ stream ถ้าต้องการเลื่อนบิตต้องใส่วงเล็บ `cout << (a << 2);` (แบบ C++)
- **Precedence (ตัวเลือก A — ตัวดำเนินการบิตสูงกว่าการเปรียบเทียบ ไม่ใช่แบบ C):** ตัวดำเนินการบิตอยู่ระหว่าง `+ -` กับ `< > <= >=` เรียงจากสูงไปต่ำ: `* / %` > `+ -` > `<< >>` > `&` > `xor` > `|` > `< > <= >=` > `== !=` > `&&` > `||` — เหตุผล: `a & 1 == 0` ต้องอ่านเป็น `(a & 1) == 0` ไม่ใช่บั๊กแบบ C
- ข้อ 24 (ตาราง precedence) กับข้อ 25 (Keywords) ยังไม่ได้แก้ — รอผู้ใช้อนุญาตก่อนแก้หัวข้อเดิม ให้ถือหัวข้อ 34 นี้เป็นตัวที่ใช้งานจริงถ้าขัดกัน

### `~` bitwise not (ยืนยันแล้ว, 2026-10-07)
- `~x` กลับทุกบิต เป็น unary operator ระดับเดียวกับ `!` และ `-` (unary) — เช่น `~5` = -6; ค่าถูกตัดตามความกว้างของ context (`char c = ~c` ได้ค่า 0..255)

### cout ต่อ stream (ยืนยันแล้ว, 2026-10-07 — ตามข้อ 15)
- `cout << "x = " << x << "\n";` พิมพ์ต่อกันตามลำดับ ทุกชนิด operand ปนกันได้ (ข้อความ, ตัวเลข/expression, char, char array)
- **กติกา newline ของตัวเลข (ผมเลือกเองเพื่อให้โค้ดเดิมไม่พัง — ขอให้ผู้ใช้ทบทวน):** `cout << x;` ที่มี operand ตัวเดียวและเป็นตัวเลข ยังขึ้นบรรทัดใหม่ให้เหมือนเดิม; ถ้าต่อ stream (2 operand ขึ้นไป) ตัวเลขจะ **ไม่** ขึ้นบรรทัดใหม่ — ต้องเขียน `"\n"` เองตามตัวอย่างใน spec
- เลขฐาน 16 / 2 (`0xFF`, `0b1010`) — **ทำไว้ในคอมไพเลอร์แล้ว (แบบ C)** แต่ยังไม่ได้ยืนยันเป็นทางการ (spec ยังไม่พูดถึง) — ถ้าไม่เอา บอกได้ ถอดออกได้ง่าย


---

## 35. Pointer — การเข้าถึง element ผ่าน pointer (ยืนยันแล้ว, 2026-10-07 — ต่อจากข้อ 4)

```c
int a[4];
int^ p = @a;          // @ ของ array = ที่อยู่ของ element แรก
p[2] = 5;             // เหมือน array: ตัวเลขใน [] นับเป็นจำนวน element (compiler คูณขนาดชนิดให้)
i32 x = p[1] + p[2];
```

**กติกา:**
- `p[i]` ใช้กับตัวแปรชนิด pointer (`T^`) ได้เหมือน array (อ่าน เขียน และ compound) — ตัวเลข `i` นับเป็น element ไม่ใช่ byte
- **ไม่มีการบวก/ลบ pointer** (`p + 1` ไม่ใช่การขยับ pointer) — ใช้ `p[i]` แทนทั้งหมด
- ผู้ใช้เลือกตัวเลือกนี้เพราะเรียบง่าย ไม่กำกวม ไม่มีบั๊กแบบ `p+1` ของ C

---

## 36. System call และ argument บรรทัดคำสั่ง — กลไกภายใน/ชั่วคราว (ผู้ใช้เลือกข้อ ข เมื่อ 2026-10-07)

> **สถานะ:** ไม่ใช่ syntax ทางการของภาษา — เป็นกลไกภายในที่ AI ใส่ไว้ชั่วคราวเพื่อให้มีทางอ่าน/เขียนไฟล์ระหว่างรอ `File::open`/`read`/`write`/`close`/`read_line` ตามข้อ 27 (ซึ่งเป็น API จริงที่ผู้ใช้ตัดสินใจไว้แล้ว) ข้อ 27 ต้องมี `struct` static method, `enum class FileMode`, `::`, `using`, `import std` ก่อนจึงจะทำได้ เมื่อข้อ 27 ใช้ได้ `syscall` จะถูกซ่อนไว้ข้างใต้ `File::` ไม่ให้ผู้ใช้เรียกตรง
> **`argc()` / `arg(i)`:** spec ไม่มีเรื่อง argument บรรทัดคำสั่ง (ใช้ `void main()`) — เป็นของชั่วคราวเช่นกัน **รอผู้ใช้ตัดสินใจ**

```c
// เขียนข้อความลงจอ: write(fd=1, buf, 4)
char msg[] = "sys\n";
syscall(64, 1, @msg, 4);

// อ่านไฟล์: openat(AT_FDCWD, path, O_RDONLY) -> read -> close
char path[] = "data.txt";
int fd = syscall(56, -100, @path, 0, 0);
if fd < 0 { /* ผิดพลาด: ค่าติดลบ = -errno แบบ POSIX */ }
char buf[256];
int n = syscall(63, fd, @buf, 255);
syscall(57, fd);

// อาร์กิวเมนต์บรรทัดคำสั่ง:  ./prog in.jk out.jasm
int count = argc();          // 3 (ชื่อโปรแกรมนับเป็นตัวที่ 0)
char^ input = arg(1);        // "in.jk"  (ข้อความ 0-terminated)
syscall(93, 0);              // exit(0)
```

**กติกา:**
- `syscall(เลข, a1, ..., a6)` เป็นฟังก์ชันในตัว (built-in) ไม่ต้อง import: รับเลข syscall ของ Linux ARM64 ตัวแรก ตามด้วย argument 0–6 ตัว (ทุกตัวเป็นจำนวนเต็ม; pointer ส่งเป็น `@x`/`@arr`/`char^`) คืนค่า `int` (64 บิต) = ผลของ kernel; ถ้าล้มเหลวได้ค่าติดลบ (-errno) ตามที่ข้อ 27 กำหนดไว้ว่าไม่ใช้ `throw`
- เลข syscall ที่ใช้บ่อย (Linux ARM64): 56 openat, 57 close, 63 read, 64 write, 93 exit; ค่า `AT_FDCWD` = -100
- เหตุผลที่มีไว้ชั่วคราว: เล็กและครอบคลุมทุกอย่าง จึงใช้เป็นฐานเขียน `File::open`/`read`/`write` ของข้อ 27 ทีหลังได้โดยไม่ต้องแก้ภาษา
- `argc()` = จำนวน argument รวมชื่อโปรแกรม; `arg(i)` = `char^` ชี้ไปที่ข้อความของ argument ที่ i (นับจาก 0); `main` ยังเป็น `void main()` เหมือนเดิม ไม่ต้องมีพารามิเตอร์ (ไม่ใช้ `main(int argc, char^^ argv)` เพราะยังไม่มี pointer ซ้อน pointer)
- `syscall`, `argc`, `arg` เป็นชื่อสงวนของ built-in (อย่านิยามฟังก์ชันชื่อซ้ำ)

---

## 37. `import std`, `using`, ไฟล์ (File) และ array ที่แนบความยาว — รายละเอียดที่ spec ยังไม่ระบุ (AI เสนอ ตามที่ผู้ใช้สั่งให้เริ่มทำข้อ 27 — รอผู้ใช้ยืนยัน/แก้, 2026-10-07)

> ที่ spec ระบุไว้แล้ว (ข้อ 1, 27) ใช้ตามนั้นทุกอย่าง: `import std`, `using std::fs`, `File::open(path, FileMode::Read)`, `read(f, buf)`, `write(f, buf)`, `close(f)`, `read_line(f, line)`, handle เป็น `i32`, ผิดพลาดคืนค่าติดลบ, `FileMode { Read, Write, Append, ReadWrite }`. หัวข้อนี้บันทึกเฉพาะ **ส่วนที่ผมต้องเลือกเองเพื่อให้ทำงานได้** — ผู้ใช้แก้ได้ทั้งหมด

**1. รูปแบบบรรทัด (ตาม spec): `import` และ `using` ไม่ต้องมี `;`** (`using enum X;` ที่ spec เขียนมี `;` ก็ใช้ได้) ทั้งสองแบบจบด้วย `;` หรือขึ้นบรรทัดใหม่ก็ได้

**2. `import std`:** ตัว `std` เขียนด้วย J2K เอง (ฝังในคอมไพเลอร์) และถูกแทรกไว้หน้าไฟล์ของผู้ใช้เมื่อมีบรรทัด `import std` (เลขบรรทัดใน error message ยังนับจากไฟล์ผู้ใช้) ตอนนี้ `std` มีเฉพาะ `File` กับ `FileMode` (`math`, `cpu` ยังไม่มี)

**3. `using`:** `using Struct;` หรือ `using std;` / `using std::fs;` ทำให้เรียก static method ของ struct นั้นได้โดยไม่ต้องมี `Struct::` (สำหรับ `std` = `File`) ฟังก์ชันของผู้ใช้ที่ชื่อซ้ำมีลำดับก่อน

**4. พฤติกรรมของฟังก์ชันไฟล์ (spec ไม่ได้ระบุ ผมเลือกแบบนี้):**
- `File::open(path, mode)`: `Read` = อ่านอย่างเดียว, `Write` = สร้างใหม่/ตัดไฟล์เดิมทิ้ง, `Append` = ต่อท้าย, `ReadWrite` = อ่านและเขียน; คืน `i32` (≥ 0 = handle, < 0 = -errno)
- `read(f, buf)`: อ่านได้มากสุด `ความยาว buf - 1` ไบต์ แล้วใส่ `0` ท้ายข้อความ; คืนจำนวนไบต์ที่อ่าน (0 = จบไฟล์, < 0 = -errno)
- `write(f, buf)`: เขียนข้อความใน `buf` จนถึง `0` (หรือจนสุดความยาว); คืนจำนวนไบต์ที่เขียน
- `read_line(f, line)`: อ่านจนเจอ `\n` หรือเต็ม (`ความยาว - 1`), ไม่เก็บ `\n`, ใส่ `0` ท้าย; คืนความยาว (-1 = จบไฟล์และไม่ได้อ่านอะไร)
- `close(f)`: คืน 0 หรือ -errno

**5. array ที่แนบความยาว (ข้อ 5 / 27: "compiler แนบความยาวตอนส่งเข้าฟังก์ชัน"):** spec ไม่ได้บอกว่าฝั่งรับเขียนยังไง ผมเสนอ: พารามิเตอร์ตัวสุดท้ายประกาศเป็น `T name[]` — ผู้เรียกส่ง array (ชื่อ array 1 มิติ หรือ string literal) แล้ว compiler ส่ง "ที่อยู่" และ "จำนวน element" ไปให้เอง; ในฟังก์ชัน `name` ใช้เหมือน `T^` (`name[i]`) และความยาวอ่านได้จากตัวแปรที่ compiler สร้างให้ชื่อ `name__len` (เช่น `buf__len`) — ชื่อ `name__len` เป็นของชั่วคราว ถ้ามี syntax ที่ดีกว่า (เช่น `buf.len`) ให้ผู้ใช้เลือก; ข้อจำกัด: ต้องเป็นพารามิเตอร์ตัวสุดท้ายเท่านั้น

---

## 38. ข้อตัดสินใจจากผู้ใช้ (2026-10-07 ตอนเช้า — ตอบรายการคำถามใน open-questions.md ข้อ A)

- **`@a[i]` และ `@s.field` ใช้ได้** (address-of ของ element/field) — ผู้ใช้ตอบ "ถือว่าไม่เป็นไร" = คงไว้
- **ความยาว array ฝั่งรับ = `name.len`** (แทนตัวแปรลับชั่วคราว `name__len` ในข้อ 37 ข้อ 5) — *ทำใน jcmp แล้ว: `a.len` ใช้ได้กับ array (ทุกมิติ = มิติแรก), array ใน struct, และพารามิเตอร์ `T name[]`; ชื่อเดิม `name__len` ยังใช้ได้ชั่วคราว*
- **`syscall` / `argc()` / `arg(i)` ซ่อนไว้ใต้ std** ไม่เปิดเป็นทางการ (ต่อจากข้อ 36)
- **`true` / `false` เป็นชนิด `bool` จริง ใช้กับ `int` ไม่ได้** (`int a = true;` = error) ตามข้อ 2a — ทำใน jcmp แล้ว (asm compiler รุ่น seed ยังหลวม)
- **`int` เป็น keyword ของจำนวนเต็ม 64 บิต** (ไม่ใช้ `i64` / `i`) — ยืนยันซ้ำ; ตัวอย่างใน spec เก่าที่เขียน `i64`/`i` ให้อ่านเป็น `int`
- **local ห้ามชื่อซ้ำ global** (ข้อ 28) — ทำใน jcmp แล้ว (error: `a local variable hides a global of the same name`)
- **ระบบ warning** (switch ไม่ครบ, struct > 64 ไบต์, Mutex lock/unlock) — ให้ *วางแผน* ก่อน (ดู open-questions.md)
- **`std` — ทำฐานก่อน** (ขอบเขตยังไม่ล็อก — ดูแผนใน open-questions.md)
- **เลขฐาน 16/2 (`0xFF`, `0b1010`) คงไว้** และ **กฎ `cout << ตัวเลข;` ตัวเดียวขึ้นบรรทัดใหม่เอง คงไว้** (ผู้ใช้ตอบข้อ 4: "กำหนดกฎไว้ก็ดี") — ตีความโดยผม: ถ้าตั้งใจให้ต่างจากนี้บอกได้
- **struct layout แบบชิดตามขนาด (natural alignment) คงไว้** (ผู้ใช้: "7 ก็ด้วย" ตามหลัก "ชิด CPU")
- **`for i in a..b` ขอบบนคำนวณครั้งเดียว คงไว้** — ถ้าต้องการตรวจใหม่ทุกรอบใช้ `while` หรือ `for` แบบ C
- **ชื่อยาวเกิน 63 ตัวอักษร = error** (ไม่ตัดเงียบ) — ทำใน jcmp แล้ว
- **ชื่อโมดูลใน std: `Sys`, `Mem`** (ผู้ใช้ถามว่าใช้ได้ไหม — ผมเห็นว่าใช้ได้; ชื่ออื่นที่เสนอ: `Str`, `Math`, `File`) · **ข้อความ warning/error เป็นภาษาอังกฤษ** (เพื่อความเป็นทางการ)
- **เลขคณิตทำที่ความกว้างเต็ม (แบบ C):** `i8 + i8` ให้ `int` ตัดค่าเมื่อเก็บลงตัวแปรหรือ cast เท่านั้น (ผู้ใช้ตกลง 2026-10-08 ตามหลักเร็ว/ชิด CPU) — แทนที่ข้อความ "ตัดตามความกว้างของ context" ใน roadmap v1.5
- **float:** `f32`/`f64` เข้มไม่คละกับ int/อีกขนาด (ต้อง cast), `coutf` สำหรับ float, พิมพ์ทศนิยม 6 หลัก (ผู้ใช้ตกลง 2026-10-08); `f8` ยังไม่ทำ (รอคำตอบว่าหมายถึงอะไร)
- **std ที่ทำแล้ว:** `Sys`, `Mem`, `Str`, `File` (และ `void^`) — ดู PROJECT_SUMMARY.md
- **`f8` ไม่ทำ / ตัดออกจากรายการชนิด** (ผู้ใช้สั่งเอาออก 2026-10-08; ลบ `f8` จากข้อ 2 และข้อ 25 แล้ว) · ชนิด float มี `f32`, `f64` เท่านั้น
- **ธงบรรทัดคำสั่ง (ตาม spec ข้อ 1.1 / 8 / 26) ทำใน jcmp แล้ว:** `-o`, `-d` (ยังไม่มีผล), `-st` (warning → error), `-I`; รูปแบบข้อความ `file:line:col: error|warning: ... [-Wname]` + บรรทัดซอร์ส + `^` (ภาษาอังกฤษ)
- **ชื่อฟังก์ชันใน `Math` (ผมเสนอเอง รอยืนยัน):** `abs min max sqrt floor ceil trunc pow` (f64) และ `iabs imin imax ipow` (int) — ไม่มี overload ตามข้อ 9a จึงต้องแยกชื่อ
- **นามสกุลไฟล์ (ผู้ใช้ตัดสิน 2026-10-08, แก้ข้อ 1.1):** `.jk` = โปรแกรมที่มี `main` · **`.j` = ไฟล์ส่วนประกอบ** ที่ถูก `import` (มีฟังก์ชัน/struct/enum/`#define` เต็มได้ แต่ **ห้ามมี `main`** — มี = error) · `import "name"` หา `name.j` ก่อน ถ้าไม่เจอลอง `name.jk` (ช่วงเปลี่ยนผ่าน) · ไฟล์ std ใน `std/` เป็น `.j` · ไฟล์ประกาศอย่างเดียวแบบ `stdlib.h` (แยกคอมไพล์) เก็บไว้ทำเมื่อมีไฟล์ object/linker · ซอร์สของ jcmp เองยังเป็น `.jk` เพราะ seed (Jcmp-v1.s) รู้จักแต่ `.jk` — จะเปลี่ยนเป็น `.j` หลังเก็บไบนารี jcmp เป็นจุดเริ่มต้นแทน seed

## 39. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ตอบคำถามค้างตามที่ผมแนะนำทั้งหมด

> บันทึกก่อนลงมือทำ: ยังไม่มีข้อไหนในหัวข้อนี้ถูกทำใน compiler (ทำเป็นพาร์ทต่อไป ดู plan-parts.md)

1. **dynamic array:** ประกาศ `T[] x = arr(n);` — `arr(n)` = **ความจุ n, ความยาว 0**; มี `x.resize(n)` ทำให้มี n ตัว; ตัวแปรชนิด `T[]` เป็น **อ้างอิง** ไปยังก้อน {len, cap, data} บน heap (`b = a` แชร์ก้อนเดียว; ส่งเข้าฟังก์ชันไม่ copy; `free()` ครั้งเดียวทำให้ทุกตัวที่ชี้ใช้ไม่ได้); เมธอด `push pop len free resize` และ `x[i]` (ตรวจขอบเขตด้วย `-d`); `insert`/`sort` ตามข้อ 5a ยังไม่ทำ
2. **`sizeof(T)` / `sizeof(x)`:** ค่าคงที่ตอนคอมไพล์ ชนิด `int` (ขนาด struct รวม padding ตาม layout ของคอมไพเลอร์)
3. **ชนิดไม่มีเครื่องหมาย `u8 u32 u64`:** แยกจาก `char` (`cout` พิมพ์ `u8` เป็นตัวเลข); `int` ยังเป็น 64 บิตมีเครื่องหมาย; **ผสมกับ signed ต้อง cast** (ตัวเลขลอยๆ ปรับตามชนิดเอง); โหลดแบบ zero-extend, เปรียบเทียบ/หาร/เลื่อนขวาแบบไม่มีเครื่องหมาย, พิมพ์ `u64` ไม่ติดลบ
4. **`cin` / `cinf` เมื่อกรอกผิดหรือจบไฟล์:** `throw "invalid input"` / `throw "end of input"` (จับด้วย `try/catch` ได้; ไม่มีใครจับ = โปรแกรมหยุดพร้อมข้อความ)
5. **function pointer:** ชนิดเขียน `RET(PARAMS)^` เช่น `int(int, int)^ op = add;` ใช้ชื่อฟังก์ชันตรงๆ เป็นค่า เรียกด้วย `op(3, 4)` เปรียบเทียบกับ `null` ได้; ตามด้วย `Thread`/`Mutex` (ข้อ 12) — ต้องย้ายพื้นที่ที่ใช้ร่วมกัน (argument ตัวที่ 9+, stack ของ try/catch) ไปเก็บต่อ thread ก่อน
6. **ปล่อยหน่วยความจำอัตโนมัติ (ผู้ใช้ตกลง 2026-10-09, ตามข้อ 8.1 ใน roadmap):**
   - ตัวแปร local ที่ประกาศจาก `alloc(...)` / `arr(...)` ตรงๆ เป็น **เจ้าของ** ก้อนนั้น; คอมไพเลอร์ใส่ `free` ให้ทุกทางออกจากบล็อก (จบบล็อก, `return`, `break`, `continue`, `throw` ที่ข้ามบล็อก)
   - **ยืม** (ค่าเริ่มต้น): ส่งเข้าฟังก์ชันตรงๆ ไม่ย้ายสิทธิ์ · **ย้าย**: `return p;`, ยัดเข้า field/global/element/ตัวแปรอื่น หรือเขียน `move(p)` เมื่อส่งเข้าฟังก์ชันที่จะเก็บไว้ — ย้ายแล้วตัวแปรเดิมเป็น `null` (จึง `free` ซ้ำไม่เป็นอะไร)
   - คอมไพเลอร์ **เตือน** (warning) เมื่อ: ใช้ตัวแปรหลังย้ายแล้ว, ผลของ `alloc` ถูกทิ้ง/ไม่มีเจ้าของ (รั่ว) · เป็นค่าเริ่มต้น (ไม่ต้องเปิดธง) · build `-d` รายงานก้อนที่ยังไม่ปล่อยตอนจบโปรแกรม
   - ใช้กับหน่วยความจำเท่านั้น — ไม่มี destructor/RAII ทั่วไป และ `Mutex` ยัง lock/unlock เอง (ข้อ 12a)
7. **ลำดับงานพาร์ทถัดไป:** `sizeof` → unsigned → function pointer → dynamic array + ปล่อยอัตโนมัติ → `cin`/`cinf` → `Thread`/`Mutex`

## 40. ข้อเสนอ (ยังไม่ล็อก — รอผู้ใช้เลือก): generics, `String`, คอลเลกชัน, lambda

> สถานะ: **ร่างทางเลือกเท่านั้น** ผู้ใช้ตอบแล้ว (2026-10-09) ว่า generics "ต้องมี", `String` + คอลเลกชัน "ควรมี", lambda "ถ้ามีก็มี" — แต่ **ยังไม่ได้เลือก syntax** ห้ามทำใน jcmp จนกว่าจะเลือก · ลำดับที่แนะนำ: ก (generics) → ข (String) → ค (List/Map) → ง (lambda)

### ก. Generics (ฟังก์ชันและ struct ที่รับชนิดเป็นพารามิเตอร์)

กลไกที่แนะนำ (ไม่ขึ้นกับ syntax): **monomorphization** — คอมไพเลอร์สร้างสำเนาของฟังก์ชัน/struct ให้ทุกชนิดที่ถูกใช้จริง (เหมือน template ของ C++/generics ของ Rust) ผลคือเร็วเท่าเขียนมือ ไม่มี boxing และเข้ากับหลัก "ชิด CPU"/prune ของฟังก์ชันที่ไม่ได้ใช้; ข้อเสีย: ไบนารีโตตามจำนวนชนิดที่ใช้

Syntax ที่เลือกได้ (วงเล็บมุม `<>` ชนกับ `<` `>` เปรียบเทียบ และ `<<` ของ `cout` จึงต้องระวัง):

| ตัวเลือก | ตัวอย่าง | ข้อดี | ข้อเสีย |
|---|---|---|---|
| ก1 `<T>` (แบบ C++/Rust/Java) | `T max<T>(T a, T b)` · `List<int> xs;` | คนรู้จักมากที่สุด | `List<List<int>>` ชน `>>`; parser ต้องแยก `a < b` กับ `f<T>(…)` |
| ก2 `[T]` | `T max[T](T a, T b)` · `List[int] xs;` | ไม่ชน `<` `>`; ไม่ชน `<<` | ชนกับ array `a[i]` ในนิพจน์ (`xs[3]` ชนิดหรือ index?) |
| ก3 `of` / keyword | `T max of T (T a, T b)` · `List of int xs;` | อ่านง่าย ไม่กำกวม | ยาว; ซ้อนหลายชั้นอ่านยาก |
| ก4 `$T` ที่ใช้ แล้วอนุมาน | `T max($T a, T b)` | สั้น | ไม่ชัดว่ามี generic ที่ไหน |

ข้อจำกัดชนิดที่ใช้ได้ (เช่น `T` ต้องเปรียบเทียบ `<` ได้): แนะนำ **ไม่มี constraint** ในรุ่นแรก — ตรวจตอน monomorphize แล้ว error ปกติ ("`<` ไม่รองรับชนิด Point") ง่ายกว่ามากและพอสำหรับ List/Map

คำถามที่ต้องตอบ: (1) เลือก ก1–ก4 หรืออื่น (2) ให้ **อนุมานชนิด** ตอนเรียก `max(1, 2)` ได้ หรือต้องเขียน `max<int>(1, 2)` เสมอ (แนะนำอนุมานได้) (3) ผูกกับข้อ 9a (ไม่มี overload): generics ไม่ทำให้มี overload — ชื่อเดียวคือฟังก์ชัน generic เดียว

### ข. `String` (ชนิดสตริงจริง)

ตอนนี้มี `char s[]` + literal + `Str` ใน std เท่านั้น ข้อเสนอ: `String` เป็น struct ใน std เก็บ {data, len, cap} บน heap เหมือน `T[]` (ข้อ 39.1 — อ้างอิง; ผูกกับกฎ "เจ้าของ/ยืม/ย้าย" ข้อ 39.6 ให้ปล่อยเองท้ายบล็อก)

- ข1: `String s = "hello";` (literal แปลงให้) · `s.len` `s.push('x')` `s + t` (ต่อ → ได้ String ใหม่) `s == t` `s[i]` `s.slice(a, b)` `s.find(t)` `s.c()` (ส่ง `char^` ให้ syscall/File)
- ข2: ไม่มี operator ใหม่ — ใช้เมธอดล้วน (`s.append(t)`, `s.equals(t)`) ปลอดภัยตรงไปตรงมา แต่เขียนยาว
- ข: **ไบต์ vs ตัวอักษร:** แนะนำรุ่นแรกเป็น **ไบต์ UTF-8** (`len` = ไบต์) เก็บ/พิมพ์ภาษาไทยได้ถูกต้อง; ฟังก์ชันระดับ code point (`s.chars()`) ทำทีหลัง
- ต้องถาม: ข1 หรือ ข2 · `+` ต่อสตริงสร้างก้อนใหม่ซ่อนอยู่ ("ไม่มี magic ซ่อน") ยอมไหม

### ค. คอลเลกชัน (สร้างบน generics ข้อ ก)

- `List<T>` — จริงๆ คือ `T[]` เดิม (ข้อ 39.1) อยู่แล้ว; เสนอเติม `insert remove sort index_of contains` ใน std (ต้องใช้ generics + function pointer/lambda เป็นตัวเปรียบเทียบ)
- `Map<K, V>` (hash table, open addressing) — `m.put(k, v)` `m.get(k)` (คืนค่าอย่างไรเมื่อไม่มี: **throw**, หรือคืนชนิด optional, หรือ `m.has(k)` แยก — ต้องเลือก) `m.remove(k)` `m.len` และการวนด้วย `for k, v in m`
- `Set<T>` — สร้างบน Map ได้
- hash/equals ของ K: แนะนำชนิดพื้นฐาน + `String` มีให้, struct ต้องเขียน `hash`/`equals` เอง (ผูกกับ method ของ struct)

### ง. Lambda / closure

- ง1 **ไม่มี closure** — มีแต่ฟังก์ชันไม่มีชื่อที่ไม่จับตัวแปร: `int(int, int)^ f = (int a, int b) -> int { return a + b; };` (คอมไพล์เป็นฟังก์ชันธรรมดา เร็ว ไม่ต้อง heap)
- ง2 จับตัวแปรได้ (`[x]` จับค่า / `[^x]` จับอ้างอิง): ต้องมี environment บน stack/heap และชนิดของ function pointer ต้องพกตัวแปรที่จับ — ซับซ้อนมาก ผูกกับเจ้าของ/ยืม (lambda ที่ออกจากบล็อกที่ยืมตัวแปรอยู่ = dangling)
- ง3 ยังไม่ทำเลย (ใช้ function pointer + `void^` context แบบ C)

แนะนำ **ง1 ก่อน** (ฟรีเกือบหมด ใช้ได้กับ `sort`/`Thread::create`) แล้วค่อยดู ง2 เมื่อมีโปรแกรมจริงที่ต้องการ

### สรุปคำถามที่รอตอบ

1. generics: ก1/ก2/ก3/ก4 และอนุมานชนิดตอนเรียก (ก ข้อ 2)
2. String: ข1 หรือ ข2 และ `+` ต่อสตริง
3. Map: ค่าเมื่อหาไม่เจอ (throw / `has` แยก / optional)
4. lambda: ง1 / ง2 / ง3

## 41. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ตอบข้อ 40

- **generics ใช้ syntax ก1 `<T>`:** `T max<T>(T a, T b)`, `List<int> xs;` · กลไก monomorphization (สร้างสำเนาต่อชนิดที่ใช้จริง) ตามที่เสนอ
- **String ใช้ ข1:** `String s = "hello";`, `s + t`, `s == t`, `s[i]`, `s.len`, `s.push(c)`, `s.slice(a, b)`, `s.find(t)`, `s.c()` · UTF-8 นับเป็นไบต์
- **Map:** ผู้ใช้ตอบ "โอเค" ตามที่แนะนำ = `m.get(k)` **throw** เมื่อหาไม่เจอ และมี `m.has(k)` ให้ตรวจก่อน
- **lambda:** ผู้ใช้ตอบ "1" = ง1 (ฟังก์ชันไม่มีชื่อที่ไม่จับตัวแปร) — *ตีความจากข้อความสั้น ถ้าไม่ตรงบอกได้* · ยังไม่ทำจนกว่า generics/String เสร็จ
- **ยังไม่ได้ตอบ (ห้ามล็อกเอง):** การอนุมานชนิดตอนเรียก `max(1, 2)` (ผมจะทำแบบเขียน `max<int>(1, 2)` ก่อน แล้วถามอีกครั้ง)

- **สถานะ (2026-10-09): generics ทำใน jcmp แล้ว** — `jcmp/jc_gen.j`: ฟังก์ชัน/struct generic (`T max<T>(T a, T b)`, `struct Box<T>`), หลายพารามิเตอร์ (`Pair<A, B>`), ซ้อนกัน (`Box<Pair<int,int>>`), ชนิดพอยน์เตอร์เป็นอาร์กิวเมนต์ (`swap<int>(@x, @y)`); **ต้องเขียน `<ชนิด>` เสมอ (ยังไม่อนุมาน)** · ข้อจำกัด: generic ต้องเขียนก่อนจุดที่ใช้ครั้งแรก · ชื่อ instance คือ `Name__args` (เช่น `max__int`) · ข้อความ error ของ instance ชี้ไปที่บรรทัดใน template

## 42. ข้อเสนอ (ยังไม่ล็อก — รอผู้ใช้เลือก): ความหมายของ `String` (ต่อจากข้อ 41)

ข้อ 41 เลือกหน้าตา (`String s = "hello"; s + t; s == t; s[i]; s.len; s.push(c); s.slice(a,b); s.find(t); s.c()`) แล้ว แต่ **ความหมายตอนคัดลอก/ชั่วคราว** ยังไม่ได้ตัดสิน และมีผลต่อความปลอดภัยของหน่วยความจำ จึงถามก่อนลงมือ:

1. **`String b = a;` ทำอะไร?**
   - **ก (แนะนำ) คัดลอกข้อมูลใหม่** (value semantics เหมือน `std::string`/Python): `b` เป็นเจ้าของก้อนของตัวเอง, ท้ายบล็อกปล่อยทั้งสอง ปลอดภัยที่สุด; ราคา: copy ทุกครั้ง (หลีกเลี่ยงได้ด้วยการส่งเข้าฟังก์ชันแบบ "ยืม" ซึ่งไม่ copy ตามข้อ 39.6)
   - ข แชร์ก้อนเดียวเหมือน `T[]` (ข้อ 39.1): เร็ว แต่ `b.push('x')` เปลี่ยน `a` ด้วย และ `free` ซ้ำได้
2. **ผลของ `a + b` (ก้อนชั่วคราว) ใครปล่อย?**
   - **ก (แนะนำ) คอมไพเลอร์ปล่อยให้ท้ายคำสั่ง** (statement) ที่สร้างมัน ยกเว้นถูกย้ายเข้าตัวแปร (`String c = a + b;` → `c` เป็นเจ้าของ) · ต้องเพิ่มกลไก "ก้อนชั่วคราว" ในคอมไพเลอร์
   - ข ห้ามใช้ `a + b` เป็นนิพจน์ซ้อน ต้องเขียน `String c = a + b;` เท่านั้น (ง่าย แต่ `cout << a + b` ไม่ได้)
3. **`String s = "hello";`** literal แปลงเป็น String (copy ไป heap) ได้เลย — และ `cout << s` พิมพ์เนื้อหา; `s == "abc"` เทียบกับ literal ได้ตรงๆ — ยืนยันตามนี้?
4. **`s[i]`** ตรวจขอบเขตด้วย `-d` เหมือน `T[]` (ไม่ตรวจใน build ปกติ) — ยืนยัน?

คำแนะนำ: 1ก + 2ก + 3 ตามนี้ + 4 ตามนี้ · ถ้าตอบ "ตามที่แนะนำ" ผมจะบันทึกเป็นข้อตัดสินใจและเริ่มทำ

## 43. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ตอบข้อ 42

- **2:** ผลชั่วคราวของ `a + b` คอมไพเลอร์ปล่อยให้ท้ายคำสั่ง (ถ้าไม่ถูกย้ายเข้าตัวแปร) · **3:** literal แปลงเป็น `String` เองได้, `cout << s` พิมพ์เนื้อหา, `s == "abc"` ได้ · **4:** `s[i]` ตรวจขอบเขตเฉพาะ `-d`
- **1 (`String b = a;` คัดลอกหรือแชร์): ยังไม่ตัดสิน** — ผู้ใช้ถามข้อเสียของ "คัดลอก" (คำตอบอยู่ในแชท: ช้าลงเมื่อส่ง/กำหนดค่าบ่อย ต้องอาศัยการ "ยืม" เพื่อเลี่ยง)

## 44. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ต่อจากข้อ 42–43

- **`String b = a;` = คัดลอกข้อมูลใหม่** (value semantics) — ตอบข้อ 42.1 ครบแล้ว
- **อนุมานชนิดตอนเรียก generic:** ยังไม่ทำ — "วางแผนไว้ค่อยทำ" (ยังเขียน `max<int>(...)` เสมอ) · แผนอยู่ใน open-questions.md ข้อ D.5
- **ตั้งแต่ 0.3.1: การแก้บั๊กออกเป็นเลข patch ต่อเนื่อง (0.3.1, 0.3.2, …) ไม่ข้ามเลข**

- **สถานะ (2026-10-09): `String` ทำใน jcmp แล้ว (ข้อ 41–44):** `String s = "x"; a + b; a == b; s += x; s.len; s[i]; push pop append clear find slice c; cin >> s;` · คัดลอกเมื่อกำหนดค่า · ปล่อยท้ายบล็อก (ตัวแปร) / ท้ายคำสั่ง (ผลชั่วคราว) · ผลชั่วคราวทางขวาของ `&&`/`||` ไม่ได้ · พารามิเตอร์ String เป็นการยืม (กำหนดค่าให้ไม่ได้) · **`+=` กับ String ผมใส่เพิ่มเอง** (ตามกฎ compound assignment ข้อ 19) — ถ้าไม่เอาบอกได้ · field/global ชนิด String ไม่ปล่อยเอง ต้อง `free()` · ยังไม่มี: `String` เป็นอาร์กิวเมนต์ที่เป็น literal ให้ *ฟังก์ชันที่ไม่ใช่พารามิเตอร์ String*, เปรียบเทียบ `<` `>`, อ่านทั้งบรรทัด

## 45. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ต่อจากข้อ 44

- **`cout` / `coutf` / `cin` / `cinf` ต้อง `import std` + `using std`** (ตาม roadmap 8.6) · ช่วงเปลี่ยนผ่าน (0.5.0) เป็น warning `[-Wstd]` ต่อโปรแกรมครั้งเดียว เวอร์ชันหน้าเปลี่ยนเป็น error · `using std` (ทั้งโมดูล) flatten เฉพาะ `Sys Mem Str Math File` · ชื่อซ้ำข้ามโมดูลที่ใช้อยู่ (`write` ใน Sys กับ File) = error "ambiguous" ต้องเขียน `Module::name`
- **ชื่อชนิดทศนิยม: `float` = 32 บิต, `double` = 64 บิต (แบบ C)** แทน `f32` / `f64` · ชื่อเก่ายังใช้ได้พร้อม warning `[-Wdeprecated]` หนึ่งครั้งต่อโปรแกรม · (`f8` ยังตัดออก) · spec ข้อเก่าที่เขียน `f32`/`f64` ให้อ่านเป็น `float`/`double`
- **ลำดับงาน:** ฐานภาษาก่อน (List/Map ด้วย generics, lambda ง1, อนุมานชนิด generic) แล้วค่อย Phase 5.5 ประสิทธิภาพ (ผู้ใช้: "ประสิทธิภาพรอฐานเสร็จก่อน จะได้แก้ ไม่ใช่มารอก่อนฐาน")

## 46. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — คอลเลกชัน (ตอบข้อ 40/45)

- **struct ที่มี method `free(self)`:** คอมไพเลอร์เรียกให้เองตอนจบบล็อกของตัวแปร local (ทุกทางออก: จบบล็อก, `return`, `break`, `continue`) — เป็นข้อยกเว้นของข้อ 39.6 ที่เคยว่า "ไม่มี RAII ทั่วไป" ผู้ใช้อนุมัติแล้ว · เพื่อไม่ให้ปล่อยซ้ำ: struct แบบนี้ **คัดลอกไม่ได้** (กำหนดจากตัวแปรอื่น/ส่งเข้าฟังก์ชันแบบค่า/คืนแบบค่า = error) ใช้พอยน์เตอร์แทน
- **List = `T[]` / `String[]` เดิม** + เมธอด `insert remove sort contains index_of` · **`Map<K,V>`:** `put get has remove len free` (`get` ไม่เจอ = throw) · **`Set<T>`:** `add has remove len free` · key เป็น int/char/String/พอยน์เตอร์ได้
- **วนอ่าน:** มี **ทั้งสองแบบ** — `for i in a..b` (ตัวเลข) และ `for x in list { }` (x เป็นสำเนาของแต่ละสมาชิก; `Map` ใช้ `for k in m.keys()`)

## 47. ข้อเสนอ (ยังไม่ล็อก — รอผู้ใช้เลือก): รูปแบบ `import` และที่ค้นหาไฟล์

ตอนนี้: `import std` / `import cpu` (โมดูลในตัว), `import "name"` (หา `name.j` แล้ว `name.jk` ข้างไฟล์ที่ import แล้วตามด้วยโฟลเดอร์ `-I dir`)

ข้อเสนอ (เหมือนแนวคิด `#include` ของ C):
- **`import "file"`** — ไฟล์ของโปรเจกต์: หาจากโฟลเดอร์ของไฟล์ที่เขียน import ก่อน แล้วตามด้วยโฟลเดอร์ที่ให้ด้วย `-I`
- **`import <name>`** — ไลบรารี: ไม่หาในโฟลเดอร์โปรเจกต์ ค้นตามลำดับ (1) โมดูลในตัว (`std`, `cpu`) (2) โฟลเดอร์ `-I` (3) ตัวแปรสภาพแวดล้อม `J2K_PATH` (คั่นด้วย `:`) (4) `~/.j2k/lib` (5) โฟลเดอร์ `lib/` ข้างตัว `jcmp` ที่ติดตั้ง
- `import std` แบบไม่มีเครื่องหมาย: ยังใช้ได้ช่วงเปลี่ยนผ่าน (เตือน) แล้วค่อยบังคับเป็น `import <std>`

ทางเลือกสำหรับ "หานอกโฟลเดอร์": (ก) `-I dir` อย่างเดียว (ง่ายสุด) (ข) `-I` + `J2K_PATH` + `~/.j2k/lib` (แนะนำ: ตั้งค่าครั้งเดียวใช้ได้ทุกโปรเจกต์) (ค) ไฟล์ตั้งค่าโปรเจกต์ (เช่น `j2k.toml`) — ทำเมื่อมี package manager

## 48. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ตอบข้อ 47 + แผน package manager

- **`import <name>` = ไลบรารี, `import "file"` = ไฟล์ของโปรเจกต์** ตามข้อเสนอข้อ 47 (ผู้ใช้ตอบ "ได้") · ลำดับค้นหาของ `<name>`: `-I` → `J2K_PATH` → `~/.j2k/lib` → `lib/` ข้างตัว `jcmp` · ทำใน jcmp แล้ว (0.7.0)
- **เปลี่ยนชื่อ `std` เป็น `stdlib`:** `import <stdlib>`, `using stdlib`, `using stdlib::math` · ชื่อเก่ายังใช้ได้พร้อม warning · `cpu` คงชื่อเดิม (`import <cpu>`)
- **แผนเพิ่ม (ยังไม่ทำ): ตัวจัดการแพ็กเกจ `jget`** คล้าย pip — ดูรายละเอียดและข้อเสนอใน docs/roadmap.md หัวข้อ "Phase 7"

## 49. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ต่อจากข้อ 48

- **`#import` บังคับมี `#`:** `#import <stdlib>`, `#import "file"` (เหมือน `#define`) · ช่วงเปลี่ยนผ่าน (0.8.0) `import` แบบไม่มี # ใช้ได้พร้อม warning `[-Wimport]` เวอร์ชันหน้าเป็น error
- **`cout` / `cin` รับทุกชนิดรวมทศนิยม — เลิก `coutf` / `cinf`** (ชื่อเก่ายังใช้ได้พร้อม warning) · ข้อ 15 เดิมที่ให้แยก `coutf` ถือว่าถูกแทนที่ · การพิมพ์ทศนิยม 6 หลักคงเดิม
- **`jget`:** คำสั่งติดตั้งคือ `jget install <ชื่อ>` (เช่น `jget install cv2`) · ข้ออื่นของ roadmap Phase 7 (`owner/name`, ดัชนีบน GitHub, ลายเซ็น) **ผู้ใช้ให้รอก่อน**
- **forward use (เรียกฟังก์ชันก่อนประกาศ):** เป็นไปตามข้อ 16 (คอมไพเลอร์สแกนทั้งไฟล์) จึงไม่ต้อง declare และไม่เตือน — ต่างจาก C ที่ต้องประกาศก่อนใช้

## 50. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — lambda ง1

- **lambda แบบไม่จับตัวแปร, เขียนชนิดครบ:** `(int a, int b) -> int { return a + b; }`, `() -> void { ... }` (ผู้ใช้เลือกแบบนี้จากตัวเลือก `(a, b) => a + b` / `fn(a, b) a + b` / `|a, b| a + b`) · ผลเป็น function pointer · ใช้ตัวแปรข้างนอกไม่ได้ (เป็น error "unknown name … a lambda cannot use the variables around it") · ทำใน jcmp แล้ว (0.9.0)
- **เลขเวอร์ชัน:** ห้ามถึง 1.0 จนกว่าจะเต็มประสิทธิภาพ (ดู PLAN.md)

- **แก้ข้อ 50 (2026-10-09):** ผู้ใช้ชี้ว่า roadmap ข้อ 8.23 ตัดสินไว้แล้วว่าการประกาศฟังก์ชันเป็นแบบ C++ **ไม่มี `->`** (ชนิดผลลัพธ์นำหน้า) — lambda จึงเขียนเหมือนฟังก์ชันที่ไม่มีชื่อ: `int(int a, int b) { return a + b; }`, `void() { ... }` · แบบ `(int a, int b) -> int { ... }` ของ 0.9.0 ยังใช้ได้พร้อม warning `[-Wdeprecated]` · (ผมไม่ได้อ่านข้อ 8.23 ก่อนเสนอตัวเลือก — ต่อไปจะเช็ค roadmap/syntax-design ก่อนเสนอ syntax)

## 51. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — อนุมานชนิดตอนเรียก generic (ต่อจากข้อ 41)

- เรียก `largest(3, 9)` โดยไม่เขียน `<T>` ได้ — คอมไพเลอร์ดูชนิดของอาร์กิวเมนต์แล้วหา T · `largest<int>(3, 9)` ยังใช้ได้
- **ตัวเลขลอยๆ:** ไม่มีจุด = `int`, มีจุด = `double`; ตัวเลขลอยๆ ปรับตามตัวแปรข้างๆ (`largest(3, n)` โดย n เป็น `i32` ได้ T = `i32`)
- **ชนิดไม่ตรงกัน** (`largest(1, 2.5)`) = error (ไม่ยกชนิดให้เอง) ตามกฎเข้ม
- **struct generic ไม่อนุมาน:** ใช้ `Box<int> b = {5};` เสมอ (ภาษาไม่มี constructor แบบเรียกชื่อ — ข้อ 9)
- **`T[]` / `T name[]`:** อนุมานจากชนิดสมาชิกของอาร์เรย์ที่ส่งเข้ามา
- **`T^`:** อนุมานจาก `@ตัวแปร`, ตัวแปรที่เป็นพอยน์เตอร์ และสตริง literal (`char`); นิพจน์อื่น = error ให้เขียน `<T>` เอง
- **T ที่ไม่อยู่ในพารามิเตอร์** (`T make<T>()`): เขียน `make<int>()` เสมอ — ถ้าลืมจะ error "cannot work out T"
- ถ้ามีฟังก์ชันธรรมดาชื่อเดียวกัน ฟังก์ชันธรรมดาชนะ

## 52. ข้อตัดสินใจของผู้ใช้ (2026-10-09) — แบบจำลองข้อผิดพลาด (ดู docs/design/01-errors.md)

- **ทางเลือก B:** `Option<T>` / `Result<T,E>` / `?` ใช้ร่วมกับ `try/catch` (ยกเลิกข้อ "ไม่มี Result" ของ roadmap 8.3 เพราะตอนนี้มี generics แล้ว)
- **enum ที่มีข้อมูล แบบ (i):** `enum class Shape { Circle(double r), Rect(double w, double h), Empty };` · สร้างค่า `Shape::Rect(2.0, 3.0)`
- **`switch` แกะค่าแบบ ก:** `Shape::Rect(w, h):` ตั้งชื่อตัวแปรตามลำดับ (เป็นสำเนา), `_` = ไม่สน
- **ตัวต่อ error:** `expr?` ต่อท้ายนิพจน์ (Result → คืน Err ออกจากฟังก์ชันทันที; Option → คืน None)
- **ชนิด error มาตรฐานของ stdlib:** struct `Error { kind, message }` (ตีความจากคำตอบ "ตามเลย")
- **`defer`:** ความหมายแบบ Zig (รันตอนออกบล็อกด้วยค่าตัวแปรขณะนั้น, เรียงย้อนกลับ, ทุกเส้นทางรวม `return`/`break`/`continue`/`throw`) · เขียนได้ทั้ง `defer stmt;` และ `defer { ... }`
- **บั๊กของระบบ** (หารศูนย์, index เกินขอบ, null, ฟังก์ชันจบโดยไม่ return) = **panic ที่จับด้วย `try/catch` ไม่ได้** ตายพร้อมข้อความ (stack trace ตามมาทีหลัง) · ช่วงเปลี่ยนผ่านเตือนก่อน

## 53. ข้อตัดสินใจของผู้ใช้ (2026-10-08) — UTF-8 ของ String

- **เมธอดแยกชื่อ** (ผู้ใช้เลือกจากตัวเลือก; `s.len` / `s[i]` ยังเป็นไบต์ตามเดิม): `s.count()` = จำนวนตัวอักษร (code point) · `s.chars()` = `String[]` ตัวอักษรละหนึ่ง (ใช้กับ `for c in s.chars()`) · `s.char_at(i)` = ตัวอักษรที่ i เป็น `String` (นอกช่วง = panic)
- `s.upper()` / `s.lower()` รู้จัก Latin-1, Latin Extended-A, Greek, Cyrillic (ภาษาไทยไม่มีตัวพิมพ์เล็ก/ใหญ่ จึงไม่เปลี่ยน)

## 54. หลักการออกแบบ "กฎ 3 ตัวตาย" (ผู้ใช้ 2026-10-08)

ทุกตัวเลือกด้านไวยากรณ์/ไลบรารีต้องถูกประเมินด้วยสามข้อ (เพื่อทั้งคนทำภาษาและคนใช้): (1) **แกะแนวทาง** — ดูว่าภาษาอื่นทำอย่างไรและยืมแนวที่พิสูจน์แล้ว (2) **คนเข้าใจง่าย ลดเวลา** (3) **เครื่องเข้าใจดี** — แยกวิเคราะห์ง่าย ไม่กำกวม ไม่มีต้นทุนซ่อน · ผู้ใช้เป็นคนตัดสินใจเลือก

## 55. เวกเตอร์ (ผู้ใช้ 2026-10-08) — เป้าหมายการเขียน

- **ค่าเริ่มต้นใช้วงเล็บปีกกา** ตามการเริ่มต้น struct ที่มีอยู่: `vec pos = {1.0, 2.0, 3.0};` (ผู้ใช้เลือกจาก 3 แบบ; ไม่ใช้ `vec pos = 1.0, 2.0, 3.0;` เพราะชนกับการประกาศหลายตัวแบบ C ในอนาคต)
- **เป้าหมายที่ผู้ใช้เสนอ:** `using vector;` แล้วเขียน `pos += vel * dt;` (เขียนง่ายเพราะคนทำเกมเขียนสูตรเวกเตอร์ทั้งวัน)
- **การนำเข้า (ผู้ใช้สั่ง 2026-10-08):** `#import <math>` ครั้งเดียว แล้วเลือกส่วนที่ใช้ด้วย `using math::vector;` / `using math::matrix;` / `using math;` (ทั้งหมด) — ไม่แยก import ต่อส่วน (ลดจำนวน import) · โหลดเฉพาะส่วนที่ using (ไม่ using = ไม่คอมไพล์เข้า) · `using math::...` เขียนนอกฟังก์ชันเท่านั้น
- **ขั้นตอน (ตามกฎ 3 ตัวตาย, ข้อ 54):** ระดับ 1 = ไลบรารี `Vec2/Vec3/Vec4`, `Mat3/Mat4` เป็นเมธอดธรรมดา (ทำแล้วใน `std/vector.j`, `std/matrix.j`; ตัวอย่าง `Vec3` ยังเป็นชื่อตัวใหญ่ รอผู้ใช้ตัดสิน) · ระดับ 2 = operator `+ - * /` และ `+=` กับเวกเตอร์ · ระดับ 3 = swizzle (`v.xy`)
- **ยังรอผู้ใช้ตัดสิน:** วิธีประกาศ operator (ตัวเลือก A–E ใน chat), ชื่อชนิด (`vec`/`vec3` หรือ `Vec3`) และขนาดของ `vec`, ชนิดสมาชิก (`double`/`float`), swizzle (`xyzw`/`rgba`)

### 55.1 คำตอบของผู้ใช้ (2026-10-08)
- **ชื่อชนิดใช้ `vec` และให้คอมไพเลอร์นับจำนวนค่าใน `{ }`:** `vec pos = {1.0, 2.0, 3.0};` เป็นเวกเตอร์ 3 ช่อง (ชื่อ `Vec2/Vec3/Vec4` ตัวใหญ่ใน 0.9.18–0.9.19 เป็นของชั่วคราว)
- **swizzle ต้องมี และรองรับทั้ง `xyzw` และ `rgba`** (เช่น `pos.xy`, `col.rgb`)
- ผู้ใช้มีโปรเจกต์จริงที่จะทำเมื่อภาษานิ่งแล้ว และอาจให้ดูคร่าวๆ (ใช้เป็นเป้าหมายการออกแบบ — ดู [[long-term-direction]])
- **ยังไม่ได้ตัดสิน:** การเขียนขนาดชัดเจนเมื่อไม่มีค่าให้นับ (พารามิเตอร์/ฟิลด์) · วิธีประกาศ operator (A–E)

### 55.2 ข้อตัดสินใจของผู้ใช้ (2026-10-08, จากตัวเลือกใน chat)
- **ขนาดที่เขียนชัดเจน:** `vec2` `vec3` `vec4` (ต่อเลขท้ายชื่อ แบบ GLSL) ใช้กับพารามิเตอร์/ฟิลด์/ค่าที่คืน · `vec` ไม่มีเลขใช้ได้เมื่อมีค่าให้นับ (`vec pos = {1.0, 2.0, 3.0};`)
- **operator แบบ C (Kotlin):** เมธอดที่มีคำ `operator` นำหน้า เช่น `operator vec3 add(self, vec3 o) {...}` · `a + b` = `a.add(b)`, `-` = `sub`, `*` = `mul`, `/` = `div`, `==` = `eq`, `!=` = ไม่ `eq`, `a += b` = `a = a.add(b)` · เฉพาะ struct · ขอบเขตแบบจำกัด (ไม่สร้างเครื่องหมายใหม่ ไม่ดัดแปลงชนิดในตัว) · `2.0 * v` (สเกลาร์ทางซ้าย) ยังไม่รองรับในรอบแรก

### 55.3 สถานะการทำ
- ✅ 0.9.20: ชื่อ `vec2/3/4`, `mat3/4` ตัวเล็ก · `operator` + `add sub mul div eq` + `+= -= *= /=`
- ✅ 0.9.22: `vec pos = {1.0, 2.0, 3.0};` (นับจำนวนค่า) · swizzle `xyzw`/`rgba` (หลายตัวอักษร = อ่านอย่างเดียว; ตัวเดียวกำหนดค่าได้)
- ⏳ `-v` (unary) · `m * v` (ต้องมีการเลือกเมธอดตามชนิดอาร์กิวเมนต์) · `2.0 * v`

## 56. ลิสต์ค่าของ array และเงื่อนไขไม่มีวงเล็บ (2026-10-08)
- **`T a[N] = {v0, v1, ...};`** (ในฟังก์ชัน: ค่าเป็นนิพจน์ได้; ตัวแปร global: ค่าคงที่เท่านั้น) · `T a[] = {...}` ขนาดนับจากจำนวนค่า · ค่าที่ไม่ใส่เป็น 0 (ภายใน 64 ตัว) · 1 มิติ, ไม่ใช่ struct · สอดคล้องกับ `Point p = {1, 2};` · ข้อเสนอจากคำถามของผู้ใช้ (ความเห็นจาก AI อื่น: ควรสม่ำเสมอกับ struct) — **ผู้ใช้ยืนยันแล้ว (2026-10-08, "1 ยืนยัน")**
- **เงื่อนไขไม่มีวงเล็บ** (`if x { }`): `{` ปิดเงื่อนไขได้เสมอ เพราะนิพจน์ไม่มีรูปแบบที่ต่อด้วย `{` (ลิสต์ค่า `{...}` ใช้ได้เฉพาะหลัง `=` ของการประกาศ) · เขียนไว้ใน LANGUAGE.md

### 55.4 Ampliacion (2026-10-08, ทำเอง ไม่เปลี่ยนรูปแบบที่ผู้ใช้เลือก)
- `-v` เรียกเมธอด `operator ... neg(self)` · `2.0 * v` = `v.mul(2.0)` (คูณสเกลาร์สลับที่ได้; เฉพาะ `*`) · `(a + b).f()` เรียกเมธอดต่อจากนิพจน์ในวงเล็บได้ · ยังไม่ทำ: `m * v` (ต้องเลือกเมธอดตามชนิดอาร์กิวเมนต์)

## 57. ข้อเสนอ (ยังไม่ล็อก — รอผู้ใช้เลือก): เขียน `alloc` ให้สั้น อ่านง่าย และเร็ว (2026-10-09)

ที่มา: ผู้ใช้เสนอ `arr[]` (ใช้บอกว่าเปิดใช้ก้อนนี้) หรือ `alloc[p=32]` และให้ **อ่านง่าย สั้น CPU ทำงานเร็ว** · ยังไม่ชัดว่า `p=32` หมายถึงอะไร (ชื่อตัวแปร + ขนาด? ขนาดเป็นไบต์หรือจำนวนตัว?) — ดูคำถามท้ายข้อ

**ตอนนี้ (ผ่านการตกลงแล้ว §39.1/39.6):** `int^ p = (int^)alloc(32);` — ขนาดเป็นไบต์, ต้อง cast จาก `void^`, ต้องคูณ `sizeof` เอง; `int[] x = arr(n);` — ความจุ n ตัว, มี `len/cap`, ปล่อยอัตโนมัติ

| | ตัวอย่าง | ยืมจาก | อ่านง่าย | เครื่องทำเร็ว |
|---|---|---|---|---|
| ก. คงเดิม | `int^ p = (int^)alloc(n * 8);` | C `malloc` | ยาว มี cast และเลข 8 | ขนาดเป็นตัวแปร: ต้องเรียกฟังก์ชันเสมอ |
| ข. ชนิดนำ + นับเป็นตัว | `int^ p = alloc<int>(n);` | Zig `alloc(T, n)`, C++ `new T[n]`, รูปแบบ `Name<args>` ของ generics (§41/51) | ไม่มี cast ไม่มีเลขไบต์ สั้นกว่า | รู้ขนาดและ alignment ตอนคอมไพล์ → ถ้า n เป็นเลขคงที่ คอมไพเลอร์เลือก size class เองและฝังเส้นทางเร็ว (ดึงจาก free list ไม่กี่คำสั่ง ไม่ต้องเรียกฟังก์ชัน) |
| ค. ชนิดมาจากตัวแปรที่ประกาศ | `int^ p = alloc(n);` (n = จำนวนตัว) | Go `make`, Rust `Vec::with_capacity` ที่อนุมานชนิด | สั้นสุด | เหมือนข แต่ **ชนกับของเดิม** (`alloc(n)` เดิมคือไบต์) ต้องเปลี่ยนความหมาย = breaking |
| ง. รูปแบบวงเล็บเหลี่ยมที่ผู้ใช้เสนอ | `alloc[32] p;` หรือ `int^ p = alloc[32];` | การประกาศ array `T a[10]` (§5) | ดูเป็นพวกเดียวกับ array: `[ ]` = ขนาด | เหมือนข ถ้าขนาดเป็นค่าคงที่ |
| จ. เติมศูนย์ | `alloc0<int>(n)` / `zalloc` | Go `make` (ศูนย์เสมอ), `calloc` | ปลอดภัยกว่า (ไม่มี garbage) | ราคา: เติมศูนย์ทุกไบต์ (ทางเลือก: ก้อนใหม่จาก `mmap` เป็นศูนย์อยู่แล้ว) |

หมายเหตุ: ข, ค, ง, จ ไม่เปลี่ยนกฎเจ้าของ/ยืม/ย้าย (§39.6): ตัวแปร local ที่ประกาศจากมันยังเป็นเจ้าของและถูก `free` ให้ · `T[] x = arr(n)` ยังเป็นรูปแบบของ dynamic array (มี `len/cap`) ส่วน `alloc…` เป็นก้อนดิบ

**ข้อเสนอของผม (ไม่ล็อก):** ข `alloc<T>(n)` (+ จ `alloc0<T>(n)`) เพราะไม่ชนของเดิม ใช้รูปแบบ `<T>` ที่ตกลงไว้แล้ว เขียนสั้น ไม่มี cast และให้คอมไพเลอร์ทำเส้นทางเร็วได้ · `alloc(bytes)` เดิมคงไว้เป็นรูปแบบระดับต่ำ

**คำถามให้ผู้ใช้:** (1) `alloc[p=32]` หมายถึงประกาศชื่อ `p` พร้อมขนาด 32 ใช่ไหม และ 32 คือไบต์หรือจำนวนตัว? (2) `arr[]` ที่ "บอกว่าเปิดใช้" ต้องการให้แทน `arr(n)` เดิม หรือเป็นเครื่องหมายเพิ่ม? (3) เอา ข, ง หรือแบบอื่น? (4) ก้อนที่ได้ควรเป็นศูนย์เสมอ (ปลอดภัย แพงกว่าเล็กน้อย) หรือ garbage แบบ C (§5)?

### 57.1 คำตอบของผู้ใช้ (2026-10-09) และที่ผมตีความ — ยังไม่ล็อก

- ผู้ใช้: `alloc[p=32]` = ประกาศ `p` พร้อมขนาด **ใช่** · `arr[n]` (แทน `arr(n)` ในรูป `[ ]`) · ปิดด้วย `free[p]` (คืนทั้งก้อน) **หรือ** `free[p=16]`
- ที่ยังไม่ชัด (ถามผู้ใช้): (ก) **ชนิดของ `p`** อยู่ที่ไหน (`alloc[p=32]` ไม่มีชนิด) (ข) 32 คือไบต์หรือจำนวนตัว (ค) `free[p=16]` หมายถึงอะไร: **ค1** ปล่อยก้อน `p` โดยบอกขนาด 16 (เหมือน sized delete ของ C++ / `free` ของ Zig ที่รู้ความยาว: ใช้ตรวจใน `-d` ว่าขนาดตรงกับตอนจอง และเครื่องไม่ต้องอ่านหัวก้อน = เร็วกว่า) · **ค2** หดก้อนให้เหลือ 16 (คืนส่วนที่เกิน; ตัวแปรยังใช้ต่อ) · **ค3** ปล่อยท้ายก้อน 16 ไบต์
- ข้อเสนอของผม (ไม่ล็อก): ชนิดอยู่ซ้ายเหมือนตัวแปรทั่วไป (§3 แบบ C): `int^ p = alloc[4];` และ `int[] x = arr[n];` — ไม่ต้องมีไวยากรณ์การประกาศแบบใหม่ · `free[p]` = ปล่อยทั้งก้อน แล้ว `p` เป็น `null` (เหมือน `free(p)` ตอนนี้) · `free[p=16]` ใช้ความหมาย **ค1** · รูปแบบ `( )` เดิมใช้ได้ต่อ (`alloc(n)`, `free(p)`, `arr(n)`) เพื่อไม่ทำให้โปรแกรมเก่าพัง
- ข้อควรระวังเรื่องการแยกวิเคราะห์: `alloc[` / `free[` / `arr[` ต้องเป็นคำสงวนในตำแหน่งนั้น (ตอนนี้ `alloc` เป็นชื่อฟังก์ชันทั่วไป และ `x[i]` คือการเข้าถึง array) — ทำได้ถ้า `alloc`, `free`, `arr` ที่ตามด้วย `[` ถูกตีเป็นรูปแบบนี้เสมอ (ห้ามมีตัวแปรชื่อ `alloc`/`free`/`arr` ที่เป็น array)

### 57.2 ผู้ใช้ถามต่อ (2026-10-09) — ข้อเสนอของผม ยังไม่ล็อก

1. **ที่วางชนิดของตัวแปร (อีกทางนอกจากชนิดอยู่ซ้าย):** (ก) ซ้าย `int^ p = alloc[4];` (แนะนำ: ตรงกับ §3 แบบ C) · (ข) ในวงเล็บ `alloc[int^ p = 4];` · (ค) ชนิดตามหลัง `alloc[p: int = 4];` (แบบ Rust/Zig — ขัดกับ §3) · (ง) แบบ generics `alloc<int>[p = 4]`
2. **ก้อนใหญ่ที่แบ่งให้หลายที่ใช้ แล้วแต่ละที่คืนส่วนของตัวเองได้ ส่วนที่เหลือยังใช้ต่อ:** มี 3 ความหมายที่ต่างกัน — **P1 สระ/Arena** (จองก้อนใหญ่ครั้งเดียวที่ global; แต่ละที่ขอชิ้นเล็กจากสระ `pool.alloc[4]`, คืนชิ้นของตัวเองด้วย `free[a]` ชิ้นอื่นไม่กระทบ, ปล่อยสระทั้งก้อนทีเดียวตอนจบ) · **P2 แบ่งก้อน (split)** (`p` ถูกแบ่งเป็นสองเจ้าของ; ต้องเขียนหัวก้อนในตำแหน่งกลาง = เสีย 16 ไบต์ต่อชิ้น) · **P3 หดก้อน** (`free[p=16]` คืนส่วนท้าย, `p` เหลือส่วนต้น)
3. **ศูนย์หรือ garbage:** ศูนย์เสมอ = ปลอดภัย แต่เติมศูนย์ทุกไบต์; garbage = เร็วสุด แบบ C (§5 ตกลงไว้แล้วสำหรับ array) — ข้อเสนอ: `alloc[..]` garbage, `arr[..]` ศูนย์ (มี `len`), และรูปศูนย์แยก `alloc0[..]`
4. **dynamic:** `alloc[n]` ที่ n เป็นตัวแปรใช้ได้อยู่แล้ว (ขนาดตอนรัน) · โตอัตโนมัติ = `arr` (`push` เพิ่มความจุเป็นสองเท่า) · ก้อนดิบโตเอง: เสนอ `grow[p=64]` (ขนาดใหม่; ย้ายและคัดลอกถ้าจำเป็น; ก้อนเก่าถูกปล่อย; `p` ชี้ก้อนใหม่)

### 57.3 ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ตอบข้อ 57.2

1. **ชนิดอยู่ในวงเล็บเหลี่ยม (ตัวเลือก ข):** `alloc[int^ p = 32];` ประกาศ `p` พร้อมขนาดในคราวเดียว (ปิดด้วย `free[p];`)
2. **กรณีสระที่ใช้ร่วมกัน (ผู้ใช้บรรยาย):** ก้อนใหญ่ถูกเปิดให้ใช้ (เช่น 32) จาก `import mem` ด้วย `alloc[int^ a = 32];` แล้วแต่ละที่ **เอาชิ้นจาก `a`** (ตัวอย่างที่ผู้ใช้เขียน: `int^ p = a[12];` = เอา 12 ตัวจาก `a` ไปไว้ที่ `p`) ตอนคืนใช้ `free[...]` — **ความหมายเป็นแบบสระ (P1)** · ยังไม่ชัด: ดู 57.4
3. **`alloc[..]` = garbage, `arr[..]` = ศูนย์, `alloc0[..]` = ศูนย์:** ผู้ใช้ตอบ "ได้"
4. **`grow[p=64]`** (ขนาดใหม่ของก้อนดิบ): ผู้ใช้ตอบ "ได้"

### 57.4 ยังไม่ล็อก — รอผู้ใช้ยืนยัน (ผมเสนอ)

`a[12]` มีความหมายอยู่แล้วว่า **สมาชิกตัวที่ 12 ของ `a`** (§5/§35) ถ้า `a[12]` แปลว่า "เอาชิ้นขนาด 12" ด้วย ทั้งผู้อ่านและคอมไพเลอร์จะแยกไม่ออก (ต้องรู้ว่า `a` เป็นสระ) · ทางเลือกสำหรับ "เอาชิ้นจากสระ":
- ก. `int^ p = a.take[12];` (เมธอดของสระ ชัดเจน อ่านออกทันที)
- ข. `alloc[int^ p = a[12]];` (ใช้รูป `alloc[...]` เดียวกัน โดยแหล่งคือสระ `a` — `alloc` ที่มีแหล่งในวงเล็บ ไม่ชนกับการ index)
- ค. `int^ p = a[0..12];` (ช่วง/slice แบบ Go/Python: ไม่ชนกับ index แต่หมายถึงมุมมอง ไม่ใช่การโอนสิทธิ์)
- คืนชิ้น: `free[p];` (คืนให้สระที่ให้มา) · คืนทั้งสระ: `free[a];`

### 57.5 ผู้ใช้เลือก ข (ใช้รูป `alloc[...]`) และเสนอเครื่องหมายโอน `>>` (2026-10-09) — ยังไม่ล็อก

- ผู้ใช้เขียน: `alloc[int^ a >> a[12]]` ("ย้ายจาก a มาไว้แบบนี้") — ชื่อ `a` ซ้ำสองที่ ผมอ่านว่า `alloc[int^ p >> a[12]]` (ประกาศ `p` แล้วโอน 12 ตัวจากสระ `a`) แต่ **ทิศทางของ `>>` ยังไม่ชัด** (ดู 57.6)
- ข้อสังเกตของผม: เครื่องหมายโอนที่ชัดเจนช่วยได้จริง เพราะ `alloc[int^ a = 32]` สร้าง `int^` ธรรมดา — คอมไพเลอร์แยกไม่ออกว่า `a` เป็น "สระ" ถ้าเขียน `alloc[int^ p = a[12]]` (กำกวมกับ index); ถ้ามีเครื่องหมายโอน (`>>`, `<<`, หรือคำ `from`) แหล่งจึงชัดทั้งคนและเครื่อง และตรงกับเรื่อง "ย้ายสิทธิ์" ของ §39.6

### 57.6 ทางเลือกทิศทาง (ผมเสนอ)
| แบบ | ตัวอย่าง | อ่านว่า | ยืมจาก |
|---|---|---|---|
| 1 | `alloc[int^ p << a[12]];` | p รับมาจาก a (ลูกศรชี้เข้าหา p) | `cout << x` ของ C++ ที่ลูกศรชี้ไปปลายทาง |
| 2 | `alloc[a[12] >> int^ p];` | เอา 12 จาก a ไปไว้ที่ p (ลูกศรชี้ไปปลายทาง) | `cin >> x`, shell `>` |
| 3 | `alloc[int^ p >> a[12]];` (ตามที่ผู้ใช้เขียน) | ลูกศรชี้ออกจาก p ทั้งที่ข้อมูลไหลเข้า p — **ทิศสวนกับที่ข้อมูลไหล** | — |
| 4 | `alloc[int^ p from a[12]];` | ภาษาอังกฤษ | SQL `FROM` |
- ข้อควรระวัง: `<<`/`>>` เป็นตัวดำเนินการเลื่อนบิตและสตรีม `cout <<` อยู่แล้ว — ในวงเล็บ `alloc[...]` ไม่ชนกัน แต่ผู้อ่านต้องรู้บริบท

### 57.7 ข้อตัดสินใจของผู้ใช้ (2026-10-09) — ทิศของเครื่องหมายโอน

ผู้ใช้เลือก **แบบ 2:** `alloc[a[12] >> int^ p];` อ่านว่า "เอา 12 ตัวจากสระ `a` ไปไว้ที่ `p`" (ลูกศรชี้ไปปลายทาง) · ผลของข้อ 57.3 – 57.7 รวมกัน:
```
alloc[int^ a = 32];          // จอง 32 ตัว (garbage)           free[a];  // คืนทั้งก้อน
alloc0[int^ z = 32];         // จอง 32 ตัว เป็นศูนย์
int[] x = arr[n];            // dynamic array ความจุ n เป็นศูนย์ มี len
grow[a = 64];                // ก้อนดิบโตเป็น 64 ตัว (ย้าย/คัดลอกถ้าจำเป็น)
alloc[a[12] >> int^ p];      // เอา 12 ตัวจากสระ a ไปไว้ที่ p
```
รูป `( )` เดิม (`alloc(n)`, `free(p)`, `arr(n)`) ใช้ได้ต่อ

### 57.8 ทำใน jcmp แล้ว (0.9.63) — ตามข้อ 57.3 – 57.7 (สิ่งที่ผมเลือกเองตอนทำ ผู้ใช้แก้ได้)

- รูปที่ใช้ได้: `alloc[int^ p = n]` · `alloc0[int^ p = n]` · `alloc[a[n] >> int^ p]` · `free[p]` · `free[p = n]` · `grow[p = n]` · `arr[n]` — n คือ **จำนวนตัว** (คอมไพเลอร์คูณขนาดชนิดเอง) · ตัวแปรที่ประกาศด้วย `alloc[..]` เป็นเจ้าของ (ปล่อยอัตโนมัติ) เหมือน `alloc(...)` เดิม · รูป `( )` เดิมใช้ได้ต่อ
- ถ้ามีตัวแปรชื่อ `alloc`/`alloc0`/`free`/`grow`/`arr` อยู่ `[` หลังมันเป็น index ตามปกติ
- **สระ:** ก้อนที่ได้จาก `alloc[..]` เป็นสระได้ ชิ้นที่เอา (`alloc[a[n] >> int^ p]`) มีหัวชิ้น 16 ไบต์ของตัวเอง · `free[p]` ของชิ้นคืนเฉพาะชิ้นนั้น (ชิ้นที่เอาล่าสุดคืนที่ให้สระจริง ชิ้นกลางเป็นที่ว่างจนกว่าจะคืนสระ) · `free[a]` ปล่อยทั้งสระ · ถ้าสระไม่พอ ผลเป็น `null`
- `free[p = n]`: ตรวจเฉพาะ build `-d` ว่าก้อนจุ n ตัวได้ · `grow[p = n]`: ก้อนใหม่ + คัดลอก + ปล่อยก้อนเก่า (ถ้าไม่มีหน่วยความจำ `p` คงเดิม)

## 58. ข้อเสนอ (ยังไม่ล็อก — รอผู้ใช้เลือก): ให้ภาษารู้จัก register (2026-10-09)

ที่มา: ผู้ใช้ "อยากให้ภาษารู้จัก register ด้วย" — ยังไม่ชัดว่าหมายถึงแบบไหน จึงเสนอทางเลือกที่ต่างกัน (เลือกได้หลายข้อ)

| | ตัวอย่าง (เป็นแค่ตัวอย่าง ไม่ใช่ syntax ที่เลือก) | ใช้ทำอะไร | ยืมจาก | ข้อดี | ข้อเสีย |
|---|---|---|---|---|---|
| ก. คำใบ้ `register` | `register int i = 0;` | บอกคอมไพเลอร์ว่าตัวนี้ร้อน ให้อยู่ใน register เสมอ | C | สั้น คนรู้จัก | คอมไพเลอร์สมัยใหม่จัดเองดีกว่าคน; ถ้าทำเป็น "บังคับ" ต้องมี error เมื่อทำไม่ได้ และห้ามเอาที่อยู่ (`@i`) |
| ข. ผูกกับ register ตัวเจาะจง | `int x @ x19;` | เขียน driver/OS ที่ต้องรู้ว่าค่าอยู่ที่ไหน | GCC `asm("x19")`, Zig | คุมได้ละเอียด | ผูกกับ ARM64 (ไม่พกพา) |
| ค. assembly แทรก | `asm { add x0, x0, #1 }` + บอกว่าอ่าน/เขียน register ไหน | kernel/bootloader/คำสั่งพิเศษ | C, Rust `asm!`, Zig | จำเป็นสำหรับ OS | ผูกกับเครื่อง; ต้องมีกฎกันชนกับ register ที่คอมไพเลอร์ใช้ |
| ง. register ของระบบ | `Sys::read(TTBR0)` / `write(...)` | การเขียน OS (ตารางหน้า, interrupt) | Rust cortex-m | ปลอดภัยกว่า asm ดิบ | ต้องมีรายการ register ต่อเครื่อง |
| จ. ชนิดที่อยู่ใน SIMD register | `vec3`/`vec4`/`f32x4` ให้อยู่ใน q-register และใช้ NEON | เกม/กราฟิก/คณิตศาสตร์ (ต่อจาก §55) | GLSL, Rust `std::simd`, Zig `@Vector` | เร็วจริงกับ `vec` ที่คุณออกแบบไว้ | ต้องมี IR และ SSA ก่อนจึงจะทำดี |
| ฉ. รายงาน/คำใบ้ผลลัพธ์ | `jcmp -regs` บอกว่าตัวแปรไหนอยู่ register ไหน, ตัวไหนล้นลง stack | ปรับความเร็ว | — | ไม่เปลี่ยนภาษา | ไม่ใช่ฟีเจอร์ภาษา |

### 58.1 ผู้ใช้ตอบ (2026-10-09): "เช่น asm จะมี x0–x31 เราอยากให้ j2k เข้าถึงได้" — ข้อเสนอ ยังไม่ล็อก

ความหมายที่ผมเข้าใจ: โค้ด J2K อ่าน/เขียน register ของเครื่อง `x0`–`x31` ได้เหมือนภาษา assembly · ปัญหาที่ต้องตอบก่อน: คอมไพเลอร์ใช้ register เหล่านี้เองอยู่แล้ว (`x0`–`x17` ชั่วคราว, `x19`–`x25`/`d8`–`d15` เก็บตัวแปร, `x27` บล็อกเธรด, `x28` ที่อยู่ global, `x29` frame, `x30` ตัวกลับ, `sp`) ถ้าให้อ่านเขียนได้ตรง ๆ ทุกที่ ค่าจะถูกคอมไพเลอร์ทำลายระหว่างบรรทัด

| | ตัวอย่าง (ไม่ใช่ syntax ที่เลือก) | หลักการ | ข้อดี | ข้อเสีย |
|---|---|---|---|---|
| 1. ชื่อ register เป็นตัวแปรพิเศษ | `x0 = 5; int a = x1;` | อ่าน/เขียนได้ทุกที่ | สั้นสุด | ไม่ปลอดภัย: ค่าถูกคอมไพเลอร์ทับระหว่างบรรทัด; ใช้ได้จริงเฉพาะในฟังก์ชัน "เปลือย" (naked) |
| 2. บล็อก asm ที่บอกเข้า/ออก/ที่ถูกทำลาย | `asm { mov x0, #5; svc 0 } in(x8 = n) out(r = x0) clobber(x1)` | ใน `{ }` เขียน assembly; นอกบล็อกบอกว่าอ่านค่าไหน เขียนค่าไหน register ไหนถูกทำลาย | ปลอดภัย: คอมไพเลอร์รู้ว่าอะไรเสี่ยงแล้วเก็บ/คืนให้ | ต้องเรียนไวยากรณ์เพิ่ม; ใช้ได้เฉพาะ ARM64 (ต้องมีชื่อ target เมื่อมีหลายเครื่อง) |
| 3. ฟังก์ชันเปลือย | `naked void start() { asm { ... } }` | ฟังก์ชันที่คอมไพเลอร์ไม่เพิ่มอะไรเลย (ไม่มี prologue/epilogue) | จำเป็นสำหรับ bootloader/ตัวจัดการ interrupt | ผู้เขียนรับผิดชอบทุกอย่าง |
| 4. ผูกตัวแปรกับ register | `int r @ x19;` | ตัวแปรหนึ่งตัวอยู่ใน register นี้ตลอด | คุมได้ละเอียด ใช้กับ 2 ได้ | ชนกับตัวจัดสรร register ต้องกันตัวนั้นออกจากการจัดสรร |
| 5. ฟังก์ชันอ่าน/เขียนในตัว | `Reg::get(0)`, `Reg::set(0, v)` | เป็นฟังก์ชันของ library | ไม่เพิ่มคำสงวน | ปัญหาเดียวกับ 1 ถ้าใช้นอก naked |

ผมเสนอ **2 + 3** (และ 4 เป็นส่วนเสริม): การเข้าถึง register จริงเกิดเฉพาะใน `asm { }` ที่บอก in/out/clobber ชัด และใน `naked` · ฟังก์ชันที่มี asm จะไม่ถูกจัดสรร register อัตโนมัติ (ปลอดภัยกว่า) · ชื่อ register ภายใน: `x0`–`x30`, `sp`, `xzr` (ตรงกับ assembler ในตัวคอมไพเลอร์) และ `mrs/msr` สำหรับ register ของระบบ (เมื่อ assembler รองรับ) · เมื่อมี ARM32/x86_64 ใช้ `asm[arm64] { }` / `asm[x86_64] { }` เลือกตามเครื่อง

### 58.2 ตัวอย่างให้เลือก (2026-10-09) — เขียนเป็น mock-up ยังไม่มีใน compiler และยังไม่ล็อก

สามแบบ: **A** แบบ C/GCC (ข้อความ assembly ในสตริง + `:` สามช่อง) · **B** แบบ Rust (ตั้งชื่อตัวถูกดำเนินการในข้อความ) · **C** แบบที่ผมเสนอ (บล็อก `asm { }` + `in/out/clobber` ตั้งชื่อตัวแปร)

**ตัวอย่าง 1 — ออกจากโปรแกรมด้วย system call** (ใช้: เรียกระบบปฏิบัติการตรง ๆ โดยไม่ผ่าน library)
```
A:  asm volatile("mov x8, 93\n svc 0" : : "r"(code) : "x0", "x8");        // ต้องใส่ code ใน x0 เอง (ผิดง่าย)
B:  asm!("mov x8, 93", "svc 0", in("x0") code);
C:  asm { mov x8, #93;  svc #0 }  in(x0 = code)  clobber(x8)
```
**ตัวอย่าง 2 — นับศูนย์นำหน้า (`clz`)** (ใช้: คำสั่งที่เร็วมากแต่ภาษายังไม่มีตัวดำเนินการนี้ ใช้ในการบีบอัด, ตารางแฮช, หาบิตแรกที่เป็น 1)
```
A:  asm("clz %0, %1" : "=r"(n) : "r"(x));
B:  asm!("clz {0}, {1}", out(reg) n, in(reg) x);
C:  int n;   asm { clz n, x }  in(x)  out(n)          // ใช้ชื่อตัวแปรตรง ๆ คอมไพเลอร์เลือก register ให้
```
**ตัวอย่าง 3 — อ่านตัวนับเวลาของ CPU** (ใช้: วัดความเร็วละเอียดมาก, OS ตั้งเวลา; register ของระบบ `cntvct_el0`)
```
A:  asm volatile("mrs %0, cntvct_el0" : "=r"(t));
B:  asm!("mrs {0}, cntvct_el0", out(reg) t);
C:  int t;   asm { mrs t, cntvct_el0 }  out(t)
```
**ตัวอย่าง 4 — กั้นลำดับหน่วยความจำ** (ใช้: เธรดและ OS ให้การเขียนของ CPU หนึ่งเห็นพร้อมกันกับอีกตัว; ไม่มีค่าเข้า/ออก)
```
A:  asm volatile("dmb ish" ::: "memory");
B:  asm!("dmb ish", options(nostack));
C:  asm { dmb ish }  memory                                // คำว่า memory = คอมไพเลอร์ห้ามสลับลำดับอ่าน/เขียนข้ามจุดนี้
```
**ตัวอย่าง 5 — หมุนบิต (`ror`)** (ใช้: แฮชอย่าง SHA-256, เข้ารหัส — เร็วกว่าใช้ shift สองครั้งแล้ว or)
```
A:  asm("ror %0, %1, #7" : "=r"(y) : "r"(x));
B:  asm!("ror {0}, {1}, #7", out(reg) y, in(reg) x);
C:  asm { ror y, x, #7 }  in(x)  out(y)
```
**ตัวอย่าง 6 — จุดเริ่มของโปรแกรมที่ไม่มีอะไรเตรียมให้ (bootloader / kernel)** (ใช้: ตั้ง stack เอง แล้วเรียก `main`; ฟังก์ชันนี้ไม่มี prologue/epilogue)
```
A:  __attribute__((naked)) void start() { asm volatile("ldr x0, =stack_top\n mov sp, x0\n bl main\n 1: wfe\n b 1b"); }
B:  #[naked] unsafe extern "C" fn start() { naked_asm!("ldr x0, =stack_top", "mov sp, x0", "bl main", "1: wfe", "b 1b"); }
C:  naked void start() { asm { ldr x0, =stack_top;  mov sp, x0;  bl main;  loop: wfe;  b loop } }
```

### 58.3 แกะภาษาอื่นตามกฎ 3 ตัวตาย (ผู้ใช้ 2026-10-09: "ต้องแกะ — อ่านง่าย เข้าใจง่าย สะดวก") — ข้อเสนอ ยังไม่ล็อก

ภาษาที่ดูแล้ว (เขียนงานเดียวกัน: `n = clz(x)`):
| ภาษา | รูปแบบ | อ่านง่าย | สะดวก | หมายเหตุ |
|---|---|---|---|---|
| C/C++ (GCC) | `asm("clz %0, %1" : "=r"(n) : "r"(x));` | ต่ำ (สตริง, `%0`) | ต่ำ (ต้องบอกเข้า/ออกเอง) | ตรวจ syntax ตอนคอมไพล์ไม่ได้ |
| Rust | `asm!("clz {0}, {1}", out(reg) n, in(reg) x);` | กลาง | กลาง | ตั้งชื่อดีกว่า C แต่ยังเป็นสตริง |
| Zig | เหมือน GCC แต่ตั้งชื่อตัวถูกดำเนินการได้ | กลาง | กลาง | — |
| MSVC (x86) | `__asm { clz n, x }` ใช้ชื่อตัวแปรตรง ๆ | สูง | สูง | แต่ไม่รองรับ ARM64/x64 แล้ว |
| **D** | `asm { clz n, x; }` ใช้ชื่อตัวแปรตรง ๆ **คอมไพเลอร์เข้าใจ asm เอง** | สูง | สูง | ไม่ต้องบอก in/out: คอมไพเลอร์ดูคำสั่งว่าตัวไหนเขียน ตัวไหนอ่าน |
| Jai | `#asm { clz n, x; }` ใช้ชื่อตัวแปรตรง ๆ | สูง | สูง | แนวเดียวกับ D |
| Delphi/Pascal | `asm ... end` ใช้ชื่อตัวแปรตรง ๆ | สูง | สูง | — |
| Go | ไฟล์ `.s` แยก (Plan 9 asm) | ต่ำ | ต่ำ | ต้องเขียนแยกไฟล์ |

ข้อสรุป: แบบที่ **อ่านง่ายและสะดวกที่สุด** คือแบบ D/Jai — เขียน assembly ในบล็อก `asm { }` ใช้ **ชื่อตัวแปรของโปรแกรมตรง ๆ** และให้คอมไพเลอร์ **อนุมานเอง** ว่า อ่านอะไร เขียนอะไร register ไหนถูกทำลาย (เพราะ assembler ของเราเองมีตารางว่าแต่ละคำสั่งเขียน/อ่านตัวถูกดำเนินการไหน) — จึงไม่ต้องเขียนรายการ `in/out/clobber` เหมือนข้อเสนอเดิมใน 58.1 (เก็บไว้เป็นทางเลือกเสริมเมื่ออนุมานไม่ได้)

ข้อเสนอ (ยังไม่ล็อก):
```
int n;   asm { clz n, x }                       // n ถูกเขียน (ออก), x ถูกอ่าน (เข้า): อนุมานเอง
asm { mov x8, #93;  svc #0 }                    // เขียน x0 และ x8 → คอมไพเลอร์เก็บค่าของมันเองไว้ก่อน (clobber อนุมานเอง)
asm { dmb ish }                                 // คำสั่งหน่วยความจำ → เป็น "ตัวกั้น" โดยอัตโนมัติ
naked void start() { asm { ldr x0, =stack_top;  mov sp, x0;  bl main;  loop: wfe;  b loop } }
```
- คำสั่งที่เป็นแค่คำนวณใน register (`clz`, `ror`, `add`…) คอมไพเลอร์ถือว่า "บริสุทธิ์" → ย้าย/ลบ/inline ได้; คำสั่งที่แตะหน่วยความจำ/ระบบ/กระโดด (`ldr`, `str`, `svc`, `dmb`, `mrs`, `b`) → ถือเป็นตัวกั้น
- คำสั่งที่ assembler ไม่รู้จัก = ข้อผิดพลาดตอนคอมไพล์ (ตรวจได้ ไม่ใช่สตริง)
- ชื่อตัวแปรที่ซ้ำกับชื่อ register (`x0`…`x30`, `sp`, `d0`…) ใน asm: เป็น error (ให้เปลี่ยนชื่อ)
- สถานะ: assembler ปัจจุบันยังไม่รู้ `clz ror mrs dmb wfe eret isb` ฯลฯ — เพิ่มพร้อมกับฟีเจอร์นี้

### 58.4 ผู้ใช้ (2026-10-09): "ภาษาเราควรมี (คำสั่งอย่าง clz) · ไม่ค่อยอยากให้เรียก assembly · อยากแทนที่ด้วย J2K คุยกับเครื่องตรง ๆ ไม่ผ่านตัวกลาง" — ข้อเสนอ ยังไม่ล็อก

ความหมายที่ผมเข้าใจ: แทนที่จะให้เขียน assembly ในโปรแกรม ให้ **ภาษามีชื่อของตัวเองสำหรับทุกอย่างที่เครื่องทำได้** (คำสั่ง CPU, register ของระบบ, I/O ที่ผูกกับที่อยู่หน่วยความจำ) คอมไพเลอร์รู้ความหมายและแปลงเป็นคำสั่งเครื่องให้เอง (แนวเดียวกับ intrinsics ของ Zig/Rust/LLVM)

ชั้นที่เสนอ:
1. **ฟังก์ชันในตัวสำหรับคำสั่ง CPU** — ชื่อเดียวกันทุกเครื่อง (ARM64/ARM32/x86_64 แปลงเป็นคำสั่งของตัวเอง): เช่น `Cpu::clz(x)`, `Cpu::popcount(x)`, `Cpu::rotl(x, k)`, `Cpu::bswap(x)`, `Cpu::wait()`, `Cpu::barrier()`; คอมไพเลอร์รู้ว่าเป็นการคำนวณบริสุทธิ์จึงพับค่าคงที่/ย้าย/vectorize ได้ (เข้ากับ IR: เพิ่มเป็นคำสั่งของ IR)
2. **register ของระบบเป็นวัตถุที่มีชนิด** — เฉพาะเครื่อง (ชื่อต่างกันตามเครื่อง): เช่น `Sys::cntvct` (อ่าน) · `Sys::ttbr0 = v;` (เขียน) · มีรายการต่อเครื่อง
3. **I/O ที่ผูกกับที่อยู่** — ชนิดตัวชี้แบบ volatile (ห้ามคอมไพเลอร์ตัด/สลับการอ่านเขียน) สำหรับ driver
4. **ฟังก์ชันเปลือย `naked`** + ฟังก์ชันระดับต่ำที่เขียนอะไรที่ไม่ใช่ฟังก์ชันบริสุทธิ์ไม่ได้ เช่น `Cpu::set_sp(v)`, `Cpu::jump(addr)` สำหรับ bootloader
5. **ทางหนีทีไล่ (ซ่อน ไม่โฆษณา):** `asm { }` แบบข้อ 58.3 เก็บไว้ใช้เฉพาะคำสั่งใหม่ที่ภาษายังไม่มีชื่อ และตอนเริ่มต้น OS ที่ต้องการจริง ๆ

ข้อดี: อ่านง่ายที่สุด (ไม่มี assembly), พกพาข้ามเครื่อง, คอมไพเลอร์ปรับแต่งได้เต็มที่, ปลอดภัยกว่า · ข้อเสีย: ต้องตั้งชื่อและทำให้ครบทีละคำสั่ง (งานเยอะ ค่อย ๆ เพิ่มได้), บางอย่างของเครื่องเฉพาะจริง ๆ (เปลี่ยนระดับสิทธิ์, ตารางหน้า) ยังต้องมีทางหนี

### 58.5 ผู้ใช้ตัดสิน (2026-10-09): **ไม่เอา asm ให้ผู้ใช้เขียน — แทนด้วย J2K เอง ให้เร็วกว่าและดีกว่า** (บันทึกตามที่ผู้ใช้สั่ง; รายละเอียดยังไม่ล็อก)

ภาษาอื่นแทน asm อย่างไร (ผมไล่ดูให้):
| ภาษา | วิธี | ตัวอย่างชื่อ (นับศูนย์นำหน้า / นับบิต 1 / หมุนบิต) |
|---|---|---|
| Go | **ไม่มี** inline asm ในภาษา; ใช้ฟังก์ชันของ `math/bits` ที่คอมไพเลอร์แปลงเป็นคำสั่งเดียว (asm มีแต่ในไฟล์ `.s` ของ runtime) | `bits.LeadingZeros64`, `bits.OnesCount64`, `bits.RotateLeft64` |
| C++20 | ไลบรารีมาตรฐาน `<bit>` | `std::countl_zero`, `std::popcount`, `std::rotl` |
| C23 | `<stdbit.h>` | `stdc_leading_zeros`, `stdc_count_ones` |
| Rust | เมธอดของชนิด + `core::arch` | `x.leading_zeros()`, `x.count_ones()`, `x.rotate_left(k)` |
| Zig | ฟังก์ชัน builtin ของภาษา | `@clz`, `@popCount`, `@byteSwap`, `@Vector` |
| Java | JIT รู้จักเมธอดเหล่านี้ | `Long.numberOfLeadingZeros`, `Long.bitCount`, `Long.rotateLeft` |
| Swift | คุณสมบัติของชนิด | `x.leadingZeroBitCount`, `x.nonzeroBitCount` |

เหตุที่เร็วกว่า asm: คอมไพเลอร์ **รู้ความหมาย** → พับค่าคงที่, ย้าย/ลบ/inline, จดจำรูปแบบ (เขียน `(x << k) | (x >> (64 - k))` แล้วคอมไพเลอร์ใช้ `ror` เอง), vectorize, เลือกคำสั่งตามรุ่น CPU (asm เป็นกล่องดำที่ปรับแต่งไม่ได้)

ข้อเสนอของผม (ยังไม่ล็อกชื่อ): (1) ไลบรารีบิต/อะตอมมิก/ลำดับหน่วยความจำ ที่คอมไพเลอร์แปลงตรง (2) **จดจำรูปแบบ** ใน IR (หมุนบิต, นับบิต, สลับไบต์) (3) ชนิด SIMD (`vec` → NEON) (4) register ระบบเป็นวัตถุมีชนิด + ตัวชี้ volatile (5) ฟังก์ชัน `naked` + ชุดฟังก์ชัน `Cpu::` ที่จำกัดและครบสำหรับ OS (`set_sp`, `jump`, `wait`, `eret`, `barrier` …) — รายการคำสั่งที่ OS ใช้มีจำกัด ตั้งชื่อให้ครบได้ (6) ผู้เขียนไลบรารีของ J2K เองมี `__asm` ภายในไว้ใช้เฉพาะเมื่อยังไม่มีชื่อ **ไม่เปิดให้ผู้ใช้ทั่วไปและไม่อยู่ในเอกสาร**

### 58.6 ผู้ใช้ถาม (2026-10-09): ย้ายค่าระหว่าง register ใน J2K เขียนอย่างไร — เสนอ (ยังไม่ล็อก)

ตัวอย่างที่ผู้ใช้เขียน: `int^ x0 = x1;` (ผมอ่านว่า "ประกาศ x0 เป็น register พร้อมชนิดตัวชี้ แล้วใส่ค่าจาก x1")

งานตัวอย่าง: x0 ← x1 · x2 ← x0 + 5 · เขียนค่า x2 ไปที่หน่วยความจำที่ x3 ชี้ · อ่านค่าจาก x4 + 8 ใส่ x5

| | หน้าตา | ข้อดี | ข้อเสีย |
|---|---|---|---|
| R1 ชื่อ register เปล่า ๆ (ใน `naked` เท่านั้น) | `x0 = x1;  x2 = x0 + 5;  (int^)x3^ = x2;  x5 = ((int^)x4)[1];` | สั้นสุด ตรงกับ asm | ชนกับชื่อตัวแปรชื่อ `x1` ที่คนตั้งกัน; ต้อง cast ทุกครั้งที่ใช้เป็นตัวชี้ |
| R2 ชื่อมี namespace | `Reg::x0 = Reg::x1;  Reg::x2 = Reg::x0 + 5;` | ไม่ชนกับตัวแปรปกติ | ยาวขึ้นทุกบรรทัด |
| R3 ประกาศตัวแปรผูกกับ register (แบบที่ผู้ใช้เขียน) | `register int^ p @ x3 = ...;` หรือ `int^ x3 = x2;` (ชื่อ=register) | ระบุชนิดตัวชี้ได้ตั้งแต่ประกาศ → เขียน `p^ = v;` ได้เลย | ถ้า "ชื่อ = register" ต้องห้ามใช้ชื่อ `x0`..`x30` เป็นตัวแปรอื่น; ถ้าใช้ `@ x3` ต้องมีเครื่องหมายผูก |

### 58.7 ทำใน jcmp แล้ว (0.9.67) — ชุดแรก (ผู้ใช้สั่ง "ลงมือเลย"; ชื่อกลุ่มยังเปลี่ยนได้)

`Bit::clz` `Bit::ctz` `Bit::popcount` `Bit::rotl` `Bit::rotr` `Bit::bswap` — ชื่อกลุ่ม `Bit` เป็นค่าตั้งต้นของผม (ผู้ใช้ยังไม่ได้เลือกระหว่าง `Bit::` กับ `Cpu::`) · คอมไพเลอร์แปลงเป็นคำสั่งเดียว (หรือสองคำสั่งสำหรับ `ctz`) ไม่มีการเรียกฟังก์ชัน · ส่วน **รูปแบบการเข้าถึง register `x0`–`x31`** (R1/R2/R3 ใน 58.6) ผู้ใช้ให้ "ค่อยกลับมาจัดการทีหลัง" — ยังไม่ทำ

## 59. SIMD (NEON) — ตัวเลือกให้ผู้ใช้เลือก (ยังไม่ล็อก; เสนอเมื่อ 2026-10-09)

**ที่มา:** วัด `tools/bench/run.sh` แล้ว `loop` ช้ากว่า clang -O2 3.6 เท่า และ `nbody` 2.3 เท่า ส่วน scalar (fib, gcd, matmul, mandel) อยู่ที่ 1.2–1.3 เท่า และ sieve เร็วกว่า · clang ใช้ NEON อัตโนมัติ (4 ตัวพร้อมกัน) ในลูปของ `loop` · เป้า "ไม่ด้อยกว่า C แต่ดีกว่า asm"

| ทาง | อะไร | ข้อดี | ข้อเสีย |
|---|---|---|---|
| 1 | ชนิดเวกเตอร์ชัดเจนในภาษา แปลงเป็น q-register / NEON ตรง ๆ | คาดเดาได้ ไม่ต้องเดา compiler; ไม่ต้อง intrinsic แบบ C; ใช้กับเกม/กราฟิกได้เลย | ต้องเลือก syntax; ผู้เขียนต้องเขียนเอง |
| 2 | vectorize อัตโนมัติ (ลูป scalar → NEON) | โค้ดเดิมเร็วขึ้นเอง | งานใหญ่มาก ต้องมี range analysis, dependence analysis, remainder loop; เสี่ยงผิดพลาด |
| 3 | ไม่ทำ SIMD ตอนนี้ | ไม่มีความเสี่ยง | `loop`/`nbody` ยังช้ากว่า C |

**ตัวเลือก syntax ของทาง 1** (ตามกฎ 3 ตัวตาย: ยืมจากภาษาอื่น / คนอ่านง่าย / เครื่องทำง่าย):

| | แบบ | ตัวอย่าง | ยืมจาก | หมายเหตุ |
|---|---|---|---|---|
| ก | ชนิดมีจำนวนช่องในชื่อ | `f64x2 a = {1.0, 2.0}; f64x2 c = a * b + a;` · `i32x4 s = x + y;` · `double r = c.sum();` | Rust `std::simd`, Zig `@Vector` | ใช้ operator เดิม `+ - * /` ทำทุกช่อง; ตรงกับ `vec2/3/4` ที่มี (จะให้ `vec2` = `f64x2` ได้) |
| ข | ชนิดแบบ generic | `vec<double,2> a;` `vec<int32,4> b;` | C++ `std::simd`, GLSL `vec` | ต้องมี generic (ภาษายังไม่มี) |
| ค | บล็อก "ทำทีละ N" ในลูป | `for i in 0..n step 4 simd { s += a[i..i+4] * b[i..i+4]; }` | OpenMP `simd`, Julia `@simd` | อ่านง่ายที่สุด แต่เป็นทาง 2 ครึ่งทาง ต้องมีการวิเคราะห์ |
| ง | ฟังก์ชันในตัว (intrinsic) | `Simd::add_f64x2(a, b)` | C `arm_neon.h` | ง่ายสุดสำหรับ compiler; อ่านยากที่สุด |

**ข้อเสนอของผม:** ทาง 1 แบบ ก (ชื่อชนิด `f64x2 f64x4 i32x4 i64x2 ...` + operator เดิม + เมธอด `sum() min() max() load() store()`) เพราะ `vec2/3/4` ที่คุณออกแบบไว้ใช้ operator อยู่แล้ว เรียนรู้ง่าย และ NEON ใช้ได้ตรง ๆ · ขั้นตอน: (1) `f64x2`/`i32x4` ใน register q พร้อม `+ - *` และ load/store จาก array (2) `f64x4` = สอง q-register (3) ให้ `vec2` ใช้ `f64x2` ภายใน (4) ค่อยพิจารณา vectorize อัตโนมัติ (ทาง 2) เมื่อมี IR ที่ครบ

## 60. The "super low" level: write the instructions themselves, with no import and no runtime (owner, 2026-10-09; the example is only an example)

Owner's words: for people who work at the very bottom, something like `_main; mov x0 #10` and so on, with no import; "that deep", but the lines are only a supposition. Rule of three below; **nothing is decided**.

Idea: a ladder of levels in ONE language and ONE tool, so that nobody has to leave it:

| level | what you write | runtime / import |
|---|---|---|
| 0 bare | the instructions of the CPU as lines of the language | none: nothing is added, the file is the program |
| 1 low | J2K with registers, `naked`, `Bit::` / `Atomic::` / `Cpu::` groups, `volatile` | none unless named |
| 2 normal | J2K as today (structs, strings, memory, `-d`) | prelude as needed |

### 60.1 The look of level 0 (options)

| | A: a file in bare mode | B: a block inside a function | C: typed calls |
|---|---|---|---|
| example | `_main:` / `mov x0 10` / `svc 0` (the whole file is instructions; first line or the extension says "bare") | `bare { add x0 x0 x1 }` with the variables bound to registers: `bare(a -> x0, b -> x1) -> x0 { add x0 x0 x1 }` | `Cpu::mov(x0, 10)` (an instruction is a call) |
| borrowed from | assemblers (GNU as, NASM, flat assembler: `fasm` needs no setup either) | Rust `asm!`, GCC inline asm, Zig `asm volatile` | Zig builtins, intrinsics of C (`arm_neon.h`) |
| easy for people | the most direct: what you know from assembly, no extra syntax | needed to mix with normal code | every instruction is a name with typed operands: autocomplete, checked |
| easy for machine | simple: lines go to the encoder that the compiler has already (`jc_asm.j`) | the compiler must know which registers the block changes (a `clobbers` list or it reads the block) | needs a table of all instructions (the table of `design/08`) |
| cost | low | medium | high (the table) |

A and B can share one reader (the same lines), so the work is once. C comes from the table of design 08 and can later be the checked form of A / B.

### 60.2 Small things that make level 0 easy (all optional, each can be decided alone)
* commas optional (`mov x0 10` and `mov x0, 10` are the same); `#` before a number optional (`mov x0, #10` is the same as `mov x0, 10`); the instruction name is case insensitive;
* an entry name without declaration (`_main` or `_start`), or none (the first instruction is the entry);
* **errors that explain**: "`add x0, x1, #5000`: the number must be 0 - 4095 (12 bits); use `mov x2, 5000` first, or `add x0, x1, #5000 >> 12, lsl #12`" instead of "parse error";
* names for numbers, strings and data (`MSG: "hello"`, `LEN = 5`), and local labels; the constants and the offsets of structs of level 2 can be used (`mov x0, Point::y_offset`);
* a call between the levels: a bare function can be called from J2K and the other way (the register convention is written in one line at the top of the function);
* `-emit-asm` and a listing with the bytes, so that the result can be read;
* no hidden code: a bare file produces exactly its own bytes (plus the ELF header).

### 60.3 Questions for the owner
1. A (a whole file), B (a block inside a function), or both? (Recommended: both, one reader.)
2. Should commas and `#` be optional (a looser look than an assembler) or exactly as in the manual of the CPU?
3. File mode: first line `#bare`, a file extension (`.jb`?), or an option `jcmp -bare file`?
4. Does a bare file need `_main` / `_start` written, or is the first instruction the entry?
5. How much checking in a bare block: only the encoding (what the CPU can do), or also the conventions (a callee-saved register that is changed and not saved gets a warning)?

## 61. Other ways to work at the bottom without writing assembly lines (owner, 2026-10-09: "other people do not want to write like 60")

Nothing is decided. The ideas can be used together; they serve different people.

| # | idea | example | borrowed from | for whom | cost |
|---|---|---|---|---|---|
| 1 | **Named operations** (intrinsics) | `Bit::clz(x)`, `Simd::add(a, b)`, `Atomic::add(p, 1, Order::acquire)` | C intrinsics, Zig builtins | everybody who needs one instruction | low (started: `Bit::`) |
| 2 | **Hardware described as data** | `device Uart @ 0x0900_0000 { data: u32 @ 0x00; flags: u32 @ 0x18 }` then `Uart.data = 'A';` is one `str`, `if Uart.flags.bit(5) == 0 {}` is a read and a test; fields with bit ranges | Rust `svd2rust`, Ada representation clauses, Zig `packed struct`, C bit fields | embedded, drivers, kernels | medium |
| 3 | **Attributes on normal functions** | `naked`, `interrupt`, `section("boot")`, `align(64)`, `noreturn`, `cold`, `inline(always)` | C / Rust attributes | kernels, boot code | low-medium |
| 4 | **The compiler knows the idioms** | `(x << k) \| (x >> (64 - k))` becomes `ror`; a loop that counts bits becomes `popcnt`; `a * 7` becomes shifts | LLVM, GCC | everybody: they write plain code | medium (each idiom is a pass) |
| 5 | **Hints on loops and data** | `@unroll(4)`, `@simd`, `@prefetch(p + 64)`, `@align(16)`, `@likely` | OpenMP, Julia `@simd`, Rust `#[inline]` | numeric code | medium |
| 6 | **Bit layouts as declarations** | `packet Header { version: u4; length: u12; flags: u16 }` gives read and write code, with the byte order | Erlang bit syntax, Kaitai, P4 | protocols, file formats | medium |
| 7 | **Experts write the bottom once, everybody calls it** | `Mem::copy`, `Str::find`, `Crc::crc32` written with idea 1 or level 0 inside the library; the user sees a function | libc / glibc (assembly inside, C outside) | most users never see assembly | the work is in the library |
| 8 | **Tools that show the bottom** | `jcmp explain f` (the instructions of `f` next to its lines, with the cost), `jcmp inst clz` (what the instruction does, the encoding), a listing with bytes, a debugger with registers | Compiler Explorer, `objdump -S`, `llvm-mca` | learning and tuning, no need to write it | medium |
| 9 | **Registers that look like variables (C-like, one statement = one instruction)** | `x0 = 10;` `x0 += x1;` `x2 = [x3 + 8];` `if x0 == 0 goto done;` | "portable assembly": C--, QBE, PL/360, the options R1 / R2 / R3 of 58.6 | people who want the bottom but dislike mnemonics | medium |
| 10 | **Assembly lines (level 0 of 60)** | `mov x0 10` | assemblers | the small group that wants exactly this | low |

Rule of three (human-easy, machine-easy, borrowed): 1, 3, 4, 7 and 8 score highest for "easy to reach"; 2 and 6 score highest for "easy to use at the bottom" because they describe hardware instead of operating it; 9 and 10 give the deepest control and are for the few. A proposal: **the main road is 1 + 3 + 4 + 7 + 8; 2 and 6 come with the freestanding mode; 9 / 10 stay as the expert level**, and the owner chooses the order.

## 62. More ideas for working at the bottom (owner, 2026-10-09: "propose more"). Nothing decided; numbers continue from 61.

| # | idea | example | borrowed from | for whom | cost |
|---|---|---|---|---|---|
| 11 | **Promises about the machine, checked by the compiler** | `ensure stack <= 256;` `ensure no_branch_on(secret);` `ensure cycles <= 40;` `ensure no_alloc;` | SPARK / Ada, Rust `#[no_panic]`, Jasmin and Vale (crypto), WCET tools | kernels, interrupt handlers, crypto, real time | medium-high (stack and call-depth analysis first: cheap) |
| 12 | **The algorithm and its schedule apart** | `kernel blur(img) = (img[x-1] + img[x] + img[x+1]) / 3;` `schedule blur: vectorize(x, 8), unroll(y, 4), tile(64);` | Halide, TVM, Futhark | numeric and image code | high |
| 13 | **Ask for the shortest instruction sequence** | `jcmp superopt f` searches the shortest and fastest sequence of instructions for a small function and proposes it (or keeps it as a rule) | STOKE, Souper | compiler authors, library experts | high, optional |
| 14 | **Run the instructions anywhere (a built-in emulator)** | `jcmp emulate kernel.bin` runs the ARM64 code on any machine with a trace and a time-travel debugger; the tests of boot code and drivers need no hardware | QEMU, Unicorn, rr | OS and driver work, the owner's phone-only setting | high (but the instruction table of `design/08` is the model) |
| 15 | **Instruction selection as rules (data)** | `rule rotl(x, k) -> ror(x, neg(k));` `rule add(mul(a, b), c) -> madd(a, b, c);` in a file per CPU | Cranelift ISLE, LLVM TableGen | whoever adds a CPU (ARM32, x86_64, RISC-V, a custom extension) | high once, then every target is a table |
| 16 | **Calling conventions and frames as declarations** | `abi Syscall { number: x8; args: x0..x5; result: x0 }` then `Syscall::call(64, 1, buf, n)`; `frame Context { x19..x30; sp }` then `Context::save(@c)` / `Context::restore(@c)` | LLVM `callingconv`, Rust `extern "C"`, Zig `callconv` | OS, context switches, FFI | medium |
| 17 | **Carry, overflow and widths as part of the language** | `u12`, `i5`; `a +% b` (wraps), `a +\| b` (saturates); `r, carry = Int::add_carry(a, b, carry)`; `hi, lo = Int::mul_wide(a, b)` | Zig, Rust, Swift (`&+`), Ada ranges | big numbers, crypto, fixed point, codecs | low-medium (adc / sbc / umulh exist) |
| 18 | **The compiler runs your code at compile time** | `const table = comptime { for i in 0..256 { crc(i) } };` unroll by a loop over `x0..x7`; a lookup table, a state machine or a specialised copy built while compiling | Zig `comptime`, D CTFE, Rust `const fn` | everybody who builds tables by hand today | high |
| 19 | **A simulated device in tests** | `mock Uart { flags = 0x20 }` then run the driver code in a test and check what it wrote | embedded test frameworks | drivers | medium (needs 2) |
| 20 | **A live monitor (peek and poke) for a board or the emulator** | `jcmp monitor` : type `Uart.data = 'A'` or `mem[0x4000_0000..+16]` and see it at once; save what worked as a function | Forth, U-Boot console, GDB | the first hour with a new board; teaching | medium (needs 2 and 14) |
| 21 | **Generate the other languages' view of a device** | `jcmp export Uart --c` gives a C header, `--svd` an SVD file, `--doc` a register table | svd2rust in reverse, CMSIS | teams that mix languages | low (needs 2) |

### Reading the table with the rule of three
* **Easy to reach (the owner's goal 1):** 14, 19, 20 (nobody needs the hardware to start), 18 (no hand-made tables), 17 (no carry tricks).
* **Deep (goal 2):** 11, 15, 16, 17, 12.
* **Easy to use (goal 3):** 11 (a promise is read and checked, not hoped), 16 (the convention is written once), 18, 21.

### Proposed order if the owner likes them
1. **17** (widths, wrap, carry: small and useful at once), then **16** and **11**'s cheap half (`ensure stack`, `ensure no_alloc`).
2. **18** (`comptime`) : it also helps the compiler's own tables.
3. **14** (the emulator) together with **2** (devices): after these two, 19, 20 and 21 are nearly free.
4. **15** with the second target (ARM32): the rules replace the hand-made instruction selector.
5. 12 and 13 only if numeric code asks for them.

## 63. Instructions close to the CPU and control of registers (owner, 2026-10-09: "and the things close to the CPU, or controlling registers?"). Proposal, nothing decided. Builds on 58.6 (R1 / R2 / R3), 60 and 62 (16, 17).

What the compiler does today: it keeps whole numbers in `x19..x25` and doubles in `d8..d15` by itself (register pass) and uses `x0..x17` for the work in between; the program cannot ask for any of it. The instruction groups (`Bit::`) exist; the registers are closed.

### 63.1 What "control" can mean (six kinds; each can be decided alone)

| kind | question it answers | example need |
|---|---|---|
| A. where a value lives | "this variable stays in x19", "never use x27" | a per-CPU pointer in a register, a hot loop |
| B. registers at a call | "the arguments are in x8 and x0..x5, the result in x0 and x1" | system calls, quotient and remainder, a custom convention |
| C. read and write a register | "put this in x0, then read x1" | boot code, context switch, syscall stub |
| D. special registers | `sp`, `lr`, `pc`, flags, system registers (`mrs`/`msr`), vector registers | stack switch, interrupt vectors, SIMD |
| E. instruction and order | "this exact instruction", "do not move this", "barrier" | drivers, locks, cache maintenance |
| F. what the compiler may touch | "this region is kept as written", "this function has no frame" | constant-time code, interrupt entry |

### 63.2 Options for each kind

**A. where a value lives**

| | A1 a hint | A2 pinned | A3 reserved for the whole program |
|---|---|---|---|
| example | `register int n = 0;` | `int n @ x19 = 0;` (compile error if impossible) | `#reserve x27, x28` (the compiler never uses them; you do) |
| from | C `register` | GCC `register int x asm("x19")`, Zig | GCC `-ffixed-reg`, Linux (x18 is the per-CPU pointer) |
| human-easy | the most familiar | clear, the name tells everything | one line at the top |
| machine-easy | trivial (a weight) | the register pass must treat the register as taken for that range | easy (remove the register from the pool) |

**B. registers at a call**

| | B1 a declared convention | B2 at the call | B3 attribute on the function |
|---|---|---|---|
| example | `abi Syscall { number: x8; args: x0..x5; result: x0 }` then `Syscall::call(64, 1, buf, n)` | `call write(x8 = 64, x0 = 1, x1 = buf, x2 = n) -> x0` | `callconv(x0 = a, x1 = b) -> (x0, x1) int divmod(int a, int b)` |
| from | LLVM `callingconv`, Zig `callconv` | assembly + C mix | Rust `extern "C"`, Zig `callconv` |
| good for | system calls, interrupts, the same convention used many times | a single odd call | functions that return two values |
| note | the one I would build first: a table, checked, reusable | | |

**C and D. read and write a register, special registers** (the three forms R1 / R2 / R3 of 58.6, now with the roles added)

| | R1 bare names | R2 `Reg::` | R3 names bound to variables |
|---|---|---|---|
| example | `x0 = x1; x2 = x0 + 5;` | `Reg::x0 = Reg::x1;` | `int^ p @ x3 = q;` |
| problem | a variable named `x1` clashes; only allowed inside `naked` or `register { }` blocks | longer | needs the binding sign |
| roles (same on every CPU) | | `Reg::arg0 .. arg7`, `Reg::ret`, `Reg::sp`, `Reg::lr`, `Reg::pc`, `Reg::zero`, `Reg::flags` | |
| system | `Sys::VBAR_EL1 = handler;` , `v = Sys::SCTLR_EL1;` , `Sys::SCTLR_EL1 \|= 1;` — names, types and access rights from the table of `design/08` | | |
| SIMD | `Vec::v0.lane(1)` or the typed `f64x2` of 59 | | |

Proposal: **R2 with roles** inside `naked` functions and `register { }` blocks (so that normal code can never be broken by a register write), R1 allowed in the same places as a shorter alias if the owner wants it.

**E. instruction and order**

| name | what it does |
|---|---|
| `Mem::barrier(Order::full / acquire / release)` | `dmb` |
| `Cpu::isb()`, `Cpu::dsb()`, `Cpu::wait()`, `Cpu::yield()`, `Cpu::halt()` | `isb`, `dsb`, `wfi`, `yield` |
| `Cache::clean(p)`, `Cache::invalidate(p)`, `Cache::zero(p)` | `dc cvac`, `dc ivac`, `dc zva` |
| `Cpu::inst("name", a, b)` | the last resort: any instruction of the table, operands typed and checked (not text) |
| `@keep` on a statement or a read of a device | the optimiser may not remove or merge it (`volatile` for a whole variable) |

**F. what the compiler may touch**

| form | meaning |
|---|---|
| `naked` function | no prologue, no epilogue, no saves: the body is all there is |
| `leaf` / `noframe` function | no frame when nothing needs the stack (the compiler checks) |
| `@no_reorder { ... }` | the instructions of the block are in this order and none is removed (constant-time code, device sequences) |
| `register { ... }` block | inside it R1 names work and the compiler keeps its hands off the registers that are written; at the end it checks that the callee-saved ones are as they were (or says which are not) |

### 63.3 Real uses written in the options above (pictures)

```
// 1. system call stub (B1 + C)
abi Syscall { number: x8; args: x0..x5; result: x0 }
int write(int fd, char^ buf, int n) { return Syscall::call(64, fd, buf, n); }       // mov x8,64 / svc 0

// 2. context switch (C + D, naked): save the callee-saved registers and the stack pointer of 'from', load those of 'to'
frame Context { x19..x30; sp }
naked void switch_to(Context^ from, Context^ to) {
    Context::save(from);          // stp x19,x20,[x0] ... ; mov x9,sp ; str x9,[x0,#96]
    Context::restore(to);         // ldp ... ; mov sp,x9
    ret;
}

// 3. a per-CPU pointer that lives in x18 for the whole program (A3)
#reserve x18
Cpu^ this_cpu() { return (Cpu^)Reg::x18; }

// 4. an interrupt handler (F + D): the entry saves what the handler may change
interrupt void on_timer() { Timer.ack(); ticks += 1; }                    // the compiler saves and restores, ends with eret

// 5. division with two results (B3)
callconv(x0 = a, x1 = b) -> (x0, x1) int divmod(int a, int b) { return (a / b, a % b); }

// 6. a hot loop with a value kept in a chosen register (A2, rare)
int sum(int^ p, int n) { int acc @ x9 = 0; for i in 0..n { acc += p[i]; } return acc; }
```

### 63.4 Order (proposal; each step is a release and has a test)
1. **`naked` and `leaf` functions** (F): easy, the base for the rest.
2. **`Reg::` read and write inside `naked` / `register { }`** (C), with the roles; a test that is an exact copy of a syscall stub.
3. **`abi` declarations and `Syscall::call`** (B1).
4. **`Cpu::`, `Mem::barrier`, `Cache::`, `Atomic::`** (E) — the names are the usual ones; the table of `design/08` later replaces the hand-written part.
5. **`Sys::` system registers and `volatile` / `device`** (D).
6. **`#reserve` and pinned variables `@ x19`** (A): needs the register pass to know pinned ranges.
7. **`interrupt` functions** (F + D) and `frame` / `Context::save`.
8. **`@no_reorder`** (F), the last one: the optimiser must learn to leave a region alone.

### 63.5 Questions for the owner
1. Roles (`Reg::arg0`, `Reg::ret`, `Reg::sp`) next to the CPU names (`Reg::x0`): yes?
2. Are bare names (R1) allowed in `naked` / `register { }`, or only `Reg::`?
3. Pinned variable: `int n @ x19` , `register(x19) int n`, or another look?
4. Is `Cpu::inst("name", ...)` accepted as the last resort?
5. Should a `register { }` block warn when a callee-saved register is left changed?

### 63.6 Answers of the owner and decisions taken for him (2026-10-09, night; he went to sleep and said "follow the plan")
* A pinned variable is written `int n @ x19` (owner's choice).
* `Cpu::inst("name", ...)` as a last resort: accepted ("any way is fine").
* Not answered, decided by delegation (the owner can change them): the roles (`Reg::arg0 .. arg7`, `Reg::ret`, `Reg::sp`, `Reg::lr`, `Reg::zero`) are allowed next to the CPU names; bare names (`x0`) are allowed **inside `naked` functions and `register { }` blocks only**, as a short alias of `Reg::x0`; a `register { }` block warns when it leaves a callee-saved register changed.
* Work order: the steps of 63.4, each one a release with tests; then a round of bug hunting; then a summary for the owner; then more optimisation.

### 63.7 Status (0.9.77)
Done: step 1 (`naked`; `noreturn` is read and has no effect yet) and step 2 (`Reg::` / bare names / roles in naked functions, statements as in `docs/LANGUAGE.md`), `Cpu::` (a first group), `Sys::` read and write (`mrs` / `msr`), `Cpu::inst`. `leaf` / `noframe` is not a keyword: the compiler will drop the frame of a leaf function by itself (to do, an optimisation). `register { }` blocks inside normal functions, `abi`, `device`, `#reserve`, pinned variables `int n @ x19`, `interrupt`, `frame` and `@no_reorder` are the next steps.

### 63.8 Status (0.9.78)
Step 4 done: `Cpu::`, `Mem::barrier*`, `Cache::`, `Atomic::` (the memory order is not an argument yet: all are sequentially consistent; `Order::` variants and the LSE forms `swpal` / `ldaddal` are to do).

### 63.9 Status (0.9.79)
Step 3 done: `abi` with `number: args: result: via:` and `Name::call(...)`. Not yet: `frame` / `Context::save`, calling conventions per function (`callconv`), returning two values.

### 63.10 Status (0.9.80)
Step 5 done: `Sys::name` (read and write, in every function) and `device` (idea 2 of section 61) with bit fields. Not yet: `volatile` as a word for a pointer, `mock` devices for tests.

### 63.11 Status (0.9.81)
Step 6 done: `#reserve`, pinned variables `int n @ x19` (the look the owner chose), `Reg::` in normal code for reserved registers and x18, `register { }` blocks (question 5: yes, a warning). Not yet: `interrupt`, `frame`, `@no_reorder`.
