# Password-protected manual backup transport v1

[Shared contracts](../README.md)

This document defines the existing LPBENC01 byte envelope. It is separate from the plaintext state
schema carried inside it. The native client-local snapshot remains a same-client format;
[Portable financial state v1](../portable-state/README.md) defines a typed cross-client payload.
Neither transport conformance nor the portable schema alone proves that every app has a working
export, import, replacement transaction, or cross-client E2E path. All fixture credentials and
contents are explicitly synthetic; never reuse their salt/nonce for a real backup.

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

## Encrypted payloads

LPBENC01 authenticates bounded plaintext bytes; it does not choose a common state schema. The
existing protected iOS client-local plaintext is UTF-8 JSON with format
`com.streamentry.linepay.snapshot`, version 1, a decimal Unix-second `createdAt` string,
versioned `AppPersistentState` under `state`, and original files under `files`. See the
[iOS encoder](../../../apps/ios/App/Sources/BackupEncryption.swift). The separate legacy
unencrypted `com.streamentry.linepay.backup` version 1 format is a binary property-list envelope,
not that protected plaintext. Android raw local-state JSON and Web's
`com.streamentry.linepay.web.snapshot` are also client-specific; none may be silently interpreted
as portable financial state.

The native iOS state JSON limit is 8 MiB, each original 25 MiB, at most 512 originals and 2,000
periods. The total encoded/encrypted limit still applies; binary and base64 overhead can make a
protected copy exceed the limit sooner than an unencrypted copy. Nothing may be silently omitted.

The canonical cross-client payload uses a different closed format:

- `format`: `com.streamentry.linepay.portable-state`
- `version`: integer 1
- `schema-v1.json`: the exact JSON payload contract in `shared/contracts/portable-state/`

Portable v1 keeps the same LPBENC01 envelope and byte limits. It retains typed financial records,
source-client IDs, frozen receipt traces, exact work/rule snapshots, and original bytes. Each source
must inventory its complete financial state and refuse the whole export when it has unsupported
financial records or drafts. Each target must validate every reference and preflight its active
profile, work-kind, rule, and attachment capabilities before offering replacement. Import is
whole-file and user-confirmed; there is no supported-subset restore or fallback to plaintext JSON.
StoreKit/trial state, local diagnostics, and activity history remain destination-owned and are not
included in this financial payload. Their presence alone does not block a portable export.

The existing native client-local archive is not silently wrapped, translated by field-name guessing,
or treated as portable v1. A client adopts the shared format only through its explicit typed adapter
and preserves its local backup compatibility separately.

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
