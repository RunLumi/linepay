# Portable browser candidate staging — October 22, 2026

The existing separate staging Worker serves the portable-transfer candidate from
[PR139](https://github.com/RunLumi/linepay/pull/139), clean source
`fe3c13ad5c80a27c2744c65d113a6c9321ecb8e7`. This is an unmerged candidate deployment.
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
ignored `.build/web-worker/`: `asset-manifest.json`, staging deployment lists, deploy log,
HTTP/browser logs and browser artifacts. A serving rollback does not roll back browser records;
follow the [release runbook](../web-worker.md#updates-rollback-and-record-recovery).

The checked candidate still has a known timezone-admission mismatch: `Intl` accepts legacy
`PST`, `CST` and `IST` identifiers refused by the canonical verifier. A shared exact-case IANA
namespace fix and renewed checks are required before promotion. The remote and local portable-provider
proofs remain component evidence; they do not clear this defect or later source changes.
