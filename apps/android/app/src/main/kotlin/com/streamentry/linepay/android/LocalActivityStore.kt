package com.streamentry.linepay.android

import android.util.AtomicFile
import com.google.gson.GsonBuilder
import com.google.gson.JsonParseException
import java.io.File
import java.nio.charset.StandardCharsets

data class AndroidLocalActivitySnapshot(
    val schemaVersion: Int = 1,
    val recordingEnabled: Boolean = false,
    val counts: Map<String, Long> = emptyMap(),
)

/** Coarse usage counts stay separate from payroll state and are excluded from pay-data backups. */
class LocalActivityStore(filesDirectory: File) {
    private val directory = File(filesDirectory, "linepaycheck").apply { mkdirs() }
    private val atomic = AtomicFile(File(directory, "activity-v1.json"))
    private val gson = GsonBuilder().disableHtmlEscaping().create()
    private val eventNames = setOf("profile-saved", "work-saved", "check-saved")

    @Synchronized
    fun snapshot(): AndroidLocalActivitySnapshot {
        if (!atomic.baseFile.exists()) return AndroidLocalActivitySnapshot()
        val fileLength = atomic.baseFile.length()
        require(fileLength in 1..MAXIMUM_BYTES.toLong()) { "Local activity file is outside the supported size." }
        val encoded = atomic.openRead().use { it.readBytes() }
        val parsed = try {
            gson.fromJson(String(encoded, StandardCharsets.UTF_8), AndroidLocalActivitySnapshot::class.java)
                ?: throw InvalidLocalState("Local activity file is empty.")
        } catch (failure: JsonParseException) {
            throw InvalidLocalState("Local activity file is invalid.")
        }
        require(parsed.schemaVersion == 1) { "Unsupported local activity version." }
        require(parsed.counts.keys.all { it in eventNames }) { "Unknown local activity event." }
        require(parsed.counts.values.all { it in 0..1_000_000_000L }) {
            "Local activity counts are outside the supported range."
        }
        return parsed
    }

    @Synchronized
    fun setRecordingEnabled(enabled: Boolean): AndroidLocalActivitySnapshot =
        update { it.copy(recordingEnabled = enabled) }

    @Synchronized
    fun record(event: String): AndroidLocalActivitySnapshot {
        require(event in eventNames) { "Unsupported local activity event." }
        return update { previous ->
            if (!previous.recordingEnabled) previous
            else previous.copy(counts = previous.counts + (event to ((previous.counts[event] ?: 0L) + 1)))
        }
    }

    @Synchronized
    fun clearCounts(): AndroidLocalActivitySnapshot = update { it.copy(counts = emptyMap()) }

    @Synchronized
    fun clearForUiTest() {
        atomic.delete()
    }

    fun diagnosticJson(snapshot: AndroidLocalActivitySnapshot = snapshot()): ByteArray {
        val report = linkedMapOf(
            "schemaVersion" to snapshot.schemaVersion,
            "recordingEnabled" to snapshot.recordingEnabled,
            "eventCounts" to snapshot.counts.toSortedMap(),
            "scope" to "device-local coarse usage counts only",
        )
        return gson.toJson(report).toByteArray(StandardCharsets.UTF_8)
    }

    private fun update(transform: (AndroidLocalActivitySnapshot) -> AndroidLocalActivitySnapshot)
        : AndroidLocalActivitySnapshot {
        val next = transform(snapshot())
        val bytes = gson.toJson(next).toByteArray(StandardCharsets.UTF_8)
        require(bytes.isNotEmpty() && bytes.size <= MAXIMUM_BYTES) { "Local activity file is too large." }
        val output = atomic.startWrite()
        try {
            output.write(bytes)
            atomic.finishWrite(output)
        } catch (failure: Throwable) {
            atomic.failWrite(output)
            throw failure
        }
        return next
    }

    companion object {
        private const val MAXIMUM_BYTES = 128 * 1024
    }
}
