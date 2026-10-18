package com.streamentry.linepay.android

import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
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
        assertEquals("MATCHES", check.verdict)
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

    private fun matchingPaycheckInput() = AndroidPaycheckInput(
        sourceStartDate = "2026-10-12",
        sourceLastDate = "2026-10-18",
        sourceTimeZone = "UTC",
        sourcePeriodConfirmed = true,
        paidGross = "200.00",
        basis = GrossBasisChoice.WAGES_ONLY,
        completeWorkConfirmed = true,
        ruleCoverageConfirmed = true,
        weeklyReviewConfirmed = true,
    )
}
