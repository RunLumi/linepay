import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class SelfHostedIOSPolicyTests(unittest.TestCase):
    PIN = "IOS_SIMULATOR_DESTINATION: platform=iOS Simulator,id=0A8C774B-C1D3-4A43-816C-81D3D3D849D8"
    RESET_STEP = "Reset synthetic app data on the pinned simulator"

    def test_ios_jobs_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/ios.yml").read_text()
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 2)
        self.assertIn("branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)
        self.assertEqual(workflow.count(self.PIN), 1)
        self.assertIn(self.RESET_STEP, workflow)

    def test_legal_regressions_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/legal-regressions.yml").read_text()
        self.assertIn("push:\n    branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 1)
        self.assertEqual(workflow.count(self.PIN), 1)
        self.assertNotIn("list devices available -j", workflow)
        self.assertIn(self.RESET_STEP, workflow)


if __name__ == "__main__":
    unittest.main()
