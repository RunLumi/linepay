import importlib.util
import json
import pathlib
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "check_screenshots", ROOT / "user-guide/scripts/check-screenshots.py")
screenshots = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(screenshots)


class GuideScreenshotTests(unittest.TestCase):
    """Issue #65: help screenshots are real captures with complete provenance."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.guide = pathlib.Path(self.tmp.name)
        for folder in ("data", "assets/screenshots", "content"):
            (self.guide / folder).mkdir(parents=True)
        (self.guide / "assets/screenshots/result.png").write_bytes(b"png")
        (self.guide / "content/audit-results.md").write_text('{{< screenshot "result" >}}\n')
        self.meta = {key: "x" for key in screenshots.REQUIRED}
        self.meta.update(guide="audit-results", fixture="Synthetic fixture",
                         alt="A paycheck result showing a possible shortfall and its scope")
        self.write()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, data=None):
        (self.guide / "data/screenshots.json").write_text(
            json.dumps(data if data is not None else {"result": self.meta}))

    def test_complete_entry_passes(self):
        self.assertEqual(screenshots.problems(self.guide), [])

    def test_missing_provenance_fails(self):
        self.meta["appCommit"] = ""
        self.write()
        self.assertTrue(any("missing provenance appCommit" in e
                            for e in screenshots.problems(self.guide)))

    def test_non_synthetic_or_vague_alt_fails(self):
        self.meta.update(fixture="real paystub", alt="screenshot of app")
        self.write()
        errors = screenshots.problems(self.guide)
        self.assertTrue(any("synthetic" in e for e in errors))
        self.assertTrue(any("alt text" in e for e in errors))

    def test_unused_unrecorded_and_missing_images_fail(self):
        (self.guide / "assets/screenshots/orphan.png").write_bytes(b"png")
        (self.guide / "content/audit-results.md").write_text("no screenshot\n")
        errors = screenshots.problems(self.guide)
        self.assertTrue(any("orphan.png has no provenance" in e for e in errors))
        self.assertTrue(any("result: not used by any guide" in e for e in errors))

    def test_repository_screenshots_pass(self):
        self.assertEqual(screenshots.problems(ROOT / "user-guide"), [])


if __name__ == "__main__":
    unittest.main()
