---
title: Manage work periods and payday
linkTitle: Pay periods
weight: 30
group: Start here
description: Keep period dates correct, close work before payday, and check an earlier paycheck later.
keywords: [weekly, biweekly, manual, payday, late paycheck, archive, calculation review]
---
## Work period versus payday

The work period identifies the dates the paycheck covers. Payday is when the employer issues or deposits the payment. These dates do not have to coincide.

LinePaycheck lets you close the completed work period and keep recording the next one while the earlier paycheck is still pending. There is no need to invent a paycheck or enter zero gross to move forward.

## Check or correct the open period

Go to **Settings → Pay period**. Review the current dates and timezone.

To correct a setup mistake, choose **Correct current dates**. Set **Starts** and **Ends, inclusive**, then choose **Save corrected dates**. All logged work must fit inside the corrected range, and the range cannot overlap closed periods. An existing current audit needs review again; previous audit revisions retain their original dates.

This corrects an open period. It does not unlock arbitrary editing of already closed work. Back up first when making significant corrections.

## Close a period

1. Review all work and unpaid breaks in **Today**.
2. Open **Pay → Finish work period**.
3. Check the displayed dates and expected wages, or read **Calculation needs review** when an amount cannot be produced safely.
4. Without a paycheck, choose **Close work, await paycheck**. With a confirmed paycheck, choose **Finish and archive**.
5. If the calculation is unresolved, choose **Close work, review calculation later** when you are satisfied that the recorded work facts are complete.

Choose **Keep period open** or **Cancel** to return without closing.

An unresolved close does **not** turn the amount into $0 and does not call the period paid or audited. LinePaycheck freezes the actual work, rule timeline, and calculation-review reason in History. It also does not consume the Free audit. This lets the next period remain usable without requiring you to delete genuine work or guess a pay rule.

For weekly and biweekly cadence, the next period is created as part of closing. For manual cadence, use **Today → Start pay period** and choose the next actual range. Check that new range before entering work.

## Review an unresolved closed period

In **History**, a closed period without a safe expected-pay result is labeled **Calculation needs review**. Open it to read the saved reason, inspect **Frozen work**, and review the exact rule snapshot and sources.

Keep the real work facts intact while you clarify the missing or ambiguous rule. A paycheck audit remains unavailable until LinePaycheck can produce a safe expected-pay calculation for that period; the app does not route an unresolved period into a subscription paywall as though payment were the blocker.

## Add the earlier paycheck

For a normally calculated pending period, open **History**, select the correct item marked **Awaiting paycheck**, and choose **Add this paycheck**. Follow the same field-review process used for the current period. The earlier work and rule snapshot remain frozen.

A pending-period link on **Today** also takes you to History. Take care to select the period covered by the paystub, not whichever period is currently open.

## Change future cadence

Use **Settings → Edit pay rules → Pay period**. Review and save the change. Future cadence does not silently change current or archived period dates.

Next: [Record and correct work]({{< relref "/recording-work" >}}) or [use History and audit revisions]({{< relref "/history" >}}).
