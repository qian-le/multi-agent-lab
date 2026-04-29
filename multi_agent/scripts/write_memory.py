#!/usr/bin/env python3
"""Write daily, project, decision, failure, and lesson memory."""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import sys


SECRET_VALUE_RE = re.compile(
    r"(?i)(api[_-]?key|token|secret|password|passwd|cookie|credential|private[_-]?key)\s*[:=]\s*['\"]?[^'\"\s]+"
)


def redact(text: str) -> str:
    return SECRET_VALUE_RE.sub(r"\1=<redacted>", text or "")


def safe_slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip())
    return value.strip("-")[:120] or "task"


def write_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def append_text(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(text)


def main() -> int:
    parser = argparse.ArgumentParser(description="Persist multi-agent memory safely.")
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--task-type", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--agents-used", required=True)
    parser.add_argument("--files-changed", default="")
    parser.add_argument("--commands-run", default="")
    parser.add_argument("--verifier-result", default="")
    parser.add_argument("--next-steps", default="")
    parser.add_argument("--lesson", default="")
    parser.add_argument("--root", default=".multi-agent")
    args = parser.parse_args()

    root = pathlib.Path(args.root)
    now = dt.datetime.now()
    day = now.strftime("%Y-%m-%d")
    clock = now.strftime("%H:%M:%S")

    task_id = redact(args.task_id)
    task_type = redact(args.task_type)
    summary = redact(args.summary)
    agents_used = redact(args.agents_used)
    files_changed = redact(args.files_changed)
    commands_run = redact(args.commands_run)
    verifier_result = redact(args.verifier_result)
    next_steps = redact(args.next_steps)

    daily_entry = f"""
## {clock} {task_id}

- task_type: {task_type}
- summary: {summary}
- agents_used: {agents_used}
- files_changed: {files_changed or "none"}
- commands_run: {commands_run or "none"}
- verifier_result: {verifier_result or "not_run"}
- next_steps: {next_steps or "none"}
"""
    append_text(root / "memory" / "daily" / f"{day}.md", daily_entry)

    project_status = f"""# Project Status

- project: openclaw-multi-agent-os
- state: active
- openclaw_config: .openclaw
- multi_agent_root: .multi-agent
- last_task: {task_id}
- last_task_type: {task_type}
- last_summary: {summary}
- last_verifier_result: {verifier_result or "not_run"}
- updated_at: {now.isoformat(timespec="seconds")}
"""
    write_text(root / "memory" / "project" / "status.md", project_status)

    verifier_lower = verifier_result.lower()
    if "fail" in verifier_lower:
        failure = f"""# Failure: {task_id}

- date: {now.isoformat(timespec="seconds")}
- task_type: {task_type}
- failure: {summary}
- verifier_result: {verifier_result}
- files_changed: {files_changed or "none"}
- commands_run: {commands_run or "none"}
- next_steps: {next_steps or "inspect failed checks and rerun workflow"}
"""
        write_text(root / "memory" / "failures" / f"{safe_slug(task_id)}.md", failure)

    if task_type == "architecture":
        decision = f"""# Architecture Decision: {task_id}

- date: {now.isoformat(timespec="seconds")}
- context: {summary}
- decision: recorded architecture workflow result
- alternatives: see run logs and Hermes review
- risks: see Guard decision and Verifier result
- verification: {verifier_result or "not_run"}
"""
        write_text(root / "memory" / "decisions" / f"{safe_slug(task_id)}.md", decision)

    if args.lesson.strip():
        lesson = f"""# Lesson: {task_id}

- date: {now.isoformat(timespec="seconds")}
- source_task: {task_id}
- lesson: {redact(args.lesson)}
- applies_to: {task_type}
- avoid: repeating known failure modes without verification
"""
        write_text(root / "memory" / "lessons" / f"{safe_slug(task_id)}.md", lesson)

    print(f"memory_written: {root / 'memory' / 'daily' / (day + '.md')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

