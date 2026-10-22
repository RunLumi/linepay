import CryptoKit
import Foundation
import LinePayDomain

/// Native adapters never ask the receiving payroll engine to reinterpret imported receipts.
enum PortableStateMapping {
    static func inventory(_ state: AppPersistentState) throws {
        try AppStateValidation.validate(state)
        let blockers: [(Bool, String)] = [
            (
                state.setupDraft != nil || state.workDraft != nil || state.paystubDraft != nil
                    || state.benefitAuditDraft != nil, "Finish or discard saved drafts first."
            ),
            (
                !state.pendingEvidenceDeletions.isEmpty,
                "Complete pending original-file deletion first."
            ),
            (
                !(state.benefitAudits ?? []).isEmpty,
                "Employer-contribution receipts are outside this transfer version."
            ),
            (
                !(state.resolutionEvents ?? []).isEmpty,
                "Follow-up and resolution records are outside this transfer version."
            ),
            (
                !(state.crewRuleOrigins ?? []).isEmpty,
                "Crew-rule adoption records are outside this transfer version."
            ),
        ]
        if let reason = blockers.first(where: { $0.0 })?.1 {
            throw BackupError.portableUnsupported(reason)
        }
    }

    static func validateStored(_ state: AppPersistentState) throws {
        guard state.portableAdoptions.count <= 1_000,
            Set(state.portableAdoptions.map(\.id)).count == state.portableAdoptions.count
        else { throw BackupError.invalidArchive }
        if !state.portableAdoptions.isEmpty {
            guard let imported = state.portableFinancialState else {
                throw BackupError.invalidArchive
            }
            for adoption in state.portableAdoptions {
                guard imported.profiles.contains(where: { $0.id == adoption.sourceProfileRef }),
                    imported.workSnapshots.contains(where: {
                        $0.id == adoption.sourceWorkSnapshotRef
                    }),
                    Set(adoption.confirmedFields) == PortableNativeAdoption.requiredFields,
                    adoption.nativeRuleID == adoption.nativeAgreement.id,
                    adoption.nativeRuleVersion == adoption.nativeAgreement.version,
                    (946_684_800...4_102_444_799).contains(adoption.confirmedEpochSeconds)
                else { throw BackupError.invalidArchive }
                var frozen = AppPersistentState()
                frozen.profile = PayProfile(
                    id: adoption.nativeProfileID, name: "Confirmed native adoption",
                    timeZoneIdentifier: adoption.nativeTimeZone, agreement: adoption.nativeAgreement
                )
                frozen.activePeriod = ActivePayPeriod(
                    id: adoption.nativePeriodID, window: adoption.nativeWindow,
                    agreement: adoption.nativeAgreement,
                    timeZoneIdentifier: adoption.nativeTimeZone, workEntries: adoption.nativeWork)
                try AppStateValidation.validate(frozen)
            }
        }
        guard let document = state.portableFinancialState else {
            guard state.portableIdentityCrosswalk.isEmpty, state.portableOriginals.isEmpty else {
                throw BackupError.invalidArchive
            }
            return
        }
        var structural = document
        for index in structural.attachments.indices {
            guard structural.attachments[index].bytesBase64.isEmpty else {
                throw BackupError.invalidArchive
            }
            structural.attachments[index].bytesBase64 = "AAAA"
        }
        try PortableStateCodec.validateStructure(JSONEncoder().encode(structural))
        try PortableStateCodec.preflight(document, validateOriginalBytes: false)
        let expected = try nativeState(document)
        guard state.portableIdentityCrosswalk == expected.portableIdentityCrosswalk,
            Set(state.portableOriginals.map(\.id)) == Set(expected.portableOriginals.map(\.id)),
            state.portableOriginals.count == expected.portableOriginals.count
        else { throw BackupError.invalidArchive }
    }

