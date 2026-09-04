# Nexus Daily Tasks

> Daily breakdown of the [roadmap](ROADMAP.md). **One day = one branch, small conventional commits, PR at the end of the day.** Tasks are ordered within each day; the shared Definition of Done applies to every day.
>
> **Prerequisites**
> - Git repository initialized (the user creates it once this document and ROADMAP.md are approved).
> - Toolchain: Xcode 26.6, iPhone 17 simulator (iOS 26.5), `swiftformat` installed.
> - Read `Documentation/architecture.md` before any architecture-sensitive work (this whole project is).

## Daily Definition of Done

1. `swiftformat .` leaves no diffs.
2. Full workspace test suite green:
   `xcodebuild test -workspace Nexus.xcworkspace -scheme Nexus -destination 'platform=iOS Simulator,name=iPhone 17'`
3. Build with no warnings.
4. All commits follow Conventional Commits (`type(scope): subject`, ≤ 72 chars, imperative mood — see `CONTRIBUTING.md`); each commit is small and atomic.
5. Work lives on a branch created that day (e.g., `feature/dashboard-model`); a PR is opened at day's end and the **user merges**. Never push directly to `main`.
6. Docs stay in sync (README/CHANGELOG when user-facing; `architecture.md` when a pattern or target changes).

---

## Phase A — v1.0 Foundation & Core (Days 1–15)

### Day 1 — Repo & workspace bootstrap (M0)

- [x] Initialize the git repo and commit a `.gitignore` (Xcode/Swift ignores: `.xcuserdata/`, `DerivedData/`, `*.xccheckout`, etc.).
- [x] Create `Nexus.xcworkspace`; under `AppPackages/` create the three package skeletons — `NexusDomain` (targets `Entities`, `RepositoryProtocols`, `ServiceProtocols`), `NexusData` (targets `Session`, `DataSources`, `Repositories`, `Persistence`, `Logging`, `Mocks`), `NexusFeatures` (targets `SharedUI`, `Navigation`, `Dashboard`, `CardDetail`) — each `swift-tools-version: 6.3`, `.iOS(.v17)` floor, Swift 6 language mode, no umbrella modules (architecture.md §3).
- [x] Create the thin `Nexus` app target (composition root) with a placeholder `NexusApp`; wire package dependencies in dependency order (Features → Data → Domain).
- [x] Add `Debug.xcconfig` / `Release.xcconfig` (`API_ENVIRONMENT = demo`, `API_BASE_URL` empty), Info.plist keys, and `Bundle+Extensions.swift` (architecture.md §7.1).
- [x] Add `TestPlan.xctestplan` skeleton and CI workflow files (`.github/workflows/ci.yml`, `pr-checks.yml`) — wired, exercised from Day 2 on.
- **Verify:** workspace opens; every package and the app target builds; no warnings. — done: `xcodebuild build-for-testing` + full TestPlan green (5 test targets, 5 smoke tests), zero build warnings.

### Day 2 — Domain entities I (M1)

- [x] `Card`, `CardType`, `CardStatus` (active/frozen/expired/lost), `CardOffer` — `Codable, Sendable, Equatable` structs with public memberwise inits and `static let mock…` values (architecture.md §4.1).
- [x] Tests: codable round-trip, equality, mock values valid.
- **Verify:** `NexusDomain` builds with no dependencies (pure Swift + Foundation); tests pass. — done: full workspace TestPlan green (27 Domain tests in 4 suites), zero build warnings, mock data uses EUR.

### Day 3 — Domain entities II + AppError (M1)

- [x] `Balance`, `Transaction`, `SpendingLimit`, `CardState`, `BankingEvent`, `CardCommand`/`CardCommandType`, `Settings` (architecture.md §4.1).
- [x] `AppError` + `ErrorCategory` grouped by feature area, computed surfaces (`errorDescription`, `failureReason`, `recoverySuggestion`, `category`, `isRecoverable`, `shouldReport`), hand-written `Equatable`, and a `#if DEBUG` `TestFactory` (architecture.md §5).
- [x] Tests: every `AppError` case constructs; category grouping; helpers behave.
- **Verify:** Domain tests pass; no SDK/OSLog/Combine imports in Domain. — done: full workspace TestPlan green (120 Domain tests in 12 suites), zero build warnings, mock events decode through the same entity `JSONDecoder` path live data will use.

### Day 4 — Domain repository & service protocols (M1)

