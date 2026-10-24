# Paycheck Audit — App Store candidate

[Release home](README.md) · [v3 plan](../plan/v3.md) · [Pricing](../product/pricing.md) · [Claims](../legal/claim-register.md)

> **Canonical App Store copy and presentation. Updated October 24, 2026.** The owner corrected the selected full-update name to **Paycheck Audit**, superseding Lineman Pay. The new name must appear in the installed app and editable App Store listing. Earlier signed builds, submitted metadata and screenshots remain historical evidence for their recorded names; they do not verify this corrected candidate. Final binary validation, metadata save, submission and public release are pending.

> **October 23 name-only submission:** The owner selected [1.0.6 (14)](evidence/release-1.0.6-2026-10-23.md) from released 1.0.5 source. Apple saved **Lineman Pay** and accepted the version as **WAITING_FOR_REVIEW**, release type **MANUAL**. Existing specialist copy, subtitle and eight screenshots were retained. The broader metadata and 1.1.0 experience below remain candidates; no public release is claimed.

## Decision and release boundary

The target public listing is **Paycheck Audit**, with the subtitle **Compare Pay & Track Hours**. Its promise is:

> Track what you worked. Compare expected pay with your paystub. Understand possible differences.

Start with US hourly workers with variable schedules or supported overtime and premiums. Preserve lineworker capabilities as an advanced path. A paycheck audit means a traceable comparison within disclosed coverage; it does not establish every legal entitlement, determine wage theft or guarantee recovery.

| State | Evidence and meaning |
|---|---|
| Existing 1.0.5 | The October 22 public listing and Apple GET readbacks retained **LinePaycheck: Lineman Pay**, version 1.0.5. The [submission receipt](evidence/release-1.0.5-2026-10-05.md) and [claim register](../legal/claim-register.md) retain the dated build 11, specialist-copy and screenshot evidence. |
| vNext candidate | Signed local 1.1.0 (13) is retained privately. October 22 GET readback found processed TestFlight 1.1.0 (12), no observed build 13 reservation/upload, and no editable 1.1.0 App Store version. Copy, screenshots and review routes below still require acceptance against the final selected binary. |
| Submitted / public vNext | Record the actual selected build, metadata, screenshots, release mode and Apple state in a new source-bound release receipt. No vNext submission or public-state claim is made here. |

Built-in Browser is available, but App Store Connect requires secure user sign-in. Paid Applications Agreement acceptance remains unverified; the owner's “I’ll handle it” reply is not an acceptance receipt. Recheck the selected build, editable version, metadata and manual release setting before any authorized write. If source changes require another archive, first check Apple's build reservations to avoid reusing an uploaded build number.

Keep `com.streamentry.linepay`, the `LinePay` project/scheme/target, `LinePayDomain`, StoreKit product IDs and stored data identifiers unchanged. For the 1.1.0 candidate, set the home-screen display name to **Paycheck Audit**; keep the technical product name and existing subscription names unchanged. This does not rename the bundle, project, domain module, or stored data. Paycheck Audit availability and trademark clearance have not been established. The historical LINE PAY mark check concerned the superseded name and does not clear this name.

## 1. Store-page job

The first three screenshots must make sense without knowing what a lineman or CBA is. They should show:

1. A comparison between recorded work, expected gross wages and confirmed paystub values.
2. Simple hourly setup with optional, explicitly confirmed rules.
3. Paystub review with editable extracted values and matching pay-period dates.

Advanced copy can then explain supported callout minimums, per diem and dated rules. Do not promote storm-specific, statutory, union or agreement coverage merely because a worker can enter a custom rate.

The app does not retrieve paystubs from an employer portal, provide direct deposit, process payroll, calculate every tax/deduction or certify employment-law compliance. Acquisition copy must make that distinction clear before a user supplies work records.

## 2. US English metadata candidate

