#!/usr/bin/env python3
"""Verify or regenerate the transfer namespace from the pinned official tzdata archive.

Only identifier names are copied. No transitions, offsets, or host timezone files are used.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

RELEASE = "2026e"
ARCHIVE_URL = "https://data.iana.org/time-zones/releases/tzdata2026e.tar.gz"
ARCHIVE_SHA256 = "b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652"
# Makefile PRIMARY_YDATA + etcetera (YDATA), factory (NDATA), and backward.
# Optional PACKRATDATA/backzone is deliberately outside the v1 transfer namespace.
SOURCE_FILES = (
    "africa", "antarctica", "asia", "australasia", "europe", "northamerica",
    "southamerica", "etcetera", "factory", "backward",
)
EXPECTED_NAMES = 598
NAMESPACE_SHA256 = "8725722643bf1f4ff4fc4b22268ade98b6fae047a86897219c3a13d4c4ced93d"
SCHEMA_PATH = Path(__file__).with_name("schema-v1.json")


def names_from_source(text: str) -> set[str]:
    names: set[str] = set()
    for line in text.splitlines():
        fields = line.partition("#")[0].split()
        if not fields or fields[0] not in {"Zone", "Link"}:
            continue
        index = 1 if fields[0] == "Zone" else 2
        if len(fields) <= index:
            raise ValueError("Incomplete Zone/Link source record")
        name = fields[index]
        if not re.fullmatch(r"[A-Za-z0-9_+./-]+", name):
            raise ValueError("Unsupported timezone identifier spelling")
        names.add(name)
    return names


def names_from_archive(data: bytes) -> list[str]:
    if hashlib.sha256(data).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Archive SHA-256 differs from the pinned official IANA release")
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        def text(name: str) -> str:
            source = archive.extractfile(name)
            if source is None:
                raise ValueError("Missing pinned source: " + name)
            return source.read().decode("utf-8")

        if text("version").strip() != RELEASE:
            raise ValueError("Unexpected IANA release version")
        if "all files in the tz code and data" not in text("LICENSE"):
            raise ValueError("Review upstream license before updating provenance")
        names = set().union(*(names_from_source(text(name)) for name in SOURCE_FILES))
    if len(names) != EXPECTED_NAMES:
        raise ValueError("Pinned namespace size changed; inspect the source selection")
    result = sorted(names)
    if hashlib.sha256(("\n".join(result) + "\n").encode("ascii")).hexdigest() != NAMESPACE_SHA256:
        raise ValueError("Pinned timezone names differ; review upstream provenance")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Downloaded official tzdata2026e.tar.gz")
    parser.add_argument("--write", action="store_true", help="Replace only the schema timezone enum")
    args = parser.parse_args()
    names = names_from_archive(args.archive.read_bytes())
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    definition = schema["$defs"]["timeZone"]
    if args.write:
        definition["enum"] = names
        SCHEMA_PATH.write_text(json.dumps(schema, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    elif definition.get("enum") != names:
        raise SystemExit("FAIL: schema timezone enum differs from pinned source; review then use --write")
    print(f"PASS: {len(names)} exact-case timezone names from IANA {RELEASE}; archive {ARCHIVE_SHA256}")


if __name__ == "__main__":
    main()
