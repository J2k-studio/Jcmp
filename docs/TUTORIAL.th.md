# เรียนรู้ภาษา J2K ทีละขั้น

บทเรียนนี้สอนภาษาด้วยโปรแกรมเล็กๆ ทุกโปรแกรมถูกคอมไพล์และรันจริงเพื่อให้ได้ผลลัพธ์ที่เห็น
ต้องมีคอมไพเลอร์ก่อน (ดู README: `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`)
พิมพ์โปรแกรมลงไฟล์ เช่น `hello.jk` แล้ว

```bash
jcmp hello.jk -o hello      # คอมไพล์
./hello                     # รัน
```

รายการความสามารถทั้งหมดดู [LANGUAGE.md](LANGUAGE.md) (ภาษาอังกฤษ) และวิธีใช้บรรทัดคำสั่งดู [USAGE.md](USAGE.md)

## สารบัญ

1. สวัสดีชาวโลก
2. ตัวเลขและตัวแปร
3. การตัดสินใจ
4. การวนซ้ำ
5. ฟังก์ชัน
6. อาร์เรย์และข้อความ
7. การอ่านข้อมูลจากผู้ใช้
8. struct และ method
9. enum และ switch
10. พอยน์เตอร์
11. อาร์เรย์ที่โตได้และหน่วยความจำ
12. สตริง (String)
13. Generics (ชนิดแบบพารามิเตอร์)
14. ลิสต์ แมป และเซต
15. จัดการ error ด้วย try และ catch
16. ทศนิยมและไลบรารี Math
17. ไฟล์
18. โปรแกรมหลายไฟล์
19. โปรเจกต์เล็ก: นับคำ

## บทที่ 1. สวัสดีชาวโลก

โปรแกรมเริ่มทำงานที่ `main` คำสั่ง `cout <<` ใช้พิมพ์ และ `\n` คือขึ้นบรรทัดใหม่ บันทึกเป็นไฟล์ `hello.jk`

```jk
import std
using std

void main() {
    cout << "Hello, J2K!\n";
}
```

ผลลัพธ์:

```
Hello, J2K!
```

คอมไพล์และรัน: `jcmp hello.jk -o hello` แล้ว `./hello` ถ้าพิมพ์ผิด คอมไพเลอร์จะบอกไฟล์ บรรทัด คอลัมน์ และแสดงบรรทัดนั้นพร้อม `^` ชี้จุดที่ผิด
**ลองทำ:** ให้พิมพ์ชื่อของคุณ

## บทที่ 2. ตัวเลขและตัวแปร

ตัวแปรมีชนิด: `int` (จำนวนเต็ม 64 บิต), `double` (ทศนิยม), `char` (ตัวอักษรหนึ่งตัว), `bool` (จริงหรือเท็จ)
พิมพ์ทศนิยมด้วย `coutf` ทุกบรรทัดจบด้วย `;`

```jk
import std
using std

void main() {
    int apples = 5;
    int pears = 3;
    int total = apples + pears;
    cout << "total = " << total << "\n";

    double price = 2.5;
    coutf << "cost = " << price * 4.0 << "\n";

    char letter = 'J';
    cout << letter << "\n";

    bool enough = total > 7;
    if enough { cout << "enough fruit\n"; }
}
```

ผลลัพธ์:

```
total = 8
cost = 10.000000
J
enough fruit
```

`bool` ไม่ใช่ตัวเลข: `if total` ผิด ต้องเขียน `if total != 0` และ `int` กับ `double` ผสมกันตรงๆ ไม่ได้ ต้อง cast เช่น `(double)total`

## บทที่ 3. การตัดสินใจ

`if`, `else if`, `else` เลือกว่าจะทำอะไร เงื่อนไขใช้ `== != < > <= >=` และ `&&` (และ) `||` (หรือ) `!` (ไม่) ต้องมี `{ }` เสมอ

```jk
import std
using std

void main() {
    int score = 72;
    if score >= 90 {
        cout << "A\n";
    } else if score >= 70 {
        cout << "B\n";
    } else {
        cout << "C\n";
    }
    bool passed = score >= 50 && score <= 100;
    if passed { cout << "passed\n"; }
}
```

ผลลัพธ์:

```
B
passed
```

**ลองทำ:** เปลี่ยนค่า `score` แล้วดูว่าได้ตัวอักษรอะไร

## บทที่ 4. การวนซ้ำ

