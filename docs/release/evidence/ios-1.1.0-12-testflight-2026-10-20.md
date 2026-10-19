# iOS 1.1.0 (12) internal TestFlight — October 20, 2026

Candidate for the v3 "Paycheck Audit" positioning release. This records an **internal TestFlight upload only**.
It is not an App Store submission, public release, metadata change or legal approval.

Source: `cb99c12de7da983db2b8c686703fa31d70a8bee6` (merge of [PR124](https://github.com/RunLumi/linepay/pull/124)),
clean checkout. Version `1.1.0`, build `12`, bundle `com.streamentry.linepay`, display name `LinePay`.

| Item | Result |
|---|---|
| IPA SHA-256 | `1be79008db923ab60f64727a45342712b91def7dea9a14fe2ce1f7088194ac7c` (6,334,926 bytes) |
| Signing | Automatic, no `-allowProvisioningUpdates`; iPhone Distribution, team `7MBXZKYSY4`; `codesign --verify --deep --strict` passed |
| Bundle | Privacy manifest bundled (no collection, no tracking); opaque icon; system frameworks only; `ITSAppUsesNonExemptEncryption=false` |
| Validation / upload | `altool --validate-app` succeeded; owner-authorized `--upload-package` succeeded, delivery reused the validation-created `buildUpload` for build 12 |
| Apple processing | Build `12a94fc3-5f51-43ea-b2d5-0983da5eb60d`: `processingState=VALID`, `expired=false`, pre-release version `1.1.0` |
| TestFlight | Internal group `tests` (auto-access): `internalBuildState=IN_BETA_TESTING`; external state `READY_FOR_BETA_SUBMISSION` and not submitted |

`altool --validate-app` under Xcode 27 reserves the build number in App Store Connect (an `AWAITING_UPLOAD`
buildUpload). The later upload attached to that reservation; no duplicate was observed.

## Gate state and limits

- **Toolchain deviation:** built with Xcode 27.1 / iOS 27.1 SDK; the repository pins Xcode 26.6. Hosted CI on the pinned toolchain is the authoritative native gate.
- **Local native gate (Xcode 27.1, iOS 18.5 simulator):** 387 passed, 1 skipped, 3 failed.
  - `AccessibilityAuditJourneyTests`: 17 audit issues. 16 occur identically at the pre-v3 baseline `7f5da5f`; the one new v3 finding is the Today work-row label clipped when the v3 status copy ("No difference within compared items: gross total only") wraps to two lines.
  - `CrewRuleJourneyTests` largest-text Files adoption: fails at the same assertion at baseline; the Files picker stays on Recents with an unsubmitted search.
  - `StoreKitLifecycleTests.billingGraceKeepsAccessThenExpires`: killed by the known Xcode 27 StoreKit-test hang on this host.
- **Hosted CI on PR124:** `UI (compact-dark-large-text)` passed on iOS 18.5; `UI (standard-light)` on the iOS 26.5 simulator failed 7 of 9 Maestro flows on `keyboard.done` (sheet form rows ignore taps there), reproduced on clean `main` without v3 changes. Unresolved.
- **Not done:** physical-device and StoreKit sandbox/TestFlight purchase testing, VoiceOver audit, App Store version/metadata/screenshots upload, review submission and public release. Those need the owner's release evidence (`python3 scripts/legal_guardrails.py release --stage submission`) and exact per-request approvals.
