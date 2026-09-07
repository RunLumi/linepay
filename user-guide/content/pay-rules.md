---
title: Configure the rules that apply
linkTitle: Overtime, callouts, and per diem
weight: 50
group: Record your work
description: Understand daily and restricted weekly overtime, date premiums, callout minimums, and separate per-diem amounts.
keywords: [OT, double time, daily overtime, weekly overtime, Sunday, holiday, guarantee, allowance]
---
## Confirm your agreement, not a common example

Open **Settings → Edit pay rules → Your rules**. Optional rules remain off until you enable them. The app does not infer an agreement from your employer, local, job title, or location.

A calculation can only cover what the app represents and you confirm. Keep a missing-rule note rather than approximating an unsupported entitlement.

## Daily overtime and additional tiers

Enable **Daily overtime**, then enter **After worked hours** and the applicable **Multiplier**. Use **Add another overtime tier** when your confirmed daily rule has additional thresholds.

A synthetic example: after eight worked hours at 1.5×, ten hours at a $50 base rate produce eight hours at $50 and two at $75: $550 before any other applicable rule. This is an illustration, not a default policy.

Multiple entries on the same payroll-local date share the daily overtime calculation. Unpaid breaks do not count as worked time. A weekly threshold is different from a daily threshold: do not enter 40 as a daily threshold to simulate weekly overtime.

## Restricted weekly overtime review

For a confirmed covered, nonexempt hourly profile, enable **Weekly overtime (restricted)** and choose the payroll workweek start. Open **Pay → Review weekly overtime**, select the workweek, and confirm that the week is complete before calculating. The review can include recorded work from more than one stored pay period.

This is a restricted estimate for one complete workweek. It does not determine state, local, public-agency, union, CBA, exemption, or alternative-method coverage. If the week is incomplete, historical weekly rules differ, or the inputs cannot be combined safely, the review stays **Needs review**; keep the actual work and clarify the rule instead of adding hours or treating the result as a legal conclusion.

## Weekdays, dates, and outside-schedule pay

**Sunday premium** sets a Sunday multiplier. Under **Other weekdays**, add another weekday premium. Under **Holidays and specific dates**, use **Add premium date** for the particular dates and multipliers you have confirmed. The app does not maintain an automatically authoritative holiday calendar for your agreement.

**Outside-schedule pay** lets you enter the same daytime regular schedule on selected weekdays and an outside-schedule multiplier. Overnight schedule windows are not supported by this setup. This limitation is about the schedule definition, not recording actual overnight shifts.

When supported premiums overlap, the **highest applicable multiplier wins**; they are not added or multiplied together. Verify that this matches your agreement. Do not treat a result as complete when your agreement requires another combination.

## Callout minimums

Enable **Callout minimum** and enter **Minimum paid hours**. Log the actual start and end of the callout and any unpaid breaks. The engine can add a separate guarantee component for a short callout, using its supported multiplier policy.

A one-hour callout with a confirmed four-hour minimum is still one hour of real work. Do not record four clock hours to represent the guarantee. A callout crossing a rule-change boundary can need review when the correct guarantee pricing is ambiguous.

## Flat per diem

Enable **Flat per diem** and enter **USD per worked date**. This is a flat amount for a local worked date, not one payment per work entry. More than one shift on the same date does not automatically earn another daily allowance; work across local dates can affect the dates included.

Expected per diem is displayed separately from expected wages. When checking a paystub, you explicitly confirm whether its gross figure includes that allowance. LinePaycheck does not infer tax treatment.

Next: [Change rules without changing the wrong work]({{< relref "/changing-rules" >}}) and [check supported limits]({{< relref "/supported-rules" >}}).
