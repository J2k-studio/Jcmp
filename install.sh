#!/bin/sh
# install.sh -- download the latest Jcmp release, check it and install it.
#   curl -fsSL https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh
#   (or:  wget -qO- https://raw.githubusercontent.com/J2k-studio/Jcmp/main/install.sh | sh)
# Environment: JCMP_VERSION=0.1.0 to pick a version (default: the latest), JCMP_BASE=URL to download from
# another place, PREFIX=/dir to choose where
# bin/jcmp goes (default: $PREFIX on Termux, else ~/.local).
set -eu
REPO="J2k-studio/Jcmp"
case "$(uname -m)" in
    aarch64|arm64) ;;
    *) echo "install: Jcmp makes programs for Linux ARM64 only (this machine is $(uname -m))"; exit 1 ;;
esac
if [ -n "${JCMP_BASE:-}" ]; then
    BASE="$JCMP_BASE"                     # a mirror or a local folder (file:///...), also used for testing
elif [ -n "${JCMP_VERSION:-}" ]; then
    BASE="https://github.com/$REPO/releases/download/v$JCMP_VERSION"
else
    BASE="https://github.com/$REPO/releases/latest/download"
fi
DEST="${PREFIX:-$HOME/.local}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fetch() {   # fetch URL FILE
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
    else echo "install: curl or wget is needed"; exit 1; fi
}
echo "downloading from $BASE ..."
fetch "$BASE/jcmp-linux-arm64" "$TMP/jcmp-linux-arm64"
fetch "$BASE/SHA256SUMS" "$TMP/SHA256SUMS"
WANT="$(grep ' jcmp-linux-arm64$' "$TMP/SHA256SUMS" | cut -d' ' -f1)"
HAVE="$(sha256sum "$TMP/jcmp-linux-arm64" | cut -d' ' -f1)"
[ -n "$WANT" ] && [ "$WANT" = "$HAVE" ] || { echo "install: the checksum does not match, nothing installed"; exit 1; }
mkdir -p "$DEST/bin"
cp "$TMP/jcmp-linux-arm64" "$DEST/bin/jcmp"
chmod +x "$DEST/bin/jcmp"
echo "installed: $DEST/bin/jcmp  ($("$DEST/bin/jcmp" --version))"
case ":$PATH:" in *":$DEST/bin:"*) ;; *) echo "add $DEST/bin to your PATH:  export PATH=\"$DEST/bin:\$PATH\"" ;; esac
