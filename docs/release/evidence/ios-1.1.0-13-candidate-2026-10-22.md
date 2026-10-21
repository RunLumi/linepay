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
