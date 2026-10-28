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
8. บรรทัด ตัวเลข และปุ่ม: read
9. struct และ method
10. enum และ switch
11. พอยน์เตอร์
12. อาร์เรย์ที่โตได้และหน่วยความจำ
13. สตริง (String)
14. Generics (ชนิดแบบพารามิเตอร์)
15. ลิสต์ แมป และเซต
16. Lambda (ฟังก์ชันไม่มีชื่อ)
17. จัดการ error ด้วย try และ catch
18. ทศนิยมและไลบรารี Math
19. ไฟล์
20. โปรแกรมหลายไฟล์
21. โปรเจกต์เล็ก: นับคำ
22. Option, Result และ ?
23. defer: เก็บกวาดทุกทางออก
24. ตัวดำเนินการสำหรับชนิดของคุณเอง
25. วันที่ เวลา และเลขสุ่ม
26. JSON
27. CSV และการจัดรูปแบบตัวเลข
28. แพตเทิร์น แฮช และการเข้ารหัส
29. path โปรแกรมอื่น และ log
30. บิตและไบต์
31. เลขที่กว้างกว่า 64 บิต
32. ดูโค้ดที่คอมไพเลอร์สร้าง
33. คุมโค้ดให้สั้น: #expect
34. เธรดและคำสั่ง atomic
35. Register: บล็อก register
36. ฟังก์ชันเปลือย: naked และ svc
37. ธงของ CPU
38. คำสั่งเครื่องที่เขียนเอง
39. ที่อยู่และไบต์
40. คุยกับ kernel โดยตรง
41. allocator ของคุณเอง
42. spinlock
43. นับนาฬิกาของ CPU
44. เวกเตอร์ในฮาร์ดแวร์
45. สองงาน สองสแตก: การสลับ context
46. คิวที่ไม่มี lock
47. ฟังก์ชันทั้งตัวเป็นคำสั่งดิบ
48. คำสั่งใดๆ ของ CPU ตามชื่อ
49. ชื่อเป็นชั้น: โมดูลและ using
50. enum ที่เก็บค่า
51. struct: เมธอด ซ้อน และอาร์เรย์
52. ค่าที่คืนหน่วยความจำเอง
53. พอยน์เตอร์ฟังก์ชันและ lambda
54. ตัวเลขทุกขนาด
55. หน่วยความจำดิบ: alloc, pool และ grow
56. ไบต์ดิบและข้อมูลที่เปลี่ยนไม่ได้
57. สร้างโปรเจกต์ด้วย makej
58. หลายคอร์ และไฟล์ build ที่เป็นโปรแกรม
59. ไลบรารีที่ใช้ร่วมกัน: export และ -l
60. สคริปต์ด้วย jsh และการเขียนโค้ดบนมือถือ

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

รันแล้วพิมพ์ `Ann 30` (หรือส่งผ่าน pipe: `echo "Ann 30" | ./input`) ถ้ากรอกผิดจะเกิด error ที่จับได้ (บทที่ 17)

## บทที่ 8. บรรทัด ตัวเลข และปุ่ม: read

`cin` อ่านทีละคำ ถ้าต้องการทั้งบรรทัด ตัวเลขจากบรรทัด หรือคำตอบของคำถาม ให้ใช้โมดูล `read` (`using Input;`): `read.line()`, `read.number()`, `read.yes("คำถาม")` ส่วน `read.enter()` รอให้กด Enter และ `read.key()` รอปุ่มเดียวโดยไม่ต้องกด Enter (ดูข้างล่าง)

```jk
#import <stdlib>
using stdlib;
using Input;

void main() {
    cout << "name? ";
    String name = read.line();
    cout << "age? ";
    int age = read.number();
    cout << name << " will be " << age + 1 << " next year\n";
    if read.yes("again?") { cout << "ok\n"; } else { cout << "bye\n"; }
}
```

ข้อมูลเข้า: `Ann
30
y`

ผลลัพธ์:

```
name? age? Ann will be 31 next year
again? [y/n] ok
```

`read.number()` โยน error เมื่อบรรทัดไม่ใช่จำนวนเต็ม (`read.try_number()` คืน `Result` แทน) `read.key()` คืนรหัสของปุ่ม ไม่แสดงบนจอและไม่ต้องกด Enter: ตัวอักษรคือรหัสของมัน Escape คือ 27 ลูกศรคือ 257 (ขึ้น) 258 (ลง) 259 (ขวา) 260 (ซ้าย) ตามด้วย Home, End, Delete, ปุ่มหน้า และ F1 ถึง F4 และเมื่ออินพุตหมดคือ -1 `read.key_timeout(ms)` ยอมแพ้เมื่อครบเวลา (-2), `read.password()` ซ่อนสิ่งที่พิมพ์ และ `read.decimal()` อ่านตัวเลขที่มีทศนิยม เกมหรือเมนูอ่านแป้นพิมพ์แบบนี้ ใน 1 โปรแกรมใช้ `read` หรือ `cin` อย่างใดอย่างหนึ่ง ไม่ใช้ทั้งสอง

## บทที่ 9. struct และ method

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

## บทที่ 10. enum และ switch

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

## บทที่ 11. พอยน์เตอร์

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

## บทที่ 12. อาร์เรย์ที่โตได้และหน่วยความจำ

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

## บทที่ 13. สตริง (String)

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

## บทที่ 14. Generics (ชนิดแบบพารามิเตอร์)

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

## บทที่ 15. ลิสต์ แมป และเซต

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

## บทที่ 16. Lambda (ฟังก์ชันไม่มีชื่อ)

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

## บทที่ 17. จัดการ error ด้วย try และ catch

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

## บทที่ 18. ทศนิยมและไลบรารี Math

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

## บทที่ 19. ไฟล์

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

## บทที่ 20. โปรแกรมหลายไฟล์

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

## บทที่ 21. โปรเจกต์เล็ก: นับคำ

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

# ไลบรารีเพิ่มเติม

## บทที่ 22. Option, Result และ ?

การทำงานที่อาจล้มเหลวให้ `Result<T, Error>` ส่วนค่าที่อาจไม่มีคือ `Option<T>` แกะ `Result` ด้วย `switch` หรือส่งความล้มเหลวต่อด้วย `?`: `int x = parse(a)?;` คืน error ให้ผู้เรียกทันที ถ้าไม่ล้มเหลวก็ได้ค่า

```jk
#import <stdlib>
using stdlib;

Result<int, Error> parse(String s) {
    if s.len == 0 { return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "empty text")); }
    return Result<int, Error>::Ok(s.to_int());
}

Result<int, Error> add(String a, String b) {
    int x = parse(a)?;
    int y = parse(b)?;
    return Result<int, Error>::Ok(x + y);
}

void show(Result<int, Error> r) {
    switch r {
        Result::Ok(v): cout << "sum = " << v << "\n";
        Result::Err(e): cout << "error: " << e.message << "\n";
    }
}

void main() {
    show(add("20", "22"));
    show(add("20", ""));
    Option<String> home = Env::get("J2K_SURELY_NOT_SET");
    cout << home.is_none() << " " << Env::get("PATH").is_some() << "\n";
}
```

ผลลัพธ์:

```
sum = 42
error: empty text
true true
```

`add` ไม่มี `if` สำหรับ error: `?` ทำให้ `Env::get` ให้ `Option`: ถามด้วย `is_none()` / `is_some()` ตัวช่วยอื่น: `unwrap()` (โยน error เมื่อไม่มีค่า) และ `or(ค่าสำรอง)` ส่วน `try` / `catch` (บทที่ 17) เป็นอีกทาง เมื่อการโยนเหมาะกว่า

## บทที่ 23. defer: เก็บกวาดทุกทางออก

`defer ประโยค;` ทำงานเมื่อออกจากบล็อก ไม่ว่าจะออกทางไหน: ถึงตอนจบ, `return`, `break`, `continue` หรือเมื่อ error ผ่านมา `defer` ตัวสุดท้ายทำงานก่อน เหมาะกับ `close`, `free`, `unlock`: เขียนไว้ติดกับสิ่งที่มันยกเลิก จึงไม่ลืมในทางใดทางหนึ่ง

```jk
#import <stdlib>
using stdlib;

void work(int n) {
    defer cout << "leaving work(" << n << ")\n";
    if n > 5 {
        cout << "big\n";
        return;
    }
    cout << "small\n";
}

void main() {
    work(3);
    work(9);
    for i in 0..2 {
        defer cout << "end of round " << i << "\n";
        cout << "round " << i << "\n";
    }
    defer cout << "first defer\n";
    defer cout << "second defer\n";
    cout << "main body\n";
}
```

ผลลัพธ์:

```
small
leaving work(3)
big
leaving work(9)
round 0
end of round 0
round 1
end of round 1
main body
second defer
first defer
```

`work(9)` return กลางทางแต่ข้อความยังออก ใน loop `defer` ทำงานเมื่อจบทุกรอบ ประโยคที่ defer เองจะ `return`, `break` หรือ `continue` ไม่ได้

## บทที่ 24. ตัวดำเนินการสำหรับชนิดของคุณเอง

