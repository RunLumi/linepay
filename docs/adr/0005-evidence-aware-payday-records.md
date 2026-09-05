# ADR 0005: Evidence-aware payday records

Status: accepted for the iOS 1.0 readiness repair.

## Context

The [readiness audit](../linepay-1.0-readiness-audit.md) found that a gross-only verdict, one active period, and replace-in-place paystub correction did not support a trustworthy repeated payday workflow. This decision refines ADR 0004 without replacing its local document store or introducing accounts, servers, payroll integrations, or an autonomous agreement interpreter.

## Decisions

### Compare like with like

Keep expected wage earnings separate from expected per-diem components. A worker confirms whether the paystub's gross includes per diem. Unknown basis is not comparable; the application does not infer tax treatment from a label.

A full-paycheck comparison also requires the worker to confirm that the complete work period is recorded. A partial or unconfirmed work log stays not comparable and does not consume the first free audit. Assessment engine version 2 records this boundary; earlier saved assessments retain their original version and meaning.

The pure domain assessment records the comparison basis, scope, confirmed component comparisons, unresolved mappings, verdict, and engine version. Gross equality alone is described as **Gross total matches**, not a clean component audit. Offsetting component discrepancies and material unknowns qualify the verdict. Hours are compared only with an explicitly confirmed hours/layout basis. Premium-only and full-rate earnings layouts are distinct representations.

These rules describe software comparison semantics, not a new compensation entitlement.

### Close work without stranding a delayed paycheck

One period is current for work entry. Closed periods retain their frozen work, agreement, payroll timezone, and calculation and can await a paycheck while the next period accepts work. History can attach that later paycheck to its original period.

Corrections append an audit revision. They do not recalculate a closed period against today's agreement or erase its earlier confirmed audit. Manual correction retains the existing original unless the worker explicitly replaces or removes it.

An active-period correction validates work containment and overlaps. Future-rule editing is the default; applying changes to the current period requires an explicit choice and successful validation. Changing the payroll timezone closes the old work period on its original boundary and requires an explicit new start rather than guessing overlapping midnights in different zones.

### Persist unfinished work and evidence ownership

Schema 2 adds setup, work and paystub-review drafts, audit revisions, and a retryable evidence-deletion queue. Source files remain separate from structured state. The v1 decoder supplies new metadata without recomputing historical money; a legacy comparison without a confirmed basis requires review.

Import ownership begins before the first asynchronous file/photo read. One operation owns the review, and cancelled/stale completions cannot overwrite a newer session. Progress distinguishes input not yet saved from an original already safely staged before OCR. OCR failure does not delete the staged original.

Field editors persist directly while pushed above the review list; saving cannot depend on an inactive parent view receiving a change callback.

An interrupted original written before a failed state commit is rediscovered by its app-generated UUID filename and queued for cleanup after relaunch. Unknown files and external exported copies are preserved.

Undo carries the original period identity and work revision. Rollover or intervening mutations invalidate stale Undo rather than inserting a prior shift into a new period.

Explicit evidence removal updates references and retains a retryable cleanup record if physical deletion fails. All application-owned temporary exports are included in local cleanup. User-exported Files/iCloud copies are outside that operation and are disclosed as such.

### Preserve platform services without central infrastructure

StoreKit entitlement lookup is independent of product-price loading. A metadata/network failure does not prevent checking signed local entitlement information. Backup restore does not grant Pro or reset previously consumed free-audit access. Existing worker-owned records remain accessible without Pro. Audits performed with verified Pro access do not consume an unused Free audit. Annual trial presentation requires actual free-offer metadata and eligibility; duration and renewal dates come from StoreKit.

An optional schema-2 onboarding progress field preserves the first work draft and first expected-pay proof across interruptions. Existing snapshots without this field resume their normal navigation.

## Consequences

More state is explicit, but no new persistence framework or remote service is introduced. Whole-document storage remains bounded and validated. Existing full backup/restore support must include drafts, audit revisions and retained originals, remap imported physical filenames, and preserve historical values.

The original readiness audit remains an immutable record of its reviewed commit. Track remediation and proof separately in [ios-1.0-remediation.md](../plan/ios-1.0-remediation.md). Source presence, passing unit tests, executed UI journeys, and real-device release acceptance are different evidence levels.
