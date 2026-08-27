#!/usr/bin/env python3
"""宣言付き和訳レビュー写し（`*.ja.md`）の契約を守るゲート。

scripts/lint の review-copy-guard。

正典 = .github の docs/doc-consistency-policy.md「Exception — declared review copies」
（2026-08-25 裁定）。写しは非正本で、**正本と同一の変更では更新しない** — 遅れてよく、
遅れは冒頭ヘッダの `基準: 英語版 @ <sha>` に pin して宣言する。

ここで見るのは「既に踏んだ失敗」1 件だけ（rule of two 適合。2026-08-27 に 2 回）:
PR #358 と #359 が英語正本と `*.ja.md` を同一 commit で触り、しかもヘッダの基準 sha を
進めなかった。結果ヘッダは「基準 = 古い sha」と宣言したまま中身だけ新しくなり、
「遅れは宣言されている」という契約そのものが崩れた（写しが何を訳したのか誰にも言えない）。
同時更新を止めれば、写しは常に宣言どおり基準 commit の内容になる。

escape は commit footer `Review-copy-co-update: <理由>`（rename や一括移動など、
同時に触るのが正しい変更のため）。origin/main が引けない環境では skip
（lint job は fetch-depth: 0 なので CI では常に引ける）。

ヘッダの語（和訳 / 正本 / 基準）自体の検査は fleet 側 repo-policy-check.sh が持つ。
ここで重複して見ない。
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CO_UPDATE_ESCAPE_RE = re.compile(r"^Review-copy-co-update:", re.MULTILINE)


def git_lines(*args: str) -> list[str] | None:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        return None
    return [ln for ln in proc.stdout.splitlines() if ln]


def canonical_of(path: str) -> str | None:
    """`docs/x.ja.md` → `docs/x.md`。写しでなければ None。"""
    if not path.endswith(".ja.md"):
        return None
    return path[: -len(".ja.md")] + ".md"


def co_updated_pairs(changed: list[str]) -> list[tuple[str, str]]:
    """同一変更で正本と写しの両方に触れている組。"""
    changed_set = set(changed)
    pairs = []
    for path in sorted(changed_set):
        canonical = canonical_of(path)
        if canonical is not None and canonical in changed_set:
            pairs.append((canonical, path))
    return pairs


def check_co_update(errors: list[str]) -> str | None:
    """正本と写しを同一変更（commit 済み + 作業樹）で触らないこと。"""
    base = git_lines("merge-base", "origin/main", "HEAD")
    if base is None:
        return "origin/main が引けないため写し同時更新チェックを skip"
    changed = git_lines("diff", "--name-only", base[0])
    if changed is None:
        return "git diff が失敗したため写し同時更新チェックを skip"
    pairs = co_updated_pairs(changed)
    if not pairs:
        return None
    msgs = git_lines("log", "--format=%B", f"{base[0]}..HEAD") or []
    if CO_UPDATE_ESCAPE_RE.search("\n".join(msgs)):
        return None
    for canonical, copy in pairs:
        errors.append(
            f"{canonical} と写し {copy} を同一変更で更新している — 写しは正本に"
            "追随させない（遅れてよい・遅れはヘッダの基準 sha が宣言する）。"
            "写し側の変更を別 PR に分けるか、footer "
            "`Review-copy-co-update: <理由>` を commit に書く"
        )
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ci", action="store_true", help="GitHub annotations で出力")
    args = ap.parse_args()

    errors: list[str] = []
    skipped = check_co_update(errors)
    if skipped:
        print(f"review-copy-guard: {skipped}", file=sys.stderr)

    for msg in errors:
        if args.ci:
            print(f"::error::{msg}")
        else:
            print(f"review-copy-guard: {msg}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
