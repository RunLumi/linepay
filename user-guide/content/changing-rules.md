---
title: Choose where a rule change applies
linkTitle: Change rates and rules
weight: 60
group: Record your work
description: Separate future rates, dated changes, and corrections to the entire open period.
keywords: [raise, rate change, prospective, effective date, correction, rule version]
---
## Choose the intent before saving

A future raise and an incorrect rate entered earlier are different problems. Open **Settings → Edit pay rules**, make your changes, and continue to **Confirm rules**. In the **Apply this change** section, the **Scope** row shows the current selection; tap it to choose the intended scope. Review the selected label and its explanation before choosing **Save reviewed rules**.

| Scope | Use it for |
| --- | --- |
| **Future work periods only** | New rules that should apply when the next work period starts, leaving logged work on its existing snapshot. |
| **New rules from a date** | A confirmed change beginning on a specific payroll-local date after the last date touched by recorded work. |
| **Recalculate this entire current period** | Correcting the setup used for all work in the current open period. |

Do not select a whole-period correction to implement a raise that should affect only later work.

## Schedule a dated change

Choose **New rules from a date** in the **Scope** row and set **New rules start** directly below it. The change begins at midnight in the payroll timezone, not at the moment you tap Save.

A prospective date cannot touch work that is already recorded, including the next-day portion of an overnight shift. This protects earlier work from accidental repricing. Work on either side of an eligible date is associated with the relevant rule snapshot.

For a synthetic example, eight hours at $50 before a confirmed change and eight at $60 afterward produce $400 and $480 respectively—not sixteen hours at the newest rate. Use the ledger’s applied rule details to inspect which snapshot a component used.

If a cross-boundary callout requires an ambiguous minimum-hours top-up, the app can preserve the work while showing a calculation problem. Confirm the actual guarantee policy rather than replacing an unknown result with zero.

## Correct the current period

Choose **Recalculate this entire current period** only when all open-period work should use the corrected setup. Read the old and reviewed rules and the **Review rule change** confirmation.

The preview’s open-period total includes per diem when present; it is not necessarily the same basis as paystub wage gross. Confirm only after understanding both the scope and amounts. An existing audit needs another review after work or relevant rules change. Earlier audit revisions remain available.

Closed periods and their calculation snapshots are not rewritten through this editor. For a mistake in already closed work, preserve a backup and contact support; do not delete evidence simply to recreate a convenient result.

## Check the result

After **Confirm rule change**, return to Pay and inspect the relevant work dates, expected amounts, and rule provenance. **Settings → Pay profile** also shows dated rule versions when present. The latest entered profile is not proof that every historical component used that version.

Next: [Read the expected-pay ledger]({{< relref "/expected-pay" >}}).
