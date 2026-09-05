# LinePaycheck Onboarding and Seven-Day Trial

> Canonical onboarding, trial presentation, and activation specification. Revised September 5, 2026.
> This is the implementation target, not a claim that the current binary implements it or that conversion lift has been demonstrated.

## 1. Decision and scope

Use **a short path to a real expected-pay result, followed by a dismissible seven-day annual Pro trial offer**. Annual is selected initially; monthly remains a clear paid alternative. The objective is more downloads becoming satisfied paying subscribers, with a strong annual mix.

This deliberately replaces the previous no-calendar-trial decision and the blanket ban on an onboarding offer. It aligns with the annual-trial hypothesis in [marketing.md](marketing.md). [pricing.md](pricing.md) owns prices and Free/Pro access; this file owns the experience. [The iOS plan](plan/ios-1.0.md) and QA checklists must use the same decision.

| Package | U.S. baseline | First-time offer |
|---|---|---|
| Free | $0 | Useful work log, expected-pay ledger, first complete paycheck audit |
| Pro Annual — recommended | $79.99 billed yearly | Seven days free for eligible customers, then yearly renewal |
| Pro Monthly | $9.99 billed monthly | Immediate paid subscription; no introductory trial |

These are commercial choices, not experimentally established optima. The initial trial offer is configured for the U.S. storefront only; eligibility elsewhere does not imply an offer exists. Use localized StoreKit prices and offer eligibility in the app. Keep the existing products `linepay.pro.yearly` and `linepay.pro.monthly`, the `LinePaycheck Pro` group, and bundle `com.streamentry.linepay`.

The strongest objection: a worker paid every two weeks may not receive a paycheck during a seven-day trial. The answer is to create useful evidence on Day 0, make an existing paycheck check possible when matching work facts exist, and retain the first free audit for workers who need more time. A sample demonstrates mechanics; it cannot stand in for personal proof or count as activation.

**Success hierarchy:** D30 net proceeds per new download, D35 first-paid conversion, trial-to-paid conversion, and annual share of first paid subscribers. Trial starts alone are a leading indicator. Annual billing alone does not prove retention or satisfaction.

This task updates the specification and App Store offer configuration. Shipping the new SwiftUI flow, reminders, and StoreKit presentation is a separate implementation step with explicit acceptance criteria below.

## 2. Evidence and what it does not prove

Research checked September 5, 2026:

| Source | Observed evidence | Implication for this design |
|---|---|---|
| RevenueCat 2026 [R1] | North America median download-to-trial is 7.1%; upper quartile exceeds 15%. Business trial starts are 89.9% Day 0. Median trial-to-paid is 37.4% for 5–9 days and 42.5% for 17–32 days. Hard-paywall D35 conversion is 10.7% versus 2.1% for freemium. | Offer within the first useful session. These are observational cohorts with different apps, audiences, prices, and acquisition—not treatment effects or LinePaycheck forecasts. |
| Apple onboarding guidance [R2] | Interactive, brief, optional instruction is preferred. | Let the worker enter work and inspect its calculation. Avoid a questionnaire or feature carousel. |
| Apple subscription presentation [R3] | The billed amount must be the dominant price; trial duration and subsequent price must be clear. | Show the full annual renewal amount near the trial CTA, with monthly equivalents subordinate. |
| Yoganarasimhan, Barzegary, and Pani, Management Science [R4] | A SaaS field experiment found shorter trials maximized acquisition, retention, and profitability on average in its setting. | Causal evidence from another product does not determine our duration. Seven days remains a testable launch choice. |
| RevenueCat trial-design analysis [R5] | Practical cases emphasize matching trial design to time-to-value and measuring revenue and retention. | Build an activation sequence during the week; changing a duration field alone is insufficient. |

The old document treated cross-app hard-paywall data as evidence against a hard paywall for this app; it establishes neither conclusion. A proof-first soft offer is our starting judgment because saved work is useful on Free and trust matters for pay calculations. Reconsider placement after measured cohorts. Do not introduce a coercive launch gate because another category's median is higher.

## 3. First-session flow

```text
Welcome → confirm pay basics → enter one real work interval → expected-pay proof
                                                               ↓
                                               annual seven-day trial offer
                                              /             |              \
                                  Start annual trial    Buy monthly     Continue free
                                              \             |              /
                                               next useful work/pay action
```

Budget friction by actions, not screen count. Internal usability target: a prepared worker reaches a credible expected-pay result in a median of two minutes; this is a test target, not a performance claim. No mandatory account, union/local survey, employer name, acquisition survey, or notification prompt.

