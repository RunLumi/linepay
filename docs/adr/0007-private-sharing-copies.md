# ADR 0007: Minimized, preview-bound report sharing

Status: Accepted implementation decision; native acceptance remains required before release.
Date: September 6, 2026
Issues: LEGAL-02/#14, LEGAL-03/#15, LEGAL-08/#20, LEGAL-09/#21, LEGAL-17/#29.

## Decision

A report is a derived sharing copy, never a replacement for the worker's evidence. The default
PDF retains the saved assessment, numeric facts, calculation explanations and source page
references. It omits optional OCR source lines, profile identifiers, source names/URLs/sections,
work notes and private unsupported-rule notes. An affirmative source-detail option creates a new
copy and warns that adjacent identifiers may be included. Neither copy is described as anonymous.

Every current, closed-period and revision report uses the same options -> PDF preview -> explicit
share flow. A value-type `ReportShareSession` owns a bounded immutable byte snapshot. The share
action is available only after that exact snapshot loads in the PDF preview and the working file
still matches it. Changed options, failed preparation, failed preview, removal and dismissal revoke
that session's share access. No record or original is altered by generating a report.

The system share uses a PDF `DataRepresentation` containing the immutable preview bytes, not the
app's temporary URL. A system activity can therefore finish using its own payload after the report
sheet closes and the working file is cleaned. There is no race in which cleanup changes which
contents are transferred. External copies remain outside the app's deletion authority.

Cleanup is limited to the matching UUID-named report in the app-owned temporary export directory.
Unrelated paths, symlink targets and dangling symlinks are refused. Failures revoke the stale share
action and remain retryable; existing delete-all cleanup is not broadened. This is not a claim of
forensic erasure or password encryption. The existing device file-protection policy is unchanged.

## Consent and scope

`ComparisonScopeDisclosure` supplies one explanation for setup, audit detail, About and PDF output.
A matching configured comparison is not certification of all statutory or contractual entitlements.
The three rule-change scopes use an exhaustive presentation switch and the same effective-date
fallback as application validation, in the frozen payroll timezone. Existing numerical guards,
calculation behavior, archived snapshots, audit revisions and persistence formats do not change.

## Verification boundary

Tests check default-private sentinel exclusion in underlying PDF text, explicit opt-in, source
preservation, report revision behavior, effective-date consent, exact bytes, interrupted preparation
and scoped cleanup. Native interaction tests cover preview-before-share and the three scopes at
large text. See [the verification receipt](../qa/legal-remediation.md) for what actually ran.
A portable Foundation test is not an iOS UI, PDFKit, VoiceOver or real-device acceptance receipt.
