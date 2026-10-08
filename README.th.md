# J2K และ Jcmp

**J2K** คือภาษาโปรแกรมระดับระบบที่ออกแบบเองตั้งแต่ศูนย์ ใกล้ฮาร์ดแวร์
**Jcmp** คือคอมไพเลอร์ของมัน อ่านซอร์ส `.jk` / `.j` แล้วเขียนไฟล์รันบน Linux ARM64 ตรงๆ
(มี assembler และตัวเขียน ELF ในตัว ไม่ใช้ LLVM, GCC, `as` หรือ `ld`)

คอมไพเลอร์เขียนด้วย J2K เอง และคอมไพล์ตัวเองได้ (self-hosting) พัฒนาทั้งหมดบนมือถือ (ARM64, Termux)

## ติดตั้ง
ต้องใช้เครื่อง Linux **ARM64** (มือถือที่มี Termux ได้) และ `curl` หรือ `wget` (Termux: `pkg install curl wget`)
คอมไพเลอร์เป็นไฟล์เดียว ปล่อยเป็น [release](https://github.com/J2k-studio/Jcmp/releases)

**วิธีที่ 1 — `install.sh` (แนะนำ)** โหลดรุ่นล่าสุด ตรวจ SHA-256 แล้ววาง `jcmp` ในโฟลเดอร์:

```bash
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh

# เลือกโฟลเดอร์เอง เช่น bin ที่อยู่ข้างโปรเจกต์ (../bin)
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh -s -- --dir ../bin
wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh -s -- --dir ../bin
```
ตัวเลือก: `--dir โฟลเดอร์`, `--version 0.3.3` (เลือกรุ่น), `--with-assembler` (ติดตั้ง `j2k_asm` ด้วย)
โฟลเดอร์เริ่มต้นคือ `$PREFIX/bin` (Termux) หรือ `~/.local/bin` รันซ้ำเพื่ออัปเดต ลบไฟล์เพื่อถอนการติดตั้ง

**วิธีที่ 2 — คำสั่งเดียวด้วย `tar` (ไฟล์ที่ได้รันได้ทันที):** ไฟล์ธรรมดาที่โหลดจาก release จะ **ไม่มีสิทธิ์รัน** (GitHub ไม่เก็บสิทธิ์ของไฟล์)
แต่ `jcmp.tar.gz` เก็บสิทธิ์ไว้ ข้างในมีแค่โปรแกรม `jcmp`:

```bash
mkdir -p ../bin
curl -fL https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp.tar.gz | tar xz -C ../bin
wget -qO- https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp.tar.gz | tar xz -C ../bin
../bin/jcmp -version
```

**วิธีที่ 3 — ทำเองทีละขั้นด้วยไฟล์ธรรมดาลง `../bin` (ต้อง `chmod +x`):**

```bash
mkdir -p ../bin && cd ../bin
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp     # หรือ wget URL เดียวกัน
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS      # ต้องขึ้น: jcmp: OK
chmod +x jcmp && rm SHA256SUMS
```

**ใช้งาน:** ใส่โฟลเดอร์ใน `PATH` แล้วลอง

```bash
export PATH="$PWD:$PATH"                      # รันในโฟลเดอร์ที่ลง jcmp
jcmp -version
printf 'void main() { cout << "hi\\n"; }\n' > hi.jk
jcmp hi.jk -o hi && ./hi
```
ไม่ตั้ง `PATH` ก็เรียกด้วยที่อยู่เต็มได้ เช่น `../bin/jcmp hi.jk -o hi`
ถ้าอยากอ่าน/สร้างคอมไพเลอร์เอง: `git clone https://github.com/J2k-studio/Jcmp.git` (มี `bin/jcmp` พร้อมใช้)

## สถานะ
* ใช้ได้แล้ว: ชนิดจำนวนเต็ม (`int i32 i8 char bool`), `f32/f64`, array (สูงสุด 3 มิติ), pointer,
  struct + method, enum, `switch`, `for`/`while`, string, `#define`, `import`
* ไลบรารีมาตรฐาน (`std/`): `Sys`, `Mem` (heap), `Str`, `Math`, `File`
* ข้อความ error/warning แบบ `ไฟล์:บรรทัด:คอลัมน์: error: ...` พร้อมบรรทัดซอร์สและ `^`
* ยังไม่มี: dynamic array, `cin`,
  thread, การทำให้โค้ดเร็วขึ้น
* `-d` ตรวจขอบเขต array ตอนรัน (ผิดแล้วโปรแกรมหยุดพร้อมข้อความ)
* รองรับเฉพาะ Linux **ARM64**

## เอกสาร
* บทเรียนทีละขั้น: [docs/TUTORIAL.th.md](docs/TUTORIAL.th.md) (ภาษาอังกฤษ: [docs/TUTORIAL.md](docs/TUTORIAL.md))
* วิธีใช้และการ build/ทดสอบ: [docs/USAGE.md](docs/USAGE.md)
* ทัวร์ภาษา: [docs/LANGUAGE.md](docs/LANGUAGE.md) (ภาษาอังกฤษ)
* สเปกภาษา (ภาษาไทย): [docs/syntax-design.md](docs/syntax-design.md)
* ประวัติแต่ละรุ่น: [CHANGELOG.md](CHANGELOG.md)

## สัญญาอนุญาต
โครงการนี้เป็น **proprietary แบบเปิดซอร์สให้อ่าน**: อ่านและรันเพื่อศึกษา/ใช้ส่วนตัวแบบไม่แสวงกำไรได้
ห้ามคัดลอก เผยแพร่ซ้ำ หรืออ้างว่าเป็นผลงานตนเอง ดูรายละเอียดใน [LICENSE](LICENSE)

ผู้เขียน: **Jao** (J2k-studio) ประเทศไทย
