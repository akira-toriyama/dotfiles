#!/bin/bash
# homebrew.nix の brews / casks に 1 行宣言を追記する。
# cask か formula(brew) かは brew info で自動判定 (formula 優先)。
# drift 詳細レポート (check-homebrew-drift.sh) の「宣言:」行から呼ばれる想定。
#
# tap formula/cask (owner/repo/name 形式) の場合は taps にも自動で追記する
# (nix-darwin homebrew は宣言された tap からしか解決しないため)。
#
# Usage:
#   add-homebrew.sh --name="act" --desc="Run your GitHub Actions locally"
#   add-homebrew.sh --name="acsandmann/tap/rift"          # --desc 省略時は brew info から補完
#                                                          # tap (acsandmann/tap) も自動追記
#
# 追記後は手で `nix flake check` → PR を想定 (このスクリプトは switch しない)。
set -euo pipefail

# per-user nix profile bin も含める (ghq 等を brew から消して Nix 版に寄せた後も解決できるように)
NIX_PROFILE_BIN="/etc/profiles/per-user/$(id -un)/bin"
export PATH="/opt/homebrew/bin:${NIX_PROFILE_BIN}:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"

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

# "    <section> = [" の直後に 1 行挿入 (awk で値は -v 経由 → escaping 不要)
insert_after_block() {
  local section="$1" line="$2"
  awk -v sec="$section" -v ln="$line" '
    $0 == "    " sec " = [" { print; print ln; next }
    { print }
  ' "$HB" > "$HB.tmp" && mv "$HB.tmp" "$HB"
}

# tap formula/cask (owner/repo/name 形式) なら tap も宣言する。
# nix-darwin homebrew は宣言された tap からしか解決しないので、これが無いと
# 新 PC の switch で "No available formula/cask" になる (既存 omniwm と同じ理由)。
if [[ "$NAME" == */*/* ]]; then
  TAP="${NAME%/*}"   # owner/repo/name → owner/repo
  if grep -q "\"$TAP\"" "$HB"; then
    echo "tap 宣言済み: $TAP"
  else
    insert_after_block "taps" "      \"$TAP\"  # ${NAME##*/} 等のカスタム tap"
    echo "✓ taps に追記: $TAP"
  fi
fi

# 本体 (brews/casks) の宣言。既に宣言済みなら no-op。
if grep -q "\"$NAME\"" "$HB"; then
  echo "既に宣言済み: $NAME (homebrew.nix)"
else
  LINE="      \"$NAME\"  # ${DESC:-TODO}"
  insert_after_block "$SECTION" "$LINE"
  echo "✓ $SECTION に追記: $NAME"
  echo "    $LINE"
fi

echo
echo "次 (eval 確認 → 差分確認。zsh でそのまま貼れるよう行末コメント無し):"
echo "  cd \"$FLAKE_DIR\""
echo "  nix flake check --no-build --impure"
echo "  git add system/modules/homebrew.nix && git diff --cached"

# 宣言を反映したので drift を再チェック (md 再生成 + 通知)。
# nix eval は dirty working tree を見るので、追記分が即 declared 扱いになる。
echo
echo "→ drift 再チェック (md 再生成 + 通知)"
if command -v homebrew-drift-check >/dev/null 2>&1; then
  homebrew-drift-check >/dev/null 2>&1 || true
else
  "$FLAKE_DIR/system/modules/scripts/check-homebrew-drift.sh" >/dev/null 2>&1 || true
fi
