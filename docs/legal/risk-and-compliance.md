# LinePaycheck: legal risk review and remediation register

**Review date:** September 6, 2026  
**Repository snapshot:** `105b024e283c70e07375f53cc4da11010441e5a2`  
**Public product:** LinePaycheck  
**Technical identity:** `streamentry/linepay`; iOS bundle `com.streamentry.linepay`  
**Document status:** Internal, AI-assisted legal-risk issue spotting and implementation guidance. Not release approval, an operative customer contract, or an opinion from retained counsel.

> **The strongest legal protection is a product whose behavior, marketing, evidence, and billing all tell the same truthful story. A disclaimer cannot substitute for fixing a misleading result or preserving a worker's records.**

This review does not claim professional licensure or thirty years of legal practice. It creates no attorney-client relationship, and putting it in a private repository does not by itself create legal privilege. A qualified lawyer should resolve jurisdiction-specific questions and approve final consumer terms and material compliance representations. Keep sensitive corporate documents and litigation advice in appropriately controlled systems, not in source-control issues.

## 1. Executive assessment

LinePaycheck has a defensible narrow product shape: a worker-controlled record and calculation tool that compares **confirmed work, configured rules, and reviewed paystub facts**, rather than a payroll processor, law firm, wage-claim representative, or universal legal-entitlement engine. The absence of a central wage-data backend reduces exposure but does not eliminate consumer, privacy, intellectual-property, or subscription obligations. The recommendations below preserve that architecture. [R01] [R03] [R04] [R06]

**Do not equate a merged fix with a fixed submitted binary.** The most urgent release risk is the dated record that version 1.0 build 2 was submitted with `AFTER_APPROVAL`, before important payroll and evidence changes. That record is not a live App Store Connect status check. Verify the actual selected binary and release state immediately; obtain the account holder's authorization before changing the submission or distribution. [R09]

Before authorizing an unrestricted paid launch, close these gates:

1. Identify and verify the actual distribution binary, subscriptions, screenshots, policy URLs, and release mode; do not let an older submission silently become the approved product.
2. Make the boundary between configured-rule comparison and comprehensive wage-law compliance unavoidable and understandable.
3. Correct the current dated-rule-change explanation; it contradicts the implemented prospective-change behavior.
4. Verify a complete, current publisher privacy/support presence and remove absolute privacy claims from reusable marketing copy.
5. Verify live annual-trial/monthly-purchase disclosures, approved products, cancellation, and the promised continuing access to saved records.
6. Review report sharing for unnecessary OCR-source disclosures and obtain a documented brand/content-rights decision.

These are risk-management release gates, not findings that every item already constitutes an unlawful act.

## 2. Scope, method, and important limits

### 2.1 What was reviewed

The review inventoried the repository tree and examined legally relevant product instructions, iOS domain/application code, rule and audit flows, persistence/evidence/backup paths, paywall and StoreKit code, bundled legal text, App Store and marketing plans, assets documentation, testing/remediation records, release procedures, and the dependency boundary. Current reads were pinned to the snapshot above. Prior archived material was used only where its version could be matched, not as a substitute for changed current files. Evidence links are collected in section 12. [R00]

This is a **repository-wide, risk-based source review**, not a representation that every executable line was formally verified. It did not inspect all Git history for secrets, render every binary asset, perform penetration testing, reproduce every device flow, verify corporate records, obtain licenses from contributors, or conduct a complete trademark clearance. It did not independently rerun the native test suite.

The review also consulted the primary legal and platform sources in section 13. Statutes, regulatory guidance, Apple contractual rules, and engineering recommendations are identified separately. No claim is made to have surveyed every state or country.

### 2.2 Jurisdiction assumptions

The release handoff records **United States-only distribution** and future-country automatic availability turned off. Pricing and marketing documents also prioritize the United States. Use that as the working launch scope, but verify the live setting. United States distribution still requires considering applicable state consumer and privacy law. [R09] [R10] [R11]

The recorded copyright string is `2026 Cloudjet Solutions`. This is not sufficient evidence of the exact contracting entity, registered suffix, incorporation, business address, tax status, or ownership of all product assets. Do not silently substitute another product's entity details. If the actual publisher or operational processing is in Singapore, Vietnam, or another country, obtain the corresponding local assessment. EU/UK/Canadian/Australian issues below are conditional expansion or operational-nexus checks, not declarations that all such laws already apply.

### 2.3 Evidence classifications

| Classification | Meaning |
|---|---|
| **Confirmed source issue** | A specific current source path supports the observation. Runtime consequences are not claimed unless separately evidenced. |
| **Dated release observation** | A repository record reports a past external state; current external status must be checked. |
| **Risk inference** | A plausible exposure derived from observed behavior, not an adjudicated violation. |
| **Verification gap** | Required evidence is absent from this review; that does not prove the control is absent everywhere. |
| **Conditional** | Applies if a feature, jurisdiction, distribution choice, or processing relationship is introduced or established. |

**Priority:** P0 means verify or control before release can safely proceed; P1 means fix before the affected feature or commercial launch; P2 means scheduled governance or a gate before expansion. Priority is a product-risk judgment, not a statutory severity classification.

## 3. Do not reopen obsolete findings as current defects

The current source materially improves the earlier implementation:

- `AppModel.candidateForProfile` protects recorded work against prospective changes and supports explicit whole-period correction. The remaining issue in LEGAL-03 is contradictory explanation, not a claim that the old repricing bug is unchanged. [R02]
- `PaycheckAssessor` distinguishes gross basis, line layout, actual/paid-equivalent hours, uncertainty, and unsupported rules. Equal gross with conflicting confirmed components produces `needsReview`. [R04]
- The report uses saved assessment scope, separates wage pay and per diem, and avoids presenting a stale gross difference as a verified shortfall. [R16]
- Original evidence, draft recovery, historical revisions, local backup/restore, and paid-access behavior have corresponding remediation work recorded. [R08]
- Current bundled legal text discusses user-directed Files/iCloud export, device backups, subscription cancellation, and continued access to saved records. Legal and support navigation now exist. [R06]

The remediation document reports a successful local native gate and separate UI checks, while identifying physical-device, live storefront, and other external limits. Those are **repository-reported verification results**, not tests executed again for this legal review. Old expected-failure counts and missing-screen claims should not be copied into new launch assessments without checking the actual version. [R08]

