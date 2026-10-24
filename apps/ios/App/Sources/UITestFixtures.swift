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
                    baseDirectory: base.appendingPathComponent("originals")),
                activity: LocalActivityLedger(
                    store: FileLocalActivityStore(
                        directory: base.appendingPathComponent("activity"))))
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
                if scenario == "premium-legacy" {
                    try seedLegacyPremium(at: base)
                    return AppSession(
                        store: store,
                        evidenceStore: LocalEvidenceStore(
                            baseDirectory: base.appendingPathComponent("originals")),
                        activity: LocalActivityLedger(
                            store: FileLocalActivityStore(
                                directory: base.appendingPathComponent("activity"))))
                }
                let model = session.model
                if scenario.hasPrefix("store-week") {
                    try seedStoreWeek(model, scenario: scenario)
                    return session
                }
                var profile = PayProfileDraft()
                profile.name = "SAMPLE - synthetic work"
                profile.hourlyRate = scenario == "precision-profile" ? "58.50" : "50"
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
                if scenario == "profile" || scenario == "precision-profile" { return session }
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
                if scenario.hasPrefix("benefits") {
                    for offset in 0..<5 {
                        let day = calendar.date(
                            byAdding: .day, value: offset, to: profile.periodStartDate)!
                        let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
                        try model.addWork(
                            start: start, end: start.addingTimeInterval(8 * 3_600),
                            kind: .regular, note: "Synthetic eight-hour benefits fixture")
                    }
                    try model.completeFirstResult()
                    if scenario.hasPrefix("benefits-review") {
                        var draft = model.makeBenefitDraft()
                        draft.fundName = "SYNTHETIC PENSION"
                        let comma = scenario.hasSuffix("comma")
                        draft.decimalSeparator = comma ? "," : "."
                        draft.segments[0].rate = comma ? "8,75" : "8.75"
                        draft.segments[0].quantity = "40"
                        draft.hasStatement = true
                        draft.statementMatchesFund = true
                        draft.statementAmount = comma ? "310,63" : "310.63"
                        draft.statementQuantity = comma ? "35,5" : "35.5"
                        try model.keepBenefitDraft(draft)
                        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
                        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                            context.beginPage()
                            ("SYNTHETIC BENEFITS STATEMENT\nEmployer contribution: USD 310.63\nEligible hours: 35.5"
                                as NSString).draw(
                                    in: CGRect(x: 48, y: 80, width: 500, height: 300),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
                        }
                        try model.retainBenefitStatement(
                            data: data, filename: "synthetic-benefits.pdf", draftID: draft.id)
                    }
                    return session
                }
                let start = profile.periodStartDate.addingTimeInterval(7 * 3600)
                try model.addWork(
                    start: start, end: start.addingTimeInterval(10 * 3600), kind: .regular,
                    note: "Synthetic test shift")
                try model.completeFirstResult()
                if scenario == "agreement" {
                    try seedAgreement(model)
                    return session
                }
                if scenario == "work" || scenario == "unsupported" { return session }
                guard let id = model.activePeriod?.id else {
                    throw AppModelError.missingActivePayPeriod
                }
                if scenario == "intake" || scenario == "ocr-confidence" {
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
                    if scenario == "ocr-confidence" {
                        let source = RecognizedPaystubLine(
                            text: "Gross pay $550.00",
                            region: SourceRegion(
                                page: 0, x: 0.07, y: 0.82, width: 0.8, height: 0.1),
                            confidence: 0.72)
                        draft.suggestions = PaystubTextParser.parse([source])
                        draft.recognizedText = source.text
                        draft.sourcePageCount = 1
                    }
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

        /// Receipts arrive only from the UI runner's synthetic golden resource, never the app bundle.
        private static func seedLegacyPremium(at base: URL) throws {
            struct Fixture: Decodable {
                struct Row: Decodable {
                    let id: String
                    let agreement: AgreementSnapshot
                    let calculation: CalculationResult
                    let assessment: PaycheckAssessment
                }
                let sourceCommit: String
                let cases: [Row]
            }
            guard let text = ProcessInfo.processInfo.environment["LINEPAY_UI_PREMIUM_LEGACY"],
                text.utf8.count <= 65_536
            else { throw LocalStateStoreError.invalidState }
            let fixture = try JSONDecoder().decode(Fixture.self, from: Data(text.utf8))
            guard fixture.sourceCommit == "3836154",
                let row = fixture.cases.first(where: { $0.id == "premium-half-cent" }),
                row.assessment.engineVersion == 4,
                let workID = row.calculation.components.first?.workIntervalID
            else { throw LocalStateStoreError.invalidState }
            let work = WorkEntry(
                interval: try WorkInterval(
                    id: workID,
                    startEpochSeconds: 1_788_739_200, endEpochSeconds: 1_788_739_260,
                    timeZoneIdentifier: "UTC"), note: "SYNTHETIC original premium-only check")
            let window = PayPeriodWindow(
                startEpochSeconds: 1_788_739_200,
                endEpochSeconds: 1_789_344_000, cadence: .weekly)
            let stub = ConfirmedPaystub(
                id: UUID(uuidString: "74000000-0000-0000-0000-000000000001")!,
                payPeriodStart: LocalDate(year: 2026, month: 9, day: 7),
                payPeriodEnd: LocalDate(year: 2026, month: 9, day: 13),
                grossPay: row.assessment.paidGross,
                regularPay: Money(amount: Decimal(string: "0.98")!, currencyCode: "USD"),
                overtimePay: Money(amount: Decimal(string: "0.48")!, currencyCode: "USD"),
                confirmedEpochSeconds: 1_788_739_261,
                confirmation: PaystubConfirmation(
                    grossBasis: .wagesOnly, lineLayout: .basePlusPremium,
                    hoursBasis: .unconfirmed, guaranteeLayout: .unconfirmed,
                    reviewedFields: [
                        .periodStart, .periodEnd, .grossPay, .regularPay, .overtimePay,
                    ],
                    suggestions: [:], hasAdditionalUnmappedPay: false, workComplete: true),
                assessment: row.assessment)
            let reconciliation = ReconciliationResult(
                expectedGross: row.calculation.expectedWages,
                actualGross: stub.grossPay, difference: .zero(currencyCode: "USD"),
                direction: .matches)
            let revision = AuditRevision(
                id: stub.id, window: window, agreement: row.agreement,
                timeZoneIdentifier: "UTC", workEntries: [work], calculation: row.calculation,
                paystub: stub, reconciliation: reconciliation)
            var state = AppPersistentState()
            state.profile = PayProfile(
                name: "SYNTHETIC legacy premium-only profile",
                timeZoneIdentifier: "UTC", agreement: row.agreement)
            state.activePeriod = ActivePayPeriod(
                id: UUID(uuidString: "75000000-0000-0000-0000-000000000001")!,
                window: window, agreement: row.agreement,
                timeZoneIdentifier: "UTC", workEntries: [work], paystub: stub,
                reconciliation: reconciliation,
                auditCompletedEpochSeconds: stub.confirmedEpochSeconds,
                hasConsumedAuditAccess: true, auditRevisions: [revision])
            state.hasUsedFreeAudit = true
            try AppStateValidation.validate(state)
            // Exercise actual old-schema reading, rather than labelling a current in-memory model old.
            state.schemaVersion = 9
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(
                to: base.appendingPathComponent("state-v1.json"), options: .atomic)
        }

        private static func seedAgreement(_ model: AppModel) throws {
            guard let next = model.activePeriod?.window.endDate,
                let zone = model.profile?.timeZoneIdentifier
            else {
                throw AppModelError.missingActivePayPeriod
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: zone)
            formatter.dateFormat = "yyyy-MM-dd"
            let lines = [
                "SYNTHETIC AGREEMENT",
                "Base hourly rate: USD 60.00 per hour",
                "Daily overtime: after 8 hours at 1.5x",
                "Effective from: \(formatter.string(from: next))",
                "Meal premium: USD 25.00 per missed meal",
            ]
            let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                context.beginPage()
                UIColor.white.setFill()
                context.fill(bounds)
                for (index, line) in lines.enumerated() {
                    (line as NSString).draw(
                        at: CGPoint(x: 36, y: 60 + index * 34),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black,
                        ])
                }
            }
            try model.retainAgreement(data: data, filename: "synthetic-agreement.pdf")
        }

        /// The App Store sample paycheck `store-week-2026-08-v1` from
        /// docs/design/app-stores/screenshots.md §4: $58.00/h, 2× after 8 paid hours in a work date,
        /// 46 hours (40 regular, 6 double time) expecting $3,016.00, against a synthetic paystub of
        /// 40 + 5 hours and $2,900.00 gross. `store-week` stops before the paycheck,
        /// `store-week-checked` confirms it, and `store-week-archived` also closes the period.
        /// `store-week-scan` stops at an unconfirmed review of a synthetic paystub read by the real
        /// on-device OCR; `store-week-sourced` confirms that same retained paystub's values.
        /// `store-week-advanced` is a separate fixture (Mon 8 h, one short callout,
        /// callout minimum and flat per diem on); its totals are never the sample paycheck's.
        private static func seedStoreWeek(_ model: AppModel, scenario: String) throws {
            let advanced = scenario == "store-week-advanced"
            var profile = PayProfileDraft()
            profile.hourlyRate = "58"
            profile.currencyCode = "USD"
            profile.timeZoneIdentifier = "America/Chicago"
            profile.preferredCadence = .weekly
            profile.useDailyOvertime = true
            profile.overtimeAfterHours = "8"
            profile.overtimeMultiplier = "2"
            if advanced {
                profile.useCalloutMinimum = true
                profile.calloutMinimumHours = "4"
                profile.usePerDiem = true
                profile.perDiemAmount = "60"
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Chicago")!
            let moment = { (date: Int, hour: Int, minute: Int) in
                calendar.date(
                    from: DateComponents(
                        year: 2026, month: 8, day: date, hour: hour, minute: minute))!
            }
            let day = { (date: Int, hour: Int) in moment(date, hour, 0) }
            profile.periodStartDate = day(24, 0)
            try model.saveProfile(profile)
            if advanced {
                try model.addWork(start: day(24, 7), end: day(24, 15), kind: .regular, note: "")
                try model.addWork(
                    start: day(25, 19), end: moment(25, 20, 30), kind: .callout, note: "")
                try model.completeFirstResult()
                return
            }
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
            if scenario == "store-week-scan" || scenario == "store-week-sourced" {
                try stageSamplePaystub(model, periodID: id)
                if scenario == "store-week-scan" { return }
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

        /// A clearly synthetic paystub for `store-week-2026-08-v1`, retained and read by the same
        /// `PaystubOCRService` as a user import. Nothing is confirmed: the draft is what the review
        /// screen shows before the user checks each value against the original.
        private static func stageSamplePaystub(_ model: AppModel, periodID: UUID) throws {
            let lines = [
                "SAMPLE PAYSTUB - ILLUSTRATIVE DATA",
                "Pay period starts 08/24/2026",
                "Pay period ends 08/30/2026",
                "Regular hours 40.00",
                "Regular pay $2,320.00",
                "Double time hours 5.00",
                "Double time pay $580.00",
                "Gross pay $2,900.00",
            ]
            let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                context.beginPage()
                UIColor.white.setFill()
                context.fill(bounds)
                for (index, line) in lines.enumerated() {
                    (line as NSString).draw(
                        at: CGPoint(x: 48, y: 72 + index * 44),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: index == 0 ? 20 : 24),
                            .foregroundColor: UIColor.black,
                        ])
                }
            }
            var draft = try model.stagePaystub(
                data: data, filename: "sample-paystub.pdf", mediaType: "application/pdf",
                kind: .file, periodID: periodID)
            let result = try recognizeBlocking(data)
            draft.suggestions = result.suggestions
            draft.recognizedText = result.recognizedText
            draft.processingNotice = result.notice
            draft.sourcePageCount = result.pageCount
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Chicago")!
            for (field, suggestion) in result.suggestions {
                guard let value = suggestion.value else { continue }
                guard field.isDate else {
                    draft[field] = value
                    continue
                }
                let parts = value.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3,
                    let date = calendar.date(
                        from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
                else { continue }
                if field == .periodStart {
                    draft.payPeriodStartDate = date
                } else {
                    draft.payPeriodEndDate = date
                }
            }
            try model.savePaystubDraft(draft)
        }

        /// Run the real OCR/parser synchronously for this synthetic startup fixture. Scheduling a
        /// MainActor task and spinning its run loop can deadlock or trigger the launch watchdog.
        private static func recognizeBlocking(_ data: Data) throws -> OCRPaystubResult {
            try PaystubOCRService.recognizeDocument(data: data, fileExtension: "pdf")
        }
    }
#endif
