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
15. Lambda (ฟังก์ชันไม่มีชื่อ)
16. จัดการ error ด้วย try และ catch
17. ทศนิยมและไลบรารี Math
18. ไฟล์
19. โปรแกรมหลายไฟล์
20. โปรเจกต์เล็ก: นับคำ
21. บิตและไบต์
22. เลขที่กว้างกว่า 64 บิต
23. ดูโค้ดที่คอมไพเลอร์สร้าง
24. คุมโค้ดให้สั้น: #expect
25. เธรดและคำสั่ง atomic
26. Register: บล็อก register
27. ฟังก์ชันเปลือย: naked และ svc
28. ธงของ CPU
29. คำสั่งเครื่องที่เขียนเอง

## บทที่ 1. สวัสดีชาวโลก

โปรแกรมเริ่มทำงานที่ `main` คำสั่ง `cout <<` ใช้พิมพ์ และ `\n` คือขึ้นบรรทัดใหม่ บันทึกเป็นไฟล์ `hello.jk`

```jk
#import <stdlib>
using stdlib;

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
`cout` พิมพ์ทศนิยมได้ด้วย ทุกบรรทัดจบด้วย `;`

```jk
#import <stdlib>
using stdlib;

void main() {
    int apples = 5;
    int pears = 3;
    int total = apples + pears;
    cout << "total = " << total << "\n";

    double price = 2.5;
    cout << "cost = " << price * 4.0 << "\n";

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
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
`cin` อ่านทศนิยมได้ด้วย คำคั่นด้วยช่องว่างหรือขึ้นบรรทัดใหม่

```jk
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
#import <stdlib>
using stdlib;

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
#import <stdlib>

using stdlib;
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
#import <stdlib>
using stdlib;

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
ฟังก์ชันหาชนิดจากอาร์กิวเมนต์เอง: `largest(3, 9)` หรือเขียนเองก็ได้ `largest<int>(3, 9)` ส่วน struct ต้องเขียนชนิดเสมอ: `Box<double>`

```jk
#import <stdlib>
using stdlib;

T largest<T>(T a, T b) {
    if a > b { return a; }
    return b;
}

struct Box<T> {
    T value;
    T get(self) { return self.value; }
}

void main() {
    cout << largest(3, 9) << "\n";
    cout << largest(2.5, 1.5) << "\n";
    cout << largest<int>(8, 2) << "\n";
    Box<int> b = {7};
    cout << b.get() << "\n";
}
```

ผลลัพธ์:

```
9
2.500000
8
7
```

generic ต้องเขียนไว้ก่อนจุดแรกที่ใช้มัน `largest(1, 2.5)` เป็น error (จำนวนเต็มกับทศนิยมไม่ปนกัน) ให้เขียน `largest(1.0, 2.5)` ถ้าคอมไพเลอร์หาชนิดไม่ได้ จะบอก แล้วคุณเขียนชนิดเอง

## บทที่ 14. ลิสต์ แมป และเซต

ลิสต์คืออาร์เรย์ที่โตได้ มีเครื่องมือเพิ่ม: `sort`, `insert`, `remove`, `contains`, `index_of` และ `for x in list` วนทุกสมาชิก
`Map<K,V>` เก็บค่าตามคีย์ ส่วน `Set<T>` เก็บแต่ละค่าครั้งเดียว ทั้งสองปล่อยหน่วยความจำเองตอนจบบล็อก

```jk
#import <stdlib>
using stdlib;

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
5 different, has 3: true
```

`ages.get("zed")` จะ throw `key not found` ถามก่อนด้วย `ages.has("zed")` ส่วน `keys_list()` สร้างลิสต์ใหม่ที่ลูป `for` ปล่อยให้เอง

## บทที่ 15. Lambda (ฟังก์ชันไม่มีชื่อ)

lambda คือฟังก์ชันเล็กๆ ที่เขียนตรงจุดที่ใช้: `int(int a, int b) { return a + b; }` ส่งให้ฟังก์ชันที่รับ function pointer ได้
หรือเก็บในตัวแปรชนิด `int(int, int)^` มันใช้ตัวแปรข้างนอกไม่ได้

```jk
#import <stdlib>
using stdlib;

int apply(int(int, int)^ f, int x, int y) {
    return f(x, y);
}

void main() {
    cout << apply(int(int a, int b) { return a + b; }, 3, 4) << "\n";
    int(int)^ triple = int(int x) { return x * 3; };
    cout << triple(5) << "\n";
}
```

ผลลัพธ์:

```
7
15
```

ชนิดเขียนครบ จึงอ่านเหมือนฟังก์ชันปกติ ถ้าต้องการค่าจากข้างนอกให้ส่งเป็นพารามิเตอร์

## บทที่ 16. จัดการ error ด้วย try และ catch

`throw "ข้อความ"` หยุดงานที่ทำอยู่และกระโดดไปที่ `catch` ที่ใกล้ที่สุด ถ้าไม่มี `catch` โปรแกรมจะหยุดและพิมพ์ `uncaught exception: ข้อความ`

```jk
#import <stdlib>
using stdlib;

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

## บทที่ 17. ทศนิยมและไลบรารี Math

`#import <stdlib>` นำไลบรารีมาตรฐานเข้ามา และ `using stdlib` ทำให้เขียน `sqrt(x)` แทน `Math::sqrt(x)` ได้ (ทุกโปรแกรมที่พิมพ์ข้อความต้องมีสองบรรทัดนี้ บทเรียนเติมให้ที่บนสุด) ถ้าสองโมดูลมีฟังก์ชันชื่อเดียวกัน (`write` อยู่ทั้งใน `Sys` และ `File`) ให้เขียนชื่อโมดูล: `File::write(...)` การแปลงชนิดต้องเขียนเอง: `(int)x`, `(double)n`

```jk
#import <stdlib>

using stdlib;
void main() {
    double a = 3.0;
    double b = 4.0;
    cout << "hypotenuse = " << sqrt(a * a + b * b) << "\n";

    int whole = (int)floor(7.9);
    cout << whole << "\n";

    double half = (double)whole / 2.0;
    cout << half << "\n";
}
```

ผลลัพธ์:

```
hypotenuse = 5.000000
7
3.500000
```

ไลบรารีมี `Sys` (คำสั่งระบบ), `Mem` (หน่วยความจำ), `Str` (ข้อความ), `Math` และ `File`

## บทที่ 18. ไฟล์

`File::open(path, mode)` คืนเลขตัวหนึ่ง (ติดลบถ้าล้มเหลว) แล้วใช้ `read`, `write`, `read_line`, `close` กับเลขนั้น

```jk
#import <stdlib>

using stdlib;
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

## บทที่ 19. โปรแกรมหลายไฟล์

ไฟล์ `.jk` คือโปรแกรม (มี `main`) ไฟล์ `.j` คือส่วนประกอบที่ไฟล์อื่น `import` ไปใช้ ห้ามมี `main`
`#import "mathx"` หาไฟล์ `mathx.j` ที่อยู่ข้างไฟล์ ส่วน `#import "tools.mathx"` หา `tools/mathx.j`

`mathx.j`:

```jk
// mathx.j -- a component: functions to import
int cube(int x) {
    return x * x * x;
}
```

`multi.jk`:

```jk
#import <stdlib>
using stdlib;

#import "mathx"

void main() {
    cout << cube(3) << "\n";
}
```

ผลลัพธ์:

```
27
```

คอมไพล์เฉพาะไฟล์หลัก: `jcmp multi.jk -o multi` ไฟล์ที่ import จะถูกอ่านให้เอง (ครั้งเดียว)

## บทที่ 20. โปรเจกต์เล็ก: นับคำ

รวมทุกอย่างเข้าด้วยกัน: อ่านคำไปเรื่อยๆ จนข้อมูลหมด (อ่านเกินจะ throw `end of input`) แล้วรายงานจำนวนคำและคำที่ยาวที่สุด

```jk
#import <stdlib>
using stdlib;

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

# ภาคที่ 2: ลงไปหาเครื่อง

## บทที่ 21. บิตและไบต์

เลขเต็มมี 64 บิต `>>` กับ `<<` เลื่อนบิต `&` เก็บบิต `xor` สลับบิต ส่วน `Bit::` คืองานที่ CPU ทำได้ในคำสั่งเดียว:
`popcount` (นับบิตที่เป็น 1), `clz` / `ctz` (นับบิต 0 ข้างหน้า / ข้างหลัง), `rotl` / `rotr` (หมุนบิต), `bswap` (กลับลำดับ 8 ไบต์)

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 0xB0;
    cout << x << " " << Bit::popcount(x) << " " << Bit::clz(x) << " " << Bit::ctz(x) << "\n";
    cout << (x >> 4) << " " << (x & 0xF) << " " << (x << 4) << " " << (x xor 0xFF) << "\n";
    cout << Bit::rotl(1, 63) << "\n";
    cout << Bit::bswap(0x0102030405060708) << "\n";
}
```

ผลลัพธ์:

```
176 3 56 4
11 0 2816 79
-9223372036854775808
578437695752307201
```

`0xB0` คือ `1011 0000` ในเลขฐานสอง: มี 3 บิตเป็น 1, มีบิต 0 อยู่ข้างหน้า 56 ตัว และข้างหลัง 4 ตัว บรรทัดสุดท้ายกลับไบต์ `01 02 ... 08` เป็น `08 07 ... 01`

## บทที่ 22. เลขที่กว้างกว่า 64 บิต

เมื่อ 64 บิตไม่พอ ก็เก็บเลขเป็นหลายคำแล้วบวกทีละคำ `Bit::add_carry(a, b, carry_in)` คืน struct ที่มีผลรวมและตัวทดออก
`Bit::mul_wide` คืนผลคูณ 128 บิตเต็ม, `Bit::div_rem` คืนผลหารและเศษพร้อมกัน, `Bit::add_sat` คือการบวกที่หยุดที่เลขมากสุดแทนที่จะวนกลับ

```jk
#import <stdlib>
using stdlib;

void main() {
    // (5, -1) + (0, 1) as numbers of two words: high word first
    BitCarry lo = Bit::add_carry(-1, 1, 0);
    BitCarry hi = Bit::add_carry(5, 0, lo.c);
    cout << hi.sum << " " << lo.sum << " " << hi.c << "\n";
    BitWide w = Bit::mul_wide(-1, 3);
    cout << w.hi << " " << w.lo << "\n";
    BitDivRem d = Bit::div_rem(-17, 5);
    cout << d.q << " " << d.r << "\n";
    cout << Bit::add_sat(9223372036854775807, 5) << "\n";
}
```

ผลลัพธ์:

```
6 0 0
2 -3
-3 -2
9223372036854775807
```

คำล่าง `-1 + 1` ได้ 0 และมีตัวทด 1 ตัวทดเข้าไปในคำบน: `5 + 0 + 1 = 6` ผลคูณ `(2^64 - 1) * 3` ใส่ 64 บิตไม่พอ: `hi` เป็น 2 และ `lo` เป็น -3

## บทที่ 23. ดูโค้ดที่คอมไพเลอร์สร้าง

คอมไพเลอร์ไม่ซ่อนสิ่งที่มันสร้าง: `jcmp program.jk -show ชื่อ` แสดงโค้ดเครื่องของฟังก์ชัน `ชื่อ` และจำนวนคำสั่ง
ฟังก์ชันเล็กๆ มักถูกยัดเข้าไปในผู้เรียก ฟังก์ชันที่ถูกเรียกครั้งเดียวจึงอาจไม่มีโค้ดของตัวเอง ตรงนี้ `scale` ยังอยู่เพราะ `main` เรียกใน loop

```jk
#import <stdlib>
using stdlib;

int scale(int x, int k) {
    return (x * k) >> 2;
}

void main() {
    int total = 0;
    for i in 0..10 { total += scale(i, 6); }
    cout << total << "\n";
}
```

ผลลัพธ์:

```
65
```

โค้ดของ `scale` ที่คอมไพเลอร์สร้าง:

```
scale:
mul x0, x0, x1
asr x0, x0, #2
L8014:
ret
// 3 instructions
```

รัน `jcmp showcode.jk -show scale` เพื่อดูบรรทัดข้างบน (เป็นโค้ดของ target ARM64 ส่วน target อื่นคำสั่งจะต่างออกไป)

## บทที่ 24. คุมโค้ดให้สั้น: #expect

ฟังก์ชันที่ถูกเรียกถี่ควรเล็กอยู่เสมอ `#expect instructions <= N` หน้าฟังก์ชัน ทำให้คอมไพเลอร์หยุดพร้อมบอกจำนวนจริงเมื่อฟังก์ชันยาวเกิน N: ไม่ว่าจะเพราะแก้โปรแกรมหรือเปลี่ยนคอมไพเลอร์

```jk
#import <stdlib>
using stdlib;

#expect instructions <= 12
int clamp(int x, int lo, int hi) {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

void main() {
    cout << clamp(-5, 0, 10) << " " << clamp(7, 0, 10) << " " << clamp(99, 0, 10) << "\n";
}
```

ผลลัพธ์:

```
0 7 10
```

ลองเปลี่ยนเป็น `#expect instructions <= 2` แล้วคอมไพล์ใหม่: คอมไพเลอร์จะบอกว่าฟังก์ชันมีกี่คำสั่งจริง

## บทที่ 25. เธรดและคำสั่ง atomic

`Thread` รันฟังก์ชันพร้อมกับฟังก์ชันอื่น สองเธรดที่ทำ `counter += 1` อาจนับตกหล่น เพราะ CPU อ่าน บวก เขียน เป็นสามขั้น `Atomic::add` ทำสามขั้นนี้เป็นขั้นเดียวที่ไม่มีใครแทรกได้

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int counter;

void work(void^ arg) {
    for i in 0..10000 { Atomic::add(@counter, 1); }
}

void main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    Thread c = create(work, null);
    a.join();
    b.join();
    c.join();
    cout << counter << "\n";
}
```

ผลลัพธ์:

```
30000
```

`Atomic::` ยังมี `cas` (เปลี่ยนค่าก็ต่อเมื่อเป็นค่าที่คาดไว้), `swap`, `load`, `store`, `bit_or` และอื่นๆ ส่วน `Mem::barrier()` จัดลำดับการเข้าถึงหน่วยความจำของเธรดหนึ่งเทียบกับเธรดอื่น

## บทที่ 26. Register: บล็อก register

CPU เก็บตัวเลขที่กำลังทำงานไว้ใน register ชื่อ `x0` ... `x30` บล็อก `register { }` ให้คุณเขียนคำสั่งที่ใช้ register เหล่านั้น `in x1 = a;` ใส่ค่าลง register ก่อนเข้าบล็อก, `out x0 = r;` เอาค่าออกหลังบล็อก และ `clobber x4;` บอกว่าคุณใช้ `x4` ทำงานของตัวเอง
ในบล็อก หนึ่งประโยคคือหนึ่งคำสั่ง

```jk
#import <stdlib>
using stdlib;

