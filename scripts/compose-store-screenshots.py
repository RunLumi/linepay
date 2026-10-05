#!/usr/bin/env python3
"""Compose App Store screenshots from unedited simulator captures (docs/design/app-stores/screenshots.md).

Each export is one raw capture, proportionally scaled and placed on the porcelain canvas under a
headline, a caption and an optional qualifier. Pixels inside the capture are never edited. The
manifest records the source identity and SHA-256 of every raw capture and export so a reviewer can
trace each uploaded image (#27). Requires Pillow and macOS's SF Pro system font.

    python3 scripts/compose-store-screenshots.py RAW_DIR EXPORT_DIR \\
        --captions assets/store/source/captions-en-US.json --manifest MANIFEST.json \\
        --source-commit SHA --app-version 1.0.5 --build 11 --device "iPhone 11 Pro Max" --os "iOS 26.5"
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1284, 2778  # Apple's 6.5-inch portrait bucket
CANVAS = (0xF4, 0xF1, 0xE8)  # DESIGN.md canvas
TEXT = (0x13, 0x17, 0x1A)  # text.primary
SECONDARY = (0x5C, 0x64, 0x68)  # text.secondary
OXIDE = (0x0E, 0x74, 0x6C)  # action.fill
LINE = (0xD6, 0xD5, 0xCC)  # line.subtle
FONT = "/System/Library/Fonts/SFNS.ttf"
MAX_SHOT_WIDTH = 980
BOTTOM_MARGIN = 70


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT, size)
    face.set_variation_by_name(weight)
    return face


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = Image.new("RGBA", image.size)
    out.paste(image, (0, 0), mask)
    return out


def compose(raw: Path, frame: dict, dest: Path) -> tuple[int, int]:
    headline, caption, small = font(100, "Bold"), font(46, "Regular"), font(34, "Medium")
    shot = Image.open(raw).convert("RGB")
    canvas = Image.new("RGB", (W, H), CANVAS)
    draw = ImageDraw.Draw(canvas)

    y = 150
    box = draw.multiline_textbbox((W // 2, y), frame["headline"], font=headline, anchor="ma",
                                  align="center", spacing=14)
    draw.multiline_text((W // 2, y), frame["headline"], font=headline, fill=TEXT, anchor="ma",
                        align="center", spacing=14)
    y = box[3] + 40
    if frame.get("lineGap"):  # The Line Gap identity detail, first frame only (§6.3).
        draw.rectangle((W // 2 - 96, y, W // 2 - 10, y + 5), fill=OXIDE)
        draw.rectangle((W // 2 + 10, y, W // 2 + 96, y + 5), fill=OXIDE)
        y += 45
    else:
        y -= 10
    draw.text((W // 2, y), frame["caption"], font=caption, fill=SECONDARY, anchor="ma")
    box = draw.textbbox((W // 2, y), frame["caption"], font=caption, anchor="ma")
    if frame.get("qualifier"):
        draw.text((W // 2, box[3] + 26), frame["qualifier"], font=small, fill=SECONDARY, anchor="ma")
        box = draw.textbbox((W // 2, box[3] + 26), frame["qualifier"], font=small, anchor="ma")

    top = box[3] + 64
    scale = min((H - top - BOTTOM_MARGIN) / shot.height, MAX_SHOT_WIDTH / shot.width)
    size = round(shot.width * scale), round(shot.height * scale)
    window = rounded(shot.resize(size, Image.LANCZOS), 64)
    x = (W - size[0]) // 2
    border = Image.new("RGBA", (size[0] + 8, size[1] + 8), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (0, 0, size[0] + 7, size[1] + 7), 68, outline=LINE, width=4)
    canvas.paste(border, (x - 4, top - 4), border)
    canvas.paste(window, (x, top), window)
    canvas.save(dest, "PNG", optimize=True)
    return size


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("raw_dir", type=Path)
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--captions", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--app-version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--os", required=True)
    args = parser.parse_args()

    captions = json.loads(args.captions.read_text(encoding="utf-8"))
    args.export_dir.mkdir(parents=True, exist_ok=True)
    root = Path.cwd().resolve()
    images = []
    for frame in captions["frames"]:
        raw = args.raw_dir / frame["raw"]
        dest = args.export_dir / f"{frame['id']}.png"
        scaled = compose(raw, frame, dest)
        images.append({
            "id": frame["id"],
            "export": dest.resolve().relative_to(root).as_posix(),
            "exportSHA256": sha256(dest),
            "exportPixels": [W, H],
            "rawCapture": raw.resolve().relative_to(root).as_posix(),
            "rawSHA256": sha256(raw),
            "sourceCropPixels": None,
            "scaledCapturePixels": list(scaled),
            "headline": frame["headline"].replace("\n", " "),
            "caption": frame["caption"],
            "qualifier": frame.get("qualifier"),
            "productState": frame["productState"],
            "accessRequirement": frame["accessRequirement"],
        })
        print(f"{dest.name}: capture scaled to {scaled[0]}x{scaled[1]}")
    manifest = {
        "platform": "ios",
        "locale": "en-US",
        "displayType": "APP_IPHONE_65",
        "fixtureID": captions["fixtureID"],
        "captureTest": "LinePayUITests/PaydayJourneyTests/testStoreScreenshotsFromSamplePaycheck",
        "sourceCommit": args.source_commit,
        "appVersion": args.app_version,
        "buildNumber": args.build,
        "device": args.device,
        "osVersion": args.os,
        "appearance": "light",
        "payrollTimeZone": "America/Chicago",
        "images": images,
    }
    args.manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
