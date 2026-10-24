---
title: Exchange a worker-provided rule draft
linkTitle: Crew rule drafts
weight: 65
group: Record your work
description: Review a rules-only file, confirm your own values, and preserve existing work and paycheck checks.
keywords: [crew, template, linepayrules, shared rules, omission, future periods]
---
**Unavailable in Paycheck Audit 1.1.0:** crew-rule sharing is held until repeated native Files export/import is verified. The instructions below describe the development workflow; its Settings entry is hidden in this release. Ordinary manual pay-rule editing remains available. Existing saved records are preserved.

## What the file contains

Open **Settings → Crew rule drafts**. A draft exchanges selected rule parameters without copying shifts, paycheck checks, original documents, benefits records or private profile IDs. It is not an official agreement, independent source verification, or a complete backup.

The format can represent currency and rounding, daily tiers, weekday premiums, an isolated callout minimum and flat per diem. It does not carry weekly overtime, schedules, outside-schedule rules, holiday/date premiums or effective-date limits. Unconfigured obligations are not waived. Keep unsupported or uncertain coverage visible rather than treating the file as your complete agreement.

The file is **not password-encrypted**. Its title and conditions may identify a group even when amounts are omitted. Review rights and the intended recipient before sharing a copy yourself.

## Prepare a file to share

1. Review **Draft title** and **Draft revision**. Keep **Include hourly and per-diem amounts** off to omit those amounts, or enable it only when you intend to share them.
2. Confirm **I have permission to share these selected rules and this title** only when that is true.
3. Choose **Review exact rule draft**. Inspect the visible summary and expand **Exact file contents** when useful. This preview is the file you are about to save.
4. Choose **Save reviewed draft to Files**, select a destination and save. Read the status beside that action. For a cloud location, confirm actual upload in Files; the app's callback does not prove another device received it.

Changing the title, revision or amount-inclusion choice invalidates the reviewed file and permission confirmation. Review again before saving another copy. Saving does not message a coworker or select a recipient for you. Copies sent or saved elsewhere remain outside later local deletion.

## Inspect a file without activating it

Choose **Choose rule draft file** and select a supported `.linepayrules` file, up to 64 KB. Read the inspection status beside that action and review **Selected draft**. Unsupported or unreadable input leaves existing rules and work unchanged.

A sender's omitted rate remains unknown. Enter **Your confirmed hourly rate** from your own source; inspection does not copy a sender's amount into your profile or replace an unknown amount with zero. When per diem is configured, explicitly review **Per diem for my work** and your own amount or applicability choice. The profile's currency and rounding policy must be compatible; do not force a currency conversion through this import.

Check **Payroll timezone** against your own work context. Separately confirm applicability to your work, classification and dates, and your amounts, currency, rounding and highest-premium semantics. Editing a material value clears those confirmations.

## Review and save your own setup

Choose **Prepare my rule setup**. Missing values or incompatible choices produce a status beside this action; they do not create a partially adopted rule version. If another unfinished setup exists, explicitly decide whether to replace that draft.

Preparation saves an unfinished setup and opens the usual four-step editor. It does not activate new rules. Review every step, including period dates and missing coverage, before saving.

For an existing profile, an imported draft applies to **Future work periods only**. This scope is shown as a read-only review value. Choose **Save reviewed rules**, then review and confirm the change. Existing work, paycheck values and earlier rule snapshots remain on their recorded terms. Ordinary manual rule editing still has the [other change scopes]({{< relref "/changing-rules" >}}).

After saving, **Retained draft references** keeps the original draft and your confirmed choices locally. Reopen the current paycheck to check its recorded amount and scope. A retained reference is not source approval or a legal-pay determination.

Use [Backup and restore]({{< relref "/backup-and-restore" >}}) for a complete recoverable copy. A rules-only file cannot restore work, paycheck history or retained originals.
