# LinePay iOS 1.0 implementation status

This file records implementation state separately from product scope so the plan never claims unverified work is release-ready.

## Implemented on `feat/ios-1.0-e2e`

- exact unpaid-break domain semantics and tests;
- full pay-profile/rule editor;
- weekly, biweekly, and manual pay-period lifecycle;
- fast work logging, notes, edit/delete/undo, repeat-last-shift;
- versioned atomic local persistence and protected paystub evidence files;
- restart-safe onboarding derived from durable state;
- local document scan, photo/file import, manual paycheck entry;
- on-device Vision OCR suggestions with explicit user confirmation;
- expected-vs-paid audit with match/shortfall/overpayment/review states;
- evidence drill-down through calculation, rule snapshot/source, and local paystub;
- immutable History snapshots;
- PDF reconciliation export and structured JSON backup;
- StoreKit Pro boundary after first free audit;
- privacy/data deletion and corrupt-state recovery;
- end-to-end manual QA checklist.

## Verification still required before calling 1.0 release-ready

- GitHub Actions must pass on Xcode 26.6 / Swift 6.3 strict concurrency;
- real-device document scanner test;
- real StoreKit sandbox/TestFlight purchase and restore test;
- VoiceOver/Dynamic Type/daylight contrast manual audit;
- TestFlight migration/relaunch test with synthetic historical data;
- final App Store privacy and product metadata review.

A green build proves compile/tests, not product-market correctness. The release gates in `docs/plan/ios-1.0.md` and `docs/checklists/ios-1.0-manual-qa.md` remain authoritative.
