package com.streamentry.linepay.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import java.math.BigDecimal
import java.math.RoundingMode

@Composable
fun TodayScreen(
    state: AndroidLocalState,
    saveError: String?,
    onAddWork: () -> Unit,
    onOpenPay: () -> Unit,
) {
    val profile = requireNotNull(state.profile)
    val period = remember(state.profile, state.work) {
        runCatching { LinePaycheckRepository.currentPeriod(state) }
    }

    PageContent {
        Text("This pay period", style = MaterialTheme.typography.labelLarge)
        val result = period.getOrNull()
        if (result != null) {
            Text(
                "${result.startDate} – ${result.lastDate} · ${result.timeZone.id}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            SectionHeading("Expected wages so far")
            MoneyText(
                formatMoney(result.expectedWages, profile.currencyCode),
                large = true,
                modifier = Modifier.testTag("today.expected-wages"),
            )
            Text(
                "${formatHours(result.workedSeconds)} worked · ${result.shifts} ${if (result.shifts == 1) "shift" else "shifts"}",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.testTag("today.work-summary"),
            )
            if (BigDecimal(result.expectedPerDiem).compareTo(BigDecimal.ZERO) > 0) {
                SectionHeading("Separate expected per diem")
                MoneyText(formatMoney(result.expectedPerDiem, profile.currencyCode))
            }
            result.boundaryReview?.let { InlineMessage(it, isError = true) }
        } else {
            InlineMessage(period.exceptionOrNull()?.message ?: "Expected pay is unavailable.", true)
        }

        InlineMessage("Configured rules only. This estimate is not a legal-pay determination.")
        saveError?.let { InlineMessage(it, isError = true) }

        SectionHeading("Work log")
        if (state.work.isEmpty()) {
            Text("No work logged yet", style = MaterialTheme.typography.bodyLarge)
        } else {
            state.work.take(12).forEach { entry ->
                Text("${entry.timeZone} · ${formatHours(workedSeconds(entry))} hr")
                if (entry.note.isNotBlank()) {
                    Text(entry.note, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                HorizontalDivider()
            }
            if (state.work.size > 12) {
                InlineMessage("Showing the 12 most recent shifts. All records remain in local history.")
            }
        }
        Button(
            onClick = onAddWork,
            modifier = Modifier.fillMaxWidth().testTag("today.add-work"),
        ) {
            Text("Add work")
        }
        if (state.work.isNotEmpty()) {
            OutlinedButton(
                onClick = onOpenPay,
                modifier = Modifier.fillMaxWidth().testTag("today.open-pay"),
            ) {
                Text("Check paycheck")
            }
        }
    }
}

fun formatMoney(value: String, currencyCode: String): String {
    val rounded = BigDecimal(value).setScale(2, RoundingMode.HALF_UP)
    return "$currencyCode ${rounded.toPlainString()}"
}

fun formatHours(seconds: Long): String =
    BigDecimal(seconds).divide(BigDecimal(3600), 2, RoundingMode.HALF_UP).toPlainString()

private fun workedSeconds(entry: AndroidWorkEntry): Long =
    entry.endEpochSeconds - entry.startEpochSeconds -
        entry.breaks.sumOf { it.endEpochSeconds - it.startEpochSeconds }
