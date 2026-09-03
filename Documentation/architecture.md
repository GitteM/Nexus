# Nexus Architecture Blueprint — Reusable Documentation

> **Purpose.** This document describes the architecture of **Nexus**, a SwiftUI /
> Swift 6.3 iOS banking app focused on **cards and their features** (issuing,
> freezing/unfreezing, spending limits, live balances and transaction
> updates), in enough detail that an LLM (or engineer) can replicate the *same
> architecture* in a **different project** — different domain, different data
> source, different UI.
>
> It is written as a *porting guide*, not a review: every section states the
> pattern, the rule, and the concrete template to copy.
>
> **Revision note.** This blueprint is the **MV revision**: `@Observable`
> models replace the earlier store/ViewModel-style layer, the use-case
> pass-through layer and the factory ladder were deleted, repositories throw
> instead of returning `Result`, session state is observation-driven (no
> polling), and the app is three packages plus a thin app target. §12
> documents what was cut and why.
>
> **Toolchain note (Xcode 26).** This revision targets **Xcode 26.6 / Swift
> 6.3** (iOS 26.5 SDK) with an **iOS 17 deployment floor**: every pattern here
> works on iOS 17, and iOS 18+ additionally unlocks SwiftData macros
> (`#Index`, `#Unique`, `@ModelActor`) and `@Entry`. Swift 6.2+'s opt-in
> **default actor isolation** can remove most `@MainActor` annotations; this
> document keeps them explicit so the snippets port to projects that do not
> enable it (§3, §12.3).

> **Reading guide for agents (incl. DeepSeek in Codewhale).** This is a
> 1,300-line porting guide — for work *inside* Nexus, read only the section
> for the layer you touch (§3 module map, §4 Domain, §5 `AppError`, §6 Data,
> §7 config/logging, §8 navigation, §9 presentation, §11 app target), not
> the whole file. §14 is the one-paragraph summary for quick recall; §13
> Step 8 is the invariants checklist used to verify Nexus itself. The
> section map also lives in `AGENTS.md` and `.codewhale/instructions.md`.

---

## 1. What This Architecture Is

Nexus is an **MV (Model-View) architecture** app — SwiftUI views driven by
`@Observable` models — structured as **three Swift Package Manager packages**
plus a thin **app target** (composition root). It combines:

- **MV layering** — views are lightweight, declarative functions of
  observable model state; business logic lives in models, services, and
  repositories.
- **`@Observable` models (the "M")** — one `@MainActor @Observable` class per
  screen family, publishing an explicit view-state enum. There is **no
  ViewModel layer**.
- **Repository pattern** — Domain defines protocols; Data implements them.
- **Service orchestration** — a use case/service type exists only when it
  composes two or more collaborators (the default is a model method).
- **Constructor-based dependency injection** — a single composition root
  builds the graph; app-wide services reach views via `@Environment`.
- **Async/await + actors + AsyncStream** — modern Swift concurrency for
  one-shot calls and live event streams. No completion handlers, no Combine.
- **Router pattern** — navigation state as a `[Route]` array bound to
  `NavigationStack`.

### When to use it

- You need a **long-lived, testable app** where the domain (business rules)
  must not depend on frameworks, SDKs, or UI.
- You have **live, event-driven data** (push notifications, WebSocket,
  server-sent events) mixed with one-shot API calls — e.g. balance updates
  and transaction alerts arriving in real time.
- You want **per-feature targets** that can be built and tested independently
  without paying for a package per layer.
- You need to **build the app before the backend exists** and connect it
  later — the protocol seam (§11.4) makes that a configuration flip, not a
  rewrite.
- You want an architecture that stays light as the app grows — every boundary
  here earns its keep (§12 lists the ones that were cut and why).

---

## 2. The Layering and the Dependency Rule

```
┌─────────────────────────────────────────────────────────────┐
│                      App Target (Nexus)                      │
│   Composition root • App entry • AppState • Route→View map   │
│   Root views • UI tests                                      │
├─────────────────────────────────────────────────────────────┤
│                    NexusFeatures                             │
│   SwiftUI Views • @Observable Models • SharedUI • Navigation │
├─────────────────────────────────────────────────────────────┤
│                    NexusData                                 │
│   Session • DataSources • Repositories • Persistence • Logs  │
├─────────────────────────────────────────────────────────────┤
│                    NexusDomain                               │
│   Entities • Repository/Service Protocols • AppError         │
└─────────────────────────────────────────────────────────────┘
```

