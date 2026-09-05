# LinePaycheck — Logo and App Icon

> **A recognizable instrument mark, not an illustration of the trade.**
>
> Two deliberate line segments. One readable interruption. A name that remains easy to read.

**Version:** 1.0 · **Platform references checked:** September 5, 2026  
**Status:** Production specification. The construction below is a design starting point, not approved final artwork, a trademark clearance, or a completed audience test.

## 1. The decision in one minute

| Element | Direction |
|---|---|
| Public name | **LinePaycheck**, with this exact spelling and capitalization |
| Core symbol | The **Line Gap** already established in `DESIGN.md` |
| App icon | Graphite field; strong porcelain mark; one small Oxide detail |
| Wordmark | Clear, carefully spaced lettering; no electrical tricks inside the name |
| Character | Precise, capable, calm, personal; industrial without costume |
| Recognition | Unequal line lengths, controlled offset, generous negative space |
| Platform strategy | One identity, platform-specific icon assets |
| First test | Does the silhouette remain recognizable at actual small sizes? |
| Non-goal | Communicating every feature, trade, and benefit inside one tiny icon |

The symbol provides recognition. The name and store subtitle explain the product. Do not force the icon to depict a paycheck, power pole, calculator, checkmark, and dollar sign simultaneously.

### Document boundaries

- [Design system](../../DESIGN.md) owns the palette, product character, and interaction language.
- [App Store playbook](../appstore.md) owns listing metadata and positioning.
- [Screenshot production](app-stores/screenshots.md) owns store-image execution.
- [Agent contract](../../AGENTS.md) owns technical identity. Keep `com.streamentry.linepay`, `LinePay`, `LinePayDomain`, and existing purchase identifiers unchanged.
- This document owns identity artwork and its production/acceptance rules. It does not add runtime features, alternate-icon settings, or a new font dependency.

## 2. What makes the identity specific to this product

The Line Gap connects to a real product question: **does the paycheck match the recorded work?** Its restrained geometry belongs beside an aligned ledger and an exact numerical comparison.

The mark is not a warning light. It must not suggest that every paycheck is wrong, that the app has detected a fault, or that a union has certified a claim.

Three characteristics should survive without color:

1. A long and a short horizontal element, rather than two identical bars.
2. A clean interruption with enough space to survive reduction.
3. A modest offset that looks intentional, not like a damaged export.

Do not claim that this construction is globally unique. Before approval, compare the rendered candidate against actual adjacent pay, banking, utility, and infrastructure identities. Distinctive intent is not evidence of exclusive rights.

### The strongest design risk

An oversimplified Line Gap can become a generic minus sign, an equals sign, or a broken-connection indicator. More decoration is not the remedy. Test the proportions and context; reject a candidate that repeatedly creates the wrong association.

A worker does not need to decode the metaphor unaided. They do need to recognize the same app the next time they see it.

## 3. Construction: a controlled starting point

These dimensions are **our exploratory construction**, not an Apple template or a validated final logo. Start here, inspect at small sizes, then record any optical refinements in the approved source.

### 3.1 Large icon master

Use a `1024 × 1024` coordinate system with an origin at the upper-left:

| Shape | Geometry in source units |
|---|---|
| Background | Full square, `0,0` to `1024,1024` |
| Long segment | `x=208`, `y=464`, `width=352`, `height=96` |
| Short segment | `x=616`, `y=432`, `width=200`, `height=96` |
| Segment corner radius | Start at `12`; subtle softening, not a capsule |
| Clear horizontal interruption | `56` units between the segments |
| Vertical offset | `32` units; short segment sits slightly higher |
| Optional identity accent | Last `24` units of the long segment, clipped inside its existing silhouette |

The combined horizontal extent is `608` units, centered on the square. Its vertical center is slightly above the mathematical center. Treat that as an optical starting point, not a rule that overrides an actual rendered comparison.

Both structural segments use the same base ink. The optional accent occupies a small portion of the existing long segment; it is not a third floating dot, spark, or bridge across the gap.

### 3.2 What may change during refinement

Adjust stroke thickness, gap, offset, corner softness, and optical position as a related system. Produce at most three close candidates from this concept before reviewing them.

Do not simultaneously change the metaphor, palette, wordmark, and icon container. That makes feedback uninterpretable.

