#!/data/data/com.termux/files/usr/bin/bash
# bootstrap-from-binary.sh -- rebuild the J2K compiler with the J2K compiler:
# no assembly seed needed, only the committed binaries in bin/.
#   bin/jcmp  compiles jcmp/jcmp.jk -o <stage1>   (the assembler is inside jcmp)
#   stage1    compiles jcmp/jcmp.jk -o <stage2>
# success = stage1 == stage2 == bin/jcmp (byte for byte). Run ./gen_std.sh first if std/ changed.
set -eu
cd "$(dirname "$0")"
O=_test_out/binboot
mkdir -p $O
bin/jcmp jcmp/jcmp.jk -o $O/stage1 && chmod +x $O/stage1
$O/stage1 jcmp/jcmp.jk -o $O/stage2 && chmod +x $O/stage2
if cmp -s $O/stage1 $O/stage2; then
    echo "stage1 == stage2 ($(wc -c < $O/stage2) bytes)"
else
    echo "FAILED: stage1 and stage2 differ"; exit 1
fi
if cmp -s $O/stage2 bin/jcmp; then
    echo "OK: the committed bin/jcmp is exactly what the sources build"
else
    echo "NOTE: bin/jcmp is older than the sources (copy $O/stage2 to bin/jcmp to update it)"
fi
