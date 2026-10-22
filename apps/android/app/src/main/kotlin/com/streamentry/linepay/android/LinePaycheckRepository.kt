package com.streamentry.linepay.android

import com.streamentry.linepay.domain.Agreement
import com.streamentry.linepay.domain.CalendarPaycycle
import com.streamentry.linepay.domain.CalendarPaycycleCadence
import com.streamentry.linepay.domain.ConfiguredPayCalculator
import com.streamentry.linepay.domain.DailyTier
import com.streamentry.linepay.domain.GrossBasis
import com.streamentry.linepay.domain.GrossPaycheckFacts
import com.streamentry.linepay.domain.LinePaycheckAssessor
import com.streamentry.linepay.domain.Money
import com.streamentry.linepay.domain.MoneyRounding
import com.streamentry.linepay.domain.PaycheckHoursBasis
import com.streamentry.linepay.domain.PaycheckLineFacts
import com.streamentry.linepay.domain.PaycheckSourcePeriod
import com.streamentry.linepay.domain.EarningsLayout
import com.streamentry.linepay.domain.GuaranteeLayout
import com.streamentry.linepay.domain.WorkBreak
import com.streamentry.linepay.domain.WorkInterval
import com.streamentry.linepay.domain.WorkKind
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

data class CurrentPeriodResult(
    val startDate: LocalDate,
    val lastDate: LocalDate,
    val timeZone: ZoneId,
    val expectedWages: String,
    val expectedPerDiem: String,
    val workedSeconds: Long,
    val shifts: Int,
    val boundaryReview: String? = null,
)

data class AndroidPaycheckInput(
    val sourceStartDate: String,
    val sourceLastDate: String,
    val sourceTimeZone: String,
    val sourcePeriodConfirmed: Boolean,
    val paidGross: String,
    val basis: GrossBasisChoice,
    val completeWorkConfirmed: Boolean,
    val ruleCoverageConfirmed: Boolean,
    val confirmedLineFacts: AndroidConfirmedPaycheckLines? = null,
)

object LinePaycheckRepository {
    private val calculator = ConfiguredPayCalculator()

    fun currentPeriod(state: AndroidLocalState): CurrentPeriodResult? {
        val profile = state.profile ?: return null
        require(!profile.requiresPortableRuleConfirmation) { "Confirm a destination configuration before calculating imported work." }
        val window = payWindow(profile)
        val overlapping = workOverlappingWindow(state.work, window.startEpochSeconds, window.endEpochSeconds)
        val selected = workInWindow(state.work, window.startEpochSeconds, window.endEpochSeconds)
        val crossesBoundary = state.work.any { entry ->
            overlaps(entry, window.startEpochSeconds, window.endEpochSeconds) &&
                (entry.startEpochSeconds < window.startEpochSeconds ||
                    entry.endEpochSeconds > window.endEpochSeconds)
        }
        if (crossesBoundary) {
            return CurrentPeriodResult(
                window.startDate,
                window.lastDate,
                window.timeZone,
                "0.00",
                "0.00",
                0,
                overlapping.size,
                "A recorded shift crosses this pay-period boundary. Split or review that shift before using an estimate.",
            )
        }
        val agreement = agreement(profile)
        val work = selected.map(::domainWork)
        val calculation = calculator.calculate(work, agreement)
        return CurrentPeriodResult(
            window.startDate,
            window.lastDate,
            window.timeZone,
            calculation.expectedWages.amount.toPlainString(),
            calculation.expectedAllowances.amount.toPlainString(),
            selected.sumOf { workedSeconds(it) },
            selected.size,
        )
    }

