# User-guide source coverage

The original full-site content review was completed **2026-09-06** against `streamentry/linepay` main commit **fdf323e8e370bf50c93fb5596ffac542c58f31dd**. It is now known to be stale for several later user-visible changes; issue #60 owns the complete release-candidate re-review and issue #64 owns a machine-checkable freshness contract.

For issue #40, the **Recording work**, related **Troubleshooting**, and **Glossary** Repeat Shift guidance was separately re-reviewed on **2026-09-06** against the merged `d05428e34103088dd85179ad39c74b904df10061` implementation. This partial review does not relabel the rest of the site as current.

For issue #41, the **Recording work**, **Overtime, callouts, and per diem**, and **Supported rules** callout-event guidance was separately re-reviewed on **2026-09-07** against the merged `9b015a08bec642e15f3449c5bca7a3af0a278bc5` implementation. This partial review does not relabel the rest of the site as current.

For issue #44, **Pay periods**, **History and corrections**, and relevant **Troubleshooting** guidance was separately reviewed on **2026-09-07** against the `fix/44-unresolved-period-rollover` candidate based on main `9b015a08bec642e15f3449c5bca7a3af0a278bc5` plus the issue-#44 changes. The reviewed contract is: an unresolved calculation can close without a fabricated amount, the reason/work/rules remain frozen in History, the next period stays independent, and **Retry saved calculation** re-runs only the frozen historical facts. This is source/test review, not a claim that hosted native Actions executed while #37 remains unresolved.

## Source map

Paths below are relative to the repository root. These notes are outside `content/` and are not published.

| Public guides | Primary implementation / contract |
| --- | --- |
| Get started; pay profile | `apps/ios/App/Sources/OnboardingFlowView.swift`, `PayProfileSetupView.swift`, `TodayView.swift` |
| Work periods; history | `PayLedgerView.swift`, `HistoryView.swift`, `AppSession.swift`, `AppState.swift`, `AppStateValidation.swift`; regressions in `UnresolvedPeriodLifecycleTests.swift` |
| Recording work | `AddWorkView.swift`, `CalloutEntryWorkflow.swift`, `RepeatWorkView.swift`, `RepeatWorkDraft.swift`, `TodayView.swift`; domain `apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/WorkTemplate.swift`; app regressions in `CalloutEntryWorkflowTests.swift` / `RepeatWorkDraftTests.swift` and domain `ProductBoundaryTests.swift` |
| Pay rules; weekly review; dated changes; expected pay | `PayProfileSetupView.swift`, `PayLedgerView.swift`, `WeeklyOvertimeReviewView.swift`, `AuditDetailView.swift`; domain `PayCalculator.swift`, `AgreementTimeline.swift`, `WeeklyRegularRate.swift`, `PaycheckAssessment.swift`; root `AGENTS.md` |
| Imports; confirmation; layouts | `PaystubImportView.swift` (includes the review and field-editor views); domain `PaycheckAssessment.swift` |
| Audit results; evidence; reports | `AuditDetailView.swift`, `AuditStatusView.swift`, `AppState.swift`, domain `PaycheckAssessment.swift` |
| Backup; data; deletion | `BackupArchive.swift`, `BackupRestoreView.swift`, `AppSession.swift`, `SettingsView.swift`, `HistoryView.swift` |
| Pro and billing | `SubscriptionStore.swift`, `SettingsView.swift`, `AuditDetailView.swift`, `docs/pricing.md` |
| Support addresses | `apps/ios/App/Sources/AppLinks.swift` |
| Visual language | `DESIGN.md` revision 2.0; semantic implementation must be rechecked on the exact release candidate |

## Important reconciliation decisions

- Current UI is a four-step setup, not the older single-form onboarding draft.
- Current Release code enables commerce. The guide does not repeat the obsolete disabled-commerce statement, and does not infer successful live purchase validation from a flag.
- The pricing contract now includes an eligible seven-day Annual offer. This supersedes the earlier no-calendar-trial discussion; actual StoreKit metadata/eligibility and purchase-sheet prices govern the user's offer.
- The app explicitly keeps existing records and exports available without Pro. Do not turn the older pricing feature list into a restriction on reading/exporting saved data.
- Expected wages and per diem are separate. Paystub gross basis and complete-work confirmation are required for a comparable full-paycheck result.
- The weekly regular-rate review is a restricted complete-workweek estimate. It requires explicit profile applicability and complete-week confirmation; it does not establish state, CBA, public-agency, exemption, or universal statutory coverage.
- Late-arriving paychecks and audit revisions exist in current History. They are not described as missing features.
- A completed work period with no safe calculation can still close. Its expected amount remains unavailable, its nonempty calculation-review reason is persisted, reconciliation remains nil, and the Free audit is not consumed. The next weekly/biweekly period is independent. A later retry operates only on A's frozen work/rules and does not rewrite B.
- Current statuses are `Compared values match`, `Gross total matches`, `Not ready to compare`, `Possible shortfall`, `Possible overpayment`, `Needs review`, and `Not audited`, with `Awaiting paycheck` and `Calculation needs review` as history/workflow states.
- Numeric guidance follows the current field UI and strict decimal-point format, not the older decimal-comma examples.
- `New rules from a date` is described using the explicit dated-timeline contract. The complete rule-change UX is tracked separately and must be re-reviewed under #15/#60.
- Backup is manual, not live sync; it replaces rather than merges; it is not password-encrypted by the app. Restore Purchases is separate. JSON/PDF exports are not the complete backup format. Unresolved closed-period state survives the complete backup without becoming zero.
- Repeat Shift copies payroll-local wall-clock facts for the shift and every recorded break. A repeated DST fold requires an explicit occurrence choice; a nonexistent local time requires manual fact review; unresolved copies cannot be saved. The ordinary Add Work editor no longer owns a template-copy API.
- Callout iOS 1.0 uses **one saved Callout row per confirmed physical callout event**. Adjacent continuation is explicitly merged; a separate adjacent event requires explicit confirmation. The row count itself must not silently decide a minimum entitlement, and legacy rows without event identity remain reviewable rather than auto-grouped.
- Do not claim source verification, universal agreement coverage, tax treatment, legally owed wages, or a recovery amount. All numerical examples are synthetic and their arithmetic is checked.

## Maintenance gate

For each release, review changed visible labels, rule shapes, audit prerequisites, scope language, data-deletion/restore behavior, billing copy, unresolved-period lifecycle, Repeat Shift time semantics, weekly review behavior, and callout event/guarantee semantics against these guides. Update the full-site reviewed date/commit only after that complete review. Add real screenshots only from a verified build and synthetic fixtures, with build/device provenance; do not publish generated app mockups as product captures.

No public guide exports this source map, root AGENTS.md, internal docs, private repository links, or code snapshots. Hosting URLs and screenshots in QA artifacts are website test data only.
