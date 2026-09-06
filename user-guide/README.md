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

The production guide is a Git-connected Cloudflare Pages project at
`https://linepaycheck-guide.pages.dev/`. Cloudflare watches
`streamentry/linepay` and automatically deploys the `main` branch after a
successful build. Preview deployments cover non-production branches and use
their own `CF_PAGES_URL` with noindex output.

| Setting | Value |
| --- | --- |
| Project | `linepaycheck-guide` |
| Repository | `streamentry/linepay` |
| Production URL | `https://linepaycheck-guide.pages.dev/` |
| Source branch | `main` |
| Root directory | `user-guide` |
| Build command | `bash scripts/build.sh` |
| Build output directory | `public` |
| Production `HUGO_VERSION` | `0.165.0` |
| Production `GUIDE_BASE_URL` | `https://linepaycheck-guide.pages.dev/` |

Pushes and merges to `main` now trigger the Pages build automatically. Keep the
root directory, command, output directory, and pinned Hugo version aligned with
the table above. `GUIDE_BASE_URL` is required for production so canonical URLs
stay on the stable help URL; preview builds use the per-deployment
`CF_PAGES_URL` instead.

The Pages project currently lists `docs.linepaycheck.com` as an additional
production domain alongside `linepaycheck-guide.pages.dev`. This repository
documentation records the observed Pages configuration; it does not claim DNS
ownership or change custom-domain settings. There is no Worker or Pages
Function. The `_headers` file supplies same-origin-only content security policy,
no-referrer, frame protection, and disables camera/microphone/geolocation for
this help site.

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

The initial Direct Upload deployment was `6dd92bb0-abc7-4f88-be25-b20a5629016d`
from `ce7d0dc`. After Git integration was enabled, the current production
deployment is `c401e09f-f340-4064-9cd0-318f4a6e0048` from `75e01e7` on
September 6, 2026. The first successful Git-connected retry was
`d95a8204-d339-4b62-90ec-d6dfd29c57e1` from `445234e`; the merge of this
documentation update then deployed automatically. Record each later deployment
separately before adding a new Help URL to the app.
