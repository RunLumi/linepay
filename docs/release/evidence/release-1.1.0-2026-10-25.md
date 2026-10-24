# Paycheck Audit 1.1.0 (15) — App Review submission, October 25, 2026

[Release home](../README.md) · [Store copy](../app-store.md) · [v3 plan](../../plan/v3.md)

Apple accepted this update as **WAITING_FOR_REVIEW**, with release type **MANUAL**. The submitted listing is **Paycheck Audit**, subtitle **Compare Pay & Track Hours**. Public release is pending Apple approval; this receipt does not claim the new version is downloadable.

## Authority and source

The owner requested “update app store description, name, keywords etc.. and release new version,” then explicitly selected release with crew-rule sharing unavailable. Microphone capture was already held pending device QA. This follows the standing per-release waiver in [legal release authority](../../legal/README.md); it is not counsel approval or a physical-device acceptance record.

- Source: `fe184e78e8c308a14ecd0586070dae9e3763e07a`.
- [PR #147](https://github.com/RunLumi/linepay/pull/147), merged main `bc05d8b2582d35c3eceb60aeab7672ffea0ed281`. Its tree exactly matches the tested source: `b4f72759835371a43ff60c5ea7762cc4e9103d42`.
- Embedded identity: `Paycheck Audit / com.streamentry.linepay / 1.1.0 / 15`, minimum iOS 18.
- IPA SHA-256: `c97900bd881d64ea725e9bd0379c80d117347200d203bed24223c6240e6b19ac`; 6281285 bytes. Archive and exported-app signatures passed `codesign --verify --deep --strict`.
- Xcode 27.1 / Swift 6.4 produced the package and executed the checks; this is actual toolchain evidence, not a claim that the repository's older Xcode baseline was installed.

The bundle ID, target/scheme, domain module, existing subscription IDs, prices and territories were preserved. Voice recording and crew-rule sharing are unavailable. The crew Settings entry is hidden and its view is guarded; ordinary manual rules, agreement documents, typed work descriptions, benefits and optional protected backups remain available. The exported binary has no microphone/speech purpose strings or `SFSpeechRecognizer` / `AVAudioRecorder` references. Its privacy manifest declares no tracking or collected data types.

## Verification

| Layer | Actual result |
|---|---|
| Domain / repository scripts | 166 domain tests and 84 script tests passed |
| Full native | 413 registered tests: 407 passed, 6 skipped, 0 failed; includes 357 app tests and 50 active UI journeys; Release simulator build passed |
| [Full native and UI workflow](https://github.com/RunLumi/linepay/actions/runs/40087758888) | Minimum-runtime iOS 18.5 plus current-runtime iOS 26.5; both UI matrix jobs passed |
| [Targeted native regressions](https://github.com/RunLumi/linepay/actions/runs/40087759027) | 33 passed, 0 skipped, 0 failed |
| Current-runtime accessibility/capture | 4 passed, 0 skipped, 0 failed |
| Maestro | All 9 standard flows and the compact dark/largest-text rule-scope flow passed |
| Install-over | Synthetic active and closed-period state remained byte-identical; saved closed History was opened and visually checked |
| Apple delivery | Package validation and upload exited 0; build 15 processed **VALID** |

The six native skips are explicit: the iOS 18 contrast auditor, the opt-in raw heuristic diagnostic, two opt-in store captures, and the two owner-held crew-sharing journeys. Current-runtime contrast and the final v3 capture ran and passed separately. These skips are not reported as successful raw audits or crew-sharing acceptance. The [accessibility procedure](../../testing/accessibility-audit.md) records the independent rendered-size, visible-contrast, semantic and scrollable-text checks.

The install-over fixtures used naming-only source `3f4ee0006186ce4bd150007bea8eeabaae4d4abf`, which retains production 1.0.5 features, and the new app without resetting its state. The tested new app's App, domain and build-configuration trees match this release. This is synthetic Simulator evidence, not a real-worker or physical-device migration certificate.

The Android check changed no Android source and initially failed because the hosted emulator went offline. Its exact-head rerun passed. No Android app was released.

## Apple readbacks

| Resource | Readback |
|---|---|
| App / bundle | `6808889292 / com.streamentry.linepay` |
| Build | `343a736c-c8fa-4717-86a6-89e9b2139002`, version 15, marketing version 1.1.0, **VALID** |
| App Store version | `f8eb634c-7208-43ab-bd89-b3b7efaa556e`, 1.1.0, **WAITING_FOR_REVIEW**, **MANUAL** |
| Review submission | `0dc3bede-4481-4456-90d8-485d85011bb2`, **WAITING_FOR_REVIEW** |
| en-US name / subtitle | **Paycheck Audit** / **Compare Pay & Track Hours**, saved and independently read back |
| Keywords | `paystub,checker,discrepancy,verification,overtime,hourly,timesheet,shift,lineman,callout,lineworker` — 99 UTF-8 bytes |
| Description | 2464 characters; includes lineman/lineworker use cases, EULA and Privacy links; SHA-256 `98ab5581891f6efb211109b1fc154703462028a659caabc965088c4c3f9dfe14` |
| Promotional text / What's New | Exact prepared values independently read back; both held capabilities disclosed in update/review notes |
| Existing Pro products | `linepay.pro.yearly` and `linepay.pro.monthly` remained **APPROVED**; no price, offer, territory or tester-group writes |

The superseded **Lineman Pay 1.0.6 (14)** had been approved but held for manual release. It was withdrawn through Apple's supported legacy submission-withdrawal endpoint (204), became Developer Rejected, and its editable version was updated atomically to 1.1.0 with build 15. The earlier binary remains retained; it was not published to clear the version slot. The modern review-item update returned 404 and made no change. The public 1.0.5 version was preserved.

## Submitted screenshots

Six real final-source captures were composed with the checked-in renderer and v3 captions. They use synthetic facts and visible comparison/access qualifiers. Apple accepted all six as **COMPLETE**, 1320 × 2868 RGB images, with matching original-file MD5 checksums; server order was explicitly saved and read back. The API's large-iPhone set identifier is `APP_IPHONE_67`.

| Order | File | Apple asset ID | Original PNG SHA-256 |
|---:|---|---|---|
| 1 | `01-is-your-paycheck-correct.png` | `cc400019-5d76-87cc-8018-ff7f6948e9d0` | `4468c271f8f424456990b29c4896f52b59c202fbc2ab3619c6654397f7b4b36a` |
| 2 | `02-track-hours-know-expected-pay.png` | `a8800019-5d76-87cc-803d-cb30347054e9` | `6f875fb5fdf8541c9dbb010b25a6f12acc3685a4941cf179fa16f270cbe0360c` |
| 3 | `03-scan-review-compare.png` | `3c400019-5d76-87cc-803a-18837e2e0832` | `8d72d9025a031f1a3ef7faa7052d19d5e914a7d9dcc051a83ff4703183c34ca0` |
| 4 | `04-possible-overtime-gaps.png` | `82000019-5d76-87cc-8036-8dd3bb21cd8d` | `3831b9d0fa170b5a982eff4e7bc09cc9b667b8234636ffcd0c21c64ce51e36c1` |
| 5 | `05-keep-the-evidence.png` | `2b400019-5d76-87cc-8018-a0e1ec586a52` | `28760447ac7f528f9e9766c62853b4b097ff590252ddf223ca55db39b65102b2` |
| 6 | `06-complex-pay.png` | `bfc00019-5d76-87cc-800a-9309c603b8ee` | `d7221fd2b2d7cb72fc6d8ad1bddff7cba1905d335b65569e474dbcdd4401237f` |

New set: `e01e09bd-e51f-4be2-a76f-5d49f36b310a`. The old draft-only eight-image set `bdd169d1-382e-4e5b-9e46-435c609bc4cd` was removed only after all six new images completed. Production set `4e65ff6b-0dd3-431e-b7c9-fe51c7ba118b` belongs to the separate public localization and was left intact. The invalid local `APP_IPHONE_69` enum was caught before network access; the supported set identifier accepted the specified image dimensions.

## Linked pages and retained evidence

[Website PR #14](https://github.com/RunLumi/linepaycheck.com/pull/14) aligned privacy/support app-name references. Its merged source `75a29febaaef131881167f056c87a7292df3f84d` was deployed to Worker version `6c86af54-a73d-4fd4-bcd2-47a066c57dc4`; live verification passed 33 read-only requests and 20 served-asset SHA matches. Local static, Chrome and WebKit checks passed; hosted website CI could not start because of its Actions budget. Publisher, contact, domain and processing architecture were unchanged.

The signed archive, IPA, source archive, actual native results, six screenshots, request/readback receipts and credential reference are retained in the private operator release bundle outside Git. No private key was copied. The four public help screenshots were refreshed from the passed final-source native journeys with provenance and scoped-result wording.

**Remaining provider step:** Apple review, followed by the authorized manual public-release request and a fresh public storefront readback. Submission, approval and publication remain separate states.


## Live help deployment follow-up

The guide's configured Git integration had not produced a new production deployment since `c03f474` in the previous month. The merged guide was therefore built from `b8e8b311665921925f730c0f1d866bc85ece363e` with pinned Hugo 0.165.0 and deployed through existing Wrangler 4.123.0 to the unchanged `linepaycheck-guide` Pages project. Correct production deployment: `a881082d-eaed-4202-b8ef-a139c37f2f79`.

A real Chrome read returned 200 for `/audit-results/`, `/crew-rule-drafts/` and `/recording-work/`. The result image's served SHA-256 matched the local build (`72d735d9990672cc388b8fdfc315358529071919430767bdd0573e53d66fa26b`); crew sharing and recording were clearly marked unavailable. A first deployment had an incorrect commit label and was superseded with the actual Git SHA; the content bytes were identical. No domain, integration or account grant was changed. [The runbook](../../../user-guide/README.md#cloudflare-pages) records the verified manual path and the unresolved automatic-trigger issue.
