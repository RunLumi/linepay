#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHECKOUT_SHA="3d3c42e5aac5ba805825da76410c181273ba90b1"
XCODEGEN_VERSION="2.46.0"
XCODEGEN_SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
MAX_ROOT_AGENTS_BYTES=12000
MAX_CLAUDE_LINES=200
MAX_SKILL_LINES=500

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

check_frontmatter() {
    local file="$1"
    shift

    [[ "$(head -n 1 "$file")" == "---" ]] || fail "$file must start with YAML frontmatter"

    for key in "$@"; do
        awk -v wanted="$key" '
            NR == 1 { next }
            /^---$/ { exit }
            index($0, wanted ":") == 1 { found = 1 }
            END { exit !found }
        ' "$file" || fail "$file requires $key frontmatter"
    done
}

command -v python3 >/dev/null 2>&1 || fail "python3 is required for harness config validation"

echo "==> Shell syntax"
for script in scripts/*.sh; do
    bash -n "$script"
done

echo "==> Required harness files"
for file in \
    AGENTS.md \
    CLAUDE.md \
    GEMINI.md \
    apps/ios/AGENTS.md \
    apps/ios/Packages/LinePayDomain/AGENTS.md \
    apps/android/AGENTS.md \
    shared/contracts/AGENTS.md \
    .maestro/AGENTS.md \
    docs/agentic.md \
    .mcp.json \
    .codex/config.toml \
    .gemini/settings.json \
    .github/copilot-instructions.md \
    .github/instructions/ios.instructions.md \
    .github/instructions/domain.instructions.md \
    .github/instructions/maestro.instructions.md \
    .github/agents/ios-engineer.agent.md \
    .github/agents/payroll-reviewer.agent.md \
    .github/agents/mobile-qa.agent.md \
    .github/agents/release-reviewer.agent.md \
    .claude/agents/ios-engineer.md \
    .claude/agents/payroll-reviewer.md \
    .claude/agents/mobile-qa.md \
    .claude/agents/release-reviewer.md \
    .github/pull_request_template.md \
    .github/ISSUE_TEMPLATE/agent-task.md \
    .agents/skills/ios-feature/SKILL.md \
    .agents/skills/payroll-domain/SKILL.md \
    .agents/skills/mobile-ui-qa/SKILL.md \
    .agents/skills/release-readiness/SKILL.md \
    .xcodebuildmcp/config.yaml \
    .github/workflows/agent-harness.yml \
    .github/workflows/ios.yml \
    scripts/agent-context.sh \
    scripts/agent-doctor.sh \
    scripts/agent-verify.sh \
    scripts/bootstrap-ios.sh \
    scripts/install-xcodegen.sh; do
    require_file "$file"
done

echo "==> Config syntax"
python3 -m json.tool .mcp.json >/dev/null
python3 -m json.tool .gemini/settings.json >/dev/null
python3 - <<'PY'
import tomllib

with open('.codex/config.toml', 'rb') as handle:
    tomllib.load(handle)
PY

echo "==> Instruction budgets"
root_agents_bytes="$(wc -c < AGENTS.md | tr -d ' ')"
(( root_agents_bytes <= MAX_ROOT_AGENTS_BYTES )) \
    || fail "AGENTS.md is ${root_agents_bytes} bytes; move focused guidance to skills/docs before exceeding ${MAX_ROOT_AGENTS_BYTES}"

claude_lines="$(wc -l < CLAUDE.md | tr -d ' ')"
(( claude_lines <= MAX_CLAUDE_LINES )) \
    || fail "CLAUDE.md is ${claude_lines} lines; keep compatibility context concise (max ${MAX_CLAUDE_LINES})"

for skill in .agents/skills/*/SKILL.md; do
    skill_lines="$(wc -l < "$skill" | tr -d ' ')"
    (( skill_lines <= MAX_SKILL_LINES )) \
        || fail "$skill is ${skill_lines} lines; split supporting detail/resources before exceeding ${MAX_SKILL_LINES}"
done

echo "==> Product identity invariants"
require_text apps/ios/project.yml "PRODUCT_BUNDLE_IDENTIFIER: com.streamentry.linepay"
require_text apps/ios/project.yml "INFOPLIST_KEY_CFBundleDisplayName: LinePaycheck"
require_text .xcodebuildmcp/config.yaml "bundleId: 'com.streamentry.linepay'"
require_text .xcodebuildmcp/config.yaml "scheme: 'LinePay'"
require_text CLAUDE.md "com.streamentry.linepay"
require_text GEMINI.md "com.streamentry.linepay"

if grep -Eq 'PRODUCT_BUNDLE_IDENTIFIER:[[:space:]]+com\.streamentry\.linepaycheck' apps/ios/project.yml; then
    fail "bundle ID was incorrectly renamed to the public brand"
fi

echo "==> Agent Skill metadata"
for skill in .agents/skills/*/SKILL.md; do
    check_frontmatter "$skill" name description
done

echo "==> Path-specific instruction metadata"
for instruction in .github/instructions/*.instructions.md; do
    check_frontmatter "$instruction" applyTo
done

echo "==> Custom agent metadata"
for agent in .github/agents/*.agent.md .claude/agents/*.md; do
    check_frontmatter "$agent" name description
done

echo "==> MCP commands"
require_text .mcp.json '"command": "xcodebuildmcp"'
require_text .mcp.json '"command": "maestro"'
require_text .codex/config.toml '[mcp_servers.xcodebuildmcp]'
require_text .codex/config.toml '[mcp_servers.maestro]'
require_text .gemini/settings.json '"xcodebuildmcp"'
require_text .gemini/settings.json '"maestro"'

echo "==> Pinned developer tools"
require_text scripts/install-xcodegen.sh "VERSION=\"$XCODEGEN_VERSION\""
require_text scripts/install-xcodegen.sh "SHA256=\"$XCODEGEN_SHA256\""
require_text .github/workflows/ios.yml "bash scripts/install-xcodegen.sh"
require_text scripts/bootstrap-ios.sh "EXPECTED_XCODEGEN_VERSION=\"$XCODEGEN_VERSION\""

echo "==> GitHub Actions supply-chain policy"
for workflow in .github/workflows/agent-harness.yml .github/workflows/ios.yml; do
    require_text "$workflow" "uses: actions/checkout@$CHECKOUT_SHA"
    require_text "$workflow" "persist-credentials: false"
done

if grep -R -En 'uses:[[:space:]]+actions/checkout@(v|main|master)' .github/workflows >/dev/null; then
    fail "actions/checkout must be pinned to the reviewed full commit SHA"
fi

echo "==> Verification commands are discoverable"
require_text AGENTS.md "bash scripts/agent-verify.sh quick"
require_text AGENTS.md "bash scripts/agent-verify.sh ios"
require_text AGENTS.md "bash scripts/agent-verify.sh ui"
require_text docs/agentic.md "bash scripts/agent-doctor.sh"

echo "Agent harness checks passed."
