# Active public claim register

> Issue #27 (LEGAL-15). Every claim LinePaycheck currently makes in public, mapped to the shipping
> behavior that supports it, the test or record that proves it, and the limitation the user is shown.
> A claim that cannot fill all four columns is removed or qualified before the next submission.
> Reviewed for App Store version 1.0.5 (11) and linepaycheck.com on October 5, 2026.

## App Store (1.0.5, en-US, all storefronts)

| Claim | Shipping behavior | Substantiation | Limitation shown |
|---|---|---|---|
| Subtitle and description: calculates expected gross pay with an explainable ledger | Pay Ledger lists each component with its formula | `LinePayDomain` calculation tests; store frame 01 and 04 captures | "Expected", "Based only on the rules you entered"; weekly overtime note over 40 h |
| "Log regular shifts, callouts, overnight work, and unpaid breaks" | Work kinds Regular, Callout, Other; overnight end dates; unpaid breaks | `AddWorkView`; Maestro `work-lifecycle.yaml`; frame 05 | No storm-specific, travel or rest rules; scope disclosure says so |
| "Set daily overtime, weekday and date premiums, and their multipliers" | `PayRuleKey` `.dailyOvertime`, `.weekday`, `.date` | Domain rule tests; frame 02 | Weekly statutory overtime is a separate review, not part of the estimate |
| "Account for callout minimums and per diem" | `.callout`, `.perDiem` rules | Domain tests | Per diem kept apart from wages |
| "Compare your paystub … review possible differences" | Paycheck check: gross, then confirmed lines | `PaycheckAssessment` tests; frames 03, 04, 06 | "Possible", "This is not a legal finding", "Only the listed confirmed lines were compared" |
| Private by default; no account; processing on-device | No account, analytics SDK or pay-data backend; Vision OCR on device | `App/Resources/PrivacyInfo.xcprivacy`; Settings › Privacy and data (frame 07) | Purchases, Files providers, exports and iCloud backups are separate flows the user chooses |
| Free: profile, logging, expected pay, ledger, first paycheck check | `AppModel.canRunAudit` allows one free check | `SubscriptionBehaviorTests`; `StoreKitLifecycleTests` | First check per install; later checks need Pro |
| "LinePaycheck Pro adds a paycheck check for every pay period after your free first check" | Pro gates only `canRunAudit` | `SubscriptionStore.hasAuditAccess`; in-app paywall copy | Auto-renewing; EULA and privacy links in the description |
| 7-day yearly trial for eligible new subscribers; local prices before purchase | App Store introductory offer on `linepay.pro.yearly` in US, CA, VN | App Store Connect offer records (release 1.0.4 evidence) | Eligibility decided by Apple; no prices in the description |
| Promotional text: "No LinePaycheck account required" | As above | As above | — |

Screenshot headlines and qualifiers are recorded per image in
`assets/store/source/capture-manifest-ios-1.0.5-en-US.json`. Every frame is an unedited capture of
the `store-week-2026-08-v1` sample (`docs/design/app-stores/screenshots.md` §4), labelled
"Illustrative data". The possible-difference frame says "First paycheck check free. Pro for ongoing
checks." `scripts/tests/test_store_screenshots.py` fails if an export loses its capture, checksum or
paid-access qualifier, or if a concept enters the upload folders.

Removed in 1.0.5: "storm work" as a tracked category; Pro "paystub scanning, reconciliation history,
and advanced audit tools"; the eight concept screenshots (fake UI, logo and employer).

## linepaycheck.com

| Claim | Substantiation | Limitation shown |
|---|---|---|
| "You worked every hour. Check every dollar." | Paycheck check, as above | Hero copy says "review possible differences in gross pay" |
| No LinePaycheck login; no central pay-data database; calculations on iPhone | As the app privacy row | Hosting requests, backups, purchases and shared reports listed as separate flows |
| Pricing card | In-app paywall and `canRunAudit` | Pro is recurring checks only; history and reports stay free (website PR #12) |
| Guides (storm, overtime, per diem, callout) | Cited public sources on each page | "General information, not legal, tax, payroll or employment advice"; all figures fictional |

## Other channels

- **Other App Store surfaces:** none. The App Store Connect API on October 5, 2026 showed 0 custom product pages, 0 in-app events and 0 product page tests.
- **Advertising:** no ad creative exists in this repository or the store account. Any future ad, social or press copy follows this register before it runs.
- **In-app and support copy:** repository copy is checked by `scripts/legal_guardrails.py` (absolute privacy and recovery claims fail the check). The support templates ask for synthetic or redacted examples only.

## Rules for new claims

- **Possible, not recovered.** Say "possible difference" for a calculated gap. Never state or imply
  money recovered, owed, stolen or guaranteed, and publish no average or typical recovery figure.
- **Testimonials.** None are used today. A future testimonial needs the worker's written permission,
  must describe a real experience, and must disclose any material connection (payment, free Pro,
  employment, family). No invented workers, stock "customers", review stars or quotes.
- **Reviews.** Never offer anything in exchange for a review or a positive rating. The app does not
  prompt for ratings today; if it ever does, use only Apple's system review prompt.
- **Agreements.** Do not name a union, utility, contractor or agreement, or claim agreement coverage
  or verification, until LEGAL-14 (#26) gates are met.
- **Features.** Market only what the submitted build does. Re-review this register whenever the
  description, promotional text, screenshots, website pricing or paywall copy changes.
