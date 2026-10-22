import Foundation
import LinePayDomain

/// Codable does not call validating initializers. Validate stored/imported semantics before use.
enum AppStateValidation {
    static func validate(_ state: AppPersistentState) throws {
        try PortableStateMapping.validateStored(state)
        let contexts =
            state.history.map { ($0.window, $0.workEntries, $0.agreement, $0.timeZoneIdentifier) }
            + [
                state.activePeriod.map {
                    ($0.window, $0.workEntries, $0.agreement, $0.timeZoneIdentifier)
                }
            ].compactMap { $0 }
        let ids = state.history.map(\.id) + [state.activePeriod?.id].compactMap { $0 }
        guard ids.count <= 2_000, Set(ids).count == ids.count,
            state.profile != nil || ids.isEmpty || state.portableCurrentProfile != nil,
            state.schemaVersion == AppPersistentState.currentSchemaVersion
        else { throw invalid() }
        if let owner = state.portableCurrentProfile {
            guard ids.contains(owner.periodID), owner.profile(in: state) != nil else {
                throw invalid()
            }
            if let source = state.portableFinancialState,
                let period = source.periods.first(where: {
                    PortableStateMapping.local("period", $0.id) == owner.periodID
                }),
                let ref = period.profileRef
                    ?? source.workSnapshots.first(where: { $0.id == period.currentWorkSnapshotRef }
                    )?.profileRef,
                let profile = source.profiles.first(where: { $0.id == ref })
            {
                guard owner.profileID == PortableStateMapping.local("profile", ref),
                    owner.sourceName == profile.name
                else { throw invalid() }
            } else if let adoption = state.portableAdoptions.first(where: {
                $0.nativePeriodID == owner.periodID
            }) {
                guard owner.profileID == adoption.nativeProfileID,
                    owner.sourceName == adoption.nativeProfileName
                else { throw invalid() }
            } else if state.portableFinancialState != nil {
                guard let profile = state.profile, owner.profileID == profile.id,
                    owner.sourceName == profile.name
                else { throw invalid() }
            }
        }
        try BenefitAuditValidation.validate(
            records: state.benefitAudits ?? [], draft: state.benefitAuditDraft)
        try AgreementImportValidation.validate(state.agreementDocuments ?? [])
        try CrewRuleDraftBuilder.validate(state.crewRuleOrigins ?? [])
        if let adoption = state.setupDraft?.crewRuleAdoption {
            _ = try adoption.proposedAgreement(newAgreementID: UUID())
        }
        let events = state.resolutionEvents ?? []
        guard events.count <= 10_000, Set(events.map(\.id)).count == events.count else {
            throw invalid()
        }
        for event in events {
            let paystubs: [ConfirmedPaystub]
            if let active = state.activePeriod, active.id == event.periodID {
                paystubs =
                    [active.paystub].compactMap { $0 }
                    + (active.auditRevisions ?? []).map(\.paystub)
            } else if let period = state.history.first(where: { $0.id == event.periodID }) {
                paystubs =
                    [period.paystub].compactMap { $0 }
                    + (period.auditRevisions ?? []).map(\.paystub)
            } else {
                throw invalid()
            }
            guard let paystub = paystubs.first(where: { $0.id == event.paystubID }),
                !event.note.isEmpty,
                event.note.count <= 4_000,
                (-62_135_596_800...253_402_300_799).contains(event.recordedEpochSeconds)
            else { throw invalid() }
            if let findingID = event.findingID {
                guard AuditFinding.contains(findingID, in: paystub)
                else { throw invalid() }
            }
        }
        if let profile = state.profile {
            guard TimeZone(identifier: profile.timeZoneIdentifier) != nil else { throw invalid() }
            try validate(profile.agreement)
        }
        if let profile = state.profile {
            try validateTimeline(
                profile.baselineAgreement ?? profile.agreement, profile.agreementChanges)
        }
        if let active = state.activePeriod {
            try validateTimeline(active.agreement, active.agreementChanges)
        }
        for period in state.history {
            try validateTimeline(period.agreement, period.agreementChanges)
        }
        for (window, entries, agreement, zone) in contexts {
            try validate(window: window, entries: entries, zone: zone)
            try validate(agreement)
        }
        let sorted = contexts.map { $0.0 }.sorted { $0.startEpochSeconds < $1.startEpochSeconds }
        for (a, b) in zip(sorted, sorted.dropFirst()) where a.endEpochSeconds > b.startEpochSeconds
        { throw invalid() }
        for original in state.allEvidence + state.pendingEvidenceDeletions {
            guard safeFilename(original.storedFilename) else { throw invalid() }
        }
        if let draft = state.workDraft, draft.periodID != state.activePeriod?.id {
            guard
                state.history.contains(where: { $0.id == draft.periodID && $0.calculation == nil })
            else { throw invalid() }
        }
        if let draft = state.paystubDraft {
            guard ids.contains(draft.targetPeriodID ?? UUID()) else { throw invalid() }
            try validate(suggestions: draft.suggestions)
        }
        let revisions =
            (state.activePeriod?.auditRevisions ?? [])
            + state.history.flatMap { $0.auditRevisions ?? [] }
        for revision in revisions {
            try validate(
                window: revision.window, entries: revision.workEntries,
                zone: revision.timeZoneIdentifier)
            try validate(revision.agreement)
            try validateTimeline(revision.agreement, revision.agreementChanges)
            if let calculation = revision.calculation {
                try validate(calculation: calculation, agreement: revision.agreement)
            }
            try validate(
                paystub: revision.paystub, calculation: revision.calculation,
                agreement: revision.agreement)
        }
        if let active = state.activePeriod, let paystub = active.paystub {
            try validate(
                paystub: paystub, calculation: nil,
                agreement: active.agreement)
        }
        for period in state.history {
            if let calculation = period.calculation {
                guard period.calculationIssue == nil else { throw invalid() }
                try validate(calculation: calculation, agreement: period.agreement)
            } else {
                guard let issue = period.calculationIssue, !issue.isEmpty,
                    period.comparisonCalculation != nil || period.reconciliation == nil
                else { throw invalid() }
            }
            for revision in period.workCorrections ?? [] {
                guard !revision.reason.isEmpty else { throw invalid() }
                try validate(
                    window: period.window, entries: revision.workEntries,
                    zone: period.timeZoneIdentifier)
            }
            if let paystub = period.paystub {
                try validate(
                    paystub: paystub,
                    calculation: period.reconciliation == nil ? nil : period.comparisonCalculation,
                    agreement: period.agreement)
            }
        }
    }