struct บอกได้ว่าเมธอดไหนถูกเรียกโดยตัวดำเนินการ: เขียน `operator` หน้าเมธอด `+` เรียก `add`, `-` เรียก `sub`, `*` เรียก `mul`, `/` เรียก `div`, `==` และ `!=` เรียก `eq`, `-v` เรียก `neg` แล้ว `a + b * 2` อ่านเหมือนเลขคณิต และเวกเตอร์ เมทริกซ์ จำนวนเชิงซ้อนในไลบรารีคณิตศาสตร์ก็ทำแบบเดียวกัน

```jk
#import <stdlib>
using stdlib;

struct Money {
    int cents;
    operator Money add(self, Money o) { Money r = {self.cents + o.cents}; return r; }
    operator Money mul(self, int k) { Money r = {self.cents * k}; return r; }
    operator bool eq(self, Money o) { return self.cents == o.cents; }
}

void main() {
    Money a = {250};
    Money b = a + a * 3;
    Money c = 2 * a;
    cout << b.cents << " " << c.cents << " " << (a + a == c) << "\n";
}
```

ผลลัพธ์:

```
1000 500 true
```

`a + a * 3` คือ `a.add(a.mul(3))`: 250 + 750 = 1000 ส่วน `2 * a` (ตัวเลขอยู่ซ้ายของ `*`) เท่ากับ `a.mul(2)` เมธอดที่ไม่มีคำ `operator` ไม่ถูกเรียกโดยตัวดำเนินการ จึงไม่มีอะไรเกิดขึ้นลับหลัง

## บทที่ 25. วันที่ เวลา และเลขสุ่ม

`Date` คือวันและเวลาในปฏิทิน (UTC): `set_unix(วินาที)` ใส่ค่าจากวินาทีนับจากปี 1970, `text()` เขียนออกมา, `add_days` เลื่อนวัน, `weekday()` 0 คืออาทิตย์ `Time::mono_ns()` คือนาฬิกาที่เดินหน้าอย่างเดียว (สำหรับวัดเวลา) และ `Time::sleep_ms` รอ `Random::seed` เริ่มเลขสุ่ม `Random::range(1, 7)` ให้ 1 ถึง 6

```jk
#import <stdlib>
using stdlib;

void main() {
    Date d;
    d.set_unix(86400 * 365);
    cout << d.text() << " weekday " << d.weekday() << "\n";
    d.add_days(60);
    cout << d.text() << " day of year " << d.day_of_year() << "\n";
    cout << Date::is_leap(2024) << " " << Date::days_in_month(2024, 2) << "\n";
    Random::seed(42);
    int r = Random::range(1, 7);
    cout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    int t0 = Time::mono_ns();
    Time::sleep_ms(20);
    cout << (Time::mono_ns() - t0 >= 20000000) << "\n";
}
```

ผลลัพธ์:

```
1971-01-01 00:00:00 weekday 5
1971-03-02 00:00:00 day of year 61
true 29
true true
true
```

หนึ่งปีหลัง 1970-01-01 คือ 1971-01-01 วันศุกร์ (5) ปี 2024 เป็นปีอธิกสุรทิน กุมภาพันธ์จึงมี 29 วัน seed เดียวกันให้เลขสุ่มชุดเดิมเสมอ โปรแกรมที่ใช้เลขสุ่มจึงทดสอบได้

## บทที่ 26. JSON

`Json::parse(text)` อ่าน JSON เป็นเอกสาร เดินดูด้วยเลข node: `doc.root()` คือบนสุด, `doc.get(node, "name")` คือสมาชิกของ object, `doc.at(node, i)` คือสมาชิกของ array, `doc.len(node)` คือจำนวน และ `doc.text`, `doc.number`, `doc.boolean` อ่านค่า `doc.dump(node)` เขียน node กลับเป็นข้อความ JSON และ `Json::quote` สร้างสตริงที่ปลอดภัย

```jk
#import <stdlib>
using stdlib;

void main() {
    String text = "{\"name\": \"J2K\", \"version\": 0.9, \"tags\": [\"fast\", \"small\"], \"ok\": true}";
    JsonDoc doc = Json::parse(text).unwrap();
    int root = doc.root();
    cout << doc.text(doc.get(root, "name")) << " " << doc.number(doc.get(root, "version")) << "\n";
    int tags = doc.get(root, "tags");
    for i in 0..doc.len(tags) { cout << doc.text(doc.at(tags, i)) << " "; }
    cout << doc.boolean(doc.get(root, "ok")) << "\n";
    cout << doc.dump(tags) << "\n";
    cout << Json::quote("say \"hi\"") << "\n";
}
```

ผลลัพธ์:

```
J2K 0.900000
fast small true
["fast","small"]
"say \"hi\""
```

node ที่ไม่มีคือ -1 และให้คำตอบว่าง ชื่อผิดจึงไม่ทำให้โปรแกรมพัง `unwrap()` โยน error ของการ parse เมื่อข้อความไม่ใช่ JSON ถ้าจะจัดการเองให้ใช้ `switch` กับ `Result`

## บทที่ 27. CSV และการจัดรูปแบบตัวเลข

`Csv::split_line` ตัดหนึ่งบรรทัดของค่าที่คั่นด้วยจุลภาคเป็นช่อง (ช่องในเครื่องหมายคำพูดมีจุลภาคได้) และ `Csv::join_line` ทำกลับกัน `Fmt` เขียนตัวเลขแบบที่คนอ่าน: `fixed` (ทศนิยม), `pad_left`, `thousands`, `hex`, `bin`, `percent`, `bytes`

```jk
#import <stdlib>
using stdlib;

void main() {
    String[] f = Csv::split_line("Ann,\"Lee, Jr\",30");
    cout << f.len << ": " << f[0] << " | " << f[1] << " | " << f[2] << "\n";
    cout << Csv::join_line(f) << "\n";
    cout << Fmt::fixed(3.14159, 2) << " " << Fmt::pad_left("7", 3, '0') << " " << Fmt::thousands(1234567) << "\n";
    cout << Fmt::hex(255) << " " << Fmt::bin(5) << " " << Fmt::percent(0.256, 1) << " " << Fmt::bytes(1536) << "\n";
}
```

ผลลัพธ์:

```
3: Ann | Lee, Jr | 30
Ann,"Lee, Jr",30
3.14 007 1,234,567
ff 101 25.6% 1.5 KB
```

ช่อง `Lee, Jr` ยังมีจุลภาคอยู่ และ `join_line` ใส่เครื่องหมายคำพูดคืนเพราะช่องนั้นต้องใช้ `Fmt::bytes(1536)` คือ `1.5 KB`

## บทที่ 28. แพตเทิร์น แฮช และการเข้ารหัส

`Regex` เป็นตัวจับแพตเทิร์นขนาดเล็ก: `matches` (ทั้งข้อความ), `find` (ตำแหน่งที่เจอครั้งแรก หรือ -1), `find_text` (ข้อความที่เจอ) `Sha256::hex` คือแฮช SHA-256 ของข้อความ (และ `Sha256::file` ของไฟล์), `Hex::encode` เขียนไบต์เป็นเลขฐานสิบหกสองหลักต่อไบต์ และ `Base64` เป็นรูปแบบข้อความที่อีเมลและเว็บใช้แทนไบต์

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find("[0-9]+", "room 42, floor 7") << " " << Regex::find_text("[0-9]+", "room 42, floor 7") << "\n";
    cout << Sha256::hex("abc") << "\n";
    cout << Hex::encode("Hi") << " " << Base64::encode("Man") << " " << Base64::decode("TWFu").unwrap() << "\n";
}
```

ผลลัพธ์:

```
true 5 42
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
4869 TWFu Man
```

แฮชของ `abc` เป็นค่าทดสอบที่รู้จักกันดีของ SHA-256 (`ba7816bf...`) `Base64::decode` ให้ `Result` เพราะข้อความอาจไม่ถูกต้อง

## บทที่ 29. path โปรแกรมอื่น และ log

`Path::join` สร้าง path ด้วยตัวคั่นที่ถูกต้อง `Proc::output(โปรแกรม, args)` รันโปรแกรมอื่นและให้สิ่งที่มันเขียน ส่วน `Proc::run` ให้ exit code `Env::args()` คือรายการอาร์กิวเมนต์ของโปรแกรมเอง (ตัวแรกคือชื่อ) `Log` เขียนข้อความไปที่ standard error พร้อมระดับ: `Log::set_level(2)` ซ่อนข้อความ `info` และเก็บ error ไว้

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << Path::join("dir", "file.txt") << "\n";
    String[] args = arr(0);
    args.push("hello from a child");
    String out = Proc::output("echo", args).unwrap();
    cout << out;
    cout << Env::args().len << "\n";
    Log::set_level(2);
    Log::info("not shown");
    Log::error("shown on the standard error");
}
```

ผลลัพธ์:

```
dir/file.txt
hello from a child
1
```

`String[] args = arr(0);` สร้างลิสต์ String ว่างและ `push` เพิ่มเข้าไป บรรทัด log ไปที่ standard error จึงไม่อยู่ในผลลัพธ์ข้างบน รันโปรแกรมใน terminal เพื่อดูทั้งสองอย่าง

# ภาคที่ 2: ลงไปหาเครื่อง

## บทที่ 30. บิตและไบต์

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

