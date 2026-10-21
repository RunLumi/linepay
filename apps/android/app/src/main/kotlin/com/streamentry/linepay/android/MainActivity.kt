package com.streamentry.linepay.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class MainActivity : ComponentActivity() {
    private lateinit var store: LocalStateStore
    private lateinit var activityStore: LocalActivityStore
    private var state by mutableStateOf(AndroidLocalState.empty())
    private var activity by mutableStateOf(AndroidLocalActivitySnapshot())
    private var loadError by mutableStateOf<String?>(null)
    private var saveError by mutableStateOf<String?>(null)
    private var activityError by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = LocalStateStore(filesDir)
        activityStore = LocalActivityStore(filesDir)
        runCatching { store.load() }
            .onSuccess { state = it }
            .onFailure {
                // Preserve the unreadable file so a future app version or manual recovery can
                // inspect it. A parse failure never silently replaces worker history with empty data.
                loadError = it.message ?: "Saved LinePaycheck data could not be opened."
            }
        runCatching { activityStore.snapshot() }
            .onSuccess { activity = it }
            .onFailure { activityError = it.message ?: "Local diagnostics could not be opened." }

        setContent {
            LinePaycheckTheme {
                LinePaycheckApp(
                    state = state,
                    activity = activity,
                    loadError = loadError,
                    saveError = saveError,
                    activityError = activityError,
                    onSaveState = ::saveState,
                    onSaveActivity = ::saveActivity,
                )
            }
        }
    }

    private fun saveState(next: AndroidLocalState): Boolean {
        val previous = state
        return try {
            store.save(next)
            state = next
            saveError = null
            val event = when {
                previous.profile == null && next.profile != null -> "profile-saved"
                next.work.size > previous.work.size -> "work-saved"
                next.checks.size > previous.checks.size -> "check-saved"
                next.weeklyReviews.size > previous.weeklyReviews.size -> "weekly-review-saved"
                else -> null
            }
            if (event != null) runCatching { activityStore.record(event) }
                .onSuccess { activity = it }
                .onFailure { activityError = it.message ?: "Local activity could not be saved." }
            true
        } catch (failure: Throwable) {
            saveError = failure.message ?: "The change could not be saved. Existing data is unchanged."
            false
        }
    }

    private fun saveActivity(next: AndroidLocalActivitySnapshot): Boolean {
        return runCatching {
            activity = activityStore.setRecordingEnabled(next.recordingEnabled)
            if (next.counts.isEmpty()) activity = activityStore.clearCounts()
            activityError = null
        }.fold(
            onSuccess = { true },
            onFailure = {
                activityError = it.message ?: "The local activity change could not be saved."
                false
            },
        )
    }

    /** Synthetic device-test reset; never exposed through the production interface. */
    internal fun resetLocalStateForUiTest() {
        check(BuildConfig.DEBUG) { "Test reset is only available in debug builds." }
        store.clearForUiTest()
        activityStore.clearForUiTest()
        state = AndroidLocalState.empty()
        activity = activityStore.snapshot()
        loadError = null
        saveError = null
        activityError = null
    }
}
