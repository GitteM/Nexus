# Nexus Roadmap

> **Purpose.** Release framing and the scope-decision log — deliberately
> small. The live day/milestone state lives in [tasks.md](tasks.md)
> checkboxes and git history; the product scope catalog (including deferred
> features) lives in [features.md](features.md); behavior detail lives in
> [appspec.md](appspec.md). This file is not a second copy of any of them.
>
> **Source of truth:** `architecture.md` wins on patterns and structure;
> `appspec.md` wins on behavior detail; `features.md` wins on product scope.
> Where they conflict, `architecture.md` wins (see
> [Known tensions & decisions](#5-known-tensions--decisions)).

## 1. Goal

Ship **Nexus**, a SwiftUI iOS banking app focused on cards and their
features — three SPM packages plus a thin app target, MV throughout
(`architecture.md`) — that runs end-to-end with **no backend** in demo mode
and plugs into a real backend later via the §11.4 adapter contract.

## 2. Releases

- **v1.0 — Foundation & Core (M0–M9, Days 1–16 — see tasks.md).** Cards:
  dashboard with carousel (art, status, offers → managed cards); card
  detail controls (freeze/unfreeze, report lost/stolen, replacement
  requests, spending limits); live balances; transaction history with
  search/filter and details. UX: dark/light, haptics, accessibility
  (Dynamic Type, VoiceOver). Localization: English/Estonian/Russian. Demo
  mode: in-memory mock graph, no network/Keychain/disk, reset action.
  *Exit: a shippable, demoable banking core with no backend.* — M0–M7 and
  M9 are merged to `main`; the M8 hardening close-out is PR #37
  (2026-09-05).
- **Deferred indefinitely** (catalogued in `features.md`; `appspec.md`
  §2.4–§2.7 mark the sections deferred): payments, security
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

The scope catalog lives in `features.md`. The v1.0 in-scope list is part of
§2 above; deferred features stay catalogued there and as placeholders in
`appspec.md` §2.4–§2.7. Keep new scope entries in `features.md` first, then
reflect them here only when they change a release.

## 4. Risks

- **No backend exists** — mitigated by demo-first design; live mode must
  still build and unit-test against the §11.4 contract.
- **SwiftData on the iOS 17 floor** — hand-written `ModelActor` for
  background writes; iOS 18 macros are a later upgrade (architecture.md
  §12.3).
- **`AsyncStream` cannot throw mid-stream** — mid-stream errors must be
  modeled as values (§12.3).
- **Toolchain availability** — Xcode 26.6, iPhone 17 simulator (iOS 26.5);
  all gates assume these exact versions.

## 5. Known tensions & decisions

- **Demo persistence (features.md vs architecture.md).** `features.md` once
  said demo state persists via "UserDefaults/Keychain"; `architecture.md`
  says demo mode is in-memory only and durable data lives in SwiftData,
  credentials in Keychain. **Decision: architecture.md wins** — demo is
  in-memory with reset; persistence is a live-mode concern. (`features.md`
  now says the same.)
- **Features with no blueprint coverage.** Payments, security, Apple Pay,
  Wallet extension, alerts, insights, virtual cards appear only in
  `features.md`; the architecture document is a pattern guide, not a scope
  list. **Decision:** build them on the same MV patterns, adding domain
  protocols (e.g., `PaymentRepositoryProtocol`,
  `BiometricAuthServiceProtocol`) following §4.2/§4.3.
- **`appspec.md` is the behavior spec.** `features.md` wins on scope;
  `appspec.md` refines it with per-feature rules, flows, and acceptance
  criteria — the v1.0 sections (§2.1–§2.3, §2.9) are settled in their
  milestone PRs, deferred sections (§2.4–§2.7) stay as placeholders;
  `architecture.md` wins on patterns. Shipped behavior is ruled by code +
  tests — update `appspec.md` in the same PR that implements or changes it.
