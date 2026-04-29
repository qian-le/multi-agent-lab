#!/usr/bin/env python3
"""Verifier for OpenClaw Multi-Agent OS."""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys


SECRET_VALUE_RE = re.compile(
    r"(?i)(api[_-]?key|token|secret|password|passwd|cookie|credential|private[_-]?key)\s*[:=]\s*['\"]?[^'\"\s]+"
)
CREATE_WORKSPACE_RE = re.compile(r"^create\s+workspace/(\S+)\s+with\s+(.+)$")


def redact(text: str) -> str:
    return SECRET_VALUE_RE.sub(r"\1=<redacted>", text)


def add_result(results: list[tuple[str, str]], ok: bool, message: str) -> None:
    results.append(("pass" if ok else "fail", message))


def parse_create_workspace_goal(goal: str) -> tuple[pathlib.Path | None, str | None, str | None]:
    match = CREATE_WORKSPACE_RE.match(goal.strip())
    if not match:
        return None, None, None

    filename, expected = match.groups()
    if not filename:
        return None, None, "filename is empty"
    if filename.startswith("/"):
        return None, None, "filename must not start with /"
    if ".." in filename:
        return None, None, "filename must not contain .."
    if "~" in filename:
        return None, None, "filename must not contain ~"
    if "/" in filename:
        return None, None, "filename must not contain path separators"

    return pathlib.Path(".multi-agent") / "workspace" / filename, expected, None


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify files, content, commands, and logs.")
    parser.add_argument("--file-exists", action="append", default=[])
    parser.add_argument("--file-contains", nargs=2, action="append", default=[], metavar=("PATH", "TEXT"))
    parser.add_argument("--command", action="append", default=[])
    parser.add_argument("--goal")
    parser.add_argument("--log-file")
    args = parser.parse_args()

    results: list[tuple[str, str]] = []
    strict_goal_failed = False

    if args.goal:
        path, expected, error = parse_create_workspace_goal(args.goal)
        if error:
            add_result(results, False, f"safe create goal rejected: {error}")
            strict_goal_failed = True
        elif path is not None and expected is not None:
            raw_path = str(path)
            exists = path.exists()
            add_result(results, exists, f"file exists: {raw_path}")
            if exists:
                text = path.read_text(encoding="utf-8", errors="replace")
                contains = expected in text
                add_result(results, contains, f"file contains '{expected}': {raw_path}")
                strict_goal_failed = strict_goal_failed or not contains
            else:
                add_result(results, False, f"file contains '{expected}': {raw_path} missing")
                strict_goal_failed = True

    for raw_path in args.file_exists:
        path = pathlib.Path(raw_path)
        add_result(results, path.exists(), f"file exists: {raw_path}")

    for raw_path, expected in args.file_contains:
        path = pathlib.Path(raw_path)
        if not path.exists():
            add_result(results, False, f"file contains '{expected}': {raw_path} missing")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        add_result(results, expected in text, f"file contains '{expected}': {raw_path}")

    for command in args.command:
        completed = subprocess.run(
            command,
            shell=True,
            executable="/bin/bash",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120,
        )
        output = redact(completed.stdout.strip())
        ok = completed.returncode == 0
        detail = f"command exit 0: {command}"
        if output:
            detail += f" | output: {output[:500]}"
        add_result(results, ok, detail)

    if args.log_file:
        path = pathlib.Path(args.log_file)
        add_result(results, path.exists() and path.stat().st_size > 0, f"log exists and non-empty: {args.log_file}")

    if not results:
        status = "partial"
    elif strict_goal_failed:
        status = "fail"
    elif all(result == "pass" for result, _ in results):
        status = "pass"
    elif any(result == "pass" for result, _ in results):
        status = "partial"
    else:
        status = "fail"

    print("## Verifier Result")
    print()
    print(f"- status: {status}")
    print("- checks:")
    for result, message in results:
        print(f"  - {result}: {redact(message)}")
    print("- evidence:")
    print("  - verifier executed locally")
    print("- next_steps:")
    if status == "pass":
        print("  - none")
    else:
        print("  - inspect failed checks and rerun workflow")

    return {"pass": 0, "partial": 2, "fail": 1}[status]


if __name__ == "__main__":
    sys.exit(main())
