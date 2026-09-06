import Foundation
import SwiftUI

/// Product scope, not a waiver of statutory rights. Reused in consent, audits and reports.
enum ComparisonScopeDisclosure {
    static var title: String { String(localized: "Not a complete wage-law check") }
    static var summary: String {
        String(
            localized:
                "A match covers only the supported rules and confirmed values compared here. It does not certify every statutory or contractual entitlement."
        )
    }
    static var supported: String {
        String(
            localized:
                "Supported when configured: base rate, daily overtime tiers, schedule and date premiums, callout minimums, and flat per diem."
        )
    }
    static var unsupported: String {
        String(
            localized:
                "Not automatically checked: statutory weekly overtime, regular-rate adjustments, exemptions, every state's rules, or all travel, rest, meal and storm provisions. Configured daily tiers do not replace weekly statutory analysis."
        )
    }
    static var combination: String {
        String(
            localized:
                "Overlapping premiums use the highest applicable multiplier, not added multipliers. Callout top-ups use the highest worked multiplier. Confirm this matches your agreement; it is not a universal interpretation."
        )
    }
    static var deadlines: String {
        String(
            localized:
                "Using LinePaycheck does not extend a filing or grievance deadline. Ask an appropriate adviser or official agency about unresolved legal questions."
        )
    }
    static var safeUse: String {
        String(
            localized:
                "Use LinePaycheck away from active electrical work and driving. It is not safety equipment or certified for electrical-glove use."
        )
    }
}

struct ComparisonScopeView: View {
    var showDetails = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ComparisonScopeDisclosure.title).font(.headline)
            Text(ComparisonScopeDisclosure.summary).font(.callout)
            if showDetails {
                details
            } else {
                DisclosureGroup("Supported rules and limitations") { details }
            }
        }
        .accessibilityIdentifier("legal.comparison-scope")
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ComparisonScopeDisclosure.supported)
            Text(ComparisonScopeDisclosure.unsupported)
            Text(ComparisonScopeDisclosure.combination)
        }.font(.footnote).foregroundStyle(LinePayColor.textSecondary)
    }
}

/// Presentation only. AppModel owns effective-date validation and calculation semantics.
enum RuleChangeConsent {
    static func explanation(
        scope: RuleEditScope, effectiveDate: Date, timeZoneIdentifier: String, workCount: Int
    ) -> String {
        switch scope {
        case .futurePeriods:
            return String(
                localized:
                    "Logged work keeps its current rules. The new snapshot is used when the next work period starts."
            )
        case .datedChange:
            guard let zone = TimeZone(identifier: timeZoneIdentifier) else {
                return String(
                    localized:
                        "The payroll timezone needs review before this dated change can be confirmed."
                )
            }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateStyle = .long
            formatter.timeZone = zone
            let date = formatter.string(from: effectiveDate)
            return String(
                localized:
                    "New rules start \(date) at midnight (\(timeZoneIdentifier)). Previously recorded work keeps its original rules. The start must be after the last recorded work date. A callout guarantee crossing this date needs review; LinePaycheck will not guess."
            )
        case .currentPeriod:
            return String(
                localized:
                    "Saved work entries to recalculate: \(workCount). These corrected rules apply to all work in the current open period. Review the before and after amounts before confirming. Earlier audit revisions remain available."
            )
        }
    }
}
