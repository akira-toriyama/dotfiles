#!/bin/sh
# 新 Mac の環境再現ブートストラップ（単一ステージ・無人一気通貫）。
#
# 事前準備（初期化直後・在席。GUI 操作はここに全部front-load する）:
#   1. システム設定 → プライバシーとセキュリティ → フルディスクアクセス → Terminal ON
#      （付与後 Terminal を Cmd-Q で再起動）
#   2. 1Password.app を手動インストール → iPhone の QR でサインイン → 設定 → 開発者 →
#      SSH agent ON → セキュリティ → 自動ロックのタイマーを OFF（スリープ時ロックは残す）
#      → ~/.ssh/config に IdentityAgent 行があることを確認（1Password が設定画面で示す
#        snippet。無ければその内容で作る。これが無いと ssh は素の macOS agent(鍵ゼロ)を向く）
#      → `ssh -o StrictHostKeyChecking=accept-new -T git@github.com` を 1 回実行し、
#      1Password の承認ダイアログで「すべてのアプリで承認する」+ 認証
#   3. GitHub fine-grained PAT（All repositories / Metadata: Read-only で足りる。t-8f19）を
#      1Password からコピーし、ワンライナーと同じターミナルで `export GH_TOKEN=<PAT>`
#      （ghq-get-mine の repo 一覧取得と clone 完全性検証が gh API を使うため。無いと
#      ✓ 完了 に到達できないので P1-ghtoken で即 fail する）
#   4. `sudo -v`（このあとのワンライナーと同じターミナルで）
#
# 実行（ここから先はパスワード入力・GUI 操作ゼロ。clone と claude-memory link まで完走）:
#
#   sudo -v && sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
#
#   CLT → workspace volume → Determinate Nix(.pkg) → repo clone → darwin-rebuild switch
#   → chezmoi apply → 1Password agent 経由 SSH 確認 → ghq-get-mine → claude-memory link
#   → 事後条件検証。✓ 完了 は全 phase + 検証を通過した時だけ出る。
#
# リカバリ入口（SSH gate で落ちた時など。前段 phase を再評価せず clone 以降だけ実行）:
#
#   sh ~/dotfiles/install.sh --phase2
#
# 同じワンライナーの再実行も安全（全 phase 冪等。導入済み部分は skip される）。
#
# 引数:
#   --phase2       ... clone 以降（SSH gate → ghq-get-mine → link → 検証）だけを実行
#   --skip-clone   ... SSH gate・clone・clone 検証を行わない（VM 実験用）。
#                      結果は最大でも PARTIAL（✓ 完了 は出ない）
# 環境変数:
#   BRANCH / REPO_DIR / FLAKE_USER / FLAKE_HOST / DOTFILES_LOG_DIR
#   DOTFILES_SKIP_FDA_GATE=1 ... FDA preflight を飛ばす（VM 実験用）
#   DOTFILES_SUDO_RULE=...    ... bootstrap 中の sudoers drop-in 内容を上書き（VM 実験用）
#
# 詳細設計: docs/reproduction-architecture.md / 検証は Tart VM（docs/operations.md）
set -e

GITHUB_USERNAME="akira-toriyama"
BRANCH="${BRANCH:-main}"
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
FLAKE_HOST="${FLAKE_HOST:-default}"
WORKSPACE_ROOT="/Volumes/workspace"
HM_PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"

MODE=full
SKIP_CLONE=0
for arg in "$@"; do
  case "$arg" in
    --phase2) MODE=phase2 ;;
    --skip-clone) SKIP_CLONE=1 ;;
    *)
      printf 'install.sh: 未知のオプション: %s (使えるのは --phase2 / --skip-clone のみ)\n' "$arg" >&2
      exit 2
      ;;
  esac
done

# ── logging prelude（FIFO + background tee。実測検証済みの機構）─────────────────
# - `exec > >(tee)` は /bin/sh(bash 3.2 POSIX モード) で構文エラー
# - `{ body } | tee` はサブシェル化で exit が死に偽成功が再発する
# - script(1) は pty を強制し nix 出力を ANSI/CR で汚す
# → FIFO なら本体がトップレベルのまま = set -e / exit / trap がそのまま効く。
DF_LOG_ROOT="${DOTFILES_LOG_DIR:-$HOME/.dotfiles-install}"
DF_RUN_ID="$(date +%Y%m%d-%H%M%S)-$MODE"
DF_RUN_DIR="$DF_LOG_ROOT/$DF_RUN_ID"
DF_LOG="$DF_RUN_DIR/install.log"
DF_EVENTS="$DF_RUN_DIR/events.tsv"
DF_SUMMARY="$DF_RUN_DIR/summary.txt"
DF_DETAIL="$DF_RUN_DIR/detail"

if ! mkdir -p "$DF_DETAIL" 2>/dev/null || ! : > "$DF_LOG" 2>/dev/null; then
  echo "FATAL: ログ出力先を用意できない: $DF_RUN_DIR" >&2
  exit 1
fi
: > "$DF_EVENTS"
printf '#ts\ttype\tname\trc\n' >> "$DF_EVENTS"
ln -sfn "$DF_RUN_ID" "$DF_LOG_ROOT/latest"

