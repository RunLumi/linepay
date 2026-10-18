# LinePaycheck local browser client

Development preview for the owner's all-stage v2 request. This is an implemented local workflow,
not yet full native feature parity, a deployed service, a released/installed PWA or a legal-pay audit.
[Execution evidence](../../docs/plan/v2-execution.md) tracks the remaining delivery work.

From the repository root, with Node 22+ and Python 3:

```bash
node --test apps/web/tests/*.test.mjs
python3 -m http.server 8769 --bind 127.0.0.1 --directory apps/web
```

Open `http://127.0.0.1:8769/`. Production requires HTTPS. The client has no package install, external
font, runtime dependency, LinePaycheck account, pay-data backend, analytics collector or remote OCR.
The manifest and service worker provide an offline shell. Close open tabs to adopt a newer shell;
updates do not force an in-progress form to reload. Browser storage can be cleared/evicted or be
transient in private browsing. Persistent storage is a user-requested hint, not a recovery copy.

## Cloudflare release

The [static web release runbook](../../docs/release/web-worker.md) packages runtime files into a
separate allowlisted directory and uses pinned Wrangler development tooling. The production origin
is `https://app.linepaycheck.com`, separate from the marketing site. Configuration and local tests
do not prove a live release; dated deployment evidence belongs in that runbook's release receipts.
Cloudflare delivers public assets and receives ordinary request metadata; pay records remain local.
Keep the origin stable: browser records do not move with DNS redirects. Before a move, export a
protected web backup, verify its delivery, unlock/inspect it at the destination and explicitly
replace there. Preserve the old origin/data until recovery is confirmed.

## Working journey

1. Explicitly confirm a new pay profile. Optional fields left blank remain unconfigured.
2. Start a period with inclusive dates and a confirmed IANA payroll timezone. Its rules are copied;
   a later profile never changes an existing period. Empty unaudited periods may be discarded.
3. Log actual start/end clocks and any explicitly classified unpaid break. Repeated DST clocks
   require first/second occurrence; nonexistent clocks are rejected. Each UI callout is one separate
   physical event. Segmented event grouping is not exposed by this first editor.
4. Review expected cash wages and separate per diem, component facts and saved references.
5. Confirm paycheck gross, gross basis, work completeness and exact period matching. Preview does
   not save. Separately confirm to append an immutable check; editing work never changes that check.
6. Close a period to freeze its work/rules/calculation. History keeps the original calculation and
   check snapshots. The app can append a later confirmed paycheck check to the same closed facts.
7. Open Benefits to check a separate fund period. Enter explicit eligible segments, bases/rates and
   effective-scope confirmations. Review before saving. A later statement or correction appends a
   new revision, retaining the original unknown/confirmed observations and source-reference note.
8. Download a password-protected copy. Verify actual file delivery in the location you chose.
   Unlock/inspect a selected copy, then separately confirm replacement. Wrong passwords, unsupported
   state and concurrent writes leave current records unchanged.
9. Review optional device-local activity milestones. They live in a separate IndexedDB database,
   remain outside financial backups and leave only through a separate manual preview/download.

## Correctness and data boundaries

Pay arithmetic uses exact BigInt rational operations, never binary floating point. Date/clock
arithmetic and occurrence indices use safe integer Numbers. The nineteen shared configured-pay
cases cover daily tiers, breaks, local midnight, DST, isolated/split callout minima, highest weekday
premia, separate per diem and exact-second cent boundaries. Rounding occurs by category/multiplier,
with deterministic remainder allocation. Twenty-nine shared earnings/hour comparison cases cover
full-rate and premium-only lines, actual-work/paid-equivalent hours, explicit callout mapping,
four-place hour presentation and exact-second differences with source-component traces. Sixteen
shared configured-gross comparison cases verify scope/review behavior. Thirteen shared fund cases
independently verify separate employer
contributions, one fund-total rounding, raw statement precision, unknowns, mixed bases and
incompatible scope. The legacy-rounding case tests a saved-result review flag, not legacy-price
production or admission of native legacy snapshots.

This first web engine rejects schedules, date-specific premiums, off-schedule multipliers and legacy
production rounding. Baseline v1 and versioned effective-date v2 calculations preserve their own
historical inputs; broader weekly/agreement interactions remain unsupported.
Daily tier boundaries must resolve to whole elapsed seconds; smaller boundaries need review.
Work instants are whole seconds from 2000–2099; each entry is at most 72 elapsed hours. It does not
implement weekly entitlement, complete CBA coverage, complete benefit/eligibility rules,
OCR/agreement imports, voice, evidence originals, complete report/physical print parity, commerce or localization.
These remain part of the full v2 objective, not silently waived by this preview.

