package com.streamentry.linepay.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PortableStateJsonTest {
    @Test fun strictPlaintextReaderPreservesDecimalStringsAndRejectsDuplicateKeysAndTrailingValues() {
        val root = PortableStateJson.parse("""{"amount":"0.100000000001","seconds":1791763200}""".toByteArray())
        assertEquals("0.100000000001", root.get("amount").asString)
        assertEquals(1791763200L, root.get("seconds").asLong)
        listOf("""{"format":"first","format":"second"}""", "{}{}", "{format:'x'}", "[]").forEach { text ->
            assertThrows(Exception::class.java) { PortableStateJson.parse(text.toByteArray()) }
        }
        assertThrows(Exception::class.java) { PortableStateJson.parse(byteArrayOf(0xc3.toByte(), 0x28)) }
        assertThrows(Exception::class.java) { PortableStateJson.parse(ByteArray(PortableStateJson.MAXIMUM_FINANCIAL_BYTES + 1)) }
    }
}
