# AGENTS.md — Nexus Agent Operating Guide

> Who this is for: any AI coding agent working in this repo (Codewhale on
> Claude or DeepSeek, and similar), plus humans who want the same rules.
> Codewhale agents get a condensed injection summary in
> `.codewhale/instructions.md`; when the two differ, this file wins. The
> full authority chain lives in `Documentation/README.md` (Conventions).
>
> Companion docs: [architecture.md](architecture.md) (patterns) ·
> [features.md](features.md) (product) · [appspec.md](appspec.md) (feature
> behavior/acceptance) · [CONTRIBUTING.md](CONTRIBUTING.md) (commits/PRs) ·
> [README.md](README.md) (index for this folder & read-when map) ·
> [tasks.md](tasks.md) (day state) / [ROADMAP.md](ROADMAP.md) (release
> framing + decision log).

## 1. Repo at a glance

- **Nexus**: SwiftUI iOS banking app focused on **cards and their features**
  (issuing, freeze/unfreeze, spending limits, balances, transactions,
  payments, security, Apple Pay). See [features.md](features.md).
- **Remote**: `git@github.com:GitteM/Nexus.git`. Default branch `main` is
  the only permanent branch — no `develop`/`release`.
- **Stack**: Swift 6.3 (Swift 6 mode, `swift-tools-version: 6.3`), Xcode
  26.6, iOS 17.0+ floor. Workspace `Nexus.xcworkspace`; three SPM packages
  under `AppPackages/` (`NexusDomain`, `NexusData`, `NexusFeatures`) plus a
  thin `Nexus` app target (composition root). No umbrella modules — import
  concrete targets.
- **Architecture**: MV (Model-View). SwiftUI views driven by `@MainActor
  @Observable` models publishing explicit `viewState` enums. No ViewModels,
  no Combine, no completion handlers. One `AppError`. SwiftData + Keychain +
  in-memory actor cache; mocks behind `#if DEBUG`; `-demoMode` /
  `API_ENVIRONMENT = demo`.
- **Testing**: Swift Testing (`@Suite`/`@Test`/`#expect`), test targets
  beside code, aggregated in the workspace TestPlan (`TestPlan.xctestplan`);
  UI tests launch with `-demoMode`.

## 2. Read the right doc (do this before acting)

`Documentation/architecture.md` is 1,300+ lines (a porting guide) — **do not
read it whole for a routine change**. Read only the section for the layer you
touch:

| Task | Read |
|---|---|
| Any new work | This file (§3–§5), then the matching row below |
| Domain code (`NexusDomain`) | architecture.md §2, §4 (entities, protocols), §5 (`AppError`) |
| Data layer (`NexusData`) | architecture.md §2, §6 (session, data sources, repositories, persistence) |
| Features/UI (`NexusFeatures`) | architecture.md §2, §8 (Router), §9 (models/views/previews) |
| App target / composition root | architecture.md §2, §11 (`AppContainer`, `AppState`, demo mode) |
| Config or logging | architecture.md §7 |
| Need a mental reset | architecture.md §14 (one-paragraph summary) |
| Verify you kept the rules | architecture.md §13 Step 8 (invariants checklist) |
| Commit / PR rules | CONTRIBUTING.md |
| Product scope vs. decisions | features.md (scope); the feature's appspec.md §2.x for rules/acceptance; conflicts resolved in ROADMAP.md §5 (architecture.md wins) |
| Current day/milestone state | tasks.md (checkboxes); confirm with `git log` |

## 3. Trunk-based workflow (critical)

1. `main` is always releasable. **Never commit to or push `main` directly.**
2. Start from `main`: `git checkout main && git pull origin main` then
   `git checkout -b <prefix>/short-name`.
3. Prefixes: `feature/`, `bugfix/`, `hotfix/`, `chore/`, `docs/`.
4. Branches live **< 1 day**; keep changes small and commit frequently.
5. Before merging: `git fetch origin && git rebase origin/main`; resolve
   conflicts locally; re-run the gates (§5); push `--force-with-lease` only
   when required.
