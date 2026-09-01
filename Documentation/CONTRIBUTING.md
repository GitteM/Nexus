# Contributing to Nexus

> **TL;DR:** All commits must follow Conventional Commits. Use `type(scope): description`. Keep subject lines under 72 characters, use imperative mood, and no period at the end.

---

## 📋 Table of Contents

1. [Commit Message Specification](#-commit-message-specification)
   - [Format Overview](#format-overview)
   - [Allowed Types](#allowed-types)
   - [Scope Rules](#scope-rules)
   - [Subject Line Rules](#subject-line-rules)
   - [Body Rules](#body-rules)
   - [Footer Rules](#footer-rules)
   - [Breaking Changes](#breaking-changes)
   - [Validation Examples](#validation-examples)
2. [Branch Naming Convention](#-branch-naming-convention)
3. [Pull Request Process](#-pull-request-process)
4. [Development Setup](#-development-setup)
5. [Testing Requirements](#-testing-requirements)
6. [Code of Conduct](#-code-of-conduct)

---

## 📝 Commit Message Specification

### Format Overview

All commit messages MUST follow the **Conventional Commits v1.0.0** specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Allowed Types

| Type | When to Use | Example |
| :--- | :--- | :--- |
| **`feat`** | A new feature or user-facing functionality | `feat: add password reset flow` |
| **`fix`** | A bug fix for existing functionality | `fix: correct session timeout handling` |
| **`docs`** | Documentation-only changes (README, API docs, comments) | `docs: update installation guide` |
| **`style`** | Code style changes: formatting, whitespace, missing semicolons, etc. | `style: format with Prettier` |
| **`refactor`** | Code restructuring that neither fixes a bug nor adds a feature | `refactor: extract validation service` |
| **`perf`** | Performance optimization | `perf: memoize expensive computation` |
| **`test`** | Adding new tests or correcting existing ones | `test: add edge cases for login` |
| **`chore`** | Build tooling, dependency updates, or maintenance tasks | `chore: upgrade typescript to v5` |
| **`ci`** | Changes to CI/CD configuration and scripts | `ci: add GitHub Actions workflow` |
| **`build`** | Changes to build system or external dependencies | `build: update webpack configuration` |
| **`revert`** | Reverts a previous commit | `revert: revert "feat: add logout button"` |

### Scope Rules

The scope is **optional** but highly recommended when the change affects a specific module/component.

- **Format:** `type(scope): description`
- **Allowed characters:** Lowercase letters, hyphens (`-`), and underscores (`_`)
- **Examples:**
  - `feat(auth): add OAuth2 provider`
  - `fix(api): correct response status code`
  - `refactor(ui/buttons): simplify button component`

**Scope Guidance:**
- Use the folder/module name: `(components)`, `(hooks)`, `(utils)`
- Use the feature name: `(auth)`, `(dashboard)`, `(checkout)`
- For cross-cutting changes, omit the scope: `feat: add logging throughout app`

### Subject Line Rules

| Rule | Requirement | ✅ Good Example | ❌ Bad Example |
| :--- | :--- | :--- | :--- |
| **Length** | ≤ 72 characters (50 is ideal) | `fix: correct timeout error` (24 chars) | `fix: correct the timeout error that occurs when the user session expires after 30 minutes` (89 chars) |
| **Mood** | Imperative (command form) | `Add`, `Fix`, `Update` | `Added`, `Adds`, `Fixed` |
| **Capitalization** | Capitalize first letter | `Fix login bug` | `fix login bug` |
| **Punctuation** | No period at the end | `Add user profile view` | `Add user profile view.` |
| **Content** | Summary of *what* changed, not *how* | `Add payment validation` | `Add if statement for payment` |

**Quick Subject Checklist:**
```
✅ "Fix memory leak in image loader"
✅ "Add support for dark mode"
✅ "Update error messages for validation"
❌ "Fixed memory leak"           (past tense)
❌ "fix: memory leak"            (lowercase)
❌ "Add support for dark mode."  (has period)
```

### Body Rules

The body is **optional** but required when the change needs explanation beyond the subject line.

| Rule | Requirement |
| :--- | :--- |
| **Separation** | Separate body from subject with a blank line |
| **Line wrapping** | Wrap at 72 characters |
| **Content focus** | Explain the *what* and *why*, NOT the *how* |
| **Paragraphs** | Use multiple paragraphs for complex changes |

**Good Body Example:**
```
fix: correct user session timeout handling

The session was not being properly invalidated when users
closed their browser, leading to stale sessions persisting
beyond the intended TTL.

This change explicitly calls session.destroy() on browser
close events and adds a cleanup routine for orphaned
sessions every 5 minutes.
```

### Footer Rules

Footers are **optional** and used for:

1. **Breaking Change Notification** (see below)
2. **Issue References**

**Issue Reference Format:**
```
feat: add user settings page

Closes #42
Refs #37, #41
```

### Breaking Changes

To signal a breaking change (backward-incompatible API changes), use **ONE** of these methods:

**Method 1: Exclamation Mark in the Header**
```
feat(api)!: change response format for user endpoint
```

**Method 2: Footer with Breaking Change**
```
feat: update authentication flow

BREAKING CHANGE: JWT token format has changed. Existing tokens
will be invalidated and require re-authentication.
```

---

### Validation Examples

**✅ Valid Commits**

```bash
feat(auth): add biometric login support
fix: correct rate limiting for API endpoints
docs: update README with new configuration options
refactor(utils): extract date formatting helpers
perf: lazy load images in gallery view
test: add unit tests for payment processor
chore: upgrade dependencies to latest versions
```

**❌ Invalid Commits**

| Commit Message | Why It's Invalid |
| :--- | :--- |
| `updated code` | No type prefix |
| `FEAT: add login` | Type must be lowercase |
| `fix: Added validation` | Past tense ("Added") |
| `fix(API): update endpoint` | Scope must be lowercase ("api") |
| `fix: corrected the bug.` | Period at the end |
| `feat: add long description that goes way beyond the seventy two character limit which makes it hard to read` | Exceeds 72 characters |
| `refactor: changed function name and updated the README and also fixed a bug` | Multiple changes in one commit (violates atomic commits) |

---

## 🌿 Branch Naming Convention

Use descriptive branch names with forward slashes:

```
feature/add-dark-mode
fix/user-login-error
docs/update-installation-guide
chore/update-dependencies
release/v2.0.0
```

---

## 🔄 Pull Request Process

1. **Title format:** Follow the same commit format for PR titles (e.g., `feat: add dark mode`)
2. **Description template:**
   - **What does this PR do?** - Summary of changes
   - **Why is this needed?** - Context or issue link
   - **Testing:** - How to test locally
   - **Screenshots:** - If UI changes
3. **Checklist:**
   - [ ] Commit messages follow Conventional Commits
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] All tests pass locally

---

## 🛠️ Development Setup

```bash
# Clone and install
git clone https://github.com/username/project.git
cd project
npm install

# Development workflow
npm run dev     # Start dev server
npm test        # Run tests
npm run lint    # Check code style
npm run build   # Build for production
```

---

## 🧪 Testing Requirements

- **Unit tests:** Required for all new features and bug fixes
- **Coverage:** Maintain or improve existing coverage (≥80%)
- **E2E tests:** Required for user-facing features
- **Run:** `npm run test:coverage` before opening PR

---

## 📄 Code of Conduct

Be respectful, inclusive, and constructive. Read our full [Code of Conduct](CODE_OF_CONDUCT.md).

---

**🎯 Reminder:** All commits are validated automatically using `commitlint`. Invalid commits will be rejected. Save yourself the hassle and use the format above!
