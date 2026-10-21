package com.streamentry.linepay.android

import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class LocalStateMigrationTest {
    @Test
    fun schemaOneWithoutWeeklyReceiptsMigratesToCurrentSchema() {
        val root = JsonParser.parseString(
            """{"schemaVersion":1,"profile":null,"work":[],"checks":[]}""",
        ).asJsonObject

        migrateAndroidLocalState(root)
        val migrated = Gson().fromJson(root, AndroidLocalState::class.java)

        assertEquals(AndroidLocalState.CURRENT_SCHEMA_VERSION, migrated.schemaVersion)
        assertEquals(emptyList<AndroidWeeklyReviewReceipt>(), migrated.weeklyReviews)
        AndroidLocalStateValidator.validate(migrated)
    }

    @Test
    fun schemaTwoCheckboxApprovalMigratesToPendingAndCurrentSchemaRequiresCollection() {
        val previouslyApproved = JsonParser.parseString(
            """{"schemaVersion":2,"profile":null,"work":[],"checks":[{"expectedGross":"200.00","weeklyReviewConfirmed":true,"reviewReasons":[],"verdict":"MATCHES"}],"weeklyReviews":[]}""",
        ).asJsonObject

        migrateAndroidLocalState(previouslyApproved)

        assertEquals(AndroidLocalState.CURRENT_SCHEMA_VERSION, previouslyApproved.get("schemaVersion").asInt)
        val migratedCheck = previouslyApproved.getAsJsonArray("checks").single().asJsonObject
        assertFalse(migratedCheck.has("weeklyReviewConfirmed"))
        assertEquals("NEEDS_REVIEW", migratedCheck.get("verdict").asString)
        assertEquals(
            "WEEKLY_REVIEW_PENDING",
            migratedCheck.getAsJsonArray("reviewReasons").last().asString,
        )

        val legacyWithReceipt = JsonParser.parseString(
            """{"schemaVersion":1,"profile":null,"work":[],"checks":[],"weeklyReviews":[{}]}""",
        ).asJsonObject
        assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(legacyWithReceipt) }

        val incompleteCurrent = JsonParser.parseString(
            """{"schemaVersion":3,"profile":null,"work":[],"checks":[]}""",
        ).asJsonObject
        assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(incompleteCurrent) }

        val fractionalVersion = JsonParser.parseString(
            """{"schemaVersion":1.5,"profile":null,"work":[],"checks":[]}""",
        ).asJsonObject
        assertThrows(InvalidLocalState::class.java) { migrateAndroidLocalState(fractionalVersion) }
    }
}
