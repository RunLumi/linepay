# Native accessibility release checks

[Testing](README.md) · [Design contract](../../DESIGN.md)

The release gate combines rendered-size assertions, reachable complete controls, visible contrast
and Apple's semantic audit. These are engineering checks, not VoiceOver/device acceptance or a
claim that every screen meets an App Store accessibility label.

## Required checks

- `DynamicTypeCoverageJourneyTests` launches the actual app at all 12 system text sizes. It compares
  rendered work/status/action/text frames with independent UIKit font metrics, retains the full
  labels, and measures the combined work row using its headline, time and note styles. The long
  activity paragraph can scroll; it must retain its complete intrinsic height.
- Its largest-text Settings journey scrolls each of 18 actions completely inside the navigation/
  tab-bar viewport and checks its text bounds. Existing normal/dark largest-text pay, consent,
  evidence and recovery journeys remain required.
- `testContrastOnFreshWorkerScreens` runs Apple's contrast audit on the existing iOS 26 simulator.
  It checks Today, Settings, the backup action after scrolling it fully into view, and local activity.
  Reports for mapped text overlapping a system bar are retained and classified as outside the
  readable viewport. Unmapped reports and reports wholly within the viewport still fail.
- `testWorkerScreensPassSemanticAccessibilityAudit` retains Apple's other checks for descriptions,
  traits, hit regions and element detection. Source color tests verify all existing light/dark/
  high-contrast pairs; supporting/action text additionally requires 7:1 on the darkest light neutral.

The iOS 18 contrast auditor returns reports without an associated SwiftUI element, so that contrast
journey explicitly skips there. The current-runtime CI job runs it on iOS 26; the minimum-runtime
suite still runs all text-size, layout, semantic, application and domain tests. A missing current
runtime is a missing gate, not a reason to turn the contrast test into an empty pass.

## Raw heuristic diagnostic

Pass `TEST_RUNNER_LINEPAY_RAW_APPLE_AUDIT=1` to `xcodebuild` to set the test runner's environment and run
`testUnfilteredAppleAuditDiagnostic`. It calls Apple's unfiltered `.all` audit and retains every
reported issue, hierarchy and screenshot. It is intentionally opt-in rather than a substitute for
the independent checks above. A default skipped diagnostic is not reported as a passing raw audit.

On October 23, Xcode 27.1/iOS 18.5 reported partial Dynamic Type support for labels that passed all
12 rendered-size cases, including the largest category. The work row grew to 395 pt and the long
activity text to 1,201 pt without falling below the expected text metrics. iOS 26 also reported
contrast for text outside the reading viewport, including rows beneath the tab bar; scrolling the
backup action fully into view produced no visible contrast failure. Stronger colors and hard
vertical scroll edges still address actual legibility rather than hiding those observations.

Apple documents that audit reports require individual investigation and supports filtering false
positives ([WWDC23](https://developer.apple.com/videos/play/wwdc2023/10035/)). An Apple engineer also
acknowledged that incorrect Dynamic Type/clipping reports can be an Inspector bug when text
visibly grows without clipping ([developer forum](https://developer.apple.com/forums/thread/823968)).
That acknowledgement is context; the app's measured layouts and screenshots are the evidence here.

Do not add blanket audit-type or nil-element exemptions to make a candidate pass. A new clipping,
small-text or visible-contrast defect must fail the corresponding concrete regression. Preserve
raw diagnostic findings and never turn simulator checks into a claim of physical VoiceOver or
universal accessibility certification.
