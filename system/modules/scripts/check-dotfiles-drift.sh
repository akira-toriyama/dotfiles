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
# 設計方針 (全ての「新 PC で再現できない」穴をこの check でカバーはしない):
#   - 「source が綺麗に再現できるか」は CI の switch-smoke が別途実証する。本 check は
#     その CI が原理的に見られない「live にあるが source に無い」穴だけを担当する。
#   - 静的に分かる穴 (モジュール配線忘れ = orphan 等) は CI 側で弾く (マージ前ブロック)。
#   - あえて検知しない / できない穴 (accept・defer):
#       ⑤ masApps        : mas 上流バグで凍結中の既知ギャップ
#       ⑥ 1Password 参照  : テンプレに op:// が無いうちは対象外 (参照追加時に resolver 検討)
#       ⑦ 管理外 GUI 設定 : 追跡是非は意図問題 → chezmoi add する運用規律で対応
#       未宣言の手動 defaults: どれを再現したいかは意図問題で原理的に検知不能
#         (defaults は「宣言済キーが実 live と一致するか」の逆監査のみ担当する)
#
# 通知:
#   - osascript の display dialog で 画面中央にウィンドウ を出す。通知許可ゲートが無い
#     (アプリ自身のダイアログ = TCC 対象外) ので、環境構築だけで機能する
#     (terminal-notifier 方式で要った「通知許可を手動 ON」の人手が不要になる)。
#   - 件数サマリを表示し、「詳細を開く」で詳細 (description + 対応コマンド) を
#     /tmp/dotfiles-drift-latest.md から code の新規ウィンドウ (`code -n`) で開く。
#   - 悪い状態が続く限り毎回 (= 毎朝 9:00 の起動ごとに) 出す。重複抑止はしない:
#     dotfiles/ が壊れている間は毎日リマインドが欲しいという運用方針。timeout 無し =
#     押すまで残る。md は毎回最新に更新。
#   - drift が解消したら md を削除する。
#   - flake パスは ghq → $HOME/dotfiles → $DOTFILES_FLAKE_DIR の順で解決
#   - 実行ログ (append): /tmp/dotfiles-drift.log (launchd の Std{Out,Err}Path)
set -eu

# 「明示的に未宣言 (破棄方針)」相当の cask は通知から除外する。
# homebrew.nix 末尾コメントの破棄方針リストとは別管理。両方を更新する想定。
IGNORE_EXTRA_CASKS="google-japanese-ime karabiner-elements"

# git の未コミットは「この日数以上どのファイルも触られていない」時だけ通知する。
# 作業中 (= 最近編集) は鳴らさず、本当に忘れて放置したものだけ拾うための滞留ゲート。
#
# ⚠️ トレードオフ (再現性の穴): この滞留ゲートは「直近 STALE_DAYS 日以内に触った
# 未コミット」を意図的に黙らせる。裏返すと、編集して数日以内に新 Mac を install.sh で
# 構築すると、その変更は commit/push されておらず origin に無いため新 PC で欠落するのに
# 通知は一度も出ない (= 無音の再現漏れ)。「作業中のうるささ回避」と「直近未コミットの
# 再現漏れ検知」は両立しないため日数で線引きしている。再現性を厳しくしたいなら日数を
# 縮める / 未コミットを別カテゴリで即通知する等を検討する。
STALE_DAYS=3

DETAIL_FILE="/tmp/dotfiles-drift-latest.md"
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
  rm -f "$DETAIL_FILE" "$HOME/.local/state/dotfiles/drift-notified.sha"
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
#   - osascript の display dialog で画面中央にウィンドウを出す。通知許可ゲートが無い
#     (アプリ自身のダイアログ = TCC 対象外) ため、環境構築だけで機能する。
#   - LaunchAgent は gui/<uid> セッションで動くので dialog を描画できる。画面ロック中 /
#     ログイン前はセッションが有効になった時に出る (launchd の catch-up)。
#   - 「詳細を開く」で code が新規ウィンドウ (-n) で詳細 md を開く。timeout 無し =
#     押すまで残る。GUI セッションが無い文脈 (CI / ssh 等) では出せず log だけ残す。
#   - subtitle は固定文字列 + 件数のみ (外部入力なし) なので dialog 文字列に直に埋める。
# ============================================================
if command -v osascript >/dev/null 2>&1; then
  dialog_msg="${subtitle}

「詳細を開く」で対応コマンド付きレポートを表示します。"
  btn=$(osascript <<OSA 2>/dev/null
display dialog "${dialog_msg}" with title "⚠ dotfiles drift" buttons {"閉じる", "詳細を開く"} default button "詳細を開く" with icon caution
OSA
) || true
  case "$btn" in
    *"詳細を開く"*)
      /opt/homebrew/bin/code -n "$DETAIL_FILE" >/dev/null 2>&1 \
        || open "$DETAIL_FILE" >/dev/null 2>&1 || true
      ;;
  esac
  echo "[$(date)] notified (dialog): $subtitle (詳細: $DETAIL_FILE)"
else
  echo "[$(date)] osascript not found, drift logged only: $subtitle (詳細: $DETAIL_FILE)"
fi
