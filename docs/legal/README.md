# Legal-risk remediation: controls, evidence and ownership

This is the implementation companion to the dated [legal review](../legal.md), not a customer contract, counsel opinion or release approval. Every original finding has its own issue. **A merged engineering safeguard does not close an external factual or professional-review gap.**

The shipping architecture remains local-first, no LinePaycheck account/backend, manual user-directed Files/iCloud backup, and native Apple commerce. Bundle ID remains `com.streamentry.linepay`. The present release-control policy is US-only and manual release; neither policy is a statement that all US wage laws are implemented.

**Status (September 9, 2026):** The legal engineering line is merged into `origin/main` at `89293885d4fce8451a3bce86fda6447c768bedd2`. The relevant integration receipts are PR #57 (`79c5ed4a067276bd7c4388653e80ef1f98f44e7c`), PR #77 (`9a599f24b69df8d32ab3c6d976bdb2d3d92eca9b`), PR #78 (`6734e773755358ad2d240b83df7d22cebede5c82`), PR #79 (`3af21e9c11c9fdb9133499c8e7d7d5e4cebd5b8e`), PR #80 (`297e4a417da4dcd51df219a5752f211746f82fc6`), PR #81 (`431abfe6d3d8936817191cc77c00ea5766e1c57a`), and PR #82 (`89293885d4fce8451a3bce86fda6447c768bedd2`). PR #82 completes the safe later paycheck-review route for a closed period whose expected pay remains unresolved: confirmed facts are retained as explicitly `notComparable`, with no invented amount or reconciliation. Exact-head targeted-native run `34263817878` passed; offline controls `34263817825` and Pages passed. The broader iOS check `34263817820` was still running at this update, and hosted-account billing/spending-limit failures remain tracked separately in #37. These receipts do not constitute storefront, counsel, publisher, physical-device, provider, or external-ownership approval.

## 1. Work register

