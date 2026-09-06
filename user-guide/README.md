# LinePaycheck user guide

A small, purpose-built Hugo documentation site. Public user instructions live in `content/`; internal engineering docs are not published. The guide uses the existing app logo and DESIGN.md's porcelain/graphite/Oxide palette, native system fonts, opaque ledger-like surfaces, responsive navigation, dark/system appearance, local search, accessible landmarks, and print styles.

## Run locally

Use **Hugo 0.165.0** (standard or extended). No theme submodule, Go modules, npm install, server, or database is required. Install the appropriate official binary; on Linux x86_64, `bash scripts/install-hugo.sh` installs and verifies the pinned release. Ensure its destination is on PATH.

From this directory:

```sh
hugo server --bind 127.0.0.1 --baseURL http://localhost:1313/
```

For static production output:

```sh
GUIDE_BASE_URL=https://your-documentation-domain.example/ bash scripts/build.sh
```

Output: `public/`. Never commit that generated directory. Every page is real static HTML; reading and navigation work without JavaScript. Optional appearance uses localStorage only. Search loads the site's own JSON index and never submits the query or calls a third-party service. There is no offline caching/service worker claim: a newly requested page still needs to be available from the host/browser cache.

## Verification

```sh
bash scripts/check.sh
# Optional real-browser checks (developer/CI dependencies only):
python3 -m venv .qa/venv
.qa/venv/bin/pip install -r requirements-test.txt
.qa/venv/bin/python -m playwright install chromium
.qa/venv/bin/python scripts/browser-smoke.py
```

The static gate builds both `/` and `/linepay/`, checks internal links, fragments, assets, search entries, metadata and landmarks, rejects leaked internal material, and tests real search-index relevance. Browser checks cover desktop light, mobile light, small-screen dark, search, appearance persistence, no-JS reading/navigation, keyboard skip links and printing. They retain screenshots/results in `.qa/`. These tests are not a claim of full WCAG certification or complete assistive-technology coverage. Run manual zoom, screen-reader, and device checks before a public launch.

`CHROMIUM_PATH` can select an existing Chromium executable for local QA. Node is used only by the search unit test, not to build or serve the site.

## GitHub Pages

The repository-level **User guide** workflow checks changes and uploads QA evidence. Publishing is deliberately opt-in so adding this site cannot replace an existing Pages site or unexpectedly publish a private repository's material.

1. In repository **Settings → Pages**, select **GitHub Actions** as the build/deployment source. Confirm your GitHub plan supports Pages for this repository's visibility; do not make the app repository public just to host help.
2. Set repository Actions variable **USER_GUIDE_PAGES_ENABLED** to `true`.
3. The default URL is `https://streamentry.github.io/linepay/`. For a separately configured custom domain, set **USER_GUIDE_BASE_URL** to its complete HTTPS URL with trailing slash.
4. Run the **User guide** workflow on `main`, or push a guide change. Deployment uses the `github-pages` environment and its approval rules.

Only `user-guide/public` is uploaded. A project path and a domain root are tested independently. Do not add a CNAME or change DNS until the intended domain is confirmed. The workflow config does not itself enable the GitHub Pages service or create a domain.

## Cloudflare Pages

Create a **Pages** project using Git integration and select this repository. Keep existing production sites and DNS unchanged until you select the intended help-site address.

| Setting | Value |
| --- | --- |
| Production branch | `main` |
| Root directory | `user-guide` |
| Build command | `bash scripts/build.sh` |
| Build output directory | `public` |
| `HUGO_VERSION`, Production and Preview | `0.165.0` |
| `GUIDE_BASE_URL`, Production | Your stable published help URL, e.g. `https://your-help-project.pages.dev/` |

For a non-main production branch, also set `GUIDE_PRODUCTION_BRANCH`. Preview builds use `CF_PAGES_URL` and emit noindex/robots exclusions; production requires an explicit stable base rather than a per-deployment hash URL. The `_headers` file supplies same-origin-only content security policy, no-referrer, frame protection, and disables camera/microphone/geolocation for this help site. GitHub Pages does not interpret Cloudflare's `_headers` format.

There is no Worker, Pages Function, Wrangler dependency, secret, API key, or upload handler. Limit build-watch paths to `user-guide/**` after the initial setup if desired. Cloudflare Git integration and its production/preview permissions are hosting-account actions, not performed merely by committing these files.

## Content and navigation

Edit Markdown files in `content/`. Add title, description, group, and weight front matter; update `data/navigation.json` when adding a guide. Use Hugo `relref` for internal Markdown links. The build fails when navigation references a missing page. Search uses the same authored content and excludes its own search page.

Do not copy internal pricing hypotheses, competitor research, legal-risk registers, engineering instructions, or unpublished release claims into the user guide. Preserve exact app labels and review the actual current implementation when updating instructions. `CONTENT-SOURCES.md` records the inspected baseline and content decisions.

Logo source: `apps/ios/App/Resources/Assets.xcassets/LinePaycheckLogo.imageset/LinePaycheckLogo.png`. The source image is reused by blob identity; Hugo makes small local web derivatives. A future approved rebrand must update both intentionally.

## Hosting sources

Researched September 6, 2026:

- https://gohugo.io/host-and-deploy/host-on-github-pages/
- https://developers.cloudflare.com/pages/framework-guides/deploy-a-hugo-site/
- https://gohugo.io/templates/types/
- https://gohugo.io/configuration/output-formats/
- https://github.com/gohugoio/hugo/releases/tag/v0.165.0

The deployment settings above configure static hosting; they are not evidence of an actual deployed URL. Record the successful deployment and domain separately before adding a new Help URL to the app.