    static func nativeState(_ document: PortableState) throws -> AppPersistentState {
        var result = AppPersistentState()
        result.portableIdentityCrosswalk = document.identityCrosswalk.map {
            PortableLocalIdentity.make(entityType: $0.entityType, portableID: $0.portableID)
        }
        let activeProfile = document.activeProfileRef.flatMap { ref in
            document.profiles.first { $0.id == ref }
        }
        let activePeriods = document.periods.filter { $0.isCurrent == true }
        let editableRules = document.ruleSnapshots.filter { rule in
            let requiredNumbers =
                [rule.hourlyRate]
                + [rule.outsideScheduleMultiplier, rule.calloutMinimumHours].compactMap { $0 }
                + (rule.dailyOvertimeTiers ?? []).flatMap { [$0.afterHours, $0.multiplier] }
                + (rule.weekdayPremiums ?? []).map(\.multiplier)
                + (rule.datePremiums ?? []).map(\.multiplier)
                + [rule.perDiemPerWorkDate?.amount].compactMap { $0 }
            guard requiredNumbers.allSatisfy({ PortableExactDecimal($0)?.nativeValue != nil })
            else { return false }
            guard
                (rule.sources ?? []).allSatisfy({
                    $0.ruleKey.map { PayRuleKey(rawValue: $0) != nil } ?? true
                })
            else { return false }

            if let weekly = rule.weeklyOvertime,
                weekly.applicability == "unsupported"
                    || PortableExactDecimal(weekly.thresholdHours)?.nativeValue != 40
            {
                return false
            }
            if let rounding = rule.rounding,
                !(0...8).contains(rounding.scale)
                    || !["payCategory", "legacySegments"].contains(rounding.scope)
            {
                return false
            }
            if let mode = rule.rounding?.mode, !["halfUp", "halfEven", "down", "up"].contains(mode)
            {
                return false
            }
            return rule.confirmedByWorker == true && rule.displayName != nil
                && rule.regularSchedule != nil
                && rule.dailyOvertimeTiers != nil
                && rule.outsideScheduleMultiplier != nil && rule.weekdayPremiums != nil
                && rule.datePremiums != nil
                && rule.rounding != nil && rule.sources != nil
                && rule.weeklyOvertime?.applicability != "unsupported"
        }
        let pairs = try editableRules.map { item in (item.id, try rule(object(item))) }
        let rulesByID = Dictionary(uniqueKeysWithValues: pairs)
        func changes(_ refs: [String]) throws -> [AgreementChange]? {
            var result: [AgreementChange] = []
            for ref in refs {
                guard let change = document.ruleChanges.first(where: { $0.id == ref }),
                    let agreement = rulesByID[change.ruleRef]
                else { return nil }
                result.append(
                    AgreementChange(
                        effectiveDate: try date(change.effectiveDate), agreement: agreement))
            }
            return result
        }
        // Future defaults and the selected current workspace have independent capability gates.
        if let profile = activeProfile, let zone = profile.timeZone,
            let cadence = profile.cadence.flatMap(PayPeriodCadence.init(rawValue:)),
            let agreement = rulesByID[profile.ruleRef],
            profile.baselineRuleRef.map({ rulesByID[$0] != nil }) ?? true,
            let timeline = try changes(profile.ruleChangeRefs)
        {
            result.profile = PayProfile(
                id: local("profile", profile.id),
                name: profile.name ?? "Imported future pay rules", timeZoneIdentifier: zone,
                agreement: agreement, preferredCadence: cadence,
                baselineAgreement: profile.baselineRuleRef.flatMap { rulesByID[$0] },
                agreementChanges: timeline)
        }
        for period in activePeriods {
            guard period.closed != true, period.archivedAtEpochSeconds == nil,
                period.calendarWindow.boundaryModel == "exactInstants",
                let start = period.calendarWindow.startEpochSeconds,
                let end = period.calendarWindow.endExclusiveEpochSeconds,
                let zone = period.calendarWindow.timeZone,
                let cadence = period.cadence.flatMap(PayPeriodCadence.init(rawValue:)),
                let ref = period.ruleRef, let agreement = rulesByID[ref],
                let timeline = try changes(period.ruleChangeRefs),
                let snapshot = document.workSnapshots.first(where: {
                    $0.id == period.currentWorkSnapshotRef
                }),
                snapshot.work.allSatisfy({ $0.note != nil && WorkKind(rawValue: $0.kind) != nil }),
                let owner = document.profiles.first(where: {
                    $0.id == (period.profileRef ?? snapshot.profileRef)
                })
            else { continue }
            let entries = try snapshot.work.map { work in
                let breaks = try work.unpaidBreaks.map {
                    try WorkBreak(
                        id: local("workBreak", $0.id), startEpochSeconds: $0.startEpochSeconds,
                        endEpochSeconds: $0.endEpochSeconds)
                }
                return WorkEntry(
                    interval: try WorkInterval(
                        id: local("workEntry", work.id), startEpochSeconds: work.startEpochSeconds,
                        endEpochSeconds: work.endEpochSeconds, timeZoneIdentifier: work.timeZone,
                        kind: WorkKind(rawValue: work.kind)!,
                        unpaidBreaks: breaks,
                        calloutEventID: work.calloutEventRef.map { local("calloutEvent", $0) }),
                    note: work.note!)
            }
            result.activePeriod = ActivePayPeriod(
                id: local("period", period.id),
                window: PayPeriodWindow(
                    id: local("periodWindow", period.windowRef), startEpochSeconds: start,
                    endEpochSeconds: end, cadence: cadence),
                agreement: agreement, timeZoneIdentifier: zone, workEntries: entries,
                workRevision: period.workRevision.map(Int.init), agreementChanges: timeline)
            result.portableCurrentProfile = PortableCurrentProfile(
                periodID: local("period", period.id), profileID: local("profile", owner.id),
                sourceName: owner.name)
        }
        var retained = document
        retained.attachments = document.attachments.map { item in
            var metadata = item
            metadata.bytesBase64 = ""
            return metadata
        }
        result.portableFinancialState = retained
        result.portableOriginals = document.attachments.map { item in
            PaystubEvidence(
                id: local("attachment", item.id),
                storedFilename: local("attachment", item.id).uuidString + ".bin",
                originalFilename: item.originalFilename, mediaType: item.mediaType,
                sourceKind: .file, createdEpochSeconds: document.exportedAtEpochSeconds)
        }
        return result
    }

