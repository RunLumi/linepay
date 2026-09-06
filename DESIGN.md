# LinePaycheck Design System

> **Precision Industrial Minimalism**
>
> A private field notebook with the clarity of a precision instrument.
>
> **The work is the input. The paycheck is the question. The evidence is the interface.**

**Revision:** 2.0 · **Research checked:** September 5, 2026

This is the visual and interaction contract for LinePaycheck on iOS and, later, Android. It covers product screens, components, content, accessibility, motion, icons, and marketing presentation. It is a design specification, not a claim that every described feature already exists or that audience preference has been validated.

This revision preserves the original porcelain/graphite/Oxide palette, Pay Ledger, Line Gap motif, native-client strategy, and anti-slop principles. It makes them more precise, resolves contrast and state-semantics gaps, and translates current platform guidance into LinePaycheck-specific decisions.

## Start here

A recognizable LinePaycheck screen has **one important answer, aligned money, visible context, and one obvious next action**. Distinctiveness comes from the arrangement of useful information, not custom chrome.

| Decision | Default |
|---|---|
| Public name | **LinePaycheck** |
| Product promise | **Check every paycheck.** |
| Feeling | Capable, calm, exact, personal, not institutional |
| Base | Porcelain in light mode; graphite in dark mode |
| Accent | Oxide for actions; copper only for rare identity details |
| Typography | Native system type; tabular digits for aligned amounts |
| Signature product surfaces | Pay Ledger, Check Summary, Evidence Receipt |
| Content structure | Rows, shared baselines, dividers, meaningful grouping |
| Navigation | Native platform controls; familiar and stable |
| Motion | Brief feedback that explains a real change |
| Trust | Show scope, assumptions, sources, and uncertainty |
| Privacy | No LinePaycheck account or central pay-data backend by default |
| Quality test | Correct, readable, recoverable, and understandable before decorative polish |

### Document boundaries

- `AGENTS.md` owns engineering invariants and technical identity. Keep `com.streamentry.linepay`, `LinePay`, `LinePayDomain`, and existing StoreKit identifiers unchanged for this visual revision.
- `docs/plan/ios-1.0.md` owns release scope. A design example does not add a feature to 1.0.
- `docs/product/onboarding.md` owns onboarding sequence and paywall triggers.
- `docs/product/pricing.md` owns pricing and entitlements. Do not copy prices into visual tokens.
- `docs/architecture/local-first-no-account.md` owns data-flow architecture.
- `docs/release/app-store.md` owns store metadata and screenshot ordering.
- This file owns presentation and interaction quality. Resolve contradictions explicitly; do not let every document declare authority over everything.

---

## 1. The north star: confidence without intimidation

The first reaction we are designing for is:

> “This is for my work. I understand it. It is careful with my pay.”

That is a hypothesis to test with lineworkers, not a promise that a color palette will make them love the app.

The experience should reward three levels of attention:

| Attention | What the user gets |
|---|---|
| A glance | Which period this is, the relevant amount, and whether anything needs review |
| A tap | The hours, rates, or paycheck lines behind that amount |
| A closer look | The exact rule snapshot, source, calculation, and remaining uncertainty |

**Minimalism means fewer competing decisions, not fewer useful facts.** A blank screen with a large number is not enough. The period, gross/net basis, and confirmation state are part of the answer.

Keep the tool approachable. Warm neutral surfaces, readable labels, and forgiving interactions provide humanity without mascots, motivational copy, or “tough worker” theater.

## 2. Design for situations, not stereotypes

These are design scenarios, not completed ethnographic findings:

| Situation | Design response |
|---|---|
| End of a long shift | Large targets; short forms; preserve drafts; do not require unnecessary typing |
| Bright daylight | Strong contrast; opaque reading surfaces; no faint metadata carrying essential meaning |
| Parked truck at night | System dark appearance; no glowing accents or startling transitions |
| Payday review | Put the comparison and its scope before trends or upsells |
| Uncertain agreement detail | Allow “not configured”; explain missing coverage rather than guessing |
| Interruption or weak connectivity | Local work remains usable; missing StoreKit access never blocks Free |
| Older phone or large text | Reflow, not clipping; preserve the same task and information |
| A worker who uses assistive technology | Native semantics and accessible evidence, not a visually impressive dead end |

Do not assume all users are male, union members, technically inexperienced, or identical in their pay arrangements. “Lineman” is an audience keyword; body copy can address “you” and “your work.”

Never encourage use while driving, climbing, or working on energized equipment. Larger touch targets are not a claim of electrical-glove compatibility or safety certification.

## 3. Current design principles worth adopting

The research below informs the direction. The concrete component names, palette, layouts, and quality targets in this document are **our design decisions**, not universal findings.

| Source-backed direction | Apply to LinePaycheck | Do not import |
|---|---|---|
| Apple: purpose, agency, responsibility, familiarity, flexibility, simplicity, craft [R1] | Make the next action legible; preserve context and recovery | Minimalism that hides controls or important facts |
| Apple: Liquid Glass separates controls/navigation from content [R2] | Native system chrome over opaque financial content | Glass ledger cards, layered blur, translucent paycheck text |
| Google: expressive hierarchy uses emphasis and grouping, while familiar patterns remain important [R3] | A confident focal amount, clear primary action, intentional containment | Arbitrary shapes, playful banking visuals, removing labels to look modern |
| Google CHI 2026 study: expressive variants improved task performance in a specific study [R4] | Test stronger hierarchy against the existing screen | Claiming the same improvement for lineworkers or for subscription conversion |
| Apple/W3C: adaptable, perceivable interfaces and measurable contrast [R5–R8] | Treat readability and alternate input as design foundations | A beautiful default-size screenshot as proof of accessibility |
| DTCG: stable token interchange format [R9] | Semantic roles that can later map to both native clients | A token-generation platform before it solves a real coordination problem |

