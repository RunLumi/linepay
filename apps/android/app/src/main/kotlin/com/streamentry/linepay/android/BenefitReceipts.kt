package com.streamentry.linepay.android

import com.streamentry.linepay.domain.BenefitContributionCalculator
import com.streamentry.linepay.domain.ContributionBasis
import com.streamentry.linepay.domain.ContributionPeriod
import com.streamentry.linepay.domain.ContributionRule
import com.streamentry.linepay.domain.ContributionStatement
import com.streamentry.linepay.domain.EligibilitySegment
import com.streamentry.linepay.domain.Money
import com.streamentry.linepay.domain.MoneyRounding
import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/** Frozen worker-entered evidence, separate from wage and paycheck receipts. Dates are end-exclusive. */
data class AndroidBenefitPeriod(val start: String, val endExclusive: String, val timeZone: String)
data class AndroidBenefitSource(val title: String, val reference: String, val eligibilityEvidence: String)
data class AndroidBenefitSegment(
    val id: String = UUID.randomUUID().toString(),
    val ruleId: String = UUID.randomUUID().toString(),
    val ruleVersion: String,
    val period: AndroidBenefitPeriod,
    val effectivePeriod: AndroidBenefitPeriod,
    val basis: ContributionBasis,
    val rate: String,
    val quantity: String,
    val source: AndroidBenefitSource,
    val eligibilityConfirmed: Boolean,
)
data class AndroidBenefitStatement(
    val fundName: String,
    val fundIdentifier: String,
    val currencyCode: String,
    val period: AndroidBenefitPeriod,
    val employerContribution: String?,
    val quantity: String?,
    val quantityBasis: ContributionBasis?,
    val sourceReference: String,
    val confirmed: Boolean,
)
data class AndroidBenefitInput(
    val fundName: String,
    val fundIdentifier: String,
    val currencyCode: String,
    val period: AndroidBenefitPeriod,
    val segments: List<AndroidBenefitSegment>,
    val completeEligibilityConfirmed: Boolean,
    val statement: AndroidBenefitStatement?,
)
data class AndroidBenefitComponent(val segmentId: String, val unroundedContribution: String)
data class AndroidBenefitResult(
    val expected: String,
    val paid: String?,
    val difference: String?,
    val eligibleQuantity: String?,
    val basis: ContributionBasis?,
    val quantityDifference: String?,
    val status: String,
    val limitation: String,
    val components: List<AndroidBenefitComponent>,
    val engine: String,
    val roundingScale: Int,
    val roundingMode: String,
)
data class AndroidBenefitReceipt(
    val id: String,
    val createdAtEpochSeconds: Long,
    val revisesReceiptId: String?,
    val input: AndroidBenefitInput,
    val result: AndroidBenefitResult,
)

object AndroidBenefitRepository {
    const val MAXIMUM_RECEIPTS = 128
    const val MAXIMUM_SEGMENTS = 100
    const val COVERAGE = "Employer contributions for this confirmed fund and period only. Eligibility and source applicability are worker-provided, not independently verified. Contribution caps and eligibility exceptions are not evaluated. Contribution or remittance timing is not verified; the selected work period does not establish when a contribution is due or credited. Excludes employee deductions, vesting, balances, investment returns, prevailing-wage compliance and legal entitlement. Does not change wage or paycheck results."

    fun preview(
        input: AndroidBenefitInput,
        revisesReceiptId: String? = null,
        createdAtEpochSeconds: Long = java.time.Instant.now().epochSecond,
    ): AndroidBenefitReceipt {
        val frozen = input.copy(segments = input.segments.toList())
        val receipt = AndroidBenefitReceipt(
            UUID.randomUUID().toString(), createdAtEpochSeconds, revisesReceiptId, frozen, calculate(frozen),
        )
        validateReceipt(receipt)
        return receipt
    }

