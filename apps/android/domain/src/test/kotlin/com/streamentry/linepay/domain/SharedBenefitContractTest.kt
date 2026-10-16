package com.streamentry.linepay.domain

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedBenefitContractTest(private val name: String,private val sample: JsonObject) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name="{0}")
        fun fixtures(): Collection<Array<Any>> {
            val root=JsonParser.parseString(File(System.getProperty("linepay.sharedContracts"),"benefits/confirmed-fund-v1.json").readText()).asJsonObject
            check(root["format"].asString=="com.streamentry.linepay.confirmed-benefit-fixtures" && root["version"].asInt==1)
            val cases=root["cases"].asJsonArray;check(cases.size()==13)
            return cases.map { arrayOf(it.asJsonObject["id"].asString,it.asJsonObject) }
        }
    }
    @Test fun sameFundNumbersScopeAndRawPrecisionMatchIndependentValues() {
        val segments=sample["segments"].asJsonArray.map { element ->
            val item=element.asJsonObject;val rule=item["rule"].asJsonObject
            EligibilitySegment(UUID.fromString(item["id"].asString),period(item["period"].asJsonObject),
                ContributionRule(UUID.fromString(rule["id"].asString),UUID.fromString(rule["fundID"].asString),rule["version"].asString,
                    basis(rule["basis"].asString),BigDecimal(rule["rate"].asString),rule["currency"].asString,period(rule["effectivePeriod"].asJsonObject)),
                BigDecimal(item["quantity"].asString),item["eligibilityConfirmed"].asBoolean)
        }
        val statement=sample["statement"].takeUnless { it.isJsonNull }?.asJsonObject?.let {
            val currency=it["currency"].asString
            ContributionStatement(UUID.fromString(it["fundID"].asString),currency,period(it["period"].asJsonObject),
                text(it["employerContribution"])?.let { value -> Money(BigDecimal(value),currency) },
                text(it["quantity"])?.let(::BigDecimal),text(it["quantityBasis"])?.let(::basis),it["confirmed"].asBoolean)
        }
        val actual=BenefitContributionCalculator().calculate(period(sample["period"].asJsonObject),segments,
            sample["completeEligibilityConfirmed"].asBoolean,statement,MoneyRounding())
        val expected=sample["expected"].asJsonObject
        same(text(expected["amount"]),actual.expected.amount)
        assertEquals(name,expected["currency"].asString,actual.expected.currencyCode)
        same(text(expected["paid"]),actual.paid?.amount)
        same(text(expected["difference"]),actual.difference?.amount)
        same(text(expected["eligibleQuantity"]),actual.eligibleQuantity)
        same(text(expected["quantityDifference"]),actual.quantityDifference)
        assertEquals(name,text(expected["quantityBasis"])?.let(::basis),actual.basis)
        val status=mapOf("notVerified" to ContributionStatus.NOT_VERIFIED,"notComparable" to ContributionStatus.NOT_COMPARABLE,
            "comparedValuesMatch" to ContributionStatus.COMPARED_VALUES_MATCH,"possibleDifference" to ContributionStatus.POSSIBLE_DIFFERENCE)
        assertEquals(name,status[expected["status"].asString],actual.status)
        assertEquals(name,expected["components"].asJsonArray.size(),actual.components.size)
        expected["components"].asJsonArray.forEachIndexed { i,value -> same(value.asString,actual.components[i].unroundedContribution.amount) }
        assertEquals(name,segments.map { it.id }.toSet(),actual.segments.map { it.id }.toSet())
        assertEquals(name,segments.map { it.rule.id to it.rule.version }.toSet(),actual.segments.map { it.rule.id to it.rule.version }.toSet())
    }
    private fun period(value: JsonObject)=ContributionPeriod(LocalDate.parse(value["start"].asString),LocalDate.parse(value["endExclusive"].asString),ZoneId.of(value["timeZone"].asString))
    private fun text(value: JsonElement): String?=if(value.isJsonNull)null else value.asString
    private fun basis(value: String)=when(value) {
        "eligibleHour" -> ContributionBasis.ELIGIBLE_HOUR
        "eligibleDay" -> ContributionBasis.ELIGIBLE_DAY
        "percentOfEligibleEarnings" -> ContributionBasis.PERCENT_OF_ELIGIBLE_EARNINGS
        "fixedPeriod" -> ContributionBasis.FIXED_PERIOD
        else -> error("Unknown contribution basis")
    }
    private fun same(expected: String?,actual: BigDecimal?) {
        if(expected==null)assertNull(name,actual) else { assertNotNull(name,actual);assertEquals(name,0,BigDecimal(expected).compareTo(actual)) }
    }
}
