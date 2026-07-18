#!/bin/sh
# ~/.claude の memory を別 PC へ引き継ぐための橋渡し。
#
# 何を: Claude Code の memory ディレクトリ
#   ~/.claude/projects/<home-slug>/memory
# を、ghq で clone した private repo
#   $(ghq root)/github.com/akira-toriyama/claude-memory
# への symlink にする。これで「ghq clone が単一ソース・Claude パスはただの link」に
# なり、全マシンで同一・再現可能になる（memory を別途 clone する特別扱いは不要）。
#
# なぜ symlink か:
# ・claude-memory は ghq-get-mine が既に clone する（install.sh §6.5）。それを link
#   するだけで済む＝ghq 一元管理という既存流儀に一致。
# ・home-slug は $HOME を "/"→"-" した文字列（/Users/tommy → -Users-tommy）。repo の
#   どこにも計算箇所が無いのでここで導出する（house 流儀＝$HOME はランタイム展開）。
#
# 冪等: 既に正しい symlink なら何もしない。
# 保護: memory が「実ディレクトリ（in-place .git を持つ既存機）」なら壊さず skip する
#   （uniform 化＝ghq へ mv して link し直す移行は、事故防止のため手動に委ねる）。
# 実行契機: 本文 hash が変われば chezmoi が再実行（run_onchange）。新 Mac では
#   install.sh の `chezmoi apply` で初回実行される。ghq/SSH は §4/§5 で準備済み。
set -e

slug=$(printf '%s' "$HOME" | tr / -)          # /Users/tommy -> -Users-tommy
mem="$HOME/.claude/projects/$slug/memory"
clone="$(ghq root)/github.com/akira-toriyama/claude-memory"

# 冪等: 既に正しく link 済み
if [ -L "$mem" ] && [ "$(readlink "$mem")" = "$clone" ]; then
  echo "claude-memory 既に link 済み ($mem -> $clone) → skip"
  exit 0
fi

# 保護: 実ディレクトリ（symlink でない）は壊さない（in-place .git の既存機）
if [ -e "$mem" ] && [ ! -L "$mem" ]; then
  echo "note: $mem は実ディレクトリ → 保護のため何もしない（uniform 化は手動: ghq へ mv して link）" >&2
  exit 0
fi

# private clone が無ければ ghq get（-p=SSH）。失敗しても bootstrap は止めない
# （§6.5 ghq-get-mine と次回 chezmoi apply が引き継ぐ）
if [ ! -d "$clone/.git" ]; then
  echo "==> claude-memory を ghq get"
  if ! ghq get -p akira-toriyama/claude-memory; then
    echo "note: ghq get 失敗（SSH 未準備 等）→ 後続 ghq-get-mine / 次回 apply で再試行" >&2
    exit 0
  fi
fi

# 古い broken symlink を掃除して張り直し
mkdir -p "$(dirname "$mem")"
ln -sfn "$clone" "$mem"
echo "==> linked $mem -> $clone"
