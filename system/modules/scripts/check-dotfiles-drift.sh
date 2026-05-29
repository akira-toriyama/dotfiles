#!/bin/bash
# dotfiles の各種「ズレ / 忘れ」を 1 日 1 回まとめて検知し、1 件の macOS 通知に
# 集約する。launchd-drift.nix から daily 起動される。homebrew-drift を発展させた版。
#
# 検知カテゴリ:
#   1. homebrew drift  — homebrew.nix の宣言 ↔ 実 install (cask/brew 双方向)
#        ※ brew は `brew leaves` で deps を除外、top-level のみ
#        ※ 未宣言 brew は「Nix 二重」と「brew のみ」に分割
#        ※ mas は bootstrapBrewOverride で常に {} のため対象外
#   2. chezmoi drift   — source ↔ live (~/.config) の乖離 (chezmoi verify)
#        ※ re-add 忘れ (live→source 未取込) / apply 忘れ (source→live 未反映)
#          / run_onchange 保留 (R) のいずれも検知
#   3. git drift       — dotfiles repo の未 push / 滞留した未コミット
#        ※ unpushed: commit したのに origin に無い (= 新 Mac で再現できない)
#        ※ uncommitted: STALE_DAYS 日以上触られていない時だけ通知 (作業中のノイズ回避)
#
# 通知:
#   - terminal-notifier で件数サマリを 1 件だけ。詳細 (description + 対応コマンド) は
#     /tmp/dotfiles-drift-latest.md に書き出し、通知クリックで code が **新規ウィンドウ**
#     (`code -n`) で開く。
#   - 重複抑止: drift 内容の hash を記録し、**同じ drift は一度しか通知しない**
#     (内容が変われば再通知)。macOS の banner は数秒で通知センターから消えるため
#     「表示中か」での判定は不安定 → 内容 hash で判定する。週末に同じ drift が続いても
#     初回 1 回だけ。md は毎回最新に更新するので後でクリックすれば最新が開く。
#   - drift が解消したら md・hash を削除し、残っていた通知も -remove で消す。
#   - flake パスは ghq → $HOME/dotfiles → $DOTFILES_FLAKE_DIR の順で解決
#   - 実行ログ (append): /tmp/dotfiles-drift.log (launchd の Std{Out,Err}Path)
set -eu

# 「明示的に未宣言 (破棄方針)」相当の cask は通知から除外する。
# homebrew.nix 末尾コメントの破棄方針リストとは別管理。両方を更新する想定。
IGNORE_EXTRA_CASKS="google-japanese-ime karabiner-elements"

# git の未コミットは「この日数以上どのファイルも触られていない」時だけ通知する。
# 作業中 (= 最近編集) は鳴らさず、本当に忘れて放置したものだけ拾うための滞留ゲート。
STALE_DAYS=3

GROUP="dotfiles-drift"
DETAIL_FILE="/tmp/dotfiles-drift-latest.md"
# 通知済み drift の内容 hash。reboot で消えないよう /tmp でなく state dir に置く。
NOTIFIED_HASH_FILE="$HOME/.local/state/dotfiles/drift-notified.sha"
# 詳細レポートの「宣言:」行が指す helper。switch 済み環境で使う前提なので bare 名。
ADD_SH="add-homebrew"
RECHECK="dotfiles-drift-check"

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

echo "[$(date)] checking drift against $FLAKE_DIR"

count_lines() { if [ -z "$1" ]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi; }

# ============================================================
# 1. homebrew drift
# ============================================================
declared_casks=$(
  nix eval --json "$FLAKE_DIR#darwinConfigurations.default.config.homebrew.casks" --impure 2>/dev/null \
    | jq -r '.[] | if type == "object" then .name else . end' 2>/dev/null | sort || true
)
declared_brews=$(
  nix eval --json "$FLAKE_DIR#darwinConfigurations.default.config.homebrew.brews" --impure 2>/dev/null \
    | jq -r '.[] | if type == "object" then .name else . end' 2>/dev/null | sort || true
)
installed_casks=$(brew list --cask 2>/dev/null | sort || true)
installed_brews=$(brew leaves 2>/dev/null | sort || true)

