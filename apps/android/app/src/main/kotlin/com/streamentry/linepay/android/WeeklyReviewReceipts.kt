package com.streamentry.linepay.android

import com.streamentry.linepay.domain.Money
import com.streamentry.linepay.domain.MoneyRounding
import com.streamentry.linepay.domain.RoundingScope
import com.streamentry.linepay.domain.WeeklyOvertimeApplicability
import com.streamentry.linepay.domain.WeeklyPremiumAllocation
import com.streamentry.linepay.domain.WeeklyPremiumCredit
import com.streamentry.linepay.domain.WeeklyRegularRateCalculator
import com.streamentry.linepay.domain.WeeklyRegularRateInput
import com.streamentry.linepay.domain.WeeklyRegularRateResult
import com.streamentry.linepay.domain.WeeklyRemunerationFact
import com.streamentry.linepay.domain.WeeklyRemunerationKind
import com.streamentry.linepay.domain.WeeklyWorkFact
import java.math.BigDecimal
import java.math.RoundingMode
import java.nio.charset.StandardCharsets
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/** A frozen projection of one saved paycheck period used as a weekly review source. */
data class AndroidWeeklySourcePeriodSnapshot(
    val periodId: String,
    val targetStartDate: String,
    val targetLastDate: String,
    val payrollTimeZone: String,
    val profile: AndroidRuleProfile,
    val work: List<AndroidWorkEntry>,
)

data class AndroidWeeklyReviewSourceSnapshot(
    val startEpochSeconds: Long,
    val timeZone: String,
    val currencyCode: String,
    /** Complete ordered selection of non-overlapping saved period snapshots for this fixed week. */
    val workContainingPeriodIds: List<String>,
    val periods: List<AndroidWeeklySourcePeriodSnapshot>,
)

data class AndroidWeeklyWorkFactSnapshot(
    val id: String,
    val payPeriodId: String?,
    val hours: String? = null,
    val workedSeconds: Long? = null,
    val straightRateAmount: String,
    val straightRateCurrencyCode: String,
    val qualifiesForWeeklyOvertime: Boolean,
)

data class AndroidWeeklyRemunerationFactSnapshot(
    val id: String,
    val amount: String,
    val currencyCode: String,
    val kind: WeeklyRemunerationKind,
    val premiumCredit: WeeklyPremiumCredit,
)

data class AndroidWeeklyReviewInputSnapshot(
    val workweekId: String,
    val startEpochSeconds: Long,
    val timeZone: String,
    val currencyCode: String,
    val boundaryConfirmed: Boolean,
    val singleEmployerConfirmed: Boolean,
    val paymentsConfirmed: Boolean,
    val completeWorkweek: Boolean,
    val applicability: WeeklyOvertimeApplicability,
    val work: List<AndroidWeeklyWorkFactSnapshot>,
    val remuneration: List<AndroidWeeklyRemunerationFactSnapshot>,
    val thresholdHours: String,
    val roundingScale: Int,
    val roundingMode: String,
)

data class AndroidWeeklyMoneySnapshot(val amount: String, val currencyCode: String)

data class AndroidWeeklyPremiumAllocationSnapshot(
    val id: String,
    val payPeriodId: String?,
    val amount: AndroidWeeklyMoneySnapshot,
    val basisNumerator: String,
    val basisDenominator: Long,
)

data class AndroidWeeklyReviewResultSnapshot(
    val engine: String,
    val endEpochSeconds: Long,
    val qualifyingSeconds: String,
    val overtimeSeconds: String,
    val includableRemuneration: AndroidWeeklyMoneySnapshot,
    val regularRate: AndroidWeeklyMoneySnapshot?,
    val statutoryAdditionalPremium: AndroidWeeklyMoneySnapshot,
    val eligibleExtraPremiumCredit: AndroidWeeklyMoneySnapshot,
    val remainingAdditionalPremium: AndroidWeeklyMoneySnapshot,
    val cashRemuneration: AndroidWeeklyMoneySnapshot,
    val expectedCash: AndroidWeeklyMoneySnapshot,
    val allocations: List<AndroidWeeklyPremiumAllocationSnapshot>,
    val explanation: String,
)

