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
61. ไลบรารีของเครื่อง: `-dyn` และ `<native>`
62. OpenGL ES: ภาพแรกที่ชิปวาด
63. สามเหลี่ยมและเชเดอร์
64. ชิปเป็นเครื่องคิดเลข: compute shader
65. Vulkan: ถามชิป
66. เกม: Jaric Engine
67. คุยกับเว็บ: `<web>`
68. บอตที่ตอบได้: `<telegram>` และ `<discord>`
69. ข่าวสดๆ: WebSocket และ Gateway ของ Discord
70. ตัวเลขที่เรียนรู้ได้: tensor และ gradient
71. สอนโครงข่าย: ชั้น, batch และ AdamW
72. โมเดลภาษาที่คุณเทรนบนมือถือ
73. รันโมเดลที่คนอื่นทำ: GGUF และ `<llama>`
74. โค้ดที่เร็ว: ภาษามีต้นทุนเท่าไรและขอความเร็วอย่างไร
75. โปรแกรมและไลบรารีจากเน็ต: `jc`
76. นับเลขฐาน 2 และฐาน 16
77. จำนวนลบ: two's complement
78. ตัวเลขมีจุด: ข้างใน
79. จากประตูตรรกะสู่ตัวบวก
80. CPU จิ๋วของเราเอง
81. assembler สำหรับ CPU จิ๋ว
82. ของจริง: คำสั่ง ARM64 เป็น 32 บิต
83. จัดหน้าผลลัพธ์: คอลัมน์ ทศนิยม เลขฐานสิบหก
84. หน้าจอของแอพ: `<ui>`
85. apk โดยไม่ต้องมีเครื่องมือ Android: `apkj`
86. ดูอาร์เรย์เพียงบางส่วน: Span
87. ตัวอักษรจริง: อ่าน UTF-8 และไลบรารี <font>
88. แสง เงา และแสงเรือง: สีผสมกันอย่างไร
89. กุญแจหลายดอกจากความลับเดียว: HKDF และเครื่องมือ jmaip
90. ลูปเร็ว: เขียนอย่างไรให้คอมไพเลอร์ใช้ SIMD ได้
91. ทำไมการวนลูปบนอาเรย์จึงเร็ว
92. จับเวลาด้วย Time::mono_ns
93. float กับ double และอาเรย์ float[]
94. ชนิดเวกเตอร์ SIMD: f32x4 อ่านและเขียน
95. ตัวดำเนินการของ f32x4 และ .sum()
96. axpy ด้วย f32x4: y = y + a * x
97. การคูณเมทริกซ์แบบตรงไปตรงมา (ijk)
98. ทำไม ijk จึงช้ากว่า: โซ่การบวก และตัวสะสมสองตัว
99. ตัวสะสมสี่ตัวด้วยมือ
100. เวกเตอร์ตามแนว j: คำนวณสี่คอลัมน์ของ C พร้อมกัน
101. บล็อกรีจิสเตอร์ขนาด 4x8
102. หลายเธรด: ลูป #multithread
103. การตรวจขอบเขตดัชนีและสวิตช์ -d
104. สวิตช์ -novec -nofma -nopeep -noir
105. อ่านแอสเซมบลีของลูป
106. ผลรวมจำนวนเต็มด้วย i32x4
107. ไม่จองหน่วยความจำในลูปที่ร้อน
108. อาเรย์ของ struct กับ struct ของอาเรย์
109. แคช: ลำดับแถวและลำดับ i-k-j กับ i-j-k
110. เปรียบเทียบกับ C อย่างยุติธรรม
111. โครงข่ายประสาทเทียมคืออะไร
112. เทนเซอร์
113. การคูณเมทริกซ์
114. เลเยอร์เชิงเส้น
115. ฟังก์ชันกระตุ้น
116. loss: ค่าเฉลี่ยกำลังสองของความคลาดเคลื่อน
117. ความชัน ตรวจด้วยสองวิธี
118. gradient descent: น้ำหนักตัวเดียว
119. น้ำหนักสองตัว: เส้นตรง
120. XOR ด้วยโครงข่ายเล็ก
121. backpropagation บนกราฟ
122. mini-batch และการสลับแถว
123. softmax และ cross-entropy
124. learning rate
125. น้ำหนักเริ่มต้น
126. embedding
127. โมเดลตัวอักษรขนาดเล็ก
128. บันทึกและโหลดน้ำหนัก
129. inference: การใช้โครงข่ายที่เทรนแล้ว
130. ทำไมการคูณเมทริกซ์คือความเร็ว
131. โปรแกรมที่แบ่งเป็นหลายไฟล์
132. เขียนเทสต์ให้ฟังก์ชันของเรา
133. จัดการข้อผิดพลาดตอนอ่านข้อมูล
134. อาร์กิวเมนต์บนบรรทัดคำสั่ง
135. อ่านไฟล์ข้อความทีละบรรทัดแล้วนับคำ
136. เขียนรายงานเป็น CSV
137. JSON เข้าและออก
138. เครื่องสถานะเล็กๆ
139. ตัวแยกคำสำหรับนิพจน์คณิตศาสตร์
140. เครื่องคิดเลขแบบ recursive descent
141. ฮีปจากพื้นฐาน
142. นับความถี่ของคำด้วยตารางแฮช
143. เรียงลำดับด้วยการเปรียบเทียบของเราเอง
144. แผนที่ห้องสำหรับเกมผจญภัยแบบข้อความ
145. ลูปของเกมโดยไม่มีกราฟิก
146. บัญชีธนาคารพร้อมเมธอดและการตรวจ
147. สแต็กทั่วไป: Stack<T>
148. defer: ทำความสะอาดเมื่อฟังก์ชันล้มเหลว
149. ไฟล์สร้างโปรแกรมของ makej และการอ่านมันเป็นข้อความ
150. อ่านข้อความผิดพลาดของคอมไพเลอร์
151. ชื่ออยู่ได้ที่ไหน: ขอบเขตตัวแปร
152. ตารางแถวและคอลัมน์
153. ค้นหาให้เร็ว: binary search
154. แก้บั๊กด้วยการดูค่า
155. นับขั้นตอน: Big-O
156. สแตก: เข้าทีหลัง ออกก่อน
157. คิวแบบ ring buffer
158. ต้นไม้ค้นหา
159. กราฟและการค้นหาแบบกว้าง
160. โปรแกรมมิงแบบไดนามิก
161. ตารางแฮชแบบเขียนเอง
162. เรียงสองแบบ นับการเปรียบเทียบ
163. หน่วยความจำและแคช: ทำไมลำดับลูปจึงสำคัญ

## บทที่ 1. สวัสดีชาวโลก

โปรแกรมเริ่มทำงานที่ `main` คำสั่ง `jout <<` ใช้พิมพ์ และ `\n` คือขึ้นบรรทัดใหม่ บันทึกเป็นไฟล์ `hello.jk`

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "Hello, J2K!\n";
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
`jout` พิมพ์ทศนิยมได้ด้วย ทุกบรรทัดจบด้วย `;`

```jk
#import <stdlib>
using stdlib;

void main() {
    int apples = 5;
    int pears = 3;
    int total = apples + pears;
    jout << "total = " << total << "\n";

    double price = 2.5;
    jout << "cost = " << price * 4.0 << "\n";

    char letter = 'J';
    jout << letter << "\n";

    bool enough = total > 7;
    if enough { jout << "enough fruit\n"; }
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
        jout << "A\n";
    } else if score >= 70 {
        jout << "B\n";
    } else {
        jout << "C\n";
    }
    bool passed = score >= 50 && score <= 100;
    if passed { jout << "passed\n"; }
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
        jout << i << " ";
        i++;
    }
    jout << "\n";

    for k in 0..5 { jout << k * k << " "; }
    jout << "\n";

    for int j = 10; j > 0; j -= 3 { jout << j << " "; }
    jout << "\n";
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
    jout << square(7) << "\n";
    jout << sum_to(10) << "\n";
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
    jout << "Hello, " << name << "!\n";
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
    jout << "total " << total << "\n";

    char word[] = "banana";
    int count = 0;
    for i in 0..word.len {
        if word[i] == 'a' { count++; }
    }
    jout << word << " has " << count << " letter a\n";

    int grid[2][3];
    for r in 0..2 {
        for c in 0..3 { grid[r][c] = r * 3 + c; }
    }
    jout << grid[1][2] << "\n";
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

`jin >> a >> b;` อ่านข้อมูลจากคีย์บอร์ด ชนิดของตัวแปรกำหนดว่าจะอ่านอะไร: ตัวเลขสำหรับ `int` คำสำหรับอาร์เรย์ `char`
`jin` อ่านทศนิยมได้ด้วย คำคั่นด้วยช่องว่างหรือขึ้นบรรทัดใหม่

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

ข้อมูลเข้า: `Ann 30`

ผลลัพธ์:

```
Ann will be 31 next year
```

รันแล้วพิมพ์ `Ann 30` (หรือส่งผ่าน pipe: `echo "Ann 30" | ./input`) ถ้ากรอกผิดจะเกิด error ที่จับได้ (บทที่ 17)

## บทที่ 8. บรรทัด ตัวเลข และปุ่ม: read

`jin` อ่านทีละคำ ถ้าต้องการทั้งบรรทัด ตัวเลขจากบรรทัด หรือคำตอบของคำถาม ให้ใช้โมดูล `read` (`using Input;`): `read.line()`, `read.number()`, `read.yes("คำถาม")` ส่วน `read.enter()` รอให้กด Enter และ `read.key()` รอปุ่มเดียวโดยไม่ต้องกด Enter (ดูข้างล่าง)

```jk
#import <stdlib>
using stdlib;
using Input;

void main() {
    jout << "name? ";
    String name = read.line();
    jout << "age? ";
    int age = read.number();
    jout << name << " will be " << age + 1 << " next year\n";
    if read.yes("again?") { jout << "ok\n"; } else { jout << "bye\n"; }
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

`read.number()` โยน error เมื่อบรรทัดไม่ใช่จำนวนเต็ม (`read.try_number()` คืน `Result` แทน) `read.key()` คืนรหัสของปุ่ม ไม่แสดงบนจอและไม่ต้องกด Enter: ตัวอักษรคือรหัสของมัน Escape คือ 27 ลูกศรคือ 257 (ขึ้น) 258 (ลง) 259 (ขวา) 260 (ซ้าย) ตามด้วย Home, End, Delete, ปุ่มหน้า และ F1 ถึง F4 และเมื่ออินพุตหมดคือ -1 `read.key_timeout(ms)` ยอมแพ้เมื่อครบเวลา (-2), `read.password()` ซ่อนสิ่งที่พิมพ์ และ `read.decimal()` อ่านตัวเลขที่มีทศนิยม เกมหรือเมนูอ่านแป้นพิมพ์แบบนี้ ใน 1 โปรแกรมใช้ `read` หรือ `jin` อย่างใดอย่างหนึ่ง ไม่ใช้ทั้งสอง

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
    jout << r.area() << "\n";
    r.grow(1);
    jout << r.w << "x" << r.h << " area " << r.area() << "\n";
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
        Light::Red: jout << "stop\n";
        Light::Yellow: jout << "slow down\n";
        Light::Green: jout << "go\n";
    }
}

void main() {
    say(Light::Green);
    say(Light::Red);

    int n = 3;
    switch n {
        1, 2: jout << "small\n";
        3: jout << "three\n";
        _: jout << "other\n";
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
    jout << n << "\n";

    int a[3];
    a[0] = 10; a[1] = 20; a[2] = 30;
    int^ q = @a;
    jout << q[1] << "\n";
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
    jout << squares.len << " items, total " << total(squares) << "\n";

    int^ buffer = (int^)alloc(sizeof(int) * 3);
    buffer[0] = 7;
    buffer[1] = 8;
    buffer[2] = 9;
    jout << buffer[0] + buffer[2] << "\n";
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
เมธอด: `push`, `append`, `pop`, `clear`, `find`, `slice(จาก, ถึง)`, `c()` (ตัวอักษรในรูปข้อความธรรมดา) `jin >> s` อ่านหนึ่งคำ
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
    jout << a << " " << b << "\n";

    String line = "Hello, " + shout("Jao");
    jout << line << " (" << line.len << " characters)\n";
    jout << line.find("Jao") << " " << line.slice(0, 5) << "\n";
    if a == "abc" { jout << "same\n"; }
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
    jout << largest(3, 9) << "\n";
    jout << largest(2.5, 1.5) << "\n";
    jout << largest<int>(8, 2) << "\n";
    Box<int> b = {7};
    jout << b.get() << "\n";
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
    for s in scores { jout << s << " "; }
    jout << "\n";

    Map<String, int> ages;
    ages.put("ann", 31);
    ages.put("bob", 25);
    ages.put("ann", 32);
    jout << ages.get("ann") << " " << ages.len << "\n";
    for name in ages.keys_list() {
        jout << name << " is " << ages.get(name) << "\n";
    }

    Set<int> seen;
    for i in 0..20 { seen.add(i % 5); }
    jout << seen.len << " different, has 3: " << seen.has(3) << "\n";
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
    jout << apply(int(int a, int b) { return a + b; }, 3, 4) << "\n";
    int(int)^ triple = int(int x) { return x * 3; };
    jout << triple(5) << "\n";
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
        jout << divide(10, 2) << "\n";
        jout << divide(1, 0) << "\n";
    } catch (e) {
        jout << "error: " << e << "\n";
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
    jout << "hypotenuse = " << sqrt(a * a + b * b) << "\n";

    int whole = (int)floor(7.9);
    jout << whole << "\n";

    double half = (double)whole / 2.0;
    jout << half << "\n";
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
    jout << line << "\n";
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
    jout << cube(3) << "\n";
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
            jin >> w;
            count++;
            int n = length(@w);
            if n > longest { longest = n; }
        }
    } catch (e) {
        // the input is over
    }
    jout << count << " words, the longest has " << longest << " letters\n";
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
        Result::Ok(v): jout << "sum = " << v << "\n";
        Result::Err(e): jout << "error: " << e.message << "\n";
    }
}

void main() {
    show(add("20", "22"));
    show(add("20", ""));
    Option<String> home = Env::get("J2K_SURELY_NOT_SET");
    jout << home.is_none() << " " << Env::get("PATH").is_some() << "\n";
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
    defer jout << "leaving work(" << n << ")\n";
    if n > 5 {
        jout << "big\n";
        return;
    }
    jout << "small\n";
}

void main() {
    work(3);
    work(9);
    for i in 0..2 {
        defer jout << "end of round " << i << "\n";
        jout << "round " << i << "\n";
    }
    defer jout << "first defer\n";
    defer jout << "second defer\n";
    jout << "main body\n";
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
    jout << b.cents << " " << c.cents << " " << (a + a == c) << "\n";
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
    jout << d.text() << " weekday " << d.weekday() << "\n";
    d.add_days(60);
    jout << d.text() << " day of year " << d.day_of_year() << "\n";
    jout << Date::is_leap(2024) << " " << Date::days_in_month(2024, 2) << "\n";
    Random::seed(42);
    int r = Random::range(1, 7);
    jout << (r >= 1 && r < 7) << " " << (Random::unit() < 1.0) << "\n";
    int t0 = Time::mono_ns();
    Time::sleep_ms(20);
    jout << (Time::mono_ns() - t0 >= 20000000) << "\n";
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
    jout << doc.text(doc.get(root, "name")) << " " << doc.number(doc.get(root, "version")) << "\n";
    int tags = doc.get(root, "tags");
    for i in 0..doc.len(tags) { jout << doc.text(doc.at(tags, i)) << " "; }
    jout << doc.boolean(doc.get(root, "ok")) << "\n";
    jout << doc.dump(tags) << "\n";
    jout << Json::quote("say \"hi\"") << "\n";
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
    jout << f.len << ": " << f[0] << " | " << f[1] << " | " << f[2] << "\n";
    jout << Csv::join_line(f) << "\n";
    jout << Fmt::fixed(3.14159, 2) << " " << Fmt::pad_left("7", 3, '0') << " " << Fmt::thousands(1234567) << "\n";
    jout << Fmt::hex(255) << " " << Fmt::bin(5) << " " << Fmt::percent(0.256, 1) << " " << Fmt::bytes(1536) << "\n";
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
    jout << Regex::matches("[a-z]+@[a-z]+\\.com", "ann@mail.com") << " " << Regex::find("[0-9]+", "room 42, floor 7") << " " << Regex::find_text("[0-9]+", "room 42, floor 7") << "\n";
    jout << Sha256::hex("abc") << "\n";
    jout << Hex::encode("Hi") << " " << Base64::encode("Man") << " " << Base64::decode("TWFu").unwrap() << "\n";
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
    jout << Path::join("dir", "file.txt") << "\n";
    String[] args = arr(0);
    args.push("hello from a child");
    String out = Proc::output("echo", args).unwrap();
    jout << out;
    jout << Env::args().len << "\n";
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
    jout << x << " " << Bit::popcount(x) << " " << Bit::clz(x) << " " << Bit::ctz(x) << "\n";
    jout << (x >> 4) << " " << (x & 0xF) << " " << (x << 4) << " " << (x xor 0xFF) << "\n";
    jout << Bit::rotl(1, 63) << "\n";
    jout << Bit::bswap(0x0102030405060708) << "\n";
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
    jout << hi.sum << " " << lo.sum << " " << hi.c << "\n";
    BitWide w = Bit::mul_wide(-1, 3);
    jout << w.hi << " " << w.lo << "\n";
    BitDivRem d = Bit::div_rem(-17, 5);
    jout << d.q << " " << d.r << "\n";
    jout << Bit::add_sat(9223372036854775807, 5) << "\n";
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
    jout << total << "\n";
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
L9017:
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
    jout << clamp(-5, 0, 10) << " " << clamp(7, 0, 10) << " " << clamp(99, 0, 10) << "\n";
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
    jout << counter << "\n";
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
    jout << add_mul(2, 3, 4) << "\n";
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
    jout << n << "\n";
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
    jout << carry_of(-1, 1) << " " << carry_of(1, 2) << "\n";
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
    jout << v << "\n";
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
    for i in 0..8 { jout << (b[i] & 255) << " "; }
    jout << "\n";
    int a[4];
    for i in 0..4 { a[i] = i * 10; }
    int^ p = @a[0];
    int^ q = @a[3];
    jout << ((int)q - (int)p) << " " << (p == @a[0]) << " " << (q^) << "\n";
    jout << sizeof(int) << " " << sizeof(char) << "\n";
}
```

ผลลัพธ์:

```
8 7 6 5 4 3 2 1 
24 true 30
8 1
```

`0x0102030405060708` ถูกเก็บเป็น `08 07 ... 01` `int` สี่ตัวคือ 32 ไบต์ `a[3]` จึงอยู่หลัง `a[0]` 24 ไบต์ ถ้าพิมพ์ที่อยู่ของตัวแปร (`jout << p;`) จะได้ `0x...` ที่นี่พิมพ์ระยะแทนเพราะที่อยู่เปลี่ยนทุกครั้งที่รัน

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
    jout << (pid > 0) << "\n";
    void^ page = Sys::mmap(4096);
    int^ words = (int^)page;
    for i in 0..512 { words[i] = i * i; }
    jout << words[511] << "\n";
    Sys::munmap(page, 4096);
}
```

ผลลัพธ์:

```
hi
true
261121
```

`mmap` ให้หน้าเต็ม (4096 ไบต์) ที่เป็นศูนย์ตอนเริ่ม ตัว `jout` เองก็จบที่ `Sys::write` ถ้าต้องการ call ที่ไลบรารีไม่มีชื่อให้ ใช้ `Sys::call(เลข, a0 ... a5)` และ `svc` ในบทที่ 36

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
    jout << a[3] + b[3] << " " << top << " " << ((int)b - (int)a) << "\n";
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
    jout << counter << "\n";
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
    jout << sum << " " << (ticks > 0) << " " << (Cpu::frequency() > 0) << "\n";
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
    jout << c.x << " " << c.y << " " << c.z << "\n";
    jout << c.zyx.x << "\n";
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
        jout << value << " ";
    }
    jout << "\n";
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
    jout << total << "\n";
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
    jout << sum_words(@a, 5) << "\n";
    jout << sum_words(@a, 0) << "\n";
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
    jout << mulhi(0x8000000000000000, 6) << " " << mulhi(100, 100) << "\n";
    jout << reverse_bits(1) << " " << reverse_bits(6) << "\n";
    jout << swap_bytes(1) << " " << swap_bytes(0x0102030405060708) << "\n";
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
    jout << text;
    jout << Fs::fs.size("tl_demo.txt") << " " << Str::str.len("abc") << "\n";
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
        Color::Red: jout << "red\n";
        Color::Green: jout << "green\n";
        Color::Blue: jout << "blue\n";
    }
    Shape a = Shape::Circle(2.0);
    Shape b = Shape::Rect(3.0, 4.5);
    Shape e = Shape::Empty;
    jout << a.area() << " " << b.area() << " " << e.area() << "\n";
    switch b {
        Shape::Rect(w, _): jout << "width " << w << "\n";
        _: jout << "something else\n";
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
    jout << p.x << " " << p.dist2() << "\n";
    Line l = {{0.0, 0.0}, {6.0, 8.0}};
    jout << l.b.dist2() << "\n";
    Point pts[3];
    for i in 0..3 { pts[i].x = (double)(i + 1); pts[i].y = (double)(i + 1); }
    double total = 0.0;
    for i in 0..3 { total += pts[i].dist2(); }
    jout << total << "\n";
    Point^ q = @p;
    q^.x = 10.0;
    jout << p.x << "\n";
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
        if self.data != null { jout << "freeing " << self.n << "\n"; free[self.data]; }
    }
}

Buffer make(int n) {
    alloc[int^ p = n];
    Buffer b = {p, n};
    return b;
}

void use(Buffer b) {
    jout << "using " << b.n << "\n";
}

