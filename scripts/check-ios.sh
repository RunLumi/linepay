#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DOMAIN_DIR="$IOS_DIR/Packages/LinePayDomain"

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

echo "==> Build app for generic iOS Simulator"
xcodebuild \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
