#!/usr/bin/env python3
"""One-time, docs-only reorganization. Refuses to overwrite unrelated destinations."""
from __future__ import annotations

import json
import posixpath
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
MOVES = {
    'docs/pricing.md': 'docs/product/pricing.md',
    'docs/onboarding.md': 'docs/product/onboarding.md',
    'docs/best-practices.md': 'docs/engineering/ios-best-practices.md',
    'docs/agentic.md': 'docs/engineering/agentic-development.md',
    'docs/testing.md': 'docs/testing/README.md',
    'docs/maestro.md': 'docs/testing/maestro.md',
    'docs/linepay-1.0-readiness-audit.md': 'docs/testing/audits/linepay-1.0-readiness-audit.md',
    'docs/checklists/ios-1.0-manual-qa.md': 'docs/testing/checklists/ios-1.0-manual-qa.md',
    'docs/checklists/ios-before-first-testflight.md': 'docs/release/checklists/ios-before-first-testflight.md',
    'docs/appstore.md': 'docs/release/app-store.md',
    'docs/release-and-testflight-api.md': 'docs/release/api-and-testflight.md',
    'docs/release-build-2-2026-09-05.md': 'docs/release/evidence/release-build-2-2026-09-05.md',
    'docs/marketing.md': 'docs/growth/marketing.md',
}
HISTORICAL = {
    'docs/linepay-1.0-readiness-audit.md',
    'docs/release-build-2-2026-09-05.md',
    'docs/plan/implementation-status.md',
}
LINK = re.compile(r'(!?\[[^\]\n]*\]\(\s*)(<[^>]+>|[^\s)]+)')
CODE = re.compile(r'`([^`\n]+)`')


def mapped(path: str) -> str:
    return MOVES.get(path, path)


def resolve(old: str, target: str) -> str | None:
    target = unquote(target)
    candidates = [posixpath.normpath(posixpath.join(posixpath.dirname(old), target))]
    if target.startswith('docs/'):
        candidates.insert(0, target)
    elif target in ('AGENTS.md', 'DESIGN.md', 'README.md'):
        candidates.append(target)
    for candidate in candidates:
        if (ROOT / candidate).exists() or candidate in MOVES:
            return candidate
    return None


def rewrite(body: str, old: str, new: str) -> str:
    def link(match: re.Match[str]) -> str:
        target = match.group(2)
        wrap = target.startswith('<')
        raw = target.strip('<>')
        parts = urlsplit(raw)
        if parts.scheme or parts.netloc or not parts.path:
            return match.group(0)
        resolved = resolve(old, parts.path)
        if resolved is None:
            return match.group(0)
        changed = posixpath.relpath(mapped(resolved), posixpath.dirname(new) or '.')
        if parts.query:
            changed += '?' + parts.query
        if parts.fragment:
            changed += '#' + parts.fragment
        return match.group(1) + ('<' + changed + '>' if wrap else changed)

    body = LINK.sub(link, body)
    segments = re.split(r'(https?://[^\s<>`\)]+)', body)
    for index in range(0, len(segments), 2):
        text = segments[index]
        for before, after in sorted(MOVES.items(), key=lambda pair: -len(pair[0])):
            text = re.sub(r'(?<![\w/.:\-])' + re.escape(before) + r'(?![\w.\-])', after, text)
        segments[index] = text
    body = ''.join(segments)

    def code(match: re.Match[str]) -> str:
        value = match.group(1)
        if not value.startswith('../') or not value.endswith('.md'):
            return match.group(0)
        resolved = resolve(old, value)
        if resolved:
            return '`' + posixpath.relpath(mapped(resolved), posixpath.dirname(new) or '.') + '`'
        return match.group(0)
    return CODE.sub(code, body)


