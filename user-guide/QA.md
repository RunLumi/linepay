# User-guide verification status

Reviewed September 6, 2026. This file is an internal handoff and is not under Hugo `content/`; it is not published.

## Current disposition

**Validated locally at the final review candidate. Not deployed yet.**

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

CSS fixture tests exercise real Chromium with authored CSS and small synthetic HTML fixtures. They do **not** constitute a Hugo build, a full-page visual review, successful local search on generated pages, or site E2E validation.

## Blocked / not yet run

The inspected User guide workflow run 34011449452 failed before runner assignment. Its check job 101427889291 had `runner_id: 0` and an empty steps array; no site build or test step executed. The underlying account/runner rejection reason could not be retrieved through the available connector. Do not describe it as a confirmed billing problem.

The inspected PR workflow still failed before runner assignment, so hosted CI remains unverified. The local gates above were run from the review candidate using checksum-verified Hugo 0.165.0 and the pinned Playwright dependency. The generated-site screenshots/results are retained in `.qa/` for this review worktree and are not committed.

Live hosting, public URL, custom-domain behavior, and provider response headers remain unverified until Pages is enabled and the first deployment completes.

## Before publishing

After merge, enable GitHub Pages with the repository Actions variable `USER_GUIDE_PAGES_ENABLED=true`, run the `User guide` workflow, inspect the deployed URL, and record its deployment URL and response status here or in the PR.

Only after validation, merge the documentation change and deliberately configure the selected hosting destination using README.md. GitHub Pages deployment remains disabled unless `USER_GUIDE_PAGES_ENABLED=true`. Cloudflare requires its Pages project connection and stable production `GUIDE_BASE_URL`. Do not assume either host was provisioned by this code change.
