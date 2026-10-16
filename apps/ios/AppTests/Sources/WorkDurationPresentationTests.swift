import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Work duration display never pretends rounded hours are an exact formula")
@MainActor
struct WorkDurationPresentationTests {
    @Test func minuteSecondAndFractionalSecondRemainRecognizable() {
        let locale = Locale(identifier: "en_US")
        let minute = LinePayFormat.workDuration(Decimal(1) / 60, locale: locale)
        #expect(minute.contains("1 min") && !minute.contains("0.02"))
        #expect(LinePayFormat.workDuration(Decimal(1) / 3_600, locale: locale).contains("1 sec"))
        #expect(
            LinePayFormat.workDuration(Decimal(string: "0.5")!, locale: locale).contains("30 min"))
        #expect(
            LinePayFormat.workDuration(Decimal(string: "0.00000001")!, locale: locale)
                == "0.000036 s")
    }
    @Test func componentFormulaStatesHourlyRateAndRequiresRecordedMultiplier() {
        let rate = Money(amount: Decimal(string: "58.50")!, currencyCode: "USD")
        func part(_ multiplier: Decimal?) -> PayComponent {
            PayComponent(
                category: .workedHours, workIntervalID: nil,
                localDate: LocalDate(year: 2026, month: 10, day: 17), hours: Decimal(1) / 60,
                multiplier: multiplier,
                amount: Money(amount: Decimal(string: "0.98")!, currencyCode: "USD"),
                explanation: "Synthetic minute", baseRate: rate)
        }
        let formula = componentFormula(
            part(1), fallbackRate: Money(amount: 50, currencyCode: "USD"))
        #expect(formula?.contains("0.02 h") == false)
        #expect(formula?.contains(LinePayFormat.money(rate) + "/h") == true)
        #expect(componentFormula(part(nil), fallbackRate: rate) == nil)
    }
}
