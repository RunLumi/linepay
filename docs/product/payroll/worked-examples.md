# Worked examples and acceptance vectors

[Payroll home](README.md) · [Calculation specification](calculation-spec.md) · [Reconciliation](reconciliation.md)

**EXAMPLE: all rates, schedules, and paystub amounts below are synthetic.** They are not US market rates, source-backed agreement presets, or claims of executed app tests. Arithmetic and timezone examples were independently checked while preparing this handbook. Statutory examples assume the ordinary cash-overtime framework and stated exclusions; see [legal applicability](us-legal-baseline.md). “Reference only” means the current app does not gain this capability merely by documenting it.

## Configured-rule arithmetic

| ID | Explicit input/rule | Expected result | Acceptance invariant |
|---|---|---|---|
| EX-01 | 8 worked hours at $50, no configured premium | 8 × 50 = **$400** | Exact configured wages; no invented OT |
| EX-02 | 12 worked hours, $50, daily 1.5× after 8 | 8 × 50 + 4 × 75 = **$700** | Split at the threshold |
| EX-03 | 14 worked hours, $50, 1.5× after 8 and 2× after 12 | 400 + 300 + 200 = **$900** | Distinct ordered tiers |
| EX-04 | 07:00–17:00 elapsed 10h, genuinely noncompensable 12:00–12:30, $50, daily 1.5× after 8 | 9.5 worked h; 400 + 1.5 × 75 = **$512.50** | Remove exact break span, not an arbitrary shift end |
| EX-05 | 10 Sunday hours at $50; Sunday 2× and daily 1.5× after 8; explicitly highest-applicable combination | 10 × 100 = **$1,000** | Do not multiply the two premiums |
| EX-06 | One isolated 2h callout, $50, applicable 2×, confirmed 4h minimum | $200 worked + $200 top-up = **$400** | Actual work stays 2h; no invented 4h worked |
| EX-07 | Two separate entries on one qualifying work date; flat $125 per work date | **$125**, not $250 | Deduplicate by allowance unit |
| EX-08 | 2h at old $50, then 6h at new $60; effective change confirmed; no premium | 100 + 360 = **$460** | Preserve effective rates instead of 8 × latest rate |
| EX-09 | 6h at $50 then 4h at $60 same workday; daily 1.5× after 8 | 300 + 120 + 180 = **$600** | Rate change does not reset daily accumulation |

EX-06 deliberately excludes regular-shift overlap, multiple calls, rest, and rate changes. It must not be labeled a complete test of any actual callout clause.

## Statutory reference cases, not current engine-coverage claims

