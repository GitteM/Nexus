# Nexus Roadmap

> **Purpose.** Release framing, the scope-decision log, and the milestone
> log — deliberately small. The product scope catalog (including deferred
> features) and per-feature behavior live in [spec.md](spec.md); the
> milestone history is §6 below; PR history and `git log` hold the detail.
> This file is not a second copy of any of them.
>
> **Source of truth:** `architecture.md` wins on patterns and structure;
> `spec.md` wins on scope and behavior detail; `styleguide.md` wins on style.
> Where they conflict, `architecture.md` wins (see
> [Known tensions & decisions](#5-known-tensions--decisions)).

## 1. Goal

Ship **Nexus**, a SwiftUI iOS banking app focused on cards and their
features — three SPM packages plus a thin app target, MV throughout
(`architecture.md`) — that runs end-to-end with **no backend** in demo mode
and plugs into a real backend later via the §11.4 adapter contract.

## 2. Releases

- **v1.0 — Foundation & Core (M0–M9, Days 1–16 — see §6).** Cards:
  dashboard with carousel (art, status, offers → managed cards); card
  detail controls (freeze/unfreeze, report lost/stolen, replacement
  requests, spending limits); live balances; transaction history with
  search/filter and details. UX: dark/light, haptics, accessibility
  (Dynamic Type, VoiceOver). Localization: English/Estonian/Russian. Demo
  mode: in-memory mock graph, no network/Keychain/disk, reset action.
  *Exit: a shippable, demoable banking core with no backend.* — M0–M7 and
  M9 are merged to `main`; the M8 hardening close-out is PR #37
  (2026-09-05).
- **Deferred indefinitely** (catalogued in `spec.md` — `§Scope` and the
  `§2.4`–`§2.7` placeholders): payments, security
  (biometrics/app lock/PIN), Apple Pay + Wallet extension, real-time
  alerts, virtual cards, insights, and locales beyond en/et/ru. Revisit
  after v1.0 ships.
- **Out of scope:** a real backend (by design — v1.0 is demo-first; the
  §11.4 adapter contract is the later seam), real push infrastructure, a
  third-party banking SDK, App Store submission, macOS/multi-platform.

### Milestone exit criteria (apply to every milestone)

- All listed deliverables exist and are wired; no stubs outside `#if DEBUG`.
- New logic has Swift Testing coverage; new user flows have UI tests
  (`-demoMode`).
- `swiftformat .` clean; build with no warnings; full TestPlan green; CI
  mirrors it.
- Docs kept in sync (README/CHANGELOG; `architecture.md` when a pattern or
  target changes).
- Architecture invariants hold (§13 Step 8): no upward imports/cycles, zero
  `@unchecked Sendable`, one `AppError`, no `Result` at repository
  boundaries, no sensitive data in logs/caches/configs.

## 3. Scope

The scope catalog lives in `spec.md` (`§Scope`). The v1.0 in-scope list is
part of §2 above; deferred features stay catalogued there and as
placeholders in `spec.md` `§2.4`–`§2.7`. Keep new scope entries in `spec.md`
first, then reflect them here only when they change a release.

## 4. Risks

- **No backend exists** — mitigated by demo-first design; live mode must
  still build and unit-test against the §11.4 contract.
- **SwiftData on the iOS 17 floor** — hand-written `ModelActor` for
  background writes; iOS 18 macros are a later upgrade (architecture.md
  §12.3).
- **`AsyncStream` cannot throw mid-stream** — mid-stream errors must be
  modeled as values (§12.3).
- **Toolchain availability** — CI is pinned to the latest stable runner image:
  Xcode 26.6, iPhone 17 simulator (iOS 26.5); local development may use a newer
  Xcode (e.g. 27 / Swift 6.4). All gates must hold on both.

## 5. Known tensions & decisions

- **Demo persistence (spec.md vs architecture.md).** `spec.md` once said
  demo state persists via "UserDefaults/Keychain"; `architecture.md` says
  demo mode is in-memory only and durable data lives in SwiftData,
  credentials in Keychain. **Decision: architecture.md wins** — demo is
  in-memory with reset; persistence is a live-mode concern. (`spec.md` now
  says the same.)
- **Features with no blueprint coverage.** Payments, security, Apple Pay,
  Wallet extension, alerts, insights, virtual cards appear only in
  `spec.md`; the architecture document is a pattern guide, not a scope
  list. **Decision:** build them on the same MV patterns, adding domain
  protocols (e.g., `PaymentRepositoryProtocol`,
  `BiometricAuthServiceProtocol`) following §4.2/§4.3.
- **`spec.md` is the scope + behavior spec.** It carries the product scope
  catalog (`§Scope`) and refines each feature with rules, flows, and
  acceptance criteria — the v1.0 sections (§2.1–§2.3, §2.9) are settled in
  their milestone PRs, deferred sections (§2.4–§2.7) stay as placeholders;
  `architecture.md` wins on patterns. Shipped behavior is ruled by code +
  tests — update `spec.md` in the same PR that implements or changes it.

## 6. Milestone log (v1.0)

The day-by-day build log is collapsed here; per-milestone PRs and
`git log` hold the detail.

- **M0 (Day 1)** — workspace + three SPM package skeletons + thin app target; CI and TestPlan wired.
- **M1 (Days 2–4)** — Domain: entities, `AppError`, repository/service protocols (no use cases).
- **M2 (Days 5–8)** — Data: session manager, data sources + caches, repositories + SwiftData/Keychain, logging, `#if DEBUG` mocks.
- **M3 (Day 9)** — SharedUI + Navigation: `Design` tokens, shared components, dependency-free `Router`/`Route`.
- **M4 (Days 10–11)** — Dashboard: carousel, offers→card, per-card live status; `DashboardUITests`.
- **M5 (Day 12)** — Card detail + controls: freeze/unfreeze, lost/stolen, replacement, spending limits; `CardDetailUITests`.
- **M6 (Day 13)** — Balances + transactions: live balance header, search/filter, detail view; `TransactionsUITests`.
- **M7 (Day 14)** — Composition root + demo mode (`AppContainer`, launch knobs, reset action).
- **M8 (Day 15)** — v1.0 hardening: invariants + accessibility audits; root `README.md` + `CHANGELOG.md` written.
- **M9 (Day 16)** — Localization (en/et/ru) via one String Catalog; canary UI tests.

v1.0 covers M0–M9; the M8 hardening close-out is PR #37 (2026-09-05).
Post-v1.0 work is tracked in `CHANGELOG.md` (`Unreleased`) and PR history.