If the thin horizontal silhouette disappears in the Home Screen grid, increase its optical weight before adding detail. If it still fails recognition, revisit the construction rather than declaring the first coordinates sacred.

### 3.3 Small-size compensation

The icon master is not the same drawing as a one-pixel interface separator.

- Inspect exported appearances at `16`, `24`, `32`, `40`, `60`, and `120` pixels as stress tests. These are QA sizes, not a replacement for platform asset slots.
- At the smallest sizes, keep the interruption at least one clearly visible raster pixel; preferably more when the available area allows it.
- Remove the optional accent before sacrificing the structural gap.
- Align straight edges to the output grid where practical; do not blur the whole symbol to hide poor rasterization.
- Do not give the small-size version a new silhouette or reverse the segment lengths.
- Review exports at 100% display scale, not only enlarged on a design canvas.

The apparent weight of both fragments should match. A mathematically identical fill can still look uneven after masking, scaling, and system lighting.

## 4. Color and monochrome behavior

Use the semantic palette in `DESIGN.md`; these are the identity-specific applications:

| Use | Field | Structural mark | Optional accent |
|---|---|---|---|
| Default app-icon concept | Graphite `#111417` | Porcelain `#F4F1E8` | Oxide `#55C9BE` |
| Light editorial background | Porcelain `#F4F1E8` | Graphite `#13171A` | Dark Oxide `#0B6D66` |
| Dark editorial background | Graphite `#111417` | Porcelain `#F4F1E8` | Oxide `#55C9BE` |
| One-ink identity | Transparent or plain field | One contrasting ink | Omitted |
| Tinted/themed icon | Platform-resolved | Consistent monochrome silhouette | Merged or omitted |

Do not alternate randomly between copper and Oxide in production. **Oxide is the default icon accent.** Copper remains an optional, deliberately approved identity treatment from the parent design system, not a second highlight to add alongside it.

Recognition must survive the accent disappearing. Never encode paid status, audit success, or a suspected shortfall in the logo's hue.

The two main inks should remain strongly separated in the real system preview. A contrast check on the flat vector cannot certify the appearance after transparency, lighting, wallpaper, and masking are applied.

## 5. Wordmark: readable before clever

Always write **LinePaycheck**. Do not introduce `LinePay Check`, `LINEPAYCHECK`, `LinePayCheck`, or a split-color spelling that makes the name look like two competing products.

### Recommended production starting point

Use **Inter SemiBold, weight 600**, as the starting type for the standalone wordmark and cross-platform marketing lettering. Inter's publisher provides it under the SIL Open Font License; verify the license accompanying the exact source version used. [L6]

This is an artwork choice, not an instruction to replace native iOS or Android interface fonts. In-app text remains native. The approved wordmark may be delivered as outlined vector artwork, without bundling a font into the app.

Refine by eye:

- Preserve ordinary, readable letterforms.
- Check the spacing around `Line`, `Pay`, and `check` without visually splitting the name.
- Start with the font's spacing; tighten only where the actual lockup needs it.
- Never horizontally compress the name to fit a slot.
- Do not cut a lightning bolt into the `L`, replace a letter with a checkmark, or remove counters for a stencil effect.
- Keep an editable source with font/version information, and export an outlined distribution copy.

An outlined wordmark avoids layout dependence on an installed font. It does not remove licensing responsibilities.

## 6. Lockups and clear space

Use the simplest approved lockup appropriate to the surface:

| Surface | Preferred identity |
|---|---|
| Home Screen / store icon | Symbol inside the platform icon field; no text |
| Website or support header | Wordmark alone, or restrained horizontal lockup |
| Onboarding | Product name plus a small Line Gap; not a giant logo splash |
| Report cover | Wordmark with the small mark and document title clearly separate |
| Small footer | Wordmark alone; omit the tagline |
| Social avatar | App-icon version, not tiny wordmark text |
| Product evidence screen | Normally no logo; let the data occupy the space |

Use at least one segment thickness of clear space around the standalone symbol. Around a wordmark or combined lockup, start with half the capital-letter height and increase it when neighboring content competes.

For a horizontal lockup, optically balance the low, wide mark with the lettering; do not force the symbol to equal the full wordmark height. Prefer a wordmark-only header over an awkward oversized emblem.

