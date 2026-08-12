#!/bin/sh
# Build a bootable Rebuilt Unix installer ISO.
# This script is intended to run inside a FreeBSD 15.1 build VM.

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$REPO_ROOT/build/config/release.conf"
. "$REPO_ROOT/build/config/build.conf"

WORK_DIR="${WORK_DIR:-/tmp/rebuilt-unix-build}"
MEDIA="$WORK_DIR/media"
ROOTFS="$WORK_DIR/rootfs"
SRC="$WORK_DIR/freebsd-src"
OUTPUT="$REPO_ROOT/build/output"
ISO="$OUTPUT/rebuilt-unix-${BASE_VERSION}-${TARGET_ARCH}.iso"

FREEBSD_ISO_URL="https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/FreeBSD-15.1-RELEASE-amd64-disc1.iso"
MKISO_URL="https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1/release/amd64/mkisoimages.sh"

rm -rf "$WORK_DIR"
mkdir -p "$MEDIA" "$ROOTFS" "$OUTPUT"

printf '%s\n' '========================================'
printf '%s\n' '       Rebuilt Unix ISO Builder'
printf '%s\n' '========================================'
printf 'Base: %s %s\n' "$BASE_OS" "$BASE_VERSION"
printf 'Arch: %s\n' "$TARGET_ARCH"
printf 'Output: %s\n' "$ISO"
printf '\n'

printf '%s\n' '[1/8] Downloading official FreeBSD 15.1 installer media...'
fetch -o "$WORK_DIR/freebsd-disc1.iso" "$FREEBSD_ISO_URL"

printf '%s\n' '[2/8] Extracting installer media...'
tar -C "$MEDIA" -xf "$WORK_DIR/freebsd-disc1.iso"

printf '%s\n' '[3/8] Preparing a target filesystem...'
tar -C "$ROOTFS" -xpf "$MEDIA/usr/freebsd-dist/base.txz"
tar -C "$ROOTFS" -xpf "$MEDIA/usr/freebsd-dist/kernel.txz"

printf '%s\n' '[4/8] Installing pkg and sudo into the target filesystem...'
mkdir -p "$ROOTFS/var/db/pkg" "$ROOTFS/var/cache/pkg"
pkg -r "$ROOTFS" bootstrap -y
pkg -r "$ROOTFS" install -y pkg sudo

printf '%s\n' '[5/8] Applying Rebuilt Unix system identity and branding...'
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

printf '%s\n' '[6/8] Creating a customized base distribution set...'
rm -f "$MEDIA/usr/freebsd-dist/base.txz"
tar -C "$ROOTFS" -cJpf "$MEDIA/usr/freebsd-dist/base.txz" .

printf '%s\n' '[7/8] Installing the FreeBSD release ISO builder...'
fetch -o "$WORK_DIR/mkisoimages.sh" "$MKISO_URL"
chmod +x "$WORK_DIR/mkisoimages.sh"

printf '%s\n' '[8/8] Creating the bootable ISO...'
rm -f "$ISO"
sh "$WORK_DIR/mkisoimages.sh" -b "REBUILT_UNIX_15_1_AMD64" "$ISO" "$MEDIA"

if [ ! -s "$ISO" ]; then
    echo "ERROR: ISO was not created" >&2
    exit 1
fi

printf '\n%s\n' '========================================'
printf 'Created: %s\n' "$ISO"
printf 'Size:    %s\n' "$(du -h "$ISO" | awk '{print $1}')"
printf '%s\n' '========================================'
