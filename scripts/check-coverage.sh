#!/usr/bin/env bash
# Fail when line coverage of src/ drops below the configured threshold.
#
# Gas assertions are excluded because coverage instrumentation inflates gas
# usage; they are still enforced by `forge test`.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

THRESHOLD="${COVERAGE_THRESHOLD:-98}"
REPORT="${COVERAGE_REPORT:-lcov.info}"

forge coverage --report lcov --report-file "$REPORT" --ir-minimum \
  --no-match-test "test_gas_" >/dev/null

python3 - "$THRESHOLD" "$REPORT" <<'PY'
import pathlib
import sys

threshold = float(sys.argv[1])
report = pathlib.Path(sys.argv[2])
hit = total = 0
counted = False
for line in report.read_text().splitlines():
    if line.startswith("SF:"):
        counted = line[3:].startswith("src/")
    elif counted and line.startswith("LH:"):
        hit += int(line[3:])
    elif counted and line.startswith("LF:"):
        total += int(line[3:])

if total == 0:
    print(f"no src/ coverage data found in {report}")
    sys.exit(1)

percent = hit / total * 100
print(f"line coverage: {hit}/{total} = {percent:.2f}% (threshold {threshold:.0f}%)")
if percent < threshold:
    print("coverage is below the threshold")
    sys.exit(1)
PY
