import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Precision corrections preserve saved checks")
@MainActor
struct CalculationRevisionPolicyTests {
    @Test func affectedActiveCheckRequiresReviewAndCorrectionAppendsWithoutRepricingPriorRevision()
        throws
    {
        let store = try legacyStore(rate: "58.50", seconds: 60, recorded: "0.97")
        let saved = try #require(store.state?.activePeriod?.auditRevisions?.first)
        let model = AppModel(store: store)
        #expect(model.calculation?.expectedWages.amount == Decimal(string: "0.98"))
        let context = try #require(model.periodContext())
        #expect(context.requiresCalculationReview && model.status(for: context) == .needsReview)
        #expect(model.currentAuditStatus == .needsReview)
        #expect(
            context.revisions.first == saved
                && store.state?.activePeriod?.auditRevisions?.first == saved)
        let display = AuditAssessment.evaluate(
            calculation: context.calculation, paystub: context.paystub,
            reconciliation: context.reconciliation,
            requiresCalculationReview: context.requiresCalculationReview)
        #expect(!display.isCurrent && display.explanation.contains("precision changed"))
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "0.97"))
        let revisions = try #require(model.activePeriod?.auditRevisions)
        #expect(revisions.count == 2 && revisions.first == saved)
        #expect(revisions.last?.calculation?.provenance?.engine == "linepay.configured-pay/3")
        #expect(model.currentPaystub?.assessment?.expectedGross?.amount == Decimal(string: "0.98"))
        #expect(model.currentPaystub?.assessment?.difference?.amount == Decimal(string: "0.01"))
    }

    @Test func closingAndReloadingRetainsOldCalculationAndItsScopedResult() throws {
        let store = try legacyStore(rate: "58.50", seconds: 60, recorded: "0.97")
        let saved = try #require(store.state?.activePeriod?.auditRevisions?.first)
        let model = AppModel(store: store)
        try model.archiveCurrentPeriod()
        let archived = try #require(model.history.first)
        #expect(archived.calculation == saved.calculation)
        let reloaded = AppModel(store: store)
        let context = try #require(reloaded.periodContext(id: archived.id))
        #expect(context.isClosed && !context.requiresCalculationReview)
        #expect(context.calculation?.expectedWages.amount == Decimal(string: "0.97"))
        #expect(context.calculation?.provenance?.engine == "linepay.configured-pay/2")
        #expect(context.revisions.first == saved)
        #expect(reloaded.status(for: context) == .grossMatches)
    }

    @Test func explicitClosedReviewUsesCurrentPrecisionButKeepsTheOriginalEstimateAndAudit() throws
    {
        let store = try legacyStore(rate: "58.50", seconds: 60, recorded: "0.97")
        let model = AppModel(store: store)
        try model.archiveCurrentPeriod()
        let prior = try #require(model.history.first)
        let oldRevision = try #require(prior.auditRevisions?.first)
        var draft = UnitFixture.paystub(model, gross: "0.97")
        draft.targetPeriodID = prior.id
        draft.payPeriodStartDate = prior.window.startDate
        draft.payPeriodEndDate = prior.window.displayEndDate
        try model.confirmPaystub(draft, periodID: prior.id)
        let after = try #require(model.history.first)
        #expect(
            after.calculation == prior.calculation && after.auditRevisions?.first == oldRevision)
        #expect(after.auditRevisions?.count == 2)
        let context = try #require(model.periodContext(id: prior.id))
        #expect(context.calculation?.expectedWages.amount == Decimal(string: "0.98"))
        #expect(context.calculation?.provenance?.engine == "linepay.configured-pay/3")
        #expect(context.paystub?.assessment?.difference?.amount == Decimal(string: "0.01"))
        #expect(model.auditStatus(for: after) == .possibleShortfall)
        let bytes = try BackupArchive(
            createdAt: UnitFixture.start,
            state: #require(store.state), files: []
        ).encoded()
        let restored = try BackupArchive.decode(bytes)
        #expect(restored.state.history.first?.calculation == prior.calculation)
        #expect(restored.state.history.first?.comparisonCalculation == context.calculation)
        #expect(AppModel(store: store).history.first?.calculation == prior.calculation)
    }

    @Test func unchangedPricesKeepTheOriginalCheckAndOriginalProvenance() throws {
        let store = try legacyStore(rate: "50", seconds: 28_800, recorded: "400")
        let model = AppModel(store: store)
        let context = try #require(model.periodContext())
        #expect(!context.requiresCalculationReview && model.currentAuditStatus == .grossMatches)
        #expect(context.calculation?.provenance?.engine == "linepay.configured-pay/2")
        #expect(model.calculation?.provenance?.engine == "linepay.configured-pay/3")
        try model.confirmPaystub(UnitFixture.paystub(model))
        #expect(
            model.activePeriod?.auditRevisions?.first?.calculation?.provenance?.engine
                == "linepay.configured-pay/2")
        #expect(
            model.activePeriod?.auditRevisions?.last?.calculation?.provenance?.engine
                == "linepay.configured-pay/3")
    }

    private func legacyStore(rate: String, seconds: TimeInterval, recorded: String) throws
        -> UnitStateStore
    {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try model.saveProfile(UnitFixture.profile(rate: rate))
        try model.addWork(
            start: UnitFixture.start, end: UnitFixture.start.addingTimeInterval(seconds),
            kind: .regular)
        let gross = try #require(model.calculation?.expectedWages.amount)
        try model.confirmPaystub(
            UnitFixture.paystub(model, gross: NSDecimalNumber(decimal: gross).stringValue))
        var state = try #require(store.state)
        var active = try #require(state.activePeriod)
        let latest = try #require(active.auditRevisions?.last)
        let current = try #require(latest.calculation)
        let amount = Money(amount: try UnitFixture.decimal(recorded), currencyCode: "USD")
        let part = try #require(current.components.first)
        let priorPart = PayComponent(
            id: part.id, category: part.category, workIntervalID: part.workIntervalID,
            localDate: part.localDate, hours: part.hours, multiplier: part.multiplier,
            amount: amount,
            explanation: part.explanation, ruleKeys: part.ruleKeys, baseRate: part.baseRate,
            appliedAgreement: part.appliedAgreement,
            unroundedAmount: Money(
                amount: recorded == "0.97"
                    ? try UnitFixture.decimal("0.97499999999999999999999999999999999996")
                    : amount.amount, currencyCode: "USD"))
        let prior = CalculationResult(
            agreementID: current.agreementID, agreementVersion: current.agreementVersion,
            components: [priorPart], total: amount, agreementSnapshots: current.agreementSnapshots,
            provenance: CalculationProvenance(
                engine: "linepay.configured-pay/2",
                rounding: "explicit-snapshot-rounding/1",
                callout: "confirmed-event-isolated-minimum/1"))
        let assessment = try PaycheckAssessor().assess(
            calculation: prior, agreement: active.agreement,
            facts: PaycheckFacts(hasCompleteWork: true, grossPay: amount, grossBasis: .wagesOnly))
        let stub = ConfirmedPaystub(
            id: latest.paystub.id, payPeriodStart: latest.paystub.payPeriodStart,
            payPeriodEnd: latest.paystub.payPeriodEnd, grossPay: amount,
            confirmedEpochSeconds: latest.paystub.confirmedEpochSeconds,
            confirmation: latest.paystub.confirmation, assessment: assessment)
        let reconciliation = ReconciliationResult(
            expectedGross: amount, actualGross: amount,
            difference: .zero(currencyCode: "USD"), direction: .matches)
        active.paystub = stub
        active.reconciliation = reconciliation
        active.auditRevisions = [
            AuditRevision(
                id: latest.id, window: latest.window, agreement: latest.agreement,
                timeZoneIdentifier: latest.timeZoneIdentifier, workEntries: latest.workEntries,
                calculation: prior, paystub: stub, reconciliation: reconciliation,
                agreementChanges: latest.agreementChanges)
        ]
        state.activePeriod = active
        try store.save(state)
        return store
    }
}