| Field | Exact candidate | Measured length / limit |
|---|---|---:|
| App Store name | **Paycheck Audit** | 14 / 30 characters |
| Subtitle | **Compare Pay & Track Hours** | 25 / 30 characters |
| Promotional text | **Track hours, review paystub figures, and understand possible pay differences—privately.** | 87 / 170 characters |
| Keywords | `paystub,checker,discrepancy,verification,overtime,hourly,timesheet,shift,lineman,callout,lineworker` | 99 / 100 UTF-8 bytes |
| Primary category | **Finance** | Retain only if it accurately describes the final product |
| Secondary category | **Utilities** | Confirm final App Store Connect value |
| Price | **Free with In-App Purchases** | Local prices come from StoreKit |
| Localization | **English (U.S.)** | No unsupported language or payroll-localization claim |

The name/subtitle and keyword limits were checked against Apple's [app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) and [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) on October 19, 2026. Keywords are an initial relevance hypothesis, not evidence of organic ranking or demand. No competitor or payroll-provider names belong in the keyword field.

Do not copy the old `LinePaycheck: Lineman Pay` / `Overtime, Callout & Per Diem` metadata into a new broad release. That is the specialist baseline recorded in the historical receipt. The original strategy remains available at [the pre-v3 revision](https://github.com/RunLumi/linepay/blob/1da1059e0c190d4ca938d5852bf8ce893ef86608/docs/release/app-store.md).

## 3. App Store description candidate

Use the following plain text only after the final build supports every advertised route. Keep the working Standard EULA and Privacy links; 1.0.2 was rejected for omitting the EULA link. Do not print a USD price in a description reused across storefronts.

```text
Want to compare your paycheck with the work you logged? Paycheck Audit helps hourly workers estimate gross wages from the hours and pay rules they confirm, then compare that estimate with confirmed paystub figures.

START WITH YOUR WORK

Enter your hourly rate, pay period and actual work. Confirm supported overtime rules and premiums instead of relying on automatic assumptions. Review estimated gross earnings and the calculation behind them.

REVIEW THE PAYSTUB

Scan or import a paystub, or enter its details by hand. Review extracted figures and confirm the dates and earnings basis before comparing. A paystub alone cannot prove which hours you worked.

UNDERSTAND THE RESULT

Compare like-for-like gross wages under the rules you confirmed. Review possible differences alongside the work facts, rule versions and paystub values. If you cannot confirm that your work log is complete, a rule is unclear, or pay periods do not align, keep the result in review. A match covers only the items compared.

BUILT FOR COMPLEX PAY, TOO

Lineman and lineworker pay settings remain available for supported callout minimums, per diem, overtime and dated pay rules. Your existing work records and historical checks remain part of your record.

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

Follow [DESIGN.md](../../DESIGN.md) and the [store screenshot system](../design/app-stores/screenshots.md). The table below defines composition requirements, not rendered assets. A real synthetic-data capture/export set for iOS 1.1.0 build 12 exists under `assets/store/raw/` and `assets/store/exports/`, with its source/build binding recorded in [`capture-manifest-ios-1.1.0-en-US.json`](../../assets/store/source/capture-manifest-ios-1.1.0-en-US.json). Those images are candidate evidence for build 12 only. Recapture and revalidate them from the final signed candidate before submission; they do not prove build 13's screens.

| Order | Headline | Actual screen evidence required |
|---:|---|---|
| 1 | **Is Your Paycheck Correct?** | Expected vs confirmed paystub amount with `Possible difference` or the actual scoped result label and visible coverage explanation |
| 2 | **Track Hours. See Expected Gross.** | Pay ledger showing the period, recorded hours, estimated gross wages and the route to rules used |
| 3 | **Import. Review. Compare.** | Imported paystub review, source-period dates and human confirmation |
| 4 | **Possible Double-Time Difference.** | A daily double-time comparison traced to the recorded hours and the configured rule; do not imply general overtime coverage |
| 5 | **Keep the Evidence.** | Comparison line, paystub source/value and the link to its recorded work component; do not imply the full rule snapshot is on this screen |
| 6 | **Built for Complex Pay, Too.** | Retained advanced lineworker settings with supported callout/per-diem scenarios |

Use real candidate captures with clearly synthetic facts and the appropriate Free/Pro qualifier. Keep historical 1.0.5 captures and their manifest intact; new screenshots need a new source/build-bound capture record. Do not use generated UI, worker testimonials, union badges, fictional employer replies or dramatic “money owed” banners. A question headline must be answered by a visibly scoped comparison, not an unqualified correct/incorrect verdict.

Inspect small-screen, large-text and dark appearances in the actual app. The submission set must remain legible at thumbnail size. Screenshot 4 is omitted if the configured daily double-time comparison cannot be captured with its scope visible. An unresolved-rule warning must never be dressed up as a detected gap. More than 40 actual weekly hours without mapped weekly coverage remains **Needs review**, even when entered gross amounts match; a configured daily double-time difference is not evidence of a weekly-overtime shortfall.

### Product Page Header and Search Results creative candidates

Apple treats these as creative assets separate from the screenshot set. Current creative assets appear on iOS 27 and iPadOS 27 and later. For these iPhone candidates, the selected specifications are 21:9 at 3840 × 1646 for the Product Page Header and 3:2 at 1920 × 1280 for Search Results. Keep the real, source/build-bound screenshots above as their own assets.

| Placement | Local candidate | Size | Visual |
|---|---|---:|---|
| Product Page Header | [PNG](../../assets/store/creative/ios/1.1.0/en-US/2026-10-22/product-page-header-21x9.png) | 3840 × 1646 | Two blank ledgers, restrained teal row bridges and one graphite pencil |
| Search Results | [PNG](../../assets/store/creative/ios/1.1.0/en-US/2026-10-22/search-results-3x2.png) | 1920 × 1280 | Two blank ledgers with four aligned rows and a restrained shared teal baseline |

The October 22 candidates were generated separately with OpenAI built-in ImageGen. Their [manifest](../../assets/store/creative/ios/1.1.0/en-US/2026-10-22/manifest.json) binds both exact prompts, untouched originals, returned generated filenames and exports by checksum. The tool did not report a model or seed. Original resolutions are 1914 × 822 (header) and 1536 × 1024 (search); macOS `sips` upsampled them to the required export dimensions. They contain no interface, text, payroll values, logo or outcome claim, and have no alpha channel. The earlier October 20 candidates and their [incomplete source record](../../assets/store/creative/ios/1.1.0/en-US/manifest.json) remain intact as historical artifacts. These files are **local candidates only**: they have not been uploaded, submitted, or approved. They complement the actual app screenshots and do not replace them; generated UI must not be used as a substitute for real app captures. Apple recommends one clear header idea and a search-result creative that makes the app's purpose obvious; the art still needs the final App Store preview and owner review before submission. See Apple's [creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/) and [asset best practices](https://developer.apple.com/app-store/asset-best-practices/).

## 6. App preview and icon

Retain the recognizable Line Gap geometry and the Precision Industrial Minimalism system. No icon redesign is required to publish this copy. Review any actual asset change separately at Home Screen and App Store sizes.

Add a preview only after the journey is accepted. Use real captured UI: confirmed rules → actual work → estimated gross wages → reviewed paystub → scoped result → evidence. No stock footage, fake employer text or recovery claim.

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
Paycheck Audit is a private work-record and paycheck-comparison utility. No account or employer login is required. It estimates earnings only under confirmed, supported rules and does not certify legal entitlement.

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
LinePaycheck is now Paycheck Audit.

A clearer paycheck-checking journey with typed work drafts, optional password-protected backups and benefits tracking. Review possible differences with their work and paystub evidence.

Your saved history and advanced lineman pay settings remain available. Microphone recording and crew-rule sharing are unavailable in this version.
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