    fun append(state: AndroidLocalState, receipt: AndroidBenefitReceipt): AndroidLocalState {
        AndroidLocalStateValidator.validate(state)
        validateReceipt(receipt)
        require(state.benefitReviews.size < MAXIMUM_RECEIPTS) { "Benefit receipt limit reached. Export a backup before deleting older receipt families." }
        require(state.benefitReviews.none { it.id == receipt.id }) { "A saved benefit receipt cannot be overwritten." }
        receipt.revisesReceiptId?.let { previous ->
            require(state.benefitReviews.any { it.id == previous }) { "The original benefit receipt is no longer available." }
        }
        return state.copy(benefitReviews = state.benefitReviews + receipt).also(AndroidLocalStateValidator::validate)
    }

    /** Delete the selected receipt and every descendant revision; never leave an orphan lineage. */
    fun deleteFamily(state: AndroidLocalState, id: String): AndroidLocalState {
        require(state.benefitReviews.any { it.id == id }) { "Benefit receipt is unavailable." }
        val removed = mutableSetOf(id)
        do {
            val priorCount = removed.size
            state.benefitReviews.filter { it.revisesReceiptId in removed }.forEach { removed += it.id }
        } while (removed.size != priorCount)
        return state.copy(benefitReviews = state.benefitReviews.filterNot { it.id in removed })
            .also(AndroidLocalStateValidator::validate)
    }

    fun validateState(state: AndroidLocalState) {
        require(state.benefitReviews.size <= MAXIMUM_RECEIPTS) { "Too many benefit receipts." }
        val preceding = mutableSetOf<String>()
        state.benefitReviews.forEach { receipt ->
            validateReceipt(receipt)
            require(receipt.id !in preceding) { "Benefit receipt identities must be unique." }
            require(receipt.revisesReceiptId == null || receipt.revisesReceiptId in preceding) { "A benefit revision must retain its earlier original." }
            preceding += receipt.id
        }
    }

    fun validateReceipt(receipt: AndroidBenefitReceipt) {
        identity(receipt.id)
        receipt.revisesReceiptId?.let(::identity)
        require(receipt.createdAtEpochSeconds in 0..253402300799L) { "Invalid benefit receipt date." }
        require(receipt.result == calculate(receipt.input)) { "A benefit receipt does not reproduce its saved result." }
    }

    private fun calculate(input: AndroidBenefitInput): AndroidBenefitResult {
        metadata(input.fundName, 200)
        metadata(input.fundIdentifier, 300)
        currency(input.currencyCode)
        val period = period(input.period)
        require(input.segments.size in 1..MAXIMUM_SEGMENTS) { "Enter between 1 and $MAXIMUM_SEGMENTS eligible segments." }
        val fund = fundId(input.fundIdentifier)
        val ruleEvidence = mutableMapOf<String, Pair<AndroidBenefitSource, AndroidBenefitPeriod>>()
        val segments = input.segments.map { segment ->
            identity(segment.id)
            identity(segment.ruleId)
            metadata(segment.ruleVersion, 128)
            metadata(segment.source.title, 200)
            metadata(segment.source.reference, 2000)
            metadata(segment.source.eligibilityEvidence, 2000)
            val evidence = segment.source to segment.effectivePeriod
            val oldEvidence = ruleEvidence.put(segment.ruleId, evidence)
            require(oldEvidence == null || oldEvidence == evidence) { "One rule identity must retain the same source evidence." }
            EligibilitySegment(
                UUID.fromString(segment.id), period(segment.period),
                ContributionRule(UUID.fromString(segment.ruleId), fund, segment.ruleVersion, segment.basis,
                    decimal(segment.rate), input.currencyCode, period(segment.effectivePeriod)),
                decimal(segment.quantity), segment.eligibilityConfirmed,
            )
        }
        val statement = input.statement?.let {
            metadata(it.fundName, 200)
            metadata(it.fundIdentifier, 300)
            currency(it.currencyCode)
            metadata(it.sourceReference, 2000)
            ContributionStatement(
                fundId(it.fundIdentifier), it.currencyCode, period(it.period),
                it.employerContribution?.let { value -> Money(decimal(value), it.currencyCode) },
                it.quantity?.let(::decimal), it.quantityBasis, it.confirmed,
            )
        }
        val result = BenefitContributionCalculator().calculate(
            period, segments, input.completeEligibilityConfirmed, statement, MoneyRounding(scale = 2, mode = java.math.RoundingMode.HALF_UP, scope = com.streamentry.linepay.domain.RoundingScope.PAY_CATEGORY),
        )
        fun BigDecimal.canonical() = stripTrailingZeros().toPlainString()
        return AndroidBenefitResult(
            result.expected.amount.canonical(), result.paid?.amount?.canonical(), result.difference?.amount?.canonical(),
            result.eligibleQuantity?.canonical(), result.basis, result.quantityDifference?.canonical(),
            result.status.name, result.limitation.name,
            result.components.map { AndroidBenefitComponent(it.segmentId.toString(), it.unroundedContribution.amount.canonical()) },
            result.engine, 2, "HALF_UP",
        )
    }