    fun addWork(
        state: AndroidLocalState,
        startLocal: String,
        endLocal: String,
        breakStartLocal: String,
        breakEndLocal: String,
        note: String,
    ): AndroidLocalState {
        val profile = requireNotNull(state.profile) { "Set up a pay profile first." }
        require(!profile.requiresPortableRuleConfirmation) { "Confirm a destination configuration before adding work or comparing a paycheck." }
        val zone = ZoneId.of(profile.payrollTimeZone)
        val start = parseUnambiguousInstant(startLocal, zone)
        val end = parseUnambiguousInstant(endLocal, zone)
        require(end > start) { "Shift end must follow its start." }
        val breaks = if (breakStartLocal.isBlank() && breakEndLocal.isBlank()) {
            emptyList()
        } else {
            require(breakStartLocal.isNotBlank() && breakEndLocal.isNotBlank()) {
                "Enter both unpaid break times, or leave both blank."
            }
            val breakStart = parseUnambiguousInstant(breakStartLocal, zone)
            val breakEnd = parseUnambiguousInstant(breakEndLocal, zone)
            require(breakStart >= start && breakEnd <= end && breakEnd > breakStart) {
                "Unpaid break must be inside the shift."
            }
            listOf(AndroidWorkBreak(startEpochSeconds = breakStart, endEpochSeconds = breakEnd))
        }
        val entry = AndroidWorkEntry(
            startEpochSeconds = start,
            endEpochSeconds = end,
            timeZone = zone.id,
            breaks = breaks,
            note = note.trim(),
        )
        AndroidLocalStateValidator.validateWork(entry)
        val next = state.copy(
            work = (state.work + entry).sortedBy { it.startEpochSeconds },
        )
        AndroidLocalStateValidator.validate(next)
        return next
    }

    fun savePaycheck(
        state: AndroidLocalState,
        input: AndroidPaycheckInput,
        createdAtEpochSeconds: Long = 0,
    ): Pair<AndroidLocalState, AndroidPaycheckSnapshot> {
        val snapshot = capturePaycheck(requireNotNull(state.profile) { "Set up a pay profile first." }, state.work, input, createdAtEpochSeconds, UUID.randomUUID().toString())
        val next = state.copy(checks = listOf(snapshot) + state.checks)
        AndroidLocalStateValidator.validate(next)
        return next to snapshot
    }

    /** Replay only a receipt that actually recorded this capture version, never earlier unknown inputs. */
    internal fun replayCapturedPaycheck(check: AndroidPaycheckSnapshot): AndroidPaycheckSnapshot = capturePaycheck(
        check.profile, check.work,
        AndroidPaycheckInput(requireNotNull(check.sourceStartDate), requireNotNull(check.sourceLastDate), requireNotNull(check.sourceTimeZone),
            check.sourcePeriodConfirmed, check.paidGross, check.grossBasis, check.completeWorkConfirmed, check.ruleCoverageConfirmed,
            requireNotNull(check.confirmedLineFacts)),
        check.createdAtEpochSeconds, check.id,
    )

