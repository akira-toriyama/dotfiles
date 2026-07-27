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
        # .tmpl は chezmoi 構文が混ざるので raw では検査できない。
        self.assertFalse([f for f in lint.shell_files() if f.endswith(".tmpl")])

    def test_python_files_are_not_in_the_shell_set(self) -> None:
        self.assertFalse([f for f in lint.shell_files() if f.endswith(".py")])


if __name__ == "__main__":
    unittest.main()
