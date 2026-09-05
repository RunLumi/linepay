#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
    echo "error: $1" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || fail "missing required harness file: $1"
}

require_text() {
    local file="$1"
    local text="$2"
    grep -Fq -- "$text" "$file" || fail "$file is missing required text: $text"
}

echo "==> Shell syntax"
for script in scripts/*.sh; do
    bash -n "$script"
done

echo "==> Required harness files"
for file in \
    AGENTS.md \
    docs/agentic.md \
    .github/copilot-instructions.md \
    .github/instructions/ios.instructions.md \
    .github/instructions/domain.instructions.md \
    .github/instructions/maestro.instructions.md \
    .agents/skills/ios-feature/SKILL.md \
    .agents/skills/payroll-domain/SKILL.md \
    .agents/skills/mobile-ui-qa/SKILL.md \
    .agents/skills/release-readiness/SKILL.md \
    .xcodebuildmcp/config.yaml \
    scripts/agent-context.sh \
    scripts/agent-doctor.sh \
    scripts/agent-verify.sh; do
    require_file "$file"
done

echo "==> Product identity invariants"
require_text apps/ios/project.yml "PRODUCT_BUNDLE_IDENTIFIER: com.streamentry.linepay"
require_text apps/ios/project.yml "INFOPLIST_KEY_CFBundleDisplayName: LinePaycheck"
require_text .xcodebuildmcp/config.yaml "bundleId: 'com.streamentry.linepay'"
require_text .xcodebuildmcp/config.yaml "scheme: 'LinePay'"

if grep -Eq 'PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]+com\.streamentry\.linepaycheck' apps/ios/project.yml; then
    fail "bundle ID was incorrectly renamed to the public brand"
fi

echo "==> Agent Skill metadata"
for skill in .agents/skills/*/SKILL.md; do
    first_line="$(head -n 1 "$skill")"
    [[ "$first_line" == "---" ]] || fail "$skill must start with YAML frontmatter"

    awk '
        NR == 1 { next }
        /^---$/ { exit }
        /^name:[[:space:]]+[^[:space:]]/ { name = 1 }
        /^description:[[:space:]]+[^[:space:]]/ { description = 1 }
        END { exit !(name && description) }
    ' "$skill" || fail "$skill requires name and description frontmatter"
done

echo "==> Path-specific instruction metadata"
for instruction in .github/instructions/*.instructions.md; do
    first_line="$(head -n 1 "$instruction")"
    [[ "$first_line" == "---" ]] || fail "$instruction must start with YAML frontmatter"

    awk '
        NR == 1 { next }
        /^---$/ { exit }
        /^applyTo:[[:space:]]+.+/ { apply_to = 1 }
        END { exit !apply_to }
    ' "$instruction" || fail "$instruction requires applyTo frontmatter"
done

echo "==> Verification commands are discoverable"
require_text AGENTS.md "bash scripts/agent-verify.sh quick"
require_text AGENTS.md "bash scripts/agent-verify.sh ios"
require_text AGENTS.md "bash scripts/agent-verify.sh ui"
require_text docs/agentic.md "bash scripts/agent-doctor.sh"

echo "Agent harness checks passed."
