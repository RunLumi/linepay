package com.streamentry.linepay.domain

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedLineAssessmentTest(private val name: String, private val sample: JsonObject) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name="{0}")
        fun cases(): Collection<Array<Any>> {
            val root=JsonParser.parseString(File(System.getProperty("linepay.sharedContracts"),"reconciliation/configured-lines-v1.json").readText()).asJsonObject
            check(root["format"].asString=="com.streamentry.linepay.configured-line-fixtures" && root["version"].asInt==1)
            val cases=root["cases"].asJsonArray;check(cases.size()==29)
            check(cases.map { it.asJsonObject["id"].asString }.toSet().size==29)
            return cases.map { arrayOf(it.asJsonObject["id"].asString,it.asJsonObject) }
        }
        internal fun enumName(value: String): String = value.replace(Regex("([a-z])([A-Z])"),"$1_$2").uppercase(Locale.ROOT)
        internal fun number(value: JsonElement): BigDecimal {
            require(value.isJsonPrimitive && value.asJsonPrimitive.isString)
            return BigDecimal(value.asString)
        }
        internal fun rule(input: JsonObject): Agreement {
            require(listOf("regularSchedule","weekdayPremiums","datePremiums").all { input[it].asJsonArray.size()==0 })
            val currency=input["currency"].asString;val rounding=input["rounding"].asJsonObject
            val mode=when(rounding["mode"].asString) {
                "halfUp"->RoundingMode.HALF_UP;"bankers"->RoundingMode.HALF_EVEN
                "up"->RoundingMode.CEILING;"down"->RoundingMode.FLOOR;else->error("Unsupported mode") }
            return Agreement(input["id"].asString,input["version"].asString,Money(number(input["hourlyRate"]),currency),
                outsideScheduleMultiplier=number(input["outsideScheduleMultiplier"]),
                dailyTiers=input["dailyOvertimeTiers"].asJsonArray.map { DailyTier(number(it.asJsonObject["afterHours"]),number(it.asJsonObject["multiplier"])) },
                calloutMinimumHours=input["calloutMinimumHours"].takeUnless { it.isJsonNull }?.let(::number),
                perDiemPerWorkDate=input["perDiemPerWorkDate"].takeUnless { it.isJsonNull }?.let { Money(number(it),currency) },
                rounding=MoneyRounding(rounding["scale"].asInt,mode,RoundingScope.valueOf(enumName(rounding["scope"].asString))))
        }
    }
    @Test fun matchesIndependentLineMoneyHoursAndSourceComponents() {
        val baseline=rule(sample["agreement"].asJsonObject);val currency=baseline.hourlyRate.currencyCode
        val changes=sample["changes"].asJsonArray.map { raw -> val row=raw.asJsonObject
            AgreementChange(LocalDate.parse(row["effectiveDate"].asString),rule(row["agreement"].asJsonObject)) }
        val work=sample["work"].asJsonArray.map { raw -> val row=raw.asJsonObject
            WorkInterval(UUID.fromString(row["id"].asString),Instant.parse(row["startUTC"].asString).epochSecond,
                Instant.parse(row["endUTC"].asString).epochSecond,ZoneId.of(row["timeZone"].asString),
                WorkKind.valueOf(enumName(row["kind"].asString)),row["unpaidBreaks"].asJsonArray.map { item ->val pause=item.asJsonObject
                    WorkBreak(UUID.fromString(pause["id"].asString),Instant.parse(pause["startUTC"].asString).epochSecond,Instant.parse(pause["endUTC"].asString).epochSecond) },
                row["calloutEventID"].takeUnless { it.isJsonNull }?.asString?.let(UUID::fromString)) }
        val calculation=ConfiguredPayCalculator().calculate(work,baseline,changes)
        val raw=sample["facts"].asJsonObject;val lines=sample["lines"].asJsonObject
        val gross=GrossPaycheckFacts(Money(number(raw["paidGross"]),currency),raw["completeWork"].asBoolean,
            GrossBasis.valueOf(enumName(raw["grossBasis"].asString)),raw["unreviewedFields"].asBoolean,raw["unsupportedRules"].asBoolean,
            raw["weeklyReviewPending"].asBoolean,raw["paidPerDiem"].takeUnless { it.isJsonNull }?.let { Money(number(it),currency) })
        val facts=PaycheckLineFacts(gross,EarningsLayout.valueOf(enumName(lines["layout"].asString)),
            PaycheckHoursBasis.valueOf(enumName(lines["hoursBasis"].asString)),GuaranteeLayout.valueOf(enumName(lines["guaranteeLayout"].asString)),
            lines["amounts"].asJsonObject.entrySet().associate { PaycheckLineField.valueOf(enumName(it.key)) to Money(number(it.value),currency) },
            lines["hours"].asJsonObject.entrySet().associate { PaycheckLineField.valueOf(enumName(it.key)) to number(it.value) },lines["completeEarnings"].asBoolean)
        val target=CalendarPaycycle.window(CalendarPaycycleCadence.MANUAL,LocalDate.of(2026,9,7),LocalDate.of(2026,9,8),ZoneId.of("UTC"))
        val result=LinePaycheckAssessor().assess(calculation,baseline,facts,target,
            PaycheckSourcePeriod(target.startDate,target.lastDate,target.timeZone,true),listOf(baseline)+changes.map { it.agreement })
        val expected=sample["expected"].asJsonObject
        assertEquals(name,GrossVerdict.valueOf(enumName(expected["verdict"].asString)),result.verdict)
        assertEquals(0,number(expected["gross"]).compareTo(result.expectedGross!!.amount))
        assertEquals(0,number(expected["difference"]).compareTo(result.difference!!.amount))
        val rows=expected["comparisons"].asJsonArray;assertEquals(name,rows.size(),result.comparisons.size)
        for ((index,item) in rows.withIndex()) {
            val row=item.asJsonObject;val actual=result.comparisons[index]
            assertEquals(PaycheckLineField.valueOf(enumName(row["field"].asString)),actual.field)
            assertEquals(PaycheckUnit.valueOf(enumName(row["unit"].asString)),actual.unit)
            assertEquals(name+" expected "+actual.field,0,number(row["expected"]).compareTo(actual.expected))
            assertEquals(name+" paid",0,number(row["paid"]).compareTo(actual.paid))
            assertEquals(name+" difference",0,number(row["difference"]).compareTo(actual.difference))
            val wages=calculation.components.filter { it.category!=ComponentCategory.PER_DIEM }
            val included=wages.filter { it.category==ComponentCategory.WORKED_HOURS || facts.guaranteeLayout==GuaranteeLayout.INCLUDED_IN_HOURLY_LINES }
            val hourParts=if(facts.hoursBasis==PaycheckHoursBasis.ACTUAL_WORK) wages.filter { it.category==ComponentCategory.WORKED_HOURS } else included
            val hourly=if(actual.unit==PaycheckUnit.HOURS) hourParts else included
            val selected=when(val source=row["source"].asString) {
                "allCash"->calculation.components;"allWages"->wages;"allowance"->calculation.components.filter { it.category==ComponentCategory.PER_DIEM }
                "guarantees"->wages.filter { it.category==ComponentCategory.CALLOUT_GUARANTEE };"allHourly"->included;"allWorked"->hourParts
                else->{val multiplier=mapOf("regular" to ONE,"overtime" to BigDecimal("1.5"),"doubleTime" to BigDecimal(2)).getValue(source)
                    hourly.filter { (it.multiplier?:ONE).compareTo(multiplier)==0 }} }
            assertEquals(name+" source trace",selected.map { it.id },actual.componentIds)
        }
        if(result.verdict==GrossVerdict.NEEDS_REVIEW)assertTrue(result.reviewReasons.isNotEmpty())
        assertEquals("linepay.android.configured-lines/1",result.engine)
        assertEquals(CalculationCoverage.CONFIGURED_RULES_ONLY,result.coverage)
    }
}
