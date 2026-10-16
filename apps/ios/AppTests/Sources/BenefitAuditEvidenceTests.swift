import Foundation
import LinePayDomain
import PDFKit
import Testing

@testable import LinePay

@Suite("Benefits originals, review invalidation and report privacy", .serialized)
@MainActor
struct BenefitAuditEvidenceTests {
    @Test func retainedStatementIsNotAnAutomaticReadingAndSurvivesRealBackupRestore() async throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(
            store: store,
            evidenceStore: LocalEvidenceStore(
                baseDirectory: root.appendingPathComponent("originals")))
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        try model.keepBenefitDraft(draft)
        let bytes = AgreementImportTests().pdf([
            "Employer contribution: USD 310.63", "Eligible hours: 35.5",
        ])
        try model.retainBenefitStatement(
            data: bytes, filename: "synthetic-benefits.pdf", draftID: draft.id)
        var reviewed = try #require(model.benefitAuditDraft)
        #expect(
            reviewed.statementAmount.isEmpty && reviewed.statementQuantity.isEmpty
                && !reviewed.statementConfirmed)
        let original = try #require(reviewed.statementEvidence)
        reviewed.statementAmount = "310.63"
        reviewed.statementQuantity = "35.5"
        reviewed.statementMatchesFund = true
        try model.keepBenefitDraft(reviewed)
        reviewed = try #require(model.benefitAuditDraft)
        reviewed.statementConfirmed = true
        try model.keepBenefitDraft(reviewed)
        try model.saveBenefitCheck(reviewed)
        let state = try #require(store.state)
        let archive = BackupArchive(
            createdAt: UnitFixture.start, state: state,
            files: [BackupArchive.EvidenceFile(id: original.id, bytes: bytes)])
        let session = AppSession(
            store: VersionedLocalStateStore(
                baseDirectory: root.appendingPathComponent("restored-state")),
            evidenceStore: LocalEvidenceStore(
                baseDirectory: root.appendingPathComponent("restored-originals")))
        try session.restore(BackupArchive.decode(archive.encoded()))
        let restored = try #require(session.model.benefitAuditRecords.first?.revisions.first)
        #expect(restored.result == model.benefitAuditRecords.first?.revisions.first?.result)
        #expect(restored.input.statementSHA256 == AgreementDocumentService.digest(bytes))
        let restoredFile = try #require(restored.input.statementEvidence)
        #expect(
            restoredFile.id == original.id && restoredFile.storedFilename != original.storedFilename
        )
        let url = try #require(session.model.evidenceURL(for: restoredFile))
        #expect(try Data(contentsOf: url) == bytes)
        _ = try await AgreementDocumentService.verifiedURL(
            url, sha256: AgreementDocumentService.digest(bytes), page: 0)
        let resultBefore = restored.result
        try session.model.removeEvidence(id: restoredFile.id)
        let after = try #require(session.model.benefitAuditRecords.first?.revisions.first)
        #expect(
            after.input.statementEvidence == nil
                && after.input.statementSHA256 == restored.input.statementSHA256)
        #expect(
            after.result == resultBefore && session.model.calculation?.expectedWages.amount == 400)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func materialChangesInvalidateReviewButNotesAndConfirmingDoNot() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        draft.statementAmount = "350"
        draft.statementMatchesFund = true
        draft.statementConfirmed = true
        try model.keepBenefitDraft(draft)
        var rateChange = draft
        rateChange.segments[0].rate = "9"
        try model.keepBenefitDraft(rateChange)
        let invalidated = try #require(model.benefitAuditDraft)
        #expect(!invalidated.rulesConfirmed && !invalidated.completeEligibilityConfirmed)
        #expect(!invalidated.segments[0].eligibilityConfirmed && !invalidated.statementConfirmed)
        var checked = invalidated
        checked.rulesConfirmed = true
        checked.completeEligibilityConfirmed = true
        checked.segments[0].eligibilityConfirmed = true
        checked.statementConfirmed = true
        try model.keepBenefitDraft(checked)
        #expect(model.benefitAuditDraft == checked)
        checked.note = "Synthetic note changed, not the facts"
        try model.keepBenefitDraft(checked)
        #expect(model.benefitAuditDraft == checked)
        var statementChange = checked
        statementChange.statementQuantity = "39"
        try model.keepBenefitDraft(statementChange)
        let statementReview = try #require(model.benefitAuditDraft)
        #expect(!statementReview.statementConfirmed && statementReview.rulesConfirmed)
        #expect(statementReview.segments[0].eligibilityConfirmed)
    }

    @Test func failedOrLateStatementImportCannotAttachToAnotherDraft() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = UnitStateStore()
        let model = AppModel(store: store, evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        try model.keepBenefitDraft(draft)
        let bytes = AgreementImportTests().pdf(["SYNTHETIC BENEFITS SOURCE"])
        #expect(throws: (any Error).self) {
            try model.retainBenefitStatement(
                data: bytes, filename: "synthetic.pdf", draftID: UUID())
        }
        let before = store.state
        store.failSave = true
        #expect(throws: AppModelError.persistenceFailed) {
            try model.retainBenefitStatement(
                data: bytes, filename: "synthetic.pdf", draftID: draft.id)
        }
        #expect(store.state == before && model.benefitAuditDraft == draft)
        store.failSave = false
        try model.retryEvidenceDeletion()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func withdrawingStatementIntakeRejectsItsLateOriginal() throws {
        let root = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            store: UnitStateStore(), evidenceStore: LocalEvidenceStore(baseDirectory: root))
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        try model.keepBenefitDraft(draft)
        let bytes = AgreementImportTests().pdf(["SYNTHETIC LATE STATEMENT"])
        draft.hasStatement = false
        try model.keepBenefitDraft(draft)
        #expect(throws: (any Error).self) {
            try model.retainBenefitStatement(
                data: bytes, filename: "synthetic.pdf", draftID: draft.id)
        }
        #expect(model.benefitAuditDraft?.hasStatement == false)
        #expect(model.benefitAuditDraft?.statementEvidence == nil)
        let files =
            FileManager.default.fileExists(atPath: root.path)
            ? try FileManager.default.contentsOfDirectory(atPath: root.path) : []
        #expect(files.isEmpty)
    }

    @Test func sourceDetailsAndPrivateNoteRequireIndependentReportChoices() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.fundName = "SYNTHETIC PRIVATE FUND"
        draft.note = "SYNTHETIC PRIVATE NOTE"
        let quote = "SYNTHETIC PRIVATE AGREEMENT QUOTE"
        let hash = String(repeating: "a", count: 64)
        draft.segments[0].sources = [
            AgreementSource(
                title: "SYNTHETIC PRIVATE SOURCE", url: "",
                documentID: UUID(), documentSHA256: hash, documentPage: 0, quotedText: quote)
        ]
        try model.saveBenefitCheck(draft)
        let revision = try #require(model.benefitAuditRecords.first?.revisions.first)
        for (sources, notes) in [(false, false), (true, false), (false, true), (true, true)] {
            let url = try BenefitReportExporter().export(
                revision,
                privacy: ReportPrivacyOptions(
                    includeSourceDetails: sources, includeBenefitNotes: notes))
            defer { try? TemporaryExports.removeReport(url) }
            let text = try #require(PDFDocument(url: url)?.string)
            #expect(text.contains("USD 350"))
            #expect(text.contains(draft.fundName) == sources)
            #expect(text.contains(quote) == sources && text.contains(hash) == sources)
            #expect(text.contains(draft.note) == notes)
            #expect(text.contains("not a recovery amount"))
        }
    }

    @Test func closingABenefitsPreviewRemovesOnlyItsOwnedTemporaryCopy() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        try model.saveBenefitCheck(filled(model))
        let before = model.benefitAuditRecords
        let revision = try #require(before.first?.revisions.first)
        var session = ReportShareSession { privacy in
            try BenefitReportExporter().export(revision, privacy: privacy)
        }
        session.prepare(privacy: ReportPrivacyOptions())
        let report = try #require(session.preparedReport)
        defer { try? FileManager.default.removeItem(at: report.url) }
        session.previewLoaded(report)
        #expect(session.shareURL == report.url)
        session.discard()
        #expect(session.shareURL == nil && session.preparedReport == nil)
        #expect(session.errorMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: report.url.path))
        #expect(
            model.benefitAuditRecords == before && model.calculation?.expectedWages.amount == 400)
    }

    @Test func preciseStatementAmountIsPreservedAcrossNativeSave() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        draft.statementMatchesFund = true
        draft.statementConfirmed = true
        draft.statementAmount = "350.001"
        try model.saveBenefitCheck(draft)
        let result = try #require(model.benefitAuditRecords.first?.revisions.first?.result)
        #expect(result.confirmedEmployerContribution?.amount == Decimal(string: "350.001"))
        #expect(result.contributionDifference?.amount == Decimal(string: "-0.001"))
        #expect(
            result.status == .possibleDifference && model.calculation?.expectedWages.amount == 400)
    }

    @Test func anotherPeriodKeepsFundIdentityButDoesNotInventNewRatesOrWork() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        let id = try model.saveBenefitCheck(filled(model))
        let first = try #require(model.benefitAuditRecords.first)
        let next = try model.startAnotherBenefitPeriod(recordID: id)
        #expect(next.fundID == first.fundID && next.recordID == nil && next.baseRevisionID == nil)
        #expect(next.segments[0].rate.isEmpty && next.segments[0].quantity.isEmpty)
        #expect(!next.hasStatement && !next.rulesConfirmed && !next.completeEligibilityConfirmed)
        #expect(model.benefitAuditRecords.first == first)
    }

    @Test func verySmallAndLargeRecordedValuesStayVisibleWithoutDisplayRounding() {
        let tiny = Money(amount: Decimal(string: "0.00000001")!, currencyCode: "USD")
        let large = Money(
            amount: Decimal(string: "12345678901234567890.12345678")!, currencyCode: "CAD")
        #expect(benefitMoney(tiny).contains("00000001"))
        #expect(
            benefitMoney(large).replacingOccurrences(of: ",", with: ".")
                == "CAD 12345678901234567890.12345678")
    }

    @Test func regionConversionPreservesExactValuesAndRequiresFreshReview() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.hasStatement = true
        draft.statementMatchesFund = true
        draft.statementAmount = "310.63000001"
        draft.statementQuantity = "35.5"
        draft.statementConfirmed = true
        let before = try draft.calculate()
        var converted = try draft.convertingNumbers(to: ",")
        #expect(converted.segments[0].rate == "8,75" && converted.statementAmount == "310,63000001")
        #expect(converted.statementQuantity == "35,5" && converted.decimalSeparator == ",")
        #expect(
            !converted.rulesConfirmed && !converted.statementConfirmed
                && !converted.completeEligibilityConfirmed)
        #expect(!converted.segments[0].eligibilityConfirmed)
        converted.rulesConfirmed = true
        converted.statementConfirmed = true
        converted.completeEligibilityConfirmed = true
        converted.segments[0].eligibilityConfirmed = true
        #expect(try converted.calculate() == before)
        #expect(draft.decimalSeparator == "." && draft.statementAmount == "310.63000001")
    }

    @Test func partialNumberConversionNeverGuessesOrErasesTheOriginalInput() throws {
        let model = AppModel(store: UnitStateStore())
        try UnitFixture.populate(model)
        var draft = filled(model)
        draft.segments[0].rate = "8."
        let before = draft
        #expect(throws: (any Error).self) { try draft.convertingNumbers(to: ",") }
        #expect(draft == before && draft.segments[0].rate == "8.")
    }

    private func filled(_ model: AppModel) -> BenefitAuditDraft {
        var draft = model.makeBenefitDraft()
        draft.fundName = "Synthetic fund"
        draft.decimalSeparator = "."
        draft.segments[0].rate = "8.75"
        draft.segments[0].quantity = "40"
        draft.segments[0].eligibilityConfirmed = true
        draft.rulesConfirmed = true
        draft.completeEligibilityConfirmed = true
        return draft
    }
}
