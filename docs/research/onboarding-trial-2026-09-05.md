# Onboarding revision and App Store trial setup — September 5, 2026

## Scope and decision

Requested work: review the onboarding strategy, research subscription conversion, apply the conclusions to the docs, and configure a seven-day introductory trial through Chrome.

The revised specification is [onboarding.md](../onboarding.md). It aligns pricing, the 1.0 plan, App Store strategy, marketing measurement, screenshot guidance, and both release checklists. The annual-only trial and U.S. launch scope follow the existing marketing plan; Monthly remains the immediate paid alternative.

No SwiftUI onboarding implementation, production analytics, advertising spend, App Review submission, or new build upload is part of this documentation/configuration delivery.

## Verified App Store configuration

Inspected and changed through Chrome's App Store Connect UI:

| Field | Observed value |
|---|---|
| App | LinePaycheck: Lineman Pay |
| App ID / bundle ID | `6808889292` / `com.streamentry.linepay` (repository identity) |
| Subscription group | LinePaycheck Pro, `22360820` |
| Annual product | `linepay.pro.yearly`, Apple ID `6808913125` |
| Annual billing | One year, upfront; existing U.S. price $79.99 |
| Annual purchase availability | United States only; explicitly approved by the user and saved in Chrome |
| Introductory type | Free trial |
| Duration | One week |
| Trial storefront | United States only |
| Offer start | September 5, 2026 |
| Offer end | No End Date |
| Monthly product | `linepay.pro.monthly`, Apple ID `6808912767` |
| Monthly offer / price | No introductory offers; U.S. $9.99 per month, independently verified by read-only API |
| Product lifecycle | Prepare for Submission in the inspected UI; Monthly API still reports `MISSING_METADATA` |

Before the write, Annual's Introductory Offers page had no current offers. After Confirm completed, its **Current Introductory Offers** table displayed `Sep 5, 2026 to No End Date`, one country/region, and `Free for the first week`. The confirmation preview identified that country as United States (USD). The browser's rendered offer key included `FREE_TRIAL-ONE_WEEK-1-UPFRONT`.

Annual offer page: https://appstoreconnect.apple.com/apps/6808889292/distribution/subscriptions/6808913125/pricing/intro-offers

### Purchase availability confirmed

Annual's **Upfront Billing Availability** dialog initially showed zero countries. The user explicitly approved enabling U.S. annual purchases at $79.99/year after the eligible seven-day trial.

After that approval, the prepared **Confirm Upfront Billing** screen showed United States (USD) and $79.99. Confirm succeeded; the dialog closed and the product's **1 Year Upfront** section changed to **1 of 175 countries or regions selected**, with Edit and Remove from Sale controls. The Save button was disabled, indicating no outstanding page edits. The availability blocker is resolved.

The product still displays **Prepare for Submission**, so this verifies saved availability configuration, not App Review approval or a live consumer purchase. Reopened Introductory Offers after the availability write and verified the current offer still shows one week free, September 5 start, no end date, and one storefront. Monthly installment billing with a twelve-month commitment remains unset; it is a different commitment from the existing Monthly alternative. No other storefront availability was enabled.

## Research conclusions

The canonical document contains the primary-source links and exact limitations. The principal changes are:

- An optional annual offer follows a real expected-pay result, resolving the old setup-paywall versus no-onboarding-paywall conflict.
- The week has concrete activation actions: record work, inspect calculations, check an available matching paycheck, and make an informed renewal decision.
- Annual receives the trial and initial recommendation; the specification keeps Monthly visible with immediate billing terms. Monthly's purchase readiness is not established by its configured price.
- First-audit Free access remains separate from Apple's group-wide introductory eligibility.
- Trial claims require real offer metadata and eligibility. A successful trial is distinct from the first paid transaction.
- Conversion and annual mix are measured against matured cohorts, proceeds, refunds, and actual renewal.

Cross-app benchmarks are observational, not proof that a paywall or duration causes lift in LinePaycheck. Seven days is the requested commercial hypothesis. The prior marketing model's 42.5% trial-to-paid figure is a stretch target, not a seven-day benchmark.

## Verification

- Repository agent doctor passed, with the optional XcodeBuildMCP tool absent.
- Full `bash scripts/agent-verify.sh ios` completed with exit code 0.
- The run passed 37 pure-domain tests, the iOS app test suite, privacy validation, and the Release simulator build.
- Local command log: `/private/tmp/linepay-trial-native-gate-20260905.log` (temporary, not a retained repository artifact).
- Financial presentation math checked: annual saving $39.89 against twelve $9.99 payments; modeled paid/download 7.985% and annual first-paid share about 64.9%.
- Approximate two-proportion sample calculation: 37% versus 47%, 80% power, two-sided 5% significance → 382 matured trials per arm; the spec budgets 400 before losses.
- Local Markdown links and fenced blocks validated for all nine edited docs; `git diff --check` passed.

The native gate exercised the current checkout while other source/artwork edits were present. It does not prove the newly specified trial flow, StoreKit sandbox transitions, App Review approval, or any conversion lift.

## Remaining product implementation

At inspected source `03dedaa`, welcome/setup completes without a first-work offer step; the paywall lacks introductory eligibility/copy; the store adapter has no dedicated trial/renewal presentation model; and no `.storekit` fixture was found. The acceptance matrix in `onboarding.md` names the required implementation and sandbox evidence. The doc update must not be mistaken for shipped funnel behavior.

## Completion audit

| Requested outcome | Evidence | State |
|---|---|---|
| Review the previous onboarding strategy | Contradictory paywall/trial policies identified and deliberately reconciled in the canonical docs | Complete |
| Research conversion and annual subscriptions | Primary sources, observational versus causal limits, and commercial assumptions documented in `onboarding.md` | Complete |
| Apply the research to docs | Concrete first-session flow, plan/eligibility copy, week-long activation, retention, measurement, experiments, and acceptance matrix | Complete |
| Set up the seven-day trial through Chrome | Saved U.S. Annual offer row: one week free, September 5 start, no end date | Offer saved |
| Configure the annual product's launch-storefront availability | User explicitly approved U.S. $79.99 annual availability; saved Chrome state shows one storefront selected | Complete; App Review/release remains separate |
| Demonstrate improved real conversion | No production cohort experiment has run; proposed UI is not implemented by this docs task | Unproven; not claimed |

The requested research, documentation, introductory offer, and approved U.S. availability configuration are complete. The next product delivery is the specified onboarding/StoreKit implementation and sandbox verification; actual conversion improvement requires production cohort evidence.

## PR review

The documentation review aligned the design-system sequence with first-work proof, made pricing experiments subordinate to the onboarding experiment order, and clarified that a local-only Free allowance cannot be guaranteed to survive deleting all app data. These are specification clarifications, not new app behavior or data collection.

PR validation: local Markdown links and fenced blocks checked across all ten changed documents; financial/example arithmetic checked; `git diff --check` and `bash scripts/check-agent-harness.sh` passed in the isolated delivery worktree. The earlier native gate above is historical checkout evidence, not a fresh test of the PR.
