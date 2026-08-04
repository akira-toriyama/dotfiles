#!/usr/bin/env python3
"""Markdown のコードスパン内で言及されたパスが実在するかを検査する。

lychee はリンク要素しか見ない。今日見つかった切れた参照 5 件のうち 3 件は
`` `~/claude-cli-tools-memo.md` `` のように**導入時からバッククォートの中**にあり、
markdown リンクだった時期が一度も無かった —— つまり lychee には構造的に見えない。
そこを埋めるのがこのゲート。

## 前提（この検査が成り立つ理由）

**コードスパンに入れたパスは「実在する」という主張である。** 実在しないパスを
書きたい時は、コードスパンに入れないか、`ALLOW` に理由付きで載せる。

## 2 つのスコープ（混ぜると誤検知になる）

- **この repo の文書**（`docs/` / ルートの `*.md` / `scripts/**`）
  → repo 相対パスを検査する。
- **`chezmoi/private_dot_claude/` 配下**（global CLAUDE.md と skills）
  → repo 相対は**検査しない**。あそこはフリート全体の文書で、`scripts/check.sh` や
  `.github/docs/…` は**別の repo**を指す（実測: 素朴に検査すると 3 件すべてが
  この理由の誤検知だった）。`~/` の検査だけ効かせる。

`~/` は全スコープ共通で、**chezmoi 管理下にあるか `ALLOW` にあること**を要求する。
「実体があるか」で判定しないのは、CI の runner に $HOME が無いから —— 手元だけ緑に
なる検査は、この repo で実害が出た失敗の形。

    nix develop .#lint --command scripts/lint docs
    python3 scripts/doc_paths.py            # 単体でも動く
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (file, line, span, なぜ駄目か)
Problem = tuple[str, int, str, str]

# この repo の top-level ディレクトリ。コードスパンの第 1 セグメントがここに
# 一致した時だけ「repo 相対パスの主張」とみなす。
#
# これが `os/exec`・`store/fsstore`・`webpro/awesome-dotfiles`・`barutsrb/tap` の
# ような他人のパスと区別する唯一の手がかり。scripts/test_doc_paths.py が実体の
# top-level と突き合わせるので、ディレクトリを増やしたら気づける。
ROOT_DIRS = (".githooks", ".github", "chezmoi", "docs", "home", "scripts", "system")

# repo 相対の検査を掛けないディレクトリ。ここはフリート横断の文書。
FLEET_DOCS = ("chezmoi/private_dot_claude/",)

# フリート文書が **この repo のファイルを名指ししている**箇所。裸のファイル名なので
# 第 1 セグメント方式では拾えず、かといって放置すると global CLAUDE.md 側だけが
# 古い名前を指したまま残る（台帳が「リネーム時は同一 PR で追従」と書いているのに
# 強制機構が無かった分）。
#
# キー = 文書に現れる表記、値 = この repo での実際の位置。**リネームすると値が
# 消えてここが落ちる** —— それがこの表の存在理由なので、落ちたら表と文書の両方を
# 直すこと（表だけ直すと文書が古いままになる）。
FLEET_CLAIMS: dict[str, str] = {
    "packages.nix": "home/modules/packages.nix",
    # modify_settings.json / dotfiles/scripts/claude-md-eval は 0 ベース再構成
    # (2026-07-28) で global CLAUDE.md からの言及ごと消えたのでキーも撤去
    # （未使用キーは test_every_claim_is_actually_mentioned が落とす設計）。
}

# 実在を主張しないコードスパンの目印。1 つでも含めば検査対象から外す。
# glob / プレースホルダ / コマンド行 / URL / シェル展開。
NOT_A_PATH = re.compile(r"[\s*?\[\]{}<>|=$`]|\.\.\.|…|://")

CODE_SPAN = re.compile(r"`{1,2}([^`\n]+?)`{1,2}")

# chezmoi 管理外だが実在する `~/` パス。**誰が作るか**を必ず書くこと ——
# それが書けないパスは、たぶん切れた参照。
ALLOW: dict[str, str] = {
    "~/.zshrc": "home-manager の programs.zsh が生成",
    "~/.zprofile": "home-manager の programs.zsh が生成",
    "~/.claude.json": "Claude Code 自身が実行時に書く（使用量・セッション状態）",
    "~/.config/furrow/config.toml": "home-manager が生成（global 既定ボード）",
    "~/Library/Fonts": "OS のディレクトリ。cask 版フォントの配置先",
    "~/Library/Application Support": "OS のディレクトリ",
    "~/.dotfiles-install/latest": "install.sh が実行時に作る symlink",
    "~/.claude/commands": (
        "未作成。作る前提で convention-command-prefix job が待っている"
        "（作らないなら job ごと撤去 — t-pd5r のユーザー判断）"
    ),
    "~/claude-cli-tools-memo.md": (
        "現存しない。本文で「このファイルは現存しない」と明示した上での歴史的参照"
    ),
    "~/.claude/plans": (
        "Claude Code が実行時に作る。宣言管理**しない**ことが不変条件で、"
        "operations.md §5.14 はまさにそれを書いている（管理下に無いのが正しい状態）"
    ),
}


def tracked_markdown() -> list[str]:
    out = subprocess.run(
        ["git", "ls-files", "-z", "*.md"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return sorted(p for p in out.split("\0") if p)


def managed_home_paths() -> set[str]:
    """chezmoi が $HOME へ置くパスを `~/...` 表記で返す。

    属性 prefix（`dot_` / `private_` / `executable_` …）の解釈を自前で書くと
    chezmoi の実装と drift するので、chezmoi 自身に訊く。
    """
    proc = subprocess.run(
        ["chezmoi", "--source", "./chezmoi", "managed", "--path-style", "absolute"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"chezmoi managed failed: {proc.stderr.strip()}")
    home = str(Path.home())
    return {
        line.replace(home, "~", 1) if line.startswith(home) else line
        for line in proc.stdout.split("\n")
        if line.strip()
    }


def spans(text: str) -> list[str]:
    """コードスパンのうち、実在を主張していそうなものだけ。"""
    found = []
    for m in CODE_SPAN.finditer(text):
        s = m.group(1).strip().rstrip("/")
        if s and not NOT_A_PATH.search(s):
            found.append(s)
    return found


def problems_in(rel: str, text: str, managed: set[str]) -> list[Problem]:
    """1 ファイル分の判定。行ごとに走査するので行番号が実際の位置になる。

    コードスパンは改行をまたげない（CODE_SPAN が \n を除外している）ので、
    行単位で見ても全文で見ても拾う集合は同じ。同じパスが複数行に出た時に
    最初の行を 3 回報告する、という形を避けるためにこちらを採る。
    """
    fleet = rel.startswith(FLEET_DOCS)
    out: list[Problem] = []
    for lineno, line in enumerate(text.split("\n"), 1):
        for s in spans(line):
            if s.startswith("~/"):
                if s not in managed and s not in ALLOW:
                    out.append(
                        (rel, lineno, s, "chezmoi 管理下でも ALLOW でもない $HOME パス")
                    )
            elif fleet:
                target = FLEET_CLAIMS.get(s)
                if target and not (ROOT / target).exists():
                    out.append(
                        (
                            rel,
                            lineno,
                            s,
                            f"この repo の {target} を指しているが実在しない"
                            "（リネームしたら文書と FLEET_CLAIMS の両方を直す）",
                        )
                    )
            elif s.split("/")[0] in ROOT_DIRS and not (ROOT / s).exists():
                out.append((rel, lineno, s, "repo にこのパスが無い"))
    return out


def check(managed: set[str] | None = None) -> list[Problem]:
    """(file, line, span, なぜ駄目か) を返す。空なら合格。"""
    if managed is None:
        managed = managed_home_paths()
    problems: list[Problem] = []
    for rel in tracked_markdown():
        problems += problems_in(rel, (ROOT / rel).read_text(encoding="utf-8"), managed)
    return problems


def main(argv: list[str] | None = None) -> int:
    ci = "--ci" in (argv if argv is not None else sys.argv[1:])
    problems = check()
    for rel, line, span, why in problems:
        msg = f"{why}: `{span}`"
        where = f"file={rel},line={line}"
        print(f"::error {where}::{msg}" if ci else f"  {rel}:{line}: {msg}")
    print(f"  checked {len(tracked_markdown())} markdown file(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
