"""Keep runnable release examples aligned with the source-bound write guard."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def unguarded_commands(text):
    commands = []
    for block in re.findall(r"```bash\n(.*?)```", text, flags=re.S):
        joined = re.sub(r"\\\n\s*", " ", block)
        commands.extend(line for line in joined.splitlines()
                        if "python3 scripts/asc-api.py" in line and "--allow-write" in line
                        and "--release-evidence" not in line)
    return commands


class ReleaseDocumentationTests(unittest.TestCase):
    def test_detector_rejects_unguarded_multiline_mutation_example(self):
        sample = '```bash\npython3 scripts/asc-api.py "/v1/reviewSubmissions/id" \\\n  --method PATCH --body "$BODY" --allow-write\n```'
        self.assertEqual(len(unguarded_commands(sample)), 1)
        guarded = sample.replace("--allow-write", '--allow-write --release-evidence "$EVIDENCE"')
        self.assertEqual(unguarded_commands(guarded), [])

    def test_canonical_release_examples_require_private_evidence(self):
        text = (ROOT / "docs/release/api-and-testflight.md").read_text()
        self.assertEqual(unguarded_commands(text), [])
        for required in ("authorized_request", "body_sha256", "--stage submission",
                         "--stage distribution", "outside the repository"):
            self.assertIn(required, text)


if __name__ == "__main__":
    unittest.main()
