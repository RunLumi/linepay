package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test

class WeeklyRegularRateBoundaryTest {
    private fun id(number: Int) = UUID.fromString("62000000-0000-0000-0000-${number.toString().padStart(12, '0')}")
    private fun work(number: Int = 1, seconds: Long = 172800, rate: String = "50", period: UUID? = id(100), qualifies: Boolean = true) =
        WeeklyWorkFact(id(number), period, workedSeconds = seconds, straightRate = Money(BigDecimal(rate), "USD"), qualifiesForWeeklyOvertime = qualifies)
    private fun payment(number: Int = 201, amount: String = "2400", kind: WeeklyRemunerationKind = WeeklyRemunerationKind.STRAIGHT_TIME,
        credit: WeeklyPremiumCredit = WeeklyPremiumCredit.NOT_APPLICABLE) =
        WeeklyRemunerationFact(id(number), Money(BigDecimal(amount), "USD"), kind, credit)
    private fun input(work: List<WeeklyWorkFact> = listOf(work()), remuneration: List<WeeklyRemunerationFact> = listOf(payment()),
        boundary: Boolean = true, employer: Boolean = true, payments: Boolean = true, complete: Boolean = true,
        applicability: WeeklyOvertimeApplicability = WeeklyOvertimeApplicability.COVERED_NONEXEMPT_HOURLY,
        threshold: BigDecimal = BigDecimal(40), rounding: MoneyRounding = MoneyRounding(),
        start: String = "2026-09-07T00:00:00Z", zone: String = "UTC") = WeeklyRegularRateInput(
            id(999), Instant.parse(start).epochSecond, ZoneId.of(zone), "USD", boundary, employer, payments, complete,
            applicability, work, remuneration, threshold, rounding,
        )
    private fun calculate(input: WeeklyRegularRateInput) = WeeklyRegularRateCalculator().calculate(input)
    private fun refused(reason: WeeklyReviewRequired.Reason, input: WeeklyRegularRateInput) {
        val failure = assertThrows(WeeklyReviewRequired::class.java) { calculate(input) }
        assertEquals(reason, failure.reason)
    }
    private fun same(expected: String, actual: BigDecimal) = assertEquals(0, BigDecimal(expected).compareTo(actual))

    @Test fun thresholdUsesExactQualifyingSecondsBeforeAtAndAfterFortyHours() {
        for ((seconds, overtime, premium) in listOf(Triple(143999L, "0", "0"), Triple(144000L, "0", "0"), Triple(144001L, "1", "0.01"))) {
            val result = calculate(input(listOf(work(seconds = seconds)), listOf(payment(amount = "2000"))))
            same(overtime, result.overtimeSeconds)
            same(premium, result.remainingAdditionalPremium.amount)
        }
    }

    @Test fun repeatingRateIsNeverRoundedBeforeTheAdditionalPremiumAndCredit() {
        val result = calculate(input(listOf(work(seconds = 180000)), listOf(payment(amount = "10.05"))))
        same("0.20", requireNotNull(result.regularRate).amount)
        same("1.01", result.statutoryAdditionalPremium.amount) // 10.05 × 10 / (2 × 50) = 1.005.
        val credited = calculate(input(listOf(work(seconds = 180000)), listOf(payment(amount = "10.05"),
            payment(202, "0.004", WeeklyRemunerationKind.EXTRA_PREMIUM, WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM))))
        same("1.01", credited.statutoryAdditionalPremium.amount)
        same("0", credited.eligibleExtraPremiumCredit.amount)
        same("1.00", credited.remainingAdditionalPremium.amount) // Round 1.005 − .004, not 1.01 − .00.
        same("11.05", credited.expectedCash.amount)
    }

    @Test fun eachSupportedRoundingModeUsesTheUnroundedFraction() {
        for ((mode, expected) in listOf(RoundingMode.HALF_UP to "1.01", RoundingMode.HALF_EVEN to "1.00",
            RoundingMode.FLOOR to "1.00", RoundingMode.CEILING to "1.01")) {
            val result = calculate(input(listOf(work(seconds = 180000)), listOf(payment(amount = "10.05")), rounding = MoneyRounding(2, mode)))
            same(expected, result.statutoryAdditionalPremium.amount)
        }
    }

