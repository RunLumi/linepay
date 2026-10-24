package com.streamentry.linepay.android

import com.google.gson.Gson
import com.google.gson.JsonParser
import com.streamentry.linepay.backup.BackupEnvelope
import com.streamentry.linepay.domain.ContributionBasis
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class BenefitReceiptTest {
    private val period = AndroidBenefitPeriod("2026-10-12", "2026-10-19", "UTC")
    private fun input(): AndroidBenefitInput = AndroidBenefitInput(
        "Synthetic employer fund A", "Synthetic fund plan A-001", "USD", period,
        listOf(AndroidBenefitSegment(
            ruleVersion = "2026-10 synthetic", period = period, effectivePeriod = period,
            basis = ContributionBasis.ELIGIBLE_HOUR, rate = "2.50", quantity = "40",
            source = AndroidBenefitSource("Synthetic fund schedule", "Section 2, page 3", "40 eligible hours confirmed in source work log"),
            eligibilityConfirmed = true,
        )), true, AndroidBenefitStatement(
            "Synthetic employer fund A", "Synthetic fund plan A-001", "USD", period, "95", "40", ContributionBasis.ELIGIBLE_HOUR,
            "Synthetic statement October page 1", true,
        ),
    )
    private fun preview(input: AndroidBenefitInput = input()) = AndroidBenefitRepository.preview(input, createdAtEpochSeconds = 1)

    @Test fun fortyHoursAtTwoFiftyComparesOnlyConfirmedEmployerAmount() {
        val receipt = preview()
        assertEquals("100", receipt.result.expected)
        assertEquals("95", receipt.result.paid)
        assertEquals("5", receipt.result.difference)
        assertEquals("40", receipt.result.eligibleQuantity)
        assertEquals("0", receipt.result.quantityDifference)
        assertEquals("POSSIBLE_DIFFERENCE", receipt.result.status)
        assertEquals("100", receipt.result.components.single().unroundedContribution)
    }

    @Test fun confirmedZeroIsDifferentFromMissingOrUnconfirmedStatement() {
        val source = input()
        val zero = preview(source.copy(statement = source.statement!!.copy(employerContribution = "0")))
        assertEquals("0", zero.result.paid)
        assertEquals("100", zero.result.difference)
        assertEquals("POSSIBLE_DIFFERENCE", zero.result.status)
        val missing = preview(source.copy(statement = null))
        assertNull(missing.result.paid)
        assertNull(missing.result.difference)
        assertEquals("NOT_VERIFIED", missing.result.status)
        assertEquals("STATEMENT_MISSING", missing.result.limitation)
        val unconfirmed = preview(source.copy(statement = source.statement.copy(confirmed = false)))
        assertEquals("NOT_VERIFIED", unconfirmed.result.status)
        assertEquals("STATEMENT_UNCONFIRMED", unconfirmed.result.limitation)
    }

    @Test fun wrongFundCurrencyPeriodOrTimeZoneNeverCompares() {
        val source = input()
        val statement = source.statement!!
        // The display name stays identical: distinct source fund identifiers must not compare.
        listOf(
            statement.copy(fundIdentifier = "Synthetic fund plan B-002"),
            statement.copy(currencyCode = "EUR"),
            statement.copy(period = period.copy(endExclusive = "2026-10-20")),
            statement.copy(period = period.copy(timeZone = "America/New_York")),
        ).forEach {
            val result = preview(source.copy(statement = it)).result
            assertEquals("NOT_COMPARABLE", result.status)
            assertEquals("SCOPE_MISMATCH", result.limitation)
            assertNull(result.paid)
            assertNull(result.difference)
            assertNull(result.quantityDifference)
        }
    }

    @Test fun unitsOnlyAndIncompatibleUnitsRetainTheirLimits() {
        val source = input()
        val units = preview(source.copy(statement = source.statement!!.copy(employerContribution = null, quantity = "39"))).result
        assertNull(units.paid)
        assertEquals("1", units.quantityDifference)
        assertEquals("POSSIBLE_DIFFERENCE", units.status)
        assertEquals("UNITS_ONLY", units.limitation)
        assertEquals("Possible unit difference", benefitStatusLabel(units.status, units.limitation))
        val matchedUnits = preview(source.copy(statement = source.statement.copy(employerContribution = null, quantity = "40"))).result
        assertEquals("Compared units match", benefitStatusLabel(matchedUnits.status, matchedUnits.limitation))
        assertNull(matchedUnits.paid)
        val incompatible = preview(source.copy(statement = source.statement.copy(quantityBasis = ContributionBasis.ELIGIBLE_DAY))).result
        assertNull(incompatible.quantityDifference)
        assertEquals("5", incompatible.difference)
        assertEquals("AMOUNT_ONLY_DIFFERENT_BASIS", incompatible.limitation)
        val noValues = preview(source.copy(statement = source.statement.copy(employerContribution = null, quantity = null, quantityBasis = null))).result
        assertEquals("NOT_VERIFIED", noValues.status)
        assertEquals("NO_COMPARABLE_VALUES", noValues.limitation)
    }

    @Test fun effectiveDatedSegmentsDaysPercentAndRoundingAreExact() {
        val source = input()
        val first = source.segments.single().copy(
            period = period.copy(endExclusive = "2026-10-15"),
            effectivePeriod = period.copy(endExclusive = "2026-10-15"),
            quantity = "20",
        )
        val second = AndroidBenefitSegment(
            ruleVersion = "new schedule", period = period.copy(start = "2026-10-15"),
            effectivePeriod = period.copy(start = "2026-10-15"), basis = ContributionBasis.ELIGIBLE_HOUR,
            rate = "3", quantity = "20", source = first.source, eligibilityConfirmed = true,
        )
        assertEquals("110", preview(source.copy(segments = listOf(first, second), statement = null)).result.expected)
        assertThrows(IllegalArgumentException::class.java) {
            preview(source.copy(segments = listOf(first.copy(period = period.copy(endExclusive = "2026-10-16")), second)))
        }
        val percent = first.copy(period = period, effectivePeriod = period, basis = ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS, rate = "5", quantity = "1000")
        assertEquals("50", preview(source.copy(segments = listOf(percent), statement = null)).result.expected)
        val days = percent.copy(basis = ContributionBasis.ELIGIBLE_DAY, rate = "12.345", quantity = "2")
        assertEquals("24.69", preview(source.copy(segments = listOf(days), statement = null)).result.expected)
        val rounded = days.copy(rate = "0.005", quantity = "1")
        assertEquals("0.01", preview(source.copy(segments = listOf(rounded), statement = null)).result.expected)
        assertEquals("0.005", preview(source.copy(segments = listOf(rounded), statement = null)).result.components.single().unroundedContribution)
    }

    @Test fun fixedPeriodRequiresExactWholePeriodOneAndSingleSegment() {
        val source = input()
        val fixed = source.segments.single().copy(basis = ContributionBasis.FIXED_PERIOD, rate = "123.45", quantity = "1")
        assertEquals("123.45", preview(source.copy(segments = listOf(fixed), statement = null)).result.expected)
        listOf(
            fixed.copy(quantity = "0"), fixed.copy(quantity = "2"),
            fixed.copy(period = period.copy(endExclusive = "2026-10-18")),
            fixed.copy(effectivePeriod = period.copy(start = "2026-10-11")),
        ).forEach { invalid ->
            assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = listOf(invalid))) }
        }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = listOf(fixed, fixed.copy(id = java.util.UUID.randomUUID().toString())))) }
    }

    @Test fun revisionAppendsFrozenOriginalWithoutTouchingWagesAndDeletionRemovesDescendants() {
        val workState = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true)),
            "2026-10-12 07:00", "2026-10-12 15:00", "", "", "Synthetic retained shift",
        )
        val oldWork = workState.work
        val first = preview()
        val saved = AndroidBenefitRepository.append(workState, first)
        val changedInput = first.input.copy(statement = first.input.statement!!.copy(employerContribution = "100"))
        val revision = AndroidBenefitRepository.preview(changedInput, first.id, 2)
        val revised = AndroidBenefitRepository.append(saved, revision)
        assertEquals(listOf(first, revision), revised.benefitReviews)
        assertEquals("5", revised.benefitReviews.first().result.difference)
        assertEquals("COMPARED_VALUES_MATCH", revision.result.status)
        assertEquals(oldWork, revised.work)
        assertEquals(workState.checks, revised.checks)
        assertEquals(workState.weeklyReviews, revised.weeklyReviews)
        assertEquals("200", LinePaycheckRepository.currentPeriod(revised)!!.expectedWages)
        assertThrows(IllegalArgumentException::class.java) { AndroidBenefitRepository.append(saved, first) }
        assertThrows(IllegalArgumentException::class.java) { AndroidBenefitRepository.append(workState, revision) }
        val withoutRevision = AndroidBenefitRepository.deleteFamily(revised, revision.id)
        assertEquals(listOf(first), withoutRevision.benefitReviews)
        val deleted = AndroidBenefitRepository.deleteFamily(revised, first.id)
        assertTrue(deleted.benefitReviews.isEmpty())
        assertEquals(oldWork, deleted.work)
    }

    @Test fun forgedResultsBadSourcesIdsUnconfirmedAndUnboundedInputsFailClosed() {
        val receipt = preview()
        listOf(
            receipt.copy(result = receipt.result.copy(expected = "999")),
            receipt.copy(result = receipt.result.copy(status = "COMPARED_VALUES_MATCH")),
            receipt.copy(result = receipt.result.copy(engine = "forged")),
            receipt.copy(result = receipt.result.copy(components = emptyList())),
            receipt.copy(id = "1-1-1-1-1"),
        ).forEach { invalid ->
            assertThrows(IllegalArgumentException::class.java) { AndroidBenefitRepository.validateReceipt(invalid) }
        }
        val source = input()
        val segment = source.segments.single()
        listOf("1e3", "1,000", "-1", "NaN", "0.0000000000001").forEach { value ->
            assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = listOf(segment.copy(rate = value)))) }
        }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(completeEligibilityConfirmed = false)) }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = listOf(segment.copy(eligibilityConfirmed = false)))) }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = List(101) { segment })) }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(segments = listOf(segment.copy(source = segment.source.copy(reference = ""))))) }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(fundName = "Bad\nfund")) }
        assertThrows(IllegalArgumentException::class.java) { preview(source.copy(statement = source.statement!!.copy(quantity = null))) }
    }

    @Test fun encryptedBackupPreservesAllInputsAndRejectsForgedReceiptAfterDecode() {
        val saved = AndroidBenefitRepository.append(AndroidLocalState.empty(), preview())
        val fixturePhrase = "synthetic-benefit-password"
        val sealed = BackupEnvelope.seal(Gson().toJson(saved).toByteArray(Charsets.UTF_8), fixturePhrase)
        val opened = JsonParser.parseString(BackupEnvelope.open(sealed, fixturePhrase).toString(Charsets.UTF_8)).asJsonObject
        migrateAndroidLocalState(opened)
        val restored = Gson().fromJson(opened, AndroidLocalState::class.java)
        assertEquals(saved, AndroidLocalStateValidator.validate(restored))
        opened.getAsJsonArray("benefitReviews")[0].asJsonObject.getAsJsonObject("result").addProperty("difference", "0")
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(Gson().fromJson(opened, AndroidLocalState::class.java))
        }
    }

    @Test fun schemaThreeMigrationPreservesExistingTreesAndRejectsBenefitSmugglingOrMissingCurrentCollection() {
        val workState = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true)),
            "2026-10-12 07:00", "2026-10-12 15:00", "", "", "Synthetic retained shift",
        )
        val root = JsonParser.parseString(Gson().toJson(workState)).asJsonObject
        root.addProperty("schemaVersion", 3)
        root.remove("benefitReviews")
        val oldProfile = root.get("profile").deepCopy()
        val oldWork = root.get("work").deepCopy()
        val oldChecks = root.get("checks").deepCopy()
        val oldWeekly = root.get("weeklyReviews").deepCopy()
        migrateAndroidLocalState(root)
        assertEquals(oldProfile, root.get("profile"))
        assertEquals(oldWork, root.get("work"))
        assertEquals(oldChecks, root.get("checks"))
        assertEquals(oldWeekly, root.get("weeklyReviews"))
        assertEquals(4, root.get("schemaVersion").asInt)
        assertEquals(workState, Gson().fromJson(root, AndroidLocalState::class.java))
        for (version in 1..3) {
            val smuggled = JsonParser.parseString(Gson().toJson(AndroidBenefitRepository.append(AndroidLocalState.empty(), preview()))).asJsonObject
            smuggled.addProperty("schemaVersion", version)
            assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(smuggled) }
        }
        root.remove("benefitReviews")
        assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(root) }
    }
    @Test fun benefitAppendBackupAndSchemaThreeMigrationKeepSavedWageAndWeeklyReceiptsExactly() {
        var state = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true)),
            "2026-10-12 07:00", "2026-10-12 15:00", "", "", "Synthetic historical work",
        )
        val (withCheck, check) = LinePaycheckRepository.savePaycheck(state, AndroidPaycheckInput(
            "2026-10-12", "2026-10-18", "UTC", true, "200", GrossBasisChoice.WAGES_ONLY, true, true,
        ), 1)
        val weekly = AndroidWeeklyReviewRepository.preview(withCheck, AndroidWeeklyReviewRequest(
            "2026-10-12 00:00", "UTC", listOf(check.id), "200",
            boundaryConfirmed = true, singleEmployerConfirmed = true, paymentsConfirmed = true,
            completeWorkweek = true, applicabilityConfirmed = true,
        ), 2)
        state = AndroidWeeklyReviewRepository.append(withCheck, weekly)
        val originalJson = JsonParser.parseString(Gson().toJson(state)).asJsonObject
        val next = AndroidBenefitRepository.append(state, preview())
        assertEquals(state.work, next.work)
        assertEquals(state.checks, next.checks)
        assertEquals(state.weeklyReviews, next.weeklyReviews)
        val roundtrip = Gson().fromJson(
            BackupEnvelope.open(BackupEnvelope.seal(Gson().toJson(next).toByteArray(), "Synthetic preservation password"), "Synthetic preservation password").toString(Charsets.UTF_8),
            AndroidLocalState::class.java,
        )
        assertEquals(next, AndroidLocalStateValidator.validate(roundtrip))
        val legacy = originalJson.deepCopy()
        legacy.addProperty("schemaVersion", 3)
        legacy.remove("benefitReviews")
        migrateAndroidLocalState(legacy)
        for (key in listOf("profile", "work", "checks", "weeklyReviews")) assertEquals(originalJson[key], legacy[key])
        assertEquals(state, AndroidLocalStateValidator.validate(Gson().fromJson(legacy, AndroidLocalState::class.java)))
        // Older schemas retain their existing safety upgrades; this extension never changes work facts.
        for (version in 1..2) {
            val earlier = originalJson.deepCopy()
            earlier.addProperty("schemaVersion", version)
            earlier.remove("benefitReviews")
            earlier.add("weeklyReviews", com.google.gson.JsonArray())
            migrateAndroidLocalState(earlier)
            assertEquals(originalJson["work"], earlier["work"])
            assertEquals(originalJson["profile"], earlier["profile"])
            assertTrue(earlier.getAsJsonArray("benefitReviews").isEmpty)
            AndroidLocalStateValidator.validate(Gson().fromJson(earlier, AndroidLocalState::class.java))
        }
    }

}