# リダイレクト前に実端末へ出す（後段でハングしても在り処が分かる）
echo "install.sh($MODE) log: $DF_LOG"
echo "              summary: $DF_LOG_ROOT/latest/summary.txt"

DF_FIFO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dfinstall.XXXXXX")"
mkfifo -m 600 "$DF_FIFO_DIR/pipe"
# tee は SIG_IGN を継承して Ctrl-C を生き延び、FIFO を最後まで drain する
trap '' INT
tee -a "$DF_LOG" < "$DF_FIFO_DIR/pipe" &
DF_TEE_PID=$!
trap - INT
# fd 3 = 実端末（tee を畳んだ後でも人間向けに 1 行出せる）
exec 3>&1
exec > "$DF_FIFO_DIR/pipe" 2>&1
rm -f "$DF_FIFO_DIR/pipe"
rmdir "$DF_FIFO_DIR" 2>/dev/null || :

DF_PHASE="bootstrap"
DF_STEP_FAILURES=0
DF_REACHED_END=0
DF_SUDO_RULE_PLANTED=0
SUDOERS_DROPIN=/etc/sudoers.d/dotfiles-bootstrap

df_now() { date +%Y-%m-%dT%H:%M:%S; }
df_say() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

df_phase() {
  DF_PHASE="$1"
  printf '%s\tPHASE\t%s\t-\n' "$(df_now)" "$1" >> "$DF_EVENTS"
  printf '\n[%s] ===== PHASE %s =====\n' "$(date +%H:%M:%S)" "$1"
}

# df_step <name> <plain|quiet> <cmd...>
#   quiet は出力を detail/<name>.log へ隔離（chezmoi の 3000 行 diff などのノイズ対策）。
#   引数は events.tsv に書かない（secret が argv に載り得るため。house rule）。
# df_step_try = リトライ前提の 1 試行。events には TRY で記録し DF_STEP_FAILURES に
#   数えない（数えると「attempt 1 失敗 → attempt 2 成功」の正常回復まで RESULT が
#   FAILED になる偽失敗が出る。成否の正本は各 phase 末尾の df_check_ok/fail）。
df_step()     { df_step_impl STEP "$@"; }
df_step_try() { df_step_impl TRY "$@"; }
df_step_impl() {
  df_step_evt="$1"
  df_step_name="$2"
  df_step_mode="$3"
  shift 3
  printf '%s\tSTEP_START\t%s\t-\n' "$(df_now)" "$df_step_name" >> "$DF_EVENTS"
  df_say "--- step $df_step_name"
  if [ "$df_step_mode" = quiet ]; then
    df_step_out="$DF_DETAIL/$df_step_name.log"
    if "$@" > "$df_step_out" 2>&1; then df_step_rc=0; else df_step_rc=$?; fi
    df_say "    output -> detail/$df_step_name.log ($(wc -l < "$df_step_out" | tr -d ' ') lines)"
    if [ "$df_step_rc" -ne 0 ]; then
      df_say "    tail of detail/$df_step_name.log:"
      tail -n 30 "$df_step_out" | sed 's/^/    | /'
    fi
  else
    if "$@"; then df_step_rc=0; else df_step_rc=$?; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$(df_now)" "$df_step_evt" "$df_step_name" "$df_step_rc" >> "$DF_EVENTS"
  if [ "$df_step_rc" -ne 0 ]; then
    if [ "$df_step_evt" = STEP ]; then
      DF_STEP_FAILURES=$((DF_STEP_FAILURES + 1))
      df_say "STEP-FAIL $df_step_name rc=$df_step_rc"
    else
      df_say "try-fail $df_step_name rc=$df_step_rc（リトライ/フォールバックで回復を試みる）"
    fi
  fi
  return "$df_step_rc"
}

# 事後条件違反の記録（fail しても flow は止めない。RESULT は必ず FAILED になる）
df_check_fail() {
  DF_STEP_FAILURES=$((DF_STEP_FAILURES + 1))
  printf '%s\tCHECK\t%s\t1\n' "$(df_now)" "$1" >> "$DF_EVENTS"
  df_say "  ✘ CHECK [$1] $2"
}
df_check_ok() { df_say "  ok [$1] $2"; }

