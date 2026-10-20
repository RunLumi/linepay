import SwiftUI

struct AuditStatusView: View {
    let status: AuditDisplayStatus
    var body: some View {
        HStack(alignment: .top, spacing: LinePaySpacing.compact) {
            Image(systemName: status.systemImage)
                .accessibilityHidden(true)
            Text(status.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .foregroundStyle(color)
        .accessibilityIdentifier("audit.status")
    }
    private var color: Color {
        switch status {
        case .matches, .grossMatches: LinePayColor.match
        case .possibleShortfall: LinePayColor.difference
        case .possibleOverpayment: LinePayColor.information
        case .needsReview, .notComparable: LinePayColor.review
        case .notAudited: LinePayColor.textSecondary
        }
    }
}