void main() {
    Buffer a = make(4);
    Buffer b = a;
    use(b);
    jout << "end of main\n";
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
    jout << op(5) << " " << apply(square, 7) << "\n";
    int k = 3;
    int(int)^ addk = int(int x) { return x + 100; };
    jout << apply(addk, k) << "\n";
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
    jout << b << " " << big << " " << small << "\n";
    int wide = 4000000000;
    jout << wide + 500000000 << "\n";
    jout << sizeof(int) << " " << sizeof(u8) << " " << sizeof(double) << " " << sizeof(char) << "\n";
    double d = 3.99;
    int t = (int)d;
    char c = (char)65;
    jout << t << " " << c << " " << (int)'z' << "\n";
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
    jout << a[2] + b[2] << "\n";
    free[b];
    alloc[pool[12] >> int^ c];
    c[0] = 99;
    jout << a[0] << " " << c[0] << "\n";
    free[pool];

    alloc[int^ p = 2];
    p[0] = 5;
    p[1] = 6;
    grow[p = 8];
    p[7] = 70;
    jout << p[1] << " " << p[7] << "\n";
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
    jout << sum << " " << limit << " " << answer() << "\n";
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
    jout << "hello\n";
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
    jout << "a build file is a program\n";
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
    jout << "a library has no main; this lesson is a program so that it runs\n";
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

ฟังก์ชัน `export` ใช้กฎการเรียกของแพลตฟอร์ม: จำนวนเต็มใน `x0 ..` และ `double` ใน `d0 ..` พารามิเตอร์และผลลัพธ์เป็น `int`, `bool`, `char` และ `double` ได้ (ไม่เกิน 8 พารามิเตอร์) String อาร์เรย์ และ struct ยังข้ามขอบเขตไม่ได้ ไลบรารีมีตัวแปรของตัวเอง (`counter` เริ่มที่ 10 ตอนโหลด) และฮีปของตัวเอง ยังไม่ได้: `jout` ในไลบรารี

## บทที่ 60. สคริปต์ด้วย jsh และการเขียนโค้ดบนมือถือ

คำสั่งของ shell ก็เป็นโปรแกรมเช่นกัน ในบทนี้โปรแกรมเป็นตัวแทนของโปรแกรมที่คุณจะเขียนบนมือถือ ด้านล่างเป็นสคริปต์

```jk
#import <stdlib>
using stdlib;

void main() {
    jout << "write it with coderin, build it with jcmp, run it\n";
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
        jout << "no libvulkan here, or the program was not built with jcmp -dyn\n";
        return 1;
    }
    int fn = Native::sym(lib, "vkEnumerateInstanceVersion");   // ฟังก์ชัน: VkResult vkEnumerateInstanceVersion(uint32_t* version)
    char out[16];                                              // ที่ว่างสำหรับเลขที่ฟังก์ชันจะเขียน
    out[0] = 0; out[1] = 0; out[2] = 0; out[3] = 0;
    int result = Native::call1(fn, (int)@out);                 // เรียกด้วยที่อยู่ของ out
    int v = Native::peek32((int)@out);                         // อ่าน 32 บิตที่ฟังก์ชันเขียน
    jout << "Vulkan " << (v >> 22) << "." << ((v >> 12) & 1023) << "\n";
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
        jout << "no OpenGL here: " << gl.log << "\n";  // gl.log บอกเหตุผล
        return 1;
    }
    jout << "chip: " << gl.renderer << "\n";           // เช่น Mali-G76
    gl.clear_color(1.0, 0.5, 0.0, 1.0);                // แดง เขียว น้ำเงิน โปร่งใส: สีส้ม
    gl.clear_color_buffer();                           // ชิประบายสีทั้งภาพ
    String pixels = gl.read_pixels(10, 10, 1, 1);      // อ่านพิกเซลกลับมาหนึ่งจุด: 4 ไบต์
    jout << (pixels[0] & 255) << " " << (pixels[1] & 255) << " " << (pixels[2] & 255) << "\n";
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
    if !gl.ok { jout << gl.log << "\n"; return 1; }
    String vertex = "#version 300 es\nlayout(location = 0) in vec2 pos;\nvoid main() { gl_Position = vec4(pos, 0.0, 1.0); }\n";
    String fragment = "#version 300 es\nprecision mediump float;\nout vec4 color;\nvoid main() { color = vec4(1.0, 0.5, 0.0, 1.0); }\n";
    int prog = gl.program(vertex, fragment);
    if prog == 0 { jout << "shader: " << gl.log << "\n"; return 1; }
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
    jout << (inside[0] & 255) << " " << (outside[0] & 255) << "\n";
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
    if !gl.ok { jout << gl.log << "\n"; return 1; }
    // แต่ละเธรดรับเลขหนึ่งตัว: v = v * 2 + 1  local_size_x = 8: หนึ่งกลุ่มมี 8 เธรด
    String shader = "#version 310 es\nlayout(local_size_x = 8) in;\nlayout(std430, binding = 0) buffer Data { float v[]; };\nvoid main() { uint i = gl_GlobalInvocationID.x; v[i] = v[i] * 2.0 + 1.0; }\n";
    Floats data = Floats::make(16);
    for i in 0..16 { data.set(i, (float)i); }
    Floats result = gl.compute(shader, data, 2, 1, 1);   // 2 กลุ่ม x 8 เธรด = 16 ตัวเลข
    if gl.log.len > 0 { jout << "log: " << gl.log << "\n"; }
    jout << result.get(0) << " " << result.get(5) << " " << result.get(15) << "\n";
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
    if !vk.ok { jout << vk.log << "\n"; return 1; }
    jout << vk.device_name << ", Vulkan " << vk.api_text() << "\n";
    jout << "memory " << vk.memory_mb << " MB, queues " << vk.queue_families << ", compute " << vk.has_compute << "\n";
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

## บทที่ 67. คุยกับเว็บ: `<web>`


บริการส่วนใหญ่บนเน็ตใช้ HTTP `#import <web>` เป็นตัวไคลเอนต์: เรียกครั้งเดียวได้คำตอบที่มี **status** (200 คือดี 404 คือไม่พบ ...), **header** และ **body** status 400 ขึ้นไป *ไม่ใช่* ข้อผิดพลาดของโปรแกรม (body มักอธิบายไว้) มีแต่การเชื่อมต่อที่ล้มเท่านั้นที่เป็น `Error`

```jk
#import <stdlib>
#import <web>

int main() {
    Result<HttpResponse, Error> r = Web::get("https://example.org/", "");     // url, extra header lines ("" for none)
    switch r {
        Result::Ok(a): {
            jout << "status " << a.status << ", " << a.body.len << " bytes\n";
            jout << "type: " << a.header("content-type") << "\n";             // a header of the answer, any case
        }
        Result::Err(e): { jout << "no answer: " << e.message << "\n"; }
    }
    return 0;
}
```

ส่งข้อมูล: `Web::post_json(url, headers, json_text)`, `Web::post_form(url, headers, "a=1&b=2")` หรือ `Web::request("PUT", url, headers, body)` header คือบรรทัดคั่นด้วย `\r\n`; `Web::url_encode(text)` ทำให้ข้อความปลอดภัยสำหรับใส่ในที่อยู่ ตามการเปลี่ยนเส้นทางให้ (สูงสุด 5 ครั้ง) ใช้ `https` ได้ หนึ่งคำขอใช้หนึ่งการเชื่อมต่อ

```jk
#import <stdlib>
#import <web>

// asks an API that answers with JSON and prints one field
int main() {
    String key = "my-secret-key";                                              // never write a real key in a file you share
    Result<HttpResponse, Error> r = Web::post_json("https://example.org/api", "Authorization: Bearer " + key, "{\"question\":\"hello\"}");
    switch r {
        Result::Ok(a): {
            if a.status >= 400 { jout << "the service said " << a.status << ": " << a.body << "\n"; return 1; }
            Result<JsonDoc, Error> pj = Json::parse(a.body);
            switch pj {
                Result::Ok(d): {
                    int n = d.get(0, "answer");                                 // 0 is the top object
                    if n >= 0 { jout << d.text(n) << "\n"; }
                }
                Result::Err(e2): { jout << "not JSON\n"; }
            }
        }
        Result::Err(e): { jout << "no answer: " << e.message << "\n"; }
    }
    return 0;
}
```

**ลอง:** เปลี่ยนที่อยู่เป็นบริการที่คุณใช้; พิมพ์ `a.head` เพื่อดู header ทั้งหมด; ขอที่อยู่ที่ไม่มีอยู่จริงแล้วอ่าน status

## บทที่ 68. บอตที่ตอบได้: `<telegram>` และ `<discord>`


บอตคือโปรแกรมที่มีบัญชีในบริการแชต คุณสร้างบอตในบริการนั้น (Telegram: แชตกับ BotFather; Discord: developer portal) ได้ **token** (ข้อความลับยาวๆ: อย่าใส่ในไฟล์ที่แชร์หรือใน git อ่านจากตัวแปรสภาพแวดล้อมหรือไฟล์ที่มีแต่คุณอ่านได้) แล้วโปรแกรมคุยกับบริการผ่าน `<web>` ที่อยู่ข้างใต้

```jk
#import <stdlib>
#import <telegram>

int main() {
    String token = "";
    switch Env::get("TG_TOKEN") { Option::Some(t): { token = t + ""; } Option::None: { } }
    if token.len == 0 { jout << "set TG_TOKEN first\n"; return 1; }
    Telegram bot = Telegram::bot(token);
    int next = 0;
    while true {
        switch bot.poll(next, 25) {                                  // waits up to 25 seconds for news (long polling)
            Result::Ok(up): {
                for i in 0..up.count() {
                    TgMessage m = up.get(i);                         // m.chat  m.from  m.text
                    bot.send(m.chat, "you said: " + m.text);
                }
                next = up.next;                                      // where to go on: the messages seen are not given again
            }
            Result::Err(e): { jout << "error: " << e.message << "\n"; return 1; }
        }
    }
    return 0;
}
```

`<discord>` ใช้แนวเดียวกัน `Discord::bot(token)`, `bot.send(channel, "ข้อความ")` และ `bot.messages(channel, last_id, 20)` (ข้อความล่าสุด เรียงเก่าไปใหม่ เก็บ `ms.last` ไว้ส่งครั้งหน้า) เลขของ Discord ใหญ่มาก ช่องและข้อความจึงเป็น **ข้อความ (text)** ต้องเปิด "Message Content Intent" ใน portal ไม่งั้นข้อความจะว่าง

```jk
#import <stdlib>
#import <discord>

int main() {
    Discord bot = Discord::bot("TOKEN-of-the-bot");
    switch bot.send("123456789012345678", "hello from J2K") {
        Result::Ok(x): { jout << "sent\n"; }
        Result::Err(e): { jout << "failed: " << e.message << "\n"; }         // Discord's own words: 401 = the token is wrong
    }
    return 0;
}
```

กติกาของบอตที่ดี: ตอบเฉพาะคน (`by_bot` ของข้อความ Discord บอกได้) ไม่ถามถี่เกินไป (HTTP 429 แปลว่ารอ) ไม่พิมพ์ token ออกมา และทดสอบกับบอตของคุณเองในแชตของคุณเองก่อนเชิญไปที่อื่น

## บทที่ 69. ข่าวสดๆ: WebSocket และ Gateway ของ Discord


การถามซ้ำๆ ("polling") เสียเวลา **WebSocket** คือการเชื่อมต่อที่เปิดค้างไว้: เซิร์ฟเวอร์ส่งข้อความมาทันทีที่มี `<websocket>` สร้างให้: `Ws::connect("wss://host/path", "")` ได้ `WebSocket`; ใช้ `send_text`, `recv` (รอข้อความเต็มถัดไป) และ `recv_wait(ms)` (รอไม่เกิน `ms` มิลลิวินาที: kind 0 เมื่อยังไม่มีอะไรมา)

```jk
#import <stdlib>
#import <websocket>

int main() {
    switch Ws::connect("wss://example.org/socket", "") {
        Result::Ok(ws): {
            ws.send_text("hello");
            int waited = 0;
            while waited < 10 {
                WsMessage m = ws.recv_wait(1000);                   // one second at most
                if m.kind == 0 { waited += 1; continue; }           // nothing yet: do something else, or wait again
                if m.kind == 8 { jout << "closed: " << m.text << "\n"; break; }
                jout << "got: " << m.text << "\n";                  // kind 1 text, 2 binary
                break;
            }
            ws.close();
        }
        Result::Err(e): { jout << "cannot connect: " << e.message << "\n"; }
    }
    return 0;
}
```

Gateway ของ Discord คือ WebSocket ที่มีกติกา (hello, identify, heartbeat ทุกไม่กี่วินาที) `<discord>` ทำกติกาให้: `Gw::connect(token, Gw::intents())` แล้ว `gw.next(1000)` ให้เหตุการณ์ทีละอัน (และส่ง heartbeat ภายใน จึงควรเรียกบ่อยๆ)

```jk
#import <stdlib>
#import <discord>

int main() {
    String token = "TOKEN-of-the-bot";
    Discord bot = Discord::bot(token);
    switch Gw::connect(token, Gw::intents()) {
        Result::Ok(gw): {
            bool run = true;
            while run {
                DcEvent e = gw.next(1000);
                if e.kind == "MESSAGE_CREATE" && !e.by_bot { bot.send(e.channel, "you said: " + e.text); }
                if e.kind == "CLOSED" || e.kind == "RECONNECT" || e.kind == "INVALID_SESSION" { run = false; }
            }
        }
        Result::Err(e): { jout << "cannot connect: " << e.message << "\n"; }
    }
    return 0;
}
```

## บทที่ 70. ตัวเลขที่เรียนรู้ได้: tensor และ gradient


โครงข่ายประสาทคือกองของการคูณที่ตัวเลขถูกปรับจนคำตอบถูก `<neuron>` ให้ชิ้นส่วนมา **`Tensor32`** คือตารางของ float 32 บิต (แถว x คอลัมน์) **`Graph`** จดการคำนวณไว้ เพื่อย้อนกลับไปบอกว่าตัวเลขแต่ละตัวควรเปลี่ยนอย่างไร (**gradient**)

โปรแกรมเรียนรู้ที่เล็กที่สุด: หา `w` และ `b` ให้ `y = w x + b` พอดีกับจุดที่อยู่บน `y = 2x + 1`

```jk
#import <stdlib>
#import <neuron>

Graph g;                                         // a Graph is big: keep it in a global (do not pass it around by value)

int main() {
    g = Graph::make();
    int w = g.param(Tensor32::zeros(1, 1));      // a parameter: a number that learns
    int b = g.param(Tensor32::zeros(1, 1));
    g.mark();                                    // what is made until now stays; what comes after is one step
    double[] xv = arr(4);
    xv.push(0.0); xv.push(1.0); xv.push(2.0); xv.push(3.0);
    double[] yv = arr(4);
    yv.push(1.0); yv.push(3.0); yv.push(5.0); yv.push(7.0);
    Tensor32 xs = Tensor32::from_list(4, 1, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    for step in 0..300 {
        int x = g.input(xs);
        int guess = g.add(g.matmul(x, w), b);    // x @ w + b: the four guesses
        int loss = g.mse(guess, ys);             // the mean of the squares of the errors
        g.backward(loss);                        // the gradient of every parameter
        g.sgd(0.1);                              // a small step downhill
        g.clear();                               // forget the step, keep the parameters
    }
    jout << "w = " << g.value(w).get(0, 0) << "  b = " << g.value(b).get(0, 0) << "\n";    // near 2 and 1
    return 0;
}
```

ศัพท์: **loss** = คำตอบผิดแค่ไหน (ยิ่งน้อยยิ่งดี); **learning rate** = ขนาดก้าว (ที่นี่ 0.1 ใหญ่เกินจะกระโดดไปมา เล็กเกินจะช้ามาก); **backward** = หา gradient ด้วยกฎลูกโซ่จาก loss ไปถึงพารามิเตอร์ทุกตัว การดำเนินการของ `Graph`: `matmul`, `add` (ตารางแถวเดียวถูกบวกเข้าทุกแถว: bias), `mul`, `relu`, `tanh`, `sigmoid`, `gelu`, `silu`, `softmax_ce`, `mse`, `embed`, `layer_norm`, `rms_norm`, `attention`, `conv2d`, `maxpool` gradient ทุกตัวของไลบรารีถูกตรวจกับผลต่างเชิงตัวเลขในเทส คุณทำเองกับไอเดียของคุณได้ (เปลี่ยนเลขไป 0.01 ทั้งสองทางแล้วดูว่า loss เปลี่ยนตามที่ gradient บอก)

**ลอง:** เปลี่ยน 300 เป็น 30 สเต็ปแล้วดู `w` หยุดก่อนถึง; เปลี่ยนจุดเป็น `y = -3x + 4`

## บทที่ 71. สอนโครงข่าย: ชั้น, batch และ AdamW


เซลล์ประสาทเดียวเรียนรู้เส้นตรง ถ้าจะเรียนเส้นโค้งหรือแยกคลาส ต้องมีหลายชั้นโดยมีส่วนโค้งคั่น **`Linear`** คือ `x @ w + b`; ระหว่างชั้นใส่ `tanh` (หรือ `relu`) ไม่งั้นทุกชั้นยุบเป็นเส้นตรงเส้นเดียว การทดสอบคลาสสิกคือ XOR ที่เส้นตรงเส้นเดียวทำไม่ได้

```jk
#import <stdlib>
#import <neuron>

Graph g;

int main() {
    g = Graph::make();
    Linear l1 = g.linear(2, 8, 1);               // 2 numbers in, 8 out; the last number only seeds the start values
    Linear l2 = g.linear(8, 1, 2);
    g.mark();
    double[] xv = arr(8);
    xv.push(0.0); xv.push(0.0); xv.push(0.0); xv.push(1.0); xv.push(1.0); xv.push(0.0); xv.push(1.0); xv.push(1.0);
    double[] yv = arr(4);
    yv.push(0.0); yv.push(1.0); yv.push(1.0); yv.push(0.0);
    Tensor32 xs = Tensor32::from_list(4, 2, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    double last = 0.0;
    for step in 0..400 {
        int h = g.tanh(g.apply(l1, g.input(xs)));
        int out = g.sigmoid(g.apply(l2, h));                 // 0 .. 1
        int loss = g.mse(out, ys);
        last = (double)g.value(loss).d[0];
        g.backward(loss);
        g.adamw(0.05, 0.0);                                  // AdamW: a learning rate for each number, adjusted as it goes
        g.clear();
    }
    jout << "loss " << last << "\n";
    int h2 = g.tanh(g.apply(l1, g.input(xs)));
    Tensor32 o = g.value(g.sigmoid(g.apply(l2, h2)));
    for i in 0..4 { jout << xs.get(i, 0) << " xor " << xs.get(i, 1) << " = " << o.get(i, 0) << "\n"; }
    g.save("xor.model");                                     // the parameters as a text file
    return 0;
}
```

เมื่อมีตัวอย่างมาก ให้ใช้ **mini-batch**: `shuffled(n, seed)` ให้ลำดับสลับของ `0..n-1`, `xs.gather(idx)` ดึงแถวเหล่านั้น `g.clip(5.0)` ย่อ gradient ที่ใหญ่เกิน และ `Sched::cosine(step, total, warm, lr, low)` ทำให้ learning rate ขึ้นใน `warm` สเต็ปแล้วลดแบบโคไซน์ ถ้าจะแยก **คลาส** ให้จบด้วย `g.softmax_ce(scores, classes)` (หนึ่งเลขคลาสต่อหนึ่งแถว) บันทึกและโหลด: `g.save(path)`, `g.load(path)` บนกราฟที่มีพารามิเตอร์เหมือนกัน

**ระวัง:** loss ที่ไม่ลด (learning rate ใหญ่หรือเล็กเกิน), loss บนข้อมูลที่เรียนลดแต่ loss บนข้อมูลที่ไม่เคยเห็นไม่ลด (โมเดลแค่จำ: เพิ่มข้อมูลหรือลดขนาดโมเดล)

## บทที่ 72. โมเดลภาษาที่คุณเทรนบนมือถือ


โมเดลภาษาอ่านข้อความแล้วเรียนว่าตัวอักษร (หรือคำ) ถัดไปคืออะไร `Gpt` ใน `<neuron>` คือ GPT ตัวเล็ก: embedding, บล็อกที่มี attention (ทุกตำแหน่งมองตำแหน่งก่อนหน้า) และชั้นที่ให้คะแนนโทเคนถัดไป ทำงาน **ทีละไบต์** ภาษาไทย อังกฤษ และโค้ดจึงไม่ต้องมีตัวตัดคำ

```jk
#import <stdlib>
#import <neuron>

Gpt m;

int main() {
    String text = "the cat sat on the mat. the dog sat on the log. ";
    String all = "";
    for r in 0..40 { all = all + text; }
    int[] data = Gpt::bytes(all);                            // the text as numbers 0-255
    m = Gpt::make(256, 16, 32, 2, 1, 1);                     // vocabulary, context, width, heads, layers, seed
    int seed = 1;
    for step in 0..200 {
        int[] starts = arr(5);                               // where in the text this batch of 4 sequences starts
        for q in 0..4 { seed = (seed * 1103515245 + 12345) & 2147483647; starts.push(seed % (data.len - 20)); }
        double loss = m.step(data, starts, 0.02, 0.0, 1.0);  // learning rate, weight decay, clip
        if step % 50 == 0 { jout << "step " << step << " loss " << loss << "\n"; }
    }
    jout << "[" << m.write(Gpt::bytes("the cat s"), 24, 0.0, 0, 1) << "]\n";   // temperature 0: the most likely letter each time
    m.save("cats.gpt");
    return 0;
}
```

เครื่องมือ `neuron` ทำสิ่งเดียวกันกับไฟล์หรือโฟลเดอร์ใดก็ได้: `neuron gpt train notes.txt`, `neuron gpt train docs/ size=medium minutes=10` แล้ว `neuron gpt write cats.gpt "the cat"` ระหว่างเทรนมันพิมพ์ loss **check** ที่วัดบนหนึ่งในสิบส่วนท้ายของข้อความที่ไม่เคยถูกเรียน: นั่นคือเลขที่ควรเชื่อ ถ้า loss บนข้อความที่เรียนลดแต่ check ไม่ลด แปลว่าโมเดลแค่จำ

โมเดลที่เทรนบนมือถือมีเลขหลักพันถึงไม่กี่ล้านตัวและอ่านข้อมูลระดับเมกะไบต์ มันเรียนสไตล์และนิสัยของข้อความที่อ่าน (สไตล์โค้ด ภาษา โน้ตของคุณ) และเติมบรรทัดได้ แต่ไม่รู้จักโลกเหมือนโมเดลใหญ่ ใช้กับงานแคบๆ ด้วยข้อความของคุณเอง โดยมีการค้นหานำหน้าสำหรับข้อเท็จจริง

## บทที่ 73. รันโมเดลที่คนอื่นทำ: GGUF และ `<llama>`


โมเดลใหญ่ถูกเทรนที่อื่นแล้วแจกเป็นไฟล์ **GGUF** (รูปแบบของ llama.cpp) `<gguf>` อ่านมัน (ส่วนหัว คำ ตารางตัวเลข) และ `<llama>` รันตระกูล Llama บน CPU: RMS norm, ตำแหน่งแบบหมุน, grouped-query attention, feed-forward แบบมีประตู และแคชที่จำโทเคนก่อนหน้า น้ำหนักมักถูก **quantise** (Q8_0, Q4_0: หนึ่งไบต์หรือสี่บิตต่อน้ำหนัก พร้อมสเกลทุก 32 ตัว): ไฟล์เล็กลง 4–8 เท่า และเมื่อเก็บเป็นไบต์ในหน่วยความจำ การคูณอ่านหน่วยความจำน้อยลง 4 เท่า (ขีดจำกัดของมือถือคือแบนด์วิดท์หน่วยความจำ ไม่ใช่ความเร็วคูณ) การคูณใช้คำสั่ง int8 dot ของชิป (`i8x16` บทที่ 74)

```jk
#import <stdlib>
#import <llama>

int main() {
    switch Lm::load("stories15M-q4_0.gguf") {                // from huggingface.co/ggml-org/tiny-llamas (19 MB)
        Result::Ok(m): {
            int[] ids = m.encode("Once upon a time");        // token numbers, the start token first
            String story = m.generate(ids, 80, 0.8, 40, 0.95, 1);    // 80 new tokens: temperature, top-k, top-p, seed
            jout << "Once upon a time" << story << "\n";
        }
        Result::Err(e): { jout << "cannot load: " << e.message << "\n"; }
    }
    return 0;
}
```

อุณหภูมิกำหนดว่าเลือกกล้าแค่ไหน (0 = เลือกโทเคนที่น่าจะเป็นที่สุดเสมอ); `top-k` เก็บ k ตัวดีที่สุด `top-p` เก็บตัวดีที่รวมกันได้โอกาส p; seed เดียวกันได้ข้อความเดียวกัน ถ้าจะทีละโทเคน ใช้ `m.step(token)` (ให้คะแนนของโทเคนถัดไป) และ `m.sample(scores, temp, top_k, top_p)` จากเชลล์: `neuron llama MODEL.gguf "start"` และ `neuron bench MODEL.gguf` (โทเคนต่อวินาที) บน Kirin 990 โมเดล 15 ล้านตัวเขียนได้ราว 120 โทเคนต่อวินาที; โมเดล 500 ล้านตัวต้องอ่านหน่วยความจำหนึ่งในสี่กิกะไบต์ต่อโทเคน จึงได้แค่ไม่กี่โทเคนต่อวินาทีจนกว่าหน่วยความจำจะเร็วขึ้น

## บทที่ 74. โค้ดที่เร็ว: ภาษามีต้นทุนเท่าไรและขอความเร็วอย่างไร


วัดก่อนแก้ `bench/lang.jk` ใน repository วัดต้นทุนเล็กๆ บนมือถือของคุณ ผลบน Kirin 990 (หนึ่งคอร์):

| อะไร | ต้นทุน |
|---|---|
| `s += a[i]` บน `int[]` (มีเช็ก) / ผ่านพอยน์เตอร์ `int^` | 1.4 ns / 1.0 ns: การเช็กกินราว 40 % |
| `f += xs[i]` บน `float[]` | 4 ns: ตอนนี้ float ช้ากว่าจำนวนเต็ม (จุดอ่อนที่รู้แล้ว) |
| เรียกฟังก์ชันเล็ก | 2 ns |
| อ่านอาร์เรย์ใหญ่ 8 ล้านครั้ง: ต่อเนื่อง / ห่าง 16 ตัว / สุ่ม | 2.5 / 6.5 / 23 ns ต่อครั้ง: **แคชเป็นตัวตัดสิน** |

สามนิสัยที่คุ้มเสมอ: **เดินหน่วยความจำตามลำดับ** (ลูปในสุดวิ่งตามดัชนีที่อยู่ติดกัน), **ทำเป็นบล็อก** ที่พอดีแคช (การคูณเมทริกซ์ใน `<neuron>` ทำทีละสี่คอลัมน์สองแถว), และ **ให้ชิปทำหลายตัวเลขพร้อมกัน** `<simd>` มีเวกเตอร์ขนาดหนึ่งรีจิสเตอร์: `f32x4` (float สี่ตัว), `i32x4`, `f64x2` และ `i8x16` (สิบหกไบต์)

```jk
#import <stdlib>
#import <simd>

// the dot product of two float arrays, four numbers at a time
float dot(float^ a, float^ b, int n) {            // n a multiple of 4
    f32x4 acc = {0.0, 0.0, 0.0, 0.0};
    int i = 0;
    while i < n {
        acc = acc + f32x4::load(a, i) * f32x4::load(b, i);     // one load and one multiply-add for four numbers
        i += 4;
    }
    return acc.sum();
}

int main() {
    float[] a = arr(1001);
    float[] b = arr(1001);
    for i in 0..1000 { a.push((float)i * 0.001); b.push(2.0); }
    jout << dot(@a[0], @b[0], 1000) << "\n";     // 999
    return 0;
}
```

`i8x16` มีอีกอย่างคือ `a.dot(b)`: dot product ของสิบหกไบต์กับสิบหกไบต์ได้ผลบวก 32 บิตสี่ตัวใน **คำสั่งเดียว** (SDOT ของ Cortex-A76) มันทำให้โมเดล quantise เร็ว: `i32x4 d = i8x16::load(w, i).dot(i8x16::load(x, i));` ให้ฟังก์ชันที่ใช้เวกเตอร์เล็กและไม่มีการเรียกฟังก์ชันในลูป คอมไพเลอร์จะได้เก็บเวกเตอร์ทุกตัวในรีจิสเตอร์ (ดูด้วย `jcmp -show NAME file.jk` และ `jcmp -irstat file.jk`) และเปรียบเทียบกับ C ธรรมดาเมื่อสำคัญ: เป้าของ J2K คือห่างจาก C ไม่กี่เท่า และเลขใน `bench/` บอกว่าตอนนี้อยู่ตรงไหน

## บทที่ 75. โปรแกรมและไลบรารีจากเน็ต: `jc`


`jc` นำของมาที่มือถือ สี่ชนิด หนึ่งคำสั่งต่อชนิด:

```text
jc install NAME          a tool of Jcmp-Tools (jsh, neuron, mulap, imgj ...), or a package (git, python, clang ...)
jc tools                 the list of tools         jc update        every tool and package that has a newer version
jc lib list              the libraries of J2K      jc lib install web telegram    a library for #import <name>
jc pkg search git        look in the packages      jc pkg list | remove NAME
jc install FILE.jc       a program of the Jaric store (it asks for the permissions it wants)
```

เครื่องมือ (tool) คือโปรแกรมเดี่ยวที่เขียนด้วย J2K (`jc install neuron`) **แพ็กเกจ (package)** คือโปรแกรมของคนอื่นที่สร้างให้ตรงกับ prefix ของแอป Jaric (`jc install git`, `python`, `python-pip`, `clang`, `dropbear`): แตกลงใน prefix และจดรายการไว้ใน `usr/var/lib/jcpkg/ชื่อ.list` เพื่อให้ `jc pkg remove ชื่อ` เอาออกได้พอดีกับที่ใส่ ไลบรารีคือไฟล์เดียว (`#import <ชื่อ>`): `jc lib install ชื่อ` วางไฟล์ในที่ที่คอมไพเลอร์หา ทุกอย่างถูกตรวจ SHA-256 ก่อนวางลงที่ ถ้า checksum ผิดจะไม่ติดตั้งอะไรเลย

ถ้าจะแชร์เครื่องมือของคุณ: โฟลเดอร์ที่มีโปรแกรม `build.sh`, `test.sh`, `README.md`, `CHANGELOG.md`, `VERSION` ทดสอบ ปล่อยแบบที่ repository Jcmp-Tools ทำ และบรรทัดใน `tools.txt` ทำให้ `jc install` หาเจอ เครื่องมือและไลบรารีทุกตัวต้องมี README ที่บอกว่าคืออะไร ติดตั้งอย่างไร และใช้อย่างไรพร้อมตัวอย่างที่ใช้ได้จริง: เมื่ออ่าน README ที่ไม่สอนอะไร ให้แก้ README

# ภาค 4: จากตัวเลขสู่เครื่อง

## บทที่ 76. นับเลขฐาน 2 และฐาน 16


คอมพิวเตอร์มีเลขแค่สองตัว 0 กับ 1 เพราะสายไฟมีแค่เปิดกับปิด เลข **ฐาน 2** เขียนด้วยสองตัวนี้: `1011` แปลว่า 1x8 + 0x4 + 1x2 + 1x1 = 11 หลักแต่ละหลักมีค่าเป็นสองเท่าของหลักทางขวา: 1, 2, 4, 8, 16, 32, 64, 128 ... หนึ่งหลักคือ **บิต** แปดบิตคือ **ไบต์** (0 ถึง 255) **ฐาน 16** (hex) มีสิบหกตัวคือ `0-9` กับ `a-f` และหนึ่งหลัก hex เท่ากับสี่บิตพอดี คนจึงอ่านไบต์เป็น hex: `0xB0` คือ `1011 0000`

```jk
#import <stdlib>

// the number n as `width` bits, the highest first
String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

// the number n as hex digits (at least `width` of them)
String hex(int n, int width) {
    String digits = "0123456789abcdef";
    String s = "";
    int i = width - 1;
    while i >= 0 {
        int d = (n >> (4 * i)) & 15;
        s.push(digits[d]);
        i -= 1;
    }
    return s;
}

int main() {
    for n in 0..9 { jout << n << " = " << bits(n, 8) << " = 0x" << hex(n, 2) << "\n"; }
    jout << "255 = " << bits(255, 8) << " = 0x" << hex(255, 2) << "\n";
    jout << "256 = " << bits(256, 9) << " = 0x" << hex(256, 3) << "\n";
    int x = 0;
    for i in 0..8 { x = x * 2 + (i % 2); }                  // shifting left and adding a bit is how a number is read digit by digit
    jout << x << " = " << bits(x, 8) << "\n";                // 01010101 = 85
    return 0;
}
```

`n >> i` เลื่อนบิตไปทางขวา `i` ที่ `& 1` เก็บบิตล่างสุด ดังนั้น `(n >> i) & 1` คือบิตที่ `i` การคูณสองเลื่อนบิตทั้งหมดไปซ้ายหนึ่งที่ (`n << 1`) การหารสองเลื่อนไปขวา ไบต์มี 8 บิต `short` มี 16 `int` ของ J2K มี 64

**ลอง:** พิมพ์ยกกำลังของสองถึง 2^16 เป็นฐานสองและ hex; เขียนฟังก์ชันที่แปลงข้อความ `"1011"` เป็น 11

## บทที่ 77. จำนวนลบ: two's complement


จำนวนลบทำจากบิตอย่างไร? CPU ใช้ **two's complement**: ถ้ามี 8 บิต -1 คือ `11111111`, -2 คือ `11111110`, ... -128 คือ `10000000` บิตสูงสุดคือเครื่องหมาย (1 = ลบ) และมีค่า -128 แทน +128 กฎการกลับเครื่องหมาย: **พลิกทุกบิตแล้วบวกหนึ่ง** ทำให้ `x + (-x)` เป็นศูนย์ทั้งหมดกับตัวทดที่ตกหายไป วงจรบวกตัวเดียวจึงบวกทั้งเลขบวกและลบ และการลบไม่ต้องมีชิ้นส่วนใหม่

```jk
#import <stdlib>

String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

int main() {
    for n in 0..4 { jout << "-" << n << " in 8 bits: " << bits(-n, 8) << "\n"; }       // 00000000 11111111 11111110 11111101
    int five = 5;
    int flipped = five xor 255;                     // every bit of the 8 turned over
    jout << "flip 5: " << bits(flipped, 8) << "  plus one: " << bits((flipped + 1) & 255, 8) << " = " << bits(-5, 8) << "\n";
    i8 small = 127;                                  // the biggest i8
    small += 1;                                      // one more wraps round to the smallest
    jout << "127 + 1 in an i8 = " << small << "\n";
    u8 byte = 200;
    byte += 100;                                     // 300 does not fit: 300 - 256
    jout << "200 + 100 in a u8 = " << byte << "\n";
    jout << "the same bits, two meanings: " << bits(200, 8) << " is 200 as u8, " << (200 - 256) << " as i8\n";
    return 0;
}
```

`int` ของ J2K มี 64 บิต เลขที่เล็กสุดคือ -2^63 ใหญ่สุด 2^63 - 1 บวกหนึ่งจากเลขที่ใหญ่สุดจะวนไปเป็นเลขเล็กสุด `i8`, `i16`, `i32` และ `u8` ... `u64` (บทที่ 54) แสดงเรื่องเดียวกันในขนาดเล็กกว่า เมื่อขยายเลขมีเครื่องหมายขนาดเล็กให้กว้างขึ้น บิตเครื่องหมายถูกคัดลอกไปที่ใหม่ (**sign extension**): `11111110` แบบ 8 บิตกับ `1111111111111110` แบบ 16 บิตต่างก็คือ -2

**ลอง:** 100 + 100 ใน i8 และ 0 - 1 ใน u8 ได้เท่าไร? ลองคิดด้วยมือจากบิตก่อน

## บทที่ 78. ตัวเลขมีจุด: ข้างใน


`double` คือ 64 บิตแบ่งเป็นสามส่วน (**IEEE 754**): 1 บิตเครื่องหมาย, 11 บิตเลขชี้กำลัง, 52 บิตเศษ ค่าคือ `(-1)^เครื่องหมาย x 1.เศษ x 2^(เลขชี้กำลัง - 1023)` `float` มี 1 + 8 + 23 บิต ตัวเลขที่ float เก็บได้จึงไม่กระจายเท่ากัน: ระหว่าง 1 ถึง 2 มีจำนวนเท่ากับระหว่าง 1024 ถึง 2048 และเลขอย่าง 0.1 เขียนแบบฐานสองได้ไม่พอดี (เหมือน 1/3 ในฐานสิบ) นั่นคือเหตุผลที่ `0.1 + 0.2` ไม่เท่ากับ `0.3` พอดี

```jk
#import <stdlib>

String bits(int n, int width) {
    String s = "";
    int i = width - 1;
    while i >= 0 {
        if ((n >> i) & 1) == 1 { s.push('1'); } else { s.push('0'); }
        i -= 1;
    }
    return s;
}

void show(double d) {
    int^ p = (int^)@d;                               // the same 8 bytes, looked at as a whole number
    int raw = p[0];
    int sign = (raw >> 63) & 1;
    int exponent = (raw >> 52) & 2047;
    int fraction = raw & 4503599627370495;           // the lowest 52 bits
    jout << d << ": sign " << sign << ", exponent " << bits(exponent, 11) << " (" << exponent - 1023 << "), fraction " << bits(fraction >> 40, 12) << "...\n";
}

int main() {
    show(1.0);
    show(2.0);
    show(0.5);
    show(-6.0);                                      // -1.5 x 2^2
    show(0.1);
    double s = 0.1 + 0.2;
    if s == 0.3 { jout << "0.1 + 0.2 is 0.3\n"; } else { jout << "0.1 + 0.2 is not exactly 0.3\n"; }
    return 0;
}
```

เปรียบเทียบตัวเลขที่วัดมาด้วยช่วงคลาดเคลื่อนเล็กๆ (`abs(a - b) < 0.000001`) อย่าใช้ `==` และอย่าบวกเลขเล็กมากเข้ากับเลขใหญ่มาก: เลขเล็กจะหาย เพราะเศษมีแค่ 52 บิต (`1e16 + 1.0` ได้ `1e16`)

**ลอง:** แสดงบิตของ 3.0 แล้วหาเครื่องหมาย เลขชี้กำลัง และเศษด้วยมือ; หา `x` ที่เล็กที่สุดที่ `1.0 + x == 1.0` (เริ่มจาก 1.0 แล้วหารสองไปเรื่อยๆ)

## บทที่ 79. จากประตูตรรกะสู่ตัวบวก


CPU ทำจาก **ประตู (gate)**: AND, OR, XOR, NOT และบวกได้ด้วยประตูเหล่านี้ การบวกสองบิต `a + b` ได้บิตผลบวกและบิตทด: ผลบวกคือ `a xor b` ทดคือ `a and b` (**half adder**) ถ้ามีตัวทดเข้ามาด้วยก็เป็น **full adder** และแปดตัวต่อกัน แต่ละตัวส่งตัวทดให้ตัวถัดไป บวกสองไบต์ได้ (**ripple adder**) นี่คือคำสั่ง `add` ในซิลิคอน

```jk
#import <stdlib>

// one full adder: three bits in (a, b and the carry from the right), two bits out
// the sum goes in sum[0], the carry out is the result
int full_adder(int a, int b, int carry_in, int^ sum) {
    int x = a xor b;
    sum[0] = x xor carry_in;
    return (a & b) | (x & carry_in);
}

// two 8-bit numbers added with eight full adders in a row
int add8(int a, int b) {
    int result = 0;
    int carry = 0;
    int sum[1];
    for i in 0..8 {
        carry = full_adder((a >> i) & 1, (b >> i) & 1, carry, @sum[0]);
        result = result | (sum[0] << i);
    }
    return result;                                   // a carry out of the last place falls off, as in a u8
}

// the multiplier of school: shift and add
int mul8(int a, int b) {
    int result = 0;
    for i in 0..8 {
        if ((b >> i) & 1) == 1 { result = add8(result, (a << i) & 255); }
    }
    return result;
}

int main() {
    jout << add8(100, 55) << " " << add8(200, 100) << " " << add8(255, 1) << "\n";      // 155 44 0
    int bad = 0;
    for a in 0..256 { for b in 0..256 { if add8(a, b) != (a + b) & 255 { bad += 1; } } }
    jout << "all 65536 sums agree with +: " << (bad == 0) << "\n";
    jout << mul8(12, 11) << " " << mul8(20, 20) << "\n";                                  // 132 144 (400 wraps)
    return 0;
}
```

CPU จริงทำทั้งแปด (หรือ 64) หลักพร้อมกันด้วยวงจรฉลาดชื่อ **carry-lookahead** ตัวทดจึงไม่ต้องเดินผ่านทุกหลัก แต่แนวคิดเหมือนกัน และคุณจะเห็นว่าทำไม `a + b` ใช้รอบเดียวส่วนการหารไม่ใช่

**ลอง:** สร้างตัวลบจาก `add8` (กลับเครื่องหมายด้วยกฎของบทที่ 77: พลิกแล้วบวกหนึ่ง); สร้างตัวเปรียบเทียบ 4 บิตด้วยประตูเท่านั้น

## บทที่ 80. CPU จิ๋วของเราเอง


โปรเซสเซอร์ทำอะไร? มันวนสามขั้นตอนไม่สิ้นสุด: **fetch** อ่านคำสั่งถัดไปจากหน่วยความจำที่ตำแหน่งของ **program counter**, **decode** ถอดความ (ทำอะไร ใช้รีจิสเตอร์ไหน), **execute** ทำ ด้านล่างคือ CPU ทั้งตัวในไม่กี่บรรทัด: รีจิสเตอร์สี่ตัว หน่วยความจำเป็นไบต์ และเจ็ดคำสั่ง แต่ละคำสั่งมีหนึ่งไบต์บอกการทำงานแล้วตามด้วยตัวเลขหนึ่งหรือสองไบต์ นี่คือ **เครื่องเสมือน (virtual machine)** ชิปจริงก็เรื่องเดียวกันแต่มีคำสั่งมากกว่าและเร็วกว่า

| opcode | ความหมาย |
|---|---|
| 1 r n | `r = n` (ใส่เลข) |
| 2 r s | `r = r + s` (บวกรีจิสเตอร์ s) |
| 3 r s | `r = r - s` |
| 4 r n | `ถ้า r != 0 ให้ pc = n` (กระโดด) |
| 5 r | พิมพ์รีจิสเตอร์ r |
| 6 | หยุด |

```jk
#import <stdlib>

int[] mem;                                           // the program, as bytes
int reg[4];
int pc;

// one step: fetch, decode, execute; false after the instruction "stop"
bool step() {
    int op = mem[pc];                                // fetch
    if op == 1 { reg[mem[pc + 1]] = mem[pc + 2]; pc += 3; }                          // r = n
    else if op == 2 { reg[mem[pc + 1]] += reg[mem[pc + 2]]; pc += 3; }              // r = r + s
    else if op == 3 { reg[mem[pc + 1]] -= reg[mem[pc + 2]]; pc += 3; }              // r = r - s
    else if op == 4 { if reg[mem[pc + 1]] != 0 { pc = mem[pc + 2]; } else { pc += 3; } }   // jump if not zero
    else if op == 5 { jout << "r" << mem[pc + 1] << " = " << reg[mem[pc + 1]] << "\n"; pc += 2; }
    else { return false; }                           // 6 (or anything else): stop
    return true;
}

int main() {
    mem = arr(32);
    // r0 = 0 (the sum), r1 = 5 (the counter), r2 = 1: add the counter to the sum, count down, until the counter is 0
    int[] program = arr(24);
    program.push(1); program.push(0); program.push(0);          //  0: r0 = 0
    program.push(1); program.push(1); program.push(5);          //  3: r1 = 5
    program.push(1); program.push(2); program.push(1);          //  6: r2 = 1
    program.push(2); program.push(0); program.push(1);          //  9: r0 = r0 + r1
    program.push(3); program.push(1); program.push(2);          // 12: r1 = r1 - r2
    program.push(4); program.push(1); program.push(9);          // 15: if r1 != 0 then jump to 9
    program.push(5); program.push(0);                           // 18: print r0
    program.push(6);                                            // 20: stop
    for i in 0..program.len { mem.push(program[i]); }
    pc = 0;
    int steps = 0;
    while step() { steps += 1; }
    jout << "ran " << steps << " instructions\n";                // the sum 5+4+3+2+1 = 15 printed once
    return 0;
}
```

โปรแกรมทุกตัวคือตัวเลขในหน่วยความจำ CPU ไม่รู้ว่าไบต์ไหนเป็นโค้ดไบต์ไหนเป็นข้อมูล program counter เป็นคนตัดสิน นี่คือเหตุผลที่บั๊กทำให้ข้อมูลของคุณถูกรันเป็นโค้ดได้ และเหตุผลที่การ **กระโดด** (เปลี่ยน `pc`) คือทั้งหมดของลูปและ `if` ในระดับนี้ เครื่องจิ๋วนี้เรียกฟังก์ชันไม่ได้: ถ้าเพิ่มรีจิสเตอร์เก็บที่อยู่กลับ (**link register**, คือ `x30` ใน ARM64) กับสองคำสั่ง `call n` และ `ret` ก็ทำได้

**ลอง:** เพิ่มคำสั่ง `7 r s` ที่คูณ; เขียนโปรแกรมที่ใช้มันคำนวณ 5 x 4 x 3; เพิ่มคำสั่งหน่วยความจำ `load r a` / `store r a`

## บทที่ 81. assembler สำหรับ CPU จิ๋ว


ตัวเลขอ่านยากสำหรับคน จึงมี **assembler** แปลงข้อความอย่าง `add r0, r1` เป็นตัวเลข (**machine code**) มันอ่านบรรทัด ค้นคำ (**mnemonic**) อ่านตัวถูกดำเนินการแล้วเขียนไบต์ ป้ายชื่อ (ชื่อของตำแหน่ง) ต้องแก้ในรอบที่สองเพราะการกระโดดอาจไปข้างหน้า ด้านล่างคือตัวเล็กสำหรับเครื่องของบทที่ 80

```jk
#import <stdlib>

// the register number of "r2": 2 (or -1)
int reg_of(String w) {
    if w.len == 2 && w[0] == 'r' && w[1] >= '0' && w[1] <= '3' { return w[1] - '0'; }
    return -1;
}

// the lines of a program, one instruction each: "load r1, 5" "add r0, r1" "sub r1, r2" "jnz r1, loop" "print r0" "stop", and "name:" for a label
// returns the bytes, or an empty array when a line is wrong (the message says which)
int[] assemble(String[] lines) {
    String[] labels = arr(8);
    int[] at = arr(8);
    int[] out = arr(64);
    int[] none = arr(1);
    for pass in 0..2 {                                       // pass 0 finds where the labels are, pass 1 writes the bytes
        out = arr(64);
        for k in 0..lines.len {
            String line = lines[k].trim();
            if line.len == 0 { continue; }
            if line[line.len - 1] == ':' {
                if pass == 0 { labels.push(line.slice(0, line.len - 1) + ""); at.push(out.len); }
                continue;
            }
            String[] w = line.replace(",", " ").split(" ");
            String[] p = arr(4);
            for i in 0..w.len { if w[i].len > 0 { p.push(w[i] + ""); } }
            String m = p[0];
            if m == "load" { out.push(1); out.push(reg_of(p[1])); out.push(p[2].to_int()); }
            else if m == "add" { out.push(2); out.push(reg_of(p[1])); out.push(reg_of(p[2])); }
            else if m == "sub" { out.push(3); out.push(reg_of(p[1])); out.push(reg_of(p[2])); }
            else if m == "jnz" {
                int target = -1;
                for j in 0..labels.len { if labels[j] == p[2] { target = at[j]; } }
                if target < 0 && pass == 1 { jout << "unknown label " << p[2] << "\n"; return none; }
                out.push(4); out.push(reg_of(p[1])); out.push(target);
            }
            else if m == "print" { out.push(5); out.push(reg_of(p[1])); }
            else if m == "stop" { out.push(6); }
            else { jout << "unknown instruction " << m << " in the line: " << line << "\n"; return none; }
        }
    }
    return out;
}

int main() {
    String[] src = arr(12);
    src.push("load r0, 0"); src.push("load r1, 5"); src.push("load r2, 1");
    src.push("again:");
    src.push("add r0, r1"); src.push("sub r1, r2"); src.push("jnz r1, again");
    src.push("print r0"); src.push("stop");
    int[] code = assemble(src);
    String line = "";
    for i in 0..code.len { line = line + str(code[i]) + " "; }
    jout << code.len << " bytes: " << line << "\n";           // the program of lesson 80
    String[] bad = arr(2);
    bad.push("jump somewhere");
    assemble(bad);                                            // unknown instruction jump in the line: jump somewhere
    return 0;
}
```

assembler จริงของ J2K เป็นเรื่องเดียวกัน (`jcmp/jc_asm.j`) แต่คำสั่งเป็นของ ARM64: แต่ละคำสั่งคือคำ 32 บิตเดียวที่มีช่องสำหรับการทำงานและรีจิสเตอร์ (บทที่ 82) มันต้องเลือกระหว่างหลายรูปแบบของ mnemonic เดียว (กระโดดสั้นกับยาว) และเช็กว่าตัวเลขพอดีกับช่อง: assembler ที่ดีจะบอกว่า "เลขไม่พอดี" แทนที่จะเขียนคำที่ผิด

**ลอง:** เพิ่มคำสั่ง `mul`; ทำให้ assembler บอกเลขบรรทัดที่ผิด; เขียน "disassembler" ที่แปลงไบต์กลับเป็นข้อความ

## บทที่ 82. ของจริง: คำสั่ง ARM64 เป็น 32 บิต


ทุกคำสั่งของ CPU ARM64 ในมือถือยาว **32 บิต** พอดี แบ่งเป็นช่อง `add x1, x1, x2` (บวกรีจิสเตอร์ 64 บิต) คือ:

```
 31 30 29 28-24 23-22 21 20-16  15-10  9-5  4-0
  1  0  0 01011  00    0  Rm    000000  Rn   Rd        =  0x8B000000 | (Rm << 16) | (Rn << 5) | Rd
```

`Rm` = 2, `Rn` = 1, `Rd` = 1 ได้ `0x8B020021` โปรแกรมสร้างคำนี้เองแล้วเทียบกับเลขที่ assembler ของคอมไพเลอร์ทำได้ (บทที่ 38 แสดงวิธี `raw<u32>[...]` ใส่คำลงในโค้ด)

```jk
#import <stdlib>

String hex(int n, int width) {
    String digits = "0123456789abcdef";
    String s = "";
    int i = width - 1;
    while i >= 0 { s.push(digits[(n >> (4 * i)) & 15]); i -= 1; }
    return s;
}

// add xd, xn, xm  (64 bits)
int encode_add(int d, int n, int m) { return 0x8B000000 | (m << 16) | (n << 5) | d; }

// sub xd, xn, xm
int encode_sub(int d, int n, int m) { return 0xCB000000 | (m << 16) | (n << 5) | d; }

// mov xd, #imm16  (movz: the number in bits 5-20)
int encode_movz(int d, int imm) { return 0xD2800000 | (imm << 5) | d; }

int main() {
    jout << "add x1, x1, x2  = 0x" << hex(encode_add(1, 1, 2), 8) << "\n";     // 8b020021
    jout << "sub x0, x3, x4  = 0x" << hex(encode_sub(0, 3, 4), 8) << "\n";     // cb040060
    jout << "mov x5, #1000   = 0x" << hex(encode_movz(5, 1000), 8) << "\n";    // d2807d05
    // run the word that we built: x1 = x1 + x2 through a raw machine word
    int a = 40;
    int b = 2;
    int r = 0;
    register {
        in x1 = a;
        in x2 = b;
        raw<u32>[0x8b020021];                        // the word that encode_add(1, 1, 2) made
        out x1 = r;
    }
    jout << a << " + " << b << " = " << r << " (done by the word)\n";
    return 0;
}
```

ดูโค้ดเครื่องที่คอมไพเลอร์ทำให้ฟังก์ชันของคุณด้วย `jcmp -show ชื่อ file.jk`: บรรทัดเหล่านั้นคือคำสั่งในรูปข้อความ และ `jcmp --emit-asm` เก็บข้อความทั้งหมด เพราะทุกคำสั่งขนาดเท่ากัน CPU จึงหาคำถัดไปได้ทันที (`pc + 4`) และถอดความหลายคำพร้อมกัน; CPU ที่คำสั่งยาวไม่เท่ากัน (x86) ต้องทำงานเพิ่มเพื่อหาว่าอันหนึ่งจบตรงไหน รีจิสเตอร์ `x0` ถึง `x7` เก็บอาร์กิวเมนต์ของการเรียนและ `x0` เก็บผลลัพธ์; `x29` คือเฟรม `x30` คือที่อยู่กลับ `sp` คือสแต็ก: บทที่ 35 ถึง 48 ใช้มัน

**ลอง:** เข้ารหัส `ldr x0, [x1]` (`0xF9400020` คือ `ldr x0, [x1, #0]`: หาช่อง); รัน `jcmp -show` กับฟังก์ชันที่บวกสองจำนวน หา `add` ในนั้นแล้วถอดบิตด้วยมือ

## บทที่ 83. จัดหน้าผลลัพธ์: คอลัมน์ ทศนิยม เลขฐานสิบหก


`jout <<` พิมพ์ค่าตามที่เป็น แต่ตาราง เงิน และที่อยู่ต้องจัดรูปแบบ: กี่หลักทศนิยม คอลัมน์กว้างเท่าไร เลขฐาน 16 J2K ไม่มี format string (`%5.2f`) และไม่มีไวยากรณ์ใหม่: การจัดหน้าทำด้วยฟังก์ชันธรรมดา ที่คุณใส่เข้าไปในสตรีม

| ฟังก์ชัน | ให้อะไร | ตัวอย่าง |
|---|---|---|
| `fmt(x, 2)` | ทศนิยมที่มี 2 หลักหลังจุด | `fmt(2.0 / 3.0, 3)` ได้ `0.667` |
| `tohex(n)` | เลขในฐาน 16 | `tohex(48879)` ได้ `beef` |
| `tobin(n)` | เลขในฐาน 2 | `tobin(37)` ได้ `100101` |
| `pad(s, w)` | ข้อความ แล้วเติมช่องว่างจนครบ `w` ตัว (ชิดซ้าย) | `pad("tea", 6)` ได้ `tea   ` |
| `padl(s, w)` | ช่องว่าง แล้วข้อความ (ชิดขวา: สำหรับตัวเลข) | `padl("7", 3)` ได้ `  7` |

ชื่อยาวอยู่ใน `Fmt`: `Fmt::fixed`, `Fmt::thousands(1234567)` (`1,234,567`), `Fmt::percent(0.256, 1)` (`25.6%`), `Fmt::bytes(1536)` (`1.5 KB`), `Fmt::pad_left(s, w, '0')` (เติมด้วยตัวอักษรใดก็ได้) ข้อความที่ยาวกว่าความกว้างจะไม่ถูกตัด

```jk
#import <stdlib>
using stdlib;

int main() {
    String[] items = arr(3);
    items.push("tea"); items.push("rice"); items.push("coconut milk");
    int[] cents = arr(3);
    cents.push(1250); cents.push(499); cents.push(1500000);
    for i in 0..items.len {
        jout << pad(items[i], 14) << padl(Fmt::thousands(cents[i] / 100), 9) << "." << Fmt::pad_left(str(cents[i] % 100), 2, '0') << "\n";
    }
    jout << "ratio " << fmt(2.0 / 3.0, 3) << "   hex " << tohex(48879) << "   bits " << tobin(37) << "\n";
    return 0;
}
```

ผลลัพธ์:

```
tea                  12.50
rice                  4.99
coconut milk     15,000.00
ratio 0.667   hex beef   bits 100101
```

(ราคาเก็บเป็นสตางค์เพื่อให้ผลรวมแม่น คอลัมน์สุดท้ายคือส่วนบาทที่มีจุลภาคคั่นหลักพัน จุด และสตางค์ที่เติม 0 ข้างหน้า) ทำไมไม่มี `printf`? คอมไพเลอร์รู้ชนิดของทุกค่าในสตรีม คุณจึงเขียน `%d` ให้ double ผิดไม่ได้ และภาษาก็เล็กอยู่

**ลอง:** พิมพ์ตารางสูตรคูณ 1 ถึง 9 เป็นคอลัมน์กว้าง 4 ด้วย `padl`; พิมพ์ `255` เป็น `ff`, `11111111` และ `0xFF` (ต่อ `"0x"` กับ `tohex`)

## บทที่ 84. หน้าจอของแอพ: `<ui>`


แอพ Android ที่สร้างด้วย `makej init -apk` วาดทุกเฟรมเองด้วย OpenGL ES `<ui>` (ติดตั้งด้วย `jc lib install ui`) ให้ปุ่ม ป้ายข้อความ สวิตช์ และสไลเดอร์ ทำงานแบบ *immediate mode*: ทุกเฟรมคุณเรียกวิดเจ็ตจากบนลงล่าง วิดเจ็ตวาดตัวเองและ **บอกว่าเกิดอะไรขึ้น** จึงไม่มีอะไรต้องคอยให้ตรงกับข้อมูลของคุณ

```text
Ui u;                              // หนึ่งตัวต่อแอพ
bool sound;  double speed;  int taps;

// game_init:   u.start();                    game_touch(a, x, y, id):  u.touch(a, x, y);
// game_frame:  Canvas2d^ c = glapp_canvas();  c^.begin();  c^.clear(u.th.bg);
//              u.begin(c, (double)glapp_w(), (double)glapp_h());
//              u.title("MY APP");
//              if u.button("TAP ME") { taps += 1; }            // เป็นจริงในเฟรมที่คลิก
//              u.toggle("SOUND", @sound);                        // แตะแล้ว sound เปลี่ยน
//              u.slider("SPEED", @speed, 0.0, 10.0);             // ลากแล้ว speed เปลี่ยน
//              u.cols(2);  u.button("A");  u.button("B");  u.end_cols();   // เคียงข้างกัน
//              u.end();  c^.end();
```

ปุ่มคลิกเมื่อนิ้วลง **และยก** ในกรอบของมัน (ผู้ใช้ที่ลากออกไปคือเปลี่ยนใจ) สีและขนาดอยู่ใน `u.th` ตอนนี้ข้อความเป็นฟอนต์ 3 x 5 ของตัวพิมพ์ใหญ่ ตัวเลข และเครื่องหมาย (ตัวพิมพ์เล็กและภาษาไทยอยู่ในแผน) หน้า (page) คือฟังก์ชันที่เรียกวิดเจ็ตแล้วคืนเลขหน้าถัดไป ดู `docs/UI.md` สำหรับรูปแบบของหน้า และวิธีทดสอบหน้าจอโดยไม่ต้องมีมือถือ (canvas จำลองที่นับการวาด: `test/t573_ui.jk`)

**ลอง:** เพิ่มสไลเดอร์ที่กำหนดขนาดสี่เหลี่ยมซึ่งคุณวาดใต้วิดเจ็ตด้วย `c^.rect`

## บทที่ 85. apk โดยไม่ต้องมีเครื่องมือ Android: `apkj`


apk คือไฟล์ zip ที่มีห้าส่วน: `AndroidManifest.xml` แบบไบนารี, `resources.arsc` (ที่เกือบว่างเปล่า), `classes.dex` (ส่วน Java เล็ก ๆ ที่เริ่มไลบรารีของคุณ), `libgame.so` ของคุณ และลายเซ็น เครื่องมือปกติ (`aapt2`, `ecj`, `d8`, `zipalign`, `apksigner`, Java) หนักสำหรับมือถือ `apkj` เป็นเครื่องมือที่เขียนด้วย J2K ที่ทำทั้งหมดเอง รวมถึงลายเซ็น (ECDSA P-256 พร้อมใบรับรองของตัวเอง):

```text
apkj key                                           # สร้าง ~/.apkj.key ครั้งเดียว เก็บไว้ (อัปเดตแอพต้องเซ็นด้วยกุญแจเดิม)
apkj build manifest.toml MyApp.apk lib/arm64-v8a/libgame.so=_out/libgame.so assets/data/hello.txt=assets/hello.txt
```

`makej apk` เรียกมันให้เมื่อขาดเครื่องมือ Android (หรือใช้ `MAKEJ_APKJ=1`) สำหรับแอพที่มี `render = "gl"` และไม่มี `icon.png` ตรวจด้วยเครื่องมือที่มีอยู่แล้ว: `apksigner verify MyApp.apk` ต้องบอก `Verifies`, `aapt2 dump badging MyApp.apk` แสดงชื่อและเวอร์ชัน และ `unzip -t` ไม่พบข้อผิดพลาด ถ้าขาดเครื่องมือ `makej` จะบอกว่าต้องติดตั้งอะไร (`jc install apkj` หรือแพ็กเกจ) แทนที่จะล้มด้วยข้อความยาว ๆ

**ลอง:** สร้าง manifest ด้วย `apkj manifest manifest.toml AndroidManifest.xml` และเปิดผลด้วย `aapt2 dump xmltree MyApp.apk --file AndroidManifest.xml` (หลัง `apkj build`); เปลี่ยน `version` ใน `manifest.toml` แล้วดู `versionCode` ตาม (`major * 10000 + minor * 100 + patch`)

## บทที่ 86. ดูอาร์เรย์เพียงบางส่วน: Span

บางครั้งฟังก์ชันควรทำงานกับอาร์เรย์เพียงส่วนเดียว เช่น ตรงกลาง สิบตัวสุดท้าย หรือหนึ่งแถวของตาราง การคัดลอกส่วนนั้นเสียเวลาและหน่วยความจำ **Span** คือมุมมอง: ชี้เข้าไปในอาร์เรย์และจำว่าเริ่มที่ไหน ยาวเท่าไร `a[2..6]` สร้าง Span ของสมาชิกที่ 2, 3, 4 และ 5 (ไม่รวมตัวท้าย เหมือน `for i in 2..6`) Span ไม่คัดลอกอะไร: การเขียนผ่านมันเปลี่ยนอาร์เรย์จริง

```jk
#import <stdlib>

using stdlib;
// the sum of a part of an array, without copying it
int total(Span<int> s) {
    int t = 0;
    for i in 0..s.len { t += s.get(i); }
    return t;
}

void main() {
    int[] a = arr(10);
    for i in 0..10 { a.push(i * i); }          // 0 1 4 9 16 25 36 49 64 81

    Span<int> mid = a[2..6];                   // the elements 2, 3, 4, 5: a view, not a copy
    jout << mid.len << " elements, the first is " << mid.get(0) << "\n";
    jout << "sum of the middle: " << total(mid) << "\n";

    mid.set(0, 100);                           // writes through to the array
    jout << "a[2] is now " << a[2] << "\n";

    Span<int> inner = mid.sub(1, 3);           // a view of a view: the elements 3 and 4 of the array
    jout << "inner: " << inner.get(0) << " " << inner.get(1) << "\n";
}

```

ผลลัพธ์:

```
4 elements, the first is 4
sum of the middle: 54
a[2] is now 100
inner: 9 16
```

Span มี `len`, `get(i)`, `set(i, v)` และ `sub(from, to)` (มุมมองของมุมมอง) ดัชนีนอก Span เป็น error ที่ `catch` ได้ ("span index out of range") ไม่ใช่การอ่านหน่วยความจำอื่นเงียบ ๆ `to_array()` ทำสำเนาจริงเมื่อต้องการ ส่ง Span ให้ฟังก์ชันเมื่อมันแค่ต้องดูช่วงหนึ่ง: ฟังก์ชันเดียวใช้ได้กับทั้งอาร์เรย์ ส่วนหนึ่ง หรือส่วนของส่วน

**ลอง:** เขียน `int biggest(Span<int> s)` แล้วเรียกกับครึ่งแรกและครึ่งหลังของอาร์เรย์

## บทที่ 87. ตัวอักษรจริง: อ่าน UTF-8 และไลบรารี <font>

ข้อความคือไบต์ อักษรอังกฤษใช้ตัวละหนึ่งไบต์ แต่อักษรไทยใช้สามไบต์ (UTF-8) ข้อความ 9 ตัวอักษรจึงยาว 21 ไบต์ ไลบรารีฟอนต์ต้องอ่านไบต์แล้วสร้างเลขประจำตัวอักษรแต่ละตัว (code point) ก่อนจะขอรูปร่างจากไฟล์ฟอนต์ โปรแกรมข้างล่างทำสิ่งนี้ด้วยมือ

```jk
#import <stdlib>
using stdlib;

// a text is bytes (UTF-8): a Thai letter is three bytes. This is how a font library reads it: byte by byte, building the number of each character.
int next_char(String s, int i, int^ len) {
    int c = s[i] & 255;
    if c < 128 { len^ = 1; return c; }
    if c >= 0xe0 { len^ = 3; return ((c & 15) << 12) | ((s[i + 1] & 63) << 6) | (s[i + 2] & 63); }
    len^ = 2;
    return ((c & 31) << 6) | (s[i + 1] & 63);
}

int main() {
    String s = "Hi สวัสดี";
    jout << "bytes: " << s.len << "\n";
    int i = 0;
    int letters = 0;
    while i < s.len {
        int n = 1;
        int cp = next_char(s, i, @n);
        jout << "U+" << padl(tohex(cp), 4) << " ";
        letters += 1;
        i += n;
    }
    jout << "\nletters: " << letters << "\n";
    return 0;
}

```

ผลลัพธ์:

```
bytes: 21
U+  48 U+  69 U+  20 U+ e2a U+ e27 U+ e31 U+ e2a U+ e14 U+ e35 
letters: 9
```

`<font>` (ติดตั้งด้วย `jc lib install font`) ทำส่วนที่เหลือ: เปิดไฟล์ TrueType (มือถือมีไว้ใน `/system/fonts`) หา glyph ของแต่ละ code point จากตาราง `cmap` อ่านเส้นขอบจาก `glyf` แล้วระบายเส้นขอบเป็นพิกเซลที่ขอบเนียน รูปร่างของอักษรสร้างครั้งเดียวแล้วเก็บเป็นรูปเล็ก ๆ จากนั้นวาดเหมือนรูปทั่วไป

```jk-no
Font f;
f.open("/system/fonts/Roboto-Regular.ttf");
f.add("/system/fonts/NotoSansThai-Regular.ttf");   // สำหรับตัวที่ฟอนต์แรกไม่มี
f.cache("cache");                                   // ที่เก็บรูปของตัวอักษร
double right = f.draw(canvas, 20.0, 40.0, "Hello สวัสดี", 24.0, 0xffffffff);
```

ภาษาไทยต้องการมากกว่าตัวอักษรเรียงกัน: เครื่องหมาย (สระหรือวรรณยุกต์ที่อยู่เหนือตัวอักษร) ไม่มีความกว้างของตัวเอง และวางทับตัวอักษรก่อนหน้า เมื่อวรรณยุกต์อยู่เหนือสระจะถูกยกขึ้น ไลบรารีทำให้เอง `<ui>` รับฟอนต์ด้วย `u.font(@f, 26.0)` แล้ววาดทุกคำของปุ่มและรายการด้วยฟอนต์นั้น

**ลอง:** เปลี่ยนข้อความเป็นชื่อของคุณ แล้วพิมพ์ความยาวเป็นไบต์และเป็นตัวอักษร

## บทที่ 88. แสง เงา และแสงเรือง: สีผสมกันอย่างไร

สีบนหน้าจอคือ `0xAARRGGBB`: alpha แดง เขียว น้ำเงิน ค่าละ 0 ถึง 255 การวาดสีที่มี alpha ทับสีอื่นคือผสมทีละช่องสี: `ผลลัพธ์ = สีบน * alpha + สีล่าง * (1 - alpha)` เงา แสงเรือง และขอบเนียนของตัวอักษร ล้วนเป็นกฎข้อนี้ซ้ำ ๆ

```jk
#import <stdlib>
using stdlib;

// a colour is 0xAARRGGBB. Drawing a colour with some alpha over another one mixes them channel by channel: this is what a screen does for every
// dot of a shadow, a glow or the edge of a letter.
int channel(int c, int shift) { return (c >> shift) & 255; }

int blend(int top, int under) {
    int a = channel(top, 24);
    int r = (channel(top, 16) * a + channel(under, 16) * (255 - a)) / 255;
    int g = (channel(top, 8) * a + channel(under, 8) * (255 - a)) / 255;
    int b = (channel(top, 0) * a + channel(under, 0) * (255 - a)) / 255;
    return 0xff000000 | (r << 16) | (g << 8) | b;
}

int main() {
    int blue = 0xff0000ff;
    int half_red = 0x80ff0000;
    jout << "half red over blue: " << tohex(blend(half_red, blue)) << "\n";
    jout << "a quarter of white over black: " << tohex(blend(0x40ffffff, 0xff000000)) << "\n";
    // a glow is many circles with a little alpha on top of each other: the centre gets the sum
    int glow = 0xff000000;
    for k in 0..8 { glow = blend(0x20ffffff, glow); }
    jout << "eight layers of a faint white: " << tohex(glow) << "\n";
    return 0;
}

```

ผลลัพธ์:

```
half red over blue: ff80007f
a quarter of white over black: ff404040
eight layers of a faint white: ffa4a4a4
```

`<ui>` 0.2.0 ใช้กฎนี้ตรง ๆ: เงานุ่มคือกล่องมุมโค้งที่ใหญ่ขึ้นเรื่อย ๆ หลายใบ แต่ละใบมี alpha นิดเดียว แสงเรืองคือวงกลมซ้อนกัน แสงใต้นิ้วคือแสงเรืองที่ตำแหน่งที่แตะ `<softcanvas>` คือ canvas ที่วาดลงหน่วยความจำด้วยกฎเดียวกัน จึงรันหน้าจอโดยไม่มีจอ แล้วดูรูป (`save_ppm`) หรือทดสอบพิกเซลได้:

```jk-no
SoftCanvas sc;  sc.make(400, 800);
Ui u;  u.start();  u.theme(0);                // 0 midnight, 1 aurora, 2 sunset, 3 light, 4 neon
u.begin(@sc, 400.0, 800.0);
u.title("My App");  u.button("Start");  u.tabs("Home|Search|Me", @tab);
u.end();
sc.save_ppm("screen.ppm");
```

แถบแท็บมี pill ที่เลื่อนไปแท็บที่เลือกและยืดตัวนิดหน่อยระหว่างเคลื่อน: ทุกเฟรม pill ขยับไปส่วนหนึ่งของระยะที่เหลือ (`pos += (want - pos) * dt * 11`) ซึ่งเป็นวิธีที่การเคลื่อนไหวนุ่ม ๆ เกือบทั้งหมดใน UI ทำกัน

**ลอง:** ผสม `0x80ffffff` ทับสีพื้นหลังของทั้งห้าธีม แล้วดูว่าอันไหนสว่างที่สุด

## บทที่ 89. กุญแจหลายดอกจากความลับเดียว: HKDF และเครื่องมือ jmaip

ความลับเดียวสร้างกุญแจได้มากเท่าที่ต้องการ ดอกละหนึ่งหน้าที่ เพื่อให้กุญแจดอกหนึ่งรั่วแล้วไม่เปิดดอกอื่น นี่คือ HKDF (RFC 5869): สกัดกุญแจที่แข็งแรงจากความลับ แล้วขยายด้วยป้ายชื่อของแต่ละหน้าที่

```jk
#import <stdlib>
using stdlib;

// a key made from a secret: HKDF turns one secret into as many keys as you need, one for each purpose. (jmaip does this for every file and passkey.)
int main() {
    char secret[32];
    for i in 0..32 { secret[i] = (char)(i * 7 + 1); }
    char salt[4];
    salt[0] = 'j'; salt[1] = 'm'; salt[2] = 'a'; salt[3] = 'i';
    char prk[32];
    Crypto::hkdf_extract(256, (char^)@salt, 4, (char^)@secret, 32, (char^)@prk);
    char info_a[8];
    info_a[0] = 'f'; info_a[1] = 'i'; info_a[2] = 'l'; info_a[3] = 'e';
    char info_b[8];
    info_b[0] = 'n'; info_b[1] = 'o'; info_b[2] = 't'; info_b[3] = 'e';
    char ka[16];
    char kb[16];
    Crypto::hkdf_expand(256, (char^)@prk, 32, (char^)@info_a, 4, (char^)@ka, 16);
    Crypto::hkdf_expand(256, (char^)@prk, 32, (char^)@info_b, 4, (char^)@kb, 16);
    String ha = "";
    String hb = "";
    for i in 0..4 { ha = ha + padl(tohex(ka[i] & 255), 2); hb = hb + padl(tohex(kb[i] & 255), 2); }
    jout << "key for files: " << ha << "...\n";
    jout << "key for notes: " << hb << "...\n";
    jout << "different: " << (ha != hb) << "\n";
    return 0;
}

```

ผลลัพธ์:

```
key for files: a7f54c14...
key for notes: 4b5db8cb...
different: true
```

เครื่องมือ **jmaip** (`jc install jmaip`) สร้างบนหลักการนี้ มันเก็บ vault ที่ล็อกด้วยรหัสผ่าน สร้าง **passkey** (กุญแจ P-256 ที่เซ็นคำท้าทาย เหมือนกุญแจของ WebAuthn) และเข้ารหัสไฟล์ด้วยกุญแจที่มาจาก passkey ดังนั้นมีเพียงผู้ที่มี passkey เท่านั้นที่เปิดได้:

```jk-no
jmaip init                                  # vault (ตั้งรหัสผ่าน)
jmaip key new phone                         # passkey; พิมพ์กุญแจสาธารณะ
jmaip key sign phone "login:7f3a"           # ลายเซ็นของคำท้าทาย
jmaip enc -k phone notes.txt                # notes.txt.jmaip ปิดผนึกด้วย AES-256-GCM
jmaip dec notes.txt.jmaip                   # หา passkey จากหัวไฟล์เอง
```

กุญแจของไฟล์คือ `HKDF(ลายเซ็นของข้อความตายตัวด้วย passkey, salt สุ่ม)` ไฟล์ที่ถูกแก้หรือกุญแจผิดจะถูกปฏิเสธ ไม่ถอดรหัสครึ่ง ๆ กลาง ๆ และจำข้อจำกัดไว้: passkey ที่เป็นไฟล์ปลอดภัยเท่ากับไฟล์และรหัสผ่านเท่านั้น ส่วนใบหน้าหรือลายนิ้วมือของมือถือจะมาทีหลังในฐานะสิ่งที่ปลดล็อกกุญแจ vault

**ลอง:** สร้างกุญแจดอกที่สามด้วยป้ายชื่อ `"backup"` แล้วตรวจว่าต่างจากอีกสองดอก

## บทที่ 90. ลูปเร็ว: เขียนอย่างไรให้คอมไพเลอร์ใช้ SIMD ได้

ลูปที่ทำสิ่งเดียวกันกับทุกสมาชิกของอาร์เรย์ รันทีละ 4 float (หรือ 2 double) ด้วย NEON ได้ คอมไพเลอร์ทำเองเมื่อมองเห็นว่าลูปเรียบง่าย ผลคูณเมทริกซ์ใน**รูปแบบอัปเดตทีละแถว**เป็นตัวอย่างคลาสสิก: ลูปในบวก `av * b[bk + j]` เข้า `c[ci + j]` สำหรับแต่ละ `j` และรอบหนึ่งไม่ขึ้นกับรอบก่อน

```jk
#import <stdlib>
using stdlib;

// C = A * B for small matrices, written in the "row update" form: the inner loop adds a row of B, times one number, to a row of C.
int main() {
    int n = 4;
    float[] a = arr(n * n);
    float[] b = arr(n * n);
    float[] c = arr(n * n);
    for i in 0..n * n { a.push((float)(i % 5)); b.push((float)(i % 3)); c.push(0.0); }
    for i in 0..n {
        for k in 0..n {
            float av = a[i * n + k];
            int ci = i * n;
            int bk = k * n;
            int j = 0;
            while j < n { c[ci + j] = c[ci + j] + av * b[bk + j]; j += 1; }
        }
    }
    for i in 0..n {
        for j in 0..n { jout << c[i * n + j] << " "; }
        jout << "\n";
    }
    return 0;
}

```

ผลลัพธ์:

```
5.000000 5.000000 8.000000 5.000000 
2.000000 6.000000 13.000000 2.000000 
4.000000 12.000000 8.000000 4.000000 
11.000000 8.000000 8.000000 11.000000 
```

นิสัยสามข้อที่ช่วยคอมไพเลอร์: (1) เก็บ offset ของแถวไว้ในตัวแปร `int` ธรรมดา (`ci`, `bk`) แล้วบวกตัวนับ `j` เข้าไป (2) อ่านค่าที่ไม่เปลี่ยน (`av`) ใส่ตัวแปรก่อนเข้าลูป (3) อย่าเรียกฟังก์ชันในลูป ถ้าสองแถวอาจซ้อนกันในหน่วยความจำ คอมไพเลอร์ตรวจตอนรันและใช้ลูปธรรมดาในกรณีนั้น ผลลัพธ์จึงเท่ากับแบบไม่ใช้เวกเตอร์เสมอ (`-novec` พิสูจน์ได้)

รูปแบบธรรมดา `s = s + a[i*n+k] * b[k*n+j]` (dot product) มีโซ่ที่รอบถัดไปต้องรอผลรวมรอบก่อน ตอนนี้ช้ากว่า (ประมาณ 1.6 ถึง 2.5 เท่าของ C บนมือถือ) งานเทรนก้อนใหญ่ให้ใช้ `<neuron>` (`matmul_fast`)

**ลอง:** คอมไพล์แบบมีและไม่มี `-novec` แล้วเทียบผลลัพธ์

## บทที่ 91. ทำไมการวนลูปบนอาเรย์จึงเร็ว

อาเรย์คือบล็อกหน่วยความจำเดียวที่สมาชิกอยู่ติดกัน โปรเซสเซอร์อ่านหน่วยความจำทีละก้อน 64 ไบต์ (cache line) การอ่านครั้งเดียวจึงได้ตัวเลขถัดไป
มาด้วยหลายตัว ลูปที่เดินตรงไปตามอาเรย์ตามลำดับใช้ทุกก้อนที่อ่านมา นี่คือเหตุผลที่ลูปแบบนี้เร็ว และเป็นเหตุให้ความเร็วส่วนใหญ่ในบทนี้มาจากการเก็บข้อมูลให้เรียงกัน

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] a = arr(1000);
    for i in 0..1000 { a.push(i % 7); }
    int total = 0;
    for i in 0..a.len { total += a[i]; }      // the elements are read in memory order
    jout << "sum: " << total << "\n";
    return 0;
}
```

ผลลัพธ์:

```
sum: 2997
```

โปรแกรมบวกตัวเลขทีละตัวตามลำดับในหน่วยความจำ ไม่มีอะไรซับซ้อน ความเร็วมาจากลำดับการอ่าน

**ลองทำ:** เปลี่ยน `i % 7` เป็น `i % 100` แล้วทายผลรวมก่อนรัน

## บทที่ 92. จับเวลาด้วย Time::mono_ns

หากอยากรู้ว่าโค้ดใช้เวลาเท่าไร ให้อ่านนาฬิกาก่อนและหลังโค้ดนั้น `Time::mono_ns()` ให้จำนวนนาโนวินาทีจากนาฬิกาที่เดินไปข้างหน้าเท่านั้น
(ไม่กระโดดถอยหลังเมื่อมีการตั้งเวลาใหม่) เวลาเปลี่ยนทุกครั้งที่รัน โปรแกรมนี้จึงพิมพ์เฉพาะสิ่งที่ไม่เปลี่ยน ได้แก่ค่าตรวจสอบของผลลัพธ์
และบรรทัดที่บอกว่านาฬิกาเดินไปข้างหน้า แล้วรันงานซ้ำหลายรอบ เก็บเวลาที่สั้นที่สุด

```jk
#import <stdlib>
using stdlib;