- [x] `CardRepositoryProtocol`, `CardOffersRepositoryProtocol`, `CardStatusRepositoryProtocol`, `CardActionRepositoryProtocol` — one-shot `async throws -> T`; subscriptions `async throws -> AsyncStream<T>` (architecture.md §4.2).
- [x] `LoggerProtocol` + `LogLevel`; `SessionManagerProtocol` (`sessionStatus`, `connect()`, `disconnect()`, `events(for:) -> AsyncStream<BankingEvent>`, `send(to:payload:)`) (architecture.md §4.3).
- [x] Apply the use-case rule (§4.4): zero use-case/service types; every operation is a model method over one repository.
- [x] Tests: protocol shapes compile and mock cleanly.
- **Verify:** Domain complete and green; no `Result` at repository boundaries. — done: full workspace TestPlan green (159 Domain tests in 20 suites), zero build warnings; `SessionStatus` added to Entities for the session protocol; shapes pinned by in-target doubles, no `Result` anywhere at the boundary.

### Day 5 — Session manager (M2)

- [x] `APISessionManager` — `@MainActor @Observable final class`, `sessionStatus`, `connect()` via `withCheckedThrowingContinuation`, `disconnect()`, `events(for:)` over `URLSessionWebSocketTask` with `onTermination` cleanup, pending-subscription queue on reconnect (architecture.md §6.2).
- [x] `EventSubscriptionManager` thin facade over the session (connect/disconnect/events/send) (architecture.md §6.2).
- [x] Tests with a fake SDK client: connect/disconnect, event bridging, reconnect behavior.
- **Verify:** Session tests green; no `DispatchQueue` barriers or `@unchecked Sendable`. — done: full workspace TestPlan green (184 tests: 159 Domain + 22 new Session/facade tests), zero build warnings; transport seam (`WebSocketClientProtocol`) + `URLSessionWebSocketClient` behind `APISessionManager`; main-actor confinement is the synchronization — no `@unchecked`, no barriers.

### Day 6 — Data sources (M2)

- [x] `CardStateDataSource` actor: per-id cache, `parseEvent` normalizes payloads → typed entities, `subscribeToCardStatus` throws on setup failure (architecture.md §6.1).
- [x] `CardActionDataSource` struct for stateless one-shot actions (architecture.md §6.1).
- [x] Offers data source with TTL cache expiry (§6.1).
- [x] Wire DTO structs; `JSONDecoder+Extensions.swift` (`decode(_:from:logger:context:)` → `AppError.deserializationError`) (architecture.md §6.4).
- [x] Tests: parse success/error paths, cache hit/miss/TTL.
- **Verify:** Data source tests green; every decode error is an `AppError`. — done: full workspace TestPlan green (55 NexusData tests in 7 suites: Session/facade + JSONDecoder extension + data sources), zero build warnings; every wire decode logs context and surfaces as `AppError`; the per-id/offers caches are seeded synchronously on subscribe (delivery is the happens-before edge for cache reads), so resubscribes are deterministic and tests never hang.

### Day 7 — Repositories + persistence (M2)

- [x] `CardRepository`, `CardOffersRepository`, `CardStatusRepository`, `CardActionRepository` — thin, validate, wrap errors with operation context (architecture.md §6.3).
- [x] SwiftData: `StoredCard` `@Model` + `SwiftDataCardRepository` mapping to Domain structs (`@Model` classes never leave NexusData); hand-written `ModelActor` for background writes on the iOS 17 floor (architecture.md §6.4).
- [x] `KeychainWrapper` for credentials; never persist card numbers/CVV/tokens in plaintext (architecture.md §6.4).
- [x] `CacheManager` actor (NSCache, 50 items / 25 MB, TTL) for ephemeral live state (architecture.md §6.4).
- [x] Tests: repository validation/error wrapping; integration tests over real `CacheManager` + repository.
- **Verify:** Repositories + persistence tests green; no `@Model` type crosses the boundary. — done: full workspace TestPlan green on the iPhone 17 simulator, zero build warnings (NexusData 115 tests in 15 suites via `swift test` on macOS; 112 execute in the iOS gate — the 3 real-Keychain tests are macOS-gated because standalone iOS test runners have no Keychain entitlement, -34018). Notes for review: `StoredCardModelActor` owns a single background context for reads *and* writes — mainContext cross-context merge timing is not deterministic on the iOS 17 floor, so the store's read-your-writes guarantee lives in one context; `SecItem*` calls sit behind `KeychainSessionProtocol` (Day 5 seam pattern) with `SecurityKeychainSession` as the real session; `CardRepository.addCard` maps an offer to a provisional local `Card` (empty holder/last-4) until the §11.4 issuance contract lands — demo offers use the Day 8 mocks instead.

