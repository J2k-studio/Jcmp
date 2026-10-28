#!/bin/sh
# runs the bootstrap N times and keeps the jasm of jcmp2 and jcmp3 of every run that differs
cd "$HOME/Jcmp"
N=${1:-6}
i=1
while [ $i -le $N ]; do
    ./bootstrap.sh > _t/boot_$i.log 2>&1
    if grep -q "BOOTSTRAP OK" _t/boot_$i.log; then echo "run $i: ok"; else echo "run $i: FAILED"; cp -r _test_out/boot _t/boot_fail_$i 2>/dev/null; fi
    i=$((i+1))
done
echo LOOP-DONE
