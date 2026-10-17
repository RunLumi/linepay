# ADR 0024: weekly review admission and exact boundaries

Status: implemented for the owner's all-stage v2 work, October 17, 2026. Native execution and visual/
accessibility acceptance remain pending. This is a correctness correction before the PWA port, not
completion of platform parity or a legal-profile approval.

Inspection found that weekly v1 could exclude noncreditable work premiums, accept unknown credit
classification, and admit invalid decoded facts. The native collector also dropped week-crossing
shifts, used only the shift-start rate, examined unrelated historical rule scope and inferred the
remuneration numerator from clock records. New calculations use `linepay.weekly-regular-rate/2`.

For the declared ordinary covered/nonexempt hourly scope, confirmed non-overtime work premiums are
includable with no credit; unknown treatment stops calculation. Explicit excluded cash remains a
separate reviewed classification. Recheck dates/weekday, threshold40, fact identities, nonnegative
amounts, currencies, optional seconds, rounding and credit classifications after decoding. Multiply
before division; do not use a displayed rounded rate for the premium. Allocation uses exact straight-
time numerators, stable source-fact IDs, deterministic period order and a conserved rounded residual.
Unsupported zero allocation bases refuse rather than silently leave positive premium unallocated.

The recorded-work collector requires an explicit start instant and clips a fixed 604,800-second window,
not a seven-calendar-date paycycle. Workweek duration and calendar paycycles are different concepts.
Split at actual break/midnight boundaries, remove only intersecting unpaid break portions, and select
that date's exact rule snapshot. Preserve source work IDs, period IDs, seconds and applied references.
Ignore unrelated old periods; refuse relevant mixed timezone/rule scope, duplicate/overlapping work
and invalid context. Input source records are never rewritten. New work facts optionally retain exact
seconds; legacy hours-only facts remain readable. Sum seconds/numerators before conversion.

The native review requires the worker to confirm the actual employer workweek start date/time and
its fixed 168-hour end. The configured weekday supplies an initial suggestion, not an inferred legal
anchor. A reviewed boundary can have a different local weekday/hour after DST; the explicit boundary
wins only for this declared review. Start/end/zone remain in new results; old results gain none.
No recurring anchor or employer schedule is invented or migrated from a weekday alone.

Clock facts do not prove remuneration/credit classification. Native review now asks for reviewed
straight-time wages and every other cash payment, its inclusion/exclusion and any eligible premium
portion. No automatic bonus, allowance, guarantee or premium-credit inference. Work completeness,
boundary and payment review are separate confirmations. Editing material facts, changing the week or
relevant stored work/rules invalidates results/confirmation. These reviews remain ephemeral and
separate from Pay; they do not silently add wages, clear a paycheck warning, consume an audit or
establish legal completeness. Physical/UI acceptance and persistent weekly evidence remain pending.

Historical weekly v1 results retain their original values. The legacy fixture was emitted from
actual `f4dd8e1` sources and demonstrates the old 2840 result versus new 2860 for explicitly stated
synthetic inputs. It is historical software behavior, not a correct current pay expectation. Native
state remains schema8; container/encryption versions are unchanged. Android/PWA adoption is pending.

Scoped primary references checked October 17, 2026: [29CFR778.105](https://www.ecfr.gov/current/title-29/section-778.105)
for fixed 168-hour workweeks and [29CFR778.207](https://www.ecfr.gov/current/title-29/section-778.207)
for non-overtime premium treatment. Applicability, exceptions and broader #42 review remain open.
A source check, worker checkbox or passing regression is not counsel/union/source approval.


The paycheck assessor's existing engine3 coarse weekly-warning guard is a remaining release blocker:
>40h in one calculation and an arbitrary attached weekly result are insufficient proof of complete
workweek/paycheck mapping. Its versioned correction and legacy-result preservation are separate
required follow-up; this review does not attach a result to bypass that guard.
