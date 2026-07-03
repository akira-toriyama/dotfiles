---
name: macos-gui-verify
description: Use when verifying macOS app GUI behavior end-to-end — dump an app's accessibility (AX) tree as JSON, query elements, and click/type/press via the peekaboo CLI. For "did my UI change actually work" checks on Swift/AppKit/SwiftUI apps.
---

# macOS GUI 検証は peekaboo（AX ツリー JSON + UI 操作）

> 出典: エージェント向け CLI 調査（2026-07-03。詳細 = `~/claude-cli-tools-memo.md` #2 節、task = projects t-c0s2）。peekaboo = openclaw/Peekaboo（MIT）、homebrew.nix で宣言済み（`steipete/tap/peekaboo`）。

## 前提（TCC）

- Accessibility + Screen Recording の許可は **CLI 本体でなくホストアプリ（Terminal / IDE）に付与**する（TCC の responsible-code）。ローカルで再ビルドしたバイナリでも同じホストから動く限り再付与不要。
- 確認: `peekaboo permissions status --all-sources`。未付与ならユーザーに System Settings での付与を依頼する（GUI 操作なので自分ではできない）。
- AI-provider 設定（API key）は自動化用途には不要。

## 基本ループ（見る → 選ぶ → 押す）

```sh
# 1) AX ツリーを JSON で見る（要素に opaque ID が振られ、snapshot が永続化される）
peekaboo see --app "MyApp" --json          # 大きい tree は --max-depth / --max-elements
# スクリーンショット不要なら: peekaboo inspect-ui --json

# 2) jq で要素を選ぶ（.data.ui_elements[] の .label / .description / .identifier で絞る）

# 3) 別プロセスからでも ID で操作できる（snapshot 経由で live 再解決）
peekaboo click --on <ID> [--snapshot <snapshot-id>]
peekaboo type "text" --app MyApp
peekaboo press return / peekaboo hotkey cmd,s / peekaboo set-value / peekaboo perform-action / peekaboo menu
```

- 既定は background 配送（フォーカスを奪わない）。key window が要るときだけ `--foreground`。
- snapshot が期限切れなら `SNAPSHOT_NOT_FOUND` → `see` を撮り直す。

## 注意

- **exit code は素の 0/1**（house の 0/1/2/3 ではない）。エラー詳細が要るときは必ず `--json` を付けて stderr でなく JSON エラーを読む。
- 要素指定は ID か属性ベース（label/identifier）で。`button 1 of window 1` 式の位置 index は tree 変化で壊れるので使わない。
- Peekaboo が重い/変化が速すぎる等の実害が出たら fallback（facet の AX モジュールで薄い Swift CLI を自作）の仕様スケッチが `~/claude-cli-tools-memo.md` #2 節にある。
