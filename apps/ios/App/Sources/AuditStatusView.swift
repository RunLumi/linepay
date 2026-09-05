import SwiftUI

struct AuditStatusView: View {
    let status: AuditDisplayStatus
    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .accessibilityIdentifier("audit.status")
    }
    private var color: Color {
        switch status {
        case .matches, .grossMatches: LinePayColor.match
        case .possibleShortfall, .possibleOverpayment: LinePayColor.difference
        case .needsReview, .notComparable: LinePayColor.review
        case .notAudited: LinePayColor.textSecondary
        }
    }
}
