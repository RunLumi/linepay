"""Synthetic release evidence only. No real approvals, credentials or Apple requests."""
import copy
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("legal_guardrails", ROOT / "scripts/legal_guardrails.py")
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)
NOW = datetime(2026, 9, 6, 8, tzinfo=timezone.utc)
SHA = "a" * 40
DEFAULT = object()


class LegalGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "review.txt").write_text("SYNTHETIC UNIT TEST EVIDENCE ONLY")
        (self.root / "screen.png").write_bytes(b"\x89PNG\r\n\x1a\nSYNTHETIC")
        with zipfile.ZipFile(self.root / "candidate.ipa", "w") as archive:
            archive.writestr("Payload/LinePay.app/Info.plist", plistlib.dumps({
                "CFBundleIdentifier": "com.streamentry.linepay",
                "CFBundleShortVersionString": "1.0", "CFBundleVersion": "99",
            }))
        self.evidence = self.valid_evidence()

    def ref(self, name):
        return {"path": name, "sha256": guard.sha256_file(self.root / name)}

    def valid_evidence(self):
        review = lambda: {
            "status": "approved", "reviewer": "Fixture reviewer", "reviewed_at": NOW.isoformat(),
            "source_sha": SHA, "rationale": "Synthetic scenario with matching evidence.",
            "evidence": [self.ref("review.txt")],
        }
        return {
            "schema_version": 1, "record_kind": "release-evidence", "stage": "distribution",
            "source_sha": SHA, "reviewed_at": NOW.isoformat(), "release_owner": "Fixture owner",
            "app": {"bundle_id": "com.streamentry.linepay", "version": "1.0", "build": "99",
                    "apple_build_id": "fixture-build", "source_sha": SHA},
            "binary": self.ref("candidate.ipa"),
            "storefront": {"checked_at": NOW.isoformat(), "release_mode": "MANUAL",
                           "territories": ["USA"], "apple_build_id": "fixture-build",
                           "readback": self.ref("review.txt"),
                           "subscriptions": [{"product_id": x, "status": "APPROVED"}
                                             for x in guard.PRODUCT_IDS]},
            "publisher": {"legal_entity": "Fixture publisher", "contact": "fixture@publisher.invalid",
                          "privacy_url": "https://linepaycheck.com/privacy",
                          "support_url": "https://linepaycheck.com/support"},
            "pages": [{"url": url, "checked_at": NOW.isoformat(), "reviewer": "Fixture reviewer",
                       "snapshot": self.ref("review.txt")}
                      for url in ("https://linepaycheck.com/privacy", "https://linepaycheck.com/support")],
            "screenshots": [{"kind": "release-capture", "source_sha": SHA,
                             "apple_build_id": "fixture-build", **self.ref("screen.png")}],
            "findings": {item: review() for item in guard.FINDING_IDS},
        }

    def errors(self, evidence=DEFAULT, stage="distribution"):
        return guard.validate_evidence(self.evidence if evidence is DEFAULT else evidence,
                                       self.root, SHA, stage, NOW)

    def test_complete_synthetic_evidence_validates(self):
        self.assertEqual(self.errors(), [])

    def test_missing_each_required_top_level_field_fails(self):
        for key in self.evidence:
            with self.subTest(key=key):
                value = copy.deepcopy(self.evidence)
                del value[key]
                self.assertTrue(self.errors(value))

    def test_each_of_21_unapproved_findings_blocks(self):
        for item in guard.FINDING_IDS:
            with self.subTest(item=item):
                value = copy.deepcopy(self.evidence)
                value["findings"][item]["status"] = "pending"
                self.assertTrue(self.errors(value))

    def test_conditional_scope_requires_reason_and_review(self):
        self.evidence["findings"]["LEGAL-14"]["status"] = "not-applicable"
        self.evidence["findings"]["LEGAL-14"]["rationale"] = "No named agreement packs are distributed."
        self.assertEqual(self.errors(), [])
        self.evidence["findings"]["LEGAL-14"]["rationale"] = ""
        self.assertTrue(self.errors())
        self.evidence = self.valid_evidence()
        self.evidence["findings"]["LEGAL-03"]["status"] = "not-applicable"
        self.assertTrue(self.errors())

    def test_unknown_finding_and_wrong_types_fail_closed(self):
        for value in ([], None, True, "approved", {"schema_version": True}):
            with self.subTest(value=value):
                self.assertTrue(self.errors(value))
        self.evidence["findings"]["LEGAL-99"] = self.evidence["findings"]["LEGAL-01"]
        self.assertTrue(self.errors())

    def test_source_changes_invalidate_root_and_every_signoff(self):
        self.evidence["source_sha"] = "b" * 40
        self.assertTrue(self.errors())
        for item in guard.FINDING_IDS:
            value = self.valid_evidence()
            value["findings"][item]["source_sha"] = "b" * 40
            with self.subTest(item=item):
                self.assertTrue(self.errors(value))

    def test_future_stale_and_naive_timestamps_fail(self):
        for timestamp in ((NOW + timedelta(hours=1)).isoformat(),
                          (NOW - timedelta(days=8)).isoformat(),
                          NOW.replace(tzinfo=None).isoformat(), "not-a-date"):
            value = self.valid_evidence()
            value["reviewed_at"] = timestamp
            with self.subTest(timestamp=timestamp):
                self.assertTrue(self.errors(value))
        self.evidence["storefront"]["checked_at"] = (NOW - timedelta(hours=25)).isoformat()
        self.assertTrue(self.errors())

    def test_missing_or_tampered_files_fail(self):
        (self.root / "review.txt").write_text("CHANGED")
        self.assertTrue(self.errors())
        (self.root / "review.txt").unlink()
        self.assertTrue(self.errors())

    def test_absolute_traversal_and_symlink_evidence_rejected(self):
        (self.root / "link.txt").symlink_to(self.root / "review.txt")
        for path in ("../review.txt", "/tmp/review.txt", "link.txt"):
            value = self.valid_evidence()
            value["findings"]["LEGAL-01"]["evidence"][0]["path"] = path
            with self.subTest(path=path):
                self.assertTrue(self.errors(value))

    def test_placeholder_approvals_do_not_count(self):
        for text in ("", "TBD", "unknown", "TODO", "pending", "<owner>"):
            value = self.valid_evidence()
            value["release_owner"] = text
            with self.subTest(text=text):
                self.assertTrue(self.errors(value))

    def test_unapproved_products_autorelease_and_new_territories_fail(self):
        for key, bad in (("release_mode", "AFTER_APPROVAL"), ("territories", ["USA", "CAN"]),
                         ("apple_build_id", "other"), ("subscriptions", [])):
            value = self.valid_evidence()
            value["storefront"][key] = bad
            with self.subTest(key=key):
                self.assertTrue(self.errors(value))
        self.evidence["storefront"]["subscriptions"][0]["status"] = "READY_TO_SUBMIT"
        self.assertTrue(self.errors())
        self.assertEqual(self.errors(stage="submission"), [])

    def test_unknown_stage_or_submission_evidence_cannot_publish(self):
        self.assertTrue(self.errors(stage="other"))
        self.evidence["stage"] = "submission"
        self.assertTrue(self.errors())

    def test_concept_screenshots_and_wrong_build_cannot_pass(self):
        for key, value in (("kind", "concept"), ("source_sha", "b" * 40),
                           ("apple_build_id", "old-build")):
            evidence = self.valid_evidence()
            evidence["screenshots"][0][key] = value
            with self.subTest(key=key):
                self.assertTrue(self.errors(evidence))

    def test_ipa_identity_is_read_not_just_claimed(self):
        self.evidence["app"]["build"] = "100"
        self.assertTrue(self.errors())
        self.evidence = self.valid_evidence()
        with zipfile.ZipFile(self.root / "candidate.ipa", "w") as archive:
            archive.writestr("not-an-app.txt", "SYNTHETIC")
        self.evidence["binary"] = self.ref("candidate.ipa")
        self.assertTrue(self.errors())

    def test_wrong_pages_and_missing_support_snapshot_fail(self):
        self.evidence["pages"][0]["url"] = "https://another.invalid/privacy"
        self.assertTrue(self.errors())
        self.evidence = self.valid_evidence()
        self.evidence["pages"].pop()
        self.assertTrue(self.errors())

    def test_json_duplicate_keys_and_oversized_file_rejected(self):
        path = self.root / "input.json"
        path.write_text('{"source_sha":"approved", "source_sha":"other"}')
        with self.assertRaises(ValueError):
            guard.read_json(path)
        path.write_bytes(b" " * (guard.MAX_EVIDENCE_BYTES + 1))
        with self.assertRaises(ValueError):
            guard.read_json(path)

    def test_read_and_exact_safety_hold_are_not_blocked_by_release_signoff(self):
        self.assertIsNone(guard.request_stage("GET", "/v1/builds", None))
        hold = json.dumps({"data": {"type": "appStoreVersions", "id": "123",
                                  "attributes": {"releaseType": "MANUAL"}}}).encode()
        self.assertIsNone(guard.request_stage("PATCH", "/v1/appStoreVersions/123", hold))
        payload = json.loads(hold)
        payload["data"]["attributes"]["versionString"] = "9.0"
        self.assertEqual(guard.request_stage("PATCH", "/v1/appStoreVersions/123",
                                           json.dumps(payload).encode()), "submission")
        self.assertEqual(guard.request_stage("POST", "/v1/appStoreVersionReleaseRequests", b"{}"),
                         "distribution")
        self.assertEqual(guard.request_stage("POST", "/v1/newFutureEndpoint", b"{}"), "submission")

    def test_approval_is_bound_to_exact_requested_body_and_path(self):
        payload = b'{"data":{"id":"123"}}'
        approval = {"method": "PATCH", "path": "/v1/apps/123", "body_sha256": guard.digest(payload)}
        self.assertTrue(guard.request_matches(approval, "PATCH", "/v1/apps/123", payload))
        self.assertFalse(guard.request_matches(approval, "POST", "/v1/apps/123", payload))
        self.assertFalse(guard.request_matches(approval, "PATCH", "/v1/apps/other", payload))
        self.assertFalse(guard.request_matches(approval, "PATCH", "/v1/apps/123", b"{}"))

    def test_copy_rules_flag_absolutes_not_qualified_descriptions(self):
        for text in ("Your pay data stays on this device.", "Your paycheck never leaves your phone.",
                     "Guaranteed wage recovery", "ADA compliant", "Certified payroll audit"):
            with self.subTest(text=text):
                self.assertTrue(guard.copy_violations(text))
        for text in ("Pay data stays on this iPhone by default.",
                     "Your pay data stays on this iPhone unless you choose to export or back it up.",
                     "Possible difference, not a legal determination.", "No paycheck uploads to our servers."):
            with self.subTest(text=text):
                self.assertEqual(guard.copy_violations(text), [])

    def test_malformed_nested_values_fail_closed_without_crashing(self):
        mutations = [
            lambda e: e["storefront"]["subscriptions"][0].update(product_id=[]),
            lambda e: e["storefront"]["subscriptions"][0].update(status={}),
            lambda e: e["pages"][0].update(url=[]),
            lambda e: e["findings"]["LEGAL-01"].update(status=[]),
            lambda e: e["screenshots"][0].update(path=True),
        ]
        for mutate in mutations:
            evidence = self.valid_evidence()
            mutate(evidence)
            with self.subTest(mutation=mutate):
                self.assertTrue(self.errors(evidence))

    def test_duplicate_manual_hold_field_cannot_bypass_gate(self):
        body = b'{"data":{"type":"appStoreVersions","id":"123","attributes":{"releaseType":"AFTER_APPROVAL","releaseType":"MANUAL"}}}'
        self.assertEqual(guard.request_stage("PATCH", "/v1/appStoreVersions/123", body), "submission")

    def test_repository_copy_scan_finds_seeded_regression(self):
        source = self.root / "apps/ios/App/Sources"
        source.mkdir(parents=True)
        (source / "Welcome.swift").write_text('Text("Your paycheck never leaves your phone.")')
        self.assertTrue(guard.check_copy(self.root))
