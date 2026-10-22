# Portable financial state v1

[Shared contracts](../README.md) · [Password-protected transport](../backup/README.md) · [ADR 0034](../../../docs/adr/0034-portable-financial-state.md)

This is a typed, user-directed manual-transfer format inside the existing LPBENC01 envelope. It is not shared runtime code, cloud sync, or evidence that a client adapter works. Pay data remains local unless the user explicitly exports a file; the format adds no account, server storage, analytics, or upload path.

## Whole-file contract

`schema-v1.json` is the closed schema for `com.streamentry.linepay.portable-state` version 1. Before export, a client inventories its entire financial state. If it finds any unsupported saved financial kind, draft, original, or evidence item, it refuses the whole export. It never emits only the records it knows how to serialize. Destination-owned StoreKit/trial state, onboarding/navigation state, local diagnostics, and local activity history are excluded by design; their presence alone does not block a financial export.

A receiver validates the complete payload, separates hard storage/admission blockers from calculator activation-review notices, and prepares a replacement preview before a separate user confirmation. A schema, reference, size, storage-capability, decode, or commit failure leaves every existing record and file unchanged. Activation-review notices keep only the incompatible selected context read-only; they do not discard a different current workspace or future default. There is no partial import, silent subset, second-format fallback, or automatic cloud path. Unknown properties and unsupported file versions fail closed.

## Preserved records and identity

V1 carries typed pay profiles, versioned rule snapshots and effective changes, rule timelines, period windows, current and historical work snapshots, work corrections, frozen paycheck receipts and assessment revisions, optional original bytes, and any weekly regular-rate result embedded in a supported calculation. A paycheck receipt retains its own target window/cadence and rule changes separately from its parent period; a historical assessment revision may therefore keep a different context without rewriting the parent.

A receipt preserves its paid statement facts and confirmations, the exact work snapshot and rules, calculation components and source traces, producing engine metadata, assessment scope/verdict/comparisons/reasons, weekly-review-pending state, and separate reconciliation when present. Receivers retain the frozen result as read-only evidence. They do not recalculate it during import or relabel it as a legal determination.

`calculation.ruleChangeRefs` retains the immutable change context recorded for that calculation. It can include future changes present in its frozen input context; each component's applied-agreement trace identifies the rules affecting that component. Map these references from the calculation's own frozen receipt/period inputs, never a later current profile or period. A native model that demonstrably calculated with an empty input list can record `[]`; an unrecoverable required context must not be invented.

Portable IDs are stable across re-export and distinct from each app's local database IDs. `identityCrosswalk` maps every typed portable identity to its original client and local ID; records without a source identity use a marked derived ID. The destination persists this crosswalk. A native work ID may recur in multiple frozen snapshots whose facts differ; those snapshot-local fact versions remain separate. References from a calculation resolve against the exact work snapshot selected by its period or receipt.

`source` describes the current exporter and format version. Original receipt producers remain in each receipt, and each original record's client/local ID remains in the crosswalk. Re-exporting from another client updates current exporter metadata without replacing historical financial provenance.

## Active profile and explicit adoption

`profiles` can retain up to 100 typed records. `activeProfileRef` identifies the saved global/default profile for **new periods**; it may be null while the user reviews imported data or configures a default. The current open workspace is selected independently by the one period whose `isCurrent` is known `true`; that period's `profileRef`, `ruleRef`, and selected work snapshot identify the rules and facts used now. Its profile may differ from `activeProfileRef`. `profile.currentPeriodRef` is per-profile context, not a global current-period selector. At most one period may be known current; older clients may leave this flag null with an explicit marker.

Restore confirmation and profile adoption are separate. If the complete source profile, rules, work, and receipts are represented by the target, the restore preview may preserve its global/default pointer when the user confirms replacement; an adoption record is not required just to preserve immutable history. Later explicit work edits or period rollover may advance current-work/current-period pointers, while prior work snapshots, rules, windows, and receipts remain unchanged. Restoring a compatible new-period default does not silently retarget an already-open period.

If material configuration is absent from the source, the target cannot calculate from a material rule/context field, or the user actually edits rules/profile settings, the worker creates a separate confirmed profile and rule snapshot. The source profile, rules, work, periods, and receipts remain unchanged. The `adoptions` record links source and adopted profiles, periods, work snapshots, and the exact rule snapshots confirmed at that time, with the confirmation time and a schema-enumerated set of configured fields. The prior known-current period may be marked noncurrent and a new adopted period made current; the original window/rules/work/receipt remain frozen. The global/default pointer remains on the prior profile unless the user separately chooses the new profile for future periods. Adoption lineage stays frozen when current pointers later advance. The new profile points back to its source with `adoptedFromProfileRef`. Adoption cannot clear weekly/statutory applicability or legal-coverage uncertainty through a generic confirmation.

