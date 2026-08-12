#!/bin/sh
# Build a bootable Rebuilt Unix ISO from the official FreeBSD 15.1 release sets.
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
mkdir -p "$ROOTFS" "$ISO_ROOT/etc" "$ISO_ROOT/boot" "$ISO_ROOT/usr/freebsd-dist" "$ISO_ROOT/usr/local/sbin" "$ISO_ROOT/installer" "$OUTPUT"

printf '%s\n' '========================================' '       Rebuilt Unix ISO Builder' '========================================'
printf 'Target: %s %s\nArch:   %s\nOutput: %s\n\n' "$BASE_OS" "$BASE_VERSION" "$TARGET_ARCH" "$ISO"

printf '%s\n' '[1/8] Downloading official FreeBSD 15.1 release sets...'
fetch -o "$WORK_DIR/base.txz" "$BASE_URL"
fetch -o "$WORK_DIR/kernel.txz" "$KERNEL_URL"
test -s "$WORK_DIR/base.txz" && test -s "$WORK_DIR/kernel.txz"

printf '%s\n' '[2/8] Verifying release sets...'
tar -tzf "$WORK_DIR/base.txz" >/dev/null
tar -tzf "$WORK_DIR/kernel.txz" >/dev/null

printf '%s\n' '[3/8] Creating Rebuilt Unix root filesystem...'
tar -C "$ROOTFS" -xpf "$WORK_DIR/base.txz"
tar -C "$ROOTFS" -xpf "$WORK_DIR/kernel.txz"
mkdir -p "$ISO_ROOT/boot/kernel"
tar -xOf "$WORK_DIR/kernel.txz" ./boot/kernel/kernel > "$ISO_ROOT/boot/kernel/kernel"
chmod 0555 "$ISO_ROOT/boot/kernel/kernel"
test -s "$ISO_ROOT/boot/kernel/kernel"

printf '%s\n' '[4/8] Applying Rebuilt Unix branding and installer...'
mkdir -p "$ROOTFS/usr/local/share/backgrounds/rebuilt-unix"
cp "$REPO_ROOT/build/branding/wallpapers/rebuilt-unix.svg" "$ROOTFS/usr/local/share/backgrounds/rebuilt-unix/rebuilt-unix.svg"
cp "$REPO_ROOT/build/branding/system/os-release" "$ROOTFS/etc/rebuilt-unix-release"
cat > "$ROOTFS/etc/motd" <<'EOF'
Welcome to Rebuilt Unix.

A FreeBSD-based Unix system rebuilt our way.
Base: FreeBSD 15.1-RELEASE
Package manager: pkg
EOF
cat > "$ROOTFS/etc/issue" <<'EOF'
Rebuilt Unix - FreeBSD 15.1-RELEASE
EOF

INSTALLER_SRC="$REPO_ROOT/build/installer/install-rebuilt-unix.sh"
INSTALLER_ISO="$ISO_ROOT/installer/install-rebuilt-unix.sh"
INSTALLER_ROOT="$ROOTFS/usr/local/sbin/install-rebuilt-unix"
test -f "$INSTALLER_SRC"
mkdir -p "$ISO_ROOT/installer" "$ROOTFS/usr/local/sbin"
cp "$INSTALLER_SRC" "$INSTALLER_ISO"
cp "$INSTALLER_SRC" "$INSTALLER_ROOT"
chmod 0555 "$INSTALLER_ISO" "$INSTALLER_ROOT"
test -x "$INSTALLER_ISO" && test -x "$INSTALLER_ROOT"

printf '%s\n' '[5/8] Preparing FreeBSD release media and installer environment...'
cp "$WORK_DIR/base.txz" "$ISO_ROOT/usr/freebsd-dist/base.txz"
cp "$WORK_DIR/kernel.txz" "$ISO_ROOT/usr/freebsd-dist/kernel.txz"
tar -C "$ROOTFS" -cJpf "$ISO_ROOT/usr/freebsd-dist/rebuilt-unix-rootfs.txz" .

# FreeBSD 15.1 bootonly media does not contain the old standalone
# /boot/mfsroot.gz file. We use it for the official bootloader files,
# then create the live filesystem image ourselves.
fetch -o "$WORK_DIR/bootonly.iso" "$BOOTONLY_URL"
test -s "$WORK_DIR/bootonly.iso"
mkdir -p "$WORK_DIR/bootonly"
mdconfig -a -t vnode -f "$WORK_DIR/bootonly.iso" -u 10
mount_cd9660 /dev/md10 "$WORK_DIR/bootonly"

cp "$WORK_DIR/bootonly/boot/loader.efi" "$ISO_ROOT/boot/loader.efi"
cp "$WORK_DIR/bootonly/boot/loader" "$ISO_ROOT/boot/loader"
cp "$WORK_DIR/bootonly/boot/cdboot" "$ISO_ROOT/boot/cdboot"
for f in loader.4th menu.4th menu-commands.4th menusets.4th support.4th version.4th beastie.4th; do
    if [ -f "$WORK_DIR/bootonly/boot/$f" ]; then cp "$WORK_DIR/bootonly/boot/$f" "$ISO_ROOT/boot/$f"; fi
