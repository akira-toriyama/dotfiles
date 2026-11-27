"""Fixture tests for claude-list-table-note (UserPromptSubmit hook).

What is pinned:
  1. a prompt asking for an epic or task list gets the note, in the
     hookSpecificOutput shape, English or Japanese, any case
  2. another list (PR, lint) and `list` inside a word (checklist) stay silent
  3. fail-open: empty, unparseable or prompt-less stdin → no output, exit 0
"""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-list-table-note"

NOTE = (
    "furrow list request: run `furrow-epic-table` (add `-r <owner/repo>` for "
    "another repo, `-r ''` for the whole board) and show its markdown table as "
    "is — ▶ active, 進捗 = done/total, icebox = members parked in icebox."
)


def run(stdin: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT)],
        input=stdin,
        capture_output=True,
        encoding="utf-8",
        check=False,
    )


def hook_input(prompt: str) -> str:
    return json.dumps(
        {"session_id": "s", "hook_event_name": "UserPromptSubmit", "prompt": prompt},
        ensure_ascii=False,
    )


class Fires(unittest.TestCase):
    def test_a_list_request_gets_the_note(self) -> None:
        want = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": NOTE,
            }
        }
        for prompt in (
            "epic 一覧見せて",
            "task 一覧見せて",
            "このリポの epic 一覧見せて",
            "list the epics",
            "List the EPICS",
            # A regex \b would see no word bound between `list` and the kana.
            "task listを見せて",
        ):
            with self.subTest(prompt=prompt):
                p = run(hook_input(prompt))
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(json.loads(p.stdout), want)


class Silent(unittest.TestCase):
    def test_other_lists_and_a_checklist_stay_silent(self) -> None:
        for prompt in ("PR 一覧見せて", "lint の一覧", "task の checklist を直して"):
            with self.subTest(prompt=prompt):
                p = run(hook_input(prompt))
                self.assertEqual((p.returncode, p.stdout), (0, ""))


class FailOpen(unittest.TestCase):
    def test_empty_or_invalid_stdin_is_silent(self) -> None:
        for stdin in ("", "not json", '{"prompt": "epic 一覧', '{"prompt": 3}', "[]"):
            with self.subTest(stdin=stdin):
                p = run(stdin)
                self.assertEqual((p.returncode, p.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