## 4. Prioritized risk register

### LEGAL-01 — Submitted build and current source may be materially different

**Priority:** P0 · **Evidence:** dated release observation and verification gap · **Owner:** release owner/account holder.

The September 5 release handoff records version 1.0 (2), `WAITING_FOR_REVIEW`, and `AFTER_APPROVAL`. It also records that this binary predates later correctness fixes, that the submission contained the app but not the subscription products, and that the original concept screenshots remained. Later changes to `main` do not update an uploaded binary. [R09]

**Exposure:** users or App Review could receive an older product while the team relies on assurances established only for newer source. Accurate metadata and a working submitted product are Apple review requirements; the commercial representations also need support. [A01] [A02]

**Required action:** read the current App Store Connect version, selected build, review state, release option, product-review status, and screenshots. If the old submission remains eligible for automatic release, obtain authorization to hold, withdraw, or replace it using the appropriate Apple workflow. Do not make those changes solely on the authority of this document.

**Close when:** the release record maps a specific source commit to the archived binary/build ID, identifies the tested StoreKit configuration versus real storefront, and includes current account readbacks and explicit owner sign-off. Neither GitHub CI nor App Review approval is described as universal legal clearance.

### LEGAL-02 — Configured-rule comparison can be mistaken for full wage-law compliance

**Priority:** P0 for broader entitlement claims; P1 for narrower launch disclosures · **Evidence:** confirmed scope and risk inference · **Owner:** product, payroll engineering, employment counsel.

The domain models base rate, schedule, weekday/date multipliers, daily overtime tiers, callout minimums, and flat per diem. It does not establish a complete statutory workweek/regular-rate engine, employee exemption analysis, jurisdiction selection, or every agreement-specific travel, rest, meal, and storm provision. The California agreement research explicitly identifies unimplemented provisions. [R03] [R18]

For covered, nonexempt employees, federal overtime generally turns on hours beyond 40 in a fixed workweek and the statutory regular rate; a biweekly pay period does not authorize averaging two workweeks. The regular-rate calculation can involve remuneration beyond the entered base rate. These are not optional rights merely because the app requires users to confirm a configuration. [A03] [A04]

**Required action:** present a short, affirmative supported/not-supported checklist before rule confirmation and on audit scope. State that a matching comparison covers only configured supported rules and confirmed lines, not every statutory or contractual entitlement. Explain that daily tiers do not substitute for weekly statutory analysis. Never infer complete agreement coverage solely from a blank unsupported-rule note.

Keep the highest-applicable-premium policy and callout top-up semantics visible; do not market them as universally correct for every collective bargaining agreement. Preserve the ability to label an audit limited or not comparable. [R05]

**Close when:** synthetic tests and user comprehension checks show that a gross or component match cannot be read as a comprehensive legal compliance certification. For claims about a specific agreement, retain an expert-reviewed coverage matrix and representative fixtures. A narrow, honestly described launch is preferable to hastily adding a nationwide legal engine.

### LEGAL-03 — Dated-change consent text contradicts the selected operation

**Priority:** P1, fix before shipping this screen · **Evidence:** confirmed source issue · **Owner:** iOS/product.

`PayProfileSetupView.review` offers future periods, dated changes, and whole-current-period correction. Its explanatory text uses a two-way condition: anything other than `.futurePeriods`, including `.datedChange`, receives text saying all current-period work will be recalculated and that the operation does not implement a mid-period change. The selected dated operation actually maps to `.prospective`; `AppModel` prevents it from altering recorded work. [R05] [R02]

**Exposure:** the worker is asked to consent using an inaccurate description of a material change to pay records. This is a usability and trust defect with potential misleading-representation consequences, not merely wording preference. [A02]

**Required action:** use an exhaustive switch with distinct explanations for all three scopes. The dated option must identify the effective date/timezone, preserve earlier work, and explain any unsupported spanning-callout situation. Whole-period correction must show the affected record count and before/after amount separately.

**Close when:** all three choices have matching UI contract tests and an inspected confirmation screen. Preserve the existing computational guard; do not remove it to make the inaccurate copy true.

### LEGAL-04 — Public policy, support, and publisher identity need current verification

**Priority:** P0 verification gate · **Evidence:** dated observations plus current bundled text · **Owner:** publisher/web/support.

The release record says the support/privacy routes were corrected from another product, but subsequently still contained preparation/planned-product language and an unfinished support channel. Current app code links to `linepaycheck.com/support` and `/privacy` and includes useful bundled summaries. This review could not independently retrieve and validate the current published pages; a retrieval limitation is not evidence that they return 404 or remain placeholders. [R09] [R06] [R07]

**Required action:** verify the live pages on a normal browser and device, including redirects, mobile readability, correct product identity, effective date, actual contact channel, and consistency with the shipping build. Identify the exact legal publisher and who receives support correspondence. Separate descriptions of on-device records from website logs, email support, Apple transactions, and user-selected file providers. [A05]

**Close when:** the publisher approves a dated policy/support snapshot, a working support request receives a response, the same entity and contact are used consistently, and the release checklist includes a live-link check. Do not publish a claim that no data is collected anywhere in the business if support or the website actually receives personal information.

### LEGAL-05 — Absolute privacy slogans conflict with optional exports and device backups

**Priority:** P1 · **Evidence:** confirmed documentation drift · **Owner:** product/marketing/privacy.

Reusable copy in `docs/pricing.md` says pay data stays on the device. A proposed marketing screenshot says wage data stays on the iPhone. These are internal suggestions, not proof that the claims have been published. Current bundled privacy text is more accurate: Files/iCloud exports are optional and device backups follow the user's settings. [R10] [R11] [R06]

**Required action:** replace absolute slogans in reusable copy with “Private by default. Calculations and paystub processing happen on your device. You choose whether to export or back up your records.” State separately that LinePaycheck does not operate a server storing the worker's pay records. Keep Apple purchases and external-link behavior distinct.

Do not promise “never leaves your phone,” “nobody else can access it,” or “end-to-end encrypted” without evidence covering every relevant path. Objective privacy promises need substantiation just like earnings claims. [A02]

**Close when:** a copy audit covers app strings, store metadata, screenshots, landing pages, ads, support replies, and source documents used by future agents. The actual current paywall's narrower no-upload-to-our-servers statement should not regress. [R12]

