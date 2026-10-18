package com.streamentry.linepay.android

import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import java.time.LocalDate
import java.time.ZoneId

@Composable
fun AddWorkScreen(
    state: AndroidLocalState,
    saveError: String?,
    onSave: (AndroidLocalState) -> Unit,
) {
    val profile = requireNotNull(state.profile)
    val zone = ZoneId.of(profile.payrollTimeZone)
    val dateDefault = LocalDate.now(zone).toString()
    var start by rememberSaveable(profile.id, profile.version) {
        mutableStateOf("$dateDefault 07:00")
    }
    var end by rememberSaveable(profile.id, profile.version) {
        mutableStateOf("$dateDefault 15:30")
    }
    var breakStart by rememberSaveable(profile.id, profile.version) {
        mutableStateOf("")
    }
    var breakEnd by rememberSaveable(profile.id, profile.version) {
        mutableStateOf("")
    }
    var note by rememberSaveable(profile.id, profile.version) { mutableStateOf("") }
    var error by rememberSaveable(profile.id, profile.version) { mutableStateOf<String?>(null) }

    PageContent {
        Text("Record the work you performed", style = MaterialTheme.typography.titleLarge)
        InlineMessage("Enter local date and 24-hour time as YYYY-MM-DD HH:mm. The payroll time zone is shown below.")
        Text("Payroll time zone: ${profile.payrollTimeZone}")
        LocalTextField(start, { start = it }, "Shift starts", "shift.start")
        LocalTextField(end, { end = it }, "Shift ends", "shift.end")
        LocalTextField(
            breakStart,
            { breakStart = it },
            "Unpaid break starts (optional)",
            "shift.break-start",
        )
        LocalTextField(
            breakEnd,
            { breakEnd = it },
            "Unpaid break ends (optional)",
            "shift.break-end",
        )
        LocalTextField(note, { note = it }, "Work note (optional)", "shift.note")
        InlineMessage("Only the break interval you enter is removed from worked time. Break classification is not inferred.")
        error?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        Button(
            onClick = {
                runCatching {
                    val next = LinePaycheckRepository.addWork(
                        state = state,
                        startLocal = start,
                        endLocal = end,
                        breakStartLocal = breakStart,
                        breakEndLocal = breakEnd,
                        note = note,
                    )
                    onSave(next)
                    error = null
                }.onFailure { error = it.message ?: "Work could not be saved." }
            },
            modifier = Modifier.testTag("shift.save"),
        ) {
            Text("Save work")
        }
    }
}
