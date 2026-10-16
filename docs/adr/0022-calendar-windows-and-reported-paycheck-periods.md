# ADR 0022: calendar windows and reported paycheck periods

Status: accepted for the owner's all-stage v2 request, October 17, 2026. Native app/runtime and
store proof remain pending; pure-domain/browser evidence does not close them.

Use [explicit calendar boundaries](../../shared/contracts/paycycles/README.md) for weekly, biweekly,
semi-monthly and custom windows. Normalize both boundaries to each local date's first instant.
Date-label addition precedes zone resolution: neither a skipped midnight nor a whole skipped date
may shift the ending label. Explicit nonexistent start/manual-last/exclusive-end dates refuse instead of normalizing.
The pure Swift helper reads explicit Gregorian dates/zone and is delegated to by the existing native
adapter only for new window creation. Its stored window/cadence shape does not change; historical
windows are not recalculated. A paycycle never implicitly defines a statutory overtime workweek.

Browser period setup reviews exact dates/zone/profile before creating a period. Standard cadence
computes the inclusive end; custom leaves it editable. Material edits invalidate review. Save one
explicit schedule record with its period, UTC boundaries and cadence; unknown legacy cadence is
not inferred from a window's length. Empty unaudited discard explicitly removes only that period's
owned cadence/plan metadata. Other profiles, periods, audits and relationships remain retained.

Keep `assessment.mjs` / configured-gross v1 unchanged for old receipts. New browser comparisons use
configured-gross v2 with retained reported source dates/zone/confirmation. A displayed timezone may
be the worker's prefilled context; it must not be described as OCR extraction. No dates are copied
into source fields from the selected window. Unknown/unconfirmed or mismatched source scope yields
notComparable, null expected gross/difference and no component directional comparisons. Preserve
confirmed paid observations. Complete work/gross-basis/rule guards still apply after dates match.

The browser can retain a noncomparable review record for a wrong/unknown period. This does not
create a completed comparable audit or authority to conclude pay is short/overpaid. The current
native confirmation flow instead refuses mismatched/unreviewed dates; its full UI/runtime remains
independent. Material source-date/context edits clear confirmation and preview. A correction is a
new record, never a rewrite. Reports show retained source facts/matching state; legacy comparisons
say separate source dates were not retained rather than fabricate them or silently reclassify them.

Web state v6 adds `paycycleSchedules` and `paycheckScopes`, validates unique/reachable references,
explicit known shapes and calculation/assessment reproduction, and commits source facts with the
new comparison atomically. Known schemas1–5 gain only empty missing metadata. Frozen synthetic v5
fixture was generated/validated with actual `ddfc768` modules, including a retained engine-v2 dated
receipt. No source dates/cadence are backfilled. Container/encryption versions stay1; native state
admission remains unsupported pending a complete financial migrator.

Verify independent Swift/Kotlin/browser calendar cases, native adapter regression source, wrong/unknown/
matching comparison scope, actual review/save/print evidence and encrypted reset/recovery. Keep
work dates distinct from payday, fixed payroll zone distinct from device timezone, and local tests
separate from native App, installed/physical PWA, provider delivery and App Store release evidence.