`while` วนซ้ำตราบที่เงื่อนไขเป็นจริง `for i in a..b` นับจาก `a` ถึง `b - 1` และมี `for` แบบ C ด้วย
`break` ออกจากลูป `continue` ข้ามไปรอบถัดไป

```jk
import std
using std

void main() {
    int i = 1;
    while i <= 3 {
        cout << i << " ";
        i++;
    }
    cout << "\n";

    for k in 0..5 { cout << k * k << " "; }
    cout << "\n";

    for int j = 10; j > 0; j -= 3 { cout << j << " "; }
    cout << "\n";
}
```

ผลลัพธ์:

```
1 2 3 
0 1 4 9 16 
10 7 4 1 
```

**ลองทำ:** พิมพ์สูตรคูณแม่ 7

## บทที่ 5. ฟังก์ชัน

ฟังก์ชันมีชนิดผลลัพธ์ ชื่อ และพารามิเตอร์ `void` คือไม่คืนค่า เขียนฟังก์ชันไว้ใต้จุดที่เรียกใช้ก็ได้

```jk
import std
using std

void main() {
    cout << square(7) << "\n";
    cout << sum_to(10) << "\n";
    greet("Ann");
}

int square(int x) {
    return x * x;
}

int sum_to(int n) {
    int s = 0;
    for i in 1..n + 1 { s += i; }
    return s;
}

void greet(char^ name) {
    cout << "Hello, " << name << "!\n";
}
```

ผลลัพธ์:

```
49
55
Hello, Ann!
```

`char^` แปลว่า "ตัวชี้ไปยังตัวอักษร" คือวิธีส่งข้อความเข้าฟังก์ชัน

## บทที่ 6. อาร์เรย์และข้อความ

`int scores[5]` คือเลข 5 ตัว นับจาก 0 `scores.len` คือความยาว ข้อความคืออาร์เรย์ของ `char` ที่ปิดท้ายด้วย 0
`char word[] = "banana"` คำนวณขนาดให้เอง อาร์เรย์มีได้ถึงสามมิติ เช่น `int grid[2][3]`

```jk
import std
using std

void main() {
    int scores[5];
    for i in 0..5 { scores[i] = (i + 1) * 10; }
    int total = 0;
    for i in 0..scores.len { total += scores[i]; }
    cout << "total " << total << "\n";

    char word[] = "banana";
    int count = 0;
    for i in 0..word.len {
        if word[i] == 'a' { count++; }
    }
    cout << word << " has " << count << " letter a\n";

    int grid[2][3];
    for r in 0..2 {
        for c in 0..3 { grid[r][c] = r * 3 + c; }
    }
    cout << grid[1][2] << "\n";
}
```

ผลลัพธ์:

```
total 150
banana has 3 letter a
5
```

คอมไพล์ด้วย `jcmp prog.jk -d -o prog` เพื่อให้โปรแกรมหยุดพร้อมข้อความเมื่อ index เกินขนาดอาร์เรย์

## บทที่ 7. การอ่านข้อมูลจากผู้ใช้

`cin >> a >> b;` อ่านข้อมูลจากคีย์บอร์ด ชนิดของตัวแปรกำหนดว่าจะอ่านอะไร: ตัวเลขสำหรับ `int` คำสำหรับอาร์เรย์ `char`
`cinf` อ่านทศนิยม คำคั่นด้วยช่องว่างหรือขึ้นบรรทัดใหม่

```jk
import std
using std

void main() {
    char name[20];
    int age;
    cin >> name >> age;
    cout << name << " will be " << age + 1 << " next year\n";
}
```

ข้อมูลเข้า: `Ann 30`

ผลลัพธ์:

```
Ann will be 31 next year
```

รันแล้วพิมพ์ `Ann 30` (หรือส่งผ่าน pipe: `echo "Ann 30" | ./input`) ถ้ากรอกผิดจะเกิด error ที่จับได้ (บทที่ 12)

## บทที่ 8. struct และ method

`struct` รวมค่าหลายตัวเข้าด้วยกัน ฟังก์ชันที่อยู่ข้างในคือ method รับตัวมันเองเป็น `self` `Rect r = {3, 4};` ใส่ค่าให้ field ตามลำดับ

```jk
import std
using std

struct Rect {
    int w;
    int h;

    int area(self) {
        return self.w * self.h;
    }

    void grow(self, int d) {
        self.w += d;
        self.h += d;
    }
}

void main() {
    Rect r = {3, 4};
    cout << r.area() << "\n";
    r.grow(1);
    cout << r.w << "x" << r.h << " area " << r.area() << "\n";
}
```

