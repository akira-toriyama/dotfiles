#!/bin/sh
# Claude Code CLI (claude) の宣言的インストール。入れ方は公式 native installer に一本化する。
#
# なぜ native か:
# ・claude は毎日のように更新が出る主力ツールで、常に最新へ張り付きたい。native バイナリは
#   起動時/定期にバックグラウンドで自己更新するので "入れておけば最新" になる。
# ・cask(upgrade=false) / nix store(immutable) / mise npm(自己更新しない) は、いずれも
#   構造的に版が遅れる。なので「版まで宣言して pin」せず、"存在" だけここで保証し、更新は
#   ツール本体に委ねる（= reproducibility と currency を両立させる唯一の形）。
# ・claude-maint.nix の月次 launchd ジョブは ~/.local/bin/claude を PATH 経由で引く
#   (home/modules/default.nix の home.sessionPath にも ~/.local/bin を追加済み)。
#
# 冪等: 既に ~/.local/bin/claude があれば何もしない（installer 自体も再実行安全）。
# 実行契機: このスクリプト本文の hash が変わると chezmoi が再実行する（run_onchange）。
#   新 Mac では install.sh の `chezmoi apply` ステップで初回実行され、自動導入される。
set -e

if [ -x "$HOME/.local/bin/claude" ]; then
  echo "claude-code 既にインストール済み ($HOME/.local/bin/claude) → skip"
  exit 0
fi

echo "==> Claude Code CLI を公式 native installer で導入"
curl -fsSL https://claude.ai/install.sh | bash
