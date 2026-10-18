# User-guide verification status

Reviewed September 6, 2026. This file is an internal handoff and is not under Hugo `content/`; it is not published.

## Current disposition

**Published to Cloudflare Pages from reviewed `main`; Git-connected automatic deployments are enabled. Hosted GitHub Actions remains unavailable.**

PR: https://github.com/streamentry/linepay/pull/36

The guide has 20 authored task pages plus home/search, custom Hugo layouts and design tokens, local search, and deployment configuration for GitHub Pages and Cloudflare Pages. App behavior was checked against the source baseline documented in CONTENT-SOURCES.md. No native app code, bundle identity, repository visibility, or DNS settings were changed. Cloudflare Pages build and repository settings were configured for the requested automatic deployment.

## Evidence actually obtained

- Read current app screens, storage/audit behavior and product contracts before writing the user instructions; source coverage and material discrepancies are recorded in CONTENT-SOURCES.md.
- Corrected the workflow's initial YAML command quoting error.
- Reproduced CSS specificity defects: explicit/system dark appearance overrode print colors and prevented supporting text from strengthening in increased-contrast mode.
- Fixed those selectors without changing the default palette. A local copy of the stylesheet was verified against its Git blob SHA before and after the fix.
- Executed `CHROMIUM_PATH=/usr/bin/chromium python3 user-guide/scripts/test-css.py` on the corrected stylesheet: all six CSS fixture states passed (system-dark, explicit dark and light; print and increased contrast). The corrected CSS blob is `df4966c8b9d7bb992731803eb4a2415a07bc0880`.
- Replaced an unexplained decorative `01 / 03` in the sample ledger with meaningful USD context.
- Updated the Hugo 0.165.0 configuration from deprecated `languageCode` to `locale`; updated data access from deprecated `.Site.Data` to `hugo.Data`. With `--panicOnWarning`, both were real build blockers rather than cosmetic warnings.
- Ran `bash scripts/check.sh` with Hugo 0.165.0: both `/` and `/linepay/` builds passed, producing 23 validated HTML pages and all 20 search entries; link, fragment, asset, metadata, leakage and search-index checks passed.
- Ran the CSS fixture suite: all six print/increased-contrast states passed across system-dark, explicit dark and light appearance.
- Ran the generated-site Chromium smoke suite: 15 page/configuration checks passed, including desktop/mobile layouts, dark appearance, local search, mobile disclosure navigation, no-JavaScript reading, keyboard skip navigation, and print layout.
- Built the exact merged source `ce7d0dce02c8312f94beed7ec61e0d11dcdc45e5` with Hugo 0.165.0 using the production base URL, then ran the generated-site validator against `https://linepaycheck-guide.pages.dev/`.
- Created Cloudflare Pages project `linepaycheck-guide` and deployed production deployment `6dd92bb0-abc7-4f88-be25-b20a5629016d` from branch `main`, source `ce7d0dc`.
- Connected the Pages project to `streamentry/linepay`, set `main` as the production branch, enabled automatic deployments, and configured `user-guide` / `bash scripts/build.sh` / `public`.
- Set production `HUGO_VERSION=0.165.0` and `GUIDE_BASE_URL=https://linepaycheck-guide.pages.dev/`; set preview `HUGO_VERSION=0.165.0` so Cloudflare uses the validated Hugo release in both environments.
- Retried the first Git-connected production build after saving those variables. Deployment `d95a8204-d339-4b62-90ec-d6dfd29c57e1` succeeded from `main`, source `445234e`.
- Merged the deployment documentation in PR #52; Cloudflare automatically deployed merge commit `75e01e7` as production deployment `c401e09f-f340-4064-9cd0-318f4a6e0048`, which succeeded. Later documentation-only merges also produced successful production builds.
- Read back `https://linepaycheck-guide.pages.dev/`, `/backup-and-restore/`, `/search/`, `/robots.txt`, and an unknown route. The first four returned HTTP 200; the unknown route returned the authored HTTP 404. The live index has 20 entries, including Backup and restore.
- Verified live `Content-Security-Policy`, `Permissions-Policy`, `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, and `X-Frame-Options: DENY` headers on the public root.
- Verified the live root after the Git-connected deployment returned HTTP 200 with the expected guide navigation and production security headers. Cloudflare currently lists `docs.linepaycheck.com` as an additional production alias.

CSS fixture tests exercise real Chromium with authored CSS and small synthetic HTML fixtures. They do **not** constitute a Hugo build, a full-page visual review, successful local search on generated pages, or site E2E validation.

## Blocked / not yet run

The inspected User guide workflow run 34011449452 failed before runner assignment. Its check job 101427889291 had `runner_id: 0` and an empty steps array; no site build or test step executed. The underlying account/runner rejection reason could not be retrieved through the available connector. Do not describe it as a confirmed billing problem.

The inspected PR workflow still failed before runner assignment, so hosted CI remains unverified. The local gates above were run from the review candidate using checksum-verified Hugo 0.165.0 and the pinned Playwright dependency. The generated-site screenshots/results are retained in `.qa/` for this review worktree and are not committed.

The Cloudflare Pages project is `linepaycheck-guide` at
`https://linepaycheck-guide.pages.dev/`, connected to `streamentry/linepay` with
automatic production deployment from `main`. The project currently lists
`docs.linepaycheck.com` as an additional production alias. No DNS, repository
visibility, Worker, Pages Function, or secret was changed by this setup.