The CHI 2026 study reports 48 participants using 10 applications, with 33% faster fixation on the relevant element and 20% faster task completion in the expressive variants. These are study-specific results, not expected LinePaycheck gains. Google's own design article warns that broken interaction conventions can reduce usability. [R3, R4]

**Our synthesis: expressive where the decision is; quiet everywhere else.**

## 4. The visual grammar

Use an **editorial ledger**, not a card dashboard:

1. A small context line: period, work date, or document.
2. A plain-language question or answer label.
3. One focal amount or action.
4. The minimum supporting facts needed to interpret it.
5. Structured detail, then evidence on demand.

Preserve a shared leading edge for labels and a trailing edge for amounts. Use baseline alignment instead of centering every element vertically. Give totals breathing room; keep their supporting ledger compact.

Default content is flat and opaque. Use a panel only to group a meaningful object, such as a selected plan or a confirmation task. Do not put a card around a card, or a separate floating tile around every metric.

There can be strong personality on the Pay and Check screens. Settings, permission dialogs, and ordinary editing controls should be comfortably conventional. **A settings screen does not need a novel silhouette to pass design review.**

## 5. Signature motif: the Line Gap

Retain the interrupted-line identity:

```text
────────────   ────────────
```

Use it as a small brand mark on welcome, the app icon, or a report cover. It is not a repeating background pattern.

In the interface, distinguish **brand mark** from **data visualization**:

- The static mark is decorative and hidden from assistive technology.
- A numeric comparison shows exact amounts and labels. A decorative gap is not a scale.
- Never widen the gap to exaggerate a small pay difference.
- Do not close or animate the gap to imply legal correctness when only entered values match.
- Use 1–2 pt strokes for an interface mark; redraw an optically heavier version for the app icon.
- No glow, lightning shape, waveform, faux electrical circuit, or decorative motion.

Recognition should come from disciplined repetition across a few important moments.

## 6. Color system: porcelain, graphite, Oxide

### 6.1 Roles before swatches

Use semantic assets/tokens. Features must not invent local RGB values. Brand, action, status, and content colors have separate jobs.

The following full-opacity sRGB references are the baseline. Platform-native controls may use system treatment; inspect the resolved result rather than assuming `.tint` chooses a safe label color.

| Semantic token | Light | Dark | Role |
|---|---|---|---|
| `canvas` | `#F4F1E8` | `#111417` | Main reading field |
| `surface.primary` | `#FBFAF6` | `#1A1F23` | Focused object or raised reading area |
| `surface.secondary` | `#E9E5DB` | `#22282C` | Quiet grouping/background |
| `text.primary` | `#13171A` | `#F4F1E8` | Amounts and primary labels |
| `text.secondary` | `#5C6468` | `#AAB2B6` | Supporting facts, not disabled text |
| `line.subtle` | `#D6D5CC` | `#394147` | Decorative separators only |
| `line.strong` | `#7A8388` | `#75848D` | Meaningful control boundary when needed |
| `action.text` | `#0B6D66` | `#55C9BE` | Links and textual actions on neutral surfaces |
| `action.fill` | `#0E746C` | `#55C9BE` | Primary custom filled action |
| `action.onFill` | `#FFFFFF` | `#111417` | Label/icon on that fill |
| `brand.copper` | `#A94E25` | `#E48A59` | Rare identity detail, not a status |
| `status.review` | `#7D5700` | `#F2C66D` | Needs user confirmation |
| `status.difference` | `#B13C35` | `#FFB4AB` | Confirmed-input comparison differs |
| `status.match` | `#276749` | `#88D5A6` | Compared values match within stated scope |
| `status.information` | `#2C5F90` | `#A7C8F5` | Non-actionable explanatory information |

Existing `brand.primary` can remain an alias for the Oxide identity/fill reference during implementation. It is **not permission to use one teal for every foreground and background**. Keep current Swift type names; this revision does not require a cosmetic API rename.

### 6.2 Two contrast bugs to prevent

**White on the dark-mode Oxide fill is approximately 2.00:1.** Use the graphite `action.onFill` in dark mode, not white.

**The original light Oxide `#0E746C` on `surface.secondary` is approximately 4.47:1.** That is below 4.5:1; rounding does not make it pass. Use the darker `action.text` for links on neutral surfaces.

Copper is for small identity details. Do not use it for necessary small text on the secondary light surface, where the original pair is also below 4.5:1.

### 6.3 Measured reference pairs

Ratios below were calculated from the listed sRGB values using WCAG relative luminance, at full opacity. They verify color pairs, not rendered screens, outdoor readability, or platform accessibility conformance. [R6, R7]