    static func archive(_ document: PortableState) throws -> BackupArchive {
        let files = try document.attachments.map { item in
            guard let bytes = Data(base64Encoded: item.bytesBase64) else {
                throw BackupError.invalidArchive
            }
            return BackupArchive.EvidenceFile(id: local("attachment", item.id), bytes: bytes)
        }
        let archive = BackupArchive(
            createdAt: Date(timeIntervalSince1970: TimeInterval(document.exportedAtEpochSeconds)),
            state: try nativeState(document), files: files)
        try archive.validate()
        guard try JSONEncoder().encode(archive.state).count <= BackupArchive.maximumStateBytes
        else { throw BackupError.tooLarge }
        return archive
    }

    static func validateOriginals(_ state: AppPersistentState, files: [BackupArchive.EvidenceFile])
        throws
    {
        guard let document = state.portableFinancialState else { return }
        for attachment in document.attachments {
            guard let file = files.first(where: { $0.id == local("attachment", attachment.id) }),
                file.bytes.count == attachment.byteLength,
                SHA256.hash(data: file.bytes).map({ String(format: "%02x", $0) }).joined()
                    == attachment.sha256
            else { throw BackupError.missingEvidence }
        }
    }

    static func export(_ state: AppPersistentState, files: [BackupArchive.EvidenceFile]) throws
        -> PortableState
    {
        try inventory(state)
        if var retained = state.portableFinancialState {
            var reconstructed = retained
            for index in reconstructed.attachments.indices {
                let item = reconstructed.attachments[index]
                guard let original = files.first(where: { $0.id == local("attachment", item.id) })
                else { throw BackupError.missingEvidence }
                reconstructed.attachments[index].bytesBase64 = original.bytes.base64EncodedString()
            }
            let expected = try nativeState(reconstructed)
            if !state.portableAdoptions.isEmpty {
                var nativeOnly = state
                nativeOnly.portableFinancialState = nil
                nativeOnly.portableIdentityCrosswalk = []
                nativeOnly.portableOriginals = []
                nativeOnly.portableAdoptions = []
                let foreignOriginalIDs = Set(state.portableOriginals.map(\.id))
                let native = try NativePortableStateWriter.export(
                    nativeOnly, files: files.filter { !foreignOriginalIDs.contains($0.id) },
                    adoptionSnapshots: state.portableAdoptions, retainedSource: reconstructed)
                return try PortableStateMerger.merge(
                    reconstructed, native: native, adoptions: state.portableAdoptions)
            }
            if state.profile == expected.profile,
                state.activePeriod != expected.activePeriod || state.history != expected.history
            {
                var nativeOnly = state
                nativeOnly.portableFinancialState = nil
                nativeOnly.portableIdentityCrosswalk = []
                nativeOnly.portableOriginals = []
                let originalIDs = Set(state.portableOriginals.map(\.id))
                let native = try NativePortableStateWriter.export(
                    nativeOnly, files: files.filter { !originalIDs.contains($0.id) },
                    retainedSource: reconstructed)
                return try PortableWorkspaceAdvance.combine(
                    reconstructed, native: native, crosswalk: state.portableIdentityCrosswalk)
            }
            guard state.profile == expected.profile,
                state.portableCurrentProfile == expected.portableCurrentProfile,
                state.activePeriod == expected.activePeriod,
                state.history == expected.history, (state.agreementDocuments ?? []).isEmpty
            else {
                throw BackupError.portableUnsupported(
                    "Create an explicit new-profile adoption before combining changed rules with imported records."
                )
            }
            retained = reconstructed
            try PortableStateCodec.preflight(retained)
            return retained
        }
        return try NativePortableStateWriter.export(state, files: files)
    }