## บทที่ 31. เลขที่กว้างกว่า 64 บิต

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

## บทที่ 32. ดูโค้ดที่คอมไพเลอร์สร้าง

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
L8491:
ret
// 3 instructions
```

รัน `jcmp showcode.jk -show scale` เพื่อดูบรรทัดข้างบน (เป็นโค้ดของ target ARM64 ส่วน target อื่นคำสั่งจะต่างออกไป)

## บทที่ 33. คุมโค้ดให้สั้น: #expect

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

## บทที่ 34. เธรดและคำสั่ง atomic

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

## บทที่ 35. Register: บล็อก register

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

## บทที่ 36. ฟังก์ชันเปลือย: naked และ svc

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

## บทที่ 37. ธงของ CPU

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

## บทที่ 38. คำสั่งเครื่องที่เขียนเอง

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

# ภาคที่ 3: ถึงกระดูก

## บทที่ 39. ที่อยู่และไบต์

ตัวแปรอยู่ที่ที่อยู่หนึ่ง `@x` คือที่อยู่นั้นและพอยน์เตอร์เก็บมันไว้ `char^` มองหน่วยความจำทีละไบต์ จึงเห็นได้ว่า `int` ถูกเก็บอย่างไร: CPU เป็น little-endian ไบต์ต่ำสุดมาก่อน พอยน์เตอร์ในอาร์เรย์เดียวกันห่างกันเท่าขนาดของสมาชิก `(int)q - (int)p` คือระยะเป็นไบต์

```jk
#import <stdlib>
using stdlib;

void main() {
    int x = 0x0102030405060708;
    char^ b = (char^)@x;
    for i in 0..8 { cout << (b[i] & 255) << " "; }
    cout << "\n";
    int a[4];
    for i in 0..4 { a[i] = i * 10; }
    int^ p = @a[0];
    int^ q = @a[3];
    cout << ((int)q - (int)p) << " " << (p == @a[0]) << " " << (q^) << "\n";
    cout << sizeof(int) << " " << sizeof(char) << "\n";
}
```

ผลลัพธ์:

```
8 7 6 5 4 3 2 1 
24 true 30
8 1
```

`0x0102030405060708` ถูกเก็บเป็น `08 07 ... 01` `int` สี่ตัวคือ 32 ไบต์ `a[3]` จึงอยู่หลัง `a[0]` 24 ไบต์ ถ้าพิมพ์ที่อยู่ของตัวแปร (`cout << p;`) จะได้ `0x...` ที่นี่พิมพ์ระยะแทนเพราะที่อยู่เปลี่ยนทุกครั้งที่รัน

## บทที่ 40. คุยกับ kernel โดยตรง

โปรแกรมทำอะไรเองไม่ได้: การเขียน หน่วยความจำ และเลข process มาจาก kernel ผ่าน system call `Sys::` เป็นชั้นบางๆ ครอบมัน: `Sys::write(ไฟล์, บัฟเฟอร์, จำนวนไบต์)`, `Sys::getpid()`, `Sys::mmap(ไบต์)` (หน่วยความจำก้อนใหม่จากระบบ ฐานของ allocator ทุกตัว) และ `Sys::munmap` ไม่มีโค้ดไลบรารีคั่นกลาง หนึ่งการเรียกคือคำสั่ง `svc` หนึ่งคำสั่ง

```jk
#import <stdlib>
using stdlib;

void main() {
    char msg[8];
    msg[0] = 'h'; msg[1] = 'i'; msg[2] = '\n';
    Sys::write(1, @msg, 3);
    int pid = Sys::getpid();
    cout << (pid > 0) << "\n";
    void^ page = Sys::mmap(4096);
    int^ words = (int^)page;
    for i in 0..512 { words[i] = i * i; }
    cout << words[511] << "\n";
    Sys::munmap(page, 4096);
}
```

ผลลัพธ์:

```
hi
true
261121
```

`mmap` ให้หน้าเต็ม (4096 ไบต์) ที่เป็นศูนย์ตอนเริ่ม ตัว `cout` เองก็จบที่ `Sys::write` ถ้าต้องการ call ที่ไลบรารีไม่มีชื่อให้ ใช้ `Sys::call(เลข, a0 ... a5)` และ `svc` ในบทที่ 36

## บทที่ 41. allocator ของคุณเอง

allocator ที่เร็วที่สุดคือตัวชี้ที่เดินหน้าอย่างเดียว (bump allocator): ขอก้อน บวกขนาดเข้า `top` เสร็จ ไม่มี `free` ของวัตถุเดียว คืนทั้งก้อนทีเดียว นี่คือสิ่งที่ arena ทำ และเป็นเหตุผลที่คอมไพเลอร์กับเกมใช้มัน ก้อนมาจาก `mmap`

```jk
#import <stdlib>
using stdlib;

int^ heap;
int top;

int^ bump(int n) {
    int^ p = @heap[top];
    top += n;
    return p;
}

void main() {
    heap = (int^)Sys::mmap(65536);
    int^ a = bump(4);
    int^ b = bump(4);
    for i in 0..4 { a[i] = i; b[i] = i * 100; }
    cout << a[3] + b[3] << " " << top << " " << ((int)b - (int)a) << "\n";
    Sys::munmap(heap, 65536);
}
```

ผลลัพธ์:

```
303 8 32
```

สองก้อนอยู่ติดกัน: `b` อยู่หลัง `a` 32 ไบต์ และ `top` นับ `int` ได้ 8 ตัว ไลบรารีมาตรฐานมีสิ่งนี้พร้อมใช้ในชื่อ `Arena` การเขียนเองสักครั้งทำให้เห็นว่า allocator ไม่มีเวทมนตร์

## บทที่ 42. spinlock

บทที่ 34 ใช้ `Atomic::add` ถ้างานใหญ่กว่านั้น (หลายประโยคที่ห้ามปนกัน) ต้องมี lock spinlock คือ `int` ตัวเดียว: 0 คือว่าง 1 คือถูกจอง `Atomic::cas(@lock, 0, 1)` เปลี่ยนเป็น 1 เฉพาะเมื่อเดิมเป็น 0 และคืนค่าเก่า จึงมีเธรดเดียวที่ชนะ ที่เหลือวนรอ `Cpu::pause()` บอก CPU ว่านี่คือ loop รอ (ประหยัดไฟและช่วย hyper-thread อื่น)

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int lock;
int counter;

void work(void^ arg) {
    for i in 0..10000 {
        while Atomic::cas(@lock, 0, 1) != 0 { Cpu::pause(); }
        counter += 1;
        Atomic::store(@lock, 0);
    }
}

void main() {
    Thread a = create(work, null);
    Thread b = create(work, null);
    a.join();
    b.join();
    cout << counter << "\n";
}
```

ผลลัพธ์:

```
20000
```

`counter += 1` ปลอดภัยแล้วทั้งที่มีสามขั้น เพราะมีเฉพาะเธรดที่ถือ lock รัน `Atomic::store` ปล่อย lock พร้อมลำดับหน่วยความจำที่ถูกต้อง เธรดถัดไปจึงเห็น `counter` ใหม่ spinlock เหมาะกับงานสั้นมาก ถ้ารอนานให้ใช้ lock ที่หลับได้

## บทที่ 43. นับนาฬิกาของ CPU

`Cpu::counter()` อ่านตัวนับของระบบใน CPU (ไม่มี system call ใช้ไม่กี่รอบ) และ `Cpu::frequency()` บอกว่ากี่ tick เป็นหนึ่งวินาที มันคือนาฬิกาจับเวลาที่แม่นที่สุดที่คุณมี การวัดโค้ด: อ่าน รัน อ่าน ลบ `Bit::popcount` คือคำสั่งเดียวของ CPU ล้านครั้งจึงเร็ว

```jk
#import <stdlib>
using stdlib;

void main() {
    int start = Cpu::counter();
    int sum = 0;
    for i in 0..1000000 { sum += Bit::popcount(i); }
    int ticks = Cpu::counter() - start;
    cout << sum << " " << (ticks > 0) << " " << (Cpu::frequency() > 0) << "\n";
}
```

ผลลัพธ์:

```
9884992 true true
```

ผลรวมคงที่ เวลาไม่คงที่ โปรแกรมจึงพิมพ์แค่ว่าวัดเวลาได้ วัดมากกว่าหนึ่งครั้ง: รอบแรกอุ่น cache `#expect instructions <= N` (บทที่ 33) คุมขนาด ตัวนับนี้คุมเวลา

## บทที่ 44. เวกเตอร์ในฮาร์ดแวร์

กราฟิกและฟิสิกส์ทำงานกับตัวเลขเป็นกลุ่ม `vec3` คือ `double` สามตัวที่มีตัวดำเนินการ `+ - *` และเลือกส่วนด้วยตัวอักษร (`c.zyx` คือเลขสามตัวเดิมเรียงกลับ) ถ้าต้องการหลายตัวพร้อมกัน CPU มี register SIMD (NEON บน ARM): คอมไพเลอร์แปลง loop บนอาร์เรย์เป็นคำสั่งเวกเตอร์เอง และ `#import <simd>` ให้ชื่อ lane

