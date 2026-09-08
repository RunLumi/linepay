---
title: Manage work periods and payday
linkTitle: Pay periods
weight: 30
group: Start here
description: Keep period dates correct, close work before payday, and check an earlier paycheck later.
keywords: [weekly, biweekly, manual, payday, late paycheck, archive]
---
## Work period versus payday

The work period identifies the dates the paycheck covers. Payday is when the employer issues or deposits the payment. These dates do not have to coincide.

LinePaycheck can close a completed work period and keep recording the next one while the earlier paycheck is still pending. If a calculation is unresolved or a callout cannot be priced safely, choose **Close work, calculation needs review** after reading the warning. The work, rules, evidence, and explicit problem are preserved; LinePaycheck never invents a pay amount or substitutes zero.

## Check or correct the open period

Go to **Settings → Pay period**. Review the current dates and timezone.

To correct a setup mistake, choose **Correct current dates**. Set **Starts** and **Ends, inclusive**, then choose **Save corrected dates**. All logged work must fit inside the corrected range, and the range cannot overlap closed periods. An existing current audit needs review again; previous audit revisions retain their original dates.

This corrects an open period. It does not unlock arbitrary editing of already closed work. Back up first when making significant corrections.

## Close a period

1. Review all work and unpaid breaks in **Today**.
2. Open **Pay → Finish work period**.
3. Check the displayed dates and expected wages. If a calculation problem is shown, read the warning and confirm that the unresolved period should be preserved for later review.
4. Without a paycheck, choose **Close work, await paycheck** or **Close work, calculation needs review**. With a confirmed paycheck, choose **Finish and archive**.

Choose **Keep period open** or **Cancel** to return without closing. Closing preserves the work and rule snapshot. An unresolved close is visibly marked **Calculation needs review** in History; add the paycheck or correct the rules later rather than treating the period as a priced result.

For weekly and biweekly cadence, the next period is created as part of closing. For manual cadence, use **Today → Start pay period** and choose the next actual range. Check that new range before entering work.

## Add the earlier paycheck

Open **History**, select the correct closed period marked **Awaiting paycheck**, and choose **Add this paycheck**. Follow the same field-review process used for the current period. The earlier work and rule snapshot remain frozen.

A pending-period link on **Today** also takes you to History. Take care to select the period covered by the paystub, not whichever period is currently open.

## Change future cadence

Use **Settings → Edit pay rules → Pay period**. Review and save the change. Future cadence does not silently change current or archived period dates.

Next: [Record and correct work]({{< relref "/recording-work" >}}) or [use History and audit revisions]({{< relref "/history" >}}).
