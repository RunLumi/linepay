---
title: Solve a problem without losing your records
linkTitle: Troubleshooting
weight: 170
group: Get help
description: Recover from input, calculation, import, backup, and purchase problems while preserving evidence.
keywords: [error, cannot save, wrong total, missing data, offline, disabled, stuck, daylight saving, repeat shift, calculation review]
---
## Protect the existing data first

Do not uninstall, reset, or delete periods as a first troubleshooting step. Keep original paystubs and export a complete backup when the app can read its records. If a recovery screen offers export of unreadable data, preserve that file before replacing local data.

Never change real work facts just to make a comparison green. An error or incomplete result is preferable to a convincing but unsupported answer.

## Work and setup problems

| Problem | Check next |
| --- | --- |
| The rate or a number is rejected | Follow the field’s decimal-point instructions. Remove currency words or ambiguous separators. Hours and money have different precision limits. |
| Save work is unavailable | Verify End is after Start, the dates are inside the open period, and no existing entry overlaps. Use **View conflicting entry**. |
| **Save same shift** is unavailable after Repeat | Look for **Clock-time review** or an outside-period message. Resolve every repeated-time choice, edit a nonexistent local time, or choose another **New date** before saving. |
| A repeated local time occurs twice | Under **Occurrence**, compare the displayed UTC offsets and choose **First occurrence** or **Second occurrence** based on the instant you actually worked. Do not choose whichever produces the preferred pay result. |
| A copied local time does not exist | Choose **Edit details**, enter the actual date/time and breaks you worked, then choose **Confirm reviewed manual times**. LinePaycheck does not silently move a nonexistent clock time forward. |
| An overnight shift has the wrong duration | Set the correct next-day End date. Review payroll timezone, unpaid breaks, and any daylight-saving transition. |
| A different work draft opens | A saved unfinished entry takes precedence. **Resume repeated shift** means a Repeat draft is pending; finish it, keep it, or explicitly discard it before beginning another. |
| Work or a draft was not saved | Keep the form open, note the error, check storage, and retry. Do not assume a preview or typed value is a committed record. |

A repeated shift copies payroll-local wall-clock facts, not elapsed-hour offsets. Around a daylight-saving transition, therefore, the elapsed duration can legitimately change even when the displayed start, end, and break clock times stay the same. Review the actual facts rather than modifying them solely to preserve the previous shift’s duration.

## Expected pay or an audit looks wrong

Review in this order: correct period → complete work → unpaid breaks → base rate and applied rule version → supported premium combination → paystub current-period values → gross basis → earnings layout.

**Not ready to compare** usually requires confirming complete work or what gross includes. **Needs review** can reflect missing coverage, conflicting lines, uncertain mapping, or work changed after the audit. Read the specific reasons before re-entering anything.

If gross matches but a component differs, check full-rate versus premium-only reporting and guarantee placement. If the paystub is higher than expected, check missing work and pay types as carefully as you would a shortfall.

A calculation problem around a dated change or callout guarantee should not be replaced with zero. Keep the work and establish the unsupported or ambiguous rule. [Supported limits]({{< relref "/supported-rules" >}}) explain common boundaries.

If the work period is complete but the calculation still cannot be produced safely, use **Pay → Finish work period → Close work, review calculation later**. This freezes the work/rules/review reason and lets the next weekly or biweekly period start normally. It does not consume the Free audit or treat the missing amount as $0.

In **History**, open the item marked **Calculation needs review**. Review **Frozen work** and the rule snapshot. Use **Retry saved calculation** after the underlying app/rule support has been clarified. Retry never changes the current period; if the same frozen facts still cannot be priced, the unresolved history remains unchanged.

## Scanning and imports

If the scanner is absent, use a supported photo/file route or **Enter manually**. If camera permission is denied, use **Open iOS Settings** or an alternative input method.

For unreadable text, review the saved original and confirm fields manually. For a failed cloud-file import, make sure the file is downloaded and available through Files. Check storage and use a readable PDF or image without destroying the source.

If another period owns a review draft, resume it from the correct period or explicitly discard the unfinished review. Do not attach the wrong paycheck simply to continue.

## Backup or restore trouble

A saved-to-location message does not prove that iCloud upload has completed. Verify the file in Files. A JSON data export or audit PDF is not the complete restorable backup.

If restoration rejects a file, preserve it unchanged, confirm it is a LinePaycheck backup, check available storage and app-version compatibility, and retry. Restoration replaces records rather than merging; always preserve the destination records you need first.

An unresolved closed period is part of the complete backup. Its saved calculation-review reason remains unresolved after restore unless the same frozen facts/rules can later be calculated safely; restore does not substitute a number.

If original-file cleanup remains pending, use **Privacy and local data → Retry original cleanup** after resolving the cause.

## Pro does not appear active

Check the Apple account and subscription state. Use **Restore Purchases** to refresh access. Pending approval, expiration, billing retry, or revoked access are not the same as an active verified subscription. An App Store product-loading failure should not make existing local records disappear.

For unresolved problems, [send a focused support request]({{< relref "/support" >}}) with the app version, iOS version, affected action, and a redacted example. Do not include passwords or unredacted wage documents.
