# iOS App: Nexus - Agent Guidance

> **Companion docs:** [architecture.md](architecture.md) (architecture blueprint) · [features.md](features.md) (product features) · [CONTRIBUTING.md](CONTRIBUTING.md) (commit message spec & PR process)

## Where to work right now (read this first)
- **Repo:** [Link to your repository].
- **Default branch:** `main` - This is always in a releasable state.
- **Active branch:** Before you start, confirm with `git branch --show-current`. Always branch from `main` for new work.
- **No `develop` or `release` branches:** We use trunk-based development with `main` as the only permanent branch.

## 🏦 What the app is (from features.md)

Nexus is a SwiftUI iOS banking app focused on **cards and their features**. Highlights:

- **Card management** – dashboard with card art and status (active/frozen/expired), freeze/unfreeze, report lost/stolen, replacement requests, PIN management (biometric-protected), virtual card personalization.
- **Balances & transactions** – real-time balances, transaction history with search/filter (date, category, amount, status), transaction details.
- **Payments** – credit card payments (minimum/full/custom amount) with confirmation receipts.
- **Security** – biometric authentication (Face ID / Touch ID), app lock on background, session timeout, secure PIN entry.
- **iOS integrations** – Apple Pay provisioning (`PKAddPaymentPassViewController`), Apple Wallet issuer extension, native biometric login.
- **Controls & alerts** – per-card spending limits (daily/weekly/monthly), real-time push alerts.
- **Demo mode** – mock data, simulated network calls, local state persistence, and a reset-to-default option for demonstrations (`-demoMode` launch argument or `API_ENVIRONMENT = demo`).

See [features.md](features.md) for the full feature list.

## 🏗️ Core Project Setup
- **Workspace / Project file:** The main Xcode workspace is `Nexus.xcworkspace`.
- **Minimum Deployment Target:** iOS 17.0 (raise to iOS 18 to unlock SwiftData macros and `@Entry`).
- **Dependency Manager:** Swift Package Manager – three packages under `AppPackages/` (`NexusDomain`, `NexusData`, `NexusFeatures`) plus a thin app target (composition root). No umbrella modules; import concrete targets.
- **Swift Version:** Swift 6.3 (Swift 6 language mode, `swift-tools-version: 6.3`), Xcode 26.6.
- **UI Framework:** SwiftUI.
- **Architecture:** MV (Model-View) – SwiftUI views driven by `@Observable` models; **no ViewModel layer, no Combine, no completion handlers**. Dependency rule: Domain depends on nothing; the app target → NexusFeatures → NexusData → NexusDomain.
- **Testing:** Swift Testing (`@Suite`/`@Test`/`#expect`) with test targets beside code, aggregated in a workspace TestPlan (`TestPlan.xctestplan`); UI tests launch with `-demoMode`.
- **Full blueprint:** Read [architecture.md](architecture.md) before any architecture-sensitive work – it is the porting guide and source of truth for patterns.

## 🌿 Trunk-Based Development Workflow

This project strictly follows **Trunk-Based Development** with short-lived feature branches.

### Branch Strategy
- **Default branch:** `main` - Always in a releasable state.
- **No long-lived branches:** All work is on `main` or short-lived feature branches.
- **No `develop` or `release` branches:** These are forbidden. `main` is the only permanent branch.

### Working with Feature Branches
1. **Always branch from `main`:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/short-descriptive-name
   ```

2. **Branch naming convention:**
   - `feature/` - New features or enhancements
   - `bugfix/` - Bug fixes
   - `hotfix/` - Critical production fixes (merge directly after review)
   - `chore/` - Maintenance or refactoring

3. **Keep branches short-lived:** 
   - Branches should live for **< 1 day**
   - Keep changes small (< 100-200 lines changed)
   - Commit frequently with clear, descriptive messages

### Merging to `main`
1. **Before merging:** Update your branch:
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Always create a Pull Request:** Even for small changes.

3. **CI/CD must pass:** All tests and builds must be green.

4. **Merge strategy:** Use **Squash and Merge** to keep history clean. Fast-forward only.

### Daily Workflow
- **Start of day:** `git pull origin main` to get latest changes.
- **Multiple commits per day:** Commit small, logical changes frequently.
- **End of day:** Push branch and create draft PR if not ready.

### Feature Flags
- Incomplete features must be hidden behind feature flags
- Do not merge code that breaks the build or causes regressions
- Use `#if DEBUG` or remote feature flag services

## ✅ Commit Messages (Conventional Commits)

All commit messages **MUST** follow the **Conventional Commits** specification. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full rules; in short:

