---
name: macos-gui-verify
description: Use when verifying macOS app GUI behavior end-to-end — for akira-toriyama Swift family apps the DEFAULT route is capsule's `make verify PROFILE=<app>` (Tart VM lab, all family apps racked); host-direct peekaboo (AX tree JSON + click/type/press) is for non-family apps or one-off pokes. For "did my UI change actually work" checks on Swift/AppKit/SwiftUI apps.
---

# macOS GUI 検証 — family app は capsule が既定、ホスト直は peekaboo

> 出典: エージェント向け CLI 調査（2026-07-03。採用 task = projects t-c0s2・done）。peekaboo = openclaw/Peekaboo（MIT）、homebrew.nix で宣言済み（`steipete/tap/peekaboo`）。

## family app の GUI 検証は capsule が既定（Tart VM の検証ラボ）

ホスト直の GUI 自動化は focus/Space を奪い、多 display 座標・TCC flakiness で
非決定的。**akira-toriyama Swift app family の「UI 変更が効いたか」検証は
capsule を既定経路にする** — ホスト直 peekaboo（下のループ）を使うのは
family 外の app か、その場限りの手元 1 回だけの確認に限る。
[capsule](https://github.com/akira-toriyama/capsule)
（local: `/Volumes/workspace/github.com/akira-toriyama/capsule`）。

- **rack は完成済み（2026-08-04 実測）**: wand / facet / sill-prism / chord /
  halo / perch の 6 profile 全てが `make verify` PASS 済み。「profile がまだ無い
  から手で」は family には成立しない。gate は app の形で決まる —— SwiftUI・
  AppKit controls = AX label / custom 描画 + 実 NSWindow = AX geometry /
  AX reader app = 自前 reader を gate に / headless daemon = control channel +
  log（正典 = capsule `docs/design.md` §The gate taxonomy）。
- **入口は一発コマンド**（生の tart ループを手組みしない）:

  ```sh
  cd /Volumes/workspace/github.com/akira-toriyama/capsule
  make verify PROFILE=<app>   # host build → clone → :ro 共有 → drive → AX assert → 破棄
  ```

  内訳・設計判断の正典は capsule の README / `docs/design.md`。
- 調査の 2 変数（知らないと毎回全部やり直しになる）: `CAPSULE_KEEP=1` =
  clone を残して post-mortem SSH / `CAPSULE_NO_BUILD=1` = 前回の host build を
  再利用して driver を高速反復。
- 対象 app の profile が無ければ、profile + driver + fixture の 3 ファイルを
  書くところから（雛形 = `profiles/wand.toml`、手順 = capsule
  `docs/design.md` §Adding an app）。
- base image が無いマシンは先に `make bake`（無人・数分）か、既存イメージの
  `.tvm` を `make import`。
- VM は使い捨て前提 — 中身の破壊も VM 削除も OK。ホストへの影響はほぼ無い。
- capsule の AX tier は peekaboo でなく **`capsule-ax-dump`**（raw AX walk）。
  SwiftUI (NSHostingView) の subtree は `inspect-ui` だと childless な opaque
  要素 1 個になる（2026-08-04 facet 実測 — 下の Electron 注意と同族）。
- 素の `tart` を手で叩く場合だけ `export TART_NO_AUTO_PRUNE=1` 必須
  （`make verify`/`make bake` は自分で設定する。素の `tart clone`/`pull` は
  OCI cache を LRU auto-prune し、他 VM を黙って消しうる）。

## VM への合成キーボードは VNC 経由（2026-08-10/11 実測・facet #448 受け入れ）

SSH 経由の合成キー CGEvent は VM 内 app に**届かない**（マウス系は届く — 非対称）。
キーが要る検証は `tart run --vnc-experimental` + vncdotool で回す。

- 起動: `TART_NO_AUTO_PRUNE=1 tart run <vm> --no-graphics --vnc-experimental`。
  **stdout をパイプで加工しない**（`| head` は vnc:// URL とパスワードを飲み込む —
  実績あり）。URL は生出力から読む。パスワードは run ごとに変わる。
- **全 vncdo 呼び出しに `--timeout <sec>` 必須**（PreToolUse hook `claude-vncdo-guard`
  が欠落を deny）。timeout 無しの hang で一晩溶かした実績が起点。
- **keysym は小文字**（`key down` / `key enter` / `key space`）。大文字 `key Down` は
  tart の VNC サーバ相手に無限 hang する（実測）。これも hook が deny。
- **Bash 1 回 = vncdo 1 invocation** に分割する。数珠つなぎの Bash が tool timeout を
  超えて background 化 → 迷子になった実績。各操作の後に capture で即検証。
- ただし **vncdo は接続（invocation）ごとに pointer/modifier 状態が独立** —
  invocation を跨いだ `move` は次の `mousedown` に引き継がれず (0,0) クリックに
  化ける（2026-08-11 実測: ⌘drag のつもりが壁紙 ⌘click → desktop reveal 発動）。
  **drag・修飾キー付き操作は 1 invocation 内に連鎖必須**:
  `vncdo --timeout 25 -s … keydown super move X Y mousedown 1 move X2 Y2 mouseup 1 keyup super`。
  連鎖の途中に `capture out.png` を挟めば mid-drag の視覚も取れる。
- **修飾キー combo `key super-n` は modifier が落ちて素の `n` になる**（実測）。
  combo は使わず `keydown super key n keyup super` 連鎖にする — それでも VM 内
  アプリに cmd+N が届かないことがあり、その場合は SSH 側 `peekaboo menu click
  --app <App> --item "New"` が確実。マウスも SSH 側 `capsule-click X Y` が
  pointer 状態問題と無縁で、VNC より信頼できる（キーだけが VNC 必須）。
- サーバは実質シングルクライアント: hang したクライアントが居座ると後続が全部
  詰まる。詰まったら `pkill -f "vncdo -s"` してから撮り直す。
- capture はフレームバッファ直取りで TCC 不要。ホイールは SSH 経由 `peekaboo scroll`
  でも可。座標系は VM のフレームバッファ実寸（Retina 2x）。

## 前提（TCC）

- Accessibility + Screen Recording の許可は **CLI 本体でなくホストアプリ（Terminal / IDE）に付与**する（TCC の responsible-code）。ローカルで再ビルドしたバイナリでも同じホストから動く限り再付与不要。
- 確認: `peekaboo permissions status --all-sources`（`--json` も可。`bridge` と `local` の 2 source が出る）。
- **付与するのは「peekaboo」ではなく責任を持つ親アプリ**。peekaboo は CLI formula だけで
  `.app` バンドルが無いので、System Settings の一覧に peekaboo という項目は出ない。
  実際に付与する対象はプロセスツリーの祖先アプリ（実測例: `zsh ← claude ← Code Helper (Plugin)
  ← Visual Studio Code.app` なので **VS Code**）。特定は
  `p=$$; ps -o ppid=,comm= -p $p` を親へ辿る。
- **付与はユーザーの手番**（macOS に TCC を grant する API / CLI は無い。`tccutil` は `reset` のみ、
  `TCC.db` は SIP 保護下）。Claude 側にできるのは**プロンプトを出させること**まで
  ——「System Settings > プライバシーとセキュリティ > 画面収録 で <親アプリ> を ON」と伝える。
- **画面収録は付与後にそのアプリを再起動するまで効かない**（Accessibility と違う）。
  IDE 内で動かしているなら、その IDE ごと再起動＝セッションも切れることを先に伝える。
- AI-provider 設定（API key）は自動化用途には不要。

## 基本ループ（見る → 選ぶ → 押す）

```sh
# 1) AX ツリーを見る。既定は see（構造化配列が返る唯一の経路。Screen Recording 必須）:
peekaboo see --app "MyApp" --json          # --mode screen で画面全体・--app frontmost も可
peekaboo inspect-ui --app "MyApp" --json   # Screen Recording が無い時だけ。返る形が違う（下記）

# 2) 要素を選ぶ。see は .data.ui_elements[] を返す。is_actionable=true で絞るのが速い:
peekaboo see --app "MyApp" --json | jq -r '.data.ui_elements[] | select(.is_actionable) | "\(.id)\t\(.role)\t\(.label)"'
#    snapshot は .data.snapshot_id、ウィンドウ名は .data.window_title（meta 階層は無い）。
#
#    ★ inspect-ui は構造化配列を返さない — テキスト塊なので jq で select できない:
peekaboo inspect-ui --app "MyApp" --json | jq -r '.data.content[].text'
#    → "elem_8 - \"保存\" - at (100, 200) size 80x24 - desc: \"...\"" 形式。role ごとに
#      グループ化され、非操作要素には [not actionable] が付く。
#    snapshot は .data.meta.snapshot_id、ウィンドウ名は .data.meta.summary.window_title。

# 3) 別プロセスからでも id で操作できる（snapshot 経由で live 再解決）
peekaboo click --on elem_8 [--snapshot <snapshot-id|latest>]
peekaboo type "text" --app MyApp
peekaboo press return / peekaboo hotkey cmd,s / peekaboo set-value / peekaboo perform-action / peekaboo menu
```

### JSON の形（2026-07-27 に両方とも実測・peekaboo 3.9.4）

**`see --json`（成功）** — `.success = true`、`.data` 直下がすべて:

| key | 中身（実測値の例） |
|---|---|
| `.data.ui_elements[]` | `{id, role, label, role_description, bounds{x,y,width,height}, is_actionable}`。`id` は `elem_8` 形式 |
| `.data.snapshot_id` / `.data.window_title` / `.data.application_name` | `meta` 階層は**無い** |
| `.data.element_count` / `.data.interactable_count` | 画面全体 1 枚で 517 / 400 |
| `.data.ui_map` | `~/.peekaboo/snapshots/<id>/snapshot.json` への**パス**（全量はこの先） |
| `.data.capture_mode` / `.data.is_dialog` / `.data.execution_time` | — |
| `.data.screenshot_raw` / `.data.screenshot_annotated` | **既定は空文字**。画像が要るなら `--path` / `--annotate` |

- **出力は大きい**（画面全体で約 160KB）。素で `cat` せず jq で絞るか `--app` で対象を狭める。

**`inspect-ui --json`（成功）** — `see` とは**別の形**。`.success = true` / `.data.isError = false`:

- `.data.meta.snapshot_id` — **`.data.snapshot_id` ではない**
- `.data.meta.{element_count, actionable_count, truncated, used_cache}`
- `.data.meta.summary.{action, target_app, window_title, capture_app, capture_window}`
- `.data.content[].text`（= `.data.text`）— **人間可読のテキスト塊**。
  **`.data.ui_elements[]` は返らない**ので jq で直接 select できない。
  絞り込みは `--max-elements` で減らすか、テキストを grep する。

**失敗** — `.success = false` + `.error.{code, message}`、**exit 1**（成功は 0）。code は実測で 4 種:

| code | いつ | どちら |
|---|---|---|
| `WINDOW_NOT_FOUND` | アプリは動いているがウィンドウが無い | `see` |
| `UNKNOWN_ERROR` | ウィンドウはあるが**共有可能な**ものが無い（Finder のデスクトップのみ等） | `see` |
| `VALIDATION_ERROR` | 同じ「ウィンドウ無し」状態 —— **`see` と code が違う** | `inspect-ui` |
| `PERMISSION_ERROR_SCREEN_RECORDING` | Screen Recording 未付与 | `see` |

- どの message も **アプリ名がローカライズ名で来る**（Notes → 「メモ」）ので文字列一致に使わない。
- **`--json` の出力が壊れて jq が落ちることがある**（`debug_logs` の中に `\'` という
  不正な JSON エスケープが混じる）。2026-07-27 に `see` で **3 回遭遇**したが、
  同じコマンドの 5 連続実行では**再現しなかった** —— ウィンドウ状態依存で
  **確実な再現条件は未特定**。落ちたら黙って諦めず、まず撮り直す。

- 既定は background 配送（フォーカスを奪わない）。key window が要るときだけ `--foreground`。
- snapshot が期限切れなら `SNAPSHOT_NOT_FOUND` → 撮り直す。
- **Electron 系は経路で結果が変わる**（VS Code で実測）: `inspect-ui` は `element_count = 0` +
  「No accessible UI elements found」を返すのに、同じアプリを `see --mode screen` で撮ると
  **517 要素（うち操作可能 400）が取れた**。0 要素は「AX が無い」ではなく
  **`inspect-ui` の経路で見えていないだけ**なので、`see` に切り替えて確かめる。
- **SwiftUI (NSHostingView) も `inspect-ui` に映らない**（2026-08-04 facet で実測）:
  subtree 全体が childless の opaque 要素 1 個になる。raw AXUIElement walk なら全階層が
  見える（`AXOpaqueProviderGroup` 配下に実要素）ので、app 側の AX 欠如と誤診しない。
  capsule 内なら `capsule-ax-dump`、ホストなら raw walk の薄い Swift CLI が要る。

## 注意

- **exit code は素の 0/1**（house の 0/1/2/3 ではない）。エラー詳細が要るときは必ず `--json` を付けて stderr でなく JSON エラーを読む。
- 要素指定は tree dump が返す `elem_N` id（+ 必要なら `--snapshot`）で。`button 1 of window 1` 式の位置 index は tree 変化で壊れるので使わない。
- Peekaboo が重い/変化が速すぎる等の実害が出たら fallback = facet の AX モジュールで薄い Swift CLI を自作する。※かつての仕様スケッチは `~/claude-cli-tools-memo.md` にあったが**このファイルは現存しない** — 実害が出た時点で task を切って設計し直すこと。
