#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT/apps/android"
MODE="${1:-unit}"
SDK_ROOT="$ROOT/.build/android-sdk"
if [[ -n "${ANDROID_SDK_ROOT:-}" && -x "${ANDROID_SDK_ROOT}/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_SDK_ROOT"
elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_HOME"
fi
JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"

if [[ -z "$JAVA_HOME" || ! -x "$JAVA_HOME/bin/java" ]]; then
    echo "error: JDK 21 is required; set JAVA_HOME to an installed JDK 21" >&2
    exit 1
fi
if ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q 'version "21\.'; then
    echo "error: this repository's Android build uses JDK 21" >&2
    exit 1
fi
if [[ ! -x "$SDK_ROOT/platform-tools/adb" ]]; then
    echo "error: Android SDK not found at $SDK_ROOT; set ANDROID_SDK_ROOT" >&2
    exit 1
fi

export JAVA_HOME
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$ROOT/.build/android-avd}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$ROOT/.build/android-user}"
export ANDROID_EMULATOR_HOME="${ANDROID_EMULATOR_HOME:-$ROOT/.build/android-emulator-home}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.build/android-gradle}"
export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$PATH"

case "$MODE" in
    unit)
        "$ANDROID_DIR/gradlew" -p "$ANDROID_DIR" --no-daemon --dependency-verification strict \
            :domain:test :backup:test :app:testDebugUnitTest :app:assembleDebug \
            :app:assembleRelease :app:lintDebug
        ;;
    device)
        CONNECTED_DEVICES=()
        while IFS= read -r device; do
            CONNECTED_DEVICES+=("$device")
        done < <(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')
        if [[ ${#CONNECTED_DEVICES[@]} -ne 1 ]]; then
            echo "error: device E2E requires exactly one online Android device; found ${#CONNECTED_DEVICES[@]}" >&2
            adb devices -l >&2
            exit 1
        fi
        export ANDROID_SERIAL="${CONNECTED_DEVICES[0]}"
        if [[ "$ANDROID_SERIAL" != emulator-* ]]; then
            echo "error: destructive synthetic-app reset is allowed only on an Android emulator" >&2
            exit 1
        fi
        AVD_NAME="$(adb -s "$ANDROID_SERIAL" shell getprop ro.boot.qemu.avd_name | tr -d '\r')"
        if [[ "$AVD_NAME" != "LinePaycheck_E2E_API_36" ]]; then
            echo "error: device E2E expects the task's LinePaycheck_E2E_API_36 AVD; found '$AVD_NAME'" >&2
            exit 1
        fi
        set +e
        "$ANDROID_DIR/gradlew" -p "$ANDROID_DIR" --no-daemon --dependency-verification strict \
            :app:connectedDebugAndroidTest
        GRADLE_RESULT=$?
        set -e
        exit "$GRADLE_RESULT"
        ;;
    *)
        echo "usage: bash scripts/check-android.sh [unit|device]" >&2
        exit 64
        ;;
esac
