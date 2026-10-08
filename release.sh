#!/data/data/com.termux/files/usr/bin/bash
# release.sh -- builds the files of a GitHub release into dist/
#   dist/jcmp                                the compiler (one file, nothing else needed)
#   dist/j2k_asm                             the stand-alone assembler (optional tool)
#   dist/jcmp.tar.gz                         only the program `jcmp`, with its executable bit (tar keeps it; a plain
#                                            release file does not): curl -fL URL | tar xz -C folder
#   dist/jcmp-<version>-linux-arm64.tar.gz   compiler + assembler + README + LICENSE + examples + docs
#   dist/SHA256SUMS                          checksums of the three files above
# The version comes from the file VERSION and must match `bin/jcmp --version`.
set -eu
cd "$(dirname "$0")"
V=$(cat VERSION)
mkdir -p build
./bootstrap.sh > build/release_bootstrap.txt 2>&1 || { cat build/release_bootstrap.txt; echo "release: bootstrap failed"; exit 1; }
grep -q "bin/jcmp is up to date" build/release_bootstrap.txt || { echo "release: bin/jcmp is not what the sources build (cp _test_out/boot/jcmp3 bin/jcmp)"; exit 1; }
[ "$(bin/jcmp -version | cut -d' ' -f2)" = "$V" ] || { echo "release: bin/jcmp says $(bin/jcmp --version), VERSION says $V"; exit 1; }
JCMP=_test_out/boot/jcmp3 ./run_all_tests.sh > build/release_tests.txt 2>&1 || true
tail -1 build/release_tests.txt | grep -q " 0 failed" || { tail -5 build/release_tests.txt; echo "release: the tests fail"; exit 1; }
rm -rf dist
mkdir -p dist/pkg
cp bin/jcmp dist/jcmp
cp bin/j2k_asm_j2k dist/j2k_asm
chmod 755 dist/jcmp dist/j2k_asm
cp bin/jcmp dist/pkg/jcmp && chmod 755 dist/pkg/jcmp
cp bin/j2k_asm_j2k dist/pkg/j2k_asm && chmod 755 dist/pkg/j2k_asm
cp README.md LICENSE VERSION dist/pkg/
mkdir -p dist/pkg/examples dist/pkg/docs
cp examples/*.jk dist/pkg/examples/
cp docs/LANGUAGE.md docs/USAGE.md dist/pkg/docs/
( cd dist && mv pkg "jcmp-$V-linux-arm64" && tar -czf "jcmp-$V-linux-arm64.tar.gz" "jcmp-$V-linux-arm64" && rm -rf "jcmp-$V-linux-arm64" )
( cd dist && tar --owner=0 --group=0 -czf jcmp.tar.gz jcmp && sha256sum jcmp jcmp.tar.gz j2k_asm "jcmp-$V-linux-arm64.tar.gz" > SHA256SUMS )
echo "release $V:"; ls -l dist | awk 'NR>1 {print "  " $5 "  " $9}'
echo
echo "To publish (after pushing the branch main and the tag):"
echo "  git tag v$V <the commit on main>   &&   git push origin main v$V"
echo "  gh release create v$V dist/* --title \"J2K / Jcmp $V\" --notes-file docs/RELEASE_NOTES.md"
