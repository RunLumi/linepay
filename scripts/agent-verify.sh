#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT/apps/ios"
DOMAIN_DIR="$IOS_DIR/Packages/LinePayDomain"
MODE="${1:-quick}"

run_quick() {
    echo "==> Test repository scripts"
    python3 -m unittest discover -s "$ROOT/scripts/tests" -v

    echo "==> Lint Swift"
    swift format lint \
        --strict \
        --recursive \
        --configuration "$ROOT/.swift-format" \
        "$IOS_DIR"

    echo "==> Test LinePayDomain"
    (
        cd "$DOMAIN_DIR"
        swift test --parallel
    )
}

case "$MODE" in
    quick)
        run_quick
        ;;
    ios)
        bash "$ROOT/scripts/check-ios.sh"
        ;;
    ui)
        bash "$ROOT/scripts/check-ios.sh"
        bash "$ROOT/scripts/test-ios-maestro.sh"
        ;;
    *)
        cat >&2 <<'EOF'
usage: bash scripts/agent-verify.sh [quick|ios|ui]

  quick  strict Swift formatting + pure LinePayDomain tests
  ios    full native iOS quality gate
  ui     native gate + local Maestro smoke suite
EOF
        exit 64
        ;;
esac
