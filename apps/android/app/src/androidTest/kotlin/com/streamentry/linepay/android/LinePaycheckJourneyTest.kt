package com.streamentry.linepay.android

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
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
            .executeShellCommand("rm -f /data/local/tmp/LinePaycheck-android-e2e-history.png /data/local/tmp/LinePaycheck-weekly-review-history.png")
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
        compose.onNodeWithText("A pay period could not be calculated from the saved rules.")
            .assertDoesNotExist()
        compose.onNodeWithTag("pay.record-check").performScrollTo().performClick()
        enter("check.gross", "200.00")
        compose.onNodeWithTag("check.confirm-period").performScrollTo().performClick()
        compose.onNodeWithTag("check.complete-work").performScrollTo().performClick()
        compose.onNodeWithTag("check.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("check.weekly-reviewed").assertDoesNotExist()
        compose.onNodeWithTag("check.save").performScrollTo().performClick()
        compose.onNodeWithText("Needs review").assertExists()

        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithText("Needs review").assertExists()
        compose.onNodeWithText("Confirmed gross: USD 200.00").assertExists()
        compose.onNodeWithText("Needs review: weekly-rate review is pending").assertExists()
        // The store is file-backed. Activity recreation reloads the persisted receipt and work.
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithText("Needs review").assertExists()
        compose.onNodeWithText("Confirmed gross: USD 200.00").assertExists()
        compose.onNodeWithText("Needs review: weekly-rate review is pending").assertExists()
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

    @Test
    fun crossPeriodWeeklyReceiptSavesReopensAndKeepsPaycheckReviewPending() {
        val profile = AndroidRuleProfile(
            hourlyRate = "25.00",
            cycleStartDate = "2026-10-12",
            payrollTimeZone = "UTC",
            rulesReviewedByWorker = true,
        )
        var prepared = AndroidLocalState(profile = profile)
        for (date in listOf("2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22")) {
            prepared = LinePaycheckRepository.addWork(
                prepared,
                "$date 07:00",
                "$date 15:00",
                "",
                "",
                "Synthetic cross-period work",
            )
        }
        val firstInput = e2ePaycheckInput("2026-10-12", "2026-10-18", "400.00")
        val (withFirst, first) = LinePaycheckRepository.savePaycheck(prepared, firstInput, createdAtEpochSeconds = 20)
        val nextProfile = profile.copy(
            id = java.util.UUID.randomUUID().toString(),
            cycleStartDate = "2026-10-19",
            version = "2",
        )
        prepared = withFirst.copy(profile = nextProfile)
        val secondInput = e2ePaycheckInput("2026-10-19", "2026-10-25", "800.00")
        val (withSecond, second) = LinePaycheckRepository.savePaycheck(prepared, secondInput, createdAtEpochSeconds = 21)
        prepared = withSecond
        assertEquals("NEEDS_REVIEW", first.verdict)
        assertEquals("NEEDS_REVIEW", second.verdict)

        val store = LocalStateStore(compose.activity.filesDir)
        store.save(prepared)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        val retained = store.load()
        assertEquals(2, retained.checks.size)

        compose.onNodeWithTag("nav.pay").performClick()
        compose.onNodeWithTag("pay.weekly-review").performScrollTo().performClick()
        enter("weekly.start", "2026-10-17 00:00")
        enter("weekly.wages", "1200.00")
        for (check in listOf(first, second)) {
            compose.onNodeWithTag("weekly.source.${check.id}").performScrollTo().performClick()
        }
        for (tag in listOf(
            "weekly.confirm-boundary",
            "weekly.confirm-employer",
            "weekly.confirm-work",
            "weekly.confirm-payments",
            "weekly.confirm-applicability",
        )) {
            compose.onNodeWithTag(tag).performScrollTo().performClick()
        }
        compose.onNodeWithTag("weekly.preview").performScrollTo().performClick()
        compose.onNodeWithText("Additional premium reference: USD 100.00").performScrollTo().assertExists()
        compose.onNodeWithText("Separate reference total: USD 1300.00").performScrollTo().assertExists()
        compose.onNodeWithTag("weekly.save").performScrollTo().performClick()

        val saved = store.load()
        assertEquals(1, saved.weeklyReviews.size)
        assertEquals("NEEDS_REVIEW", saved.checks.single { it.id == first.id }.verdict)
        assertEquals("NEEDS_REVIEW", saved.checks.single { it.id == second.id }.verdict)
        assertEquals(2, saved.weeklyReviews.single().source.periods.size)
        assertEquals(
            saved.weeklyReviews.single().source.workContainingPeriodIds,
            saved.weeklyReviews.single().source.periods.map { it.periodId },
        )
        val fixture = InstrumentationRegistry.getInstrumentation().context.assets
            .open("encryption-v1.json").bufferedReader().use { JSONObject(it.readText()) }
        val protectedBackup = store.createEncryptedBackup(saved, fixture.getString("uiPhraseASCII"))
        assertEquals(saved, store.restoreEncryptedBackup(protectedBackup, fixture.getString("uiPhraseASCII")))
        compose.onNodeWithText("Weekly review receipts").assertExists()
        compose.onAllNodesWithText("Open weekly review · additional premium USD 100.00").assertCountEquals(2)

        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithText("Weekly review receipts").assertExists()
        compose.onNodeWithText("2026-10-17 · additional premium reference USD 100.00").assertExists()
        compose.onAllNodesWithText("Needs review: weekly-rate review is pending").assertCountEquals(2)
        val receiptId = saved.weeklyReviews.single().id
        compose.onNodeWithTag("history.weekly-receipt.$receiptId").performScrollTo().performClick()
        compose.onNodeWithTag("weekly-receipt.detail-title").assertTextContains("Weekly review receipt")
        compose.onNodeWithTag("weekly-receipt.additional-premium")
            .assertTextContains("Additional premium reference: USD 100.00")
        compose.onNodeWithText("2026-10-12 – 2026-10-18 · rule 1 · 2 recorded work entries").assertExists()
        compose.onNodeWithTag("navigation.back").performClick()
        compose.onNodeWithTag("history.check." + first.id + ".weekly-receipt." + receiptId)
            .performScrollTo().performClick()
        compose.onNodeWithTag("weekly-receipt.detail-title").assertExists()
        compose.onNodeWithTag("navigation.back").performClick()
        InstrumentationRegistry.getInstrumentation().uiAutomation
            .executeShellCommand("screencap -p /data/local/tmp/LinePaycheck-weekly-review-history.png")
            .close()
    }

    @Test
    fun employerContributionReviewSavesSeparateEvidenceAndSurvivesRelaunchAndBackup() {
        enter("setup.hourly-rate", "25.00")
        enter("setup.period-start", "2026-10-12")
        enter("setup.time-zone", "UTC")
        compose.onNodeWithTag("setup.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()
        compose.onNodeWithTag("nav.settings").performClick()
        compose.onNodeWithTag("settings.benefits").performScrollTo().performClick()
        enter("benefit.fund", "Synthetic employer fund A")
        enter("benefit.fund-id", "Synthetic fund plan A-001")
        enter("benefit.period.end", "2026-10-19")
        enter("benefit.segment.0.period.end", "2026-10-19")
        enter("benefit.segment.0.rate", "2.50")
        enter("benefit.segment.0.quantity", "40")
        enter("benefit.segment.0.version", "Synthetic 2026-10")
        enter("benefit.segment.0.effective.end", "2026-10-19")
        enter("benefit.segment.0.title", "Synthetic contribution schedule")
        enter("benefit.segment.0.reference", "Section 2 page 3")
        enter("benefit.segment.0.evidence", "40 eligible hours from synthetic work log")
        compose.onNodeWithTag("benefit.segment.0.confirm").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.complete").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.statement.enabled").performScrollTo().performClick()
        enter("benefit.statement.fund-id", "Synthetic fund plan A-001")
        enter("benefit.statement.amount", "95")
        enter("benefit.statement.reference", "Synthetic statement page 1")
        compose.onNodeWithTag("benefit.statement.confirm").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.preview").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.expected").assertTextContains("USD 100.00")
        compose.onNodeWithText("Expected minus statement: USD 5.00").assertExists()
        compose.onNodeWithTag("benefit.save").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.receipt.title").assertExists()
        compose.onNodeWithText("Possible difference").assertExists()
        val store = LocalStateStore(compose.activity.filesDir)
        val saved = store.load()
        assertEquals(1, saved.benefitReviews.size)
        assertTrue(saved.work.isEmpty())
        assertTrue(saved.checks.isEmpty())
        assertTrue(saved.weeklyReviews.isEmpty())
        val encrypted = store.createEncryptedBackup(saved, "Synthetic benefit backup password")
        assertEquals(saved, store.restoreEncryptedBackup(encrypted, "Synthetic benefit backup password"))
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("benefit.receipt.title").assertExists()
        compose.onNodeWithTag("navigation.back").performClick()
        compose.onNodeWithTag("nav.history").performClick()
        val id = saved.benefitReviews.single().id
        compose.onNodeWithTag("benefit.history.$id").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.receipt.title").assertExists()
        compose.onNodeWithText("Possible difference").assertExists()
        compose.onNodeWithTag("benefit.revise").performScrollTo().performClick()
        enter("benefit.statement.amount", "100")
        compose.onNodeWithTag("benefit.segment.0.confirm").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.complete").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.statement.confirm").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.preview").performScrollTo().performClick()
        compose.onNodeWithTag("benefit.save").performScrollTo().performClick()
        compose.onNodeWithText("Compared values match").assertExists()
        val revised = store.load()
        assertEquals(2, revised.benefitReviews.size)
        assertEquals(saved.benefitReviews.single(), revised.benefitReviews.first())
        assertEquals(id, revised.benefitReviews.last().revisesReceiptId)
    }

    private fun enter(tag: String, value: String) {
        compose.onNodeWithTag(tag).performScrollTo().performTextClearance()
        compose.onNodeWithTag(tag).performTextInput(value)
    }

    private fun e2ePaycheckInput(start: String, last: String, gross: String) = AndroidPaycheckInput(
        sourceStartDate = start,
        sourceLastDate = last,
        sourceTimeZone = "UTC",
        sourcePeriodConfirmed = true,
        paidGross = gross,
        basis = GrossBasisChoice.WAGES_ONLY,
        completeWorkConfirmed = true,
        ruleCoverageConfirmed = true,
    )

}
