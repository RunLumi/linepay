# Self-hosted iOS CI runner

The repository uses a dedicated macOS runner labelled `linepay-ios` for the
iOS and legal-regression workflows, including pull requests. This is an
intentional security boundary: repository pull-request code executes on the
authorized developer-owned Mac. Do not use this runner for an untrusted fork
or unrelated repository.

The runner must have these labels:

```text
self-hosted, macOS, ARM64, linepay-ios
```

Required local prerequisites are Xcode 26.6, XcodeGen 2.46.0, the pinned
`QC iPhone 17 Pro v2` simulator (UDID
`0A8C774B-C1D3-4A43-816C-81D3D3D849D8`, iOS 26.4), the
`LinePay Release iPhone 18` simulator (UDID
`6CB95D1F-BC8E-4C06-B8C4-606F58AA02A9`, iOS 18.5), and the repository's pinned
Swift package resolution. The
runner registration token is short-lived and must never be committed, logged,
or placed in this repository. Keep the runner service and its work directory
owned by the intended macOS user; do not register a personal runner for an
untrusted repository.

Before relying on a run, verify the runner is online in GitHub and record the
actual workflow SHA, Xcode version, simulator/device, command, exit code and
retained artifacts. A registered runner is not evidence that an iOS test
passed. If CoreSimulator is unavailable, the job must fail and remain an
honest missing native receipt.

The workflows reset only the synthetic LinePay app container on the selected
pinned simulator before testing. They do not erase the device or alter
unrelated simulator data. The focused legal-regression gate uses iOS 26.4 for
the large-text scope journey. The full iOS gate uses iOS 18.5 because the
installed iOS 26.4 StoreKit test daemon reproducibly returns
`SKInternalErrorDomain Code=3` while clearing local test transactions; that is
an environment limitation, not a relaxed product assertion.
