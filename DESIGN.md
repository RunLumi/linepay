# LinePay Design System

> **Design thesis:** LinePay should feel like a precision field instrument that happens to live on an iPhone.
>
> Not a fintech dashboard. Not an “AI app.” Not blue-collar cosplay. Not a generic SwiftUI template with orange paint.

This document is the design constitution for LinePay. It applies to product design, visual design, interaction design, copy, screenshots, app icon work, and implementation on iOS and Android.

When a design decision conflicts with this document, either change the design or update this document deliberately. Do not let the visual system drift one screen at a time.

---

## 1. Product feeling

A lineworker opening LinePay should feel, within seconds:

1. **This was made for people who work real hours.**
2. **This thing is precise.**
3. **It will not waste my time.**
4. **My pay data is mine.**
5. **I can trust what I am looking at.**

The desired character is:

- industrial, but not theatrical;
- modern, but not trendy;
- rugged, but not visually noisy;
- dense enough to be useful, but never cramped;
- serious about money, but not corporate;
- distinctly LinePay, while still feeling native on iPhone.

A useful shorthand:

> **Fluke/Klein-level confidence + Apple-level restraint + a clean field notebook.**

This is a metaphor for quality and attitude, not permission to imitate any brand's trade dress.

---

## 2. The visual direction: Precision Industrial Minimalism

Our internal name for the direction is **Precision Industrial Minimalism**.

Its visual ingredients are:

- graphite and porcelain rather than generic white and navy;
- metal-like neutral hierarchy without fake metal textures;
- one restrained oxidized-conductor accent;
- tabular, aligned numbers;
- clear dividers and ledger-like structure;
- modest corner radii;
- almost no decorative shadows;
- native controls where native behavior matters;
- very little ornamental illustration;
- motion that feels mechanical and intentional;
- exact language instead of marketing language.

The UI should resemble a **well-designed instrument panel or job record**, not a moodboard about electricity.

### Do not literalize “industrial”

Never add decorative:

- hazard stripes;
- fake bolts, screws, rivets, diamond plate, carbon fiber, brushed metal, wood grain, or rust;
- lightning-bolt backgrounds;
- hard hats, hooks, bucket trucks, poles, or powerlines merely as decoration;
- faux stencil fonts;
- distressed typography;
- “tough guy” imagery;
- generated photos of workers.

Lineworkers already know what their trade looks like. The app earns credibility through usefulness, vocabulary, precision, and restraint.

---

## 3. Research basis

The system should stay aligned with current platform behavior rather than fight iOS for brand theater.

Apple's current HIG emphasizes purpose, simplicity, craft, hierarchy, consistency, and adapting to users' contexts. It recommends system typography, Dynamic Type, sufficient contrast, semantic color, familiar controls, and restrained use of custom branding.

Primary references:

- Apple HIG, Design principles: https://developer.apple.com/design/human-interface-guidelines/design-principles
- Apple HIG, Color: https://developer.apple.com/design/human-interface-guidelines/color
- Apple HIG, Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Apple HIG, Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple HIG, Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- Apple HIG, App icons: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple SF Symbols: https://developer.apple.com/sf-symbols/
- Apple WWDC26, Communicate your brand identity on iOS: https://developer.apple.com/videos/play/wwdc2026/251/

We also explicitly respect industrial safety-color conventions. OSHA recommends red for danger, yellow for caution, and orange for warning. Those colors therefore should not casually become LinePay's omnipresent brand language.

- OSHA recommended color coding: https://www.osha.gov/laws-regs/regulations/standardnumber/1910/1910.145AppA

Current adjacent pay/time apps tend toward generic finance/time-tracker conventions: white cards, blue/green accents, dashboard grids, and conventional progress components. LinePay should not win by making a prettier version of the same dashboard. It should win by making the **pay evidence itself** feel unusually clear.

Relevant adjacent products:

- LineVault: https://apps.apple.com/us/app/linevault/id6764867679
- Paycheck & OT Estimator: https://apps.apple.com/us/app/paycheck-ot-estimator/id6755323596

---

## 4. Brand principle: quiet identity, not wallpaper

LinePay's identity should be strongest in:

- the app icon;
- the first-run screen;
- the primary action color;
- numeric presentation;
- the discrepancy/audit visualization;
- the language of work and evidence;
- a small recurring **Line Gap** motif defined below.

It should *not* require:

