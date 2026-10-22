# Portable browser candidate staging — October 22, 2026

The existing separate staging Worker serves the portable-transfer candidate from
[PR139](https://github.com/RunLumi/linepay/pull/139). The final checked source is
`9851f2d52762598637468ad988ad30148c1f7b8f`; its follow-up evidence appears below.
The initial deployment used clean source `fe3c13ad5c80a27c2744c65d113a6c9321ecb8e7`.
These are unmerged candidate deployments.
Production at `app.linepaycheck.com` was not changed. The development-preview label and
`noindex` remain. This receipt does not establish full interchange, native parity or release readiness.

| Evidence | Observed result |
|---|---|
| Origin | `https://linepaycheck-web-staging.4rqnf2gvxf.workers.dev/` |
| Worker version | `392aed90-4d12-4499-bb2f-318bd3fda5ef` |
| Deployment | `5d20429b-d53a-4f10-9d3a-e221c14ece65`, 100%, October 22 02:29:22 UTC |
| Asset receipt SHA-256 | `cc6bbb16234a2f9a37626ed75fa81b8e2854112c5fa2e9e5e478aff03b36da19` |
| Asset boundary | 36 allowlisted files, including `_headers`; no tests, fixtures, receipts or credentials |
| Public HTTPS | 35 runtime assets byte-matched, headers/MIME, 11 missing/private refusals and POST rejection passed |
| Ordinary Worker journeys | Fresh Chromium and WebKit journeys passed |

The existing account identity, pinned Wrangler 4.148.0, asset check and dry run were verified before
deployment. A subsequent Cloudflare deployment-list readback confirmed the version and percentage
above. The ordinary browser journeys checked scoped pay comparison, local persistence, report
preview/download/print, protected manual backup, service-worker reload and same-origin GET-only
traffic. Synthetic records only were used.

Both engines also passed the portable-provider journey at this exact staging version: the captured
iOS encrypted file was selected locally without resealing; inspection left destination records
unchanged; explicit replacement preserved the three frozen receipts, current profile and distinct
future default; actual encrypted download, shared verification, reimport and relaunch passed. A raw
fractional-timestamp payload refused before replacement. The coordinator independently checked the
output hashes and ran the latest canonical verifier against both downloaded plaintexts.

This bounded transfer proof disabled service workers and allowed only same-origin allowlisted
asset GETs without query or body. Each engine recorded 99 permitted requests and zero blocked
attempts. File reading, decryption and records remained local; no financial bytes were uploaded.
The ordinary service-worker journey above is separate evidence. Automatic approval review initially
rejected an unguarded execution as a possible sensitive-file upload; the materially safer guarded
execution was approved. One public-asset API timeout occurred before file selection; browser-transport
asset attestation then passed.

The content-addressed aggregate receipt is
`0430d56e82f4819e8b7fe1fb3938ce91c6d30a35c4f832877dbf95634c502d9e` under ignored
`.build/web-provider-staging-e2e/`. Captured encrypted output SHA-256 values are
`2be8dee23747375bd2426dafc8a02521531a52a3188869d11c279205fed32baa` (Chromium) and
`4e9fcbd0a00698195f5d138e7675f01baaebac984f253b6424bc08de22bba813` (WebKit).

The previous staging deployment was `c7bf35ae-7bd6-4afd-8806-9dfa24a9c1f4`, version
`e63dc069-c39a-4db7-ab30-e4c2aa921486`. Retained private evidence is under the tested worktree's
ignored `.build/web-worker/staging-392aed90-4d12-4499-bb2f-318bd3fda5ef/`: asset receipt,
deployment lists, deploy log, HTTP/browser logs and browser artifacts. A serving rollback does not roll back browser records;
follow the [release runbook](../web-worker.md#updates-rollback-and-record-recovery).

The initial candidate had a timezone-admission mismatch: `Intl` accepts legacy
`PST`, `CST` and `IST` identifiers refused by the canonical verifier. A shared exact-case IANA
namespace fix was required before promotion. Its initial proofs do not clear later source changes.

## Final namespace and cache update

Clean source `9851f2d52762598637468ad988ad30148c1f7b8f` fixes the namespace mismatch using the
canonical schema and clearly refuses unavailable native calendar zones. All 264 Web tests and the
exact-head hosted documentation, legal and browser/Worker checks passed. Its runtime SHA-256 is
`7ff1b8ee39418f6246cba831a8351f929078b021aeff49d759deebb54a8412c9`; the 36-file asset receipt is
`eafe819693f8fcfef0e4461c446bb169689b3ca93d2ca5c5b502b1ccb7464bdf`.

The final staging version is `3756f77b-4813-45ca-a8f9-668ddf44c11f`, read back at 100% in
deployment `e32cdbd4-64bf-415d-9e6e-f8d76603edbc`, October 22 03:28:13 UTC. The same final version
passed the 35-asset HTTPS checks, all header/refusal checks, ordinary Chromium/WebKit journeys and
fresh guarded provider transfer journeys in both engines. Each provider journey recorded 99
allowlisted asset GETs and zero blocked requests. The coordinator independently verified output
hashes, the entire original graph except export metadata, and both plaintexts with the shared verifier.

Final encrypted output SHA-256 values are
`f2cf2f4f77eeb8ab044052ee59f3e14b516ad9d1ea247735f576aa03efd0a011` (Chromium) and
`01e578d9e5f1516def23fc3f8c7ad89ff8fe6cced6309b0349a006fa433357be` (WebKit).
The ignored `.build/web-provider-staging-cache18-e2e/` aggregate receipt has SHA-256
`d56fbee0b9a0a5a2b791b513a351322e0e7cb053fbb6bd694f25dc63c2ef20d5`.

The shell cache advanced from v17 to v18 because unchanged service-worker bytes could otherwise
keep existing clients on older modules. An actual staging Chromium lifecycle probe verified the
new worker waited while an unsaved 09:00 editor and exact saved records remained intact. Closing
only the task page and reopening in the same isolated context activated v18, deleted the old
shell cache and retained the exact synthetic USD10.00 result. No forced activation, site-data reset
or user-profile access occurred; 132 observed requests were fixed asset GETs without bodies/query.
Service-worker routing limits are disclosed in the retained probe. The coordinator verified eight
bound artifacts and the final served module hashes. Lifecycle aggregate SHA-256:
`a75144d5affe1638c4db17ea00ebcd03011e2b34f59d475378c1eb179dbafd84`.

The first lifecycle attempt failed in the test harness while reading a nullable waiting worker;
it is retained as an incomplete test. The corrected probe used awaited state polling. To repeat the
actual lifecycle, staging temporarily restored the verified v17 version `8de9b6b6-06c1-4099-8e43-d3f0ece5a03d`
in deployment `94fb82a8-5c11-4283-887c-ca4831965e7a`, then restored the final version above. Production
was untouched throughout. The earlier namespace-only candidate and its ordinary probes are retained
under `.build/web-worker/staging-8de9b6b6-06c1-4099-8e43-d3f0ece5a03d/`; its fresh Chromium provider
proof does not establish an existing-client update. No physical-device, full parity or public release
claim follows from these staging checks.
