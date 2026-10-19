# ADR 0031: Cloudflare static web release

Status: accepted implementation direction for the owner's October 19, 2026 request to release the
web client on Cloudflare Workers. Source/configuration and local checks do not establish deployment.
The [web release runbook](../release/web-worker.md) owns live receipts and recovery procedures.

Host the [local browser client](0018-local-browser-client-and-versioned-web-state.md) as Workers Static
Assets, with no application request handler, server storage, account, remote OCR or analytics
binding. Cloudflare delivers the public app files; all pay calculations and IndexedDB records remain
in the browser. Ordinary HTTP delivery exposes request metadata to the hosting provider. Do not
describe hosting as zero network access or make a blanket "no data collected" claim for the website.
Never put pay facts, passwords, exports or diagnostic content in requests, paths, queries or logs.

The stable production origin is `https://app.linepaycheck.com`, on the distinct Worker
`linepaycheck-web`. Keep the existing marketing apex/www Worker separate. A staging Worker has its
own origin and synthetic records. Disable production `workers.dev` and version-preview aliases to
avoid creating competing places for workers to store records. An origin change is a data migration:
browser storage does not follow a redirect. Preserve access to the old origin and require a verified
manual protected export, inspected restore, and explicit replacement at the new origin. Native
backup-state interoperability remains unsupported.

Build a fixed runtime-only directory from app-shell files and browser modules; reject missing local
module/shell references and verify every published byte. Keep tests, fixtures, source receipts,
dependency tooling, configuration and documentation outside this directory. Wrangler is pinned as a
development-only dependency with a committed lockfile. There is no bundler, runtime SDK or new pay
engine boundary. Asset-only configuration needs no application bindings or generated Env types.

Serve real 404s for unknown paths. Keep unversioned filenames browser-revalidated; the explicit
versioned service-worker shell continues to wait for existing clients to close. Never force a reload
of work in progress or clear IndexedDB during deployment/rollback. Headers add same-origin framing,
MIME protection and no-referrer policy while retaining the app's existing CSP and sandboxed Blob
report/print flow. The development-preview app remains `noindex` until a separate reviewed change
adopts public acquisition claims. Hosting does not establish native parity, installed-PWA quality,
physical Files delivery, legal coverage or release of a new iOS version.

Current primary documentation reviewed October 19, 2026:

- [Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)
- [Asset headers](https://developers.cloudflare.com/workers/static-assets/headers/)
- [HTML routing](https://developers.cloudflare.com/workers/static-assets/routing/advanced/html-handling/)
- [Workers rollback](https://developers.cloudflare.com/workers/configuration/versions-and-deployments/rollbacks/)
