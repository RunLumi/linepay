# Paycheck Audit — worldwide availability, October 25, 2026

[Release home](../README.md) · [1.1.0 source and native evidence](release-1.1.0-2026-10-25.md) · [Legal register](../../legal/README.md)

## Verified outcome

At **2026-10-25 01:02:50 UTC** (08:02:50 Asia/Ho_Chi_Minh), an independent App Store Connect GET returned all **175 of 175** current app territories with `available: true` and `contentStatuses: ["AVAILABLE"]`, with no next page. This supersedes the earlier 00:51:51 UTC snapshot, when 22 were available and 153 were processing. It is Apple's provider state; physical downloads were not exercised in every country.

The public U.S. iTunes lookup independently returned **Paycheck Audit / 1.1.0**. Apple reported version `f8eb634c-7208-43ab-bd89-b3b7efaa556e` as **READY_FOR_SALE**, with build `343a736c-c8fa-4717-86a6-89e9b2139002` (**15 / VALID**), retaining release type **MANUAL**. This availability task did not issue a version-release request; it observed the already-public version.

## Authority and changes

The owner explicitly requested “make this app available in all country.” The app was previously selected only for the United States, Canada and Vietnam.

- Updated the remaining 172 existing `territoryAvailabilities` resources to `available: true` using Apple's documented PATCH endpoint; retained an exact request/response receipt for each.
- Updated both existing subscription plan availability resources to all 175 current territories: `linepay.pro.yearly` (`6808913125`) and `linepay.pro.monthly` (`6808912767`). Independent GETs verified the complete territory sets and existing prices in all 175 territories for each product.
- Preserved prices, introductory offers, product IDs, bundle `com.streamentry.linepay`, binary, permissions and release policy. Automatic inclusion of future territories remains unchanged (`false`); this receipt covers all current territories.
- A preliminary bulk-create request returned HTTP 409 because the app availability already existed and inline resources were absent. It made no change; subsequent supported updates targeted existing resources. No availability was deleted.

The source remains `fe184e78e8c308a14ecd0586070dae9e3763e07a`, version **1.1.0 (15)**, with IPA SHA-256 `c97900bd881d64ea725e9bd0379c80d117347200d203bed24223c6240e6b19ac`. No new binary was built or uploaded. Existing source-bound native evidence remains in the linked release receipt. Voice recording and crew-rule sharing remain unavailable.

## Evidence and limits

The private operator archive `paycheck-audit-worldwide-20261025-fug9u4gh` retains the 44 original availability request/readback, price and public-lookup receipts plus checksums; no credentials were copied. The final all-available readback is retained separately in the task's private evidence directory as `worldwide-pr-readback-20261025-response.json`, SHA-256 `5704f99a8b6054f535b29650985a2a8fa0203049cf6e86f6e7f89e9513cce0ba`.

This is distribution evidence, not new payroll-law coverage, trademark clearance, counsel approval, physical-device purchase testing or proof of downloadability on every account. The new-territory trigger in the legal register applies: market review remains follow-up work. User authorization to expand distribution is not described as acceptance of every jurisdiction's legal risk.

Apple documents [app availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store) and [availability statuses](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses). Provider restrictions can change independently of the selected territory list.
