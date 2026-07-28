"""claude-quota-note SessionStart hook のテスト。

実 ~/.claude.json を読ませず、CLAUDE_QUOTA_FILE で fixture を注入して
出力 1 行の形と fail-open を固定する。
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parent.parent
    / "chezmoi"
    / "dot_local"
    / "bin"
    / "executable_claude-quota-note"
)


def run_hook(payload: object | str | None) -> str:
    with tempfile.TemporaryDirectory() as d:
        env = {"HOME": d, "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}
        if payload is not None:
            f = Path(d) / "claude.json"
            f.write_text(
                payload if isinstance(payload, str) else json.dumps(payload),
                encoding="utf-8",
            )
            env["CLAUDE_QUOTA_FILE"] = str(f)
        proc = subprocess.run(
            ["bash", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
            check=True,  # fail-open 契約: どの入力でも exit 0
        )
        return proc.stdout


def fixture(weekly: float, fable: float) -> dict[str, object]:
    return {
        "cachedUsageUtilization": {
            "utilization": {
                "limits": [
                    {"kind": "weekly_all", "percent": weekly},
                    {
                        "kind": "weekly_scoped",
                        "percent": fable,
                        "scope": {"model": {"display_name": "Fable"}},
                    },
                ]
            }
        }
    }


class QuotaNote(unittest.TestCase):
    def test_fable_behind_warns(self) -> None:
        out = run_hook(fixture(weekly=62, fable=48))
        self.assertIn("quota: Weekly 62% / Fable 48%", out)
        self.assertIn("Fable 遅行", out)

    def test_invariant_holding_notes_target(self) -> None:
        out = run_hook(fixture(weekly=40, fable=55))
        self.assertIn("quota: Weekly 40% / Fable 55%", out)
        self.assertIn("不変条件充足", out)

    def test_missing_file_is_silent(self) -> None:
        self.assertEqual(run_hook(None), "")

    def test_unexpected_schema_is_silent(self) -> None:
        self.assertEqual(run_hook({"cachedUsageUtilization": {}}), "")

    def test_broken_json_is_silent(self) -> None:
        self.assertEqual(run_hook("not-json{{"), "")


if __name__ == "__main__":
    unittest.main()
