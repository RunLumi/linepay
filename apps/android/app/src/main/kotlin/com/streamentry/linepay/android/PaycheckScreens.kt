package com.streamentry.linepay.android

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import java.time.Instant

@Composable
fun PayScreen(
    state: AndroidLocalState,
    onRecordPaycheck: () -> Unit,
    onOpenHistory: () -> Unit,
    onWeeklyReview: () -> Unit,
    onOpenWeeklyReceipt: (String) -> Unit,
) {
    val profile = requireNotNull(state.profile)
    val period = runCatching { LinePaycheckRepository.currentPeriod(state) }.getOrNull()
    PageContent {
        Text("Paycheck review", style = MaterialTheme.typography.headlineSmall)
        if (period != null) {
            Text("${period.startDate} – ${period.lastDate} · ${period.timeZone.id}")
            SectionHeading("Expected wages")
            MoneyText(formatMoney(period.expectedWages, profile.currencyCode), large = true)
            if (period.expectedPerDiem != "0.00") {
                SectionHeading("Separate expected per diem")
                MoneyText(formatMoney(period.expectedPerDiem, profile.currencyCode))
            }
            period.boundaryReview?.let { note -> InlineMessage(note, isError = true) }
        } else {
            InlineMessage("A pay period could not be calculated from the saved rules.", true)
        }

        InlineMessage("Expected pay uses only the rules you entered. Unconfigured legal or agreement rules are not assumed away.")
        Button(
            onClick = onRecordPaycheck,
            modifier = Modifier.fillMaxWidth().testTag("pay.record-check"),
        ) {
            Text("Record paycheck facts")
        }
        OutlinedButton(
            onClick = onWeeklyReview,
            modifier = Modifier.fillMaxWidth().testTag("pay.weekly-review"),
        ) { Text("Review complete workweek") }
        if (state.checks.isNotEmpty()) {
            val latest = state.checks.first()
            SectionHeading("Latest saved check")
            Text("${latest.targetStartDate} – ${latest.targetLastDate}")
            Text(verdictLabel(latest.verdict), style = MaterialTheme.typography.titleMedium)
            AndroidWeeklyReviewRepository.relatedReviews(state, latest.id).forEach { receipt ->
                OutlinedButton(
                    onClick = { onOpenWeeklyReceipt(receipt.id) },
                    modifier = Modifier.fillMaxWidth().testTag("pay.weekly-receipt.${receipt.id}"),
                ) { Text("Open linked weekly review details") }
            }
            OutlinedButton(
                onClick = onOpenHistory,
                modifier = Modifier.fillMaxWidth().testTag("pay.open-history"),
            ) {
                Text("Open saved checks")
            }
        }
    }
}

