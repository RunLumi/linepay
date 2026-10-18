package com.streamentry.linepay.backup

import com.google.gson.JsonParser
import java.io.File
import java.nio.charset.StandardCharsets
import org.junit.Assert.*
import org.junit.Test

class BackupEnvelopeTest {
    private val vector get() = JsonParser.parseString(File(System.getProperty("linepay.sharedContracts"),"backup/encryption-v1.json").readText()).asJsonObject
    private fun bytes(hex: String): ByteArray = hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    @Test fun independentVectorMatchesIncludingCanonicalUnicode() {
        val fixture=vector
        val encoded=bytes(fixture["encodedHex"].asString)
        val plaintext=fixture["plaintextUTF8"].asString.toByteArray(StandardCharsets.UTF_8)
        val actual=BackupEnvelope.sealWithFixtureParameters(plaintext,fixture["password"].asString,
            bytes(fixture["saltHex"].asString),bytes(fixture["nonceHex"].asString))
        assertArrayEquals(encoded,actual)
        assertArrayEquals(plaintext,BackupEnvelope.open(encoded,fixture["normalizedPassword"].asString))
    }
    @Test fun wrongPasswordAndAuthenticatedRegionDamageReleaseNoPlaintext() {
        val fixture=vector;val encoded=bytes(fixture["encodedHex"].asString);val phrase=fixture["password"].asString
        assertEquals(BackupEnvelopeException.Reason.PASSWORD_REQUIRED,assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(encoded,null) }.reason)
        assertEquals(BackupEnvelopeException.Reason.PASSWORD_OR_DAMAGE,assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(encoded,phrase+" wrong") }.reason)
        for (offset in listOf(12,28,44,encoded.lastIndex)) {
            val damaged=encoded.copyOf();damaged[offset]=(damaged[offset].toInt() xor 1).toByte()
            assertEquals(BackupEnvelopeException.Reason.PASSWORD_OR_DAMAGE,assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(damaged,phrase) }.reason)
        }
    }
    @Test fun unboundedWorkFactorsAndInvalidLengthsFailBeforePasswordDerivation() {
        val encoded=bytes(vector["encodedHex"].asString)
        val future=encoded.copyOf();future[8]=(future[8].toInt() xor 1).toByte()
        assertEquals(BackupEnvelopeException.Reason.UNSUPPORTED_VERSION,assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(future,null) }.reason)
        assertEquals(BackupEnvelopeException.Reason.INVALID,assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(encoded.dropLast(1).toByteArray(),null) }.reason)
    }
    @Test fun randomExportsDifferAndInputPolicyKeepsSpaces() {
        val phrase=vector["uiPhraseASCII"].asString
        val plaintext="SYNTHETIC PRIVATE COPY".toByteArray(StandardCharsets.UTF_8)
        val first=BackupEnvelope.seal(plaintext,phrase)
        val second=BackupEnvelope.seal(plaintext,phrase)
        assertFalse(first.contentEquals(second))
        assertArrayEquals(plaintext,BackupEnvelope.open(first,phrase))
        val spaced=BackupEnvelope.seal(plaintext," $phrase ")
        assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.open(spaced,phrase) }
        assertThrows(BackupEnvelopeException::class.java) { BackupEnvelope.seal(plaintext,"short") }
    }
}
