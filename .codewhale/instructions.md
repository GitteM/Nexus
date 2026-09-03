# Nexus — Codewhale Project Instructions

Entry point for Codewhale working in this repository. **This file is injected
into every session, so it stays short.** The agent may run on a
limited-context model (DeepSeek): read only what the table below says, never
whole documents. One concern per file; `Documentation/README.md` is the index.

**Authority.** The rules below are a **condensed mirror** of
`Documentation/AGENTS.md` §3–§6 so the highest-severity rules survive
injection. `AGENTS.md` is the canonical operating guide and wins on
conflict; if these two files disagree, this one is stale — fix it. The full
authority chain lives in `Documentation/README.md` (Conventions).

## Non-negotiables (worst failures, in order)

1. **Git.** Trunk-based development on `main`. Never commit or push to
   `main`. Work on a short-lived branch (`feature/`, `bugfix/`, `hotfix/`,
   `chore/`, `docs/`), open a PR, and let the user merge. Branches < 1 day;
   changes small. Confirm with `git status` / `git branch --show-current`
   before any git step.
2. **Commits.** Conventional Commits: `type(scope): subject` — subject ≤ 72
   chars, imperative mood, capitalized, no trailing period. Full spec:
   `Documentation/CONTRIBUTING.md`.
3. **Gates before submitting code.** `swiftformat .` clean, full workspace
   TestPlan green, zero build warnings. Docs-only changes skip the test
   suite — say so and state what you did verify.
4. **Architecture rules are constraints, not suggestions.** Read the
   relevant `Documentation/architecture.md` section first (see table). Never
   import upward or create package cycles; one `AppError` everywhere; no
   ViewModels, Combine, completion handlers, or `Result` at repository
   boundaries; `@Model` classes never leave NexusData; no sensitive data in
   logs/caches/configs.
5. **Docs stay in sync.** User-facing change → README/CHANGELOG; pattern or
   target change → `architecture.md`; workflow change → `AGENTS.md`;
   milestone/day state → `tasks.md` / `ROADMAP.md`.

## Reality beats prose

- Read `Documentation/AGENTS.md` at the start of any task — it is the
  operating guide (workflow, gates, conventions).
- Current day state comes from `Documentation/tasks.md` checkboxes and
  `git log`, never from dated "as of" notes in docs.
- Read files before describing them; verify results with tools; report what
  you could not verify.

## Where to look (decision table)

| Task | Read first |
|---|---|
| Any new work | `Documentation/AGENTS.md` (workflow + gates) |
| Architecture-sensitive code | `architecture.md`: §2 layering; the § for the layer you touch — §3 module map, §4 Domain, §5 `AppError`, §6 Data, §7 config/logging, §8 navigation, §9 presentation, §11 app target; §14 for one-paragraph recall; §13 Step 8 to verify invariants |
| Commit / PR rules | `Documentation/CONTRIBUTING.md` |
| Product scope + behavior | `Documentation/features.md` (scope overview) → `appspec.md` §2.x (rules/acceptance for the feature you touch); conflicts → `ROADMAP.md` §5 (architecture.md wins on patterns) |
| Day / milestone status | `Documentation/tasks.md` + `ROADMAP.md` |
| Which doc does what | `Documentation/README.md` |

## Repo at a glance

- **Nexus**: SwiftUI iOS banking app — card issuing, freeze/unfreeze,
  spending limits, balances, transactions, payments, security, Apple Pay.
- **Stack**: Swift 6.3 (Swift 6 mode), Xcode 26.6, iOS 17.0+; SPM packages
  `NexusDomain` / `NexusData` / `NexusFeatures` + thin app target
  (composition root); workspace `Nexus.xcworkspace`.
- **Architecture**: MV — `@MainActor @Observable` models drive SwiftUI
  views; explicit `viewState` enums; SwiftData + Keychain + in-memory actor
  cache; mocks behind `#if DEBUG`; `-demoMode` / `API_ENVIRONMENT = demo`.
- **Testing**: Swift Testing (`@Suite`/`@Test`/`#expect`) aggregated in
  `TestPlan.xctestplan`; UI tests launch with `-demoMode`. Local run:
  `xcodebuild test -workspace Nexus.xcworkspace -scheme Nexus -destination
  'platform=iOS Simulator,name=iPhone 17'`

## Know the intentional gaps

`Documentation/CHANGELOG.md` and the root README.md are empty **on
purpose** (populated at v1.0, Day 15 — see `tasks.md`). Do not treat them
as broken or "fix" them. `appspec.md` holds a behavior-spec skeleton — fill
feature sections at their milestone PRs, don't front-load them.
