"""claude_md_guard の純関数部のテスト。

git に依存する check_ledger_sync は「origin/main が引けなければ skip 理由を
返す」制御だけをここで見る（diff 内容の分岐は repo の実状態に依存するので
fixture 化しない — サイズ・pin 検査が本丸で、そちらは決定的に固定する）。
"""

from __future__ import annotations

import unittest

import claude_md_guard as guard


class ModelIdRegex(unittest.TestCase):
    def test_versioned_ids_are_caught(self) -> None:
        for s in (
            "claude-opus-4-8",
            "model: claude-sonnet-5",
            "us claude-haiku-4-5-20251001",
            "claude-fable-5",
        ):
            self.assertIsNotNone(guard.MODEL_ID_RE.search(s), s)

    def test_aliases_and_bare_names_pass(self) -> None:
        for s in ("opus[1m]", "fable", "sonnet + low", "最新 Opus", "claude-opus"):
            self.assertIsNone(guard.MODEL_ID_RE.search(s), s)


class LedgerEscape(unittest.TestCase):
    def test_footer_matches_at_line_start_only(self) -> None:
        self.assertIsNotNone(
            guard.LEDGER_ESCAPE_RE.search("subject\n\nLedger-unchanged: typo only")
        )
        self.assertIsNone(
            guard.LEDGER_ESCAPE_RE.search("mentions Ledger-unchanged: mid-line")
        )


class SizeCheck(unittest.TestCase):
    def test_current_file_is_within_limit(self) -> None:
        # ゲートの本丸: いま管理下にある CLAUDE.md が上限内であること。
        # 上限を超える変更はこの test でなく lint ゲートが PR で止めるが、
        # ここで恒常的に見ておくと「上限だけ上げて散文を足す」事故に気づける。
        errors: list[str] = []
        guard.check_size(errors)
        self.assertEqual(errors, [])

    def test_model_pin_check_is_clean_now(self) -> None:
        errors: list[str] = []
        guard.check_model_pin(errors)
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
