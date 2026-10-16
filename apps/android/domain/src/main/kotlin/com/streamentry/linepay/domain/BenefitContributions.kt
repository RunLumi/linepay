package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

enum class ContributionBasis { ELIGIBLE_HOUR, ELIGIBLE_DAY, PERCENT_OF_ELIGIBLE_EARNINGS, FIXED_PERIOD }
data class ContributionPeriod(val start: LocalDate, val endExclusive: LocalDate, val zone: ZoneId) {
    init { require(start.year in 1..9999 && endExclusive.year in 1..9999 && endExclusive > start) }
    fun contains(other: ContributionPeriod): Boolean = zone == other.zone && start <= other.start && endExclusive >= other.endExclusive
}
class ContributionRule(val id: UUID, val fundId: UUID, val version: String, val basis: ContributionBasis,
    rate: BigDecimal, currencyCode: String, val effectivePeriod: ContributionPeriod) {
    val rate: BigDecimal = rate.stripTrailingZeros()
    val currencyCode: String = Money(ZERO,currencyCode).currencyCode
    init { require(version.isNotBlank() && version.length <= 128 && rate >= ZERO) }
    internal fun fingerprint(): List<Any> = listOf(fundId,version,basis,rate,currencyCode,effectivePeriod)
}
data class EligibilitySegment(val id: UUID, val period: ContributionPeriod, val rule: ContributionRule,
    val quantity: BigDecimal, val confirmed: Boolean)
class ContributionStatement(val fundId: UUID, currencyCode: String, val period: ContributionPeriod,
    val employerContribution: Money?, val quantity: BigDecimal? = null, val quantityBasis: ContributionBasis? = null,
    val confirmed: Boolean) {
    val currencyCode: String = Money(ZERO,currencyCode).currencyCode
}
enum class ContributionStatus { NOT_VERIFIED, NOT_COMPARABLE, COMPARED_VALUES_MATCH, POSSIBLE_DIFFERENCE }
enum class ContributionLimitation { STATEMENT_MISSING, STATEMENT_UNCONFIRMED, SCOPE_MISMATCH,
    NO_COMPARABLE_VALUES, UNITS_ONLY, AMOUNT_ONLY_DIFFERENT_BASIS, CONFIRMED_VALUES_ONLY }
data class ContributionComponent(val segmentId: UUID, val unroundedContribution: Money)
class ContributionResult(val fundId: UUID, val period: ContributionPeriod, val expected: Money,
    val paid: Money?, val difference: Money?, val eligibleQuantity: BigDecimal?, val basis: ContributionBasis?,
    val quantityDifference: BigDecimal?, val status: ContributionStatus, val limitation: ContributionLimitation,
    val statement: ContributionStatement?, segments: List<EligibilitySegment>, components: List<ContributionComponent>) {
    val segments = frozen(segments)
    val components = frozen(components)
    val engine = "linepay.android.confirmed-benefit/1"
}
class ContributionReviewError(val reason: Reason): IllegalArgumentException(reason.name) {
    enum class Reason { INCOMPLETE_COVERAGE, INVALID_ROUNDING, OVERLAPPING_SEGMENTS, INCONSISTENT_RULE,
        UNCONFIRMED_ELIGIBILITY, INVALID_QUANTITY, FUND_MISMATCH, CURRENCY_MISMATCH, RULE_NOT_EFFECTIVE,
        INVALID_STATEMENT, ARITHMETIC_NOT_EXACT }
}

