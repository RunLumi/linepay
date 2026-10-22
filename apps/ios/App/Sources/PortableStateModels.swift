import Foundation

// Typed values follow shared/contracts/portable-state/schema-v1.json.
// Strict structural validation precedes decoding; nil fields encode as explicit JSON null.

struct PortableState: Codable, Hashable, Sendable {
    let format: String
    let version: Int64
    let exportedAtEpochSeconds: Int64
    let source: PortableSource
    let sourceInventory: PortableSourceInventory
    let identityCrosswalk: [PortableIdentity]
    let profiles: [PortableProfile]
    let ruleSnapshots: [PortableRuleSnapshot]
    let ruleChanges: [PortableRuleChange]
    let periods: [PortablePeriod]
    let workSnapshots: [PortableWorkSnapshot]
    let paycheckReceipts: [PortablePaycheckReceipt]
    var attachments: [PortableAttachment]
    let ruleTimelines: [PortableRuleTimeline]
    let activeProfileRef: String?
    let adoptions: [PortableProfileAdoption]
    private enum CodingKeys: String, CodingKey {
        case format, version, exportedAtEpochSeconds, source, sourceInventory, identityCrosswalk,
            profiles, ruleSnapshots, ruleChanges, periods, workSnapshots, paycheckReceipts,
            attachments, ruleTimelines, activeProfileRef, adoptions
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(format, forKey: .format)
        try values.encode(version, forKey: .version)
        try values.encode(exportedAtEpochSeconds, forKey: .exportedAtEpochSeconds)
        try values.encode(source, forKey: .source)
        try values.encode(sourceInventory, forKey: .sourceInventory)
        try values.encode(identityCrosswalk, forKey: .identityCrosswalk)
        try values.encode(profiles, forKey: .profiles)
        try values.encode(ruleSnapshots, forKey: .ruleSnapshots)
        try values.encode(ruleChanges, forKey: .ruleChanges)
        try values.encode(periods, forKey: .periods)
        try values.encode(workSnapshots, forKey: .workSnapshots)
        try values.encode(paycheckReceipts, forKey: .paycheckReceipts)
        try values.encode(attachments, forKey: .attachments)
        try values.encode(ruleTimelines, forKey: .ruleTimelines)
        try values.encode(activeProfileRef, forKey: .activeProfileRef)
        try values.encode(adoptions, forKey: .adoptions)
    }
}

struct PortableSource: Codable, Hashable, Sendable {
    let client: String
    let localStateSchema: Int64
    let exporterVersion: String
    private enum CodingKeys: String, CodingKey { case client, localStateSchema, exporterVersion }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(client, forKey: .client)
        try values.encode(localStateSchema, forKey: .localStateSchema)
        try values.encode(exporterVersion, forKey: .exporterVersion)
    }
}

struct PortableSourceInventory: Codable, Hashable, Sendable {
    let profileCount: Int64
    let ruleSnapshotCount: Int64
    let ruleChangeCount: Int64
    let periodCount: Int64
    let workSnapshotCount: Int64
    let workEntryCount: Int64
    let paycheckReceiptCount: Int64
    let attachmentCount: Int64
    let unsupportedFinancialRecordKinds: [String]
    let unsupportedDraftKinds: [String]
    let omittedFinancialRecordCount: Int64
    let ruleTimelineCount: Int64
    let workBreakCount: Int64
    let workCorrectionCount: Int64
    let calculationComponentCount: Int64
    let auditRevisionCount: Int64
    let workweekCount: Int64
    let weeklyAllocationCount: Int64
    let periodWindowCount: Int64
    let adoptionCount: Int64
    private enum CodingKeys: String, CodingKey {
        case profileCount, ruleSnapshotCount, ruleChangeCount, periodCount, workSnapshotCount,
            workEntryCount, paycheckReceiptCount, attachmentCount, unsupportedFinancialRecordKinds,
            unsupportedDraftKinds, omittedFinancialRecordCount, ruleTimelineCount, workBreakCount,
            workCorrectionCount, calculationComponentCount, auditRevisionCount, workweekCount,
            weeklyAllocationCount, periodWindowCount, adoptionCount
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(profileCount, forKey: .profileCount)
        try values.encode(ruleSnapshotCount, forKey: .ruleSnapshotCount)
        try values.encode(ruleChangeCount, forKey: .ruleChangeCount)
        try values.encode(periodCount, forKey: .periodCount)
        try values.encode(workSnapshotCount, forKey: .workSnapshotCount)
        try values.encode(workEntryCount, forKey: .workEntryCount)
        try values.encode(paycheckReceiptCount, forKey: .paycheckReceiptCount)
        try values.encode(attachmentCount, forKey: .attachmentCount)
        try values.encode(unsupportedFinancialRecordKinds, forKey: .unsupportedFinancialRecordKinds)
        try values.encode(unsupportedDraftKinds, forKey: .unsupportedDraftKinds)
        try values.encode(omittedFinancialRecordCount, forKey: .omittedFinancialRecordCount)
        try values.encode(ruleTimelineCount, forKey: .ruleTimelineCount)
        try values.encode(workBreakCount, forKey: .workBreakCount)
        try values.encode(workCorrectionCount, forKey: .workCorrectionCount)
        try values.encode(calculationComponentCount, forKey: .calculationComponentCount)
        try values.encode(auditRevisionCount, forKey: .auditRevisionCount)
        try values.encode(workweekCount, forKey: .workweekCount)
        try values.encode(weeklyAllocationCount, forKey: .weeklyAllocationCount)
        try values.encode(periodWindowCount, forKey: .periodWindowCount)
        try values.encode(adoptionCount, forKey: .adoptionCount)
    }
}

