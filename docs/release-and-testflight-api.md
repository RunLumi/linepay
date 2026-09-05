# Release and TestFlight through the Apple API

Operational workflow for `com.streamentry.linepay`. Prefer supported App Store Connect APIs over browser automation. Local compilation/signing still uses Xcode; binary delivery uses Apple's API-key-authenticated command-line uploader. No browser session, Apple ID password, or browser cookies are needed for the normal path.

Checked September 5, 2026 against Apple's OpenAPI specification **4.4.1** and the actual 1.0 (2) upload. This is a procedure, not evidence that the app is published. The dated [build 2 handoff](release-build-2-2026-09-05.md) records that run and its blockers.

## 1. Boundaries and evidence

| Milestone | Required evidence | Does not prove |
|---|---|---|
| Local candidate | Exact source state, passing gates, signed archive, IPA SHA-256 | Apple accepted it |
| Upload accepted | Successful uploader result and delivery ID | Processing finished |
| Build processed | Matching app/version/build, `processingState=VALID`, not expired | Testers have access |
| Internal TestFlight | Correct internal group contains the build; beta state permits testing | External beta approval |
| External TestFlight | Beta review state permits testing, intended external group contains build | App Store approval |
| Submitted for review | Exact review submission/items and returned submitted/review state | Approved or public |
| Public release | Distribution state plus the correct version on the target public storefront | All storefronts updated instantly |

Run the [release-readiness skill](../.agents/skills/release-readiness/SKILL.md) and [first-TestFlight checklist](checklists/ios-before-first-testflight.md). A Debug build with commerce disabled is not purchase-path proof. Before a commerce launch, test eligible/ineligible annual trial, monthly purchase, cancel, pending, restore, renewal, expiry/revocation, and persisted entitlement behavior with StoreKit Test and sandbox/TestFlight as applicable.

**Authority:** an API key's permissions are not user authorization. Confirm exact app, build, audience, territories, notification intent, and manual/automatic release policy. Preserve unrelated draft changes and existing tester membership. Compliance answers, legal agreements, credentials/provisioning changes, deletions, and public release remain explicit decision boundaries. Never work around an approval rejection using a different API or UI.

## 2. Authentication and the reusable client

Use an existing **team** API key with the least sufficient role; an App Manager key was sufficient for the verified upload/metadata operations. Keep the private key outside the repository. Account Holder/Admin setup and any new access grant are separate authorized work, not part of an automatic release retry. See [Apple API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api).

Prerequisites: repository-pinned Xcode/XcodeGen, a Python environment with `cryptography`, and `jq` for inspecting JSON. The Python package is developer tooling only, not an app dependency. Verify the existing environment before installing anything:

```bash
python3 -c 'import cryptography'
python3 scripts/asc-api.py --help
```

Set these locally or through CI's secret store; replace the uppercase example values:

```bash
export ASC_KEY_ID='YOUR_EXISTING_TEAM_KEY_ID'
export ASC_ISSUER_ID='YOUR_TEAM_ISSUER_UUID'
export ASC_PRIVATE_KEY_PATH='/absolute/private/path/AuthKey_YOUR_EXISTING_TEAM_KEY_ID.p8'
export ASC_APP_ID='6808889292'
export ASC_TEAM_ID='7MBXZKYSY4'
```

Do not put `.p8` files, tokens, review-contact payloads, or tester lists in git. Do not use `set -x`, print a JWT, or paste credentials into a task. Treat returned JSON as potentially sensitive: contacts, tester information, and signed upload URLs can appear in responses.

[`scripts/asc-api.py`](../scripts/asc-api.py) signs a five-minute ES256 JWT per request, fixes the destination to Apple's API origin, blocks redirects, and defaults to GET. It supports one POST/PATCH only with `--allow-write` and a reviewed JSON body. It does not retry mutations, delete resources, grant permissions, upload binary parts, or bypass missing approvals. Authentication follows [Apple's JWT specification](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests).

```bash
python3 scripts/asc-api.py "/v1/apps/$ASC_APP_ID"
python3 scripts/asc-api.py "/v1/apps/$ASC_APP_ID/appStoreVersions"
python3 scripts/asc-api.py "/v1/apps/$ASC_APP_ID/betaGroups"
```

