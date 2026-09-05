# Manual iCloud Drive backup and restore

Status: accepted feature decision; implementation requires the native CI and device checks below.
Date: September 5, 2026.

## Decision

Add **manual, opt-in iCloud Drive backup and restore** through Apple's Files picker. This is not automatic scheduled backup, live synchronization, a CloudKit database, or Apple's full-device iCloud Backup. The user selects a private destination in iCloud Drive. Other enabled Files providers or On My iPhone are supported too. LinePaycheck cannot claim a destination is iCloud when the user selected somewhere else.

This user-requested addition supersedes the earlier deferral of manual restore and iCloud file backup in the 1.0 plan and local-first architecture notes. All other 1.0 requirements and previously identified readiness gaps remain unchanged. No LinePaycheck account, central server, new runtime dependency, CloudKit container, or new app-specific iCloud entitlement is introduced. The file picker grants access only to the user-selected document/location. The bundle identifier remains `com.streamentry.linepay`.

Backup and restore are data-safety features available without Pro. Purchases remain separate and use StoreKit's verified entitlement state; a backup never grants a subscription.

## Experience

Settings > Your data > iCloud backup & restore. The same restore entry is available on the welcome and unreadable-data recovery screens.

1. **Back up:** review the privacy warning, prepare a snapshot, choose Browse > iCloud Drive in Files, and save to a private folder.
2. **Restore:** select a `.linepaybackup` file in Files, wait for validation, review its date and counts, and explicitly confirm **Restore and replace**. No records are merged.
3. **After restore:** discard stale screens by replacing the app model lifetime, then return to the restored app state. Existing StoreKit ownership is unaffected.

A Files save callback establishes provider acceptance, not that remote iCloud upload is complete. The app tells the user to confirm upload in Files before relying on the copy on another phone. It does not fabricate an automatic-backup toggle, upload percentage, scheduled job, or persistent 'last cloud backup succeeded' timestamp.

## Scope and format

A single binary property-list envelope contains a version, format identifier, payload bytes, and SHA-256 payload digest. The payload contains the saved-state JSON, creation date, and original document bytes keyed by evidence ID. Format/UTType: `com.streamentry.linepay.backup`; extension: `.linepaybackup`.

Included: saved profile and exact agreement versions, active and historical periods, work and notes, confirmed paystub fields, reconciliation snapshots, free-audit usage, and every retained referenced original paystub with its source metadata.

Excluded: unsaved view drafts (the current app does not persist them), deliberately deleted originals, temporary exports, StoreKit transactions/Pro entitlement, and device/account configuration. Old JSON-only exports are not complete backups and are rejected by this restore path rather than silently restoring without evidence.

Bounds: 64 MiB encoded file, 8 MiB state JSON, 25 MiB per retained original, 512 originals, 2,000 periods, and 50,000 entries per period. These are implementation safety bounds, not pricing limits. Oversized/missing originals fail the complete backup; nothing is silently omitted. Revisit bounds using measured memory behavior on supported phones rather than removing them blindly.

## Privacy

The archive contains sensitive information and is **not password-encrypted by LinePaycheck**. The explicit warning appears before export and on the backup screen. Use a private destination and do not share the archive casually. SHA-256 detects accidental changes; it does not prove authorship, conceal contents, verify payroll correctness, or authenticate a maliciously modified backup.

iCloud's encryption properties depend on the user's Apple settings and availability of Advanced Data Protection. Do not promise universal end-to-end encryption. Saving through another Files provider uses that provider's security. No raw pay data, file paths, filenames, or archive contents are logged by this feature.

Deleting local records does not delete user-exported/iCloud copies. Manage those copies in Files. Existing OS-level device backup behavior is separate from this feature.

## Restore safety contract

- Validate format, schema version, checksum, size, evidence references, duplicate IDs, safe filenames, key calendar/money invariants, and work/break ranges before mutating local data.
- Imported filenames never become destinations. Save originals to newly generated local filenames and remap only the physical paths. Preserve evidence IDs, creation dates, source metadata, work IDs, rule versions, and archived calculation values.
- Write all new originals first. Save the new state atomically **last**, using the existing `AppStateStoring` boundary. A failed original/state write leaves previous records and previous originals in place. Remove only staged originals after a failed commit; report cleanup problems explicitly.
- After commit, delete prior referenced originals. A cleanup error is a successful restore with a warning, not a false failed-restore message. Interrupted processes may leave unreferenced originals; they must not leave committed records pointing at uninstalled originals. Delete all local data clears the evidence directory.
- Restoring unreadable state requires the separate explicit replace confirmation. The recovery screen offers raw-file export first. Unenumerable old originals are retained and disclosed rather than deleted speculatively.
- Do not overwrite or delete the chosen backup. Do not automatically merge, recompute historical results, grant Pro, or reset known used free-audit access. Preserve usage with the logical OR of existing and restored state; this is not claimed to be tamper-proof identity enforcement.
- Rebuild the observable app model and reset the navigation lifetime only after committing. Tests inject the existing store seams; no parallel persistence architecture is introduced.

The original evidence/state adapters retain their existing data-protection behavior. This feature does not make a new claim about crash-atomic deletion across multiple files or password-based archive encryption.

## Verification

Automated suite: `apps/ios/AppTests/Sources/BackupTests.swift`. Includes full saved-state/original-byte round trip with relaunch, frozen history, missing/extra/duplicate originals, path traversal rejection, checksum/version/legacy-format/size rejection, failed state commit rollback, failed evidence write, explicit unreadable-store consent, free-audit preservation, cleanup warnings, and input-file preservation.

Run `bash scripts/agent-verify.sh ios`. Syntax parsing on Linux is not an iOS build, and passing store tests is not proof of an actual iCloud upload.

Before release, record device results for:

- Fresh install: restore without onboarding or Pro; verify original documents open and saved calculations/timezones match.
- Two iPhones using the same iCloud Drive: save, confirm upload in Files, download and restore, relaunch, compare all records and bytes.
- File-provider offline/download failure, iCloud signed out/disabled, full iCloud storage, low local storage, cancellation at each picker/confirmation, corrupt/unsupported archive, and an old snapshot replacing newer local records only after confirmation.
- App termination during preparation/import/restore: no committed missing originals; recovery messaging and retained files behave as documented.
- Both appearances, largest Dynamic Type, VoiceOver, and small-screen restore preview. Real files in tests must be synthetic.
- Release Info.plist declares the backup type; camera usage description and existing display/bundle identity remain unchanged; the backup type does not enable automatic external-file opening.

## Primary references

- Apple, Transferable file exporter: https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:item:contenttypes:defaultfilename:oncompletion:oncancellation:)
- Apple, file importer and security-scoped access: https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:)
- Apple, file coordination: https://developer.apple.com/documentation/foundation/nsfilecoordinator
- Apple, exported file types: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations
- Apple, iCloud data security: https://support.apple.com/en-us/102651
