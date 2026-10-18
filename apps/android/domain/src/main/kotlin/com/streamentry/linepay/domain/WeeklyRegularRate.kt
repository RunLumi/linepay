package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

enum class WeeklyOvertimeApplicability { COVERED_NONEXEMPT_HOURLY, UNKNOWN }
enum class WeeklyRemunerationKind { STRAIGHT_TIME, INCLUDABLE_BONUS, EXCLUDED_CASH, EXTRA_PREMIUM }
enum class WeeklyPremiumCredit { NOT_APPLICABLE, ELIGIBLE_EXTRA_PREMIUM, INELIGIBLE, UNKNOWN }

/** Duration is either exact seconds or an explicit decimal number of hours; never both. */
data class WeeklyWorkFact(
    val id: UUID,
    val payPeriodId: UUID?,
    val hours: BigDecimal? = null,
    val workedSeconds: Long? = null,
    val straightRate: Money,
    val qualifiesForWeeklyOvertime: Boolean,
) {
    internal val seconds: BigDecimal get() = workedSeconds?.let(BigDecimal::valueOf) ?: requireNotNull(hours) * SECONDS_PER_HOUR
    internal val straightNumerator: BigDecimal get() = straightRate.amount * seconds
}

data class WeeklyRemunerationFact(
    val id: UUID,
    val amount: Money,
    val kind: WeeklyRemunerationKind,
    val premiumCredit: WeeklyPremiumCredit = WeeklyPremiumCredit.NOT_APPLICABLE,
) {
    internal val isIncludable: Boolean get() = kind == WeeklyRemunerationKind.STRAIGHT_TIME ||
        kind == WeeklyRemunerationKind.INCLUDABLE_BONUS ||
        (kind == WeeklyRemunerationKind.EXTRA_PREMIUM && premiumCredit == WeeklyPremiumCredit.INELIGIBLE)
}

/** An explicit, fixed 168-hour workweek. Calendar paycycle boundaries supply no implicit facts. */
class WeeklyRegularRateInput(
    val workweekId: UUID,
    val startEpochSeconds: Long,
    val timeZone: ZoneId,
    val currencyCode: String,
    val boundaryConfirmed: Boolean,
    val singleEmployerConfirmed: Boolean,
    val paymentsConfirmed: Boolean,
    val completeWorkweek: Boolean,
    val applicability: WeeklyOvertimeApplicability,
    work: List<WeeklyWorkFact>,
    remuneration: List<WeeklyRemunerationFact>,
    val thresholdHours: BigDecimal = BigDecimal(40),
    val rounding: MoneyRounding = MoneyRounding(),
) {
    val work: List<WeeklyWorkFact> = frozen(work)
    val remuneration: List<WeeklyRemunerationFact> = frozen(remuneration)
}

data class WeeklyPremiumAllocation(
    val id: UUID,
    val payPeriodId: UUID?,
    val amount: Money,
    val basisNumerator: BigDecimal,
) {
    val basisDenominator: Long get() = 3600L
}

class WeeklyRegularRateResult internal constructor(
    val input: WeeklyRegularRateInput,
    val endEpochSeconds: Long,
    val qualifyingSeconds: BigDecimal,
    val overtimeSeconds: BigDecimal,
    val includableRemuneration: Money,
    val regularRate: Money?,
    val statutoryAdditionalPremium: Money,
    val eligibleExtraPremiumCredit: Money,
    val remainingAdditionalPremium: Money,
    val cashRemuneration: Money,
    val expectedCash: Money,
    allocations: List<WeeklyPremiumAllocation>,
) {
    val allocations: List<WeeklyPremiumAllocation> = frozen(allocations)
    val engine: String = "linepay.android.weekly-regular-rate/3"
    val explanation: String = "Restricted complete-workweek reference for explicitly confirmed covered/nonexempt hourly scope. " +
        "Remuneration and premium treatment are confirmed separately from clock work. " +
        "Applicability, source approval and paycheck mapping remain separate reviews."
}

class WeeklyReviewRequired(val reason: Reason) : IllegalArgumentException(reason.name) {
    enum class Reason {
        BOUNDARY_UNCONFIRMED, EMPLOYER_UNCONFIRMED, REMUNERATION_UNCONFIRMED, INCOMPLETE_WORKWEEK,
        APPLICABILITY_UNKNOWN, UNSUPPORTED_THRESHOLD, INVALID_WORKWEEK, INVALID_ROUNDING,
        INVALID_FACT_COLLECTION, DUPLICATE_FACT_ID, INVALID_WORK_FACT, INVALID_REMUNERATION,
        INVALID_CREDIT_CLASSIFICATION, UNKNOWN_PREMIUM_CREDIT, CURRENCY_MISMATCH,
        REMUNERATION_WITHOUT_QUALIFYING_HOURS, ALLOCATION_UNAVAILABLE, ALLOCATION_NOT_CONSERVED,
    }
}

