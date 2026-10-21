package com.streamentry.linepay.android

import com.google.gson.Gson
import com.google.gson.JsonParser
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

class LinePaycheckRepositoryTest {
    private val profile = AndroidRuleProfile(
        hourlyRate = "25.00",
        currencyCode = "USD",
        cadence = PayCycleChoice.WEEKLY,
        cycleStartDate = "2026-10-12",
        payrollTimeZone = "UTC",
        dailyOvertimeAfterHours = "8",
        dailyOvertimeMultiplier = "1.5",
        rulesReviewedByWorker = true,
    )

    @Test
    fun unpaidBreakReducesWorkedTimeAndSavedCheckKeepsExactSnapshot() {
        val state = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = profile),
            startLocal = "2026-10-12 07:00",
            endLocal = "2026-10-12 15:30",
            breakStartLocal = "2026-10-12 12:00",
            breakEndLocal = "2026-10-12 12:30",
            note = "Synthetic shift",
        )

        val estimate = LinePaycheckRepository.currentPeriod(state)!!
        assertEquals("200", estimate.expectedWages)
        assertEquals("8.00", java.math.BigDecimal(estimate.workedSeconds)
            .divide(java.math.BigDecimal(3600), 2, java.math.RoundingMode.HALF_UP).toPlainString())

        val input = matchingPaycheckInput()
        val (next, check) = LinePaycheckRepository.savePaycheck(state, input, createdAtEpochSeconds = 1)
        assertEquals("NEEDS_REVIEW", check.verdict)
        assertTrue(check.reviewReasons.contains("WEEKLY_REVIEW_PENDING"))
        assertEquals("200", check.expectedGross)
        assertEquals(1, check.work.size)
        assertEquals("Synthetic shift", check.work.single().note)
        assertEquals("linepay.android.configured-lines/1", check.engine)
        assertEquals(check, next.checks.single())
        assertEquals("1", check.profile.version)
    }

    @Test
    fun statementFromDifferentPeriodNeverProducesGrossMatch() {
        val state = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = profile),
            startLocal = "2026-10-12 07:00",
            endLocal = "2026-10-12 15:30",
            breakStartLocal = "",
            breakEndLocal = "",
            note = "Synthetic shift",
        )
        val input = matchingPaycheckInput().copy(sourceStartDate = "2026-10-19", sourceLastDate = "2026-10-25")

        val (_, check) = LinePaycheckRepository.savePaycheck(state, input, createdAtEpochSeconds = 2)

        assertEquals("NOT_COMPARABLE", check.verdict)
        assertEquals("DIFFERENT_PERIOD", check.periodMatch)
        assertNull(check.expectedGross)
        assertNotEquals("MATCHES", check.verdict)
    }

    @Test
    fun nonexistentAndRepeatedLocalWorkTimesFailClosed() {
        val zone = ZoneId.of("America/Los_Angeles")

        assertThrows(IllegalArgumentException::class.java) {
            LinePaycheckRepository.parseUnambiguousInstant("2026-03-08 02:30", zone)
        }
        assertThrows(IllegalArgumentException::class.java) {
            LinePaycheckRepository.parseUnambiguousInstant("2026-11-01 01:30", zone)
        }
    }

    @Test
    fun crossPeriodWeeklyReceiptIsFrozenAppendOnlyAndNeverChangesPaycheckVerdict() {
        val (state, first, second) = twoSavedPeriods()
        assertEquals("NEEDS_REVIEW", first.verdict)
        assertTrue(first.reviewReasons.contains("WEEKLY_REVIEW_PENDING"))
        assertEquals(
            setOf(first.id, second.id),
            AndroidWeeklyReviewRepository.periodsContainingWorkInWeek(
                state,
                "2026-10-17 00:00",
                "UTC",
            ).map { it.id }.toSet(),
        )
        val beforeChecks = state.checks
        val preview = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 40,
        )

        assertEquals(emptyList<AndroidWeeklyReviewReceipt>(), state.weeklyReviews)
        assertEquals("1200", preview.result.cashRemuneration.amount)
        assertEquals("100", preview.result.remainingAdditionalPremium.amount)
        assertEquals("1300", preview.result.expectedCash.amount)
        assertEquals(setOf(first.id, second.id), preview.source.periods.map { it.periodId }.toSet())
        assertEquals(6, preview.input.work.size)

        val saved = AndroidWeeklyReviewRepository.append(state, preview)
        AndroidLocalStateValidator.validate(saved)
        assertEquals(1, saved.weeklyReviews.size)
        assertEquals(beforeChecks, saved.checks)
        assertEquals("NEEDS_REVIEW", saved.checks.single { it.id == first.id }.verdict)
        assertTrue(saved.checks.single { it.id == first.id }.reviewReasons.contains("WEEKLY_REVIEW_PENDING"))
        assertEquals(1, AndroidWeeklyReviewRepository.relatedReviews(saved, first.id).size)
        assertEquals(1, AndroidWeeklyReviewRepository.relatedReviews(saved, second.id).size)

        val recalculation = AndroidWeeklyReviewRepository.preview(
            saved,
            weeklyRequest(listOf(first.id, second.id)).copy(straightTimeWages = "1201.00"),
            createdAtEpochSeconds = 45,
        )
        val appendedAgain = AndroidWeeklyReviewRepository.append(saved, recalculation)
        assertEquals(listOf(recalculation, preview), appendedAgain.weeklyReviews)
        assertNotEquals(recalculation.id, preview.id)
        assertEquals("100", preview.result.remainingAdditionalPremium.amount)
        assertEquals("100.08", recalculation.result.remainingAdditionalPremium.amount)
        assertEquals(beforeChecks, appendedAgain.checks)
    }

    @Test
    fun weeklyPreviewRejectsOmittedWorkPeriodEvenWhenItsSavedDatesDoNotIntersectTheWeek() {
        val (state, first, second) = twoSavedPeriods()
        val workOutsideDates = first.copy(
            id = java.util.UUID.randomUUID().toString(),
            targetStartDate = "2026-10-10",
            targetLastDate = "2026-10-16",
        )
        val dateOverlapWithoutWork = first.copy(
            id = java.util.UUID.randomUUID().toString(),
            targetStartDate = "2026-10-17",
            targetLastDate = "2026-10-18",
            work = emptyList(),
        )
        val candidateState = state.copy(checks = state.checks + workOutsideDates + dateOverlapWithoutWork)

        val visibleIds = AndroidWeeklyReviewRepository.periodsContainingWorkInWeek(
            candidateState,
            "2026-10-17 00:00",
            "UTC",
        ).map { it.id }.toSet()
        assertTrue(workOutsideDates.id in visibleIds)
        assertTrue(dateOverlapWithoutWork.id !in visibleIds)
        assertTrue(first.id in visibleIds)
        assertTrue(second.id in visibleIds)

        val validPreview = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 47,
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                candidateState,
                weeklyRequest(listOf(first.id, second.id)),
                createdAtEpochSeconds = 48,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.append(candidateState, validPreview)
        }
    }

    @Test
    fun weeklyReviewRefusesCanonicalWorkWithoutItsSavedPaycheckSource() {
        val (state, first, second) = twoSavedPeriods()
        val completePreview = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 48,
        )
        val afterDeletingSourceCheck = AndroidWeeklyReviewRepository.deletePaycheckPeriod(state, first.id)

        // Deleting a check removes its receipt, but intentionally retains the canonical shifts.
        assertEquals(state.work, afterDeletingSourceCheck.work)
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                afterDeletingSourceCheck,
                weeklyRequest(listOf(second.id)),
                createdAtEpochSeconds = 49,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.append(afterDeletingSourceCheck, completePreview)
        }

        // New canonical work added after a valid preview also invalidates that save candidate.
        val workAddedAfterPreview = LinePaycheckRepository.addWork(
            state,
            "2026-10-23 07:00",
            "2026-10-23 15:00",
            "",
            "",
            "Synthetic unsaved weekly source",
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                workAddedAfterPreview,
                weeklyRequest(listOf(first.id, second.id)),
                createdAtEpochSeconds = 50,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.append(workAddedAfterPreview, completePreview)
        }
    }

    @Test
    fun completeSourceInventorySurvivesRestoreWithoutConsultingMutablePaycheckRows() {
        val (state, first, second) = twoSavedPeriods()
        val receipt = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 49,
        )
        assertEquals(
            receipt.source.workContainingPeriodIds,
            receipt.source.periods.map { it.periodId },
        )

        val saved = AndroidWeeklyReviewRepository.append(state, receipt)
        val restoredJson = com.google.gson.Gson().toJson(saved)
        val restored = com.google.gson.Gson().fromJson(restoredJson, AndroidLocalState::class.java)
        val importedWithChangedLiveRows = restored.copy(checks = emptyList(), work = emptyList())

        assertEquals(saved.weeklyReviews, AndroidLocalStateValidator.validate(importedWithChangedLiveRows).weeklyReviews)
    }

    @Test
    fun schemaTwoReceiptMigrationRebuildsCompleteSourceSetAndRejectsAnOmittedPeriod() {
        val (state, first, second) = twoSavedPeriods()
        val receipt = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 50,
        )
        val saved = AndroidWeeklyReviewRepository.append(state, receipt)
        val legacyRoot = JsonParser.parseString(Gson().toJson(saved)).asJsonObject
        legacyRoot.addProperty("schemaVersion", 2)
        legacyRoot.getAsJsonArray("weeklyReviews").first().asJsonObject
            .getAsJsonObject("source").remove("workContainingPeriodIds")
        legacyRoot.getAsJsonArray("checks").forEach { encoded ->
            encoded.asJsonObject.addProperty("weeklyReviewConfirmed", true)
            encoded.asJsonObject.addProperty("verdict", "MATCHES")
            val reasons = encoded.asJsonObject.getAsJsonArray("reviewReasons")
            for (index in reasons.size() - 1 downTo 0) {
                if (reasons[index].asString == "WEEKLY_REVIEW_PENDING") reasons.remove(index)
            }
        }

        migrateAndroidLocalState(legacyRoot)

        val imported = Gson().fromJson(legacyRoot, AndroidLocalState::class.java)
        AndroidLocalStateValidator.validate(imported)
        assertEquals(AndroidLocalState.CURRENT_SCHEMA_VERSION, imported.schemaVersion)
        assertEquals(
            listOf(first.id, second.id),
            imported.weeklyReviews.single().source.workContainingPeriodIds,
        )
        assertTrue(imported.checks.all { it.verdict == "NEEDS_REVIEW" })

        val omittedRoot = JsonParser.parseString(Gson().toJson(saved)).asJsonObject
        omittedRoot.addProperty("schemaVersion", 2)
        omittedRoot.getAsJsonArray("weeklyReviews").first().asJsonObject
            .getAsJsonObject("source").remove("workContainingPeriodIds")
        omittedRoot.getAsJsonArray("weeklyReviews").first().asJsonObject
            .getAsJsonObject("source").getAsJsonArray("periods").remove(1)
        assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(omittedRoot) }
    }

    @Test
    fun retainedWeeklyReceiptReplaysWithoutDependingOnCurrentPaycheckRows() {
        val (state, first, second) = twoSavedPeriods()
        val receipt = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 41,
        )
        val saved = AndroidWeeklyReviewRepository.append(state, receipt)
        AndroidLocalStateValidator.validate(saved)

        val unknownEngine = receipt.copy(result = receipt.result.copy(engine = "linepay.android.weekly/99"))
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(unknownEngine)))
        }
        val changedResult = receipt.copy(
            result = receipt.result.copy(expectedCash = receipt.result.expectedCash.copy(amount = "0.00")),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(changedResult)))
        }
        val changedInput = receipt.copy(
            input = receipt.input.copy(work = receipt.input.work.drop(1)),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(changedInput)))
        }
        val missingSource = receipt.copy(
            source = receipt.source.copy(periods = receipt.source.periods.drop(1)),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(missingSource)))
        }
        val missingSourceInventory = receipt.copy(
            source = receipt.source.copy(workContainingPeriodIds = receipt.source.workContainingPeriodIds.drop(1)),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(missingSourceInventory)))
        }
        assertEquals(
            saved.weeklyReviews,
            AndroidLocalStateValidator.validate(saved.copy(checks = emptyList())).weeklyReviews,
        )
        val forgedMatch = saved.checks.first().copy(
            expectedGross = null,
            verdict = "MATCHES",
            reviewReasons = emptyList(),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(checks = listOf(forgedMatch) + saved.checks.drop(1)))
        }
        val missingWages = receipt.copy(input = receipt.input.copy(remuneration = emptyList()))
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(missingWages)))
        }
        val changedRuleSnapshot = receipt.copy(
            source = receipt.source.copy(
                periods = receipt.source.periods.mapIndexed { index, period ->
                    if (index == 0) period.copy(profile = period.profile.copy(hourlyRate = "26.00")) else period
                },
            ),
        )
        assertThrows(IllegalArgumentException::class.java) {
            AndroidLocalStateValidator.validate(saved.copy(weeklyReviews = listOf(changedRuleSnapshot)))
        }
    }

    @Test
    fun deletingLinkedSourcePeriodRemovesWeeklyReceiptButKeepsWorkAndOtherPeriod() {
        val (state, first, second) = twoSavedPeriods()
        val receipt = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)),
            createdAtEpochSeconds = 42,
        )
        val saved = AndroidWeeklyReviewRepository.append(state, receipt)
        val originalWork = saved.work

        val deleted = AndroidWeeklyReviewRepository.deletePaycheckPeriod(saved, second.id)

        assertEquals(listOf(first), deleted.checks)
        assertEquals(emptyList<AndroidWeeklyReviewReceipt>(), deleted.weeklyReviews)
        assertEquals(originalWork, deleted.work)
    }

    @Test
    fun weeklyCalculatorAdmissionStillRequiresEveryExplicitConfirmation() {
        val (state, first, second) = twoSavedPeriods()
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                state,
                weeklyRequest(listOf(first.id, second.id)).copy(applicabilityConfirmed = false),
                createdAtEpochSeconds = 43,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                state,
                weeklyRequest(listOf(first.id, second.id)).copy(completeWorkweek = false),
                createdAtEpochSeconds = 44,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AndroidWeeklyReviewRepository.preview(
                state,
                weeklyRequest(listOf(first.id, second.id)).copy(straightTimeWages = ""),
                createdAtEpochSeconds = 46,
            )
        }
    }

    @Test
    fun weeklyPaymentFieldsKeepCashExclusionsAndPremiumCreditClassificationSeparate() {
        val (state, first, second) = twoSavedPeriods()
        val receipt = AndroidWeeklyReviewRepository.preview(
            state,
            weeklyRequest(listOf(first.id, second.id)).copy(
                includableBonus = "100.00",
                excludedCash = "50.00",
                eligibleExtraPremium = "20.00",
                ineligibleExtraPremium = "10.00",
            ),
            createdAtEpochSeconds = 47,
        )

        assertEquals(
            listOf(
                com.streamentry.linepay.domain.WeeklyRemunerationKind.STRAIGHT_TIME,
                com.streamentry.linepay.domain.WeeklyRemunerationKind.INCLUDABLE_BONUS,
                com.streamentry.linepay.domain.WeeklyRemunerationKind.EXCLUDED_CASH,
                com.streamentry.linepay.domain.WeeklyRemunerationKind.EXTRA_PREMIUM,
                com.streamentry.linepay.domain.WeeklyRemunerationKind.EXTRA_PREMIUM,
            ),
            receipt.input.remuneration.map { it.kind },
        )
        assertEquals(
            listOf(
                com.streamentry.linepay.domain.WeeklyPremiumCredit.NOT_APPLICABLE,
                com.streamentry.linepay.domain.WeeklyPremiumCredit.NOT_APPLICABLE,
                com.streamentry.linepay.domain.WeeklyPremiumCredit.NOT_APPLICABLE,
                com.streamentry.linepay.domain.WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM,
                com.streamentry.linepay.domain.WeeklyPremiumCredit.INELIGIBLE,
            ),
            receipt.input.remuneration.map { it.premiumCredit },
        )
        assertEquals("1310", receipt.result.includableRemuneration.amount)
        assertEquals("1380", receipt.result.cashRemuneration.amount)
        assertEquals("20", receipt.result.eligibleExtraPremiumCredit.amount)
        assertEquals("89.17", receipt.result.remainingAdditionalPremium.amount)
        assertEquals("1469.17", receipt.result.expectedCash.amount)
    }

    private fun weeklyRequest(periodIds: List<String>) = AndroidWeeklyReviewRequest(
        startLocal = "2026-10-17 00:00",
        timeZone = "UTC",
        sourcePeriodIds = periodIds,
        straightTimeWages = "1200.00",
        boundaryConfirmed = true,
        singleEmployerConfirmed = true,
        paymentsConfirmed = true,
        completeWorkweek = true,
        applicabilityConfirmed = true,
    )

    private fun twoSavedPeriods(): Triple<AndroidLocalState, AndroidPaycheckSnapshot, AndroidPaycheckSnapshot> {
        var state = AndroidLocalState(profile = profile)
        for (date in listOf("2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22")) {
            state = LinePaycheckRepository.addWork(
                state,
                "$date 07:00",
                "$date 15:00",
                "",
                "",
                "Synthetic weekly source",
            )
        }
        val firstInput = matchingPaycheckInput().copy(
            sourceStartDate = "2026-10-12",
            sourceLastDate = "2026-10-18",
            paidGross = "400.00",
        )
        val (withFirst, first) = LinePaycheckRepository.savePaycheck(state, firstInput, createdAtEpochSeconds = 10)
        val nextProfile = profile.copy(
            id = java.util.UUID.randomUUID().toString(),
            cycleStartDate = "2026-10-19",
            version = "2",
        )
        state = withFirst.copy(profile = nextProfile)
        val secondInput = matchingPaycheckInput().copy(
            sourceStartDate = "2026-10-19",
            sourceLastDate = "2026-10-25",
            paidGross = "800.00",
        )
        val (withSecond, second) = LinePaycheckRepository.savePaycheck(state, secondInput, createdAtEpochSeconds = 11)
        return Triple(withSecond, first, second)
    }

    private fun matchingPaycheckInput() = AndroidPaycheckInput(
        sourceStartDate = "2026-10-12",
        sourceLastDate = "2026-10-18",
        sourceTimeZone = "UTC",
        sourcePeriodConfirmed = true,
        paidGross = "200.00",
        basis = GrossBasisChoice.WAGES_ONLY,
        completeWorkConfirmed = true,
        ruleCoverageConfirmed = true,
    )
}
