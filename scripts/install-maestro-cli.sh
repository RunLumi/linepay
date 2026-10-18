#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="2.11.0"
EXPECTED_SHA256="5384593cb4e7a106489e75a821d157dd43f4e438df6bc308b72e82c685e1283a"
ARCHIVE="$ROOT/.build/tools/maestro-$VERSION.zip"
INSTALL_ROOT="$ROOT/.build/tools/maestro-$VERSION"
MAESTRO_BIN="$INSTALL_ROOT/maestro/bin/maestro"

mkdir -p "$ROOT/.build/tools"
if [[ ! -f "$ARCHIVE" ]]; then
    curl -fL --retry 3 --connect-timeout 30 --max-time 900 \
        "https://github.com/mobile-dev-inc/Maestro/releases/download/cli-$VERSION/maestro.zip" \
        -o "$ARCHIVE"
fi

python3 - "$ARCHIVE" "$EXPECTED_SHA256" <<'PY'
from hashlib import sha256
import sys

path = sys.argv[1]
expected = sys.argv[2]
digest = sha256()
with open(path, "rb") as archive:
    for block in iter(lambda: archive.read(1024 * 1024), b""):
        digest.update(block)
actual = digest.hexdigest()
if actual != expected:
    raise SystemExit(f"error: Maestro archive digest mismatch: {actual}")
print(f"Maestro archive SHA-256 verified: {actual}")
PY

if [[ ! -x "$MAESTRO_BIN" ]]; then
    mkdir -p "$INSTALL_ROOT"
    unzip -q -o "$ARCHIVE" -d "$INSTALL_ROOT"
fi
if [[ ! -x "$MAESTRO_BIN" ]]; then
    echo "error: Maestro binary was not found in the verified archive" >&2
    exit 1
fi

if [[ -n "${JAVA_HOME:-}" && ! -x "$JAVA_HOME/bin/java" ]]; then
    echo "error: JAVA_HOME does not point to an installed JDK" >&2
    exit 1
fi
if [[ -z "${JAVA_HOME:-}" ]] && ! command -v java >/dev/null 2>&1; then
    echo "error: Java 17 or newer is required to run Maestro" >&2
    exit 1
fi
mkdir -p "$ROOT/.build/maestro-home"
MAESTRO_CLI_NO_ANALYTICS=1 \
MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true \
MAESTRO_OPTS="${MAESTRO_OPTS:-} -Duser.home=$ROOT/.build/maestro-home" \
JAVA_HOME="${JAVA_HOME:-}" \
"$MAESTRO_BIN" --version