### LEGAL-06 — Trial, Free audit, and paid entitlement are different promises

**Priority:** P0 live-commerce gate · **Evidence:** current implementation and dated external gap · **Owner:** product/release/commerce.

Canonical pricing now offers eligible annual subscribers a seven-day introductory trial, then the localized yearly price; monthly is immediately paid. Independently, the first complete comparable audit remains free without an App Store subscription. The older no-calendar-trial policy is superseded. Current code checks actual product/offer eligibility and provides Continue free, Restore Purchases, and Manage subscription. [R10] [R12] [R13]

The dated release record does not establish that either subscription was approved with the app. Local StoreKit tests are not evidence of live product approval or actual account-specific offers. [R09] [R08]

**Required action:** test the actual launch storefront with eligible and ineligible accounts, annual and monthly choices, cancellation, pending approval, restore, refund/revocation, billing grace, and catalog failure. Display the full annual charge, renewal frequency, trial end condition, and cancellation route before purchase; do not lead with the monthly equivalent of an annual charge. Never advertise a trial when eligibility or product metadata is unavailable. [A06] [A07]

Make clear that continuing free does not enroll the worker in recurring billing. Reconcile documentation that lists history or OCR as Pro features with the actual first-audit sampling and permanent access to existing records. Buying Pro must fund continuing useful audits, not merely unlock records the user already owns.

**Close when:** the selected build, approved product IDs, actual offers, visible terms, and post-expiry data access have a documented end-to-end receipt. No new trial product, account system, or entitlement backend is required merely to satisfy this gate.

### LEGAL-07 — Renewal/cancellation obligations cannot be dismissed as Apple's problem

**Priority:** P1 · **Evidence:** legal applicability/operational verification · **Owner:** publisher/commerce counsel.

ROSCA requires material negative-option disclosures, express informed consent, and a simple mechanism to stop recurring charges. Apple's purchase sheet and subscription management are important controls, but they do not justify assuming every seller-side obligation is discharged. [A07]

**Current-law caution:** the FTC's March 2026 notice describes the 2024 amended Negative Option Rule as vacated and starts further rulemaking. Do not implement a checklist that falsely presents the vacated rule as a currently binding nationwide final rule. The new notice is not itself a final replacement rule. [A08]

California's amended section 17602 addresses consent verification, retainable acknowledgements, online cancellation, material changes, and renewal reminders for applicable contracts. Its special more-than-31-day trial reminder is not automatically triggered by a seven-day trial; annual renewal requirements remain a separate question. [A09]

**Required action:** create a responsibility matrix covering what Apple handles, the evidence available to the publisher, and any residual obligations under launch-state law. Review consent-record retention, renewal/price-change notices, cancellation links, and support escalation. Keep the cancellation route accessible without a LinePaycheck login or a retention conversation. Do not assume an optional local notification replaces a legally required notice.

**Close when:** counsel has reviewed the actual App Store distribution relationship and applicable state requirements, with evidence of how each obligation is satisfied. Do not collect email addresses or build a billing backend before establishing that the platform arrangements are insufficient.

### LEGAL-08 — Reports can disclose more than the compared field

**Priority:** P1 · **Evidence:** confirmed export path; conditional sensitive-data inference · **Owner:** iOS/privacy.

`ReconciliationReportExporter` excludes original paystub pages but writes `suggestion.sourceText` into a comparison's source caption. It also includes profile/rule names, source URLs, and pay information. Excluding images does not make the resulting report redacted. An OCR line can contain additional identifiers beside a relevant number; this is an exposure scenario, not a finding that a real user's identifier has already leaked. [R16]

**Required action:** preview the exact export, visibly identify its sensitive contents, and let the worker limit optional source text and identifiers. Prefer field-specific evidence excerpts instead of entire recognized lines when they are unnecessary. Keep original evidence intact inside the record; distinguish an intentionally redacted sharing copy from the original. Do not email or upload reports automatically.

**Close when:** synthetic tests place an employee ID, bank-like value, and Social-Security-number-like string near an amount and show that the default sharing path does not unexpectedly reproduce those fields. A redaction feature must actually remove underlying text/content, not merely draw a visible box. Do not market any report as “anonymous” without a separate re-identification review.

### LEGAL-09 — Backup security and deletion promises need precise boundaries

**Priority:** P1 · **Evidence:** confirmed architecture; risk-based security review · **Owner:** iOS/privacy.

Complete backups contain state and retained original paystubs. `BackupArchive` uses a checksum to detect damage; it does not password-encrypt the archive or authenticate its author. Current UI discloses that distinction. `LocalEvidenceStore` uses atomic writes and after-first-unlock file protection. That protection is not the same as making files unavailable every time the screen is locked. [R14] [R15] [R06]

**Required action:** preserve explicit private-destination consent, replacement-restore confirmation, original-file inclusion notices, size/version limitations, and the statement that local deletion does not delete external copies or cancel subscriptions. Threat-model shared phones, device loss, previews/app-switcher exposure, support attachments, and temporary reports. Decide deliberately whether stricter file protection or an optional app lock is warranted. These are design decisions, not a statement that a particular statute universally requires Face ID or password-protected backups.

Verify cleanup and failure handling across state, originals, drafts, and app-owned temporary exports. Do not promise forensic erasure of flash storage or removal from the user's provider/device backups. Avoid adding unnecessary server copies to make recovery appear easier. [R19]

**Close when:** a real two-device iCloud transfer/restore and failure test is recorded; controls and privacy wording match actual protection classes, retention, and deletion scope. The absence of app-level password encryption is disclosed accurately rather than labeled automatically unlawful or automatically safe.

### LEGAL-10 — App Privacy labels and privacy-law scope are different analyses

**Priority:** P1 · **Evidence:** release declaration and conditional processing assessment · **Owner:** privacy/publisher.

The dated release record says the owner approved and published “Data Not Collected.” Apple's label definition centers on off-device transmission accessible to the developer or relevant partners beyond servicing a real-time request. Purely local processing does not, by itself, require labeling the pay records as developer-collected. Optional support disclosures have specific cumulative conditions; they are not a universal exemption for anything a user chooses to send. [R09] [A05]

