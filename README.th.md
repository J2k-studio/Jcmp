# J2K และ Jcmp

**J2K** คือภาษาโปรแกรมระดับระบบที่ออกแบบเองตั้งแต่ศูนย์ ใกล้ฮาร์ดแวร์
**Jcmp** คือคอมไพเลอร์ของมัน อ่านซอร์ส `.jk` / `.j` แล้วเขียนไฟล์รันบน Linux ARM64 ตรงๆ
(มี assembler และตัวเขียน ELF ในตัว ไม่ใช้ LLVM, GCC, `as` หรือ `ld`)

คอมไพเลอร์เขียนด้วย J2K เอง และคอมไพล์ตัวเองได้ (self-hosting) พัฒนาทั้งหมดบนมือถือ (ARM64, Termux)

## ติดตั้ง
ต้องใช้เครื่อง Linux **ARM64** (มือถือที่มี Termux ได้) และ `curl` หรือ `wget` (Termux: `pkg install curl wget`)
คอมไพเลอร์เป็นไฟล์เดียว ปล่อยเป็น [release](https://github.com/J2k-studio/Jcmp/releases)

```bash
# บรรทัดเดียว (โหลดรุ่นล่าสุด ตรวจ SHA-256 แล้วติดตั้ง)
curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh

# หรือทำเองทีละขั้น
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/jcmp-linux-arm64
curl -fLO https://github.com/J2k-studio/Jcmp/releases/latest/download/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS      # ต้องขึ้น OK
chmod +x jcmp-linux-arm64 && mv jcmp-linux-arm64 ~/.local/bin/jcmp

jcmp --version
jcmp examples/hello.jk -o hello && ./hello    # examples อยู่ในไฟล์ .tar.gz ของ release หรือใน repo
```

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
* วิธีใช้และการ build/ทดสอบ: [docs/USAGE.md](docs/USAGE.md)
* ทัวร์ภาษา: [docs/LANGUAGE.md](docs/LANGUAGE.md) (ภาษาอังกฤษ)
* สเปกภาษา (ภาษาไทย): [docs/syntax-design.md](docs/syntax-design.md)
* ประวัติแต่ละรุ่น: [CHANGELOG.md](CHANGELOG.md)

## สัญญาอนุญาต
โครงการนี้เป็น **proprietary แบบเปิดซอร์สให้อ่าน**: อ่านและรันเพื่อศึกษา/ใช้ส่วนตัวแบบไม่แสวงกำไรได้
ห้ามคัดลอก เผยแพร่ซ้ำ หรืออ้างว่าเป็นผลงานตนเอง ดูรายละเอียดใน [LICENSE](LICENSE)

ผู้เขียน: **Jao** (J2k-studio) ประเทศไทย
