# Android agent instructions

The repository-root `AGENTS.md` remains authoritative.

The owner explicitly authorized Android as part of all v2 stages on October 16, 2026. Current implementation work is authorized; preserve the local-only decision and report JVM, app-build, emulator, physical-device and Play evidence separately.

## Android baseline and release guardrails

- Kotlin + Jetpack Compose; pure payroll logic stays in `:domain` and has no Android dependency.
- JDK 21, Gradle 9.4.1, Kotlin/KGP 2.4.0, JVM 17 bytecode, AGP 9.2.0.
- Compose BOM 2026.06.00; compile/target SDK 36; minimum SDK 26.
- Keep SDK, AVD, user config and Gradle caches under the ignored repository `.build` directory by default.
- The current KGP 2.4.0 Android plugin requires temporary AGP 9 legacy-DSL/built-in-Kotlin opt-outs. Do not remove or upgrade these independently; verify the Kotlin metadata boundary and all modules before migration.
- Android pay data remains app-private; automatic Android backup and network permission stay disabled. Manual encrypted backup and the separate opt-in local activity export are user initiated.

The general default outside that authorization remains: Android is **deferred until product demand justifies the second native client**. Do not create Android app architecture, Gradle scaffolding, shared-runtime abstractions, or feature parity work unless the user/task explicitly asks to begin Android implementation.

When Android work is authorized:

- use native Kotlin + Jetpack Compose;
- preserve the local-first/no-account product architecture unless a demonstrated requirement changes it;
- treat `shared/contracts` fixtures as the behavioral treaty with iOS;
- do not port Swift implementation details merely for symmetry;
- keep payroll calculations deterministic and independently tested against the same canonical fixtures.

Current Android product work uses the `:app` Compose client, app-private versioned state, and the
separate opt-in `LocalActivityStore`. Pay-data backup is explicit and password-protected; the
diagnostics ledger is excluded. Android automatic cloud backup and `INTERNET` permission stay off.
Run `bash scripts/check-android.sh unit` for strict JVM/app/release/lint verification and
`bash scripts/agent-verify.sh android-ui` only when the synthetic `LinePaycheck_E2E_API_36` AVD is online.

The first Android client is a bounded configured-rules vertical slice. It is not full iOS feature
parity: do not represent user rule confirmation as independent applicability or legal verification,
and keep unresolved weekly-rate, line-level paystub, OCR/voice, commerce, localization,
and physical-device/store evidence visible. Manual employer-contribution receipts use the existing
four-basis calculator and retain separate fund/period/source evidence; they do not establish
eligibility, caps, remittance timing, legal-fringe compliance or wage-check clearance.

Outside explicit task authorization, the best Android code is no Android code.