    private fun capturePaycheck(profile: AndroidRuleProfile, workEntries: List<AndroidWorkEntry>, input: AndroidPaycheckInput,
        createdAtEpochSeconds: Long, id: String): AndroidPaycheckSnapshot {
        require(!profile.requiresPortableRuleConfirmation) { "Confirm a destination configuration before adding work or comparing a paycheck." }
        val captured = input.confirmedLineFacts ?: AndroidConfirmedPaycheckLines(currencyCode = profile.currencyCode.uppercase())
        captured.validate()
        require(captured.currencyCode == profile.currencyCode.uppercase()) { "Statement currency differs from the configured profile. No currency conversion or comparison was performed." }
        val window = payWindow(profile)
        val overlapping = workOverlappingWindow(workEntries, window.startEpochSeconds, window.endEpochSeconds)
        val selected = workInWindow(workEntries, window.startEpochSeconds, window.endEpochSeconds)
        val partial = workEntries.any { entry ->
            overlaps(entry, window.startEpochSeconds, window.endEpochSeconds) &&
                (entry.startEpochSeconds < window.startEpochSeconds ||
                    entry.endEpochSeconds > window.endEpochSeconds)
        }
        val agreement = agreement(profile)
        val calculation = if (partial) null else calculator.calculate(selected.map(::domainWork), agreement)
        val basis = when (input.basis) {
            GrossBasisChoice.WAGES_ONLY -> GrossBasis.WAGES_ONLY
            GrossBasisChoice.WAGES_AND_PER_DIEM -> GrossBasis.WAGES_AND_PER_DIEM
        }
        val paidGross = Money(observedDecimal(input.paidGross, hours = false), profile.currencyCode)
        val facts = GrossPaycheckFacts(
            paidGross = paidGross,
            paidPerDiem = captured.paidPerDiem?.let { Money(observedDecimal(it, hours = false), profile.currencyCode) },
            completeWork = input.completeWorkConfirmed && !partial,
            basis = basis,
            unreviewedFields = !input.sourcePeriodConfirmed,
            unsupportedRules = !input.ruleCoverageConfirmed ||
                !profile.rulesReviewedByWorker || partial,
            // Manually identified lines do not resolve complete-workweek mapping or legal scope.
            // A separate weekly reference cannot clear this outstanding review.
            weeklyReviewPending = true,
        )
        val sourceStart = LocalDate.parse(input.sourceStartDate)
        val sourceLast = LocalDate.parse(input.sourceLastDate)
        val sourceZone = ZoneId.of(input.sourceTimeZone)
        val source = PaycheckSourcePeriod(
            firstDate = sourceStart,
            lastDate = sourceLast,
            timeZone = sourceZone,
            confirmed = input.sourcePeriodConfirmed,
        )
        val lineFacts = PaycheckLineFacts(
            gross = facts,
            layout = EarningsLayout.valueOf(captured.layout),
            hoursBasis = PaycheckHoursBasis.valueOf(captured.hoursBasis),
            guaranteeLayout = GuaranteeLayout.valueOf(captured.guaranteeLayout),
            amounts = captured.domainAmounts(profile.currencyCode),
            hours = captured.domainHours(),
            completeEarningsLines = captured.completeEarningsLines,
        )
        val assessment = LinePaycheckAssessor().assess(
            calculation = calculation,
            baseline = agreement,
            facts = lineFacts,
            target = window,
            source = source,
            snapshots = listOf(agreement),
        )
        return AndroidPaycheckSnapshot(
            id = id,
            createdAtEpochSeconds = createdAtEpochSeconds,
            profile = profile.copy(),
            work = overlapping.map { it.copy(breaks = it.breaks.toList()) },
            targetStartDate = window.startDate.toString(),
            targetLastDate = window.lastDate.toString(),
            payrollTimeZone = window.timeZone.id,
            sourceStartDate = sourceStart.toString(),
            sourceLastDate = sourceLast.toString(),
            sourceTimeZone = sourceZone.id,
            sourcePeriodConfirmed = input.sourcePeriodConfirmed,
            paidGross = paidGross.amount.toPlainString(),
            grossBasis = input.basis,
            completeWorkConfirmed = input.completeWorkConfirmed,
            ruleCoverageConfirmed = input.ruleCoverageConfirmed,
            expectedGross = assessment.expectedGross?.amount?.toPlainString(),
            difference = assessment.difference?.amount?.toPlainString(),
            verdict = assessment.verdict.name,
            periodMatch = assessment.periodMatch.name,
            reviewReasons = assessment.reviewReasons.map { it.name },
            comparisons = assessment.comparisons.map {
                AndroidLineComparisonSnapshot(
                    field = it.field.name,
                    expected = it.expected.toPlainString(),
                    paid = it.paid.toPlainString(),
                    difference = it.difference.toPlainString(),
                    unit = it.unit.name,
                    currencyCode = it.currencyCode,
                    componentIds = it.componentIds.map(UUID::toString),
                )
            },
            components = calculation?.components.orEmpty().map {
                AndroidPayComponentSnapshot(
                    category = it.category.name,
                    date = it.date.toString(),
                    amount = it.amount.amount.toPlainString(),
                    currencyCode = it.amount.currencyCode,
                    multiplier = it.multiplier?.toPlainString(),
                    seconds = it.seconds?.toPlainString(),
                    agreementId = it.reference.id,
                    agreementVersion = it.reference.version,
                    explanation = it.explanation,
                    ruleKeys = it.ruleKeys,
                    id = it.id.toString(),
                    workId = it.workId?.toString(),
                )
            },
            engine = assessment.engine,
            coverage = assessment.coverage.name,
            confirmedLineFacts = captured.copy(),
        )
    }