/** Append-only weekly-rate receipt. It never mutates a paycheck comparison or its verdict. */
data class AndroidWeeklyReviewReceipt(
    val id: String = UUID.randomUUID().toString(),
    val createdAtEpochSeconds: Long,
    val reference: String = "",
    val source: AndroidWeeklyReviewSourceSnapshot,
    val input: AndroidWeeklyReviewInputSnapshot,
    val result: AndroidWeeklyReviewResultSnapshot,
)

/** User-entered facts for an in-memory preview; previewing does not persist state. */
data class AndroidWeeklyReviewRequest(
    val startLocal: String,
    val timeZone: String,
    val sourcePeriodIds: List<String>,
    val straightTimeWages: String,
    val includableBonus: String = "",
    val excludedCash: String = "",
    val eligibleExtraPremium: String = "",
    val ineligibleExtraPremium: String = "",
    val reference: String = "",
    val boundaryConfirmed: Boolean,
    val singleEmployerConfirmed: Boolean,
    val paymentsConfirmed: Boolean,
    val completeWorkweek: Boolean,
    val applicabilityConfirmed: Boolean,
)

object AndroidWeeklyReviewRepository {
    const val ENGINE = "linepay.android.weekly-regular-rate/3"
    const val WORKWEEK_SECONDS = 604_800L
    private const val MAXIMUM_SOURCE_PERIODS = 32
    private const val MAXIMUM_SOURCE_WORK_ENTRIES = 2_000
    private const val MAXIMUM_REFERENCE_LENGTH = 2_000
    private val calculator = WeeklyRegularRateCalculator()

    fun preview(
        state: AndroidLocalState,
        request: AndroidWeeklyReviewRequest,
        createdAtEpochSeconds: Long,
    ): AndroidWeeklyReviewReceipt {
        require(createdAtEpochSeconds in -62_135_596_800L..253_402_300_799L) {
            "Weekly review date is outside the supported range."
        }
        require(request.reference.length <= MAXIMUM_REFERENCE_LENGTH) {
            "Weekly source note is too long."
        }
        require(request.straightTimeWages.isNotBlank()) {
            "Enter the reviewed straight-time wages for all hours in the week."
        }
        require(request.boundaryConfirmed) { "Confirm the exact 168-hour workweek boundary." }
        require(request.singleEmployerConfirmed) { "Confirm the selected periods belong to one employer." }
        require(request.completeWorkweek) { "Confirm the work and unpaid breaks for the full week." }
        require(request.paymentsConfirmed) { "Confirm each payment and premium-credit classification." }
        require(request.applicabilityConfirmed) {
            "This restricted reference requires separately confirmed covered, nonexempt hourly scope."
        }

        val profile = requireNotNull(state.profile) { "Set up a pay profile first." }
        val zone = ZoneId.of(request.timeZone)
        val start = LinePaycheckRepository.parseUnambiguousInstant(request.startLocal, zone)
        val end = Math.addExact(start, WORKWEEK_SECONDS)
        require(request.timeZone == profile.payrollTimeZone) {
            "Use the payroll time zone saved in the pay profile."
        }
        val currency = profile.currencyCode.uppercase()
        val source = sourceSnapshot(state, request.sourcePeriodIds, start, end, zone, currency)
        val work = workFromSource(source)
        val receiptId = UUID.randomUUID().toString()
        val remuneration = remunerationFacts(request, receiptId, currency)
        val input = AndroidWeeklyReviewInputSnapshot(
            workweekId = UUID.randomUUID().toString(),
            startEpochSeconds = start,
            timeZone = zone.id,
            currencyCode = currency,
            boundaryConfirmed = request.boundaryConfirmed,
            singleEmployerConfirmed = request.singleEmployerConfirmed,
            paymentsConfirmed = request.paymentsConfirmed,
            completeWorkweek = request.completeWorkweek,
            applicability = WeeklyOvertimeApplicability.COVERED_NONEXEMPT_HOURLY,
            work = work.map(::snapshot),
            remuneration = remuneration,
            thresholdHours = "40",
            roundingScale = 2,
            roundingMode = RoundingMode.HALF_UP.name,
        )
        val result = calculator.calculate(input.toDomain())
        val receipt = AndroidWeeklyReviewReceipt(
            id = receiptId,
            createdAtEpochSeconds = createdAtEpochSeconds,
            reference = request.reference.trim(),
            source = source,
            input = input,
            result = result.toSnapshot(),
        )
        validateReceipt(receipt)
        return receipt
    }

