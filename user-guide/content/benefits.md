---
title: Check employer benefit contributions
linkTitle: Employer benefits
weight: 115
group: Check a paycheck
description: Review one fund's eligible units and contribution rates separately from wages and deductions.
keywords: [benefits, pension, annuity, health, welfare, employer contribution, statement]
---

**Development preview:** this page describes the unreleased v2 workflow. Earlier App Store versions may not show these controls.

## Keep compensation categories separate

Open **Settings → Employer contribution checks**, then **Start a benefits check**. This checks one employer benefit fund. Cash wages, allowances, employee deductions, taxes and project/fringe compliance are separate. A fund name or reference does not verify membership or a legal entitlement.

Enter the fund name, category, currency and work dates covered by the check. A fund statement may cover a month even when wage paychecks cover weeks. Check the payroll timezone and every prefilled date; use work dates, not the statement's issue or deposit date.

## Review rates and eligible units

Open a date/rate segment. Choose the actual basis: an amount per eligible hour, per eligible day, a percentage of separately confirmed eligible earnings, or a fixed amount for this whole period. Enter the rate and eligible units explicitly. Clock hours, paid overtime equivalents and benefit eligibility are different; the app does not multiply or copy them automatically.

Enter the dates for those units and the dates you checked the rate applies. These are the scope of your review, not an invented agreement expiry. Another rate needs another nonoverlapping segment. A fixed-period amount needs one whole period with exactly matching applicability dates; a monthly amount is not automatically prorated into a weekly amount.

Add an optional reference or a clause from a retained agreement. Open the cited physical PDF page and check the original. Attaching a clause does not fill a rate or certify applicability. An absent, conditional or unsupported rule remains a reason for further review.

Check the fund-total rounding policy. The app sums exact segment contributions and rounds the expected total once. Original confirmed statement values are retained; extra printed precision is not silently rounded into a match.

## Missing statement or confirmed observations

If the statement has not arrived, leave **I have an employer contribution statement** off. An expected contribution can be saved as **Not verified**. Missing does not mean zero, unpaid or legally owed.

When you have the statement, enter only values you can read and review. Missing amount or unit count stays empty; zero is an affirmative observation. Keep every printed decimal in a USD/CAD contribution amount, including fractional cents when shown. VND amounts use whole units. Check the reported unit basis, currency, work dates, timezone and whether it is the same fund. Incompatible scope is **Not comparable**.

You can retain a statement PDF locally. Retention does not automatically read or confirm its values. **Read retained statement** checks its bytes against the saved fingerprint before opening it; file identity is different from legal validity or correct interpretation.

## Preview, then explicitly save

On the final review, check each segment's units, the source rules and whole-period eligibility. Review statement facts separately when present. Changing material input clears the corresponding confirmations. A saved draft retains its numeric context. When you reopen it in another region, complete valid numbers are reformatted without changing their values and need a fresh review. Partial or unreadable entries stay unchanged: finish or correct them using the displayed saved separator, then choose **Use this region’s number format** before previewing.

Choose **Preview benefits check** (**Preview check** at accessibility text sizes). Inspect expected contribution, confirmed observations, money and unit differences, each segment's unrounded calculation, rounding and limits. **Save reviewed benefits check** (**Save check** at accessibility text sizes) is the separate save action. Previewing alone does not create a saved check.

Synthetic example: 40 confirmed eligible hours at USD 8.75 gives USD 350. A confirmed statement with 35.5 eligible hours and USD 310.63 gives possible differences of 4.5 hours and USD 39.37. These are examples, not recommended rates, verified eligibility or recovery amounts.

A matching amount or count concerns only the compared values. Caps, exceptions, remittance deadlines, other fund obligations and legally owed amounts are not determined.

## Continue later without rewriting history

**Resume benefits draft** returns to unfinished input. Closing the editor keeps the draft; **Discard benefits draft** is a separate choice.

Open a saved check and choose **Correct latest saved check** when an earlier fact was wrong or a statement arrived later. Review again and explain the correction. Saving appends a revision; **Saved revision** lets you inspect earlier observations and results.

For another work period, choose **Check another period for this fund**. This reuses the fund identity, not prior rates, eligible units or statement values. New facts and applicability need a fresh review.

Complete [backups]({{< relref "/backup-and-restore" >}}) include saved benefits checks, revisions, drafts and retained originals. Removing an original affects every revision sharing it but keeps recorded observations and comparisons. Deleting a benefits check removes its local revisions; wage records and other checks remain. Exported copies are separate.

## Share a scoped report

From the intended saved revision, choose **Prepare a benefits report**. The default omits fund/source names, source quotations, fingerprints, original pages and the private note. It still contains sensitive dates, units, rates and amounts and is not anonymous.

**Include optional source details** and **Include this check's private note** are independent, default-off choices. Choose **Preview this report**, inspect the exact PDF and its limits, then choose a destination yourself. Nothing is sent automatically. A prepared report is not proof that a Files provider finished saving or uploading it.
