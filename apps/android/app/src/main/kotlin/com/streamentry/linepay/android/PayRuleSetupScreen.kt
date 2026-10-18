package com.streamentry.linepay.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp

@Composable
fun PayRuleSetupScreen(
    initial: AndroidRuleProfile?,
    saveError: String?,
    onSave: (AndroidRuleProfile) -> Unit,
) {
    var hourlyRate by rememberSaveable(initial?.id) { mutableStateOf(initial?.hourlyRate ?: "") }
    var currencyCode by rememberSaveable(initial?.id) { mutableStateOf(initial?.currencyCode ?: "USD") }
    var cadence by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.cadence ?: PayCycleChoice.WEEKLY)
    }
    var cycleStartDate by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.cycleStartDate ?: "")
    }
    var customLastDate by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.customLastDate.orEmpty())
    }
    var timeZone by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.payrollTimeZone ?: "America/Chicago")
    }
    var overtimeAfter by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.dailyOvertimeAfterHours ?: "8")
    }
    var overtimeMultiplier by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.dailyOvertimeMultiplier ?: "1.5")
    }
    var outsideScheduleMultiplier by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.outsideScheduleMultiplier ?: "1")
    }
    var perDiem by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.perDiemPerWorkDate.orEmpty())
    }
    var dailyOvertimeEnabled by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.dailyOvertimeAfterHours != null)
    }
    var rulesReviewed by rememberSaveable(initial?.id) {
        mutableStateOf(initial?.rulesReviewedByWorker ?: false)
    }
    var inputError by rememberSaveable(initial?.id) { mutableStateOf<String?>(null) }

    PageContent {
        if (initial == null) {
            Text("Set up a pay profile", style = MaterialTheme.typography.headlineMedium)
            InlineMessage("Rules come from what you enter and confirm. Unconfigured rules stay outside the estimate.")
        } else {
            Text("Review configured rules", style = MaterialTheme.typography.headlineMedium)
        }

        SectionHeading("Hourly rate")
        LocalTextField(
            value = hourlyRate,
            onValueChange = { hourlyRate = it },
            label = "Hourly base rate",
            tag = "setup.hourly-rate",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = currencyCode,
            onValueChange = { currencyCode = it.uppercase().take(3) },
            label = "Currency code",
            tag = "setup.currency",
        )

        SectionHeading("Pay period")
        LocalTextField(
            value = cycleStartDate,
            onValueChange = { cycleStartDate = it },
            label = "Period start date (YYYY-MM-DD)",
            tag = "setup.period-start",
        )
        ColumnChoiceRow(
            title = "Weekly",
            selected = cadence == PayCycleChoice.WEEKLY,
            tag = "setup.cadence.weekly",
        ) { cadence = PayCycleChoice.WEEKLY }
        ColumnChoiceRow(
            title = "Every two weeks",
            selected = cadence == PayCycleChoice.BIWEEKLY,
            tag = "setup.cadence.biweekly",
        ) { cadence = PayCycleChoice.BIWEEKLY }
        ColumnChoiceRow(
            title = "Twice monthly (1st or 16th)",
            selected = cadence == PayCycleChoice.SEMIMONTHLY,
            tag = "setup.cadence.semimonthly",
        ) { cadence = PayCycleChoice.SEMIMONTHLY }
        ColumnChoiceRow(
            title = "Custom dates",
            selected = cadence == PayCycleChoice.CUSTOM,
            tag = "setup.cadence.custom",
        ) { cadence = PayCycleChoice.CUSTOM }
        if (cadence == PayCycleChoice.CUSTOM) {
            LocalTextField(
                value = customLastDate,
                onValueChange = { customLastDate = it },
                label = "Last date, inclusive (YYYY-MM-DD)",
                tag = "setup.period-last",
            )
        }
        LocalTextField(
            value = timeZone,
            onValueChange = { timeZone = it },
            label = "Payroll time zone (for example, America/Chicago)",
            tag = "setup.time-zone",
        )

        SectionHeading("Configured rules")
        Row(
            modifier = Modifier.fillMaxWidth().clickable {
                dailyOvertimeEnabled = !dailyOvertimeEnabled
            },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Checkbox(
                checked = dailyOvertimeEnabled,
                onCheckedChange = { dailyOvertimeEnabled = it },
                modifier = Modifier.testTag("setup.daily-overtime-enabled"),
            )
            Text("Configure daily overtime tier")
        }
        if (dailyOvertimeEnabled) {
            LocalTextField(
                value = overtimeAfter,
                onValueChange = { overtimeAfter = it },
                label = "Overtime after hours in a local day",
                tag = "setup.daily-overtime-after",
                keyboardType = KeyboardType.Decimal,
            )
            LocalTextField(
                value = overtimeMultiplier,
                onValueChange = { overtimeMultiplier = it },
                label = "Overtime multiplier",
                tag = "setup.daily-overtime-multiplier",
                keyboardType = KeyboardType.Decimal,
            )
        }
        LocalTextField(
            value = outsideScheduleMultiplier,
            onValueChange = { outsideScheduleMultiplier = it },
            label = "Outside-schedule multiplier",
            tag = "setup.outside-schedule-multiplier",
            keyboardType = KeyboardType.Decimal,
        )
        LocalTextField(
            value = perDiem,
            onValueChange = { perDiem = it },
            label = "Per diem per worked local date (optional)",
            tag = "setup.per-diem",
            keyboardType = KeyboardType.Decimal,
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp).clickable {
                rulesReviewed = !rulesReviewed
            },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Checkbox(
                checked = rulesReviewed,
                onCheckedChange = { rulesReviewed = it },
                modifier = Modifier.testTag("setup.rules-reviewed"),
            )
            Text(
                "I reviewed which rules are configured. This does not verify agreement scope or complete legal coverage.",
                style = MaterialTheme.typography.bodyMedium,
            )
        }

        inputError?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        Button(
            onClick = {
                runCatching {
                    val profile = AndroidRuleProfile(
                        id = initial?.id ?: java.util.UUID.randomUUID().toString(),
                        version = ((initial?.version?.toIntOrNull() ?: 0) + 1).toString(),
                        hourlyRate = hourlyRate.trim(),
                        currencyCode = currencyCode.trim(),
                        cadence = cadence,
                        cycleStartDate = cycleStartDate.trim(),
                        customLastDate = customLastDate.trim().takeIf { cadence == PayCycleChoice.CUSTOM },
                        payrollTimeZone = timeZone.trim(),
                        dailyOvertimeAfterHours = if (dailyOvertimeEnabled) overtimeAfter.trim() else null,
                        dailyOvertimeMultiplier = overtimeMultiplier.trim(),
                        outsideScheduleMultiplier = outsideScheduleMultiplier.trim(),
                        perDiemPerWorkDate = perDiem.trim().takeIf { it.isNotEmpty() },
                        rulesReviewedByWorker = rulesReviewed,
                    )
                    AndroidLocalStateValidator.validateProfile(profile)
                    onSave(profile)
                    inputError = null
                }.onFailure {
                    inputError = it.message ?: "Check the rule values and try again."
                }
            },
            modifier = Modifier.fillMaxWidth().padding(top = 20.dp).testTag("setup.save"),
        ) {
            Text(if (initial == null) "Save pay rules" else "Save reviewed rules")
        }
    }
}

@Composable
fun LocalTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    tag: String,
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).testTag(tag),
    )
}

@Composable
private fun ColumnChoiceRow(
    title: String,
    selected: Boolean,
    tag: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(
            selected = selected,
            onClick = onClick,
            modifier = Modifier.testTag(tag),
        )
        Text(title)
    }
}
