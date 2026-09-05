import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Paystub suggestions never silently choose a payroll column")
struct PaystubParserTests {
    @Test(arguments: [
        ("Gross pay $1,234.56", "1234.56"), ("GROSS EARNINGS 1234.56", "1234.56"),
        ("Gross 0.00", "0.00"),
    ])
    func unambiguousGross(_ line: String, _ expected: String) {
        let result = PaystubTextParser.parse(lines: [line])
        #expect(result.grossPay == expected)
        #expect(result.recognizedText == line)
    }

    @Test(arguments: [
        "Gross pay Current $1,234.56 YTD $12,345.67", "Gross pay 100.00 200.00",
        "Gross adjustment -125.00", "Gross ($125.00)", "Gross 125.00-",
        "Gross YEAR TO DATE 125.00", "Gross 1,23.00", "Gross 125.000",
        "Gross nothing", "Gross 1.234,56", "Grosspay 125.00", "Gross abc125.00",
    ])
    func uncertainOrMalformedValueIsNotSuggested(_ line: String) {
        #expect(PaystubTextParser.parse(lines: [line]).grossPay == nil)
    }

    @Test func supportedLabelsStayIndependent() {
        let lines = [
            "Gross 500.00", "Regular pay 300.00", "OT pay 100.00", "Double-time 50.00",
            "Per-diem 50.00",
        ]
        let result = PaystubTextParser.parse(lines: lines)
        #expect(result.regularPay == "300.00" && result.overtimePay == "100.00")
        #expect(result.doubleTimePay == "50.00" && result.perDiemPay == "50.00")
        #expect(result.recognizedText == lines.joined(separator: "\n"))
        #expect(PaystubTextParser.parse(lines: ["Gross 100.00", "Gross 200.00"]).grossPay == nil)
        #expect(PaystubTextParser.parse(lines: []).recognizedText.isEmpty)
        #expect(PaystubTextParser.parse(lines: []).grossPay == nil)
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
        #expect(LinePayFormat.localDate(LocalDate(year: 2026, month: 1, day: 2)) == "01/02/2026")
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

    @Test(arguments: [
        AuditDisplayStatus.notAudited, .matches, .possibleShortfall, .possibleOverpayment,
        .needsReview,
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