### Day 8 — Logging + shared mocks (M2)

- [x] `LoggingService` (OSLog-backed, maps Domain `LogLevel` → `OSLogType`; logs display-safe data only — last four digits, never card numbers) (architecture.md §7.2).
- [x] `MockCardRepository`, `MockOffersRepository`, `MockStatusRepository`, `MockActionRepository` in `NexusData/Mocks` (`#if DEBUG`): seed data, `shouldThrowError`/`shouldNeverComplete` knobs, call counts (architecture.md §9.5).
- [x] `MockSessionManager` + `MockEventGenerator` emitting synthetic `BankingEvent`s **through the same `parseEvent` path** as live data (architecture.md §11.2, §12.3).
- [x] Tests: mock failure modes; demo events decode through the real path.
- **Verify:** Mocks live only in `NexusData/Mocks` behind `#if DEBUG`; release build compiles them to empty. — done: full workspace TestPlan green on iPhone 17 (NexusData 159 tests/19 suites, Domain 159/20 — same counts via macOS `swift test`), zero build warnings on re-run (first-run noise was the documented dependency-scan set); `swift build -c release` compiles the `Mocks` target to empty (no public symbols in its object files) while `Logging` ships `LoggingService`; demo payloads are canonical JSON (`JSONEncoder.sortedKeys`) and decode through the real `CardStateDataSource`/`OffersDataSource` `parseEvent` path end to end over `MockSessionManager`.

### Day 9 — SharedUI + Navigation (M3)

- [x] Design tokens: `Spacing`, `Icons`, `ColorPalette`, and a single `Strings` enum via `String(localized:)` (architecture.md §9.4).
- [x] Shared components: `LoadingView`, `EmptyStateView`, `ErrorView`, `SessionStatusIndicator`, `WarningRow`, `InfoRow`, `DestructiveButton`, `BackToolbarItem`, `DisconnectedView`, `AppLoadingView`, `AppErrorView` (architecture.md §9.4).
- [x] `Router` + `Route` (Hashable, `.cardDetail(cardID:)`) in the dependency-free `Navigation` target (architecture.md §8).
- [x] `View+Extensions`, `Date+Extensions` (architecture.md §9.4).
- **Verify:** Builds green; `Navigation` imports nothing above Foundation/SwiftUI; components ship `#Preview`s. — done: full workspace TestPlan green on the iPhone 17 simulator (332 tests: 159 Domain + 159 Data + 13 NexusFeatures + 1 app, plus 1 UI launch test), zero build warnings after the first-build dependency-scan noise on a fresh DerivedData, `swiftformat` clean; branch rebased onto the post-M2 `main` (`775b479`); design tokens split into a dedicated `Design` target (`ColorPalette`/`Spacing`/`Icons`/`Strings`) with `SharedUI` depending on it, and `NexusFeatures` made iOS-only — the CI package step builds it for the iOS simulator triple instead of macOS (architecture.md §3, §9.4 updated); 9 Router/Route tests + 4 date-helper tests replace the M3 smoke suite.

### Day 10 — Dashboard model + view (M4)

- [x] `DashboardModel`: `@MainActor @Observable`, `viewState` (loading/loaded/error/empty), idempotent `load()`, per-card live subscription `Task`s owned by the model (architecture.md §9.1).
- [x] `DashboardViewState` Equatable enum with `errorMessage`/`recoverySuggestion` (architecture.md §9.2).
- [x] `DashboardView` switches on `viewState`; `@Environment(DashboardModel.self)`; one-shot work via `.task`/`.refreshable` (architecture.md §9.3).
- [x] Preview factories `.preview`/`.emptyPreview`/`.loadingPreview`/`.errorPreview` over the shared mock repositories (architecture.md §9.5).
- [x] Model tests: state transitions, call counts, loading/error knobs.
- **Verify:** Model + view tests green; no ViewModel layer, no `ObservableObject`. — done: full workspace TestPlan green on iPhone 17 (Domain 161 tests/20 suites, Data 156/19, Features 30/5 — incl. new Dashboard suites — plus 1 app smoke + 1 UI launch test), zero build warnings after the documented first-build noise, `swiftformat` clean; repository protocols strengthened to `Sendable` (architecture.md §4.2) so the `@MainActor` model can hand them to `async let`/subscription tasks — Data implementations already were `Sendable`, only Domain test doubles needed `@MainActor`; loaded screen is a minimal cards/offers content scaffold (the Day 11 carousel restyle), with `#Preview`s per state.