Persist real inputs before the offer. Dismissing or cancelling a purchase must return to the same saved work. Returning users resume their task, not the welcome screen.

### Welcome: recognizable outcome

Headline: **Know what your work should pay.**

Support: **Log your work. See the math. Check the paycheck.**

Trust: **No LinePaycheck account. Your pay data stays on this iPhone by default.**

CTA: **Calculate my work pay**.

Use the actual product's ledger visual or the Line Gap mark. Optional **See an example** opens clearly labeled synthetic data in a separate, discardable preview. It must never write a sample into the worker's real ledger or imply recovered wages. No purchase or permission request on this screen.

### Pay basics: minimum necessary truth

Default the editable profile label to **My current pay**. Ask for hourly rate and show currency and work timezone explicitly. Suggest a timezone for confirmation; never silently equate payroll timezone with device timezone. Keep optional rules off.

A compact **Add overtime or other rules** disclosure exposes overtime thresholds, premiums, callout guarantees, and per diem. Each additional rule requires explicit confirmation. A short flow must still represent the worker's actual agreement; do not calculate a complicated shift with a silently incomplete rule set.

CTA: **Save my pay rules**. Show validation next to the field. Preserve drafts, keyboard access, and large-text layout.

### First work: make the calculation personal

Ask for one actual recent work interval: date, start/end, and any unpaid break. Make overnight dates explicit. Use confirmed rules without inventing a “typical” eight-hour shift.

CTA: **See expected pay**.

Allow **I'll log work later**. That route enters Today with one useful next action; it does not claim personal proof or automatically open the proof-triggered offer. An explicit **Try Pro** action remains available. A returning user sees the offer once after their first real result.

Workers arriving with a paycheck may follow **Check a paycheck I have** as a secondary route after setup. Ask for matching work facts and pay-period dates. Never compare a full paycheck to one shift and label the difference an underpayment.

### Expected-pay proof: the monetization hinge

Display the computed gross estimate, exact interval/period, currency, applied rule summary, and a tappable explanation. Label the scope **Expected gross for this work**. A base-rate-only result must say **Using the rules you confirmed; add any missing premiums**.

Make this result a real readable screen; no timed auto-advance or immediate modal covering the number.

Primary continuation: **Check every paycheck** → trial offer.
Secondary: **Keep logging work** → Today.

The offer is the next step after a result, not a reward for completing a form. A match is a successful check; do not require or manufacture a discrepancy to sell Pro.

## 4. Annual trial offer: exact interaction contract

Show at most three paid benefits, each supported by the current binary:

- **Check every paycheck** with scanning or manual entry and confirmed work.
- **Follow every possible difference** back to its inputs and calculation.
- **Keep and share your audit record** for your own review.

Private calculation is a trust property shared with Free, not a fictional Pro-exclusive benefit.

For an eligible annual customer, the content hierarchy is:

```text
Check every paycheck.

[Real result summary, only if available and accurately scoped]

Annual — Recommended
7 days free, then $79.99 per year
Billed yearly. About $6.67/month equivalent.
Save about 33% compared with 12 monthly payments.

Monthly
$9.99 per month. Billed today. No free trial.

[ Start my 7-day free trial ]
Then $79.99/year, automatically renewing.
Cancel at least 24 hours before the trial ends to avoid renewal.

Continue free
Restore Purchases · Manage Subscription · Terms · Privacy
```

The displayed prices above are U.S. examples. Render the complete annual charge prominently. Calculate any savings using the loaded annual and monthly products in the same currency with Decimal; hide savings if products or comparison validity are unavailable. Do not make the monthly equivalent look like the billing schedule.

The trial starts only when Apple's purchase flow completes successfully with a verified transaction. Opening the app, tapping the CTA, closing the sheet, or saving a profile does not start it.

### CTA and eligibility matrix

| Selected product / state | CTA | Pricing and behavior |
|---|---|---|
| Annual, actual seven-day free offer present, eligible | **Start my 7-day free trial** | Show free duration and full annual renewal price |
| Annual, ineligible or no active offer | **Subscribe yearly** | Show immediate full yearly charge; no trial claim |
| Annual, eligibility unresolved | **Checking trial availability…** | Keep Free and retry available; no speculative free claim |
| Monthly | **Subscribe monthly** | Show immediate monthly charge and no trial |
| Products unavailable | **Retry App Store prices** | Keep **Continue free**; preserve work |
| Existing active Pro | **Continue to my work** | Do not sell a duplicate plan; provide management |
| Purchase pending | **Waiting for approval** | Explain status; no Pro unlock yet |
| Purchase cancelled | Same selected plan and terms | Quiet return; no alarm or repeated confirmation |

