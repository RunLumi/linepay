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

The production guide is a Direct Upload Cloudflare Pages project at
`https://linepaycheck-guide.pages.dev/`. It has no custom domain, Pages Function,
Worker, DNS record, secret, or repository connection.

| Setting | Value |
| --- | --- |
| Project | `linepaycheck-guide` |
| Production URL | `https://linepaycheck-guide.pages.dev/` |
| Source branch | `main` |
| Build command | `GUIDE_BASE_URL=https://linepaycheck-guide.pages.dev/ bash user-guide/scripts/build.sh` |
| Upload directory | `user-guide/public` |

To publish a reviewed `main` commit, build the site with its production URL and upload
the generated directory with Wrangler. Attach the commit SHA and message to the
deployment. A Direct Upload project does not deploy from Git automatically; do not
claim that future merges are public until their own upload succeeds.

```sh
GUIDE_BASE_URL=https://linepaycheck-guide.pages.dev/ bash user-guide/scripts/build.sh
wrangler pages deploy user-guide/public \
  --project-name=linepaycheck-guide \
  --branch=main \
  --commit-hash=<reviewed-main-sha> \
  --commit-message='<reviewed main commit message>' \
  --commit-dirty=false
```

Preview builds use `CF_PAGES_URL` and emit noindex/robots exclusions; production requires an explicit stable base rather than a per-deployment hash URL. The `_headers` file supplies same-origin-only content security policy, no-referrer, frame protection, and disables camera/microphone/geolocation for this help site.

There is no Worker, Pages Function, secret, API key, custom domain, or upload handler. Wrangler is used only for authenticated Direct Upload. Do not add a CNAME or change DNS until the intended domain is separately approved.

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

The default Pages URL was deployed from `ce7d0dc` as production deployment
`6dd92bb0-abc7-4f88-be25-b20a5629016d` on September 6, 2026. Record each later
deployment separately before adding a new Help URL to the app.