| Foreground / background | Light | Dark |
|---|---:|---:|
| Primary text / canvas | 15.96:1 | 16.36:1 |
| Secondary text / secondary surface | 4.80:1 | 6.93:1 |
| Action text / secondary surface | 4.92:1 | 7.45:1 |
| Action label / primary action fill | 5.62:1 | 9.23:1 |
| Review text / secondary surface | 5.16:1 | 9.29:1 |
| Difference text / secondary surface | 4.68:1 | 8.79:1 |
| Match text / secondary surface | 5.35:1 | 8.61:1 |
| Strong boundary / secondary surface | 3.07:1 | 3.86:1 |

Use at least **4.5:1 for all essential text**, including action labels. This is a deliberately simple LinePaycheck target, stricter than using the large-text exception everywhere. Target **7:1 or better for focal amounts**. Meaningful non-text indicators need at least **3:1** against adjacent colors when they are required to identify the control/state. Decorative dividers are not control boundaries. [R6, R7]

Do not place critical text over glass, photos, gradients, or arbitrary opacity layers and reuse these ratios as proof.

### 6.4 Increased contrast and state behavior

In Increase Contrast, keep the same hierarchy while strengthening it:

- Use primary text for supporting information that is important to a decision.
- Promote necessary weak separators/boundaries to `line.strong` or stronger.
- Suggested high-contrast action references: light text `#063E3A`, light fill `#064C47` with white label; dark text/fill `#8AE1D5` with graphite label.
- Keep labels and symbols in every state; more saturation is not an accessibility strategy.
- Let native components respond to system accessibility settings; inspect custom content independently.

The app follows system light/dark appearance by default. No custom theme selector is required for 1.0. A normal product screen may contain no copper at all.

## 7. Typography: authoritative numbers, ordinary words

Use the native system font. On iOS, use SF through system text styles; on Android, use the platform type system. Do not ship an ornamental display font in 1.0.

| Role | iOS reference | Behavior |
|---|---|---|
| Focal amount | `.largeTitle.bold()` | One per screen region; monospaced digits |
| Screen title | Native navigation title | Avoid repeating it as another giant heading |
| Section label | `.headline` | Sentence case, clear hierarchy |
| Ledger label/value | `.body` or `.headline` | Readable without opening the row |
| Formula and supporting facts | `.subheadline` | Still decision-grade contrast |
| Source metadata | `.footnote` | Accessible disclosure to full context |

Use regular, medium, semibold, and bold. No light-weight financial text. No decorative all-caps eyebrows on every section. Abbreviations such as OT can remain uppercase because they mean something.

Use tabular digits for aligned money, rates, multipliers, and durations, not a monospaced font for every sentence. Preserve currency, sign, cents, and units. Do not show `$3K` where the user needs `$3,016.00`.

Large text changes the layout, not the amount of truth shown. Let an amount move beneath its label; let rows become taller. Do not use shrinking text or a restrictive Dynamic Type range to force the original composition to fit. [R5]

**Optical craft:** align labels and amounts on their first baseline; keep decimal precision consistent within a comparison; allow the long negative amount to fit before polishing the short positive example.

## 8. Spacing, shape, and density

Use a small 4 pt-based scale:

```text
4   inline relation
8   compact relation
12  compact row padding / related controls
16  standard spacing
20  typical compact-phone horizontal margin
24  section inset / substantial grouping
32  separation between major sections
48  rare hero breathing room
```

Choose one screen margin for a flow. Do not alternate 16/20/24 between adjacent screens accidentally. These are iOS points; map conceptually to Android dp, not physical pixels.

Custom content panels use roughly **10–12 pt** radius; small badges use **6–8 pt**. This is not a cap on native sheet, button, tab-bar, or menu geometry. Let the OS own its shapes, including capsules where appropriate.

Default shadow: none. Distinguish surfaces with placement, tone, or a border. Do not rely on the subtle difference between two pale backgrounds to identify an interactive target.

Give a total more whitespace than a formula, but do not make the user scroll through a poster to reach today's work.

## 9. Native navigation, distinct content

Preserve the established product structure unless the product plan deliberately changes it:

| Destination | Job |
|---|---|
| Today | Add, review, or correct work |
| Pay | Understand the selected period and check its paycheck |
| History | Return to earlier periods and their recorded results |
| Settings | Pay profiles, privacy/data controls, and subscription management |

Use labeled native tabs and ordinary push navigation. Preserve selected period, scroll position, and draft context when returning from evidence. Never make a tab disappear because Pro expired.

Focused creation/editing can use a native sheet. Provide clear cancel/save behavior and protect unsaved work when dismissal would lose it. There should be one obvious commit action, not competing floating and toolbar save buttons.

No custom bottom dock, hamburger navigation, bespoke back gesture, or long-press-only route to an essential action. Navigation stays familiar; the payoff is in the content.

## 10. Controls that invite confident action

LinePaycheck targets for custom/frequent controls:

- Primary action: **52–56 pt minimum height**, allowed to grow with text.
- Frequent tappable row: **at least 48 pt** high.
- iOS icon-only hit area: **at least 44 × 44 pt**; use 48 where practical.
- Android touch target: **at least 48 × 48 dp**. [R10]

These are hit areas, not icon drawing sizes. Invisible hit areas must not overlap neighboring actions. Important affordances need visible labels or unmistakable native behavior.

A primary button label names the action: `Add work`, `Confirm fields`, `Check paycheck`. A busy label names the operation: `Saving work…`, not `Working…` everywhere.

