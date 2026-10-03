import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Paystub suggestions never silently choose a payroll column")
struct PaystubParserTests {
    @Test(arguments: [
        ("Gross pay $1,234.56", "1234.56"), ("GROSS EARNINGS 1234.56", "1234.56"),
        ("Gross 0.00", "0"),
        ("Gross pay Current $1,234.56 YTD $12,345.67", "1234.56"),
    ])
    func unambiguousGross(_ line: String, _ expected: String) {
        let result = parse([line])
        #expect(result[.grossPay]?.value == expected)
        #expect(result[.grossPay]?.sourceText == line)
    }

    @Test(arguments: [
        "Gross pay 100.00 200.00",
        "Gross adjustment -125.00", "Gross ($125.00)", "Gross 125.00-",
        "Gross YEAR TO DATE 125.00", "Gross 1,23.00", "Gross 125.000",
        "Gross nothing", "Gross 1.234,56", "Grosspay 125.00", "Gross abc125.00",
    ])
    func uncertainOrMalformedValueIsNotSuggested(_ line: String) {
        #expect(parse([line])[.grossPay]?.value == nil)
    }

    @Test func supportedLabelsStayIndependent() {
        let lines = [
            "Gross 500.00", "Regular pay 300.00", "OT pay 100.00", "Double-time 50.00",
            "Per-diem 50.00",
        ]
        let result = parse(lines)
        #expect(result[.regularPay]?.value == "300" && result[.overtimePay]?.value == "100")
        #expect(result[.doubleTimePay]?.value == "50" && result[.perDiemPay]?.value == "50")
        #expect(result[.grossPay]?.sourceText == lines[0])
        #expect(parse(["Gross 100.00", "Gross 200.00"])[.grossPay]?.value == nil)
        #expect(parse([]).isEmpty)
        #expect(parse([])[.grossPay]?.value == nil)
    }

    private func parse(_ lines: [String]) -> [PaystubField: OCRFieldSuggestion] {
        PaystubTextParser.parse(
            lines.enumerated().map { index, text in
                RecognizedPaystubLine(
                    text: text,
                    region: SourceRegion(
                        page: 0, x: 0, y: Double(index) / 20, width: 1, height: 0.04),
                    confidence: 0.99)
            })
    }

    @Test(arguments: ["pdf", "PDF", "png", "", "heic"])
    func corruptDocumentIsRejectedBeforeRecognition(_ fileExtension: String) async {
        await #expect(throws: (any Error).self) {
            try await PaystubOCRService().recognize(
                data: Data("not an image or PDF".utf8), fileExtension: fileExtension)
        }
        #expect(PaystubOCRError.unsupportedDocument.errorDescription?.contains("manually") == true)
        #expect(PaystubOCRError.noReadablePages.errorDescription?.contains("manually") == true)
    }
}

