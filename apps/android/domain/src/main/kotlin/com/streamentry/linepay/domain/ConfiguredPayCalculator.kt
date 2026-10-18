package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/** Pure configured-rule calculation. No Android, clock, locale, storage, commerce or network dependency. */
class ConfiguredPayCalculator {
    private data class DayKey(val date: LocalDate, val zone: ZoneId)
    private data class Segment(val entry: WorkInterval, val start: Long, val end: Long, val date: LocalDate,
        val agreement: Agreement, val inSchedule: Boolean)
    private data class RawPrice(val category: ComponentCategory, val workId: UUID?, val date: LocalDate,
        val seconds: BigDecimal?, val multiplier: BigDecimal?, val rate: Money?, val agreement: Agreement,
        val numerator: BigDecimal, val explanation: String, val ruleKeys: List<String>)
    private data class RoundKey(val category: ComponentCategory, val multiplier: BigDecimal?,
        val currency: String, val rule: MoneyRounding)

    fun calculate(work: List<WorkInterval>, baseline: Agreement,
        changes: List<AgreementChange> = emptyList()): CalculationResult {
        require(work.map { it.id }.toSet().size == work.size) { "Duplicate work identity" }
        val entries = work.sortedBy { it.start }
        require(entries.zipWithNext().all { (a,b) -> a.end <= b.start }) { "Overlapping work" }
        require(changes.size <= 256)
        val timeline = changes.sortedBy { it.effectiveDate }
        require(timeline.map { it.effectiveDate }.toSet().size == timeline.size)
        require((listOf(baseline.version) + timeline.map { it.agreement.version }).toSet().size == timeline.size + 1)
        require(timeline.all { it.agreement.id == baseline.id && it.agreement.hourlyRate.currencyCode == baseline.hourlyRate.currencyCode &&
            it.agreement.rounding.scale == baseline.rounding.scale && it.agreement.rounding.mode == baseline.rounding.mode })
        fun rule(date: LocalDate): Agreement = timeline.lastOrNull { it.effectiveDate <= date }?.agreement ?: baseline
        val segments = entries.flatMap { split(it, ::rule) }.sortedBy { it.start }
        val cumulative = mutableMapOf<DayKey, BigDecimal>()
        val prices = mutableListOf<RawPrice>()
        for (segment in segments) {
            val agreement = segment.agreement
            require(agreement.effectiveStart == null || segment.date >= agreement.effectiveStart)
            require(agreement.effectiveEnd == null || segment.date <= agreement.effectiveEnd)
            val day = DayKey(segment.date, segment.entry.zone)
            var position = cumulative[day] ?: ZERO
            var remaining = BigDecimal(segment.end - segment.start)
            while (remaining > ZERO) {
                val tier = agreement.dailyTiers.lastOrNull { it.afterHours * SECONDS_PER_HOUR <= position }
                val next = agreement.dailyTiers.map { it.afterHours * SECONDS_PER_HOUR }.firstOrNull { it > position }
                val seconds = if (next == null) remaining else remaining.min(next - position)
                val overtime = tier?.multiplier ?: ONE
                val schedule = if (segment.inSchedule) ONE else agreement.outsideScheduleMultiplier
                val weekday = agreement.weekdayPremiums.filter { it.weekday == segment.date.dayOfWeek }.maxOfOrNull { it.multiplier } ?: ONE
                val dated = agreement.datePremiums.filter { it.date == segment.date }.maxOfOrNull { it.multiplier } ?: ONE
                val multiplier = maxOf(overtime, schedule, weekday, dated)
                val keys = mutableListOf("base")
                if (overtime > ONE && overtime.compareTo(multiplier) == 0) keys += "dailyOvertime"
                if (schedule > ONE && schedule.compareTo(multiplier) == 0) keys += "schedule"
                if (weekday > ONE && weekday.compareTo(multiplier) == 0) keys += "weekday"
                if (dated > ONE && dated.compareTo(multiplier) == 0) keys += "date"
                prices += RawPrice(ComponentCategory.WORKED_HOURS, segment.entry.id, segment.date,
                    seconds, multiplier, agreement.hourlyRate, agreement,
                    agreement.hourlyRate.amount * seconds * multiplier,
                    "Recorded work priced with highest applicable confirmed multiplier", frozen(keys))
                remaining -= seconds
                position += seconds
            }
            cumulative[day] = position
        }
        val calls = entries.filter { it.kind == WorkKind.CALLOUT }
        for (entry in calls.filter { it.calloutEventId == null }) {
            val start = localDate(entry.start, entry.zone)
            val end = localDate(entry.end - 1, entry.zone)
            if (rule(start).calloutMinimumHours != null || timeline.any {
                it.effectiveDate > start && it.effectiveDate <= end && it.agreement.calloutMinimumHours != null }) {
                throw PayReviewRequired(PayReviewRequired.Reason.CALLOUT_IDENTITY)
            }
        }
        for (group in calls.filter { it.calloutEventId != null }.groupBy { it.calloutEventId }.values.sortedBy { it.first().start }) {
            val first = group.first(); val last = group.last()
            if (group.any { it.zone != first.zone } || group.zipWithNext().any { (a,b) -> a.end != b.start }) {
                throw PayReviewRequired(PayReviewRequired.Reason.CALLOUT_INTERACTION)
            }
            val date = localDate(first.start, first.zone)
            val agreement = rule(date)
            val worked = BigDecimal(group.sumOf { it.workedSeconds })
            val crossed = timeline.filter { it.effectiveDate > date && it.effectiveDate <= localDate(last.end - 1, first.zone) }
            if (crossed.isNotEmpty() && (listOf(agreement) + crossed.map { it.agreement }).any {
                it.calloutMinimumHours?.let { hours -> hours * SECONDS_PER_HOUR > worked } == true }) {
                throw PayReviewRequired(PayReviewRequired.Reason.CALLOUT_RATE_CHANGE)
            }
            val minimum = agreement.calloutMinimumHours ?: continue
            val missing = minimum * SECONDS_PER_HOUR - worked
            if (missing <= ZERO) continue
            val ids = group.map { it.id }.toSet()
            val paid = prices.filter { it.category == ComponentCategory.WORKED_HOURS && it.workId in ids }
            val multipliers = paid.mapNotNull { it.multiplier }.map { it.stripTrailingZeros() }.toSet()
            if (multipliers.size != 1 || paid.any { it.rate != agreement.hourlyRate } || entries.any {
                it.id !in ids && it.kind == WorkKind.REGULAR && it.start >= last.end &&
                    BigDecimal(it.start) < BigDecimal(first.start) + minimum * SECONDS_PER_HOUR }) {
                throw PayReviewRequired(PayReviewRequired.Reason.CALLOUT_INTERACTION)
            }
            val multiplier = multipliers.single()
            prices += RawPrice(ComponentCategory.CALLOUT_GUARANTEE, first.id, date, missing,
                multiplier, agreement.hourlyRate, agreement, agreement.hourlyRate.amount * missing * multiplier,
                "One isolated minimum for the confirmed physical callout; actual work is unchanged", listOf("callout"))
        }
        val days = segments.associateBy { DayKey(it.date, it.entry.zone) }
        for ((day, segment) in days.entries.sortedWith(compareBy({ it.key.date }, { it.key.zone.id }))) {
            val allowance = segment.agreement.perDiemPerWorkDate ?: continue
            prices += RawPrice(ComponentCategory.PER_DIEM, null, day.date, null, null, null,
                segment.agreement, allowance.amount * SECONDS_PER_HOUR,
                "Configured flat per diem for worked local date", listOf("perDiem"))
        }
        return CalculationResult(round(prices), baseline.hourlyRate.currencyCode, baseline.rounding)
    }

