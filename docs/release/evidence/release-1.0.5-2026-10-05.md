# Release 1.0.5 (11): submission record — October 5, 2026

This is a point-in-time record of what happened. It is not App Review approval, a storefront release, or legal clearance.

## Context

[1.0.4 (9)](release-1.0.4-2026-10-04.md) was approved and released automatically; on October 5 it read back as `READY_FOR_SALE`, and the public U.S., Canada and Vietnam product pages showed version 1.0.4.

Build 10 of 1.0.5 (TestFlight only, October 4) predates two fixes, so it was not submitted. Build 11 was cut from `main` after #104 and #107.

## What 1.0.5 contains

| Change | PR |
|---|---|
| VND money entry rejects decimals instead of reading `45.00` as 45 đồng | #101 |
| Invalid-number message shows the region's own format | #104 |
| With the weekly overtime review on and more than 40 hours logged, a paycheck check stays **Needs review** (issue #67, review-only contract) | #104 |
| Keyboard **Done** is an owned row, so it always appears on iOS 26 (issue #106) | #107 |

## Verification

- Full iOS gate on the self-hosted runner for #107 (the last code change): app tests including the StoreKit lifecycle suite, the XCTest UI journeys and the Release build passed, and the Maestro matrix passed 9/9 flows plus the compact dark large-text job. The known largest-text rule-scope journey (`LegalJourneyTests.testEachRuleScopeKeepsItsPromisedEffectAtLargestText`) still fails; it is a separate product fix.
- `legal_guardrails.py check` and the repository script tests passed after the build bump.

## App Store Connect

| Item | State (read back through the API) |
|---|---|
| Build `11` (`1.0.5`), delivery `4d5db312-726f-44da-8a4e-10429fb3a126` | `VALID`; `altool --validate-app` reported no errors |
| App Store version `1.0.5` | `WAITING_FOR_REVIEW`, `releaseType: AFTER_APPROVAL`, submitted 2026-10-05 01:13 UTC |
| Description and review notes | Carried over from 1.0.4 (Standard EULA and privacy links, no prices) |

Archived from commit `192d9ea` in a clean worktree; IPA SHA-256 `b98b25612dd99708a3033e56fd9df2ac32871cde8e7b820d0fe06edf25e6d1ca`.

## Owner decisions

- Submitted without the legal release-evidence bundle, through the same one-off client as 1.0.2–1.0.4, as the next step of the release plan the owner approved. The repository guard is unchanged and no LEGAL issue is closed.
- Released automatically after approval (`AFTER_APPROVAL`), as for 1.0.4.