int work(int[] a) {
    int s = 0;
    for i in 0..a.len { s += a[i] * 3; }
    return s;
}

int main() {
    int[] a = arr(100000);
    for i in 0..100000 { a.push(i % 10); }
    int best = 0;
    int check = 0;
    for run in 0..5 {
        int t0 = Time::mono_ns();
        check = work(a);
        int dt = Time::mono_ns() - t0;
        if run == 0 || dt < best { best = dt; }
    }
    int t_end = Time::mono_ns();
    if t_end >= 0 { jout << "ok: the clock went forward\n"; }
    jout << "checksum: " << check << "\n";
    return 0;
}
```

ผลลัพธ์:

```
ok: the clock went forward
checksum: 1350000
```

การจับเวลาครั้งเดียวไม่นิ่ง โปรแกรมอื่น แคช และตัวนาฬิกาเองทำให้ตัวเลขเปลี่ยน ค่าที่ซื่อตรงคือเวลาที่ดีที่สุดจากหลายรอบ
โปรแกรมนี้ไม่พิมพ์เวลา ผลลัพธ์จึงเหมือนเดิมทุกครั้งที่รัน

**ลองทำ:** เปลี่ยนจาก 5 รอบเป็น 10 รอบ แล้วดูว่าค่า checksum ไม่เปลี่ยน

## บทที่ 93. float กับ double และอาเรย์ float[]

`float` คือทศนิยม 32 บิต และ `double` คือ 64 บิต `float[]` ใช้หน่วยความจำครึ่งหนึ่งของ `double[]` ที่มีความยาวเท่ากัน จึงมีตัวเลข
เป็นสองเท่าในแต่ละ cache line และสี่ตัวลงในรีจิสเตอร์ NEON ตัวเดียว (หนึ่ง `f32x4`) ใช้ `float` เมื่อความแม่นยำพอ (งานกราฟิกและโครงข่ายประสาทส่วนใหญ่)
ใช้ `double` เมื่อผลรวมต้องแม่นถึงหลายหลัก การแปลงระหว่างสองชนิดต้องเขียน cast เอง

```jk
#import <stdlib>
using stdlib;

