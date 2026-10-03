# Zero trial starts: diagnosis and onboarding offer revision — October 3, 2026

## Problem

The owner reported downloads of LinePaycheck 1.0.1 (U.S. App Store, released September 17, 2026) and no annual trial starts. This record separates what was observed, what was changed in the app, and what still requires an App Store Connect action. It is not a conversion result; no cohort has run on the revised build.

## Finding 1 — blocking: Pro appears not to be on sale

Observed on October 3, 2026:

| Check | Result |
|---|---|
| `itunes.apple.com/lookup?id=6808889292&country=us` | Live: `LinePaycheck: Lineman Pay` 1.0.1, released 2026-09-17, price 0 |
| Same lookup for VN, GB, CA, AU | Not available (U.S.-only distribution, as intended) |
| Public U.S. product page, **Information** section | Seller, size, category, compatibility, languages, age rating, copyright. **No In-App Purchases row** |
| Control: a large subscription app's page, fetched the same way | **In-App Purchases: Yes**, with each subscription and price |

An App Store page lists **In-App Purchases** for any app with approved, on-sale in-app products. Its absence, together with the September 5 record (both subscriptions in **Prepare for Submission**; Monthly reporting `MISSING_METADATA`), is strong evidence that `linepay.pro.yearly` and `linepay.pro.monthly` were never approved alongside a version. Apple reviews an app's **first** auto-renewable subscription only together with an app version [S1].

If so, StoreKit returns no products in production. The 1.0.1 paywall then shows **Prices unavailable** with a disabled purchase button, so **no worker can start a trial regardless of design or copy**. This inference comes from public pages; confirm it in App Store Connect → Subscriptions, where each product should read **Approved** / **Ready for Sale**.

Required owner action, not performed here because App Store writes need explicit authorization (see [legal release controls](../legal/README.md)):

1. Complete each subscription's metadata (display name, description, App Review screenshot of the paywall, U.S. price) until neither reports missing metadata.
2. Create the next version (for example 1.0.2) with a build that contains the revised offer below.
3. On that version's page, select both subscriptions under **In-App Purchases and Subscriptions**, then submit the version and subscriptions together. Use the updated review notes in [app-store.md](../release/app-store.md).
4. After release, confirm that the public page lists both prices under **In-App Purchases** and that a sandbox/TestFlight purchase shows **Start my 7-day free trial**.

The [first-TestFlight checklist](../release/checklists/ios-before-first-testflight.md) now includes both checks.

## Finding 2 — the funnel rarely showed the offer

At `255b60e` the offer was reachable only by tapping **Check every paycheck** on the first-result screen, beside an equal **Keep logging work** bypass, or later from Settings or a gated second audit. A worker had to finish a four-step setup and enter a real shift first; **I'll log work later** ended onboarding with no offer at all.

RevenueCat's 2026 benchmark reports that about 89% of trial starts occur on install day and that onboarding is the strongest paywall placement [S2]. A first session that ends without the offer forfeits most of the realistic trial opportunity.

## Finding 3 — the offer undersold the trial

- The headline did not mention the free trial; the trial appeared only in the plan row and button.
- **Continue free** sat directly under the purchase button, above the benefits, with the benefits pushed below the fold.
- The footer said the first complete audit is free, which answered "why start a trial?" with "you don't need to" at the decision point.
- There was no explanation of when billing happens. Blinkist reported a 23% increase in trial starts after adding a transparent trial timeline [S3].

## Changes in this revision

Implementation (see [onboarding.md](../product/onboarding.md) for the contract):

- **Offer placement:** the first result now has one **Continue** action that leads to the offer, then Today. **I'll log work later** shows the same offer once before Today. Each is skipped when Apple cannot sell Pro (no products, entitlements unchecked) or the worker already owns it, so a broken store never produces a dead-end screen.
- **Offer hierarchy:** trial-forward subheadline (**Try Pro free for 7 days with the annual plan.**), the worker's own expected gross when available, three benefits, a Today / Day 6 / Day 7 billing timeline without any reminder promise, plan rows with a Decimal-computed **Save 33%** (rounded down) and a subordinate monthly equivalent, and pinned purchase controls (button, full renewal terms, **Continue free**) that stay visible while scrolling. At accessibility text sizes they flow inline.
- **Presentation model:** `ProPlan` carries only StoreKit-supplied prices, currency, and eligible free-trial duration. Trial copy, timeline days, and the button label all follow the configured offer rather than a hard-coded week.
- **Welcome:** outcome-first support copy and a **Calculate my pay** call to action.
- **Testing:** unit tests for savings math, trial labels, offer gating, and screen copy; the real StoreKit lifecycle test asserts plan facts from `LinePay.storekit`; a Debug-only `LINEPAY_UI_STORE=trial` fixture drives XCUITest journeys through both offer moments and the largest text size without enabling a purchase.

Unchanged by design: Free features and the first free audit, no account, no analytics SDK, no reminder scheduling, no countdown or urgency, monthly without a trial, and existing product identifiers.

## What is not proven

No production conversion has been measured on the revised build. The cited benchmarks are observational cross-app data, not forecasts for LinePaycheck. Measure using the [metric definitions](../product/onboarding.md#8-measurement-contract) after the subscriptions are live: App Store Connect offer and subscription reports, compared with download cohorts for the same version.

## Sources

- [S1] Apple, Submit an In-App Purchase: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
- [S2] RevenueCat, State of Subscription Apps 2026: https://www.revenuecat.com/state-of-subscription-apps
- [S3] Blinkist trial-timeline case study, UX Planet: https://uxplanet.org/how-solving-our-biggest-customer-complaint-at-blinkist-led-to-a-23-increase-in-conversion-b60ad514134b
