#!/usr/bin/env bash
set -euo pipefail
# Standard Hugo is sufficient: no Sass, Node, theme submodule, or Go modules.
VERSION=0.165.0
SHA256=5c3a37a5450b3e386e5b75a87a790fea2d04a796d75e171216c80ef48a32b432
PREFIX="${HUGO_INSTALL_DIR:-$HOME/.local/bin}"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "Install Hugo $VERSION for your platform from https://gohugo.io/installation/" >&2
  exit 1
fi
command -v curl >/dev/null
command -v sha256sum >/dev/null
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl --fail --location --retry 2 --output "$TMP/hugo.tar.gz" \
  "https://github.com/gohugoio/hugo/releases/download/v$VERSION/hugo_${VERSION}_linux-amd64.tar.gz"
printf '%s  %s\n' "$SHA256" "$TMP/hugo.tar.gz" | sha256sum --check --status
tar -xzf "$TMP/hugo.tar.gz" -C "$TMP" hugo
mkdir -p "$PREFIX"
install -m 0755 "$TMP/hugo" "$PREFIX/hugo"
"$PREFIX/hugo" version