6. Always open a PR; **the user merges** (squash). Never merge your own PR.
7. Slash commands (Codewhale): `/start-feature [description]`,
   `/sync`, `/pr`, `/status`.

## 4. Commit messages (Conventional Commits)

```
type(scope): subject        # feat | fix | docs | style | refactor | perf |
                            # test | chore | ci | build | revert
```

- Subject ≤ 72 chars, imperative mood, capitalized, no trailing period.
- Scope: lowercase module/area, e.g. `feat(data)`, `fix(session)`,
  `docs(tasks)`. Omit for cross-cutting changes.
- Body: blank line, explain *what* and *why*, wrapped at 72 chars.
- Footer: `Closes #42` / `BREAKING CHANGE:` when applicable.
- Examples from this repo: `feat(data): add OffersDataSource with TTL
  cache`; `test(data): cover CardStateDataSource cache and parse paths`.
- Full spec with validation examples: CONTRIBUTING.md.

## 5. Definition of done — run before submitting any code

1. `swiftformat .` leaves no diffs (CI runs `swiftformat --lint .`).
2. Full workspace TestPlan green:
   ```bash
   xcodebuild test -workspace Nexus.xcworkspace \
     -scheme Nexus \
     -destination 'platform=iOS Simulator,name=iPhone 17'
   ```
3. Build with zero warnings.
4. Commits conventional + atomic; branch pushed; PR opened.
5. Docs updated where relevant (Non-negotiables #5 in `.codewhale/instructions.md`).
6. CI mirrors local (Xcode 26.6, iPhone 17 simulator, iOS 26.5 SDK).
   The per-PR CI gate runs the **full workspace TestPlan, UI suite
   included** (a failed test is retried once in-place). If free-tier
   cold-runner UI flakes appear, reproduce locally on a warm simulator
   before treating them as regressions; the on-demand "UI Tests" workflow
   remains available for extra confidence runs.

**Docs-only changes** (markdown/config prose): skip the test suite, but state
that you did, and confirm nothing but docs changed.

> **Known tooling noise — Xcode dependency-scan warnings (not a DoD
> failure).** The first `build-for-testing`/test run after a fresh
> DerivedData (or after `Reset Package Caches`) prints 12 warnings of the
> form `'Session' is missing a dependency on 'Entities' because dependency
> scan of Swift module 'Session' …` (Session/DataSources/Repositories/
> Persistence → Entities/ServiceProtocols/…). Verified facts: (1) they
> appear on **any** code state — same set with or without a diff — so they
> are never a regression; (2) NexusData's `Package.swift` already declares
> every flagged edge, so there is nothing to "fix" in the manifests; (3)
> they never fail builds or tests; (4) the next build in the same
> DerivedData prints **0** of them — they are a one-time artifact of
> Xcode 26.6's package-graph dependency scan on first generation. Do not
> chase them as a gate violation; ignore or re-run once.

## 6. Architecture invariants (from architecture.md §13 Step 8)

Verify these when you touch architecture-sensitive code:

- Domain imports nothing above Foundation; no SDK/OSLog/Combine in Domain.
- No upward imports; no package cycles; `Router` depends on nothing.
- One `AppError` across boundaries; no `Result` at repository boundaries;
  no `@unchecked Sendable`.
- Models own and cancel their subscription `Task`s; one-shot work runs from
  view `.task`/`.refreshable`.
- `@Model` classes never leave NexusData; credentials only in Keychain;
  no card numbers/CVV/tokens in logs, caches, or configs.
- Demo mode is `#if DEBUG` only — no network/Keychain/disk; release builds
  ignore `-demoMode`; views never depend on the concrete session class.

## 7. Reporting

State what changed, what you verified (and how), and what remains — never
present an unverified result as done. If a gate blocks you, name it and ask.

---

**Living document.** Update this file when workflows change; keep
`.codewhale/instructions.md` in sync (it must stay shorter).
