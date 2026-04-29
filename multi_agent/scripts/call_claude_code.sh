#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$MA_DIR/logs/runs"
MSG_DIR="$MA_DIR/logs/messages"
mkdir -p "$LOG_DIR" "$MSG_DIR"

PLAN_FILE=""
HERMES_FILE=""
GUARD_FILE=""
OUTPUT_FILE=""
GOAL=""
TASK_ID="claude_$(date +%Y%m%d_%H%M%S)"
DRY_RUN=0
CLAUDE_TIMEOUT_SECONDS="${CLAUDE_TIMEOUT_SECONDS:-180}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_FILE="${2:-}"
      shift 2
      ;;
    --hermes)
      HERMES_FILE="${2:-}"
      shift 2
      ;;
    --guard)
      GUARD_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --goal)
      GOAL="${2:-}"
      shift 2
      ;;
    --task-id)
      TASK_ID="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 64
      ;;
  esac
done

if [[ -z "$PLAN_FILE" || -z "$GUARD_FILE" || -z "$OUTPUT_FILE" ]]; then
  printf 'usage: call_claude_code.sh --plan PLAN --guard GUARD --output OUT [--hermes REVIEW] [--goal GOAL]\n' >&2
  exit 64
fi

RUN_LOG="$LOG_DIR/${TASK_ID}_claude_code.log"
PROMPT_FILE="$MSG_DIR/${TASK_ID}_claude_code_prompt.md"
HELP_FILE="$MSG_DIR/${TASK_ID}_claude_code_help.txt"

guard_section() {
  local start="$1"
  local stop="$2"
  awk -v start="$start" -v stop="$stop" '
    $0 ~ start {capture=1; next}
    stop != "" && $0 ~ stop {capture=0}
    capture {print}
  ' "$GUARD_FILE"
}

{
  printf '# Claude Code Execution Request\n\n'
  printf 'You are the bounded execution backend for OpenClaw Multi-Agent OS.\n\n'
  printf '## User Goal\n\n%s\n\n' "$GOAL"
  printf '## Analyst Plan\n\n'
  cat "$PLAN_FILE"
  printf '\n\n## Hermes Review\n\n'
  if [[ -n "$HERMES_FILE" && -f "$HERMES_FILE" ]]; then
    cat "$HERMES_FILE"
  else
    printf 'No Hermes review was provided.\n'
  fi
  printf '\n\n## Guard Decision And Allowed Scope\n\n'
  cat "$GUARD_FILE"
  printf '\n\n## Guard Allowed Scope Only\n\n'
  guard_section '^allowed_scope:' '^forbidden_actions:'
  printf '\n\n## Guard Forbidden Actions Only\n\n'
  guard_section '^forbidden_actions:' ''
  printf '\n\n## Verifier Validation Method\n\n'
  awk '/^verify:/{capture=1; next} capture {print}' "$PLAN_FILE"
  printf '\n\n## Hard Boundaries\n\n'
  printf -- '- Only execute the Guard allowed scope.\n'
  printf -- '- Do not delete files.\n'
  printf -- '- Do not use sudo, chmod -R, chown -R, or system path edits.\n'
  printf -- '- Do not print, copy, or persist credentials.\n'
  printf -- '- Keep changes minimal and leave verification to Verifier.\n'
  printf '\n## Required Executor Output\n\n'
  printf -- '- 执行目标:\n- 执行步骤:\n- 修改文件:\n- 运行命令:\n- 成功项:\n- 失败项:\n- 需要 Verifier 检查的内容:\n'
} > "$PROMPT_FILE"

printf 'Claude prompt: %s\n' "$PROMPT_FILE" >> "$RUN_LOG"

if [[ "$DRY_RUN" -eq 1 ]]; then
  cat > "$OUTPUT_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤: dry-run only
- 修改文件: none
- 运行命令: none
- 成功项: prompt generated for Claude Code
- 失败项: none
- 需要 Verifier 检查的内容: none
EOF
  printf 'dry-run complete\n' >> "$RUN_LOG"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  cat > "$OUTPUT_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤: Claude Code backend requested
- 修改文件: none
- 运行命令: claude
- 成功项: none
- 失败项: claude command not found
- 需要 Verifier 检查的内容: Claude Code was not executed
EOF
  printf 'claude: missing\n' >> "$RUN_LOG"
  exit 20
fi

timeout 20 claude --help > "$HELP_FILE" 2>> "$RUN_LOG" || true
if ! grep -Eq -- '-p, --print|--print' "$HELP_FILE"; then
  cat > "$OUTPUT_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤: Claude Code backend capability check
- 修改文件: none
- 运行命令: claude --help
- 成功项: none
- 失败项: claude help did not expose non-interactive --print mode
- 需要 Verifier 检查的内容: inspect $RUN_LOG
EOF
  printf 'claude: --print not available according to help\n' >> "$RUN_LOG"
  exit 20
fi

if timeout "$CLAUDE_TIMEOUT_SECONDS" claude --print \
  --no-session-persistence \
  --permission-mode acceptEdits \
  --tools "Read,Write,Edit" \
  < "$PROMPT_FILE" > "$OUTPUT_FILE" 2>> "$RUN_LOG"; then
  if [[ -s "$OUTPUT_FILE" ]]; then
    printf 'claude execution complete via --print\n' >> "$RUN_LOG"
    exit 0
  fi
fi
CLAUDE_STATUS=$?

cat > "$OUTPUT_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤: Claude Code backend attempted
- 修改文件: unknown
- 运行命令: claude --print --no-session-persistence --permission-mode acceptEdits --tools Read,Write,Edit
- 成功项: none
- 失败项: Claude Code command returned no usable output or timed out with status $CLAUDE_STATUS
- 需要 Verifier 检查的内容: inspect $RUN_LOG
EOF
exit 21
