---
title: Set up a pay profile
linkTitle: Your pay profile
weight: 20
group: Start here
description: Choose the right rate, timezone, cadence, and source references before calculating pay.
keywords: [hourly rate, USD, CAD, VND, currency, decimal comma, timezone, agreement, setup]
---
## What a profile represents

A pay profile is the set of rules you entered for your work. Its name is for your reference; naming it after an employer or union does not verify its contents. The current setup supports one active profile. Choose its **Pay currency** (US dollar, Canadian dollar, or Vietnamese đồng) when you first set it up; the currency then stays fixed for that profile so saved calculations never change denomination. LinePaycheck is not a multi-employer payroll system or a currency converter.

Review the latest entered profile in **Settings → Pay profile**. To change it, choose **Settings → Edit pay rules** and follow the four setup steps.

## Enter the base rate and timezone

Use the straight-time hourly rate, not an overtime rate, take-home amount, or estimated rate with allowances included. Type amounts the way your iPhone region writes numbers: `58.40` or `1,250.50` in the United States and English Canada, `58,40` or `1.250,50` where the comma is the decimal mark (for example Vietnam or French Canada). A lone `58.40` is also accepted in comma regions. Vietnamese đồng have no decimals, so enter whole amounts such as `45000`; `45.00` is rejected rather than read as 45 đồng.

Select the payroll timezone that defines your work dates and premium boundaries. Your phone’s current travel location is not a substitute. An overnight shift can cross a payroll-local date even when the phone shows a different date.

Existing periods retain their timezone context. Do not change the phone’s timezone or rename a profile to try to reinterpret earlier work. Review the active period’s displayed timezone before logging.

## Choose the actual pay period

Select **Weekly**, **Every 2 weeks**, **Twice monthly (1–15, 16–end)**, or manual dates in the cadence selector. Twice-monthly periods start on the 1st or 16th and follow the payroll calendar, including February and daylight-saving changes. Use manual dates if your employer uses other cutoff days. At first setup, check **First day of this pay period**, any manual end date, and the period preview. The pay period is the interval covered by the paycheck, not its issue or deposit date.

Later cadence edits apply to future periods. Use [Correct current dates]({{< relref "/pay-periods" >}}) for an open period’s dates.

## Add only confirmed rules

Common optional rules start off. Enable the relevant rules and inspect **What LinePaycheck will calculate** before saving. Premiums use the highest applicable multiplier rather than adding together. A callout minimum can add paid entitlement without adding fictional clock hours.

For anything not represented, choose **I don’t see my rule** and keep a note of the missing rule. A nonempty note marks the agreement’s coverage as incomplete. See [supported rules and limits]({{< relref "/supported-rules" >}}).

## Keep a useful source reference

Under **Where these rules come from (optional)**, add a title, URL, and section or note. Associate the reference with the relevant rule when offered. **Add source** lets you retain additional references.

Use a specific agreement version or section where possible. A saved link is a reference you supplied; it is not independent verification, and it does not guarantee that the external document will remain available.

When editing an established profile, read [Choose where a rule change applies]({{< relref "/changing-rules" >}}) before confirming. A new rate should not accidentally reprice earlier work.

On **Confirm rules**, **Apply this change** keeps the selected **Scope** visible in the form. Review that current value and any **New rules start** date before **Save reviewed rules**; the action is not hidden in a toolbar-only menu.

## Start with an agreement PDF

Choose **Import an agreement PDF** on the welcome screen, or **Settings → Agreement documents** after setup. Select **Choose agreement PDF** in Files. The app retains the original locally before reading its text or scanned pages on the device.

Open the retained document and review every candidate clause. Inspect the original physical PDF page, correct any reading, and explicitly choose whether to confirm it, mark it not applicable, or keep it unresolved. A text match or recognition percentage does not establish that a rule applies to your employer, classification, dates or work.

Confirm applicability, currency and effective dates separately. Conditional, unsupported or conflicting clauses need your attention; the reader does not choose a classification or invent missing rules. If replacing daily overtime tiers, acknowledge that replacement. **Review complete rule setup** prepares a draft in the usual editor. Check every step and the change scope before its final save; importing or preparing alone never activates rules.

The reader handles a bounded set of explicit clause formats. It can miss tables, cross-references, amendments and other layouts. Reading is limited to 25 MB, 128 pages, 250,000 text characters and 64 candidates; an incomplete-reading notice requires further manual review. The complete retained PDF can contain more than the reader examined. Empty or unresolved extraction is not evidence that the agreement has no additional obligations.
