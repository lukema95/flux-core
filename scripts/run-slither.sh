#!/usr/bin/env bash
# Run Slither with the repository configuration.
#
# Install: python3 -m venv .venv && .venv/bin/pip install slither-analyzer
# Then:    SLITHER_BIN=.venv/bin/slither bash scripts/run-slither.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SLITHER_BIN="${SLITHER_BIN:-slither}"

if ! command -v "$SLITHER_BIN" >/dev/null 2>&1; then
  echo "slither not found; install slither-analyzer or set SLITHER_BIN" >&2
  exit 1
fi

"$SLITHER_BIN" . --config-file slither.config.json --fail-medium
