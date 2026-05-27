#!/bin/bash
# system/modules/homebrew.nix の宣言と実 install の drift を 1 日 1 回検知し、
# 差分があれば macOS 通知を出す。launchd-drift.nix から daily 起動される。
#
# 仕様:
#   - cask: 双方向 (未宣言 install / 未 install 宣言) の両方検出
#   - brew: missing (宣言 - install) のみ。brew leaves で top-level 比較
#   - mas:  bootstrapBrewOverride で masApps が常に {} になるため対象外
#   - 通知本文には最初の「未宣言 cask」の brew description を添える
#   - flake パスは ghq → $HOME/dotfiles → $DOTFILES_FLAKE_DIR の順で解決
#   - 出力は /tmp/homebrew-drift.log にも残る (launchd の StandardOutPath)
set -eu

# 「明示的に未宣言（破棄方針）」相当の cask は通知から除外する。
# homebrew.nix 末尾コメントの破棄方針リストとは別管理。両方を更新する想定。
IGNORE_EXTRA_CASKS="google-japanese-ime karabiner-elements"

# launchd 環境は PATH がほぼ空。Homebrew + Nix の bin を明示注入する。
PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
export PATH

FLAKE_DIR="${DOTFILES_FLAKE_DIR:-}"
if [ -z "$FLAKE_DIR" ] && command -v ghq >/dev/null 2>&1; then
  FLAKE_DIR=$(ghq list -p github.com/akira-toriyama/dotfiles 2>/dev/null | head -1)
fi
if [ -z "$FLAKE_DIR" ] && [ -d "$HOME/dotfiles" ]; then
  FLAKE_DIR="$HOME/dotfiles"
fi
if [ -z "$FLAKE_DIR" ] || [ ! -e "$FLAKE_DIR/flake.nix" ]; then
  echo "[$(date)] flake not found, skipping"
  exit 0
fi

echo "[$(date)] checking drift against $FLAKE_DIR"

# 宣言側: nix eval (失敗時は空)
declared_casks=$(
  nix eval --json "$FLAKE_DIR#darwinConfigurations.default.config.homebrew.casks" --impure 2>/dev/null \
    | jq -r '.[] | if type == "object" then .name else . end' 2>/dev/null | sort || true
)
declared_brews=$(
  nix eval --json "$FLAKE_DIR#darwinConfigurations.default.config.homebrew.brews" --impure 2>/dev/null \
    | jq -r '.[] | if type == "object" then .name else . end' 2>/dev/null | sort || true
)

# 実 install 側
installed_casks=$(brew list --cask 2>/dev/null | sort || true)
# brew leaves = top-level (依存だけで入った formula は除外)。
# 宣言に無い leaves が出ても、それは「明示 install してまだ宣言してない」もの。
installed_brews=$(brew leaves 2>/dev/null | sort || true)

# diff (POSIX: comm を使う)
extra_casks_raw=$(comm -13 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
# IGNORE_EXTRA_CASKS を除外
extra_casks=$extra_casks_raw
for ignore in $IGNORE_EXTRA_CASKS; do
  extra_casks=$(echo "$extra_casks" | grep -v "^${ignore}$" || true)
done
missing_casks=$(comm -23 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
missing_brews=$(comm -23 <(echo "$declared_brews") <(echo "$installed_brews") | grep -v '^$' || true)

# stderr/log にも残す
{
  [ -n "$extra_casks" ]   && printf '[未宣言 cask]\n%s\n' "$extra_casks"
  [ -n "$missing_casks" ] && printf '[未 install cask]\n%s\n' "$missing_casks"
  [ -n "$missing_brews" ] && printf '[未 install brew]\n%s\n' "$missing_brews"
} || true

if [ -z "$extra_casks$missing_casks$missing_brews" ]; then
  echo "[$(date)] no drift"
  exit 0
fi

# 通知本文を組み立て (空行除去 + 1 行サマリ化)
summary=""
[ -n "$extra_casks" ]   && summary="$summary 未宣言 cask: $(echo "$extra_casks" | tr '\n' ' ')"
[ -n "$missing_casks" ] && summary="$summary / 未 install cask: $(echo "$missing_casks" | tr '\n' ' ')"
[ -n "$missing_brews" ] && summary="$summary / 未 install brew: $(echo "$missing_brews" | tr '\n' ' ')"

# 最初の「未宣言 cask」だけ brew info の description を添える (なぜ入れたかのヒント)
first_extra=$(echo "$extra_casks" | head -n1)
if [ -n "$first_extra" ]; then
  desc=$(brew info --cask "$first_extra" --json=v2 2>/dev/null | jq -r '.casks[0].desc // empty' 2>/dev/null || true)
  [ -n "$desc" ] && summary="$summary - 例: $first_extra → $desc"
fi

# osascript の文字列に " が混ざるとパース崩れ。エスケープ。
escaped=$(printf '%s' "$summary" | sed 's/"/\\"/g')

osascript \
  -e "display notification \"$escaped\" with title \"homebrew drift\" subtitle \"system/modules/homebrew.nix を更新\" sound name \"Pop\"" \
  >/dev/null 2>&1 || true

echo "[$(date)] notified: $summary"
