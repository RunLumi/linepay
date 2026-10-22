import Foundation
import LinePayDomain

/// Validates recorded facts independently of whether this client can activate their configuration.
/// It does not run a payroll or assessment engine over a frozen receipt.
enum PortableFinancialValidation {
    static func validate(_ state: PortableState) throws {
        for profile in state.profiles { if let zone = profile.timeZone { try validateZone(zone) } }
        for period in state.periods { try window(period.calendarWindow) }
        for snapshot in state.workSnapshots {
            for work in snapshot.work {
                try validateZone(work.timeZone)
                guard work.endEpochSeconds > work.startEpochSeconds else {
                    throw BackupError.invalidArchive
                }
                var previous = work.startEpochSeconds
                var unpaid: Int64 = 0
                for rest in work.unpaidBreaks {
                    guard rest.endEpochSeconds > rest.startEpochSeconds,
                        rest.startEpochSeconds >= previous,
                        rest.startEpochSeconds >= work.startEpochSeconds,
                        rest.endEpochSeconds <= work.endEpochSeconds
                    else { throw BackupError.invalidArchive }
                    previous = rest.endEpochSeconds
                    unpaid += rest.endEpochSeconds - rest.startEpochSeconds
                }
                guard unpaid < work.endEpochSeconds - work.startEpochSeconds else {
                    throw BackupError.invalidArchive
                }
            }
        }
        for rule in state.ruleSnapshots {
            for value in [rule.effectiveStartDate, rule.effectiveEndDateInclusive].compactMap({ $0 }
            ) { _ = try day(value) }
            if let multiplier = rule.outsideScheduleMultiplier { try atLeastOne(multiplier) }
            for tier in rule.dailyOvertimeTiers ?? [] { try atLeastOne(tier.multiplier) }
            for premium in rule.weekdayPremiums ?? [] { try atLeastOne(premium.multiplier) }
            for premium in rule.datePremiums ?? [] {
                _ = try day(premium.date)
                try atLeastOne(premium.multiplier)
            }
            var ranges: [String: [(String, String)]] = [:]
            for schedule in rule.regularSchedule ?? [] {
                guard schedule.end > schedule.start else { throw BackupError.invalidArchive }
                ranges[schedule.weekday, default: []].append((schedule.start, schedule.end))
            }
            for rows in ranges.values {
                let sorted = rows.sorted { $0.0 < $1.0 }
                for (left, right) in zip(sorted, sorted.dropFirst()) where left.1 > right.0 {
                    throw BackupError.invalidArchive
                }
            }
        }
        for receipt in state.paycheckReceipts {
            try window(receipt.targetWindow)
            try sourcePeriod(receipt.sourcePeriod)
            try sourcePeriod(receipt.assessment.reportedPeriod)
            let reported = receipt.assessment.reportedPeriod
            switch receipt.assessment.periodMatch {
            case "confirmedSamePeriod":
                guard reported?.confirmed == true,
                    reported?.startDate == receipt.targetWindow.startDate,
                    reported?.endDateInclusive == receipt.targetWindow.endDateInclusive,
                    reported?.timeZone == receipt.targetWindow.timeZone
                else { throw BackupError.invalidArchive }
            case "differentPeriod":
                guard reported?.confirmed == true else { throw BackupError.invalidArchive }
            case "unconfirmedPeriod":
                guard reported?.confirmed != true else { throw BackupError.invalidArchive }
            default: break
            }
            let pendingReasons: Set<String> = [
                "WEEKLY_REVIEW_PENDING",
                "A separate complete-workweek review is pending.",
                PaycheckAssessor.weeklyMappingReviewReason,
            ]
            let pendingReason = !pendingReasons.isDisjoint(with: receipt.assessment.reviewReasons)
            if receipt.reviewFacts.weeklyReviewPending == true {
                guard ["needsReview", "notComparable"].contains(receipt.assessment.verdict),
                    receipt.assessment.verdict != "needsReview" || pendingReason
                else { throw BackupError.invalidArchive }
            }
            if receipt.reviewFacts.weeklyReviewPending == false && pendingReason {
                throw BackupError.invalidArchive
            }
            guard receipt.assessment.paidGross.currency == receipt.paystubFacts.currency,
                PortableExactDecimal(receipt.assessment.paidGross.amount)
                    == PortableExactDecimal(receipt.paystubFacts.grossPay)
            else { throw BackupError.invalidArchive }
            for comparison in receipt.assessment.comparisons {
                guard comparison.currency == receipt.paystubFacts.currency else {
                    throw BackupError.invalidArchive
                }
                try nonnegative(comparison.expected)
                try nonnegative(comparison.paid)
            }
        }
        for calculation in state.periods.compactMap(\.calculation)
            + state.paycheckReceipts.compactMap(\.calculation)
        {
            if let total = calculation.total {
                try nonnegative(total.amount)
                guard total.currency == calculation.currency else {
                    throw BackupError.invalidArchive
                }
            }
            for component in calculation.components {
                _ = try day(component.localDate)
                try nonnegative(component.amount.amount)
                guard component.amount.currency == calculation.currency else {
                    throw BackupError.invalidArchive
                }
                let amounts: [PortableMoney?] = [
                    component.baseRate, component.unroundedAmount,
                    component.appliedAgreement?.hourlyRate,
                ]
                for money in amounts.compactMap({ $0 }) {
                    try nonnegative(money.amount)
                    guard money.currency == calculation.currency else {
                        throw BackupError.invalidArchive
                    }
                }
                if let multiplier = component.multiplier { try atLeastOne(multiplier) }
                if let numerator = component.baseTimeNumerator { try nonnegative(numerator) }
            }
        }
    }

