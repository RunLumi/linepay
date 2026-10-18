# LinePaycheck Android

The owner authorized native Android for the v2 work on October 16, 2026. The client uses Kotlin
and Jetpack Compose. Payroll data remains in app-private local storage; the app has no LinePaycheck
account, backend, network permission, ad/analytics SDK, or Android automatic backup.

## Current product slice

- `domain` contains the independent exact-money configured-pay, benefit, calendar-period, gross
  comparison, and earnings/hour comparison engines. Calculation provenance remains
  `linepay.android.configured-pay/1`; this does not claim parity with the Swift engine or complete
  legal coverage.
- `app` provides pay-rule setup, exact-time work entry with explicit unpaid breaks and payroll
  timezone, expected pay, source-period-confirmed gross checks, a saved-check history, and local
  settings. Saved checks keep the work/rule/source facts and result that were used at the time.
- A versioned `AtomicFile` stores worker data in the app sandbox. Android cloud backup is disabled.
  The separate device-local activity ledger is opt-in and excluded from pay-data backups.
- The Files picker supports password-protected manual pay-data backup and an explicit review before
  replacing local data. Diagnostic export contains only opt-in coarse usage counts, not wages or
  pay dates.
- User confirmation can remove review reasons only for the stated configured-rule scope. Weekly-rate
  review, agreement applicability, eligibility, and unconfigured rules are not inferred or verified.

This is a first Android vertical slice, not full feature parity. Android OCR/voice/StoreKit, line-level
paystub entry, full weekly overtime review, multiple employer profiles, Spanish localization, and
Play distribution remain outside this tested slice. App Store release evidence remains an iOS gate.

## Toolchain

JDK 21 runs Gradle; bytecode targets JVM 17. The repository pins Gradle 9.4.1, Kotlin/KGP 2.4.0,
Android Gradle Plugin 9.2.0, Compose BOM 2026.06.00, compile/target SDK 36, and min SDK 26. AGP 9.2
still requires the temporary `android.builtInKotlin=false` and `android.newDsl=false` compatibility
settings for the pinned Kotlin Android plugin; revisit that opt-out with a deliberate compiler
migration rather than changing plugin versions independently.

For a local SDK, keep command-line tools, SDK packages, emulator images, and Gradle caches in the
ignored repository `.build` directory. No global shell profile is required.

## Verification

With the repository SDK provisioned at `.build/android-sdk`:

```bash
bash scripts/check-android.sh unit
```

This runs the Swift-independent Android domain and backup JVM suites, app unit tests, debug and
release APK builds, and Android lint with strict dependency verification. When the task's
`LinePaycheck_E2E_API_36` emulator is online, run the black-box instrumentation journey and encrypted backup
round-trip with:

```bash
bash scripts/check-android.sh device
```

The repository's Maestro flow drives the same first-check journey through Android's
accessibility/resource-id tree. To install the pinned CLI locally under `.build` and run that flow
with Maestro analytics disabled:

```bash
bash scripts/install-maestro-cli.sh
bash scripts/test-android-maestro.sh
```

`bash scripts/agent-verify.sh android-ui` runs both the instrumentation and Maestro journeys. The
Compose semantics tags are part of the automation surface; keep them stable when visible copy changes.
The checked-in Maestro first-check flow lives at `.maestro/android/first-paycheck.yaml`; its pinned
CLI installer verifies the official 2.11.0 archive digest and runs with analytics disabled.

The scripts require exactly one online emulator, verify its AVD name, and refuse to reset a physical
device. The locally created Pixel 8/API 36 ARM64 AVD is stored under
`ANDROID_AVD_HOME="$PWD/.build/android-avd"`; boot it with `-no-metrics` to keep emulator usage
reporting disabled. Maestro clears only this synthetic app state and removes only the backup file it
created in the AVD's Downloads folder. Test XML and APKs stay under ignored module `build/` directories.

The app UI, persistence, history, and manual backup were tested on one synthetic Pixel 8/API 36
emulator, including a 200% system font-size instrumentation run. This is device-runtime evidence
for that image only, not a physical-device or Play Store release result.
