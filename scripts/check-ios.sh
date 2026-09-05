#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DOMAIN_DIR="$IOS_DIR/Packages/LinePayDomain"
PRIVACY_MANIFEST="$IOS_DIR/App/Resources/PrivacyInfo.xcprivacy"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/linepay-derived.XXXXXX")"
trap 'rm -rf "$DERIVED_DATA"' EXIT

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required; run scripts/bootstrap-ios.sh after installing it" >&2
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "error: Swift toolchain is required" >&2
    exit 1
fi

echo "==> Lint Swift"
swift format lint \
    --strict \
    --recursive \
    --configuration "$ROOT/.swift-format" \
    "$IOS_DIR"

echo "==> Validate privacy manifest"
plutil -lint "$PRIVACY_MANIFEST"

echo "==> Test pure domain package"
(
    cd "$DOMAIN_DIR"
    swift test
)

echo "==> Generate Xcode project"
(
    cd "$IOS_DIR"
    xcodegen generate
)

echo "==> Run app-layer tests on iOS Simulator"
xcodebuild \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    test

BUILT_PRIVACY_MANIFEST="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LinePay.app/PrivacyInfo.xcprivacy"
if [[ ! -f "$BUILT_PRIVACY_MANIFEST" ]]; then
    echo "error: PrivacyInfo.xcprivacy was not bundled into LinePay.app" >&2
    exit 1
fi

echo "==> Build Release for generic iOS Simulator"
xcodebuild \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build
