#!/usr/bin/env bash
# Public smoke test — checks file structure and script syntax
# No runtime dependencies (openclaw/hermes/claude not required)
set -euo pipefail

echo "=== Public Smoke Test ==="
echo

# Check root files
echo "[1] Checking root files..."
for f in README.md LICENSE CONTRIBUTING.md ROADMAP.md .gitignore; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check core skeleton files
echo
echo "[2] Checking .multi-agent core files..."
for f in \
  .multi-agent/README.md \
  .multi-agent/config.yaml \
  .multi-agent/agents/main.md \
  .multi-agent/agents/router.md \
  .multi-agent/agents/scout.md \
  .multi-agent/agents/analyst.md \
  .multi-agent/agents/guard.md \
  .multi-agent/agents/executor.md \
  .multi-agent/agents/verifier.md \
  .multi-agent/workflows/info.yaml \
  .multi-agent/workflows/modify.yaml \
  .multi-agent/scripts/run_workflow.sh \
  .multi-agent/scripts/verify.py; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check docs
echo
echo "[3] Checking docs..."
for f in docs/architecture.md docs/workflows.md docs/security.md; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Syntax check bash scripts
echo
echo "[4] Checking bash script syntax..."
shopt -s nullglob
for f in .multi-agent/scripts/*.sh tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    echo "  OK: $f"
  else
    echo "  SYNTAX ERROR: $f"
    exit 1
  fi
done
shopt -u nullglob

# Syntax check python scripts
echo
echo "[5] Checking Python script syntax..."
shopt -s nullglob
for f in .multi-agent/scripts/*.py tests/*.py; do
  if python3 -m py_compile "$f" 2>/dev/null; then
    echo "  OK: $f"
  else
    echo "  SYNTAX ERROR: $f"
    exit 1
  fi
done
shopt -u nullglob

# Check forbidden directories are not tracked by git (runtime artifacts only)
echo
echo "[6] Checking forbidden directories not tracked by git..."
# These directories should exist (runtime) but must not be git-tracked
for dir in \
  .multi-agent/logs \
  .multi-agent/memory/daily \
  .multi-agent/memory/failures \
  .multi-agent/memory/decisions; do
  tracked=$(git ls-files --error-unmatch "$dir" 2>/dev/null && echo YES || echo NO)
  if [[ "$tracked" == "YES" ]]; then
    echo "  TRACKED (should not be): $dir"
    exit 1
  else
    echo "  OK (not tracked): $dir"
  fi
done

# Check gitignore covers critical items
echo
echo "[7] Checking .gitignore coverage..."
required_patterns=(
  ".multi-agent/logs/"
  ".multi-agent/memory/daily/"
  ".multi-agent/memory/failures/"
  ".multi-agent/memory/decisions/"
  ".multi-agent/workspace/"
  ".env"
  ".ssh/"
  ".openclaw/"
)
for pat in "${required_patterns[@]}"; do
  if grep -q "$pat" .gitignore 2>/dev/null; then
    echo "  OK: $pat in .gitignore"
  else
    echo "  MISSING in .gitignore: $pat"
    exit 1
  fi
done

echo
echo "=== public smoke test passed ==="
