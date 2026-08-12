#!/bin/sh
# Build a bootable Rebuilt Unix ISO from the official FreeBSD 15.1 release sets.
# This script runs inside the FreeBSD builder VM.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$REPO_ROOT/build/config/release.conf"
. "$REPO_ROOT/build/config/build.conf"

WORK_DIR="${WORK_DIR:-/tmp/rebuilt-unix-build}"
ROOTFS="$WORK_DIR/rootfs"
ISO_ROOT="$WORK_DIR/iso-root"
OUTPUT="$REPO_ROOT/build/output"
ISO="$OUTPUT/rebuilt-unix-${BASE_VERSION}-${TARGET_ARCH}.iso"

FREEBSD_MIRROR="https://download.freebsd.org/releases/amd64/amd64/15.1-RELEASE"
BASE_URL="$FREEBSD_MIRROR/base.txz"
KERNEL_URL="$FREEBSD_MIRROR/kernel.txz"
SRC_URL="https://codeload.github.com/freebsd/freebsd-src/tar.gz/refs/heads/releng/15.1"

rm -rf "$WORK_DIR"
mkdir -p "$ROOTFS" "$ISO_ROOT/usr/freebsd-dist" "$OUTPUT"

printf '%s\n' '========================================'
printf '%s\n' '       Rebuilt Unix ISO Builder'
printf '%s\n' '========================================'
printf 'Target: %s %s\n' "$BASE_OS" "$BASE_VERSION"
printf 'Arch:   %s\n' "$TARGET_ARCH"
printf 'Output: %s\n\n' "$ISO"

printf '%s\n' '[1/7] Downloading official FreeBSD 15.1 release sets...'
fetch -o "$WORK_DIR/base.txz" "$BASE_URL"
fetch -o "$WORK_DIR/kernel.txz" "$KERNEL_URL"

test -s "$WORK_DIR/base.txz"
test -s "$WORK_DIR/kernel.txz"

printf '%s\n' '[2/7] Verifying release sets...'
tar -tzf "$WORK_DIR/base.txz" >/dev/null
tar -tzf "$WORK_DIR/kernel.txz" >/dev/null

printf '%s\n' '[3/7] Creating Rebuilt Unix root filesystem...'
tar -C "$ROOTFS" -xpf "$WORK_DIR/base.txz"
tar -C "$ROOTFS" -xpf "$WORK_DIR/kernel.txz"

printf '%s\n' '[4/7] Applying Rebuilt Unix branding and configuration...'
mkdir -p "$ROOTFS/usr/local/share/backgrounds/rebuilt-unix"
cp "$REPO_ROOT/build/branding/wallpapers/rebuilt-unix.svg" \
   "$ROOTFS/usr/local/share/backgrounds/rebuilt-unix/rebuilt-unix.svg"
cp "$REPO_ROOT/build/branding/system/os-release" \
   "$ROOTFS/etc/rebuilt-unix-release"

cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Rebuilt Unix.

A FreeBSD-based Unix system rebuilt our way.
Base: FreeBSD 15.1-RELEASE
Package manager: pkg

EOF

cat > "$ROOTFS/etc/issue" <<'EOF'
Rebuilt Unix - FreeBSD 15.1-RELEASE

EOF

printf '%s\n' '[5/7] Preparing FreeBSD release media...'
cp "$WORK_DIR/base.txz" "$ISO_ROOT/usr/freebsd-dist/base.txz"
cp "$WORK_DIR/kernel.txz" "$ISO_ROOT/usr/freebsd-dist/kernel.txz"
tar -C "$ROOTFS" -cJpf "$ISO_ROOT/usr/freebsd-dist/rebuilt-unix-rootfs.txz" .

printf '%s\n' '[6/7] Fetching matching FreeBSD 15.1 ISO tooling...'
# GitHub's archive endpoint may not provide a Content-Length header. The
# FreeBSD fetch utility treats that as an error, so use fetch's pipe mode via
# curl, which follows redirects and accepts chunked responses.
if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required to download the FreeBSD source archive" >&2
    exit 1
fi
curl -L --fail --retry 3 --retry-delay 2 -o "$WORK_DIR/freebsd-src.tar.gz" "$SRC_URL"
test -s "$WORK_DIR/freebsd-src.tar.gz"
mkdir -p "$WORK_DIR/src"
tar -xzf "$WORK_DIR/freebsd-src.tar.gz" -C "$WORK_DIR/src" --strip-components=1

MKISO="$WORK_DIR/src/release/amd64/mkisoimages.sh"
if [ ! -x "$MKISO" ]; then
    chmod +x "$MKISO"
fi

test -f "$WORK_DIR/src/tools/boot/install-boot.sh"
test -f "$WORK_DIR/src/release/scripts/tools.sh"

printf '%s\n' '[7/7] Creating the bootable ISO...'
rm -f "$ISO"
# mkisoimages.sh expects to be run from the FreeBSD source tree so its
# relative tools/ paths resolve correctly.
cd "$WORK_DIR/src/release/amd64"
sh "$MKISO" -b "REBUILT_UNIX_15_1_AMD64" "$ISO" "$ISO_ROOT"

if [ ! -s "$ISO" ]; then
    echo "ERROR: ISO was not created" >&2
    exit 1
fi

printf '\n%s\n' '========================================'
printf 'Created: %s\n' "$ISO"
printf 'Size:    %s\n' "$(du -h "$ISO" | awk '{print $1}')"
printf '%s\n' '========================================'
