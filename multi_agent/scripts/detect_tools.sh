#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$MA_DIR/logs/runs"
mkdir -p "$LOG_DIR"

REPORT="$LOG_DIR/tools_report_$(date +%Y%m%d_%H%M%S).log"

tool_version() {
  local cmd="$1"
  if command -v timeout >/dev/null 2>&1; then
    timeout 10 "$cmd" --version 2>&1 | head -n 1
  else
    "$cmd" --version 2>&1 | head -n 1
  fi
}

check_tool() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    local path
    local version
    path="$(command -v "$cmd")"
    version="$(tool_version "$cmd" || true)"
    printf '%s: found\n' "$name"
    printf '  command: %s\n' "$cmd"
    printf '  path: %s\n' "$path"
    printf '  version: %s\n' "${version:-unknown}"
  else
    printf '%s: missing\n' "$name"
    printf '  command: %s\n' "$cmd"
    printf '  version: unavailable\n'
  fi
}

{
  printf 'tools_report\n'
  printf 'generated_at: %s\n' "$(date -Iseconds)"
  printf 'multi_agent_root: %s\n\n' "$MA_DIR"
  check_tool "openclaw" "openclaw"
  printf '\n'
  check_tool "hermes" "hermes"
  printf '\n'
  check_tool "claude" "claude"
  printf '\n'
  check_tool "python3" "python3"
  printf '\n'
  check_tool "git" "git"
  printf '\n'
  check_tool "rg" "rg"
  printf '\nreport_file: %s\n' "$REPORT"
} | tee "$REPORT"

