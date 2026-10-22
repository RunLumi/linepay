import copy
import datetime as dt
import json
import sys
import tempfile
import unittest
from decimal import Decimal, getcontext, localcontext
from unittest.mock import patch
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"


class PortableStateContractTests(unittest.TestCase):
    def load(self, name):
        return verify.load_json(FIXTURES / name)

    def test_common_pending_fixture_passes_all_targets_and_refusals(self):
        verify.check()

    def test_attachment_fixture_is_valid_for_ios_only(self):
        doc = self.load("attachment-valid.json")
        verify.validate_document(doc)
        self.assertEqual([], verify.target_preflight(doc, "ios"))
        self.assertIn("target.attachmentsUnsupported", {x.code for x in verify.target_preflight(doc, "web")})
        self.assertIn("target.attachmentsUnsupported", {x.code for x in verify.target_preflight(doc, "android")})

    def test_adoption_keeps_original_records_and_ids_while_adding_new_active_profile(self):
        before = self.load("adoption-before.json")
        after = self.load("adoption-after.json")
        verify.validate_document(before)
        verify.validate_document(after)
        self.assertEqual("profile.ios-adopted-1", after["activeProfileRef"])
        self.assertEqual("profile.android-1", after["profiles"][1]["adoptedFromProfileRef"])
        for field in ("profiles", "ruleSnapshots", "periods", "workSnapshots", "paycheckReceipts"):
            self.assertEqual(before[field], after[field][: len(before[field])])
        before_crosswalk = {row["portableID"]: row for row in before["identityCrosswalk"]}
        after_crosswalk = {row["portableID"]: row for row in after["identityCrosswalk"]}
        for portable_id, row in before_crosswalk.items():
            self.assertEqual(row, after_crosswalk[portable_id])
        self.assertEqual("ios", after["source"]["client"])
        self.assertEqual("android", after["paycheckReceipts"][0]["producer"]["client"])
        self.assertEqual([], verify.target_preflight(after, "ios"))

    def test_current_workspace_and_future_default_remain_distinct_through_adoption(self):
        after = self.load("adoption-after.json")
        profile_a = after["profiles"][0]
        rule_a = after["ruleSnapshots"][0]
        period_a = after["periods"][0]
        current_work_a = after["workSnapshots"][0]
        profile_c = next(p for p in after["profiles"] if p["id"] == "profile.ios-adopted-1")
        period_c = next(p for p in after["periods"] if p["id"] == profile_c["currentPeriodRef"])

        # Add a distinct global/next-period default B with a feature Android can retain but review.
        rule_b = copy.deepcopy(rule_a)
        rule_b.update({"id":"rule.future-B.v1","ruleID":"future-B","version":"1","datePremiums":[{"date":"2026-11-07","multiplier":"2"}]})
        profile_b = {"id":"profile.future-B","name":"Future default B","timeZone":"America/Denver","cadence":"weekly","cycleStartDate":"2026-10-26","customEndDate":None,"ruleRef":rule_b["id"],"baselineRuleRef":rule_b["id"],"ruleChangeRefs":[],"currentPeriodRef":None,"currentWorkSnapshotRef":None,"adoptedFromProfileRef":None,"fieldsNotRecorded":["currentPeriodRef","currentWorkSnapshotRef"]}
        after["profiles"].append(profile_b)
        after["ruleSnapshots"].append(rule_b)
        after["identityCrosswalk"].append({"entityType":"profile","portableID":profile_b["id"],"originClient":"ios","originKind":"native","originLocalID":"profile-future-B"})
        after["identityCrosswalk"].append({"entityType":"ruleSnapshot","portableID":rule_b["id"],"originClient":"ios","originKind":"native","originLocalID":"rule-future-B@1"})
        after["sourceInventory"]["profileCount"] += 1
        after["sourceInventory"]["ruleSnapshotCount"] += 1
        after["activeProfileRef"] = profile_b["id"]

        # Before adoption, A owns the open workspace while B is the future-period default.
        profile_a["currentPeriodRef"] = period_a["id"]
        profile_a["fieldsNotRecorded"].remove("currentPeriodRef")
        period_a["isCurrent"] = False
        period_a["closed"] = True
        period_a["archivedAtEpochSeconds"] = period_c["calendarWindow"]["startEpochSeconds"]
        period_a["fieldsNotRecorded"].remove("isCurrent")
        period_a["fieldsNotRecorded"].remove("closed")
        period_a["fieldsNotRecorded"].remove("archivedAtEpochSeconds")
        period_a["currentWorkSnapshotRef"] = current_work_a["id"]
        period_a["fieldsNotRecorded"].remove("currentWorkSnapshotRef")
        period_a["workSnapshotRefs"].append(current_work_a["id"])
        current_work_a["periodRef"] = period_a["id"]

        # After adoption A closes and C owns current work; B remains the saved default.
        before = copy.deepcopy(after)
        before["profiles"] = [p for p in before["profiles"] if p["id"] != profile_c["id"]]
        before["ruleSnapshots"] = [r for r in before["ruleSnapshots"] if r["id"] != profile_c["ruleRef"]]
        before["periods"] = [p for p in before["periods"] if p["id"] != period_c["id"]]
        before["workSnapshots"] = [s for s in before["workSnapshots"] if s["profileRef"] != profile_c["id"]]
        before["adoptions"] = []
        removed_ids = {profile_c["id"], profile_c["ruleRef"], period_c["id"], period_c["windowRef"], "snapshot.ios-adopted-current-1", "adoption.ios-1"}
        before["identityCrosswalk"] = [row for row in before["identityCrosswalk"] if row["portableID"] not in removed_ids]
        before["sourceInventory"].update({
            "profileCount":len(before["profiles"]),"adoptionCount":0,"ruleSnapshotCount":len(before["ruleSnapshots"]),
            "periodCount":len(before["periods"]),"periodWindowCount":sum(row["entityType"]=="periodWindow" for row in before["identityCrosswalk"]),
            "workSnapshotCount":len(before["workSnapshots"]),"workEntryCount":sum(len(s["work"]) for s in before["workSnapshots"]),
        })
        before_a = next(p for p in before["periods"] if p["id"] == period_a["id"])
        before_a["isCurrent"] = True
        before_a["closed"] = False
        before_a["archivedAtEpochSeconds"] = None
        before_a["fieldsNotRecorded"].extend(["archivedAtEpochSeconds"])
        verify.validate_document(before)
        verify.validate_document(after)
        self.assertEqual(profile_b["id"], before["activeProfileRef"])
        self.assertEqual(profile_b["id"], after["activeProfileRef"])
        self.assertTrue(next(p for p in before["periods"] if p["id"] == period_a["id"])["isCurrent"])
        self.assertEqual(profile_a["id"], next(p for p in before["periods"] if p["id"] == period_a["id"])["profileRef"])
        self.assertTrue(next(p for p in after["periods"] if p["id"] == period_c["id"])["isCurrent"])
        self.assertEqual(profile_c["id"], next(p for p in after["periods"] if p["id"] == period_c["id"])["profileRef"])
        self.assertEqual([], verify.target_preflight(after, "android"))
        before_reviews = verify.target_activation_review(before, "android")
        after_reviews = verify.target_activation_review(after, "android")
        self.assertTrue(any("activeProfile[profile.future-B]" in issue.path for issue in before_reviews))
        self.assertTrue(any("currentPeriod[period.current-1]" in issue.path for issue in before_reviews))
        self.assertTrue(any("activeProfile[profile.future-B]" in issue.path for issue in after_reviews))
        self.assertTrue(any("currentPeriod[period.ios-adopted-current-1]" in issue.path for issue in after_reviews))
        # Profile array order is not a selection signal.
        reordered = copy.deepcopy(after)
        reordered["profiles"] = list(reversed(reordered["profiles"]))
        self.assertEqual([], verify.target_preflight(reordered, "android"))
        self.assertTrue(any("activeProfile[profile.future-B]" in issue.path for issue in verify.target_activation_review(reordered, "android")))

    def test_post_adoption_rule_edit_and_period_rollover_keep_lineage_frozen(self):
        doc = self.load("adoption-after.json")
        profile = doc["profiles"][1]
        initial_rule = profile["ruleRef"]
        initial_receipt = copy.deepcopy(doc["paycheckReceipts"][0])
        initial_adoption = copy.deepcopy(doc["adoptions"][0])
        initial_source_profile = copy.deepcopy(doc["profiles"][0])
        initial_adopted_period = doc["adoptions"][0]["adoptedPeriodRef"]

        next_rule = copy.deepcopy(next(r for r in doc["ruleSnapshots"] if r["id"] == initial_rule))
        next_rule["id"] = "rule.ios-adopted-1.v2"
        next_rule["version"] = "confirmed-2"
        next_rule["hourlyRate"] = "21.00"
        next_rule["confirmedAtEpochSeconds"] += 60
        doc["ruleSnapshots"].append(next_rule)
        doc["identityCrosswalk"].append({"entityType":"ruleSnapshot","portableID":next_rule["id"],"originClient":"ios","originKind":"native","originLocalID":"ios-agreement-adopted-1@confirmed-2"})

        period_id = "period.ios-adopted-current-2"
        window_id = "window.ios-adopted-current-2"
        work_id = "snapshot.ios-adopted-current-2"
        zone = ZoneInfo("America/Denver")
        start = dt.datetime(2026, 10, 26, 0, 0, tzinfo=zone)
        end = dt.datetime(2026, 11, 2, 0, 0, tzinfo=zone)
        archived = int(start.timestamp())
        for kind, pid, local in [
            ("period", period_id, "ios-period-adopted-2"),
            ("periodWindow", window_id, "ios-window-adopted-2"),
            ("workSnapshot", work_id, "ios-work-snapshot-adopted-2"),
        ]:
            doc["identityCrosswalk"].append({"entityType":kind,"portableID":pid,"originClient":"ios","originKind":"native","originLocalID":local})
        change = {"id":"ruleChange.post-adoption-1","profileRef":profile["id"],"periodRef":period_id,"effectiveDate":"2026-10-26","sourceProfileRef":None,"ruleRef":next_rule["id"],"confirmed":True,"createdAtEpochSeconds":archived,"fieldsNotRecorded":[]}
        doc["ruleChanges"].append(change)
        doc["identityCrosswalk"].append({"entityType":"ruleChange","portableID":change["id"],"originClient":"ios","originKind":"native","originLocalID":"ios-rule-change-1"})

        old_period = next(p for p in doc["periods"] if p["id"] == initial_adopted_period)
        old_period["isCurrent"] = False
        old_period["closed"] = True
        old_period["archivedAtEpochSeconds"] = archived
        old_period["fieldsNotRecorded"].remove("archivedAtEpochSeconds")
        new_window = {"startDate":"2026-10-26","endDateInclusive":"2026-11-01","endExclusiveDate":"2026-11-02","timeZone":"America/Denver","boundaryModel":"exactInstants","startEpochSeconds":int(start.timestamp()),"endExclusiveEpochSeconds":int(end.timestamp()),"fieldsNotRecorded":[]}
        new_period = {"id":period_id,"profileRef":profile["id"],"calendarWindow":new_window,"cadence":"weekly","isCurrent":True,"closed":False,"archivedAtEpochSeconds":None,"calculationIssue":None,"ruleRef":next_rule["id"],"ruleChangeRefs":[change["id"]],"currentWorkSnapshotRef":work_id,"workSnapshotRefs":[work_id],"workCorrections":[],"windowRef":window_id,"ruleTimelineRefs":[],"calculation":None,"auditCompletedAtEpochSeconds":None,"workRevision":0,"fieldsNotRecorded":["archivedAtEpochSeconds","calculationIssue","calculation","auditCompletedAtEpochSeconds"]}
        new_work = {"id":work_id,"profileRef":profile["id"],"periodRef":period_id,"role":"currentLedger","revision":0,"sourceRef":"snapshot.ios-adopted-current-1","work":[],"fieldsNotRecorded":[]}
        doc["periods"].append(new_period)
        doc["workSnapshots"].append(new_work)
        profile["ruleRef"] = next_rule["id"]
        profile["baselineRuleRef"] = next_rule["id"]
        profile["currentPeriodRef"] = period_id
        profile["currentWorkSnapshotRef"] = work_id
        profile["ruleChangeRefs"].append(change["id"])
        doc["sourceInventory"]["ruleSnapshotCount"] += 1
        doc["sourceInventory"]["ruleChangeCount"] += 1
        doc["sourceInventory"]["periodCount"] += 1
        doc["sourceInventory"]["periodWindowCount"] += 1
        doc["sourceInventory"]["workSnapshotCount"] += 1

        # Later edits and rollover do not rewrite the original receipt or adoption proof.
        self.assertEqual(initial_receipt, doc["paycheckReceipts"][0])
        self.assertEqual(initial_adoption, doc["adoptions"][0])
        self.assertEqual(initial_source_profile, doc["profiles"][0])
        self.assertEqual(initial_rule, doc["adoptions"][0]["adoptedRuleRefs"][0])
        self.assertEqual([], verify.target_preflight(doc, "ios"))
        verify.validate_document(doc)

    def test_future_rule_changes_are_resolved_for_activation_and_may_follow_period_end(self):
        doc = self.load("adoption-after.json")
        profile = next(p for p in doc["profiles"] if p["id"] == doc["activeProfileRef"])
        period = next(p for p in doc["periods"] if p["isCurrent"] is True)
        source_rule = next(r for r in doc["ruleSnapshots"] if r["id"] == profile["ruleRef"])
        future_rule = copy.deepcopy(source_rule)
        future_rule.update({
            "id": "rule.future-premium.v1",
            "ruleID": "future-premium",
            "version": "1",
            "datePremiums": [{"date": "2026-11-07", "multiplier": "2"}],
        })
        doc["ruleSnapshots"].append(future_rule)
        doc["identityCrosswalk"].append({"entityType":"ruleSnapshot","portableID":future_rule["id"],"originClient":"ios","originKind":"native","originLocalID":"future-premium@1"})
        doc["sourceInventory"]["ruleSnapshotCount"] += 1

        profile_change = {
            "id": "ruleChange.profile-future-1", "profileRef": profile["id"],
            "periodRef": None, "effectiveDate": "2026-11-07", "sourceProfileRef": None,
            "ruleRef": future_rule["id"], "confirmed": True,
            "createdAtEpochSeconds": 1793034000, "fieldsNotRecorded": [],
        }
        period_change = {
            "id": "ruleChange.period-boundary-1", "profileRef": profile["id"],
            "periodRef": period["id"],
            "effectiveDate": period["calendarWindow"]["endExclusiveDate"],
            "sourceProfileRef": None, "ruleRef": future_rule["id"],
            "confirmed": True, "createdAtEpochSeconds": 1793034000,
            "fieldsNotRecorded": [],
        }
        for change in (profile_change, period_change):
            doc["ruleChanges"].append(change)
            doc["identityCrosswalk"].append({"entityType":"ruleChange","portableID":change["id"],"originClient":"ios","originKind":"native","originLocalID":change["id"]})
            doc["sourceInventory"]["ruleChangeCount"] += 1
        profile["ruleChangeRefs"].append(profile_change["id"])
        period["ruleChangeRefs"].append(period_change["id"])

        verify.validate_document(doc)
        reviews = verify.target_activation_review(doc, "web")
        self.assertTrue(any(
            issue.code == "activation.ruleFeatureNeedsReview"
            and "rule.future-premium.v1" in issue.path
            and issue.path.endswith(".datePremiums")
            for issue in reviews
        ))

    def test_selected_rule_decimal_precision_is_reviewed_without_refusing_frozen_file(self):
        doc = self.load("adoption-after.json")
        selected_rule = next(r for r in doc["ruleSnapshots"] if r["id"] == doc["profiles"][1]["ruleRef"])
        selected_rule["hourlyRate"] = "0.12345678901234567890123456789012345678901234567890"
        verify.validate_document(doc)
        for target in ("ios", "web", "android"):
            self.assertEqual([], verify.target_preflight(doc, target))
            self.assertTrue(any(
                issue.code == "activation.ruleNumberPrecisionNeedsReview"
                and issue.path.endswith(".hourlyRate")
                for issue in verify.target_activation_review(doc, target)
            ))

    def test_same_work_id_can_have_different_facts_in_distinct_frozen_snapshots(self):
        doc = self.load("adoption-after.json")
        original = doc["workSnapshots"][0]["work"][0]
        adopted = doc["workSnapshots"][2]["work"][0]
        self.assertEqual(original["id"], adopted["id"])
        adopted["startEpochSeconds"] += 3600
        adopted["endEpochSeconds"] += 3600
        verify.validate_document(doc)

    def test_duplicate_work_id_within_one_snapshot_is_rejected(self):
        doc = self.load("common-weekly-pending.json")
        doc["workSnapshots"][0]["work"].append(copy.deepcopy(doc["workSnapshots"][0]["work"][0]))
        doc["sourceInventory"]["workEntryCount"] += 1
        with self.assertRaises(verify.VerificationFailure) as caught:
            verify.validate_document(doc)
        self.assertEqual("identity.duplicateSnapshotWorkID", caught.exception.issue.code)

    def test_adoption_cannot_claim_legal_or_weekly_applicability_confirmation(self):
        doc = self.load("adoption-after.json")
        doc["adoptions"][0]["confirmedFields"].append("legalCoverage")
        with self.assertRaises(verify.VerificationFailure) as caught:
            verify.validate_document(doc)
        self.assertEqual("schema.enum", caught.exception.issue.code)

    def test_pending_weekly_source_period_failure_can_remain_not_comparable(self):
        doc = self.load("common-weekly-pending.json")
        receipt = doc["paycheckReceipts"][0]
        receipt["sourcePeriod"]["confirmed"] = False
        receipt["assessment"]["reportedPeriod"]["confirmed"] = False
        receipt["assessment"]["periodMatch"] = "unconfirmedPeriod"
        receipt["assessment"]["verdict"] = "notComparable"
        receipt["assessment"]["expectedGross"] = None
        receipt["assessment"]["difference"] = None
        receipt["assessment"]["comparisons"] = []
        receipt["assessment"]["reviewReasons"] = ["The paycheck work period has not been confirmed from source dates."]
        verify.validate_document(doc)

    def test_nested_unknown_array_is_null_but_recorded_empty_array_stays_empty(self):
        known_empty = self.load("common-weekly-pending.json")
        known_assessment = known_empty["paycheckReceipts"][0]["assessment"]
        self.assertEqual([], known_assessment["weeklyReviewRefs"])
        self.assertNotIn("weeklyReviewRefs", known_assessment["fieldsNotRecorded"])
        verify.validate_document(known_empty)

        unknown = copy.deepcopy(known_empty)
        unknown_assessment = unknown["paycheckReceipts"][0]["assessment"]
        unknown_assessment["weeklyReviewRefs"] = None
        unknown_assessment["fieldsNotRecorded"].append("weeklyReviewRefs")
        verify.validate_document(unknown)
        self.assertIsNone(unknown_assessment["weeklyReviewRefs"])
        self.assertIn("weeklyReviewRefs", unknown_assessment["fieldsNotRecorded"])

    def test_ios_frozen_weekly_mapping_reason_is_recognized_without_rewriting(self):
        doc = self.load("common-weekly-pending.json")
        receipt = doc["paycheckReceipts"][0]
        receipt["assessment"]["reviewReasons"] = [verify.IOS_WEEKLY_MAPPING_REVIEW_REASON]
        verify.validate_document(doc)
        self.assertEqual(verify.IOS_WEEKLY_MAPPING_REVIEW_REASON, receipt["assessment"]["reviewReasons"][0])

    def test_web_frozen_weekly_pending_reason_is_recognized_without_rewriting(self):
        doc = self.load("common-weekly-pending.json")
        receipt = doc["paycheckReceipts"][0]
        receipt["assessment"]["reviewReasons"] = [verify.WEB_WEEKLY_REVIEW_PENDING_REASON]
        verify.validate_document(doc)
        self.assertEqual(verify.WEB_WEEKLY_REVIEW_PENDING_REASON, receipt["assessment"]["reviewReasons"][0])

    def test_unrelated_weekly_pending_text_cannot_satisfy_weekly_reason_guard(self):
        doc = self.load("common-weekly-pending.json")
        receipt = doc["paycheckReceipts"][0]
        receipt["assessment"]["reviewReasons"] = ["A separate weekly schedule review is pending."]
        with self.assertRaises(verify.VerificationFailure) as caught:
            verify.validate_document(doc)
        self.assertEqual("receipt.pendingWeeklyReasonLost", caught.exception.issue.code)

    def test_schema_verifier_fails_closed_on_unimplemented_assertions(self):
        schema = verify.load_json(verify.SCHEMA_PATH)
        self.assertEqual([], verify.schema_vocabulary_issues(schema))
        schema["$defs"]["decimal"]["exclusiveMinimum"] = 0
        self.assertEqual("schema.assertionUnsupported", verify.schema_vocabulary_issues(schema)[0].code)

    def test_repeating_decimal_trace_strings_survive_validation_and_json_roundtrip(self):
        schema = self.load_schema()
        traces = [
            {
                "workedSeconds": "1",
                "rate": "50",
                "hours": "0.0002777777777777777777777777777777777777",
                "unroundedAmount": "0.013888888888888888888888888888888888888",
            },
            {
                "workedSeconds": "60",
                "rate": "50",
                "hours": "0.016666666666666666666666666666666666666",
                "unroundedAmount": "0.8333333333333333333333333333333333333",
            },
            {
                "workedSeconds": "1",
                "rate": "0.00000001",
                "hours": "0.0002777777777777777777777777777777777777",
                "unroundedAmount": "0.000000000002777777777777777777777777777777777777",
            },
        ]
        for trace in traces:
            for field in ("rate", "hours", "unroundedAmount"):
                self.assertEqual(
                    [], verify.schema_issues(
                        trace[field], {"$ref": "#/$defs/nonnegativeDecimal"}, root=schema
                    )
                )
        self.assertEqual(
            [], verify.schema_issues(
                "0." + "1" * 128,
                {"$ref": "#/$defs/nonnegativeDecimal"},
                root=schema,
            )
        )
        self.assertTrue(
            verify.schema_issues(
                "0." + "1" * 129,
                {"$ref": "#/$defs/nonnegativeDecimal"},
                root=schema,
            )
        )

        original = traces[1]["hours"]
        changed_after_28_digits = original[:-1] + ("5" if original[-1] != "5" else "4")
        with localcontext() as context:
            context.prec = verify.DECIMAL_VALIDATION_PRECISION
            self.assertNotEqual(Decimal(original), Decimal(changed_after_28_digits))

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "traces.json"
            path.write_text(json.dumps(traces, separators=(",", ":")), encoding="utf-8")
            restored = verify.load_json(path)
        self.assertEqual(traces, restored)
        self.assertEqual(original, restored[1]["hours"])
        self.assertGreaterEqual(verify.DECIMAL_VALIDATION_PRECISION, 24 + 128 + 32)

    def test_verifier_uses_explicit_precision_for_38_digit_arithmetic(self):
        expected = Decimal("10000000000000000000000000000000000001")
        observed = {}

        def arithmetic_probe(_doc):
            observed["precision"] = getcontext().prec
            observed["sum"] = Decimal("10000000000000000000000000000000000000") + Decimal(1)

        with patch.object(verify, "_validate_document", side_effect=arithmetic_probe):
            verify.validate_document({})
        self.assertEqual(verify.DECIMAL_VALIDATION_PRECISION, observed["precision"])
        self.assertEqual(expected, observed["sum"])

    def load_schema(self):
        return verify.load_json(verify.SCHEMA_PATH)

    def test_duplicate_json_keys_and_float_numbers_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            path.write_text('{"x":1,"x":2}', encoding="utf-8")
            with self.assertRaises(ValueError):
                verify.load_json(path)
            path.write_text('{"amount":1.25}', encoding="utf-8")
            with self.assertRaises(ValueError):
                verify.load_json(path)

    def test_ocr_source_scalars_keep_high_precision_and_exponent_strings(self):
        doc = self.load("adoption-after.json")
        doc["paycheckReceipts"][0]["lineFacts"]["suggestions"] = [{
            "field": "grossPay",
            "value": "800.00",
            "sourceText": "800.00",
            "region": {"page": 0, "x": "1.2345678901234568e-1", "y": "0.5", "width": "0.25", "height": "0.125"},
            "confidence": "9.999999999999998e-1",
            "reason": None,
        }]
        verify.validate_document(doc)


if __name__ == "__main__":
    unittest.main()
