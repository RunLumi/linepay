package com.streamentry.linepay.android

import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

enum class PayCycleChoice {
    WEEKLY,
    BIWEEKLY,
    SEMIMONTHLY,
    CUSTOM,
}

enum class GrossBasisChoice {
    WAGES_ONLY,
    WAGES_AND_PER_DIEM,
}

data class AndroidRuleProfile(
    val id: String = UUID.randomUUID().toString(),
    val version: String = "1",
    val hourlyRate: String,
    val currencyCode: String = "USD",
    val cadence: PayCycleChoice = PayCycleChoice.WEEKLY,
    val cycleStartDate: String,
    val customLastDate: String? = null,
    val payrollTimeZone: String,
    val dailyOvertimeAfterHours: String? = "8",
    val dailyOvertimeMultiplier: String = "1.5",
    val outsideScheduleMultiplier: String = "1",
    val perDiemPerWorkDate: String? = null,
    val rulesReviewedByWorker: Boolean = false,
    val hasIndependentEffectiveDates: Boolean = false,
    val effectiveStartDate: String? = null,
    val effectiveEndDateInclusive: String? = null,
    val requiresPortableRuleConfirmation: Boolean = false,
    val importedSourceProfileRef: String? = null,
    val calculationRuleID: String? = null,
    val useAsFutureDefault: Boolean = false,
    val portableRuleFieldsNeedingConfirmation: List<String>? = null,
)

data class AndroidWorkBreak(
    val id: String = UUID.randomUUID().toString(),
    val startEpochSeconds: Long,
    val endEpochSeconds: Long,
)

data class AndroidWorkEntry(
    val id: String = UUID.randomUUID().toString(),
    val startEpochSeconds: Long,
    val endEpochSeconds: Long,
    val timeZone: String,
    val breaks: List<AndroidWorkBreak> = emptyList(),
    val note: String = "",
)

data class AndroidPayComponentSnapshot(
    val category: String,
    val date: String,
    val amount: String,
    val currencyCode: String,
    val multiplier: String? = null,
    val seconds: String? = null,
    val agreementId: String,
    val agreementVersion: String,
    val explanation: String,
    val ruleKeys: List<String> = emptyList(),
    val id: String? = null,
    val workId: String? = null,
)

data class AndroidLineComparisonSnapshot(
    val field: String,
    val expected: String,
    val paid: String,
    val difference: String,
    val unit: String,
    val currencyCode: String,
    val componentIds: List<String> = emptyList(),
)

/** A saved check is a receipt. It keeps its original work, confirmed rules, statement and verdict. */
data class AndroidPaycheckSnapshot(
    val id: String = UUID.randomUUID().toString(),
    val createdAtEpochSeconds: Long,
    val profile: AndroidRuleProfile,
    val work: List<AndroidWorkEntry>,
    val targetStartDate: String,
    val targetLastDate: String,
    val payrollTimeZone: String,
    val sourceStartDate: String?,
    val sourceLastDate: String?,
    val sourceTimeZone: String?,
    val sourcePeriodConfirmed: Boolean,
    val paidGross: String,
    val grossBasis: GrossBasisChoice,
    val completeWorkConfirmed: Boolean,
    val ruleCoverageConfirmed: Boolean,
    val expectedGross: String?,
    val difference: String?,
    val verdict: String,
    val periodMatch: String,
    val reviewReasons: List<String>,
    val comparisons: List<AndroidLineComparisonSnapshot>,
    val components: List<AndroidPayComponentSnapshot>,
    val engine: String,
    val coverage: String,
)

data class AndroidLocalState(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val profile: AndroidRuleProfile? = null,
    val work: List<AndroidWorkEntry> = emptyList(),
    val checks: List<AndroidPaycheckSnapshot> = emptyList(),
    val weeklyReviews: List<AndroidWeeklyReviewReceipt> = emptyList(),
    val benefitReviews: List<AndroidBenefitReceipt> = emptyList(),
    val portableArchive: AndroidPortableArchive? = null,
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION = 5
        const val MAXIMUM_WORK_ENTRIES = 10_000
        const val MAXIMUM_SAVED_CHECKS = 2_000
        const val MAXIMUM_WEEKLY_REVIEWS = 128

        fun empty() = AndroidLocalState()
    }
}

class InvalidLocalState(message: String) : IllegalArgumentException(message)