    private fun split(entry: WorkInterval, rule: (LocalDate) -> Agreement): List<Segment> {
        val result = mutableListOf<Segment>()
        var cursor = entry.start
        while (cursor < entry.end) {
            val date = localDate(cursor, entry.zone)
            val nextDay = date.plusDays(1).atStartOfDay(entry.zone).toEpochSecond()
            val end = minOf(entry.end, nextDay)
            require(end > cursor)
            val agreement = rule(date)
            val windows = agreement.schedule.filter { it.weekday == date.dayOfWeek }
            val bounds = sortedSetOf(cursor, end)
            for (window in windows) {
                for (time in listOf(window.start, window.end)) {
                    val local = date.atTime(time)
                    val offsets = entry.zone.rules.getValidOffsets(local)
                    // No silent wall-clock normalization. Such a rule needs an explicit review.
                    if (offsets.size != 1) throw PayReviewRequired(PayReviewRequired.Reason.SCHEDULE_CLOCK_AMBIGUITY)
                    val point = local.toEpochSecond(offsets.single())
                    if (point > cursor && point < end) bounds += point
                }
            }
            for (pause in entry.breaks) {
                if (pause.start > cursor && pause.start < end) bounds += pause.start
                if (pause.end > cursor && pause.end < end) bounds += pause.end
            }
            for ((start, finish) in bounds.zipWithNext()) {
                val middle = start + (finish - start) / 2
                if (entry.breaks.any { middle >= it.start && middle < it.end }) continue
                val clock = Instant.ofEpochSecond(middle).atZone(entry.zone).toLocalTime()
                result += Segment(entry, start, finish, date, agreement,
                    windows.any { clock >= it.start && clock < it.end })
            }
            cursor = end
        }
        return result
    }