/** One explicitly confirmed fund scope. No automatic wage/OT mapping, eligibility or legal-fringe claim. */
class BenefitContributionCalculator {
    fun calculate(period: ContributionPeriod, segments: List<EligibilitySegment>, completeEligibilityConfirmed: Boolean,
        statement: ContributionStatement?, rounding: MoneyRounding): ContributionResult {
        if (!completeEligibilityConfirmed || segments.isEmpty() || segments.size > 1000) fail(ContributionReviewError.Reason.INCOMPLETE_COVERAGE)
        if (rounding.scope != RoundingScope.PAY_CATEGORY) fail(ContributionReviewError.Reason.INVALID_ROUNDING)
        val ordered=segments.sortedBy { it.period.start }
        if (ordered.map { it.id }.toSet().size != ordered.size) fail(ContributionReviewError.Reason.OVERLAPPING_SEGMENTS)
        val currency=ordered.first().rule.currencyCode
        val fund=ordered.first().rule.fundId
        val bases=ordered.map { it.rule.basis }.toSet()
        val snapshots=mutableMapOf<UUID,List<Any>>()
        val components=mutableListOf<ContributionComponent>()
        var previousEnd=period.start
        var raw=ZERO
        var units=ZERO
        for (segment in ordered) {
            val rule=segment.rule
            val previous=snapshots.put(rule.id,rule.fingerprint())
            if (previous != null && previous != rule.fingerprint()) fail(ContributionReviewError.Reason.INCONSISTENT_RULE)
            if (!segment.confirmed) fail(ContributionReviewError.Reason.UNCONFIRMED_ELIGIBILITY)
            if (segment.quantity < ZERO || (rule.basis == ContributionBasis.FIXED_PERIOD &&
                (segment.quantity.compareTo(ONE) != 0 || ordered.size != 1 || segment.period != period || rule.effectivePeriod != period))) {
                fail(ContributionReviewError.Reason.INVALID_QUANTITY)
            }
            if (rule.fundId != fund) fail(ContributionReviewError.Reason.FUND_MISMATCH)
            if (rule.currencyCode != currency) fail(ContributionReviewError.Reason.CURRENCY_MISMATCH)
            if (!period.contains(segment.period) || !rule.effectivePeriod.contains(segment.period)) fail(ContributionReviewError.Reason.RULE_NOT_EFFECTIVE)
            if (segment.period.start < previousEnd) fail(ContributionReviewError.Reason.OVERLAPPING_SEGMENTS)
            previousEnd=segment.period.endExclusive
            var amount=exact(rule.rate * segment.quantity)
            if (rule.basis == ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS) amount=exact(amount.movePointLeft(2))
            raw=exact(raw+amount)
            if (bases.size == 1) units=exact(units+segment.quantity)
            components += ContributionComponent(segment.id,Money(amount,currency))
        }
        val expected=Money(raw,currency).rounded(rounding)
        val basis=bases.singleOrNull()
        val eligible=if (basis != null) units else null
        fun result(status: ContributionStatus, limitation: ContributionLimitation, paid: Money? = null,
            difference: Money? = null, quantityDifference: BigDecimal? = null) = ContributionResult(
                fund,period,expected,paid,difference,eligible,basis,quantityDifference,status,limitation,statement,ordered,components)
        if (statement == null) return result(ContributionStatus.NOT_VERIFIED,ContributionLimitation.STATEMENT_MISSING)
        if (statement.employerContribution?.amount?.let { it < ZERO } == true ||
            statement.quantity?.let { it < ZERO } == true ||
            (statement.quantity != null) != (statement.quantityBasis != null)) fail(ContributionReviewError.Reason.INVALID_STATEMENT)
        if (!statement.confirmed) return result(ContributionStatus.NOT_VERIFIED,ContributionLimitation.STATEMENT_UNCONFIRMED)
        if (statement.period != period || statement.fundId != fund || statement.currencyCode != currency ||
            statement.employerContribution?.currencyCode?.let { it != currency } == true) {
            return result(ContributionStatus.NOT_COMPARABLE,ContributionLimitation.SCOPE_MISMATCH)
        }
        val difference=statement.employerContribution?.let { Money(exact(expected.amount-it.amount),currency) }
        val unitDifference=if (statement.quantity != null && eligible != null && statement.quantityBasis == basis)
            exact(eligible-statement.quantity) else null
        if (difference == null && unitDifference == null) return result(ContributionStatus.NOT_VERIFIED,ContributionLimitation.NO_COMPARABLE_VALUES)
        val differs=difference?.amount?.compareTo(ZERO)?.let { it != 0 } == true || unitDifference?.compareTo(ZERO)?.let { it != 0 } == true
        val limitation=when {
            difference == null -> ContributionLimitation.UNITS_ONLY
            statement.quantity != null && unitDifference == null -> ContributionLimitation.AMOUNT_ONLY_DIFFERENT_BASIS
            else -> ContributionLimitation.CONFIRMED_VALUES_ONLY
        }
        return result(if (differs) ContributionStatus.POSSIBLE_DIFFERENCE else ContributionStatus.COMPARED_VALUES_MATCH,
            limitation,statement.employerContribution,difference,unitDifference)
    }
    private fun exact(value: BigDecimal): BigDecimal {
        val compact=value.stripTrailingZeros()
        if (compact.precision() > 38 || compact.scale() !in -127..128) fail(ContributionReviewError.Reason.ARITHMETIC_NOT_EXACT)
        return value
    }
    private fun fail(reason: ContributionReviewError.Reason): Nothing = throw ContributionReviewError(reason)
}
