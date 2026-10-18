package com.streamentry.linepay.domain

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedPayrollContractTest(private val name: String, private val sample: JsonObject) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name="{0}")
        fun fixtures(): Collection<Array<Any>> {
            val root = File(System.getProperty("linepay.sharedContracts"), "payroll/configured-pay-v1.json")
            val corpus = JsonParser.parseString(root.readText()).asJsonObject
            check(corpus["format"].asString == "com.streamentry.linepay.configured-pay-fixtures")
            check(corpus["version"].asInt == 1 && corpus["premiumCombination"].asString == "highestApplicable")
            val cases = corpus["cases"].asJsonArray
            check(cases.size() == 19)
            check(cases.map { it.asJsonObject["id"].asString }.toSet().size == cases.size())
            return cases.map { arrayOf(it.asJsonObject["id"].asString, it.asJsonObject) }
        }
    }
    @Test fun matchesIndependentMoneyTimeAndSnapshotReferences() {
        val source = sample["agreement"].asJsonObject
        check(source["regularSchedule"].asJsonArray.size() == 0 && source["datePremiums"].asJsonArray.size() == 0)
        val currency = source["currency"].asString
        val rounding = source["rounding"].asJsonObject
        val mode = when(rounding["mode"].asString) {
            "halfUp" -> RoundingMode.HALF_UP
            "bankers" -> RoundingMode.HALF_EVEN
            "down" -> RoundingMode.FLOOR
            "up" -> RoundingMode.CEILING
            else -> error("Unsupported rounding mode")
        }
        val scope = when(rounding["scope"].asString) {
            "payCategory" -> RoundingScope.PAY_CATEGORY
            "legacySegments" -> RoundingScope.LEGACY_SEGMENTS
            else -> error("Unsupported rounding scope")
        }
        val agreement = Agreement(source["id"].asString, source["version"].asString,
            Money(decimal(source,"hourlyRate"), currency),
            outsideScheduleMultiplier = decimal(source,"outsideScheduleMultiplier"),
            dailyTiers = source["dailyOvertimeTiers"].asJsonArray.map {
                DailyTier(decimal(it.asJsonObject,"afterHours"), decimal(it.asJsonObject,"multiplier"))
            }, weekdayPremiums = source["weekdayPremiums"].asJsonArray.map {
                WeekdayPremium(DayOfWeek.valueOf(it.asJsonObject["weekday"].asString.uppercase()), decimal(it.asJsonObject,"multiplier"))
            }, calloutMinimumHours = source["calloutMinimumHours"].takeUnless { it.isJsonNull }?.asString?.let(::BigDecimal),
            perDiemPerWorkDate = source["perDiemPerWorkDate"].takeUnless { it.isJsonNull }?.asString?.let { Money(BigDecimal(it),currency) },
            rounding = MoneyRounding(rounding["scale"].asInt,mode,scope))
        val zone = ZoneId.of(sample["timeZone"].asString)
        val work = sample["work"].asJsonArray.map { raw ->
            val item = raw.asJsonObject
            WorkInterval(UUID.fromString(item["id"].asString), epoch(item["startUTC"].asString), epoch(item["endUTC"].asString),
                zone, WorkKind.valueOf(item["kind"].asString.uppercase()), item["unpaidBreaks"].asJsonArray.map {
                    val pause = it.asJsonObject
                    WorkBreak(UUID.fromString(pause["id"].asString),epoch(pause["startUTC"].asString),epoch(pause["endUTC"].asString))
                }, item["calloutEventID"].takeUnless { it.isJsonNull }?.asString?.let(UUID::fromString))
        }
        val actual = ConfiguredPayCalculator().calculate(work,agreement)
        val expected = sample["expected"].asJsonObject
        assertEquals(name,expected["currency"].asString,actual.currency)
        same(expected["wages"].asString,actual.expectedWages.amount)
        same(expected["allowances"].asString,actual.expectedAllowances.amount)
        same((decimal(expected,"wages") + decimal(expected,"allowances")).toPlainString(),actual.total.amount)
        val worked = actual.components.filter { it.category == ComponentCategory.WORKED_HOURS }
        same(expected["workedAmount"].asString,worked.fold(ZERO) { total, part -> total + part.amount.amount })
        same(expected["calloutGuarantee"].asString,actual.components.filter { it.category == ComponentCategory.CALLOUT_GUARANTEE }.fold(ZERO) { total, part -> total + part.amount.amount })
        same(expected["actualWorkedSeconds"].asString,worked.fold(ZERO) { total, part -> total + requireNotNull(part.seconds) })
        assertEquals(name,expected["multipliers"].asJsonArray.map { BigDecimal(it.asString).stripTrailingZeros() }.toSet(),worked.map { requireNotNull(it.multiplier).stripTrailingZeros() }.toSet())
        assertEquals(name,expected["workDates"].asJsonArray.map { it.asString }.toSet(),worked.map { it.date.toString() }.toSet())
        assertEquals(name,work.map { it.id }.toSet(),worked.map { it.workId }.toSet())
        val reference = expected["reference"].asJsonObject
        assertTrue(name,actual.components.all { it.reference.id == reference["id"].asString && it.reference.version == reference["version"].asString && it.explanation.isNotBlank() && it.ruleKeys.isNotEmpty() })
    }
    private fun same(expected: String, actual: BigDecimal) = assertEquals("$name expected $expected actual $actual",0,BigDecimal(expected).compareTo(actual))
    private fun decimal(value: JsonObject,key: String): BigDecimal {
        val text = value[key].asString
        check(text.matches(Regex("\\d+(\\.\\d+)?")))
        return BigDecimal(text)
    }
    private fun epoch(value: String): Long { check(value.endsWith("Z")); return Instant.parse(value).epochSecond }
}
