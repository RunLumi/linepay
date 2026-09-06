# Product-to-code traceability

[Product handbook](README.md) · [Canonical implementation map](implementation-map.md) · [Issue tracker #49](https://github.com/streamentry/linepay/issues/49)

The complete mapping lives in **[implementation-map.md](implementation-map.md)**. It covers all 45 BR business rules, 18 PAY concepts and 34 EX examples, including the end-only OCR finding (#48). Maintain that map instead of two competing coverage tables.

## Consolidation notes

The parallel mapping remains in this file's Git history. Its distinct findings, including unpriceable-period rollover and end-only OCR dates, are retained in the consolidated map rather than discarded or refiled. Two cross-reference corrections matter:

- Weekly/regular-rate capability is tracked in **#42**; #43 is its duplicate. Concurrent duplicate-closure actions are not evidence that the missing capability was fixed.
- The final pinned handbook at `990154cb517773036c29d8051a30e7e0edf9feaa`, blob `b080373207306366bc67934f8715ce49278ba6a7`, defines **EX-13 as 30h at $40 plus 20h at $60, total $2,640**. Unequal hours deliberately test weighted-rate computation. The older equal-hours $2,600 vector is not substituted for that source. See [the exact example](https://github.com/streamentry/linepay/blob/990154cb517773036c29d8051a30e7e0edf9feaa/docs/product/payroll/worked-examples.md).

The consolidated map distinguishes executed portable observations from source-traced application gaps and native/device verification. No app fix, merge, release or legal approval is implied.
