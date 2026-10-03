# Whole-app review: usability, copy, correctness and value — October 3, 2026

[Dated research](README.md) · [Design system](../../DESIGN.md) · [Business rules](../product/business-rules.md)

**Kind:** observed review plus the implementation changes made in response (PR #95, released to TestFlight as 1.0.3). This is not user research, legal review or a conversion result. It records what one reviewer saw while using the app as a new worker on the iOS 26.5 Simulator with synthetic data.

## Method

Each screen was used as a first-time lineworker would use it. The reviewer started from a fresh install with no data. Synthetic fixtures (`--ui-testing`, `LINEPAY_UI_SCENARIO`) then supplied the later states: logged work, matched, short and overpaid paychecks, and a closed period awaiting its paycheck. Questions asked of every screen:

1. **Easy:** Is the next action obvious and reachable with one thumb? How many taps does the job take?
2. **Correct:** Can the worker end up with a wrong, blocked or misleading state?
3. **Clear:** Does the copy say what a tired worker needs, in their words, without legal fog?
4. **Worth paying for:** Does the screen show the value Pro sells, which is a trustworthy answer to "was I paid right?"

Reviewed: welcome, the four setup steps, first-shift intro, first result, Today (empty, populated, awaiting a paycheck), Add work, Repeat shift, Pay, paycheck source chooser, paystub review, paycheck result (match, shortfall), line comparison, "Why this amount?", rules used, History (list and closed period), Settings, pay period, privacy and data, export, backup, About, report sharing, weekly overtime review, the onboarding and contextual paywalls, and dark mode on Today, Pay and the result.

## Findings and responses

Severity: **Blocker** stops or misleads a worker on a main path; **Major** costs real effort or trust; **Minor** is polish.

### Correctness and dead ends

| # | Finding | Severity | Response |
|---|---|---|---|
| 1 | First setup defaulted the pay period to start **today**. A worker who logs "one recent interval", as the next screen asks, got "outside the current pay period". | Blocker | Defaults to the start of this week. Add work limits dates to the period and shows it. The error explains the fix. Regression test added. |
| 2 | Add work's only exit was **Keep draft**. Opening it and leaving stranded a draft that blocked repeat, edit and delete of every other shift. | Blocker | Plain **Cancel**: an untouched sheet leaves nothing; an edited one asks *Keep as draft / Discard changes*. A UI journey proves it. |
| 3 | **Repeat last shift** proposed the same day as the shift it repeats, so it opened in conflict with Save disabled. Leaving also stranded a draft. | Blocker | Proposes the first free day in the period. The "resumed draft" flag is fixed when the sheet opens, so autosave cannot flip it. Unit and UI tests added. |
| 4 | **Add work** after logging today's shift opened already overlapping it, with Save disabled. | Major | Suggests the next free day. Overlap copy names the shift ("Sat, Oct 3 · 7:00 AM – 5:00 PM"). Test added. |
| 5 | A shortfall showed "Possible shortfall" on Pay but not **how much**. | Major | Pay shows expected, paystub and "Paystub is lower by $50.00" while the result is current. The result screen leads with verdict and amount. |
| 6 | Validation errors rendered at the end of long forms, under the keyboard. | Major | Errors sit beside the pinned action button. |
| 7 | Predictive text in number fields: one tap turned `50` into `50 days`. | Major | Autocorrect and suggestions are off for amounts and rates. |
| 8 | Expanding "Weekly overtime" silently switched the rule on. | Major | An ordinary toggle with an explanation. |
| 9 | An empty period showed a large **$0.00**, which DESIGN.md prohibits ("Avoid: a misleading $0.00 earned"). | Minor | "No work logged yet" on Today and Pay. |
| 10 | The Pro prompt on the paycheck result rendered under iOS 26's floating tab bar. | Minor | Moved to a safe-area inset above it. |
| 11 | Start pay period suggested today rather than continuing from the last closed period. | Minor | Continues from the last period and never overlaps after a timezone change. Test added. |

### Effort

| # | Finding | Response |
|---|---|---|
| 12 | Typing in a paycheck took about **12 taps across sub-screens**: one pushed screen per date and the gross, plus a toggle and a picker. | One screen: inline dates with a single "these dates match" check, an inline gross amount, the work-complete check, and a one-tap gross basis. Pinned **Compare with expected pay**. OCR values still need an explicit confirm. |
| 13 | Setup's primary button lived in the navigation bar. Step 4 opened scrolled to the bottom. The rate field needed a tap. | Pinned **Continue**; each step starts at its top; the rate field takes focus. |
| 14 | Today put "Repeat last shift" above "Add work". Several actions rendered as black text that did not look tappable. | Add work first. Repeat shows which shift it copies. Textual actions use the action color and a 48 pt row. |
| 15 | After closing a period, the paycheck the worker came to add sat at the bottom, behind the tab bar. | "Add the paycheck for Oct 3–9, 2026" sits with the main actions. |

### Clarity

| # | Finding | Response |
|---|---|---|
| 16 | Raw identifiers: `America/Chicago`, `rules v1`, `10/03/2026`. | "Central Time (Chicago)", "rules version 1", "Sat, Oct 3, 2026". Dates in shared reports cannot be misread as day/month. |
| 17 | Ledger rows said "Premium work" with no formula. | "Overtime · 1.5×   $150.00" over "2 h × $50.00 × 1.5". Callout top-ups say they are paid-equivalent hours, not time worked. |
| 18 | Mixed "audit" and "check" for the same action. | Buttons and titles say "check". Legal and long-form text was left as reviewed. |
| 19 | Each setup rule had only a name. | Each rule has a one-line explanation. The footer says "not configured, not ruled out". |
| 20 | "Save as not comparable" wore the primary fill, inviting a reflexive tap that produces no answer. | Secondary style until both comparison questions are answered. |

### Value: is it worth $79.99/year?

- **The core promise now lands in the first minute.** Rate → this week's period → one shift → an exact, explained expected amount. Add work previews "Adds to expected wages $400.00" before saving, using the same calculation a saved shift receives. The worker sees the value before the paywall.
- **The paycheck answer is now the hero.** "Possible shortfall · $50.00", then expected versus paid, then the line-by-line trace and a shareable report. This is the thing a worker would pay for, and it no longer hides behind taps.
- **The paywall says what Pro adds.** The first check is free; Pro checks every payday after. The duplicate "Check every paycheck" benefit was replaced.
- **Remaining value gap (not fixed here):** weekly overtime over 40 hours is **not** part of the main estimate. This is product-safety gated by #42 (GAP-01). Pay now says so plainly, and points to the weekly review over 40 hours. For many hourly workers weekly overtime is the most common premium. Admitting it through the source/applicability review in #42 is the highest-value next step.

## Verification

At the final head of PR #95:

- **Domain:** 105 `LinePayDomain` tests pass.
- **App unit tests:** 225 pass, including the new regressions above.
- **UI journeys:** the full XCUITest suite was run on the iOS 26.5 Simulator; see the PR for the final tally. One journey skips by design because this simulator has no "Save to Files".
- **Not run:**
  - `StoreKitLifecycleTests`: `SKTestSession` fails with `SKInternalErrorDomain Code=3` on this host. Purchase code is unchanged.
  - Maestro: not installed on this host.
  - The self-hosted CI runner: offline.

## Open items

- Weekly overtime in the main estimate (#42).
- Largest Dynamic Type sizes were checked through the existing UI journeys, not screen by screen.
- Real-device camera scanning and OCR on paper paystubs were not exercised. The simulator has no camera.
- The home-screen name stays `LinePay`, as `docs/release/app-store.md` requires.
