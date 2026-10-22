import Foundation

/// Re-export can add explicitly confirmed native facts while retaining every frozen source record.
enum PortableStateMerger {
    static func merge(
        _ foreign: PortableState, native: PortableState, adoptions: [PortableNativeAdoption]
    ) throws -> PortableState {
        let localIdentities = foreign.identityCrosswalk.map {
            PortableLocalIdentity.make(entityType: $0.entityType, portableID: $0.portableID)
        }
        let merged = try PortableWorkspaceAdvance.combine(
            foreign, native: native, crosswalk: localIdentities)
        var combined = try PortableStateMapping.object(merged)
        if adoptions.contains(where: { $0.makesFutureDefault == true }) {
            combined["activeProfileRef"] = native.activeProfileRef
        }
        var profiles = combined["profiles"] as? [[String: Any]] ?? []
        var lineage = combined["adoptions"] as? [[String: Any]] ?? []
        var crosswalk = combined["identityCrosswalk"] as? [[String: Any]] ?? []
        for adoption in adoptions {
            let profile = NativePortableStateWriter.portableID(
                "profile", adoption.nativeProfileID.uuidString)
            let period = NativePortableStateWriter.portableID(
                "period", adoption.nativePeriodID.uuidString)
            let work = NativePortableStateWriter.portableID(
                "workSnapshot",
                adoption.nativePeriodID.uuidString + ":adoption:" + adoption.id.uuidString)
            let rule = NativePortableStateWriter.portableID(
                "ruleSnapshot", adoption.nativeRuleID + ":" + adoption.nativeRuleVersion)
            let id = NativePortableStateWriter.portableID("profileAdoption", adoption.id.uuidString)
            guard let index = profiles.firstIndex(where: { $0["id"] as? String == profile }) else {
                throw BackupError.invalidArchive
            }
            profiles[index]["adoptedFromProfileRef"] = adoption.sourceProfileRef
            lineage.append([
                "id": id, "sourceProfileRef": adoption.sourceProfileRef,
                "adoptedProfileRef": profile,
                "sourcePeriodRef": adoption.sourcePeriodRef as Any? ?? NSNull(),
                "adoptedPeriodRef": period,
                "sourceWorkSnapshotRef": adoption.sourceWorkSnapshotRef,
                "adoptedWorkSnapshotRef": work,
                "sourceRuleRefs": adoption.sourceRuleRefs, "adoptedRuleRefs": [rule],
                "confirmedAtEpochSeconds": adoption.confirmedEpochSeconds,
                "confirmedFields": adoption.portableConfirmedFields,
                "fieldsNotRecorded": [],
            ])
            crosswalk.append([
                "entityType": "profileAdoption", "portableID": id, "originClient": "ios",
                "originKind": "native", "originLocalID": adoption.id.uuidString,
            ])
        }
        combined["profiles"] = profiles
        combined["adoptions"] = lineage
        combined["identityCrosswalk"] = crosswalk
        combined["sourceInventory"] = inventory(combined)
        return try PortableStateCodec.decode(
            JSONSerialization.data(withJSONObject: combined, options: .sortedKeys))
    }

    static func inventory(_ value: [String: Any]) -> [String: Any] {
        func rows(_ key: String) -> [[String: Any]] { value[key] as? [[String: Any]] ?? [] }
        let work = rows("workSnapshots").flatMap { $0["work"] as? [[String: Any]] ?? [] }
        let calculations = (rows("periods") + rows("paycheckReceipts")).compactMap {
            $0["calculation"] as? [String: Any]
        }
        let weekly = calculations.compactMap { $0["weeklyRegularRate"] as? [String: Any] }
        return [
            "profileCount": rows("profiles").count,
            "ruleSnapshotCount": rows("ruleSnapshots").count,
            "ruleChangeCount": rows("ruleChanges").count,
            "ruleTimelineCount": rows("ruleTimelines").count,
            "periodCount": rows("periods").count, "workSnapshotCount": rows("workSnapshots").count,
            "workEntryCount": work.count,
            "workBreakCount": work.reduce(0) { $0 + (($1["unpaidBreaks"] as? [Any])?.count ?? 0) },
            "workCorrectionCount": rows("periods").reduce(0) {
                $0 + (($1["workCorrections"] as? [Any])?.count ?? 0)
            },
            "calculationComponentCount": calculations.reduce(0) {
                $0 + (($1["components"] as? [Any])?.count ?? 0)
            },
            "periodWindowCount": rows("identityCrosswalk").filter {
                $0["entityType"] as? String == "periodWindow"
            }.count,
            "paycheckReceiptCount": rows("paycheckReceipts").count,
            "auditRevisionCount": rows("paycheckReceipts").filter {
                !($0["auditRevisionRef"] is NSNull)
            }.count,
            "attachmentCount": rows("attachments").count, "adoptionCount": rows("adoptions").count,
            "workweekCount": weekly.count,
            "weeklyAllocationCount": weekly.reduce(0) {
                $0 + (($1["allocations"] as? [Any])?.count ?? 0)
            },
            "unsupportedFinancialRecordKinds": [] as [String],
            "unsupportedDraftKinds": [] as [String], "omittedFinancialRecordCount": 0,
        ]
    }
}