### Day 11 — Dashboard content + card carousel (M4)

- [x] Swipeable card carousel with card art, last-4 digits, status indicators (active/frozen/expired) (features.md — Card Dashboard).
- [x] Offers row: add an offer → becomes a managed card via `CardRepository.addCard` (architecture.md §4.4 example).
- [x] Dark/light appearance; haptic feedback on card actions; Dynamic Type + VoiceOver pass (features.md — UX).
- [x] UI tests: `-demoMode` renders ready state; `-demoState=error`/`-demoState=loading` knobs drive the mock repositories (architecture.md §10).
- **Verify:** UI tests green on the iPhone 17 simulator; carousel accessible. — done: full workspace TestPlan green on iPhone 17 (Domain 161 tests/20 suites, Data 156/19, Features 36/5, 1 app smoke, 4 UI tests in `DashboardUITests` — ready/error/loading states + add-offer flow, replacing the Day 1 launch smoke), zero build warnings (second-run clean; first-run set was the documented dependency-scan noise), `swiftformat` clean, Release build compiles the DEBUG-only demo root out; appspec §2.1 records the M4 behavior decisions (paged carousel in repository order, per-`CardType` art via `ColorPalette.CardArt` + `CardArtwork`, direct offer→card add with transient-error alert, haptics on add success/failure). Coverage note: the UI tests assert the accessibility surface (labels/values/identifiers) and the add flow; haptics ride model signals asserted in unit tests — the physical haptic feel and the full visual Dynamic Type/VoiceOver pass are Day 15 human QA.

### Day 12 — Card detail & controls (M5)

- [x] `CardDetailModel`/`CardDetailView` reachable via `router.navigateTo(.cardDetail(cardID:))`.
- [x] Freeze/unfreeze via `CardActionRepository` + `CardCommand`; report lost/stolen; request replacement; replacement-request tracking (features.md — Card Controls/Replacement Tracking).
- [x] Spending limits: display and set daily/weekly/monthly per card via `CardCommand.setSpendingLimit` (architecture.md §4.1, §11.4).
- [x] Live status updates through the `CardStatusRepository` subscription (architecture.md §9.1).
- [x] Tests: freeze/unfreeze/lost/replacement state transitions; error paths; UI test for the freeze flow.
- **Verify:** Control flows green; freeze state survives model reload (persisted via repository). — done: full workspace TestPlan green on iPhone 17 (Domain 161 tests/20 suites, Data 166/19 — incl. new `MockCommandCoordinator` + mock-hook tests — Features 65/6 — incl. new `CardDetailModelTests` suite — 1 app smoke, 6 UI tests: 4 Dashboard + 2 new `CardDetailUITests`), zero build warnings, `swiftformat` clean. Notes for review: `MockCommandCoordinator` plays the backend echo in demo/tests (freeze→frozen etc. publishes through `MockStatusRepository.publish` + mirrors the store; `requestReplacement` mints a replacement offer for the dashboard §4.4 add path; `setSpendingLimit` persists the card-level amount) and is owned by the interim `DemoGraph` in `Nexus/DemoRootView.swift`, which now binds the shared `Router` + route→view mapping (Day 14 `AppContainer` takes over; card tap on the carousel front pushes detail); `CardDetail` product added to the `NexusUITests` target (pbxproj) for the shared accessibility namespace; appspec §2.2 records the M5 decisions (optimistic apply + idempotent stream reconcile, lost/stolen → `lost` with distinct commands, per-period limit ledger + card-level current limit; limit-window semantics deferred to the backend contract).

### Day 13 — Balances & transactions (M6)