```jk
#import <stdlib>
using stdlib;
#import <math>
using math::vector;

void main() {
    vec3 a = {1.0, 2.0, 3.0};
    vec3 b = {4.0, 5.0, 6.0};
    vec3 c = a + b * 2.0;
    cout << c.x << " " << c.y << " " << c.z << "\n";
    cout << c.zyx.x << "\n";
}
```

ผลลัพธ์:

```
9.000000 12.000000 15.000000
15.000000
```

`a + b * 2.0` คือ `(1,2,3) + (8,10,12)` ใช้ `jcmp file.jk -show ชื่อ` (บทที่ 32) กับ loop บนอาร์เรย์ `double` เพื่อดูคำสั่งเวกเตอร์

## บทที่ 45. สองงาน สองสแตก: การสลับ context

thread คือวิธีของ kernel ที่ให้ทำสองอย่างพร้อมกัน ถ้าไม่ใช้ kernel ก็ยังทำสองงานที่ผลัดกันทำได้ ถ้าแต่ละงานมีสแตกของตัวเอง งานหนึ่งก็คือ register ของมัน: `x19` ถึง `x30` และตัวชี้สแตก `sp` `frame Context { x19..x30; sp; }` ตั้งชื่อให้ระเบียน 13 คำนั้น `Context::save(x0)` เขียน register ลงระเบียนที่ `x0` ส่วน `Context::restore(x1)` โหลดกลับจากระเบียนที่ `x1` หลัง `restore` คำสั่ง `ret` จะไปที่ `x30` ที่เก็บไว้ คือเข้าไปในอีกงานหนึ่ง

```jk
#import <stdlib>
using stdlib;

frame Context { x19..x30; sp; }

naked void ctx_save(int^ c) {
    Context::save(x0);
    ret;
}

naked void ctx_switch(int^ from, int^ to) {
    Context::save(x0);
    Context::restore(x1);
    ret;
}

int main_ctx[16];
int task_ctx[16];
char task_stack[16384];
int value;

void squares() {
    int n = 1;
    while true {
        value = n * n;
        n += 1;
        ctx_switch(@task_ctx, @main_ctx);
    }
}

void main() {
    ctx_save(@task_ctx);
    task_ctx[10] = 0;
    task_ctx[11] = (int)squares;
    task_ctx[12] = ((int)@task_stack + 16000) & (0 - 16);
    for k in 0..6 {
        ctx_switch(@main_ctx, @task_ctx);
        cout << value << " ";
    }
    cout << "\n";
}
```

ผลลัพธ์:

```
1 4 9 16 25 36 
```

ครั้งแรกยังไม่มีสถานะที่เก็บไว้ `main` จึงสร้างให้: เก็บ register ของตัวเองลง `task_ctx` เป็นจุดเริ่ม แล้วแก้สามคำ: คำที่ 10 (`x29` ตัวชี้เฟรม) เป็น 0, คำที่ 11 (`x30` ที่ที่ switch จะกลับไป) เป็นฟังก์ชัน `squares` และคำที่ 12 (`sp`) เป็นปลายของหน่วยความจำก้อนหนึ่งที่ใช้เป็นสแตก จัดแนว 16 `squares` ไม่เคย return: มันเขียนค่าแล้ว switch กลับ และทุกครั้งที่ `main` switch มา มันก็ทำต่อจากตำแหน่ง switch ครั้งก่อน นี่คือวิธีสร้าง coroutine, green thread และ generator ใช้ได้กับ ARM64 เท่านั้นเพราะ register ที่เก็บเป็นของ ARM64

## บทที่ 46. คิวที่ไม่มี lock

spinlock ทำให้ thread รอกัน ring buffer ที่มีผู้เขียนหนึ่งและผู้อ่านหนึ่งไม่ต้องมี lock เลย: ผู้เขียนเป็นเจ้าของ `head` (เขียนไปกี่ตัว) ผู้อ่านเป็นเจ้าของ `tail` (อ่านไปกี่ตัว) และแต่ละฝ่ายอ่านเลขของอีกฝ่ายเท่านั้น `Atomic::load` และ `Atomic::store` คือการโหลดและเก็บพร้อมลำดับหน่วยความจำที่ทำให้ถูกต้อง: สิ่งที่ผู้เขียนใส่ลงในวงก่อน `Atomic::store(@head, ...)` ผู้อ่านที่เห็น `head` ใหม่จะเห็นด้วย

```jk
#import <stdlib>
using stdlib;

#import <cpu>
using cpu::thread;

int ring[64];
int head;
int tail;
int total;

void producer(void^ arg) {
    for i in 1..1001 {
        while Atomic::load(@head) - Atomic::load(@tail) >= 64 { Cpu::pause(); }
        int h = Atomic::load(@head);
        ring[h % 64] = i;
        Atomic::store(@head, h + 1);
    }
}

void consumer(void^ arg) {
    int got = 0;
    while got < 1000 {
        int t = Atomic::load(@tail);
        while Atomic::load(@head) == t { Cpu::pause(); }
        total += ring[t % 64];
        Atomic::store(@tail, t + 1);
        got += 1;
    }
}

void main() {
    Thread a = create(producer, null);
    Thread b = create(consumer, null);
    a.join();
    b.join();
    cout << total << "\n";
}
```

ผลลัพธ์:

```
500500
```

ผลรวม 1 ถึง 1000 เท่ากับ 500500 ทุกครั้ง (รันติดกัน 60 ครั้งเพื่อความมั่นใจ) ถ้าวงเต็มผู้เขียนรอ ถ้าว่างผู้อ่านรอ และ `Cpu::pause()` ทำให้การรอเบาต่อ CPU ใช้ได้กับผู้เขียนหนึ่งและผู้อ่านหนึ่งเท่านั้น ถ้ามีผู้เขียนสองตัวจะเขียน `head` ตัวเดียวกัน ต้องใช้ `Atomic::cas` (บท spinlock)

## บทที่ 47. ฟังก์ชันทั้งตัวเป็นคำสั่งดิบ

ในฟังก์ชัน `naked` คอมไพเลอร์ไม่เติมอะไรเลย: คุณเขียนคำสั่งเครื่องเอง หนึ่งประโยคคือหนึ่งคำสั่ง ใช้ register `x0` ถึง `x30` ตามชื่อ `x2 = x2 + x3;` คือ `add x2, x2, x3`, `x3 = [x0 + 0];` คือโหลดจากหน่วยความจำ, `if x1 == 0 goto done;` เปรียบเทียบแล้วกระโดด, `ชื่อ:` คือ label, `goto`, `ret` อาร์กิวเมนต์มาใน `x0`, `x1`, ... และผลลัพธ์ส่งกลับใน `x0` นี่คือ loop ของ `sum_words` ลูปเดียวกับที่คอมไพเลอร์สร้างให้ แต่เขียนด้วยมือ

```jk
#import <stdlib>
using stdlib;

naked int sum_words(int^ p, int n) {
    x2 = 0;
loop:
    if x1 == 0 goto done;
    x3 = [x0 + 0];
    x2 = x2 + x3;
    x0 = x0 + 8;
    x1 = x1 - 1;
    goto loop;
done:
    x0 = x2;
    ret;
}

void main() {
    int a[5] = {10, 20, 30, 40, 5};
    cout << sum_words(@a, 5) << "\n";
    cout << sum_words(@a, 0) << "\n";
}
```

ผลลัพธ์:

```
105
0
```

`x0` เดินไปตามอาร์เรย์ทีละ 8 ไบต์ (หนึ่ง `int`), `x1` นับถอยหลัง, `x2` คือผลรวม เมื่อ `x1` เป็น 0 จะกระโดดไป `done` เพราะไม่มีเฟรม จึงไม่มี register ที่ถูกเซฟให้: ฟังก์ชัน naked ใช้ `x0` ถึง `x17` ได้เลย ถ้าจะใช้ `x19` ขึ้นไปต้องเซฟเอง

## บทที่ 48. คำสั่งใดๆ ของ CPU ตามชื่อ

`Cpu::inst("ชื่อ", ตัวถูกดำเนินการ ...)` ใส่คำสั่งใดๆ ที่ assembler รู้จัก โดยใช้ register เป็นตัวถูกดำเนินการ CPU จึงทำในคำสั่งเดียวสิ่งที่ภาษาไม่มีตัวดำเนินการให้: `umulh` คือ 64 บิตบนของผลคูณ 128 บิต, `rbit` กลับทั้ง 64 บิต, `rev` กลับ 8 ไบต์

```jk
#import <stdlib>
using stdlib;

naked int mulhi(int a, int b) {
    Cpu::inst("umulh", x0, x0, x1);
    ret;
}

naked int reverse_bits(int a) {
    Cpu::inst("rbit", x0, x0);
    ret;
}

naked int swap_bytes(int a) {
    Cpu::inst("rev", x0, x0);
    ret;
}

void main() {
    cout << mulhi(0x8000000000000000, 6) << " " << mulhi(100, 100) << "\n";
    cout << reverse_bits(1) << " " << reverse_bits(6) << "\n";
    cout << swap_bytes(1) << " " << swap_bytes(0x0102030405060708) << "\n";
}
```

ผลลัพธ์:

```
3 0
-9223372036854775808 6917529027641081856
72057594037927936 578437695752307201
```

