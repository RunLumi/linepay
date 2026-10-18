package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.Collections
import java.util.Locale
import java.util.UUID

internal val ZERO: BigDecimal = BigDecimal.ZERO
internal val ONE: BigDecimal = BigDecimal.ONE
internal val SECONDS_PER_HOUR: BigDecimal = BigDecimal(3600)
internal fun <T> frozen(values: Collection<T>): List<T> = Collections.unmodifiableList(ArrayList(values))

class Money(amount: BigDecimal, currencyCode: String) {
    val amount: BigDecimal = amount.stripTrailingZeros()
    val currencyCode: String = currencyCode.uppercase(Locale.ROOT)
    init { require(currencyCode.matches(Regex("[A-Za-z]{3}"))) { "Currency must be explicit" } }
    operator fun plus(other: Money): Money {
        require(currencyCode == other.currencyCode) { "Currency mismatch" }
        return Money(amount + other.amount, currencyCode)
    }
    operator fun minus(other: Money): Money {
        require(currencyCode == other.currencyCode) { "Currency mismatch" }
        return Money(amount - other.amount, currencyCode)
    }
    fun rounded(rule: MoneyRounding): Money = Money(amount.setScale(rule.scale, rule.mode), currencyCode)
    override fun equals(other: Any?): Boolean = other is Money && currencyCode == other.currencyCode && amount.compareTo(other.amount) == 0
    override fun hashCode(): Int = 31 * currencyCode.hashCode() + amount.hashCode()
    override fun toString(): String = "$currencyCode ${amount.toPlainString()}"
}

enum class RoundingScope { PAY_CATEGORY, LEGACY_SEGMENTS }
data class MoneyRounding(val scale: Int = 2, val mode: RoundingMode = RoundingMode.HALF_UP,
    val scope: RoundingScope = RoundingScope.PAY_CATEGORY) {
    init { require(scale in 0..8) }
}
enum class WorkKind { REGULAR, CALLOUT, OTHER }
data class WorkBreak(val id: UUID, val start: Long, val end: Long) { init { require(end > start) } }
class WorkInterval(val id: UUID, val start: Long, val end: Long, val zone: ZoneId,
    val kind: WorkKind = WorkKind.REGULAR, breaks: List<WorkBreak> = emptyList(), val calloutEventId: UUID? = null) {
    val breaks: List<WorkBreak> = frozen(breaks.sortedBy { it.start })
    init {
        require(start in -62_135_596_800L..253_402_300_799L && end in -62_135_596_800L..253_402_300_799L && end > start)
        require(kind == WorkKind.CALLOUT || calloutEventId == null)
        require(this.breaks.map { it.id }.toSet().size == this.breaks.size)
        require(this.breaks.all { it.start >= start && it.end <= end })
        require(this.breaks.zipWithNext().all { (a,b) -> a.end <= b.start })
        require(workedSeconds > 0)
    }
    val workedSeconds: Long get() = end - start - breaks.sumOf { it.end - it.start }
}
data class DailyTier(val afterHours: BigDecimal, val multiplier: BigDecimal) {
    init { require(afterHours >= ZERO && multiplier >= ONE) }
}
data class WeekdayPremium(val weekday: DayOfWeek, val multiplier: BigDecimal) { init { require(multiplier >= ONE) } }
data class DatePremium(val date: LocalDate, val multiplier: BigDecimal) { init { require(multiplier >= ONE) } }
data class ScheduleWindow(val weekday: DayOfWeek, val start: LocalTime, val end: LocalTime) {
    init { require(end > start && start.second == 0 && end.second == 0 && start.nano == 0 && end.nano == 0) }
}
class Agreement(val id: String, val version: String, val hourlyRate: Money,
    schedule: List<ScheduleWindow> = emptyList(), val outsideScheduleMultiplier: BigDecimal = ONE,
    dailyTiers: List<DailyTier> = emptyList(), weekdayPremiums: List<WeekdayPremium> = emptyList(),
    datePremiums: List<DatePremium> = emptyList(), val calloutMinimumHours: BigDecimal? = null,
    val perDiemPerWorkDate: Money? = null, val rounding: MoneyRounding = MoneyRounding(),
    val effectiveStart: LocalDate? = null, val effectiveEnd: LocalDate? = null) {
    val schedule = frozen(schedule)
    val dailyTiers = frozen(dailyTiers.sortedBy { it.afterHours })
    val weekdayPremiums = frozen(weekdayPremiums)
    val datePremiums = frozen(datePremiums)
    init {
        require(id.isNotBlank() && version.isNotBlank() && id.length <= 256 && version.length <= 128)
        require(hourlyRate.amount >= ZERO && outsideScheduleMultiplier >= ONE)
        require(this.dailyTiers.map { it.afterHours.stripTrailingZeros() }.toSet().size == this.dailyTiers.size)
        require(calloutMinimumHours == null || calloutMinimumHours > ZERO)
        require(perDiemPerWorkDate == null || (perDiemPerWorkDate.amount >= ZERO && perDiemPerWorkDate.currencyCode == hourlyRate.currencyCode))
        require(effectiveStart == null || effectiveEnd == null || effectiveEnd >= effectiveStart)
    }
}
data class AgreementChange(val effectiveDate: LocalDate, val agreement: Agreement)
data class AgreementReference(val id: String, val version: String, val hourlyRate: Money)
enum class ComponentCategory { WORKED_HOURS, CALLOUT_GUARANTEE, PER_DIEM }
data class PayComponent(val id: UUID, val category: ComponentCategory, val workId: UUID?,
    val date: LocalDate, val seconds: BigDecimal?, val multiplier: BigDecimal?, val baseRate: Money?,
    val amount: Money, val reference: AgreementReference, val explanation: String, val ruleKeys: List<String>)
enum class CalculationCoverage { CONFIGURED_RULES_ONLY }
class CalculationResult(components: List<PayComponent>, val currency: String, private val finalRounding: MoneyRounding = MoneyRounding()) {
    val components = frozen(components)
    val expectedWages: Money get() = Money(components.filter { it.category != ComponentCategory.PER_DIEM }.fold(ZERO) { total, part -> total + part.amount.amount }, currency)
    val expectedAllowances: Money get() = Money(components.filter { it.category == ComponentCategory.PER_DIEM }.fold(ZERO) { total, part -> total + part.amount.amount }, currency)
    val total: Money get() = (expectedWages + expectedAllowances).rounded(finalRounding)
    val engine: String = "linepay.android.configured-pay/1"
    val coverage: CalculationCoverage = CalculationCoverage.CONFIGURED_RULES_ONLY
}
class PayReviewRequired(val reason: Reason): IllegalArgumentException(reason.name) {
    enum class Reason { CALLOUT_IDENTITY, CALLOUT_INTERACTION, CALLOUT_RATE_CHANGE, SCHEDULE_CLOCK_AMBIGUITY }
}
