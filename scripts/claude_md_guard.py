#!/usr/bin/env python3
"""global CLAUDE.md の再肥大・剥離を止めるゲート（scripts/lint の claude-md-guard）。

2026-07 に常時ロードされる global CLAUDE.md が 5 週で 1.6KB→33.8KB に肥大し、
0 ベース再構成（PR #294 / #295）で ~10KB に戻した。このゲートはその再発防止で、
どれも「既に踏んだ失敗」への対処（rule of two 適合）:

1. サイズ上限 — 肥大の再演を PR で止める（超えたら削るか、機構/正典へ移す）。
2. 具体 model ID の pin 禁止 — `claude-opus-4-8` のような版付き ID を書くと
   世代交代で文書と実体がずれる（実際にずれた実績・台帳参照）。
3. 台帳同期 — CLAUDE.md に触る変更は docs/claude-md-ledger.md も同一 PR で
   触る（PR #274 が同一 PR 更新を落とした実績）。escape は commit footer
   `Ledger-unchanged: <理由>`。origin/main が引けない環境では skip
   （lint job は fetch-depth: 0 なので CI では常に引ける）。
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLAUDE_MD = "chezmoi/private_dot_claude/CLAUDE.md"
LEDGER = "docs/claude-md-ledger.md"
SETTINGS = "chezmoi/private_dot_claude/modify_settings.json"

# 2026-07-28 の 0 ベース着地 10,180 bytes + 約 13% の余裕。上げる時は「何を足す
# 価値が余裕分を上回るか」を PR で言えること（黙って上げるならこのゲートは無意味）。
SIZE_LIMIT_BYTES = 11_500

# 版付き model ID（alias の "opus[1m]" や素の "fable" は通る）。
MODEL_ID_RE = re.compile(r"claude-(?:opus|sonnet|haiku|fable)-[0-9][0-9a-z-]*")

LEDGER_ESCAPE_RE = re.compile(r"^Ledger-unchanged:", re.MULTILINE)


def check_size(errors: list[str]) -> None:
    n = (ROOT / CLAUDE_MD).stat().st_size
    if n > SIZE_LIMIT_BYTES:
        errors.append(
            f"{CLAUDE_MD}: {n} bytes > {SIZE_LIMIT_BYTES} — 足した分だけ削るか、"
            "機構（hook/lint）や正典へ移す（肥大の再演を止めるゲート）"
        )


def check_model_pin(errors: list[str]) -> None:
    for rel in (CLAUDE_MD, SETTINGS):
        text = (ROOT / rel).read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            # modify_settings.json は実体が bash script で、コメントに「pin する
            # な」という負例の具体 ID が出る。効くのは実値だけなのでコメントは免除。
            if rel == SETTINGS and line.lstrip().startswith("#"):
                continue
            m = MODEL_ID_RE.search(line)
            if m:
                errors.append(
                    f"{rel}:{i}: 具体 model ID {m.group(0)!r} を書かない"
                    "（版なし alias を使う — 世代交代で文書と実体がずれた実績）"
                )


def git_lines(*args: str) -> list[str] | None:
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        return None
    return [ln for ln in proc.stdout.splitlines() if ln]


def check_ledger_sync(errors: list[str]) -> str | None:
    """CLAUDE.md に触る変更（commit 済み + working tree）は台帳も触ること。

    skip（None でなく理由文字列を返す）: origin/main が引けない場合のみ。
    """
    base = git_lines("merge-base", "origin/main", "HEAD")
    if base is None:
        return "origin/main が引けないため台帳同期チェックを skip"
    changed = git_lines("diff", "--name-only", base[0])
    if changed is None:
        return "git diff が失敗したため台帳同期チェックを skip"
    if CLAUDE_MD in changed and LEDGER not in changed:
        msgs = git_lines("log", "--format=%B", f"{base[0]}..HEAD") or []
        if not LEDGER_ESCAPE_RE.search("\n".join(msgs)):
            errors.append(
                f"{CLAUDE_MD} に触る変更が {LEDGER} を更新していない — 同一 PR で"
                "台帳の行（削除なら削除記録）を更新するか、footer "
                "`Ledger-unchanged: <理由>` を commit に書く"
            )
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ci", action="store_true", help="GitHub annotations で出力")
    args = ap.parse_args()

    errors: list[str] = []
    check_size(errors)
    check_model_pin(errors)
    skipped = check_ledger_sync(errors)
    if skipped:
        print(f"  note: {skipped}")

    for e in errors:
        print(f"::error ::{e}" if args.ci else f"  {e}")
    if not errors:
        n = (ROOT / CLAUDE_MD).stat().st_size
        print(f"  {CLAUDE_MD}: {n} bytes ≤ {SIZE_LIMIT_BYTES}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