A visible **Continue free** action is required on the onboarding offer. Contextual sheets may use **Not now**, but must return to the attempted task/result. No delayed close control, false urgency, ambiguous trial toggle, fake social proof, fabricated savings, or annual label such as “Most popular” before evidence exists.

Have Terms and Privacy links available before promoting this as launch-ready. Do not copy a policy URL from another app.

## 5. The seven-day activation sequence

The week is an opportunity to build evidence, not seven push messages. All prompts are conditional and stop when their task is complete.

| Moment | User need | Product response and action |
|---|---|---|
| Immediately after verified start | “What did I start?” | Confirm annual plan, actual expiry/renewal date and price. Return to saved work. CTA **Log my next work** or **Check my paycheck**, based on available facts. |
| Day 0 | Make setup useful | Ensure one real work record has a reviewed ledger. Offer one optional reminder for the user's chosen work-log time. |
| Days 1–2 | Repeat without re-entering everything | **Add today's work**; offer reviewable reuse of the previous shift. Never automatically mark hours as worked. |
| Days 2–4 | Experience recurring audit value | If matching paycheck/work facts exist: scan/import, confirm uncertain OCR, show comparison and source evidence. Otherwise help complete the current work period. |
| Before renewal, preferably 48 hours ahead | Decide with confidence | Show a factual recap of records/checks, renewal amount/date, and **Manage Subscription**. Offer an opt-in local reminder only if implemented and successfully scheduled. |
| At expiry or first paid transaction | Understand access | Reconcile verified StoreKit state. Show actual paid/expired status. Keep all existing records and results accessible. |
| Following pay cycles | Reason to remain subscribed | Make repeated logging, checks, source review, and reports easier. Show usefulness, including matching paychecks, without guilt or monetary recovery claims. |

The app must not promise “we'll remind you” unless permission and scheduling succeeded. Permission refusal has no effect on access. Use neutral lock-screen copy such as **Review your LinePaycheck subscription**; do not include wage values. Calculate dates from verified store status, not seven device-calendar dates after install. Follow Apple's cancellation guidance [R6].

If renewal is already disabled, show **Ends on [date]** instead of **Renews on [date]**. Do not confuse cancelling renewal with immediate entitlement revocation. Follow verified entitlement state; do not promise future access the store has removed.

After payment, prevent involuntary churn through understandable billing recovery and verified grace-period handling when configured. Do not silently enable new billing settings during trial setup. A yearly customer's first renewal takes a year to observe; annual “retention” in a first-month dashboard is not a renewal metric.

## 6. Free access and later conversion

Keep the first complete paycheck audit available without an App Store trial. It serves workers without a paycheck during the week and workers who decline an annual commitment.

The app-managed free audit and Apple's introductory offer are separate:

- Completing a free audit never changes Apple's trial eligibility.
- Audits while an active verified Pro trial/subscription exists must not consume the unused Free audit.
- Preserve the used Free-audit state with saved/restored work; cancellation does not reset it. Reinstalling or deleting all local data may erase that device-local allowance. Accept that limitation rather than adding an account/backend to police it; Apple's introductory eligibility remains independent.
- If a trial expires with the Free audit unused, that one audit remains available.
- Correcting/re-running the already-free audit period remains available.
- Existing work, recorded rules, saved audit evidence, and completed results remain readable after expiry.

Contextual offer triggers: an explicit Pro action, an attempt at another new audit beyond Free, or the first free audit's optional completion offer. After a dismissal, suppress unsolicited repeat offers for that session. Do not add a launch-count timer or show another paywall after every edit.

For eligible Free users at a later boundary: **Try checking every paycheck free for 7 days**, with the annual terms. For ineligible users: **Keep checking every paycheck**, with normal prices. No resetting the trial clock or alternate group to obtain another introduction.

## 7. StoreKit implementation requirements

Use StoreKit 2 directly. Query product data and introductory eligibility before rendering trial-specific purchase copy. `isEligibleForIntroOffer` can be true even when no offer is configured; both eligibility and a real `introductoryOffer` are required [R7, R8].

For the requested trial, validate offer payment mode is free and total offer duration is seven days. A future configuration change must update the rendered duration, not retain a hard-coded promise. Track storefront/product refresh and stale UI states. Normal `Product.purchase()` invokes Apple's applicable introductory terms; no coupon product, app bundle, local trial entitlement, or extra subscription group is needed.

Entitlement authority remains verified transactions and subscription status. Keep purchase, trial, renewal-disabled, grace, expired, refunded/revoked, pending, and unavailable states distinguishable. An annual trial is not a paid annual conversion. Handle foreground/launch refresh as well as transaction updates; never grant Pro from a local start date.

