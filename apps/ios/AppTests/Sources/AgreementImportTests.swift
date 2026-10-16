import Foundation
import LinePayDomain
import PDFKit
import Testing
import UIKit

@testable import LinePay

@Suite("Local agreement proposals", .serialized)
@MainActor
struct AgreementImportTests {
    @Test(arguments: [
        ("Base hourly rate: USD 58.40 per hour", ImportedRuleKind.baseRate, "58.40", ""),
        ("Daily overtime: after 8 hours at 1.5x", .dailyOvertime, "8", "1.5"),
        ("Daily double time: after 12 hours at 2x", .dailyDoubleTime, "12", "2"),
        ("Sunday premium: 2x", .sundayPremium, "2", ""),
        ("Callout minimum: 4 hours", .calloutMinimum, "4", ""),
        ("Per diem: USD 125.00 per worked date", .perDiem, "125.00", ""),
        ("Effective from: 2026-08-14", .effectiveStart, "2026-08-14", ""),
    ])
    func exactCandidatesKeepTheirSourceAndRemainUnreviewed(
        _ sample: (String, ImportedRuleKind, String, String)
    ) throws {
        let candidates = AgreementClauseParser.parse([
            AgreementTextLine(text: sample.0, page: 3, confidence: nil)
        ])
        let candidate = try #require(candidates.first)
        #expect(candidates.count == 1)
        #expect(candidate.kind == sample.1)
        #expect(candidate.value == sample.2)
        #expect((candidate.multiplier ?? "") == sample.3)
        #expect(candidate.quote == sample.0 && candidate.page == 3)
        #expect(candidate.status == .suggested)
        if sample.0.contains("USD") { #expect(candidate.currencyCode == "USD") }
        #expect(ImportedRuleReview(candidate: candidate).decision == .unreviewed)
    }

    @Test func conflictingBaseRatesNeverSelectAClassificationForTheWorker() {
        let candidates = AgreementClauseParser.parse([
            AgreementTextLine(
                text: "Base hourly rate: USD 50.00 per hour", page: 0, confidence: nil),
            AgreementTextLine(
                text: "Base hourly rate: USD 60.00 per hour", page: 1, confidence: nil),
        ])
        #expect(candidates.count == 2)
        #expect(candidates.allSatisfy { $0.status == .conflicting })
    }

    @Test(arguments: [
        "Callout minimum: 4 hours unless adjoining regular work",
        "Base hourly rate: USD 50.00 per hour subject to classification",
        "Sunday premium: 2x in lieu of overtime",
    ])
    func conditionalClausesAreNotReducedToAnUnconditionalRule(_ quote: String) throws {
        let candidate = try #require(
            AgreementClauseParser.parse([
                AgreementTextLine(text: quote, page: 0, confidence: nil)
            ]).first)
        #expect(candidate.status == .unsupported)
        #expect(candidate.value == nil)
    }

    @Test func lowConfidenceAbstainsAndIDsAreReproducible() throws {
        let line = AgreementTextLine(
            text: "Base hourly rate: USD 50.00 per hour", page: 0, confidence: 0.4)
        let first = try #require(AgreementClauseParser.parse([line]).first)
        #expect(first.value == nil && first.status == .manualReview)
        #expect(AgreementClauseParser.parse([line]).first?.id == first.id)
    }

