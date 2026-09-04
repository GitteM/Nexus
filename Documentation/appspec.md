# Nexus App Specification (appspec.md)

> **What this file is.** The **behavior contract** for the Nexus product: per
> feature, the business rules, user flows, and acceptance criteria that the
> code must satisfy. It refines the scope overview in
> [features.md](features.md) — it does not restate it.
>
> **Status (2026-09-03):** skeleton with one worked example — **Card
> Controls** (§2.2). Remaining sections fill in the same PR that implements
> each feature; see the status tag at the top of every section.
>
> **Precedence.** `features.md` wins on *scope*; this file wins on *behavior
> detail*; `architecture.md` wins on *patterns* (how things are built);
> `ROADMAP.md` §5 is the decision log. For shipped features, **code + tests
> are the rule of record**: update this file in the same PR that implements
> or changes the behavior, and treat any contradiction here vs. `features.md`
> as a stale-doc bug to fix in that PR.

## 1. How to use this document

- **Agents (incl. DeepSeek in Codewhale):** read only the section for the
  feature you touch, plus this preamble. Do not read the whole file.
- **Before a feature milestone:** the section marked `not yet specified`
  must be drafted in the milestone PR (per `tasks.md` Definition of Done,
  docs stay in sync).
- **Tags:** `not yet specified` — fill at implementation ·
  `draft` — proposed defaults (provisional picks marked 🔶), confirm when the feature ships ·
  `specified` — matches shipped behavior (code + tests are the record).
- **Transitions:** `not yet specified` → `draft` happens in the milestone
  PR that authors the section; `draft` → `specified` only when the feature
  ships and its acceptance criteria pass (code + tests are the record).

## 2. Feature specifications

### 2.1 Card Management — dashboard, carousel, offers
- **Status:** M4 (Days 10–11) settled — model contract and Day 11
  dashboard behaviors below are pinned by code + tests; card controls land
  at M5 (§2.2).
- **Scope pointer:** features.md §Core Features (Card Dashboard, Card
  Personalization); tasks.md Days 10–11; architecture.md §9 (Dashboard
  model/view), §11.4 (CardOffer → Card add path).

**Model contract (Days 10–11, pinned by tests):**

- `DashboardModel` (MV model, no ViewModel layer) publishes `viewState`
  `{loading, loaded, empty, error(AppError)}`, `cards`, `offeredCards`,
  and `cardStates` (per-card live status).
- `.loaded` iff a successful fetch returned cards or offers; `.empty` only
  when both lists are empty (fresh account). `.error` carries the `AppError`
  with its `errorDescription`/`recoverySuggestion` projections.
- `load()` is idempotent: no-op once content is on screen or while a load
  is in flight; from `.error` it retries. `refresh()` is the force path
  (pull-to-refresh, empty-state refresh): it never blanks on-screen content
  and keeps the last good data if the refresh fails.
- Per-card live subscriptions are owned by the model (one task per card,
  started on load, cancelled when the card leaves the list or the model
  deallocates); each `CardState` updates `cardStates` and the matching
  card's effective status via `Card.withStatus`.
- Views switch on `viewState`; one-shot work is view-triggered
  (`.task`/`.refreshable`).
- `addOffer(_:)` is the offer→card operation: one model method over one
  repository (`CardRepositoryProtocol.addCard`, architecture.md §4.4). On
  success the returned card is appended to `cards`, its live subscription
  starts, and the offer leaves `offeredCards`. In-flight adds are tracked
  per offer (`offersBeingAdded`); a failed add sets a transient
  `addOfferError` (never blanks `.loaded` content); `dismissAddOfferError()`
  clears it.

**Day 11 dashboard behaviors (pinned by code + tests):**

1. *Card carousel* — a paged `TabView`, one card front per managed card, in
   repository order (no manual reorder in v1.0). Swipe to change page;
   custom dots below the art; VoiceOver reads each front as one element
   ("Credit card ending in 4821, Active", value "Card 1 of 6") with an
   adjustable action to page up/down. The front shows the live status
   (chip drawn from `card.status`, so `CardState` updates repaint it).
2. *Card art* — a physical-card look, per `CardType` gradient
   (`ColorPalette.CardArt` + `CardArtwork` in SharedUI, reused by later
   card screens) with fixed white on-art text; same art in dark and light
   (appearance support comes from the chrome around it). Height scales with
   Dynamic Type. Only display-safe data is drawn: the last four digits, or
   the type name for a provisioned card with no number yet — no PAN is
   ever fabricated or rendered.
