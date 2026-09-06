# LinePaycheck — App Store Screenshot Production

> **Show the work. Show the math. Show the check.**
>
> The product is the visual. The caption tells the viewer why it matters.

**Version:** 1.0 · **Platform references checked:** September 5, 2026  
**Status:** Production specification and release-gated storyboard. This document does not create screenshots, verify rendering, or establish conversion lift.

## 1. The decision in one minute

| Decision | Default |
|---|---|
| Creative direction | **The Proof Sheet**: an editorial frame around genuine product evidence |
| First market | U.S. English; lineworkers checking complex hourly pay |
| Platform now | iOS; native Android captures only when Android exists |
| Orientation | Portrait for the phone listing |
| Main visual | One large, legible capture of an actual app state |
| First three | Expected pay → confirmed rules → possible difference |
| Story continuity | One synthetic period, one profile, one mathematically consistent paycheck |
| Color | Porcelain/graphite; restrained Oxide; no feature-by-feature rainbow |
| Message | One short benefit per frame, supported by visible UI |
| Trust | Clear scope, sample-data labeling, and honest paid-feature disclosure |
| Optimization | Qualified understanding and downloads, not sensational claims |

### Read alongside

- [Design system](../../../DESIGN.md): visual hierarchy, colors, evidence, accessibility, and privacy language.
- [App Store playbook](../../release/app-store.md): canonical metadata and screenshot sequence.
- [Logo and app icon](../logo.md): identity artwork and lettering.
- [Pricing](../../product/pricing.md): actual Free/Pro boundary; never invent one for artwork.
- [Onboarding](../../product/onboarding.md): proof-first seven-day annual trial offer and separate first-audit-free access.
- [iOS release plan](../../plan/ios-1.0.md): shipping capability, not marketing aspiration.
- [Mobile QA](../../testing/maestro.md): the existing capture/verification context.

This document makes the existing store sequence executable. It does not silently add features, reorder the commercial strategy, change the bundle ID, or replace the design system.

## 2. Why this should look unlike a generic finance listing

A lineworker should recognize a useful record, not an ad wearing a hard hat.

The distinction is **continuity of evidence**. The same hours, rate, period, expected gross, paycheck gross, and difference recur across the appropriate frames. Someone who reads carefully can verify the story instead of discovering a new invented number on each slide.

The Proof Sheet uses the same leading edges, restrained rules, and trailing amount alignment as the app. It feels authored because the data and composition agree, not because every frame has a different illustration.

Do not imitate:

- a banking dashboard with a green balance and no pay context;
- a utility-equipment catalog with hazard stripes and worker portraits;
- a subscription landing page with review stars, oversized savings claims, or a countdown;
- a concept-art carousel that depicts a better app than the submitted build.

The first three frames must answer: **Is this for my work? Does it use my rules? What does checking the paycheck add?**

Apple notes that, depending on orientation, the first one to three screenshots can appear in search when no app preview is present. Treat this as a reason to prioritize the opening story, not a guarantee of a particular search layout. [S1]

## 3. Product truth is the first production gate

Apple requires metadata to reflect the actual app, screenshots to show it in use, and featured paid content to be identified appropriately. Text/image overlays are permitted; that does not permit fictional functionality. [S2]

Apply these LinePaycheck rules:

1. **Capture the real implementation.** A seeded development build may load synthetic facts, but must use the same UI, calculation, and entitlement behavior as the release candidate for the represented state.
2. **Never paint features into the UI.** No fake buttons, invented evidence links, patched totals, fabricated agreement coverage, or removed uncertainty labels.
3. **No future-state art in the upload folder.** Internal concepts live separately and are clearly labeled `CONCEPT — NOT FOR STORE UPLOAD`.
4. **A disabled feature is not a shipping feature.** Do not market recurring audits when commerce and auditing are unavailable in the submitted build.
5. **Label sample facts.** Use `Illustrative data` near numerical examples. A synthetic difference is not a testimonial or money recovered.
6. **Disclose real access requirements.** If the featured workflow requires Pro beyond the first free check, use a readable `Pro for ongoing checks` or equivalent accurate qualifier.
7. **Privacy applies to both tiers.** Never present private processing as something only a subscriber receives.

A three-frame truthful set beats an eight-frame fictional set. If the core audit capability is unfinished, either defer the audit-led listing or obtain an explicit product decision for a calculator-only release. Do not silently substitute fake audit screenshots to preserve the planned sequence.

