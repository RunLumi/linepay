package com.streamentry.linepay.domain

import java.math.BigDecimal
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import org.junit.Assert.*
import org.junit.Test

class BenefitBoundaryTest {
    private val fund=UUID.fromString("30000000-0000-0000-0000-000000000001")
    private val period=ContributionPeriod(LocalDate.of(2026,10,1),LocalDate.of(2026,11,1),ZoneId.of("America/Chicago"))
    private fun rule(id: UUID=UUID.fromString("30000000-0000-0000-0000-000000000010"),
        basis: ContributionBasis=ContributionBasis.ELIGIBLE_HOUR, rate: String="8.75",
        scope: ContributionPeriod=period)=ContributionRule(id,fund,"1",basis,BigDecimal(rate),"USD",scope)
    private fun segment(id: Int=1,scope: ContributionPeriod=period,rule: ContributionRule=rule(),
        confirmed: Boolean=true,quantity: String="40")=EligibilitySegment(
            UUID.fromString("30000000-0000-0000-0000-${id.toString().padStart(12,'0')}"),scope,rule,BigDecimal(quantity),confirmed)
    private fun rejected(reason: ContributionReviewError.Reason,segments: List<EligibilitySegment>,complete: Boolean=true) {
        val error=assertThrows(ContributionReviewError::class.java) {
            BenefitContributionCalculator().calculate(period,segments,complete,null,MoneyRounding())
        }
        assertEquals(reason,error.reason)
    }
    @Test fun incompleteAndUnconfirmedEligibilityCannotBecomeAnExpectation() {
        rejected(ContributionReviewError.Reason.INCOMPLETE_COVERAGE,listOf(segment()),complete=false)
        rejected(ContributionReviewError.Reason.UNCONFIRMED_ELIGIBILITY,listOf(segment(confirmed=false)))
    }
    @Test fun overlapAndDuplicateIdentityAreRefused() {
        rejected(ContributionReviewError.Reason.OVERLAPPING_SEGMENTS,listOf(segment(),segment()))
        rejected(ContributionReviewError.Reason.OVERLAPPING_SEGMENTS,listOf(segment(1),segment(2)))
    }
    @Test fun sameRuleIdentityCannotHideAChangedVersionedDefinition() {
        val middle=LocalDate.of(2026,10,16)
        val first=ContributionPeriod(period.start,middle,period.zone)
        val second=ContributionPeriod(middle,period.endExclusive,period.zone)
        rejected(ContributionReviewError.Reason.INCONSISTENT_RULE,
            listOf(segment(1,first,rule(rate="8.75")),segment(2,second,rule(rate="9.00"))))
    }
    @Test fun fixedPeriodCannotBeProratedOrReusedForAnotherScope() {
        rejected(ContributionReviewError.Reason.INVALID_QUANTITY,
            listOf(segment(rule=rule(basis=ContributionBasis.FIXED_PERIOD,rate="120"),quantity="2")))
        val narrower=ContributionPeriod(period.start,LocalDate.of(2026,10,16),period.zone)
        rejected(ContributionReviewError.Reason.INVALID_QUANTITY,
            listOf(segment(scope=narrower,rule=rule(basis=ContributionBasis.FIXED_PERIOD,rate="120"),quantity="1")))
    }
    @Test fun invalidStatementShapeIsNotConvertedToZeroOrComparable() {
        val statement=ContributionStatement(fund,"USD",period,Money(BigDecimal(-1),"USD"),confirmed=true)
        val error=assertThrows(ContributionReviewError::class.java) {
            BenefitContributionCalculator().calculate(period,listOf(segment()),true,statement,MoneyRounding())
        }
        assertEquals(ContributionReviewError.Reason.INVALID_STATEMENT,error.reason)
    }
    @Test fun timezoneMismatchDoesNotBecomeAPossibleDebt() {
        val statement=ContributionStatement(fund,"USD",
            ContributionPeriod(period.start,period.endExclusive,ZoneId.of("UTC")),Money(BigDecimal(350),"USD"),confirmed=true)
        val result=BenefitContributionCalculator().calculate(period,listOf(segment()),true,statement,MoneyRounding())
        assertEquals(ContributionStatus.NOT_COMPARABLE,result.status)
        assertNull(result.paid)
        assertNull(result.difference)
        assertEquals(0,BigDecimal(350).compareTo(result.expected.amount))
    }
}
