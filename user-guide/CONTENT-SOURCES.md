# User-guide source coverage

Content reviewed **2026-09-06** against `streamentry/linepay` main commit **fdf323e8e370bf50c93fb5596ffac542c58f31dd**. This is a source/label review, not a claim that the app has been released or that native UI, hardware, billing, and two-device recovery have all been validated. Website QA has a separate evidence artifact.

## Source map

Paths below are relative to the repository root. These notes are outside `content/` and are not published.

| Public guides | Primary implementation / contract |
| --- | --- |
| Get started; pay profile | `apps/ios/App/Sources/OnboardingFlowView.swift`, `PayProfileSetupView.swift`, `TodayView.swift` |
| Work periods; history | `PayLedgerView.swift`, `HistoryView.swift`, `SettingsView.swift`, `AppState.swift` under the same Sources directory |
| Recording work | `AddWorkView.swift`, `TodayView.swift` |
| Pay rules; dated changes; expected pay | `PayProfileSetupView.swift`, `PayLedgerView.swift`, `AuditDetailView.swift`; `apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/AgreementTimeline.swift`, `PaycheckAssessment.swift`; root `AGENTS.md` |
| Imports; confirmation; layouts | `PaystubImportView.swift` (includes the review and field-editor views); domain `PaycheckAssessment.swift` |
| Audit results; evidence; reports | `AuditDetailView.swift`, `AuditStatusView.swift`, `AppState.swift`, domain `PaycheckAssessment.swift` |
| Backup; data; deletion | `BackupRestoreView.swift`, `SettingsView.swift`, `HistoryView.swift` |
| Pro and billing | `SubscriptionStore.swift`, `SettingsView.swift`, `AuditDetailView.swift`, `docs/pricing.md` |
| Support addresses | `apps/ios/App/Sources/AppLinks.swift` |
| Visual language | `DESIGN.md` revision 2.0, current main blob `4c7bc03cf1548d6eb92be94f474265f1ff96f41a` |

## Important reconciliation decisions

- Current UI is a four-step setup, not the older single-form onboarding draft.
- Current Release code enables commerce. The guide does not repeat the obsolete disabled-commerce statement, and does not infer successful live purchase validation from a flag.
- The pricing contract now includes an eligible seven-day Annual offer. This supersedes the earlier no-calendar-trial discussion; actual StoreKit metadata/eligibility and purchase-sheet prices govern the user's offer.
- The app explicitly keeps existing records and exports available without Pro. Do not turn the older pricing feature list into a restriction on reading/exporting saved data.
- Expected wages and per diem are separate. Paystub gross basis and complete-work confirmation are required for a comparable full-paycheck result.
- Late-arriving paychecks and audit revisions exist in current History. They are not described as missing features.
- Current statuses are `Compared values match`, `Gross total matches`, `Not ready to compare`, `Possible shortfall`, `Possible overpayment`, `Needs review`, and `Not audited`, with `Awaiting paycheck` as a history/workflow state.
- Numeric guidance follows the current field UI and strict decimal-point format, not the older decimal-comma examples.
- `New rules from a date` is described using the explicit dated-timeline contract. The rule editor contains a broader ternary help sentence that can sound like every non-future scope recalculates the whole period. The guide does not repeat that misleading sentence; this documentation change does not alter app logic or claim the UI wording is fixed.
- Backup is manual, not live sync; it replaces rather than merges; it is not password-encrypted by the app. Restore Purchases is separate. JSON/PDF exports are not the complete backup format.
- Do not claim source verification, universal agreement coverage, tax treatment, legally owed wages, or a recovery amount. All numerical examples are synthetic and their arithmetic is checked.

## Maintenance gate

For each release, review changed visible labels, rule shapes, audit prerequisites, scope language, data-deletion/restore behavior, and billing copy against these guides. Update the reviewed date only after that review. Add real screenshots only from a verified build and synthetic fixtures, with build/device provenance; do not publish generated app mockups as product captures.

No public guide exports this source map, root AGENTS.md, internal docs, private repository links, or code snapshots. Hosting URLs and screenshots in QA artifacts are website test data only.
