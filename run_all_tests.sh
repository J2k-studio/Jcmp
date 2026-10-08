#!/data/data/com.termux/files/usr/bin/bash
# run_all_tests.sh — build Jcmp-v1 + j2k_asm_v1 once, then run the whole
# test suite (v0 arithmetic + v1.1 if/else + v1.2 while/break/continue/
# compound-assign) and report PASS/FAIL against expected exit codes.
#
# วางไฟล์นี้ไว้โฟลเดอร์เดียวกับ Jcmp-v1.s และ j2k_asm_v1.s แล้วมีโฟลเดอร์ย่อย
# ชื่อ tests/ หรือ test/ (สคริปต์เช็คให้อัตโนมัติว่ามีอันไหน) ที่เก็บไฟล์ .jk
#
# ใช้งาน:
#   chmod +x run_all_tests.sh
#   ./run_all_tests.sh

set -u
cd "$(dirname "$0")"   # always run from the repository root
PASS=0
FAIL=0
FAILED_NAMES=""

# หาโฟลเดอร์ที่เก็บไฟล์ .jk อัตโนมัติ (tests/ หรือ test/)
if [ -d "tests" ]; then
    TESTDIR="tests"
elif [ -d "test" ]; then
    TESTDIR="test"
else
    echo "ไม่เจอโฟลเดอร์ tests/ หรือ test/ — ย้ายไฟล์ .jk ทั้งหมดไปไว้ในโฟลเดอร์ใดโฟลเดอร์หนึ่งก่อน"
    exit 1
fi
echo "ใช้โฟลเดอร์เทส: $TESTDIR/"

mkdir -p build
if [ -f seed/Jcmp-v1.s ]; then
echo "== building Jcmp-v1 (the frozen assembly compiler) =="
as -o build/Jcmp-v1.o seed/Jcmp-v1.s || { echo "seed/Jcmp-v1.s assemble FAILED"; exit 1; }
ld -o build/Jcmp build/Jcmp-v1.o || { echo "Jcmp-v1.o link FAILED"; exit 1; }
chmod +x build/Jcmp

echo "== building j2k_asm_v1 =="
as -o build/j2k_asm_v1.o seed/j2k_asm_v1.s || { echo "j2k_asm_v1.s assemble FAILED"; exit 1; }
ld -o build/j2k_asm_v1 build/j2k_asm_v1.o || { echo "j2k_asm_v1.o link FAILED"; exit 1; }
chmod +x build/j2k_asm_v1
elif [ -z "${JCMP:-}" ]; then
    echo "seed/ is not here: run the suite with the J2K compiler:  JCMP=_test_out/boot/jcmp3 ./run_all_tests.sh   (after ./bootstrap.sh)"
    exit 1
fi

mkdir -p _test_out
# the J2K compiler's std contains float code: use the J2K assembler (it knows the FP instructions)
if [ -n "${JCMP:-}" ]; then ASM=${ASM:-bin/j2k_asm_j2k}; fi
echo ""
echo "== running tests =="

run_test () {
    name="$1"
    expected="$2"
    jk="${TESTDIR}/${name}.jk"
    jasm="_test_out/${name}.jasm"
    elf="_test_out/${name}_bin"

    if [ ! -f "$jk" ]; then
        echo "SKIP  $name (missing $jk)"
        return
    fi

    rm -f "$jasm" "$elf"
    ${JCMP:-build/Jcmp} "$jk" "$jasm" ${JCFLAGS:-} 2> "_test_out/${name}.compile_err"
    if [ -f "${TESTDIR}/${name}.warn" ] && ! cmp -s "${TESTDIR}/${name}.warn" "_test_out/${name}.compile_err"; then
        echo "FAIL  $name  (compiler messages differ from ${TESTDIR}/${name}.warn -- see _test_out/${name}.compile_err)"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi
    if [ ! -f "$jasm" ]; then
        echo "FAIL  $name  (Jcmp compile error: $(cat _test_out/${name}.compile_err))"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi

    ${ASM:-build/j2k_asm_v1} "$jasm" "$elf" 2> "_test_out/${name}.asm_err"
    if [ ! -f "$elf" ]; then
        echo "FAIL  $name  (j2k_asm error: $(cat _test_out/${name}.asm_err))"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi
    chmod +x "$elf"

    input=/dev/null
    [ -f "${TESTDIR}/${name}.in" ] && input="${TESTDIR}/${name}.in"      # optional keyboard input for cin
    timeout 20 "./$elf" < "$input" > "_test_out/${name}.stdout" 2>/dev/null
    actual=$?

    # optional stdout check: test/<name>.out holds the exact expected output
    if [ -f "${TESTDIR}/${name}.out" ] && ! cmp -s "${TESTDIR}/${name}.out" "_test_out/${name}.stdout"; then
        echo "FAIL  $name  (stdout differs from ${TESTDIR}/${name}.out -- see _test_out/${name}.stdout)"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
        return
    fi

    if [ "$actual" -eq "$expected" ]; then
        echo "PASS  $name  (got $actual)"
        PASS=$((PASS+1))
    else
        echo "FAIL  $name  (expected $expected, got $actual)"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
    fi
}

