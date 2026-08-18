"""claude-board-shard-guard の fixture テスト。

PreToolUse guard の契約は「本物の board shard への Edit/Write だけを ask にし、
それ以外は必ず allow（無出力・exit 0）」。誤検知する guard は guard 全体を
無視させるので、allow 側のケースを厚くしてある。

ここで固定するのは:

  1. 本物の board shard（tasks / epics / repos / meta.json）→ ask
  2. scratchpad にコピーされた board → allow（検証セッションが temp に board を
     丸ごとコピーする。実測 2026-08-19 で 112 board・20885 shard あり、
     ここで訊くと毎回のノイズになる）
  3. `.furrow/` を含まない frozen-board fixture → allow（furrow の test 資産）
  4. Bash は対象外 → allow（実測の事故は全部 Bash 経路だが、正しい直し方の
     `git checkout --ours` まで巻き込むので意図的に非カバー）
  5. fail-open: 壊れた JSON / 空 stdin / file_path 欠落 → 無出力・exit 0
"""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-board-shard-guard"

BOARD = "/Volumes/workspace/github.com/akira-toriyama/projects/.furrow"


def run(payload: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT)],
        input=payload,
        capture_output=True,
        text=True,
        check=False,
    )


def call(tool: str, path: str) -> subprocess.CompletedProcess[str]:
    return run(json.dumps({"tool_name": tool, "tool_input": {"file_path": path}}))


def decision(proc: subprocess.CompletedProcess[str]) -> str | None:
    if not proc.stdout.strip():
        return None
    got = json.loads(proc.stdout)["hookSpecificOutput"]["permissionDecision"]
    assert isinstance(got, str)
    return got


class AsksOnRealShards(unittest.TestCase):
    def test_task_epic_repo_meta_all_ask(self) -> None:
        for rel in (
            "tasks/t-mzzp.json",
            "epics/e-3vvm.json",
            "repos/akira-toriyama-dotfiles.json",
            "meta.json",
        ):
            with self.subTest(rel=rel):
                proc = call("Edit", f"{BOARD}/{rel}")
                self.assertEqual(proc.returncode, 0)
                self.assertEqual(decision(proc), "ask")

    def test_every_edit_tool_is_covered(self) -> None:
        for tool in ("Edit", "Write", "MultiEdit"):
            with self.subTest(tool=tool):
                self.assertEqual(decision(call(tool, f"{BOARD}/tasks/t-x.json")), "ask")

    def test_reason_names_the_git_route(self) -> None:
        proc = call("Write", f"{BOARD}/tasks/t-x.json")
        out = json.loads(proc.stdout)["hookSpecificOutput"]
        reason = out["permissionDecisionReason"]
        self.assertIn("git checkout --ours", reason)
        self.assertIn("t-x.json", reason)


class AllowsEverythingElse(unittest.TestCase):
    def test_scratchpad_board_copy_is_exempt(self) -> None:
        roots = (
            "/tmp",
            "/private/tmp",
            "/var/folders/ab/cd",
            "/private/var/folders/ab/cd",
        )
        for root in roots:
            with self.subTest(root=root):
                proc = call("Write", f"{root}/sp/copy/.furrow/tasks/t-6npg.json")
                self.assertEqual(proc.stdout, "")
                self.assertEqual(proc.returncode, 0)

    def test_frozen_board_fixture_has_no_furrow_component(self) -> None:
        path = (
            "/Volumes/workspace/github.com/akira-toriyama/furrow"
            "/internal/store/fsstore/testdata/frozen-board/tasks/t-frzn1.json"
        )
        self.assertIsNone(decision(call("Write", path)))

    def test_bash_is_deliberately_uncovered(self) -> None:
        payload = json.dumps(
            {
                "tool_name": "Bash",
                "tool_input": {
                    "command": f"sed -i '' s/a/b/ {BOARD}/tasks/t-w77e.json"
                },
            }
        )
        self.assertIsNone(decision(run(payload)))

    def test_bodies_and_other_json_pass(self) -> None:
        for path in (
            f"{BOARD}/bodies/t-mzzp.md",
            f"{BOARD}/config.toml",
            "/Volumes/workspace/github.com/akira-toriyama/dotfiles/package.json",
        ):
            with self.subTest(path=path):
                self.assertIsNone(decision(call("Edit", path)))


class FailsOpen(unittest.TestCase):
    def test_broken_json(self) -> None:
        proc = run("not-json{{")
        self.assertEqual(proc.stdout, "")
        self.assertEqual(proc.returncode, 0)

    def test_empty_stdin(self) -> None:
        proc = run("")
        self.assertEqual(proc.stdout, "")
        self.assertEqual(proc.returncode, 0)

    def test_missing_file_path(self) -> None:
        proc = run(json.dumps({"tool_name": "Edit", "tool_input": {}}))
        self.assertEqual(proc.stdout, "")
        self.assertEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
