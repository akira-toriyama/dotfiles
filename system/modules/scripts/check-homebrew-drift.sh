#!/bin/bash
# system/modules/homebrew.nix の宣言と実 install の drift を 1 日 1 回検知し、
# 差分があれば macOS 通知を出す。launchd-drift.nix から daily 起動される。
#
# 仕様:
#   - cask: 双方向 (未宣言 install / 未 install 宣言) の両方検出
#   - brew: 双方向 (未宣言 install / 未 install 宣言) の両方検出
#           ※ install 側は `brew leaves` を使い deps を除外、top-level のみ比較
#           ※ 未宣言 brew はさらに 2 分類:
#               - Nix と brew で二重 (Nix profile bin に同名あり) → brew 側 uninstall 推奨
#               - brew のみ → declare or uninstall 判断
#   - mas:  bootstrapBrewOverride で masApps が常に {} になるため対象外
#   - 通知: summary だけ。詳細 (description + 対応コマンド) は
#           /tmp/homebrew-drift-latest.txt に書き出し、通知クリックで code で開く。
#   - flake パスは ghq → $HOME/dotfiles → $DOTFILES_FLAKE_DIR の順で解決
#   - 通知は terminal-notifier (homebrew.nix の brews で宣言)。osascript の
#     display notification は macOS 15 で banner 抑止されがちなため不採用。
#   - -group homebrew-drift 固定で「通知センターに常に最新 1 件」運用
#   - 実行ログ (append): /tmp/homebrew-drift.log
#   - 詳細レポート (overwrite): /tmp/homebrew-drift-latest.txt
set -eu

# 「明示的に未宣言（破棄方針）」相当の cask は通知から除外する。
# homebrew.nix 末尾コメントの破棄方針リストとは別管理。両方を更新する想定。
IGNORE_EXTRA_CASKS="google-japanese-ime karabiner-elements"

DETAIL_FILE="/tmp/homebrew-drift-latest.txt"
# 詳細レポートの「宣言:」行が指す helper。FLAKE_DIR 解決後に絶対パス化する。
ADD_SH=""

# Nix (home.packages) が置く per-user profile の bin。
#   - ここに同名があれば「brew と Nix の二重 install」と判定する
#   - add-homebrew (writeShellScriptBin) もここに入るので PATH にも含める
NIX_PROFILE_BIN="/etc/profiles/per-user/$(id -un)/bin"

# launchd 環境は PATH がほぼ空。Homebrew + Nix の bin を明示注入する。
PATH="/opt/homebrew/bin:${NIX_PROFILE_BIN}:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
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

# add-homebrew は Nix (home.packages の writeShellScriptBin) で PATH に乗る。
# 未配置の新 PC では repo の実体パスにフォールバック。
if command -v add-homebrew >/dev/null 2>&1; then
  ADD_SH="add-homebrew"
else
  ADD_SH="$FLAKE_DIR/system/modules/scripts/add-homebrew.sh"
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
installed_brews=$(brew leaves 2>/dev/null | sort || true)

