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

## Correctness and data boundaries

Pay arithmetic uses exact BigInt rational operations, never binary floating point. Date/clock
arithmetic and occurrence indices use safe integer Numbers. The nineteen shared configured-pay
cases cover daily tiers, breaks, local midnight, DST, isolated/split callout minima, highest weekday
premia, separate per diem and exact-second cent boundaries. Rounding occurs by category/multiplier,
with deterministic remainder allocation. Sixteen shared configured-gross comparison cases verify
scope/review behavior. Thirteen shared fund cases independently verify separate employer
contributions, one fund-total rounding, raw statement precision, unknowns, mixed bases and
incompatible scope. The legacy-rounding case tests a saved-result review flag, not legacy-price
production or admission of native legacy snapshots.

This first web engine rejects schedules, date-specific premiums, off-schedule multipliers and legacy
production rounding. Baseline v1 and versioned effective-date v2 calculations preserve their own
historical inputs; broader weekly/agreement interactions remain unsupported.
Daily tier boundaries must resolve to whole elapsed seconds; smaller boundaries need review.
Work instants are whole seconds from 2000–2099; each entry is at most 72 elapsed hours. It does not
implement weekly entitlement, complete CBA coverage, paid-equivalent/hourly paystub mapping, complete benefit/eligibility rules,
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
version 1 with `com.streamentry.linepay.web.state` version 5. Known v1/v2/v3/v4 schemas migrate explicitly
by adding only empty fund/origin/follow-up metadata after validating all existing records; unknown fields/
versions are rejected. Reading migration does not write, advance revision, reprice wage history or invent a fund
check. `tests/fixtures/web-state-v1.json` is synthetic and was generated/validated using actual
commit `192cab9` source. Actual encrypted old-version recovery is tested in both browsers.
**Native snapshots are rejected** until
an explicit complete financial-state migrator exists. Matching encryption is not state portability.
Browser download evidence does not establish actual OS Files/iCloud delivery or two-device restore.

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
inspection-before-replacement, stale-tab conflict, narrow/dark/enlarged text and offline reload with
the real origin stopped plus a fresh no-worker negative control. Positive/offline proof uses real responses. One separate negative test aborts a module request, then
removes the route and requires a real reload with stored records unchanged.
[Playwright WebKit issue 42775](https://github.com/microsoft/playwright/issues/42775) explains why its
offline-emulation flag cannot establish this; the harness uses real server unavailability for both
engines. Installed/home-screen PWA behavior and physical browser/device behavior remain unverified.

The home-screen PNG is copied unchanged from the repository’s existing native AppIcon-1024.png; no new icon ownership or brand claim is introduced.

The local-browser GitHub workflow runs the same domain and two-browser commands on changes to this
client or shared contracts. Workflow configuration is not hosted-CI success evidence; inspect the
actual run before merging.

The 103 Node checks include nineteen pay, sixteen gross, thirteen fund and five portable-rule
fixtures, plus eight temporal prices/five refusals, bounded-input, history/migration and cipher checks. Pay/gross/fund have independent
Swift/Kotlin consumers; portable-rule fixtures currently have a Swift consumer. Shared
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
