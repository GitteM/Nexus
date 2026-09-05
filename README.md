# Nexus

A SwiftUI iOS banking demo focused on **cards and their features** —
card issuing, freeze/unfreeze, report lost/stolen, replacement tracking,
spending limits, live balances, and transaction history with search and
filtering. Ships with a full **demo mode** so the whole v1.0 feature set
runs with no backend.

- **Stack**: Swift 6.3 (Swift 6 language mode), Xcode 26.6, iOS 17.0+.
- **Architecture**: MV (Model-View) — `@MainActor @Observable` models drive
  SwiftUI views through explicit `viewState` enums. No ViewModels, no
  Combine, no completion handlers.
- **Packages**: three SPM packages under `AppPackages/`
  (`NexusDomain` — entities, protocols, one `AppError`;
  `NexusData` — session, data sources, repositories, persistence,
  logging, `#if DEBUG` mocks; `NexusFeatures` — design tokens, shared UI,
  navigation, screens) plus a thin `Nexus` app target that composes them.
- **Localization**: English, Estonian, Russian via one app String Catalog.
- **Persistence (live mode)**: SwiftData for durable state, Keychain for
  credentials, display-safe logging only (last four digits, never PANs).

## Requirements

- Xcode 26.6 with the iOS 26.5 SDK and an **iPhone 17** simulator
  (tests target it by name).
- `swiftformat` (0.63+) on `PATH` for the formatting gate.

## Run

Open `Nexus.xcworkspace` and run the **Nexus Demo** scheme on an iPhone 17
simulator. Demo mode (`-demoMode`, also selected by
`API_ENVIRONMENT = demo`) builds an in-memory mock graph — no network,
Keychain, or disk — with seeded cards, offers, balances and transactions,
and a **Reset demo** action in the UI. Release builds compile the demo
graph out and ignore `-demoMode`; live mode composes the real data layer
and reports the missing-backend config gap while `API_BASE_URL` is empty.

UI tests additionally understand `-demoState`, `-demoActionState`, and
`-demoOpenCard` launch knobs (parsed in
`Nexus/AppContainer+Dependencies+Demo.swift`).

## Test

The workspace TestPlan aggregates the unit, integration, and UI suites:

```bash
xcodebuild test -workspace Nexus.xcworkspace -scheme Nexus \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

UI tests launch the app in `-demoMode`; the localization canaries launch
with `-AppleLanguages (ru)` / `(et)` and assert translated chrome on the
real view layer. The first test build after a fresh DerivedData prints
known Xcode dependency-scan warnings — documented one-time tooling noise,
not a failure (see `Documentation/AGENTS.md`).

## Layout

```text
Nexus.xcworkspace          workspace (open this)
AppPackages/NexusDomain/   domain: entities, repository/service protocols
AppPackages/NexusData/     data: session, sources, repositories, mocks
AppPackages/NexusFeatures/ features: design tokens, shared UI, screens
Nexus/                     thin app target (composition root, demo wiring)
NexusUITests/              UI suites (dashboard, card detail, transactions)
Documentation/             operating guide, architecture, specs, roadmap
```

## Documentation

Start at `Documentation/README.md` — the index maps every file to the
task that needs it. Highlights: `AGENTS.md` (operating guide, gates,
invariants), `architecture.md` (blueprint; §14 is the one-paragraph
summary), `features.md` / `appspec.md` (scope and behavior), `tasks.md`
(day state), `ROADMAP.md` (release framing + decision log),
`CONTRIBUTING.md` (commits/PRs).

## Scope notes

v1.0 ships demo-first with **no backend**. Payments, biometrics/app lock,
Apple Pay provisioning, alerts/insights and additional locales are
deferred beyond v1.0; demo and server content stays English by design.
