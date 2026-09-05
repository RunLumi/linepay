#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
EXPECTED_XCODEGEN_VERSION="2.46.0"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: Xcode command line tools are required" >&2
    exit 1
fi

install_hint() {
    cat >&2 <<'EOF'
Install the repository-pinned XcodeGen build with:

  XCODEGEN_PREFIX="$HOME/.local" bash scripts/install-xcodegen.sh
  export PATH="$HOME/.local/bin:$PATH"

The installer verifies the official 2.46.0 release archive by SHA-256 before installing it.
EOF
}

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: XcodeGen $EXPECTED_XCODEGEN_VERSION is required" >&2
    install_hint
    exit 1
fi

XCODEGEN_VERSION="$(xcodegen --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
if [[ "$XCODEGEN_VERSION" != "$EXPECTED_XCODEGEN_VERSION" ]]; then
    echo "error: expected XcodeGen $EXPECTED_XCODEGEN_VERSION, found ${XCODEGEN_VERSION:-unknown}" >&2
    install_hint
    exit 1
fi

echo "Using:"
xcodebuild -version
xcodegen --version

cd "$IOS_DIR"
xcodegen generate

echo "Generated $IOS_DIR/LinePay.xcodeproj"
