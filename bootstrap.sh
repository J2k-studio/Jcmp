# bootstrap.sh -- the three-stage bootstrap of the J2K compiler written in J2K
# (and, when the assembly seed is present, a comparison with it on the test programs).
#
#   stage 0  bin/jcmp (the committed binary)  compiles jcmp/jcmp.jk  -> jcmp1
#   stage 1  jcmp1                            compiles jcmp/jcmp.jk  -> jcmp2
#   stage 2  jcmp2                            compiles jcmp/jcmp.jk  -> jcmp3
# success = jcmp2.jasm and jcmp3.jasm (and the binaries) are identical.
# (The first compiler, written in assembly, cannot read the .j sources any more. If its
# files are in seed/ the script also compares the two compilers on the tests.)
set -u
cd "$(dirname "$0")"
O=_test_out/boot
mkdir -p $O
mkdir -p build
if [ -f seed/Jcmp-v1.s ]; then
    as -o build/Jcmp-v1.o seed/Jcmp-v1.s && ld -o build/Jcmp build/Jcmp-v1.o || exit 1
    as -o build/j2k_asm_v1.o seed/j2k_asm_v1.s && ld -o build/j2k_asm_v1 build/j2k_asm_v1.o || exit 1
fi

bin/jcmp jcmp/jcmp.jk -o $O/jcmp1 --emit-asm $O/jcmp1.jasm  || { echo "stage 0 FAILED"; exit 1; }
$O/jcmp1 jcmp/jcmp.jk -o $O/jcmp2 --emit-asm $O/jcmp2.jasm  || { echo "stage 1 FAILED"; exit 1; }
$O/jcmp2 jcmp/jcmp.jk -o $O/jcmp3 --emit-asm $O/jcmp3.jasm  || { echo "stage 2 FAILED"; exit 1; }
chmod +x $O/jcmp1 $O/jcmp2 $O/jcmp3
if cmp -s $O/jcmp2.jasm $O/jcmp3.jasm && cmp -s $O/jcmp2 $O/jcmp3; then
    echo "BOOTSTRAP OK: jcmp2 and jcmp3 are identical ($(wc -c < $O/jcmp3.jasm) bytes of .jasm)"
else
    echo "BOOTSTRAP FAILED: jcmp2 and jcmp3 differ"; exit 1
fi
if cmp -s $O/jcmp3 bin/jcmp; then echo "bin/jcmp is up to date"; else echo "NOTE: bin/jcmp differs from what the sources build (cp $O/jcmp3 bin/jcmp to update)"; fi

# the J2K compiler vs the assembly compiler on every test it understands (only if seed/ is present)
if [ ! -x build/Jcmp ]; then echo "(no assembly seed here: comparison with it skipped)"; exit 0; fi
# (the std library contains float code: assemble with the J2K assembler, which knows it)
ASM=bin/j2k_asm_j2k
same=0; diff=0; skip=0
for jk in test/t*.jk; do
    n=$(basename $jk .jk)
    $O/jcmp3 $jk $O/$n.new.jasm 2>/dev/null; ra=$?
    build/Jcmp $jk $O/$n.old.jasm 2>/dev/null; rb=$?
    case $n in t57_*|t64_*|t65_*) skip=$((skip+1)); continue;; esac   # i8 arithmetic: jcmp uses int width like C, the frozen asm compiler wraps
    case $n in t13[1-9]_*|t14[0-9]_*|t15[0-9]_*|t16[0-9]_*|t17[0-9]_*) skip=$((skip+1)); continue;; esac   # rules only jcmp has (the asm compiler is a frozen seed)
    if [ $ra -ne 0 ] && [ $rb -ne 0 ]; then skip=$((skip+1)); continue; fi
    if [ $ra -ne 0 ] || [ $rb -ne 0 ]; then echo "ACCEPT MISMATCH: $n (jcmp3 rc=$ra, Jcmp rc=$rb)"; diff=$((diff+1)); continue; fi
    $ASM $O/$n.new.jasm $O/$n.new 2>/dev/null; $ASM $O/$n.old.jasm $O/$n.old 2>/dev/null
    chmod +x $O/$n.new $O/$n.old 2>/dev/null
    $O/$n.new > $O/$n.new.out 2>/dev/null; a=$?
    $O/$n.old > $O/$n.old.out 2>/dev/null; b=$?
    if [ $a -eq $b ] && cmp -s $O/$n.new.out $O/$n.old.out; then same=$((same+1)); else diff=$((diff+1)); echo "DIFFERENT: $n (new rc=$a, old rc=$b)"; fi
done
echo "tests the J2K compiler can build: same result as the assembly compiler = $same, different = $diff (not in its subset: $skip)"