- [x] Balance display (current/available/credit limit) with live updates from the event stream (features.md — Real-Time Balances).
- [x] `TransactionHistoryModel`: recent + pending transactions; search/filter by date range, category, amount, status (features.md — Search & Filter).
- [x] Transaction details view: merchant info, location, transaction ID (features.md — Transaction Details).
- [x] Tests: filter/search logic; live balance updates; UI test for history + filter.
- **Verify:** Balances and transactions green; live events update state without polling. — done: full workspace TestPlan green on iPhone 17 (Domain 161 tests/20 suites, Data 179/20 — incl. new balance/transaction source tests — Features 86/9 — incl. new filter/history/detail suites — 1 app smoke, 8 UI tests: 4 Dashboard + 2 CardDetail + 2 new `TransactionsUITests`), zero build warnings, `swiftformat` clean. Notes for review: account activity is per-card — Card Detail's new “Transactions” row pushes the history screen, which carries the live balance header above the feed (entry-point decision recorded in appspec §2.3); new `Transactions` NexusFeatures target + `Transactions` product wired into the app and UI-test targets (pbxproj); `BalanceRepositoryProtocol`/`TransactionRepositoryProtocol` + `CardBalanceDataSource`/`CardTransactionsDataSource` (per-kind parse on `card.events.{id}`, feed dedupes by id, bounded at 100) + repositories + mocks; search/filter semantics (search text, category/status/date presets, amount magnitude) live in the pure `TransactionQuery` rule; the transaction detail is a snapshot view with a `missing` state for stale links; appspec §2.3 records all M6 decisions.

### Day 14 — Composition root + demo mode (M7)

- [ ] `NexusApp` creates `AppContainer` once (architecture.md §11.1).
- [ ] `AppContainer`: `Mode` (live/demo), inline `createDependencies()`, `appState`, `sessionStatus` computed pass-through, `retry()`/`reinitialize()`, `handleSessionStatusChange(_:)` driven by `.onChange` — no polling (architecture.md §11.2–11.3).
- [ ] `AppState` enum + `ContentView` switch; `MainNavigationView` binds `Router.routes` to `NavigationStack`; route→view mapping lives in the app target (architecture.md §11.3, §8).
- [ ] `AppContainer+Preview` for each state (architecture.md §9.5).
- [ ] Demo mode rules: `#if DEBUG` only, no network/Keychain/disk; reset-demo action; "Nexus Demo" scheme; `API_ENVIRONMENT = demo` auto-selects demo (architecture.md §11.2).
- [ ] Integration tests: container builds both modes; state transitions.
- **Verify:** App runs end-to-end in demo mode with no backend; release build ignores `-demoMode`.

### Day 15 — v1.0 hardening (M8)

- [ ] Full test sweep: unit + integration + UI via the workspace TestPlan; CI green (architecture.md §10).
- [ ] Verify architecture invariants (§13 Step 8): no upward imports/cycles; zero `@unchecked Sendable`; one `AppError`; no `Result` at boundaries; models own + cancel subscription tasks; no sensitive data in logs/caches/configs.
- [ ] Accessibility pass (Dynamic Type, VoiceOver) across the v1.0 screens.
- [ ] Write `README.md` and `CHANGELOG.md` (v1.0 section).
- **Exit:** **v1.0 shippable** — core cards, controls, balances, transactions, demo mode all working with no backend.

---

## Phase B — v1.1 Payments & Security (Days 16–21)

### Day 16 — Payments domain + data (M9)

- [ ] Entities: `Payment`, payment status, payment amount validation (minimum/full/custom; `AppError.insufficientFunds`) (architecture.md §5).
- [ ] `PaymentRepositoryProtocol` + implementation: validate, submit via session `send` for the payment command, surface `AppError` (architecture.md §11.4 pattern).
- [ ] Tests: amount validation rules; insufficient funds; repository error wrapping.
- **Verify:** Payments domain/data green; new protocol lives in Domain, implementation in Data.

### Day 17 — Payments UI (M9)

- [ ] `PaymentsModel`/`PaymentsView`: pay minimum/full/custom amount from a linked account (features.md — Credit Card Payments).
- [ ] Confirmation screen + receipt view (features.md — Payment Confirmation).
- [ ] Loading/success/error states; haptics; accessibility.
- [ ] Tests: model state transitions; UI tests (`-demoMode`) for a full payment flow.
- **Verify:** Payment flow green end to end in demo mode.

### Day 18 — Biometric auth (M10)

- [ ] `BiometricAuthServiceProtocol` (Domain) + LocalAuthentication-backed implementation; mock authenticator for previews/tests (features.md — Biometric Authentication).
- [ ] Biometric login on launch; biometric approval for sensitive actions (payments, PIN) (features.md — Biometric Login).
- [ ] Tests: success/failure/not-available paths; denial flow.
- **Verify:** Auth tests green; no sensitive data passed to or logged by the biometric layer.

### Day 19 — App lock + session timeout (M10)