int add_mul(int a, int b, int c) {
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        in x3 = c;
        clobber x4;
        x4 = x1 + x2;
        x0 = x4 * x3;
        out x0 = r;
    }
    return r;
}

void main() {
    cout << add_mul(2, 3, 4) << "\n";
}
```

ผลลัพธ์:

```
20
```

`(2 + 3) * 4 = 20` ซอร์สเดียวกันคอมไพล์ได้ทั้ง target ARM64 และ ARM32 (ชื่อ `x0 ...` เหมือนกันทั้งสอง)

## บทที่ 27. ฟังก์ชันเปลือย: naked และ svc

ฟังก์ชัน `naked` ไม่มี prologue และ epilogue: ตัวฟังก์ชันคือทั้งหมดที่มี และอาร์กิวเมนต์อยู่ใน `x0`, `x1`, ... ประโยค `svc(0);` ขอบริการจากเคอร์เนล หมายเลขบริการอยู่ใน `x8`
นี่คือ `write` (หมายเลข 64) ที่เขียนเองด้วยมือ โดยไม่ใช้ไลบรารีเลย

```jk
#import <stdlib>
using stdlib;

naked int my_write(int fd, char^ buf, int n) {
    Reg::x8 = 64;
    svc(0);
    ret;
}

void main() {
    char msg[6] = {'h', 'e', 'l', 'l', 'o', '\n'};
    int n = my_write(1, @msg, 6);
    cout << n << "\n";
}
```

ผลลัพธ์:

```
hello
6
```

`write(1, buffer, 6)` ส่ง 6 ไบต์ไปที่ standard output และคืนจำนวนที่เขียน `ret;` กลับไปหาผู้เรียกโดยมีผลลัพธ์ใน `x0`

## บทที่ 28. ธงของ CPU

หลังการบวกหรือเปรียบเทียบ CPU จะเก็บธงสี่ตัว: `n` (ลบ), `z` (ศูนย์), `c` (ตัวทด) และ `v` (ล้น) ภาษา C ซ่อนมันไว้ แต่ที่นี่คุณอ่านได้ `Cpu::inst("adds", ...)` คือคำสั่ง `adds` ที่ตั้งธง และ `Flags::c` อ่านธงหนึ่งตัวเป็น 0 หรือ 1

```jk
#import <stdlib>
using stdlib;

