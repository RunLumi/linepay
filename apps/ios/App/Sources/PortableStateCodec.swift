import CoreFoundation
import CryptoKit
import Foundation

/// Local-only typed interchange. This validates structure before any native state is allocated.
enum PortableStateCodec {
    static let format = "com.streamentry.linepay.portable-state"

    static func decode(_ data: Data) throws -> PortableState {
        guard data.count <= BackupArchive.maximumBytes - BackupEncryption.overheadBytes else {
            throw BackupError.tooLarge
        }
        try validateStructure(data)
        guard var financial = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.invalidArchive
        }
        financial.removeValue(forKey: "attachments")
        guard
            try JSONSerialization.data(withJSONObject: financial).count
                <= BackupArchive.maximumStateBytes
        else { throw BackupError.tooLarge }
        let result = try JSONDecoder().decode(PortableState.self, from: data)
        try preflight(result)
        return result
    }

    static func validateStructure(_ data: Data) throws {
        var keys = PortableJSONKeys(data)
        try keys.validate()
        let value = try JSONSerialization.jsonObject(with: data)
        guard
            let schemaURL = Bundle.main.url(
                forResource: "portable-state-schema-v1", withExtension: "json"),
            let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL))
                as? [String: Any]
        else { throw BackupError.invalidArchive }
        try validate(value, schema: schema, root: schema)
        try validateMissingMarkers(value)
    }

    static func encode(_ value: PortableState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        _ = try decode(data)
        return data
    }

    private static func validate(_ value: Any, schema: [String: Any], root: [String: Any]) throws {
        if let reference = schema["$ref"] as? String,
            let definitions = root["$defs"] as? [String: Any],
            let definition = definitions[String(reference.split(separator: "/").last ?? "")]
                as? [String: Any]
        {
            try validate(value, schema: definition, root: root)
            if reference == "#/$defs/sourceScalar" {
                guard let text = value as? String, let scalar = Double(text), scalar.isFinite,
                    (0...1).contains(scalar)
                else { throw BackupError.invalidArchive }
                if let exact = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
                    exact < 0 || exact > 1
                {
                    throw BackupError.invalidArchive
                }
            }
            return
        }
        if let choices = schema["anyOf"] as? [[String: Any]] {
            let applicable = choices.filter {
                ($0["type"] as? String == "null") == (value is NSNull)
            }
            guard let choice = applicable.first else { throw BackupError.invalidArchive }
            try validate(value, schema: choice, root: root)
            return
        }
        if let expected = schema["const"] {
            guard (value as? NSObject) == (expected as? NSObject) else {
                throw BackupError.invalidArchive
            }
        }
        if let options = schema["enum"] as? [String] {
            guard let text = value as? String, options.contains(text) else {
                throw BackupError.invalidArchive
            }
        }
        if let types = schema["type"] as? [String] {
            for type in types {
                var branch = schema
                branch["type"] = type
                if (try? validate(value, schema: branch, root: root)) != nil { return }
            }
            throw BackupError.invalidArchive
        }
        switch schema["type"] as? String {
        case "null": guard value is NSNull else { throw BackupError.invalidArchive }
        case "object":
            guard let object = value as? [String: Any],
                let properties = schema["properties"] as? [String: [String: Any]],
                Set(object.keys).isSubset(of: Set(properties.keys)),
                Set(schema["required"] as? [String] ?? []).isSubset(of: Set(object.keys))
            else { throw BackupError.invalidArchive }
            for (key, child) in object {
                do {
                    try validate(child, schema: properties[key]!, root: root)
                } catch PortableSchemaFailure.field(let path) {
                    throw PortableSchemaFailure.field(key + "." + path)
                } catch { throw PortableSchemaFailure.field(key) }
            }
        case "array":
            guard let items = value as? [Any],
                items.count <= (schema["maxItems"] as? Int ?? 100_000),
                items.count >= (schema["minItems"] as? Int ?? 0),
                let itemSchema = schema["items"] as? [String: Any]
            else { throw BackupError.invalidArchive }
            if schema["uniqueItems"] as? Bool == true {
                let encoded = try items.map {
                    try JSONSerialization.data(
                        withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys])
                }
                guard Set(encoded).count == encoded.count else { throw BackupError.invalidArchive }
            }
            for (index, item) in items.enumerated() {
                do {
                    try validate(item, schema: itemSchema, root: root)
                } catch PortableSchemaFailure.field(let path) {
                    throw PortableSchemaFailure.field("[\(index)]." + path)
                } catch { throw PortableSchemaFailure.field("[\(index)]") }
            }
        case "string":
            guard let text = value as? String,
                text.unicodeScalars.count <= (schema["maxLength"] as? Int ?? Int.max),
                text.unicodeScalars.count >= (schema["minLength"] as? Int ?? 0)
            else { throw BackupError.invalidArchive }
            if let pattern = schema["pattern"] as? String {
                guard
                    text.range(of: pattern, options: .regularExpression)
                        == (text.startIndex..<text.endIndex)
                else {
                    throw BackupError.invalidArchive
                }
            }
        case "integer":
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
                number.int64Value >= ((schema["minimum"] as? NSNumber)?.int64Value ?? Int64.min),
                number.int64Value <= ((schema["maximum"] as? NSNumber)?.int64Value ?? Int64.max)
            else { throw BackupError.invalidArchive }
        case "boolean":
            guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID()
            else { throw BackupError.invalidArchive }
        default: break
        }
    }

    private static func validateMissingMarkers(_ value: Any) throws {
        if let object = value as? [String: Any] {
            if let fields = object["fieldsNotRecorded"] as? [String] {
                for field in fields {
                    var resolved: Any = object
                    for component in field.split(separator: ".", omittingEmptySubsequences: false) {
                        guard !component.isEmpty else { throw BackupError.invalidArchive }
                        guard let child = (resolved as? [String: Any])?[String(component)] else {
                            throw BackupError.invalidArchive
                        }
                        resolved = child
                    }
                    let missing = resolved
                    guard field != "fieldsNotRecorded",
                        missing is NSNull
                    else { throw BackupError.invalidArchive }
                }
            }
            for child in object.values { try validateMissingMarkers(child) }
        } else if let array = value as? [Any] {
            for child in array { try validateMissingMarkers(child) }
        }
    }

    /// Every reference and every original is checked before the replacement preview is available.
    static func preflight(_ value: PortableState, validateOriginalBytes: Bool = true) throws {
        guard value.format == format, value.version == 1, value.profiles.count <= 100 else {
            throw BackupError.portableUnsupported(
                "This transfer exceeds the retained-profile limit.")
        }
        guard value.periods.filter({ $0.isCurrent == true }).count <= 1 else {
            throw BackupError.invalidArchive
        }
        try PortableFinancialValidation.validate(value)
        let inventory = value.sourceInventory
        guard inventory.profileCount == value.profiles.count,
            inventory.ruleSnapshotCount == value.ruleSnapshots.count,
            inventory.ruleChangeCount == value.ruleChanges.count,
            inventory.ruleTimelineCount == value.ruleTimelines.count,
            inventory.periodCount == value.periods.count,
            inventory.workSnapshotCount == value.workSnapshots.count,
            inventory.workEntryCount == value.workSnapshots.reduce(0, { $0 + $1.work.count }),
            inventory.paycheckReceiptCount == value.paycheckReceipts.count,
            inventory.attachmentCount == value.attachments.count,
            inventory.unsupportedFinancialRecordKinds.isEmpty,
            inventory.unsupportedDraftKinds.isEmpty,
            inventory.omittedFinancialRecordCount == 0
        else { throw BackupError.invalidArchive }
        let allIDs =
            value.profiles.map(\.id) + value.ruleSnapshots.map(\.id)
            + value.periods.map(\.id) + value.workSnapshots.map(\.id)
            + value.paycheckReceipts.map(\.id) + value.attachments.map(\.id)
        guard Set(allIDs).count == allIDs.count else { throw BackupError.invalidArchive }
        let profiles = Set(value.profiles.map(\.id))
        let rules = Set(value.ruleSnapshots.map(\.id))
        let periods = Dictionary(uniqueKeysWithValues: value.periods.map { ($0.id, $0) })
        let works = Dictionary(uniqueKeysWithValues: value.workSnapshots.map { ($0.id, $0) })
        let originals = Set(value.attachments.map(\.id))
        guard value.identityCrosswalk.count <= 100_000,
            Set(value.identityCrosswalk.map { $0.entityType + ":" + $0.portableID }).count
                == value.identityCrosswalk.count
        else { throw BackupError.invalidArchive }
        guard value.activeProfileRef.map(profiles.contains) ?? value.profiles.isEmpty else {
            throw BackupError.invalidArchive
        }
        var requiredIdentities = Set<String>()
        func require(_ kind: String, _ id: String) { requiredIdentities.insert(kind + ":" + id) }
        for item in value.profiles { require("profile", item.id) }
        for item in value.ruleSnapshots { require("ruleSnapshot", item.id) }
        for item in value.ruleChanges { require("ruleChange", item.id) }
        for item in value.ruleTimelines { require("ruleTimeline", item.id) }
        for item in value.periods {
            require("period", item.id)
            require("periodWindow", item.windowRef)
            for correction in item.workCorrections { require("workCorrection", correction.id) }
            for component in item.calculation?.components ?? [] {
                require("calculationComponent", component.id)
            }
        }
        for item in value.workSnapshots {
            require("workSnapshot", item.id)
            for work in item.work {
                require("workEntry", work.id)
                if let event = work.calloutEventRef { require("calloutEvent", event) }
                for rest in work.unpaidBreaks { require("workBreak", rest.id) }
            }
        }
        for item in value.paycheckReceipts {
            require("paycheckReceipt", item.id)
            require("paystub", item.paystubFacts.id)
            require("periodWindow", item.targetWindowRef)
            if let revision = item.auditRevisionRef { require("auditRevision", revision) }
            for component in item.calculation?.components ?? [] {
                require("calculationComponent", component.id)
            }
        }
        for item in value.attachments { require("attachment", item.id) }
        for item in value.adoptions { require("profileAdoption", item.id) }
        let calculations =
            value.periods.compactMap(\.calculation)
            + value.paycheckReceipts.compactMap(\.calculation)
        let weeklyResults = calculations.compactMap(\.weeklyRegularRate)
        for weekly in weeklyResults {
            require("workweek", weekly.workweekID)
            for allocation in weekly.allocations { require("weeklyAllocation", allocation.id) }
        }
        guard inventory.workweekCount == weeklyResults.count,
            inventory.weeklyAllocationCount
                == weeklyResults.reduce(0, { $0 + $1.allocations.count })
        else { throw BackupError.invalidArchive }
        for weekly in weeklyResults {
            let currency = weekly.expectedCash.currency
            let money =
                [
                    weekly.includableRemuneration, weekly.statutoryAdditionalPremium,
                    weekly.eligibleExtraPremiumCredit,
                    weekly.remainingAdditionalPremium, weekly.cashRemuneration, weekly.expectedCash,
                ] + [weekly.regularRate].compactMap { $0 }
            guard
                money.allSatisfy({
                    $0.currency == currency && PortableExactDecimal($0.amount)?.negative == false
                }),
                weekly.timeZone.map({ TimeZone(identifier: $0) != nil }) ?? true
            else { throw BackupError.invalidArchive }
            if let start = weekly.startEpochSeconds, let end = weekly.endEpochSeconds, end <= start
            {
                throw BackupError.invalidArchive
            }
            for allocation in weekly.allocations {
                guard allocation.periodRef.map({ periods[$0] != nil }) ?? true,
                    allocation.amount.currency == currency, allocation.basis.currency == currency,
                    PortableExactDecimal(allocation.amount.amount)?.negative == false,
                    PortableExactDecimal(allocation.basis.amount)?.negative == false
                else { throw BackupError.invalidArchive }
            }
        }
        let suppliedIdentities = Set(
            value.identityCrosswalk.map { $0.entityType + ":" + $0.portableID })
        guard requiredIdentities == suppliedIdentities,
            Set(value.identityCrosswalk.map(\.portableID)).count == value.identityCrosswalk.count,
            inventory.adoptionCount == value.adoptions.count
        else { throw BackupError.invalidArchive }
        let confirmedFieldNames: Set<String> = [
            "name", "timeZone", "cadence", "cycleStartDate", "customEndDate", "currency",
            "hourlyRate", "regularSchedule", "dailyOvertimeTiers", "outsideScheduleMultiplier",
            "weekdayPremiums", "datePremiums", "calloutMinimumHours", "perDiemPerWorkDate",
            "effectiveStartDate", "effectiveEndDateInclusive", "rounding",
            "weeklyOvertimeThreshold", "workweekStart", "currentWork", "periodWindow",
        ]
        guard Set(value.adoptions.map(\.adoptedProfileRef)).count == value.adoptions.count else {
            throw BackupError.invalidArchive
        }
        for adoption in value.adoptions {
            guard profiles.contains(adoption.sourceProfileRef),
                profiles.contains(adoption.adoptedProfileRef),
                adoption.sourceProfileRef != adoption.adoptedProfileRef,
                Set(adoption.confirmedFields).isSubset(of: confirmedFieldNames),
                value.profiles.first(where: { $0.id == adoption.adoptedProfileRef })?
                    .adoptedFromProfileRef == adoption.sourceProfileRef,
                adoption.sourcePeriodRef.map({ periods[$0] != nil }) ?? true,
                adoption.adoptedPeriodRef.map({ periods[$0] != nil }) ?? true,
                adoption.sourceWorkSnapshotRef.map({ works[$0] != nil }) ?? true,
                adoption.adoptedWorkSnapshotRef.map({ works[$0] != nil }) ?? true,
                adoption.sourceRuleRefs.allSatisfy(rules.contains),
                adoption.adoptedRuleRefs.allSatisfy(rules.contains)
            else { throw BackupError.invalidArchive }
        }
        for profile in value.profiles {
            guard rules.contains(profile.ruleRef),
                profile.currentPeriodRef.map({ periods[$0] != nil }) ?? true,
                profile.currentWorkSnapshotRef.map({ works[$0]?.profileRef == profile.id }) ?? true
            else { throw BackupError.invalidArchive }
        }
        for rule in value.ruleSnapshots {
            for source in rule.sources ?? [] {
                guard source.documentRef.map(originals.contains) ?? true else {
                    throw BackupError.missingEvidence
                }
            }

        }
        for period in value.periods {
            guard period.profileRef.map(profiles.contains) ?? true,
                period.ruleRef.map(rules.contains) ?? true,
                period.workSnapshotRefs.allSatisfy({ works[$0]?.periodRef == period.id })
            else { throw BackupError.invalidArchive }
        }
        for snapshot in value.workSnapshots {
            guard
                snapshot.periodRef.map({
                    periods[$0]?.workSnapshotRefs.contains(snapshot.id) == true
                }) ?? true,
                Set(snapshot.work.map(\.id)).count == snapshot.work.count
            else { throw BackupError.invalidArchive }
        }
        let receipts = Set(value.paycheckReceipts.map(\.id))
        for change in value.ruleChanges {
            guard change.profileRef.map(profiles.contains) ?? true, rules.contains(change.ruleRef),
                change.periodRef.map({ periods[$0] != nil }) ?? true
            else { throw BackupError.invalidArchive }
        }
        for receipt in value.paycheckReceipts {
            guard receipt.receiptKind == "paycheck-v1",
                receipt.periodRef.map({ periods[$0] != nil }) ?? true,
                works[receipt.workSnapshotRef]?.periodRef == receipt.periodRef,
                receipt.ruleRefs.allSatisfy(rules.contains),
                receipt.attachmentRefs.allSatisfy(originals.contains),
                receipt.supersedesReceiptRef.map(receipts.contains) ?? true,
                receipt.reviewFacts.weeklyReviewPending != true
                    || receipt.assessment.verdict != "matches"
            else { throw BackupError.invalidArchive }
        }
        for receipt in value.paycheckReceipts {
            let workIDs = Set(works[receipt.workSnapshotRef]?.work.map(\.id) ?? [])
            for component in receipt.calculation?.components ?? [] {
                guard component.workRef.map(workIDs.contains) ?? true,
                    component.appliedAgreement.map({ rules.contains($0.ruleRef) }) ?? true
                else { throw BackupError.invalidArchive }
            }
            let ownedComponents = Set(receipt.calculation?.components.map(\.id) ?? [])
            for comparison in receipt.assessment.comparisons {
                guard comparison.componentRefs.allSatisfy(ownedComponents.contains),
                    PortableExactDecimal.difference(
                        expected: comparison.expected, paid: comparison.paid,
                        equals: comparison.difference)
                else { throw BackupError.invalidArchive }
            }
        }
        var bytesTotal = 0
        for attachment in value.attachments where validateOriginalBytes {
            guard
                !attachment.originalFilename.contains("/")
                    && !attachment.originalFilename.contains("\\")
                    && !attachment.originalFilename.contains("\0")
                    && attachment.originalFilename != "." && attachment.originalFilename != "..",
                let bytes = Data(base64Encoded: attachment.bytesBase64),
                bytes.count == attachment.byteLength,
                bytes.count <= BackupArchive.maximumEvidenceBytes,
                SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined()
                    == attachment.sha256
            else { throw BackupError.invalidArchive }
            bytesTotal += bytes.count
            guard bytesTotal <= BackupArchive.maximumBytes else { throw BackupError.tooLarge }
        }
        // Native conversion performs stricter rule, work, boundary, identity and capability checks.
        _ = try PortableStateMapping.nativeState(value)
    }
}

/// Diagnostic paths contain field names and indices only, never financial values.
enum PortableSchemaFailure: Error { case field(String) }
