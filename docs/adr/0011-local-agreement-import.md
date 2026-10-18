# ADR 0011: retained agreements and reviewed rule proposals

Status: accepted October 16, 2026 for the owner-authorized [v2 implementation](../plan/v2-execution.md).

## Authority and data flow

Import PDFs through Files and retain their exact bytes in the existing protected local evidence
store. Extract embedded text or use local Vision for scanned pages. No cloud model, account,
network upload, named agreement pack, or professional verification is introduced.

A bounded local pattern reader proposes supported values and preserves other recognized clauses
as unresolved. It abstains on conditional/ambiguous or low-confidence text. This is document
understanding assistance, not an autonomous contract interpreter. User review of employer,
classification, jurisdiction, amendments, currency and dates remains mandatory. A structural match
or fingerprint is not evidence of legal applicability or permission to republish an agreement.

## Representation and history

Schema 6 adds optional imported-document records. Versions 1–5 migrate additively; historical
work, rule snapshots, audits and resolution events are not recalculated. Older binaries reject
schema 6 rather than ignoring document ownership and deleting originals as unreferenced files.

Each document records an immutable SHA-256, physical PDF page count, extraction version,
source excerpts/candidates and saved review decisions. Each confirmed imported source in an
`AgreementSnapshot` retains optional document ID, SHA-256, zero-based physical PDF page and
quotation. Source metadata is additive in `LinePayDomain`; it has no effect on payroll arithmetic.
Rule editors preserve this metadata when a profile is edited. Removing an original does not remove
historical source locators, quotations or calculation facts. Missing originals are disclosed.

Backups include retained agreement PDFs and their records through the existing evidence mapping.
Restore changes physical filenames without changing document IDs or fingerprints. Original-view
routes verify file bytes against the recorded hash before displaying a cited PDF. A removed
original can be reattached only when its exact fingerprint matches. Failed saves/reattachment do
not replace prior state. Existing backup size limits remain explicit; they are not encryption.

## Activation boundary

Importing and extracting cannot change the active profile or expected pay. The worker reviews each
candidate (confirmed, not applicable, or unresolved), verifies dates/currency/applicability, and
prepares a draft for the existing rule editor. The editor's final scope/preview/confirmation is the
only activation path. Replacing an unfinished setup draft requires explicit consent.

Supported mapping initially uses existing engine semantics: base hourly rate, daily premium tiers,
Sunday multiplier, isolated callout minimum and flat per-worked-date allowance. Selected daily tiers
replace the draft's tier list only after an explicit acknowledgement. Other existing categories are
kept for final review. Unsupported weekly/legal/benefit/differential/meal/show-up conditions are
retained as limitations, not reinterpreted as another rule or silently waived. Benefits will remain
separate from wage gross in their own v2 slice.

## Bounds and evidence

Read at most 25 MB, 128 PDF pages, 250,000 text characters and 64 candidate clauses per import.
Show a limitation when reading is incomplete. Retain the complete original, including unread pages.
Cancellation preserves the saved original and does not resurrect deleted records.

Required evidence: parser boundaries/conflicts/abstention, exact source provenance and round-trip,
real PDF extraction, review/activation refusal, independent expected money after explicit activation,
old-store migration, backup/restore and failed-save/original lifecycle regressions, plus native
import/review/source navigation. Corpus precision and production-layout coverage are separate
claims; no generalized performance claim follows from synthetic fixtures alone.
