# ADR 0015: password-protected manual backups

Status: accepted for owner-authorized local-only v2 work, October 17, 2026. Implementation `426f237` passed the full native gate (349 passed, zero failed, one intentional skip) and eight focused crypto/adaptive UI checks; cross-device/provider, Android/PWA restoration and release declarations
remain separate evidence.

The owner superseded accounts/automatic sync with manual backup and diagnostic exports. Add optional
password protection to the existing complete backup flow, without an account, backend, runtime
package, stored password or Pro restriction. Keep old unprotected snapshots readable. The current
copy's protection choice is explicit; the unprotected mode retains its sensitive-data warning.

Use Apple CommonCrypto PBKDF2-HMAC-SHA256 (600,000 rounds, fresh 16-byte salt) and CryptoKit AES-256-GCM
(fresh 12-byte nonce). The bounded versioned header is authenticated. Wrong passwords/tampering
produce no plaintext for state decoding and no local-state mutation. Resource costs are fixed per
supported version; attacker-provided arbitrary iteration counts are rejected before derivation.
The [platform-neutral transport](../../shared/contracts/backup/README.md) owns bytes and Unicode
normalization. A native/Node vector proves interoperability of that envelope, not a cryptography
certification or complete Android/PWA adoption.

The protected payload uses versioned JSON, decimal Unix-second strings for date values, exact
financial JSON values and base64 originals. Preserve timestamps without a lossy binary epoch shift;
reject an unrepresentable date rather than silently changing it. Existing state schema, migration,
identity, history, evidence validation and last-write state commit remain authoritative. Do not
rename the app, file extension or bundle ID. Keep global encoded/state/original/count bounds.

Derivation, encryption and coordinated file reading run on the existing BackupIO actor. The app
keeps entered passwords only for the immediate operation/review and clears UI fields afterward,
on selection discard and on dismissal. It writes no password/key to state, Keychain, diagnostics,
logs or exports. Clearing an in-memory field is not a claim of guaranteed runtime-memory erasure.
No plaintext temporary backup file is needed to prepare a protected copy.

Unlocking and validating a file only prepares an immutable restore preview. The worker separately
confirms replacement, not merge. A selected file can change before retry; each read is bounded,
authenticated and validated again. The preview reports the actual opened transport, not merely
whether the worker happened to type a password. Existing originals/state are untouched until the
confirmed restore commit; the selected backup is never modified or deleted.

A forgotten password cannot be recovered by LinePaycheck. The UI requires matching confirmation and
an acknowledgement that the password was kept separately before protected export. Old app versions
cannot open protected copies. Files-provider acceptance is not remote upload/delivery proof.

Primary sources checked October 16–17, 2026:

- [Apple AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- Apple SDK `CommonCrypto/CommonKeyDerivation.h`, documenting explicit encoding/normalization and PBKDF2 parameters
- [OWASP password derivation guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Node crypto API](https://nodejs.org/api/crypto.html)
- [Apple export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Apple encryption documentation](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)

The existing NO non-exempt-encryption flag is retained for the Apple OS-only implementation, with
its old HTTPS-only comment corrected. This is an engineering classification to recheck for the
actual release, not owner/counsel approval. Adding this feature triggers renewed #32 declaration
review; the 1.0.5 declaration is not v2 approval. No App Store write occurs from this ADR/inventory.