/** Versioned boundary for local files and manually exported backups. */
object AndroidLocalStateValidator {
    fun validate(state: AndroidLocalState): AndroidLocalState {
        require(state.schemaVersion == AndroidLocalState.CURRENT_SCHEMA_VERSION) {
            "This backup uses an unsupported LinePaycheck state version."
        }
        require(state.work.size <= AndroidLocalState.MAXIMUM_WORK_ENTRIES) {
            "This file has too many work entries."
        }
        require(state.checks.size <= AndroidLocalState.MAXIMUM_SAVED_CHECKS) {
            "This file has too many saved checks."
        }
        require(state.weeklyReviews.size <= AndroidLocalState.MAXIMUM_WEEKLY_REVIEWS) {
            "This file has too many weekly review records."
        }
        require(state.work.map { it.id }.toSet().size == state.work.size) {
            "Work entry identities must be unique."
        }
        require(state.checks.map { it.id }.toSet().size == state.checks.size) {
            "Saved check identities must be unique."
        }
        state.profile?.let(::validateProfile)
        state.work.forEach(::validateWork)
        state.checks.forEach(::validateCheck)
        AndroidWeeklyReviewRepository.validateState(state)
        AndroidBenefitRepository.validateState(state)
        state.portableArchive?.let(AndroidPortableStateCodec::validateArchive)
        AndroidPortableStateCodec.validateCurrentSourceProfile(state)
        return state
    }

    fun validateProfile(profile: AndroidRuleProfile): AndroidRuleProfile {
        require(runCatching { UUID.fromString(profile.id) }.isSuccess) { "Invalid rule identity." }
        require(profile.version.isNotBlank() && profile.version.length <= 128) {
            "Invalid rule version."
        }
        profile.calculationRuleID?.let { require(it.isNotBlank() && it.length <= 128) { "Invalid calculation rule identity." } }
        require(profile.portableRuleFieldsNeedingConfirmation.orEmpty().size <= 64 && profile.portableRuleFieldsNeedingConfirmation.orEmpty().all { it.length in 1..100 }) { "Invalid imported-rule confirmation context." }
        profile.effectiveStartDate?.let { require(LocalDate.parse(it).year in 1..9999) { "Invalid rule effective start." } }
        profile.effectiveEndDateInclusive?.let { require(LocalDate.parse(it).year in 1..9999) { "Invalid rule effective end." } }
        require(profile.effectiveStartDate == null || profile.effectiveEndDateInclusive == null || LocalDate.parse(profile.effectiveEndDateInclusive) >= LocalDate.parse(profile.effectiveStartDate)) { "Rule effective dates are reversed." }
        require(profile.hasIndependentEffectiveDates || (profile.effectiveStartDate == null && profile.effectiveEndDateInclusive == null)) { "Independent rule dates require an explicit date model." }
        requireDecimal(profile.hourlyRate, minimum = BigDecimal.ZERO, maximum = BigDecimal("1000000"))
        require(profile.currencyCode.matches(Regex("[A-Za-z]{3}"))) { "Currency must be explicit." }
        require(runCatching { LocalDate.parse(profile.cycleStartDate) }.isSuccess) {
            "Pay period start must be an ISO local date."
        }
        require(runCatching { ZoneId.of(profile.payrollTimeZone) }.isSuccess) {
            "Choose a valid payroll time zone."
        }
        when (profile.cadence) {
            PayCycleChoice.CUSTOM -> {
                val last = requireNotNull(profile.customLastDate) { "Custom periods need an end date." }
                require(LocalDate.parse(last) >= LocalDate.parse(profile.cycleStartDate)) {
                    "Custom period end must be on or after its start."
                }
            }
            PayCycleChoice.SEMIMONTHLY -> require(
                LocalDate.parse(profile.cycleStartDate).dayOfMonth in setOf(1, 16)
            ) { "Semi-monthly periods start on the 1st or 16th." }
            PayCycleChoice.WEEKLY, PayCycleChoice.BIWEEKLY -> Unit
        }
        profile.dailyOvertimeAfterHours?.let {
            requireDecimal(it, minimum = BigDecimal.ZERO, maximum = BigDecimal("24"))
        }
        requireDecimal(profile.dailyOvertimeMultiplier, minimum = BigDecimal.ONE, maximum = BigDecimal("10"))
        requireDecimal(profile.outsideScheduleMultiplier, minimum = BigDecimal.ONE, maximum = BigDecimal("10"))
        profile.perDiemPerWorkDate?.let {
            requireDecimal(it, minimum = BigDecimal.ZERO, maximum = BigDecimal("1000000"))
        }
        return profile
    }

