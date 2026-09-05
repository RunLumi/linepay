import Foundation
import LinePayDomain
import Testing

@testable import LinePay

/// Fixed synthetic inputs and isolated storage. Tests never write to the production directory.
@MainActor
enum UnitFixture {
    static let start = Date(timeIntervalSince1970: 1_786_089_600)

    static func decimal(_ text: String) throws -> Decimal {
        try #require(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")))
    }

    static func profile(rate: String = "50", cadence: PayPeriodCadence = .weekly) -> PayProfileDraft {
        var draft = PayProfileDraft()
        draft.hourlyRate = rate
        draft.timeZoneIdentifier = "UTC"
        draft.periodStartDate = start
        draft.manualPeriodEndDate = start.addingTimeInterval(2 * 86_400)
        draft.preferredCadence = cadence
        return draft
    }

    static func populate(_ model: AppModel, evidence: Bool = false) throws {
        try model.saveProfile(profile())
        try model.addWork(start: start, end: start.addingTimeInterval(8 * 3_600), kind: .regular, note: "Synthetic shift")
        if evidence { try model.confirmPaystub(paystub(model, original: Data("SYNTHETIC ORIGINAL".utf8))) }
    }

    static func paystub(_ model: AppModel, gross: String = "400", original: Data? = nil) -> PaystubConfirmationDraft {
        var draft = PaystubConfirmationDraft()
        draft.payPeriodStartDate = model.activePeriod?.window.startDate
        draft.payPeriodEndDate = model.activePeriod?.window.displayEndDate
        draft.grossPay = gross
        draft.sourceData = original
        draft.originalFilename = "synthetic.pdf"
        draft.mediaType = "application/pdf"
        draft.sourceKind = original == nil ? .manual : .file
        return draft
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

@MainActor
final class UnitStateStore: AppStateStoring {
    var state: AppPersistentState?
    var failLoad = false
    var failSave = false
    var failReset = false
    var saveCount = 0
    var recoveryFileURL: URL? { nil }
    func load() throws -> AppPersistentState? {
        if failLoad { throw UnitFailure.injected }
        return state
    }
    func save(_ state: AppPersistentState) throws {
        if failSave { throw UnitFailure.injected }
        self.state = state
        saveCount += 1
    }
    func reset() throws {
        if failReset { throw UnitFailure.injected }
        state = nil
    }
}

enum UnitFailure: Error { case injected }
