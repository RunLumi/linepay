# Lineman Pay — App Store candidate

[Release home](README.md) · [v3 plan](../plan/v3.md) · [Pricing](../product/pricing.md) · [Claims](../legal/claim-register.md)

> **Canonical App Store copy and presentation. Updated October 20, 2026.** The owner selected the v3 positioning and, on October 20, selected Lineman Pay as the next-version listing and home-screen display name; implementation, submission and manual public release after Apple approval remain requested. The copy below is a **candidate for vNext**, not evidence of an App Store Connect write, name availability, trademark clearance, passing release gate or public release. The candidate source is set to version 1.1.0, build 13; its signed binary, Apple build record, and final release evidence are still pending. The current shared CI job fell back to Xcode 27.1; the repository's Xcode 26.6 / Swift 6.3 baseline remains unverified.

## Decision and release boundary

The target public listing is **Lineman Pay**, with the subtitle **Verify Pay & Track Hours**. Its promise is:

> Track what you worked. Compare expected pay with your paystub. Understand possible differences.

Start with US hourly workers with variable schedules or supported overtime and premiums. Preserve lineworker capabilities as an advanced path. A paycheck audit means a traceable comparison within disclosed coverage; it does not establish every legal entitlement, determine wage theft or guarantee recovery.

| State | Evidence and meaning |
|---|---|
| Existing 1.0.5 | The October 19 US listing readback retained **LinePaycheck: Lineman Pay**, version 1.0.5. The [submission receipt](evidence/release-1.0.5-2026-10-05.md) and [claim register](../legal/claim-register.md) retain the dated build 11, specialist-copy and screenshot evidence. |
| vNext candidate | Generic hourly setup and direct paycheck comparison, with advanced rules retained. Copy and review routes below require acceptance against the final candidate. |
| Submitted / public vNext | Record the actual selected build, metadata, screenshots, release mode and Apple state in a new source-bound release receipt. No vNext submission or public-state claim is made here. |

Keep `com.streamentry.linepay`, the `LinePay` project/scheme/target, `LinePayDomain`, StoreKit product IDs and stored data identifiers unchanged. For the 1.1.0 candidate, set the home-screen display name to **Lineman Pay**; keep the technical product name and existing subscription names unchanged. This does not rename the bundle, project, domain module, or stored data. Availability and trademark/confusability review remain open. The prior USPTO readback found a live registered **LINE PAY** mark (serial 97491295, LY Corporation); an exact Lineman Pay clearance has not been established.

## 1. Store-page job

The first three screenshots must make sense without knowing what a lineman or CBA is. They should show:

1. A comparison between recorded work, expected earnings and confirmed paystub values.
2. Simple hourly setup with optional, explicitly confirmed rules.
3. Paystub review with editable extracted values and matching pay-period dates.

Advanced copy can then explain supported callout minimums, per diem and dated rules. Do not promote storm-specific, statutory, union or agreement coverage merely because a worker can enter a custom rate.

The app does not retrieve paystubs from an employer portal, provide direct deposit, process payroll, calculate every tax/deduction or certify employment-law compliance. Acquisition copy must make that distinction clear before a user supplies work records.

## 2. US English metadata candidate

| Field | Exact candidate | Measured length / limit |
|---|---|---:|
| App Store name | **Lineman Pay** | 11 / 30 characters |
| Subtitle | **Verify Pay & Track Hours** | 24 / 30 characters |
| Promotional text | **Track hours, review paystub figures, and understand possible pay differences—privately.** | 87 / 170 characters |
| Keywords | `paystub,discrepancy,overtime,checker,timesheet,underpaid,shift,earnings,callout` | 79 / 100 UTF-8 bytes |
| Primary category | **Finance** | Retain only if it accurately describes the final product |
| Secondary category | **Utilities** | Confirm final App Store Connect value |
| Price | **Free with In-App Purchases** | Local prices come from StoreKit |
| Localization | **English (U.S.)** | No unsupported language or payroll-localization claim |

The name/subtitle and keyword limits were checked against Apple's [app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) on October 19, 2026. Keywords are an initial relevance hypothesis, not evidence of organic ranking or demand. No competitor or payroll-provider names belong in the keyword field.

