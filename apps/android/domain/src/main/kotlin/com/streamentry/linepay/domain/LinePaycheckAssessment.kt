package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.ZoneId
import java.util.Collections
import java.util.UUID

enum class EarningsLayout { UNCONFIRMED, FULL_RATE_BUCKETS, BASE_PLUS_PREMIUM }
enum class PaycheckHoursBasis { UNCONFIRMED, ACTUAL_WORK, PAID_EQUIVALENTS }
enum class GuaranteeLayout { UNCONFIRMED, SEPARATE_LINE, INCLUDED_IN_HOURLY_LINES }
enum class PaycheckUnit { MONEY, HOURS }
enum class PaycheckLineField(val unit: PaycheckUnit) {
    GROSS_PAY(PaycheckUnit.MONEY), PER_DIEM_PAY(PaycheckUnit.MONEY),
    REGULAR_PAY(PaycheckUnit.MONEY), OVERTIME_PAY(PaycheckUnit.MONEY), DOUBLE_TIME_PAY(PaycheckUnit.MONEY),
    CALLOUT_PAY(PaycheckUnit.MONEY), REGULAR_HOURS(PaycheckUnit.HOURS),
    OVERTIME_HOURS(PaycheckUnit.HOURS), DOUBLE_TIME_HOURS(PaycheckUnit.HOURS)
}
enum class PaycheckPeriodMatch { CONFIRMED_SAME_PERIOD, UNCONFIRMED_PERIOD, DIFFERENT_PERIOD }
enum class PaycheckLineReviewReason {
    NO_CALCULATION, INCOMPLETE_WORK, UNCONFIRMED_GROSS_BASIS, LEGACY_ROUNDING,
    UNSUPPORTED_RULES, UNREVIEWED_FIELDS, WEEKLY_REVIEW_PENDING, OFFSETTING_DIFFERENCES,
    UNCONFIRMED_PERIOD, DIFFERENT_PERIOD, UNKNOWN_GUARANTEE_MAPPING, UNKNOWN_EARNINGS_LAYOUT,
    UNKNOWN_HOURS_BASIS, UNUSUAL_MULTIPLIER, MISSING_EXACT_TIME_OR_RULE_EVIDENCE,
    CONFLICTING_CALLOUT_MAPPING, CONFLICTING_EARNINGS, EMPTY_COMPLETE_BREAKDOWN
}
class PaycheckSourcePeriod(val firstDate: LocalDate?, val lastDate: LocalDate?,
    val timeZone: ZoneId?, val confirmed: Boolean) {
    init {
        require((firstDate == null) == (lastDate == null)) { "Confirm both source dates or neither" }
        require(firstDate == null || lastDate!! >= firstDate) { "Source dates are reversed" }
        require(!confirmed || (firstDate != null && timeZone != null)) { "Unknown source period cannot be confirmed" }
    }
}
class PaycheckLineFacts(val gross: GrossPaycheckFacts, val layout: EarningsLayout,
    val hoursBasis: PaycheckHoursBasis, val guaranteeLayout: GuaranteeLayout,
    amounts: Map<PaycheckLineField, Money> = emptyMap(), hours: Map<PaycheckLineField, BigDecimal> = emptyMap(),
    val completeEarningsLines: Boolean = false) {
    val amounts: Map<PaycheckLineField, Money> = Collections.unmodifiableMap(LinkedHashMap(amounts))
    val hours: Map<PaycheckLineField, BigDecimal> = Collections.unmodifiableMap(LinkedHashMap(hours))
    init {
        require(this.amounts.keys.all { it in MONEY_FIELDS }) { "Unsupported earnings observation" }
        require(this.hours.keys.all { it in HOURS_FIELDS }) { "Unsupported hours observation" }
        require(this.amounts.values.all { it.amount >= ZERO && it.currencyCode == gross.paidGross.currencyCode }) {
            "Invalid observed earnings amount/currency"
        }
        require(this.hours.values.all { it >= ZERO && it <= BigDecimal(10000) }) { "Invalid observed hours" }
    }
    companion object {
        internal val MONEY_FIELDS = setOf(PaycheckLineField.REGULAR_PAY, PaycheckLineField.OVERTIME_PAY,
            PaycheckLineField.DOUBLE_TIME_PAY, PaycheckLineField.CALLOUT_PAY)
        internal val HOURS_FIELDS = setOf(PaycheckLineField.REGULAR_HOURS, PaycheckLineField.OVERTIME_HOURS,
            PaycheckLineField.DOUBLE_TIME_HOURS)
    }
}
class PaycheckLineComparison(val field: PaycheckLineField, val expected: BigDecimal, val paid: BigDecimal,
    val difference: BigDecimal, val currencyCode: String, componentIds: List<UUID>) {
    val componentIds: List<UUID> = frozen(componentIds)
    val unit: PaycheckUnit = this.field.unit
}
class LinePaycheckAssessment(val expectedGross: Money?, val paidGross: Money, val difference: Money?,
    val verdict: GrossVerdict, val periodMatch: PaycheckPeriodMatch, val sourcePeriod: PaycheckSourcePeriod,
    comparisons: List<PaycheckLineComparison>, reasons: List<PaycheckLineReviewReason>) {
    val comparisons: List<PaycheckLineComparison> = frozen(comparisons)
    val reviewReasons: List<PaycheckLineReviewReason> = frozen(reasons)
    val engine = "linepay.android.configured-lines/1"
    val coverage = CalculationCoverage.CONFIGURED_RULES_ONLY
}