At small sizes, remove the tagline first, then use wordmark-only or icon-only. Do not shrink an entire presentation lockup until the name becomes unreadable.

`Check every paycheck.` is optional supporting copy. It is not permanently attached to the icon or squeezed beneath the wordmark in navigation.

## 7. iOS app icon: modern without baked-in effects

Apple's current icon guidance uses a `1024 × 1024` layered source for iOS, with system masking and multiple appearances. Maintain consistent core features across default, dark, clear, and tinted presentations. [L1]

### Production workflow

1. Finish the flat silhouette before applying material effects.
2. Import clean vector foreground geometry into **Icon Composer**.
3. Use a full-bleed background and a minimal set of foreground layers/groups.
4. Tune supported system effects gently; check the interruption under lighting and appearance changes.
5. Inspect the resulting icon in system context and integrate the approved source through the project's existing build configuration.

Apple recommends clearly defined foreground edges and vector source; Icon Composer supports composition and appearance previews. [L1, L2]

### LinePaycheck-specific constraints

- Keep the two line fragments in one coherent optical plane unless a tested reason justifies separation.
- Do not add heavy refraction, internal blur, or layered shadows that close the gap or split the mark into unrelated pieces.
- Do not pre-render an outer rounded-square mask into the master.
- Do not bake system shine, external shadows, or a fake glass tile into the flat vector.
- Transparent foreground layers are appropriate; that does not mean the flattened marketing icon should have accidental transparent corners.
- The production screenshot uses the icon as the system renders it, not an invented brighter promotional version.

### Appearance and compatibility acceptance

Check default, dark, clear-light, clear-dark, tinted-light, and tinted-dark where supported by the current system. Also inspect the compiled fallback on the project's **iOS 18 minimum**. Newer icon tooling is not proof that older-device output is correct.

Use the supported Xcode/Icon Composer integration for the chosen toolchain. Verify the archive and installed app; do not hand-invent asset names or assume a PNG dropped into the repository is automatically the shipped icon.

One identity is enough for launch. Do not add user-selectable alternate icons merely to demonstrate the design system.

## 8. Android later: two deliverables, not one resized Apple export

### Google Play listing icon

Google specifies **512 × 512**, **32-bit PNG**, **sRGB**, and a maximum **1024 KB** file size. Submit a full square without pre-applied outer rounding or drop shadow; Play supplies those treatments. [L4]

For LinePaycheck, use an opaque graphite field and the same flat mark. Do not export an Apple-rendered glass icon and reuse its baked lighting or mask as the Play source.

### Android launcher icon

Prepare separate adaptive foreground/background layers and a monochrome layer. Android specifies a `108 × 108 dp` layer canvas with a central `66 × 66 dp` safe region for essential content. Test circular and other launcher masks, including themed presentation. [L5]

Recompose the mark to the adaptive-icon template and keylines. Do not map the Apple canvas edge directly to the launcher safe region or stretch the wide symbol into a square. Preserve its proportions and check optical size under real masks.

Android implementation remains future scope. This specification does not claim that Android assets or an Android app already exist.

## 9. Originality and rights are production gates

Apple explicitly prohibits using SF Symbols, or confusingly similar glyphs, for app icons, logos, or other trademark uses. SF Symbols remain appropriate for ordinary supported in-app interface roles. [L3]

Therefore the Line Gap must be original geometry, not an exported or modified system glyph used as a brand shortcut.

Before approving artwork:

- Record who created it, its source files, and any licensed inputs.
- Compare against relevant app icons and existing marks; examine silhouette, not just colors.
- Do not borrow a utility's insignia, union emblem, equipment maker's trade dress, or a bank's mark.
- Keep license/version records for type or third-party assets actually used.
- Do not label the logo registered, trademark-cleared, or legally exclusive without the appropriate confirmation.

Image-generation output, when used for exploratory concepts, is not final vector artwork or a rights check. Rebuild the chosen geometry deliberately and run the same similarity and craft review. Do not use generated lettering or raster-to-vector noise as a production wordmark.

## 10. Quality review: observable, not a beauty score