3. *Offers row* — a horizontal row of offer mini-cards (type art + title +
   subtitle) with an explicit add action. No confirmation sheet: Add calls
   `addOffer` directly; the button shows a spinner while in flight and the
   offer disappears from the catalog on success. An offer whose id is
   already managed renders as "Added" (disabled) — the repository is the
   duplicate rule's owner and throws `cardAlreadyExists` if asked.
4. *Failure UX* — a failed add surfaces the `AppError` (headline +
   recovery guidance) in an alert; the loaded dashboard content stays on
   screen. Success/failure haptics ride the model's `lastAddedCardID` /
   `addOfferError` signals (`.sensoryFeedback`, features.md §UX).
5. *UI-test harness* — the dashboard UI suite launches with `-demoMode` and
   the `-demoState=ready|loading|error` knobs, which drive the shared mock
   repositories (architecture.md §10). **Interim app-target note:** Day 11
   adds a small DEBUG-only `DemoRootView` (Nexus/DemoRootView.swift) that
   parses the launch arguments and builds the dashboard over the mocks;
   Day 14's `AppContainer` replaces it — it is not a shipped pattern.

**Rule of record:** `DashboardModel` code + tests (Day 10–11),
`DashboardView`/carousel/offers code + UI tests, and this section — keep
in sync in the M4 PR.

### 2.2 Card Controls — freeze/unfreeze, lost/stolen, replacement, spending limits
- **Status:** M5 (Day 12) settled — behaviors below are pinned by code +
  tests; every 🔶 draft default is resolved as marked. Day 12 ships the
  dashboard→detail navigation, the card-control flows, and the freeze UI
  round trip.
- **In scope:** freeze/unfreeze, report lost/stolen, request replacement,
  spending-limit display and set. **Not in scope:** PIN management (M10),
  Apple Pay (M12), virtual cards (M14).
- **Vocabulary (pinned by Domain — do not change lightly):** statuses
  `CardStatus {active, frozen, expired, lost}`; commands `CardCommandType
  {freeze, unfreeze, reportLost, reportStolen, requestReplacement,
  setSpendingLimit}`; `CardCommand` carries `amount` + `period` payload only
  for `.setSpendingLimit`. Errors surface as `AppError.cardActionFailed` (or
  more specific) from `CardActionRepositoryProtocol.execute`.
- **Live state:** status changes arrive on `card.events.{cardId}` and decode
  to `CardState`; `subscribeToCardStatus` yields the current state first,
  then updates (architecture.md §11.4).

**Flows**

1. *Freeze/unfreeze* — from Card Detail, tap the status control → confirm
   dialog → execute. **Settled:** the new status applies immediately on
   execute success (repository-store rule) and the live subscription
   reconciles idempotently when the stream frame arrives — no flicker, no
   double signal; in-flight is bounded to the `execute` call
   (`pendingAction` disables every control while set). A failure surfaces a
   transient `actionError` alert and the card is unchanged; `viewState`
   stays `.loaded`. Settled: unfreeze needs no extra auth in v1.0
   (sensitive-action biometric gating arrives with M10 — revisit then).
2. *Report lost / stolen* — from Card Detail → a confirm dialog offers the
   two options → the card reaches `lost`. **Settled:** there is no separate
   `stolen` status — `reportLost` and `reportStolen` are distinct commands
   for the backend record but both land on `lost` (features copy: “Report
   lost or stolen”). The lost card then offers a replacement.
3. *Request replacement* — from the lost-card state (once), sends
   `requestReplacement`; the demo/test backend echo (`MockCommandCoordinator`)
   mints a replacement `CardOffer` (same type + currency) into the offers
   store, and the dashboard's offer→card add path (architecture.md §4.4)
   turns it into a managed card. The old card stays `lost`.
4. *Spending limits* — per card, choose period `daily | weekly | monthly`
   and amount in the card's currency; save sends `setSpendingLimit`.
   **Settled:** the screen shows per-period rows (fed by the model's
   in-session ledger) plus the card-level current limit
   (`Card.spendingLimit`), which the demo store mirrors so it survives a
   reload. The wire has no limit-read contract yet — the ledger is
   session-local and the backend limit stream stays an open item (§11.4).

**Rules**

- Transition validity — **settled and enforced in `CardDetailModel`**, every
  row of the matrix unit-tested (an invalid transition is a silent no-op and
  the UI never offers it): `freeze` only when `active`; `unfreeze` only when
  `frozen`; lost/stolen reporting only when the card is neither `expired`
  nor already `lost`; `expired` is terminal and never appears as a live
  update; `requestReplacement` only after `lost` and only once; limit
  changes only for a working card (`active`/`frozen`) and a positive amount.