/** Pure restricted reference; no clock, Android, storage, source inference or paycheck verdict. */
class WeeklyRegularRateCalculator {
    fun calculate(input: WeeklyRegularRateInput): WeeklyRegularRateResult {
        validate(input)
        val currency = input.currencyCode
        val rounding = input.rounding
        fun rounded(value: BigDecimal) = Money(value, currency).rounded(rounding)
        fun fraction(numerator: BigDecimal, denominator: BigDecimal) =
            Money(numerator.divide(denominator, rounding.scale, rounding.mode), currency)

        val qualifying = input.work.filter { it.qualifiesForWeeklyOvertime }.fold(ZERO) { sum, fact -> sum + fact.seconds }
        val includable = input.remuneration.filter { it.isIncludable }.fold(ZERO) { sum, fact -> sum + fact.amount.amount }
        val cash = input.remuneration.fold(ZERO) { sum, fact -> sum + fact.amount.amount }
        val credit = input.remuneration.filter { it.premiumCredit == WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM }
            .fold(ZERO) { sum, fact -> sum + fact.amount.amount }
        if (qualifying.signum() == 0 && includable.signum() > 0) fail(WeeklyReviewRequired.Reason.REMUNERATION_WITHOUT_QUALIFYING_HOURS)

        val overtime = (qualifying - input.thresholdHours * SECONDS_PER_HOUR).max(ZERO)
        // Keep the rational fraction intact until each monetary output's rounding boundary.
        // A displayed regular rate or rounded statutory premium must never drive remaining pay.
        val denominator = if (qualifying.signum() > 0) qualifying * BigDecimal(2) else ONE
        val statutoryNumerator = includable * overtime
        val remainingNumerator = (statutoryNumerator - credit * denominator).max(ZERO)
        val statutoryMoney = fraction(statutoryNumerator, denominator)
        val remainingMoney = fraction(remainingNumerator, denominator)
        val cashMoney = rounded(cash)
        val allocations = allocate(remainingMoney, input.work, rounding)

        return WeeklyRegularRateResult(
            input = input,
            endEpochSeconds = input.startEpochSeconds + 604800L,
            qualifyingSeconds = qualifying,
            overtimeSeconds = overtime,
            includableRemuneration = Money(includable, currency),
            regularRate = if (qualifying.signum() > 0) fraction(includable * SECONDS_PER_HOUR, qualifying) else null,
            statutoryAdditionalPremium = statutoryMoney,
            eligibleExtraPremiumCredit = rounded(credit),
            remainingAdditionalPremium = remainingMoney,
            cashRemuneration = cashMoney,
            expectedCash = cashMoney + remainingMoney,
            allocations = allocations,
        )
    }

