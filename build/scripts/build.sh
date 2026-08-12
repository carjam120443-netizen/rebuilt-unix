#!/bin/sh
# Rebuilt Unix image builder
# Base: FreeBSD 15.1-RELEASE
# Target: amd64

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONFIG="$BUILD_DIR/config/release.conf"
OUTPUT_DIR="$BUILD_DIR/output"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: build configuration not found: $CONFIG" >&2
    exit 1
fi

. "$CONFIG"

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "        Rebuilt Unix Build System"
echo "========================================"
echo "Base OS:     $BASE_OS $BASE_VERSION"
echo "Architecture: $TARGET_ARCH"
echo "Packages:    $PACKAGES"
echo "Output:      $OUTPUT_DIR"
echo

echo "Build stages are not implemented yet."
echo "The next stage will acquire the FreeBSD base system"
echo "and assemble the target filesystem before creating an ISO."
echo

echo "Configuration loaded successfully."