/** New explicit comparison only. Persist its original work, exact calculation, source dates,
 * observations and complete rule snapshots together; this never upgrades a saved gross receipt.
 * Source confirmation is a worker assertion, not independent verification or weekly entitlement.
 */
class LinePaycheckAssessor {
    fun assess(calculation: CalculationResult?, baseline: Agreement, facts: PaycheckLineFacts,
        target: CalendarPaycycleWindow, source: PaycheckSourcePeriod,
        snapshots: List<Agreement> = listOf(baseline)): LinePaycheckAssessment {
        val currency = baseline.hourlyRate.currencyCode
        // Preserve the existing observation admission even when source dates prohibit comparison.
        GrossPaycheckAssessor().assess(null,currency,facts.gross,baseline.rounding)
        val periodMatch = when {
            !source.confirmed -> PaycheckPeriodMatch.UNCONFIRMED_PERIOD
            source.firstDate == target.startDate && source.lastDate == target.lastDate &&
                source.timeZone == target.timeZone -> PaycheckPeriodMatch.CONFIRMED_SAME_PERIOD
            else -> PaycheckPeriodMatch.DIFFERENT_PERIOD
        }
        if (periodMatch != PaycheckPeriodMatch.CONFIRMED_SAME_PERIOD) return LinePaycheckAssessment(
            null,facts.gross.paidGross,null,GrossVerdict.NOT_COMPARABLE,periodMatch,source,emptyList(),
            listOf(if (periodMatch == PaycheckPeriodMatch.UNCONFIRMED_PERIOD)
                PaycheckLineReviewReason.UNCONFIRMED_PERIOD else PaycheckLineReviewReason.DIFFERENT_PERIOD))
        val base = GrossPaycheckAssessor().assess(calculation,currency,facts.gross,baseline.rounding)
        val reasons = base.reviewReasons.map { PaycheckLineReviewReason.valueOf(it.name) }.toMutableList()
        val comparisons = base.comparisons.map { part -> PaycheckLineComparison(
            if (part.field == GrossComparisonField.GROSS_PAY) PaycheckLineField.GROSS_PAY else PaycheckLineField.PER_DIEM_PAY,
            part.expected.amount,part.paid.amount,part.difference.amount,currency,part.componentIds) }.toMutableList()
        if (calculation == null) return LinePaycheckAssessment(base.expectedGross,base.paidGross,base.difference,
            base.verdict,periodMatch,source,comparisons,reasons)
        require(calculation.components.map { it.id }.toSet().size == calculation.components.size) { "Duplicate ledger component" }
        val definitions = snapshots.toList().associateBy { it.id to it.version }
        require(definitions.size == snapshots.size) { "Ambiguous rule identity" }
        require(snapshots.all { it.hourlyRate.currencyCode == currency }) { "Mixed rule currencies" }
        val wages = calculation.components.filter { it.category != ComponentCategory.PER_DIEM }
        require(wages.all { (it.seconds == null || it.seconds >= ZERO) &&
            (it.multiplier == null || it.multiplier >= ONE) && (it.baseRate == null || it.baseRate.amount >= ZERO) }) {
            "Invalid hourly trace"
        }
        val guarantees = wages.filter { it.category == ComponentCategory.CALLOUT_GUARANTEE }
        val hasLines = facts.amounts.isNotEmpty() || facts.hours.isNotEmpty()
        val guaranteeKnown = guarantees.isEmpty() || facts.guaranteeLayout != GuaranteeLayout.UNCONFIRMED
        val unusual = wages.any { part -> !listOf(ONE,BigDecimal("1.5"),BigDecimal(2)).any { it.compareTo(part.multiplier ?: ONE) == 0 } }
        if (hasLines && !guaranteeKnown) reasons += PaycheckLineReviewReason.UNKNOWN_GUARANTEE_MAPPING
        if (hasLines && unusual) reasons += PaycheckLineReviewReason.UNUSUAL_MULTIPLIER
        if (hasLines && facts.layout == EarningsLayout.UNCONFIRMED) reasons += PaycheckLineReviewReason.UNKNOWN_EARNINGS_LAYOUT
        val included = wages.filter { it.category == ComponentCategory.WORKED_HOURS || facts.guaranteeLayout == GuaranteeLayout.INCLUDED_IN_HOURLY_LINES }
        val needBase = facts.layout == EarningsLayout.BASE_PLUS_PREMIUM && facts.amounts.keys.any { it != PaycheckLineField.CALLOUT_PAY }
        val missingBase = needBase && included.any { part ->
            val snapshot = definitions[part.reference.id to part.reference.version]
            part.seconds == null || part.baseRate == null || snapshot == null ||
                snapshot.hourlyRate != part.baseRate || snapshot.hourlyRate != part.reference.hourlyRate }
        val hourParts = if (facts.hoursBasis == PaycheckHoursBasis.ACTUAL_WORK)
            wages.filter { it.category == ComponentCategory.WORKED_HOURS } else included
        val missingHours = facts.hours.isNotEmpty() && hourParts.any { it.seconds == null }
        if (missingBase || missingHours) reasons += PaycheckLineReviewReason.MISSING_EXACT_TIME_OR_RULE_EVIDENCE
        fun total(parts: List<PayComponent>) = parts.fold(ZERO) { n,c -> n+c.amount.amount }
        data class Bucket(val category: ComponentCategory, val multiplier: BigDecimal, val rounding: MoneyRounding)
        fun basePay(parts: List<PayComponent>): BigDecimal {
            val groups = mutableMapOf<Bucket,BigDecimal>()
            var result = ZERO
            for (part in parts) {
                val snapshot = definitions.getValue(part.reference.id to part.reference.version)
                val numerator = part.baseRate!!.amount * part.seconds!!
                if (snapshot.rounding.scope == RoundingScope.LEGACY_SEGMENTS) {
                    result += numerator.divide(SECONDS_PER_HOUR,snapshot.rounding.scale,snapshot.rounding.mode)
                } else {
                    val key = Bucket(part.category,(part.multiplier ?: ONE).stripTrailingZeros(),snapshot.rounding)
                    groups[key]=(groups[key] ?: ZERO)+numerator
                }
            }
            return result+groups.entries.fold(ZERO) { n,(key,numerator) ->
                n+numerator.divide(SECONDS_PER_HOUR,key.rounding.scale,key.rounding.mode) }
        }
        fun compareMoney(field: PaycheckLineField, expected: BigDecimal, paid: Money, parts: List<PayComponent>) {
            comparisons += PaycheckLineComparison(field,expected,paid.amount,
                (expected-paid.amount).setScale(baseline.rounding.scale,baseline.rounding.mode),currency,parts.map { it.id })
        }
        if (hasLines && guaranteeKnown && !unusual && facts.layout != EarningsLayout.UNCONFIRMED) {
            for ((field,multiplier) in listOf(PaycheckLineField.REGULAR_PAY to ONE,
                PaycheckLineField.OVERTIME_PAY to BigDecimal("1.5"),PaycheckLineField.DOUBLE_TIME_PAY to BigDecimal(2))) {
                val paid=facts.amounts[field] ?: continue
                if (missingBase) continue
                val selected=included.filter { (facts.layout == EarningsLayout.BASE_PLUS_PREMIUM && field == PaycheckLineField.REGULAR_PAY)
                    || (it.multiplier ?: ONE).compareTo(multiplier)==0 }
                val expected=if (facts.layout == EarningsLayout.FULL_RATE_BUCKETS) total(selected)
                    else if (field == PaycheckLineField.REGULAR_PAY) basePay(selected) else total(selected)-basePay(selected)
                compareMoney(field,expected,paid,selected)
            }
            facts.amounts[PaycheckLineField.CALLOUT_PAY]?.let { paid ->
                if (facts.guaranteeLayout == GuaranteeLayout.SEPARATE_LINE) compareMoney(PaycheckLineField.CALLOUT_PAY,total(guarantees),paid,guarantees)
                else reasons += PaycheckLineReviewReason.CONFLICTING_CALLOUT_MAPPING
            }
            if (facts.hours.isNotEmpty() && facts.hoursBasis == PaycheckHoursBasis.UNCONFIRMED) reasons += PaycheckLineReviewReason.UNKNOWN_HOURS_BASIS
            else if (!missingHours) for ((field,multiplier) in listOf(PaycheckLineField.REGULAR_HOURS to ONE,
                PaycheckLineField.OVERTIME_HOURS to BigDecimal("1.5"),PaycheckLineField.DOUBLE_TIME_HOURS to BigDecimal(2))) {
                val paid=facts.hours[field] ?: continue
                val selected=hourParts.filter { (facts.layout == EarningsLayout.BASE_PLUS_PREMIUM && field == PaycheckLineField.REGULAR_HOURS)
                    || (it.multiplier ?: ONE).compareTo(multiplier)==0 }
                val seconds=selected.fold(ZERO) { n,c -> n+c.seconds!! }
                comparisons += PaycheckLineComparison(field,seconds.divide(SECONDS_PER_HOUR,4,RoundingMode.HALF_UP),paid,
                    (seconds-paid*SECONDS_PER_HOUR).divide(SECONDS_PER_HOUR,4,RoundingMode.HALF_UP),currency,selected.map { it.id })
            }
        }
        val entered=listOf(PaycheckLineField.REGULAR_PAY,PaycheckLineField.OVERTIME_PAY,PaycheckLineField.DOUBLE_TIME_PAY).mapNotNull { facts.amounts[it]?.amount }.toMutableList()
        if (facts.guaranteeLayout == GuaranteeLayout.SEPARATE_LINE) facts.amounts[PaycheckLineField.CALLOUT_PAY]?.let { entered += it.amount }
        if (facts.gross.basis == GrossBasis.WAGES_AND_PER_DIEM) facts.gross.paidPerDiem?.let { entered += it.amount }
        if (facts.gross.basis != GrossBasis.UNCONFIRMED && facts.layout != EarningsLayout.UNCONFIRMED) {
            val subtotal=entered.fold(ZERO,BigDecimal::add)
            if (entered.isNotEmpty() && (subtotal > facts.gross.paidGross.amount ||
                (facts.completeEarningsLines && subtotal.compareTo(facts.gross.paidGross.amount)!=0))) reasons += PaycheckLineReviewReason.CONFLICTING_EARNINGS
            if (facts.completeEarningsLines && entered.isEmpty()) reasons += PaycheckLineReviewReason.EMPTY_COMPLETE_BREAKDOWN
        } else if (facts.completeEarningsLines) reasons += PaycheckLineReviewReason.UNKNOWN_EARNINGS_LAYOUT
        if (facts.completeEarningsLines && !guaranteeKnown) reasons += PaycheckLineReviewReason.UNKNOWN_GUARANTEE_MAPPING
        val differingLines=comparisons.any { it.field != PaycheckLineField.GROSS_PAY && it.difference.compareTo(ZERO)!=0 }
        val verdict=when {
            base.expectedGross == null -> GrossVerdict.NOT_COMPARABLE
            reasons.isNotEmpty() -> GrossVerdict.NEEDS_REVIEW
            base.difference!!.amount.compareTo(ZERO)==0 && differingLines -> {
                reasons += PaycheckLineReviewReason.OFFSETTING_DIFFERENCES;GrossVerdict.NEEDS_REVIEW }
            else -> base.verdict
        }
        return LinePaycheckAssessment(base.expectedGross,base.paidGross,base.difference,verdict,periodMatch,source,comparisons,reasons.distinct())
    }
}
