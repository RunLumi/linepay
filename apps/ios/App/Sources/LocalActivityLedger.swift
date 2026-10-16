import CryptoKit
import Foundation
import Observation

/// Closed vocabulary only: callers cannot attach pay values, names, text, URLs or arbitrary attributes.
enum LocalMilestone: String, Codable, CaseIterable, Sendable {
    case firstObservedOpen = "first_observed_open"
    case appOpened = "app_opened"
    case profileStarted = "profile_started"
    case profileReady = "profile_ready"
    case workLogged = "work_logged"
    case expectedPaySeen = "expected_pay_seen"
    case paycheckIntakeStarted = "paycheck_intake_started"
    case paycheckImported = "paycheck_imported"
    case auditCompleted = "audit_completed"
    case secondAudit = "second_audit"
    case purchaseVerified = "purchase_verified"
    case verifiedTrialObserved = "verified_trial_observed"
    case verifiedPaidObserved = "verified_paid_observed"
    case backupRestored = "backup_restored"
}

enum LocalActivityIdentity {
    case once
    case period(UUID)
    case work(UUID)
    case transaction(UInt64)
    fileprivate var key: String {
        switch self {
        case .once: "once"
        case .period(let id): "period:\(id.uuidString)"
        case .work(let id): "work:\(id.uuidString)"
        case .transaction(let id): "transaction:\(id)"
        }
    }
}

struct LocalActivityTally: Codable, Equatable, Sendable {
    let milestone: LocalMilestone
    var count: Int
}

struct LocalActivityDay: Codable, Equatable, Sendable {
    let dayUTC: String
    var tallies: [LocalActivityTally]
}

/// Separate from AppPersistentState: restoring a pay backup must not create funnel observations.
struct LocalActivitySnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var recordingEnabled = true
    var firstObservedDayUTC: String?
    var days: [LocalActivityDay] = []
    var totals: [LocalActivityTally] = []
    var deduplicationDigests: [String] = []
    var prunedDayCount = 0
    var failedObservationCount = 0
    var recordingPauseCount = 0
}

@MainActor
protocol LocalActivityStoring {
    func load() throws -> LocalActivitySnapshot?
    func save(_ value: LocalActivitySnapshot) throws
}

@MainActor
final class MemoryLocalActivityStore: LocalActivityStoring {
    var value: LocalActivitySnapshot?
    func load() throws -> LocalActivitySnapshot? { value }
    func save(_ value: LocalActivitySnapshot) throws { self.value = value }
}

