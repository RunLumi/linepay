import CryptoKit
import Foundation
import LinePayDomain

/// Explicit field mapping; native Codable snapshots are never embedded as opaque client payloads.
enum NativePortableStateWriter {
    private static let null = NSNull()
    static func portableID(_ type: String, _ local: String) -> String {
        "ios:" + type + ":"
            + SHA256.hash(data: Data(local.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func export(
        _ state: AppPersistentState, files: [BackupArchive.EvidenceFile],
        adoptionSnapshots: [PortableNativeAdoption] = [], retainedSource: PortableState? = nil
    ) throws -> PortableState {
        try PortableStateMapping.inventory(state)
        var writer = Writer(
            state: state, files: files, adoptionSnapshots: adoptionSnapshots,
            retainedSource: retainedSource)
        return try writer.write()
    }

    private struct Writer {
        let state: AppPersistentState
        let files: [BackupArchive.EvidenceFile]
        let adoptionSnapshots: [PortableNativeAdoption]
        let retainedSource: PortableState?
        var identities: [[String: Any]] = []
        var rules: [String: [String: Any]] = [:]
        var originalRules: [String: AgreementSnapshot] = [:]
        var works: [[String: Any]] = []
        var periods: [[String: Any]] = []
        var receipts: [[String: Any]] = []
        var changes: [[String: Any]] = []
        var originals: [[String: Any]] = []

        mutating func identity(_ type: String, _ local: String) -> String {
            let portable = NativePortableStateWriter.portableID(type, local)
            if !identities.contains(where: { $0["portableID"] as? String == portable }) {
                identities.append([
                    "entityType": type, "portableID": portable, "originClient": "ios",
                    "originKind": "native", "originLocalID": local,
                ])
            }
            return portable
        }
        mutating func write() throws -> PortableState {
            guard (state.agreementDocuments ?? []).isEmpty else {
                throw BackupError.portableUnsupported(
                    "Imported agreement review records need a full iPhone backup.")
            }
            guard let profile = state.profile ?? state.portableCurrentProfile?.profile(in: state)
            else {
                throw BackupError.portableUnsupported(
                    "Configure a pay profile before exporting financial records.")
            }
            var profilesByID = [profile.id: profile]
            var ownerByPeriod: [UUID: UUID] = [:]
            if let active = state.activePeriod {
                let owner = try ownerProfile(
                    periodID: active.id, window: active.window, agreement: active.agreement,
                    zone: active.timeZoneIdentifier)
                profilesByID[owner.id] = owner
                ownerByPeriod[active.id] = owner.id
                try period(
                    id: active.id, window: active.window, agreement: active.agreement,
                    zone: active.timeZoneIdentifier,
                    entries: active.workEntries,
                    closed: false, archived: nil, issue: nil,
                    profileID: identity("profile", owner.id.uuidString),
                    paid: active.paystub, calculation: nil, reconciliation: active.reconciliation,
                    revisions: active.auditRevisions ?? [],
                    ruleChanges: active.agreementChanges ?? [],

                    auditCompleted: active.auditCompletedEpochSeconds,
                    workRevision: active.workRevision)
            }
            for completed in state.history {
                let owner = try ownerProfile(
                    periodID: completed.id, window: completed.window,
                    agreement: completed.agreement, zone: completed.timeZoneIdentifier)
                profilesByID[owner.id] = owner
                ownerByPeriod[completed.id] = owner.id
                try period(
                    id: completed.id, window: completed.window, agreement: completed.agreement,
                    zone: completed.timeZoneIdentifier,
                    entries: completed.workEntries,
                    closed: true, archived: completed.archivedEpochSeconds,
                    issue: completed.calculationIssue,
                    profileID: identity("profile", owner.id.uuidString), paid: completed.paystub,
                    calculation: completed.calculation,
                    reconciliation: completed.reconciliation,
                    revisions: completed.auditRevisions ?? [],
                    ruleChanges: completed.agreementChanges ?? [],

                    corrections: completed.workCorrections ?? [])
            }
            for adoption in adoptionSnapshots {
                if profilesByID[adoption.nativeProfileID] == nil {
                    profilesByID[adoption.nativeProfileID] = PayProfile(
                        id: adoption.nativeProfileID,
                        name: adoption.nativeProfileName ?? "Confirmed native adoption",
                        timeZoneIdentifier: adoption.nativeTimeZone,
                        agreement: adoption.nativeAgreement,
                        preferredCadence: adoption.nativeWindow.cadence,
                        baselineAgreement: adoption.nativeAgreement)
                }
                let adoptionProfileID = identity("profile", adoption.nativeProfileID.uuidString)
                _ = try rule(adoption.nativeAgreement)
                let retainedWork = snapshot(
                    adoption.nativeWork, periodID: adoption.nativePeriodID.uuidString,
                    profileID: adoptionProfileID, suffix: "adoption:" + adoption.id.uuidString,
                    role: "periodRevision")
                guard
                    let index = periods.firstIndex(where: {
                        $0["id"] as? String
                            == NativePortableStateWriter.portableID(
                                "period", adoption.nativePeriodID.uuidString)
                    })
                else { throw BackupError.invalidArchive }
                guard
                    (periods[index]["calendarWindow"] as? NSDictionary)
                        == (calendar(adoption.nativeWindow, adoption.nativeTimeZone) as NSDictionary)
                else {
                    throw BackupError.portableUnsupported(
                        "The adopted period context changed; use a full iPhone backup to preserve its original context."
                    )
                }
                var refs = periods[index]["workSnapshotRefs"] as? [String] ?? []
                refs.append(retainedWork)
                periods[index]["workSnapshotRefs"] = refs
            }
            for reference in try BackupArchive.evidence(in: state) {
                guard let file = files.first(where: { $0.id == reference.id }) else {
                    throw BackupError.missingEvidence
                }
                originals.append([
                    "id": identity("attachment", reference.id.uuidString),
                    "kind": "paystubOriginal",
                    "originalFilename": reference.originalFilename,
                    "mediaType": reference.mediaType,
                    "sourceKind": reference.sourceKind.rawValue,
                    "createdAtEpochSeconds": reference.createdEpochSeconds,
                    "recognizedText": reference.recognizedText as Any? ?? null,
                    "sha256": SHA256.hash(data: file.bytes).map { String(format: "%02x", $0) }
                        .joined(),
                    "byteLength": file.bytes.count, "bytesBase64": file.bytes.base64EncodedString(),
                    "fieldsNotRecorded": [],
                ])
            }
            var profileObjects: [[String: Any]] = []
            for item in profilesByID.values.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                let profileID = identity("profile", item.id.uuidString)
                let currentRule = try rule(item.agreement)
                let baseline = try item.baselineAgreement.map { try rule($0) }
                let profileChanges = try ruleChanges(
                    item.agreementChanges ?? [], profileID: profileID, periodID: nil)
                let active = state.activePeriod.flatMap {
                    ownerByPeriod[$0.id] == item.id ? $0 : nil
                }
                let closed = state.history.first { ownerByPeriod[$0.id] == item.id }
                let currentID = active?.id ?? closed?.id
                let revision = active?.workRevision ?? 0
                let activeID = currentID.map { identity("period", $0.uuidString) }
                let activeWork = currentID.map {
                    identity("workSnapshot", $0.uuidString + ":current:" + String(revision))
                }
                profileObjects.append([
                    "id": profileID, "name": item.name, "timeZone": item.timeZoneIdentifier,
                    "cadence": item.preferredCadence.rawValue, "cycleStartDate": null,
                    "adoptedFromProfileRef": null, "customEndDate": null, "ruleRef": currentRule,
                    "baselineRuleRef": baseline as Any? ?? null, "ruleChangeRefs": profileChanges,
                    "currentPeriodRef": activeID as Any? ?? null,
                    "currentWorkSnapshotRef": activeWork as Any? ?? null,
                    "fieldsNotRecorded": ["cycleStartDate", "customEndDate"],
                ])
            }
            let workRows = works.flatMap { $0["work"] as? [[String: Any]] ?? [] }
            let breakCount = workRows.reduce(0) {
                $0 + (($1["unpaidBreaks"] as? [Any])?.count ?? 0)
            }
            let componentCount = (receipts + periods).reduce(0) { total, item in
                total
                    + (((item["calculation"] as? [String: Any])?["components"] as? [Any])?.count
                        ?? 0)
            }
            let weeklyResults = (receipts + periods).compactMap {
                ($0["calculation"] as? [String: Any])?["weeklyRegularRate"] as? [String: Any]
            }
            let allocationCount = weeklyResults.reduce(0) {
                $0 + (($1["allocations"] as? [Any])?.count ?? 0)
            }
            let correctionCount = periods.reduce(0) {
                $0 + (($1["workCorrections"] as? [Any])?.count ?? 0)
            }
            let inventory: [String: Any] = [
                "profileCount": profileObjects.count, "ruleSnapshotCount": rules.count,
                "ruleChangeCount": changes.count, "ruleTimelineCount": 0, "adoptionCount": 0,
                "workBreakCount": breakCount, "workweekCount": weeklyResults.count,
                "weeklyAllocationCount": allocationCount,
                "workCorrectionCount": correctionCount, "calculationComponentCount": componentCount,
                "periodWindowCount": identities.filter {
                    $0["entityType"] as? String == "periodWindow"
                }.count,
                "auditRevisionCount": receipts.filter { !($0["auditRevisionRef"] is NSNull) }.count,
                "periodCount": periods.count, "workSnapshotCount": works.count,
                "workEntryCount": workRows.count,
                "paycheckReceiptCount": receipts.count, "attachmentCount": originals.count,
                "unsupportedFinancialRecordKinds": [] as [String],
                "unsupportedDraftKinds": [] as [String], "omittedFinancialRecordCount": 0,
            ]
            let source: [String: Any] = [
                "client": "ios", "localStateSchema": AppPersistentState.currentSchemaVersion,
                "exporterVersion": "portable-state-v1",
            ]
            var payload: [String: Any] = [
                "format": PortableStateCodec.format, "version": 1,
                "exportedAtEpochSeconds": Int64(Date().timeIntervalSince1970.rounded()),
            ]
            payload["activeProfileRef"] = identity("profile", profile.id.uuidString)
            payload["adoptions"] = [] as [String]
            payload["source"] = source
            payload["sourceInventory"] = inventory
            payload["identityCrosswalk"] = identities
            payload["profiles"] = profileObjects
            payload["ruleSnapshots"] = rules.values.sorted {
                ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "")
            }
            payload["ruleChanges"] = changes
            payload["ruleTimelines"] = [] as [String]
            payload["periods"] = periods
            payload["workSnapshots"] = works
            payload["paycheckReceipts"] = receipts
            payload["attachments"] = originals
            return try PortableStateCodec.decode(
                JSONSerialization.data(withJSONObject: payload, options: .sortedKeys))
        }
        mutating func rule(_ value: AgreementSnapshot) throws -> String {
            let id = identity("ruleSnapshot", value.id + ":" + value.version)
            if let original = originalRules[id] {
                guard original == value else { throw BackupError.invalidArchive }
                return id
            }
            originalRules[id] = value
            let weekdays = [
                "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
            ]
            let object: [String: Any] = [
                "id": id, "ruleID": value.id, "version": value.version,
                "displayName": value.displayName,
                "effectiveStartDate": value.effectiveStart.map(date) as Any? ?? null,
                "effectiveEndDateInclusive": value.effectiveEnd.map(date) as Any? ?? null,
                "currency": value.hourlyRate.currencyCode,
                "hourlyRate": decimal(value.hourlyRate.amount),
                "regularSchedule": value.regularSchedule.map {
                    [
                        "weekday": weekdays[$0.weekday.rawValue - 1], "start": time($0.start),
                        "end": time($0.end),
                    ]
                },
                "dailyOvertimeTiers": value.dailyOvertimeTiers.map {
                    ["afterHours": decimal($0.afterHours), "multiplier": decimal($0.multiplier)]
                },
                "outsideScheduleMultiplier": decimal(value.outsideScheduleMultiplier),
                "weekdayPremiums": value.weekdayPremiums.map {
                    [
                        "weekday": weekdays[$0.weekday.rawValue - 1],
                        "multiplier": decimal($0.multiplier),
                    ]
                },
                "datePremiums": value.datePremiums.map {
                    ["date": date($0.date), "multiplier": decimal($0.multiplier)]
                },
                "calloutMinimumHours": value.calloutMinimum.map { decimal($0.minimumHours) } as Any?
                    ?? null,
                "perDiemPerWorkDate": value.flatPerDiem.map { money($0.amountPerWorkDate) } as Any?
                    ?? null,
                "weeklyOvertime": value.weeklyOvertime.map {
                    [
                        "workweekStart": weekdays[$0.workweekStart.rawValue - 1],
                        "thresholdHours": decimal($0.thresholdHours),
                        "applicability": $0.applicability.rawValue,
                    ]
                } as Any? ?? null,
                "rounding": [
                    "scale": value.rounding.scale, "scope": value.rounding.scope.rawValue,
                    "mode": value.rounding.mode == .bankers
                        ? "halfEven" : value.rounding.mode.rawValue,
                ],
                "sources": value.sources.map { source -> [String: Any] in
                    [
                        "title": source.title, "url": source.url,
                        "section": source.section as Any? ?? null,
                        "verifiedEpochSeconds": source.verifiedEpochSeconds as Any? ?? null,
                        "ruleKey": source.ruleKey?.rawValue as Any? ?? null,
                        "documentRef": source.documentID.map {
                            identity("attachment", $0.uuidString)
                        } as Any? ?? null,
                        "documentSHA256": source.documentSHA256 as Any? ?? null,
                        "documentPage": source.documentPage as Any? ?? null,
                        "quotedText": source.quotedText as Any? ?? null,
                    ]
                },
                "unsupportedRuleNotes": value.unsupportedRuleNotes as Any? ?? null,
                "confirmedAtEpochSeconds": value.confirmedEpochSeconds as Any? ?? null,
                "confirmedByWorker": value.confirmedEpochSeconds != nil ? true : null,
                "fieldsNotRecorded": value.confirmedEpochSeconds == nil
                    ? ["confirmedByWorker"] : [],
            ]
            rules[id] = object
            return id
        }
        mutating func ruleChanges(_ values: [AgreementChange], profileID: String, periodID: String?)
            throws -> [String]
        {
            try values.map { value in
                let ruleRef = try rule(value.agreement)
                let id = identity(
                    "ruleChange",
                    (periodID ?? profileID) + ":" + date(value.effectiveDate) + ":"
                        + ruleRef)
                let row: [String: Any] = [
                    "id": id, "profileRef": profileID, "periodRef": periodID as Any? ?? null,
                    "effectiveDate": date(value.effectiveDate), "sourceProfileRef": null,
                    "ruleRef": ruleRef,
                    "confirmed": null, "createdAtEpochSeconds": null,
                    "fieldsNotRecorded": [
                        "confirmed", "createdAtEpochSeconds", "sourceProfileRef",
                    ],
                ]
                if let prior = changes.first(where: { $0["id"] as? String == id }) {
                    guard NSDictionary(dictionary: prior).isEqual(to: row) else {
                        throw BackupError.invalidArchive
                    }
                } else {
                    changes.append(row)
                }
                return id
            }
        }
        mutating func snapshot(
            _ entries: [WorkEntry], periodID: String, profileID: String, suffix: String,
            role: String
        ) -> String {
            let id = identity("workSnapshot", periodID + ":" + suffix)
            let rows = entries.map { work -> [String: Any] in
                [
                    "id": identity("workEntry", work.id.uuidString),
                    "startEpochSeconds": work.interval.startEpochSeconds,
                    "endEpochSeconds": work.interval.endEpochSeconds,
                    "timeZone": work.interval.timeZoneIdentifier,
                    "kind": work.interval.kind.rawValue,
                    "calloutEventRef": work.interval.calloutEventID.map {
                        identity("calloutEvent", $0.uuidString)
                    } as Any? ?? null,
                    "unpaidBreaks": work.interval.unpaidBreaks.map { rest in
                        [
                            "id": identity("workBreak", rest.id.uuidString),
                            "startEpochSeconds": rest.startEpochSeconds,
                            "endEpochSeconds": rest.endEpochSeconds,
                        ] as [String: Any]
                    }, "note": work.note, "fieldsNotRecorded": [],
                ]
            }
            works.append([
                "id": id, "profileRef": profileID, "periodRef": identity("period", periodID),
                "role": role, "revision": null, "sourceRef": null, "work": rows,
                "fieldsNotRecorded": ["revision"],
            ])
            return id
        }
        func ownerProfile(
            periodID: UUID, window: PayPeriodWindow, agreement: AgreementSnapshot, zone: String?
        ) throws -> PayProfile {
            if let owner = state.portableCurrentProfile, owner.periodID == periodID,
                let profile = owner.profile(in: state)
            {
                return state.profile?.id == profile.id ? state.profile! : profile
            }
            if let adoption = adoptionSnapshots.first(where: { $0.nativePeriodID == periodID }) {
                return PayProfile(
                    id: adoption.nativeProfileID,
                    name: adoption.nativeProfileName ?? "Confirmed native adoption",
                    timeZoneIdentifier: adoption.nativeTimeZone, agreement: agreement,
                    preferredCadence: window.cadence,
                    baselineAgreement: agreement)
            }
            if let source = retainedSource,
                let period = source.periods.first(where: {
                    PortableStateMapping.local("period", $0.id) == periodID
                }),
                let ref = period.profileRef
                    ?? source.workSnapshots.first(where: { $0.id == period.currentWorkSnapshotRef }
                    )?.profileRef,
                let original = source.profiles.first(where: { $0.id == ref }),
                let zone = zone ?? original.timeZone
            {
                let id = PortableStateMapping.local("profile", ref)
                if let selected = state.profile, selected.id == id { return selected }
                return PayProfile(
                    id: id, name: original.name ?? "Current confirmed pay rules",
                    timeZoneIdentifier: zone,
                    agreement: agreement, preferredCadence: window.cadence,
                    baselineAgreement: agreement)
            }
            guard let profile = state.profile else { throw BackupError.invalidArchive }
            return profile
        }

        mutating func period(
            id: UUID, window: PayPeriodWindow, agreement: AgreementSnapshot, zone: String?,
            entries: [WorkEntry], closed: Bool, archived: Int64?, issue: String?, profileID: String,
            paid: ConfirmedPaystub?, calculation: CalculationResult?,
            reconciliation: ReconciliationResult?,
            revisions: [AuditRevision], ruleChanges: [AgreementChange],
            auditCompleted: Int64? = nil, workRevision: Int? = nil,
            corrections: [ClosedWorkRevision] = []
        ) throws {
            let periodID = identity("period", id.uuidString)
            let currentWork = snapshot(
                entries, periodID: id.uuidString, profileID: profileID,
                suffix: "current:" + String(workRevision ?? 0),
                role: "currentLedger")
            let ruleID = try rule(agreement)
            let changedRules = try self.ruleChanges(
                ruleChanges, profileID: profileID, periodID: periodID)
            var snapshotRefs = [currentWork]
            var correctionObjects: [[String: Any]] = []
            for (index, correction) in corrections.enumerated() {
                let work = snapshot(
                    correction.workEntries, periodID: id.uuidString, profileID: profileID,
                    suffix: "correction:\(index)", role: "workCorrection")
                snapshotRefs.append(work)
                correctionObjects.append([
                    "id": identity("workCorrection", id.uuidString + ":correction:\(index)"),
                    "workSnapshotRef": work, "reason": correction.reason,
                    "correctedAtEpochSeconds": correction.correctedEpochSeconds,
                ])
            }
            var priorReceipt: String?
            for revision in revisions {
                let work = snapshot(
                    revision.workEntries, periodID: id.uuidString, profileID: profileID,
                    suffix: revision.id.uuidString, role: "auditRevision")
                snapshotRefs.append(work)
                priorReceipt = try receipt(
                    revision.paystub, periodID: periodID, profileID: profileID, workID: work,
                    calculation: revision.calculation,
                    agreement: revision.agreement, window: revision.window,
                    zone: revision.timeZoneIdentifier,
                    reconciliation: revision.reconciliation, supersedes: priorReceipt,
                    auditRevision: revision.id, ruleChanges: revision.agreementChanges ?? [])
            }
            if let paid, !revisions.contains(where: { $0.paystub.id == paid.id }) {
                _ = try receipt(
                    paid, periodID: periodID, profileID: profileID, workID: currentWork,
                    calculation: calculation,
                    agreement: agreement, window: window, zone: zone,
                    reconciliation: reconciliation, supersedes: priorReceipt)
            }
            periods.append([
                "id": periodID, "profileRef": profileID, "calendarWindow": calendar(window, zone),
                "cadence": window.cadence.rawValue, "isCurrent": !closed, "closed": closed,
                "archivedAtEpochSeconds": archived as Any? ?? null,
                "calculationIssue": issue as Any? ?? null,
                "ruleRef": ruleID, "ruleChangeRefs": changedRules, "ruleTimelineRefs": [],
                "currentWorkSnapshotRef": currentWork,
                "workSnapshotRefs": snapshotRefs, "workCorrections": correctionObjects,
                "fieldsNotRecorded": [],
                "windowRef": identity("periodWindow", window.id.uuidString),
                "calculation": try self.calculation(
                    calculation, ruleChangeRefs: changedRules),
                "auditCompletedAtEpochSeconds": auditCompleted as Any? ?? null,
                "workRevision": workRevision as Any? ?? null,
            ])
        }
        mutating func calculation(
            _ value: CalculationResult?, ruleChangeRefs: [String]
        ) throws -> Any {
            guard let value else { return null }
            let ruleRefs = try (value.agreementSnapshots ?? []).map { try rule($0) }
            let primary = rules.first {
                $0.value["ruleID"] as? String == value.agreementID
                    && $0.value["version"] as? String == value.agreementVersion
            }?.key
            let components = try value.components.map { component -> [String: Any] in
                var applied: Any = null
                if let source = component.appliedAgreement {
                    guard
                        let ref = rules.first(where: {
                            $0.value["ruleID"] as? String == source.id
                                && $0.value["version"] as? String == source.version
                        })?.key
                    else { throw BackupError.invalidArchive }
                    applied = [
                        "ruleRef": ref, "ruleID": source.id, "version": source.version,
                        "hourlyRate": money(source.hourlyRate),
                    ]
                }
                return [
                    "id": identity("calculationComponent", component.id.uuidString),
                    "category": component.category.rawValue,
                    "workRef": component.workIntervalID.map { identity("workEntry", $0.uuidString) }
                        as Any? ?? null,
                    "localDate": date(component.localDate),
                    "hours": component.hours.map(decimal) as Any? ?? null,
                    "workedSeconds": null,
                    "multiplier": component.multiplier.map(decimal) as Any? ?? null,
                    "amount": money(component.amount), "explanation": component.explanation,
                    "ruleKeys": component.ruleKeys.map { $0.map(\.rawValue) } as Any? ?? null,
                    "baseRate": component.baseRate.map(money) as Any? ?? null,
                    "appliedAgreement": applied,
                    "unroundedAmount": component.unroundedAmount.map(money) as Any? ?? null,
                    "baseTimeNumerator": component.baseTimeNumerator.map(decimal) as Any? ?? null,
                    "fieldsNotRecorded": ["workedSeconds"],
                ]
            }
            return [
                "agreementID": value.agreementID, "agreementVersion": value.agreementVersion,
                "primaryRuleRef": primary as Any? ?? null, "agreementSnapshotRefs": ruleRefs,
                "currency": value.total.currencyCode, "total": money(value.total),
                "provenance": value.provenance.map {
                    ["engine": $0.engine, "rounding": $0.rounding, "callout": $0.callout]
                } as Any? ?? null,
                "weeklyRegularRate": weekly(value.weeklyRegularRate), "components": components,
                "engine": value.provenance?.engine as Any? ?? null,
                "coverage": null, "wages": null, "allowances": null, "ruleTimelineRef": null,
                "ruleChangeRefs": ruleChangeRefs,
                "fieldsNotRecorded": [
                    "coverage", "wages", "allowances", "ruleTimelineRef",
                ] + (value.provenance == nil ? ["engine", "provenance"] : []),
            ] as [String: Any]
        }
        mutating func weekly(_ value: WeeklyRegularRateResult?) -> Any {
            guard let value else { return null }
            let weekdays = [
                "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
            ]
            var absent: [String] = []
            if value.startEpochSeconds == nil { absent.append("startEpochSeconds") }
            if value.endEpochSeconds == nil { absent.append("endEpochSeconds") }
            if value.timeZoneIdentifier == nil { absent.append("timeZone") }
            return [
                "workweekID": identity("workweek", value.workweekID.uuidString),
                "weekStart": date(value.weekStart),
                "workweekStart": weekdays[value.workweekStart.rawValue - 1],
                "qualifyingHours": decimal(value.qualifyingHours),
                "includableRemuneration": money(value.includableRemuneration),
                "regularRate": value.regularRate.map(money) as Any? ?? null,
                "overtimeHours": decimal(value.overtimeHours),
                "statutoryAdditionalPremium": money(value.statutoryAdditionalPremium),
                "eligibleExtraPremiumCredit": money(value.eligibleExtraPremiumCredit),
                "remainingAdditionalPremium": money(value.remainingAdditionalPremium),
                "cashRemuneration": money(value.cashRemuneration),
                "expectedCash": money(value.expectedCash),
                "allocations": value.allocations.map { allocation -> [String: Any] in
                    [
                        "id": identity("weeklyAllocation", allocation.id.uuidString),
                        "periodRef": allocation.payPeriodID.map {
                            identity("period", $0.uuidString)
                        } as Any? ?? null,
                        "amount": money(allocation.amount), "basis": money(allocation.basis),
                    ]
                }, "engineVersion": value.engineVersion,
                "startEpochSeconds": value.startEpochSeconds as Any? ?? null,
                "endEpochSeconds": value.endEpochSeconds as Any? ?? null,
                "timeZone": value.timeZoneIdentifier as Any? ?? null,
                "fieldsNotRecorded": absent,
            ] as [String: Any]
        }

        mutating func receipt(
            _ paid: ConfirmedPaystub, periodID: String, profileID: String, workID: String,
            calculation: CalculationResult?,
            agreement: AgreementSnapshot, window: PayPeriodWindow, zone: String?,
            reconciliation: ReconciliationResult?, supersedes: String?,
            auditRevision: UUID? = nil,
            ruleChanges: [AgreementChange] = []
        ) throws -> String {
            guard let assessment = paid.assessment else {
                throw BackupError.portableUnsupported(
                    "Legacy paycheck facts without a frozen assessment need a full iPhone backup.")
            }
            let id = identity("paycheckReceipt", paid.id.uuidString)
            let ruleID = try rule(agreement)
            let targetChanges = try self.ruleChanges(
                ruleChanges, profileID: profileID, periodID: periodID)
            let calculationObject = try self.calculation(
                calculation, ruleChangeRefs: targetChanges)
            var facts: [String: Any] = [
                "id": identity("paystub", paid.id.uuidString),
                "periodStartDate": paid.payPeriodStart.map(date) as Any? ?? null,
                "periodEndDateInclusive": paid.payPeriodEnd.map(date) as Any? ?? null,
                "currency": paid.grossPay.currencyCode, "grossPay": decimal(paid.grossPay.amount),
                "regularHours": paid.regularHours.map(decimal) as Any? ?? null,
                "regularPay": paid.regularPay.map { decimal($0.amount) } as Any? ?? null,
                "overtimeHours": paid.overtimeHours.map(decimal) as Any? ?? null,
                "overtimePay": paid.overtimePay.map { decimal($0.amount) } as Any? ?? null,
                "doubleTimeHours": paid.doubleTimeHours.map(decimal) as Any? ?? null,
                "doubleTimePay": paid.doubleTimePay.map { decimal($0.amount) } as Any? ?? null,
                "calloutPay": paid.calloutPay.map { decimal($0.amount) } as Any? ?? null,
                "perDiemPay": paid.perDiemPay.map { decimal($0.amount) } as Any? ?? null,
                "confirmed": true, "notes": paid.notes,
                "confirmedAtEpochSeconds": paid.confirmedEpochSeconds,
                "evidenceRef": paid.evidence.map { identity("attachment", $0.id.uuidString) }
                    as Any? ?? null,
                "fieldsNotRecorded": [],
            ]
            // `null` monetary lines retain absence; they are not zero-valued earnings.
            facts["fieldsNotRecorded"] = [] as [String]
            let confirmation = paid.confirmation
            let amounts: [(String, Money?)] = [
                ("regularPay", paid.regularPay), ("overtimePay", paid.overtimePay),
                ("doubleTimePay", paid.doubleTimePay), ("calloutPay", paid.calloutPay),
                ("perDiemPay", paid.perDiemPay),
            ]
            let hours: [(String, Decimal?)] = [
                ("regularHours", paid.regularHours), ("overtimeHours", paid.overtimeHours),
                ("doubleTimeHours", paid.doubleTimeHours),
            ]
            let lineFacts: [String: Any] = [
                "grossBasis": confirmation?.grossBasis.rawValue as Any? ?? null,
                "lineLayout": confirmation?.lineLayout.rawValue as Any? ?? null,
                "hoursBasis": confirmation?.hoursBasis.rawValue as Any? ?? null,
                "guaranteeLayout": confirmation?.guaranteeLayout.rawValue as Any? ?? null,
                "amounts": amounts.compactMap { field, value -> [String: Any]? in
                    value.map { ["field": field, "amount": money($0)] }
                },
                "hours": hours.compactMap { field, value -> [String: Any]? in
                    value.map { ["field": field, "hours": decimal($0)] }
                },
                "reviewedFields": confirmation?.reviewedFields.map(\.rawValue).sorted() as Any?
                    ?? null,
                "suggestions": confirmation?.suggestions.sorted {
                    $0.key.rawValue < $1.key.rawValue
                }.map { field, value -> [String: Any] in
                    [
                        "field": field.rawValue, "value": value.value as Any? ?? null,
                        "sourceText": value.sourceText,
                        "region": [
                            "page": value.region.page, "x": String(value.region.x),
                            "y": String(value.region.y), "width": String(value.region.width),
                            "height": String(value.region.height),
                        ],
                        "confidence": String(value.confidence),
                        "reason": value.reason as Any? ?? null,
                    ]
                } as Any? ?? null,
                "hasAdditionalUnmappedPay": confirmation?.hasAdditionalUnmappedPay as Any? ?? null,
                "workComplete": confirmation?.workComplete as Any? ?? null,
                "earningsLinesComplete": confirmation?.earningsLinesComplete as Any? ?? null,
                "fieldsNotRecorded": confirmation == nil
                    ? [
                        "grossBasis", "lineLayout", "hoursBasis", "guaranteeLayout",
                        "hasAdditionalUnmappedPay", "workComplete", "earningsLinesComplete",
                        "reviewedFields", "suggestions",
                    ] : [],
            ]
            let compared = assessment.comparisons.map { item -> [String: Any] in
                [
                    "id": item.id, "field": item.field.rawValue, "expected": decimal(item.expected),
                    "paid": decimal(item.paid),
                    "difference": decimal(item.difference), "unit": item.unit.rawValue,
                    "currency": item.currencyCode,
                    "componentRefs": item.componentIDs.map {
                        identity("calculationComponent", $0.uuidString)
                    },
                ]
            }
            let recorded: [String: Any] = [
                "engineID": "LinePayDomain.PaycheckAssessor",
                "engineVersion": assessment.engineVersion,
                "verdict": assessment.verdict.rawValue, "scope": assessment.scope.rawValue,
                "expectedGross": assessment.expectedGross.map(money) as Any? ?? null,
                "paidGross": money(assessment.paidGross),
                "difference": assessment.difference.map(money) as Any? ?? null,
                "comparisons": compared,
                "reviewReasons": assessment.reviewReasons, "scopeNotes": assessment.scopeNotes,
                "weeklyContextCount": null, "weeklyReviewRefs": null, "periodMatch": null,
                "reportedPeriod": null,
                "fieldsNotRecorded": [
                    "weeklyContextCount", "weeklyReviewRefs", "periodMatch", "reportedPeriod",
                ],
            ]
            let reconcile: Any =
                reconciliation.map { result -> [String: Any] in
                    [
                        "expectedGross": money(result.expectedGross),
                        "actualGross": money(result.actualGross),
                        "difference": money(result.difference),
                        "direction": result.direction.rawValue,
                    ]
                } as Any? ?? null
            let producer: [String: Any] = [
                "client": "ios", "localStateSchema": null,
                "calculationEngineID": calculation?.provenance?.engine as Any? ?? null,
                "calculationEngineVersion": null,
                "assessmentEngineID": "LinePayDomain.PaycheckAssessor",
                "assessmentEngineVersion": assessment.engineVersion,
                "fieldsNotRecorded": ["calculationEngineVersion", "localStateSchema"]
                    + (calculation != nil && calculation?.provenance == nil
                        ? ["calculationEngineID"] : [])
                    ,
            ]
            receipts.append([
                "receiptKind": "paycheck-v1", "id": id, "periodRef": periodID,
                "workSnapshotRef": workID,
                "createdAtEpochSeconds": paid.confirmedEpochSeconds,
                "supersedesReceiptRef": supersedes as Any? ?? null,
                "auditRevisionRef": auditRevision.map { identity("auditRevision", $0.uuidString) }
                    as Any? ?? null,
                "targetWindowRef": identity("periodWindow", window.id.uuidString),
                "targetWindow": calendar(window, zone),
                "targetCadence": window.cadence.rawValue,
                "targetRuleChangeRefs": targetChanges,
                "producer": producer,
                "ruleRefs": Array(
                    Set(
                        [ruleID]
                            + ((calculationObject as? [String: Any])?["agreementSnapshotRefs"]
                                as? [String] ?? []))
                ).sorted(),
                "sourcePeriod": [
                    "startDate": paid.payPeriodStart.map(date) as Any? ?? null,
                    "endDateInclusive": paid.payPeriodEnd.map(date) as Any? ?? null,
                    "timeZone": null, "confirmed": null,
                    "fieldsNotRecorded": ["timeZone", "confirmed"],
                ], "paystubFacts": facts, "lineFacts": lineFacts,
                "reviewFacts": [
                    "completeWorkConfirmed": confirmation?.workComplete as Any? ?? null,
                    "ruleCoverageConfirmed": null,
                    "unreviewedFields": null,
                    "weeklyReviewPending": assessment.reviewReasons.contains(
                        PaycheckAssessor.weeklyMappingReviewReason) ? true : null,
                    "fieldsNotRecorded": ["ruleCoverageConfirmed", "unreviewedFields"]
                        + (assessment.reviewReasons.contains(
                            PaycheckAssessor.weeklyMappingReviewReason)
                            ? [] : ["weeklyReviewPending"])
                        ,
                ],
                "calculation": calculationObject, "assessment": recorded,
                "reconciliation": reconcile,
                "attachmentRefs": paid.evidence.map { [identity("attachment", $0.id.uuidString)] }
                    ?? [], "fieldsNotRecorded": [],
            ])
            return id
        }
        func calendar(_ value: PayPeriodWindow, _ zone: String?) -> [String: Any] {
            guard let zone else {
                return [
                    "startDate": null, "endDateInclusive": null, "endExclusiveDate": null,
                    "timeZone": null, "boundaryModel": "sourcePeriodUnknown",
                    "startEpochSeconds": value.startEpochSeconds,
                    "endExclusiveEpochSeconds": value.endEpochSeconds,
                    "fieldsNotRecorded": [
                        "startDate", "endDateInclusive", "endExclusiveDate", "timeZone",
                    ],
                ]
            }
            return [
                "startDate": localDate(value.startEpochSeconds, zone),
                "endDateInclusive": localDate(value.endEpochSeconds - 1, zone),
                "endExclusiveDate": localDate(value.endEpochSeconds, zone), "timeZone": zone,
                "boundaryModel": "exactInstants",
                "startEpochSeconds": value.startEpochSeconds,
                "endExclusiveEpochSeconds": value.endEpochSeconds, "fieldsNotRecorded": [],
            ]
        }
        func decimal(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
        func money(_ value: Money) -> [String: Any] {
            ["amount": decimal(value.amount), "currency": value.currencyCode]
        }
        func date(_ value: LocalDate) -> String {
            String(format: "%04d-%02d-%02d", value.year, value.month, value.day)
        }
        func time(_ value: LocalTime) -> String {
            String(format: "%02d:%02d", value.hour, value.minute)
        }
        func localDate(_ epoch: Int64, _ zone: String) -> String {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let value = calendar.dateComponents(
                [.year, .month, .day], from: Date(timeIntervalSince1970: TimeInterval(epoch)))
            return String(format: "%04d-%02d-%02d", value.year!, value.month!, value.day!)
        }
    }
}
