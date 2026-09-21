# Swift Style Guide — new iOS project, late 2026

> **Tags**: [[reference]] [[styleguide]] [[conventions]] [[swift6]] [[performance]] [[readability]]
>
> **Scope:** a new Swift app on the **Swift 6** language mode, built with **SwiftUI**
> (UIKit idioms are covered where a screen needs them).
> **Status:** living document; the *mechanical* half is enforced by **SwiftFormat**, so this
> guide spends its words on the decisions a formatter cannot make.
>
> **Pattern:** the project follows **MV (Model–View)** — SwiftUI views driven by
> `@MainActor @Observable` models, with **no ViewModel layer**. `architecture.md` is the
> canonical spec for the MV variant (where models live, state ownership, persistence, and
> the layer boundaries); this guide styles the code *inside* those layers. Where a style
> choice and the pattern disagree, the pattern wins.

## About this guide

One guide for a new iOS project on the Swift 6 language mode, covering the whole surface of
coding style: file layout, formatting, naming, language practice, concurrency, architecture,
framework idioms, documentation, and tests.

**The model layer is shared; the view layer is not.** Rules are framework-neutral unless
stated; where a SwiftUI and a UIKit idiom differ, the section shows both forms. Both
frameworks observe the **same** `@Observable` model — there is no ViewModel layer between
them, and only the view layer changes.

It builds on three sources:

- **Apple’s Swift API Design Guidelines** — naming and API shape, followed as if quoted in
  full.
- **The Swift standard library’s own style** — the basis of the formatting and
  language-practice rules.
- **Apple’s current documentation** — framework and performance idioms for the Swift 6 /
  iOS 26 era.

**Precedence when rules conflict:**

1. **The compiler.** A rule that would not compile, or that silences a warning by hiding a
   real problem, loses.
2. **SwiftFormat.** For anything mechanical — spacing, wrapping, brace placement, import
   order — the formatter is the source of truth, and the config is committed.
3. **This guide.** For the decisions a formatter can’t make: naming, types, concurrency
   isolation, error strategy. For layer structure and the MV pattern itself,
   `architecture.md` is the reference — this guide styles the code *inside* those layers.
4. **Local team convention.** Where this guide offers a judgement call marked *house
   style*, the nearest consistent choice wins — but pick one and pin it.

**How to read this:** each rule is *what* + *why* + a short example. Read §1–§2 once, then
use the rest as a reference.

**Attribution:** naming and API rules follow **Apple’s Swift API Design Guidelines**;
formatting and language-practice rules follow the **Swift standard library style**;
framework and platform facts reflect **Apple’s documentation** for the Swift 6 / iOS 26 era.

---

## Contents