# shellcheck disable=SC2329  # trap EXIT から呼ばれる
df_finish() {
  df_rc=$?
  set +e
  # bootstrap 用 sudoers drop-in の後始末（SIGKILL 死の残骸は次回起動時 self-heal が拾う）
  if [ "$DF_SUDO_RULE_PLANTED" = 1 ]; then
    sudo -n rm -f "$SUDOERS_DROPIN" 2>/dev/null
    if [ -f "$SUDOERS_DROPIN" ]; then
      df_say "WARNING: $SUDOERS_DROPIN を削除できていない。手動で削除すること"
    else
      df_say "sudoers drop-in 削除済み"
    fi
  fi

  if [ "$df_rc" -ne 0 ]; then
    df_verdict=FAILED
  elif [ "$DF_REACHED_END" != "1" ]; then
    df_verdict=ABORTED; df_rc=99
  elif [ "$DF_STEP_FAILURES" -gt 0 ]; then
    df_verdict=FAILED; df_rc=1
  elif [ "$SKIP_CLONE" = 1 ]; then
    df_verdict=PARTIAL
  else
    df_verdict=OK
  fi
  printf '%s\tEND\t%s\t%s\n' "$(df_now)" "$df_verdict" "$df_rc" >> "$DF_EVENTS"

  printf '\n[%s] ================ RESULT ================\n' "$(date +%H:%M:%S)"
  printf 'RESULT: %s (exit %s)\n' "$df_verdict" "$df_rc"
  awk -F'\t' '($2=="STEP"||$2=="CHECK") && $4!="0"{printf "FAIL %s\n", $3}' "$DF_EVENTS"
  case "$df_verdict" in
    OK)
      printf '\n✓ 完了。全 phase + 事後条件検証を通過。新しいターミナルを開いて使用開始。\n' ;;
    PARTIAL)
      printf '\nPARTIAL: --skip-clone のため未完（ghq-get-mine と claude-memory link が残っている）\n' ;;
    *)
      printf '\nNEXT: 上の FAIL を直し、同じコマンドを再実行（冪等）。\n'
      printf '     SSH gate (P-onepassword) 起因なら 1Password の サインイン / SSH agent ON /\n'
      printf '     鍵承認 を確認して "sh %s/install.sh --phase2" が最短。詳細: %s\n' "$REPO_DIR" "$DF_SUMMARY" ;;
  esac
  printf 'summary: %s\nlog:     %s\n' "$DF_SUMMARY" "$DF_LOG"

  # tee を畳んで install.log を完成させてから summary を直接書く
  exec >/dev/null 2>&1
  wait "$DF_TEE_PID" 2>/dev/null || :
  {
    echo "result=$df_verdict"
    echo "exit_code=$df_rc"
    echo "mode=$MODE"
    echo "step_failures=$DF_STEP_FAILURES"
    printf 'failed=%s\n' \
      "$(awk -F'\t' '($2=="STEP"||$2=="CHECK") && $4!="0"{printf "%s ", $3}' "$DF_EVENTS")"
    echo "last_phase=$DF_PHASE"
    echo "reached_end=$DF_REACHED_END"
    echo "run_id=$DF_RUN_ID"
    echo "log=$DF_LOG"
    echo "events=$DF_EVENTS"
    echo "--- steps ---"
    awk -F'\t' '$2=="STEP"||$2=="CHECK"{printf "%-4s %s rc=%s\n", ($4=="0"?"ok":"FAIL"), $3, $4}
                $2=="TRY"{printf "%-4s %s rc=%s\n", ($4=="0"?"ok":"try"), $3, $4}' "$DF_EVENTS"
    awk -F'\t' '$2=="STEP" && $4!="0"{print $3}' "$DF_EVENTS" | while IFS= read -r df_f; do
      if [ -f "$DF_DETAIL/$df_f.log" ]; then
        echo "--- detail/$df_f.log (last 30) ---"
        tail -n 30 "$DF_DETAIL/$df_f.log"
      fi
    done
    echo "--- last 40 log lines ---"
    tail -n 40 "$DF_LOG" 2>/dev/null
  } > "$DF_SUMMARY" 2>&1

  printf 'install.sh(%s): RESULT %s (exit %s) — %s\n' "$MODE" "$df_verdict" "$df_rc" "$DF_SUMMARY" >&3
  exit "$df_rc"
}
trap df_finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# ===== logging prelude ここまで =====

# ── 共有ヘルパ（full と --phase2 の両方が使う）─────────────────────────────────
# CLT 判定。/usr/bin/git は shim（実行すると CLT 不在時に GUI ダイアログ）なので
# 判定に使わない。phase2 でも git を叩く前に必ずこれで確認する。
CLT_DIR=/Library/Developer/CommandLineTools
clt_ok() {
  [ -x "$CLT_DIR/usr/bin/git" ] && return 0
  clt_dp=$(/usr/bin/xcode-select -p 2>/dev/null) || return 1
  [ -n "$clt_dp" ] && [ -x "$clt_dp/usr/bin/git" ]
}

# gh 認証の前提 gate。ghq-get-mine（gh repo list）と V5b が gh API を必要とし、
# 無いと ✓ 完了 に構造的に到達できないため、長い phase に入る前に即 fail させる。
df_gate_ghtoken() {
  if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
    df_check_ok P1-ghtoken "GH_TOKEN/GITHUB_TOKEN あり"
  elif env PATH="$HM_PATH:$PATH" gh auth status >/dev/null 2>&1; then
    df_check_ok P1-ghtoken "gh auth 済み"
  else
    df_check_fail P1-ghtoken "gh の認証が無い"
    df_say "  fine-grained PAT（All repositories / Metadata: Read-only）を 1Password からコピーし、"
    df_say "  \`export GH_TOKEN=<PAT>\` してから再実行すること（事前準備 3）"
    exit 1
  fi
}

