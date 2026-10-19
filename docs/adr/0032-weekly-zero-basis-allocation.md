# ADR 0032: versioned weekly residual allocation

Status: implemented candidate, October 19, 2026. Native release and weekly-to-paycheck mapping
remain separate gates.

The weekly reference distributes an already rounded additional premium across periods in
proportion to their confirmed rate-times-second bases. Version 2 could give a residual cent to
a zero-basis group merely because its identity sorted first. For 50 qualifying hours and USD0.10
confirmed includable remuneration, the additional premium is 0.10 × 10 / (2 × 50) = USD0.01.
With bases 0,60000,60000, the first group must receive zero and the first positive group receives
the cent. The weekly total itself does not change.

New Swift, browser and Android reference results identify engine version 3. The residual pass
visits only positive-basis groups, in the existing deterministic identity order. Zero groups stay
visible at zero; allocations still sum exactly to the rounded premium. This is an arithmetic
correction under confirmed inputs, not a new legal-pay rule or proof of applicability.

Native recorded v1/v2 results remain frozen Codable values. Browser v2 records validate using
their original arithmetic, including its known defect; newly requested calculations always use
v3. Unknown engines and altered retained results refuse. Genuine v2 zero-basis and positive-basis
receipts survive encrypted browser recovery without repricing. The new shared v3 vectors place the zero basis first, middle and last, accept exactly 168 actual
hours, and refuse per-fact/aggregate excess time. The original seventeen v2 vectors remain unchanged.

Android adopts the pure restricted reference for the first time, using exact rational intermediates
and explicit workweek, employer, remuneration and applicability confirmations. This milestone adds
no Android UI, state migration or gross-verdict change. Native collection/persistence and complete
weekly-to-paycheck mapping remain pending; a reference result cannot clear missing coverage.

Regression evidence includes a failing pre-fix zero-basis case, Swift historical round-trip,
browser same-version replay/tamper refusals/encrypted recovery, and all three shared consumers.
See the [shared reference](../../shared/contracts/weekly/README.md),
[business rules](../product/business-rules.md#restricted-weekly-review) and
[execution record](../plan/v2-execution.md) for actual integration gates.

New v3 inputs also bound actual work to the explicitly reviewed fixed 168-hour window. This
includes actual work declared nonqualifying for overtime; excluded cash belongs in remuneration,
not invented elapsed time. Per-fact hours and seconds follow the same bound, aggregate work cannot
exceed the window, and native decimal conversions must preserve exact durations. Android normalizes
accepted decimal hours before arithmetic; extreme-scale zero representations cannot cause overflow.
These admission corrections leave the confirmed forty-hour reference threshold unchanged. Browser
v2 replay retains its original admission semantics rather than invalidating a stored receipt.

A browser downgrade to a pre-v3 client cannot read new v3 weekly receipts, even though the outer
state schema remains8. Prefer repair forward, retain manual backups, and verify the intended reader
before rollback. Reverting assets alone is not a recovery procedure for newer stored results.
