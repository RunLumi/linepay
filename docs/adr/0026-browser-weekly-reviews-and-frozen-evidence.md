# ADR 0026: browser weekly reviews and frozen evidence

Status: implemented for the owner's all-stage/local-only v2 request, October 17, 2026. Browser
runtime receipts are recorded in the execution ledger. Full platform parity, installed/physical PWA,
verified paycheck allocation and release remain pending.

Add a separate Workweeks surface. Its fixed 168-hour boundary is an explicit timestamp with seconds
and offset, plus payroll timezone; no paycycle or device-timezone inference. The worker explicitly
selects source periods for one employer and confirms employer scope, boundary, all work and every
remuneration classification. No employer identity is inferred from a profile, rate or currency.
Unselected employers are not merged. Selected periods remain associated even if no worked portion
falls inside this interval; absence of worked hours is not a waiver of other obligations.

Capture only relevant original clock entries/breaks, exact baseline/dated-rule plans and selected
period identities. Do not copy paystub histories or imported originals into a weekly review. Clip
both tails to 604,800 seconds, split at actual local midnights, subtract intersecting breaks and select
the recorded effective rate. Relevant mixed currency/timezone, overlaps/duplicates or malformed
facts refuse. Sources are frozen with the record; later ledger edits do not reprice it.

Remuneration starts blank and unclassified. Explicitly review straight-time wages, includable bonuses,
excluded cash and premium portions. Unknown premium treatment refuses. Ineligible non-overtime work
premiums are includable with no credit. Eligible credit means the already-paid extra premium, not a
full overtime line. The exact rational engine sums seconds/numerators, multiplies before division,
rounds cash/premium under explicit policy and conserves deterministic allocation units. Hours/rate
presentation rounding never feeds arithmetic. Shared Swift/browser vectors establish a bounded
mathematical subset, not applicability, universal legal coverage or employer/source verification.

Preview writes nothing; material edits invalidate preview/confirmations. Saving appends an immutable
weekly record with original inputs, source note and reproducible result. Saved history is local and
included in the existing protected manual financial backup. This feature does not add a weekly PDF,
automatic transfer, backend/account or verified weekly-to-paycheck premium integration.

Web state v7 adds `weeklyReviews`. Known schemas1–6 gain an empty array without invented reviews or
repricing. A frozen v6 fixture was generated/validated with actual 928d58c modules and retains the
v6 calendar/source-period metadata. State validation checks complete source/rule admission, exact
input/result reproduction, unique identities and the shared restorable 8 MiB snapshot budget before
commit. Container/encryption versions remain1; native financial snapshot interchange stays unsupported.

New paycheck assessments use `linepay.web.configured-gross/3`. A frozen prefix count and related
review IDs capture the append-only weekly knowledge present when the check was made; local storage
revision numbers are unsuitable because restore rewrites that concurrency token. New checks with
related weekly evidence stay Needs review even if the worker leaves the manual weekly-pending flag
off. No arbitrary weekly result clears missing mapping. Old v1/v2 and earlier-prefix v3 receipts
reproduce their original values; later related evidence labels them as an earlier context in UI/
reports, rather than rewriting them. Protected recovery preserves prefix order/references.

The shell advances to cache v9. A new worker controls a context after normal navigation; no forced
reload/skipWaiting is added over an unsaved form. Browser E2E uses real IndexedDB, encrypted downloads,
reset/inspection/replace and stopped-origin navigation with the existing no-worker negative control.
These tests are not OS Files delivery, physical/installed PWA, native migration or App Store proof.
