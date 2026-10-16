import Foundation
import LinePayDomain

extension LocalActivityLedger {
    /// Called only after the financial state has been validated and durably committed.
    /// No financial values cross this boundary, and diagnostic failure never rolls pay data back.
    func observeCommittedChange(from old: AppPersistentState, to new: AppPersistentState) {
        if old.setupDraft == nil, new.setupDraft != nil { record(.profileStarted, once: .once) }
        if old.profile != new.profile, new.profile != nil, new.setupDraft == nil {
            record(.profileReady, once: .once)
        }
        let oldWork = Set(
            (old.activePeriod?.workEntries ?? []).map(\.id)
                + old.history.flatMap { $0.workEntries.map(\.id) })
        let newWork = Set(
            (new.activePeriod?.workEntries ?? []).map(\.id)
                + new.history.flatMap { $0.workEntries.map(\.id) })
        for id in newWork.subtracting(oldWork) { record(.workLogged, once: .work(id)) }
        if old.paystubDraft == nil, let draft = new.paystubDraft, let period = draft.targetPeriodID
        {
            record(.paycheckIntakeStarted, once: .period(period))
        }
        let oldImported = importedPeriods(old)
        for id in importedPeriods(new).subtracting(oldImported) {
            record(.paycheckImported, once: .period(id))
        }
        for id in comparablePeriods(new).subtracting(comparablePeriods(old)) {
            record(.auditCompleted, once: .period(id))
        }
        if count(.auditCompleted) >= 2 { record(.secondAudit, once: .once) }
    }

    private func importedPeriods(_ state: AppPersistentState) -> Set<UUID> {
        var ids = Set(state.history.filter { $0.paystub != nil }.map(\.id))
        if let active = state.activePeriod, active.paystub != nil { ids.insert(active.id) }
        if let draft = state.paystubDraft, draft.sourceEvidence != nil,
            let id = draft.targetPeriodID
        {
            ids.insert(id)
        }
        return ids
    }

    private func comparablePeriods(_ state: AppPersistentState) -> Set<UUID> {
        let pairs =
            state.history.map { ($0.id, $0.paystub) }
            + [state.activePeriod.map { ($0.id, $0.paystub) }].compactMap { $0 }
        return Set(
            pairs.compactMap { id, stub in
                guard let stub, stub.confirmation?.workComplete == true,
                    let result = stub.assessment,
                    result.verdict != .notComparable, result.expectedGross != nil,
                    result.difference != nil
                else { return nil }
                return id
            })
    }
}

extension AppModel {
    /// A visible safe expected-pay row, not merely a background calculation or restored record.
    func observedExpectedPay(periodID: UUID? = nil) {
        guard let context = periodContext(id: periodID), !context.workEntries.isEmpty,
            context.calculation != nil
        else { return }
        localActivity.record(.expectedPaySeen, once: .period(context.id))
    }
}
