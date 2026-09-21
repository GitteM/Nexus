#!/usr/bin/env bash
#
# Xcode "Run Script" build-phase helper — inline SwiftLint feedback.
#
# Report-only: it never fails the build. The *enforcing* gate is the committed
# pre-commit hook (.githooks/pre-commit) and, in CI, `swiftformat --lint .`.
#
# Xcode runs build phases with a sanitized PATH that does NOT include
# Homebrew's bin, so `swiftlint` is resolved from the usual install locations
# before giving up. If it still isn't found the phase no-ops (exit 0), which
# keeps CI — where SwiftLint isn't installed — unaffected.
#
# Wiring: Nexus target → Build Phases → Run Script ("SwiftLint"),
#   script body "${SRCROOT}/scripts/lint-buildphase.sh",
#   "Based on dependency analysis" unchecked,
#   build setting ENABLE_USER_SCRIPT_SANDBOXING = No.
set -uo pipefail

# Escape hatch for a deliberately unconventional build.
if [ "${SWIFT_LINT_SKIP:-0}" = "1" ]; then
  exit 0
fi

# Skip clean-only builds; there is nothing to lint.
case "${ACTION:-build}" in
  clean) exit 0 ;;
esac

# Xcode's PATH omits Homebrew, so look beyond it rather than silently skipping.
resolve_swiftlint() {
  if command -v swiftlint >/dev/null 2>&1; then
    command -v swiftlint
    return 0
  fi
  for candidate in \
    /opt/homebrew/bin/swiftlint \
    /usr/local/bin/swiftlint \
    "${HOME:-/root}/.local/bin/swiftlint"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! swiftlint_bin="$(resolve_swiftlint)"; then
  echo "note: swiftlint not found — skipping inline lint (install with 'brew bundle')."
  exit 0
fi

# Lint the whole repo from its root so the root config and the per-Tests
# nested configs both apply. `--quiet` hides the progress chatter; violations
# still print in Xcode's reporter format and appear inline.
cd "${SRCROOT:-$(git rev-parse --show-toplevel)}"
echo "note: SwiftLint $("$swiftlint_bin" version) — linting ${PWD}"
"$swiftlint_bin" --quiet || true
exit 0
