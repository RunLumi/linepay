# User-guide verification status

Reviewed September 6, 2026. This file is an internal handoff and is not under Hugo `content/`; it is not published.

## Current disposition

**Implemented, awaiting full generated-site validation. Not deployed.**

PR: https://github.com/streamentry/linepay/pull/36

The guide has 20 authored task pages plus home/search, custom Hugo layouts and design tokens, local search, and deployment configuration for GitHub Pages and Cloudflare Pages. App behavior was checked against the source baseline documented in CONTENT-SOURCES.md. No native app code, bundle identity, production domain, hosting account settings, or repository visibility was changed.

## Evidence actually obtained

- Read current app screens, storage/audit behavior and product contracts before writing the user instructions; source coverage and material discrepancies are recorded in CONTENT-SOURCES.md.
- Corrected the workflow's initial YAML command quoting error.
- Reproduced CSS specificity defects: explicit/system dark appearance overrode print colors and prevented supporting text from strengthening in increased-contrast mode.
- Fixed those selectors without changing the default palette. A local copy of the stylesheet was verified against its Git blob SHA before and after the fix.
- Executed `CHROMIUM_PATH=/usr/bin/chromium python3 user-guide/scripts/test-css.py` on the corrected stylesheet: all six CSS fixture states passed (system-dark, explicit dark and light; print and increased contrast). The corrected CSS blob is `df4966c8b9d7bb992731803eb4a2415a07bc0880`.
- Replaced an unexplained decorative `01 / 03` in the sample ledger with meaningful USD context.

CSS fixture tests exercise real Chromium with authored CSS and small synthetic HTML fixtures. They do **not** constitute a Hugo build, a full-page visual review, successful local search on generated pages, or site E2E validation.

## Blocked / not yet run

The inspected User guide workflow run 34011449452 failed before runner assignment. Its check job 101427889291 had `runner_id: 0` and an empty steps array; no site build or test step executed. The underlying account/runner rejection reason could not be retrieved through the available connector. Do not describe it as a confirmed billing problem.

The local environment has no Hugo binary and could not resolve external package/download hosts. Therefore these checks remain unverified until executed in a working environment:

- Hugo builds at `/` and `/linepay/`.
- Generated-page link, fragment, asset, metadata, and search-index validation.
- Real-index search unit tests.
- Full generated-site Chromium smoke checks and screenshot review.
- Live hosting, public URL, custom-domain behavior, and provider response headers.

The checked-in scripts and workflow define these gates; their existence is not evidence that they passed. Subsequent source changes need their own final-commit verification.

## Before publishing

Resolve the GitHub runner-start issue or use a local environment with Hugo 0.165.0. Run `bash user-guide/scripts/check.sh`, the CSS regressions, and `browser-smoke.py`; inspect the screenshots and fix any generated-site errors. Record the passing commit and evidence here or in the PR.

Only after validation, merge the documentation change and deliberately configure the selected hosting destination using README.md. GitHub Pages deployment remains disabled unless `USER_GUIDE_PAGES_ENABLED=true`. Cloudflare requires its Pages project connection and stable production `GUIDE_BASE_URL`. Do not assume either host was provisioned by this code change.