    @Test fun allocationConservesEveryCentAndItsIdentityDoesNotDependOnInputOrder() {
        val source = listOf(work(3, 60000, "1", id(103)), work(2, 60000, "1", id(102)), work(1, 60000, "1", id(101)))
        val first = calculate(input(source, listOf(payment(amount = "0.20"))))
        val reversed = calculate(input(source.reversed(), listOf(payment(amount = "0.20"))))
        assertEquals(listOf(id(101), id(102), id(103)), first.allocations.map { it.payPeriodId })
        assertEquals(listOf(Money(BigDecimal("0.01"), "USD"), Money(BigDecimal("0.01"), "USD"), Money(ZERO, "USD")), first.allocations.map { it.amount })
        assertEquals(first.allocations, reversed.allocations)
        same("0.02", first.allocations.fold(ZERO) { sum, row -> sum + row.amount.amount })
        assertEquals(listOf(id(1), id(2), id(3)), first.allocations.map { it.id })
    }

    @Test fun groupBasisRetainsExactSecondsAndUsesTheSmallestSourceIdentity() {
        val result = calculate(input(listOf(work(2, 144001, "19.99", null), work(1, 28799, "19.99", null))))
        val group = result.allocations.single()
        assertNull(group.payPeriodId)
        assertEquals(id(1), group.id)
        same("3454272", group.basisNumerator)
        assertEquals(3600L, group.basisDenominator)
    }

    @Test fun zeroBasisPeriodCannotReceiveARoundingResidual() {
        val source = listOf(work(1, 60000, "0", id(101)), work(2, 60000, "1", id(102)), work(3, 60000, "1", id(103)))
        val result = calculate(input(source, listOf(payment(amount = "0.10"))))
        same("0.01", result.remainingAdditionalPremium.amount)
        assertEquals(listOf(Money(ZERO, "USD"), Money(BigDecimal("0.01"), "USD"), Money(ZERO, "USD")), result.allocations.map { it.amount })
    }

    @Test fun everyAdmissionConfirmationIsIndependentAndUnknownScopeRefuses() {
        refused(WeeklyReviewRequired.Reason.BOUNDARY_UNCONFIRMED, input(boundary = false))
        refused(WeeklyReviewRequired.Reason.EMPLOYER_UNCONFIRMED, input(employer = false))
        refused(WeeklyReviewRequired.Reason.REMUNERATION_UNCONFIRMED, input(payments = false))
        refused(WeeklyReviewRequired.Reason.INCOMPLETE_WORKWEEK, input(complete = false))
        refused(WeeklyReviewRequired.Reason.APPLICABILITY_UNKNOWN, input(applicability = WeeklyOvertimeApplicability.UNKNOWN))
        refused(WeeklyReviewRequired.Reason.UNSUPPORTED_THRESHOLD, input(threshold = BigDecimal(35)))
    }

    @Test fun unknownAndIncompatiblePremiumClassificationsRefuse() {
        refused(WeeklyReviewRequired.Reason.UNKNOWN_PREMIUM_CREDIT, input(remuneration = listOf(payment(),
            payment(202, "240", WeeklyRemunerationKind.EXTRA_PREMIUM, WeeklyPremiumCredit.UNKNOWN))))
        refused(WeeklyReviewRequired.Reason.INVALID_CREDIT_CLASSIFICATION, input(remuneration = listOf(payment(),
            payment(202, "240", WeeklyRemunerationKind.EXTRA_PREMIUM))))
        refused(WeeklyReviewRequired.Reason.INVALID_CREDIT_CLASSIFICATION, input(remuneration = listOf(
            payment(202, "240", WeeklyRemunerationKind.INCLUDABLE_BONUS, WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM))))
    }

    @Test fun explicitlyExcludedCashIsRetainedWithoutBecomingIncludableOrCredit() {
        val result = calculate(input(remuneration = listOf(payment(), payment(202, "100", WeeklyRemunerationKind.EXCLUDED_CASH))))
        same("2400", result.includableRemuneration.amount)
        same("2500", result.cashRemuneration.amount)
        same("200", result.remainingAdditionalPremium.amount)
        same("2700", result.expectedCash.amount)
    }