ผลลัพธ์:

```
12
4x5 area 20
```

method ชื่อ `init(self)` จะทำงานเองเมื่อสร้างตัวแปรโดยไม่ใช้ `{ ... }` ฟังก์ชัน `static` ไม่มี `self` เรียกด้วย `Rect::ชื่อ(...)`

## บทที่ 9. enum และ switch

`enum class` คือรายการค่าที่มีชื่อ `switch` เลือก case ที่ตรง โดยไม่ไหลต่อ `_` คือ "อย่างอื่นทั้งหมด"
enum ไม่ใช่ตัวเลข จึงไม่สับสนโดยไม่ตั้งใจ

```jk
import std
using std

enum class Light { Red, Yellow, Green };

void say(Light l) {
    switch l {
        Light::Red: cout << "stop\n";
        Light::Yellow: cout << "slow down\n";
        Light::Green: cout << "go\n";
    }
}

void main() {
    say(Light::Green);
    say(Light::Red);

    int n = 3;
    switch n {
        1, 2: cout << "small\n";
        3: cout << "three\n";
        _: cout << "other\n";
    }
}
```

ผลลัพธ์:

```
go
stop
three
```

ถ้า `switch` ของ enum ลืมสมาชิกตัวใดตัวหนึ่ง คอมไพเลอร์จะเตือน (ใช้ `-st` เพื่อให้ warning เป็น error)

## บทที่ 10. พอยน์เตอร์

`@x` คือที่อยู่ของ `x` `int^ p` คือพอยน์เตอร์ชี้ไปที่ int และ `p^` คือค่าที่มันชี้ พอยน์เตอร์ทำให้ฟังก์ชันแก้ตัวแปรของผู้เรียกได้
`p[i]` เข้าถึงสมาชิกตัวที่ i (ไม่มี `p + 1`)

```jk
import std
using std

void bump(int^ p) {
    p^ = p^ + 1;
}

void main() {
    int n = 5;
    bump(@n);
    bump(@n);
    cout << n << "\n";

    int a[3];
    a[0] = 10; a[1] = 20; a[2] = 30;
    int^ q = @a;
    cout << q[1] << "\n";
}
```

ผลลัพธ์:

```
7
20
```

## บทที่ 11. อาร์เรย์ที่โตได้และหน่วยความจำ

`int[] list = arr(4)` คืออาร์เรย์ที่โตได้ เริ่มว่างและโตเมื่อ `push` ส่วน `alloc(n)` ขอหน่วยความจำดิบ
ตัวแปร local ที่สร้างจาก `arr` หรือ `alloc` จะถูกคอมไพเลอร์ปล่อยให้เองตอนจบบล็อก จึงแทบไม่ต้องเรียก `free` เอง

```jk
import std

using std
int total(int[] list) {
    int s = 0;
    for i in 0..list.len { s += list[i]; }
    return s;
}

void main() {
    int[] squares = arr(4);
    for i in 1..6 { squares.push(i * i); }
    cout << squares.len << " items, total " << total(squares) << "\n";

    int^ buffer = (int^)alloc(sizeof(int) * 3);
    buffer[0] = 7;
    buffer[1] = 8;
    buffer[2] = 9;
    cout << buffer[0] + buffer[2] << "\n";
}   // squares and buffer are freed here
```

ผลลัพธ์:

```
5 items, total 55
16
```

การส่งมอบหน่วยความจำให้ที่อื่น: `return p;` เก็บใน field หรือ `move(p)` คอมไพล์แบบ `-d` จะบอกตอนจบว่ามีกี่บล็อกที่ไม่ได้ปล่อย

## บทที่ 12. สตริง (String)

`String` เก็บข้อความที่ยาวขึ้นได้ `String s = "hello";` ทำสำเนาของข้อความ `a + b` ต่อสตริง `==` เปรียบเทียบ `s.len` คือความยาว `s[i]` คือตัวอักษรตัวที่ i
เมธอด: `push`, `append`, `pop`, `clear`, `find`, `slice(จาก, ถึง)`, `c()` (ตัวอักษรในรูปข้อความธรรมดา) `cin >> s` อ่านหนึ่งคำ
`String` ถูกปล่อยเองตอนจบบล็อก และ `String b = a;` ทำสำเนาแยกอิสระ

