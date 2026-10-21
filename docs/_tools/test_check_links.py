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

    def test_hugo_relref_shortcode_is_not_a_local_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text(
                '[Guide]({{< relref "/getting-started" >}})\n', encoding="utf-8")
            self.assertEqual(check(root), (0, []))

    def test_named_anchor_and_escaping(self):
        self.assertIn("explicit", anchors('<a id="explicit"></a>\n# Notes'))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text("[Outside](../outside.md)\n", encoding="utf-8")
            self.assertEqual(len(check(root)[1]), 1)

    def test_android_build_output_is_excluded_but_source_docs_remain_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in ("apps/android/build", "apps/android/app/build/intermediates/assets"):
                output = root / path
                output.mkdir(parents=True)
                (output / "README.md").write_text("[Generated](missing.md)\n", encoding="utf-8")
            source = root / "apps/android/app/src/main/assets"
            source.mkdir(parents=True)
            (source / "README.md").write_text("[Source](missing.md)\n", encoding="utf-8")
            count, errors = check(root)
            self.assertEqual(count, 1)
            self.assertEqual(len(errors), 1)
            self.assertIn("src/main/assets/README.md", errors[0])


if __name__ == "__main__":
    unittest.main()
