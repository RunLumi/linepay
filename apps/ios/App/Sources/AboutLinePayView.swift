import SwiftUI

struct AboutLinePayView: View {
    var body: some View {
        List {
            Section("LinePaycheck") {
                Text("Check every paycheck.").font(.title2.bold())
                LabeledContent(
                    "Version",
                    value:
                        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))"
                )
                Text(
                    "Estimates expected pay from confirmed work and rules, then compares the paycheck facts you review. It is not payroll, legal advice, or an authority on your agreement."
                )
            }
            Section {
                NavigationLink("Privacy policy") { LegalTextView(kind: .privacy) }
                NavigationLink("Terms of use") { LegalTextView(kind: .terms) }
                NavigationLink("Acknowledgements") { LegalTextView(kind: .acknowledgements) }
                NavigationLink("Support and data recovery") { LegalTextView(kind: .support) }
            }
        }.navigationTitle("About LinePaycheck").navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalTextView: View {
    enum Kind { case privacy, terms, acknowledgements, support }
    let kind: Kind
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title).font(.title2.bold())
                Text(content).textSelection(.enabled)
                if kind == .terms,
                    let url = URL(
                        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                {
                    Link(
                        "Apple Standard Licensed Application End User License Agreement",
                        destination: url
                    ).frame(minHeight: 44)
                }
                if kind == .privacy {
                    Link("Open published privacy policy", destination: AppLinks.privacy).frame(
                        minHeight: 44)
                }
                if kind == .support {
                    Link("Open support website", destination: AppLinks.support).frame(minHeight: 44)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private var title: String {
        switch kind {
        case .privacy: "Privacy policy"
        case .terms: "Terms of use"
        case .acknowledgements: "Acknowledgements"
        case .support: "Support and recovery"
        }
    }
    private var content: String {
        switch kind {
        case .privacy:
            "LinePaycheck processes your work records, pay rules, original paystubs, OCR suggestions and confirmed audit facts on your device. It does not create a LinePaycheck account or transmit these records to a LinePaycheck server. No advertising or behavioral analytics SDK is included.\n\nPurchases are processed by Apple. The app reads verified App Store entitlement information to unlock future audits; subscription entitlements are not part of data backups.\n\nSharing and backups are your choice. Saving to iCloud Drive or another Files provider transfers the selected file to that provider. Complete backups contain sensitive pay information and are not password-encrypted by LinePaycheck. Use a private destination. iOS device backups follow your Apple and device settings.\n\nYou can remove originals while keeping confirmed figures, export records, or delete local data. Local deletion does not delete copies you previously exported and does not cancel an App Store subscription.\n\nSource websites open only when you choose their links. Those sites have their own privacy practices. Do not send an unredacted paystub to support unless you deliberately choose to share it."
        case .terms:
            "The app uses Apple's Standard Licensed Application End User License Agreement.\n\nLinePaycheck's estimates depend on the work, agreement rules, paystub layout and values you confirm. Missing or unsupported rules and ambiguous statements can limit an audit. Review the evidence and discuss discrepancies with payroll or an appropriate adviser. A comparison is not a legal determination that money is owed.\n\nThe first comparable audit is free. Pro covers future paychecks; existing work, confirmed audits and worker-owned data remain accessible without an active subscription. Billing periods and localized prices are shown from the App Store. Subscriptions renew until cancelled through Apple subscription settings. Deleting the app or its local data does not cancel a subscription."
        case .acknowledgements:
            "Built with Swift, SwiftUI and Apple platform frameworks. The payroll domain is maintained as a separate local Swift package. No third-party tracking or advertising framework is included.\n\nXcodeGen and testing tools are development dependencies, not runtime services. Apple and framework names belong to their respective owners. LinePaycheck is not affiliated with, endorsed by or an authority for a union, employer or payroll provider."
        case .support:
            "Keep your saved data until a problem is understood. From Settings, create a complete backup when the app can read your records. If data cannot be opened, export the recovery file before choosing a destructive reset or replacement restore.\n\nFor an incorrect amount, note the app version, pay-period timezone, rule version, work facts and exact comparison. Use synthetic or redacted examples when contacting support. Never include Social Security numbers, bank details or employer credentials.\n\nOpen the support website below for the publisher's current contact and recovery guidance."
        }
    }
}
