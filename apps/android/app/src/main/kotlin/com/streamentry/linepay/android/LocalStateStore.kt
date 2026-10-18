package com.streamentry.linepay.android

import android.util.AtomicFile
import com.google.gson.GsonBuilder
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
    private val gson = GsonBuilder().disableHtmlEscaping().create()

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
            gson.fromJson(text, AndroidLocalState::class.java)
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

    fun restoreEncryptedBackup(encoded: ByteArray, password: String?): AndroidLocalState =
        decode(BackupEnvelope.open(encoded, password))
}
