# พื้นฐาน J2K

ชุดบทเรียนสำหรับผู้เริ่มต้น มี 10 บท ตั้งแต่ 0 ถึง 9 ไม่ต้องเคยเขียนโปรแกรมมาก่อน
แต่ละบทมีแนวคิดเดียว โปรแกรมเล็ก ๆ ผลที่พิมพ์ออกมา บรรทัด **Try** (ลองทำ)
และบรรทัด **If it does not work** (ถ้าไม่ได้ผล) พิมพ์โปรแกรมด้วยตัวเอง แล้วคุณจะจำได้

อ่านได้บนโทรศัพท์ ใน Termux หรือในแอป Jaric เวอร์ชันภาษาอังกฤษอยู่ที่ [BASICS.md](BASICS.md)

---

## 0. ติดตั้งและรันไฟล์แรก

บน Termux ติดตั้งคอมไพเลอร์ด้วยคำสั่งเดียว (จาก README):

```console
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
```

ถ้าใช้ `wget` แทน: `wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh`
ถ้าไม่มีคำสั่งใดคำสั่งหนึ่ง ให้รัน `pkg install curl wget` ก่อน บน Termux คอมไพเลอร์จะอยู่ใน
`$PREFIX/bin` ซึ่งอยู่ใน path อยู่แล้ว ตรวจด้วย `jcmp -version`

สำหรับแอป Jaric ไฟล์ของโครงการบอกเพียงว่าคอมไพเลอร์ติดตั้งด้วย `jc install jcmp`
(ในรายการเครื่องมือ) ไม่ได้อธิบายขั้นตอนเพิ่มเติมสำหรับแอป

บันทึกโค้ดนี้เป็นไฟล์ `hello.jk`:

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
}
```

คอมไพล์และรัน:

```console
jcmp hello.jk -o hello
./hello
```

ผลที่พิมพ์ออกมา:

```text
Hello, J2K!
```

**Try:** เปลี่ยนข้อความในเครื่องหมายคำพูด แล้วคอมไพล์ใหม่

**If it does not work:** ข้อความ `jcmp: command not found` หมายความว่าหา `jcmp` ไม่เจอใน path
ให้เรียกด้วยที่อยู่โฟลเดอร์แทน เช่น `../bin/jcmp hello.jk -o hello`

---

## 1. `main` และ `jout`

ทุกโปรแกรมเริ่มทำงานที่ `main` คำสั่งระหว่างวงเล็บปีกกา `{ }` จะทำงานจากบนลงล่าง
`jout <<` ใช้พิมพ์ค่าที่อยู่หลังมัน ข้อความอยู่ในเครื่องหมายคำพูด `\n` ขึ้นบรรทัดใหม่
ตัวเลขพิมพ์ออกมาตามที่เขียน จะพิมพ์หลายค่าในบรรทัดเดียวก็ใส่ `<<` เพิ่มได้ ทุกบรรทัดจบด้วย `;`
สองบรรทัดแรก (`#import` และ `using`) ทำให้ใช้ `jout` ได้ ให้วางไว้ด้านบนเสมอ

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
    jout << "Next line\n";
    jout << "A number: " << 42 << "\n";
    jout << "Two numbers: " << 3 << " and " << 4 << "\n";
    jout << 10 + 5 * 2 << "\n";
}
```

ผลที่พิมพ์ออกมา:

```text
Hello, J2K!
Next line
A number: 42
Two numbers: 3 and 4
20
```

**Try:** พิมพ์ชื่อของคุณบรรทัดหนึ่ง และอายุบรรทัดถัดไป

**If it does not work:** บรรทัดที่ไม่มี `;` ทำให้เกิดข้อความนี้ (ไฟล์ `broken.jk`):

```text
broken.jk:5:26: error: expected ';' at the end of line 5: the statement is not finished
 5 |     jout << "Next line\n"
   |                          ^
1 error generated.
```

---

## 2. ตัวแปร

ตัวแปรคือกล่องที่มีชื่อ เก็บค่าไว้หนึ่งค่า ชนิด (type) บอกว่าค่านั้นเป็นอะไร:
`int` คือจำนวนเต็ม `double` คือจำนวนทศนิยม `bool` คือ `true` หรือ `false`
`char` คือตัวอักษรหนึ่งตัว (ใส่เครื่องหมายคำพูดเดี่ยว) และ `String` คือข้อความ (ใส่เครื่องหมายคำพูดคู่)
ประกาศตัวแปรโดยเขียนชนิดนำหน้า ให้ค่าด้วย และเปลี่ยนค่าทีหลังด้วย `=`

```jk
#import <stdlib>
using stdlib;

