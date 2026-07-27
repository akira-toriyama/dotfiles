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

# `code --install-extension` は Aqua セッションが無いと（SSH 越しの実行・headless VM
# での検証など）Electron が WindowServer に繋がれず無期限にブロックする。実測
# 2026-07-20: Tart VM を SSH 駆動した `install.sh --skip-clone` の chezmoi apply が
# この 1 行で 37 分ハングし（CPU ゼロ = 純粋な block）、install 全体が停止した。
# install.sh 側の df_step chezmoi-apply に watchdog は無いので、ここで自前で張る。
# macOS に timeout(1) は無いため background + sleep watchdog（install.sh の SSH gate
# と同じ機構）。拡張は環境の必須要素ではないので、失敗しても warn して続行する
# —— VSCode 未導入時に exit 0 で skip しているのと同じ扱い。
# shellcheck disable=SC2043  # 1 要素なのは今だけ — 拡張を足す時に行を増やす拡張点として
#                             ループの形を保つ（潰すと足す側が構造ごと書き直すことになる）
for ext in \
  anthropic.claude-code; do
  "$CODE_BIN" --install-extension "$ext" --force >/dev/null &
  ext_pid=$!
  (
    sleep 120
    kill "$ext_pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  ext_watchdog=$!
  if wait "$ext_pid" 2>/dev/null; then
    kill "$ext_watchdog" 2>/dev/null || :
  else
    kill "$ext_watchdog" 2>/dev/null || :
    echo "⚠ $ext のインストールに失敗/タイムアウト（GUI セッション外での実行が疑わしい）。" >&2
    echo "  スキップして続行する。GUI セッションで chezmoi apply を再実行すれば入る。" >&2
  fi
done
echo "VSCode 拡張のインストール完了"
