"""claude-epic-guard の fixture テスト。

PreToolUse guard の契約は「**この機械が使うよう設定された board** に向かう
`furrow epic activate / deactivate / done` の Bash 呼び出しだけを止め、それ以外は
必ず allow（無出力・exit 0）」。止め方は 2 通り: 本体 session には ask（人が
ダイアログで答える）、subagent には deny（答える相手が居ないので ask は停止になる —
claude-board-shard-guard の初版が 2026-08-19 に踏んだ）。

誤検知する guard は guard 全体を無視させるので、allow 側のケースを厚くしてある。

ここで固定するのは:
  1. 設定された board に向かう 3 コマンド → ask（コマンド位置にあるものだけ）。
     引用符・heredoc の本文・コメントの中の文字列はコマンドではない。ただし二重引用符の
     中の `$( )` とバッククォートはコマンド位置
  2. subagent（agent_id あり）→ deny
  3. 3 コマンド以外の furrow、コマンドに触れているだけの文字列、--help → allow
  4. 設定外の board（scratch・fixture）や board が引けない場所 → allow
  5. board は furrow 自身に聞く: 聞く場所は hook の cwd か、先頭の `cd /abs`。
     その furrow 呼び出しの前に置かれた FURROW_DIR / FURROW_BOARD は一緒に渡す
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
import time
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

# `furrow board --json` の stub。STUB_LOG に、呼ばれた場所・FURROW_BOARD・引数・
# FURROW_DIR を残す。
STUB = """#!/bin/bash
if [ -n "${STUB_LOG:-}" ]; then
  printf '%s|%s|%s|%s\\n' "$PWD" "${FURROW_BOARD:-}" "$*" "${FURROW_DIR:-}" \\
    >>"$STUB_LOG"
fi
if [ "${STUB_EXIT:-0}" != 0 ]; then
  echo '{"error":{"kind":"validation"}}' >&2
  exit "$STUB_EXIT"
fi
if [ -n "${FURROW_DIR:-}" ]; then
  printf '{"store":"%s","source":"env"}\\n' "${STUB_DIR_STORE:-$STUB_STORE}"
  exit 0
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
    dir_store: str | None = None,
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
        if dir_store is not None:
            env["STUB_DIR_STORE"] = dir_store
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
            "printf furrow epic done e-1",
            "furrow note t-9cby furrow epic done e-1",
            "furrow sync; echo furrow epic activate e-1",
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

    def test_a_cd_to_a_missing_directory_is_judged_from_its_ancestor(self) -> None:
        with tempfile.TemporaryDirectory() as where:
            got = bash(f"cd {where}/not/made/yet && furrow epic done e-1", cwd="/")
            self.assertEqual(
                os.path.realpath(got.log[0].split("|")[0]), os.path.realpath(where)
            )

    def test_an_inline_furrow_board_reaches_the_read(self) -> None:
        for spelled in ("/x/.furrow", '"/x/.furrow"', "'/x/.furrow'"):
            with self.subTest(spelled=spelled):
                got = bash(f"FURROW_BOARD={spelled} furrow epic done e-1")
                self.assertEqual(got.log[0].split("|")[1], "/x/.furrow")

    def test_an_inline_furrow_dir_reaches_the_read(self) -> None:
        """FURROW_DIR is first in furrow's discovery order: without it the guard
        asked about a fixture and missed the real board named from elsewhere."""
        for spelled in ("/x/.furrow", '"/x/.furrow"', "'/x/.furrow'"):
            with self.subTest(spelled=spelled):
                got = bash(f"FURROW_DIR={spelled} furrow epic done e-1")
                self.assertEqual(got.log[0].split("|")[3], "/x/.furrow")
                self.assertEqual(got.log[0].split("|")[1], "")

    def test_a_leading_cd_ended_by_a_semicolon_or_a_newline_is_followed(self) -> None:
        with (
            tempfile.TemporaryDirectory() as where,
            tempfile.TemporaryDirectory() as elsewhere,
        ):
            for sep in ("; ", "\n"):
                with self.subTest(sep=sep):
                    got = bash(f"cd {where}{sep}furrow epic done e-1", cwd=elsewhere)
                    self.assertEqual(
                        os.path.realpath(got.log[0].split("|")[0]),
                        os.path.realpath(where),
                    )

    def test_a_command_with_its_own_config_home_passes(self) -> None:
        got = bash("XDG_CONFIG_HOME=/private/tmp/rig furrow epic done e-1")
        self.assertIsNone(got.decision)
        self.assertEqual(got.log, [])