**Required action:** retain a written data-flow and label rationale for the exact release. Inspect app integrations, website analytics/logs, support systems, crash-report handling, attribution, and actual publisher access to transaction information. Keep Apple processing outside the app distinct from data the publisher independently obtains. An empty required-reason-API array is not automatically valid or invalid: audit actual covered API use and the built privacy report, not the presence of `FileManager` alone. [R20]

Assess applicable law independently. CCPA coverage depends on statutory business/activity thresholds; the adjusted revenue threshold effective January 1, 2025 is $26,625,000, not the older $25 million figure. Other qualifying thresholds and other privacy statutes must be considered separately. A small app is not automatically subject to the entire CCPA, and falling outside it does not eliminate all privacy duties. CalOPPA has a separate scope. [A10] [A11] [A12]

**Close when:** the publisher signs off on the documented actual flows and applicable-law assessment. Do not alter submitted compliance declarations automatically or add consent screens without knowing the processing and legal basis they address.

### LEGAL-11 — Support is a potential new sensitive-data processing channel

**Priority:** P1 before accepting real support records · **Evidence:** current support guidance and verification gap · **Owner:** support/privacy.

Bundled support text appropriately asks for synthetic or redacted examples and says not to send Social Security numbers, bank details, or employer credentials. A central wage-data backend is absent, but an inbox or issue tracker can still become one informally. [R06]

**Required action:** publish a real monitored contact, use minimum necessary diagnostic fields, define access and retention, and provide a safe route for an unavoidable document case. Do not request complete backup archives by default. Never paste real paystubs into public issues, CI artifacts, marketing tools, or coding-agent prompts without a separately authorized and legally appropriate process. Redaction and worker permission are controls, not automatic proof that every processing activity is lawful.

If GDPR applies to the publisher's processing, union-membership data can engage Article 9 in addition to the ordinary lawful-basis and transparency analysis. If Singapore's PDPA applies to the actual entity/processing, accountability, protection, retention, transfer, and contact arrangements need review. Do not infer those legal nexuses from a repository name. [A13] [A14]

**Close when:** a short support-data procedure names the responsible person, approved systems, permitted data, retention/deletion process, vendor review, and escalation route. It explains honestly that the publisher cannot retrieve device-local records that were never sent to it.

### LEGAL-12 — The product name has not received trademark clearance

**Priority:** P1 before material branding spend or launch expansion · **Evidence:** verification gap and preliminary search lead · **Owner:** founder/IP counsel.

The public brand is LinePaycheck while internal identifiers remain LinePay. An official LY Corporation announcement documents commercial use of LINE Pay. That is a search lead, not a finding that LinePaycheck infringes, that a particular mark is currently registered in a launch country, or that rights disappeared when a service changed. [R01] [A15]

USPTO guidance calls for considering similar marks and related goods/services, including potential confusion in appearance, sound, meaning, or commercial impression. A proper clearance goes beyond exact-match federal searches to other relevant sources, including common-law use. [A16] [A17]

**Required action:** obtain a dated clearance of LinePaycheck, LinePay, phonetic/spacing variants, the icon, and relevant software/payroll/financial service uses in the actual launch territories. Verify relevant register records rather than relying on search-engine snippets, available domains, or an accepted App Store name. Assess both registrability and use risk.

**Close when:** the founder has a documented counsel recommendation and consciously approves the residual risk or a different public brand. Do not change `com.streamentry.linepay` or other installed-product identifiers merely because a public-name review is required.

### LEGAL-13 — Corporate ownership, software licenses, and asset provenance need a chain of title

**Priority:** P1 · **Evidence:** verification gap; current assets and dependency boundary · **Owner:** founder/IP/release.

The assets record distinguishes a current user-selected logo from older generated screen concepts. Selection by the user proves a product decision, not necessarily ownership or a license from every rights holder. The tree search did not identify a top-level LICENSE. A proprietary repository is not required to adopt an open-source license; the missing file is not proof of infringement. [R17] [R00]

**Required action:** confirm the exact owning entity and obtain suitable employee/contractor/contributor assignments or licenses. Maintain provenance for current logo inputs, fonts, illustrations, screenshots, copied snippets, generated assets, and any licensed content. Record tool terms and meaningful human creative contribution where relevant. The Copyright Office's AI-authorship position does not mean AI output is automatically protected or free of third-party rights. [A18]

Maintain a small dependency/license inventory. ViewInspector is pinned and test-only; distinguish development copies from code actually distributed in the app. Preserve applicable notices and verify the reviewed revision's license. Do not add a runtime attribution screen for a dependency without first determining what is shipped and what its license requires. [R21]

**Close when:** there is an ownership/provenance register, a reviewed distribution dependency list, required notices, and no unsupported claim of exclusive ownership over third-party material. Store underlying signed contracts outside this public-facing engineering document.

### LEGAL-14 — Agreement references and future verified presets have separate rights and authority risks

**Priority:** P1 for any shipped preset; P2 while limited to references/synthetic fixtures · **Evidence:** current research limits and conditional feature · **Owner:** payroll product/IP counsel.

The California agreement research links a public agreement and explicitly marks its interpretation and unsupported provisions as limited. Current source-entry UI states that a worker's reference is not independently verified by LinePaycheck. Preserve those distinctions. A source URL and a confirmation timestamp are not proof of union approval or complete legal interpretation. [R18] [R05]

Copyright distinguishes facts, ideas, and systems from protected expression; public availability of an agreement does not automatically license redistribution of the full document, logos, explanatory text, or layout. Fair use is context-specific, not a blanket permission for commercial rule packs. [A19]

**Required action:** keep facts and calculation rules separate from copied expression. Before shipping a named verified pack, document the source/license or other legal basis, covered employer/local/classification, effective dates, amendments, exclusions, reviewer, and change process. Explain exactly what “verified” means and by whom. Do not imply IBEW, a contractor, or a payroll provider endorses the app without permission.

**Close when:** a rights and payroll-coverage review supports each distributed pack and every endorsement claim. Test fixtures must remain clearly synthetic, not silently become authoritative production rates.

### LEGAL-15 — Marketing, testimonials, and concept screenshots require proof

**Priority:** P0 for misleading submitted assets; P1 otherwise · **Evidence:** current copy/assets records and dated submission · **Owner:** marketing/release.

`assets/README.md` says the eight generated screens are concepts, not captures, and identifies layout/date discrepancies. The release handoff says earlier concept screenshots remained in the submission. Do not assume they have since been replaced. Current marketing also proposes claims about every hour, line-by-line checking, and long storm shifts that need qualification to the supported behavior. [R17] [R09] [R11]