- Limit window semantics (calendar day vs. rolling 24 h) and whether
  authorizations or settlements count still need the backend contract (§11.4)
  — recorded as an open item, not a v1.0 demo blocker.
- Every action is immediately visible (execute success applies the change —
  repository-store rule) and confirmed by the event stream; the model
  reconciles both idempotently without double-toasting or flicker. In demo
  mode and tests the echo is played by `MockCommandCoordinator`
  (`MockActionRepository.onExecute` → status/limit/offers stores); the real
  action repository stays send-only and confirmation comes from
  `card.events.{cardId}` (architecture.md §11.4).

**Acceptance criteria (M5, Day 12) — all met:**

- [x] Freeze/unfreeze round-trip in `-demoMode`: control reflects the
      stream-confirmed status; reload keeps the state (repository store) —
      `CardDetailUITests.testFreezeRoundTripReflectsOnDetailAndDashboard`
      (freeze on detail, dashboard chip updates, reopen keeps Frozen).
- [x] Invalid transition is impossible from the UI and rejected by the model
      (unit test per row of the transition matrix) — `CardDetailModelTests`
      freeze/unfreeze/report/replacement rows.
- [x] `AppError.cardActionFailed` renders the error state with a working
      retry; the card status is unchanged on failure — model tests +
      `CardDetailUITests.testFreezeFailureLeavesTheCardActive`
      (`-demoActionState=error` knob).
- [x] Spending-limit set persists across model reload; displayed per period
      in card currency — model ledger tests; the demo store's card-level
      mirror survives reload (session ledger is v1.0-scoped, see above).
- [x] Report lost/stolen + replacement: dashboard tracks the new card; the
      old one stays `lost` — coordinator tests (offer minted once, card
      stays lost) + the existing dashboard add-offer path (Day 11).
- [x] UI test (Swift Testing + `-demoMode`) covers the freeze flow and the
      failure knob (`shouldThrowError` mock) — the two `CardDetailUITests`.
- [x] VoiceOver + Dynamic Type pass on all controls — status/action elements
      carry labels + identifiers; the full visual Dynamic Type/VoiceOver
      sweep remains Day 15 human QA (Day 11 convention).

**Implementation map:** `CardDetailModel` (+ `CardDetailViewState`,
`CardDetailAccessibility`), `CardDetailView`, `Strings.CardDetail`;
mock/test pairing `MockCommandCoordinator` + `MockActionRepository.onExecute`
(NexusData/Mocks); dashboard card-tap → `Router` → `.cardDetail(cardID:)`;
interim demo composition root `Nexus/DemoRootView.swift` (shared
`DemoGraph` + `Router` + route→view mapping) — Day 14's `AppContainer`
takes this over and this file is deleted there.

**Rule of record:** Domain vocabulary + `CardActionRepositoryProtocol`
(code), Day 12 tests (tasks.md), and this section — keep the three in sync
in the M5 PR.

### 2.3 Balances & Transactions
- **Status:** M6 (Day 13) settled — behaviors below are pinned by code +
  tests; every open item resolved as marked.
- **Scope pointer:** features.md §Balance & Transactions; tasks.md Day 13;
  architecture.md §9.1 (live subscription ownership), §4.2/§6.1
  (repository/source contract).

**Entry & placement (settled):** account activity is per-card. Card
Detail gains an “Account activity → Transactions” row that pushes the
per-card history screen; that screen carries the **live balance header**
(current, available, credit limit when present, card currency) above the
searchable/filterable feed. A card-wide balance widget on the dashboard is
out of M6 scope (recorded for a later milestone).

**Data contract (M6, new protocols):** `BalanceRepositoryProtocol` (latest
per-card value + subscription) and `TransactionRepositoryProtocol`
(newest-first feed list + subscription) mirror the status boundary.
`CardBalanceDataSource` and `CardTransactionsDataSource` subscribe on
`card.events.{cardId}` and parse only their own payload kind, skipping
others (the §6.1 per-kind contract). The transaction feed replaces a frame
with the same id in place (pending → cleared) and is bounded
(`defaultFeedLimit = 100`, oldest dropped). Demo mocks seed the credit
card (balance + the 9-transaction mock set) and expose `publish` for live
updates; no balance/transaction command echo exists in v1.0 (nothing
changes them until Payments, M9).

