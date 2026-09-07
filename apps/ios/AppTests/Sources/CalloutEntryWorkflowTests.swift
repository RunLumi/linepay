import Foundation
import LinePayDomain
import SwiftUI
import Testing
import ViewInspector

@testable import LinePay

@Suite("Callout event logging")
@MainActor
struct CalloutEntryWorkflowTests {
    @Test func adjacentNewCalloutRequiresAnExplicitEventDecision() throws {
        let model = try calloutModel()
        let start = UnitFixture.start + 8 * 3_600
        try model.addWork(
            start: start,
            end: start + 3_600,
            kind: .callout,
            note: "First physical call")

        try saveAdjacentDraft(model: model, start: start + 3_600)
        let view = AddWorkView(model: model)
        let content = try text(view)
        #expect(content.contains("touches an existing callout"))
        #expect(content.contains("This is a separate callout"))
        #expect(
            try view.inspect().find(viewWithAccessibilityIdentifier: "work.save").button()
                .isDisabled())
    }

    @Test func continueExistingCalloutExtendsOneEventInsteadOfCreatingAnotherMinimum() throws {
        let model = try calloutModel()
        let start = UnitFixture.start + 8 * 3_600
        try model.addWork(
            start: start,
            end: start + 3_600,
            kind: .callout,
            note: "First segment")
        try saveAdjacentDraft(model: model, start: start + 3_600)

        let view = AddWorkView(model: model)
        try view.inspect().find(viewWithAccessibilityIdentifier: "work.callout-continue").button().tap()

        #expect(model.workEntries.count == 1)
        let merged = try #require(model.workEntries.first)
        #expect(merged.interval.durationHours == 2)
        #expect(merged.note.contains("First segment") && merged.note.contains("Possible continuation"))
        let calculation = try #require(model.calculation)
        #expect(calculation.total.amount == 200)
        #expect(calculation.components.filter { $0.category == .calloutGuarantee }.count == 1)
    }

    @Test func mergingTwoAdjacentSavedRowsRestoresOnePhysicalCalloutMinimum() throws {
        let model = try calloutModel()
        let start = UnitFixture.start + 8 * 3_600
        try model.addWork(
            start: start,
            end: start + 3_600,
            kind: .callout,
            note: "Storm ticket A")
        try model.addWork(
            start: start + 3_600,
            end: start + 2 * 3_600,
            kind: .callout,
            note: "Storm ticket B")

        #expect(model.workEntries.count == 2)
        let beforeIDs = Set(model.workEntries.compactMap(\.interval.calloutEventID))
        #expect(beforeIDs.count == 2)
        #expect(try #require(model.calculation).total.amount == 400)

        let first = try #require(model.workEntries.first)
        let edit = AddWorkView(model: model, existingEntry: first)
        #expect(try text(edit).contains("Merge adjacent callout"))
        try edit.inspect().find(viewWithAccessibilityIdentifier: "work.callout-merge").button().tap()

        #expect(model.workEntries.count == 1)
        let merged = try #require(model.workEntries.first)
        #expect(merged.interval.durationHours == 2)
        #expect(merged.note.contains("Storm ticket A") && merged.note.contains("Storm ticket B"))
        let calculation = try #require(model.calculation)
        #expect(calculation.total.amount == 200)
        #expect(calculation.components.filter { $0.category == .calloutGuarantee }.count == 1)
    }

    @Test func mergePlanPreservesBreakFactsAcrossMidnight() throws {
        let start = UnitFixture.start + 22 * 3_600
        let firstBreak = try WorkBreak(
            startEpochSeconds: seconds(start + 30 * 60),
            endEpochSeconds: seconds(start + 45 * 60))
        let first = WorkEntry(
            interval: try WorkInterval(
                startEpochSeconds: seconds(start),
                endEpochSeconds: seconds(start + 2 * 3_600),
                timeZoneIdentifier: "UTC",
                kind: .callout,
                calloutEventID: UUID(),
                unpaidBreaks: [firstBreak]),
            note: "Before midnight")
        let secondBreak = try WorkBreak(
            startEpochSeconds: seconds(start + 2.5 * 3_600),
            endEpochSeconds: seconds(start + 2.75 * 3_600))
        let second = WorkEntry(
            interval: try WorkInterval(
                startEpochSeconds: seconds(start + 2 * 3_600),
                endEpochSeconds: seconds(start + 4 * 3_600),
                timeZoneIdentifier: "UTC",
                kind: .callout,
                calloutEventID: UUID(),
                unpaidBreaks: [secondBreak]),
            note: "After midnight")

        let plan = try CalloutEntryWorkflow.merge(first, second)
        #expect(plan.start == start)
        #expect(plan.end == start + 4 * 3_600)
        #expect(plan.breaks == [firstBreak, secondBreak])
        #expect(plan.note.contains("Before midnight") && plan.note.contains("After midnight"))
    }

    @Test func legacyCalloutRowMustBeReviewedBeforeEditingCanSave() throws {
        let model = try calloutModel()
        let start = UnitFixture.start + 8 * 3_600
        let legacy = WorkEntry(
            interval: try WorkInterval(
                startEpochSeconds: seconds(start),
                endEpochSeconds: seconds(start + 3_600),
                timeZoneIdentifier: "UTC",
                kind: .callout,
                calloutEventID: nil),
            note: "Legacy callout")

        let view = AddWorkView(model: model, existingEntry: legacy)
        let content = try text(view)
        #expect(content.contains("no confirmed event identity"))
        #expect(content.contains("Confirm this row is one callout event"))
        #expect(
            try view.inspect().find(viewWithAccessibilityIdentifier: "work.save").button()
                .isDisabled())
    }

    private func saveAdjacentDraft(model: AppModel, start: Date) throws {
        let draft = WorkDraft(
            periodID: try #require(model.activePeriod).id,
            editingEntryID: nil,
            start: start,
            end: start + 3_600,
            kind: .callout,
            note: "Possible continuation",
            hasUnpaidBreak: false,
            breakStart: start + 900,
            breakEnd: start + 1_800,
            copiedFrom: nil)
        try model.saveWorkDraft(draft)
    }

    private func calloutModel() throws -> AppModel {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.useCalloutMinimum = true
        profile.calloutMinimumHours = "4"
        try model.saveProfile(profile)
        return model
    }

    private func text<V: View>(_ view: V) throws -> String {
        try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }.joined(
            separator: "\n")
    }

    private func seconds(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }
}
