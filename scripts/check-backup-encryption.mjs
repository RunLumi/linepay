import assert from 'node:assert/strict';
import { pbkdf2Sync, createCipheriv, createDecipheriv, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';

// Independent, dependency-free transport verifier. Fixture credentials are synthetic/public.
const vector = JSON.parse(readFileSync(new URL('../shared/contracts/backup/encryption-v1.json', import.meta.url)));
const encoded = Buffer.from(vector.encodedHex, 'hex');
const header = encoded.subarray(0, 44);
const salt = encoded.subarray(12, 28);
const nonce = encoded.subarray(28, 40);
const plaintext = Buffer.from(vector.plaintextUTF8, 'utf8');
assert.equal(header.subarray(0, 8).toString(), 'LPBENC01');
assert.equal(header.readUInt32BE(8), 600_000);
assert.equal(header.readUInt32BE(40), plaintext.length);
assert.equal(encoded.length, plaintext.length + 60);
const normalized = Buffer.from(vector.password.normalize('NFC'), 'utf8');
const key = pbkdf2Sync(normalized, salt, 600_000, 32, 'sha256');
assert.equal(key.toString('hex'), vector.keyHex);
const cipher = createCipheriv('aes-256-gcm', key, nonce);
cipher.setAAD(header);
const sealed = Buffer.concat([cipher.update(plaintext), cipher.final(), cipher.getAuthTag()]);
assert.deepEqual(Buffer.concat([header, sealed]), encoded);
const decipher = createDecipheriv('aes-256-gcm', key, nonce);
decipher.setAAD(header);
decipher.setAuthTag(encoded.subarray(encoded.length - 16));
assert.deepEqual(Buffer.concat([decipher.update(encoded.subarray(44, -16)), decipher.final()]), plaintext);

const passwordKey = await webcrypto.subtle.importKey('raw', normalized, 'PBKDF2', false, ['deriveKey']);
const aes = await webcrypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations: 600_000, hash: 'SHA-256' },
  passwordKey, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
const params = { name: 'AES-GCM', iv: nonce, additionalData: header, tagLength: 128 };
assert.deepEqual(Buffer.from(await webcrypto.subtle.encrypt(params, aes, plaintext)), sealed);
assert.deepEqual(Buffer.from(await webcrypto.subtle.decrypt(params, aes, sealed)), plaintext);
const damaged = Buffer.from(sealed); damaged[damaged.length - 1] ^= 1;
await assert.rejects(webcrypto.subtle.decrypt(params, aes, damaged));
console.log('PASS: synthetic backup envelope matches Node crypto and WebCrypto; authenticated tampering rejected. Native fixture parity is checked separately by BackupEncryptionTests.');
