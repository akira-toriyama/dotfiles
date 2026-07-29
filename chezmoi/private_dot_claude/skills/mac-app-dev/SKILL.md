---
name: mac-app-dev
description: Use when developing, modifying, or debugging a macOS app in Swift (AppKit/SwiftUI) — AX/AppKit gotchas, packaging & code-signing/TCC, testing & debugging. (Architecture & concurrency *design* → see the software-architecture skill.) Distilled house patterns.
---

# macOS app development — house patterns

> facet (Swift macOS app) から抽出した汎用知見。facet 固有の型名/ドメインは含めない。

## 設計・並行性 → `software-architecture` skill 参照
層分離（Core / Adapter / View）・ports & adapters・DDD・YAGNI 層判断・**並行性の設計則**（serial queue 一元化／cross-actor 非循環／value snapshot 受け渡し／非 Sendable 境界）は **`software-architecture` skill**（mac app 設計時に auto 発火）に集約＝二重管理しない。本 skill は以下の **macOS 固有の実装メカニクス**に専念する。

## UI の既定は SwiftUI + Sill（AppKit は floor と legacy 保守だけ）
- **新規 UI は SwiftUI ＋ [Sill](https://github.com/akira-toriyama/sill)**（共通 UI 基盤。theming コアと
  共有 widget kit を提供する）。**どの library が在るかは Sill の `Package.swift` を読む** ——
  ここにも global CLAUDE.md にも一覧を書き写さない（写した瞬間 drift する。正本は 1 箇所）。
- **AppKit を書いてよいのは 2 つだけ**: ① SwiftUI で届かない **essential floor**（何が floor かの
  判断基準と規律は `software-architecture` skill。floor の一覧を持つのは Sill 側であって skill ではない）
  ② 既存 AppKit コードの **legacy 保守**。下の落とし穴節はこの 2 つに効く実装知識。
- **足りない部品はアプリ側に one-off で足す前に Sill への PR を検討する**（共通化できるものを
  各アプリに散らさない）。
- OS サポートは**最新 macOS のみ**。古い OS 向けの availability 分岐は書かない。

## AppKit / AX 落とし穴
- agent 系アプリ: `LSUIElement=true`（Dock 無し）＋非アクティブ化パネル。別 window を focus する**前に** key を返す（クリックで panel が key を握ったまま離れない事故を防ぐ）。
- window title 等は **AX 解決**（`kAXTitle`・短 TTL キャッシュ・off-main）。backend が埋めると仮定しない。
- **flipped clip view を初日から使う**（非 flipped `NSClipView` は断続的 drag 失敗）。既知 fix は先回り採用。
- drag-state は **backend 往復フラグ**（確定で clear）でモデル化、mouseUp でなく。
- 新 window 検知は per-app AX 購読（`kAXWindowCreated`/`kAXFocusedWindowChanged`/`kAXUIElementDestroyed`）＋`NSWorkspace` launch/terminate。swizzling しない。
- ディスプレイ再構成は単一 `didChangeScreenParametersNotification` で処理、~0.5s デバウンス、画面外 window は最寄り可視ディスプレイへ snap。
- private SkyLight/CGS は `dlsym` で read-only。Space 跨ぎ移動は SIP-off が要る → 公開 API + AX に留めて SIP-on を維持。

## Packaging / signing / build
- **TCC 許可は署名 identity ＋ bundle id に紐づく** → ad-hoc 署名は毎ビルドで許可を失う。**永続 self-signed cert ＋ 固定 bundle id** で許可を跨ぐ。
- `@main` は named type に（`@main enum App` を普通の .swift に）。`main.swift` は実行ターゲットの `@testable import` を壊す。
- 新 `Sources/*` には `.target`、`Tests/*` には `.testTarget` を必ず。

## Testing / debugging
- `swift build` は CommandLineTools で可、`swift test`(XCTest) は Xcode 必須 → **CI を test gate**、ローカルは `swift build` を bar に。
- GUI バグ: **理論より先に観察** — 画面録画をフレーム抽出（`ffmpeg -i in.mov -vf fps=3 f_%02d.png`）して PNG を読む。hot path は env gate 付きログ。
- 2回以上 fix が外れたら、OS 挙動を**使い捨ての純 AppKit `.executableTarget` sandbox**（アプリ依存なし）に切り出して OS ノブを A/B（MRE）。
- 科学的デバッグ（観察→仮説→実験）＋`git bisect`。綺麗な commit が bisect を安くする。
- ホスト影響変更・新規許可フローの検証は **VM**（Tart・APFS-COW clone + suspend snapshot）でクリーン環境実証。
- 二層ログ: 常時 `Log.line` ＋ env-gate `Log.debug`（off は bool 1回）。temp file へ書き、gate on の時だけ stderr へミラー。

## コメント方針（mandate 2026-07-29）
- **コメントの読者は Claude Code。人間向けの説明コメントは書かない** — tutorial 調の
  逐語説明・コードの言い換え・飾りの区切り見出しは書かない。既存コードで見つけたら削る。
- 書く・残すのは**保守に効くコメントだけ**: コードに表せない制約・不変条件・
  型/module 冒頭の層契約（役割と禁止事項）・外部仕様への追随点・「なぜこうしないか」。
- 迷ったら書かない。コードで表せる情報は naming・型・test に載せる。
