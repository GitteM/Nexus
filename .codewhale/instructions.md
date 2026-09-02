# Nexus — Codewhale Project Instructions

Entry point for Codewhale working in this repository. The docs below are the source of truth; this file summarizes the standing rules. **Read `Documentation/AGENTS.md` first when starting any work, and re-read it before architecture-sensitive or workflow-sensitive changes.**

## Source of truth (all under `Documentation/`)

- **`AGENTS.md`** — agent guidance: where to work, trunk-based workflow, agent conventions, slash commands.
- **`architecture.md`** — architecture blueprint / porting guide; source of truth for patterns. Read before any architecture-sensitive work.
- **`features.md`** — product features.
- **`CONTRIBUTING.md`** — commit message spec & PR process.
- **`appspec.md`** — app specification.
- **`ROADMAP.md`** / **`tasks.md`** — roadmap and task tracking.

## Project at a glance

- **Nexus**: SwiftUI iOS banking app focused on cards and their features (issuing, freeze/unfreeze, spending limits, balances, transactions, payments, security, Apple Pay).
- **Stack**: Swift 6.3 (Swift 6 mode), Xcode 26.6, iOS 17.0+ deployment target, Swift Package Manager (`NexusDomain`, `NexusData`, `NexusFeatures` + thin app target), workspace `Nexus.xcworkspace`.
- **Architecture**: MV (Model-View) — SwiftUI views driven by `@MainActor @Observable` models; no ViewModels, no Combine, no completion handlers; one `AppError`; SwiftData + Keychain + in-memory actor cache; mocks behind `#if DEBUG`; `-demoMode` for previews/tests/demo.
- **Testing**: Swift Testing (`@Suite`/`@Test`/`#expect`), workspace TestPlan, UI tests launch with `-demoMode`.

## Standing rules (critical)

1. **Git workflow** — trunk-based development on `main` with short-lived branches (`feature/`, `bugfix/`, `hotfix/`, `chore/`). **Never push to or commit directly on `main`.** Always branch, open a PR, and let the user merge. Keep branches < 1 day and changes small.
2. **Commits** — Conventional Commits: `type(scope): description`, subject ≤ 72 chars, imperative mood. See `Documentation/CONTRIBUTING.md`.
3. **Before submitting a change** — run `swiftformat .`, run the workspace test suite (`xcodebuild test -workspace Nexus.xcworkspace -scheme Nexus -destination 'platform=iOS Simulator,name=iPhone 17'`), and build without warnings.
4. **Architecture-sensitive work** — read `Documentation/architecture.md` first and follow its patterns; never import upward or create package cycles.
5. **Docs** — keep `README.md`, `CHANGELOG.md`, `Documentation/architecture.md`, and `Documentation/AGENTS.md` updated when relevant.

## Current repo status (as of 2026-09-02)

- **Repo initialized** 2026-09-01 (Day 1); remote `origin` = `git@github.com:GitteM/Nexus.git`; default branch `main`. Trunk-based workflow applies — confirm with `git status` before following AGENTS.md git steps.
- **Progress: M0 (Day 1) and M1 (Days 2–4) merged to `main`** — workspace + package skeletons (M0); Domain entities, `AppError`, repository/service protocols (M1). Verified: full TestPlan green (159 Domain tests in 20 suites), zero build warnings.
- `Documentation/ROADMAP.md` and `tasks.md` are populated and kept in sync; `Documentation/appspec.md` is still empty (not a source of truth).
