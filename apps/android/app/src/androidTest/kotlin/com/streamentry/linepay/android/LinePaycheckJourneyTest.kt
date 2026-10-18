package com.streamentry.linepay.android

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONObject

@RunWith(AndroidJUnit4::class)
class LinePaycheckJourneyTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Before
    fun resetSyntheticAppState() {
        InstrumentationRegistry.getInstrumentation().uiAutomation
            .executeShellCommand("rm -f /data/local/tmp/LinePaycheck-android-e2e-history.png")
            .close()
        compose.activity.runOnUiThread { compose.activity.resetLocalStateForUiTest() }
        compose.waitForIdle()
    }

    @Test
    fun confirmedWorkAndPaycheckRemainDeviceLocalAcrossActivityRelaunch() {
        enter("setup.hourly-rate", "25.00")
        enter("setup.period-start", "2026-10-12")
        enter("setup.time-zone", "UTC")
        compose.onNodeWithTag("setup.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()

        compose.onNodeWithTag("today.add-work").assertExists().performScrollTo().performClick()
        enter("shift.start", "2026-10-12 07:00")
        enter("shift.end", "2026-10-12 15:30")
        enter("shift.break-start", "2026-10-12 12:00")
        enter("shift.break-end", "2026-10-12 12:30")
        compose.onNodeWithTag("shift.note").performTextInput("Synthetic shift")
        compose.onNodeWithTag("shift.save").performScrollTo().performClick()
        compose.onNodeWithTag("today.expected-wages").assertTextContains("USD 200.00")

        compose.onNodeWithTag("nav.pay").performClick()
        compose.onNodeWithTag("pay.record-check").performScrollTo().performClick()
        enter("check.gross", "200.00")
        compose.onNodeWithTag("check.confirm-period").performScrollTo().performClick()
        compose.onNodeWithTag("check.complete-work").performScrollTo().performClick()
        compose.onNodeWithTag("check.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("check.weekly-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("check.save").performScrollTo().performClick()
        compose.onNodeWithText("Compared values match").assertExists()

        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithText("Compared values match").assertExists()
        compose.onNodeWithText("Confirmed gross: USD 200.00").assertExists()
        // The store is file-backed. Activity recreation reloads the persisted receipt and work.
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithText("Compared values match").assertExists()
        compose.onNodeWithText("Confirmed gross: USD 200.00").assertExists()
    }

    @Test
    fun encryptedManualBackupRoundTripsTheVersionedLocalState() {
        val profile = AndroidRuleProfile(
            hourlyRate = "25.00",
            cycleStartDate = "2026-10-12",
            payrollTimeZone = "UTC",
            rulesReviewedByWorker = true,
        )
        val state = LinePaycheckRepository.addWork(
            AndroidLocalState(profile = profile),
            "2026-10-12 07:00",
            "2026-10-12 15:30",
            "",
            "",
            "Synthetic backup record",
        )
        val store = LocalStateStore(compose.activity.filesDir)
        val fixture = InstrumentationRegistry.getInstrumentation().context.assets
            .open("encryption-v1.json").bufferedReader().use { JSONObject(it.readText()) }
        val passphrase = fixture.getString("uiPhraseASCII")

        val encrypted = store.createEncryptedBackup(state, passphrase)
        val restored = store.restoreEncryptedBackup(encrypted, passphrase)

        assertEquals(state, restored)
        assertTrue(com.streamentry.linepay.backup.BackupEnvelope.isEncrypted(encrypted))
        assertFalse(encrypted.contentEquals(store.encode(state)))
    }

    private fun enter(tag: String, value: String) {
        compose.onNodeWithTag(tag).performScrollTo().performTextClearance()
        compose.onNodeWithTag(tag).performTextInput(value)
    }

}
