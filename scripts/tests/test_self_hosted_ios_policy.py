import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class SelfHostedIOSPolicyTests(unittest.TestCase):
    def test_ios_jobs_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/ios.yml").read_text()
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 2)
        self.assertIn("branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)

    def test_legal_regressions_use_the_dedicated_runner(self):
        workflow = (ROOT / ".github/workflows/legal-regressions.yml").read_text()
        self.assertIn("push:\n    branches: [dev, testing]", workflow)
        self.assertIn("pull_request:", workflow)
        self.assertEqual(workflow.count("runs-on: linepay-ios"), 1)


if __name__ == "__main__":
    unittest.main()
