#if DEBUG
    import Foundation
    import LinePayDomain
    import UIKit

    /// Available only in Debug and only with an explicit UI-test launch argument. Test cleanup never
    /// addresses the production state directory. Every record is synthetic and locally generated.
    @MainActor
    enum UITestFixtures {
        /// `LINEPAY_UI_STORE=trial` renders the offer with synthetic U.S. prices and an eligible
        /// seven-day annual trial. Nothing can be bought and Pro is never granted.
        static func subscriptionStore() -> SubscriptionStore? {
            switch ProcessInfo.processInfo.environment["LINEPAY_UI_STORE"] {
            case "trial": .fixture(plans: samplePlans(trial: true))
            case "no-trial": .fixture(plans: samplePlans(trial: false))
            default: nil
            }
        }

        static func samplePlans(trial: Bool) -> [ProPlan] {
            [
                ProPlan(
                    id: SubscriptionStore.yearlyProductID, period: .year,
                    price: Decimal(sign: .plus, exponent: -2, significand: 7_999),
                    currencyCode: "USD", displayPrice: "$79.99",
                    monthlyEquivalent: "$6.67", freeTrial: trial ? .days(7) : nil),
                ProPlan(
                    id: SubscriptionStore.monthlyProductID, period: .month,
                    price: Decimal(sign: .plus, exponent: -2, significand: 999),
                    currencyCode: "USD", displayPrice: "$9.99",
                    monthlyEquivalent: nil, freeTrial: nil),
            ]
        }

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
                if scenario.hasPrefix("store-week") {
                    try seedStoreWeek(model, scenario: scenario)
                    return session
                }
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
                if scenario == "profile" { return session }
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

        /// The App Store sample paycheck `store-week-2026-08-v1` from
        /// docs/design/app-stores/screenshots.md §4: $58.00/h, 2× after 8 paid hours in a work date,
        /// 46 hours (40 regular, 6 double time) expecting $3,016.00, against a synthetic paystub of
        /// 40 + 5 hours and $2,900.00 gross. `store-week` stops before the paycheck,
        /// `store-week-checked` confirms it, and `store-week-archived` also closes the period.
        private static func seedStoreWeek(_ model: AppModel, scenario: String) throws {
            var profile = PayProfileDraft()
            profile.hourlyRate = "58"
            profile.currencyCode = "USD"
            profile.timeZoneIdentifier = "America/Chicago"
            profile.preferredCadence = .weekly
            profile.useDailyOvertime = true
            profile.overtimeAfterHours = "8"
            profile.overtimeMultiplier = "2"
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Chicago")!
            let day = { (date: Int, hour: Int) in
                calendar.date(from: DateComponents(year: 2026, month: 8, day: date, hour: hour))!
            }
            profile.periodStartDate = day(24, 0)
            try model.saveProfile(profile)
            for (date, start, end) in [
                (24, 7, 15), (25, 7, 15), (26, 7, 15), (27, 6, 20), (28, 7, 15),
            ] {
                try model.addWork(
                    start: day(date, start), end: day(date, end), kind: .regular, note: "")
            }
            try model.completeFirstResult()
            guard scenario != "store-week" else { return }
            guard let id = model.activePeriod?.id else {
                throw AppModelError.missingActivePayPeriod
            }
            var stub = try model.paycheckDraft(for: id)
            stub.grossPay = "2900"
            stub.regularHours = "40"
            stub.regularPay = "2320"
            stub.doubleTimeHours = "5"
            stub.doubleTimePay = "580"
            stub.workComplete = true
            stub.earningsLinesComplete = true
            stub.grossBasis = .wagesOnly
            stub.lineLayout = .fullRateBuckets
            stub.hoursBasis = .actualWork
            stub.reviewedFields = [
                .periodStart, .periodEnd, .grossPay, .regularHours, .regularPay, .doubleTimeHours,
                .doubleTimePay,
            ]
            try model.confirmPaystub(stub)
            if scenario == "store-week-archived" { try model.archiveCurrentPeriod() }
        }
    }
#endif
