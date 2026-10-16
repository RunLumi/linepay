# ADR 0018: local browser client and versioned web state

Status: accepted for the owner's explicit all-stage/local-only v2 implementation request, October
17, 2026. Deployment, native portability, physical/installed-PWA and release evidence remain pending.

Implement the browser client in `apps/web` using platform ES modules, DOM controls, IndexedDB,
Service Worker/Cache Storage and WebCrypto. No framework, build step, runtime dependency, account,
automatic sync, remote pay processing or telemetry collector is introduced. Assets are same-origin;
CSP restricts requests/scripts and blocks form submission to a server. Pay data never belongs in URL
parameters, HTTP requests, app-shell caches or logs. Native Swift/Kotlin clients remain independent.

Exact BigInt rational arithmetic owns pay pricing. Number is limited to calendar/clock safe integers,
indices and bounded metadata. The shared fixtures are the behavioral treaty; passing the initial
configured-rule subset does not establish full native/statutory parity. Reject unimplemented rule
shapes explicitly. Use distinct web calculation/assessment provenance and preserve work/rule IDs.

Each pay period captures an immutable rule snapshot. Closed calculations and each separately saved
paycheck check retain their work/rules/facts/results. Later profile/work edits do not replace earlier
checks. Future arithmetic changes require a new engine identity and retained historical interpretation
or a deliberate migration; never silently reprice saved records. Same-version validation can reproduce
and reject an inconsistent receipt but does not rewrite the saved result.

Use revision-checked IndexedDB transactions, requesting strict durability. Success is transaction
completion, not a physical-disk or retention guarantee. Other tabs' stale mutations abort atomically;
failed writes leave prior records. A selected restore is fully authenticated, decoded and validated
before preview; only a separate explicit replace commits it, under the same revision guard. Unknown
fields/versions and inconsistent retained receipts fail closed. Keep bounded payload/history limits.

Web backups use the shared authenticated password envelope but a deliberately separate versioned
financial-state format (`com.streamentry.linepay.web.snapshot`, web state v1). Native snapshots must
be rejected until a full, reviewed schema migration can preserve every relevant pay/evidence record.
Matching encryption does not prove financial portability. Passwords remain transient; no recovery
backend or key storage is introduced. A requested download is not a verified provider-save receipt.

The service worker caches only an explicit versioned app-shell allowlist. It never caches user data
or arbitrary fetches. New workers wait for old clients to close; do not force activation/reload of
in-progress edits. Browser storage remains subject to eviction/deletion/private-mode lifecycle;
request persistent storage only on user intent and keep manual backup warnings actionable.

Verification uses independent shared arithmetic, malformed-state/crypto cases and real Chromium/
WebKit form/storage/backup/conflict/offline journeys. Stop the actual test origin and require a fresh
no-worker negative control; do not replace offline proof with intercepted successful responses.

Primary platform references checked October 17, 2026:

- [IndexedDB transactions and durability](https://developer.mozilla.org/en-US/docs/Web/API/IDBDatabase/transaction)
- [Storage API and persistence](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API)
- [Persistent-storage request](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist)
- [Service-worker activation](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerGlobalScope/skipWaiting)
- [Playwright WebKit offline-emulation limitation](https://github.com/microsoft/playwright/issues/42775)