Every control has deliberate normal, pressed, selected, focused, disabled, busy, and error behavior where applicable. Disabled controls have an explanation when the reason is not obvious. Do not disable the entire screen because one product price is loading.

For numeric input, provide a persistent label, visible units, appropriate keyboard, and an accessible way to finish editing. Placeholder text is not a saved value. Parse according to the declared input format; never silently reinterpret `7.30` hours as 7 hours 30 minutes.

## 11. A small vocabulary of domain components

These are component contracts, not a demand to create a framework or a separate package. Extract only when the behavior exists and reuse benefits correctness.

| Component | Required information | Required behavior |
|---|---|---|
| `PeriodHeader` | Exact date range, applicable profile | Changes period explicitly; never silently changes calculation scope |
| `MoneyAmount` | Amount, currency, semantic label | Exact display; large-text reflow; useful spoken value |
| `PayLedgerRow` | Pay category, quantity/unit, rate, amount | Explain formula; retain amount when expanded |
| `CheckSummary` | Comparable expected/actual values, basis, state | Show difference or explain why comparison is unavailable |
| `EvidenceReceipt` | Work, rule version, math, paycheck fact, source | Trace a number without losing the original comparison |
| `ConfirmationRow` | Extracted/entered value, source, review status | Correct and confirm; not “verified” merely because OCR returned text |
| `StatusLabel` | State, text, symbol | Understandable without hue; not a generic trust badge |
| `PlanOption` | Store price, billing duration, selected state | Selection and price understandable with VoiceOver |

Do not create `UniversalCard`, `FancyTile`, a bespoke navigation framework, or an “AI insight” abstraction. Keep design tokens small and domain components meaningful.

## 12. Signature screen A: the Pay Ledger

This should be the app's most recognizable everyday surface.

```text
Pay                                      Aug 24–30

Expected gross
$3,016.00
46 hours recorded · My current pay · Rules v3
Not compared with a paycheck yet

Regular                               $2,320.00
40 h × $58.00

Double time                             $696.00
6 h × $58.00 × 2
View applied rules                              ›
────────────────────────────────────────────────
Expected gross                        $3,016.00

[ Check paycheck ]
```

**Synthetic design example only.** It is not a worker's paycheck or a published agreement. Its arithmetic is `40 × 58 + 6 × 58 × 2 = 3,016`. The implementation must generate example results through a tested fixture, not paste totals into a production view.

### Ledger interaction

- Keep the date range, gross basis, and profile close to the amount.
- Rows share an amount column; formulas sit beneath their labels.
- Expanding a row reveals applied conditions and source, not a duplicate card.
- Distinguish worked hours from paid minimum hours. A 1.5-hour callout with a 4-hour minimum is not four hours of actual work.
- Separate wages, reimbursements, deductions, and net pay according to the available facts. Do not silently add per diem to gross wages or compare gross against a bank deposit.
- Where classification is uncertain, ask for confirmation rather than tax treatment inference.
- Do not label all stored work “this pay period” without actually filtering by that period.
- An incomplete supported rule set produces a scoped estimate, not a complete contractual audit.

If checking is not implemented in a build, do not show a working-looking primary action that does nothing. The release plan controls availability.

## 13. Signature screen B: the Check Summary

The emotional peak is understanding, not excitement.

```text
Paycheck check                          Aug 24–30
Gross pay · USD

Expected                               $3,016.00
On your paystub                        $2,900.00
────────────────────────────────────────────────
Possible gross difference
$116.00

Double-time hours differ                       ›
Recorded: 6 h · Paystub: 5 h
1 h × $58.00 × 2 = $116.00

Based on your confirmed entries and rules v3.
Review the details before contacting payroll.

[ Review difference ]
```

This uses the same synthetic example as the ledger. It does not assert money is owed, recovered, or legally missing. A production reason is shown only if the comparison can support that specific explanation.

### State language

| State | Presentation | Next action |
|---|---|---|
| Missing comparable facts | `Not ready to compare` and the exact missing input | `Add paystub gross` or another specific action |
| Material OCR/rule uncertainty | `Needs confirmation` | `Review fields` |
| Compared values match | `Matches entered data` plus scope/tolerance | `View calculation` |
| Comparable values differ | `Possible gross difference` plus amount | `Review difference` |
| Actual amount exceeds expectation | `Paystub is higher than expected` | `Review difference` |
| Work/rules changed since check | `Check needs updating` | `Review changes` |
| Operation failed | No new success state or replacement zero | Retry while retaining inputs |

A match means only that the supported comparison matches, not that all pay obligations were checked. “Recorded” and “saved” are data states, not correctness guarantees.

Red-family emphasis is permitted for a difference after material inputs are confirmed. It is not a full-screen alarm. Unconfirmed input uses review styling. Higher-than-expected pay is not automatically green or “extra money earned.”

## 14. Signature screen C: the Evidence Receipt

One tap from a difference should answer **why**. A further source interaction can reveal the original document region.

```text
Why this differs

Work recorded
Aug 27 · 6 h classified as double time

Rule used
My current pay · Version 3 · Entered by you
$58.00 base rate · 2× multiplier

Expected
6 h × $58.00 × 2 = $696.00

Paystub entry
5 h × $58.00 × 2 = $580.00
Confirmed by you · View original                 ›

Possible difference
$116.00
```

