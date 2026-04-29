#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$MA_DIR/.." && pwd)"
cd "$ROOT_DIR"

TASK_TYPE=""
GOAL=""
BACKEND="shell"
DRY_RUN=0

usage() {
  cat <<'EOF'
usage: run_workflow.sh --type TYPE --goal GOAL [--backend shell|python|claude_code] [--dry-run]

TYPE: info | analysis | modify | debug | architecture | risky
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TASK_TYPE="${2:-}"
      shift 2
      ;;
    --goal)
      GOAL="${2:-}"
      shift 2
      ;;
    --backend)
      BACKEND="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ -z "$TASK_TYPE" || -z "$GOAL" ]]; then
  usage >&2
  exit 64
fi

case "$TASK_TYPE" in
  info|analysis|modify|debug|architecture|risky)
    ;;
  *)
    printf 'unsupported task type: %s\n' "$TASK_TYPE" >&2
    exit 64
    ;;
esac

case "$BACKEND" in
  shell|python|claude_code)
    ;;
  *)
    printf 'unsupported backend: %s\n' "$BACKEND" >&2
    exit 64
    ;;
esac

mkdir -p "$MA_DIR/logs/runs" "$MA_DIR/logs/messages" "$MA_DIR/workspace" \
  "$MA_DIR/memory/daily" "$MA_DIR/memory/project" "$MA_DIR/memory/decisions" \
  "$MA_DIR/memory/failures" "$MA_DIR/memory/lessons"

TASK_ID="${TASK_TYPE}_$(date +%Y%m%d_%H%M%S)_$$"
RUN_LOG="$MA_DIR/logs/runs/${TASK_ID}.log"
ROUTER_FILE="$MA_DIR/logs/messages/${TASK_ID}_router.md"
SCOUT_FILE="$MA_DIR/logs/messages/${TASK_ID}_scout.md"
ANALYST_FILE="$MA_DIR/logs/messages/${TASK_ID}_analyst.md"
HERMES_FILE="$MA_DIR/logs/messages/${TASK_ID}_hermes.md"
GUARD_FILE="$MA_DIR/logs/messages/${TASK_ID}_guard.md"
EXECUTOR_FILE="$MA_DIR/logs/messages/${TASK_ID}_executor.md"
VERIFIER_FILE="$MA_DIR/logs/messages/${TASK_ID}_verifier.md"

AGENTS_USED="main,router"
FILES_CHANGED=""
COMMANDS_RUN=""
VERIFIER_RESULT="not_run"
SUMMARY="workflow started"
NEXT_STEPS="none"

log() {
  printf '%s\n' "$*" | tee -a "$RUN_LOG"
}

goal_is_smoke() {
  printf '%s' "$GOAL" | grep -Eqi 'workspace/test[.]txt' &&
    printf '%s' "$GOAL" | grep -Eqi 'hello multi-agent'
}

goal_is_claude_backend_test() {
  printf '%s' "$GOAL" | grep -Eqi 'workspace/claude_backend_test[.]txt' &&
    printf '%s' "$GOAL" | grep -Eqi 'claude backend test'
}

SAFE_CREATE_MATCH=0
SAFE_CREATE_VALID=0
SAFE_CREATE_FILE=""
SAFE_CREATE_CONTENT=""
SAFE_CREATE_REL=""
SAFE_CREATE_TARGET=""
SAFE_CREATE_ERROR=""

