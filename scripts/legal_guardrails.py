#!/usr/bin/env python3
"""Offline release-evidence and active-copy checks. Consistency is not legal clearance.

Ordinary CI runs `check`. `release` additionally needs real, owner-reviewed evidence
outside this repository. The program never obtains approvals, calls Apple, or publishes.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import sys
import zipfile

FINDING_IDS = tuple(f"LEGAL-{number:02}" for number in range(1, 22))
PRODUCT_IDS = ("linepay.pro.monthly", "linepay.pro.yearly")
BUNDLE_ID = "com.streamentry.linepay"
PAGES = ("https://linepaycheck.com/privacy", "https://linepaycheck.com/support")
MAX_EVIDENCE_BYTES = 5 * 1024 * 1024
SHA = re.compile(r"[0-9a-f]{40}\Z")
DIGEST = re.compile(r"[0-9a-f]{64}\Z")
PLACEHOLDER = re.compile(r"^(?:tbd|todo|unknown|pending|n/?a|example|replace.*|<.*>)$", re.I)
COPY_PATHS = (
    "docs/pricing.md", "docs/marketing.md", "docs/appstore.md",
    "docs/product/pricing.md", "docs/growth/marketing.md", "docs/release/appstore.md",
)
INVENTORY_PATH = "docs/legal/inventory.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_json(path):
    path = Path(path)
    if path.stat().st_size > MAX_EVIDENCE_BYTES:
        raise ValueError("Evidence JSON is too large.")

    return strict_json(path.read_bytes())


def strict_json(data):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("Duplicate JSON field; approval is ambiguous.")
            value[key] = item
        return value
    return json.loads(data, object_pairs_hook=unique)


def meaningful(value):
    return isinstance(value, str) and len(value.strip()) >= 3 and not PLACEHOLDER.fullmatch(value.strip())


def validate_evidence(data, evidence_directory, expected_source, stage, now=None):
    """Validate evidence shape, freshness, file bytes and identity; never manufacture attestations."""
    errors = []
    root = Path(evidence_directory).resolve()
    now = now or datetime.now(timezone.utc)
    if not isinstance(data, dict):
        return ["Evidence must be an object."]
    if stage not in ("submission", "distribution"):
        return ["Unknown release stage."]
    if not isinstance(expected_source, str) or not SHA.fullmatch(expected_source):
        return ["A full source commit SHA is required."]

    def require(condition, message):
        if not condition:
            errors.append(message)

    def obj(value, label):
        if not isinstance(value, dict):
            errors.append(label + " must be an object.")
            return {}
        return value

    def fresh(value, label, maximum=timedelta(days=7)):
        try:
            if not isinstance(value, str):
                raise ValueError()
            date = datetime.fromisoformat(value.replace("Z", "+00:00"))
            if date.tzinfo is None or not timedelta(0) <= now - date <= maximum:
                raise ValueError()
        except (ValueError, TypeError, OverflowError):
            errors.append(label + " needs a fresh, timezone-qualified, non-future timestamp.")

    def reference(value, label):
        item = obj(value, label)
        path, checksum = item.get("path"), item.get("sha256")
        try:
            if not isinstance(path, str) or not path or "\\" in path:
                raise ValueError()
            rel = PurePosixPath(path)
            if rel.is_absolute() or any(p in (".", "..") for p in path.split("/")):
                raise ValueError()
            candidate = root.joinpath(*rel.parts)
            cursor = root
            for component in rel.parts:
                cursor = cursor / component
                if cursor.is_symlink():
                    raise ValueError()
            if not candidate.is_file() or not candidate.resolve().is_relative_to(root):
                raise ValueError()
            if not isinstance(checksum, str) or not DIGEST.fullmatch(checksum):
                raise ValueError()
            if candidate.stat().st_size > 1024 * 1024 * 1024 or sha256_file(candidate) != checksum:
                raise ValueError()
            return candidate
        except (OSError, ValueError):
            errors.append(label + " has missing, unsafe or checksum-mismatched evidence.")
            return None

    require(type(data.get("schema_version")) is int and data.get("schema_version") == 1,
            "Unsupported evidence schema.")
    require(data.get("record_kind") == "release-evidence", "Templates are not release approvals.")
    require(data.get("stage") in (stage, "distribution"), "Evidence does not authorize this stage.")
    require(data.get("source_sha") == expected_source, "Root approval is for a different source commit.")
    require(meaningful(data.get("release_owner")), "Identify the approving release owner.")
    fresh(data.get("reviewed_at"), "Release review")
    app = obj(data.get("app"), "App identity")
    require(app.get("source_sha") == expected_source, "Source-to-build mapping is missing or stale.")
    require(app.get("bundle_id") == BUNDLE_ID, "Bundle identity does not match LinePaycheck.")
    for key in ("version", "build", "apple_build_id"):
        require(isinstance(app.get(key), str) and bool(app.get(key))
                and not PLACEHOLDER.fullmatch(app[key]), "App identity is missing " + key + ".")
    binary = reference(data.get("binary"), "Candidate IPA")
    if binary:
        try:
            with zipfile.ZipFile(binary) as archive:
                files = [item for item in archive.infolist()
                         if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", item.filename)]
                if len(files) != 1 or files[0].file_size > 1024 * 1024:
                    raise ValueError()
                info = plistlib.loads(archive.read(files[0]))
                if not isinstance(info, dict):
                    raise ValueError()
                for field, key in (("CFBundleIdentifier", "bundle_id"),
                                   ("CFBundleShortVersionString", "version"), ("CFBundleVersion", "build")):
                    require(info.get(field) == app.get(key), "Actual IPA differs from declared " + key + ".")
        except (OSError, ValueError, KeyError, RuntimeError, zipfile.BadZipFile, plistlib.InvalidFileException):
            errors.append("Candidate IPA identity could not be read safely.")

    store = obj(data.get("storefront"), "Storefront")
    fresh(store.get("checked_at"), "Live storefront readback", timedelta(hours=24))
    require(store.get("release_mode") == "MANUAL", "This remediation release requires manual release control.")
    require(store.get("territories") == ["USA"], "New territory needs an explicit scope/policy revision.")
    require(store.get("apple_build_id") == app.get("apple_build_id"), "Selected Apple build differs from candidate.")
    reference(store.get("readback"), "Storefront readback")
    products = store.get("subscriptions")
    if not isinstance(products, list) or not all(isinstance(x, dict) for x in products):
        products = []
    product_ids = [x.get("product_id") for x in products if isinstance(x.get("product_id"), str)]
    require(len(products) == len(PRODUCT_IDS) and len(product_ids) == len(products)
            and set(product_ids) == set(PRODUCT_IDS),
            "Both existing subscription products must be represented exactly once.")
    allowed = {"APPROVED"} if stage == "distribution" else {"APPROVED", "READY_TO_SUBMIT", "WAITING_FOR_REVIEW"}
    require(all(isinstance(x.get("status"), str) and x["status"] in allowed for x in products), "Subscription status is not valid for this stage.")
    publisher = obj(data.get("publisher"), "Publisher")
    for field in ("legal_entity", "contact"):
        require(meaningful(publisher.get(field)), "Publisher needs an approved " + field + ".")
    require(publisher.get("privacy_url") == PAGES[0] and publisher.get("support_url") == PAGES[1],
            "Published destinations differ from the app's approved links.")
    pages = data.get("pages")
    if not isinstance(pages, list) or not all(isinstance(x, dict) for x in pages):
        pages = []
    page_urls = [x.get("url") for x in pages if isinstance(x.get("url"), str)]
    require(len(pages) == 2 and len(page_urls) == 2 and set(page_urls) == set(PAGES), "Both live policy/support snapshots are required.")
    for page in pages:
        fresh(page.get("checked_at"), "Published page", timedelta(hours=24))
        require(meaningful(page.get("reviewer")), "Page content needs an attributable review.")
        reference(page.get("snapshot"), "Published page snapshot")
    screenshots = data.get("screenshots")
    if not isinstance(screenshots, list) or not screenshots:
        errors.append("Release-candidate screenshots are required; concepts cannot substitute.")
        screenshots = []
    for index, raw in enumerate(screenshots):
        image = obj(raw, "Screenshot")
        require(image.get("kind") == "release-capture", "Concepts are not release screenshots.")
        require(image.get("source_sha") == expected_source and image.get("apple_build_id") == app.get("apple_build_id"),
                "Screenshot does not describe the candidate build.")
        path = reference(image, f"Screenshot {index + 1}")
        if path:
            with path.open("rb") as stream:
                require(stream.read(8) == b"\x89PNG\r\n\x1a\n", "Screenshot must be a reviewed PNG capture.")
    findings = obj(data.get("findings"), "Finding approvals")
    require(set(findings) == set(FINDING_IDS), "Review all 21 findings; unknown IDs do not count.")
    for identifier in FINDING_IDS:
        item = obj(findings.get(identifier), identifier)
        allowed_status = {"approved", "not-applicable"} if identifier in ("LEGAL-14", "LEGAL-21") else {"approved"}
        require(isinstance(item.get("status"), str) and item["status"] in allowed_status, identifier + " is not approved for this release.")
        require(meaningful(item.get("reviewer")) and meaningful(item.get("rationale")),
                identifier + " needs a real reviewer and written rationale.")
        require(item.get("source_sha") == expected_source, identifier + " review is source-mismatched.")
        fresh(item.get("reviewed_at"), identifier)
        refs = item.get("evidence")
        if not isinstance(refs, list) or not refs:
            errors.append(identifier + " needs actual retained evidence.")
            refs = []
        for ref in refs:
            reference(ref, identifier)
    return list(dict.fromkeys(errors))


def copy_violations(text):
    violations = []
    for phrase in re.split(r'[\n"]|(?<=[.!?])\s+', text):
        lower = " ".join(phrase.lower().split())
        if re.search(r"(?:pay(?:check| data)?|wage data).{0,35}(?:stays? on|never leaves?).{0,35}(?:device|phone|iphone)", lower):
            if not re.search(r"by default|unless|choose|optional|only.*processing", lower):
                violations.append("Absolute device-only privacy promise")
        for pattern, label in (
            (r"guaranteed (?:wage |pay |money )?recovery", "Unsubstantiated recovery guarantee"),
            (r"\bada compliant\b|\bfully accessible\b", "Unsubstantiated universal accessibility claim"),
            (r"certified payroll audit|all statutory entitlements verified", "Unsubstantiated legal certification"),
        ):
            if re.search(pattern, lower):
                violations.append(label)
    return sorted(set(violations))


def check_copy(root):
    root = Path(root)
    paths = {root / p for p in COPY_PATHS if (root / p).is_file()}
    paths.update((root / "apps/ios/App/Sources").glob("*.swift"))
    errors = []
    for path in sorted(paths):
        for violation in copy_violations(path.read_text(encoding="utf-8")):
            errors.append(f"{path.relative_to(root)}: {violation}")
    return errors


def inventory(root):
    root = Path(root)
    paths = {root / "apps/ios/project.yml", root / "apps/ios/App/Info.plist"}
    for pattern in ("apps/ios/**/Package.swift", "apps/ios/**/Package.resolved", "apps/ios/App/Resources/**/*"):
        paths.update(path for path in root.glob(pattern) if path.is_file() and ".build" not in path.parts)
    return {str(path.relative_to(root)): sha256_file(path) for path in sorted(paths) if path.is_file()}


def request_stage(method, path, body):
    """Reads and one exact non-publishing safety hold do not require completed release evidence.

    Unknown writes default to the gate. Authentication/explicit --allow-write remain independent.
    """
    if method == "GET":
        return None
    if method == "PATCH" and re.fullmatch(r"/v1/appStoreVersions/[A-Za-z0-9-]+", path):
        try:
            expected = {"data": {"type": "appStoreVersions", "id": path.rsplit("/", 1)[1],
                                 "attributes": {"releaseType": "MANUAL"}}}
            if strict_json(body) == expected:
                return None
        except (ValueError, TypeError):
            pass
    return "distribution" if "appStoreVersionReleaseRequests" in path else "submission"


def request_matches(approval, method, path, body):
    return isinstance(approval, dict) and approval == {
        "method": method, "path": path, "body_sha256": digest(body or b"")}


def validate_release_file(path, root, stage):
    root = Path(root).resolve()
    path = Path(path).resolve()
    if path.is_relative_to(root):
        raise ValueError("Keep private release approvals and supporting files outside the repository.")
    sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(root), "status", "--porcelain"], text=True).strip()
    if dirty:
        raise ValueError("Release approval requires a clean, committed candidate; do not ignore changed files.")
    data = read_json(path)
    errors = validate_evidence(data, path.parent, sha, stage)
    errors += check_copy(root)
    saved_inventory = read_json(root / INVENTORY_PATH)
    if saved_inventory.get("files") != inventory(root):
        errors.append("Runtime resources or dependency inventory changed; review and record the new inventory.")
    if errors:
        raise ValueError("\n".join(errors))
    return data


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "inventory", "release"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--stage", choices=("submission", "distribution"), default="distribution")
    parser.add_argument("--evidence", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "inventory":
            print(json.dumps({"status": "mechanical inventory, not ownership approval", "files": inventory(args.root)}, indent=2))
            return 0
        if args.command == "release":
            if args.evidence is None:
                raise ValueError("Real owner-reviewed --evidence is required. A template is not approval.")
            validate_release_file(args.evidence, args.root, args.stage)
            print("Evidence consistency passed. Human authorization and external facts remain the owner's responsibility.")
            return 0
        errors = check_copy(args.root)
        record = read_json(args.root / INVENTORY_PATH)
        if record.get("files") != inventory(args.root):
            errors.append("Resource/dependency inventory drift; review before updating its recorded hashes.")
        if errors:
            raise ValueError("\n".join(errors))
        print("Active-copy and inventory checks passed; no legal or release approval is implied.")
        return 0
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        print("Blocked: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