    private fun period(value: AndroidBenefitPeriod): ContributionPeriod {
        require(value.start.matches(Regex("\\d{4}-\\d{2}-\\d{2}")) && value.endExclusive.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) { "Use ISO dates YYYY-MM-DD." }
        require(value.timeZone.length in 1..100) { "Enter a valid payroll time zone." }
        return ContributionPeriod(LocalDate.parse(value.start), LocalDate.parse(value.endExclusive), ZoneId.of(value.timeZone))
    }

    private fun decimal(value: String): BigDecimal {
        require(value.length in 1..48 && value.matches(Regex("(?:0|[1-9][0-9]{0,23})(?:\\.[0-9]{1,12})?"))) { "Enter a nonnegative decimal without commas, signs or exponent notation (up to 12 decimal places)." }
        return BigDecimal(value).also { require(it.precision() <= 38) { "Decimal exceeds supported precision." } }
    }

    private fun identity(value: String) {
        require(UUID.fromString(value).toString() == value) { "Invalid benefit receipt identity." }
    }
    private fun metadata(value: String, maximum: Int) {
        require(value.isNotBlank() && value == value.trim() && value.length <= maximum && value.none { it.isISOControl() }) { "Source and fund details must be nonempty, trimmed text of at most $maximum characters." }
    }
    private fun currency(value: String) {
        require(value.matches(Regex("[A-Z]{3}"))) { "Enter an uppercase three-letter currency code." }
    }
    private fun fundId(identifier: String) = UUID.nameUUIDFromBytes(("linepay.benefit.fund/" + identifier).toByteArray(Charsets.UTF_8))
}

fun benefitStatusLabel(status: String, limitation: String): String = when {
    limitation == "UNITS_ONLY" && status == "COMPARED_VALUES_MATCH" -> "Compared units match"
    limitation == "UNITS_ONLY" && status == "POSSIBLE_DIFFERENCE" -> "Possible unit difference"
    status == "COMPARED_VALUES_MATCH" -> "Compared values match"
    status == "POSSIBLE_DIFFERENCE" -> "Possible difference"
    status == "NOT_COMPARABLE" -> "Not comparable"
    else -> "Not verified"
}

fun benefitBasisLabel(basis: ContributionBasis): String = when (basis) {
    ContributionBasis.ELIGIBLE_HOUR -> "Eligible hours"
    ContributionBasis.ELIGIBLE_DAY -> "Eligible days"
    ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS -> "Percent of eligible earnings"
    ContributionBasis.FIXED_PERIOD -> "Fixed period"
}

fun benefitLimitationLabel(limitation: String): String = when (limitation) {
    "STATEMENT_MISSING" -> "No statement entered; payment is not verified."
    "STATEMENT_UNCONFIRMED" -> "Statement details are not confirmed."
    "SCOPE_MISMATCH" -> "Statement fund, currency or exact period differs. No comparison was made."
    "NO_COMPARABLE_VALUES" -> "No compatible statement values were provided."
    "UNITS_ONLY" -> "Only compatible units were compared; payment is not verified."
    "AMOUNT_ONLY_DIFFERENT_BASIS" -> "Only amounts were compared; statement units use a different basis."
    else -> "Only the confirmed values shown were compared."
}
