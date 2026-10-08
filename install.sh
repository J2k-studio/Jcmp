#!/bin/sh
# install.sh -- download the Jcmp compiler from the latest GitHub release, check it and put it in a folder.
#
#   curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
#   wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
#
# Options (after `sh -s --` when the script comes through a pipe):
#   --dir DIR          the folder for the program (default: $PREFIX/bin on Termux, else ~/.local/bin).
#                      Example: ... | sh -s -- --dir ../bin
#   --version X.Y.Z    a specific release (default: the latest)
#   --with-assembler   also install j2k_asm, the stand-alone assembler
# Environment: JCMP_VERSION (same as --version), JCMP_BASE=URL to download from another place (a mirror,
# or file:///folder for a local copy).
set -eu
REPO="J2k-studio/Jcmp"
BINDIR=""
VERSION="${JCMP_VERSION:-}"
WITH_ASM=0
usage() { sed -n '2,13p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' || true; }
while [ $# -gt 0 ]; do
    case "$1" in
        --dir) [ $# -ge 2 ] || { echo "install: --dir needs a folder"; exit 1; }; BINDIR="$2"; shift 2 ;;
        --version) [ $# -ge 2 ] || { echo "install: --version needs a number"; exit 1; }; VERSION="$2"; shift 2 ;;
        --with-assembler) WITH_ASM=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "install: unknown option '$1' (try --help)"; exit 1 ;;
    esac
done
case "$(uname -m)" in
    aarch64|arm64) ;;
    *) echo "install: Jcmp makes programs for Linux ARM64 only (this machine is $(uname -m))"; exit 1 ;;
esac
fetch() {   # fetch URL FILE
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
    else echo "install: curl or wget is needed"; exit 1; fi
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if [ -z "${JCMP_BASE:-}" ] && [ -z "$VERSION" ]; then
    # find the number of the latest release first, so that all files come from the same release
    if fetch "https://api.github.com/repos/$REPO/releases/latest" "$TMP/latest.json" 2>/dev/null; then
        VERSION="$(sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' "$TMP/latest.json" | head -1)"
    fi
fi
if [ -n "${JCMP_BASE:-}" ]; then
    BASE="$JCMP_BASE"
elif [ -n "$VERSION" ]; then
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
else
    BASE="https://github.com/$REPO/releases/latest/download"
fi
if [ -z "$BINDIR" ]; then
    if [ -n "${PREFIX:-}" ]; then BINDIR="$PREFIX/bin"; else BINDIR="$HOME/.local/bin"; fi
fi
mkdir -p "$BINDIR"
BINDIR="$(cd "$BINDIR" && pwd)"
echo "downloading from $BASE ..."
fetch "$BASE/SHA256SUMS" "$TMP/SHA256SUMS"
install_one() {   # install_one NAME OLD-NAME : releases before 0.2.2 called the files NAME-linux-arm64
    GOT="$1"
    if ! fetch "$BASE/$1" "$TMP/$1" 2>/dev/null; then
        GOT="$2"
        fetch "$BASE/$2" "$TMP/$2"
    fi
    WANT="$(grep " $GOT\$" "$TMP/SHA256SUMS" | cut -d' ' -f1)"
    HAVE="$(sha256sum "$TMP/$GOT" | cut -d' ' -f1)"
    [ -n "$WANT" ] && [ "$WANT" = "$HAVE" ] || { echo "install: the checksum of $GOT does not match, nothing installed"; exit 1; }
    cp "$TMP/$GOT" "$BINDIR/$1"
    chmod +x "$BINDIR/$1"
}
install_one jcmp jcmp-linux-arm64
[ "$WITH_ASM" = 1 ] && install_one j2k_asm j2k_asm-linux-arm64
echo "installed: $BINDIR/jcmp  ($("$BINDIR/jcmp" -version))"
[ "$WITH_ASM" = 1 ] && echo "installed: $BINDIR/j2k_asm"
case ":$PATH:" in *":$BINDIR:"*) ;; *) echo "add the folder to your PATH:  export PATH=\"$BINDIR:\$PATH\"" ;; esac
