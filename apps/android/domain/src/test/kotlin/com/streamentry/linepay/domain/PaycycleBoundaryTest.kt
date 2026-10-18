package com.streamentry.linepay.domain

import java.time.LocalDate
import java.time.ZoneId
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class PaycycleBoundaryTest {
    @Test fun explicitZoneDoesNotReadTheDeviceDefault() {
        val original = TimeZone.getDefault()
        try {
            fun calculate() = CalendarPaycycle.window(
                CalendarPaycycleCadence.WEEKLY, LocalDate.of(2026, 3, 2),
                timeZone = ZoneId.of("America/Los_Angeles"),
            )
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Tokyo"))
            val tokyo = calculate()
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            assertEquals(tokyo, calculate())
            assertEquals(167L * 3600L, tokyo.elapsedSeconds)
        } finally {
            TimeZone.setDefault(original)
        }
    }

    @Test fun invalidMissingOrOutOfRangeManualDatesRefuse() {
        val start = LocalDate.of(2026, 10, 5)
        val zone = ZoneId.of("UTC")
        assertThrows(IllegalArgumentException::class.java) {
            CalendarPaycycle.window(CalendarPaycycleCadence.MANUAL, start, timeZone = zone)
        }
        assertThrows(IllegalArgumentException::class.java) {
            CalendarPaycycle.window(CalendarPaycycleCadence.WEEKLY, LocalDate.of(9999, 12, 31), timeZone = zone)
        }
        assertThrows(IllegalArgumentException::class.java) {
            CalendarPaycycle.window(CalendarPaycycleCadence.MANUAL, start, LocalDate.of(10000, 1, 1), zone)
        }
    }

    @Test fun whollySkippedBoundaryDatesCannotBeSilentlyMovedToAnotherDate() {
        val zone = ZoneId.of("Pacific/Apia")
        assertThrows(IllegalArgumentException::class.java) {
            CalendarPaycycle.window(CalendarPaycycleCadence.WEEKLY, LocalDate.of(2011, 12, 30), timeZone = zone)
        }
        assertThrows(IllegalArgumentException::class.java) {
            CalendarPaycycle.window(
                CalendarPaycycleCadence.MANUAL, LocalDate.of(2011, 12, 28), LocalDate.of(2011, 12, 29), zone,
            )
        }
    }
}