struct PortableIdentity: Codable, Hashable, Sendable {
    let entityType: String
    let portableID: String
    let originClient: String
    let originKind: String
    let originLocalID: String?
    private enum CodingKeys: String, CodingKey {
        case entityType, portableID, originClient, originKind, originLocalID
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(entityType, forKey: .entityType)
        try values.encode(portableID, forKey: .portableID)
        try values.encode(originClient, forKey: .originClient)
        try values.encode(originKind, forKey: .originKind)
        try values.encode(originLocalID, forKey: .originLocalID)
    }
}

struct PortableProfile: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let timeZone: String?
    let cadence: String?
    let cycleStartDate: String?
    let customEndDate: String?
    let ruleRef: String
    let baselineRuleRef: String?
    let ruleChangeRefs: [String]
    let currentPeriodRef: String?
    let currentWorkSnapshotRef: String?
    let fieldsNotRecorded: [String]
    let adoptedFromProfileRef: String?
    private enum CodingKeys: String, CodingKey {
        case id, name, timeZone, cadence, cycleStartDate, customEndDate, ruleRef, baselineRuleRef,
            ruleChangeRefs, currentPeriodRef, currentWorkSnapshotRef, fieldsNotRecorded,
            adoptedFromProfileRef
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(cadence, forKey: .cadence)
        try values.encode(cycleStartDate, forKey: .cycleStartDate)
        try values.encode(customEndDate, forKey: .customEndDate)
        try values.encode(ruleRef, forKey: .ruleRef)
        try values.encode(baselineRuleRef, forKey: .baselineRuleRef)
        try values.encode(ruleChangeRefs, forKey: .ruleChangeRefs)
        try values.encode(currentPeriodRef, forKey: .currentPeriodRef)
        try values.encode(currentWorkSnapshotRef, forKey: .currentWorkSnapshotRef)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(adoptedFromProfileRef, forKey: .adoptedFromProfileRef)
    }
}

struct PortableRounding: Codable, Hashable, Sendable {
    let scope: String
    let scale: Int64
    let mode: String
    private enum CodingKeys: String, CodingKey { case scope, scale, mode }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(scope, forKey: .scope)
        try values.encode(scale, forKey: .scale)
        try values.encode(mode, forKey: .mode)
    }
}

struct PortableSourceLocator: Codable, Hashable, Sendable {
    let title: String
    let url: String
    let section: String?
    let verifiedEpochSeconds: Int64?
    let ruleKey: String?
    let documentRef: String?
    let documentSHA256: String?
    let documentPage: Int64?
    let quotedText: String?
    private enum CodingKeys: String, CodingKey {
        case title, url, section, verifiedEpochSeconds, ruleKey, documentRef, documentSHA256,
            documentPage, quotedText
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(title, forKey: .title)
        try values.encode(url, forKey: .url)
        try values.encode(section, forKey: .section)
        try values.encode(verifiedEpochSeconds, forKey: .verifiedEpochSeconds)
        try values.encode(ruleKey, forKey: .ruleKey)
        try values.encode(documentRef, forKey: .documentRef)
        try values.encode(documentSHA256, forKey: .documentSHA256)
        try values.encode(documentPage, forKey: .documentPage)
        try values.encode(quotedText, forKey: .quotedText)
    }
}

struct PortableScheduleWindow: Codable, Hashable, Sendable {
    let weekday: String
    let start: String
    let end: String
    private enum CodingKeys: String, CodingKey { case weekday, start, end }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weekday, forKey: .weekday)
        try values.encode(start, forKey: .start)
        try values.encode(end, forKey: .end)
    }
}

struct PortableDatePremium: Codable, Hashable, Sendable {
    let date: String
    let multiplier: String
    private enum CodingKeys: String, CodingKey { case date, multiplier }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(date, forKey: .date)
        try values.encode(multiplier, forKey: .multiplier)
    }
}

struct PortableWeekdayPremium: Codable, Hashable, Sendable {
    let weekday: String
    let multiplier: String
    private enum CodingKeys: String, CodingKey { case weekday, multiplier }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weekday, forKey: .weekday)
        try values.encode(multiplier, forKey: .multiplier)
    }
}

struct PortableDailyTier: Codable, Hashable, Sendable {
    let afterHours: String
    let multiplier: String
    private enum CodingKeys: String, CodingKey { case afterHours, multiplier }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(afterHours, forKey: .afterHours)
        try values.encode(multiplier, forKey: .multiplier)
    }
}

struct PortableWeeklyRule: Codable, Hashable, Sendable {
    let workweekStart: String
    let thresholdHours: String
    let applicability: String
    private enum CodingKeys: String, CodingKey { case workweekStart, thresholdHours, applicability }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(workweekStart, forKey: .workweekStart)
        try values.encode(thresholdHours, forKey: .thresholdHours)
        try values.encode(applicability, forKey: .applicability)
    }
}

