#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: Xcode command line tools are required" >&2
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: XcodeGen >= 2.46.0 is required.
Install it with: brew install xcodegen
EOF
    exit 1
fi

echo "Using:"
xcodebuild -version
xcodegen --version

cd "$IOS_DIR"
xcodegen generate

echo "Generated $IOS_DIR/LinePay.xcodeproj"
