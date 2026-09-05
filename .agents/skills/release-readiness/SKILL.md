---
name: release-readiness
description: Prepare or review LinePaycheck for TestFlight, App Store submission, signing/configuration, privacy, StoreKit, versioning, or release-critical changes.
---

# LinePaycheck release-readiness workflow

Release work is a verification task first and a configuration task second.

## 1. Load canonical release context

Read:

- `AGENTS.md`
- `apps/ios/AGENTS.md`
- `docs/best-practices.md`
- `docs/checklists/ios-before-first-testflight.md`
- `docs/appstore.md` when store metadata/positioning is in scope

Public brand is **LinePaycheck**. Preserve bundle ID **`com.streamentry.linepay`** and existing technical target/scheme names unless the user explicitly requests a migration.

## 2. Identify release surface changed

Classify the task:

- build/version/signing;
- entitlements/capabilities;
- privacy manifest/data collection;
- StoreKit/products/paywall;
- persistence/migration;
- OCR/camera/photo/file permissions;
- App Store metadata/screenshots;
- critical user journey.

Check only the relevant surfaces, then run the full release gate before handoff.

## 3. Protect irreversible identity

Before changing project identity, verify:

- `PRODUCT_BUNDLE_IDENTIFIER` remains `com.streamentry.linepay`;
- home-screen display name remains `LinePay`, while the public product and bundle name remain `LinePaycheck`;
- version/build numbers move intentionally;
- no accidental target/scheme/module rename breaks CI/scripts/TestFlight continuity.

Do not “clean up” internal `LinePay*` names during release work.

## 4. Privacy and data flow

Verify:

- `PrivacyInfo.xcprivacy` is valid and bundled;
- required-reason APIs are declared when used;
- permissions describe the actual user-facing need;
- no real wage/paystub data is present in logs, fixtures, screenshots, or crash metadata;
- no analytics/tracking/backend data flow was added without deliberate architecture review.

## 5. Persistence safety

If persisted models changed:

- identify source and destination schema versions;
- run migration tests on representative synthetic fixtures;
- verify stable identifiers and historical rule snapshots survive;
- verify failed migration/recovery behavior does not silently discard worker history.

No release with an untested destructive migration.

## 6. StoreKit safety

If commerce is enabled/changed:

- verify product IDs and App Store configuration;
- verify purchase, cancellation, pending, restore, expiration/revocation/entitlement behavior as applicable;
- never grant Pro on an unverified transaction;
- keep pay-calculation correctness independent of commerce state;
- verify Free users are not trapped by a failed/unavailable store.

## 7. Build and critical-flow gate

Run:

```bash
bash scripts/agent-doctor.sh
bash scripts/agent-verify.sh ios
```

For a release candidate with local Maestro available:

```bash
bash scripts/agent-verify.sh ui
```

Also complete the checked-in TestFlight checklist. Do not claim App Store/TestFlight readiness solely from a successful compile.

## 8. Inspect the archive-facing configuration

Review generated/effective settings for:

- bundle/display name;
- marketing version/build number;
- deployment target/device family;
- Info.plist usage strings;
- entitlements/capabilities;
- Release warnings;
- privacy manifest inclusion.

Treat warnings in release configuration as defects unless explicitly understood and accepted.

## 9. Handoff

Report:

- release surface changed;
- identity/privacy/persistence/StoreKit implications;
- exact gates run and their results;
- any action that still must occur in Apple Developer/App Store Connect;
- any reason the build is not yet safe to distribute.
