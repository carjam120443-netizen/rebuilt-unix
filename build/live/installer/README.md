# Rebuilt Unix Installer Integration

This directory is reserved for the installer that will eventually run from the shared live environment.

The installer should be launched from the live system and install the same Rebuilt Unix base that the main image is built from.

Planned entry point:

```text
/usr/local/lib/rebuilt-unix/installer/rebuilt-installer
```

Keeping the installer under `build/live/installer/` lets the live boot environment and the installed system share the same base configuration without making the installer itself part of the installed runtime by default.
