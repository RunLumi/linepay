#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DERIVED_DATA="${LINEPAY_MAESTRO_DERIVED_DATA:-$ROOT/.build/maestro-ios}"
RESULTS_DIR="${LINEPAY_MAESTRO_RESULTS_DIR:-$ROOT/.build/maestro-results}"
DEVICE_NAME="${MAESTRO_IOS_DEVICE:-iPhone 17 Pro}"
TEST_TARGET="${1:-$ROOT/.maestro}"
MAESTRO_PID=""
IOS_BUILD_JOBS="${LINEPAY_IOS_BUILD_JOBS:-2}"
if [[ ! "$IOS_BUILD_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: LINEPAY_IOS_BUILD_JOBS must be a positive integer" >&2
    exit 64
fi

check_task_output() {
    local output="$1" default_output="$2"
    if [[ "$output" != "$default_output" && -e "$output" \
        && ! -f "$output/.linepay-maestro-output" ]]; then
        local entry populated=false
        for entry in "$output"/* "$output"/.[!.]* "$output"/..?*; do
            if [[ -e "$entry" || -L "$entry" ]]; then populated=true; break; fi
        done
        if [[ ! -d "$output" || "$populated" == true ]]; then
            echo "error: output override must be an empty or dedicated task directory: $output" >&2
            exit 64
        fi
    fi
}
check_task_output "$DERIVED_DATA" "$ROOT/.build/maestro-ios"
check_task_output "$RESULTS_DIR" "$ROOT/.build/maestro-results"

cleanup() {
    if [[ -n "$MAESTRO_PID" ]] && kill -0 "$MAESTRO_PID" 2>/dev/null; then
        kill "$MAESTRO_PID" 2>/dev/null || true
        wait "$MAESTRO_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

for command in xcodebuild xcrun xcodegen maestro; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "error: $command is required" >&2
        exit 1
    fi
done

DEVICE_LINE="$(xcrun simctl list devices available | grep -F "$DEVICE_NAME (" | head -n 1 || true)"
if [[ -z "$DEVICE_LINE" ]]; then
    echo "error: no available iOS Simulator named '$DEVICE_NAME'" >&2
    echo "Set MAESTRO_IOS_DEVICE to one shown by: xcrun simctl list devices available" >&2
    exit 1
fi

DEVICE_UDID="$(printf '%s\n' "$DEVICE_LINE" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')"
if [[ ! "$DEVICE_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    echo "error: could not determine simulator UDID from: $DEVICE_LINE" >&2
    exit 1
fi

echo "==> Generate Xcode project"
(
    cd "$IOS_DIR"
    xcodegen generate
)

echo "==> Boot $DEVICE_NAME ($DEVICE_UDID)"
xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
if [[ "${CI:-}" != "true" ]]; then
    open -a Simulator >/dev/null 2>&1 || true
fi
xcrun simctl bootstatus "$DEVICE_UDID" -b

echo "==> Build LinePay for simulator"
rm -rf "$DERIVED_DATA"
mkdir -p "$DERIVED_DATA"
touch "$DERIVED_DATA/.linepay-maestro-output"
xcodebuild \
    -jobs "$IOS_BUILD_JOBS" \
    -onlyUsePackageVersionsFromResolvedFile \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LinePay.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "error: expected simulator app at $APP_PATH" >&2
    exit 1
fi

echo "==> Install LinePay"
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

echo "==> Run Maestro: $TEST_TARGET"
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"
touch "$RESULTS_DIR/.linepay-maestro-output"
maestro --udid "$DEVICE_UDID" test --test-output-dir "$RESULTS_DIR" "$TEST_TARGET" &
MAESTRO_PID=$!
wait "$MAESTRO_PID"
MAESTRO_STATUS=$?
MAESTRO_PID=""
exit "$MAESTRO_STATUS"
