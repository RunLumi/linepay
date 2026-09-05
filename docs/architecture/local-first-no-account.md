# Local-First Architecture: No Account, No Central Backend

## Decision

LinePay 1.0 will ship with **no LinePay user account, no username/password flow, and no central backend storing worker pay data**.

This is a product feature, not merely an implementation shortcut.

> **No account is a feature. No backend is the default.**
>
> LinePay stores worker pay data locally and performs calculation and document processing on-device. A server may only be introduced when a demonstrated user requirement cannot reasonably be solved locally or through platform services.

## Why this decision fits LinePay

LinePay answers a narrow, high-trust question:

> Given the work I actually performed and the pay rules I confirmed, what should I expect to be paid and where might my paycheck differ?

Creating an account before a worker can answer that question adds friction without adding value.

Paystubs and wage history are sensitive. Keeping them on the device gives LinePay a simple and credible privacy story:

> Your pay data stays on your phone. LinePay does not require an account or upload your paycheck to a LinePay server.

The absence of a backend also removes a large class of operational and security work:

- password storage and resets;
- email verification;
- authentication tokens and session handling;
- user databases;
- API infrastructure;
- server-side encryption/key management;
- account deletion workflows;
- backend migrations;
- synchronization conflicts;
- breach surface;
- backend monitoring and recurring infrastructure cost.

## iOS 1.0 architecture

```text
                     iPhone
                       │
        ┌──────────────┼──────────────┐
        │              │              │
     SwiftUI        SwiftData      StoreKit 2
        │              │              │
        │         local history     subscription
        │              │              │
        └─────── LinePay app ─────────┘
                       │
              LinePayDomain
          deterministic pay engine
                       │
              Vision / VisionKit
                on-device OCR
                       │
                Files / Share

               NO LINEPAY API
               NO USER DATABASE
               NO PAYSTUB UPLOAD
```

## First-run behavior

Preferred first-run experience:

```text
Open LinePay
    ↓
Set pay profile / confirmed rules
    ↓
Log work
    ↓
See expected pay
    ↓
Audit paycheck
```

Do not insert account creation, email verification, passwords, or profile registration into this path.

## Subscription without a LinePay account

A LinePay account is not required for an iOS subscription.

Use StoreKit 2 and the user's Apple account for purchase and restore behavior.

LinePay entitlement logic must remain behind a small application interface so domain calculations never depend on StoreKit.

Required behaviors include:

- purchase;
- restore;
- renewal;
- expiration;
- grace period / billing retry;
- transaction updates;
- local StoreKit configuration tests.

Do not create a backend only to mirror App Store subscription state unless a future cross-platform requirement proves it necessary.

## Local persistence

When persistence is introduced, store locally:

- pay profiles and immutable rule snapshots;
- work intervals;
- pay periods;
- calculation snapshots;
- source-document metadata;
- confirmed OCR/paystub facts;
- reconciliation results;
- preferences.

Persistence models remain adapters. The deterministic domain model remains independent from SwiftData.

Historical results must retain the exact rule version and source facts needed to reproduce what the worker saw at the time.

## Paystub processing

Default pipeline:

```text
Paystub image / PDF
        ↓
Vision / VisionKit OCR
        ↓
local deterministic parsing
        ↓
worker confirmation for uncertain material fields
        ↓
LinePayDomain reconciliation
        ↓
local audit result
```

Do not upload a paystub, OCR text, wage amount, employer identifier, or work history to a remote service by default.

If remote AI processing is ever proposed, it requires a separate ADR, explicit user value, privacy review, and explicit user consent. It must never silently become part of core pay calculation.

## Backup and recovery

### 1.0

Prefer device-local data plus an explicit LinePay export/backup path when implemented.

A user-selected backup should be portable and versioned so future app versions can migrate it safely.

### Possible future option: iCloud / CloudKit

If users strongly request automatic backup or multi-device Apple sync, prefer the user's private iCloud/CloudKit container before building LinePay-owned account infrastructure.

The product should still feel accountless:

```text
iPhone
   ↕
private iCloud data
```

No separate LinePay password should be required merely for Apple-device synchronization.

## Verified rule packs

Verified rule packs do not require user accounts.

Initially, packs can ship in the app bundle as versioned, source-backed data.

If updates become frequent, a future read-only distribution path may be acceptable:

```text
LinePay
   ↓
signed/versioned rule-pack manifest + files
   ↓
CDN/object storage
```

Such an endpoint should not require a worker identity or receive wage/paystub data.

Rule packs must remain versioned and immutable for historical calculations.

## Android

The existence of an Android app is **not**, by itself, a reason to add a central account/backend.

A simple initial model is:

```text
iOS
  local persistence
  native Swift domain engine
  StoreKit

Android
  local persistence
  native Kotlin domain engine
  Google Play Billing
```

The platforms share schemas, canonical fixtures, and rule behavior, not necessarily user data.

Only add cross-platform synchronization when real users demonstrate that it is valuable enough to justify the privacy and operational cost.

## What does not require our backend

| Capability | Central LinePay backend required? |
| --- | --- |
| Pay calculation | No |
| Work logging | No |
| Paystub OCR | No |
| Paystub reconciliation | No |
| Local history | No |
| StoreKit subscription | No |
| PDF/report export | No |
| User-selected backup file | No |
| iCloud sync | No LinePay backend |
| Bundled verified rule packs | No |
| Read-only rule-pack downloads | Possibly a tiny CDN, not a user backend |
| Android app | No |

## What may justify a backend later

A backend is reconsidered only for a demonstrated requirement such as:

- cross-platform iOS ↔ Android synchronization;
- one entitlement purchased outside app stores and honored across platforms;
- a web account/dashboard;
- employer/payroll integrations;
- collaborative/community agreement data requiring moderation and identity;
- server-distributed data that cannot reasonably be delivered as signed static content.

Even then, separate **content infrastructure** from **user-data infrastructure**. Do not turn a need for downloadable rule packs into an excuse to centralize pay history.

## Product copy principles

Good:

- "No LinePay account required."
- "Your pay data stays on this device."
- "Paystub processing happens on your iPhone."
- "LinePay does not upload your paycheck to a LinePay server."

Avoid absolute claims such as "nothing ever leaves your phone" if Apple platform services, optional iCloud backup, diagnostics, or future user-triggered sharing make that statement technically false.

## Non-goals for 1.0

Do not build:

- signup/login;
- password reset;
- email verification;
- OAuth/social login;
- LinePay user IDs;
- backend API;
- Postgres/user database;
- remote analytics SDK;
- server-side paystub storage;
- payroll provider account linking;
- employer dashboards;
- custom synchronization infrastructure.

## Architecture test

Before introducing any remote service, answer all of these:

1. What demonstrated user problem cannot reasonably be solved on-device or through platform services?
2. Does the server need worker identity, or can it be anonymous/read-only content delivery?
3. Does any wage, employer, work-history, paystub, or agreement-selection data leave the device?
4. What security, privacy, deletion, migration, availability, and operating burden is introduced?
5. Is the resulting user value clearly greater than that burden?
6. Is there a simpler local-first alternative?

If the answers are weak, do not add the backend.
