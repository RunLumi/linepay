# Android Play release evidence — October 19, 2026

[Android release procedure](../android-play.md) · [v3 plan](../../plan/v3.md)

Status: **1.0.1 (2) is available in internal testing; its U.S. production changes are in Google review, not publicly available**. Earlier checkpoints below retain their original scope.

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

### Production block at the initial checkpoint

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

## 1.0.1 (2): verified production review and internal update

- Source: `301b916866585890f8df855c54d7bd6982b7c3d2`, local branch
  `codex/android-play-release`; package unchanged. Version 1.0.1/code 2 adds a direct
  `https://linepaycheck.com/privacy#android` action in Settings and corrects Pay-screen error
  rendering. A nullable optional review message previously made a successfully calculated
  period also show an unavailable-period error. The engine, work facts, rule snapshots and
  saved $200 matching comparison were unchanged; an instrumentation assertion now rejects
  that false error. Genuine unavailable-period errors remain visible.
- The owner explicitly approved public Android privacy-policy publication, IARC terms/contact
  sharing, and publication of the existing public business contacts. The Android section is
  live at `https://linepaycheck.com/privacy`, website source `7b90d32`, Worker version
  `08b196dc-fa6a-4088-933b-6774e0941645`. Website `pnpm check` passed; live verification used
  33 read-only requests and matched 20 assets to local SHA-256. Browser independently found
  the Android policy section. This supersedes the earlier publication-approval block.
- Play setup was completed: no sign-in/paywall restrictions, no ads or advertising ID,
  non-government, no health features, adult-worker audience 18+, Finance category, public
  support email/website, and local-only Data safety. Financial features use **Other**, with
  the exact calculation/comparison scope and exclusions disclosed; Play required no additional
  financial documentation. IARC returned ESRB Everyone/PEGI 3 and equivalent regional ratings.
  These are provider questionnaire results, not independent payroll or security certification.
- Final Android JVM/build/debug-lint gate passed: 137 domain, 4 backup, 3 app tests;
  `.build/android-play-v2-final-unit.log`. The final two instrumentation tests, including the
  false-error regression, passed, followed by the complete Maestro work → paycheck → history
  → encrypted backup → reviewed restore journey **1/1 in 4m29s** at the existing **200% text,
  dark** emulator settings; `.build/android-play-v2-final-ui.log`.
- Earlier interrupted instrumentation receipts and failed Maestro captures remain retained.
  Large-text tapping placed the timezone caret mid-value, so backspacing left `UTCcago`;
  explicit native selection and exact field assertions fixed that automation defect. Date
  inputs can already be fully selected, so their Select-all menu action is conditional while
  the exact replacement-value assertions remain mandatory. The final flow scrolls to the
  saved comparison before asserting visibility.
- A separate visible-policy-action smoke flow passed and launched Chrome's FirstRunActivity;
  Chrome terms were not accepted. The policy page's content was verified separately in the
  desktop Browser. This is not proof of a completed Android-browser page load. Captures live
  under `.build/maestro-home/.maestro/tests/2026-10-19_161447/`.
- Signed AAB/APK verification and release lint passed; `.build/android-play-v2-signed-final.log`.
  The upload certificate matches the original recovered key. Package/version, non-debuggable
  flag and absence of network permission were inspected. UI journeys used the debug variant;
  signed release-artifact inspection is separate evidence.

| Artifact | SHA-256 |
|---|---|
| AAB | `608da2724903d38ca5fee9e719ddca2266b69676a31cc1aef445aafad929ea51` |
| Release APK | `463ebd5c862ea2eccc830e712c46ed39747cfc31c999d260e353e3986572f874` |

Play accepted bundle 2 (1.0.1), min API 26/target SDK 36. Fresh Publishing overview readback
shows **Changes in review**, including **1.0.1 (2) — first production release**, full rollout,
and **United States only**. Managed publishing is off. No duplicate submission or withdrawal
was performed when the existing in-review state was discovered. Google approval and public
storefront availability are not yet proven.

The same existing bundle was then published to internal track `4700980308332830413` as
**1.0.1 (2) — verified production candidate**. Fresh readback shows Active and Available to
internal testers. The previously authorized tester list remains selected. Screenshots:
`.build/android-play-production-in-review.png` and `.build/android-play-internal-v2.png`.
Only the two existing diagnostics warnings remain: absent deobfuscation mapping and native
debug symbols. No test, requirement or warning was disabled to publish.

The key/password recovery directory remains Git-ignored and owner-only. Version 1 artifacts
remain intact; version 2 artifacts and their source-bound receipt are under
`backups/android-play-20261019/releases/2/`. The root SHA-256 manifest covers both versions
and all signing recovery files. Google-held distribution private-key custody is unchanged.

After the final QA and policy-action smoke, the existing emulator was handed exclusively to
the owner-authorized **Complete v2 and release** chat for its requested QA window. This chat
does not install, reset or interact with that AVD during the handoff.
