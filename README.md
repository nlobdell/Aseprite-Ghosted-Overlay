# Ghosted Overlay for Aseprite

This repo is the public-safe companion to a private customized Aseprite checkout.

It contains:
- the bundled `Ghostling Tools` extension
- the `Ghosted` UI/theme patch for the home screen, tabs, theme palette, and dark-theme default
- the in-app Ghostling workflow guide
- a small PowerShell installer for applying the overlay to a licensed Aseprite source checkout

It does not contain:
- the full Aseprite source tree
- prebuilt binaries
- the private build/test repo history

## Install

1. Clone the official Aseprite source to a private/local folder.
2. From this overlay repo, run:

```powershell
.\scripts\install-overlay.ps1 -AsepriteRepoPath C:\path\to\your\aseprite
```

3. Rebuild Aseprite, or re-sync `data/` into your existing build output.

## What Gets Applied

- `extensions/ghostling-tools/` is copied into `data/extensions/ghostling-tools/`
- `CUSTOMIZATION.md` is copied into the Aseprite repo root so the home-screen guide button has a local guide to open
- `patches/ghosted-ui.patch` is applied to the Aseprite checkout

## Patch Scope

The patch currently updates:
- `data/extensions/aseprite-theme/theme.xml`
- `data/extensions/aseprite-theme/dark/theme.xml`
- `data/pref.xml`
- `data/strings/en.ini`
- `data/widgets/home_view.xml`
- `src/app/pref/preferences.cpp`
- `src/app/ui/home_view.cpp`
- `src/app/ui/home_view.h`
- `src/app/ui/status_bar.cpp`

## Notes

- Keep your full Aseprite checkout private unless you have reviewed the Aseprite license and are sure your use is allowed.
- This repo is meant to be the shareable layer you can move between clean local checkouts.
