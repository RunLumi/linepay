# iOS before first TestFlight checklist

Use this checklist before the first build is distributed outside development. Its purpose is to catch decisions that become annoying or irreversible once users have data or App Store records exist.

## Identity and signing

- [ ] Confirm the final Apple Developer team/legal entity.
- [ ] Confirm the final bundle identifier. Treat it as stable after distribution begins.
- [ ] Confirm app display name and App Store name availability.
- [ ] Confirm production entitlements. Do not enable capabilities speculatively.
- [ ] Keep signing identities/profiles out of git.

## Deployment and compatibility

- [ ] Re-evaluate the iOS 18 minimum using actual prospect/device evidence.
- [ ] Test at least the minimum supported iOS and the current iOS release.
- [ ] Test a small-screen and large-screen iPhone.
- [ ] Verify Dynamic Type, VoiceOver, dark mode, locale/currency formatting, and reduced-motion behavior where relevant.

## Money and time

- [ ] No currency calculation uses `Double`/`Float`.
- [ ] Rounding behavior is explicit and covered by tests.
- [ ] Test shifts across midnight.
- [ ] Test DST spring-forward and fall-back boundaries.
- [ ] Test pay-period boundaries.
- [ ] Test Sunday/holiday semantics only from explicit rule definitions.
- [ ] Test the user's selected work timezone differing from the device's current timezone.

## Persistence and migrations

If persistence exists by this point:

- [ ] First shipped schema is explicitly versioned.
- [ ] Stable domain identifiers do not depend on database object identity.
- [ ] Raw work facts are stored, not only derived totals.
- [ ] Historical calculations preserve/reference the exact agreement/rule snapshot used.
- [ ] A representative store created by the oldest supported schema migrates successfully to the release schema.
- [ ] A migration failure does not silently destroy user data.
- [ ] Export/recovery strategy is documented before users accumulate valuable history.

## OCR and documents

If paystub scanning exists:

- [ ] Prefer document/photo pickers that request the narrowest practical permission.
- [ ] OCR runs locally by default.
- [ ] Original evidence and parsed facts remain distinguishable.
- [ ] Material low-confidence fields require confirmation before reconciliation.
- [ ] Logs/crashes never contain raw paystub text or images.
- [ ] Synthetic fixtures cover common layouts and OCR failures.

## Privacy and security

- [ ] Review `PrivacyInfo.xcprivacy` against the actual binary and dependencies.
- [ ] Review required-reason API declarations.
- [ ] App Store privacy answers match actual collection, not marketing intent.
- [ ] No tracking/ad SDK exists unless an explicit decision changed the privacy architecture.
- [ ] No secrets, real paystubs, or personally identifying wage data exist in repo/test fixtures.
- [ ] Sensitive values are redacted from application logging.
- [ ] Data deletion/export behavior is understandable to a user.

## StoreKit

If subscriptions exist:

- [ ] Product identifiers are chosen deliberately before production creation.
- [ ] Purchase and restore are tested with StoreKit configuration/sandbox.
- [ ] Active, expired, revoked, grace-period, and billing-retry states are handled.
- [ ] Transaction updates are observed correctly across launches.
- [ ] Calculation correctness and access to the user's existing records do not depend on a successful App Store network call.
- [ ] Paywall copy communicates what Pro unlocks without implying legal certainty.
- [ ] Annual introductory offer is configured and tested as seven days free; Monthly has no introductory trial.
- [ ] Trial copy depends on both actual offer metadata and eligibility; full renewal price and cancellation timing are visible.
- [ ] Sandbox/TestFlight proves eligible purchase, ineligible purchase, trial-to-paid, expiry, and restore; a saved App Store offer is not purchase-path proof.

## Release engineering

- [ ] CI passes from a clean checkout on the pinned/current supported Xcode line.
- [ ] Application dependency lockfiles such as `Package.resolved` are committed when present.
- [ ] No compiler warnings in our code.
- [ ] Archive/Release build succeeds, not only Debug.
- [ ] Crash reporting choice is explicit; if absent, that is deliberate too.
- [ ] Version/build-number strategy is documented and automated before frequent beta releases.

## Product truth

- [ ] Every preset rule shown as verified has a source and effective version.
- [ ] The app says “expected”, “estimated”, or “possible discrepancy” where certainty is not warranted.
- [ ] No AI/OCR output silently becomes a pay entitlement.
- [ ] A worker can understand *why* a discrepancy was flagged and which input/rule caused it.

If any unchecked item can cause data loss, incorrect money, privacy leakage, or an irreversible App Store identity decision, fix it before distributing the build.
