#!/usr/bin/env bash
#
# The definition of done. Verifies both packages in dependency order:
#   1. abc_accounting (repo root) — the released package: analyze + full test suite.
#   2. contracts_for_abc_accounting            — the dev-only conformance kit: the SAME acceptance
#      suite, green against the ReferenceLedger AND the real AccountLedger, plus
#      the version guard. The red stub spec (tagged `pending`) is run explicitly so
#      a regression that makes it accidentally pass is caught.
#
# Usage:  ./tool/verify.sh
# Exits non-zero on the first failure.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "abc_accounting — pub get"
dart pub get

step "abc_accounting — analyze"
dart analyze

step "abc_accounting — test"
dart test

step "contracts_for_abc_accounting — pub get"
(cd contracts && dart pub get)

step "contracts_for_abc_accounting — analyze"
(cd contracts && dart analyze)

step "contracts_for_abc_accounting — test (suite green vs ReferenceLedger and AccountLedger; version guard)"
(cd contracts && dart test)

step "contracts_for_abc_accounting — the pending stub spec must still be RED"
# Invert the exit code: the run is expected to fail (UnimplementedError).
if (cd contracts && dart test --run-skipped -t pending) >/dev/null 2>&1; then
  echo "ERROR: the pending stub conformance run PASSED — it must be red." >&2
  exit 1
fi
echo "ok — the stub spec is red, as required."

printf '\n\033[1;32mAll checks passed.\033[0m\n'
