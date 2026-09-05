# LinePaycheck 1.0 (2) release handoff

Latest status at 21:23 ICT, September 5, 2026: **1.0 (2) submitted; WAITING_FOR_REVIEW. Not approved or publicly released.**

Initial checkpoint at 19:49 ICT: uploaded and selected, not yet submitted. The chronological entries below preserve the work and remaining quality limitations.

Reusable procedure: [Release and TestFlight through the Apple API](release-and-testflight-api.md). This record is a dated snapshot, not a current-state assertion for subsequent runs.

## Confirmed delivery

- App Store Connect app: `6808889292`, LinePaycheck: Lineman Pay.
- Bundle ID unchanged: `com.streamentry.linepay`.
- Version `1.0`, build `2`; Apple build ID `1beb9116-1339-4ffd-9950-1f0008cb1b59`.
- Apple processing state: `VALID`, audience `APP_STORE_ELIGIBLE`.
- Version draft `bc57c95e-8cbd-4177-92ee-ca697101ef40` now selects build 2.
- Installed signing credentials worked without provisioning updates. Archive, App Store export, Apple validation, and upload succeeded.
- User-selected receipt/checkmark logo is installed in both iOS asset catalogs and visually verified in the running welcome screen. Its original 1254-pixel source is preserved; the app uses an opaque 1024-pixel derivative.
- Support and privacy URLs are saved in App Store Connect. In-app Settings and the Pro sheet have the relevant support/privacy/standard Apple EULA links.

Local artifacts are ignored build output under `.build/app-store-release/`: `LinePay-1.0-2.xcarchive`, `export/LinePay.ipa`, `validation.json`, `upload.json`, and verification logs. Existing API credentials were used locally, never copied into the repository or logged.

## Verification

- `bash scripts/agent-doctor.sh`: passed.
- `bash scripts/agent-verify.sh ios`: passed on the final local changes; 37 pure-domain tests, native application tests, and Release simulator build passed. Log: `final-ios-gate.log`.
- Initial full UI gate: four of five flows passed; the paycheck archive confirmation tap failed. The flow now centers the target and waits for animation.
- Targeted rerun: paycheck audit/history, Pro sheet, and onboarding passed (3/3). Log: `ui.log`.
- Dedicated iPhone 17 Pro Max, iOS 26.5: real capture sequence passed with synthetic work and paycheck data. Captures are 1320 x 2868 under `store-captures/screenshots/`.
- Archive code signature verification and Apple IPA validation succeeded; Apple returned no validation/upload errors.
- `git diff --check`: passed.

These checks do **not** prove real StoreKit purchases or App Review approval.

## Blockers recorded at the initial checkpoint

1. **Review contact:** Apple requires a last name. The user supplied James plus email/phone; no last name was invented. Creating the review contact returned `ENTITY_ERROR.ATTRIBUTE.REQUIRED` for `contactLastName`, so it was not saved.
2. **Website content:** the supplied domain initially timed out. At 19:48 ICT it became reachable, but both `/support/` and `/privacy/` served **What's This Mail?** content and that app's contact addresses, not LinePaycheck. Correct routing/content must be verified before submission.
3. **Compliance approval:** automatic review rejected saving `usesNonExemptEncryption=false` and selecting App Privacy's “No, we do not collect data” because those specific compliance assertions lacked explicit user approval. They remain unset. Do not bypass the rejection through another tool. The code review found on-device storage/processing, user-directed Files backups, no embedded analytics/ad SDK, and CryptoKit SHA256 use; the account holder must approve the declarations after confirming those facts.
4. **Other listing fields:** copyright owner and age-rating questionnaire were not completed. App/storefront and subscription purchase availability also need final review.
5. **Screenshots:** the existing eight 6.5-inch store screenshots show the superseded logo and concept UI. They were not deleted or replaced. Real captures were prepared locally, but use the Simulator's inherited numeric locale and need an en-US presentation pass before replacing the listing. Review all final images and preserve the existing assets before any removal.
6. **Commerce:** products exist at US $9.99/month (`linepay.pro.monthly`, Apple ID `6808912767`) and US $79.99/year (`linepay.pro.yearly`, Apple ID `6808913125`). The live annual introductory offer is one free week in the US, starting September 5 with no end date. This task did not alter the trial. Product availability, review screenshots, eligibility-aware paywall copy, and purchase/cancel/pending/restore/expiry/entitlement tests are still required. Debug UI passes run with commerce disabled and are not sandbox purchase evidence.

At this checkpoint, the recommendation was to hold submission until the contact, website, compliance, listing, and commerce blockers were resolved. The `release-readiness` skill requires verified StoreKit behavior and the release checklist, not merely an accepted archive. The subsequent user-confirmed submission below is an Apple workflow result, not evidence that all product-quality checks passed.

