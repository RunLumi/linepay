import Foundation
import Testing
@testable import LinePayDomain

@Test("Daily overtime begins exactly at configured threshold")
func dailyOvertimeThreshold() throws {
    let rules = try agreement(
        dailyOvertimeTiers: [try DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5"))]
    )
    let shift = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 18, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("110.00"))
    #expect(result.components.map(\.hours) == [8, 2])
    #expect(result.components.map(\.multiplier) == [1, decimal("1.5")])
}

@Test("Multiple work intervals on same local date share daily overtime accumulation")
func overtimeAccumulatesAcrossIntervals() throws {
    let rules = try agreement(
        dailyOvertimeTiers: [try DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5"))]
    )
    let morning = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 12, 0))
    let afternoon = try work((2026, 9, 7, 13, 0), (2026, 9, 7, 19, 0))

    let result = try PayCalculator().calculate(
        work: [morning, afternoon],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("110.00"))
}

@Test("Second overtime tier splits at its exact threshold")
func secondOvertimeTier() throws {
    let rules = try agreement(
        dailyOvertimeTiers: [
            try DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5")),
            try DailyOvertimeTier(afterHours: 12, multiplier: 2),
        ]
    )
    let shift = try work((2026, 9, 7, 6, 0), (2026, 9, 7, 20, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("180.00"))
    #expect(result.components.map(\.hours) == [8, 4, 2])
}

@Test("Higher weekend premium wins over lower overtime tier")
func weekendPremiumWinsOverOvertime() throws {
    let rules = try agreement(
        weekdayPremiums: [try WeekdayPremium(weekday: .sunday, multiplier: 2)],
        dailyOvertimeTiers: [try DailyOvertimeTier(afterHours: 8, multiplier: decimal("1.5"))]
    )
    let shift = try work((2026, 9, 6, 8, 0), (2026, 9, 6, 18, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("200.00"))
    #expect(result.components.allSatisfy { $0.multiplier == 2 })
}

@Test("Per diem is paid once for multiple intervals on same local work date")
func perDiemOncePerDate() throws {
    let rules = try agreement(
        flatPerDiem: FlatPerDiemRule(
            amountPerWorkDate: Money(amount: 5, currencyCode: "USD")
        )
    )
    let first = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 10, 0))
    let second = try work((2026, 9, 7, 12, 0), (2026, 9, 7, 14, 0))

    let result = try PayCalculator().calculate(
        work: [first, second],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("45.00"))
    #expect(result.components.filter { $0.category == .perDiem }.count == 1)
}

@Test("Cross-midnight work can earn per diem on two local dates")
func perDiemAcrossMidnight() throws {
    let rules = try agreement(
        flatPerDiem: FlatPerDiemRule(
            amountPerWorkDate: Money(amount: 5, currencyCode: "USD")
        )
    )
    let shift = try work((2026, 9, 7, 23, 0), (2026, 9, 8, 1, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("30.00"))
    #expect(result.components.filter { $0.category == .perDiem }.count == 2)
}

@Test("Spring DST transition pays actual elapsed time, not wall-clock difference")
func springDSTUsesElapsedTime() throws {
    let rules = try agreement()
    let shift = try work((2026, 3, 8, 1, 0), (2026, 3, 8, 4, 0))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("20.00"))
}

@Test("Fall DST transition pays repeated elapsed hour")
func fallDSTUsesElapsedTime() throws {
    let rules = try agreement()
    let shift = try work((2026, 11, 1, 0, 30), (2026, 11, 1, 2, 30))

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("30.00"))
}

@Test("Historical timezone is stored with the work interval")
func intervalTimezoneControlsLocalDate() throws {
    let tokyo = "Asia/Tokyo"
    let sundayPremium = try WeekdayPremium(weekday: .sunday, multiplier: 2)
    let rules = try agreement(weekdayPremiums: [sundayPremium])
    let shift = try work(
        (2026, 9, 6, 8, 0),
        (2026, 9, 6, 9, 0),
        timeZoneIdentifier: tokyo
    )

    let result = try PayCalculator().calculate(
        work: [shift],
        agreement: rules,
        policy: .highestApplicable
    )

    #expect(result.total.amount == decimal("20.00"))
}

@Test("Overlapping work intervals are rejected instead of double counted")
func overlapRejected() throws {
    let rules = try agreement()
    let first = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 12, 0))
    let second = try work((2026, 9, 7, 11, 0), (2026, 9, 7, 13, 0))

    #expect(throws: PayCalculationError.overlappingWorkIntervals) {
        try PayCalculator().calculate(
            work: [first, second],
            agreement: rules,
            policy: .highestApplicable
        )
    }
}

@Test("Duplicate work IDs are rejected to preserve audit identity")
func duplicateIDRejected() throws {
    let rules = try agreement()
    let id = UUID()
    let first = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 9, 0), id: id)
    let second = try work((2026, 9, 7, 10, 0), (2026, 9, 7, 11, 0), id: id)

    #expect(throws: PayCalculationError.duplicateWorkIntervalID) {
        try PayCalculator().calculate(
            work: [first, second],
            agreement: rules,
            policy: .highestApplicable
        )
    }
}

@Test("Work outside agreement effective dates is rejected")
func effectiveDateGuard() throws {
    let rules = try agreement(
        effectiveStart: LocalDate(year: 2026, month: 6, day: 1),
        effectiveEnd: LocalDate(year: 2027, month: 5, day: 31)
    )
    let oldShift = try work((2026, 5, 31, 8, 0), (2026, 5, 31, 9, 0))

    #expect(
        throws: PayCalculationError.workOutsideAgreementEffectiveDates(
            LocalDate(year: 2026, month: 5, day: 31)
        )
    ) {
        try PayCalculator().calculate(
            work: [oldShift],
            agreement: rules,
            policy: .highestApplicable
        )
    }
}

@Test("Per diem currency mismatch is rejected")
func perDiemCurrencyMismatch() throws {
    let rules = try agreement(
        flatPerDiem: FlatPerDiemRule(
            amountPerWorkDate: Money(amount: 5, currencyCode: "CAD")
        )
    )
    let shift = try work((2026, 9, 7, 8, 0), (2026, 9, 7, 9, 0))

    #expect(throws: MoneyError.currencyMismatch(lhs: "USD", rhs: "CAD")) {
        try PayCalculator().calculate(
            work: [shift],
            agreement: rules,
            policy: .highestApplicable
        )
    }
}
