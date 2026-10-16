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
7. Download a password-protected copy. Verify actual file delivery in the location you chose.
   Unlock/inspect a selected copy, then separately confirm replacement. Wrong passwords, unsupported
   state and concurrent writes leave current records unchanged.

## Correctness and data boundaries

Pay arithmetic uses exact BigInt rational operations, never binary floating point. Date/clock
arithmetic and occurrence indices use safe integer Numbers. The nineteen shared configured-pay
cases cover daily tiers, breaks, local midnight, DST, isolated/split callout minima, highest weekday
premia, separate per diem and exact-second cent boundaries. Rounding occurs by category/multiplier,
with deterministic remainder allocation. Sixteen shared configured-gross comparison cases verify
scope/review behavior; the legacy-rounding case tests a saved-result review flag, not legacy-price
production or admission of native legacy snapshots.

This first web engine rejects schedules, date-specific premiums, off-schedule multipliers and legacy
production rounding. It supports one confirmed snapshot per period, not effective-date transitions.
Daily tier boundaries must resolve to whole elapsed seconds; smaller boundaries need review.
Work instants are whole seconds from 2000–2099; each entry is at most 72 elapsed hours. It does not
implement weekly entitlement, complete CBA coverage, paid-equivalent/hourly paystub mapping, benefits,
OCR/agreement imports, voice, evidence originals, resolution/PDF reports, commerce or localization.
These remain part of the full v2 objective, not silently waived by this preview.

IndexedDB stores one versioned state with revision-checked atomic replacement. A write succeeds only
on transaction completion, requesting strict durability; the app cannot guarantee physical disk or
browser retention. Unknown formats/fields, conflicting definitions for one rule identity/version and changed saved
calculations/assessments fail closed.
Future engine versions must retain readable historical semantics or implement an explicit migration;
never change a saved result silently. Limits: 8 MiB payload, 100 profiles/periods, 10,000 work records
including audit snapshots and 1,000 checks. State validation independently reproduces same-version
receipts without overwriting them.

Backups use the [shared AES-GCM/PBKDF2 envelope](../../shared/contracts/backup/README.md), fresh random
salt/nonce and fixed bounded derivation parameters. Passwords are used transiently and not written
to local state. The encrypted JSON payload is deliberately `com.streamentry.linepay.web.snapshot`
version 1 with `com.streamentry.linepay.web.state` version 1. **Native snapshots are rejected** until
an explicit complete financial-state migrator exists. Matching encryption is not state portability.
Browser download evidence does not establish actual OS Files/iCloud delivery or two-device restore.

## Real browser verification

Use the pinned `requirements-test.txt` in an isolated developer Python environment with the selected
browser available. This
repository does not install runtimes automatically. The harness starts/stops its own ephemeral
loopback origin, uses synthetic data and the public backup-fixture password, and saves captures and
reports to ignored `.build/web-e2e/`:

```bash
BROWSER=chromium CHROMIUM_EXECUTABLE=/path/to/chrome python3 apps/web/tests/browser_e2e.py
BROWSER=webkit python3 apps/web/tests/browser_e2e.py
```

It covers actual forms, immutable history, downloaded encrypted recovery, wrong-password refusal,
inspection-before-replacement, stale-tab conflict, narrow/dark/enlarged text and offline reload with
the real origin stopped plus a fresh no-worker negative control. There is no response interception.
[Playwright WebKit issue 42775](https://github.com/microsoft/playwright/issues/42775) explains why its
offline-emulation flag cannot establish this; the harness uses real server unavailability for both
engines. Installed/home-screen PWA behavior and physical browser/device behavior remain unverified.

The home-screen PNG is copied unchanged from the repository’s existing native AppIcon-1024.png; no new icon ownership or brand claim is introduced.

The local-browser GitHub workflow runs the same domain and two-browser commands on changes to this
client or shared contracts. Workflow configuration is not hosted-CI success evidence; inspect the
actual run before merging.
