# iOS 1.0 implementation notes

These notes capture non-obvious implementation decisions made while turning the 1.0 plan into working code.

## Actual work remains actual work

Unpaid breaks are modeled as exact intervals inside a work interval. The clock span is preserved and break segments are removed before schedule/day/overtime slicing. This prevents a 10-hour presence with a 1-hour unpaid break from becoming a fabricated 9-hour clock shift.

Callout guarantees remain derived pay components. A worker who actually worked 7 hours under a 10-hour guarantee still has 7 hours of work facts plus a separate 3-hour-equivalent guarantee component.

## Historical meaning is snapshot-first

A completed pay period freezes its agreement snapshot, work facts, calculation result, confirmed paycheck facts, reconciliation, and evidence metadata. Editing current rules never recomputes archived history.

## OCR is a suggestion layer

Vision OCR runs locally and can prefill recognizable money lines. It never creates a pay rule and its output is not trusted until the user confirms structured fields.

Manual paycheck entry is always available.

## Free audit is a pay-period entitlement

The first completed paycheck audit consumes the global free-audit allowance, but that pay period remains re-auditable if the worker corrects work or paystub facts later. LinePay does not punish correction with a paywall.

## Pro appears after value

Onboarding contains no subscription step. The first audit is free. A later new-pay-period audit requires Pro in commerce-enabled builds, while debug builds remain frictionless for deterministic testing.

## Persistence is deliberately small

The current dataset does not justify a relational object graph. The versioned local state document provides atomic commits, simple backup/recovery, and explicit immutable snapshots. ADR 0004 defines the trigger for reconsidering SwiftData/indexed persistence.