## Exact values and unknown source fields

- Every monetary amount, rate, multiplier, hour quantity, worked-second quantity, and difference uses a bounded decimal **string** with no exponent, locale separator, binary float, or implicit currency. The wire grammar allows up to 24 integer digits and 128 fractional digits. This is a frozen-value transfer envelope, not an editor precision promise: for example, iOS number entry accepts at most 8 fractional digits, while its exact `Decimal` calculation trace for one second divided by 3,600 has more than 38 fractional digits. The fractional envelope covers Foundation decimal exponents down to −128; the 24-digit integer ceiling is a deliberate portable-format bound, not the full Foundation numeric range. A client refuses the whole file when a stored value exceeds either bound. Exporters and importers preserve each original decimal string exactly and never normalize or round a frozen trace.
- Amounts carry an explicit currency. Clients do not sum across currencies.
- Source OCR coordinates/confidence use a separate finite `sourceScalar` string with exponent spelling allowed and range checks; this does not widen the payroll decimal grammar.
- Work intervals and breaks use integer Unix seconds with the original IANA timezone. Periods retain local start/end-exclusive dates and timezone; stored exact instants are included and checked. If the source stored only local dates, it uses `localDatesOnly` with null instants and explicit `fieldsNotRecorded` markers. A receiver never invents boundaries from a device calendar.
- A null source field means unknown/not stored only when the owning record's `fieldsNotRecorded` names that field (including dotted paths). An empty array is a recorded empty collection. An absent pay rule is not converted into zero, a waiver, or a confirmed rule.
- Original attachments carry their exact bytes, purpose, source metadata, safe display filename, byte count, and SHA-256. Local paths never cross the boundary. A missing byte payload or digest mismatch invalidates the full file. A receiver without a private original-file store refuses the entire file if any attachment is present.

The source inventory counts serialized work/component occurrences across snapshots/calculations; the same portable work or component ID can therefore occur more than once. `periodWindowCount` counts distinct typed window identities. Unsupported record lists and omitted-record count must be empty/zero in any valid portable file.

### Supported timezone namespace

