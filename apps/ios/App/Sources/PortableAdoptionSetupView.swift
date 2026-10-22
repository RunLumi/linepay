import Foundation
import LinePayDomain
import SwiftUI

struct PortableAdoptionSetupView: View {
    let model: AppModel
    let document: PortableState
    let onSaved: () -> Void
    var body: some View {
        if let (profile, snapshot) = PortableAdoptionScope.currentSource(document) {
            PayProfileSetupView(
                model: model, showsIntro: false, onSaved: onSaved,
                initialDraft: model.setupDraft
                    ?? PortableAdoptionDraft.make(
                        document: document, profile: profile, snapshot: snapshot),
                portableSource: snapshot,
                portableInheritedScope: PortableAdoptionScope.note(
                    document: document, snapshot: snapshot),
                onPortableReviewed: { draft, confirmations, makeDefault in
                    try model.adoptPortableWork(
                        draft, sourceSnapshotID: snapshot.id, confirmedFields: confirmations,
                        makeDefaultForFuture: makeDefault)
                })
        } else {
            Text(
                "This transfer has no current work snapshot to adopt. Its frozen evidence remains available."
            )
        }
    }
}

/// Prefill only source-recorded context; missing global pointers do not replace a selected period.
enum PortableAdoptionDraft {
    static func make(
        document: PortableState, profile: PortableProfile, snapshot: PortableWorkSnapshot
    ) -> PayProfileDraft {
        let period =
            document.periods.first(where: { $0.id == snapshot.periodRef })
            ?? document.periods.first(where: { $0.id == profile.currentPeriodRef })
        var draft = PayProfileDraft()
        draft.name = profile.name ?? "New confirmed pay rules"
        draft.timeZoneIdentifier = period?.calendarWindow.timeZone ?? profile.timeZone ?? "UTC"
        if let cadence = (period?.cadence ?? profile.cadence).flatMap(
            PayPeriodCadence.init(rawValue:))
        {
            draft.preferredCadence = cadence
        }
        if let rule = document.ruleSnapshots.first(where: { $0.id == profile.ruleRef }) {
            draft.hourlyRate = rule.hourlyRate
            draft.currencyCode = rule.currency
            if let first = rule.dailyOvertimeTiers?.first {
                draft.useDailyOvertime = true
                draft.overtimeAfterHours = first.afterHours
                draft.overtimeMultiplier = first.multiplier
            }
            draft.outsideScheduleMultiplier = rule.outsideScheduleMultiplier ?? "1"
            if let rounding = rule.rounding,
                let mode = MoneyRoundingMode(
                    rawValue: rounding.mode == "halfEven" ? "bankers" : rounding.mode),
                let scope = PayRoundingScope(rawValue: rounding.scope)
            {
                draft.roundingRule = MoneyRoundingRule(
                    scale: Int(rounding.scale), mode: mode, scope: scope)
            }
        }
        if let period {
            let zone =
                TimeZone(identifier: draft.timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = zone
            formatter.dateFormat = "yyyy-MM-dd"
            if let text = period.calendarWindow.startDate, let start = formatter.date(from: text) {
                draft.periodStartDate = start
            }
            if let text = period.calendarWindow.endDateInclusive,
                let end = formatter.date(from: text)
            {
                draft.manualPeriodEndDate = end
            }
        }
        if let (_, snapshot) = PortableAdoptionScope.currentSource(document) {
            draft.unsupportedRuleNotes = PortableAdoptionScope.note(
                document: document, snapshot: snapshot)
        }
        // A known source value is only a proposal; final review separately confirms rounding.
        return draft
    }
}
