#!/usr/bin/env bash
# Regression tests for the Stop hook
# chezmoi/dot_local/bin/executable_claude-work-report-check.
#
# Run locally: bash scripts/claude-work-report-check-test.sh
# CI: .github/workflows/ci.yml job `hook-scripts-test`.
#
# Contract under test: the hook emits {"decision":"block",...} when (and only
# when) the work-request closing template is used without a verifiable
# やり残し declaration (a t-xxxx furrow id or the literal 「なし」 on the
# declaration line). Everything else — including malformed input — must allow.
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

run "定型 + task ID 列挙 → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: t-ab3d, t-9kzz
別セッションで作業お願いします。')" allow

run "定型 + なし → allow" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: なし
別セッションで作業お願いします。')" allow

run "opener だけで やり残し宣言行が無い → block" \
  "$(mk '品質担保できる範囲まで作業続けました。以上です。')" block

run "やり残し宣言行に ID も なし も無い → block" \
  "$(mk 'やり残しは task 化済:（あとでやります）')" block

run "なし は宣言行スコープ（他行の「問題なし」では通らない）→ block" \
  "$(mk '品質担保できる範囲まで作業続けました。
やり残しは task 化済: 未起票
テストは問題なしでした。')" block

run "stop_hook_active=true は違反があっても素通し → allow" \
  "$(jq -n '{stop_hook_active: true, last_assistant_message: "やり残しは task 化済:（あとで）"}')" allow

run "壊れた JSON → allow (fail-open)" 'not-json{{' allow

run "last_assistant_message 欠落 → allow (fail-open)" \
  '{"stop_hook_active": false}' allow

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ all $n tests passed"
else
  echo "❌ failure(s) above ($n tests)"
fi
exit "$fail"
