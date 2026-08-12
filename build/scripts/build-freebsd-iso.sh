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
MKISO_URL="https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1/release/amd64/mkisoimages.sh"

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

printf '%s\n' '[2/7] Verifying release sets...'
fetch -o "$WORK_DIR/CHECKSUM.SHA256" "$FREEBSD_MIRROR/CHECKSUM.SHA256"
if grep -q "base.txz" "$WORK_DIR/CHECKSUM.SHA256"; then
    grep 'base.txz' "$WORK_DIR/CHECKSUM.SHA256" | sha256 -c - >/dev/null
fi
if grep -q "kernel.txz" "$WORK_DIR/CHECKSUM.SHA256"; then
    grep 'kernel.txz' "$WORK_DIR/CHECKSUM.SHA256" | sha256 -c - >/dev/null
fi

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

# Keep the original release metadata available to the installer.
fetch -o "$ISO_ROOT/usr/freebsd-dist/CHECKSUM.SHA256" "$FREEBSD_MIRROR/CHECKSUM.SHA256"

# Add the customized filesystem as an additional release set for the
# Rebuilt Unix installer/live environment. The installed system remains
# FreeBSD-derived; no Linux distribution is used as a target base.
tar -C "$ROOTFS" -cJpf "$ISO_ROOT/usr/freebsd-dist/rebuilt-unix-rootfs.txz" .

printf '%s\n' '[6/7] Installing the FreeBSD ISO builder...'
fetch -o "$WORK_DIR/mkisoimages.sh" "$MKISO_URL"
chmod +x "$WORK_DIR/mkisoimages.sh"

printf '%s\n' '[7/7] Creating the bootable ISO...'
rm -f "$ISO"
sh "$WORK_DIR/mkisoimages.sh" -b "REBUILT_UNIX_15_1_AMD64" "$ISO" "$ISO_ROOT"

if [ ! -s "$ISO" ]; then
    echo "ERROR: ISO was not created" >&2
    exit 1
fi

printf '\n%s\n' '========================================'
printf 'Created: %s\n' "$ISO"
printf 'Size:    %s\n' "$(du -h "$ISO" | awk '{print $1}')"
printf '%s\n' '========================================'
