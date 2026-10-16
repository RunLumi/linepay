# ADR 0019: portable rule drafts and recipient provenance

Status: accepted for the owner's all-stage/local-only v2 request, October 17, 2026. Browser file
exchange is implemented; native UI/Android and public/device release evidence remain pending.

Use the [portable rule-draft contract](../../shared/contracts/templates/README.md) for explicit
manual sharing. Keep it separate from financial-state backups and verified agreement packs. A draft
contains selected configured parameters, not worker/time/paycheck/fund/evidence records. Omit wage
and per-diem amounts by default. Copy them only on explicit inclusion and exact-file review. The
public template ID is freshly chosen by the caller, never copied from a private profile or ledger.
No account, automatic transfer, recipient lookup, remote analytics or backend is introduced.

The scope remains worker-provided/unverified. Do not convert a title, UUID, rights checkbox or file
hash into publisher/union/counsel approval. No named agreement or source library ships through this
work. Rights and applicability review for any future official pack remain independent gates.

v1 explicitly supports highest-applicable premium combination, ordered daily/weekday parameters,
isolated callout minimum and flat worked-date allowance, with exact bounded decimal strings and
explicit rounding. Known unsupported conditions refuse export/adoption. Standard JSON parsers own
syntax; an additional object-key scan rejects duplicate/escaped aliases before typed admission.
Native and browser codecs share fixtures; no third-party runtime JSON library or shared calculation
implementation is added. Native code reads Data/explicit arguments, not files, random IDs, clocks,
locale, UI, network or storage. Native callers use the exposed calculation policy.

Every import is inspection first. The recipient must confirm their own hourly amount and listed
rules/applicability. Configured-but-omitted allowance amounts require an explicit own-amount or
not-applicable choice. Absent configuration is not waived entitlement. Adoption creates a new
profile and leaves existing periods/history unchanged. Monetary choices and original draft are
retained separately so a profile cannot silently rewrite what was confirmed.

Web state v3 adds `templateOrigins`: profile ID, complete admitted packet, recipient hourly/allowance
choices and their confirmation flags. Validate the origin against the new profile, reject orphaned
origins or conflicting payloads under one external ID/revision, and save both atomically using the
existing revision guard. This is provenance of worker input, not authenticated authorship. Existing
v1/v2 schemas migrate explicitly by adding only empty missing metadata; original wage/fund records
and engine receipts remain byte-for-value unchanged. A frozen synthetic v2 fixture was generated
and validated with actual commit `3edf4bd` modules, complementing the earlier v1 fixture.

The snapshot-container/encryption versions do not change. New web backups retain draft/recipient
provenance; old v1/v2 backups remain inspectable/recoverable. Unknown schema fields and future
versions fail closed. Native state backup admission remains unsupported until a complete financial
schema migration exists. The separate Swift codec does not establish native Files UI, storage,
profile-source persistence, Android interoperability or App Store readiness.

Verify shared admission and privacy defaults in pure JavaScript/Swift tests. Use actual browser
export/inspect/confirm, separate sender/recipient contexts, changed-value refusal, and encrypted
recipient reset/recovery. Preserve source versus local/CI/browser/device/store evidence separately.
A passing synthetic handoff is not production crew-usage or commercial-rights evidence.
