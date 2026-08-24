#!/usr/bin/env python3
"""Tests for the pure parts of the harness.

The parts that call a model are not tested here; the parts that can silently
skew a result are. A/B order and the release gate are the two places where a
quiet mistake turns into a wrong conclusion rather than a visible error.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import judge
import run

HERE = Path(__file__).resolve().parent


class TestOrder(unittest.TestCase):
    def test_deterministic(self) -> None:
        self.assertEqual(judge.order_for("x", 1), judge.order_for("x", 1))

    def test_both_conditions_present(self) -> None:
        for case_id in ("a", "b", "c", "d"):
            self.assertEqual(
                set(judge.order_for(case_id, 1)), {"baseline", "candidate"}
            )

    def test_not_always_the_same_side(self) -> None:
        """A fixed order would let the judge learn position instead of quality."""
        firsts = {judge.order_for(f"case{i}", t)[0] for i in range(20) for t in (1, 2)}
        self.assertEqual(firsts, {"baseline", "candidate"})


class TestMetrics(unittest.TestCase):
    def test_counts_bullets_and_headers(self) -> None:
        m = judge.metrics("# H\n\n- one\n- two\n1. three\n")
        self.assertEqual(m["headers"], 1)
        self.assertEqual(m["bullets"], 3)

    def test_hyphen_in_prose_is_not_a_bullet(self) -> None:
        self.assertEqual(judge.metrics("a-b は -1 になる")["bullets"], 0)

    def test_named_and_unnamed_filler_are_separate(self) -> None:
        m = judge.metrics("良い質問ですね。\nまず確認します。")
        self.assertEqual(m["named_filler"], 1)
        self.assertEqual(m["unnamed_filler"], 1)

    def test_first_line_skips_leading_blanks(self) -> None:
        self.assertEqual(judge.metrics("\n\nabc\nlonger line")["first_line_chars"], 3)


class TestFireCounts(unittest.TestCase):
    CASES = {"close": {"fire_regex": "品質担保できる範囲まで"}, "plain": {}}

    def test_counts_per_condition(self) -> None:
        rows = [
            {
                "case_id": "close",
                "condition": "candidate",
                "response": "品質担保できる範囲まで作業続けました。",
            },
            {
                "case_id": "close",
                "condition": "candidate",
                "response": "終わりました。",
            },
            {"case_id": "close", "condition": "baseline", "response": "終わりました。"},
        ]
        f = judge.fire_counts(rows, self.CASES)
        self.assertEqual(f[("close", "candidate")], (1, 2))
        self.assertEqual(f[("close", "baseline")], (0, 1))

    def test_cases_without_fire_regex_are_absent(self) -> None:
        rows = [{"case_id": "plain", "condition": "baseline", "response": "x"}]
        self.assertEqual(judge.fire_counts(rows, self.CASES), {})


def v(winner: str | None, cut: bool = False) -> dict[str, object]:
    return {"winner": winner, "lost_correctness": cut, "lost_safety": False}


class TestGate(unittest.TestCase):
    def test_passes_on_a_clean_win(self) -> None:
        passed, reasons = judge.gate([v("candidate")] * 8 + [v("baseline")] * 2)
        self.assertTrue(passed, reasons)

    def test_blocks_when_baseline_ties_or_wins(self) -> None:
        passed, reasons = judge.gate([v("candidate")] * 5 + [v("baseline")] * 5)
        self.assertFalse(passed)
        self.assertIn("did not beat baseline", " ".join(reasons))

    def test_blocks_a_win_bought_by_cutting_content(self) -> None:
        passed, reasons = judge.gate(
            [v("candidate", cut=True)] * 4 + [v("candidate")] * 6
        )
        self.assertFalse(passed)
        self.assertIn("cutting needed content", " ".join(reasons))

    def test_baseline_side_cuts_do_not_count_against_the_candidate(self) -> None:
        passed, _ = judge.gate([v("baseline", cut=True)] * 2 + [v("candidate")] * 8)
        self.assertTrue(passed)

    def test_blocks_when_a_pair_failed_to_judge(self) -> None:
        passed, reasons = judge.gate([v("candidate")] * 9 + [{"winner": None}])
        self.assertFalse(passed)
        self.assertIn("failed to judge", " ".join(reasons))


class TestTwoArmGate(unittest.TestCase):
    """With two file-backed arms both sides cut, so only the excess counts.

    Measured once (PR #274 old vs new, 30 pairs): baseline 8 cut-wins,
    candidate 11. The one-arm rate blocks that; the candidate is not worse
    than what it replaces.
    """

    def test_the_observed_run_passes_two_arm_but_blocks_one_arm(self) -> None:
        verdicts = (
            [v("candidate", cut=True)] * 11
            + [v("candidate")] * 6
            + [v("baseline", cut=True)] * 8
            + [v("baseline")] * 5
        )
        self.assertFalse(judge.gate(verdicts)[0])
        self.assertTrue(judge.gate(verdicts, two_arm=True)[0])

    def test_blocks_when_the_candidate_cuts_far_more_than_the_baseline(self) -> None:
        passed, reasons = judge.gate(
            [v("candidate", cut=True)] * 6 + [v("candidate")] * 2 + [v("baseline")] * 2,
            two_arm=True,
        )
        self.assertFalse(passed)
        self.assertIn("excess", " ".join(reasons))

    def test_baseline_cutting_more_never_blocks(self) -> None:
        passed, _ = judge.gate(
            [v("candidate")] * 6 + [v("baseline", cut=True)] * 4, two_arm=True
        )
        self.assertTrue(passed)

    def test_the_win_count_check_still_applies(self) -> None:
        passed, reasons = judge.gate([v("candidate")] * 5 + [v("baseline")] * 5, True)
        self.assertFalse(passed)
        self.assertIn("did not beat baseline", " ".join(reasons))

    def test_the_threshold_is_a_parameter_not_a_constant(self) -> None:
        verdicts = [v("candidate", cut=True)] * 3 + [v("candidate")] * 7
        self.assertTrue(judge.gate(verdicts, two_arm=True, cut_delta=0.5)[0])
        self.assertFalse(judge.gate(verdicts, two_arm=True, cut_delta=0.1)[0])


class TestNeutralGate(unittest.TestCase):
    """expect="neutral" refuses harm instead of demanding a win.

    Motivated by a measured structural block (2026-08-24, 44 pairs): a
    conversation-neutral consolidation tied 18:18 in the gated frame, which
    "must beat baseline" can never pass, while its whole effect lived in
    observation cases.
    """

    def test_a_tie_passes_neutral_but_blocks_improve(self) -> None:
        verdicts = [v("candidate")] * 5 + [v("baseline")] * 5
        self.assertFalse(judge.gate(verdicts, two_arm=True)[0])
        self.assertTrue(judge.gate(verdicts, two_arm=True, expect="neutral")[0])

    def test_a_loss_beyond_the_bound_blocks(self) -> None:
        passed, reasons = judge.gate(
            [v("candidate")] * 4 + [v("baseline")] * 6,
            two_arm=True,
            expect="neutral",
        )
        self.assertFalse(passed)
        self.assertIn("neutral bound", " ".join(reasons))

    def test_a_small_loss_within_the_bound_passes(self) -> None:
        passed, _ = judge.gate(
            [v("candidate")] * 10 + [v("baseline")] * 11,
            two_arm=True,
            expect="neutral",
        )
        self.assertTrue(passed)

    def test_the_cut_delta_still_applies_in_neutral(self) -> None:
        passed, reasons = judge.gate(
            [v("candidate", cut=True)] * 5 + [v("baseline")] * 5,
            two_arm=True,
            expect="neutral",
        )
        self.assertFalse(passed)
        self.assertIn("excess", " ".join(reasons))

    def test_the_loss_bound_is_a_parameter(self) -> None:
        verdicts = [v("candidate")] * 3 + [v("baseline")] * 7
        self.assertTrue(
            judge.gate(verdicts, two_arm=True, expect="neutral", loss_delta=0.5)[0]
        )
        self.assertFalse(
            judge.gate(verdicts, two_arm=True, expect="neutral", loss_delta=0.1)[0]
        )


class TestSplitGated(unittest.TestCase):
    """Observation cases are judged and reported but never gated.

    Cut flags attach only to winners, so a case subset the candidate is
    supposed to win inflates its cut count mechanically (measured 2026-08-24:
    +62% excess in the dev subset vs +3% in the conversational frame).
    """

    CASES = {
        "conv": {},
        "obs": {"gate": False},
        "explicit": {"gate": True},
    }

    def test_gate_defaults_to_true(self) -> None:
        gated, observed = judge.split_gated(
            [{"case_id": "conv"}, {"case_id": "explicit"}], self.CASES
        )
        self.assertEqual(len(gated), 2)
        self.assertEqual(observed, [])

    def test_observation_cases_are_split_out(self) -> None:
        gated, observed = judge.split_gated(
            [{"case_id": "conv"}, {"case_id": "obs"}], self.CASES
        )
        self.assertEqual([r["case_id"] for r in gated], ["conv"])
        self.assertEqual([r["case_id"] for r in observed], ["obs"])

    def test_an_unknown_case_id_stays_gated(self) -> None:
        gated, observed = judge.split_gated([{"case_id": "ghost"}], self.CASES)
        self.assertEqual(len(gated), 1)
        self.assertEqual(observed, [])


class TestResolveMode(unittest.TestCase):
    """Guessing one-arm for an unlabelled two-arm run is the silent failure."""

    def test_file_rows_select_the_two_arm_gate(self) -> None:
        two_arm, warning = judge.resolve_mode([{"baseline_mode": "file"}] * 4)
        self.assertTrue(two_arm)
        self.assertIsNone(warning)

    def test_none_rows_select_the_one_arm_gate(self) -> None:
        two_arm, warning = judge.resolve_mode([{"baseline_mode": "none"}] * 4)
        self.assertFalse(two_arm)
        self.assertIsNone(warning)

    def test_rows_predating_the_field_warn_instead_of_assuming(self) -> None:
        two_arm, warning = judge.resolve_mode([{"case_id": "x"}] * 4)
        self.assertFalse(two_arm)
        self.assertIsNotNone(warning)

    def test_a_mixed_file_makes_itself_heard(self) -> None:
        two_arm, warning = judge.resolve_mode(
            [{"baseline_mode": "file"}, {"baseline_mode": "none"}]
        )
        self.assertTrue(two_arm)
        assert warning is not None
        self.assertIn("mixed", warning)


class TestBaselineModeIsRecorded(unittest.TestCase):
    """judge.py cannot pick a gate from arms_key — it is only a hash."""

    def test_a_bare_baseline_is_labelled_none(self) -> None:
        self.assertEqual(
            run.baseline_mode({"baseline": None, "candidate": "NEW"}), "none"
        )

    def test_a_file_backed_baseline_is_labelled_file(self) -> None:
        self.assertEqual(
            run.baseline_mode({"baseline": "OLD", "candidate": "NEW"}), "file"
        )


class TestIsolation(unittest.TestCase):
    def test_baseline_gets_no_section(self) -> None:
        self.assertNotIn("--append-system-prompt", run.build_cmd("m", None))

    def test_candidate_gets_the_section(self) -> None:
        cmd = run.build_cmd("m", "RULES")
        self.assertIn("--append-system-prompt", cmd)
        self.assertTrue(cmd[cmd.index("--append-system-prompt") + 1].endswith("RULES"))

    def test_operator_settings_are_excluded_from_both_arms(self) -> None:
        """Without this the baseline would already contain the rules under test.

        Covers the --baseline arm too: a file-backed baseline still goes
        through build_cmd, and losing the isolation on that side would make
        every A/B-of-two-revisions run meaningless in the same way.
        """
        for section in (None, "OLD RULES", "RULES"):
            cmd = run.build_cmd("m", section)
            self.assertEqual(cmd[cmd.index("--setting-sources") + 1], "")
            self.assertEqual(cmd[cmd.index("--tools") + 1], "")
            self.assertIn("--system-prompt", cmd)


class TestBaselineArm(unittest.TestCase):
    """--baseline turns the harness into an A/B of two revisions.

    Without it the baseline arm is always "no section", so an edit that neither
    adds nor removes content — reordering, splitting a bullet, spelling out
    precedence — has no measurable contrast.
    """

    def test_a_file_backed_baseline_is_appended_like_the_candidate(self) -> None:
        cmd = run.build_cmd("m", "OLD")
        self.assertIn("--append-system-prompt", cmd)
        self.assertTrue(cmd[cmd.index("--append-system-prompt") + 1].endswith("OLD"))

    def test_the_two_arms_carry_different_text(self) -> None:
        arms = {"baseline": "OLD", "candidate": "NEW"}
        appended = {
            cond: run.build_cmd("m", arms[cond])[
                run.build_cmd("m", arms[cond]).index("--append-system-prompt") + 1
            ]
            for cond in arms
        }
        self.assertNotEqual(appended["baseline"], appended["candidate"])


class TestArmsKey(unittest.TestCase):
    """Guards the resume path: reusing --out across different arms would
    recycle responses from a comparison nobody ran."""

    def test_same_arms_same_key(self) -> None:
        a = {"baseline": None, "candidate": "X"}
        self.assertEqual(run.arms_key("m", a), run.arms_key("m", dict(a)))

    def test_changing_the_baseline_changes_the_key(self) -> None:
        no_file = {"baseline": None, "candidate": "X"}
        with_file = {"baseline": "OLD", "candidate": "X"}
        self.assertNotEqual(run.arms_key("m", no_file), run.arms_key("m", with_file))

    def test_changing_the_model_changes_the_key(self) -> None:
        a = {"baseline": None, "candidate": "X"}
        self.assertNotEqual(run.arms_key("m1", a), run.arms_key("m2", a))

    def test_the_arms_are_not_interchangeable(self) -> None:
        """Swapping which side is which is a different experiment."""
        self.assertNotEqual(
            run.arms_key("m", {"baseline": "A", "candidate": "B"}),
            run.arms_key("m", {"baseline": "B", "candidate": "A"}),
        )


class TestResume(unittest.TestCase):
    KEY = "deadbeefdeadbeef"

    def write(self, rows: list[dict[str, object]]) -> Path:
        d = Path(tempfile.mkdtemp())
        p = d / "responses.jsonl"
        p.write_text("".join(json.dumps(r) + "\n" for r in rows))
        return p

    def row(self, **kw: object) -> dict[str, object]:
        base: dict[str, object] = {
            "case_id": "c",
            "condition": "baseline",
            "trial": 1,
            "response": "text",
            "arms_key": self.KEY,
        }
        base.update(kw)
        return base

    def test_matching_rows_are_resumable(self) -> None:
        done, foreign = run.completed(self.write([self.row()]), self.KEY)
        self.assertEqual(done, {("c", "baseline", 1)})
        self.assertEqual(foreign, set())

    def test_rows_from_another_comparison_are_reported_not_reused(self) -> None:
        done, foreign = run.completed(
            self.write([self.row(arms_key="other")]), self.KEY
        )
        self.assertEqual(done, set())
        self.assertEqual(foreign, {"other"})

    def test_unlabelled_rows_are_treated_as_foreign(self) -> None:
        """Files written before arms_key existed could hold any pair of arms."""
        row = self.row()
        del row["arms_key"]
        done, foreign = run.completed(self.write([row]), self.KEY)
        self.assertEqual(done, set())
        self.assertTrue(foreign)

    def test_failed_rows_are_retried_not_skipped(self) -> None:
        done, foreign = run.completed(self.write([self.row(response=None)]), self.KEY)
        self.assertEqual(done, set())
        self.assertEqual(foreign, set())

    def test_a_missing_file_is_not_an_error(self) -> None:
        self.assertEqual(
            run.completed(Path("/nonexistent/x.jsonl"), self.KEY), (set(), set())
        )

    def test_model_is_pinned_into_the_command(self) -> None:
        self.assertEqual(
            run.build_cmd("pinned-model", None)[
                run.build_cmd("pinned-model", None).index("--model") + 1
            ],
            "pinned-model",
        )


class TestCases(unittest.TestCase):
    def setUp(self) -> None:
        self.cases = json.loads((HERE / "cases.json").read_text())

    def test_ids_are_unique(self) -> None:
        ids = [c["id"] for c in self.cases]
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_case_has_a_prompt(self) -> None:
        for c in self.cases:
            self.assertTrue(c.get("prompt", "").strip(), c["id"])

    def test_fire_regex_is_not_in_its_own_prompt(self) -> None:
        """A prompt containing the marker would let either arm echo it back,
        and the fire count would measure the prompt instead of the section."""
        for c in self.cases:
            if "fire_regex" in c:
                self.assertNotRegex(c["prompt"], c["fire_regex"], c["id"])


class ExitCodes(unittest.TestCase):
    """A blocked gate and a mistyped flag must not look the same to a caller.

    Both used to exit 2. The gate now exits 3; argparse keeps 2.
    """

    def test_a_usage_error_still_exits_two(self) -> None:
        p = subprocess.run(
            [sys.executable, str(HERE / "judge.py"), "--no-such-flag"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(p.returncode, 2, p.stderr)
        self.assertIn("unrecognized arguments", p.stderr)

    def test_the_blocked_code_is_documented_as_three(self) -> None:
        # 実際に BLOCKED を出すには judge の run が要るので、契約の側を固定する:
        # main() の戻り値と README の記述が 3 で揃っていること。
        source = (HERE / "judge.py").read_text(encoding="utf-8")
        self.assertIn("return 0 if passed else 3", source)
        self.assertIn("exit 3", (HERE / "README.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
