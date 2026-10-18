# Effective-date configured-pay fixtures v1

[Shared contracts](../README.md) · [Configured-pay subset](README.md)

`effective-date-v1.json` contains eight independently calculated synthetic prices and five refusals,
consumed by Swift, Kotlin and the browser v2 engine. It extends, rather than replaces, the original
nineteen configured-pay cases. No fixture establishes source rights, legal applicability, statutory
coverage, device behavior or complete platform parity.

Each case has one baseline, explicit payroll IANA timezone, actual UTC work/break instants, and
changes with an ISO local effective date and immutable agreement ID/version. A change begins at
midnight in the work's recorded payroll-local date context, never the device's current timezone.
All versions keep one agreement ID, currency and compatible rounding scale/mode; duplicate dates,
reused versions, currency conversion and incompatible policies refuse. The browser subset retains
its explicit unsupported schedule/date/off-schedule/legacy-policy boundaries.

Price each actual segment under the selected local-date snapshot, preserve the original work ID,
actual seconds and applied version/rate, and use the highest applicable configured multiplier.
Actual daily positions reset on payroll-local dates. Unpaid breaks remain excluded across the
boundary. Flat per diem uses the selected snapshot for each actually worked local date; absence is
unconfigured, not a legal waiver. A binding physical-callout minimum crossing a change refuses
rather than split/guess guarantees. Satisfied minima do not invent paid or worked time.

Rounding still aggregates category/multiplier numerators with the compatible policy across rate
versions before division/rounding. Independent example: one second at 18/hour plus one at 54/hour
is exactly 0.02; rounding each version separately to 0.01 + 0.02 would incorrectly create 0.03.
Keep deterministic remainder allocation and applied rule references.

Cases cover rate/allowance and daily-threshold transitions, one interval through local midnight,
a break straddling the boundary, three versions, cross-version half cents, a New York fall-back
night and a future change that does not reprice earlier work. Refusals cover duplicate dates,
currency/mode mismatch, version reuse and binding callout uncertainty. Wider rules, timezones,
regular-rate/weekly interactions, source review and full agreement coverage remain separate work.

Verify native Swift through `SharedTimelineContractTests` / `agent-verify.sh quick`, Kotlin through
`SharedTimelineContractTest` using [Android commands](../../../apps/android/README.md), and browser
through `node --test apps/web/tests/timeline.test.mjs`. Runtime/state/browser evidence is separate.