int carry_of(int a, int b) {
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        Cpu::inst("adds", Reg::x3, Reg::x1, Reg::x2);
        x0 = Flags::c;
        out x0 = r;
    }
    return r;
}

void main() {
    cout << carry_of(-1, 1) << " " << carry_of(1, 2) << "\n";
}
```

ผลลัพธ์:

```
1 0
```

`-1` คือบิตทุกตัวเป็น 1 ดังนั้น `-1 + 1` ทดออกทางบนสุด: ธงเป็น 1 ส่วน `1 + 2` ไม่ทด: 0 (บทนี้ใช้กับ target ARM64)

## บทที่ 29. คำสั่งเครื่องที่เขียนเอง

ที่ชั้นล่างสุดมีแต่ตัวเลข `raw<u32>[...]` ใส่คำสั่งเครื่อง 32 บิตลงในโค้ดตามที่คุณเขียนทุกประการ คำสั่ง `add x1, x1, #2` ของ CPU ARM64 คือเลข `0x91000821` และ `nop` คือ `0xd503201f`

```jk
#import <stdlib>
using stdlib;

void main() {
    int v = 5;
    register {
        in x1 = v + 1;
        raw<u32>[0xd503201f];
        raw<u32>[0x91000821];
        out x1 = v;
    }
    cout << v << "\n";
}
```

ผลลัพธ์:

```
8
```

`5 + 1 = 6` แล้วคำสั่งบวกอีก 2: ได้ 8 เลขเหล่านี้เป็นของ ARM64 บน target ARM32 คำสั่งเดียวกันเป็นเลขอีกตัว (`0xE2811002`) โปรแกรมที่เขียนคำสั่งเครื่องเองจึงใช้ได้กับ CPU ตระกูลเดียว

## ต่อไป

* [LANGUAGE.md](LANGUAGE.md) — ทุกความสามารถพร้อมตัวอย่าง (function pointer, ชนิด unsigned, `sizeof` ฯลฯ)
* [USAGE.md](USAGE.md) — ตัวเลือกของคอมไพเลอร์ (`-d`, `-st`, `-I`, `--emit-asm`)
* โฟลเดอร์ `examples/` ใน repository — โปรแกรมตัวอย่างเพิ่มเติม