For EX-10–EX-14 assume one covered, nonexempt employee, one employer, complete workweeks, no applicable alternative method, cash overtime, no higher state/contract obligation, and straight time paid for all worked hours. Compensation inclusions/exclusions and credits are as explicitly stated. See [F01](sources.md#f01), [F02](sources.md#f02), [F05](sources.md#f05), and [F06](sources.md#f06).

| ID | Explicit facts | Reference result | Failure being prevented |
|---|---|---|---|
| EX-10 | Six 8h days = 48h; $50 base; no other remuneration/premiums | 48 × 50 + 8 × 25 = **$2,600** | Daily-only engine would show $2,400 and miss weekly OT |
| EX-11 | Biweekly check: week A 50h, week B 30h; $50 | A $2,750 + B $1,500 = **$4,250** | Averaging 80h across two weeks incorrectly gives $4,000 |
| EX-12 | 48h at $50 plus $240 includable nondiscretionary bonus allocated to this week; no prior premiums | R $2,640; RR $55; extra 8 × $27.50 = $220; **$2,860 cash** | Base-rate-only premium would miss bonus effect |
| EX-13 | Same complete week: 30h at $40 and 20h at $60; weighted method applicable | R $2,400; RR $48; extra 10 × $24 = $240; **$2,640** | Unequal hours expose an incorrect unweighted average |
| EX-14 | 48h at $50; contract already pays 40h at 1× and 8h at 2×; assume $400 extra premium meets lawful credit conditions | Contract cash **$2,800**; regular-rate floor extra $200; eligible credit $400; additional federal cash **$0** | Double-paying statutory premium or crediting unrelated payments |

EX-14 is not a rule that every amount labeled overtime is creditable. If the supposed credit were an unrelated reimbursement or non-work guarantee, the assumption would fail and the answer would require re-analysis. State and contractual obligations remain independently relevant.

## Paystub interpretation and verdicts

| ID | Facts | Required result |
|---|---|---|
| EX-15 | Expected $400 wages + $125 separately reimbursed per diem; check wage gross $400 and reimbursement $125; mapping confirmed | Wage-gross difference **$0**; allowance difference **$0**. Do not invent $125 missing wages. |
| EX-16 | Expected regular $400 and OT $150; confirmed regular $350 and OT $200; both gross $550 | Gross difference **$0**; regular **+$50**, OT **−$50**. **Needs review**, not unconditional Matches. |
| EX-17 | 10h at $50 with 2h at 1.5×; full-rate check shows regular $400 + OT $150 | Expected gross **$550**; compared lines match under full-rate layout. |
| EX-18 | Same work as EX-17; check shows base for all 10h $500 + premium-only OT $50 | Same **$550**; compared lines match under base-plus-premium layout. Never expect another $150 premium. |
| EX-19 | Same gross as expected but a material rest rule is explicitly unsupported | **Needs review / limited configured scope**; do not certify all agreement pay. |
| EX-20 | Only half the work period is recorded, but a complete paycheck is entered | No full-paycheck difference conclusion until completeness is resolved. |
| EX-21 | Manually typed `1,000.00`; supported US grouping | Exactly **1000.00**, or clear rejection under an incompatible locale policy; never 1. |
| EX-22 | `58oops`, invalid grouping, mixed currency, NaN, unsupported negative adjustment | Validation error, not a partial or absolute-value parse. |
| EX-23 | OCR line `Gross pay: Current $1,000.00 YTD $12,000.00` | Propose current **1000.00 only with supported column evidence**, or abstain. Never choose the last number automatically. |

## Time and lifecycle cases

| ID | Synthetic facts | Expected behavior |
|---|---|---|
| EX-24 | New York, March 8, 2026, local 01:00 EST (06:00Z) to 04:00 EDT (08:00Z) | **2 elapsed hours**, not 3 |
| EX-25 | New York, November 1, 2026, 00:00 EDT (04:00Z) to 04:00 EST (09:00Z) | **5 elapsed hours**, not 4 |
| EX-26 | A ends Sunday; B receives new work Monday; A's check arrives Thursday | Audit A with frozen A facts while B is unchanged and usable |
| EX-27 | Delete work in A, close A/start B, then attempt retained Undo | Reject stale command; no A work inserted into B |
| EX-28 | Scan original, confirm, later edit only an amount manually | Retain original source; append the permitted audit revision |
| EX-29 | Change profile timezone after archiving A, then display/export A | A's original dates, timezone, rules and amounts remain unchanged |
| EX-30 | Kill app during a work draft or imported-source review | Resume the original draft/source/context; do not invent completion |
| EX-31 | Fail storage write or evidence deletion | Preserve valid prior state or retryable cleanup and truthful error; no false success |
| EX-32 | Product metadata fails offline while a valid signed entitlement is available | Entitlement lookup remains independent; owned records remain accessible |
| EX-33 | Run audit during verified Pro trial with an unused Free audit | Preserve unused Free allowance; a later Free audit consumes it according to the canonical contract |
| EX-34 | Restore local backup containing historical Pro flags | Verify StoreKit independently; do not mint a subscription from local JSON |

## Turning examples into tests

Each implemented vector records its EX ID, named input variant, test path, and the candidate SHA/result. Add just-before/at/after thresholds and contrary inputs where relevant. A mismatch requires investigating applicability, facts, and rounding before changing the expected value. Never edit a fixture merely to agree with a buggy implementation.
