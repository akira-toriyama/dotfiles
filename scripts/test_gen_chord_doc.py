"""gen-chord-doc.py の引数処理のテスト。

守っているのは 1 点だけ: **未知フラグで書き込みモードに落ちないこと**。
以前は `check_only=("--check" in sys.argv[1:])` だったので、`--dry-run` や
`--chek` と打つと「読むだけのつもり」が docs/chord.md の書き換えになった。
生成ロジック本体は verify-chord-doc.yml が `--check` で回している。
"""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "gen-chord-doc.py"
DOC = ROOT / "docs" / "chord.md"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


class UnknownFlags(unittest.TestCase):
    def test_an_unknown_flag_is_a_usage_error_not_a_write(self) -> None:
        before = DOC.read_bytes()
        p = run("--dry-run")
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertIn("unrecognized arguments", p.stderr)
        self.assertEqual(DOC.read_bytes(), before, "doc was modified by a bad flag")

    def test_a_near_miss_of_check_does_not_silently_write(self) -> None:
        before = DOC.read_bytes()
        p = run("--chek")
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertEqual(DOC.read_bytes(), before, "doc was modified by a typo")


class CheckMode(unittest.TestCase):
    def test_check_reports_sync_without_writing(self) -> None:
        before = DOC.read_bytes()
        p = run("--check")
        # 0 = 同期済み / 1 = 差分あり。どちらでも書き込んではいけない。
        self.assertIn(p.returncode, (0, 1), p.stderr)
        self.assertEqual(DOC.read_bytes(), before)

    def test_help_exits_zero(self) -> None:
        p = run("--help")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("--check", p.stdout)


if __name__ == "__main__":
    unittest.main()
