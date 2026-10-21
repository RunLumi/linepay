package com.streamentry.linepay.android

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import java.time.Instant
import java.time.ZoneId

@Composable
fun WeeklyReviewReceiptDetailScreen(receipt: AndroidWeeklyReviewReceipt) {
    val zone = ZoneId.of(receipt.source.timeZone)
    val start = Instant.ofEpochSecond(receipt.source.startEpochSeconds).atZone(zone)
    val end = Instant.ofEpochSecond(receipt.result.endEpochSeconds).atZone(zone)
    val regularRate = receipt.result.regularRate?.let {
        formatMoney(it.amount, it.currencyCode)
    } ?: "Unavailable"

    PageContent {
        Text(
            "Weekly review receipt",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.testTag("weekly-receipt.detail-title"),
        )
        Text("Saved separately from paycheck comparisons")

        SectionHeading("Reviewed workweek")
        Text("${start.toLocalDateTime()} – ${end.toLocalDateTime()} · ${zone.id}")
        Text("168 elapsed hours · ${receipt.source.workContainingPeriodIds.size} saved source periods")

        SectionHeading("Frozen paycheck sources")
        receipt.source.periods.forEach { period ->
            Text(
                "${period.targetStartDate} – ${period.targetLastDate} · rule ${period.profile.version} · ${period.work.size} recorded work entries",
            )
        }

        SectionHeading("Reviewed payments")
        receipt.input.remuneration.forEach { payment ->
            val label = when (payment.kind) {
                com.streamentry.linepay.domain.WeeklyRemunerationKind.STRAIGHT_TIME -> "Straight-time wages"
                com.streamentry.linepay.domain.WeeklyRemunerationKind.INCLUDABLE_BONUS -> "Includable bonus"
                com.streamentry.linepay.domain.WeeklyRemunerationKind.EXCLUDED_CASH -> "Excluded cash"
                com.streamentry.linepay.domain.WeeklyRemunerationKind.EXTRA_PREMIUM ->
                    when (payment.premiumCredit) {
                        com.streamentry.linepay.domain.WeeklyPremiumCredit.ELIGIBLE_EXTRA_PREMIUM ->
                            "Extra premium reviewed as creditable"
                        com.streamentry.linepay.domain.WeeklyPremiumCredit.INELIGIBLE ->
                            "Extra premium reviewed as not creditable"
                        else -> "Extra premium with unclassified credit"
                    }
            }
            Text("$label · ${formatMoney(payment.amount, payment.currencyCode)}")
        }

        SectionHeading("Reference amounts")
        Text("Regular-rate reference: $regularRate")
        Text(
            "Statutory additional premium: ${formatMoney(
                receipt.result.statutoryAdditionalPremium.amount,
                receipt.result.statutoryAdditionalPremium.currencyCode,
            )}",
        )
        Text(
            "Reviewed premium credit: ${formatMoney(
                receipt.result.eligibleExtraPremiumCredit.amount,
                receipt.result.eligibleExtraPremiumCredit.currencyCode,
            )}",
        )
        Text(
            "Additional premium reference: ${formatMoney(
                receipt.result.remainingAdditionalPremium.amount,
                receipt.result.remainingAdditionalPremium.currencyCode,
            )}",
            modifier = Modifier.testTag("weekly-receipt.additional-premium"),
        )
        Text(
            "Separate reference total: ${formatMoney(
                receipt.result.expectedCash.amount,
                receipt.result.expectedCash.currencyCode,
            )}",
        )

        SectionHeading("Allocation by saved paycheck period")
        receipt.result.allocations.forEach { allocation ->
            val period = receipt.source.periods.firstOrNull { it.periodId == allocation.payPeriodId }
            val range = period?.let { "${it.targetStartDate} – ${it.targetLastDate}" } ?: "Unmapped period"
            Text("$range · ${formatMoney(allocation.amount.amount, allocation.amount.currencyCode)}")
        }

        if (receipt.reference.isNotBlank()) {
            SectionHeading("Private source note")
            Text(receipt.reference)
        }

        SectionHeading("Limits")
        Text(
            "This restricted reference uses the saved work and rules shown above. Worker-provided classifications are not independent verification. It does not change a saved paycheck amount or clear a weekly-rate review warning.",
        )
        Text("Calculation engine: ${receipt.result.engine}")
    }
}
