---
name: condition-wait
description: Use when waiting for a condition — a log line to appear (regex), a TCP port to open, an HTTP endpoint to become healthy, a file to exist, or a process to exit — instead of hand-writing until/sleep polling loops. wait4x recipes with a clean exit-code contract and known footguns.
---

# 条件待ちは wait4x（until+sleep を手書きしない）

> 出典: エージェント向け CLI 調査（2026-07-03、実機検証済み。採用 task = projects t-v1t1・done）。wait4x は nix 宣言済み（packages.nix）。

## exit code 契約

`0` = 条件成立 ／ **`124` = timeout**（coreutils 互換・判別確実）／ `1` = その他（usage エラー含む点だけ house 規約と違う）。

## ⚠️ footgun 3 点（全て実機で再現確認済み）

1. **`-t` を必ず明示する** — 既定 timeout はたった **10s**。
2. **exec の文字列に `$` を入れない** — wait4x が parse 時に**空 env で展開**して消える。`$PID` 等は呼び出しシェル側で展開させる（下のレシピ 5 の形は安全）。
3. **exec と `-- 後続コマンド` を併用しない** — 引数が二重使用されるバグがある。後続は shell の `&&` で。`--` が使えるのは tcp/http のみ。

## レシピ

```sh
# 1) ログに regex が現れるまで（+ マッチ行を表示）。rotation-safe（毎 poll でファイルを開き直す）
wait4x exec 'grep -qE "READY" /path/app.log' -q -t 60s -i 500ms && grep -m1 -E "READY" /path/app.log

# 2) TCP ポート（tcp/http は `-- 後続` OK）
wait4x tcp 127.0.0.1:5432 -q -t 60s

# 3) HTTP 健全性（--expect-body-regex / --expect-header / --expect-body-json も可）
wait4x http http://127.0.0.1:8080/health --expect-status-code 200 -q -t 60s

# 4) ファイル存在/非空
wait4x exec 'test -s /path/artifact' -q -t 30s

# 5) プロセス終了待ち（$PID はこのシェルが展開するので安全）
wait4x exec "kill -0 $PID" --invert-check -q -t 300s

# 6) AND 結合は && 連結（CLI の 1 呼び出し AND は同型マルチターゲットのみ）
wait4x tcp 127.0.0.1:8080 -q -t 60s && wait4x exec 'grep -q ready /path/app.log' -q -t 60s
```

古い定石 `timeout 60 tail -F | grep -m1` は使わない: 素の macOS に `timeout(1)` が無く、match 後も tail が生き続けて pipeline が終わらない（SIGPIPE 不発を実証済み）。

## watch

upstream PR wait4x#506（`wait4x file FILE --expect-content-regex`）が merge されたらレシピ 1 は 1 コマンドに畳める。