    fun validateWork(entry: AndroidWorkEntry): AndroidWorkEntry {
        require(runCatching { UUID.fromString(entry.id) }.isSuccess) { "Invalid work identity." }
        require(entry.endEpochSeconds > entry.startEpochSeconds) { "Work end must follow its start." }
        require(runCatching { ZoneId.of(entry.timeZone) }.isSuccess) { "Invalid work time zone." }
        require(entry.note.length <= 4000) { "Work notes are too long." }
        require(entry.breaks.map { it.id }.toSet().size == entry.breaks.size) {
            "Break identities must be unique."
        }
        require(entry.breaks.all {
            it.endEpochSeconds > it.startEpochSeconds &&
                it.startEpochSeconds >= entry.startEpochSeconds &&
                it.endEpochSeconds <= entry.endEpochSeconds
        }) { "A break must be inside the recorded shift." }
        require(entry.breaks.sortedBy { it.startEpochSeconds }.zipWithNext().all { (a, b) ->
            a.endEpochSeconds <= b.startEpochSeconds
        }) { "Recorded breaks cannot overlap." }
        return entry
    }

    private fun validateCheck(check: AndroidPaycheckSnapshot) {
        check.components.forEach { component ->
            component.id?.let { require(UUID.fromString(it).toString() == it) { "Invalid saved component identity." } }
            component.workId?.let { require(check.work.any { work -> work.id == it }) { "Saved component references unknown work." } }
        }
        val componentIDs = check.components.mapNotNull { it.id }
        require(componentIDs.toSet().size == componentIDs.size) { "Saved component identities must be unique." }
        require(runCatching { UUID.fromString(check.id) }.isSuccess) { "Invalid saved-check identity." }
        validateProfile(check.profile)
        check.work.forEach(::validateWork)
        val start = LocalDate.parse(check.targetStartDate)
        val last = LocalDate.parse(check.targetLastDate)
        require(last >= start) { "Saved check has a reversed period." }
        require(runCatching { ZoneId.of(check.payrollTimeZone) }.isSuccess) {
            "Saved check has an invalid payroll time zone."
        }
        if (check.sourceStartDate != null || check.sourceLastDate != null) {
            require(check.sourceStartDate != null && check.sourceLastDate != null) {
                "Source period needs both dates."
            }
            require(LocalDate.parse(check.sourceLastDate) >= LocalDate.parse(check.sourceStartDate)) {
                "Saved source period is reversed."
            }
            require(!check.sourcePeriodConfirmed || check.sourceTimeZone != null) {
                "A confirmed source period needs a time zone."
            }
            check.sourceTimeZone?.let { zone ->
                require(runCatching { ZoneId.of(zone) }.isSuccess) {
                    "Saved source time zone is invalid."
                }
            }
        }
        require(
            check.verdict in setOf(
                "MATCHES", "POSSIBLE_SHORTFALL", "POSSIBLE_OVERPAYMENT", "NEEDS_REVIEW",
                "NOT_COMPARABLE",
            )
        ) { "Saved check verdict is invalid." }
        require(check.verdict != "MATCHES") {
            "Android paycheck receipts cannot clear weekly-rate review without a source-approved mapping."
        }
        if (check.expectedGross != null) {
            require("WEEKLY_REVIEW_PENDING" in check.reviewReasons && check.verdict == "NEEDS_REVIEW") {
                "Comparable paycheck receipts must retain the unresolved weekly-rate review."
            }
        }
        requireDecimal(check.paidGross, minimum = BigDecimal.ZERO, maximum = BigDecimal("1000000000000"))
        check.expectedGross?.let {
            requireDecimal(it, minimum = BigDecimal.ZERO, maximum = BigDecimal("1000000000000"))
        }
        check.difference?.let {
            requireDecimal(it, minimum = BigDecimal("-1000000000000"), maximum = BigDecimal("1000000000000"))
        }
    }

    private fun requireDecimal(value: String, minimum: BigDecimal, maximum: BigDecimal) {
        val parsed = try {
            BigDecimal(value)
        } catch (_: NumberFormatException) {
            throw InvalidLocalState("Enter a complete decimal amount.")
        }
        require(parsed >= minimum && parsed <= maximum) { "Amount is outside the supported range." }
        require(parsed.precision() <= 38 && parsed.scale() in -12..12) {
            "Amount precision is outside the supported range."
        }
    }
}