`0x8000000000000000 * 6` คือ 3 คูณ 2^64 ครึ่งบนจึงเป็น 3 `rbit(1)` ย้ายบิตล่างสุดไปบนสุด (ตัวเลขที่เห็นติดลบเพราะบิต 63 คือเครื่องหมาย) `rev(1)` คือ 1 ตามด้วยบิต 0 อีก 56 ตัว ชื่อคำสั่งมาจากคู่มือ ARM64; `jcmp file.jk -show ชื่อ` แสดงสิ่งที่สร้าง ชื่อที่ assembler ไม่รู้จักทำให้คอมไพเลอร์หยุดพร้อมข้อความ และ `raw<u32>[...]` (บทที่ 38) เขียนคำสั่งเครื่องเองได้

# ภาคที่ 4: ภาษาเพิ่มเติม

## บทที่ 49. ชื่อเป็นชั้น: โมดูลและ using

ฟังก์ชันของไลบรารีมีชื่อสามชั้น: `Fs::fs.write(...)` คือ namespace `Fs` โมดูล `fs` และฟังก์ชัน `write` `using Fs;` ตัด namespace ออก เขียน `fs.write(...)` ได้เลย และ `using Str::str.len;` ทำให้ฟังก์ชันเดียวใช้ชื่อสั้นได้ รูปยาวใช้ได้เสมอ จึงใช้ปนกันได้ ไฟล์ของคุณเองนำเข้าด้วย `#import "ชื่อ"` (บทที่ 20) และไลบรารีด้วย `#import <ชื่อ>`

```jk
#import <stdlib>
using stdlib;
using Fs;
using Str::str.len;

void main() {
    fs.write("tl_demo.txt", "hello modules\n");
    String text = fs.read("tl_demo.txt");
    cout << text;
    cout << Fs::fs.size("tl_demo.txt") << " " << Str::str.len("abc") << "\n";
    Fs::fs.remove("tl_demo.txt");
}
```

ผลลัพธ์:

```
hello modules
14 3
```

ชื่อสั้นทำให้โปรแกรมอ่านเหมือนสคริปต์ ชื่อยาวบอกว่าฟังก์ชันมาจากไหน ถ้ามีสองโมดูลที่ใช้อยู่ชื่อสั้นซ้ำกัน คอมไพเลอร์จะให้เขียนรูปยาว จึงไม่มีการเลือกโดยบังเอิญ

## บทที่ 50. enum ที่เก็บค่า

สมาชิกของ `enum class` เก็บค่าได้: `Circle(double r)`, `Rect(double w, double h)`, `Empty` ค่าของ enum คือสิ่งเดียวที่เป็นสมาชิกต่างกันในเวลาต่างกัน `switch` แกะมันออกและตั้งชื่อให้ค่า (`_` ข้ามค่าหนึ่ง) เมธอดเขียนหลังสมาชิกต่อจาก `;` และ `switch self^` ดูตัววัตถุเอง

```jk
#import <stdlib>

using stdlib;
enum class Color { Red, Green, Blue };

enum class Shape { Circle(double r), Rect(double w, double h), Empty;
    double area(self) {
        switch self^ {
            Shape::Circle(r): return 3.0 * r * r;
            Shape::Rect(w, h): return w * h;
            Shape::Empty: return 0.0;
        }
        return 0.0;
    }
};

void main() {
    Color c = Color::Green;
    switch c {
        Color::Red: cout << "red\n";
        Color::Green: cout << "green\n";
        Color::Blue: cout << "blue\n";
    }
    Shape a = Shape::Circle(2.0);
    Shape b = Shape::Rect(3.0, 4.5);
    Shape e = Shape::Empty;
    cout << a.area() << " " << b.area() << " " << e.area() << "\n";
    switch b {
        Shape::Rect(w, _): cout << "width " << w << "\n";
        _: cout << "something else\n";
    }
}
```

ผลลัพธ์:

```
green
12.000000 13.500000 0.000000
width 3.000000
```

`switch` ตรวจว่าจัดการทุกสมาชิกแล้ว เว้นแต่มี `_` เมื่อเพิ่มสมาชิกใหม่ จึงเห็นทุกจุดที่ต้องแก้ นี่คือเครื่องมือของสิ่งที่มีหลายรูป: token ข้อความ ผลลัพธ์

## บทที่ 51. struct: เมธอด ซ้อน และอาร์เรย์

`struct` รวมค่าและมีเมธอดได้ `self` คือตัววัตถุ struct ซ้อนกันได้ (`Line` เก็บ `Point` สองตัว เขียน `{{...}, {...}}`) ถูกคัดลอกเมื่อกำหนดค่า อาร์เรย์ของมันอ้างด้วยดัชนีเหมือนอาร์เรย์ทั่วไป และ `@p` คือพอยน์เตอร์ไปที่มัน (`q^.x` เข้าถึงสมาชิกผ่านพอยน์เตอร์)

```jk
#import <stdlib>

using stdlib;
struct Point {
    double x;
    double y;
    double dist2(self) { return self.x * self.x + self.y * self.y; }
    void move(self, double dx, double dy) { self.x += dx; self.y += dy; }
}

struct Line {
    Point a;
    Point b;
}

void main() {
    Point p = {3.0, 4.0};
    p.move(1.0, 0.0);
    cout << p.x << " " << p.dist2() << "\n";
    Line l = {{0.0, 0.0}, {6.0, 8.0}};
    cout << l.b.dist2() << "\n";
    Point pts[3];
    for i in 0..3 { pts[i].x = (double)(i + 1); pts[i].y = (double)(i + 1); }
    double total = 0.0;
    for i in 0..3 { total += pts[i].dist2(); }
    cout << total << "\n";
    Point^ q = @p;
    q^.x = 10.0;
    cout << p.x << "\n";
}
```

ผลลัพธ์:

```
4.000000 32.000000
100.000000
28.000000
10.000000
```

`p.move(1.0, 0.0)` เปลี่ยน `p` เพราะ `self` คือตัววัตถุจริง ไม่ใช่สำเนา อาร์เรย์ของ struct ตรงนี้กรอกทีละสมาชิก การเขียน `pts[3] = {{...}}` ยังไม่รองรับ

## บทที่ 52. ค่าที่คืนหน่วยความจำเอง

struct ที่มีเมธอด `free(self)` จะคืนสิ่งที่ถืออยู่เมื่อจบบล็อกของตัวแปร เพราะอย่างนั้นมันจึง **ย้าย** ไม่ได้คัดลอก: `Buffer b = a;` ทำให้ `a` ว่างและ `b` เป็นเจ้าของหน่วยความจำ ส่งเข้าฟังก์ชันแบบค่าก็ย้ายเข้าไป และฟังก์ชันคืนเมื่อจบ คุณเขียน `free` ครั้งเดียวและไม่ต้องเรียกเอง

```jk
#import <stdlib>

using stdlib;
struct Buffer {
    int^ data;
    int n;
    void free(self) {
        if self.data != null { cout << "freeing " << self.n << "\n"; free[self.data]; }
    }
}

Buffer make(int n) {
    alloc[int^ p = n];
    Buffer b = {p, n};
    return b;
}

void use(Buffer b) {
    cout << "using " << b.n << "\n";
}

void main() {
    Buffer a = make(4);
    Buffer b = a;
    use(b);
    cout << "end of main\n";
}
```

ผลลัพธ์:

```
using 4
freeing 4
end of main
```

"freeing 4" พิมพ์ครั้งเดียว โดย `use` เมื่อพารามิเตอร์จบ ก่อน "end of main": buffer ถูกย้ายจาก `a` ไป `b` ไปยังพารามิเตอร์ ไม่มี free ซ้ำ ไม่รั่ว และไม่มี garbage collector String อาร์เรย์ และลิสต์สร้างด้วยวิธีเดียวกัน

## บทที่ 53. พอยน์เตอร์ฟังก์ชันและ lambda

ฟังก์ชันเป็นค่าได้: `int(int)^ op = twice;` คือพอยน์เตอร์ไปยังฟังก์ชันที่รับ `int` และให้ `int` ส่งให้ฟังก์ชันอื่นได้ (`apply`) และเรียกเหมือนฟังก์ชัน lambda คือฟังก์ชันไม่มีชื่อ เขียนตรงที่ใช้: ชนิดผลลัพธ์ พารามิเตอร์ และตัวฟังก์ชัน

```jk
#import <stdlib>

using stdlib;
int twice(int x) { return x * 2; }
int square(int x) { return x * x; }

int apply(int(int)^ f, int v) { return f(v); }

void main() {
    int(int)^ op = twice;
    cout << op(5) << " " << apply(square, 7) << "\n";
    int k = 3;
    int(int)^ addk = int(int x) { return x + 100; };
    cout << apply(addk, k) << "\n";
}
```

ผลลัพธ์:

```
10 49
103
```

วิธีนี้ทำให้การเรียงลำดับรับตัวเปรียบเทียบ thread รับงานของมัน และสร้างตารางคำสั่งได้ ชนิดเขียนเหมือนฟังก์ชัน: ผลลัพธ์ แล้วพารามิเตอร์ใน `( )` แล้ว `^`

## บทที่ 54. ตัวเลขทุกขนาด

