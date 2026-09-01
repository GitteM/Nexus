# Nexus Roadmap

> **Status:** Living document — drafted 2026-09-01 from [architecture.md](architecture.md) (the "how") and [features.md](features.md) (the "what"). The daily breakdown lives in [tasks.md](tasks.md). **Day 1 (M0) scaffolded 2026-09-01**: workspace, three package skeletons, thin `Nexus` app target, TestPlan and CI files in place; workspace builds with zero warnings and the full TestPlan is green.
>
> **Source of truth:** `architecture.md` wins on patterns and structure; `features.md` wins on product scope. Where they conflict, this document follows `architecture.md` (see [Known tensions](#5-known-tensions--decisions)).

## 1. Goal

Ship **Nexus**, a SwiftUI iOS banking app focused on cards and their features, built on the **MV (Model-View)** architecture described in `architecture.md`: three Swift Package Manager packages (`NexusDomain`, `NexusData`, `NexusFeatures`) plus a thin app target (composition root). The app must run end-to-end with **no backend**, in demo mode, from the start of feature work, and be ready to plug into a real backend later via the §11.4 adapter contract.

## 2. Guiding principles

- **Demo-first.** The app must run completely on `-demoMode` / `API_ENVIRONMENT = demo` (in-memory mocks, no network/Keychain/disk) from the first feature milestone. Views and models never know whether they are live or demo.
- **Architecture-first.** Follow the `architecture.md` Step 1–8 porting checklist in order. Never import upward; one `AppError`; no ViewModels, Combine, completion handlers, or `Result` at repository boundaries.
- **Small, trunk-based changes.** One day = one branch, small conventional commits, PR at the end of the day. Branches live < 1 day; no direct pushes to `main`.
- **Tests with the work.** Swift Testing suites beside code, aggregated in the workspace TestPlan; > 80% coverage; UI tests launch with `-demoMode`. Every milestone ends green.
- **Staged releases.** Each release (v1.0 → v1.1 → v1.2) ends shippable: green build, green tests, docs updated.

## 3. Releases and milestones

Estimated effort: **28 working days (~6 weeks)**. Milestones map 1:1 to days in [tasks.md](tasks.md).

| Milestone | Release | Days | Goal |
|---|---|---|---|
| **M0** Project setup | v1.0 | 1 | Git repo, workspace, package + app skeletons, config, TestPlan, CI |
| **M1** Domain layer | v1.0 | 2–4 | Entities, `AppError`, repository/service protocols, mocks |
| **M2** Data layer | v1.0 | 5–8 | Session, data sources, repositories, persistence, logging, shared mocks |
| **M3** SharedUI + Navigation | v1.0 | 9 | Design tokens, shared components, `Router`/`Route` |
| **M4** Dashboard | v1.0 | 10–11 | Dashboard model/view, card carousel, offers |
| **M5** Card detail & controls | v1.0 | 12 | Freeze/unfreeze, lost/stolen, replacement, spending limits |
| **M6** Balances & transactions | v1.0 | 13 | Live balances, history, search/filter, details |
| **M7** Composition root + demo mode | v1.0 | 14 | `AppContainer`, `AppState`, route→view, demo wiring |
| **M8** v1.0 hardening | v1.0 | 15 | Full test sweep, invariants, README/CHANGELOG |
| **M9** Payments | v1.1 | 16–17 | Credit card payments + confirmation |
| **M10** Security | v1.1 | 18–20 | Biometric auth, app lock, session timeout, PIN |
| **M11** v1.1 hardening | v1.1 | 21 | Security review, full sweep, docs |
| **M12** Apple Pay + Wallet extension | v1.2 | 22–23 | In-app provisioning, issuer extension target |
| **M13** Real-time alerts | v1.2 | 24 | Push notifications (`simctl push` demo) |
| **M14** Virtual cards + personalization | v1.2 | 25 | Virtual card numbers, card themes |
| **M15** Insights | v1.2 | 26 | Spending insights from transaction history |
| **M16** v1.2 hardening | v1.2 | 27 | Integration sweep, invariants, doc updates |
| **M17** Release readiness | v1.2 | 28 | Final QA, docs, release checklist |

### Release definitions

- **v1.0 — Foundation & Core** (Days 1–15). Domain and Data layers complete; dashboard with card carousel, card controls (freeze/unfreeze, lost/stolen, replacement, spending limits), live balances, transaction history with search/filter and details; full demo mode; dark/light, haptics, accessibility. *Exit: a shippable, demoable banking core with no backend.*
- **v1.1 — Payments & Security** (Days 16–21). Credit card payments (minimum/full/custom) with confirmation; biometric login and action approval, app lock, session timeout, secure PIN entry, PIN management. *Exit: payments and security complete and reviewed.*
- **v1.2 — iOS Integrations, Alerts & Insights** (Days 22–28). Apple Pay provisioning, Wallet issuer extension, real-time alerts, virtual card numbers, card personalization, spending insights. *Exit: full features.md feature set shipped.*

### Milestone exit criteria (apply to every milestone)

- All listed deliverables exist and are wired; no stubs outside `#if DEBUG`.
- New logic has Swift Testing coverage; new user flows have UI tests (`-demoMode`).
- `swiftformat .` clean; build with no warnings; full TestPlan green; CI mirrors it.
- Docs kept in sync (README/CHANGELOG; `architecture.md` when a pattern or target changes).
- Architecture invariants hold (§13 Step 8): no upward imports/cycles, zero `@unchecked Sendable`, one `AppError`, no `Result` at repository boundaries, no sensitive data in logs/caches/configs.

## 4. Scope

### In scope (from features.md)

- **Cards (v1.0):** dashboard with card art/status, carousel; freeze/unfreeze, report lost/stolen, replacement requests + tracking; spending limits (daily/weekly/monthly).
- **Balances & transactions (v1.0):** current/available balances and credit limits, live updates; history with pending/cleared; search/filter by date, category, amount, status; transaction details.
- **UX (v1.0):** dark/light mode, haptics, accessibility (Dynamic Type, VoiceOver).
- **Demo mode (v1.0):** mock data, simulated network calls, in-memory state with reset-to-default; `-demoMode` / `API_ENVIRONMENT = demo`.
- **Payments (v1.1):** credit card payments (minimum/full/custom), confirmation + receipts.
- **Security (v1.1):** biometric login + action approval, app lock, session timeout, secure PIN entry, PIN view/change/reset.
- **iOS integrations (v1.2):** Apple Pay provisioning (`PKAddPaymentPassViewController`), Wallet issuer extension.
- **Alerts & insights (v1.2):** real-time push alerts (large purchases, low balance; `simctl push` in demo), virtual card numbers, card personalization, spending insights.

### Out of scope (for now)

- **Real backend.** The app ships demo-first; a backend plugs in later via the §11.4 adapter checklist (four repository protocols + `SessionManagerProtocol` against URLSession). No backend work is scheduled.
- **Real push infrastructure.** Demo uses `simctl push`; APNs certificate/infrastructure work is deferred until a backend exists.
- **Third-party banking SDK.** The default transport is URLSession (architecture.md §6.2); an SDK adapter is an alternative, not a requirement.
- **App Store submission**, macOS/multi-platform, localization beyond English.
- **git/CI hosting setup** beyond the local repo + workflow files (user initializes the repo once this document and tasks.md are approved).

## 5. Known tensions & decisions

- **Demo persistence (features.md vs architecture.md).** `features.md` says demo state persists via "UserDefaults/Keychain"; `architecture.md` says demo mode is in-memory only and durable data lives in SwiftData, credentials in Keychain. **Decision: architecture.md wins** — demo is in-memory with reset; persistence is a live-mode concern.
- **Features with no blueprint coverage.** Payments, security, Apple Pay, Wallet extension, alerts, insights, virtual cards appear only in `features.md`; the architecture document is a pattern guide, not a scope list. **Decision:** build them on the same MV patterns, adding domain protocols (e.g., `PaymentRepositoryProtocol`, `BiometricAuthServiceProtocol`) following §4.2/§4.3.
- **Wallet issuer extension adds a new target.** The `NexusWalletExtension` extension target goes beyond the module map in `architecture.md` §3 — update that document when it lands (Day 23).
- **`appspec.md` is empty.** Not a source; revisit when populated.

## 6. Risks

- **No backend exists** — mitigated by demo-first design; live mode must still build and unit-test against the §11.4 contract.
- **Wallet issuer extension complexity** (new target, app groups, device verification) — scheduled late and isolated in M12 so a slip does not block v1.0/v1.1.
- **SwiftData on the iOS 17 floor** — hand-written `ModelActor` for background writes; iOS 18 macros are a later upgrade (architecture.md §12.3).
- **`AsyncStream` cannot throw mid-stream** — mid-stream errors must be modeled as values (§12.3).
- **Toolchain availability** — Xcode 26.6, iPhone 17 simulator (iOS 26.5); all gates assume these exact versions.

## 7. How to use this roadmap

1. Read [tasks.md](tasks.md) for the day-by-day breakdown; each day maps to a milestone above.
2. Prerequisite: the user initializes the git repo (Day 1) once this roadmap and tasks.md are approved.
3. A milestone is done only when its **exit criteria** pass — never merge red.
4. Update this document as reality diverges (scope, dates, patterns); keep tasks.md in sync.
