# ADR 0023: native crew drafts and retained adoption

Status: implemented for the owner's all-stage/local-only v2 request, October17,2026. Native runtime,
Files-provider and visual/accessibility acceptance remain pending. Compilation is separate evidence.

Use the existing [portable draft contract](../../shared/contracts/templates/README.md). The native
Settings entry prepares an exact reviewed in-memory file for the system Files exporter. A new public
UUID identifies the draft; private profile IDs, work/paycheck histories, source text and originals
never enter this format. Wage/allowance amounts default to omitted. Title/revision/amount-option
changes invalidate the prepared file and rights confirmation. A rights checkbox is not legal clearance.
Do not infer provider upload completion or recipient delivery from the system save callback.

The welcome screen also offers inspection before a first profile exists; preparation returns to
the normal onboarding setup flow. Import coordinates a user-selected local/provider file off the UI actor, with security-scoped access,
cancellation and a65,536-byte allocation bound. Strict domain decoding precedes inspection. Merely
opening a file creates no persisted profile, source approval or active rules. Included amounts are
shown as draft facts; recipient entry fields start blank. Currency, explicit timezone, allowance
choice, rounding and applicability require review. Existing unfinished setup is replaced only after
an explicit replacement choice. Preparation saves a setup draft; the existing four-step editor still
owns period/context review and final rule save.

`CrewRuleAdoption` retains original bytes and exact recipient wage/allowance choices. Reproduce the
selected rules before admitting decoded provenance or a final agreement. New native state schema8
adds optional retained origins and an optional setup-draft adoption. Schemas1–7 add no inferred
origins and preserve existing snapshots. Each saved origin includes the resulting immutable agreement
version and confirmed timezone. Conflicting contents under one retained public ID/revision refuse;
recipient amount choices do not change the original packet identity. Metadata is saved atomically with the existing profile transaction;
failed persistence leaves the prior draft and work/rules unchanged. Backup carries this metadata through
the existing state/encryption container; it does not change the portable financial-container version.

Native currently has one profile. First-time adoption creates it; adoption into an existing profile
creates a fresh immutable version for **future periods only**, preserving existing work/audit/history
snapshots. Incompatible currency or rounding refuses, rather than silently converting or changing
rounding. Later manual edits preserve an already reviewed pay-category rounding mode; they do not
silently reset a banker-rounded draft to half-up. This differs from the browser's multiple-profile model. Imported terms cannot be changed in
the editor while retaining a stale adoption confirmation; return to the import review and prepare again.
Current-period corrections and dated-change scopes are unavailable for imported crew drafts.

An explicitly configured zero per-diem amount remains configured, distinct from absent/unknown.
The native profile adapter previously rejected zero despite the domain allowing it; accept explicit
zero without inventing missing allowance values. This does not establish eligibility or legal waiver.

No account, remote lookup/collector, bundle identity change, new dependency, named pack, official
library or automatic send is introduced. Android adoption and broader platform parity remain pending.
Pure tests, SDK compilation, native App tests, actual Simulator/Files interaction, physical transfer,
crew usage, source rights and App Store release are independent evidence layers.
