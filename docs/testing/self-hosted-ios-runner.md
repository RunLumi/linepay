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

Required local prerequisites are Xcode 26.6, XcodeGen 2.46.0, an available
iPhone Simulator, and the repository's pinned Swift package resolution. The
runner registration token is short-lived and must never be committed, logged,
or placed in this repository. Keep the runner service and its work directory
owned by the intended macOS user; do not register a personal runner for an
untrusted repository.

Before relying on a run, verify the runner is online in GitHub and record the
actual workflow SHA, Xcode version, simulator/device, command, exit code and
retained artifacts. A registered runner is not evidence that an iOS test
passed. If CoreSimulator is unavailable, the job must fail and remain an
honest missing native receipt.
