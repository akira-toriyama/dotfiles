"""claude-board-shard-guard の fixture テスト。

PreToolUse guard の契約は「**この機械が使うよう設定された board** の shard への
Edit/Write だけを ask にし、それ以外は必ず allow（無出力・exit 0）」。
誤検知する guard は guard 全体を無視させるので、allow 側のケースを厚くしてある。

scope を「パスの形」ではなく「furrow の config に載っている board」にしているのは、
形だけで判定した初版が実害を出したため（2026-08-19）: `*/.furrow/tasks/*.json` は
board の**コピー**にも一致し、コピーは本物より桁違いに多い（/private/tmp だけで
112 board・20885 shard）。除外リストは完成しようがなく、実際に
~/Library/Caches/askprobe/.furrow/tasks/ へ書こうとした検証エージェントが ask に
当たり、**非対話のサブエージェントには ask に答える相手が居ないので停止した**。

ここで固定するのは:
  1. 設定された board の shard（tasks / epics / repos / meta.json）→ ask
  2. 設定外の .furrow/（temp・cache・他人の checkout）→ allow
  3. `.furrow/` を含まない frozen-board fixture → allow（furrow の test 資産）
  4. Bash は対象外 → allow（実測の事故は全部 Bash 経路だが、正しい直し方の
     `git checkout --ours` まで巻き込むので意図的に非カバー）
  5. fail-open: 壊れた JSON / 空 stdin / file_path 欠落 / config 不読 → 無出力・exit 0
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-board-shard-guard"

BOARD = "/Volumes/workspace/github.com/akira-toriyama/projects/.furrow"
OTHER_BOARD = "/Volumes/workspace/github.com/akira-toriyama/other/.furrow"
CONFIG = f'''# test fixture
[[board]]
path        = "{BOARD}"
scopes      = ["/Volumes/workspace/github.com/akira-toriyama"]

[[board]]
path        = "{OTHER_BOARD}"
'''


def run(payload: str, config: str | None = CONFIG) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ)
    with tempfile.TemporaryDirectory() as tmp:
        if config is None:
            env["FURROW_CONFIG"] = str(Path(tmp) / "nonexistent.toml")
        else:
            cfg = Path(tmp) / "config.toml"
            cfg.write_text(config)
            env["FURROW_CONFIG"] = str(cfg)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            input=payload,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )


def call(tool: str, path: str, **kw: object) -> subprocess.CompletedProcess[str]:
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    return run(payload, **kw)  # type: ignore[arg-type]


def decision(proc: subprocess.CompletedProcess[str]) -> str | None:
    if not proc.stdout.strip():
        return None
    got = json.loads(proc.stdout)["hookSpecificOutput"]["permissionDecision"]
    assert isinstance(got, str)
    return got


class AsksOnTheConfiguredBoard(unittest.TestCase):
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

    def test_every_configured_board_counts_not_just_the_first(self) -> None:
        proc = call("Write", f"{OTHER_BOARD}/tasks/t-x.json")
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


class AllowsBoardsThisMachineDoesNotUse(unittest.TestCase):
    def test_the_cache_path_that_hung_an_agent(self) -> None:
        """2026-08-19 の実害そのもの。ask は非対話エージェントを止める。"""
        path = "/Users/tommy/Library/Caches/askprobe/.furrow/tasks/t-probe.json"
        self.assertIsNone(decision(call("Write", path)))

    def test_scratchpad_and_other_checkouts(self) -> None:
        for path in (
            "/private/tmp/claude-501/sp/copy/.furrow/tasks/t-6npg.json",
            "/tmp/x/.furrow/meta.json",
            "/var/folders/ab/cd/T/y/.furrow/epics/e-1.json",
            "/Users/tommy/somewhere-else/.furrow/tasks/t-1.json",
        ):
            with self.subTest(path=path):
                self.assertIsNone(decision(call("Write", path)))

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

    def test_bodies_and_other_files_under_the_board_pass(self) -> None:
        for path in (
            f"{BOARD}/bodies/t-mzzp.md",
            f"{BOARD}/config.toml",
            f"{BOARD}/tasks/notes.md",
        ):
            with self.subTest(path=path):
                self.assertIsNone(decision(call("Edit", path)))


class FailsOpen(unittest.TestCase):
    def test_no_readable_config(self) -> None:
        proc = call("Edit", f"{BOARD}/tasks/t-x.json", config=None)
        self.assertEqual(proc.stdout, "")
        self.assertEqual(proc.returncode, 0)

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
