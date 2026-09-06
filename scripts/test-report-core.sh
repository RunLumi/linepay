#!/usr/bin/env bash
# Portable tests for the exact Foundation-only sharing implementation, not native iOS acceptance.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v swift >/dev/null 2>&1 || { echo "error: Swift 6.2+ is required" >&2; exit 1; }
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/linepay-report-core.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/Sources/ReportCore" "$SCRATCH/Tests/ReportCoreTests"
cat > "$SCRATCH/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "ReportCore",
    targets: [
        .target(name: "ReportCore"),
        .testTarget(name: "ReportCoreTests", dependencies: ["ReportCore"]),
    ]
)
SWIFT
for name in ReportShareSession TemporaryExports; do
    cp "$ROOT/apps/ios/App/Sources/$name.swift" "$SCRATCH/Sources/ReportCore/"
    cmp "$ROOT/apps/ios/App/Sources/$name.swift" "$SCRATCH/Sources/ReportCore/$name.swift"
done
# Only the test-module name changes; no substitute production implementation or assertions.
sed 's/^@testable import LinePay$/@testable import ReportCore/' \
    "$ROOT/apps/ios/AppTests/Sources/ReportShareSessionTests.swift" \
    > "$SCRATCH/Tests/ReportCoreTests/ReportShareSessionTests.swift"
echo '==> Sharing core only. PDFKit, SwiftUI, StoreKit and device acceptance are NOT covered.'
swift --version
swift test --package-path "$SCRATCH"
