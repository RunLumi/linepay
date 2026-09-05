import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Conservative paystub parsing")
struct OCRParserTests {
    func line(_ text: String) -> RecognizedPaystubLine {
        RecognizedPaystubLine(
            text: text, region: SourceRegion(page: 2, x: 0.1, y: 0.5, width: 0.8, height: 0.1),
            confidence: 0.9)
    }
    @Test func currentNeverSelectsYTD() {
        let fields = PaystubTextParser.parse([line("Gross pay: Current $1,000.00 YTD $12,000.00")])
        #expect(fields[.grossPay]?.value == "1000")
        #expect(fields[.grossPay]?.region.page == 2)
    }
    @Test(arguments: [
        "Gross pay $1,000.00 $12,000.00", "Gross YTD $12,000.00", "Gross pay -$100.00",
        "Gross pay ($100.00)",
    ])
    func abstainsFromAmbiguousOrNegativeRows(_ text: String) {
        let result = PaystubTextParser.parse([line(text)])[.grossPay]
        #expect(result?.value == nil)
        #expect(result?.reason != nil)
    }
    @Test func datesAndHoursCarrySource() {
        let result = PaystubTextParser.parse([
            line("Pay period 08/31/2026 to 09/06/2026"), line("Regular hours 40.00"),
        ])
        #expect(result[.periodStart]?.value == "2026-08-31")
        #expect(result[.periodEnd]?.value == "2026-09-06")
        #expect(result[.regularHours]?.value == "40")
        #expect(PaystubTextParser.normalizedDate("02/30/2026") == nil)
    }
    @Test func repeatedLabelsDoNotGuess() {
        #expect(
            PaystubTextParser.parse([line("Gross 400.00"), line("Gross 500.00")])[.grossPay]?.value
                == nil)
    }
}