The exact grouping can vary with the supported engine; never invent row-level reconciliation from a gross-total difference alone.

Keep three questions separate:

1. **Input status:** Was this value read, entered, or confirmed?
2. **Rule provenance:** Was this rule entered by the user or sourced from a specific agreement version?
3. **Comparison result:** Did these comparable values match?

A user-confirmed OCR value does not validate the rule's legal applicability. An agreement source does not prove OCR was correct. No composite “98% accurate” badge, trust score, or green shield should collapse these distinctions.

## 15. Paystub capture and correction

Make correction easier than rescanning:

- Offer only the capture/import methods implemented in the release.
- Request camera permission when the user chooses scanning, not during welcome.
- Keep document text visually separate from editable fields.
- Show a concise count such as `Review 2 fields`, when that count is real.
- Preserve the source page/region so a value can be checked without memory.
- Use `Enter manually` when capture is denied, unsupported, or unsuccessful.
- Show originals without color grading, decorative rotation, or filters that damage legibility.
- Differentiate a machine-read value from one the worker confirmed.
- Do not celebrate successful OCR as successful paycheck auditing.

No fake scanning beam, AI sparkle, staged analysis delay, or spinning “financial intelligence” sequence. When processing is genuinely in progress, show honest progress and cancellation where supported.

## 16. Rule setup: progressive disclosure without hidden assumptions

Present a short base-pay section, then reveal optional rule details when enabled. Keep the selected value near its consequence.

The default is not “common lineman rules.” It is **only the rules the user explicitly supplies or confirms**.

- Profile label, rate, currency, and work timezone remain visible.
- Optional rules start off; placeholder examples are not enabled assumptions.
- A disabled premium is described as `Not configured`, not `Does not apply`.
- Explain how supported premiums interact when that affects the result.
- Make minimum paid hours visibly different from actual worked duration.
- Do not imply a rule is verified because the user selected a union/local name.
- Preserve prior rule versions and show which version a historical check used.
- Editing present-day rules must not visually overwrite an old result without a deliberate recalculation/revision flow.

A setup preview can demonstrate entered rules with clearly labeled sample work. It must not insert fictional work into the real ledger. Do not add a sample mode until it is properly isolated and tested.

## 17. Onboarding and soft paywall

Follow `docs/product/onboarding.md`: value/trust, confirmed pay basics, one real work interval and its expected-pay result, then an optional seven-day annual trial offer. Keep the full renewal price and Continue free clear. Do not create another tour to showcase the design system.

The welcome screen uses one clear headline, a short outcome explanation, one primary action, and the Line Gap mark. Avoid both a blank dashboard and a long marketing poster.

On the offer:

- Make annual and monthly billing unambiguous; use StoreKit's localized price data.
- Show the billed total and duration prominently. A monthly equivalent must never be more prominent than the annual charge.
- Keep `Continue free` available immediately and visually legible. In compact layouts, provide a persistent escape route instead of burying it below a long benefits list.
- Support restore and accessible terms/privacy links when commerce is active.
- Show renewal/cancellation information in readable text.
- Use real configured rules for personalization, not invented savings or loss estimates.
- Never obscure the first completed audit's result behind an upsell.
- Do not sell planned audit functionality in a build that does not have it.

A selected annual plan is not permission to disguise a purchase as a free continuation. Commerce and free-use actions must be distinguishable by their labels and surrounding terms.

Privacy is not an upgrade. Do not imply Free users have less private processing. Prices, entitlements, and the first-audit-free policy remain owned by the pricing document.

## 18. Empty, loading, error, and recovery states

These states deserve the same composition work as the populated ledger.

| Situation | Good presentation | Avoid |
|---|---|---|
| No work | `No work logged for Aug 24–30` + `Add work` | A misleading `$0.00 earned` or a floating illustration |
| No paystub | Explain what can be estimated now and what checking needs | Making the ledger feel broken |
| Calculation incomplete | Show remaining required facts and coverage limits | A complete-looking total with a hidden warning |
| Save fails | `Work wasn't saved. Your entry is still here.` + retry | Dismissing the form or showing a success haptic |
| Store unavailable | Free remains usable; explain Pro is temporarily unavailable | A blocking spinner over the entire app |
| Data changed | Mark the prior result stale and retain its context | Presenting yesterday's result as current |
| User cancelled | Return quietly with inputs intact | Red error language for a normal choice |
| Destructive action | Name what will be removed; offer undo when feasible | Generic `Are you sure?` without consequences |

No skeleton when local content is already available. No artificial delay to imply sophisticated work. Distinguish zero, missing, not evaluated, and failed; they are not four spellings of the same state.

Saving is a real boundary. Confirmation appears after the write succeeds. A delete/undo flow must restore the record and its relevant associations, not merely the row animation.

## 19. Motion and haptics: make cause visible

Use motion only to explain selection, continuity, completion, or disclosure.

| Interaction | Reference treatment |
|---|---|
| Button/selection feedback | Native pressed/selected state |
| Small custom disclosure | About 120–180 ms, restrained ease |
| Native sheet/navigation | System transition |
| Result refresh | Stable layout; brief change indication if helpful |
| Successful save | Quiet visible confirmation; optional single haptic |
| Possible discrepancy | State change, not celebration or alarm |

