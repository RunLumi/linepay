package com.streamentry.linepay.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.streamentry.linepay.backup.BackupEnvelope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun SettingsScreen(
    state: AndroidLocalState,
    activity: AndroidLocalActivitySnapshot,
    activityError: String?,
    saveError: String?,
    onEditRules: () -> Unit,
    onSaveState: (AndroidLocalState) -> Boolean,
    onSaveActivity: (AndroidLocalActivitySnapshot) -> Boolean,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val stateStore = remember { LocalStateStore(context.filesDir) }
    val activityStore = remember { LocalActivityStore(context.filesDir) }
    var backupPassword by rememberSaveable { mutableStateOf("") }
    var restorePassword by rememberSaveable { mutableStateOf("") }
    var pendingExport by remember { mutableStateOf<ByteArray?>(null) }
    var pendingImportBytes by remember { mutableStateOf<ByteArray?>(null) }
    var restorePreview by remember { mutableStateOf<AndroidLocalState?>(null) }
    var message by rememberSaveable { mutableStateOf<String?>(null) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    var busy by rememberSaveable { mutableStateOf(false) }

    val exportBackup = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream"),
    ) { uri ->
        val bytes = pendingExport
        if (uri != null && bytes != null) {
            runCatching { writeDocument(context, uri, bytes) }
                .onSuccess { message = "Encrypted backup saved to the destination you chose." }
                .onFailure { error = it.message ?: "Backup export failed." }
        }
        bytes?.fill(0)
        pendingExport = null
    }

    val exportDiagnostics = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        if (uri != null) {
            runCatching { writeDocument(context, uri, activityStore.diagnosticJson(activity)) }
                .onSuccess { message = "Local diagnostics exported to the destination you chose." }
                .onFailure { error = it.message ?: "Diagnostic export failed." }
        }
    }

    val selectBackup = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            busy = true
            error = null
            scope.launch {
                runCatching { readDocument(context, uri) }
                    .onSuccess { bytes ->
                        pendingImportBytes = bytes
                        restorePreview = null
                        message = "Backup selected. Enter its password, then review what will be restored."
                    }
                    .onFailure { error = it.message ?: "The selected file could not be read." }
                busy = false
            }
        }
    }

    PageContent {
        Text("Privacy and local data", style = androidx.compose.material3.MaterialTheme.typography.headlineSmall)
        SectionHeading("Pay rules")
        val profile = requireNotNull(state.profile)
        Text("${profile.currencyCode} ${profile.hourlyRate} per hour")
        Text("${profile.cadence.name.lowercase()} · ${profile.payrollTimeZone}")
        Text("Rule version ${profile.version}")
        OutlinedButton(
            onClick = onEditRules,
            modifier = Modifier.fillMaxWidth().testTag("settings.edit-rules"),
        ) { Text("Edit pay rules") }

        SectionHeading("Privacy")
        Text("Pay, work, saved checks and rules stay in this app's private local files. There is no LinePaycheck account, pay-data server or analytics collector.")
        Text("Android automatic app backup is disabled. Pay data leaves this app only when you explicitly export a password-protected backup or share a report.")
        TextButton(
            onClick = {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://linepaycheck.com/privacy#android")))
                }.onFailure { error = "No web browser could open the privacy policy. Visit linepaycheck.com/privacy." }
            },
            modifier = Modifier.testTag("settings.privacy-policy"),
        ) { Text("Read privacy policy") }

        SectionHeading("Device-local activity")
        androidx.compose.foundation.layout.Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Text("Record coarse usage counts", modifier = Modifier.weight(1f))
            Switch(
                checked = activity.recordingEnabled,
                onCheckedChange = { enabled ->
                    onSaveActivity(activity.copy(recordingEnabled = enabled))
                },
                modifier = Modifier.testTag("settings.activity-recording"),
            )
        }
        Text("Counts are stored separately from payroll data and are excluded from backups. No amounts, period dates, names, notes or documents are recorded.")
        activity.counts.toSortedMap().forEach { (event, count) -> Text("$event · $count") }
        activityError?.let { InlineMessage(it, isError = true) }
        OutlinedButton(
            onClick = {
                message = null
                error = null
                exportDiagnostics.launch("LinePaycheck-local-diagnostics.json")
            },
            modifier = Modifier.fillMaxWidth().testTag("settings.export-diagnostics"),
        ) { Text("Export local diagnostics") }
        TextButton(
            onClick = {
                onSaveActivity(activity.copy(counts = emptyMap()))
                message = "Local activity counts cleared. Pay data is unchanged."
            },
            modifier = Modifier.testTag("settings.clear-activity"),
        ) { Text("Clear local activity counts") }

        SectionHeading("Manual encrypted backup")
        Text("Backups contain pay data. Choose a private destination and keep the password separate; LinePaycheck does not save it.")
        OutlinedTextField(
            value = backupPassword,
            onValueChange = { backupPassword = it },
            label = { Text("New backup password (12 characters minimum)") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth().testTag("backup.password.create"),
        )
        Button(
            enabled = !busy,
            onClick = {
                busy = true
                error = null
                message = null
                val password = backupPassword
                scope.launch {
                    runCatching {
                        withContext(Dispatchers.IO) { stateStore.createEncryptedBackup(state, password) }
                    }.onSuccess { bytes ->
                        pendingExport = bytes
                        backupPassword = ""
                        exportBackup.launch("LinePaycheck-backup.lpb")
                    }.onFailure { error = it.message ?: "Encrypted backup could not be prepared." }
                    busy = false
                }
            },
            modifier = Modifier.fillMaxWidth().testTag("settings.export-backup"),
        ) { Text(if (busy) "Preparing…" else "Choose backup destination") }

        OutlinedTextField(
            value = restorePassword,
            onValueChange = { restorePassword = it },
            label = { Text("Backup password") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth().testTag("backup.password.restore"),
        )
        OutlinedButton(
            enabled = !busy,
            onClick = { selectBackup.launch(arrayOf("application/octet-stream", "*/*")) },
            modifier = Modifier.fillMaxWidth().testTag("settings.select-backup"),
        ) { Text("Select encrypted backup") }
        if (pendingImportBytes != null && restorePreview == null) {
            Button(
                enabled = !busy,
                onClick = {
                    busy = true
                    error = null
                    val bytes = pendingImportBytes ?: return@Button
                    val password = restorePassword
                    scope.launch {
                        runCatching {
                            withContext(Dispatchers.IO) {
                                stateStore.restoreEncryptedBackup(bytes, password)
                            }
                        }.onSuccess {
                            restorePreview = it
                            restorePassword = ""
                            message = null
                        }.onFailure {
                            error = it.message ?: "Backup could not be opened. No local data changed."
                        }
                        busy = false
                    }
                },
                modifier = Modifier.fillMaxWidth().testTag("settings.review-restore"),
            ) { Text("Review backup contents") }
        }
        restorePreview?.let { candidate ->
            val workLabel = if (candidate.work.size == 1) "work entry" else "work entries"
            val checkLabel = if (candidate.checks.size == 1) "saved check" else "saved checks"
            Text(
                "Selected backup: ${candidate.work.size} $workLabel and ${candidate.checks.size} $checkLabel. Local activity is not included."
            )
            Button(
                onClick = {
                    if (onSaveState(candidate)) {
                        pendingImportBytes?.fill(0)
                        pendingImportBytes = null
                        restorePreview = null
                        message = "The reviewed backup replaced local pay data."
                    }
                },
                modifier = Modifier.fillMaxWidth().testTag("settings.confirm-restore"),
            ) { Text("Replace local pay data") }
            TextButton(onClick = { restorePreview = null }) { Text("Cancel restore") }
        }

        error?.let { InlineMessage(it, isError = true) }
        saveError?.let { InlineMessage(it, isError = true) }
        message?.let { InlineMessage(it) }
    }

}

private fun writeDocument(context: Context, uri: Uri, bytes: ByteArray) {
    val output = requireNotNull(context.contentResolver.openOutputStream(uri, "wt")) {
        "The selected destination did not open for writing."
    }
    output.use { it.write(bytes) }
}

private fun readDocument(context: Context, uri: Uri): ByteArray {
    val input = requireNotNull(context.contentResolver.openInputStream(uri)) {
        "The selected file did not open for reading."
    }
    input.use { stream ->
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (true) {
            val count = stream.read(buffer)
            if (count < 0) break
            total += count
            require(total <= BackupEnvelope.MAXIMUM_BYTES) { "The selected backup is too large." }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }
}