```jk
import std
using std

String shout(String s) {
    String r = s + "!";
    return r;
}

void main() {
    String a = "abc";
    String b = a;
    b.push('d');
    cout << a << " " << b << "\n";

    String line = "Hello, " + shout("Jao");
    cout << line << " (" << line.len << " characters)\n";
    cout << line.find("Jao") << " " << line.slice(0, 5) << "\n";
    if a == "abc" { cout << "same\n"; }
}
```

ผลลัพธ์:

```
abc abcd
Hello, Jao! (11 characters)
7 Hello
same
```

`String` ใหม่ที่เกิดจากนิพจน์ (`a + b`, การเรียกฟังก์ชัน, `slice`) ถูกปล่อยให้เองตอนจบคำสั่ง ส่วน `s.c()` ชี้เข้าไปใน String จึงใช้ได้จนกว่าจะแก้ String
พารามิเตอร์ที่เป็น String เป็นการยืม String ของผู้เรียก จึงกำหนดค่าให้มันในฟังก์ชันไม่ได้

## บทที่ 13. Generics (ชนิดแบบพารามิเตอร์)

ฟังก์ชันหรือ struct รับชนิดเป็นพารามิเตอร์ได้ เขียนใน `<>` ต่อท้ายชื่อ คอมไพเลอร์สร้างสำเนาให้ทุกชนิดที่ใช้
ตอนใช้ต้องเขียนชนิดทุกครั้ง: `largest<int>(...)`, `Box<double>`

```jk
import std
using std

T largest<T>(T a, T b) {
    if a > b { return a; }
    return b;
}

struct Box<T> {
    T value;
    T get(self) { return self.value; }
}

void main() {
    cout << largest<int>(3, 9) << "\n";
    coutf << largest<double>(2.5, 1.5) << "\n";
    Box<int> b = {7};
    cout << b.get() << "\n";
}
```

ผลลัพธ์:

```
9
2.500000
7
```

generic ต้องเขียนไว้ก่อนจุดแรกที่ใช้มัน

## บทที่ 14. ลิสต์ แมป และเซต

ลิสต์คืออาร์เรย์ที่โตได้ มีเครื่องมือเพิ่ม: `sort`, `insert`, `remove`, `contains`, `index_of` และ `for x in list` วนทุกสมาชิก
`Map<K,V>` เก็บค่าตามคีย์ ส่วน `Set<T>` เก็บแต่ละค่าครั้งเดียว ทั้งสองปล่อยหน่วยความจำเองตอนจบบล็อก

```jk
import std
using std

void main() {
    int[] scores = arr(4);
    scores.push(72); scores.push(95); scores.push(60);
    scores.sort();
    for s in scores { cout << s << " "; }
    cout << "\n";

    Map<String, int> ages;
    ages.put("ann", 31);
    ages.put("bob", 25);
    ages.put("ann", 32);
    cout << ages.get("ann") << " " << ages.len << "\n";
    for name in ages.keys_list() {
        cout << name << " is " << ages.get(name) << "\n";
    }

    Set<int> seen;
    for i in 0..20 { seen.add(i % 5); }
    cout << seen.len << " different, has 3: " << seen.has(3) << "\n";
}
```

ผลลัพธ์:

```
60 72 95 
32 2
ann is 32
bob is 25
5 different, has 3: 1
```

`ages.get("zed")` จะ throw `key not found` ถามก่อนด้วย `ages.has("zed")` ส่วน `keys_list()` สร้างลิสต์ใหม่ที่ลูป `for` ปล่อยให้เอง

## บทที่ 15. จัดการ error ด้วย try และ catch

`throw "ข้อความ"` หยุดงานที่ทำอยู่และกระโดดไปที่ `catch` ที่ใกล้ที่สุด ถ้าไม่มี `catch` โปรแกรมจะหยุดและพิมพ์ `uncaught exception: ข้อความ`

```jk
import std
using std

int divide(int a, int b) {
    if b == 0 { throw "cannot divide by zero"; }
    return a / b;
}

void main() {
    try {
        cout << divide(10, 2) << "\n";
        cout << divide(1, 0) << "\n";
    } catch (e) {
        cout << "error: " << e << "\n";
    }
}
```

ผลลัพธ์:

```
5
error: cannot divide by zero
```

## บทที่ 16. ทศนิยมและไลบรารี Math

