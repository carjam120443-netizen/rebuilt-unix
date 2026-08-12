#!/bin/sh
# Rebuilt Unix installer.
# Intended to run from the ISO/live environment as root.
# Installs the bundled Rebuilt Unix rootfs to a selected target disk.
set -eu

ROOTFS="/usr/freebsd-dist/rebuilt-unix-rootfs.txz"
TARGET="${1:-}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Install Rebuilt Unix must be run as root."
    exit 1
fi

if [ ! -f "$ROOTFS" ]; then
    echo "ERROR: Rebuilt Unix root filesystem is not present on this ISO."
    exit 1
fi

if [ -z "$TARGET" ]; then
    echo "Available disks:"
    geom disk list | awk '/^[^ ]+:/ {print $1}' | tr -d ':'
    echo
    printf "Target disk (for example ada0): "
    read -r TARGET
fi

case "$TARGET" in
    /dev/*) DISK="$TARGET" ;;
    *) DISK="/dev/$TARGET" ;;
esac

if [ ! -e "$DISK" ]; then
    echo "ERROR: $DISK does not exist."
    exit 1
fi

echo
printf '%s\n' "WARNING: this will erase $DISK and install Rebuilt Unix."
printf '%s' "Type INSTALL to continue: "
read -r CONFIRM
[ "$CONFIRM" = "INSTALL" ] || { echo "Installation cancelled."; exit 1; }

PART="${DISK}p2"
EFI="${DISK}p1"
MOUNT=/mnt/rebuilt-unix

# GPT: EFI system partition + UFS root partition.
gpart destroy -F "$DISK" 2>/dev/null || true
gpart create -s GPT "$DISK"
gpart add -a 1m -t efi -s 260m "$DISK"
gpart add -a 1m -t freebsd-ufs "$DISK"

newfs_msdos -F 32 -c 1 "$EFI"
newfs -U "$PART"

mkdir -p "$MOUNT"
mount "$PART" "$MOUNT"
mkdir -p "$MOUNT/boot/efi"
mount_msdosfs "$EFI" "$MOUNT/boot/efi"

# Restore the bundled system.
tar -xpf "$ROOTFS" -C "$MOUNT"

# Ensure the Rebuilt Unix branding survives installation.
mkdir -p "$MOUNT/etc"
cat > "$MOUNT/etc/motd" <<'EOF'
Welcome to Rebuilt Unix.

A FreeBSD-based Unix system rebuilt our way.
Package manager: pkg
EOF

cat > "$MOUNT/etc/fstab" <<EOF
$PART / ufs rw 1 1
$EFI /boot/efi msdosfs rw,noauto 0 0
EOF

# Install the release-matched FreeBSD bootloader when the boot tools are
# available in the live environment.
if [ -x /usr/libexec/bsdinstall/bootconfig ]; then
    /usr/libexec/bsdinstall/bootconfig "$DISK" "$MOUNT" || true
fi

sync
umount "$MOUNT/boot/efi" || true
umount "$MOUNT"

echo
printf '%s\n' 'Rebuilt Unix installation completed.'
printf '%s\n' 'Power off or reboot, remove the ISO, and boot from the installed disk.'