# diff
extra_casks_raw=$(comm -13 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
extra_casks=$extra_casks_raw
for ignore in $IGNORE_EXTRA_CASKS; do
  extra_casks=$(echo "$extra_casks" | grep -v "^${ignore}$" || true)
done
missing_casks=$(comm -23 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
extra_brews_all=$(comm -13 <(echo "$declared_brews") <(echo "$installed_brews") | grep -v '^$' || true)
missing_brews=$(comm -23 <(echo "$declared_brews") <(echo "$installed_brews") | grep -v '^$' || true)

# 未宣言 brew を「Nix 二重」と「brew のみ」に分割。
# tap prefix (a/b/name) は basename を取って Nix profile bin と突き合わせる。
dup_brews=""
undeclared_brews=""
while IFS= read -r name; do
  [ -z "$name" ] && continue
  base="${name##*/}"
  if [ -e "$NIX_PROFILE_BIN/$base" ]; then
    dup_brews="${dup_brews}${name}"$'\n'
  else
    undeclared_brews="${undeclared_brews}${name}"$'\n'
  fi
done <<< "$extra_brews_all"
dup_brews=$(echo "$dup_brews" | grep -v '^$' || true)
undeclared_brews=$(echo "$undeclared_brews" | grep -v '^$' || true)

if [ -z "$extra_casks$missing_casks$dup_brews$undeclared_brews$missing_brews" ]; then
  echo "[$(date)] no drift"
  rm -f "$DETAIL_FILE"
  exit 0
fi

# 件数
count_lines() { if [ -z "$1" ]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi; }
n_ec=$(count_lines "$extra_casks")
n_mc=$(count_lines "$missing_casks")
n_dup=$(count_lines "$dup_brews")
n_ub=$(count_lines "$undeclared_brews")
n_mb=$(count_lines "$missing_brews")

# subtitle: 件数サマリ
subtitle_parts=""
[ "$n_ec" -gt 0 ]  && subtitle_parts="${subtitle_parts}未宣言 cask ${n_ec} / "
[ "$n_mc" -gt 0 ]  && subtitle_parts="${subtitle_parts}未 install cask ${n_mc} / "
[ "$n_dup" -gt 0 ] && subtitle_parts="${subtitle_parts}Nix二重 brew ${n_dup} / "
[ "$n_ub" -gt 0 ]  && subtitle_parts="${subtitle_parts}未宣言 brew ${n_ub} / "
[ "$n_mb" -gt 0 ]  && subtitle_parts="${subtitle_parts}未 install brew ${n_mb} / "
subtitle="${subtitle_parts% / }件 drift"

# 詳細レポートの description 取得
get_desc_cask() {
  brew info --cask "$1" --json=v2 2>/dev/null | jq -r '.casks[0].desc // empty' 2>/dev/null || true
}
get_desc_brew() {
  brew info --formula "$1" --json=v2 2>/dev/null | jq -r '.formulae[0].desc // empty' 2>/dev/null || true
}

{
  echo "homebrew drift detected at $(date '+%Y-%m-%d %H:%M:%S')"
  echo "flake: $FLAKE_DIR"
  echo
  echo "概要: $subtitle"
  echo

  if [ "$n_dup" -gt 0 ]; then
    echo "============================================================"
    echo "■ Nix と brew で二重 install (${n_dup} 件)"
    echo "  home.packages (Nix) に同名があるので brew 側を消すのが正。"
    echo "  ↓ そのまま貼って実行 (Nix 版が残る):"
    echo "------------------------------------------------------------"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "・$name${desc:+  ($desc)}"
      echo "    brew uninstall $name"
    done <<< "$dup_brews"
    echo
  fi

  if [ "$n_ub" -gt 0 ]; then
    echo "============================================================"
    echo "■ 未宣言 brew (${n_ub} 件) — brew のみ。宣言化 or 削除を判断"
    echo "------------------------------------------------------------"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "・$name${desc:+  ($desc)}"
      echo "    宣言: $ADD_SH --name=\"$name\" --desc=\"$desc\""
      echo "    削除: brew uninstall $name"
    done <<< "$undeclared_brews"
    echo
  fi

  if [ "$n_ec" -gt 0 ]; then
    echo "============================================================"
    echo "■ 未宣言 cask (${n_ec} 件) — install 済だが homebrew.nix に無い"
    echo "------------------------------------------------------------"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_cask "$name")
      echo "・$name${desc:+  ($desc)}"
      echo "    宣言: $ADD_SH --name=\"$name\" --desc=\"$desc\""
      echo "    削除: brew uninstall --cask $name"
    done <<< "$extra_casks"
    echo
  fi

  if [ "$n_mc" -gt 0 ]; then
    echo "============================================================"
    echo "■ 未 install cask (${n_mc} 件) — 宣言済だが install されてない"
    echo "------------------------------------------------------------"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_cask "$name")
      echo "・$name${desc:+  ($desc)}"
      echo "    install: brew install --cask $name"
      echo "    宣言取消: homebrew.nix の casks から削除"
    done <<< "$missing_casks"
    echo
  fi

  if [ "$n_mb" -gt 0 ]; then
    echo "============================================================"
    echo "■ 未 install brew (${n_mb} 件) — 宣言済だが install されてない"
    echo "------------------------------------------------------------"
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "・$name${desc:+  ($desc)}"
      echo "    install: brew install $name"
      echo "    宣言取消: homebrew.nix の brews から削除"
    done <<< "$missing_brews"
    echo
  fi

  echo "============================================================"
  echo "再チェック: launchctl kickstart -p gui/\$UID/org.nixos.homebrew-drift"
  echo "実行ログ: tail -30 /tmp/homebrew-drift.log"
} > "$DETAIL_FILE"

# 通知。terminal-notifier 未導入なら log だけ残して exit (新 PC 初日対策)。
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -group "homebrew-drift" \
    -title "homebrew drift" \
    -subtitle "$subtitle" \
    -message "クリックで詳細を開く (code $DETAIL_FILE)" \
    -execute "/opt/homebrew/bin/code $DETAIL_FILE" \
    -sound Pop \
    >/dev/null 2>&1 || true
  echo "[$(date)] notified: $subtitle (詳細: $DETAIL_FILE)"
else
  echo "[$(date)] terminal-notifier not found, drift logged only: $subtitle (詳細: $DETAIL_FILE)"
fi
