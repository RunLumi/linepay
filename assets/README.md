# LinePaycheck design assets

## Committed application logo

`brand/linepaycheck-icon-1024.png` is the 1024 × 1024 RGB PNG used by the iOS application. The same bytes are installed in `AppIcon.appiconset/AppIcon-1024.png` and `LinePaycheckLogo.imageset/LinePaycheckLogo.png`. `LineGapMark` uses the bundled `LinePaycheckLogo` image on the welcome and Pro screens. Technical bundle/product identifiers remain unchanged.

The generated source had a rounded outer square with white corners. The application derivative removes that baked-in outer mask, keeps the selected symbol, normalizes its palette, and uses an opaque full-bleed graphite field. iOS supplies the Home Screen mask. The original remains unmodified in the accompanying asset package.

## Full-resolution asset package: import still required

**The application logo is committed. The other 17 PNG files are packaged but have not been pushed to this repository.** A manifest entry does not establish that the corresponding binary is present.

Use **`linepaycheck-design-assets-v2.zip`** from the associated chat. It contains the original generated logo, all eight unchanged generated screen images, eight dimension-normalized 1284 × 2778 screen derivatives, and copies of the three already-committed logo files. The three logo copies are identical to the files in this repository; the importer preserves them.

Package details:

- Archive bytes: `28212580`
- Archive SHA-256: `f8a339dfa7cd0faa8982b4359dc0d4b5e197e44754a397130d693e3ac929971c`
- Manifest format version: `1`; package revision: `2`
- Contents: 20 PNGs and the exact matching `assets/design-assets-manifest.json`
- Expected additions to the current checkout: 17 PNGs
- No app-preview videos were generated.

Revision 2 preserves every original and the committed icon. The resized images use explicit PNG sRGB metadata and proportional LANCZOS scaling to 1284 × 2776, with one pixel of padding above and below. Their hashes differ from the previous package specification. **Pull the matching manifest and use the v2 archive together; do not mix package revisions.**

### Import and publish from your local checkout

Save the ZIP in your Downloads folder, then run these commands from the repository root. Adjust the ZIP path if needed. Begin with a clean working tree; inspect `git status` before proceeding.

```bash
git pull --ff-only
python3 scripts/import-design-assets.py "$HOME/Downloads/linepaycheck-design-assets-v2.zip" --check
python3 scripts/import-design-assets.py "$HOME/Downloads/linepaycheck-design-assets-v2.zip"
git add assets/brand/source assets/app-stores/concepts
git diff --cached --stat
git commit -m "assets: add generated logo source and screenshot concepts"
git push
```

The importer verifies the full archive against `design-assets-manifest.json` before writing. It refuses conflicting existing files, preserves identical files, and performs no network requests. `--check` validates without writing. Only the explicit `git commit` and `git push` commands publish the imported assets.

A local verification run for revision 2 passed: dry-run without writes, 17-file import with the three existing icons preserved, repeated import adding zero files, all image dimensions/modes/hashes, refusal to overwrite a modified existing file, and rejection of a mismatched archive manifest. This checks packaging/import behavior, not a native iOS build or screenshot fidelity.

Resulting layout after import:

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

There are nine unique generated originals: one logo and eight screens. Duplicate chat attachments containing the identical logo are represented once.

## These screen images are concepts, not store captures

All eight screen images were generated as mockups, not captured from the running app. Their visual design and functionality have not been verified against the release candidate. In particular, some use a three-tab layout and the scan/history examples contain 2024 dates rather than the intended 2026 period. Resizing does not repair those discrepancies or establish App Store compliance.

Keep them under `concepts`; do not upload them as verified App Store screenshots. Produce final images from the running release-candidate UI with consistent synthetic data, accurate feature availability, and the disclosure rules in `docs/design/app-stores/screenshots.md`.

The archive preserves originals byte-for-byte. Derived screen images change only pixel dimensions/color-profile packaging, not UI wording or depicted functionality. Original and derivative hashes, dimensions, source mappings, and unapproved concept status are recorded in the manifest.
