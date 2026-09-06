# LinePay iOS 1.0 ASCII Mockups

Status: **Canonical interaction reference for iOS 1.0 planning**

Governing documents:

- `AGENTS.md`
- `DESIGN.md`
- `docs/plan/ios-1.0.md`
- `docs/product/pricing.md`

These are structure and interaction mockups, not pixel specifications. Native iOS controls, sheets, pickers, typography, spacing, accessibility behavior, and materials should remain native unless `DESIGN.md` says otherwise.

The visual target is **Precision Industrial Minimalism**: ledger structure, aligned numbers, graphite/porcelain surfaces, Oxide interaction color, almost no decoration, and evidence-first hierarchy.

---

## 0. Mockup conventions

```text
+--------------------------------------+
| Screen title                    Edit |
+--------------------------------------+
|                                      |
|  PRIMARY FACT                        |
|  $7,421.80                           |
|                                      |
|  Secondary information               |
|                                      |
|  [ Primary action ]                  |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

Conventions:

- `[ Action ]` = tappable button/control.
- `> Row` = tappable navigation/disclosure row.
- `( )` = radio/selection.
- `[x]` = enabled toggle/check.
- `[ ]` = disabled toggle/check.
- `...` = system-owned content or long scrolling content.
- Monetary values use aligned/tabular digits in implementation.
- Status never relies on color alone.
- Native system scanner/photo/file/share/StoreKit UI is not recreated; only our handoff screens are mocked.

---

# A. Onboarding and setup

## 1. Welcome

Purpose: establish the product promise and privacy in seconds.

```text
+--------------------------------------+
|                                      |
|                                      |
|          --------   --------         |
|             LINE GAP                 |
|                                      |
|  Know what your work should pay.     |
|                                      |
|  LinePay uses the work and pay rules |
|  you confirm to estimate your check. |
|                                      |
|  Your pay data stays on this iPhone. |
|                                      |
|  [ Set up my pay                ]    |
|                                      |
|  No account. No employer connection. |
|                                      |
+--------------------------------------+
```

No paywall. No carousel. No permission request.

---

## 2. Pay basics

Purpose: collect only facts needed to start a valid profile.

```text
+--------------------------------------+
| < Back                Set up my pay  |
+--------------------------------------+
|                                      |
|  PAY BASICS                          |
|                                      |
|  Profile name                        |
|  +--------------------------------+  |
|  | My current pay                 |  |
|  +--------------------------------+  |
|                                      |
|  Base hourly rate                    |
|  +--------------------------------+  |
|  | $ 58.00                        |  |
|  +--------------------------------+  |
|                                      |
|  Currency                            |
|  USD                             >   |
|                                      |
|  Payroll timezone                    |
|  America/Chicago                 >   |
|                                      |
|  Used for Sunday, overtime and       |
|  overnight rule boundaries.          |
|                                      |
|  [ Continue                     ]    |
|                                      |
+--------------------------------------+
```

Do not ask for union/local/employer unless needed for a source-backed rule preset later.

---

## 3. Pay period setup

```text
+--------------------------------------+
| < Back                   Pay period  |
+--------------------------------------+
|                                      |
|  How often does this check close?    |
|                                      |
|  ( ) Weekly                          |
|  (*) Every 2 weeks                   |
|  ( ) Custom dates                    |
|                                      |
|  Current period                      |
|  Aug 31 - Sep 13, 2026               |
|                                      |
|  Starts                              |
|  Monday, Aug 31                  >   |
|                                      |
|  LinePay will use this period on     |
|  Today and Pay. You can correct it   |
|  later without changing old checks.  |
|                                      |
|  [ Continue                     ]    |
|                                      |
+--------------------------------------+
```

---

## 4. Optional rules

Purpose: progressive disclosure. Everything optional starts off.

```text
+--------------------------------------+
| < Back                    Pay rules  |
+--------------------------------------+
|                                      |
|  Add only rules that actually apply. |
|                                      |
|  Daily overtime                 [x]  |
|  After 8.0 worked hours       1.5x > |
|  ----------------------------------  |
|  Sunday premium                 [ ]  |
|  ----------------------------------  |
|  Callout minimum                [x]  |
|  4 paid hours minimum             >  |
|  ----------------------------------  |
|  Per diem                       [x]  |
|  $125 per worked day              >  |
|  ----------------------------------  |
|  Outside-schedule premium        [ ]  |
|  ----------------------------------  |
|  Holiday/date premium            [ ]  |
|                                      |
|  > Advanced agreement rules          |
|                                      |
|  [ Continue                     ]    |
|                                      |
|  [ I don't see my rule          ]    |
|                                      |
+--------------------------------------+
```

---

## 5. Confirm pay rules

The first trust checkpoint.

```text
+--------------------------------------+
| < Back                Confirm rules  |
+--------------------------------------+
|                                      |
|  This is what LinePay will use.      |
|                                      |
|  Base rate                 $58.00/hr  |
|  ----------------------------------  |
|  Daily overtime                      |
|  After 8.0 worked hours         1.5x |
|  ----------------------------------  |
|  Callout minimum            4.0 paid |
|                                  hrs |
|  ----------------------------------  |
|  Per diem              $125/work day |
|  ----------------------------------  |
|  Pay period                    2 weeks|
|  Timezone             America/Chicago|
|                                      |
|  Rule source                         |
|  Confirmed by you - no source        |
|  attached yet.                       |
|                                      |
|  [ Use these rules             ]    |
|                                      |
|  You can edit future rules later.    |
|  Old pay periods keep their version. |
|                                      |
+--------------------------------------+
```

---

## 6. Unsupported rule explanation

```text
+--------------------------------------+
| < Back                Unsupported    |
+--------------------------------------+
|                                      |
|  Don't force a close-enough rule.    |
|                                      |
|  If your agreement uses a rule that  |
|  LinePay cannot represent correctly, |
|  leave it out rather than approxim-  |
|  ating it.                           |
|                                      |
|  Examples                            |
|  - unusual stacking rules            |
|  - conditional meal penalties        |
|  - complex travel guarantees         |
|                                      |
|  [ Continue without this rule   ]    |
|                                      |
|  [ Add source/note for later    ]    |
|                                      |
|  LinePay will mark calculations      |
|  that may be incomplete.             |
|                                      |
+--------------------------------------+
```

---

# B. Today and work capture

## 7. Today - empty current period

```text
+--------------------------------------+
| Today                                |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|  EXPECTED GROSS                      |
|  $0.00                               |
|                                      |
|  0 h logged                          |
|  My current pay                      |
|                                      |
|  [ + Add work                   ]    |
|                                      |
|  WORK LOG                            |
|                                      |
|  No work logged this pay period.     |
|  Add today's hours and LinePay will  |
|  calculate what they should pay.     |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 8. Today - active period

```text
+--------------------------------------+
| Today                                |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|  EXPECTED GROSS                      |
|  $3,284.00                           |
|                                      |
|  44.0 h logged  |  Paystub pending   |
|                                      |
|  [ Repeat last shift            ]    |
|  [ + Add work                   ]    |
|                                      |
|  WORK LOG                            |
|                                      |
|  Fri, Sep 4                    12.0 h |
|  Regular work                        |
|  7:00 AM - 7:00 PM                 > |
|  ----------------------------------  |
|  Thu, Sep 3                    12.0 h |
|  Callout                             |
|  6:00 AM - 6:00 PM                 > |
|  ----------------------------------  |
|  Wed, Sep 2                    10.0 h |
|  Regular work                       >|
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

Primary visual emphasis remains expected gross, not number of cards.

---

## 9. Add work

```text
+--------------------------------------+
| Cancel                    Add work   |
+--------------------------------------+
|                                      |
|  WORK TYPE                           |
|  [ Regular ] [ Callout ] [ Other ]   |
|                                      |
|  Start                               |
|  Fri, Sep 4        7:00 AM       >   |
|                                      |
|  End                                 |
|  Fri, Sep 4        7:00 PM       >   |
|                                      |
|  Unpaid break                        |
|  0 min                           >   |
|                                      |
|  Duration                            |
|  12.0 h                              |
|                                      |
|  Note                                |
|  +--------------------------------+  |
|  | Storm - Tulsa                  |  |
|  +--------------------------------+  |
|                                      |
|  Timezone: America/Chicago           |
|                                      |
|  [ Save work                    ]    |
|                                      |
+--------------------------------------+
```

Duration is derived and never edits start/end behind the user's back.

---

## 10. Repeat last shift / quick draft

```text
+--------------------------------------+
| Cancel               Repeat last     |
+--------------------------------------+
|                                      |
|  Copied from Thu, Sep 3              |
|                                      |
|  Callout                             |
|  6:00 AM - 6:00 PM                   |
|  Break: 0 min                        |
|  Note: Storm - Tulsa                 |
|                                      |
|  New date                            |
|  Fri, Sep 4                      >   |
|                                      |
|  [ Save same shift              ]    |
|                                      |
|  [ Edit details                 ]    |
|                                      |
+--------------------------------------+
```

If time/date changes cross a DST boundary, saving still goes through normal validation/calculation.

---

## 11. Edit work

```text
+--------------------------------------+
| Cancel                    Edit work  |
+--------------------------------------+
|                                      |
|  Regular work                        |
|                                      |
|  Start                               |
|  Fri, Sep 4        7:00 AM       >   |
|                                      |
|  End                                 |
|  Fri, Sep 4        7:30 PM       >   |
|                                      |
|  Unpaid break                        |
|  30 min                          >   |
|                                      |
|  Worked duration                     |
|  12.0 h                              |
|                                      |
|  [ Save changes                 ]    |
|                                      |
|  [ Delete work                  ]    |
|                                      |
+--------------------------------------+
```

---

## 12. Work validation error

Inline, specific, recoverable.

```text
+--------------------------------------+
| Cancel                    Add work   |
+--------------------------------------+
|                                      |
|  Start    Fri 7:00 AM                |
|  End      Fri 6:00 PM                |
|                                      |
|  ! This overlaps work already logged |
|    Friday from 5:00 PM - 8:00 PM.    |
|                                      |
|  [ View conflicting entry       ]    |
|                                      |
|  Your draft is still here.            |
|                                      |
|  [ Save work ]  (disabled)           |
|                                      |
+--------------------------------------+
```

Other errors use same pattern: invalid range, break too long, unsupported rule/effective-date issue.

---

## 13. Delete + Undo state

```text
+--------------------------------------+
| Today                                |
+--------------------------------------+
|  ...                                 |
|                                      |
|  Thu, Sep 3                    12.0 h |
|  Callout                            > |
|                                      |
|  Work deleted.             [ Undo ]  |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

Use native transient presentation where appropriate.

---

# C. Pay and expected calculation

## 14. Pay - no work

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|  EXPECTED GROSS                      |
|  $0.00                               |
|                                      |
|  No work to calculate yet.           |
|                                      |
|  [ Add work                     ]    |
|                                      |
|  Pay rules                           |
|  My current pay v1                  >|
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 15. Pay - expected ledger

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|  EXPECTED GROSS                      |
|  $7,421.80                           |
|                                      |
|  84.5 worked hours                   |
|  My current pay - rules v3           |
|                                      |
|  [ Check paycheck               ]    |
|                                      |
|  PAY LEDGER                          |
|                                      |
|  Fri, Sep 11                         |
|  Regular   8.0h x $58.00     $464.00 |
|                                      |
|  Overtime  4.0h x $58 x1.5   $348.00 |
|  After 8 worked hours              > |
|                                      |
|  Callout minimum             $116.00 |
|  +2.0 paid-hour equivalent         > |
|                                      |
|  Per diem                    $125.00 |
|  Worked day                        > |
|  ----------------------------------  |
|  Thu, Sep 10                         |
|  ...                                 |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 16. Ledger component detail - Why this amount?

```text
+--------------------------------------+
| < Pay              Why this amount? |
+--------------------------------------+
|                                      |
|  CALLOUT MINIMUM             $116.00 |
|                                      |
|  Work facts                          |
|  Callout: Sep 11                     |
|  5:00 AM - 7:00 AM                  |
|  Actual work                    2.0 h |
|                                      |
|  Applied rule                        |
|  4 paid hours minimum                |
|                                      |
|  Calculation                         |
|  Guaranteed                4.0 h     |
|  Actual work              -2.0 h     |
|  Additional paid equiv.    2.0 h     |
|  x $58.00                           |
|  = $116.00                           |
|                                      |
|  Rule source                         |
|  Agreement v3 - Rule 7.4           >|
|                                      |
+--------------------------------------+
```

The language keeps actual hours and derived entitlement separate.

---

## 17. Rule source detail

```text
+--------------------------------------+
| < Back                  Rule source  |
+--------------------------------------+
|                                      |
|  Callout minimum                     |
|  Rule 7.4                            |
|                                      |
|  4 paid hours minimum                |
|                                      |
|  Source                              |
|  Outside Line Agreement 2026         |
|  Section 7.4                         |
|                                      |
|  Effective                           |
|  Jan 1 - Dec 31, 2026                |
|                                      |
|  Verification                        |
|  Confirmed by you Sep 1, 2026        |
|                                      |
|  [ Open source link             ]    |
|                                      |
|  Rule snapshot                       |
|  agreement-123 / version 3           |
|                                      |
+--------------------------------------+
```

If no source exists, replace source block with `Confirmed by you - no source attached.`

---

# D. Paystub acquisition and review

## 18. Check paycheck - source chooser

```text
+--------------------------------------+
| Cancel               Check paycheck |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|  Expected: $7,421.80                 |
|                                      |
|  Add the paycheck you want to check. |
|  Processing stays on this iPhone.    |
|                                      |
|  [ Scan paystub                 ]    |
|                                      |
|  [ Choose photo                 ]    |
|                                      |
|  [ Choose PDF or file           ]    |
|                                      |
|  [ Enter manually               ]    |
|                                      |
|  No LinePay account or server upload.|
|                                      |
+--------------------------------------+
```

Manual entry is first-class.

---

## 19. System document scanner handoff

We do not recreate VisionKit UI.

```text
+--------------------------------------+
| LINEPAY HANDOFF                      |
+--------------------------------------+
|                                      |
|  [ System Document Scanner ]         |
|                                      |
|  Native camera, crop, page capture,  |
|  retake and Done controls.           |
|                                      |
|  On Done -> OCR Review               |
|  On Cancel -> return to Pay          |
|                                      |
+--------------------------------------+
```

---

## 20. OCR review

```text
+--------------------------------------+
| Cancel               Review paystub  |
+--------------------------------------+
|                                      |
|  Check 2 fields before auditing.     |
|                                      |
|  PAY PERIOD                          |
|  Aug 31 - Sep 13              Ready  |
|                                      |
|  GROSS PAY                           |
|  $6,968.20                    Ready  |
|                                      |
|  REGULAR HOURS                       |
|  80.0                         Ready  |
|                                      |
|  OVERTIME HOURS                      |
|  2.5                         ! Check >|
|  Source text is unclear.             |
|                                      |
|  DOUBLE TIME                         |
|  Not found                   ! Check >|
|                                      |
|  [ Review 2 fields              ]    |
|                                      |
|  [ Audit with confirmed fields  ]    |
|  (enabled only when sufficient)      |
|                                      |
+--------------------------------------+
```

No `AI confidence 73%` theater unless a value genuinely helps the worker decide.

---

## 21. OCR field/source detail

```text
+--------------------------------------+
| < Review             Overtime hours  |
+--------------------------------------+
|                                      |
|  Source on paystub                   |
|  +--------------------------------+  |
|  | OT HOURS        12.50          |  |
|  | [source crop / page region]    |  |
|  +--------------------------------+  |
|                                      |
|  LinePay read                        |
|  +--------------------------------+  |
|  | 2.5                            |  |
|  +--------------------------------+  |
|                                      |
|  Enter the value shown               |
|  +--------------------------------+  |
|  | 12.5                           |  |
|  +--------------------------------+  |
|                                      |
|  [ Confirm 12.5                 ]    |
|                                      |
+--------------------------------------+
```

Correction is easier than rescanning.

---

## 22. Manual paystub entry

```text
+--------------------------------------+
| Cancel               Enter paystub  |
+--------------------------------------+
|                                      |
|  PAY PERIOD                          |
|  Aug 31 - Sep 13                 >   |
|                                      |
|  Gross pay                           |
|  +--------------------------------+  |
|  | $ 6,968.20                     |  |
|  +--------------------------------+  |
|                                      |
|  Optional line details               |
|                                      |
|  Regular hours                       |
|  +--------------------------------+  |
|  | 80.0                           |  |
|  +--------------------------------+  |
|                                      |
|  Overtime hours                      |
|  +--------------------------------+  |
|  | 12.5                           |  |
|  +--------------------------------+  |
|                                      |
|  > Add another paystub line           |
|                                      |
|  [ Confirm and audit            ]    |
|                                      |
+--------------------------------------+
```

Top-level audit may proceed from gross only; component verdict strength depends on evidence available.

---

## 23. Incomplete evidence / needs confirmation

```text
+--------------------------------------+
| Review paystub                       |
+--------------------------------------+
|                                      |
|  ! More information is needed        |
|                                      |
|  LinePay can compare the gross total,|
|  but cannot reliably map the overtime|
|  lines on this paystub.              |
|                                      |
|  Confirmed                           |
|  Gross pay                 $6,968.20 |
|                                      |
|  Needs review                        |
|  Overtime hours                 2    |
|                                      |
|  [ Review fields                ]    |
|                                      |
|  [ Continue with limited audit  ]    |
|                                      |
|  Result will be marked Needs review. |
|                                      |
+--------------------------------------+
```

---

# E. Audit states

## 24. Audit - Matches

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|                                      |
|  EXPECTED                PAID        |
|  $7,421.80           $7,421.80       |
|                                      |
|  -----------||----------------       |
|              no gap                  |
|                                      |
|  [check] Matches                     |
|                                      |
|  Confirmed paystub facts match       |
|  LinePay's expected total.           |
|                                      |
|  > View confirmed paystub            |
|  > View Pay Ledger                    |
|                                      |
|  [ Finish this pay period       ]    |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

No confetti or animated celebration.

---

## 25. Audit - Possible shortfall

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|                                      |
|  EXPECTED                PAID        |
|  $7,421.80           $6,968.20       |
|                                      |
|  -----------   ----------------      |
|             gap                      |
|                                      |
|  ! POSSIBLE SHORTFALL                |
|  $453.60                             |
|                                      |
|  What to check                       |
|                                      |
|  Missing callout minimum     $232.00 >|
|  Missing rest/premium item   $221.60 >|
|                                      |
|  Check these lines with your paystub |
|  or payroll. LinePay is an estimate. |
|                                      |
|  [ Finish this pay period       ]    |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 26. Audit - Possible overpayment

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  EXPECTED                PAID        |
|  $6,968.20           $7,110.20       |
|                                      |
|  -----------   ----------------      |
|             gap                      |
|                                      |
|  ! POSSIBLE OVERPAYMENT              |
|  $142.00                             |
|                                      |
|  One paystub line is higher than the |
|  rules and work currently recorded.  |
|                                      |
|  Premium line                +$142.00>|
|                                      |
|  Check whether LinePay is missing a  |
|  rule before treating this as final. |
|                                      |
|  [ Review rules                 ]    |
|  [ Finish this pay period       ]    |
|                                      |
+--------------------------------------+
```

Neutral wording and status cue, not celebratory green.

---

## 27. Audit - Needs review

```text
+--------------------------------------+
| Pay                                  |
+--------------------------------------+
|                                      |
|  EXPECTED                PAID        |
|  $7,421.80           $6,968.20       |
|                                      |
|  ? NEEDS REVIEW                      |
|                                      |
|  The gross totals differ by $453.60, |
|  but LinePay cannot confidently map  |
|  two paystub lines.                  |
|                                      |
|  ! Overtime hours              Check >|
|  ! Premium line                Check >|
|                                      |
|  [ Review paystub fields        ]    |
|                                      |
|  You can keep this period open.      |
|                                      |
+--------------------------------------+
```

---

## 28. Discrepancy detail

```text
+--------------------------------------+
| < Audit        Possible discrepancy |
+--------------------------------------+
|                                      |
|  CALLOUT MINIMUM                     |
|  Possible difference        -$232.00 |
|                                      |
|  Expected                    $464.00  |
|  Paystub                     $232.00  |
|                                      |
|  1. WORK FACTS                        |
|  Sep 11 callout                4.0 h >|
|                                      |
|  2. APPLIED RULE                      |
|  4 paid hours minimum        Rule 7.4>|
|                                      |
|  3. CALCULATION                       |
|  4.0 paid h x $58.00        $232.00  |
|  + related expected line    $232.00  |
|                                      |
|  4. PAYSTUB EVIDENCE                  |
|  Callout / OT line           $232.00 >|
|                                      |
|  [ View source paystub         ]     |
|                                      |
|  Check this line with payroll.       |
|                                      |
+--------------------------------------+
```

Exact component mapping may differ by rule type, but the evidence ladder stays consistent.

---

## 29. Paystub evidence viewer

```text
+--------------------------------------+
| < Back                  Paystub 1/2  |
+--------------------------------------+
|                                      |
|  +--------------------------------+  |
|  |                                |  |
|  |       ORIGINAL PAYSTUB         |  |
|  |                                |  |
|  |   [highlighted source field]   |  |
|  |                                |  |
|  +--------------------------------+  |
|                                      |
|  Confirmed value                     |
|  Overtime hours               12.5   |
|                                      |
|  [ Edit confirmed value        ]     |
|                                      |
+--------------------------------------+
```

Use real zoom/pan/accessibility behavior, not a decorative image card.

---

## 30. Finish pay period

```text
+--------------------------------------+
| Cancel           Finish pay period  |
+--------------------------------------+
|                                      |
|  AUG 31 - SEP 13                     |
|                                      |
|  Expected                  $7,421.80 |
|  Paid                      $6,968.20 |
|  Possible difference        -$453.60 |
|                                      |
|  Status                            ! |
|  Possible shortfall                 |
|                                      |
|  Finishing keeps this audit and its  |
|  rule version as a historical record.|
|                                      |
|  [ Finish & archive            ]     |
|                                      |
|  [ Keep period open            ]     |
|                                      |
+--------------------------------------+
```

---

# F. History

## 31. History - empty

```text
+--------------------------------------+
| History                              |
+--------------------------------------+
|                                      |
|  No finished pay periods yet.        |
|                                      |
|  Complete your first paycheck audit  |
|  and finish the period to keep it    |
|  here.                               |
|                                      |
|  [ Go to current pay period     ]    |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 32. History - list

```text
+--------------------------------------+
| History                              |
+--------------------------------------+
|                                      |
|  Sep 2026                            |
|                                      |
|  Aug 31 - Sep 13        ! Shortfall  |
|  Expected              $7,421.80     |
|  Paid                  $6,968.20     |
|  Difference             -$453.60   > |
|  ----------------------------------  |
|  Aug 17 - Aug 30        [check] Match|
|  Expected              $5,802.00     |
|  Paid                  $5,802.00   > |
|  ----------------------------------  |
|  Aug 3 - Aug 16         ? Review     |
|  Expected              $6,144.00     |
|  Paid                  $6,020.00   > |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 33. Historical period detail

```text
+--------------------------------------+
| < History          Aug 31 - Sep 13  |
+--------------------------------------+
|                                      |
|  POSSIBLE SHORTFALL                  |
|  $453.60                             |
|                                      |
|  Expected                  $7,421.80 |
|  Paid                      $6,968.20 |
|                                      |
|  Archived Sep 14, 2026               |
|  Rules: My current pay v3            |
|                                      |
|  > Audit details                      |
|  > Pay Ledger                         |
|  > Confirmed paystub                  |
|  > Rule snapshot                      |
|                                      |
|  [ Export audit report          ]    |
|                                      |
+--------------------------------------+
```

No recalculation against current rules unless the user explicitly creates a new comparison outside the archived record.

---

# G. Monetization

## 34. Post-first-audit Pro offer

This appears only **after** the first free audit result has already been delivered and remains dismissible.

```text
+--------------------------------------+
| Done                       LinePay Pro|
+--------------------------------------+
|                                      |
|  Audit every paycheck.               |
|                                      |
|  Your first audit is complete.       |
|  Pro keeps checking future paychecks |
|  against the work and rules you log. |
|                                      |
|  BEST VALUE                          |
|  (*) $79.99 / year                   |
|      Save $39.89 vs monthly          |
|                                      |
|  ( ) $9.99 / month                   |
|                                      |
|  [ Continue with Yearly         ]    |
|                                      |
|  Your pay data stays on this iPhone. |
|                                      |
|  Restore Purchases                   |
|                                      |
+--------------------------------------+
```

`Done` returns to the completed first audit with no penalty.

---

## 35. Second-audit paywall

Hard value boundary after free audit is consumed.

```text
+--------------------------------------+
| < Pay                    LinePay Pro |
+--------------------------------------+
|                                      |
|  Keep checking every paycheck.       |
|                                      |
|  You already used your free complete |
|  paycheck audit. Your work log and   |
|  expected-pay calculation remain     |
|  available without Pro.              |
|                                      |
|  (*) $79.99 / year   Best value      |
|  ( ) $9.99 / month                   |
|                                      |
|  [ Continue with Yearly         ]    |
|                                      |
|  Restore Purchases                   |
|                                      |
+--------------------------------------+
```

Do not threaten loss of worker-owned data.

---

## 36. Store unavailable / restore result

State is inline/system-like, not a separate marketing screen.

```text
+--------------------------------------+
| LinePay Pro                          |
+--------------------------------------+
|                                      |
|  ! App Store is unavailable          |
|                                      |
|  We couldn't load subscription       |
|  options right now. Your work and    |
|  pay history are still available.    |
|                                      |
|  [ Try again                    ]    |
|                                      |
|  [ Restore Purchases            ]    |
|                                      |
|  [ Not now                      ]    |
|                                      |
+--------------------------------------+
```

Restore success uses: `LinePay Pro restored.`

---

# H. Settings and local data

## 37. Settings

```text
+--------------------------------------+
| Settings                             |
+--------------------------------------+
|                                      |
|  PAY                                 |
|  > Pay profile        My current pay |
|  > Pay period              Every 2 wk|
|  > Rule sources                    2 |
|                                      |
|  LINEPAY PRO                         |
|  > LinePay Pro                 Free  |
|  > Restore Purchases                 |
|                                      |
|  YOUR DATA                           |
|  > Privacy & local data              |
|  > Export data                       |
|                                      |
|  ABOUT                               |
|  > About LinePay                     |
|                                      |
+--------------------------------------+
| Today      Pay      History  Settings|
+--------------------------------------+
```

---

## 38. Pay profile summary

```text
+--------------------------------------+
| < Settings             Pay profile  |
+--------------------------------------+
|                                      |
|  My current pay                      |
|  Active rules v3                     |
|                                      |
|  Base rate                 $58.00/hr |
|  Daily OT        after 8.0 h at 1.5x |
|  Callout minimum             4.0 h   |
|  Per diem               $125/work day|
|                                      |
|  Effective                           |
|  Sep 1, 2026 - current               |
|                                      |
|  [ Edit future rules            ]    |
|                                      |
|  Old pay periods keep the rules      |
|  they were calculated with.          |
|                                      |
+--------------------------------------+
```

---

## 39. Edit pay rules

Same structure as onboarding Optional Rules, but makes version consequence explicit.

```text
+--------------------------------------+
| Cancel               Edit pay rules |
+--------------------------------------+
|                                      |
|  Base rate                    $60.00 >|
|  Daily overtime                [x]   |
|  Callout minimum               [x]   |
|  Per diem                      [x]   |
|  Sunday premium                [ ]   |
|                                      |
|  Effective from                      |
|  Sep 14, 2026                    >   |
|                                      |
|  Saving creates rules v4.            |
|  Archived periods stay on v3.        |
|                                      |
|  [ Review changes               ]    |
|                                      |
+--------------------------------------+
```

Review screen shows before/after differences before commit.

---

## 40. Pay period settings

```text
+--------------------------------------+
| < Settings              Pay period  |
+--------------------------------------+
|                                      |
|  Cadence                             |
|  Every 2 weeks                   >   |
|                                      |
|  Current period                      |
|  Aug 31 - Sep 13, 2026               |
|                                      |
|  Next period                         |
|  Sep 14 - Sep 27, 2026               |
|                                      |
|  [ Correct current dates        ]    |
|                                      |
|  Changes to cadence apply to future  |
|  periods and never rewrite History.  |
|                                      |
+--------------------------------------+
```

---

## 41. Rule sources

```text
+--------------------------------------+
| < Settings             Rule sources |
+--------------------------------------+
|                                      |
|  Outside Line Agreement 2026         |
|  2 rules attached                  > |
|  ----------------------------------  |
|  Manual confirmations                |
|  2 rules with no source            > |
|                                      |
|  [ Add source                   ]    |
|                                      |
|  A source helps explain a rule.      |
|  It does not make LinePay legal      |
|  advice or an authority.             |
|                                      |
+--------------------------------------+
```

---

## 42. Privacy & local data

```text
+--------------------------------------+
| < Settings        Privacy & data    |
+--------------------------------------+
|                                      |
|  Your paycheck stays on your iPhone. |
|                                      |
|  No LinePay account                  |
|  No employer connection              |
|  No paystub upload to LinePay server |
|                                      |
|  Stored on this device               |
|  - pay rules                         |
|  - work history                      |
|  - paystub sources you keep          |
|  - confirmed audit facts             |
|                                      |
|  > Manage paystub sources             |
|  > Export my data                     |
|                                      |
|  [ Delete all LinePay data      ]    |
|                                      |
+--------------------------------------+
```

---

## 43. Export data

```text
+--------------------------------------+
| < Settings              Export data |
+--------------------------------------+
|                                      |
|  Choose what to export               |
|                                      |
|  [x] Pay profiles / rule snapshots   |
|  [x] Work history                    |
|  [x] Audit summaries                 |
|  [ ] Original paystub files          |
|                                      |
|  Format                              |
|  ( ) CSV data                        |
|  (*) Audit PDF / archive package     |
|                                      |
|  [ Prepare export               ]    |
|                                      |
|  Nothing is uploaded automatically.  |
|  You choose where the file goes.     |
|                                      |
+--------------------------------------+
```

Then hand off to native Share Sheet.

---

## 44. Delete all data confirmation

```text
+--------------------------------------+
| Delete all LinePay data?             |
+--------------------------------------+
|                                      |
|  This removes pay rules, work logs,  |
|  pay periods, audit history and kept |
|  paystub sources from this iPhone.   |
|                                      |
|  This cannot be undone unless you    |
|  previously exported a backup.       |
|                                      |
|  [ Cancel                       ]    |
|                                      |
|  [ Delete all LinePay data      ]    |
|       destructive styling             |
|                                      |
+--------------------------------------+
```

Do not require typing a phrase unless real testing proves accidental deletion is common.

---

## 45. About / legal

```text
+--------------------------------------+
| < Settings             About LinePay|
+--------------------------------------+
|                                      |
|  LinePay                             |
|  Version 1.0 (build ...)             |
|                                      |
|  LinePay estimates expected pay and  |
|  compares it with facts you confirm. |
|  It is not payroll, legal advice, or |
|  an authority on your agreement.     |
|                                      |
|  > Privacy policy                     |
|  > Terms of use                       |
|  > Open-source acknowledgements       |
|                                      |
|  Bundle                              |
|  com.streamentry.linepay             |
|                                      |
+--------------------------------------+
```

---

# I. Recovery

## 46. Local data recovery screen

Only shown if persisted data cannot be opened safely.

```text
+--------------------------------------+
| LinePay                              |
+--------------------------------------+
|                                      |
|  ! LinePay couldn't open your data   |
|                                      |
|  We won't overwrite it.              |
|                                      |
|  Your existing LinePay data is being |
|  kept while we try a safe recovery.  |
|                                      |
|  [ Try again                    ]    |
|                                      |
|  [ Export recovery copy         ]    |
|                                      |
|  [ Contact support info         ]    |
|                                      |
|  Do not show `Start over` as the     |
|  primary action.                     |
|                                      |
+--------------------------------------+
```

A destructive reset, if ever offered, belongs behind secondary confirmation after recovery/export options.

---

# J. End-to-end happy path

The entire 1.0 product should feel this simple even though the internals are rigorous:

```text
FIRST DAY

[Welcome]
    |
    v
[Pay basics] -> [Pay period] -> [Optional rules] -> [Confirm]
    |
    v
[Today]

AFTER WORK

[Today]
   | \
   |  +--> [Repeat last] --+
   |                        |
   +-----> [Add work] ------+
                            |
                            v
                     Expected pay updates

PAYDAY

[Pay]
  |
  v
[Check paycheck]
  |       |       |       |
 scan    photo    PDF    manual
  \       |       |       /
   +------v-------v------+
          |
          v
     [Review facts]
          |
          v
        [Audit]
     /      |       \
 match   difference  review
     \      |       /
          v
 [Finish pay period]
          |
          v
       [History]

FIRST AUDIT ONLY

[Completed audit]
       |
       +--> optional [Pro offer]

SECOND AUDIT

[Check paycheck]
       |
       v
[Pro required]
```

---

# K. Interaction quality checklist for implementation agents

Before a screen is considered implemented, verify:

1. Is the worker's main fact/action obvious within ~2 seconds?
2. Is there only one dominant primary action in the current region?
3. Is every money value either a source fact or explainable calculation?
4. Can a user correct a mistake without starting over?
5. Are actual worked hours visually distinct from guaranteed/derived paid equivalents?
6. Does uncertainty say `Check` / `Needs review` instead of pretending confidence?
7. Is any manual fallback buried behind automation? If yes, fix it.
8. Could a familiar shift be entered with fewer taps using safe reuse?
9. Does the screen work with large Dynamic Type without hiding critical content?
10. Does VoiceOver describe status and money meaningfully?
11. Is any status communicated by color alone? If yes, fix it.
12. Is a custom card/control replacing a good native iOS control? If yes, justify it.
13. Is there a gradient, glow, decorative dashboard tile, AI sparkle, or fake industrial element? Remove it.
14. If the logo were hidden, would this still feel like LinePay because of ledger structure, vocabulary, precision, and evidence?
15. Does this screen make LinePay materially closer to insanely great?

The desired reaction is not `cool app`.

It is:

> **Yes. That is exactly how my pay works, and I can see why.**