- [**Part I — Foundations**](#part-i--foundations)
  - [1. Guiding principles](#1-guiding-principles)
  - [2. Tooling and enforcement](#2-tooling-and-enforcement)
- [**Part II — Source files**](#part-ii--source-files)
  - [3. File names and encoding](#3-file-names-and-encoding)
  - [4. File structure and member order](#4-file-structure-and-member-order)
  - [5. Access control and namespacing](#5-access-control-and-namespacing)
- [**Part III — Formatting**](#part-iii--formatting)
  - [6. Whitespace and line rules](#6-whitespace-and-line-rules)
  - [7. Line-wrapping (the short version)](#7-line-wrapping-the-short-version)
  - [8. Constructs](#8-constructs)
- [**Part IV — Naming**](#part-iv--naming)
  - [9. Names and API shape](#9-names-and-api-shape)
  - [10. Identifiers](#10-identifiers)
- [**Part V — Language and practice**](#part-v--language-and-practice)
  - [11. Types and mutability](#11-types-and-mutability)
  - [12. Optionals and error handling](#12-optionals-and-error-handling)
  - [13. Concurrency — checked, not remembered](#13-concurrency--checked-not-remembered)
  - [14. Functions, data, and composition](#14-functions-data-and-composition)
  - [15. Performance-shaped style](#15-performance-shaped-style)
  - [16. Logging and security](#16-logging-and-security)
- [**Part VI — Framework idioms**](#part-vi--framework-idioms)
  - [17. SwiftUI](#17-swiftui)
  - [18. UIKit](#18-uikit)
  - [19. Modern APIs over legacy](#19-modern-apis-over-legacy)
- [**Part VII — Documentation and tests**](#part-vii--documentation-and-tests)
  - [20. Documentation comments](#20-documentation-comments)
  - [21. Testing style](#21-testing-style)
- [**Appendix A — Modern Swift notes (Swift 6 / iOS 26)**](#appendix-a--modern-swift-notes-swift-6--ios-26)
- [**Appendix B — Quick reference**](#appendix-b--quick-reference)
- [**Appendix C — Basis**](#appendix-c--basis)

---

# Part I — Foundations

## 1. Guiding principles

**Clarity at the point of use is the most important goal.** A declaration is read once; a
call site is read forever. Optimise names, types, and APIs for the reader of the *use*, not
the author of the *declaration*.

Two axes govern every judgement call below:

- **Readability** — can a new engineer predict what this does without running it?
- **Performance** — is this allocation, dispatch, or thread hop necessary? (Only ever
  decided *after* measuring — see §15.)

Three habits follow, and they recur throughout:

- **Values first.** `let` and value types make state easier to reason about and safe to
  share across threads.
- **Make illegal states unrepresentable.** If a type can’t express a bad state, no runtime
  check is needed.
- **Put guarantees in mechanisms.** Use the compiler, types, and tests — not discipline,
  comments, or wiki pages — to enforce boundaries.

## 2. Tooling and enforcement

The mechanical half — spacing, line length, wrapping, brace and comma placement, import
ordering — belongs to tools so that review can focus on the rest.

- **SwiftFormat is the formatting source of truth** (`.swiftformat`). It owns shape —
  spacing, line length, wrapping, brace and comma placement, blank lines, import order — and
  the language-practice cleanups a formatter can make, including the per-member access
  control of §5 (`extensionAccessControl`) and `final` on leaf classes. It is the **only tool
  that writes**, and it **never writes during a build**. The rules in Part III are what it
  enforces — you should rarely need to think about them by hand.
- **SwiftLint is the reporter** (`.swiftlint.yml`), for the semantic checks a formatter
  should not decide (force unwrap/cast/`try`, multi-line call shape). It **never reformats**
  — one writer, one reporter.
- **Format first, lint second.** Each config pins its rule set explicitly (SwiftFormat
  `--disable all` plus an `--enable` list; SwiftLint `only_rules:`), so the two rule sets stay
  disjoint and cannot oscillate. Adding a rule is a deliberate act.
- **Commit the config** — `.swiftformat`, `.swiftlint.yml`, a nested `.swiftlint.yml` under
  each `Tests/` directory (fixtures may force-unwrap), and a `Brewfile` so a fresh machine
  gets both tools with `brew bundle`.

```ini
# .swiftformat — the committed config is the source of truth
--swift-version 6.3
--indent 4
--max-width 100
--semicolons never

# Pin the rule set: everything off, then an explicit enable list, so an
# upstream default change cannot silently reshape the code.
--disable all
--enable indent
--enable sortImports
# … the rest of the enable list
```

- **Where each runs.** Locally, a committed pre-commit hook (`.githooks/pre-commit`,
  activated once with `git config core.hooksPath .githooks`) formats the staged Swift files,
  re-stages them, then runs the report-only checks and blocks the commit on any violation —
  so CI never sees one. `scripts/format.sh` and `scripts/lint.sh` run the same two steps by
  hand. In the editor, a **Run Script** build phase (`scripts/lint-buildphase.sh`)
  surfaces SwiftLint violations inline; it no-ops when `swiftlint` isn't installed, so it
  never runs on CI. In CI, `swiftformat --lint .` is the gate; **CI never writes**.

- **Compiler warnings are errors.** Code should build warning-free; the only tolerated
  exception is an unavoidable deprecation during a migration window. Turn on
  **strict concurrency** and the **Swift 6 language mode** from day one (§12) — retrofitting
  it later is far more expensive.

---

# Part II — Source files

## 3. File names and encoding

- **Extension:** every Swift file ends in `.swift`.
- **Name after the primary entity.** A file containing `MyType` is `MyType.swift`; a file
  that conforms a type to a protocol is `MyType+MyProtocol.swift`; a grab-bag of related
  top-level helpers can be named for the grouping (`Math.swift`).
- **Encoding:** UTF-8.
- **One top-level type per file** in general. Exceptions: a type and its delegate protocol;
  a type and its small helper types.

## 4. File structure and member order

- **Imports go first**, one group per kind, each group lexicographically sorted, groups
  separated by one blank line, and **not line-wrapped**:

  ```swift
  import CoreLocation          // modules (not under test)
  import UIKit

  import func Darwin.C.isatty  // individual declarations (only when a whole import is too broad)

  @testable import MyModule    // @testable, test sources only
  ```

  Import the **whole module** rather than individual members unless a whole-module import
  would pollute the namespace (e.g. some C interfaces). Import exactly what you use — don’t
  rely on transitive imports.

- **Order members logically, and say so with `// MARK: -`.** There is no single correct
  order, but it must be explainable. Never let a type become “chronological by date added”.

  ```swift
  final class MovieRatingViewController: UITableViewController {
      // MARK: - Lifecycle
      override func viewDidLoad() { /* … */ }

      // MARK: - User actions
      @objc private func ratingStarWasTapped(_ sender: UIButton?) { /* … */ }
  }
  ```

- **Group overloads together.** Multiple initializers, subscripts, or same-base-name
  functions appear consecutively with no other code between them.
- **Use extensions to organise**, not to scatter. Group conformances and logical units so a
  reviewer could describe the structure.

## 5. Access control and namespacing

- **Omit access where the default is right.** Top-level declarations default to `internal`;
  nested ones default to the lesser of `internal` and their enclosing type.
- **Choose the level deliberately:**

  ```swift
  enum CardsFeature {                     // whole feature lives here
      struct Card { /* … */ }             // internal by default
  }

  package struct CardID { /* … */ }       // (Swift 5.9) shared across targets of one package
  public struct Card: Sendable { /* … */ } // the contract — a long-lived promise
  ```

  - `internal` — the default; the implementation lives here.
  - `package` — visible to other targets **of the same package**, not beyond.
  - `public` — a promise; every addition should be justified in review.
- **Never `public extension`.** Set the access level on each member instead, so the surface
  is explicit (SwiftFormat’s `extensionAccessControl` enforces this mechanically):

  ```swift
  extension String {
      public var isUppercase: Bool { /* … */ }   // ✅ each member is explicit
  }

  public extension String {                       // ❌
      var isUppercase: Bool { /* … */ }
  }
  ```

- **Nesting, not name prefixes, expresses scope.** Associate a type’s error or flag enum by
  nesting it. Use a **case-less `enum`** as a namespace for constants/helpers (it can’t be
  instantiated and needs no boilerplate):

  ```swift
  final class Parser {
      enum Error: Swift.Error { case invalidToken(String), unexpectedEOF }
  }

  enum Dimensions {
      static let tileMargin: CGFloat = 8
  }
  ```

- **Hiding is access control’s job, not naming’s.** Don’t prefix with underscores except to
  work around a genuine language limitation across a module boundary.

---

# Part III — Formatting

> These rules are what **SwiftFormat** enforces. They’re stated so you can read a diff
> confidently and configure the tool deliberately.

## 6. Whitespace and line rules

- **Indent with 4 spaces; never tabs** (Xcode’s default width). Pick a width in config and
  let the formatter apply it — don't hand-align.
- **Column limit: 100 characters.** Wrap longer lines (§7 below); exceptions are import
  statements, long unbreakable tokens (e.g. a URL in a comment), and generated code.
- **Braces: K&R.** No line break before `{`; a line break after `{` and before `}`, except
  for empty blocks (`{}`) and single-statement blocks (§8). `} else {` sits on one line.
- **No semicolons** — the only legal ones are inside strings or comments.
- **One statement per line.** A statement may share its line with a block body only when the
  body holds zero or one statements:

  ```swift
  guard let value = value else { return 0 }
  let squares = numbers.map { $0 * $0 }
  ```

- **No parentheses around the top-level expression** of `if`/`guard`/`while`/`switch`:

  ```swift
  if x == 0 && y == 0 { /* … */ }        // ✅
  if (x == 0 && y == 0) { /* … */ }      // ❌
  ```

  Grouping parentheses inside an expression are fine when they genuinely aid readability.
- **Horizontal whitespace** — one space where the language requires it, plus:
  - no space around `.` for member access (`view.bounds.width`) and no space around the
    `..<` / `...` range operators (`1...5`);
  - a space *after* (not before) commas in argument lists and literals (`[1, 2, 3]`);
  - spaces on both sides of binary/ternary operators (including `=`).

  ```swift
  let width = view.bounds.width   // no space around .
  for n in 1...5 { /* … */ }      // no space around ranges
  let numbers = [1, 2, 3]         // space after commas, not before
  ```
- **Vertical whitespace** — one blank line between members of a type (optional between
  consecutive single-line stored properties or enum cases); blank lines within a function
  only to group logical steps. Don't stack multiple blank lines.

## 7. Line-wrapping (the short version)

Let the formatter do the work; know the shape it produces. A wrapped list is either
**horizontal** (all on one line) or **vertical** (one element per line) — never a mix.
Continuation lines of a vertical list are indented **+4** from the first line. For generic
`where` clauses, break before `where`, then go vertical if still too long:

```swift
public func index<Elements: Collection, Element>(
    of element: Element,
    in collection: Elements
) -> Elements.Index?
where
    Elements.Element == Element,
    Element: Equatable
{
    // …
}
```

## 8. Constructs

- **Switch:** `case` is indented at the same level as `switch`; the statements inside are
  +2. **No empty `fallthrough`** — combine patterns into ranges or comma lists instead.

  ```swift
  switch value {
  case 1: print("one")
  case 2...4: print("two to four")
  case 5, 7: print("five or seven")
  default: break
  }
  ```

- **Enum cases:** one per line, except the comma form when no case has associated/raw values
  and all fit on one line. Order logically; if none is obvious, order lexicographically.
  Never write `case empty()` — use `case empty`.
- **Trailing commas:** required in multi-line collection literals (cleaner diffs), and
  omitted after the last argument of a multi-line call (`--trailing-commas collections-only`).
- **Numeric literals:** group long literals with `_` where it aids reading
  (`1_000_000`, `0xFF_FF`); don’t group opaque identifiers.
- **Attributes:** parameterised attributes (`@available(iOS 26, *)`, `@objc(...)`) go on
  their own line, lexicographically ordered. Parameterless ones (`@IBOutlet`, `@objc`) may
  share the declaration line if they fit.
- **Non-documentation comments** use `//`, never `/* … */`.
- **Trailing closures:** use trailing-closure syntax for a single final closure. With
  **multiple** closures, use the labelled multiple-trailing-closure form (Swift 5.3+) — and
  never overload two functions that differ only in a closure argument label.

  ```swift
  UIView.animate(withDuration: 0.5) {
      // animations
  } completion: { finished in
      // completion
  }
  ```

---

# Part IV — Naming

## 9. Names and API shape

**Write names that read as fluent English at the call site.** Apple’s API Design Guidelines
apply in full; the highest-value subset:

- **Methods read as phrases**, with the first argument joining the base name:
  `array.insert("a", at: 0)` — not `array.insert(at: 0, value: "a")`.
- **Booleans assert:** `isBlocked`, `hasExpired`, `shouldRetry`.
- **Casing:** types and protocols `UpperCamelCase`; members and locals `lowerCamelCase`;
  acronyms uniform (`URLSession`, not `UrlSession`).
- **Don’t abbreviate** what the reader must decode: `MaskedPAN`, not `MPAN`.
- **Don’t repeat the type in static/instance members that return it:**
  `UIColor.red` (not `redColor`), `URLSession.shared` (not `sharedSession`).
- **Global constants** are `lowerCamelCase`; no Hungarian prefixes (`kSecondsPerMinute`). ✗
- **Initializer parameters** that map to stored properties share the property’s name; use
  explicit `self.` on assignment to disambiguate.
- **Delegate methods** follow Cocoa’s linguistic shape — the delegate’s source object is the
  first (often unlabelled) argument, and the verb/noun of the name describes the event or
  the return value:

  ```swift
  func scrollViewDidBeginScrolling(_ scrollView: UIScrollView)           // Void → event
  func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool   // Bool → assertion
  func numberOfSections(in scrollView: UIScrollView) -> Int              // query → noun phrase
  ```

## 10. Identifiers

- **7-bit ASCII by default.** Unicode identifiers are allowed only for genuine domain
  meaning understood by the team (e.g. `Δx` for a delta). Never emoji.

---

# Part V — Language and practice

## 11. Types and mutability

**Default to `let`, `struct`, and `enum`; reach for `class` only for identity or lifetime.**

- `let` on a struct freezes every property; `let` on a class freezes only the reference —
  immutable means `let` stored properties *inside* the class.
- Value types are `Sendable` essentially for free; that is what makes them safe across
  threads.
- **Transform, don’t mutate**, at boundaries: return new values, keep mutation local.
  *Immutable at the boundaries, mutable in the small.*

```swift
struct Money: Sendable, Equatable {
    let amount: Decimal
    let currency: Currency   // carrying the currency makes EUR/USD mixing impossible
}
```

- **Mark leaf classes `final`** — signals intent and enables static dispatch.
- **Model with enums** so contradictions can’t be represented; exhaustive `switch` then
  forces every new case to be handled.

```swift
final class TokenStore { /* leaf type: not designed for subclassing */ }

enum TransferState: Sendable, Equatable {
    case draft
    case pendingApproval(by: String)
    case authorized(at: Date)
    case declined(reason: String)   // not five Bools that can contradict each other
}
```

- **Use shorthand types**: `[Element]`, `[Key: Value]`, `Wrapped?` — long forms only when
  required (e.g. `[Element].Index`).
- **`Void` in function types; omit it on `func`s.** Empty argument lists are `()`.

  ```swift
  func doSomething() { /* … */ }
  let callback: () -> Void
  ```

- **Write existential protocols with `any`** (`any CardServicing`) and generics with
  `some`/concrete types; be explicit so the cost of the existential is visible.

## 12. Optionals and error handling

**Optional** conveys a non-error “value or absence”. **Errors** convey failure.

- **Avoid sentinel values.** Not finding something is a valid outcome → `Optional`, not
  `-1`.
- **`Optional` for a single obvious failure; `throws` when there are multiple error
  states.** Throwing keeps valid outputs and failure cleanly separated.
- **Test non-nil without unwrapping** via `!= nil` (clearer than `if let _ =`).
- **Force-unwrap/force-cast are smells.** Allowed in tests, and in production only when the
  failure is unmistakably programmer error — and then only with a comment stating the
  invariant, or an inline assertion:

  ```swift
  // Safe: `value` came from a source that only permits valid raw values.
  return SomeEnum(rawValue: value)!
  ```

- **`try!` is forbidden** except in tests and in the REPL-evaluable single-expression case
  (e.g. a regex from a string literal). Prefer `try?`/`do-catch` with context.
- **Implicitly-unwrapped optionals (`T!`) are discouraged**, allowed only where the UI
  lifecycle guarantees non-nil (`@IBOutlet`, `prepareForSegue`-set properties, test
  fixtures) or to bridge un-annotated Objective-C APIs — kept to the smallest footprint.
- **`Result` is a value, `throws` is control flow.** Use `throws`/`async throws` by default;
  reach for `Result` only when the outcome must outlive the call (a non-throwing callback, a
  stored/batched/compared result, a publisher).

  ```swift
  func fetchBalance() async throws(APIError) -> Decimal             // handle it here
  func authorize(pin: String,
                 completion: @escaping (Result<Token, APIError>) -> Void)  // must travel
  ```

  At this project's repository and service boundaries the rule is stricter still: the seam
  is `async throws` only — **no completion handlers** and **no `Result`**
  (`architecture.md` §4.2, §12.1). `Result` survives only for outcomes that are genuinely
  stored, batched, or compared later.

- **Typed throws `throws(E)`** (Swift 6) is not a default — it freezes the error set.
  Prefer it module-internally; resist it just because “only one error can happen”.
- **`guard` for early exit** so the happy path stays flat; **`for … where`** instead of a
  loop whose body is a single `if`.

## 13. Concurrency — checked, not remembered

**Write waiting code top-to-bottom and let the compiler prove isolation.** Turn on the
**Swift 6 language mode** and strict concurrency from the start; data-race issues become
compile errors rather than production crashes.

- **`async`/`await`** replaces nested callbacks. `await` *pauses*, it does not block — the
  thread is freed. After an `await` you resume **where you started**, so a call begun on
  main returns on main.
- **Isolation:**
  - `@MainActor` on the models *you* write — the `@Observable` screen models of §17/§18.
    SwiftUI `View` and `UIViewController` are already main-actor, so
    `body`/`viewDidLoad`/`@IBAction` are covered — don’t annotate them again.
  - `nonisolated` for pure helpers (formatting, decoding, maths).
  - `actor` for shared mutable state with no UI — a serial queue attached to the data.
  - `Sendable` on models that cross a boundary; value types qualify for free.
- **Structured concurrency:** `async let` and task groups for independent work, not a queue
  of sequential `await`s. A task group always waits for its children.

  ```swift
  async let balance = service.fetchBalance()
  async let limits  = service.fetchLimits()
  let (b, l) = try await (balance, limits)
  ```

- **`Task { }` inherits context** (what you want almost always); `Task.detached` is rare.
  In SwiftUI prefer **`.task { }`**, which cancels automatically when the view disappears.
- **Legacy callbacks** (delegates, notifications, completion handlers) hop with
  `Task { @MainActor in … }`. Use `MainActor.assumeIsolated` only when the API *guarantees*
  main.
- **Swift 6.2 ergonomics** make this friendlier: a module can default to main-actor
  isolation, and `@concurrent` marks work that should run off the main actor.

```swift
// SwiftUI — runs on appear, auto-cancelled on disappear
List(model.cards) { CardRow(card: $0) }
    .task { await model.load() }

// UIKit — UIViewController is already @MainActor; own the task so you can cancel it
@MainActor final class CardsViewController: UIViewController {
    private let model: CardsModel
    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadTask = Task { await model.load() }   // cancel in viewDidDisappear/deinit
    }
}
```

## 14. Functions, data, and composition

**Build pipelines from small, independently readable and testable steps.**

```swift
let topMerchants = transactions
    .filter { !$0.isRefunded }
    .map(\.merchant)
    .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
    .sorted { $0.value > $1.value }
    .prefix(3)
```

- **`compactMap`, not the old optional-returning `flatMap`** — `raw.compactMap { Int($0) }`
  turns `[T?]` into `[T]`; `flatMap` on a sequence *flattens*.
- **`reduce(into:_:)`** for value-type accumulators (cheaper than `reduce(_:_:)`).
- **Each chain step allocates** — over a large collection add `.lazy` and let `prefix`
  short-circuit.
- **Point-free `\.email` at the readable end only**; `{ $0.email }` is fine when key paths
  get cryptic.

**Structure:**

- **Prefer protocol-oriented composition over inheritance**: protocol + extension + default
  implementation, so unrelated value types share behaviour.

  ```swift
  protocol Payable { var amount: Decimal { get }; func pay() throws }

  extension Payable {                       // shared behaviour, no base class
      func pay() throws { /* validate, audit, call service */ }
  }

  final class CardsModel {                  // @MainActor @Observable in a screen model
      private let service: any CardServicing // injected, not `.shared`
      init(service: any CardServicing) { self.service = service }
  }
  ```

- **Inject dependencies through `init`**; construct live objects only at the composition
  root. Avoid service singletons.
- **Don’t over-abstract.** Point-free style, phantom types, and custom operators earn their
  place only where a mistake would otherwise be silent and expensive; past that they hurt
  readability. **Define new operators sparingly**; don’t overload existing ones with
  surprising meaning.
- **Prefer explicit control flow** over trapping arithmetic: use overflow operators
  (`&+`) only when wraparound is intended; otherwise let the trap catch the bug.

## 15. Performance-shaped style

Performance is a **loop, not a habit**: turn the complaint into a number → reproduce on a
Release build on the oldest device you support → measure at the right layer → localise to
one line → fix the cause → re-measure → encode the number as a test. Profile first, guess
never.

Style choices that pay off *after* measurement:

- **Value types and `final`** — no per-frame heap/ARC churn, static dispatch (SwiftUI
  rebuilds view structs every frame; UIKit reuses cells).
- **Decode *and* down-sample images off the main thread**, to display size — usually the
  biggest scroll win.
- **`reduce(into:)` / `.lazy`** to avoid intermediate allocations.
- **Event-driven updates, not polling `Timer`s.**
- **`OSSignposter`** to name the line and turn “the feed is slow” into “`bindCell` takes
  14 ms”.

Rough budgets worth memorising: **< 100 ms** synchronous main-thread work for a discrete
interaction; **< 1 display refresh interval (8/17 ms)** for continuous interaction; **< 5 ms**
to prepare the next screen update.

## 16. Logging and security

- **Private by default.** Use `Logger` with privacy annotations — `.private` for
  identifiers, `.sensitive` for credentials, `.private(mask: .hash)` for correlation,
  `.public` only for status codes, durations, and route *templates*.

  ```swift
  log.notice("card frozen for \(userID)")                        // userID → <private>
  log.notice("last4 \(last4, privacy: .public)")
  log.notice("trace \(traceID, privacy: .private(mask: .hash))") // correlate, not identify
  ```

  The project's `LoggerProtocol` carries the privacy decision in the seam
  (`LogPrivacy`: `visible` / `redacted` / `sensitive`, mapped to the log's
  annotation in `LoggingService`, `architecture.md` §7.2). It defaults to
  `.redacted`, so identifiers stay out of persisted logs unless a caller marks a
  message `.visible` — and never mark a PAN, CVV, or token visible.

- **Typed events, never `[String: Any]`.** Model loggable/analytics events as enums so a
  `Card` can’t leak into a parameter, and adding an event forces a visibility decision at
  compile time.
- **Own the vendor boundary.** Analytics and crash SDKs sit behind protocols you own;
  feature code never imports a vendor SDK.
- **Mask at the type, not the call site.** Never log PANs, tokens, or
  `error.localizedDescription` as a crash reason.

  ```swift
  struct MaskedPAN: Sendable, CustomStringConvertible {
      let last4: String
      init(_ pan: String) { last4 = String(pan.filter(\.isNumber).suffix(4)) }
      var description: String { "•••• •••• •••• \(last4)" }
  }
  ```

- Gate secrets behind the Keychain, use file protection for sensitive local data, and
  harden card-entry screens (`isSecureTextEntry`, privacy overlays).

---

# Part VI — Framework idioms

SwiftUI and UIKit are equal citizens. Prefer **SwiftUI for new screens** and **UIKit where it
already exists** (or where it fits better); both observe the same shared `@Observable`
**model** — there is no ViewModel layer — and bridge with thin representables /
`UIHostingController` so no business logic lives in either.

## 17. SwiftUI

One micro-example per topic; §18 mirrors them for UIKit.

- **State:** `@State` for local view state, an `@Observable` model for shared state. A view
  is a value; `body` is a pure function of state. The model is a
  `@MainActor @Observable final class` publishing an explicit `viewState` enum; it is
  injected through the environment (or passed to a feature-local screen) and **never created
  in the view**. One-shot work runs from the view's `.task`/`.refreshable`; the model owns
  only its long-lived subscription tasks.

  ```swift
  struct CardView: View {
      @State private var isFlipped = false
      @Environment(CardsModel.self) private var model   // shared @Observable
      var body: some View { Text(model.name) }
  }
  ```

- **Keep `body` lean and side-effect-free.** `@Observable` tracks *what a body reads*, so a
  stray read widens dependencies; do no work in the initialiser — SwiftUI builds views
  freely.
- **Layout from stacks, not frames.** Reach for `GeometryReader` only when measurement is
  genuinely needed; prefer `.aspectRatio`, `ViewThatFits`, `containerRelativeFrame`,
  `onGeometryChange`, `.scrollTransition`.

  ```swift
  HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(card.name)
      Spacer()
      Text(card.last4).foregroundStyle(.secondary)
  }
  ```

- **Lists identify by a stable `id`** so diffing is cheap.

  ```swift
  List(model.cards) { card in CardRow(card: card) }   // Card: Identifiable
  ```

- **Lifecycle = `.task` / `.onChange`.** `.task` runs on appear and cancels on disappear.

  ```swift
  .task { await model.load() }
  .onChange(of: model.query) { _, _ in model.search() }
  ```

- **Corners and shadow.**

  ```swift
  card.clipShape(.rect(cornerRadius: 16))             // .continuous for the squircle
      .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
  ```

- **Dynamic Type via semantic fonts** — they scale automatically.

  ```swift
  Text(card.name).font(.headline)
  ```

- **Style controls with a `ButtonStyle`**, not ad-hoc modifiers.

  ```swift
  Button("Pay") { pay() }.buttonStyle(.borderedProminent)
  ```

- **Navigation:** `NavigationStack` + `navigationDestination(for:)`, registered once, on a
  view always present in the stack.

  ```swift
  NavigationStack(path: $path) {
      List(model.cards) { CardRow(card: $0) }
          .navigationDestination(for: Card.self) { CardDetail(card: $0) }
  }
  ```

- **Accessibility is not optional.**

  ```swift
  Image(systemName: "lock.fill").accessibilityLabel("Locked")
  ```

- **Bridge to UIKit with a thin representable**; keep the model framework-neutral.

  ```swift
  struct MapView: UIViewRepresentable {
      func makeUIView(context: Context) -> MKMapView { MKMapView() }
      func updateUIView(_ view: MKMapView, context: Context) { /* … */ }
  }
  ```

## 18. UIKit

Mirrors §17 topic for topic.

- **State:** the view controller holds the same `@Observable` model, renders from it, and
  forwards actions — no business logic in the controller.

  ```swift
  final class CardsViewController: UIViewController {
      private let model: CardsModel            // the shared @Observable model
      private func render() { titleLabel.text = model.cards.first?.name }
  }
  ```

- **Keep controllers thin.** Build views in `loadView`/`viewDidLoad`, never in a stored
  property’s initialiser, so construction stays lazy and testable.
- **Layout from anchors, activated as a batch** — typed and more readable than the stringly
  initializer; prefer the layout guides over spacer views.

  ```swift
  NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
      titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
  ])
  ```

- **Self-sizing cells:** `rowHeight = automaticDimension` + a closed top-to-bottom
  constraint chain; a multiline label needs `preferredMaxLayoutWidth`.
- **Lists reuse and re-configure.** Use the `indexPath` dequeue overload and a diffable data
  source, and set **every** content-dependent property in `configure(with:)` (or reset in
  `prepareForReuse()`).

  ```swift
  var config = cell.defaultContentConfiguration()   // iOS 14+
  config.text = card.name
  cell.contentConfiguration = config

  var snapshot = NSDiffableDataSourceSnapshot<Section, Card>()
  snapshot.appendItems(model.cards)
  dataSource.apply(snapshot, animatingDifferences: true)
  ```

- **Lifecycle = own the task.** Start work on the main actor; cancel it when the view goes
  away.

  ```swift
  private var loadTask: Task<Void, Never>?
  override func viewDidLoad() {
      super.viewDidLoad()
      loadTask = Task { await model.load() }
  }
  deinit { loadTask?.cancel() }
  ```

- **Corners and shadow.** `masksToBounds = true` clips the shadow too — put the shadow on a
  wrapper; recompute `cornerRadius` in `layoutSubviews()` if `bounds` changes.

  ```swift
  card.layer.cornerRadius = 16
  card.layer.cornerCurve = .continuous
  card.layer.shadowOpacity = 0.15
  card.layer.shadowRadius = 8
  card.layer.shadowOffset = CGSize(width: 0, height: 2)
  ```

- **Dynamic Type via preferred fonts**, and let the label track the setting.

  ```swift
  label.font = .preferredFont(forTextStyle: .headline)
  label.adjustsFontForContentSizeCategory = true
  ```

- **Style controls with a configuration** (iOS 15+), not `setTitle(_:for:)` and friends.

  ```swift
  var config = UIButton.Configuration.filled()
  config.title = "Pay"
  button.configuration = config
  ```

- **Navigation:** push onto the navigation controller (or drive it from a coordinator).

  ```swift
  navigationController?.pushViewController(
      CardDetailViewController(card: card), animated: true)
  ```

- **Accessibility is not optional.**

  ```swift
  lockImageView.isAccessibilityElement = true
  lockImageView.accessibilityLabel = "Locked"
  ```

- **Prefer `UIGraphicsImageRenderer`** over `UIGraphicsBeginImageContext`.
- **Bridge to SwiftUI with `UIHostingController`**; keep the hosting layer thin and free of
  logic.

  ```swift
  let host = UIHostingController(rootView: CardsListView(model: model))
  addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
  ```

## 19. Modern APIs over legacy

- **File access:** `URL`-based APIs, not string paths.

  ```swift
  let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
  ```

- **Sorting:** `NSSortDescriptor(keyPath:)` (compile-checked) over `key:`.
- **Instrumentation:** `OSSignposter` (iOS 15+) over the C `os_signpost` API.
- **Logging:** `Logger` with privacy annotations.
- **State:** `@Observable` over `ObservableObject`.
- **Testing:** Swift Testing for unit/logic; XCTest for UI and performance (§21).
- **Gate availability** with `#available`/`@available` and name the version. Pick a minimum
  deployment target that matches your audience (commonly one or two majors back) and gate
  everything newer.

---

# Part VII — Documentation and tests

## 20. Documentation comments

- **Use `///`, never `/** … */`.**
- **Open with a single-sentence summary**, terminated with a period, written as a verb phrase
  for methods and a noun phrase for properties — no “This method …”.
- **Document `Parameter(s)`, `Returns`, `Throws`** in that order; singular `Parameter` for
  one argument, plural `Parameters` for several. Continuation lines indent +4.
- **Apple’s markup for rich formatting** — `` `backticks` `` for symbols, `*italic*`,
  `**bold**`, blank `///` lines between paragraphs, fenced code for examples. This is what
  DocC renders.
- **Where to document:** every `open`/`public` declaration and each public member. Exempt:
  self-explanatory enum cases, overrides/requirements (document only *new* behaviour — never
  copy the base comment), extensions themselves, and test types/methods. Never write a
  comment that merely restates the code — and never omit a comment whose only job is to
  explain a term the reader won’t know.

```swift
/// Returns the sum of the numbers in the given array.
///
/// - Parameter numbers: The numbers to sum.
/// - Returns: The sum of the numbers.
func sum(_ numbers: [Int]) -> Int { /* … */ }
```

## 21. Testing style

- **Swift Testing is the default** for unit and logic tests:

  ```swift
  @Suite("Card model") @MainActor
  struct CardModelTests {
      @Test func loadsCards() async {
          let model = CardsModel(service: MockCardService(result: .success([.fixture])))
          await model.load()
          #expect(model.cards.count == 1)
      }

      @Test("Valid IBANs pass", arguments: ["EE38…", "LT…"])
      func ibanValidation(_ iban: String) { #expect(IBANValidator.isValid(iban)) }
  }
  ```

- **XCTest remains for UI automation** (`XCUIApplication`) and **performance** (`measure {}`)
  — the two things Swift Testing doesn’t cover.
- **A pyramid, not a diamond:** many fast unit tests over models and pure logic, a
  thin band of integration tests at the network/decoding seam, and a handful of UI tests on
  the journeys that would cost money if they broke.
- **Test the model, not the view.** Both frameworks: unit-test the `@MainActor` model
  with injected fakes (mark the suite `@MainActor` when it touches UI state); reserve
  XCUITest for view/controller wiring and critical journeys.
- **Determinism:** pin locale/calendar/timezone; reset shared state (Keychain, `UserDefaults`,
  caches) between tests; stub the transport (`URLProtocol`) rather than hitting a live
  backend; prefer awaiting an expectation over `sleep`. Use accessibility identifiers and
  `waitForExistence`, never fixed sleeps, in UI tests.
- **Comments in tests are exempt from §20’s documentation requirement**, but `// MARK:`
  grouping still helps.

---

# Appendix A — Modern Swift notes (Swift 6 / iOS 26)

The version each rule arrived in — worth knowing when you turn it on:

- **Concurrency (§13).** `async`/`await`, `Task`, actors, `@MainActor`: Swift 5.5. `Sendable`
  violations become **errors** in the Swift 6 language mode; default main-actor inference
  and `@concurrent` arrive in Swift 6.2.
- **Typed throws** `throws(E)`: Swift 6.0.
- **Access control.** `package`: Swift 5.9. Explicit `any` for existentials: Swift 5.6.
- **Observation.** `@Observable` replaces `ObservableObject` + `@Published`: iOS 17.
- **Multiple trailing closures** (labelled): Swift 5.3.
- **Testing.** **Swift Testing** (`@Test`, `#expect`, `@Suite`) is the default for logic
  tests; XCTest stays for UI and performance: Xcode 16 / Swift 6.
- **Formatting.** **SwiftFormat** (nicklockwood) owns shape and **SwiftLint** owns the
  semantics, so most of Part III is enforced rather than reviewed. Both are pinned — the exact
  SwiftFormat version in CI, both via the committed `Brewfile` locally.
- **Documentation.** **DocC** renders the `///` markup in §20.
- **OS versioning.** Apple moved to **unified versioning at 26.0** (`anyAppleOS`), so gate
  APIs with `@available` rather than assuming a number.
- **Errors.** `Result` is reserved for outcomes that outlive the call; `async throws` covers
  the rest.

# Appendix B — Quick reference

- **Formatting:** 4-space indent, 100-col, K&R braces, no semicolons, one statement/line,
  trailing commas in multi-line collections — enforced by SwiftFormat.
- **Files:** `.swift`, named for the primary type; `Type+Protocol.swift` for conformances.
- **Imports:** first, grouped, sorted, one blank line between groups, not wrapped.
- **Names:** fluent at the call site; `UpperCamelCase` types, `lowerCamelCase` members;
  no Hungarian prefixes.
- **Types:** `let`/`struct`/`enum` by default; `final` leaf classes; enums for state.
- **Errors:** `throws` default, `Result` only when it must outlive the call; no `try!`/force
  unwrap outside tests.
- **Concurrency:** Swift 6 mode; `@MainActor` models, `actor` for shared state, `Sendable`
  boundaries; `async let`/task groups for parallelism.
- **Docs:** `///` with summary + tags; document every public declaration.
- **Tests:** Swift Testing for logic, XCTest for UI/perf; deterministic and isolated.

# Appendix C — Basis

- **Naming and API shape:** Apple’s Swift API Design Guidelines.
- **Formatting and language practice:** the Swift standard library style.
- **Framework and performance idioms:** Apple’s current documentation (Swift 6 / iOS 26 era).
