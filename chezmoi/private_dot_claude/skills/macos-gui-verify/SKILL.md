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
# 1) AX ツリーを見る。Screen Recording が要らない方が inspect-ui:
peekaboo inspect-ui --app "MyApp" --json   # 大きい tree は --max-depth / --max-elements / --max-children
peekaboo see --app "MyApp" --json          # スクリーンショットも要るとき（Screen Recording 必須）

# 2) 要素 ID を拾う。★ inspect-ui は構造化配列を返さない（下の「JSON の形」参照）:
peekaboo inspect-ui --app "MyApp" --json | jq -r '.data.content[].text'
#    → "elem_8 - \"保存\" - at (100, 200) size 80x24 - desc: \"...\"" 形式のテキスト塊。
#      role ごとにグループ化され、非操作要素には [not actionable] が付く。
#    snapshot は .data.meta.snapshot_id、ウィンドウ名は .data.meta.summary.window_title。

# 3) 別プロセスからでも id で操作できる（snapshot 経由で live 再解決）
peekaboo click --on elem_8 [--snapshot <snapshot-id|latest>]
peekaboo type "text" --app MyApp
peekaboo press return / peekaboo hotkey cmd,s / peekaboo set-value / peekaboo perform-action / peekaboo menu
```

### JSON の形（`inspect-ui` は 2026-07-27 に実測・peekaboo 3.9.4）

- 成功: `.success = true` / `.data.isError = false`
  - `.data.meta.snapshot_id` — **`.data.snapshot_id` ではない**
  - `.data.meta.{element_count, actionable_count, truncated, used_cache}`
  - `.data.meta.summary.{action, target_app, window_title, capture_app, capture_window}`
  - `.data.content[].text`（= `.data.text`）— **人間可読のテキスト塊**。
    **`.data.ui_elements[]` のような構造化配列は返らない**ので、
    `id / role / label / bounds / is_actionable` を jq で直接 select することはできない。
    絞り込みが要るなら `--max-elements` で減らすか、テキストを grep する。
- 失敗: `.success = false` + `.error.{code, message}`、**exit 1**（成功は 0）
  - ウィンドウを持たないアプリ → `VALIDATION_ERROR`「App 'X' is running but has no windows or dialogs」。
    エラーでなく状態 — 対象アプリのウィンドウを開いてから撮る。
    **`X` はローカライズ名で来る**（Notes → 「メモ」）ので文字列一致に使わない。
  - Screen Recording 未付与で `see` → `PERMISSION_ERROR_SCREEN_RECORDING`・exit 1。
- **`see --json` の成功時スキーマは未検証**（この機械は Screen Recording 未付与のため実測できていない）。
  `inspect-ui` と同形とは限らないので、使う前に 1 回撮って確かめること。

- 既定は background 配送（フォーカスを奪わない）。key window が要るときだけ `--foreground`。
- snapshot が期限切れなら `SNAPSHOT_NOT_FOUND` → 撮り直す。
- **Electron / 非ネイティブアプリは 0 要素で返ることがある**（VS Code で実測: `element_count = 0` +
  「No accessible UI elements found」）。AX 経路が無いだけなので、`see` の画像側に切り替える。

## 注意

- **exit code は素の 0/1**（house の 0/1/2/3 ではない）。エラー詳細が要るときは必ず `--json` を付けて stderr でなく JSON エラーを読む。
- 要素指定は tree dump が返す `elem_N` id（+ 必要なら `--snapshot`）で。`button 1 of window 1` 式の位置 index は tree 変化で壊れるので使わない。
- Peekaboo が重い/変化が速すぎる等の実害が出たら fallback = facet の AX モジュールで薄い Swift CLI を自作する。※かつての仕様スケッチは `~/claude-cli-tools-memo.md` にあったが**このファイルは現存しない** — 実害が出た時点で task を切って設計し直すこと。
