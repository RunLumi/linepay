package com.streamentry.linepay.android

import java.math.BigDecimal
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class WeeklySourceSelectionTest {
    private val profile = AndroidRuleProfile(hourlyRate = "50", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true)
    private fun work(state: AndroidLocalState, date: String) = LinePaycheckRepository.addWork(state, "$date 08:00", "$date 16:00", "", "", "Synthetic weekly source")
    private fun initial(days: Int = 6): AndroidLocalState {
        var state = AndroidLocalState(profile = profile)
        for (day in 12 until 12 + days) state = work(state, "2026-10-$day")
        return state
    }
    private fun save(state: AndroidLocalState, at: Long = 10) = LinePaycheckRepository.savePaycheck(state,
        AndroidPaycheckInput("2026-10-12", "2026-10-18", "UTC", true, "2400", GrossBasisChoice.WAGES_ONLY, true, true), at)
    private fun request(vararg checks: AndroidPaycheckSnapshot) = AndroidWeeklyReviewRequest("2026-10-12 00:00", "UTC", checks.map { it.id }, "2400",
        boundaryConfirmed = true, singleEmployerConfirmed = true, paymentsConfirmed = true, completeWorkweek = true, applicabilityConfirmed = true)
    private fun preview(state: AndroidLocalState, vararg checks: AndroidPaycheckSnapshot) = AndroidWeeklyReviewRepository.preview(state, request(*checks), 30)
    private fun same(expected: String, actual: String) = assertEquals(0, BigDecimal(expected).compareTo(BigDecimal(actual)))

    @Test fun explicitEarlierSourceRemainsSelectableAndAlternativesAreNeverDeletedOrAddedAsWork() {
        val (firstState, first) = save(initial())
        val (state, later) = save(firstState, 20)
        val receipt = preview(state, first)
        same("172800", receipt.result.qualifyingSeconds)
        same("50", requireNotNull(receipt.result.regularRate).amount)
        same("200", receipt.result.remainingAdditionalPremium.amount)
        same("2600", receipt.result.expectedCash.amount)
        assertEquals(listOf(first.id), receipt.source.workContainingPeriodIds)
        val saved = AndroidWeeklyReviewRepository.append(state, receipt)
        assertEquals(state.checks, saved.checks)
        assertEquals(later, saved.checks.first())
        assertEquals(receipt.result.remainingAdditionalPremium, preview(state, later).result.remainingAdditionalPremium)
        assertThrows(IllegalArgumentException::class.java) { AndroidWeeklyReviewRepository.preview(state, request(), 30) }
        assertThrows(IllegalArgumentException::class.java) { preview(state, first, later) }
    }

    @Test fun alternativeWithDistinctExtraShiftCannotBeOmittedEvenIfItIsAbsentFromTheLiveLedger() {
        val (partialState, partial) = save(initial(5))
        val (state, complete) = save(work(partialState, "2026-10-17"), 20)
        assertThrows(IllegalArgumentException::class.java) { preview(state, partial) }
        assertThrows(IllegalArgumentException::class.java) { preview(state.copy(work = partialState.work), partial) }
        same("172800", preview(state, complete).result.qualifyingSeconds)
        same("200", preview(state, complete).result.remainingAdditionalPremium.amount)
    }

    @Test fun changedFactsForTheSameWorkIdentityRequireTheExactLiveVersionWithoutRewritingOldReceipts() {
        val (firstState, first) = save(initial())
        val frozen = AndroidWeeklyReviewRepository.append(firstState, preview(firstState, first))
        val changed = frozen.copy(work = frozen.work.mapIndexed { index, entry -> if (index == 0) entry.copy(endEpochSeconds = entry.endEpochSeconds + 3600) else entry })
        val (state, revised) = save(changed, 20)
        assertThrows(IllegalArgumentException::class.java) { preview(state, first) }
        same("176400", preview(state, revised).result.qualifyingSeconds)
        val reopened = AndroidLocalStateValidator.validate(androidLocalStateGson().fromJson(androidLocalStateGson().toJson(state), AndroidLocalState::class.java))
        assertEquals(frozen.weeklyReviews, reopened.weeklyReviews)
        assertEquals(first, reopened.checks.single { it.id == first.id })
    }

    @Test fun ruleVersionIsAnExplicitSourceChoiceAndDoesNotInferRemunerationFromTheChosenRate() {
        val (firstState, first) = save(initial())
        val changed = firstState.copy(profile = profile.copy(hourlyRate = "60", version = "2"))
        val (state, revised) = save(changed, 20)
        val originalReview = preview(state, first)
        val revisedReview = preview(state, revised)
        assertEquals("1", originalReview.source.periods.single().profile.version)
        assertEquals("2", revisedReview.source.periods.single().profile.version)
        assertEquals("60", revisedReview.input.work.first().straightRateAmount)
        // Reviewed remuneration is independently entered as2400, so its rate remains2400/48=50.
        same("50", requireNotNull(revisedReview.result.regularRate).amount)
        same("200", revisedReview.result.remainingAdditionalPremium.amount)
        assertNotEquals(originalReview.input.work.first().straightRateAmount, revisedReview.input.work.first().straightRateAmount)
    }

    @Test fun stalePreviewRejectsNewDistinctWorkButAnIdenticalUnselectedAlternativeDoesNotRewriteItsInputs() {
        val (firstState, first) = save(initial())
        val receipt = preview(firstState, first)
        val (withAlternative, _) = save(firstState, 20)
        assertEquals(receipt, AndroidWeeklyReviewRepository.append(withAlternative, receipt).weeklyReviews.single())
        val newWork = work(withAlternative, "2026-10-18")
        assertThrows(IllegalArgumentException::class.java) { AndroidWeeklyReviewRepository.append(newWork, receipt) }
        val (withNewSnapshot, _) = save(newWork, 25)
        assertThrows(IllegalArgumentException::class.java) { AndroidWeeklyReviewRepository.append(withNewSnapshot, receipt) }
        assertThrows(IllegalArgumentException::class.java) { AndroidWeeklyReviewRepository.append(firstState.copy(checks = emptyList()), receipt) }
    }

    @Test fun differingTimeZonesAndOverlappingDateWindowsAreNeverGuessedToBeOnePeriod() {
        val (firstState, first) = save(initial())
        for (otherProfile in listOf(profile.copy(payrollTimeZone = "Etc/UTC"), profile.copy(cycleStartDate = "2026-10-15"))) {
            val (state, other) = save(firstState.copy(profile = otherProfile), 20)
            assertNotEquals(AndroidWeeklyReviewRepository.sourcePeriodKey(first), AndroidWeeklyReviewRepository.sourcePeriodKey(other))
            assertThrows(IllegalArgumentException::class.java) { preview(state, first) }
            assertThrows(IllegalArgumentException::class.java) { preview(state, first, other) }
        }
    }

    @Test fun selectedAdjacentPeriodsWithConflictingVersionsOfOneSpanningShiftRefuse() {
        var state = AndroidLocalState(profile = profile)
        state = LinePaycheckRepository.addWork(state, "2026-10-18 23:00", "2026-10-19 01:00", "", "", "Synthetic spanning work")
        val (firstState, first) = save(state)
        val changed = firstState.copy(profile = profile.copy(cycleStartDate = "2026-10-19"), work = firstState.work.map { it.copy(endEpochSeconds = it.endEpochSeconds + 3600) })
        val (next, second) = save(changed, 20)
        assertThrows(IllegalArgumentException::class.java) { preview(next, first, second) }
    }

    @Test fun reversedExplicitChoicesFreezeChronologicalSourcesAndConserveTheSameTwoPeriodAllocation() {
        var workState = AndroidLocalState(profile = profile)
        for (day in 17..22) workState = work(workState, "2026-10-$day")
        val (firstState, generatedFirst) = save(workState)
        val first = generatedFirst.copy(id = "74000000-0000-0000-0000-000000000001")
        val nextProfile = profile.copy(cycleStartDate = "2026-10-19", version = "2")
        val (secondState, generatedSecond) = LinePaycheckRepository.savePaycheck(firstState.copy(profile = nextProfile, checks = listOf(first)),
            AndroidPaycheckInput("2026-10-19", "2026-10-25", "UTC", true, "1600", GrossBasisChoice.WAGES_ONLY, true, true), 20)
        val second = generatedSecond.copy(id = "74000000-0000-0000-0000-000000000002")
        val state = AndroidLocalStateValidator.validate(secondState.copy(checks = listOf(second, first)))
        val forward = AndroidWeeklyReviewRepository.preview(state, request(first, second).copy(startLocal = "2026-10-17 00:00"), 30)
        val reverse = AndroidWeeklyReviewRepository.preview(state, request(second, first).copy(startLocal = "2026-10-17 00:00"), 30)
        assertEquals(listOf(first.id, second.id), reverse.source.workContainingPeriodIds)
        assertEquals(forward.source, reverse.source)
        assertEquals(forward.result.allocations, reverse.result.allocations)
        same("200", reverse.result.remainingAdditionalPremium.amount)
        // Sixteen and32hours at50 give bases800/1600: floor66.66/133.33, first stable ID receives the residual cent.
        assertEquals(listOf("66.67", "133.33"), reverse.result.allocations.map { it.amount.amount })
        same("200", reverse.result.allocations.fold(BigDecimal.ZERO) { total, row -> total + BigDecimal(row.amount.amount) }.toPlainString())
    }

    @Test fun allDistinctPeriodGroupsAreRequiredEvenWhenOneOnlyContainsWorkOutsideItsSavedDates() {
        val (state, first) = save(initial())
        val unrelatedWindow = first.copy(id = UUID.randomUUID().toString(), targetStartDate = "2026-10-05", targetLastDate = "2026-10-11", confirmedLineFacts = null)
        val candidate = state.copy(checks = listOf(unrelatedWindow, first))
        assertThrows(IllegalArgumentException::class.java) { preview(candidate, first) }
        assertTrue(AndroidWeeklyReviewRepository.periodsContainingWorkInWeek(candidate, "2026-10-12 00:00", "UTC").any { it.id == unrelatedWindow.id })
    }
}