# ── 事後条件検証（システム層）。full の終盤 と --phase2 の両方から呼ぶ ──────────────
run_verify_system() {
  df_phase verify-system
  # 「終わった」を主張する前に事実を確認する。/etc/profiles/per-user/$USER/bin に
  # コマンドが揃うのは useUserPackages 由来で activation 中断でも起きる＝証拠にならない
  # （2026-07-18 の誤診の元）。以下は home-manager activation の実走を直接見る。
  hm_state="${XDG_STATE_HOME:-$HOME/.local/state}/home-manager"
  gcroot="$hm_state/gcroots/current-home"
  expect_gen=""
  act=$(grep -o "/nix/store/[a-z0-9]*-activation-$USER" /run/current-system/activate 2>/dev/null | head -1 || :)
  [ -n "$act" ] && expect_gen=$(grep -o '/nix/store/[a-z0-9]*-home-manager-generation' "$act" 2>/dev/null | head -1 || :)
  if [ ! -e "$gcroot" ]; then
    df_check_fail V1-hm-activation "$gcroot が無い = home-manager activation が完走していない"
  elif [ -n "$expect_gen" ] && [ "$(readlink -f "$gcroot" 2>/dev/null)" != "$expect_gen" ]; then
    df_check_fail V1-hm-stale "home-manager 世代が古い: actual=$(readlink -f "$gcroot" 2>/dev/null) expected=$expect_gen"
  else
    df_check_ok V1-hm-activation "home-manager activation 完走"
  fi

  # V2: user layer の実体。期待リストは手書きせず現世代から導出（drift しない）
  if [ -n "$expect_gen" ] && [ -d "$expect_gen/home-files" ]; then
    ( cd "$expect_gen/home-files" && find . \( -type f -o -type l \) | sed 's|^\./||' ) \
      > "$DF_RUN_DIR/expected-home-files"
    v2_missing=0
    while IFS= read -r rel; do
      [ -e "$HOME/$rel" ] || { v2_missing=$((v2_missing + 1)); df_say "    missing: ~/$rel"; }
    done < "$DF_RUN_DIR/expected-home-files"
    if [ "$v2_missing" -gt 0 ]; then
      df_check_fail V2-home-files "$v2_missing 件の home file 欠落"
    else
      df_check_ok V2-home-files "$(wc -l < "$DF_RUN_DIR/expected-home-files" | tr -d ' ') files"
    fi
  else
    df_check_fail V2-home-files "期待ファイル一覧を導出できない（世代パス不明 = V1 を先に直す）"
  fi

  # (V3 旧 hm-profile チェックは撤去: nix-darwin + useUserPackages 構成の home-manager は
  #  profile を ~/.local/state/nix/profiles にも /nix/var/nix/profiles/per-user にも
  #  作らない（gcroots/current-home のみ）。Tart VM の健全なフル実行で実測確認 2026-07-19。
  #  残すと恒久 false FAIL で ✓ 完了 が構造的に出なくなる。activation の witness は V1/V2。）

  # V4: workspace volume + ghq root。GHQ_ROOT は export しない —— env は git config に
  # 勝つため、壊れた home-manager 層を覆い隠して「壊れた環境に正しく clone」する
  # 2026-07-18 を再現してしまう。ghq root は home-manager 完走の witness として読む。
  if ! diskutil info "$WORKSPACE_ROOT" 2>/dev/null | grep -q 'Case-sensitive'; then
    df_check_fail V4-workspace "$WORKSPACE_ROOT が case-sensitive APFS として存在しない"
  fi
  ghq_root=$(env PATH="$HM_PATH:$PATH" ghq root 2>/dev/null || :)
  if [ "$ghq_root" = "$WORKSPACE_ROOT" ]; then
    df_check_ok V4-ghq-root "$ghq_root"
  else
    df_check_fail V4-ghq-root "ghq root='$ghq_root'（期待 $WORKSPACE_ROOT）。~/.config/git/config 欠落 = V1 の実害"
  fi

  # V6: brew の宣言 vs 実体（期待値は flake から導出。ci.yml の cask 検証と同じ流儀。
  # flake 参照は $REPO_DIR 明示 —— `.#` だと cwd 依存になり --phase2（任意 cwd）で壊れる）
  if [ -x /opt/homebrew/bin/brew ]; then
    for kind in brews casks; do
      env PATH="$HM_PATH:$PATH" nix eval --impure --json \
        "$REPO_DIR#darwinConfigurations.${FLAKE_HOST}.config.homebrew.${kind}" 2>/dev/null \
        | env PATH="$HM_PATH:$PATH" jq -r '.[] | if type=="string" then . else .name end' \
        | sed 's|.*/||' | sort > "$DF_RUN_DIR/expected-$kind" || :
      if [ "$kind" = brews ]; then
        /opt/homebrew/bin/brew list --formula 2>/dev/null | sort > "$DF_RUN_DIR/actual-$kind" || :
      else
        /opt/homebrew/bin/brew list --cask 2>/dev/null | sort > "$DF_RUN_DIR/actual-$kind" || :
      fi
      if [ ! -s "$DF_RUN_DIR/expected-$kind" ]; then
        df_check_fail "V6-$kind" "期待 $kind を flake から導出できない"
        continue
      fi
      comm -23 "$DF_RUN_DIR/expected-$kind" "$DF_RUN_DIR/actual-$kind" > "$DF_RUN_DIR/missing-$kind"
      if [ -s "$DF_RUN_DIR/missing-$kind" ]; then
        df_check_fail "V6-$kind" "未 install: $(tr '\n' ' ' < "$DF_RUN_DIR/missing-$kind")"
      else
        df_check_ok "V6-$kind" "全 $(wc -l < "$DF_RUN_DIR/expected-$kind" | tr -d ' ') 件"
      fi
    done
  else
    df_check_fail V6-brew "/opt/homebrew/bin/brew が無い"
  fi
}