## 4. One source of truth for the sample paycheck

Use the synthetic example already established in `DESIGN.md`.

**Design fixture identifier:** `store-week-2026-08-v1`  
This is the fixture specification. It does not assert that a checked-in executable fixture already exists. Creating the tested seed/fixture is a prerequisite for producing these captures.

| Fact | Value |
|---|---|
| Period | August 24–30, 2026 |
| Payroll timezone | `America/Chicago` |
| Currency / comparison basis | USD / gross wages |
| Profile | `My current pay` |
| Rule snapshot | Version 3; entered/confirmed by the user in the sample |
| Base rate | `$58.00/hour` |
| Sample daily rule | After 8 paid work hours in a local work date, use `2×` |
| Recorded work | 46 hours total: 40 regular, 6 double time |
| Expected regular | `40 × 58 = $2,320.00` |
| Expected double time | `6 × 58 × 2 = $696.00` |
| Expected gross | `$3,016.00` |
| Sample paystub regular | 40 hours, `$2,320.00` |
| Sample paystub double time | 5 hours, `$580.00` |
| Sample paystub gross | `$2,900.00` |
| Possible gross difference | `$116.00` |

### Reproducible work distribution

A simple seed can use 8 paid hours on August 24, 25, 26, and 28, and 14 paid hours on August 27. This yields 40 regular hours and 6 double-time hours under the explicitly entered sample rule.

These are synthetic paid-work facts, not a recommendation about shift length, breaks, safety, or a real collective bargaining agreement. Do not label them as an official local/utility agreement.

Callout minimums, per diem, Sunday premiums, deductions, and net pay are **not configured in this fixture**. Do not add them merely because those terms help marketing. If a supplemental feature example is needed, give it a separate tested fixture and do not pass its totals off as this paycheck.

### State continuity across frames

- Frames 1–2 show the work/rules before comparison.
- Frame 3 shows the completed comparison after the relevant paystub fields are confirmed.
- Frame 4 explains the same `$116.00` difference, when line-level reconciliation actually exists.
- Frame 5 shows one work-entry detail from the same period.
- Frame 6 shows the earlier source-confirmation stage; it must not simultaneously claim that the uncertain field has already been verified.
- Frame 8 shows the saved result for that period, when durable history exists.

A gross-only comparison cannot substantiate `one missing double-time hour`. If that is all the build supports, show the gross difference and no invented reason. The sample paystub must contain line-level facts before a line-level explanation is allowed.

Keep the sample document synthetic from the start. Do not use a real paystub and rely on a blur over the worker's name. Exclude real employer logos, employee IDs, addresses, signatures, barcodes, bank details, and QR codes.

## 5. The release-gated storyboard

Preserve the order from `docs/release/app-store.md`. The eight slots are an editorial plan, not eight mandatory uploads. Frames 3, 4, 6, and 8 require the corresponding implemented behavior. Never pad the set just to fill the maximum.

| Slot | Headline | Product proof | Gate |
|---|---|---|---|
| 01 | **Know what your work should pay.** | Pay Ledger: period, `$3,016.00` expected gross, hours, formula | Scoped calculation and accurate period filtering |
| 02 | **Built around your pay rules.** | User-entered `$58.00` rate and `2× after 8 h` rule | Rule setup with explicit values and provenance |
| 03 | **Spot possible pay differences.** | `$3,016.00` expected vs `$2,900.00` paystub; `$116.00` possible difference | Real comparable-paycheck reconciliation |
| 04 | **See the math behind every hour.** | Ledger detail / Evidence Receipt | The level of explanation shown is implemented |
| 05 | **Log the shift. Keep the evidence.** | Work entry with date, start/end, timezone, and duration | Genuine logging/editing and save behavior |
| 06 | **Scan the paystub. Confirm the fields.** | Original source beside fields needing review | On-device capture/OCR, correction, and provenance |
| 07 | **No account. No uploads to us.** | Actual privacy/data-control screen | Bounded claim matches the submitted build |
| 08 | **Keep every pay period straight.** | Saved period with meaningful comparison status | Durable history and correct entitlement behavior |

**Copy safety clarification for slot 07:** the store master previously used `No account. No paycheck upload.` The bounded wording here applies `DESIGN.md` v2's more precise privacy rule. Keep the same slot and intent, and reconcile the master copy before submission. Do not promise that user exports, device backups, or Apple purchase traffic never leave the phone.

