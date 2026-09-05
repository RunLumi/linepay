import SwiftUI

struct AuditStatusView: View {
    let status: AuditDisplayStatus

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel(status.title)
    }

    private var color: Color {
        switch status {
        case .notAudited:
            .secondary
        case .matches:
            .green
        case .possibleShortfall:
            .red
        case .possibleOverpayment:
            .blue
        case .needsReview:
            .orange
        }
    }
}
