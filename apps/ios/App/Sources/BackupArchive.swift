import CryptoKit
import Foundation
import LinePayDomain

/// A bounded, self-contained snapshot. Checksums detect damage, not malicious authorship.
struct BackupArchive: Sendable {
    static let maximumBytes = 64 * 1_024 * 1_024
    static let maximumStateBytes = 8 * 1_024 * 1_024
    static let maximumEvidenceBytes = 25 * 1_024 * 1_024
    static let maximumEvidenceCount = 512

    struct EvidenceFile: Codable, Sendable {
        let id: UUID
        let bytes: Data
    }

    struct Payload: Codable, Sendable {
        let createdAt: Date
        let stateJSON: Data
        let files: [EvidenceFile]
    }

    struct Envelope: Codable {
        let format: String
        let version: Int
        let payload: Data
        let sha256: Data
    }

    let createdAt: Date
    let state: AppPersistentState
    let files: [EvidenceFile]

    var workCount: Int {
        (state.activePeriod?.workEntries.count ?? 0)
            + state.history.reduce(0) { $0 + $1.workEntries.count }
    }

    var periodCount: Int { state.history.count + (state.activePeriod == nil ? 0 : 1) }

    func validate() throws {
        guard createdAt.timeIntervalSince1970.isFinite else { throw BackupError.invalidArchive }
        try Self.validate(state: state, files: files)
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let stateJSON = try encoder.encode(state)
        guard stateJSON.count <= Self.maximumStateBytes else { throw BackupError.tooLarge }
        let plist = PropertyListEncoder()
        plist.outputFormat = .binary
        let payload = try plist.encode(
            Payload(createdAt: createdAt, stateJSON: stateJSON, files: files))
        let data = try plist.encode(
            Envelope(
                format: "com.streamentry.linepay.backup", version: 1,
                payload: payload, sha256: Data(SHA256.hash(data: payload))
            )
        )
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        do {
            let decoder = PropertyListDecoder()
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.format == "com.streamentry.linepay.backup" else {
                throw BackupError.invalidArchive
            }
            guard envelope.version == 1 else { throw BackupError.newerVersion }
            guard Data(SHA256.hash(data: envelope.payload)) == envelope.sha256 else {
                throw BackupError.damagedArchive
            }
            let payload = try decoder.decode(Payload.self, from: envelope.payload)
            guard payload.stateJSON.count <= maximumStateBytes else { throw BackupError.tooLarge }
            let decoded = try JSONDecoder().decode(AppPersistentState.self, from: payload.stateJSON)
            guard
                decoded.schemaVersion == 1
                    || decoded.schemaVersion == AppPersistentState.currentSchemaVersion
            else {
                throw BackupError.newerVersion
            }
            let state = try decoded.upgraded()
            guard payload.createdAt.timeIntervalSince1970.isFinite else {
                throw BackupError.invalidArchive
            }
            try validate(state: state, files: payload.files)
            return BackupArchive(createdAt: payload.createdAt, state: state, files: payload.files)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.invalidArchive
        }
    }

