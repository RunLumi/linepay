# ADR-0008: Bounded weekly regular-rate layer

Status: accepted as a restricted capability; broader legal coverage remains unsupported.

## Decision

LinePaycheck admits one explicit weekly layer for a complete, single-employer, covered/nonexempt hourly workweek. The worker must confirm applicability and the payroll-local workweek anchor. The layer represents qualifying hours, includable remuneration, multiple straight-time rates, explicitly classified extra-premium credits, missing-input states, and deterministic allocation of remaining premium across pay-period slices.

The layer is separate from daily tiers, pay cadence, contract workday, and paycheck comparison. It never averages hours across weeks, infers state/CBA applicability, treats per diem as universally excluded, or credits an entire overtime line. Unknown applicability, incomplete adjacent-week context, and unknown credit classification fail closed.

## Consequences

- EX-10–EX-14 are executable synthetic regressions in `WeeklyRegularRateTests`.
- `CalculationResult` can carry an explicit weekly result and reports can disclose it.
- The native review flow requires a complete-week confirmation before calculation.
- State/CBA variants, public-agency alternatives, jurisdiction matrices, and legal/source approval remain outside this capability.
- A clean weekly result is still a configured, restricted estimate, not a legal certification.
