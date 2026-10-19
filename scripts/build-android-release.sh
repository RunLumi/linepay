#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for name in LINEPAY_ANDROID_KEYSTORE LINEPAY_ANDROID_STORE_PASSWORD LINEPAY_ANDROID_KEY_ALIAS LINEPAY_ANDROID_KEY_PASSWORD; do
    if [[ -z "${!name:-}" ]]; then
        echo "error: $name must be supplied through the environment" >&2
        exit 1
    fi
done
if [[ ! -f "$LINEPAY_ANDROID_KEYSTORE" ]]; then
    echo "error: upload keystore does not exist" >&2
    exit 1
fi

SDK_ROOT="$ROOT/.build/android-sdk"
if [[ -n "${ANDROID_SDK_ROOT:-}" && -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_SDK_ROOT"
elif [[ -n "${ANDROID_HOME:-}" && -x "$ANDROID_HOME/platform-tools/adb" ]]; then
    SDK_ROOT="$ANDROID_HOME"
fi
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21)}"
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$ROOT/.build/android-user}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.build/android-gradle}"

"$ROOT/apps/android/gradlew" -p "$ROOT/apps/android" --no-daemon --dependency-verification strict \
    :app:bundleRelease :app:assembleRelease :app:lintRelease

AAB="$ROOT/apps/android/app/build/outputs/bundle/release/app-release.aab"
APK="$ROOT/apps/android/app/build/outputs/apk/release/app-release.apk"
VERIFICATION="$("$JAVA_HOME/bin/jarsigner" -J-Duser.language=en -verify "$AAB")"
if [[ "$VERIFICATION" != *"jar verified."* ]]; then
    echo "error: release bundle signature was not verified" >&2
    exit 1
fi
printf '%s\n' "$VERIFICATION"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose --print-certs "$APK"
shasum -a 256 "$AAB" "$APK"