The default Pages URL is live. Custom-domain behavior, physical accessibility testing, and a successful hosted GitHub Actions run remain separate evidence gaps.

## Before publishing

For a future release, merge the reviewed guide change to `main`, watch the
Cloudflare Pages deployment for that commit, inspect the deployed URL and headers,
then append the new production deployment ID and response status here or in the PR.

GitHub Pages remains disabled because the current private-repository plan does not support it. Cloudflare Git integration is the selected host; future content changes become public only after the automatic production build succeeds.


## October17,2026 local v2 candidate check

The candidate now builds with workspace-extracted official Hugo0.165.0 (verified package checksum;
no installer/global installation). `scripts/check.sh` passed both `/` and `/linepay/`:24 HTML pages,
21 search entries, internal fragments/assets, deterministic search,58 source reviews and4 retained
screenshot-provenance checks. Support copy now distinguishes optional v2 backup protection from
unprotected copies and says never to send a backup password. This is a local candidate, not deployment.

The real Chromium smoke run first failed the old no-JavaScript browse-count assertion of20; the
new benefits page makes the current count21. Corrected that specific inventory expectation, added
benefits/support pages in each viewport, asserted the new password guidance, and remove stale success
receipts before each run. Final **21 page/configuration checks passed**, with desktop/mobile/small-dark
overflow checks, mobile navigation, search, persisted dark preference, no-JS reading, keyboard skip
link and print layout. Synthetic artifacts: `.qa/browser/`; log
`/private/tmp/linepay-v2-crew-guide-browser-final.log`. No network success response was mocked.

Native crew-file source and SDK compilation do not verify the actual iOS/Files workflow. Its new
instructions remain internal until native App tests, Simulator/physical provider transfer and visual/
accessibility acceptance. This paragraph does not revise the historical September deployment receipts.


## October17 weekly-review candidate guidance

Updated pay-rules/supported-rules with a development-preview label, fixed168-hour employer-boundary
review, explicit remuneration/credit classification and the fact that the review is unsaved/separate
from Pay. Source freshness now covers59 mapped files. Root/project builds remain24 HTML pages and
21 search entries each. This is candidate guidance; native interaction and accessibility acceptance
is pending and no new native screenshot was invented.

Expanded actual Chromium checks to both weekly guidance pages in desktop/mobile/small-dark layouts.
The first new assertion differed only on Hugo's typographic apostrophe; normalize that character
before asserting the same visible statement. Final **27 page/configuration checks passed**, with
navigation/search/no-JS/keyboard/print controls, log
`/private/tmp/linepay-v2-weekly-guide-browser-final.log`. Source/policy text and guide rendering do not
establish native App/weekly-to-paycheck mapping or public release.


## October 17 assessment-v4 candidate guidance

Candidate audit/history/report/expected-pay/import guidance distinguishes active re-review from
preserved earlier weekly comparisons. View recorded comparison is described only where a saved
revision exists. No new native screenshot or successful native PDF/migration receipt is claimed.

Pinned Hugo root/project checks pass24 HTML pages/21 search entries each,59 targeted source
reviews and4 existing screenshot-provenance checks. Actual local Chromium now checks the changed
pages as well: **42 page/configuration checks passed**, including mobile/dark overflow, real
navigation/search, no-JS, keyboard skip and print controls. Log
`/private/tmp/linepay-v2-assessment-guide-browser.log`; no publication occurred. Source/SDK checks
and guide rendering do not establish native App/VoiceOver/PDF or verified weekly allocation.