### Frame 01 — make the job obvious

Optional subhead: `For linemen. Based on the rules you confirm.`

Show the real Pay Ledger, not a welcome screen. The main amount is labeled **Expected gross**, with the period and hours close enough to remain interpretable. Keep `Not compared with a paycheck yet` if that is the actual state.

Composition: porcelain frame, dark headline, large ledger crop. The app's amount is the hero; do not replace it with a larger decorative number outside the UI.

Reject the frame if viewers mistake the amount for a bank balance, take-home pay, or confirmed money owed.

### Frame 02 — credibility through actual configuration

Optional subhead: `Your rate. Your confirmed rules.`

Show the rate and enabled daily rule from the sample. Optional callout/per-diem controls may appear only in their genuine `Not configured` state. Do not select a real union name and imply the app verified its agreement.

Show enough of the rule section to explain the consequence. Avoid a full-length form shrunk until every field becomes unreadable.

### Frame 03 — the differentiated outcome

Optional subhead: `Compare expected gross with your paystub.`

The three essential facts are expected gross, paystub gross, and **possible** difference. Preserve the word `Possible`, the gross basis, and the exact cents. Red-family emphasis stays limited to the actual comparison state, not the whole poster.

If the first audit is free in the submitted build, a secondary caption may state: `First paycheck check free. Pro for ongoing checks.` Do not present a subscription as automatically free or include an unavailable offer.

No `We recovered $116`, `Your employer stole this`, or arbitrary before/after bar lengths.

### Frame 04 — show why, not another dashboard

Use the same numbers and show the applied rule, recorded 6 double-time hours, paystub 5 hours, and formula only if the build can support that explanation. Otherwise show an honest expanded calculation without attributing the gross difference to a specific line.

This is a good place for one **dark-mode capture**. The darker surface represents a closer inspection of evidence, not a new feature color scheme. Preserve the same editorial grid.

If evidence appears only after another tap, capture that screen. Do not fuse several navigation states into a fictional single screen.

### Frame 05 — make routine use look manageable

Capture the actual work-entry/editor flow for August 27. Include the date range, relevant timezone, and clear duration. Do not imply an automatic timer or background location feature if entry is manual.

A callout/overnight alternative can be developed later from an isolated fixture. It must not silently change the 46-hour sample or imply unimplemented storm/rest rules.

Do not show fingers, a worker driving, or the app in use on energized equipment. Ease of use is demonstrated by the interface, not staged unsafe context.

### Frame 06 — uncertainty is proof of care

Show a synthetic paystub crop with the double-time field still awaiting confirmation. Keep `Needs confirmation` visible. If the user confirms five hours, that must be the same five hours used in frame 03.

No scanning beam, fake certainty score, or invented AI message. Capture the correction interface rather than a camera pointed at a real person's payroll document.

The intended reaction is: `I can check what it read`, not `I must trust a black box`.

### Frame 07 — privacy without absolutism

Supporting copy: `Pay details are processed on your device.`

Show a real privacy/settings screen with useful controls or truthful explanations. Do not substitute a giant lock illustration or use a disabled backup switch to imply working backup.

The fuller claim is **no LinePaycheck account and no paycheck uploads to LinePaycheck servers**. Purchase services, user-initiated sharing, and backup behavior retain their actual meanings. `Restore Purchases` is not data recovery.

### Frame 08 — continuity, only after persistence ships

Show the saved August 24–30 result. One genuine seeded period is acceptable; a twelve-month invented history is unnecessary.

A row distinguishes `Matches entered data`, `Needs confirmation`, or `Possible difference` as the underlying state requires. Do not paint green status onto every period. Keep the period accessible after reopening the app before capturing it.

Where the featured history workflow requires Pro, make that requirement readable. Existing user records and the first audit result must not be depicted as held hostage after cancellation.

## 6. Layout system: the Proof Sheet

These are **LinePaycheck composition targets**, not platform rules or proven conversion optima.

### 6.1 Phone master layout

For the recommended iOS portrait master at `1320 × 2868`:

| Region | Starting specification |
|---|---|
| Horizontal editorial margin | `80 px` on each side |
| Top breathing room | About `120 px` |
| Headline | About `104–112 px`, semibold/bold; aim for two lines |
| Supporting sentence | About `48–56 px`; omit rather than force a paragraph |
| Main product window | Begins around `y=580–640`; about `1160 px` wide |
| Bottom safety margin | At least `100 px` for editorial content |
| Small qualifying copy | Readable supporting type; never microscopic legal camouflage |

Recompose when the actual capture needs more space. Do not stretch the image to hit these dimensions. Use a consistent grid across the set, not identical crop coordinates for unrelated screens.

### 6.2 Three permitted compositions

**A. Full interface:** one intact screen scaled proportionally, with a short heading outside it. Use when essential labels stay readable.

**B. Focused product window:** one truthful crop of a real screen, enlarged to make the relevant result readable. Keep the date/basis/state needed to interpret it. Use for the ledger and comparison.

**C. Evidence close-up:** one real evidence screen or source-review screen. One inset from the same source is allowed only when it clarifies the task and does not fabricate an interaction.

A crop may omit irrelevant navigation. It must not omit the warning that makes a claim accurate. Do not reassemble rows, amounts, and controls into a layout the app cannot produce.

### 6.3 Editorial continuity

- Frames 1–3 use consistent typography, margins, and porcelain editorial backgrounds.
- Introduce dark mode deliberately, preferably in frame 4; do not alternate appearances randomly.
- Keep amount emphasis inside the product image. Marketing lettering does not compete with another giant number.
- Use the Line Gap at most sparingly, such as a small first-frame identity detail. Do not draw a conductor line across eight panels.
- Every image stands alone. No sentence or crucial UI element continues across a carousel seam.
- No perspective-tilted devices, stacked phones, cinematic lighting, floating glass cards, or artificially extruded UI.

A full-screen 3D phone frame often makes the actual interface too small. Default to a clean product window. A restrained device frame is optional on Apple assets only when it improves context and its use complies with the applicable asset license; it is not the default.

### 6.4 Typography and color

Inside captures, preserve the native typography exactly. For editorial overlays, use the approved marketing type/wordmark from `logo.md`; Inter is a practical cross-store starting point. This does not add a custom typeface to the app.

Use sentence case. Use line breaks that preserve phrases: `your work`, `pay rules`, and `possible difference`. Never squeeze text horizontally or distort letter widths to fit.

Use the parent design system's primary text for most captions. Essential editorial text targets at least `4.5:1` contrast, with stronger contrast for focal claims and amounts. Do not rely on teal-on-teal, opacity, or a gradient to make words appear premium.

## 7. Thumbnail and accessibility quality

Test the actual exports in a store-like layout, not just a desktop artboard:

- At around **200 px image width**, the headline, primary amount, and its state should be understandable without zooming. This is an internal stress test, not an official store dimension.
- At larger product-page viewing size, the supporting formula and qualification must be legible.
- Check the first three as a group and each one alone.
- Verify that `Possible`, `Expected gross`, `Needs confirmation`, and paid-feature qualifiers have not become unreadable.
- Check light and dark surrounds; thin graphite borders must not disappear into the store surface.
- Use meaningful alt text where the platform supports it; preserve an internal description for every image regardless.

Static store images do not inherit Dynamic Type or VoiceOver semantics from the app. An accessible app capture can still become an inaccessible promotional image after shrinking and overlaying text.

Draft screenshot descriptions, kept under 140 characters for the Play handoff:

| Slot | Description |
|---|---|
| 01 | Sample Pay Ledger showing $3,016 expected gross from 40 regular hours and 6 double-time hours. |
| 02 | User-entered pay rules: $58 hourly rate and double time after 8 hours, with optional rules not configured. |
| 03 | Sample gross comparison: $3,016 expected, $2,900 on the paystub, and a possible $116 difference. |
| 04 | Sample explanation comparing 6 recorded double-time hours with 5 paystub hours at a $58 base rate. |
| 05 | Work-entry screen with start and end times, work date, payroll timezone, and duration. |
| 06 | Synthetic paystub source and extracted double-time hours awaiting the user's confirmation. |
| 07 | Privacy settings explaining on-device pay processing and no paycheck uploads to LinePaycheck servers. |
| 08 | Saved sample pay period for August 24–30 with its expected pay and comparison status. |

Update these descriptions to match the final capture. Do not copy the frame-04 description when the build only supports gross-level comparison.

## 8. Platform export specifications