@Composable
fun RecordPaycheckScreen(
    state: AndroidLocalState,
    saveError: String?,
    onSave: (AndroidLocalState) -> Unit,
) {
    val profile = requireNotNull(state.profile)
    val period = LinePaycheckRepository.payWindow(profile)
    var sourceStart by rememberSaveable(profile.id) {
        mutableStateOf(period.startDate.toString())
    }
    var sourceLast by rememberSaveable(profile.id) {
        mutableStateOf(period.lastDate.toString())
    }
    var sourceZone by rememberSaveable(profile.id) {
        mutableStateOf(profile.payrollTimeZone)
    }
    var paidGross by rememberSaveable(profile.id) { mutableStateOf("") }
    var basis by rememberSaveable(profile.id) { mutableStateOf(GrossBasisChoice.WAGES_ONLY) }
    var sourceConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var completeWork by rememberSaveable(profile.id) { mutableStateOf(false) }
    var rulesReviewed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var inputError by rememberSaveable(profile.id) { mutableStateOf<String?>(null) }

    PageContent {
        Text("Confirm what the paycheck shows", style = MaterialTheme.typography.headlineSmall)
        InlineMessage("The source period and the selected work period must match before values can be compared.")
        LocalTextField(sourceStart, { sourceStart = it }, "Statement period starts (YYYY-MM-DD)", "check.period-start")
        LocalTextField(sourceLast, { sourceLast = it }, "Statement period ends (YYYY-MM-DD)", "check.period-end")
        LocalTextField(sourceZone, { sourceZone = it }, "Statement payroll time zone", "check.time-zone")
        LocalTextField(paidGross, { paidGross = it }, "Paystub gross amount", "check.gross")
        Text("What the gross amount includes", style = MaterialTheme.typography.titleMedium)
        ChoiceRow(
            label = "Wages only; per diem is separate",
            selected = basis == GrossBasisChoice.WAGES_ONLY,
            tag = "check.basis.wages",
        ) { basis = GrossBasisChoice.WAGES_ONLY }
        ChoiceRow(
            label = "Wages and per diem together",
            selected = basis == GrossBasisChoice.WAGES_AND_PER_DIEM,
            tag = "check.basis.total",
        ) { basis = GrossBasisChoice.WAGES_AND_PER_DIEM }

        ConfirmationRow(
            checked = sourceConfirmed,
            tag = "check.confirm-period",
            label = "I confirmed the dates and payroll time zone from this statement.",
        ) { sourceConfirmed = it }
        ConfirmationRow(
            checked = completeWork,
            tag = "check.complete-work",
            label = "All work for this pay period is recorded.",
        ) { completeWork = it }
        ConfirmationRow(
            checked = rulesReviewed,
            tag = "check.rules-reviewed",
            label = "I reviewed whether these configured rules cover my circumstances. This is not independent verification.",
        ) { rulesReviewed = it }
        InlineMessage("Weekly-rate treatment remains pending until a source-approved mapping is available. A separate weekly reference cannot clear this review.")
        InlineMessage("A match means these confirmed values match within the configured scope. It does not establish that every law or agreement rule is represented.")
        inputError?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        Button(
            onClick = {
                runCatching {
                    val input = AndroidPaycheckInput(
                        sourceStartDate = sourceStart.trim(),
                        sourceLastDate = sourceLast.trim(),
                        sourceTimeZone = sourceZone.trim(),
                        sourcePeriodConfirmed = sourceConfirmed,
                        paidGross = paidGross.trim(),
                        basis = basis,
                        completeWorkConfirmed = completeWork,
                        ruleCoverageConfirmed = rulesReviewed,
                    )
                    val (next, _) = LinePaycheckRepository.savePaycheck(
                        state = state,
                        input = input,
                        createdAtEpochSeconds = Instant.now().epochSecond,
                    )
                    onSave(next)
                    inputError = null
                }.onFailure { inputError = it.message ?: "This check could not be saved." }
            },
            modifier = Modifier.fillMaxWidth().testTag("check.save"),
        ) {
            Text("Save configured-rules check")
        }
    }
}

