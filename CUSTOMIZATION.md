# Ghostling Workflow Guide

`Ghostling Tools` adds a template-first cosmetic workflow on top of Aseprite.

## New Cosmetic Template

Open `File > New > New Ghostling Cosmetic...` to create a starter document.

The template gives you:
- a `3x3` grid
- the base Ghostling reference art
- `EXPORT Front` and `EXPORT Back` layers
- an `ANCHOR Mount` layer for the mount pixel

The base reference is aligned to the bottom of the canvas so extra space naturally grows upward.

## Drawing Rules

- Paint visible cosmetic art on `EXPORT Front` or `EXPORT Back`
- Keep the base reference layers untouched
- Place exactly one opaque pixel on `ANCHOR Mount`
- Leave the mount layer hidden when you are done

## Export

Open `File > Export > Export Ghostling Cosmetic Package...` to generate the package.

The exporter writes:
- `<name>-front.png`
- `<name>-back.png`
- `<name>.ghostling.json`

The JSON sidecar includes the anchor point and base reference bounds used by the cosmetic pipeline.

## Naming

New template tabs default to `New Ghostling - <Slot>` so each cosmetic type is easier to track while you work.

## Tips

- Keep the default canvas size unless the cosmetic needs extra room.
- If you expand the canvas, keep the cosmetic visually anchored against the bottom-aligned base.
- Use the home screen shortcuts in `Ghosted Hall` if you want to jump straight into a new cosmetic or reopen this guide.