Apple allows one introductory redemption per group. Restoring on another device and selecting another duration must not offer an additional trial [R9].

App Store configuration evidence is recorded in [the trial setup record](research/onboarding-trial-2026-09-05.md). Server configuration, a successful StoreKit test, and App Review approval prove different things.

## 8. Measurement contract

At launch, use App Store Connect offer/subscription reports and privacy-safe local observation. Apple exposes completed-offer conversion and subscription lifecycle reporting [R10, R11]. A calendar-period ratio of trial starts divided by downloads is a directional proxy, not a linked install-cohort conversion rate.

No new remote analytics, tracking SDK, or wage-data backend is authorized by this specification. Local counters do not provide a production funnel dashboard. If aggregate Apple reports cannot answer an experiment, document the blind spot; a minimal remote-event proposal requires an explicit privacy/data-flow decision before shipping.

| Metric | Definition and window |
|---|---|
| Download → trial | Unique eligible annual trial starters within 30 days of first download / first-time downloads in that cohort; report true linked cohort only when available |
| Offer → trial | Verified introductory starts / eligible unique viewers of the offer; local QA or approved measurement only |
| Trial → paid | Trials with a verified first nonzero standard-price charge / trials whose free period has ended; include cancelled trials in denominator |
| D35 download → paid | Unique first-paid customers within 35 days / first-time downloads of the same cohort |
| Annual share | New annual first-paid customers / all new first-paid customers; exclude free starts, restores, renewals, and switches |
| D30 net proceeds/download | Estimated developer proceeds through Day 30, net of refunds exactly once / cohort downloads; record tax/commission/reporting lag |
| Retention | D30 usage separately from monthly first renewal and annual first renewal; count only subscriptions due to renew |
| Activation | First real work saved + first expected-pay explanation viewed; sample activity excluded |
| Audit value | Confirmed real audit completed; match and possible difference both count |

De-duplicate transactions by store transaction identity. Treat switches separately to avoid double-counting payers. Exclude sandbox/TestFlight and re-downloads from first-acquisition denominators. Segment by storefront, app version, acquisition source, eligibility, and plan where reporting permits. Do not divide today's conversions by today's trial starts.

For cohort trial conversion, freeze the readout after all enrolled trials have ended plus a 48-hour reporting buffer; report unresolved billing separately and revise when later charges arrive. For D30/D35 revenue, use full matured windows. Do not erase failed billing or auto-renew-disabled users to improve the rate.

Proposed local development events: `first_open`, `pay_basics_saved`, `first_real_work_saved`, `first_expected_pay_viewed`, `trial_offer_viewed`, `plan_selected`, `purchase_attempted`, `verified_trial_started`, `verified_first_paid`, `first_real_audit_completed`, `manage_subscription_opened`. Store only stage, coarse variant, product identifier, and result; no wage, rule, employer, union, paystub, or raw purchase identity in analytics logs.

## 9. Experiments and decision thresholds

The economic model in `marketing.md` assumes 12.2% annual trial starts × 42.5% trial-to-paid + 2.8% direct monthly purchases ≈ 8.0% paid/download and 65% annual payer share. Those are stretch targets, not measured performance. In particular, 42.5% is not the published benchmark for seven-day trials.

Internal gates before paid scale:

- Five observed representative workers: at least four reach a correct, explainable real-work result within two minutes; all can state the annual renewal amount and find Free/cancellation. Any charge misunderstanding is a release defect.
- First 100 matured trials: descriptive readout with uncertainty and cancellation/activation interviews. This is a diagnostic sample, not proof of a winning experiment.
- Review product/offer design if matured trial-to-paid is below 30% or annual share below 50%. Investigate before lowering price.
- Ambition: annual trial starts ≥12.2%, trial-to-paid ≥42.5%, total paid/download ≥8%, annual first-paid share ≥65%. Do not scale from these point estimates without actual cohort proceeds covering acquisition cost and tolerable refund/support outcomes.
- Stop a variant immediately for incorrect trial terms, unverified unlock, inaccessible Free access, lost work, or misleading comparison. Pause scaling if refunds exceed 5% of first charges or users report unexpected billing; this threshold is an internal guardrail, not an Apple rule.

Ordered experiments, one variable at a time:

