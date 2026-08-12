# Rebuilt Unix Live Boot

This directory defines the shared live-boot layout for Rebuilt Unix.

The live environment is designed to be reusable by both:

- the normal Rebuilt Unix live system
- the future graphical/text installer

The live environment should boot into a temporary filesystem without requiring installation to the target disk.

## Planned boot flow

```text
Firmware
  -> bootloader
  -> Rebuilt Unix live kernel
  -> init / rc system
  -> live root filesystem
  -> live services
  -> optional installer
```

The installer is intentionally separate from the live base so that the same bootable image can eventually provide both **Try Rebuilt Unix** and **Install Rebuilt Unix** options.

## Planned layout

- `config/` — live boot settings
- `rootfs/` — files copied into the live filesystem
- `installer/` — future installer integration point
- `scripts/` — live image assembly helpers
- `boot/` — bootloader configuration when implemented
