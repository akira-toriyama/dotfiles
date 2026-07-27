---
name: macos-gui-verify
description: Use when verifying macOS app GUI behavior end-to-end — dump an app's accessibility (AX) tree as JSON, query elements, and click/type/press via the peekaboo CLI. For "did my UI change actually work" checks on Swift/AppKit/SwiftUI apps.
---

# macOS GUI 検証は peekaboo（AX ツリー JSON + UI 操作）

> 出典: エージェント向け CLI 調査（2026-07-03。採用 task = projects t-c0s2・done）。peekaboo = openclaw/Peekaboo（MIT）、homebrew.nix で宣言済み（`steipete/tap/peekaboo`）。

## 前提（TCC）

- Accessibility + Screen Recording の許可は **CLI 本体でなくホストアプリ（Terminal / IDE）に付与**する（TCC の responsible-code）。ローカルで再ビルドしたバイナリでも同じホストから動く限り再付与不要。
- 確認: `peekaboo permissions status --all-sources`。未付与ならユーザーに System Settings での付与を依頼する（GUI 操作なので自分ではできない）。
- AI-provider 設定（API key）は自動化用途には不要。

## 基本ループ（見る → 選ぶ → 押す）

```sh
# 1) AX ツリーを JSON で見る（要素に opaque ID が振られ、snapshot が永続化される）
peekaboo see --app "MyApp" --json          # 大きい tree は --max-depth / --max-elements
# スクリーンショット不要なら: peekaboo inspect-ui --json

# 2) jq で要素を選ぶ。要素は .data.ui_elements[]、各要素のキーは
#    { id, role, label, role_description, bounds, is_actionable }。id は "elem_8" 形式。
#    操作対象は is_actionable=true で絞るのが速い:
peekaboo see --app "MyApp" --json | jq -r '.data.ui_elements[] | select(.is_actionable) | "\(.id)\t\(.role)\t\(.label)"'
#    snapshot は .data.snapshot_id、ウィンドウ名は .data.window_title。

# 3) 別プロセスからでも id で操作できる（snapshot 経由で live 再解決）
peekaboo click --on elem_8 [--snapshot <snapshot-id|latest>]   # --on は .data.ui_elements[].id の値
peekaboo type "text" --app MyApp
peekaboo press return / peekaboo hotkey cmd,s / peekaboo set-value / peekaboo perform-action / peekaboo menu
```

- 既定は background 配送（フォーカスを奪わない）。key window が要るときだけ `--foreground`。
- snapshot が期限切れなら `SNAPSHOT_NOT_FOUND` → `see` を撮り直す。
- `see` が `WINDOW_NOT_FOUND` を返すのはそのアプリに実ウィンドウが無いとき（Finder のデスクトップのみ等）。エラーでなく状態 — 対象アプリのウィンドウを開いてから撮る。

## 注意

- **exit code は素の 0/1**（house の 0/1/2/3 ではない）。エラー詳細が要るときは必ず `--json` を付けて stderr でなく JSON エラーを読む。
- 要素指定は `see` が返す `.id`（+ 必要なら `--snapshot`）で。`button 1 of window 1` 式の位置 index は tree 変化で壊れるので使わない。
- Peekaboo が重い/変化が速すぎる等の実害が出たら fallback = facet の AX モジュールで薄い Swift CLI を自作する。※かつての仕様スケッチは `~/claude-cli-tools-memo.md` にあったが**このファイルは現存しない** — 実害が出た時点で task を切って設計し直すこと。