- [ ] App lock: auto-lock on background, re-authentication gate (features.md — App Lock).
- [ ] Session timeout: auto-logout after inactivity (2 minutes) (features.md — Session Timeout).
- [ ] Integrate lock/timeout states into `AppState` + `ContentView` (architecture.md §11.3 pattern).
- [ ] Tests: background/foreground transitions; timeout timer; re-auth success/failure.
- **Verify:** Lock/timeout flows green; session state remains observation-driven (no polling).

### Day 20 — Secure PIN entry + PIN management (M10)

- [ ] Custom numeric keypad with obfuscation (features.md — Secure PIN Entry).
- [ ] View PIN (biometric-protected); change/reset PIN with verification; `PINStore` backed by Keychain (architecture.md §6.4).
- [ ] Tests: PIN validation, change/reset flows; assert no PIN ever appears in logs or stores outside Keychain.
- **Verify:** PIN flows green; security invariants hold.

### Day 21 — v1.1 hardening (M11)

- [ ] Security review: no plaintext PINs/tokens anywhere; Keychain only; no sensitive logging.
- [ ] Full test sweep + CI green; docs updated (README, CHANGELOG v1.1).
- **Exit:** **v1.1 shippable** — payments and security complete and reviewed.

---

## Phase C — v1.2 iOS Integrations, Alerts & Insights (Days 22–28)

### Day 22 — Apple Pay provisioning (M12)

- [ ] "Add to Apple Wallet" via `PKAddPaymentPassViewController` (In-App Provisioning) behind a protocol seam so it is testable (features.md — Apple Pay Provisioning).
- [ ] Card eligibility check + provisioning state model; pass activation state handling.
- [ ] Tests: eligibility and state transitions with a mocked provisioning service.
- **Verify:** Provisioning flow builds and runs in demo/simulator where the API allows.

### Day 23 — Wallet issuer extension (M12)

- [ ] New `NexusWalletExtension` extension target — **extends the module map in architecture.md §3; update that doc with this day's change** (features.md — Apple Wallet Issuer Extension).
- [ ] Discover/import cards from the Wallet app; app group + shared model access.
- [ ] Verification on device/simulator where possible; document what needs a device.
- **Verify:** Extension builds; architecture.md §3 reflects the new target.

### Day 24 — Real-time alerts (M13)

- [ ] Push notifications via APNs; demo path uses `simctl push` (features.md — Real-Time Alerts).
- [ ] Alert center + alert model: large purchases, low balance; alerts generated from the live event streams (architecture.md §6.1 pattern).
- [ ] Tests: alert generation from events; notification payload handling.
- **Verify:** Alert flow green in demo; release path documented as backend-dependent.

### Day 25 — Virtual cards + personalization (M14)

- [ ] Generate virtual card numbers for online purchases (features.md — Virtual Card Numbers).
- [ ] Card personalization: color/design/theme for virtual cards, persisted via SwiftData settings (features.md — Card Personalization; architecture.md §6.4).
- [ ] Tests: virtual card generation rules; settings persistence round-trip.
- **Verify:** Virtual card + personalization flows green.

### Day 26 — Insights (M15)

- [ ] `InsightsModel`/`InsightsView`: spending by category/merchant and trends computed from transaction history (features.md — Insights & Tools).
- [ ] Charts; dark/light support; accessibility.
- [ ] Tests: aggregation logic correctness (empty history, pending transactions, rounding).
- **Verify:** Insights tests green; aggregation handles empty/edge data.

### Day 27 — v1.2 hardening (M16)

- [ ] Full integration sweep across all features; full TestPlan green; CI green.
- [ ] Re-verify architecture invariants (§13 Step 8); accessibility pass.
- [ ] Update `architecture.md` for any new targets/protocols/patterns that landed (payments, security, Apple Pay, alerts) if they changed the blueprint.
- **Verify:** Everything green; docs reflect the shipped architecture.

### Day 28 — Release readiness (M17)

- [ ] Final QA pass: full demo walkthrough, reset-demo, all loading/error/empty states.
- [ ] Docs: README (complete feature list), CHANGELOG (v1.2), roadmap status update.
- [ ] Optional: App Store checklist review (privacy, permissions, release notes).
- **Exit:** **v1.2 shippable** — full `features.md` feature set.

---

## Notes

- If a day overflows, split the branch and carry the remainder to the next day — never merge red, never stretch a branch past one day.
- The milestone table in `ROADMAP.md` is the source of truth for scope; keep `tasks.md` in sync when either changes.
- Git is initialized by the user **after** ROADMAP.md and tasks.md are approved — Day 1 assumes the repo exists.
