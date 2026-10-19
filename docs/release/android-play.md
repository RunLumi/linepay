# Android Play release

[Release index](README.md) · [Android client](../../apps/android/README.md) · [v3 positioning](../plan/v3.md)

The Android package remains `com.streamentry.linepay.android`. The first candidate uses
version `1.0`, code `1`, and the v3 display name **Paycheck Audit: LinePay**. Its supported
scope is manual configured-rule wages, work records, a period-confirmed gross comparison,
immutable history, encrypted manual backup and local diagnostics. Do not advertise Android
OCR, weekly-rate review, line-level paystub intake, subscriptions or full iOS parity.

The subsequent verified candidate is 1.0.1/code 2 from source `301b916`, with the in-app
privacy-policy action and corrected Pay-screen error rendering. The same bundle is available
internally and in U.S. production review. See the [dated release evidence](evidence/android-1.0.1-2026-10-19.md)
for source hashes, actual test layers, approval history and current publication boundaries.

## Signing and recovery

Supply `LINEPAY_ANDROID_KEYSTORE`, `LINEPAY_ANDROID_STORE_PASSWORD`,
`LINEPAY_ANDROID_KEY_ALIAS` and `LINEPAY_ANDROID_KEY_PASSWORD` through the environment.
Partial configuration refuses. Ordinary CI can still build unsigned release artifacts without
the four variables; those artifacts are not Play upload candidates.

The owner requested a recovery bundle under repository-local `backups/`. That directory is
Git-ignored, mode 0700, with mode 0600 files. The dated bundle contains the upload keystore,
public certificate, `signing.env`, `signing.json`, recovery instructions and `SHA256SUMS`.
Passwords are stored in plaintext beside the password-encrypted key as explicitly requested;
filesystem permissions do not encrypt the recovery bundle. Never include its contents in
Git, CI, screenshots, public artifacts or support requests. Retain a separate private copy
for protection against loss of this disk.

The upload key signs the AAB sent to Play. With Google-generated Play App Signing, Google
holds the separate distribution private key; backing up the upload keystore does not back up
that Google-held private key. See [Android app signing](https://developer.android.com/studio/publish/app-signing).

After restoring the bundle to another machine, update its private `signing.env` keystore path.
Source that trusted local file in a shell with command tracing disabled, then run:

```bash
bash scripts/check-android.sh unit
bash scripts/build-android-release.sh
bash scripts/agent-verify.sh android-ui
```

Use the existing synthetic `LinePaycheck_E2E_API_36` emulator for device checks. Never reset
a real worker's device or data. The release builder verifies the AAB signature and APK signing
certificate; retain source SHA, artifact hashes, certificate fingerprint and actual test results.

## Play Console

Check for an existing listing before creating one. Preserve the package ID permanently.
Use the current Play Console UI through the Browser plugin for this owner-authorized release.
App creation requires publisher attestations for Developer Program policies and U.S. export
laws; technical tests do not supply those attestations. Keep an approval block visible rather
than using another interface to bypass it.

Before production submission, complete the actual app-content, privacy, audience, ads,
content-rating, financial-feature, app-access and store-listing requirements. The app has no
account or network permission, but the publisher must review the actual Play disclosures.
Use real synthetic Android screenshots and the existing brand asset. Never reuse iOS screenshots
to imply Android features. Keep US payroll scope explicit and do not claim legal certification.

Upload the signed AAB, confirm package/version/certificate readback, review the selected track
and countries, then submit the authorized release. Record upload, review, testing availability
and production availability separately. A saved draft or successful upload is not publication.
Google may impose testing or account-verification requirements; report the actual console state.

## First-release listing draft

- Name: **Paycheck Audit: LinePay**
- Short description: **Track hours, estimate gross pay, and compare your paycheck privately.**
- Language: English (United States).
- Category candidate: Finance; no ads, employer login, payroll processing or money transfer.

Full description draft:

> Track the work you performed. Estimate gross pay using the rates and rules you confirm.
> Compare that estimate with a gross paycheck figure for the same period, then keep the
> work facts, configured rules and comparison together in your local history.
>
> Record shift times, payroll timezone and unpaid breaks. Choose your pay-cycle dates and
> confirm the comparison period and gross basis. Missing or unsupported information stays
> visible as a review requirement.
>
> Your records stay in app-private storage. There is no LinePay account, employer login,
> advertising SDK or pay-data server. Create a password-protected manual backup using
> Android's file picker, and preview a backup before replacing local records.
>
> This Android release supports manual configured-rule estimates and gross comparisons.
> It does not scan paystubs, calculate take-home taxes, infer applicable overtime law,
> verify agreements, process payroll or decide whether an employer violated the law.
> A possible difference is a prompt to review the facts, not proof of underpayment.

The privacy policy was updated with owner approval and its Android section was verified live
on October 19, 2026. Platform-specific backup, local diagnostics and no-network/no-account
behavior are described separately from the existing iPhone app. Future releases must recheck
the actual policy against their binaries and disclosures.