    fun append(state: AndroidLocalState, receipt: AndroidWeeklyReviewReceipt): AndroidLocalState {
        validateReceipt(receipt)
        validateCurrentSourceSet(state, receipt)
        val next = state.copy(weeklyReviews = listOf(receipt) + state.weeklyReviews)
        AndroidLocalStateValidator.validate(next)
        return next
    }

    fun deletePaycheckPeriod(state: AndroidLocalState, periodId: String): AndroidLocalState {
        val exists = state.checks.any { it.id == periodId }
        require(exists) { "Saved paycheck period was not found." }
        val next = state.copy(
            checks = state.checks.filterNot { it.id == periodId },
            weeklyReviews = state.weeklyReviews.filterNot { review ->
                review.source.periods.any { it.periodId == periodId }
            },
        )
        AndroidLocalStateValidator.validate(next)
        return next
    }

    fun relatedReviews(state: AndroidLocalState, periodId: String): List<AndroidWeeklyReviewReceipt> =
        state.weeklyReviews.filter { review -> review.source.periods.any { it.periodId == periodId } }

    internal fun sourcePeriodKey(check: AndroidPaycheckSnapshot): Triple<String, String, String> =
        Triple(check.targetStartDate, check.targetLastDate, check.payrollTimeZone)

    fun periodsContainingWorkInWeek(
        state: AndroidLocalState,
        startLocal: String,
        timeZone: String,
    ): List<AndroidPaycheckSnapshot> {
        val zone = ZoneId.of(timeZone)
        val start = LinePaycheckRepository.parseUnambiguousInstant(startLocal, zone)
        val end = Math.addExact(start, WORKWEEK_SECONDS)
        return state.checks.filter { check ->
            periodSnapshot(check, start, end).work.isNotEmpty()
        }.sortedWith(compareBy<AndroidPaycheckSnapshot> { it.targetStartDate }.thenBy { it.id })
    }

    fun validateState(state: AndroidLocalState) {
        require(state.weeklyReviews.map { it.id }.toSet().size == state.weeklyReviews.size) {
            "Weekly review identities must be unique."
        }
        state.weeklyReviews.forEach(::validateReceipt)
    }

