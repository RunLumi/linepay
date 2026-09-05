"""Keep the reviewed package graph reproducible without tracking generated Xcode files."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path("apps/ios/LinePay.xcodeproj")
LOCK = PROJECT / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"


class PackageLockTests(unittest.TestCase):
    def test_lock_matches_the_pinned_test_dependency(self):
        graph = json.loads((ROOT / LOCK).read_text())
        self.assertEqual(graph["version"], 3)
        spec = (ROOT / "apps/ios/project.yml").read_text()
        match = re.search(
            r"(?m)^  ViewInspector:\n    url: (\S+)\n    revision: ([0-9a-f]{40})$",
            spec,
        )
        self.assertIsNotNone(match, "ViewInspector must stay pinned to a reviewed commit")
        pins = [pin for pin in graph["pins"] if pin["identity"] == "viewinspector"]
        self.assertEqual(len(pins), 1)
        self.assertEqual(pins[0]["location"], match.group(1))
        self.assertEqual(pins[0]["state"]["revision"], match.group(2))
        self.assertEqual(pins[0]["kind"], "remoteSourceControl")

    def test_only_the_lockfile_is_trackable_inside_the_generated_project(self):
        paths = [
            (LOCK, False),
            (PROJECT / "project.pbxproj", True),
            (PROJECT / "xcshareddata/xcschemes/LinePay.xcscheme", True),
            (PROJECT / "project.xcworkspace/contents.xcworkspacedata", True),
            (PROJECT / "project.xcworkspace/xcshareddata/swiftpm/configuration/registries.json", True),
            (PROJECT / "project.xcworkspace/xcuserdata/test.xcuserdatad/WorkspaceSettings.xcsettings", True),
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True, timeout=10)
            shutil.copyfile(ROOT / ".gitignore", root / ".gitignore")
            for path, expected in paths:
                with self.subTest(path=str(path)):
                    file = root / path
                    file.parent.mkdir(parents=True, exist_ok=True)
                    file.touch()
                    result = subprocess.run(
                        ["git", "-c", "core.excludesFile=/dev/null", "-C", str(root),
                         "check-ignore", "--no-index", "-q", str(path)],
                        check=False, timeout=10,
                    )
                    self.assertIn(result.returncode, (0, 1))
                    self.assertEqual(result.returncode == 0, expected)


if __name__ == "__main__":
    unittest.main()
