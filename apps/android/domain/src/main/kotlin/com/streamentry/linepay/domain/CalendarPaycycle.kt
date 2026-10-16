package com.streamentry.linepay.domain

import java.time.LocalDate
import java.time.ZoneId

enum class CalendarPaycycleCadence { WEEKLY, BIWEEKLY, SEMIMONTHLY, MANUAL }

@ConsistentCopyVisibility
data class CalendarPaycycleWindow internal constructor(
    val cadence: CalendarPaycycleCadence,
    val startDate: LocalDate,
    val lastDate: LocalDate,
    val endExclusiveDate: LocalDate,
    val timeZone: ZoneId,
    val startEpochSeconds: Long,
    val endEpochSeconds: Long,
) {
    val elapsedSeconds: Long get() = endEpochSeconds - startEpochSeconds
}

/** Explicit local-calendar boundaries, never an inferred statutory overtime workweek.
 * Dates advance before zone resolution so a skipped midnight cannot shift the next boundary.
 */
object CalendarPaycycle {
    fun window(
        cadence: CalendarPaycycleCadence,
        startDate: LocalDate,
        manualEndDate: LocalDate? = null,
        timeZone: ZoneId,
    ): CalendarPaycycleWindow {
        require(startDate.year in 1..9999) { "Unsupported calendar year" }
        fun firstInstant(date: LocalDate): Long {
            val boundary = date.atStartOfDay(timeZone)
            require(boundary.toLocalDate() == date) { "Local calendar date does not exist" }
            return boundary.toEpochSecond()
        }
        val endExclusive = when (cadence) {
            CalendarPaycycleCadence.WEEKLY -> startDate.plusDays(7)
            CalendarPaycycleCadence.BIWEEKLY -> startDate.plusDays(14)
            CalendarPaycycleCadence.SEMIMONTHLY -> {
                require(startDate.dayOfMonth == 1 || startDate.dayOfMonth == 16) {
                    "Twice-monthly cycles start on the 1st or 16th"
                }
                if (startDate.dayOfMonth == 1) startDate.withDayOfMonth(16)
                else startDate.withDayOfMonth(1).plusMonths(1)
            }
            CalendarPaycycleCadence.MANUAL -> {
                require(manualEndDate != null && manualEndDate >= startDate) {
                    "Confirm both custom dates in order"
                }
                firstInstant(manualEndDate)
                manualEndDate.plusDays(1)
            }
        }
        require(endExclusive.year in 1..9999) { "Unsupported calendar year" }
        val start = firstInstant(startDate)
        val end = firstInstant(endExclusive)
        require(end > start) { "Invalid paycycle boundaries" }
        return CalendarPaycycleWindow(
            cadence, startDate, endExclusive.minusDays(1), endExclusive, timeZone, start, end,
        )
    }
}