    private static func window(_ value: PortableCalendarWindow) throws {
        if let zone = value.timeZone { try validateZone(zone) }
        for text in [value.startDate, value.endDateInclusive, value.endExclusiveDate].compactMap({
            $0
        }) { _ = try day(text) }
        guard (value.startEpochSeconds == nil) == (value.endExclusiveEpochSeconds == nil) else {
            throw BackupError.invalidArchive
        }
        if value.boundaryModel == "localDatesOnly", value.startEpochSeconds != nil {
            throw BackupError.invalidArchive
        }
        if let start = value.startEpochSeconds, let end = value.endExclusiveEpochSeconds,
            end <= start
        {
            throw BackupError.invalidArchive
        }
        if let start = value.startDate, let end = value.endExclusiveDate {
            guard end > start, let inclusive = value.endDateInclusive,
                calendar().date(byAdding: .day, value: 1, to: try day(inclusive)) == (try day(end))
            else { throw BackupError.invalidArchive }
        }
        if value.boundaryModel == "exactInstants" {
            guard let start = value.startEpochSeconds, let end = value.endExclusiveEpochSeconds,
                let zone = value.timeZone, let timeZone = TimeZone(identifier: zone),
                let startDate = value.startDate, let endDate = value.endExclusiveDate
            else { throw BackupError.invalidArchive }
            var local = calendar()
            local.timeZone = timeZone
            for (text, seconds) in [(startDate, start), (endDate, end)] {
                let date = try day(text)
                let parts = calendar().dateComponents([.year, .month, .day], from: date)
                guard local.date(from: parts)?.timeIntervalSince1970 == TimeInterval(seconds) else {
                    throw BackupError.invalidArchive
                }
            }
        }
    }
    private static func sourcePeriod(_ value: PortableSourcePeriod?) throws {
        guard let value else { return }
        if let zone = value.timeZone { try validateZone(zone) }
        for text in [value.startDate, value.endDateInclusive].compactMap({ $0 }) {
            _ = try day(text)
        }
        if let start = value.startDate, let end = value.endDateInclusive, end < start {
            throw BackupError.invalidArchive
        }
    }
    private static func calendar() -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private static func day(_ text: String) throws -> Date {
        let values = text.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { throw BackupError.invalidArchive }
        let parts = DateComponents(year: values[0], month: values[1], day: values[2])
        let value = calendar()
        guard let date = value.date(from: parts),
            value.dateComponents([.year, .month, .day], from: date) == parts
        else { throw BackupError.invalidArchive }
        return date
    }
    private static func validateZone(_ value: String) throws {
        // The shared schema owns exact-case IANA membership; this checks native availability.
        guard TimeZone(identifier: value) != nil else { throw BackupError.invalidArchive }
    }
    private static func nonnegative(_ value: String) throws {
        guard let number = PortableExactDecimal(value), !number.negative else {
            throw BackupError.invalidArchive
        }
    }
    private static func atLeastOne(_ value: String) throws {
        guard let number = PortableExactDecimal(value), !number.negative,
            let whole = number.string.split(separator: ".").first, whole != "0"
        else { throw BackupError.invalidArchive }
    }
}
