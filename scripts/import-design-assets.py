#!/usr/bin/env python3
"""Import the reviewed LinePaycheck artwork ZIP without overwriting changed files."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

MANIFEST = "assets/design-assets-manifest.json"


def import_assets(root: Path, archive_path: Path, check_only: bool = False) -> int:
    manifest_bytes = (root / MANIFEST).read_bytes()
    manifest = json.loads(manifest_bytes)
    if manifest.get("version") != 1 or manifest.get("repository") != "streamentry/linepay":
        raise ValueError("This is not the expected LinePaycheck artwork manifest.")
    entries = manifest["files"]
    expected = {item["path"] for item in entries}
    if len(expected) != len(entries):
        raise ValueError("Duplicate paths in the checked-in manifest.")
    total_size = sum(item["bytes"] for item in entries)
    if total_size > 64 * 1024 * 1024:
        raise ValueError("Artwork package exceeds the expected size budget.")
    pending = []
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != expected | {MANIFEST}:
            raise ValueError("ZIP file list does not match the checked-in manifest.")
        if archive.getinfo(MANIFEST).file_size != len(manifest_bytes):
            raise ValueError("Archive manifest has an unexpected size.")
        if archive.read(MANIFEST) != manifest_bytes:
            raise ValueError("Archive manifest differs from the reviewed repository manifest.")
        # Verify the entire package before writing anything.
        for item in entries:
            relative = PurePosixPath(item["path"])
            if relative.is_absolute() or ".." in relative.parts or relative.suffix != ".png":
                raise ValueError(f"Unsafe asset path: {relative}")
            target = root.joinpath(*relative.parts)
            if target.is_symlink() or not target.resolve().is_relative_to(root.resolve()):
                raise ValueError(f"Unsafe asset destination: {relative}")
            info = archive.getinfo(item["path"])
            if info.file_size != item["bytes"]:
                raise ValueError(f"Unexpected size: {relative}")
            data = archive.read(info)
            if hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError(f"Checksum mismatch: {relative}")
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"Not a PNG: {relative}")
            if target.exists():
                if target.read_bytes() != data:
                    raise ValueError(f"Refusing to replace a different existing file: {relative}")
            else:
                pending.append((target, data))
    if not check_only:
        for target, data in pending:
            target.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive creation protects unrelated files that appear after validation.
            with target.open("xb") as output:
                output.write(data)
    print(f"Verified {len(entries)} PNGs; {len(pending)} "
          + ("would be added." if check_only else "added. Existing identical files preserved."))
    print("Screen images remain design concepts, not verified App Store captures.")
    return len(pending)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Path to linepaycheck-design-assets.zip")
    parser.add_argument("--check", action="store_true", help="Validate without writing files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if not (root / "apps/ios/project.yml").is_file():
        parser.error("Run the copy of this script inside the LinePaycheck repository.")
    try:
        import_assets(root, args.archive.expanduser(), args.check)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"Import failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
