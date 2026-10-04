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

To be completed with the exact results below.

## App Store Connect

To be completed after upload and submission.
