package com.streamentry.linepay.android

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.google.gson.Strictness
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import java.io.StringReader
import java.math.BigDecimal
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/** Strict authenticated-plaintext reader. Reject duplicate fields before Gson can overwrite them. */
internal object PortableStateJson {
    const val MAXIMUM_FINANCIAL_BYTES = 8 * 1024 * 1024

    fun parse(bytes: ByteArray): JsonObject {
        require(bytes.isNotEmpty() && bytes.size <= MAXIMUM_FINANCIAL_BYTES) {
            "Portable financial data is empty or exceeds Android's supported 8 MiB limit."
        }
        val text = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes)).toString()
        return JsonReader(StringReader(text)).use { reader ->
            reader.strictness = Strictness.STRICT
            var nodes = 0
            fun read(depth: Int): JsonElement {
                require(depth <= 48 && ++nodes <= 200_000) { "Portable data is too deeply nested or contains too many values." }
                return when (reader.peek()) {
                    JsonToken.BEGIN_OBJECT -> JsonObject().apply {
                        reader.beginObject()
                        while (reader.hasNext()) {
                            val key = reader.nextName()
                            require(!has(key)) { "Portable data contains a duplicate field: $key." }
                            add(key, read(depth + 1))
                        }
                        reader.endObject()
                    }
                    JsonToken.BEGIN_ARRAY -> JsonArray().apply {
                        reader.beginArray()
                        while (reader.hasNext()) add(read(depth + 1))
                        reader.endArray()
                    }
                    JsonToken.STRING -> JsonPrimitive(reader.nextString())
                    JsonToken.NUMBER -> {
                        val exact = reader.nextString()
                        require(exact.length <= 64 && exact.matches(Regex("-?(?:0|[1-9][0-9]*)"))) { "Portable numbers must be exact integer literals; financial decimals are strings." }
                        JsonPrimitive(BigDecimal(exact))
                    }
                    JsonToken.BOOLEAN -> JsonPrimitive(reader.nextBoolean())
                    JsonToken.NULL -> { reader.nextNull(); JsonNull.INSTANCE }
                    else -> throw InvalidLocalState("Invalid portable JSON value.")
                }
            }
            val root = read(0)
            require(reader.peek() == JsonToken.END_DOCUMENT && root.isJsonObject) { "Portable data must contain exactly one financial document." }
            root.asJsonObject
        }
    }
}
