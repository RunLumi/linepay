package com.streamentry.linepay.android

import android.util.AtomicFile
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonParseException
import com.streamentry.linepay.backup.BackupEnvelope
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/** File-private local state. Android automatic cloud backup is disabled in the manifest. */
class LocalStateStore(filesDirectory: File) {
    private val stateDirectory = File(filesDirectory, "linepaycheck").apply { mkdirs() }
    private val atomicFile = AtomicFile(File(stateDirectory, "state-v1.json"))
    private val gson = androidLocalStateGson()

    @Synchronized
    fun load(): AndroidLocalState {
        val input = try {
            atomicFile.openRead()
        } catch (_: FileNotFoundException) {
            return AndroidLocalState.empty()
        }
        val encoded = input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                total += count
                require(total <= BackupEnvelope.MAXIMUM_BYTES) {
                    "Saved LinePaycheck data exceeds the supported size."
                }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
        return decode(encoded)
    }

    @Synchronized
    fun save(state: AndroidLocalState) {
        val validated = AndroidLocalStateValidator.validate(state)
        val encoded = gson.toJson(validated).toByteArray(StandardCharsets.UTF_8)
        require(encoded.isNotEmpty() && encoded.size <= BackupEnvelope.MAXIMUM_BYTES) {
            "Saved LinePaycheck data exceeds the supported size."
        }
        val output = atomicFile.startWrite()
        try {
            output.write(encoded)
            atomicFile.finishWrite(output)
        } catch (failure: Throwable) {
            atomicFile.failWrite(output)
            throw failure
        }
    }

    @Synchronized
    fun clearForUiTest() {
        atomicFile.delete()
    }

    fun encode(state: AndroidLocalState): ByteArray {
        val validated = AndroidLocalStateValidator.validate(state)
        return gson.toJson(validated).toByteArray(StandardCharsets.UTF_8)
    }

    fun decode(encoded: ByteArray): AndroidLocalState {
        require(encoded.isNotEmpty() && encoded.size <= BackupEnvelope.MAXIMUM_BYTES) {
            "The selected file is empty or too large."
        }
        val text = try {
            StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(encoded))
                .toString()
        } catch (_: Exception) {
            throw InvalidLocalState("This file is not valid UTF-8 LinePaycheck data.")
        }
        val parsed = try {
            val tree = JsonParser.parseString(text)
            if (!tree.isJsonObject) throw InvalidLocalState("This file contains no LinePaycheck state.")
            val root = tree.asJsonObject
            migrateAndroidLocalState(root)
            gson.fromJson(root, AndroidLocalState::class.java)
                ?: throw InvalidLocalState("This file contains no LinePaycheck state.")
        } catch (failure: JsonParseException) {
            throw InvalidLocalState("This file is not valid LinePaycheck state.")
        }
        return try {
            AndroidLocalStateValidator.validate(parsed)
        } catch (failure: IllegalArgumentException) {
            if (failure is InvalidLocalState) throw failure
            throw InvalidLocalState(failure.message ?: "This file contains invalid saved data.")
        } catch (_: RuntimeException) {
            throw InvalidLocalState("This file contains incomplete or invalid saved data.")
        }
    }

    fun createEncryptedBackup(state: AndroidLocalState, password: String): ByteArray =
        BackupEnvelope.seal(encode(state), password)

    fun createPortableEncryptedBackup(state: AndroidLocalState, password: String): ByteArray =
        BackupEnvelope.seal(AndroidPortableStateCodec.encode(state), password)

    fun restoreEncryptedBackup(encoded: ByteArray, password: String?): AndroidLocalState {
        val plaintext = BackupEnvelope.open(encoded, password)
        return try {
            val probe = JsonParser.parseString(plaintext.toString(StandardCharsets.UTF_8))
            if (probe.isJsonObject && probe.asJsonObject.has("format")) {
                require(probe.asJsonObject.get("format").isJsonPrimitive && probe.asJsonObject.get("format").asString == AndroidPortableStateCodec.FORMAT) {
                    "This encrypted file uses an unsupported financial backup format. No data changed."
                }
                AndroidPortableStateCodec.decode(plaintext)
            } else decode(plaintext)
        } finally {
            plaintext.fill(0)
        }
    }

}

/** Pure version boundary, shared by local files and encrypted backup imports. */
internal fun migrateAndroidLocalState(root: JsonObject) {
    val encodedVersion = root.get("schemaVersion")
    if (encodedVersion?.isJsonPrimitive != true || !encodedVersion.asJsonPrimitive.isNumber) {
        throw InvalidLocalState("This file has no supported LinePaycheck state version.")
    }
    val version = encodedVersion.asString.toIntOrNull()
        ?: throw InvalidLocalState("This file has no supported LinePaycheck state version.")
    when (version) {
        1 -> {
            // Schema 1 predates weekly receipts. Never reinterpret a non-empty unknown field.
            val priorReceipts = root.get("weeklyReviews")
            if (priorReceipts != null && (!priorReceipts.isJsonArray || priorReceipts.asJsonArray.size() != 0)) {
                throw InvalidLocalState("This legacy state contains unsupported weekly review records.")
            }
            root.add("weeklyReviews", JsonArray())
            root.addProperty("schemaVersion", 2)
            migrateAndroidSchemaTwo(root)
        }
        2 -> migrateAndroidSchemaTwo(root)
        3 -> {
            if (root.get("weeklyReviews")?.isJsonArray != true) {
                throw InvalidLocalState("This saved state is missing its weekly review collection.")
            }
        }
        4 -> {
            if (root.get("weeklyReviews")?.isJsonArray != true || root.get("benefitReviews")?.isJsonArray != true) {
                throw InvalidLocalState("This saved state is missing its review collections.")
            }
        }
        AndroidLocalState.CURRENT_SCHEMA_VERSION -> {
            if (root.get("weeklyReviews")?.isJsonArray != true || root.get("benefitReviews")?.isJsonArray != true) {
                throw InvalidLocalState("This saved state is missing its review collections.")
            }
        }
        else -> throw InvalidLocalState("This backup uses an unsupported LinePaycheck state version.")
    }
    if (version < 4) {
        val prior = root.get("benefitReviews")
        if (prior != null && (!prior.isJsonArray || prior.asJsonArray.size() != 0)) {
            throw InvalidLocalState("This legacy state contains unsupported benefit receipts.")
        }
        root.add("benefitReviews", JsonArray())
        root.addProperty("schemaVersion", 4)
    }
    if (version < 5) {
        if (root.has("portableArchive") && !root.get("portableArchive").isJsonNull) {
            throw InvalidLocalState("Legacy data contains unsupported portable evidence.")
        }
        root.add("portableArchive", com.google.gson.JsonNull.INSTANCE)
        root.addProperty("schemaVersion", AndroidLocalState.CURRENT_SCHEMA_VERSION)
    }
}

