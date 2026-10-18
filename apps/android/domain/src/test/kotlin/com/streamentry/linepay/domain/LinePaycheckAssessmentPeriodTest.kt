package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LinePaycheckAssessmentPeriodTest {
    @Test
    fun unconfirmedOrMismatchedSourcePeriodCannotProduceLineComparisons() {
        val utc = ZoneId.of("UTC")
        val target = CalendarPaycycle.window(
            CalendarPaycycleCadence.MANUAL,
            LocalDate.parse("2026-09-07"),
            LocalDate.parse("2026-09-07"),
            utc,
        )
        val agreement = Agreement("synthetic-period", "1", Money(BigDecimal("50"), "USD"))
        val facts = PaycheckLineFacts(
            GrossPaycheckFacts(
                paidGross = Money(BigDecimal.ZERO, "USD"),
                completeWork = true,
                basis = GrossBasis.WAGES_ONLY,
                unreviewedFields = false,
                unsupportedRules = false,
                weeklyReviewPending = false,
            ),
            layout = EarningsLayout.FULL_RATE_BUCKETS,
            hoursBasis = PaycheckHoursBasis.ACTUAL_WORK,
            guaranteeLayout = GuaranteeLayout.SEPARATE_LINE,
        )
        val wrongDate = PaycheckSourcePeriod(
            target.startDate.plusDays(1), target.lastDate.plusDays(1), utc, confirmed = true,
        )
        val wrongZone = PaycheckSourcePeriod(
            target.startDate, target.lastDate, ZoneId.of("America/Los_Angeles"), confirmed = true,
        )
        val unconfirmed = PaycheckSourcePeriod(
            target.startDate, target.lastDate, utc, confirmed = false,
        )

        for ((source, expectedMatch) in listOf(
            unconfirmed to PaycheckPeriodMatch.UNCONFIRMED_PERIOD,
            wrongDate to PaycheckPeriodMatch.DIFFERENT_PERIOD,
            wrongZone to PaycheckPeriodMatch.DIFFERENT_PERIOD,
        )) {
            val result = LinePaycheckAssessor().assess(
                calculation = null,
                baseline = agreement,
                facts = facts,
                target = target,
                source = source,
            )
            assertEquals(expectedMatch, result.periodMatch)
            assertEquals(GrossVerdict.NOT_COMPARABLE, result.verdict)
            assertNull(result.expectedGross)
            assertNull(result.difference)
            assertTrue(result.comparisons.isEmpty())
            assertTrue(result.reviewReasons.isNotEmpty())
        }
    }
}