class QuotedTextIsNotACommand(unittest.TestCase):
    """初版は生の文字列で照合し、引用符の中の区切り文字（; & ` ( と行頭）を
    コマンドの始まりと読んだ。レビューが実物の commit メッセージと task 本文で
    再現した。"""

    def assert_allowed_without_asking_furrow(self, command: str) -> None:
        got = bash(command)
        self.assertIsNone(got.decision, command)
        self.assertEqual(got.proc.stdout, "")
        self.assertEqual(got.log, [], f"furrow was consulted for: {command}")

    def test_mentions_inside_quotes(self) -> None:
        for command in (
            "git commit -m 'asks before `furrow epic activate|deactivate|done` runs'",
            'furrow note t-9cby "applied; furrow epic done e-1 awaits the human"',
            'echo "(furrow epic done e-1 now)"',
            'echo "a & furrow epic done e-1"',
            'git commit -m "subject\n\nfurrow epic done e-1 now asks"',
            "printf '%s\n' 'x' | grep -c ';furrow epic done e-1'",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_a_heredoc_body_is_data(self) -> None:
        for command in (
            "git commit -F - <<'EOF'\nsubject\n\nfurrow epic done e-1 is gated\nEOF",
            "furrow note t-1 -F - <<EOF\nfurrow epic activate e-1\nEOF\nfurrow sync",
            "cat > msg <<-MSG\n\tfurrow epic done e-1\n\tMSG\ngit commit -F msg",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_a_comment_is_data(self) -> None:
        self.assert_allowed_without_asking_furrow(
            "# later; furrow epic done e-1\nfurrow sync"
        )
        self.assert_allowed_without_asking_furrow(
            "furrow sync # then: furrow epic done e-1"
        )


class CommandPositionsSurviveTheMasking(unittest.TestCase):
    def assert_asks(self, command: str) -> None:
        self.assertEqual(bash(command).decision, "ask", command)

    def test_command_substitution_inside_double_quotes_runs(self) -> None:
        self.assert_asks('out="$(furrow epic done e-1 --json)"')
        self.assert_asks('echo "result: `furrow epic done e-1`"')
        self.assert_asks('echo "$(echo "$(furrow epic done e-1)")"')

    def test_backticks_at_the_top_level_run(self) -> None:
        self.assert_asks("x=`furrow epic done e-1`")

    def test_a_real_command_after_quoted_text(self) -> None:
        self.assert_asks('furrow note t-1 "it\'s fine" && furrow epic done e-1')
        self.assert_asks(
            "furrow note t-1 -F - <<'EOF'\nit's done\nEOF\nfurrow epic done e-1"
        )
        self.assert_asks("# don't forget the box\nfurrow epic done e-1")
        self.assert_asks("echo 'a) b' && (furrow epic done e-1)")

    def test_a_scan_that_ends_inside_a_quote_falls_back_to_the_raw_text(self) -> None:
        self.assert_asks('echo "never closed; furrow epic done e-1')

    def test_a_heredoc_whose_delimiter_never_comes_masks_nothing(self) -> None:
        self.assert_asks("cat <<EOF\nbody\nfurrow epic done e-1")

    def test_a_here_string_is_not_a_heredoc(self) -> None:
        self.assert_asks("cat <<< word\nfurrow epic done e-1")

    def test_more_spellings(self) -> None:
        for command in (
            "furrow --json=true epic done e-1",
            'MSG="a b" furrow epic done e-1',
            "command furrow epic done e-1",
            "exec furrow epic done e-1",
            "time furrow epic done e-1",
            "furrow \\\n  epic \\\n  done e-1",
            "for e in e-1 e-2; do furrow epic done $e; done",
            "if furrow epic done e-1; then echo ok; fi",
            "furrow sync && ! furrow epic deactivate e-1",
            "step furrow epic done e-1",
            "xargs furrow epic done < ids.txt",
            "sudo env furrow epic done e-1",
        ):
            with self.subTest(command=command):
                self.assert_asks(command)


class TheReasonNamesWhatRuns(unittest.TestCase):
    def test_the_decision_comes_from_the_verb_not_from_an_argument(self) -> None:
        got = bash('furrow epic activate e-2 --reason "after epic done of e-1"')
        self.assertTrue(
            got.reason.startswith(
                "active epic の切り替えです: furrow epic activate e-2"
            )
        )
        self.assertNotIn("close", got.reason.split("\n")[0].split(": ")[0])

    def test_every_gated_command_of_the_call_is_listed(self) -> None:
        got = bash("furrow epic done e-1 && furrow epic activate e-2 --reason next")
        self.assertEqual(
            got.reason.split("\n")[:2],
            [
                "epic の close です: furrow epic done e-1",
                "active epic の切り替えです: furrow epic activate e-2 --reason next",
            ],
        )

    def test_a_redirection_cut_off_by_its_ampersand_is_not_shown(self) -> None:
        got = bash("furrow epic done e-1 2>&1 | tail -3")
        self.assertEqual(
            got.reason.split("\n")[0], "epic の close です: furrow epic done e-1"
        )

    def test_a_subagent_is_told_every_command_too(self) -> None:
        got = bash("furrow epic done e-1; furrow epic done e-2", agent="a1")
        self.assertEqual(got.decision, "deny")
        self.assertIn("furrow epic done e-1 / furrow epic done e-2", got.reason)


class TheLexerDoesNotHideRealCalls(unittest.TestCase):
    """2 回目のレビューが見つけた見逃し。引用符と heredoc を別々の走査で隠した版は、
    引用符やコメントの中の `<<EOF` を heredoc の始まりと読み、後ろの本物のコマンドを
    隠した。どれも初版（生の文字列で照合）は ask を返していた。"""

    def assert_asks(self, command: str) -> None:
        self.assertEqual(bash(command).decision, "ask", command)

    def test_a_heredoc_marker_inside_a_quote_or_a_comment_starts_nothing(self) -> None:
        self.assert_asks(
            'git commit -m "a <<EOF body"\nfurrow epic done e-1\ncat <<EOF\nx\nEOF'
        )
        self.assert_asks(
            "# body goes in <<EOF below\nfurrow epic done e-1\ncat <<EOF\nnote\nEOF"
        )

    def test_a_heredoc_fed_to_a_shell_is_code(self) -> None:
        for command in (
            "bash <<'EOF'\nfurrow epic done e-1\nEOF",
            "sh -s <<EOF\nset -e\nfurrow epic done e-1\nEOF",
            "sudo /bin/bash <<EOF\nfurrow epic done e-1\nEOF",
        ):
            with self.subTest(command=command):
                self.assert_asks(command)

    def test_quoting_the_first_lexer_lost_track_of(self) -> None:
        for command in (
            "echo $'can\\'t'\nfurrow epic done e-1 # don't",
            'echo "${a:-"it\'s"}"; furrow epic done e-1; echo "${b:-"that\'s"}"',
            "echo ${x:-a #b}; furrow epic done e-1",
            "echo \\ #; furrow epic done e-1",
        ):
            with self.subTest(command=command):
                self.assert_asks(command)

    def test_a_substitution_closes_at_its_own_parenthesis(self) -> None:
        got = bash('echo "$(furrow epic done e-1)" -h')
        self.assertEqual(got.decision, "ask")
        self.assertEqual(
            got.reason.split("\n")[0], "epic の close です: furrow epic done e-1"
        )

    def test_a_case_arm_and_wrappers_with_arguments(self) -> None:
        for command in (
            "case $v in done) furrow epic done e-1;; esac",
            "timeout 30 furrow epic done e-1",
            "nice -n 5 furrow epic done e-1",
        ):
            with self.subTest(command=command):
                self.assert_asks(command)

    def test_a_mention_does_not_silence_a_real_call(self) -> None:
        """FURROW_DIR / XDG_CONFIG_HOME は、その呼び出しの前の代入だけを見る。"""
        for command in (
            'furrow note t-1 "try FURROW_DIR=/tmp/x next" && furrow epic done e-1',
            "FURROW_DIR=/tmp/fixture/.furrow furrow ls; furrow epic done e-1",
            'furrow note t-1 "a rig: XDG_CONFIG_HOME=/tmp/r" && furrow epic done e-1',
            "XDG_CONFIG_HOME=/tmp/rig furrow ls; furrow epic done e-1",
        ):
            with self.subTest(command=command):
                got = bash(command)
                self.assertEqual(got.decision, "ask")
                self.assertEqual([line.split("|")[3] for line in got.log], [""])

    def test_each_call_is_judged_against_its_own_board(self) -> None:
        got = bash(
            "FURROW_DIR=/scratch/.furrow furrow epic done e-1; furrow epic done e-2",
            dir_store=SCRATCH,
        )
        self.assertEqual(got.decision, "ask")
        self.assertIn(": furrow epic done e-2\n", got.reason)
        self.assertNotIn("e-1", got.reason)

    def test_a_long_command_stays_inside_the_hook_timeout(self) -> None:
        """reduce で出力を状態に溜めた版は 100000 字に 21 秒、130000 字で 30 秒の
        timeout を超えた。1 字ずつ出す foreach は長さに比例する。"""
        body = "\n".join(
            f"line {i}: it's text, not furrow epic done" for i in range(4500)
        )
        command = f"cat > notes.md <<'EOF'\n{body}\nEOF\nfurrow epic done e-1"
        self.assertGreater(len(command), 190_000)
        started = time.monotonic()
        got = bash(command)
        self.assertEqual(got.decision, "ask")
        self.assertLess(time.monotonic() - started, 20)

    def test_a_command_too_long_to_lex_is_matched_raw(self) -> None:
        pad = "x" * 200_001
        self.assertEqual(bash(f"echo {pad}\nfurrow epic done e-1").decision, "ask")


class TheLexerDoesNotInventCalls(unittest.TestCase):
    def assert_allowed_without_asking_furrow(self, command: str) -> None:
        got = bash(command)
        self.assertIsNone(got.decision, command)
        self.assertEqual(got.log, [], f"furrow was consulted for: {command}")

    def test_heredoc_delimiters_of_any_shape(self) -> None:
        for command in (
            "cat <<END-MSG\nfurrow epic done e-1\nEND-MSG",
            "cat <<EOF.txt\nfurrow epic done e-1\nEOF.txt",
            "cat <<A <<B\nx\nA\nfurrow epic done e-1\nB",
            'cat <<"E O F"\nfurrow epic done e-1\nE O F\nfurrow sync',
            "cat <<\\EOF\nfurrow epic done e-1\nEOF",
        ):
            with self.subTest(command=command):
                self.assert_allowed_without_asking_furrow(command)

    def test_an_escaped_dollar_and_a_quoted_default(self) -> None:
        self.assert_allowed_without_asking_furrow('echo "\\$(furrow epic done e-1)"')
        self.assert_allowed_without_asking_furrow(
            'echo "${x:-"a; furrow epic done e-1"}"'
        )

    def test_a_shift_is_not_a_heredoc(self) -> None:
        got = bash("echo $((1<<2))\nfurrow epic done e-1")
        self.assertEqual(got.decision, "ask")


class TheDialogShowsTheCommandAsWritten(unittest.TestCase):
    def test_wide_spaces_inside_an_argument_survive(self) -> None:
        got = bash('furrow epic activate e-1 --reason "a　b"')
        self.assertIn('--reason "a　b"', got.reason)

    def test_text_before_the_command_does_not_shift_the_span(self) -> None:
        got = bash('furrow note t-1 "日本語の本文 🙂" && furrow epic done e-1')
        self.assertEqual(
            got.reason.split("\n")[0], "epic の close です: furrow epic done e-1"
        )


class RoundThree(unittest.TestCase):
    """3 回目のレビューが見つけたもの。字句解析の骨組みは保ち、読めていなかった形を
    足した。"""

    def assert_asks(self, command: str, **kw: object) -> Result:
        got = bash(command, **kw)  # type: ignore[arg-type]
        self.assertEqual(got.decision, "ask", command)
        return got

    def assert_allowed(self, command: str, **kw: object) -> Result:
        got = bash(command, **kw)  # type: ignore[arg-type]
        self.assertIsNone(got.decision, command)
        return got

    def test_xargs_with_a_placeholder(self) -> None:
        self.assert_asks(
            "furrow epic ls --json | jq -r '.[].id' | xargs -I{} furrow epic done {}"
        )
        self.assert_asks("echo e-1 | xargs -I {} furrow epic done {}")

    def test_a_redirection_in_front_of_the_command(self) -> None:
        self.assert_asks(">/dev/null furrow epic done e-1")
        self.assert_asks("2>&1 furrow epic done e-1")

    def test_a_heredoc_piped_to_a_shell_is_code(self) -> None:
        self.assert_asks("cat <<EOF | bash\nfurrow epic done e-1\nEOF")
        self.assert_asks("cat <<'EOF' | sh -s\nfurrow epic done e-1\nEOF")

    def test_a_substitution_in_an_unquoted_heredoc_body_runs(self) -> None:
        body = "closed: $(furrow epic done e-1 --json | jq -r .id)"
        got = self.assert_asks(f"furrow note t-1 -F - <<EOF\n{body}\nEOF")
        self.assertEqual(
            got.reason.split("\n")[0], "epic の close です: furrow epic done e-1 --json"
        )
        self.assert_asks("cat <<EOF\nnow `furrow epic done e-1`\nEOF")

    def test_a_quoted_heredoc_body_stays_literal(self) -> None:
        body = "closed: $(furrow epic done e-1 --json | jq -r .id)"
        for intro in ("<<'EOF'", '<<"EOF"', "<<\\EOF"):
            with self.subTest(intro=intro):
                self.assert_allowed(f"furrow note t-1 -F - {intro}\n{body}\nEOF")
        self.assert_allowed("cat <<EOF\nescaped \\$(furrow epic done e-1)\nEOF")

    def test_a_heredoc_inside_a_substitution_closed_on_its_delimiter_line(self) -> None:
        self.assert_asks("x=$(cat <<EOF\nhi\nEOF)\nfurrow epic done e-1")
        self.assert_asks(
            "git commit -m \"$(cat <<'EOF'\nit's done\nEOF\n)\" && furrow epic done e-1"
        )

    def test_a_shift_inside_arithmetic_is_not_a_heredoc(self) -> None:
        loop = "for e in e-1; do furrow epic done $e; done"
        self.assert_asks(f"mask=$((1 << bit))\n{loop}")
        self.assert_asks(f"(( flags << shift ))\n{loop}")
        self.assert_asks(f'echo "$((1 << bit))"\n{loop}')

    def test_a_hash_after_a_substitution_is_not_a_comment(self) -> None:
        self.assert_asks("echo $(date)#x; furrow epic done e-1")

    def test_the_fallback_still_sees_keywords_and_wrappers(self) -> None:
        pad = "x" * 200_001
        for tail in (
            "for e in e-1; do furrow epic done $e; done",
            "go run ./cmd/furrow epic done e-1",
            "if true; then furrow epic done e-1; fi",
            "timeout 30 furrow epic done e-1",
            "xargs -I{} furrow epic done {}",
        ):
            with self.subTest(tail=tail):
                self.assert_asks(f"echo {pad}\n{tail}")

    def test_the_fallback_does_not_read_prose_as_a_call(self) -> None:
        pad = "x" * 200_001
        self.assert_allowed(
            f"echo {pad}\necho the hook asks before furrow epic done runs"
        )

    def test_a_stack_deeper_than_the_cap_falls_back(self) -> None:
        nest = '"$(echo ' * 300
        started = time.monotonic()
        self.assert_asks(f"echo {nest}\nfurrow epic done e-1")
        self.assertLess(time.monotonic() - started, 10)

    def test_an_assignment_holding_a_substitution_stays_one_word(self) -> None:
        """`)` で照合をやり直し、前に置いた FURROW_DIR を落としていた。"""
        for value in (
            '"$(mktemp -d)/.furrow"',
            "$(mktemp -d)/.furrow",
            "`mktemp -d`/x",
        ):
            with self.subTest(value=value):
                got = self.assert_allowed(
                    f"FURROW_DIR={value} furrow epic done e-1", dir_store=SCRATCH
                )
                self.assertEqual(len(got.log), 1)
                self.assertNotEqual(got.log[0].split("|")[3], "")

    def test_an_assignment_from_a_substitution_does_not_hide_the_call(self) -> None:
        got = self.assert_asks('NOTE="$(cat note.md)" furrow epic done e-1')
        self.assertEqual(
            got.reason.split("\n")[0],
            'epic の close です: NOTE="$(cat note.md)" furrow epic done e-1',
        )

    def test_a_call_inside_and_a_call_outside_a_substitution(self) -> None:
        got = self.assert_asks('X="$(furrow epic done e-1)" furrow epic activate e-2')
        self.assertEqual(
            [line.split(": ")[0] for line in got.reason.split("\n")[:2]],
            ["active epic の切り替えです", "epic の close です"],
        )

    def test_a_cd_that_is_not_the_first_word_is_followed(self) -> None:
        with (
            tempfile.TemporaryDirectory() as where,
            tempfile.TemporaryDirectory() as hook,
        ):
            real = os.path.realpath(where)
            for command in (
                f"cd {where} || exit 1\nfurrow epic done e-1",
                f"cd {where} 2>/dev/null && furrow epic done e-1",
                f"set -e; cd {where}; furrow epic done e-1",
                f"(cd {where} && furrow epic done e-1)",
                f"pushd {where} >/dev/null; furrow epic done e-1",
                f"builtin cd -- {where} && furrow epic done e-1",
            ):
                with self.subTest(command=command):
                    got = self.assert_asks(command, cwd=hook)
                    self.assertEqual(os.path.realpath(got.log[0].split("|")[0]), real)

    def test_a_quoted_cd_path_with_a_space_is_followed(self) -> None:
        with (
            tempfile.TemporaryDirectory() as base,
            tempfile.TemporaryDirectory() as hook,
        ):
            where = Path(base) / "a b"
            where.mkdir()
            got = self.assert_asks(f'cd "{where}" && furrow epic done e-1', cwd=hook)
            self.assertEqual(
                os.path.realpath(got.log[0].split("|")[0]), os.path.realpath(where)
            )

    def test_each_call_reads_the_cd_in_front_of_it(self) -> None:
        with tempfile.TemporaryDirectory() as one, tempfile.TemporaryDirectory() as two:
            got = self.assert_asks(
                f"cd {one} && furrow epic done e-1; cd {two} && furrow epic done e-2"
            )
            self.assertEqual(
                [os.path.realpath(line.split("|")[0]) for line in got.log],
                [os.path.realpath(one), os.path.realpath(two)],
            )

    def test_a_board_that_resolves_nowhere_is_asked_once_not_per_call(self) -> None:
        calls = "; ".join(f"furrow epic done e-{n}" for n in range(40))
        got = self.assert_allowed(calls, furrow_exit=2)
        self.assertEqual(len(got.log), 1)


class WhereACallRuns(unittest.TestCase):
    """4 回目のレビューと transcript の再生から。シェルに聞かないと分からない場所への
    cd（`cd "$tmp"`、`cd "$(mktemp -d)"`）の後ろの呼び出しを hook の cwd で判定すると、
    scratch board でのドリルに確認が出る。この機械の transcript では、そういう cd の
    後ろの 27 回は全部ドリルだった。"""

    def where_asked(self, got: Result) -> list[str]:
        return [os.path.realpath(line.split("|")[0]) for line in got.log]

    def test_a_cd_that_needs_the_shell_leaves_the_place_unknown(self) -> None:
        for command in (
            'cd "$(mktemp -d)" && furrow init && furrow epic activate e-1',
            'tmp=$(mktemp -d); cd "$tmp" && furrow epic activate e-1',
            "cd $E/a && furrow epic done $EID >/dev/null",
            'cd "$S/work"\nfurrow epic deactivate "$C"',
            "cd - && furrow epic done e-1",
            "pushd && furrow epic done e-1",
            "popd; furrow epic done e-1",
        ):
            with self.subTest(command=command):
                got = bash(command)
                self.assertIsNone(got.decision)
                self.assertEqual(got.log, [])

    def test_an_absolute_cd_after_an_unknown_one_is_known_again(self) -> None:
        with tempfile.TemporaryDirectory() as where:
            got = bash(
                f'cd "$T" && furrow epic done e-1; cd {where} && furrow epic done e-2'
            )
            self.assertEqual(got.decision, "ask")
            self.assertNotIn("e-1", got.reason)
            self.assertEqual(self.where_asked(got), [os.path.realpath(where)])

    def test_a_directory_made_by_the_same_command_is_judged_from_its_parent(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as base:
            new = f"{base}/drill/board"
            got = bash(
                f"mkdir -p {new} && cd {new} && furrow init && furrow epic activate e-1"
            )
            self.assertEqual(self.where_asked(got), [os.path.realpath(base)])

    def test_relative_moves_are_joined(self) -> None:
        with tempfile.TemporaryDirectory() as base:
            (Path(base) / "a" / "b").mkdir(parents=True)
            real = os.path.realpath(base)
            for moves, want in (
                (f"cd {base} && cd a", f"{real}/a"),
                (f"cd {base}/a; cd b; cd ..", f"{real}/a"),
                (f"cd {base}/a/b && cd ../..", real),
            ):
                with self.subTest(moves=moves):
                    got = bash(f"{moves} && furrow epic done e-1")
                    self.assertEqual(self.where_asked(got), [want])

    def test_a_cd_target_is_read_through_a_variable_the_command_assigns(self) -> None:
        with (
            tempfile.TemporaryDirectory() as hook,
            tempfile.TemporaryDirectory() as where,
        ):
            real = os.path.realpath(where)
            for command in (
                f'S={where}; cd "$S" || exit 1; furrow epic done e-1',
                f'B={where}; S="$B/not-made"; cd "${{S}}" && furrow epic done e-1',
                f"export REPO='{where}'\ncd $REPO && furrow epic done e-1",
            ):
                with self.subTest(command=command):
                    got = bash(command, cwd=hook)
                    self.assertEqual(got.decision, "ask")
                    self.assertEqual(self.where_asked(got), [real])

    def test_a_case_arm_does_not_end_the_cd_in_front_of_it(self) -> None:
        """drill の定型。case の `)` を group の閉じと数えると cd を捨て、hook の cwd で
        判定して scratch board に確認を出した（transcript の再生で 6 回）。"""
        with (
            tempfile.TemporaryDirectory() as hook,
            tempfile.TemporaryDirectory() as where,
        ):
            got = bash(
                f'S={where}; cd "$S" || exit 1\n'
                'case "$Q" in "$S"/*|/private"$S"/*) ;; *) echo ABORT; exit 1;; esac\n'
                'furrow epic activate "$A" >/dev/null 2>&1',
                cwd=hook,
            )
            self.assertEqual(self.where_asked(got), [os.path.realpath(where)])

    def test_a_call_in_a_case_arm_is_a_call(self) -> None:
        got = bash(
            "case $v in close) furrow epic done e-1 ;; *) furrow epic ls ;; esac"
        )
        self.assertEqual(got.decision, "ask")
        self.assertEqual(
            got.reason.split("\n")[0], "epic の close です: furrow epic done e-1"
        )

    def test_home_is_a_known_place(self) -> None:
        got = bash(
            "cd && furrow epic done e-1; cd ~ && furrow epic done e-2;"
            ' cd "$HOME" && furrow epic done e-3'
        )
        self.assertEqual(len(set(self.where_asked(got))), 1)
        self.assertIn("e-3", got.reason)
        self.assertEqual(got.decision, "ask")

    def test_a_cd_that_ended_with_its_subshell_is_not_followed(self) -> None:
        with (
            tempfile.TemporaryDirectory() as hook,
            tempfile.TemporaryDirectory() as away,
        ):
            for command in (
                f"(cd {away} && ls) && furrow epic done e-1",
                f"( cd {away} && true ); furrow epic activate e-1",
                f"pushd {away} && popd && furrow epic done e-1",
                f"pushd {away} >/dev/null; ls; popd >/dev/null; furrow epic done e-1",
            ):
                with self.subTest(command=command):
                    got = bash(command, cwd=hook)
                    self.assertEqual(got.decision, "ask")
                    self.assertEqual(self.where_asked(got), [os.path.realpath(hook)])

    def test_a_cd_behind_a_keyword_is_followed(self) -> None:
        with (
            tempfile.TemporaryDirectory() as hook,
            tempfile.TemporaryDirectory() as where,
        ):
            got = bash(f"if cd {where}; then furrow epic done e-1; fi", cwd=hook)
            self.assertEqual(self.where_asked(got), [os.path.realpath(where)])

    def test_places_already_read_are_not_read_again(self) -> None:
        with tempfile.TemporaryDirectory() as one, tempfile.TemporaryDirectory() as two:
            calls = "; ".join(
                f"cd {one if n % 2 else two} && furrow epic done e-{n}"
                for n in range(40)
            )
            got = bash(calls)
            self.assertEqual(got.decision, "ask")
            self.assertEqual(len(got.log), 2)


class AShellNameThatIsOnlyAnArgument(unittest.TestCase):
    """heredoc の本文をコードと読むのは、その行の pipeline のコマンド語が shell の
    ときだけ。行のどこかに shell の名前があるだけで本文を読んだ版は、file へ書く
    heredoc に確認を出した。"""

    BODY = "furrow epic done e-1"

    def test_the_body_stays_data(self) -> None:
        for intro in (
            "echo sh; cat > notes.md <<EOF",
            "which bash && cat > notes.md <<'EOF'",
            "ls /bin/zsh; cat > notes.md <<'EOF'",
            "shellcheck -s bash - <<'EOF'",
            "grep -n sh <<'EOF'",
            "cat > /tmp/zsh <<'EOF'",
            "cat > run.sh <<EOF",
        ):
            with self.subTest(intro=intro):
                got = bash(f"{intro}\n{self.BODY}\nEOF")
                self.assertIsNone(got.decision)
                self.assertEqual(got.log, [])

    def test_the_body_is_a_script(self) -> None:
        for intro in (
            "bash <<EOF",
            "sudo /bin/bash <<'EOF'",
            "FOO=1 env sh -s <<EOF",
            "cat <<EOF | sh",
            "cat <<'EOF' | sudo bash -s",
            "if true; then bash <<EOF",
            "true && zsh <<EOF",
        ):
            with self.subTest(intro=intro):
                self.assertEqual(bash(f"{intro}\n{self.BODY}\nEOF").decision, "ask")

    def test_a_comment_after_a_subshell(self) -> None:
        got = bash("(make)# don't\nfurrow epic done e-1 # can't")
        self.assertEqual(got.decision, "ask")


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
