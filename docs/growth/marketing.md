# Paycheck Audit: LinePay — growth and validation

[Growth home](README.md) · [v3 plan](../plan/v3.md) · [App Store copy](../release/app-store.md) · [Pricing](../product/pricing.md)

> **Current positioning, October 19, 2026.** This replaces the earlier lineman-only month-one acquisition recommendation. It is an experiment plan, not evidence of paid demand, profitable acquisition, a live rename or authorization to create campaigns or spend. [The previous model](https://github.com/RunLumi/linepay/blob/1da1059e0c190d4ca938d5852bf8ce893ef86608/docs/growth/marketing.md) and [September campaign record](apple-ads-campaign-2026-09-22.md) remain dated history.

## Positioning and strongest objection

**Target public name:** Paycheck Audit: LinePay. **Subtitle:** Verify Pay & Track Hours. The [App Store document](../release/app-store.md) owns exact fields, description, screenshots and release conditions.

> A private paycheck checker for hourly workers: record your work, compare expected earnings with your paystub, and understand possible differences.

The strongest objection is that “paycheck” searchers often want an employer portal or take-home-tax estimate. Broad acquisition could add installs while reducing audit completion, paid conversion and trust. The specialist audience may have more valuable repeat problems. Keep the advanced lineworker path and test the broader entry; do not erase the niche because a broad keyword produces more installs.

The initial generic audience is US hourly workers with variable hours, overtime or premiums who can supply their actual work and paystub. Construction/trades, field service and utilities are candidate segments, not proof of legal-rule coverage. Workers seeking payroll login, direct deposit, tax filing, employer processing or universal wage-law verification are outside the promise.

## Evidence available and unknown

The [v3 plan](../plan/v3.md#1-why-observed-apple-ads-evidence-not-imagined-aso-demand) records owner-provided Apple Ads screenshots dated October 19. The broad `paycheck` keyword produced more absolute installs in that view; the `lineworker` sample was small. Visible provider-brand terms suggest navigational leakage. Confirm identical date/country/attribution filters before combining screenshots. A suppressed “Low volume terms” row does not reveal its actual search query.

Those observations establish neither organic search volume nor audit completion, paid conversion, repeat-payday retention or profitable CAC. The earlier $4,000 media model and projected conversion/annual mix are superseded planning assumptions, not an approved new budget or measured result. Do not carry them into a release claim.

## Promise and segment architecture

| Lane | Worker intent | Relevant product proof | Claim boundary |
|---|---|---|---|
| Paycheck check | “Does my paystub match my work?” | Complete work → confirmed rules → same-period, like-for-like comparison → evidence | A possible difference needs review; a match covers compared items only |
| Hourly pay | “What gross earnings should these hours produce?” | Generic hourly setup, actual hours and explicit optional rules | No assumed national overtime rule; no complete take-home-tax estimate |
| Advanced lineworker | “How do these confirmed callout/premium rules apply?” | Retained advanced setup, supported callout/per-diem/dated-rule fixtures | No automatic union, employer, storm or CBA verification |

The general route uses **Check my paycheck**; the alternative is **Set up lineworker or advanced pay**. Keep the first comparison reachable before an optional subscription offer. A missing rule or incomplete work record remains a review/not-comparable state. These routes require final candidate acceptance before their screenshots or acquisition copy are published.

## Copy and creative

Use one consistent promise across the store, corresponding website and first-use experience:

> Track what you worked. Compare expected pay with your paystub. Understand possible differences.

The first three real screenshots are comparison, hourly setup and scan/review/compare. Specialist creative follows, using the exact [store sequence](../release/app-store.md#5-screenshot-sequence-and-acceptance). Preserve Precision Industrial Minimalism and synthetic, visibly scoped amounts. Do not make generated UI, implied legal verdicts, recovered-dollar banners, union endorsement or employer accusations part of acquisition.

Keep the offer unchanged: one Pro entitlement, existing Monthly/Annual IDs, $9.99/month and $79.99/year US anchors, an eligible annual introductory offer and a separate first complete comparable audit free. Actual prices/eligibility come from StoreKit. Saved records remain accessible after Pro ends. [Pricing](../product/pricing.md) and [onboarding](../product/onboarding.md) own the commercial contract.

## Proposed acquisition experiment

The owner selected **Paycheck Audit** on October 24, with a generic paycheck/hourly-pay listing and retained lineman/lineworker description and keywords. Treat reported low downloads as a reason to test reach, not a causal finding about keyword narrowness. Audit-intent and generic-hourly tests are both primary; specialist acquisition remains a separate retained use case. The exact 99-byte listing field lives in [store copy](../release/app-store.md#2-us-english-metadata-candidate).

Run no new campaign until the corresponding product journey, store assets, scope copy and owner-approved budget are ready. A release request does not authorize ad spend or outreach messages.

| Group | Initial intent examples | Proposed test | Decision it answers |
|---|---|---|---|
| Audit | paycheck audit, paycheck checker, paystub checker, paycheck discrepancy, paycheck verification | Separate exact-match group | Do problem-aware workers complete a comparable audit? |
| Hourly | hourly pay, overtime pay, paycheck, paystub | Separate exact-match group with a tighter owner-set cap | Does broader traffic reach value without portal/tax confusion? |
| Specialist | lineworker, lineman pay, callout tracker, storm pay | Preserve as a separate group | Does specialist value/retention outperform the generic segment? |
| Discovery | Broad match/Search Match only if separately funded | Small capped group; review disclosed actual queries | Which relevant queries deserve an exact test? |

Review navigational provider queries separately. Proposed exact negatives for clearly observed employer-login intent include `adp`, `proliant`, `paycor` and `paychex`; these are exclusion candidates, never app keywords or brand claims. Do not block all `payroll` phrases without checking context. Exact matches include close variants, and exact negatives do not block every variant; follow Apple's [match-type](https://ads.apple.com/app-store/help/keywords/0059-understand-keyword-match-types) and [negative-keyword](https://ads.apple.com/app-store/help/keywords/0060-use-negative-keywords) rules when configuring an authorized campaign.

Keep paid and organic evidence separate. Before scaling, collect dated US keyword-popularity suggestions, organic result positions and competing screenshots. Vendor difficulty scores are models. Product Page Optimization creative results do not prove an indexed name/title winner.

Do not open more networks to compensate for a failed first-audit journey. Meta, Google and TikTok have no media allocation in this plan. A remote attribution/MMP or ad-network SDK would add a data flow excluded by the current local-only decision; channel testing does not justify silently adding one.

## Measurement with local-only data

The owner chose device-local activity and **manual diagnostic export**. Preserve that decision:

- No remote product events, cross-app tracking, automatic attribution SDK or central account/pay-data backend.
- Use Apple Ads and App Store Connect aggregate acquisition, proceeds and subscription reports for the information Apple actually supplies.
- Opt-in local counters/manual exports can describe behavior on one device. Request no wage values, employer/union identity, OCR text, original documents or full backups for growth research.
- Voluntarily shared diagnostics or interviews are a selected sample, not all installs. Record consent, sampling method and the denominator; do not join them to an advertising identity or infer a population conversion rate.
- Observe usability with synthetic data or participants' private on-device records. Do not copy real payroll evidence into research notes, Git or campaign systems.

Apple aggregates cannot automatically link a particular install/query to a first audit or second payday. If that linkage is unavailable, report the blind spot. Do not divide unrelated aggregates and label the result a linked funnel.

| Question | Usable evidence | Limit |
|---|---|---|
| Is acquisition relevant? | Disclosed query reports, spend and installs with identical filters | Suppressed queries remain unknown |
| Can an informed user reach value? | Observed synthetic task completion and consented manual local summaries | Small/selected sample; not install-level activation |
| Do checks recur? | Consented follow-up after a second payday and manually shared local counts | Payday maturity and nonresponse bias matter |
| Is commerce working? | Tested purchase/restore path plus Apple subscription/proceeds reports | Local StoreKit tests do not establish production transactions |
| Is acquisition economic? | Mature acquisition spend and attributable actual net proceeds where available | No assumed commission, annual mix, refunds or renewals |

## Gates, stopping and next actions

These are initial experiment thresholds, **not industry benchmarks or achieved results**. They guide investigation rather than claim statistical proof from a small sample.

| Area | Initial gate | If it fails |
|---|---|---|
| Relevance | Investigate a cohort with more than 20% of spend on clearly unrelated navigation | Correct queries/copy; do not scale broad “paycheck” bidding |
| Expected pay | Aim for at least 50% of observed qualified generic users to reach a credible estimate | Fix the largest setup/rule-comprehension obstacle |
| First audit | Aim for at least 30% of observed eligible users to complete a comparable audit | Separate unsupported cases, missing evidence and abandonment |
| Repeat use | Aim for 40–50% of observed users who have reached a second payday to check again | Reassess recurring need before changing price |
| Economics | Actual contribution-adjusted proceeds must support the owner-approved acquisition payback period | Hold spend; report uncertainty rather than model a profitable result |
| Trust | No known false legal verdict, silent rule assumption or monetary defect | Stop the claim/affected flow, fix it and add meaningful regression evidence |

Aim for at least 30 comparable audits per materially tested segment before treating operational patterns as stable; substantially more paid observations may be needed for economics. A handful of installs is not a winner. If volume is sparse, use observed sessions and retain uncertainty rather than expanding spend to manufacture certainty.

The next seven days of authorized product work should produce:

1. Generic and advanced acceptance receipts at the final source, including unknown overtime, incomplete work and mismatched pay periods.
2. Actual candidate screenshots for the functioning claims in the store sequence, the updated claim mapping and source-bound manual-release evidence.
3. A review of the existing Apple Ads exports with matching filters and a proposed capped experiment, kept pending separate budget/campaign authorization.

The cheapest demand test, when participant contact is separately authorized, is five generic hourly workers and five lineworkers completing the same synthetic task, followed by a second-payday check-in. Record completion, misunderstood rules and willingness to repeat/pay without collecting their payroll records. This is a proposed study; no interviews, messages or campaign changes have been performed by this document.

Go broader when generic users can complete supported audits and show repeat value, with economics at least competitive with the specialist path. Hold specialist-first when broad users mainly seek portals/tax estimates or unsupported coverage dominates. Preserve local data, advanced workflows and historical rule snapshots through either decision.
