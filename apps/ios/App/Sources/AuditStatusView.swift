import SwiftUI

struct AuditStatusView: View {
    let status: AuditDisplayStatus
    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
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
