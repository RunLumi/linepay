# Explicit local-calendar paycycles v1

[Shared contracts](../README.md)

`calendar-v1.json` contains fourteen independent boundary cases and seven refusals consumed by
Swift `CalendarPaycycle` and browser `paycycleWindow`. It is calendar engineering evidence, not a
statutory workweek, pay-frequency law, verified agreement or legal coverage profile.

Input: weekly/biweekly/semimonthly/manual cadence, explicit start calendar date, inclusive manual
last date, and IANA payroll timezone. Weekly and biweekly advance seven/fourteen local dates, not
168/336 fixed hours. Semi-monthly means only 1–15 and 16–month-end. Manual uses both inclusive
calendar dates. The exclusive end is the first valid instant of its local ending date. A skipped
starting midnight must not carry its shifted hour into the next week. Nonexistent dates, invalid
cutoffs, reversed manual bounds or unknown timezone refuse instead of inventing a window.

Output names the start/inclusive end/exclusive end dates and exact UTC boundaries, with measured
elapsed seconds. Date arithmetic is calendar arithmetic; Number is permitted for safe integer time
metadata, never payroll money. The native helper accepts validated Gregorian dates and explicit
zone only; the browser retains its 2000–2099 representation bounds.

Cases include common/leap February, month/year boundaries, LA spring/fall half-month and weekly/
biweekly changes, a 25-hour New York manual day, and Sao Paulo's 2018 skipped midnight. That weekly
case starts at01:00 but ends at00:00 the following week (167 elapsed hours). The previous native
Calendar-add-from-start behavior could retain01:00; the adapter now uses the shared helper for new
windows only. Stored historical native windows remain unchanged.

```bash
node --test apps/web/tests/paycycle.test.mjs
bash scripts/agent-verify.sh quick
```

Pure-domain tests establish the shared boundary subset. Native App/Simulator tests, physical
browser/device behavior, broader timezone transitions and release proof remain separate gates.
