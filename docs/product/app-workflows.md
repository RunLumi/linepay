# How LinePaycheck works

[Product home](README.md) · [Business rules](business-rules.md) · [Screen mockups](../plan/mockups.md)

**PRODUCT specification.** This explains intended user-visible behavior. For implementation evidence and exclusions, use [coverage and gaps](payroll/coverage-and-gaps.md) and the candidate's test results. It does not declare all planned screens finished.

## 1. First use and first value

```text
Welcome: private, no signup
  → pay basics
  → pay-period cadence and boundaries
  → supported rules, sources, and missing coverage
  → plain-language confirmation
  → record actual work
  → see expected pay and its explanation
  → optional eligible annual trial / monthly subscription / Continue Free
```

Optional contractual premiums begin unconfigured, not guessed. The app must explain that unconfigured legal coverage is a limitation, not zero entitlement. A worker can save progress and return. No fabricated sample shift silently becomes real work.

The first visible amount includes its earnings window, currency, wage/allowance basis, and coverage. The worker can answer “Which hours and rules produced this?” before seeing an upsell. Current trial and first-audit interactions are governed by [pricing](pricing.md) and [onboarding](onboarding.md); do not revive the older no-calendar-trial policy from a historical plan.

## 2. End of a shift

Today offers Add Work and, where useful, Repeat Last Shift. A work draft contains date/time instants, payroll timezone, kind, notes, and explicit break spans. A repeated shift is still a proposal requiring review. Show elapsed time separately from unpaid breaks and derived entitlements.

On Save: validate facts and period ownership, calculate using the effective rules, persist safely, then show the new result. Failure leaves the draft and old saved records intact. A callout guarantee adds a pay component; it never changes a two-hour actual callout into four hours of physical work.

Edit uses the same invariants. Delete offers context-bound Undo. Changing tabs, closing a period, or opening a different employer profile cannot cause Undo or a resumed draft to write into the wrong context.

## 3. Payday and document review

```text
Choose earnings period
  → scan / image / PDF / manual entry
  → preserve a period-bound intake draft and original
  → on-device OCR suggestions, when applicable
  → inspect source beside uncertain fields
  → confirm dates, current-period amounts, line mappings, and work completeness
  → run only the comparisons justified by that evidence
```

Material review questions are:

- Does this paycheck cover this exact earnings period and all recorded work?
- Is the printed amount wage gross or a total including per diem? Is it current, not YTD?
- Are overtime amounts full wages or extra premiums above base already elsewhere?
- Are displayed hours actual work or guaranteed equivalents? Where is callout pay included?

Blank is unknown, not zero. A manual path is equally legitimate and subject to the same validation. For imported documents the app retains page/field provenance; review edits do not destroy original evidence. A page limit, missing text, unreadable document, or ambiguous value produces an explicit limitation.

## 4. Understanding a result

The Pay screen shows the comparison scope first, then expected vs confirmed paid, then actionable reasons. [Reconciliation](payroll/reconciliation.md) owns exact semantics.

| Outcome | Meaning | Next action |
|---|---|---|
| Matches within stated scope | Comparable totals/confirmed lines agree under the recorded rules | Inspect scope; save the audit |
| Possible shortfall | A supported comparable expected amount exceeds confirmed paid | Review implicated work, rule and paycheck evidence |
| Possible overpayment | Confirmed paid exceeds the supported expected amount | Review missing work, adjustment lines and rules; do not infer a repayment debt |
| Needs review | There are conflicts, missing material coverage, stale facts, or uncertain mappings | Correct or explicitly qualify the evidence |
| Not comparable | A meaningful expected-versus-paid comparison cannot be made | Resolve period, currency, gross basis, completeness or unsupported structure |

The amount is never a legal conclusion. “Matched” does not prove that an unmodeled bonus, weekly overtime requirement, rest premium, or prevailing-wage fringe was paid.

The evidence view narrows to the relevant components rather than repeating an unrelated full ledger. Source links and calculations remain available when the device is offline, except deliberately opened external websites.

## 5. The two-period lifecycle

Work closure and audit closure are different dimensions. This conceptual diagram does not mandate identical enum names in code:

```text
Period A: recording work
       → work closed / awaiting paycheck ──────────→ audited revision 1
                |                                      → revised audit 2, if corrected
                v
Period B: recording new work, independently
```

A common acceptance scenario is A ending Sunday, B beginning Monday, and A's check arriving Thursday. The worker audits A from History while continuing B. No temporary profile swap, reopening overwrite, or work deletion is required.

An “archive” action must not strand an unpaid period. A saved historical audit is an immutable observation; a new correction is an appended revision with its own inputs and explanation. Viewing old records uses their saved timezone, not the current profile's timezone.

## 6. Changing pay arrangements

Distinguish editing future defaults, recording an effective-dated rate/rule change, and correcting a past mistake. Show exactly which work will change. Preserve a prior audit before applying a correction. If the engine cannot represent an interaction such as a mid-callout guarantee spanning rate changes, disclose the limit instead of interpolating a convenient formula.

A different local, employer, project, classification, or work state requires applicability review. A “storm” note is not authorization to select a nationwide storm rate. [The rule catalog](payroll/rule-catalog.md) lists the missing facts to collect.

## 7. Subscription and owned records

A successful Free audit authorizes that period's audit access; repeat corrections to that period are not new pay-period consumption. A verified Pro trial/subscription authorizes recurring audits according to the canonical entitlement contract. Cancelling renewal does not mean immediately ending an already paid access period. StoreKit controls the actual signed state, eligibility, and billing presentation.

Workers can continue Free logging and reading/exporting their existing records after Pro access ends. Restore Purchases is independent from restore local data. A backup cannot manufacture an App Store entitlement.

## 8. Backup, privacy, and deletion

Manual backup and restore use the worker's selected Files provider, which can be iCloud Drive. This is not automatic device synchronization and does not require a LinePay account. Show whether originals are included and warn that the resulting file contains sensitive records. Follow the [backup architecture](../architecture/icloud-drive-backup-restore.md) rather than inventing encryption guarantees.

Deleting an original can leave confirmed structured facts and audit history, with the evidence state marked accordingly. Deleting all local data also handles app-controlled drafts, queued deletion, and temporary exports; copies already shared elsewhere are outside the app's control. On corrupted storage, offer safe export/retry/restore and explicit reset, not silent destruction.

## 9. Screens are acceptance states

Use [the 1.0 plan](../plan/ios-1.0.md) and [mockups](../plan/mockups.md) for the full screen/state list. Reusable views are encouraged. A state is complete only when reachable, correct, recoverable, and verified at an appropriate level. File count, a successful build, and a pleasing screenshot do not prove the recurring payday workflow.
