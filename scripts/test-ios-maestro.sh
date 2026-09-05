#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DERIVED_DATA="$ROOT/.build/maestro-ios"
DEVICE_NAME="${MAESTRO_IOS_DEVICE:-iPhone 17 Pro}"
TEST_TARGET="${1:-$ROOT/.maestro}"

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
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b

echo "==> Build LinePay for simulator"
rm -rf "$DERIVED_DATA"
xcodebuild \
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
maestro --udid "$DEVICE_UDID" test "$TEST_TARGET"
