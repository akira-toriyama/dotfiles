"""modify_settings.json の fixture テスト（t-vk0w）。

この script は `~/.claude/settings.json` を **毎 apply 作り直す**経路そのもので、
壊れたときに失うのが permission allowlist —— つまり Claude が確認なしに叩ける
コマンドの一覧。壊れ方が「落ちる」なら気づくが、「静かに削る」は気づけない。
なので、ここで固定するのは生成結果の細部ではなく **絶対に壊してはいけない性質**:

  1. 素通しの fail-safe: jq が無い / 入力が壊れている → stdin をそのまま返す
  2. 非破壊: 既存の allowlist・hook・未知キーを 1 つも失わない
  3. 冪等: 2 回通しても増えない（不動点）
  4. 上書きしない: 既に model / effortLevel があれば尊重する（jq の //=）
  5. $HOME はリテラル: 生成時に展開しない（hook 実行時に Claude が展開する）

PATH は jq だけを通す形に固定して走らせる。開発機の PATH には rundiff が居て
step 3 が動くが CI には居ないので、素の環境で走らせると手元と CI で別物を
テストすることになる。
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "private_dot_claude" / "modify_settings.json"

STALE_CHECK = "$HOME/.local/bin/git-stale-check"
WORK_REPORT = "$HOME/.local/bin/claude-work-report-check"
QUOTA_NOTE = "$HOME/.local/bin/claude-quota-note"
PJLINT_NOTE = "$HOME/.local/bin/claude-projects-lint-note"


def jq_only_path() -> str:
    """jq は通し rundiff は通さない PATH。手元と CI で同じ経路を踏ませる。"""
    jq = shutil.which("jq")
    if jq is None:  # pragma: no cover - devShell が供給する
        raise unittest.SkipTest("jq not on PATH")
    return os.pathsep.join([str(Path(jq).parent), "/usr/bin", "/bin"])


def run(stdin: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT)],
        input=stdin,
        capture_output=True,
        text=True,
        check=False,
        env={"PATH": jq_only_path(), "HOME": os.environ.get("HOME", "/tmp")},
    )


def commands(settings: dict[str, Any], event: str) -> list[str]:
    return [
        h.get("command")
        for entry in settings.get("hooks", {}).get(event, [])
        for h in entry.get("hooks", [])
    ]


class JqIsAvailable(unittest.TestCase):
    def test_jq_is_on_path(self) -> None:
        """jq が無いと下のテストは全部「素通し経路」だけを見て緑になる。
        欠けていることを黙って許すと、このファイルは何も守らなくなる。"""
        self.assertIsNotNone(
            shutil.which("jq"),
            "jq must be supplied by devShells.lint — without it these tests "
            "silently exercise only the pass-through branch",
        )


class FailSafe(unittest.TestCase):
    def test_unparseable_input_is_passed_through_verbatim(self) -> None:
        broken = '{"permissions": {"allow": ["Bash(ls:*)"'
        p = run(broken)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, broken, "a broken file must not be rewritten")

    def test_empty_input_becomes_a_valid_object(self) -> None:
        p = run("")
        self.assertEqual(p.returncode, 0, p.stderr)
        json.loads(p.stdout)


class NeverLoses(unittest.TestCase):
    def test_an_existing_allow_entry_survives(self) -> None:
        given = {"permissions": {"allow": ["Bash(rg:*)", "Read(//tmp/**)"]}}
        got = json.loads(run(json.dumps(given)).stdout)
        for entry in given["permissions"]["allow"]:
            self.assertIn(entry, got["permissions"]["allow"])

    def test_a_deny_list_is_untouched(self) -> None:
        given = {"permissions": {"deny": ["Bash(rm:*)"]}}
        got = json.loads(run(json.dumps(given)).stdout)
        self.assertEqual(got["permissions"]["deny"], ["Bash(rm:*)"])

    def test_unknown_keys_pass_through(self) -> None:
        given = {"statusLine": {"type": "command"}, "somethingNew": [1, 2]}
        got = json.loads(run(json.dumps(given)).stdout)
        self.assertEqual(got["statusLine"], given["statusLine"])
        self.assertEqual(got["somethingNew"], given["somethingNew"])

    def test_an_unrelated_hook_survives(self) -> None:
        given = {"hooks": {"SessionStart": [{"hooks": [{"command": "mine"}]}]}}
        got = json.loads(run(json.dumps(given)).stdout)
        self.assertIn("mine", commands(got, "SessionStart"))


class Seeds(unittest.TestCase):
    def test_it_adds_both_session_start_hooks_and_the_stop_hook(self) -> None:
        got = json.loads(run("{}").stdout)
        self.assertIn(STALE_CHECK, commands(got, "SessionStart"))
        self.assertIn(QUOTA_NOTE, commands(got, "SessionStart"))
        self.assertIn(PJLINT_NOTE, commands(got, "SessionStart"))
        self.assertIn(WORK_REPORT, commands(got, "Stop"))

    def test_home_stays_literal(self) -> None:
        """hook の command は Claude が実行時に展開する。生成時に展開すると
        別マシンへ配ったときに他人の $HOME が焼き込まれる。"""
        out = run("{}").stdout
        self.assertIn("$HOME/.local/bin/", out)
        home = os.environ.get("HOME", "")
        if home:
            self.assertNotIn(f"{home}/.local/bin/git-stale-check", out)

    def test_it_seeds_model_and_effort_when_absent(self) -> None:
        got = json.loads(run("{}").stdout)
        self.assertEqual(got["model"], "opus[1m]")
        self.assertEqual(got["effortLevel"], "xhigh")

    def test_it_does_not_override_an_existing_model_or_effort(self) -> None:
        given = {"model": "sonnet", "effortLevel": "low"}
        got = json.loads(run(json.dumps(given)).stdout)
        self.assertEqual(got["model"], "sonnet", "/model must win over the seed")
        self.assertEqual(got["effortLevel"], "low", "/effort must win over the seed")

    def test_no_concrete_model_id_is_seeded(self) -> None:
        """版付き ID を焼くと世代交代で stale になる（claude-md-guard と同じ規則）。"""
        self.assertNotRegex(run("{}").stdout, r"claude-(opus|sonnet|haiku|fable)-[0-9]")


class Idempotent(unittest.TestCase):
    def test_a_second_pass_changes_nothing(self) -> None:
        once = run("{}").stdout
        twice = run(once).stdout
        self.assertEqual(json.loads(once), json.loads(twice))

    def test_hooks_are_not_duplicated(self) -> None:
        settings = run(run("{}").stdout).stdout
        got = json.loads(settings)
        self.assertEqual(commands(got, "SessionStart").count(STALE_CHECK), 1)
        self.assertEqual(commands(got, "SessionStart").count(QUOTA_NOTE), 1)
        self.assertEqual(commands(got, "SessionStart").count(PJLINT_NOTE), 1)
        self.assertEqual(commands(got, "Stop").count(WORK_REPORT), 1)

    def test_allow_entries_are_not_duplicated(self) -> None:
        allow = json.loads(run(run("{}").stdout).stdout)["permissions"]["allow"]
        self.assertEqual(len(allow), len(set(allow)))

    # 「live の ~/.claude/settings.json が既に不動点である」ことは **ここでは
    # 検査しない**。それは script の契約ではなくこのマシンの状態で、seed 対象の
    # キー（model / effortLevel）を人が消せば当然 apply が書き戻す —— 実際に
    # 2026-08-03 時点の live には model キーが無く、この検査を書いたら落ちた。
    # live↔source の乖離は chezmoi の担当（drift 検出器と t-1px4）。


if __name__ == "__main__":
    unittest.main()