extra_casks_raw=$(comm -13 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
extra_casks=$extra_casks_raw
for ignore in $IGNORE_EXTRA_CASKS; do
  extra_casks=$(echo "$extra_casks" | grep -v "^${ignore}$" || true)
done
missing_casks=$(comm -23 <(echo "$declared_casks") <(echo "$installed_casks") | grep -v '^$' || true)
extra_brews_all=$(comm -13 <(echo "$declared_brews") <(echo "$installed_brews") | grep -v '^$' || true)
missing_brews=$(comm -23 <(echo "$declared_brews") <(echo "$installed_brews") | grep -v '^$' || true)

# 未宣言 brew を「Nix 二重」と「brew のみ」に分割。
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

n_ec=$(count_lines "$extra_casks")
n_mc=$(count_lines "$missing_casks")
n_dup=$(count_lines "$dup_brews")
n_ub=$(count_lines "$undeclared_brews")
n_mb=$(count_lines "$missing_brews")

# ============================================================
# 2. chezmoi drift (source <-> live 乖離)
# ============================================================
chezmoi_status=""
if command -v chezmoi >/dev/null 2>&1; then
  cz_rc=0
  chezmoi --source "$FLAKE_DIR/chezmoi" verify >/dev/null 2>&1 || cz_rc=$?
  if [ "$cz_rc" -ne 0 ]; then
    chezmoi_status=$(chezmoi --source "$FLAKE_DIR/chezmoi" status 2>/dev/null | grep -v '^$' || true)
  fi
fi
n_cz=$(count_lines "$chezmoi_status")

# ============================================================
# 3. git drift (unpushed / 滞留 uncommitted)
# ============================================================
n_unpushed=$(git -C "$FLAKE_DIR" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
dirty=$(git -C "$FLAKE_DIR" status --porcelain 2>/dev/null | grep -v '^$' || true)
n_dirty=$(count_lines "$dirty")
n_stale=0
if [ "$n_dirty" -gt 0 ]; then
  now=$(date +%s)
  newest=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line:3}"
    case "$line" in *' -> '*) path="${line##* -> }" ;; esac
    full="$FLAKE_DIR/$path"
    [ -e "$full" ] || continue
    m=$(stat -f %m "$full" 2>/dev/null || echo 0)
    [ "$m" -gt "$newest" ] && newest=$m
  done <<< "$dirty"
  if [ "$newest" -gt 0 ]; then
    age_days=$(( (now - newest) / 86400 ))
    [ "$age_days" -ge "$STALE_DAYS" ] && n_stale=$n_dirty
  fi
fi

# ============================================================
# 集約: 何も無ければ静かに終了 (+ 残通知を消す)
# ============================================================
total=$(( n_ec + n_mc + n_dup + n_ub + n_mb + n_cz + n_unpushed + n_stale ))
if [ "$total" -eq 0 ]; then
  echo "[$(date)] no drift"
  rm -f "$DETAIL_FILE" "$NOTIFIED_HASH_FILE"
  command -v terminal-notifier >/dev/null 2>&1 && terminal-notifier -remove "$GROUP" >/dev/null 2>&1 || true
  exit 0
fi

# subtitle: 件数サマリ
subtitle_parts=""
[ "$n_ec" -gt 0 ]       && subtitle_parts="${subtitle_parts}未宣言cask${n_ec} / "
[ "$n_mc" -gt 0 ]       && subtitle_parts="${subtitle_parts}未installcask${n_mc} / "
[ "$n_dup" -gt 0 ]      && subtitle_parts="${subtitle_parts}Nix二重brew${n_dup} / "
[ "$n_ub" -gt 0 ]       && subtitle_parts="${subtitle_parts}未宣言brew${n_ub} / "
[ "$n_mb" -gt 0 ]       && subtitle_parts="${subtitle_parts}未installbrew${n_mb} / "
[ "$n_cz" -gt 0 ]       && subtitle_parts="${subtitle_parts}chezmoi乖離${n_cz} / "
[ "$n_unpushed" -gt 0 ] && subtitle_parts="${subtitle_parts}未push${n_unpushed} / "
[ "$n_stale" -gt 0 ]    && subtitle_parts="${subtitle_parts}滞留未commit${n_stale} / "
subtitle="${subtitle_parts% / }"

# 詳細レポートの description 取得
get_desc_cask() {
  brew info --cask "$1" --json=v2 2>/dev/null | jq -r '.casks[0].desc // empty' 2>/dev/null || true
}
get_desc_brew() {
  brew info --formula "$1" --json=v2 2>/dev/null | jq -r '.formulae[0].desc // empty' 2>/dev/null || true
}

# Markdown コードフェンス用ヘルパ (sh コマンドを ```sh ... ``` で囲む)。
# バッククォートは literal 出力が目的なので SC2016 を抑止。
# shellcheck disable=SC2016
fence() { printf '```sh\n%s\n```\n' "$1"; }