| Test | Acceptance condition |
|---|---|
| Silhouette | Both fragments and their interruption remain recognizable without color |
| Small-size test | No disappearing gap, clipped fragment, fuzzy seam, or illegible name |
| Context | Icon can be located beside ordinary apps on both light and dark backgrounds |
| Appearance | Core geometry stays consistent across supported system presentations |
| Semantic risk | No repeated strong interpretation as a warning, disconnection, or certification badge |
| Wordmark | Readers reproduce `LinePaycheck` without being coached about its spelling |
| Product continuity | Icon, welcome, store listing, and report look like one product |
| Rights | Original source and relevant licenses documented; no borrowed system logo |
| Build output | Approved artwork is the artwork actually installed and uploaded |

For formative feedback, show the candidate in a small app grid to **5–8 target users**. Show it briefly with its name, then ask them to find it again and describe what they remember. Ask for associations before explaining the metaphor. Include some users who did not participate in design selection.

These are internal qualitative tests, not proof of conversion lift or statistical validation. If several people independently see the same unwanted meaning, fix it. Do not compensate with a long story about why the symbol is clever.

After one sound candidate passes the gates, stop expanding the logo project. The evidence screens deserve more engineering attention than a twentieth mark variation.

## 11. Delivery package and source hygiene

Suggested paths below are **future artwork deliverables**, not files created by this document:

```text
assets/brand/
  source/
    line-gap-master.svg
    linepaycheck-wordmark-editable.<design-tool-format>
    LinePay.icon/                    # Icon Composer source, when produced
  exports/
    line-gap-monochrome.svg
    linepaycheck-wordmark.svg        # Outlined artwork
    linepaycheck-lockup-light.svg
    linepaycheck-lockup-dark.svg
    app-icon-marketing-1024.png
    play-listing-icon-512.png        # Android release only
  manifest.md
```

Keep the editable design-tool source or its stable revision link, exact source-font version/license, approved geometry, palette, exported sizes, appearance review, and source revision in the manifest. Source artwork belongs in a small, reviewable package; do not check in hundreds of exploratory exports.

Avoid externally linked images, embedded tracking, remote fonts, missing linked assets, hidden layers with old branding, and raster masks that fail at another scale. Export standard SVG paths/fills with predictable bounds. Remove editor-specific debris where safe without losing editability in the original source.

Do not distribute proprietary platform font files with a brand handoff. Reference approved sources/licenses instead.

## 12. Paste-ready production brief

> Create the LinePaycheck identity using the established Line Gap: two unequal horizontal segments with a small controlled offset and a visible interruption. Start in one ink. Optimize recognition at Home Screen size before presentation at 1024 pixels. Use graphite and porcelain, with one small Oxide accent contained inside the silhouette. The mark must remain intact in monochrome and platform-tinted appearances. Pair it with a readable LinePaycheck wordmark; do not alter letterforms into electrical symbols. No lightning bolt, hard hat, dollar sign, generic checkmark, shield, pole, circuit board, metallic texture, glow, or fake certification. Deliver editable vector sources, outlined wordmark exports, platform-specific icon sources, and a small-size/system-appearance proof sheet. This is a precision pay-checking tool, not a bank or an electrical safety product.

## References

Primary platform and type-publisher sources. Checked September 5, 2026. The construction, QA sizes, visual choices, and user-test suggestions above are LinePaycheck design judgments, not platform mandates or measured outcomes.

- **[L1] Apple HIG — App icons:** identity, source size, appearances, and vector/layer guidance. https://developer.apple.com/design/human-interface-guidelines/app-icons/
- **[L2] Apple — Icon Composer / creating your app icon:** composition, appearance previews, and production workflow. https://developer.apple.com/icon-composer/ and https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
- **[L3] Apple HIG — SF Symbols:** interface use and prohibited logo/trademark use. https://developer.apple.com/design/human-interface-guidelines/sf-symbols
- **[L4] Android Developers — Google Play icon design specifications:** listing-icon export and masking. https://developer.android.com/distribute/google-play/resources/icon-design-specifications
- **[L5] Android Developers — Adaptive icons:** launcher layers, safe region, and themed icons. https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
- **[L6] Inter publisher:** type source and SIL Open Font License reference. https://rsms.me/inter/

**Completion boundary:** approving this document does not approve a final logo, create icon assets, clear trademark rights, or verify a compiled app icon. Those remain explicit artwork-production gates.