def put(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')


def main() -> None:
    evidence = ROOT / 'docs/qa'
    if evidence.exists():
        for item in evidence.rglob('*'):
            if item.is_file():
                old = item.relative_to(ROOT).as_posix()
                MOVES[old] = old.replace('docs/qa/', 'docs/testing/evidence/', 1)
    originals = {}
    for path in ROOT.rglob('*.md'):
        relative = path.relative_to(ROOT).as_posix()
        if any(part in {'.git', '.build', 'node_modules', '.test-results'} for part in path.parts):
            continue
        originals[relative] = path.read_text(encoding='utf-8')
    for before, after in MOVES.items():
        source, dest = ROOT / before, ROOT / after
        if not source.exists():
            continue
        if dest.exists():
            assert before == 'docs/pricing.md' and 'moved to' in dest.read_text().lower() \
                and 'docs/pricing.md' in dest.read_text(), f'Destination already contains content: {after}'
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(source.read_bytes())
        source.unlink()

    for old, body in originals.items():
        if old == 'docs/product/pricing.md':
            continue
        new = mapped(old)
        if old in HISTORICAL:
            continue
        updated = rewrite(body, old, new)
        if updated != body:
            put(new, updated)

    for before, after in MOVES.items():
        if not before.endswith('.md') or not (ROOT / after).exists():
            continue
        relative = posixpath.relpath(after, posixpath.dirname(before))
        put(before, '# Moved\n\nThe canonical document is [' + after + '](' + relative + ').\n\n'
            'This compatibility entry contains no independent requirements. Edit the canonical file.\n')

    indexes = {
        'docs/engineering/README.md': ('Engineering', [('iOS best practices', 'ios-best-practices.md'), ('Agent development', 'agentic-development.md')]),
        'docs/architecture/README.md': ('Architecture', [('Local-first, no account', 'local-first-no-account.md'), ('Manual Files/iCloud backup and restore', 'icloud-drive-backup-restore.md'), ('Architecture decisions', '../adr/README.md')]),
        'docs/design/README.md': ('Design', [('Design system', '../../DESIGN.md'), ('Logo', 'logo.md'), ('App Store screenshot design', 'app-stores/screenshots.md'), ('Screen structures', '../plan/mockups.md')]),
        'docs/release/README.md': ('Release', [('App Store metadata', 'app-store.md'), ('API and TestFlight workflow', 'api-and-testflight.md'), ('Before first TestFlight', 'checklists/ios-before-first-testflight.md'), ('Build 2 historical evidence', 'evidence/release-build-2-2026-09-05.md')]),
        'docs/growth/README.md': ('Growth', [('Marketing strategy', 'marketing.md'), ('Pricing', '../product/pricing.md'), ('Onboarding', '../product/onboarding.md')]),
        'docs/plan/README.md': ('Plans and implementation evidence', [('1.0 release scope', 'ios-1.0.md'), ('Structural screen mockups', 'mockups.md'), ('Current remediation', 'ios-1.0-remediation.md'), ('Historical implementation report', 'implementation-status.md')]),
    }
    for path, (title, links) in indexes.items():
        if (ROOT / path).exists():
            continue
        content = '# ' + title + '\n\n[Documentation home](../README.md)\n\n'
        for label, destination in links:
            if (ROOT / path).parent.joinpath(destination).exists():
                content += f'- [{label}]({destination})\n'
        put(path, content)
    for folder, title in [('adr', 'Architecture decision records'), ('research', 'Dated research')]:
        path = 'docs/' + folder + '/README.md'
        if (ROOT / path).exists():
            continue
        content = '# ' + title + '\n\n[Documentation home](../README.md)\n\n'
        if folder == 'research':
            content += 'Research notes are scoped and dated, not a current implementation or legal-coverage certificate. See the [payroll source register](../product/payroll/sources.md).\n\n'
        for child in sorted((ROOT / 'docs' / folder).glob('*.md')):
            if child.name != 'README.md':
                content += f'- [{child.stem}]({child.name})\n'
        put(path, content)

    guide = ROOT / 'docs/testing/README.md'
    if guide.exists():
        content = guide.read_text()
        navigation = '\n\n## Documentation navigation\n\n[Documentation home](../README.md) · [Maestro](maestro.md) · [Manual QA](checklists/ios-1.0-manual-qa.md) · [Historical audit](audits/linepay-1.0-readiness-audit.md) · [Payroll acceptance cases](../product/payroll/worked-examples.md)\n'
        put('docs/testing/README.md', content + navigation)
    else:
        put('docs/testing/README.md', '# Testing\n\n[Documentation home](../README.md) · [Maestro](maestro.md) · [Manual QA](checklists/ios-1.0-manual-qa.md)\n')

    agents = (ROOT / 'AGENTS.md').read_text()
    insert = ('| Product behavior / business rules | [Product handbook](docs/product/README.md), [business rules](docs/product/business-rules.md) |\n'
              '| Payroll applicability / legal scope | [Legal baseline](docs/product/payroll/us-legal-baseline.md), [coverage](docs/product/payroll/coverage-and-gaps.md), [sources](docs/product/payroll/sources.md) |\n'
              '| Documentation changes | [Documentation map](docs/README.md), [docs agent contract](docs/AGENTS.md) |\n')
    agents = agents.replace('| Work | Read / use |\n|---|---|\n', '| Work | Read / use |\n|---|---|\n' + insert)
    anchor = '## Architecture boundary\n'
    addition = ('## Payroll coverage and product craft\n\n'
                'Use the product handbook before changing a pay number or verdict. A configured-rules estimate is not automatically a complete US legal-pay audit. Federal weekly overtime, regular-rate treatment, jurisdiction and agreement applicability are independent obligations; unconfigured is not waived. Preserve explicit unsupported coverage and never fabricate professional or union verification.\n\n'
                'Make LinePaycheck exceptionally clear, fast, reliable, and recoverable. Apply Pareto efficiency to complexity, not to correctness, privacy, evidence, migration safety, or accessibility. Spend disproportionate craft on the few interactions that earn worker trust.\n\n')
    assert anchor in agents
    agents = agents.replace(anchor, addition + anchor)
    assert len(agents.encode()) < 12000, 'Root agent contract exceeded harness size budget'
    put('AGENTS.md', agents)
    for file in ['.agents/skills/payroll-domain/SKILL.md',
                 'apps/ios/Packages/LinePayDomain/AGENTS.md',
                 '.github/instructions/domain.instructions.md']:
        target = ROOT / file
        if target.exists():
            prefix = posixpath.relpath('docs/product/payroll', posixpath.dirname(file))
            put(file, target.read_text() + '\n## Product rule references\n\n'
                f'Read the [payroll contract]({prefix}/README.md), [coverage limits]({prefix}/coverage-and-gaps.md), '
                f'and [source approval]({prefix}/sources.md) before changing wage or audit behavior. '
                'A configured daily premium is not a complete federal weekly-overtime implementation. '
                'Link relevant business-rule/example IDs in regressions; preserve scoped conclusions.\n')
    root_readme = (ROOT / 'README.md').read_text()
    if '(docs/README.md)' not in root_readme:
        put('README.md', root_readme + '\n## Product and documentation\n\n[Documentation map](docs/README.md) · [Business rules](docs/product/business-rules.md) · [Payroll handbook](docs/product/payroll/README.md)\n')

    harness = ROOT / 'scripts/check-agent-harness.sh'
    if harness.exists():
        put('scripts/check-agent-harness.sh', harness.read_text().replace('docs/agentic.md', 'docs/engineering/agentic-development.md'))
    workflow = ROOT / '.github/workflows/agent-harness.yml'
    if workflow.exists():
        put('.github/workflows/agent-harness.yml', workflow.read_text().replace('docs/agentic.md', 'docs/engineering/agentic-development.md'))
    put('docs/_tools/path-migrations.json', json.dumps(MOVES, indent=2) + '\n')
    print('Canonical paths migrated:', len(MOVES))
    print('Application Swift/Kotlin sources were not modified.')


if __name__ == '__main__':
    main()