Do not copy the old `LinePaycheck: Lineman Pay` / `Overtime, Callout & Per Diem` metadata into a new broad release. That is the specialist baseline recorded in the historical receipt. The original strategy remains available at [the pre-v3 revision](https://github.com/RunLumi/linepay/blob/1da1059e0c190d4ca938d5852bf8ce893ef86608/docs/release/app-store.md).

## 3. App Store description candidate

Use the following plain text only after the final build supports every advertised route. Keep the working Standard EULA and Privacy links; 1.0.2 was rejected for omitting the EULA link. Do not print a USD price in a description reused across storefronts.

```text
Not sure your paycheck matches the hours you worked? Lineman Pay helps hourly workers estimate expected earnings, compare a paystub, and understand possible differences.

START WITH YOUR WORK

Enter your hourly rate, pay period and actual work. Confirm supported overtime rules and premiums instead of relying on automatic assumptions. Review estimated gross earnings and the calculation behind them.

REVIEW THE PAYSTUB

Scan or import a paystub, or enter its details by hand. Review extracted figures and confirm the dates and earnings basis before comparing. A paystub alone cannot prove which hours you worked.

UNDERSTAND THE RESULT

Compare like-for-like earnings under the rules you confirmed. Review possible differences with the work facts, rule versions and statement values behind them. Missing work, unclear rules or incompatible pay periods need review; a match covers only the items compared.

BUILT FOR COMPLEX PAY, TOO

Lineworkers can keep using advanced settings for supported callout minimums, per diem, overtime and dated pay rules. Your existing work records and historical checks remain part of your record.

PRIVATE BY DEFAULT

No account or employer login is required. The app does not connect to your employer's payroll portal. Calculations and paystub processing happen on your iPhone. You choose when to export a report or create a manual backup; those files may contain sensitive pay information.

FREE TO START

Set up pay rules, log work, review expected pay and complete your first comparable paycheck audit free without enrolling in a subscription.

LinePaycheck Pro adds ongoing paycheck checks after your free first check. Saved work, checks and reports remain accessible when Pro ends.

Pro is an optional auto-renewing monthly or yearly subscription, charged to your Apple ID and managed in your App Store account settings. Local prices and any eligible introductory offer are shown before purchase.

Results depend on complete and accurate inputs, supported rules and correctly matched periods. The app does not determine legal entitlement or calculate every tax, deduction or pay requirement. Estimates and possible differences are for review, not legal, tax, payroll or employment advice.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://linepaycheck.com/privacy
```

Before submission, substantiate the new generic journey and each feature claim in the [claim register](../legal/claim-register.md) with the actual candidate revision and receipts. That register's October 5 review does not approve the new name, copy, screenshots or audience expansion.

Do not add named agreement packs, verified sources, voice input, benefits auditing or other v2 roadmap features to this description solely because code exists. Each advertised capability needs final acceptance and its applicable privacy/rights review. A configured-rules estimate is not a complete US legal-pay audit.

## 4. Promotional text

The next-release candidate is the exact text in the metadata table:

> Track hours, review paystub figures, and understand possible pay differences—privately.

Promotional text is editable separately from an app version, but changing it remains an authenticated publication action under the release contract. Do not publish the generic promise before the corresponding journey ships.

For the **historical 1.0.5 receipt**, the previous §4 default was:

> Track real work, calculate expected pay from your confirmed rules, and check each paycheck for possible differences. No LinePaycheck account required.

The dated release record refers to that older text; it is not silently rewritten by this candidate.

## 5. Screenshot sequence and acceptance

Follow [DESIGN.md](../../DESIGN.md) and the [store screenshot system](../design/app-stores/screenshots.md). These are composition requirements, **not existing captures or approved assets**.

| Order | Headline | Actual screen evidence required |
|---:|---|---|
| 1 | **Is Your Paycheck Correct?** | Expected vs confirmed paystub amount with `Possible difference` or the actual scoped result label and visible coverage explanation |
| 2 | **Track Hours. Know Expected Pay.** | Generic hourly setup and actual work, with an explicit rate and estimate scope |
| 3 | **Scan. Review. Compare.** | Editable paystub review, source-period dates and human confirmation |
| 4 | **Review Possible Overtime Gaps.** | A supported overtime component traced to work and a confirmed rule; show unresolved coverage honestly |
| 5 | **Keep the Evidence.** | Source facts, rule snapshot, comparison and preview of the actual shareable report |
| 6 | **Built for Complex Pay, Too.** | Retained advanced lineworker settings with supported callout/per-diem scenarios |

Use real candidate captures with clearly synthetic facts and the appropriate Free/Pro qualifier. Keep historical 1.0.5 captures and their manifest intact; new screenshots need a new source/build-bound capture record. Do not use generated UI, worker testimonials, union badges, fictional employer replies or dramatic “money owed” banners. A question headline must be answered by a visibly scoped comparison, not an unqualified correct/incorrect verdict.

Inspect small-screen, large-text and dark appearances in the actual app. The submission set must remain legible at thumbnail size. Screenshot 4 is omitted if a meaningful, supported overtime comparison cannot be captured; an unresolved-rule warning must never be dressed up as a detected gap. In particular, more than 40 actual weekly hours without mapped weekly coverage remains **Needs review**, even when entered gross amounts match. A configured difference in that state is not a verified overtime shortfall.

## 6. App preview and icon

Retain the recognizable Line Gap geometry and the Precision Industrial Minimalism system. No icon redesign is required to publish this copy. Review any actual asset change separately at Home Screen and App Store sizes.

Add a preview only after the journey is accepted. Use real captured UI: confirmed rules → actual work → expected earnings → reviewed paystub → scoped result → evidence. No stock footage, fake employer text or recovery claim.

## 7. Privacy, URLs and web presentation

Use the existing canonical routes, then verify them live for the selected release:

| Purpose | URL |
|---|---|
| Marketing | <https://linepaycheck.com> |
| Support | <https://linepaycheck.com/support> |
| Privacy | <https://linepaycheck.com/privacy> |
| Standard EULA | <https://www.apple.com/legal/internet-services/itunes/dev/stdeula/> |

The policy and support pages must match the real publisher, contact, processing, backup and deletion behavior. The existing `Data Not Collected` declaration is historical evidence for 1.0.5; audit the actual new binary and permissions before carrying it forward. User-selected Files/iCloud backups, reports, purchases and support messages are distinct flows.

The owner selected local-only product measurement and manual diagnostic exports. No tracking/attribution SDK, remote funnel events or pay-data backend is authorized by the repositioning. A Cloudflare-hosted web client does not make wage records server-side: browser storage, host requests and user exports must be described accurately in that client's own privacy copy. Do not imply native/web feature parity or automatic synchronization.

The corresponding website candidate is:

> **Check your paycheck against your work.**
>
> Estimate earnings from the hours and rules you confirm. Compare your paystub and review possible differences. Private by default, with advanced tools for lineworker pay.

This is copy guidance, not proof the separate marketing website or Cloudflare client has been updated.

## 8. Subscription continuity

[Pricing](../product/pricing.md) and [onboarding](../product/onboarding.md) own access and offer policy. The v3 name does not change:

- One `LinePaycheck Pro` subscription group and the existing `linepay.pro.monthly` / `linepay.pro.yearly` products.
- US anchors of $9.99/month and $79.99/year; actual storefront prices come from StoreKit.
- Seven-day annual introduction for eligible customers when the actual offer is available; Monthly is immediately paid.
- A first complete comparable audit free, separate from subscription enrollment and an unused Free audit during Pro access.
- Readable/exportable saved records after Pro ends; no paywall on the worker's existing evidence.

Retain existing subscription display names unless separately reviewed. Candidate copy must not promise an introductory offer when StoreKit eligibility or metadata is unknown. Use “Local prices and any eligible introductory offer are shown before purchase” in the listing; the actual paywall supplies full price, renewal and cancellation terms.

## 9. App Review notes candidate

The route below follows the v3 implementation labels. It is **pending final native/UI acceptance**, not a tested review receipt. Replace it with the exact shipped steps and supply a synthetic paystub attachment or the verified in-app review sample before submission. Do not leave a reviewer to invent real payroll evidence.

```text
Lineman Pay is a private work-record and paycheck-comparison utility. No account or employer login is required. It estimates earnings only under confirmed, supported rules and does not certify legal entitlement.

Suggested review path:
1. On a fresh launch, tap "Check my paycheck". For specialist settings, the alternative is "Set up lineworker or advanced pay".
2. Complete Pay basics and Pay period. On Your rules, leave "My overtime rules still need checking" on if the overtime rules are unknown; unknown coverage must remain a review state. Confirm the information you entered.
3. Record actual work for the selected period. On "Your expected pay", use "Add more work" until the work record is complete, then tap "Compare my paystub".
4. Enter the attached synthetic paystub details by hand, or use the scan/import route. Review extracted figures, matching pay-period dates, gross basis and work completeness before confirming.
5. Tap "View paycheck result". Review the compared scope, possible difference or review state, and its evidence. A different pay period is blocked rather than silently matched.
6. The first complete comparable audit is free without subscription enrollment. Ongoing new checks require Pro. The optional offer can be dismissed; saved work and checks remain accessible.
7. Open Settings > View Pro options to review Monthly/Annual, Restore Purchases and subscription management. Prices and any annual introductory offer depend on StoreKit and eligibility.

Calculations and paystub processing happen on-device. Manual exports/backups are initiated by the user. Existing technical IDs and subscription products remain unchanged.
```

## 10. What's New candidate

Use only if the final submitted build includes the accepted generic journey. Add other v2 improvements individually after their final release gates; this is not a declaration that the whole roadmap is complete.

```text
A simpler way to check your paycheck.

Start with hourly pay, record your work and compare your paystub from the expected-pay screen. Uncertain overtime rules and mismatched pay periods stay visible for review.

Your lineworker and advanced pay settings remain available, along with your saved work and paycheck history.

Calculations depend on the supported rules and information you confirm. A possible difference is a prompt to review, not a legal finding.
```

## 11. Submission and experiment gates

Before publication:

- [ ] Confirm name availability, brand review and owner risk decision; retain the bundle ID and upgrade path.
- [ ] Final native/domain/StoreKit gates pass for the exact source; inspect the generic and advanced journeys, large text and failure states.
- [ ] Complete physical-device/manual gates required by the shipped features; code or Simulator evidence cannot substitute for them.
- [ ] Update the claim register for the new name, audience, actual feature scope and source-bound screenshots.
- [ ] Verify support/privacy pages, final permissions, encryption declarations, privacy answers, territory and subscription configuration.
- [ ] Validate the final pasted field lengths/UTF-8 bytes, description, EULA/Privacy links and review attachment.
- [ ] Archive, sign and hash the actual binary; record selected Apple build and exact metadata in the release receipt.
- [ ] Set **MANUAL** release, submit under the authorized release request and read back App Review state.
- [ ] After Apple approval, perform the authorized manual public release and verify the public listing. Approval, submission and publication remain distinct states.

After publication, test one creative variable at a time. First compare the headline “Is Your Paycheck Correct?” with “Spot Possible Pay Differences” while preserving actual UI and scope. Apple's [Product Page Optimization](https://developer.apple.com/app-store/product-page-optimization/) tests creative assets; those results do not establish a winning indexed app name. Use the [growth plan](../growth/marketing.md) for segments, uncertainty and local-only measurement limits; no campaign or spend is authorized by this document.

## Sources and historical context

Apple field constraints verified October 19, 2026:

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/): name and subtitle limits, installed identity, categories.
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/): 100-byte keywords, 170-character promotional text, 4,000-character description/What's New, 4,000-byte review notes, release-mode meaning.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): review the current rules against the submitted product and assets.

For the dated pre-v3 strategy, use the [October 19 baseline](https://github.com/RunLumi/linepay/blob/1da1059e0c190d4ca938d5852bf8ce893ef86608/docs/release/app-store.md). Keep historical receipts and original failures intact; a candidate rewrite is not evidence that an old store page changed.