`int` คือ 64 บิต แต่โปรแกรมสำหรับรูปแบบไฟล์หรือเครื่องจักรต้องการขนาดอื่น: `u8`, `u16`, `u32`, `u64` (ไม่มีเครื่องหมาย) และ `i8`, `i16`, `i32` เมื่อล้นมันวนกลับเหมือนฮาร์ดแวร์ `sizeof(ชนิด)` ให้ขนาดเป็นไบต์ และ `(ชนิด)ค่า` แปลงชนิด

```jk
#import <stdlib>

using stdlib;
void main() {
    u8 b = 250;
    b += 10;
    u32 big = 4000000000;
    big += 500000000;
    i32 small = 2000000000;
    small += 2000000000;
    cout << b << " " << big << " " << small << "\n";
    int wide = 4000000000;
    cout << wide + 500000000 << "\n";
    cout << sizeof(int) << " " << sizeof(u8) << " " << sizeof(double) << " " << sizeof(char) << "\n";
    double d = 3.99;
    int t = (int)d;
    char c = (char)65;
    cout << t << " " << c << " " << (int)'z' << "\n";
}
```

ผลลัพธ์:

```
4 205032704 -294967296
4500000000
8 1 8 1
3 A 122
```

250 + 10 ใน `u8` ได้ 4, 4,000,000,000 + 500,000,000 ใน `u32` ได้ 205,032,704 และสองพันล้านบวกสองพันล้านใน `i32` เป็นลบ ผลบวกเดียวกันใน `int` ไม่วน การแปลง `double` เป็น `int` ตัดทศนิยม (3.99 เป็น 3)

## บทที่ 55. หน่วยความจำดิบ: alloc, pool และ grow

`alloc[int^ p = n];` ขอ `int` จำนวน `n` จาก heap `p` เป็นเจ้าของ และคืนเมื่อจบบล็อก (หรือทันทีด้วย `free[p];`) `grow[p = m];` ขยายก้อนและเก็บเนื้อหาเดิม **pool** คือก้อนใหญ่ที่ตัดเป็นชิ้น: `alloc[pool[12] >> int^ a];` เอา 12 `int` จาก pool ให้ `a` (เป็น null ถ้า pool ไม่พอ) `free[b];` คืนหนึ่งชิ้น `free[pool];` คืนทั้งหมด

```jk
#import <stdlib>
using stdlib;
void main() {
    alloc[int^ pool = 32];
    alloc[pool[12] >> int^ a];
    alloc[pool[12] >> int^ b];
    for i in 0..3 { a[i] = i + 1; b[i] = (i + 1) * 10; }
    cout << a[2] + b[2] << "\n";
    free[b];
    alloc[pool[12] >> int^ c];
    c[0] = 99;
    cout << a[0] << " " << c[0] << "\n";
    free[pool];

    alloc[int^ p = 2];
    p[0] = 5;
    p[1] = 6;
    grow[p = 8];
    p[7] = 70;
    cout << p[1] << " " << p[7] << "\n";
    free[p];
}
```

ผลลัพธ์:

```
33
1 99
6 70
```

pool คือ allocator ในบทที่ 41 (พอยน์เตอร์ที่เดินหน้า) ที่เพิ่มการคืนทีละชิ้น `c` ได้พื้นที่ที่ `b` คืนมา ใช้ pool กับของเล็กๆ จำนวนมากที่เกิดและตายพร้อมกัน และตรวจ null เมื่อ pool อาจไม่พอ build แบบ debug (`jcmp -d`) ตรวจก้อนเหล่านี้ว่าเขียนเกินท้ายหรือใช้หลัง free ไหม

## บทที่ 56. ไบต์ดิบและข้อมูลที่เปลี่ยนไม่ได้

`raw<u32>[0x91008800];` ใส่คำสั่งเครื่องลงในโค้ดตามที่เขียนทุกประการ (ตรงนี้คือ `add x0, x0, #34`) ข้างประโยคปกติของฟังก์ชัน naked `#pragma read` ทำให้ตัวแปร global อ่านอย่างเดียว: การเขียนเป็น error ตอนคอมไพล์ และเขียนผ่านพอยน์เตอร์จะหยุดโปรแกรม เพราะหน้าหน่วยความจำถูกป้องกัน

```jk
#import <stdlib>

using stdlib;
#pragma read
int limit = 100;

#pragma read begin
int table[4] = {10, 20, 30, 40};
#pragma read end

naked int answer() {
    x0 = 0;
    raw<u32>[0x91008800];
    ret;
}

int main() {
    int sum = 0;
    for i in 0..4 { sum += table[i]; }
    cout << sum << " " << limit << " " << answer() << "\n";
    return 0;
}
```

ผลลัพธ์:

```
100 100 34
```

`answer()` คือ 0 บวก 34 ตารางที่ห้ามเปลี่ยน (ตาราง lookup ค่าคงที่ของรูปแบบไฟล์) ควรอยู่ใต้ `#pragma read`: บั๊กที่เขียนทับจะถูกพบทันทีแทนที่จะพบทีหลัง คำสั่งดิบนี้ใช้กับ ARM64 บน ARM32 คำสั่งเดียวกันเป็นอีกคำสั่งหนึ่ง

## บทที่ 57. สร้างโปรเจกต์ด้วย makej

โปรเจกต์ที่มีหลายไฟล์และหลายโปรแกรมสร้างด้วย **makej** (ติดตั้งด้วย `curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp-Tools/main/install.sh | sh -s -- makej`) ไฟล์ build คือไฟล์ธรรมดาชื่อ `makej` ที่คุณเขียนเอง (`nano makej` หรือ `makej init` เขียนตัวเริ่มต้นให้) แต่ละ `[program.ชื่อ]` คือโปรแกรมที่สร้างจากไฟล์ `main` (พร้อม `flags` ที่ให้) แต่ละ `[library.ชื่อ]` คือไลบรารี (`-l`) และแต่ละ `[step.ชื่อ]` คือคำสั่งเชลล์ใดๆ ส่วน `needs` บอกสิ่งที่ต้องทำก่อน นี่คือโปรแกรมแรกของโปรเจกต์ `src/hello.jk`:

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << "hello\n";
}
```

ผลลัพธ์:

```
hello
```

ไฟล์ `makej` ทั้งหมดของโปรเจกต์:

```
[makej]
out = "_out"

[program.hello]
main = "src/hello.jk"

[program.tool]
main = "src/tool.jk"
flags = "-d"

[step.run]
run = "_out/hello && _out/tool"
needs = "hello tool"
```

แล้วในโฟลเดอร์ของโปรเจกต์:

```
$ makej
makej: building hello
makej: building tool
makej: done
$ makej
makej: done
$ makej -v run
makej: hello is up to date
makej: tool is up to date
makej: run
  $ _out/hello && _out/tool
hello
tool
makej: done
```

`makej` ครั้งแรกสร้างทุกอย่าง ครั้งที่สองไม่มีอะไรต้องทำ เพราะโปรแกรมจะสร้างใหม่ก็ต่อเมื่อไฟล์ `.jk` หรือ `.j` ในโฟลเดอร์ของไฟล์ main (และโฟลเดอร์ย่อย) ใหม่กว่าผลลัพธ์ `makej ชื่อ` สร้างเป้าหมายเดียวกับสิ่งที่มันต้องใช้ `-v` แสดงคำสั่ง เป้าหมายที่ไฟล์ main อยู่โฟลเดอร์เดียวกันจะถูกสร้างพร้อมกันเมื่อไฟล์ในนั้นเปลี่ยน ชื่อผิดให้ `makej: there is no target 'nosuch'` และรหัสออก 2

## บทที่ 58. หลายคอร์ และไฟล์ build ที่เป็นโปรแกรม

`makej -j 4` สร้าง 4 อย่างพร้อมกัน (ค่าเริ่มต้นคือจำนวนคอร์ที่เปิดอยู่ เครื่องแบบนี้มี 8) เป้าหมายเริ่มทันทีที่สิ่งที่มันต้องใช้เสร็จ ถ้าตัวหนึ่งล้ม ตัวที่กำลังรันอยู่จะทำจนจบ ไม่เริ่มอะไรใหม่ และรหัสออกเป็น 1 เมื่อการสร้างต้องการ loop หรือเงื่อนไข ให้เขียนไฟล์ build เป็นโปรแกรม J2K ชื่อ `makej.jk` แทน (ชนะไฟล์ธรรมดาถ้ามีทั้งสอง):

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << "a build file is a program\n";
}
```

ผลลัพธ์:

```
a build file is a program
```

นี่คือ `makej.jk` ของโปรเจกต์ที่สร้างโปรแกรมจากทุกไฟล์ในโฟลเดอร์ด้วย loop:

```jk-no
#import <stdlib>
#import <makej>

int main() {
    Build b = Build::make();
    String[] files = Dir::list("tools").unwrap();
    for i in 0..files.len {
        if files[i].ends_with(".jk") {
            b.program(Path::stem(files[i]), "tools/" + files[i], "");
        }
    }
    return b.run();
}
```

