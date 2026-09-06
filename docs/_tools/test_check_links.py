import tempfile
import unittest
from pathlib import Path

from check_links import anchors, check


class DocumentationLinksTests(unittest.TestCase):
    def test_paths_anchors_duplicates_and_external_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "docs").mkdir()
            (root / "README.md").write_text(
                "[Guide](docs/guide.md#rule-1)\n[Web](https://example.test/missing)\n"
                "[Duplicate](docs/guide.md#rule-1-1)\n", encoding="utf-8")
            (root / "docs/guide.md").write_text(
                "# Rule 1\n# Rule 1\n[Back](../README.md)\n", encoding="utf-8")
            self.assertEqual(check(root), (3, []))

    def test_missing_local_path_and_anchor_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text(
                "# Home\n[Missing](lost.md)\n[Bad](#absent)\n", encoding="utf-8")
            count, errors = check(root)
            self.assertEqual(count, 2)
            self.assertEqual(len(errors), 2)

    def test_examples_in_fences_are_not_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text(
                "```text\n[example](not-a-file.md)\n```\n", encoding="utf-8")
            self.assertEqual(check(root), (0, []))

    def test_named_anchor_and_escaping(self):
        self.assertIn("explicit", anchors('<a id="explicit"></a>\n# Notes'))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text("[Outside](../outside.md)\n", encoding="utf-8")
            self.assertEqual(len(check(root)[1]), 1)


if __name__ == "__main__":
    unittest.main()
