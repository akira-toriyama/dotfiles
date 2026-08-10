"""claude-fanout-cwd-guard の判定テスト。

この guard は 8 つの Claude hook のうち唯一 **作業を止められる**ので、壊れ方が
非対称になる。誤って止める（うるさい）と外されて終わり、止め損なう（黙る）と
2026-08-10 の事故がそのまま再発する —— 17 体中 0 体しか指定した木を読まず、
約 200 万 token と board への 21 件が全部無駄になった件。

なのでここで固定するのは境界そのもの:

  止める  : 同一 repo の別 worktree を指した Agent / Workflow の fan-out
  止めない: 別 repo のパス / 自分の木のパス / 対象外の tool / git 管理外 /
            jq や stdin が壊れている / 明示の環境変数による解除

git は fetch 不要なローカル repo だけで組み、ネットワークに依存させない。
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
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-fanout-cwd-guard"


def git(cwd: Path, *args: str) -> str:
    p = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
        env={
            **os.environ,
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
        },
    )
    return p.stdout


def commit(repo: Path, name: str) -> None:
    (repo / name).write_text(name, encoding="utf-8")
    git(repo, "add", name)
    git(repo, "-c", "user.name=t", "-c", "user.email=t@e", "commit", "-qm", name)


class FanoutCwdGuard(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        git(self.root, "init", "-q", "-b", "main", str(self.repo))
        commit(self.repo, "a")
        # 同一 repo の別 worktree（＝止めたい対象）
        self.sibling = self.root / "sibling"
        git(self.repo, "worktree", "add", "-q", "--detach", str(self.sibling), "HEAD")
        # 無関係な別 repo（＝止めてはいけない対象）
        self.other = self.root / "other"
        git(self.root, "init", "-q", "-b", "main", str(self.other))
        commit(self.other, "b")
        self.addCleanup(self.tmp.cleanup)

    def decide(
        self,
        *,
        tool: str = "Task",
        text: str,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
    ) -> str:
        payload = json.dumps(
            {
                "tool_name": tool,
                "tool_input": {"prompt": text},
                "cwd": str(cwd if cwd is not None else self.repo),
            }
        )
        p = subprocess.run(
            ["bash", str(SCRIPT)],
            input=payload,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, **(env or {})},
        )
        self.assertEqual(p.returncode, 0, f"guard must always exit 0: {p.stderr}")
        if not p.stdout.strip():
            return "allow"
        decision = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]
        return str(decision)

    # --- 止める側 -------------------------------------------------------
    def test_denies_a_sibling_worktree_of_the_same_repo(self) -> None:
        self.assertEqual(self.decide(text=f"review {self.sibling}"), "deny")

    def test_denies_for_the_workflow_tool_too(self) -> None:
        d = self.decide(tool="Workflow", text=f"review {self.sibling}")
        self.assertEqual(d, "deny")

    def test_denies_when_the_path_points_at_a_file_inside_the_sibling(self) -> None:
        d = self.decide(text=f"read {self.sibling}/a for context")
        self.assertEqual(d, "deny")

    def test_the_reason_names_both_trees_and_the_way_out(self) -> None:
        """止めるだけの guard は迂回される。次の一手まで出す。"""
        payload = json.dumps(
            {
                "tool_name": "Task",
                "tool_input": {"prompt": f"review {self.sibling}"},
                "cwd": str(self.repo),
            }
        )
        out = subprocess.run(
            ["bash", str(SCRIPT)],
            input=payload,
            capture_output=True,
            text=True,
            check=False,
        ).stdout
        reason = json.loads(out)["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertIn(str(self.repo), reason)
        self.assertIn(str(self.sibling), reason)
        self.assertIn("/cd", reason)
        self.assertIn("CLAUDE_ALLOW_CROSS_TREE_FANOUT", reason)

    # --- 止めない側 -----------------------------------------------------
    def test_allows_a_path_in_a_different_repository(self) -> None:
        """別 repo は正当な相互参照。ここを止めると毎日鳴って外される。"""
        self.assertEqual(self.decide(text=f"compare with {self.other}"), "allow")

    def test_allows_a_path_inside_the_session_tree(self) -> None:
        self.assertEqual(self.decide(text=f"review {self.repo}/a"), "allow")

    def test_allows_a_prompt_with_no_paths(self) -> None:
        self.assertEqual(self.decide(text="find the bug"), "allow")

    def test_allows_tools_other_than_agent_and_workflow(self) -> None:
        self.assertEqual(self.decide(tool="Bash", text=f"ls {self.sibling}"), "allow")

    def test_allows_when_cwd_is_not_a_git_work_tree(self) -> None:
        self.assertEqual(
            self.decide(text=f"review {self.sibling}", cwd=self.root), "allow"
        )

    def test_the_escape_hatch_allows_a_deliberate_cross_tree_run(self) -> None:
        d = self.decide(
            text=f"review {self.sibling}",
            env={"CLAUDE_ALLOW_CROSS_TREE_FANOUT": "1"},
        )
        self.assertEqual(d, "allow")

    # --- fail-open ------------------------------------------------------
    def test_unparseable_stdin_allows(self) -> None:
        p = subprocess.run(
            ["bash", str(SCRIPT)],
            input="not json",
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout.strip(), "")

    def test_empty_stdin_allows(self) -> None:
        p = subprocess.run(
            ["bash", str(SCRIPT)],
            input="",
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout.strip(), "")

    def test_without_jq_it_allows(self) -> None:
        """jq が無い環境で黙って止めると、原因の分からない全 fan-out 不能になる。"""
        bare = self.root / "bin"  # bash と git だけ通し jq は通さない PATH
        bare.mkdir()
        for tool in ("bash", "git"):
            found = shutil.which(tool)
            if found is None:  # pragma: no cover - devShell が供給する
                self.skipTest(f"{tool} not on PATH")
            (bare / tool).symlink_to(found)
        p = subprocess.run(
            [str(bare / "bash"), str(SCRIPT)],
            input=json.dumps(
                {
                    "tool_name": "Task",
                    "tool_input": {"prompt": f"review {self.sibling}"},
                    "cwd": str(self.repo),
                }
            ),
            capture_output=True,
            text=True,
            check=False,
            env={"PATH": str(bare), "HOME": os.environ.get("HOME", "/tmp")},
        )
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout.strip(), "")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
