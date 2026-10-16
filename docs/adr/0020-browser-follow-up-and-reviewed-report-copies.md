# ADR 0020: browser follow-up and reviewed report copies

Status: accepted for the owner's all-stage/local-only v2 request, October 17, 2026. Native/platform
release, actual OS print/save and physical delivery remain independent evidence gates.

Follow the existing native six worker-recorded statuses: reviewing, shared, awaitingResponse,
corrected, explained and unresolved. Store append-only events against an existing period and saved
check. A status/note never changes gross, expected amounts, comparison verdict or records money
recovered. Shared is a worker report, not an automatic consequence of a download. Require a
nonempty bounded note and preserve original events when adding a correction.

Web state v4 adds `resolutionEvents`. Validate exact shape/status/Unicode, identity uniqueness,
check/period relationship and limits (10,000 events, 4,000 UTF-16 units per note, existing 8 MiB state
cap). Refuse unsupported controls/lone surrogates rather than produce lossy HTML. Known v1/v2/v3
migration adds only empty missing metadata; never invent old follow-up or reprice prior receipts.
A synthetic v3 fixture is generated/validated with actual `5a42523` modules. Container/encryption
versions remain 1; actual encrypted old-schema recovery preserves profiles, wage/fund history and
crew provenance. Native state admission remains unsupported pending a full financial migrator.

A browser evidence report is a receipt of one saved calculation/assessment. Render saved values,
period/zone, creation instant, confirmation/scope, configured parameters and rule/engine references;
never call the pay calculator in the report renderer. A newer personal profile cannot change it.
Unknown comparable gross stays unknown, not zero. Guarantee top-ups are not actual clock time.

Default copies omit worker follow-up history, detailed clock/break facts and imported-draft text.
Each is an explicit privacy option, scoped only to the selected check. Even the minimized report
contains sensitive amounts/dates/reference IDs and is not anonymous. No evidence originals are
attached by this initial browser report. No report is sent to another person or server automatically.

Review and download use the same prepared UTF-8 HTML bytes. Privacy/data changes invalidate the
preview and revoke its Blob URL. Navigation and mutation dispose old previews; a download has its
own short-lived URL so UI cleanup does not interrupt an initiated save. Never delete user-exported
external copies. Refuse reports above 2 MiB without silently dropping a ledger/history tail.

Preview the exact document in a sandboxed Blob iframe with same-origin access only for inspection
and explicit print invocation, modals allowed, scripts disallowed. The self-contained document's
CSP denies scripts, forms, objects and external resources. Parent frame policy permits Blob views;
inline report CSS is admitted by a fixed SHA-256 hash, checked against source/parent policy in
tests. Escape all dynamic values. Do not weaken the parent to arbitrary inline scripts/styles.
Only enable actions after the actual prepared Blob document loads, not an initial blank frame.

The downloaded HTML is printable outside the app. Print/save PDF invokes the selected report frame,
not the surrounding app or private form fields. Chromium's PDF rendering of actual downloaded
HTML provides layout/text evidence; it does not prove an OS print dialog, provider save or physical
recipient delivery. WebKit verifies actual review/download/print-media layout, without a PDF claim.
Use real browser and independent PDF extraction/rendering, not an invented PDF output or mocked
successful network path. Keep release/device/source-rights evidence separate.
