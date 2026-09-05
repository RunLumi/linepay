#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DOMAIN_DIR="$IOS_DIR/Packages/LinePayDomain"
PRIVACY_MANIFEST="$IOS_DIR/App/Resources/PrivacyInfo.xcprivacy"
EXPECTED_XCODEGEN_VERSION="2.46.0"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/linepay-derived.XXXXXX")"
trap 'rm -rf "$DERIVED_DATA"' EXIT

SIMULATOR_DESTINATION="${IOS_SIMULATOR_DESTINATION:-}"
if [[ -z "$SIMULATOR_DESTINATION" ]]; then
    SIMULATOR_UDID="$({ xcrun simctl list devices available 2>/dev/null || true; } \
        | sed -nE '/iPhone.*\([0-9A-Fa-f-]{36}\)/s/.*\(([0-9A-Fa-f-]{36})\).*/\1/p' \
        | head -n 1)"
    if [[ -z "$SIMULATOR_UDID" ]]; then
        echo "error: no available iPhone Simulator found" >&2
        exit 1
    fi
    SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required; run scripts/bootstrap-ios.sh after installing it" >&2
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "error: Swift toolchain is required" >&2
    exit 1
fi

XCODEGEN_VERSION="$(xcodegen --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
if [[ "$XCODEGEN_VERSION" != "$EXPECTED_XCODEGEN_VERSION" ]]; then
    echo "error: expected XcodeGen $EXPECTED_XCODEGEN_VERSION, found $XCODEGEN_VERSION" >&2
    echo "Update project.yml, CI, and this check deliberately when upgrading XcodeGen." >&2
    exit 1
fi

PACKAGE_LOCK="$IOS_DIR/LinePay.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$PACKAGE_LOCK" ]]; then
    echo "error: restore the tracked Xcode Package.resolved before building" >&2
    echo "git restore apps/ios/LinePay.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" >&2
    exit 1
fi
cp "$PACKAGE_LOCK" "$DERIVED_DATA/Package.resolved.expected"

check_package_lock() {
    if ! cmp -s "$DERIVED_DATA/Package.resolved.expected" "$PACKAGE_LOCK"; then
        echo "error: project generation or dependency resolution changed Package.resolved" >&2
        echo "Review and commit dependency changes deliberately; never regenerate the lock silently." >&2
        exit 1
    fi
}

RESULTS_DIR="${LINEPAY_TEST_RESULTS_DIR:-$ROOT/.test-results}"
mkdir -p "$RESULTS_DIR"
RESULTS_DIR="$(cd "$RESULTS_DIR" && pwd)"
if [[ -e "$RESULTS_DIR/AppTests.xcresult" ]]; then
    echo "error: $RESULTS_DIR/AppTests.xcresult already exists; use a fresh results directory" >&2
    exit 1
fi

echo "==> Toolchain"
xcodebuild -version
swift --version
xcodegen --version

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
    swift test --parallel --enable-code-coverage
)

DOMAIN_COVERAGE="$(find "$DOMAIN_DIR/.build" -path '*/codecov/LinePayDomain.json' -print -quit)"
if [[ -z "$DOMAIN_COVERAGE" ]]; then
    echo "error: SwiftPM did not produce the requested coverage report" >&2
    exit 1
fi
cp "$DOMAIN_COVERAGE" "$RESULTS_DIR/domain-coverage.json"

echo "==> Test repository scripts"
python3 -m unittest discover -s "$ROOT/scripts/tests" -v

echo "==> Generate Xcode project"
(
    cd "$IOS_DIR"
    xcodegen generate
)
check_package_lock

echo "==> Run app-layer tests on iOS Simulator"
xcodebuild \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Debug \
    -destination "$SIMULATOR_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -resultBundlePath "$RESULTS_DIR/AppTests.xcresult" \
    -enableCodeCoverage YES \
    -onlyUsePackageVersionsFromResolvedFile \
    CODE_SIGNING_ALLOWED=NO \
    test
check_package_lock

xcrun xccov view --report --json "$RESULTS_DIR/AppTests.xcresult" > "$RESULTS_DIR/app-coverage.json"
xcrun xccov view --report "$RESULTS_DIR/AppTests.xcresult" > "$RESULTS_DIR/app-coverage.txt"

BUILT_PRIVACY_MANIFEST="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LinePay.app/PrivacyInfo.xcprivacy"
if [[ ! -f "$BUILT_PRIVACY_MANIFEST" ]]; then
    echo "error: PrivacyInfo.xcprivacy was not bundled into LinePay.app" >&2
    exit 1
fi

# Without a launch screen, iOS can run the app in a 320 x 480 compatibility viewport.
BUILT_INFO_PLIST="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LinePay.app/Info.plist"
plutil -extract UILaunchScreen xml1 -o /dev/null "$BUILT_INFO_PLIST"

echo "==> Build Release for generic iOS Simulator"
xcodebuild \
    -project "$IOS_DIR/LinePay.xcodeproj" \
    -scheme LinePay \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA" \
    -onlyUsePackageVersionsFromResolvedFile \
    CODE_SIGNING_ALLOWED=NO \
    build
check_package_lock

echo "==> Xcode dependency lockfile preserved"
plutil -extract UILaunchScreen xml1 -o /dev/null \
    "$DERIVED_DATA/Build/Products/Release-iphonesimulator/LinePay.app/Info.plist"