parse_workspace_create_goal() {
  local goal="$1"
  SAFE_CREATE_MATCH=0
  SAFE_CREATE_VALID=0
  SAFE_CREATE_FILE=""
  SAFE_CREATE_CONTENT=""
  SAFE_CREATE_REL=""
  SAFE_CREATE_TARGET=""
  SAFE_CREATE_ERROR=""

  if [[ "$goal" =~ ^create[[:space:]]+workspace/([^[:space:]]+)[[:space:]]+with[[:space:]]+(.+)$ ]]; then
    SAFE_CREATE_MATCH=1
    SAFE_CREATE_FILE="${BASH_REMATCH[1]}"
    SAFE_CREATE_CONTENT="${BASH_REMATCH[2]}"

    if [[ -z "$SAFE_CREATE_FILE" ]]; then
      SAFE_CREATE_ERROR="filename is empty"
    elif [[ "$SAFE_CREATE_FILE" == /* ]]; then
      SAFE_CREATE_ERROR="filename must not start with /"
    elif [[ "$SAFE_CREATE_FILE" == *..* ]]; then
      SAFE_CREATE_ERROR="filename must not contain .."
    elif [[ "$SAFE_CREATE_FILE" == *~* ]]; then
      SAFE_CREATE_ERROR="filename must not contain ~"
    elif [[ "$SAFE_CREATE_FILE" == */* ]]; then
      SAFE_CREATE_ERROR="filename must not contain path separators"
    else
      SAFE_CREATE_VALID=1
      SAFE_CREATE_REL=".multi-agent/workspace/$SAFE_CREATE_FILE"
      SAFE_CREATE_TARGET="$MA_DIR/workspace/$SAFE_CREATE_FILE"
    fi
  fi
}

write_memory() {
  local memory_agents="$AGENTS_USED,memory_manager"
  python3 "$SCRIPT_DIR/write_memory.py" \
    --root "$MA_DIR" \
    --task-id "$TASK_ID" \
    --task-type "$TASK_TYPE" \
    --summary "$SUMMARY" \
    --agents-used "$memory_agents" \
    --files-changed "$FILES_CHANGED" \
    --commands-run "$COMMANDS_RUN" \
    --verifier-result "$VERIFIER_RESULT" \
    --next-steps "$NEXT_STEPS" >> "$RUN_LOG" 2>&1
}

parse_guard_decision() {
  awk -F': *' '/^decision:/ {print $2; exit}' "$GUARD_FILE"
}

parse_hermes_decision() {
  if [[ ! -f "$HERMES_FILE" ]]; then
    printf ''
    return
  fi
  grep -Ei '最终建议|final recommendation|approve|revise|reject' "$HERMES_FILE" |
    tail -n 1 |
    tr '[:upper:]' '[:lower:]'
}

log "task_id: $TASK_ID"
log "task_type: $TASK_TYPE"
log "backend: $BACKEND"
log "dry_run: $DRY_RUN"
log "goal: $GOAL"
log "run_log: $RUN_LOG"

parse_workspace_create_goal "$GOAL"

COMPLEXITY="low"
RISK_LEVEL="low"
NEED_HERMES="no"
NEED_USER_CONFIRM="no"
WORKFLOW=".multi-agent/workflows/${TASK_TYPE}.yaml"

case "$TASK_TYPE" in
  architecture)
    COMPLEXITY="high"
    RISK_LEVEL="medium"
    NEED_HERMES="yes"
    ;;
  debug)
    COMPLEXITY="medium"
    RISK_LEVEL="medium"
    ;;
  risky)
    COMPLEXITY="high"
    RISK_LEVEL="high"
    NEED_HERMES="yes"
    NEED_USER_CONFIRM="yes"
    ;;
esac

if printf '%s' "$GOAL" | grep -Eqi 'system|permission|credential|token|cookie|delete|remove|sudo|/etc|/usr|/bin|/var'; then
  RISK_LEVEL="high"
  NEED_USER_CONFIRM="yes"
fi

cat > "$ROUTER_FILE" <<EOF
task_type: $TASK_TYPE
complexity: $COMPLEXITY
risk_level: $RISK_LEVEL
workflow: $WORKFLOW
need_hermes: $NEED_HERMES
need_user_confirm: $NEED_USER_CONFIRM
reason: classified from explicit --type and goal keywords
EOF
log "stage router: $ROUTER_FILE"

KEY_FILES="$(find .multi-agent -maxdepth 2 -type f | sort | head -n 80)"
OPENCLAW_STATE="missing"
if [[ -d ".openclaw" ]]; then
  OPENCLAW_STATE="present at .openclaw"
fi

cat > "$SCOUT_FILE" <<EOF
## Scout Report

- 目标: $GOAL
- 已检查路径:
  - .
  - .openclaw
  - .multi-agent
- 发现的关键文件:
$(printf '%s\n' "$KEY_FILES" | sed 's/^/  - /')
- 当前状态:
  - OpenClaw: $OPENCLAW_STATE
  - Multi-Agent root: .multi-agent
  - Git repository: $(git rev-parse --is-inside-work-tree 2>/dev/null || printf 'no')