    static func local(_ type: String, _ id: String) -> UUID {
        PortableLocalIdentity.make(entityType: type, portableID: id).localID
    }
    static func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        guard
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
                as? [String: Any]
        else { throw BackupError.invalidArchive }
        return object
    }
    private static func decimal(_ text: String) throws -> Decimal {
        guard let exact = PortableExactDecimal(text), let result = exact.nativeValue else {
            throw BackupError.portableUnsupported(
                "A configured value exceeds this iPhone's exact decimal capacity. Confirm a new native configuration before using it for calculations."
            )
        }
        return result
    }
    private static func text(_ value: [String: Any], _ key: String) throws -> String {
        guard let result = value[key] as? String else {
            throw BackupError.portableUnsupported(
                "The source did not record a required rule field: " + key)
        }
        return result
    }
    private static func amount(_ value: [String: Any], _ key: String) throws -> Decimal {
        try decimal(text(value, key))
    }
    private static func date(_ text: String) throws -> LocalDate {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw BackupError.invalidArchive }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let instant = calendar.date(from: components),
            calendar.dateComponents([.year, .month, .day], from: instant) == components
        else { throw BackupError.invalidArchive }
        return LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }
    private static func time(_ text: String) throws -> LocalTime {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { throw BackupError.invalidArchive }
        return try LocalTime(hour: parts[0], minute: parts[1])
    }
    private static func weekday(_ value: String) throws -> Weekday {
        let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        guard let index = names.firstIndex(of: value), let result = Weekday(rawValue: index + 1)
        else { throw BackupError.invalidArchive }
        return result
    }
    private static func rule(_ fields: [String: Any]) throws -> AgreementSnapshot {
        guard let schedules = fields["regularSchedule"] as? [[String: Any]],
            let tiers = fields["dailyOvertimeTiers"] as? [[String: Any]],
            let weekdays = fields["weekdayPremiums"] as? [[String: Any]],
            let dates = fields["datePremiums"] as? [[String: Any]],
            let rounding = fields["rounding"] as? [String: Any],
            let scale = rounding["scale"] as? Int,
            let scope = PayRoundingScope(rawValue: try text(rounding, "scope")),
            let sources = fields["sources"] as? [[String: Any]]
        else {
            throw BackupError.portableUnsupported(
                "The complete configured rule was not recorded or is outside this version.")
        }
        let currency = try text(fields, "currency")
        let modeText = try text(rounding, "mode")
        guard let mode = MoneyRoundingMode(rawValue: modeText == "halfEven" ? "bankers" : modeText)
        else {
            throw BackupError.portableUnsupported("This rounding policy is unsupported on iPhone.")
        }
        return try AgreementSnapshot(
            id: text(fields, "ruleID"), version: text(fields, "version"),
            displayName: text(fields, "displayName"),
            effectiveStart: (fields["effectiveStartDate"] as? String).map(date),
            effectiveEnd: (fields["effectiveEndDateInclusive"] as? String).map(date),
            hourlyRate: Money(amount: amount(fields, "hourlyRate"), currencyCode: currency),
            regularSchedule: schedules.map {
                try RegularScheduleWindow(
                    weekday: weekday(text($0, "weekday")), start: time(text($0, "start")),
                    end: time(text($0, "end")))
            },
            outsideScheduleMultiplier: amount(fields, "outsideScheduleMultiplier"),
            weekdayPremiums: weekdays.map {
                try WeekdayPremium(
                    weekday: weekday(text($0, "weekday")), multiplier: amount($0, "multiplier"))
            },
            datePremiums: dates.map {
                try DatePremium(date: date(text($0, "date")), multiplier: amount($0, "multiplier"))
            },
            dailyOvertimeTiers: tiers.map {
                try DailyOvertimeTier(
                    afterHours: amount($0, "afterHours"), multiplier: amount($0, "multiplier"))
            },
            calloutMinimum: (fields["calloutMinimumHours"] as? String).map {
                try CalloutMinimumRule(minimumHours: decimal($0))
            },
            flatPerDiem: (fields["perDiemPerWorkDate"] as? [String: Any]).map {
                try FlatPerDiemRule(
                    amountPerWorkDate: Money(
                        amount: amount($0, "amount"), currencyCode: text($0, "currency")))
            },
            weeklyOvertime: (fields["weeklyOvertime"] as? [String: Any]).map { weekly in
                guard
                    let applicability = WeeklyOvertimeApplicability(
                        rawValue: try text(weekly, "applicability"))
                else {
                    throw BackupError.portableUnsupported(
                        "This weekly applicability declaration needs a new native profile.")
                }
                return try WeeklyOvertimeRule(
                    workweekStart: weekday(text(weekly, "workweekStart")),
                    applicability: applicability, thresholdHours: amount(weekly, "thresholdHours"))
            },
            rounding: MoneyRoundingRule(scale: scale, mode: mode, scope: scope),
            sources: sources.map { source in
                if let key = source["ruleKey"] as? String, PayRuleKey(rawValue: key) == nil {
                    throw BackupError.portableUnsupported(
                        "An unknown source rule reference cannot be represented on this iPhone.")
                }
                return AgreementSource(
                    title: try text(source, "title"), url: try text(source, "url"),
                    section: source["section"] as? String,
                    verifiedEpochSeconds: source["verifiedEpochSeconds"] as? Int64,
                    ruleKey: (source["ruleKey"] as? String).flatMap(PayRuleKey.init(rawValue:)),
                    documentID: (source["documentRef"] as? String).map { local("attachment", $0) },
                    documentSHA256: source["documentSHA256"] as? String,
                    documentPage: source["documentPage"] as? Int,
                    quotedText: source["quotedText"] as? String)
            }, unsupportedRuleNotes: fields["unsupportedRuleNotes"] as? String,
            confirmedEpochSeconds: fields["confirmedAtEpochSeconds"] as? Int64)
    }
    private static func validateBoundary(
        _ fields: [String: Any], start: Int64, end: Int64, zone: String
    ) throws {
        guard let timeZone = TimeZone(identifier: zone), end > start else {
            throw BackupError.invalidArchive
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        for (key, epoch) in [
            ("startDate", start), ("endExclusiveDate", end), ("endDateInclusive", end - 1),
        ] {
            let expected = try date(text(fields, key))
            let parts = calendar.dateComponents(
                [.year, .month, .day], from: Date(timeIntervalSince1970: TimeInterval(epoch)))
            guard parts.year == expected.year, parts.month == expected.month,
                parts.day == expected.day
            else { throw BackupError.invalidArchive }
        }
        guard
            calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(start)))
                .timeIntervalSince1970 == TimeInterval(start),
            calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(end)))
                .timeIntervalSince1970 == TimeInterval(end)
        else { throw BackupError.invalidArchive }
    }
}