IndexedDB stores one versioned state with revision-checked atomic replacement. A write succeeds only
on transaction completion, requesting strict durability; the app cannot guarantee physical disk or
browser retention. Unknown formats/fields, conflicting definitions for one rule identity/version and changed saved
calculations/assessments fail closed.
Future engine versions must retain readable historical semantics or implement an explicit migration;
never change a saved result silently. Limits: 8 MiB payload, 100 profiles/periods, 10,000 work records
including audit snapshots and 1,000 paycheck checks. Fund history is bounded to 100 checks,
100 revisions per check (1,000 total) and 10,000 eligibility segments; the editor allows 100 segments
per revision. State validation independently reproduces same-version
receipts without overwriting them.

Backups use the [shared AES-GCM/PBKDF2 envelope](../../shared/contracts/backup/README.md), fresh random
salt/nonce and fixed bounded derivation parameters. Passwords are used transiently and not written
to local state. The encrypted JSON payload is deliberately `com.streamentry.linepay.web.snapshot`
version 1 with `com.streamentry.linepay.web.state` version 8. Known v1/v2/v3/v4/v5/v6/v7 schemas migrate explicitly
by adding only empty fund/origin/follow-up metadata after validating all existing records; unknown fields/
versions are rejected. Reading migration does not write, advance revision, reprice wage history or invent a fund
check. `tests/fixtures/web-state-v1.json` is synthetic and was generated/validated using actual
commit `192cab9` source. Actual encrypted old-version recovery is tested in both browsers.
**Native snapshots are rejected** until
an explicit complete financial-state migrator exists. Matching encryption is not state portability.
Browser download evidence does not establish actual OS Files/iCloud delivery or two-device restore.

## Device-local activity and manual diagnostics

The closed local vocabulary records first/open observations, profile setup, new work, visible
expected pay, started/saved paycheck checks, comparable confirmed checks, a second comparable check,
and explicit financial-backup restores. There are no app-install, purchase, trial, revenue, account,
employer, union, payroll-date, amount, document or free-text events. Record identities are accepted
only in a closed local identity shape and stored as internal SHA-256 deduplication digests; hashing
is not anonymity. No activity is sent to a server or included in a financial backup.

The separate database keeps lifetime totals and up to 400 observed UTC days, caps its digest set at
20,000, and fails closed on unknown/corrupt state. Observation failure never rolls back a saved pay
record. The user can pause recording, clear only activity, or review the exact diagnostic JSON before
downloading it. The export contains milestone counts, usage days and recording status; it can still
be personal and is not a pay-data backup. Browser/device backup behavior depends on platform settings
and has not been independently verified. Clearing all local data clears activity first, then pay
records; if activity cannot be cleared, pay data is left intact. Restored pay backups never backfill
activity history.

## Real browser verification

Use the pinned `requirements-test.txt` in an isolated developer Python environment with the selected
browser available. The local harness does not install runtimes automatically. The harness starts/stops its own ephemeral
loopback origin, uses synthetic data and the public backup-fixture password, and saves captures and
reports to ignored `.build/web-e2e/`:

```bash
BROWSER=chromium CHROMIUM_EXECUTABLE=/path/to/chrome python3 apps/web/tests/browser_e2e.py
BROWSER=webkit python3 apps/web/tests/browser_e2e.py
```

