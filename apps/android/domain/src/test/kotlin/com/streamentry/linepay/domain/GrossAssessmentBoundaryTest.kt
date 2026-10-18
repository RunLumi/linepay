package com.streamentry.linepay.domain

import java.math.BigDecimal
import org.junit.Assert.*
import org.junit.Test

class GrossAssessmentBoundaryTest {
    private fun facts(gross: Money=Money(BigDecimal(400),"USD"),allowance: Money?=null)=GrossPaycheckFacts(
        gross,true,GrossBasis.WAGES_ONLY,false,false,false,allowance)
    @Test fun negativeEvidenceIsRejectedEvenWithoutAnExpectedCalculation() {
        for (input in listOf(facts(gross=Money(BigDecimal(-1),"USD")),facts(allowance=Money(BigDecimal(-1),"USD")))) {
            assertThrows(IllegalArgumentException::class.java) {
                GrossPaycheckAssessor().assess(null,"USD",input,MoneyRounding())
            }
        }
    }
    @Test fun currenciesCannotBeMixedOrConvertedImplicitly() {
        for (input in listOf(facts(gross=Money(BigDecimal(400),"CAD")),facts(allowance=Money(BigDecimal(100),"CAD")))) {
            assertThrows(IllegalArgumentException::class.java) {
                GrossPaycheckAssessor().assess(null,"USD",input,MoneyRounding())
            }
        }
        assertThrows(IllegalArgumentException::class.java) {
            GrossPaycheckAssessor().assess(CalculationResult(emptyList(),"CAD"),"USD",facts(),MoneyRounding())
        }
    }
    @Test fun retainedAssessmentsDefensivelyCopyEvidenceAndReasons() {
        val source=mutableListOf<GrossComparison>()
        val reasons=mutableListOf(GrossReviewReason.INCOMPLETE_WORK)
        val result=GrossPaycheckAssessment(null,facts().paidGross,null,GrossVerdict.NOT_COMPARABLE,source,reasons)
        reasons.clear()
        assertEquals(listOf(GrossReviewReason.INCOMPLETE_WORK),result.reviewReasons)
        assertThrows(UnsupportedOperationException::class.java) { (result.reviewReasons as MutableList).clear() }
        assertThrows(UnsupportedOperationException::class.java) { (result.comparisons as MutableList).clear() }
    }
}
