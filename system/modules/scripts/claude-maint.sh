#!/bin/bash
# ~/.claude の自作ドキュメント (CLAUDE.md 要所トリガー索引 / commands / skills) を
# 月 1 回まとめて保守し、判断レポート付きの PR を 1 本作る。launchd (claude-maint.nix)
# から毎月 1 日に起動される。check-dotfiles-drift.sh の兄弟 (= 同じ流儀)。
#
# やること:
#   ① 集計 (機械的) : ~/.claude/projects/*/*.jsonl から各 skill / command の
#        「明示起動の回数・最終起動日」を集計。観測期間も出す。
#        ※ description トリガーの自動ロードは記録に残らない → 低/ゼロ回数でも
#          実際に有用な場合がある (この前提はプロンプトにも渡す)。
#   ② 判断 (claude -p, 頭脳) : 使用表 + 各 doc + .maint-ignore を渡し、
#        archive 候補 / 要更新 を判定。確実な更新は直接 Edit、archive は
#        .claude-maint-archive.list に列挙させる (移動はシェルがやる)。
#   ③ レポート : docs/claude-maint-reports/YYYY-MM.md を必ず生成 (=常に diff あり)。
#   ④ PR : git worktree で隔離 → commit → push → gh pr create (普通の PR)。
#
# 安全方針:
#   - ユーザの作業クローンを汚さないため git worktree で隔離して作業する。
#   - 決定論的な配管 (集計・git・移動・push・PR) はシェル。判断と内容編集だけ claude。
#   - 「低カウント = archive」はしない。誤 archive 防止は .maint-ignore (pin) と
#     プロンプトの判断ガードで二重化。
#   - PR の merge がユーザの承認点。auto-merge / main 直 push はしない。
#
# 使い方:
#   claude-maint.sh            # 本番 (worktree → PR)
#   claude-maint.sh --dry-run  # push/PR せず、レポートを /tmp に出して worktree を残す
#
# remote 非依存: dotfiles repo を ghq → $HOME/dotfiles → $DOTFILES_FLAKE_DIR の順で
# 解決し、その origin に PR を出す (akira→emmett 移行後は自動で emmett へ向く)。
set -eu

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# --- launchd は PATH がほぼ空。必要な bin を明示注入する (drift script と同方針)。----
NIX_PROFILE_BIN="/etc/profiles/per-user/$(id -un)/bin"
PATH="/opt/homebrew/bin:${NIX_PROFILE_BIN}:${HOME}/.local/share/mise/shims:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
export PATH

LOG_PREFIX="[$(date '+%F %T')] claude-maint:"
log() { echo "$LOG_PREFIX $*"; }

# 暴走コスト上限 (env で上書き可)。
MAX_BUDGET_USD="${CLAUDE_MAINT_MAX_USD:-3}"

# --- dotfiles repo 解決 (drift script から流用) -------------------------------
FLAKE_DIR="${DOTFILES_FLAKE_DIR:-}"
if [ -z "$FLAKE_DIR" ] && command -v ghq >/dev/null 2>&1; then
  FLAKE_DIR=$(ghq list -p 2>/dev/null | grep -E '/dotfiles$' | head -1 || true)
fi
if [ -z "$FLAKE_DIR" ] && [ -d "$HOME/dotfiles" ]; then
  FLAKE_DIR="$HOME/dotfiles"
fi
if [ -z "$FLAKE_DIR" ] || [ ! -e "$FLAKE_DIR/flake.nix" ]; then
  log "dotfiles repo not found, skipping"; exit 0
fi
log "repo = $FLAKE_DIR"

# --- 前提コマンド --------------------------------------------------------------
for c in claude git gh jq; do
  command -v "$c" >/dev/null 2>&1 || { log "missing command: $c — skipping"; exit 0; }
done

# --- ~/.claude のソース (chezmoi 管理) のパス ----------------------------------
# 移行中の命名 divergence (private_dot_claude vs dot_claude) を両対応。
CLAUDE_SRC=""
for cand in "chezmoi/private_dot_claude" "chezmoi/dot_claude"; do
  [ -d "$FLAKE_DIR/$cand" ] && { CLAUDE_SRC="$cand"; break; }
done
[ -n "$CLAUDE_SRC" ] || { log "claude source dir not found under $FLAKE_DIR/chezmoi — skipping"; exit 0; }
log "claude source = $CLAUDE_SRC"

