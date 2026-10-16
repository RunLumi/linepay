package com.streamentry.linepay.domain

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedGrossAssessmentTest(private val name: String, private val corpus: JsonObject, private val sample: JsonObject) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name="{0}")
        fun fixtures(): Collection<Array<Any>> {
            val file=File(System.getProperty("linepay.sharedContracts"),"reconciliation/configured-gross-v1.json")
            val root=JsonParser.parseString(file.readText()).asJsonObject
            check(root["format"].asString == "com.streamentry.linepay.configured-gross-fixtures" && root["version"].asInt == 1)
            val cases=root["cases"].asJsonArray
            check(cases.size() == 16 && cases.map { it.asJsonObject["id"].asString }.toSet().size == cases.size())
            return cases.map { arrayOf(it.asJsonObject["id"].asString,root,it.asJsonObject) }
        }
    }
    @Test fun confirmedGrossComparisonKeepsItsScopeAndEvidence() {
        val currency=corpus["currency"].asString
        val scope=when(sample["roundingScope"].asString) {
            "payCategory" -> RoundingScope.PAY_CATEGORY
            "legacySegments" -> RoundingScope.LEGACY_SEGMENTS
            else -> error("Unknown scope")
        }
        val rounding=MoneyRounding(scope=scope)
        val rule=Agreement("synthetic-gross","1",Money(BigDecimal(corpus["hourlyRate"].asString),currency),
            perDiemPerWorkDate=sample["perDiemPerWorkDate"].takeUnless { it.isJsonNull }?.asString?.let { Money(BigDecimal(it),currency) },rounding=rounding)
        val source=corpus["work"].asJsonObject
        val work=WorkInterval(UUID.fromString(source["id"].asString),Instant.parse(source["startUTC"].asString).epochSecond,
            Instant.parse(sample["workEndUTC"].asString).epochSecond,ZoneId.of(source["timeZone"].asString))
        val calculation=if (sample["hasCalculation"].asBoolean) ConfiguredPayCalculator().calculate(listOf(work),rule) else null
        val facts=sample["facts"].asJsonObject
        val basis=when(facts["grossBasis"].asString) {
            "wagesOnly" -> GrossBasis.WAGES_ONLY
            "wagesAndPerDiem" -> GrossBasis.WAGES_AND_PER_DIEM
            "unconfirmed" -> GrossBasis.UNCONFIRMED
            else -> error("Unknown gross basis")
        }
        val result=GrossPaycheckAssessor().assess(calculation,currency,GrossPaycheckFacts(
            Money(BigDecimal(facts["paidGross"].asString),currency),facts["completeWork"].asBoolean,basis,
            facts["unreviewedFields"].asBoolean,facts["unsupportedRules"].asBoolean,facts["weeklyReviewPending"].asBoolean,
            facts["paidPerDiem"].takeUnless { it.isJsonNull }?.asString?.let { Money(BigDecimal(it),currency) }),rounding)
        val expected=sample["expected"].asJsonObject
        val verdict=when(expected["verdict"].asString) {
            "matches" -> GrossVerdict.MATCHES
            "possibleShortfall" -> GrossVerdict.POSSIBLE_SHORTFALL
            "possibleOverpayment" -> GrossVerdict.POSSIBLE_OVERPAYMENT
            "needsReview" -> GrossVerdict.NEEDS_REVIEW
            "notComparable" -> GrossVerdict.NOT_COMPARABLE
            else -> error("Unknown verdict")
        }
        assertEquals(verdict,result.verdict)
        amount(expected,"gross",result.expectedGross)
        amount(expected,"difference",result.difference)
        assertEquals(Money(BigDecimal(facts["paidGross"].asString),currency),result.paidGross)
        val comparisons=expected["comparisons"].asJsonArray
        assertEquals(comparisons.size(),result.comparisons.size)
        for ((index,item) in comparisons.withIndex()) {
            val row=item.asJsonObject
            val actual=result.comparisons[index]
            assertEquals(if (row["field"].asString == "grossPay") GrossComparisonField.GROSS_PAY else GrossComparisonField.PER_DIEM_PAY,actual.field)
            amount(row,"expected",actual.expected);amount(row,"paid",actual.paid);amount(row,"difference",actual.difference)
            val selected=calculation!!.components.filter {
                if (actual.field == GrossComparisonField.PER_DIEM_PAY) it.category == ComponentCategory.PER_DIEM
                else basis == GrossBasis.WAGES_AND_PER_DIEM || it.category != ComponentCategory.PER_DIEM
            }
            assertEquals(selected.map { it.id },actual.componentIds)
        }
        if (result.verdict == GrossVerdict.NEEDS_REVIEW || result.verdict == GrossVerdict.NOT_COMPARABLE) assertTrue(result.reviewReasons.isNotEmpty())
        else assertTrue(result.reviewReasons.isEmpty())
    }
    private fun amount(row: JsonObject,key: String,actual: Money?) {
        if (row[key].isJsonNull) assertNull(actual)
        else { assertNotNull(actual); assertEquals(name,0,BigDecimal(row[key].asString).compareTo(actual!!.amount)) }
    }
}
