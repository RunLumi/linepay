# Lineman Pay 1.1.0 (13) signed candidate — October 22, 2026

This records a local signed archive and IPA, not an upload, submission, published name change or release approval. The owner made the App Store name change the highest priority on October 22; unfinished portable-state adapters are outside this binary.

The archive was produced from clean merged source `32f46417d8bdeeffa7981061324976a678ede050`. Generated Xcode files were disposable outputs; the tracked checkout stayed clean throughout archive/export. The existing name change from PR127 is included.

| Evidence | Observed result |
|---|---|
| Embedded display name | `Lineman Pay` |
| Embedded bundle/version/build | `com.streamentry.linepay` / `1.1.0` / `13` |
| Archive and export | Both exited 0 using existing automatic signing, team `7MBXZKYSY4`; no provisioning-update flag |
| Archive signature | `codesign --verify --deep --strict` passed |
| IPA | 6,335,356 bytes; SHA-256 `010b2e44997be05249c9813f3048afd33d25309ee4d519531482546caddc2cba` |
| Privacy resource | `PrivacyInfo.xcprivacy` present; declared no collection/tracking |
| Encryption flag | Embedded `ITSAppUsesNonExemptEncryption=false` |
| Minimum OS and build SDK | iOS 18.0 minimum; Xcode 27.1, iPhoneOS 27.1 SDK |
| Offline controls | Agent doctor and active-copy/resource inventory checks passed |

The archive, dSYMs, IPA, source record, export logs and identity/hash receipt are retained privately on the release SSD outside Git. No credentials or private approvals are recorded here. Xcode 27.1 differs from the repository's 26.6 baseline; this archive does not establish pinned-toolchain CI success.

## Listing preparation

The [metadata candidate](../app-store.md) has been checked locally: name 11 characters, subtitle 25 characters, keywords 79 UTF-8 bytes, description 2,453 characters with the Standard EULA and privacy links retained. Length checks do not establish feature acceptance, name availability, trademark clearance or Apple approval. Apple permits changing the name when a new version or its status permits editing ([app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)).

Built-in Browser connected using its official client. App Store Connect is at password sign-in. The Apple Developer account displayed a program agreement accepted October 18; the Paid Applications Agreement in App Store Connect has not yet been reverified. The owner's earlier reply, “I’ll handle it,” is not acceptance evidence. No listing fields or agreement were changed in this run.

## Remaining gates

- Name availability, brand review and the owner risk decision still need source-bound evidence.
- Native CI and the accessibility findings remain unresolved. PR132's later `5e138c4` has additional adaptive-label fixes and local evidence, including 14 unresolved audit events; those changes are not in this archived main revision.
- Physical-device, VoiceOver and actual StoreKit/sandbox acceptance remain separate checks. The prior [build 12 receipt](ios-1.1.0-12-testflight-2026-10-20.md) does not clear them for build 13.
- Final build-bound screenshots, claim/permission/privacy review, selected Apple build and exact write authorization remain required by the [release procedure](../api-and-testflight.md) and [legal controls](../../legal/README.md).
- This IPA was not validated against Apple, uploaded or submitted. Build-number reservations must be read back before any upload. Manual release is intended but has not been saved/read back for a new App Store version.

If further app fixes are merged, archive and verify the new source before submission; do not describe this IPA as containing those fixes.

## Fresh Apple readback, October 22

The existing App Manager key `2HR347AH8Q` successfully read the intended app, builds, build-upload reservations, App Store versions and App Info. The app ID and bundle matched the intended product. All 12 build records and all 12 upload reservations were inspected; neither a processed build 13 nor a `1.1.0 (13)` upload reservation was observed. This observation must be refreshed before upload to handle concurrent activity.

The current App Store version is `1.0.5`, `READY_FOR_SALE`; `1.1.0 (12)` is a valid processed TestFlight build. No `1.1.0` App Store version or editable App Info was present. There is therefore no new-version release setting to place on a manual hold yet. The public U.S. listing independently showed `LinePaycheck: Lineman Pay`, subtitle `Overtime, Callout & Per Diem`, version `1.0.5`.

These were GET requests only. No version, build reservation, metadata, agreement, upload or submission was created or changed. The exact proposed name/subtitle/keywords/description and the verified credential reference are retained privately with the signed candidate. The issuer and private key are not included in this repository.

## Release retry, October 23, 2026

The owner requested latest-source integration, the v3 name and a new iOS release, then limited
merge scope to validated iOS release fixes. Fetch and fast-forward reconciliation confirmed
`main` was already current at `484cc017a7dd5695a8ea9bc8124933e66bbbad3e`. That revision already
sets `CFBundleDisplayName` to **Lineman Pay**, version `1.1.0`, build `13`; the installed bundle
identity remains `com.streamentry.linepay`. No Android, web or portable-state PR was selected.

Fresh authenticated GET requests verified the intended app and inspected all 12 build and upload
records without a next page. App Store Connect still returned **LinePaycheck: Lineman Pay**,
`1.0.5 / READY_FOR_SALE`; the latest processed candidate was `1.1.0 (12) / VALID`. No build 13,
build-13 reservation, editable App Info or 1.1.0 App Store version was observed. The retained
build-13 IPA's embedded identity and SHA-256 were independently rechecked and matched the table
above. No Apple write, upload, submission, tester notification or public release was performed.

PR #132 remained draft with native checks queued; the sole configured iOS runner was offline.
Its head `d0e20b6ee3fbe4ebb6efcc70ca098b7baf908e26` was combined with current main in an independent
local clone at integration commit `9c5829c`. That integration was **not pushed or merged**.
Local validation used Xcode 27.1 and the existing iOS 18.5 LinePay release simulator. No device or
runtime was created or erased, and unrelated backups were preserved.

The native gate passed Swift lint, the privacy-manifest check, 166 domain tests, 83 repository
script tests and all 353 app tests. Unlike the previous candidate run, the real local StoreKit
billing-grace test passed (60.239 seconds). Both audit/offer journeys, the largest-dark worker
reachability journey and the Today status-wrap journey passed. Apple's full accessibility audit
failed with **15 events: 10 partial Dynamic Type, 4 contrast and 1 clipping**. Those findings must
not be silently filtered into a pass. After the failed mandatory audit, the remaining UI run was interrupted deliberately; the
second benefits journey was in progress. Five completed UI cases passed and the Apple audit case
failed. The full native gate did not pass, and the subsequent Release build was not reached.

The private release directory still contained no source-bound release-approval bundle. Final
candidate/device and VoiceOver acceptance, actual StoreKit sandbox acceptance, privacy and
permission/encryption review, naming/confusability review, final build-bound screenshots and the
exact Apple write evidence remain required. A prepared `POST /v1/appStoreVersions` payload for
1.1.0 with manual release is only a local draft, not an executed or approved request. The owner's
request is recorded as release intent; it is not fabricated evidence that those reviews passed.