    static func evidence(in state: AppPersistentState) throws -> [PaystubEvidence] {
        let references =
            ([state.activePeriod?.paystub?.evidence]
            + state.history.map { $0.paystub?.evidence }).compactMap { $0 }
        var unique: [UUID: PaystubEvidence] = [:]
        for reference in references {
            // Never allow an imported path to reach the local evidence store.
            guard isSafeFilename(reference.storedFilename) else { throw BackupError.invalidArchive }
            if let existing = unique[reference.id], existing != reference {
                throw BackupError.invalidArchive
            }
            unique[reference.id] = reference
        }
        return unique.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    static func isSafeFilename(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return !value.isEmpty && value.count <= 150 && value != "." && value != ".."
            && value.unicodeScalars.allSatisfy { allowed.contains($0) }
            && !value.contains("..")
    }

    private static func validate(state: AppPersistentState, files: [EvidenceFile]) throws {
        guard state.schemaVersion == AppPersistentState.currentSchemaVersion else {
            throw BackupError.newerVersion
        }
        let references = try evidence(in: state)
        guard files.count <= maximumEvidenceCount,
            Set(files.map(\.id)).count == files.count,
            Set(files.map(\.id)) == Set(references.map(\.id))
        else { throw BackupError.missingEvidence }
        var total = 0
        for file in files {
            guard !file.bytes.isEmpty, file.bytes.count <= maximumEvidenceBytes else {
                throw BackupError.tooLarge
            }
            total += file.bytes.count
            guard total <= maximumBytes else { throw BackupError.tooLarge }
        }
        let ids = state.history.map(\.id) + [state.activePeriod?.id].compactMap { $0 }
        guard Set(ids).count == ids.count, ids.count <= 2_000 else {
            throw BackupError.invalidArchive
        }
        guard state.profile != nil || ids.isEmpty else { throw BackupError.invalidArchive }
        if let zone = state.profile?.timeZoneIdentifier, TimeZone(identifier: zone) == nil {
            throw BackupError.invalidArchive
        }
        if let profile = state.profile {
            try validate(agreement: profile.agreement)
            try validateTimeline(
                baseline: profile.baselineAgreement ?? profile.agreement,
                changes: profile.agreementChanges ?? [])
        }
        if let active = state.activePeriod {
            try validateTimeline(baseline: active.agreement, changes: active.agreementChanges ?? [])
            try validate(
                window: active.window, entries: active.workEntries, zone: active.timeZoneIdentifier)
        }
        for period in state.history {
            try validateTimeline(baseline: period.agreement, changes: period.agreementChanges ?? [])
            let snapshots = period.calculation.agreementSnapshots ?? [period.agreement]
            for snapshot in snapshots { try validate(agreement: snapshot) }
            for component in period.calculation.components {
                if let reference = component.appliedAgreement {
                    guard snapshots.contains(where: { AgreementReference($0) == reference }) else {
                        throw BackupError.invalidArchive
                    }
                }
            }
            guard period.calculation.agreementID == period.agreement.id,
                period.calculation.agreementVersion == period.agreement.version,
                !period.calculation.total.amount.isNaN
            else { throw BackupError.invalidArchive }
            try validate(
                window: period.window, entries: period.workEntries, zone: period.timeZoneIdentifier)
        }
    }

    private static func validateTimeline(baseline: AgreementSnapshot, changes: [AgreementChange])
        throws
    {
        _ = try AgreementTimeline(baseline: baseline, changes: changes)
        try validate(agreement: baseline)
        for change in changes { try validate(agreement: change.agreement) }
    }

    private static func validate(agreement: AgreementSnapshot) throws {
        guard !agreement.hourlyRate.amount.isNaN, agreement.hourlyRate.amount >= 0,
            agreement.hourlyRate.currencyCode.utf8.count == 3,
            agreement.hourlyRate.currencyCode.utf8.allSatisfy({ (65...90).contains($0) }),
            (0...8).contains(agreement.rounding.scale),
            !agreement.outsideScheduleMultiplier.isNaN,
            agreement.outsideScheduleMultiplier >= 1,
            Set(agreement.dailyOvertimeTiers.map(\.afterHours)).count
                == agreement.dailyOvertimeTiers.count
        else { throw BackupError.invalidArchive }
        for window in agreement.regularSchedule {
            let start = try LocalTime(hour: window.start.hour, minute: window.start.minute)
            let end = try LocalTime(hour: window.end.hour, minute: window.end.minute)
            _ = try RegularScheduleWindow(weekday: window.weekday, start: start, end: end)
        }
        for tier in agreement.dailyOvertimeTiers {
            guard !tier.afterHours.isNaN, !tier.multiplier.isNaN else {
                throw BackupError.invalidArchive
            }
            _ = try DailyOvertimeTier(afterHours: tier.afterHours, multiplier: tier.multiplier)
        }
        for premium in agreement.weekdayPremiums {
            guard !premium.multiplier.isNaN else { throw BackupError.invalidArchive }
            _ = try WeekdayPremium(weekday: premium.weekday, multiplier: premium.multiplier)
        }
        for premium in agreement.datePremiums {
            try validate(date: premium.date)
            guard !premium.multiplier.isNaN else { throw BackupError.invalidArchive }
            _ = try DatePremium(date: premium.date, multiplier: premium.multiplier)
        }
        if let date = agreement.effectiveStart { try validate(date: date) }
        if let date = agreement.effectiveEnd { try validate(date: date) }
        if let minimum = agreement.calloutMinimum {
            guard !minimum.minimumHours.isNaN else { throw BackupError.invalidArchive }
            _ = try CalloutMinimumRule(minimumHours: minimum.minimumHours)
        }
        if let perDiem = agreement.flatPerDiem {
            guard !perDiem.amountPerWorkDate.amount.isNaN,
                perDiem.amountPerWorkDate.currencyCode == agreement.hourlyRate.currencyCode
            else { throw BackupError.invalidArchive }
        }
    }

    private static func validate(date: LocalDate) throws {
        guard (1...9_999).contains(date.year), (1...12).contains(date.month),
            (1...31).contains(date.day)
        else { throw BackupError.invalidArchive }
    }

    private static func validate(window: PayPeriodWindow, entries: [WorkEntry], zone: String?)
        throws
    {
        // Bound dates before downstream subtraction/calendar operations on imported Int64 values.
        let epochRange: ClosedRange<Int64> = -62_135_596_800...253_402_300_799
        guard epochRange.contains(window.startEpochSeconds),
            epochRange.contains(window.endEpochSeconds),
            window.endEpochSeconds > window.startEpochSeconds,
            entries.count <= 50_000, Set(entries.map(\.id)).count == entries.count
        else { throw BackupError.invalidArchive }
        if let zone, TimeZone(identifier: zone) == nil { throw BackupError.invalidArchive }
        let sorted = entries.sorted {
            $0.interval.startEpochSeconds < $1.interval.startEpochSeconds
        }
        var previousEnd: Int64?
        for entry in sorted {
            let work = entry.interval
            guard work.startEpochSeconds >= window.startEpochSeconds,
                work.endEpochSeconds <= window.endEpochSeconds,
                work.endEpochSeconds > work.startEpochSeconds,
                TimeZone(identifier: work.timeZoneIdentifier) != nil
            else { throw BackupError.invalidArchive }
            if let previousEnd, work.startEpochSeconds < previousEnd {
                throw BackupError.invalidArchive
            }
            // Synthesized Codable does not rerun validating initializers.
            let breaks = try work.unpaidBreaks.map {
                try WorkBreak(
                    id: $0.id, startEpochSeconds: $0.startEpochSeconds,
                    endEpochSeconds: $0.endEpochSeconds)
            }
            _ = try WorkInterval(
                id: work.id, startEpochSeconds: work.startEpochSeconds,
                endEpochSeconds: work.endEpochSeconds, timeZoneIdentifier: work.timeZoneIdentifier,
                kind: work.kind, unpaidBreaks: breaks
            )
            previousEnd = work.endEpochSeconds
        }
    }
}

enum BackupError: LocalizedError, Equatable {
    case operationInProgress
    case tooLarge
    case invalidArchive
    case damagedArchive
    case newerVersion
    case missingEvidence
    case unavailableFile
    case currentDataUnreadable
    case restoreFailed
    case cleanupFailed

    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            "A backup operation is already running."
        case .tooLarge:
            "This backup exceeds the supported size (64 MB total, 25 MB per original). No local data changed."
        case .invalidArchive:
            "This is not a valid complete LinePaycheck backup. Older JSON-only exports cannot be restored here."
        case .damagedArchive:
            "This backup failed its integrity check. Choose another copy. No local data changed."
        case .newerVersion:
            "This backup uses an unsupported version. Update LinePaycheck before restoring."
        case .missingEvidence:
            "A referenced paystub original is missing or duplicated. A complete backup must include every retained original."
        case .unavailableFile:
            "The file could not be read. Download it in Files, check iCloud Drive and your connection, then retry."
        case .currentDataUnreadable:
            "The current data could not be read. Export the recovery file before replacing it with a backup."
        case .restoreFailed:
            "Restore did not complete. Your existing records are unchanged. Free device storage and retry."
        case .cleanupFailed:
            "Restore did not complete. Existing records are unchanged, but temporary imported originals could not all be removed."
        }
    }
}
