import Foundation
import LinePayDomain
import Testing

@testable import LinePay

@Suite("Portable financial state: fail closed before replacement")
@MainActor
struct PortableStateTests {
    @Test func schemaElevenAdmissionPreservesAllExistingFinancialFacts() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        try model.archiveCurrentPeriod()
        let original = try #require(store.state)
        var old = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        old["schemaVersion"] = 11
        old.removeValue(forKey: "portableFinancialState")
        old.removeValue(forKey: "portableIdentityCrosswalk")
        old.removeValue(forKey: "portableOriginals")
        let migrated = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(migrated.schemaVersion == 12)
        #expect(migrated.profile == original.profile)
        #expect(migrated.activePeriod == original.activePeriod)
        #expect(migrated.history == original.history)
        #expect(migrated.portableFinancialState == nil)
        #expect(migrated.portableIdentityCrosswalk.isEmpty)
        #expect(migrated.portableOriginals.isEmpty)
    }

    @Test func duplicateOrEscapedEquivalentKeysCannotHideConflictingFacts() throws {
        for text in [
            #"{"paid":"1","paid":"9"}"#, #"{"paid":"1","\u0070aid":"9"}"#,
            #"{"rows":[{"x":1,"x":2}]}"#, #"{"epoch":1.0000000000000000000001}"#, #"{"epoch":1e0}"#,
        ] {
            var scanner = PortableJSONKeys(Data(text.utf8))
            #expect(throws: (any Error).self) { try scanner.validate() }
        }
        var valid = PortableJSONKeys(Data(#"{"a":[{"paid":"1"},{"paid":"9"}]}"#.utf8))
        try valid.validate()
    }

    @Test func unsupportedSavedDraftRefusesWholeFileWithoutChangingState() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        var state = try #require(store.state)
        state.setupDraft = UnitFixture.profile()
        let original = state
        #expect(throws: (any Error).self) { try PortableStateMapping.inventory(state) }
        #expect(state == original)
    }

    @Test func ordinaryNativeGrossReceiptKeepsEveryOriginalCalculationTrace() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let original = try #require(store.state)
        let portable = try NativePortableStateWriter.export(original, files: [])
        #expect(portable.paycheckReceipts.count == 1)
        #expect(portable.paycheckReceipts.first?.calculation?.ruleChangeRefs == [])
        #expect(
            portable.paycheckReceipts.first?.calculation?.fieldsNotRecorded.contains(
                "ruleChangeRefs") == false)
        let receipt = try #require(portable.paycheckReceipts.first)
        let originalReceipt = try #require(original.activePeriod?.auditRevisions?.last)
        #expect(receipt.assessment.verdict == originalReceipt.paystub.assessment?.verdict.rawValue)
        #expect(
            receipt.assessment.reviewReasons == originalReceipt.paystub.assessment?.reviewReasons)
        #expect(receipt.assessment.scopeNotes == originalReceipt.paystub.assessment?.scopeNotes)
        #expect(
            receipt.calculation?.components.count == originalReceipt.calculation?.components.count)
        #expect(
            receipt.calculation?.components.first?.baseTimeNumerator
                == originalReceipt.calculation?.components.first?.baseTimeNumerator.map {
                    NSDecimalNumber(decimal: $0).stringValue
                })
        let archive = try PortableStateMapping.archive(portable)
        #expect(archive.workCount == portable.sourceInventory.workEntryCount)
        #expect(archive.state.activePeriod?.workEntries.count == 1)
        #expect(
            archive.state.portableFinancialState?.paycheckReceipts.first?.assessment
                == receipt.assessment)
        let reexported = try PortableStateMapping.export(archive.state, files: [])
        #expect(reexported == portable)
    }

    @Test func embeddedWeeklyResultPreservesTypedTraceWithoutAllocatingHistoricalPay() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let state = try #require(store.state)
        let period = try #require(state.activePeriod)
        let weekly = try WeeklyRegularRateCalculator().calculate(
            WeeklyRegularRateInput(
                weekStart: LocalDate(year: 2026, month: 9, day: 7), workweekStart: .monday,
                completeWorkweek: true, applicability: .coveredNonexemptHourly,
                work: [
                    WeeklyWorkFact(
                        payPeriodID: period.id, hours: 48,
                        straightRate: Money(amount: 50, currencyCode: "USD"))
                ],
                remuneration: [
                    WeeklyRemunerationFact(
                        amount: Money(amount: 2400, currencyCode: "USD"), kind: .straightTime)
                ]))
        let revision = try #require(period.auditRevisions?.first)
        let originalCalculation = try #require(revision.calculation)
        let calculation = CalculationResult(
            agreementID: originalCalculation.agreementID,
            agreementVersion: originalCalculation.agreementVersion,
            components: originalCalculation.components,
            total: originalCalculation.total,
            agreementSnapshots: originalCalculation.agreementSnapshots,
            provenance: originalCalculation.provenance, weeklyRegularRate: weekly)
        let assessment = try PaycheckAssessor().assess(
            calculation: calculation, agreement: period.agreement,
            facts: PaycheckFacts(
                hasCompleteWork: true, grossPay: revision.paystub.grossPay, grossBasis: .wagesOnly))
        let stub = ConfirmedPaystub(
            id: revision.paystub.id, payPeriodStart: revision.paystub.payPeriodStart,
            payPeriodEnd: revision.paystub.payPeriodEnd, grossPay: revision.paystub.grossPay,
            confirmedEpochSeconds: revision.paystub.confirmedEpochSeconds,
            confirmation: revision.paystub.confirmation, assessment: assessment)
        var frozenState = state
        var frozenPeriod = period
        frozenPeriod.paystub = stub
        frozenPeriod.auditRevisions = [
            AuditRevision(
                id: revision.id, window: revision.window,
                agreement: revision.agreement, timeZoneIdentifier: revision.timeZoneIdentifier,
                workEntries: revision.workEntries, calculation: calculation, paystub: stub,
                reconciliation: revision.reconciliation, agreementChanges: revision.agreementChanges
            )
        ]
        frozenState.activePeriod = frozenPeriod
        let portable = try NativePortableStateWriter.export(frozenState, files: [])
        let receipt = try #require(portable.paycheckReceipts.first)
        let result = try #require(receipt.calculation?.weeklyRegularRate)
        #expect(result.qualifyingHours == "48" && result.overtimeHours == "8")
        #expect(result.allocations.first?.periodRef == portable.periods.first?.id)
        #expect(portable.sourceInventory.workweekCount == 1)
        #expect(portable.sourceInventory.weeklyAllocationCount == Int64(result.allocations.count))
        let restored = try PortableStateMapping.archive(
            PortableStateCodec.decode(PortableStateCodec.encode(portable)))
        #expect(try PortableStateMapping.export(restored.state, files: []) == portable)
        #expect(
            restored.state.portableFinancialState?.paycheckReceipts.first?.assessment
                == receipt.assessment)
        #expect(receipt.assessment.expectedGross?.amount == "400")
    }

    @Test func repeatingNativeTracesRetainEveryFoundationDecimalDigit() throws {
        for (seconds, rate, expectedHours, expectedUnrounded) in [
            (
                1, "50", "0.0002777777777777777777777777777777777777",
                "0.013888888888888888888888888888888888888"
            ),
            (
                60, "50", "0.016666666666666666666666666666666666666",
                "0.8333333333333333333333333333333333333"
            ),
            (
                1, "0.00000001", "0.0002777777777777777777777777777777777777",
                "0.000000000002777777777777777777777777777777777777"
            ),
        ] {
            let store = UnitStateStore()
            let setup = AppModel(store: store)
            try setup.saveProfile(UnitFixture.profile(rate: "50"))
            if rate != "50" {
                // Native imported snapshots may contain rates beyond the USD editor's two
                // fraction digits. Construct an admitted domain snapshot, not an editor waiver.
                var state = try #require(store.state)
                let profile = try #require(state.profile)
                let agreement = try AgreementSnapshot(
                    id: profile.agreement.id,
                    version: profile.agreement.version, displayName: profile.agreement.displayName,
                    hourlyRate: Money(amount: UnitFixture.decimal(rate), currencyCode: "USD"),
                    regularSchedule: [], rounding: profile.agreement.rounding,
                    confirmedEpochSeconds: profile.agreement.confirmedEpochSeconds)
                state.profile = PayProfile(
                    id: profile.id, name: profile.name,
                    timeZoneIdentifier: profile.timeZoneIdentifier, agreement: agreement,
                    preferredCadence: profile.preferredCadence, baselineAgreement: agreement)
                state.activePeriod?.agreement = agreement
                try store.save(state)
            }
            let model = AppModel(store: store)
            try model.addWork(
                start: UnitFixture.start,
                end: UnitFixture.start.addingTimeInterval(TimeInterval(seconds)), kind: .regular)
            let native = try #require(model.calculation?.components.first)
            #expect(native.hours.map { NSDecimalNumber(decimal: $0).stringValue } == expectedHours)
            #expect(
                native.unroundedAmount.map { NSDecimalNumber(decimal: $0.amount).stringValue }
                    == expectedUnrounded)
            let gross = try #require(model.calculation?.total.amount)
            try model.confirmPaystub(
                UnitFixture.paystub(model, gross: NSDecimalNumber(decimal: gross).stringValue))
            let portable = try NativePortableStateWriter.export(
                try #require(store.state), files: [])
            let calculation = try #require(portable.paycheckReceipts.first?.calculation)
            let component = try #require(calculation.components.first)
            #expect(component.hours == expectedHours)
            #expect(component.unroundedAmount?.amount == expectedUnrounded)
            let decoded = try PortableStateCodec.decode(PortableStateCodec.encode(portable))
            #expect(decoded == portable)
            let restored = try PortableStateMapping.archive(decoded)
            #expect(try PortableStateMapping.export(restored.state, files: []) == portable)
        }
    }

    @Test func exactFrozenDifferenceDoesNotRoundBeyondNativePrecision() throws {
        let low = "0." + String(repeating: "0", count: 127) + "1"
        #expect(PortableExactDecimal.difference(expected: "1", paid: "1", equals: "0"))
        #expect(PortableExactDecimal.difference(expected: low, paid: "0", equals: low))
        #expect(PortableExactDecimal.difference(expected: "0", paid: low, equals: "-" + low))
        #expect(!PortableExactDecimal.difference(expected: low, paid: "0", equals: "0"))
        let beyondNative = "1.123456789012345678901234567890123456789012345678901234567890"
        #expect(PortableExactDecimal(beyondNative)?.nativeValue == nil)
        #expect(PortableExactDecimal(beyondNative)?.string == String(beyondNative.dropLast()))
    }

    @Test func malformedUnknownFieldAndWrongPasswordCannotReplaceDestination() async throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        let original = try #require(store.state)
        let portable = try NativePortableStateWriter.export(original, files: [])
        var object = try #require(
            JSONSerialization.jsonObject(with: PortableStateCodec.encode(portable))
                as? [String: Any])
        object["trialAccess"] = true
        #expect(throws: (any Error).self) {
            try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        }
        let directory = UnitFixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("synthetic.lpb")
        let protected = try BackupEncryption.seal(
            PortableStateCodec.encode(portable), password: "synthetic password 2026")
        try protected.write(to: url)
        let session = AppSession(store: store, evidenceStore: MemoryEvidenceStore())
        await #expect(throws: (any Error).self) {
            try await session.inspectBackup(at: url, password: "different password")
        }
        #expect(store.state == original)
        let preview = try await session.inspectBackup(at: url, password: "synthetic password 2026")
        #expect(store.state == original)
        try session.restore(preview)
        #expect(store.state?.portableFinancialState != nil)
    }

    @Test func workIdentitySurvivesEditsButReceiptReferencesStayScoped() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let entry = try #require(model.workEntries.first)
        try model.updateWork(
            id: entry.id, start: UnitFixture.start,
            end: UnitFixture.start.addingTimeInterval(9 * 3_600), kind: .regular)
        let portable = try NativePortableStateWriter.export(try #require(store.state), files: [])
        let snapshots = portable.workSnapshots.filter {
            $0.work.contains(where: { $0.id == portable.workSnapshots.first?.work.first?.id })
        }
        #expect(snapshots.count >= 2)
        #expect(Set(snapshots.compactMap { $0.work.first?.endEpochSeconds }).count == 2)
        var object = try #require(
            JSONSerialization.jsonObject(with: PortableStateCodec.encode(portable))
                as? [String: Any])
        var receipts = try #require(object["paycheckReceipts"] as? [[String: Any]])
        var calculation = try #require(receipts[0]["calculation"] as? [String: Any])
        var components = try #require(calculation["components"] as? [[String: Any]])
        components[0]["workRef"] = "outside:owning-snapshot"
        calculation["components"] = components
        receipts[0]["calculation"] = calculation
        object["paycheckReceipts"] = receipts
        #expect(throws: (any Error).self) {
            try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func originalsKeepHashesAndFailedReplacementKeepsDestination() throws {
        let source = UnitStateStore()
        let model = AppModel(store: source)
        try UnitFixture.populate(model, evidence: true)
        let original = try #require(source.state)
        let reference = try #require(original.allEvidence.first)
        let bytes = Data("SYNTHETIC ORIGINAL".utf8)
        let portable = try NativePortableStateWriter.export(
            original, files: [.init(id: reference.id, bytes: bytes)])
        let archive = try PortableStateMapping.archive(portable)
        #expect(archive.files.first?.bytes == bytes)
        #expect(
            archive.state.portableFinancialState?.attachments.first?.bytesBase64.isEmpty == true)
        #expect(archive.state.portableOriginals.count == 1)
        let destination = UnitStateStore()
        var prior = AppPersistentState()
        prior.hasUsedFreeAudit = true
        destination.state = prior
        let session = AppSession(store: destination, evidenceStore: MemoryEvidenceStore())
        destination.failSave = true
        #expect(throws: (any Error).self) { try session.restore(archive) }
        #expect(destination.state == prior)
        destination.failSave = false
        try session.restore(archive)
        #expect(destination.state?.hasUsedFreeAudit == true)
        let restored = try #require(destination.state)
        #expect(try PortableStateMapping.export(restored, files: archive.files) == portable)
        #expect(
            restored.portableOriginals.first?.storedFilename
                != archive.state.portableOriginals.first?.storedFilename)
    }

    @Test func canonicalAndroidPendingReceiptNeverBecomesCleanMatch() throws {
        let url = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let portable = try PortableStateCodec.decode(Data(contentsOf: url))
        let receipt = try #require(portable.paycheckReceipts.first)
        #expect(receipt.assessment.verdict == "needsReview")
        #expect(receipt.reviewFacts.weeklyReviewPending == true)
        let archive = try PortableStateMapping.archive(portable)
        #expect(archive.state.profile == nil)
        #expect(archive.state.activePeriod == nil)
        #expect(archive.workCount == 10)
        #expect(
            archive.state.portableFinancialState?.paycheckReceipts.first?.assessment.reviewReasons
                == ["WEEKLY_REVIEW_PENDING"])
        #expect(try PortableStateMapping.export(archive.state, files: []) == portable)
    }

    @Test func explicitAdoptionAddsNewFactsAndReexportsOriginalPendingReceipt() throws {
        let url = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: url))
        let archive = try PortableStateMapping.archive(source)
        let store = UnitStateStore()
        store.state = archive.state
        let model = AppModel(store: store)
        #expect(model.profile == nil && model.calculation == nil)
        let snapshot = try #require(
            source.workSnapshots.first(where: { $0.role == "currentLedger" }))
        var draft = UnitFixture.profile(rate: "20")
        draft.currencyCode = "USD"
        draft.timeZoneIdentifier = "America/Denver"
        draft.periodStartDate = try #require(
            ISO8601DateFormatter().date(from: "2026-10-19T06:00:00Z"))
        draft.useDailyOvertime = true
        draft.overtimeAfterHours = "8"
        draft.overtimeMultiplier = "1.5"
        draft.roundingRule = MoneyRoundingRule(scale: 2, mode: .halfUp, scope: .payCategory)
        let unchanged = store.state
        #expect(throws: (any Error).self) {
            try model.adoptPortableWork(
                draft, sourceSnapshotID: snapshot.id, confirmedFields: ["payRules"])
        }
        #expect(store.state == unchanged)
        try model.adoptPortableWork(
            draft, sourceSnapshotID: snapshot.id,
            confirmedFields: PortableNativeAdoption.requiredFields)
        #expect(model.workEntries.count == 5)
        #expect(model.calculation?.total.amount == Decimal(800))
        let adopted = try #require(store.state)
        let exported = try PortableStateMapping.export(adopted, files: [])
        #expect(exported.profiles.count == 2)
        #expect(
            exported.profiles.first(where: { $0.id == source.profiles.first?.id })
                == source.profiles.first)
        #expect(exported.paycheckReceipts == source.paycheckReceipts)
        #expect(exported.adoptions.count == 1)
        #expect(exported.activeProfileRef == source.activeProfileRef)
        #expect(model.profile == nil && model.currentProfile?.agreement.hourlyRate.amount == 20)
        let relaunched = AppModel(store: store)
        #expect(
            relaunched.profile == nil
                && relaunched.currentProfile?.agreement.hourlyRate.amount == 20)
        for invalidScope in ["payRules", "legalClearance", "weeklyApplicability"] {
            var invalid = try #require(
                JSONSerialization.jsonObject(with: PortableStateCodec.encode(exported))
                    as? [String: Any])
            var lineage = try #require(invalid["adoptions"] as? [[String: Any]])
            lineage[0]["confirmedFields"] = [invalidScope]
            invalid["adoptions"] = lineage
            #expect(throws: (any Error).self) {
                try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: invalid))
            }
        }
        #expect(exported.paycheckReceipts.first?.assessment.verdict == "needsReview")
        #expect(exported.paycheckReceipts.first?.reviewFacts.weeklyReviewPending == true)
        let restored = try PortableStateMapping.archive(exported)
        #expect(restored.state.activePeriod?.workEntries.count == 5)
        #expect(
            restored.state.portableCurrentProfile?.profile(in: restored.state)?.agreement.hourlyRate
                .amount == Decimal(20))
        #expect(try PortableStateMapping.export(restored.state, files: []) == exported)
        let inherited = try #require(model.currentProfile?.agreement.unsupportedRuleNotes)
        #expect(inherited.contains(source.paycheckReceipts[0].id))
        #expect(inherited.contains(snapshot.id))
        try model.confirmPaystub(UnitFixture.paystub(model, gross: "800"))
        #expect(model.currentAuditStatus == .needsReview)
        let rechecked = try PortableStateMapping.export(try #require(store.state), files: [])
        for receipt in source.paycheckReceipts {
            #expect(rechecked.paycheckReceipts.first(where: { $0.id == receipt.id }) == receipt)
        }
        #expect(
            rechecked.paycheckReceipts.contains {
                $0.id != source.paycheckReceipts[0].id && $0.assessment.verdict == "needsReview"
            })
        let independentStore = UnitStateStore()
        let independent = AppModel(store: independentStore)
        try UnitFixture.populate(independent)
        try independent.confirmPaystub(UnitFixture.paystub(independent))
        #expect(independent.currentAuditStatus == .grossMatches)
        #expect(
            (independent.profile?.agreement.unsupportedRuleNotes ?? "").contains("inherited")
                == false)
    }

    @Test func fullyRecordedImportAdvancesWorkWithoutReconfirmingOrRewritingHistory() throws {
        let sourceStore = UnitStateStore()
        let sourceModel = AppModel(store: sourceStore)
        try UnitFixture.populate(sourceModel)
        try sourceModel.confirmPaystub(UnitFixture.paystub(sourceModel))
        let source = try NativePortableStateWriter.export(
            try #require(sourceStore.state), files: [])
        let incoming = try PortableStateMapping.archive(source)
        let targetStore = UnitStateStore()
        targetStore.state = incoming.state
        let target = AppModel(store: targetStore)
        #expect(target.profile != nil && target.workEntries.count == 1)
        try target.addWork(
            start: UnitFixture.start.addingTimeInterval(86_400),
            end: UnitFixture.start.addingTimeInterval(86_400 + 8 * 3_600), kind: .regular,
            note: "New confirmed work")
        let exported = try PortableStateMapping.export(try #require(targetStore.state), files: [])
        #expect(exported.profiles.count == 1 && exported.adoptions.isEmpty)
        #expect(exported.paycheckReceipts == source.paycheckReceipts)
        #expect(exported.ruleSnapshots == source.ruleSnapshots)
        for snapshot in source.workSnapshots {
            #expect(exported.workSnapshots.first(where: { $0.id == snapshot.id }) == snapshot)
        }
        #expect(exported.activeProfileRef == source.activeProfileRef)
        #expect(
            exported.profiles.first?.currentWorkSnapshotRef
                != source.profiles.first?.currentWorkSnapshotRef)
        let reimported = try PortableStateMapping.archive(exported)
        #expect(reimported.state.activePeriod?.workEntries.count == 2)
        #expect(try PortableStateMapping.export(reimported.state, files: []) == exported)
    }

    @Test func currentWorkspaceUsesItsOwnRulesWhileFutureDefaultRemainsIndependent() throws {
        let originalStore = UnitStateStore()
        let original = AppModel(store: originalStore)
        try UnitFixture.populate(original)
        try original.confirmPaystub(UnitFixture.paystub(original))
        let source = try NativePortableStateWriter.export(
            try #require(originalStore.state), files: [])
        let store = UnitStateStore()
        store.state = try PortableStateMapping.archive(source).state
        let adopting = AppModel(store: store)
        let snapshot = try #require(
            source.workSnapshots.first(where: { $0.role == "currentLedger" }))
        var adoptedDraft = UnitFixture.profile(rate: "75")
        adoptedDraft.roundingRule = MoneyRoundingRule(scale: 2, mode: .halfUp, scope: .payCategory)
        try adopting.adoptPortableWork(
            adoptedDraft, sourceSnapshotID: snapshot.id,
            confirmedFields: PortableNativeAdoption.requiredFields)
        let combined = try PortableStateMapping.export(try #require(store.state), files: [])
        var object = try #require(
            JSONSerialization.jsonObject(with: PortableStateCodec.encode(combined))
                as? [String: Any])
        object["activeProfileRef"] = source.activeProfileRef
        let selected = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        let targetStore = UnitStateStore()
        targetStore.state = try PortableStateMapping.archive(selected).state
        let target = AppModel(store: targetStore)
        #expect(target.profile?.agreement.hourlyRate.amount == 50)
        #expect(target.activePeriod?.agreement.hourlyRate.amount == 75)
        #expect(target.calculation?.total.amount == 600)
        try target.addWork(
            start: UnitFixture.start.addingTimeInterval(86_400),
            end: UnitFixture.start.addingTimeInterval(86_400 + 8 * 3_600), kind: .regular)
        #expect(target.calculation?.total.amount == 1200)
        let exported = try PortableStateMapping.export(try #require(targetStore.state), files: [])
        #expect(exported.activeProfileRef == source.activeProfileRef)
        #expect(exported.periods.filter { $0.isCurrent == true }.count == 1)
        #expect(exported.paycheckReceipts == selected.paycheckReceipts)
        for frozen in selected.workSnapshots {
            #expect(exported.workSnapshots.first(where: { $0.id == frozen.id }) == frozen)
        }
        let roundtrip = try PortableStateMapping.archive(exported)
        #expect(roundtrip.state.profile?.agreement.hourlyRate.amount == 50)
        #expect(roundtrip.state.activePeriod?.agreement.hourlyRate.amount == 75)
    }

    @Test func adoptionPrefillUsesSelectedSnapshotPeriodWhenGlobalPointerWasNotRecorded() throws {
        let url = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: url))
        var object = try #require(
            JSONSerialization.jsonObject(with: PortableStateCodec.encode(source)) as? [String: Any])
        var profiles = try #require(object["profiles"] as? [[String: Any]])
        profiles[0]["currentPeriodRef"] = NSNull()
        profiles[0]["timeZone"] = NSNull()
        var missing = profiles[0]["fieldsNotRecorded"] as? [String] ?? []
        for field in ["currentPeriodRef", "timeZone"] where !missing.contains(field) {
            missing.append(field)
        }
        profiles[0]["fieldsNotRecorded"] = missing
        object["profiles"] = profiles
        var periods = try #require(object["periods"] as? [[String: Any]])
        let snapshot = try #require(
            source.workSnapshots.first(where: { $0.role == "paycheckInput" }))
        periods[0]["isCurrent"] = true
        periods[0]["currentWorkSnapshotRef"] = snapshot.id
        periods[0]["fieldsNotRecorded"] = (periods[0]["fieldsNotRecorded"] as? [String] ?? [])
            .filter { !["isCurrent", "currentWorkSnapshotRef"].contains($0) }
        object["periods"] = periods
        let input = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        let (profile, selectedSnapshot) = try #require(PortableAdoptionScope.currentSource(input))
        let period = try #require(
            input.periods.first(where: { $0.id == selectedSnapshot.periodRef }))
        let draft = PortableAdoptionDraft.make(
            document: input, profile: profile, snapshot: snapshot)
        #expect(draft.timeZoneIdentifier == period.calendarWindow.timeZone)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let recordedZone = TimeZone(identifier: draft.timeZoneIdentifier)
        let validZone = try #require(recordedZone)
        formatter.timeZone = validZone
        formatter.dateFormat = "yyyy-MM-dd"
        #expect(formatter.string(from: draft.periodStartDate) == period.calendarWindow.startDate)
        #expect(
            formatter.string(from: draft.manualPeriodEndDate)
                == period.calendarWindow.endDateInclusive)
    }

    @Test func compatibleCurrentWorkspaceSurvivesUnrepresentableFutureDefaultAndRelaunch() throws {
        let source = try independentContexts()
        let future = try #require(
            source.profiles.first(where: { $0.id == source.activeProfileRef }))
        var object = try PortableStateMapping.object(source)
        var rules = try #require(object["ruleSnapshots"] as? [[String: Any]])
        let index = try #require(rules.firstIndex(where: { $0["id"] as? String == future.ruleRef }))
        rules[index]["hourlyRate"] = "50.123456789012345678901234567890123456789012345678901"
        object["ruleSnapshots"] = rules
        let input = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        let store = UnitStateStore()
        store.state = try PortableStateMapping.archive(input).state
        let model = AppModel(store: store)
        #expect(model.profile == nil)
        #expect(model.currentProfile?.agreement.hourlyRate.amount == 75)
        #expect(model.calculation?.total.amount == 600 && model.isOnboarded)
        let reloaded = AppModel(store: store)
        #expect(reloaded.profile == nil && reloaded.calculation?.total.amount == 600)
        #expect(try PortableStateMapping.export(try #require(store.state), files: []) == input)
        var forgedObject = try PortableStateMapping.object(try #require(store.state))
        var forgedActive = try #require(forgedObject["activePeriod"] as? [String: Any])
        let forgedID = UUID().uuidString
        forgedActive["id"] = forgedID
        forgedObject["activePeriod"] = forgedActive
        var forgedOwner = try #require(forgedObject["portableCurrentProfile"] as? [String: Any])
        forgedOwner["periodID"] = forgedID
        forgedOwner["profileID"] = UUID().uuidString
        forgedOwner["sourceName"] = "Forged owner"
        forgedObject["portableCurrentProfile"] = forgedOwner
        let forged = try JSONDecoder().decode(
            AppPersistentState.self, from: JSONSerialization.data(withJSONObject: forgedObject))
        #expect(throws: (any Error).self) { try AppStateValidation.validate(forged) }
        try model.archiveCurrentPeriod()
        #expect(model.activePeriod == nil && model.history.count == 1 && model.isOnboarded)
        #expect(throws: (any Error).self) {
            try model.startNewPayPeriod(startDate: UnitFixture.start.addingTimeInterval(7 * 86_400))
        }
        let exported = try PortableStateMapping.export(try #require(store.state), files: [])
        #expect(exported.activeProfileRef == input.activeProfileRef)
        #expect(
            exported.ruleSnapshots.contains {
                $0.id == future.ruleRef
                    && $0.hourlyRate == "50.123456789012345678901234567890123456789012345678901"
            })
        #expect(exported.periods.filter { $0.isCurrent == true }.isEmpty)
        var corrupted = try #require(store.state)
        let owner = try #require(corrupted.portableCurrentProfile)
        corrupted.portableCurrentProfile = PortableCurrentProfile(
            periodID: owner.periodID, profileID: UUID(), sourceName: owner.sourceName)
        #expect(throws: (any Error).self) { try AppStateValidation.validate(corrupted) }
    }

    @Test func futureDefaultRemainsAvailableWhenCurrentRulesNeedReview() throws {
        let source = try independentContexts()
        let current = try #require(source.periods.first(where: { $0.isCurrent == true }))
        var object = try PortableStateMapping.object(source)
        var rules = try #require(object["ruleSnapshots"] as? [[String: Any]])
        let index = try #require(
            rules.firstIndex(where: { $0["id"] as? String == current.ruleRef }))
        rules[index]["rounding"] = NSNull()
        var missing = rules[index]["fieldsNotRecorded"] as? [String] ?? []
        missing.append("rounding")
        rules[index]["fieldsNotRecorded"] = missing
        object["ruleSnapshots"] = rules
        let input = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        let store = UnitStateStore()
        store.state = try PortableStateMapping.archive(input).state
        let model = AppModel(store: store)
        #expect(model.activePeriod == nil && model.calculation == nil)
        #expect(model.profile?.agreement.hourlyRate.amount == 50)
        #expect(try PortableStateMapping.export(try #require(store.state), files: []) == input)
        try model.startNewPayPeriod(startDate: UnitFixture.start.addingTimeInterval(7 * 86_400))
        try model.addWork(
            start: UnitFixture.start.addingTimeInterval(7 * 86_400),
            end: UnitFixture.start.addingTimeInterval(7 * 86_400 + 8 * 3_600), kind: .regular)
        #expect(model.calculation?.total.amount == 400)
        let exported = try PortableStateMapping.export(try #require(store.state), files: [])
        #expect(exported.activeProfileRef == input.activeProfileRef)
        #expect(exported.periods.filter { $0.isCurrent == true }.count == 1)
        #expect(exported.periods.first(where: { $0.id == current.id })?.ruleRef == current.ruleRef)
        #expect(exported.ruleSnapshots.first(where: { $0.id == current.ruleRef })?.rounding == nil)
        let restored = try PortableStateMapping.archive(exported)
        #expect(restored.state.profile?.agreement.hourlyRate.amount == 50)
        #expect(restored.state.activePeriod?.agreement.hourlyRate.amount == 50)
    }

    @Test
    func adoptingCurrentContextPreservesDefaultUnlessSeparatelyChosenAndRollsOverUsingDefault()
        throws
    {
        for chooseFuture in [false, true] {
            let source = try independentContexts()
            let store = UnitStateStore()
            store.state = try PortableStateMapping.archive(source).state
            let model = AppModel(store: store)
            let (_, snapshot) = try #require(PortableAdoptionScope.currentSource(source))
            var draft = UnitFixture.profile(rate: "90")
            draft.roundingRule = MoneyRoundingRule(scale: 2, mode: .halfUp, scope: .payCategory)
            try model.adoptPortableWork(
                draft, sourceSnapshotID: snapshot.id,
                confirmedFields: PortableNativeAdoption.requiredFields,
                makeDefaultForFuture: chooseFuture)
            #expect(model.currentProfile?.agreement.hourlyRate.amount == 90)
            #expect(model.profile?.agreement.hourlyRate.amount == (chooseFuture ? 90 : 50))
            let relaunched = AppModel(store: store)
            #expect(relaunched.calculation?.total.amount == 720)
            #expect(relaunched.profile?.agreement.hourlyRate.amount == (chooseFuture ? 90 : 50))
            let exported = try PortableStateMapping.export(try #require(store.state), files: [])
            #expect((exported.activeProfileRef == source.activeProfileRef) == !chooseFuture)
            #expect(exported.periods.filter { $0.isCurrent == true }.count == 1)
            let roundtrip = try PortableStateMapping.archive(exported)
            #expect(
                roundtrip.state.profile?.agreement.hourlyRate.amount == (chooseFuture ? 90 : 50))
            #expect(roundtrip.state.activePeriod?.agreement.hourlyRate.amount == 90)
            try model.archiveCurrentPeriod()
            #expect(model.activePeriod?.agreement.hourlyRate.amount == (chooseFuture ? 90 : 50))
            let advanced = try PortableStateMapping.export(try #require(store.state), files: [])
            #expect(advanced.activeProfileRef == exported.activeProfileRef)
            #expect(advanced.profiles.count == exported.profiles.count)
            #expect(advanced.adoptions.count == exported.adoptions.count)
            #expect(advanced.periods.filter { $0.isCurrent == true }.count == 1)
            let advancedRestore = try PortableStateMapping.archive(advanced)
            #expect(
                advancedRestore.state.activePeriod?.agreement.hourlyRate.amount
                    == (chooseFuture ? 90 : 50))
        }
    }

    private func independentContexts() throws -> PortableState {
        let sourceStore = UnitStateStore()
        let sourceModel = AppModel(store: sourceStore)
        try UnitFixture.populate(sourceModel)
        let source = try NativePortableStateWriter.export(
            try #require(sourceStore.state), files: [])
        let store = UnitStateStore()
        store.state = try PortableStateMapping.archive(source).state
        let model = AppModel(store: store)
        let snapshot = try #require(
            source.workSnapshots.first(where: { $0.role == "currentLedger" }))
        var draft = UnitFixture.profile(rate: "75")
        draft.roundingRule = MoneyRoundingRule(scale: 2, mode: .halfUp, scope: .payCategory)
        try model.adoptPortableWork(
            draft, sourceSnapshotID: snapshot.id,
            confirmedFields: PortableNativeAdoption.requiredFields)
        return try PortableStateMapping.export(try #require(store.state), files: [])
    }

    @Test func inactiveUnmappableSourceKeyIsRetainedAndOnlySelectedContextIsGuarded() throws {
        let source = try independentContexts()
        let future = try #require(
            source.profiles.first(where: { $0.id == source.activeProfileRef }))
        let locator: [String: Any] = [
            "title": "Foreign source", "url": "https://example.invalid/source", "section": NSNull(),
            "verifiedEpochSeconds": NSNull(),
            "ruleKey": "source-specific-unknown-key", "documentRef": NSNull(),
            "documentSHA256": NSNull(), "documentPage": NSNull(), "quotedText": NSNull(),
        ]
        for selected in [false, true] {
            var object = try PortableStateMapping.object(source)
            var rules = try #require(object["ruleSnapshots"] as? [[String: Any]])
            let index = try #require(
                rules.firstIndex(where: { $0["id"] as? String == future.ruleRef }))
            if selected {
                rules[index]["sources"] = [locator]
            } else {
                var inactive = rules[index]
                inactive["id"] = "test.inactive-rule"
                inactive["ruleID"] = "test.inactive-domain-rule"
                inactive["sources"] = [locator]
                rules.append(inactive)
                var crosswalk = try #require(object["identityCrosswalk"] as? [[String: Any]])
                crosswalk.append([
                    "entityType": "ruleSnapshot", "portableID": "test.inactive-rule",
                    "originClient": "ios", "originKind": "native",
                    "originLocalID": "test.inactive-rule",
                ])
                object["identityCrosswalk"] = crosswalk
                var inventory = try #require(object["sourceInventory"] as? [String: Any])
                inventory["ruleSnapshotCount"] = rules.count
                object["sourceInventory"] = inventory
            }
            object["ruleSnapshots"] = rules
            let input = try PortableStateCodec.decode(
                JSONSerialization.data(withJSONObject: object))
            let restored = try PortableStateMapping.archive(input)
            #expect(restored.state.activePeriod?.agreement.hourlyRate.amount == 75)
            #expect((restored.state.profile == nil) == selected)
            #expect(try PortableStateMapping.export(restored.state, files: []) == input)
        }
    }

    @Test func changedImportedWindowRefusesPortableExportAndFullBackupRetainsBothContexts() throws {
        let sourceStore = UnitStateStore()
        let original = AppModel(store: sourceStore)
        try UnitFixture.populate(original)
        try original.confirmPaystub(UnitFixture.paystub(original))
        let source = try NativePortableStateWriter.export(
            try #require(sourceStore.state), files: [])
        let store = UnitStateStore()
        store.state = try PortableStateMapping.archive(source).state
        let model = AppModel(store: store)
        let old = try #require(model.activePeriod)
        try model.correctCurrentPeriod(
            start: old.window.startDate,
            end: old.window.displayEndDate.addingTimeInterval(2 * 86_400))
        let corrected = try #require(store.state)
        #expect(corrected.activePeriod?.window != old.window)
        #expect(throws: (any Error).self) { try PortableStateMapping.export(corrected, files: []) }
        #expect(store.state == corrected)
        #expect(corrected.portableFinancialState?.paycheckReceipts == source.paycheckReceipts)
        let backup = BackupArchive(createdAt: UnitFixture.start, state: corrected, files: [])
        let restored = try BackupArchive.decode(backup.encoded())
        #expect(restored.state.activePeriod?.window == corrected.activePeriod?.window)
        #expect(restored.state.portableFinancialState?.paycheckReceipts == source.paycheckReceipts)
    }

    @Test func selectedClosedEvidenceStaysReadOnlyWithoutDisablingFutureDefault() throws {
        let source = try independentContexts()
        var object = try PortableStateMapping.object(source)
        var periods = try #require(object["periods"] as? [[String: Any]])
        let index = try #require(periods.firstIndex(where: { $0["isCurrent"] as? Bool == true }))
        periods[index]["closed"] = true
        periods[index]["archivedAtEpochSeconds"] = source.exportedAtEpochSeconds
        periods[index]["fieldsNotRecorded"] =
            (periods[index]["fieldsNotRecorded"] as? [String] ?? []).filter {
                !["closed", "archivedAtEpochSeconds"].contains($0)
            }
        object["periods"] = periods
        let input = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        let restored = try PortableStateMapping.archive(input)
        #expect(restored.state.activePeriod == nil)
        #expect(restored.state.profile?.agreement.hourlyRate.amount == 50)
        #expect(try PortableStateMapping.export(restored.state, files: []) == input)
    }

    @Test func markerSeparatesUnknownArrayFromKnownEmptyAndNativeInputChangesStayFrozen() throws {
        let sourceURL = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: sourceURL))
        var object = try PortableStateMapping.object(source)
        var receipts = try #require(object["paycheckReceipts"] as? [[String: Any]])
        var assessment = try #require(receipts[0]["assessment"] as? [String: Any])
        #expect(assessment["weeklyReviewRefs"] as? [String] == [])
        var missing = assessment["fieldsNotRecorded"] as? [String] ?? []
        missing.append("weeklyReviewRefs")
        assessment["fieldsNotRecorded"] = missing
        receipts[0]["assessment"] = assessment
        object["paycheckReceipts"] = receipts
        #expect(throws: (any Error).self) {
            try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
        }
        assessment["weeklyReviewRefs"] = NSNull()
        receipts[0]["assessment"] = assessment
        object["paycheckReceipts"] = receipts
        _ = try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))

        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.saveProfile(UnitFixture.profile(rate: "55"), scope: .futurePeriods)
        try model.confirmPaystub(UnitFixture.paystub(model))
        let recorded = try #require(model.activePeriod?.auditRevisions?.last)
        #expect(recorded.agreementChanges?.count == 1)
        try model.saveProfile(UnitFixture.profile(rate: "60"), scope: .futurePeriods)
        let portable = try NativePortableStateWriter.export(try #require(store.state), files: [])
        let receipt = try #require(portable.paycheckReceipts.first)
        let calculation = try #require(receipt.calculation)
        #expect(!calculation.ruleChangeRefs.isEmpty)
        #expect(calculation.ruleChangeRefs == receipt.targetRuleChangeRefs)
        #expect(calculation.ruleChangeRefs != portable.periods.first?.ruleChangeRefs)
        let oldChange = try #require(
            portable.ruleChanges.first(where: { $0.id == calculation.ruleChangeRefs.first }))
        #expect(
            portable.ruleSnapshots.first(where: { $0.id == oldChange.ruleRef })?.hourlyRate == "55")
        #expect(
            calculation.components.map(\.amount.amount)
                == recorded.calculation?.components.map {
                    NSDecimalNumber(decimal: $0.amount.amount).stringValue
                })
        #expect(!calculation.fieldsNotRecorded.contains("ruleChangeRefs"))
        #expect(receipt.assessment.weeklyReviewRefs == nil)
        #expect(receipt.assessment.fieldsNotRecorded.contains("weeklyReviewRefs"))
        _ = try PortableStateCodec.encode(portable)
    }

    @Test func frozenRuleChangesDistinguishAgreementIdentityAtTheSameDateAndVersion() throws {
        let store = UnitStateStore()
        let model = AppModel(store: store)
        try UnitFixture.populate(model)
        try model.saveProfile(UnitFixture.profile(rate: "55"), scope: .futurePeriods)
        try model.confirmPaystub(UnitFixture.paystub(model))
        var state = try #require(store.state)
        let old = try #require(state.activePeriod?.agreementChanges?.first)
        var encoded = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(old.agreement))
                as? [String: Any])
        encoded["id"] = "synthetic-independent-agreement"
        let different = try JSONDecoder().decode(
            AgreementSnapshot.self, from: JSONSerialization.data(withJSONObject: encoded))
        #expect(different.version == old.agreement.version)
        state.activePeriod?.agreementChanges = [
            AgreementChange(effectiveDate: old.effectiveDate, agreement: different)
        ]
        let baseline = try #require(state.activePeriod?.agreement)
        var encodedBaseline = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(baseline)) as? [String: Any])
        encodedBaseline["id"] = different.id
        state.activePeriod?.agreement = try JSONDecoder().decode(
            AgreementSnapshot.self,
            from: JSONSerialization.data(withJSONObject: encodedBaseline))
        try AppStateValidation.validate(state)
        let portable = try NativePortableStateWriter.export(state, files: [])
        let receipt = try #require(portable.paycheckReceipts.first)
        let frozenRefs = try #require(receipt.calculation?.ruleChangeRefs)
        let currentRefs = try #require(portable.periods.first?.ruleChangeRefs)
        #expect(frozenRefs == receipt.targetRuleChangeRefs)
        #expect(frozenRefs.count == 1 && currentRefs.count == 1 && frozenRefs != currentRefs)
        let frozen = try #require(portable.ruleChanges.first { $0.id == frozenRefs[0] })
        let current = try #require(portable.ruleChanges.first { $0.id == currentRefs[0] })
        #expect(frozen.effectiveDate == current.effectiveDate)
        #expect(frozen.ruleRef != current.ruleRef)
        _ = try PortableStateCodec.encode(portable)
    }

    @Test func wireZonesPreserveIANAAliasesAndRefuseFoundationOnlyOffsetNames() throws {
        let sourceURL = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: sourceURL))
        let unsupported = [
            "GMT+14", "GMT+05:30", "GMT-5", "GMT+1400", "UTC+14", "UTC+05:30",
            "GMT+00:00", "gmt+14", "PST", "CST", "IST", "america/new_york", "Asia/Hanoi",
        ]
        let supported = [
            "UTC", "Etc/UTC", "US/Eastern", "EST", "CET", "Etc/GMT-14", "Etc/GMT+5",
            "GMT+0", "GMT-0", "GMT0", "CST6CDT", "PST8PDT", "Asia/Ho_Chi_Minh",
        ]
        for zone in supported + unsupported {
            var object = try PortableStateMapping.object(source)
            var profiles = try #require(object["profiles"] as? [[String: Any]])
            profiles[0]["timeZone"] = zone
            let missing = try #require(profiles[0]["fieldsNotRecorded"] as? [String])
            profiles[0]["fieldsNotRecorded"] = missing.filter { $0 != "timeZone" }
            object["profiles"] = profiles
            let data = try JSONSerialization.data(withJSONObject: object)
            if unsupported.contains(zone) {
                #expect(throws: (any Error).self) { _ = try PortableStateCodec.decode(data) }
            } else {
                let decoded = try PortableStateCodec.decode(data)
                #expect(decoded.profiles[0].timeZone == zone)
                let roundTrip = try PortableStateCodec.decode(PortableStateCodec.encode(decoded))
                #expect(roundTrip.profiles[0].timeZone == zone)
            }
        }
    }

    @Test func wireStringLimitsCountUnicodeScalarsWithoutNormalizingNotes() throws {
        let sourceURL = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: sourceURL))
        for (repetitions, allowed) in [(2_000, true), (2_001, false), (3_000, false)] {
            let note = String(repeating: "e\u{0301}", count: repetitions)
            #expect(note.count == repetitions)
            #expect(note.unicodeScalars.count == repetitions * 2)
            var object = try PortableStateMapping.object(source)
            var snapshots = try #require(object["workSnapshots"] as? [[String: Any]])
            var work = try #require(snapshots[0]["work"] as? [[String: Any]])
            work[0]["note"] = note
            snapshots[0]["work"] = work
            object["workSnapshots"] = snapshots
            let data = try JSONSerialization.data(withJSONObject: object)
            if allowed {
                let decoded = try PortableStateCodec.decode(data)
                let preserved = try #require(decoded.workSnapshots[0].work[0].note)
                #expect(Data(preserved.utf8) == Data(note.utf8))
                let roundTrip = try PortableStateCodec.decode(PortableStateCodec.encode(decoded))
                let retained = try #require(roundTrip.workSnapshots[0].work[0].note)
                #expect(Data(retained.utf8) == Data(note.utf8))
            } else {
                #expect(throws: (any Error).self) { try PortableStateCodec.decode(data) }
            }
        }
    }

    @Test func missingMarkersRejectEmptyDottedPathSegments() throws {
        let sourceURL = try #require(
            Bundle(for: PortableFixtureBundle.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let source = try PortableStateCodec.decode(Data(contentsOf: sourceURL))
        for marker in [".weeklyReviewRefs", "weeklyReviewRefs.", "weeklyReviewRefs.."] {
            var object = try PortableStateMapping.object(source)
            var receipts = try #require(object["paycheckReceipts"] as? [[String: Any]])
            var assessment = try #require(receipts[0]["assessment"] as? [String: Any])
            assessment["weeklyReviewRefs"] = NSNull()
            var missing = assessment["fieldsNotRecorded"] as? [String] ?? []
            missing.append(marker)
            assessment["fieldsNotRecorded"] = missing
            receipts[0]["assessment"] = assessment
            object["paycheckReceipts"] = receipts
            #expect(throws: (any Error).self) {
                try PortableStateCodec.decode(JSONSerialization.data(withJSONObject: object))
            }
        }
    }

    @Test func unknownLegacyEngineDoesNotEraseItsOwningFrozenInputContext()
        throws
    {
        for recordedContext in [false, true] {
            let store = UnitStateStore()
            let model = AppModel(store: store)
            try UnitFixture.populate(model)
            try model.confirmPaystub(UnitFixture.paystub(model))
            var state = try #require(store.state)
            var active = try #require(state.activePeriod)
            let revision = try #require(active.auditRevisions?.first)
            let prior = try #require(revision.calculation)
            let unknownEngine = CalculationResult(
                agreementID: prior.agreementID, agreementVersion: prior.agreementVersion,
                components: prior.components, total: prior.total,
                agreementSnapshots: prior.agreementSnapshots, provenance: nil)
            active.auditRevisions = [
                AuditRevision(
                    id: revision.id, window: revision.window,
                    agreement: revision.agreement, timeZoneIdentifier: revision.timeZoneIdentifier,
                    workEntries: revision.workEntries, calculation: unknownEngine,
                    paystub: revision.paystub,
                    reconciliation: revision.reconciliation,
                    agreementChanges: recordedContext ? [] : nil)
            ]
            state.activePeriod = active
            let portable = try NativePortableStateWriter.export(state, files: [])
            #expect(portable.paycheckReceipts.first?.calculation?.ruleChangeRefs == [])
            #expect(portable.paycheckReceipts.first?.calculation?.provenance == nil)
            #expect(
                portable.paycheckReceipts.first?.producer.fieldsNotRecorded.contains(
                    "calculationEngineID") == true)
            #expect(
                portable.paycheckReceipts.first?.calculation?.fieldsNotRecorded.contains(
                    "provenance") == true)
            let incoming = try PortableStateMapping.archive(portable)
            #expect(try PortableStateMapping.export(incoming.state, files: []) == portable)
            let backup = BackupArchive(createdAt: UnitFixture.start, state: state, files: [])
            #expect(try BackupArchive.decode(backup.encoded()).state == state)
        }
    }

    @Test func adapterIDsAreStableAndTyped() {
        let first = PortableLocalIdentity.make(entityType: "workEntry", portableID: "external:1")
        #expect(
            first == PortableLocalIdentity.make(entityType: "workEntry", portableID: "external:1"))
        #expect(
            first.localID
                != PortableLocalIdentity.make(entityType: "period", portableID: "external:1")
                .localID)
    }
}

private final class PortableFixtureBundle {}