| Order | Comparison | Primary outcome | Guardrail |
|---|---|---|---|
| 0 | Observe actual users before quantitative testing | Correct first-result and renewal understanding | No invented work/pay rules |
| 1 | Proof → offer versus setup → offer | D35 paid/download, then D30 proceeds/download | First-result completion, refunds |
| 2 | Annual recommended versus neutral plan presentation | Net proceeds/download | Total paid conversion, price comprehension |
| 3 | Trial roadmap versus concise benefit offer | Mature trial-to-paid | Actual audit/return use, cancellation clarity |
| 4 | Seven-day annual trial versus a supported longer duration | D30/D60 proceeds/download | Time to first useful result and cash payback |

Do not mix price, traffic, screenshots, offer duration, and copy in one experiment. Use a stable local assignment for presentation only if results can be measured lawfully. Apple offers are storefront/product schedules, not per-user randomized durations; test duration sequentially with fixed acquisition/version where possible and disclose time/seasonality confounding. Apple supports one week, two weeks, and month-based free offers—not an arbitrary 17-day offer.

Predefine enrollment, minimum effect, readout date, confidence method, and stop rules. As a rough two-proportion planning example, detecting 37% versus 47% conversion with 80% power and two-sided 5% significance needs about 382 matured trials per arm. Budget at least 400 per arm before losses; recompute for the actual baseline. With small traffic, prioritize observed task completion and cohort diagnostics over claims of statistical wins.

## 10. Implementation gap and acceptance matrix

Inspection at source commit `03dedaa` found:

- `OnboardingFlowView` has welcome/setup and completes immediately after saving.
- `ProPaywallView` selects annual first but uses generic purchase copy and no trial eligibility presentation.
- `SubscriptionStore` verifies purchases and current entitlements but exposes no trial/renewal presentation model.
- No checked-in `.storekit` file was found.
- First-work proof, trial roadmap/reminders, and production funnel measurement are specified here; they are not established by this docs change.

A saved App Store offer alone does not close these gaps. Build the flow without modifying payroll arithmetic or retroactively changing stored agreement snapshots.

| Requirement | Acceptance evidence |
|---|---|
| No-login first session, minimal explicit pay facts | Fresh install/manual QA; optional rules remain off |
| Real work → correct scoped result → optional offer | Simulator journey; preserved inputs and explainable ledger |
| Eligible annual / ineligible annual / monthly | StoreKit configuration plus sandbox cases; CTA and charge terms match the selected product |
| Product missing / network failure / unknown eligibility | Free remains usable and no false trial promise appears |
| Purchase cancel / failure / pending / unverified | No false success; inputs survive; duplicate taps prevented |
| Trial start / paid renewal / expiry / revoke / restore | Verified state transitions and no local timer-based Pro |
| Active Pro skip; restored purchase skip | No duplicate trial invitation |
| Trial/free-audit interaction | Focused tests for unused, used, active-trial, expired-trial, and same-period recheck cases |
| Renewal reminder | Opt-in, verified date, scheduled confirmation, denied-permission path, cancelled-renewal handling |
| Accessibility | Small/large iPhone, large text, dark mode, VoiceOver reading of price and selected plan, reachable Free/terms |
| Retention | End-to-end repeat-work and second-paycheck journey; history remains accessible after cancellation |
| Release | Full native gate, relevant Maestro flows, StoreKit sandbox/TestFlight evidence; no readiness claim from docs or configuration alone |

Deliver in this order: trial eligibility/pricing presentation → first-work proof and offer placement → trial activation/renewal state → test matrix and real-worker observation. Do not launch paid acquisition until the first two slices and purchase-path verification are complete.

## References

- [R1] RevenueCat, State of Subscription Apps 2026: https://www.revenuecat.com/state-of-subscription-apps
- [R2] Apple HIG, Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- [R3] Apple, Auto-renewable Subscriptions, presentation: https://developer.apple.com/app-store/subscriptions/
- [R4] Yoganarasimhan, Barzegary, Pani, Design and Evaluation of Optimal Free Trials: https://pubsonline.informs.org/doi/10.1287/mnsc.2022.4507
- [R5] RevenueCat, The 7-day trial and other free trial myths, March 19, 2026: https://www.revenuecat.com/blog/growth/7-day-trial-subscription-app
- [R6] Apple Support, Cancel a subscription: https://support.apple.com/en-us/118428
- [R7] Apple StoreKit, Introductory offer eligibility: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/iseligibleforintrooffer
- [R8] Apple StoreKit, Introductory offer metadata: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/introductoryoffer
- [R9] Apple, Set up introductory offers: https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions
- [R10] Apple, Sales and Trends metrics: https://developer.apple.com/help/app-store-connect/reference/reporting/sales-and-trends-metrics-and-dimensions/
- [R11] Apple, Subscription analytics: https://developer.apple.com/help/app-store-connect-analytics/monetization/subscriptions