    /** Validates a frozen receipt without consulting current paycheck rows or work records. */
    fun validateReceipt(receipt: AndroidWeeklyReviewReceipt) {
        require(runCatching { UUID.fromString(receipt.id) }.isSuccess) {
            "Invalid weekly review identity."
        }
        require(receipt.createdAtEpochSeconds in -62_135_596_800L..253_402_300_799L) {
            "Weekly review date is outside the supported range."
        }
        require(receipt.reference.length <= MAXIMUM_REFERENCE_LENGTH) { "Weekly source note is too long." }
        require(receipt.result.engine == ENGINE) { "Unsupported weekly review engine version." }
        val source = receipt.source
        require(source.periods.isNotEmpty() && source.periods.size <= MAXIMUM_SOURCE_PERIODS) {
            "Weekly review must retain its source periods."
        }
        require(source.periods.map { it.periodId }.toSet().size == source.periods.size) {
            "Weekly review source period identities must be unique."
        }
        require(source.workContainingPeriodIds.isNotEmpty() &&
            source.workContainingPeriodIds.size <= MAXIMUM_SOURCE_PERIODS &&
            source.workContainingPeriodIds.toSet().size == source.workContainingPeriodIds.size) {
            "Weekly review must retain its complete work-containing source period set."
        }
        val zone = ZoneId.of(source.timeZone)
        require(source.currencyCode.matches(Regex("[A-Z]{3}"))) { "Weekly review currency is invalid." }
        val end = Math.addExact(source.startEpochSeconds, WORKWEEK_SECONDS)
        for (period in source.periods) {
            require(runCatching { UUID.fromString(period.periodId) }.isSuccess) {
                "Invalid weekly source period identity."
            }
            AndroidLocalStateValidator.validateProfile(period.profile)
            period.work.forEach(AndroidLocalStateValidator::validateWork)
            require(period.work.isNotEmpty() && period.work.all { overlaps(it, source.startEpochSeconds, end) }) {
                "Weekly source periods must each retain work inside the reviewed week."
            }
        }
        require(source.periods.all { it.profile.currencyCode.equals(source.currencyCode, ignoreCase = true) }) {
            "Weekly source periods use different currencies."
        }
        val orderedPeriods = source.periods.sortedWith(compareBy<AndroidWeeklySourcePeriodSnapshot> {
            periodWindow(it).start
        }.thenBy { it.periodId })
        require(source.periods == orderedPeriods) { "Weekly source periods are not in canonical order." }
        require(source.workContainingPeriodIds == source.periods.map { it.periodId }) {
            "Weekly source snapshots do not match the retained complete source period set."
        }
        val windows = source.periods.map(::periodWindow)
        require(windows.sortedBy { it.start }.zipWithNext().all { (a, b) -> a.end <= b.start }) {
            "Weekly source periods overlap; the source mapping is ambiguous."
        }

        val input = receipt.input
        require(input.workweekId.let { runCatching { UUID.fromString(it) }.isSuccess }) {
            "Invalid weekly workweek identity."
        }
        require(input.startEpochSeconds == source.startEpochSeconds && input.timeZone == zone.id &&
            input.currencyCode == source.currencyCode) {
            "Weekly input does not match its frozen source boundary and currency."
        }
        require(input.boundaryConfirmed && input.singleEmployerConfirmed && input.paymentsConfirmed &&
            input.completeWorkweek && input.applicability == WeeklyOvertimeApplicability.COVERED_NONEXEMPT_HOURLY) {
            "Weekly review is missing a required worker confirmation."
        }
        require(input.thresholdHours == "40" && input.roundingScale == 2 &&
            input.roundingMode == RoundingMode.HALF_UP.name) {
            "Unsupported weekly threshold or rounding configuration."
        }
        require(input.remuneration.all { fact ->
            fact.kind in WeeklyRemunerationKind.entries && fact.premiumCredit in WeeklyPremiumCredit.entries
        }) { "Weekly payment classification is unknown." }
        require(input.remuneration.count { it.kind == WeeklyRemunerationKind.STRAIGHT_TIME } == 1) {
            "Weekly review must retain its reviewed straight-time wage fact."
        }
        require(input.work.size <= 2_000 && input.remuneration.size <= 100) {
            "Weekly review has too many work or payment facts."
        }
        val derivedWork = workFromSource(source).map(::snapshot)
        require(input.work == derivedWork) { "Weekly input work does not match its frozen source periods." }
        val replay = calculator.calculate(input.toDomain())
        require(replay.toSnapshot() == receipt.result) {
            "Saved weekly result does not reproduce from its retained facts."
        }
    }

