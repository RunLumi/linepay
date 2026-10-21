#!/usr/bin/env python3
"""Independent standard-library verifier for portable financial-state v1."""
from __future__ import annotations

import argparse
import base64
import binascii
import copy
import datetime as dt
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation, localcontext
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

ROOT = Path(__file__).resolve().parent
SCHEMA_PATH = ROOT / "schema-v1.json"
COMMON_PATH = ROOT / "fixtures" / "common-weekly-pending.json"
REFUSAL_PATH = ROOT / "fixtures" / "refusal-cases-v1.json"
MAX_FINANCIAL_BYTES = 8 * 1024 * 1024
MAX_ENCRYPTED_FILE_BYTES = 64 * 1024 * 1024
# The wire grammar admits at most 24 integer and 128 fractional digits. Keep validation
# arithmetic comfortably above the maximum operand width plus realistic aggregate counts.
DECIMAL_VALIDATION_PRECISION = 256


@dataclass(frozen=True)
class Issue:
    code: str
    path: str
    message: str

    def __str__(self) -> str:
        return f"{self.code} at {self.path}: {self.message}"


class VerificationFailure(Exception):
    def __init__(self, issue: Issue):
        super().__init__(str(issue))
        self.issue = issue


def _reject_float(text: str) -> Any:
    raise ValueError(f"JSON floating-point number is forbidden: {text}")


def _reject_constant(text: str) -> Any:
    raise ValueError(f"Non-finite JSON number is forbidden: {text}")


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=_unique_object,
        parse_float=_reject_float,
        parse_constant=_reject_constant,
    )


