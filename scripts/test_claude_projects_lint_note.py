"""claude-projects-lint-note の fixture テスト。

SessionStart hook は fail-open が契約（壊れた hook はセッション開始ごとに
ノイズを吐く）。ここで固定するのは:

  1. fail-open: config 無し / path 行無し / lint script 無し → 無出力・exit 0
  2. happy path: config → checkout 解決 → lint 出力がそのまま stdout に出る
  3. lint が exit 2（error あり）でも hook は exit 0 で出力を通す

lint 本体は projects repo 側でテスト済み（scripts/projects_lint_test.py）なので、
ここでは stub の projects-lint.sh を置いて配管だけを見る。
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-projects-lint-note"


def run(config: str | None) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ)
    env["FURROW_CONFIG"] = config if config is not None else "/nonexistent/config.toml"
    return subprocess.run(
        ["bash", str(SCRIPT)], capture_output=True, text=True, check=False, env=env
    )


class FailOpen(unittest.TestCase):
    def test_missing_config_is_silent(self) -> None:
        p = run(None)
        self.assertEqual((p.returncode, p.stdout), (0, ""))

    def test_config_without_path_line_is_silent(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".toml", delete=False) as f:
            f.write('[[board]]\nrepo = "auto"\n')
        p = run(f.name)
        self.assertEqual((p.returncode, p.stdout), (0, ""))

    def test_checkout_without_lint_script_is_silent(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            cfg = Path(d) / "config.toml"
            cfg.write_text(f'[[board]]\npath = "{d}/.furrow"\n')
            p = run(str(cfg))
            self.assertEqual((p.returncode, p.stdout), (0, ""))


class HappyPath(unittest.TestCase):
    def fake_checkout(self, d: str, lint_body: str) -> str:
        """stub の projects-lint.sh を持つ checkout を作り config path を返す。"""
        scripts = Path(d) / "scripts"
        scripts.mkdir()
        (scripts / "projects-lint.sh").write_text(lint_body)
        cfg = Path(d) / "config.toml"
        cfg.write_text(f'[[board]]\npath = "{d}/.furrow"\nrepo = "auto"\n')
        return str(cfg)

    def test_lint_output_reaches_stdout(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            cfg = self.fake_checkout(d, 'echo "warn requests-open: t-1"\nexit 0\n')
            p = run(cfg)
            self.assertEqual(p.returncode, 0)
            self.assertIn("requests-open: t-1", p.stdout)

    def test_lint_errors_exit_2_still_prints_and_exits_0(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            cfg = self.fake_checkout(d, 'echo "error reserved-box-missing"\nexit 2\n')
            p = run(cfg)
            self.assertEqual(p.returncode, 0, "the hook must never fail the session")
            self.assertIn("reserved-box-missing", p.stdout)

    def test_clean_board_is_silent(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            cfg = self.fake_checkout(d, "exit 0\n")
            p = run(cfg)
            self.assertEqual((p.returncode, p.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
