# Local agreement import evaluation

[Testing contract](README.md) · [Architecture](../adr/0011-local-agreement-import.md)

The v2 reader is a conservative, English clause-pattern assistant. It does not interpret an entire
contract, select a worker classification, establish publication rights or verify legal applicability.
An unsupported clause remains a limitation. No official agreement pack is included by this slice.

`AgreementImportTests` owns seven exact-label examples (hourly rate, daily overtime/double time,
Sunday multiplier, callout minimum, flat per-worked-date allowance and ISO effective start),
conflicting rates, conditional-clause abstention, low recognition confidence and stable source IDs.
Synthetic PDFs exercise embedded text and a raster-only page through the actual local Vision
adapter. These are development fixtures, not an independent employer-layout accuracy corpus.
Do not infer recall, production precision or broad PDF/table support from their pass count.

The real PDF → retained original → reviewed draft → explicit profile activation test uses independent
amounts: the previous eight hours at 50 remain 400; eight later hours at the confirmed 60 rate are
480. Preparation alone must preserve both the old profile and its result. Original bytes, physical
PDF page, quotation and fingerprint remain traceable through the rule snapshot.

`AgreementImportLifecycleTests` owns schema-5 migration, manual backup/restore with exact bytes
and stable citations, source removal and exact-file reattachment, failed-save atomicity, changed
original refusal, unfinished-draft replacement consent, protected referenced imports and deleted
record non-resurrection. The backup-mapping regression also preserves closed-period calculation
issues and work-correction history. PDF-report source quotations and fingerprints require the
separate source-detail opt-in; minimized reports exclude them.

Native `PaydayJourneyTests` exercise the first-run entry, source page, editable values, explicit
clause/date/applicability review, handoff to the existing editor, final activation and largest-text
review recovery. Record the actual result bundle in the [execution ledger](../plan/v2-execution.md).
A source PDF viewed by a Simulator test is separate from a real Files-provider import or physical
camera scan. Final release gates remain required against the eventual release candidate.

Before a broader accuracy claim, add rights-cleared independent PDFs, classifications, amendments,
multi-page tables, scans and ambiguous layouts. Label expected candidates and abstentions before
running extraction. Report supported-field precision and missing/unsupported clauses separately;
no threshold allows an uncertain clause to become an active rule without confirmation.