Engineering changes are reviewed in [PR #34](https://github.com/streamentry/linepay/pull/34), [PR #57](https://github.com/streamentry/linepay/pull/57), and the subsequent native/CI integration PRs [#77–#82](https://github.com/streamentry/linepay/pulls?q=is%3Apr+is%3Amerged+77..82). Read the dated receipts before treating native changes as verified or merged. Each row below is an implementation/closure map, **not a claim that all checkboxes on the issue are complete**.

| Finding / issue | Repository control or fix | Evidence still required to close the original issue |
|---|---|---|
| [LEGAL-01 / #13](https://github.com/streamentry/linepay/issues/13) | Source/build-bound release preflight; API submission guard | Actual selected Apple binary, review/release mode, storefront and owner authorization |
| [LEGAL-02 / #14](https://github.com/streamentry/linepay/issues/14) | Shared supported/unsupported disclosure in setup, results, About and PDFs; regression cases | Native acceptance and worker comprehension; expert scope review for agreement claims |
| [LEGAL-03 / #15](https://github.com/streamentry/linepay/issues/15) | Exhaustive three-scope consent with frozen-zone date and correction preview | Passing native tests and rendered confirmation states |
| [LEGAL-04 / #16](https://github.com/streamentry/linepay/issues/16) | Required policy/support snapshots and publisher/contact fields | Real live pages, exact legal entity and monitored contact verification |
| [LEGAL-05 / #17](https://github.com/streamentry/linepay/issues/17) | Correct current reusable privacy copy; CI scans active copy, not historical audits | Website, App Store assets, advertisements and support copy review |
| [LEGAL-06 / #18](https://github.com/streamentry/linepay/issues/18) | Product IDs/statuses bound to release; free audit separate from trial | Actual eligible/ineligible storefront transactions and continuing saved-record access |
| [LEGAL-07 / #19](https://github.com/streamentry/linepay/issues/19) | Commerce responsibility matrix below; attributable release review | Counsel/account-holder review of actual platform and applicable state obligations |
| [LEGAL-08 / #20](https://github.com/streamentry/linepay/issues/20) | Minimized default PDF, explicit source-detail opt-in, exact-byte preview/share and cleanup controls | Native PDF/text, preview, cancellation and recipient-flow checks |
| [LEGAL-09 / #21](https://github.com/streamentry/linepay/issues/21) | Scoped temporary-file deletion; sharing lifetime checks; threat decisions below | Two real devices/iCloud/provider failures and actual protection behavior |
| [LEGAL-10 / #22](https://github.com/streamentry/linepay/issues/22) | Hashed resources/dependency inventory; source-bound privacy review | Built privacy report, actual website/support/vendor flows and owner declaration |
| [LEGAL-11 / #23](https://github.com/streamentry/linepay/issues/23) | Minimum-data support procedure and issue template; safer bundled wording | Adopted owner, monitored system, access controls and actual retention settings |
| [LEGAL-12 / #24](https://github.com/streamentry/linepay/issues/24) | Mandatory brand review evidence; preserve installed identity | Actual trademark clearance and founder residual-risk decision |
| [LEGAL-13 / #25](https://github.com/streamentry/linepay/issues/25) | Dependency/asset fingerprint and chain-of-title checklist | Actual contributor agreements, current asset provenance and distribution-license review |
| [LEGAL-14 / #26](https://github.com/streamentry/linepay/issues/26) | Pack rights/coverage gate; no-pack non-applicability must be reasoned and reviewed | Rights, payroll scope and reviewer evidence for each shipped named pack |
| [LEGAL-15 / #27](https://github.com/streamentry/linepay/issues/27) | Current claims table and build-bound actual screenshot checks | Store-selected captures and substantiation/permission for public claims/testimonials |
| [LEGAL-16 / #28](https://github.com/streamentry/linepay/issues/28) | Standard EULA retained; separate terms-review evidence | Actual publisher/consumer-counsel review, not invented clauses or approvals |
| [LEGAL-17 / #29](https://github.com/streamentry/linepay/issues/29) | Non-adjudicative results/reports, deadline warning and support boundaries | Native/export checks and adopted support/marketing practice |
| [LEGAL-18 / #30](https://github.com/streamentry/linepay/issues/30) | Safe-use and minimum-sharing wording; no blanket employer-permission or DOB demand | Audience, store rating and actual marketing alignment |
| [LEGAL-19 / #31](https://github.com/streamentry/linepay/issues/31) | Changed-flow UI acceptance tests and precise evidence matrix | Physical VoiceOver, focus, largest-text and field-use evidence for advertised features |
| [LEGAL-20 / #32](https://github.com/streamentry/linepay/issues/32) | Owner-controlled request/body approvals before authenticated writes | Actual compliance declarations and credential-custody review |
| [LEGAL-21 / #33](https://github.com/streamentry/linepay/issues/33) | Scope-change triggers, current inventory and market gate | Approved actual market/processing map and operating decisions |

Do not add `Closes #13`–`#33` wholesale to a PR. Close an issue only when its own acceptance evidence exists; otherwise comment with the implemented control, test receipt and remaining owner action. Do not call an infrastructure failure a passing test or lower the test bar to get a merge.

### Acceptance evidence ledger

This is the durable issue-to-evidence register. `Pending` means the original issue stays open.

| Issue | Remaining acceptance | Responsible role | Regression / fix evidence | Native / UI evidence | Merge state | External blocker |
|---|---|---|---|---|---|---|
| #13 | Exact binary/storefront/release authorization | Release owner | PR #35 release guards | Local tooling only | PR #35 merged | Apple readback and owner authorization |
| #14 | Native disclosure and comprehension | Product + qualified reviewer | `LegalRegressionTests`; PR #34/#57 and current `main` | Exact-head native receipt `34263817878` covers legal regressions; comprehension remains unverified | PR #57 and follow-ups merged | Worker and expert review |
| #15 | Three scopes, dates, cancellation, large text | iOS owner | `LegalConsentAndReportTests`, `NoOpenPeriodRuleTests`; PR #34/#57 | Exact-head targeted-native receipt `34263817878`; broad iOS receipt still separate | PR #57 and follow-ups merged | Rendered/user acceptance |
| #16 | Live pages, entity and monitored contact | Publisher | Release snapshot guards | Not applicable | Controls merged | Publisher facts and live support test |
| #17 | Audit all public copy | Publisher | Copy scanner | Not applicable | Controls merged | Actual store/ads/support inventory |
| #18 | Live purchase lifecycle and saved-record access | Commerce owner | StoreKit lifecycle tests | Simulator is not storefront proof | Controls merged | App Store products and sandbox transactions |
| #19 | Applicable consumer obligations | Publisher + counsel | Responsibility matrix | Not applicable | Controls merged | Attributable legal review |
| #20 | PDF, preview, native share and receiver handoff | iOS owner | `LegalRegressionTests`, `ReportShareSessionTests`, `ReportTransferTests`; PR #34/#57 | Exact-head targeted-native receipt `34263817878`; receiver/provider behavior remains unverified | PR #57 and follow-ups merged | Receiver/provider acceptance |
| #21 | Two-device/provider/protection behavior | Security owner | Temporary-export and share-session tests; PR #34 | Simulator evidence only | PR #34 merged | Physical devices and iCloud/provider failures |
| #22 | Binary privacy report and real data flows | Privacy owner | Inventory/hash guards | Local manifest validation only | Controls merged | Actual vendor/web/support review and signoff |
| #23 | Adopted incident/support operations | Support owner | Support procedure checks | Not applicable | Controls merged | Monitored channel, access and retention settings |
| #24 | Trademark clearance and residual-risk decision | Founder + qualified counsel | Brand evidence gate | Not applicable | Controls merged | Search, recommendation and founder decision |
| #25 | Chain of title and distribution licenses | Publisher | Provenance/dependency inventory | Not applicable | Controls merged | Agreements, asset ownership and license review |
| #26 | Rights/scope for each shipped pack | Content owner | Pack gate | Not applicable | Controls merged | Per-pack evidence or reviewed non-applicability |
| #27 | Exact release screenshots and public claims | Marketing + release owner | Screenshot/claims gate | No selected release captures | Controls merged | Store-selected captures and permissions |
| #28 | Publisher/consumer terms approval | Publisher + counsel | Terms evidence gate | Not applicable | Controls merged | Attributable approval |
| #29 | Native wording plus adopted support/marketing practice | Product + support owner | Legal report/UI regressions; PR #34/#57 | Exact-head targeted-native receipt `34263817878`; operational adoption remains unverified | Controls merged | Operational adoption |
| #30 | Rendered audience/safe-use alignment | Product owner | Legal UI regressions; PR #34/#57 | Exact-head targeted-native receipt `34263817878`; store/marketing alignment remains unverified | Controls merged | Store rating and marketing alignment |
| #31 | Focus, VoiceOver, text sizes and device evidence | Accessibility QA | `LegalJourneyTests`; PR #34/#57 | Simulator evidence only; physical VoiceOver/device acceptance remains open | Controls merged | Physical VoiceOver/device acceptance |
| #32 | Exact declarations and credential custody | Release owner | Authenticated-write guards | Not applicable | Controls merged | Binary-specific declarations and owner review |
| #33 | Approved market/processing baseline | Founder + qualified advisers | Scope-change guards | Not applicable | Controls merged | Entity, location, tax/privacy/commercial decisions |
| #37 | Hosted jobs execute and retain artifacts | GitHub account owner | Earlier hosted attempts failed before steps; authorized self-hosted targeted-native run `34263817878` now executed and passed | Focused artifacts are inspectable; broad iOS run `34263817820` was still in progress at this update | Open | Repair hosted account Billing/Plans or document an approved durable runner policy, then retain full artifacts |

## 2. Development checks versus release approval

```bash
# Safe, offline ordinary-CI checks. No secrets, Apple account or approvals required.
python3 -m unittest discover -s scripts/tests -v
python3 scripts/legal_guardrails.py check

# Explicit inventory update AFTER reviewing changed resources/dependencies.
python3 scripts/legal_guardrails.py inventory > /tmp/reviewed-inventory.json
# Review its diff against docs/legal/inventory.json; do not auto-approve it in CI.

# External evidence is private, retained outside Git; use the exact clean candidate checkout.
python3 scripts/legal_guardrails.py release --stage submission --evidence /private/release/evidence.json
python3 scripts/legal_guardrails.py release --stage distribution --evidence /private/release/evidence.json
```

The preflight requires a full source SHA, clean checkout, actual IPA hash/embedded bundle-version-build identity, selected Apple build, recent storefront readback, manual release, US territory scope, both existing subscription products, live policy/support snapshots, actual build-bound screenshots, and review evidence for all 21 findings. Distribution requires approved products; submission accepts their documented pre-approval states. The controlling submission still needs appropriate product attachment and owner review.

All approval records must identify a reviewer, rationale, timezone-qualified date, source SHA and retained evidence with checksums. The release and individual source re-attestations are at most seven days old; storefront/page readbacks are at most 24 hours old. These are **internal freshness policies**, not statutory deadlines. Source changes invalidate approvals. Underlying long-lived legal advice can be referenced by a new attributable applicability review; do not invent a fresh counsel opinion.

Start from `release-evidence.template.json`, which is intentionally non-approving and cannot pass. Relative artifact paths are resolved inside its external evidence folder; traversal, absolute paths, symlinks, missing files, altered checksums, unknown findings and malformed fields fail closed. The IPA's identity is read from its embedded Info.plist, not merely the filename.

**What this cannot prove:** a JSON reviewer name is not an authenticated signature; a checksum is not proof of author, legal correctness or screenshot truth. The owner must check source-to-build provenance, actual account readbacks, counsel scope and evidence authenticity. The program enforces consistency and missing-evidence barriers, not legal clearance. A future signing/attestation service is not required for this small app.

### App Store Connect write boundary

`scripts/asc-api.py` stays GET-first. `--allow-write` alone is insufficient for other writes: provide `--release-evidence`, including `authorized_request` with exact method, path and SHA-256 of the reviewed JSON payload bytes. Unknown write endpoints default to the gate. Release requests require distribution evidence. Duplicate JSON fields are rejected before credentials/network access.

One narrow safety exception is an explicitly authorized PATCH of a single existing `appStoreVersions/<id>` whose entire payload changes only `releaseType` to `MANUAL`. This can prevent automatic release without pretending the product is already ready. It does not authorize submission, publishing, changing any other field, or using another endpoint. GET remains available. Other withdrawal workflows need the account holder's appropriate Apple workflow; do not broaden the exception by guesswork.

No request is made by the preflight itself. No release credentials, private keys, worker records, signed contracts or actual approval bundles belong in Git, tests or CI artifacts. An agent must still have the user's authorization for the specific external action.

## 3. Current approved engineering language (not an external publication receipt)

| Purpose | Allowed formulation / boundary |
|---|---|
| Privacy | Private by default. Calculations and paystub processing happen on your device. You choose whether to export or back up your records. No paycheck uploads to a LinePaycheck server. |
| Calculation | Expected pay from the supported rules and work facts the worker confirms. Do not imply full statutory weekly-overtime/regular-rate or every-CBA coverage. |
| Match | Only the stated gross basis and confirmed components were compared. A match is not certification of every legal entitlement. |
| Difference | Possible difference to review. Never automatically relabel it as recovered money or employer liability. |
| Rules | Worker-entered, referenced, or scoped/reviewed as actually evidenced. A source URL alone does not mean official/verified/endorsed. |
| Free and Pro | First complete comparable audit is free without enrolling in recurring billing. Existing records remain readable/exportable after Pro ends. |
| Trial | Eligible annual users receive the actual StoreKit introductory offer. Monthly is immediately paid. No eligible-offer claim while metadata is unknown. |
| Backup | Manual, user-directed Files/iCloud snapshot. Includes retained originals. Not password-encrypted by LinePaycheck; checksum detects damage, not authorship. |
| Sharing | Default report omits optional identity/source text but still contains sensitive amounts/dates/rules and is not anonymous. Preview the exact copy. |
| Screenshots | Actual release-candidate captures, consistent synthetic facts; concepts remain labelled concepts. |
| Accessibility | Name the exact supported feature/build/device evidence. No blanket ADA/fully-accessible/all-screens claim from code coverage. |

The active-copy scanner is deliberately narrow: app Swift strings and current pricing/marketing/store documents, including known canonical replacements. Historical audits, third-party quotations and legal problem examples are not silently rewritten. It catches common overclaims; it is not a language-understanding or advertising-law certification. New copy surfaces must be added to the review scope.

## 4. Commerce responsibility and operating record

| Topic | Platform control to verify | Publisher responsibility/evidence |
|---|---|---|
| Purchase/offer | Apple product metadata, eligibility and purchase confirmation | Correct in-app full price/frequency/trial wording; do not invent eligibility |
| Consent/receipt | Apple transaction/receipt/acknowledgement mechanisms | Verify what records the actual distribution arrangement supplies and what applicable law still requires |
| Renewal/price change | Apple's actual notice and subscription flows | Counsel-reviewed allocation of any residual notice/retention duties; no unsupported promise Apple handles everything |
| Cancel/restore/refund | Apple subscription settings, restore and refund process | Reachable routes without LinePaycheck login; accurate support explanations; never guarantee every refund outcome |
| Expiry/catalog failure | Verified current entitlement and unavailable-store behavior | Continue access to saved work, audits and exports; test independent of product-catalog success |

Keep seven-day annual intro-trial eligibility separate from first-audit sampling. Do not add email collection, a billing backend or a local-notification substitute without establishing a need. Use the primary sources in `docs/legal.md`; do not revive the vacated 2024 FTC rule as a binding nationwide requirement. Actual applicability and platform allocation remain counsel/account-holder work.

## 5. Minimum-data support and incident procedure

Before accepting real support records, the publisher must name the monitored channel, accountable owner, permitted staff/vendors, access controls and retention/deletion schedule. This document specifies the required procedure; it does not claim those external systems are configured.

1. Start with app/build version, relevant screen, steps, rule version, payroll timezone, and synthetic values. Never request a full backup, original paystub, SSN, bank details, employer credentials, coworkers' information or operational secrets by default.
2. Preserve the worker's original local data. Explain that support cannot retrieve records never sent from their device. Do not recommend destructive reset as the first response to a data problem.
3. If sensitive material is strictly necessary, first agree a minimum-data handling route with the privacy owner, actual access/retention controls and the worker. Voluntary sending alone is not that process. Do not paste it into GitHub, CI, advertising tools or coding-agent prompts.
4. For accidentally received sensitive material, restrict access, stop forwarding, notify the responsible owner, determine lawful retention/hold/deletion needs, and record the disposition without copying the data into the engineering issue.
5. For a suspected wrong amount or privacy leak, retain synthetic reproduction and the affected source/build mapping; correct the implementation and claims, add regression tests and use the release gate. Assess notification/remedy obligations with the appropriate advisers. Do not announce universal safety from a passing test.
6. Support explains inputs and calculations, not a worker's definitive legal entitlement. The app does not extend filing/grievance deadlines. Never automatically send accusations or legal demands to an employer.

Retention must be adopted in the real receiving system and communicated accurately. A proposed short retention period is not evidence of deletion. Do not erase the worker's own evidence or external provider backups while cleaning publisher-owned diagnostic copies.

## 6. Data-security decisions and acceptance

A default minimized report excludes original pages, notes and optional source identity. Including source details requires affirmative selection and a new preview. Preparing another version invalidates the old share permission. A fingerprint binds sharing to the prepared bytes; it is only an integrity check. Cleanup must not remove a file while a system activity is using it or follow a symlink to original evidence. Failed cleanup disables the stale share action and offers retry; deleting app-owned data never claims to delete provider copies or cancel billing.

Retained wage records use the existing local protection architecture. After-first-unlock protection is not an app lock on every screen lock. New Face ID requirements, blanket backup exclusion or password encryption are not silently introduced here. Shared-device, app-switcher, file-provider and lost-device behavior still require an explicit threat decision and device tests. Do not promise forensic flash erasure, anonymous reports, authenticated backups or guaranteed upload completion.

| Acceptance area | Required actual receipt |
|---|---|
| Three rule scopes | Small and large text, frozen timezone/date, correction amounts, cancel and failed save |
| Matched and differing audits | Visible scope before interpreting a result; supported/not-supported disclosure and unchanged saved verdict |
| PDF | Extracted text free of default-private sentinel fields; opted-in copy labelled; current/history/revision routes |
| Preview/share | Correct file, option-change invalidation, failed load/export/cleanup, cancellation and activity completion |
| Backup | Two real devices with the same chosen Drive, completed upload/download/restore, missing/locked provider, replacement consent |
| Accessibility | VoiceOver labels/order/focus/errors, largest text, contrast/appearance, reachable cancellation and commerce controls |
| Commerce | Local StoreKit scenarios plus separately recorded actual eligible/ineligible storefront behavior |

Source inspection and view-body tests are useful but do not satisfy physical-device rows. Capture synthetic data only.

## 7. Ownership, licenses, assets and agreement packs

`inventory.json` records mechanical hashes of Xcode dependency declarations, resolved packages, Info.plist and shipped resource inputs. It is not ownership approval. Changed inputs fail the ordinary check until reviewed; source changes also invalidate release attestations.

Current reviewed remote package: ViewInspector at `f110d97d84f7a3a2fe89b897d63c814c538f695e`, test-target-only, MIT (copyright 2019 Alexey), as recorded from its pinned upstream LICENSE in the legal review. Preserve applicable upstream notices in development copies. Verify what is actually distributed; do not claim a test-only package ships in the app or add a runtime attribution service merely for appearance.

The founder must retain a private chain of title for code contributors, current logo inputs, generated/copied assets and any licensed material. User selection of a logo is not proof of ownership. A private proprietary repo does not need an unrequested open-source license. Do not invent assignments or exclusivity over third-party content.

Trademark clearance covers LinePaycheck/LinePay variants, icon and related uses in actual territories. It needs a real professional recommendation and founder decision, not domain availability or this document. Preserve the installed bundle ID unless its migration is explicitly authorized.

Before a named agreement pack ships, require rights/legal basis, employer/local/classification applicability, effective dates/amendments, covered/excluded provisions, reviewer and version-change process. Public availability is not permission to copy all protected expression. A no-pack launch can use a reasoned reviewed non-applicability record. Synthetic tests must never silently become official rates.

## 8. Change triggers and external approval

Re-evaluate the corresponding issues before adding territories, payroll-law coverage, named packs, accounts/cloud sync, analytics/ad-tech, support vendors, new runtime SDKs/encryption, employer processing, credit/fund movement, legal representation or child-directed marketing. Currency conversion alone does not localize payroll law. Never send wage/union/paystub/discrepancy data as advertising events.

The founder/account holder owns the actual entity, operating-location, tax/settlement, support and compliance declarations. Consumer counsel reviews EULA/supplements and mandatory remedies; no blanket no-refund, unreviewed arbitration or access-to-records waiver is added here. Scope of GDPR/PDPA/CCPA and other regimes follows the actual facts, not a guessed company suffix. Insurance can be considered with a broker; no policy purchase or claim of coverage is made.

Known external limitations must remain visible: live App Store readback, published-site verification, exact publisher/contacts, real support adoption, trademark/ownership/counsel approvals and physical-device tests. Neither this file nor GitHub issue closure may impersonate that evidence.