    private fun sourceSnapshot(
        state: AndroidLocalState,
        selectedIds: List<String>,
        start: Long,
        end: Long,
        zone: ZoneId,
        currency: String,
    ): AndroidWeeklyReviewSourceSnapshot {
        require(selectedIds.isNotEmpty() && selectedIds.size <= MAXIMUM_SOURCE_PERIODS) {
            "Select every saved paycheck period that contains work for this week."
        }
        require(selectedIds.toSet().size == selectedIds.size) { "A source period was selected more than once." }
        val checks = state.checks.associateBy { it.id }
        val eligiblePeriods = state.checks.map { check ->
            periodSnapshot(check, start, end)
        }.filter { it.work.isNotEmpty() }
            .sortedWith(compareBy<AndroidWeeklySourcePeriodSnapshot> { periodWindow(it).start }.thenBy { it.periodId })
        val eligibleById = eligiblePeriods.associateBy { it.periodId }
        val selected = selectedIds.map { id ->
            eligibleById[id] ?: throw IllegalArgumentException("A selected saved paycheck source is unavailable for this week.")
        }
        val groups = eligiblePeriods.groupBy { Triple(it.targetStartDate, it.targetLastDate, it.payrollTimeZone) }
        val selectedGroups = selected.groupBy { Triple(it.targetStartDate, it.targetLastDate, it.payrollTimeZone) }
        require(selectedGroups.keys == groups.keys && selectedGroups.values.all { it.size == 1 }) {
            "Choose exactly one saved check for every distinct period shown. Alternative checks are not additional work periods."
        }
        // Choosing an alternative must never silently discard a distinct retained shift.
        val selectedWorkIds = selected.flatMap { it.work }.map { it.id }.toSet()
        require(eligiblePeriods.flatMap { it.work }.all { it.id in selectedWorkIds }) {
            "The selected checks omit recorded work retained in another source. Choose a complete source snapshot."
        }
        requireCanonicalWorkIsRepresented(state, start, end, selected)
        require(selected.size <= MAXIMUM_SOURCE_PERIODS) {
            "Too many saved paycheck periods contain work in this week."
        }
        val periods = selected.map { snapshot ->
            val check = checks.getValue(snapshot.periodId)
            require(check.profile.currencyCode.equals(currency, ignoreCase = true)) {
                "A source period uses a different currency."
            }
            require(snapshot.work.size <= MAXIMUM_SOURCE_WORK_ENTRIES) {
                "A source period contains too many work entries for a weekly review."
            }
            snapshot
        }.sortedWith(compareBy<AndroidWeeklySourcePeriodSnapshot> { periodWindow(it).start }.thenBy { it.periodId })
        val windows = periods.map(::periodWindow)
        require(windows.zipWithNext().all { (a, b) -> a.end <= b.start }) {
            "Select one saved check for each non-overlapping paycheck period."
        }
        return AndroidWeeklyReviewSourceSnapshot(
            startEpochSeconds = start,
            timeZone = zone.id,
            currencyCode = currency,
            workContainingPeriodIds = periods.map { it.periodId },
            periods = periods,
        )
    }

    /** Append is an admission boundary: reject stale or altered previews against current saved checks. */
    private fun validateCurrentSourceSet(state: AndroidLocalState, receipt: AndroidWeeklyReviewReceipt) {
        val start = receipt.source.startEpochSeconds
        val end = Math.addExact(start, WORKWEEK_SECONDS)
        val current = sourceSnapshot(
            state, receipt.source.workContainingPeriodIds, start, end,
            ZoneId.of(receipt.source.timeZone), receipt.source.currencyCode,
        ).periods
        require(current == receipt.source.periods) {
            "Saved paycheck work or rules changed after preview. Review the complete week again before saving."
        }
    }

    /** Raw work survives check deletion, so every in-week entry must still have a frozen paycheck source. */
    private fun requireCanonicalWorkIsRepresented(
        state: AndroidLocalState,
        start: Long,
        end: Long,
        periods: List<AndroidWeeklySourcePeriodSnapshot>,
    ) {
        val savedWorkById = periods.flatMap { it.work }.groupBy { it.id }
        val unrepresentedWork = state.work.filter { entry ->
            overlaps(entry, start, end) && savedWorkById[entry.id].orEmpty().none { it == entry }
        }
        require(unrepresentedWork.isEmpty()) {
            "Every recorded shift in the reviewed week must belong to a saved paycheck period before weekly review."
        }
    }

    private fun periodSnapshot(
        check: AndroidPaycheckSnapshot,
        weekStart: Long,
        weekEnd: Long,
    ) = AndroidWeeklySourcePeriodSnapshot(
        periodId = check.id,
        targetStartDate = check.targetStartDate,
        targetLastDate = check.targetLastDate,
        payrollTimeZone = check.payrollTimeZone,
        profile = check.profile.copy(),
        work = check.work.filter { overlaps(it, weekStart, weekEnd) }.map { copyWork(it) },
    )

    private data class PeriodWindow(val id: String, val start: Long, val end: Long)

    private fun periodWindow(period: AndroidWeeklySourcePeriodSnapshot): PeriodWindow {
        val zone = ZoneId.of(period.payrollTimeZone)
        val first = LocalDate.parse(period.targetStartDate)
        val last = LocalDate.parse(period.targetLastDate)
        require(last >= first) { "Weekly source period is reversed." }
        val start = first.atStartOfDay(zone).toEpochSecond()
        val end = last.plusDays(1).atStartOfDay(zone).toEpochSecond()
        require(end > start) { "Weekly source period has invalid boundaries." }
        return PeriodWindow(period.periodId, start, end)
    }

