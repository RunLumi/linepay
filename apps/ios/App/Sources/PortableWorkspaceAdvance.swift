import Foundation

/// Workspace pointers can advance; source rule values, receipt inputs, and results stay frozen.
enum PortableWorkspaceAdvance {
    static func combine(
        _ source: PortableState, native: PortableState, crosswalk: [PortableLocalIdentity]
    ) throws -> PortableState {
        var fresh = try PortableStateMapping.object(native)
        var retained = try PortableStateMapping.object(source)
        var remapping: [String: String] = [:]
        for identity in crosswalk
        where [
            "profile", "period", "periodWindow", "workEntry", "workBreak", "paystub",
            "auditRevision", "attachment", "calloutEvent", "calculationComponent",
        ].contains(identity.entityType) {
            remapping[
                NativePortableStateWriter.portableID(
                    identity.entityType, identity.localID.uuidString)] = identity.portableID
        }
        for rule in native.ruleSnapshots {
            if let original = source.ruleSnapshots.first(where: {
                $0.ruleID == rule.ruleID && $0.version == rule.version
            }) {
                remapping[rule.id] = original.id
            }
        }
        fresh = remap(fresh, ids: remapping) as? [String: Any] ?? [:]
        let oldChanges = retained["ruleChanges"] as? [[String: Any]] ?? []
        for change in fresh["ruleChanges"] as? [[String: Any]] ?? [] {
            if let match = oldChanges.first(where: {
                ($0["effectiveDate"] as? String) == (change["effectiveDate"] as? String)
                    && ($0["ruleRef"] as? String) == (change["ruleRef"] as? String)
                    && ($0["profileRef"] as? String) == (change["profileRef"] as? String)
                    && ($0["periodRef"] as? String) == (change["periodRef"] as? String)
            }),
                let id = change["id"] as? String, let original = match["id"] as? String
            {
                remapping[id] = original
            }
        }
        fresh = remap(fresh, ids: remapping) as? [String: Any] ?? [:]
        // A future default profile is not the owner of an earlier selected work period.
        var newPeriods = fresh["periods"] as? [[String: Any]] ?? []
        var newSnapshots = fresh["workSnapshots"] as? [[String: Any]] ?? []
        var newProfiles = fresh["profiles"] as? [[String: Any]] ?? []
        var retainedProfiles = retained["profiles"] as? [[String: Any]] ?? []
        let originalPeriods = retained["periods"] as? [[String: Any]] ?? []
        for index in newPeriods.indices {
            guard let id = newPeriods[index]["id"] as? String,
                let old = originalPeriods.first(where: { $0["id"] as? String == id })
            else { continue }
            let owner =
                old["profileRef"] as? String
                ?? source.workSnapshots.first(where: {
                    $0.id == (old["currentWorkSnapshotRef"] as? String)
                })?.profileRef
            if let owner {
                newPeriods[index]["profileRef"] = old["profileRef"]
                for i in newSnapshots.indices where newSnapshots[i]["periodRef"] as? String == id {
                    newSnapshots[i]["profileRef"] = owner
                }
                for i in newProfiles.indices
                where newProfiles[i]["currentPeriodRef"] as? String == id
                    && newProfiles[i]["id"] as? String != owner
                {
                    if let prior = retainedProfiles.first(where: {
                        $0["id"] as? String == newProfiles[i]["id"] as? String
                    }) {
                        newProfiles[i]["currentPeriodRef"] = prior["currentPeriodRef"]
                        newProfiles[i]["currentWorkSnapshotRef"] = prior["currentWorkSnapshotRef"]
                    }
                }
                if newPeriods[index]["isCurrent"] as? Bool == true,
                    let i = retainedProfiles.firstIndex(where: { $0["id"] as? String == owner })
                {
                    retainedProfiles[i]["currentPeriodRef"] = id
                    retainedProfiles[i]["currentWorkSnapshotRef"] =
                        newPeriods[index]["currentWorkSnapshotRef"]
                }
            }
        }
        fresh["periods"] = newPeriods
        fresh["workSnapshots"] = newSnapshots
        fresh["profiles"] = newProfiles
        retained["profiles"] = retainedProfiles
        for key in [
            "profiles", "periods", "ruleSnapshots", "ruleChanges", "ruleTimelines", "workSnapshots",
            "paycheckReceipts", "attachments", "identityCrosswalk", "adoptions",
        ] {
            var oldRows = retained[key] as? [[String: Any]] ?? []
            for row in fresh[key] as? [[String: Any]] ?? [] {
                let idKey = key == "identityCrosswalk" ? "portableID" : "id"
                guard let id = row[idKey] as? String else { throw BackupError.invalidArchive }
                if let index = oldRows.firstIndex(where: { $0[idKey] as? String == id }) {
                    if key == "profiles" {
                        // A default with no native-owned selected period retains its last source context.
                        if row["currentPeriodRef"] is NSNull { continue }
                        oldRows[index]["currentPeriodRef"] = row["currentPeriodRef"]
                        oldRows[index]["currentWorkSnapshotRef"] = row["currentWorkSnapshotRef"]
                        oldRows[index]["fieldsNotRecorded"] =
                            (oldRows[index]["fieldsNotRecorded"] as? [String] ?? []).filter {
                                !["currentPeriodRef", "currentWorkSnapshotRef"].contains($0)
                            }
                    } else if key == "periods" {
                        guard let oldWindow = oldRows[index]["calendarWindow"] as? NSDictionary,
                            let newWindow = row["calendarWindow"] as? NSDictionary,
                            oldWindow == newWindow,
                            oldRows[index]["windowRef"] as? String == row["windowRef"] as? String,
                            oldRows[index]["cadence"] as? String == row["cadence"] as? String,
                            oldRows[index]["ruleRef"] as? String == row["ruleRef"] as? String
                        else {
                            throw BackupError.portableUnsupported(
                                "A changed imported period or rule context needs a new confirmed profile context. Use a full iPhone backup to preserve this correction."
                            )
                        }
                        let oldRef = oldRows[index]["currentWorkSnapshotRef"] as? String
                        let newRef = row["currentWorkSnapshotRef"] as? String
                        if oldRef != newRef, !(oldRows[index]["calculation"] is NSNull) {
                            throw BackupError.portableUnsupported(
                                "A saved standalone period calculation needs its original work context. Use a full iPhone backup before advancing this imported period."
                            )
                        }
                        let existing = oldRows[index]["workSnapshotRefs"] as? [String] ?? []
                        let added = row["workSnapshotRefs"] as? [String] ?? []
                        oldRows[index]["workSnapshotRefs"] =
                            existing + added.filter { !existing.contains($0) }
                        oldRows[index]["currentWorkSnapshotRef"] = row["currentWorkSnapshotRef"]
                        oldRows[index]["workRevision"] = row["workRevision"]
                        if !(row["auditCompletedAtEpochSeconds"] is NSNull) {
                            oldRows[index]["auditCompletedAtEpochSeconds"] =
                                row["auditCompletedAtEpochSeconds"]
                        }
                        oldRows[index]["isCurrent"] = row["isCurrent"]
                        oldRows[index]["closed"] = row["closed"]
                        oldRows[index]["archivedAtEpochSeconds"] = row["archivedAtEpochSeconds"]
                        if oldRows[index]["calculation"] is NSNull {
                            oldRows[index]["calculation"] = row["calculation"]
                        }
                        oldRows[index]["fieldsNotRecorded"] =
                            (oldRows[index]["fieldsNotRecorded"] as? [String] ?? []).filter {
                                field in
                                guard
                                    [
                                        "workRevision", "currentWorkSnapshotRef", "isCurrent",
                                        "closed", "archivedAtEpochSeconds",
                                        "auditCompletedAtEpochSeconds",
                                    ].contains(field)
                                else { return true }
                                return row[field] is NSNull
                            }
                    } else if key == "workSnapshots" || key == "paycheckReceipts"
                        || key == "attachments"
                    {
                        guard (oldRows[index] as NSDictionary) == (row as NSDictionary) else {
                            throw BackupError.portableUnsupported(
                                "A frozen imported record cannot be replaced during export.")
                        }
                    }
                    // Reuse original rule/change/crosswalk values and their source provenance.
                } else {
                    oldRows.append(row)
                }
            }
            retained[key] = oldRows
        }
        let selected = Set(
            (fresh["periods"] as? [[String: Any]] ?? []).filter { $0["isCurrent"] as? Bool == true }
                .compactMap { $0["id"] as? String })
        if var periods = retained["periods"] as? [[String: Any]], !selected.isEmpty {
            for index in periods.indices where periods[index]["isCurrent"] as? Bool == true {
                if let id = periods[index]["id"] as? String, !selected.contains(id) {
                    periods[index]["isCurrent"] = false
                }
            }
            retained["periods"] = periods
        }
        retained["activeProfileRef"] = source.activeProfileRef as Any? ?? NSNull()
        retained["source"] = fresh["source"]
        retained["exportedAtEpochSeconds"] = fresh["exportedAtEpochSeconds"]
        retained["sourceInventory"] = PortableStateMerger.inventory(retained)
        return try PortableStateCodec.decode(
            JSONSerialization.data(withJSONObject: retained, options: .sortedKeys))
    }

