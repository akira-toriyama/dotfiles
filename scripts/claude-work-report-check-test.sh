#!/usr/bin/env bash
# Regression tests for the Stop hook
# chezmoi/dot_local/bin/executable_claude-work-report-check.
#
# Run locally: bash scripts/claude-work-report-check-test.sh
# CI: .github/workflows/ci.yml job `hook-scripts-test`.
#
# Contract under test: the hook emits {"decision":"block",...} when (and only
# when) a work-session close is attempted (armed by the retired template
# opener, a やり残し line, or a closed/created counts token) without the two
# verifiable elements — ①a やり残し line carrying a t-xxxx furrow id or the
# literal 「なし」 ②a `closed N / created M` line, with any budget-overrun
# reason on the counts line or the line right after it. Everything else —
# including malformed input — must allow.
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/chezmoi/dot_local/bin/executable_claude-work-report-check"
fail=0
n=0

run() { # $1=name  $2=stdin payload  $3=expected: allow|block
  local name=$1 payload=$2 expect=$3 out decision
  out=$(printf '%s' "$payload" | bash "$script")
  if [ -z "$out" ]; then
    decision=allow
  else
    decision=$(printf '%s' "$out" | jq -r '.decision // "allow"' 2>/dev/null) || decision=unparseable
  fi
  n=$((n + 1))
  if [ "$decision" = "$expect" ]; then
    printf '  ✓ %s\n' "$name"
  else
    printf '  ✗ %s — expected %s, got %s (output: %s)\n' "$name" "$expect" "$decision" "$out"
    fail=1
  fi
}

mk() { # $1=last_assistant_message → full hook payload
  jq -n --arg m "$1" '{stop_hook_active: false, last_assistant_message: $m}'
}

run "定型なしの普通の応答 → allow" \
  "$(mk '原因は Authorization ヘッダ欠落でした。修正済みです。')" allow

run "定型 + task ID 列挙 + 増減の実数 → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d, t-9kzz
closed 3 / created 1
別セッションで作業お願いします。')" allow

run "定型 + なし + 増減の実数 → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: なし
closed 1 / created 0
別セッションで作業お願いします。')" allow

run "opener だけで やり残し宣言行が無い → block" \
  "$(mk '品質担保できる範囲まで作業続けました。以上です。')" block

run "やり残し宣言行に ID も なし も無い → block" \
  "$(mk 'やり残しは task 化済:（あとでやります）')" block

run "なし は宣言行スコープ（他行の「問題なし」では通らない）→ block" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: 未起票
テストは問題なしでした。')" block

# ---- 生成予算 (created ≤ closed − 1) ----------------------------------------
# ID が揃っていても board が増え続けるなら収束していない。実数の申告と、超過時の
# 理由を要求する（数え方そのものは hook から検証できない — id 検査と同じ割り切り）。

run "ID はあるが closed/created 行が無い → block" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d
別セッションで作業お願いします。')" block

run "created > closed で理由なし → block" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d, t-9kzz
closed 1 / created 2
別セッションで作業お願いします。')" block

run "created > closed でも理由が書いてあれば → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d, t-9kzz
closed 1 / created 2（理由: 今日の作業が生んだ blocker）
別セッションで作業お願いします。')" allow

# 予算は created ≤ closed − 1。等号は「予算内」ではなく超過ちょうどで、ここが
# 2026-08-19 まで素通りしていた（規範を 1 件ぶん常に見逃す off-by-one）。
run "created == closed は予算内ではない（created ≤ closed − 1）→ block" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: なし
closed 2 / created 2
別セッションで作業お願いします。')" block

run "created == closed でも理由が書いてあれば → allow" \
  "$(mk 'やり残し: なし
closed 3 / created 3
理由: 今日の作業が生んだ blocker')" allow

# 0/0 だけは免除する。規範を字義どおり読むと closed 0 のとき created ≤ −1 で
# あらゆる起票が違反になるが、0/0 は board を増やしていない。
run "closed 0 / created 0 は免除 → allow" \
  "$(mk 'やり残し: なし
closed 0 / created 0')" allow

# counts は「最後の counts 形」を採る。先頭を採っていた頃は、規約の引用や repo ごとの
# 内訳が本物の宣言を覆い隠して予算 gate も board 照合も黙って通った（2026-08-19 実地）。
run "前方に counts 形の引用があっても締めの数字で判定する → block" \
  "$(mk '規約は closed 5 / created 1 の形です。
やり残し: なし
closed 1 / created 9')" block

run "前方の引用が超過でも、締めが予算内なら → allow" \
  "$(mk '規約は closed 1 / created 9 の形です。
やり残し: なし
closed 5 / created 1')" allow

# 理由行の探索も最後の counts 行に固定する。前方一致に引きずられていた頃は、正しい
# 位置に書いた理由が採用されず false BLOCK になった。
run "前方に counts 形の引用があっても、締めの直後の理由行が効く → allow" \
  "$(mk 'この検査は closed 3 / created 3 のような形を見ます。
やり残し: t-ab3d
closed 1 / created 2
理由: 今日の作業が生んだ blocker')" allow

run "全角混じり・語順どおりなら読める → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d
このセッションの増減: closed 4 / created 0
別セッションで作業お願いします。')" allow

# ---- 契約化（2026-07-28 逐語定型の退役）: 文面自由・必須 2 要素 ---------------
# arming は ①旧 opener（後方互換） ②やり残し行 ③counts トークン のいずれか。

