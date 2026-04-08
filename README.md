# Ghosted Overlay for Aseprite

Ghosted Overlay is the shareable companion repo for a private customized Aseprite checkout.

It packages the Ghosted visual layer and Ghostling cosmetic workflow without shipping a full Aseprite source tree or any binaries.

## Included

- `Ghostling Tools`, a bundled extension for Ghostling cosmetic templates and exports
- the Ghosted UI/theme patch for tabs, home view, palette styling, and dark-theme defaults
- the in-app Ghostling workflow guide
- a PowerShell installer that applies the overlay to your own licensed Aseprite checkout

## Not Included

- a full Aseprite source checkout
- redistributable Aseprite binaries
- build outputs from the private working repo

## Quick Install

1. Clone the official Aseprite source into your own private/local workspace.
2. Run the installer from this repo:

```powershell
.\scripts\install-overlay.ps1 -AsepriteRepoPath C:\path\to\your\aseprite
```

3. Rebuild Aseprite, or resync the `data/` directory into your existing build output.

## What The Installer Does

- copies `extensions/ghostling-tools/` into `data/extensions/ghostling-tools/`
- copies `CUSTOMIZATION.md` into the Aseprite repo root so the home-screen guide button opens a local file
- applies `patches/ghosted-ui.patch` to your checkout

## Patch Coverage

The current patch touches:

- `data/extensions/aseprite-theme/theme.xml`
- `data/extensions/aseprite-theme/dark/theme.xml`
- `data/pref.xml`
- `data/strings/en.ini`
- `data/widgets/home_view.xml`
- `src/app/pref/preferences.cpp`
- `src/app/ui/home_view.cpp`
- `src/app/ui/home_view.h`
- `src/app/ui/status_bar.cpp`

## Public-Safety Notes

- This repo is meant to stay on the overlay side of the line: your original extension/assets/docs plus an apply-on-top patch for your own checkout.
- Aseprite itself is not redistributed here. Review the Aseprite license before sharing anything beyond this overlay repo.
- See [NOTICE.md](NOTICE.md) for the usage boundary and [LICENSE](LICENSE) for the original overlay files in this repo.
