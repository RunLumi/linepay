# Local web client on Cloudflare Workers

[Release index](README.md) · [Browser behavior and limits](../../apps/web/README.md) ·
[Hosting/privacy decision](../adr/0031-cloudflare-static-web-release.md)

This runbook releases the implemented browser client. It does not certify full v2/v3 completion,
native feature parity, legal-pay coverage, installed/physical-device PWA behavior or an App Store
release. The visible development-preview label and `noindex` remain until their own reviewed change.

## Origins and hosting boundary

Production is `https://app.linepaycheck.com`, Worker `linepaycheck-web`, in the verified RunLumi
account. Staging is the separate `linepaycheck-web-staging` Worker on its account's `workers.dev`
hostname. Its records must be synthetic. Check current DNS and Worker ownership before the first
deployment; do not replace the existing apex/www marketing Worker or bind a hostname owned by
another application. The account ID and domain in `apps/web/wrangler.jsonc` are public identifiers,
not credentials. Production disables `workers.dev` and version-preview URLs.

Cloudflare receives ordinary asset-request metadata. No pay-data API, server database, analytics
collector or automatic backup is configured. Pay records stay in that browser's IndexedDB unless
the worker deliberately exports a file. Do not enable Cloudflare Web Analytics, request-body
logging, collectors or another data flow as part of a routine static deployment.

The app sends `Cache-Control: no-transform` on its assets. A proxied custom domain can inherit
zone-level Web Analytics injection even when the Worker has no analytics binding and staging
has none. Cloudflare documents that this directive prevents automatic beacon injection
([Web Analytics setup](https://developers.cloudflare.com/web-analytics/get-started/)).
Verify both actual browser HTML bytes and network requests on the production hostname; a plain
HTTP client's byte check alone does not prove the browser receives the same HTML. Ordinary CDN
request metadata remains part of static hosting; this directive does not disable edge inspection.

## Reproducible checks

Use Node 22+ and the repository's pinned Python browser tools. From the repository root:

```bash
npm --prefix tools/web-worker ci --ignore-scripts --no-audit --no-fund
node --test apps/web/tests/*.test.mjs
WRANGLER_SEND_METRICS=false npm --prefix tools/web-worker run check:worker
npm --prefix tools/web-worker run check:assets
```

Wrangler 4.148.0 is pinned with integrity receipts in `tools/web-worker/package-lock.json`; it was
published October 6, 2026. It is development tooling and never enters the public assets. The
October 1 compatibility date is supported by this pinned runtime. Reassess it with a tested tooling
update. Asset-only hosting requires no application `main`, Node compatibility flag or Env types.

The builder writes only `.build/web-worker/assets` plus a private source/byte receipt at
`.build/web-worker/asset-manifest.json`. It allows the six app-shell entry files, regular `.mjs`
browser modules and `_headers`. It checks relative module, HTML, manifest-icon and service-worker
shell references. `check:assets` refuses extra/stale files. Never deploy `apps/web`, the repository
root, `.build`, or a directory containing tests, backups, receipts or credentials.

Run the actual local Workers HTTP boundary, then use a second terminal for probes:

```bash
WRANGLER_SEND_METRICS=false npm --prefix tools/web-worker run dev:worker
node tools/web-worker/check-http.mjs http://127.0.0.1:8787/
BROWSER=chromium python3 tools/web-worker/check-browser.py http://127.0.0.1:8787/
BROWSER=webkit python3 tools/web-worker/check-browser.py http://127.0.0.1:8787/
```

Use the isolated Python environment from the [browser test instructions](../../apps/web/README.md#real-browser-verification).
HTTP probes compare every public runtime file with the built SHA-256 receipt and check MIME,
cache/security headers, missing/private-path 404s and POST rejection. Fresh synthetic browser
contexts verify exact wages, saved comparison, sandboxed report preview/download/print layout,
encrypted backup download, service-worker control and retained records after reload. They send no
pay data to the server. The existing full Chromium/WebKit journey separately proves offline reload
with its actual local origin stopped. These are distinct evidence layers.

## Stage, deploy and read back

Deploy only the reviewed source after the relevant PR checks pass. Read current `main`, use a clean
checkout and build there; retain the resulting asset receipt with the tested source commit. Confirm
authentication and the intended account before writing:

```bash
WRANGLER_SEND_METRICS=false tools/web-worker/node_modules/.bin/wrangler whoami
WRANGLER_SEND_METRICS=false npm --prefix tools/web-worker run deploy:staging
```

Use the actual staging URL returned by Wrangler for both probes above. Record URL, commit, asset
receipt, date, Worker version/deployment ID and results. Then deploy the same reviewed source:

```bash
WRANGLER_SEND_METRICS=false npm --prefix tools/web-worker run deploy:production
node tools/web-worker/check-http.mjs https://app.linepaycheck.com/
BROWSER=chromium python3 tools/web-worker/check-browser.py https://app.linepaycheck.com/
BROWSER=webkit python3 tools/web-worker/check-browser.py https://app.linepaycheck.com/
WRANGLER_SEND_METRICS=false tools/web-worker/node_modules/.bin/wrangler deployments list --config apps/web/wrangler.jsonc --env production --json
```

Do not record auth tokens or real worker records. CLI success is an upload receipt; passing the
normal HTTPS hostname, byte probes and browser journey is live serving evidence. A temporary DNS
override alone does not prove ordinary public DNS. Store a dated, source-bound deployment receipt
under `docs/release/evidence/` when the live results exist; do not manufacture a receipt in advance.

## Updates, rollback and record recovery

Keep the same origin. Existing tabs retain their loaded service-worker shell while editing; a new
version waits for those clients to close. Do not force activation, clear site data, or tell workers
to uninstall the PWA as a routine update. Browser storage can still be evicted/deleted and private
browsing can be transient. Ask workers to maintain protected manual backups in a verified location.

Before each subsequent deployment, retain the previous version ID and clean source/asset receipt.
For a serving regression, roll back the exact previously verified version and rerun the HTTP and
synthetic browser probes using that version's asset receipt:

```bash
WRANGLER_SEND_METRICS=false tools/web-worker/node_modules/.bin/wrangler rollback PREVIOUS_VERSION_ID --config apps/web/wrangler.jsonc --env production --message "Restore previously verified web assets"
```

Read the deployment back. Rollback restores served assets, not a browser's already active shell or
IndexedDB. A release that changes saved-state schemas must first document backwards compatibility;
do not serve an older client that rejects newer records and call that recovered. Existing known
schema migrations preserve historical records, but are not a blanket downgrade guarantee. A first
deployment has no prior production version: preserve the source and repair forward if necessary.

Before an origin move, export a protected web backup at the **old** origin, verify the file actually
exists, unlock/inspect it at the new origin, then explicitly replace there. Confirm records and
original saved checks before abandoning the old origin. A redirect or matching password envelope
cannot transfer IndexedDB, and native snapshots remain rejected. Do not clear the old browser data
as part of DNS cleanup. Deleting browser records does not delete exported provider copies.