The following is a checked reference, not a permanent substitute for each store's current upload validation. Recheck official specifications at release; do not change the design because of an outdated template from a screenshot generator.

### 8.1 Apple App Store

Apple accepts **1–10 screenshots** in JPEG/JPG/PNG without alpha or transparency. Its current 6.9-inch phone bucket accepts portrait `1260 × 2736`, `1290 × 2796`, or `1320 × 2868`, with corresponding landscape dimensions. Our default is `1320 × 2868` portrait. [S3]

Provide captures appropriate to supported devices. Apple can scale the required high-resolution set when UI is the same; use device-specific captures when it differs. If the app supports iPad, supply the required iPad set from the actual iPad layout, not a stretched phone image. [S3, S4]

Practical export choice: lossless, opaque sRGB PNG for crisp interface text. This is our production preference, not a claim that Apple only accepts sRGB PNG.

No Android navigation, Google Play badge, unapproved platform claims, or irrelevant marketplace imagery inside Apple assets. [S2]

### 8.2 Google Play — future native Android release

For phone screenshots, Google accepts JPEG/24-bit PNG without alpha, dimensions between `320` and `3840 px`, and a long edge no more than twice the short edge. A listing needs at least two screenshots; up to eight per supported device type are allowed. For screenshot-based recommendation eligibility, the guidance calls for at least four qualifying app images at `1080 × 1920` portrait or `1920 × 1080` landscape. [S5]

Use **1080 × 1920 portrait** as the Android editorial master, with native Android captures. Do not reuse iPhone chrome or stretch Apple's taller aspect ratio into it. Keep all meaningful crop labels intact.

Google discourages unnecessary device imagery, store badges, promotional ranking/price claims, and install CTAs in these assets. Include useful localized alt text; its guidance recommends 140 characters or fewer. [S5]

### 8.3 Google Play feature graphic

Separate deliverable: **1024 × 500**, JPEG or 24-bit PNG without alpha. [S5]

Suggested direction: a restrained Oxide field, readable porcelain headline, and a genuine cropped comparison/evidence fragment. The headline can be `Your work. Your rules. Your check.` Avoid turning the graphic into an oversized duplicate of the app icon or implying a recovery amount.

Keep the central message away from potential playback overlays/cropping. Do not claim Android availability or produce a Play submission until the native app exists.

## 9. Capture workflow and provenance

Use the existing native build and Maestro/simulator workflow. Do not create a second marketing-only UI implementation.

### Capture preparation

1. Select the exact source commit, build number, device, OS, locale, appearance, and text size.
2. Load a tested synthetic fixture into a disposable test installation. Never seed a user's real database.
3. Reach the target state through real interactions or a test-only seed path that does not change product behavior.
4. Confirm the calculation, rules, source status, and entitlement state before capturing.
5. Remove debug banners, keyboards that obscure the claimed feature, unrelated notifications, personal account details, and development error overlays.
6. Capture and retain the original image before any editorial composition.

Use a stable status-bar appearance when supported by the capture tooling; do not pretend connection indicators prove offline operation. Control the app's sample date/time separately from decorative status-bar time. A reproducible fixture must not depend on today's date.

### Allowed post-processing

- Proportional downscaling.
- A truthful crop with recorded source bounds.
- A plain editorial background.
- Headline, supporting caption, sample label, and accurate paid-feature qualifier outside the app image.
- Lossless export and correct color-profile conversion.

### Not allowed

- Retouching amounts, rates, dates, comparison state, permissions, or subscription status inside the UI.
- Compositing a newer UI component into an older capture.
- Removing uncertainty or missing-rule notices to make the app seem more capable.
- Adding an evidence link, backup control, agreement certification, or AI feature that does not exist.
- Filling whitespace with fake testimonials, invented reviews, customer logos, badges, or exaggerated savings.

If the app needs a visual improvement, fix the app, rebuild, and recapture. Do not repair product-design debt inside the marketing file.

## 10. Asset organization and manifest

The following are **proposed production paths**, not files created by this specification:

```text
assets/store/
  source/
    proof-sheet-master.<design-tool-format>
    captions-en-US.json
    capture-manifest.json
  raw/
    ios/<build>/en-US/<device>/<appearance>/
    android/<build>/en-US/<device>/<appearance>/
  exports/
    ios/<version>/en-US/6.9/
      01-expected-pay.png
      02-confirmed-rules.png
      03-possible-difference.png
      ...
    android/<version>/en-US/phone/   # Future
  qa/
    contact-sheet.png
    thumbnail-strip.png
    review.md
```