int main() {
    float[] f = arr(4000);
    double[] d = arr(4000);
    for i in 0..4000 {
        f.push((float)i * 0.5);
        d.push((double)i * 0.5);
    }
    double sf = 0.0;
    double sd = 0.0;
    for i in 0..4000 {
        sf += (double)f[i];
        sd += d[i];
    }
    jout << "float bytes: " << sizeof(float) << ", double bytes: " << sizeof(double) << "\n";
    jout << "sums: " << sf << " " << sd << "\n";
    return 0;
}
```

ผลลัพธ์:

```
float bytes: 4, double bytes: 8
sums: 3999000.000000 3999000.000000
```

ผลรวมทั้งสองถูกต้องที่นี่เพราะตัวเลขเป็นครึ่งหนึ่งและมีค่าน้อย เมื่อใช้ค่าอย่าง 0.1 ผลรวมแบบ `float` จะคลาดจาก `double` หลังบวกจำนวนมาก
การเลือกชนิดจึงเป็นการตัดสินใจจริง

**ลองทำ:** เปลี่ยน `0.5` เป็น `0.1` ทั้งสองที่ แล้วเทียบผลรวมทั้งสอง

## บทที่ 94. ชนิดเวกเตอร์ SIMD: f32x4 อ่านและเขียน

`#import <simd>` ให้ชนิดเวกเตอร์ `f32x4` เก็บตัวเลข float สี่ตัวในรีจิสเตอร์ NEON 128 บิตตัวเดียว ส่วนของมันชื่อ `x y z w`
`f32x4::load(p, i)` อ่าน float สี่ตัวเริ่มจากสมาชิกที่ `i` ของอาเรย์ที่ `p` ชี้อยู่ และ `v.store(p, i)` เขียนค่ากลับ ดัชนีนับเป็นสมาชิก ไม่ใช่ไบต์
ลูปที่ทำ load งาน แล้ว store จัดการสี่สมาชิกในแต่ละรอบ

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    float a[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    float c[8];
    f32x4 v = f32x4::load(@a[0], 4);       // a[4] a[5] a[6] a[7]
    v.store(@c[0], 0);                     // into c[0] c[1] c[2] c[3]
    f32x4 w = f32x4::load(@a[0], 0);       // a[0] .. a[3]
    w.store(@c[4], 0);                     // into c[4] .. c[7]
    for i in 0..8 { jout << c[i] << " "; }
    jout << "\n";
    return 0;
}
```

ผลลัพธ์:

```
5.000000 6.000000 7.000000 8.000000 1.000000 2.000000 3.000000 4.000000 
```

สี่ตัวแรกของ `c` คือสี่ตัวท้ายของ `a` และสี่ตัวหลังคือสี่ตัวแรกของ `a`

**ลองทำ:** โหลดจากดัชนี 2 แทน 4 แล้วทายค่าทุกตัวของ `c` ก่อนรัน

## บทที่ 95. ตัวดำเนินการของ f32x4 และ .sum()

ตัวดำเนินการ `+ - * /` ทำงานกับทั้งสี่ช่องพร้อมกัน คำสั่งเดียวบวกได้สี่ครั้ง ตัวเลขธรรมดาที่อยู่ข้างหนึ่งจะถูกใช้กับทุกช่อง
`.sum()` `.min()` และ `.max()` ให้ค่าเดียวจากสี่ช่อง จึงใช้เปลี่ยนผลเวกเตอร์เป็นคำตอบเดียวได้

```jk
#import <stdlib>
using stdlib;

#import <simd>

int main() {
    f32x4 x = {1.0, 2.0, 3.0, 4.0};
    f32x4 y = {0.5, 0.5, 2.0, 2.0};
    f32x4 z = x * y + x;                   // four lanes at once: 1.5 3 9 12
    jout << z.x << " " << z.y << " " << z.z << " " << z.w << "\n";
    f32x4 h = z / 2.0 - 1.0;               // the number is used for every lane
    jout << h.x << " " << h.w << "\n";
    jout << "sum " << z.sum() << "  min " << z.min() << "  max " << z.max() << "\n";
    return 0;
}
```

ผลลัพธ์:

```
1.500000 3.000000 9.000000 12.000000
-0.250000 5.000000
sum 25.500000  min 1.500000  max 12.000000
```

ช่องของ `z` คือ 1.5, 3, 9 และ 12 ดังนั้น `z.sum()` คือ 25.5 ค่าน้อยสุดคือ 1.5 และมากสุดคือ 12

**ลองทำ:** คิด `z.sum()` จากบรรทัดแรกด้วยมือแล้วตรวจสอบ

## บทที่ 96. axpy ด้วย f32x4: y = y + a * x

สูตร `y = y + a * x` (ชื่อในวงการ BLAS คือ axpy) พบบ่อยมากในพีชคณิตเชิงเส้นและการฝึกโมเดล แต่ละสมาชิกมีการคูณหนึ่งครั้งและการบวกหนึ่งครั้ง
ตัวเลข `a` ถูกใส่ในเวกเตอร์ด้วย `{a, a, a, a}` แล้วอ่าน `x` กับ `y` ทีละสี่ตัว ในรูปแบบง่ายนี้ `n` ต้องหารด้วย 4 ลงตัว
บทที่ 90 แสดงรูปแบบแถวของการคูณเมทริกซ์ บทนี้คือแนวคิดเดียวกันเมื่อใช้เดี่ยวๆ

```jk
#import <stdlib>
#import <simd>
using stdlib;

// y = y + a * x for n numbers; n must be a multiple of 4 in this simple form
void axpy(float a, float^ x, float^ y, int n) {
    f32x4 av = {a, a, a, a};
    int i = 0;
    while i < n {
        f32x4 xv = f32x4::load(x, i);
        f32x4 yv = f32x4::load(y, i);
        yv = yv + av * xv;
        yv.store(y, i);
        i += 4;
    }
}

int main() {
    float x[8];
    float y[8];
    for i in 0..8 {
        x[i] = (float)i;
        y[i] = 1.0;
    }
    axpy(0.5, @x[0], @y[0], 8);
    for i in 0..8 { jout << y[i] << " "; }
    jout << "\n";
    return 0;
}
```

ผลลัพธ์:

```
1.000000 1.500000 2.000000 2.500000 3.000000 3.500000 4.000000 4.500000 
```

แต่ละสมาชิกคือ `1 + 0.5 * i` ดังนั้นบรรทัดนี้คือ 1, 1.5, 2 ... 4.5

**ลองทำ:** เรียก `axpy` อีกครั้งโดยให้ `a` เป็น 2.0 แล้วทายบรรทัดใหม่

## บทที่ 97. การคูณเมทริกซ์แบบตรงไปตรงมา (ijk)

`C = A * B` มักเขียนด้วยลูปสามชั้น: สำหรับทุกแถว `i` ของ C และทุกคอลัมน์ `j` ให้หาผลคูณจุด (dot product) ของแถว `i` ของ A กับคอลัมน์ `j` ของ B
ผลรวม `s` คือผลคูณจุดหนึ่งครั้ง เขียนอ่านง่ายและเป็นรูปแบบในตำราส่วนใหญ่ ตัวอย่างเป็น 4x4 โดย `A[i][k] = i + k` และ `B[k][j] = k - j`
เก็บแต่ละเมทริกซ์ในอาเรย์แบนหนึ่งอาเรย์ โดยดัชนีคือ `i*n + k`

```jk
#import <stdlib>
using stdlib;

// C = A * B for 4x4, the plain way: C[i][j] is the dot product of row i of A and column j of B
int main() {
    int n = 4;
    float[] a = arr(16);
    float[] b = arr(16);
    float[] c = arr(16);
    for i in 0..n {
        for k in 0..n { a.push((float)(i + k)); }
    }
    for k in 0..n {
        for j in 0..n { b.push((float)(k - j)); }
    }
    for i in 0..n {
        for j in 0..n {
            float s = 0.0;
            for k in 0..n { s = s + a[i * n + k] * b[k * n + j]; }
            c.push(s);
        }
    }
    for i in 0..n {
        for j in 0..n { jout << c[i * n + j] << " "; }
        jout << "\n";
    }
    return 0;
}
```

ผลลัพธ์:

```
14.000000 8.000000 2.000000 -4.000000 
20.000000 10.000000 0.000000 -10.000000 
26.000000 12.000000 -2.000000 -16.000000 
32.000000 14.000000 -4.000000 -22.000000 
```

ลูปชั้นใน `k` เป็นโซ่: `s = s + ...` แต่ละครั้งต้องรอผลของครั้งก่อน บทที่ 98 อธิบายว่าทำไมสิ่งนี้จำกัดความเร็ว

**ลองทำ:** คำนวณตัวแรกของแถว 0 ด้วยมือ (คือผลคูณจุดของแถว 0 ของ A กับคอลัมน์ 0 ของ B) แล้วตรวจสอบ

## บทที่ 98. ทำไม ijk จึงช้ากว่า: โซ่การบวก และตัวสะสมสองตัว

โปรเซสเซอร์บวกหลายค่าพร้อมกันได้ แต่โซ่ `s = s + x` ต้องรอผลก่อนหน้าเสมอ โซ่ยาวเพียงเส้นเดียวจึงทำงานได้ช้าเท่ากับการบวกทีละครั้งต่อกัน
วิธีแก้คือ **jam** ลูป: ใช้ผลรวมสองตัวที่ไม่ขึ้นต่อกัน `s0` สำหรับพจน์คู่และ `s1` สำหรับพจน์คี่ แล้วรวมตอนท้าย ผลเท่าเดิม และโซ่ทั้งสองทำงานคู่กัน
การบวก float ตามลำดับต่างกันอาจทำให้หลักสุดท้ายต่างได้ ตัวอย่างนี้จึงใช้จำนวนเต็มในค่า float

```jk
#import <stdlib>
using stdlib;

// one chain: every add waits for the one before it
float dot_one(float[] a, float[] b, int n) {
    float s = 0.0;
    for i in 0..n { s = s + a[i] * b[i]; }
    return s;
}

// two chains: s0 and s1 do not wait for each other; they are added at the end
float dot_two(float[] a, float[] b, int n) {
    float s0 = 0.0;
    float s1 = 0.0;
    int i = 0;
    while i + 2 <= n {
        s0 = s0 + a[i] * b[i];
        s1 = s1 + a[i + 1] * b[i + 1];
        i += 2;
    }
    return s0 + s1;
}

int main() {
    float[] a = arr(8);
    float[] b = arr(8);
    for i in 0..8 {
        a.push((float)(i + 1));
        b.push((float)(i % 3));
    }
    jout << "one chain: " << dot_one(a, b, 8) << "\n";
    jout << "two chains: " << dot_two(a, b, 8) << "\n";
    return 0;
}
```

ผลลัพธ์:

```
one chain: 33.000000
two chains: 33.000000
```

ทั้งสองบรรทัดพิมพ์ผลรวมเดียวกัน โซ่สี่เส้น (บทที่ 99) มักเร็วกว่าอีก เพราะโปรเซสเซอร์บวกได้สี่ครั้งพร้อมกัน

**ลองทำ:** เขียน `dot_three` ที่ใช้สามโซ่ แล้วตรวจว่าพิมพ์ผลรวมเดียวกัน

## บทที่ 99. ตัวสะสมสี่ตัวด้วยมือ

โซ่สี่เส้น `s0 .. s3` รับสมาชิก `i`, `i+1`, `i+2` และ `i+3` ลูปก้าวทีละสี่ ส่วนที่เหลือ (เมื่อ `n` ไม่หารด้วย 4 ลงตัว) บวกต่อท้าย
เป็นเทคนิคเดียวกับเวกเตอร์ที่มีสี่ช่อง คือสี่โซ่ที่ทำงานพร้อมกัน

```jk
#import <stdlib>
using stdlib;

// four chains: s0 .. s3 take the elements i .. i+3; the loop steps by 4 and the tail is added at the end
float dot_four(float[] a, float[] b, int n) {
    float s0 = 0.0;
    float s1 = 0.0;
    float s2 = 0.0;
    float s3 = 0.0;
    int i = 0;
    while i + 4 <= n {
        s0 = s0 + a[i] * b[i];
        s1 = s1 + a[i + 1] * b[i + 1];
        s2 = s2 + a[i + 2] * b[i + 2];
        s3 = s3 + a[i + 3] * b[i + 3];
        i += 4;
    }
    float s = s0 + s1 + s2 + s3;
    while i < n {
        s = s + a[i] * b[i];
        i += 1;
    }
    return s;
}

int main() {
    float[] a = arr(18);
    float[] b = arr(18);
    for i in 0..18 {
        a.push((float)(i + 1));
        b.push((float)(i % 4));
    }
    float plain = 0.0;
    for i in 0..18 { plain = plain + a[i] * b[i]; }
    jout << "plain: " << plain << "\n";
    jout << "four chains: " << dot_four(a, b, 18) << "\n";
    return 0;
}
```

ผลลัพธ์:

```
plain: 242.000000
four chains: 242.000000
```

ผลรวมทั้งสองบรรทัดเท่ากัน ลูป `while` ท้ายจัดการสมาชิกสองตัวที่เหลือ (18 ไม่หารด้วย 4 ลงตัว)

**ลองทำ:** เปลี่ยน 18 ทุกที่เป็น 16 (อาเรย์และลูป) แล้วตรวจว่าลูปส่วนท้ายไม่ทำงานอะไรเลย

## บทที่ 100. เวกเตอร์ตามแนว j: คำนวณสี่คอลัมน์ของ C พร้อมกัน

แทนที่จะคำนวณผลคูณจุดทีละตัว เวกเตอร์เก็บสี่คอลัมน์ได้: `cv` คือ `C[i][j..j+3]` สำหรับแต่ละ `k` ตัวเลข `A[i][k]` ถูกใส่ในทุกช่อง
(broadcast ด้วย `{x, x, x, x}`) แถว `B[k][0..3]` ถูกโหลดเป็นเวกเตอร์เดียว แล้วทำ `cv = cv + av * bv` สี่ช่องคือผลรวมสี่ตัวแยกกัน
จึงมีโซ่สี่เส้นทำงานคู่กัน และการโหลดอ่านหน่วยความจำตามลำดับ ตัวอย่างใช้ข้อมูลชุดเดียวกับบทที่ 97

```jk
#import <stdlib>
#import <simd>
using stdlib;

// C = A * B for 4x4, four columns of C at a time: cv holds the row i of C
int main() {
    int n = 4;
    float a[16];
    float b[16];
    float c[16];
    for i in 0..n {
        for k in 0..n { a[i * n + k] = (float)(i + k); }
    }
    for k in 0..n {
        for j in 0..n { b[k * n + j] = (float)(k - j); }
    }
    for i in 0..n {
        f32x4 cv = {0.0, 0.0, 0.0, 0.0};
        for k in 0..n {
            float x = a[i * n + k];                 // A[i][k]
            f32x4 av = {x, x, x, x};                // broadcast to every lane
            f32x4 bv = f32x4::load(@b[0], k * n);   // B[k][0..3]
            cv = cv + av * bv;
        }
        cv.store(@c[0], i * n);
    }
    for i in 0..16 {
        jout << c[i] << " ";
        if i % 4 == 3 { jout << "\n"; }
    }
    return 0;
}
```

ผลลัพธ์:

```
14.000000 8.000000 2.000000 -4.000000 
20.000000 10.000000 0.000000 -10.000000 
26.000000 12.000000 -2.000000 -16.000000 
32.000000 14.000000 -4.000000 -22.000000 
```

สี่บรรทัดนี้เป็นสี่บรรทัดเดียวกับที่บทที่ 97 พิมพ์

**ลองทำ:** เปลี่ยน `n` เป็น 8 และอาเรย์เป็น 64 ตัว แล้วนับว่าลูปชั้นในทำงานกี่ครั้ง

## บทที่ 101. บล็อกรีจิสเตอร์ขนาด 4x8

บล็อกรีจิสเตอร์คือชิ้นเล็กๆ ของ C ที่อยู่ในรีจิสเตอร์ตลอดลูป `k` ในที่นี้ C มี 4 แถว 8 คอลัมน์ เก็บเป็นค่า `f32x4` แปดตัว คือสองตัวต่อแถว
(คอลัมน์ 0..3 และ 4..7) แต่ละ `k` โหลดเวกเตอร์สองตัวจากแถว `k` ของ B (แปดตัวเลข) และสำหรับแต่ละแถวใส่ `A[i][k]` เป็น broadcast
แล้วบวกเข้าเวกเตอร์สองตัวของแถวนั้น C ไม่ถูกเขียนลงหน่วยความจำจนจบ ตัวอย่างใช้ K = 3 และตัวเลขน้อย เพื่อให้ตรวจผลด้วยมือได้

```jk
#import <stdlib>
#import <simd>
using stdlib;

// A is 4x3, B is 3x8, C is 4x8 (K = 3). The eight vectors of C stay in registers during the loop over k.
int main() {
    float a[12];
    float b[24];
    for i in 0..4 {
        for k in 0..3 { a[i * 3 + k] = (float)(i + k + 1); }
    }
    for k in 0..3 {
        for j in 0..8 { b[k * 8 + j] = (float)(k + j); }
    }
    f32x4 z = {0.0, 0.0, 0.0, 0.0};
    f32x4 c00 = z;  f32x4 c01 = z;
    f32x4 c10 = z;  f32x4 c11 = z;
    f32x4 c20 = z;  f32x4 c21 = z;
    f32x4 c30 = z;  f32x4 c31 = z;
    for k in 0..3 {
        f32x4 b_lo = f32x4::load(@b[0], k * 8);       // B[k][0..3]
        f32x4 b_hi = f32x4::load(@b[0], k * 8 + 4);   // B[k][4..7]
        float x0 = a[k];
        float x1 = a[3 + k];
        float x2 = a[6 + k];
        float x3 = a[9 + k];
        f32x4 a0 = {x0, x0, x0, x0};
        f32x4 a1 = {x1, x1, x1, x1};
        f32x4 a2 = {x2, x2, x2, x2};
        f32x4 a3 = {x3, x3, x3, x3};
        c00 = c00 + a0 * b_lo;  c01 = c01 + a0 * b_hi;
        c10 = c10 + a1 * b_lo;  c11 = c11 + a1 * b_hi;
        c20 = c20 + a2 * b_lo;  c21 = c21 + a2 * b_hi;
        c30 = c30 + a3 * b_lo;  c31 = c31 + a3 * b_hi;
    }
    float out[32];
    c00.store(@out[0], 0);   c01.store(@out[0], 4);
    c10.store(@out[0], 8);   c11.store(@out[0], 12);
    c20.store(@out[0], 16);  c21.store(@out[0], 20);
    c30.store(@out[0], 24);  c31.store(@out[0], 28);
    for i in 0..4 {
        for j in 0..8 { jout << out[i * 8 + j] << " "; }
        jout << "\n";
    }
    return 0;
}
```

ผลลัพธ์:

```
8.000000 14.000000 20.000000 26.000000 32.000000 38.000000 44.000000 50.000000 
11.000000 20.000000 29.000000 38.000000 47.000000 56.000000 65.000000 74.000000 
14.000000 26.000000 38.000000 50.000000 62.000000 74.000000 86.000000 98.000000 
17.000000 32.000000 47.000000 62.000000 77.000000 92.000000 107.000000 122.000000 
```

แถว 0 คือ `A[0][k]` คูณกับแถว `k` ของ B บวกกันเมื่อ `k = 0, 1, 2` สำหรับคอลัมน์ 0 ได้ 1*0 + 2*1 + 3*2 = 8

**ลองทำ:** เปลี่ยน K เป็น 2 (ใช้แค่ `k` 0 และ 1) แล้วตรวจตัวแรกของแถว 0 ด้วยมือ

## บทที่ 102. หลายเธรด: ลูป #multithread

วาง `#multithread` ไว้บรรทัดก่อนลูป `for` เพื่อแบ่งรอบของลูปให้แกนประมวลผลทั้งหมด (ไม่เกิน 16 ส่วน) แต่ละรอบต้องไม่ขึ้นกับรอบอื่น
และในตัวลูปห้ามใช้ `break` `return` หรือ `#multithread` อีกชั้น ลูปจบเมื่อทุกส่วนทำเสร็จ ผลลัพธ์จึงเหมือนเดิมเสมอ

```jk
#import <stdlib>
using stdlib;

int squares[1000];

void main() {
    int offset = 5;
    #multithread
    for i in 0..1000 {                  // the iterations are shared among the machine's cores
        squares[i] = i * i + offset;    // every iteration writes its own element
    }
    jout << squares[999] << "\n";
}
```

ผลลัพธ์:

```
998006
```

แต่ละรอบเขียนเฉพาะสมาชิกของตัวเอง ส่วนต่างๆ จึงไม่แตะหน่วยความจำเดียวกัน ลูปที่บวกเข้าผลรวมร่วมกันต้องใช้ `Mutex` (ดู LANGUAGE.md)
หรือผลรวมแยกของแต่ละส่วน

**ลองทำ:** เปลี่ยน `offset` เป็น 7 แล้วทายผลก่อนรัน

## บทที่ 103. การตรวจขอบเขตดัชนีและสวิตช์ -d

การตรวจว่า `a[i]` อยู่ในขอบเขตทำเฉพาะตอนสร้างด้วย `-d`: `jcmp prog.jk -d -o prog` ถ้าดัชนีผิด โปรแกรมจะหยุดพร้อมข้อความ
`runtime error: index out of bounds, array size is N` และ exit code 134 การสร้างแบบปกติไม่ตรวจ ดัชนีผิดจึงอ่านหน่วยความจำอื่น
ใช้ `-d` ตอนทดสอบ การตรวจมีต้นทุนเป็นการเปรียบเทียบในทุกรอบลูป รุ่นที่ปล่อยใช้งานจึงไม่ใส่ การวนแบบ `0..a.len` ไม่มีทางเกินขอบเขต ควรเขียนแบบนี้ก่อน

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] a = arr(10);
    for i in 0..10 { a.push(i * 3); }
    int total = 0;
    for i in 0..a.len { total += a[i]; }      // i always stays inside 0 .. a.len - 1
    jout << "total " << total << "\n";
    return 0;
}
```

ผลลัพธ์:

```
total 135
```

สร้างด้วย `-d` ด้วยก็ได้: `jcmp bounds.jk -d -o bounds` ผลลัพธ์เหมือนกัน เพราะโปรแกรมนี้ไม่เกินขอบเขต

**ลองทำ:** เปลี่ยนลูปเป็น `for i in 0..11` แล้วสร้างด้วย `-d` และอ่านข้อความผิดพลาด

## บทที่ 104. สวิตช์ -novec -nofma -nopeep -noir

มีสวิตช์สี่ตัวที่ปิดการเพิ่มประสิทธิภาพทีละอย่าง เพื่อหาว่าอันไหนทำให้ผิด ได้แก่ `-novec` (ไม่ใช้ลูปเวกเตอร์ NEON) `-nofma`
(คงการปัดเศษสองครั้งของ `a*b + c`) `-nopeep` (ไม่เขียนคำสั่งแอสเซมบลีตอนท้ายใหม่) และ `-noir` (ข้ามตัวเพิ่มประสิทธิภาพระดับกลาง)
ถ้าผลเปลี่ยนเมื่อเพิ่มสวิตช์ตัวใด ข้อผิดพลาดอยู่ในส่วนนั้น โปรแกรมนี้พิมพ์ผลเหมือนกันทุกสวิตช์ เพราะตัวเลขเป็นค่าที่แม่นตรง

```jk
#import <stdlib>
using stdlib;

int main() {
    double[] x = arr(8);
    double[] y = arr(8);
    for i in 0..8 {
        x.push(0.5 * (double)i);
        y.push(2.0 * (double)i);
    }
    double s = 0.0;
    for i in 0..8 { s = s + x[i] * y[i] + 1.0; }   // a * b + c: with FMA this is one rounding
    jout << "sum " << s << "\n";
    return 0;
}
```

ผลลัพธ์:

```
sum 148.000000
```

ลองเอง: `jcmp switches.jk -o fast` และ `jcmp switches.jk -novec -noir -o plain` แล้วรันทั้งสองและเทียบผล เมื่อหาบั๊ก ให้ใช้ทีละสวิตช์

**ลองทำ:** เพิ่ม `-nofma` ในคำสั่ง แล้วตรวจว่าผลยังเป็น `sum 148.000000`

## บทที่ 105. อ่านแอสเซมบลีของลูป

`--emit-asm file` เขียนแอสเซมบลีที่คอมไพเลอร์สร้างไว้ เพื่อดูว่าลูปของคุณกลายเป็นอะไร เขียนคำสั่งพร้อมชื่อไฟล์ที่ต้องการ:
`jcmp total.jk -o total --emit-asm total.jasm` `-show NAME` เขียนเฉพาะหนึ่งฟังก์ชันและจำนวนคำสั่งของมัน (ARM64) เหมาะกับฟังก์ชันเล็กอย่าง `total` ด้านล่าง
อ่านเฉพาะตัวลูป ไม่ต้องอ่านทั้งไฟล์ เพราะลูปคือส่วนที่มีผลต่อความเร็ว

```jk
#import <stdlib>
using stdlib;

// a small function with one loop: a good thing to look at with -show total or --emit-asm
double total(double[] v) {
    double s = 0.0;
    for i in 0..v.len { s = s + v[i] * 2.0; }
    return s;
}

