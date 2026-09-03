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
- **Status:** not yet specified — fill at M4 (Days 10–11).
- **Scope pointer:** features.md §Core Features (Card Dashboard, Card
  Personalization); tasks.md Days 10–11; architecture.md §9 (Dashboard
  model/view), §11.4 (CardOffer → Card add path).
- **Open decisions to record here at M4:** carousel behavior (swipe
  boundaries, reorder?), card art variants, offer→card add confirmation.

### 2.2 Card Controls — freeze/unfreeze, lost/stolen, replacement, spending limits
- **Status:** draft — proposed defaults marked 🔶, confirm at M5 (Day 12).
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

1. *Freeze/unfreeze* — from Card Detail, tap the status control → confirm →
   command in-flight (`loading` state) → confirmed status arrives via the
   status subscription; on failure show the `error` view state with recovery.
   🔶 Default: unfreeze requires no extra auth in v1.0 (sensitive-action
   biometric gating arrives with M10 — revisit then).
2. *Report lost / stolen* — from Card Detail → report → card reaches `lost`
   🔶 (there is no separate `stolen` status — decide copy + behavior at M5)
   → user is offered a replacement.
3. *Request replacement* — sends `requestReplacement`; the replacement card
   becomes a managed card (CardOffer → Card path, architecture.md §4.4) and
   is tracked on the dashboard.
4. *Spending limits* — per card, choose period `daily | weekly | monthly`
   and amount in the card's currency; save sends `setSpendingLimit`.
   Dashboard/detail shows current spend vs. limit per period.

**Rules**

- 🔶 Transition validity (proposed — enforce in the model, test at M5):
  `freeze` only when `active`; `unfreeze` only when `frozen`; lost/stolen
  reporting only when not `expired` and not already `lost`; `expired` is
  terminal and never appears as a live update (assumption from demo mocks).
- 🔶 Limit window semantics (calendar day vs. rolling 24 h) and whether
  authorizations or settlements count — decide at M5 with the backend
  contract (§11.4).
- Every action is immediately visible in the repository store (execute()
  applies the change so later reads reflect it) and confirmed by the event
  stream — the UI must reconcile both without double-toasting or flicker.

**Acceptance criteria (M5, Day 12)**

- [ ] Freeze/unfreeze round-trip in `-demoMode`: control reflects the
      stream-confirmed status; reload keeps the state (repository store).
- [ ] Invalid transition is impossible from the UI and rejected by the model
      (unit test per row of the transition matrix).
- [ ] `AppError.cardActionFailed` renders the error state with a working
      retry; the card status is unchanged on failure.
- [ ] Spending-limit set persists across model reload; displayed per period
      in card currency.
- [ ] Report lost/stolen + replacement: dashboard tracks the new card; the
      old one stays `lost`.
- [ ] UI test (Swift Testing + `-demoMode`) covers the freeze flow and the
      failure knob (`shouldThrowError` mock).
- [ ] VoiceOver + Dynamic Type pass on all controls (features.md §UX).

**Rule of record:** Domain vocabulary + `CardActionRepositoryProtocol`
(code), Day 12 tests (tasks.md), and this section — keep the three in sync
in the M5 PR.

### 2.3 Balances & Transactions
- **Status:** not yet specified — fill at M6 (Day 13).
- **Scope pointer:** features.md §Balance & Transactions; tasks.md Day 13;
  architecture.md §9.1 (live subscription ownership).
- **Open decisions to record here at M6:** search/filter predicate
  semantics, pending vs. cleared handling, currency display, live-update
  UX for a visible transaction list.

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
