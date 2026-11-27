"""Fixture tests for claude-list-table-note (UserPromptSubmit hook).

What is pinned:
  1. a list word (一覧 / リスト / list / lists) with a subject word (epic(s) /
     task(s) / エピック / タスク / 箱) gets the note in the hookSpecificOutput
     shape — one fire case per word, each the only one of its group, so
     losing any alternative fails a case
  2. silent: other lists (PR, lint, keyboard, dashboard, onboarding), an
     English word inside a longer one (checklist, subtasks, listener), 箱
     inside a word (ゴミ箱, 宝箱, 箱根), a background report, a continuation
     summary, and a cwd that is not on a configured furrow board
  3. fail-open: empty, unparseable or prompt-less stdin, no furrow, no config
     → no output, exit 0

furrow is a stub that reports the configured board only from the fleet
directory, as the real one does inside a [[board]] scope, and fails
elsewhere. Only jq and the stub are on PATH: jq's own directory also holds
the real furrow (same setup as test_claude_epic_guard.py).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-list-table-note"

BOARD = "/Volumes/workspace/github.com/akira-toriyama/projects/.furrow"
CONFIG = f'''[[board]]
path        = "{BOARD}"
scopes      = ["/Volumes/workspace/github.com/akira-toriyama"]
'''

STUB = """#!/bin/sh
[ "$1 $2" = "board --json" ] || exit 2
if [ "$(pwd -P)" = "$STUB_FLEET_DIR" ]; then
  printf '{"store":"%s","source":"user-config"}\\n' "$STUB_STORE"
  exit 0
fi
echo '{"error":{"kind":"validation","message":"no .furrow found"}}' >&2
exit 2
"""

NOTE = (
    "If the user is asking for the list of furrow epics (boxes): run "
    "`furrow-epic-table` (add `-r <owner/repo>` for another repo, `-r ''` for "
    "the whole board) and show its markdown table as is — ▶ active, 進捗 = "
    "done/total, icebox = members parked in icebox. A box's own tasks are not "
    "this table (`furrow epic show <id>`)."
)
FIRED = {
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": NOTE,
    }
}


class Hook(unittest.TestCase):
    def setUp(self) -> None:
        jq = shutil.which("jq")
        if jq is None:  # pragma: no cover - the devShell supplies it
            raise unittest.SkipTest("jq not on PATH")
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(os.path.realpath(tmp.name))
        self.bindir = root / "bin"
        self.bindir.mkdir()
        (self.bindir / "jq").symlink_to(jq)
        stub = self.bindir / "furrow"
        stub.write_text(STUB)
        stub.chmod(0o755)
        self.fleet = root / "fleet"
        self.fleet.mkdir()
        self.outside = root / "outside"
        self.outside.mkdir()
        self.config = root / "config.toml"
        self.config.write_text(CONFIG)
        self.home = root

    def run_hook(
        self, stdin: str, *, store: str = BOARD, config: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        env = {
            "PATH": os.pathsep.join([str(self.bindir), "/usr/bin", "/bin"]),
            "HOME": str(self.home),
            "FURROW_CONFIG": str(config or self.config),
            "STUB_FLEET_DIR": str(self.fleet),
            "STUB_STORE": store,
        }
        return subprocess.run(
            ["bash", str(SCRIPT)],
            input=stdin,
            capture_output=True,
            encoding="utf-8",
            check=False,
            env=env,
        )

    def payload(self, prompt: str, cwd: Path | None = None) -> str:
        return json.dumps(
            {
                "session_id": "s",
                "hook_event_name": "UserPromptSubmit",
                "cwd": str(cwd or self.fleet),
                "prompt": prompt,
            },
            ensure_ascii=False,
        )

    def assertSilent(self, p: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual((p.returncode, p.stdout), (0, ""), p.stderr)


class Fires(Hook):
    def test_each_list_word_and_subject_word_fires(self) -> None:
        for prompt in (
            "epic 一覧見せて",  # 一覧 + epic
            "task 一覧見せて",  # 一覧 + task
            "このリポの epic 一覧見せて",
            "list the epics",  # list + epics
            "list the tasks",  # list + tasks
            "show the epic lists",  # lists
            "List the EPICS",  # case-insensitive, both words
            "task listを見せて",  # a regex \b would see no bound before the kana
            "タスクのリスト見せて",  # リスト + タスク
            "エピック一覧",  # エピック
            "箱の一覧見せて",  # 箱
            "箱一覧見せて",  # 箱 before 一覧, the one kanji allowed after it
        ):
            with self.subTest(prompt=prompt):
                p = self.run_hook(self.payload(prompt))
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(json.loads(p.stdout), FIRED)


class Silent(Hook):
    def test_other_lists_and_words_inside_words_stay_silent(self) -> None:
        for prompt in (
            "PR 一覧見せて",
            "lint の一覧",
            "task の checklist を直して",
            "キーボードの一覧",
            "list the keyboard layers",
            "ダッシュボード一覧",
            "onboarding list",
            "list the subtasks",
            "fix the task listener",
            "ゴミ箱の一覧",
            "宝箱の一覧",
            "箱根の宿一覧",
        ):
            with self.subTest(prompt=prompt):
                self.assertSilent(self.run_hook(self.payload(prompt)))

    def test_a_prompt_the_user_did_not_type_stays_silent(self) -> None:
        for prompt in (
            "<task-notification>\n<task-id>a1</task-id>\n"
            "<status>completed</status>\n"
            "<summary>the epic task list agent finished</summary>\n"
            "</task-notification>",
            "This session is being continued from a previous conversation that ran "
            "out of context. The user asked for the epic 一覧 and the task list.",
        ):
            with self.subTest(prompt=prompt[:30]):
                self.assertSilent(self.run_hook(self.payload(prompt)))

    def test_a_cwd_off_the_configured_boards_stays_silent(self) -> None:
        prompt = "epic 一覧見せて"
        with self.subTest("no board in scope"):
            self.assertSilent(self.run_hook(self.payload(prompt, cwd=self.outside)))
        with self.subTest("a board the config does not name"):
            p = self.run_hook(
                self.payload(prompt), store="/private/tmp/scratch/.furrow"
            )
            self.assertSilent(p)


class FailOpen(Hook):
    def test_empty_or_invalid_stdin_is_silent(self) -> None:
        for stdin in ("", "not json", '{"prompt": "epic 一覧', '{"prompt": 3}', "[]"):
            with self.subTest(stdin=stdin):
                self.assertSilent(self.run_hook(stdin))

    def test_no_furrow_or_no_config_is_silent(self) -> None:
        prompt = self.payload("epic 一覧見せて")
        with self.subTest("no config"):
            self.assertSilent(self.run_hook(prompt, config=self.home / "none.toml"))
        with self.subTest("no furrow"):
            (self.bindir / "furrow").unlink()
            self.assertSilent(self.run_hook(prompt))


if __name__ == "__main__":
    unittest.main()