struct PortableRuleSnapshot: Codable, Hashable, Sendable {
    let id: String
    let ruleID: String
    let version: String
    let displayName: String?
    let effectiveStartDate: String?
    let effectiveEndDateInclusive: String?
    let currency: String
    let hourlyRate: String
    let regularSchedule: [PortableScheduleWindow]?
    let dailyOvertimeTiers: [PortableDailyTier]?
    let outsideScheduleMultiplier: String?
    let weekdayPremiums: [PortableWeekdayPremium]?
    let datePremiums: [PortableDatePremium]?
    let calloutMinimumHours: String?
    let perDiemPerWorkDate: PortableMoney?
    let weeklyOvertime: PortableWeeklyRule?
    let rounding: PortableRounding?
    let sources: [PortableSourceLocator]?
    let unsupportedRuleNotes: String?
    let confirmedAtEpochSeconds: Int64?
    let fieldsNotRecorded: [String]
    let confirmedByWorker: Bool?
    private enum CodingKeys: String, CodingKey {
        case id, ruleID, version, displayName, effectiveStartDate, effectiveEndDateInclusive,
            currency, hourlyRate, regularSchedule, dailyOvertimeTiers, outsideScheduleMultiplier,
            weekdayPremiums, datePremiums, calloutMinimumHours, perDiemPerWorkDate, weeklyOvertime,
            rounding, sources, unsupportedRuleNotes, confirmedAtEpochSeconds, fieldsNotRecorded,
            confirmedByWorker
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(ruleID, forKey: .ruleID)
        try values.encode(version, forKey: .version)
        try values.encode(displayName, forKey: .displayName)
        try values.encode(effectiveStartDate, forKey: .effectiveStartDate)
        try values.encode(effectiveEndDateInclusive, forKey: .effectiveEndDateInclusive)
        try values.encode(currency, forKey: .currency)
        try values.encode(hourlyRate, forKey: .hourlyRate)
        try values.encode(regularSchedule, forKey: .regularSchedule)
        try values.encode(dailyOvertimeTiers, forKey: .dailyOvertimeTiers)
        try values.encode(outsideScheduleMultiplier, forKey: .outsideScheduleMultiplier)
        try values.encode(weekdayPremiums, forKey: .weekdayPremiums)
        try values.encode(datePremiums, forKey: .datePremiums)
        try values.encode(calloutMinimumHours, forKey: .calloutMinimumHours)
        try values.encode(perDiemPerWorkDate, forKey: .perDiemPerWorkDate)
        try values.encode(weeklyOvertime, forKey: .weeklyOvertime)
        try values.encode(rounding, forKey: .rounding)
        try values.encode(sources, forKey: .sources)
        try values.encode(unsupportedRuleNotes, forKey: .unsupportedRuleNotes)
        try values.encode(confirmedAtEpochSeconds, forKey: .confirmedAtEpochSeconds)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(confirmedByWorker, forKey: .confirmedByWorker)
    }
}

