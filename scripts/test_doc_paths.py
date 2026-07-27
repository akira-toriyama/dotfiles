#!/usr/bin/env python3
"""scripts/doc_paths.py の回帰テスト。

守りたいのは 2 つ。
1. **誤検知を出さないこと** —— 誤検知が続くゲートは無視されるようになり、
   本物の切れた参照も一緒に無視される。ここで潰した誤検知の型を固定する。
2. **見逃さないこと** —— 実在しない repo 相対パスと、素性の分からない `~/` パスは
   必ず捕まえる。
"""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

import doc_paths

ROOT = Path(__file__).resolve().parent.parent


class TestRootDirs(unittest.TestCase):
    def test_matches_the_real_top_level_of_the_repo(self) -> None:
        """top-level を増やしたらここが落ちる（＝ ROOT_DIRS の更新を強制する）。

        更新を忘れると、その新ディレクトリ配下のパス言及だけ黙って無検査になる。
        """
        out = subprocess.run(
            ["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout
        live = {p.split("/")[0] for p in out.split("\n") if "/" in p}
        self.assertEqual(set(doc_paths.ROOT_DIRS), live)


class TestSpanFiltering(unittest.TestCase):
    """コードスパンのうち「実在を主張しているもの」だけを拾えているか。"""

    def spans(self, text: str) -> list[str]:
        return doc_paths.spans(f"`{text}`")

    def test_a_plain_path_is_picked_up(self) -> None:
        self.assertEqual(self.spans("docs/operations.md"), ["docs/operations.md"])

    def test_a_trailing_slash_is_stripped(self) -> None:
        self.assertEqual(self.spans("docs/"), ["docs"])

    def test_globs_are_not_paths(self) -> None:
        for s in ("chezmoi/private_*.tmpl", "home/modules/*.nix", "Sources/*"):
            self.assertEqual(self.spans(s), [], s)

    def test_placeholders_are_not_paths(self) -> None:
        for s in ("system/hosts/<hostname>.nix", "bodies/<id>.md", "chezmoi/..."):
            self.assertEqual(self.spans(s), [], s)

    def test_command_lines_are_not_paths(self) -> None:
        for s in (
            "glyph lint --range origin/main..HEAD",
            "nix develop .#lint --command scripts/lint",
            "go run ./cmd/furrow <args>",
        ):
            self.assertEqual(self.spans(s), [], s)

    def test_urls_are_not_paths(self) -> None:
        # lychee の担当。ここで二重に見ると報告が重複する。
        self.assertEqual(self.spans("https://github.com/akira-toriyama/dotfiles"), [])

    def test_shell_expansions_are_not_paths(self) -> None:
        for s in ('$(op read "op://Vault/Item/field")', "GHQ_ROOT=/Volumes/workspace"):
            self.assertEqual(self.spans(s), [], s)


class TestRepoRelativeRule(unittest.TestCase):
    def test_only_first_segments_in_root_dirs_are_checked(self) -> None:
        """他人の repo のパスを掴まないこと。

        skills は Go や fleet の話をするので `os/exec` や `store/fsstore` が出る。
        素朴に「/ を含むもの」を検査すると全部誤検知になる。
        """
        for s in ("os/exec", "store/fsstore", "webpro/awesome-dotfiles", "owner/repo"):
            self.assertEqual(doc_paths.ROOT_DIRS.count(s.split("/")[0]), 0, s)

    def test_a_bare_filename_is_not_checked(self) -> None:
        """`packages.nix` はルートに無いがサブディレクトリには在る。

        第 1 セグメントが ROOT_DIRS に無いので対象外 —— 曖昧な参照を無理に
        解決しにいかない、という設計上の割り切り。
        """
        self.assertEqual(doc_paths.spans("`packages.nix`"), ["packages.nix"])
        self.assertNotIn("packages.nix", doc_paths.ROOT_DIRS)


class TestHomeRule(unittest.TestCase):
    def test_a_chezmoi_managed_path_is_accepted_without_an_allow_entry(self) -> None:
        managed = doc_paths.managed_home_paths()
        self.assertIn("~/.claude/CLAUDE.md", managed)
        self.assertNotIn("~/.claude/CLAUDE.md", doc_paths.ALLOW)

    def test_every_allow_entry_carries_a_reason(self) -> None:
        """理由を書けないパスは、たぶん切れた参照。空文字を通さない。"""
        for path, reason in doc_paths.ALLOW.items():
            self.assertTrue(reason.strip(), path)
            self.assertTrue(path.startswith("~/"), path)

    def test_allow_does_not_duplicate_what_chezmoi_already_manages(self) -> None:
        """管理下に入ったのに ALLOW に残っていると、外した時に検知できなくなる。"""
        managed = doc_paths.managed_home_paths()
        overlap = sorted(set(doc_paths.ALLOW) & managed)
        self.assertEqual(overlap, [], "chezmoi 管理下に入ったので ALLOW から外すこと")


class TestFleetClaims(unittest.TestCase):
    """global CLAUDE.md / skills が名指しした dotfiles のファイルが実在するか。

    台帳は「リネーム時は同一 PR で追従」と書いていたが強制機構が無く、
    global CLAUDE.md だけ古い名前を指したまま残る形が空いていた。
    """

    def fleet_text(self) -> str:
        out = subprocess.run(
            ["git", "ls-files", "-z", "chezmoi/private_dot_claude/"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        return "\n".join(
            (ROOT / p).read_text(encoding="utf-8")
            for p in out.split("\0")
            if p.endswith(".md")
        )

    def test_every_claimed_target_exists(self) -> None:
        for span, target in doc_paths.FLEET_CLAIMS.items():
            with self.subTest(span=span):
                self.assertTrue((ROOT / target).exists(), f"{span} -> {target}")

    def test_every_claim_is_actually_mentioned(self) -> None:
        """使われなくなったキーが残ると、守っているつもりで何も守らなくなる。"""
        text = self.fleet_text()
        for span in doc_paths.FLEET_CLAIMS:
            with self.subTest(span=span):
                self.assertIn(f"`{span}`", text)

    def test_a_renamed_target_is_caught(self) -> None:
        saved = dict(doc_paths.FLEET_CLAIMS)
        try:
            doc_paths.FLEET_CLAIMS["packages.nix"] = "home/modules/renamed-away.nix"
            problems = doc_paths.check(managed=set())
            self.assertTrue(
                any(s == "packages.nix" for _, _, s, _ in problems),
                "リネームを検知できていない",
            )
        finally:
            doc_paths.FLEET_CLAIMS.clear()
            doc_paths.FLEET_CLAIMS.update(saved)


class TestTheRepoIsClean(unittest.TestCase):
    def test_no_dangling_path_mentions(self) -> None:
        """このゲートが今の repo で緑であること（回帰の入口）。"""
        self.assertEqual(doc_paths.check(), [])


if __name__ == "__main__":
    unittest.main()
