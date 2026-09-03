# Contributing to Nexus

> **TL;DR:** Conventional Commits: `type(scope): subject`. Subject ≤ 72
> chars, imperative mood, capitalized, no trailing period. Branches:
> `feature/` `bugfix/` `hotfix/` `chore/` `docs/`. You never merge your own
> PR — the user does. Nothing here is enforced by a commit hook; CI and the
> reviewer check, so agents must self-check against the rules below.

---

## 1. Commit message specification

All commit messages follow the **Conventional Commits v1.0.0** spec:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Allowed types

| Type | When to use | Example (Swift-flavored) |
| :--- | :--- | :--- |
| **`feat`** | New feature or user-facing functionality | `feat(data): add OffersDataSource with TTL cache` |
| **`fix`** | Bug fix | `fix(session): correct reconnect subscription replay` |
| **`docs`** | Documentation only | `docs(tasks): mark Day 6 data sources complete` |
| **`style`** | Formatting/whitespace, no behavior change | `style: format with swiftformat` |
| **`refactor`** | Restructure; no bug fix, no feature | `refactor(cards): extract validation helper` |
| **`perf`** | Performance improvement | `perf: memoize balance formatting` |
| **`test`** | Add/correct tests | `test(data): cover cache TTL expiry` |
| **`chore`** | Tooling/maintenance | `chore: drop placeholder DataSources stub` |
| **`ci`** | CI/CD config changes | `ci(pr): add DeepSeek AI code review workflow` |
| **`build`** | Build system / dependencies | `build(data): add Session dependency to DataSources` |
| **`revert`** | Revert a commit | `revert: revert "feat: add freeze card action"` |

### Scope

Optional but recommended when the change is localized. Lowercase module or
area name, hyphenated when needed: `domain`, `data`, `session`, `features`,
`app`, `ui`, `docs`, `ci`, `tasks`. Omit for cross-cutting changes.

### Subject line

| Rule | Requirement | ✅ | ❌ |
| :--- | :--- | :--- | :--- |
| Length | ≤ 72 chars (50 ideal) | `feat(data): add offers TTL cache` | `feat(data): add an offers data source that caches with a TTL and refreshes in the background` |
| Mood | Imperative | `Add`, `Fix`, `Update` | `Added`, `Adds`, `Fixed` |
| Capitalization | First letter capital | `Fix login bug` | `fix login bug` |
| Punctuation | No trailing period | `Add payment validation` | `Add payment validation.` |
| Content | What changed, not how | `Add payment validation` | `Add if statement for payment` |

### Body

- Optional; required when the subject needs context.
- Blank line after subject; wrap at 72 chars; explain *what* and *why*,
  not *how*.

### Footers

- `Closes #42` / `Refs #37, #41` for issue links.
- Breaking changes: `BREAKING CHANGE:` footer, or `!` after the type/scope
  (`feat(api)!: ...`).

### Validation examples

**✅ Valid**

```bash
feat(auth): add biometric login support
fix: correct session timeout handling
docs: update contributing guide
refactor(utils): extract date formatting helpers
test: add edge cases for transaction filtering
ci(pr): add DeepSeek AI code review workflow
```

**❌ Invalid**

| Commit | Why invalid |
| :--- | :--- |
| `updated code` | No type prefix |
| `FEAT: add login` | Type must be lowercase |
| `fix: Added validation` | Past tense |
| `fix(API): update endpoint` | Scope must be lowercase |
| `fix: corrected the bug.` | Trailing period |
| `feat: add long description that goes way beyond seventy two chars` | Subject too long |
| `refactor: change A and update B and fix C` | Not atomic — one change per commit |

---

## 2. Branch naming

One short-lived branch per day's work, from `main`:

- `feature/` — new features or enhancements
- `bugfix/` — bug fixes
- `hotfix/` — critical fixes for a released state
- `chore/` — maintenance, tooling, refactoring
- `docs/` — documentation-only changes

No long-lived or `develop`/`release` branches. Branches live < 1 day.

---

## 3. Pull request process

1. Push the branch and open a PR to `main` early (draft is fine).
2. **Title:** Conventional Commits format (`feat(cards): ...`).
3. **Description:**
   - What does this PR do?
   - Why is this needed? (issue link or context)
   - Testing: what you ran and the result
   - Screenshots: for UI changes
4. **Checklist:**
   - [ ] Commit messages follow Conventional Commits
   - [ ] `swiftformat .` clean
   - [ ] Workspace TestPlan green, zero build warnings
   - [ ] Tests added/updated for new logic
   - [ ] Docs updated (README/CHANGELOG, architecture.md, AGENTS.md,
     tasks.md/ROADMAP.md as relevant)
5. **Merge:** the user reviews and merges (squash). CI must be green first.
   Never merge your own PR; never push to `main`.

---

## 4. Development setup

```bash
# Prerequisites: Xcode 26.6, iPhone 17 simulator (iOS 26.5), swiftformat

open Nexus.xcworkspace            # full workspace (app + packages)

# Build / test the whole workspace TestPlan:
xcodebuild test -workspace Nexus.xcworkspace \
  -scheme Nexus \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Faster: build or test a single package:
swift build --package-path AppPackages/NexusDomain
swift test  --package-path AppPackages/NexusData

# Format / lint:
swiftformat .                     # format in place (run before submitting)
swiftformat --lint .              # CI lint check
```

Configs live in `Configs/` (`Debug.xcconfig`, `Release.xcconfig`,
`Info.plist`); the scheme and TestPlan are shared at the workspace root.

---

## 5. Testing requirements

- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`) — no XCTest
  for new suites.
- **Placement:** test targets beside code (`AppPackages/*/Tests`); suites
  aggregate in `TestPlan.xctestplan` and run in CI.
- **What to cover:** all new business logic (unit); critical user flows
  (UI tests, launched with `-demoMode`); aim for > 80% coverage overall.
- **Verify:** the full workspace TestPlan command above, not just the
  package you touched.

---

## 6. Documentation

Keep docs in sync with the change:

- Root `README.md` / `Documentation/CHANGELOG.md` — user-facing features
  (both are empty placeholders until v1.0, Day 15 — see tasks.md).
- `Documentation/architecture.md` — when a pattern, target, or invariant
  changes.
- `Documentation/AGENTS.md` and `.codewhale/instructions.md` — when
  workflows or agent conventions change.
- `Documentation/tasks.md` / `ROADMAP.md` — day/milestone status.
- `Documentation/features.md` — product scope; resolve scope conflicts in
  `ROADMAP.md` §5 (architecture.md wins).

---

**Living document.** Update it when these rules change, and keep
`Documentation/AGENTS.md` and `.codewhale/instructions.md` consistent with
it — agents read all three.
