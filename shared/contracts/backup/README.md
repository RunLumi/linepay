# Password-protected backup transport v1

[Shared contracts](../README.md)

This is a transport contract, not shared runtime code or proof that every client can restore the
snapshot state. Native Android and full PWA state decoding/restoration remain pending. All fixture
credentials and contents are explicitly synthetic; never reuse their salt/nonce for a real backup.

## Bytes

All integers are unsigned, big-endian. Maximum complete file size is 67,108,864 bytes (64 MiB).

| Offset | Length | Meaning |
|---|---|---|
| 0 | 8 | ASCII `LPBENC01`; unsupported versions must be rejected |
| 8 | 4 | PBKDF2 iteration count: exactly 600,000 in this version |
| 12 | 16 | Fresh cryptographically random salt for each export |
| 28 | 12 | Fresh cryptographically random AES-GCM nonce for each export |
| 40 | 4 | Plaintext byte count N; N > 0 and N + 60 equals complete file size |
| 44 | N | AES-256-GCM ciphertext |
| 44 + N | 16 | GCM authentication tag |

Derive a 32-byte key with PBKDF2-HMAC-SHA256 from NFC-normalized, UTF-8 password bytes and the salt.
Keep spaces; never trim, case-fold or silently truncate. Creation requires at least 12 Unicode
scalars after NFC normalization and no more than 1,024 UTF-8 bytes. Opening accepts a nonempty
password within the byte limit; a failed authentication reveals no plaintext.

The complete 44-byte header is GCM additional authenticated data. Validate size, version, fixed
iteration count and length *before* derivation. Do not accept attacker-selected unbounded work
factors, ignore trailing bytes, release unauthenticated plaintext or fall back to a clear format
after protected-file failure. A wrong password and authenticated-region damage intentionally share
one unlock-failure result. No password reset/recovery service or stored password is implied.

## Encrypted payload

Authenticated plaintext is UTF-8 JSON:

- `format`: `com.streamentry.linepay.snapshot`
- `version`: integer 1
- `createdAt`: decimal Unix seconds, encoded as a string
- `state`: saved-state object, currently schema version 7
- `files`: retained originals, each with `id` and base64 `bytes`

Date-valued draft/metadata fields use decimal Unix-second strings. Existing explicitly named
integer epoch-second fields retain their integer representation. Money must be parsed with exact
decimal semantics, never through binary floating point. Consumers must implement the supported
state schema and its validation/migrations deliberately; this transport spec does not define every
pay-state field. Reject unsupported versions instead of dropping unfamiliar financial records.

The serialized state limit remains 8 MiB, each original 25 MiB, at most 512 originals and 2,000
periods. The total encoded/encrypted limit still applies; base64 overhead can make a protected
copy exceed the limit sooner than a legacy binary copy. Nothing may be silently omitted.

Legacy unprotected `.linepaybackup` binary envelopes remain readable by the native client. They
must not be described as encrypted or authenticated by a password. A checksum is not confidentiality
or authorship. The filename extension is unchanged; content determines the format.

## Conformance evidence

`encryption-v1.json` is generated independently with Node crypto, then checked byte-for-byte by
native `BackupEncryptionTests` using the platform's PBKDF2/AES implementations. It deliberately
includes a decomposed Unicode password and a separate public ASCII phrase for deterministic native UI keyboard input. Run:

```bash
node scripts/check-backup-encryption.mjs
```

The verifier checks Node crypto and Node's WebCrypto API, including tag corruption rejection.
The Node verifier is not a real-browser or Android integration test. An optional Playwright harness checks actual browser WebCrypto against the same vector, using an intercepted test origin and only synthetic data:

```bash
BROWSER=chromium CHROMIUM_EXECUTABLE=/path/to/chrome python3 scripts/check-backup-encryption-browser.py
BROWSER=webkit python3 scripts/check-backup-encryption-browser.py
```

Run those commands in a developer environment with Playwright and the selected browser installed. Reports are written under `.build/backup-crypto-browser/`; passing crypto transport conformance is still not full PWA or Android restoration. Native restore tests separately check
unchanged records before confirmation, legacy support, exact dates and retained original bytes.
