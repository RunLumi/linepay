# ADR 0017: native Android calculation and backup boundaries

Status: accepted for the owner's explicit all-stage v2 authorization. October 17, 2026. This
calculation/transport decision does not change iOS release authority. The initial native Compose
implementation and its bounded persistence decision are recorded separately in [ADR 0030](0030-android-local-native-state-and-export.md).

Use native Kotlin and Compose rather than a shared Swift/runtime layer. Begin with independently
testable JVM libraries: deterministic configured-pay `domain` and separate password-transport
`backup`. Domain calculations contain no Android UI, clock, locale, storage, commerce, networking,
analytics or cryptographic-randomness dependencies. Money is BigDecimal with explicit currency;
actual time/tier positions remain seconds through monetary rounding. Inputs are defensively copied.

The configured engine covers explicit daily/schedule/date/weekday rules, effective dates, breaks,
physical callout identity and guarded isolated minima, separate per diem, rounding policy and ledger
allocation. It must reject ambiguous/unsupported inputs instead of inventing a rule. In particular,
ambiguous/nonexistent schedule wall-clock boundaries are review-required. This conservative behavior
needs broader parity/source evaluation; matching the first nineteen fixtures is not full parity.
Use separate Android engine provenance until complete cross-client admission is actually justified.

The backup adapter uses Java cryptographic APIs for the shared AES-256-GCM/PBKDF2 transport, with
canonical Unicode, fixed bounded derivation work and authenticated headers. It releases plaintext
only after authentication. It owns no file picker, password storage, account or restore operation.
Snapshot-schema decoding and financial replacement safety are later client responsibilities, not
established by a cipher-vector match. JVM-provider tests are distinct from Android runtime behavior.

Pin Gradle 9.4.1 and Kotlin 2.4.0; use installed JDK 21 and target JVM 17 bytecode for later Android
adoption. Official wrapper/distribution SHA-256 values, dependency locks and verification metadata
are retained. JUnit and Gson are test-only; no runtime payroll SDK or remote dependency is added.
Generating dependency checksums is mechanical integrity bookkeeping, not legal/source approval.

At the October 17 checkpoint, the Android SDK target was empty and no runtime or emulator had been
installed. On October 19, after explicit owner approval, Android command-line tools, SDK 36, and one
Pixel 8/API 36 ARM64 AVD were installed under ignored `.build` storage. The first Compose client now
has a bounded local work/check workflow, versioned file state, and explicit encrypted backup
restore. Its JVM, build, lint, and AVD test evidence is in [v2 execution](../plan/v2-execution.md).
Keep development caches local to this repository by default. Full parity, OCR/voice, commerce,
weekly-rate computation, source/applicability review, localization, physical-device validation and
store gates remain outside that first Android slice.

Primary build references checked October 17, 2026:

- [Kotlin 2.4 compatibility](https://kotlinlang.org/docs/whatsnew24.html)
- [Kotlin Gradle configuration](https://kotlinlang.org/docs/gradle-configure-project.html)
- [Android Gradle compatibility](https://developer.android.com/build/releases/about-agp)
- [Official Gradle wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