@Suite("Presentation values and serialization")
@MainActor
struct PresentationValueTests {
    @Test func exactNumbersAndSigns() throws {
        let amount = try UnitFixture.decimal("1234.50")
        #expect(LinePayFormat.decimal(amount) == "1234.5")
        #expect(LinePayFormat.hours(8) == "8")
        // Evidence leaves the app, so a calendar date must not read as either 1 Feb or 2 Jan.
        let date = LinePayFormat.localDate(LocalDate(year: 2026, month: 1, day: 2))
        #expect(date.contains("2026") && date.contains("2") && !date.contains("/"))
        #expect(date != LinePayFormat.localDate(LocalDate(year: 2026, month: 2, day: 1)))
        #expect(LinePayFormat.timeZoneName("America/Chicago").contains("Chicago"))
        #expect(!LinePayFormat.timeZoneName("America/Los_Angeles").contains("_"))
        let positive = Money(amount: 10, currencyCode: "USD")
        #expect(LinePayFormat.signedMoney(positive) == "+" + LinePayFormat.money(positive))
        #expect(
            LinePayFormat.signedMoney(.zero(currencyCode: "USD"))
                == LinePayFormat.money(.zero(currencyCode: "USD")))
        let negative = Money(amount: -10, currencyCode: "USD")
        #expect(LinePayFormat.signedMoney(negative) == LinePayFormat.money(negative))
    }

    @Test func breaksAndTimeFormattingKeepExplicitContext() throws {
        let pause = try WorkBreak(startEpochSeconds: 600, endEpochSeconds: 2_400)
        let work = try WorkInterval(
            startEpochSeconds: 0, endEpochSeconds: 3_600, timeZoneIdentifier: "UTC",
            unpaidBreaks: [pause])
        #expect(LinePayFormat.breakDuration(work) != nil)
        let without = try WorkInterval(
            startEpochSeconds: 0, endEpochSeconds: 3_600, timeZoneIdentifier: "UTC")
        #expect(LinePayFormat.breakDuration(without) == nil)
        #expect(!LinePayFormat.workDateRange(work).isEmpty)
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        let window = try #require(model.activePeriod?.window)
        let utc = LinePayFormat.payPeriod(window, timeZoneIdentifier: "UTC")
        let west = LinePayFormat.payPeriod(window, timeZoneIdentifier: "America/Los_Angeles")
        #expect(!utc.isEmpty && utc != west)
    }

    @Test func workPreviewPricesTheDraftExactlyAsSavingWouldWithoutSaving() throws {
        let model = AppModel()
        var profile = UnitFixture.profile()
        profile.useDailyOvertime = true
        profile.overtimeAfterHours = "8"
        profile.overtimeMultiplier = "1.5"
        try model.saveProfile(profile)
        let period = try #require(model.activePeriod)
        // 07:00 on the period's first (UTC) day, so a 10 h shift stays on one workday.
        let start = period.window.startDate + 7 * 3_600
        var draft = WorkDraft(
            periodID: period.id, editingEntryID: nil, start: start,
            end: start.addingTimeInterval(10 * 3_600), kind: .regular, note: "",
            hasUnpaidBreak: false, breakStart: start, breakEnd: start, copiedFrom: nil)
        // 8 h x $50 + 2 h x $50 x 1.5 = $550.00, and nothing was persisted.
        #expect(model.expectedWagesChange(saving: draft)?.amount == 550)
        #expect(model.workEntries.isEmpty)

        try model.addWork(start: start, end: start.addingTimeInterval(8 * 3_600), kind: .regular)
        let saved = try #require(model.workEntries.first)
        draft.editingEntryID = saved.id
        // Editing the saved 8 h shift to 10 h adds only the two overtime hours.
        #expect(model.expectedWagesChange(saving: draft)?.amount == 150)
        // Outside the period there is no estimate rather than a guess.
        draft.start = period.window.startDate - 86_400
        draft.end = draft.start + 3_600
        #expect(model.expectedWagesChange(saving: draft) == nil)
    }

    @Test func newWorkSuggestionSkipsADayAlreadyLogged() throws {
        let model = AppModel()
        try model.saveProfile(UnitFixture.profile())
        let period = try #require(model.activePeriod)
        let now = period.window.startDate + 12 * 3_600
        let first = AddWorkView.suggestedInterval(model: model, now: now)
        #expect(model.conflictingWork(start: first.start, end: first.end, excluding: nil) == nil)
        try model.addWork(start: first.start, end: first.end, kind: .regular)
        let second = AddWorkView.suggestedInterval(model: model, now: now)
        #expect(second.start >= first.end)
        #expect(model.conflictingWork(start: second.start, end: second.end, excluding: nil) == nil)
        #expect(period.window.contains(start: second.start, end: second.end))
    }

    @Test func firstPeriodDefaultsToTheStartOfThisWeekSoRecentShiftsFit() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        calendar.firstWeekday = 1
        // Saturday afternoon: yesterday's shift must fall inside the proposed first period.
        let saturday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 15)))
        let start = PayProfileDraft.startOfCurrentWeek(now: saturday, calendar: calendar)
        #expect(calendar.component(.weekday, from: start) == calendar.firstWeekday)
        #expect(start == calendar.startOfDay(for: start))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: saturday))
        #expect(start <= yesterday && start <= saturday)
        #expect(saturday.timeIntervalSince(start) < 7 * 86_400)
    }

    @Test(arguments: [
        AuditDisplayStatus.notAudited, .matches, .grossMatches, .possibleShortfall,
        .possibleOverpayment, .needsReview, .notComparable,
    ])
    func statusIsTextualAndHasAnIcon(_ status: AuditDisplayStatus) {
        #expect(!status.title.isEmpty && !status.systemImage.isEmpty)
    }

    @Test(arguments: PayPeriodCadence.allCases)
    func cadenceSurvivesSerialization(_ cadence: PayPeriodCadence) throws {
        #expect(cadence.id == cadence.rawValue && !cadence.title.isEmpty)
        #expect(
            try JSONDecoder().decode(PayPeriodCadence.self, from: JSONEncoder().encode(cadence))
                == cadence)
    }
}
