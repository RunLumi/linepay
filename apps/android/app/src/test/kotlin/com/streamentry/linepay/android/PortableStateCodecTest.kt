package com.streamentry.linepay.android

import com.google.gson.Gson
import com.google.gson.JsonParser
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PortableStateCodecTest {
    private fun sourceState(): AndroidLocalState {
        var state = AndroidLocalState(profile = AndroidRuleProfile(
            hourlyRate = "25.00", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true,
        ))
        for (day in 12..16) state = LinePaycheckRepository.addWork(
            state, "2026-10-$day 07:00", "2026-10-$day 15:00", "", "", "Synthetic portable shift $day",
        )
        return LinePaycheckRepository.savePaycheck(state, AndroidPaycheckInput(
            "2026-10-12", "2026-10-18", "UTC", true, "1000.00", GrossBasisChoice.WAGES_ONLY, true, true,
        ), 1792195200).first
    }

    @Test fun nativeExportImportKeepsFrozenWeeklyWarningAndStableIdentitiesWithoutReassessment() {
        val original = sourceState()
        assertEquals("NEEDS_REVIEW", original.checks.single().verdict)
        val bytes = AndroidPortableStateCodec.encode(original, 1792195200)
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location ->
            File(location).mkdirs()
            File(location, "android-portable-source.json").writeBytes(bytes)
            File(location, "android-portable-source.lpb").writeBytes(com.streamentry.linepay.backup.BackupEnvelope.seal(bytes, "Synthetic portable backup password"))
        }
        val first = PortableStateJson.parse(bytes)
        val imported = AndroidPortableStateCodec.decode(bytes)
        assertEquals(5, imported.work.size)
        assertTrue(imported.checks.isEmpty())
        val sourceReceipt = imported.portableArchive!!.document.getAsJsonArray("paycheckReceipts").single().asJsonObject
        assertEquals("needsReview", sourceReceipt.getAsJsonObject("assessment").get("verdict").asString)
        assertTrue(sourceReceipt.getAsJsonObject("assessment").getAsJsonArray("reviewReasons").any { it.asString == "WEEKLY_REVIEW_PENDING" })
        val next = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(first.get("paycheckReceipts"), next.get("paycheckReceipts"))
        assertEquals(first.get("identityCrosswalk"), next.get("identityCrosswalk"))
        assertEquals(first.get("workSnapshots"), next.get("workSnapshots"))
        val backupState = androidLocalStateGson().fromJson(androidLocalStateGson().toJson(imported), AndroidLocalState::class.java)
        assertEquals(imported, AndroidLocalStateValidator.validate(backupState))
    }

    @Test fun canonicalTimeZoneNamesAreExactAndUnsupportedShortFormsCannotReplaceState() {
        val destination = sourceState()
        val before = androidLocalStateGson().toJson(destination)
        fun fixture(zone: String): com.google.gson.JsonObject {
            val root = JsonParser.parseString(File(System.getProperty("linepay.sharedContracts"), "portable-state/fixtures/common-weekly-pending.json").readText()).asJsonObject
            fun replaceZones(value: com.google.gson.JsonElement) {
                when {
                    value.isJsonObject -> value.asJsonObject.entrySet().toList().forEach { (key, child) ->
                        if (key == "timeZone" && child.isJsonPrimitive) value.asJsonObject.addProperty(key, zone) else replaceZones(child)
                    }
                    value.isJsonArray -> value.asJsonArray.forEach { replaceZones(it) }
                }
            }
            replaceZones(root)
            return root
        }
        for (zone in listOf("PST", "CST", "IST", "utc", "us/eastern", "america/New_York")) {
            assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(fixture(zone).toString().toByteArray()) }
            assertEquals(before, androidLocalStateGson().toJson(destination))
        }
        for (zone in listOf("US/Eastern", "US/Pacific", "UTC", "Etc/UTC")) {
            val source = fixture(zone)
            val restored = AndroidPortableStateCodec.decode(source.toString().toByteArray())
            val again = PortableStateJson.parse(AndroidPortableStateCodec.encode(restored, 1792281600))
            for (field in listOf("profiles", "ruleSnapshots", "periods", "workSnapshots", "paycheckReceipts")) assertEquals(source.get(field), again.get(field))
            assertEquals(zone, again.getAsJsonArray("profiles").first().asJsonObject.get("timeZone").asString)
        }
        // Canonical wire membership and runtime tzdb availability are independent admission gates.
        // EST is canonical but unavailable in JDK 21's ZoneId provider; other runtimes may support it.
        val available = java.time.ZoneId.getAvailableZoneIds()
        for (zone in listOf("EST", "CET")) {
            val source = fixture(zone)
            if (zone in available) {
                val restored = AndroidPortableStateCodec.decode(source.toString().toByteArray())
                val again = PortableStateJson.parse(AndroidPortableStateCodec.encode(restored, 1792281600))
                for (field in listOf("profiles", "ruleSnapshots", "periods", "workSnapshots", "paycheckReceipts")) assertEquals(source.get(field), again.get(field))
            } else {
                val error = assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(source.toString().toByteArray()) }
                assertTrue(error.message!!.contains("needs a supported IANA time zone"))
                assertEquals(before, androidLocalStateGson().toJson(destination))
            }
        }
    }

    @Test fun commonFixtureImportsWithoutInventingNativeVerdictAndUnknownFieldsRefuseWholeFile() {
        val fixture = File(System.getProperty("linepay.sharedContracts"), "portable-state/fixtures/common-weekly-pending.json").readBytes()
        val imported = AndroidPortableStateCodec.decode(fixture)
        assertEquals(5, imported.work.size)
        assertTrue(imported.checks.isEmpty())
        val before = Gson().toJson(imported)
        val malformed = JsonParser.parseString(fixture.toString(Charsets.UTF_8)).asJsonObject
        malformed.addProperty("trialDays", 365)
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(malformed.toString().toByteArray()) }
        assertEquals(before, Gson().toJson(imported))
    }

    @Test fun schemaFourMigrationAddsOnlyPortableBoundaryAndPreservesFinancialTrees() {
        val state = sourceState()
        val legacy = JsonParser.parseString(Gson().toJson(state)).asJsonObject
        legacy.addProperty("schemaVersion", 4)
        legacy.remove("portableArchive")
        val old = legacy.deepCopy()
        migrateAndroidLocalState(legacy)
        for (key in listOf("profile", "work", "checks", "weeklyReviews", "benefitReviews")) assertEquals(old[key], legacy[key])
        assertEquals(5, legacy.get("schemaVersion").asInt)
        assertTrue(legacy.get("portableArchive").isJsonNull)
        AndroidLocalStateValidator.validate(Gson().fromJson(legacy, AndroidLocalState::class.java))
    }
    @Test fun legacyComponentRecoveryUsesProvenSourceOrderRatherThanEqualAmounts() {
        val state = sourceState()
        val check = state.checks.single()
        assertEquals(5, check.components.size)
        assertEquals(1, check.components.map { it.amount }.toSet().size)
        assertTrue(check.components.all { it.id != null && it.workId != null })
        val legacy = check.copy(components = check.components.map { it.copy(id = null, workId = null) })
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(state.copy(checks = listOf(legacy)), 1792195200))
        val components = exported.getAsJsonArray("paycheckReceipts").single().asJsonObject
            .getAsJsonObject("calculation").getAsJsonArray("components")
        val originIDs = exported.getAsJsonArray("identityCrosswalk").map { it.asJsonObject }
            .filter { it.get("entityType").asString == "calculationComponent" }
            .associate { it.get("portableID").asString to it.get("originLocalID").asString }
        assertEquals(check.comparisons.single().componentIds, components.map { originIDs.getValue(it.asJsonObject.get("id").asString) })
        assertTrue(components.all { it.asJsonObject.get("workRef").isJsonNull })
        val bad = listOf(
            legacy.copy(engine = "unproven.source.engine/2"),
            legacy.copy(comparisons = listOf(legacy.comparisons.single().copy(componentIds = legacy.comparisons.single().componentIds.dropLast(1)))),
            legacy.copy(comparisons = listOf(legacy.comparisons.single().copy(componentIds = List(5) { legacy.comparisons.single().componentIds.first() }))),
        )
        bad.forEach { malformed ->
            assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.encode(state.copy(checks = listOf(malformed)), 1792195200) }
        }
    }

    @Test fun sameLogicalWorkIdentityKeepsDifferentFrozenVersionsAndRejectsCrossSnapshotReference() {
        val state = sourceState()
        val original = state.work.first()
        val corrected = original.copy(endEpochSeconds = original.endEpochSeconds - 3600, note = "Synthetic corrected current work")
        val changed = state.copy(work = listOf(corrected) + state.work.drop(1))
        val bytes = AndroidPortableStateCodec.encode(changed, 1792195200)
        val imported = AndroidPortableStateCodec.decode(bytes)
        assertEquals(corrected.endEpochSeconds, imported.work.first().endEpochSeconds)
        val root = imported.portableArchive!!.document
        val receipt = root.getAsJsonArray("paycheckReceipts").single().asJsonObject
        val frozen = root.getAsJsonArray("workSnapshots").single { it.asJsonObject.get("id") == receipt.get("workSnapshotRef") }.asJsonObject
        assertEquals(original.endEpochSeconds, frozen.getAsJsonArray("work").first().asJsonObject.get("endEpochSeconds").asLong)
        assertEquals("1000", receipt.getAsJsonObject("assessment").getAsJsonObject("expectedGross").get("amount").asString)
        val extra = AndroidWorkEntry(startEpochSeconds = original.startEpochSeconds - 86400, endEpochSeconds = original.endEpochSeconds - 86400, timeZone = "UTC", note = "Synthetic current-only work")
        val document = PortableStateJson.parse(AndroidPortableStateCodec.encode(state.copy(work = state.work + extra), 1792195200))
        val ledger = document.getAsJsonArray("workSnapshots").single { it.asJsonObject.get("role").asString == "currentLedger" }.asJsonObject
        val extraID = ledger.getAsJsonArray("work").last().asJsonObject.get("id").asString
        document.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("calculation")
            .getAsJsonArray("components").first().asJsonObject.addProperty("workRef", extraID)
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(document.toString().toByteArray()) }
    }

    @Test fun capabilityAndPendingRefusalsHappenBeforeAnyReplacement() {
        val state = sourceState()
        val before = androidLocalStateGson().toJson(state)
        val base = PortableStateJson.parse(AndroidPortableStateCodec.encode(state, 1792195200))
        val mutations: List<(com.google.gson.JsonObject) -> Unit> = listOf(
            { it.getAsJsonArray("workSnapshots").first().asJsonObject.getAsJsonArray("work").first().asJsonObject.addProperty("kind", "unrecognizedWork") },
            { it.getAsJsonArray("paycheckReceipts").first().asJsonObject.getAsJsonObject("assessment").addProperty("verdict", "matches") },
            { it.getAsJsonArray("profiles").first().asJsonObject.addProperty("ruleRef", "missing-rule") },
            { it.getAsJsonObject("sourceInventory").getAsJsonArray("unsupportedFinancialRecordKinds").add("benefitReceipt") },
            { it.getAsJsonObject("sourceInventory").addProperty("omittedFinancialRecordCount", 1) },
        )
        mutations.forEach { mutate ->
            val invalid = base.deepCopy(); mutate(invalid)
            assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(invalid.toString().toByteArray()) }
            assertEquals(before, androidLocalStateGson().toJson(state))
        }
    }

    @Test fun typedUnsupportedRulesStayFrozenAndRequireNewNativeConfiguration() {
        val document = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val rule = document.getAsJsonArray("ruleSnapshots").single().asJsonObject
        rule.addProperty("calloutMinimumHours", "2")
        rule.add("datePremiums", JsonParser.parseString("[{\"date\":\"2026-10-12\",\"multiplier\":\"2\"}]"))
        val imported = AndroidPortableStateCodec.decode(document.toString().toByteArray())
        assertTrue(imported.profile!!.requiresPortableRuleConfirmation)
        assertTrue("calloutMinimumHours" in imported.profile.portableRuleFieldsNeedingConfirmation.orEmpty())
        assertTrue("datePremiums" in imported.profile.portableRuleFieldsNeedingConfirmation.orEmpty())
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(imported) }
        val reexported = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(document.get("ruleSnapshots"), reexported.get("ruleSnapshots"))
        assertEquals(document.get("paycheckReceipts"), reexported.get("paycheckReceipts"))
    }

    private fun nativeAdoptionProfile() = AndroidRuleProfile(
        hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true,
        hasIndependentEffectiveDates = true, effectiveStartDate = "2026-10-12",
    )

    @Test fun highPrecisionSourceRateStaysExactReadOnlyThroughRelaunchExportAndExplicitAdoption() {
        val source = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val exactRate = "0.12345678901234567890123456789012345678901234567890"
        source.getAsJsonArray("ruleSnapshots").single().asJsonObject.addProperty("hourlyRate", exactRate)
        val retained = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        assertEquals(null, retained.profile)
        assertTrue(retained.work.isEmpty()) // Source work remains in its typed archive, never projected as a substitute native ledger.
        assertTrue(AndroidPortableStateCodec.requiresSeparateNativeLedger(retained))
        assertEquals(null, LinePaycheckRepository.currentPeriod(retained))
        val reopened = androidLocalStateGson().fromJson(androidLocalStateGson().toJson(retained), AndroidLocalState::class.java)
        AndroidLocalStateValidator.validate(reopened)
        val beforeAdoption = PortableStateJson.parse(AndroidPortableStateCodec.encode(reopened, 1792281600))
        for (field in listOf("profiles", "ruleSnapshots", "workSnapshots", "periods", "paycheckReceipts")) assertEquals(source.get(field), beforeAdoption.get(field))
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.adopt(retained, nativeAdoptionProfile(), 1792281600) }
        val adopted = AndroidPortableStateCodec.adopt(retained, nativeAdoptionProfile(), 1792281600, startNewWorkLedger = true)
        assertTrue(adopted.work.isEmpty())
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792281600))
        assertEquals(exactRate, after.getAsJsonArray("ruleSnapshots").first { it.asJsonObject.get("id") == source.getAsJsonArray("ruleSnapshots").single().asJsonObject.get("id") }.asJsonObject.get("hourlyRate").asString)
        assertEquals(source.get("paycheckReceipts"), after.get("paycheckReceipts"))
        assertEquals(source, retained.portableArchive!!.document) // Preview/cancel never mutates original source facts.
    }

    @Test fun unknownProfileContextIsRetainedWithoutInventingTimezoneCadenceOrDates() {
        val source = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profile = source.getAsJsonArray("profiles").single().asJsonObject
        for (field in listOf("timeZone", "cadence", "cycleStartDate")) { profile.add(field, com.google.gson.JsonNull.INSTANCE); profile.getAsJsonArray("fieldsNotRecorded").add(field) }
        val imported = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        assertEquals(null, imported.profile)
        assertEquals(profile, AndroidPortableStateCodec.sourceProfileForReview(imported))
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(source.get("profiles"), exported.get("profiles"))
        val adopted = AndroidPortableStateCodec.adopt(imported, nativeAdoptionProfile(), 1792281600, startNewWorkLedger = true)
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792281600))
        assertEquals(profile, after.getAsJsonArray("profiles").single { it.asJsonObject.get("id") == profile.get("id") })
        assertEquals(source.get("paycheckReceipts"), after.get("paycheckReceipts"))
    }

    @Test fun usableCurrentAIsIndependentOfUnprojectableFutureDefaultB() {
        val root = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profileA = root.getAsJsonArray("profiles").single().asJsonObject
        val ruleA = root.getAsJsonArray("ruleSnapshots").single().asJsonObject
        val periodA = root.getAsJsonArray("periods").single().asJsonObject
        periodA.addProperty("isCurrent", true)
        periodA.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("isCurrent"))
        periodA.addProperty("currentWorkSnapshotRef", profileA.get("currentWorkSnapshotRef").asString)
        periodA.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentWorkSnapshotRef"))
        periodA.getAsJsonArray("workSnapshotRefs").add(profileA.get("currentWorkSnapshotRef").asString)
        val profileB = profileA.deepCopy(); val ruleB = ruleA.deepCopy()
        profileB.addProperty("id", "synthetic.future-unknown-profile-B"); ruleB.addProperty("id", "synthetic.future-precise-rule-B")
        ruleB.addProperty("ruleID", "synthetic.future-B-rule")
        profileB.addProperty("ruleRef", ruleB.get("id").asString); profileB.addProperty("baselineRuleRef", ruleB.get("id").asString)
        profileB.add("currentWorkSnapshotRef", com.google.gson.JsonNull.INSTANCE)
        profileB.getAsJsonArray("fieldsNotRecorded").add("currentWorkSnapshotRef")
        for (field in listOf("timeZone", "cadence", "cycleStartDate")) { profileB.add(field, com.google.gson.JsonNull.INSTANCE); profileB.getAsJsonArray("fieldsNotRecorded").add(field) }
        ruleB.addProperty("hourlyRate", "0.12345678901234567890123456789012345678901234567890")
        root.getAsJsonArray("profiles").add(profileB); root.getAsJsonArray("ruleSnapshots").add(ruleB)
        root.addProperty("activeProfileRef", profileB.get("id").asString)
        for ((kind, id) in listOf("profile" to profileB.get("id").asString, "ruleSnapshot" to ruleB.get("id").asString)) root.getAsJsonArray("identityCrosswalk").add(
            com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(mapOf("entityType" to kind, "portableID" to id, "originClient" to "web", "originKind" to "derived", "originLocalID" to null)))
        root.getAsJsonObject("sourceInventory").apply { addProperty("profileCount", 2); addProperty("ruleSnapshotCount", 2) }
        val imported = AndroidPortableStateCodec.decode(root.toString().toByteArray())
        assertTrue(imported.profile != null)
        assertTrue(!imported.profile!!.requiresPortableRuleConfirmation)
        assertEquals("25", imported.profile.hourlyRate)
        assertTrue(portableFutureDefaultLabel(imported)!!.contains(ruleB.get("hourlyRate").asString))
        assertEquals(5, imported.work.size)
        assertTrue(LinePaycheckRepository.currentPeriod(imported) != null)
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(profileB.get("id"), after.get("activeProfileRef"))
        assertTrue(after.getAsJsonArray("profiles").any { it == profileB })
        assertTrue(after.getAsJsonArray("ruleSnapshots").any { it == ruleB })
    }

    @Test fun defaultProfilePointerCannotActivateAnExplicitlyClosedNoncurrentContext() {
        val source = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profile = source.getAsJsonArray("profiles").single().asJsonObject
        val period = source.getAsJsonArray("periods").single().asJsonObject
        profile.addProperty("currentPeriodRef", period.get("id").asString)
        profile.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
        period.addProperty("isCurrent", false); period.addProperty("closed", true)
        for (field in listOf("isCurrent", "closed")) period.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive(field))
        val imported = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        assertTrue(imported.profile!!.requiresPortableRuleConfirmation)
        assertTrue("noCurrentWorkspace" in imported.profile.portableRuleFieldsNeedingConfirmation.orEmpty())
        assertEquals(null, portableCurrentPeriodLabel(imported))
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(imported) }
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(source.get("profiles"), exported.get("profiles"))
        assertEquals(source.get("periods"), exported.get("periods"))
    }

    @Test fun futureRuleChangeIsFrozenConfigurationAndDoesNotExtendCurrentWorkWindow() {
        val source = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profile = source.getAsJsonArray("profiles").single().asJsonObject
        val period = source.getAsJsonArray("periods").single().asJsonObject
        val changeID = "synthetic.future-rule-change"
        val change = com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(mapOf(
            "id" to changeID, "profileRef" to profile.get("id").asString, "periodRef" to period.get("id").asString,
            "effectiveDate" to "2026-10-19", "sourceProfileRef" to profile.get("id").asString, "ruleRef" to profile.get("ruleRef").asString,
            "confirmed" to true, "createdAtEpochSeconds" to 1792195200, "fieldsNotRecorded" to emptyList<String>(),
        )).asJsonObject
        source.getAsJsonArray("ruleChanges").add(change)
        period.getAsJsonArray("ruleChangeRefs").add(changeID)
        profile.getAsJsonArray("ruleChangeRefs").add(changeID)
        source.getAsJsonArray("identityCrosswalk").add(com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(mapOf(
            "entityType" to "ruleChange", "portableID" to changeID, "originClient" to "ios", "originKind" to "derived", "originLocalID" to null)))
        source.getAsJsonObject("sourceInventory").addProperty("ruleChangeCount", 1)
        val imported = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        assertTrue(imported.profile!!.requiresPortableRuleConfirmation)
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(imported) }
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(source.get("ruleChanges"), after.get("ruleChanges"))
        assertEquals(source.get("periods"), after.get("periods"))
    }

    @Test fun actualWebKitProviderKeepsWebWeeklyWarningAndOriginalForeignReceipts() {
        // Synthetic real WebKit download: ciphertext SHA a6471ac98584da3031ae752842bfeb6e3994cd63cb4580ad46319883f8a7ad87.
        val bytes = requireNotNull(javaClass.getResourceAsStream("/portable/webkit-a647-provider.json")).use { it.readBytes() }
        val original = PortableStateJson.parse(bytes)
        val imported = AndroidPortableStateCodec.decode(bytes)
        val webReceipt = original.getAsJsonArray("paycheckReceipts").single { it.asJsonObject.getAsJsonObject("producer").get("client").asString == "web" }.asJsonObject
        assertEquals("needsReview", webReceipt.getAsJsonObject("assessment").get("verdict").asString)
        assertTrue(webReceipt.getAsJsonObject("reviewFacts").get("weeklyReviewPending").asBoolean)
        assertEquals("A separate complete-workweek review is pending.", webReceipt.getAsJsonObject("assessment").getAsJsonArray("reviewReasons").single().asString)
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        for (field in listOf("profiles", "ruleSnapshots", "periods", "workSnapshots", "paycheckReceipts")) assertEquals(original.get(field), exported.get(field))
    }

    @Test fun weeklyPendingRegistryAcceptsOnlyEstablishedExactReasonsAndRejectsFlagContradictions() {
        val knownReasons = listOf(
            "WEEKLY_REVIEW_PENDING",
            "A separate complete-workweek review is pending.",
            "Complete workweek coverage and any additional weekly premium are not mapped into this paycheck comparison. A pay-period hour total or a separate weekly result does not establish that mapping. Review the complete workweek before relying on the gross difference.",
        )
        for (reason in knownReasons) {
            val original = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
            val receipt = original.getAsJsonArray("paycheckReceipts").single().asJsonObject
            receipt.getAsJsonObject("assessment").add("reviewReasons", com.google.gson.JsonArray().apply { add(reason) })
            AndroidPortableStateCodec.decode(original.toString().toByteArray())
            receipt.getAsJsonObject("reviewFacts").addProperty("weeklyReviewPending", false)
            assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(original.toString().toByteArray()) }
        }
    }

    @Test fun unrelatedWeeklyPendingTextCannotStandInForTheSourceReviewReason() {
        for (unrelated in listOf("Weekly weather notes are pending review.", "weekly pending", "A separate complete-workweek review is pending!")) {
            val original = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
            original.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("assessment")
                .add("reviewReasons", com.google.gson.JsonArray().apply { add(unrelated) })
            assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(original.toString().toByteArray()) }
        }
    }

    @Test fun nullableReferenceCollectionsPreserveUnknownVersusKnownEmptyAndRejectMarkerContradiction() {
        val source = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val assessment = source.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("assessment")
        val knownEmpty = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        assertTrue(knownEmpty.portableArchive!!.document.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("assessment").get("weeklyReviewRefs").isJsonArray)
        assessment.add("weeklyReviewRefs", com.google.gson.JsonNull.INSTANCE)
        assessment.getAsJsonArray("fieldsNotRecorded").add("weeklyReviewRefs")
        val unknown = AndroidPortableStateCodec.decode(source.toString().toByteArray())
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(unknown, 1792281600))
        assertEquals(source.get("paycheckReceipts"), exported.get("paycheckReceipts"))
        assessment.add("weeklyReviewRefs", com.google.gson.JsonArray())
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(source.toString().toByteArray()) }
    }

    @Test fun actualFinalIosProviderRetainsNullableReferencesAndEveryOriginalReceipt() {
        val bytes = requireNotNull(javaClass.getResourceAsStream("/portable/ios-66a3-provider.json")).use { it.readBytes() }
        val source = PortableStateJson.parse(bytes)
        val state = AndroidPortableStateCodec.decode(bytes)
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(state, 1792281600))
        for (field in listOf("paycheckReceipts", "ruleSnapshots", "workSnapshots")) assertEquals(source.get(field), after.get(field))
        assertTrue(source.getAsJsonArray("paycheckReceipts").any { it.asJsonObject.getAsJsonObject("assessment").get("weeklyReviewRefs").isJsonNull })
    }

    @Test fun separateWeeklyReceiptBlocksPortableExportAndPreservesSourceState() {
        val state = sourceState()
        val weekly = AndroidWeeklyReviewRepository.preview(state, AndroidWeeklyReviewRequest(
            "2026-10-12 00:00", "UTC", listOf(state.checks.single().id), "1000",
            boundaryConfirmed = true, singleEmployerConfirmed = true, paymentsConfirmed = true,
            completeWorkweek = true, applicabilityConfirmed = true,
        ), 1792195200)
        val withWeekly = AndroidWeeklyReviewRepository.append(state, weekly)
        val before = Gson().toJson(withWeekly)
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.encode(withWeekly, 1792195200) }
        assertEquals(before, Gson().toJson(withWeekly))
    }

    @Test fun unknownSourceRulesRequireSeparateAdoptionAndFreezeLineageAcrossLaterEdits() {
        val bytes = File(System.getProperty("linepay.sharedContracts"), "portable-state/fixtures/common-weekly-pending.json").readBytes()
        val imported = AndroidPortableStateCodec.decode(bytes)
        val originalDocument = imported.portableArchive!!.document.deepCopy()
        val sourceProfile = imported.profile!!
        assertTrue(sourceProfile.requiresPortableRuleConfirmation)
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(imported) }
        assertThrows(IllegalArgumentException::class.java) {
            LinePaycheckRepository.addWork(imported, "2026-10-26 07:00", "2026-10-26 15:00", "", "", "Synthetic blocked work")
        }
        val beforeConfirmation = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792799999))
        assertEquals(originalDocument.get("profiles"), beforeConfirmation.get("profiles"))
        assertEquals(originalDocument.get("ruleSnapshots"), beforeConfirmation.get("ruleSnapshots"))
        val unchanged = androidLocalStateGson().fromJson(androidLocalStateGson().toJson(imported), AndroidLocalState::class.java)
        assertEquals(imported, AndroidLocalStateValidator.validate(unchanged))
        val confirmed = sourceProfile.copy(id = java.util.UUID.randomUUID().toString(), version = "1", rulesReviewedByWorker = true,
            requiresPortableRuleConfirmation = false, importedSourceProfileRef = null, calculationRuleID = null, portableRuleFieldsNeedingConfirmation = emptyList(),
            effectiveStartDate = sourceProfile.cycleStartDate, effectiveEndDateInclusive = null, useAsFutureDefault = true)
        val adopted = AndroidPortableStateCodec.adopt(imported, confirmed, 1792799999)
        assertEquals(originalDocument, adopted.portableArchive!!.document)
        assertTrue(adopted.profile!!.id != sourceProfile.id)
        val firstExport = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792799999))
        assertEquals(2, firstExport.getAsJsonArray("profiles").size())
        assertEquals(originalDocument.get("paycheckReceipts"), firstExport.get("paycheckReceipts"))
        val newProfileRef = firstExport.get("activeProfileRef").asString
        assertTrue(newProfileRef != originalDocument.get("activeProfileRef").asString)
        val later = adopted.copy(profile = confirmed.copy(version = "2", hourlyRate = "30"))
        val laterExport = PortableStateJson.parse(AndroidPortableStateCodec.encode(later, 1792800000))
        assertEquals(firstExport.get("adoptions"), laterExport.get("adoptions"))
        assertEquals(originalDocument.get("paycheckReceipts"), laterExport.get("paycheckReceipts"))
        assertEquals(1, laterExport.getAsJsonArray("adoptions").size())
        val reopened = AndroidPortableStateCodec.decode(laterExport.toString().toByteArray())
        assertTrue(!reopened.profile!!.requiresPortableRuleConfirmation)
        assertEquals("30", reopened.profile.hourlyRate)
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location ->
            File(location).mkdirs()
            File(location, "android-adopted-roundtrip.json").writeText(laterExport.toString())
        }
    }

    @Test fun allSharedAndroidAndStructuralRefusalCasesRejectTheWholeDocument() {
        val directory = File(System.getProperty("linepay.sharedContracts"), "portable-state/fixtures")
        val cases = JsonParser.parseString(File(directory, "refusal-cases-v1.json").readText()).asJsonObject.getAsJsonArray("cases")
        var checked = 0
        cases.map { it.asJsonObject }.filter { !it.has("target") || it.get("target").asString == "android" }.forEach { case ->
            val fixture = case.get("baseFixture")?.asString ?: "common-weekly-pending.json"
            val document = JsonParser.parseString(File(directory, fixture).readText()).asJsonObject
            case.getAsJsonArray("operations").forEach { encoded ->
                val operation = encoded.asJsonObject
                val parts = operation.get("path").asString.removePrefix("/").split('/').map { it.replace("~1", "/").replace("~0", "~") }
                var parent: com.google.gson.JsonElement = document
                parts.dropLast(1).forEach { key -> parent = if (parent.isJsonArray) parent.asJsonArray[key.toInt()] else parent.asJsonObject.get(key) }
                val key = parts.last()
                if (parent.isJsonArray && operation.get("op").asString == "remove") parent.asJsonArray.remove(key.toInt())
                else if (parent.isJsonArray && key == "-" && operation.get("op").asString == "add") parent.asJsonArray.add(operation.get("value").deepCopy())
                else if (parent.isJsonArray) parent.asJsonArray.set(key.toInt(), operation.get("value").deepCopy())
                else if (operation.get("op").asString == "remove") parent.asJsonObject.remove(key)
                else parent.asJsonObject.add(key, operation.get("value").deepCopy())
            }
            if (case.get("activationReview")?.asBoolean == true) {
                val retained = AndroidPortableStateCodec.decode(document.toString().toByteArray())
                assertTrue(retained.profile!!.requiresPortableRuleConfirmation)
                assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(retained) }
                val again = PortableStateJson.parse(AndroidPortableStateCodec.encode(retained, 1792281600))
                assertEquals(document.get("workSnapshots"), again.get("workSnapshots"))
                assertEquals(document.get("paycheckReceipts"), again.get("paycheckReceipts"))
                val confirmed = retained.profile.copy(id = java.util.UUID.randomUUID().toString(), version = "1", rulesReviewedByWorker = true,
                    requiresPortableRuleConfirmation = false, importedSourceProfileRef = null, calculationRuleID = null, portableRuleFieldsNeedingConfirmation = emptyList())
                assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.adopt(retained, confirmed, 1792281600) }
                val adopted = AndroidPortableStateCodec.adopt(retained, confirmed, 1792281600, startNewWorkLedger = true)
                assertTrue(adopted.work.isEmpty())
                val adoptedExport = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792281600))
                document.getAsJsonArray("workSnapshots").forEach { original -> assertTrue(adoptedExport.getAsJsonArray("workSnapshots").any { it == original }) }
            } else assertThrows(case.get("id").asString, Exception::class.java) { AndroidPortableStateCodec.decode(document.toString().toByteArray()) }
            checked++
        }
        assertEquals(cases.count { !it.asJsonObject.has("target") || it.asJsonObject.get("target").asString == "android" }, checked)
    }

    @Test fun actualLegacyProfileFieldsAbsentInSchemaFourKeepOriginalWagesAndReceipts() {
        val state = sourceState()
        val tree = JsonParser.parseString(Gson().toJson(state)).asJsonObject
        tree.addProperty("schemaVersion", 4)
        tree.remove("portableArchive")
        val newFields = listOf("hasIndependentEffectiveDates", "effectiveStartDate", "effectiveEndDateInclusive", "requiresPortableRuleConfirmation", "importedSourceProfileRef", "calculationRuleID", "portableRuleFieldsNeedingConfirmation")
        newFields.forEach { tree.getAsJsonObject("profile").remove(it) }
        tree.getAsJsonArray("checks").forEach { check ->
            newFields.forEach { check.asJsonObject.getAsJsonObject("profile").remove(it) }
            check.asJsonObject.getAsJsonArray("components").forEach { it.asJsonObject.remove("id"); it.asJsonObject.remove("workId") }
        }
        val original = tree.deepCopy()
        migrateAndroidLocalState(tree)
        val migrated = androidLocalStateGson().fromJson(tree, AndroidLocalState::class.java)
        AndroidLocalStateValidator.validate(migrated)
        assertEquals("1000", LinePaycheckRepository.currentPeriod(migrated)!!.expectedWages)
        assertTrue(!migrated.profile!!.requiresPortableRuleConfirmation)
        assertTrue(migrated.checks.single().components.all { it.id == null && it.workId == null })
        for (key in listOf("profile", "work", "checks", "weeklyReviews", "benefitReviews")) assertEquals(original[key], tree[key])
        AndroidPortableStateCodec.decode(AndroidPortableStateCodec.encode(migrated, 1792195200))
    }

    @Test fun fullyRecordedImportAcceptsNewWorkWhileFrozenFactsAndRulesRemainUnchanged() {
        val imported = AndroidPortableStateCodec.decode(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        assertTrue(!imported.profile!!.requiresPortableRuleConfirmation)
        val original = imported.portableArchive!!.document.deepCopy()
        val next = LinePaycheckRepository.addWork(imported, "2026-10-17 07:00", "2026-10-17 15:00", "", "", "Synthetic new work after restore")
        assertEquals("1200", LinePaycheckRepository.currentPeriod(next)!!.expectedWages)
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(next, 1792281600))
        assertEquals(original.get("ruleSnapshots"), exported.get("ruleSnapshots"))
        assertEquals(original.get("paycheckReceipts"), exported.get("paycheckReceipts"))
        original.getAsJsonArray("workSnapshots").forEach { snapshot ->
            assertEquals(snapshot, exported.getAsJsonArray("workSnapshots").single { it.asJsonObject.get("id") == snapshot.asJsonObject.get("id") })
        }
        val oldProfile = original.getAsJsonArray("profiles").single().asJsonObject.deepCopy()
        val newProfile = exported.getAsJsonArray("profiles").single().asJsonObject.deepCopy()
        assertTrue(oldProfile.get("currentWorkSnapshotRef") != newProfile.get("currentWorkSnapshotRef"))
        oldProfile.remove("currentWorkSnapshotRef"); newProfile.remove("currentWorkSnapshotRef")
        assertEquals(oldProfile, newProfile)
        val withNewCheck = LinePaycheckRepository.savePaycheck(next, AndroidPaycheckInput(
            "2026-10-12", "2026-10-18", "UTC", true, "1200", GrossBasisChoice.WAGES_ONLY, true, true,
        ), 1792281600).first
        val finalExport = PortableStateJson.parse(AndroidPortableStateCodec.encode(withNewCheck, 1792281600))
        assertEquals(2, finalExport.getAsJsonArray("paycheckReceipts").size())
        val originalReceipt = original.getAsJsonArray("paycheckReceipts").single()
        assertEquals(originalReceipt, finalExport.getAsJsonArray("paycheckReceipts").single { it.asJsonObject.get("id") == originalReceipt.asJsonObject.get("id") })
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location ->
            File(location).mkdirs()
            File(location, "android-known-import-new-work.json").writeText(finalExport.toString())
        }
    }

    @Test fun newWorkDoesNotReattachFrozenPeriodCalculationToChangedInputs() {
        val root = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profile = root.getAsJsonArray("profiles").single().asJsonObject
        val period = root.getAsJsonArray("periods").single().asJsonObject
        val ledgerRef = profile.get("currentWorkSnapshotRef").asString
        period.addProperty("currentWorkSnapshotRef", ledgerRef)
        period.addProperty("isCurrent", true)
        period.getAsJsonArray("workSnapshotRefs").add(ledgerRef)
        for (field in listOf("currentWorkSnapshotRef", "isCurrent", "calculation")) period.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive(field))
        profile.addProperty("currentPeriodRef", period.get("id").asString)
        profile.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
        period.add("calculation", root.getAsJsonArray("paycheckReceipts").single().asJsonObject.get("calculation").deepCopy())
        root.getAsJsonObject("sourceInventory").addProperty("calculationComponentCount", 10)
        val oldPeriod = period.deepCopy()
        val imported = AndroidPortableStateCodec.decode(root.toString().toByteArray())
        val changed = LinePaycheckRepository.addWork(imported, "2026-10-17 07:00", "2026-10-17 15:00", "", "", "Synthetic added shift")
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(changed, 1792281600))
        val retained = after.getAsJsonArray("periods").single { it.asJsonObject.get("id") == oldPeriod.get("id") }.asJsonObject
        oldPeriod.addProperty("isCurrent", false)
        assertEquals(oldPeriod, retained)
        val selected = after.getAsJsonArray("periods").single { it.asJsonObject.get("isCurrent").takeUnless { value -> value.isJsonNull }?.asBoolean == true }.asJsonObject
        assertTrue(selected.get("id") != retained.get("id"))
        assertTrue(selected.get("calculation").isJsonNull)
        assertEquals(root.get("paycheckReceipts"), after.get("paycheckReceipts"))
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location -> File(location).mkdirs(); File(location, "android-frozen-period-new-work.json").writeText(after.toString()) }
    }

    @Test fun correctedCurrentWindowNeverBecomesAProfileDerivedPeriodBeforeConfirmation() {
        val document = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val profile = document.getAsJsonArray("profiles").single().asJsonObject
        val period = document.getAsJsonArray("periods").single().asJsonObject
        profile.addProperty("currentPeriodRef", period.get("id").asString)
        profile.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
        period.addProperty("isCurrent", true)
        period.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("isCurrent"))
        period.addProperty("cadence", "custom")
        period.getAsJsonObject("calendarWindow").addProperty("endDateInclusive", "2026-10-25")
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(document.toString().toByteArray()) } // A corrected window requires a distinct frozen identity.
        period.addProperty("windowRef", "synthetic.corrected-current-window")
        document.getAsJsonArray("identityCrosswalk").add(com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(mapOf("entityType" to "periodWindow", "portableID" to "synthetic.corrected-current-window", "originClient" to "web", "originKind" to "derived", "originLocalID" to null)))
        document.getAsJsonObject("sourceInventory").addProperty("periodWindowCount", 2)
        period.getAsJsonObject("calendarWindow").addProperty("endDateInclusive", "2026-10-25")
        val imported = AndroidPortableStateCodec.decode(document.toString().toByteArray())
        assertTrue(imported.profile!!.requiresPortableRuleConfirmation)
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.currentPeriod(imported) }
        assertTrue(portableCurrentPeriodLabel(imported)!!.contains("2026-10-25"))
        val beforeConfirmation = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(document.get("periods"), beforeConfirmation.get("periods"))
        assertEquals(document.get("paycheckReceipts"), beforeConfirmation.get("paycheckReceipts"))
        val confirmed = imported.profile.copy(id = java.util.UUID.randomUUID().toString(), version = "1", cadence = PayCycleChoice.CUSTOM,
            customLastDate = "2026-10-25", rulesReviewedByWorker = true, requiresPortableRuleConfirmation = false,
            importedSourceProfileRef = null, calculationRuleID = null, portableRuleFieldsNeedingConfirmation = emptyList())
        val adopted = AndroidPortableStateCodec.adopt(imported, confirmed, 1792281600)
        assertEquals("2026-10-25", LinePaycheckRepository.payWindow(adopted.profile!!).lastDate.toString())
        val after = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792281600))
        val retainedPeriod = after.getAsJsonArray("periods").single { it.asJsonObject.get("id") == period.get("id") }.asJsonObject
        assertEquals(period.get("calendarWindow"), retainedPeriod.get("calendarWindow"))
        assertEquals(period.get("cadence"), retainedPeriod.get("cadence"))
        assertTrue(!retainedPeriod.get("isCurrent").asBoolean)
        assertEquals(1, after.getAsJsonArray("periods").count { it.asJsonObject.get("isCurrent").takeUnless { value -> value.isJsonNull }?.asBoolean == true })
        assertEquals(document.get("paycheckReceipts"), after.get("paycheckReceipts"))
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location ->
            File(location).mkdirs(); File(location, "android-corrected-window.json").writeText(after.toString())
        }
    }

    @Test fun embeddedFrozenWeeklyResultsRetainOriginalIDsAllocationsAndPendingReasons() {
        fun objectOf(vararg fields: Pair<String, Any?>): com.google.gson.JsonObject =
            com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(fields.toMap()).asJsonObject
        fun money(value: String) = objectOf("amount" to value, "currency" to "USD")
        val root = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val receipt = root.getAsJsonArray("paycheckReceipts").single().asJsonObject
        val period = root.getAsJsonArray("periods").single().asJsonObject
        val weekly = objectOf("workweekID" to "synthetic.frozen-week-1", "weekStart" to "2026-10-12", "workweekStart" to "monday",
            "qualifyingHours" to "40", "includableRemuneration" to money("1000"), "regularRate" to money("25"), "overtimeHours" to "0",
            "statutoryAdditionalPremium" to money("0"), "eligibleExtraPremiumCredit" to money("0"), "remainingAdditionalPremium" to money("0"),
            "cashRemuneration" to money("1000"), "expectedCash" to money("1000"),
            "allocations" to listOf(objectOf("id" to "synthetic.frozen-allocation-1", "periodRef" to period.get("id").asString, "amount" to money("0"), "basis" to money("1000"))),
            "engineVersion" to "synthetic.foreign-weekly/7", "startEpochSeconds" to null, "endEpochSeconds" to null, "timeZone" to null,
            "fieldsNotRecorded" to listOf("startEpochSeconds", "endEpochSeconds", "timeZone"))
        val calculation = receipt.getAsJsonObject("calculation")
        calculation.add("weeklyRegularRate", weekly)
        calculation.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("weeklyRegularRate"))
        for ((kind, id) in listOf("workweek" to "synthetic.frozen-week-1", "weeklyAllocation" to "synthetic.frozen-allocation-1")) {
            root.getAsJsonArray("identityCrosswalk").add(objectOf("entityType" to kind, "portableID" to id, "originClient" to "web", "originKind" to "derived", "originLocalID" to null))
        }
        val inventory = root.getAsJsonObject("sourceInventory")
        inventory.addProperty("workweekCount", 1); inventory.addProperty("weeklyAllocationCount", 1)
        val wrongPeriodCalculation = root.deepCopy()
        wrongPeriodCalculation.getAsJsonArray("periods").single().asJsonObject.apply {
            add("calculation", calculation.deepCopy())
            getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("calculation"))
        }
        wrongPeriodCalculation.getAsJsonObject("sourceInventory").apply {
            addProperty("workweekCount", 2); addProperty("weeklyAllocationCount", 2); addProperty("calculationComponentCount", 10)
        }
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.decode(wrongPeriodCalculation.toString().toByteArray()) }
        val imported = AndroidPortableStateCodec.decode(root.toString().toByteArray())
        assertTrue(imported.weeklyReviews.isEmpty())
        assertTrue(imported.checks.isEmpty())
        val reexported = PortableStateJson.parse(AndroidPortableStateCodec.encode(imported, 1792281600))
        assertEquals(root.get("paycheckReceipts"), reexported.get("paycheckReceipts"))
        assertEquals(root.get("periods"), reexported.get("periods"))
        assertEquals("needsReview", reexported.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("assessment").get("verdict").asString)
        assertEquals(weekly, reexported.getAsJsonArray("paycheckReceipts").single().asJsonObject.getAsJsonObject("calculation").get("weeklyRegularRate"))
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location ->
            File(location).mkdirs(); File(location, "android-foreign-weekly-roundtrip.json").writeText(reexported.toString())
        }
    }

    @Test fun currentAAndSavedFutureBRemainSeparateWhenNewCurrentCIsConfirmed() {
        fun objectOf(vararg fields: Pair<String, Any?>) = com.google.gson.GsonBuilder().serializeNulls().create().toJsonTree(fields.toMap()).asJsonObject
        val root = PortableStateJson.parse(AndroidPortableStateCodec.encode(sourceState(), 1792195200))
        val sourceA = root.getAsJsonArray("profiles").single().asJsonObject
        val periodA = root.getAsJsonArray("periods").single().asJsonObject
        sourceA.addProperty("name", "Current profile A")
        sourceA.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("name"))
        sourceA.addProperty("currentPeriodRef", periodA.get("id").asString)
        sourceA.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("currentPeriodRef"))
        periodA.addProperty("isCurrent", true)
        periodA.getAsJsonArray("fieldsNotRecorded").remove(com.google.gson.JsonPrimitive("isCurrent"))
        val futureB = sourceA.deepCopy()
        futureB.addProperty("id", "synthetic.profile.future-B"); futureB.addProperty("name", "Future profile B")
        futureB.addProperty("cycleStartDate", "2026-10-26"); futureB.addProperty("ruleRef", "synthetic.rule.future-B")
        futureB.addProperty("baselineRuleRef", "synthetic.rule.future-B"); futureB.add("currentPeriodRef", com.google.gson.JsonNull.INSTANCE)
        futureB.addProperty("currentWorkSnapshotRef", "synthetic.ledger.future-B")
        val ruleB = root.getAsJsonArray("ruleSnapshots").single().asJsonObject.deepCopy()
        ruleB.addProperty("id", "synthetic.rule.future-B"); ruleB.addProperty("ruleID", "synthetic-native-rule-B")
        ruleB.addProperty("hourlyRate", "30"); ruleB.addProperty("effectiveStartDate", "2026-10-26")
        val ledgerB = objectOf("id" to "synthetic.ledger.future-B", "profileRef" to "synthetic.profile.future-B", "periodRef" to null,
            "role" to "currentLedger", "revision" to null, "sourceRef" to null, "work" to emptyList<Any>(), "fieldsNotRecorded" to listOf("revision", "sourceRef"))
        root.getAsJsonArray("profiles").add(futureB); root.getAsJsonArray("ruleSnapshots").add(ruleB); root.getAsJsonArray("workSnapshots").add(ledgerB)
        for ((kind, id) in listOf("profile" to "synthetic.profile.future-B", "ruleSnapshot" to "synthetic.rule.future-B", "workSnapshot" to "synthetic.ledger.future-B")) root.getAsJsonArray("identityCrosswalk").add(objectOf("entityType" to kind, "portableID" to id, "originClient" to "web", "originKind" to "derived", "originLocalID" to null))
        root.addProperty("activeProfileRef", "synthetic.profile.future-B")
        root.getAsJsonObject("sourceInventory").apply { addProperty("profileCount", 2); addProperty("ruleSnapshotCount", 2); addProperty("workSnapshotCount", 3) }
        val imported = AndroidPortableStateCodec.decode(root.toString().toByteArray())
        assertEquals(5, imported.work.size)
        assertEquals("25", imported.profile!!.hourlyRate)
        assertEquals("1000", LinePaycheckRepository.currentPeriod(imported)!!.expectedWages)
        assertTrue(portableFutureDefaultLabel(imported)!!.contains("Future profile B"))
        val currentC = imported.profile.copy(id = java.util.UUID.randomUUID().toString(), version = "1", hourlyRate = "32",
            requiresPortableRuleConfirmation = false, importedSourceProfileRef = null, calculationRuleID = null,
            portableRuleFieldsNeedingConfirmation = emptyList(), useAsFutureDefault = false)
        val adopted = AndroidPortableStateCodec.adopt(imported, currentC, 1792281600)
        val exported = PortableStateJson.parse(AndroidPortableStateCodec.encode(adopted, 1792281600))
        assertEquals("synthetic.profile.future-B", exported.get("activeProfileRef").asString)
        assertEquals(futureB, exported.getAsJsonArray("profiles").single { it.asJsonObject.get("id") == futureB.get("id") })
        assertEquals(sourceA, exported.getAsJsonArray("profiles").single { it.asJsonObject.get("id") == sourceA.get("id") })
        val current = exported.getAsJsonArray("periods").single { it.asJsonObject.get("isCurrent").takeUnless { value -> value.isJsonNull }?.asBoolean == true }.asJsonObject
        assertTrue(current.get("profileRef") != sourceA.get("id") && current.get("profileRef") != futureB.get("id"))
        val reopened = AndroidPortableStateCodec.decode(exported.toString().toByteArray())
        assertEquals("32", reopened.profile!!.hourlyRate)
        assertEquals("1280", LinePaycheckRepository.currentPeriod(reopened)!!.expectedWages)
        assertTrue(portableFutureDefaultLabel(reopened)!!.contains("Future profile B"))
        assertEquals(root.get("paycheckReceipts"), exported.get("paycheckReceipts"))
        System.getenv("ANDROID_PORTABLE_ARTIFACT_DIR")?.let { location -> File(location).mkdirs(); File(location, "android-current-A-future-B-adopt-C.json").writeText(exported.toString()) }
    }

}
