"""git-stale-check の判定テスト（t-vk0w）。

この script は 2 つの hook から自動で走る（zsh の chpwd と Claude の
SessionStart）ので、壊れ方は「誤警告でうるさい」か「黙る」の 2 択。後者は
気づけない —— stale read 事故の再発を止める唯一の機構が無言で死ぬ。ここで固定するのは
その 2 方向:

  出す   : upstream より behind のときだけ、件数と upstream 名つきで 1 行
  出さない: git 管理外 / upstream 無し / detached HEAD / 最新 / ahead のみ

fetch は throttle + 背景実行なのでテストでは触らない。XDG_CACHE_HOME を tmpdir へ
逃がして throttle stamp が $HOME を汚さないようにし、remote は fetch 不要な
ローカル bare repo で作る（ネットワーク非依存）。
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_git-stale-check"


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


class GitStaleCheck(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.cache = self.root / "cache"
        # bare remote <- clone。fetch なしで behind を作れる形にする。
        self.remote = self.root / "remote.git"
        git(self.root, "init", "-q", "--bare", "-b", "main", str(self.remote))
        self.seed = self.root / "seed"
        git(self.root, "clone", "-q", str(self.remote), str(self.seed))
        commit(self.seed, "a")
        git(self.seed, "push", "-q", "origin", "main")
        self.repo = self.root / "work"
        git(self.root, "clone", "-q", str(self.remote), str(self.repo))
        self.addCleanup(self.tmp.cleanup)

    def run_check(self, cwd: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, "XDG_CACHE_HOME": str(self.cache)},
        )

    def make_behind(self, n: int) -> None:
        """upstream を n commit 進め、work の remote-tracking ref だけ更新する。"""
        for i in range(n):
            commit(self.seed, f"ahead{i}")
        git(self.seed, "push", "-q", "origin", "main")
        git(self.repo, "fetch", "-q", "origin")

    def test_silent_when_up_to_date(self) -> None:
        p = self.run_check(self.repo)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_warns_when_behind(self) -> None:
        self.make_behind(2)
        p = self.run_check(self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("git-stale-check", p.stdout)
        self.assertIn("2 commit(s) behind", p.stdout)
        self.assertIn("origin/main", p.stdout)
        self.assertIn("work", p.stdout, "the warning should name the repo")

    def test_warning_goes_to_stdout_not_stderr(self) -> None:
        """SessionStart hook は stdout をセッション冒頭 context に入れる。
        stderr に出すと agent 側には届かない（この script の存在理由が消える）。"""
        self.make_behind(1)
        p = self.run_check(self.repo)
        self.assertIn("behind", p.stdout)
        self.assertNotIn("behind", p.stderr)

    def test_silent_when_ahead_only(self) -> None:
        commit(self.repo, "local-only")
        p = self.run_check(self.repo)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "", "ahead is not stale — pulling would be wrong")

    def test_silent_without_an_upstream(self) -> None:
        git(self.repo, "checkout", "-q", "-b", "no-upstream")
        p = self.run_check(self.repo)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_silent_on_detached_head(self) -> None:
        head = git(self.repo, "rev-parse", "HEAD").strip()
        git(self.repo, "checkout", "-q", head)
        p = self.run_check(self.repo)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_silent_outside_a_repo(self) -> None:
        plain = self.root / "plain"
        plain.mkdir()
        p = self.run_check(plain)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_never_exits_nonzero(self) -> None:
        """advisory only — chpwd と SessionStart から走るので、非 0 は
        prompt やセッション開始の側で騒ぎになる。"""
        self.make_behind(1)
        for cwd in (self.repo, self.root):
            self.assertEqual(self.run_check(cwd).returncode, 0, str(cwd))


if __name__ == "__main__":
    unittest.main()
