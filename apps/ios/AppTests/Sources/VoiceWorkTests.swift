import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Voice readings require explicit work facts", .serialized)
struct VoiceWorkTests {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func spokenClockWordsProduceAnEditableProposalOnly() throws {
        let proposal = try VoiceWorkProposal.parse(
            "Regular from seven AM to three thirty PM. Unpaid break from noon to twelve thirty PM.",
            day: date("2026-10-16T16:00:00Z"), timeZoneIdentifier: "America/Chicago")
        #expect(proposal.start == date("2026-10-16T12:00:00Z"))
        #expect(proposal.end == date("2026-10-16T20:30:00Z"))
        #expect(
            proposal.breaks == [
                VoiceWorkBreak(
                    start: date("2026-10-16T17:00:00Z"), end: date("2026-10-16T17:30:00Z"))
            ])
        #expect(proposal.kind == .regular)
    }

    @Test func overnightAndEachBreakDayAreExplicit() throws {
        let proposal = try VoiceWorkProposal.parse(
            "Callout from 7 PM to 7 AM next day; unpaid break from midnight next day to 00:30 next day",
            day: date("2026-10-16T16:00:00Z"), timeZoneIdentifier: "America/Chicago")
        #expect(proposal.start == date("2026-10-17T00:00:00Z"))
        #expect(proposal.end == date("2026-10-17T12:00:00Z"))
        #expect(proposal.breaks.first?.start == date("2026-10-17T05:00:00Z"))
        #expect(proposal.kind == .callout)
    }

    @Test func omissionNegationExtraInstructionsAndAmbiguousClocksNeverBecomeWork() {
        for text in [
            "Regular from 7 AM to 3 PM", "Regular from 7 to 3; no unpaid breaks",
            "Regular from 7 AM to 3 PM; no unpaid breaks; not actually worked",
            "Not regular from 7 AM to 3 PM; no unpaid breaks",
            "Regular from 7 PM to 7 AM; no unpaid breaks",
            "Regular from 7 AM to 3 PM; paid break from noon to 12:30 PM",
            "Regular from 7 AM to 3 PM; unpaid break from noon to 12:30 PM; no unpaid breaks",
            "Regular from 7 AM to 3 PM; unpaid break from 2 PM to 4 PM",
            "Regular from 7 AM to 3 PM; unpaid break from noon to 1 PM; unpaid break from 12:30 PM to 1:30 PM",
            "Regular from 13 PM to 15 PM; no unpaid breaks",
        ] {
            #expect(throws: (any Error).self) {
                try VoiceWorkProposal.parse(
                    text, day: date("2026-10-16T16:00:00Z"),
                    timeZoneIdentifier: "America/Chicago")
            }
        }
    }

    @Test func daylightSavingGapsAndFoldsRequireManualReview() throws {
        for (day, text) in [
            ("2026-03-08T12:00:00Z", "Regular from 2:30 AM to 4 AM; no unpaid breaks"),
            ("2026-11-01T12:00:00Z", "Regular from 1:30 AM to 4 AM; no unpaid breaks"),
        ] {
            #expect(throws: VoiceWorkError.daylightSavingClock) {
                try VoiceWorkProposal.parse(
                    text, day: date(day), timeZoneIdentifier: "America/Chicago")
            }
        }
        let normal = try VoiceWorkProposal.parse(
            "Other from 01:30 to 04:00; no unpaid breaks",
            day: date("2026-11-02T12:00:00Z"), timeZoneIdentifier: "America/Chicago")
        #expect(normal.end.timeIntervalSince(normal.start) == 9_000)
    }

    @Test @MainActor func applyingProposalPreservesNotesAndNeverSavesUntilExplicitEditorAction()
        throws
    {
        let model = AppModel(store: UnitStateStore())
        try model.saveProfile(UnitFixture.profile())
        let period = try #require(model.activePeriod)
        let original = WorkDraft(
            periodID: period.id, editingEntryID: nil,
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(8 * 3_600),
            kind: .regular, note: "SYNTHETIC ticket retained", hasUnpaidBreak: false,
            breakStart: UnitFixture.start, breakEnd: UnitFixture.start, copiedFrom: nil)
        let proposal = try VoiceWorkProposal.parse(
            "Regular from 07:00 to 15:30; unpaid break from 12:00 to 12:30",
            day: UnitFixture.start, timeZoneIdentifier: model.currentTimeZoneIdentifier)
        let edited = proposal.applying(to: original)
        #expect(edited.note == original.note && edited.periodID == original.periodID)
        #expect(model.workEntries.isEmpty && model.workDraft == nil)
        try model.saveWorkDraft(edited)
        #expect(model.workEntries.isEmpty && model.workDraft == edited)
        try model.addWork(
            start: edited.start, end: edited.end, kind: edited.kind,
            note: edited.note, unpaidBreakStart: edited.breakStart, unpaidBreakEnd: edited.breakEnd)
        #expect(model.workEntries.count == 1)
        #expect(model.calculation?.expectedWages.amount == 400)
    }
    @Test @MainActor func actualSpeechRequestRequiresOnDeviceRecognitionWithoutPartialFacts() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SYNTHETIC.caf")
        let request = LocalVoiceCapture.request(url: url)
        #expect(request.requiresOnDeviceRecognition)
        #expect(!request.shouldReportPartialResults)
        let capture = LocalVoiceCapture()
        #expect(capture.phase == .idle && capture.text.isEmpty && !capture.busy)
        capture.cancel()
        #expect(capture.phase == .idle)
    }

    @Test func temporaryAudioCleanupIsScopedAndLeavesUnrelatedFilesAlone() throws {
        let url = try LocalVoiceAudioFiles.newURL()
        defer { try? LocalVoiceAudioFiles.remove(url) }
        try Data("SYNTHETIC AUDIO BYTES".utf8).write(to: url)
        let unrelated = LocalVoiceAudioFiles.directory.appendingPathComponent("unrelated.txt")
        defer { try? FileManager.default.removeItem(at: unrelated) }
        let bytes = Data("SYNTHETIC UNRELATED FILE".utf8)
        try bytes.write(to: unrelated)
        #expect(throws: (any Error).self) { try LocalVoiceAudioFiles.remove(unrelated) }
        try LocalVoiceAudioFiles.removeAll()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: unrelated) == bytes)
    }

}
