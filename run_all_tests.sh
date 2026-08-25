#!/data/data/com.termux/files/usr/bin/bash
# run_all_tests.sh — build Jcmp-v1 + j2k_asm_v0.3 once, then run the whole
# test suite (v0 arithmetic + v1.1 if/else + v1.2 while/break/continue/
# compound-assign) and report PASS/FAIL against expected exit codes.
#
# วางไฟล์นี้ไว้โฟลเดอร์เดียวกับ Jcmp-v1.s และ j2k_asm_v0.3.s แล้วสร้างโฟลเดอร์
# ย่อยชื่อ tests/ ที่มีไฟล์ .jk ทั้งหมดอยู่ข้างใน (ตามที่แนบมาให้)
#
# ใช้งาน:
#   chmod +x run_all_tests.sh
#   ./run_all_tests.sh

set -u
PASS=0
FAIL=0
FAILED_NAMES=""

echo "== building Jcmp-v1 =="
as -o Jcmp-v1.o Jcmp-v1.s || { echo "Jcmp-v1.s assemble FAILED"; exit 1; }
ld -o Jcmp Jcmp-v1.o || { echo "Jcmp-v1.o link FAILED"; exit 1; }
chmod +x Jcmp

echo "== building j2k_asm_v0.3 =="
as -o j2k_asm_v0.3.o j2k_asm_v0.3.s || { echo "j2k_asm_v0.3.s assemble FAILED"; exit 1; }
ld -o j2k_asm_v0.3 j2k_asm_v0.3.o || { echo "j2k_asm_v0.3.o link FAILED"; exit 1; }
chmod +x j2k_asm_v0.3

mkdir -p _test_out
echo ""
echo "== running tests =="

run_test () {
    name="$1"
    expected="$2"
    jk="tests/${name}.jk"
    jasm="_test_out/${name}.jasm"
    elf="_test_out/${name}_bin"

    if [ ! -f "$jk" ]; then
        echo "SKIP  $name (missing $jk)"
        return
    fi

    ./Jcmp "$jk" "$jasm" 2> "_test_out/${name}.compile_err"
    if [ ! -f "$jasm" ]; then
        echo "FAIL  $name  (Jcmp compile error: $(cat _test_out/${name}.compile_err))"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi

    ./j2k_asm_v0.3 "$jasm" "$elf" 2> "_test_out/${name}.asm_err"
    if [ ! -f "$elf" ]; then
        echo "FAIL  $name  (j2k_asm error: $(cat _test_out/${name}.asm_err))"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi

    "./$elf"
    actual=$?

    if [ "$actual" -eq "$expected" ]; then
        echo "PASS  $name  (got $actual)"
        PASS=$((PASS+1))
    else
        echo "FAIL  $name  (expected $expected, got $actual)"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
    fi
}

# name                        expected exit code
run_test t01_single             7
run_test t02_add                8
run_test t03_sub                12
run_test t04_if_true            1
run_test t05_if_false           0
run_test t06_elif               30
run_test t07_elif_fallthrough   99
run_test t08_nested_if          42
run_test t09_while              10
run_test t10_minuseq            8
run_test t11_decrement          3
run_test t12_break              5
run_test t13_continue           18
run_test t14_nested_while       9
run_test t15_nested_break       6
run_test t16_combined           2

echo ""
echo "== summary: $PASS passed, $FAIL failed =="
if [ "$FAIL" -gt 0 ]; then
    echo "failed tests:$FAILED_NAMES"
    echo "(ดู _test_out/<name>.compile_err หรือ .asm_err และ .jasm ที่ generate ไว้ เพื่อ debug)"
fi
