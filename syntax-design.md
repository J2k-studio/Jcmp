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
import "test"                     // relative: test.jk ในโฟลเดอร์เดียวกัน
import "test.math"                // relative sub-path: test/math.jk
import "./home.test.mach"         // absolute จาก root: /home/test/mach.jk
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
f8, f32, f64      // float แยกขนาดชัดเจน
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
- ไม่มี type — ถ้าต้องการ type ใช้ `const` แทน

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
| Type | `i8` `i32` `i64` `f8` `f32` `f64` `char` `void` |
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
