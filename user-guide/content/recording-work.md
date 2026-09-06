---
title: Record, repeat, and correct work
linkTitle: Log your work
weight: 40
group: Record your work
description: Save real clock times and unpaid breaks without turning paid guarantees into fake worked hours.
keywords: [shift, hours, breaks, repeat, undo, draft, overnight, callout, daylight saving, DST]
---
## Add a shift

Open **Today → Add work**. Choose **Regular**, **Callout**, or **Other**, then set **Start** and **End**, including both dates. Add an optional note for the storm, crew, ticket, or facts you will need later.

Selecting Callout identifies the work type; it does not invent a minimum-hours rule. The configured agreement determines whether a guarantee applies. The app is a manual work record, not an automatic attendance clock or GPS tracker.

Review **Actual worked time** and **Payroll timezone**, then choose **Save work**. Your entry should appear in the work log and update expected pay. If saving fails, the error is not confirmation that the entry was recorded.

## Record unpaid breaks accurately

Enable **Unpaid break** and enter its actual start and end. Use **Add another break** for additional intervals. Breaks must fit inside the shift and must not overlap each other.

Unpaid breaks reduce worked time used by the calculation. Do not subtract a paid break merely because you stopped working, and do not invent an unpaid interval to make a paycheck total fit. Record only the facts and treatment you have confirmed.

For example, 7:00 AM–3:30 PM with a 30-minute unpaid break is eight actual worked hours on an ordinary day. A guaranteed payment is calculated separately from those hours.

## Overnight work and daylight saving time

For work ending after midnight, explicitly choose the following date for **End**. Changing one field does not automatically move another.

Elapsed time can differ from wall-clock subtraction during a daylight-saving transition. Check the payroll timezone, both dates, and the worked-time preview. Daily rules use the local day boundaries represented in the calculation. Do not split or extend real work simply to force an expected result.

## Repeat a familiar shift

Choose **Repeat last shift** on Today. LinePaycheck copies the work type, start/end wall-clock times, and each recorded break into the selected **New date** in the payroll timezone. Review the result before choosing **Save same shift**. Use **Edit details** whenever the actual shift differed.

Repeating is a shortcut to a new reviewed entry, not permission to log a shift twice. An overlap warning offers **View conflicting entry** so you can inspect the existing record.

### If the copied clock time is affected by daylight saving

A daylight-saving change can make a local clock time happen twice or not exist at all. In that case LinePaycheck shows **Clock-time review** instead of silently moving the copied time.

- If the same local time occurs twice, use **Occurrence** and choose **First occurrence** or **Second occurrence**. The app shows the UTC offset beside each candidate so the two real instants are distinguishable.
- If the copied local time does not exist, choose **Edit details**, enter the actual date/time you worked, review any breaks, then choose **Confirm reviewed manual times**. This confirmation records your reviewed facts; it is not an automatic daylight-saving correction.
- **Save same shift** or **Save work** stays unavailable while a required clock-time decision is unresolved or the resulting shift falls outside the current work period.

The same rule applies to copied unpaid breaks, including multiple breaks and overnight shifts. LinePaycheck preserves their intended payroll-local wall times rather than carrying forward elapsed-hour offsets from the original shift.

## Keep a draft or fix an entry

Use **Keep draft** to leave an unfinished entry. A normal draft returns as **Resume work draft**; an unfinished repeated shift returns as **Resume repeated shift**. Finish or explicitly discard the pending draft before starting a different entry. **Discard this draft → Discard draft** removes the unfinished input, not an already saved shift.

Tap a saved work entry to edit it. Save the corrected facts and re-review any audit that becomes stale. The app keeps previous audit revisions rather than presenting the old comparison as current.

To delete work, use the entry’s **Delete work** action or the work-log swipe action. Use **Undo** while it is offered. Undo is a short-lived recovery action, not a permanent recycle bin; further changes or moving periods can remove it.

Next: [Understand expected pay]({{< relref "/expected-pay" >}}).
