#!/usr/bin/env bash
set -euo pipefail

VERSION="2.46.0"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
PREFIX="${XCODEGEN_PREFIX:-${HOME}/.local}"

for command in curl unzip install; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "error: $command is required to install XcodeGen" >&2
        exit 1
    fi
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/linepay-xcodegen.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

ZIP="$TMP/xcodegen.zip"

echo "==> Download XcodeGen ${VERSION}"
curl --fail --location --silent --show-error --retry 3 --output "$ZIP" "$URL"

echo "==> Verify XcodeGen archive"
if command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "$SHA256" "$ZIP" | shasum -a 256 -c -
elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$SHA256" "$ZIP" | sha256sum -c -
else
    echo "error: shasum or sha256sum is required to verify XcodeGen" >&2
    exit 1
fi

unzip -q "$ZIP" -d "$TMP/unpacked"
ARCHIVE_ROOT="$TMP/unpacked/xcodegen"
BIN="$ARCHIVE_ROOT/bin/xcodegen"
PRESETS="$ARCHIVE_ROOT/share/xcodegen/SettingPresets"

# Do not trust ZIP permission metadata. The verified bytes are enough; install(1)
# establishes the executable mode at the destination.
[[ -f "$BIN" ]] || {
    echo "error: verified XcodeGen archive did not contain bin/xcodegen" >&2
    exit 1
}
[[ -d "$PRESETS" ]] || {
    echo "error: verified XcodeGen archive did not contain SettingPresets" >&2
    exit 1
}

mkdir -p "$PREFIX/bin" "$PREFIX/share/xcodegen"
install -m 0755 "$BIN" "$PREFIX/bin/xcodegen"
rm -rf "$PREFIX/share/xcodegen/SettingPresets"
cp -R "$PRESETS" "$PREFIX/share/xcodegen/SettingPresets"

echo "Installed XcodeGen $VERSION to $PREFIX/bin/xcodegen"
"$PREFIX/bin/xcodegen" --version