- a logo in every navigation bar;
- a custom font;
- gradients;
- branded card backgrounds;
- custom versions of every system control;
- decorative illustrations on every empty state.

If a screen would stop feeling like LinePay after removing the logo, fix the screen's hierarchy and product language rather than making the logo larger.

---

## 5. Signature motif: The Line Gap

LinePay's core job is to reveal the gap between **what the work should pay** and **what the paycheck says**.

The visual signature should therefore be a simple line interrupted by a precise offset/gap.

Conceptually:

```text
────────────   ────────────
             ↑
           the gap
```

The motif can appear, sparingly, in:

- the app icon;
- the audit comparison view;
- discrepancy markers;
- branded separators in onboarding/marketing;
- export/report covers.

It must never become a decorative pattern.

### Rules for the motif

- 1–2 pt strokes in UI.
- No glow.
- No lightning shape.
- No waveform animation.
- No gradient stroke.
- The gap must correspond to a real concept when used inside product UI.

The Line Gap should become recognizable because it is repeated **rarely and consistently**, not because it covers the product.

---

## 6. Color system

### 6.1 Philosophy

LinePay is predominantly neutral.

Color has four jobs only:

1. brand/interactivity;
2. status;
3. focus/selection;
4. limited visualization.

Never use color simply because an area feels empty.

Use semantic color assets rather than hard-coded hex values in feature code. Every custom color requires light, dark, and increased-contrast consideration.

### 6.2 Reference palette

These values are design references. Implementation must use named semantic assets/tokens.

| Token | Light reference | Dark reference | Meaning |
|---|---:|---:|---|
| `canvas` | `#F4F1E8` | `#111417` | Porcelain / graphite base |
| `surface.primary` | `#FBFAF6` | `#1A1F23` | Main raised content surface |
| `surface.secondary` | `#E9E5DB` | `#22282C` | Secondary grouping |
| `text.primary` | `#13171A` | `#F4F1E8` | Primary content |
| `text.secondary` | `#5C6468` | system secondary label | Secondary content |
| `line.subtle` | system separator | system separator | Structural divider |
| `brand.primary` | `#0E746C` | `#55C9BE` | **Oxide**, primary interaction/brand |
| `brand.copper` | `#A94E25` | `#E48A59` | Rare material accent, not status |

### 6.3 Why Oxide

The primary brand color is a restrained copper-oxide teal rather than neon blue, purple, or safety orange.

It gives LinePay a material/electrical character without screaming “electricity app.” It also avoids making OSHA-style warning colors our normal interaction language.

The reference pairs were selected to support strong text/background contrast in their intended modes. Still test the real UI with Accessibility Inspector. Do not treat hex values as a substitute for accessibility testing.

### 6.4 Copper is a signature accent, not a second primary color

`brand.copper` may appear in tiny brand moments such as:

- the app icon;
- the Line Gap mark;
- a 1–2 pt detail line;
- a marketing screenshot annotation.

It should **not** color every button, icon, card, and heading.

A normal product screen should often contain no copper at all.

### 6.5 Semantic status colors

Status colors are separate from brand colors.

Prefer system semantic colors so they adapt to appearance and accessibility settings.

| State | Color family | Required non-color cue |
|---|---|---|
| Confirmed match | system green | checkmark + “Matches” |
| Possible shortfall | system red | discrepancy icon + amount + text |
| Needs confirmation | system yellow/orange | triangle/question + “Review” |
| Informational | system blue | info symbol + text |
| Unknown/not evaluated | gray | explicit label |

**Never communicate a pay state with color alone.**

Do not use green merely because a number is positive. An employer overpayment, for example, is not automatically “good.” Status follows meaning, not arithmetic sign.

### 6.6 Contrast requirements

At minimum:

- normal text: WCAG AA 4.5:1;
- large/bold text: 3:1;
- meaningful non-text controls/state boundaries: target 3:1;
- test light mode, dark mode, Increase Contrast, and Reduce Transparency combinations.

Apple explicitly notes that lighting conditions can affect usability. Assume LinePay may be opened in bright daylight, inside a truck, or at night.

### 6.7 Forbidden color behavior

Do not use:

- blue-purple gradients;
- rainbow charts;
- glow/neon;
- low-contrast gray-on-gray because it looks “premium”;
- translucent colored cards stacked on colored backgrounds;
- red/yellow/orange as general brand decoration;
- green for all money;
- different arbitrary colors for every pay category.

