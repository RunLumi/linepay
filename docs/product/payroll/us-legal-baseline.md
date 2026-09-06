# US lineworker payroll: legal baseline and applicability

[Payroll home](README.md) · [Sources](sources.md) · [Rule catalog](rule-catalog.md) · [Coverage and gaps](coverage-and-gaps.md)

**LAW summaries plus explicitly labeled PRODUCT requirements. Research checked September 6, 2026.** This is not an exhaustive labor-law manual or an assurance of nationwide compliance. Professional review is required before marketing a profile as verifying legal entitlements. Absence from this document does not mean a payment is not required.

## 1. Determine the applicable rule set before calculating

A utility-employed lineworker, an outside-construction contractor's employee, an apprentice, and a public-agency employee need not have the same compensation rules. High compensation alone does not establish a white-collar exemption for manual work; assess actual duties and applicable coverage. [F04](sources.md#f04)

**PRODUCT applicability record:** identify the legal employer; actual work/classification; private/public employment; job jurisdiction; applicable agreement and assent; project requirements; relevant effective dates; wage schedule; statutory workweek; and the meaning of payroll lines. A union local number, job title, home address, or device timezone is not a sufficient selector.

If a necessary legal or contractual context is unknown, calculate only the configured scope and explain what remains unchecked. Do not relabel uncertainty as an opt-out from mandatory law.

## 2. Federal overtime is weekly, not biweekly or universally daily

For covered, nonexempt employees under the ordinary FLSA rule, overtime is due after 40 hours worked in a fixed recurring 168-hour workweek at not less than 1.5 times the regular rate. A pay period cannot average a high-hour week against a low-hour week. Federal law does not by itself make every Saturday, Sunday, holiday, or hour after eight in a day premium work. [F01](sources.md#f01)

**PRODUCT requirements:** store workweek boundaries independently of paycheck dates. Obtain the complete workweek even when a pay period cuts through it. Do not treat `afterHours: 8` daily tiers as the federal weekly check. A simple one-week hourly example is valid only with its stated coverage and pay assumptions.

State/local public-agency employees can have lawful compensatory-time arrangements under prescribed conditions. They require a separate applicability and accounting path, not the ordinary cash-only calculator. Emergency restoration is not itself a police/fire exemption. [F08](sources.md#f08)

## 3. Base rate is not necessarily regular rate

The regular rate is derived from includable remuneration and hours actually worked. Certain exclusions apply, and only specifically qualifying premium compensation may credit statutory overtime. Ordinary shift differentials are not automatically excludable overtime premiums merely because payroll calls them “premium.” [F02](sources.md#f02)

Nondiscretionary bonuses can require allocation to the weeks in which they were earned and additional overtime adjustments. Calling a bonus discretionary does not establish the exclusion. [F05](sources.md#f05)

Multiple-rate calculations and alternative rate-in-effect methods have conditions; do not automatically use the latest, highest, or simple unweighted average rate. Callback guarantees and paid non-work time need separate treatment from worked hours and qualifying premium credits. [F06](sources.md#f06)

**PRODUCT requirements:** distinguish wage components, hours, inclusions, exclusions, credit-eligible premium portions, and unsupported compensation. Do not mark a statutory audit complete without those inputs. The bounded formula in [calculation-spec.md](calculation-spec.md) is not permission to approximate missing components.

## 4. Count work using facts, not payroll labels

Federal hours-worked rules address suffered/permitted work, whether waiting is work, and the constraints of on-call arrangements. Short rest breaks and genuinely duty-free meal periods are treated differently. Ordinary commuting, travel during the workday, special assignments, and overnight travel also have different rules. [F03](sources.md#f03)

**PRODUCT requirements:** an “unpaid break” toggle cannot legally determine compensability. Record duty status, actual interval, and source basis. Preserve disputed periods rather than deleting them. Capture reporting location, directed travel, driver/passenger status, and timing when necessary for a supported travel rule; otherwise flag travel classification as unreviewed. An agreement may separately promise additional travel pay.

## 5. State law and CBAs interact; neither is a universal template

California's general framework includes daily overtime, double time, weekly overtime, and seventh-day provisions, subject to exceptions. Do not infer that framework solely from a worker's home state, or use it nationally. [S01](sources.md#s01)

California Labor Code §514's exception to §§510 and 511 requires a qualifying agreement addressing wages/hours/working conditions, premium overtime rates, and the specified wage threshold. It is not “all union workers are exempt from daily overtime,” and it does not waive federal requirements. [S02](sources.md#s02)

The applicable wage order must also be established; construction-specific Wage Order 16 is an applicability reference, not a universal rule for every utility employee. [S03](sources.md#s03)

**PRODUCT rule:** evaluate independent applicable obligations and their lawful offsets. Neither `max(federal total, state total, CBA total)` nor multiplying every available premium is a universal legal algorithm. Record why each obligation applies, which hours it covers, and which payments legally satisfy or credit it. Unsupported interactions require review.

## 6. Contractual lineworker premiums

The signed California outside-line agreement is an example, not the product's default national rule. Read [C01](sources.md#c01) for its scope, wage-table distinction, and specific clause locators. An isolated callout fixture cannot establish that the engine handles regular-shift overlap, meals, travel, rest, or subsistence exceptions in that agreement.

**PRODUCT requirements:** every rule pack identifies employer/project assent, territory, classification, complete amendment context, exact effective dates, and unresolved variants. Avoid “union verified” or “CBA compliant” unless the stated scope has actual review evidence.

## 7. Per diem: three different questions

Keep these separate: **what the agreement promises**, **how the paycheck reports it**, and **its legal/tax treatment**.

IRS accountable-plan rules involve a business connection, adequate accounting, and return of excess within the applicable requirements. Accountable and nonaccountable reimbursements can be reported differently. This does not establish an employer's obligation to pay a GSA amount, nor decide the FLSA treatment. [T01](sources.md#t01)

**PRODUCT requirements:** use explicit allowance eligibility and gross mapping. A separately reimbursed amount must not become a false missing wage. If regular-rate treatment is unresolved, exclude the statutory conclusion, not quietly the compensation. No take-home tax prediction or “tax-free per diem” promise is part of the basic audit.

## 8. Prevailing wages and fringe benefits

On covered Davis-Bacon/Related Acts projects, basic wage and fringe obligations are distinct; approved benefits or cash treatment require the applicable rules. Classification, incorporated wage determination, and apprentice requirements matter. [P01](sources.md#p01)

**PRODUCT requirements:** identify whether this project is covered and which wage determination applies. CBA wages alone do not certify project compliance. Employer-paid pension/health contributions are not automatically cash gross or deductions from take-home pay. Without a reviewed project/fringe engine, report this coverage as unsupported.

## 9. What this handbook deliberately does not claim

No complete 50-state/local survey; no automatic exemption or independent-contractor determination; no exhaustive municipal-utility rules; no statutory penalties, interest, limitations-period, grievance-deadline, net-tax, garnishment, or legal recovery calculation. These require additional jurisdiction- and date-specific sources and modeling.

A user may still use a limited configured-rules estimate. The display must tell them what was and was not checked. **Correct arithmetic is necessary; correct applicability and complete evidence are separate requirements.**
