---
title: Trace a difference and share a report
linkTitle: Evidence and reports
weight: 120
group: Check a paycheck
description: Follow a compared line back to work, rules, and the paystub without sharing more than necessary.
keywords: [PDF, export, evidence, receipt, source, report, payroll]
---
## Follow the comparison

In **Paycheck audit**, open a row under **Compared lines**. The detail shows expected, confirmed paid, and difference values. Under **Only the work behind this line**, open an applicable component to inspect its calculation and rule snapshot.

The evidence chain is: recorded work → applied rule and rate → expected component → confirmed paystub value. Each stage answers a different question. Confirming a source number does not prove that the configured rule covers your entire agreement.

If no expected component is applicable, check for incomplete work or an incompatible paystub layout. Do not invent a missing line-level explanation from a total-only difference.

## Inspect rules and original documents

Use the component’s evidence or **Rules and sources** to inspect the relevant snapshot and references. A reference entered by you is not independent verification by LinePaycheck.

Use **View original paystub** to open retained source pages. For a mapped field, **View source for this field** can take you to the relevant region. Check labels and current-period columns as well as digits.

A manually entered audit or one whose original was removed can retain confirmed values without a document. “No original available” is an evidence limitation, not permission to imply that the app verified the source.

## Prepare a worker-owned PDF

1. Open the required audit from Pay or History. For an older revision, select that revision first.
2. Under **Worker-owned report**, choose **Prepare audit report**.
3. Keep the default minimized report, or explicitly choose **Include optional source details** after reading its sensitive-content warning.
4. Choose **Preview this report** and inspect the exact generated PDF. **Share report** becomes available only after this preview.
5. Review the period, comparison scope, limitations, and sensitive amounts before selecting a destination in the system share sheet.

The default report excludes original paystub pages, optional OCR source text, profile names, and source identifiers, but it still contains sensitive pay amounts/dates and is not anonymous. Optional source details can add private rule, source, and OCR text and require a new review. Share only with an intended recipient and avoid public links. A previously saved or shared copy is outside later local deletion. Preparing or sharing a PDF does not contact payroll on your behalf.

Existing records and exports remain available without Pro. A PDF is a report, not a complete restorable backup.

## Ask a focused question

For example:

> For the work period [dates], my recorded work and confirmed rules produce [expected amount] on [gross basis]. The paystub shows [confirmed amount]. Could you help explain the difference in [specific line or scope]? I may be missing a rule or adjustment.

Fill this from your actual reviewed records, not the guide’s examples. Do not state that a flagged amount is legally owed solely because the app found a difference.

## Preserve a recoverable copy

Use [Backup and restore]({{< relref "/backup-and-restore" >}}) to preserve records and retained originals. Removing an original affects every audit revision sharing that source; see [privacy and deletion]({{< relref "/privacy-and-deletion" >}}) before doing so.