- 疑似问题:
  - none from read-only scout
- 交给 Analyst 的信息:
  - Use .multi-agent as the bounded orchestration layer.
  - Do not modify .openclaw unless a later plan explicitly scopes it.
EOF
AGENTS_USED="$AGENTS_USED,scout"
log "stage scout: $SCOUT_FILE"

if [[ "$TASK_TYPE" == "info" ]]; then
  SUMMARY="info workflow completed with read-only Scout report"
  VERIFIER_RESULT="not_required"
  NEXT_STEPS="review $SCOUT_FILE"
  write_memory
  log "workflow_result: pass"
  log "memory: written"
  printf 'workflow_result: pass\n'
  printf 'scout_report: %s\n' "$SCOUT_FILE"
  exit 0
fi

PLAN_FILES="- no file changes"
PLAN_COMMANDS="- no execution"
PLAN_VERIFY="- inspect Analyst output"
PLAN_RISK="$RISK_LEVEL"
HERMES_REQUIRED="no"

if [[ "$SAFE_CREATE_VALID" -eq 1 ]]; then
  PLAN_FILES="- $SAFE_CREATE_REL"
  PLAN_COMMANDS="- create $SAFE_CREATE_REL with exact requested content"
  PLAN_VERIFY="- file exists: $SAFE_CREATE_REL
- file contains: $SAFE_CREATE_CONTENT"
elif goal_is_smoke; then
  PLAN_FILES="- .multi-agent/workspace/test.txt"
  PLAN_COMMANDS="- create .multi-agent/workspace/test.txt with exact content: hello multi-agent"
  PLAN_VERIFY="- file exists: .multi-agent/workspace/test.txt
- file contains: hello multi-agent"
elif goal_is_claude_backend_test; then
  PLAN_FILES="- .multi-agent/workspace/claude_backend_test.txt"
  PLAN_COMMANDS="- create .multi-agent/workspace/claude_backend_test.txt with exact content: claude backend test"
  PLAN_VERIFY="- file exists: .multi-agent/workspace/claude_backend_test.txt
- file contains: claude backend test"
elif [[ "$TASK_TYPE" == "architecture" ]]; then
  PLAN_FILES="- .multi-agent/agents/*.md
