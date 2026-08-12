#!/bin/sh
# Rebuilt Unix live filesystem preparation
# Base: FreeBSD 15.1-RELEASE / amd64

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIVE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=$(CDPATH= cd -- "$LIVE_DIR/../.." && pwd)
. "$LIVE_DIR/config/live.conf"

ROOTFS="$LIVE_DIR/rootfs"
mkdir -p "$ROOTFS" "$LIVE_DIR/boot"

echo "Preparing Rebuilt Unix live filesystem..."
echo "Base: $BASE_OS $BASE_VERSION"
echo "Architecture: $TARGET_ARCH"

echo

echo "This stage prepares the filesystem layout."
echo "The ISO builder will populate it from the FreeBSD release sets."

echo "Live environment: $LIVE_MODE"

echo "Installer enabled: $ENABLE_INSTALLER"

echo "Persistence: $PERSISTENCE"

echo

echo "Planned live packages: $LIVE_PACKAGES"

echo "Live filesystem preparation complete."