{
  echo "# dotfiles drift"
  echo
  echo "- 検知: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- flake: \`$FLAKE_DIR\`"
  echo "- 概要: **$subtitle**"
  echo

  # ---- chezmoi ----
  if [ "$n_cz" -gt 0 ]; then
    echo "## chezmoi 乖離 (${n_cz} 件) — source ↔ live"
    echo
    echo "> \`~/.config\` を直接編集して re-add 忘れ、または apply 忘れ。"
    echo
    echo '```'
    echo "$chezmoi_status"
    echo '```'
    echo
    echo "- 差分を見る"
    fence "chezmoi diff"
    echo "- live の編集を source に取り込む (re-add 忘れ)"
    fence "chezmoi re-add <path>   # 例: chezmoi re-add ~/.config/xxx"
    echo "- source を live に反映 (apply 忘れ / R 解消)"
    fence "chezmoi apply -v"
    echo
  fi

  # ---- git ----
  if [ "$n_unpushed" -gt 0 ] || [ "$n_stale" -gt 0 ]; then
    echo "## git (\`$FLAKE_DIR\`)"
    echo
    if [ "$n_unpushed" -gt 0 ]; then
      echo "### 未 push (${n_unpushed} commit) — origin に無い = 新 Mac で再現できない"
      fence "git -C \"$FLAKE_DIR\" push"
      echo
    fi
    if [ "$n_stale" -gt 0 ]; then
      echo "### 滞留した未コミット (${n_stale} 件, ${STALE_DAYS}日以上放置)"
      echo
      echo '```'
      echo "$dirty"
      echo '```'
      echo "- commit して PR (または chezmoi re-add 経由で取り込む)"
      echo
    fi
  fi

  # ---- homebrew ----
  if [ "$n_dup" -gt 0 ]; then
    echo "## Nix と brew で二重 install (${n_dup} 件)"
    echo
    echo "> home.packages (Nix) に同名あり → **brew 側を消す** (Nix 版が残る)。下を貼るだけ。"
    echo
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "- **$name**${desc:+ — $desc}"
      fence "brew uninstall $name"
      echo
    done <<< "$dup_brews"
    echo
  fi

  if [ "$n_ub" -gt 0 ]; then
    echo "## 未宣言 brew (${n_ub} 件) — brew のみ"
    echo
    echo "> 宣言化 (Nix に取り込む) か 削除 かを判断。"
    echo
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "### $name${desc:+ — $desc}"
      echo "- 宣言 (実行後に自動で再チェック+通知)"
      fence "$ADD_SH --name=\"$name\" --desc=\"$desc\""
      echo "- 削除"
      fence "brew uninstall $name"
      echo
    done <<< "$undeclared_brews"
    echo
  fi

  if [ "$n_ec" -gt 0 ]; then
    echo "## 未宣言 cask (${n_ec} 件) — install 済だが homebrew.nix に無い"
    echo
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_cask "$name")
      echo "### $name${desc:+ — $desc}"
      echo "- 宣言 (実行後に自動で再チェック+通知)"
      fence "$ADD_SH --name=\"$name\" --desc=\"$desc\""
      echo "- 削除"
      fence "brew uninstall --cask $name"
      echo
    done <<< "$extra_casks"
    echo
  fi

  if [ "$n_mc" -gt 0 ]; then
    echo "## 未 install cask (${n_mc} 件) — 宣言済だが install されてない"
    echo
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_cask "$name")
      echo "### $name${desc:+ — $desc}"
      echo "- install"
      fence "brew install --cask $name"
      echo "- 宣言取消: \`homebrew.nix\` の casks から該当行を削除"
      echo
    done <<< "$missing_casks"
    echo
  fi

  if [ "$n_mb" -gt 0 ]; then
    echo "## 未 install brew (${n_mb} 件) — 宣言済だが install されてない"
    echo
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      desc=$(get_desc_brew "$name")
      echo "### $name${desc:+ — $desc}"
      echo "- install"
      fence "brew install $name"
      echo "- 宣言取消: \`homebrew.nix\` の brews から該当行を削除"
      echo
    done <<< "$missing_brews"
    echo
  fi

  echo "---"
  echo
  echo "- 手動で再チェック (md 再生成 + 通知)"
  fence "$RECHECK"
  echo "- 実行ログ"
  fence "tail -30 /tmp/dotfiles-drift.log"
} > "$DETAIL_FILE"

# ============================================================
# 通知。
#   - terminal-notifier 未導入なら log だけ残して exit (新 PC 初日対策)。
#   - 既に同 group の通知が通知センターに残っていれば再通知しない (-list で判定)。
#   - クリックで code が新規ウィンドウ (-n) で詳細 md を開く。
# ============================================================
if command -v terminal-notifier >/dev/null 2>&1; then
  # drift 内容の hash (検知時刻の行は除外して安定化)。同一なら再通知しない。
  cur_hash=$(grep -v '検知:' "$DETAIL_FILE" | shasum | awk '{print $1}')
  prev_hash=$(cat "$NOTIFIED_HASH_FILE" 2>/dev/null || true)
  if [ "$cur_hash" = "$prev_hash" ]; then
    echo "[$(date)] 同一 drift を通知済みのため再通知スキップ: $subtitle (md は更新済: $DETAIL_FILE)"
  else
    terminal-notifier \
      -group "$GROUP" \
      -title "dotfiles drift" \
      -subtitle "$subtitle" \
      -message "🤖 詳細を開く" \
      -execute "/opt/homebrew/bin/code -n $DETAIL_FILE" \
      -sound Pop \
      >/dev/null 2>&1 || true
    mkdir -p "$(dirname "$NOTIFIED_HASH_FILE")"
    echo "$cur_hash" > "$NOTIFIED_HASH_FILE"
    echo "[$(date)] notified: $subtitle (詳細: $DETAIL_FILE)"
  fi
else
  echo "[$(date)] terminal-notifier not found, drift logged only: $subtitle (詳細: $DETAIL_FILE)"
fi