void main() {
    int apples = 5;
    apples = apples + 2;
    double price = 2.5;
    bool sunny = true;
    char letter = 'J';
    String name = "Ann";
    jout << apples << "\n";
    jout << price << "\n";
    jout << sunny << "\n";
    jout << letter << "\n";
    jout << name << "\n";
}
```

ผลที่พิมพ์ออกมา:

```text
7
2.500000
true
J
Ann
```

**Try:** ให้ `price` เป็น 4.0 แล้วพิมพ์ จากนั้นเก็บชื่อของคุณไว้ใน `name`

**If it does not work:** เอาข้อความไปเก็บใน `int` (ไฟล์ `broken.jk`) จะได้สองข้อความ
ข้อความที่สองเป็นผลจากข้อแรก:

```text
broken.jk:5:24: error: a text cannot be stored in an int
 5 |     int apples = "five";
   |                        ^
  help: declare the variable as char^ or String
broken.jk:6:20: error: unknown name 'apples'
 6 |     jout << apples << "\n";
   |                    ^
2 errors generated.
```

---

## 3. การคำนวณและการเปรียบเทียบ

`+ - * /` และ `%` (เศษ) ทำงานตามปกติ `*` และ `/` ทำก่อน `( )` เปลี่ยนลำดับได้
`7 / 2` ได้ `3` (จำนวนเต็ม) และ `7.0 / 2.0` ได้ `3.5` การเปรียบเทียบ (`== != < > <= >=`) ให้ผลเป็น `bool`;
`&&` คือ "และ" `||` คือ "หรือ" และ `!` กลับค่า `bool`

```jk
#import <stdlib>
using stdlib;

void main() {
    int a = 7;
    int b = 2;
    jout << a / b << "\n";
    jout << 7.0 / 2.0 << "\n";
    jout << a % b << "\n";
    jout << 2 + 3 * 4 << "\n";
    jout << (2 + 3) * 4 << "\n";
    jout << (a == 7) << "\n";
    jout << (a >= 3 && b < 1) << "\n";
    jout << (a >= 3 || b < 1) << "\n";
    jout << !(a == 7) << "\n";
}
```

ผลที่พิมพ์ออกมา:

```text
3
3.500000
1
14
20
true
false
true
false
```

**If it does not work:** `bool` ต้องเป็นค่าจริงหรือเท็จ ดังนั้น `bool ok = 5;` (ไฟล์ `broken.jk`)
ให้ผลดังนี้:

```text
broken.jk:5:16: error: type mismatch: expected bool, got a number (use a comparison for a bool, or a cast)
 5 |     bool ok = 5;
   |                ^
broken.jk:6:16: error: unknown name 'ok'
 6 |     jout << ok << "\n";
   |                ^
2 errors generated.
```

---

## 4. `if`, `else` และเงื่อนไขซ้อนกัน

`if` จะทำบล็อกของมันเมื่อเงื่อนไขเป็น `true` เท่านั้น `else if` ลองเงื่อนไขอื่น
และ `else` ทำงานเมื่อไม่มีเงื่อนไขด้านบนเป็นจริง ต้องมีวงเล็บปีกกา `{ }` เสมอ
เงื่อนไขคือผลลัพธ์ `bool` จากบทที่ 3 และใส่ `if` ไว้ในอีก `if` ได้

```jk
#import <stdlib>
using stdlib;