For writes, save a reviewed JSON body under an ignored `.build/` run directory, then pass it explicitly. Always GET the target before and after the mutation. Follow pagination links only after checking the same `https://api.appstoreconnect.apple.com` origin; pass their path/query to the client. A first page is not an inventory.

For scripted sequences use `set -euo pipefail`; never let a JSON-filter pipeline hide the client's nonzero exit status. Do not run all write examples as one unattended batch.

## 3. Prepare one immutable candidate

1. Run `bash scripts/agent-context.sh`; inspect status, diff, worktrees, and recent commits. Prefer a clean intended source revision. If a dirty tree is explicitly included, record its complete release-relevant diff and hashes; do not label it as the clean HEAD build.
2. Discover existing builds and upload reservations before choosing an unused build number:

   ```bash
   python3 scripts/asc-api.py "/v1/builds?filter[app]=$ASC_APP_ID&sort=-uploadedDate&limit=20"
   python3 scripts/asc-api.py "/v1/apps/$ASC_APP_ID/buildUploads?limit=20"
   ```

3. Set `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` deliberately in `apps/ios/project.yml`. Keep bundle ID, `LinePay` scheme, and public display name unchanged. Never reuse a version/build pair after an uncertain upload without checking Apple first.
4. Run `bash scripts/agent-doctor.sh` and `bash scripts/agent-verify.sh ui` when Maestro is available; `ui` includes the native gate, so do not redundantly run `ios` first. Record unsupported manual checks honestly. Re-run only checks invalidated by later changes.
5. Verify the icon is opaque, the privacy manifest is bundled, permissions match behavior, StoreKit IDs match the configured products, and supported migration/recovery paths are safe.

Use a fresh per-run output directory; never overwrite a prior archive:

```bash
mkdir -p .build
LINEPAY_RELEASE_DIR="$(mktemp -d "$PWD/.build/release.XXXXXX")"
export LINEPAY_RELEASE_DIR
(cd apps/ios && xcodegen generate)
xcodebuild -quiet -project apps/ios/LinePay.xcodeproj -scheme LinePay \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$LINEPAY_RELEASE_DIR/LinePay.xcarchive" \
  DEVELOPMENT_TEAM="$ASC_TEAM_ID" CODE_SIGN_STYLE=Automatic archive \
  > "$LINEPAY_RELEASE_DIR/archive.log" 2>&1
```

The build-2 archive worked with installed credentials **without** `-allowProvisioningUpdates`. Do not add that flag as a blind retry: it can mutate developer-account signing resources. Inspect signing errors and obtain any necessary authority separately.

Create `ExportOptions.plist` inside the run directory, using the confirmed team ID:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>7MBXZKYSY4</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict></plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath "$LINEPAY_RELEASE_DIR/LinePay.xcarchive" \
  -exportPath "$LINEPAY_RELEASE_DIR/export" \
  -exportOptionsPlist "$LINEPAY_RELEASE_DIR/ExportOptions.plist" \
  > "$LINEPAY_RELEASE_DIR/export.log" 2>&1
plutil -p "$LINEPAY_RELEASE_DIR/LinePay.xcarchive/Info.plist"
codesign --verify --deep --strict --verbose=2 \
  "$LINEPAY_RELEASE_DIR/LinePay.xcarchive/Products/Applications/LinePay.app"
shasum -a 256 "$LINEPAY_RELEASE_DIR/export/LinePay.ipa"
```

Retain archive, dSYMs, export summary, IPA hash, source evidence, and gate logs. Do not rebuild merely because Apple's processing is slow.

## 4. Upload and verify processing

### Verified binary-delivery route: API-key-authenticated altool

This is a command-line Apple upload, not browser automation or a REST `POST /v1/builds`. These options worked with Xcode 26.6/altool 26.40.1; inspect `xcrun altool --help` after toolchain upgrades. The uploader looks for `AuthKey_<KEY_ID>.p8` in its documented key locations, including the user's `.appstoreconnect/private_keys` directory. `ASC_PRIVATE_KEY_PATH` belongs to our REST helper and does **not** configure altool's key search. Do not copy a key into the repo. [Apple upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

```bash
xcrun altool --validate-app "$LINEPAY_RELEASE_DIR/export/LinePay.ipa" \
  --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
  --output-format json > "$LINEPAY_RELEASE_DIR/validation.json" 2>&1
