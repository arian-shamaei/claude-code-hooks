#!/usr/bin/env python3
"""PreToolUse guard for the Zettelkasten vault.

Enforces the vault's one hard rule at the harness level: agents write only
inside ai/. Protected: notes/, sources/, inbox/, 000 Index.md. Reading is
never blocked. Exit 2 = block (stderr shown to the model).
"""
import json
import os
import sys

VAULT = os.path.expanduser("~/Documents/Zettelkasten")
PROTECTED = ["notes", "sources", "inbox", "000 Index.md"]

RULE = (
    "BLOCKED by the Zettelkasten vault rule: notes/, sources/, inbox/ and "
    "000 Index.md are Arian's writing — no agent writes there, ever. "
    "Machine output goes in ai/ (see the vault's CLAUDE.md). Propose the "
    "text in chat instead and let Arian write it himself."
)


def is_protected(path: str) -> bool:
    if not path:
        return False
    p = os.path.realpath(os.path.expanduser(path))
    if not p.startswith(VAULT + os.sep):
        return False
    rel = p[len(VAULT) + 1:]
    return any(rel == t or rel.startswith(t + os.sep) for t in PROTECTED)


def bash_touches_protected(cmd: str) -> bool:
    # Only care if the command mentions a protected vault path at all.
    lowered = cmd.replace("~", os.path.expanduser("~"))
    mentions = any(
        f"Zettelkasten/{t}" in lowered or f"Zettelkasten/{t.split('.')[0]}" in lowered
        for t in PROTECTED
    ) or "Zettelkasten/000" in lowered
    if not mentions:
        return False
    write_marks = (">", "tee ", "sed -i", "mv ", "cp ", "rm ", "rmdir",
                   "touch ", "mkdir ", "truncate", "install ", "rsync ",
                   "chmod ", "chflags ", "ln ", "unlink ", "python")
    return any(m in cmd for m in write_marks)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}
    if tool in ("Write", "Edit", "NotebookEdit"):
        path = ti.get("file_path") or ti.get("notebook_path") or ""
        if is_protected(path):
            print(RULE, file=sys.stderr)
            sys.exit(2)
    elif tool == "Bash":
        if bash_touches_protected(ti.get("command", "")):
            print(RULE + " (This Bash command looks like it writes to a "
                  "protected path; read-only commands are fine.)", file=sys.stderr)
            sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
