package com.streamentry.linepay.domain

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedWeeklyReferenceTest(
    private val name: String,
    private val sample: JsonObject,
    private val refused: Boolean,
) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0}")
        fun fixtures(): Collection<Array<Any>> {
            val rows = fixturesFor("reference-v2.json", 2, 7, 10) + fixturesFor("reference-v3.json", 3, 5, 5)
            check(rows.map { it[0] }.toSet().size == rows.size)
            return rows
        }

        private fun fixturesFor(path: String, version: Int, caseCount: Int, refusalCount: Int): Collection<Array<Any>> {
            val file = File(System.getProperty("linepay.sharedContracts"), "weekly/$path")
            val root = JsonParser.parseString(file.readText()).asJsonObject
            check(root["format"].asString == "com.streamentry.linepay.weekly-reference-fixtures")
            check(root["version"].asInt == version)
            val cases = root["cases"].asJsonArray
            val refusals = root["refusals"].asJsonArray
            check(cases.size() == caseCount && refusals.size() == refusalCount)
            check((cases + refusals).map { it.asJsonObject["id"].asString }.toSet().size == caseCount + refusalCount)
            return cases.map { arrayOf(it.asJsonObject["id"].asString, it.asJsonObject, false) } +
                refusals.map { arrayOf(it.asJsonObject["id"].asString, it.asJsonObject, true) }
        }
    }

    @Test fun confirmedReferencesMatchIndependentAmountsAndUnknownInputsRefuse() {
        if (refused) {
            assertThrows("$name must refuse", IllegalArgumentException::class.java) { calculate() }
            return
        }
        val result = calculate()
        val expected = sample["expected"].asJsonObject
        same(expected["qualifyingSeconds"].asString, result.qualifyingSeconds)
        same(expected["overtimeSeconds"].asString, result.overtimeSeconds)
        same(expected["regularRate"].asString, requireNotNull(result.regularRate).amount)
        for ((actual, field) in listOf(
            result.statutoryAdditionalPremium to "statutoryAdditionalPremium",
            result.eligibleExtraPremiumCredit to "eligibleExtraPremiumCredit",
            result.remainingAdditionalPremium to "remainingAdditionalPremium",
            result.cashRemuneration to "cashRemuneration",
            result.expectedCash to "expectedCash",
        )) {
            same(expected[field].asString, actual.amount)
            assertEquals(name, result.input.currencyCode, actual.currencyCode)
        }
        assertEquals(name, expected["allocationAmounts"].asJsonArray.map { BigDecimal(it.asString).stripTrailingZeros() },
            result.allocations.map { it.amount.amount })
        same(result.remainingAdditionalPremium.amount.toPlainString(), result.allocations.fold(ZERO) { sum, item -> sum + item.amount.amount })
        assertEquals("linepay.android.weekly-regular-rate/3", result.engine)
        assertEquals(604800L, result.endEpochSeconds - result.input.startEpochSeconds)
        assertTrue(result.explanation.isNotBlank())
    }

    private fun calculate(): WeeklyRegularRateResult {
        val input = sample["input"].asJsonObject
        val rounding = input["rounding"].asJsonObject
        return WeeklyRegularRateCalculator().calculate(WeeklyRegularRateInput(
            workweekId = UUID.fromString("61000000-0000-0000-0000-000000000099"),
            startEpochSeconds = Instant.parse(input["startUTC"].asString).epochSecond,
            timeZone = ZoneId.of(input["timeZone"].asString),
            currencyCode = input["currency"].asString,
            boundaryConfirmed = input["boundaryConfirmed"].asBoolean,
            singleEmployerConfirmed = input["singleEmployerConfirmed"].asBoolean,
            paymentsConfirmed = input["paymentsConfirmed"].asBoolean,
            completeWorkweek = input["completeWorkweek"].asBoolean,
            applicability = when (input["applicability"].asString) {
                "coveredNonexemptHourly" -> WeeklyOvertimeApplicability.COVERED_NONEXEMPT_HOURLY
                "unknown" -> WeeklyOvertimeApplicability.UNKNOWN
                else -> error("Unsupported fixture applicability")
            },
            work = input["work"].asJsonArray.map { raw ->
                val item = raw.asJsonObject
                WeeklyWorkFact(
                    id = UUID.fromString(item["id"].asString),
                    payPeriodId = item["payPeriodID"].takeUnless { it.isJsonNull }?.asString?.let(UUID::fromString),
                    hours = item["hours"].takeUnless { it.isJsonNull }?.asString?.let(::BigDecimal),
                    workedSeconds = item["workedSeconds"].takeUnless { it.isJsonNull }?.asLong,
                    straightRate = money(item["straightRate"].asJsonObject),
                    qualifiesForWeeklyOvertime = item["qualifies"].asBoolean,
                )
            },
            remuneration = input["remuneration"].asJsonArray.map { raw ->
                val item = raw.asJsonObject
                WeeklyRemunerationFact(
                    UUID.fromString(item["id"].asString), money(item["amount"].asJsonObject),
                    when (item["kind"].asString) {
                        "straightTime" -> WeeklyRemunerationKind.STRAIGHT_TIME
                        "includableBonus" -> WeeklyRemunerationKind.INCLUDABLE_BONUS
                        "excludedCash" -> WeeklyRemunerationKind.EXCLUDED_CASH
                        "extraPremium" -> WeeklyRemunerationKind.EXTRA_PREMIUM
                        else -> error("Unsupported fixture remuneration")
                    },
                    when (item["premiumCredit"].asString) {
                        "notApplicable" -> WeeklyPremiumCredit.NOT_APPLICABLE
                        "eligibleExtraPremium" -> WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM
                        "ineligible" -> WeeklyPremiumCredit.INELIGIBLE
                        "unknown" -> WeeklyPremiumCredit.UNKNOWN
                        else -> error("Unsupported fixture premium classification")
                    },
                )
            },
            rounding = MoneyRounding(rounding["scale"].asInt, when (rounding["mode"].asString) {
                "halfUp" -> RoundingMode.HALF_UP
                "bankers" -> RoundingMode.HALF_EVEN
                "down" -> RoundingMode.FLOOR
                "up" -> RoundingMode.CEILING
                else -> error("Unsupported fixture rounding")
            }, when (rounding["scope"].asString) {
                "payCategory" -> RoundingScope.PAY_CATEGORY
                "legacySegments" -> RoundingScope.LEGACY_SEGMENTS
                else -> error("Unsupported fixture rounding scope")
            }),
        ))
    }

    private fun money(source: JsonObject) = Money(BigDecimal(source["amount"].asString), source["currency"].asString)
    private fun same(expected: String, actual: BigDecimal) =
        assertEquals("$name expected $expected actual $actual", 0, BigDecimal(expected).compareTo(actual))
}
