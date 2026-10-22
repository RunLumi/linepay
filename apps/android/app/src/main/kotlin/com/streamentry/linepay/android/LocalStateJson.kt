package com.streamentry.linepay.android

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.TypeAdapter
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter

/** Portable null+not-recorded fields are required contract data, unlike optional native fields. */
internal fun androidLocalStateGson(): Gson {
    val archiveCodec = GsonBuilder().serializeNulls().disableHtmlEscaping().create()
    val adapter = object : TypeAdapter<AndroidPortableArchive>() {
        override fun write(writer: JsonWriter, value: AndroidPortableArchive?) {
            archiveCodec.toJson(value, AndroidPortableArchive::class.java, writer)
        }
        override fun read(reader: JsonReader): AndroidPortableArchive? =
            archiveCodec.fromJson(reader, AndroidPortableArchive::class.java)
    }
    return GsonBuilder().disableHtmlEscaping()
        .registerTypeAdapter(AndroidPortableArchive::class.java, adapter).create()
}
