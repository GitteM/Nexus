# Nexus

A SwiftUI iOS banking demo focused on **cards and their features** —
card issuing, freeze/unfreeze, report lost/stolen, replacement tracking,
spending limits, live balances, and transaction history with search and
filtering. Ships with a full **demo mode** so the whole v1.0 feature set
runs with no backend.

- **Stack**: Swift 6 language mode (`swift-tools-version: 6.3`), Xcode 26.6 (CI pin), iOS 17.0+.
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

- **Xcode 26.6** with the iOS 26.5 SDK and an **iPhone 17** simulator (tests
  target it by name). That's the **CI pin** — local development may use a
  newer Xcode (e.g. 27), so a change must build on both.
- **SwiftFormat + SwiftLint** on `PATH` for the formatting/lint gate, pinned
  to `swiftformat 0.63.0` and `swiftlint 0.65.1` (see `Brewfile`).
- Optional: activate the pre-commit hook with
  `git config core.hooksPath .githooks`.

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
NexusTests/                app-target unit tests (AppContainer, smoke)
NexusUITests/              UI suites (dashboard, card detail, transactions)
Configs/                   Debug/Release xcconfigs + Info.plist
scripts/                   format/lint wrappers (format.sh, lint.sh)
TestPlan.xctestplan        workspace test plan (every suite)
Brewfile                   Homebrew manifest: swiftformat + swiftlint
Documentation/             operating guide, architecture, styleguide, spec, roadmap
```

## Documentation

Start at `Documentation/AGENTS.md` — the operating guide, whose doc map and
authority chain (§8) route every task to the right file. Highlights:
`architecture.md` (blueprint; §14 is the one-paragraph summary), `spec.md`
(product scope + per-feature behavior), `styleguide.md` (Swift style),
`ROADMAP.md` (release framing, decision log, milestone log),
`CONTRIBUTING.md` (commits/PRs).

## Scope notes

v1.0 ships demo-first with **no backend**. Payments, biometrics/app lock,
Apple Pay provisioning, alerts/insights and additional locales are
deferred beyond v1.0; demo and server content stays English by design.
