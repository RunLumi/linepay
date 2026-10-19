"""Exercise startup failure modes with real short-lived fake SDK processes, never an AVD."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "scripts/start-android-ci-emulator.py"
EMULATOR = """import os, sys, time
from pathlib import Path
if '-accel-check' in sys.argv:
    print('synthetic acceleration check')
    sys.exit(1 if os.environ.get('FAKE_MODE') == 'no-acceleration' else 0)
Path(os.environ['RUNNER_TEMP'], 'launch-arguments.txt').write_text(' '.join(sys.argv[1:]))
print('synthetic emulator started', flush=True)
if os.environ.get('FAKE_MODE') == 'crash':
    sys.exit(42)
while True:
    time.sleep(1)
"""
ADB = """import os, sys, time
mode = os.environ.get('FAKE_MODE', 'ready')
if mode == 'hung-adb':
    time.sleep(60)
if 'get-state' in sys.argv:
    print('offline' if mode == 'offline' else 'device')
else:
    print('0' if mode == 'boot-incomplete' else '1')
"""


class AndroidCIEmulatorTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="linepay-fake-ci-sdk-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.sdk = self.root / "sdk"
        self.output = self.root / "linepay-android"
        for relative, source in (("emulator/emulator", EMULATOR), ("platform-tools/adb", ADB)):
            tool = self.sdk / relative
            tool.parent.mkdir(parents=True, exist_ok=True)
            tool.write_text(f"#!{sys.executable}\n{source}")
            tool.chmod(0o700)
        self.env = {**os.environ, "GITHUB_ACTIONS": "true", "RUNNER_OS": "Linux",
                    "RUNNER_ENVIRONMENT": "github-hosted", "RUNNER_TEMP": str(self.root),
                    "ANDROID_SDK_ROOT": str(self.sdk)}
        self.addCleanup(self.stop_fake_process)

    def stop_fake_process(self):
        pid_file = self.output / "emulator.pid"
        if pid_file.exists():
            try:
                os.killpg(int(pid_file.read_text()), signal.SIGKILL)
            except ProcessLookupError:
                pass

    def launch(self, mode="ready", **override):
        started = time.monotonic()
        result = subprocess.run([
            sys.executable, str(LAUNCHER), "--startup-timeout", "1.5", "--device-timeout", "0.7",
            "--command-timeout", "0.2", "--poll-interval", "0.02",
        ], env={**self.env, "FAKE_MODE": mode, **override}, capture_output=True, text=True, timeout=8)
        self.assertLess(time.monotonic() - started, 5, result.stderr)
        return result

    def test_success_requires_acceleration_and_completed_boot(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = (self.root / "launch-arguments.txt").read_text()
        self.assertIn("-accel on", arguments)
        self.assertIn("-avd LinePaycheck_E2E_API_36", arguments)
        self.assertIn("booted in", result.stdout)

    def test_crashed_emulator_fails_promptly_and_keeps_its_log(self):
        result = self.launch("crash")
        self.assertEqual(result.returncode, 1)
        self.assertIn("status 42", result.stderr)
        self.assertIn("synthetic emulator started", (self.output / "emulator.log").read_text())

    def test_disconnected_device_hits_discovery_deadline(self):
        result = self.launch("offline")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Timed out during ADB device discovery", result.stderr)
        self.assertTrue((self.output / "startup-error.log").is_file())

    def test_hung_adb_cannot_outlive_discovery_deadline(self):
        result = self.launch("hung-adb")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Timed out during ADB device discovery", result.stderr)

    def test_online_device_without_boot_completion_still_fails(self):
        result = self.launch("boot-incomplete")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Timed out during Android boot completion", result.stderr)

    def test_missing_acceleration_never_launches_an_emulator(self):
        result = self.launch("no-acceleration")
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.root / "launch-arguments.txt").exists())
        self.assertIn("synthetic acceleration check", (self.output / "acceleration.log").read_text())

    def test_local_or_self_hosted_runner_is_rejected_before_sdk_use(self):
        for override in ({"GITHUB_ACTIONS": "false"}, {"RUNNER_OS": "macOS"},
                         {"RUNNER_ENVIRONMENT": "self-hosted"}):
            with self.subTest(override=override):
                result = self.launch(**override)
                self.assertEqual(result.returncode, 2)
                self.assertIn("restricted to ephemeral GitHub-hosted Linux runners", result.stderr)
                self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