/** Schema 3 makes weekly-source completeness immutable and removes checkbox approval. */
private fun migrateAndroidSchemaTwo(root: JsonObject) {
    val checks = root.get("checks")
    if (checks?.isJsonArray != true) {
        throw InvalidLocalState("This saved state is missing its paycheck checks.")
    }
    val reviews = root.get("weeklyReviews")
    if (reviews?.isJsonArray != true) {
        throw InvalidLocalState("This saved state is missing its weekly review collection.")
    }

    checks.asJsonArray.forEach { encodedCheck ->
        val check = encodedCheck.requireJsonObject("A saved paycheck check is invalid.")
        check.remove("weeklyReviewConfirmed")
        val expectedGross = check.get("expectedGross")
        val priorVerdict = check.get("verdict")?.asString
        if ((expectedGross != null && !expectedGross.isJsonNull) || priorVerdict == "MATCHES") {
            val reasons = check.get("reviewReasons")
            if (reasons?.isJsonArray != true) {
                throw InvalidLocalState("A saved paycheck review is missing its reasons.")
            }
            if (reasons.asJsonArray.none { it.isJsonPrimitive && it.asString == "WEEKLY_REVIEW_PENDING" }) {
                reasons.asJsonArray.add("WEEKLY_REVIEW_PENDING")
            }
            check.addProperty("verdict", "NEEDS_REVIEW")
        }
    }

    reviews.asJsonArray.forEach { encodedReview ->
        val review = encodedReview.requireJsonObject("A saved weekly review is invalid.")
        val source = review.get("source")?.requireJsonObject("A weekly review has no frozen source.")
            ?: throw InvalidLocalState("A weekly review has no frozen source.")
        val start = source.longValue("startEpochSeconds")
        val end = try {
            Math.addExact(start, AndroidWeeklyReviewRepository.WORKWEEK_SECONDS)
        } catch (_: ArithmeticException) {
            throw InvalidLocalState("A weekly review boundary is outside the supported range.")
        }
        val periods = source.get("periods")
        if (periods?.isJsonArray != true) {
            throw InvalidLocalState("A weekly review is missing its source periods.")
        }
        val eligibleIds = checks.asJsonArray.mapNotNull { encodedCheck ->
            val check = encodedCheck.requireJsonObject("A saved paycheck check is invalid.")
            val work = check.get("work")
            if (work?.isJsonArray != true) throw InvalidLocalState("A saved paycheck check is missing work.")
            val containsWork = work.asJsonArray.any { encodedWork ->
                val entry = encodedWork.requireJsonObject("A saved work record is invalid.")
                entry.longValue("endEpochSeconds") > start && entry.longValue("startEpochSeconds") < end
            }
            if (containsWork) check.stringValue("id") else null
        }.toSet()

        val completePeriods = JsonArray()
        periods.asJsonArray.forEach { encodedPeriod ->
            val period = encodedPeriod.requireJsonObject("A weekly source period is invalid.")
            val work = period.get("work")
            if (work?.isJsonArray != true) throw InvalidLocalState("A weekly source period is missing work.")
            val containsWork = work.asJsonArray.any { encodedWork ->
                val entry = encodedWork.requireJsonObject("A weekly source work record is invalid.")
                entry.longValue("endEpochSeconds") > start && entry.longValue("startEpochSeconds") < end
            }
            if (containsWork) completePeriods.add(period.deepCopy())
        }
        val retainedIds = completePeriods.map { encodedPeriod ->
            encodedPeriod.asJsonObject.stringValue("periodId")
        }
        if (retainedIds.toSet() != eligibleIds || retainedIds.size != eligibleIds.size) {
            throw InvalidLocalState(
                "A legacy weekly receipt does not retain every saved period containing work for its week.",
            )
        }
        source.add("periods", completePeriods)
        source.add("workContainingPeriodIds", JsonArray().apply { retainedIds.forEach(::add) })
    }

    root.addProperty("schemaVersion", 3)
}

private fun JsonElement.requireJsonObject(message: String): JsonObject {
    if (!isJsonObject) throw InvalidLocalState(message)
    return asJsonObject
}

private fun JsonObject.longValue(key: String): Long = try {
    get(key)?.asLong ?: throw InvalidLocalState("Saved data is missing $key.")
} catch (_: RuntimeException) {
    throw InvalidLocalState("Saved data contains an invalid $key.")
}

private fun JsonObject.stringValue(key: String): String = try {
    get(key)?.asString ?: throw InvalidLocalState("Saved data is missing $key.")
} catch (_: RuntimeException) {
    throw InvalidLocalState("Saved data contains an invalid $key.")
}