**Search & filter semantics (settled, pinned by `TransactionQuery`
unit tests):** free-text search over merchant and transaction id
(case-insensitive); category and status are exact matches; date presets
all / 7 / 30 / 90 days relative to now; amount filters apply to the
*magnitude* (a €129.99 spend is “€100–300”, a €45 refund is not).
Ordering stays newest-first and the query never mutates the source list.
The UI surfaces search, category/status/date menus, and Clear filters;
the amount-range API is implemented and unit-tested but not surfaced in
the v1.0 UI (recorded).

**Display & live semantics (settled):** pending rows show a Pending
marker; refunds render as a positive signed amount. The history model
subscribes to the balance and the feed after its first load — frames
update state in place, never blank the screen, no polling; a reload keeps
the state through the repository stores. The transaction detail is a
snapshot deep view (merchant, signed amount, category, status, date,
optional location, selectable transaction id); a stale deep link whose
transaction left the feed renders a “missing” empty state, not an error.

**Acceptance criteria (M6, Day 13) — all met:**

- [x] Live balance updates without polling — model + data-source tests
      (publish → header updates; viewState stays `.loaded`).
- [x] Filter/search logic — `TransactionQuery` pure-filter suite + model
      query tests (search, category, status, date window, amount,
      combined, clear).
- [x] Transaction details — `TransactionDetailModel`/View tests (found /
      missing / error / retry) + UI navigation test.
- [x] UI test for history + filter — `TransactionsUITests`
      (balance header, feed row → detail, search narrows the list).
- [x] VoiceOver + Dynamic Type on the new controls — combined row elements
      with identifiers + labels; full visual sweep remains Day 15 human QA
      (Day 11 convention).

**Implementation map:** Domain protocols (`BalanceRepositoryProtocol`,
`TransactionRepositoryProtocol`); Data sources/repositories + mocks;
NexusFeatures `Transactions` target (`TransactionFilter`,
`TransactionHistoryModel`/`View`, `TransactionDetailModel`/`View`, a11y
namespace, previews); Route cases + app-target DemoGraph wiring; `Strings`
/`Icons` additions; `CardDetail` entry row.

### 2.4 Payments
- **Status:** not yet specified — fill at M9 (Days 16–17).
- **Scope pointer:** features.md §Payments; tasks.md Days 16–17.
- **Open decisions to record here at M9:** minimum/full/custom validation
  rules, confirmation + receipt content, insufficient-funds handling.

### 2.5 Security — biometrics, app lock, timeout, PIN
- **Status:** not yet specified — fill at M10 (Days 18–20).
- **Scope pointer:** features.md §Security; tasks.md Days 18–20.
- **Open decisions to record here at M10:** PIN length/retry policy, timeout
  duration (features.md says "e.g. 2 minutes"), which actions require
  biometric re-approval (see §2.2 🔶 above), lock behavior on backgrounding.
- **Data-handling constraints** (do not duplicate here — architecture.md
  §13 Step 8 owns them): Keychain-only credentials, no plaintext card
  data/tokens in logs, caches, or configs.

### 2.6 iOS Integrations — Apple Pay, Wallet extension
- **Status:** not yet specified — fill at M12 (Days 22–23).
- **Scope pointer:** features.md §iOS-Specific Integrations; tasks.md Days
  22–23 (adds the `NexusWalletExtension` target — update architecture.md §3
  then).

### 2.7 Alerts & Insights
- **Status:** not yet specified — fill at M13–M15 (Days 24–26).
- **Scope pointer:** features.md §Controls & Alerts, §Insights & Tools;
  tasks.md Days 24–26.
- **Open decisions to record here at M13:** alert thresholds ("large
  purchase" = what amount?), low-balance rule, alert center behavior.

### 2.8 UX/UI — appearance, haptics, accessibility
- **Status:** not yet specified — cross-cutting; fill per feature, first
  pass at M4.
- **Scope pointer:** features.md §UX/UI; tasks.md Days 11, 15, 27.
- **Constraints owned elsewhere:** architecture.md §9.4 (design tokens,
  strings), §13 Step 8 (a11y invariants).

### 2.9 Demo mode & data
- **Status:** not yet specified — fill at M7 (Day 14).
- **Scope pointer:** features.md §Demo-Specific Features; architecture.md
  §11.2 demo-mode rules; ROADMAP.md §5 (demo is in-memory — no
  network/Keychain/disk).
- **Open decisions to record here at M7:** demo dataset contents (mock
  cards/transactions/offers in EUR), `-demoState` knobs, reset-demo UX.

## 3. Non-goals (for now)

Real backend, real push infrastructure, third-party banking SDK, App Store
submission, localization beyond English, macOS/multi-platform — same list as
ROADMAP.md §4 (out of scope); keep that list single-sourced there.