**Required action:** use captures of the release-candidate UI with consistent synthetic examples. Any decorative framing must not invent features, verdicts, speed, or rule coverage. A depicted possible shortfall is not proof of recovered wages. Remove unimplemented “verified agreements,” universal storm/rest coverage, and guaranteed or typical savings unless supported.

For endorsements, retain actual permission and underlying evidence, disclose material connections, and prohibit fake reviews, fabricated workers, or incentives conditioned on positive sentiment. Apple review-manipulation restrictions are a separate platform gate. Internal financial benchmarks and chat-only citation tokens in marketing docs are not sufficient substantiation for public performance claims. [A02] [A20] [A01]

**Close when:** each objective claim maps to a shipping feature, test or substantiation record, and approved wording. Report estimated differences separately from amounts an employer later corrected or actually paid; never describe the first category as recovered money.

### LEGAL-16 — Standard EULA use is valid, but neither a universal shield nor a complete operating policy

**Priority:** P1 · **Evidence:** current terms and legal review needed · **Owner:** publisher/consumer counsel.

The app links to Apple's Standard Licensed Application End User License Agreement and provides product-specific explanatory text. Apple's standard agreement applies where a custom one has not been provided; a custom EULA is not automatically required merely because the app has wage calculations. [R06] [R07] [A21] [A22]

**Required action:** have counsel check the contracting party, support contact, paid service description, corrections process, subscription cancellation/refunds, data ownership, and compatibility of any supplementary terms with Apple's agreement and mandatory consumer rights. Do not promise no refunds under any circumstances or require users to waive all rights as a condition of reading their own records.

Do not assume an “as is” or “not legal advice” clause neutralizes inaccurate marketing, unfair billing, known calculation faults, or every negligence claim. The available causes of action and enforceability of caps/exclusions depend on jurisdiction and facts; this review does not resolve them. Additional arbitration, class-waiver, indemnity, or choice-of-law clauses should not be copied into the app without jurisdictional and assent review.

**Close when:** the contractual structure is consistent and approved, with meaningful access before purchase and a versioned record of material changes. Keep the review document separate from binding customer terms; writing this file does not amend those terms.

### LEGAL-17 — Legal advice, accusation, recovery, and evidence-certification boundaries

**Priority:** P1 for current copy; mandatory gate before expanded services · **Evidence:** risk inference/conditional · **Owner:** product/support/counsel.

A configurable calculator is not automatically unauthorized legal practice. The risk changes if staff or an agent selects a worker's legal interpretation, declares a particular employer legally liable, drafts personalized legal demands, negotiates recovery, or presents itself as counsel. State rules differ; California's section 6125 is an example of the licensing boundary, not a complete nationwide analysis. [A23]

**Required action:** retain “expected,” “confirmed,” “possible difference,” and scope qualifiers. Do not automatically send allegations to employers or publish underpayment rankings. Support can explain what inputs and calculation rules produced a result without purporting to resolve the worker's legal entitlement. Direct unresolved agreement/legal questions to the worker's appropriate adviser or official agency; do not tell them that using the app suspends any filing or grievance deadline.

For reports, describe a worker-controlled record, not a certified payroll record, independent witness, legal audit opinion, or guaranteed admissible exhibit. Federal Rule of Evidence 901 illustrates that authentication requires support for what an item is claimed to be; a checksum alone does not establish authorship, truth, or admissibility. [A24] [R14] [R16]

**Close when:** support scripts, reports, product names/descriptions, and future automated outputs stay within the approved scope. Any representation, referral-fee, contingent recovery, or formal filing feature receives a separate legal review before implementation.

### LEGAL-18 — Worker sharing, confidentiality, minors, and safe-use messaging need balanced treatment

**Priority:** P1 for launch representations; conditional legal specifics · **Evidence:** product audience and risk assessment · **Owner:** product/counsel.

Paystubs or free-text notes may include another person's data, employer identifiers, or operational information. Restrict unnecessary collection and public sharing without imposing a blanket rule that workers need employer permission to discuss their own pay. NLRB guidance recognizes wage-discussion rights for employees covered by the NLRA; coverage and circumstances matter. Do not make a universal confidentiality or anti-retaliation promise. [A25]

The recorded App Store age rating is 4+, which is a content-rating outcome, not proof the product targets children or that all child-privacy obligations apply. COPPA's scope depends on child-directed services or relevant actual knowledge of collecting under-13 information. Define the intended worker audience and counsel-review any age restriction; do not add intrusive date-of-birth collection merely to create the appearance of compliance. [R09] [A26]

**Required action:** use synthetic training/test material; warn against including coworkers' identifiers and credentials in support examples. Frame the app as for use away from active electrical work or driving. Large tap targets are not certification for electrical gloves, safety equipment, or use in a hazardous task.

**Close when:** audience, content rating, privacy, and actual marketing agree; the app does not claim safety certification, employer invisibility, or guaranteed protection from retaliation. New child-directed marketing or user-to-user publication requires a fresh review.

### LEGAL-19 — Accessibility claims require feature-level evidence, not a coverage percentage

**Priority:** P1 for advertised accessibility; P2 for conditional market expansion · **Evidence:** reported tests and external limits · **Owner:** mobile QA/product.

The remediation record includes representative large-text, dark/light, and reduced-motion testing, but explicitly leaves physical VoiceOver and additional device/field combinations open. Do not turn those results into “fully accessible,” “ADA compliant,” or “all screens tested.” Apple's Accessibility Nutrition Labels concern actual supported features and should reflect appropriate verification. [R08] [A27]

The EU accessibility framework covers specified products/services and includes scope and exemption questions, including microenterprise service exemptions. Do not assume every standalone utility is automatically covered or exempt. US accessibility obligations likewise need a business/jurisdiction-specific assessment. [A28]

**Required action:** finish critical-flow screen-reader, largest-text, contrast, focus, error, and purchase/restore testing; document the exact devices and limitations. Keep accurate accessibility support statements even where a particular statute's application is unsettled.

**Close when:** any published accessibility claim maps to concrete acceptance evidence. Missing automated line coverage is not itself a legal violation, and 100% line coverage would not prove accessibility or legal compliance.

### LEGAL-20 — Compliance declarations and release credentials must remain owner-controlled

