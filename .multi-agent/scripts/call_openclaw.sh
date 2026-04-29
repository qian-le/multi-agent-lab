#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$MA_DIR/logs/runs"
MSG_DIR="$MA_DIR/logs/messages"
mkdir -p "$LOG_DIR" "$MSG_DIR"

AGENT=""
GOAL=""
CONTEXT_FILE=""
OUTPUT_FILE="$MSG_DIR/openclaw_adapter_$(date +%Y%m%d_%H%M%S).md"
TASK_ID="openclaw_$(date +%Y%m%d_%H%M%S)"
OPENCLAW_TIMEOUT_SECONDS="${OPENCLAW_TIMEOUT_SECONDS:-90}"

usage() {
  cat <<'EOF'
usage: call_openclaw.sh --agent scout|analyst|guard|executor|verifier|coordinator --goal GOAL [--context-file PATH] --output-file PATH
EOF
}

redact_stream() {
  sed -E 's/((api[_-]?key|token|secret|password|passwd|cookie|credential|private[_-]?key)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1<redacted>/Ig'
}

write_fallback() {
  local reason="$1"
  {
    printf '## OpenClaw Adapter Result\n\n'
    printf -- '- mode: fallback\n'
    printf -- '- agent: %s\n' "${AGENT:-none}"
    printf -- '- goal: %s\n' "$GOAL"
    printf -- '- reason: %s\n' "$reason"
    printf -- '- output_source: local adapter fallback\n'
    printf -- '- next_step: inspect %s and OpenClaw gateway/provider status\n' "$RUN_LOG"
  } > "$OUTPUT_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENT="${2:-}"
      shift 2
      ;;
    --goal)
      GOAL="${2:-}"
      shift 2
      ;;
    --context-file)
      CONTEXT_FILE="${2:-}"
      shift 2
      ;;
    --output-file|--output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --task-id)
      TASK_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$AGENT" || -z "$GOAL" || -z "$OUTPUT_FILE" ]]; then
  usage >&2
  exit 64
fi

case "$AGENT" in
  scout|analyst|guard|executor|verifier|coordinator)
    ;;
  *)
    printf 'unsupported OpenClaw agent: %s\n' "$AGENT" >&2
    exit 64
    ;;
esac

RUN_LOG="$LOG_DIR/${TASK_ID}_${AGENT}_openclaw.log"
HELP_FILE="$MSG_DIR/${TASK_ID}_${AGENT}_openclaw_help.txt"
AGENTS_FILE="$MSG_DIR/${TASK_ID}_${AGENT}_openclaw_agents.json"
PROMPT_FILE="$MSG_DIR/${TASK_ID}_${AGENT}_openclaw_prompt.md"
RAW_OUTPUT="$MSG_DIR/${TASK_ID}_${AGENT}_openclaw_raw.json"

if ! command -v openclaw >/dev/null 2>&1; then
  printf 'openclaw: missing\n' >> "$RUN_LOG"
  write_fallback "openclaw command not found"
  printf '%s\n' "$OUTPUT_FILE"
  exit 0
fi

timeout 20 openclaw agent --help > "$HELP_FILE" 2>> "$RUN_LOG" || true
if ! grep -q -- '--agent <id>' "$HELP_FILE"; then
  printf 'openclaw agent help did not expose --agent <id>\n' >> "$RUN_LOG"
  write_fallback "openclaw agent command does not expose --agent <id>"
  printf '%s\n' "$OUTPUT_FILE"
  exit 0
fi

timeout 20 openclaw agents list --json > "$AGENTS_FILE" 2>> "$RUN_LOG"
LIST_STATUS=$?
if [[ "$LIST_STATUS" -ne 0 || ! -s "$AGENTS_FILE" ]]; then
  printf 'openclaw agents list failed, status=%s\n' "$LIST_STATUS" >> "$RUN_LOG"
  write_fallback "unable to list OpenClaw agents"
  printf '%s\n' "$OUTPUT_FILE"
  exit 0
fi

if ! python3 - "$AGENTS_FILE" "$AGENT" <<'PY' >> "$RUN_LOG" 2>&1
import json
import sys

path, expected = sys.argv[1], sys.argv[2]
agents = json.load(open(path, encoding="utf-8"))
ids = {item.get("id") for item in agents}
if expected not in ids:
    print(f"agent_not_configured: {expected}")
    sys.exit(1)
print(f"agent_configured: {expected}")
PY
then
  write_fallback "OpenClaw agent '$AGENT' is not configured in agents list"
  printf '%s\n' "$OUTPUT_FILE"
  exit 0
fi

{
  printf '# OpenClaw Agent Request\n\n'
  printf 'Agent: %s\n\n' "$AGENT"
  printf 'Goal: %s\n\n' "$GOAL"
  printf 'Safety:\n'
  printf -- '- Stay within the provided context and role.\n'
  printf -- '- Do not delete files.\n'
  printf -- '- Do not use sudo, chmod -R, chown -R, or system path edits.\n'
  printf -- '- Do not print or persist credentials.\n\n'
  printf 'Context:\n'
  if [[ -n "$CONTEXT_FILE" ]]; then
    if [[ -f "$CONTEXT_FILE" ]]; then
      head -c 20000 "$CONTEXT_FILE" | redact_stream
      printf '\n'
    else
      printf 'context file missing: %s\n' "$CONTEXT_FILE"
    fi
  else
    printf 'No context file provided.\n'
  fi
} > "$PROMPT_FILE"

printf 'openclaw: %s\n' "$(command -v openclaw)" >> "$RUN_LOG"
printf 'prompt_file: %s\n' "$PROMPT_FILE" >> "$RUN_LOG"

PROMPT_TEXT="$(cat "$PROMPT_FILE")"
timeout "$OPENCLAW_TIMEOUT_SECONDS" openclaw agent \
  --agent "$AGENT" \
  --message "$PROMPT_TEXT" \
  --json \
  --timeout "$OPENCLAW_TIMEOUT_SECONDS" > "$RAW_OUTPUT" 2>> "$RUN_LOG"
CALL_STATUS=$?

if [[ "$CALL_STATUS" -eq 0 && -s "$RAW_OUTPUT" ]]; then
  {
    printf '## OpenClaw Adapter Result\n\n'
    printf -- '- mode: real_openclaw_agent\n'
    printf -- '- agent: %s\n' "$AGENT"
    printf -- '- goal: %s\n' "$GOAL"
    printf -- '- raw_output: %s\n\n' "$RAW_OUTPUT"
    printf '```json\n'
    head -c 20000 "$RAW_OUTPUT" | redact_stream
    printf '\n```\n'
  } > "$OUTPUT_FILE"
  printf 'openclaw agent call succeeded\n' >> "$RUN_LOG"
  printf '%s\n' "$OUTPUT_FILE"
  exit 0
fi

printf 'openclaw agent call failed, status=%s\n' "$CALL_STATUS" >> "$RUN_LOG"
write_fallback "openclaw agent call failed; see run log for gateway/provider details"
printf '%s\n' "$OUTPUT_FILE"
exit 0
