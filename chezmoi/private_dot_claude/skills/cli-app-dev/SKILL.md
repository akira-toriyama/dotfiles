---
name: cli-app-dev
description: Use when developing or modifying a CLI app/tool (especially in Swift) — argument grammar, exit codes, stdout/stderr discipline, config files, Homebrew distribution. Distilled house patterns.
---

# CLI app development — house patterns

> facet (Swift app の CLI 面) ＋ cli-migration から抽出した汎用知見。facet 固有のサブコマンド語彙は含めない。

## 引数 grammar & UX
- POSIX/GNU: `--long-option`。`--help`/`--version` は行のどこでも効く。
- **grammar を1つに決めて commit**。facet は `--flag=VALUE` → `--flag VALUE`（互換 shim 無しのハードカットオーバー）。value flag は次トークンを無条件に消費＝負値が通る（`--pos-x -1440`）。value 欠落は大声で `exit 2`。
- **subcommand / subject-verb**（`tool DOMAIN --verb`）は flat な flag soup より scale し補完も自然。flag は影響する verb の下に scope。
- **canonical 形を1つ**、bare-flag 同義語なし。op ごとに明示の NAME/value を要求（短縮はユーザーの shell alias の仕事）。
- show/set は idempotent。toggle は別途明示の `--toggle`（show での toggle にしない）。
- 対称な op: 新 noun = テーブル行 ＋ dispatch case の追加だけ、noun ごとの専用 flag を作らない。

## エラー / exit code / ストリーム
- **exit code**: 0 成功 / 1 utility 失敗 / 2 usage 誤り。typo・未知名は**大声で失敗**（`exit 2` ＋ stderr）、silent fallback しない。
- **stdout = パイプ可能な結果 / stderr = 診断・ログ**。happy path は silent success（Rule of Silence）。
- ユーザー識別子の strict name policy: 非空・先頭 `-` 不可・空白や grammar 文字（`: = ,`）不可。flag に見える値は拒否（silent 誤適用を防ぐ）。

## アーキテクチャ
- **parser を純粋な isolated seam に**: 純 arg-parser を Core に（unit-test 可・GUI 無し）→ argv を安定した内部 control 文字列へ。impure な exit/stderr の殻は app 層。grammar 変更が core を触らない。

## Config ファイル
- 単一 config = **read-only な source of truth**。auto-生成/auto-書込/runtime override の永続化をしない。CLI override は session 限り。
- 範囲外/未知値は default に clamp（typo は 1 key を壊すだけ、アプリ全体でない）。読みは `effective*` アクセサ経由、生 optional を直接見ない。
- bare top-level key より名前付き `[section]` ブロック（各 section が自己完結で grep できる）。

## スクリプト / 配布 / ハザード
- 状態変更スクリプトは `--dry-run`（preview）＋ `/tmp/<script>.log` に tee（`--silent` で opt-out）。※長命サーバの env-gate default-quiet とは極性が逆。
- **Homebrew tap で配布**、release ごとに formula bump を CI 自動化、**publish 後に remote formula の url/sha が実際に変わったか目視**（update-tap は未変更でも成功報告する前科）。
- **silent-break ハザード**: hotkey runner（skhd/hammerspoon/chord）は非ゼロ exit を握り潰す → 古い binding が無言で失敗。grammar 変更時は全 binding を再確認。
- **GUI→CLI 分離**: キーボードショートカット管理をアプリに入れない。合成可能な CLI を出し、skhd/Karabiner/hammerspoon でユーザーに配線させる（yabai+skhd モデル）。
