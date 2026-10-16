# Selected worker-provided rule drafts v1

[Shared contracts](../README.md) · [Browser client](../../../apps/web/README.md)

`rule-drafts-v1.json` contains five synthetic cases consumed independently by JavaScript and Swift.
A rule draft transfers selected configurable parameters. It is not a work record, payroll backup,
verified agreement, official preset or source-approval artifact. It has no publisher authentication.
Do not infer rights, legal applicability, completeness, professional review or production crew use
from a file, a worker's confirmation or these tests.

## File contract

File extension: `.linepayrules`. UTF-8 JSON, at most 65,536 bytes. Root fields are exactly:

| Field | Meaning |
|---|---|
| `format` | `com.streamentry.linepay.rule-template` |
| `version` | Integer `1` |
| `templateID` | Public UUID for this draft; not a worker/profile/period identifier |
| `revision` | 1–32 ASCII letters, digits, dots or hyphens; an opaque draft revision |
| `title` | Nonempty title, at most 240 UTF-8 bytes, no C0/DEL controls |
| `scope` | `workerConfirmedConfiguredRulesOnly` |
| `premiumCombination` | `highestApplicable`; premiums do not multiply together |
| `rules` | The fields below |

Unknown/missing fields, incompatible scope/version/precedence, duplicate object fields (including
escaped aliases), numeric JSON money and oversized files are rejected. A changed payload requires a
new template ID or revision. JSON layout/key order is not a signature or source-identity guarantee.

Rules contain explicit three-letter uppercase `currency`, nullable decimal-string `hourlyRate`,
`dailyOvertimeTiers`, `weekdayPremiums`, nullable decimal-string `calloutMinimumHours`, `perDiem` and
`rounding`. A tier has only `afterHours` and `multiplier`. A weekday premium has only `weekday` and
`multiplier`; names are lowercase Sunday through Saturday, unique and in that order. Thresholds
must increase and resolve to whole elapsed seconds. `perDiem` has exactly Boolean `configured` and
nullable decimal-string `amount`. Unconfigured per diem cannot carry an amount. Configured with a
null amount means the amount was omitted, **not zero**. Rounding has `scale`, `mode`, `scope`:
scale 0–8, modes halfUp/bankers/down/up, scope payCategory.

Numbers use unsigned decimal strings with up to eight fractional digits; no grouping, exponent or
currency symbol. Monetary values are 0–10,000,000, daily thresholds 0–168 hours, positive callout
minimum up to 168 hours, and multipliers 1–10. These are v1 representation/safety limits, not legal
pay ceilings. At most 20 tiers and 7 weekday premiums. Smaller-than-one-second daily thresholds,
legacy rounding, schedules, off-schedule/date premiums, effective-date transitions and weekly rules
are not represented. Exports containing those unsupported conditions must refuse rather than
silently drop them. Source documents, annotations, employer/worker identities and original ledger
rule IDs are not copied by the exporter. The recipient must check their own applicability context.

## Sharing and adoption

Export defaults omit hourly wage and per-diem amounts. Including them requires an explicit choice
and a new exact-file review. The title/conditions can still identify a group; the file is not
anonymous. Sender UI requires rights confirmation, which is not independent legal clearance.
No real agreement pack or wage library is bundled by this feature.

Import inspects without creating records. The recipient must explicitly confirm an hourly rate,
currency/rounding and applicability to their work/classification/dates. An included sender amount
may be displayed for review but does not waive confirmation. A configured allowance requires an
explicit own-amount or not-applicable decision. An unconfigured allowance remains unconfigured,
not a legal waiver. Unsupported/unknown values do not become zero or an inferred rule.

Adoption creates a fresh profile, preserving the draft and the recipient's actual choices. It does
not edit existing period/rule/history snapshots. The browser stores those origins atomically with
the profile in web state v3, and protects them in manual encrypted backup/recovery. Its old v1/v2
migrations add only empty origin metadata after validating retained records. The Swift codec
returns a new proposed agreement and exposes its calculation policy; native app adapters must
persist original draft/choices, collect confirmation and implement actual Files UI before claiming
a native sharing workflow. Android decoding/adoption remains pending.

## Verification

```bash
node --test apps/web/tests/*.test.mjs
bash scripts/agent-verify.sh quick
```

The five cases cover omitted/included amounts, absent allowance versus zero, multiple premiums,
UTF-8 title and exact CAD/callout configuration. Negative suites cover unknown/private fields,
number/precision/boundary refusal, escaped duplicate fields, missing confirmation, altered origin
choices and immutable draft identity. Real browser tests transfer actual downloaded files between
isolated synthetic sender/recipient contexts, then restore recipient provenance through encrypted
backup. This is engineering evidence, not observed adoption by a real crew or OS/device delivery.