    private fun round(prices: List<RawPrice>): List<PayComponent> {
        val amounts = MutableList(prices.size) { ZERO }
        val groups = mutableMapOf<RoundKey, MutableList<Int>>()
        for ((index, price) in prices.withIndex()) {
            val rule = price.agreement.rounding
            if (rule.scope == RoundingScope.LEGACY_SEGMENTS) {
                amounts[index] = price.numerator.divide(SECONDS_PER_HOUR, rule.scale, rule.mode)
            } else {
                groups.getOrPut(RoundKey(price.category, price.multiplier?.stripTrailingZeros(),
                    price.agreement.hourlyRate.currencyCode, rule)) { mutableListOf() } += index
            }
        }
        for ((key, indices) in groups) {
            val target = indices.fold(ZERO) { sum, i -> sum + prices[i].numerator }.divide(SECONDS_PER_HOUR, key.rule.scale, key.rule.mode)
            val floors = indices.map { prices[it].numerator.divide(SECONDS_PER_HOUR, key.rule.scale, RoundingMode.FLOOR) }
            var residual = target - floors.fold(ZERO, BigDecimal::add)
            val unit = ONE.movePointLeft(key.rule.scale)
            val ranked = indices.indices.sortedWith { a,b ->
                val left = prices[indices[a]].numerator - floors[a] * SECONDS_PER_HOUR
                val right = prices[indices[b]].numerator - floors[b] * SECONDS_PER_HOUR
                val comparison = right.compareTo(left)
                if (comparison == 0) a.compareTo(b) else comparison
            }
            for (position in indices.indices) amounts[indices[position]] = floors[position]
            for (position in ranked) if (residual >= unit) { amounts[indices[position]] += unit; residual -= unit }
            check(residual.compareTo(ZERO) == 0) { "Invalid rounded allocation" }
        }
        return prices.mapIndexed { index, price ->
            val reference = AgreementReference(price.agreement.id, price.agreement.version, price.agreement.hourlyRate)
            val identity = listOf(price.category.name, price.workId?.toString() ?: "", price.date.toString(),
                price.agreement.id, price.agreement.version, index.toString()).joinToString("\u0000")
            PayComponent(UUID.nameUUIDFromBytes(identity.toByteArray(StandardCharsets.UTF_8)), price.category,
                price.workId, price.date, price.seconds, price.multiplier, price.rate,
                Money(amounts[index], price.agreement.hourlyRate.currencyCode), reference, price.explanation, frozen(price.ruleKeys))
        }
    }
    private fun localDate(seconds: Long, zone: ZoneId): LocalDate = Instant.ofEpochSecond(seconds).atZone(zone).toLocalDate()
}
