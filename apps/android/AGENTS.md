# Android agent instructions

The repository-root `AGENTS.md` remains authoritative.

Android is intentionally **deferred until product demand justifies the second native client**. Do not create Android app architecture, Gradle scaffolding, shared-runtime abstractions, or feature parity work unless the user/task explicitly asks to begin Android implementation.

When Android work is authorized:

- use native Kotlin + Jetpack Compose;
- preserve the local-first/no-account product architecture unless a demonstrated requirement changes it;
- treat `shared/contracts` fixtures as the behavioral treaty with iOS;
- do not port Swift implementation details merely for symmetry;
- keep payroll calculations deterministic and independently tested against the same canonical fixtures.

Until then, the best Android code is no Android code.
