import SwiftUI

struct AuditStatusView: View {
    let status: AuditDisplayStatus

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(color)
            .accessibilityLabel(status.title)
    }

    private var color: Color {
        switch status {
        case .notAudited:
            LinePayColor.textSecondary
        case .matches:
            LinePayColor.match
        case .possibleShortfall:
            LinePayColor.difference
        case .possibleOverpayment:
            LinePayColor.information
        case .needsReview:
            LinePayColor.review
        }
    }
}