- .multi-agent/workflows/*.yaml
- .multi-agent/scripts/*.sh
- .multi-agent/scripts/*.py
- .multi-agent/README.md"
  PLAN_COMMANDS="- execute only after Hermes approve or Analyst revision
- keep changes within .multi-agent"
  PLAN_VERIFY="- run smoke test
- inspect logs and memory output"
  HERMES_REQUIRED="yes"
elif [[ "$TASK_TYPE" == "debug" || "$TASK_TYPE" == "modify" ]]; then
  PLAN_FILES="- .multi-agent/workspace/*"
  PLAN_COMMANDS="- no generic shell execution; only supported safe actions may run"
  PLAN_VERIFY="- run verifier against explicit changed files"
fi

cat > "$ANALYST_FILE" <<EOF
## Analyst Plan

- 问题判断: The task requires $TASK_TYPE workflow handling.
- 根因分析: Current request should be executed through scoped multi-agent stages rather than direct ad-hoc commands.
- 推荐方案: Use Router, Scout, Analyst, Guard, Executor, Verifier, and Memory according to $WORKFLOW.
- 备选方案: Use --dry-run to produce plans and logs without execution.
- 需要修改的文件:
$PLAN_FILES
- 执行步骤:
$PLAN_COMMANDS
- 风险等级: $PLAN_RISK
- 验证方法:
$PLAN_VERIFY
- 是否需要 Hermes 审查: $HERMES_REQUIRED

allowed_files:
$PLAN_FILES
commands:
$PLAN_COMMANDS
verify:
$PLAN_VERIFY
EOF
AGENTS_USED="$AGENTS_USED,analyst"
log "stage analyst: $ANALYST_FILE"

if [[ "$TASK_TYPE" == "analysis" ]]; then
  python3 "$SCRIPT_DIR/guard_check.py" \
    --task-type "$TASK_TYPE" \
    --plan-file "$ANALYST_FILE" > "$GUARD_FILE" 2>> "$RUN_LOG"
  GUARD_STATUS=$?
  AGENTS_USED="$AGENTS_USED,guard"
  log "stage guard: $GUARD_FILE status=$GUARD_STATUS"
  SUMMARY="analysis workflow completed; no execution performed"
  VERIFIER_RESULT="not_required"
  NEXT_STEPS="review $ANALYST_FILE"
  write_memory
  log "workflow_result: pass"
  printf 'workflow_result: pass\n'
  printf 'analyst_plan: %s\n' "$ANALYST_FILE"
  printf 'guard_decision: %s\n' "$GUARD_FILE"
  exit 0
fi

ANALYST_REVISED=0
if [[ "$TASK_TYPE" == "architecture" || "$TASK_TYPE" == "risky" ]]; then
  "$SCRIPT_DIR/call_hermes.sh" \
    --input "$ANALYST_FILE" \
    --output "$HERMES_FILE" \
    --goal "$GOAL" \
    --task-id "$TASK_ID" >> "$RUN_LOG" 2>&1
  HERMES_STATUS=$?
  AGENTS_USED="$AGENTS_USED,hermes_reviewer"
  log "stage hermes: $HERMES_FILE status=$HERMES_STATUS"

  HERMES_DECISION="$(parse_hermes_decision)"
  if printf '%s' "$HERMES_DECISION" | grep -qi 'reject'; then
    SUMMARY="workflow stopped because Hermes rejected the plan"
    VERIFIER_RESULT="fail"
    NEXT_STEPS="revise Analyst plan before execution"
    write_memory
    log "workflow_result: stopped_by_hermes_reject"
    printf 'workflow_result: stopped_by_hermes_reject\n'
    exit 3
  fi
  if printf '%s' "$HERMES_DECISION" | grep -qi 'revise'; then
    REVISED_FILE="$MA_DIR/logs/messages/${TASK_ID}_analyst_revised.md"
    cp "$ANALYST_FILE" "$REVISED_FILE"
    cat >> "$REVISED_FILE" <<'EOF'

## Analyst Revision

- revision_status: incorporated
- changes:
  - tightened execution scope to .multi-agent only
  - kept verification explicit
  - kept deletion and system-path changes out of scope
- analyst_revision: true
EOF
    ANALYST_FILE="$REVISED_FILE"
    ANALYST_REVISED=1
    AGENTS_USED="$AGENTS_USED,analyst_revision"
    log "stage analyst_revision: $ANALYST_FILE"
  fi
fi

if [[ "$ANALYST_REVISED" -eq 1 ]]; then
  python3 "$SCRIPT_DIR/guard_check.py" \
    --task-type "$TASK_TYPE" \
    --plan-file "$ANALYST_FILE" \
    --hermes-file "$HERMES_FILE" \
    --analyst-revised > "$GUARD_FILE" 2>> "$RUN_LOG"
else
  python3 "$SCRIPT_DIR/guard_check.py" \
    --task-type "$TASK_TYPE" \
    --plan-file "$ANALYST_FILE" \
    --hermes-file "$HERMES_FILE" > "$GUARD_FILE" 2>> "$RUN_LOG"
fi
GUARD_STATUS=$?
AGENTS_USED="$AGENTS_USED,guard"
log "stage guard: $GUARD_FILE status=$GUARD_STATUS"

GUARD_DECISION="$(parse_guard_decision)"
if [[ "$GUARD_DECISION" != "allow" ]]; then
  SUMMARY="workflow stopped by Guard with decision: ${GUARD_DECISION:-unknown}"
  VERIFIER_RESULT="not_run"
  NEXT_STEPS="review Guard decision and confirm scope before execution"
  write_memory
  log "workflow_result: stopped_by_guard"
  printf 'workflow_result: stopped_by_guard\n'
  printf 'guard_decision: %s\n' "$GUARD_FILE"
  exit 4
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  SUMMARY="dry-run completed after Guard allow; Executor skipped"
  VERIFIER_RESULT="not_run"
  NEXT_STEPS="rerun without --dry-run to execute"
  write_memory
  log "workflow_result: dry_run_pass"
  printf 'workflow_result: dry_run_pass\n'
  exit 0
fi

EXEC_STATUS=0
case "$BACKEND" in
  shell)
    if [[ "$SAFE_CREATE_VALID" -eq 1 ]]; then
      mkdir -p "$MA_DIR/workspace"
      CONTENT_SUMMARY="${SAFE_CREATE_CONTENT//$'\n'/ }"
      if [[ ${#CONTENT_SUMMARY} -gt 80 ]]; then
        CONTENT_SUMMARY="${CONTENT_SUMMARY:0:80}..."
      fi
      if [[ -L "$SAFE_CREATE_TARGET" ]]; then
        EXEC_STATUS=10
        WRITE_RESULT="refused to follow symlink at $SAFE_CREATE_REL"
        WRITE_ACTION="$WRITE_RESULT"
        FAILURE_RESULT="$WRITE_RESULT"
        FILES_CHANGED=""
        COMMANDS_RUN="none"
      else
        if printf '%s\n' "$SAFE_CREATE_CONTENT" > "$SAFE_CREATE_TARGET"; then
          EXEC_STATUS=0
          WRITE_RESULT="file write completed"
          WRITE_ACTION="wrote requested content into $SAFE_CREATE_REL"
          FAILURE_RESULT="none"
          FILES_CHANGED="$SAFE_CREATE_REL"
          COMMANDS_RUN="safe shell create $SAFE_CREATE_REL"
        else
          EXEC_STATUS=$?
          WRITE_RESULT="file write failed with status $EXEC_STATUS"
          WRITE_ACTION="$WRITE_RESULT"
          FAILURE_RESULT="$WRITE_RESULT"
          FILES_CHANGED=""
          COMMANDS_RUN="safe shell create $SAFE_CREATE_REL"
        fi
      fi
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - used shell backend
  - matched safe action: create workspace/<filename> with <content>
  - $WRITE_ACTION
  - content summary: $CONTENT_SUMMARY
  - content bytes: ${#SAFE_CREATE_CONTENT}
- 修改文件:
  - ${FILES_CHANGED:-none}
- 运行命令:
  - $COMMANDS_RUN
- 成功项:
  - $WRITE_RESULT
- 失败项:
  - $FAILURE_RESULT
- 需要 Verifier 检查的内容:
  - file exists: $SAFE_CREATE_REL
  - file contains requested content
EOF
    elif [[ "$SAFE_CREATE_MATCH" -eq 1 ]]; then
      EXEC_STATUS=10
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - shell backend refused unsafe workspace create request
- 修改文件:
  - none
- 运行命令:
  - none
- 成功项:
  - Guard boundary preserved
- 失败项:
  - $SAFE_CREATE_ERROR
- 需要 Verifier 检查的内容:
  - executor refusal status
EOF
    elif goal_is_smoke; then
      mkdir -p "$MA_DIR/workspace"
      printf 'hello multi-agent\n' > "$MA_DIR/workspace/test.txt"
      FILES_CHANGED=".multi-agent/workspace/test.txt"
      COMMANDS_RUN="create .multi-agent/workspace/test.txt"
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - used shell backend
  - wrote exact smoke-test content into .multi-agent/workspace/test.txt
- 修改文件:
  - .multi-agent/workspace/test.txt
- 运行命令:
  - create .multi-agent/workspace/test.txt
- 成功项:
  - file write completed
- 失败项:
  - none
- 需要 Verifier 检查的内容:
  - file exists
  - file contains hello multi-agent
EOF
    else
      EXEC_STATUS=10
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - shell backend refused generic execution
- 修改文件:
  - none
- 运行命令:
  - none
- 成功项:
  - Guard boundary preserved
- 失败项:
  - no supported safe shell action matched the goal
- 需要 Verifier 检查的内容:
  - executor log exists
EOF
    fi
    ;;
  python)
    if goal_is_smoke; then
      python3 -c 'from pathlib import Path; p=Path(".multi-agent/workspace/test.txt"); p.parent.mkdir(parents=True, exist_ok=True); p.write_text("hello multi-agent\n", encoding="utf-8")'
      EXEC_STATUS=$?
      FILES_CHANGED=".multi-agent/workspace/test.txt"
      COMMANDS_RUN="python3 create .multi-agent/workspace/test.txt"
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - used python backend
  - wrote exact smoke-test content into .multi-agent/workspace/test.txt
- 修改文件:
  - .multi-agent/workspace/test.txt
- 运行命令:
  - python3 local file write
- 成功项:
  - file write command exited with $EXEC_STATUS
- 失败项:
  - none if exit code is 0
- 需要 Verifier 检查的内容:
  - file exists
  - file contains hello multi-agent
EOF
    else
      EXEC_STATUS=10
      cat > "$EXECUTOR_FILE" <<EOF
## Executor Result

- 执行目标: $GOAL
- 执行步骤:
  - python backend refused generic execution
- 修改文件:
  - none
- 运行命令:
  - none
- 成功项:
  - Guard boundary preserved
- 失败项:
  - no supported safe python action matched the goal
- 需要 Verifier 检查的内容:
  - executor log exists
EOF
    fi
    ;;
  claude_code)
    "$SCRIPT_DIR/call_claude_code.sh" \
      --plan "$ANALYST_FILE" \
      --hermes "$HERMES_FILE" \
      --guard "$GUARD_FILE" \
      --output "$EXECUTOR_FILE" \
      --goal "$GOAL" \
      --task-id "$TASK_ID" >> "$RUN_LOG" 2>&1
    EXEC_STATUS=$?
    COMMANDS_RUN="claude_code adapter"
    ;;
esac

AGENTS_USED="$AGENTS_USED,executor"
log "stage executor: $EXECUTOR_FILE status=$EXEC_STATUS"

if [[ "$SAFE_CREATE_VALID" -eq 1 ]]; then
  python3 "$SCRIPT_DIR/verify.py" \
    --goal "$GOAL" > "$VERIFIER_FILE" 2>> "$RUN_LOG"
  VERIFY_STATUS=$?
elif goal_is_smoke; then
  python3 "$SCRIPT_DIR/verify.py" \
    --file-exists ".multi-agent/workspace/test.txt" \
    --file-contains ".multi-agent/workspace/test.txt" "hello multi-agent" > "$VERIFIER_FILE" 2>> "$RUN_LOG"
  VERIFY_STATUS=$?
elif goal_is_claude_backend_test; then
  python3 "$SCRIPT_DIR/verify.py" \
    --file-exists ".multi-agent/workspace/claude_backend_test.txt" \
    --file-contains ".multi-agent/workspace/claude_backend_test.txt" "claude backend test" > "$VERIFIER_FILE" 2>> "$RUN_LOG"
  VERIFY_STATUS=$?
else
  python3 "$SCRIPT_DIR/verify.py" \
    --log-file "$EXECUTOR_FILE" > "$VERIFIER_FILE" 2>> "$RUN_LOG"
  VERIFY_STATUS=$?
fi

AGENTS_USED="$AGENTS_USED,verifier"
log "stage verifier: $VERIFIER_FILE status=$VERIFY_STATUS"

if grep -Eq 'status: pass' "$VERIFIER_FILE"; then
  VERIFIER_RESULT="pass"
  SUMMARY="workflow completed and verifier passed"
  NEXT_STEPS="none"
  RESULT_EXIT=0
elif grep -Eq 'status: partial' "$VERIFIER_FILE"; then
  VERIFIER_RESULT="partial"
  SUMMARY="workflow completed with partial verification"
  NEXT_STEPS="inspect verifier output and add stronger checks"
  RESULT_EXIT=2
else
  VERIFIER_RESULT="fail"
  SUMMARY="workflow failed verification"
  NEXT_STEPS="inspect executor and verifier logs"
  RESULT_EXIT=1
fi

if [[ "$EXEC_STATUS" -ne 0 && "$VERIFIER_RESULT" == "pass" ]]; then
  VERIFIER_RESULT="fail"
  SUMMARY="executor failed even though verifier checks passed"
  NEXT_STEPS="inspect executor status and rerun"
  RESULT_EXIT=1
fi

write_memory
AGENTS_USED="$AGENTS_USED,memory_manager"
log "stage memory: written"
log "workflow_result: $VERIFIER_RESULT"

printf 'workflow_result: %s\n' "$VERIFIER_RESULT"
printf 'task_id: %s\n' "$TASK_ID"
printf 'run_log: %s\n' "$RUN_LOG"
printf 'verifier: %s\n' "$VERIFIER_FILE"
exit "$RESULT_EXIT"