---

## 7. Light and dark appearance

Support both from the beginning.

### Light mode

Light mode should feel like **porcelain, paper, and machined labeling**, not sterile white SaaS.

- warm near-white canvas;
- nearly-black text;
- subtle neutral surfaces;
- strong outdoor legibility;
- Oxide as the main action color.

### Dark mode

Dark mode should feel like **graphite equipment in a truck cab**, not gamer UI.

- charcoal, not a sea of pure OLED black;
- no neon glow;
- no blue-purple gradients;
- raised surfaces separated mostly by tone and dividers;
- brighter Oxide for interactive emphasis;
- copper used even more sparingly.

Follow the system appearance by default. Do not add a custom theme selector until users ask for it.

---

## 8. Typography

### 8.1 Use the system font

Use SF Pro through SwiftUI's system text styles on iOS.

Do **not** ship a custom display font in v1.

Reasons:

- Dynamic Type works correctly;
- Bold Text and accessibility behavior are stronger;
- system typography survives OS changes better;
- it looks like a serious tool rather than a branded landing page;
- custom typography is not where LinePay earns differentiation.

Apple recommends avoiding light weights for legibility. LinePay uses Regular, Medium, Semibold, and Bold only.

### 8.2 Numeric typography is part of the brand

Money, hours, rates, and deltas should use tabular/monospaced digits where alignment matters.

SwiftUI example:

```swift
Text(amount.formatted(.currency(code: "USD")))
    .font(.title.bold())
    .monospacedDigit()
```

Numbers should feel stable when changing. A total should not visually jitter from `$998` to `$1,004`.

### 8.3 Type hierarchy

Prefer system semantic styles rather than a large custom type scale.

| Purpose | Preferred style |
|---|---|
| One focal amount | `.largeTitle` or `.title` + bold/semibold |
| Screen title | navigation title/system convention |
| Section title | `.headline` |
| Primary row | `.body` / `.headline` |
| Secondary value | `.subheadline` |
| Metadata/source | `.caption` / `.footnote` |
| Rule identifiers | `.caption.monospaced()` sparingly |

### 8.4 One giant number rule

A screen gets **at most one** oversized numeric focal point.

Bad:

```text
$7,421     84.5h     $453     17.3h
BIG        BIG       BIG      BIG
```

Good:

```text
Expected this period
$7,421.80

84.5 hours · 17.3 OT
Possible difference: $453.60
```

Hierarchy communicates confidence.

### 8.5 Copy casing

- Sentence case by default.
- Avoid decorative ALL CAPS.
- A short technical code such as `OT2` may be uppercase because the domain uses it.
- Never uppercase entire buttons or section headers to manufacture an “industrial” feeling.

---

## 9. Layout and spacing

Use an 8 pt rhythm with 4 pt half-steps where needed.

Reference tokens:

```text
space.1 = 4
space.2 = 8
space.3 = 12
space.4 = 16
space.5 = 24
space.6 = 32
space.7 = 48
```

### Screen margins

- Typical compact iPhone horizontal content inset: 16–20 pt.
- Respect system safe areas.
- Prefer full-width structured sections over many floating cards.

### Density

LinePay is a work tool. It can be denser than a wellness app.

Dense does not mean tiny.

Prefer:

- rows;
- aligned columns;
- sections;
- dividers;
- disclosure;

instead of giving every fact a separate rounded rectangle.

---

## 10. Shape language

### Corner radius

Rounded corners are functional, not decoration.

Reference:

- compact chips/badges: 6–8 pt;
- content panels: 10–12 pt;
- primary buttons: system button shape or ~12 pt;
- sheets/navigation: let the system own the container geometry.

Avoid 20–32 pt “soft SaaS card” radii.

### Borders and separators

LinePay prefers **structure over elevation**.

Use:

- system separators;
- 1 px / hairline boundaries;
- tonal surface changes;
- whitespace.

Avoid stacked shadows.

### Shadows

Default: none.

Use a shadow only when hierarchy actually requires physical elevation and a native system material does not already solve it.

---

## 11. Materials and Liquid Glass

On current iOS, let standard navigation and controls adopt system Liquid Glass behavior naturally.

Apple's HIG specifically advises against using Liquid Glass throughout the content layer.

Therefore:

- navigation bars/toolbars/tab bars: system behavior;
- menus/buttons where the system provides the material: system behavior;
- **content cards, pay rows, totals, audit panels: do not turn them into glass**;
- no manually blurred glass-card dashboard;
- no translucent “frosted” paystub cells.

This is both a platform rule and an anti-slop rule.

---

## 12. Controls: field-ready, not glove-certified

Apple's default iOS control target is 44×44 pt. For LinePay's frequent actions, target larger when layout permits.

Recommended:

- primary action height: 52–56 pt;
- common row tap target: >= 48 pt;
- icon-only button hit area: >= 44×44 pt;
- generous separation between destructive and confirm actions.

LinePay should remain easy to operate with cold/tired hands or while standing beside a truck.

Do **not** claim the app works with electrical rubber gloves. Capacitive behavior depends on the glove/device setup. We design for forgiving motor interaction, not a safety certification.

### Primary actions

At most one visually dominant primary action in a region.

Examples:

- `Add work`
- `Review paystub`
- `Confirm hours`

Avoid competing primary buttons.

### Destructive actions

Use system destructive styling and explicit nouns:

- `Delete pay period`
- `Remove paystub`

Never `Yes, delete` without naming what disappears.

---

## 13. Navigation

Use predictable iOS navigation before inventing custom chrome.

Probable core information architecture:

```text
Today / Pay Period
History
Rules
Settings
```

Do not finalize tab count because a design document says so. The product workflow decides.

### Navigation principles

- Put the current task before brand decoration.
- Avoid hamburger menus on iPhone.
- Avoid a custom bottom dock that imitates a tab bar.
- Avoid permanently visible actions that are irrelevant to most screens.
- Prefer a system sheet for focused creation/editing flows.

---

## 14. The core LinePay visual object: the Pay Ledger

The most distinctive UI should not be a dashboard card. It should be a **pay ledger**.

A pay calculation needs to communicate:

```text
what happened
× what rule/rate applied
= what it should pay
→ why
```

A row might conceptually look like:

```text
REGULAR                              $464.00
8.0 h × $58.00

DOUBLE TIME                          $464.00
4.0 h × $58.00 × 2.0
Callout minimum · Rule 7.4          [source]
```

Use alignment, typography, and dividers rather than decorative cards.

### Ledger rules

- Amounts align on the trailing edge.
- Hours and rates use monospaced digits where useful.
- Every non-obvious calculation can disclose its rule/evidence.
- Rows can expand, but the collapsed state remains scannable.
- Derived totals never obscure raw hours.
- `OT1`, `OT2`, callout, per diem, travel, etc. use the language users recognize.

This ledger should become more visually ownable than any generic chart.

---

## 15. Audit / discrepancy design

This is LinePay's “wow” screen.

It must make a discrepancy understandable in under five seconds.

### Primary comparison

```text
EXPECTED                         PAID
$7,421.80                    $6,968.20

        POSSIBLE SHORTFALL
            $453.60
```

Then show the reasons, not a confetti chart:

```text
Possible missing callout minimum       $232.00
Possible missing rest-period pay       $221.60
```

Each discrepancy opens into:

1. work facts;
2. applied rule;
3. calculation;
4. paystub fact;
5. source/evidence;
6. confidence/confirmation state.

### Visual rule

The discrepancy is not a “score.”

Do not use:

- circular gauges;
- health-score metaphors;
- AI confidence stars;
- celebratory confetti when pay matches;
- scary animation when it does not.

Money discrepancy is serious. Calm clarity is the delight.

### Uncertainty

If OCR or rule matching is uncertain, show it directly:

> **Needs confirmation**
> Paystub rate may read `$58.80`. Check the highlighted field.

Show the source crop or source line when possible.

Never hide uncertainty behind a magic wand icon.

---

## 16. Data visualization

Default to tables, aligned rows, bars, and timelines before charts.

Acceptable:

- horizontal progress toward pay-period hours;
- compact stacked hour bar (regular / OT / DT) if labels remain clear;
- timeline of shifts;
- expected-vs-paid comparison bar;
- historical trend line where time actually matters.

Avoid:

- donut charts;
- radial gauges;
- 3D charts;
- five-color stacked cards;
- gratuitous sparklines;
- pie charts for pay composition when a ledger is clearer.

Every chart must answer a real question faster than text would.

---

## 17. Icons

Use SF Symbols first on iOS.

Reasons:

