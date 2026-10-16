# OCR extraction and review evidence

[Test contract](README.md) · [V2 checkpoint](../plan/v2-execution.md)

OCR produces suggestions, never confirmed paycheck facts. Text recognition confidence is not a
calibrated probability of correct payroll interpretation. The review displays the original reading,
page and score alongside the editable value, preserves the source, and still requires confirmation.
Low-confidence dates receive the same explicit warning as low-confidence amount suggestions.

## Reproducible synthetic checks

| Layer | Cases | Independent expectation |
|---|---|---|
| `OCRCorpusTests` supported text layouts | 9 amount/hour fields × 3 current-period layouts | Fixed decimal strings; exact source text, page region and confidence retained |
| Ambiguous text | 7 ambiguous/negative/current-YTD rows plus conflicting gross rows on different pages | No amount selected, including when recognition confidence is high |
| Uncertain dates | A low-confidence, explicit period interval | Correct ISO dates remain suggestions and carry a warning; reviewed fields stay empty |
| Receipt wording | A 72% synthetic reading | Score is labelled recognition confidence and does not verify pay |
| `DocumentPipelineTests` clear PDFs | 4 fixed gross examples × 1/2 pages | Vision must extract the exact current gross from the correct page; no permissive nil success |
| Document bounds | Existing 9-page PDF fixture | Only first 8 pages read, explicit notice, original 9 pages retained |
| Native review journey | Synthetic low-confidence reading and original PDF | Receipt and source route work; score does not enable an unconfirmed comparison |

The PDF cases render known literal values into actual PDFs and invoke the on-device Vision path.
The UI fixture separately injects a labelled synthetic recognition result to exercise display and
confirmation deterministically. It is not evidence that Vision returned 72% on that source.

Execution results and source revisions are recorded in the v2 checkpoint. Test functions with
parameterized cases may be reported as one Swift Testing test with several cases; retain both
counts rather than treating a function count as the corpus size.

## Scope and promotion

These are synthetic supported-layout regressions written with the implementation. They are not
an independent holdout corpus, a representative survey of employer formats, or proof of the
roadmap's 98% production precision target. Recognition can abstain; measure both precision and
coverage so that abstaining on everything cannot be reported as success.

Before a broader performance claim, freeze separately reviewed/redacted evaluation documents,
field-level ground truth and the supported layout/language definition. Record exact amount/date
matches, incorrect non-abstaining suggestions, abstentions, current/YTD confusion, source-page
accuracy, user edit rate and sample counts. Keep test-set data out of extraction tuning. Never put
real wage or paystub documents into Git or logs, and never infer employer-wide support from one
layout. Current recognition language is English (US); it does not verify agreement applicability,
currency, statutory coverage or payroll completeness.
