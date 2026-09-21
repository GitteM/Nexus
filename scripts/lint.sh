#!/usr/bin/env bash
#
# Report-only checks, in the order and with the commands CI parity expects:
# shape first (SwiftFormat --lint), then semantics (SwiftLint --strict).
# Neither command writes. This is what the pre-commit hook runs after
# formatting.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

swiftformat --lint .
swiftlint --strict