`import std` นำไลบรารีมาตรฐานเข้ามา และ `using std` ทำให้เขียน `sqrt(x)` แทน `Math::sqrt(x)` ได้ (ทุกโปรแกรมที่พิมพ์ข้อความต้องมีสองบรรทัดนี้ บทเรียนเติมให้ที่บนสุด) ถ้าสองโมดูลมีฟังก์ชันชื่อเดียวกัน (`write` อยู่ทั้งใน `Sys` และ `File`) ให้เขียนชื่อโมดูล: `File::write(...)` การแปลงชนิดต้องเขียนเอง: `(int)x`, `(double)n`

```jk
import std

using std
void main() {
    double a = 3.0;
    double b = 4.0;
    coutf << "hypotenuse = " << sqrt(a * a + b * b) << "\n";

    int whole = (int)floor(7.9);
    cout << whole << "\n";

    double half = (double)whole / 2.0;
    coutf << half << "\n";
}
```

ผลลัพธ์:

```
hypotenuse = 5.000000
7
3.500000
```

ไลบรารีมี `Sys` (คำสั่งระบบ), `Mem` (หน่วยความจำ), `Str` (ข้อความ), `Math` และ `File`

## บทที่ 17. ไฟล์

`File::open(path, mode)` คืนเลขตัวหนึ่ง (ติดลบถ้าล้มเหลว) แล้วใช้ `read`, `write`, `read_line`, `close` กับเลขนั้น

```jk
import std

using std
void main() {
    i32 f = File::open("note.txt", FileMode::Write);
    if f < 0 { throw "cannot create note.txt"; }
    File::write(f, "J2K can write files\n");
    File::close(f);

    char line[64];
    i32 g = File::open("note.txt", FileMode::Read);
    File::read_line(g, line);
    File::close(g);
    cout << line << "\n";
}
```

ผลลัพธ์:

```
J2K can write files
```

## บทที่ 18. โปรแกรมหลายไฟล์

ไฟล์ `.jk` คือโปรแกรม (มี `main`) ไฟล์ `.j` คือส่วนประกอบที่ไฟล์อื่น `import` ไปใช้ ห้ามมี `main`
`import "mathx"` หาไฟล์ `mathx.j` ที่อยู่ข้างไฟล์ ส่วน `import "tools.mathx"` หา `tools/mathx.j`

`mathx.j`:

```jk
// mathx.j -- a component: functions to import
int cube(int x) {
    return x * x * x;
}
```

`multi.jk`:

```jk
import std
using std

import "mathx"

void main() {
    cout << cube(3) << "\n";
}
```

ผลลัพธ์:

```
27
```

คอมไพล์เฉพาะไฟล์หลัก: `jcmp multi.jk -o multi` ไฟล์ที่ import จะถูกอ่านให้เอง (ครั้งเดียว)

## บทที่ 19. โปรเจกต์เล็ก: นับคำ

รวมทุกอย่างเข้าด้วยกัน: อ่านคำไปเรื่อยๆ จนข้อมูลหมด (อ่านเกินจะ throw `end of input`) แล้วรายงานจำนวนคำและคำที่ยาวที่สุด

```jk
import std
using std

int length(char^ s) {
    int n = 0;
    while s[n] != 0 { n++; }
    return n;
}

void main() {
    char w[32];
    int count = 0;
    int longest = 0;
    try {
        while true {
            cin >> w;
            count++;
            int n = length(@w);
            if n > longest { longest = n; }
        }
    } catch (e) {
        // the input is over
    }
    cout << count << " words, the longest has " << longest << " letters\n";
}
```

ข้อมูลเข้า: `the quick brown fox jumps over the lazy dog`

ผลลัพธ์:

```
9 words, the longest has 5 letters
```

รัน: `echo "the quick brown fox jumps over the lazy dog" | ./wordcount`
**ลองทำ:** ให้พิมพ์คำที่ยาวที่สุดด้วย

## ต่อไป

* [LANGUAGE.md](LANGUAGE.md) — ทุกความสามารถพร้อมตัวอย่าง (function pointer, ชนิด unsigned, `sizeof` ฯลฯ)
* [USAGE.md](USAGE.md) — ตัวเลือกของคอมไพเลอร์ (`-d`, `-st`, `-I`, `--emit-asm`)
* โฟลเดอร์ `examples/` ใน repository — โปรแกรมตัวอย่างเพิ่มเติม