Keep concepts outside `exports/`. Filename numbering is for reliable upload order, not an ASO ranking technique.

Minimum manifest per image:

```json
{
  "id": "03-possible-difference",
  "platform": "ios",
  "locale": "en-US",
  "sourceCommit": "REPLACE_WITH_CAPTURE_COMMIT",
  "appVersion": "REPLACE_WITH_CAPTURE_VERSION",
  "buildNumber": "REPLACE_WITH_CAPTURE_BUILD",
  "device": "REPLACE_WITH_CAPTURE_DEVICE",
  "osVersion": "REPLACE_WITH_CAPTURE_OS",
  "appearance": "light",
  "fixtureID": "store-week-2026-08-v1",
  "productState": "confirmed-gross-comparison",
  "rawCapture": "REPLACE_WITH_RAW_IMAGE_PATH",
  "rawSHA256": "REPLACE_WITH_HASH",
  "sourceCropPixels": null,
  "exportPixels": [1320, 2868],
  "headline": "Spot possible pay differences.",
  "qualifier": "Illustrative data",
  "accessRequirement": "REPLACE_WITH_ACTUAL_FREE_OR_PRO_REQUIREMENT",
  "verifiedAgainstBuild": false,
  "approvedForUpload": false
}
```

Replace every placeholder before approval. Record a crop rectangle as `[x, y, width, height]` when cropping. Keep source dimensions and editorial scaling in the composition source. Reviewers should be able to trace every exported pixel region to the raw capture and every number to the tested fixture.

Do not ship a complex asset-management service for eight screenshots. A small manifest and editable master are sufficient.

## 11. Localization and ASO without keyword theater

Launch with carefully proofread U.S. English. Preserve the brand spelling; localize editorial text and native UI together when the language is actually supported.

For each later locale:

- Render real localized interface captures and check number, currency, date, and timezone labels.
- Reflow captions; do not shrink longer translations into unreadable text.
- Keep U.S.-only rule coverage explicit. A translated caption does not create local payroll support.
- Have a fluent reviewer check trade vocabulary and the distinction between expected, paid, and possible difference.
- Keep right-to-left language behavior native; the identity mark does not become a different logo.

Use `lineman`, `paycheck`, `overtime`, and `callout` where they naturally explain a real benefit. Metadata strategy remains in `docs/release/app-store.md`.

Do not promise ranking improvements from screenshot filenames, repeated keywords embedded in images, or unverified search-volume estimates. These assets primarily explain the product and earn a download; keyword selection and conversion are related but different jobs.

## 12. Quality gates before upload

A screenshot is not approved merely because its dimensions are accepted.

### Product and numerical truth

- [ ] Every pictured action and result exists in the release candidate.
- [ ] Period, timezone, currency, and gross/net basis are correct.
- [ ] `$2,320 + $696 = $3,016`; sample paystub `$2,320 + $580 = $2,900`; difference `$116`.
- [ ] Specific discrepancy reasons are supported by actual compared facts.
- [ ] Unconfirmed fields do not look confirmed.
- [ ] Sample facts cannot be mistaken for a real recovery/testimonial.
- [ ] Optional rules and agreement verification are represented honestly.
- [ ] Free/Pro requirements and privacy wording match the build.
- [ ] History screenshots survive relaunch; purchase restoration is not presented as backup.

### Visual craft

- [ ] First three frames explain the product without requiring the others.
- [ ] Each frame has one focal message and one main product view.
- [ ] Primary amount, context, and uncertainty are readable at the chosen preview sizes.
- [ ] Native UI has not been stretched, reconstructed, or cosmetically falsified.
- [ ] Headline line breaks, margins, crop alignment, and text weight are deliberate.
- [ ] Light/dark captures remain consistent with the actual app.
- [ ] Sample and paid-feature qualifiers are not hidden in tiny low-contrast text.
- [ ] No decorative phone collage, worker imagery, fake badge, countdown, or glow.

### Delivery

