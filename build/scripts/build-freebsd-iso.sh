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
FREEBSD_ISO_MIRROR="https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1"
BASE_URL="$FREEBSD_MIRROR/base.txz"
KERNEL_URL="$FREEBSD_MIRROR/kernel.txz"
BOOTONLY_URL="$FREEBSD_ISO_MIRROR/FreeBSD-15.1-RELEASE-amd64-bootonly.iso"
RAW_BASE="https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1"

rm -rf "$WORK_DIR"
mkdir -p "$ROOTFS" "$ISO_ROOT/etc" "$ISO_ROOT/boot" "$ISO_ROOT/usr/freebsd-dist" "$OUTPUT"

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

printf '%s\n' '[5/7] Preparing FreeBSD release media and boot files...'
cp "$WORK_DIR/base.txz" "$ISO_ROOT/usr/freebsd-dist/base.txz"
cp "$WORK_DIR/kernel.txz" "$ISO_ROOT/usr/freebsd-dist/kernel.txz"
tar -C "$ROOTFS" -cJpf "$ISO_ROOT/usr/freebsd-dist/rebuilt-unix-rootfs.txz" .

fetch -o "$WORK_DIR/bootonly.iso" "$BOOTONLY_URL"
test -s "$WORK_DIR/bootonly.iso"
mkdir -p "$WORK_DIR/bootonly"
mdconfig -a -t vnode -f "$WORK_DIR/bootonly.iso" -u 10
mount_cd9660 /dev/md10 "$WORK_DIR/bootonly"
mkdir -p "$ISO_ROOT/boot"
cp "$WORK_DIR/bootonly/boot/loader.efi" "$ISO_ROOT/boot/loader.efi"
cp "$WORK_DIR/bootonly/boot/loader" "$ISO_ROOT/boot/loader"
cp "$WORK_DIR/bootonly/boot/loader.rc" "$ISO_ROOT/boot/loader.rc" 2>/dev/null || true
umount "$WORK_DIR/bootonly"
mdconfig -d -u 10

# mkisoimages.sh writes /etc/fstab into the staging tree. Keep the staging
# root valid even though Rebuilt Unix's full installed rootfs is archived
# separately under /usr/freebsd-dist.
cat > "$ISO_ROOT/etc/fstab" <<'EOF'
# Rebuilt Unix live/installer media
# Filesystems are selected by the FreeBSD boot environment.
EOF

printf '%s\n' '[6/7] Installing lightweight FreeBSD 15.1 ISO tooling...'
mkdir -p "$WORK_DIR/src/release/amd64" \
         "$WORK_DIR/src/release/scripts" \
         "$WORK_DIR/src/tools/boot"

fetch -o "$WORK_DIR/src/release/amd64/mkisoimages.sh" \
  "$RAW_BASE/release/amd64/mkisoimages.sh"
fetch -o "$WORK_DIR/src/release/scripts/tools.subr" \
  "$RAW_BASE/release/scripts/tools.subr"
fetch -o "$WORK_DIR/src/tools/boot/install-boot.sh" \
  "$RAW_BASE/tools/boot/install-boot.sh"

chmod +x "$WORK_DIR/src/release/amd64/mkisoimages.sh" \
         "$WORK_DIR/src/tools/boot/install-boot.sh"

test -s "$WORK_DIR/src/release/amd64/mkisoimages.sh"
test -s "$WORK_DIR/src/release/scripts/tools.subr"
test -s "$WORK_DIR/src/tools/boot/install-boot.sh"

for tool in makefs mkimg etdump; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required FreeBSD ISO tool '$tool' is unavailable" >&2
        exit 1
    fi
done

printf '%s\n' '[7/7] Creating the bootable ISO...'
rm -f "$ISO"
cd "$WORK_DIR/src/release/amd64"
sh "$WORK_DIR/src/release/amd64/mkisoimages.sh" \
   -b "REBUILT_UNIX_15_1_AMD64" "$ISO" "$ISO_ROOT"

if [ ! -s "$ISO" ]; then
    echo "ERROR: ISO was not created" >&2
    exit 1
fi

printf '\n%s\n' '========================================'
printf 'Created: %s\n' "$ISO"
printf 'Size:    %s\n' "$(du -h "$ISO" | awk '{print $1}')"
printf '%s\n' '========================================'
