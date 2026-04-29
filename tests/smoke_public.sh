#!/usr/bin/env bash
# Public smoke test — checks file structure and script syntax
# No runtime dependencies (openclaw/hermes/claude not required)
set -euo pipefail

echo "=== Public Smoke Test ==="
echo

# Check root files
echo "[1] Checking root files..."
for f in README.md LICENSE CONTRIBUTING.md ROADMAP.md SECURITY.md .gitignore; do
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
  .multi-agent/agents/memory_manager.md \
  .multi-agent/workflows/info.yaml \
  .multi-agent/workflows/modify.yaml \
  .multi-agent/workflows/analysis.yaml \
  .multi-agent/workflows/debug.yaml \
  .multi-agent/workflows/architecture.yaml \
  .multi-agent/workflows/risky.yaml \
  .multi-agent/scripts/run_workflow.sh \
  .multi-agent/scripts/verify.py \
  .multi-agent/scripts/guard_check.py \
  .multi-agent/adapters/openclaw_adapter.md \
  .multi-agent/adapters/hermes_adapter.md \
  .multi-agent/adapters/claude_code_adapter.md \
  .multi-agent/memory/templates/daily.md; do
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
echo "[7] Checking Python script syntax..."
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

# Check forbidden directories not tracked by git
echo
echo "[8] Checking forbidden directories not tracked by git..."
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

# Check .gitignore covers critical items
echo
echo "[9] Checking .gitignore coverage..."
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

# Check README has no obviously fake/inflated claims
echo
echo "[10] Checking README honesty..."
# Allow "not a production system" (honest disclaimer) but flag inflated claims
if grep -qi "fully functional\|production-ready\|fully integrated\|complete system" README.md 2>/dev/null; then
  echo "  WARNING: README may contain inflated claims"
  exit 1
else
  echo "  OK: README is appropriately modest"
fi

# Check MiMo doc clearly marks integration as planned
echo
echo "[11] Checking MiMo doc status..."
if grep -qi "not.*integrat\|planned\|target\|future\|aspirational" docs/model-integration-roadmap.md 2>/dev/null; then
  echo "  OK: MiMo integration is clearly marked as planned"
else
  echo "  WARNING: MiMo integration status unclear in docs/mimo-orbit.md"
  exit 1
fi

echo
echo "=== public smoke test passed ==="
