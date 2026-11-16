"""claude-epic-guard の fixture テスト。

PreToolUse guard の契約は「**この機械が使うよう設定された board** に向かう
`furrow epic activate / deactivate / done` の Bash 呼び出しだけを止め、それ以外は
必ず allow（無出力・exit 0）」。止め方は 2 通り: 本体 session には ask（人が
ダイアログで答える）、subagent には deny（答える相手が居ないので ask は停止になる —
claude-board-shard-guard の初版が 2026-08-19 に踏んだ）。

誤検知する guard は guard 全体を無視させるので、allow 側のケースを厚くしてある。

ここで固定するのは:
  1. 設定された board に向かう 3 コマンド → ask（コマンド位置にあるものだけ）
  2. subagent（agent_id あり）→ deny
  3. 3 コマンド以外の furrow、コマンドに触れているだけの文字列、--help → allow
  4. 設定外の board（scratch・fixture）や board が引けない場所 → allow
  5. board は furrow 自身に聞く: 聞く場所は hook の cwd か、先頭の `cd /abs &&`
  6. fail-open: 壊れた JSON / 空 stdin / furrow 不在 / config 不読 → 無出力・exit 0

furrow は stub に差し替える（PATH の先頭に置く）。本物を呼ぶと、テストの結果が
開発機の board 設定で変わる。
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-epic-guard"

BOARD = "/Volumes/workspace/github.com/akira-toriyama/projects/.furrow"
OTHER_BOARD = "/Volumes/workspace/github.com/akira-toriyama/other/.furrow"
SCRATCH = "/private/tmp/scratch/.furrow"
CONFIG = f'''# test fixture
[[board]]
path        = "{BOARD}"
scopes      = ["/Volumes/workspace/github.com/akira-toriyama"]

[[board]]
path        = "{OTHER_BOARD}"
'''

# `furrow board --json` の stub。呼ばれた場所・FURROW_BOARD・引数を STUB_LOG に残す。
STUB = """#!/bin/bash
if [ -n "${STUB_LOG:-}" ]; then
  printf '%s|%s|%s\\n' "$PWD" "${FURROW_BOARD:-}" "$*" >>"$STUB_LOG"
fi
if [ "${STUB_EXIT:-0}" != 0 ]; then
  echo '{"error":{"kind":"validation"}}' >&2
  exit "$STUB_EXIT"