xcrun altool --upload-package "$LINEPAY_RELEASE_DIR/export/LinePay.ipa" \
  --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
  --wait --output-format json > "$LINEPAY_RELEASE_DIR/upload.json" 2>&1
```

Run the upload only after validation succeeds and the exact artifact upload is authorized. The installed uploader mixes status lines with JSON; these log filenames do not imply the entire file can be parsed as JSON. Check exit status and the result, not a substring alone.

Use the REST client to discover the processed build. Set `ASC_BUILD_NUMBER` to the exact candidate's build number and match its `preReleaseVersion`/platform as well:

```bash
python3 scripts/asc-api.py "/v1/builds?filter[app]=$ASC_APP_ID&filter[version]=$ASC_BUILD_NUMBER&include=preReleaseVersion"
```

Save the returned **build resource ID** as `ASC_BUILD_ID`; do not assume it equals the delivery ID. Require the intended app, marketing version, platform, build number, `processingState=VALID`, and `expired=false`. Use bounded polling with backoff; a temporarily empty response means not yet observed, not upload failure. Preserve errors/warnings and stop for `FAILED`/`INVALID` or any unexplained state. See [build upload information](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builduploads-_id_).

### Direct REST binary upload: supported protocol, not yet exercised here

Apple's 4.4.1 schema also exposes `buildUploads`/`buildUploadFiles`. For a strictly REST-only delivery implementation: reserve a build upload for app/platform/version/build; reserve the IPA file with `assetType=ASSET` and `uti=com.apple.ipa`; perform the returned `uploadOperations` exactly; commit the uploaded file with the required checksums; then inspect the upload's errors/state and resulting build. Do not invent part offsets, omit required companion files, send the App Store JWT to asset URLs, or re-create reservations blindly. Our helper handles JSON reservations/commits only, not the multipart transfer. Keep the proven altool route until this path has its own end-to-end evidence. [File reservation](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-builduploadfiles), [file commit](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-builduploadfiles-_id_), [upload resource](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builduploads-_id_).

## 5. TestFlight distribution through REST

Resolve existing groups by app, name, and `isInternalGroup`; never pick an arbitrary first group. Adding a build can expose it to existing testers and interact with notification/automatic-distribution settings. Confirm the intended group and inspect those settings first; this workflow does not create testers, public links, or invitations implicitly. [Beta groups](https://developer.apple.com/documentation/appstoreconnectapi/beta-groups).

| Read / prepare | API route |
|---|---|
| Existing groups | `GET /v1/apps/{appId}/betaGroups` |
| Group and current builds | `GET /v1/betaGroups/{groupId}`; `GET /v1/betaGroups/{groupId}/builds` |
| Build testing state | `GET /v1/builds/{buildId}/buildBetaDetail` |
| App beta descriptions | `GET /v1/apps/{appId}/betaAppLocalizations` |
| Beta review contact | `GET /v1/apps/{appId}/betaAppReviewDetail` |
| What to test | `GET /v1/builds/{buildId}/betaBuildLocalizations`; create with `POST /v1/betaBuildLocalizations`, or PATCH the returned localization ID |

Internal distribution: save this body as `group-build.json`, replacing `BUILD_ID`, then POST it to the intended group's relationship:

```json
{"data":[{"type":"builds","id":"BUILD_ID"}]}
```

```bash
python3 scripts/asc-api.py "/v1/betaGroups/$ASC_BETA_GROUP_ID/relationships/builds" \
  --method POST --body "$LINEPAY_RELEASE_DIR/group-build.json" --allow-write
