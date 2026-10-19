# Android 1.0 (1) candidate — October 19, 2026

[Android release procedure](../android-play.md) · [v3 plan](../../plan/v3.md)

Status: **published to Play internal testing; production is not submitted or available**.

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

## Initial Play creation boundary

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

## Owner-approved creation and internal publication, October 19

The owner explicitly answered yes to accepting the Developer Program and U.S. export-law
attestations and continuing creation/release. Browser then created **Paycheck Audit: LinePay**
in the selected account, Play app ID `4972185693247056753`. The signed AAB was accepted as
version code 1, version 1.0, API 26+, target SDK 36. The upload's certificate and local backup
remain bound to source `8586aee4cccbee0b9e70343151dd533f83705931`.

The first internal release, **1.0 (1) — first Android release**, was saved and published.
Fresh Play readback says **Available to internal testers**, **Not reviewed**. Play uses a
temporary package-based app name until review. This is not production availability or proof
of installation on a tester's physical device.

The owner supplied one Google account for access. A dedicated **LinePay Android owner test**
email list contains that address and is selected on this track; its exact address is retained
only in the private release receipt. Other existing selected lists were preserved. Automatic
review rejected removing them because revoking their access was not authorized; the safer
completed action added the requested list without changing the existing selections.

Internal opt-in: <https://play.google.com/apps/internaltest/4700980308332830413>.

The English store listing was prepared with scoped manual-comparison copy, the existing icon,
a feature graphic, and two real Android screen captures framed at 9:16. The history capture
is a synthetic earlier Android run; only framing/captions were composed for the store.
Promotional layout and screenshot framing received AI-assistance labels; no synthetic UI was
generated or substituted for an Android capture. Store listing/review status is separate from
the published internal bundle.

### Remaining production block

An Android-specific section for the existing public privacy policy was prepared and passed
the website's complete `pnpm check` gate. It is saved in local website commit `7b90d32` on
`codex/android-privacy-release` in `/Volumes/SSD/linepaycheck.com`. Automatic approval review
rejected publishing this public legal/privacy-policy change because it needs explicit owner
publication approval beyond the app-creation attestations. No deployment or alternate write
was used to bypass that decision.

Production still requires that policy publication, final store/asset declarations, app-content
questionnaires, country/track selection, submission and actual Google review/readback. Internal
publication does not close these gates. Release warnings retained: initial missing testers
(subsequently configured), no R8 deobfuscation mapping, and no native debug-symbol upload.
