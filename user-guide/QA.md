# User-guide verification status

Reviewed September 6, 2026. This file is an internal handoff and is not under Hugo `content/`; it is not published.

## Current disposition

**Published to Cloudflare Pages from reviewed `main`; hosted GitHub Actions remains unavailable.**

PR: https://github.com/streamentry/linepay/pull/36

The guide has 20 authored task pages plus home/search, custom Hugo layouts and design tokens, local search, and deployment configuration for GitHub Pages and Cloudflare Pages. App behavior was checked against the source baseline documented in CONTENT-SOURCES.md. No native app code, bundle identity, production domain, hosting account settings, or repository visibility was changed.

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
- Read back `https://linepaycheck-guide.pages.dev/`, `/backup-and-restore/`, `/search/`, `/robots.txt`, and an unknown route. The first four returned HTTP 200; the unknown route returned the authored HTTP 404. The live index has 20 entries, including Backup and restore.
- Verified live `Content-Security-Policy`, `Permissions-Policy`, `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, and `X-Frame-Options: DENY` headers on the public root.

CSS fixture tests exercise real Chromium with authored CSS and small synthetic HTML fixtures. They do **not** constitute a Hugo build, a full-page visual review, successful local search on generated pages, or site E2E validation.

## Blocked / not yet run

The inspected User guide workflow run 34011449452 failed before runner assignment. Its check job 101427889291 had `runner_id: 0` and an empty steps array; no site build or test step executed. The underlying account/runner rejection reason could not be retrieved through the available connector. Do not describe it as a confirmed billing problem.

The inspected PR workflow still failed before runner assignment, so hosted CI remains unverified. The local gates above were run from the review candidate using checksum-verified Hugo 0.165.0 and the pinned Playwright dependency. The generated-site screenshots/results are retained in `.qa/` for this review worktree and are not committed.

The Cloudflare Pages project is `linepaycheck-guide` at
`https://linepaycheck-guide.pages.dev/`. No custom domain, DNS, repository
visibility, Worker, Pages Function, secret, or Git integration was configured.

The default Pages URL is live. Custom-domain behavior, physical accessibility testing, and a successful hosted GitHub Actions run remain separate evidence gaps.

## Before publishing

For a future release, build against `https://linepaycheck-guide.pages.dev/`, upload
the generated output to the `linepaycheck-guide` Pages project with the reviewed
`main` commit SHA and message, inspect the deployed URL and headers, then append the
new production deployment ID and response status here or in the PR.

GitHub Pages remains disabled because the current private-repository plan does not support it. Cloudflare Direct Upload is the selected host; future content changes still require a successful build and upload before they are public.