`Build::make()` อ่านบรรทัดคำสั่ง (`-j`, `-v`, ชื่อเป้าหมาย) `b.program`, `b.library` และ `b.step` เพิ่มเป้าหมาย `b.needs(a, b)` จัดลำดับ และ `b.run()` สร้างแล้วให้รหัสออก มันเป็นโปรแกรมธรรมดา ทุกอย่างในบทสอนนี้จึงใช้ได้ในนั้น ทั้งไฟล์ธรรมดาและโปรแกรมใช้เครื่องยนต์เดียวกัน

## บทที่ 59. ไลบรารีที่ใช้ร่วมกัน: export และ -l

คอมไพเลอร์ไม่ได้สร้างได้แค่โปรแกรม ด้วย `-l` มันสร้าง **ไลบรารีที่ใช้ร่วมกัน** (`.so`) ที่จุดเข้าคือฟังก์ชันที่ใส่ `export` ไว้ข้างหน้า นี่คือวิธีที่โค้ด J2K กลายเป็น "สมอง" ของแอพ Android หรือตัวช่วยของโปรแกรมอื่น ไฟล์ด้านล่างเป็นโปรแกรมปกติเพื่อให้บทนี้รันได้ โค้ดไลบรารีอยู่ถัดไป

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << "a library has no main; this lesson is a program so that it runs\n";
}
```

ผลลัพธ์:

```
a library has no main; this lesson is a program so that it runs
```

```jk-no
export int add(int a, int b) { return a + b; }
export double half(double x) { return x / 2.0; }

int counter = 10;
export int next() { counter = counter + 1; return counter; }
```

สร้างด้วย  `jcmp mylib.jk -l -o libmy.so`  แล้วโปรแกรมอะไรก็โหลดได้: โปรแกรม C แอพ Android (JNI, `System.loadLibrary`) หรือ python:

```
$ python3 -c "import ctypes; L = ctypes.CDLL('./libmy.so'); print(L.add(2, 3), L.next(), L.next())"
5 11 12
```

ฟังก์ชัน `export` ใช้กฎการเรียกของแพลตฟอร์ม: จำนวนเต็มใน `x0 ..` และ `double` ใน `d0 ..` พารามิเตอร์และผลลัพธ์เป็น `int`, `bool`, `char` และ `double` ได้ (ไม่เกิน 8 พารามิเตอร์) String อาร์เรย์ และ struct ยังข้ามขอบเขตไม่ได้ ไลบรารีมีตัวแปรของตัวเอง (`counter` เริ่มที่ 10 ตอนโหลด) และฮีปของตัวเอง ยังไม่ได้: `cout` ในไลบรารี

## บทที่ 60. สคริปต์ด้วย jsh และการเขียนโค้ดบนมือถือ

คำสั่งของ shell ก็เป็นโปรแกรมเช่นกัน ในบทนี้โปรแกรมเป็นตัวแทนของโปรแกรมที่คุณจะเขียนบนมือถือ ด้านล่างเป็นสคริปต์

```jk
#import <stdlib>
using stdlib;

void main() {
    cout << "write it with coderin, build it with jcmp, run it\n";
}
```

ผลลัพธ์:

```
write it with coderin, build it with jcmp, run it
```

`jsh` ซึ่งเป็น shell ของ Jaric รันสคริปต์ได้ สคริปต์คือไฟล์ข้อความ `jsh script.sh a b` รันมัน (`$1` คือ `a`, `$2` คือ `b`) ส่วนประกอบมีดังนี้:

```jk-no
name=world
echo hello $name                        # ตัวแปร และคอมเมนต์
if [ -f notes.txt ]; then echo found; else echo missing; fi
for f in *.jk; do echo file $f; done    # glob
n=0
while [ $n -lt 3 ]; do n=$((n + 1)); done     # คำนวณ
count=$(dir *.jk | wc -l)               # ผลลัพธ์ของคำสั่ง
hello() { echo hi $1; }                 # ฟังก์ชัน
hello jao
```

เขียนและสร้างบนมือถือ: `coderin hello.jk` (Ctrl-S บันทึก Ctrl-Q ออก) แล้ว `jcmp hello.jk -o hello && ./hello` ใน `makej` การสร้างก็เป็นไฟล์เช่นกัน

## บทที่ 61. ไลบรารีของเครื่อง: `-dyn` และ `<native>`

โปรแกรม J2K ปกติเป็นแบบ *static* คือไฟล์เดียวที่คุยกับเคอร์เนลด้วย system call และไม่ต้องใช้อะไรอีก แต่การ์ดจอใช้ผ่านไลบรารีของเครื่อง (`libvulkan.so`, `libEGL.so`, `libGLESv3.so`, `libOpenCL.so`) โปรแกรมจึงต้องเป็นแบบ *dynamic* คือตัวโหลดของ Android เป็นคนสตาร์ตและให้ `libdl.so` กับ `libc.so` สั่งด้วยตัวเลือกเดียว:

```
jcmp -dyn gpu.jk -o gpu       # โปรแกรม dynamic รันใน Termux และในแอป Jaric ได้ โดยไม่ต้องมีแอปอื่น
```

ไลบรารี `<native>` ทำที่เหลือ: `Native::open("libvulkan.so")` ให้ *handle* (0 ถ้าไม่มีไลบรารี) `Native::sym(handle, "ชื่อ")` ให้ที่อยู่ของฟังก์ชัน `Native::call1 .. call8` เรียกฟังก์ชันด้วยจำนวนเต็มและพอยน์เตอร์ (ได้ค่าที่ฟังก์ชันคืน) หน่วยความจำที่ฟังก์ชัน C เติมอ่านด้วย `Native::peek32`, `peek64`, `peek8` และเขียนด้วย `poke32`, `poke64` ส่วน `Native::text(ที่อยู่)` สร้าง String จากข้อความแบบ C

```jk
#import <stdlib>
#import <native>

int main() {
    int lib = Native::open("libvulkan.so");
    if lib == 0 {
        cout << "no libvulkan here, or the program was not built with jcmp -dyn\n";
        return 1;
    }
    int fn = Native::sym(lib, "vkEnumerateInstanceVersion");   // ฟังก์ชัน: VkResult vkEnumerateInstanceVersion(uint32_t* version)
    char out[16];                                              // ที่ว่างสำหรับเลขที่ฟังก์ชันจะเขียน
    out[0] = 0; out[1] = 0; out[2] = 0; out[3] = 0;
    int result = Native::call1(fn, (int)@out);                 // เรียกด้วยที่อยู่ของ out
    int v = Native::peek32((int)@out);                         // อ่าน 32 บิตที่ฟังก์ชันเขียน
    cout << "Vulkan " << (v >> 22) << "." << ((v >> 12) & 1023) << "\n";
    return 0;
}
```

บนเครื่องของผู้เขียนพิมพ์ `Vulkan 1.1` ถ้าสร้างแบบปกติ (static) จะพิมพ์ข้อความแรก เพราะโปรแกรม static ไม่มี `libdl.so`

หลักการสั้นๆ: ไลบรารีอ่าน `/proc/self/maps` หาว่า `libdl.so` อยู่ที่ไหนในหน่วยความจำ อ่านตารางสัญลักษณ์ของมันและหา `dlopen` กับ `dlsym` แล้วสร้าง function pointer จากเลขนั้นเรียกเหมือนฟังก์ชันทั่วไป ส่วนอาร์กิวเมนต์ทศนิยม (OpenGL ใช้เยอะ) ส่งด้วย `Native::callf1 .. callf4` (ทศนิยมล้วน) และ `Native::calli_f1 .. calli_f4` (ตัวเลขก่อน ตามด้วยทศนิยม) เพราะมาตรฐาน C ต้องการให้อยู่ใน register คนละชุดกับที่ J2K ใช้

## บทที่ 62. OpenGL ES: ภาพแรกที่ชิปวาด

`<opengl3>` สร้าง context OpenGL ES แบบ *นอกจอ* (พื้นผิวขนาดที่ขอ ไม่แสดงบนจอ) บนไดรเวอร์จริง ทุกคำสั่งเหมือนเอกสาร OpenGL ES แต่สะกดแบบ J2K (`glClearColor` คือ `gl.clear_color`)

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(64, 64, 3, 1);                    // 64 x 64 พิกเซล OpenGL ES 3.1 (ใช้ 2, 0 สำหรับ 2.0 แบบเก่า)
    if !gl.ok {
        cout << "no OpenGL here: " << gl.log << "\n";  // gl.log บอกเหตุผล
        return 1;
    }
    cout << "chip: " << gl.renderer << "\n";           // เช่น Mali-G76
    gl.clear_color(1.0, 0.5, 0.0, 1.0);                // แดง เขียว น้ำเงิน โปร่งใส: สีส้ม
    gl.clear_color_buffer();                           // ชิประบายสีทั้งภาพ
    String pixels = gl.read_pixels(10, 10, 1, 1);      // อ่านพิกเซลกลับมาหนึ่งจุด: 4 ไบต์
    cout << (pixels[0] & 255) << " " << (pixels[1] & 255) << " " << (pixels[2] & 255) << "\n";
    gl.close();
    return 0;
}
```