# ── clone 以降（full の終盤 と --phase2 の両方から呼ぶ）───────────────────────────
run_clone_phases() {
  if [ "$SKIP_CLONE" = 1 ]; then
    df_phase clone
    df_say "--skip-clone 指定 → SSH gate / ghq-get-mine / clone 検証を行わない（RESULT は最大 PARTIAL）"
    return 0
  fi

  df_phase onepassword
  # ssh-add -l はロック中でも成功する偽陽性なので使わない。実署名で判定する。
  # agent がロック中だと ssh は GUI 承認待ちで無期限ブロックし得るため、watchdog で
  # 75 秒に制限する（ConnectTimeout は TCP にしか効かない。timeout(1) は macOS に無い）。
  OP_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  if [ ! -S "$OP_SOCK" ]; then
    df_check_fail P-onepassword "1Password SSH agent socket が無い（設定 → 開発者 → SSH agent を ON に）"
    exit 1
  fi
  gate_out="$DF_RUN_DIR/ssh-gate.out"
  ssh -n -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -T git@github.com \
    > "$gate_out" 2>&1 &
  gate_pid=$!
  # watchdog の fd を FIFO から切り離す（>/dev/null 2>&1）。切り離さないと kill 後も
  # orphan の sleep が FIFO の write 端を掴み、df_finish の wait(tee) が最大 75 秒止まる
  ( sleep 75; kill "$gate_pid" 2>/dev/null ) >/dev/null 2>&1 &
  gate_watchdog=$!
  wait "$gate_pid" 2>/dev/null || :
  kill "$gate_watchdog" 2>/dev/null || :
  if grep -q "successfully authenticated" "$gate_out"; then
    df_check_ok P-onepassword "1Password agent 経由で GitHub 認証成功"
  else
    df_check_fail P-onepassword "GitHub SSH 認証失敗/タイムアウト（1Password のロック解除・SSH agent ON・鍵承認・~/.ssh/config の IdentityAgent を確認）"
    sed 's/^/    | /' "$gate_out" | tail -n 3
    exit 1
  fi

  df_phase clone
  if ! clt_ok; then
    df_check_fail P-clt "CLT が無い（--phase2 は full run 完了後のリカバリ入口。先にワンライナーを実行）"
    exit 1
  fi
  # SIGKILL 死の壊れ clone（.git はあるが HEAD 不能）を退避してから ghq に再 clone させる。
  # 放置すると ghq get は「exists」で skip し、V5a の存在チェックも通ってしまう
  for d in "$WORKSPACE_ROOT/github.com/$GITHUB_USERNAME"/*; do
    [ -d "$d/.git" ] || continue
    git -C "$d" rev-parse --verify -q HEAD >/dev/null 2>&1 && continue
    df_say "壊れた clone を退避: $d -> $d.broken-$DF_RUN_ID"
    mv "$d" "$d.broken-$DF_RUN_ID" || :
  done
  # ghq-get-mine 自身が ghq root != /Volumes/workspace で hard fail する安全弁を持つ
  df_step ghq-get-mine quiet env PATH="$HM_PATH:$PATH" ghq-get-mine || exit 1
  df_step link-claude-memory plain env PATH="$HM_PATH:$PATH" link-claude-memory || :

  df_phase verify-clone
  # V5a: 自作 CLI ラッパが hardcode する source clone の実在（HEAD 解決まで確認）
  v5_missing=""
  for r in furrow pare cifail rundiff revpost projects claude-memory; do
    git -C "$WORKSPACE_ROOT/github.com/$GITHUB_USERNAME/$r" rev-parse --verify -q HEAD \
      >/dev/null 2>&1 || v5_missing="$v5_missing $r"
  done
  if [ -n "$v5_missing" ]; then
    df_check_fail V5a-wrapper-src "自作 CLI の source が無い/壊れている:$v5_missing"
  else
    df_check_ok V5a-wrapper-src "全 wrapper source clone 済み"
  fi
  # V5b: gh repo list との全件突き合わせ（limit はソース側 ghq-get-mine の 200 より広く
  # 取り、200 超で検証が空振りになる縮退を検出できるようにする）
  if env PATH="$HM_PATH:$PATH" gh auth status >/dev/null 2>&1; then
    env PATH="$HM_PATH:$PATH" gh repo list "$GITHUB_USERNAME" --no-archived --limit 1000 \
      --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null | sort > "$DF_RUN_DIR/expected-repos" || :
    env PATH="$HM_PATH:$PATH" ghq list 2>/dev/null | sed 's|^github.com/||' | sort > "$DF_RUN_DIR/actual-repos" || :
    if [ -s "$DF_RUN_DIR/expected-repos" ]; then
      comm -23 "$DF_RUN_DIR/expected-repos" "$DF_RUN_DIR/actual-repos" > "$DF_RUN_DIR/missing-repos"
      if [ -s "$DF_RUN_DIR/missing-repos" ]; then
        df_check_fail V5b-clone "未 clone: $(tr '\n' ' ' < "$DF_RUN_DIR/missing-repos")"
      else
        df_check_ok V5b-clone "全 $(wc -l < "$DF_RUN_DIR/expected-repos" | tr -d ' ') repo clone 済み"
      fi
    else
      df_check_fail V5b-clone "gh repo list が空。clone 完全性を検証できていない"
    fi
  else
    df_check_fail V5b-gh "gh 未認証（GH_TOKEN を export するか gh auth login 後に --phase2 で再実行）"
  fi
  # V7: claude-memory link（「完了」の定義に含まれる）。memory は per-project なので
  # clone の projects/ に居る全 slug が生きた symlink であることを確認する（t-tnc9）
  v7_bad="" v7_n=0
  for v7_d in "$WORKSPACE_ROOT/github.com/$GITHUB_USERNAME/claude-memory/projects"/*/; do
    [ -d "$v7_d" ] || continue
    v7_n=$((v7_n + 1))
    v7_slug=$(basename "$v7_d")
    v7_mem="$HOME/.claude/projects/$v7_slug/memory"
    { [ -L "$v7_mem" ] && [ -e "$v7_mem" ]; } || v7_bad="$v7_bad $v7_slug"
  done
  if [ "$v7_n" -eq 0 ]; then
    df_check_fail V7-claude-memory "clone に projects/<slug> が 1 つも無い（claude-memory の layout を確認）"
  elif [ -n "$v7_bad" ]; then
    df_check_fail V7-claude-memory "生きた symlink でない slug:$v7_bad（link-claude-memory を確認）"
  else
    df_check_ok V7-claude-memory "全 $v7_n slug link 済み"
  fi
}