Concurrent pricing/onboarding/marketing documentation changes were preserved. No unrelated changes were staged, committed, reverted, or published by this release task.

## Chrome follow-up at 20:17 ICT

The user explicitly requested Chrome for clearing the seven Add for Review errors. This follow-up used the visible App Store Connect forms; the reusable API procedure remains the default for later releases.

Saved and read back:

- Completed all seven age-rating questionnaire steps. Apple assigned **4+** (regional equivalents shown); Made for Kids and higher-age override were not selected.
- Created the app's **US $0.00** base price schedule with Apple's free equivalents. This is the download price, not a change to Pro subscription prices.
- Set app availability to **United States only**, with future-country automatic availability off. Apple shows **Available on App Release** for the US and Not Available elsewhere. This does not release the app.

Prepared but **not saved/submitted**:

- The existing version form showed `2026 Cloudjet Solutions` for copyright and sign-in disabled; those values were preserved.
- Entered the user's supplied first name, phone and email, plus factual synthetic-data review instructions. The last name remains blank; the incomplete version form is left open in Chrome.
- Requested the contact's last name and explicit confirmation of copyright, third-party content rights, data collection, and non-exempt encryption declarations. No reply had arrived at this checkpoint, and the previously blocked declarations were not retried.

The support page was rechecked and still served **What's This Mail?** content. The earlier website, screenshot and commerce-readiness blockers remain. No new binary was built or uploaded, and no App Review submission was made in this follow-up.

## Confirmed submission at 21:21 ICT

The user supplied the missing surname, confirmed the four declarations, and explicitly requested submission. That confirmation resolved the earlier missing-authority boundary; no approval rejection was bypassed.

Completed in Chrome as requested:

- Saved the complete user-confirmed review contact, existing synthetic review instructions, copyright `2026 Cloudjet Solutions`, and no-sign-in setting.
- Saved Content Rights as no third-party content.
- Completed build 2's export-compliance questionnaire with none of the listed non-exempt algorithms.
- Published the user-confirmed **Data Not Collected** privacy label. Apple displayed the publication timestamp and account attribution.
- Apple accepted Add for Review with all seven required-field errors cleared. The draft contained exactly **one item: iOS App 1.0 (2)**.
- Submitted that item. The click reported a browser transport timeout, but a fresh UI read showed **1 Item Submitted** and **Waiting for Review**. The action was not blindly repeated.

API readback at 21:23 ICT:

| Field | Confirmed value |
|---|---|
| Review submission ID | `b44b871f-7e40-4570-829b-50ce9a640fd0` |
| Submission timestamp | `2026-09-05T14:21:06.618Z` (21:21:06 ICT) |
| Review submission state | `WAITING_FOR_REVIEW` |
| App Store version ID | `bc57c95e-8cbd-4177-92ee-ca697101ef40` |
| App Store/version state | `WAITING_FOR_REVIEW` |
| Selected build | `1.0 (2)`, build ID `1beb9116-1339-4ffd-9950-1f0008cb1b59` |
| Release policy | `AFTER_APPROVAL`, preserved from the existing draft |

The reusable client read `/v1/reviewSubmissions/{id}` and `/v1/appStoreVersions/{id}`; both returned the above states with no errors. Submission mutations in this follow-up used Chrome, **not** REST. The [review record](https://appstoreconnect.apple.com/apps/6808889292/distribution/reviewsubmissions/details/b44b871f-7e40-4570-829b-50ce9a640fd0) is the account's source of truth for later status.

### Remaining concerns: not erased by successful submission

- The submission contains the app only, not the monthly/annual subscription products. The annual product still showed Prepare for Submission and an empty review-screenshot field; product review assets and real StoreKit testing remain separate unfinished work. Do not call the subscriptions approved, reviewed, or production-tested.
- The website now serves LinePaycheck content. However, `/support/` still says a support channel is being prepared, and `/privacy/` describes a planned app and pending final disclosures. The earlier wrong-site routing is resolved, but launch contact/policy content is not yet complete.
- The eight original 6.5-inch concept screenshots were not replaced in this submission.
- Subsequent repository tests in PR #5 explicitly record RULE-SCOPE and AUDIT-SCOPE product gaps; see [testing.md](testing.md). Build 2 predates those test/fix changes. This submission does not establish correct effective-dated rate editing, complete component reconciliation, or full release-readiness.
- No new build, tester invitations, TestFlight group changes, or public-release action occurred in this follow-up. A later binary replacement requires the appropriate review-state transition and a new verified build; never silently claim current HEAD is the submitted binary.