@Composable
fun HistoryScreen(
    state: AndroidLocalState,
    saveError: String?,
    onDeleteCheck: (String) -> Boolean,
    onOpenBenefitReceipt: (String) -> Unit,
    onOpenPortableReceipt: (String) -> Unit,
    onOpenWeeklyReceipt: (String) -> Unit,
) {
    var deleteCandidate by remember { mutableStateOf<AndroidPaycheckSnapshot?>(null) }
    deleteCandidate?.let { check ->
        val linkedCount = AndroidWeeklyReviewRepository.relatedReviews(state, check.id).size
        AlertDialog(
            onDismissRequest = { deleteCandidate = null },
            title = { Text("Delete saved paycheck period?") },
            text = {
                Text(
                    if (linkedCount == 0) {
                        "This removes the saved period receipt. Work records remain unchanged."
                    } else {
                        "This removes the saved period and its $linkedCount linked weekly review ${if (linkedCount == 1) "receipt" else "receipts"}. Work records remain unchanged."
                    },
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(
                    onClick = {
                        if (onDeleteCheck(check.id)) deleteCandidate = null
                    },
                    modifier = Modifier.testTag("history.confirm-delete-check"),
                ) { Text("Delete period") }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { deleteCandidate = null }) {
                    Text("Keep period")
                }
            },
        )
    }
    PageContent {
        PortableReceiptHistory(state.portableArchive, onOpenPortableReceipt)
        if (state.benefitReviews.isNotEmpty()) {
            BenefitHistoryRows(state.benefitReviews, onOpenBenefitReceipt)
        }
        Text("Saved checks", style = MaterialTheme.typography.headlineSmall)
        InlineMessage("Each check keeps the work, rules, statement period and result that were saved at that time.")
        saveError?.let { InlineMessage(it, isError = true) }
        if (state.weeklyReviews.isNotEmpty()) {
            SectionHeading("Weekly review receipts")
            Text("These are separate frozen references. They do not change saved paycheck gross or verdicts.")
            state.weeklyReviews.forEach { receipt ->
                val start = Instant.ofEpochSecond(receipt.source.startEpochSeconds)
                    .atZone(java.time.ZoneId.of(receipt.source.timeZone))
                Text("${start.toLocalDate()} · additional premium reference ${formatMoney(receipt.result.remainingAdditionalPremium.amount, receipt.result.remainingAdditionalPremium.currencyCode)}")
                Text("${receipt.source.periods.size} linked paycheck ${if (receipt.source.periods.size == 1) "period" else "periods"} · receipt ${receipt.id}")
                OutlinedButton(
                    onClick = { onOpenWeeklyReceipt(receipt.id) },
                    modifier = Modifier.fillMaxWidth().testTag("history.weekly-receipt.${receipt.id}"),
                ) { Text("Open weekly review details") }
            }
        }
        if (state.checks.isEmpty()) {
            Text("No saved paycheck checks yet.")
        } else {
            state.checks.forEach { check ->
                SectionHeading("${check.targetStartDate} – ${check.targetLastDate}")
                Text(verdictLabel(check.verdict), style = MaterialTheme.typography.titleMedium)
                Text("Confirmed gross: ${formatMoney(check.paidGross, check.profile.currencyCode)}")
                check.expectedGross?.let {
                    Text("Expected in this scope: ${formatMoney(it, check.profile.currencyCode)}")
                }
                Text("Coverage: configured rules only", color = MaterialTheme.colorScheme.onSurfaceVariant)
                check.reviewReasons.forEach { reason ->
                    Text("Needs review: ${reviewReasonLabel(reason)}")
                }
                AndroidWeeklyReviewRepository.relatedReviews(state, check.id).forEach { receipt ->
                    OutlinedButton(
                        onClick = { onOpenWeeklyReceipt(receipt.id) },
                        modifier = Modifier.fillMaxWidth()
                            .testTag("history.check.${check.id}.weekly-receipt.${receipt.id}"),
                    ) {
                        Text(
                            "Open weekly review · additional premium ${formatMoney(receipt.result.remainingAdditionalPremium.amount, receipt.result.remainingAdditionalPremium.currencyCode)}",
                        )
                    }
                }
                androidx.compose.material3.TextButton(
                    onClick = { deleteCandidate = check },
                    modifier = Modifier.fillMaxWidth().testTag("history.delete-check.${check.id}"),
                ) { Text("Delete saved period") }
            }
        }
    }
}

@Composable
private fun ChoiceRow(
    label: String,
    selected: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onClick, modifier = Modifier.testTag(tag))
        Text(label, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun ConfirmationRow(
    checked: Boolean,
    tag: String,
    label: String,
    onCheckedChange: (Boolean) -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.testTag(tag),
        )
        Text(label, modifier = Modifier.weight(1f))
    }
}

fun verdictLabel(verdict: String): String = when (verdict) {
    "MATCHES" -> "Compared values match"
    "POSSIBLE_SHORTFALL" -> "Possible difference under configured rules"
    "POSSIBLE_OVERPAYMENT" -> "Possible difference under configured rules"
    "NEEDS_REVIEW" -> "Needs review"
    else -> "Not comparable"
}

private fun reviewReasonLabel(reason: String): String = when (reason) {
    "INCOMPLETE_WORK" -> "the work log may be incomplete"
    "UNCONFIRMED_GROSS_BASIS" -> "the gross-pay basis is unconfirmed"
    "UNSUPPORTED_RULES" -> "rule coverage is not confirmed"
    "WEEKLY_REVIEW_PENDING" -> "weekly-rate review is pending"
    "UNCONFIRMED_PERIOD" -> "the statement period is unconfirmed"
    "DIFFERENT_PERIOD" -> "the statement period differs from the work period"
    else -> reason.lowercase().replace('_', ' ')
}
