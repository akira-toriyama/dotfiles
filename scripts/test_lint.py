#!/usr/bin/env python3
"""scripts/lint 自身の回帰テスト。

守りたいのは 1 点に尽きる —— **走っていないゲートがあるのに緑を出さないこと**。
「ツールが無いので黙って skip して ✓ を出す」は、この repo で実害が出た失敗の形
（緑は「実行できた」証拠であって「意図した状態になった」証拠ではない）。

    python3 -m unittest scripts.test_lint      # repo ルートから
    nix develop .#lint --command python3 -m unittest discover -s scripts -p 'test_*.py'
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parent.parent


def load_lint() -> ModuleType:
    """拡張子の無い `scripts/lint` を module として読む。"""
    spec = importlib.util.spec_from_loader(
        "lint_runner",
        importlib.machinery.SourceFileLoader(
            "lint_runner", str(ROOT / "scripts" / "lint")
        ),
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


lint = load_lint()


class TestGateDeclaration(unittest.TestCase):
    def test_every_gate_belongs_to_a_known_group(self) -> None:
        self.assertEqual(set(lint.GATES.values()), set(lint.GROUPS))

    def test_groups_are_sorted_and_unique(self) -> None:
        self.assertEqual(lint.GROUPS, sorted(set(lint.GROUPS)))

    def test_the_secret_gate_exists(self) -> None:
        # gitleaks を消したら気づけるように名指しで固定する。
        self.assertIn("gitleaks", lint.GATES)
        self.assertEqual(lint.GATES["gitleaks"], "secret")


class TestOptInGroups(unittest.TestCase):
    """ネットワークを叩くゲートが既定に混ざらないこと。

    混ざると PR の合否が他人のサーバの機嫌（5xx / rate limit）で決まる。
    「入れてはいけない」を散文で書いても守られないので、ここで固定する。
    """

    def test_opt_in_groups_are_real_groups(self) -> None:
        self.assertTrue(set(lint.GROUPS) >= lint.OPT_IN_GROUPS)

    def test_the_default_run_excludes_them(self) -> None:
        self.assertEqual(
            set(lint.DEFAULT_GROUPS), set(lint.GROUPS) - lint.OPT_IN_GROUPS
        )
        self.assertFalse(set(lint.DEFAULT_GROUPS) & lint.OPT_IN_GROUPS)

    def test_the_external_link_check_is_opt_in(self) -> None:
        self.assertEqual(lint.GATES["lychee-external"], "external")
        self.assertIn("external", lint.OPT_IN_GROUPS)

    def test_a_default_runner_does_not_want_the_external_gate(self) -> None:
        r = lint.Runner(ci=False, groups=lint.DEFAULT_GROUPS)
        self.assertFalse(r.wants("lychee-external"))
        self.assertTrue(r.wants("lychee"))

    def test_naming_the_group_turns_it_on(self) -> None:
        r = lint.Runner(ci=False, groups=["external"])
        self.assertTrue(r.wants("lychee-external"))

    def test_the_offline_gate_is_not_opt_in(self) -> None:
        # 相対パス + アンカーの検査は 0 network なので PR で走り続けること。
        self.assertNotIn(lint.GATES["lychee"], lint.OPT_IN_GROUPS)


class TestMissingGateIsNotGreen(unittest.TestCase):
    """宣言したゲートが走らなかったら緑を出さない、という一番大事な性質。"""

    def test_runner_reports_missing_when_a_gate_never_ran(self) -> None:
        r = lint.Runner(ci=False, groups=["python"])
        expected = {g for g, grp in lint.GATES.items() if grp == "python"}
        # 何も走らせずに突き合わせると、全ゲートが missing になる。
        self.assertEqual(expected - r.ran, expected)
        self.assertTrue(expected, "python グループのゲートが 1 つも宣言されていない")

    def test_wants_filters_by_group(self) -> None:
        r = lint.Runner(ci=False, groups=["shell"])
        self.assertTrue(r.wants("shellcheck"))
        self.assertFalse(r.wants("ruff"))


class TestTheRunnerChecksItself(unittest.TestCase):
    """検査する側が未検査、を防ぐ。

    `scripts/lint` は拡張子が無いので ruff / mypy の自動探索に載らない。
    明示指定を外すとランナー本体だけが黙って検査対象から消えるので、ここで固定する。
    """

    def test_self_is_declared(self) -> None:
        self.assertEqual(lint.SELF, "scripts/lint")
        self.assertTrue((ROOT / lint.SELF).is_file())

    def test_self_is_not_discoverable_by_extension(self) -> None:
        # 拡張子があるなら明示指定は不要になり、この仕掛け自体が要らなくなる。
        self.assertFalse(lint.SELF.endswith(".py"))


class TestShellFileDiscovery(unittest.TestCase):
    def test_discovery_is_shebang_based_not_extension_based(self) -> None:
        found = set(lint.shell_files())
        # 拡張子が嘘をつくファイル: bash script なのに .json。
        self.assertIn("chezmoi/private_dot_claude/modify_settings.json", found)
        # 拡張子が無いファイル。
        self.assertIn(".githooks/pre-push", found)

    def test_templates_are_excluded(self) -> None:
        # .tmpl は chezmoi 構文が混ざるので raw では検査できない
        # （render 後に見るのは tmpl グループ = TestTemplateDiscovery）。
        self.assertFalse([f for f in lint.shell_files() if f.endswith(".tmpl")])

    def test_python_files_are_not_in_the_shell_set(self) -> None:
        self.assertFalse([f for f in lint.shell_files() if f.endswith(".py")])


class TestTemplateDiscovery(unittest.TestCase):
    """tmpl ゲートが「0 件を検査して緑」にならないことを固定する。

    shell_files() が .tmpl を除外している以上、tmpl 側の対象集合が空に縮退しても
    lint は ✓ を出してしまう（ゲート自体は「走った」ので missing にもならない）。
    実在ファイルを名指しで押さえるのがいちばん確実な歯止め。
    """

    def test_shell_templates_are_found(self) -> None:
        found = lint.tmpl_files(".sh.tmpl")
        self.assertIn("chezmoi/run_onchange_after_chord-validate.sh.tmpl", found)
        self.assertIn("chezmoi/run_onchange_after_azookey-bridge.sh.tmpl", found)

    def test_plist_templates_are_found(self) -> None:
        found = lint.tmpl_files(".plist.tmpl")
        self.assertIn(
            "chezmoi/private_Library/LaunchAgents/"
            "com.akira-toriyama.azookey-bridge.plist.tmpl",
            found,
        )

    def test_every_declared_suffix_has_at_least_one_target(self) -> None:
        for suffix in lint.TMPL_SUFFIXES:
            with self.subTest(suffix=suffix):
                self.assertTrue(
                    lint.tmpl_files(suffix),
                    f"{suffix} の対象が 0 件。ゲートが空振りしている",
                )

    def test_declared_suffixes_cover_every_tracked_template(self) -> None:
        """新種の .tmpl（例: .toml.tmpl）が増えたら気づけるように。

        カバーしていない .tmpl は CI の chezmoi-templates job が render 検証だけは
        するので落ちはしないが、中身の検査は誰もしていない状態になる。
        """
        uncovered = sorted(
            p
            for p in lint.tracked("*.tmpl")
            if not any(p.endswith(s) for s in lint.TMPL_SUFFIXES)
        )
        self.assertEqual(
            uncovered,
            [],
            "TMPL_SUFFIXES が見ていない .tmpl がある。検査を足すか、"
            "検査不要ならこの期待値に理由付きで足すこと",
        )


class NewFilesAreVisible(unittest.TestCase):
    """まだ add していないファイルも検査対象に入ること。

    ここが漏れると「手元は緑・push すると赤」が新規ファイルに限って起きる。
    CI はその時点で追跡済みのファイルを見るので、ローカルだけが盲目になる。
    実際に踏んだ（PR #312 の doc-paths）ので、性質として固定する。
    """

    def test_an_unadded_file_is_in_the_target_set(self) -> None:
        new = ROOT / "zz-lint-visibility-probe.md"
        self.assertFalse(new.exists(), "probe name collided with a real file")
        new.write_text("probe\n", encoding="utf-8")
        try:
            self.assertIn(new.name, lint.tracked())
        finally:
            new.unlink()

    def test_a_gitignored_file_is_not(self) -> None:
        """--exclude-standard が効いていること。生成物まで拾い始めたら別の壊れ方。"""
        ignored = ROOT / "result"
        if not ignored.exists():
            self.skipTest("no build result symlink present to use as a probe")
        self.assertNotIn("result", lint.tracked())


if __name__ == "__main__":
    unittest.main()
