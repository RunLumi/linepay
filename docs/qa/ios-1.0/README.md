# Synthetic iOS 1.0 review evidence

Native screenshot source: `4c15b53d830fd115e96fa429db302c592092f087`; the maximum-text picker capture uses the identical application source at `a6357a3d2658b13076227953ba078ccf4f0d7627`. The PDF was generated on `f78abbeecacf643bda80d50b2fe9766cde9e1fc8`; its report-generation source is unchanged in the newer candidate.

These captures contain synthetic records only. They are not customer paychecks, recovered wages, device verification, legal findings, or App Store approval.

- [ledger-light.png](ledger-light.png): actual recorded work and expected wages on iPhone 16 Pro / iOS 18.5 Simulator.
- [audit-needs-review.png](audit-needs-review.png): equal gross with offsetting confirmed component differences remains Needs review.
- [audit-dark-large.png](audit-dark-large.png): the same audit with dark appearance and the largest accessibility text size; the screen scrolls rather than shrinking text.
- [audit-choice-dark-large.png](audit-choice-dark-large.png): native gross-basis selection on iPhone SE / iOS 18.5 at the largest accessibility text size; the prompt and selected value wrap without truncation.
- [synthetic-audit.pdf](synthetic-audit.pdf): generated through the app's Prepare audit report action on iPhone SE / iOS 18.5 Simulator. Both pages were rendered and visually inspected. It preserves the gross basis, component differences, rule version and estimation boundary, and excludes original paystub pages.

Native result bundles, detailed logs and the full screenshot set remain under `.build/readiness/4c15b53/native-final/` (native) and `.build/readiness/f78abbe/` (PDF) in the shared workspace. The authoritative status, commands and external release gates are in [the remediation record](../../plan/ios-1.0-remediation.md).
