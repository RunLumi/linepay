# LinePay iOS 1.0 manual QA

Run on a real iPhone before App Store submission. Use synthetic pay data only.

## Fresh install

- [ ] Launch shows value/privacy welcome, not a paywall.
- [ ] No account/login prompt exists.
- [ ] No camera/photo permission appears before the user chooses a relevant action.
- [ ] Optional pay rules are off by default.
- [ ] Saving a profile enters Today and survives force-quit/relaunch.

## Pay rules

- [ ] Base rate and timezone are visible and editable.
- [ ] Weekly, biweekly, and manual pay periods create the expected boundaries.
- [ ] Regular schedule + outside multiplier can be enabled explicitly.
- [ ] Daily OT, Sunday, date premium, callout minimum, and per diem are independent toggles.
- [ ] Agreement effective dates reject work outside the configured dates.
- [ ] Source title/URL/section remain visible in audit evidence.
- [ ] Editing rules increments the version and never changes archived history.

## Work logging

- [ ] Add a normal shift.
- [ ] Add an overnight shift.
- [ ] Add a callout.
- [ ] Add an exact unpaid break and verify clock span differs from paid worked time.
- [ ] Overlapping work is rejected without mutating the existing log.
- [ ] Work outside the current pay period is rejected clearly.
- [ ] Repeat last shift preserves time/duration/kind/break pattern and uses the new date.
- [ ] Delete work and Undo restores the exact entry.
- [ ] Expected gross and ledger update immediately after edits.

## Paystub evidence

- [ ] Scan a synthetic paystub using the document camera.
- [ ] Import a paystub photo.
- [ ] Import a PDF/image from Files.
- [ ] Enter a paycheck manually.
- [ ] OCR suggestions are editable before audit.
- [ ] A failed/partial OCR still permits manual confirmation.
- [ ] Original evidence can be viewed locally.
- [ ] Removing original evidence does not delete confirmed structured facts.

## Reconciliation

- [ ] Exact gross match shows `Matches` with non-color cue.
- [ ] Lower paid gross shows `Possible shortfall`.
- [ ] Higher paid gross shows `Possible overpayment`.
- [ ] Editing work after an audit changes status to `Needs review` rather than silently trusting stale reconciliation.
- [ ] Re-running the same pay-period audit remains allowed after the free audit was consumed.
- [ ] Optional confirmed regular/OT/DT/callout/per-diem lines produce explainable comparisons.
- [ ] Evidence drill-down reaches calculation, rule version/source, and paystub evidence.

## Pricing / StoreKit

- [ ] First complete paycheck audit is possible before subscribing.
- [ ] Welcome has no paywall; the first real expected-pay result leads to an optional annual trial offer with Continue free.
- [ ] Eligible Annual shows seven days free then the full localized yearly charge; ineligible Annual and Monthly show immediate paid terms.
- [ ] Unknown eligibility, missing offer, or unavailable products never produce a false free-trial claim.
- [ ] Trial start, renewal, disabled renewal, expiry, revocation, and restore follow verified StoreKit state.
- [ ] Audits during Pro/trial do not consume an unused Free audit; same-period corrections remain available.
- [ ] Renewal reminder is promised only after opt-in and successful scheduling; denied permissions preserve access.
- [ ] A later new pay-period audit asks for Pro in a Release/TestFlight build.
- [ ] Yearly and monthly products show App Store localized prices.
- [ ] Yearly is recommended without hiding monthly.
- [ ] Purchase, cancel, pending, restore, expiration, and billing-retry behavior do not affect pay calculation/history.

## History / export

- [ ] Finish pay period creates immutable History row.
- [ ] Weekly/biweekly cadence advances to the next period automatically.
- [ ] Manual cadence requires an explicit new period.
- [ ] Historical work/rules/calculation/audit survive relaunch.
- [ ] PDF reconciliation export contains expected/paid/difference, ledger, rule references, and disclaimer.
- [ ] PDF report does not silently include the original paystub.
- [ ] JSON backup exports user-owned structured data.

## Privacy / recovery

- [ ] No paystub/wage content appears in console logs.
- [ ] Airplane mode still allows setup, work logging, calculation, history, manual audit, and exports.
- [ ] Delete all local data returns to onboarding.
- [ ] Corrupt/unsupported local state shows recovery UI rather than overwriting the source.
- [ ] Recovery file can be exported before reset.

## Accessibility / field use

- [ ] VoiceOver identifies all icon-only actions.
- [ ] Dynamic Type remains usable through accessibility sizes.
- [ ] Increase Contrast and dark mode preserve hierarchy.
- [ ] Statuses are understandable without color.
- [ ] Frequent controls are at least 44 pt and primary field actions are comfortably larger.
- [ ] Reduce Motion does not remove required information.