These durations are design starting points, not research-proven optima. Do not override native motion just to match a number.

Respect Reduce Motion with a fade or immediate state update instead of large translation, scaling, parallax, or animated blur. Information conveyed by motion remains available in text/state. [R8]

No money count-up from zero, bouncing CTA, repeated spring effects, ambient animation, auto-scrolling ledger, haptic on every tap, or suspense before showing a result. A pay amount should never look as though it is gambling toward an answer.

The performance goal is prompt feedback, not perpetual activity. Avoid unnecessary timers, continuous visual effects, and forced loading sequences in a local utility.

## 20. Words, amounts, and time

Write like a careful coworker: plain, specific, respectful. Be confident about what is known and explicit about what is not.

| Use | Not |
|---|---|
| `Expected gross` | `Guaranteed paycheck` |
| `Possible difference` | `Your employer owes you` |
| `Matches entered data` | `Certified correct` |
| `Needs confirmation` | `AI verified` |
| `Entered by you` | A verification badge without provenance |
| `View applied rule` | `Unlock insights` |
| `Not configured` | Silently treating an unknown rule as inapplicable |
| `Saved on this iPhone` after a successful write | `Safe forever` |

Use the public name **LinePaycheck**. Do not expose internal `LinePayDomain`, database IDs, or StoreKit identifiers to workers.

**Amounts:** show currency when ambiguity is possible; preserve signs and exact cents; use locale-aware display without converting Decimal calculations through binary floating point. Label the comparison basis. Never subtract a net deposit from expected gross.

**Time:** display the work/payroll timezone when it matters, not merely the phone's present timezone. Show both dates for overnight work. Distinguish `7 h 30 min` from `7.50 h`; do not use `7.30 h` for seven and a half hours. When a DST transition makes clock time and elapsed duration differ, explain the relevant basis.

**Dates:** use clear localized dates such as `Aug 24–30`, with year visible when context requires it. Avoid ambiguous numeric dates in evidence intended for another person.

## 21. Privacy made concrete

Primary trust copy:

> **No account. No paycheck uploads to our servers.**

Supporting copy, when true for the build:

> Your work and paycheck details are processed on your device.

Do not promise “nothing ever leaves your phone” without considering user-initiated sharing, device backups, platform services, and the actual implementation. No LinePaycheck backend is not the same as no network activity: subscription purchases use Apple services.

Explain backup behavior accurately. `Restore Purchases` restores purchase access; it is not a promise to restore local work history. If the product does not yet provide data recovery, do not show backup-success language or imply support can retrieve a lost paycheck.

For sharing/export, show what will be included and allow review before invoking the system share flow. Never include a full original paystub when the user expects a summary. Redact identifiers in demo screenshots and support examples.

When widgets or notifications are eventually supported, do not expose wages on a lock screen by default. Such surfaces are optional future scope, not requirements added by this document.

## 22. Icons and app icon

Use SF Symbols on iOS and platform-appropriate icons on Android. Use consistent optical weight. Prefer monochrome/hierarchical rendering; keep text labels where the action is not universally obvious.

Custom art is reserved for a concept the system cannot express, chiefly the Line Gap. Do not make a robot, lightning bolt, hard hat, dollar sign, bank, or shield-with-check the identity.

### App icon direction

**Graphite field, a strong porcelain Line Gap, one restrained Oxide/copper detail.**

- Two or three deliberate geometric elements, no text.
- Enough stroke weight and negative space to survive small sizes.
- A stable silhouette in monochrome/tinted variants.
- No faux metal, rivets, tiny pole illustration, drop-shadow stack, or generic fintech monogram.
- Use Apple's current icon workflow and preview tools; let the system supply supported appearance effects rather than painting those effects into every asset. [R11]

Test Home Screen, Spotlight, and the applicable dark/tinted/clear presentations. A large beautiful source file is not proof that the small icon works.

## 23. Data visualization: never distort the paycheck

A chart must answer a question better than aligned text. For 1.0, a ledger and a comparison are usually sufficient.

A shift timeline can help explain work across dates. A labeled hour-composition bar can help show allocation. A trend can help compare genuinely comparable periods when the feature exists. None is required just to fill a screen.

Rules:

- Expected and actual bars use the same basis and scale.
- Do not truncate a money-bar axis to magnify a small discrepancy.
- Do not mix gross wages and reimbursements into an unlabeled total.
- Do not draw progress toward an hours target the user never set.
- Keep exact values and important findings visible without dragging or hovering.
- Provide an equivalent textual/table view and useful spoken context. [R12]
- Labels, symbols, patterns, or direct annotation supplement color.

No donut, gauge, financial-health score, three-dimensional chart, gratuitous sparkline, or celebratory green “found money” visualization.

## 24. Accessibility and adaptive layout

Accessibility is not an optional visual variant. Apply the contrast targets in section 6 and test real tasks. [R5–R8, R13]

### Required layout adaptations

| Constraint | Response |
|---|---|
| Narrow supported phone | Stack label/value when needed; preserve exact amounts |
| Largest accessibility text | Grow rows/buttons; stack comparisons and plan choices; allow scrolling |
| Landscape or short viewport | Keep the active field and primary/escape actions reachable |
| Long profile name | Wrap or disclose the full name; do not truncate the paycheck value to make room |
| Large negative amount | Preserve sign, currency, and cents |
| Keyboard visible | Keep the active field visible and provide a way to finish/dismiss |
| Dark + Increase Contrast | Use resolved semantic pairs, not dimmed copies of light screens |
| Reduce Transparency | Opaque, comprehensible content remains intact |

