#!/bin/sh
# Claude Code MCP servers（user scope）の宣言的登録。~/.claude.json は claude CLI が
# 所有する runtime ファイルで chezmoi 管理に置けない（One file, one owner）ため、
# 「登録コマンドの冪等再実行」という形で宣言する（furrow t-dxrp）。
#
# ・playwright: mise shim の絶対パスで npx を指す（PATH 非依存。node の版が変わっても
#   シムのパスは不変）。--output-dir で生成物（page-*.yml snapshot / console-*.log /
#   screenshot）を $TMPDIR 配下へ向ける: 既定は CWD/.playwright-mcp で、開いていた repo
#   の作業ツリーに落ちる。global gitignore で commit は防いでいるが、snapshot は操作中の
#   ページ本文をそのまま含む（2026-11-09 に GitHub の PAT 生成ページの token 値入り yml が
#   作業ツリーに残った）ので、置き場自体を作業ツリー外・OS が掃除する一時領域にする。
#   TMPDIR は macOS の per-user 一時領域（0700、未使用 3 日で掃除）。MCP 自身も CWD が
#   書けない時は os.tmpdir() に逃がすので、同じ場所に揃える。
# ・github（remote http）: 登録までは宣言可能。OAuth 同意だけは端末ごとに 1 回の対話が
#   要り宣言不可 — 未同意の間 `claude mcp list` は ✘ を出すが、実害は接続時のみ。
#   対話セッションの /mcp から同意する。
#
# 冪等: remove→add で常にこの宣言値へ収束させる（既存スキップ方式だと、宣言を変えた
# 時に live が追随しない）。
# 実行契機: 本文 hash 変更（run_onchange）。新 Mac では install.sh の chezmoi apply で
# 初回実行される。ファイル名が install-claude-code より後にソートされるのは意図
# （chezmoi は同フェーズの script を名前順に実行する。claude CLI 導入後に走らせる）。
set -e

CLAUDE_BIN="$HOME/.local/bin/claude"
if [ ! -x "$CLAUDE_BIN" ]; then
  if command -v claude >/dev/null 2>&1; then
    CLAUDE_BIN="$(command -v claude)"
  else
    echo "⚠ claude CLI が無い（install-claude-code 未完？）→ skip。導入後に再度 chezmoi apply するか、本 script のコマンドを手動実行" >&2
    exit 0
  fi
fi

echo "==> MCP servers を user scope へ登録（remove→add で宣言値に収束）"
# macOS の TMPDIR は末尾 / 付き（/var/folders/…/T/）なので、そのまま連結すると
# 登録値が `T//playwright-mcp` になる。既定を当ててから末尾 / を剥がす。
pw_out="${TMPDIR:-/tmp}"
pw_out="${pw_out%/}/playwright-mcp"
"$CLAUDE_BIN" mcp remove -s user playwright >/dev/null 2>&1 || true
"$CLAUDE_BIN" mcp add -s user playwright -- "$HOME/.local/share/mise/shims/npx" -y "@playwright/mcp@latest" --output-dir "$pw_out"
"$CLAUDE_BIN" mcp remove -s user github >/dev/null 2>&1 || true
"$CLAUDE_BIN" mcp add -s user --transport http github "https://api.githubcopilot.com/mcp/"
echo "==> 登録完了（github の OAuth 同意だけは対話セッションの /mcp で端末ごとに 1 回）"
