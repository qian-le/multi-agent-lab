#!/usr/bin/env python3
"""Guard check for OpenClaw Multi-Agent OS execution plans."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys


DENY_PATTERNS = [
    (re.compile(r"\brm\s+-[^\n]*r[^\n]*f|\brm\s+-[^\n]*f[^\n]*r", re.I), "recursive force delete is forbidden"),
    (re.compile(r"\bsudo\b", re.I), "sudo is forbidden"),
    (re.compile(r"\bchmod\s+-R\b", re.I), "recursive chmod is forbidden"),
    (re.compile(r"\bchown\s+-R\b", re.I), "recursive chown is forbidden"),
    (re.compile(r"\bdd\s+if=", re.I), "raw disk writes are forbidden"),
    (re.compile(r"\bmkfs(\.|\\s|$)", re.I), "filesystem formatting is forbidden"),
    (re.compile(r"\bshred\b", re.I), "secure deletion is forbidden"),
]

ASK_PATTERNS = [
    (re.compile(r"\bdelete\b|\bremove\b|\boverwrite\b|删除|覆盖|清空", re.I), "destructive intent needs user confirmation"),
    (re.compile(r"\b(systemctl|service)\b", re.I), "service management needs user confirmation"),
    (re.compile(r"\b(apt|apt-get|yum|dnf|pacman|brew|npm|pip3?|cargo)\s+install\b", re.I), "install commands need user confirmation"),
]

SYSTEM_PATH_RE = re.compile(r"(^|[\s'\"=:])/(usr|bin|etc|var|boot|dev|proc|sys|root)(/|[\s'\"=:]|$)")
SECRET_RE = re.compile(
    r"(api[_-]?key|token|secret|password|passwd|cookie|credential|private[_-]?key)",
    re.I,
)


def read_text(path: str | None) -> str:
    if not path:
        return ""
    p = pathlib.Path(path)
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")


def hermes_decision(text: str) -> str:
    if not text:
        return ""
    lines = [line.strip().lower() for line in text.splitlines()]
    final_lines = [line for line in lines if "final" in line or "最终建议" in line]
    haystack = "\n".join(final_lines or lines[-10:])
    if "reject" in haystack:
        return "reject"
    if "revise" in haystack:
        return "revise"
    if "approve" in haystack:
        return "approve"
    return ""


def has_clear_scope(plan: str) -> bool:
    required_markers = ("allowed_files:", "需要修改的文件", "执行步骤", "commands:", "验证方法")
    return any(marker in plan for marker in required_markers)


def emit(decision: str, risk_level: str, reason: str, allowed_scope: str, forbidden_actions: str) -> int:
    print("[Guard Decision]")
    print(f"decision: {decision}")
    print(f"risk_level: {risk_level}")
    print(f"reason: {reason}")
    print("allowed_scope:")
    print(allowed_scope.strip() or "- none")
    print("forbidden_actions:")
    print(forbidden_actions.strip() or "- destructive deletes")
    print("- recursive permission or ownership changes")
    print("- system path modification")
    print("- secret exposure or credential handling")
    return {"allow": 0, "ask_user": 2, "deny": 3}[decision]


def main() -> int:
    parser = argparse.ArgumentParser(description="Check an execution plan before Executor runs.")
    parser.add_argument("--plan-file", required=True)
    parser.add_argument("--task-type", default="modify")
    parser.add_argument("--hermes-file")
    parser.add_argument("--analyst-revised", action="store_true")
    args = parser.parse_args()

    plan = read_text(args.plan_file)
    hermes = read_text(args.hermes_file)
    task_type = args.task_type.strip().lower()

    if not plan.strip():
        return emit("ask_user", "medium", "execution plan is empty", "- none", "- all execution until scope is clear")

    h_decision = hermes_decision(hermes)
    if h_decision == "reject":
        return emit("deny", "high", "Hermes rejected the plan", "- none", "- all execution")
    if h_decision == "revise" and not args.analyst_revised:
        return emit("deny", "medium", "Hermes requested revision but Analyst revision is missing", "- none", "- all execution")

    if task_type == "risky":
        return emit("ask_user", "high", "task_type is risky and requires explicit user confirmation", "- none", "- all execution")

    for pattern, reason in DENY_PATTERNS:
        if pattern.search(plan):
            return emit("deny", "high", reason, "- none", "- forbidden command in plan")

    if SYSTEM_PATH_RE.search(plan):
        return emit("deny", "high", "plan references protected system paths", "- none", "- system path modification")

    if SECRET_RE.search(plan):
        return emit("ask_user", "high", "plan references credential or secret-related keywords", "- none", "- secret exposure or credential handling")

    for pattern, reason in ASK_PATTERNS:
        if pattern.search(plan):
            return emit("ask_user", "medium", reason, "- pending user confirmation", "- destructive or environment-changing actions")

    if task_type in {"modify", "debug", "architecture"} and not has_clear_scope(plan):
        return emit("ask_user", "medium", "execution scope is not clear enough", "- none", "- all execution until scope is clear")

    risk = "medium" if task_type in {"debug", "architecture"} else "low"
    allowed = []
    for line in plan.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ") and (
            ".multi-agent/" in stripped
            or "workspace/" in stripped
            or stripped.startswith("- no file changes")
        ):
            allowed.append(stripped)
    if not allowed:
        allowed.append("- scope defined in Analyst Plan")

    return emit(
        "allow",
        risk,
        "plan has clear scope and no forbidden operations were detected",
        "\n".join(allowed),
        "- destructive deletes\n- recursive permission changes\n- system path modification\n- secret exposure",
    )


if __name__ == "__main__":
    sys.exit(main())