Do not impose a fixed height on financial rows, consent text, or paywall terms. Do not horizontally scroll ordinary forms to preserve a mockup's columns.

### Assistive interaction

- Group each row's label, quantity, amount, and state meaningfully.
- Speak the subject and scope, not color or visual position. Example: `Double time, 6 hours at 116 US dollars per hour, expected 696 US dollars.`
- Source evidence needs an accessible text equivalent when a crop is visual only.
- A `View source` action must identify the source sufficiently in context.
- Expose selected/expanded/disabled state through appropriate semantics.
- Hide decorative marks from VoiceOver; keep actual evidence reachable.
- Announce important completed actions or validation errors without reading every keystroke.
- Do not unexpectedly move accessibility focus when a background result refreshes.
- Support Voice Control/Switch Control through labeled native controls rather than custom gestures alone.

Use stable accessibility identifiers for automation, separate from localizable spoken labels. Test with VoiceOver, not only an accessibility tree inspector. Claim App Store accessibility support only after common tasks satisfy the applicable evaluation criteria. [R13, R14]

## 25. Token implementation without a framework tax

Start with the existing iOS token layer and named assets where useful. Extend it deliberately; do not add a third-party design-system dependency.

Keep three levels conceptually distinct:

```text
Reference values       Semantic roles          Domain use
porcelain / Oxide  →   canvas / action.text →  Pay Ledger / Check Summary
```

Features reference semantic roles. A color's meaning does not change because a developer likes another shade in a screenshot.

When Android implementation begins, a small shared token specification can prevent drift. DTCG 2025.10 is a stable interchange format to consider then; it is a Community Group specification, not a W3C Recommendation. A generator is optional, not a prerequisite. [R9]

Maintain platform-native typography, motion, focus, and control behavior. Do not serialize SwiftUI-specific types into shared design data.

For iOS implementation:

- Use semantic text styles, `.monospacedDigit()`, and layout that can reflow.
- Render a supplied calculation result; views do not reproduce payroll math.
- Use system navigation, selection, sheets, menus, keyboards, and feedback first.
- Scope appearance changes; avoid global hacks that restyle unrelated system controls.
- Newer OS effects need availability-safe behavior on the iOS 18 baseline; no custom glass backport is required.
- Test the actual foreground selected by a filled system button in each appearance.

## 26. Android: the same instrument, not the same pixels

Preserve the brand, semantic states, ledger hierarchy, evidence trail, and numeric meaning. Use Jetpack Compose and Android conventions for navigation, back behavior, pickers, sheets, focus, and accessibility.

Material 3 Expressive can inform emphasis and feedback, but should not replace the restrained product character with playful shapes or excessive bounce. Keep important labels. Do not copy Liquid Glass into Android. [R3]

Wallpaper-derived colors, if ever supported, must not remove status distinctions or compromise the specified contrast. Default to a tested brand scheme until real evidence warrants additional theming.

Cross-platform consistency means a worker understands the same paycheck on either phone. It does not require identical chrome or shared UI runtime code.

## 27. Store screenshots and public presentation

`docs/release/app-store.md` owns the sequence. This file owns how each frame looks:

- Show the actual shipping UI with a large, readable crop.
- One short outcome headline per frame.
- Porcelain/graphite backgrounds, a restrained accent, consistent typography.
- Use the same synthetic period across related screenshots so numbers reconcile.
- Label illustrative/sample data appropriately; never frame a synthetic discrepancy as a customer recovery.
- Do not display future audit, OCR, backup, or subscription capabilities as available before they ship.
- No floating 3D-phone collage, generated worker portrait, fake testimonial, fake ranking badge, or gradient theme per feature.

The first impression should come from a clear paycheck question and a convincing product answer, not from an elaborate poster hiding a tiny app screen.

## 28. The anti-slop rule, refined

Reject these defaults:

- Repeated icon + all-caps eyebrow + giant number in a 2×2 tile grid.
- Purple/blue gradients, neon edges, glow, glass content cards, or faux industrial texture.
- Every row enclosed in another rounded card.
- Unexplained positive/negative colors, generic scores, or AI-confidence percentages.
- Decorative worker photos, electrical equipment silhouettes, emojis as navigation, or sparkles.
- Chat bubbles around structured payroll information.
- Generic greetings, inspirational quotes, or verbose startup language.
- Missing labels disguised as minimalism.
- Artificial loading, confetti, urgency timers, guilt-based decline copy, or hidden Free access.

But **do not reject useful native conventions merely because other apps also use them**. A normal toggle is not slop. A native sheet is not slop. Restraint is not the same as erasing all warmth or color.

The useful smell test is:

> Does this screen reveal something about this worker's pay, or could its content be swapped for a crypto balance without changing the layout?

Apply that test to signature product screens, not as an excuse to reinvent Settings.

## 29. A design is done when it survives real use

### Blocking checks for every important screen

