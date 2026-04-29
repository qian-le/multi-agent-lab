#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$MA_DIR/.." && pwd)"
cd "$ROOT_DIR"

RUN_OUTPUT="$MA_DIR/logs/runs/smoke_test_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$MA_DIR/logs/runs" "$MA_DIR/workspace"

bash "$SCRIPT_DIR/run_workflow.sh" \
  --type modify \
  --goal "create workspace/test.txt with hello multi-agent" \
  --backend shell > "$RUN_OUTPUT" 2>&1
STATUS=$?

FAILURES=0

if [[ "$STATUS" -ne 0 ]]; then
  printf 'smoke_test: run_workflow failed with status %s\n' "$STATUS"
  FAILURES=$((FAILURES + 1))
fi

if [[ ! -f "$MA_DIR/workspace/test.txt" ]]; then
  printf 'smoke_test: missing .multi-agent/workspace/test.txt\n'
  FAILURES=$((FAILURES + 1))
fi

if [[ -f "$MA_DIR/workspace/test.txt" ]]; then
  if ! grep -q 'hello multi-agent' "$MA_DIR/workspace/test.txt"; then
    printf 'smoke_test: file content check failed\n'
    FAILURES=$((FAILURES + 1))
  fi
fi

if ! find "$MA_DIR/logs/runs" -type f -name '*.log' | grep -q .; then
  printf 'smoke_test: no run logs found\n'
  FAILURES=$((FAILURES + 1))
fi

TODAY="$(date +%F)"
if [[ ! -f "$MA_DIR/memory/daily/${TODAY}.md" ]]; then
  printf 'smoke_test: missing daily memory for %s\n' "$TODAY"
  FAILURES=$((FAILURES + 1))
fi

if ! grep -q 'workflow_result: pass' "$RUN_OUTPUT"; then
  printf 'smoke_test: workflow output did not report pass\n'
  FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -eq 0 ]]; then
  printf 'smoke_test: pass\n'
  printf 'run_output: %s\n' "$RUN_OUTPUT"
  exit 0
fi

python3 "$SCRIPT_DIR/write_memory.py" \
  --root "$MA_DIR" \
  --task-id "smoke_test_$(date +%Y%m%d_%H%M%S)" \
  --task-type "modify" \
  --summary "smoke test failed" \
  --agents-used "smoke_test,memory_manager" \
  --files-changed ".multi-agent/workspace/test.txt" \
  --commands-run "bash .multi-agent/scripts/run_workflow.sh --type modify --goal create workspace/test.txt with hello multi-agent --backend shell" \
  --verifier-result "fail" \
  --next-steps "inspect $RUN_OUTPUT"

printf 'smoke_test: fail\n'
printf 'run_output: %s\n' "$RUN_OUTPUT"
exit 1

