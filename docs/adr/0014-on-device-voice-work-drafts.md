# ADR 0014: on-device voice work drafts

Status: accepted for the owner-authorized v2 implementation, October 16, 2026. Implementation `e4aaf22` passed the complete native gate: 342 passed, zero failed, one intentional store-screenshot skip. Microphone and recognition accuracy on a supported physical device remain unproven.

The owner required local-only operation for every roadmap stage. Voice input therefore uses Apple's
native recorder and Speech recognizer, with no remote processor, SDK or fallback. Recording starts
only from an explicit action after microphone/speech authorization. Both initial setup and actual
recognition require `supportsOnDeviceRecognition` and availability. Every Speech request sets
`requiresOnDeviceRecognition = true`; a missing local recognizer fails closed to manual input.

A recording lasts at most one minute. Its protected, backup-excluded temporary CAF is removed on
completion/cancel; the next process launch retries abandoned-file cleanup. Cleanup errors remain
visible and prevent starting another recording in that session. All-local-data deletion retries
owned-audio cleanup before deleting pay data. Unknown files and paths outside the owned directory
are not removed. Raw audio/transcript are not added to financial state, evidence or backups.

A final reading is editable and untrusted. The parser accepts explicit regular/callout/other clock
facts, the selected local start date/timezone, optional explicit next-day endpoints, and either
stated unpaid-break intervals or an explicit no-unpaid-breaks statement. Bare ambiguous clock hours,
missing break facts, extra/negated instructions, overlapping breaks and DST gaps/folds are rejected
rather than normalized into work. No rate, overtime applicability or guarantee is inferred.

The worker reviews proposed dates, clock times, work type and breaks, explicitly confirms them,
then applies them to the existing work editor. This only changes its draft; the final Save work
remains separate. Existing overlap, pay-period, break, callout-identity and persistence validation
still governs the saved entry. Notes and entry identity remain; prior saved work/history cannot
change merely because a transcript arrived. A changed reading/date resets review confirmation.

Late permission, recorder and recognition callbacks are ignored after cancellation or a new
capture session. Leaving the foreground stops recording; no background microphone mode is added.
Permission denial, unavailable local models, interruption, timeout and cleanup failure keep manual
entry available and cannot save work or grant a pay rule.

Sources retrieved October 16, 2026:

- Apple: [on-device support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- Apple: [required local recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- Apple: [file recognition requests](https://developer.apple.com/documentation/speech/sfspeechurlrecognitionrequest)
- Apple: [microphone permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:))
- Apple: [privacy details](https://developer.apple.com/app-store/app-privacy-details/)

Apple distinguishes on-device processing from off-device collection. This architecture is designed
to retain that boundary; source flags and simulator tests are not proof of real-device network
behavior or a fresh App Privacy owner review. Resource inventory updates record purpose strings
mechanically and do not provide release authorization or close a privacy/legal issue.
