#!/bin/sh
# dotfiles repo の git hooks を有効化（pre-push の apply 忘れガード）。
#
# git は clone 同梱の hook/設定を自動では有効化しない（セキュリティ仕様）。
# そこで chezmoi apply のたびに、いま使っている clone を CHEZMOI_SOURCE_DIR
# から特定し、その repo に core.hooksPath=.githooks を best-effort で設定する。
# install.sh §3.5（~/dotfiles 向け）と冗長だが idempotent で、ghq 等
# install.sh を経ない clone でも apply 一回で効く。詳細 docs/operations.md §5.11
set -u

[ -n "${CHEZMOI_SOURCE_DIR:-}" ] || exit 0
repo=$(git -C "$CHEZMOI_SOURCE_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$repo/.githooks/pre-push" ] || exit 0

git -C "$repo" config core.hooksPath .githooks 2>/dev/null || true
