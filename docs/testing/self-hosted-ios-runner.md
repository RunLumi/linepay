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

Required local prerequisites are Xcode 26.6 (or the newer installed Xcode,
which the workflows fall back to), XcodeGen 2.46.0, a `QC iPhone 17 Pro v2`
simulator on iOS 26, a `LinePay Release iPhone 18` simulator on iOS 18.5, and
the repository's pinned Swift package resolution. The workflows find each
simulator by its exact name, never by UDID: a UDID does not survive a host
restore or a rebuilt simulator, and a missing name fails the job with the list
of available devices. The
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

Before the full iOS gate, its dedicated iOS 18.5 simulator is shut down and
its simulator-scoped StoreKit, App Store, and iTunes Store daemons are
kickstarted, then it is booted again to give local StoreKit a clean session;
this is a scoped daemon restart and reboot, not an erase.

The two Maestro matrix jobs use the same two named devices; workflows never
create or auto-select a simulator. Maestro 2.7.0 is downloaded once into the runner user's persistent
`~/.cache/linepay` directory, verified by SHA-256, and reused by the second
matrix job. A partial download is written to a temporary name and is never
used as the cache entry.

## Current host (October 4, 2026)

After the October 3 SSD restore removed the previous runner and simulators, the
runner was re-registered on the developer Mac mini:

- Runner `Hongs-Mac-mini-linepay-ios`, v2.337.0 (SHA-256 checked against the
  release notes), installed in `/Volumes/SSD/actions-runner/linepay` with work
  directory `/Volumes/SSD/actions-runner/linepay-work`. Its PATH is fixed in
  `.path` to Homebrew plus system directories so CI does not inherit an
  interactive shell's wrappers.
- Simulators recreated with the names above: `LinePay Release iPhone 18`
  (iPhone 16 type, iOS 18.5) and `QC iPhone 17 Pro v2` (iPhone 17 Pro, iOS 26.5).
- **macOS privacy limits the launchd service.** A LaunchAgent cannot read the
  external `/Volumes/SSD` volume until the owner grants access in System
  Settings > Privacy & Security (Full Disk Access, or Files and Folders >
  Removable Volumes, for the runner's `runsvc.sh`/`bash`). Until then the
  service exits with `Operation not permitted` and the runner is started with
  `./run.sh` from a logged-in terminal instead. After granting access, stop the
  terminal runner and run `./svc.sh start`.
