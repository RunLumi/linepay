# LinePay iOS

Native SwiftUI client. iOS ships first; Android remains a separate native client when demand proves it is worth building.

## Toolchain

- Xcode 26.x stable
- Swift 6.2 toolchain / Swift 6 language mode
- XcodeGen >= 2.46.0
- iOS deployment target 18.0

## Generate and open

```bash
cd apps/ios
brew install xcodegen   # first time only
xcodegen generate
open LinePay.xcodeproj
```

The generated `.xcodeproj` is intentionally ignored. `project.yml`, xcconfigs, package manifests, and source folders are the source of truth.

## Fast checks

```bash
# Pure domain package, fastest feedback loop
cd apps/ios/Packages/LinePayDomain
swift test

# Formatting/linting using the Swift toolchain
cd ../../../../
swift format lint --recursive --configuration .swift-format apps/ios

# Full iOS build/test after project generation
cd apps/ios
xcodegen generate
xcodebuild \
  -project LinePay.xcodeproj \
  -scheme LinePay \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Do not hard-code a simulator name into CI without verifying the runner image. CI should discover or use a known installed device/runtime.

## Why this shape

The Xcode app target should stay thin. Business-critical pay logic belongs in `Packages/LinePayDomain`, which is a local Swift package with no SwiftUI, SwiftData, StoreKit, Vision, or network dependencies. This makes calculations fast to test and difficult for platform concerns to contaminate.

Do not create feature modules merely because a folder has grown. Extract a module when a real boundary has independent tests, ownership, dependencies, or build-time value.
