# Nexus Swift Style Guide

> **Scope.** Nexus's SwiftUI code on the **Swift 6 language mode**. The project has **no
> UIKit** — every screen is SwiftUI. The architecture is **MV**: `@MainActor @Observable`
> models publishing explicit `viewState` enums, driven by views, with **no ViewModel layer**.
> `architecture.md` owns that pattern; this guide styles the code *inside* it.
>
> **Precedence.** 1) the compiler · 2) **SwiftFormat** (mechanical shape) · 3) this guide
> (the decisions a formatter can't make) · 4) `architecture.md` for layer structure.
> Where a style choice and the pattern disagree, the pattern wins.

## 1. Tooling

**One writer, one reporter.** SwiftFormat owns shape; SwiftLint owns the judgement calls a
formatter shouldn't make. Nothing else reformats, so the two never oscillate.

- **`.swiftformat`** — the formatting source of truth: spacing, the 100-column wrap, braces,
  commas, blank lines, import order, and the language-practice cleanups a formatter *can*
  make — per-member access control (§4) via `extensionAccessControl`, and `final` on leaf
  classes. It runs in the pre-commit hook, never during a build.
- **`.swiftlint.yml`** — semantics only: `force_cast`, `force_try`, `force_unwrapping`,
  `multiline_call_arguments`. Each `Tests/` directory has a nested config that relaxes
  `force_unwrapping` for fixtures.
- **Run through the scripts.** `scripts/format.sh` writes; `scripts/lint.sh` reports
  (`swiftformat --lint` + `swiftlint --strict`). The committed hook
  (`.githooks/pre-commit`, activated with `git config core.hooksPath .githooks`) formats and
  re-stages the staged Swift files, then blocks the commit on any violation.
- **Config is committed, rule sets are pinned** — SwiftFormat `--disable all` plus an
  explicit enable list; SwiftLint `only_rules:`. An upstream default change can't silently
  reshape the code, and adding a rule is deliberate. `Brewfile` pins both tools.
- **Warnings are errors.** Build warning-free. The Swift 6 language mode and strict
  concurrency are on from day one (§7) — retrofitting them is far more expensive.

## 2. Formatting

SwiftFormat enforces this; know the shape so you can read a diff confidently.

- **4-space indent** (no tabs). **100-column limit** — exceptions are import lines and long
  unbreakable tokens.
- **K&R braces** (`} else {` on one line); **no semicolons**; one statement per line.
- One blank line between members; blank lines inside a function only to group steps. Never
  stack blank lines.
- A wrapped list is either fully horizontal or **one element per line** — never mixed.
  Continuation lines indent **+4**.
- **Trailing commas** in multi-line collection literals; **none** after the last argument of
  a multi-line call.
- `if x == 0 {}`, not `if (x == 0) {}`; no space around `.` or range operators; a space
  *after* commas.

## 3. Files, imports, member order

- **One primary type per file**, named for it (`Card.swift`); a conforming extension is
  `Card+Identifiable.swift`.
- **Imports first**, grouped, lexicographically sorted within a group, groups separated by one
  blank line, not line-wrapped. `@testable` last, test sources only. Import the **whole
  module** and import exactly what you use — never rely on transitive imports.
- **Order members logically and label them with `// MARK: -`** (lifecycle, then actions, then
  helpers). Keep overloads together. Group conformances in extensions rather than scattering
  them.

## 4. Access control

Default to `internal`. Reach for `public` only for the contract a module actually exposes, and
justify each addition in review. **Never `public extension`** — put the access level on each
member so the surface is explicit:

```swift
extension String {
    public var isUppercase: Bool { /* … */ }   // ✅ every member is explicit
}

public extension String {                       // ❌ SwiftFormat's extensionAccessControl bans this
    var isUppercase: Bool { /* … */ }
}
```

Express scope by **nesting**, not name prefixes; use a **case-less `enum`** as a namespace for
constants.

## 5. Naming

Write names that read as fluent English at the call site (Apple's API Design Guidelines).

- **Methods read as phrases**, the first argument joining the base name:
  `array.insert("a", at: 0)`.
- **Booleans assert:** `isBlocked`, `hasExpired`, `shouldRetry`.
- Types `UpperCamelCase`, members `lowerCamelCase`; acronyms uniform (`URLSession`).
- **Don't abbreviate** (`MaskedPAN`, not `MPAN`) and **don't repeat the type** in members that
  return it (`UIColor.red`).
- No Hungarian prefixes; **ASCII identifiers only** (no emoji).
- Initializer parameters that map to stored properties share the property's name; write
  `self.x = x` on assignment.

## 6. Types and mutability

**Default to `let`, `struct`, and `enum`; use `class` only for identity or lifetime.**

- `let` on a struct freezes every property; on a class it freezes only the reference.
- Value types are `Sendable` essentially for free — that is what makes them safe to pass
  across isolation boundaries.
- **Mark leaf classes `final`.** **Model with enums** so contradictory states can't be
  represented; an exhaustive `switch` then forces every new case to be handled.
- Shorthand types (`[Element]`, `[Key: Value]`, `Wrapped?`); `Void` in function types only.
- **Write existential protocols with `any`** (`any CardRepositoryProtocol`) and generics with
  `some`/concrete — explicit, so the cost of the existential is visible.

```swift
struct Money: Sendable, Equatable {
    let amount: Decimal
    let currency: Currency   // carrying the currency makes EUR/USD mixing impossible
}
```

## 7. Concurrency

The Swift 6 language mode turns data races into **compile errors**. Write waiting code
top-to-bottom and let the compiler prove isolation.

- **`async`/`await`** replaces callbacks. `await` *pauses* (it frees the thread), and you
  resume where you started.
- **Isolation:**
  - `@MainActor` on the `@Observable` screen models *you* write. SwiftUI `View` is already
    main-actor — don't re-annotate `body`.
  - `nonisolated` for pure helpers (formatting, decoding, maths).
  - `actor` for shared mutable state with no UI — a serial queue attached to the data.
  - `Sendable` on anything crossing a boundary; value types qualify for free.
- **Structured concurrency:** `async let` / task groups for independent work, always awaited.
- **In SwiftUI, use `.task { }`** — it runs on appear and cancels on disappear. `Task { }`
  inherits context; `Task.detached` is rare.

```swift
List(model.cards) { CardRow(card: $0) }
    .task { await model.load() }   // auto-cancelled when the view leaves
```

## 8. Optionals and errors

**Optional** means "value or absence"; **errors** mean failure.

- No sentinel values — "not found" is a valid outcome, so it's an `Optional`, not `-1`.
- **`throws` by default; `Result` only when the outcome must outlive the call** (stored,
  batched, or compared later).
- **At the repository and service boundaries the seam is `async throws` only** — no completion
  handlers, no `Result` (`architecture.md` §4.2).
- **No `try!` and no force-unwrap outside tests.** In production, a force-unwrap is allowed
  only for an unmistakable programmer error, with a comment stating the invariant.
- `guard` for early exit so the happy path stays flat.

## 9. SwiftUI

The project's screen shape: a `@MainActor @Observable` model publishing an explicit
`viewState` enum, injected through the environment and **never created in a view**. Views
switch on `viewState`; the model owns its long-lived subscription tasks.

```swift
struct CardView: View {
    @Environment(CardDetailModel.self) private var model   // shared @Observable model
    var body: some View {
        switch model.viewState {
        case .loading: LoadingView()
        case let .error(error): ErrorView(error: error) { Task { await model.load() } }
        case .loaded:  CardContent(model: model)
        }
    }
}
```

- **State:** `@State` for local view state, the environment model for shared state. A view is
  a value; `body` is a pure function of state.
- **Keep `body` lean and side-effect-free.** `@Observable` tracks *what a body reads*, so a
  stray read widens dependencies — and do no work in an initialiser; SwiftUI builds views
  freely. One-shot work runs from `.task`/`.refreshable`.
- **Layout from stacks, not frames.** Avoid `GeometryReader` unless measurement is genuinely
  needed; prefer `.aspectRatio`, `containerRelativeFrame`, `ViewThatFits`.
- **Lists identify by a stable `id`** (`Identifiable`) so diffing is cheap.
- **Lifecycle = `.task` / `.onChange`**, not timers.
- **Dynamic Type via semantic fonts** (`.font(.headline)`), never fixed point sizes.
- **Accessibility is not optional:** label glyph-only controls, and set identifiers from the
  shared `…Accessibility` namespaces so UI tests query ids, not copy.
- **Navigation:** `NavigationStack` + `navigationDestination(for:)`, registered once on a view
  that is always in the stack.

## 10. Logging and security

- **Private by default.** The seam is `LoggerProtocol` carrying `LogPrivacy`
  (`visible` / `redacted` / `sensitive`), mapped to the log's annotation in `LoggingService`
  and **defaulting to `.redacted`** (`architecture.md` §7.2). Never mark a PAN, CVV, or token
  `.visible`.
- **Mask at the type, not the call site** — a `MaskedPAN` value cannot leak a number by
  accident.
- Only display-safe data reaches logs, caches, or configs; credentials live in the Keychain.

## 11. Documentation comments

- **`///`, never `/** … */`.** Open with a one-sentence summary (a verb phrase for methods, a
  noun phrase for properties), then `- Parameter(s)`, `- Returns`, `- Throws` in that order.
- Document every public declaration and each public member. Skip self-explanatory cases,
  overrides, and tests. **Never restate the code.**
- DocC renders the markup; each target ships a `.docc` catalog.

## 12. Testing

- **Swift Testing is the default** for unit and logic tests — `@Suite`, `@Test`, `#expect`,
  and parameterized `arguments:`.
- **XCTest only for UI** (`XCUIApplication`) and performance (`measure {}`).
- **Test the model, not the view.** Inject repository doubles, assert on `viewState`; mark the
  suite `@MainActor` when it touches UI state.

```swift
@Suite("Card model") @MainActor
struct CardModelTests {
    @Test func `load lands loaded`() async {
        let model = DashboardModel(cardRepository: MockCardRepository(seed: [.mockCreditCard]), …)
        await model.load()
        #expect(model.viewState == .loaded)
    }
}
```

- **Determinism:** inject a fixed clock/calendar/locale, reset shared state between tests,
  stub the transport, and in UI tests query accessibility ids with `waitForExistence` — never
  fixed sleeps.

## Quick reference

- **Formatting:** 4-space indent, 100-col, K&R braces, no semicolons, trailing commas in
  multi-line collections — enforced by SwiftFormat.
- **Files:** one primary type per file; `Type+Protocol.swift` for conformances; imports first,
  grouped and sorted.
- **Names:** fluent at the call site; `UpperCamelCase` types, `lowerCamelCase` members.
- **Types:** `let`/`struct`/`enum` by default; `final` leaf classes; enums for state;
  `any` for existentials.
- **Errors:** `async throws` at the boundaries; no `Result`, `try!`, or force-unwrap outside
  tests.
- **Concurrency:** Swift 6 mode; `@MainActor` models, `actor` for shared state, `Sendable` at
  boundaries; `.task` for view-triggered work.
- **SwiftUI:** model from the environment, lean side-effect-free `body`, semantic fonts,
  accessibility ids.
- **Docs:** `///` summary + tags on every public declaration.
- **Tests:** Swift Testing for logic, XCTest for UI; deterministic and isolated.