YM=$(date '+%Y-%m')
BRANCH="chore/claude-maint-${YM}"

# 既に今月の PR/branch があるなら二重起動しない (月内の再実行ガード)。
if [ "$DRY_RUN" -eq 0 ] && git -C "$FLAKE_DIR" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  log "branch $BRANCH already on origin — this month already processed, skipping"; exit 0
fi

# ============================================================================
# ① 集計 (機械的)
# ============================================================================
PROJECTS="$HOME/.claude/projects"

# 候補の列挙: 実体のある自作分だけ (symlink = plugin 由来は自動除外)。
# skills: 直下の実ディレクトリ / commands: 直下の実 .md。
# (macOS の bash は 3.2 で mapfile が無いため while-read で配列化)
SKILLS=(); COMMANDS=()
while IFS= read -r line; do [ -n "$line" ] && SKILLS+=("$line"); done \
  < <(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
while IFS= read -r line; do [ -n "$line" ] && COMMANDS+=("$line"); done \
  < <(find "$HOME/.claude/commands" -maxdepth 1 -mindepth 1 -type f -name '*.md' -exec basename {} .md \; 2>/dev/null | sort)

# skill 起動の集計 (name=Skill の tool_use の .input.skill)。count + last-used。
# rg は launchd PATH に無いので grep -r を使う (/usr/bin/grep は常在)。
SKILL_STATS=$(
  grep -rhI --include='*.jsonl' '"name":"Skill"' "$PROJECTS" 2>/dev/null \
  | jq -r '.timestamp as $t | (.message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill) | "\(.)\t\($t // "-")"' 2>/dev/null \
  | awk -F'\t' '{c[$1]++; if($2>last[$1]) last[$1]=$2} END{for(k in c) printf "%s\t%d\t%s\n", k, c[k], substr(last[k],1,10)}' \
  || true
)
# command 起動の集計 (<command-name>/foo)。最終日は付けない (count 主体)。
CMD_STATS=$(
  grep -rhoEI --include='*.jsonl' 'command-name>/[A-Za-z0-9_-]+' "$PROJECTS" 2>/dev/null \
  | sed 's#.*command-name>/##' \
  | sort | uniq -c | awk '{printf "%s\t%d\n", $2, $1}' \
  || true
)
# 観測期間 (トランスクリプト .jsonl の最古〜最新 mtime を proxy に。全 timestamp 走査は重い)。
WINDOW=$(
  find "$PROJECTS" -name '*.jsonl' -type f -exec stat -f '%Sm' -t '%Y-%m-%d' {} + 2>/dev/null \
  | sort | awk 'NR==1{f=$0} {l=$0} END{if(f)printf "%s 〜 %s", f, l; else printf "(no data)"}'
)

lookup_skill() { echo "$SKILL_STATS" | awk -F'\t' -v k="$1" '$1==k{print $2" 回 / 最終 "$3; f=1} END{if(!f)print "0 回"}'; }
lookup_cmd()   { echo "$CMD_STATS"   | awk -F'\t' -v k="$1" '$1==k{print $2" 回"; f=1} END{if(!f)print "0 回"}'; }

# 使用表 (markdown) を組む。
USAGE_TABLE=$(
  echo "観測期間: ${WINDOW}"
  echo
  echo "### skills (明示起動回数)"
  for s in ${SKILLS[@]+"${SKILLS[@]}"}; do echo "- ${s}: $(lookup_skill "$s")"; done
  echo
  echo "### commands (起動回数)"
  for c in ${COMMANDS[@]+"${COMMANDS[@]}"}; do echo "- ${c}: $(lookup_cmd "$c")"; done
)
log "usage aggregated (skills=${#SKILLS[@]} commands=${#COMMANDS[@]})"

# .maint-ignore (除外/pin) — live を正とする。無ければ空。
IGNORE_FILE="$HOME/.claude/.maint-ignore"
IGNORE_CONTENT="(.maint-ignore なし)"
[ -f "$IGNORE_FILE" ] && IGNORE_CONTENT=$(grep -vE '^\s*(#|$)' "$IGNORE_FILE" || true)

# ============================================================================
# ② worktree を切って ③ claude に判断・編集させる
# ============================================================================
WT="${TMPDIR:-/tmp}/claude-maint-wt"
cleanup() { [ "$DRY_RUN" -eq 0 ] && git -C "$FLAKE_DIR" worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap cleanup EXIT

git -C "$FLAKE_DIR" worktree remove --force "$WT" >/dev/null 2>&1 || true
git -C "$FLAKE_DIR" branch -D "$BRANCH" >/dev/null 2>&1 || true   # 前回失敗の残骸を掃除
git -C "$FLAKE_DIR" fetch --quiet origin 2>/dev/null || true
# ベースは origin/main (PR を最新 main 相手に出す)。CLAUDE_MAINT_BASE で上書き可 (テスト用)。
BASE="${CLAUDE_MAINT_BASE:-origin/main}"
git -C "$FLAKE_DIR" rev-parse --verify -q "$BASE" >/dev/null 2>&1 || BASE="main"
git -C "$FLAKE_DIR" worktree add -q -b "$BRANCH" "$WT" "$BASE"
log "worktree = $WT (base $BASE)"

# base に自作 docs がまだ無い場合は何もしない (空っぽの PR を防ぐ)。
# 移行で chezmoi/private_dot_claude を main に commit する前はここで安全に抜ける。
if [ ! -d "$WT/$CLAUDE_SRC" ]; then
  log "claude source ($CLAUDE_SRC) が base $BASE に未 commit — skipping (docs commit 待ち)"
  exit 0
fi

REPORT_REL="docs/claude-maint-reports/${YM}.md"
ARCHIVE_LIST="$WT/.claude-maint-archive.list"
mkdir -p "$WT/$(dirname "$REPORT_REL")"

PROMPT=$(cat <<EOF
あなたは ~/.claude の自作ドキュメント保守担当。作業ツリーは現在の作業ディレクトリ。

## 対象 (自作分のみ。plugin / symlink は対象外)
- 索引: ${CLAUDE_SRC}/CLAUDE.md
- commands: ${CLAUDE_SRC}/commands/*.md
- skills:   ${CLAUDE_SRC}/skills/*/SKILL.md

## 除外 / pin (.maint-ignore) — これらは絶対に archive しない
${IGNORE_CONTENT}

## 使用統計
${USAGE_TABLE}

⚠️ この回数は「明示起動」のみ。description トリガーの自動ロードは記録に残らないため、
狭いトリガーの skill は回数が低/ゼロでも実際に有用なことが多い。**低回数だけを理由に
archive してはいけない。**

## やること
1. 各 doc を読む。
2. 【更新】CLAUDE.md と各 skill から参照される URL を WebFetch で、ローカル参照パスを
   Read/Glob で検証する。**確実な不具合 (リンク切れ・恒久リダイレクト先・移動したパス)
   だけ**を直接 Edit で修正する。主観的な陳腐化や書き換えは直さず、レポートに「要確認」
   として記載するに留める。
3. 【archive】次の全てを満たす doc だけを archive 候補にする:
   (a) 使われていない、かつ (b) 冗長 / 時代遅れ / 別の正本に置換済み等の積極的根拠がある、
   かつ (c) .maint-ignore で pin されていない。**迷ったら残す**。
   archive する物の **リポジトリ相対パス** を 1 行 1 件で .claude-maint-archive.list に
   書く (ファイル/ディレクトリ単位。例: ${CLAUDE_SRC}/skills/foo)。候補が無ければ空ファイルを作る。
   ※ 実際の移動はシェルが行うので、あなたはリスト化だけ。
4. レポートを ${REPORT_REL} に必ず書く (変更ゼロでも「今月は変更なし」と明記)。
   見出し: 概要 / 使用統計サマリ / 適用した更新 / archive / 要確認(人手) / keep 理由。
5. 最終メッセージは 1 行サマリだけ返す。
EOF
)

log "running claude (budget \$${MAX_BUDGET_USD}) ..."
CLAUDE_RC=0
RUN_LOG="$WT/.claude-maint-run.log"
( cd "$WT" && claude --print \
    --permission-mode acceptEdits \
    --allowedTools "Read Edit Write WebFetch Glob Grep" \
    --max-budget-usd "$MAX_BUDGET_USD" \
    --output-format text \
    "$PROMPT" ) >"$RUN_LOG" 2>&1 || CLAUDE_RC=$?
sed "s/^/$LOG_PREFIX claude| /" "$RUN_LOG" 2>/dev/null || true
rm -f "$RUN_LOG"   # PR に含めない
[ "$CLAUDE_RC" -eq 0 ] || log "claude exited rc=$CLAUDE_RC (続行: レポート有無で判断)"

# claude がレポートを書かなかった場合のフォールバック (常に PR を出すため最低限の md を置く)。
if [ ! -s "$WT/$REPORT_REL" ]; then
  log "report missing — writing fallback"
  {
    echo "# Claude ドキュメント保守 ${YM}"
    echo
    echo "- 実行: $(date '+%F %T')"
    echo "- ⚠️ claude による判断が完了しなかった (rc=$CLAUDE_RC)。使用統計のみ記録。"
    echo
    echo '## 使用統計'
    echo '```'
    echo "$USAGE_TABLE"
    echo '```'
  } > "$WT/$REPORT_REL"
fi

# ============================================================================
# ④ archive 移動 → commit → push → PR
# ============================================================================
ARCHIVE_DEST="archive/claude-docs"   # chezmoi 外 = $HOME に展開されない (履歴のみ残る)
moved=0
if [ -s "$ARCHIVE_LIST" ]; then
  while IFS= read -r rel; do
    rel="${rel#./}"; [ -z "$rel" ] && continue
    src="$WT/$rel"
    [ -e "$src" ] || { log "archive: not found, skip: $rel"; continue; }
    dest="$WT/$ARCHIVE_DEST/$(echo "$rel" | sed "s#^chezmoi/private_dot_claude/##; s#^chezmoi/dot_claude/##")"
    mkdir -p "$(dirname "$dest")"
    ( cd "$WT" && git mv "$rel" "${dest#"$WT"/}" ) && moved=$((moved+1)) && log "archived: $rel"
  done < "$ARCHIVE_LIST"
fi
rm -f "$ARCHIVE_LIST"   # PR に含めない

if [ "$DRY_RUN" -eq 1 ]; then
  cp "$WT/$REPORT_REL" "${TMPDIR:-/tmp}/claude-maint-${YM}.md" 2>/dev/null || true
  log "DRY-RUN: report → ${TMPDIR:-/tmp}/claude-maint-${YM}.md / archived=${moved} / worktree 残置: $WT"
  log "DRY-RUN: 'git -C $WT status' で変更を確認できます"
  trap - EXIT   # worktree を消さない
  exit 0
fi

cd "$WT"
git add -A
if git diff --cached --quiet; then
  log "no changes at all (想定外: レポートは常に出るはず) — skipping PR"
  exit 0
fi
git -c user.email="claude-maint@noreply" -c user.name="claude-maint" \
    commit -q -m "chore: monthly Claude docs maintenance (${YM})" \
    -m "archived: ${moved} / report: ${REPORT_REL}"
git push -q -u origin "$BRANCH"

# worktree は git remote 設定を共有するので gh は origin を自動検出する。
PR_URL=$(gh pr create \
  --head "$BRANCH" --base main \
  --title "chore: Claude docs maintenance ${YM}" \
  --body-file "$WT/$REPORT_REL" 2>&1) || { log "gh pr create failed: $PR_URL"; PR_URL=""; }
log "PR: ${PR_URL:-(作成失敗・branch は push 済)}"

# worktree を片付けてから通知 (dialog はクリックまでブロックするため先に掃除)。
cd "$HOME"
git -C "$FLAKE_DIR" worktree remove --force "$WT" >/dev/null 2>&1 || true
trap - EXIT

# --- 通知 (drift script と同じ osascript dialog 方式 / TCC 不要) ----------------
if [ -n "$PR_URL" ] && command -v osascript >/dev/null 2>&1; then
  msg="今月の Claude ドキュメント保守 PR を作成しました (archive ${moved} 件)。
${PR_URL}"
  btn=$(osascript -e "display dialog \"${msg//\"/\\\"}\" with title \"Claude docs maintenance ${YM}\" buttons {\"閉じる\",\"PR を開く\"} default button \"PR を開く\" giving up after 600" 2>/dev/null) || true
  case "$btn" in *"PR を開く"*) open "$PR_URL" >/dev/null 2>&1 || true ;; esac
fi
log "done"
