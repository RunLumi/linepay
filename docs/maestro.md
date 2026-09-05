# Build and Test LinePay Locally with Maestro

Status: **local iOS UI-testing workflow**  
Bundle ID: **`com.streamentry.linepay`**  
App baseline: **Xcode 26.6, Swift 6.3 compiler, iOS 18+**

This guide describes the supported local workflow for building the LinePay iOS app, installing it into an Xcode Simulator, and running black-box UI smoke tests with Maestro.

Maestro is used only for end-to-end user journeys. Payroll arithmetic belongs in `LinePayDomain` tests, and app orchestration belongs in Swift Testing. Do not move correctness testing into slow UI flows.

## 1. What Maestro tests in LinePay

Maestro drives the installed Simulator `.app` through the iOS Accessibility tree. It does not link into LinePay or require a test SDK inside the app.

Use Maestro for questions such as:

- can a fresh user complete onboarding?
- can a user enter pay rules and reach Today?
- can a user add/edit/delete work through the real UI?
- can a future user scan/confirm a paystub and reach reconciliation?
- does a critical journey still work after navigation/copy/layout changes?

Do **not** use Maestro to prove:

- overtime arithmetic;
- rounding rules;
- DST/timezone calculations;
- agreement rule precedence;
- reconciliation math.

Those belong in deterministic Swift tests.

## 2. Repository layout

```text
.maestro/
  config.yaml
  flows/
    onboarding-smoke.yaml

apps/ios/
  project.yml
  App/
  AppTests/
  Packages/LinePayDomain/

scripts/
  check-ios.sh
  test-ios-maestro.sh
```

The Maestro workspace uses the canonical iOS bundle ID:

```yaml
appId: com.streamentry.linepay
```

Test artifacts are written under:

```text
.build/maestro-results/
```

`.build/` is ignored by Git.

## 3. Prerequisites

You need:

- macOS;
- Xcode 26.6 with an iOS Simulator runtime;
- Xcode Command Line Tools selected;
- XcodeGen 2.46.0;
- Java 17 or newer;
- Maestro CLI.

Verify the Apple toolchain:

```bash
xcodebuild -version
swift --version
xcode-select -p
xcrun simctl list devices available
```

If Xcode was installed but the Simulator components have never been initialized, run:

```bash
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

### Install XcodeGen

```bash
brew install xcodegen
xcodegen --version
```

LinePay currently expects XcodeGen `2.46.0`. Keep `apps/ios/project.yml`, CI, and local scripts aligned when upgrading it.

### Install Java 17+

For example with Homebrew:

```bash
brew install --cask temurin@17
java -version
```

Ensure `JAVA_HOME` points to Java 17+ if your shell does not select it automatically.

### Install Maestro CLI

Official installer:

```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
```

Or Homebrew:

```bash
brew tap mobile-dev-inc/tap
brew trust --formula mobile-dev-inc/tap/maestro
brew install mobile-dev-inc/tap/maestro
```

Verify:

```bash
maestro --help
```

## 4. Fast path: build, install, and run Maestro

From the repository root:

```bash
bash scripts/test-ios-maestro.sh
```

The script will:

1. validate required tools;
2. locate an available `iPhone 17 Pro` Simulator;
3. generate `LinePay.xcodeproj` with XcodeGen;
4. boot the Simulator;
5. build the Debug iOS Simulator app;
6. install `LinePay.app`;
7. run the Maestro workspace.

The generated Xcode project and build products are disposable output.

### Use a different Simulator

List available devices:

```bash
xcrun simctl list devices available
```

Then:

```bash
MAESTRO_IOS_DEVICE="iPhone 16 Pro" bash scripts/test-ios-maestro.sh
```

Use an exact Simulator name from `simctl` output.

### Run one flow only

```bash
bash scripts/test-ios-maestro.sh .maestro/flows/onboarding-smoke.yaml
```

## 5. Manual build/install workflow

Use this when debugging the build separately from Maestro.

Generate the Xcode project:

```bash
cd apps/ios
xcodegen generate
cd ../..
```

Open the Simulator:

```bash
open -a Simulator
```

Find the Simulator you want:

```bash
xcrun simctl list devices available
```

Build for it:

```bash
xcodebuild \
  -project apps/ios/LinePay.xcodeproj \
  -scheme LinePay \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/maestro-ios \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Install the built app into the booted Simulator:

```bash
xcrun simctl install booted \
  .build/maestro-ios/Build/Products/Debug-iphonesimulator/LinePay.app
```

Then run Maestro:

```bash
maestro test .maestro
```

Or run only smoke tests:

```bash
maestro test .maestro --include-tags=smoke
```

## 6. Current smoke flow

The first checked-in flow is:

```text
.maestro/flows/onboarding-smoke.yaml
```

It verifies the minimum fresh-install journey:

```text
fresh app state
    ↓
welcome
    ↓
set up pay
    ↓
enter hourly rate
    ↓
save confirmed pay rules
    ↓
soft Pro screen
    ↓
continue free
    ↓
Today screen is usable
```

The flow deliberately does not enable optional overtime/callout/per-diem rules. This protects the product invariant that LinePay never silently invents optional pay rules.

## 7. Selector policy

Prefer stable accessibility identifiers over visible English text for controls that belong to critical automation journeys.

Current examples:

```text
onboarding.set-up-pay
pay-profile.hourly-rate
pay-profile.save
paywall.continue-free
today.add-work
```

In SwiftUI:

```swift
Button("Set up my pay") {
    // ...
}
.accessibilityIdentifier("onboarding.set-up-pay")
```

In Maestro:

```yaml
- tapOn:
    id: onboarding.set-up-pay
```

Why:

- localization changes should not break tests;
- copy improvements should not break tests;
- duplicate text is less ambiguous;
- identifiers are easier to inspect and diagnose.

Do not add identifiers to every decorative view. Add them to stable user actions and critical observable states.

Identifier naming convention:

```text
<feature>.<semantic-control>
```

Examples:

```text
today.add-work
work.save
paystub.confirm-gross
reconciliation.possible-difference
settings.edit-pay-rules
```

Identifiers describe product meaning, not implementation structure. Avoid names such as `button1`, `vstack3`, or `blueCTA`.

## 8. Fresh-state tests

Use:

```yaml
- launchApp:
    clearState: true
```

For iOS, Maestro resets application state by reinstalling the app. Fresh-install flows should therefore be independent and able to run in any order.

Do not design a suite where Flow B requires Flow A to have left data behind.

If reusable setup becomes necessary, compose setup through `runFlow` rather than relying on execution order and accidental device state.

This matters even more after SwiftData arrives: E2E flows should make their starting state explicit.

## 9. Waiting and flake prevention

Maestro already retries ordinary assertions while the UI settles. Prefer:

```yaml
- assertVisible:
    id: today.add-work
```

over fixed sleeps.

For genuinely slow operations, use `extendedWaitUntil` with a realistic timeout.

Avoid:

```text
sleep 5 seconds
sleep 10 seconds
sleep 30 seconds
```

Fixed delays make tests both slower and less reliable.

Use `scrollUntilVisible` instead of hardcoded swipe coordinates for normal full-screen scroll views:

```yaml
- scrollUntilVisible:
    element:
      id: pay-profile.save
    direction: DOWN
```

### iOS keyboard caveat

Maestro's `hideKeyboard` can be unreliable on iOS because the platform does not expose a direct keyboard-dismiss API.

For the current onboarding smoke flow, after entering the decimal hourly rate we tap a safe non-action area near the navigation bar before scrolling to the Save button:

```yaml
- tapOn:
    point: "50%,12%"
```

Prefer stable semantic actions when possible. Use coordinate taps only for system-level workarounds like this, not for normal feature navigation.

## 10. Authoring flows

A flow has configuration above `---` and commands below it:

```yaml
appId: com.streamentry.linepay
name: Add one work interval
tags:
  - smoke
  - ios
---
- launchApp
- tapOn:
    id: today.add-work
```

Keep flows focused on one user journey.

Good:

```text
onboarding-smoke.yaml
add-work-smoke.yaml
edit-work.yaml
paystub-reconciliation-smoke.yaml
```