struct PortableRuleChange: Codable, Hashable, Sendable {
    let id: String
    let profileRef: String?
    let periodRef: String?
    let effectiveDate: String
    let sourceProfileRef: String?
    let ruleRef: String
    let confirmed: Bool?
    let createdAtEpochSeconds: Int64?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, profileRef, periodRef, effectiveDate, sourceProfileRef, ruleRef, confirmed,
            createdAtEpochSeconds, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(profileRef, forKey: .profileRef)
        try values.encode(periodRef, forKey: .periodRef)
        try values.encode(effectiveDate, forKey: .effectiveDate)
        try values.encode(sourceProfileRef, forKey: .sourceProfileRef)
        try values.encode(ruleRef, forKey: .ruleRef)
        try values.encode(confirmed, forKey: .confirmed)
        try values.encode(createdAtEpochSeconds, forKey: .createdAtEpochSeconds)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableCalendarWindow: Codable, Hashable, Sendable {
    let startDate: String?
    let endDateInclusive: String?
    let endExclusiveDate: String?
    let timeZone: String?
    let boundaryModel: String
    let startEpochSeconds: Int64?
    let endExclusiveEpochSeconds: Int64?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case startDate, endDateInclusive, endExclusiveDate, timeZone, boundaryModel,
            startEpochSeconds, endExclusiveEpochSeconds, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(startDate, forKey: .startDate)
        try values.encode(endDateInclusive, forKey: .endDateInclusive)
        try values.encode(endExclusiveDate, forKey: .endExclusiveDate)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(boundaryModel, forKey: .boundaryModel)
        try values.encode(startEpochSeconds, forKey: .startEpochSeconds)
        try values.encode(endExclusiveEpochSeconds, forKey: .endExclusiveEpochSeconds)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortablePeriod: Codable, Hashable, Sendable {
    let id: String
    let profileRef: String?
    let calendarWindow: PortableCalendarWindow
    let cadence: String?
    let isCurrent: Bool?
    let closed: Bool?
    let archivedAtEpochSeconds: Int64?
    let calculationIssue: String?
    let ruleRef: String?
    let ruleChangeRefs: [String]
    let currentWorkSnapshotRef: String?
    let workSnapshotRefs: [String]
    let workCorrections: [PortableWorkCorrection]
    let fieldsNotRecorded: [String]
    let windowRef: String
    let ruleTimelineRefs: [String]
    let calculation: PortableCalculation?
    let auditCompletedAtEpochSeconds: Int64?
    let workRevision: Int64?
    private enum CodingKeys: String, CodingKey {
        case id, profileRef, calendarWindow, cadence, isCurrent, closed, archivedAtEpochSeconds,
            calculationIssue, ruleRef, ruleChangeRefs, currentWorkSnapshotRef, workSnapshotRefs,
            workCorrections, fieldsNotRecorded, windowRef, ruleTimelineRefs, calculation,
            auditCompletedAtEpochSeconds, workRevision
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(profileRef, forKey: .profileRef)
        try values.encode(calendarWindow, forKey: .calendarWindow)
        try values.encode(cadence, forKey: .cadence)
        try values.encode(isCurrent, forKey: .isCurrent)
        try values.encode(closed, forKey: .closed)
        try values.encode(archivedAtEpochSeconds, forKey: .archivedAtEpochSeconds)
        try values.encode(calculationIssue, forKey: .calculationIssue)
        try values.encode(ruleRef, forKey: .ruleRef)
        try values.encode(ruleChangeRefs, forKey: .ruleChangeRefs)
        try values.encode(currentWorkSnapshotRef, forKey: .currentWorkSnapshotRef)
        try values.encode(workSnapshotRefs, forKey: .workSnapshotRefs)
        try values.encode(workCorrections, forKey: .workCorrections)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(windowRef, forKey: .windowRef)
        try values.encode(ruleTimelineRefs, forKey: .ruleTimelineRefs)
        try values.encode(calculation, forKey: .calculation)
        try values.encode(auditCompletedAtEpochSeconds, forKey: .auditCompletedAtEpochSeconds)
        try values.encode(workRevision, forKey: .workRevision)
    }
}

struct PortableWorkCorrection: Codable, Hashable, Sendable {
    let id: String
    let workSnapshotRef: String
    let reason: String
    let correctedAtEpochSeconds: Int64
    private enum CodingKeys: String, CodingKey {
        case id, workSnapshotRef, reason, correctedAtEpochSeconds
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(workSnapshotRef, forKey: .workSnapshotRef)
        try values.encode(reason, forKey: .reason)
        try values.encode(correctedAtEpochSeconds, forKey: .correctedAtEpochSeconds)
    }
}

struct PortableWorkSnapshot: Codable, Hashable, Sendable {
    let id: String
    let profileRef: String
    let periodRef: String?
    let role: String
    let revision: Int64?
    let sourceRef: String?
    let work: [PortableWorkEntry]
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, profileRef, periodRef, role, revision, sourceRef, work, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(profileRef, forKey: .profileRef)
        try values.encode(periodRef, forKey: .periodRef)
        try values.encode(role, forKey: .role)
        try values.encode(revision, forKey: .revision)
        try values.encode(sourceRef, forKey: .sourceRef)
        try values.encode(work, forKey: .work)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableWorkEntry: Codable, Hashable, Sendable {
    let id: String
    let startEpochSeconds: Int64
    let endEpochSeconds: Int64
    let timeZone: String
    let kind: String
    let calloutEventRef: String?
    let unpaidBreaks: [PortableWorkBreak]
    let note: String?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, startEpochSeconds, endEpochSeconds, timeZone, kind, calloutEventRef, unpaidBreaks,
            note, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(startEpochSeconds, forKey: .startEpochSeconds)
        try values.encode(endEpochSeconds, forKey: .endEpochSeconds)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(kind, forKey: .kind)
        try values.encode(calloutEventRef, forKey: .calloutEventRef)
        try values.encode(unpaidBreaks, forKey: .unpaidBreaks)
        try values.encode(note, forKey: .note)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableWorkBreak: Codable, Hashable, Sendable {
    let id: String
    let startEpochSeconds: Int64
    let endEpochSeconds: Int64
    private enum CodingKeys: String, CodingKey { case id, startEpochSeconds, endEpochSeconds }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(startEpochSeconds, forKey: .startEpochSeconds)
        try values.encode(endEpochSeconds, forKey: .endEpochSeconds)
    }
}

struct PortableMoney: Codable, Hashable, Sendable {
    let amount: String
    let currency: String
    private enum CodingKeys: String, CodingKey { case amount, currency }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(amount, forKey: .amount)
        try values.encode(currency, forKey: .currency)
    }
}

struct PortablePaycheckReceipt: Codable, Hashable, Sendable {
    let receiptKind: String
    let id: String
    let periodRef: String?
    let workSnapshotRef: String
    let createdAtEpochSeconds: Int64
    let supersedesReceiptRef: String?
    let producer: PortableProducer
    let ruleRefs: [String]
    let sourcePeriod: PortableSourcePeriod?
    let paystubFacts: PortablePaystubFacts
    let lineFacts: PortableLineFacts
    let reviewFacts: PortableReviewFacts
    let calculation: PortableCalculation?
    let assessment: PortableAssessment
    let reconciliation: PortableReconciliation?
    let attachmentRefs: [String]
    let fieldsNotRecorded: [String]
    let auditRevisionRef: String?
    let targetWindowRef: String
    let targetWindow: PortableCalendarWindow
    let targetCadence: String?
    let targetRuleChangeRefs: [String]
    private enum CodingKeys: String, CodingKey {
        case receiptKind, id, periodRef, workSnapshotRef, createdAtEpochSeconds,
            supersedesReceiptRef, producer, ruleRefs, sourcePeriod, paystubFacts, lineFacts,
            reviewFacts, calculation, assessment, reconciliation, attachmentRefs, fieldsNotRecorded,
            auditRevisionRef, targetWindowRef, targetWindow, targetCadence, targetRuleChangeRefs
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(receiptKind, forKey: .receiptKind)
        try values.encode(id, forKey: .id)
        try values.encode(periodRef, forKey: .periodRef)
        try values.encode(workSnapshotRef, forKey: .workSnapshotRef)
        try values.encode(createdAtEpochSeconds, forKey: .createdAtEpochSeconds)
        try values.encode(supersedesReceiptRef, forKey: .supersedesReceiptRef)
        try values.encode(producer, forKey: .producer)
        try values.encode(ruleRefs, forKey: .ruleRefs)
        try values.encode(sourcePeriod, forKey: .sourcePeriod)
        try values.encode(paystubFacts, forKey: .paystubFacts)
        try values.encode(lineFacts, forKey: .lineFacts)
        try values.encode(reviewFacts, forKey: .reviewFacts)
        try values.encode(calculation, forKey: .calculation)
        try values.encode(assessment, forKey: .assessment)
        try values.encode(reconciliation, forKey: .reconciliation)
        try values.encode(attachmentRefs, forKey: .attachmentRefs)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(auditRevisionRef, forKey: .auditRevisionRef)
        try values.encode(targetWindowRef, forKey: .targetWindowRef)
        try values.encode(targetWindow, forKey: .targetWindow)
        try values.encode(targetCadence, forKey: .targetCadence)
        try values.encode(targetRuleChangeRefs, forKey: .targetRuleChangeRefs)
    }
}

struct PortableProducer: Codable, Hashable, Sendable {
    let client: String
    let localStateSchema: Int64?
    let calculationEngineID: String?
    let calculationEngineVersion: PortableVersion?
    let assessmentEngineID: String?
    let assessmentEngineVersion: PortableVersion?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case client, localStateSchema, calculationEngineID, calculationEngineVersion,
            assessmentEngineID, assessmentEngineVersion, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(client, forKey: .client)
        try values.encode(localStateSchema, forKey: .localStateSchema)
        try values.encode(calculationEngineID, forKey: .calculationEngineID)
        try values.encode(calculationEngineVersion, forKey: .calculationEngineVersion)
        try values.encode(assessmentEngineID, forKey: .assessmentEngineID)
        try values.encode(assessmentEngineVersion, forKey: .assessmentEngineVersion)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortablePaystubFacts: Codable, Hashable, Sendable {
    let id: String
    let periodStartDate: String?
    let periodEndDateInclusive: String?
    let currency: String
    let grossPay: String
    let regularHours: String?
    let regularPay: String?
    let overtimeHours: String?
    let overtimePay: String?
    let doubleTimeHours: String?
    let doubleTimePay: String?
    let calloutPay: String?
    let perDiemPay: String?
    let notes: String?
    let confirmedAtEpochSeconds: Int64?
    let evidenceRef: String?
    let fieldsNotRecorded: [String]
    let confirmed: Bool?
    private enum CodingKeys: String, CodingKey {
        case id, periodStartDate, periodEndDateInclusive, currency, grossPay, regularHours,
            regularPay, overtimeHours, overtimePay, doubleTimeHours, doubleTimePay, calloutPay,
            perDiemPay, notes, confirmedAtEpochSeconds, evidenceRef, fieldsNotRecorded, confirmed
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(periodStartDate, forKey: .periodStartDate)
        try values.encode(periodEndDateInclusive, forKey: .periodEndDateInclusive)
        try values.encode(currency, forKey: .currency)
        try values.encode(grossPay, forKey: .grossPay)
        try values.encode(regularHours, forKey: .regularHours)
        try values.encode(regularPay, forKey: .regularPay)
        try values.encode(overtimeHours, forKey: .overtimeHours)
        try values.encode(overtimePay, forKey: .overtimePay)
        try values.encode(doubleTimeHours, forKey: .doubleTimeHours)
        try values.encode(doubleTimePay, forKey: .doubleTimePay)
        try values.encode(calloutPay, forKey: .calloutPay)
        try values.encode(perDiemPay, forKey: .perDiemPay)
        try values.encode(notes, forKey: .notes)
        try values.encode(confirmedAtEpochSeconds, forKey: .confirmedAtEpochSeconds)
        try values.encode(evidenceRef, forKey: .evidenceRef)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(confirmed, forKey: .confirmed)
    }
}

struct PortableLineFacts: Codable, Hashable, Sendable {
    let grossBasis: String?
    let lineLayout: String?
    let hoursBasis: String?
    let guaranteeLayout: String?
    let amounts: [PortableLineAmount]?
    let hours: [PortableLineHours]?
    let reviewedFields: [String]?
    let suggestions: [PortableOcrSuggestion]?
    let hasAdditionalUnmappedPay: Bool?
    let workComplete: Bool?
    let earningsLinesComplete: Bool?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case grossBasis, lineLayout, hoursBasis, guaranteeLayout, amounts, hours, reviewedFields,
            suggestions, hasAdditionalUnmappedPay, workComplete, earningsLinesComplete,
            fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(grossBasis, forKey: .grossBasis)
        try values.encode(lineLayout, forKey: .lineLayout)
        try values.encode(hoursBasis, forKey: .hoursBasis)
        try values.encode(guaranteeLayout, forKey: .guaranteeLayout)
        try values.encode(amounts, forKey: .amounts)
        try values.encode(hours, forKey: .hours)
        try values.encode(reviewedFields, forKey: .reviewedFields)
        try values.encode(suggestions, forKey: .suggestions)
        try values.encode(hasAdditionalUnmappedPay, forKey: .hasAdditionalUnmappedPay)
        try values.encode(workComplete, forKey: .workComplete)
        try values.encode(earningsLinesComplete, forKey: .earningsLinesComplete)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableLineAmount: Codable, Hashable, Sendable {
    let field: String
    let amount: PortableMoney
    private enum CodingKeys: String, CodingKey { case field, amount }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(field, forKey: .field)
        try values.encode(amount, forKey: .amount)
    }
}

struct PortableLineHours: Codable, Hashable, Sendable {
    let field: String
    let hours: String
    private enum CodingKeys: String, CodingKey { case field, hours }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(field, forKey: .field)
        try values.encode(hours, forKey: .hours)
    }
}

struct PortableOcrSuggestion: Codable, Hashable, Sendable {
    let field: String
    let value: String?
    let sourceText: String
    let region: PortableSourceRegion?
    let confidence: String
    let reason: String?
    private enum CodingKeys: String, CodingKey {
        case field, value, sourceText, region, confidence, reason
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(field, forKey: .field)
        try values.encode(value, forKey: .value)
        try values.encode(sourceText, forKey: .sourceText)
        try values.encode(region, forKey: .region)
        try values.encode(confidence, forKey: .confidence)
        try values.encode(reason, forKey: .reason)
    }
}

struct PortableSourceRegion: Codable, Hashable, Sendable {
    let x: String
    let y: String
    let width: String
    let height: String
    let page: Int64?
    private enum CodingKeys: String, CodingKey { case x, y, width, height, page }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(x, forKey: .x)
        try values.encode(y, forKey: .y)
        try values.encode(width, forKey: .width)
        try values.encode(height, forKey: .height)
        try values.encode(page, forKey: .page)
    }
}

struct PortableReviewFacts: Codable, Hashable, Sendable {
    let completeWorkConfirmed: Bool?
    let ruleCoverageConfirmed: Bool?
    let unreviewedFields: Bool?
    let weeklyReviewPending: Bool?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case completeWorkConfirmed, ruleCoverageConfirmed, unreviewedFields, weeklyReviewPending,
            fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(completeWorkConfirmed, forKey: .completeWorkConfirmed)
        try values.encode(ruleCoverageConfirmed, forKey: .ruleCoverageConfirmed)
        try values.encode(unreviewedFields, forKey: .unreviewedFields)
        try values.encode(weeklyReviewPending, forKey: .weeklyReviewPending)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableCalculation: Codable, Hashable, Sendable {
    let agreementID: String?
    let agreementVersion: String?
    let primaryRuleRef: String?
    let agreementSnapshotRefs: [String]
    let currency: String
    let total: PortableMoney?
    let provenance: PortableCalculationProvenance?
    let weeklyRegularRate: PortableWeeklyResult?
    let components: [PortableComponent]
    let fieldsNotRecorded: [String]
    let engine: String?
    let coverage: String?
    let wages: PortableMoney?
    let allowances: PortableMoney?
    let ruleTimelineRef: String?
    let ruleChangeRefs: [String]
    private enum CodingKeys: String, CodingKey {
        case agreementID, agreementVersion, primaryRuleRef, agreementSnapshotRefs, currency, total,
            provenance, weeklyRegularRate, components, fieldsNotRecorded, engine, coverage, wages,
            allowances, ruleTimelineRef, ruleChangeRefs
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(agreementID, forKey: .agreementID)
        try values.encode(agreementVersion, forKey: .agreementVersion)
        try values.encode(primaryRuleRef, forKey: .primaryRuleRef)
        try values.encode(agreementSnapshotRefs, forKey: .agreementSnapshotRefs)
        try values.encode(currency, forKey: .currency)
        try values.encode(total, forKey: .total)
        try values.encode(provenance, forKey: .provenance)
        try values.encode(weeklyRegularRate, forKey: .weeklyRegularRate)
        try values.encode(components, forKey: .components)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(engine, forKey: .engine)
        try values.encode(coverage, forKey: .coverage)
        try values.encode(wages, forKey: .wages)
        try values.encode(allowances, forKey: .allowances)
        try values.encode(ruleTimelineRef, forKey: .ruleTimelineRef)
        try values.encode(ruleChangeRefs, forKey: .ruleChangeRefs)
    }
}

struct PortableCalculationProvenance: Codable, Hashable, Sendable {
    let engine: String
    let rounding: String
    let callout: String
    private enum CodingKeys: String, CodingKey { case engine, rounding, callout }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(engine, forKey: .engine)
        try values.encode(rounding, forKey: .rounding)
        try values.encode(callout, forKey: .callout)
    }
}

struct PortableComponent: Codable, Hashable, Sendable {
    let id: String
    let category: String
    let workRef: String?
    let localDate: String
    let hours: String?
    let workedSeconds: String?
    let multiplier: String?
    let amount: PortableMoney
    let explanation: String
    let ruleKeys: [String]?
    let baseRate: PortableMoney?
    let appliedAgreement: PortableAgreementReference?
    let unroundedAmount: PortableMoney?
    let baseTimeNumerator: String?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, category, workRef, localDate, hours, workedSeconds, multiplier, amount,
            explanation, ruleKeys, baseRate, appliedAgreement, unroundedAmount, baseTimeNumerator,
            fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(category, forKey: .category)
        try values.encode(workRef, forKey: .workRef)
        try values.encode(localDate, forKey: .localDate)
        try values.encode(hours, forKey: .hours)
        try values.encode(workedSeconds, forKey: .workedSeconds)
        try values.encode(multiplier, forKey: .multiplier)
        try values.encode(amount, forKey: .amount)
        try values.encode(explanation, forKey: .explanation)
        try values.encode(ruleKeys, forKey: .ruleKeys)
        try values.encode(baseRate, forKey: .baseRate)
        try values.encode(appliedAgreement, forKey: .appliedAgreement)
        try values.encode(unroundedAmount, forKey: .unroundedAmount)
        try values.encode(baseTimeNumerator, forKey: .baseTimeNumerator)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableAgreementReference: Codable, Hashable, Sendable {
    let ruleRef: String
    let ruleID: String
    let version: String
    let hourlyRate: PortableMoney?
    private enum CodingKeys: String, CodingKey { case ruleRef, ruleID, version, hourlyRate }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(ruleRef, forKey: .ruleRef)
        try values.encode(ruleID, forKey: .ruleID)
        try values.encode(version, forKey: .version)
        try values.encode(hourlyRate, forKey: .hourlyRate)
    }
}

struct PortableWeeklyResult: Codable, Hashable, Sendable {
    let workweekID: String
    let weekStart: String
    let workweekStart: String
    let qualifyingHours: String
    let includableRemuneration: PortableMoney
    let regularRate: PortableMoney?
    let overtimeHours: String
    let statutoryAdditionalPremium: PortableMoney
    let eligibleExtraPremiumCredit: PortableMoney
    let remainingAdditionalPremium: PortableMoney
    let cashRemuneration: PortableMoney
    let expectedCash: PortableMoney
    let allocations: [PortableWeeklyAllocation]
    let engineVersion: String
    let startEpochSeconds: Int64?
    let endEpochSeconds: Int64?
    let timeZone: String?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case workweekID, weekStart, workweekStart, qualifyingHours, includableRemuneration,
            regularRate, overtimeHours, statutoryAdditionalPremium, eligibleExtraPremiumCredit,
            remainingAdditionalPremium, cashRemuneration, expectedCash, allocations, engineVersion,
            startEpochSeconds, endEpochSeconds, timeZone, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(workweekID, forKey: .workweekID)
        try values.encode(weekStart, forKey: .weekStart)
        try values.encode(workweekStart, forKey: .workweekStart)
        try values.encode(qualifyingHours, forKey: .qualifyingHours)
        try values.encode(includableRemuneration, forKey: .includableRemuneration)
        try values.encode(regularRate, forKey: .regularRate)
        try values.encode(overtimeHours, forKey: .overtimeHours)
        try values.encode(statutoryAdditionalPremium, forKey: .statutoryAdditionalPremium)
        try values.encode(eligibleExtraPremiumCredit, forKey: .eligibleExtraPremiumCredit)
        try values.encode(remainingAdditionalPremium, forKey: .remainingAdditionalPremium)
        try values.encode(cashRemuneration, forKey: .cashRemuneration)
        try values.encode(expectedCash, forKey: .expectedCash)
        try values.encode(allocations, forKey: .allocations)
        try values.encode(engineVersion, forKey: .engineVersion)
        try values.encode(startEpochSeconds, forKey: .startEpochSeconds)
        try values.encode(endEpochSeconds, forKey: .endEpochSeconds)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableWeeklyAllocation: Codable, Hashable, Sendable {
    let id: String
    let periodRef: String?
    let amount: PortableMoney
    let basis: PortableMoney
    private enum CodingKeys: String, CodingKey { case id, periodRef, amount, basis }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(periodRef, forKey: .periodRef)
        try values.encode(amount, forKey: .amount)
        try values.encode(basis, forKey: .basis)
    }
}

struct PortableAssessment: Codable, Hashable, Sendable {
    let engineID: String?
    let engineVersion: PortableVersion?
    let verdict: String
    let scope: String
    let expectedGross: PortableMoney?
    let paidGross: PortableMoney
    let difference: PortableMoney?
    let comparisons: [PortableComparison]
    let reviewReasons: [String]
    let scopeNotes: [String]?
    let weeklyContextCount: Int64?
    let weeklyReviewRefs: [String]?
    let fieldsNotRecorded: [String]
    let periodMatch: String?
    let reportedPeriod: PortableSourcePeriod?
    private enum CodingKeys: String, CodingKey {
        case engineID, engineVersion, verdict, scope, expectedGross, paidGross, difference,
            comparisons, reviewReasons, scopeNotes, weeklyContextCount, weeklyReviewRefs,
            fieldsNotRecorded, periodMatch, reportedPeriod
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(engineID, forKey: .engineID)
        try values.encode(engineVersion, forKey: .engineVersion)
        try values.encode(verdict, forKey: .verdict)
        try values.encode(scope, forKey: .scope)
        try values.encode(expectedGross, forKey: .expectedGross)
        try values.encode(paidGross, forKey: .paidGross)
        try values.encode(difference, forKey: .difference)
        try values.encode(comparisons, forKey: .comparisons)
        try values.encode(reviewReasons, forKey: .reviewReasons)
        try values.encode(scopeNotes, forKey: .scopeNotes)
        try values.encode(weeklyContextCount, forKey: .weeklyContextCount)
        try values.encode(weeklyReviewRefs, forKey: .weeklyReviewRefs)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
        try values.encode(periodMatch, forKey: .periodMatch)
        try values.encode(reportedPeriod, forKey: .reportedPeriod)
    }
}

struct PortableComparison: Codable, Hashable, Sendable {
    let id: String
    let field: String
    let expected: String
    let paid: String
    let difference: String
    let unit: String
    let currency: String
    let componentRefs: [String]
    private enum CodingKeys: String, CodingKey {
        case id, field, expected, paid, difference, unit, currency, componentRefs
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(field, forKey: .field)
        try values.encode(expected, forKey: .expected)
        try values.encode(paid, forKey: .paid)
        try values.encode(difference, forKey: .difference)
        try values.encode(unit, forKey: .unit)
        try values.encode(currency, forKey: .currency)
        try values.encode(componentRefs, forKey: .componentRefs)
    }
}

struct PortableReconciliation: Codable, Hashable, Sendable {
    let expectedGross: PortableMoney
    let actualGross: PortableMoney
    let difference: PortableMoney
    let direction: String
    private enum CodingKeys: String, CodingKey {
        case expectedGross, actualGross, difference, direction
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(expectedGross, forKey: .expectedGross)
        try values.encode(actualGross, forKey: .actualGross)
        try values.encode(difference, forKey: .difference)
        try values.encode(direction, forKey: .direction)
    }
}

struct PortableAttachment: Codable, Hashable, Sendable {
    let id: String
    let kind: String
    let originalFilename: String
    let mediaType: String
    let sourceKind: String?
    let createdAtEpochSeconds: Int64?
    let recognizedText: String?
    let sha256: String
    let byteLength: Int64
    var bytesBase64: String
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, kind, originalFilename, mediaType, sourceKind, createdAtEpochSeconds,
            recognizedText, sha256, byteLength, bytesBase64, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(kind, forKey: .kind)
        try values.encode(originalFilename, forKey: .originalFilename)
        try values.encode(mediaType, forKey: .mediaType)
        try values.encode(sourceKind, forKey: .sourceKind)
        try values.encode(createdAtEpochSeconds, forKey: .createdAtEpochSeconds)
        try values.encode(recognizedText, forKey: .recognizedText)
        try values.encode(sha256, forKey: .sha256)
        try values.encode(byteLength, forKey: .byteLength)
        try values.encode(bytesBase64, forKey: .bytesBase64)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableRuleTimeline: Codable, Hashable, Sendable {
    let id: String
    let periodRef: String
    let baselineRuleRef: String?
    let ruleChangeRefs: [String]
    let createdAtEpochSeconds: Int64?
    let confirmed: Bool?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, periodRef, baselineRuleRef, ruleChangeRefs, createdAtEpochSeconds, confirmed,
            fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(periodRef, forKey: .periodRef)
        try values.encode(baselineRuleRef, forKey: .baselineRuleRef)
        try values.encode(ruleChangeRefs, forKey: .ruleChangeRefs)
        try values.encode(createdAtEpochSeconds, forKey: .createdAtEpochSeconds)
        try values.encode(confirmed, forKey: .confirmed)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableSourcePeriod: Codable, Hashable, Sendable {
    let startDate: String?
    let endDateInclusive: String?
    let timeZone: String?
    let confirmed: Bool?
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case startDate, endDateInclusive, timeZone, confirmed, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(startDate, forKey: .startDate)
        try values.encode(endDateInclusive, forKey: .endDateInclusive)
        try values.encode(timeZone, forKey: .timeZone)
        try values.encode(confirmed, forKey: .confirmed)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}

struct PortableProfileAdoption: Codable, Hashable, Sendable {
    let id: String
    let sourceProfileRef: String
    let adoptedProfileRef: String
    let sourcePeriodRef: String?
    let adoptedPeriodRef: String?
    let sourceWorkSnapshotRef: String?
    let adoptedWorkSnapshotRef: String?
    let sourceRuleRefs: [String]
    let adoptedRuleRefs: [String]
    let confirmedAtEpochSeconds: Int64
    let confirmedFields: [String]
    let fieldsNotRecorded: [String]
    private enum CodingKeys: String, CodingKey {
        case id, sourceProfileRef, adoptedProfileRef, sourcePeriodRef, adoptedPeriodRef,
            sourceWorkSnapshotRef, adoptedWorkSnapshotRef, sourceRuleRefs, adoptedRuleRefs,
            confirmedAtEpochSeconds, confirmedFields, fieldsNotRecorded
    }
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(sourceProfileRef, forKey: .sourceProfileRef)
        try values.encode(adoptedProfileRef, forKey: .adoptedProfileRef)
        try values.encode(sourcePeriodRef, forKey: .sourcePeriodRef)
        try values.encode(adoptedPeriodRef, forKey: .adoptedPeriodRef)
        try values.encode(sourceWorkSnapshotRef, forKey: .sourceWorkSnapshotRef)
        try values.encode(adoptedWorkSnapshotRef, forKey: .adoptedWorkSnapshotRef)
        try values.encode(sourceRuleRefs, forKey: .sourceRuleRefs)
        try values.encode(adoptedRuleRefs, forKey: .adoptedRuleRefs)
        try values.encode(confirmedAtEpochSeconds, forKey: .confirmedAtEpochSeconds)
        try values.encode(confirmedFields, forKey: .confirmedFields)
        try values.encode(fieldsNotRecorded, forKey: .fieldsNotRecorded)
    }
}
