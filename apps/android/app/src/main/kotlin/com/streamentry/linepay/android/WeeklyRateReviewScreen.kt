package com.streamentry.linepay.android

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import java.time.Instant
import java.time.ZoneId

@Composable
fun WeeklyRateReviewScreen(
    state: AndroidLocalState,
    saveError: String?,
    onSave: (AndroidLocalState) -> Boolean,
    onOpenHistory: () -> Unit,
    onOpenWeeklyReceipt: (String) -> Unit,
) {
    val profile = requireNotNull(state.profile)
    var startLocal by rememberSaveable(profile.id) {
        mutableStateOf("${profile.cycleStartDate} 00:00")
    }
    var selectedIds by rememberSaveable(state.checks.map { it.id }) { mutableStateOf("") }
    var straightTimeWages by rememberSaveable(profile.id) { mutableStateOf("") }
    var includableBonus by rememberSaveable(profile.id) { mutableStateOf("") }
    var excludedCash by rememberSaveable(profile.id) { mutableStateOf("") }
    var eligibleExtraPremium by rememberSaveable(profile.id) { mutableStateOf("") }
    var ineligibleExtraPremium by rememberSaveable(profile.id) { mutableStateOf("") }
    var reference by rememberSaveable(profile.id) { mutableStateOf("") }
    var boundaryConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var employerConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var completeWorkweek by rememberSaveable(profile.id) { mutableStateOf(false) }
    var paymentsConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var applicabilityConfirmed by rememberSaveable(profile.id) { mutableStateOf(false) }
    var preview by remember { mutableStateOf<AndroidWeeklyReviewReceipt?>(null) }
    var inputError by rememberSaveable(profile.id) { mutableStateOf<String?>(null) }

    fun changed() {
        preview = null
        inputError = null
    }

    val checkedIds = selectedIds.split(',').filter { it.isNotBlank() }.toSet()
    val visibleSources = remember(state.checks, startLocal, profile.payrollTimeZone) {
        runCatching {
            AndroidWeeklyReviewRepository.periodsContainingWorkInWeek(
                state = state,
                startLocal = startLocal,
                timeZone = profile.payrollTimeZone,
            )
        }
    }
    val sources = visibleSources.getOrDefault(emptyList())
    val savedReviews = state.weeklyReviews

    PageContent {
        Text("Complete workweek review", style = MaterialTheme.typography.headlineSmall)
        InlineMessage(
            "This restricted weekly reference is separate from the paycheck comparison. It does not change gross pay, clear a Needs review warning, or establish legal or agreement applicability.",
        )
        SectionHeading("Workweek boundary")
        LocalTextField(
            value = startLocal,
            onValueChange = { startLocal = it; selectedIds = ""; changed() },
            label = "Exact local start (YYYY-MM-DD HH:MM)",
            tag = "weekly.start",
        )
        Text("Payroll time zone: ${profile.payrollTimeZone} · fixed 168 elapsed hours")
        Text("A calendar pay period does not establish the employer's recurring workweek boundary.")

        SectionHeading("Saved paycheck periods and work")
        Text("Choose one saved check for each distinct period. If a period has several checks, inspect their work and rule versions before choosing. All alternatives remain in history.")
        if (visibleSources.isFailure) {
            Text("Enter a valid, unambiguous workweek start to see matching saved periods.")
        } else if (sources.isEmpty()) {
            Text("No saved paycheck period contains work in this 168-hour workweek.")
        } else {
            sources.groupBy(AndroidWeeklyReviewRepository::sourcePeriodKey).forEach { (period, alternatives) ->
                Text("${period.first} – ${period.second} · ${period.third}", style = MaterialTheme.typography.titleSmall)
                if (alternatives.size > 1) Text("${alternatives.size} saved alternatives · choose one; none is selected for you.")
                alternatives.forEach { check ->
                    WeeklySelectionRow(
                        checked = check.id in checkedIds,
                        tag = "weekly.source.${check.id}",
                        label = "${check.profile.currencyCode} ${check.profile.hourlyRate}/hr · rule ${check.profile.version} · ${check.work.size} work entries · saved ${Instant.ofEpochSecond(check.createdAtEpochSeconds)}",
                    ) { selected ->
                        val next = checkedIds.toMutableSet()
                        next.removeAll(alternatives.map { it.id }.toSet())
                        if (selected) next += check.id
                        selectedIds = next.sorted().joinToString(",")
                        changed()
                    }
                    var inspectSource by rememberSaveable(check.id) { mutableStateOf(false) }
                    OutlinedButton(
                        onClick = { inspectSource = !inspectSource },
                        modifier = Modifier.fillMaxWidth().testTag("weekly.inspect.${check.id}"),
                    ) { Text(if (inspectSource) "Hide source work" else "Inspect saved source work") }
                    if (inspectSource) {
                        Text("Saved source identity: ${check.id}")
                        Text("Original source work is shown below. Weekly calculation clips it to the confirmed 168-hour interval and removes recorded unpaid breaks.")
                        check.work.forEach { entry ->
                            val sourceZone = ZoneId.of(entry.timeZone)
                            Text("${Instant.ofEpochSecond(entry.startEpochSeconds).atZone(sourceZone)} – ${Instant.ofEpochSecond(entry.endEpochSeconds).atZone(sourceZone)} · work ${entry.id}")
                            entry.breaks.forEach { pause ->
                                Text("Unpaid break: ${Instant.ofEpochSecond(pause.startEpochSeconds).atZone(sourceZone)} – ${Instant.ofEpochSecond(pause.endEpochSeconds).atZone(sourceZone)}")
                            }
                        }
                    }
                }
            }
        }
        Text("Only saved periods containing work in this 168-hour week are shown. Choose one source for every distinct period yourself; none are selected automatically. The selected sources must cover every recorded shift, including work retained in alternatives. Confirm that they belong to one employer and contain all work for the week.")

        SectionHeading("Reviewed payments")
        LocalTextField(
            value = straightTimeWages,
            onValueChange = { straightTimeWages = it; changed() },
            label = "Straight-time wages for all hours (required)",
            tag = "weekly.wages",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = includableBonus,
            onValueChange = { includableBonus = it; changed() },
            label = "Includable bonus (optional)",
            tag = "weekly.bonus",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = excludedCash,
            onValueChange = { excludedCash = it; changed() },
            label = "Excluded cash payment (optional)",
            tag = "weekly.excluded-cash",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = eligibleExtraPremium,
            onValueChange = { eligibleExtraPremium = it; changed() },
            label = "Extra premium reviewed as creditable (optional)",
            tag = "weekly.eligible-premium",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = ineligibleExtraPremium,
            onValueChange = { ineligibleExtraPremium = it; changed() },
            label = "Extra premium reviewed as not creditable (optional)",
            tag = "weekly.ineligible-premium",
            keyboardType = KeyboardType.Decimal,
        )
        Text("Enter each cash amount once. Do not enter net pay, year-to-date totals, or employer fund contributions. Classification is a worker-provided fact, not legal verification.")
        LocalTextField(
            value = reference,
            onValueChange = { reference = it.take(2_000); changed() },
            label = "Private source note (optional)",
            tag = "weekly.reference",
        )

        SectionHeading("Confirm this review")
        WeeklyConfirmationRow("weekly.confirm-boundary", "I confirmed the employer's exact recurring 168-hour boundary.", boundaryConfirmed) { boundaryConfirmed = it; changed() }
        WeeklyConfirmationRow("weekly.confirm-employer", "I confirmed every selected period belongs to one employer.", employerConfirmed) { employerConfirmed = it; changed() }
        WeeklyConfirmationRow("weekly.confirm-work", "I recorded every shift and unpaid break for the complete week.", completeWorkweek) { completeWorkweek = it; changed() }
        WeeklyConfirmationRow("weekly.confirm-payments", "I reviewed all amounts and payment classifications.", paymentsConfirmed) { paymentsConfirmed = it; changed() }
        WeeklyConfirmationRow("weekly.confirm-applicability", "I confirmed covered, nonexempt hourly scope for this reference; this is not independent verification.", applicabilityConfirmed) { applicabilityConfirmed = it; changed() }

        inputError?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        Button(
            onClick = {
                runCatching {
                    val request = AndroidWeeklyReviewRequest(
                        startLocal = startLocal.trim(),
                        timeZone = profile.payrollTimeZone,
                        sourcePeriodIds = checkedIds.toList(),
                        straightTimeWages = straightTimeWages.trim(),
                        includableBonus = includableBonus.trim(),
                        excludedCash = excludedCash.trim(),
                        eligibleExtraPremium = eligibleExtraPremium.trim(),
                        ineligibleExtraPremium = ineligibleExtraPremium.trim(),
                        reference = reference.trim(),
                        boundaryConfirmed = boundaryConfirmed,
                        singleEmployerConfirmed = employerConfirmed,
                        paymentsConfirmed = paymentsConfirmed,
                        completeWorkweek = completeWorkweek,
                        applicabilityConfirmed = applicabilityConfirmed,
                    )
                    preview = AndroidWeeklyReviewRepository.preview(
                        state = state,
                        request = request,
                        createdAtEpochSeconds = Instant.now().epochSecond,
                    )
                    inputError = null
                }.onFailure { inputError = it.message ?: "The weekly review could not be calculated." }
            },
            modifier = Modifier.fillMaxWidth().testTag("weekly.preview"),
        ) { Text("Review complete workweek") }

        preview?.let { receipt ->
            SectionHeading("Preview · not saved yet")
            Text("Reviewed cash: ${formatMoney(receipt.result.cashRemuneration.amount, receipt.result.cashRemuneration.currencyCode)}")
            Text("Regular-rate reference: ${receipt.result.regularRate?.let { formatMoney(it.amount, it.currencyCode) } ?: "Not available"}")
            Text("Additional premium reference: ${formatMoney(receipt.result.remainingAdditionalPremium.amount, receipt.result.remainingAdditionalPremium.currencyCode)}")
            Text("Separate reference total: ${formatMoney(receipt.result.expectedCash.amount, receipt.result.expectedCash.currencyCode)}")
            receipt.result.allocations.forEach { allocation ->
                val period = receipt.source.periods.firstOrNull { it.periodId == allocation.payPeriodId }
                Text("${period?.targetStartDate ?: "Unmapped period"} allocation · ${formatMoney(allocation.amount.amount, allocation.amount.currencyCode)}")
            }
            Text("This estimate remains separate from every saved paycheck gross and verdict.")
            Button(
                onClick = {
                    runCatching {
                        val next = AndroidWeeklyReviewRepository.append(state, receipt)
                        if (onSave(next)) onOpenHistory()
                    }.onFailure { inputError = it.message ?: "The weekly receipt could not be saved." }
                },
                modifier = Modifier.fillMaxWidth().testTag("weekly.save"),
            ) { Text("Save as new weekly review") }
        }

        if (savedReviews.isNotEmpty()) {
            SectionHeading("Retained weekly reviews")
            savedReviews.forEach { receipt ->
                val weekStart = Instant.ofEpochSecond(receipt.source.startEpochSeconds)
                    .atZone(ZoneId.of(receipt.source.timeZone))
                Text("${weekStart.toLocalDate()} · additional premium ${formatMoney(receipt.result.remainingAdditionalPremium.amount, receipt.result.remainingAdditionalPremium.currencyCode)}")
                Text("Saved receipt ${receipt.id}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedButton(
                    onClick = { onOpenWeeklyReceipt(receipt.id) },
                    modifier = Modifier.fillMaxWidth().testTag("weekly.saved-receipt.${receipt.id}"),
                ) { Text("Open weekly review details") }
            }
            OutlinedButton(
                onClick = onOpenHistory,
                modifier = Modifier.fillMaxWidth().testTag("weekly.open-history"),
            ) { Text("Open saved history") }
        }
    }
}

@Composable
private fun WeeklySelectionRow(
    checked: Boolean,
    tag: String,
    label: String,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        RadioButton(selected = checked, onClick = { onCheckedChange(true) }, modifier = Modifier.testTag(tag))
        Text(label, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun WeeklyConfirmationRow(
    tag: String,
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Checkbox(checked = checked, onCheckedChange = onCheckedChange, modifier = Modifier.testTag(tag))
        Text(label, modifier = Modifier.weight(1f))
    }
}
