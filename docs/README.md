# Documentation map

[Repository home](../README.md) · [Agent contract](../AGENTS.md) · [Product handbook](product/README.md)

Start with the product handbook for behavior, not a historical implementation report. Read the smallest relevant set below. A document can specify a feature without proving that it is implemented, tested, or released.

## Canonical ownership

| Topic | Canonical home |
|---|---|
| Product purpose, workflows and business rules | [Product](product/README.md) |
| Pay calculation, applicability, source approval and coverage limits | [Payroll](product/payroll/README.md) |
| Price, tier, eligibility and activation policy | [Pricing](product/pricing.md), [onboarding](product/onboarding.md) |
| iOS release scope and structural screens | [1.0 plan](plan/ios-1.0.md), [mockups](plan/mockups.md) |
| What has actually been verified | [Remediation](plan/ios-1.0-remediation.md), [testing](testing/README.md), commit-specific evidence |
| Visual and interaction system | [DESIGN.md](../DESIGN.md), [design assets](design/README.md) |
| Storage/privacy boundaries and architectural decisions | [Architecture](architecture/README.md), [ADRs](adr/README.md) |
| Engineering and agent execution | [Engineering](engineering/README.md) |
| Tests, manual gates, and audit history | [Testing](testing/README.md), [original readiness audit](testing/audits/linepay-1.0-readiness-audit.md) |
| Legal risk, publisher obligations, and compliance review | [Legal](legal/README.md) |
| Distribution, store metadata and release evidence | [Release](release/README.md) |
| Positioning and acquisition | [Growth](growth/README.md) |
| Dated external research | [Research](research/README.md) |

## Structure

```text
docs/
  product/       Business rules, workflows, pricing, onboarding, payroll handbook
  architecture/  Data-flow and storage policies
  adr/           Stable numbered architecture decisions
  engineering/   iOS practice and agent-development guidance
  testing/       Test guide, Maestro, checklists, audits, evidence
  design/        Logo and store-screenshot design; root DESIGN.md stays authoritative
  plan/          Release scope, mockups, implementation and remediation records
  legal/         Legal-risk register and compliance review
  release/       Store metadata, API/TestFlight procedures, checklists and evidence
  growth/        Marketing strategy
  research/      Dated research and source notes
  _tools/        Documentation link checks
```

Root `AGENTS.md` and `DESIGN.md`, numbered ADR paths, and current `docs/plan/` paths remain stable to minimize disruption to active work. Compatibility files at former flat paths contain redirects only, not competing specifications. Follow their canonical destination when editing.

## Evidence and conflict policy

An external source defines a rule only within its applicable scope. A product requirement is not a legal entitlement; a source file is not proof of successful execution; a historical test run is not evidence for a newer commit. [Product evidence labels](product/README.md) and [coverage gates](product/payroll/coverage-and-gaps.md) make these distinctions explicit.

Pricing owns commercial policy; the release plan owns scope; the product/payroll handbook owns business semantics; design owns presentation; ADRs own architecture. The legal-risk register owns its scoped assessment of business and release risks, not a blanket override of those documents. Resolve conflicts with a dated decision and affected references rather than silently allowing multiple sources of truth.

**Important:** current pricing includes the eligible annual introductory trial as well as separate first-audit sampling. Historical “no calendar trial” proposals are not current policy. Current payroll configuration is not automatically a complete US legal-pay check.

## Maintenance

Use relative links for current repository documentation and commit-pinned links for historical implementation evidence. Keep historical audit assertions and original source locators unchanged. New files need an owning index and links back to related rules. Run:

```bash
python3 docs/_tools/check_links.py
python3 -m unittest discover -s docs/_tools -p 'test_*.py'
```

External legal links need source review, not merely an HTTP-success check. These commands check local documentation links; they do not certify the law or the app.
