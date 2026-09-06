#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v hugo >/dev/null || { echo 'Install Hugo 0.165.0; see README.md.' >&2; exit 1; }
hugo version | grep -Eq '^hugo v0\.165\.0([+ -]|$)' || { echo 'Expected Hugo 0.165.0.' >&2; exit 1; }
BASE="${GUIDE_BASE_URL:-https://streamentry.github.io/linepay/}"
if [[ "${CF_PAGES:-}" == 1 ]]; then
  if [[ "${CF_PAGES_BRANCH:-}" != "${GUIDE_PRODUCTION_BRANCH:-main}" ]]; then
    BASE="${CF_PAGES_URL:?Cloudflare preview URL is required}"
    export HUGO_PARAMS_NOINDEX=true
  elif [[ -z "${GUIDE_BASE_URL:-}" ]]; then
    echo 'Set GUIDE_BASE_URL to the stable production docs URL, not a per-build preview URL.' >&2
    exit 1
  fi
fi
# Production URLs are configuration, not executable shell fragments.
case "$BASE" in https://*|http://localhost*|http://127.0.0.1*) ;; *) echo 'Use an absolute HTTPS base URL.' >&2; exit 1 ;; esac
hugo --source "$ROOT" --destination "$ROOT/public" --baseURL "${BASE%/}/" --environment production --cleanDestinationDir --panicOnWarning
