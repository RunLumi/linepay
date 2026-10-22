package com.streamentry.linepay.android

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onAllNodesWithTag
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

    @Test
    fun portableSourceReceiptStaysFrozenThroughGuardedAdoptionRelaunchAndEncryptedReexport() {
        var source = AndroidLocalState(profile = AndroidRuleProfile(
            hourlyRate = "25.00", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true,
        ))
        for (day in 12..16) source = LinePaycheckRepository.addWork(source, "2026-10-$day 07:00", "2026-10-$day 15:00", "", "", "Synthetic portable shift")
        source = LinePaycheckRepository.savePaycheck(source, e2ePaycheckInput("2026-10-12", "2026-10-18", "1000.00"), 1792195200).first
        val document = PortableStateJson.parse(AndroidPortableStateCodec.encode(source, 1792195200))
        val sourceRule = document.getAsJsonArray("ruleSnapshots").single().asJsonObject
        sourceRule.add("rounding", com.google.gson.JsonNull.INSTANCE)
        sourceRule.getAsJsonArray("fieldsNotRecorded").add("rounding")
        document.getAsJsonArray("workSnapshots").first { it.asJsonObject.get("role").asString == "currentLedger" }.asJsonObject
            .getAsJsonArray("work").first().asJsonObject.addProperty("kind", "callout")
        val password = "Synthetic portable backup password"
        val envelope = com.streamentry.linepay.backup.BackupEnvelope.seal(document.toString().toByteArray(), password)
        val store = LocalStateStore(compose.activity.filesDir)
        val before = store.load()
        val candidate = store.restoreEncryptedBackup(envelope, password)
        assertEquals(before, store.load()) // Opening and validating a backup is not replacement consent.
        assertTrue(candidate.profile!!.requiresPortableRuleConfirmation)
        assertEquals(5, candidate.work.size)
        store.save(candidate)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("portable.adoption-required").assertExists()
        compose.onNodeWithTag("nav.history").performClick()
        val receiptID = document.getAsJsonArray("paycheckReceipts").single().asJsonObject.get("id").asString
        compose.onNodeWithTag("portable.history.$receiptID").performScrollTo().performClick()
        compose.onNodeWithTag("portable.receipt.title").assertExists()
        compose.onNodeWithText("Needs review").assertExists()
        compose.onNodeWithText("Weekly-rate review is pending.").assertExists()
        captureSyntheticScreen("LinePaycheck-portable-receipt.png")
        compose.onNodeWithTag("navigation.back").performClick()
        compose.onNodeWithTag("nav.today").performClick()
        compose.onNodeWithTag("portable.review-adoption").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()
        assertTrue(store.load().profile!!.requiresPortableRuleConfirmation)
        compose.onNodeWithTag("navigation.back").performClick() // Cancel leaves original rules and receipts intact.
        assertEquals(candidate, store.load())
        compose.onNodeWithTag("portable.review-adoption").performScrollTo().performClick()
        compose.onNodeWithTag("setup.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("setup.confirm-effective-bounds").performScrollTo().performClick()
        compose.onNodeWithTag("setup.confirm-rounding").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()
        assertTrue(store.load().profile!!.requiresPortableRuleConfirmation) // Rules alone cannot reinterpret source callout work.
        compose.onNodeWithTag("setup.new-work-ledger").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()
        val adopted = store.load()
        assertFalse(adopted.profile!!.requiresPortableRuleConfirmation)
        assertTrue(adopted.work.isEmpty())
        assertTrue(adopted.profile.id != candidate.profile.id)
        assertEquals(document, adopted.portableArchive!!.document)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("today.add-work").assertExists()
        val reexported = store.createPortableEncryptedBackup(adopted, password)
        val reopened = store.restoreEncryptedBackup(reexported, password)
        assertFalse(reopened.profile!!.requiresPortableRuleConfirmation)
        val retained = reopened.portableArchive!!.document
        assertEquals(document.get("paycheckReceipts"), retained.get("paycheckReceipts"))
        assertEquals(1, retained.getAsJsonArray("adoptions").size())
        assertTrue(retained.getAsJsonArray("ruleSnapshots").single { it.asJsonObject.get("id") == sourceRule.get("id") }.asJsonObject.get("rounding").isJsonNull)
        val fullAndroidBackup = store.createEncryptedBackup(adopted, password)
        assertEquals(adopted, store.restoreEncryptedBackup(fullAndroidBackup, password))
    }

    @Test
    fun unprojectableSourceRemainsReadableUntilSeparateNativeRulesAreConfirmed() {
        var source = AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true))
        source = LinePaycheckRepository.addWork(source, "2026-10-12 07:00", "2026-10-12 15:00", "", "", "Synthetic precision source")
        source = LinePaycheckRepository.savePaycheck(source, e2ePaycheckInput("2026-10-12", "2026-10-18", "200"), 1792195200).first
        val original = PortableStateJson.parse(AndroidPortableStateCodec.encode(source, 1792195200))
        original.getAsJsonArray("ruleSnapshots").single().asJsonObject.addProperty("hourlyRate", "0.12345678901234567890123456789012345678901234567890")
        val store = LocalStateStore(compose.activity.filesDir)
        val retained = AndroidPortableStateCodec.decode(original.toString().toByteArray())
        assertEquals(null, retained.profile)
        store.save(retained)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("portable.unprojected-source").assertExists()
        compose.onNodeWithTag("nav.history").performClick()
        val receiptID = original.getAsJsonArray("paycheckReceipts").single().asJsonObject.get("id").asString
        compose.onNodeWithTag("portable.history.$receiptID").performScrollTo().performClick()
        compose.onNodeWithTag("portable.receipt.title").assertExists()
        compose.onNodeWithTag("navigation.back").performClick()
        compose.onNodeWithTag("nav.today").performClick()
        compose.onNodeWithTag("portable.review-adoption").performScrollTo().performClick()
        compose.onNodeWithTag("navigation.back").performClick()
        assertEquals(retained, store.load())
        compose.onNodeWithTag("portable.review-adoption").performScrollTo().performClick()
        enter("setup.hourly-rate", "25")
        enter("setup.period-start", "2026-10-12")
        enter("setup.time-zone", "UTC")
        compose.onNodeWithTag("setup.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("setup.confirm-effective-bounds").performScrollTo().performClick()
        compose.onNodeWithTag("setup.confirm-rounding").performScrollTo().performClick()
        compose.onNodeWithTag("setup.new-work-ledger").performScrollTo().performClick()
        compose.onNodeWithTag("setup.save").performScrollTo().performClick()
        assertTrue(store.load().profile != null)
        assertTrue(store.load().work.isEmpty())
        assertEquals(original, store.load().portableArchive!!.document)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("today.add-work").assertExists()
    }

    @Test
    fun backupReplacementPreservesEnabledDestinationActivityOnSuccessAndFailure() {
        val activityStore = LocalActivityStore(compose.activity.filesDir)
        activityStore.setRecordingEnabled(true)
        activityStore.record("work-saved")
        val originalActivity = activityStore.snapshot()
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        val source = AndroidLocalState(profile = AndroidRuleProfile(
            hourlyRate = "25", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true,
        ))
        val store = LocalStateStore(compose.activity.filesDir)
        val encrypted = store.createPortableEncryptedBackup(source, "Synthetic activity preservation password")
        val candidate = store.restoreEncryptedBackup(encrypted, "Synthetic activity preservation password")
        assertEquals(AndroidLocalState.empty(), store.load())
        compose.activity.runOnUiThread { assertTrue(compose.activity.replacePayData(candidate)) }
        compose.waitForIdle()
        assertEquals(candidate, store.load())
        assertEquals(originalActivity, activityStore.snapshot())
        val invalid = candidate.copy(work = listOf(AndroidWorkEntry(startEpochSeconds = 10, endEpochSeconds = 9, timeZone = "UTC")))
        compose.activity.runOnUiThread { assertFalse(compose.activity.replacePayData(invalid)) }
        compose.waitForIdle()
        assertEquals(candidate, store.load())
        assertEquals(originalActivity, activityStore.snapshot())
    }

    @Test
    fun portableBackupUsesRealSystemFilesAndRetainsEncryptedArtifact() {
        var source = AndroidLocalState(profile = AndroidRuleProfile(
            hourlyRate = "25.00", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true,
        ))
        for (day in 12..16) source = LinePaycheckRepository.addWork(source, "2026-10-$day 07:00", "2026-10-$day 15:00", "", "", "Synthetic SAF shift")
        source = LinePaycheckRepository.savePaycheck(source, e2ePaycheckInput("2026-10-12", "2026-10-18", "1000.00"), 1792195200).first
        LocalStateStore(compose.activity.filesDir).save(source)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("nav.settings").performClick()
        enter("backup.password.create", "Synthetic portable backup password")
        compose.onNodeWithTag("settings.export-portable").performScrollTo().performClick()
        compose.waitForIdle()
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        compose.waitUntil(30_000) { automation.rootInActiveWindow?.packageName?.toString()?.contains("documentsui") == true }
        systemNode { it.packageName?.toString()?.contains("documentsui") == true }
        runCatching { clickSystemNode { it.contentDescription?.toString() in listOf("Show roots", "Open navigation drawer") } }
        clickSystemNode { it.text?.toString() == "Downloads" }
        val filename = "LinePaycheck-portable-android-e2e-${java.util.UUID.randomUUID()}.lpb"
        val editor = systemNode { it.className?.toString() == "android.widget.EditText" }
        assertTrue(editor.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_SET_TEXT, android.os.Bundle().apply {
            putCharSequence(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, filename)
        }))
        clickSystemNode { it.text?.toString()?.equals("Save", ignoreCase = true) == true }
        compose.waitUntil(15_000) { compose.onAllNodesWithText("Encrypted backup saved to the destination you chose.").fetchSemanticsNodes().isNotEmpty() }
        captureSyntheticScreen("LinePaycheck-portable-saf-success.png")
        val encrypted = java.io.FileInputStream(automation.executeShellCommand("cat /sdcard/Download/$filename").fileDescriptor).use { it.readBytes() }
        assertTrue(com.streamentry.linepay.backup.BackupEnvelope.isEncrypted(encrypted))
        val restored = LocalStateStore(compose.activity.filesDir).restoreEncryptedBackup(encrypted, "Synthetic portable backup password")
        assertEquals(5, restored.work.size)
        val receipt = restored.portableArchive!!.document.getAsJsonArray("paycheckReceipts").single().asJsonObject
        assertTrue(receipt.getAsJsonObject("reviewFacts").get("weeklyReviewPending").asBoolean)
        java.io.File(compose.activity.filesDir, "portable-saf-artifact.lpb").writeBytes(encrypted)
        java.io.File(compose.activity.filesDir, "portable-saf-filename.txt").writeText(filename)
        automation.executeShellCommand("rm -f /data/local/tmp/LinePaycheck-portable-saf-artifact.lpb").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
        automation.executeShellCommand("cp /sdcard/Download/$filename /data/local/tmp/LinePaycheck-portable-saf-artifact.lpb").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
        val retained = java.io.FileInputStream(automation.executeShellCommand("cat /data/local/tmp/LinePaycheck-portable-saf-artifact.lpb").fileDescriptor).use { it.readBytes() }
        assertTrue("The retained artifact must be the exact SAF-created ciphertext", encrypted.contentEquals(retained))
    }

    @Test
    @androidx.test.filters.SdkSuppress(minSdkVersion = 29)
    fun actualWebProviderImportsThroughFilesKeepsWarningsAndExportsThroughSaf() = runActualProviderFilesRoundTrip(
        "webkit-a647-provider.linepaybackup", "a6471ac98584da3031ae752842bfeb6e3994cd63cb4580ad46319883f8a7ad87",
        "Synthetic portable password 2026", "web", "A separate complete-workweek review is pending.",
    )

    @Test
    @androidx.test.filters.SdkSuppress(minSdkVersion = 29)
    fun actualIosProviderImportsThroughFilesKeepsUnknownReferencesAndExportsThroughSaf() = runActualProviderFilesRoundTrip(
        "ios-66a3-provider.linepaybackup", "66a3d984b0c526ef3790fef9dfd12f40981930c1c900536845107e3f8e8b9ccd",
        "synthetic portable passphrase 2026", "ios", "An agreement rule is not represented. The expected amount may be incomplete.",
    )

    @androidx.annotation.RequiresApi(29)
    private fun runActualProviderFilesRoundTrip(assetName: String, expectedSHA: String, password: String, sourceClient: String, sourceWarning: String) {
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        val provider = InstrumentationRegistry.getInstrumentation().context.assets.open("portable/$assetName").use { it.readBytes() }
        assertEquals(expectedSHA, java.security.MessageDigest.getInstance("SHA-256").digest(provider).joinToString("") { "%02x".format(it) })
        val providerName = "LinePaycheck-$sourceClient-${expectedSHA.take(8)}-${java.util.UUID.randomUUID()}.linepaybackup"
        val resolver = compose.activity.contentResolver
        val staged = requireNotNull(resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, android.content.ContentValues().apply {
            put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, providerName)
            put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
            put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_DOWNLOADS)
        }))
        requireNotNull(resolver.openOutputStream(staged)).use { it.write(provider) } // Stage the exact captured provider download; never reseal a fixture.
        val original = PortableStateJson.parse(com.streamentry.linepay.backup.BackupEnvelope.open(provider, password))
        val destination = AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "32", cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true))
        val store = LocalStateStore(compose.activity.filesDir)
        store.save(destination)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("nav.settings").performClick()
        compose.onNodeWithTag("settings.select-backup").performScrollTo().performClick()
        compose.waitForIdle()
        compose.waitUntil(30_000) { automation.rootInActiveWindow?.packageName?.toString()?.contains("documentsui") == true }
        runCatching { clickSystemNode { it.contentDescription?.toString() in listOf("Show roots", "Open navigation drawer") } }
        clickSystemNode { it.text?.toString() == "Downloads" }
        clickSystemNode { it.text?.toString() == providerName }
        compose.waitForIdle()
        compose.waitUntil(30_000) { compose.onAllNodesWithText("Review backup contents").fetchSemanticsNodes().isNotEmpty() }
        enter("backup.password.restore", password)
        compose.onNodeWithTag("settings.review-restore").performScrollTo().performClick()
        compose.waitUntil(30_000) { compose.onAllNodesWithText("Replace local pay data").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(destination, store.load())
        compose.onNodeWithTag("settings.confirm-restore").performScrollTo().performClick()
        assertEquals(original.getAsJsonArray("paycheckReceipts").size(), store.load().portableArchive!!.document.getAsJsonArray("paycheckReceipts").size())
        assertEquals(null, store.load().profile)
        compose.onNodeWithText("Original imported rules remain read-only. No native pay rules are active.").assertExists()
        compose.onNodeWithTag("settings.benefits").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithTag("nav.history").performClick()
        val sourceReceipt = original.getAsJsonArray("paycheckReceipts").single { it.asJsonObject.getAsJsonObject("producer").get("client").asString == sourceClient }.asJsonObject
        compose.onNodeWithTag("portable.history.${sourceReceipt.get("id").asString}").performScrollTo().performClick()
        compose.onNodeWithText(sourceWarning).performScrollTo().assertExists()
        captureSyntheticScreen("LinePaycheck-$sourceClient-imported-receipt.png")
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("portable.receipt.title").assertExists()
        compose.onNodeWithText(sourceWarning).assertExists()
        compose.onNodeWithTag("navigation.back").performClick()
        compose.onNodeWithTag("nav.settings").performClick()
        enter("backup.password.create", "Synthetic portable backup password")
        compose.onNodeWithTag("settings.export-portable").performScrollTo().performClick()
        compose.waitForIdle()
        compose.waitUntil(30_000) { automation.rootInActiveWindow?.packageName?.toString()?.contains("documentsui") == true }
        runCatching { clickSystemNode { it.contentDescription?.toString() in listOf("Show roots", "Open navigation drawer") } }
        clickSystemNode { it.text?.toString() == "Downloads" }
        val filename = "LinePaycheck-$sourceClient-to-Android-${java.util.UUID.randomUUID()}.lpb"
        assertTrue(systemNode { it.className?.toString() == "android.widget.EditText" }.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_SET_TEXT, android.os.Bundle().apply {
            putCharSequence(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, filename)
        }))
        clickSystemNode { it.text?.toString()?.equals("Save", ignoreCase = true) == true }
        compose.waitUntil(30_000) { compose.onAllNodesWithText("Encrypted backup saved to the destination you chose.").fetchSemanticsNodes().isNotEmpty() }
        val actual = java.io.FileInputStream(automation.executeShellCommand("cat /sdcard/Download/$filename").fileDescriptor).use { it.readBytes() }
        val reexported = store.restoreEncryptedBackup(actual, "Synthetic portable backup password").portableArchive!!.document
        for (field in listOf("profiles", "ruleSnapshots", "periods", "workSnapshots", "paycheckReceipts")) assertEquals(original.get(field), reexported.get(field))
        for ((from, to) in listOf(providerName to "LinePaycheck-$sourceClient-provider-input.lpb", filename to "LinePaycheck-$sourceClient-android-saf.lpb")) {
            automation.executeShellCommand("rm -f /data/local/tmp/$to").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
            automation.executeShellCommand("cp /sdcard/Download/$from /data/local/tmp/$to").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
            val copied = java.io.FileInputStream(automation.executeShellCommand("cat /data/local/tmp/$to").fileDescriptor).use { it.readBytes() }
            assertTrue(copied.contentEquals(if (from == providerName) provider else actual))
        }
        resolver.delete(staged, null, null)
    }

    @Test
    fun sharedRefusalsPreservePayDataAndEnabledActivityThroughEncryptedRestore() {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        val cases = com.google.gson.JsonParser.parseString(assets.open("refusal-cases-v1.json").bufferedReader().use { it.readText() }).asJsonObject.getAsJsonArray("cases")
        val store = LocalStateStore(compose.activity.filesDir)
        val ledger = LocalActivityStore(compose.activity.filesDir)
        ledger.setRecordingEnabled(true)
        ledger.record("work-saved")
        val beforeActivity = ledger.snapshot()
        val beforeState = store.load()
        var checked = 0
        for (encodedCase in cases) {
            val case = encodedCase.asJsonObject
            if (case.has("target") && case.get("target").asString != "android") continue
            val filename = case.get("baseFixture")?.asString ?: "common-weekly-pending.json"
            val root = com.google.gson.JsonParser.parseString(assets.open(filename).bufferedReader().use { it.readText() }).asJsonObject
            for (encodedOperation in case.getAsJsonArray("operations")) {
                val operation = encodedOperation.asJsonObject
                val parts = operation.get("path").asString.removePrefix("/").split('/').map { it.replace("~1", "/").replace("~0", "~") }
                var parent: com.google.gson.JsonElement = root
                parts.dropLast(1).forEach { key -> parent = if (parent.isJsonArray) parent.asJsonArray[key.toInt()] else parent.asJsonObject.get(key) }
                val key = parts.last()
                if (operation.get("op").asString == "remove") {
                    if (parent.isJsonArray) parent.asJsonArray.remove(key.toInt()) else parent.asJsonObject.remove(key)
                } else if (parent.isJsonArray && key == "-" && operation.get("op").asString == "add") parent.asJsonArray.add(operation.get("value").deepCopy())
                else if (parent.isJsonArray) parent.asJsonArray.set(key.toInt(), operation.get("value").deepCopy())
                else parent.asJsonObject.add(key, operation.get("value").deepCopy())
            }
            val encrypted = com.streamentry.linepay.backup.BackupEnvelope.seal(root.toString().toByteArray(), "Synthetic refusal password")
            val result = runCatching { store.restoreEncryptedBackup(encrypted, "Synthetic refusal password") }
            if (case.get("activationReview")?.asBoolean == true) {
                assertTrue(result.getOrThrow().profile!!.requiresPortableRuleConfirmation)
                assertTrue(runCatching { LinePaycheckRepository.currentPeriod(result.getOrThrow()) }.isFailure)
            } else assertTrue(case.get("id").asString, result.isFailure)
            assertEquals(beforeState, store.load())
            assertEquals(beforeActivity, ledger.snapshot())
            checked++
        }
        assertEquals(cases.count { !it.asJsonObject.has("target") || it.asJsonObject.get("target").asString == "android" }, checked)
    }

    @Test
    fun confirmedPaycheckLinesKeepOffsetsUnknownsAndMismatchedPeriodThroughHistoryAndBackup() {
        var source = AndroidLocalState(profile = AndroidRuleProfile(hourlyRate = "50", dailyOvertimeAfterHours = "8", dailyOvertimeMultiplier = "1.5",
            cycleStartDate = "2026-10-12", payrollTimeZone = "UTC", rulesReviewedByWorker = true))
        source = LinePaycheckRepository.addWork(source, "2026-10-12 08:00", "2026-10-12 18:00", "", "", "Synthetic confirmed-line work")
        val store = LocalStateStore(compose.activity.filesDir)
        store.save(source)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        enterLineStatement("350.00", "200.00", "2026-10-12", "2026-10-18")
        val offset = store.load().checks.first()
        assertEquals("NEEDS_REVIEW", offset.verdict)
        assertEquals("350.00", offset.confirmedLineFacts!!.regularPay)
        assertTrue("WEEKLY_REVIEW_PENDING" in offset.reviewReasons)
        assertEquals(0, java.math.BigDecimal(requireNotNull(offset.difference)).signum())
        assertEquals(0, java.math.BigDecimal("50").compareTo(java.math.BigDecimal(offset.comparisons.single { it.field == "REGULAR_PAY" }.difference)))
        assertEquals(0, java.math.BigDecimal("-50").compareTo(java.math.BigDecimal(offset.comparisons.single { it.field == "OVERTIME_PAY" }.difference)))
        compose.onNodeWithTag("nav.history").performClick()
        compose.onNodeWithTag("history.check.${offset.id}.lines").performScrollTo().performClick()
        compose.onNodeWithTag("history.check.${offset.id}.comparison.REGULAR_PAY").performScrollTo().assertTextContains("expected minus source 50.00 USD", substring = true)
        compose.onNodeWithTag("history.check.${offset.id}.comparison.OVERTIME_PAY").performScrollTo().assertTextContains("expected minus source -50.00 USD", substring = true)
        captureSyntheticScreen("LinePaycheck-confirmed-lines-offset.png")
        enterLineStatement("400", null, "2026-10-12", "2026-10-18")
        val incomplete = store.load().checks.first()
        assertEquals(null, incomplete.confirmedLineFacts!!.overtimePay)
        assertFalse(incomplete.comparisons.any { it.field == "OVERTIME_PAY" })
        assertTrue("CONFLICTING_EARNINGS" in incomplete.reviewReasons)
        enterLineStatement("350", "200", "2026-10-13", "2026-10-19")
        val mismatch = store.load().checks.first()
        assertEquals("NOT_COMPARABLE", mismatch.verdict)
        assertEquals(null, mismatch.expectedGross)
        assertTrue(mismatch.comparisons.isEmpty())
        assertEquals("350", mismatch.confirmedLineFacts!!.regularPay)
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        assertEquals(listOf(mismatch, incomplete, offset), store.load().checks)
        compose.onNodeWithTag("nav.history").performClick()
        if (compose.onAllNodesWithTag("history.check.${offset.id}.comparison.REGULAR_PAY").fetchSemanticsNodes().isEmpty()) {
            compose.onNodeWithTag("history.check.${offset.id}.lines").performScrollTo().performClick()
        }
        compose.onNodeWithTag("history.check.${offset.id}.comparison.REGULAR_PAY").performScrollTo().assertTextContains("source 350 USD", substring = true)
        val reopened = store.restoreEncryptedBackup(store.createEncryptedBackup(store.load(), "Synthetic confirmed lines password"), "Synthetic confirmed lines password")
        assertEquals(store.load(), reopened)
        val portable = store.restoreEncryptedBackup(store.createPortableEncryptedBackup(store.load(), "Synthetic confirmed lines password"), "Synthetic confirmed lines password")
        assertEquals(3, portable.portableArchive!!.document.getAsJsonArray("paycheckReceipts").size())
        val original = portable.portableArchive.document.getAsJsonArray("paycheckReceipts").single { it.asJsonObject.getAsJsonObject("paystubFacts").get("regularPay").takeUnless { value -> value.isJsonNull }?.asString == "350.00" }.asJsonObject
        assertEquals("confirmedLines", original.getAsJsonObject("assessment").get("scope").asString)
        assertTrue(original.getAsJsonObject("reviewFacts").get("weeklyReviewPending").asBoolean)
    }

    private fun enterLineStatement(regular: String, overtime: String?, first: String, last: String) {
        compose.onNodeWithTag("nav.pay").performClick()
        compose.onNodeWithTag("pay.record-check").performScrollTo().performClick()
        enter("check.period-start", first); enter("check.period-end", last)
        enter("check.currency", "USD"); enter("check.gross", "550")
        compose.onNodeWithTag("check.show-lines").performScrollTo().performClick()
        compose.onNodeWithTag("check.layout.FULL_RATE_BUCKETS").performScrollTo().performClick()
        compose.onNodeWithTag("check.hours-basis.ACTUAL_WORK").performScrollTo().performClick()
        enter("check.line.regular-pay", regular)
        if (overtime != null) enter("check.line.overtime-pay", overtime) else compose.onNodeWithTag("check.line.overtime-pay").performScrollTo().performTextClearance()
        compose.onNodeWithTag("check.complete-lines").performScrollTo().performClick()
        compose.onNodeWithTag("check.confirm-period").performScrollTo().performClick()
        compose.onNodeWithTag("check.complete-work").performScrollTo().performClick()
        compose.onNodeWithTag("check.rules-reviewed").performScrollTo().performClick()
        compose.onNodeWithTag("check.save").performScrollTo().performClick()
        compose.waitForIdle()
    }

    private fun captureSyntheticScreen(filename: String) {
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        automation.executeShellCommand("rm -f /data/local/tmp/$filename").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
        automation.executeShellCommand("screencap -p /data/local/tmp/$filename").use { descriptor -> java.io.FileInputStream(descriptor.fileDescriptor).use { it.readBytes() } }
        val bytes = java.io.FileInputStream(automation.executeShellCommand("cat /data/local/tmp/$filename").fileDescriptor).use { it.readBytes() }
        assertTrue("Synthetic screenshot must survive app uninstall", bytes.size > 8 && bytes.copyOfRange(0, 8).contentEquals(byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)))
    }

    private fun systemNode(predicate: (android.view.accessibility.AccessibilityNodeInfo) -> Boolean): android.view.accessibility.AccessibilityNodeInfo {
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        fun find(node: android.view.accessibility.AccessibilityNodeInfo?): android.view.accessibility.AccessibilityNodeInfo? {
            if (node == null) return null
            for (index in node.childCount - 1 downTo 0) find(node.getChild(index))?.let { return it }
            return node.takeIf(predicate)
        }
        val deadline = android.os.SystemClock.uptimeMillis() + 10_000
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            find(automation.rootInActiveWindow)?.let { return it }
            android.os.SystemClock.sleep(100)
        }
        fun texts(node: android.view.accessibility.AccessibilityNodeInfo?): String = if (node == null) "(no root)" else
            "${node.packageName}:${node.text}:${node.contentDescription}\n" + (0 until node.childCount).joinToString("") { texts(node.getChild(it)) }
        val details = texts(automation.rootInActiveWindow)
        java.io.File(compose.activity.filesDir, "portable-picker-failure.txt").writeText(details)
        automation.takeScreenshot()?.let { bitmap -> java.io.File(compose.activity.filesDir, "portable-picker-failure.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) } }
        error("Synthetic system Files control was not available: ${details.take(3000)}")
    }

    private fun clickSystemNode(predicate: (android.view.accessibility.AccessibilityNodeInfo) -> Boolean) {
        fun clickableAncestor(candidate: android.view.accessibility.AccessibilityNodeInfo): android.view.accessibility.AccessibilityNodeInfo? {
            var current: android.view.accessibility.AccessibilityNodeInfo? = candidate
            while (current != null && (!current.isClickable || !current.isEnabled)) current = current.parent
            return current
        }
        repeat(5) {
            val matched = systemNode { candidate -> predicate(candidate) && clickableAncestor(candidate) != null }
            if (clickableAncestor(matched)?.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK) == true) return
            android.os.SystemClock.sleep(100)
        }
        error("Synthetic Files control did not accept its click")
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
