import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class SelfHostedIOSPolicyTests(unittest.TestCase):
    # Pinned by name: a UDID does not survive a host restore or simulator rebuild.
    FULL_PIN = "IOS_SIMULATOR_NAME: LinePay Release iPhone 18"
    LEGAL_PIN = "IOS_SIMULATOR_NAME: QC iPhone 17 Pro v2"
    RESOLVE = 'grep -F "$IOS_SIMULATOR_NAME ("'
    RESET_STEP = "Reset synthetic app data on the pinned simulator"

    def test_ios_jobs_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/ios.yml").read_text()
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 2)
        self.assertIn("branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)
        self.assertEqual(workflow.count(self.FULL_PIN), 1)
        self.assertIn(self.RESOLVE, workflow)
        self.assertNotIn("id=6CB95D1F", workflow)
        self.assertIn(self.RESET_STEP, workflow)
        self.assertIn('xcrun simctl shutdown "$UDID"', workflow)
        self.assertIn('launchctl kickstart -k "system/$SERVICE"', workflow)
        self.assertIn("device: QC iPhone 17 Pro v2", workflow)
        self.assertIn("device: LinePay Release iPhone 18", workflow)
        self.assertIn("MAESTRO_CACHE=", workflow)
        self.assertNotIn("simctl create", workflow)
        self.assertIn("MAESTRO_CLI_NO_ANALYTICS", workflow)
        self.assertIn('mkdir -p "$HOME/.maestro"', workflow)

    def test_legal_regressions_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/legal-regressions.yml").read_text()
        self.assertIn("push:\n    branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 1)
        self.assertEqual(workflow.count(self.LEGAL_PIN), 1)
        self.assertIn(self.RESOLVE, workflow)
        self.assertNotIn("id=0A8C774B", workflow)
        self.assertNotIn("list devices available -j", workflow)
        self.assertIn(self.RESET_STEP, workflow)


if __name__ == "__main__":
    unittest.main()
