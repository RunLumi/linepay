"""Fail when a guide-relevant app source changed since the guides were last reviewed (#64).

`user-guide/source-review.json` records, for each tracked app source, the git blob SHA it had
when the mapped guides were last reviewed. A tracked file whose current blob differs is stale
unless the record is updated: either the mapped guides were re-reviewed (`reviewed`), or the
change was judged to alter no public instruction (`reviewed-no-guide-change` with a reason).
Unrelated files are never tracked, so ordinary development does not trip this check. Stdlib only.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

GUIDE = Path(__file__).resolve().parents[1]
ROOT = GUIDE.parent
RECORD = GUIDE / "source-review.json"
DISPOSITIONS = {"reviewed", "reviewed-no-guide-change"}


def blob(path: Path) -> str:
    """The git blob SHA of the working-tree file, independent of commit or checkout state."""
    return subprocess.check_output(
        ["git", "hash-object", "--", str(path)], cwd=ROOT, text=True).strip()


def problems(record: dict, root: Path = ROOT, guide: Path = GUIDE, hash_of=blob) -> list[str]:
    errors: list[str] = []
    if not record.get("reviewedOn") or not record.get("appVersion"):
        errors.append("source-review.json needs reviewedOn and appVersion")
    sources = record.get("sources", [])
    if not sources:
        errors.append("source-review.json tracks no sources")
    for entry in sources:
        path = entry.get("path", "")
        source = root / path
        if not path or not source.is_file():
            errors.append(f"{path or '<missing path>'}: tracked source does not exist")
            continue
        guides = entry.get("guides", [])
        if not guides:
            errors.append(f"{path}: maps to no guide")
        for page in guides:
            if not (guide / "content" / f"{page}.md").is_file():
                errors.append(f"{path}: mapped guide content/{page}.md does not exist")
        disposition = entry.get("disposition")
        if disposition not in DISPOSITIONS:
            errors.append(f"{path}: disposition must be one of {sorted(DISPOSITIONS)}")
        if disposition == "reviewed-no-guide-change" and not entry.get("reason", "").strip():
            errors.append(f"{path}: reviewed-no-guide-change needs a reason")
        if entry.get("blob") != hash_of(source):
            errors.append(
                f"{path} changed since the guide review ({', '.join(guides)}). Re-review those "
                "guides, then run `python3 user-guide/scripts/check-freshness.py --record` "
                "(or mark it reviewed-no-guide-change with a reason).")
    return errors


def record_current(record: dict) -> dict:
    """Refresh every tracked blob after a review. Run only once the mapped guides are checked."""
    for entry in record["sources"]:
        entry["blob"] = blob(ROOT / entry["path"])
    return record


def main(argv: list[str]) -> int:
    record = json.loads(RECORD.read_text(encoding="utf-8"))
    if argv[1:] == ["--record"]:
        RECORD.write_text(json.dumps(record_current(record), indent=2) + "\n", encoding="utf-8")
        print(f"Recorded {len(record['sources'])} reviewed source blobs.")
        return 0
    errors = problems(record)
    if errors:
        print("Guide freshness check failed:", *errors, sep="\n- ", file=sys.stderr)
        return 1
    print(f"PASS: {len(record['sources'])} guide-relevant sources match the "
          f"{record['reviewedOn']} review (LinePaycheck {record['appVersion']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
