# Release 1.0.4 (9): review, international entry, and trial clarity — October 4, 2026

This is a point-in-time record of what happened. It is not App Review approval, a storefront release, or legal clearance.

## Why this release

On October 3, 2026 sales were extended from the U.S. to Canada and Vietnam. A whole-app review on an `en_VN` simulator, driving the shipped 1.0.3 flows against live sandbox StoreKit products, found that the app still assumed U.S. dollars and U.S. number entry, and that the paywall and its follow-up moments could be clearer.

## Findings and fixes

| Area | Finding | Fix |
|---|---|---|
| Currency | Every profile was created in `USD`, so a Canadian or Vietnamese worker could not record their pay. | Setup offers USD, CAD or VND, suggested from the region. The currency is fixed once a profile exists, so no saved calculation changes denomination. VND profiles round to whole đồng. |
| Number entry | `StrictDecimal` accepted only `1,234.56` and capped amounts at 10,000,000, so `58,40`, `1.234,56` and an ordinary 15,000,000 ₫ paycheck were rejected. | The parser takes an explicit decimal separator (still no locale inside the domain). The app passes the region's separator; a lone `58.40` stays unambiguous in comma regions; zero-decimal currencies accept paycheck-sized amounts. The OCR parser keeps the U.S. paystub grammar. |
| Money display | Amounts always showed two decimals (`467.200,00 ₫`). | The currency's own minor units. |
| Paywall timeline | "Day 6 / Day 7" made the worker count. | Real dates for the reminder day and the billing day. |
| Trial reminder | None; a worker had to remember the billing date. | Opt-in **Remind me before I'm charged** (on by default). Permission is asked only after a trial starts; one local notification two days before billing; removed when the trial is cancelled or converts. Lock-screen text names the plan price and date, never pay data. |
| Post-check offer | After the free check, Pro was a small text link. | A primary **Try Pro free for 7 days** action, naming the possible shortfall the check found when the result is current. |
| Repeat last shift | Repeating the last day of a period opened on that same day, in conflict, with Save disabled. | Proposes the most recent earlier free day in the period. |
| Paystub review | The bar said "Answer the two questions below" although they are above it and one may be answered. | Names exactly what is left. Empty optional lines read **Optional**, not an amber **Check**. |
| Visual | On iOS 26 scrolled text collided with the navigation title and Back button; full-width list buttons had a stray half-width separator. | Hard top scroll edge on iOS 26+; separators span the row. The Pay tab uses a currency-neutral icon. |

## Verification

All runs on the `en_VN` iPhone simulator (iOS 26.5, Xcode 27.0), app tests pinned to `en`/`US`.

| Check | Result |
|---|---|
| `swift format lint --strict` on changed files | Passed |
| `agent-verify.sh quick` | Passed: 108 domain tests, 59 script tests |
| App tests (Swift Testing) | Passed: 233, including new `CurrencyEntryTests`, comma-decimal `StrictDecimal` cases and the end-of-period repeat regression |
| UI journeys (XCTest) | Passed: 11 in the final run. `testEachRuleScopeKeepsItsPromisedEffectAtLargestText` passed in the previous run of the same tree and self-skipped in the final run because the hosted simulator did not expose a menu option at the largest text size |
| `legal_guardrails.py check` | Passed after recording the `project.yml` version-bump hash |
| `StoreKitLifecycleTests` (local `SKTestSession`) | **Did not run to completion on this host.** All cases fail in session setup (`AppStore.sync`), before app code: `userCancelled` on this branch, 300 s timeouts on unchanged `main` (`ae38273`). The simulator has no Apple Account. The suite must be rerun on the CI runner |
| Live StoreKit in the simulator | The Debug build with commerce enabled loaded both real products from Apple and an eligible one-week free trial (U.S. sandbox storefront): **Start my 7-day free trial**, then $79.99 per year |
| Simulator walkthrough | Fresh install in Vietnam: VND suggested, `45.000` accepted, ₫45.000/hr, 8 h = ₫360.000; dated trial timeline (today, reminder day, billing day) with the reminder switch; separators and top edge |

## App Store Connect

| Item | State (read back through the API) |
|---|---|
| Build `9` (`1.0.4`), delivery `f9e7de8c-5cd0-4156-a0c8-c8a9154279b0` | `VALID`; `altool --validate-app` reported no errors |
| App Store version `1.0.4` | `WAITING_FOR_REVIEW`, `releaseType: AFTER_APPROVAL`, submitted 2026-10-04 01:31 UTC |
| Description | Keeps the Standard EULA and privacy links; USD prices removed (shown in all three storefronts) |
| Subscriptions | Unchanged and `APPROVED`: U.S., Canada, Vietnam; annual one-week free trial in all three |

Archive and IPA were built from commit `e9f23d4` in a clean worktree; the App Store export used the Team Store profile, whose certificate list now includes both distribution identities, so `xcodebuild -exportArchive` succeeded (the 1.0.2 two-certificate failure did not recur). IPA SHA-256 `d33d966d6fabd7bd5a37c0c75ade5240a5e7da50b763a0a2f519f21caa992ae2`.

## Owner decisions

- **Submitted without the legal release-evidence bundle**, on the owner's instruction to release 1.0.4 (the owner waived the gate explicitly for 1.0.2 and 1.0.3). Writes used the same one-off client, which reuses `scripts/asc-api.py` token and request code. The repository guard is unchanged and no LEGAL issue is closed.
- **Released automatically after approval** (`AFTER_APPROVAL`), at the owner's request to release the new version.

## After approval

- Confirm 1.0.4 is `READY_FOR_SALE` in all three storefronts.
- On a device signed in to a Canadian or Vietnamese Apple Account, confirm the paywall shows local prices and the trial; start and cancel a trial to see the reminder scheduled and then removed.
- Rerun `StoreKitLifecycleTests` on the self-hosted `linepay-ios` runner.