    private static func validateTimeline(
        _ baseline: AgreementSnapshot, _ changes: [AgreementChange]?
    ) throws {
        try validate(baseline)
        _ = try AgreementTimeline(baseline: baseline, changes: changes ?? [])
        for change in changes ?? [] { try validate(change.agreement) }
    }

    static func safeFilename(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ ."))
        return !value.isEmpty && value.count <= 150 && !value.contains("..")
            && value != "." && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func validate(suggestions: [PaystubField: OCRFieldSuggestion]) throws {
        for suggestion in suggestions.values {
            let region = suggestion.region
            guard suggestion.confidence.isFinite, (0...1).contains(suggestion.confidence),
                region.page >= 0, region.page < 10_000,
                [region.x, region.y, region.width, region.height].allSatisfy({
                    $0.isFinite && (0...1).contains($0)
                }),
                region.x + region.width <= 1.000001, region.y + region.height <= 1.000001
            else { throw invalid() }
        }
    }

    private static func validate(calculation: CalculationResult, agreement: AgreementSnapshot)
        throws
    {
        guard calculation.agreementID == agreement.id,
            calculation.agreementVersion == agreement.version,
            !calculation.total.amount.isNaN, calculation.total.amount >= 0,
            calculation.total.currencyCode == agreement.hourlyRate.currencyCode,
            Set(calculation.components.map(\.id)).count == calculation.components.count,
            calculation.components.allSatisfy({
                !$0.amount.amount.isNaN && $0.amount.amount >= 0
                    && $0.amount.currencyCode == calculation.total.currencyCode
            })
        else { throw invalid() }
        let sum = Money(
            amount: calculation.components.reduce(0) { $0 + $1.amount.amount },
            currencyCode: calculation.total.currencyCode
        ).rounded(using: agreement.rounding)
        guard sum == calculation.total else { throw invalid() }
        for component in calculation.components {
            if let base = component.baseTimeNumerator {
                guard !base.isNaN, base >= 0 else { throw invalid() }
            }
            if calculation.provenance?.engine == PayCalculator.currentEngine,
                component.category != .perDiem
            {
                guard let base = component.baseTimeNumerator,
                    let raw = component.unroundedAmount,
                    raw.amount == base * (component.multiplier ?? 1) / 3_600
                else { throw invalid() }
            }
            if let raw = component.unroundedAmount {
                guard !raw.amount.isNaN, raw.amount >= 0,
                    raw.currencyCode == calculation.total.currencyCode
                else { throw invalid() }
            }
        }
        if let provenance = calculation.provenance {
            let supportedPrecision =
                (provenance.engine == "linepay.configured-pay/2"
                    && provenance.rounding == "explicit-snapshot-rounding/1")
                || (["linepay.configured-pay/3", PayCalculator.currentEngine].contains(
                    provenance.engine)
                    && provenance.rounding == "exact-seconds-snapshot-rounding/2")
            guard supportedPrecision,
                provenance.callout == "confirmed-event-isolated-minimum/1"
            else { throw invalid() }
        }
        // Do not recalculate historical amounts with a new engine version.
    }

    private static func validate(
        paystub: ConfirmedPaystub, calculation: CalculationResult?, agreement: AgreementSnapshot
    ) throws {
        let currency = agreement.hourlyRate.currencyCode
        let money = [
            paystub.grossPay, paystub.regularPay, paystub.overtimePay,
            paystub.doubleTimePay, paystub.calloutPay, paystub.perDiemPay,
        ].compactMap { $0 }
        guard
            money.allSatisfy({ !$0.amount.isNaN && $0.amount >= 0 && $0.currencyCode == currency }),
            [paystub.regularHours, paystub.overtimeHours, paystub.doubleTimeHours].compactMap({ $0 }
            )
            .allSatisfy({ !$0.isNaN && $0 >= 0 && $0 <= 10_000 })
        else { throw invalid() }
        if let date = paystub.payPeriodStart { try validate(date) }
        if let date = paystub.payPeriodEnd { try validate(date) }
        if let start = paystub.payPeriodStart, let end = paystub.payPeriodEnd, start > end {
            throw invalid()
        }
        if let confirmation = paystub.confirmation {
            try validate(suggestions: confirmation.suggestions)
        }

        // Legacy audits remain review-only.
        guard let assessment = paystub.assessment else { return }
        guard (1...PaycheckAssessor.currentEngineVersion).contains(assessment.engineVersion),
            assessment.paidGross == paystub.grossPay,
            Set(assessment.comparisons.map(\.id)).count == assessment.comparisons.count
        else { throw invalid() }
        if assessment.engineVersion >= 4, assessment.expectedGross != nil,
            PaycheckAssessor.requiresWeeklyMappingReview(
                agreement: agreement, calculation: calculation)
        {
            guard assessment.verdict == .needsReview,
                assessment.reviewReasons.contains(PaycheckAssessor.weeklyMappingReviewReason)
            else { throw invalid() }
        }
        if assessment.engineVersion >= 5, assessment.expectedGross != nil,
            paystub.confirmation?.lineLayout == .basePlusPremium, let calculation
        {
            let included = calculation.components.filter {
                $0.category == .workedHours
                    || ($0.category == .calloutGuarantee
                        && paystub.confirmation?.guaranteeLayout == .includedInHourlyLines)
            }
            let hasMoneyLines = [paystub.regularPay, paystub.overtimePay, paystub.doubleTimePay]
                .contains { $0 != nil }
            if hasMoneyLines && included.contains(where: { $0.baseTimeNumerator == nil }) {
                guard assessment.verdict == .needsReview,
                    assessment.reviewReasons.contains(PaycheckAssessor.exactBaseReviewReason),
                    !assessment.comparisons.contains(where: {
                        [.regularPay, .overtimePay, .doubleTimePay].contains($0.field)
                    })
                else { throw invalid() }
            }
        }
        for comparison in assessment.comparisons {
            guard
                [comparison.expected, comparison.paid, comparison.difference].allSatisfy({
                    !$0.isNaN
                }),
                comparison.expected >= 0, comparison.paid >= 0, comparison.currencyCode == currency,
                comparison.unit == (comparison.field.isHours ? .hours : .money)
            else { throw invalid() }
            let difference = Money(
                amount: comparison.expected - comparison.paid, currencyCode: currency
            ).rounded(
                using: comparison.unit == .hours
                    ? MoneyRoundingRule(scale: 4) : agreement.rounding)
            guard comparison.difference == difference.amount else { throw invalid() }
            if let calculation {
                guard
                    Set(comparison.componentIDs).isSubset(of: Set(calculation.components.map(\.id)))
                else { throw invalid() }
            }
        }
        if let expected = assessment.expectedGross {
            guard !expected.amount.isNaN, expected.amount >= 0, expected.currencyCode == currency,
                let difference = assessment.difference, !difference.amount.isNaN,
                difference.currencyCode == currency,
                let gross = assessment.comparisons.first(where: { $0.field == .grossPay }),
                gross.expected == expected.amount, gross.paid == assessment.paidGross.amount,
                gross.difference == difference.amount
            else { throw invalid() }
            if let calculation, let basis = paystub.confirmation?.grossBasis {
                let recordedExpected =
                    basis == .wagesOnly ? calculation.expectedWages : calculation.total
                guard basis != .unconfirmed, expected == recordedExpected else { throw invalid() }
            }
        } else if assessment.verdict != .notComparable || assessment.difference != nil {
            throw invalid()
        }
        switch assessment.verdict {
        case .matches:
            guard assessment.difference?.amount == 0, assessment.reviewReasons.isEmpty,
                assessment.comparisons.allSatisfy({ !$0.differs })
            else { throw invalid() }
        case .possibleShortfall:
            guard let difference = assessment.difference, difference.amount > 0,
                assessment.reviewReasons.isEmpty
            else { throw invalid() }
        case .possibleOverpayment:
            guard let difference = assessment.difference, difference.amount < 0,
                assessment.reviewReasons.isEmpty
            else { throw invalid() }
        case .needsReview:
            guard !assessment.reviewReasons.isEmpty else { throw invalid() }
        case .notComparable:
            guard assessment.expectedGross == nil else { throw invalid() }
        }
    }

    private static func validate(_ agreement: AgreementSnapshot) throws {
        for source in agreement.sources { try AgreementImportValidation.validate(source) }

        guard !agreement.hourlyRate.amount.isNaN, agreement.hourlyRate.amount > 0,
            agreement.hourlyRate.amount <= 10_000_000,
            agreement.hourlyRate.currencyCode.utf8.count == 3,
            agreement.hourlyRate.currencyCode.utf8.allSatisfy({ (65...90).contains($0) }),
            (0...8).contains(agreement.rounding.scale),
            !agreement.outsideScheduleMultiplier.isNaN, agreement.outsideScheduleMultiplier >= 1,
            Set(agreement.dailyOvertimeTiers.map(\.afterHours)).count
                == agreement.dailyOvertimeTiers.count,
            Set(agreement.weekdayPremiums.map(\.weekday)).count == agreement.weekdayPremiums.count,
            Set(agreement.datePremiums.map(\.date)).count == agreement.datePremiums.count
        else { throw invalid() }
        for item in agreement.regularSchedule {
            _ = try RegularScheduleWindow(
                weekday: item.weekday,
                start: LocalTime(hour: item.start.hour, minute: item.start.minute),
                end: LocalTime(hour: item.end.hour, minute: item.end.minute))
        }
        for tier in agreement.dailyOvertimeTiers {
            guard !tier.afterHours.isNaN, !tier.multiplier.isNaN else { throw invalid() }
            _ = try DailyOvertimeTier(afterHours: tier.afterHours, multiplier: tier.multiplier)
        }
        for premium in agreement.weekdayPremiums {
            guard !premium.multiplier.isNaN, premium.multiplier >= 1 else { throw invalid() }
        }
        for premium in agreement.datePremiums {
            try validate(premium.date)
            guard !premium.multiplier.isNaN, premium.multiplier >= 1 else { throw invalid() }
        }
        if let start = agreement.effectiveStart { try validate(start) }
        if let end = agreement.effectiveEnd { try validate(end) }
        if let start = agreement.effectiveStart, let end = agreement.effectiveEnd, start > end {
            throw invalid()
        }
        if let rule = agreement.calloutMinimum {
            guard !rule.minimumHours.isNaN, rule.minimumHours > 0 else { throw invalid() }
        }
        if let rule = agreement.flatPerDiem {
            guard !rule.amountPerWorkDate.amount.isNaN, rule.amountPerWorkDate.amount >= 0,
                rule.amountPerWorkDate.currencyCode == agreement.hourlyRate.currencyCode
            else { throw invalid() }
        }
    }
    private static func validate(_ date: LocalDate) throws {
        guard (1...9999).contains(date.year), (1...12).contains(date.month),
            (1...31).contains(date.day)
        else { throw invalid() }
        let calendar = Calendar(identifier: .gregorian)
        let parts = DateComponents(year: date.year, month: date.month, day: date.day)
        guard let value = calendar.date(from: parts),
            calendar.component(.day, from: value) == date.day
        else { throw invalid() }
    }
    private static func validate(window: PayPeriodWindow, entries: [WorkEntry], zone: String?)
        throws
    {
        let range: ClosedRange<Int64> = -62_135_596_800...253_402_300_799
        guard range.contains(window.startEpochSeconds), range.contains(window.endEpochSeconds),
            window.endEpochSeconds > window.startEpochSeconds, entries.count <= 50_000,
            Set(entries.map(\.id)).count == entries.count
        else { throw invalid() }
        if let zone, TimeZone(identifier: zone) == nil { throw invalid() }
        let ordered = entries.sorted {
            $0.interval.startEpochSeconds < $1.interval.startEpochSeconds
        }
        var priorEnd: Int64?
        for entry in ordered {
            let work = entry.interval
            guard work.startEpochSeconds >= window.startEpochSeconds,
                work.endEpochSeconds <= window.endEpochSeconds,
                work.endEpochSeconds > work.startEpochSeconds,
                work.startEpochSeconds >= (priorEnd ?? work.startEpochSeconds)
            else { throw invalid() }
            _ = try WorkInterval(
                id: work.id, startEpochSeconds: work.startEpochSeconds,
                endEpochSeconds: work.endEpochSeconds, timeZoneIdentifier: work.timeZoneIdentifier,
                kind: work.kind,
                unpaidBreaks: try work.unpaidBreaks.map {
                    try WorkBreak(
                        id: $0.id, startEpochSeconds: $0.startEpochSeconds,
                        endEpochSeconds: $0.endEpochSeconds)
                })
            priorEnd = work.endEpochSeconds
        }
    }
    private static func invalid() -> LocalStateStoreError { .invalidState }
}
