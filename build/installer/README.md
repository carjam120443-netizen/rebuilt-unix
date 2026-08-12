# Rebuilt Unix Installer

The installer is shared by the live ISO and the installed system workflow.

Planned components:

- `config/` — installer defaults and partitioning policy
- `scripts/` — installer stages
- `assets/` — installer artwork and resources
- `templates/` — generated system configuration templates

The installer must never modify a host filesystem during CI builds; it operates on the selected target disk when launched from the live environment.