# ── リカバリ入口: clone 以降だけ ─────────────────────────────────────────────
if [ "$MODE" = phase2 ]; then
  df_phase pre
  # full run が SIGKILL 死した後に --phase2 へ来た場合の drop-in self-heal。
  # 消せない（sudo チケット無し）なら FAIL を記録して ✓ 完了 を出さない
  # （NOPASSWD:SETENV ALL を残したまま「完了」は宣言しない）
  if [ -f "$SUDOERS_DROPIN" ]; then
    df_say "前回の sudoers drop-in が残っている → 除去を試みる"
    sudo -n rm -f "$SUDOERS_DROPIN" 2>/dev/null || :
    if [ -f "$SUDOERS_DROPIN" ]; then
      df_check_fail P-sudoers-residue "$SUDOERS_DROPIN が残存。\`sudo rm $SUDOERS_DROPIN\` を手動実行すること"
    else
      df_say "sudoers drop-in 削除済み（self-heal）"
    fi
  fi
  [ "$SKIP_CLONE" = 1 ] || df_gate_ghtoken
  run_verify_system
  run_clone_phases
  DF_REACHED_END=1
  exit 0
fi

# ── full run ─────────────────────────────────────────────────────────────────

df_phase pre
# 再実行 self-heal: 前回 SIGKILL 死などで残った drop-in を除去（この時点では
# sudo チケットがあるので -n で消せる。無ければ次の assert で止まる）
if [ -f "$SUDOERS_DROPIN" ]; then
  df_say "前回の sudoers drop-in が残っている → 除去（再実行 self-heal）"
  sudo -n rm -f "$SUDOERS_DROPIN" 2>/dev/null || :
fi

# FDA preflight: TCC の管理ダイアログ（kTCCServiceSystemPolicySysAdminFiles）を
# 全行程で出さないための前提。TCC.db は FDA がある時だけ読める（fail-closed 実測済み）。
# 抑止効果そのものは Tart VM で検証する（VM-gated。外れたら per-accessor 前倒しに切替）。
if [ "${DOTFILES_SKIP_FDA_GATE:-0}" != 1 ]; then
  if /usr/bin/head -c 1 "/Library/Application Support/com.apple.TCC/TCC.db" >/dev/null 2>&1; then
    df_check_ok P1-fda "Terminal にフルディスクアクセスあり"
  else
    df_check_fail P1-fda "Terminal にフルディスクアクセスが無い"
    df_say "  システム設定 → プライバシーとセキュリティ → フルディスクアクセス → Terminal を ON にし、"
    df_say "  Terminal を Cmd-Q で再起動してから同じコマンドを再実行すること。"
    exit 1
  fi
fi

# sudo 前提: ワンライナーの `sudo -v &&` でチケットがある状態を強制する。
# macOS の sudo は PASSWORD_TIMEOUT=0（プロンプトが出ると無限ハングしログも残らない）
# なので、以降すべての sudo は -n 固定 = プロンプト事象を即時の非ゼロに変換する。
export SUDO_ASKPASS=/usr/bin/false
if ! sudo -n true 2>/dev/null; then
  df_check_fail P1-sudo "sudo チケットが無い"
  df_say "  先に \`sudo -v\` を実行し、同じターミナルで再実行すること"
  exit 1
fi

# gh 認証 gate（15 分の nix/switch を走らせてから ghq-get-mine で落ちるのを防ぐ）
[ "$SKIP_CLONE" = 1 ] || df_gate_ghtoken

