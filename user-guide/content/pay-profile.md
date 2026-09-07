---
title: Set up a pay profile
linkTitle: Your pay profile
weight: 20
group: Start here
description: Choose the right rate, timezone, cadence, and source references before calculating pay.
keywords: [hourly rate, USD, currency, timezone, agreement, setup]
---
## What a profile represents

A pay profile is the set of rules you entered for your work. Its name is for your reference; naming it after an employer or union does not verify its contents. The current setup supports one active profile and a base hourly rate in U.S. dollars. It is not a multi-employer payroll system or a currency converter.

Review the latest entered profile in **Settings → Pay profile**. To change it, choose **Settings → Edit pay rules** and follow the four setup steps.

## Enter the base rate and timezone

Use the straight-time hourly rate, not an overtime rate, take-home amount, or estimated rate with allowances included. Use a decimal point, such as `58.40`. Follow the field’s number-format instructions; do not assume a comma represents a decimal separator.

Select the payroll timezone that defines your work dates and premium boundaries. Your phone’s current travel location is not a substitute. An overnight shift can cross a payroll-local date even when the phone shows a different date.

Existing periods retain their timezone context. Do not change the phone’s timezone or rename a profile to try to reinterpret earlier work. Review the active period’s displayed timezone before logging.

## Choose the actual pay period

Select **Weekly**, **Every 2 weeks**, or manual dates in the cadence selector. At first setup, check **Current period starts**, any manual end date, and the period preview. The pay period is the interval covered by the paycheck, not its issue or deposit date.

Later cadence edits apply to future periods. Use [Correct current dates]({{< relref "/pay-periods" >}}) for an open period’s dates.

## Add only confirmed rules

Common optional rules start off. Enable the relevant rules and inspect **What LinePaycheck will calculate** before saving. Premiums use the highest applicable multiplier rather than adding together. A callout minimum can add paid entitlement without adding fictional clock hours.

For anything not represented, choose **I don’t see my rule** and keep a note of the missing rule. A nonempty note marks the agreement’s coverage as incomplete. See [supported rules and limits]({{< relref "/supported-rules" >}}).

## Keep a useful source reference

Under **Source references, optional**, add a title, URL, and section or note. Associate the reference with the relevant rule when offered. **Add source** lets you retain additional references.

Use a specific agreement version or section where possible. A saved link is a reference you supplied; it is not independent verification, and it does not guarantee that the external document will remain available.

When editing an established profile, read [Choose where a rule change applies]({{< relref "/changing-rules" >}}) before confirming. A new rate should not accidentally reprice earlier work.

On **Confirm rules**, **Apply this change** keeps the selected **Scope** visible in the form. Review that current value and any **New rules start** date before **Save reviewed rules**; the action is not hidden in a toolbar-only menu.
