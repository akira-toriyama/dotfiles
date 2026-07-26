#!/usr/bin/env python3
"""Tests for the pure parts of the harness.

The parts that call a model are not tested here; the parts that can silently
skew a result are. A/B order and the release gate are the two places where a
quiet mistake turns into a wrong conclusion rather than a visible error.
"""
import json
import unittest
from pathlib import Path

import judge
import run

HERE = Path(__file__).resolve().parent


class TestOrder(unittest.TestCase):
    def test_deterministic(self):
        self.assertEqual(judge.order_for("x", 1), judge.order_for("x", 1))

    def test_both_conditions_present(self):
        for case_id in ("a", "b", "c", "d"):
            self.assertEqual(set(judge.order_for(case_id, 1)), {"baseline", "candidate"})

    def test_not_always_the_same_side(self):
        """A fixed order would let the judge learn position instead of quality."""
        firsts = {judge.order_for(f"case{i}", t)[0] for i in range(20) for t in (1, 2)}
        self.assertEqual(firsts, {"baseline", "candidate"})


class TestMetrics(unittest.TestCase):
    def test_counts_bullets_and_headers(self):
        m = judge.metrics("# H\n\n- one\n- two\n1. three\n")
        self.assertEqual(m["headers"], 1)
        self.assertEqual(m["bullets"], 3)

    def test_hyphen_in_prose_is_not_a_bullet(self):
        self.assertEqual(judge.metrics("a-b は -1 になる")["bullets"], 0)

    def test_named_and_unnamed_filler_are_separate(self):
        m = judge.metrics("良い質問ですね。\nまず確認します。")
        self.assertEqual(m["named_filler"], 1)
        self.assertEqual(m["unnamed_filler"], 1)

    def test_first_line_skips_leading_blanks(self):
        self.assertEqual(judge.metrics("\n\nabc\nlonger line")["first_line_chars"], 3)


def v(winner, cut=False):
    return {"winner": winner, "lost_correctness": cut, "lost_safety": False}


class TestGate(unittest.TestCase):
    def test_passes_on_a_clean_win(self):
        passed, reasons = judge.gate([v("candidate")] * 8 + [v("baseline")] * 2)
        self.assertTrue(passed, reasons)

    def test_blocks_when_baseline_ties_or_wins(self):
        passed, reasons = judge.gate([v("candidate")] * 5 + [v("baseline")] * 5)
        self.assertFalse(passed)
        self.assertIn("did not beat baseline", " ".join(reasons))

    def test_blocks_a_win_bought_by_cutting_content(self):
        passed, reasons = judge.gate([v("candidate", cut=True)] * 4 + [v("candidate")] * 6)
        self.assertFalse(passed)
        self.assertIn("cutting needed content", " ".join(reasons))

    def test_baseline_side_cuts_do_not_count_against_the_candidate(self):
        passed, _ = judge.gate([v("baseline", cut=True)] * 2 + [v("candidate")] * 8)
        self.assertTrue(passed)

    def test_blocks_when_a_pair_failed_to_judge(self):
        passed, reasons = judge.gate([v("candidate")] * 9 + [{"winner": None}])
        self.assertFalse(passed)
        self.assertIn("failed to judge", " ".join(reasons))


class TestIsolation(unittest.TestCase):
    def test_baseline_gets_no_section(self):
        self.assertNotIn("--append-system-prompt", run.build_cmd("m", None))

    def test_candidate_gets_the_section(self):
        cmd = run.build_cmd("m", "RULES")
        self.assertIn("--append-system-prompt", cmd)
        self.assertTrue(cmd[cmd.index("--append-system-prompt") + 1].endswith("RULES"))

    def test_operator_settings_are_excluded_from_both_arms(self):
        """Without this the baseline would already contain the rules under test."""
        for section in (None, "RULES"):
            cmd = run.build_cmd("m", section)
            self.assertEqual(cmd[cmd.index("--setting-sources") + 1], "")

    def test_model_is_pinned_into_the_command(self):
        self.assertEqual(run.build_cmd("pinned-model", None)[
            run.build_cmd("pinned-model", None).index("--model") + 1], "pinned-model")


class TestCases(unittest.TestCase):
    def setUp(self):
        self.cases = json.loads((HERE / "cases.json").read_text())

    def test_ids_are_unique(self):
        ids = [c["id"] for c in self.cases]
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_case_has_a_prompt(self):
        for c in self.cases:
            self.assertTrue(c.get("prompt", "").strip(), c["id"])


if __name__ == "__main__":
    unittest.main()
