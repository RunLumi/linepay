package com.streamentry.linepay.android

import com.google.gson.JsonParser
import com.streamentry.linepay.backup.BackupEnvelope
import java.io.File
import java.math.BigDecimal
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ConfirmedPaycheckLinesTest {
    private fun tenHourState(multiplier: String = "1.5", perDiem: String? = null): AndroidLocalState = LinePaycheckRepository.addWork(
        AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "50", dailyOvertimeAfterHours = "8", dailyOvertimeMultiplier = multiplier,
            cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true, perDiemPerWorkDate = perDiem)),
        "2026-10-12 08:00", "2026-10-12 18:00", "", "", "Synthetic ten-hour source",
    )
    private fun full() = AndroidConfirmedPaycheckLines("USD", layout = "FULL_RATE_BUCKETS", hoursBasis = "ACTUAL_WORK")
    private fun input(lines: AndroidConfirmedPaycheckLines, gross: String = "550") = AndroidPaycheckInput(
        "2026-10-12", "2026-10-18", "UTC", true, gross, GrossBasisChoice.WAGES_ONLY, true, true, lines,
    )
    private fun save(lines: AndroidConfirmedPaycheckLines, state: AndroidLocalState = tenHourState(), gross: String = "550") =
        LinePaycheckRepository.savePaycheck(state, input(lines, gross), 1792195200)
    private fun sameDecimal(expected: String, actual: String?) = assertEquals(0, BigDecimal(expected).compareTo(BigDecimal(requireNotNull(actual))))
    private fun part(check: AndroidPaycheckSnapshot, field: String) = check.comparisons.single { it.field == field }
    private fun nativeDecode(json: String): AndroidLocalState {
        val root = JsonParser.parseString(json).asJsonObject
        migrateAndroidLocalState(root)
        validateCapturedLineJson(root)
        return AndroidLocalStateValidator.validate(androidLocalStateGson().fromJson(root, AndroidLocalState::class.java))
    }

    @Test fun offsettingMoneyDifferencesNeverCancelUnderMatchingGross() {
        val lines = full().copy(regularPay = "350.00", overtimePay = "200.00", regularHours = "8.0000", overtimeHours = "2", completeEarningsLines = true)
        val (state, check) = save(lines)
        sameDecimal("550", check.expectedGross); sameDecimal("0", check.difference)
        sameDecimal("400", part(check, "REGULAR_PAY").expected); sameDecimal("50", part(check, "REGULAR_PAY").difference)
        sameDecimal("150", part(check, "OVERTIME_PAY").expected); sameDecimal("-50", part(check, "OVERTIME_PAY").difference)
        assertEquals("NEEDS_REVIEW", check.verdict)
        assertTrue("WEEKLY_REVIEW_PENDING" in check.reviewReasons)
        assertEquals(lines, check.confirmedLineFacts)
        assertEquals(state, nativeDecode(androidLocalStateGson().toJson(state)))
        assertTrue(part(check, "REGULAR_PAY").componentIds.isNotEmpty())
        assertTrue(part(check, "OVERTIME_PAY").componentIds.isNotEmpty())
    }

    @Test fun premiumOnlyUsesAllBaseHoursAndExtraOvertimeRatherThanFullOvertimeRate() {
        val (_, check) = save(full().copy(layout = "BASE_PLUS_PREMIUM", regularPay = "500", overtimePay = "50", regularHours = "10", overtimeHours = "2", completeEarningsLines = true))
        sameDecimal("500", part(check, "REGULAR_PAY").expected)
        sameDecimal("50", part(check, "OVERTIME_PAY").expected)
        sameDecimal("10", part(check, "REGULAR_HOURS").expected)
        sameDecimal("2", part(check, "OVERTIME_HOURS").expected)
        assertTrue(check.comparisons.all { BigDecimal(it.difference).signum() == 0 })
        assertEquals("NEEDS_REVIEW", check.verdict)
        assertTrue("WEEKLY_REVIEW_PENDING" in check.reviewReasons)
    }

    @Test fun blankOvertimeIsUnknownButExplicitZeroIsAComparedSourceObservation() {
        val (_, blank) = save(full().copy(regularPay = "400"))
        assertFalse(blank.comparisons.any { it.field == "OVERTIME_PAY" })
        assertEquals(null, blank.confirmedLineFacts!!.overtimePay)
        assertFalse("CONFLICTING_EARNINGS" in blank.reviewReasons)
        val (_, zero) = save(full().copy(regularPay = "400", overtimePay = "0"))
        sameDecimal("0", part(zero, "OVERTIME_PAY").paid)
        sameDecimal("150", part(zero, "OVERTIME_PAY").difference)
        assertEquals("0", zero.confirmedLineFacts!!.overtimePay)
        val (_, incompleteClaim) = save(full().copy(regularPay = "400", completeEarningsLines = true))
        assertTrue("CONFLICTING_EARNINGS" in incompleteClaim.reviewReasons)
        val (_, emptyClaim) = save(full().copy(completeEarningsLines = true))
        assertTrue("EMPTY_COMPLETE_BREAKDOWN" in emptyClaim.reviewReasons)
    }

    @Test fun differentStatementPeriodRetainsEnteredLinesWithoutExpectedOrComparedValues() {
        val lines = full().copy(regularPay = "350", overtimePay = "200", completeEarningsLines = true)
        val mismatched = input(lines).copy(sourceStartDate = "2026-10-13", sourceLastDate = "2026-10-19")
        val (_, check) = LinePaycheckRepository.savePaycheck(tenHourState(), mismatched, 1792195200)
        assertEquals("NOT_COMPARABLE", check.verdict)
        assertEquals("DIFFERENT_PERIOD", check.periodMatch)
        assertEquals(null, check.expectedGross); assertEquals(null, check.difference)
        assertTrue(check.comparisons.isEmpty())
        assertEquals(lines, check.confirmedLineFacts)
        val state = AndroidLocalState(profile = check.profile, checks = listOf(check))
        val wire = PortableStateJson.parse(AndroidPortableStateCodec.encode(state, 1792195200)).getAsJsonArray("paycheckReceipts").single().asJsonObject
        assertTrue(wire.getAsJsonObject("reviewFacts").get("weeklyReviewPending").asBoolean)
        assertEquals(2, wire.getAsJsonObject("lineFacts").getAsJsonArray("amounts").size())
        assertEquals("notComparable", wire.getAsJsonObject("assessment").get("verdict").asString)
        assertEquals("grossOnly", wire.getAsJsonObject("assessment").get("scope").asString)
    }

    @Test fun unknownMappingsAndUnusualMultipliersStayExplicitReviewQuestions() {
        val (_, layout) = save(full().copy(layout = "UNCONFIRMED", regularPay = "400", overtimePay = "150"))
        assertTrue("UNKNOWN_EARNINGS_LAYOUT" in layout.reviewReasons)
        assertFalse(layout.comparisons.any { it.field == "REGULAR_PAY" })
        val retained = PortableStateJson.parse(AndroidPortableStateCodec.encode(AndroidLocalState(profile = layout.profile, checks = listOf(layout)), 1792195200)).getAsJsonArray("paycheckReceipts").single().asJsonObject
        assertEquals("grossOnly", retained.getAsJsonObject("assessment").get("scope").asString)
        assertEquals(2, retained.getAsJsonObject("lineFacts").getAsJsonArray("amounts").size())
        val (_, hours) = save(full().copy(hoursBasis = "UNCONFIRMED", regularHours = "8"))
        assertTrue("UNKNOWN_HOURS_BASIS" in hours.reviewReasons)
        assertFalse(hours.comparisons.any { it.unit == "HOURS" })
        val (_, unusual) = save(full().copy(regularPay = "400", overtimePay = "175"), tenHourState("1.75"), "575")
        assertTrue("UNUSUAL_MULTIPLIER" in unusual.reviewReasons)
        assertEquals("NEEDS_REVIEW", unusual.verdict)
    }

    @Test fun calloutChoiceDoesNotCreateGuaranteeAndHoursKeepTheirOwnUnits() {
        val (_, separate) = save(full().copy(guaranteeLayout = "SEPARATE_LINE", calloutPay = "0", regularHours = "8", overtimeHours = "2"))
        sameDecimal("0", part(separate, "CALLOUT_PAY").expected)
        assertTrue(part(separate, "CALLOUT_PAY").componentIds.isEmpty())
        val (_, wrongMapping) = save(full().copy(guaranteeLayout = "INCLUDED_IN_HOURLY_LINES", calloutPay = "5"))
        assertTrue("CONFLICTING_CALLOUT_MAPPING" in wrongMapping.reviewReasons)
        val (_, equivalents) = save(full().copy(hoursBasis = "PAID_EQUIVALENTS", regularHours = "8", overtimeHours = "3"))
        assertEquals("HOURS", part(equivalents, "OVERTIME_HOURS").unit)
        sameDecimal("2", part(equivalents, "OVERTIME_HOURS").expected)
        sameDecimal("-1", part(equivalents, "OVERTIME_HOURS").difference)
    }

    @Test fun optionalPerDiemRemainsUnknownUntilEnteredAndUsesConfirmedGrossBasis() {
        val state = tenHourState(perDiem = "20")
        val (_, unknown) = save(full().copy(regularPay = "400", overtimePay = "150"), state)
        assertFalse(unknown.comparisons.any { it.field == "PER_DIEM_PAY" })
        val lines = full().copy(regularPay = "400", overtimePay = "150", paidPerDiem = "20.00", completeEarningsLines = true)
        val (_, included) = LinePaycheckRepository.savePaycheck(state, input(lines, "570").copy(basis = GrossBasisChoice.WAGES_AND_PER_DIEM), 1792195200)
        sameDecimal("570", included.expectedGross); sameDecimal("0", part(included, "PER_DIEM_PAY").difference)
        assertFalse("CONFLICTING_EARNINGS" in included.reviewReasons)
        assertEquals("20.00", included.confirmedLineFacts!!.paidPerDiem)
    }

    @Test fun exactInputBoundsRejectMalformedCurrencyDecimalsAndHoursWithoutChangingState() {
        val state = tenHourState()
        val before = androidLocalStateGson().toJson(state)
        for (value in listOf("", "-1", "+1", "1e2", "NaN", "1,000", "01", "1.", "0.0000000000001", "1000000000001")) {
            assertThrows(IllegalArgumentException::class.java) { save(full().copy(regularPay = value), state) }
        }
        for (value in listOf("10000.0001", "1e2", "-0")) assertThrows(IllegalArgumentException::class.java) { save(full().copy(regularHours = value), state) }
        full().copy(regularPay = "1000000000000", regularHours = "10000", overtimeHours = "0.000000000001").validate()
        for (currency in listOf("CAD", "US", "usd")) assertThrows(IllegalArgumentException::class.java) { save(full().copy(currencyCode = currency), state) }
        assertThrows(IllegalArgumentException::class.java) { LinePaycheckRepository.savePaycheck(state, input(full(), "5.5e2")) }
        assertEquals(before, androidLocalStateGson().toJson(state))
        val (_, exact) = save(full().copy(regularPay = "399.995", regularHours = "8.00005"), state)
        sameDecimal("0.01", part(exact, "REGULAR_PAY").difference) // 400 - 399.995, then wage rounding.
        sameDecimal("-0.0001", part(exact, "REGULAR_HOURS").difference) // Exact seconds, independent four-place hour rounding.
    }

    @Test fun capturedReplayRejectsChangedResultsFactsComponentsAndFutureCaptureVersions() {
        val (state, check) = save(full().copy(regularPay = "350", overtimePay = "200"))
        val wrong = listOf(
            check.copy(expectedGross = "999"), check.copy(difference = "1"), check.copy(reviewReasons = emptyList()),
            check.copy(confirmedLineFacts = check.confirmedLineFacts!!.copy(regularPay = "349")),
            check.copy(components = check.components.mapIndexed { index, part -> if (index == 0) part.copy(amount = "1") else part }),
            check.copy(comparisons = check.comparisons.map { if (it.field == "REGULAR_PAY") it.copy(componentIds = emptyList()) else it }),
            check.copy(confirmedLineFacts = check.confirmedLineFacts.copy(version = 2)),
        )
        wrong.forEach { assertThrows(IllegalArgumentException::class.java) { AndroidLocalStateValidator.validate(state.copy(checks = listOf(it))) } }
        val changedCurrent = state.copy(profile = state.profile!!.copy(hourlyRate = "60", version = "2"), work = emptyList())
        AndroidLocalStateValidator.validate(changedCurrent)
        assertEquals(check, changedCurrent.checks.single())
    }

    @Test fun schemaFiveMigrationPreservesUnknownCapturesAndRejectsSmuggledRecordedInputs() {
        val (state, _) = save(full().copy(regularPay = "400"))
        val legacy = JsonParser.parseString(androidLocalStateGson().toJson(state)).asJsonObject
        legacy.addProperty("schemaVersion", 5)
        legacy.getAsJsonArray("checks").forEach { it.asJsonObject.remove("confirmedLineFacts") }
        val original = legacy.deepCopy()
        migrateAndroidLocalState(legacy)
        for (field in listOf("profile", "work", "checks", "weeklyReviews", "benefitReviews", "portableArchive")) assertEquals(original.get(field), legacy.get(field))
        val restored = nativeDecode(legacy.toString())
        assertEquals(null, restored.checks.single().confirmedLineFacts)
        assertEquals(6, restored.schemaVersion)
        for (version in 1..5) {
            val bad = JsonParser.parseString(androidLocalStateGson().toJson(state)).asJsonObject
            bad.addProperty("schemaVersion", version)
            assertThrows(IllegalArgumentException::class.java) { migrateAndroidLocalState(bad) }
        }
    }

    @Test fun capturedJsonRejectsCoercionMissingConfirmationAndUnrecognizedFields() {
        val (state, _) = save(full().copy(regularPay = "400"))
        for (mutate in listOf<(com.google.gson.JsonObject) -> Unit>(
            { it.addProperty("regularPay", 400) }, { it.remove("completeEarningsLines") }, { it.addProperty("inferredBonus", "10") },
            { it.addProperty("version", "1") }, { it.addProperty("hoursBasis", "guessed") }, { it.add("layout", com.google.gson.JsonNull.INSTANCE) },
        )) {
            val root = JsonParser.parseString(androidLocalStateGson().toJson(state)).asJsonObject
            mutate(root.getAsJsonArray("checks").single().asJsonObject.getAsJsonObject("confirmedLineFacts"))
            assertThrows(IllegalArgumentException::class.java) { nativeDecode(root.toString()) }
        }
    }

    @Test fun encryptedNativeAndPortableRoundTripsRetainExactObservationsAndLegacyUnknownMarkers() {
        val lines = full().copy(regularPay = "350.00", overtimePay = "200.00", regularHours = "8.0000", overtimeHours = "2.0000", doubleTimePay = "0.00", completeEarningsLines = true)
        val (state, check) = save(lines)
        val encrypted = BackupEnvelope.seal(androidLocalStateGson().toJson(state).toByteArray(), "Synthetic confirmed lines password")
        assertEquals(state, nativeDecode(BackupEnvelope.open(encrypted, "Synthetic confirmed lines password").toString(Charsets.UTF_8)))
        val wire = PortableStateJson.parse(AndroidPortableStateCodec.encode(state, 1792195200))
        val receipt = wire.getAsJsonArray("paycheckReceipts").single().asJsonObject
        val facts = receipt.getAsJsonObject("lineFacts")
        assertEquals("confirmedLines", receipt.getAsJsonObject("assessment").get("scope").asString)
        assertEquals("350.00", receipt.getAsJsonObject("paystubFacts").get("regularPay").asString)
        assertEquals("0.00", receipt.getAsJsonObject("paystubFacts").get("doubleTimePay").asString)
        assertTrue(receipt.getAsJsonObject("paystubFacts").get("calloutPay").isJsonNull)
        assertEquals("8.0000", facts.getAsJsonArray("hours").single { it.asJsonObject.get("field").asString == "regularHours" }.asJsonObject.get("hours").asString)
        val restored = AndroidPortableStateCodec.decode(wire.toString().toByteArray())
        val again = PortableStateJson.parse(AndroidPortableStateCodec.encode(restored, 1792281600))
        assertEquals(wire.get("paycheckReceipts"), again.get("paycheckReceipts"))
        val legacy = state.copy(checks = listOf(check.copy(confirmedLineFacts = null)))
        val oldWire = PortableStateJson.parse(AndroidPortableStateCodec.encode(legacy, 1792195200)).getAsJsonArray("paycheckReceipts").single().asJsonObject
        assertTrue(oldWire.getAsJsonObject("lineFacts").get("amounts").isJsonNull)
        assertTrue(oldWire.getAsJsonObject("lineFacts").get("hours").isJsonNull)
        val unknownReference = legacy.copy(checks = listOf(legacy.checks.single().let { saved ->
            saved.copy(comparisons = saved.comparisons.map { comparison ->
                if (comparison.field == "REGULAR_PAY") comparison.copy(componentIds = listOf(java.util.UUID.randomUUID().toString())) else comparison
            })
        }))
        assertThrows(IllegalArgumentException::class.java) { AndroidPortableStateCodec.encode(unknownReference, 1792195200) }
        System.getenv("ANDROID_LINE_ARTIFACT_DIR")?.let { dir -> File(dir).mkdirs(); File(dir, "android-confirmed-lines.json").writeText(wire.toString()) }
    }
}
