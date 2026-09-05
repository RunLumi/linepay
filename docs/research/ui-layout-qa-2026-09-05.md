# Adaptive iPhone layout and Maestro QA

Date: 2026-09-05. Baseline: `a802eab`. The shared checkout advanced to `1206fa2` during verification, incorporating this UI work and concurrent logo changes; final checks target that checkout.

## Root cause and fix

The initial iPhone 17 Pro run rendered LinePaycheck in a 320 x 480-point compatibility viewport on a 402 x 874-point screen. The built Info.plist had no launch-screen declaration. This produced black bands and an accessibility hierarchy that could not expose the welcome action correctly.

`project.yml` now generates the launch screen and scene manifest and declares portrait and both landscape orientations. The same simulator then reported a full 402 x 874-point app window. The native gate checks for `UILaunchScreen` in both Debug and Release build products.

## Interaction changes

- Welcome and Pro actions fill their available width, grow with text, and reserve bottom safe-area space.
- Money comparisons and ledger rows stack when two columns cannot fit. Exact values, currency, signs, and cents remain visible.
- Pay-profile and paycheck inputs retain their labels after typing. The entire labeled field can receive focus on iOS 18; each field has a distinct focus target.
- Decimal keyboards and work notes have a native Done action. Forms can scroll while the keyboard is visible.
- Failed pay-rule, work, and paycheck saves show an alert immediately and retain the draft. Editing sheets require explicit Cancel or Save instead of losing drafts to a swipe.
- Work type keeps one-tap segmented selection at standard text sizes and uses a native menu at accessibility sizes.
- Today’s paycheck row opens Pay directly. Settings actions have full-width touch areas.
- Action foreground/fill colors are distinct, including dark-mode button labels. Status text and symbols use the design system’s semantic colors. Increased contrast and reduced motion are supported.
- Pro shows unavailable prices explicitly when StoreKit has not returned a product. Its dismissal action and billing terms remain reachable.

## Numeric-entry regression found during keyboard QA

Foundation’s permissive parser read `58,40` as `58`, `58.40abc` as `58.4`, and `1,234.56` as `1` with the previous POSIX parsing call.

Entry now accepts one complete nonnegative decimal token with either `.` or `,` as the decimal separator, with leading/trailing whitespace allowed. Mixed or repeated separators, exponents, and trailing text are rejected. A single separator always means decimals; the forms explicitly instruct users to omit thousands grouping. Existing positivity/zero rules remain in effect.

App tests cover exact comma/point rates, malformed edits preserving the existing rule version/rate, exact paystub cents and optional hours, and malformed paystub edits preserving the confirmed record. Stored historical snapshots and payroll algorithms are unchanged.

## Verification

Toolchain: Xcode 26.6 / Swift 6.3.3 / XcodeGen 2.46.0 / Maestro CLI 2.6.1.

| Device and condition | Evidence |
|---|---|
| iPhone SE 3rd generation, iOS 18.5, 375 x 667 points, light | Full `agent-verify.sh ui` passed on `1206fa2`; all five Maestro flows passed in 3m 7s |
| iPhone 17 Pro, iOS 26.5, 402 x 874 points, dark + increased contrast + largest accessibility text | All five flows passed before the concurrent logo sync (6m 47s). The affected adaptive-layout and Pro journeys were then rebuilt and revalidated on `1206fa2`: 2/2 passed in 3m 40s |

The current-checkout native gate passed Swift formatting, 37 domain tests, app orchestration tests including numeric-entry regressions, the new logo-bundling test, privacy-manifest bundling, Release compilation, and the launch-screen checks.

Five independent Maestro journeys cover onboarding/validation/keyboard dismissal; add/edit/overlap recovery/delete/undo; manual paycheck confirmation/audit/archive/relaunch; Pro options/terms/dismissal; and long names/landscape keyboards/large negative monetary comparisons. Shared helpers reset only the dedicated QA simulators and use synthetic data.

Reproduce the full compact-device gate:

```bash
IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,name=LinePay UI QA Compact,arch=arm64' \
MAESTRO_IOS_DEVICE='LinePay UI QA Compact' \
bash scripts/agent-verify.sh ui
```

Local evidence:

- `.build/ui-qa-evidence/full-ui-gate.log`
- `.build/ui-qa-evidence/current-checkout-ui-gate.log`
- `.build/maestro-results/screenshots/`
- `.build/ui-qa-evidence/final-large-text.log`
- `.build/ui-qa-evidence/final-large-text/screenshots/`
- `.build/ui-qa-evidence/current-checkout-large-text.log`
- `.build/ui-qa-evidence/current-checkout-large-text/screenshots/`

Early failures were retained in other `.build/ui-qa-evidence/` directories for debugging; they are not final passing evidence. One concurrent run reported an app stop without a LinePay crash report; simulator logs showed XCTest accessibility errors. Subsequent independent passes completed successfully. The current-checkout log and affected-screen captures supersede the earlier artwork captures.

Visual inspection covered the new-logo welcome screen, normal and accessibility-sized work forms, decimal keyboards, landscape note entry, validation alerts, restored work, large negative comparisons, archived history, and the end of the Pro billing terms. The keyboard and bottom actions reserve visible space; long values reflow without removing their signs or cents.

This verifies the listed simulator journeys and inspected layouts. It does not claim physical-device camera/OCR testing, a real StoreKit purchase, VoiceOver certification, or lineworker usability-study results.