- correct optical weights;
- Dynamic Type behavior;
- accessibility support;
- localization/RTL behavior;
- consistency with native controls.

Use monochrome or hierarchical rendering most of the time.

### Custom icon rule

Create a custom symbol only when the concept is LinePay-specific and no SF Symbol communicates it accurately.

Potential custom symbol:

- Line Gap / discrepancy mark.

### Forbidden icon clichés

Do not use these as the primary LinePay identity:

- lightning bolt;
- robot head;
- sparkle/star for “AI”;
- generic dollar sign;
- hard hat;
- shield-with-check as generic “trust” decoration;
- bank building;
- crypto-style hexagon.

A symbol must communicate function before personality.

---

## 18. App icon direction

The icon should be recognizable at a glance without becoming a cartoon trade logo.

### Preferred concept

**Graphite field + Line Gap mark**

- graphite dominant field;
- porcelain/light conductor line;
- one small Oxide or copper element;
- 2–3 geometric elements maximum;
- no text;
- no `$`;
- no lightning bolt;
- no detailed pole illustration.

The mark may suggest a line/conductor and an offset gap without literally drawing electrical infrastructure.

Use Apple's Icon Composer/Liquid Glass icon workflow when preparing production assets, but do not turn the icon into translucent layer soup.

Test at:

- Home Screen size;
- Spotlight/Search;
- notification/settings sizes;
- dark/tinted/clear system appearances where applicable.

---

## 19. Motion

Motion communicates state and causality.

LinePay motion should feel **mechanical, quick, and quiet**.

Reference behavior:

- small state transition: ~120–180 ms;
- sheet/navigation: system animation;
- expanding calculation details: restrained ease;
- number updates: subtle content transition if it improves continuity;
- success: haptic + state change, not celebration theater.

Avoid:

- springy cards;
- bouncing primary buttons;
- looping gradients;
- shimmer outside true loading states;
- animated background lines;
- confetti;
- parallax decoration;
- dramatic count-up animation for money.

Respect Reduce Motion.

---

## 20. Haptics

Use haptics as confirmation, not seasoning.

Good candidates:

- a work entry successfully saved;
- a rule confirmation committed;
- a paystub field confirmed;
- an audit completed;
- destructive action confirmed.

Do not haptic every tap.

A possible discrepancy should not trigger an alarm-like haptic. The user needs information, not adrenaline.

---

## 21. Content and voice

LinePay speaks like a competent coworker who is careful with numbers.

### Voice qualities

- direct;
- plain;
- specific;
- calm;
- respectful;
- short.

### Preferred domain language

Use words workers use:

- pay period;
- shift;
- regular;
- overtime / OT;
- double time / DT where appropriate;
- callout;
- standby;
- per diem;
- travel;
- rate;
- agreement;
- rule;
- paystub;
- expected pay;
- possible difference / possible shortfall.

Avoid startup/product language:

- “unlock insights”;
- “optimize your earnings”;
- “AI-powered intelligence”;
- “financial wellness”;
- “journey”;
- “supercharge”;
- “magic”;
- “smart pay assistant.”

### Never overclaim

Use:

- `Expected pay`
- `Possible shortfall`
- `Based on the rules you confirmed`
- `Needs confirmation`

Avoid:

- `Your employer owes you $453.60`
- `We found wage theft`
- `Guaranteed missing pay`

---

## 22. Empty states

Empty states should get the user to the first useful action.

They do not need illustrations.

Bad:

> [3D floating paycheck illustration]
> **Nothing here yet!**
> Your financial journey starts here ✨

Good:

> **No work logged this pay period**
> Add today's hours to start calculating expected pay.
>
> `Add work`

One useful sentence, one action.

---

## 23. First-run experience

The first screen must not be an empty dashboard.

Recommended emotional sequence:

### Screen 1

> **Know what your work should pay.**
>
> LinePay uses the work and pay rules you confirm to estimate your check. Your pay data stays on your phone.
>
> `Set up my pay`
>
> `Try a sample pay period`

Visually:

- strong typography;
- huge whitespace;
- one small Line Gap brand detail;
- no illustration carousel;
- no account creation;
- no permission wall.

### Setup philosophy

Ask only what is required to calculate the first useful result.

Do not build a seven-screen onboarding tour explaining features the user has not experienced.

Progress should feel like completing a job setup, not filling a SaaS CRM form.

### First “aha”

The first meaningful delight should be:

