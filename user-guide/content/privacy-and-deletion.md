---
title: Control your data and original documents
linkTitle: Privacy and deletion
weight: 150
group: Keep control
description: Know what stays local, what can leave through your choices, and what deletion does not remove.
keywords: [privacy, local, offline, deletion, originals, cleanup, security]
---
## Local by default, not disconnected from all services

The app does not require a LinePaycheck account or employer connection. Work, pay rules, paystub processing, and calculations are local by default; the core app does not use a central LinePaycheck pay-data backend or analytics SDK.

App Store purchases use Apple’s services. A Files provider can use the network to retrieve or store a selected document. You choose report exports and manual iCloud Drive backups, and iOS may also back up app data according to device settings.

The v2 development build offers optional password protection for complete backup copies. Unprotected copies remain readable without a password. The app cannot recover or store your backup password; keep it separately and check the selected file before relying on it. Manual reports and diagnostic exports have their own sharing scope and are not automatically protected by a backup password.

“Local by default” does not mean exported copies cannot leave the phone, that all services work offline, or that a lost phone’s records can be recovered without a backup. Keep your device and storage accounts appropriately protected.

## Work descriptions

**Draft work from notes** accepts a typed or pasted English description. Review all proposed clock facts before applying them, then save work separately. Microphone recording is unavailable in this version, and this candidate does not request microphone or speech-recognition permission. No audio is captured or sent to a recognition server.

## Device-local activity in the v2 development build

Open **Settings → Device-local activity** to inspect or disable local milestone counts. This ledger records closed event labels, counts and UTC usage days; it does not record pay amounts, payroll dates, names, document text or arbitrary attributes. Nothing is sent to a collector. Existing subscriptions and renewals are observations, not new-customer conversion evidence.

**Preview local diagnostic file** shows the exact JSON before you choose a Files destination. Usage days and counts can still be personal; the file is not anonymous. Share it only deliberately. **Clear only local activity** removes these observations while keeping the recording preference and your pay records. Exported copies remain in their selected locations.

The daily breakdown retains up to 400 observed UTC days. Disabled recording, failures and bounded deduplication can make counts incomplete. A pay-data backup does not include or restore this ledger. **Delete all local data** also clears activity observations while preserving your recording preference.

## Review or remove retained originals

Go to **Settings → Privacy and local data → Original documents**. Choose **Remove original** for the selected document, then read and confirm the consequence. An audit’s **Remove this original** action provides the same kind of source removal.

Every audit revision sharing that original loses access to its document and associated OCR excerpts. Confirmed figures and calculation records remain. This is different from deleting the entire period.

For a v2 benefits statement, removing its original keeps saved observations and comparisons; every revision sharing that original loses access to its bytes. Benefits checks remain separate from wage-period records.

For an imported agreement, removing its original keeps saved review decisions and rule-snapshot citations. Reattach only the exact same PDF when you need to restore that source; a changed document is a separate import. An import referenced by a saved draft or rule history cannot be deleted as unused.

Files already exported elsewhere are not removed. A removed original is also absent from future backups, although an earlier backup may still contain it.

## Pending cleanup

If a file cannot be removed immediately, the app can queue it for cleanup. Settings displays the remaining count. Use **Retry original cleanup** after resolving storage or access problems, then check the result. A queued deletion is not proof that the underlying original bytes have already disappeared.

## Delete all local records

Create a complete backup first when you may need the information again. Then choose **Delete all local data** and read the confirmation.

This removes local work, rules, saved drafts, audits, and originals. It does **not** delete exported reports or backups from other locations, cancel an App Store subscription, or reset already-used Free-audit access.

Cancel your subscription separately through **Manage subscription** when that is your intent. Remove external copies separately in their own storage destinations.

## Share less when asking for help

Use a redacted screenshot or a description of the issue. Paystubs can contain names, addresses, employee identifiers, deductions, and other sensitive information. Do not post originals or complete backups publicly.

The help site’s search runs locally in the browser and does not submit your query to a search service. Ordinary hosting requests are separate from the iPhone app’s storage behavior. The website cannot inspect or recover the app data on your phone.

Read the [privacy policy](https://linepaycheck.com/privacy) for the product’s policy, and [backup guidance]({{< relref "/backup-and-restore" >}}) before changing devices or deleting records.
