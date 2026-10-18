#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="$ROOT/.build/android-sdk"
if [[ -n "${ANDROID_SDK_ROOT:-}" && -x "${ANDROID_SDK_ROOT}/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_SDK_ROOT"
elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_HOME"
fi
JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"
MAESTRO_BIN="${MAESTRO_BIN:-$ROOT/.build/tools/maestro-2.11.0/maestro/bin/maestro}"

if [[ -z "$JAVA_HOME" || ! -x "$JAVA_HOME/bin/java" ]]; then
    echo "error: JDK 21 is required; set JAVA_HOME" >&2
    exit 1
fi
if [[ ! -x "$SDK_ROOT/platform-tools/adb" ]]; then
    echo "error: Android SDK not found at $SDK_ROOT" >&2
    exit 1
fi
if [[ ! -x "$MAESTRO_BIN" ]]; then
    if command -v maestro >/dev/null 2>&1; then
        MAESTRO_BIN="$(command -v maestro)"
    else
        echo "error: Maestro CLI 2.11.0 is not installed; see apps/android/README.md" >&2
        exit 1
    fi
fi

export JAVA_HOME
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$ROOT/.build/android-avd}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$ROOT/.build/android-user}"
export ANDROID_EMULATOR_HOME="${ANDROID_EMULATOR_HOME:-$ROOT/.build/android-emulator-home}"
export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$PATH"
export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
export MAESTRO_OPTS="${MAESTRO_OPTS:-} -Duser.home=$ROOT/.build/maestro-home"

CONNECTED_DEVICES=()
while IFS= read -r device; do
    CONNECTED_DEVICES+=("$device")
done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
if [[ ${#CONNECTED_DEVICES[@]} -ne 1 ]]; then
    echo "error: Android Maestro requires exactly one online device; found ${#CONNECTED_DEVICES[@]}" >&2
    adb devices -l >&2
    exit 1
fi
ANDROID_SERIAL="${ANDROID_SERIAL:-${CONNECTED_DEVICES[0]}}"
if [[ "$ANDROID_SERIAL" != "${CONNECTED_DEVICES[0]}" ]]; then
    echo "error: selected Android device does not match the sole connected device" >&2
    exit 1
fi
if [[ "$ANDROID_SERIAL" != emulator-* ]]; then
    echo "error: Maestro clearState and Files-provider tests run only on a synthetic Android emulator" >&2
    exit 1
fi
AVD_NAME="$(adb -s "$ANDROID_SERIAL" shell getprop ro.boot.qemu.avd_name | tr -d '\r')"
if [[ "$AVD_NAME" != "LinePaycheck_E2E_API_36" ]]; then
    echo "error: Maestro E2E expects the task's LinePaycheck_E2E_API_36 AVD; found '$AVD_NAME'" >&2
    exit 1
fi

mkdir -p "$ROOT/.build/maestro-results" "$ROOT/.build/maestro-home"
TEST_BACKUP_PATH="/sdcard/Download/LinePaycheck-backup.lpb"
cleanup_test_backup() {
    adb -s "$ANDROID_SERIAL" shell rm -f "$TEST_BACKUP_PATH" >/dev/null 2>&1 || true
}
trap cleanup_test_backup EXIT
adb -s "$ANDROID_SERIAL" shell rm -f "$TEST_BACKUP_PATH"
adb -s "$ANDROID_SERIAL" install -r \
    "$ROOT/apps/android/app/build/outputs/apk/debug/app-debug.apk"
"$MAESTRO_BIN" --device="$ANDROID_SERIAL" test \
    --format JUNIT \
    --output "$ROOT/.build/maestro-results/android-first-paycheck.xml" \
    "$ROOT/.maestro/android/first-paycheck.yaml"