Avoid one giant `everything.yaml` that tries to validate the entire app in sequence.

## 11. Tags

Use tags to keep local suites intentional.

Recommended tags:

```text
smoke        critical fast journey
regression   bug or edge-case UI regression
ios          iOS-specific journey
storekit     purchase/restore behavior
ocr          scanner/import behavior
```

Run smoke only:

```bash
maestro test .maestro --include-tags=smoke
```

Run everything except a temporarily isolated tag:

```bash
maestro test .maestro --exclude-tags=experimental
```

Do not use `flaky` as a permanent graveyard. A flaky critical test is a defect in either the app, selector strategy, or test design and should be fixed.

## 12. Maestro Studio

Maestro Studio is useful for inspecting the Accessibility tree and authoring/debugging flows interactively.

Open the running Simulator, connect Maestro Studio, and point its workspace to:

```text
<repo>/.maestro
```

Use Inspect Screen to confirm the element exposes the expected accessibility identifier.

Studio is an authoring/debugging tool. The checked-in YAML remains source of truth.

## 13. Debugging failures

First establish which layer failed.

### App failed to build

Run:

```bash
bash scripts/check-ios.sh
```

Do not debug Maestro until the native app tests/build are green.

### Simulator unavailable

```bash
xcrun simctl list devices available
```

Then select one explicitly:

```bash
MAESTRO_IOS_DEVICE="<exact name>" bash scripts/test-ios-maestro.sh
```

### Maestro cannot find an element

Check, in order:

1. is the correct screen visible?
2. is the element actually in the Accessibility tree?
3. does its `.accessibilityIdentifier(...)` match the YAML exactly?
4. is the element below the fold and needs `scrollUntilVisible`?
5. did a keyboard or sheet cover it?
6. did product behavior change legitimately, requiring the flow to change?

Do not immediately replace a semantic selector with coordinates.

### Inspect artifacts

Local test artifacts are configured under:

```text
.build/maestro-results/
```

They include failure screenshots/logs and command metadata generated by Maestro.

A failure artifact is usually more useful than adding arbitrary retries.

## 14. What belongs in CI later

Maestro is currently documented and runnable locally first.

Before making Maestro a required PR gate:

- keep the smoke suite under a few minutes;
- prove it is stable across repeated local runs;
- pin/record the Maestro CLI version used by CI;
- use a known Simulator runtime/device;
- upload Maestro artifacts on failure;
- keep domain/app Swift tests as the primary fast gate.

The intended test pyramid remains:

```text
many LinePayDomain tests
        ↓
fewer app integration tests
        ↓
very few Maestro end-to-end flows
```

Do not make the slowest layer carry correctness that can be tested deterministically below it.

## 15. Normal local development loop

For ordinary Swift work:

```bash
bash scripts/check-ios.sh
```

For a user-facing critical-flow change:

```bash
bash scripts/check-ios.sh
bash scripts/test-ios-maestro.sh
```

For rapid Maestro iteration after the app is already built and installed:

```bash
maestro test .maestro/flows/onboarding-smoke.yaml
```

This is the expected local quality loop for LinePay.

## 16. Source references

Current Maestro documentation used for this workflow:

- CLI installation: https://docs.maestro.dev/maestro-cli/how-to-install-maestro-cli
- iOS support: https://docs.maestro.dev/getting-started/build-and-install-your-app/ios
- SwiftUI accessibility identifiers: https://docs.maestro.dev/platform-support/ios-swiftui
- Workspace configuration: https://docs.maestro.dev/api-reference/configuration/workspace-configuration
- Test discovery/tags: https://docs.maestro.dev/maestro-flows/workspace-management/test-discovery-and-tags
- `launchApp`: https://docs.maestro.dev/api-reference/commands/launchapp
- `assertVisible`: https://docs.maestro.dev/reference/commands-available/assertvisible
- `scrollUntilVisible`: https://docs.maestro.dev/reference/commands-available/scrolluntilvisible
- test artifacts: https://docs.maestro.dev/maestro-flows/workspace-management/test-reports-and-artifacts
- iOS `hideKeyboard` caveat: https://docs.maestro.dev/reference/commands-available/hidekeyboard
