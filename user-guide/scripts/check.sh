#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v hugo >/dev/null || { echo 'Install Hugo 0.165.0 first.' >&2; exit 1; }
hugo version | grep -Eq '^hugo v0\.165\.0([+ -]|$)' || { echo 'Expected Hugo 0.165.0.' >&2; exit 1; }
mkdir -p "$ROOT/.qa"
hugo --source "$ROOT" --destination "$ROOT/.qa/root" --baseURL https://guide.example.test/ --environment production --cleanDestinationDir --panicOnWarning
python3 "$ROOT/scripts/check-site.py" "$ROOT/.qa/root" https://guide.example.test/
hugo --source "$ROOT" --destination "$ROOT/.qa/project/linepay" --baseURL https://guide.example.test/linepay/ --environment production --cleanDestinationDir --panicOnWarning
python3 "$ROOT/scripts/check-site.py" "$ROOT/.qa/project/linepay" https://guide.example.test/linepay/
node "$ROOT/scripts/test-search.mjs"