    @Test fun missingHoursAndZeroAllocationBasisDoNotInventPremiumMapping() {
        refused(WeeklyReviewRequired.Reason.REMUNERATION_WITHOUT_QUALIFYING_HOURS, input(work = listOf(work(qualifies = false))))
        refused(WeeklyReviewRequired.Reason.ALLOCATION_UNAVAILABLE, input(work = listOf(work(rate = "0"))))
        val empty = calculate(input(work = emptyList(), remuneration = listOf(payment(amount = "0"))))
        assertNull(empty.regularRate)
        same("0", empty.expectedCash.amount)
        assertTrue(empty.allocations.isEmpty())
    }

    @Test fun duplicateFactsMixedCurrencyAndInvalidRoundingCannotProduceAnEstimate() {
        refused(WeeklyReviewRequired.Reason.DUPLICATE_FACT_ID, input(work = listOf(work(), work())))
        refused(WeeklyReviewRequired.Reason.DUPLICATE_FACT_ID, input(remuneration = listOf(payment(), payment())))
        refused(WeeklyReviewRequired.Reason.CURRENCY_MISMATCH, input(work = listOf(work().copy(straightRate = Money(BigDecimal(50), "CAD")))))
        refused(WeeklyReviewRequired.Reason.INVALID_ROUNDING, input(rounding = MoneyRounding(scope = RoundingScope.LEGACY_SEGMENTS)))
        refused(WeeklyReviewRequired.Reason.INVALID_ROUNDING, input(rounding = MoneyRounding(mode = RoundingMode.HALF_DOWN)))
    }

    @Test fun durationIsExplicitAndAmbiguousOrInvalidValuesRefuse() {
        refused(WeeklyReviewRequired.Reason.INVALID_WORK_FACT, input(work = listOf(work().copy(hours = BigDecimal(48)))))
        refused(WeeklyReviewRequired.Reason.INVALID_WORK_FACT, input(work = listOf(work().copy(workedSeconds = null))))
        refused(WeeklyReviewRequired.Reason.INVALID_WORK_FACT, input(work = listOf(work(seconds = -1))))
        refused(WeeklyReviewRequired.Reason.INVALID_WORK_FACT, input(work = listOf(work(seconds = 604801))))
        refused(WeeklyReviewRequired.Reason.INVALID_WORK_FACT, input(work = listOf(work(rate = "-1"))))
        refused(WeeklyReviewRequired.Reason.INVALID_REMUNERATION, input(remuneration = listOf(payment(amount = "-1"))))
        refused(WeeklyReviewRequired.Reason.INVALID_REMUNERATION, input(remuneration = listOf(payment(amount = "0.000000001"))))
    }

    @Test fun workweekEndIsFixed168HoursAcrossDstAndNeverASevenDatePaycycle() {
        val result = calculate(input(start = "2026-03-02T12:00:00Z", zone = "America/New_York"))
        assertEquals("2026-03-09T12:00:00Z", Instant.ofEpochSecond(result.endEpochSeconds).toString())
        assertEquals(8, Instant.ofEpochSecond(result.endEpochSeconds).atZone(result.input.timeZone).hour)
        assertEquals(7, Instant.ofEpochSecond(result.input.startEpochSeconds).atZone(result.input.timeZone).hour)
        refused(WeeklyReviewRequired.Reason.INVALID_WORKWEEK, input(start = "9999-12-30T00:00:00Z"))
    }

    @Test fun inputCollectionsAreFrozenAndResultRetainsTheExplicitFacts() {
        val work = mutableListOf(work())
        val payments = mutableListOf(payment())
        val source = input(work, payments)
        work.clear()
        payments.clear()
        val result = calculate(source)
        assertSame(source, result.input)
        assertEquals(1, source.work.size)
        assertEquals(1, source.remuneration.size)
        assertThrows(UnsupportedOperationException::class.java) { (source.work as MutableList<*>).clear() }
        assertThrows(UnsupportedOperationException::class.java) { (result.allocations as MutableList<*>).clear() }
    }
}
