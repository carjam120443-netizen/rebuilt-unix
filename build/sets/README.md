# FreeBSD Release Sets

This directory documents the FreeBSD release sets used by the Rebuilt Unix builder.

The CI builder downloads release files into a temporary workspace instead of committing large binary sets to Git.

Expected sets:

- `base.txz` — FreeBSD base userland
- `kernel.txz` — FreeBSD kernel
- `lib32.txz` — optional 32-bit compatibility libraries
- `src.txz` — optional source tree (not required for the ISO)

The exact set list is controlled by the build scripts.