**Priority:** P1 per release · **Evidence:** source/release records and verification gap · **Owner:** account holder/release/security.

The release record contains user-approved content-rights, privacy, and export-compliance answers. They should be checked against the new release, not blindly reused and not silently reversed. The current backup uses CryptoKit SHA-256 for integrity; hashing is not equivalent to password encryption. Conversely, a “no backend” architecture is not a universal export-control conclusion. Follow Apple's export-compliance process for the actual binary and applicable exemptions. [R09] [R14] [A29]

**Required action:** validate the final app's privacy manifest, SDK inventory, encryption usage and declarations, content-rights rationale, age rating, territories, and subscription metadata. Adding future backup encryption, CloudKit, analytics, or new SDKs triggers a fresh declaration review. Manual Files-picker backup should not be relabeled as an app-owned iCloud synchronization service.

Review signing/API credential custody, minimum necessary access, CI artifact contents, and incident response. This review did not audit secret values or all historical commits and provides no “no secrets ever committed” certification.

**Close when:** each declaration has an attributable owner approval and source/binary rationale, credentials are not in repository artifacts, and significant changes invalidate stale sign-off.

### LEGAL-21 — Expansion, ad-tech, and operating obligations need change triggers

**Priority:** P2, before the triggering change · **Evidence:** conditional · **Owner:** founder/privacy/commercial counsel.

Marketing proposes later acquisition/measurement channels, not proof that tracking SDKs are already shipped. Preserve the current absence of a runtime advertising/behavioral SDK. Before identifiers, conversion events, pixels, email audiences, or third-party SDKs are introduced, assess platform tracking rules, consent, notices, minimization, vendor use, and international transfers. Never send wage amounts, union identifiers, paystub text, or discovered discrepancies as advertising events. [R11] [A05]

Before EU distribution, assess GDPR territorial scope and actual processing roles and verify Apple's DSA trader requirements; a small commercial publisher is not necessarily a non-trader. Other countries require separate assessment of wage terminology/rules, subscriptions, consumer remedies, taxes, and privacy. A storefront currency conversion does not establish legal or payroll localization. [A13] [A30]

**Required action:** document actual seller entity, operational locations, applicable taxes/Apple settlement responsibilities, support obligations, contributor ownership, and suitable technology errors-and-omissions/cyber insurance options. Insurance is risk transfer, not a substitute for corrections; coverage, exclusions, and territory require broker/counsel review.

Do not assume HIPAA, GLBA, FCRA, payroll-agent, or money-transmission regimes apply solely because a paystub contains financial information. Equally, do not assume they can never apply after adding lending, credit decisions, fund movement, employer processing, or regulated services. Treat those as separate product-approval gates.

**Close when:** the founder approves an actual market/processing map and a change-control checklist. No employer dashboard, account system, foreign subsidiary, or data warehouse is required by this review merely to launch the present narrow app.

## 5. Data-flow and disclosure map

This is a source-based map for verification, not a substitute for observing the release binary and publisher systems. [R02] [R06] [R12] [R14] [R15] [R16] [R19]

| Data/path | Current observed or documented behavior | Legal/operational check |
|---|---|---|
| Work, rates, rules, drafts, confirmed audits | Stored locally; calculations on device | Describe supported purpose, retained versions, correction and deletion accurately. Do not imply a publisher copy exists. |
| Original paystubs and OCR | Local originals plus local recognized text and field provenance | Limit unnecessary reuse; English OCR and page/size limits must not be sold as universal document support. |
| PDF report | Local generated file; user chooses sharing | Original pages excluded, but values/source text can still be sensitive. Preview and minimize. |
| Complete backup | State plus retained original files; not password-encrypted by the app | Explain inclusion, replacement restore, trusted destination, format/size limits, and provider responsibility. |
| iCloud Drive/other Files provider | User-selected export/import, not automatic sync | Do not claim provider upload completion from a save callback or claim local deletion removes provider copies. |
| Device/system backups | Depend on Apple/device settings | “Private by default” is more accurate than “never leaves the phone.” |
| StoreKit | Apple billing; app checks verified access and product metadata | Correct product approval, trial eligibility, renewal/cancellation, and local saved-record access. |
| Source/support/privacy links | Open external destinations chosen by user | Verify destinations and disclose relevant website/provider practices. |
| Support correspondence | Actual receiving system/retention not independently verified | Establish minimum-data support process and publisher notice. |
| CI/testing | Synthetic fixtures and retained verification artifacts are the intended practice | Inspect release/CI outputs; never export a real worker's evidence into tests or agent tooling. |
| Future advertising/analytics | Described as conditional; not established as shipped tracking | Require a new privacy and platform review before integration. |

## 6. Draft replacement wording

These are implementation proposals for review, not automatically binding terms or approval to change a submission.

### Product scope

> LinePaycheck estimates pay using the supported work rules you enter and confirm. It compares the paycheck facts you review. It does not check every legal or contractual entitlement. A match means only that the stated comparison matches within its displayed scope.

Show the specific missing categories and comparison scope nearby; do not rely on this paragraph alone to cure an overbroad headline.

### Privacy

> Your work records and paystub processing are private by default and run on your device. LinePaycheck does not operate a server storing your pay records. You choose whether to share a report or save a backup to iCloud Drive or another Files provider. Device backups follow your Apple and device settings.

### Dated rule change

> These rules start on [confirmed date] in [payroll timezone]. Previously recorded work keeps its existing rules. Review the before-and-after summary. Some work spanning a rule change may need additional review.

Use separate text for future-period changes and whole-period correction. Populate the date/timezone from actual saved state, not a device-default guess.

### Audit matches

> Gross total matches. This comparison covers the listed configured rules. Individual hours and earnings lines were not verified.

Use that only for a genuine gross-only match. For conflicting lines, use the actual `needsReview` result and describe the differences. Do not replace a valid detailed assessment with generic reassurance.

### Backup and report sharing

> This file contains sensitive pay information. Choose a private destination and review what is included. A backup contains retained original paystubs and is not password-encrypted by LinePaycheck. Deleting local records does not delete exported copies.

A report must describe its own actual contents rather than incorrectly borrowing the backup's original-document warning.

### Annual trial and Free option

> [Actual eligible trial duration] free, then [localized full annual price] each year until cancelled. Manage or cancel in Apple subscription settings. Continue free does not start a subscription; your unused first comparable paycheck audit remains available.

