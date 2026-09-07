---
title: Use History and audit revisions
linkTitle: History and corrections
weight: 130
group: Check a paycheck
description: Add late paychecks, review unresolved calculations, correct confirmed paycheck facts, and return to earlier evidence.
keywords: [closed period, late paycheck, revisions, archive, correction, delete, calculation needs review]
---
## Find the right period

Open **History**. Closed work periods are grouped by month and show their dates. A period with a safe calculation shows expected wages. A period that could not be priced safely shows **Calculation needs review** instead of a zero amount. A period with no paystub is marked **Awaiting paycheck**; a period with confirmed paycheck facts shows the available audit status and amounts.

Select the work dates covered by the paycheck, not simply the most recent item. History uses the period’s saved timezone context, rather than your phone’s current location.

## When a calculation needs review

Open the period and read **Calculation review**. LinePaycheck preserves the reason that prevented a safe calculation and displays the **Frozen work** that was closed for that period.

Use **Review rule snapshot** or **Rule sources** to inspect the saved rule context. Do not change genuine work facts just to create a number. No $0 amount is substituted, and an unresolved period cannot start a paycheck audit until its calculation can be resolved safely.

Closing this period does not block the next work period. Later work belongs to its own period and is not rewritten when you return to this older review.

## Add a paycheck that arrived later

For a period with a safe expected-pay calculation, select the pending period and choose **Add this paycheck**. Import or enter its paystub and complete field review. You can do this while the next work period remains open for new shifts.

The closed period’s work and rules stay frozen. A late audit does not recalculate old work using the latest profile rate.

If the period says **Calculation needs review**, clarify the calculation issue first. A subscription is not the missing prerequisite, so LinePaycheck does not present a Pro paywall in place of that review.

## Correct paycheck facts

Open a calculated period and choose **Correct paycheck facts**, or open its live audit and choose **Review or correct confirmed facts**. To keep the same source, choose **Correct existing facts, keep original** where offered.

Correct the erroneous field, reconfirm it, and review the comparison basis and scope before saving. A correction appends an audit revision rather than silently replacing all prior evidence.

This is a paycheck-fact correction, not arbitrary editing of frozen work. If already closed work itself is wrong, preserve a backup and contact support before deleting or rebuilding history.

## Read an earlier revision

Under **Audit revisions**, select the timestamped audit you need. Its saved work, rules, calculation, and confirmed facts explain what was assessed at that time. A later correction does not make that earlier record the current answer.

When sharing a report, make sure you have opened the intended current or historical revision. Keep the period and revision context with any explanation you send.

Original files can be shared by several revisions. Removing a shared original removes access for all of them, even though the confirmed figures and calculation records remain.

## Delete only with a backup plan

**Delete work period and its audits → Delete period** removes that period’s local work and confirmed facts. Originals that are not shared elsewhere are deleted or queued for cleanup. This is not the same as closing a period, and the guide does not assume a historical recycle bin exists.

Export a complete backup first when those records may be needed later. Local deletion does not delete copies already exported to Files, iCloud Drive, email, or another destination. It also does not cancel a subscription.

Next: [Back up and restore safely]({{< relref "/backup-and-restore" >}}).
