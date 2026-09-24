"""claude-quota-note SessionStart hook のテスト。

実 ~/.claude.json を読ませず、CLAUDE_QUOTA_FILE で fixture を注入して
出力 1 行の形と fail-open を固定する。時計は CLAUDE_QUOTA_NOW で注入する。
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any

SCRIPT = (
    Path(__file__).resolve().parent.parent
    / "chezmoi"
    / "dot_local"
    / "bin"
    / "executable_claude-quota-note"
)

# 2026-09-24T08:00:00Z — a fixed "now" so the age arithmetic is exact.
NOW = 1_790_236_800
HOUR = 3600
DAY = 24 * HOUR


def run_hook(payload: object | str | None, *, now: int | str | None = None) -> str:
    with tempfile.TemporaryDirectory() as d:
        env = {"HOME": d, "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}
        if payload is not None:
            f = Path(d) / "claude.json"
            f.write_text(
                payload if isinstance(payload, str) else json.dumps(payload),
                encoding="utf-8",
            )
            env["CLAUDE_QUOTA_FILE"] = str(f)
        if now is not None:
            env["CLAUDE_QUOTA_NOW"] = str(now)
        proc = subprocess.run(
            ["bash", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
            check=True,  # fail-open 契約: どの入力でも exit 0
        )
        return proc.stdout


def fixture(
    weekly: float,
    fable: float,
    *,
    resets_at: str | None = None,
    fetched_ms: int | None = None,
) -> dict[str, object]:
    weekly_all: dict[str, Any] = {"kind": "weekly_all", "percent": weekly}
    fable_scoped: dict[str, Any] = {
        "kind": "weekly_scoped",
        "percent": fable,
        "scope": {"model": {"display_name": "Fable"}},
    }
    if resets_at is not None:
        weekly_all["resets_at"] = resets_at
        fable_scoped["resets_at"] = resets_at
    cache: dict[str, Any] = {"utilization": {"limits": [weekly_all, fable_scoped]}}
    if fetched_ms is not None:
        cache["fetchedAtMs"] = fetched_ms
    return {"cachedUsageUtilization": cache}


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


class QuotaNoteFreshness(unittest.TestCase):
    """The cache is what Claude Code saw at its last usage fetch, not a live
    read. Past the window's resets_at the numbers are last week's by
    definition — the 2026-09-24 misroute (t-kk92) read a 7-day-old
    "Fable 100%" as current."""

    def test_past_window_reset_is_stale_not_numbers(self) -> None:
        out = run_hook(
            fixture(
                weekly=99,
                fable=100,
                resets_at="2026-09-19T21:59:59.669466+00:00",
                fetched_ms=1_789_604_112_762,  # 2026-09-17T00:15:12Z
            ),
            now=NOW,
        )
        self.assertIn("quota: stale", out)
        self.assertIn("reset 2026-09-19T21:59:59Z", out)
        self.assertIn("fetched 2026-09-17T00:15:12Z", out)
        self.assertIn("run /usage", out)
        self.assertNotIn("Weekly", out)
        self.assertNotIn("100%", out)

    def test_inside_window_carries_fetch_age_in_hours(self) -> None:
        out = run_hook(
            fixture(
                weekly=62,
                fable=48,
                resets_at="2026-09-26T21:59:59.000000+00:00",
                fetched_ms=(NOW - 3 * HOUR) * 1000,
            ),
            now=NOW,
        )
        self.assertIn("quota: Weekly 62% / Fable 48% (fetched 3h ago)", out)
        self.assertIn("Fable 遅行", out)
        self.assertNotIn("stale", out)

    def test_inside_window_age_switches_to_days_at_48h(self) -> None:
        out = run_hook(
            fixture(
                weekly=40,
                fable=55,
                resets_at="2026-09-26T21:59:59.000000+00:00",
                fetched_ms=(NOW - 5 * DAY) * 1000,
            ),
            now=NOW,
        )
        self.assertIn("quota: Weekly 40% / Fable 55% (fetched 5d ago)", out)

    def test_unparseable_reset_falls_open_to_numbers(self) -> None:
        out = run_hook(
            fixture(weekly=62, fable=48, resets_at="soon", fetched_ms=NOW * 1000),
            now=NOW,
        )
        self.assertIn("quota: Weekly 62% / Fable 48% (fetched 0h ago)", out)
        self.assertNotIn("stale", out)

    def test_no_freshness_fields_prints_numbers_unchanged(self) -> None:
        out = run_hook(fixture(weekly=62, fable=48), now=NOW)
        self.assertEqual(
            out,
            "quota: Weekly 62% / Fable 48%"
            " — Fable 遅行（不変条件 Fable% ≥ Weekly% 割れ・委譲の敷居を下げる）\n",
        )

    def test_garbage_clock_is_silent(self) -> None:
        self.assertEqual(run_hook(fixture(weekly=62, fable=48), now="abc"), "")


if __name__ == "__main__":
    unittest.main()
