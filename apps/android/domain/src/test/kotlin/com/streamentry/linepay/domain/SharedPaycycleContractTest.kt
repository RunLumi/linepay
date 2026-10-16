package com.streamentry.linepay.domain

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedPaycycleContractTest(
    private val name: String,
    private val sample: JsonObject,
    private val refused: Boolean,
) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0}")
        fun fixtures(): Collection<Array<Any>> {
            val file = File(System.getProperty("linepay.sharedContracts"), "paycycles/calendar-v1.json")
            val root = JsonParser.parseString(file.readText()).asJsonObject
            check(root["format"].asString == "com.streamentry.linepay.calendar-paycycle-fixtures")
            check(root["version"].asInt == 1)
            val cases = root["cases"].asJsonArray
            val refusals = root["refusals"].asJsonArray
            check(cases.size() == 15 && refusals.size() == 10)
            check((cases + refusals).map { it.asJsonObject["id"].asString }.toSet().size == 25)
            return cases.map { arrayOf(it.asJsonObject["id"].asString, it.asJsonObject, false) } +
                refusals.map { arrayOf(it.asJsonObject["id"].asString, it.asJsonObject, true) }
        }
    }

    private fun window(): CalendarPaycycleWindow {
        val input = sample["input"].asJsonObject
        val cadence = when (input["cadence"].asString) {
            "weekly" -> CalendarPaycycleCadence.WEEKLY
            "biweekly" -> CalendarPaycycleCadence.BIWEEKLY
            "semimonthly" -> CalendarPaycycleCadence.SEMIMONTHLY
            "manual" -> CalendarPaycycleCadence.MANUAL
            else -> error("Unknown fixture cadence")
        }
        return CalendarPaycycle.window(
            cadence, LocalDate.parse(input["startDate"].asString),
            LocalDate.parse(input["manualEndDate"].asString), ZoneId.of(input["timeZone"].asString),
        )
    }

    @Test fun explicitCalendarDatesAndInstantsMatchIndependentExpectations() {
        if (refused) {
            try {
                window()
                fail("$name must refuse")
            } catch (_: IllegalArgumentException) {
                // Valid inputs violating the confirmed cadence/custom boundary contract.
            } catch (_: DateTimeException) {
                // Invalid Gregorian date or unknown timezone is refused at input admission.
            }
            return
        }
        val result = window()
        val expected = sample["expected"].asJsonObject
        assertEquals(name, expected["startDate"].asString, result.startDate.toString())
        assertEquals(name, expected["endDate"].asString, result.lastDate.toString())
        assertEquals(name, expected["endExclusiveDate"].asString, result.endExclusiveDate.toString())
        assertEquals(name, Instant.parse(expected["startUTC"].asString).epochSecond, result.startEpochSeconds)
        assertEquals(name, Instant.parse(expected["endExclusiveUTC"].asString).epochSecond, result.endEpochSeconds)
        assertEquals(name, expected["elapsedSeconds"].asLong, result.elapsedSeconds)
        assertEquals(sample["input"].asJsonObject["timeZone"].asString, result.timeZone.id)
    }
}