void main() {
    int score = 72;
    if score >= 90 {
        jout << "A\n";
    } else if score >= 70 {
        jout << "B\n";
    } else {
        jout << "C\n";
    }
    bool passed = score >= 50 && score <= 100;
    if passed { jout << "passed\n"; }

    if score >= 50 {
        if score >= 70 { jout << "good pass\n"; }
    }
}
```

ผลที่พิมพ์ออกมา:

```text
B
passed
good pass
```

**Try:** เปลี่ยน `score` เป็น 95 แล้วเป็น 40 ทายผลก่อนรันทุกครั้ง

**If it does not work:** เงื่อนไขต้องเป็น `bool` ไม่ใช่ตัวเลข ถ้าเขียน `int n = 3;` แล้ว `if n {`
(ไฟล์ `broken.jk`) คอมไพเลอร์จะบอกว่า:

```text
broken.jk:6:10: error: a bool is required here
 6 |     if n {
   |          ^
  help: write a comparison, e.g. x != 0
1 error generated.
```

---

## 5. การวนซ้ำ (loop)

`while` จะทำซ้ำตราบที่เงื่อนไขยังเป็น `true` `for i in a..b` นับ `i` ตั้งแต่ `a` ถึง `b - 1`
ภายในลูป `break` ออกจากลูปก่อนกำหนด และ `continue` ข้ามไปรอบถัดไป ลูปหนึ่งวางอยู่ในอีกลูปได้

```jk
#import <stdlib>
using stdlib;

void main() {
    int i = 1;
    while i <= 3 {
        jout << i << " ";
        i++;
    }
    jout << "\n";

    int sum = 0;
    for k in 1..11 { sum += k; }
    jout << "sum 1..10 = " << sum << "\n";

    for r in 1..4 {
        for c in 1..4 { jout << r * c << "\t"; }
        jout << "\n";
    }
}
```

ผลที่พิมพ์ออกมา (ตารางคั่นด้วยแท็บ):

```text
1 2 3 
sum 1..10 = 55
1	2	3	
2	4	6	
3	6	9	
```

**Try:** พิมพ์ตารางคูณของ 7 ด้วย `for`

**If it does not work:** บรรทัด `while` ต้องมี `{` หลังเงื่อนไข ถ้าไม่มีวงเล็บ (ไฟล์ `broken.jk`)
คอมไพเลอร์จะบอกว่า:

```text
broken.jk:7:9: error: expected '{', but found 'cout'
 7 |         jout << i << " ";
   |         ^
broken.jk:10:1: error: a type was expected, but found '}'
 10 | }
    | ^
  help: a type is int, char, bool, double, float, String, a struct name, or one of these followed by ^ or []
2 errors generated.
```

---

## 6. รับข้อมูลด้วย `jin`

`jin >>` อ่านจากแป้นพิมพ์ คำแต่ละคำคั่นด้วยช่องว่างหรือขึ้นบรรทัดใหม่ ชนิดของตัวแปรเป็นตัวกำหนดว่าจะอ่านอะไร:
ตัวเลขสำหรับ `int` หรือคำสำหรับอาร์เรย์ `char` นอกจากนี้ยังป้อนข้อมูลให้โปรแกรมผ่านท่อ (pipe) ได้ด้วย: `echo "..." | ./name`

```jk
#import <stdlib>
using stdlib;

void main() {
    char name[20];
    int age;
    jin >> name >> age;
    jout << name << " will be " << age + 1 << " next year\n";
}
```

รันพร้อมข้อมูลจาก pipe:

```console
jcmp input.jk -o input
echo "Ann 30" | ./input
```

ผลที่พิมพ์ออกมา:

```text
Ann will be 31 next year
```

ถ้าข้อมูลหมดก่อนถึงตัวเลข โปรแกรมจะหยุดพร้อมข้อผิดพลาด:

```console
echo "Ann" | ./input
```

```text
uncaught exception: end of input: a whole number was expected, but the input has ended
```

**Try:** รัน `echo "Bob 41" | ./input`

**If it does not work:** ถ้าใส่คำแทนตัวเลข โปรแกรมจะหยุดด้วยข้อความนี้ (`echo "Ann thirty" | ./broken`):

```text
uncaught exception: invalid input: a whole number was expected, but found 't'
```

---

## 7. ฟังก์ชัน

ฟังก์ชันมีชนิดของผลลัพธ์ ชื่อ และพารามิเตอร์ในวงเล็บ `void` หมายความว่าไม่ให้ผลลัพธ์
`return` ส่งค่ากลับไปให้ผู้เรียก ฟังก์ชันเรียกฟังก์ชันอื่นได้ และเรียกตัวเองได้ (recursion)
ถ้าหยุดได้ที่ใดที่หนึ่ง ฟังก์ชันจะเขียนไว้ต่ำกว่าจุดที่เรียกใช้ก็ได้

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << factorial(5) << "\n";
    banner();
}

int factorial(int n) {
    if n <= 1 { return 1; }
    return n * factorial(n - 1);
}

void print_box(int n) {
    for i in 0..n { jout << "*"; }
    jout << "\n";
}

void banner() {
    print_box(3);
    jout << "ready\n";
}
```

ผลที่พิมพ์ออกมา:

```text
120
***
ready
```

**Try:** เขียน `int square(int x) { return x * x; }` แล้วพิมพ์ `square(7)`

**If it does not work:** ค่าที่ส่งเข้าไปต้องมีชนิดตรงกับพารามิเตอร์ ส่งข้อความให้พารามิเตอร์ที่เป็น `int`
(ไฟล์ `broken.jk`) จะได้:

```text
broken.jk:9:22: error: argument 1 of 'twice': a text was given, but the parameter is a number
 9 |     jout << twice("a") << "\n";
   |                      ^
  help: declare the parameter as char^ or String, or give a number
1 error generated.
```

---

## 8. อาร์เรย์

อาร์เรย์คือหลายค่าที่มีชนิดเดียวกันในตัวแปรเดียว `int scores[5];` จองที่สำหรับตัวเลขห้าตัว นับจาก 0:
`scores[0]` คือตัวแรก `scores.len` คือความยาว อาร์เรย์แบบยืดได้ `int[] list = arr(4);` เริ่มว่าง
และโตขึ้นด้วย `push`: `list.push(v)` เพิ่มค่าต่อท้าย วนดูทุกค่าด้วย `for i in 0..scores.len`

```jk
#import <stdlib>
using stdlib;

void main() {
    int scores[5];
    for i in 0..5 { scores[i] = (i + 1) * 10; }
    int total = 0;
    for i in 0..scores.len { total += scores[i]; }
    jout << "total " << total << "\n";

    int best = scores[0];
    for i in 1..scores.len {
        if scores[i] > best { best = scores[i]; }
    }
    jout << "max " << best << "\n";

    int[] list = arr(4);
    for i in 1..4 { list.push(i * i); }
    jout << list.len << " " << list[2] << "\n";
}
```

ผลที่พิมพ์ออกมา:

```text
total 150
max 50
3 9
```

**Try:** เพิ่ม `scores[2] = 99;` ก่อนลูป แล้วทายผล `total`

**กฎขอบเขต (bounds rule):** ดัชนีต้องอยู่ในช่วง `0` ถึง `len - 1` ให้คอมไพล์ด้วย `-d` เพื่อตรวจระหว่างรัน
เช่น `int small[3];` แล้วดัชนีที่รู้ค่าตอนรันเป็น 5 (ไฟล์ `broken.jk`):

```console
jcmp broken.jk -d -o broken
./broken
```

```text
runtime error: index out of bounds, array size is 3
```

โปรแกรมจะหยุดด้วยรหัสออก 134 ถ้าไม่ใส่ `-d` จะไม่มีการตรวจ ดังนั้นขณะเรียนรู้ให้ทดสอบด้วย `-d` เสมอ

---

## 9. ข้อความ (String)

`String` คือข้อความที่ยาวขึ้นได้ ต่อข้อความด้วย `+` `title.len` คือจำนวนตัวอักษร
`title[0]` คือตัวแรก และ `==` เปรียบเทียบสองข้อความ `"{n}"` ใส่ค่าของ `n` ลงในข้อความ
`to_int()` แปลง `String` เป็น `int` เมธอดใช้กับตัวแปรได้ (`s.to_int()`) และใช้กับข้อความที่เขียนในโปรแกรมโดยตรงได้ด้วย (`"42".to_int()` ได้ 42)

```jk
#import <stdlib>
using stdlib;

void main() {
    String first = "J2K";
    String title = first + " basics";
    jout << title << " " << title.len << " " << title[0] << "\n";
    if first == "J2K" { jout << "same\n"; }

    String text = "42";
    int n = text.to_int();
    jout << "{n} plus one is {n + 1}\n";
}
```

ผลที่พิมพ์ออกมา:

```text
J2K basics 10 J
same
42 plus one is 43
```

**Try:** ให้ `text` เป็น `"7"` แล้วพิมพ์ `n * 6`

**If it does not work:** ข้อความที่ไม่ใช่ตัวเลขจะทำให้โปรแกรมหยุด (ไฟล์ `broken.jk`):

```text
uncaught exception: not a number
```

ถ้าต้องการให้โปรแกรมทำงานต่อหลังข้อความผิด ใช้ `try` กับ `catch` (ดู [LANGUAGE.md](LANGUAGE.md))

---

## อ่านข้อความของคอมไพเลอร์

ทุกข้อความมีรูปแบบ `file:line:column: error: what is wrong` บรรทัดถัดไปแสดงบรรทัดนั้นและเครื่องหมาย `^`
ชี้ตำแหน่ง บรรทัด `help:` บอกสิ่งที่ควรลอง ข้อความแรกสำคัญที่สุด: แก้ข้อนั้นแล้วคอมไพล์ใหม่
เพราะข้อความถัดไปมักเป็นผลจากข้อแรก

## ขั้นต่อไป

* [docs/TUTORIAL.md](TUTORIAL.md): บทเรียนทีละขั้นตอน มีบทเรียนและแบบฝึกหัดเพิ่มเติม
* [docs/COOKBOOK.md](COOKBOOK.md): สูตรสั้น ๆ สำหรับงานที่พบบ่อย
* [docs/LANGUAGE.md](LANGUAGE.md): คู่มืออ้างอิงภาษาฉบับเต็ม
