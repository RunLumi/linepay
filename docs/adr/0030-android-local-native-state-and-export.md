# ADR 0030: Android local native state and manual export

Status: accepted. October 19, 2026. Owner-authorized Android v2 implementation with the subsequent
local-only data-flow decision.

## Context

The owner authorized a native Android client, then chose to keep accounts, cloud sync, pay-data
backend storage, and remote funnel analytics out of v2. The Android Kotlin domain and password
envelope existed, but there was no Compose application, persisted state, snapshot restore, or device
E2E path.

## Decision

- Use a native Kotlin + Jetpack Compose app that calls the pure `:domain` calculators. Views do not
  contain pay arithmetic, time-zone interpretation, or gross verdict logic.
- Store the version-1 Android profile, exact work instants plus their entered `ZoneId`, saved paycheck
  inputs, calculation components, rule snapshot, period match, and saved verdict in one app-private
  JSON state file written through Android `AtomicFile`. Saved checks are immutable receipts; editing
  current rules does not rewrite them.
- Reject unknown state schemas and invalid imported values. Restore validates the entire payload
  before showing its count-only preview; it replaces pay state only after a separate user action.
- Use the shared AES-GCM/PBKDF2 `BackupEnvelope` only for a manual Files-provider export/import.
  The password is transient and is never written to state.
- Keep the opt-in coarse activity ledger in a separate app-private file. It is excluded from pay
  backups and its manual JSON export contains only event counts and recording status.
- Disable Android automatic cloud backup and omit the `INTERNET` permission. There is no account,
  remote report delivery, analytics SDK, or runtime server.
- Limit v2 Android coverage to configured-rule work entry, calendar windows, gross comparison, saved
  history, and manual local export. The UI must say that it does not compute weekly statutory-rate
  treatment and must preserve the assessor's `NEEDS_REVIEW`/`NOT_COMPARABLE` outcomes.
- Pin AGP 9.2.0, Gradle 9.4.1, Kotlin/KGP 2.4.0, Compose BOM 2026.06.00, and SDK 36. The pinned
  KGP still requires AGP's temporary legacy DSL/built-in-Kotlin opt-outs; migrate the modules
  together only after compiler metadata and shared-domain tests prove compatibility.

## Consequences

The Android client can work offline without sending payroll content anywhere. The app's first
schema has no older Android release to migrate; future schema changes must add explicit fixtures
and migration tests before release. Local files use the operating system's app-private storage;
exported backups are the only user-controlled copy that leaves that boundary. Files providers may
have their own sync behavior after the user chooses a destination.

This is not Android feature parity. It does not provide OCR, voice logging, StoreKit/commerce,
benefit checks, a weekly overtime calculation, Spanish localization, multi-employer profiles,
physical-device evidence, or Play release evidence. A confirmed configured-rules match is not a
legal determination or source/applicability review.

## Verification receipt

- Existing Android domain and backup suites: 141 JVM tests.
- Android app unit tests: 3 pass.
- Android `assembleDebug`, `assembleRelease`, and `lintDebug`: pass on the pinned wrapper and SDK 36.
- Connected instrumentation: 2 tests pass on the single synthetic Pixel 8/API 36 ARM64 emulator;
  the main journey saves a period-matched check, recreates the Activity, and reads the same saved
  result. Encrypted backup state round-trip passes on device.
- Manifest permission inspection found no `INTERNET` permission.

These checks are local host/emulator evidence. They do not establish a physical Android device,
Play Console, or complete cross-client/payroll parity result.
