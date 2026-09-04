# Nexus Roadmap

> **Status:** Living document — drafted 2026-09-01 from [architecture.md](architecture.md) (the "how") and [features.md](features.md) (the "what"). The daily breakdown lives in [tasks.md](tasks.md). **M0 (Day 1) complete 2026-09-01** — workspace, three package skeletons, thin `Nexus` app target, TestPlan and CI files in place. **M1 (Days 2–4) complete 2026-09-02** — Domain entities, `AppError`, and the repository/service protocols merged to `main`. **M2 (Days 5–8) in progress as of 2026-09-03** — Day 5 session manager merged (#7); the live day state and test counts live in [tasks.md](tasks.md) checkboxes and git history, not in this block.
>
> **Source of truth:** `architecture.md` wins on patterns and structure; `appspec.md` wins on behavior detail; `features.md` wins on product scope. Where they conflict, this document follows `architecture.md` (see [Known tensions](#5-known-tensions--decisions)).

## 1. Goal

Ship **Nexus**, a SwiftUI iOS banking app focused on cards and their features, built on the **MV (Model-View)** architecture described in `architecture.md`: three Swift Package Manager packages (`NexusDomain`, `NexusData`, `NexusFeatures`) plus a thin app target (composition root). The app must run end-to-end with **no backend**, in demo mode, from the start of feature work, and be ready to plug into a real backend later via the §11.4 adapter contract.

## 2. Guiding principles

- **Demo-first.** The app must run completely on `-demoMode` / `API_ENVIRONMENT = demo` (in-memory mocks, no network/Keychain/disk) from the first feature milestone. Views and models never know whether they are live or demo.
- **Architecture-first.** Follow the `architecture.md` Step 1–8 porting checklist in order. Never import upward; one `AppError`; no ViewModels, Combine, completion handlers, or `Result` at repository boundaries.
- **Small, trunk-based changes.** One day = one branch, small conventional commits, PR at the end of the day. Branches live < 1 day; no direct pushes to `main`.
- **Tests with the work.** Swift Testing suites beside code, aggregated in the workspace TestPlan; > 80% coverage; UI tests launch with `-demoMode`. Every milestone ends green.
- **Staged releases.** Each release ends shippable: green build, green tests, docs updated.

## 3. Releases and milestones

Estimated effort: **15 working days (~3 weeks)**. Milestones map 1:1 to days in [tasks.md](tasks.md).

| Milestone | Release | Days | Goal |
|---|---|---|---|
| **M0** Project setup | v1.0 | 1 | Git repo, workspace, package + app skeletons, config, TestPlan, CI |
| **M1** Domain layer | v1.0 | 2–4 | Entities, `AppError`, repository/service protocols |
| **M2** Data layer | v1.0 | 5–8 | Session, data sources, repositories, persistence, logging, shared mocks |
| **M3** SharedUI + Navigation | v1.0 | 9 | Design tokens, shared components, `Router`/`Route` |
| **M4** Dashboard | v1.0 | 10–11 | Dashboard model/view, card carousel, offers |
| **M5** Card detail & controls | v1.0 | 12 | Freeze/unfreeze, lost/stolen, replacement, spending limits |
| **M6** Balances & transactions | v1.0 | 13 | Live balances, history, search/filter, details |
| **M7** Composition root + demo mode | v1.0 | 14 | `AppContainer`, `AppState`, route→view, demo wiring |
| **M8** v1.0 hardening | v1.0 | 15 | Full test sweep, invariants, README/CHANGELOG |

### Release definitions

- **v1.0 — Foundation & Core** (Days 1–15). Domain and Data layers complete; dashboard with card carousel, card controls (freeze/unfreeze, lost/stolen, replacement, spending limits), live balances, transaction history with search/filter and details; full demo mode; dark/light, haptics, accessibility. *Exit: a shippable, demoable banking core with no backend.*

### Deferred releases (v1.1/v1.2 — removed from the active plan)

Payments, security (biometrics/app lock/PIN), Apple Pay + Wallet extension,
real-time alerts, virtual cards, and insights were previously scheduled as
v1.1/v1.2 (Days 16–28). They are **deferred indefinitely** — `features.md`
retains them as a catalog, and `appspec.md` §2.4–§2.7 mark the relevant
sections deferred. Revisit after v1.0 ships.

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

### Deferred (previously v1.1/v1.2)

- **Payments:** credit card payments (minimum/full/custom), confirmation + receipts.
- **Security:** biometric login + action approval, app lock, session timeout, secure PIN entry, PIN view/change/reset.
- **iOS integrations:** Apple Pay provisioning (`PKAddPaymentPassViewController`), Wallet issuer extension.
- **Alerts & insights:** real-time push alerts, virtual card numbers, card personalization, spending insights.

### Out of scope (for now)

- **Real backend.** The app ships demo-first; a backend plugs in later via the §11.4 adapter checklist (four repository protocols + `SessionManagerProtocol` against URLSession). No backend work is scheduled.
- **Real push infrastructure.** Demo uses `simctl push`; APNs certificate/infrastructure work is deferred until a backend exists.
- **Third-party banking SDK.** The default transport is URLSession (architecture.md §6.2); an SDK adapter is an alternative, not a requirement.
- **App Store submission**, macOS/multi-platform, localization beyond English.
- **git/CI hosting setup** beyond the local repo + workflow files (user initializes the repo once this document and tasks.md are approved).

## 5. Known tensions & decisions

- **Demo persistence (features.md vs architecture.md).** `features.md` once said demo state persists via "UserDefaults/Keychain"; `architecture.md` says demo mode is in-memory only and durable data lives in SwiftData, credentials in Keychain. **Decision: architecture.md wins** — demo is in-memory with reset; persistence is a live-mode concern. (`features.md` now says the same.)
- **Features with no blueprint coverage.** Payments, security, Apple Pay, Wallet extension, alerts, insights, virtual cards appear only in `features.md`; the architecture document is a pattern guide, not a scope list. **Decision:** build them on the same MV patterns, adding domain protocols (e.g., `PaymentRepositoryProtocol`, `BiometricAuthServiceProtocol`) following §4.2/§4.3.
- **`appspec.md` is the behavior spec.** `features.md` wins on scope;
  `appspec.md` refines it with per-feature rules, flows, and acceptance
  criteria (skeleton + Card Controls example as of 2026-09-03);
  `architecture.md` wins on patterns. Shipped behavior is ruled by code +
  tests — update `appspec.md` in the same PR that implements or changes it.

## 6. Risks

- **No backend exists** — mitigated by demo-first design; live mode must still build and unit-test against the §11.4 contract.
- **SwiftData on the iOS 17 floor** — hand-written `ModelActor` for background writes; iOS 18 macros are a later upgrade (architecture.md §12.3).
- **`AsyncStream` cannot throw mid-stream** — mid-stream errors must be modeled as values (§12.3).
- **Toolchain availability** — Xcode 26.6, iPhone 17 simulator (iOS 26.5); all gates assume these exact versions.

## 7. How to use this roadmap

1. Read [tasks.md](tasks.md) for the day-by-day breakdown; each day maps to a milestone above.
2. Prerequisite: the user initializes the git repo (Day 1) once this roadmap and tasks.md are approved.
3. A milestone is done only when its **exit criteria** pass — never merge red.
4. Update this document as reality diverges (scope, dates, patterns); keep tasks.md in sync.