python3 scripts/asc-api.py "/v1/betaGroups/$ASC_BETA_GROUP_ID/builds"
python3 scripts/asc-api.py "/v1/builds/$ASC_BUILD_ID/buildBetaDetail"
```

The relationship POST adds rather than replaces builds. Verify membership and testing eligibility; do not claim tester installation from group membership. [Add builds](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betagroups-_id_-relationships-builds).

External distribution requires the appropriate beta information, approved export answers, and any required Beta App Review. Inspect an existing submission before creating one. Save `beta-review.json` with the exact build relationship:

```json
{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":{"data":{"type":"builds","id":"BUILD_ID"}}}}}
```

Submit via `POST /v1/betaAppReviewSubmissions`, then read the returned `/v1/betaAppReviewSubmissions/{id}` and build beta detail. Associate only the intended external group and verify access after the review permits testing. Beta approval does not approve the App Store version. [Beta review submission](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betaappreviewsubmissions).

## 6. App Store draft, commerce, and assets through REST

Resolve IDs from the selected app/version; localization IDs, app-info IDs, and review-contact IDs are different resources. GET before PATCH; create only when the relationship is actually absent. Do not convert a timeout/403 into an assumption that something does not exist.

| Surface | API family / important checks |
|---|---|
| Version | `/v1/apps/{appId}/appStoreVersions`, `/v1/appStoreVersions/{id}`; preserve intended `releaseType` |
| Selected build | PATCH `/v1/appStoreVersions/{id}/relationships/build` with `{"data":{"type":"builds","id":"BUILD_ID"}}`; GET the version's `/build` to verify |
| Description/support/marketing | `/v1/appStoreVersions/{id}/appStoreVersionLocalizations`, then `/v1/appStoreVersionLocalizations/{id}` |
| Privacy URL/name/subtitle | App's `/appInfos`, chosen app-info's `/appInfoLocalizations`, then `/v1/appInfoLocalizations/{id}` |
| Review contact | Version's `/appStoreReviewDetail`; create `/v1/appStoreReviewDetails` or PATCH its ID; first **and last** name, email, phone, factual notes and sign-in requirement |
| Age/content/export | `/v1/ageRatingDeclarations/{id}`, app `contentRightsDeclaration`, build `usesNonExemptEncryption`; only after the exact declarations are approved |
| App price/territories | `appPriceSchedules`, `appAvailabilities` v2 and `territoryAvailabilities`; free app price is separate from paid subscriptions |
| StoreKit | `subscriptionGroups`, `subscriptions`, localizations, prices, introductory offers and availability; do not duplicate existing product IDs or silently change the annual trial |
| Screenshots | `appScreenshotSets` → `appScreenshots` reservations → returned upload operations → commit and verify processing/order |

Verify support/privacy pages' **content**, not just HTTP 200: app identity, accurate policy, real contact, HTTPS, and no unrelated site's routing. Do not invent a legal owner, review surname, or data declaration. A privacy-manifest file does not itself publish an App Privacy label.

Use real shipping UI and synthetic records for screenshots, with explicit en-US presentation for the US listing. Preserve current assets before any approved removal. Reservation responses contain signed upload URLs: transfer only the intended bytes using the provided headers, then commit with the checksum and wait for completion. Subscription review screenshots are separate from public listing screenshots. [Asset upload protocol](https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

**API limitation:** the checked 4.4.1 public specification exposes privacy-policy URL fields but no endpoint for publishing the App Privacy data-collection questionnaire. If that remains required, report it and use an explicitly authorized account-holder/UI step; never call undocumented browser-session endpoints or claim a URL update completed the label. Legal agreement acceptance and missing account privileges also require separate handling. [App Privacy management](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).

## 7. Submit the reviewed set, not an accidental draft bundle

Read `/v1/apps/{appId}/reviewSubmissions` and reuse the intended editable submission if one exists. Do not create duplicates after uncertain responses. Confirm all items and release policy immediately before the final submission. For first subscriptions, include their eligible subscription-version items with the new app version; do not confuse a product ID with a `subscriptionVersions` resource ID.

The following are JSON payload templates, **not instructions to submit an unready build**. Replace uppercase IDs with live-discovered IDs and keep each body under the run directory.

Create the review container using `POST /v1/reviewSubmissions`:

```json
{"data":{"type":"reviewSubmissions","relationships":{"app":{"data":{"type":"apps","id":"APP_ID"}}}}}
```

Attach the intended app version using `POST /v1/reviewSubmissionItems`:

```json
{"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":"SUBMISSION_ID"}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":"VERSION_ID"}}}}}
```

The current schema also supports `subscriptionVersion`/`subscriptionGroupVersion` relationships. Discover eligible versions from their product/group resources; attach exactly the required versions using the same submission relationship. Read `/v1/reviewSubmissions/{id}/items` and validate the complete set before submitting. Apple's API performs server-side eligibility checks. [Create submission](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissions), [submission items](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissionitems).

Final submission is a separate PATCH to `/v1/reviewSubmissions/{id}`:

```json
{"data":{"type":"reviewSubmissions","id":"SUBMISSION_ID","attributes":{"submitted":true}}}
```

```bash
python3 scripts/asc-api.py "/v1/reviewSubmissions/$ASC_REVIEW_SUBMISSION_ID" \
  --method PATCH --body "$LINEPAY_RELEASE_DIR/submit-review.json" --allow-write
python3 scripts/asc-api.py "/v1/reviewSubmissions/$ASC_REVIEW_SUBMISSION_ID"
python3 scripts/asc-api.py "/v1/reviewSubmissions/$ASC_REVIEW_SUBMISSION_ID/items"
```

Retain the returned state, errors and IDs. A successful creation of a review container is not a submitted review. [Modify submission](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-reviewsubmissions-_id_).

## 8. Public release and recovery

If the intended version uses `AFTER_APPROVAL`, public release follows Apple's approval workflow; do not silently change to manual or vice versa. With manual release, require `PENDING_DEVELOPER_RELEASE` and explicit release authority before `POST /v1/appStoreVersionReleaseRequests`:

```json
{"data":{"type":"appStoreVersionReleaseRequests","relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":"VERSION_ID"}}}}}
```

Apple says this release request cannot be canceled. Do not execute it as a readiness probe. Re-read distribution/territory state and confirm the correct app/version on the public target storefront before saying **published**. [Manual release API](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstoreversionreleaserequests).

| Failure | Response |
|---|---|
| 401 | Check key/issuer pairing, JWT lifetime and host clock; never print the token |
| 403 | Inspect existing role/app access; do not auto-create or upgrade credentials |
| 409/422 | Read the exact field/resource error and current draft; preserve unrelated edits |
| 429/5xx/read timeout | Honor rate limits/backoff and bound polling |
| Uncertain mutation/upload | Reconcile server state by app/version/build/resource ID before retrying; never blindly repeat POST |
| Signing failure | Inspect installed profile/certificate/team; no blanket provisioning-update retry |
| Rejected/unready candidate | Keep prior production intact, fix the source, create a new tested build; never pretend it is a binary rollback |
| Approval blocked | Record the exact decision and stop that action; complete independent safe work |

## 9. Close each run with a dated release record

Document the source revision/diff, version/build, IPA SHA-256, Apple build/upload/submission IDs, validation results, exact TestFlight groups and notification choices, StoreKit evidence, approved compliance answers, final state and observation time, public URL if verified, and remaining blockers/owner. Exclude secrets and raw contact/tester data.

Mark each step **executed and verified**, **documented but not exercised**, or **blocked**. Build 2 verified local archive/export, API-key upload, processing, metadata updates and build selection. On September 5 the user explicitly requested Chrome for the final submission: Apple accepted review submission `b44b871f-7e40-4570-829b-50ce9a640fd0`, and subsequent REST reads confirmed `WAITING_FOR_REVIEW`. That is UI submission plus API readback, not proof that the REST submission-write examples ran. Beta distribution, REST submission writes, and public-release examples remain unexercised for LinePaycheck.

After a future successful release, update the dated run record with the actual TestFlight/review/public readbacks and amend this guide only for newly proven operational details. This documentation request does not itself authorize another upload, tester notification, compliance declaration, or publication.

Offline client checks:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_asc_api.py' -v
git diff --check
```

The endpoint/payload examples were checked against Apple's [official OpenAPI reference](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip). Recheck the current specification when an API schema or platform requirement changes; do not rely on private web endpoints as a compatibility layer.

Documentation/client validation on September 5, 2026: seven offline tests passed; all six JSON payload examples passed schema validation against 4.4.1; eleven shell blocks passed `bash -n`; export plist and local links parsed/resolved; one live read-only request returned the expected app ID/name/bundle ID. No beta distribution, declaration, or review/public-release mutation was performed to test this guide.
