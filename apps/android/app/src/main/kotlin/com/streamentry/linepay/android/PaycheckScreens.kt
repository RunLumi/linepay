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
    var sourceCurrency by rememberSaveable(profile.id) { mutableStateOf(profile.currencyCode) }
    var paidGross by rememberSaveable(profile.id) { mutableStateOf("") }
    var basis by rememberSaveable(profile.id) { mutableStateOf(GrossBasisChoice.WAGES_ONLY) }
    var sourceConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var completeWork by rememberSaveable(profile.id) { mutableStateOf(false) }
    var rulesReviewed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var showLines by rememberSaveable(profile.id) { mutableStateOf(false) }
    var lineLayout by rememberSaveable(profile.id) { mutableStateOf("UNCONFIRMED") }
    var hoursBasis by rememberSaveable(profile.id) { mutableStateOf("UNCONFIRMED") }
    var guaranteeLayout by rememberSaveable(profile.id) { mutableStateOf("UNCONFIRMED") }
    var regularPay by rememberSaveable(profile.id) { mutableStateOf("") }
    var overtimePay by rememberSaveable(profile.id) { mutableStateOf("") }
    var doubleTimePay by rememberSaveable(profile.id) { mutableStateOf("") }
    var calloutPay by rememberSaveable(profile.id) { mutableStateOf("") }
    var regularHours by rememberSaveable(profile.id) { mutableStateOf("") }
    var overtimeHours by rememberSaveable(profile.id) { mutableStateOf("") }
    var doubleTimeHours by rememberSaveable(profile.id) { mutableStateOf("") }
    var paidPerDiem by rememberSaveable(profile.id) { mutableStateOf("") }
    var completeEarningsLines by rememberSaveable(profile.id) { mutableStateOf(false) }
    var inputError by rememberSaveable(profile.id) { mutableStateOf<String?>(null) }

    PageContent {
        Text("Confirm what the paycheck shows", style = MaterialTheme.typography.headlineSmall)
        InlineMessage("The source period and the selected work period must match before values can be compared.")
        LocalTextField(sourceStart, { sourceStart = it }, "Statement period starts (YYYY-MM-DD)", "check.period-start")
        LocalTextField(sourceLast, { sourceLast = it }, "Statement period ends (YYYY-MM-DD)", "check.period-end")
        LocalTextField(sourceZone, { sourceZone = it }, "Statement payroll time zone", "check.time-zone")
        LocalTextField(sourceCurrency, { sourceCurrency = it }, "Statement currency (three-letter code)", "check.currency")
        Text("All entered money uses this statement currency. It must match ${profile.currencyCode}; this comparison does not convert currencies.")
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

        androidx.compose.material3.TextButton(onClick = { showLines = !showLines }, modifier = Modifier.testTag("check.show-lines")) {
            Text(if (showLines) "Hide source lines" else "Add hours and earnings lines (optional)")
        }
        if (showLines) {
            SectionHeading("Source hours and earnings")
            Text("Enter only current-period values you identified on this statement. Typed values count as your confirmation. Blank means unknown; enter 0 only when the source confirms zero. Money and hours are different quantities.")
            Text("Full rates include base pay in each overtime bucket. Base plus premiums puts all applicable base pay in the regular line and only the extra premium in the overtime/double-time lines.")
            for ((value, label) in listOf("UNCONFIRMED" to "Earnings layout not confirmed", "FULL_RATE_BUCKETS" to "Full rates in separate buckets", "BASE_PLUS_PREMIUM" to "Base pay plus extra premiums")) {
                ChoiceRow(label, lineLayout == value, "check.layout.$value") { lineLayout = value }
            }
            Text("Actual hours exclude guarantee top-ups. Paid-equivalent hours can include a configured guarantee only when it is mapped into hourly lines.")
            for ((value, label) in listOf("UNCONFIRMED" to "Hours basis not confirmed", "ACTUAL_WORK" to "Actual worked hours", "PAID_EQUIVALENTS" to "Paid-equivalent hours")) {
                ChoiceRow(label, hoursBasis == value, "check.hours-basis.$value") { hoursBasis = value }
            }
            Text("Callout mapping describes the statement only. This native profile does not configure a callout guarantee; choosing a mapping does not add one or establish eligibility.")
            for ((value, label) in listOf("UNCONFIRMED" to "Callout mapping not confirmed", "SEPARATE_LINE" to "Callout guarantee shown separately", "INCLUDED_IN_HOURLY_LINES" to "Callout guarantee included in hourly lines")) {
                ChoiceRow(label, guaranteeLayout == value, "check.guarantee.$value") { guaranteeLayout = value }
            }
            LocalTextField(regularPay, { regularPay = it }, "Regular/base pay (optional)", "check.line.regular-pay")
            LocalTextField(overtimePay, { overtimePay = it }, "Overtime pay (optional)", "check.line.overtime-pay")
            LocalTextField(doubleTimePay, { doubleTimePay = it }, "Double-time pay (optional)", "check.line.double-time-pay")
            LocalTextField(calloutPay, { calloutPay = it }, "Separate callout pay (optional)", "check.line.callout-pay")
            LocalTextField(paidPerDiem, { paidPerDiem = it }, "Observed per diem (optional)", "check.line.per-diem-pay")
            LocalTextField(regularHours, { regularHours = it }, "Regular/base hours (optional)", "check.line.regular-hours")
            LocalTextField(overtimeHours, { overtimeHours = it }, "Overtime hours (optional)", "check.line.overtime-hours")
            LocalTextField(doubleTimeHours, { doubleTimeHours = it }, "Double-time hours (optional)", "check.line.double-time-hours")
            Text("Hour comparisons use exact worked seconds and four-place half-up hour differences. Money differences use the configured wage rounding policy. Original typed observations stay saved.")
            ConfirmationRow(completeEarningsLines, "check.complete-lines", "These entered earnings lines are the complete breakdown of this stated gross, including any observed per diem it includes.") { completeEarningsLines = it }
        }

        ConfirmationRow(
            checked = sourceConfirmed,
            tag = "check.confirm-period",
            label = "I confirmed the dates, payroll time zone and currency from this statement.",
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
                        confirmedLineFacts = AndroidConfirmedPaycheckLines(
                            currencyCode = sourceCurrency.trim().uppercase(),
                            layout = lineLayout, hoursBasis = hoursBasis, guaranteeLayout = guaranteeLayout,
                            regularPay = regularPay.trim().takeIf { it.isNotEmpty() }, overtimePay = overtimePay.trim().takeIf { it.isNotEmpty() },
                            doubleTimePay = doubleTimePay.trim().takeIf { it.isNotEmpty() }, calloutPay = calloutPay.trim().takeIf { it.isNotEmpty() },
                            regularHours = regularHours.trim().takeIf { it.isNotEmpty() }, overtimeHours = overtimeHours.trim().takeIf { it.isNotEmpty() },
                            doubleTimeHours = doubleTimeHours.trim().takeIf { it.isNotEmpty() }, paidPerDiem = paidPerDiem.trim().takeIf { it.isNotEmpty() },
                            completeEarningsLines = completeEarningsLines,
                        ),
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
                PaycheckLineHistory(check)
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
private fun PaycheckLineHistory(check: AndroidPaycheckSnapshot) {
    val capture = check.confirmedLineFacts
    if (capture == null) {
        Text("Earlier source lines were not recorded; the original saved result remains unchanged.")
        return
    }
    if (check.comparisons.any { it.field != "GROSS_PAY" && java.math.BigDecimal(it.difference).signum() != 0 }) {
        Text("A saved line comparison differs. Matching gross does not cancel individual money or hour differences.")
    }
    var expanded by rememberSaveable(check.id) { mutableStateOf(false) }
    androidx.compose.material3.TextButton(onClick = { expanded = !expanded }, modifier = Modifier.testTag("history.check.${check.id}.lines")) {
        Text(if (expanded) "Hide source lines and comparisons" else "Show source lines and comparisons")
    }
    if (expanded) {
        Text("Layout: ${capture.layout.lowercase().replace('_', ' ')} · hours: ${capture.hoursBasis.lowercase().replace('_', ' ')}")
        Text("Callout mapping: ${capture.guaranteeLayout.lowercase().replace('_', ' ')}")
        Text(if (capture.completeEarningsLines) "Worker confirmed a complete earnings breakdown." else "Earnings breakdown completeness was not confirmed.")
        SectionHeading("Observed source values · ${capture.currencyCode}")
        if (capture.amounts().isEmpty() && capture.hours().isEmpty() && capture.paidPerDiem == null) Text("No earnings or hour lines were entered. Blank observations remain unknown.")
        capture.amounts().forEach { (field, value) -> Text("${lineFieldLabel(field.name)}: ${check.profile.currencyCode} $value", fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace) }
        capture.hours().forEach { (field, value) -> Text("${lineFieldLabel(field.name)}: $value hours", fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace) }
        capture.paidPerDiem?.let { Text("Observed per diem: ${check.profile.currencyCode} $it") }
        SectionHeading("Frozen comparisons")
        if (check.comparisons.isEmpty()) Text("No values were comparable for the saved statement period and scope.")
        check.comparisons.forEach { part ->
            val suffix = if (part.unit == "HOURS") " hours" else " ${part.currencyCode}"
            Text("${lineFieldLabel(part.field)} · expected ${part.expected}$suffix · source ${part.paid}$suffix · expected minus source ${part.difference}$suffix", fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace, modifier = Modifier.testTag("history.check.${check.id}.comparison.${part.field}"))
            Text("${part.componentIds.size} original ledger components · rule ${check.profile.calculationRuleID ?: check.profile.id} / ${check.profile.version}")
        }
        Text("These values use the original work, rule and source snapshots. Line comparisons do not verify weekly statutory treatment or complete legal coverage.")
    }
}

private fun lineFieldLabel(field: String): String = when (field) {
    "GROSS_PAY" -> "Gross pay"
    "PER_DIEM_PAY" -> "Per diem"
    "REGULAR_PAY" -> "Regular/base pay"
    "OVERTIME_PAY" -> "Overtime pay"
    "DOUBLE_TIME_PAY" -> "Double-time pay"
    "CALLOUT_PAY" -> "Separate callout pay"
    "REGULAR_HOURS" -> "Regular/base hours"
    "OVERTIME_HOURS" -> "Overtime hours"
    "DOUBLE_TIME_HOURS" -> "Double-time hours"
    else -> field
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