    private fun workFromSource(source: AndroidWeeklyReviewSourceSnapshot): List<WeeklyWorkFact> {
        val weekStart = source.startEpochSeconds
        val weekEnd = Math.addExact(weekStart, WORKWEEK_SECONDS)
        val windows = source.periods.associate { it.periodId to periodWindow(it) }
        val entryById = linkedMapOf<String, AndroidWorkEntry>()
        for (period in source.periods) {
            for (entry in period.work) {
                val existing = entryById[entry.id]
                require(existing == null || existing == entry) {
                    "The same work entry changed between saved source periods."
                }
                entryById.putIfAbsent(entry.id, entry)
            }
        }
        val facts = mutableListOf<WeeklyWorkFact>()
        val occupied = mutableListOf<Pair<Long, Long>>()
        for (entry in entryById.values.sortedWith(compareBy<AndroidWorkEntry> { it.startEpochSeconds }.thenBy { it.id })) {
            val start = maxOf(entry.startEpochSeconds, weekStart)
            val end = minOf(entry.endEpochSeconds, weekEnd)
            if (start >= end) continue
            val cuts = sortedSetOf(start, end)
            entry.breaks.forEach { pause ->
                if (pause.startEpochSeconds in (start + 1) until end) cuts += pause.startEpochSeconds
                if (pause.endEpochSeconds in (start + 1) until end) cuts += pause.endEpochSeconds
            }
            windows.values.forEach { window ->
                if (window.start in (start + 1) until end) cuts += window.start
                if (window.end in (start + 1) until end) cuts += window.end
            }
            val orderedCuts = cuts.toList()
            for ((pieceStart, pieceEnd) in orderedCuts.zipWithNext()) {
                if (entry.breaks.any { pieceStart >= it.startEpochSeconds && pieceEnd <= it.endEpochSeconds }) continue
                val period = source.periods.singleOrNull { sourcePeriod ->
                    val window = windows.getValue(sourcePeriod.periodId)
                    pieceStart >= window.start && pieceEnd <= window.end
                } ?: throw IllegalArgumentException("Select source periods that cover every recorded work segment.")
                occupied += pieceStart to pieceEnd
                val factId = UUID.nameUUIDFromBytes(
                    "${period.periodId}:${entry.id}:$pieceStart:$pieceEnd".toByteArray(StandardCharsets.UTF_8),
                )
                facts += WeeklyWorkFact(
                    id = factId,
                    payPeriodId = UUID.fromString(period.periodId),
                    workedSeconds = pieceEnd - pieceStart,
                    straightRate = Money(BigDecimal(period.profile.hourlyRate), period.profile.currencyCode),
                    qualifiesForWeeklyOvertime = true,
                )
            }
        }
        occupied.sortBy { it.first }
        require(occupied.zipWithNext().all { (a, b) -> a.second <= b.first }) {
            "Weekly source periods contain overlapping work entries."
        }
        // Source periods and their work are canonicalized before slicing, so this order is replayable.
        return facts
    }

    private fun remunerationFacts(
        request: AndroidWeeklyReviewRequest,
        receiptId: String,
        currency: String,
    ): List<AndroidWeeklyRemunerationFactSnapshot> {
        val rows = listOf(
            Triple("straight-time", request.straightTimeWages, WeeklyRemunerationKind.STRAIGHT_TIME to WeeklyPremiumCredit.NOT_APPLICABLE),
            Triple("includable-bonus", request.includableBonus, WeeklyRemunerationKind.INCLUDABLE_BONUS to WeeklyPremiumCredit.NOT_APPLICABLE),
            Triple("excluded-cash", request.excludedCash, WeeklyRemunerationKind.EXCLUDED_CASH to WeeklyPremiumCredit.NOT_APPLICABLE),
            Triple("eligible-extra-premium", request.eligibleExtraPremium, WeeklyRemunerationKind.EXTRA_PREMIUM to WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM),
            Triple("ineligible-extra-premium", request.ineligibleExtraPremium, WeeklyRemunerationKind.EXTRA_PREMIUM to WeeklyPremiumCredit.INELIGIBLE),
        )
        return rows.filter { (_, amount, _) -> amount.isNotBlank() }.map { (key, amount, classification) ->
            AndroidWeeklyRemunerationFactSnapshot(
                id = UUID.nameUUIDFromBytes("$receiptId:$key".toByteArray(StandardCharsets.UTF_8)).toString(),
                amount = amount.trim(),
                currencyCode = currency,
                kind = classification.first,
                premiumCredit = classification.second,
            )
        }
    }