int main() {
    double[] v = arr(16);
    for i in 0..16 { v.push((double)i); }
    jout << total(v) << "\n";
    return 0;
}
```

ผลลัพธ์:

```
240.000000
```

ผลลัพธ์คือ `240.000000` คือสองเท่าของผลรวม 0 ถึง 15

**ลองทำ:** รัน `jcmp total.jk -show total` แล้วดูว่าฟังก์ชันมีกี่คำสั่ง จากนั้นเปลี่ยน `* 2.0` เป็น `* 3.0` แล้วนับใหม่

## บทที่ 106. ผลรวมจำนวนเต็มด้วย i32x4

จำนวนเต็มมีรูปแบบเดียวกัน `i32[]` เก็บเลข 32 บิต และ `i32x4` บวกเลขสี่ตัวในคำสั่งเดียว การรวมอาเรย์จำนวนเต็มเป็นลูปโหลดกับบวก
เหมือนกับ float และรวมช่องทั้งสี่ตอนท้ายด้วย `.sum()` ผลรวมของจำนวนเต็มแม่นตรง ดังนั้นผลรวมแบบเวกเตอร์ได้เลขเดียวกับการบวกธรรมดา ไม่ว่าบวกตามลำดับใด

```jk
#import <stdlib>
#import <simd>
using stdlib;

int main() {
    i32[] a = arr(1000);
    for i in 0..1000 { a.push((i32)(i * 3 % 17)); }
    i32 plain = 0;
    for i in 0..a.len { plain += a[i]; }
    i32x4 acc = {0, 0, 0, 0};
    int i = 0;
    while i < a.len {
        acc += i32x4::load(@a[0], i);      // four numbers per turn
        i += 4;
    }
    jout << "plain " << plain << "\n";
    jout << "vector " << acc.sum() << "\n";
    return 0;
}
```

ผลลัพธ์:

```
plain 7991
vector 7991
```

ทั้งสองบรรทัดพิมพ์ผลรวมเดียวกัน ความยาวอาเรย์ 1000 หารด้วย 4 ลงตัว ลูปเวกเตอร์จึงไม่ต้องมีส่วนท้าย

**ลองทำ:** เปลี่ยน `1000` เป็น `999` แล้วคิดว่าการโหลดเวกเตอร์ตัวสุดท้ายจะอ่านเกินขอบเขตตรงไหน จากนั้นเขียนลูปส่วนท้ายแบบบทที่ 99 แทน

## บทที่ 107. ไม่จองหน่วยความจำในลูปที่ร้อน

`arr` `alloc` หรือสตริงที่ต่อด้วย `+` ในลูป ทำให้ขอหน่วยความจำจาก heap ทุกรอบ ซึ่งช้ากว่าการคำนวณรอบๆ และสตริงที่ต่อด้วย `+`
คัดลอกข้อความทุกครั้ง ให้จองครั้งเดียวก่อนลูปแล้วใช้หน่วยความจำนั้นซ้ำ โปรแกรมด้านล่างจองบัฟเฟอร์ครั้งเดียว แล้วเขียนลงไปหนึ่งแสนครั้ง

```jk
#import <stdlib>
using stdlib;

int main() {
    int[] buf = arr(8);
    for i in 0..8 { buf.push(0); }        // allocated once, before the loop
    int total = 0;
    for round in 0..100000 {
        for j in 0..8 { buf[j] = round + j; }   // the same memory every round
        total += buf[7] - buf[0];
    }
    jout << total << "\n";
    return 0;
}
```

ผลลัพธ์:

```
700000
```

แต่ละรอบบวก 7 (สมาชิกตัวสุดท้ายลบตัวแรก) ผลรวมจึงเป็น 700000

**ลองทำ:** ย้าย `arr(8)` และคำสั่ง push เข้าไปในลูปนอก แล้วจับเวลาทั้งสองแบบด้วย `Time::mono_ns` (บทที่ 92)

## บทที่ 108. อาเรย์ของ struct กับ struct ของอาเรย์

อาเรย์ของ struct (AoS) เก็บ `x` และ `y` ของจุดเดียวไว้ติดกัน struct ของอาเรย์ (SoA) เก็บค่า `x` ทั้งหมดในอาเรย์หนึ่ง และ `y` ทั้งหมดในอีกอาเรย์
ลูปที่ใช้แค่ `x` อ่านหน่วยความจำน้อยกว่ามากเมื่อใช้ SoA เพราะไม่มีการโหลดค่า `y` โปรแกรมด้านล่างสองแบบให้ผลรวมของ `x` เท่ากัน

```jk
#import <stdlib>
using stdlib;

struct Point { double x; double y; }

// array of structs: the x and y of one point are next to each other
double sum_x_aos(Point[] ps) {
    double s = 0.0;
    for i in 0..ps.len { s = s + ps[i].x; }
    return s;
}

// struct of arrays: all the x values are in one array
double sum_x_soa(double[] xs) {
    double s = 0.0;
    for i in 0..xs.len { s = s + xs[i]; }
    return s;
}

int main() {
    Point[] ps = arr(1000);
    double[] xs = arr(1000);
    double[] ys = arr(1000);
    for i in 0..1000 {
        Point p = {(double)i * 0.5, (double)i};
        ps.push(p);
        xs.push((double)i * 0.5);
        ys.push((double)i);
    }
    jout << "aos " << sum_x_aos(ps) << "\n";
    jout << "soa " << sum_x_soa(xs) << "\n";
    jout << "count of y " << ys.len << "\n";
    return 0;
}
```

ผลลัพธ์:

```
aos 249750.000000
soa 249750.000000
count of y 1000
```

ผลรวมทั้งสองเท่ากัน ลูป SoA อ่านเฉพาะอาเรย์ `xs` ส่วนลูป AoS ต้องข้ามค่า `y` ทุกตัว

**ลองทำ:** เพิ่มฟังก์ชัน `sum_y_soa` แล้วตรวจว่าผลรวมของ `ys` คือ 499500

## บทที่ 109. แคช: ลำดับแถวและลำดับ i-k-j กับ i-j-k

เมทริกซ์ในหน่วยความจำเก็บทีละแถว (row-major): `a[i*n + j]` การเดินตามแถวอ่านสมาชิกข้างเคียง ซึ่งเป็นมิตรกับแคช ส่วนการเดินลงตามคอลัมน์
กระโดดข้าม `n` ตัวทุกครั้ง ในการคำนวณ `C = A * B` ลำดับของลูปสามชั้นกำหนดว่าเมทริกซ์ใดถูกอ่านตามแถว ลำดับ i-k-j เดินตามแถวของ `B` และ `C`
ส่วนลำดับ i-j-k เดินลงตามคอลัมน์ของ `B` โปรแกรมทั้งสองได้เมทริกซ์เดียวกัน จึงต่างกันที่ความเร็วเท่านั้น (เมทริกซ์ขนาดนี้พอดีกับแคชทั้งคู่ ช่องว่างจึงอาจน้อย ประเด็นคือลำดับ)

```jk
#import <stdlib>
using stdlib;

int main() {
    int n = 64;
    double[] a = arr(n * n);
    double[] b = arr(n * n);
    double[] c1 = arr(n * n);
    double[] c2 = arr(n * n);
    for i in 0..n * n {
        a.push((double)(i % 7));
        b.push((double)(i % 5));
        c1.push(0.0);
        c2.push(0.0);
    }
    // i-j-k: the inner loop walks down a column of B (a jump of n numbers each time)
    for i in 0..n {
        for j in 0..n {
            for k in 0..n { c1[i * n + j] = c1[i * n + j] + a[i * n + k] * b[k * n + j]; }
        }
    }
    // i-k-j: the inner loop walks along a row of B and a row of C
    for i in 0..n {
        for k in 0..n {
            for j in 0..n { c2[i * n + j] = c2[i * n + j] + a[i * n + k] * b[k * n + j]; }
        }
    }
    bool same = true;
    for i in 0..n * n {
        if c1[i] != c2[i] { same = false; }
    }
    jout << "same matrix: " << same << "\n";
    return 0;
}
```

ผลลัพธ์:

```
same matrix: true
```

เมทริกซ์ทั้งสองเท่ากัน ลำดับของลูปจึงไม่เปลี่ยนคำตอบ เปลี่ยนแค่ลำดับที่หน่วยความจำถูกอ่าน

**ลองทำ:** เปลี่ยน `n` เป็น 128 แล้วเทียบเวลาของสองลูปด้วย `Time::mono_ns` (บทที่ 92) อย่าพิมพ์เวลาในการทดสอบที่ต้องรันซ้ำ

## บทที่ 110. เปรียบเทียบกับ C อย่างยุติธรรม

การจะพูดว่า J2K เร็วหรือช้ากว่า C ต้องเปรียบเทียบอัลกอริทึมเดียวกัน ข้อมูลเดียวกัน และการตั้งค่าเดียวกัน รันสองเวอร์ชันสลับกัน (A, B, A, B ...)
เพื่อให้ความร้อนและงานอื่นกระทบทั้งคู่เท่าๆ กัน เก็บเวลาที่ดีที่สุดจาก N รอบ และตรวจว่าทั้งสองให้คำตอบเดียวกันก่อนเปรียบเทียบเวลาใดๆ
โปรแกรมนี้แสดงรูปแบบของการทดสอบเช่นนี้: สองเวอร์ชันของเคอร์เนลเดียว รันสลับกัน เทียบคำตอบ และไม่พิมพ์เวลา

```jk
#import <stdlib>
using stdlib;

// kernel A: one chain of adds
double kernel_a(double[] v) {
    double s = 0.0;
    for i in 0..v.len { s = s + v[i]; }
    return s;
}

// kernel B: four chains of adds, the same answer
double kernel_b(double[] v) {
    double s0 = 0.0;
    double s1 = 0.0;
    double s2 = 0.0;
    double s3 = 0.0;
    int n = v.len;
    int i = 0;
    while i + 4 <= n {
        s0 = s0 + v[i];
        s1 = s1 + v[i + 1];
        s2 = s2 + v[i + 2];
        s3 = s3 + v[i + 3];
        i += 4;
    }
    double s = s0 + s1 + s2 + s3;
    while i < n {
        s = s + v[i];
        i += 1;
    }
    return s;
}

int main() {
    double[] v = arr(100000);
    for i in 0..100000 { v.push((double)(i % 9)); }
    int best_a = 0;
    int best_b = 0;
    double ra = 0.0;
    double rb = 0.0;
    for round in 0..7 {
        // A and B take turns, so the load of the machine hits both alike
        int t0 = Time::mono_ns();
        ra = kernel_a(v);
        int t1 = Time::mono_ns();
        rb = kernel_b(v);
        int t2 = Time::mono_ns();
        int da = t1 - t0;
        int db = t2 - t1;
        if round == 0 || da < best_a { best_a = da; }
        if round == 0 || db < best_b { best_b = db; }
    }
    jout << "same answer: " << (ra == rb) << "\n";
    jout << "done\n";
    return 0;
}
```

ผลลัพธ์:

```
same answer: true
done
```

เวลาเก็บไว้ใน `best_a` และ `best_b` แต่ไม่ได้พิมพ์ ผลลัพธ์จึงไม่เปลี่ยน เมื่อจะรายงานเวลา ให้พิมพ์ในการวัดของคุณเอง
คู่กับเคอร์เนลเดียวกันที่เขียนด้วย C บนข้อมูลเดียวกัน และบอกว่าใช้คอมไพเลอร์และตัวเลือกใด

**ลองทำ:** เพิ่มเคอร์เนลที่สาม แล้วรันในรอบสลับกัน คำตอบต้องตรงกันด้วย

## บทที่ 111. โครงข่ายประสาทเทียมคืออะไร

โครงข่ายประสาทเทียมคือหน่วยเล็กๆ จำนวนมาก แต่ละหน่วยคือผลรวมถ่วงน้ำหนักของอินพุต ที่ส่งผ่านฟังก์ชันหนึ่ง หนึ่งหน่วยที่เขียนด้วยมือด้วย double คือแนวคิดทั้งหมด: `out = relu(w1 * x1 + w2 * x2 + b)`

```jk
#import <stdlib>
#import <math>
using stdlib;
// one neuron: it weighs its inputs, adds a bias, and passes the sum through an activation (here relu)
double relu(double x) {
    if x > 0.0 { return x; }
    return 0.0;
}
void main() {
    double x1 = 2.0;
    double x2 = 1.0;
    double w1 = 0.5;
    double w2 = -1.0;
    double b = 0.2;
    double z = w1 * x1 + w2 * x2 + b;
    jout << "sum    = " << z << "\n";
    jout << "output = " << relu(z) << "\n";
    jout << "negative sum -> " << relu(-0.5) << "\n";
}

```

ผลลัพธ์:

```
sum    = 0.200000
output = 0.200000
negative sum -> 0.000000
```

น้ำหนัก `w1`, `w2` และ bias `b` คือตัวเลขที่การเทรนจะเปลี่ยน ที่นี่ผลรวมเป็นบวก relu จึงคงค่าไว้ ถ้าผลรวมเป็นลบจะกลายเป็น 0

**ลอง:** เปลี่ยน `x2` เป็น 3.0 แล้วทายผลลัพธ์ก่อนรัน

## บทที่ 112. เทนเซอร์

`Tensor` คือตารางตัวเลขที่มี `rows` และ `cols` ตัวเลขเป็น double เก็บเรียงทีละแถวในฟิลด์ `d` `Tensor::zeros(r, c)` สร้างตารางที่เต็มด้วย 0.0 ส่วน `set` กับ `get` เขียนและอ่านช่องตามแถวและคอลัมน์

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// a Tensor is a table of rows x cols doubles; zeros makes one filled with 0.0
void main() {
    Tensor t = Tensor::zeros(2, 3);
    t.set(0, 1, 5.0);
    t.set(1, 2, -1.5);
    jout << "shape " << t.rows << " x " << t.cols << "\n";
    jout << "get(0, 1) = " << t.get(0, 1) << "\n";
    jout << "get(1, 2) = " << t.get(1, 2) << "\n";
    for r in 0..t.rows {
        for c in 0..t.cols { jout << t.get(r, c) << " "; }
        jout << "\n";
    }
}

```

ผลลัพธ์:

```
shape 2 x 3
get(0, 1) = 5.000000
get(1, 2) = -1.500000
0.000000 5.000000 0.000000 
0.000000 0.000000 -1.500000 
```

ช่อง (r, c) คือ `d[r * cols + c]` `set` เปลี่ยนตารางในที่เดิม ส่วนการดำเนินการอย่าง `matmul`, `add` และ `relu` ไม่เปลี่ยนอินพุต แต่คืน Tensor ใหม่

**ลอง:** พิมพ์ `t.d[1 * 3 + 2]` แล้วตรวจว่าเท่ากับ `t.get(1, 2)`

## บทที่ 113. การคูณเมทริกซ์

ในการคูณเมทริกซ์ ช่อง (i, j) ของผลลัพธ์คือผลรวมของ `A[i][k] * B[k][j]` ทุก k `a.matmul(b)` คือลูปธรรมดา `a.matmul_fast(b)` ใช้ float32 และ dot product โดยใช้สี่เธรดเมื่อตารางใหญ่ ตารางเล็กใช้ลูปธรรมดา ผลจึงตรงกัน คอลัมน์ของ A ต้องเท่ากับแถวของ B

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// C = A x B with the plain loop (matmul) and the fast way (matmul_fast)
void show(Tensor c) {
    for r in 0..c.rows {
        for k in 0..c.cols { jout << c.get(r, k) << " "; }
        jout << "\n";
    }
}
void main() {
    Tensor a = Tensor::zeros(2, 3);
    Tensor b = Tensor::zeros(3, 2);
    for i in 0..6 {
        a.d[i] = (double)(i + 1);
        b.d[i] = (double)(i % 4);
    }
    show(a.matmul(b));
    // a big table: the fast way gives the same numbers, up to float32 rounding
    Tensor p = Tensor::zeros(40, 70);
    Tensor q = Tensor::zeros(70, 50);
    for i in 0..40 * 70 { p.d[i] = (double)(i % 11) * 0.125 - 0.5; }
    for i in 0..70 * 50 { q.d[i] = (double)(i % 7) * 0.25 - 0.75; }
    Tensor slow = p.matmul(q);
    Tensor fast = p.matmul_fast(q);
    double worst = 0.0;
    for i in 0..slow.rows * slow.cols {
        double diff = Math::abs(slow.d[i] - fast.d[i]);
        if diff > worst { worst = diff; }
    }
    jout << "shape " << fast.rows << " x " << fast.cols << ", same: " << (worst < 0.001) << "\n";
}

```

ผลลัพธ์:

```
4.000000 10.000000 
10.000000 25.000000 
shape 40 x 50, same: true
```

แถว 0 ของผลลัพธ์คือแถว 0 ของ A คูณ B: ช่องแรกคือ 1 * 0 + 2 * 2 + 3 * 0 = 4 ตารางใหญ่ถูกตรวจเทียบกับลูปธรรมดา

**ลอง:** พิมพ์ `fast.rows` และ `fast.cols` ก่อนการตรวจ แล้วยืนยันว่าได้ 40 และ 50

## บทที่ 114. เลเยอร์เชิงเส้น

เลเยอร์ของนิวรอนคือ `y = x @ w + b`: แถวของอินพุตคูณตารางน้ำหนัก แล้วบวก bias `Dense::make(inputs, outputs, seed)` สร้างน้ำหนักจาก seed จึงได้น้ำหนักเดิมเมื่อ seed เดิม `forward` จำอินพุตไว้ด้วย การเทรนต้องใช้ค่านี้ภายหลัง

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// a linear layer: y = x @ w + b. The same sum is computed here by hand, and the two agree.
void main() {
    Dense layer = Dense::make(3, 2, 7);
    Tensor x = Tensor::zeros(1, 3);
    x.set(0, 0, 1.0);
    x.set(0, 1, -2.0);
    x.set(0, 2, 0.5);
    Tensor y = layer.forward(x);
    jout << "y has " << y.rows << " row and " << y.cols << " columns\n";
    bool same = true;
    for j in 0..2 {
        double s = layer.b.get(0, j);
        for i in 0..3 { s += x.get(0, i) * layer.w.get(i, j); }
        jout << "y[" << j << "] = " << y.get(0, j) << "  by hand " << s << "\n";
        if Math::abs(s - y.get(0, j)) > 0.000001 { same = false; }
    }
    jout << "same: " << same << "\n";
}

```

ผลลัพธ์:

```
y has 1 row and 2 columns
y[0] = 0.615230  by hand 0.615230
y[1] = -0.542970  by hand -0.542970
same: true
```

เลเยอร์เชิงเส้นทำแค่นี้: ผลรวมถ่วงน้ำหนักสำหรับเอาต์พุตแต่ละตัว บวก bias การเทรนเปลี่ยน `w` และ `b`

**ลอง:** เปลี่ยนเป็น `Dense::make(3, 4, 7)` แล้วทายรูปร่างของ `y` ก่อนรัน

## บทที่ 115. ฟังก์ชันกระตุ้น

ถ้าไม่มีฟังก์ชันกระตุ้น เลเยอร์ซ้อนกันก็เป็นแค่เลเยอร์เดียว เพราะผลรวมของผลรวมยังเป็นผลรวม ฟังก์ชันกระตุ้นทำให้เอาต์พุตโค้ง: `relu(x)` คือ max(0, x) `tanh` อยู่ระหว่าง -1 ถึง 1 และ `sigmoid` อยู่ระหว่าง 0 ถึง 1 เขียนด้วยมือบน double ก่อน แล้วทำฟังก์ชันเดียวกันบนกราฟของค่า `Tensor32` ด้วย `g.relu`, `g.tanh` และ `g.sigmoid`

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// activation functions: by hand on doubles, then the same on a graph of float32 values
double relu(double x) {
    if x > 0.0 { return x; }
    return 0.0;
}
double sigmoid(double x) { return 1.0 / (1.0 + Math::exp(-x)); }
void main() {
    double[] xs = arr(4);
    xs.push(-2.0); xs.push(-0.5); xs.push(0.0); xs.push(1.5);
    for i in 0..4 {
        double x = xs[i];
        jout << "x " << x << "  relu " << relu(x) << "  tanh " << Math::tanh(x) << "  sigmoid " << sigmoid(x) << "\n";
    }
    Graph g = Graph::make();
    int a = g.input(Tensor32::from_list(1, 4, xs));
    int r = g.relu(a);
    int t = g.tanh(a);
    int s = g.sigmoid(a);
    jout << "graph relu " << g.value(r).d[0] << " " << g.value(r).d[3] << "\n";
    jout << "graph tanh " << g.value(t).d[0] << " " << g.value(t).d[3] << "\n";
    jout << "graph sigmoid " << g.value(s).d[2] << "\n";
}

```

ผลลัพธ์:

```
x -2.000000  relu 0.000000  tanh -0.964028  sigmoid 0.119203
x -0.500000  relu 0.000000  tanh -0.462117  sigmoid 0.377541
x 0.000000  relu 0.000000  tanh 0.000000  sigmoid 0.500000
x 1.500000  relu 1.500000  tanh 0.905148  sigmoid 0.817574
graph relu 0.000000 1.500000
graph tanh -0.964028 0.905148
graph sigmoid 0.500000
```

กราฟคำนวณเส้นโค้งเดียวกันด้วย float32 ตัวเลขหลักท้ายอาจต่างจาก double เล็กน้อย

**ลอง:** พิมพ์ `sigmoid(0.0)` แล้วตรวจว่าได้ 0.5

## บทที่ 116. loss: ค่าเฉลี่ยกำลังสองของความคลาดเคลื่อน

loss บอกว่าเอาต์พุตผิดแค่ไหน Mean squared error เอาความคลาดเคลื่อนทีละตัว ยกกำลังสอง แล้วหาค่าเฉลี่ย การยกกำลังสองทำให้ความผิดใหญ่มีน้ำหนักมากกว่าความผิดเล็ก และค่าลบไม่หักล้างค่าบวก

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// the loss by hand, then the same with the graph's mse node
void main() {
    double[] out = arr(3);
    out.push(0.8); out.push(0.2); out.push(0.6);
    double[] want = arr(3);
    want.push(1.0); want.push(0.0); want.push(1.0);
    double s = 0.0;
    for i in 0..3 {
        double e = out[i] - want[i];
        s += e * e;
        jout << "error " << i << ": " << e << "\n";
    }
    jout << "mse by hand = " << s / 3.0 << "\n";
    Graph g = Graph::make();
    int o = g.input(Tensor32::from_list(3, 1, out));
    int l = g.mse(o, Tensor32::from_list(3, 1, want));
    jout << "mse of the graph = " << g.value(l).d[0] << "\n";
}

```

ผลลัพธ์:

```
error 0: -0.200000
error 1: 0.200000
error 2: -0.400000
mse by hand = 0.080000
mse of the graph = 0.080000
```

`mse(เอาต์พุต, เป้าหมาย)` ของกราฟคืนโหนด `g.value(โหนด).d[0]` อ่านตัวเลขของมัน ผลทั้งสองแบบตรงกัน

**ลอง:** เปลี่ยนเอาต์พุตตัวที่สองจาก `0.2` เป็น `0.5` แล้วคำนวณ loss ใหม่ด้วยมือก่อนรัน

## บทที่ 117. ความชัน ตรวจด้วยสองวิธี

การเทรนต้องใช้ความชันของ loss คือ loss เปลี่ยนเท่าไรเมื่อน้ำหนักหนึ่งตัวเปลี่ยน สำหรับ `f(w) = (2w - 6)^2` ความชันคือ `2 * (2w - 6) * 2` การตรวจเชิงตัวเลขขยับ `w` ทีละนิดไปสองทาง แล้วหารการเปลี่ยนแปลงด้วยระยะ และ `backward` ของกราฟต้องให้ค่าเดียวกัน

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// f(w) = (2w - 6)^2: the slope by hand, the slope by a numerical check, and the slope from the graph
double f(double w) {
    double e = 2.0 * w - 6.0;
    return e * e;
}
void main() {
    double w = 1.0;
    double h = 0.001;
    double exact = 2.0 * (2.0 * w - 6.0) * 2.0;
    double numeric = (f(w + h) - f(w - h)) / (2.0 * h);
    jout << "f(1) = " << f(w) << "\n";
    jout << "slope by hand = " << exact << "\n";
    jout << "slope numeric = " << numeric << "\n";
    jout << "they agree: " << (Math::abs(exact - numeric) < 0.0001) << "\n";
    Graph g = Graph::make();
    double[] wv = arr(1);
    wv.push(w);
    double[] xv = arr(1);
    xv.push(2.0);
    double[] yv = arr(1);
    yv.push(6.0);
    int wn = g.param(Tensor32::from_list(1, 1, wv));
    g.mark();
    int x = g.input(Tensor32::from_list(1, 1, xv));
    int l = g.mse(g.matmul(x, wn), Tensor32::from_list(1, 1, yv));
    g.backward(l);
    jout << "slope from the graph = " << g.gradient(wn).d[0] << "\n";
}

```

ผลลัพธ์:

```
f(1) = 16.000000
slope by hand = -16.000000
slope numeric = -16.000000
they agree: true
slope from the graph = -16.000000
```

ที่ `w = 1` loss คือ 16 และความชันคือ -16 คือการเพิ่ม `w` ทำให้ loss ลด วิธีตรวจนี้ไลบรารีใช้กับทุกการดำเนินการ

**ลอง:** ใช้ `w = 3.0` ความชันตรงนั้นเป็น 0 ซึ่งคือจุดต่ำสุดของ loss

## บทที่ 118. gradient descent: น้ำหนักตัวเดียว

gradient descent ขยับน้ำหนักทีละนิดสวนทางกับความชัน ทำซ้ำไปเรื่อยๆ rate (ที่นี่ 0.05) กำหนดว่าแต่ละก้าวใหญ่แค่ไหน ข้อมูลคือ `y = 2x` ที่ x = 1, 2, 3 ดังนั้นน้ำหนักที่ถูกคือ 2

```jk
#import <stdlib>
using stdlib;
// fit one weight: y = 2x on x = 1, 2, 3. The loss is the mean of (w*x - y)^2.
void main() {
    double[] xs = arr(3);
    xs.push(1.0); xs.push(2.0); xs.push(3.0);
    double[] ys = arr(3);
    ys.push(2.0); ys.push(4.0); ys.push(6.0);
    double w = 0.0;
    double rate = 0.05;
    for step in 0..60 {
        double g = 0.0;
        double loss = 0.0;
        for i in 0..3 {
            double e = w * xs[i] - ys[i];
            loss += e * e;
            g += 2.0 * e * xs[i];
        }
        if step % 10 == 0 { jout << "step " << step << "  w = " << w << "  loss = " << loss / 3.0 << "\n"; }
        w = w - rate * g / 3.0;
    }
    jout << "w after 60 steps = " << w << "\n";
}

```

ผลลัพธ์:

```
step 0  w = 0.000000  loss = 18.666667
step 10  w = 1.996276  loss = 0.000065
step 20  w = 1.999993  loss = 0.000000
step 30  w = 2.000000  loss = 0.000000
step 40  w = 2.000000  loss = 0.000000
step 50  w = 2.000000  loss = 0.000000
w after 60 steps = 2.000000
```

แต่ละก้าวใช้ความชันจากข้อมูล น้ำหนักจึงเคลื่อนเข้าหา 2 และ loss ลดลง rate ต้องเล็กพอ บทเรื่อง learning rate แสดงว่าเกิดอะไรขึ้นเมื่อใหญ่เกินไป

**ลอง:** เปลี่ยนข้อมูลเป็น `y = 3x` แล้วหาน้ำหนักที่ได้

## บทที่ 119. น้ำหนักสองตัว: เส้นตรง

เส้นตรงต้องใช้น้ำหนักสองตัว: `y = w * x + b` การไล่ลงชันชุดเดิมขยับทั้งสองตัว แต่ละตัวด้วยค่าเฉลี่ยความชันของตัวเองจากจุดข้อมูล ข้อมูลคือ `y = 3x + 1` ดังนั้นคำตอบคือ w = 3 และ b = 1

```jk
#import <stdlib>
using stdlib;
// the line y = 3x + 1 on five points: w is the slope, b the bias, both moved by their average slope
void main() {
    double[] xs = arr(5);
    double[] ys = arr(5);
    for i in 0..5 {
        xs.push((double)i);
        ys.push(3.0 * (double)i + 1.0);
    }
    double w = 0.0;
    double b = 0.0;
    double rate = 0.02;
    for step in 0..1500 {
        double gw = 0.0;
        double gb = 0.0;
        double loss = 0.0;
        for i in 0..5 {
            double e = w * xs[i] + b - ys[i];
            loss += e * e;
            gw += 2.0 * e * xs[i];
            gb += 2.0 * e;
        }
        if step % 500 == 0 { jout << "step " << step << "  loss " << loss / 5.0 << "\n"; }
        w = w - rate * gw / 5.0;
        b = b - rate * gb / 5.0;
    }
    jout << "w = " << w << "  b = " << b << "\n";
}

```

ผลลัพธ์:

```
step 0  loss 67.000000
step 500  loss 0.000000
step 1000  loss 0.000000
w = 3.000000  b = 1.000000
```

loss ลงไปใกล้ 0 เพราะข้อมูลอยู่บนเส้นตรงพอดี

**ลอง:** เพิ่มจุด x = 5, y = 20 (ไม่อยู่บนเส้น) ลงในข้อมูล แล้วดูว่า w และ b เปลี่ยนอย่างไร

## บทที่ 120. XOR ด้วยโครงข่ายเล็ก

XOR ให้ 1 เมื่อมีอินพุตเพียงตัวเดียวที่เป็น 1 เส้นตรงเส้นเดียวแยกคำตอบนี้ไม่ได้ แต่เลเยอร์ซ่อนที่มีหน่วย tanh ทำได้ นี่คือโครงข่ายเล็กแบบคลาสสิก seed ถูกกำหนดไว้ จึงรันได้ผลเดิมทุกครั้ง และ loss ลดลงทีละช่วง

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// XOR: two layers (6 tanh units, then a sigmoid) learn it. The seeds are fixed.
void main() {
    Graph g = Graph::make();
    Linear l1 = g.linear(2, 6, 1);
    Linear l2 = g.linear(6, 1, 2);
    g.mark();
    double[] xv = arr(8);
    xv.push(0.0); xv.push(0.0); xv.push(0.0); xv.push(1.0);
    xv.push(1.0); xv.push(0.0); xv.push(1.0); xv.push(1.0);
    double[] yv = arr(4);
    yv.push(0.0); yv.push(1.0); yv.push(1.0); yv.push(0.0);
    Tensor32 xs = Tensor32::from_list(4, 2, xv);
    Tensor32 ys = Tensor32::from_list(4, 1, yv);
    for step in 0..3000 {
        int h = g.tanh(g.apply(l1, g.input(xs)));
        int o = g.sigmoid(g.apply(l2, h));
        int l = g.mse(o, ys);
        if step % 1000 == 0 { jout << "step " << step << "  loss " << g.value(l).d[0] << "\n"; }
        g.backward(l);
        g.sgd(0.5);
        g.clear();
    }
    int h = g.tanh(g.apply(l1, g.input(xs)));
    Tensor32 out = g.value(g.sigmoid(g.apply(l2, h)));
    for i in 0..4 {
        jout << (int)(xs.get(i, 0)) << " xor " << (int)(xs.get(i, 1)) << " -> " << (int)(out.d[i] + 0.5) << "  (exact " << out.d[i] << ")\n";
    }
}

```

ผลลัพธ์:

```
step 0  loss 0.277362
step 1000  loss 0.001553
step 2000  loss 0.000650
0 xor 0 -> 0  (exact 0.010549)
0 xor 1 -> 1  (exact 0.976775)
1 xor 0 -> 1  (exact 0.980717)
1 xor 1 -> 0  (exact 0.024364)
```

คำตอบปัดเป็น 0 หรือ 1 และแสดงค่าจริงด้วย ถ้า seed ไหนไม่ได้คำตอบ ให้เปลี่ยน seed (อาร์กิวเมนต์สุดท้ายของ `linear`)

**ลอง:** ใช้เลเยอร์ซ่อน 2 หน่วย (`g.linear(2, 2, 1)` กับ `g.linear(2, 1, 2)`) แล้วดูว่ายังเรียนได้หรือไม่

## บทที่ 121. backpropagation บนกราฟ

