# ADR 0028: browser earnings and hours with retained source mapping

Status: v2 candidate implementation, October 18, 2026. Local browser evidence is recorded in the
[execution checkpoint](../plan/v2-execution.md). This does not complete the PWA, native interchange,
Android, source/legal review, physical installation or release gates.

The browser previously compared gross and a separate allowance. A matching total could not explain
regular/overtime/double-time earnings or hours. New explicit reviews use comparison producer
`linepay.web.configured-lines/4`; existing gross producers1–3 remain unchanged for receipt replay.

Workers choose full hourly rates or base plus extra premium, actual worked hours or paid
equivalents, and callout guarantees separate or included in hourly lines. Typed optional values are
worker-confirmed observations. Blank is unknown; explicit zero is a known value. An optional complete
breakdown assertion checks the entered nonoverlapping earnings against the declared gross basis.
It does not infer a pay rule, exemption, employer, workweek allocation or legal completeness.

New comparisons derive exact line evidence from the receipt's frozen work and saved rule plan using
the retained v2 calculation kernel. A baseline without a dated plan uses its explicit baseline
snapshot with no changes. This is a new explicit review, not migration-time repricing. Before using
the trace, require category/work/date/multiplier/amount/reference/row identities and wage/allowance
totals to reproduce the recorded calculation. The transient empty-plan execution identifier is not
stored or presented as a worker's source reference. All19 admitted shared configured-pay ledgers
exercise this correlation. Existing calculation producers and their output shapes are unchanged.

Premium-only base sums exact hourly rate × paid seconds within each original category/multiplier
bucket, then divides/rounds once; extra premium is the bucket's rounded gross minus that base.
Never derive cash from displayed decimal hours. Dated rates remain in their corresponding work
fragments. A synthetic60seconds at58.50/hour gives0.98 base and, at1.5×,0.48 extra within1.46 gross.
A1second fragment at1 plus1second at17 gives exactly0.005 base before cent rounding.

Hours derive from exact seconds and remain separate from money. Expected hours are displayed to
four decimals, with a separately rounded half-up four-decimal difference computed from the exact
quantity. Wage rounding modes must not change the hours verdict. Original clock facts/component
links remain available. Confirmation of actual work excludes guarantee top-ups; paid equivalents
include them only when mapped into hourly lines. No full-period directional result is produced for
unconfirmed or mismatched paycheck source dates. Unknown guarantee/layout/hours mapping, unusual
multipliers, unresolved weekly context and conflicting earnings require review. Matching gross
cannot cancel offsetting line differences.

State8 adds bounded append-only `paycheckLineScopes`, each linked to one compatible audit and period.
Validation reproduces each receipt with its original work, rule plan, weekly-prefix context and
line facts. Missing, duplicated, changed, orphaned or future fields refuse recovery. Schemas1–7 add
only empty line metadata without writes, revised verdicts or inferred confirmation. The v7 fixture
was generated/validated using actual3312c73 code and includes original weekly evidence and a
producer3 Needs review receipt. Financial payload/encrypted-snapshot size gates remain8MiB.

Preview writes nothing. Any material form edit removes the pending save action; confirmation
atomically appends the line facts and new receipt. Earlier copies remain frozen. Reviewed reports
include only the chosen receipt, its explicit mapping, component references and separate hours/money
units; optional private details remain default-off. Downloaded report/encrypted recovery and offline
shell paths use the real browser. They do not establish OS Files delivery or native snapshot support.

The enlarged320px Chromium run exposed the existing work-form mobile grid's automatic minimum:
date/time controls stretched the column to337px. Use a zero-minimum fractional column so native
controls stay within the viewport. Preserve text size and controls; do not hide overflow. The
inspected form retains visible labels, explicit units and source limitations in dark/enlarged text.
No runtime dependency, account, backend, collector or store write is added.
