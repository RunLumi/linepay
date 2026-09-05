#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

cat <<'EOF'
LinePaycheck agent context
==========================
Public brand: LinePaycheck
Repository: streamentry/linepay
iOS bundle ID: com.streamentry.linepay
Internal Xcode scheme/target: LinePay
Domain package: LinePayDomain

Canonical context:
- AGENTS.md
- apps/ios/AGENTS.md for iOS work
- docs/best-practices.md for iOS engineering
- DESIGN.md for user-facing UI
- docs/plan/ios-1.0.md for current product scope
- docs/agentic.md for the agent harness
EOF

echo
echo "Git"
echo "---"
printf 'Branch: '
git branch --show-current 2>/dev/null || echo "unknown"
printf 'HEAD:   '
git rev-parse --short HEAD 2>/dev/null || echo "unknown"

echo
echo "Working tree"
echo "------------"
STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ -z "$STATUS" ]]; then
    echo "Clean working tree."
else
    printf '%s\n' "$STATUS"

    if ! git diff --quiet; then
        echo
        echo "Unstaged diff summary:"
        git diff --stat
    fi

    if ! git diff --cached --quiet; then
        echo
        echo "Staged diff summary:"
        git diff --cached --stat
    fi
fi

echo
echo "Toolchain"
echo "---------"
if command -v xcodebuild >/dev/null 2>&1; then
    xcodebuild -version | sed 's/^/  /'
else
    echo "  xcodebuild: missing"
fi

if command -v swift >/dev/null 2>&1; then
    swift --version | head -n 1 | sed 's/^/  /'
else
    echo "  swift: missing"
fi

if command -v xcodegen >/dev/null 2>&1; then
    printf '  xcodegen: '
    xcodegen --version
else
    echo "  xcodegen: missing"
fi

if command -v maestro >/dev/null 2>&1; then
    printf '  maestro: available ('
    maestro --version 2>/dev/null | head -n 1 | tr -d '\n' || true
    echo ')'
else
    echo "  maestro: optional / missing"
fi

if command -v xcodebuildmcp >/dev/null 2>&1; then
    echo "  xcodebuildmcp: optional / available"
else
    echo "  xcodebuildmcp: optional / missing"
fi

cat <<'EOF'

Verification
------------
  bash scripts/agent-verify.sh quick   # format + domain tests
  bash scripts/agent-verify.sh ios     # full native iOS gate
  bash scripts/agent-verify.sh ui      # native gate + Maestro smoke

Before editing, inspect the nearest existing implementation and tests. Do not overwrite unrelated working-tree changes, including untracked files.
EOF