backpropagation คือกฎลูกโซ่ที่ไล่กลับทางบนกราฟ แต่ละโหนดรู้การดำเนินการของมัน (`op`) และพาเรนต์ของมัน (`pa`, `pb`) `backward(loss)` เริ่มด้วยความชัน 1 ที่ loss แล้วส่งต่อให้พาเรนต์ ที่นี่กราฟประกอบด้วย input, param, matmul, relu และ mse และตรวจความชันของน้ำหนักด้วยมือ

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// the operation of a node, by its number (the OP_ functions of <neuron>)
String op_name(int op) {
    if op == OP_INPUT() { return "input"; }
    if op == OP_PARAM() { return "param"; }
    if op == OP_MATMUL() { return "matmul"; }
    if op == OP_RELU() { return "relu"; }
    if op == OP_MSE() { return "mse"; }
    return "other";
}
void main() {
    Graph g = Graph::make();
    double[] wv = arr(2);
    wv.push(0.5); wv.push(1.0);
    double[] xv = arr(2);
    xv.push(1.0); xv.push(2.0);
    double[] tv = arr(1);
    tv.push(1.0);
    int w = g.param(Tensor32::from_list(2, 1, wv));
    g.mark();
    int x = g.input(Tensor32::from_list(1, 2, xv));
    int h = g.relu(g.matmul(x, w));
    int loss = g.mse(h, Tensor32::from_list(1, 1, tv));
    for i in 0..g.count { jout << "node " << i << " " << op_name(g.op[i]) << "\n"; }
    g.backward(loss);
    Tensor32 gw = g.gradient(w);
    jout << "loss " << g.value(loss).d[0] << "\n";
    jout << "gradient of w: " << gw.d[0] << " " << gw.d[1] << "\n";
}

```

ผลลัพธ์:

```
node 0 param
node 1 input
node 2 matmul
node 3 relu
node 4 mse
loss 2.250000
gradient of w: 3.000000 6.000000
```

กฎลูกโซ่ให้ความชันของน้ำหนักเป็น `2 * (2.5 - 1.0) * x` คือ `(3, 6)` `backward` เดินโหนดกลับทาง จาก loss ย้อนไปยังอินพุต matmul ส่ง `dy * B^T` ให้ A และ `A^T * dy` ให้ B เลขของการดำเนินการคือค่าของฟังก์ชัน `OP_` ของมัน

**ลอง:** เปลี่ยนน้ำหนักเป็น `(0.5, -1.0)` แล้วทายความชันก่อนรัน relu ปิดกั้นมัน คำตอบคือ `(0, 0)`

## บทที่ 122. mini-batch และการสลับแถว

การเทรนทุกแถวพร้อมกันช้าเมื่อข้อมูลใหญ่ mini-batch จึงใช้ทีละไม่กี่แถว การสลับแถวทุก epoch ทำให้แต่ละชุดต่างกัน `shuffled(n, seed)` ให้ลำดับสุ่มของ 0 ถึง n-1 จาก seed คงที่ seed เดิมจึงได้ลำดับเดิมเสมอ epoch คือการผ่านข้อมูลทุกแถวหนึ่งรอบ

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// eight points of y = 2x + 1; each epoch shuffles the rows and trains on two mini-batches of four
void main() {
    Tensor32 xs = Tensor32::zeros(8, 1);
    Tensor32 ys = Tensor32::zeros(8, 1);
    for i in 0..8 {
        xs.set(i, 0, (double)i / 4.0);
        ys.set(i, 0, 2.0 * (double)i / 4.0 + 1.0);
    }
    Graph g = Graph::make();
    Linear lin = g.linear(1, 1, 3);
    g.mark();
    for epoch in 0..3 {
        int[] perm = shuffled(8, epoch + 1);
        jout << "epoch " << epoch << " order:";
        for i in 0..8 { jout << " " << perm[i]; }
        jout << "\n";
        for bt in 0..2 {
            int[] idx = arr(4);
            for q in 0..4 { idx.push(perm[bt * 4 + q]); }
            int o = g.apply(lin, g.input(xs.gather(idx)));
            int l = g.mse(o, ys.gather(idx));
            g.backward(l);
            g.sgd(0.5);
            g.clear();
        }
        int full = g.apply(lin, g.input(xs));
        int whole = g.mse(full, ys);
        jout << "  loss on all rows " << g.value(whole).d[0] << "\n";
        g.clear();
    }
}

```

ผลลัพธ์:

```
epoch 0 order: 6 1 4 5 0 7 2 3
  loss on all rows 12.326004
epoch 1 order: 1 3 5 6 4 2 7 0
  loss on all rows 8.866676
epoch 2 order: 2 4 0 7 6 1 3 5
  loss on all rows 6.333731
```

แต่ละ epoch ได้ลำดับใหม่ ชุดข้อมูลจึงใหม่ loss ของทุกแถวลดลงจาก epoch หนึ่งไปอีก epoch

**ลอง:** เทียบ `shuffled(8, 9)` กับลำดับของ seed 1 แล้วตรวจว่าต่างกัน

## บทที่ 123. softmax และ cross-entropy

สำหรับการจัดประเภท เอาต์พุตคือคะแนนหนึ่งตัวต่อคลาส `softmax` เปลี่ยนคะแนนแต่ละแถวเป็นความน่าจะเป็นที่รวมกันได้ 1 cross-entropy คือ loss ของงานนี้: `-log(ความน่าจะเป็นของคลาสที่ถูก)` หาค่าเฉลี่ยทุกแถว ค่านี้เล็กเมื่อคลาสที่ถูกมีความน่าจะเป็นสูง

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// three samples, three classes: row r holds the scores of the classes 0, 1, 2; the right class of row r is r
void main() {
    double[] v = arr(9);
    v.push(2.0); v.push(0.5); v.push(-1.0);
    v.push(0.1); v.push(0.3); v.push(0.2);
    v.push(1.0); v.push(0.0); v.push(2.5);
    Tensor s = Tensor::zeros(3, 3);
    for i in 0..9 { s.d[i] = v[i]; }
    Tensor p = s.softmax();
    for r in 0..3 {
        double sum = 0.0;
        jout << "probabilities " << r << ":";
        for c in 0..3 {
            jout << " " << p.get(r, c);
            sum += p.get(r, c);
        }
        jout << "  sum " << sum << "\n";
    }
    int[] right = arr(3);
    right.push(0); right.push(1); right.push(2);
    double hand = 0.0;
    for r in 0..3 { hand = hand - Math::log(p.get(r, right[r])); }
    jout << "cross-entropy by hand " << hand / 3.0 << "\n";
    Graph g = Graph::make();
    int a = g.input(Tensor32::from_list(3, 3, v));
    int l = g.softmax_ce(a, right);
    jout << "cross-entropy by the library " << g.value(l).d[0] << "\n";
}

```

ผลลัพธ์:

```
probabilities 0: 0.785597 0.175290 0.039113  sum 1.000000
probabilities 1: 0.300610 0.367165 0.332225  sum 1.000000
probabilities 2: 0.170953 0.062890 0.766157  sum 1.000000
cross-entropy by hand 0.503207
cross-entropy by the library 0.503207
```

`softmax_ce` ทำทั้งสองขั้น (softmax แล้วลอการิทึม) ในโหนดเดียว และให้ตัวเลขเดียวกับการคำนวณด้วยมือ

**ลอง:** ให้คลาสที่ถูกของแถว 0 เป็นคลาส 2 (`right[0] = 2`) แล้วดู loss เพิ่มขึ้น เพราะคะแนนของคลาส 2 ในแถวนั้นต่ำที่สุด

## บทที่ 124. learning rate

learning rate คือขนาดของแต่ละก้าว เล็กไปเทรนจะช้า ใหญ่ไปแต่ละก้าวจะข้ามจุดต่ำสุด และน้ำหนักแกว่งกว้างขึ้นเรื่อยๆ ที่นี่เทรนเส้น `y = 2x` ด้วยสองค่า: 0.2 ลู่เข้า ส่วน 0.22 ลู่ออก

```jk
#import <stdlib>
#import <math>
using stdlib;
// y = 2x on x = 1, 2, 3: train w with one rate for 60 steps and return it
double train(double rate) {
    double[] xs = arr(3);
    xs.push(1.0); xs.push(2.0); xs.push(3.0);
    double[] ys = arr(3);
    ys.push(2.0); ys.push(4.0); ys.push(6.0);
    double w = 0.0;
    for step in 0..60 {
        double g = 0.0;
        for i in 0..3 { g += 2.0 * (w * xs[i] - ys[i]) * xs[i]; }
        w = w - rate * g / 3.0;
    }
    return w;
}
void main() {
    double small = train(0.2);
    double big = train(0.22);
    jout << "rate 0.2:  w = " << small << "  converged: " << (Math::abs(small - 2.0) < 0.01) << "\n";
    jout << "rate 0.22: w = " << big << "  converged: " << (Math::abs(big - 2.0) < 0.01) << "\n";
}

```

ผลลัพธ์:

```
rate 0.2:  w = 1.999627  converged: true
rate 0.22: w = -43.183479  converged: false
```

สำหรับข้อมูลนี้ rate ต้องต่ำกว่าประมาณ 0.214 ความโค้งของ loss คือ (2/3) * (1 + 4 + 9) = 9.33 และแต่ละก้าวคูณ error ด้วย `1 - rate * 9.33` ตัวคูณนี้มีขนาด 1 ที่ rate 0.214 เลือกค่าที่ใหญ่ที่สุดที่ยังลู่เข้า และเผื่อไว้บ้าง

**ลอง:** ลอง 0.21 กับ 0.1 แล้วดูว่าค่าไหนลู่เข้าเร็วกว่า

## บทที่ 125. น้ำหนักเริ่มต้น

น้ำหนักเริ่มต้นสำคัญ ถ้าเป็นศูนย์ทั้งหมด นิวรอนทุกตัวจะเรียนสิ่งเดียวกัน น้ำหนักสุ่มทำลายความเท่ากันนี้ได้ แต่ต้องมีขนาดเล็ก `Dense::make` สุ่มแต่ละน้ำหนักจาก -1 ถึง 1 คูณด้วย `sqrt(2 / inputs)` นิวรอนที่มีอินพุตมากจึงได้น้ำหนักเล็กลง seed ทำให้ตัวเลขสุ่มเหมือนเดิมทุกครั้งที่รัน

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// the starting weights: the same seed gives the same weights; the size is limited by sqrt(2 / inputs)
void main() {
    Dense a = Dense::make(4, 3, 5);
    Dense b = Dense::make(4, 3, 5);
    Dense c = Dense::make(4, 3, 6);
    double limit = Math::sqrt(2.0 / 4.0);
    bool inside = true;
    bool same = true;
    bool other = false;
    for i in 0..12 {
        if Math::abs(a.w.d[i]) > limit { inside = false; }
        if a.w.d[i] != b.w.d[i] { same = false; }
        if a.w.d[i] != c.w.d[i] { other = true; }
    }
    jout << "limit sqrt(2/4) = " << limit << "\n";
    jout << "first weights of seed 5:";
    for i in 0..4 { jout << " " << a.w.d[i]; }
    jout << "\n";
    jout << "all inside the limit: " << inside << "\n";
    jout << "same seed, same weights: " << same << "\n";
    jout << "other seed, other weights: " << other << "\n";
}

```

ผลลัพธ์:

```
limit sqrt(2/4) = 0.707107
first weights of seed 5: 0.287792 0.613769 0.699329 0.046669
all inside the limit: true
same seed, same weights: true
other seed, other weights: true
```

น้ำหนักทุกตัวของเลเยอร์อยู่ในขอบเขต เลเยอร์สองตัวที่ seed เดียวกันเท่ากัน และ seed ต่างกันได้ตัวเลขต่างกัน

**ลอง:** ทำเลเยอร์ที่มี 16 อินพุต แล้วพิมพ์ขอบเขต `sqrt(2 / 16)` ก่อนรัน

## บทที่ 126. embedding

คำจะเข้าเลเยอร์เป็นข้อความไม่ได้ ดังนั้นแต่ละคำได้หมายเลข (id) และตาราง embedding มีหนึ่งแถวต่อหนึ่ง id `g.embed(table, ids)` คัดลอกแถวของ id ที่ให้มา ประโยคสามคำจึงได้ตารางสามแถว แถวเหล่านี้ถูกเรียนเหมือนน้ำหนักอื่นๆ ที่นี่คลังคำมีหกคำ

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// six words; each word is one row of the table (4 numbers); the id of a word is its row number
void main() {
    String[] words = arr(6);
    words.push("cat"); words.push("sat"); words.push("on");
    words.push("the"); words.push("mat"); words.push("dog");
    Graph g = Graph::make();
    int table = g.param(Tensor32::random(6, 4, 3, 0.5));
    g.mark();
    int[] ids = arr(3);
    ids.push(3); ids.push(5); ids.push(1);
    int e = g.embed(table, ids);
    Tensor32 rows = g.value(e);
    jout << "rows " << rows.rows() << " columns " << rows.cols() << "\n";
    for i in 0..3 {
        jout << words[ids[i]] << ":";
        for k in 0..4 { jout << " " << rows.get(i, k); }
        jout << "\n";
    }
    bool same = true;
    for k in 0..4 {
        if rows.get(1, k) != g.value(table).get(5, k) { same = false; }
    }
    jout << "the row of dog is row 5 of the table: " << same << "\n";
}

```

ผลลัพธ์:

```
rows 3 columns 4
the: -0.383500 0.475000 -0.476500 -0.438000
dog: -0.187500 -0.385000 0.183500 -0.170000
sat: -0.179500 0.159000 -0.048500 -0.114000
the row of dog is row 5 of the table: true
```

ประโยคคือ id 3, 5, 1: the, dog, sat การค้นหาคัดลอกแถว และระหว่างเทรนความชันของการค้นหาจะกลับไปที่แถวเดิม

**ลอง:** เปลี่ยนประโยคเป็น `ids` 0, 1, 4 (cat, sat, mat) แล้วตรวจแถวแรกอีกครั้ง

## บทที่ 127. โมเดลตัวอักษรขนาดเล็ก

โมเดลระดับตัวอักษรอ่านไบต์ เมื่อได้ไบต์ 8 ตัวล่าสุด มันทายไบต์ถัดไปในทุกตำแหน่ง `Gpt` ใน `<neuron>` คือโมเดลนี้ในขนาดเล็ก มี embedding, attention, เลเยอร์ GELU และ AdamW สำหรับการเทรน ที่นี่ข้อความสั้นๆ ที่ซ้ำกันสอนรูปแบบ และ loss ลดลง

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// a tiny character model: it reads 8 bytes and guesses the next one at every place. The text repeats, so the loss falls.
Gpt m;
void main() {
    String text = "abcabcabcabcabcabcabcabc";
    int[] data = Gpt::bytes(text);
    m = Gpt::make(256, 8, 16, 2, 1, 1);
    int[] starts = arr(4);
    starts.push(0); starts.push(4); starts.push(8); starts.push(12);
    for step in 0..60 {
        double loss = m.step(data, starts, 0.01, 0.0, 1.0);
        if step % 15 == 0 { jout << "step " << step << "  loss " << loss << "\n"; }
    }
    jout << "loss at the end " << m.loss_on(data, starts) << "\n";
}

```

ผลลัพธ์:

```
step 0  loss 6.085010
step 15  loss 0.248414
step 30  loss 0.010925
step 45  loss 0.002814
loss at the end 0.001733
```

แต่ละตัวเลขคือ loss เฉลี่ยของชุดข้อมูลก่อนการปรับน้ำหนักในก้าวนั้น บรรทัดสุดท้ายวัดหลังเทรนโดยไม่เรียนเพิ่ม

**ลอง:** ลองรูปแบบสั้นๆ อื่น เช่น `"xyxyxyxyxyxyxyxyxyxyxyxy"` แล้วเทียบว่า loss ลดเร็วแค่ไหน

## บทที่ 128. บันทึกและโหลดน้ำหนัก

โครงข่ายที่เทรนแล้วจะมีประโยชน์ก็ต่อเมื่อเก็บไว้ได้ `save(path)` เขียนน้ำหนักเป็นข้อความ (ขนาดของเลเยอร์และตัวเลข) และ `Network::load(path)` อ่านกลับมา โครงข่ายที่โหลดแล้วให้คำตอบเหมือนตัวที่บันทึก

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// train a network on XOR, save its weights to a file, load them back and compare the answers
void main() {
    Tensor x = Tensor::zeros(4, 2);
    Tensor y = Tensor::zeros(4, 1);
    x.set(1, 1, 1.0); x.set(2, 0, 1.0); x.set(3, 0, 1.0); x.set(3, 1, 1.0);
    y.set(1, 0, 1.0); y.set(2, 0, 1.0);
    Network n = Network::make();
    n.add(2, 8);
    n.add(8, 1);
    n.fit(x, y, 4000, 0.1);
    bool saved = n.save("tut_net.jw");
    Network m = Network::load("tut_net.jw");
    Tensor a = n.predict(x);
    Tensor b = m.predict(x);
    double worst = 0.0;
    for i in 0..4 {
        double d = Math::abs(a.d[i] - b.d[i]);
        if d > worst { worst = d; }
    }
    jout << "saved: " << saved << "\n";
    jout << "loaded answers equal: " << (worst < 0.000001) << "\n";
    Fs::remove("tut_net.jw");
}

```

ผลลัพธ์:

```
saved: true
loaded answers equal: true
```

ไฟล์เป็นข้อความธรรมดา จึงอ่านและคัดลอกได้ โปรแกรมลบไฟล์ของมันเมื่อจบ

**ลอง:** พิมพ์ `n.text()` ก่อนบันทึก แล้วหาบรรทัดแรก `neuron-jw 1`

## บทที่ 129. inference: การใช้โครงข่ายที่เทรนแล้ว

inference คือการใช้โครงข่ายที่เทรนแล้ว รันเฉพาะขั้นไปข้างหน้า `predict` ไม่เรียนรู้ น้ำหนักจึงไม่เปลี่ยนไม่ว่าจะเรียกกี่ครั้ง นี่คือสิ่งที่โปรแกรมที่เสร็จแล้วทำกับโครงข่ายที่โหลดมา

```jk
#import <stdlib>
#import <neuron>
using stdlib;
// inference: a trained network answers; predict runs only the forward pass
void main() {
    Tensor x = Tensor::zeros(4, 2);
    Tensor y = Tensor::zeros(4, 1);
    x.set(1, 1, 1.0); x.set(2, 0, 1.0); x.set(3, 0, 1.0); x.set(3, 1, 1.0);
    y.set(1, 0, 1.0); y.set(2, 0, 1.0);
    Network n = Network::make();
    n.add(2, 8);
    n.add(8, 1);
    n.fit(x, y, 4000, 0.1);
    String before = n.text();
    Tensor answer = n.predict(x);
    for i in 0..4 {
        jout << "(" << x.get(i, 0) << ", " << x.get(i, 1) << ") -> " << (int)(answer.d[i] + 0.5) << "\n";
    }
    Tensor one = Tensor::zeros(1, 2);
    one.set(0, 0, 1.0);
    jout << "(1, 0) -> " << (int)(n.predict(one).d[0] + 0.5) << "\n";
    for k in 0..100 { n.predict(x); }
    jout << "weights unchanged after 100 calls: " << (n.text() == before) << "\n";
}

```

ผลลัพธ์:

```
(0.000000, 0.000000) -> 0
(0.000000, 1.000000) -> 1
(1.000000, 0.000000) -> 1
(1.000000, 1.000000) -> 0
(1, 0) -> 1
weights unchanged after 100 calls: true
```

คำตอบปัดเป็น 0 หรือ 1 การตรวจสุดท้ายเทียบข้อความของน้ำหนักทั้งหมดก่อนและหลัง 100 ครั้งที่เรียก `predict`

**ลอง:** ทายคำตอบของ `(0, 0)` และ `(1, 1)` แล้วเทียบกับตารางข้างบน

## บทที่ 130. ทำไมการคูณเมทริกซ์คือความเร็ว

เวลาส่วนใหญ่ของการเทรนไปอยู่ที่การคูณเมทริกซ์ เลเยอร์แต่ละตัวทำสามครั้งต่อหนึ่ง step (ขั้นไปข้างหน้า ความชันของอินพุต และความชันของน้ำหนัก) `matmul_fast` ทำให้แต่ละการคูณเร็วขึ้น: ตัวเลขเป็น float32 แต่ละ dot product ใช้เวกเตอร์กว้างสี่สองตัวสะสม และแถวถูกแบ่งให้สี่เธรด โปรแกรมนี้ตรวจตารางเร็วเทียบกับแบบธรรมดา และไม่พิมพ์เวลา เพราะเวลาต่างกันในแต่ละเครื่อง

```jk
#import <stdlib>
#import <math>
#import <neuron>
using stdlib;
// one matrix product of 64 x 64 by 64 x 64: 262144 multiply-adds. The fast way must give the same table.
void main() {
    Tensor a = Tensor::zeros(64, 64);
    Tensor b = Tensor::zeros(64, 64);
    for i in 0..64 * 64 {
        a.d[i] = (double)(i % 9) * 0.1 - 0.4;
        b.d[i] = (double)(i % 5) * 0.2 - 0.4;
    }
    Tensor slow = a.matmul(b);
    Tensor fast = a.matmul_fast(b);
    double worst = 0.0;
    double sum = 0.0;
    for i in 0..64 * 64 {
        double diff = Math::abs(slow.d[i] - fast.d[i]);
        if diff > worst { worst = diff; }
        sum += fast.d[i];
    }
    jout << "multiply-adds: " << 64 * 64 * 64 << "\n";
    jout << "same table: " << (worst < 0.001) << "\n";
    jout << "sum of the table: " << sum << "\n";
}

```

ผลลัพธ์:

```
multiply-adds: 262144
same table: true
sum of the table: 0.020103
```

micro-kernel คือส่วนในสุดของการคูณเมทริกซ์: บล็อกเล็กๆ ของผลลัพธ์ (เช่น 4 แถว คูณ 8 คอลัมน์) ถูกเก็บในรีจิสเตอร์เวกเตอร์ระหว่างที่ลูปตามมิติที่ใช้ร่วมทำงาน ตัวเลขจึงถูกโหลดครั้งเดียวแล้วใช้ซ้ำ เคอร์เนล 4x8 แบบนี้เป็นการทดลองในงานของคอมไพเลอร์เอง และยังไม่อยู่ใน `<neuron>` ส่วน `matmul_fast` ข้างบนคือตัวที่ใช้ได้วันนี้

**ลอง:** เปลี่ยนขนาด 64 เป็น 128 แล้วตรวจว่าตารางยังเหมือนเดิม (งานเพิ่มเป็นแปดเท่า)

## บทที่ 131. โปรแกรมที่แบ่งเป็นหลายไฟล์

โปรแกรมใหญ่แบ่งเป็นหลายไฟล์ ไฟล์ `.j` แต่ละไฟล์มีเรื่องเดียว (รูปร่าง รายงาน ตัวแยกข้อความ) และไม่มี `main` ไฟล์ที่มี `main` (`.jk`) จะ import ไฟล์เหล่านี้ ไฟล์หนึ่งถูกอ่านครั้งเดียวแม้มีสองไฟล์ import มัน ในตัวอย่าง `report.j` ใช้ `geometry.j` และ `main.jk` ใช้ทั้งสองไฟล์

`geometry.j`:

```jk
// geometry.j -- a component: a point and the distance between two points. No main here.
struct Point {
    int x;
    int y;
}

int manhattan(Point a, Point b) {
    int dx = a.x - b.x;
    int dy = a.y - b.y;
    if dx < 0 { dx = -dx; }
    if dy < 0 { dy = -dy; }
    return dx + dy;
}
```

`ec_multi_files.jk`:

`report.j`:

```jk
#import <stdlib>
using stdlib;

#import "geometry"

// report.j -- a component that uses geometry.j
void print_distance(Point a, Point b) {
    jout << "distance " << manhattan(a, b) << "\n";
}
```

`ec_multi_files.jk`:

```jk
#import <stdlib>
using stdlib;

#import "geometry"
#import "report"

void main() {
    Point home = {0, 0};
    Point shop = {3, -4};
    print_distance(home, shop);
    jout << "same again: " << manhattan(shop, home) << "\n";
}
```

ผลลัพธ์:

```
distance 7
same again: 7
```

คอมไพล์เฉพาะไฟล์หลัก: `jcmp main.jk -o main` คอมไพเลอร์หา `report.j` และ `geometry.j` ที่อยู่ข้างๆ เอง ชื่อไฟล์ต้องตรงกับชื่อที่ import

**ลองทำ:** เพิ่มฟังก์ชัน `int chebyshev(Point a, Point b)` ใน `geometry.j` (ค่าผลต่างที่มากกว่า) แล้วพิมพ์ค่านั้นจาก `main.jk`

## บทที่ 132. เขียนเทสต์ให้ฟังก์ชันของเรา

เทสต์ตรวจผลลัพธ์ทีละอย่าง: เรียกฟังก์ชันด้วยค่าที่รู้อยู่แล้ว แล้วเทียบกับคำตอบที่เราคาดไว้ นี่คือตัวรันเทสต์เล็กๆ ใน J2K แต่ละการตรวจพิมพ์ `PASS` หรือ `FAIL` และบรรทัดสุดท้ายนับจำนวน คุณเก็บตัวรันนี้ไว้ในไฟล์ `.j` แล้วใช้ในทุกโปรแกรมได้

```jk
#import <stdlib>
using stdlib;

int passed = 0;
int failed = 0;

// the function under test
int clamp(int x, int lo, int hi) {
    if x < lo { return lo; }
    if x > hi { return hi; }
    return x;
}

void check_int(String name, int got, int want) {
    if got == want {
        passed += 1;
        jout << "PASS " << name << "\n";
    } else {
        failed += 1;
        jout << "FAIL " << name << ": got " << got << ", want " << want << "\n";
    }
}

void main() {
    check_int("below the range", clamp(-5, 0, 10), 0);
    check_int("inside the range", clamp(7, 0, 10), 7);
    check_int("above the range", clamp(99, 0, 10), 10);
    check_int("the edge", clamp(10, 0, 10), 10);
    jout << passed << " passed, " << failed << " failed\n";
}
```

ผลลัพธ์:

```
PASS below the range
PASS inside the range
PASS above the range
PASS the edge
4 passed, 0 failed
```

ผลลัพธ์ของตัวรันเทสต์: บรรทัด `FAIL` บอกชื่อการตรวจ ค่าที่ฟังก์ชันคืนมา และค่าที่คาดไว้ ให้มี `check` หนึ่งอันต่อพฤติกรรมหนึ่งอย่าง พร้อมชื่อที่บอกว่าตรวจอะไร

**ลองทำ:** เปลี่ยนค่าที่คาดไว้ให้เป็นค่าผิดสักตัว แล้วดูบรรทัด `FAIL` และตัวนับ

## บทที่ 133. จัดการข้อผิดพลาดตอนอ่านข้อมูล

ข้อมูลเข้าอาจผิดได้ และข้อมูลผิดไม่ใช่บั๊กของโปรแกรม ฟังก์ชันที่อาจล้มเหลวคืนค่า `Result<int, Error>`: เป็น `Ok` พร้อมค่า หรือ `Err` พร้อมข้อความ โปรแกรมนี้อ่านคำจากข้อมูลเข้า พิมพ์ผลของแต่ละคำ และทำต่อเมื่อคำหนึ่งผิด ข้อมูลเข้าคือ `12 x -3 7y 40`

```jk
#import <stdlib>
using stdlib;

// a whole number from text: an optional minus sign, then digits only
Result<int, Error> parse_int(char^ s) {
    int i = 0;
    bool negative = false;
    if s[0] == '-' {
        negative = true;
        i = 1;
    }
    if s[i] == 0 {
        return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "empty number"));
    }
    int value = 0;
    while s[i] != 0 {
        if s[i] < '0' || s[i] > '9' {
            return Result<int, Error>::Err(Error::make(ErrorKind::Invalid, "not a number"));
        }
        value = value * 10 + (s[i] - '0');
        i += 1;
    }
    if negative { value = -value; }
    return Result<int, Error>::Ok(value);
}

void main() {
    char w[32];
    int total = 0;
    int bad = 0;
    try {
        while true {
            jin >> w;
            Result<int, Error> r = parse_int(@w);
            switch r {
                Result::Ok(v): {
                    total += v;
                    jout << w << " is " << v << "\n";
                }
                Result::Err(e): {
                    bad += 1;
                    jout << w << " is wrong: " << e.message << "\n";
                }
            }
        }
    } catch (e) {
        // the input is over
    }
    jout << "total " << total << ", " << bad << " wrong\n";
}
```

ข้อมูลเข้า: `12 x -3 7y 40`

ผลลัพธ์:

```
12 is 12
x is wrong: not a number
-3 is -3
7y is wrong: not a number
40 is 40
total 49, 2 wrong
```

`Error` มี `kind` (ชนิดของความผิดพลาด) และ `message` (ข้อความ) โปรแกรมตัดสินเองว่าความผิดพลาดหมายความว่าอะไร ในตัวอย่างนี้มันนับแล้วทำต่อ ทางเลือกอีกทางคือหยุดทันทีด้วย `unwrap()` ซึ่งจะ panic เมื่อเป็น `Err` `Option<T>` ใช้หลักการเดียวกันกับค่าที่อาจไม่มี เช่น `Env::get(name)`

**ลองทำ:** ให้โปรแกรมหยุดที่คำผิดคำแรกแทนการนับ

## บทที่ 134. อาร์กิวเมนต์บนบรรทัดคำสั่ง

`Env::args()` คืนคำที่พิมพ์ต่อจากชื่อโปรแกรมเป็นรายการ String ตัวที่ 0 คือชื่อของโปรแกรมเอง โปรแกรมที่ต้องการอาร์กิวเมนต์จะตรวจว่าได้มาเท่าไร และพิมพ์วิธีใช้เมื่อไม่ครบ

```jk
#import <stdlib>
using stdlib;

// usage: sum NUMBER NUMBER
void main() {
    String[] a = Env::args();
    jout << "arguments given: " << (a.len - 1) << "\n";
    if a.len != 3 {
        jout << "usage: sum NUMBER NUMBER\n";
        return;
    }
    int x = a[1].to_int();
    int y = a[2].to_int();
    jout << x << " + " << y << " = " << x + y << "\n";
}
```

ผลลัพธ์:

```
arguments given: 0
usage: sum NUMBER NUMBER
```

รัน `./sum 20 22` ผลลัพธ์คือ `20 + 22 = 42` ถ้าไม่ให้ตัวเลขสองตัว โปรแกรมจะพิมพ์วิธีใช้แทน `to_int()` อ่านตัวเลขจากข้อความ อาร์กิวเมนต์เป็น String เสมอ ตัวเลขในนั้นต้องแปลงก่อนใช้

**ลองทำ:** พิมพ์ทุกอาร์กิวเมนต์ด้วย loop ตั้งแต่ index 1 ถึง `a.len - 1`

## บทที่ 135. อ่านไฟล์ข้อความทีละบรรทัดแล้วนับคำ

`Fs::write_text` เขียนไฟล์ และ `Fs::read_lines` คืนบรรทัดของไฟล์เป็นรายการ String โปรแกรมด้านล่างเขียนไฟล์เล็กๆ ไว้ในโฟลเดอร์ปัจจุบัน อ่านกลับทีละบรรทัด นับคำในแต่ละบรรทัด แล้วลบไฟล์ คำคือกลุ่มของตัวอักษรที่คั่นด้วยช่องว่าง

```jk
#import <stdlib>
using stdlib;

// the number of words in one line: a word starts where a letter follows a space
int count_words(String line) {
    int n = 0;
    bool inside = false;
    for i in 0..line.len {
        if line[i] == ' ' {
            inside = false;
        } else if !inside {
            inside = true;
            n += 1;
        }
    }
    return n;
}

void main() {
    String path = "lines_demo.txt";
    Fs::write_text(path, "the first line\nthe second line has more words\n\nlast\n").unwrap();
    String[] lines = Fs::read_lines(path).unwrap();
    int words = 0;
    for i in 0..lines.len {
        int n = count_words(lines[i]);
        words += n;
        jout << "line " << (i + 1) << ": " << n << " words\n";
    }
    jout << lines.len << " lines, " << words << " words\n";
    Fs::remove(path);
}
```

ผลลัพธ์:

```
line 1: 3 words
line 2: 6 words
line 3: 0 words
line 4: 1 words
4 lines, 10 words
```

บรรทัดว่างตรงกลางมี 0 คำ ไฟล์อยู่ในโฟลเดอร์ปัจจุบันและถูกลบเมื่อจบ โปรแกรมจึงไม่เหลืออะไรไว้ ถ้าชื่อไฟล์มีโฟลเดอร์ให้ใช้ `Path::join`

**ลองทำ:** นับจำนวนตัวอักษรของไฟล์ด้วย (ผลรวม `lines[i].len` บวกหนึ่งต่อการขึ้นบรรทัดแต่ละครั้ง)

## บทที่ 136. เขียนรายงานเป็น CSV

ไฟล์ CSV คือตารางในรูปข้อความ หนึ่งบรรทัดต่อหนึ่งแถว และคั่นฟิลด์ด้วยคอมมา `Csv::join_line` สร้างบรรทัดจากฟิลด์ และใส่เครื่องหมายคำพูดให้ฟิลด์ที่มีคอมมา โปรแกรมนี้ทำรายงานการขายเล็กๆ เขียนเป็น CSV อ่านกลับ แล้วพิมพ์เป็นตารางที่คอลัมน์ตรงกัน

```jk
#import <stdlib>
using stdlib;

