"""claude-vncdo-guard の判定テスト。

台帳がこの guard に「unit 9 ケース実測」と書いていたが、テストは存在しなかった
（2026-08-19 検出）。この file がその主張を実体にする。固定する境界:

  止める  : deadline 無しの vncdo 実行 / uppercase keysym / help フラグが
            別 segment にある deadline 無し実行
  止めない: --timeout / -t 付き / lowercase keysym / --help・--version の
            probe（VNC に接続しないので hang しえない）/ 文字列言及のみ /
            対象外 tool / 壊れた stdin / 明示 escape marker
"""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-vncdo-guard"


def run_guard(stdin: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT)],
        input=stdin,
        capture_output=True,
        text=True,
        check=False,
    )


def bash_call(command: str) -> str:
    return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})


class VncdoGuardTest(unittest.TestCase):
    # --- 止める側 ---

    def test_deny_no_deadline(self) -> None:
        p = run_guard(bash_call("vncdo -s host::5900 capture out.png"))
        self.assertEqual(p.returncode, 2)
        self.assertIn("--timeout", p.stderr)

    def test_deny_uppercase_keysym(self) -> None:
        p = run_guard(bash_call("vncdo --timeout 10 -s host::5900 key Down"))
        self.assertEqual(p.returncode, 2)
        self.assertIn("lowercase", p.stderr)

    def test_deny_help_in_other_segment(self) -> None:
        # help フラグが vncdo と別の pipeline segment にある場合は免除しない
        p = run_guard(bash_call("vncdo -s h capture x.png; foo --help"))
        self.assertEqual(p.returncode, 2)

    def test_deny_path_prefixed_invocation(self) -> None:
        p = run_guard(bash_call("/usr/local/bin/vncdo -s h capture x.png"))
        self.assertEqual(p.returncode, 2)

    # --- 止めない側 ---

    def test_allow_with_long_timeout(self) -> None:
        p = run_guard(bash_call("vncdo --timeout 25 -s h -p pw capture out.png"))
        self.assertEqual(p.returncode, 0)

    def test_allow_with_short_timeout(self) -> None:
        p = run_guard(bash_call("vncdo -t 10 -s h key down"))
        self.assertEqual(p.returncode, 0)

    def test_allow_help_probe(self) -> None:
        # 実測誤爆 2026-08-19: `vncdo --help 2>&1 | grep timeout` が deny された
        p = run_guard(bash_call("vncdo --help 2>&1 | grep timeout"))
        self.assertEqual(p.returncode, 0)

    def test_allow_version_probe(self) -> None:
        p = run_guard(bash_call("vncdo --version"))
        self.assertEqual(p.returncode, 0)

    def test_allow_mention_only(self) -> None:
        p = run_guard(bash_call("grep -n 'vncdo without --timeout' docs/notes.md"))
        self.assertEqual(p.returncode, 0)

    def test_allow_non_bash_tool(self) -> None:
        p = run_guard(
            json.dumps({"tool_name": "Read", "tool_input": {"file_path": "/x"}})
        )
        self.assertEqual(p.returncode, 0)

    def test_allow_broken_stdin(self) -> None:
        p = run_guard("this is not json")
        self.assertEqual(p.returncode, 0)

    def test_allow_escape_marker(self) -> None:
        p = run_guard(bash_call("CLAUDE_ALLOW_RAW_VNCDO=1 vncdo -s h capture x.png"))
        self.assertEqual(p.returncode, 0)


if __name__ == "__main__":
    unittest.main()
