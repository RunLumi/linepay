# Release 1.0.2 (5): submission record — October 3, 2026

This is a point-in-time record of what happened. It is not App Review approval, a storefront release, or legal clearance.

## Outcome

Each state below was read back through the App Store Connect API after submission (2026-10-03 06:51 UTC):

| Item | State |
|---|---|
| App Store version `1.0.2`, build `5` | `WAITING_FOR_REVIEW`, `releaseType: MANUAL` |
| `linepay.pro.yearly` (subscription version 1) | `WAITING_FOR_REVIEW` |
| `linepay.pro.monthly` (subscription version 1) | `WAITING_FOR_REVIEW` |
| Group `LinePaycheck Pro` (group version 1) | Included in the same review submission |
| TestFlight, internal group `tests` (access to all builds) | `IN_BETA_TESTING` |

The annual introductory offer was verified as `FREE_TRIAL`, `ONE_WEEK`, territory `USA`. Both products are available in the U.S. only, at $79.99/year and $9.99/month.

## Why this release matters

Before this submission both subscriptions were `READY_TO_SUBMIT`. They had never been reviewed, so production StoreKit returned no products and no one could start a trial on 1.0 or 1.0.1. See the [trial conversion diagnosis](../../research/trial-conversion-2026-10-03.md). The binary contains the onboarding trial offer from PR #92.

## Owner decisions

- **Legal release evidence gate waived.** The owner explicitly chose to submit without the 21-finding evidence bundle described in [legal controls](../../legal/README.md). As a result, `scripts/asc-api.py` refused the writes. They went through a one-off client that reuses its token code; the repository guard is unchanged. This record does not close any LEGAL issue.
- **Full iOS CI gate not run.** The self-hosted `linepay-ios` runner was offline. StoreKit lifecycle tests did not run on the pinned toolchain, so TestFlight is the first purchase-path check.

## Build and signing

- Source: `release/1.0.2` at `aa4eceb` (PR #93), with a clean tree after `xcodegen generate`.
- Archive: Release, 1.0.2 (5), `com.streamentry.linepay`, team `7MBXZKYSY4`. `codesign --verify --deep --strict` passed and `PrivacyInfo.xcprivacy` is bundled.
- Builds 1–4 already existed (3 and 4 were for 1.0.1). Always list builds before choosing a number.
- **Two-certificate gotcha.** The build Mac has two "iPhone Distribution: CLOUDJET SOLUTIONS PTE. LTD." identities. The Xcode-managed Store profile includes only one of them, so `xcodebuild -exportArchive` picked the other and failed with "profile doesn't include signing certificate". The owner uploaded through Xcode Organizer instead. Removing the unused certificate avoids this.

## API sequence that worked for first subscriptions

`POST /v1/subscriptionSubmissions` returns `409 STATE_ERROR.FIRST_SUBSCRIPTION_MUST_BE_SUBMITTED_ON_VERSION`. It fails even while an app version is in an open review submission. What works is putting the subscription **versions** inside the same review submission as the app version:

1. `POST /v1/appStoreVersions` with `versionString: 1.0.2`, `releaseType: MANUAL`.
2. `PATCH` the version's localization `whatsNew`, and its `appStoreReviewDetail` notes.
3. `PATCH /v1/appStoreVersions/{id}/relationships/build` with the processed build.
4. `POST /v1/reviewSubmissions` with `platform: IOS` and the app relationship.
5. `POST /v1/reviewSubmissionItems`, one per item:
   - `appStoreVersion`;
   - `subscriptionVersion` for each subscription (ID from `GET /v1/subscriptions/{id}/versions`);
   - `subscriptionGroupVersion` (ID from `GET /v1/subscriptionGroups/{id}/versions`).
6. `PATCH /v1/reviewSubmissions/{id}` with `submitted: true`.

## Credentials (no secrets here)

Writes used the team API key whose `.p8` lives in `~/.appstoreconnect/private_keys/` on the build Mac. The key ID, Issuer ID, and backups of keys and certificates are kept in the owner's private key backup outside this public repository. Ask the owner for them; never commit them.

## After review

- After approval, confirm that the public U.S. product page lists **In-App Purchases** with both prices.
- Install from the App Store and confirm the offer shows real prices and **Start my 7-day free trial**.
- Release manually.
- Measure trial starts with App Store Connect subscription reports.