# run_fail NAME -- the program test/NAME.jk must be REJECTED by Jcmp
run_fail() {
    name="$1"
    jk="${TESTDIR}/${name}.jk"
    jasm="_test_out/${name}.jasm"
    rm -f "$jasm"
    if ${JCMP:-build/Jcmp} "$jk" "$jasm" ${JCFLAGS:-} 2> "_test_out/${name}.compile_err"; then
        echo "FAIL  $name  (should have been rejected but compiled)"
        FAIL=$((FAIL+1))
        FAILED_NAMES="$FAILED_NAMES $name"
    else
        echo "PASS  $name  (rejected: $(head -1 _test_out/${name}.compile_err | cut -c1-60))"
        PASS=$((PASS+1))
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
run_test t17_mul                42
run_test t18_div                6
run_test t19_mul_expr           42
run_test t20_div_expr           6
run_test t21_fact               120
run_test t25_func_simple        7
run_test t26_func_noargs        42
run_test t27_func_recursion     55
run_test t28_array_main         30
run_test t29_array_fn           200
run_test t30_array_call_index   105
run_test t31_return_chain       15
run_test t32_decl_chain         12
run_test t33_array_write_chain  112
run_test t34_unary_minus_literal 5
run_test t35_unary_minus_var     13
run_test t36_unary_minus_mixed   32
run_test t37_ten_vars             55
run_test t38_spill_basic          78
run_test t39_spill_compound       68
run_test t40_modulo                9
run_test t41_for_basic             45
run_test t42_for_continue_break    49
run_test t43_cond_chain            13
run_test t44_plain_reassign         45
run_test t45_plain_reassign_spilled 150
run_test t46_precedence_basic       22
run_test t47_parens                 41
run_test t48_precedence_unary        9
run_test t49_precedence_cond         1
run_test t50_precedence_mixed       30
run_test t51_nested_call_arg        14
run_test t52_cmp_as_value            3
run_test t53_logical_not             2
run_test t54_for_range              45
run_test t55_for_nested              9
run_test t56_i8_wrap               171
if [ -n "${JCMP:-}" ]; then run_test t57_i8_arith_wrap 88; else run_test t57_i8_arith_wrap 216; fi   # J2K: i8 arithmetic is done at int width (like C)
run_test t58_i32_wrap               32
run_test t59_i8_array               71
run_test t60_i8_param_ret           17
run_test t61_i32_array              40
run_test t62_i8_compound            46
run_test t63_i32_max                78
if [ -n "${JCMP:-}" ]; then run_test t64_cond_width 99; else run_test t64_cond_width 12; fi   # J2K: i8 arithmetic is done at int width (like C)
if [ -n "${JCMP:-}" ]; then run_test t65_cond_width_for 58; else run_test t65_cond_width_for 37; fi   # J2K: i8 arithmetic is done at int width (like C)
run_test t66_compound_expr           57
run_test t67_compound_spilled_call 221
run_test t68_compound_i8           224
run_test t69_char_basic             95
run_test t70_char_string            42
run_test t71_char_cout               0
run_test t72_comments_bool          13
run_test t73_char_func              77
run_test t74_void_callstmt           9
run_test t75_func_order             40
run_test t76_main_no_return          0
run_test t77_void_main               0
run_test t78_bigframe                241
run_test t79_multidim                36
run_test t80_multidim3               17
run_test t81_array_compound          154
run_test t82_logic                    135
run_test t83_shortcircuit              7
run_test t84_bitops                    185
run_test t85_cout_shift                0
run_test t86_bit_compound            35
run_test t87_hex_bin                  58
run_test t88_bitnot                   29
run_test t89_cout_chain                0
run_test t90_global                    34
run_test t91_global_array              65
run_test t92_pointer                   68
run_test t93_pointer_global            40
run_test t94_pointer_index             63
run_test t95_big_immediates           24
run_test t96_syscall                   35
run_test t97_bool                      255
run_test t98_bool_paren                31
run_test t99_big_offset                37
run_test t108_struct                    116
run_test t109_struct_arrays            160
run_test t110_struct_copy             104
run_test t111_frame_spill_mix         241
run_test t112_struct_value            91
run_test t113_struct_methods          133
run_test t114_struct_ctor             67
run_test t115_enum_cast               133
run_test t122_static                  75
run_test t123_switch                  181
run_test t124_string_literal          27
run_test t125_cmp_both_sides          9
run_test t126_define                  48
run_test t127_array_param             218
run_test t128_std_file                63
run_test t129_big_limits              68
run_test t130_import                  42
run_fail t100_fail_if_int
run_fail t101_fail_bool_to_int
run_fail t102_fail_int_to_bool
run_fail t103_fail_arith_bool
run_fail t104_fail_return_bool
run_fail t105_fail_bool_arg
run_fail t106_fail_not_int
run_fail t107_fail_and_int
run_fail t116_fail_int_to_enum
run_fail t117_fail_enum_to_int
run_fail t118_fail_enum_arith
run_fail t119_fail_enum_cond
run_fail t120_fail_enum_cmp_int
run_fail t121_fail_cast_bool
# rules only the J2K compiler enforces (spec items 2a and 28): run them with JCMP=...
if [ -n "${JCMP:-}" ]; then
    run_fail t131_fail_local_hides_global
    run_fail t132_fail_int_from_true
    run_test t133_array_len             43
    run_test t134_raw_string            11
    ASM=bin/j2k_asm_j2k run_test t135_float_basic         116
    ASM=bin/j2k_asm_j2k run_test t136_float_func          14
    run_test t140_mem_alloc             46
    run_test t150_import_j              41
    run_fail t151_fail_j_main
    run_fail t152_fail_dup_local
    JCFLAGS="-d" run_test t154_bounds                  134
    JCFLAGS="-d" run_test t155_bounds_multi            134
    run_test t153_shadow_in_block       14
    run_test t156_struct_result         59
    run_test t157_ptr_ptr               15
    run_test t158_many_args             132
    run_test t159_try_catch             1
    run_fail t160_fail_throw_number
    run_test t161_sizeof                222
    run_test t162_unsigned              127
    run_fail t163_fail_sign_mix
    run_test t164_fnptr                 143
    run_test t167_dyn_array             13
    JCFLAGS="-d" run_test t168_dyn_bounds              134
    run_fail t169_fail_dyn_type
    run_test t170_owner                 103
    run_test t171_warn_owner            1
    run_test t173_cin                   111
    run_test t174_char_after_float      9
    JCFLAGS="-d" run_test t172_leak_report            3
    run_fail t165_fail_fnptr_type
    run_fail t166_fail_fnptr_args
    JCFLAGS="-I test/incdir" run_test t144_include_dir     42
    ASM=bin/j2k_asm_j2k run_test t143_math           151
    run_test t141_str                   59
    run_test t142_sys                   17
    run_test t145_warn_switch           22
    run_test t146_warn_struct           10
    run_fail t147_fail_static_call
    run_fail t148_fail_method_scope
    JCFLAGS="-st" run_fail t149_fail_strict_switch
    run_fail t137_fail_float_mix
    run_fail t138_fail_cout_float
    run_fail t139_fail_float_mod
fi

echo ""
echo "== summary: $PASS passed, $FAIL failed =="
if [ "$FAIL" -gt 0 ]; then
    echo "failed tests:$FAILED_NAMES"
    echo "(ดู _test_out/<name>.compile_err หรือ .asm_err และ .jasm ที่ generate ไว้ เพื่อ debug)"
fi