done
if [ -d "$WORK_DIR/bootonly/boot/lua" ]; then
    mkdir -p "$ISO_ROOT/boot/lua"
    cp -Rp "$WORK_DIR/bootonly/boot/lua/." "$ISO_ROOT/boot/lua/"
fi

umount "$WORK_DIR/bootonly"
mdconfig -d -u 10

# Create the live root filesystem used by the loader. The complete FreeBSD
# base+kernel root is just under 1 GiB uncompressed, so 2 GiB gives it safe
# headroom for the installer, branding, and future live-environment files.
mkdir -p "$ROOTFS/dev" "$ROOTFS/tmp" "$ROOTFS/var" "$ROOTFS/var/tmp"
chmod 1777 "$ROOTFS/tmp" "$ROOTFS/var/tmp"
makefs -t ffs -s 2g "$WORK_DIR/mfsroot" "$ROOTFS" >/dev/null
gzip -f "$WORK_DIR/mfsroot"
cp "$WORK_DIR/mfsroot.gz" "$ISO_ROOT/boot/mfsroot.gz"

test -s "$ISO_ROOT/boot/loader.efi"
test -s "$ISO_ROOT/boot/loader"
test -s "$ISO_ROOT/boot/cdboot"
test -s "$ISO_ROOT/boot/kernel/kernel"
test -s "$ISO_ROOT/boot/lua/loader.lua"
test -s "$ISO_ROOT/boot/mfsroot.gz"

cat > "$ISO_ROOT/boot/menu.rc" <<'EOF'
include /boot/menu.4th
include /boot/loader.4th
menu-init
set loader_menu_title="Rebuilt Unix"
set menu_caption[1]="Boot Rebuilt Unix"
set menu_command[1]="boot"
set menu_caption[2]="Install Rebuilt Unix"
set menu_command[2]="set mfsroot_load=YES; set mfsroot_type=md_image; set mfsroot_name=/boot/mfsroot.gz; boot-conf"
set menu_caption[3]="FreeBSD Installer / Recovery"
set menu_command[3]="set mfsroot_load=YES; set mfsroot_type=md_image; set mfsroot_name=/boot/mfsroot.gz; boot-conf"
set menu_options=3
set menu_timeout_command="boot"
menu-display
EOF
cat > "$ISO_ROOT/boot/loader.rc" <<'EOF'
include /boot/loader.4th
start
read-conf /boot/loader.conf
include /boot/menu.rc
EOF
cat > "$ISO_ROOT/boot/loader.conf" <<'EOF'
autoboot_delay="5"
loader_logo="none"
beastie_disable="YES"
kernel="/boot/kernel/kernel"
mfsroot_load="YES"
mfsroot_type="md_image"
mfsroot_name="/boot/mfsroot.gz"
EOF

cat > "$ISO_ROOT/etc/fstab" <<'EOF'
# Rebuilt Unix live/installer media
EOF
cat > "$ISO_ROOT/etc/group" <<'EOF'
wheel:*:0:root
operator:*:5:root
bin:*:7:
daemon:*:1:
kmem:*:2:
sys:*:3:
tty:*:4:
mail:*:6:
games:*:13:
news:*:8:
man:*:9:
network:*:69:
audio:*:44:
video:*:44:
EOF
cat > "$ISO_ROOT/etc/passwd" <<'EOF'
root:*:0:0:Charlie &:/root:/bin/sh
EOF
cat > "$ISO_ROOT/etc/master.passwd" <<'EOF'
root:*:0:0::0:0:Charlie &:/root:/bin/sh
EOF

printf '%s\n' '[6/8] Installing lightweight FreeBSD 15.1 ISO tooling...'
mkdir -p "$WORK_DIR/src/release/amd64" "$WORK_DIR/src/release/scripts" "$WORK_DIR/src/tools/boot"
fetch -o "$WORK_DIR/src/release/amd64/mkisoimages.sh" "$RAW_BASE/release/amd64/mkisoimages.sh"
fetch -o "$WORK_DIR/src/release/scripts/tools.subr" "$RAW_BASE/release/scripts/tools.subr"
fetch -o "$WORK_DIR/src/tools/boot/install-boot.sh" "$RAW_BASE/tools/boot/install-boot.sh"
chmod +x "$WORK_DIR/src/release/amd64/mkisoimages.sh" "$WORK_DIR/src/tools/boot/install-boot.sh"
for tool in makefs mkimg etdump; do
    if ! command -v "$tool" >/dev/null 2>&1; then echo "ERROR: required FreeBSD ISO tool '$tool' is unavailable" >&2; exit 1; fi
done

printf '%s\n' '[7/8] Creating the bootable ISO...'
rm -f "$ISO"
cd "$WORK_DIR/src/release/amd64"
sh "$WORK_DIR/src/release/amd64/mkisoimages.sh" -b "REBUILT_UNIX_15_1_AMD64" "$ISO" "$ISO_ROOT"
test -s "$ISO"
printf '%s\n' '[8/8] ISO validation complete.'
printf 'Created: %s\nSize: %s\n' "$ISO" "$(du -h "$ISO" | awk '{print $1}')"