- [ ] Exact permitted dimensions, orientation, and formats checked against current store guidance.
- [ ] No alpha/transparency in uploaded screenshot images.
- [ ] File size and color rendering inspected after export.
- [ ] Correct locale and actual supported device family.
- [ ] Ordered filenames, raw captures, fixture revision, and manifest present.
- [ ] Alt descriptions match the exported state where used.
- [ ] All placeholders removed from upload assets and manifest.
- [ ] Final images inspected in the actual store upload/preview interface before submission.

## 13. Validate comprehension before optimizing conversion

Start with the same 5–8 representative users proposed in `DESIGN.md`. This is a small formative review, not a powered A/B experiment.

Show the first three at plausible phone size, without narrating. Ask:

1. What does this app do, and who is it for?
2. Is `$3,016` take-home pay, expected gross, or a bank balance?
3. What does the `$116` difference establish, and what does it not establish?
4. Which details must you enter or confirm?
5. What do you think is free, paid, and uploaded?

Fix recurring misunderstanding before refining shadows or trying new slogans. A beautiful image that implies legal certainty is a failed image.

Then, when traffic supports it, test one meaningful change with Apple Product Page Optimization: for example, the same opening claim with a full-screen ledger versus a larger focused ledger crop. Keep the icon, pricing, and remaining sequence stable. Apple provides treatment allocation and conversion analysis; the test concerns downloads, not automatic proof of paid retention. [S6, S7]

Use the platform's estimate to decide whether the test can be informative. Apple currently describes tests running up to 90 days; the appearance of results after five first-time downloads is not evidence that a winner has been established. [S6, S7]

Report absolute conversion, relative lift, uncertainty, and the exact change. Do not call a low-volume fluctuation a best practice. App Store aggregate data alone does not reveal the private first-audit-to-Pro funnel; do not invent that attribution or introduce a tracking backend just for artwork optimization.

Custom product pages can later align a specific acquisition message with a matching supported feature, such as callout work. They are tailored landing pages, not automatically randomized causal experiments. [S8]

## 14. Production brief

> Produce the LinePaycheck store set as Proof Sheets: a short plain-language benefit above one large, genuine app capture. Preserve the canonical sequence of expected pay, confirmed rules, possible difference, explanation, work logging, source confirmation, privacy, and saved history. Use the same synthetic August 24–30 paycheck wherever related: 40 regular hours and 6 double-time hours at a $58 base rate, $3,016 expected gross, $2,900 sample paystub gross, and a possible $116 difference. Show only features and explanation depth the build actually supports. Keep the interface opaque, the numbers aligned, and uncertainty visible. Use porcelain, graphite, and restrained Oxide. No stock workers, generated UI, fake recovered-money claims, decorative phone stacks, artificial reviews, or keyword wallpaper. Deliver untouched raw captures, editable composition sources, localized captions, an auditable capture manifest, and phone-size proof sheets. A screenshot is finished only when it is attractive, legible, truthful, and reproducible.

## References

Primary platform sources checked September 5, 2026. Official upload constraints are distinct from LinePaycheck's creative targets and unvalidated hypotheses.

- **[S1] Apple — Creating your product page:** screenshots, search presentation, and benefit-led sequencing. https://developer.apple.com/app-store/product-page/
- **[S2] Apple — App Review Guidelines, 2.3.1–2.3.3 and 2.3.9–2.3.10:** accurate capability, paid-feature disclosure, actual UI, and rights/platform imagery. https://developer.apple.com/app-store/review/guidelines/
- **[S3] Apple — Screenshot specifications:** sizes, counts, formats, and transparency restrictions. https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- **[S4] Apple — Upload app previews and screenshots:** device/localization scaling and Media Manager. https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- **[S5] Google Play — Add preview assets:** phone screenshot/export requirements, recommendation criteria, feature graphic, and alt text. https://support.google.com/googleplay/android-developer/answer/9866151?hl=en
- **[S6] Apple — Create/run a Product Page Optimization test:** traffic allocation, duration estimate, and test limits. https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/create-a-test and https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/run-a-test
- **[S7] Apple — Product Page Optimization analytics:** conversion, lift, uncertainty, and results interpretation. https://developer.apple.com/help/app-store-connect-analytics/acquisition/product-page-optimization/
- **[S8] Apple — Get started with custom product pages:** matching acquisition messages to relevant product-page content. https://developer.apple.com/videos/play/tech-talks/10886/

**Completion boundary:** this document specifies the work. It does not create raw captures, implement the sample fixture, verify current OCR/history availability, run a conversion experiment, or submit anything to either app store.