# bootstrap 用 sudoers drop-in。keepalive だけでは不足する（実測 2 系統）:
#   - macOS 26 の sudo は use_pty 既定 ON → sudo ごとに新 pty/session でチケット不継承
#   - brew は起動のたび sudo --reset-timestamp を叩きチケットを殺す
# → NOPASSWD:SETENV（brew が -E で env を積むため SETENV 必須）。窓は本スクリプトの
#   実行中のみ: trap 削除 + 起動時 self-heal + 終了時の存在チェックで封じる。
# ※ Defaults !use_pty 案（宣言側）との優劣は Tart VM probe で最終確定（VM-gated seam）。
DOTFILES_SUDO_RULE="${DOTFILES_SUDO_RULE:-$USER ALL=(ALL) NOPASSWD:SETENV: ALL}"
df_sudo_tmp="$DF_RUN_DIR/sudoers-dropin"
printf '%s\n' "$DOTFILES_SUDO_RULE" > "$df_sudo_tmp"
if sudo -n /usr/sbin/visudo -cf "$df_sudo_tmp" >/dev/null 2>&1 \
  && sudo -n /usr/bin/install -m 0440 -o root -g wheel "$df_sudo_tmp" "$SUDOERS_DROPIN"; then
  DF_SUDO_RULE_PLANTED=1
  df_check_ok P1-sudoers "bootstrap drop-in 設置（終了時に自動削除）"
else
  df_check_fail P1-sudoers "sudoers drop-in を設置できない（visudo 検証失敗 or install 失敗）"
  exit 1
fi
rm -f "$df_sudo_tmp"

df_phase clt
# headless CLT: sentinel で softwareupdate に CLT ラベルを出させて -i する。
# clt_ok は共有ヘルパ節で定義済み（/usr/bin/git shim は判定に使わない）。
CLT_SENTINEL=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
clt_pick_label() {
  # macOS 26 は複数ラベルを同時提示する（26.5 / 26.6 を実測）。beta を除き最新を
  # sort -V で選ぶ（lexical だと 26.9 > 26.10 になる罠）。
  /usr/sbin/softwareupdate --list 2>&1 \
    | sed -n 's/^[* -]*Label: \(Command Line Tools for Xcode[^,]*\).*$/\1/p' \
    | grep -iv beta \
    | sort -V | tail -n 1
}
if clt_ok; then
  df_say "CLT 導入済み → skip"
else
  clt_attempt=0
  while [ "$clt_attempt" -lt 3 ]; do
    clt_attempt=$((clt_attempt + 1))
    df_say "CLT headless install 試行 $clt_attempt/3"
    sudo -n /usr/bin/touch "$CLT_SENTINEL"
    clt_label=$(clt_pick_label || :)
    if [ -z "$clt_label" ]; then
      df_say "  softwareupdate --list に CLT ラベルが出ない（少し待って再試行）"
      sleep 15
      continue
    fi
    df_say "  label: $clt_label"
    df_step_try "clt-install-$clt_attempt" quiet sudo -n /usr/sbin/softwareupdate --install "$clt_label" || :
    [ -d "$CLT_DIR" ] && sudo -n /usr/bin/xcode-select --switch "$CLT_DIR" 2>/dev/null || :
    sudo -n rm -f "$CLT_SENTINEL" 2>/dev/null || :
    clt_ok && break
  done
  sudo -n rm -f "$CLT_SENTINEL" 2>/dev/null || :
  if clt_ok; then
    df_check_ok P-clt "CLT headless install 完了"
  else
    df_check_fail P-clt "CLT を headless で導入できなかった"
    exit 1
  fi
fi

df_phase workspace-volume
# t-s4ea の対策（sparseimage wedge → 内蔵 APFS へ）。消さない。
# run 1 の Nix Store mount 失敗はこの volume と無関係と確定済み（unified log 検証）。
if diskutil info "$WORKSPACE_ROOT" 2>/dev/null | grep -q 'Case-sensitive'; then
  df_say "workspace volume 既存 (case-sensitive) → skip"
else
  WORKSPACE_CONTAINER=$(diskutil info / | awk -F': *' '/APFS Container:/ {gsub(/[[:space:]]+$/, "", $2); print $2; exit}')
  if [ -z "$WORKSPACE_CONTAINER" ]; then
    df_check_fail P-volume "APFS Container 検出失敗 (diskutil info / を確認)"
    exit 1
  fi
  df_step workspace-addvolume plain \
    sudo -n diskutil apfs addVolume "$WORKSPACE_CONTAINER" "Case-sensitive APFS" workspace || exit 1
fi

df_phase nix
# Determinate は .pkg 経路（curl|sh は素の Rust バイナリのみで、/nix 不在時の
# 「捨て volume を add/delete して回復する」postinstall 前処理が無い = run 1 の敗因。
# run 2 は手動 .pkg で成功しており、同機構を headless で使う）。
# 再実行の fresh sh は nix を知らないので、導入済み判定の前に profile を source する
# （しないと毎回 .pkg を再ダウンロード・再インストールする無駄が出る）
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
# download は .part へ落として mv（atomic）。中断の部分ファイルを完成品と誤認しない
nix_pkg="$DF_RUN_DIR/Determinate.pkg"
nix_pkg_download() {
  curl --proto '=https' --tlsv1.2 -fsSL -o "$nix_pkg.part" \
    https://install.determinate.systems/determinate-pkg/stable/Universal \
    && mv -f "$nix_pkg.part" "$nix_pkg"
}
if command -v nix >/dev/null 2>&1 && [ -d /nix ]; then
  df_say "nix 導入済み → skip"
