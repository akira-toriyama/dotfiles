"""review_copy_guard の純関数部のテスト。

git に依存する check_co_update は repo の実状態に依存するので fixture 化しない
（claude_md_guard の同期チェックと同じ方針）。本丸は「どの組を同時更新と見なすか」
の判定で、そこは決定的に固定する。
"""

from __future__ import annotations

import unittest

import review_copy_guard as guard


class CanonicalOf(unittest.TestCase):
    def test_copy_maps_to_its_original(self) -> None:
        self.assertEqual(guard.canonical_of("docs/glossary.ja.md"), "docs/glossary.md")
        self.assertEqual(guard.canonical_of("CLAUDE.ja.md"), "CLAUDE.md")
        self.assertEqual(
            guard.canonical_of("chezmoi/private_dot_claude/CLAUDE.ja.md"),
            "chezmoi/private_dot_claude/CLAUDE.md",
        )

    def test_non_copies_map_to_nothing(self) -> None:
        for path in (
            "docs/glossary.md",
            "scripts/lint",
            # `.ja.` を含まない・末尾が .ja の紛らわしい名前は対象外
            "docs/ja.md",
            "docs/notes.ja",
            "docs/ja-policy.md",
        ):
            self.assertIsNone(guard.canonical_of(path), path)


class CoUpdatedPairs(unittest.TestCase):
    def test_original_and_copy_together_is_a_pair(self) -> None:
        self.assertEqual(
            guard.co_updated_pairs(["docs/glossary.md", "docs/glossary.ja.md"]),
            [("docs/glossary.md", "docs/glossary.ja.md")],
        )

    def test_either_side_alone_is_clean(self) -> None:
        # 写しだけ触る = 人間の指示による追随（本来の運用）
        self.assertEqual(guard.co_updated_pairs(["docs/glossary.ja.md"]), [])
        # 正本だけ触る = 写しは遅れてよい（宣言済み）
        self.assertEqual(guard.co_updated_pairs(["docs/glossary.md"]), [])
        self.assertEqual(guard.co_updated_pairs([]), [])

    def test_unrelated_pairs_do_not_match(self) -> None:
        # 別文書どうしなので組にならない
        self.assertEqual(
            guard.co_updated_pairs(["docs/glossary.md", "docs/operations.ja.md"]), []
        )

    def test_every_offending_pair_is_reported(self) -> None:
        changed = [
            "docs/glossary.md",
            "docs/glossary.ja.md",
            "docs/operations.md",
            "docs/operations.ja.md",
            "scripts/lint",
        ]
        self.assertEqual(
            guard.co_updated_pairs(changed),
            [
                ("docs/glossary.md", "docs/glossary.ja.md"),
                ("docs/operations.md", "docs/operations.ja.md"),
            ],
        )


class CoUpdateEscape(unittest.TestCase):
    def test_footer_matches_at_line_start_only(self) -> None:
        self.assertIsNotNone(
            guard.CO_UPDATE_ESCAPE_RE.search(
                "subject\n\nReview-copy-co-update: renamed both sides"
            )
        )
        self.assertIsNone(
            guard.CO_UPDATE_ESCAPE_RE.search("mentions Review-copy-co-update: mid-line")
        )


if __name__ == "__main__":
    unittest.main()
