#!/usr/bin/env bash
# Public smoke test — checks file structure and script syntax
# No runtime dependencies (openclaw/hermes/claude not required)
set -euo pipefail

echo "=== Public Smoke Test ==="
echo

# Check root files
echo "[1] Checking root files..."
for f in README.md LICENSE .gitignore; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check core skeleton files
echo
echo "[2] Checking multi_agent/ core files..."
for f in \
  multi_agent/README.md \
  multi_agent/config.yaml \
  multi_agent/agents/main.md \
  multi_agent/agents/router.md \
  multi_agent/agents/scout.md \
  multi_agent/agents/analyst.md \
  multi_agent/agents/guard.md \
  multi_agent/agents/executor.md \
  multi_agent/agents/verifier.md \
  multi_agent/agents/memory_manager.md \
  multi_agent/workflows/info.yaml \
  multi_agent/workflows/modify.yaml \
  multi_agent/workflows/analysis.yaml \
  multi_agent/workflows/debug.yaml \
  multi_agent/workflows/architecture.yaml \
  multi_agent/workflows/risky.yaml \
  multi_agent/scripts/run_workflow.sh \
  multi_agent/scripts/verify.py \
  multi_agent/scripts/guard_check.py \
  multi_agent/adapters/openclaw_adapter.md \
  multi_agent/adapters/hermes_adapter.md \
  multi_agent/adapters/claude_code_adapter.md \
  multi_agent/adapters/shell_adapter.md \
  multi_agent/memory/templates/daily.md \
  multi_agent/memory/templates/decision.md \
  multi_agent/memory/templates/failure.md \
  multi_agent/memory/templates/lesson.md; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check examples
echo
echo "[3] Checking examples..."
for f in \
  examples/info-workflow.md \
  examples/modify-workflow.md \
  examples/architecture-review.md; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check docs
echo
echo "[4] Checking docs..."
for f in \
  docs/architecture.md \
  docs/workflows.md \
  docs/security.md \
  docs/model-integration-roadmap.md; do
  if [[ -f "$f" ]]; then
    echo "  OK: $f"
  else
    echo "  MISSING: $f"
    exit 1
  fi
done

# Check CI
echo
echo "[5] Checking GitHub Actions CI..."
if [[ -f ".github/workflows/public-smoke.yml" ]]; then
  echo "  OK: .github/workflows/public-smoke.yml"
else
  echo "  MISSING: .github/workflows/public-smoke.yml"
  exit 1
fi

# Syntax check bash scripts
echo
echo "[6] Checking bash script syntax..."
shopt -s nullglob
for f in multi_agent/scripts/*.sh tests/*.sh; do
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
echo "[7] Checking Python script syntax..."
shopt -s nullglob
for f in multi_agent/scripts/*.py tests/*.py; do
  if python3 -m py_compile "$f" 2>/dev/null; then
    echo "  OK: $f"
  else
    echo "  SYNTAX ERROR: $f"
    exit 1
  fi
done
shopt -u nullglob

# Check forbidden directories not tracked by git
echo
echo "[8] Checking forbidden directories not tracked by git..."
for dir in \
  multi_agent/logs \
  multi_agent/memory/daily \
  multi_agent/memory/failures \
  multi_agent/memory/decisions; do
  tracked=$(git ls-files --error-unmatch "$dir" 2>/dev/null && echo YES || echo NO)
  if [[ "$tracked" == "YES" ]]; then
    echo "  TRACKED (should not be): $dir"
    exit 1
  else
    echo "  OK (not tracked): $dir"
  fi
done

# Check .gitignore covers critical items
echo
echo "[9] Checking .gitignore coverage..."
required_patterns=(
  "logs/"
  "memory/daily/"
  "memory/failures/"
  "memory/decisions/"
  "workspace/"
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

# Check README has no obviously fake/inflated claims
echo
echo "[10] Checking README honesty..."
if grep -qi "fully functional\|production-ready\|fully integrated\|complete system" README.md 2>/dev/null; then
  echo "  WARNING: README may contain inflated claims"
  exit 1
else
  echo "  OK: README is appropriately modest"
fi

# Check model integration doc status
echo
echo "[11] Checking model integration doc status..."
if grep -qi "not.*integrat\|planned\|target\|future\|aspirational" docs/model-integration-roadmap.md 2>/dev/null; then
  echo "  OK: model integration is clearly marked as planned"
else
  echo "  WARNING: model integration status unclear"
  exit 1
fi

# Check no real API keys / tokens / secrets are present
echo
echo "[12] Scanning for leaked secrets..."
LEAKED=$(grep -rEl \
  "sk-[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9_-]{35,}|ghp_[a-zA-Z0-9]{36,}" \
  --include="*.md" --include="*.sh" --include="*.py" \
  --include="*.yaml" --include="*.yml" \
  . 2>/dev/null | grep -v ".git/" || true)
if [[ -n "$LEAKED" ]]; then
  echo "  LEAKED SECRETS FOUND:"
  echo "$LEAKED"
  exit 1
else
  echo "  OK: no obvious API keys/tokens detected"
fi

echo
echo "=== public smoke test passed ==="