else
  nix_attempt=0
  while [ "$nix_attempt" -lt 2 ]; do
    nix_attempt=$((nix_attempt + 1))
    df_say "Determinate .pkg install 試行 $nix_attempt/2"
    if [ ! -f "$nix_pkg" ]; then
      df_step_try "nix-pkg-download-$nix_attempt" plain nix_pkg_download || { sleep 10; continue; }
    fi
    df_step_try "nix-pkg-install-$nix_attempt" quiet \
      sudo -n /usr/sbin/installer -pkg "$nix_pkg" -target / || { sleep 10; continue; }
    break
  done
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  if [ -d /nix ] && command -v nix >/dev/null 2>&1; then
    df_check_ok P-nix "/nix あり + nix $(nix --version 2>/dev/null | head -1)"
  else
    df_check_fail P-nix "/nix または nix コマンドが無い（.pkg install 失敗。summary の detail を確認）"
    exit 1
  fi
fi

df_phase repo
# SIGKILL 死の壊れ clone（.git はあるが HEAD 不能 = git clone の途中死）を退避して
# clone し直す。放置すると以後の全再実行が switch で同じ失敗を繰り返し、収束しない
if [ -d "$REPO_DIR/.git" ] && ! git -C "$REPO_DIR" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  df_say "壊れた clone（前回中断の残骸）を退避: $REPO_DIR -> $REPO_DIR.broken-$DF_RUN_ID"
  mv "$REPO_DIR" "$REPO_DIR.broken-$DF_RUN_ID"
fi
if [ ! -d "$REPO_DIR/.git" ]; then
  df_step git-clone plain \
    git clone -b "$BRANCH" "https://github.com/${GITHUB_USERNAME}/dotfiles.git" "$REPO_DIR" || exit 1
fi
cd "$REPO_DIR"
git config core.hooksPath .githooks

df_phase switch
# repo 自身の locked flake から darwin-rebuild を起動する（flake.nix の passthrough）。
# `nix run nix-darwin/master#...` は実行時に master を解決する rolling 参照で、
# brew と同型の pin×rolling 不安定 + 未認証 api.github.com 403 リスクがあった。
# locked 入力の取得は codeload tarball 直行なので GITHUB_TOKEN も不要になる。
switch_cmd() {
  sudo -n USER="$USER" FLAKE_USER="${FLAKE_USER:-}" \
    nix run "$REPO_DIR#darwin-rebuild" -- switch --flake "$REPO_DIR#$FLAKE_HOST" --impure
}
# 初回は TRY（fallback+retry で回復し得る）。retry まで失敗したら STEP として数える
if df_step_try darwin-switch plain switch_cmd; then
  :
else
  # フォールバック: nix-darwin の brew bundle は fetch all → install all 設計で、
  # 1 件の失敗が全 install を道連れにする。tap → formula → cask を個別 install し、
  # その後 switch をもう 1 回だけ試す（bounded retry）。
  # 対象リストは flake から nix eval で導出する —— /nix/store の *-Brewfile を find で
  # 拾う方式は複数世代あると任意の（stale な）1 つを掴む。V6 と同じ流儀で正本から引く
  df_say "switch 失敗 → per-item brew フォールバック + bounded retry"
  if [ -x /opt/homebrew/bin/brew ]; then
    for bf_kind in taps brews casks; do
      env PATH="$HM_PATH:$PATH" nix eval --impure --json \
        "$REPO_DIR#darwinConfigurations.${FLAKE_HOST}.config.homebrew.${bf_kind}" 2>/dev/null \
        | env PATH="$HM_PATH:$PATH" jq -r '.[] | if type=="string" then . else .name end' \
        | while IFS= read -r bf_item; do
        [ -z "$bf_item" ] && continue
        case "$bf_kind" in
          taps)  bf_cmd="tap" ;;
          brews) bf_cmd="install --formula" ;;
          casks) bf_cmd="install --cask" ;;
        esac
        # shellcheck disable=SC2086  # bf_cmd の語分割は意図的
        if /opt/homebrew/bin/brew $bf_cmd "$bf_item" >/dev/null 2>&1; then
          df_say "  ✓ $bf_kind $bf_item"
        else
          df_say "  ✘ $bf_kind $bf_item 失敗"
        fi
      done
    done
  fi
  df_step darwin-switch-retry plain switch_cmd || df_say "switch retry も失敗（RESULT は FAILED になる。verify で実害を特定）"
fi

df_phase chezmoi
# --no-tty: 対話プロンプト（外部変更されたターゲットの上書き確認）を無効化する。
# 無いと stdin が TTY の環境（通常のターミナル実行）で無言のハングになり得る。
# プロンプト事象はエラー化され step 失敗 = 正直な FAILED として観測される
df_step chezmoi-apply quiet env \
  PATH="$HM_PATH:$PATH" \
  chezmoi --source "$REPO_DIR/chezmoi" apply --verbose --no-tty || :

run_verify_system

# ── clone 以降（事前準備で 1Password が生きていればここまで無人で完走する）────────
run_clone_phases

DF_REACHED_END=1