struct Sale {
    String item;
    int qty;
    double price;
}

Sale make_sale(String item, int qty, double price) {
    Sale s;
    s.item = item;
    s.qty = qty;
    s.price = price;
    return s;
}

void main() {
    Sale[] sales = arr(3);
    sales.push(make_sale("pen, blue", 3, 1.5));
    sales.push(make_sale("notebook", 2, 2.25));
    sales.push(make_sale("ink", 10, 0.4));

    String path = "sales_demo.csv";
    String text = "item,qty,price,total\n";
    for i in 0..sales.len {
        String[] f = arr(4);
        f.push(sales[i].item);
        f.push(Fmt::fixed((double)sales[i].qty, 0));
        f.push(Fmt::fixed(sales[i].price, 2));
        f.push(Fmt::fixed((double)sales[i].qty * sales[i].price, 2));
        text = text + Csv::join_line(f) + "\n";
    }
    Fs::write_text(path, text).unwrap();

    // read it back and print it as a table
    String[] lines = Fs::read_lines(path).unwrap();
    for i in 0..lines.len {
        String[] f = Csv::split_line(lines[i]);
        jout << Fmt::pad_right(f[0], 12, ' ') << Fmt::pad_left(f[1], 4, ' ') << Fmt::pad_left(f[2], 8, ' ') << Fmt::pad_left(f[3], 8, ' ') << "\n";
    }
    Fs::remove(path);
}
```

ผลลัพธ์:

```
item         qty   price   total
pen, blue      3    1.50    4.50
notebook       2    2.25    4.50
ink           10    0.40    4.00
```

ทุกอย่างในตารางมาจากไฟล์ `Csv::join_line` ใส่เครื่องหมายคำพูดให้ `pen, blue` เพราะมีคอมมา `Csv::split_line` ตัดคำพูดออกตอนอ่าน `Fmt::fixed(x, 2)` เขียนทศนิยมสองตำแหน่งเสมอ ซึ่งคอลัมน์เงินต้องการ

**ลองทำ:** เพิ่มแถวที่ราคา 12.5 แล้วตรวจว่าคอลัมน์ total ยังตรงแนวเดิม

## บทที่ 137. JSON เข้าและออก

โปรแกรมมักรับ JSON และตอบกลับเป็น JSON `Json::parse` อ่านข้อความเป็นเอกสาร เราเดินไปตาม node number รวมค่าที่ต้องการ แล้วเขียนคำตอบเป็น JSON ด้วย `Json::quote` (ข้อความ) และ `Json::num_text` (ตัวเลข) ข้อมูลเข้าคือรายการคำสั่งซื้อ และคำตอบคือ JSON หนึ่งก้อนที่มียอดรวมของรายการที่จ่ายแล้ว

```jk
#import <stdlib>
using stdlib;

void main() {
    String text = "[{\"item\": \"tea\", \"price\": 2.5, \"paid\": true}, {\"item\": \"cake\", \"price\": 3.25, \"paid\": false}, {\"item\": \"jam\", \"price\": 4, \"paid\": true}]";
    JsonDoc doc = Json::parse(text).unwrap();
    int root = doc.root();
    double paid_total = 0.0;
    int unpaid = 0;
    for i in 0..doc.len(root) {
        int order = doc.at(root, i);
        double price = doc.number(doc.get(order, "price"));
        if doc.boolean(doc.get(order, "paid")) {
            paid_total += price;
            jout << "paid: " << Json::quote(doc.text(doc.get(order, "item"))) << "\n";
        } else {
            unpaid += 1;
        }
    }
    String answer = "{\"paid_total\": " + Json::num_text(paid_total) + ", \"unpaid\": " + Json::num_text((double)unpaid) + "}";
    jout << answer << "\n";
    JsonDoc back = Json::parse(answer).unwrap();
    jout << "read back: " << back.number(back.get(back.root(), "paid_total")) << "\n";
}
```

ผลลัพธ์:

```
paid: "tea"
paid: "jam"
{"paid_total": 6.5, "unpaid": 1}
read back: 6.500000
```

`Json::parse` คืน `Result` ดังนั้นข้อความที่ผิดรูปแบบไม่ทำให้โปรแกรมพัง คำตอบเป็นข้อความธรรมดา จึงส่งให้โปรแกรมอื่นหรือบันทึกได้ การอ่านคำตอบกลับด้วย `Json::parse` เป็นวิธีตรวจว่าคำตอบเป็น JSON ที่ถูกต้อง

**ลองทำ:** เพิ่มคำสั่งซื้อที่สี่ที่ `"paid": true` และราคา 1.25 แล้วตรวจว่า `paid_total` กลายเป็น 7.75

## บทที่ 138. เครื่องสถานะเล็กๆ

เครื่องสถานะคือโปรแกรมที่อยู่ในสถานะหนึ่งเสมอ และเหตุการณ์แต่ละอย่างย้ายไปสถานะถัดไป `enum class` ที่มีข้อมูลเป็นวิธีที่ดีในการเขียนสถานะ เช่น `Paying(int cents)` จำว่าจ่ายไปเท่าไรแล้ว ตู้นี้ขนม 25 สตางค์ เหรียญมี 5, 10, 20 ฯลฯ และเหตุการณ์ 0 หมายถึง "ไม่มีเหรียญ"

```jk
#import <stdlib>
using stdlib;

enum class Vend {
    Idle,
    Paying(int cents),
    Change(int back)
}

// the next state from the current one and an event (a coin in cents; 0 = nothing put in)
Vend step(Vend s, int coin) {
    switch s {
        Vend::Idle: {
            if coin > 0 { return Vend::Paying(coin); }
            return Vend::Idle;
        }
        Vend::Paying(c): {
            int sum = c + coin;
            if sum >= 25 { return Vend::Change(sum - 25); }
            return Vend::Paying(sum);
        }
        Vend::Change(b): {
            return Vend::Idle;
        }
    }
    return s;
}

void show(Vend s) {
    switch s {
        Vend::Idle: jout << "idle\n";
        Vend::Paying(c): jout << "paying, " << c << " cents so far\n";
        Vend::Change(b): jout << "give back " << b << " cents\n";
    }
}

void main() {
    Vend s = Vend::Idle;
    int events[5];
    events[0] = 10;
    events[1] = 10;
    events[2] = 10;
    events[3] = 0;
    events[4] = 0;
    for i in 0..5 {
        s = step(s, events[i]);
        show(s);
    }
}
```

ผลลัพธ์:

```
paying, 10 cents so far
paying, 20 cents so far
give back 5 cents
idle
idle
```

แต่ละสถานะคือค่าของ enum จึงคัดลอกและส่งต่อได้ และ `switch` ทำให้มั่นใจว่าจัดการทุกสถานะแล้ว เครื่องนี้ไม่มีตัวแปรลับ สิ่งที่มันรู้ทั้งหมดอยู่ในค่า `s`

**ลองทำ:** เพิ่มสถานะ `Broken` ที่เครื่องไปถึงเมื่อใส่เหรียญ 100 ขึ้นไป แล้วจัดการในฟังก์ชัน `show`

## บทที่ 139. ตัวแยกคำสำหรับนิพจน์คณิตศาสตร์

ก่อนโปรแกรมจะเข้าใจ `(12 + 3) * 4` มันต้องตัดข้อความเป็นโทเค็นก่อน คือตัวเลข ตัวดำเนินการ และวงเล็บ นี่คือตัวแยกโทเค็น มันเดินไปในข้อความด้วย index ข้ามช่องว่าง และสร้างตัวเลขหนึ่งตัวจากกลุ่มของเลขโดด โทเค็นเป็น `enum class` ที่มีข้อมูล เก็บในรายการ

```jk
#import <stdlib>
using stdlib;

enum class Token {
    Num(int value),
    Op(char sign),
    Open,
    Close
}

Token[] tokenize(String s) {
    Token[] out = arr(8);
    int i = 0;
    while i < s.len {
        char c = s[i];
        if c == ' ' {
            i += 1;
        } else if c >= '0' && c <= '9' {
            int v = 0;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                v = v * 10 + (s[i] - '0');
                i += 1;
            }
            out.push(Token::Num(v));
        } else if c == '(' {
            out.push(Token::Open);
            i += 1;
        } else if c == ')' {
            out.push(Token::Close);
            i += 1;
        } else {
            out.push(Token::Op(c));
            i += 1;
        }
    }
    return out;
}

void main() {
    Token[] toks = tokenize("(12 + 3) * 4");
    for i in 0..toks.len {
        switch toks[i] {
            Token::Num(v): jout << "number " << v << "\n";
            Token::Op(c): jout << "operator " << c << "\n";
            Token::Open: jout << "open bracket\n";
            Token::Close: jout << "close bracket\n";
        }
    }
}
```

ผลลัพธ์:

```
open bracket
number 12
operator +
number 3
close bracket
operator *
number 4
```

ตัวแยกโทเค็นไม่ตรวจว่าโทเค็นสมเหตุสมผลหรือไม่ `12 12` จะได้ตัวเลขสองตัวติดกัน ซึ่งเป็นหน้าที่ของตัวแยกโครงสร้าง (ตัวคิดเลขในบทถัดไป) อักขระที่ไม่รู้จักถูกเก็บเป็น `Op` เพื่อให้ตัวแยกโครงสร้างรายงานได้

**ลองทำ:** เพิ่ม `Token::Name(String)` สำหรับตัวอักษร เพื่อให้ `x + 1` ถูกแยกโทเค็นได้ด้วย

## บทที่ 140. เครื่องคิดเลขแบบ recursive descent

ตัวแยกโครงสร้างแบบ recursive descent มีหนึ่งฟังก์ชันต่อหนึ่งระดับของไวยากรณ์: `expr` (บวกและลบ) `term` (คูณและหาร) และ `factor` (ตัวเลขหรือวงเล็บ) แต่ละฟังก์ชันอ่านโทเค็นที่ต้องการแล้วเรียกระดับถัดไป วงเล็บเรียก `expr` อีกครั้ง จึงเป็น recursive ตัวแยกโทเค็นอยู่ในไฟล์ของมันเอง `tokens.j` จากบทที่ 139 โปรแกรมนี้ import มัน

`tokens.j`:

```jk
#import <stdlib>
using stdlib;

// tokens.j -- the tokenizer of the lesson before (no main here)
enum class Token {
    Num(int value),
    Op(char sign),
    Open,
    Close
}

Token[] tokenize(String s) {
    Token[] out = arr(8);
    int i = 0;
    while i < s.len {
        char c = s[i];
        if c == ' ' {
            i += 1;
        } else if c >= '0' && c <= '9' {
            int v = 0;
            while i < s.len && s[i] >= '0' && s[i] <= '9' {
                v = v * 10 + (s[i] - '0');
                i += 1;
            }
            out.push(Token::Num(v));
        } else if c == '(' {
            out.push(Token::Open);
            i += 1;
        } else if c == ')' {
            out.push(Token::Close);
            i += 1;
        } else {
            out.push(Token::Op(c));
            i += 1;
        }
    }
    return out;
}
```

`ec_calculator.jk`:

```jk
#import <stdlib>
using stdlib;

#import "tokens"

Token[] toks;
int pos = 0;

// the token at the position, or an operator that matches nothing when the list is over
char peek_op() {
    if pos >= toks.len { return '#'; }
    switch toks[pos] {
        Token::Op(c): return c;
        _: return '#';
    }
    return '#';
}

int factor() {
    if pos >= toks.len { return 0; }
    Token t = toks[pos];
    pos += 1;
    switch t {
        Token::Num(v): return v;
        Token::Open: {
            int v = expr();
            pos += 1;          // skip the close bracket
            return v;
        }
        _: return 0;
    }
    return 0;
}

int term() {
    int v = factor();
    while peek_op() == '*' || peek_op() == '/' {
        char op = peek_op();
        pos += 1;
        int r = factor();
        if op == '*' { v = v * r; } else { v = v / r; }
    }
    return v;
}

int expr() {
    int v = term();
    while peek_op() == '+' || peek_op() == '-' {
        char op = peek_op();
        pos += 1;
        int r = term();
        if op == '+' { v = v + r; } else { v = v - r; }
    }
    return v;
}

int calc(String s) {
    toks = tokenize(s);
    pos = 0;
    return expr();
}

void main() {
    String[] sums = arr(4);
    sums.push("2 + 3 * (4 - 1)");
    sums.push("(10 - 4) / 2");
    sums.push("7 - 2 - 1");
    sums.push("100 / 7 / 2");
    for i in 0..sums.len {
        jout << sums[i] << " = " << calc(sums[i]) << "\n";
    }
}
```

ผลลัพธ์:

```
2 + 3 * (4 - 1) = 11
(10 - 4) / 2 = 3
7 - 2 - 1 = 4
100 / 7 / 2 = 7
```

`7 - 2 - 1` ได้ 4 ไม่ใช่ 6: loop ใน `expr` รับตัวดำเนินการจากซ้ายไปขวา เหมือนการคำนวณจริง วงเล็บใน `factor` ทำให้ไวยากรณ์เป็น recursive: `expr` เรียก `factor` ซึ่งเรียก `expr` ฟังก์ชันเขียนก่อนหรือหลังกันได้ เพราะฟังก์ชันใช้ก่อนที่จะเขียนได้

**ลองทำ:** เพิ่มเครื่องหมายลบนำหน้า (`-5 + 2`) ใน `factor`

## บทที่ 141. ฮีปจากพื้นฐาน

ฮีปคือต้นไม้ที่เก็บในรายการ ค่าที่น้อยที่สุดจะอยู่ที่ index 0 เสมอ `push` เพิ่มค่าไว้ท้ายแล้วยกขึ้นไปเรื่อยๆ ถ้าน้อยกว่าพ่อของมัน `pop` เอาค่าที่ index 0 ออก แล้วย้ายค่าท้ายสุดขึ้นมาแทนและดันลงไปจนถึงที่ การ push ตัวเลขทั้งหมดแล้ว pop จนหมดจะได้ลำดับที่เรียงแล้ว นี่คือ heap sort

```jk
#import <stdlib>
using stdlib;

struct MinHeap {
    int[] a;

    void push(self, int x) {
        self.a.push(x);
        int i = self.a.len - 1;
        while i > 0 {
            int parent = (i - 1) / 2;
            if self.a[i] >= self.a[parent] { break; }
            int t = self.a[i];
            self.a[i] = self.a[parent];
            self.a[parent] = t;
            i = parent;
        }
    }

    int pop(self) {
        int top = self.a[0];
        int last = self.a.len - 1;
        self.a[0] = self.a[last];
        self.a.pop();
        int i = 0;
        while true {
            int l = 2 * i + 1;
            int r = l + 1;
            int m = i;
            if l < self.a.len && self.a[l] < self.a[m] { m = l; }
            if r < self.a.len && self.a[r] < self.a[m] { m = r; }
            if m == i { break; }
            int t = self.a[i];
            self.a[i] = self.a[m];
            self.a[m] = t;
            i = m;
        }
        return top;
    }
}

void main() {
    MinHeap h;
    h.a = arr(8);
    int input[7];
    input[0] = 5; input[1] = 3; input[2] = 8; input[3] = 1;
    input[4] = 9; input[5] = 2; input[6] = 7;
    for i in 0..7 { h.push(input[i]); }
    jout << "smallest first: ";
    while h.a.len > 0 {
        jout << h.pop() << " ";
    }
    jout << "\n";
}
```

ผลลัพธ์:

```
smallest first: 1 2 3 5 7 8 9 
```

ฮีปคือ struct ที่มีเมธอดสำหรับแต่ละขั้น และรายการที่มันเก็บคือ `int[]` ธรรมดา ไลบรารีมาตรฐานมี `Heap<T>` ด้วย (`std/collections.j`) การเขียนเองทำให้เห็นว่ามันทำงานอย่างไร คิวที่มีลำดับความสำคัญ เช่น งานถัดไปที่จะรัน ก็คือฮีปของคู่ (ลำดับความสำคัญ, งาน)

**ลองทำ:** เปลี่ยนสองเงื่อนไขเปรียบเทียบให้เป็น max-heap

## บทที่ 142. นับความถี่ของคำด้วยตารางแฮช

`Map<K, V>` คือตารางแฮชในไลบรารีมาตรฐาน `put` เก็บค่าไว้ภายใต้คีย์ `get` อ่านค่า `has` ถามว่ามีคีย์นั้นหรือไม่ เพื่อนับคำ Map ให้จำนวนของแต่ละคำ: คำที่ยังไม่มีเริ่มที่ 1 คำที่มีอยู่แล้วเพิ่มอีกหนึ่ง `keys_list()` คืนรายการคำ ซึ่งเรียงก่อนพิมพ์เพื่อให้ลำดับคงที่

```jk
#import <stdlib>
using stdlib;

void main() {
    String[] words = arr(16);
    words.push("the"); words.push("cat"); words.push("and"); words.push("the");
    words.push("dog"); words.push("and"); words.push("the"); words.push("bird");

    Map<String, int> count;
    for i in 0..words.len {
        String w = words[i];
        if count.has(w) {
            count.put(w, count.get(w) + 1);
        } else {
            count.put(w, 1);
        }
    }

    String[] keys = count.keys_list();
    keys.sort();
    for i in 0..keys.len {
        jout << keys[i] << " " << count.get(keys[i]) << "\n";
    }
    jout << "distinct words: " << count.len << "\n";
}
```

ผลลัพธ์:

```
and 2
bird 1
cat 1
dog 1
the 3
distinct words: 5
```

`get` กับคีย์ที่ไม่มีจะโยน `key not found` โปรแกรมจึงถาม `has` ก่อน ตารางขยายตัวเองเมื่อเต็ม การเรียงคีย์ทำให้ผลลัพธ์เหมือนเดิมทุกครั้ง แม้ตารางแฮชเองไม่มีลำดับแน่นอน

**ลองทำ:** นับคำจากประโยคที่คุณพิมพ์: ใส่คำในอาร์เรย์จากไฟล์ เหมือนบทที่ 135

## บทที่ 143. เรียงลำดับด้วยการเปรียบเทียบของเราเอง

`sort_by<T>(list, less)` เรียงลำดับด้วยการเปรียบเทียบที่เราให้: `less(x, y)` เป็นจริงเมื่อ `x` ต้องมาก่อน `y` การเปรียบเทียบเป็นฟังก์ชันที่มีชื่อหรือ lambda (ฟังก์ชันไม่มีชื่อ เขียนตรงจุดที่ใช้) การเรียงนี้เป็น stable: ค่าที่เท่ากันยังคงลำดับเดิม

```jk
#import <stdlib>
using stdlib;

// a named comparison: the bigger number first
bool bigger_first(int x, int y) { return x > y; }

void main() {
    int[] nums = arr(8);
    nums.push(5); nums.push(12); nums.push(7); nums.push(30); nums.push(2);

    sort_by<int>(nums, bigger_first);
    for i in 0..nums.len { jout << nums[i] << " "; }
    jout << "\n";

    // a lambda: order by the last digit (equal digits keep their order)
    sort_by<int>(nums, bool(int x, int y) { return x % 10 < y % 10; });
    for i in 0..nums.len { jout << nums[i] << " "; }
    jout << "\n";

    // a lambda for decimals: by the distance from zero
    double[] ds = arr(3);
    ds.push(-2.5); ds.push(1.0); ds.push(-4.0);
    sort_by<double>(ds, bool(double x, double y) { return x * x < y * y; });
    for i in 0..ds.len { jout << ds[i] << " "; }
    jout << "\n";
}
```

ผลลัพธ์:

```
30 12 7 5 2 
30 12 2 5 7 
1.000000 -2.500000 -4.000000 
```

`sort_by` เรียกการเปรียบเทียบของเราทุกครั้งที่ต้องการเทียบสองค่า ผลที่ได้จึงขึ้นกับกฎที่เราเขียนเท่านั้น ตัวอย่างนี้มีจำนวนเต็มและทศนิยม ลำดับที่เท่ากันยังคงลำดับเดิม (stable)

**ลองทำ:** เรียงตัวเลขตามระยะห่างจาก 10 (ค่าที่ใกล้ 10 ที่สุดมาก่อน) ด้วย lambda

## บทที่ 144. แผนที่ห้องสำหรับเกมผจญภัยแบบข้อความ

เกมผจญภัยแบบข้อความคือกราฟ ห้องแต่ละห้องมีทางออกไปทางเหนือ ตะวันออก ใต้ และตะวันตก และทางออกจะพาไปห้องอื่นหรือไม่ไปไหนเลย ในที่นี้ห้องคือ struct รายการห้องอยู่ในลิสต์ ทางออกคือ index ของห้องอื่น และ `-1` หมายถึงกำแพง รายการการเดินจะพาผู้เล่นไปตามห้อง

```jk
#import <stdlib>
using stdlib;

struct Room {
    String name;
    int north;
    int east;
    int south;
    int west;
}

// the index of the room in direction d (n e s w), or -1 for a wall
int exit_of(Room r, char d) {
    if d == 'n' { return r.north; }
    if d == 'e' { return r.east; }
    if d == 's' { return r.south; }
    if d == 'w' { return r.west; }
    return -1;
}

Room make_room(String name, int north, int east, int south, int west) {
    Room r;
    r.name = name;
    r.north = north;
    r.east = east;
    r.south = south;
    r.west = west;
    return r;
}

void main() {
    Room[] rooms = arr(3);
    Room hall = make_room("Hall", 1, -1, -1, -1);
    Room kitchen = make_room("Kitchen", -1, 2, 0, -1);
    Room garden = make_room("Garden", -1, -1, -1, 1);
    rooms.push(hall);
    rooms.push(kitchen);
    rooms.push(garden);

    String path = "nessw";
    int here = 0;
    jout << "start in " << rooms[here].name << "\n";
    for i in 0..path.len {
        char d = path[i];
        int next = exit_of(rooms[here], d);
        if next < 0 {
            jout << "a wall to the " << d << "\n";
        } else {
            here = next;
            jout << "go " << d << " to " << rooms[here].name << "\n";
        }
    }
    jout << "you are in the " << rooms[here].name << "\n";
}
```

ผลลัพธ์:

```
start in Hall
go n to Kitchen
go e to Garden
a wall to the s
a wall to the s
go w to Kitchen
you are in the Kitchen
```

ห้องคือข้อมูล และการเดินคือ loop ห้องใหม่หรือเส้นทางใหม่ไม่ต้องเขียนโค้ดใหม่ ห้องแต่ละห้องเป็นค่า `rooms[here]` จึงอ่านได้ และ `rooms[here].name` คือชื่อ ในเกมที่ใหญ่กว่า รายการห้องอาจมาจากไฟล์ JSON (บทที่ 137)

**ลองทำ:** เพิ่มห้อง `Cellar` ใต้ห้องครัว แล้วเดินลงไป

## บทที่ 145. ลูปของเกมโดยไม่มีกราฟิก

เกมทำสิ่งเดิมซ้ำๆ: อัปเดตโลก แล้ววาด การอัปเดตต้องไม่ดูนาฬิกา ไม่เช่นนั้นเกมจะเล่นต่างกันในเครื่องแต่ละเครื่อง แต่ให้ไปข้างหน้าทีละขั้นคงที่ `dt` และจำนวนขั้นเท่าเดิมให้ผลเท่าเดิมเสมอ ในตัวอย่างลูกบอลตกลงมาและเด้งหนึ่งครั้งบนพื้น ลูปพิมพ์ความสูงทุก 20 ขั้น

```jk
#import <stdlib>
using stdlib;

void main() {
    double dt = 1.0 / 60.0;     // a fixed step: 60 steps for each second, every time
    double gravity = -9.8;      // metres per second squared
    double height = 5.0;
    double speed = 0.0;
    bool bounced = false;

    for step in 0..300 {
        speed += gravity * dt;
        height += speed * dt;
        if height <= 0.0 {
            height = 0.0;
            if !bounced {
                speed = -speed * 0.6;
                bounced = true;
                jout << "bounce at step " << step << "\n";
            } else {
                speed = 0.0;
            }
        }
        if step % 20 == 0 {
            jout << "step " << step << " height " << Fmt::fixed(height, 2) << "\n";
        }
    }
    jout << "final height " << Fmt::fixed(height, 2) << "\n";
}
```

ผลลัพธ์:

```
step 0 height 5.00
step 20 height 4.37
step 40 height 2.66
bounce at step 60
step 60 height 0.00
step 80 height 1.42
step 100 height 1.75
step 120 height 1.00
step 140 height 0.00
step 160 height 0.00
step 180 height 0.00
step 200 height 0.00
step 220 height 0.00
step 240 height 0.00
step 260 height 0.00
step 280 height 0.00
final height 0.00
```

รันโปรแกรมเดิมสองครั้งจะได้ตัวเลขเดิม ไม่มีอะไรขึ้นกับเวลาที่รัน เกมจริงเพิ่มการรับอินพุตและการวาดเข้าไปในลูป แต่กฎยังเหมือนเดิม สถานะเปลี่ยนเฉพาะในการอัปเดต และ `dt` เท่ากันทุกขั้น

**ลองทำ:** เปลี่ยน `dt` เป็น `1.0 / 30.0` แล้วดูว่าการเด้งย้ายไปขั้นอื่นอย่างไร

## บทที่ 146. บัญชีธนาคารพร้อมเมธอดและการตรวจ

struct ที่มีเมธอดเก็บข้อมูลและกฎในการเปลี่ยนข้อมูลไว้ด้วยกัน บัญชีธนาคารเก็บเงินเป็นสตางค์ซึ่งเป็นจำนวนเต็ม เพราะเงินเป็น `double` จะมีความคลาดเคลื่อนเล็กน้อยจากการปัดเศษ แต่ละเมธอดตรวจค่าที่รับเข้ามาก่อนแก้ไข และคืน `true` หรือ `false` เพื่อให้ผู้เรียกรู้ผล

```jk
#import <stdlib>
using stdlib;

struct Account {
    String owner;
    int cents;

    bool deposit(self, int amount) {
        if amount <= 0 { return false; }
        self.cents += amount;
        return true;
    }

    bool withdraw(self, int amount) {
        if amount <= 0 || amount > self.cents { return false; }
        self.cents -= amount;
        return true;
    }

    void show(self) {
        jout << self.owner << ": " << Fmt::fixed((double)self.cents / 100.0, 2) << "\n";
    }
}

void main() {
    Account acc;
    acc.owner = "Ann";
    acc.cents = 0;
    acc.deposit(5000);
    acc.show();

    if acc.withdraw(1250) {
        jout << "took 12.50\n";
    }
    acc.show();

    if !acc.withdraw(999999) {
        jout << "refused: not enough money\n";
    }
    if !acc.deposit(-5) {
        jout << "refused: the amount must be more than 0\n";
    }
    acc.show();
}
```

ผลลัพธ์:

```
Ann: 50.00
took 12.50
Ann: 37.50
refused: not enough money
refused: the amount must be more than 0
Ann: 37.50
```

`withdraw` ตรวจยอดเงินก่อนถอน ดังนั้นยอดจะไม่ติดลบผ่าน struct นี้ กฎอยู่ในที่เดียว ผู้ที่ใช้ `Account` ได้กฎนี้ไปโดยอัตโนมัติ เมื่อโปรแกรมใหญ่ขึ้น ให้แก้ฟิลด์ผ่านเมธอดเท่านั้น

**ลองทำ:** เพิ่มเมธอด `bool transfer(self, Account^ to, int amount)` ที่ถอนจากบัญชีหนึ่งและฝากเข้าอีกบัญชีหนึ่ง

## บทที่ 147. สแต็กทั่วไป: Stack<T>

สแต็กเอาของที่ใส่เข้าไปทีหลังสุดออกก่อน (เหมือนกองจาน) `Stack<T>` ใช้ได้กับชนิด `T` ใดก็ได้ เขียน `Stack<int>` สำหรับตัวเลข หรือ `Stack<String>` สำหรับข้อความ และคอมไพเลอร์สร้างโค้ดให้แต่ละชนิด `init` ทำงานเมื่อสร้างตัวแปร struct จึงพร้อมใช้ทันที

```jk
#import <stdlib>
using stdlib;

struct Stack<T> {
    T[] items;

    void init(self) {
        self.items = arr(4);
    }

    void push(self, T x) {
        self.items.push(x);
    }

    bool empty(self) {
        return self.items.len == 0;
    }

    // takes the top item off; throws when the stack is empty
    T pop(self) {
        if self.items.len == 0 { throw "the stack is empty"; }
        return self.items.pop();
    }
}

void main() {
    Stack<int> nums;
    for i in 1..4 { nums.push(i * i); }
    while !nums.empty() {
        jout << nums.pop() << " ";
    }
    jout << "\n";

    Stack<int> more;
    more.push(7);
    more.push(8);
    jout << more.pop() << " then " << more.pop() << "\n";
}
```

ผลลัพธ์:

```
9 4 1 
8 then 7
```

struct เดียวใช้ได้กับทุกชนิด `Stack<int>` ทุกที่ที่ใช้เป็นโค้ดชุดเดียวกัน คอมไพเลอร์สร้างให้ครั้งเดียวแล้วนำกลับมาใช้ค่าที่ใส่ทีหลังสุดจะออกก่อน `empty()` ถูกถามก่อน `pop()` เพราะ `pop` โยน error เมื่อสแต็กว่าง

**ลองทำ:** สร้าง `Stack<double>` แล้ว push ทศนิยมสองค่า

## บทที่ 148. defer: ทำความสะอาดเมื่อฟังก์ชันล้มเหลว

ฟังก์ชันที่สร้างไฟล์ชั่วคราวต้องลบมัน แม้เกิดปัญหาครึ่งทาง `defer` วางการลบไว้ข้างๆ การสร้าง และจะทำงานเมื่อฟังก์ชันจบ ไม่ว่าจะด้วย `return` หรือเมื่อ error (`throw`) ออกจากฟังก์ชัน โปรแกรมด้านล่างเขียนไฟล์ แล้วจงใจให้ล้มเหลว ผู้เรียกจะเห็นว่าไฟล์ถูกลบไปแล้ว

```jk
#import <stdlib>
using stdlib;

// writes a file, checks it, and removes the file on every way out
int check_file(String path, String text) {
    Fs::write_text(path, text).unwrap();
    defer Fs::remove(path);
    defer jout << "removed " << path << "\n";
    String[] lines = Fs::read_lines(path).unwrap();
    if lines.len == 0 { throw "the file is empty"; }
    return lines.len;
}

void main() {
    jout << check_file("defer_ok.txt", "a\nb\nc\n") << " lines\n";
    try {
        jout << check_file("defer_bad.txt", "") << " lines\n";
    } catch (e) {
        jout << "caught: " << e << "\n";
    }
    jout << "left behind: " << Fs::exists("defer_ok.txt") << Fs::exists("defer_bad.txt") << "\n";
}
```

ผลลัพธ์:

```
removed defer_ok.txt
3 lines
removed defer_bad.txt
caught: the file is empty
left behind: falsefalse
```

บรรทัด `defer` สองบรรทัดทำงานกลับลำดับ คือข้อความก่อน แล้วลบ ทั้งสองการเรียก ไฟล์หายไปก่อนที่ `main` จะตรวจ ถ้าไม่มี `defer` การลบจะเป็นบรรทัดสุดท้ายของฟังก์ชัน และ `throw` จะข้ามมันไป

**ลองทำ:** ย้ายบรรทัด `defer` ไปไว้หลัง `throw` แล้วดูว่าเมื่อล้มเหลวโปรแกรมจะไม่ลบอะไรเลย

## บทที่ 149. ไฟล์สร้างโปรแกรมของ makej และการอ่านมันเป็นข้อความ

**makej** สร้างโปรเจกต์จากไฟล์สร้าง ซึ่งเป็นไฟล์ข้อความธรรมดาชื่อ `makej` (บทที่ 57) มีส่วนในวงเล็บเหลี่ยม: `[program.NAME]` สำหรับโปรแกรมพร้อมไฟล์ `main` และ `[step.NAME]` สำหรับคำสั่ง shell พร้อม `needs` (สิ่งที่ต้องสร้างก่อน) ไฟล์นี้เป็นเพียงข้อความ โปรแกรมจึงอ่านมันได้เหมือนไฟล์อื่น โปรแกรมด้านล่างเขียนไฟล์สร้างเล็กๆ อ่านทีละบรรทัด แสดงรายการส่วนต่างๆ แล้วลบไฟล์

```jk
#import <stdlib>
using stdlib;

