# Release 1.0.3 (8): resubmission record — October 3, 2026

This is a point-in-time record of what happened. It is not App Review approval, a storefront release, or legal clearance.

## Why 1.0.2 was rejected

App Review stopped 1.0.2 (5) with an automated metadata issue (Guideline 3.1.2): the submission offers auto-renewable subscriptions but the App Store description had no functional link to the Terms of Use (EULA). In-app links and the website do not satisfy this; the link must be in the product-page metadata.

At the same time, `linepaycheck.com/support`, `/privacy`, and `/terms` still described a planned, in-development app with no subscription offer. They were rewritten for the shipping app and deployed (website PR RunLumi/linepaycheck.com#7, Worker version `6368d3d8`, `pnpm verify:live` passed).

## Outcome

Each state below was read back through the App Store Connect API after submission (2026-10-03 15:52 UTC):

| Item | State |
|---|---|
| App Store version `1.0.3`, build `8`, `releaseType: MANUAL` | `WAITING_FOR_REVIEW` |
| `linepay.pro.yearly` (subscription version 1) | `WAITING_FOR_REVIEW` |
| `linepay.pro.monthly` (subscription version 1) | `WAITING_FOR_REVIEW` |
| Group `LinePaycheck Pro` (group version 1) | `WAITING_FOR_REVIEW` |

## What changed in App Store Connect

- The developer-rejected 1.0.2 version was renamed to `1.0.3` instead of creating a new version, so review notes, contact, and other metadata carried over. Build 8 (`c59b4bc`) was already attached.
- The en-US description gained a subscription disclosure, `Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`, and `Privacy Policy: https://linepaycheck.com/privacy`. The canonical copy is in [App Store metadata](../app-store.md).
- What's New keeps the 7-day annual trial text (1.0.2 never shipped) and adds the 1.0.3 fixes.
- A new review submission held the app version, both subscription versions, and the group version, then was submitted. The first-subscription sequence from the [1.0.2 record](release-1.0.2-2026-10-03.md) applies unchanged; `DEVELOPER_REJECTED` subscription versions can be added to a new submission directly.

## Owner decisions

- **Legal release evidence gate waived again.** `scripts/asc-api.py` refused the writes; they went through a one-off client that reuses its token and request code. The repository guard is unchanged. This record does not close any LEGAL issue.
- **StoreKit lifecycle tests not run on build 8.** TestFlight remains the first purchase-path check.

## After review

- After approval, confirm the U.S. product page shows the Terms of Use link and **In-App Purchases** with both prices.
- Release manually, then install from the App Store and confirm the trial offer shows real prices.
