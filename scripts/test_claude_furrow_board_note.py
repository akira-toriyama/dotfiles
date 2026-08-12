"""claude-furrow-board-note の fixture テスト。

SessionStart hook は fail-open が契約（壊れた hook はセッション開始ごとに
ノイズを吐く）。ここで固定するのは:

  1. fail-open: furrow 不在 / board が非 0 終了 / 空出力 / 壊れた JSON
     → 無出力・exit 0
  2. writable=true → 完全に無音（健全な board で毎回喋る hook は読まれなくなる）
  3. writable=false → 1 行出る。両方の version を数字で名指しし、
     「READ は通る」という非対称性に触れる（これが気づけない理由そのもの）
  4. schema_state で remedy が分岐する: too-new は binary を上げる /
     outdated は checkout を戻すか board を upgrade するかを人間が選ぶ
     （hook は flag day の順序を勝手に決めない）

`furrow board` 本体は furrow 側でテスト済みなので、ここでは stub を
FURROW_BOARD_CMD に差して配管だけを見る。
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-furrow-board-note"


def run_with(stub_body: str | None) -> subprocess.CompletedProcess[str]:
    """Run the hook with `furrow board --json` stubbed by a shell script."""
    env = dict(os.environ)
    with tempfile.TemporaryDirectory() as tmp:
        if stub_body is None:
            env["FURROW_BOARD_CMD"] = str(Path(tmp) / "nonexistent-furrow")
        else:
            stub = Path(tmp) / "furrow-stub"
            stub.write_text(stub_body)
            stub.chmod(0o755)
            env["FURROW_BOARD_CMD"] = str(stub)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )


def emitting(json_line: str) -> str:
    return f"#!/bin/sh\ncat <<'EOF'\n{json_line}\nEOF\n"


READ_ONLY = (
    '{"schema_version":8,"binary_schema_version":9,'
    '"schema_state":"outdated","writable":false}'
)
TOO_NEW = (
    '{"schema_version":10,"binary_schema_version":9,'
    '"schema_state":"too-new","writable":false}'
)
HEALTHY = (
    '{"schema_version":9,"binary_schema_version":9,'
    '"schema_state":"current","writable":true}'
)


class TestFailOpen(unittest.TestCase):
    """A hook that breaks the session is worse than a missed warning."""

    def test_missing_furrow_is_silent(self) -> None:
        r = run_with(None)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")

    def test_nonzero_exit_is_silent(self) -> None:
        # `board` never fails on a version mismatch, so a non-zero exit means
        # something else (no board in scope) — not a condition to warn about.
        r = run_with("#!/bin/sh\nexit 2\n")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")

    def test_empty_output_is_silent(self) -> None:
        r = run_with("#!/bin/sh\n:\n")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")

    def test_unparseable_json_is_silent(self) -> None:
        r = run_with(emitting("not json at all"))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")


class TestHealthyBoardIsSilent(unittest.TestCase):
    def test_writable_board_says_nothing(self) -> None:
        r = run_with(emitting(HEALTHY))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(
            r.stdout,
            "",
            "a hook that speaks on every healthy session start stops being read",
        )


class TestReadOnlyBoardWarns(unittest.TestCase):
    def test_one_line_naming_both_versions(self) -> None:
        r = run_with(emitting(READ_ONLY))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(len(r.stdout.strip().splitlines()), 1, r.stdout)
        self.assertIn("v8", r.stdout)
        self.assertIn("v9", r.stdout)

    def test_names_the_asymmetry_that_hides_it(self) -> None:
        # The whole reason this hook exists: reads keep working, so nothing
        # looks wrong until a write. If the line does not say that, a reader
        # will "verify" with `furrow ls`, see it answer, and dismiss the warning.
        r = run_with(emitting(READ_ONLY))
        self.assertIn("READ", r.stdout)

    def test_outdated_offers_both_remedies_without_choosing(self) -> None:
        # A flag day's ordering is the human's call, so the hook must not tell
        # anyone to run `furrow upgrade` as if it were the obvious fix.
        r = run_with(emitting(READ_ONLY))
        self.assertIn("checkout", r.stdout)
        self.assertIn("upgrade", r.stdout)

    def test_too_new_points_at_the_binary_instead(self) -> None:
        r = run_with(emitting(TOO_NEW))
        self.assertIn("pull", r.stdout)
        self.assertNotIn("upgrade", r.stdout)


if __name__ == "__main__":
    unittest.main()