พิมพ์ `255 128 0` (เลขของสีส้ม) `read_pixels` คืนไบต์ แดง เขียว น้ำเงิน โปร่งใส ของแต่ละพิกเซล เริ่มจากแถวล่างสุด (OpenGL นับจากล่างขึ้นบน) การแสดงภาพบนจอของแอป Jaric ส่งพิกเซลด้วยข้อความ `gfx` (ไลบรารี `<gamej>` เป็นตัวอย่าง) หรือใช้ไลบรารี `<gpu>` ที่ส่ง *คำสั่ง* ให้แอปวาดบนจอ

## บทที่ 63. สามเหลี่ยมและเชเดอร์

ชิปรันโปรแกรมเล็กๆ ชื่อ *เชเดอร์* เขียนด้วย GLSL (ภาษาคล้าย C) *vertex shader* วางมุมของสามเหลี่ยม *fragment shader* ให้สีแต่ละพิกเซล `gl.program(vertex, fragment)` คอมไพล์และลิงก์ทั้งสอง คืน 0 และเติม `gl.log` เมื่อเชเดอร์มีที่ผิด (ข้อความของไดรเวอร์บอกบรรทัด)

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(64, 64, 3, 1);
    if !gl.ok { cout << gl.log << "\n"; return 1; }
    String vertex = "#version 300 es\nlayout(location = 0) in vec2 pos;\nvoid main() { gl_Position = vec4(pos, 0.0, 1.0); }\n";
    String fragment = "#version 300 es\nprecision mediump float;\nout vec4 color;\nvoid main() { color = vec4(1.0, 0.5, 0.0, 1.0); }\n";
    int prog = gl.program(vertex, fragment);
    if prog == 0 { cout << "shader: " << gl.log << "\n"; return 1; }
    gl.clear_color(0.0, 0.0, 0.0, 1.0);
    gl.clear_color_buffer();
    gl.use(prog);
    Floats corners = Floats::make(6);                  // สามมุม แต่ละมุม x กับ y ตั้งแต่ -1 ถึง 1
    corners.set(0, -1.0); corners.set(1, -1.0);
    corners.set(2, 1.0);  corners.set(3, -1.0);
    corners.set(4, 0.0);  corners.set(5, 1.0);
    gl.draw_triangles(corners, 3);
    String inside = gl.read_pixels(32, 20, 1, 1);      // พิกเซลในสามเหลี่ยม
    String outside = gl.read_pixels(1, 62, 1, 1);      // พิกเซลมุมซ้ายบน
    cout << (inside[0] & 255) << " " << (outside[0] & 255) << "\n";
    gl.close();
    return 0;
}
```

พิมพ์ `255 0` คือส้มข้างใน ดำข้างนอก `Floats` คือก้อนหน่วยความจำของเลข 32 บิต (สิ่งที่ชิปอ่าน) ใช้ `set(i, x)` และ `get(i)` ขั้นตอนเดียวกันวาดสามเหลี่ยมได้เป็นพัน: ใส่หลายมุมใน `Floats` เดียว ส่งครั้งเดียว วาดครั้งเดียว

## บทที่ 64. ชิปเป็นเครื่องคิดเลข: compute shader

OpenGL ES 3.1 รันเชเดอร์ที่ไม่วาดอะไร มีแต่ *คำนวณ* ให้ก้อนตัวเลข บอกว่าจะเริ่มกี่กลุ่มเธรด แล้วชิปรันโปรแกรมเล็กเดียวกันกับทุกตัวเลขพร้อมกัน (หลายร้อยตัวในเวลาเดียวกัน) `gl.compute(source, data, groups_x, groups_y, groups_z)` ทำทุกขั้นและคืนตัวเลขที่เปลี่ยนแล้ว

```jk
#import <stdlib>
#import <opengl3>

int main() {
    Gl gl = Gl::open(8, 8, 3, 1);
    if !gl.ok { cout << gl.log << "\n"; return 1; }
    // แต่ละเธรดรับเลขหนึ่งตัว: v = v * 2 + 1  local_size_x = 8: หนึ่งกลุ่มมี 8 เธรด
    String shader = "#version 310 es\nlayout(local_size_x = 8) in;\nlayout(std430, binding = 0) buffer Data { float v[]; };\nvoid main() { uint i = gl_GlobalInvocationID.x; v[i] = v[i] * 2.0 + 1.0; }\n";
    Floats data = Floats::make(16);
    for i in 0..16 { data.set(i, (float)i); }
    Floats result = gl.compute(shader, data, 2, 1, 1);   // 2 กลุ่ม x 8 เธรด = 16 ตัวเลข
    if gl.log.len > 0 { cout << "log: " << gl.log << "\n"; }
    cout << result.get(0) << " " << result.get(5) << " " << result.get(15) << "\n";
    gl.close();
    return 0;
}
```

พิมพ์ `1.000000 11.000000 31.000000` ชิปไม่ได้เร็วกว่าสำหรับเลขตัวเดียว แต่ชนะเมื่อมีตัวเลขเยอะมากและทำงานเดียวกันกับทุกตัว: ภาพ ฟิสิกส์ของวัตถุจำนวนมาก เมทริกซ์ ชั้นของโครงข่ายประสาท (`<neuron>` ใช้ได้ภายหลัง)

## บทที่ 65. Vulkan: ถามชิป

Vulkan คืออินเทอร์เฟซสมัยใหม่ ต้องเขียนมากกว่า ควบคุมได้มากกว่า ไดรเวอร์ทำงานน้อยกว่า `<vulkan>` เป็นก้าวแรก: สร้าง *instance* หาชิปและบอกว่าทำอะไรได้ ขั้นอื่น (device, queue, buffer, pipeline) ทำแบบเดียวกัน: โครงสร้างในหน่วยความจำ ฟังก์ชันที่หาจากชื่อ และ `Native::call`

```jk
#import <stdlib>
#import <vulkan>

int main() {
    Vk vk = Vk::open();
    if !vk.ok { cout << vk.log << "\n"; return 1; }
    cout << vk.device_name << ", Vulkan " << vk.api_text() << "\n";
    cout << "memory " << vk.memory_mb << " MB, queues " << vk.queue_families << ", compute " << vk.has_compute << "\n";
    vk.close();
    return 0;
}
```

บนเครื่องของผู้เขียน: `Mali-G76, Vulkan 1.1.97`, 7460 MB, queue family เดียวที่คำนวณได้ สร้างด้วย `jcmp -dyn` โครงสร้างของ Vulkan คือก้อนไบต์ที่มีฟิลด์ในตำแหน่งตายตัว (สเปกบอกออฟเซ็ต) `Native::poke32(address + offset, value)` เขียนหนึ่งฟิลด์ ดูซอร์สของ `<vulkan>` (`jcmp -showlib vulkan`) ว่าเติม `VkApplicationInfo` และ `VkInstanceCreateInfo` อย่างไร

## บทที่ 66. เกม: Jaric Engine

`makej init -game` สร้างโปรเจกต์ที่มีเกมเล็กและบทเรียนห้าบท (`makej play1` .. `play5`) ไลบรารี `<gamej>` คือเอนจิน: ลูปเป็นของคุณ (`while game.running()`) เอนจินให้ปุ่ม การแตะ เวลาของแต่ละรอบ (`g.dt`) การวาด (`clear rect circle line text art`) การชน (`Game::overlap`) และเสียง บนเทอร์มินัลวาดด้วยบล็อกครึ่งช่อง ในแอป Jaric วาดบนพื้นผิวภาพ `makej apk` ทำเป็นแอป Android `makej pack` ทำเป็นแพ็กเกจ `.jc`

```jk
#import <stdlib>
#import <gamej>

int main() {
    Game g = Game::open("Lesson");            // ทั้งจอ
    double x = 20.0;                          // ตำแหน่งของสี่เหลี่ยม
    while g.running() {                       // เป็นเท็จหลังกด Esc
        g.begin();                            // อ่านปุ่ม วัดเวลา (g.dt หน่วยวินาที)
        if g.held(Key::left()) { x -= 40.0 * g.dt; }       // 40 พิกเซลต่อวินาที: ความเร็วเท่ากันทุกเครื่อง
        if g.held(Key::right()) { x += 40.0 * g.dt; }
        g.clear(Game::rgb(10, 20, 40));       // สีของท้องฟ้า
        g.rect((int)x, 30, 6, 6, Game::rgb(255, 200, 60));  // x y กว้าง สูง สี
        g.end();                              // แสดงภาพ รอรอบถัดไป
    }
    g.close();
    return 0;
}
```

ถ้าจะคุยกับชิปเอง ใช้ `<gpu>` ในแอป (สามเหลี่ยม ภาพ สีย้อม: คำสั่งชุดเดียวต่อหนึ่งภาพ) หรือ `<opengl3>` / `<vulkan>` ในโปรแกรม dynamic แผนของเอนจิน (ชั้น ระบบฉากแบบ Godot API แบบ MonoGame) อยู่ในเอกสารของโครงการ Jaric

## ต่อไป

* [LANGUAGE.md](LANGUAGE.md) — ทุกความสามารถพร้อมตัวอย่าง (function pointer, ชนิด unsigned, `sizeof` ฯลฯ)
* [USAGE.md](USAGE.md) — ตัวเลือกของคอมไพเลอร์ (`-d`, `-st`, `-I`, `--emit-asm`)
* โฟลเดอร์ `examples/` ใน repository — โปรแกรมตัวอย่างเพิ่มเติม
