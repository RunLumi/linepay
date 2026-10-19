# Android 1.0 (1) candidate — October 19, 2026

[Android release procedure](../android-play.md) · [v3 plan](../../plan/v3.md)

Status: **signed local candidate; not created, uploaded, submitted or published in Play**.

The owner requested Android app creation and release through Browser, and a backup of the
signing key and passwords under `backups/`. The candidate keeps package
`com.streamentry.linepay.android`, version `1.0`, code `1`, uses **Paycheck Audit: LinePay**,
and reuses the existing brand icon. No payroll rules, stored data format or network permission
were changed for this packaging work.

## Actual local verification

- Strict Android gate: 137 domain, 4 backup and 3 app JVM tests; debug/release APK builds and
  debug lint passed. Log: `.build/android-play-unit.log`.
- Signed AAB, signed release APK and release lint passed. The release script requires all
  signing variables and refuses a bundle whose signature is not verified. Log:
  `.build/android-play-signed-verification.log`.
- The bundle signer matches the recovered upload-key certificate. APK inspection confirms
  the exact package/version/name, no `INTERNET` permission and no debuggable flag.
- Two instrumentation tests passed on the existing `LinePaycheck_E2E_API_36` ARM64/API 36
  emulator. The checked-in Maestro first-paycheck/backup journey passed **1/1**, in 2m53s.
  These automated journeys used the debug app, separately from release signature inspection.
  Log: `.build/android-play-ui.log`; JUnit: `.build/maestro-results/android-first-paycheck.xml`.
- The signed release APK was then installed on that same synthetic emulator and cold-launched
  successfully to pay-profile setup. Screenshot: `.build/android-play-release-launch.png`;
  accessibility hierarchy: `.build/android-play-release-window.xml`.
- Five documentation-tool tests and the legal active-copy/inventory check passed. A source-only
  documentation snapshot passed link checking. The shared checkout's broad link scan also crawls a
  generated Android test asset README and reports its missing parent link; this is not a broken
  source-document link and remains visible as a scanner limitation.

The private dated recovery folder contains the upload key, its public certificate, plaintext
password recovery files, signed artifacts, a candidate receipt and verified checksums. It is
excluded from Git, with directory mode 0700 and file mode 0600. This is one copy on the same
disk, not proof of an independent off-device backup. Google Play's separate distribution
private key is not part of this backup.

## Play and publication boundary

Browser confirmed no existing LinePay listing in the selected Cloudjet Solutions PTE. account
and confirmed the package name is available. The new-app form has the v3 name, package,
English (United States), App and Free selected.

Automatic approval review rejected the next action because creating the app certifies
Developer Program and U.S. export-law compliance, including encryption requirements. The
owner authorized release but had not explicitly approved these legal attestations. No alternate
interface was used to bypass that rejection. The form remains ready for owner approval.

The live privacy/support pages were inspected in Browser and currently describe iPhone
behavior. Accurate Android policy/support coverage, actual Play questionnaires/listing assets,
track requirements, review submission and production readback remain outstanding. Do not
call this a v3 feature-parity release or a published Android app.
