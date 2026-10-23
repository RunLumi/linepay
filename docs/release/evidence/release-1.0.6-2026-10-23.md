# Lineman Pay 1.0.6 (14) — name-only App Review submission, October 23, 2026

[Release home](../README.md) · [v3 name decision](../../plan/v3.md)

## Owner-selected scope and source

The owner requested release with the v3 name and explicitly selected a **name-only update from
the released app**, retaining its features and store description. This is separate from the
unready 1.1.0 candidate and its unresolved accessibility findings.

- Production base: `192d9ea621e0a2cd691d0b1dc5f99b5a59075ece`, verified against the 1.0.5 build-11 receipt and Apple's current selected production build.
- Release source: [`3f4ee0006186ce4bd150007bea8eeabaae4d4abf`](https://github.com/RunLumi/linepay/commit/3f4ee0006186ce4bd150007bea8eeabaae4d4abf), clean branch `codex/ios-1.0.6-lineman-pay`.
- Display/listing name: **Lineman Pay**. Embedded identity: `com.streamentry.linepay / 1.0.6 / 14`.
- App sources and resources are byte-identical to the production base. The patch changes the display name, version/build, matching harness/doctor checks and the project inventory.
- Scheme, bundle ID, app data, calculations, subscriptions and features are retained. No 1.1.0 feature, voice permission or password-protected-backup implementation is included.

The production-based release branch must not be merged over the newer 1.1.0 application on main.
The release receipt is maintained on main independently.

## Executed local validation

| Check | Result |
|---|---|
| Doctor, strict Swift lint, privacy manifest and legal inventory | Passed |
| Domain / repository / app tests | 109 / 71 / 240 passed |
| Native UI | 11 passed, 2 skipped, 0 failed |
| Skipped cases | Existing legal report-share and largest-text rule-scope journeys: system controls were unavailable; skips are not acceptance evidence |
| Simulator Release build / dependency lock | Passed / preserved |
| Actual visual inspection | Synthetic Today screen, USD 550 and 10 hours; readable production UI |
| Signed device archive / IPA export / signature | Passed using existing signing; no provisioning update |
| IPA | 4,564,728 bytes; SHA-256 `53fb45a13ca8729ec10b80db51c4eb25f20d3381c14dd89bd5390af2b116f26b` |
| Embedded privacy | No collection/tracking declarations; no new microphone/speech permission; non-exempt encryption flag false |

Validation used Xcode 27.1 / Swift 6.4, iOS 18.5 on the existing iPhone 16 simulator.
It does not establish pinned Xcode 26.6, new physical-device, VoiceOver or sandbox-purchase evidence.
No claim is made that the pending 1.1.0 accessibility findings were fixed. The full native script
exited 0; its two skipped legal cases remain explicit limitations.

## Apple state and release authority

Before delivery, Apple's current production version was `1.0.5 / READY_FOR_SALE`, selected build
`4d5db312-726f-44da-8a4e-10429fb3a126` (11). All 12 upload reservations were inspected; build 14
was absent. Both existing subscriptions were `APPROVED`. The single en-US listing had eight
screenshots in the 6.5-inch set. The selected scope preserves its subtitle, description, screenshots,
prices, offers, review contact and territories; only the app name and truthful version release
notes are intended to change. Manual release is intended for the new version.

The owner's current request and explicit name-only selection use the **standing per-release
waiver with a receipt**, documented in [legal controls](../../legal/README.md). This is release
authority, not a fabricated 21-finding approval bundle, counsel/trademark clearance or device-test
receipt. The checked-in `asc-api.py` guard is unchanged. The private one-off client validates the
clean source, exact IPA hash, intended app, native result and Apple's current official OpenAPI
4.5.1 payload shapes, records each exact request and performs no automatic mutation retry.

## Executed Apple delivery and submission

| Milestone | Verified result |
|---|---|
| Apple validation / upload | Both altool operations exited 0; uploader 27.0.5; same exact IPA as above |
| Upload / build ID | `1c3947bb-5924-4c2f-a395-6c97cb1f04be`; upload `COMPLETE`, build `VALID`, not expired; iOS `1.0.6 (14)` |
| App Store version | `f8eb634c-7208-43ab-bd89-b3b7efaa556e`; selected build read back as 14 |
| Listing name | Saved and independently read back as **Lineman Pay**; every other App Info localization field unchanged |
| Version copy | Only `whatsNew` differs from production; description, subtitle, keywords, promotional text and URLs retained |
| Screenshots | Eight inherited captures; filenames, sizes and source checksums match production |
| Review contact / copyright | Inherited values verified unchanged; contact data retained privately |
| Review submission | `7b3f6a8f-e0cf-4a6e-9a94-2ceab9d9169e`; exactly one version item; accepted as **WAITING_FOR_REVIEW** |
| Independent readbacks | Review and version both **WAITING_FOR_REVIEW**, release mode **MANUAL**, at `2026-10-23T11:41:07Z` (18:41 Asia/Ho_Chi_Minh) |

What's New: “LinePaycheck is now Lineman Pay. This update changes the app name. Your saved records,
confirmed pay rules, and subscription stay the same.”

No new privacy, age-rating, content-rights or encryption declaration was submitted. The existing
build encryption flag read back false. No TestFlight group, invitation or notification was changed,
and no legal agreement was accepted. Existing subscriptions remain approved with no price/offer
mutation. The name save is not a professional trademark-clearance opinion.

**Not public yet.** Apple approval and the subsequent manual release remain outstanding; no public
release request was sent. The production listing remains 1.0.5 until a later actual release.
This record does not promise an automatic release or close the separate 1.1.0/device/legal findings.

The archive, dSYMs, IPA, native log/xcresult, binary/source receipts, exact API payloads and hashes,
Apple readbacks and an existing credential reference are retained in a new private SSD release
bundle outside Git (directory 0700, private records 0600, executable archive modes preserved).
The retained IPA checksum and archive signature were reverified. No `.p8` was copied or created.
Private contacts, issuer/key references and raw account responses are not in this repository.