@MainActor
struct FileLocalActivityStore: LocalActivityStoring {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory =
            directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LinePayLocalActivity", isDirectory: true)
    }
    var url: URL { directory.appendingPathComponent("activity-v1.json") }
    func load() throws -> LocalActivitySnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try url.resourceValues(forKeys: [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
            let size = attributes.fileSize, size > 0, size <= 4 * 1_024 * 1_024
        else { throw LocalActivityError.invalidData }
        let parent = try directory.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard parent.isSymbolicLink != true else { throw LocalActivityError.invalidData }
        let bytes = try Data(contentsOf: url)
        guard bytes.count == size else { throw LocalActivityError.invalidData }
        return try JSONDecoder().decode(LocalActivitySnapshot.self, from: bytes)
    }
    func save(_ value: LocalActivitySnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let parent = try directory.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard parent.isSymbolicLink != true else { throw LocalActivityError.invalidData }
        let bytes = try JSONEncoder().encode(value)
        guard bytes.count <= 4 * 1_024 * 1_024 else { throw LocalActivityError.invalidData }
        try bytes.write(
            to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum LocalActivityError: Error { case invalidData, counterLimit }

@MainActor
@Observable
final class LocalActivityLedger {
    private(set) var snapshot = LocalActivitySnapshot()
    private(set) var issue: String?
    @ObservationIgnored private let store: any LocalActivityStoring
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var readable = true
    @ObservationIgnored private var pendingFailures = 0

    init(
        store: any LocalActivityStoring = MemoryLocalActivityStore(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.now = now
        do {
            let value = try store.load() ?? LocalActivitySnapshot()
            try Self.validate(value)
            snapshot = value
        } catch {
            readable = false
            snapshot.recordingEnabled = false
            issue =
                "Local activity could not be read. It has not been overwritten. Pay records are separate; clear only this activity when you want to restart it."
        }
    }

    func count(_ milestone: LocalMilestone) -> Int {
        snapshot.totals.first(where: { $0.milestone == milestone })?.count ?? 0
    }

    func record(_ milestone: LocalMilestone, once identity: LocalActivityIdentity? = nil) {
        guard readable, snapshot.recordingEnabled else { return }
        do {
            var value = snapshot
            if let identity {
                if case .once = identity, count(milestone) > 0 { return }
                let digest = SHA256.hash(data: Data("\(milestone.rawValue)|\(identity.key)".utf8))
                    .map { String(format: "%02x", $0) }.joined()
                guard !value.deduplicationDigests.contains(digest) else { return }
                value.deduplicationDigests.append(digest)
                if value.deduplicationDigests.count > 20_000 {
                    value.deduplicationDigests.removeFirst()
                }
            }
            if let index = value.totals.firstIndex(where: { $0.milestone == milestone }) {
                guard value.totals[index].count < 1_000_000_000 else {
                    throw LocalActivityError.counterLimit
                }
                value.totals[index].count += 1
            } else {
                value.totals.append(LocalActivityTally(milestone: milestone, count: 1))
            }
            let day = try Self.day(now())
            if value.firstObservedDayUTC == nil { value.firstObservedDayUTC = day }
            if !value.days.contains(where: { $0.dayUTC == day }) {
                value.days.append(LocalActivityDay(dayUTC: day, tallies: []))
            }
            guard let dayIndex = value.days.firstIndex(where: { $0.dayUTC == day }) else { return }
            if let index = value.days[dayIndex].tallies.firstIndex(where: {
                $0.milestone == milestone
            }) {
                guard value.days[dayIndex].tallies[index].count < 1_000_000_000 else {
                    throw LocalActivityError.counterLimit
                }
                value.days[dayIndex].tallies[index].count += 1
            } else {
                value.days[dayIndex].tallies.append(
                    LocalActivityTally(milestone: milestone, count: 1))
            }
            value.days.sort { $0.dayUTC < $1.dayUTC }
            while value.days.count > 400 {
                value.days.removeFirst()
                value.prunedDayCount += 1
            }
            try persist(value)
        } catch {
            pendingFailures = min(1_000_000_000, pendingFailures + 1)
            issue =
                "A local activity observation could not be saved. Pay records are unchanged. Counts may be incomplete; retry after checking storage."
        }
    }

    func setRecordingEnabled(_ enabled: Bool) throws {
        guard readable else { throw LocalActivityError.invalidData }
        guard snapshot.recordingEnabled != enabled else { return }
        var value = snapshot
        if !enabled { value.recordingPauseCount += 1 }
        value.recordingEnabled = enabled
        try persist(value)
    }

    /// Explicit user reset, including recovery from an unreadable activity file. Preserve opt-out.
    func clear() throws {
        var value = LocalActivitySnapshot()
        value.recordingEnabled = snapshot.recordingEnabled
        try persist(value, resettingFailures: true)
        readable = true
    }

    func diagnosticData() throws -> Data {
        let export = LocalDiagnosticExport(
            schemaVersion: 1,
            generatedDayUTC: try Self.day(now()), firstObservedDayUTC: snapshot.firstObservedDayUTC,
            recordingEnabled: snapshot.recordingEnabled,
            recordingIssue: issue != nil || snapshot.failedObservationCount > 0
                || pendingFailures > 0,
            failedObservationCount: snapshot.failedObservationCount + pendingFailures,
            recordingPauseCount: snapshot.recordingPauseCount,
            prunedDayCount: snapshot.prunedDayCount,
            totals: LocalMilestone.allCases.map {
                LocalActivityTally(milestone: $0, count: count($0))
            },
            days: snapshot.days,
            scope:
                "Device-local lifetime totals since this ledger reset, with up to 400 observed UTC days of breakdown and 20,000 deduplication digests. Old repeated identities may be counted again after deduplication retention. Not App Store installs, global cohorts or subscriber counts. Restores do not backfill history. Verified commerce observations can include existing subscriptions and renewals. Disabled recording, failures and retention make counts incomplete. No pay amounts, payroll dates, names, source text, identifiers or deduplication keys are exported. Usage days/counts can still be personal; this file is not anonymous or a pay-data backup."
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    private func persist(_ incoming: LocalActivitySnapshot, resettingFailures: Bool = false) throws
    {
        var value = incoming
        if !resettingFailures { value.failedObservationCount += pendingFailures }
        try Self.validate(value)
        try store.save(value)
        snapshot = value
        pendingFailures = 0
        issue = nil
    }

    private static func day(_ date: Date) throws -> String {
        guard date.timeIntervalSince1970.isFinite,
            (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
        else { throw LocalActivityError.invalidData }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0,
            components.day ?? 0)
    }

    static func validate(_ value: LocalActivitySnapshot) throws {
        guard value.schemaVersion == 1, value.days.count <= 400,
            value.prunedDayCount >= 0 && value.prunedDayCount < 1_000_000_000,
            (0...1_000_000_000).contains(value.failedObservationCount),
            (0...1_000_000_000).contains(value.recordingPauseCount),
            value.totals.count <= LocalMilestone.allCases.count,
            Set(value.totals.map(\.milestone)).count == value.totals.count,
            value.totals.allSatisfy({ (1...1_000_000_000).contains($0.count) }),
            value.deduplicationDigests.count <= 20_000,
            Set(value.deduplicationDigests).count == value.deduplicationDigests.count,
            value.deduplicationDigests.allSatisfy(AgreementImportValidation.isDigest),
            Set(value.days.map(\.dayUTC)).count == value.days.count,
            value.days.map(\.dayUTC) == value.days.map(\.dayUTC).sorted()
        else { throw LocalActivityError.invalidData }
        let dateStrings = value.days.map(\.dayUTC) + [value.firstObservedDayUTC].compactMap { $0 }
        for text in dateStrings {
            guard text.count == 10, let normalized = PaystubTextParser.normalizedDate(text),
                normalized == text
            else { throw LocalActivityError.invalidData }
        }
        for day in value.days {
            guard day.tallies.count <= LocalMilestone.allCases.count,
                Set(day.tallies.map(\.milestone)).count == day.tallies.count,
                day.tallies.allSatisfy({ (1...1_000_000_000).contains($0.count) })
            else { throw LocalActivityError.invalidData }
        }
    }
}

struct LocalDiagnosticExport: Codable, Sendable {
    let schemaVersion: Int
    let generatedDayUTC: String
    let firstObservedDayUTC: String?
    let recordingEnabled: Bool
    let recordingIssue: Bool
    let failedObservationCount: Int
    let recordingPauseCount: Int
    let prunedDayCount: Int
    let totals: [LocalActivityTally]
    let days: [LocalActivityDay]
    let scope: String
}
