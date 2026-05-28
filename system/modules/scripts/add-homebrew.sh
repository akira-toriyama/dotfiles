#!/bin/bash
# homebrew.nix の brews / casks に 1 行宣言を追記する。
# cask か formula(brew) かは brew info で自動判定 (formula 優先)。
# drift 詳細レポート (check-homebrew-drift.sh) の「宣言:」行から呼ばれる想定。
#
# Usage:
#   add-homebrew.sh --name="act" --desc="Run your GitHub Actions locally"
#   add-homebrew.sh --name="acsandmann/tap/rift"          # --desc 省略時は brew info から補完
#
# 追記後は手で `nix flake check` → PR を想定 (このスクリプトは switch しない)。
set -euo pipefail

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"

NAME=""
DESC=""
for arg in "$@"; do
  case "$arg" in
    --name=*) NAME="${arg#--name=}" ;;
    --desc=*) DESC="${arg#--desc=}" ;;
    *) echo "unknown arg: $arg (使い方: --name=... [--desc=...])" >&2; exit 1 ;;
  esac
done
[ -z "$NAME" ] && { echo "--name は必須" >&2; exit 1; }

# flake dir 解決
FLAKE_DIR="${DOTFILES_FLAKE_DIR:-}"
if [ -z "$FLAKE_DIR" ] && command -v ghq >/dev/null 2>&1; then
  FLAKE_DIR=$(ghq list -p github.com/akira-toriyama/dotfiles 2>/dev/null | head -1)
fi
[ -z "$FLAKE_DIR" ] && [ -d "$HOME/dotfiles" ] && FLAKE_DIR="$HOME/dotfiles"
[ -z "$FLAKE_DIR" ] && { echo "flake が見つからない" >&2; exit 1; }
HB="$FLAKE_DIR/system/modules/homebrew.nix"

# cask / formula 判定 (formula 優先 = CLI が多いため)
if brew info --formula "$NAME" >/dev/null 2>&1; then
  SECTION="brews"
elif brew info --cask "$NAME" >/dev/null 2>&1; then
  SECTION="casks"
else
  echo "error: '$NAME' は formula でも cask でも見つからない" >&2
  exit 1
fi

# desc 省略時は brew info から補完 (推奨値)
if [ -z "$DESC" ]; then
  if [ "$SECTION" = "brews" ]; then
    DESC=$(brew info --formula "$NAME" --json=v2 2>/dev/null | jq -r '.formulae[0].desc // empty' || true)
  else
    DESC=$(brew info --cask "$NAME" --json=v2 2>/dev/null | jq -r '.casks[0].desc // empty' || true)
  fi
fi

# 既に宣言済みなら no-op
if grep -q "\"$NAME\"" "$HB"; then
  echo "既に宣言済み: $NAME (homebrew.nix)" >&2
  exit 0
fi

# "    SECTION = [" の直後に 1 行挿入 (awk で値は -v 経由 → escaping 不要)
LINE="      \"$NAME\"  # ${DESC:-TODO}"
awk -v sec="$SECTION" -v ln="$LINE" '
  $0 == "    " sec " = [" { print; print ln; next }
  { print }
' "$HB" > "$HB.tmp" && mv "$HB.tmp" "$HB"

echo "✓ $SECTION に追記: $NAME"
echo "    $LINE"
echo
echo "次:"
echo "  cd \"$FLAKE_DIR\""
echo "  nix flake check --no-build --impure   # eval 確認"
echo "  git add system/modules/homebrew.nix && git diff --cached"