Render only the real eligible offer. Use immediate-charge language for non-trial monthly/yearly selections. Keep Apple's applicable cancellation timing visible and distinguish cancelling billing from deleting records.

## 7. Minimal remediation sequence

| Order | Deliverable | Accountable owner | Acceptance evidence |
|---|---|---|---|
| 1 | Live submission/binary/product audit | Account holder/release | Current build ID, source mapping, release option, subscription status, screenshot set. Any hold/replacement explicitly authorized. |
| 2 | Correct dated-change explanation | iOS/product | Three-scope tests and inspected confirmation with real date/timezone. |
| 3 | Supported-rule and audit-scope statement | Product/payroll counsel | Coverage matrix, accurate first-run/audit copy, no implication of comprehensive statutory compliance. |
| 4 | Publisher policy and support completion | Founder/privacy/web | Exact entity/contact, current policy version, functioning URLs and support channel, documented actual flows. |
| 5 | Paid-flow sign-off | Commerce/release | Eligible/ineligible live offers, annual/monthly price, restore/cancel/expiry, saved-data access, platform/state responsibility matrix. |
| 6 | Share/export minimization | iOS/privacy | Sensitive-source-text test, export preview, preserved originals, accurate provider/deletion warnings. |
| 7 | Name/content-rights decision | Founder/IP counsel | Dated clearance and asset/license/assignment register. |
| 8 | Incident and release checklist | Release/support/privacy | Reproducible build evidence, report/complaint triage, data-minimizing diagnostics, escalation owner. |

Do not spend effort on a generic compliance dashboard, collection-heavy consent platform, or centralized payroll database before these concrete items. Equally, do not use “Pareto efficiency” to defer correctness, truthful billing, or evidence preservation.

## 8. Incident, complaint, and correction procedure to establish

This is a proposed operating control; its existence is not established merely by this document.

When someone reports incorrect pay, lost records, unexpected charging, or exposure, record the app/build version and a minimal synthetic or redacted reproduction. Distinguish a product calculation bug, unsupported rule, incorrect input, ambiguous paystub layout, Apple billing issue, and a real employer dispute. Do not require a complete paystub to start triage.

Preserve relevant existing evidence without instructing the worker to reset/delete first. Route potentially material financial/data faults to engineering and the accountable publisher. If a shipped build is affected, assess warnings, correction releases, support/refund guidance, and any legally required notice with counsel. Do not silently replace historical findings with new-engine results; preserve the prior calculation and show any new assessment as a revision.

For a suspected security incident, establish the actual affected systems, data, recipients, and jurisdictions before concluding there is no breach because there is no app backend. Support mail, CI artifacts, credentials, and exported files are separate exposure paths. Have counsel assess any notification duties and deadlines for the actual event rather than adopting a universal timer.

## 9. Release approval checklist

These boxes intentionally remain unchecked. The document records work to verify, not legal approval.

- [ ] The actual submitted/released binary is mapped to reviewed source; no older automatic-release path is being overlooked.
- [ ] Store screenshots and feature claims depict the submitted build, not generated concept behavior.
- [ ] Statutory/contractual coverage limitations are clear at the relevant decision points.
- [ ] All three rule-change scope explanations match implemented behavior.
- [ ] Publisher identity, live privacy/support pages, and contact process are verified.
- [ ] App Privacy, required-reason API, content-rights, encryption, and age declarations have current evidence and owner approval.
- [ ] Live subscription products/offers, consent, cancel/restore/refund support, and continuing saved-data access are verified.
- [ ] Relevant renewal/notice responsibilities are assigned and documented, including platform-provided controls.
- [ ] Exported reports minimize unnecessary personal information; backup/security/deletion promises match actual behavior.
- [ ] Current name, icon, source agreements, dependencies, and contributor ownership have a rights decision.
- [ ] Device, accessibility, and real-worker acceptance gaps are accurately disclosed in release sign-off.
- [ ] Support and incident escalation are operational and use minimum necessary personal data.
- [ ] Counsel has reviewed unresolved launch-jurisdiction and consumer-contract questions.

## 10. Unknowns the founder must resolve

The repository does not establish all of the following: the exact registered publisher and contracting entity; corporate ownership/assignments; current external submission status; actual approved IAP availability; current website/support content and processors; all distribution countries; trademark clearance; asset permissions; insurance; tax treatment of settlement proceeds; or the publisher's country-specific data-processing obligations.

Keep a short private business record answering those questions. Do not put passports, full personal addresses, bank information, signing keys, API credentials, real paystubs, or private counsel communications into this file. Business-level revenue and processing facts, not just this app's user count, may matter to legal applicability.

## 11. Maintenance rules

Revisit this assessment when payroll scope changes; a named agreement pack is shipped; claims/marketing change; a new binary enters review; prices/trials/territories change; a new SDK or website/support processor is added; automatic cloud sync or encryption is introduced; an employer/regulator integration is proposed; or a material complaint occurs.

Close findings with a commit, reproducible test, external account receipt, or approved legal/business record as appropriate. Do not mark a legal check complete solely because a test coverage percentage improved. Preserve the distinction between fixed current source and older distributed binaries.

This document is not a promise that all possible legal risk has been found. It is the current, source-grounded remediation register for the reviewed product scope.

## 12. Repository evidence register

All links below are pinned to the reviewed commit. Their contents are evidence of source or recorded observations, not automatic proof of the current external App Store or website state.

[R00]: https://github.com/streamentry/linepay/tree/105b024e283c70e07375f53cc4da11010441e5a2
[R01]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/AGENTS.md
[R02]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/AppModel.swift
[R03]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/DomainModels.swift
[R04]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/Packages/LinePayDomain/Sources/LinePayDomain/PaycheckAssessment.swift
[R05]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/PayProfileSetupView.swift
[R06]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/AboutLinePayView.swift
[R07]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/AppLinks.swift
[R08]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/docs/plan/ios-1.0-remediation.md
[R09]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/docs/release-build-2-2026-09-05.md
[R10]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/docs/pricing.md
[R11]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/docs/marketing.md
[R12]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/OnboardingPaywallView.swift
[R13]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/SubscriptionStore.swift
[R14]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/BackupArchive.swift
[R15]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/EvidenceStore.swift
[R16]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/ReconciliationReportExporter.swift
[R17]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/assets/README.md
[R18]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/docs/research/california-outside-line-2022-2027.md
[R19]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Sources/TemporaryExports.swift
[R20]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/App/Resources/PrivacyInfo.xcprivacy
[R21]: https://github.com/streamentry/linepay/blob/105b024e283c70e07375f53cc4da11010441e5a2/apps/ios/project.yml

