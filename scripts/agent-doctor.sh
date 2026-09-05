#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_PROJECT="$ROOT/apps/ios/project.yml"
GENERATED_XCODE_PROJECT="$ROOT/apps/ios/LinePay.xcodeproj"
PRIVACY_MANIFEST="$ROOT/apps/ios/App/Resources/PrivacyInfo.xcprivacy"
EXPECTED_XCODEGEN_VERSION="2.46.0"

failures=0
warnings=0

ok() {
    printf 'ok: %s\n' "$1"
}

warn() {
    printf 'warning: %s\n' "$1" >&2
    warnings=$((warnings + 1))
}

fail() {
    printf 'error: %s\n' "$1" >&2
    failures=$((failures + 1))
}

require_command() {
    local command_name="$1"
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name is available"
    else
        fail "$command_name is required"
    fi
}

optional_command() {
    local command_name="$1"
    local purpose="$2"
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name is available ($purpose)"
    else
        warn "$command_name is optional and missing ($purpose)"
    fi
}

cd "$ROOT"

echo "==> Agent harness integrity"
if bash "$ROOT/scripts/check-agent-harness.sh"; then
    ok "agent harness contract is internally consistent"
else
    fail "agent harness validation failed"
fi

echo
echo "==> Required local toolchain"
require_command git
require_command xcodebuild
require_command swift
require_command xcodegen

if command -v xcodegen >/dev/null 2>&1; then
    version="$(xcodegen --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
    if [[ "$version" == "$EXPECTED_XCODEGEN_VERSION" ]]; then
        ok "XcodeGen version is $EXPECTED_XCODEGEN_VERSION"
    else
        fail "expected XcodeGen $EXPECTED_XCODEGEN_VERSION, found ${version:-unknown}"
    fi
fi

echo
echo "==> Optional mobile-agent tools"
optional_command maestro "checked-in E2E flows"
optional_command xcodebuildmcp "interactive simulator/build/debug/UI agent loop"

if [[ -d "$GENERATED_XCODE_PROJECT" ]]; then
    ok "generated LinePay.xcodeproj is available for direct Xcode/MCP use"
else
    warn "generated LinePay.xcodeproj is absent; run 'bash scripts/bootstrap-ios.sh' before direct XcodeBuildMCP/Xcode use"
fi

echo
echo "==> Repository contracts"
for path in \
    AGENTS.md \
    apps/ios/AGENTS.md \
    DESIGN.md \
    docs/best-practices.md \
    docs/agentic.md \
    docs/plan/ios-1.0.md \
    docs/maestro.md; do
    if [[ -f "$ROOT/$path" ]]; then
        ok "$path"
    else
        fail "missing $path"
    fi
done

if grep -q 'PRODUCT_BUNDLE_IDENTIFIER: com.streamentry.linepay' "$IOS_PROJECT"; then
    ok "canonical bundle ID is com.streamentry.linepay"
else
    fail "apps/ios/project.yml must keep PRODUCT_BUNDLE_IDENTIFIER com.streamentry.linepay"
fi

if grep -q 'INFOPLIST_KEY_CFBundleDisplayName: LinePaycheck' "$IOS_PROJECT"; then
    ok "public iOS display name is LinePaycheck"
else
    fail "apps/ios/project.yml must expose LinePaycheck as the display name"
fi

if [[ -f "$PRIVACY_MANIFEST" ]]; then
    if plutil -lint "$PRIVACY_MANIFEST" >/dev/null; then
        ok "PrivacyInfo.xcprivacy is valid"
    else
        fail "PrivacyInfo.xcprivacy failed plutil validation"
    fi
fi

if [[ -f "$ROOT/.xcodebuildmcp/config.yaml" ]]; then
    if grep -q "bundleId: 'com.streamentry.linepay'" "$ROOT/.xcodebuildmcp/config.yaml"; then
        ok "XcodeBuildMCP bundle default matches canonical bundle ID"
    else
        fail ".xcodebuildmcp/config.yaml bundleId drifted from com.streamentry.linepay"
    fi
fi

echo
if (( failures > 0 )); then
    echo "Agent doctor found $failures blocking issue(s) and $warnings optional warning(s)." >&2
    exit 1
fi

echo "Agent doctor passed with $warnings optional warning(s)."
