package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test

class PayBoundaryTest {
    private val start = Instant.parse("2026-10-16T07:00:00Z").epochSecond
    private fun work(offset: Long, seconds: Long, kind: WorkKind = WorkKind.REGULAR, event: UUID? = null) =
        WorkInterval(UUID.nameUUIDFromBytes("$offset/$seconds/$kind/$event".toByteArray()),start+offset,start+offset+seconds,ZoneId.of("UTC"),kind,calloutEventId=event)
    private fun rules(rounding: MoneyRounding = MoneyRounding()) = Agreement("synthetic","1",Money(BigDecimal("19.99"),"USD"),rounding=rounding)

    @Test fun exactCategoryRoundingConservesAcrossPartitionsForEveryMode() {
        for (mode in listOf(RoundingMode.HALF_UP,RoundingMode.HALF_EVEN,RoundingMode.FLOOR,RoundingMode.CEILING)) {
            val rule = rules(MoneyRounding(2,mode))
            val whole = ConfiguredPayCalculator().calculate(listOf(work(0,1800)),rule)
            val parts = ConfiguredPayCalculator().calculate(listOf(work(0,1),work(1,1799)),rule)
            val expected = BigDecimal("19.99").divide(BigDecimal(2),2,mode)
            assertEquals(0,expected.compareTo(whole.total.amount))
            assertEquals(whole.total,parts.total)
            assertEquals(parts.total.amount,parts.components.fold(ZERO) { sum,part -> sum + part.amount.amount }.stripTrailingZeros())
        }
    }
    @Test fun duplicateAndOverlappingFactsAreRefused() {
        val shift=work(0,3600)
        assertThrows(IllegalArgumentException::class.java) { ConfiguredPayCalculator().calculate(listOf(shift,shift),rules()) }
        assertThrows(IllegalArgumentException::class.java) { ConfiguredPayCalculator().calculate(listOf(shift,work(1800,3600)),rules()) }
    }
    @Test fun calloutIdentityAndNonAdjacentGroupingNeedReview() {
        val rule=Agreement("synthetic","1",Money(BigDecimal(50),"USD"),calloutMinimumHours=BigDecimal(4))
        val absent=assertThrows(PayReviewRequired::class.java) { ConfiguredPayCalculator().calculate(listOf(work(0,3600,WorkKind.CALLOUT)),rule) }
        assertEquals(PayReviewRequired.Reason.CALLOUT_IDENTITY,absent.reason)
        val id=UUID.fromString("10000000-0000-0000-0000-000000000001")
        val gap=assertThrows(PayReviewRequired::class.java) { ConfiguredPayCalculator().calculate(listOf(work(0,3600,WorkKind.CALLOUT,id),work(7200,3600,WorkKind.CALLOUT,id)),rule) }
        assertEquals(PayReviewRequired.Reason.CALLOUT_INTERACTION,gap.reason)
    }
    @Test fun ruleInputsAreCopiedAndMoneyCurrencyCannotBeMixed() {
        val tiers=mutableListOf(DailyTier(BigDecimal(8),BigDecimal("1.5")))
        val rule=Agreement("synthetic","1",Money(BigDecimal(50),"usd"),dailyTiers=tiers)
        tiers.clear()
        assertEquals(1,rule.dailyTiers.size)
        assertEquals(Money(BigDecimal("1.00"),"USD"),Money(BigDecimal.ONE,"usd"))
        assertThrows(IllegalArgumentException::class.java) { Money(ONE,"USD") + Money(ONE,"CAD") }
        assertThrows(IllegalArgumentException::class.java) { Money(ONE,"ßD") }
    }
    @Test fun effectiveDateTransitionUsesEachImmutableRate() {
        val a=Agreement("synthetic","a",Money(BigDecimal(50),"USD"))
        val b=Agreement("synthetic","b",Money(BigDecimal(60),"USD"))
        val overnight=WorkInterval(UUID.fromString("10000000-0000-0000-0000-000000000002"),
            Instant.parse("2026-10-16T23:00:00Z").epochSecond,Instant.parse("2026-10-17T01:00:00Z").epochSecond,ZoneId.of("UTC"))
        val result=ConfiguredPayCalculator().calculate(listOf(overnight),a,listOf(AgreementChange(LocalDate.of(2026,10,17),b)))
        assertEquals(0,BigDecimal(110).compareTo(result.total.amount))
        assertEquals(setOf("a","b"),result.components.map { it.reference.version }.toSet())
    }
    @Test fun scheduleDateAndWeekdayPremiaUseHighestExplicitMultiplier() {
        val agreement=Agreement("synthetic","1",Money(BigDecimal(50),"USD"),
            schedule=listOf(ScheduleWindow(DayOfWeek.FRIDAY,LocalTime.of(7,0),LocalTime.of(15,0))),
            outsideScheduleMultiplier=BigDecimal("1.5"),weekdayPremiums=listOf(WeekdayPremium(DayOfWeek.FRIDAY,BigDecimal(2))),
            datePremiums=listOf(DatePremium(LocalDate.of(2026,10,16),BigDecimal(3))))
        val result=ConfiguredPayCalculator().calculate(listOf(work(0,36000)),agreement)
        assertEquals(0,BigDecimal(1500).compareTo(result.total.amount))
        assertTrue(result.components.all { it.ruleKeys.toSet() == setOf("base","date") })
    }
    @Test fun splittingAnOrdinaryShiftDoesNotResetTheDailyTier() {
        val rule=Agreement("synthetic","1",Money(BigDecimal(50),"USD"),
            dailyTiers=listOf(DailyTier(BigDecimal(8),BigDecimal("1.5"))))
        val result=ConfiguredPayCalculator().calculate(listOf(work(0,18000),work(18000,18000)),rule)
        assertEquals(0,BigDecimal(550).compareTo(result.total.amount))
    }
    @Test fun regularWorkInsideACalloutGuaranteeRequiresReview() {
        val rule=Agreement("synthetic","1",Money(BigDecimal(50),"USD"),calloutMinimumHours=BigDecimal(4))
        val event=UUID.fromString("10000000-0000-0000-0000-000000000003")
        val failure=assertThrows(PayReviewRequired::class.java) {
            ConfiguredPayCalculator().calculate(listOf(work(0,3600,WorkKind.CALLOUT,event),work(3600,3600)),rule)
        }
        assertEquals(PayReviewRequired.Reason.CALLOUT_INTERACTION,failure.reason)
    }
    @Test fun ambiguousScheduleWallClockFailsClosedWithoutChangingActualInstants() {
        val rule=Agreement("synthetic","1",Money(BigDecimal(50),"USD"),schedule=listOf(
            ScheduleWindow(DayOfWeek.SUNDAY,LocalTime.of(2,30),LocalTime.of(4,0))))
        val entry=WorkInterval(UUID.fromString("10000000-0000-0000-0000-000000000004"),
            Instant.parse("2026-03-08T06:00:00Z").epochSecond,Instant.parse("2026-03-08T09:00:00Z").epochSecond,
            ZoneId.of("America/New_York"))
        val failure=assertThrows(PayReviewRequired::class.java) { ConfiguredPayCalculator().calculate(listOf(entry),rule) }
        assertEquals(PayReviewRequired.Reason.SCHEDULE_CLOCK_AMBIGUITY,failure.reason)
        assertEquals(10800,entry.workedSeconds)
    }

}
