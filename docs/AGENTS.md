# Documentation contributor contract

Follow the repository [agent contract](../AGENTS.md). Use [docs/README.md](README.md) to select the canonical owner for the change.

- Preserve the distinction between sourced law, a specific agreement, product requirements, observed implementation, synthetic examples, and unknown coverage. Never describe US lineman pay as one universal formula.
- Payroll changes need the [legal baseline](product/payroll/us-legal-baseline.md), [sources](product/payroll/sources.md), and [coverage matrix](product/payroll/coverage-and-gaps.md). User confirmation is not legal verification; a passing fixture is not complete agreement coverage.
- Keep source jurisdiction, edition/effective dates, exact provision and review status traceable. Do not invent counsel/union approval, sources, test results, or absence of amendments.
- Update the owning index and affected relative links. Redirects contain no business rules. Do not create another competing pricing, onboarding, design, or release specification.
- Keep original audit findings and historical commit links intact; record remediation separately with the actual tested revision. Do not rewrite a historical failure into a later success.
- Examples use synthetic records and independently checked arithmetic. Mark reference algorithms that are not implemented. No real paystub/worker data in documentation or fixtures.
- Spend detail on correctness boundaries and recurring user journeys, not redundant process. A doc-only change does not require an unrelated native rebuild; changed scripts or configuration still require appropriate verification.

Before handoff, run `python3 docs/_tools/check_links.py` and `python3 -m unittest discover -s docs/_tools -p 'test_*.py'`. State whether work is a specification change, implementation change, or new verification evidence.
