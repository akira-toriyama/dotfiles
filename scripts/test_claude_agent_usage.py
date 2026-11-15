"""claude-agent-usage のテスト。

実 ~/.claude/projects を読ませず、CLAUDE_PROJECTS_DIR に fixture の木を注入して、
1 応答 = 1 turn の重複排除・並び順・TOTAL 行・session の自動選択・exit 2 を固定する。
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parent.parent
    / "chezmoi"
    / "dot_local"
    / "bin"
    / "executable_claude-agent-usage"
)

HEADER = "label\tmodel\tturns\tread\toutput\tmax_ctx\tminutes"


def assistant(
    mid: str, ts: str, *, inp: int, read: int, create: int, out: int
) -> dict[str, object]:
    return {
        "type": "assistant",
        "timestamp": ts,
        "message": {
            "id": mid,
            "model": "model-a",
            "usage": {
                "input_tokens": inp,
                "cache_read_input_tokens": read,
                "cache_creation_input_tokens": create,
                "output_tokens": out,
            },
        },
    }


def write_jsonl(path: Path, rows: list[dict[str, object] | str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join((r if isinstance(r, str) else json.dumps(r)) + "\n" for r in rows),
        encoding="utf-8",
    )


def project_dir(projects: Path, cwd: Path) -> Path:
    return projects / re.sub(r"[^A-Za-z0-9]", "-", str(cwd.resolve()))


def run(projects: Path, cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(SCRIPT), *args],
        cwd=cwd,
        env={**os.environ, "CLAUDE_PROJECTS_DIR": str(projects)},
        capture_output=True,
        text=True,
        check=False,
    )


class AgentUsageTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        self.projects = root / "projects"
        self.cwd = root / "work.tree"
        self.cwd.mkdir()
        self.session = project_dir(self.projects, self.cwd) / "session-1"

        # main loop: one response logged as two content blocks (same id).
        write_jsonl(
            Path(f"{self.session}.jsonl"),
            [
                {"type": "user", "timestamp": "2026-11-15T01:00:00.000Z"},
                assistant(
                    "m1", "2026-11-15T01:00:10.500Z", inp=10, read=90, create=0, out=5
                ),
                assistant(
                    "m1", "2026-11-15T01:00:11.000Z", inp=10, read=90, create=0, out=5
                ),
            ],
        )
        # An Agent-tool subagent, labelled by its meta description.
        sub = self.session / "subagents"
        write_jsonl(
            sub / "agent-a1.jsonl",
            [
                assistant(
                    "a1", "2026-11-15T01:00:00.000Z", inp=1, read=200, create=99, out=7
                ),
                "not json at all",
                assistant(
                    "a2", "2026-11-15T01:30:00.000Z", inp=1, read=600, create=99, out=3
                ),
            ],
        )
        (sub / "agent-a1.meta.json").write_text(
            json.dumps({"description": "review:unit"}), encoding="utf-8"
        )
        # A workflow agent with no meta file: labelled by its file name.
        write_jsonl(
            sub / "workflows" / "wf_1" / "agent-b1.jsonl",
            [assistant("b1", "2026-11-15T02:00:00Z", inp=0, read=40, create=0, out=1)],
        )
        # A transcript with no API response contributes no row.
        write_jsonl(sub / "agent-empty.jsonl", [{"type": "user"}])

    def table(self, *args: str) -> list[list[str]]:
        p = run(self.projects, self.cwd, *args)
        self.assertEqual(p.returncode, 0, p.stderr)
        lines = p.stdout.splitlines()
        self.assertEqual(lines[0], HEADER)
        return [line.split("\t") for line in lines[1:]]

    def test_rows_are_per_agent_most_tokens_first_with_a_total(self) -> None:
        self.assertEqual(
            self.table(),
            [
                ["review:unit", "model-a", "2", "1000", "10", "700", "30"],
                ["main", "model-a", "1", "100", "5", "100", "0"],
                ["agent-b1", "model-a", "1", "40", "1", "40", "0"],
                ["TOTAL", "-", "4", "1140", "16", "700", "30"],
            ],
        )

    def test_an_explicit_session_directory_reads_the_same_table(self) -> None:
        self.assertEqual(self.table(str(self.session)), self.table())
        self.assertEqual(self.table(f"{self.session}/"), self.table())

    def test_the_default_is_the_session_whose_subagents_were_written_last(self) -> None:
        older = self.session.parent / "session-0"
        write_jsonl(
            older / "subagents" / "agent-old.jsonl",
            [assistant("o1", "2026-11-14T00:00:00Z", inp=0, read=9, create=0, out=1)],
        )
        os.utime(older / "subagents", (1, 1))
        self.assertEqual(self.table()[0][0], "review:unit")
        os.utime(older / "subagents", (4_000_000_000, 4_000_000_000))
        self.assertEqual(self.table()[0][0], "agent-old")

    def test_no_session_is_usage_not_an_empty_table(self) -> None:
        elsewhere = self.cwd.parent / "elsewhere"
        elsewhere.mkdir()
        p = run(self.projects, elsewhere)
        self.assertEqual(p.returncode, 2)
        self.assertEqual(p.stdout, "")
        self.assertIn("no session with subagents", p.stderr)

    def test_a_missing_directory_and_extra_arguments_are_usage(self) -> None:
        for args in ([str(self.session) + "-nope"], ["a", "b"]):
            p = run(self.projects, self.cwd, *args)
            self.assertEqual(p.returncode, 2, args)
            self.assertEqual(p.stdout, "")

    def test_a_session_with_no_api_response_is_refused(self) -> None:
        bare = self.session.parent / "session-bare"
        write_jsonl(bare / "subagents" / "agent-x.jsonl", [{"type": "user"}])
        p = run(self.projects, self.cwd, str(bare))
        self.assertEqual(p.returncode, 2)
        self.assertIn("no API response", p.stderr)


if __name__ == "__main__":
    unittest.main()
