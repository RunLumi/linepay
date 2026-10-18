package com.streamentry.linepay.backup

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.text.Normalizer
import javax.crypto.AEADBadTagException
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class BackupEnvelopeException(val reason: Reason): IllegalArgumentException(reason.name) {
    enum class Reason { TOO_LARGE, INVALID, UNSUPPORTED_VERSION, PASSWORD_REQUIRED, PASSWORD_POLICY, PASSWORD_OR_DAMAGE, CRYPTOGRAPHY }
}

/** Only the shared encrypted transport. This does not parse state, replace records or save passwords. */
object BackupEnvelope {
    const val MAXIMUM_BYTES = 64 * 1024 * 1024
    private const val HEADER_BYTES = 44
    private const val OVERHEAD_BYTES = 60
    private const val ITERATIONS = 600_000
    private val magic = "LPBENC01".toByteArray(StandardCharsets.US_ASCII)
    private val prefix = "LPBENC".toByteArray(StandardCharsets.US_ASCII)

    fun isEncrypted(bytes: ByteArray): Boolean = bytes.size >= prefix.size && prefix.indices.all { bytes[it] == prefix[it] }

    fun seal(plaintext: ByteArray, password: String): ByteArray {
        val random = SecureRandom()
        val salt = ByteArray(16).also(random::nextBytes)
        val nonce = ByteArray(12).also(random::nextBytes)
        return sealWithFixtureParameters(plaintext,password,salt,nonce)
    }

    internal fun sealWithFixtureParameters(plaintext: ByteArray, password: String, salt: ByteArray, nonce: ByteArray): ByteArray {
        normalized(password,creating=true)
        if (plaintext.isEmpty() || plaintext.size > MAXIMUM_BYTES - OVERHEAD_BYTES) fail(BackupEnvelopeException.Reason.TOO_LARGE)
        if (salt.size != 16 || nonce.size != 12) fail(BackupEnvelopeException.Reason.INVALID)
        val header = ByteBuffer.allocate(HEADER_BYTES).order(ByteOrder.BIG_ENDIAN)
            .put(magic).putInt(ITERATIONS).put(salt).put(nonce).putInt(plaintext.size).array()
        val key = derive(password,salt)
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE,SecretKeySpec(key,"AES"),GCMParameterSpec(128,nonce))
            cipher.updateAAD(header)
            return header + cipher.doFinal(plaintext)
        } catch (failure: GeneralSecurityException) {
            fail(BackupEnvelopeException.Reason.CRYPTOGRAPHY)
        } finally { key.fill(0) }
    }

    fun open(encoded: ByteArray, password: String?): ByteArray {
        if (encoded.size > MAXIMUM_BYTES) fail(BackupEnvelopeException.Reason.TOO_LARGE)
        if (encoded.size < OVERHEAD_BYTES || !isEncrypted(encoded)) fail(BackupEnvelopeException.Reason.INVALID)
        val bytes = encoded.copyOf()
        val header = bytes.copyOfRange(0,HEADER_BYTES)
        val fields = ByteBuffer.wrap(header).order(ByteOrder.BIG_ENDIAN)
        val version = ByteArray(8).also(fields::get)
        if (!version.contentEquals(magic) || fields.int != ITERATIONS) fail(BackupEnvelopeException.Reason.UNSUPPORTED_VERSION)
        val salt = ByteArray(16).also(fields::get)
        val nonce = ByteArray(12).also(fields::get)
        val length = fields.int
        if (length <= 0 || length != bytes.size - OVERHEAD_BYTES) fail(BackupEnvelopeException.Reason.INVALID)
        if (password.isNullOrEmpty()) fail(BackupEnvelopeException.Reason.PASSWORD_REQUIRED)
        val key = derive(password,salt)
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE,SecretKeySpec(key,"AES"),GCMParameterSpec(128,nonce))
            cipher.updateAAD(header)
            return cipher.doFinal(bytes,HEADER_BYTES,bytes.size - HEADER_BYTES)
        } catch (failure: AEADBadTagException) {
            fail(BackupEnvelopeException.Reason.PASSWORD_OR_DAMAGE)
        } catch (failure: BadPaddingException) {
            fail(BackupEnvelopeException.Reason.PASSWORD_OR_DAMAGE)
        } catch (failure: GeneralSecurityException) {
            fail(BackupEnvelopeException.Reason.CRYPTOGRAPHY)
        } finally { key.fill(0) }
    }

    private fun normalized(password: String, creating: Boolean): String {
        val value = Normalizer.normalize(password,Normalizer.Form.NFC)
        val utf8 = value.toByteArray(StandardCharsets.UTF_8)
        if (value.isEmpty() || utf8.size > 1024 || String(utf8,StandardCharsets.UTF_8) != value ||
            (creating && value.codePointCount(0,value.length) < 12)) fail(BackupEnvelopeException.Reason.PASSWORD_POLICY)
        return value
    }
    private fun derive(password: String, salt: ByteArray): ByteArray {
        val chars = normalized(password,creating=false).toCharArray()
        val spec = PBEKeySpec(chars,salt,ITERATIONS,256)
        chars.fill('\u0000')
        return try { SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded }
        catch (failure: GeneralSecurityException) { fail(BackupEnvelopeException.Reason.CRYPTOGRAPHY) }
        finally { spec.clearPassword() }
    }
    private fun fail(reason: BackupEnvelopeException.Reason): Nothing = throw BackupEnvelopeException(reason)
}