**The dependency rule:** a layer may depend only on layers *below* it (or
laterally, on the same layer's other targets). **Domain depends on nothing.**

The direction of imports is the single most important rule to preserve when
porting. A dependency diagram of the packages as declared:

```
Nexus (app target)
  └── NexusFeatures ──► NexusData ──► NexusDomain
```

In practice the concrete types move *upward* only through protocols: Domain
declares `XRepositoryProtocol`, Data implements it, the composition root
injects it into a model. The app target is the only place that knows both a
concrete view and its dependencies.

---

## 3. Module Map (Packages and Targets)

Three packages live under `AppPackages/`; each package exports **multiple
small targets** so consumers import only what they need. There are **no
umbrella modules**.

| Package | Targets (libraries) | Depends on |
|---|---|---|
| **NexusDomain** | `Entities`, `RepositoryProtocols`, `ServiceProtocols` | nothing |
| **NexusData** | `Session`, `DataSources`, `Repositories`, `Persistence`, `Logging`, `Mocks` (`#if DEBUG`) | NexusDomain, networking SDK (only in `Session`) |
| **NexusFeatures** | `Design`, `SharedUI`, `Navigation`, `Dashboard`, `CardDetail` | NexusDomain, NexusData |
| **Nexus app target** | `Nexus`, `NexusTests`, `NexusUITests` | all three packages |

Notes on the map:

- Each package declares `swift-tools-version: 6.3` (Xcode 26.6, Swift 6
  language mode). `NexusDomain` and `NexusData` declare
  `platforms: [.iOS(.v17), .macOS(.v14)]` (the Data layer runs its test
  suite on macOS); **`NexusFeatures` is iOS-only** (`platforms: [.iOS(.v17)]`)
  — it carries SwiftUI components that use UIKit-backed system colors, so
  CI builds it for the iOS simulator rather than the host (pr-checks
  `packages` job). iOS 17 is the deployment floor; raise it to iOS 18 to
  unlock SwiftData macros and `@Entry` (§6.4, §9.4).
- **`Design` (in NexusFeatures) is the token home**: `ColorPalette`,
  `Spacing`, `Icons`, `Strings` live in their own dependency-free target so
  any UI consumer (components, screens, the app target) adopts the design
  language without importing components (§9.4).
- **No umbrella targets** — consumers import concrete targets
  (`import Entities`, `import CardDetail`). `@_exported` is private Swift API
  and was removed (§12.1).
- **Infrastructure is not a package.** Configuration lives in the app target;
  logging lives in NexusData. A package that exists only for plumbing is a
  tax, not a layer (§12.1).
- **`Mocks` (in NexusData) is the shared `#if DEBUG` home** for mock
  repositories, the mock session manager, and the demo event generator —
  consumed by previews, UI tests, and demo mode (§9.5, §11.2). Release
  builds compile it to empty.
- Tests live inside the owning package (`Tests/<Target>Tests/`) and are
  aggregated by a **TestPlan** at the workspace level (§10).
- **Swift 6.2+ default actor isolation (opt-in).** Add
  `swiftSettings: [.defaultIsolation(MainActor.self)]` per package to get
  MainActor-isolated-by-default code without writing `@MainActor`
  everywhere. Trade-off: background-safe types must then opt back out with
  `nonisolated`, and un-opted repository calls hop to the main actor. The
  snippets here keep explicit `@MainActor` so they port either way (§12.3).

---

## 4. Domain Layer — the Core

**Path:** `AppPackages/NexusDomain/Sources/{Entities, RepositoryProtocols,
ServiceProtocols}/`

**Rule:** Domain has **no UI, no persistence, no SDK, no Combine, no OSLog**.
It is pure Swift + Foundation.

### 4.1 Entities (`Entities` target)

Plain value types: `struct`, `Codable`, `Sendable`, `Equatable` where
possible. Every entity carries a public memberwise `init` (so other packages
can construct them) and, where useful, **static mock values** for previews and
tests.

```swift
public struct Card: Codable, Sendable, Equatable {
    public let id: String
    public let cardholderName: String
    public let lastFourDigits: String
    public let type: CardType          // .credit, .debit, .prepaid
    public let status: CardStatus      // .active, .frozen, .expired, .lost
    // ...
    public let spendingLimit: Decimal?
    public let currency: String

    public init(id: String, cardholderName: String, /* ... */) { /* ... */ }
}

public extension Card {
    static let mockCreditCard = Card(/* ... */)
    static var mockDefaults: [Card] { [.mockCreditCard, /* ... */] }
}
```

Entities seen in Nexus and their roles:

- `Card`, `CardOffer` — managed vs. offered cards (a card offer becomes a
  managed card when the user adds it).
- `CardState`, `Balance`, `Transaction`, `SpendingLimit` — typed, decoded live
  data.
- `CardType`, `CardStatus`, `SessionStatus` — small enums with `displayName`
  / `icon` conveniences.
- `BankingEvent` — the transport-neutral event value (`channel`, `payload`).
- `CardCommand`, `CardCommandType` — outgoing card actions (freeze, unfreeze,
  set spending limit).
- `AppError` (+ `ErrorCategory`) — the **single error type** for the whole
  app; see §5.
- `Settings` — user preferences (persisted via SwiftData, §6.4).

### 4.2 Repository protocols (`RepositoryProtocols` target)

One protocol per aggregate/concern. One-shot calls **throw**; subscriptions
return an **`AsyncStream`** and throw on setup failure. There is no `Result`
at this boundary — in async Swift, `throws` is the idiomatic failure channel
(the old `Result` + `throws` double style was eliminated, §12.1).

```swift
public protocol CardOffersRepositoryProtocol {
    func getAvailableOffers() async throws -> [CardOffer]
    func subscribeToOffers() async throws -> AsyncStream<[CardOffer]>
}

public protocol CardStatusRepositoryProtocol {
    func getCardStatus(cardId: String) async throws -> CardState?
    func subscribeToCardStatus(cardId: String) async throws
        -> AsyncStream<CardState>
}
```

Nexus has four repository protocols: `CardRepositoryProtocol`
(add/remove/list cards), `CardOffersRepositoryProtocol`,
`CardStatusRepositoryProtocol`, `CardActionRepositoryProtocol`.

### 4.3 Service protocols (`ServiceProtocols` target)

Abstractions for cross-cutting infrastructure the domain still needs to *name*.
Domain defines its own `LogLevel` (mapped to `OSLogType` inside the logging
implementation) and a **stream-based** session protocol — no completion
handlers anywhere:

```swift
public enum LogLevel: Sendable {
    case debug, info, notice, error, fault
}

public protocol LoggerProtocol: Sendable {
    func log(_ message: String, level: LogLevel)
}

public protocol SessionManagerProtocol: Sendable {
    var sessionStatus: SessionStatus { get }   // .connecting/.connected/.disconnected/.error
    func connect() async throws                // establish authenticated session
    func disconnect()
    func events(for channel: String) -> AsyncStream<BankingEvent>
    func send(to channel: String, payload: String) async throws
}
```

### 4.4 The use-case rule

**Rule: a use case (or service type) exists only when it composes two or more
collaborators.** A single repository call is a one-line model method — a
wrapper class, its factory slot, and its test target are pure ceremony. Nexus
currently has **zero** use cases: every operation is a model method over one
repository. The one place a use case *would* earn its existence is card
removal, which composes a repository call with a session side effect — and
even that fits in the model:

```swift
@MainActor
@Observable
public final class CardModel {   // lives in NexusFeatures (§9)
    public private(set) var cards: [Card] = []
    private let repository: CardRepositoryProtocol
    private let session: SessionManagerProtocol

    public func add(_ offer: CardOffer) async throws {
        let card = try await repository.addCard(offer)   // throws — no Result to unwrap
        cards.append(card)
    }

    public func remove(_ card: Card) async throws {
        // Two collaborators → extract a RemoveCardService if this grows.
        try await repository.removeCard(card.id)
        await session.unsubscribe(from: eventChannel(for: card))
    }
}
```

**Why this rule:** the previous plan's seven single-method use cases each
added a type, a constructor parameter, and a test target without adding
behavior. When a real composition appears, write it as a plain `final class`
taking protocols, with one `execute()`, and unit-test it like any service —
the criterion, not the layer, decides.

### 4.5 Importing

Consumers import the concrete targets they use (`import Entities`,
`import RepositoryProtocols`). No umbrella re-exports, no `@_exported`.

---

## 5. The Error Model — `AppError`

**The whole app speaks one error type.** Every layer throws or returns
`AppError`; never raw `Error` across boundaries, never `NSError`, never
SDK-specific types.

```swift
public enum AppError: Error, LocalizedError {
    case apiConnectionFailed(String? = nil)
    case cardNotFound(cardId: String)
    case cardAlreadyExists(cardId: String)
    case insufficientFunds(amount: Decimal)
    case persistenceError(operation: String, details: String? = nil)
    case serializationError(type: String, details: String? = nil)
    case validationError(field: String, reason: String)
    case unknown(underlying: Error? = nil)
    // ... grouped by category: network / card / account / data / system /
    //     initialization / unknown
}
```

It carries four computed surfaces used by every layer:

- `errorDescription` — user-facing message.
- `failureReason` — short technical reason.
- `recoverySuggestion` — the action a user could take.
- `category: ErrorCategory` — analytics/grouping.
- `isRecoverable`, `shouldReport` — policy flags.

It is `Equatable` via a hand-written comparison extension (Swift enums with
associated values get synthesis only if the payloads are Equatable; `Error?`
payloads need manual comparison).

**Conventions when porting:**

- Define *your* `AppError` in Domain (`Entities` target). Group cases by
  feature area, mirroring your architecture's categories.
- Decoding helpers wrap `DecodingError` into
  `AppError.deserializationError(type:details:)` with context (see the
  `JSONDecoder` extension in Data, §6.4).
- Repositories wrap lower-level errors and **augment the operation context**
  (e.g., `operation: "get_cards"`).
- Models map any thrown error to `AppError` with a fallback and decide
  whether the view state changes.
- Add a `#if DEBUG` `TestFactory` enum with factory methods for every case —
  tests and previews construct errors without stringly code.

---

## 6. Data Layer

**Path:** `AppPackages/NexusData/Sources/{Session, DataSources,
Repositories, Persistence, Logging}/`

**Rule:** Data implements the Domain protocols. It may import Domain and the
SDK (here the banking/network SDK) — it may *not* import NexusFeatures or the
app target.

### 6.1 Data sources (`DataSources` target) — transport & cache

The data source is the *furthest-out* object: it owns the live transport
(WebSocket / push / API) and an **in-memory cache** for what it has seen. Two
shapes appear:

- **Actor** for stateful streaming sources:

```swift
public actor CardStateDataSource: CardStateDataSourceProtocol {
    private let eventSubscriptionManager: EventSubscriptionManagerProtocol
    private var cardStatesCache: [String: CardState] = [:]
    private let logger: LoggerProtocol

    public func subscribeToCardStatus(cardId: String) async throws
        -> AsyncStream<CardState> {
        let source = eventSubscriptionManager.events(for: cardEventChannel(cardId))
        return AsyncStream { continuation in
            let task = Task {
                for await event in source {
                    guard let state = parseEvent(event) else { continue }
                    updateCardState(state)            // keep the per-id cache warm
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}
```

- **Struct** for stateless one-shot sources (`CardActionDataSource`).

Key details to preserve:

- Subscription methods **throw on setup failure** — a returned stream means
  "subscribed". (`AsyncStream` itself still cannot throw mid-stream; that
  limitation and its handling live in §12.3.)
- The actor's `parseEvent` normalizes raw payloads into typed entities and
  **keeps a per-id cache** so `getX(id:)` can answer immediately.
- Expiry/cleanup lives in the data source (offers cache drops stale entries
  after a few minutes).

### 6.2 The session manager — the one SDK-touching object

`APISessionManager` is an **`@MainActor @Observable final class`** conforming
to `SessionManagerProtocol`. It wraps the networking stack behind the Domain
protocol and is the *only* place that transport leaks:

**Default transport (no SDK required):** URLSession + async/await (REST) for
one-shot calls, and `URLSessionWebSocketTask` for the live event channel
(server-sent events as a fallback). A third-party banking SDK — when one
exists — is an *alternative adapter* implementing the same
`SessionManagerProtocol`; the app is built against the protocol either way
(§11.4).

```swift
@MainActor
@Observable
public final class APISessionManager: @preconcurrency SessionManagerProtocol {
    public private(set) var sessionStatus: SessionStatus = .disconnected
    // SDK delegate/callback → hop to MainActor → continuation.yield(event)
    // Pending-subscription queue on reconnect: plain state, no barrier queue.
}
```

Rules:

- `sessionStatus` is the only public read and is consumed by UI — so the
  whole object lives on the main actor. **No `@unchecked Sendable`, no
  `DispatchQueue` barriers** — actor isolation *is* the synchronization.
  Swift 6.2+ conformance isolation: because the protocol inherits
  `Sendable`, the conformance must be marked `@preconcurrency` (an
  *isolated* conformance cannot carry `Sendable`) — see §12.3.
- `events(for:)` returns an `AsyncStream` whose continuation the SDK bridge
  yields into; `onTermination` cleans up the channel.
- `connect()` bridges the delegate callback into
  `withCheckedThrowingContinuation` (the canonical callback→async bridge).
- `EventSubscriptionManager` is a thin facade over it
  (`connect/disconnect/events(for:)/send`), which is what data sources
  receive — data sources never see the SDK directly.

**Trade-off:** every SDK event hops to the main actor. At banking-feed rates
(a few events/second) that is noise; if events ever become high-frequency,
promote this to an `actor` + `AsyncStream` at the boundary and let consumers
observe through the stream (§12.3).

### 6.3 Repositories (`Repositories` target)

Repositories are thin: they **hold a data source (or store) and validate and
wrap errors**. They add no business rules. All methods throw — the `Result`
wrapping was deleted with the use-case layer (§12.1).

```swift
public struct CardRepository: CardRepositoryProtocol {
    private let cacheManager: CacheManagerProtocol

    public func addCard(_ offer: CardOffer) async throws -> Card {
        // validate → check duplicates → build Card → persist via cacheManager
    }
}
```

### 6.4 Persistence (`Persistence` target) and utilities

Two storage tiers, one rule:

- **SwiftData for durable user data** (card list, preferences). `@Model`
  classes live in this target and **never cross the repository boundary** —
  they are classes, `@MainActor`-bound, and not `Sendable`. Repositories map
  them to the Domain structs:

```swift
@Model final class StoredCard {
    var id: String
    var cardholderName: String
    var lastFourDigits: String
    // ... never Sendable, never leaves NexusData
}

@MainActor
public struct SwiftDataCardRepository: CardRepositoryProtocol {
    private let container: ModelContainer

    public func getCards() async throws -> [Card] {
        try container.mainContext
            .fetch(FetchDescriptor<StoredCard>())
            .map { $0.toDomain() }          // domain sees only Codable structs
    }
    // add/remove map domain ↔ storage; background writes use @ModelActor
}
```

On the iOS 17 floor, `ModelContext` is used on the main actor and background
writes use a hand-written `ModelActor`; raising the floor to iOS 18 unlocks
the `@ModelActor` macro plus `#Index`/`#Unique` on `@Model` classes. Filtered
fetches use the `#Predicate` macro (iOS 17+).

- **An in-memory actor cache for ephemeral live state** (offers with TTL,
  streaming card states). `CacheManager` is an `actor` holding an `NSCache`
  (50 items / 25 MB) with TTL — no disk backing, no `@unchecked Sendable`.

**Banking-specific rules:** never persist raw card numbers, CVV, or auth
tokens to any cache or store in plaintext — credentials belong in the
**Keychain** (a `KeychainWrapper` lives in this target), and caches hold only
display-safe data (last four digits, balances, preferences).

`JSONDecoder+Extensions.swift` is a high-value utility: `decode(_:from:logger:
context:)` catches every `DecodingError` kind, logs it, and rethrows as
`AppError.deserializationError` with context. **Port this extension — it is
what keeps decoding errors in the AppError model.**

---

## 7. Configuration and Logging

**Infrastructure is not a package.** Configuration lives in the app target;
logging lives in NexusData. Both patterns are portable as written.

### 7.1 Configuration (app target)

Values flow **xcconfig → Info.plist → Bundle extension**:

```swift
// Debug.xcconfig / Release.xcconfig
API_BASE_URL = https://api.nexusbank.example   // leave empty until a backend exists
API_ENVIRONMENT = sandbox                      // sandbox | production | demo

// Info.plist
<key>API_BASE_URL</key><string>$(API_BASE_URL)</string>

// Bundle+Extension.swift
public extension Bundle {
    static let apiBaseURL: URL = {
        guard let string = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: string) else {
            fatalError("API_BASE_URL missing from Info.plist")
        }
        return url
    }()
}
```

No secrets in code, per-environment values via build configurations. Banking
credentials (tokens, PINs) never live in xcconfig or Info.plist — they are
held in the Keychain at runtime.

**No backend yet?** Set `API_ENVIRONMENT = demo` (and leave `API_BASE_URL`
empty) in the Debug configuration — `AppContainer` then defaults to demo
mode (§11.2) and the app runs entirely on the shared mocks. Switching to a
real backend is configuration + the §11.4 adapter checklist, nothing else.

### 7.2 Logging (`NexusData/Logging`)

`LoggingService` is an `OSLog`-backed type conforming to Domain's
`LoggerProtocol`, mapping the Domain `LogLevel` to `OSLogType`:

```swift
public struct LoggingService: LoggerProtocol {
    private let logger = Logger(subsystem: "com.nexusbank.app", category: "default")

    public func log(_ message: String, level: LogLevel) {
        let type: OSLogType = switch level {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .error: .error
        case .fault: .fault
        }
        logger.log(level: type, "\(message, privacy: .public)")
    }
}
```

Every layer receives a `LoggerProtocol` via initializer — **no global logging
calls in the codebase.** Never log card numbers or sensitive payloads — log
only display-safe identifiers (last four digits).

---

## 8. Navigation Layer and the Router Pattern

**Path:** `AppPackages/NexusFeatures/Sources/Navigation/`

The `Router` is a plain `@Observable` class holding a **stack of `Route`
values** — it has no knowledge of views, and the target depends on nothing but
SwiftUI/Foundation (no Presentation imports, no package cycle):

```swift
@Observable
public final class Router {
    public var routes: [Route] = []
    public func navigateTo(_ route: Route) { routes.append(route) }
    public func navigateBack() { guard !routes.isEmpty else { return }; routes.removeLast() }
    public func popToRoot() { routes.removeAll() }
    public func popTo(_ route: Route) { /* remove above index */ }
}
```

`Route` is a `Hashable` enum of **destinations, with data**. There is no
`.back` case — going back is an action, not a destination:

```swift
public enum Route: Hashable {
    case cardDetail(cardID: String)
}
```

The **route→view mapping lives in the app target** — the only place that knows
both routes and views:

```swift
extension Route {
    @ViewBuilder @MainActor
    var destination: some View {
        switch self {
        case .cardDetail(let cardID): CardDetailView(cardID: cardID)
        }
    }
}
```

The root view binds the stack:

```swift
@Environment(Router.self) private var router

var body: some View {
    @Bindable var router = router
    NavigationStack(path: $router.routes) {
        DashboardView()
            .navigationDestination(for: Route.self) { $0.destination }
    }
}
```

**Rules when porting:** `Route` is `Hashable` and carries data; the router is
injected via `.environment(Router.self)`; views navigate by calling
`router.navigateTo(.x)` or declaratively with `NavigationLink(value:)`; detail
views that must stay router-agnostic take an `onNavigate: (Route) -> Void`
closure instead of touching the router.

On iOS 26, `NavigationStack` + `navigationDestination(for:)` is unchanged and
remains the pattern. If the app ever grows tab-based chrome, iOS 26's new
`Tab`/`TabSection` API composes *around* the router: tabs become an outer
shell, and the router stays the navigation-state owner inside each tab.

---

## 9. Presentation Layer and the MV Pattern

**Path:** `AppPackages/NexusFeatures/Sources/{SharedUI, Navigation,
Dashboard, CardDetail}/`

The "V" is SwiftUI views; the "M" is `@Observable` models. There is no
ViewModel layer.

### 9.1 Models — the "M"

The model is the heart of a screen. Shape:

- `@MainActor @Observable final class`, named `…Model` (a store by any other
  name is a model).
- Constructor receives **repositories + services + logger only** (no use
  cases, no factories, no data sources).
- Publishes an explicit **`viewState` enum** (`loading / loaded / error /
  empty`) plus domain data arrays.
- Owns **long-lived subscription `Task`s** (per-card live streams) — the one
  justified place for model-owned tasks; one-shot work is `async` and
  view-triggered (§9.3).
- **No protocol** — concrete `@Observable` classes only. Substitutability
  comes from mocking at the repository boundary (§9.5).
- **No business rules** — it orchestrates repositories, mutates state, and
  maps errors to the view state.

```swift
@MainActor
@Observable
public final class DashboardModel {
    public private(set) var viewState: DashboardViewState = .loading
    public private(set) var cards: [Card] = []
    public private(set) var offeredCards: [CardOffer] = []
    public private(set) var cardStates: [String: CardState] = [:]

    private let cardRepository: CardRepositoryProtocol
    private let offersRepository: CardOffersRepositoryProtocol
    private let statusRepository: CardStatusRepositoryProtocol
    private var subscriptionTasks: [String: Task<Void, Never>] = [:]

    public func load() async {          // idempotent: safe to refire on every appear
        guard viewState != .loaded else { return }
        viewState = .loading
        do {
            async let cards = cardRepository.getCards()
            async let offers = offersRepository.getAvailableOffers()
            (self.cards, self.offeredCards) = try await (cards, offers)
            startLiveSubscriptions()
            viewState = .loaded
        } catch let error as AppError {
            viewState = .error(error)
        } catch {
            viewState = .error(.unknown(underlying: error))
        }
    }
}
```

Live subscriptions are **per-card `Task`s that `for await` an
`AsyncStream`** and write straight into the observable state — this is what
makes the UI update live:

```swift
private func startLiveSubscriptions() {
    for card in cards {
        let task = Task { @MainActor [weak self] in
            guard let stream = try? await statusRepository
                .subscribeToCardStatus(cardId: card.id) else { return }
            for await cardState in stream {
                guard !Task.isCancelled else { break }
                self?.cardStates[cardState.cardId] = cardState
                // also update card.status / lastUpdated
            }
        }
        subscriptionTasks[card.id] = task
    }
}
```

### 9.2 View state enums

`DashboardViewState` is an `Equatable` enum with convenience projections
(`errorMessage`, `recoverySuggestion`), mirrored at app level by `AppState`
(see §11). Views switch on it directly.

### 9.3 Views — the "V"

- **Screen views** (`DashboardView`, `CardDetailView`) are small: they
  switch on `model.viewState` and delegate to content components. Data-driven
  components (`DashboardContentView`) stay even smaller.
- `@Environment(DashboardModel.self)`, `@Environment(Router.self)` — models
  and router are injected by the environment, **never created in views**.
- One-shot async work goes through **`.task` / `.task(id:)` /
  `.refreshable`** — SwiftUI owns cancellation; the model never spawns
  one-shot tasks itself.
- `@State` for view-local UI state (search text, sheet flags); `@Bindable`
  for two-way binds into models. A complex local interaction can be a
  `@State` struct with mutating actions — that is view-owned state, not a
  ViewModel.
- Detail views take `onNavigate: (Route) -> Void` when they must stay
  router-agnostic.
- **Every view ships `#Preview`s** for every state using the mock strategy
  (§9.5).

```swift
struct DashboardView: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        switch model.viewState {
        case .loading:  LoadingView()
        case .loaded:   DashboardContent(model: model)   // composed components
        case let .error(error):
            ErrorView(error: error) { Task { await model.load() } }
        }
        .task { await model.load() }          // refires on appear; idempotent
        .refreshable { await model.load() }   // pull-to-refresh, free
    }
}
```

### 9.4 SharedUI

Presentation-layer UI lives in two NexusFeatures targets: the **`Design`**
target holds the design language, `SharedUI` holds components.

- **Design tokens (`Design` target — dependency-free):** `Spacing` (static
  CGFloat scale, `xs…section3`), `Icons` (SF Symbol names), `ColorPalette`
  (namespace; system colors resolve per platform/appearance here — the one
  place platform-backed values live), plus the **localization seam**: a
  single `Strings` enum using `String(localized:)` — all UI copy goes
  through it. Components and screens import `Design` directly.
- **Components (`SharedUI` target):** `LoadingView`, `EmptyStateView`,
  `ErrorView`, `SessionStatusIndicator`, `WarningRow`, `InfoRow`,
  `DestructiveButton`, `BackToolbarItem`, `DisconnectedView` (shown when
  the session drops), `AppLoadingView`, `AppErrorView`.
- **Extensions (`SharedUI`):** `View+Extensions` (row-tap helper, etc.),
  `Date+Extensions`.
- **iOS 17+/18+ niceties:** `EmptyStateView` can wrap `ContentUnavailableView`
  (iOS 17+); hand-written `EnvironmentKey` conformances can be replaced by
  the `@Entry` macro (iOS 18+).
- **NexusFeatures is iOS-only** — no macOS platform target (§3); the SPM
  package CI build uses the iOS simulator triple.

### 9.5 Preview, mock & demo strategy

This is a deliberate, layered system — **mock at the repository boundary, run
the real models over them**:

1. Entities ship `static let mockX` values (in Domain).
2. `Mock*Repository` classes and a mock `SessionManagerProtocol` live in
   **`NexusData/Mocks`** (`#if DEBUG`), shared by previews, unit/UI tests,
   and **demo mode** (§11.2). They conform to the Domain protocols with
   `shouldThrowError` / `shouldNeverComplete` knobs to simulate states.
3. Public model factories: `DashboardModel.preview`, `.emptyPreview`,
   `.loadingPreview`, `.errorPreview` — built over the shared mock
   repositories.
4. `AppContainer+Preview.swift` builds full `AppContainer` previews for each
   `AppState` (`previewState:` init), injecting the shared mock
   `SessionManagerProtocol` (a **protocol mock — never a subclass of a
   concrete class**).

Result: SwiftUI previews, unit tests, UI tests, and demo mode all exercise
the *real* orchestration code; only the transport/persistence edges are
faked. The mocks exist once, in one place.

Xcode 26's previews — `#Preview` traits and `@Previewable` (iOS 18+) for
per-preview state — compose with the same mock strategy; no new machinery.

---

## 10. Testing Strategy

- **Framework:** Swift Testing (1.0+, bundled with Xcode 26) — `@Suite`,
  `@Test`, `#expect`, `#require`, `Issue.record`. Tests are `async`, run
  against mocks, and use the modern features: parameterized
  `@Test(arguments:)` over the mock failure knobs, and traits such as
  `.timeLimit(...)`, `.bug(...)`, `.serialized` where shared state requires
  it. XCTest remains available for any legacy bridge; new tests are Swift
  Testing.
- **Test targets live beside their code:** `Domain/Tests/*`,
  `Data/Tests/{Session,DataSources,Repositories,Persistence,Logging}Tests`,
  `Features/Tests/{Dashboard,CardDetail,Navigation}Tests`, plus `NexusTests`
  (integration) and `NexusUITests` (UI) in the app target.
- **A workspace TestPlan** (`TestPlan.xctestplan`) enumerates every test
  target across all packages; the Xcode scheme runs the whole plan with
  `Cmd+U`.
- **Model tests** drive `load()` and assert `viewState` transitions; mocks
  with `shouldNeverComplete` test loading, mocks with `shouldThrowError` test
  error states, call counts (`mockRepository.getCardsCallCount == 1`).
- **Session tests** exercise `connect`/`disconnect`/event bridging against a
  fake SDK client.
- **UI tests** (`NexusUITests`) cover the real view layer: launch with the
  `-demoMode` argument → the container builds the mock graph → optional
  `-demoState=error` / `-demoState=loading` knobs drive the mock
  repositories → assert loading, error, and ready states render. Previews
  cover states cheaply; UI tests cover the wiring.
- **Integration tests** exercise real `CacheManager` + `CardRepository`
  (and/or the SwiftData repository) end to end, clearing state between tests.
- **CI** (`.github/workflows/ci.yml`, `pr-checks.yml`): Xcode 26.6 (Swift
  6.3), iPhone 17 simulator (iOS 26.5), `xcodebuild build-for-testing` then
  `test-without-building` against the workspace TestPlan, with SPM/DerivedData
  caching and PR pass/fail comments.

---

## 11. The App Target — Composition Root

**Path:** `Nexus/`

### 11.1 `NexusApp` — entry

```swift
@main
struct NexusApp: App {
    private let appContainer = AppContainer()   // one container for the app's life

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appContainer)
        }
    }
}
```

### 11.2 `AppContainer` — the composition root

`@MainActor @Observable final class AppContainer` is where **everything is
built and injected**. Responsibilities:

- Construct the `APISessionManager` (the one SDK-touching object) from config.
- `createDependencies()` builds the graph **inline, with plain
  initializers** — there is no factory ladder (§12.1 explains why it was
  cut): repositories → models → done.
- Exposes `appState: AppState` and owns the state machine.
- Reacts to **observation, not polling**: `ContentView` calls
  `handleSessionStatusChange(_:)` from `.onChange(of: container.sessionStatus)`
  (§11.3), mapping session changes to app state transitions
  (`ready↔disconnected`) and restarting live subscriptions on reconnect.
- Exposes `sessionStatus` as a **computed pass-through** of the session
  object, so views never depend on the concrete session class — live and
  demo are interchangeable at the environment boundary (§11.3).
- Selects **live vs. demo mode** at init — one `Mode` enum, defaulted from
  the `-demoMode` launch argument; `createDependencies()` switches on it
  (demo mode below).
- Provides `retry()` → `reinitialize()` for error recovery.
- Has a `#if DEBUG` `init(previewState:)` for previews.

```swift
private func createDependencies() {
    let logger = LoggingService()
    session = APISessionManager(config: .live)
    let cardRepository = SwiftDataCardRepository(container: container)
    dashboardModel = DashboardModel(
        cardRepository: cardRepository,
        offersRepository: CardOffersRepository(...),
        statusRepository: CardStatusRepository(...),
        logger: logger)
}
```

#### Demo mode — run the app without real data

A `Mode` enum at the composition root is the *only* place the app knows
whether it is live or demo — views and models are identical in both:

```swift
@MainActor @Observable
final class AppContainer {
    enum Mode { case live, demo }
    private let mode: Mode

    /// `.demo` when launched with `-demoMode` or when no backend is configured.
    static var defaultMode: Mode {
        if ProcessInfo.processInfo.arguments.contains("-demoMode") { return .demo }
        let environment = Bundle.main.infoDictionary?["API_ENVIRONMENT"] as? String
        return environment == "demo" ? .demo : .live
    }

    init(mode: Mode = AppContainer.defaultMode) {
        self.mode = mode
        createDependencies()
    }

    private func createDependencies() {
        switch mode {
        case .live:
            session = APISessionManager(config: .live)
            dashboardModel = DashboardModel(
                cardRepository: SwiftDataCardRepository(container: container),
                offersRepository: CardOffersRepository(...),
                statusRepository: CardStatusRepository(...),
                logger: logger)
        case .demo:
            session = MockSessionManager()                 // connects instantly
            dashboardModel = DashboardModel(
                cardRepository: MockCardRepository(seed: .mockDefaults),
                offersRepository: MockOffersRepository(seed: .mockDefaults),
                statusRepository: MockStatusRepository(...),
                logger: logger)
        }
    }
}
```

**Demo mode rules:**

- **No network, no Keychain, no disk.** The mock session manager and
  repositories are in-memory only; the demo never touches real persistence.
- **The demo feels alive, not static.** `MockSessionManager`'s
  `MockEventGenerator` emits synthetic `BankingEvent`s on a timer, so the
  app exercises the real `AsyncStream` → model → view pipeline — balances
  tick, transactions arrive, `cardStates` update live. This is what makes a
  banking demo worth showing.
- **Views never change and never know.** The session's status reaches views
  through the container's computed `sessionStatus` pass-through (§11.3) —
  never through the concrete session class — so live and demo inject
  identically. This is the MV payoff: demo mode is purely a composition-root
  decision.
- **`#if DEBUG` everywhere.** All mock and demo code lives in
  `NexusData/Mocks` behind `#if DEBUG`; a release build compiles it to empty
  and the `-demoMode` argument is ignored. A dedicated "Nexus Demo" Xcode
  scheme makes the flag unnecessary to remember.
- **Auto-select when unconfigured.** `API_ENVIRONMENT = demo` (§7.1) in a
  Debug build makes `.demo` the default — the app runs with no backend and
  no launch argument. Flip the config when the backend lands (§11.4).

### 11.3 `AppState` and `ContentView`

`AppState` mirrors `DashboardViewState` at app level:

```swift
public enum AppState: Equatable {
    case initializing, loading, ready
    case error(AppError)
    case disconnected
}
```

`ContentView` switches on `appContainer.appState` and reacts to the session
**by observation** — no polling task:

```swift
struct ContentView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            switch container.appState {
            case .initializing, .loading: AppLoadingView()
            case .ready:
                MainNavigationView()
                    .environment(container.router)
                    .environment(container.dashboardModel)
            case .disconnected: DisconnectedView { /* re-establish the session */ }
            case let .error(appError): AppErrorView(error: appError) { container.retry() }
            }
        }
        .onChange(of: container.sessionStatus) { _, status in
            container.handleSessionStatusChange(status)
        }
    }
}
```

Session state is observed through **`container.sessionStatus`**, a computed
pass-through (`AppContainer.sessionStatus` reads `session.sessionStatus`).
`@Environment` observation requires a *concrete* `@Observable` type, so views
must not read a protocol-typed session value from the environment — the
container is the one concrete observable that exists in both live and demo
modes (§11.2), and the session object itself is owned by the container and
injected only into models that need it.

This is the **"state machine at the top"** pattern: the root view is a pure
function of `appState`, and each state gets its own environment injection.
`sessionStatus` is already observable — the view layer reacting to it *is*
the mechanism; the old 250 ms polling loop was an approximation of
observation and was deleted.

---

### 11.4 Backend plug-in contract — building now, connecting later

The app is designed to be built **before a backend exists** and connected
later with **zero changes above the Data layer**. Two pieces define the
contract.

**What the app-side adapters must implement (the checklist):**

- The four repository protocols (§4.2), each backed by URLSession REST
  calls: decode wire JSON into **DTO structs** (in NexusData), map them to
  domain entities, and surface failures as `AppError` — reuse the
  `JSONDecoder` extension (§6.4) so every decode error is contextualized.
- `SessionManagerProtocol` (§4.3): the auth handshake in `connect()`
  (`withCheckedThrowingContinuation` over the token endpoint), a WebSocket
  session (`URLSessionWebSocketTask`) fed into `events(for:)`, and
  `sessionStatus` transitions. The default transport is defined in §6.2; a
  banking SDK, if one appears, is just another adapter.
- The event channel namespace — the app and the backend must agree on
  channel naming. Nexus uses `card.events.{cardId}` and `card.offers`;
  `parseEvent` (§6.1) maps wire payloads to `BankingEvent` → typed entities.
- Wire JSON shapes, defined once in NexusData as DTOs — the backend mirrors
  them. Domain entities are the *internal* language; the wire is never seen
  above the data sources.

**What the backend must provide (hand this to whoever builds it):**

- REST endpoints for cards, offers, card status, and card actions
  (freeze/unfreeze/spending limit), matching the repository protocol
  signatures and the DTO shapes.
- A WebSocket (or SSE) event stream on the channel namespace, pushing
  balance/status/transaction updates as `BankingEvent`-shaped payloads.
- Errors as JSON with a machine-readable code the Data layer maps to
  `AppError` cases (`apiConnectionFailed`, `cardNotFound`, ...).

**Until the backend exists:** `API_ENVIRONMENT = demo` (§7.1) or
`-demoMode` selects the mock graph (§11.2). The moment the adapters above
are implemented, flip the config and the app goes live — no model, view, or
navigation code changes.

---

## 12. Pitfalls, Departures & Deviations

Be honest about these when porting — they are the *actual* friction points of
this codebase and the decisions that keep it honest.

### 12.1 What was cut from the previous plan (and why)

- **The use-case layer** — seven single-method classes that translated
  `Result` into `throws`. Replaced by the §4.4 rule: a use case must compose
  ≥2 collaborators; the default is a model method.
- **The `Result<T, AppError>` repository style** — the double error style
  (`Result` at the boundary, `throws` above it) cost a `switch` at every
  caller. One style now: `async throws`. Keep `Result` only where failure
  must be a *value* (batch operations) — rare.
- **The factory ladder** — four `*Factory` protocols + `Default*`
  implementations to construct ~10 objects that one composition root builds
  once. Plain initializers are type-checked and greppable. Factories earn
  their keep only when a **second composition root** appears (widgets,
  watchOS, test bundles).
- **The 250 ms session-polling `Task`** — `sessionStatus` is already
  `@Observable`; the poll was a second source of truth. Now
  observation-driven (§11.3). If you ever need the *sequence* of session
  changes (reconnect backoff), consume an `AsyncStream` of them — still no
  polling.
- **Store protocols** (`XStoreProtocol: Observable`) — protocol-ized
  observable state is friction with `@Environment`/`@Bindable`, and
  substitutability already comes from mocking repositories. Concrete models.
- **`@unchecked Sendable` + barrier `DispatchQueue`s** — replaced by
  `@MainActor` on the session manager and `actor` on the cache. Zero
  `@unchecked` in the codebase.
- **`@_exported` umbrella modules** — private Swift API and a source of
  ambiguous symbols. Import concrete targets.
- **The Navigation ↔ Presentation package cycle** — `Router`/`Route` now live
  in a dependency-free target; the route→view switch lives in the app target.
  The router never imports views.
- **The SDK and OSLog imports in Domain** — Domain is now pure Swift:
  `LogLevel` replaces `OSLogType` in the protocol, and the session protocol
  already spoke only Domain types.
- **JSON-disk durable storage** — replaced by SwiftData for durable data; the
  in-memory cache stays for ephemeral live state.
- **Store-owned one-shot `Task`s** — one-shot loads are `async` methods
  called from view `.task`/`.refreshable`; SwiftUI owns cancellation.

### 12.2 Accepted departures from pure MV (all justified)

- **Model-owned subscription `Task`s** — live streams must outlive view
  identity; view `.task` would cancel on navigation. This is the complement
  to view-owned one-shots, not a return to store-driven loading.
- **`viewState` enums in models** — this is domain state
  (loading/loaded/error/empty), not presentation logic; views merely render
  it.
- **App-level `AppState` machine in `AppContainer`** — `AppContainer` is a
  model of app lifecycle, not a ViewModel.
- **Environment injection for models and the router** — app-wide shared
  state; the session object itself is container-owned, and its status
  reaches views through the container's computed pass-through (§11.3);
  initializer injection remains for feature-local dependencies.
- **The SwiftData mapping layer** — persistence in repositories, never views;
  the mapping structs are the boundary, not a ViewModel.

### 12.3 Remaining friction points

1. **`AsyncStream` cannot throw mid-stream.** Setup failures now throw (so a
   returned stream means "subscribed"), but mid-stream errors must be modeled
   as values — session status, an error element in the stream, or
   `AsyncThrowingStream` if you need typed mid-stream failure.
2. **`@MainActor` session manager** means every SDK event hops to the main
   actor. Fine at a few events/second; promote to an actor at high rates
   (§6.2).
3. **SwiftData is `@MainActor`-coupled and not `Sendable`.** Repositories are
   `@MainActor`; use the `@ModelActor` macro (iOS 18+) or a hand-written
   `ModelActor` on the iOS 17 floor for background writes. Plan lightweight
   migrations from day one. If your durable surface is truly one small list,
   a plain JSON file is defensible — say so explicitly rather than silently
   choosing.
4. **Models with many collaborators** — a model taking more than ~4
   repositories/services is the same smell the old `CardStore` had with 7 use
   cases. Split by feature when it appears.
5. Some entities are placeholders (a stub `CardCommandType.unknown`, unused
   `Settings`) — don't over-model the domain until a rule needs the type.
6. **Demo mocks can drift from the real backend.** The synthetic
   `MockEventGenerator` payloads are hand-written; route them through the
   *same* entity parsing (`parseEvent` / the `JSONDecoder` AppError
   extension) so a demo exercises the same decode path as live data — and
   keep the mock event shapes in lockstep with the SDK's payloads.
7. **Default actor isolation (Swift 6.2+) is a project-wide choice.**
   Enabling `-default-isolation MainActor` removes most `@MainActor`
   boilerplate but makes every type MainActor by default — background-safe
   code must opt back out with `nonisolated`, and un-opted repository calls
   hop to the main actor. Adopt it only if the whole team commits to the
   model (§3).
8. **`@MainActor` conformers of `Sendable` protocols need
   `@preconcurrency`.** Swift 6.2+'s conformance-isolation diagnostics
   (`#ConformanceIsolation`, `#IsolatedConformances`) reject a
   main-actor-isolated class satisfying a nonisolated protocol that
   inherits `Sendable`; an isolated conformance (`: @MainActor P`) cannot
   carry `Sendable`. Mark the conformance `@preconcurrency` instead
   (runtime-checked, still zero `@unchecked Sendable`) — applies to
   `APISessionManager` (§6.2) and any `@MainActor` session/mock conformer;
   the Day 4 test doubles set the pattern.

---

## 13. Porting Checklist — Applying This to a Different Project

Use this as an ordered recipe. Replace the card/banking domain with your own
(e.g., loans, payments, investments, budgeting).

### Step 0 — Choose your domain mapping

| Nexus concept | Generic role | Other project examples |
|---|---|---|
| `Card` / `CardOffer` | managed vs. candidate entity | `Loan` / `LoanOffer` |
| `CardState` + typed payloads | live state per entity | `AccountStatus` |
| `APISessionManager` | session/transport wrapper | `GatewayClient` |
| `BankingEvent` | transport-neutral event | `FeedEvent` |
| `DashboardModel` + `DashboardViewState` | screen model + state | `AccountListModel` + `AccountListViewState` |
| `AppState` | app-level state machine | same shape |
| `Route` cases | navigation destinations | your screens |

### Step 1 — Create the packages (in dependency order)

1. `AppPackages/NexusDomain` — targets `Entities`, `RepositoryProtocols`,
   `ServiceProtocols`. `swift-tools-version: 6.3` (Xcode 26.6), `.iOS(.v17)`
   floor, Swift 6 language mode. No dependencies.
2. `AppPackages/NexusData` — targets `Session`, `DataSources`,
   `Repositories`, `Persistence`, `Logging`, `Mocks` (`#if DEBUG`). Depends
   on NexusDomain (path) + your SDK (in `Session` only).
3. `AppPackages/NexusFeatures` — `SharedUI`, `Navigation` (Router/Route), one
   target per feature. Depends on NexusDomain, NexusData (path).
4. The app target — composition root, route→view mapping, UI tests.
5. Optionally add `swiftSettings: [.defaultIsolation(MainActor.self)]` to
   every package (Swift 6.2+) — see §3 and §12.3 for the trade-off.

### Step 2 — Write the Domain (no frameworks)

- Entities: `Codable, Sendable, Equatable` structs + static mocks.
- `AppError` + `ErrorCategory` + Equatable + `TestFactory`.
- Repository protocols: one-shot `async throws -> T`; subscriptions
  `async throws -> AsyncStream<T>`.
- Service protocols: `LoggerProtocol` with your own `LogLevel` first;
  session/transport protocol with `events(for:) -> AsyncStream<T>`.
- Apply the use-case rule (§4.4): zero use cases until one composes ≥2
  collaborators.

### Step 3 — Write the Data layer

- Session/transport manager (`@MainActor @Observable final class`,
  continuation-based event bridging, pending-subscription queue on
  reconnect) against the default URLSession transport (§6.2).
- Thin subscription facade.
- Actor data sources with in-memory caches and payload→entity parsing.
- Throwing repository implementations with validation + error-context
  wrapping, decoding wire JSON into DTOs → domain entities (§11.4).
- SwiftData repositories mapping `@Model` → domain structs (never let
  `@Model` classes cross the boundary); an in-memory `actor` cache for
  ephemeral state; Keychain for credentials, never plaintext card data on
  disk.
- The `JSONDecoder` AppError extension.

### Step 4 — Write Configuration and Logging

- `Bundle` config extension in the app target (xcconfig → Info.plist →
  Bundle).
- `LoggingService` (OSLog) in NexusData mapping `LogLevel` → `OSLogType` (no
  sensitive data in logs).

### Step 5 — Write Features (Presentation)

- `Spacing`/`Icons`/`Strings` tokens.
- `Route` (Hashable, with data) + `Router` in the `Navigation` target.
- One `@MainActor @Observable` model per screen + `viewState` enum.
- Views: switch on `viewState`, `@Environment` for model/router, `.task` /
  `.refreshable` for one-shots, `#Preview` for every state.
- Preview factories over the shared `Mock*Repository` classes
  (`NexusData/Mocks`).

### Step 6 — Write the app target

- `App` entry creates the container once.
- `AppContainer`: inline construction, expose `appState` and a
  `sessionStatus` pass-through, react to session changes via `.onChange` (no
  polling), `retry()`.
- `AppState` enum; `ContentView` switches on it and injects environments.
- Route→view mapping in the app target; `MainNavigationView` binds
  `Router.routes` to `NavigationStack`.
- `AppContainer+Preview` for each state.
- Demo mode: `Mode` enum in `AppContainer`, `-demoMode` launch argument,
  mock session event generator — `#if DEBUG` only, no network/Keychain/disk.
- Backend plug-in: implement the §11.4 adapter checklist against URLSession
  when the backend exists; `API_ENVIRONMENT = demo` is the no-backend
  default.

### Step 7 — Tests, TestPlan, CI

- Swift Testing suites per package next to code.
- Mock repositories with call counts and failure knobs; model tests assert
  `viewState` transitions, parameterized with `@Test(arguments:)` over the
  failure knobs.
- Session tests with a fake SDK client; UI tests launch with `-demoMode`
  (plus optional `-demoState` knobs).
- `TestPlan.xctestplan` listing all test targets; scheme runs it.
- GitHub Actions: Xcode 26, `xcodebuild build-for-testing` +
  `test-without-building` with caching.

### Step 8 — Verify the invariants

- [ ] Domain has no UI/Data/Infrastructure imports and no SDK, OSLog, or
      Combine.
- [ ] No layer imports upward; no package cycles (Router depends on nothing).
- [ ] All async boundary types are `Sendable`; UI types are `@MainActor`;
      zero `@unchecked Sendable`.
- [ ] Every thrown error is an `AppError` (or is converted at the boundary);
      no `Result` at repository boundaries.
- [ ] Models own and cancel their subscription tasks; one-shot work runs
      from view `.task` — no leaks on deinit/state change.
- [ ] Every screen state (loading/loaded/error/empty) has a preview and a
      test.
- [ ] No sensitive data (card numbers, tokens) in logs, caches, or configs.
- [ ] Demo mode is `#if DEBUG` only, touches no network/Keychain/disk,
      release builds ignore `-demoMode`, and views never depend on the
      concrete session class (status flows through the container
      pass-through).
- [ ] Toolchain: `swift-tools-version: 6.3`, builds with Xcode 26 under the
      Swift 6 language mode with strict concurrency; CI runs the same
      Xcode.
- [ ] Runs with no backend: `API_ENVIRONMENT = demo` (or `-demoMode`)
      yields the full demo experience; switching to live is config plus the
      §11.4 adapters — zero changes above the Data layer.
- [ ] Build + full TestPlan green, CI mirrors the local commands.

---

## 14. One-Paragraph Summary (for quick recall)

Nexus is **MV (Model-View)** over three SPM packages: **NexusDomain** (pure
Swift: entities with mocks, repository/service protocols, one `AppError`
taxonomy, a `LogLevel` enum — no SDK, no OSLog, no use cases), **NexusData**
(`@MainActor @Observable` session manager behind a stream-based protocol,
actor data sources with in-memory caches and `AsyncStream` event
subscriptions, thin throwing repositories, SwiftData repositories mapping
`@Model` classes to domain structs plus an in-memory actor cache and Keychain
for secrets, OSLog logging), and **NexusFeatures** (one `@MainActor
@Observable` model per screen with an explicit `loading/loaded/error/empty`
view state, small composed views switched on that state via `.task`/
`.refreshable`, design tokens, previews via mock repositories behind real
models, and a dependency-free `Router` holding a `[Route]` stack bound to
`NavigationStack`). The **app target** is the composition root: `AppContainer`
builds the graph inline, owns the route→view mapping, and exposes an
app-level state machine (`AppState`) driven by observation — the root view is
a pure switch on that state and reacts to session changes with `.onChange`,
not polling. A `-demoMode` launch argument — or an `API_ENVIRONMENT = demo` build
configuration — swaps the composition root to in-memory mocks (no network,
Keychain, or disk), so the app demos itself on synthetic live events through
the real stream→model→view pipeline. A future backend plugs in at the
protocol seam (§11.4): implement the four repository protocols and
`SessionManagerProtocol` against URLSession, and the app goes live with no
changes above the Data layer. Tests use Swift Testing per package plus a UI
test target, aggregated in a workspace TestPlan, run in CI with `xcodebuild`.
