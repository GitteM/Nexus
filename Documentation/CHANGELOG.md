# Changelog

All notable changes to Nexus are tracked here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project
versioned as **v1.0** at the Day-15 hardening milestone (see
`tasks.md`).

## v1.0 — Foundation & Core (2026-09-05)

First shippable release: a demoable banking core with no backend.

### Added

- **Cards** — dashboard with swipeable card carousel (per-type card art,
  last-four digits, status), offers row that turns an offer into a managed
  card, and card detail with freeze/unfreeze, report lost/stolen,
  replacement requests (tracked as a dashboard offer) and daily/weekly/
  monthly spending limits.
- **Balances & transactions** — live per-card balance header (current,
  available, credit limit) and a transaction history with pending/cleared
  rows, search/filter by text, category, status, date window and amount,
  plus a transaction detail deep view.
- **Demo mode** — in-memory mock graph (`-demoMode` / `API_ENVIRONMENT =
  demo`, DEBUG builds only) with seeded data, live event streams through
  the real parse path, and a reset-demo action; release builds ignore
  `-demoMode`.
- **Architecture** — three SPM packages (`NexusDomain`, `NexusData`,
  `NexusFeatures`) plus a thin app composition root; one `AppError`;
  repository protocols without `Result`; SwiftData + Keychain + in-memory
  cache in the data layer; shared design tokens and `Router`/`Route`
  navigation.
- **Accessibility & UX** — dark/light appearance, haptics, Dynamic Type
  and VoiceOver across the v1.0 screens, explicit accessibility namespaces
  shared with the UI tests.
- **Localization** — English, Estonian and Russian via one app String
  Catalog (chrome copy, domain value labels, `AppError` surfaces; format
  keys keep their placeholders; diagnostics stay English).
- **Hardening** — architecture-invariant and accessibility audits closed:
  VoiceOver-activatable transaction rows, status (not action) announcement
  for added offers, per-state previews for every view state, Dynamic Type
  scaling on list/offer copy, full TestPlan sweep green with zero warnings.
- **Docs** — this changelog, the root README, and the v1.0 milestone
  records in `Documentation/` (`tasks.md`, `ROADMAP.md`).

### Known limitations

- No backend yet — live mode composes the real data layer against the
  §11.4 adapter contract and reports the missing config while
  `API_BASE_URL` is empty.
- Payments, biometrics/app lock, Apple Pay + Wallet, real-time alerts and
  virtual cards are catalogued in `features.md` but deferred beyond v1.0.
- Demo/server content stays English by design.
