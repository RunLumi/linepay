---
title: Back up, restore, and move iPhones
linkTitle: Backup and restore
weight: 140
group: Keep control
description: Make a complete manual copy and understand exactly what replacing local data will do.
keywords: [backup, restore, iCloud, new phone, migration, recovery, Files, export]
---
## Three different operations

| Operation | What it gives you |
| --- | --- |
| **Complete LinePaycheck backup** | A restorable snapshot of saved work, profiles, rule snapshots, notes, periods, saved drafts, audit history, and retained original paystubs. |
| **Audit PDF or JSON data export** | A report or structured data for your use. A JSON export does not include original document bytes and is not the complete backup format. |
| **Restore Purchases** | A check of App Store purchase access. It does not restore work, paystubs, or history. |

The app’s backup is **manual**. It does not turn on automatic backup or live sync. A backup represents the data saved when you created it, not changes made afterward.

## Create a complete backup

1. Open **Settings → Backup and restore**.
2. Choose **Back up to iCloud Drive**.
3. Read the sensitive-data notice and choose **Choose location**.
4. In Files, select a private iCloud Drive folder or another suitable Files location and save.
5. Check the saved file in Files. For iCloud Drive, confirm that uploading has finished before depending on another device being able to access it.

Despite the button’s name, the Files picker can offer other locations. A copy saved only on the same phone does not protect against losing that phone.

> **The backup is not password-encrypted by LinePaycheck.** Anyone who can access and open the file can access its contents. Choose a private location; do not attach it to a public support issue or share it casually.

Deleted originals, unsaved input, and App Store subscription entitlements are not included. Saved drafts and originals still retained by the app are included.

## Restore a selected backup

Before restoring, back up the destination iPhone’s current data when you need to keep it. Restoration **replaces local LinePaycheck data; it does not merge two sets of records**.

Open **Restore from iCloud Drive**, select the backup in Files, and review its creation time, period count, work-entry count, and original-paystub count. Choose **Replace local data with this backup**, then **Restore and replace** only when you are sure it is the correct snapshot.

**Discard selection** abandons the selected backup. The source backup and your App Store purchases are not changed by restoration.

## Move to another iPhone

Create and verify a complete backup on the old phone. Install LinePaycheck on the new phone, open its backup/restore entry point, and restore the file. Inspect several periods and retained originals before retiring the old device. Use **Restore Purchases** separately for subscription access with the appropriate Apple account.

Do not uninstall the only installation holding valuable records before you have verified a usable backup. This is a transfer workflow, not ongoing synchronization between devices.

## When data or a backup cannot be read

Keep the source file unchanged. Check device storage, Files availability, and app-version compatibility. Follow the recovery screen’s available export option before replacing unreadable current data. If a backup was made by a newer app, update the destination app rather than editing the file’s version markers.

Do not reset data as your first troubleshooting step. See [troubleshooting]({{< relref "/troubleshooting" >}}) and contact support with a description—not an unredacted backup.
