"""brew-bundle-nonfatal.sh の契約テスト。

このラッパが守るのは 1 点だけ: brew bundle が何をしようと activation を止めない。
壊れると main が赤くなるのではなく **緑のまま home-manager が飛ぶ** ので、
exit code と receipt の両方をここで固定する。fake brew を PATH に置いて回すため
Linux の CI job でもそのまま走る。
"""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parent.parent
    / "system"
    / "modules"
    / "scripts"
    / "brew-bundle-nonfatal.sh"
)

FAILING_BREW = (
    "#!/bin/sh\n"
    'echo "Installing gifski has failed!" >&2\n'
    'echo "\\`brew bundle\\` failed! 1 Brewfile dependency failed to install" >&2\n'
    "exit 1\n"
)
OK_BREW = "#!/bin/sh\nexit 0\n"


def run_wrapper(
    brew_body: str, *, preexisting_receipt: bool = False
) -> tuple[subprocess.CompletedProcess[str], str | None]:
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        brew = bindir / "brew"
        brew.write_text(brew_body, encoding="utf-8")
        brew.chmod(0o755)

        receipt = Path(d) / "state" / "brew-bundle.failed"
        if preexisting_receipt:
            receipt.parent.mkdir(parents=True, exist_ok=True)
            receipt.write_text("rc=1\nat=1970-01-01T00:00:00Z\n", encoding="utf-8")

        cmd = f'PATH="{bindir}:$PATH" env brew bundle --file=/dev/null --no-upgrade'
        proc = subprocess.run(
            ["bash", str(SCRIPT), str(receipt), cmd],
            capture_output=True,
            text=True,
            check=False,
        )
        body = receipt.read_text(encoding="utf-8") if receipt.exists() else None
        return proc, body


class TestNonFatalContract(unittest.TestCase):
    def test_failure_does_not_abort_and_leaves_a_receipt(self) -> None:
        proc, receipt = run_wrapper(FAILING_BREW)
        self.assertEqual(proc.returncode, 0, "activation を止めてはいけない")
        self.assertIsNotNone(receipt, "失敗を無音にしてはいけない")
        assert receipt is not None
        self.assertIn("rc=1", receipt)
        self.assertIn("at=", receipt)
        self.assertIn("BREW-BUNDLE-FAILED", proc.stderr)

    def test_failure_marker_goes_to_stderr_not_stdout(self) -> None:
        proc, _ = run_wrapper(FAILING_BREW)
        self.assertNotIn("BREW-BUNDLE-FAILED", proc.stdout)

    def test_success_writes_no_receipt(self) -> None:
        proc, receipt = run_wrapper(OK_BREW)
        self.assertEqual(proc.returncode, 0)
        self.assertIsNone(receipt)
        self.assertNotIn("BREW-BUNDLE-FAILED", proc.stderr)

    def test_success_clears_a_stale_receipt(self) -> None:
        # 消し忘れると過去 1 回の失敗が install.sh の RESULT を永久に FAILED にする。
        proc, receipt = run_wrapper(OK_BREW, preexisting_receipt=True)
        self.assertEqual(proc.returncode, 0)
        self.assertIsNone(receipt, "成功時に stale receipt が残ってはいけない")

    def test_unwritable_receipt_still_exits_zero_but_says_so(self) -> None:
        # 非致命化の代償が「無音」になる唯一の経路。exit 0 は保ちつつ別の語で騒ぐ。
        with tempfile.TemporaryDirectory() as d:
            bindir = Path(d) / "bin"
            bindir.mkdir()
            brew = bindir / "brew"
            brew.write_text(FAILING_BREW, encoding="utf-8")
            brew.chmod(0o755)
            blocker = Path(d) / "blocked"
            blocker.write_text("not a directory\n", encoding="utf-8")
            receipt = blocker / "brew-bundle.failed"
            cmd = f'PATH="{bindir}:$PATH" env brew bundle --file=/dev/null'
            proc = subprocess.run(
                ["bash", str(SCRIPT), str(receipt), cmd],
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(proc.returncode, 0, "書けなくても activation は止めない")
        self.assertIn("RECEIPT-WRITE-FAILED", proc.stderr)

    def test_failure_overwrites_a_stale_receipt(self) -> None:
        _, receipt = run_wrapper(FAILING_BREW, preexisting_receipt=True)
        assert receipt is not None
        self.assertNotIn("1970-01-01", receipt)


if __name__ == "__main__":
    unittest.main()
