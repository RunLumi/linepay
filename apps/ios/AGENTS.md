# LinePaycheck iOS Agent Instructions

The repository-root `AGENTS.md` remains authoritative for engineering and product invariants.

For every iOS engineering change, **read and follow `../../docs/engineering/ios-best-practices.md` before implementation**.

For every user-facing iOS change, **also read and follow `../../DESIGN.md` before implementation**.

In particular:

- preserve the Precision Industrial Minimalism direction;
- prefer native SwiftUI/system behavior over custom chrome;
- use semantic design tokens rather than raw colors in feature views;
- use SF Pro/system text styles and Dynamic Type;
- use monospaced digits where numeric alignment matters;
- prefer rows, dividers, and ledger structure over generic card grids;
- keep Liquid Glass in the system control/navigation layer, not the content layer;
- never communicate pay state using color alone;
- maintain >=44 pt touch targets, with 48–56 pt preferred for frequent field actions;
- show uncertainty and evidence explicitly in OCR/audit workflows;
- do not introduce gradients, decorative glow, generic fintech dashboards, AI/sparkle motifs, faux industrial textures, or trade cosplay;
- run the `DESIGN.md` Design QA checklist before considering a user-facing screen complete.

Engineering changes must also preserve the tested boundaries in `docs/engineering/ios-best-practices.md`, especially Swift 6 concurrency safety, exact money/time semantics, privacy-by-architecture, localization readiness, migration safety, and layered test coverage.

For user-facing work, compilation is not completion when Simulator inspection is available. Prefer XcodeBuildMCP for the interactive build/run/screenshot/accessibility loop and Maestro for durable critical journeys.

If a feature genuinely requires breaking a rule in `DESIGN.md` or `docs/engineering/ios-best-practices.md`, update the relevant decision deliberately rather than silently drifting from the system.
