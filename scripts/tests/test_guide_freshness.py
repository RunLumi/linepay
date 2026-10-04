import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "check_freshness", ROOT / "user-guide/scripts/check-freshness.py")
freshness = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(freshness)


class GuideFreshnessTests(unittest.TestCase):
    """Issue #64: tracked app changes must be matched by a guide review record."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.guide = self.root / "user-guide"
        (self.guide / "content").mkdir(parents=True)
        (self.guide / "content" / "pay-profile.md").write_text("# Pay profile\n")
        (self.root / "Setup.swift").write_text("let label = \"Pay basics\"\n")
        (self.root / "Unrelated.swift").write_text("let x = 1\n")
        self.record = {
            "reviewedOn": "2026-10-04", "appVersion": "1.0.5",
            "sources": [{
                "path": "Setup.swift", "guides": ["pay-profile"],
                "disposition": "reviewed", "blob": self.hash(self.root / "Setup.swift")}],
        }

    def tearDown(self):
        self.tmp.cleanup()

    @staticmethod
    def hash(path):
        return pathlib.Path(path).read_text()

    def problems(self):
        return freshness.problems(self.record, self.root, self.guide, hash_of=self.hash)

    def test_current_record_passes(self):
        self.assertEqual(self.problems(), [])

    def test_tracked_ui_change_fails(self):
        (self.root / "Setup.swift").write_text("let label = \"Your pay\"\n")
        errors = self.problems()
        self.assertEqual(len(errors), 1)
        self.assertIn("Setup.swift changed since the guide review", errors[0])

    def test_unrelated_change_does_not_fail(self):
        (self.root / "Unrelated.swift").write_text("let x = 2\n")
        self.assertEqual(self.problems(), [])

    def test_reviewed_no_guide_change_passes_with_reason_after_recording(self):
        (self.root / "Setup.swift").write_text("let label = \"Pay basics\" // refactor\n")
        entry = self.record["sources"][0]
        entry.update(disposition="reviewed-no-guide-change", reason="comment only",
                     blob=self.hash(self.root / "Setup.swift"))
        self.assertEqual(self.problems(), [])
        entry["reason"] = " "
        self.assertTrue(any("needs a reason" in e for e in self.problems()))

    def test_missing_guide_page_fails(self):
        self.record["sources"][0]["guides"].append("removed-page")
        self.assertTrue(any("content/removed-page.md does not exist" in e for e in self.problems()))

    def test_missing_source_and_metadata_fail(self):
        self.record["sources"].append(
            {"path": "Gone.swift", "guides": ["pay-profile"], "disposition": "reviewed", "blob": ""})
        self.record["reviewedOn"] = ""
        errors = self.problems()
        self.assertTrue(any("Gone.swift: tracked source does not exist" in e for e in errors))
        self.assertTrue(any("needs reviewedOn and appVersion" in e for e in errors))

    def test_repository_record_is_current_and_public_cue_matches(self):
        record = json.loads((ROOT / "user-guide/source-review.json").read_text())
        self.assertEqual(freshness.problems(record), [])
        hugo = (ROOT / "user-guide/hugo.toml").read_text()
        self.assertIn(f"LinePaycheck {record['appVersion']}", hugo,
                      "The public footer cue must name the reviewed app version")


if __name__ == "__main__":
    unittest.main()
