#!/bin/bash
# nix-darwin の brew bundle 呼び出しを非致命化するラッパ。homebrew-nonfatal.nix が
# activation script の中から呼ぶ。
#
# なぜ必要か: activation script は set -e で走り、断片は activation-scripts.nix の
# :138 (homebrew) → :140 (postActivation = home-manager) の固定順で連結される。
# brew bundle が 1 formula でも落とすと home-manager activation にも
# /run/current-system の世代更新にも到達しない (2026-08-26 実測)。formula の可用性は
# upstream / runner 側の事情で壊れるので、ユーザレイヤ全体をそれの人質にしない。
#
# 契約:
#   - 常に exit 0。activation を止めない
#   - 失敗は receipt に残す。無音にはしない。読み手は install.sh の V6-brew-bundle
#   - receipt は実行前に必ず消す。消し忘れると過去の失敗が永久に FAILED を作る
#
# 不変条件: $2 は外部コマンドであること。eval はこのシェルで走るので `exit` を含む
# 文字列を渡すと結局 activation が死ぬ。
set -uo pipefail

receipt="$1"
brew_bundle_cmd="$2"

mkdir -p "$(dirname "$receipt")"
rm -f "$receipt"

# upstream が組み立てた 1 本のコマンド文字列をそのまま実行する。分割すると
# PATH=... sudo ... env ... の前置き代入が壊れる。
# shellcheck disable=SC2294
eval "$brew_bundle_cmd"
rc=$?

if [ "$rc" -ne 0 ]; then
  printf 'rc=%s\nat=%s\n' "$rc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$receipt"
  printf >&2 'dotfiles: BREW-BUNDLE-FAILED rc=%s receipt=%s (activation continues)\n' "$rc" "$receipt"
fi

exit 0
