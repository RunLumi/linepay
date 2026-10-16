package com.streamentry.linepay.domain

import java.util.UUID

enum class GrossBasis { UNCONFIRMED, WAGES_ONLY, WAGES_AND_PER_DIEM }
enum class GrossVerdict { MATCHES, POSSIBLE_SHORTFALL, POSSIBLE_OVERPAYMENT, NEEDS_REVIEW, NOT_COMPARABLE }
enum class GrossReviewReason { NO_CALCULATION, INCOMPLETE_WORK, UNCONFIRMED_GROSS_BASIS,
    LEGACY_ROUNDING, UNSUPPORTED_RULES, UNREVIEWED_FIELDS, WEEKLY_REVIEW_PENDING, OFFSETTING_DIFFERENCES }
enum class GrossComparisonField { GROSS_PAY, PER_DIEM_PAY }
class GrossPaycheckFacts(val paidGross: Money, val completeWork: Boolean, val basis: GrossBasis,
    val unreviewedFields: Boolean, val unsupportedRules: Boolean, val weeklyReviewPending: Boolean,
    val paidPerDiem: Money? = null)
class GrossComparison(val field: GrossComparisonField, val expected: Money, val paid: Money,
    val difference: Money, componentIds: List<UUID>) {
    val componentIds: List<UUID> = frozen(componentIds)
}
class GrossPaycheckAssessment(val expectedGross: Money?, val paidGross: Money, val difference: Money?,
    val verdict: GrossVerdict, comparisons: List<GrossComparison>, reviewReasons: List<GrossReviewReason>) {
    val comparisons = frozen(comparisons)
    val reviewReasons = frozen(reviewReasons)
    val engine = "linepay.android.configured-gross/1"
    val coverage = CalculationCoverage.CONFIGURED_RULES_ONLY
}

/** A scoped comparison, never a legal-pay conclusion or verification of unentered earnings lines.
 * The caller must independently confirm period matching and the completeness flags.
 * Save the result with immutable work/rule/statement snapshots; never recalculate saved verdicts.
 */
class GrossPaycheckAssessor {
    fun assess(calculation: CalculationResult?, currency: String, facts: GrossPaycheckFacts,
        rounding: MoneyRounding): GrossPaycheckAssessment {
        val code = Money(ZERO,currency).currencyCode
        require(facts.paidGross.currencyCode == code &&
            (facts.paidPerDiem == null || facts.paidPerDiem.currencyCode == code)) { "Currency mismatch" }
        require(facts.paidGross.amount >= ZERO && (facts.paidPerDiem == null || facts.paidPerDiem.amount >= ZERO)) {
            "Negative paycheck observation"
        }
        if (calculation == null) return GrossPaycheckAssessment(null,facts.paidGross,null,
            GrossVerdict.NOT_COMPARABLE,emptyList(),listOf(GrossReviewReason.NO_CALCULATION))
        require(calculation.currency == code && calculation.components.all {
            it.amount.currencyCode == code && it.amount.amount >= ZERO
        }) { "Invalid calculation currency or amount" }
        val reasons = mutableListOf<GrossReviewReason>()
        val expected = when {
            !facts.completeWork -> { reasons += GrossReviewReason.INCOMPLETE_WORK; null }
            facts.basis == GrossBasis.UNCONFIRMED -> { reasons += GrossReviewReason.UNCONFIRMED_GROSS_BASIS; null }
            facts.basis == GrossBasis.WAGES_ONLY -> calculation.expectedWages
            else -> calculation.total
        }
        if (rounding.scope == RoundingScope.LEGACY_SEGMENTS) reasons += GrossReviewReason.LEGACY_ROUNDING
        if (facts.unsupportedRules) reasons += GrossReviewReason.UNSUPPORTED_RULES
        if (facts.unreviewedFields) reasons += GrossReviewReason.UNREVIEWED_FIELDS
        if (facts.weeklyReviewPending) reasons += GrossReviewReason.WEEKLY_REVIEW_PENDING
        val comparisons = mutableListOf<GrossComparison>()
        fun compare(field: GrossComparisonField, expectedAmount: Money, paid: Money, parts: List<PayComponent>) =
            GrossComparison(field,expectedAmount,paid,(expectedAmount-paid).rounded(rounding),parts.map { it.id })
        if (expected != null) comparisons += compare(GrossComparisonField.GROSS_PAY,expected,facts.paidGross,
            calculation.components.filter { facts.basis == GrossBasis.WAGES_AND_PER_DIEM || it.category != ComponentCategory.PER_DIEM })
        if (facts.paidPerDiem != null) comparisons += compare(GrossComparisonField.PER_DIEM_PAY,
            calculation.expectedAllowances,facts.paidPerDiem,calculation.components.filter { it.category == ComponentCategory.PER_DIEM })
        val difference = comparisons.firstOrNull { it.field == GrossComparisonField.GROSS_PAY }?.difference
        val verdict = when {
            expected == null -> GrossVerdict.NOT_COMPARABLE
            reasons.isNotEmpty() -> GrossVerdict.NEEDS_REVIEW
            difference!!.amount.compareTo(ZERO) == 0 && comparisons.any { it.difference.amount.compareTo(ZERO) != 0 } -> {
                reasons += GrossReviewReason.OFFSETTING_DIFFERENCES
                GrossVerdict.NEEDS_REVIEW
            }
            difference.amount > ZERO -> GrossVerdict.POSSIBLE_SHORTFALL
            difference.amount < ZERO -> GrossVerdict.POSSIBLE_OVERPAYMENT
            else -> GrossVerdict.MATCHES
        }
        return GrossPaycheckAssessment(expected,facts.paidGross,difference,verdict,comparisons,reasons)
    }
}
