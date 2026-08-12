# Build System

This directory contains the Rebuilt Unix build system.

The build process is intended to produce a reproducible amd64 image based on FreeBSD 15.1-RELEASE.

## Layout

- `config/` — build configuration and release settings
- `scripts/` — build stages and helper scripts
- `packages/` — package lists and package configuration
- `rootfs/` — files installed into the target filesystem
- `output/` — generated images and build artifacts (not committed)
