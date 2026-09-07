# User-guide source coverage

The original full-site content review was completed **2026-09-06** against `streamentry/linepay` main commit **fdf323e8e370bf50c93fb5596ffac542c58f31dd**. It is now known to be stale for several later user-visible changes; issue #60 owns the complete release-candidate re-review and issue #64 owns a machine-checkable freshness contract.

Targeted refresh **2026-09-07** was performed against the integrated candidate before this documentation-only commit: `cd68adb9cb5aebb5c0987418bcfd262200ce526c` (tree `aa19b228da10a5c9d329bc3fd6ca338801a5ec3c`). It covers only the legal-review drift in `changing-rules.md`, `pay-profile.md`, `evidence-and-reports.md`, `support.md`, and the new in-app User Guide link. The full-site review remains pending under #60; this entry must not be read as a release-wide freshness attestation.

For issue #40, the **Recording work**, related **Troubleshooting**, and **Glossary** Repeat Shift guidance was separately re-reviewed on **2026-09-06** against the `fix/40-repeat-shift-dst-ui` candidate based on main **dcd23bc6f9121cad29b43cd42a3b8e78e45ccf0e** plus the issue-#40 changes. This partial review does not relabel the rest of the site as current and is not a claim that native simulator, hardware, billing, or release validation passed.

## Source map

Paths below are relative to the repository root. These notes are outside `content/` and are not published.

| Public guides | Primary implementation / contract |
| --- | --- |
| Get started; pay profile | `apps/ios/App/Sources/OnboardingFlowView.swift`, `PayProfileSetupView.swift`, `TodayView.swift` |
| Work periods; history | `PayLedgerView.swift`, `HistoryView.swift`, `SettingsView.swift`, `AppState.swift` under the same Sources directory |
| Recording work | `AddWorkView.swift`, `RepeatWorkView.swift`, `RepeatWorkDraft.swift`, `TodayView.swift`; domain `apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/WorkTemplate.swift`; Repeat regressions in `apps/ios/AppTests/Sources/RepeatWorkDraftTests.swift` and domain `ProductBoundaryTests.swift` |
| Pay rules; dated changes; expected pay | `PayProfileSetupView.swift`, `PayLedgerView.swift`, `AuditDetailView.swift`; `apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/AgreementTimeline.swift`, `PaycheckAssessment.swift`; root `AGENTS.md` |
| Imports; confirmation; layouts | `PaystubImportView.swift` (includes the review and field-editor views); domain `PaycheckAssessment.swift` |
| Audit results; evidence; reports | `AuditDetailView.swift`, `AuditStatusView.swift`, `AppState.swift`, domain `PaycheckAssessment.swift` |
| Backup; data; deletion | `BackupRestoreView.swift`, `SettingsView.swift`, `HistoryView.swift` |
| Pro and billing | `SubscriptionStore.swift`, `SettingsView.swift`, `AuditDetailView.swift`, `docs/pricing.md` |
| Support addresses | `apps/ios/App/Sources/AppLinks.swift` |
| Visual language | `DESIGN.md` revision 2.0; semantic implementation must be rechecked on the exact release candidate |

## Important reconciliation decisions

- Current UI is a four-step setup, not the older single-form onboarding draft.
- Current Release code enables commerce. The guide does not repeat the obsolete disabled-commerce statement, and does not infer successful live purchase validation from a flag.
- The pricing contract now includes an eligible seven-day Annual offer. This supersedes the earlier no-calendar-trial discussion; actual StoreKit metadata/eligibility and purchase-sheet prices govern the user's offer.
- The app explicitly keeps existing records and exports available without Pro. Do not turn the older pricing feature list into a restriction on reading/exporting saved data.
- Expected wages and per diem are separate. Paystub gross basis and complete-work confirmation are required for a comparable full-paycheck result.
- Late-arriving paychecks and audit revisions exist in current History. They are not described as missing features.
- Current statuses are `Compared values match`, `Gross total matches`, `Not ready to compare`, `Possible shortfall`, `Possible overpayment`, `Needs review`, and `Not audited`, with `Awaiting paycheck` as a history/workflow state.
- Numeric guidance follows the current field UI and strict decimal-point format, not the older decimal-comma examples.
- `New rules from a date` is described using the explicit dated-timeline contract. The complete rule-change UX is tracked separately and must be re-reviewed under #15/#60.
- Backup is manual, not live sync; it replaces rather than merges; it is not password-encrypted by the app. Restore Purchases is separate. JSON/PDF exports are not the complete backup format.
- Repeat Shift copies payroll-local wall-clock facts for the shift and every recorded break. A repeated DST fold requires an explicit occurrence choice; a nonexistent local time requires manual fact review; unresolved copies cannot be saved. The ordinary Add Work editor no longer owns a template-copy API.
- Do not claim source verification, universal agreement coverage, tax treatment, legally owed wages, or a recovery amount. All numerical examples are synthetic and their arithmetic is checked.

## Maintenance gate

For each release, review changed visible labels, rule shapes, audit prerequisites, scope language, data-deletion/restore behavior, billing copy, and Repeat Shift time semantics against these guides. Update the full-site reviewed date/commit only after that complete review. Add real screenshots only from a verified build and synthetic fixtures, with build/device provenance; do not publish generated app mockups as product captures.

No public guide exports this source map, root AGENTS.md, internal docs, private repository links, or code snapshots. Hosting URLs and screenshots in QA artifacts are website test data only.