void main() {
    String path = "makej_demo";
    String build = "[makej]\nout = \"_out\"\n\n[program.hello]\nmain = \"src/hello.jk\"\n\n[step.run]\nneeds = \"hello\"\nrun = \"_out/hello\"\n";
    Fs::write_text(path, build).unwrap();

    String[] lines = Fs::read_lines(path).unwrap();
    int targets = 0;
    int settings = 0;
    for i in 0..lines.len {
        String line = lines[i];
        if line.len > 0 && line[0] == '[' {
            targets += 1;
            jout << "target " << line << "\n";
        } else if line.len > 0 && line[0] != '#' {
            settings += 1;
        }
    }
    jout << targets << " sections, " << settings << " settings\n";
    Fs::remove(path);
}
```

ผลลัพธ์:

```
target [makej]
target [program.hello]
target [step.run]
3 sections, 4 settings
```

`makej` จริงอ่านไฟล์นี้เอง บรรทัดที่ขึ้นต้นด้วย `#` เป็นคอมเมนต์ และชื่อส่วนบอกชนิดของเป้าหมาย รัน `makej init` ในโฟลเดอร์เพื่อสร้างไฟล์เริ่มต้น และ `makej -v` เพื่อดูคำสั่งที่มันรัน (บทที่ 57) โปรแกรมข้างบนแสดงแค่ว่าไฟล์นี้เป็นข้อความธรรมดา และมันตรวจสิ่งเดียวกับที่ makej ตรวจได้

```jk-no
[makej]
out = "_out"

[program.hello]
main = "src/hello.jk"
```

**ลองทำ:** พิมพ์เฉพาะบรรทัด `main = ...` พร้อมชื่อส่วนที่อยู่เหนือมัน

## บทที่ 150. อ่านข้อความผิดพลาดของคอมไพเลอร์

เมื่อคอมไพเลอร์พบปัญหา มันพิมพ์ตำแหน่งและเหตุผลในบรรทัดเดียว: `ไฟล์:บรรทัด:คอลัมน์: error: ข้อความ` แล้วพิมพ์บรรทัดของซอร์สพร้อม `^` ชี้จุดนั้น อ่านบรรทัดแรกก่อน ไฟล์ บรรทัด และคอลัมน์บอกว่าต้องดูตรงไหน ข้อความบอกปัญหาเป็นคำพูด โปรแกรมด้านล่างคอมไพล์ได้ รูปแบบข้อความแสดงหลังโปรแกรม จากข้อผิดพลาดจริง

```jk
#import <stdlib>
using stdlib;

// this program compiles; the message format is shown after it
int average(int[] values) {
    int total = 0;
    for i in 0..values.len { total += values[i]; }
    if values.len == 0 { return 0; }
    return total / values.len;
}

void main() {
    int[] marks = arr(3);
    marks.push(70);
    marks.push(85);
    marks.push(91);
    jout << "average " << average(marks) << "\n";
}
```

ผลลัพธ์:

```
average 82
```

สมมติว่าขาด `}` ท้ายบรรทัด `for` ในฟังก์ชัน `average` นี่คือผลลัพธ์จริงของคอมไพเลอร์สำหรับการเปลี่ยนเพียงจุดเดียวนี้:

```jk-no
ec_read_errors.jk:12:6: error: a variable cannot be void
 12 | void main() {
    |      ^
  help: void is only for functions that give no value; use int, double, ... for a variable
ec_read_errors.jk:19:1: error: the file ends inside a block: the '{' on line 5 is never closed
  help: a '}' is missing; check the braces that follow that line
```

อ่านตามลำดับนี้: (1) ไฟล์และตำแหน่ง `12:6` คือบรรทัด 12 คอลัมน์ 6 (2) ข้อความ บอกว่าอะไรผิด (3) บรรทัดของซอร์สที่มี `^` และบรรทัด `help` ซึ่งมักบอกวิธีแก้ ข้อความแรกชี้ไปที่ `main` แต่สาเหตุคือ `{` ของ `average` ที่บรรทัด 5 ซึ่งไม่ถูกปิด ดังนั้นตำแหน่งที่คอมไพเลอร์สังเกตเห็นปัญหาไม่จำเป็นต้องเป็นตำแหน่งของความผิดพลาด ให้อ่านบรรทัด `help` และข้อความสุดท้ายด้วย แก้ทีละจุด คอมไพล์ใหม่ ข้อความที่เหลืออาจหายไปเอง

**ลองทำ:** ลบ `}` ท้ายบรรทัด `for` ในฟังก์ชัน `average` คอมไพล์ แล้วดูว่าข้อความระบุบรรทัดของฟังก์ชันหรือไม่

## บทที่ 151. ชื่ออยู่ได้ที่ไหน: ขอบเขตตัวแปร

ตัวแปรมีอยู่ตั้งแต่บรรทัดที่สร้างมันจนถึงปีกกาปิดของบล็อกที่สร้าง ตัวแปรที่สร้างนอกฟังก์ชันทั้งหมด (global) มองเห็นได้ทุกที่ ในลูปจะได้ตัวแปรใหม่ทุกรอบ

```jk
#import <stdlib>
using stdlib;

int total = 100;                 // a global: visible everywhere

int twice(int x) {
    int result = x * 2;          // a local: only inside twice
    return result;
}

void main() {
    int n = 5;
    if n > 3 {
        int inner = n + 1;       // lives only inside these braces
        jout << "inner = " << inner << "\n";
    }
    for i in 0..3 {
        int sq = i * i;          // a new sq for every turn
        jout << "sq = " << sq << "\n";
    }
    jout << twice(n) << " " << total << "\n";
}

```

ผลลัพธ์:

```
inner = 6
sq = 0
sq = 1
sq = 4
10 100
```

ถ้าใช้ชื่อนอกบล็อกของมัน คอมไพเลอร์จะบอกว่าไม่รู้จักชื่อนั้น ควรใช้ตัวแปรโลคัลเป็นหลัก เพราะ global ถูกแก้จากที่ไหนก็ได้ จึงตามยากว่าใครแก้

**ลอง:** พิมพ์ `inner` หลังบล็อก `if` แล้วอ่านข้อความผิดพลาด

## บทที่ 152. ตารางแถวและคอลัมน์

ตารางที่มีแถวและคอลัมน์เก็บไว้ในอาร์เรย์เดียวได้: ช่อง (แถว, คอลัมน์) อยู่ที่ `แถว * ความกว้าง + คอลัมน์` วิธีนี้เก็บตัวเลขทั้งหมดติดกันในหน่วยความจำ ซึ่งซีพียูชอบ

```jk
#import <stdlib>
using stdlib;

// a 3 x 3 table kept in one array: the cell (row, col) is at row * 3 + col
void main() {
    int[] t = arr(9);
    for r in 0..3 {
        for c in 0..3 { t.push((r + 1) * (c + 1)); }
    }
    for r in 0..3 {
        for c in 0..3 { jout << t[r * 3 + c] << " "; }
        jout << "\n";
    }
    int diag = 0;
    for k in 0..3 { diag += t[k * 3 + k]; }
    jout << "diagonal sum = " << diag << "\n";
}

```

ผลลัพธ์:

```
1 2 3 
2 4 6 
3 6 9 
diagonal sum = 14
```

นี่คือรูปแบบเดียวกับบทผลคูณเมทริกซ์ อ่านตารางทีละแถว (ลูปในวิ่งตามคอลัมน์) จะเร็ว อ่านทีละคอลัมน์จะช้ากว่า

**ลอง:** ทำเป็น 4 x 4 แล้วพิมพ์ผลรวมของแถวที่สอง

## บทที่ 153. ค้นหาให้เร็ว: binary search

เมื่ออาร์เรย์เรียงแล้ว ไม่ต้องดูทุกตัว ดูตัวกลาง ถ้าค่าที่หาน้อยกว่า คำตอบอยู่ครึ่งซ้าย ไม่เช่นนั้นอยู่ครึ่งขวา ทุกขั้นทิ้งไปครึ่งหนึ่ง จึงใช้แค่ราว 20 ขั้นสำหรับ 1,000,000 ตัว

```jk
#import <stdlib>
using stdlib;

// binary search in a sorted array: each step throws half of the rest away
int find(int[] a, int x) {
    int lo = 0;
    int hi = a.len - 1;
    while lo <= hi {
        int mid = (lo + hi) / 2;
        if a[mid] == x { return mid; }
        if a[mid] < x { lo = mid + 1; } else { hi = mid - 1; }
    }
    return 0 - 1;
}

void main() {
    int[] a = arr(8);
    for i in 0..8 { a.push(i * 3); }
    jout << find(a, 9) << " " << find(a, 10) << " " << find(a, 21) << "\n";
}

```

ผลลัพธ์:

```
3 -1 7
```

ฟังก์ชันคืนตำแหน่ง หรือ -1 ถ้าไม่มีตัวเลขนั้น ใช้ได้กับอาร์เรย์ที่เรียงแล้วเท่านั้น ถ้าไม่เรียง คำตอบจะผิด

**ลอง:** นับว่าลูปทำกี่ขั้นสำหรับ 21 และสำหรับ 10

## บทที่ 154. แก้บั๊กด้วยการดูค่า

ดีบักเกอร์ที่ง่ายที่สุดคือการพิมพ์: พิมพ์ค่าที่สำคัญแล้วเทียบกับที่คาดไว้ เริ่มจากอินพุตเล็กๆ ที่คำนวณคำตอบด้วยมือได้

```jk
#import <stdlib>
using stdlib;

// debugging by looking: print the values that matter, then compare with what you expected
int collatz_steps(int n) {
    int steps = 0;
    while n != 1 {
        if n % 2 == 0 { n = n / 2; } else { n = 3 * n + 1; }
        steps += 1;
    }
    return steps;
}

void main() {
    for n in 1..8 {
        jout << "n = " << n << "  steps = " << collatz_steps(n) << "\n";
    }
}

```

ผลลัพธ์:

```
n = 1  steps = 0
n = 2  steps = 1
n = 3  steps = 7
n = 4  steps = 2
n = 5  steps = 5
n = 6  steps = 8
n = 7  steps = 16
```

ตรงนี้ขั้นตอนของ 3 คือ 7 ขั้น (3, 10, 5, 16, 8, 4, 2, 1) ถ้าผลลัพธ์ไม่ตรงกับที่นับด้วยมือ บั๊กอยู่ในลูป ถ้าตรง ให้ดูที่ผู้เรียก คอมไพล์ด้วย `-d` เพื่อหยุดเมื่อใช้ดัชนีอาร์เรย์ผิด

**ลอง:** พิมพ์ `n` ในลูปของ `collatz_steps` สำหรับค่าเริ่มต้น 6

## บทที่ 155. นับขั้นตอน: Big-O

เวลาที่โปรแกรมใช้ขึ้นกับจำนวนขั้นตอน และจำนวนขั้นตอนขึ้นกับขนาดข้อมูล เราไม่จับเวลา แต่นับขั้นตอน โปรแกรมนี้นับขั้นตอนของการค้นหาสองแบบ: ดูทุกตัว (linear) หรือแบ่งช่วงครึ่งหนึ่งทุกรอบ (binary สำหรับข้อมูลที่เรียงแล้ว)

```jk
#import <stdlib>
using stdlib;

// Big-O by counting: how many steps does a search need as the data grows?
int linear_steps(int n) { return n; }                 // look at every item in the worst case

int binary_steps(int n) {
    int lo = 0;
    int hi = n - 1;
    int steps = 0;
    while lo <= hi {                                   // search for a value that is not there: the worst case
        int mid = (lo + hi) / 2;
        steps += 1;
        hi = mid - 1;
    }
    return steps;
}

void main() {
    jout << "n          linear    binary\n";
    int n = 16;
    for t in 0..5 {
        jout << pad(str(n), 10) << " " << pad(str(linear_steps(n)), 9) << " " << binary_steps(n) << "\n";
        n = n * 16;
    }
}

```

ผลลัพธ์:

```
n          linear    binary
16         16        4
256        256       8
4096       4096      12
65536      65536     16
1048576    1048576   20
```

เมื่อข้อมูลโตขึ้น 16 เท่า linear ใช้ขั้นตอนมากขึ้น 16 เท่า (**O(n)**) แต่ binary เพิ่มแค่ 4 ขั้น (**O(log n)**) ข้อมูลล้านตัว: 1,048,576 ขั้นเทียบกับ 20 Big-O เก็บเฉพาะรูปร่างของการเติบโต: O(1), O(log n), O(n), O(n log n), O(n^2), O(2^n) คือชื่อที่จะเจอ

**ลอง:** เปลี่ยนตัวคูณ 16 เป็น 2 แล้วดูคอลัมน์ binary เพิ่มทีละ 1

## บทที่ 156. สแตก: เข้าทีหลัง ออกก่อน

สแตกคืนของในลำดับตรงข้าม: ตัวที่เข้าทีหลังออกก่อน (LIFO) การเรียกฟังก์ชันทำงานแบบนี้ ปุ่ม undo ก็เช่นกัน และเป็นเครื่องมือตรวจวงเล็บ

```jk
#import <stdlib>
using stdlib;

// a stack in an array: the last item in is the first one out (LIFO)
struct Stack { int[] items; }

void push(Stack s, int x) { s.items.push(x); }
int pop(Stack s) {
    int x = s.items[s.items.len - 1];
    s.items.pop();
    return x;
}

// are the brackets of a text balanced? ( [ { and the matching closers
bool balanced(String t) {
    Stack s;
    s.items = arr(8);
    for i in 0..t.len {
        char c = t[i];
        if c == '(' || c == '[' || c == '{' { push(s, (int)c); }
        else if c == ')' || c == ']' || c == '}' {
            if s.items.len == 0 { return false; }
            int o = pop(s);
            if c == ')' && o != (int)'(' { return false; }
            if c == ']' && o != (int)'[' { return false; }
            if c == '}' && o != (int)'{' { return false; }
        }
    }
    return s.items.len == 0;
}

void main() {
    jout << balanced("(a[b]c)") << " " << balanced("(a[b)]") << " " << balanced("((") << "\n";
}

```

ผลลัพธ์:

```
true false false
```

push วงเล็บเปิดทุกตัว เจอวงเล็บปิดให้ pop มาตรวจว่าคู่กัน สุดท้ายสแตกต้องว่าง ทุกขั้น O(1) ทั้งการตรวจ O(n)

**ลอง:** เพิ่มข้อความ `"([)]"` แล้วอธิบายว่าทำไมไม่สมดุล

## บทที่ 157. คิวแบบ ring buffer

คิวคืนของตามลำดับที่เข้ามา: เข้าก่อนออกก่อน (FIFO) ring buffer เก็บในอาร์เรย์ขนาดคงที่: จุดเริ่มเลื่อนไปข้างหน้าแล้ววนกลับที่ปลายอาร์เรย์ จึงไม่ต้องย้ายข้อมูลเลย

```jk
#import <stdlib>
using stdlib;

// a queue in a ring buffer: first in, first out (FIFO); head and tail wrap around at the end of the array
int[] buf;
int head = 0;
int count = 0;
int cap = 4;

bool enqueue(int x) {
    if count == cap { return false; }
    buf[(head + count) % cap] = x;
    count += 1;
    return true;
}

int dequeue() {
    int x = buf[head];
    head = (head + 1) % cap;
    count -= 1;
    return x;
}

void main() {
    buf = arr(cap);
    for i in 0..cap { buf.push(0); }
    for i in 1..7 { jout << enqueue(i * 10) << " "; }       // the 5th and 6th do not fit
    jout << "\n";
    jout << dequeue() << " " << dequeue() << "\n";
    jout << enqueue(99) << " " << enqueue(98) << "\n";       // the freed places are used again
    while count > 0 { jout << dequeue() << " "; }
    jout << "\n";
}

```

ผลลัพธ์:

```
true true true true false false 
10 20
true true
30 40 99 98 
```

ตำแหน่งช่องว่างถัดไปคือ `(head + count) % cap` เครื่องหมาย `%` ทำให้ตำแหน่งวนกลับ คีย์บอร์ด การ์ดเครือข่าย และเสียง ใช้ ring buffer ทั้งหมด คิวเต็มจะตอบ `false` แทนที่จะขยาย

**ลอง:** ตั้ง `cap` เป็น 8 แล้วเติมให้เต็ม

## บทที่ 158. ต้นไม้ค้นหา

binary search tree เก็บคีย์ที่น้อยกว่าไว้ทางซ้าย และที่มากกว่าไว้ทางขวาของโหนด ค้นและเพิ่มลงไปทีละกิ่ง: ราว log n ขั้นเมื่อต้นไม้สมดุล

```jk
#import <stdlib>
using stdlib;

// a binary search tree kept in arrays: node i has a key, a left child and a right child (-1: none)
int[] key;
int[] left;
int[] right;

int insert(int root, int k) {
    key.push(k); left.push(0 - 1); right.push(0 - 1);
    int id = key.len - 1;
    if root < 0 { return id; }
    int cur = root;
    while true {
        if k < key[cur] {
            if left[cur] < 0 { left[cur] = id; break; }
            cur = left[cur];
        } else {
            if right[cur] < 0 { right[cur] = id; break; }
            cur = right[cur];
        }
    }
    return root;
}

void inorder(int n) {                                    // left, node, right: the keys come out sorted
    if n < 0 { return; }
    inorder(left[n]);
    jout << key[n] << " ";
    inorder(right[n]);
}

int height(int n) {
    if n < 0 { return 0; }
    int a = height(left[n]);
    int b = height(right[n]);
    if a > b { return a + 1; }
    return b + 1;
}

void main() {
    key = arr(8); left = arr(8); right = arr(8);
    int root = 0 - 1;
    int[] data = arr(8);
    data.push(50); data.push(30); data.push(70); data.push(20); data.push(40); data.push(60); data.push(80);
    for i in 0..data.len { root = insert(root, data[i]); }
    inorder(root);
    jout << "\nheight " << height(root) << "\n";
}

```

ผลลัพธ์:

```
20 30 40 50 60 70 80 
height 3
```

ที่นี่โหนดถูกเก็บในอาร์เรย์สามตัว (`key`, `left`, `right`) และลูกคือดัชนี: ไม่มี pointer และข้อมูลอยู่ติดกันในหน่วยความจำ การอ่านต้นไม้แบบ ซ้าย โหนด ขวา ให้คีย์เรียงลำดับ นั่นคือการเรียง ความสูง 3 คือจำนวนขั้นไปคีย์ที่ลึกที่สุด ต้นไม้ที่สร้างจากข้อมูลที่เรียงแล้วจะกลายเป็นเส้นตรงสูง n

**ลอง:** ใส่คีย์ตามลำดับ 10, 20, 30, 40 แล้วพิมพ์ความสูง

## บทที่ 159. กราฟและการค้นหาแบบกว้าง

กราฟคือโหนดที่เชื่อมด้วยเส้น: ถนน เพื่อน ลิงก์ การพึ่งพา การค้นหาแบบกว้าง (BFS) เยี่ยมโหนดตามลำดับระยะจากจุดเริ่ม โดยใช้คิว ดังนั้นครั้งแรกที่ถึงโหนดคือเส้นทางที่สั้นที่สุด

```jk
#import <stdlib>
using stdlib;

// breadth-first search: the fewest steps from a start node to every other node of a graph
// the graph is kept as lists: the neighbours of node v are nb[start[v] .. start[v+1])
void main() {
    int n = 6;
    int[] start = arr(8);
    int[] nb = arr(16);
    // edges: 0-1 0-2 1-3 2-3 3-4 (node 5 is alone)
    int[] ea = arr(8); int[] eb = arr(8);
    ea.push(0); eb.push(1); ea.push(0); eb.push(2); ea.push(1); eb.push(3); ea.push(2); eb.push(3); ea.push(3); eb.push(4);
    for v in 0..n {
        start.push(nb.len);
        for e in 0..ea.len {
            if ea[e] == v { nb.push(eb[e]); }
            if eb[e] == v { nb.push(ea[e]); }
        }
    }
    start.push(nb.len);
    int[] dist = arr(8);
    for v in 0..n { dist.push(0 - 1); }
    int[] queue = arr(8);
    queue.push(0);
    dist[0] = 0;
    int qh = 0;
    while qh < queue.len {
        int v = queue[qh];
        qh += 1;
        for k in start[v]..start[v + 1] {
            int w = nb[k];
            if dist[w] < 0 { dist[w] = dist[v] + 1; queue.push(w); }
        }
    }
    for v in 0..n { jout << "node " << v << ": " << dist[v] << "\n"; }
}

```

ผลลัพธ์:

```
node 0: 0
node 1: 1
node 2: 1
node 3: 2
node 4: 3
node 5: -1
```

กราฟเก็บเป็นลิสต์ (`start[v]` ถึง `start[v+1]` บอกว่าเพื่อนบ้านของ `v` อยู่ที่ใดใน `nb`) รูปแบบที่โปรแกรมกราฟใหญ่ใช้เพราะกะทัดรัด โหนด 5 ไม่มีเส้น ระยะจึงเป็น -1 แปลว่า 'ถึงไม่ได้' งานเป็น O(โหนด + เส้น)

**ลอง:** เพิ่มเส้น 4-5 แล้วรันอีกครั้ง

## บทที่ 160. โปรแกรมมิงแบบไดนามิก

บางปัญหาประกอบด้วยปัญหาย่อยแบบเดียวกันที่ซ้ำกัน dynamic programming (DP) แก้แต่ละกรณีเล็กครั้งเดียว จดคำตอบไว้ในตาราง แล้วสร้างคำตอบใหญ่จากตาราง

```jk
#import <stdlib>
using stdlib;

// dynamic programming: the longest common subsequence of two texts; table[i][j] uses the answers for shorter texts
int lcs(String a, String b) {
    int w = b.len + 1;
    int[] t = arr((a.len + 1) * w);
    for i in 0..(a.len + 1) * w { t.push(0); }
    for i in 1..a.len + 1 {
        for j in 1..b.len + 1 {
            if a[i - 1] == b[j - 1] { t[i * w + j] = t[(i - 1) * w + (j - 1)] + 1; }
            else {
                int up = t[(i - 1) * w + j];
                int lf = t[i * w + (j - 1)];
                if up > lf { t[i * w + j] = up; } else { t[i * w + j] = lf; }
            }
        }
    }
    return t[a.len * w + b.len];
}

// the fewest coins for an amount (coins 1, 5, 12): the answer for 15 is 3 coins of 5, not 12 + 1 + 1 + 1
int coins(int amount) {
    int[] best = arr(amount + 1);
    best.push(0);
    for x in 1..amount + 1 {
        int m = 1000000;
        if x >= 1 && best[x - 1] + 1 < m { m = best[x - 1] + 1; }
        if x >= 5 && best[x - 5] + 1 < m { m = best[x - 5] + 1; }
        if x >= 12 && best[x - 12] + 1 < m { m = best[x - 12] + 1; }
        best.push(m);
    }
    return best[amount];
}

void main() {
    jout << lcs("AGGTAB", "GXTXAYB") << " " << lcs("abc", "xyz") << "\n";
    jout << coins(15) << " " << coins(11) << " " << coins(24) << "\n";
}

```

ผลลัพธ์:

```
4 0
3 3 2
```

สองตัวอย่างคลาสสิก: ลำดับย่อยร่วมที่ยาวที่สุดของสองข้อความ (ตาราง `len(a) x len(b)` ช่อง) และจำนวนเหรียญน้อยที่สุดสำหรับยอดเงิน ปัญหาเหรียญแสดงว่าทำไมการเลือกแบบโลภพลาด: ที่ 15 ถ้าหยิบเหรียญใหญ่สุดก่อน (12 + 1 + 1 + 1) ใช้ 4 เหรียญ แต่ตารางหาได้ 3 (5 + 5 + 5) ตารางทำให้งานเป็น O(n x m) แทนที่จะเป็นเอกซ์โปเนนเชียลแบบเรียกซ้ำตรงๆ

**ลอง:** เพิ่มเหรียญ 7 แล้วดูคำตอบของ 14

## บทที่ 161. ตารางแฮชแบบเขียนเอง

ตารางแฮชหาค่าจากคีย์ได้ในราวหนึ่งขั้น: ฟังก์ชันแปลงคีย์เป็นตำแหน่งในอาร์เรย์ สองคีย์อาจต้องการตำแหน่งเดียวกัน (ชนกัน) open addressing จะลองตำแหน่งถัดไป

```jk
#import <stdlib>
using stdlib;

// a hash table from scratch: open addressing (if the place is taken, try the next one)
int cap = 16;
int[] keys;
int[] vals;
bool[] used;
int probes = 0;

int h(int k) { return (k * 31 + 7) % cap; }

void put(int k, int v) {
    int i = h(k);
    while used[i] && keys[i] != k { i = (i + 1) % cap; probes += 1; }
    used[i] = true; keys[i] = k; vals[i] = v;
}

int get(int k) {
    int i = h(k);
    while used[i] {
        if keys[i] == k { return vals[i]; }
        i = (i + 1) % cap;
    }
    return 0 - 1;
}

void main() {
    keys = arr(cap); vals = arr(cap); used = arr(cap);
    for i in 0..cap { keys.push(0); vals.push(0); used.push(false); }
    for i in 0..10 { put(i * 16 + 3, i * 100); }          // these keys all want the same place: collisions
    jout << get(3) << " " << get(35) << " " << get(147) << " " << get(4) << "\n";
    jout << "extra probes: " << probes << "\n";
}

```

ผลลัพธ์:

```
0 200 900 -1
extra probes: 45
```

คีย์ 10 ตัวที่ห่างกัน 16 เท่ากัน ตกที่ตำแหน่งเดียวกัน แต่ละตัวจึงต้องเดินผ่านตัวก่อนหน้า: 45 ครั้งเพิ่ม ฟังก์ชันแฮชที่ดีกระจายคีย์ ตารางที่เกือบเต็มจะช้า ตารางจริงจึงขยายเมื่อเต็มราว 70 % ไลบรารี `<collections>` มีให้พร้อมใช้ (บทที่ 142)

**ลอง:** เปลี่ยน `cap` เป็น 17 (จำนวนเฉพาะ) แล้วเทียบจำนวนครั้ง

## บทที่ 162. เรียงสองแบบ นับการเปรียบเทียบ

การเรียงคือที่มาตรฐานที่จะเห็น Big-O ทำงาน insertion sort ย้ายแต่ละตัวกลับเข้าที่ ใช้ราว n x n / 4 การเปรียบเทียบ merge sort แบ่ง เรียงครึ่งละส่วน แล้วผสาน ใช้ราว n x log2(n)

```jk
#import <stdlib>
using stdlib;

// two sorts, the same data: count the comparisons (insertion sort ~ n*n/4, merge sort ~ n*log2(n))
int cmp_count = 0;

void insertion(int[] a) {
    for i in 1..a.len {
        int x = a[i];
        int j = i - 1;
        while j >= 0 {
            cmp_count += 1;
            if a[j] <= x { break; }
            a[j + 1] = a[j];
            j -= 1;
        }
        a[j + 1] = x;
    }
}

void merge_sort(int[] a, int[] tmp, int lo, int hi) {   // sorts a[lo .. hi)
    if hi - lo < 2 { return; }
    int mid = (lo + hi) / 2;
    merge_sort(a, tmp, lo, mid);
    merge_sort(a, tmp, mid, hi);
    int i = lo;
    int j = mid;
    int k = lo;
    while i < mid && j < hi {
        cmp_count += 1;
        if a[i] <= a[j] { tmp[k] = a[i]; i += 1; } else { tmp[k] = a[j]; j += 1; }
        k += 1;
    }
    while i < mid { tmp[k] = a[i]; i += 1; k += 1; }
    while j < hi { tmp[k] = a[j]; j += 1; k += 1; }
    for q in lo..hi { a[q] = tmp[q]; }
}

int[] make(int n) {
    int[] a = arr(n);
    int seed = 12345;
    for i in 0..n { seed = (seed * 1103515245 + 12345) % 2147483648; a.push(seed % 1000); }
    return a;
}

void main() {
    int n = 1000;
    int[] a = make(n);
    int[] b = make(n);
    int[] tmp = arr(n);
    tmp.resize(n);
    insertion(a);
    int c1 = cmp_count;
    cmp_count = 0;
    merge_sort(b, tmp, 0, n);
    int c2 = cmp_count;
    jout << "insertion sort: " << c1 << " comparisons\n";
    jout << "merge sort:     " << c2 << " comparisons\n";
    bool same = true;
    for i in 0..n { if a[i] != b[i] { same = false; } }
    jout << "same result: " << same << "\n";
}

```

ผลลัพธ์:

```
insertion sort: 242690 comparisons
merge sort:     8670 comparisons
same result: true
```

สำหรับตัวเลข 1000 ตัว: 242,690 ครั้ง เทียบกับ 8,670 ครั้ง ได้ผลเรียงเหมือนกัน ที่ 1,000,000 ตัว ตัวแรกต้องราว 250 พันล้านครั้ง ตัวที่สองราว 20 ล้านครั้ง สำหรับข้อมูลน้อยๆ insertion sort เร็วกว่า (ไม่มีการเรียกซ้ำ ไม่มีอาร์เรย์ที่สอง) ไลบรารีจริงจึงใช้ทั้งสองแบบ

**ลอง:** ตั้ง `n` เป็น 100 และ 10000 แล้วดูว่าสองตัวเลขโตอย่างไร

## บทที่ 163. หน่วยความจำและแคช: ทำไมลำดับลูปจึงสำคัญ

ซีพียูเร็วกว่าหน่วยความจำมาก เพื่อซ่อนการรอ มันอ่านหน่วยความจำเป็นก้อนละ 64 ไบต์ (cache line) และเก็บก้อนล่าสุดไว้ใกล้ๆ โปรแกรมที่ใช้ตัวเลขทั้งก้อนก่อนไปก้อนถัดไปเร็วกว่าโปรแกรมที่กระโดดหลายเท่า

```jk
#import <stdlib>
using stdlib;

// the same sum of a table, read by rows and by columns: one answer, but the CPU reads memory in blocks (cache lines),
// so walking along a row uses every number of a block while walking down a column uses one number of each block
void main() {
    int n = 512;
    float[] t = arr(n * n);
    for i in 0..n * n { t.push((float)(i % 10)); }
    float by_rows = 0.0;
    for r in 0..n { for c in 0..n { by_rows += t[r * n + c]; } }
    float by_cols = 0.0;
    for c in 0..n { for r in 0..n { by_cols += t[r * n + c]; } }
    jout << by_rows << " " << by_cols << " " << (by_rows == by_cols) << "\n";
    jout << "bytes in a row: " << n * 4 << ", bytes between two numbers of a column: " << n * 4 << "\n";
}

```

ผลลัพธ์:

```
1179636.000000 1179636.000000 true
bytes in a row: 2048, bytes between two numbers of a column: 2048
```

ผลรวมสองแบบให้คำตอบเท่ากัน (และเท่ากันทุกบิตตรงนี้เพราะทุกตัวเลขเป็นจำนวนเต็มเล็ก) แบบแรกเดินตามแถว: 16 float ต่อก้อน ใช้ครบทุกตัว แบบที่สองลงตามคอลัมน์: ห่างกัน 2048 ไบต์ แต่ละก้อนให้ได้ตัวเลขเดียวแล้วถูกทิ้ง ที่วัดบนมือถือเครื่องนี้สำหรับผลคูณเมทริกซ์ 384 x 384 float: ลำดับลูปที่ลูปในเดินตามแถว (`ikj`, `kij`) ใช้ราว 50 มิลลิวินาที ลำดับอื่น 230 ถึง 270 มิลลิวินาที สำหรับ `ijk` ธรรมดา และ C ก็ไม่ต่างกัน: บทเรียนนี้เกี่ยวกับหน่วยความจำ ไม่ใช่ภาษา

**ลอง:** ตั้ง `n` เป็น 1024 แล้วจับเวลาสองลูปด้วย `Time::mono_ns()` จากบทที่ 92

## ต่อไป

* [LANGUAGE.md](LANGUAGE.md) — ทุกความสามารถพร้อมตัวอย่าง (function pointer, ชนิด unsigned, `sizeof` ฯลฯ)
* [USAGE.md](USAGE.md) — ตัวเลือกของคอมไพเลอร์ (`-d`, `-st`, `-I`, `--emit-asm`)
* โฟลเดอร์ `examples/` ใน repository — โปรแกรมตัวอย่างเพิ่มเติม
