# CI gate

The end-to-end 1.0 implementation is not considered verified until the pull request passes the repository's Xcode 26.6 / Swift 6.3 `scripts/check-ios.sh` workflow.

Compiler, lint, domain-test, app-test, or generated-project failures found by CI must be fixed before merge. Manual real-device and StoreKit/TestFlight checks remain separate release gates.