run "自由文でも 2 要素が揃っていれば → allow" \
  "$(mk '修正を merge しました。
やり残し: なし
closed 2 / created 0')" allow

run "counts 行だけで やり残し宣言が無い（counts が arm する新経路）→ block" \
  "$(mk '作業完了です。closed 3 / created 1')" block

run "「task」語なしの やり残し行でも arm され、ID/なし が無い → block" \
  "$(mk 'やり残しがあります。次のセッションでやります。')" block

run "超過理由が counts 行の直後の行にあれば → allow" \
  "$(mk 'やり残し: t-ab3d
closed 1 / created 2
理由: 今日の作業が生んだ blocker')" allow

run "超過理由が counts 行から離れた行にしか無い → block" \
  "$(mk '失敗の理由は依存の破損でした。修正済みです。
やり残し: t-ab3d
closed 1 / created 2')" block

run "stop_hook_active=true は違反があっても素通し → allow" \
  "$(jq -n '{stop_hook_active: true, last_assistant_message: "やり残しは task 化済:（あとで）"}')" allow

run "壊れた JSON → allow (fail-open)" 'not-json{{' allow

run "last_assistant_message 欠落 → allow (fail-open)" \
  '{"stop_hook_active": false}' allow

# ---- board 実数照合 (furrow t-64tw) ------------------------------------------
# 形式が揃った締めは、board が証言できる範囲で数字の真偽も見る。session 境界は
# transcript 先頭の timestamp、実数は `furrow stats -r '' --since <t0> --json` の
# window。furrow は PATH shim で偽装し、shape 検査と独立に照合だけを試験する。
# 並走セッションで実数が膨らむ側（closed の過少申告・created の過大申告）は
# 通り、嘘の側（closed 過大・created 過少）だけ block になることを両方向で見る。

shimdir=$(mktemp -d)
transcript=$(mktemp)
printf '{"timestamp":"2026-08-02T00:00:00Z","type":"summary"}\n' >"$transcript"

mkshim() { # $1=window JSON (or "ERR" to exit 2)
  if [ "$1" = ERR ]; then
    printf '#!/bin/sh\nexit 2\n' >"$shimdir/furrow"
  else
    printf '#!/bin/sh\nprintf %%s '"'"'{"total":9,"drafts":0,"window":%s}'"'"'\n' "$1" >"$shimdir/furrow"
  fi
  chmod +x "$shimdir/furrow"
}

mkt() { # $1=last_assistant_message → payload carrying the transcript
  jq -n --arg m "$1" --arg t "$transcript" \
    '{stop_hook_active: false, last_assistant_message: $m, transcript_path: $t}'
}

close_msg='やり残し: なし
closed 2 / created 0'

mkshim '{"created":0,"closed":2,"created_ids":[],"closed_ids":["t-a1","t-b2"]}'
PATH="$shimdir:$PATH" run "実数一致 → allow" "$(mkt "$close_msg")" allow

mkshim '{"created":0,"closed":1,"created_ids":[],"closed_ids":["t-a1"]}'
PATH="$shimdir:$PATH" run "closed 過大申告（宣言2/実数1）→ block" "$(mkt "$close_msg")" block

mkshim '{"created":2,"closed":2,"created_ids":["t-x1","t-y2"],"closed_ids":["t-a1","t-b2"]}'
PATH="$shimdir:$PATH" run "created 過少申告（宣言0/実数2）→ block" "$(mkt "$close_msg")" block

mkshim '{"created":0,"closed":3,"created_ids":[],"closed_ids":["t-a1","t-b2","t-c3"]}'
PATH="$shimdir:$PATH" run "closed 過少申告（並走分・宣言2/実数3）→ allow" "$(mkt "$close_msg")" allow

mkshim '{"created":1,"closed":2,"created_ids":["t-x1"],"closed_ids":["t-a1","t-b2"]}'
PATH="$shimdir:$PATH" run "created 過大申告（宣言側が多い）→ allow" \
  "$(mkt 'やり残し: なし
closed 2 / created 1
理由: 今日の作業が生んだ blocker を起票')" allow

mkshim '{"created":0,"closed":2,"created_ids":[],"closed_ids":["t-a1","t-b2"]}'
PATH="$shimdir:$PATH" run "board 照合も締めの counts を見る（前方の引用は実数と突合しない）→ allow" \
  "$(mkt '規約は closed 9 / created 0 の形です。
やり残し: なし
closed 2 / created 0')" allow

mkshim ERR
PATH="$shimdir:$PATH" run "furrow が exit 2（board 圏外）→ allow (fail-open)" "$(mkt "$close_msg")" allow

mkshim '{"created":0,"closed":1,"created_ids":[],"closed_ids":["t-a1"]}'
run_no_shim_transcript=$(jq -n --arg m "$close_msg" '{stop_hook_active: false, last_assistant_message: $m, transcript_path: "/nonexistent/transcript"}')
PATH="$shimdir:$PATH" run "transcript が読めない → allow (fail-open)" "$run_no_shim_transcript" allow

printf 'no timestamps here\n' >"$transcript"
mkshim '{"created":0,"closed":1,"created_ids":[],"closed_ids":["t-a1"]}'
PATH="$shimdir:$PATH" run "transcript に timestamp が無い → allow (fail-open)" "$(mkt "$close_msg")" allow

rm -rf "$shimdir" "$transcript"

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ all $n tests passed"
else
  echo "❌ failure(s) above ($n tests)"
fi
exit "$fail"