    @Test func preparationRequiresDatesApplicabilityAndEveryDecision() throws {
        let document = fixtureDocument()
        var review = reviewed(document)
        review.datesConfirmed = false
        #expect(throws: (any Error).self) {
            try AgreementImportDraftBuilder.build(
                document: document, review: review, profile: nil, activePeriod: nil)
        }
        review = reviewed(document)
        review.rules[0].decision = .unreviewed
        #expect(throws: (any Error).self) {
            try AgreementImportDraftBuilder.build(
                document: document, review: review, profile: nil, activePeriod: nil)
        }
        review = reviewed(document)
        review.applicabilityConfirmed = false
        #expect(throws: (any Error).self) {
            try AgreementImportDraftBuilder.build(
                document: document, review: review, profile: nil, activePeriod: nil)
        }
    }

    @Test func realPDFRetainedPreparedAndExplicitlyActivatedWithoutRepricingHistory() async throws {
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UnitStateStore()
        let originals = LocalEvidenceStore(baseDirectory: directory)
        let model = AppModel(store: store, evidenceStore: originals)
        try UnitFixture.populate(model)
        let initial = try #require(model.calculation)
        let bytes = pdf([
            "Base hourly rate: USD 60.00 per hour",
            "Daily overtime: after 8 hours at 1.5x", "Effective from: 2026-08-14",
        ])
        let id = try model.retainAgreement(data: bytes, filename: "synthetic-agreement.pdf")
        let extracted = try await AgreementDocumentService().extract(bytes)
        try model.finishAgreementExtraction(id: id, result: extracted)
        let document = try #require(model.agreementDocument(id: id))
        try model.saveAgreementReview(id: id, review: reviewed(document))
        try await model.prepareImportedAgreement(id: id)
        #expect(model.calculation == initial)
        #expect(model.profile?.agreement.hourlyRate.amount == 50)
        let draft = try #require(model.setupDraft)
        #expect(draft.hourlyRate == "60.00")
        let citation = try #require(draft.additionalSources.first { $0.ruleKey == .base })
        #expect(
            citation.documentID == id
                && citation.documentSHA256 == AgreementDocumentService.digest(bytes))
        #expect(
            citation.documentPage == 0
                && citation.quotedText == "Base hourly rate: USD 60.00 per hour")
        #expect(!model.canDeleteAgreementImport(id: id))
        try model.saveProfile(draft, scope: .prospective)
        #expect(model.calculation?.expectedWages.amount == 400)
        try model.archiveCurrentPeriod()
        let next = try #require(model.activePeriod)
        try model.addWork(
            start: next.window.startDate, end: next.window.startDate.addingTimeInterval(8 * 3_600),
            kind: .regular, note: "Synthetic imported-rule work")
        #expect(model.calculation?.expectedWages.amount == 480)
        #expect(model.history.first?.calculation?.expectedWages.amount == 400)
        #expect(model.activePeriod?.agreement.sources.contains { $0.documentID == id } == true)
    }

    @Test func newProfileCanPrepareAnIncompleteManualDraftWithoutInventingABaseRate() throws {
        var document = fixtureDocument()
        document.candidates = []
        document.extractionNotice = "No supported clauses found; manual review required."
        let draft = try AgreementImportDraftBuilder.build(
            document: document, review: reviewed(document), profile: nil, activePeriod: nil)
        #expect(draft.hourlyRate.isEmpty)
        #expect(!draft.useDailyOvertime && !draft.useCalloutMinimum && !draft.usePerDiem)
        #expect(draft.unsupportedRuleNotes.contains("manual review"))
    }

    @Test func scannedPDFUsesLocalRecognitionAndRetainsPhysicalPageCitation() async throws {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let image = UIGraphicsImageRenderer(size: bounds.size).image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            for (index, line) in [
                "SYNTHETIC AGREEMENT", "Base hourly rate: USD 60.00 per hour",
                "Effective from: 2026-08-14",
            ].enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 36, y: 60 + index * 40),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black,
                    ])
            }
        }
        let bytes = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        #expect(
            PDFDocument(data: bytes)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty != false)
        let result = try await AgreementDocumentService().extract(bytes)
        let base = try #require(result.candidates.first { $0.kind == .baseRate })
        #expect(base.value == "60.00" && base.currencyCode == "USD")
        #expect(base.page == 0 && base.recognitionConfidence != nil)
        #expect(base.status == .suggested)
        #expect(ImportedRuleReview(candidate: base).decision == .unreviewed)
    }

    func fixtureDocument() -> ImportedAgreementDocument {
        let lines = ["Base hourly rate: USD 60.00 per hour", "Effective from: 2026-08-14"]
        return ImportedAgreementDocument(
            id: UUID(), filename: "synthetic-agreement.pdf",
            sha256: String(repeating: "a", count: 64),
            pageCount: 1,
            candidates: AgreementClauseParser.parse(
                lines.map { AgreementTextLine(text: $0, page: 0, confidence: nil) }),
            importedEpochSeconds: 0, extractionVersion: AgreementClauseParser.version)
    }

    func reviewed(_ document: ImportedAgreementDocument) -> AgreementImportReview {
        var review = AgreementImportReview()
        review.rules = (document.candidates ?? []).map { candidate in
            var value = ImportedRuleReview(candidate: candidate)
            value.decision = candidate.status == .unsupported ? .unresolved : .confirmed
            return value
        }
        review.currencyCode = "USD"
        review.timeZoneIdentifier = "UTC"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        review.startDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 14))
        review.applicabilityConfirmed = true
        review.currencyConfirmed = true
        review.datesConfirmed = true
        review.noEndDateSpecified = true
        review.dailyTierReplacementConfirmed = true
        return review
    }

    func pdf(_ lines: [String]) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(bounds)
            for (index, line) in (["SYNTHETIC AGREEMENT"] + lines).enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 36, y: 60 + index * 34),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black,
                    ])
            }
        }
    }
}
