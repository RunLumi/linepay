"""Every help screenshot is a real, provenance-recorded capture that a guide actually uses (#65).

Checks `data/screenshots.json` against `assets/screenshots/*.png` and the `screenshot` shortcode
calls in `content/`. Concept art and marketing captures live elsewhere and are never accepted
here. Stdlib only.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

GUIDE = Path(__file__).resolve().parents[1]
REQUIRED = ("guide", "alt", "caption", "appVersion", "appCommit", "build", "ios", "device",
            "appearance", "textSize", "locale", "fixture", "source", "capturedOn")
CALL = re.compile(r'\{\{<\s*screenshot\s+"([^"]+)"\s*>\}\}')


def problems(guide: Path = GUIDE) -> list[str]:
    errors: list[str] = []
    data = json.loads((guide / "data" / "screenshots.json").read_text(encoding="utf-8"))
    images = {p.stem for p in (guide / "assets" / "screenshots").glob("*.png")}
    used: dict[str, set[str]] = {}
    for page in (guide / "content").glob("*.md"):
        for name in CALL.findall(page.read_text(encoding="utf-8")):
            used.setdefault(name, set()).add(page.stem)
    for name, meta in data.items():
        missing = [key for key in REQUIRED if not str(meta.get(key, "")).strip()]
        if missing:
            errors.append(f"{name}: missing provenance {', '.join(missing)}")
        if len(str(meta.get("alt", ""))) < 40:
            errors.append(f"{name}: alt text must describe the task and state, not just the screen")
        if "synthetic" not in str(meta.get("fixture", "")).lower():
            errors.append(f"{name}: fixture must be synthetic data")
        if name not in images:
            errors.append(f"{name}: no assets/screenshots/{name}.png")
        if name not in used:
            errors.append(f"{name}: not used by any guide")
        elif meta.get("guide") not in used[name]:
            errors.append(f"{name}: recorded for {meta.get('guide')} but used in {sorted(used[name])}")
    for name in images - data.keys():
        errors.append(f"assets/screenshots/{name}.png has no provenance entry")
    for name in used.keys() - data.keys():
        errors.append(f"screenshot {name!r} is used but has no provenance entry")
    return errors


def main() -> int:
    errors = problems()
    if errors:
        print("Screenshot check failed:", *errors, sep="\n- ", file=sys.stderr)
        return 1
    count = len(json.loads((GUIDE / "data" / "screenshots.json").read_text(encoding="utf-8")))
    print(f"PASS: {count} help screenshots have complete provenance and are used by their guides")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
