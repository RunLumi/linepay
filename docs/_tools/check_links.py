#!/usr/bin/env python3
"""Check local Markdown link paths/anchors without accessing external services."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
LINK = re.compile(r"!?\[[^\]\n]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)")
REFERENCE = re.compile(r"^\s*\[[^]\n]+\]:\s*(<[^>]+>|\S+)", re.M)


def without_fences(text: str) -> str:
    output: list[str] = []
    fence: str | None = None
    for line in text.splitlines():
        match = FENCE.match(line)
        if match:
            token = match.group(1)[0]
            if fence is None:
                fence = token
            elif fence == token:
                fence = None
            output.append("")
        else:
            output.append(line if fence is None else "")
    return "\n".join(output)


def anchors(text: str) -> set[str]:
    found = set(re.findall(r'\b(?:id|name)=["\']([^"\']+)["\']', text))
    counts: dict[str, int] = {}
    for line in without_fences(text).splitlines():
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue
        label = re.sub(r"<[^>]*>", "", match.group(1))
        label = re.sub(r"\[([^]]+)\]\([^)]*\)", r"\1", label)
        slug = re.sub(r"[^\w\- ]", "", label.lower()).replace(" ", "-")
        n = counts.get(slug, 0)
        counts[slug] = n + 1
        found.add(slug if n == 0 else f"{slug}-{n}")
    return found


def check(root: Path) -> tuple[int, list[str]]:
    checked = 0
    errors: list[str] = []
    excluded = {".git", ".build", ".test-results", "node_modules", "DerivedData"}
    for source in sorted(root.rglob("*.md")):
        if excluded.intersection(source.relative_to(root).parts):
            continue
        body = without_fences(source.read_text(encoding="utf-8"))
        for match in list(LINK.finditer(body)) + list(REFERENCE.finditer(body)):
            url = match.group(1).strip("<>")
            parts = urlsplit(url)
            if parts.scheme or parts.netloc or url.startswith("//"):
                continue
            raw = unquote(parts.path)
            if not raw and not parts.fragment:
                continue
            checked += 1
            target = ((root / raw.lstrip("/")) if raw.startswith("/")
                      else source.parent / raw).resolve() if raw else source.resolve()
            line = body.count("\n", 0, match.start()) + 1
            location = f"{source.relative_to(root)}:{line}: {url}"
            if not target.is_relative_to(root):
                errors.append(f"Outside repository: {location}")
            elif not target.exists():
                errors.append(f"Missing path: {location}")
            elif parts.fragment and target.is_file() and target.suffix.lower() == ".md":
                fragment = unquote(parts.fragment)
                if fragment not in anchors(target.read_text(encoding="utf-8")):
                    errors.append(f"Missing anchor: {location}")
    return checked, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    count, errors = check(args.root.resolve())
    print(f"Checked {count} local Markdown links; {len(errors)} error(s).")
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