It covers actual wage/fund forms, immutable revisions, material-edit confirmation invalidation,
downloaded encrypted recovery, old-version migration, wrong-password refusal,
inspection-before-replacement, stale-tab conflict, Diagnostics focus/Enter flow,
narrow/dark/enlarged text and offline reload with
the real origin stopped plus a fresh no-worker negative control. Positive/offline proof uses real responses. One separate negative test aborts a module request, then
removes the route and requires a real reload with stored records unchanged.
[Playwright WebKit issue 42775](https://github.com/microsoft/playwright/issues/42775) explains why its
offline-emulation flag cannot establish this; the harness uses real server unavailability for both
engines. Diagnostics moves focus to its labeled recording setting and supports Enter to open the
exact-copy preview; this is not a VoiceOver or assistive-technology certification.
Installed/home-screen PWA behavior and physical browser/device behavior remain unverified.

The home-screen PNG is copied unchanged from the repository’s existing native AppIcon-1024.png; no new icon ownership or brand claim is introduced.

The local-browser GitHub workflow runs the same domain and two-browser commands on changes to this
client or shared contracts. Workflow configuration is not hosted-CI success evidence; inspect the
actual run before merging.

The 216 Node checks include nineteen pay, sixteen gross, twenty-nine earnings/hour, thirteen fund,
seven local-activity boundaries, five portable-rule fixtures and a light/dark contrast audit, plus
eight temporal prices/five refusals, bounded-input,
history/migration and cipher checks. Pay/line/gross/fund have independent Swift/Kotlin consumers;
portable-rule fixtures currently have a Swift consumer. Shared
fixtures do not establish full platform/legal parity. Fund eligibility is never inferred from wage
hours or overtime; optional source notes remain worker-provided, without original-file or third-party
verification. Fund differences never change cash wages or the wage verdict. Fund arithmetic refuses more than 38 significant digits rather than silently rounding inputs;
large exact internal totals are not reparsed through the bounded entry parser. Statement differences
retain actual decimal precision rather than using the wage-comparison cent rounding policy.


## Crew rule drafts

Pay rules includes a [rules-only draft workflow](../../shared/contracts/templates/README.md).
Preview exact JSON and choose whether to include monetary values; the default omits hourly/per-diem
amounts and never copies work/paycheck/fund/evidence records or private profile IDs. This is an
unencrypted, potentially identifying file, not a verified agreement or anonymous export. Review
rights/title/conditions before choosing a recipient yourself. The app sends nothing to a recipient.

Import inspection creates no profile. Confirm your own rate, allowance decision, rule applicability,
currency and rounding before saving a fresh profile. Old periods retain their snapshots. Web state
v3 retains the complete admitted draft plus the recipient's actual monetary choices and confirmation
flags atomically with that profile. Recover them through protected manual backups. The synthetic
v2 migration fixture was generated/validated with actual `3edf4bd` code; both old schemas are also
opened through actual encrypted browser recovery. Source and recipient histories remain separate.

This browser workflow and shared Swift codec do not establish native iOS Files/UI/persistence,
Android support, physical-device transfer, source rights or actual crew adoption. Those remain
separate acceptance work in the original v2 goal. No official preset or agreement library is added.


Startup uses a guarded bootstrap. A failed app-module load shows a reload action and preserves
stored records; it does not pretend storage is still opening or silently reset it. The test origin
uses a larger connection queue for parallel modules. Source-bound browser reports are fresh per
run, record explicit pass/fail and a runtime SHA-256, and retain per-context/network diagnostics on
failure. A stale prior green report is never retained as the current result.


## Saved-check follow-up and evidence reports

Each saved paycheck check has worker-reported follow-up and a report workflow. Statuses and notes
append to that exact check; they never correct its wages, comparison verdict or claim recovered
money. Record another comparison for a later paycheck. Nothing is sent to an employer or union.
Follow-up was introduced in web state v4; current v5 retains it in protected backups. Prior imports add no invented history.
The v3 fixture was generated/validated with actual `5a42523` source.

The default evidence copy uses saved period/zone, amounts, confirmation, configured rules and
engine references. It remains sensitive and is not anonymous. Follow-up notes, detailed recorded
clocks and crew-draft text are separate opt-ins, scoped to that check. Preview the exact sandboxed
HTML, then download that copy or invoke Print / save PDF for the report frame. Changing an option
requires another review. Scripts/network are disabled in the document, all values are escaped,
fixed inline CSS is hash-admitted and prepared Blob URLs are disposed on navigation/mutation.
Reports above 2 MiB refuse rather than silently omit details. No originals are attached.

Actual Chromium tests render downloaded HTML to PDFs and check privacy, amounts, Unicode text,
pagination and the long-note tail. WebKit tests actual HTML preview/download and print-media layout.
These do not establish actual OS print/save-provider or physical delivery. Native PDF/report UI
and full native-state interchange remain separate gates; this browser work does not certify them.


## Confirmed effective-date plans

An open period can review/apply complete confirmed profiles from explicit local dates. The baseline
stays intact. Each saved revision is retained; changes require compatible currency/rounding and
fresh immutable rule versions. Preview shows the period timezone, current/proposed wages and
allowances. Material edits clear that review. A later revision can return to baseline or move a
change without repricing earlier audits. Closed periods retain their final plan.

Legacy `linepay.web.configured-pay/1` still reproduces old checks. Dated calculations use `/2`, exact
quantities/applied rates, rule snapshots and an immutable plan ID. Reports resolve the selected
saved plan rather than the latest one. Web state v5 adds only empty plan metadata when migrating
prior schemas; the v4 fixture was generated/validated with actual `f7cbe82` code. Unknown/missing
references fail closed. Encrypted recovery retains every plan and both old/new receipts.

The [temporal corpus](../../shared/contracts/payroll/effective-date-v1.md) independently verifies eight
prices/five refusals in Swift, Kotlin and browser, including local midnight/breaks, DST, per diem,
changed daily tiers and cross-version cent aggregation. This does not establish every agreement,
regular-rate interaction, timezone or device. Binding callout uncertainty refuses instead of guessing.
Pending mutations disable the previous controls after capturing their values so typing a second
shift cannot be silently lost when the first save refreshes the form.


## Calendar setup and paycheck date scope

Review weekly, biweekly, semi-monthly (1–15/16–end) or custom dates before creating a period.
Standard windows derive the inclusive last date from the fixed payroll zone; clock changes do not
turn them into fixed-hour spans. Cadence does not configure federal/statutory weekly overtime.
The shared Swift/Kotlin/browser [calendar corpus](../../shared/contracts/paycycles/README.md) covers fifteen
independent windows/ten refusals, including a skipped midnight that must not shift the next boundary.

New comparisons retain source work-period dates/context/confirmation separately from the ledger.
Source date fields start blank. Use the dates covered by the paycheck, not payday. Unknown,
unconfirmed or mismatched periods can be retained as noncomparable review records, with no expected
gross/directional difference. Only confirmed matching dates/context permit the existing scoped
comparison, subject to complete work, basis and rule-review guards. Editing dates/context requires
re-confirmation. Legacy configured-gross v1 results stay as recorded and disclose missing separate
source facts; new guarded reviews use v2.

Web state v6 introduced schedule/source-period metadata; v7 retains it with its owner. Old schema1–5
imports add no inferred cadence or source dates. The v5 fixture was generated/validated using actual
`ddfc768` source. Protected reset/recovery preserves wrong/unknown/matching reviews distinctly.
This browser record flow is not the native App confirmation path, native runtime/device proof or
legal verification; final release and physical/provider delivery gates remain open.


## Complete-workweek references (development preview)

Open Workweeks, choose the employer's source periods, enter its exact start instant/offset and
payroll timezone, and review the fixed168-hour end. Confirm one employer and complete actual work.
Enter reviewed straight-time remuneration and every other cash payment/classification separately;
clock records do not invent those amounts or classify premium credit. An extra-premium credit is
only the eligible already-paid portion above base. Unknown treatment prevents calculation.

Preview saves nothing. Material changes clear review; Save reviewed workweek appends frozen clock/
rate/remuneration evidence to local history. Later work changes preserve it. Protected manual backup
includes these records and private reference notes. Selected unworked periods remain linked, not
silently discarded. Representation limits:128 reviews,2000 source/slice facts and100 payment facts
per review; amounts up to10,000,000 with8 fractional digits, and2000–2099 clock representation. They
are engineering bounds, not legal wage limits. State commits must fit the restorable8MiB snapshot.

Statev7 adds weekly reviews; v1–6 migrate only with empty missing metadata. Actual928d58c modules
produced the retained v6 fixture. Comparison engine3 captures the known weekly-review prefix and
references so a new check cannot waive indicated weekly scope. Older checks remain exactly saved,
with an earlier-context note after new evidence. No weekly amount is added to Pay or automatically
mapped/cleared against a paycheck. Native financial-state portability, full platform parity, actual
OS provider transfer, physical/installed PWA and public deployment remain separate requirements.


## Confirmed paycheck earnings and hours

New reviews can compare regular/overtime/double-time earnings and hours plus separate callout pay.
Choose each source layout explicitly: full rates versus base plus extra premium, actual work versus
paid equivalents, and guarantees separate versus included in hourly lines. Enter only values
identified on the source; blank remains unknown. A complete-breakdown assertion checks the entered
nonoverlapping earnings against gross and its stated allowance basis. Missing/unusual mapping and
weekly context can keep the result in review even with matching gross.

Premium-only base retains exact seconds through bucket rounding; hours never feed cash math.
Displayed expected hours and independent half-up hour differences use four decimals, regardless
of the wage rounding policy. The original work/rule plan and component references explain the
quantity. Preview writes nothing; changes remove the pending save consent. A later confirmation
appends a receipt and its line facts. Historical reviewed reports preserve that mapping and label
hours separately from currency.

State8 validates/reproduces line receipts and refuses changed/missing evidence. Schemas1–7 add
only empty line metadata without repricing. The synthetic v7 migration fixture was generated and
validated by actual3312c73 sources; it retains weekly evidence and its original producer3 receipt.
Both browser engines exercise actual encrypted migration/recovery, including those older records.
This is browser history compatibility; native/Android financial-state interchange remains pending.
See [ADR0028](../../docs/adr/0028-browser-confirmed-paycheck-lines-and-hours.md).
