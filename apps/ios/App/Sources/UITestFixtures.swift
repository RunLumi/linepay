#if DEBUG
    import Foundation
    import LinePayDomain
    import UIKit

    /// Available only in Debug and only with an explicit UI-test launch argument. Test cleanup never
    /// addresses the production state directory. Every record is synthetic and locally generated.
    @MainActor
    enum UITestFixtures {
        static func session() -> AppSession {
            let base = FileManager.default.temporaryDirectory.appendingPathComponent(
                "LinePayUITest", isDirectory: true)
            let reset = ProcessInfo.processInfo.arguments.contains("--reset-ui-state")
            if reset { try? FileManager.default.removeItem(at: base) }
            let store = VersionedLocalStateStore(baseDirectory: base)
            let session = AppSession(
                store: store,
                evidenceStore: LocalEvidenceStore(
                    baseDirectory: base.appendingPathComponent("originals")))
            guard reset, let scenario = ProcessInfo.processInfo.environment["LINEPAY_UI_SCENARIO"],
                scenario != "empty"
            else { return session }
            do {
                if scenario == "corrupt" {
                    try FileManager.default.createDirectory(
                        at: base, withIntermediateDirectories: true)
                    try Data("synthetic corrupt state".utf8).write(
                        to: base.appendingPathComponent("state-v1.json"))
                    return AppSession(
                        store: store,
                        evidenceStore: LocalEvidenceStore(
                            baseDirectory: base.appendingPathComponent("originals")))
                }
                let model = session.model
                var profile = PayProfileDraft()
                profile.name = "SAMPLE - synthetic work"
                profile.hourlyRate = "50"
                profile.timeZoneIdentifier = "America/Chicago"
                profile.useDailyOvertime = true
                profile.overtimeAfterHours = "8"
                profile.overtimeMultiplier = "1.5"
                profile.useCalloutMinimum = true
                profile.calloutMinimumHours = "4"
                if scenario == "unsupported" {
                    profile.unsupportedRuleNotes = "SAMPLE rest-period premium not configured"
                }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: profile.timeZoneIdentifier) ?? .current
                profile.periodStartDate = calendar.startOfDay(for: Date())
                try model.saveProfile(profile)
                if scenario == "unresolved" {
                    let boundary = profile.periodStartDate.addingTimeInterval(86_400)
                    var changed = profile
                    changed.hourlyRate = "60"
                    changed.changeEffectiveDate = boundary
                    try model.saveProfile(changed)
                    try model.addWork(
                        start: boundary.addingTimeInterval(-3_600),
                        end: boundary.addingTimeInterval(3_600),
                        kind: .callout, note: "Synthetic unresolved spanning callout")
                    try model.completeFirstResult()
                    return session
                }
                let start = profile.periodStartDate.addingTimeInterval(7 * 3600)
                try model.addWork(
                    start: start, end: start.addingTimeInterval(10 * 3600), kind: .regular,
                    note: "Synthetic test shift")
                try model.completeFirstResult()
                if scenario == "work" || scenario == "unsupported" { return session }
                guard let id = model.activePeriod?.id else {
                    throw AppModelError.missingActivePayPeriod
                }
                if scenario == "intake" {
                    let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
                    let bytes = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                        context.beginPage()
                        ("SYNTHETIC PAYSTUB\nGross pay $550.00" as NSString).draw(
                            at: CGPoint(x: 48, y: 100),
                            withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
                    }
                    var draft = try model.stagePaystub(
                        data: bytes, filename: "synthetic-intake.pdf",
                        mediaType: "application/pdf", kind: .file, periodID: id)
                    draft.grossPay = "550"
                    draft.notes = "Synthetic staged source; no OCR confirmation is assumed."
                    try model.savePaystubDraft(draft)
                    return session
                }
                if scenario == "awaiting" {
                    try model.archiveCurrentPeriod()
                    return session
                }
                var stub = try model.paycheckDraft(for: id)
                stub.grossPay =
                    scenario == "shortfall" ? "500" : scenario == "overpayment" ? "600" : "550"
                stub.workComplete = true
                stub.grossBasis = scenario == "not-comparable" ? .unconfirmed : .wagesOnly
                stub.reviewedFields = [.periodStart, .periodEnd, .grossPay]
                if scenario == "review" {
                    stub.regularPay = "350"
                    stub.overtimePay = "200"
                    stub.lineLayout = .fullRateBuckets
                    stub.reviewedFields.formUnion([.regularPay, .overtimePay])
                }
                try model.confirmPaystub(stub)
            } catch {
                // Failing fixtures must fail a UI test visibly, never silently produce success data.
                session.restoreNotice = "Synthetic UI fixture failed: \(error.localizedDescription)"
            }
            return session
        }
    }
#endif
