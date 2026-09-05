"""Run fail-fast CLI paths in an isolated copy with stub executables; never download tools."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CommandGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "apps/ios").mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ["dirname", "grep", "head", "sed", "mktemp", "rm", "cat"]:
            path = shutil.which(name)
            if path:
                (self.bin / name).symlink_to(path)
        self.environment = {**os.environ, "PATH": str(self.bin), "TMPDIR": str(self.root),
                            "IOS_SIMULATOR_DESTINATION": "platform=iOS Simulator,id=synthetic"}
        self.bash = shutil.which("bash")

    def stub(self, name, body="exit 0"):
        file = self.bin / name
        file.write_text("#!/bin/bash\n" + body + "\n")
        file.chmod(0o755)

    def run_script(self, name, *args):
        target = self.root / "scripts" / name
        shutil.copyfile(ROOT / "scripts" / name, target)
        return subprocess.run([self.bash, str(target), *args], env=self.environment,
                              capture_output=True, text=True, timeout=10)

    def test_unknown_verification_mode_is_usage_error(self):
        result = self.run_script("agent-verify.sh", "not-a-mode")
        self.assertEqual(result.returncode, 64)
        self.assertIn("usage:", result.stderr)

    def test_bootstrap_requires_xcode_before_generation(self):
        result = self.run_script("bootstrap-ios.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Xcode command line tools are required", result.stderr)

    def test_bootstrap_rejects_wrong_generator_version(self):
        self.stub("xcodebuild")
        self.stub("xcodegen", "echo 'Version: 0.0.1'")
        result = self.run_script("bootstrap-ios.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected XcodeGen 2.46.0", result.stderr)

    def test_native_gate_requires_generator_and_swift(self):
        result = self.run_script("check-ios.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xcodegen is required", result.stderr)
        self.stub("xcodegen")
        result = self.run_script("check-ios.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Swift toolchain is required", result.stderr)

    def test_maestro_requires_all_tools(self):
        result = self.run_script("test-ios-maestro.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xcodebuild is required", result.stderr)
        for tool in ["xcodebuild", "xcrun", "xcodegen"]:
            self.stub(tool)
        result = self.run_script("test-ios-maestro.sh")
        self.assertIn("maestro is required", result.stderr)
        self.assertNotEqual(result.returncode, 0)

    def test_installer_fails_before_network_when_curl_missing(self):
        result = self.run_script("install-xcodegen.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("curl is required", result.stderr)


if __name__ == "__main__":
    unittest.main()
