import Foundation
import LinePayDomain

struct BenefitRuleDraft: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var basis: BenefitContributionBasis = .eligibleHour
    var rate = ""
    var quantity = ""
    var start: Date
    var end: Date
    var effectiveStart: Date
    var effectiveEnd: Date
    var reference = ""
    var sources: [AgreementSource] = []
    var eligibilityConfirmed = false

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
        effectiveStart = start
        effectiveEnd = end
    }
}

/// Editable source facts; preparing a preview never creates a saved comparison.
struct BenefitAuditDraft: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var recordID: UUID?
    var baseRevisionID: UUID?
    var fundID = UUID()
    var fundName = ""
    var kind: BenefitKind = .pension
    var currencyCode = "USD"
    var timeZoneIdentifier = "UTC"
    var decimalSeparator = String(NumberEntry.decimalSeparator)
    var start: Date
    var end: Date
    var segments: [BenefitRuleDraft]
    var completeEligibilityConfirmed = false
    var rulesConfirmed = false
    var roundingMode: MoneyRoundingMode = .halfUp
    var roundingScale = 2
    var hasStatement = false
    var statementStart: Date
    var statementEnd: Date
    var statementCurrencyCode = "USD"
    var statementTimeZoneIdentifier = "UTC"
    var statementMatchesFund = false
    var otherStatementFundID = UUID()
    var statementAmount = ""
    var statementQuantity = ""
    var statementBasis: BenefitContributionBasis = .eligibleHour
    var statementConfirmed = false
    var statementEvidence: PaystubEvidence?
    var statementSHA256: String?
    var note = ""

    init(start: Date, end: Date) {
        self.start = start
        self.end = end
        statementStart = start
        statementEnd = end
        segments = [BenefitRuleDraft(start: start, end: end)]
    }

    /// Reformat only values that parse completely in their saved context. Failed conversion
    /// returns no replacement, so partial input is preserved rather than guessed or cleared.
    func convertingNumbers(to separator: Character) throws -> Self {
        guard [".", ","].contains(String(separator)), [".", ","].contains(decimalSeparator) else {
            throw DecimalInputError.invalidNumber
        }
        guard String(separator) != decimalSeparator else { return self }
        let old: Character = decimalSeparator == "," ? "," : "."
        func converted(_ text: String, maximum: Decimal, precision: Int, symbol: Bool = false)
            throws -> String
        {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
            let value = try StrictDecimal.parse(
                text, maximum: maximum, fractionDigits: precision,
                allowDollarSign: symbol, decimalSeparator: old)
            let canonical = LinePayFormat.decimal(value)
            return separator == "," ? canonical.replacingOccurrences(of: ".", with: ",") : canonical
        }
        var copy = self
        copy.segments = try segments.map { segment in
            var value = segment
            value.rate = try converted(
                segment.rate, maximum: NumberEntry.amountMaximum(currencyCode: currencyCode),
                precision: 8)
            value.quantity = try converted(segment.quantity, maximum: 1_000_000_000, precision: 8)
            return value
        }
        copy.statementAmount = try converted(
            statementAmount,
            maximum: NumberEntry.amountMaximum(currencyCode: statementCurrencyCode),
            precision: statementCurrencyCode == "VND" ? 0 : 8, symbol: true)
        copy.statementQuantity = try converted(
            statementQuantity, maximum: 1_000_000_000, precision: 8)
        copy.decimalSeparator = String(separator)
        return copy.invalidatingReview(comparedTo: self)
    }

    func invalidatingReview(comparedTo previous: Self) -> Self {
        var copy = self
        let expectationChanged = expectationFacts != previous.expectationFacts
        if expectationChanged {
            copy.rulesConfirmed = false
            copy.completeEligibilityConfirmed = false
            for index in copy.segments.indices { copy.segments[index].eligibilityConfirmed = false }
        }
        if expectationChanged || hasStatement != previous.hasStatement
            || statementStart != previous.statementStart || statementEnd != previous.statementEnd
            || statementCurrencyCode != previous.statementCurrencyCode
            || statementTimeZoneIdentifier != previous.statementTimeZoneIdentifier
            || statementMatchesFund != previous.statementMatchesFund
            || statementAmount != previous.statementAmount
            || statementQuantity != previous.statementQuantity
            || statementBasis != previous.statementBasis
            || statementEvidence != previous.statementEvidence
            || statementSHA256 != previous.statementSHA256
        {
            copy.statementConfirmed = false
        }
        return copy
    }

    private var expectationFacts: Self {
        var copy = self
        copy.rulesConfirmed = false
        copy.completeEligibilityConfirmed = false
        for index in copy.segments.indices { copy.segments[index].eligibilityConfirmed = false }
        copy.hasStatement = false
        copy.statementStart = start
        copy.statementEnd = end
        copy.statementCurrencyCode = currencyCode
        copy.statementTimeZoneIdentifier = timeZoneIdentifier
        copy.statementMatchesFund = false
        copy.statementAmount = ""
        copy.statementQuantity = ""
        copy.statementBasis = .eligibleHour
        copy.statementConfirmed = false
        copy.statementEvidence = nil
        copy.statementSHA256 = nil
        copy.note = ""
        return copy
    }

    func calculate() throws -> BenefitContributionResult {
        guard !fundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            rulesConfirmed, [".", ","].contains(decimalSeparator),
            PayProfileDraft.supportedCurrencyCodes.contains(currencyCode),
            PayProfileDraft.supportedCurrencyCodes.contains(statementCurrencyCode)
        else { throw AppModelError.invalidField("Review the fund, currency and source rules") }
        let period = try window(start, end)
        let lines = try segments.map { draft in
            let rate = try StrictDecimal.parse(
                draft.rate, maximum: NumberEntry.amountMaximum(currencyCode: currencyCode),
                fractionDigits: 8, decimalSeparator: decimalSeparator == "," ? "," : ".")
            let quantity = try StrictDecimal.parse(
                draft.quantity, maximum: 1_000_000_000, fractionDigits: 8,
                decimalSeparator: decimalSeparator == "," ? "," : ".")
            var sources = draft.sources
            if !draft.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sources.append(AgreementSource(title: draft.reference, url: ""))
            }
            let rule = try BenefitRuleSnapshot(
                id: draft.id, fundID: fundID, version: "local-\(draft.id.uuidString)",
                basis: draft.basis, rate: rate, currencyCode: currencyCode,
                effectivePeriod: window(draft.effectiveStart, draft.effectiveEnd), sources: sources)
            return BenefitEligibilitySegment(
                id: draft.id, period: try window(draft.start, draft.end), rule: rule,
                quantity: quantity, eligibilityConfirmed: draft.eligibilityConfirmed)
        }
        let statement: BenefitStatementObservation?
        if hasStatement {
            let amount =
                statementAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : try Money(
                    amount: StrictDecimal.parse(
                        statementAmount,
                        maximum: NumberEntry.amountMaximum(currencyCode: statementCurrencyCode),
                        fractionDigits: statementCurrencyCode == "VND" ? 0 : 8,
                        allowDollarSign: true, decimalSeparator: decimalSeparator == "," ? "," : "."
                    ),
                    currencyCode: statementCurrencyCode)
            let units =
                statementQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : try StrictDecimal.parse(
                    statementQuantity, maximum: 1_000_000_000,
                    fractionDigits: 8, decimalSeparator: decimalSeparator == "," ? "," : ".")
            statement = BenefitStatementObservation(
                fundID: statementMatchesFund ? fundID : otherStatementFundID,
                currencyCode: statementCurrencyCode,
                period: try window(
                    statementStart, statementEnd, zoneID: statementTimeZoneIdentifier),
                employerContribution: amount, quantity: units,
                quantityBasis: units == nil ? nil : statementBasis, confirmed: statementConfirmed)
        } else {
            statement = nil
        }
        return try BenefitContributionCalculator().calculate(
            period: period, segments: lines,
            completeEligibilityConfirmed: completeEligibilityConfirmed, statement: statement,
            rounding: MoneyRoundingRule(
                scale: NumberEntry.amountFractionDigits(currencyCode: currencyCode),
                mode: roundingMode))
    }

    private func window(_ start: Date, _ end: Date, zoneID: String? = nil) throws -> BenefitPeriod {
        let identifier = zoneID ?? timeZoneIdentifier
        guard let zone = TimeZone(identifier: identifier),
            start.timeIntervalSince1970.isFinite, end.timeIntervalSince1970.isFinite
        else { throw BenefitContributionError.invalidPeriod }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        func local(_ date: Date) -> LocalDate {
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return LocalDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
        }
        return try BenefitPeriod(
            start: local(start), end: local(end), timeZoneIdentifier: identifier)
    }
}

struct BenefitAuditRevision: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var input: BenefitAuditDraft
    let result: BenefitContributionResult
    let recordedEpochSeconds: Int64
}

struct BenefitAuditRecord: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let fundID: UUID
    var revisions: [BenefitAuditRevision]
}
