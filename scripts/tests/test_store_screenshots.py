import hashlib
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
STORE = ROOT / "assets/store"
REQUIRED = ("sourceCommit", "appVersion", "buildNumber", "device", "osVersion", "fixtureID",
            "captureTest")


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class StoreScreenshotProvenanceTests(unittest.TestCase):
    """Issue #27: every store export is a recorded composition of a real capture, never concept art."""

    def setUp(self):
        self.manifests = [json.loads(p.read_text(encoding="utf-8"))
                          for p in sorted((STORE / "source").glob("capture-manifest-*.json"))]

    def test_every_export_is_listed_and_unchanged(self):
        listed = {}
        for manifest in self.manifests:
            for key in REQUIRED:
                self.assertTrue(manifest.get(key), f"capture manifest needs {key}")
            for image in manifest["images"]:
                listed[image["export"]] = image
        exports = sorted(p.relative_to(ROOT).as_posix()
                         for p in (STORE / "exports").rglob("*") if p.is_file())
        self.assertTrue(exports, "no store exports recorded")
        self.assertEqual(exports, sorted(listed), "an export has no capture manifest entry")
        for path, image in listed.items():
            self.assertEqual(sha256(ROOT / path), image["exportSHA256"], f"{path} changed")
            raw = ROOT / image["rawCapture"]
            self.assertTrue(raw.is_file(), f"{path}: raw capture {raw} is missing")
            self.assertEqual(sha256(raw), image["rawSHA256"], f"{raw} changed")
            self.assertTrue(image["headline"] and image["accessRequirement"])

    def test_concepts_never_enter_the_upload_folders(self):
        for folder in ("exports", "raw"):
            for path in (STORE / folder).rglob("*"):
                self.assertNotIn("concept", path.as_posix().lower(), path)

    def test_possible_difference_frame_discloses_paid_access(self):
        for manifest in self.manifests:
            for image in manifest["images"]:
                if "Pro" in image["accessRequirement"] and image["id"].endswith(
                        "possible-difference"):
                    self.assertIn("Pro for ongoing checks", image["qualifier"] or "")


if __name__ == "__main__":
    unittest.main()