> **“Yes. That is how my pay actually works.”**

not an animation.

---

## 24. Paystub/OCR interface

Scanning is evidence capture, not magic.

### Scanner behavior

- use familiar native camera/document interaction;
- dark surrounding chrome when scanning improves focus;
- immediately show what was recognized;
- visually distinguish confirmed vs unconfirmed fields;
- allow tapping a parsed value to see its original source region;
- make correction faster than rescanning.

### OCR presentation

Do not say:

> `AI analyzed your paycheck ✨`

Say:

> `Check these 2 fields`

or:

> `We could not confidently read the overtime rate.`

The UI must reveal the boundary between machine extraction and user-confirmed fact.

---

## 25. Privacy presentation

Privacy is a product characteristic, not a green shield badge.

Good places to communicate it:

- first run;
- scanner permission context;
- Settings > Privacy;
- paystub screen footer/info;
- App Store screenshots.

Preferred phrasing:

> **Your paycheck stays on your phone.**

Follow with concrete details when needed:

> No LinePay account. No employer connection. No paystub upload to a LinePay server.

Avoid vague claims such as “military-grade privacy.”

---

## 26. Accessibility is part of the aesthetic

A field tool that becomes hard to read in sunlight or at larger text sizes is badly designed.

Required from the first feature:

- Dynamic Type;
- VoiceOver labels and sensible reading order;
- Bold Text support;
- Increase Contrast testing;
- Reduce Transparency testing;
- Reduce Motion testing;
- no meaning conveyed by color alone;
- large enough touch targets;
- landscape/layout stress tests where relevant;
- real-device review outdoors before release.

### Large text behavior

When text gets large:

- rows may grow vertically;
- trailing amounts may move beneath labels;
- controls may stack;
- information must not disappear merely to preserve a compact visual.

Do not lock important screens into fixed heights.

---

## 27. “No AI slop” rules

This section is intentionally explicit. AI-assisted implementation must not regress LinePay into the statistical average of current app screenshots.

### Never generate by default

- gradient hero backgrounds;
- purple/blue glow;
- glowing cards;
- glass content cards;
- 24–32 pt pill cards everywhere;
- icon + tiny uppercase eyebrow + huge number repeated in a 2×2 dashboard;
- three gradients to communicate three pay categories;
- meaningless sparkles;
- “AI” badges;
- chat bubbles for non-chat workflows;
- generic dashboard greetings such as `Good morning, James`;
- motivational money quotes;
- giant donut charts;
- soft 3D illustrations;
- generated worker portraits;
- fake testimonials inside the app;
- endless chips/tags;
- decorative waveforms;
- floating action buttons that ignore iOS conventions;
- hamburger menus on iPhone;
- custom nav bars merely to look branded;
- emoji as production navigation icons;
- excessive blur;
- skeleton loading when data is already local;
- optimistic “success” green for uncertain calculations.

### The AI-slop smell test

Before accepting a screen, ask:

> If the logo and words were blurred, could this screenshot be from any AI finance, habit, crypto, fitness, or time-tracking app?

If yes, redesign it.

LinePay should be recognizable from:

- the ledger structure;
- numeric typography;
- the Line Gap comparison;
- porcelain/graphite/Oxide palette;
- domain vocabulary;
- restrained density;
- evidence-first interactions.

---

## 28. Component philosophy

Do not create a design-system component because one view used a style twice.

Start with SwiftUI/system components and semantic tokens.

Extract a reusable component when:

- the interaction semantics repeat;
- accessibility behavior repeats;
- visual consistency matters across several features;
- the component has a stable domain meaning.

Likely LinePay-specific components later:

- `MoneyAmount`
- `PayLedgerRow`
- `PayComponentRow`
- `DiscrepancyRow`
- `EvidenceLink`
- `ConfirmationState`
- `RuleReference`
- `ExpectedVsPaid`

Avoid generic abstractions such as:

- `FancyCard`
- `GradientPanel`
- `UniversalTile`
- `CustomButtonStyle42`

Domain components are easier to reason about than aesthetic Lego.

---

## 29. Semantic design tokens

Keep tokens semantic, not literal.

Good:

```text
color.canvas
color.surface.primary
color.text.primary
color.action.primary
color.status.review
space.section
radius.panel
```

Bad:

```text
color.teal500
color.gray200
space24ForCards
radiusPretty
```

The design system must be portable in concept to Android even though implementations remain native.

