# LinePaycheck design assets

## Committed application logo

`brand/linepaycheck-icon-1024.png` is the 1024 × 1024 RGB PNG used by the iOS application. The same bytes are installed in `AppIcon.appiconset/AppIcon-1024.png` and `LinePaycheckLogo.imageset/LinePaycheckLogo.png`. `LineGapMark` now uses the bundled logo on the welcome and Pro screens. Technical bundle/product identifiers remain unchanged.

The generated source had a rounded outer square with white corners. The application derivative removes that baked-in outer mask, keeps the selected symbol, normalizes its palette, and uses an opaque full-bleed graphite field. iOS supplies the Home Screen mask. The original remains unmodified in the accompanying asset package.

## Full-resolution asset package: import required

The logo derivative is committed. The original generated logo and eight full-resolution generated screen images could not be transferred into this repository through the current working environment. They are provided in `linepaycheck-design-assets.zip` in the associated chat, together with eight correctly sized 1284 × 2778 PNG derivatives. Do not mistake this manifest for proof that every binary has already been committed.

After obtaining that package and pulling this commit into a clean checkout, run:

```bash
python3 scripts/import-design-assets.py /path/to/linepaycheck-design-assets.zip
```

The importer verifies every byte against `design-assets-manifest.json`, refuses conflicting existing files, and preserves identical files. It performs no network requests and does not commit or push. `--check` validates without writing. After reviewing the imported files, add/commit the `assets` directory and push normally.

Resulting layout:

```text
assets/
  brand/
    linepaycheck-icon-1024.png
    source/linepaycheck-generated.png
  app-stores/concepts/en-US/
    originals/       # Eight unchanged generated screen images, 853 × 1844
    1284x2778/       # Eight proportional resizes, tiny aspect padding, RGB PNG
  design-assets-manifest.json
```

There are nine unique generated originals: one logo and eight screens. No app-preview videos were generated. Duplicate chat attachments containing the identical logo are represented once.

## These screen images are concepts, not store captures

All eight screen images were generated as mockups, not captured from the running app. Their visual design and functionality have not been verified against the release candidate. In particular, some use a three-tab layout and the scan/history examples contain 2024 dates rather than the intended 2026 period. Resizing does not repair those discrepancies or establish App Store compliance.

Keep them under `concepts`; do not upload them as verified App Store screenshots. Produce final images from the running release-candidate UI with consistent synthetic data, accurate feature availability, and the disclosure rules in `docs/design/app-stores/screenshots.md`.

The archive preserves originals byte-for-byte. Derived screen images change only pixel dimensions/color-profile packaging, not UI wording or depicted functionality. Original and derivative hashes, dimensions, source mappings, and unapproved concept status are recorded in the manifest.
