---
title: Back up, restore, and move iPhones
linkTitle: Backup and restore
weight: 140
group: Keep control
description: Make a complete manual copy and understand exactly what replacing local data will do.
keywords: [backup, restore, iCloud, new phone, migration, recovery, Files, export]
---
## Choose the right operation

| Operation | What it gives you |
| --- | --- |
| **Complete LinePaycheck backup** | A restorable snapshot of saved work, profiles, rule snapshots, notes, periods, saved drafts, audit history and its follow-up comparison links, and retained original paystub and agreement PDFs. |
| **Audit PDF or JSON data export** | A report or structured data for your use. A JSON export does not include original document bytes and is not the complete backup format. |
| **Portable financial records (v2 candidate)** | A protected transfer of supported financial facts and frozen receipts between compatible clients. It is not a complete iPhone backup. |
| **Restore Purchases** | A check of App Store purchase access. It does not restore work, paystubs, or history. |

The app’s backup is **manual**. It does not turn on automatic backup or live sync. A backup represents the data saved when you created it, not changes made afterward.

## Create a complete backup

1. Open **Settings → Backup and restore**.
2. Choose **Back up to iCloud Drive**.
3. Read the sensitive-data notice and choose **Choose location**.
4. In Files, select a private iCloud Drive folder or another suitable Files location and save.
5. Check the saved file in Files. For iCloud Drive, confirm that uploading has finished before depending on another device being able to access it.

Despite the button’s name, the Files picker can offer other locations. A copy saved only on the same phone does not protect against losing that phone.

> **Without password protection, the backup is not password-encrypted by LinePaycheck.** Anyone who can open that copy can read it. Choose a private location; do not attach any backup to a public support issue or share it casually.

### Optional password protection in the v2 development build

Before starting the backup, select **Protect this copy with a password**. Enter **New backup password** and **Confirm backup password**, using a long, unique passphrase of at least 12 characters. Spaces are kept. Keep the password separately and confirm **I have kept the password separately** before continuing.

The app cannot recover a forgotten password. It does not save the password for you. Protection applies to this exported copy; it does not encrypt copies you exported earlier or turn on synchronization. Older app versions cannot open protected backups. The filename still ends in `.linepaybackup`. Keep both protected and unprotected files in private storage.

Deleted originals, unsaved input, device-local activity observations, and App Store subscription entitlements are not included. A manual diagnostic export is separate from a pay-data backup; restoring pay data never backfills observed usage or conversion history. Saved drafts, agreement review decisions, source citations and originals still retained by the app are included. In the v2 development workflow, this also includes benefits checks, their immutable revisions and retained statement PDFs.

## Restore a selected backup

Before restoring, back up the destination iPhone’s current data when you need to keep it. Restoration **replaces local LinePaycheck data; it does not merge two sets of records**.

Open **Restore from iCloud Drive**, select the backup in Files, and review its creation time, period count, work-entry count, and original-paystub count. Choose **Replace local data with this backup**, then **Restore and replace** only when you are sure it is the correct snapshot.

For a password-protected copy in v2, enter **Backup password** and choose **Unlock and review** first. A wrong password or damaged file cannot produce a replacement preview. Unlocking only checks the file; the separate replace confirmation is still required. **Discard locked selection** abandons a locked copy.

**Discard selection** abandons the selected backup. The source backup and your App Store purchases are not changed by restoration.

## Move to another iPhone

Create and verify a complete backup on the old phone. Install LinePaycheck on the new phone, open its backup/restore entry point, and restore the file. Inspect several periods and retained originals before retiring the old device. Use **Restore Purchases** separately for subscription access with the appropriate Apple account.

Do not uninstall the only installation holding valuable records before you have verified a usable backup. This is a transfer workflow, not ongoing synchronization between devices.

## When data or a backup cannot be read

Keep the source file unchanged. Check device storage, Files availability, and app-version compatibility. Follow the recovery screen’s available export option before replacing unreadable current data. If a backup was made by a newer app, update the destination app rather than editing the file’s version markers.

Do not reset data as your first troubleshooting step. See [troubleshooting]({{< relref "/troubleshooting" >}}) and contact support with a description—not an unredacted backup.

## Portable financial records in the v2 candidate

**Development preview:** this is a separate transfer workflow in the unreleased candidate. It does not promise complete Android/web feature parity, physical-device or cloud-provider delivery, or a released App Store version.

In **Settings → Backup and restore**, enable **Protect this copy with a password**, complete both password fields and keep the passphrase separately. Then choose **Export portable financial records** and save to a private Files location. This operation requires password protection. Use **Restore from iCloud Drive** to select a compatible protected transfer, then **Unlock and review**. Check the counts, including **Work snapshot entries** and **Frozen imported receipts**, before the separate replace confirmations. Multiple frozen snapshots can contain the same work entry; that count need not mean distinct shifts.

A portable transfer preserves supported profiles, rule versions and dated changes, period and work snapshots, frozen paycheck facts/results, and supported retained originals. Original receipt values and review reasons remain read-only; importing does not run another client's calculator over them. Missing source facts stay unknown. A rule or number that this iPhone cannot safely use may remain available as evidence while requiring a separately confirmed configuration for new estimates.

The exporter refuses the **whole transfer** when saved financial records cannot be represented. Examples include saved benefits checks, follow-up/resolution records, crew-rule adoption records, agreement review records, unfinished saved drafts, legacy paycheck facts without a frozen assessment, missing originals, or pending original-file deletion. It does not silently export a supported subset. Keep a **complete iPhone backup** instead; do not delete valuable records just to force a transfer. Other clients can reject the whole file when they cannot retain its originals or financial record types. Exceeding file or record limits also prevents transfer.

App Store access, Free-audit/trial state, local activity and diagnostics remain owned by the destination device; a financial transfer does not copy or reset them. Files and any chosen storage provider handle the destination you select. There is no LinePaycheck account, automatic upload or ongoing synchronization. Verify the saved copy and inspect restored records before relying on another device.

For new calculations after transfer, read [imported rules and current work]({{< relref "/pay-profile" >}}).
