# LinePaycheck native Android work

The owner explicitly authorized every v2 stage on October 16, 2026, including native Android despite
the earlier demand gate. Kotlin + Jetpack Compose remains the client direction; no account, pay-data
backend, analytics collector or shared Swift runtime is introduced.

**Implemented and JVM-tested:**

- `domain`: immutable configured-rule/work inputs, exact BigDecimal/second pricing, daily tiers,
  break/day/schedule segmentation, explicit weekday/date premiums, isolated physical callout minima,
  per diem, effective-dated rule selection, explicit rounding and ledger allocation.
  Separate employer-contribution calculations use confirmed fund/period/rate/unit facts; they do
  not add benefits to wages or infer eligibility.
- `backup`: JCA password-protected transport matching the shared native/Node/browser vector.
  This module does not decode financial snapshot state, perform restore or retain a password.

**Not yet delivered:** Compose application, persistence/migration/history, complete native feature
parity, actual Android OCR/voice/commerce adapters, snapshot-state interchange and device/emulator
E2E. Passing JVM tests is not a native app build or Android-runtime verification. The configured-pay
fixture subset does not establish statutory, complete agreement, benefits or weekly-rate coverage.
Schedule boundaries that fall in a clock gap/fold fail closed pending explicit review/parity work.

## Reproduce the current checks

JDK 21 runs the build; library bytecode targets JVM 17. Gradle 9.4.1, Kotlin 2.4.0, dependency locks
and SHA-256 verification metadata are checked in. The official Gradle wrapper and distribution
checksums were verified. No Android SDK or emulator is needed for these JVM checks.

From the repository root on macOS:

```bash
JAVA_HOME="$(/usr/libexec/java_home -v 21)" \
GRADLE_USER_HOME="$PWD/.build/android-gradle" \
apps/android/gradlew -p apps/android --no-daemon --dependency-verification strict :domain:test :backup:test
```

On another host, set JAVA_HOME to an installed JDK 21. The first run needs standard Maven/Gradle
repositories; subsequent runs can use `--offline` when all dependencies are cached. Test XML and
HTML reports are under each module's ignored `build/` directory. Shared fixtures are read directly
from `shared/contracts/`, never copied into the production library.

Current evidence: nineteen shared payroll cases, nine additional pay boundaries, thirteen shared fund cases,
six additional fund boundaries, and four backup transport cases passed. The backup Unicode/tamper tests use explicitly public synthetic
fixture inputs. No real worker/credential data belongs in tests or logs.

The configured-pay engine has its own `linepay.android.configured-pay/1` provenance. Do not admit
it to another client's persisted results or claim full parity solely because the current nineteen
cases match. Broader native contracts and runtime evidence must precede that decision.