    fun payWindow(profile: AndroidRuleProfile) = CalendarPaycycle.window(
        cadence = when (profile.cadence) {
            PayCycleChoice.WEEKLY -> CalendarPaycycleCadence.WEEKLY
            PayCycleChoice.BIWEEKLY -> CalendarPaycycleCadence.BIWEEKLY
            PayCycleChoice.SEMIMONTHLY -> CalendarPaycycleCadence.SEMIMONTHLY
            PayCycleChoice.CUSTOM -> CalendarPaycycleCadence.MANUAL
        },
        startDate = LocalDate.parse(profile.cycleStartDate),
        manualEndDate = profile.customLastDate?.let(LocalDate::parse),
        timeZone = ZoneId.of(profile.payrollTimeZone),
    )

    fun parseUnambiguousInstant(value: String, zone: ZoneId): Long {
        val normalized = value.trim().replace(' ', 'T')
        val local = LocalDateTime.parse(normalized)
        val offsets = zone.rules.getValidOffsets(local)
        require(offsets.size == 1) {
            "This local time is missing or repeated in the selected time zone. Choose an unambiguous time."
        }
        return local.toEpochSecond(offsets.single())
    }

    private fun agreement(profile: AndroidRuleProfile): Agreement {
        val overtimeThreshold = profile.dailyOvertimeAfterHours?.let(::BigDecimal)
        val tiers = overtimeThreshold?.let {
            listOf(DailyTier(afterHours = it, multiplier = BigDecimal(profile.dailyOvertimeMultiplier)))
        }.orEmpty()
        return Agreement(
            id = profile.calculationRuleID ?: profile.id,
            version = profile.version,
            hourlyRate = Money(BigDecimal(profile.hourlyRate), profile.currencyCode),
            outsideScheduleMultiplier = BigDecimal(profile.outsideScheduleMultiplier),
            dailyTiers = tiers,
            perDiemPerWorkDate = profile.perDiemPerWorkDate?.let {
                Money(BigDecimal(it), profile.currencyCode)
            },
            rounding = MoneyRounding(scale = 2, mode = RoundingMode.HALF_UP),
            effectiveStart = if (profile.hasIndependentEffectiveDates) profile.effectiveStartDate?.let(LocalDate::parse) else LocalDate.parse(profile.cycleStartDate),
            effectiveEnd = if (profile.hasIndependentEffectiveDates) profile.effectiveEndDateInclusive?.let(LocalDate::parse) else null,
        )
    }

    private fun domainWork(entry: AndroidWorkEntry) = WorkInterval(
        id = UUID.fromString(entry.id),
        start = entry.startEpochSeconds,
        end = entry.endEpochSeconds,
        zone = ZoneId.of(entry.timeZone),
        kind = WorkKind.REGULAR,
        breaks = entry.breaks.map {
            WorkBreak(UUID.fromString(it.id), it.startEpochSeconds, it.endEpochSeconds)
        },
    )

    private fun workInWindow(entries: List<AndroidWorkEntry>, start: Long, end: Long) =
        entries.filter { it.startEpochSeconds >= start && it.endEpochSeconds <= end }

    private fun workOverlappingWindow(entries: List<AndroidWorkEntry>, start: Long, end: Long) =
        entries.filter { overlaps(it, start, end) }

    private fun overlaps(entry: AndroidWorkEntry, start: Long, end: Long) =
        entry.endEpochSeconds > start && entry.startEpochSeconds < end

    private fun workedSeconds(entry: AndroidWorkEntry) =
        entry.endEpochSeconds - entry.startEpochSeconds -
            entry.breaks.sumOf { it.endEpochSeconds - it.startEpochSeconds }

}
