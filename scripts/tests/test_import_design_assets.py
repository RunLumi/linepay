"""Hermetic contracts for the asset importer; only synthetic bytes and temporary roots."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import warnings
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "import-design-assets.py"
SPEC = importlib.util.spec_from_file_location("import_design_assets", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
PNG = b"\x89PNG\r\n\x1a\nSYNTHETIC TEST DATA"


class AssetImporterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.archive = Path(self.temp.name) / "source.zip"
        self.files = {"assets/brand/a.png": PNG, "assets/brand/b.png": PNG + b"2"}
        self.manifest = {
            "version": 1, "repository": "streamentry/linepay",
            "files": [{"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                      for path, data in self.files.items()],
        }

    def write_archive(self, *, extra=None, excluded=(), manifest_bytes=None):
        data = json.dumps(self.manifest, sort_keys=True).encode()
        target = self.root / MODULE.MANIFEST
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.archive, "w") as archive:
                archive.writestr(MODULE.MANIFEST, data if manifest_bytes is None else manifest_bytes)
                for path, value in self.files.items():
                    if path not in excluded:
                        archive.writestr(path, value)
                if extra:
                    archive.writestr(*extra)

    def run_import(self, check=False):
        with contextlib.redirect_stdout(io.StringIO()):
            return MODULE.import_assets(self.root, self.archive, check_only=check)

    def assert_no_assets(self):
        self.assertFalse((self.root / "assets/brand/a.png").exists())
        self.assertFalse((self.root / "assets/brand/b.png").exists())

    def test_complete_import_is_idempotent_and_preserves_input_archive(self):
        self.write_archive()
        before = self.archive.read_bytes()
        self.assertEqual(self.run_import(), 2)
        for path, data in self.files.items():
            self.assertEqual((self.root / path).read_bytes(), data)
        self.assertEqual(self.run_import(), 0)
        self.assertEqual(self.archive.read_bytes(), before)

    def test_check_only_does_not_write_any_asset(self):
        self.write_archive()
        self.assertEqual(self.run_import(check=True), 2)
        self.assert_no_assets()

    def test_changed_existing_file_is_never_overwritten(self):
        self.write_archive()
        file = self.root / "assets/brand/a.png"
        file.parent.mkdir(parents=True)
        file.write_bytes(b"user work")
        with self.assertRaises(ValueError):
            self.run_import()
        self.assertEqual(file.read_bytes(), b"user work")
        self.assertFalse((file.parent / "b.png").exists())

    def test_late_invalid_file_cannot_leave_earlier_valid_file_written(self):
        self.files["assets/brand/b.png"] += b"corrupt"
        self.write_archive()
        with self.assertRaises(ValueError):
            self.run_import()
        self.assert_no_assets()

    def test_checksum_mismatch_with_same_size_is_rejected(self):
        self.manifest["files"][1]["sha256"] = "0" * 64
        self.write_archive()
        with self.assertRaises(ValueError):
            self.run_import()
        self.assert_no_assets()

    def test_missing_extra_and_duplicate_zip_entries_are_rejected(self):
        cases = [{"excluded": ["assets/brand/b.png"]}, {"extra": ("unreviewed.png", PNG)},
                 {"extra": ("assets/brand/a.png", PNG)}]
        for arguments in cases:
            with self.subTest(arguments=arguments):
                self.write_archive(**arguments)
                with self.assertRaises(ValueError):
                    self.run_import()
                self.assert_no_assets()

    def test_archive_manifest_size_and_bytes_must_match(self):
        for data in [b"{}", b" " * len(json.dumps(self.manifest, sort_keys=True).encode())]:
            with self.subTest(data_length=len(data)):
                self.write_archive(manifest_bytes=data)
                with self.assertRaises(ValueError):
                    self.run_import()
                self.assert_no_assets()

    def test_wrong_repository_and_version_are_rejected(self):
        for field, value in [("version", 2), ("repository", "other/repository")]:
            old = self.manifest[field]
            self.manifest[field] = value
            self.write_archive()
            with self.assertRaises(ValueError):
                self.run_import()
            self.manifest[field] = old
            self.assert_no_assets()

    def test_duplicate_manifest_paths_are_rejected(self):
        self.manifest["files"].append(self.manifest["files"][0])
        self.write_archive()
        with self.assertRaises(ValueError):
            self.run_import()
        self.assert_no_assets()

    def test_oversized_manifest_is_rejected_before_reading_payload(self):
        self.manifest["files"][0]["bytes"] = 64 * 1024 * 1024 + 1
        self.write_archive()
        with self.assertRaises(ValueError):
            self.run_import()
        self.assert_no_assets()

    def test_path_traversal_absolute_and_wrong_extension_are_rejected(self):
        for path in ["../outside.png", "/tmp/outside.png", "assets/../outside.png", "assets/a.svg"]:
            with self.subTest(path=path):
                self.files = {path: PNG}
                self.manifest["files"] = [{"path": path, "bytes": len(PNG), "sha256": hashlib.sha256(PNG).hexdigest()}]
                self.write_archive()
                with self.assertRaises(ValueError):
                    self.run_import()

    def test_symlink_destination_is_rejected_without_touching_target(self):
        self.write_archive()
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.root / "assets/brand").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.run_import()
        self.assertEqual(list(outside.iterdir()), [])

    def test_non_png_with_correct_checksum_is_rejected(self):
        self.files = {"assets/a.png": b"not png"}
        self.manifest["files"] = [{"path": path, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                                  for path, data in self.files.items()]
        self.write_archive()
        with self.assertRaises(ValueError):
            self.run_import()
        self.assertFalse((self.root / "assets/a.png").exists())

    def test_corrupt_zip_and_invalid_manifest_json_are_rejected(self):
        self.write_archive()
        self.archive.write_bytes(b"not ZIP")
        with self.assertRaises(zipfile.BadZipFile):
            self.run_import()
        (self.root / MODULE.MANIFEST).write_bytes(b"not JSON")
        with self.assertRaises(ValueError):
            self.run_import()


if __name__ == "__main__":
    unittest.main()