### Initial token categories

```text
Color
Typography
Spacing
Radius
Stroke
Motion
Haptic
Layout
```

Do not create a giant token framework before the product needs one.

---

## 30. iOS implementation guidance

### Prefer

- SwiftUI native navigation;
- semantic `Color` assets;
- SF Symbols;
- Dynamic Type styles;
- `.monospacedDigit()` for aligned numeric values;
- native sheets, menus, pickers, toggles, text fields;
- system keyboard types for numeric/currency input;
- `ContentUnavailableView` only when it suits the LinePay copy and hierarchy;
- Accessibility Inspector during feature development, not just release week.

### Avoid

- hard-coded font sizes for core content;
- hard-coded raw RGB values inside feature views;
- custom controls that replicate system controls;
- custom navigation infrastructure in v1;
- global appearance hacks;
- UIKit wrappers solely to customize aesthetics already available in SwiftUI;
- custom material/blur layers around every section.

---

## 31. Android translation later

Android should share the **design language and semantic tokens**, not pixel-copy iOS.

When Android exists:

- use Jetpack Compose and Android-native navigation/controls;
- preserve LinePay's hierarchy, colors, ledger, Line Gap, and numeric behavior;
- adapt platform chrome to Android conventions;
- do not force iOS Liquid Glass or iOS navigation metaphors onto Android.

Cross-platform consistency means the same product character and information architecture, not identical screenshots.

---

## 32. Screenshot / App Store direction

App Store screenshots should look like evidence, not ads generated from a Figma template.

Preferred sequence:

1. **Know what your work should pay** — real pay-period ledger.
2. **Spot possible missing pay** — expected vs paid audit.
3. **Built for real overtime rules** — callout/OT/DT breakdown.
4. **Scan your paystub on-device** — source-confirmation view.
5. **Your paycheck stays on your phone** — privacy proof points.

Use short copy and large product UI.

Avoid:

- fake floating 3D iPhones;
- five colored gradient backgrounds;
- generated lineworker imagery;
- giant marketing paragraphs;
- fake chat conversations;
- “Powered by AI.”

The product itself should be the visual.

---

## 33. Design QA checklist

Before merging a user-facing screen, review all of these.

### Product

- What is the one job of this screen?
- Is the most important fact/action obvious within ~2 seconds?
- Does every visible element earn its space?
- Are we using actual linework/pay vocabulary?
- Are uncertainty and evidence visible where they matter?

### Visual

- Is there one clear focal point?
- Did we use a row/divider when a card was unnecessary?
- Did we accidentally introduce another arbitrary color?
- Are corner radii restrained?
- Is branding quiet?
- Does the screen still look distinctive without a logo?

### Accessibility

- Dynamic Type through accessibility sizes?
- VoiceOver order and labels?
- 4.5:1 normal text contrast where applicable?
- meaningful controls/states sufficiently differentiated?
- color-independent state cue?
- >=44 pt touch target, preferably larger for frequent field actions?
- dark + light + Increase Contrast checked?

### Anti-slop

- Any gradient?
- Any decorative glow?
- Any generic dashboard tile grid?
- Any unnecessary glass content card?
- Any sparkle/AI/magic language?
- Any visual cliché pretending to make the app “for linemen”?

If any answer is uncomfortable, fix it before polishing.

---

## 34. Design review scorecard

Score proposed major screens from 1–5 on each dimension:

| Dimension | Question |
|---|---|
| Clarity | Can a tired user understand the screen immediately? |
| Trust | Does the UI show where numbers came from? |
| Field usability | Is it readable and tappable in imperfect conditions? |
| Native quality | Does it behave like a first-class iOS app? |
| Distinctiveness | Could it be recognized without the logo? |
| Restraint | Did we remove decorative/nonessential UI? |
| Domain truth | Does it reflect how workers actually talk about pay? |
| Accessibility | Does the experience survive real accessibility settings? |

A major screen should not ship with any dimension below **4** without an explicit reason.

---

## 35. The standard to hold

The goal is not:

> “This looks cool for an indie app.”

The goal is:

> **“This feels like a tool somebody cared enough to get exactly right.”**

LinePay should earn affection the way a good field tool does: it is immediately understandable, comfortable to use, dependable under pressure, and better every time you notice a detail.

When tempted to add personality, first ask whether we can create more personality through **precision**.

That is the LinePay design language.