```
type(scope): description
```

- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`
- **Subject:** ≤ 72 characters, imperative mood, capitalized first letter, no trailing period
- **Scope (optional):** lowercase feature/module name, e.g. `feat(cards): add freeze card action`
- **Body (optional):** blank line after subject; explain *what* and *why*, wrapped at 72 chars
- **Footer (optional):** issue refs (`Closes #42`) and `BREAKING CHANGE:` notes

## ✅ Always Run Before Submitting a Change
1.  **Format code:** Run `swiftformat .` to ensure consistent style.
2.  **Run tests:** Execute the test suite (runs the workspace TestPlan):
    ```bash
    xcodebuild test -workspace Nexus.xcworkspace \
      -scheme Nexus \
      -destination 'platform=iOS Simulator,name=iPhone 17'
    ```
3.  **Check for warnings:** Build without warnings. Address any new warnings.
4.  **Verify CI locally:** Run the same checks that CI would run (Xcode 26.6, iPhone 17 simulator, iOS 26.5).

## 📦 Code & Architecture Guidelines (from architecture.md)

- **Layering:** Domain is pure Swift (no UI, persistence, SDK, Combine, OSLog). Data implements Domain protocols. Features hold views and `@Observable` models. The app target is the composition root (`AppContainer`). Never import upward or create package cycles.
- **State Management:** One `@MainActor @Observable` model per screen, injected via `@Environment`. No ViewModels, no `ObservableObject`/`@Published`, no Combine.
- **View state:** Each model publishes an explicit `viewState` enum (`loading` / `loaded` / `error` / `empty`); views switch on it and use `.task` / `.refreshable` for one-shot work.
- **Concurrency:** async/await + actors + `AsyncStream`. One-shot calls are `async throws`; live subscriptions return `AsyncStream`. No completion handlers, no `Result` at repository boundaries.
- **Errors:** The whole app speaks one `AppError` type – never raw `Error`, `NSError`, or SDK types across boundaries.
- **Use-case rule:** A use case/service type exists only when it composes ≥ 2 collaborators; the default is a model method.
- **Navigation:** `Router` holds a `[Route]` stack bound to `NavigationStack`; the route→view mapping lives in the app target.
- **Persistence:** SwiftData for durable data (`@Model` classes never leave NexusData), an in-memory actor cache for ephemeral state, Keychain for credentials. Never persist card numbers/CVV/tokens in plaintext; never log sensitive data.
- **Mocks & demo:** Mock repositories and the mock session manager live in `NexusData/Mocks` behind `#if DEBUG`; previews, tests, and demo mode all run the real models over the shared mocks.
- **Testing:** Write unit tests for all new business logic (Swift Testing); UI tests for critical user flows; aim for > 80% test coverage.
- **Accessibility:** Ensure all new UI elements are accessible with VoiceOver and support Dynamic Type.

## 🤖 Agent Work Conventions

### Git Workflow (CRITICAL)
- **NEVER** push directly to `main` without explicit permission.
- **ALWAYS** create a feature branch when making changes.
- **ALWAYS** check with the user before merging any PR.
- **DO NOT** commit directly to `main` - this is forbidden.

### Standard Agent Workflow for New Tasks
1. **Start new feature:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/short-descriptive-name
   ```

2. **Make changes:** Write code following project guidelines.

3. **Commit changes (Conventional Commits, see CONTRIBUTING.md):**
   ```bash
   git add .
   git commit -m "feat(cards): add freeze card action"
   ```

4. **Push and create PR:**
   ```bash
   git push origin feature/short-descriptive-name
   ```
   Then suggest: "I've pushed the changes. Would you like me to create a Pull Request?"

5. **After PR approval:** The user will merge, not the agent.

### Agent Slash Commands
- `/start-feature [description]` - Creates new feature branch from `main`
- `/sync` - Rebase current branch on latest `main`
- `/pr` - Create PR from current branch to `main`
- `/status` - Show current branch and uncommitted changes

## 🔄 Conflict Resolution
- If conflicts occur, rebase on `main`:
  ```bash
  git fetch origin
  git rebase origin/main
  ```
- Resolve conflicts locally
- Run tests again after resolving
- Push force if necessary: `git push --force-with-lease`

## 📝 Documentation
- Update `README.md` when adding significant features
- Document public APIs with Swift comments
- Keep `CHANGELOG.md` updated with notable changes
- Update [architecture.md](architecture.md) when architecture-sensitive patterns change
- Update this `AGENTS.md` if workflows change

---

**Remember:** This is a living document. Keep it updated as the project evolves!