fi
printf '{"store":"%s","source":"user-config"}\\n' "$STUB_STORE"
"""


class Result:
    def __init__(self, proc: subprocess.CompletedProcess[str], log: list[str]) -> None:
        self.proc = proc
        self.log = log

    @property
    def decision(self) -> str | None:
        if not self.proc.stdout.strip():
            return None
        got = json.loads(self.proc.stdout)["hookSpecificOutput"]["permissionDecision"]
        assert isinstance(got, str)
        return got

    @property
    def reason(self) -> str:
        got = json.loads(self.proc.stdout)["hookSpecificOutput"][
            "permissionDecisionReason"
        ]
        assert isinstance(got, str)
        return got


def run(
    payload: str,
    *,
    store: str = BOARD,
    config: str | None = CONFIG,
    furrow: bool = True,
    furrow_exit: int = 0,
) -> Result:
    jq = shutil.which("jq")
    if jq is None:  # pragma: no cover - devShell が供給する
        raise unittest.SkipTest("jq not on PATH")
    with tempfile.TemporaryDirectory() as tmp:
        # jq だけを通す bin。jq の親ディレクトリをそのまま PATH に入れると、同じ場所に
        # 居る本物の furrow まで通ってしまう。
        bindir = Path(tmp) / "bin"
        bindir.mkdir()
        (bindir / "jq").symlink_to(jq)
        if furrow:
            stub = bindir / "furrow"
            stub.write_text(STUB)
            stub.chmod(0o755)
        log = Path(tmp) / "furrow.log"
        env = {
            "PATH": os.pathsep.join([str(bindir), "/usr/bin", "/bin"]),
            "HOME": tmp,
            "STUB_STORE": store,
            "STUB_EXIT": str(furrow_exit),
            "STUB_LOG": str(log),
        }
        if config is None:
            env["FURROW_CONFIG"] = str(Path(tmp) / "nonexistent.toml")
        else:
            cfg = Path(tmp) / "config.toml"
            cfg.write_text(config)
            env["FURROW_CONFIG"] = str(cfg)
        proc = subprocess.run(
            ["bash", str(SCRIPT)],
            input=payload,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        lines = log.read_text().splitlines() if log.exists() else []
        return Result(proc, lines)


def bash(
    command: str, *, cwd: str = "/", agent: str | None = None, **kw: object
) -> Result:
    payload: dict[str, object] = {
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": cwd,
    }
    if agent is not None:
        payload["agent_id"] = agent
    return run(json.dumps(payload), **kw)  # type: ignore[arg-type]


class AsksOnTheConfiguredBoard(unittest.TestCase):
    def test_the_three_commands_ask(self) -> None:
        for verb in ("activate", "deactivate", "done"):
            with self.subTest(verb=verb):
                got = bash(f"furrow epic {verb} e-3vpx")
                self.assertEqual(got.decision, "ask")
                self.assertEqual(got.proc.returncode, 0)

    def test_the_reason_shows_the_command_and_nothing_before_it(self) -> None:
        got = bash(
            'furrow sync && furrow epic activate e-3vpx --reason "box" && furrow sync'
        )
        self.assertEqual(got.decision, "ask")
        self.assertIn(': furrow epic activate e-3vpx --reason "box"\n', got.reason)
        self.assertNotIn("furrow sync", got.reason)

    def test_the_reason_names_the_one_decision_the_command_is(self) -> None:
        switch, close = "active epic の切り替えです: ", "epic の close です: "
        for verb, want, other in (
            ("activate", switch, close),
            ("deactivate", switch, close),
            ("done", close, switch),
        ):
            with self.subTest(verb=verb):
                reason = bash(f"furrow epic {verb} e-1 --json").reason
                self.assertTrue(reason.startswith(f"{want}furrow epic {verb} e-1"))
                self.assertNotIn(other, reason)

    def test_a_second_configured_board_asks_too(self) -> None:
        self.assertEqual(
            bash("furrow epic done e-1", store=OTHER_BOARD).decision, "ask"
        )

    def test_command_positions(self) -> None:
        for command in (
            "furrow sync; furrow epic done e-1",
            "furrow sync || furrow epic done e-1",
            "true | furrow epic done e-1",
            "(furrow epic done e-1)",
            "{ furrow epic done e-1; }",
            "out=$(furrow epic done e-1 --json)",
            "furrow sync\nfurrow epic done e-1\nfurrow sync",
            "  furrow   epic   done   e-1  ",
            "furrow epic done e-1 2>&1 | tail -3",
            "furrow epic done e-1",
        ):
            with self.subTest(command=command):
                self.assertEqual(bash(command).decision, "ask")

    def test_other_spellings_of_the_binary(self) -> None:
        for command in (
            "go run ./cmd/furrow epic done e-1",
            "GOTOOLCHAIN=local go run ./cmd/furrow epic done e-1",
            "/etc/profiles/per-user/tommy/bin/furrow epic done e-1",
            "./furrow epic activate e-1",
            "furrow --json epic done e-1",
            "NO_COLOR=1 furrow epic deactivate e-1",
        ):
            with self.subTest(command=command):
                self.assertEqual(bash(command).decision, "ask")


class DeniesInASubagent(unittest.TestCase):
    def test_a_subagent_is_denied_not_asked(self) -> None:
        got = bash("furrow epic done e-1", agent="a1b2c3")
        self.assertEqual(got.decision, "deny")
        self.assertIn("furrow epic done e-1", got.reason)
        self.assertIn("parent session", got.reason)

    def test_a_subagent_on_a_scratch_board_passes(self) -> None:
        got = bash("furrow epic done e-1", agent="a1b2c3", store=SCRATCH)
        self.assertIsNone(got.decision)


class AllowsEverythingElse(unittest.TestCase):
    def assert_allowed_without_asking_furrow(self, command: str) -> None:
        got = bash(command)
        self.assertIsNone(got.decision, command)
        self.assertEqual(got.proc.returncode, 0)
        self.assertEqual(got.proc.stdout, "")
        self.assertEqual(got.log, [], f"furrow was consulted for: {command}")

    def test_other_furrow_commands(self) -> None:
        for command in (
            "furrow epic ls --json",
            "furrow epic show e-1",
            'furrow epic add "a box" -r furrow',
            "furrow epic set e-1 --successor e-2",
            "furrow epic reopen e-1",
            "furrow epic dep e-1 e-2",
            "furrow epic rm e-1",
            "furrow done t-9cby",
            "furrow set t-9cby -s done",
            "furrow revisit --boxes",
            "furrow sync && furrow brief",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_help_is_a_read(self) -> None:
        for command in (
            "furrow epic done --help",
            "furrow epic activate -h",
            "furrow epic --help",
            "furrow epic done --help 2>&1 | head -20",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_text_that_only_mentions_a_command(self) -> None:
        for command in (
            "grep -rn 'furrow epic done' docs",
            'git commit -m "the guard asks before furrow epic done runs"',
            'furrow note t-9cby "next: furrow epic activate e-1 once the human says"',
            "echo furrow epic done e-1",
            'rg -n "furrow epic (activate|deactivate|done)" .',
            "man furrow-epic-done",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_a_longer_word_is_not_the_command(self) -> None:
        for command in (
            "furrow epic done-ish e-1",
            "furrow epic activated",
            "furrow epics done e-1",
        ):
            with self.subTest(command=command):
                self.assertIsNone(bash(command).decision)

    def test_one_help_occurrence_does_not_excuse_a_real_one(self) -> None:
        got = bash("furrow epic done --help; furrow epic done e-1")
        self.assertEqual(got.decision, "ask")
        self.assertIn(": furrow epic done e-1\n", got.reason)

    def test_another_tool_is_not_bash(self) -> None:
        payload = json.dumps(
            {
                "tool_name": "Write",
                "tool_input": {"file_path": "/x", "content": "furrow epic done e-1"},
            }
        )
        self.assertIsNone(run(payload).decision)


class ScopeIsTheBoardFurrowReports(unittest.TestCase):
    def test_a_scratch_board_passes(self) -> None:
        got = bash("furrow epic done e-1", store=SCRATCH)
        self.assertIsNone(got.decision)
        self.assertEqual(len(got.log), 1)

    def test_a_copy_of_the_board_passes(self) -> None:
        self.assertIsNone(
            bash("furrow epic done e-1", store="/private/tmp/copy" + BOARD).decision
        )

    def test_no_board_here_passes(self) -> None:
        self.assertIsNone(bash("furrow epic done e-1", furrow_exit=2).decision)

    def test_furrow_is_asked_with_board_json(self) -> None:
        got = bash("furrow epic done e-1")
        self.assertEqual([line.split("|")[2] for line in got.log], ["board --json"])

    def test_furrow_is_asked_from_the_hook_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as where:
            got = bash("furrow epic done e-1", cwd=where)
            self.assertEqual(got.decision, "ask")
            self.assertEqual(
                os.path.realpath(got.log[0].split("|")[0]), os.path.realpath(where)
            )

    def test_a_leading_absolute_cd_wins_over_the_hook_cwd(self) -> None:
        with (
            tempfile.TemporaryDirectory() as where,
            tempfile.TemporaryDirectory() as elsewhere,
        ):
            for lead in (
                f"cd {where}",
                f'cd "{where}"',
                f"cd '{where}'",
                f"cd -- {where}",
            ):
                with self.subTest(lead=lead):
                    got = bash(f"{lead} && furrow epic done e-1", cwd=elsewhere)
                    self.assertEqual(got.decision, "ask")
                    self.assertEqual(
                        os.path.realpath(got.log[0].split("|")[0]),
                        os.path.realpath(where),
                    )

    def test_a_leading_cd_to_a_missing_directory_falls_back_to_the_hook_cwd(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as where:
            got = bash("cd /nonexistent/zzz && furrow epic done e-1", cwd=where)
            self.assertEqual(
                os.path.realpath(got.log[0].split("|")[0]), os.path.realpath(where)
            )

    def test_an_inline_furrow_board_reaches_the_read(self) -> None:
        for spelled in ("/x/.furrow", '"/x/.furrow"', "'/x/.furrow'"):
            with self.subTest(spelled=spelled):
                got = bash(f"FURROW_BOARD={spelled} furrow epic done e-1")
                self.assertEqual(got.log[0].split("|")[1], "/x/.furrow")

    def test_a_command_with_its_own_config_home_passes(self) -> None:
        got = bash("XDG_CONFIG_HOME=/private/tmp/rig furrow epic done e-1")
        self.assertIsNone(got.decision)
        self.assertEqual(got.log, [])


class FailsOpen(unittest.TestCase):
    def assert_silent(self, got: Result) -> None:
        self.assertEqual(got.proc.returncode, 0)
        self.assertEqual(got.proc.stdout, "")

    def test_broken_json(self) -> None:
        self.assert_silent(run("{not json"))

    def test_empty_stdin(self) -> None:
        self.assert_silent(run(""))

    def test_no_command(self) -> None:
        self.assert_silent(run(json.dumps({"tool_name": "Bash", "tool_input": {}})))

    def test_a_command_that_is_not_a_string(self) -> None:
        self.assert_silent(
            run(
                json.dumps({"tool_name": "Bash", "tool_input": {"command": ["furrow"]}})
            )
        )

    def test_no_furrow_on_path(self) -> None:
        self.assert_silent(bash("furrow epic done e-1", furrow=False))

    def test_no_readable_config(self) -> None:
        self.assert_silent(bash("furrow epic done e-1", config=None))

    def test_a_config_without_boards(self) -> None:
        self.assert_silent(bash("furrow epic done e-1", config="# empty\n"))

    def test_furrow_reports_no_store(self) -> None:
        self.assert_silent(bash("furrow epic done e-1", store=""))

    def test_no_cwd_in_the_payload(self) -> None:
        payload = json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": "furrow epic done e-1"}}
        )
        self.assertEqual(run(payload).decision, "ask")


if __name__ == "__main__":
    unittest.main()