`$defs.timeZone.enum` contains 598 exact-case names from the normal data build of
[IANA tzdata 2026e](https://www.iana.org/time-zones/releases/2026e), released September 29,
2026. This is the supported v1 transfer namespace, not every optional published timezone.
It includes `Zone` names and `Link` names from `africa`, `antarctica`, `asia`, `australasia`,
`europe`, `northamerica`, `southamerica`, `etcetera`, `factory`, and `backward`: the release
Makefile's `PRIMARY_YDATA`, `etcetera`, `NDATA`, and enabled backward compatibility data.
Optional `PACKRATDATA=backzone` is excluded; its additional `Asia/Hanoi` name is outside this
version's supported namespace. Real legacy names such as `US/Eastern`, `EST`, `CET`,
`Etc/UTC`, and `GMT+0`/`GMT-0` remain accepted without rewriting their spelling. Parser-only
abbreviations such as `PST`, `CST`, and `IST`, invented offsets, and case variants are refused.

The enum is the sole shipped namespace resource. Public native parsers are insufficient for this
boundary: some accept extra abbreviations, while browser enumeration omits real IANA aliases.
Receivers still check native timezone availability before using a name for calendar calculations.
Namespace admission does **not** establish that the installed transition rules are from 2026e,
are current, or match another device. No offsets or transition tables are bundled here.

The selected source files and `LICENSE` are public domain under the release's license notice.
The official archive is pinned by SHA-256
`b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652`.
The sorted names joined with one LF after every name have SHA-256
`8725722643bf1f4ff4fc4b22268ade98b6fae047a86897219c3a13d4c4ced93d`.
Regenerate only from the official archive, never from host timezone files:

```sh
curl --fail --location https://data.iana.org/time-zones/releases/tzdata2026e.tar.gz --output /tmp/linepay-tzdata2026e.tar.gz
python3 shared/contracts/portable-state/generate_time_zones.py /tmp/linepay-tzdata2026e.tar.gz
# After reviewing a deliberate namespace update, use the same command with --write.
```

The generator verifies the archive digest, release version, selected names and namespace digest;
without `--write` it only compares the schema. A later namespace update requires reviewing the
official release/license, updating pinned provenance and regression expectations, and synchronizing
the exact schema bytes in each client. It does not silently update native calendar behavior.

V1 intentionally excludes separate employer-benefit receipts, separate weekly-review receipts, crew rule origins/templates, follow-up/resolution events, agreement extraction/review workflow state, and in-progress financial drafts. If any are retained by the source, export refuses the whole file. A weekly-pending paycheck itself is supported and keeps its original verdict and reasons. It can remain `NOT_COMPARABLE` when a period-confirmation failure takes precedence; it may never become a clean match or directional result while weekly review is pending.

## Target capability preflight

The independent verifier models the following v1 receiver boundaries. They are adapter targets, not runtime or release evidence.

| Receiver | Current workspace and new-period default | Whole-file limits |
|---|---|---|
| iOS | The selected current period and global/default profile are checked independently; all modeled v1 work kinds and configured rules are supported; original evidence is supported | Up to 100 retained profiles; separate benefits, weekly-review receipts, crew origins, and agreement-extraction workflow are outside v1 |
| Web | The selected current period and global/default profile are checked independently; calculator needs review for configured regular schedules, date premiums, non-1 outside-schedule multiplier, or a weekly-overtime rule it cannot calculate | Up to 100 retained profiles; no private original-attachment store |
| Android v3 | The selected current period and global/default profile are checked independently; calculator needs review for nonregular work, multiple daily tiers, schedules, weekday/date premiums, callout minimums, or weekly rules | Up to 100 retained profiles; no private original-attachment store; weekly-pending verdict is preserved |

Inactive source profiles and historical receipts remain typed records and are not silently flattened. Whole-file admission blockers include unpreservable originals, unsupported financial kinds/drafts, schema/reference errors, and hard size/retention limits. Separately, `target_activation_review` reports rule/work contexts the native calculator cannot safely activate. It checks both `activeProfileRef` (new-period default) and the unique known `isCurrent` period (current workspace); such notices keep a context read-only or require adoption but do not discard the other context or block a fully preservable file. Any whole-file blocker means `canReplace` is false and there is no importable subset.

The activation review resolves each referenced rule change to its frozen `ruleRef`, including future-effective changes retained on a current period. A scheduled change after a period's end does not expand that period's allowed work-time bounds. Selected rule numbers are also checked against each calculator's exact parser capacity (Foundation `Decimal` on iOS; 12 fractional places on Web and Android). A number outside that capacity remains preserved in the typed file but requires a separate native configuration before calculation; this does not narrow the decimal grammar for frozen receipt traces.

## Size and integrity

LPBENC01 remains unchanged: fixed PBKDF2/AES-GCM parameters, authenticated header, and a 64 MiB complete-file maximum. Each original is at most 25 MiB; there are at most 512 originals; non-attachment financial JSON is at most 8 MiB. Base64 expansion counts toward 64 MiB. Records and attachments are never truncated to fit.

Password protection provides confidentiality when the password is strong and detects authenticated-region damage. It does not identify the file's author or prove a rule's legal applicability, source approval, or employer verification.

## Independent contract gate

All checked-in records are synthetic. Run the standard-library verifier and tests:

```bash
python3 shared/contracts/portable-state/verify.py check
python3 -m unittest discover -s shared/contracts/portable-state/tests -p 'test_*.py'
python3 shared/contracts/portable-state/verify.py check shared/contracts/portable-state/fixtures/adoption-after.json
```

`common-weekly-pending.json` is the five-shift Android receipt with an exact current work ledger and canonical `needsReview` verdict carrying the source `WEEKLY_REVIEW_PENDING` reason. The verifier also recognizes the exact Web and iOS weekly-review reasons without rewriting them; unrelated text containing “weekly” and “pending” does not satisfy the pending-reason guard. `adoption-before.json` and `adoption-after.json` prove the contract shape for preserving source profile/receipt while a separately confirmed profile becomes current; tests assert original records and IDs remain unchanged. Another test keeps future default B selected while A is the current workspace, adopts current A as C, and verifies the independent pointers. A post-adoption rule edit and period rollover test proves the adoption receipt still points to the exact initially confirmed rule snapshot. `attachment-valid.json` supplies a synthetic original for iOS-only capability tests. The decimal trace regression covers native 1-second/1-minute repeating values, a minimum admitted rate, and exact JSON string roundtrip beyond Python's default 28-digit decimal context. `refusal-cases-v1.json` exercises closed fields, inventory, decimal grammar, references, time ranges, weekly-pending integrity, attachment hashes, hard whole-file refusals, and calculator activation-review notices.

These checks prove only the shared schema and independent structural/range/identity/reference/hash/preflight contract. They do not prove native export/import, UI confirmation, atomic replacement, device behavior, or real cross-client E2E. Each client must pass those integration gates separately.
