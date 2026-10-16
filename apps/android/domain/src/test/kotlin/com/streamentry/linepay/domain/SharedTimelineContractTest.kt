package com.streamentry.linepay.domain

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class SharedTimelineContractTest(private val name: String,private val sample: JsonObject,private val refused: Boolean) {
 companion object {
  @JvmStatic @Parameterized.Parameters(name="{0}") fun fixtures(): Collection<Array<Any>> {
   val root=JsonParser.parseString(File(System.getProperty("linepay.sharedContracts"),"payroll/effective-date-v1.json").readText()).asJsonObject
   check(root["format"].asString=="com.streamentry.linepay.effective-pay-fixtures"&&root["version"].asInt==1)
   check(root["cases"].asJsonArray.size()==8&&root["refusals"].asJsonArray.size()==5)
   return root["cases"].asJsonArray.map {arrayOf(it.asJsonObject["id"].asString,it.asJsonObject,false)}+root["refusals"].asJsonArray.map {arrayOf(it.asJsonObject["id"].asString,it.asJsonObject,true)}
  }
 }
 private fun decimal(r: JsonObject,k: String)=BigDecimal(r[k].asString)
 private fun agreement(r: JsonObject): Agreement {
  check(r["regularSchedule"].asJsonArray.size()==0&&r["datePremiums"].asJsonArray.size()==0&&r["outsideScheduleMultiplier"].asString=="1")
  val currency=r["currency"].asString;val rounding=r["rounding"].asJsonObject
  val mode=when(rounding["mode"].asString){"halfUp"->RoundingMode.HALF_UP;"bankers"->RoundingMode.HALF_EVEN;"down"->RoundingMode.FLOOR;"up"->RoundingMode.CEILING;else->error("Unknown rounding")}
  return Agreement(r["id"].asString,r["version"].asString,Money(decimal(r,"hourlyRate"),currency),dailyTiers=r["dailyOvertimeTiers"].asJsonArray.map {DailyTier(decimal(it.asJsonObject,"afterHours"),decimal(it.asJsonObject,"multiplier"))},weekdayPremiums=r["weekdayPremiums"].asJsonArray.map {WeekdayPremium(DayOfWeek.valueOf(it.asJsonObject["weekday"].asString.uppercase()),decimal(it.asJsonObject,"multiplier"))},calloutMinimumHours=r["calloutMinimumHours"].takeUnless {it.isJsonNull}?.asString?.let(::BigDecimal),perDiemPerWorkDate=r["perDiemPerWorkDate"].takeUnless {it.isJsonNull}?.asString?.let {Money(BigDecimal(it),currency)},rounding=MoneyRounding(rounding["scale"].asInt,mode,RoundingScope.PAY_CATEGORY))
 }
 private fun calculate(): CalculationResult {
  val zone=ZoneId.of(sample["timeZone"].asString)
  val work=sample["work"].asJsonArray.map {raw->val w=raw.asJsonObject;WorkInterval(UUID.fromString(w["id"].asString),Instant.parse(w["startUTC"].asString).epochSecond,Instant.parse(w["endUTC"].asString).epochSecond,zone,WorkKind.valueOf(w["kind"].asString.uppercase()),w["unpaidBreaks"].asJsonArray.map {val b=it.asJsonObject;WorkBreak(UUID.fromString(b["id"].asString),Instant.parse(b["startUTC"].asString).epochSecond,Instant.parse(b["endUTC"].asString).epochSecond)},w["calloutEventID"].takeUnless {it.isJsonNull}?.asString?.let(UUID::fromString))}
  return ConfiguredPayCalculator().calculate(work,agreement(sample["baseline"].asJsonObject),sample["changes"].asJsonArray.map {AgreementChange(LocalDate.parse(it.asJsonObject["effectiveDate"].asString),agreement(it.asJsonObject["agreement"].asJsonObject))})
 }
 @Test fun independentTemporalArithmeticAndRefusal() {
  if(refused){assertThrows(name,IllegalArgumentException::class.java){calculate()};return}
  val result=calculate();val expected=sample["expected"].asJsonObject
  for((key,value) in listOf("wages" to result.expectedWages.amount,"allowances" to result.expectedAllowances.amount,"total" to result.total.amount))assertEquals(name,0,decimal(expected,key).compareTo(value))
  val seconds=result.components.filter {it.category==ComponentCategory.WORKED_HOURS}.fold(BigDecimal.ZERO){n,p->n+requireNotNull(p.seconds)}
  assertEquals(name,0,decimal(expected,"workedSeconds").compareTo(seconds))
  assertEquals(name,expected["appliedVersions"].asJsonArray.map {it.asString}.toSet(),result.components.map {it.reference.version}.toSet())
  assertTrue(result.components.all {it.reference.id==sample["baseline"].asJsonObject["id"].asString&&it.explanation.isNotBlank()})
 }
}