- The task, period, currency, and pay basis are unambiguous where relevant.
- The amount is traceable and agrees with its test fixture.
- Missing or unconfirmed facts cannot look like a completed audit.
- Light, dark, and increased-contrast foreground/background pairs pass their targets.
- Largest supported text preserves content and reachable actions.
- VoiceOver can complete the task and reach its evidence.
- Save failure, cancellation, interruption, and empty data are recoverable.
- The current build actually supports every prominent promised action.
- Existing work and the first free audit result are not hidden behind coercive presentation.
- There is no new account requirement, pay-data upload, or unrelated design dependency.

A nice screenshot cannot compensate for a failure in these checks.

### Visual proof package

For a substantial UI change, capture the same synthetic scenario in light, dark, and an accessibility text size. Include at least one adverse state such as unconfirmed OCR or a failed save. Compare actual simulator/device captures, not just source code or a generated concept image.

Use existing repository verification and the Maestro/simulator workflow where applicable. Compilation does not prove design quality; a docs-only edit does not require a native build.

### Cheap audience test

Before broad visual expansion, test the ledger and paycheck check with 5–8 representative lineworkers, including an apprentice or traveler and someone who reviews complex checks. Include varied ages and accessibility needs where feasible. This is formative testing, not a statistically powered conversion experiment.

Ask them to:

1. Identify the period, expected gross, and whether a check has happened.
2. Explain the synthetic $116 difference without coaching.
3. Find and correct an uncertain paycheck field.
4. Continue without subscribing.
5. Say what they believe happens to their pay data.

Initial internal targets: at least 4 of the first 5 participants correctly identify the main result within about 5 seconds; all can find the Free path; no participant mistakes the example for a legal finding or believes purchase restoration backs up wage records. These are design targets, not achieved results or industry benchmarks. Treat any serious misunderstanding as a design defect to fix.

Track task success, misunderstanding, input errors, and recovery before asking “Does it look premium?” Do not introduce tracking SDKs solely for this test.

## 30. Implementation order and scope control

Apply this revision in small, reviewable slices:

1. **Foundation:** separate action foreground/fill/on-fill tokens; check contrast and large text; remove decorative uppercase; preserve native control behavior.
2. **Everyday value:** refine the Pay Ledger and scoped period header with a shared, tested synthetic scenario.
3. **Trust at payday:** implement Check Summary and Evidence Receipt only alongside supported reconciliation and source facts.
4. **Failure quality:** validate correction, save failure, stale results, and first-run/Free escape paths.
5. **Presentation:** prepare icon variants and real App Store captures after product behavior and public naming agree.

Do not launch an app-wide rewrite, add a design framework, build unused components, alter commercial policy, or ship a new backend in the name of polish.

The finish line is not “this looks expensive.” It is:

> **I can read it, use it, check its work, and trust it with mine.**

---

## Research references

Primary sources checked for this revision. Platform guidance is evidence; the specific LinePaycheck composition and targets above remain design judgments to validate.

- **[R1] Apple HIG, Design principles.** Purpose, agency, responsibility, familiarity, flexibility, simplicity, and craft. https://developer.apple.com/design/human-interface-guidelines/design-principles
- **[R2] Apple HIG, Materials.** Functional-layer use of Liquid Glass and restraint in custom effects. https://developer.apple.com/design/human-interface-guidelines/materials
- **[R3] Google Design, Better, Easier, Emotional UX.** Expressive hierarchy research and cautions about breaking familiar patterns. https://design.google/library/expressive-material-design-google-research
- **[R4] Bentley et al., Usability Hasn't Peaked: Exploring How Expressive Design Overcomes the Usability Plateau, CHI 2026.** Study-specific results, not a LinePaycheck experiment. https://research.google/pubs/usability-hasnt-peaked-exploring-how-expressive-design-overcomes-the-usability-plateau/
- **[R5] Apple HIG, Accessibility.** Adaptable presentation, larger text, contrast, and interaction accessibility. https://developer.apple.com/design/human-interface-guidelines/accessibility/
- **[R6] W3C WAI, Understanding WCAG 2.2 SC 1.4.3, Contrast (Minimum).** Numeric text-contrast method and thresholds. https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- **[R7] W3C WAI, Understanding WCAG 2.2 SC 1.4.11, Non-text Contrast.** Required control/graphic distinctions versus decorative boundaries. https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- **[R8] Apple, Reduced Motion evaluation criteria.** Meaning-preserving alternatives to potentially problematic motion. https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria
- **[R9] Design Tokens Community Group, Format Module 2025.10.** Stable Community Group interchange specification. https://www.designtokens.org/TR/2025.10/format/
- **[R10] Android Developers, Compose accessibility API defaults.** Native interaction semantics and minimum touch targets. https://developer.android.com/develop/ui/compose/accessibility/api-defaults
- **[R11] Apple, Icon Composer.** Platform icon creation and appearance preview workflow. https://developer.apple.com/icon-composer/
- **[R12] Apple HIG, Charts.** Clear data context and accessible presentation. https://developer.apple.com/design/human-interface-guidelines/charts
- **[R13] Apple HIG, VoiceOver.** Labels, grouping, meaningful images, and navigation. https://developer.apple.com/design/human-interface-guidelines/voiceover
- **[R14] Apple, VoiceOver evaluation criteria.** Common-task accessibility and accurate support claims. https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria

**Verification for this document:** reference color ratios and synthetic example arithmetic were calculated; current repository design/product constraints were reviewed. This document update alone does not implement UI, verify screenshot rendering, or establish customer preference.