    private static let references: Set<String> = [
        "id", "portableID", "activeProfileRef", "profileRef", "sourceProfileRef",
        "adoptedProfileRef", "periodRef", "sourcePeriodRef", "adoptedPeriodRef", "workSnapshotRef",
        "sourceWorkSnapshotRef", "adoptedWorkSnapshotRef", "currentWorkSnapshotRef",
        "currentPeriodRef", "baselineRuleRef", "adoptedFromProfileRef", "ruleRef", "windowRef",
        "targetWindowRef", "auditRevisionRef", "workRef", "calloutEventRef", "documentRef",
        "evidenceRef", "primaryRuleRef", "ruleTimelineRef", "supersedesReceiptRef", "ruleRefs",
        "attachmentRefs", "componentRefs", "ruleChangeRefs", "targetRuleChangeRefs",
        "ruleTimelineRefs", "workSnapshotRefs", "sourceRuleRefs", "adoptedRuleRefs",
    ]

    private static func remap(_ value: Any, ids: [String: String], key: String = "") -> Any {
        if let string = value as? String, references.contains(key) { return ids[string] ?? string }
        if let rows = value as? [Any] { return rows.map { remap($0, ids: ids, key: key) } }
        if let object = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (childKey, child) in object {
                result[childKey] = remap(child, ids: ids, key: childKey)
            }
            return result
        }
        return value
    }
}