def _json_key(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _schema_type_ok(value: Any, kind: str) -> bool:
    if kind == "object":
        return isinstance(value, dict)
    if kind == "array":
        return isinstance(value, list)
    if kind == "string":
        return isinstance(value, str)
    if kind == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if kind == "number":
        return isinstance(value, (int, Decimal)) and not isinstance(value, bool)
    if kind == "boolean":
        return isinstance(value, bool)
    if kind == "null":
        return value is None
    return False


SUPPORTED_SCHEMA_ASSERTIONS = {
    "$ref", "anyOf", "const", "enum", "type", "minLength", "maxLength", "pattern",
    "minimum", "maximum", "minItems", "maxItems", "uniqueItems", "items", "required",
    "additionalProperties",
}
SCHEMA_METADATA = {"$schema", "$id", "title", "description", "contentEncoding"}


def schema_vocabulary_issues(schema: dict[str, Any]) -> list[Issue]:
    """Fail closed when the pinned schema grows an assertion this verifier does not implement."""
    issues: list[Issue] = []

    def visit(node: Any, path: str) -> None:
        if not isinstance(node, dict):
            issues.append(Issue("schema.definitionShape", path, "schema node must be an object"))
            return
        allowed = SUPPORTED_SCHEMA_ASSERTIONS | SCHEMA_METADATA | {"$defs", "properties"}
        unknown = node.keys() - allowed
        for key in sorted(unknown):
            issues.append(Issue("schema.assertionUnsupported", f"{path}.{key}", "verifier does not implement this schema keyword"))
        if "additionalProperties" in node and node["additionalProperties"] is not False:
            issues.append(Issue("schema.assertionUnsupported", f"{path}.additionalProperties", "only the closed-object form is supported"))
        for container_name in ("$defs", "properties"):
            container = node.get(container_name)
            if container is not None:
                if not isinstance(container, dict):
                    issues.append(Issue("schema.definitionShape", f"{path}.{container_name}", "schema map must be an object"))
                else:
                    for key, child in container.items():
                        visit(child, f"{path}.{container_name}.{key}")
        if "items" in node:
            visit(node["items"], f"{path}.items")
        if "anyOf" in node:
            branches = node["anyOf"]
            if not isinstance(branches, list):
                issues.append(Issue("schema.definitionShape", f"{path}.anyOf", "anyOf must be an array"))
            else:
                for index, child in enumerate(branches):
                    visit(child, f"{path}.anyOf[{index}]")

    visit(schema, "schema")
    return issues


def schema_issues(value: Any, schema: dict[str, Any], path: str = "$", root: dict[str, Any] | None = None) -> list[Issue]:
    root = root or schema
    issues: list[Issue] = []
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/$defs/"):
            return [Issue("schema.ref", path, f"unsupported schema reference {ref}")]
        name = ref.removeprefix("#/$defs/")
        target = root.get("$defs", {}).get(name)
        if target is None:
            return [Issue("schema.ref", path, f"unknown schema definition {name}")]
        issues.extend(schema_issues(value, target, path, root))
    if "anyOf" in schema:
        branch_results = [schema_issues(value, branch, path, root) for branch in schema["anyOf"]]
        if not any(not result for result in branch_results):
            issues.append(Issue("schema.anyOf", path, "value does not match any allowed shape"))
    if "const" in schema and value != schema["const"]:
        issues.append(Issue("schema.const", path, f"expected {schema['const']!r}"))
    if "enum" in schema and value not in schema["enum"]:
        issues.append(Issue("schema.enum", path, "value is outside the closed enum"))
    expected = schema.get("type")
    if expected is not None:
        expected_types = expected if isinstance(expected, list) else [expected]
        if not any(_schema_type_ok(value, item) for item in expected_types):
            return issues + [Issue("schema.type", path, f"expected {expected_types}, got {type(value).__name__}")]
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            issues.append(Issue("schema.minLength", path, "string is shorter than allowed"))
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            issues.append(Issue("schema.maxLength", path, "string is longer than allowed"))
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            issues.append(Issue("schema.pattern", path, "string does not match the required pattern"))
    if isinstance(value, (int, Decimal)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            issues.append(Issue("schema.minimum", path, "number is below the allowed minimum"))
        if "maximum" in schema and value > schema["maximum"]:
            issues.append(Issue("schema.maximum", path, "number is above the allowed maximum"))
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            issues.append(Issue("schema.minItems", path, "array has too few items"))
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            issues.append(Issue("schema.maxItems", path, "array has too many items"))
        if schema.get("uniqueItems"):
            encoded = [_json_key(item) for item in value]
            if len(set(encoded)) != len(encoded):
                issues.append(Issue("schema.uniqueItems", path, "array contains duplicates"))
        item_schema = schema.get("items")
        if item_schema:
            for index, item in enumerate(value):
                issues.extend(schema_issues(item, item_schema, f"{path}[{index}]", root))
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                issues.append(Issue("schema.required", f"{path}.{key}", "required property is missing"))
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for key in value.keys() - props.keys():
                issues.append(Issue("schema.additionalProperties", f"{path}.{key}", "unknown property is forbidden"))
        for key, item in value.items():
            if key in props:
                issues.extend(schema_issues(item, props[key], f"{path}.{key}", root))
    return issues


def _fail(code: str, path: str, message: str) -> None:
    raise VerificationFailure(Issue(code, path, message))


def _zone(value: str, path: str) -> ZoneInfo:
    try:
        return ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError):
        _fail("time.zone", path, "unknown IANA timezone")
        raise AssertionError("unreachable")


def _date(value: str, path: str) -> dt.date:
    try:
        return dt.date.fromisoformat(value)
    except (TypeError, ValueError):
        _fail("time.date", path, "invalid calendar date")
        raise AssertionError("unreachable")


def _local_midnight_epoch(day: dt.date, zone: ZoneInfo) -> int:
    return int(dt.datetime.combine(day, dt.time.min, tzinfo=zone).timestamp())


def _has_marker(obj: dict[str, Any], field: str) -> bool:
    markers = obj.get("fieldsNotRecorded", [])
    return field in markers or any(marker.startswith(field + ".") for marker in markers)


def _marker_value(obj: dict[str, Any], dotted_path: str) -> Any:
    value: Any = obj
    for part in dotted_path.split("."):
        if not isinstance(value, dict) or part not in value:
            return _MISSING
        value = value[part]
    return value


_MISSING = object()


def _check_markers(obj: dict[str, Any], path: str) -> None:
    markers = obj.get("fieldsNotRecorded", [])
    for marker in markers:
        value = _marker_value(obj, marker)
        if value is _MISSING:
            _fail("source.invalidMarker", f"{path}.fieldsNotRecorded", f"marker {marker!r} does not name a field")
        if value is not None:
            _fail("source.markerContradiction", f"{path}.{marker}", "a field marked not-recorded must be null")


def _check_all_markers(doc: dict[str, Any]) -> None:
    def walk(value: Any, path: str) -> None:
        if isinstance(value, dict):
            if "fieldsNotRecorded" in value:
                _check_markers(value, path)
            for key, child in value.items():
                if key != "fieldsNotRecorded":
                    walk(child, f"{path}.{key}")
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{path}[{index}]")
    walk(doc, "$")


def _identity_maps(doc: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    rows = doc["identityCrosswalk"]
    by_id: dict[str, dict[str, Any]] = {}
    native_origins: set[tuple[str, str, str]] = set()
    for index, row in enumerate(rows):
        path = f"identityCrosswalk[{index}]"
        pid = row["portableID"]
        if pid in by_id:
            _fail("identity.duplicatePortableID", f"{path}.portableID", "portable ID is repeated")
        by_id[pid] = row
        local = row["originLocalID"]
        if row["originKind"] == "native" and local is None:
            _fail("identity.nativeWithoutLocalID", f"{path}.originLocalID", "native identity needs its source local ID")
        if row["originKind"] == "native" and local is not None:
            key = (row["entityType"], row["originClient"], local)
            if key in native_origins:
                _fail("identity.duplicateNativeOrigin", f"{path}.originLocalID", "native typed source ID maps more than once")
            native_origins.add(key)
    return by_id, {pid: row["entityType"] for pid, row in by_id.items()}


def _require_identity(identity_types: dict[str, str], pid: str | None, kind: str, path: str) -> None:
    if pid is None:
        return
    actual = identity_types.get(pid)
    if actual != kind:
        _fail("identity.missingOrWrongType", path, f"{pid!r} needs crosswalk type {kind}, got {actual!r}")


def _check_component_work_date(component: dict[str, Any], work: dict[str, Any], path: str) -> None:
    zone = _zone(work["timeZone"], path + ".workTimeZone")
    day = _date(component["localDate"], path + ".localDate")
    first_day = dt.datetime.fromtimestamp(work["startEpochSeconds"], zone).date()
    last_day = dt.datetime.fromtimestamp(work["endEpochSeconds"] - 1, zone).date()
    if day < first_day or day > last_day:
        _fail("reference.componentDateOutsideWork", path + ".localDate", "component date lies outside the selected work interval")


def _count_calculations(doc: dict[str, Any]) -> tuple[int, int, int]:
    components = workweeks = allocations = 0
    def visit(calculation: dict[str, Any] | None) -> None:
        nonlocal components, workweeks, allocations
        if calculation is None:
            return
        components += len(calculation["components"])
        weekly = calculation["weeklyRegularRate"]
        if weekly is not None:
            workweeks += 1
            allocations += len(weekly["allocations"])
    for period in doc["periods"]:
        visit(period["calculation"])
    for receipt in doc["paycheckReceipts"]:
        visit(receipt["calculation"])
    return components, workweeks, allocations


def _check_inventory(doc: dict[str, Any]) -> None:
    inv = doc["sourceInventory"]
    entries = [w for snap in doc["workSnapshots"] for w in snap["work"]]
    breaks = [b for w in entries for b in w["unpaidBreaks"]]
    corrections = [c for period in doc["periods"] for c in period["workCorrections"]]
    components, workweeks, allocations = _count_calculations(doc)
    expected = {
        "profileCount": len(doc["profiles"]),
        "adoptionCount": len(doc["adoptions"]),
        "ruleSnapshotCount": len(doc["ruleSnapshots"]),
        "ruleChangeCount": len(doc["ruleChanges"]),
        "ruleTimelineCount": len(doc["ruleTimelines"]),
        "periodCount": len(doc["periods"]),
        "periodWindowCount": sum(row["entityType"] == "periodWindow" for row in doc["identityCrosswalk"]),
        "workSnapshotCount": len(doc["workSnapshots"]),
        "workEntryCount": len(entries),
        "workBreakCount": len(breaks),
        "workCorrectionCount": len(corrections),
        "calculationComponentCount": components,
        "workweekCount": workweeks,
        "weeklyAllocationCount": allocations,
        "paycheckReceiptCount": len(doc["paycheckReceipts"]),
        "auditRevisionCount": sum(r["auditRevisionRef"] is not None for r in doc["paycheckReceipts"]),
        "attachmentCount": len(doc["attachments"]),
    }
    for key, value in expected.items():
        if inv[key] != value:
            _fail("inventory.countMismatch", f"sourceInventory.{key}", f"declares {inv[key]}, actual count is {value}")
    if inv["omittedFinancialRecordCount"] != 0:
        _fail("inventory.omittedRecords", "sourceInventory.omittedFinancialRecordCount", "portable files cannot omit financial records")
    if inv["unsupportedFinancialRecordKinds"] or inv["unsupportedDraftKinds"]:
        _fail("inventory.unsupportedRecords", "sourceInventory", "unsupported records must make the exporter refuse the whole file")
    for i, snapshot in enumerate(doc["workSnapshots"]):
        if snapshot["revision"] is None and not _has_marker(snapshot, "revision"):
            _fail("source.missingMarker", f"workSnapshots[{i}].revision", "an unavailable source revision ordinal requires a marker")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        producer = receipt["producer"]
        if producer["localStateSchema"] is None and not _has_marker(producer, "localStateSchema"):
            _fail("source.missingMarker", f"paycheckReceipts[{i}].producer.localStateSchema", "an unstamped producer schema version requires a marker")
        if receipt["targetCadence"] is None and not _has_marker(receipt, "targetCadence"):
            _fail("source.missingMarker", f"paycheckReceipts[{i}].targetCadence", "an unavailable target cadence requires a marker")


def _all_refs_and_identities(doc: dict[str, Any], schema: dict[str, Any]) -> None:
    rules = {r["id"]: r for r in doc["ruleSnapshots"]}
    profiles = {p["id"]: p for p in doc["profiles"]}
    periods = {p["id"]: p for p in doc["periods"]}
    work_snapshots = {s["id"]: s for s in doc["workSnapshots"]}
    timelines = {t["id"]: t for t in doc["ruleTimelines"]}
    receipts = {r["id"]: r for r in doc["paycheckReceipts"]}
    attachments = {a["id"] for a in doc["attachments"]}
    identity_rows, identity_types = _identity_maps(doc)

    if len(profiles) != len(doc["profiles"]) or len(rules) != len(doc["ruleSnapshots"]) or len(periods) != len(doc["periods"]) or len(work_snapshots) != len(doc["workSnapshots"]) or len(timelines) != len(doc["ruleTimelines"]) or len(receipts) != len(doc["paycheckReceipts"]) or len(attachments) != len(doc["attachments"]):
        _fail("identity.duplicateRecordID", "$", "a top-level record ID is repeated")
    if sum(period["isCurrent"] is True for period in doc["periods"]) > 1:
        _fail("period.multipleCurrent", "periods", "at most one known period may be marked as the current workspace")

    type_requirements = [
        ("profiles", "id", "profile"), ("ruleSnapshots", "id", "ruleSnapshot"),
        ("ruleChanges", "id", "ruleChange"), ("ruleTimelines", "id", "ruleTimeline"),
        ("periods", "id", "period"), ("workSnapshots", "id", "workSnapshot"),
        ("paycheckReceipts", "id", "paycheckReceipt"), ("attachments", "id", "attachment"),
        ("adoptions", "id", "profileAdoption"),
    ]
    for collection, field, kind in type_requirements:
        for index, record in enumerate(doc[collection]):
            _require_identity(identity_types, record[field], kind, f"{collection}[{index}].{field}")
    for i, period in enumerate(doc["periods"]):
        _require_identity(identity_types, period["windowRef"], "periodWindow", f"periods[{i}].windowRef")
        for correction in period["workCorrections"]:
            _require_identity(identity_types, correction["id"], "workCorrection", f"periods[{i}].workCorrections.id")
    for i, snapshot in enumerate(doc["workSnapshots"]):
        work_ids: set[str] = set()
        break_ids: set[str] = set()
        for j, work in enumerate(snapshot["work"]):
            if work["id"] in work_ids:
                _fail("identity.duplicateSnapshotWorkID", f"workSnapshots[{i}].work[{j}].id", "work IDs must be unique within one snapshot")
            work_ids.add(work["id"])
            _require_identity(identity_types, work["id"], "workEntry", f"workSnapshots[{i}].work[{j}].id")
            for k, b in enumerate(work["unpaidBreaks"]):
                if b["id"] in break_ids:
                    _fail("identity.duplicateSnapshotBreakID", f"workSnapshots[{i}].work[{j}].unpaidBreaks[{k}].id", "break IDs must be unique within one snapshot")
                break_ids.add(b["id"])
                _require_identity(identity_types, b["id"], "workBreak", f"workSnapshots[{i}].work[{j}].unpaidBreaks[{k}].id")
            if work["calloutEventRef"] is not None:
                _require_identity(identity_types, work["calloutEventRef"], "calloutEvent", f"workSnapshots[{i}].work[{j}].calloutEventRef")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        _require_identity(identity_types, receipt["paystubFacts"]["id"], "paystub", f"paycheckReceipts[{i}].paystubFacts.id")
        _require_identity(identity_types, receipt["targetWindowRef"], "periodWindow", f"paycheckReceipts[{i}].targetWindowRef")
        if receipt["auditRevisionRef"] is not None:
            _require_identity(identity_types, receipt["auditRevisionRef"], "auditRevision", f"paycheckReceipts[{i}].auditRevisionRef")
        for change_ref in receipt["targetRuleChangeRefs"]:
            if change_ref not in {change["id"] for change in doc["ruleChanges"]}:
                _fail("reference.danglingRuleChange", f"paycheckReceipts[{i}].targetRuleChangeRefs", f"rule change {change_ref!r} does not exist")

    def require_rule(rule_id: str | None, path: str) -> None:
        if rule_id is not None and rule_id not in rules:
            _fail("reference.danglingRule", path, f"rule snapshot {rule_id!r} does not exist")
    for i, profile in enumerate(doc["profiles"]):
        require_rule(profile["ruleRef"], f"profiles[{i}].ruleRef")
        require_rule(profile["baselineRuleRef"], f"profiles[{i}].baselineRuleRef")
        for refid in profile["ruleChangeRefs"]:
            if refid not in {c["id"] for c in doc["ruleChanges"]}:
                _fail("reference.danglingRuleChange", f"profiles[{i}].ruleChangeRefs", f"rule change {refid!r} does not exist")
        if profile["currentPeriodRef"] is not None and profile["currentPeriodRef"] not in periods:
            _fail("reference.danglingPeriod", f"profiles[{i}].currentPeriodRef", "current period does not exist")
        if profile["currentPeriodRef"] is not None and periods[profile["currentPeriodRef"]]["profileRef"] not in (None, profile["id"]):
            _fail("reference.currentPeriodProfileMismatch", f"profiles[{i}].currentPeriodRef", "current period belongs to another profile")
        if profile["currentWorkSnapshotRef"] is not None:
            snap = work_snapshots.get(profile["currentWorkSnapshotRef"])
            if snap is None or snap["role"] != "currentLedger" or snap["profileRef"] != profile["id"]:
                _fail("reference.invalidCurrentWork", f"profiles[{i}].currentWorkSnapshotRef", "current work must point to the profile's currentLedger snapshot")
        if profile["adoptedFromProfileRef"] is not None:
            if profile["adoptedFromProfileRef"] not in profiles or profile["adoptedFromProfileRef"] == profile["id"]:
                _fail("reference.invalidAdoptionSource", f"profiles[{i}].adoptedFromProfileRef", "adoption source must be another retained profile")
            if profile["id"] not in {a["adoptedProfileRef"] for a in doc["adoptions"]}:
                _fail("reference.missingAdoptionRecord", f"profiles[{i}].adoptedFromProfileRef", "adopted profile requires a typed adoption receipt")
    if doc["activeProfileRef"] is not None and doc["activeProfileRef"] not in profiles:
        _fail("reference.danglingActiveProfile", "activeProfileRef", "active profile does not exist")
    adopted_profiles: set[str] = set()
    allowed_confirmed_fields = set(schema["$defs"]["confirmedField"]["enum"])
    for i, adoption in enumerate(doc["adoptions"]):
        source_ref, adopted_ref = adoption["sourceProfileRef"], adoption["adoptedProfileRef"]
        if source_ref not in profiles or adopted_ref not in profiles:
            _fail("reference.danglingAdoptionProfile", f"adoptions[{i}]", "adoption source and destination profiles must be retained")
        if source_ref == adopted_ref or adopted_ref in adopted_profiles:
            _fail("reference.duplicateAdoption", f"adoptions[{i}]", "adoption destination must be distinct and have one lineage receipt")
        adopted_profiles.add(adopted_ref)
        if profiles[adopted_ref]["adoptedFromProfileRef"] != source_ref:
            _fail("reference.adoptionLineageMismatch", f"adoptions[{i}]", "profile lineage and adoption receipt disagree")
        source_profile = profiles[source_ref]
        if source_profile["currentPeriodRef"] is not None and adoption["sourcePeriodRef"] != source_profile["currentPeriodRef"]:
            _fail("reference.adoptionSourcePeriodMismatch", f"adoptions[{i}].sourcePeriodRef", "adoption must retain the source profile's exact current period")
        if source_profile["currentWorkSnapshotRef"] is not None and adoption["sourceWorkSnapshotRef"] != source_profile["currentWorkSnapshotRef"]:
            _fail("reference.adoptionSourceWorkMismatch", f"adoptions[{i}].sourceWorkSnapshotRef", "adoption must retain the source profile's exact current work snapshot")
        if any(field not in allowed_confirmed_fields for field in adoption["confirmedFields"]):
            _fail("adoption.confirmationScope", f"adoptions[{i}].confirmedFields", "confirmation fields name configured facts only; legal or weekly applicability cannot be cleared by adoption")
        for field, owner_ref in [("sourcePeriodRef", source_ref), ("adoptedPeriodRef", adopted_ref)]:
            refid = adoption[field]
            if refid is not None:
                period = periods.get(refid)
                allowed_owner = (None, owner_ref) if field == "sourcePeriodRef" else (owner_ref,)
                if period is None or period["profileRef"] not in allowed_owner:
                    _fail("reference.danglingAdoptionPeriod", f"adoptions[{i}].{field}", "adoption period is missing or belongs to another profile")
        for field, owner_ref in [("sourceWorkSnapshotRef", source_ref), ("adoptedWorkSnapshotRef", adopted_ref)]:
            refid = adoption[field]
            if refid is not None:
                snapshot = work_snapshots.get(refid)
                if snapshot is None or snapshot["profileRef"] != owner_ref:
                    _fail("reference.danglingAdoptionWork", f"adoptions[{i}].{field}", "adoption work snapshot is missing or belongs to another profile")
        for field in ("sourceRuleRefs", "adoptedRuleRefs"):
            refs = adoption[field]
            if not refs:
                _fail("reference.emptyAdoptionRules", f"adoptions[{i}].{field}", "adoption must identify the exact retained rule snapshots confirmed at that time")
            if any(refid not in rules for refid in refs):
                _fail("reference.danglingAdoptionRule", f"adoptions[{i}].{field}", "adoption rule snapshot does not exist")
            if field == "sourceRuleRefs":
                required_source_rules = {source_profile["ruleRef"]}
                if source_profile["baselineRuleRef"] is not None:
                    required_source_rules.add(source_profile["baselineRuleRef"])
                if not required_source_rules.issubset(set(refs)):
                    _fail("reference.incompleteAdoptionSourceRules", f"adoptions[{i}].{field}", "adoption must retain the source profile's current and baseline rules")
    for i, change in enumerate(doc["ruleChanges"]):
        effective_date = _date(change["effectiveDate"], f"ruleChanges[{i}].effectiveDate")
        if change["profileRef"] is not None and change["profileRef"] not in profiles:
            _fail("reference.danglingProfile", f"ruleChanges[{i}].profileRef", "profile does not exist")
        if change["periodRef"] is not None and change["periodRef"] not in periods:
            _fail("reference.danglingPeriod", f"ruleChanges[{i}].periodRef", "period does not exist")
        if change["periodRef"] is not None:
            window = periods[change["periodRef"]]["calendarWindow"]
            if window["startDate"] is not None and effective_date < _date(window["startDate"], f"periods[{change['periodRef']}].calendarWindow.startDate"):
                _fail("rule.changeOutsidePeriod", f"ruleChanges[{i}].effectiveDate", "effective date precedes its retained period")
            # A saved period may own future-effective configuration for the next period. This is
            # rule-selection metadata, not work or a calendar instant admitted to this window.
        if change["sourceProfileRef"] is not None and change["sourceProfileRef"] not in profiles:
            _fail("reference.danglingProfile", f"ruleChanges[{i}].sourceProfileRef", "source profile does not exist")
        require_rule(change["ruleRef"], f"ruleChanges[{i}].ruleRef")
    attachment_by_id = {a["id"]: a for a in doc["attachments"]}
    for i, rule in enumerate(doc["ruleSnapshots"]):
        for j, source in enumerate(rule["sources"] or []):
            document_ref = source["documentRef"]
            if document_ref is not None:
                attachment = attachment_by_id.get(document_ref)
                if attachment is None or attachment["kind"] != "sourceDocumentOriginal":
                    _fail("reference.danglingSourceDocument", f"ruleSnapshots[{i}].sources[{j}].documentRef", "source document reference needs its original attachment")
                if source["documentSHA256"] is not None and source["documentSHA256"] != attachment["sha256"]:
                    _fail("reference.sourceDocumentHashMismatch", f"ruleSnapshots[{i}].sources[{j}].documentSHA256", "source locator hash differs from original attachment")
    for i, timeline in enumerate(doc["ruleTimelines"]):
        if timeline["periodRef"] not in periods:
            _fail("reference.danglingPeriod", f"ruleTimelines[{i}].periodRef", "timeline period does not exist")
        require_rule(timeline["baselineRuleRef"], f"ruleTimelines[{i}].baselineRuleRef")
        change_by_id = {c["id"]: c for c in doc["ruleChanges"]}
        for refid in timeline["ruleChangeRefs"]:
            if refid not in change_by_id or change_by_id[refid]["periodRef"] not in (None, timeline["periodRef"]):
                _fail("reference.danglingRuleChange", f"ruleTimelines[{i}].ruleChangeRefs", f"rule change {refid!r} is missing or belongs to another period")
    for i, period in enumerate(doc["periods"]):
        if period["profileRef"] is not None and period["profileRef"] not in profiles:
            _fail("reference.danglingProfile", f"periods[{i}].profileRef", "profile does not exist")
        require_rule(period["ruleRef"], f"periods[{i}].ruleRef")
        for refid in period["ruleChangeRefs"]:
            change = next((c for c in doc["ruleChanges"] if c["id"] == refid), None)
            if change is None:
                _fail("reference.danglingRuleChange", f"periods[{i}].ruleChangeRefs", f"rule change {refid!r} does not exist")
            if change["periodRef"] not in (None, period["id"]):
                _fail("reference.ruleChangePeriodMismatch", f"periods[{i}].ruleChangeRefs", f"rule change {refid!r} belongs to another period")
        for refid in period["ruleTimelineRefs"]:
            if refid not in timelines or timelines[refid]["periodRef"] != period["id"]:
                _fail("reference.danglingRuleTimeline", f"periods[{i}].ruleTimelineRefs", f"rule timeline {refid!r} is missing or belongs to another period")
        snapshot_refs = set(period["workSnapshotRefs"])
        if period["currentWorkSnapshotRef"] is not None:
            snapshot_refs.add(period["currentWorkSnapshotRef"])
        for refid in snapshot_refs:
            snap = work_snapshots.get(refid)
            if snap is None or snap["periodRef"] not in (None, period["id"]):
                _fail("reference.danglingWorkSnapshot", f"periods[{i}].workSnapshotRefs", f"snapshot {refid!r} is missing or belongs to another period")
            if period["profileRef"] is not None and snap["profileRef"] != period["profileRef"]:
                _fail("reference.workSnapshotProfileMismatch", f"periods[{i}].workSnapshotRefs", f"snapshot {refid!r} belongs to another profile")
            if period["profileRef"] is not None and snap["profileRef"] != period["profileRef"]:
                _fail("reference.workSnapshotProfileMismatch", f"periods[{i}].workSnapshotRefs", f"snapshot {refid!r} belongs to another profile")
        if period["currentWorkSnapshotRef"] is not None and work_snapshots[period["currentWorkSnapshotRef"]]["role"] not in ("currentLedger", "periodRevision"):
            _fail("reference.invalidCurrentWork", f"periods[{i}].currentWorkSnapshotRef", "period current work must be a ledger or period revision")
        for correction in period["workCorrections"]:
            if correction["workSnapshotRef"] not in work_snapshots:
                _fail("reference.danglingWorkSnapshot", f"periods[{i}].workCorrections", "work correction source snapshot does not exist")
    for i, snap in enumerate(doc["workSnapshots"]):
        if snap["profileRef"] not in profiles:
            _fail("reference.danglingProfile", f"workSnapshots[{i}].profileRef", "work snapshot profile does not exist")
        if snap["periodRef"] is not None and snap["periodRef"] not in periods:
            _fail("reference.danglingPeriod", f"workSnapshots[{i}].periodRef", "work snapshot period does not exist")
        if snap["sourceRef"] is not None and snap["sourceRef"] not in identity_rows:
            _fail("reference.danglingSource", f"workSnapshots[{i}].sourceRef", "work snapshot source ID has no identity row")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        if receipt["periodRef"] is not None and receipt["periodRef"] not in periods:
            _fail("reference.danglingPeriod", f"paycheckReceipts[{i}].periodRef", "receipt period does not exist")
        if receipt["workSnapshotRef"] not in work_snapshots:
            _fail("reference.danglingWorkSnapshot", f"paycheckReceipts[{i}].workSnapshotRef", "receipt work snapshot does not exist")
        exact_work = {work["id"]: work for work in work_snapshots[receipt["workSnapshotRef"]]["work"]}
        exact_work_ids = set(exact_work)
        for rid in receipt["ruleRefs"]:
            require_rule(rid, f"paycheckReceipts[{i}].ruleRefs")
        for rid in receipt["targetRuleChangeRefs"]:
            if rid not in {c["id"] for c in doc["ruleChanges"]}:
                _fail("reference.danglingRuleChange", f"paycheckReceipts[{i}].targetRuleChangeRefs", f"rule change {rid!r} does not exist")
        for aid in receipt["attachmentRefs"]:
            if aid not in attachment_by_id:
                _fail("reference.danglingAttachment", f"paycheckReceipts[{i}].attachmentRefs", f"attachment {aid!r} does not exist")
        paystub_evidence = receipt["paystubFacts"]["evidenceRef"]
        if paystub_evidence is not None and paystub_evidence not in attachment_by_id:
            _fail("reference.danglingAttachment", f"paycheckReceipts[{i}].paystubFacts.evidenceRef", "paystub evidence attachment does not exist")
        if paystub_evidence is not None and attachment_by_id[paystub_evidence]["kind"] != "paystubOriginal":
            _fail("reference.attachmentKindMismatch", f"paycheckReceipts[{i}].paystubFacts.evidenceRef", "paystub evidence must reference a paystub original")
        _check_calculation(receipt.get("calculation"), f"paycheckReceipts[{i}].calculation", rules, periods, timelines, doc["ruleChanges"], identity_types)
        if receipt["calculation"] is not None:
            calculation = receipt["calculation"]
            needed_rules = {refid for refid in [calculation["primaryRuleRef"], *calculation["agreementSnapshotRefs"]] if refid is not None}
            needed_rules.update(component["appliedAgreement"]["ruleRef"] for component in calculation["components"] if component["appliedAgreement"] is not None)
            if not needed_rules.issubset(set(receipt["ruleRefs"])):
                _fail("reference.receiptRuleRefsIncomplete", f"paycheckReceipts[{i}].ruleRefs", "receipt must list every rule snapshot used by its frozen calculation")
            if not set(calculation["ruleChangeRefs"]).issubset(set(receipt["targetRuleChangeRefs"])):
                _fail("reference.receiptRuleChangesIncomplete", f"paycheckReceipts[{i}].targetRuleChangeRefs", "receipt must retain every rule change used by its calculation")
            components = {c["id"] for c in receipt["calculation"]["components"]}
            for j, component in enumerate(receipt["calculation"]["components"]):
                if component["workRef"] is not None and component["workRef"] not in exact_work_ids:
                    _fail("reference.componentWrongWorkSnapshot", f"paycheckReceipts[{i}].calculation.components[{j}].workRef", "component work ID is not in the receipt's selected frozen snapshot")
                if component["workRef"] is not None:
                    _check_component_work_date(component, exact_work[component["workRef"]], f"paycheckReceipts[{i}].calculation.components[{j}]")
            for j, comparison in enumerate(receipt["assessment"]["comparisons"]):
                for refid in comparison["componentRefs"]:
                    if refid not in components:
                        _fail("reference.danglingComponent", f"paycheckReceipts[{i}].assessment.comparisons[{j}].componentRefs", f"component {refid!r} is not in this frozen receipt")
        elif any(c["componentRefs"] for c in receipt["assessment"]["comparisons"]):
            _fail("reference.danglingComponent", f"paycheckReceipts[{i}].assessment.comparisons", "comparison refers to components but no frozen calculation exists")
        _check_pending_weekly(receipt, i)
    for i, period in enumerate(doc["periods"]):
        _check_calculation(period.get("calculation"), f"periods[{i}].calculation", rules, periods, timelines, doc["ruleChanges"], identity_types)
        calculation = period.get("calculation")
        if calculation is not None:
            exact_work = {}
            if period["currentWorkSnapshotRef"] is not None:
                exact_work = {work["id"]: work for work in work_snapshots[period["currentWorkSnapshotRef"]]["work"]}
            for j, component in enumerate(calculation["components"]):
                if component["workRef"] is not None and component["workRef"] not in exact_work:
                    _fail("reference.componentWrongWorkSnapshot", f"periods[{i}].calculation.components[{j}].workRef", "component work ID is not in the period's selected current snapshot")
                if component["workRef"] is not None:
                    _check_component_work_date(component, exact_work[component["workRef"]], f"periods[{i}].calculation.components[{j}]")

    windows_by_id: dict[str, tuple[dict[str, Any], Any]] = {}
    for period in doc["periods"]:
        windows_by_id[period["windowRef"]] = (period["calendarWindow"], period["cadence"])
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        candidate = (receipt["targetWindow"], receipt["targetCadence"])
        existing = windows_by_id.get(receipt["targetWindowRef"])
        if existing is not None and _json_key(existing) != _json_key(candidate):
            _fail("identity.periodWindowConflict", f"paycheckReceipts[{i}].targetWindowRef", "one window identity cannot describe different frozen boundaries or cadence")
        windows_by_id[receipt["targetWindowRef"]] = candidate

    expected_identity_ids: dict[str, set[str]] = {kind: set() for kind in {
        "profile", "ruleSnapshot", "ruleChange", "ruleTimeline", "period", "periodWindow",
        "workSnapshot", "workEntry", "workBreak", "workCorrection", "paycheckReceipt", "paystub",
        "auditRevision", "calculationComponent", "attachment", "calloutEvent", "workweek", "weeklyAllocation", "profileAdoption",
    }}
    for collection, kind in [("profiles", "profile"), ("ruleSnapshots", "ruleSnapshot"), ("ruleChanges", "ruleChange"), ("ruleTimelines", "ruleTimeline"), ("periods", "period"), ("workSnapshots", "workSnapshot"), ("paycheckReceipts", "paycheckReceipt"), ("attachments", "attachment"), ("adoptions", "profileAdoption")]:
        expected_identity_ids[kind].update(record["id"] for record in doc[collection])
    expected_identity_ids["periodWindow"].update(p["windowRef"] for p in doc["periods"])
    expected_identity_ids["periodWindow"].update(r["targetWindowRef"] for r in doc["paycheckReceipts"])
    expected_identity_ids["workCorrection"].update(c["id"] for p in doc["periods"] for c in p["workCorrections"])
    for snapshot in doc["workSnapshots"]:
        for work in snapshot["work"]:
            expected_identity_ids["workEntry"].add(work["id"])
            expected_identity_ids["workBreak"].update(b["id"] for b in work["unpaidBreaks"])
            if work["calloutEventRef"] is not None:
                expected_identity_ids["calloutEvent"].add(work["calloutEventRef"])
    for receipt in doc["paycheckReceipts"]:
        expected_identity_ids["paystub"].add(receipt["paystubFacts"]["id"])
        if receipt["auditRevisionRef"] is not None:
            expected_identity_ids["auditRevision"].add(receipt["auditRevisionRef"])
    for record in [*doc["periods"], *doc["paycheckReceipts"]]:
        calc = record.get("calculation")
        if calc is None:
            continue
        expected_identity_ids["calculationComponent"].update(c["id"] for c in calc["components"])
        if calc["weeklyRegularRate"] is not None:
            expected_identity_ids["workweek"].add(calc["weeklyRegularRate"]["workweekID"])
            expected_identity_ids["weeklyAllocation"].update(a["id"] for a in calc["weeklyRegularRate"]["allocations"])
    for pid, row in identity_rows.items():
        kind = row["entityType"]
        if pid not in expected_identity_ids.get(kind, set()):
            _fail("identity.unusedCrosswalkRow", "identityCrosswalk", f"{kind} identity {pid!r} is not referenced by a portable record")
    for kind, expected_ids in expected_identity_ids.items():
        actual_ids = {pid for pid, row in identity_rows.items() if row["entityType"] == kind}
        if actual_ids != expected_ids:
            missing = sorted(expected_ids - actual_ids)
            if missing:
                _fail("identity.missingCrosswalkRow", "identityCrosswalk", f"missing {kind} identity row for {missing[0]!r}")


def _check_calculation(calc: dict[str, Any] | None, path: str, rules: dict[str, Any], periods: dict[str, Any], timelines: dict[str, Any], rule_changes: list[dict[str, Any]], identity_types: dict[str, str]) -> None:
    if calc is None:
        return
    for key in [calc["primaryRuleRef"], *calc["agreementSnapshotRefs"]]:
        if key is not None and key not in rules:
            _fail("reference.danglingRule", path, f"rule snapshot {key!r} does not exist")
    rule_change_ids = {change["id"] for change in rule_changes}
    if any(key not in rule_change_ids for key in calc["ruleChangeRefs"]):
        _fail("reference.danglingRuleChange", path + ".ruleChangeRefs", "calculation references a missing rule change")
    if calc["ruleTimelineRef"] is not None and calc["ruleTimelineRef"] not in timelines:
        _fail("reference.danglingRuleTimeline", path + ".ruleTimelineRef", "rule timeline does not exist")
    rules_by_pair = {(r["ruleID"], r["version"]): r for r in rules.values()}
    for i, component in enumerate(calc["components"]):
        _require_identity(identity_types, component["id"], "calculationComponent", f"{path}.components[{i}].id")
        if component["workRef"] is not None and identity_types.get(component["workRef"]) != "workEntry":
            _fail("reference.danglingWorkEntry", f"{path}.components[{i}].workRef", "component work entry does not exist")
        agreement = component["appliedAgreement"]
        if agreement is not None:
            rule = rules.get(agreement["ruleRef"])
            if rule is None:
                _fail("reference.danglingRule", f"{path}.components[{i}].appliedAgreement.ruleRef", "component rule snapshot does not exist")
            if agreement["ruleID"] != rule["ruleID"] or agreement["version"] != rule["version"]:
                _fail("reference.ruleVersionMismatch", f"{path}.components[{i}].appliedAgreement", "component source ID/version does not match referenced snapshot")
    weekly = calc["weeklyRegularRate"]
    if weekly is not None:
        _require_identity(identity_types, weekly["workweekID"], "workweek", path + ".weeklyRegularRate.workweekID")
        for j, allocation in enumerate(weekly["allocations"]):
            _require_identity(identity_types, allocation["id"], "weeklyAllocation", f"{path}.weeklyRegularRate.allocations[{j}].id")
            if allocation["periodRef"] is not None and allocation["periodRef"] not in periods:
                _fail("reference.danglingPeriod", f"{path}.weeklyRegularRate.allocations[{j}].periodRef", "weekly allocation period does not exist")


IOS_WEEKLY_MAPPING_REVIEW_REASON = (
    "Complete workweek coverage and any additional weekly premium are not mapped into this "
    "paycheck comparison. A pay-period hour total or a separate weekly result does not "
    "establish that mapping. Review the complete workweek before relying on the gross difference."
)
WEB_WEEKLY_REVIEW_PENDING_REASON = "A separate complete-workweek review is pending."
WEEKLY_REVIEW_PENDING_REASON_TOKEN = "WEEKLY_REVIEW_PENDING"
RECOGNIZED_WEEKLY_PENDING_REASONS = frozenset({
    IOS_WEEKLY_MAPPING_REVIEW_REASON,
    WEB_WEEKLY_REVIEW_PENDING_REASON,
    WEEKLY_REVIEW_PENDING_REASON_TOKEN,
})


def _check_pending_weekly(receipt: dict[str, Any], index: int) -> None:
    pending = receipt["reviewFacts"]["weeklyReviewPending"]
    reasons = receipt["assessment"]["reviewReasons"]
    reason_pending = any(reason in RECOGNIZED_WEEKLY_PENDING_REASONS for reason in reasons)
    verdict = receipt["assessment"]["verdict"]
    path = f"paycheckReceipts[{index}]"
    if pending is True and verdict in {"matches", "possibleShortfall", "possibleOverpayment"}:
        _fail("receipt.pendingWeeklyLost", path, "weekly-review-pending cannot become a clean or directional verdict")
    if pending is True and verdict == "needsReview" and not reason_pending:
        _fail("receipt.pendingWeeklyReasonLost", path, "needsReview must retain the original weekly-pending reason")
    if pending is False and reason_pending:
        _fail("receipt.pendingWeeklyContradiction", path, "weekly pending reason conflicts with a false pending flag")
def _check_time(doc: dict[str, Any]) -> None:
    def check_window(w: dict[str, Any], path: str) -> None:
        if w["timeZone"] is not None:
            _zone(w["timeZone"], path + ".timeZone")
        has_start, has_end = w["startEpochSeconds"] is not None, w["endExclusiveEpochSeconds"] is not None
        if has_start != has_end:
            _fail("time.partialBoundary", path, "period boundaries must be both exact or both absent")
        if w["boundaryModel"] == "exactInstants" and not has_start:
            _fail("time.missingExactBoundary", path, "exactInstants requires both stored epoch boundaries")
        if w["boundaryModel"] == "localDatesOnly" and has_start:
            _fail("time.boundaryModelMismatch", path, "localDatesOnly cannot carry derived epoch boundaries")
        if w["boundaryModel"] == "exactInstants":
            zone = _zone(w["timeZone"], path + ".timeZone")
            start_date = _date(w["startDate"], path + ".startDate")
            end_date = _date(w["endExclusiveDate"], path + ".endExclusiveDate")
            if _local_midnight_epoch(start_date, zone) != w["startEpochSeconds"]:
                _fail("time.startBoundaryMismatch", path + ".startEpochSeconds", "exact instant is not the stored local start-of-day")
            if _local_midnight_epoch(end_date, zone) != w["endExclusiveEpochSeconds"]:
                _fail("time.endBoundaryMismatch", path + ".endExclusiveEpochSeconds", "exact instant is not the stored local end-exclusive date")
        if w["startDate"] is not None and w["endExclusiveDate"] is not None:
            if _date(w["endExclusiveDate"], path + ".endExclusiveDate") <= _date(w["startDate"], path + ".startDate"):
                _fail("time.reversedPeriod", path, "period end-exclusive date must follow start date")
            if w["endDateInclusive"] != (_date(w["endExclusiveDate"], path + ".endExclusiveDate") - dt.timedelta(days=1)).isoformat():
                _fail("time.inclusiveEndMismatch", path + ".endDateInclusive", "inclusive and end-exclusive dates disagree")
    for i, profile in enumerate(doc["profiles"]):
        if profile["timeZone"] is not None:
            _zone(profile["timeZone"], f"profiles[{i}].timeZone")
    for i, period in enumerate(doc["periods"]):
        check_window(period["calendarWindow"], f"periods[{i}].calendarWindow")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        check_window(receipt["targetWindow"], f"paycheckReceipts[{i}].targetWindow")
        for source_path, source_period in [
            (f"paycheckReceipts[{i}].sourcePeriod", receipt["sourcePeriod"]),
            (f"paycheckReceipts[{i}].assessment.reportedPeriod", receipt["assessment"]["reportedPeriod"]),
        ]:
            if source_period is None:
                continue
            if source_period["timeZone"] is not None:
                _zone(source_period["timeZone"], source_path + ".timeZone")
            if source_period["startDate"] is not None:
                _date(source_period["startDate"], source_path + ".startDate")
            if source_period["endDateInclusive"] is not None:
                _date(source_period["endDateInclusive"], source_path + ".endDateInclusive")
            if source_period["startDate"] is not None and source_period["endDateInclusive"] is not None and source_period["endDateInclusive"] < source_period["startDate"]:
                _fail("time.reversedSourcePeriod", source_path, "reported period end precedes start")
    seen_breaks: set[str] = set()
    for i, snapshot in enumerate(doc["workSnapshots"]):
        for j, work in enumerate(snapshot["work"]):
            path = f"workSnapshots[{i}].work[{j}]"
            zone = _zone(work["timeZone"], path + ".timeZone")
            start, end = work["startEpochSeconds"], work["endEpochSeconds"]
            if end <= start:
                _fail("time.invalidWorkRange", path, "work end must be after start")
            if dt.datetime.fromtimestamp(start, zone).tzinfo is None:
                _fail("time.invalidWorkInstant", path + ".startEpochSeconds", "invalid zoned instant")
            last_break_end = start
            for k, br in enumerate(work["unpaidBreaks"]):
                bp = f"{path}.unpaidBreaks[{k}]"
                if br["endEpochSeconds"] <= br["startEpochSeconds"]:
                    _fail("time.invalidBreakRange", bp, "break end must be after start")
                if br["startEpochSeconds"] < start or br["endEpochSeconds"] > end:
                    _fail("time.breakOutsideWork", bp, "break must fall inside its work interval")
                if br["startEpochSeconds"] < last_break_end:
                    _fail("time.overlappingBreaks", bp, "breaks must not overlap")
                last_break_end = br["endEpochSeconds"]
    _check_period_match_consistency(doc)


def _check_period_match_consistency(doc: dict[str, Any]) -> None:
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        assessment = receipt["assessment"]
        reported = assessment["reportedPeriod"]
        if assessment["periodMatch"] == "confirmedSamePeriod":
            w = receipt["targetWindow"]
            if reported is None or reported["confirmed"] is not True:
                _fail("receipt.periodMatchContradiction", f"paycheckReceipts[{i}].assessment", "confirmed match requires confirmed reported dates")
            if (reported["startDate"], reported["endDateInclusive"], reported["timeZone"]) != (w["startDate"], w["endDateInclusive"], w["timeZone"]):
                _fail("receipt.periodMatchContradiction", f"paycheckReceipts[{i}].assessment.reportedPeriod", "reported window differs from target period")
        if assessment["periodMatch"] == "differentPeriod" and (reported is None or reported["confirmed"] is not True):
            _fail("receipt.periodMatchContradiction", f"paycheckReceipts[{i}].assessment", "different-period status needs confirmed reported dates")
        if assessment["periodMatch"] == "unconfirmedPeriod" and reported is not None and reported["confirmed"] is True:
            _fail("receipt.periodMatchContradiction", f"paycheckReceipts[{i}].assessment", "unconfirmed-period status conflicts with confirmed source dates")


def _check_attachments(doc: dict[str, Any]) -> None:
    for i, item in enumerate(doc["attachments"]):
        path = f"attachments[{i}]"
        name = item["originalFilename"]
        if name in (".", "..") or "/" in name or "\\" in name or any(ord(ch) < 32 for ch in name):
            _fail("attachment.unsafeFilename", path + ".originalFilename", "filename must be a display name, never a path")
        try:
            data = base64.b64decode(item["bytesBase64"], validate=True)
        except (binascii.Error, ValueError):
            _fail("attachment.invalidBase64", path + ".bytesBase64", "invalid canonical base64")
        if base64.b64encode(data).decode("ascii") != item["bytesBase64"]:
            _fail("attachment.noncanonicalBase64", path + ".bytesBase64", "base64 must use canonical padding and alphabet")
        if len(data) != item["byteLength"]:
            _fail("attachment.byteLengthMismatch", path + ".byteLength", "declared byte length does not match decoded bytes")
        digest = hashlib.sha256(data).hexdigest()
        if digest != item["sha256"]:
            _fail("attachment.hashMismatch", path + ".sha256", "original bytes do not match SHA-256")
    full = json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if len(full) > MAX_ENCRYPTED_FILE_BYTES:
        _fail("size.encryptedFileLimit", "$", "portable payload exceeds the existing encrypted-file limit")
    financial = copy.deepcopy(doc)
    for attachment in financial["attachments"]:
        attachment["bytesBase64"] = ""
    reduced = json.dumps(financial, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if len(reduced) > MAX_FINANCIAL_BYTES:
        _fail("size.financialLimit", "$", "financial-state portion exceeds 8 MiB")


def _decimal(value: str, path: str) -> Decimal:
    try:
        number = Decimal(value)
    except InvalidOperation:
        _fail("number.invalidDecimal", path, "expected an exact decimal string")
    if not number.is_finite():
        _fail("number.nonFinite", path, "financial values must be finite")
    return number


def _require_nonnegative(value: str, path: str, *, strictly_positive: bool = False) -> None:
    number = _decimal(value, path)
    if number < 0 or (strictly_positive and number <= 0):
        _fail("number.outOfRange", path, "financial quantity is outside its allowed nonnegative range")


def _check_financial_ranges(doc: dict[str, Any]) -> None:
    for i, rule in enumerate(doc["ruleSnapshots"]):
        path = f"ruleSnapshots[{i}]"
        _require_nonnegative(rule["hourlyRate"], path + ".hourlyRate")
        if rule["effectiveStartDate"] is not None:
            _date(rule["effectiveStartDate"], path + ".effectiveStartDate")
        if rule["effectiveEndDateInclusive"] is not None:
            _date(rule["effectiveEndDateInclusive"], path + ".effectiveEndDateInclusive")
        if rule["effectiveStartDate"] is not None and rule["effectiveEndDateInclusive"] is not None and rule["effectiveEndDateInclusive"] < rule["effectiveStartDate"]:
            _fail("rule.reversedEffectiveDates", path, "rule end date precedes its start date")
        if rule["outsideScheduleMultiplier"] is not None and _decimal(rule["outsideScheduleMultiplier"], path + ".outsideScheduleMultiplier") < 1:
            _fail("number.outOfRange", path + ".outsideScheduleMultiplier", "outside-schedule multiplier must be at least 1")
        for j, tier in enumerate(rule["dailyOvertimeTiers"] or []):
            if _decimal(tier["afterHours"], f"{path}.dailyOvertimeTiers[{j}].afterHours") > 24:
                _fail("number.outOfRange", f"{path}.dailyOvertimeTiers[{j}].afterHours", "daily threshold cannot exceed 24 hours")
            if _decimal(tier["multiplier"], f"{path}.dailyOvertimeTiers[{j}].multiplier") < 1:
                _fail("number.outOfRange", f"{path}.dailyOvertimeTiers[{j}].multiplier", "premium multiplier must be at least 1")
        for collection in ("weekdayPremiums", "datePremiums"):
            for j, premium in enumerate(rule[collection] or []):
                if _decimal(premium["multiplier"], f"{path}.{collection}[{j}].multiplier") < 1:
                    _fail("number.outOfRange", f"{path}.{collection}[{j}].multiplier", "premium multiplier must be at least 1")
        if rule["calloutMinimumHours"] is not None:
            _require_nonnegative(rule["calloutMinimumHours"], path + ".calloutMinimumHours", strictly_positive=True)
        if rule["perDiemPerWorkDate"] is not None:
            _require_nonnegative(rule["perDiemPerWorkDate"]["amount"], path + ".perDiemPerWorkDate.amount")
            if rule["perDiemPerWorkDate"]["currency"] != rule["currency"]:
                _fail("money.currencyMismatch", path + ".perDiemPerWorkDate.currency", "per-diem currency must match its rule currency")
        if rule["weeklyOvertime"] is not None:
            _require_nonnegative(rule["weeklyOvertime"]["thresholdHours"], path + ".weeklyOvertime.thresholdHours")
        schedule = rule["regularSchedule"] or []
        for j, item in enumerate(schedule):
            if item["start"] >= item["end"]:
                _fail("rule.invalidScheduleRange", f"{path}.regularSchedule[{j}]", "schedule end must follow its start")
            for other in schedule[:j]:
                if item["weekday"] == other["weekday"] and item["start"] < other["end"] and other["start"] < item["end"]:
                    _fail("rule.overlappingSchedule", f"{path}.regularSchedule[{j}]", "same-day schedule windows must not overlap")
    for i, period in enumerate(doc["periods"]):
        calc = period["calculation"]
        if calc is not None:
            _check_calculation_ranges(calc, f"periods[{i}].calculation")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        path = f"paycheckReceipts[{i}]"
        facts = receipt["paystubFacts"]
        _require_nonnegative(facts["grossPay"], path + ".paystubFacts.grossPay")
        for field, amount in facts.items():
            if field in {"regularPay", "overtimePay", "doubleTimePay", "calloutPay", "perDiemPay"} and amount is not None:
                _require_nonnegative(amount, path + ".paystubFacts." + field)
        if facts["periodStartDate"] is not None and facts["periodEndDateInclusive"] is not None and facts["periodEndDateInclusive"] < facts["periodStartDate"]:
            _fail("time.reversedPaystubPeriod", path + ".paystubFacts", "paystub end date precedes start date")
        assessment = receipt["assessment"]
        if assessment["paidGross"]["currency"] != facts["currency"]:
            _fail("money.currencyMismatch", path + ".assessment.paidGross.currency", "assessment and paystub currencies differ")
        if assessment["expectedGross"] is not None and assessment["expectedGross"]["currency"] != facts["currency"]:
            _fail("money.currencyMismatch", path + ".assessment.expectedGross.currency", "assessment and paystub currencies differ")
        if assessment["difference"] is not None and assessment["difference"]["currency"] != facts["currency"]:
            _fail("money.currencyMismatch", path + ".assessment.difference.currency", "assessment and paystub currencies differ")
        if receipt["lineFacts"]["amounts"] is not None:
            for j, line in enumerate(receipt["lineFacts"]["amounts"]):
                _require_nonnegative(line["amount"]["amount"], f"{path}.lineFacts.amounts[{j}].amount")
                if line["amount"]["currency"] != facts["currency"]:
                    _fail("money.currencyMismatch", f"{path}.lineFacts.amounts[{j}].amount.currency", "line and paystub currencies differ")
        calc = receipt["calculation"]
        if calc is not None:
            if calc["currency"] != facts["currency"]:
                _fail("money.currencyMismatch", path + ".calculation.currency", "calculation and paystub currencies differ")
            _check_calculation_ranges(calc, path + ".calculation")
        _require_nonnegative(assessment["paidGross"]["amount"], path + ".assessment.paidGross.amount")
        if assessment["expectedGross"] is not None:
            _require_nonnegative(assessment["expectedGross"]["amount"], path + ".assessment.expectedGross.amount")
        for j, comparison in enumerate(assessment["comparisons"]):
            _require_nonnegative(comparison["expected"], f"{path}.assessment.comparisons[{j}].expected")
            _require_nonnegative(comparison["paid"], f"{path}.assessment.comparisons[{j}].paid")
            if comparison["currency"] != facts["currency"]:
                _fail("money.currencyMismatch", f"{path}.assessment.comparisons[{j}].currency", "comparison and paystub currencies differ")
        if receipt["reconciliation"] is not None:
            for field in ("expectedGross", "actualGross"):
                _require_nonnegative(receipt["reconciliation"][field]["amount"], f"{path}.reconciliation.{field}.amount")


def _check_calculation_ranges(calc: dict[str, Any], path: str) -> None:
    for i, component in enumerate(calc["components"]):
        cp = f"{path}.components[{i}]"
        _require_nonnegative(component["amount"]["amount"], cp + ".amount.amount")
        if component["amount"]["currency"] != calc["currency"]:
            _fail("money.currencyMismatch", cp + ".amount.currency", "component and calculation currencies differ")
        for field in ("baseRate", "unroundedAmount"):
            if component[field] is not None:
                _require_nonnegative(component[field]["amount"], cp + f".{field}.amount")
                if component[field]["currency"] != calc["currency"]:
                    _fail("money.currencyMismatch", cp + f".{field}.currency", "component and calculation currencies differ")
        if component["appliedAgreement"] is not None and component["appliedAgreement"]["hourlyRate"] is not None:
            _require_nonnegative(component["appliedAgreement"]["hourlyRate"]["amount"], cp + ".appliedAgreement.hourlyRate.amount")
            if component["appliedAgreement"]["hourlyRate"]["currency"] != calc["currency"]:
                _fail("money.currencyMismatch", cp + ".appliedAgreement.hourlyRate.currency", "applied rule and calculation currencies differ")
        if component["baseTimeNumerator"] is not None:
            _require_nonnegative(component["baseTimeNumerator"], cp + ".baseTimeNumerator")
        if component["multiplier"] is not None and _decimal(component["multiplier"], cp + ".multiplier") < 1:
            _fail("number.outOfRange", cp + ".multiplier", "pay component multiplier must be at least 1")
        if component["hours"] is not None and _decimal(component["hours"], cp + ".hours") < 0:
            _fail("number.outOfRange", cp + ".hours", "component hours cannot be negative")
    weekly = calc["weeklyRegularRate"]
    if weekly is not None:
        for field in ("includableRemuneration", "statutoryAdditionalPremium", "eligibleExtraPremiumCredit", "remainingAdditionalPremium", "cashRemuneration", "expectedCash"):
            _require_nonnegative(weekly[field]["amount"], path + f".weeklyRegularRate.{field}.amount")
        if weekly["regularRate"] is not None:
            _require_nonnegative(weekly["regularRate"]["amount"], path + ".weeklyRegularRate.regularRate.amount")
        for i, allocation in enumerate(weekly["allocations"]):
            _require_nonnegative(allocation["amount"]["amount"], f"{path}.weeklyRegularRate.allocations[{i}].amount.amount")
            _require_nonnegative(allocation["basis"]["amount"], f"{path}.weeklyRegularRate.allocations[{i}].basis.amount")


def _check_ocr_scalars(doc: dict[str, Any]) -> None:
    def bounded(value: str, path: str) -> None:
        try:
            number = Decimal(value)
        except InvalidOperation:
            _fail("ocr.invalidSourceScalar", path, "OCR source scalar is not a finite decimal spelling")
        if not number.is_finite() or number < 0 or number > 1:
            _fail("ocr.sourceScalarRange", path, "normalized OCR source scalar must be within [0, 1]")
    for i, receipt in enumerate(doc["paycheckReceipts"]):
        suggestions = receipt["lineFacts"]["suggestions"]
        if suggestions is None:
            continue
        for j, suggestion in enumerate(suggestions):
            bounded(suggestion["confidence"], f"paycheckReceipts[{i}].lineFacts.suggestions[{j}].confidence")
            region = suggestion["region"]
            if region is not None:
                for field in ("x", "y", "width", "height"):
                    bounded(region[field], f"paycheckReceipts[{i}].lineFacts.suggestions[{j}].region.{field}")


def validate_document(doc: Any) -> None:
    # Decimal construction and comparisons are exact, but any future relationship or aggregate
    # arithmetic in validation must not inherit Python's default precision of 28 digits.
    with localcontext() as context:
        context.prec = DECIMAL_VALIDATION_PRECISION
        _validate_document(doc)


def _validate_document(doc: Any) -> None:
    schema = load_json(SCHEMA_PATH)
    vocabulary_issues = schema_vocabulary_issues(schema)
    if vocabulary_issues:
        raise VerificationFailure(vocabulary_issues[0])
    issues = schema_issues(doc, schema, root=schema)
    if issues:
        raise VerificationFailure(issues[0])
    if not isinstance(doc, dict):
        _fail("schema.type", "$", "portable payload must be an object")
    _check_all_markers(doc)
    _check_inventory(doc)
    _all_refs_and_identities(doc, schema)
    _check_time(doc)
    _check_attachments(doc)
    _check_financial_ranges(doc)
    _check_ocr_scalars(doc)


TARGET_LIMITS = {
    "ios": {"maxProfiles": 100, "attachments": True, "workKinds": {"regular", "callout", "other"}},
    "web": {"maxProfiles": 100, "attachments": False, "workKinds": {"regular", "callout", "other"}},
    "android": {"maxProfiles": 100, "attachments": False, "workKinds": {"regular"}},
}


def _rule_decimal_values(rule: dict[str, Any]) -> list[tuple[str, str]]:
    """Return persisted numeric inputs that a selected native rule must parse."""
    values: list[tuple[str, str]] = [("hourlyRate", rule["hourlyRate"])]
    for field in ("outsideScheduleMultiplier", "calloutMinimumHours"):
        if rule[field] is not None:
            values.append((field, rule[field]))
    for field in ("dailyOvertimeTiers", "weekdayPremiums", "datePremiums"):
        for index, item in enumerate(rule[field] or []):
            for numeric_field, value in item.items():
                if numeric_field in {"afterHours", "multiplier"}:
                    values.append((f"{field}[{index}].{numeric_field}", value))
    if rule["perDiemPerWorkDate"] is not None:
        values.append(("perDiemPerWorkDate.amount", rule["perDiemPerWorkDate"]["amount"]["amount"]))
    if rule["weeklyOvertime"] is not None:
        values.append(("weeklyOvertime.thresholdHours", rule["weeklyOvertime"]["thresholdHours"]))
    return values


def _foundation_decimal_exact(value: str) -> bool:
    """Match the Foundation Decimal significant-digit and exponent representability envelope."""
    unsigned = value.removeprefix("-")
    whole, _, fraction = unsigned.partition(".")
    coefficient = (whole + fraction).lstrip("0")
    scale = len(fraction)
    while scale > 0 and coefficient.endswith("0"):
        coefficient = coefficient[:-1]
        scale -= 1
    if not coefficient:
        return True
    return len(coefficient) <= 38 and scale <= 128


def _target_rule_decimal_needs_review(value: str, target: str) -> bool:
    fraction_digits = len(value.partition(".")[2])
    if target in {"web", "android"}:
        return fraction_digits > 12
    return not _foundation_decimal_exact(value)


def target_preflight(doc: dict[str, Any], target: str) -> list[Issue]:
    """Hard whole-file storage/admission blockers, independent of calculator readiness."""
    if target not in TARGET_LIMITS:
        return [Issue("target.unknown", "$", f"unknown target {target!r}")]
    caps = TARGET_LIMITS[target]
    blockers: list[Issue] = []
    if len(doc["profiles"]) > caps["maxProfiles"]:
        blockers.append(Issue("target.profileLimit", "profiles", f"{target} can retain at most {caps['maxProfiles']} typed profiles"))
    if doc["attachments"] and not caps["attachments"]:
        blockers.append(Issue("target.attachmentsUnsupported", "attachments", f"{target} has no private original-attachment store"))
    if doc["sourceInventory"]["unsupportedFinancialRecordKinds"] or doc["sourceInventory"]["unsupportedDraftKinds"]:
        blockers.append(Issue("target.unsupportedRecords", "sourceInventory", "portable financial payload reports unsupported source records"))
    return blockers


def target_activation_review(doc: dict[str, Any], target: str) -> list[Issue]:
    """Return contexts that must stay gated/read-only until target-native rules are complete.

    `activeProfileRef` is the saved global/default profile for new periods. A period marked
    `isCurrent` independently owns the current workspace, even when its profile differs.
    These review notices do not block a complete typed restore; target-native calculation must
    remain gated until the specific context is compatible or explicitly adopted.
    """
    if target not in TARGET_LIMITS:
        return [Issue("target.unknown", "$", f"unknown target {target!r}")]
    reviews: list[Issue] = []
    profiles = {p["id"]: p for p in doc["profiles"]}
    rules = {r["id"]: r for r in doc["ruleSnapshots"]}
    rule_changes = {c["id"]: c for c in doc["ruleChanges"]}
    timelines = {t["id"]: t for t in doc["ruleTimelines"]}
    snapshots = {s["id"]: s for s in doc["workSnapshots"]}
    seen: set[tuple[str, str]] = set()

    def check_rules(context: str, rule_refs: set[str]) -> None:
        for rule_id in sorted(rule_refs):
            rule = rules.get(rule_id)
            if rule is None:
                continue
            path = f"{context}.ruleSnapshots[{rule_id}]"
            material_fields = ("regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier", "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate", "weeklyOvertime", "rounding")
            for field in material_fields:
                if rule[field] is None and _has_marker(rule, field):
                    key = (context, f"unknown:{rule_id}:{field}")
                    if key not in seen:
                        reviews.append(Issue("activation.ruleFieldNotRecorded", f"{path}.{field}", "material rule field was not recorded; keep this context read-only until confirmed"))
                        seen.add(key)
            unsupported: list[str] = []
            if target == "web":
                unsupported.extend(field for field in ("regularSchedule", "datePremiums", "weeklyOvertime") if rule[field] not in (None, []))
                if rule["outsideScheduleMultiplier"] not in (None, "1", "1.0", "1.00"):
                    unsupported.append("outsideScheduleMultiplier")
            elif target == "android":
                unsupported.extend(field for field in ("regularSchedule", "weekdayPremiums", "datePremiums", "weeklyOvertime") if rule[field] not in (None, []))
                if rule["dailyOvertimeTiers"] is not None and len(rule["dailyOvertimeTiers"]) > 1:
                    unsupported.append("dailyOvertimeTiers")
                if rule["calloutMinimumHours"] is not None:
                    unsupported.append("calloutMinimumHours")
            for field in unsupported:
                key = (context, f"unsupported:{rule_id}:{field}")
                if key not in seen:
                    reviews.append(Issue("activation.ruleFeatureNeedsReview", f"{path}.{field}", "typed rule is retained, but this target cannot calculate with the configured feature"))
                    seen.add(key)
            for field, value in _rule_decimal_values(rule):
                if _target_rule_decimal_needs_review(value, target):
                    key = (context, f"precision:{rule_id}:{field}")
                    if key not in seen:
                        reviews.append(Issue("activation.ruleNumberPrecisionNeedsReview", f"{path}.{field}", "typed rule value is retained, but this target cannot parse it within its exact native decimal bounds; confirm a new native configuration before calculation"))
                        seen.add(key)

    def changed_rule_refs(change_refs: list[str]) -> set[str]:
        return {
            rule_changes[change_ref]["ruleRef"]
            for change_ref in change_refs
            if change_ref in rule_changes
        }

    default_profile = profiles.get(doc["activeProfileRef"])
    if default_profile is not None:
        refs = {
            default_profile["ruleRef"],
            *changed_rule_refs(default_profile["ruleChangeRefs"]),
        }
        if default_profile["baselineRuleRef"] is not None:
            refs.add(default_profile["baselineRuleRef"])
        check_rules(f"activeProfile[{default_profile['id']}] (new-period default)", refs)

    current_periods = [p for p in doc["periods"] if p["isCurrent"] is True]
    for period in current_periods:
        context = f"currentPeriod[{period['id']}] workspace"
        refs = {
            refid for refid in [period["ruleRef"], *changed_rule_refs(period["ruleChangeRefs"])]
            if refid is not None
        }
        for timeline_id in period["ruleTimelineRefs"]:
            timeline = timelines[timeline_id]
            if timeline["baselineRuleRef"] is not None:
                refs.add(timeline["baselineRuleRef"])
            refs.update(changed_rule_refs(timeline["ruleChangeRefs"]))
        check_rules(context, refs)
        snapshot_ref = period["currentWorkSnapshotRef"]
        if snapshot_ref is None:
            if _has_marker(period, "currentWorkSnapshotRef"):
                reviews.append(Issue("activation.currentWorkSnapshotMissing", f"periods[{period['id']}].currentWorkSnapshotRef", "current workspace work snapshot was not recorded"))
            continue
        snapshot = snapshots[snapshot_ref]
        if target == "android":
            for index, work in enumerate(snapshot["work"]):
                if work["kind"] != "regular" or work["calloutEventRef"] is not None:
                    reviews.append(Issue("activation.workKindNeedsReview", f"periods[{period['id']}].workSnapshots[{snapshot_ref}].work[{index}]", "typed work is retained, but Android cannot calculate this work kind natively"))

    # Android and some legacy states keep a global ledger without a saved period object. Use it
    # only when the payload contains no known current period; never assign it to a future profile.
    if not current_periods and default_profile is not None and default_profile["currentWorkSnapshotRef"] is not None:
        snapshot_ref = default_profile["currentWorkSnapshotRef"]
        snapshot = snapshots[snapshot_ref]
        if target == "android":
            for index, work in enumerate(snapshot["work"]):
                if work["kind"] != "regular" or work["calloutEventRef"] is not None:
                    reviews.append(Issue("activation.workKindNeedsReview", f"activeProfile[{default_profile['id']}].workSnapshots[{snapshot_ref}].work[{index}]", "typed work is retained, but Android cannot calculate this work kind natively"))
    return reviews

def verify_refusal_cases() -> int:
    common = load_json(COMMON_PATH)
    cases = load_json(REFUSAL_PATH)["cases"]
    for case in cases:
        base_name = case.get("baseFixture", "common-weekly-pending.json")
        base = common if base_name == "common-weekly-pending.json" else load_json(ROOT / "fixtures" / base_name)
        mutated = copy.deepcopy(base)
        for operation in case.get("operations", []):
            _apply_operation(mutated, operation)
        if "target" in case:
            validate_document(mutated)
            issues = target_activation_review(mutated, case["target"]) if case.get("activationReview") else target_preflight(mutated, case["target"])
            got = {issue.code for issue in issues}
            expected = case["expectedCode"]
            if expected not in got:
                raise AssertionError(f"{case['id']}: expected target issue {expected}; got {sorted(got)}")
        else:
            try:
                validate_document(mutated)
            except VerificationFailure as failure:
                if failure.issue.code != case["expectedCode"]:
                    raise AssertionError(f"{case['id']}: expected {case['expectedCode']}; got {failure.issue}") from failure
            else:
                raise AssertionError(f"{case['id']}: mutation unexpectedly validated")
    return len(cases)


def _apply_operation(doc: Any, operation: dict[str, Any]) -> None:
    path = operation["path"].strip("/").split("/") if operation.get("path") else []
    target = doc
    for token in path[:-1]:
        token = token.replace("~1", "/").replace("~0", "~")
        target = target[int(token)] if isinstance(target, list) else target[token]
    if not path:
        raise ValueError("root replacement is not supported in refusal fixture")
    key = path[-1].replace("~1", "/").replace("~0", "~")
    if operation["op"] == "replace":
        if isinstance(target, list): target[int(key)] = operation["value"]
        else: target[key] = operation["value"]
    elif operation["op"] == "add":
        if isinstance(target, list):
            if key == "-": target.append(operation["value"])
            else: target.insert(int(key), operation["value"])
        else: target[key] = operation["value"]
    elif operation["op"] == "remove":
        if isinstance(target, list): target.pop(int(key))
        else: del target[key]
    else:
        raise ValueError(f"unsupported mutation op {operation['op']}")


def check(path: Path | None = None, target: str | None = None) -> None:
    doc = load_json(path or COMMON_PATH)
    validate_document(doc)
    review_count = 0
    if target:
        blockers = target_preflight(doc, target)
        if blockers:
            raise VerificationFailure(blockers[0])
        review_count = len(target_activation_review(doc, target))
    else:
        for candidate in TARGET_LIMITS:
            blockers = target_preflight(doc, candidate)
            if blockers:
                raise VerificationFailure(blockers[0])
            review_count += len(target_activation_review(doc, candidate))
    if path is None:
        count = verify_refusal_cases()
        print(f"PASS: common fixture retainable by all targets; {count} refusal cases passed; {review_count} activation-review notices")
    else:
        print(f"PASS: {path}; {review_count} activation-review notices")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    check_parser = sub.add_parser("check", help="verify the common fixture or a supplied portable payload")
    check_parser.add_argument("path", nargs="?", type=Path)
    check_parser.add_argument("--target", choices=sorted(TARGET_LIMITS))
    args = parser.parse_args(argv)
    try:
        check(args.path, args.target)
    except (VerificationFailure, ValueError, OSError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
