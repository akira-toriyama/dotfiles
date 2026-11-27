"""Fixture tests for furrow-epic-table.

What is pinned:
  1. the table: header, one row per box in furrow's order, ▶ on the active
     box, done/total, the icebox members counted per box (an unfiled icebox
     task counts nowhere), （常設） on a standing box, `|` in a title escaped
  2. -r reaches both furrow reads verbatim, '' included; no -r, no scope
  3. a failing furrow read → exit 1, no table, furrow's stderr passed on;
     furrow missing → exit 1 with a message, not a traceback

furrow is a stub first on PATH: the real one would read this machine's board.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_furrow-epic-table"

# Logs each call's argv as [a][b]… so an empty argument stays visible.
STUB = """#!/bin/sh
for a in "$@"; do printf '[%s]' "$a"; done >>"$STUB_LOG"
echo >>"$STUB_LOG"
if [ "${STUB_FAIL:-}" = "$1" ]; then
  echo '{"error":{"kind":"validation","message":"stub refused"}}' >&2
  echo '[]'
  exit 2
fi
case $1 in
epic) cat "$STUB_DIR/epics.json" ;;
*) cat "$STUB_DIR/icebox.json" ;;
esac
"""

EPICS = [
    {
        "id": "e-zz01",
        "title": "新 Mac 再現",
        "active": True,
        "standing": False,
        "progress": {"done": 3, "total": 5},
    },
    {
        "id": "e-aa02",
        "title": "a | b",
        "active": False,
        "standing": False,
        "progress": {"done": 0, "total": 2},
    },
    {
        "id": "e-mm03",
        "title": "requests",
        "active": False,
        "standing": True,
        "progress": {"done": 42, "total": 43},
    },
]
ICEBOX = [
    {"id": "t-0001", "epic": "e-zz01", "status": "icebox"},
    {"id": "t-0002", "epic": "e-mm03", "status": "icebox"},
    {"id": "t-0003", "epic": None, "status": "icebox"},
    {"id": "t-0004", "epic": "e-zz01", "status": "icebox"},
]
TABLE = """\
| | id | 進捗 | icebox | タイトル |
|---|---|---|---|---|
| ▶ | e-zz01 | 3/5 | 2 | 新 Mac 再現 |
| | e-aa02 | 0/2 | 0 | a \\| b |
| | e-mm03 | 42/43 | 1 | requests（常設） |
"""


class StubbedFurrow(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        stub = self.dir / "furrow"
        stub.write_text(STUB)
        stub.chmod(0o755)
        for name, rows in (("epics.json", EPICS), ("icebox.json", ICEBOX)):
            (self.dir / name).write_text(
                json.dumps(rows, ensure_ascii=False), encoding="utf-8"
            )
        self.log = self.dir / "calls.log"

    def run_table(
        self, *args: str, fail: str = "", path: str | None = None
    ) -> subprocess.CompletedProcess[str]:
        env = {
            "PATH": path or os.pathsep.join([str(self.dir), "/usr/bin", "/bin"]),
            "STUB_DIR": str(self.dir),
            "STUB_LOG": str(self.log),
            "STUB_FAIL": fail,
        }
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            capture_output=True,
            encoding="utf-8",
            check=False,
            env=env,
        )

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []


class Table(StubbedFurrow):
    def test_the_sample_board_prints_the_table(self) -> None:
        p = self.run_table()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, TABLE)


class Scope(StubbedFurrow):
    def test_r_reaches_both_reads_verbatim(self) -> None:
        cases = {
            (): ["[epic][ls][--json]", "[ls][-s][icebox][--json]"],
            ("-r", "akira-toriyama/dotfiles"): [
                "[epic][ls][--json][-r][akira-toriyama/dotfiles]",
                "[ls][-s][icebox][--json][-r][akira-toriyama/dotfiles]",
            ],
            ("-r", ""): [
                "[epic][ls][--json][-r][]",
                "[ls][-s][icebox][--json][-r][]",
            ],
        }
        for args, want in cases.items():
            with self.subTest(args=args):
                self.log.unlink(missing_ok=True)
                p = self.run_table(*args)
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(self.calls(), want)


class Failure(StubbedFurrow):
    def test_a_failing_read_exits_1_with_furrow_stderr(self) -> None:
        # The stub prints [] before failing: the exit status decides, not stdout.
        for read in ("epic", "ls"):
            with self.subTest(failing=read):
                p = self.run_table(fail=read)
                self.assertEqual(p.returncode, 1)
                self.assertEqual(p.stdout, "")
                self.assertIn("stub refused", p.stderr)

    def test_a_missing_furrow_exits_1_without_a_traceback(self) -> None:
        empty = self.dir / "empty"
        empty.mkdir()
        p = self.run_table(path=os.pathsep.join([str(empty), "/usr/bin", "/bin"]))
        self.assertEqual(p.returncode, 1)
        self.assertEqual(p.stdout, "")
        self.assertIn("furrow", p.stderr)
        self.assertNotIn("Traceback", p.stderr)


if __name__ == "__main__":
    unittest.main()
