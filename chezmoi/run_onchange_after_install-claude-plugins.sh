#!/bin/sh
# Claude Code plugin の宣言的インストール。現状は JetBrains の
# modern-go-guidelines 1本（go-dev skill が「新 stdlib API の索引」として使う。
# 採否の根拠と使用時のガードレールは skills/go-dev/SKILL.md 側）。
#
# なぜ settings.json のシードと二本立てか:
# ・modify_settings.json (#11) が seed するのは extraKnownMarketplaces と
#   enabledPlugins の2キーだけ＝「どれを有効にするか」の宣言。実体（CLI 本体と
#   ルールを抱えた ~/.claude/plugins/ 配下のキャッシュ）は落ちてこない。
# ・キーだけある新 Mac で Claude Code が起動時に自動取得してくれるかは**未測定**
#   （隔離 config での検証が認証を通せなかった）。取得されるなら下は no-op、
#   されないならここが唯一の入口になる。どちらでも正しいので両方置く。
# ・~/.claude/plugins/ 自体は state ディレクトリなので chezmoi の管理対象に
#   しない（バイナリキャッシュと .in_use の PID が入る）。
#
# 冪等: 既に導入済みなら何もしない。
# fail-soft: plugin は補助であって前提ではないので、ネットワーク不通などで
# 失敗しても警告だけ出して apply 全体は落とさない（claude 本体を入れる
# run_onchange_after_install-claude-code.sh が set -e で固いのとは対照的＝
# あちらは前提、こちらは補助）。
set -u

MARKETPLACE_REPO='JetBrains/go-modern-guidelines'
MARKETPLACE_NAME='goland-claude-marketplace'
PLUGIN="modern-go-guidelines@${MARKETPLACE_NAME}"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude が PATH に無い → plugin 導入を skip" >&2
  exit 0
fi

if claude plugin list 2>/dev/null | grep -q "modern-go-guidelines"; then
  echo "claude plugin 既に導入済み ($PLUGIN) → skip"
  exit 0
fi

echo "==> Claude Code plugin を導入: $PLUGIN"

if ! claude plugin marketplace add "$MARKETPLACE_REPO" 2>&1; then
  echo "warn: marketplace 追加に失敗 ($MARKETPLACE_REPO) → plugin 導入を見送り" >&2
  exit 0
fi

if ! claude plugin install "$PLUGIN" --scope user 2>&1; then
  echo "warn: plugin 導入に失敗 ($PLUGIN) → 次回 apply で再試行される" >&2
  exit 0
fi

echo "==> 導入完了: $PLUGIN"
