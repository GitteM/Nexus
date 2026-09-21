#!/usr/bin/env bash
#
# SwiftFormat is the only tool that writes. This formats the whole tree in
# place, or just the paths you pass:
#
#   scripts/format.sh                       # format everything
#   scripts/format.sh Sources/Foo.swift     # format specific files
#
# The pre-commit hook (.githooks/pre-commit) runs this on staged files for you.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

if [ "$#" -gt 0 ]; then
  exec swiftformat "$@"
fi
exec swiftformat .
