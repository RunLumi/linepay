---
title: Supported rules and important limits
linkTitle: What the app can check
weight: 180
group: Get help
description: Know when the app’s calculation fits your agreement and when to leave the result incomplete.
keywords: [limitations, unsupported, weekly overtime, union, agreement, CBA, taxes, callout]
---
## A configured tool, not an agreement authority

LinePaycheck estimates and compares pay from your recorded work and confirmed rules. It is not payroll software, a tax calculator, legal advice, an employer portal, or an autonomous interpreter of a collective bargaining agreement.

The iPhone setup currently uses a U.S.-dollar base rate and one active pay profile. Android parity, web access to your wage history, multiple-employer management, automatic employer imports, and live cross-device synchronization are not features these guides promise.

## What the current setup represents

The setup includes actual work intervals, multiple unpaid breaks, daily overtime tiers, a restricted weekly regular-rate review for a confirmed complete workweek, Sunday and additional weekday premiums, specific-date premiums, a same-day regular schedule and outside-schedule multiplier, an isolated callout-minimum variant, flat per diem by worked local date, source references, and rule effective dates.

Supported premium overlaps use the highest applicable multiplier; they do not stack. Actual worked time remains separate from guarantee entitlements. Expected wages remain separate from per diem until you select a confirmed comparison basis.

This describes available rule shapes, not a statement that all agreements using similar words have identical meaning.

## Callout coverage is deliberately narrow

The current callout model treats **one saved Callout row as one confirmed physical callout event**. A configured minimum can add one isolated guarantee for that event while leaving actual worked time unchanged.

When adjacent Callout rows are known to be continued segments of the same physical call, merge them rather than allowing row count to create another minimum. When another triggering call really occurred, keep it separate even if the times happen to touch. LinePaycheck does not infer event identity from adjacency, notes, employer, or job description.

Discontinuous duty, regular-shift overlap, mixed pricing within the minimum window, a minimum spanning an effective-rate change, canceled/reporting calls, rest/fatigue rules, and other agreement-specific callout interactions are not generalized by this isolated variant. They can produce **Needs review** or an unavailable calculation instead of a guessed amount.

Older callout rows that predate event identity remain ambiguous until explicitly reviewed. The app must not retroactively assign them to one event merely because that would produce a cleaner result.

## Do not approximate missing rules

The restricted weekly review is available only after you explicitly confirm a covered, nonexempt hourly profile and a complete single-employer workweek. It does not establish state/local, public-agency, exemption, union/CBA, alternative-method, or universal federal coverage. Rest-period premiums, unusual stacking, meal penalties, travel guarantees, and overnight regular-schedule windows are not automatically inferred by the setup. More specialized agreements may have further requirements not represented here.

Use **I don’t see my rule** in setup and record what is missing. A nonempty missing-rule note marks coverage as incomplete. Do not hide the limitation by adding fake hours, setting a misleading base rate, or choosing a near-enough rule.

A dated change can also create a callout guarantee whose correct rate depends on agreement-specific interpretation. The app can retain the work while requiring review rather than inventing a price for that guarantee.

## Paystub mapping has its own limits

A total can be comparable while individual lines remain unmapped. Full-rate versus premium-only reporting, paid-equivalent hours, guarantee placement, and unusual multipliers require care. The current standard hourly line mapping is designed around 1×, 1.5×, and 2× categories; other multipliers can require manual review rather than an automatic line-level conclusion.

Unreviewed OCR fields do not become confirmed paid facts. Blank is not zero. A gross-only match does not establish that all hours, allowances, deductions, or contractual rules were audited.

## What to do when your case does not fit

Keep the real work and source documents. Mark missing coverage, read the scoped result, and ask payroll or a qualified adviser to clarify the relevant rule. Share a narrowly framed question or an audit report where helpful.

Check app-version notes and the guide’s review date when behavior differs. These guides explain the inspected implementation; they are not independent confirmation that every distribution build, agreement, device, or purchase path has been release-validated.

Next: [Ask for help safely]({{< relref "/support" >}}).