    private fun snapshot(fact: WeeklyWorkFact) = AndroidWeeklyWorkFactSnapshot(
        id = fact.id.toString(),
        payPeriodId = fact.payPeriodId?.toString(),
        hours = fact.hours?.toPlainString(),
        workedSeconds = fact.workedSeconds,
        straightRateAmount = fact.straightRate.amount.toPlainString(),
        straightRateCurrencyCode = fact.straightRate.currencyCode,
        qualifiesForWeeklyOvertime = fact.qualifiesForWeeklyOvertime,
    )

    private fun AndroidWeeklyReviewInputSnapshot.toDomain() = WeeklyRegularRateInput(
        workweekId = UUID.fromString(workweekId),
        startEpochSeconds = startEpochSeconds,
        timeZone = ZoneId.of(timeZone),
        currencyCode = currencyCode,
        boundaryConfirmed = boundaryConfirmed,
        singleEmployerConfirmed = singleEmployerConfirmed,
        paymentsConfirmed = paymentsConfirmed,
        completeWorkweek = completeWorkweek,
        applicability = applicability,
        work = work.map { fact ->
            WeeklyWorkFact(
                id = UUID.fromString(fact.id),
                payPeriodId = fact.payPeriodId?.let(UUID::fromString),
                hours = fact.hours?.let(::BigDecimal),
                workedSeconds = fact.workedSeconds,
                straightRate = Money(BigDecimal(fact.straightRateAmount), fact.straightRateCurrencyCode),
                qualifiesForWeeklyOvertime = fact.qualifiesForWeeklyOvertime,
            )
        },
        remuneration = remuneration.map { fact ->
            WeeklyRemunerationFact(
                id = UUID.fromString(fact.id),
                amount = Money(BigDecimal(fact.amount), fact.currencyCode),
                kind = fact.kind,
                premiumCredit = fact.premiumCredit,
            )
        },
        thresholdHours = BigDecimal(thresholdHours),
        rounding = MoneyRounding(
            scale = roundingScale,
            mode = runCatching { RoundingMode.valueOf(roundingMode) }
                .getOrElse { throw InvalidLocalState("Unsupported weekly rounding mode.") },
            scope = RoundingScope.PAY_CATEGORY,
        ),
    )

    private fun WeeklyRegularRateResult.toSnapshot() = AndroidWeeklyReviewResultSnapshot(
        engine = engine,
        endEpochSeconds = endEpochSeconds,
        qualifyingSeconds = qualifyingSeconds.toPlainString(),
        overtimeSeconds = overtimeSeconds.toPlainString(),
        includableRemuneration = includableRemuneration.snapshot(),
        regularRate = regularRate?.snapshot(),
        statutoryAdditionalPremium = statutoryAdditionalPremium.snapshot(),
        eligibleExtraPremiumCredit = eligibleExtraPremiumCredit.snapshot(),
        remainingAdditionalPremium = remainingAdditionalPremium.snapshot(),
        cashRemuneration = cashRemuneration.snapshot(),
        expectedCash = expectedCash.snapshot(),
        allocations = allocations.map { it.snapshot() },
        explanation = explanation,
    )

    private fun Money.snapshot() = AndroidWeeklyMoneySnapshot(amount.toPlainString(), currencyCode)

    private fun WeeklyPremiumAllocation.snapshot() = AndroidWeeklyPremiumAllocationSnapshot(
        id = id.toString(),
        payPeriodId = payPeriodId?.toString(),
        amount = amount.snapshot(),
        basisNumerator = basisNumerator.toPlainString(),
        basisDenominator = basisDenominator,
    )

    private fun copyWork(entry: AndroidWorkEntry) = entry.copy(breaks = entry.breaks.map { it.copy() })

    private fun overlaps(entry: AndroidWorkEntry, start: Long, end: Long) =
        entry.endEpochSeconds > start && entry.startEpochSeconds < end
}