    private fun validate(input: WeeklyRegularRateInput) {
        if (!input.boundaryConfirmed) fail(WeeklyReviewRequired.Reason.BOUNDARY_UNCONFIRMED)
        if (!input.singleEmployerConfirmed) fail(WeeklyReviewRequired.Reason.EMPLOYER_UNCONFIRMED)
        if (!input.paymentsConfirmed) fail(WeeklyReviewRequired.Reason.REMUNERATION_UNCONFIRMED)
        if (!input.completeWorkweek) fail(WeeklyReviewRequired.Reason.INCOMPLETE_WORKWEEK)
        if (input.applicability != WeeklyOvertimeApplicability.COVERED_NONEXEMPT_HOURLY) fail(WeeklyReviewRequired.Reason.APPLICABILITY_UNKNOWN)
        if (input.thresholdHours.compareTo(BigDecimal(40)) != 0) fail(WeeklyReviewRequired.Reason.UNSUPPORTED_THRESHOLD)
        if (input.startEpochSeconds !in -62135596800L..253401695999L ||
            Instant.ofEpochSecond(input.startEpochSeconds).atZone(input.timeZone).year !in 1..9999 ||
            Instant.ofEpochSecond(input.startEpochSeconds + 604800L).atZone(input.timeZone).year !in 1..9999) {
            fail(WeeklyReviewRequired.Reason.INVALID_WORKWEEK)
        }
        if (input.rounding.scale !in 0..8 || input.rounding.scope != RoundingScope.PAY_CATEGORY || input.rounding.mode !in setOf(
                RoundingMode.HALF_UP, RoundingMode.HALF_EVEN, RoundingMode.FLOOR, RoundingMode.CEILING)) {
            fail(WeeklyReviewRequired.Reason.INVALID_ROUNDING)
        }
        if (!input.currencyCode.matches(Regex("[A-Z]{3}"))) fail(WeeklyReviewRequired.Reason.CURRENCY_MISMATCH)
        if (input.work.size > 2000 || input.remuneration.size > 100) fail(WeeklyReviewRequired.Reason.INVALID_FACT_COLLECTION)
        if (input.work.map { it.id }.toSet().size != input.work.size ||
            input.remuneration.map { it.id }.toSet().size != input.remuneration.size) fail(WeeklyReviewRequired.Reason.DUPLICATE_FACT_ID)
        for (fact in input.work) {
            if ((fact.hours == null) == (fact.workedSeconds == null) ||
                fact.hours?.let { !validAmount(it) } == true ||
                fact.workedSeconds?.let { it !in 0L..604800L } == true || !validAmount(fact.straightRate.amount)) {
                fail(WeeklyReviewRequired.Reason.INVALID_WORK_FACT)
            }
            if (fact.straightRate.currencyCode != input.currencyCode) fail(WeeklyReviewRequired.Reason.CURRENCY_MISMATCH)
        }
        for (fact in input.remuneration) {
            if (!validAmount(fact.amount.amount)) fail(WeeklyReviewRequired.Reason.INVALID_REMUNERATION)
            if (fact.amount.currencyCode != input.currencyCode) fail(WeeklyReviewRequired.Reason.CURRENCY_MISMATCH)
            if ((fact.kind == WeeklyRemunerationKind.EXTRA_PREMIUM) == (fact.premiumCredit == WeeklyPremiumCredit.NOT_APPLICABLE)) {
                fail(WeeklyReviewRequired.Reason.INVALID_CREDIT_CLASSIFICATION)
            }
            if (fact.premiumCredit == WeeklyPremiumCredit.UNKNOWN) fail(WeeklyReviewRequired.Reason.UNKNOWN_PREMIUM_CREDIT)
        }
    }

    private fun allocate(remaining: Money, work: List<WeeklyWorkFact>, rounding: MoneyRounding): List<WeeklyPremiumAllocation> {
        if (remaining.amount.signum() == 0) return emptyList()
        val groups = work.filter { it.qualifiesForWeeklyOvertime && it.seconds.signum() > 0 }.groupBy { it.payPeriodId }
        val bases = groups.mapValues { (_, facts) -> facts.fold(ZERO) { sum, fact -> sum + fact.straightNumerator } }
        val total = bases.values.fold(ZERO, BigDecimal::add)
        if (total.signum() <= 0) fail(WeeklyReviewRequired.Reason.ALLOCATION_UNAVAILABLE)
        val allocations = bases.entries.sortedBy { it.key?.toString() ?: "" }.map { (period, basis) ->
            WeeklyPremiumAllocation(
                id = requireNotNull(groups[period]).minBy { it.id.toString() }.id,
                payPeriodId = period,
                amount = Money((remaining.amount * basis).divide(total, rounding.scale, RoundingMode.FLOOR), remaining.currencyCode),
                basisNumerator = basis,
            )
        }.toMutableList()
        val unit = ONE.movePointLeft(rounding.scale)
        var residual = remaining.amount - allocations.fold(ZERO) { sum, item -> sum + item.amount.amount }
        for (index in allocations.indices) {
            if (residual < unit) break
            val row = allocations[index]
            if (row.basisNumerator.signum() == 0) continue
            allocations[index] = row.copy(amount = row.amount + Money(unit, remaining.currencyCode))
            residual -= unit
        }
        if (residual.signum() != 0) fail(WeeklyReviewRequired.Reason.ALLOCATION_NOT_CONSERVED)
        return allocations
    }

    private fun validAmount(value: BigDecimal): Boolean = value.signum() >= 0 &&
        value <= BigDecimal("10000000") && value.stripTrailingZeros().scale() <= 8
    private fun fail(reason: WeeklyReviewRequired.Reason): Nothing = throw WeeklyReviewRequired(reason)
}