| Reference | Evidence used |
|---|---|
| R00–R01 | Repository inventory, product identity, invariants and agent/release constraints. |
| R02–R05 | Prospective rule protection, modeled rule categories, scope-aware audit, and the three-choice/two-description UI mismatch. |
| R06–R07 | Current bundled legal/support content and external policy/contact destinations. |
| R08–R09 | Current remediation record versus dated build-2 external submission state. |
| R10–R13 | Canonical revised pricing/trial decision, proposed marketing, actual paywall and StoreKit access code. |
| R14–R16, R19 | Backup contents/checksum, local file protection, report source-text export, temporary-copy cleanup. |
| R17–R18, R21 | Asset provenance/concept warnings, limited agreement research, and development/runtime dependency distinction. |
| R20 | Manifest declarations requiring verification against the actual final binary. |

## 13. Legal and platform authority register

Sources consulted for the September 6, 2026 assessment. These links support the identified principles; applying them to the publisher and a particular worker requires the missing factual and jurisdictional analysis. Proposed rules are not treated as enacted requirements. Primary text is paraphrased, not reproduced as a substitute for the source.

[A01]: https://developer.apple.com/app-store/review/guidelines/
[A02]: https://www.ftc.gov/legal-library/browse/ftc-policy-statement-regarding-advertising-substantiation
[A03]: https://www.dol.gov/agencies/whd/fact-sheets/23-flsa-overtime-pay
[A04]: https://www.dol.gov/agencies/whd/fact-sheets/56a-regular-rate
[A05]: https://developer.apple.com/app-store/app-privacy-details/
[A06]: https://developer.apple.com/app-store/subscriptions/
[A07]: https://www.law.cornell.edu/uscode/text/15/8403
[A08]: https://www.ftc.gov/news-events/news/press-releases/2026/03/ftc-seeks-public-comment-response-advance-notice-proposed-rulemaking-regarding-negative-option
[A09]: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=17602.
[A10]: https://oag.ca.gov/privacy/ccpa
[A11]: https://privacy.ca.gov/laws-and-regulations/monetary-thresholds-in-the-ccpa/
[A12]: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22575.
[A13]: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679
[A14]: https://www.pdpc.gov.sg/data-protection-obligations
[A15]: https://www.lycorp.co.jp/en/news/release/008632/
[A16]: https://www.uspto.gov/trademarks/search/likelihood-confusion
[A17]: https://www.uspto.gov/trademarks/search/comprehensive-clearance-search-similar-trademarks
[A18]: https://newsroom.loc.gov/news/copyright-office-releases-part-2-of-artificial-intelligence-report/s/f3959c36-d616-498d-b8f9-67641fd18bab
[A19]: https://www.copyright.gov/title17/92chap1.html
[A20]: https://www.ftc.gov/business-guidance/resources/consumer-reviews-testimonials-rule-questions-answers
[A21]: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
[A22]: https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/
[A23]: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=6125.
[A24]: https://www.law.cornell.edu/rules/fre/rule_901
[A25]: https://www.nlrb.gov/about-nlrb/rights-we-protect/your-rights/your-rights-to-discuss-wages
[A26]: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
[A27]: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/
[A28]: https://europa.eu/youreurope/business/selling-in-eu/selling-goods-services/accessibility/index_en.htm
[A29]: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
[A30]: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/

| Reference | Authority and limited proposition |
|---|---|
| A01 | Apple App Review Guidelines: app completeness, accurate metadata, subscriptions, privacy and IP; platform rules, not a court's legal clearance. |
| A02 | FTC advertising-substantiation policy: support objective express/implied claims before disseminating them. |
| A03–A04 | US Department of Labor guidance: workweek overtime and regular-rate principles; not an individualized worker determination. |
| A05 | Apple's specific label definitions, optional-disclosure criteria, privacy URL and tracking guidance; distinct from statutory privacy scope. |
| A06 | Apple subscription product/disclosure guidance and platform billing behavior. |
| A07 | ROSCA, 15 USC 8403: material terms, informed consent and stopping recurring charges. |
| A08 | FTC March 2026 negative-option ANPRM: expressly recognizes the vacated 2024 rule; not a replacement final rule. |
| A09 | California BPC 17602: amended automatic-renewal requirements; relevant amendments apply to contracts entered, amended or extended on/after July 1, 2025. |
| A10–A12 | California privacy scope guidance, current monetary adjustment, and CalOPPA's distinct statute. |
| A13 | GDPR, including territorial scope, controller/processing definitions, lawful basis, sensitive union data, transparency and security; applicability must be established. |
| A14 | Singapore PDPC data-protection obligations; conditional on the actual organization's legal/processing nexus. |
| A15–A17 | Primary evidence of LINE Pay commercial use and USPTO clearance/confusion guidance; not a completed search or infringement opinion. |
| A18–A19 | US Copyright Office human-authorship guidance and Copyright Act expression/fair-use framework. |
| A20 | FTC consumer-review/testimonial rule guidance; separate from Apple's review-manipulation policy. |
| A21–A22 | Apple standard EULA and optional custom-license process. |
| A23 | California unauthorized-practice statutory boundary; other jurisdictions require their own analysis. |
| A24 | Federal Rule of Evidence 901: authentication is a distinct evidentiary requirement, not established solely by an app-generated report. |
| A25 | NLRB wage-discussion guidance for covered employees; no universal workplace confidentiality rule is inferred. |
| A26 | FTC COPPA guidance: child-directed/actual-knowledge analysis, not an inference from a 4+ store rating alone. |
| A27–A28 | Apple accessibility-feature disclosures and EU accessibility scope/exemptions; not a blanket legal certification. |
| A29–A30 | Apple export-compliance process and EU DSA trader information requirements. |

**Final position:** preserve the small local-first product, close the concrete misleading-copy and release-evidence gaps, and keep promises no broader than the software and business can support. The legal work should sharpen the product's truthfulness, not expand its data collection or bury its limitations in boilerplate.
