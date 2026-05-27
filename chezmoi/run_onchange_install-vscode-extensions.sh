#!/bin/sh
# VSCode 拡張の宣言的インストール。
# VSCode 本体は cask（nix-darwin/homebrew.casks）管理だが、拡張は
# `code --install-extension` で追加するのが正攻法なので chezmoi 側で扱う。
# 拡張リストが変わるとスクリプト本文の hash が変化 → chezmoi が再実行 → 増分 install。
#
# 拡張リスト:
# - anthropic.claude-code
set -e

# cask の VSCode が提供する code バイナリ
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

if [ ! -x "$CODE_BIN" ]; then
  echo "VSCode が未導入のためスキップ（先に darwin-rebuild switch で cask を入れる）" >&2
  exit 0
fi

for ext in \
  anthropic.claude-code
do
  "$CODE_BIN" --install-extension "$ext" --force >/dev/null
done
echo "VSCode 拡張のインストール完了"
