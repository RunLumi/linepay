import Foundation

public enum CrewRuleTemplateError: Error, Equatable, Sendable {
    case invalidFormat, invalidNumber, unsupportedRules, confirmationRequired, missingRate,
        allowanceReviewRequired
}

/// Selected worker-provided parameters, never a verified agreement, work record or payroll backup.
public struct CrewRuleTemplate: Hashable, Sendable {
    public struct Tier: Decodable, Hashable, Sendable {
        public let afterHours: String
        public let multiplier: String
    }
    public struct WeekPremium: Decodable, Hashable, Sendable {
        public let weekday: String
        public let multiplier: String
    }
    public struct Allowance: Decodable, Hashable, Sendable {
        public let configured: Bool
        public let amount: String?
    }
    public struct Rules: Decodable, Hashable, Sendable {
        public let currency: String
        public let hourlyRate: String?
        public let dailyOvertimeTiers: [Tier]
        public let weekdayPremiums: [WeekPremium]
        public let calloutMinimumHours: String?
        public let perDiem: Allowance
        public let rounding: MoneyRoundingRule
    }
    public enum PerDiemChoice: String, Codable, Hashable, Sendable {
        case unreviewed, notConfigured, notApplicable, confirmedAmount
    }
    public let templateID: UUID
    public let revision: String
    public let title: String
    public let rules: Rules
    public var calculationPolicy: PayCalculationPolicy { .highestApplicable }
    private static let weekdayNames = [
        "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    ]
    private static let weekdays: [Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]
    private struct Payload: Decodable {
        let format: String
        let version: Int
        let templateID: UUID
        let revision: String
        let title: String
        let scope: String
        let premiumCombination: String
        let rules: Rules
    }

    /// No random ID, clock or device context is read here. Callers choose the new public identity.
    public static func sharing(
        _ agreement: AgreementSnapshot, templateID: UUID, revision: String, title: String,
        includeAmounts: Bool = false
    ) throws -> Self {
        guard agreement.regularSchedule.isEmpty, agreement.datePremiums.isEmpty,
            agreement.outsideScheduleMultiplier == 1, agreement.weeklyOvertime == nil,
            agreement.effectiveStart == nil, agreement.effectiveEnd == nil,
            agreement.unsupportedRuleNotes?.isEmpty != false
        else { throw CrewRuleTemplateError.unsupportedRules }
        let result = Self(
            templateID: templateID, revision: revision, title: title,
            rules: Rules(
                currency: agreement.hourlyRate.currencyCode,
                hourlyRate: includeAmounts ? text(agreement.hourlyRate.amount) : nil,
                dailyOvertimeTiers: agreement.dailyOvertimeTiers.map {
                    Tier(afterHours: text($0.afterHours), multiplier: text($0.multiplier))
                },
                weekdayPremiums: agreement.weekdayPremiums.sorted {
                    $0.weekday.rawValue < $1.weekday.rawValue
                }.map {
                    WeekPremium(
                        weekday: weekdayNames[$0.weekday.rawValue - 1],
                        multiplier: text($0.multiplier))
                },
                calloutMinimumHours: agreement.calloutMinimum.map { text($0.minimumHours) },
                perDiem: Allowance(
                    configured: agreement.flatPerDiem != nil,
                    amount: includeAmounts
                        ? agreement.flatPerDiem.map { text($0.amountPerWorkDate.amount) } : nil),
                rounding: agreement.rounding))
        try result.validate()
        return result
    }

    public static func decode(_ data: Data) throws -> Self {
        guard !data.isEmpty, data.count <= 65_536, !data.contains(0),
            String(data: data, encoding: .utf8) != nil
        else { throw CrewRuleTemplateError.invalidFormat }
        try preflight(data)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.format == "com.streamentry.linepay.rule-template", payload.version == 1,
            payload.scope == "workerConfirmedConfiguredRulesOnly",
            payload.premiumCombination == "highestApplicable"
        else { throw CrewRuleTemplateError.invalidFormat }
        let result = Self(
            templateID: payload.templateID, revision: payload.revision, title: payload.title,
            rules: payload.rules)
        try result.validate()
        return result
    }

    public func encoded() throws -> Data {
        try validate()
        func value(_ text: String?) -> Any { text.map { $0 as Any } ?? NSNull() }
        let object: [String: Any] = [
            "format": "com.streamentry.linepay.rule-template", "version": 1,
            "templateID": templateID.uuidString.lowercased(), "revision": revision, "title": title,
            "scope": "workerConfirmedConfiguredRulesOnly",
            "premiumCombination": "highestApplicable",
            "rules": [
                "currency": rules.currency, "hourlyRate": value(rules.hourlyRate),
                "dailyOvertimeTiers": rules.dailyOvertimeTiers.map {
                    ["afterHours": $0.afterHours, "multiplier": $0.multiplier]
                },
                "weekdayPremiums": rules.weekdayPremiums.map {
                    ["weekday": $0.weekday, "multiplier": $0.multiplier]
                },
                "calloutMinimumHours": value(rules.calloutMinimumHours),
                "perDiem": [
                    "configured": rules.perDiem.configured, "amount": value(rules.perDiem.amount),
                ],
                "rounding": [
                    "scale": rules.rounding.scale, "mode": rules.rounding.mode.rawValue,
                    "scope": rules.rounding.scope.rawValue,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard data.count <= 65_536 else { throw CrewRuleTemplateError.invalidFormat }
        return data
    }

    /// The adapter must persist this template and the recipient choices with the new profile.
    /// It must not replace an existing rule snapshot, infer missing amounts or create source approval.
    public func proposeAgreement(
        newAgreementID: UUID, hourlyRate: Money?, perDiemChoice: PerDiemChoice,
        perDiemAmount: Money? = nil, applicabilityConfirmed: Bool, valuesConfirmed: Bool
    ) throws -> AgreementSnapshot {
        try validate()
        guard applicabilityConfirmed, valuesConfirmed else {
            throw CrewRuleTemplateError.confirmationRequired
        }
        guard let hourlyRate else { throw CrewRuleTemplateError.missingRate }
        guard hourlyRate.currencyCode == rules.currency else {
            throw CrewRuleTemplateError.invalidFormat
        }
        _ = try Self.number(Self.text(hourlyRate.amount))
        let allowance: FlatPerDiemRule?
        if rules.perDiem.configured {
            switch perDiemChoice {
            case .confirmedAmount:
                guard let perDiemAmount, perDiemAmount.currencyCode == rules.currency else {
                    throw CrewRuleTemplateError.allowanceReviewRequired
                }
                _ = try Self.number(Self.text(perDiemAmount.amount))
                allowance = try FlatPerDiemRule(amountPerWorkDate: perDiemAmount)
            case .notApplicable:
                guard perDiemAmount == nil else {
                    throw CrewRuleTemplateError.allowanceReviewRequired
                }
                allowance = nil
            case .unreviewed, .notConfigured: throw CrewRuleTemplateError.allowanceReviewRequired
            }
        } else {
            guard perDiemChoice == .notConfigured, perDiemAmount == nil else {
                throw CrewRuleTemplateError.allowanceReviewRequired
            }
            allowance = nil
        }
        return try AgreementSnapshot(
            id: newAgreementID.uuidString.lowercased(), version: "1",
            displayName: "Worker-provided draft: " + title,
            hourlyRate: hourlyRate, regularSchedule: [],
            weekdayPremiums: rules.weekdayPremiums.map {
                try WeekdayPremium(
                    weekday: Self.weekdays[Self.weekdayNames.firstIndex(of: $0.weekday)!],
                    multiplier: Self.number($0.multiplier, maximum: 10, minimum: 1))
            },
            dailyOvertimeTiers: rules.dailyOvertimeTiers.map {
                try DailyOvertimeTier(
                    afterHours: Self.number($0.afterHours, maximum: 168),
                    multiplier: Self.number($0.multiplier, maximum: 10, minimum: 1))
            },
            calloutMinimum: rules.calloutMinimumHours.map {
                try CalloutMinimumRule(minimumHours: Self.number($0, maximum: 168))
            },
            flatPerDiem: allowance, rounding: rules.rounding)
    }

    private func validate() throws {
        let trimScalars: Set<UInt32> = [32, 160, 5760, 8232, 8233, 8239, 8287, 12288, 65279]
        let hasTitle = title.unicodeScalars.contains {
            !trimScalars.contains($0.value) && !(8192...8202).contains($0.value)
        }

        guard (1...32).contains(revision.utf8.count),
            revision.utf8.allSatisfy({
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || $0 == 45 || $0 == 46
            }),
            hasTitle, title.utf8.count <= 240,
            !title.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
            rules.currency.utf8.count == 3,
            rules.currency.utf8.allSatisfy({ (65...90).contains($0) }),
            rules.dailyOvertimeTiers.count <= 20, rules.weekdayPremiums.count <= 7,
            (0...8).contains(rules.rounding.scale), rules.rounding.scope == .payCategory
        else { throw CrewRuleTemplateError.invalidFormat }
        if let rate = rules.hourlyRate { _ = try Self.number(rate) }
        var previous: Decimal?
        for tier in rules.dailyOvertimeTiers {
            let threshold = try Self.number(tier.afterHours, maximum: 168)
            _ = try Self.number(tier.multiplier, maximum: 10, minimum: 1)
            var seconds = threshold * 3_600
            var integer = Decimal()
            NSDecimalRound(&integer, &seconds, 0, .down)
            guard seconds == integer, previous.map({ threshold > $0 }) ?? true else {
                throw CrewRuleTemplateError.invalidFormat
            }
            previous = threshold
        }
        var previousDay = -1
        for premium in rules.weekdayPremiums {
            guard let day = Self.weekdayNames.firstIndex(of: premium.weekday), day > previousDay
            else { throw CrewRuleTemplateError.invalidFormat }
            _ = try Self.number(premium.multiplier, maximum: 10, minimum: 1)
            previousDay = day
        }
        if let minimum = rules.calloutMinimumHours {
            guard try Self.number(minimum, maximum: 168) > 0 else {
                throw CrewRuleTemplateError.invalidNumber
            }
        }
        guard rules.perDiem.configured || rules.perDiem.amount == nil else {
            throw CrewRuleTemplateError.invalidFormat
        }
        if let amount = rules.perDiem.amount { _ = try Self.number(amount) }
    }
    private static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
    private static func number(_ value: String, maximum: Decimal = 10_000_000, minimum: Decimal = 0)
        throws -> Decimal
    {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), (1...8).contains(parts[0].utf8.count),
            parts[0].count == 1 || parts[0].first != "0",
            parts.count == 1 || (1...8).contains(parts[1].utf8.count),
            parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } })
        else { throw CrewRuleTemplateError.invalidNumber }
        let result = try StrictDecimal.parse(value, maximum: maximum, fractionDigits: 8)
        guard result >= minimum else { throw CrewRuleTemplateError.invalidNumber }
        return result
    }
    private static func rejectDuplicateFields(_ data: Data) throws {
        let bytes = Array(data)
        var stack: [Set<String>?] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 123 {
                stack.append(Set())
                index += 1
                continue
            }
            if byte == 91 {
                stack.append(nil)
                index += 1
                continue
            }
            if byte == 125 || byte == 93 {
                _ = stack.popLast()
                index += 1
                continue
            }
            guard byte == 34 else {
                index += 1
                continue
            }
            let start = index
            index += 1
            while index < bytes.count {
                if bytes[index] == 92 {
                    index += 2
                    continue
                }
                if bytes[index] == 34 { break }
                index += 1
            }
            let end = index
            var next = end + 1
            while next < bytes.count && [9, 10, 13, 32].contains(bytes[next]) { next += 1 }
            if next < bytes.count && bytes[next] == 58 {
                guard !stack.isEmpty, var fields = stack.last!, end < bytes.count,
                    let key = try JSONSerialization.jsonObject(
                        with: Data(bytes[start...end]), options: [.fragmentsAllowed]) as? String,
                    fields.insert(key).inserted
                else { throw CrewRuleTemplateError.invalidFormat }
                stack[stack.count - 1] = fields
            }
            index = end + 1
        }
    }
    private static func preflight(_ data: Data) throws {
        func object(_ value: Any?, _ expected: [String]) throws -> [String: Any] {
            guard let result = value as? [String: Any], Set(result.keys) == Set(expected) else {
                throw CrewRuleTemplateError.invalidFormat
            }
            return result
        }
        let root = try object(
            JSONSerialization.jsonObject(with: data),
            [
                "format", "version", "templateID", "revision", "title", "scope",
                "premiumCombination", "rules",
            ])
        let rules = try object(
            root["rules"],
            [
                "currency", "hourlyRate", "dailyOvertimeTiers", "weekdayPremiums",
                "calloutMinimumHours", "perDiem", "rounding",
            ])
        _ = try object(rules["perDiem"], ["configured", "amount"])
        _ = try object(rules["rounding"], ["scale", "mode", "scope"])
        guard let tiers = rules["dailyOvertimeTiers"] as? [Any], tiers.count <= 20,
            let premiums = rules["weekdayPremiums"] as? [Any], premiums.count <= 7
        else { throw CrewRuleTemplateError.invalidFormat }
        try rejectDuplicateFields(data)
        for tier in tiers { _ = try object(tier, ["afterHours", "multiplier"]) }
        for premium in premiums { _ = try object(premium, ["weekday", "multiplier"]) }
    }
}
